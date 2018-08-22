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
 * Testbench for axil_register
 */
module test_axil_register;

// Parameters
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;
parameter STRB_WIDTH = (DATA_WIDTH/8);
parameter AW_REG_TYPE = 1;
parameter W_REG_TYPE = 1;
parameter B_REG_TYPE = 1;
parameter AR_REG_TYPE = 1;
parameter R_REG_TYPE = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [ADDR_WIDTH-1:0] s_axil_awaddr = 0;
reg [2:0] s_axil_awprot = 0;
reg s_axil_awvalid = 0;
reg [DATA_WIDTH-1:0] s_axil_wdata = 0;
reg [STRB_WIDTH-1:0] s_axil_wstrb = 0;
reg s_axil_wvalid = 0;
reg s_axil_bready = 0;
reg [ADDR_WIDTH-1:0] s_axil_araddr = 0;
reg [2:0] s_axil_arprot = 0;
reg s_axil_arvalid = 0;
reg s_axil_rready = 0;
reg m_axil_awready = 0;
reg m_axil_wready = 0;
reg [1:0] m_axil_bresp = 0;
reg m_axil_bvalid = 0;
reg m_axil_arready = 0;
reg [DATA_WIDTH-1:0] m_axil_rdata = 0;
reg [1:0] m_axil_rresp = 0;
reg m_axil_rvalid = 0;

// Outputs
wire s_axil_awready;
wire s_axil_wready;
wire [1:0] s_axil_bresp;
wire s_axil_bvalid;
wire s_axil_arready;
wire [DATA_WIDTH-1:0] s_axil_rdata;
wire [1:0] s_axil_rresp;
wire s_axil_rvalid;
wire [ADDR_WIDTH-1:0] m_axil_awaddr;
wire [2:0] m_axil_awprot;
wire m_axil_awvalid;
wire [DATA_WIDTH-1:0] m_axil_wdata;
wire [STRB_WIDTH-1:0] m_axil_wstrb;
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
    $dumpfile("test_axil_register.lxt");
    $dumpvars(0, test_axil_register);
end

axil_register #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .AW_REG_TYPE(AW_REG_TYPE),
    .W_REG_TYPE(W_REG_TYPE),
    .B_REG_TYPE(B_REG_TYPE),
    .AR_REG_TYPE(AR_REG_TYPE),
    .R_REG_TYPE(R_REG_TYPE)
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
