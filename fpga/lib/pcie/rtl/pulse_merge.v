/*

Copyright (c) 2018 Alex Forencich

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
 * Pulse merge module
 */
module pulse_merge #
(
    parameter INPUT_WIDTH = 2,
    parameter COUNT_WIDTH = 4
)
(
    input  wire                   clk,
    input  wire                   rst,

    input  wire [INPUT_WIDTH-1:0] pulse_in,
    output wire [COUNT_WIDTH-1:0] count_out,
    output wire                   pulse_out
);

reg [COUNT_WIDTH-1:0] count_reg = {COUNT_WIDTH{1'b0}}, count_next;
reg pulse_reg = 1'b0, pulse_next;

assign count_out = count_reg;
assign pulse_out = pulse_reg;

integer i;

always @* begin
    count_next = count_reg;
    pulse_next = count_reg > 0;

    if (count_reg > 0) begin
        count_next = count_reg - 1;
    end

    for (i = 0; i < INPUT_WIDTH; i = i + 1) begin
        count_next = count_next + pulse_in[i];
    end
end

always @(posedge clk) begin
    if (rst) begin
        count_reg <= {COUNT_WIDTH{1'b0}};
        pulse_reg <= 1'b0;
    end else begin
        count_reg <= count_next;
        pulse_reg <= pulse_next;
    end
end

endmodule

`resetall
