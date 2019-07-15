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
 * Testbench for axi_cdma
 */
module test_axi_cdma_32_unaligned;

// Parameters
parameter AXI_DATA_WIDTH = 32;
parameter AXI_ADDR_WIDTH = 16;
parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
parameter AXI_ID_WIDTH = 8;
parameter AXI_MAX_BURST_LEN = 16;
parameter LEN_WIDTH = 20;
parameter TAG_WIDTH = 8;
parameter ENABLE_UNALIGNED = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [AXI_ADDR_WIDTH-1:0] s_axis_desc_read_addr = 0;
reg [AXI_ADDR_WIDTH-1:0] s_axis_desc_write_addr = 0;
reg [LEN_WIDTH-1:0] s_axis_desc_len = 0;
reg [TAG_WIDTH-1:0] s_axis_desc_tag = 0;
reg s_axis_desc_valid = 0;
reg m_axi_awready = 0;
reg m_axi_wready = 0;
reg [AXI_ID_WIDTH-1:0] m_axi_bid = 0;
reg [1:0] m_axi_bresp = 0;
reg m_axi_bvalid = 0;
reg m_axi_arready = 0;
reg [AXI_ID_WIDTH-1:0] m_axi_rid = 0;
reg [AXI_DATA_WIDTH-1:0] m_axi_rdata = 0;
reg [1:0] m_axi_rresp = 0;
reg m_axi_rlast = 0;
reg m_axi_rvalid = 0;
reg enable = 0;

// Outputs
wire s_axis_desc_ready;
wire [TAG_WIDTH-1:0] m_axis_desc_status_tag;
wire m_axis_desc_status_valid;
wire [AXI_ID_WIDTH-1:0] m_axi_awid;
wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
wire [7:0] m_axi_awlen;
wire [2:0] m_axi_awsize;
wire [1:0] m_axi_awburst;
wire m_axi_awlock;
wire [3:0] m_axi_awcache;
wire [2:0] m_axi_awprot;
wire m_axi_awvalid;
wire [AXI_DATA_WIDTH-1:0] m_axi_wdata;
wire [AXI_STRB_WIDTH-1:0] m_axi_wstrb;
wire m_axi_wlast;
wire m_axi_wvalid;
wire m_axi_bready;
wire [AXI_ID_WIDTH-1:0] m_axi_arid;
wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
wire [7:0] m_axi_arlen;
wire [2:0] m_axi_arsize;
wire [1:0] m_axi_arburst;
wire m_axi_arlock;
wire [3:0] m_axi_arcache;
wire [2:0] m_axi_arprot;
wire m_axi_arvalid;
wire m_axi_rready;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_desc_read_addr,
        s_axis_desc_write_addr,
        s_axis_desc_len,
        s_axis_desc_tag,
        s_axis_desc_valid,
        m_axi_awready,
        m_axi_wready,
        m_axi_bid,
        m_axi_bresp,
        m_axi_bvalid,
        m_axi_arready,
        m_axi_rid,
        m_axi_rdata,
        m_axi_rresp,
        m_axi_rlast,
        m_axi_rvalid,
        enable
    );
    $to_myhdl(
        s_axis_desc_ready,
        m_axis_desc_status_tag,
        m_axis_desc_status_valid,
        m_axi_awid,
        m_axi_awaddr,
        m_axi_awlen,
        m_axi_awsize,
        m_axi_awburst,
        m_axi_awlock,
        m_axi_awcache,
        m_axi_awprot,
        m_axi_awvalid,
        m_axi_wdata,
        m_axi_wstrb,
        m_axi_wlast,
        m_axi_wvalid,
        m_axi_bready,
        m_axi_arid,
        m_axi_araddr,
        m_axi_arlen,
        m_axi_arsize,
        m_axi_arburst,
        m_axi_arlock,
        m_axi_arcache,
        m_axi_arprot,
        m_axi_arvalid,
        m_axi_rready
    );

    // dump file
    $dumpfile("test_axi_cdma_32_unaligned.lxt");
    $dumpvars(0, test_axi_cdma_32_unaligned);
end

axi_cdma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axis_desc_read_addr(s_axis_desc_read_addr),
    .s_axis_desc_write_addr(s_axis_desc_write_addr),
    .s_axis_desc_len(s_axis_desc_len),
    .s_axis_desc_tag(s_axis_desc_tag),
    .s_axis_desc_valid(s_axis_desc_valid),
    .s_axis_desc_ready(s_axis_desc_ready),
    .m_axis_desc_status_tag(m_axis_desc_status_tag),
    .m_axis_desc_status_valid(m_axis_desc_status_valid),
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),
    .enable(enable)
);

endmodule
