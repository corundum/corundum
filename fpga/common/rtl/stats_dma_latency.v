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
module stats_dma_latency #
(
    // Counter width (bits)
    parameter COUNT_WIDTH = 16,
    // Tag width (bits)
    parameter TAG_WIDTH = 8,
    // Length field width (bits)
    parameter LEN_WIDTH = 16,
    // Status field width (bits)
    parameter STATUS_WIDTH = 4
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * Tag inputs
     */
    input  wire [TAG_WIDTH-1:0]     in_start_tag,
    input  wire [LEN_WIDTH-1:0]     in_start_len,
    input  wire                     in_start_valid,
    input  wire [TAG_WIDTH-1:0]     in_finish_tag,
    input  wire [STATUS_WIDTH-1:0]  in_finish_status,
    input  wire                     in_finish_valid,

    /*
     * Statistics increment output
     */
    output wire [TAG_WIDTH-1:0]     out_tag,
    output wire [LEN_WIDTH-1:0]     out_len,
    output wire [STATUS_WIDTH-1:0]  out_status,
    output wire [COUNT_WIDTH-1:0]   out_latency,
    output wire                     out_valid
);

reg [COUNT_WIDTH-1:0] count_reg = 0;

reg [TAG_WIDTH-1:0] out_tag_reg = 0;
reg [LEN_WIDTH-1:0] out_len_reg = 0;
reg [STATUS_WIDTH-1:0] out_status_reg = 0;
reg [COUNT_WIDTH-1:0] out_latency_reg = 0;
reg out_valid_reg = 1'b0;

assign out_tag = out_tag_reg;
assign out_len = out_len_reg;
assign out_status = out_status_reg;
assign out_latency = out_latency_reg;
assign out_valid = out_valid_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [LEN_WIDTH-1:0] len_mem_reg[2**TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [COUNT_WIDTH-1:0] count_mem_reg[2**TAG_WIDTH-1:0];

integer i;

initial begin
    for (i = 0; i < 2**TAG_WIDTH; i = i + 1) begin
        len_mem_reg[i] = 0;
        count_mem_reg[i] = 0;
    end
end

always @(posedge clk) begin
    count_reg <= count_reg + 1;

    out_tag_reg <= 0;
    out_len_reg <= 0;
    out_status_reg <= 0;
    out_latency_reg <= 0;
    out_valid_reg <= 0;

    if (in_start_valid) begin
        len_mem_reg[in_start_tag] <= in_start_len;
        count_mem_reg[in_start_tag] <= count_reg;
    end

    if (in_finish_valid) begin
        out_tag_reg <= in_finish_tag;
        out_len_reg <= len_mem_reg[in_finish_tag];
        out_status_reg <= in_finish_status;
        out_latency_reg <= count_reg - count_mem_reg[in_finish_tag];
        out_valid_reg <= 1'b1;
    end

    if (rst) begin
        count_reg <= 0;

        out_tag_reg <= 0;
        out_len_reg <= 0;
        out_status_reg <= 0;
        out_latency_reg <= 0;
        out_valid_reg <= 0;
    end
end

endmodule

`resetall
