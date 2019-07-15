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
 * Testbench for axi_axil_adapter
 */
module test_axi_axil_adapter_32_16;

// Parameters
parameter ADDR_WIDTH = 32;
parameter AXI_DATA_WIDTH = 32;
parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
parameter AXI_ID_WIDTH = 8;
parameter AXIL_DATA_WIDTH = 16;
parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8);
parameter CONVERT_BURST = 1;
parameter CONVERT_NARROW_BURST = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [AXI_ID_WIDTH-1:0] s_axi_awid = 0;
reg [ADDR_WIDTH-1:0] s_axi_awaddr = 0;
reg [7:0] s_axi_awlen = 0;
reg [2:0] s_axi_awsize = 0;
reg [1:0] s_axi_awburst = 0;
reg s_axi_awlock = 0;
reg [3:0] s_axi_awcache = 0;
reg [2:0] s_axi_awprot = 0;
reg s_axi_awvalid = 0;
reg [AXI_DATA_WIDTH-1:0] s_axi_wdata = 0;
reg [AXI_STRB_WIDTH-1:0] s_axi_wstrb = 0;
reg s_axi_wlast = 0;
reg s_axi_wvalid = 0;
reg s_axi_bready = 0;
reg [AXI_ID_WIDTH-1:0] s_axi_arid = 0;
reg [ADDR_WIDTH-1:0] s_axi_araddr = 0;
reg [7:0] s_axi_arlen = 0;
reg [2:0] s_axi_arsize = 0;
reg [1:0] s_axi_arburst = 0;
reg s_axi_arlock = 0;
reg [3:0] s_axi_arcache = 0;
reg [2:0] s_axi_arprot = 0;
reg s_axi_arvalid = 0;
reg s_axi_rready = 0;
reg m_axil_awready = 0;
reg m_axil_wready = 0;
reg [1:0] m_axil_bresp = 0;
reg m_axil_bvalid = 0;
reg m_axil_arready = 0;
reg [AXIL_DATA_WIDTH-1:0] m_axil_rdata = 0;
reg [1:0] m_axil_rresp = 0;
reg m_axil_rvalid = 0;

// Outputs
wire s_axi_awready;
wire s_axi_wready;
wire [AXI_ID_WIDTH-1:0] s_axi_bid;
wire [1:0] s_axi_bresp;
wire s_axi_bvalid;
wire s_axi_arready;
wire [AXI_ID_WIDTH-1:0] s_axi_rid;
wire [AXI_DATA_WIDTH-1:0] s_axi_rdata;
wire [1:0] s_axi_rresp;
wire s_axi_rlast;
wire s_axi_rvalid;
wire [ADDR_WIDTH-1:0] m_axil_awaddr;
wire [2:0] m_axil_awprot;
wire m_axil_awvalid;
wire [AXIL_DATA_WIDTH-1:0] m_axil_wdata;
wire [AXIL_STRB_WIDTH-1:0] m_axil_wstrb;
wire m_axil_wvalid;
wire m_axil_bready;
wire [ADDR_WIDTH-1:0] m_axil_araddr;
wire [2:0] m_axil_arprot;
wire m_axil_arvalid;
wire m_axil_rready;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axi_awid,
        s_axi_awaddr,
        s_axi_awlen,
        s_axi_awsize,
        s_axi_awburst,
        s_axi_awlock,
        s_axi_awcache,
        s_axi_awprot,
        s_axi_awvalid,
        s_axi_wdata,
        s_axi_wstrb,
        s_axi_wlast,
        s_axi_wvalid,
        s_axi_bready,
        s_axi_arid,
        s_axi_araddr,
        s_axi_arlen,
        s_axi_arsize,
        s_axi_arburst,
        s_axi_arlock,
        s_axi_arcache,
        s_axi_arprot,
        s_axi_arvalid,
        s_axi_rready,
        m_axil_awready,
        m_axil_wready,
        m_axil_bresp,
        m_axil_bvalid,
        m_axil_arready,
        m_axil_rdata,
        m_axil_rresp,
        m_axil_rvalid
    );
    $to_myhdl(
        s_axi_awready,
        s_axi_wready,
        s_axi_bid,
        s_axi_bresp,
        s_axi_bvalid,
        s_axi_arready,
        s_axi_rid,
        s_axi_rdata,
        s_axi_rresp,
        s_axi_rlast,
        s_axi_rvalid,
        m_axil_awaddr,
        m_axil_awprot,
        m_axil_awvalid,
        m_axil_wdata,
        m_axil_wstrb,
        m_axil_wvalid,
        m_axil_bready,
        m_axil_araddr,
        m_axil_arprot,
        m_axil_arvalid,
        m_axil_rready
    );

    // dump file
    $dumpfile("test_axi_axil_adapter_32_16.lxt");
    $dumpvars(0, test_axi_axil_adapter_32_16);
end

axi_axil_adapter #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .CONVERT_BURST(CONVERT_BURST),
    .CONVERT_NARROW_BURST(CONVERT_NARROW_BURST)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .m_axil_awaddr(m_axil_awaddr),
    .m_axil_awprot(m_axil_awprot),
    .m_axil_awvalid(m_axil_awvalid),
    .m_axil_awready(m_axil_awready),
    .m_axil_wdata(m_axil_wdata),
    .m_axil_wstrb(m_axil_wstrb),
    .m_axil_wvalid(m_axil_wvalid),
    .m_axil_wready(m_axil_wready),
    .m_axil_bresp(m_axil_bresp),
    .m_axil_bvalid(m_axil_bvalid),
    .m_axil_bready(m_axil_bready),
    .m_axil_araddr(m_axil_araddr),
    .m_axil_arprot(m_axil_arprot),
    .m_axil_arvalid(m_axil_arvalid),
    .m_axil_arready(m_axil_arready),
    .m_axil_rdata(m_axil_rdata),
    .m_axil_rresp(m_axil_rresp),
    .m_axil_rvalid(m_axil_rvalid),
    .m_axil_rready(m_axil_rready)
);

endmodule
