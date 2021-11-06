/*

Copyright (c) 2021 Alex Forencich

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
 * Statistics collector
 */
module stats_collect #
(
    // Channel count
    parameter COUNT = 8,
    // Increment width (bits)
    parameter INC_WIDTH = 8,
    // Statistics counter increment width (bits)
    parameter STAT_INC_WIDTH = 16,
    // Statistics counter ID width (bits)
    parameter STAT_ID_WIDTH = $clog2(COUNT),
    // Statistics counter update period (cycles)
    parameter UPDATE_PERIOD = 1024
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * Increment inputs
     */
    input  wire [INC_WIDTH*COUNT-1:0]  stat_inc,
    input  wire [COUNT-1:0]            stat_valid,

    /*
     * Statistics increment output
     */
    output wire [STAT_INC_WIDTH-1:0]   m_axis_stat_tdata,
    output wire [STAT_ID_WIDTH-1:0]    m_axis_stat_tid,
    output wire                        m_axis_stat_tvalid,
    input  wire                        m_axis_stat_tready,

    /*
     * Control inputs
     */
    input  wire                        update
);

parameter COUNT_WIDTH = $clog2(COUNT);
parameter PERIOD_COUNT_WIDTH = $clog2(UPDATE_PERIOD-1);
parameter ACC_WIDTH = INC_WIDTH+COUNT_WIDTH+1;

localparam [1:0]
    STATE_READ = 2'd0,
    STATE_WRITE = 2'd1;

reg [1:0] state_reg = STATE_READ, state_next;

reg [STAT_INC_WIDTH-1:0] m_axis_stat_tdata_reg = 0, m_axis_stat_tdata_next;
reg [STAT_ID_WIDTH-1:0] m_axis_stat_tid_reg = 0, m_axis_stat_tid_next;
reg m_axis_stat_tvalid_reg = 0, m_axis_stat_tvalid_next;

reg [COUNT_WIDTH-1:0] count_reg = 0, count_next;
reg [PERIOD_COUNT_WIDTH-1:0] update_period_reg = UPDATE_PERIOD-1, update_period_next;
reg [COUNT-1:0] zero_reg = {COUNT{1'b1}}, zero_next;
reg [COUNT-1:0] update_reg = {COUNT{1'b0}}, update_next;

wire [ACC_WIDTH-1:0] acc_int[COUNT-1:0];
reg [COUNT-1:0] acc_clear;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [STAT_INC_WIDTH-1:0] mem_reg[COUNT-1:0];

reg [STAT_INC_WIDTH-1:0] mem_rd_data_reg = 0;

reg mem_rd_en;
reg mem_wr_en;
reg [STAT_INC_WIDTH-1:0] mem_wr_data;

assign m_axis_stat_tdata = m_axis_stat_tdata_reg;
assign m_axis_stat_tid = m_axis_stat_tid_reg;
assign m_axis_stat_tvalid = m_axis_stat_tvalid_reg;

generate

    genvar n;

    for (n = 0; n < COUNT; n = n + 1) begin
        reg [ACC_WIDTH-1:0] acc_reg = 0;

        assign acc_int[n] = acc_reg;

        always @(posedge clk) begin
            if (acc_clear[n]) begin
                if (stat_valid[n]) begin
                    acc_reg <= stat_inc[n*INC_WIDTH +: INC_WIDTH];
                end else begin
                    acc_reg <= 0;
                end
            end else begin
                if (stat_valid[n]) begin
                    acc_reg <= acc_reg + stat_inc[n*INC_WIDTH +: INC_WIDTH];
                end
            end

            if (rst) begin
                acc_reg <= 0;
            end
        end
    end

endgenerate

always @* begin
    state_next = STATE_READ;

    m_axis_stat_tdata_next = m_axis_stat_tdata_reg;
    m_axis_stat_tid_next = m_axis_stat_tid_reg;
    m_axis_stat_tvalid_next = m_axis_stat_tvalid_reg && !m_axis_stat_tready;

    count_next = count_reg;
    update_period_next = update_period_reg;
    zero_next = zero_reg;
    update_next = update_reg;

    acc_clear = {COUNT{1'b0}};

    mem_rd_en = 1'b0;
    mem_wr_en = 1'b0;
    mem_wr_data = 0;

    case (state_reg)
        STATE_READ: begin
            mem_rd_en = 1'b1;
            state_next = STATE_WRITE;
        end
        STATE_WRITE: begin;
            mem_wr_en = 1'b1;
            acc_clear[count_reg] = 1'b1;
            if (!m_axis_stat_tvalid_reg && update_reg[count_reg]) begin
                update_next[count_reg] = 1'b0;
                mem_wr_data = 0;
                if (zero_reg[count_reg]) begin
                    m_axis_stat_tdata_next = acc_int[count_reg];
                    m_axis_stat_tid_next = count_reg;
                    m_axis_stat_tvalid_next = acc_int[count_reg] != 0;
                end else begin
                    m_axis_stat_tdata_next = mem_rd_data_reg + acc_int[count_reg];
                    m_axis_stat_tid_next = count_reg;
                    m_axis_stat_tvalid_next = mem_rd_data_reg != 0 || acc_int[count_reg] != 0;
                end
            end else begin
                if (zero_reg[count_reg]) begin
                    mem_wr_data = acc_int[count_reg];
                end else begin
                    mem_wr_data = mem_rd_data_reg + acc_int[count_reg];
                end
            end
            zero_next[count_reg] = 1'b0;

            if (count_reg == COUNT-1) begin
                count_next = 0;
            end else begin
                count_next = count_reg + 1;
            end

            state_next = STATE_READ;
        end
    endcase

    if (update_period_reg == 0) begin
        update_next = {COUNT{1'b1}};
        update_period_next = UPDATE_PERIOD-1;
    end else begin
        update_period_next = update_period_reg - 1;
    end

    if (update) begin
        update_next = {COUNT{1'b1}};
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    m_axis_stat_tdata_reg <= m_axis_stat_tdata_next;
    m_axis_stat_tid_reg <= m_axis_stat_tid_next;
    m_axis_stat_tvalid_reg <= m_axis_stat_tvalid_next;

    count_reg <= count_next;
    update_period_reg <= update_period_next;
    zero_reg <= zero_next;
    update_reg <= update_next;

    if (mem_wr_en) begin
        mem_reg[count_reg] <= mem_wr_data;
    end else if (mem_rd_en) begin
        mem_rd_data_reg <= mem_reg[count_reg];
    end

    if (rst) begin
        state_reg <= STATE_READ;
        m_axis_stat_tvalid_reg <= 1'b0;
        count_reg <= 0;
        update_period_reg <= UPDATE_PERIOD-1;
        zero_reg <= {COUNT{1'b1}};
        update_reg <= {COUNT{1'b0}};
    end
end

endmodule

`resetall
