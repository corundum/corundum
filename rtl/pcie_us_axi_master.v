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

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Ultrascale PCIe AXI Master
 */
module pcie_us_axi_master #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream CQ tuser signal width
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
    // PCIe AXI stream CC tuser signal width
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81,
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 64,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256
)
(
    input  wire                               clk,
    input  wire                               rst,

    /*
     * AXI input (CQ)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]    s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]    s_axis_cq_tkeep,
    input  wire                               s_axis_cq_tvalid,
    output wire                               s_axis_cq_tready,
    input  wire                               s_axis_cq_tlast,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0] s_axis_cq_tuser,

    /*
     * AXI output (CC)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep,
    output wire                               m_axis_cc_tvalid,
    input  wire                               m_axis_cc_tready,
    output wire                               m_axis_cc_tlast,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser,

    /*
     * AXI Master output
     */
    output wire [AXI_ID_WIDTH-1:0]            m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axi_awaddr,
    output wire [7:0]                         m_axi_awlen,
    output wire [2:0]                         m_axi_awsize,
    output wire [1:0]                         m_axi_awburst,
    output wire                               m_axi_awlock,
    output wire [3:0]                         m_axi_awcache,
    output wire [2:0]                         m_axi_awprot,
    output wire                               m_axi_awvalid,
    input  wire                               m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]          m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]          m_axi_wstrb,
    output wire                               m_axi_wlast,
    output wire                               m_axi_wvalid,
    input  wire                               m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]            m_axi_bid,
    input  wire [1:0]                         m_axi_bresp,
    input  wire                               m_axi_bvalid,
    output wire                               m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]            m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axi_araddr,
    output wire [7:0]                         m_axi_arlen,
    output wire [2:0]                         m_axi_arsize,
    output wire [1:0]                         m_axi_arburst,
    output wire                               m_axi_arlock,
    output wire [3:0]                         m_axi_arcache,
    output wire [2:0]                         m_axi_arprot,
    output wire                               m_axi_arvalid,
    input  wire                               m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]            m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]          m_axi_rdata,
    input  wire [1:0]                         m_axi_rresp,
    input  wire                               m_axi_rlast,
    input  wire                               m_axi_rvalid,
    output wire                               m_axi_rready,

    /*
     * Configuration
     */
    input  wire [15:0]                        completer_id,
    input  wire                               completer_id_enable,
    input  wire [2:0]                         max_payload_size,

    /*
     * Status
     */
    output wire                               status_error_cor,
    output wire                               status_error_uncor
);

wire [AXIS_PCIE_DATA_WIDTH-1:0]    axis_cq_tdata_read;
wire [AXIS_PCIE_KEEP_WIDTH-1:0]    axis_cq_tkeep_read;
wire                               axis_cq_tvalid_read;
wire                               axis_cq_tready_read;
wire                               axis_cq_tlast_read;
wire [AXIS_PCIE_CQ_USER_WIDTH-1:0] axis_cq_tuser_read;

wire [AXIS_PCIE_DATA_WIDTH-1:0]    axis_cq_tdata_write;
wire [AXIS_PCIE_KEEP_WIDTH-1:0]    axis_cq_tkeep_write;
wire                               axis_cq_tvalid_write;
wire                               axis_cq_tready_write;
wire                               axis_cq_tlast_write;
wire [AXIS_PCIE_CQ_USER_WIDTH-1:0] axis_cq_tuser_write;

wire [3:0] req_type;
wire [1:0] select;

wire [1:0] status_error_uncor_int;

pcie_us_axis_cq_demux #(
    .M_COUNT(2),
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH)
)
cq_demux_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_cq_tdata(s_axis_cq_tdata),
    .s_axis_cq_tkeep(s_axis_cq_tkeep),
    .s_axis_cq_tvalid(s_axis_cq_tvalid),
    .s_axis_cq_tready(s_axis_cq_tready),
    .s_axis_cq_tlast(s_axis_cq_tlast),
    .s_axis_cq_tuser(s_axis_cq_tuser),

    .m_axis_cq_tdata({axis_cq_tdata_write, axis_cq_tdata_read}),
    .m_axis_cq_tkeep({axis_cq_tkeep_write, axis_cq_tkeep_read}),
    .m_axis_cq_tvalid({axis_cq_tvalid_write, axis_cq_tvalid_read}),
    .m_axis_cq_tready({axis_cq_tready_write, axis_cq_tready_read}),
    .m_axis_cq_tlast({axis_cq_tlast_write, axis_cq_tlast_read}),
    .m_axis_cq_tuser({axis_cq_tuser_write, axis_cq_tuser_read}),

    .req_type(req_type),
    .target_function(),
    .bar_id(),
    .msg_code(),
    .msg_routing(),

    .enable(1'b1),
    .drop(1'b0),
    .select(select)
);

assign select[1] = req_type == 4'b0001;
assign select[0] = ~select[1];

pcie_us_axi_master_rd #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN)
)
pcie_us_axi_master_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI input (CQ)
     */
    .s_axis_cq_tdata(axis_cq_tdata_read),
    .s_axis_cq_tkeep(axis_cq_tkeep_read),
    .s_axis_cq_tvalid(axis_cq_tvalid_read),
    .s_axis_cq_tready(axis_cq_tready_read),
    .s_axis_cq_tlast(axis_cq_tlast_read),
    .s_axis_cq_tuser(axis_cq_tuser_read),

    /*
     * AXI output (CC)
     */
    .m_axis_cc_tdata(m_axis_cc_tdata),
    .m_axis_cc_tkeep(m_axis_cc_tkeep),
    .m_axis_cc_tvalid(m_axis_cc_tvalid),
    .m_axis_cc_tready(m_axis_cc_tready),
    .m_axis_cc_tlast(m_axis_cc_tlast),
    .m_axis_cc_tuser(m_axis_cc_tuser),

    /*
     * AXI master interface
     */
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

    /*
     * Configuration
     */
    .completer_id(completer_id),
    .completer_id_enable(completer_id_enable),
    .max_payload_size(max_payload_size),

    /*
     * Status
     */
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor_int[0])
);

pcie_us_axi_master_wr #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN)
)
pcie_us_axi_master_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI input (CQ)
     */
    .s_axis_cq_tdata(axis_cq_tdata_write),
    .s_axis_cq_tkeep(axis_cq_tkeep_write),
    .s_axis_cq_tvalid(axis_cq_tvalid_write),
    .s_axis_cq_tready(axis_cq_tready_write),
    .s_axis_cq_tlast(axis_cq_tlast_write),
    .s_axis_cq_tuser(axis_cq_tuser_write),

    /*
     * AXI master interface
     */
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

    /*
     * Status
     */
    .status_error_uncor(status_error_uncor_int[1])
);

pulse_merge #(
    .INPUT_WIDTH(2),
    .COUNT_WIDTH(4)
)
status_error_uncor_pm_inst (
    .clk(clk),
    .rst(rst),

    .pulse_in(status_error_uncor_int),
    .count_out(),
    .pulse_out(status_error_uncor)
);

endmodule

`resetall
