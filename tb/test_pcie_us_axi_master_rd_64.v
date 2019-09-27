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
 * Testbench for pcie_us_axi_master_rd
 */
module test_pcie_us_axi_master_rd_64;

// Parameters
parameter AXIS_PCIE_DATA_WIDTH = 64;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_CQ_USER_WIDTH = 85;
parameter AXIS_PCIE_CC_USER_WIDTH = 33;
parameter AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH;
parameter AXI_ADDR_WIDTH = 64;
parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
parameter AXI_ID_WIDTH = 8;
parameter AXI_MAX_BURST_LEN = 256;

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
reg m_axi_arready = 0;
reg [AXI_ID_WIDTH-1:0] m_axi_rid = 0;
reg [AXI_DATA_WIDTH-1:0] m_axi_rdata = 0;
reg [1:0] m_axi_rresp = 0;
reg m_axi_rlast = 0;
reg m_axi_rvalid = 0;
reg [15:0] completer_id = 0;
reg completer_id_enable = 0;
reg [2:0] max_payload_size = 0;

// Outputs
wire s_axis_cq_tready;
wire [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_cc_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_cc_tkeep;
wire m_axis_cc_tvalid;
wire m_axis_cc_tlast;
wire [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser;
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
        m_axi_arready,
        m_axi_rid,
        m_axi_rdata,
        m_axi_rresp,
        m_axi_rlast,
        m_axi_rvalid,
        completer_id,
        completer_id_enable,
        max_payload_size
    );
    $to_myhdl(
        s_axis_cq_tready,
        m_axis_cc_tdata,
        m_axis_cc_tkeep,
        m_axis_cc_tvalid,
        m_axis_cc_tlast,
        m_axis_cc_tuser,
        m_axi_arid,
        m_axi_araddr,
        m_axi_arlen,
        m_axi_arsize,
        m_axi_arburst,
        m_axi_arlock,
        m_axi_arcache,
        m_axi_arprot,
        m_axi_arvalid,
        m_axi_rready,
        status_error_cor,
        status_error_uncor
    );

    // dump file
    $dumpfile("test_pcie_us_axi_master_rd_64.lxt");
    $dumpvars(0, test_pcie_us_axi_master_rd_64);
end

pcie_us_axi_master_rd #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN)
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
    .completer_id(completer_id),
    .completer_id_enable(completer_id_enable),
    .max_payload_size(max_payload_size),
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor)
);

endmodule
