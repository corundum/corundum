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

`timescale 1ns / 1ps

/*
 * Testbench for pcie_tag_manager
 */
module test_pcie_tag_manager;

// Parameters
parameter PCIE_TAG_COUNT = 256;
parameter PCIE_TAG_WIDTH = $clog2(PCIE_TAG_COUNT);
parameter PCIE_EXT_TAG_ENABLE = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg m_axis_tag_ready = 0;
reg [PCIE_TAG_WIDTH-1:0] s_axis_tag = 0;
reg s_axis_tag_valid = 0;
reg ext_tag_enable = 0;

// Outputs
wire [PCIE_TAG_WIDTH-1:0] m_axis_tag;
wire m_axis_tag_valid;
wire [PCIE_TAG_COUNT-1:0] active_tags;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        m_axis_tag_ready,
        s_axis_tag,
        s_axis_tag_valid,
        ext_tag_enable
    );
    $to_myhdl(
        m_axis_tag,
        m_axis_tag_valid,
        active_tags
    );

    // dump file
    $dumpfile("test_pcie_tag_manager.lxt");
    $dumpvars(0, test_pcie_tag_manager);
end

pcie_tag_manager #(
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .PCIE_TAG_WIDTH(PCIE_TAG_WIDTH),
    .PCIE_EXT_TAG_ENABLE(PCIE_EXT_TAG_ENABLE)
)
UUT (
    .clk(clk),
    .rst(rst),
    .m_axis_tag(m_axis_tag),
    .m_axis_tag_valid(m_axis_tag_valid),
    .m_axis_tag_ready(m_axis_tag_ready),
    .s_axis_tag(s_axis_tag),
    .s_axis_tag_valid(s_axis_tag_valid),
    .ext_tag_enable(ext_tag_enable),
    .active_tags(active_tags)
);

endmodule
