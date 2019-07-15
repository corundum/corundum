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
 * Testbench for axil_interconnect
 */
module test_axil_interconnect_4x4;

// Parameters
parameter S_COUNT = 4;
parameter M_COUNT = 4;
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;
parameter STRB_WIDTH = (DATA_WIDTH/8);
parameter M_REGIONS = 1;
parameter M_BASE_ADDR = {32'h03000000, 32'h02000000, 32'h01000000, 32'h00000000};
parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}};
parameter M_CONNECT_READ = {M_COUNT{{S_COUNT{1'b1}}}};
parameter M_CONNECT_WRITE = {M_COUNT{{S_COUNT{1'b1}}}};
parameter M_SECURE = {M_COUNT{1'b0}};

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [S_COUNT*ADDR_WIDTH-1:0] s_axil_awaddr = 0;
reg [S_COUNT*3-1:0] s_axil_awprot = 0;
reg [S_COUNT-1:0] s_axil_awvalid = 0;
reg [S_COUNT*DATA_WIDTH-1:0] s_axil_wdata = 0;
reg [S_COUNT*STRB_WIDTH-1:0] s_axil_wstrb = 0;
reg [S_COUNT-1:0] s_axil_wvalid = 0;
reg [S_COUNT-1:0] s_axil_bready = 0;
reg [S_COUNT*ADDR_WIDTH-1:0] s_axil_araddr = 0;
reg [S_COUNT*3-1:0] s_axil_arprot = 0;
reg [S_COUNT-1:0] s_axil_arvalid = 0;
reg [S_COUNT-1:0] s_axil_rready = 0;
reg [M_COUNT-1:0] m_axil_awready = 0;
reg [M_COUNT-1:0] m_axil_wready = 0;
reg [M_COUNT*2-1:0] m_axil_bresp = 0;
reg [M_COUNT-1:0] m_axil_bvalid = 0;
reg [M_COUNT-1:0] m_axil_arready = 0;
reg [M_COUNT*DATA_WIDTH-1:0] m_axil_rdata = 0;
reg [M_COUNT*2-1:0] m_axil_rresp = 0;
reg [M_COUNT-1:0] m_axil_rvalid = 0;

// Outputs
wire [S_COUNT-1:0] s_axil_awready;
wire [S_COUNT-1:0] s_axil_wready;
wire [S_COUNT*2-1:0] s_axil_bresp;
wire [S_COUNT-1:0] s_axil_bvalid;
wire [S_COUNT-1:0] s_axil_arready;
wire [S_COUNT*DATA_WIDTH-1:0] s_axil_rdata;
wire [S_COUNT*2-1:0] s_axil_rresp;
wire [S_COUNT-1:0] s_axil_rvalid;
wire [M_COUNT*ADDR_WIDTH-1:0] m_axil_awaddr;
wire [M_COUNT*3-1:0] m_axil_awprot;
wire [M_COUNT-1:0] m_axil_awvalid;
wire [M_COUNT*DATA_WIDTH-1:0] m_axil_wdata;
wire [M_COUNT*STRB_WIDTH-1:0] m_axil_wstrb;
wire [M_COUNT-1:0] m_axil_wvalid;
wire [M_COUNT-1:0] m_axil_bready;
wire [M_COUNT*ADDR_WIDTH-1:0] m_axil_araddr;
wire [M_COUNT*3-1:0] m_axil_arprot;
wire [M_COUNT-1:0] m_axil_arvalid;
wire [M_COUNT-1:0] m_axil_rready;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axil_awaddr,
        s_axil_awprot,
        s_axil_awvalid,
        s_axil_wdata,
        s_axil_wstrb,
        s_axil_wvalid,
        s_axil_bready,
        s_axil_araddr,
        s_axil_arprot,
        s_axil_arvalid,
        s_axil_rready,
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
        s_axil_awready,
        s_axil_wready,
        s_axil_bresp,
        s_axil_bvalid,
        s_axil_arready,
        s_axil_rdata,
        s_axil_rresp,
        s_axil_rvalid,
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
    $dumpfile("test_axil_interconnect_4x4.lxt");
    $dumpvars(0, test_axil_interconnect_4x4);
end

axil_interconnect #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_WIDTH(M_ADDR_WIDTH),
    .M_CONNECT_READ(M_CONNECT_READ),
    .M_CONNECT_WRITE(M_CONNECT_WRITE),
    .M_SECURE(M_SECURE)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
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
