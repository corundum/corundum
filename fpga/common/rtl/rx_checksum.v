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

`timescale 1ns / 1ps

/*
 * Receive checksum offload module
 */
module rx_checksum #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8)
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

// bus width assertions
initial begin
    if (DATA_WIDTH != 256) begin
        $error("Error: AXI stream interface width must be 256 (instance %m)");
        $finish;
    end

    if (KEEP_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

reg [KEEP_WIDTH-1:0] mask_reg = 32'hffffc000;
reg [DATA_WIDTH-1:0] s_axis_tdata_masked;

reg [16:0] sum_1_1_reg = 0;
reg [16:0] sum_1_2_reg = 0;
reg [16:0] sum_1_3_reg = 0;
reg [16:0] sum_1_4_reg = 0;
reg [16:0] sum_1_5_reg = 0;
reg [16:0] sum_1_6_reg = 0;
reg [16:0] sum_1_7_reg = 0;
reg [16:0] sum_1_8_reg = 0;
reg sum_1_valid_reg = 1'b0;
reg sum_1_last_reg = 1'b0;

reg [17:0] sum_2_1_reg = 0;
reg [17:0] sum_2_2_reg = 0;
reg [17:0] sum_2_3_reg = 0;
reg [17:0] sum_2_4_reg = 0;
reg sum_2_valid_reg = 1'b0;
reg sum_2_last_reg = 1'b0;

reg [18:0] sum_3_1_reg = 0;
reg [18:0] sum_3_2_reg = 0;
reg sum_3_valid_reg = 1'b0;
reg sum_3_last_reg = 1'b0;

reg [19:0] sum_4_reg = 0;
reg sum_4_valid_reg = 1'b0;
reg sum_4_last_reg = 1'b0;

reg [20:0] sum_5_temp = 0;
reg [15:0] sum_5_reg = 0;

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

always @(posedge clk) begin
    sum_1_valid_reg <= 1'b0;
    sum_2_valid_reg <= 1'b0;
    sum_3_valid_reg <= 1'b0;
    sum_4_valid_reg <= 1'b0;
    m_axis_csum_valid_reg <= 1'b0;

    if (s_axis_tvalid) begin
        sum_1_1_reg <= {s_axis_tdata_masked[ 0*8 +: 8], s_axis_tdata_masked[ 1*8 +: 8]} + {s_axis_tdata_masked[ 2*8 +: 8], s_axis_tdata_masked[ 3*8 +: 8]};
        sum_1_2_reg <= {s_axis_tdata_masked[ 4*8 +: 8], s_axis_tdata_masked[ 5*8 +: 8]} + {s_axis_tdata_masked[ 6*8 +: 8], s_axis_tdata_masked[ 7*8 +: 8]};
        sum_1_3_reg <= {s_axis_tdata_masked[ 8*8 +: 8], s_axis_tdata_masked[ 9*8 +: 8]} + {s_axis_tdata_masked[10*8 +: 8], s_axis_tdata_masked[11*8 +: 8]};
        sum_1_4_reg <= {s_axis_tdata_masked[12*8 +: 8], s_axis_tdata_masked[13*8 +: 8]} + {s_axis_tdata_masked[14*8 +: 8], s_axis_tdata_masked[15*8 +: 8]};
        sum_1_5_reg <= {s_axis_tdata_masked[16*8 +: 8], s_axis_tdata_masked[17*8 +: 8]} + {s_axis_tdata_masked[18*8 +: 8], s_axis_tdata_masked[19*8 +: 8]};
        sum_1_6_reg <= {s_axis_tdata_masked[20*8 +: 8], s_axis_tdata_masked[21*8 +: 8]} + {s_axis_tdata_masked[22*8 +: 8], s_axis_tdata_masked[23*8 +: 8]};
        sum_1_7_reg <= {s_axis_tdata_masked[24*8 +: 8], s_axis_tdata_masked[25*8 +: 8]} + {s_axis_tdata_masked[26*8 +: 8], s_axis_tdata_masked[27*8 +: 8]};
        sum_1_8_reg <= {s_axis_tdata_masked[28*8 +: 8], s_axis_tdata_masked[29*8 +: 8]} + {s_axis_tdata_masked[30*8 +: 8], s_axis_tdata_masked[31*8 +: 8]};
        sum_1_valid_reg <= 1'b1;
        sum_1_last_reg <= s_axis_tlast;

        if (s_axis_tlast) begin
            mask_reg <= 32'hffffc000;
        end else begin
            mask_reg <= {KEEP_WIDTH{1'b1}};
        end
    end

    if (sum_1_valid_reg) begin
        sum_2_1_reg <= sum_1_1_reg + sum_1_2_reg;
        sum_2_2_reg <= sum_1_3_reg + sum_1_4_reg;
        sum_2_3_reg <= sum_1_5_reg + sum_1_6_reg;
        sum_2_4_reg <= sum_1_7_reg + sum_1_8_reg;
        sum_2_valid_reg <= 1'b1;
        sum_2_last_reg <= sum_1_last_reg;
    end

    if (sum_2_valid_reg) begin
        sum_3_1_reg <= sum_2_1_reg + sum_2_2_reg;
        sum_3_2_reg <= sum_2_3_reg + sum_2_4_reg;
        sum_3_valid_reg <= 1'b1;
        sum_3_last_reg <= sum_2_last_reg;
    end

    if (sum_3_valid_reg) begin
        sum_4_reg <= sum_3_1_reg + sum_3_2_reg;
        sum_4_valid_reg <= 1'b1;
        sum_4_last_reg <= sum_3_last_reg;
    end

    if (sum_4_valid_reg) begin
        sum_5_temp = sum_4_reg + sum_5_reg;
        sum_5_temp = sum_5_temp[15:0] + sum_5_temp[20:16];
        sum_5_temp = sum_5_temp[15:0] + sum_5_temp[16];

        if (sum_4_last_reg) begin
            m_axis_csum_reg <= sum_5_temp;
            m_axis_csum_valid_reg <= 1'b1;
            sum_5_reg <= 0;
        end else begin
            sum_5_reg <= sum_5_temp;
        end
    end

    if (rst) begin
        mask_reg <= 32'hffffc000;
        sum_1_valid_reg <= 1'b0;
        sum_2_valid_reg <= 1'b0;
        sum_3_valid_reg <= 1'b0;
        sum_4_valid_reg <= 1'b0;
        m_axis_csum_valid_reg <= 1'b0;
    end
end

endmodule
