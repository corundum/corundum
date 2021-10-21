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
 * PTP hardware clock
 */
module mqnic_ptp #
(
    parameter PTP_PERIOD_NS_WIDTH = 4,
    parameter PTP_OFFSET_NS_WIDTH = 32,
    parameter PTP_FNS_WIDTH = 32,
    parameter PTP_PERIOD_NS = 4'd4,
    parameter PTP_PERIOD_FNS = 32'd0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,
    parameter REG_ADDR_WIDTH = 7+(PTP_PEROUT_ENABLE ? $clog2((PTP_PEROUT_COUNT+1)/2) + 1 : 0),
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8)
)
(
    input  wire                         clk,
    input  wire                         rst,

    /*
     * Register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]    reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]    reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]    reg_wr_strb,
    input  wire                         reg_wr_en,
    output wire                         reg_wr_wait,
    output wire                         reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]    reg_rd_addr,
    input  wire                         reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]    reg_rd_data,
    output wire                         reg_rd_wait,
    output wire                         reg_rd_ack,

    /*
     * PTP clock
     */
    output wire                         ptp_pps,
    output wire [95:0]                  ptp_ts_96,
    output wire                         ptp_ts_step,
    output wire [PTP_PEROUT_COUNT-1:0]  ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]  ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]  ptp_perout_pulse
);

// bus width assertions
initial begin
    if (REG_DATA_WIDTH != 32) begin
        $error("Error: Register interface width must be 32 (instance %m)");
        $finish;
    end

    if (REG_STRB_WIDTH * 8 != REG_DATA_WIDTH) begin
        $error("Error: Register interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (REG_ADDR_WIDTH < 7+(PTP_PEROUT_ENABLE ? $clog2((PTP_PEROUT_COUNT+1)/2) + 1 : 0)) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end
end

wire clock_reg_wr_wait;
wire clock_reg_wr_ack;
wire [31:0] clock_reg_rd_data;
wire clock_reg_rd_wait;
wire clock_reg_rd_ack;

wire perout_reg_wr_wait[PTP_PEROUT_COUNT-1:0];
wire perout_reg_wr_ack[PTP_PEROUT_COUNT-1:0];
wire [31:0] perout_reg_rd_data[PTP_PEROUT_COUNT-1:0];
wire perout_reg_rd_wait[PTP_PEROUT_COUNT-1:0];
wire perout_reg_rd_ack[PTP_PEROUT_COUNT-1:0];

reg reg_wr_wait_cmb;
reg reg_wr_ack_cmb;
reg [31:0] reg_rd_data_cmb;
reg reg_rd_wait_cmb;
reg reg_rd_ack_cmb;

assign reg_wr_wait = reg_wr_wait_cmb;
assign reg_wr_ack = reg_wr_ack_cmb;
assign reg_rd_data = reg_rd_data_cmb;
assign reg_rd_wait = reg_rd_wait_cmb;
assign reg_rd_ack = reg_rd_ack_cmb;

integer k;

always @* begin
    reg_wr_wait_cmb = clock_reg_wr_wait;
    reg_wr_ack_cmb = clock_reg_wr_ack;
    reg_rd_data_cmb = clock_reg_rd_data;
    reg_rd_wait_cmb = clock_reg_rd_wait;
    reg_rd_ack_cmb = clock_reg_rd_ack;

    if (PTP_PEROUT_ENABLE) begin
        for (k = 0; k < PTP_PEROUT_COUNT; k = k + 1) begin
            reg_wr_wait_cmb = reg_wr_wait_cmb | perout_reg_wr_wait[k];
            reg_wr_ack_cmb = reg_wr_ack_cmb | perout_reg_wr_ack[k];
            reg_rd_data_cmb = reg_rd_data_cmb | perout_reg_rd_data[k];
            reg_rd_wait_cmb = reg_rd_wait_cmb | perout_reg_rd_wait[k];
            reg_rd_ack_cmb = reg_rd_ack_cmb | perout_reg_rd_ack[k];
        end
    end
end

mqnic_ptp_clock #(
    .PTP_PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .PTP_OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .PTP_FNS_WIDTH(PTP_FNS_WIDTH),
    .PTP_PERIOD_NS(PTP_PERIOD_NS),
    .PTP_PERIOD_FNS(PTP_PERIOD_FNS),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT)
)
ptp_clock_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Register interface
     */
    .reg_wr_addr(reg_wr_addr),
    .reg_wr_data(reg_wr_data),
    .reg_wr_strb(reg_wr_strb),
    .reg_wr_en(reg_wr_en && (reg_wr_addr >> 7 == 0)),
    .reg_wr_wait(clock_reg_wr_wait),
    .reg_wr_ack(clock_reg_wr_ack),
    .reg_rd_addr(reg_rd_addr),
    .reg_rd_en(reg_rd_en && (reg_rd_addr >> 7 == 0)),
    .reg_rd_data(clock_reg_rd_data),
    .reg_rd_wait(clock_reg_rd_wait),
    .reg_rd_ack(clock_reg_rd_ack),

    /*
     * PTP clock
     */
    .ptp_pps(ptp_pps),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step)
);

generate

genvar n;

if (PTP_PEROUT_ENABLE) begin

    for (n = 0; n < PTP_PEROUT_COUNT; n = n + 1) begin : perout
        
        mqnic_ptp_perout ptp_perout_inst (
            .clk(clk),
            .rst(rst),

            /*
             * Register interface
             */
            .reg_wr_addr(reg_wr_addr),
            .reg_wr_data(reg_wr_data),
            .reg_wr_strb(reg_wr_strb),
            .reg_wr_en(reg_wr_en && ((reg_wr_addr >> 6) == n+2)),
            .reg_wr_wait(perout_reg_wr_wait[n]),
            .reg_wr_ack(perout_reg_wr_ack[n]),
            .reg_rd_addr(reg_rd_addr),
            .reg_rd_en(reg_rd_en && ((reg_rd_addr >> 6) == n+2)),
            .reg_rd_data(perout_reg_rd_data[n]),
            .reg_rd_wait(perout_reg_rd_wait[n]),
            .reg_rd_ack(perout_reg_rd_ack[n]),

            /*
             * PTP clock
             */
            .ptp_ts_96(ptp_ts_96),
            .ptp_ts_step(ptp_ts_step),
            .ptp_perout_locked(ptp_perout_locked[n]),
            .ptp_perout_error(ptp_perout_error[n]),
            .ptp_perout_pulse(ptp_perout_pulse[n])
        );

    end
    
end else begin
    
    assign ptp_perout_locked = 0;
    assign ptp_perout_error = 0;
    assign ptp_perout_pulse = 0;

end

endgenerate

endmodule

`resetall
