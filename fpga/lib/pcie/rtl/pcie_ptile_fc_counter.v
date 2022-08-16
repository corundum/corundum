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
 * P-Tile PCIe flow control counter
 */
module pcie_ptile_fc_counter #
(
    parameter WIDTH = 16,
    parameter INDEX = 0
)
(
    input  wire              clk,
    input  wire              rst,

    input  wire [WIDTH-1:0]  tx_cdts_limit,
    input  wire [2:0]        tx_cdts_limit_tdm_idx,
    input  wire [WIDTH-1:0]  fc_dec,
    output wire [WIDTH-1:0]  fc_av
);

reg [WIDTH-1:0] fc_cap_reg = 0;
reg [WIDTH-1:0] fc_limit_reg = 0;
reg [WIDTH-1:0] fc_inc_reg = 0;
reg [WIDTH-1:0] fc_av_reg = 0;

assign fc_av = fc_av_reg;

always @(posedge clk) begin
    if (tx_cdts_limit_tdm_idx == INDEX) begin
        if (!fc_cap_reg) begin
            fc_cap_reg <= tx_cdts_limit;
        end
        fc_inc_reg <= tx_cdts_limit - fc_limit_reg;
        fc_limit_reg <= tx_cdts_limit;
    end

    if ($signed({1'b0, fc_av_reg}) - $signed({1'b0, fc_dec}) + $signed({1'b0, fc_inc_reg}) < 0) begin
        fc_av_reg <= 0;
    end else if ($signed({1'b0, fc_av_reg}) - $signed({1'b0, fc_dec}) + $signed({1'b0, fc_inc_reg}) > fc_cap_reg) begin
        fc_av_reg <= fc_cap_reg;
    end else begin
        fc_av_reg <= $signed({1'b0, fc_av_reg}) - $signed({1'b0, fc_dec}) + $signed({1'b0, fc_inc_reg});
    end

    if (rst) begin
        fc_cap_reg <= 0;
        fc_limit_reg <= 0;
        fc_inc_reg <= 0;
        fc_av_reg <= 0;
    end
end

endmodule

`resetall
