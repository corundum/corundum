/*

Copyright (c) 2019 Alex Forencich

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
 * Testbench for axi_dp_ram
 */
module test_axi_dp_ram;

// Parameters
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 16;
parameter STRB_WIDTH = (DATA_WIDTH/8);
parameter ID_WIDTH = 8;
parameter A_PIPELINE_OUTPUT = 0;
parameter B_PIPELINE_OUTPUT = 0;
parameter A_INTERLEAVE = 0;
parameter B_INTERLEAVE = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg a_clk = 0;
reg a_rst = 0;
reg b_clk = 0;
reg b_rst = 0;
reg [ID_WIDTH-1:0] s_axi_a_awid = 0;
reg [ADDR_WIDTH-1:0] s_axi_a_awaddr = 0;
reg [7:0] s_axi_a_awlen = 0;
reg [2:0] s_axi_a_awsize = 0;
reg [1:0] s_axi_a_awburst = 0;
reg s_axi_a_awlock = 0;
reg [3:0] s_axi_a_awcache = 0;
reg [2:0] s_axi_a_awprot = 0;
reg s_axi_a_awvalid = 0;
reg [DATA_WIDTH-1:0] s_axi_a_wdata = 0;
reg [STRB_WIDTH-1:0] s_axi_a_wstrb = 0;
reg s_axi_a_wlast = 0;
reg s_axi_a_wvalid = 0;
reg s_axi_a_bready = 0;
reg [ID_WIDTH-1:0] s_axi_a_arid = 0;
reg [ADDR_WIDTH-1:0] s_axi_a_araddr = 0;
reg [7:0] s_axi_a_arlen = 0;
reg [2:0] s_axi_a_arsize = 0;
reg [1:0] s_axi_a_arburst = 0;
reg s_axi_a_arlock = 0;
reg [3:0] s_axi_a_arcache = 0;
reg [2:0] s_axi_a_arprot = 0;
reg s_axi_a_arvalid = 0;
reg s_axi_a_rready = 0;
reg [ID_WIDTH-1:0] s_axi_b_awid = 0;
reg [ADDR_WIDTH-1:0] s_axi_b_awaddr = 0;
reg [7:0] s_axi_b_awlen = 0;
reg [2:0] s_axi_b_awsize = 0;
reg [1:0] s_axi_b_awburst = 0;
reg s_axi_b_awlock = 0;
reg [3:0] s_axi_b_awcache = 0;
reg [2:0] s_axi_b_awprot = 0;
reg s_axi_b_awvalid = 0;
reg [DATA_WIDTH-1:0] s_axi_b_wdata = 0;
reg [STRB_WIDTH-1:0] s_axi_b_wstrb = 0;
reg s_axi_b_wlast = 0;
reg s_axi_b_wvalid = 0;
reg s_axi_b_bready = 0;
reg [ID_WIDTH-1:0] s_axi_b_arid = 0;
reg [ADDR_WIDTH-1:0] s_axi_b_araddr = 0;
reg [7:0] s_axi_b_arlen = 0;
reg [2:0] s_axi_b_arsize = 0;
reg [1:0] s_axi_b_arburst = 0;
reg s_axi_b_arlock = 0;
reg [3:0] s_axi_b_arcache = 0;
reg [2:0] s_axi_b_arprot = 0;
reg s_axi_b_arvalid = 0;
reg s_axi_b_rready = 0;

// Outputs
wire s_axi_a_awready;
wire s_axi_a_wready;
wire [ID_WIDTH-1:0] s_axi_a_bid;
wire [1:0] s_axi_a_bresp;
wire s_axi_a_bvalid;
wire s_axi_a_arready;
wire [ID_WIDTH-1:0] s_axi_a_rid;
wire [DATA_WIDTH-1:0] s_axi_a_rdata;
wire [1:0] s_axi_a_rresp;
wire s_axi_a_rlast;
wire s_axi_a_rvalid;
wire s_axi_b_awready;
wire s_axi_b_wready;
wire [ID_WIDTH-1:0] s_axi_b_bid;
wire [1:0] s_axi_b_bresp;
wire s_axi_b_bvalid;
wire s_axi_b_arready;
wire [ID_WIDTH-1:0] s_axi_b_rid;
wire [DATA_WIDTH-1:0] s_axi_b_rdata;
wire [1:0] s_axi_b_rresp;
wire s_axi_b_rlast;
wire s_axi_b_rvalid;

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
        s_axi_a_awid,
        s_axi_a_awaddr,
        s_axi_a_awlen,
        s_axi_a_awsize,
        s_axi_a_awburst,
        s_axi_a_awlock,
        s_axi_a_awcache,
        s_axi_a_awprot,
        s_axi_a_awvalid,
        s_axi_a_wdata,
        s_axi_a_wstrb,
        s_axi_a_wlast,
        s_axi_a_wvalid,
        s_axi_a_bready,
        s_axi_a_arid,
        s_axi_a_araddr,
        s_axi_a_arlen,
        s_axi_a_arsize,
        s_axi_a_arburst,
        s_axi_a_arlock,
        s_axi_a_arcache,
        s_axi_a_arprot,
        s_axi_a_arvalid,
        s_axi_a_rready,
        s_axi_b_awid,
        s_axi_b_awaddr,
        s_axi_b_awlen,
        s_axi_b_awsize,
        s_axi_b_awburst,
        s_axi_b_awlock,
        s_axi_b_awcache,
        s_axi_b_awprot,
        s_axi_b_awvalid,
        s_axi_b_wdata,
        s_axi_b_wstrb,
        s_axi_b_wlast,
        s_axi_b_wvalid,
        s_axi_b_bready,
        s_axi_b_arid,
        s_axi_b_araddr,
        s_axi_b_arlen,
        s_axi_b_arsize,
        s_axi_b_arburst,
        s_axi_b_arlock,
        s_axi_b_arcache,
        s_axi_b_arprot,
        s_axi_b_arvalid,
        s_axi_b_rready
    );
    $to_myhdl(
        s_axi_a_awready,
        s_axi_a_wready,
        s_axi_a_bid,
        s_axi_a_bresp,
        s_axi_a_bvalid,
        s_axi_a_arready,
        s_axi_a_rid,
        s_axi_a_rdata,
        s_axi_a_rresp,
        s_axi_a_rlast,
        s_axi_a_rvalid,
        s_axi_b_awready,
        s_axi_b_wready,
        s_axi_b_bid,
        s_axi_b_bresp,
        s_axi_b_bvalid,
        s_axi_b_arready,
        s_axi_b_rid,
        s_axi_b_rdata,
        s_axi_b_rresp,
        s_axi_b_rlast,
        s_axi_b_rvalid
    );

    // dump file
    $dumpfile("test_axi_dp_ram.lxt");
    $dumpvars(0, test_axi_dp_ram);
end

axi_dp_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .A_PIPELINE_OUTPUT(A_PIPELINE_OUTPUT),
    .B_PIPELINE_OUTPUT(B_PIPELINE_OUTPUT),
    .A_INTERLEAVE(A_INTERLEAVE),
    .B_INTERLEAVE(B_INTERLEAVE)
)
UUT (
    .a_clk(a_clk),
    .a_rst(a_rst),
    .b_clk(b_clk),
    .b_rst(b_rst),
    .s_axi_a_awid(s_axi_a_awid),
    .s_axi_a_awaddr(s_axi_a_awaddr),
    .s_axi_a_awlen(s_axi_a_awlen),
    .s_axi_a_awsize(s_axi_a_awsize),
    .s_axi_a_awburst(s_axi_a_awburst),
    .s_axi_a_awlock(s_axi_a_awlock),
    .s_axi_a_awcache(s_axi_a_awcache),
    .s_axi_a_awprot(s_axi_a_awprot),
    .s_axi_a_awvalid(s_axi_a_awvalid),
    .s_axi_a_awready(s_axi_a_awready),
    .s_axi_a_wdata(s_axi_a_wdata),
    .s_axi_a_wstrb(s_axi_a_wstrb),
    .s_axi_a_wlast(s_axi_a_wlast),
    .s_axi_a_wvalid(s_axi_a_wvalid),
    .s_axi_a_wready(s_axi_a_wready),
    .s_axi_a_bid(s_axi_a_bid),
    .s_axi_a_bresp(s_axi_a_bresp),
    .s_axi_a_bvalid(s_axi_a_bvalid),
    .s_axi_a_bready(s_axi_a_bready),
    .s_axi_a_arid(s_axi_a_arid),
    .s_axi_a_araddr(s_axi_a_araddr),
    .s_axi_a_arlen(s_axi_a_arlen),
    .s_axi_a_arsize(s_axi_a_arsize),
    .s_axi_a_arburst(s_axi_a_arburst),
    .s_axi_a_arlock(s_axi_a_arlock),
    .s_axi_a_arcache(s_axi_a_arcache),
    .s_axi_a_arprot(s_axi_a_arprot),
    .s_axi_a_arvalid(s_axi_a_arvalid),
    .s_axi_a_arready(s_axi_a_arready),
    .s_axi_a_rid(s_axi_a_rid),
    .s_axi_a_rdata(s_axi_a_rdata),
    .s_axi_a_rresp(s_axi_a_rresp),
    .s_axi_a_rlast(s_axi_a_rlast),
    .s_axi_a_rvalid(s_axi_a_rvalid),
    .s_axi_a_rready(s_axi_a_rready),
    .s_axi_b_awid(s_axi_b_awid),
    .s_axi_b_awaddr(s_axi_b_awaddr),
    .s_axi_b_awlen(s_axi_b_awlen),
    .s_axi_b_awsize(s_axi_b_awsize),
    .s_axi_b_awburst(s_axi_b_awburst),
    .s_axi_b_awlock(s_axi_b_awlock),
    .s_axi_b_awcache(s_axi_b_awcache),
    .s_axi_b_awprot(s_axi_b_awprot),
    .s_axi_b_awvalid(s_axi_b_awvalid),
    .s_axi_b_awready(s_axi_b_awready),
    .s_axi_b_wdata(s_axi_b_wdata),
    .s_axi_b_wstrb(s_axi_b_wstrb),
    .s_axi_b_wlast(s_axi_b_wlast),
    .s_axi_b_wvalid(s_axi_b_wvalid),
    .s_axi_b_wready(s_axi_b_wready),
    .s_axi_b_bid(s_axi_b_bid),
    .s_axi_b_bresp(s_axi_b_bresp),
    .s_axi_b_bvalid(s_axi_b_bvalid),
    .s_axi_b_bready(s_axi_b_bready),
    .s_axi_b_arid(s_axi_b_arid),
    .s_axi_b_araddr(s_axi_b_araddr),
    .s_axi_b_arlen(s_axi_b_arlen),
    .s_axi_b_arsize(s_axi_b_arsize),
    .s_axi_b_arburst(s_axi_b_arburst),
    .s_axi_b_arlock(s_axi_b_arlock),
    .s_axi_b_arcache(s_axi_b_arcache),
    .s_axi_b_arprot(s_axi_b_arprot),
    .s_axi_b_arvalid(s_axi_b_arvalid),
    .s_axi_b_arready(s_axi_b_arready),
    .s_axi_b_rid(s_axi_b_rid),
    .s_axi_b_rdata(s_axi_b_rdata),
    .s_axi_b_rresp(s_axi_b_rresp),
    .s_axi_b_rlast(s_axi_b_rlast),
    .s_axi_b_rvalid(s_axi_b_rvalid),
    .s_axi_b_rready(s_axi_b_rready)
);

endmodule
