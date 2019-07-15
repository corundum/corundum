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
 * Testbench for axil_dp_ram
 */
module test_axil_dp_ram;

// Parameters
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 16;
parameter STRB_WIDTH = DATA_WIDTH/8;
parameter PIPELINE_OUTPUT = 0;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg a_clk = 0;
reg a_rst = 0;
reg b_clk = 0;
reg b_rst = 0;
reg [ADDR_WIDTH-1:0] s_axil_a_awaddr = 0;
reg [2:0] s_axil_a_awprot = 0;
reg s_axil_a_awvalid = 0;
reg [DATA_WIDTH-1:0] s_axil_a_wdata = 0;
reg [STRB_WIDTH-1:0] s_axil_a_wstrb = 0;
reg s_axil_a_wvalid = 0;
reg s_axil_a_bready = 0;
reg [ADDR_WIDTH-1:0] s_axil_a_araddr = 0;
reg [2:0] s_axil_a_arprot = 0;
reg s_axil_a_arvalid = 0;
reg s_axil_a_rready = 0;
reg [ADDR_WIDTH-1:0] s_axil_b_awaddr = 0;
reg [2:0] s_axil_b_awprot = 0;
reg s_axil_b_awvalid = 0;
reg [DATA_WIDTH-1:0] s_axil_b_wdata = 0;
reg [STRB_WIDTH-1:0] s_axil_b_wstrb = 0;
reg s_axil_b_wvalid = 0;
reg s_axil_b_bready = 0;
reg [ADDR_WIDTH-1:0] s_axil_b_araddr = 0;
reg [2:0] s_axil_b_arprot = 0;
reg s_axil_b_arvalid = 0;
reg s_axil_b_rready = 0;

// Outputs
wire s_axil_a_awready;
wire s_axil_a_wready;
wire [1:0] s_axil_a_bresp;
wire s_axil_a_bvalid;
wire s_axil_a_arready;
wire [DATA_WIDTH-1:0] s_axil_a_rdata;
wire [1:0] s_axil_a_rresp;
wire s_axil_a_rvalid;
wire s_axil_b_awready;
wire s_axil_b_wready;
wire [1:0] s_axil_b_bresp;
wire s_axil_b_bvalid;
wire s_axil_b_arready;
wire [DATA_WIDTH-1:0] s_axil_b_rdata;
wire [1:0] s_axil_b_rresp;
wire s_axil_b_rvalid;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        a_clk,
        a_rst,
        b_clk,
        b_rst,
        s_axil_a_awaddr,
        s_axil_a_awprot,
        s_axil_a_awvalid,
        s_axil_a_wdata,
        s_axil_a_wstrb,
        s_axil_a_wvalid,
        s_axil_a_bready,
        s_axil_a_araddr,
        s_axil_a_arprot,
        s_axil_a_arvalid,
        s_axil_a_rready,
        s_axil_b_awaddr,
        s_axil_b_awprot,
        s_axil_b_awvalid,
        s_axil_b_wdata,
        s_axil_b_wstrb,
        s_axil_b_wvalid,
        s_axil_b_bready,
        s_axil_b_araddr,
        s_axil_b_arprot,
        s_axil_b_arvalid,
        s_axil_b_rready
    );
    $to_myhdl(
        s_axil_a_awready,
        s_axil_a_wready,
        s_axil_a_bresp,
        s_axil_a_bvalid,
        s_axil_a_arready,
        s_axil_a_rdata,
        s_axil_a_rresp,
        s_axil_a_rvalid,
        s_axil_b_awready,
        s_axil_b_wready,
        s_axil_b_bresp,
        s_axil_b_bvalid,
        s_axil_b_arready,
        s_axil_b_rdata,
        s_axil_b_rresp,
        s_axil_b_rvalid
    );

    // dump file
    $dumpfile("test_axil_dp_ram.lxt");
    $dumpvars(0, test_axil_dp_ram);
end

axil_dp_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .PIPELINE_OUTPUT(PIPELINE_OUTPUT)
)
UUT (
    .a_clk(a_clk),
    .a_rst(a_rst),
    .b_clk(b_clk),
    .b_rst(b_rst),
    .s_axil_a_awaddr(s_axil_a_awaddr),
    .s_axil_a_awprot(s_axil_a_awprot),
    .s_axil_a_awvalid(s_axil_a_awvalid),
    .s_axil_a_awready(s_axil_a_awready),
    .s_axil_a_wdata(s_axil_a_wdata),
    .s_axil_a_wstrb(s_axil_a_wstrb),
    .s_axil_a_wvalid(s_axil_a_wvalid),
    .s_axil_a_wready(s_axil_a_wready),
    .s_axil_a_bresp(s_axil_a_bresp),
    .s_axil_a_bvalid(s_axil_a_bvalid),
    .s_axil_a_bready(s_axil_a_bready),
    .s_axil_a_araddr(s_axil_a_araddr),
    .s_axil_a_arprot(s_axil_a_arprot),
    .s_axil_a_arvalid(s_axil_a_arvalid),
    .s_axil_a_arready(s_axil_a_arready),
    .s_axil_a_rdata(s_axil_a_rdata),
    .s_axil_a_rresp(s_axil_a_rresp),
    .s_axil_a_rvalid(s_axil_a_rvalid),
    .s_axil_a_rready(s_axil_a_rready),
    .s_axil_b_awaddr(s_axil_b_awaddr),
    .s_axil_b_awprot(s_axil_b_awprot),
    .s_axil_b_awvalid(s_axil_b_awvalid),
    .s_axil_b_awready(s_axil_b_awready),
    .s_axil_b_wdata(s_axil_b_wdata),
    .s_axil_b_wstrb(s_axil_b_wstrb),
    .s_axil_b_wvalid(s_axil_b_wvalid),
    .s_axil_b_wready(s_axil_b_wready),
    .s_axil_b_bresp(s_axil_b_bresp),
    .s_axil_b_bvalid(s_axil_b_bvalid),
    .s_axil_b_bready(s_axil_b_bready),
    .s_axil_b_araddr(s_axil_b_araddr),
    .s_axil_b_arprot(s_axil_b_arprot),
    .s_axil_b_arvalid(s_axil_b_arvalid),
    .s_axil_b_arready(s_axil_b_arready),
    .s_axil_b_rdata(s_axil_b_rdata),
    .s_axil_b_rresp(s_axil_b_rresp),
    .s_axil_b_rvalid(s_axil_b_rvalid),
    .s_axil_b_rready(s_axil_b_rready)
);

endmodule
