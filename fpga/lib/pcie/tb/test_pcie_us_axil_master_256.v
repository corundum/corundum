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
 * Testbench for pcie_us_axil_master
 */
module test_pcie_us_axil_master_256;

// Parameters
parameter AXIS_PCIE_DATA_WIDTH = 256;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_CQ_USER_WIDTH = 85;
parameter AXIS_PCIE_CC_USER_WIDTH = 33;
parameter AXI_DATA_WIDTH = 32;
parameter AXI_ADDR_WIDTH = 64;
parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
parameter ENABLE_PARITY = 0;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [AXIS_PCIE_DATA_WIDTH-1:0] s_axis_cq_tdata = 0;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] s_axis_cq_tkeep = 0;
reg s_axis_cq_tvalid = 0;
reg s_axis_cq_tlast = 0;
reg [AXIS_PCIE_CQ_USER_WIDTH-1:0] s_axis_cq_tuser = 0;
reg m_axis_cc_tready = 0;
reg m_axil_awready = 0;
reg m_axil_wready = 0;
reg [1:0] m_axil_bresp = 0;
reg m_axil_bvalid = 0;
reg m_axil_arready = 0;
reg [AXI_DATA_WIDTH-1:0] m_axil_rdata = 0;
reg [1:0] m_axil_rresp = 0;
reg m_axil_rvalid = 0;
reg [15:0] completer_id = 0;
reg completer_id_enable = 0;

// Outputs
wire s_axis_cq_tready;
wire [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_cc_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_cc_tkeep;
wire m_axis_cc_tvalid;
wire m_axis_cc_tlast;
wire [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser;
wire [AXI_ADDR_WIDTH-1:0] m_axil_awaddr;
wire [2:0] m_axil_awprot;
wire m_axil_awvalid;
wire [AXI_DATA_WIDTH-1:0] m_axil_wdata;
wire [AXI_STRB_WIDTH-1:0] m_axil_wstrb;
wire m_axil_wvalid;
wire m_axil_bready;
wire [AXI_ADDR_WIDTH-1:0] m_axil_araddr;
wire [2:0] m_axil_arprot;
wire m_axil_arvalid;
wire m_axil_rready;
wire status_error_cor;
wire status_error_uncor;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_cq_tdata,
        s_axis_cq_tkeep,
        s_axis_cq_tvalid,
        s_axis_cq_tlast,
        s_axis_cq_tuser,
        m_axis_cc_tready,
        m_axil_awready,
        m_axil_wready,
        m_axil_bresp,
        m_axil_bvalid,
        m_axil_arready,
        m_axil_rdata,
        m_axil_rresp,
        m_axil_rvalid,
        completer_id,
        completer_id_enable
    );
    $to_myhdl(
        s_axis_cq_tready,
        m_axis_cc_tdata,
        m_axis_cc_tkeep,
        m_axis_cc_tvalid,
        m_axis_cc_tlast,
        m_axis_cc_tuser,
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
        m_axil_rready,
        status_error_cor,
        status_error_uncor
    );

    // dump file
    $dumpfile("test_pcie_us_axil_master_256.lxt");
    $dumpvars(0, test_pcie_us_axil_master_256);
end

pcie_us_axil_master #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .ENABLE_PARITY(ENABLE_PARITY)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axis_cq_tdata(s_axis_cq_tdata),
    .s_axis_cq_tkeep(s_axis_cq_tkeep),
    .s_axis_cq_tvalid(s_axis_cq_tvalid),
    .s_axis_cq_tready(s_axis_cq_tready),
    .s_axis_cq_tlast(s_axis_cq_tlast),
    .s_axis_cq_tuser(s_axis_cq_tuser),
    .m_axis_cc_tdata(m_axis_cc_tdata),
    .m_axis_cc_tkeep(m_axis_cc_tkeep),
    .m_axis_cc_tvalid(m_axis_cc_tvalid),
    .m_axis_cc_tready(m_axis_cc_tready),
    .m_axis_cc_tlast(m_axis_cc_tlast),
    .m_axis_cc_tuser(m_axis_cc_tuser),
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
    .m_axil_rready(m_axil_rready),
    .completer_id(completer_id),
    .completer_id_enable(completer_id_enable),
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor)
);

endmodule
