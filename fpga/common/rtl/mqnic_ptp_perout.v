/*

Copyright 2021, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PTP period output
 */
module mqnic_ptp_perout
(
    input  wire         clk,
    input  wire         rst,

    /*
     * Register interface
     */
    input  wire [6:0]   reg_wr_addr,
    input  wire [31:0]  reg_wr_data,
    input  wire [3:0]   reg_wr_strb,
    input  wire         reg_wr_en,
    output wire         reg_wr_wait,
    output wire         reg_wr_ack,
    input  wire [6:0]   reg_rd_addr,
    input  wire         reg_rd_en,
    output wire [31:0]  reg_rd_data,
    output wire         reg_rd_wait,
    output wire         reg_rd_ack,

    /*
     * PTP clock
     */
    input  wire [95:0]  ptp_ts_96,
    input  wire         ptp_ts_step,
    output wire         ptp_perout_locked,
    output wire         ptp_perout_error,
    output wire         ptp_perout_pulse
);

reg ptp_perout_enable_reg = 1'b0;

// control registers
reg reg_wr_ack_reg = 1'b0;
reg [31:0] reg_rd_data_reg = 0;
reg reg_rd_ack_reg = 1'b0;

reg [95:0] set_ptp_perout_start_reg = 0;
reg set_ptp_perout_start_valid_reg = 0;
reg [95:0] set_ptp_perout_period_reg = 0;
reg set_ptp_perout_period_valid_reg = 0;
reg [95:0] set_ptp_perout_width_reg = 0;
reg set_ptp_perout_width_valid_reg = 0;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

always @(posedge clk) begin
    reg_wr_ack_reg <= 1'b0;
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    set_ptp_perout_start_valid_reg <= 1'b0;
    set_ptp_perout_period_valid_reg <= 1'b0;
    set_ptp_perout_width_valid_reg <= 1'b0;

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_reg <= 1'b1;
        case ({reg_wr_addr >> 2, 2'b00})
            6'h00: begin
                // PTP perout control
                ptp_perout_enable_reg <= reg_wr_data[0];
            end
            6'h10: set_ptp_perout_start_reg[15:0] <= reg_wr_data;  // PTP perout start fns
            6'h14: set_ptp_perout_start_reg[45:16] <= reg_wr_data; // PTP perout start ns
            6'h18: set_ptp_perout_start_reg[79:48] <= reg_wr_data; // PTP perout start sec l
            6'h1C: begin
                // PTP perout start sec h
                set_ptp_perout_start_reg[95:80] <= reg_wr_data;
                set_ptp_perout_start_valid_reg <= 1'b1;
            end
            6'h20: set_ptp_perout_period_reg[15:0] <= reg_wr_data;  // PTP perout period fns
            6'h24: set_ptp_perout_period_reg[45:16] <= reg_wr_data; // PTP perout period ns
            6'h28: set_ptp_perout_period_reg[79:48] <= reg_wr_data; // PTP perout period sec l
            6'h2C: begin
                // PTP perout period sec h
                set_ptp_perout_period_reg[95:80] <= reg_wr_data;
                set_ptp_perout_period_valid_reg <= 1'b1;
            end
            6'h30: set_ptp_perout_width_reg[15:0] <= reg_wr_data;  // PTP perout width fns
            6'h34: set_ptp_perout_width_reg[45:16] <= reg_wr_data; // PTP perout width ns
            6'h38: set_ptp_perout_width_reg[79:48] <= reg_wr_data; // PTP perout width sec l
            6'h3C: begin
                // PTP perout width sec h
                set_ptp_perout_width_reg[95:80] <= reg_wr_data;
                set_ptp_perout_width_valid_reg <= 1'b1;
            end
            default: reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_reg <= 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            6'h00: begin
                // PTP perout control
                reg_rd_data_reg[0] <= ptp_perout_enable_reg;
            end
            6'h04: begin
                // PTP perout status
                reg_rd_data_reg[0] <= ptp_perout_pulse;
                reg_rd_data_reg[8] <= ptp_perout_locked;
                reg_rd_data_reg[16] <= ptp_perout_error;
            end
            6'h10: reg_rd_data_reg <= set_ptp_perout_start_reg[15:0];  // PTP perout start fns
            6'h14: reg_rd_data_reg <= set_ptp_perout_start_reg[45:16]; // PTP perout start ns
            6'h18: reg_rd_data_reg <= set_ptp_perout_start_reg[79:48]; // PTP perout start sec l
            6'h1C: reg_rd_data_reg <= set_ptp_perout_start_reg[95:80]; // PTP perout start sec h
            6'h20: reg_rd_data_reg <= set_ptp_perout_period_reg[15:0];  // PTP perout period fns
            6'h24: reg_rd_data_reg <= set_ptp_perout_period_reg[45:16]; // PTP perout period ns
            6'h28: reg_rd_data_reg <= set_ptp_perout_period_reg[79:48]; // PTP perout period sec l
            6'h2C: reg_rd_data_reg <= set_ptp_perout_period_reg[95:80]; // PTP perout period sec h
            6'h30: reg_rd_data_reg <= set_ptp_perout_width_reg[15:0];  // PTP perout width fns
            6'h34: reg_rd_data_reg <= set_ptp_perout_width_reg[45:16]; // PTP perout width ns
            6'h38: reg_rd_data_reg <= set_ptp_perout_width_reg[79:48]; // PTP perout width sec l
            6'h3C: reg_rd_data_reg <= set_ptp_perout_width_reg[95:80]; // PTP perout width sec h
            default: reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        ptp_perout_enable_reg <= 1'b0;
    end
end

ptp_perout #(
    .FNS_ENABLE(0),
    .OUT_START_S(0),
    .OUT_START_NS(0),
    .OUT_START_FNS(0),
    .OUT_PERIOD_S(1),
    .OUT_PERIOD_NS(0),
    .OUT_PERIOD_FNS(0),
    .OUT_WIDTH_S(0),
    .OUT_WIDTH_NS(500000000),
    .OUT_WIDTH_FNS(0)
)
ptp_perout_inst (
    .clk(clk),
    .rst(rst),
    .input_ts_96(ptp_ts_96),
    .input_ts_step(ptp_ts_step),
    .enable(ptp_perout_enable_reg),
    .input_start(set_ptp_perout_start_reg),
    .input_start_valid(set_ptp_perout_start_valid_reg),
    .input_period(set_ptp_perout_period_reg),
    .input_period_valid(set_ptp_perout_period_valid_reg),
    .input_width(set_ptp_perout_width_reg),
    .input_width_valid(set_ptp_perout_width_valid_reg),
    .locked(ptp_perout_locked),
    .error(ptp_perout_error),
    .output_pulse(ptp_perout_pulse)
);

endmodule

`resetall
