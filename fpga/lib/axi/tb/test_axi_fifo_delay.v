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
 * Testbench for axi_fifo
 */
module test_axi_fifo_delay;

// Parameters
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;
parameter STRB_WIDTH = (DATA_WIDTH/8);
parameter ID_WIDTH = 8;
parameter AWUSER_ENABLE = 0;
parameter AWUSER_WIDTH = 1;
parameter WUSER_ENABLE = 0;
parameter WUSER_WIDTH = 1;
parameter BUSER_ENABLE = 0;
parameter BUSER_WIDTH = 1;
parameter ARUSER_ENABLE = 0;
parameter ARUSER_WIDTH = 1;
parameter RUSER_ENABLE = 0;
parameter RUSER_WIDTH = 1;
parameter WRITE_FIFO_DEPTH = 32;
parameter READ_FIFO_DEPTH = 32;
parameter WRITE_FIFO_DELAY = 1;
parameter READ_FIFO_DELAY = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [ID_WIDTH-1:0] s_axi_awid = 0;
reg [ADDR_WIDTH-1:0] s_axi_awaddr = 0;
reg [7:0] s_axi_awlen = 0;
reg [2:0] s_axi_awsize = 0;
reg [1:0] s_axi_awburst = 0;
reg s_axi_awlock = 0;
reg [3:0] s_axi_awcache = 0;
reg [2:0] s_axi_awprot = 0;
reg [3:0] s_axi_awqos = 0;
reg [3:0] s_axi_awregion = 0;
reg [AWUSER_WIDTH-1:0] s_axi_awuser = 0;
reg s_axi_awvalid = 0;
reg [DATA_WIDTH-1:0] s_axi_wdata = 0;
reg [STRB_WIDTH-1:0] s_axi_wstrb = 0;
reg s_axi_wlast = 0;
reg [WUSER_WIDTH-1:0] s_axi_wuser = 0;
reg s_axi_wvalid = 0;
reg s_axi_bready = 0;
reg [ID_WIDTH-1:0] s_axi_arid = 0;
reg [ADDR_WIDTH-1:0] s_axi_araddr = 0;
reg [7:0] s_axi_arlen = 0;
reg [2:0] s_axi_arsize = 0;
reg [1:0] s_axi_arburst = 0;
reg s_axi_arlock = 0;
reg [3:0] s_axi_arcache = 0;
reg [2:0] s_axi_arprot = 0;
reg [3:0] s_axi_arqos = 0;
reg [3:0] s_axi_arregion = 0;
reg [ARUSER_WIDTH-1:0] s_axi_aruser = 0;
reg s_axi_arvalid = 0;
reg s_axi_rready = 0;
reg m_axi_awready = 0;
reg m_axi_wready = 0;
reg [ID_WIDTH-1:0] m_axi_bid = 0;
reg [1:0] m_axi_bresp = 0;
reg [BUSER_WIDTH-1:0] m_axi_buser = 0;
reg m_axi_bvalid = 0;
reg m_axi_arready = 0;
reg [ID_WIDTH-1:0] m_axi_rid = 0;
reg [DATA_WIDTH-1:0] m_axi_rdata = 0;
reg [1:0] m_axi_rresp = 0;
reg m_axi_rlast = 0;
reg [RUSER_WIDTH-1:0] m_axi_ruser = 0;
reg m_axi_rvalid = 0;

// Outputs
wire s_axi_awready;
wire s_axi_wready;
wire [ID_WIDTH-1:0] s_axi_bid;
wire [1:0] s_axi_bresp;
wire [BUSER_WIDTH-1:0] s_axi_buser;
wire s_axi_bvalid;
wire s_axi_arready;
wire [ID_WIDTH-1:0] s_axi_rid;
wire [DATA_WIDTH-1:0] s_axi_rdata;
wire [1:0] s_axi_rresp;
wire s_axi_rlast;
wire [RUSER_WIDTH-1:0] s_axi_ruser;
wire s_axi_rvalid;
wire [ID_WIDTH-1:0] m_axi_awid;
wire [ADDR_WIDTH-1:0] m_axi_awaddr;
wire [7:0] m_axi_awlen;
wire [2:0] m_axi_awsize;
wire [1:0] m_axi_awburst;
wire m_axi_awlock;
wire [3:0] m_axi_awcache;
wire [2:0] m_axi_awprot;
wire [3:0] m_axi_awqos;
wire [3:0] m_axi_awregion;
wire [AWUSER_WIDTH-1:0] m_axi_awuser;
wire m_axi_awvalid;
wire [DATA_WIDTH-1:0] m_axi_wdata;
wire [STRB_WIDTH-1:0] m_axi_wstrb;
wire m_axi_wlast;
wire [WUSER_WIDTH-1:0] m_axi_wuser;
wire m_axi_wvalid;
wire m_axi_bready;
wire [ID_WIDTH-1:0] m_axi_arid;
wire [ADDR_WIDTH-1:0] m_axi_araddr;
wire [7:0] m_axi_arlen;
wire [2:0] m_axi_arsize;
wire [1:0] m_axi_arburst;
wire m_axi_arlock;
wire [3:0] m_axi_arcache;
wire [2:0] m_axi_arprot;
wire [3:0] m_axi_arqos;
wire [3:0] m_axi_arregion;
wire [ARUSER_WIDTH-1:0] m_axi_aruser;
wire m_axi_arvalid;
wire m_axi_rready;

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
        s_axi_awqos,
        s_axi_awregion,
        s_axi_awuser,
        s_axi_awvalid,
        s_axi_wdata,
        s_axi_wstrb,
        s_axi_wlast,
        s_axi_wuser,
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
        s_axi_arqos,
        s_axi_arregion,
        s_axi_aruser,
        s_axi_arvalid,
        s_axi_rready,
        m_axi_awready,
        m_axi_wready,
        m_axi_bid,
        m_axi_bresp,
        m_axi_buser,
        m_axi_bvalid,
        m_axi_arready,
        m_axi_rid,
        m_axi_rdata,
        m_axi_rresp,
        m_axi_rlast,
        m_axi_ruser,
        m_axi_rvalid
    );
    $to_myhdl(
        s_axi_awready,
        s_axi_wready,
        s_axi_bid,
        s_axi_bresp,
        s_axi_buser,
        s_axi_bvalid,
        s_axi_arready,
        s_axi_rid,
        s_axi_rdata,
        s_axi_rresp,
        s_axi_rlast,
        s_axi_ruser,
        s_axi_rvalid,
        m_axi_awid,
        m_axi_awaddr,
        m_axi_awlen,
        m_axi_awsize,
        m_axi_awburst,
        m_axi_awlock,
        m_axi_awcache,
        m_axi_awprot,
        m_axi_awqos,
        m_axi_awregion,
        m_axi_awuser,
        m_axi_awvalid,
        m_axi_wdata,
        m_axi_wstrb,
        m_axi_wlast,
        m_axi_wuser,
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
        m_axi_arqos,
        m_axi_arregion,
        m_axi_aruser,
        m_axi_arvalid,
        m_axi_rready
    );

    // dump file
    $dumpfile("test_axi_fifo_delay.lxt");
    $dumpvars(0, test_axi_fifo_delay);
end

axi_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AWUSER_ENABLE(AWUSER_ENABLE),
    .AWUSER_WIDTH(AWUSER_WIDTH),
    .WUSER_ENABLE(WUSER_ENABLE),
    .WUSER_WIDTH(WUSER_WIDTH),
    .BUSER_ENABLE(BUSER_ENABLE),
    .BUSER_WIDTH(BUSER_WIDTH),
    .ARUSER_ENABLE(ARUSER_ENABLE),
    .ARUSER_WIDTH(ARUSER_WIDTH),
    .RUSER_ENABLE(RUSER_ENABLE),
    .RUSER_WIDTH(RUSER_WIDTH),
    .WRITE_FIFO_DEPTH(WRITE_FIFO_DEPTH),
    .READ_FIFO_DEPTH(READ_FIFO_DEPTH),
    .WRITE_FIFO_DELAY(WRITE_FIFO_DELAY),
    .READ_FIFO_DELAY(READ_FIFO_DELAY)
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
    .s_axi_awqos(s_axi_awqos),
    .s_axi_awregion(s_axi_awregion),
    .s_axi_awuser(s_axi_awuser),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wuser(s_axi_wuser),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_buser(s_axi_buser),
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
    .s_axi_arqos(s_axi_arqos),
    .s_axi_arregion(s_axi_arregion),
    .s_axi_aruser(s_axi_aruser),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_ruser(s_axi_ruser),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awqos(m_axi_awqos),
    .m_axi_awregion(m_axi_awregion),
    .m_axi_awuser(m_axi_awuser),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wuser(m_axi_wuser),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_buser(m_axi_buser),
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
    .m_axi_arqos(m_axi_arqos),
    .m_axi_arregion(m_axi_arregion),
    .m_axi_aruser(m_axi_aruser),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_ruser(m_axi_ruser),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready)
);

endmodule
