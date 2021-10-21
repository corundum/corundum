/*

Copyright 2019, The Regents of the University of California.
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
 * Receive checksum offload module
 */
module rx_checksum #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    // Checksum start offset
    parameter START_OFFSET = 14
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    input  wire                   s_axis_tlast,

    /*
     * Checksum output
     */
    output wire [15:0]            m_axis_csum,
    output wire                   m_axis_csum_valid
);

parameter LEVELS = $clog2(DATA_WIDTH/8);
parameter OFFSET_WIDTH = START_OFFSET/KEEP_WIDTH > 1 ? $clog2(START_OFFSET/KEEP_WIDTH) : 1;

// bus width assertions
initial begin
    if (KEEP_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

reg [OFFSET_WIDTH-1:0] offset_reg = START_OFFSET/KEEP_WIDTH;
reg [KEEP_WIDTH-1:0] mask_reg = {KEEP_WIDTH{1'b1}} << START_OFFSET;
reg [DATA_WIDTH-1:0] s_axis_tdata_masked;

reg [DATA_WIDTH-1:0] sum_reg[LEVELS-2:0];
reg [LEVELS-2:0] sum_valid_reg = 0;
reg [LEVELS-2:0] sum_last_reg = 0;

reg [16+LEVELS-1:0] sum_acc_temp = 0;
reg [15:0] sum_acc_reg = 0;

reg [15:0] m_axis_csum_reg = 0;
reg m_axis_csum_valid_reg = 1'b0;

assign m_axis_csum = m_axis_csum_reg;
assign m_axis_csum_valid = m_axis_csum_valid_reg;

// Mask input data
integer j;

always @* begin
    for (j = 0; j < KEEP_WIDTH; j = j + 1) begin
        s_axis_tdata_masked[j*8 +: 8] = (s_axis_tkeep[j] && mask_reg[j]) ? s_axis_tdata[j*8 +: 8] : 8'd0;
    end
end

integer i;

always @(posedge clk) begin
    sum_valid_reg[0] <= 1'b0;

    if (s_axis_tvalid) begin
        for (i = 0; i < DATA_WIDTH/8/4; i = i + 1) begin
            sum_reg[0][i*17 +: 17] <= {s_axis_tdata_masked[(4*i+0)*8 +: 8], s_axis_tdata_masked[(4*i+1)*8 +: 8]} + {s_axis_tdata_masked[(4*i+2)*8 +: 8], s_axis_tdata_masked[(4*i+3)*8 +: 8]};
        end
        sum_valid_reg[0] <= 1'b1;
        sum_last_reg[0] <= s_axis_tlast;

        if (s_axis_tlast) begin
            offset_reg <= START_OFFSET/KEEP_WIDTH;
            mask_reg <= {KEEP_WIDTH{1'b1}} << START_OFFSET;
        end else if (START_OFFSET < KEEP_WIDTH || offset_reg == 0) begin
            mask_reg <= {KEEP_WIDTH{1'b1}};
        end else begin
            offset_reg <= offset_reg - 1;
            if (offset_reg == 1) begin
                mask_reg <= {KEEP_WIDTH{1'b1}} << (START_OFFSET%KEEP_WIDTH);
            end else begin
                mask_reg <= {KEEP_WIDTH{1'b0}};
            end
        end
    end

    if (rst) begin
        offset_reg <= START_OFFSET/KEEP_WIDTH;
        mask_reg <= {KEEP_WIDTH{1'b1}} << START_OFFSET;
        sum_valid_reg[0] <= 1'b0;
    end
end

generate

    genvar l;

    for (l = 1; l < LEVELS-1; l = l + 1) begin

        always @(posedge clk) begin
            sum_valid_reg[l] <= 1'b0;

            if (sum_valid_reg[l-1]) begin
                for (i = 0; i < DATA_WIDTH/8/4/2**l; i = i + 1) begin
                    sum_reg[l][i*(17+l) +: (17+l)] <= sum_reg[l-1][(i*2+0)*(17+l-1) +: (17+l-1)] + sum_reg[l-1][(i*2+1)*(17+l-1) +: (17+l-1)];
                end
                sum_valid_reg[l] <= 1'b1;
                sum_last_reg[l] <= sum_last_reg[l-1];
            end

            if (rst) begin
                sum_valid_reg[l] <= 1'b0;
            end
        end

    end

endgenerate

always @(posedge clk) begin
    m_axis_csum_valid_reg <= 1'b0;

    if (sum_valid_reg[LEVELS-2]) begin
        sum_acc_temp = sum_reg[LEVELS-2][16+LEVELS-1-1:0] + sum_acc_reg;
        sum_acc_temp = sum_acc_temp[15:0] + (sum_acc_temp >> 16);
        sum_acc_temp = sum_acc_temp[15:0] + sum_acc_temp[16];

        if (sum_last_reg[LEVELS-2]) begin
            m_axis_csum_reg <= sum_acc_temp;
            m_axis_csum_valid_reg <= 1'b1;
            sum_acc_reg <= 0;
        end else begin
            sum_acc_reg <= sum_acc_temp;
        end
    end

    if (rst) begin
        m_axis_csum_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
