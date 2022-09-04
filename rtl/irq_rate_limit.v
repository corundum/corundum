/*

Copyright (c) 2022 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * IRQ rate limit module
 */
module irq_rate_limit #
(
    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = 11
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * Interrupt request input
     */
    input  wire [IRQ_INDEX_WIDTH-1:0]  in_irq_index,
    input  wire                        in_irq_valid,
    output wire                        in_irq_ready,

    /*
     * Interrupt request output
     */
    output wire [IRQ_INDEX_WIDTH-1:0]  out_irq_index,
    output wire                        out_irq_valid,
    input  wire                        out_irq_ready,

    /*
     * Configuration
     */
    input  wire [15:0]                 prescale,
    input  wire [15:0]                 min_interval
);

localparam [1:0]
    STATE_INIT = 2'd0,
    STATE_IDLE = 2'd1,
    STATE_IRQ_IN = 2'd2,
    STATE_IRQ_OUT = 2'd3;

reg [1:0] state_reg = STATE_INIT, state_next;

reg [IRQ_INDEX_WIDTH-1:0] cur_index_reg = 0, cur_index_next;
reg [IRQ_INDEX_WIDTH-1:0] irq_index_reg = 0, irq_index_next;

reg mem_rd_en;
reg mem_wr_en;
reg [IRQ_INDEX_WIDTH-1:0] mem_addr;
reg [17+1+1-1:0] mem_wr_data;
reg [17+1+1-1:0] mem_rd_data_reg;
reg mem_rd_data_valid_reg = 1'b0, mem_rd_data_valid_next;

(* ramstyle = "no_rw_check, mlab" *)
reg [17+1+1-1:0] mem_reg[2**IRQ_INDEX_WIDTH-1:0];

reg in_irq_ready_reg = 0, in_irq_ready_next;

reg [IRQ_INDEX_WIDTH-1:0] out_irq_index_reg = 0, out_irq_index_next;
reg out_irq_valid_reg = 0, out_irq_valid_next;

assign in_irq_ready = in_irq_ready_reg;

assign out_irq_index = out_irq_index_reg;
assign out_irq_valid = out_irq_valid_reg;

integer i;

initial begin
    for (i = 0; i < 2**IRQ_INDEX_WIDTH; i = i + 1) begin
        mem_reg[i] = 0;
    end
end

reg [15:0] prescale_count_reg = 0;
reg [16:0] time_count_reg = 0;

always @(posedge clk) begin
    if (prescale_count_reg != 0) begin
        prescale_count_reg <= prescale_count_reg - 1;
    end else begin
        prescale_count_reg <= prescale;
        time_count_reg <= time_count_reg + 1;
    end

    if (rst) begin
        prescale_count_reg <= 0;
        time_count_reg <= 0;
    end
end

always @* begin
    state_next = STATE_INIT;

    cur_index_next = cur_index_reg;
    irq_index_next = irq_index_reg;

    in_irq_ready_next = 1'b0;

    out_irq_index_next = out_irq_index_reg;
    out_irq_valid_next = out_irq_valid_reg && !out_irq_ready;

    mem_rd_en = 1'b0;
    mem_wr_en = 1'b0;
    mem_addr = cur_index_reg;
    mem_wr_data = mem_rd_data_reg;
    mem_rd_data_valid_next = mem_rd_data_valid_reg;

    case (state_reg)
        STATE_INIT: begin
            // init - clear all timers
            mem_addr = cur_index_reg;
            mem_wr_data[0] = 1'b0;
            mem_wr_data[1] = 1'b0;
            mem_wr_data[2 +: 17] = 0;
            mem_wr_en = 1'b1;
            cur_index_next = cur_index_reg + 1;
            if (cur_index_next != 0) begin
                state_next = STATE_INIT;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_IDLE: begin
            // idle - wait for requests and check timers
            in_irq_ready_next = 1'b1;
            if (in_irq_valid && in_irq_ready) begin
                // new interrupt request
                irq_index_next = in_irq_index;
                mem_addr = in_irq_index;
                mem_rd_en = 1'b1;
                mem_rd_data_valid_next = 1'b1;
                in_irq_ready_next = 1'b0;
                state_next = STATE_IRQ_IN;
            end else if (mem_rd_data_valid_reg && mem_rd_data_reg[1] && (mem_rd_data_reg[2 +: 17] - time_count_reg) >> 16 != 0) begin
                // timer expired
                in_irq_ready_next = 1'b0;
                state_next = STATE_IRQ_OUT;
            end else begin
                // read next timer
                irq_index_next = cur_index_reg;
                mem_addr = cur_index_reg;
                mem_rd_en = 1'b1;
                mem_rd_data_valid_next = 1'b1;
                cur_index_next = cur_index_reg + 1;
                state_next = STATE_IDLE;
            end
        end
        STATE_IRQ_IN: begin
            // pass through IRQ
            if (mem_rd_data_reg[1]) begin
                // timer running, set pending bit
                mem_addr = irq_index_reg;
                mem_wr_data[0] = 1'b1;
                mem_wr_data[1] = 1'b1;
                mem_wr_data[2 +: 17] = mem_rd_data_reg[2 +: 17];
                mem_wr_en = 1'b1;
                mem_rd_data_valid_next = 1'b0;

                in_irq_ready_next = 1'b1;
                state_next = STATE_IDLE;
            end else if (!out_irq_valid || out_irq_ready) begin
                // timer not running, start timer and generate IRQ
                mem_addr = irq_index_reg;
                mem_wr_data[0] = 1'b0;
                mem_wr_data[1] = min_interval != 0;
                mem_wr_data[2 +: 17] = time_count_reg + min_interval;
                mem_wr_en = 1'b1;
                mem_rd_data_valid_next = 1'b0;

                out_irq_valid_next = 1'b1;
                out_irq_index_next = irq_index_reg;

                in_irq_ready_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_IRQ_IN;
            end
        end
        STATE_IRQ_OUT: begin
            // handle timer expiration
            if (mem_rd_data_reg[0]) begin
                // pending bit set, generate IRQ and restart timer
                if (!out_irq_valid || out_irq_ready) begin
                    mem_addr = irq_index_reg;
                    mem_wr_data[0] = 1'b0;
                    mem_wr_data[1] = min_interval != 0;
                    mem_wr_data[2 +: 17] = time_count_reg + min_interval;
                    mem_wr_en = 1'b1;
                    mem_rd_data_valid_next = 1'b0;

                    out_irq_valid_next = 1'b1;
                    out_irq_index_next = irq_index_reg;

                    in_irq_ready_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_IRQ_OUT;
                end
            end else begin
                // pending bit not set, reset timer
                mem_addr = irq_index_reg;
                mem_wr_data[0] = 1'b0;
                mem_wr_data[1] = 1'b0;
                mem_wr_data[2 +: 17] = 0;
                mem_wr_en = 1'b1;
                mem_rd_data_valid_next = 1'b0;
                
                in_irq_ready_next = 1'b1;
                state_next = STATE_IDLE;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    cur_index_reg <= cur_index_next;
    irq_index_reg <= irq_index_next;

    in_irq_ready_reg <= in_irq_ready_next;

    out_irq_index_reg <= out_irq_index_next;
    out_irq_valid_reg <= out_irq_valid_next;

    if (mem_wr_en) begin
        mem_reg[mem_addr] <= mem_wr_data;
    end else if (mem_rd_en) begin
        mem_rd_data_reg <= mem_reg[mem_addr];
    end

    mem_rd_data_valid_reg <= mem_rd_data_valid_next;

    if (rst) begin
        state_reg <= STATE_INIT;
        cur_index_reg <= 0;
        in_irq_ready_reg <= 1'b0;
        out_irq_valid_reg <= 1'b0;
        mem_rd_data_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
