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
 * Ultrascale PCIe AXI DMA
 */
module pcie_us_axi_dma #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 64,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // Enable PCIe client tag
    parameter PCIE_CLIENT_TAG = 1,
    // PCIe tag count
    parameter PCIE_TAG_COUNT = 32,
    // PCIe tag field width
    parameter PCIE_TAG_WIDTH = $clog2(PCIE_TAG_COUNT),
    // Support PCIe extended tags
    parameter PCIE_EXT_TAG_ENABLE = (PCIE_TAG_COUNT>32),
    // Length field width
    parameter LEN_WIDTH = 20,
    // Tag field width
    parameter TAG_WIDTH = 8
)
(
    input  wire                            clk,
    input  wire                            rst,

    /*
     * AXI input (RC)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0] s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0] s_axis_rc_tkeep,
    input  wire                            s_axis_rc_tvalid,
    output wire                            s_axis_rc_tready,
    input  wire                            s_axis_rc_tlast,
    input  wire [74:0]                     s_axis_rc_tuser,

    /*
     * AXI output (RQ)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_rq_tkeep,
    output wire                            m_axis_rq_tvalid,
    input  wire                            m_axis_rq_tready,
    output wire                            m_axis_rq_tlast,
    output wire [59:0]                     m_axis_rq_tuser,

    /*
     * Tag input
     */
    input  wire [PCIE_TAG_WIDTH-1:0]       s_axis_pcie_rq_tag,
    input  wire                            s_axis_pcie_rq_tag_valid,

    /*
     * AXI read descriptor input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]      s_axis_read_desc_pcie_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]       s_axis_read_desc_axi_addr,
    input  wire [LEN_WIDTH-1:0]            s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]            s_axis_read_desc_tag,
    input  wire                            s_axis_read_desc_valid,
    output wire                            s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [TAG_WIDTH-1:0]            m_axis_read_desc_status_tag,
    output wire                            m_axis_read_desc_status_valid,

    /*
     * AXI write descriptor input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]      s_axis_write_desc_pcie_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]       s_axis_write_desc_axi_addr,
    input  wire [LEN_WIDTH-1:0]            s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]            s_axis_write_desc_tag,
    input  wire                            s_axis_write_desc_valid,
    output wire                            s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [TAG_WIDTH-1:0]            m_axis_write_desc_status_tag,
    output wire                            m_axis_write_desc_status_valid,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]         m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]       m_axi_awaddr,
    output wire [7:0]                      m_axi_awlen,
    output wire [2:0]                      m_axi_awsize,
    output wire [1:0]                      m_axi_awburst,
    output wire                            m_axi_awlock,
    output wire [3:0]                      m_axi_awcache,
    output wire [2:0]                      m_axi_awprot,
    output wire                            m_axi_awvalid,
    input  wire                            m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]       m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]       m_axi_wstrb,
    output wire                            m_axi_wlast,
    output wire                            m_axi_wvalid,
    input  wire                            m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]         m_axi_bid,
    input  wire [1:0]                      m_axi_bresp,
    input  wire                            m_axi_bvalid,
    output wire                            m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]         m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]       m_axi_araddr,
    output wire [7:0]                      m_axi_arlen,
    output wire [2:0]                      m_axi_arsize,
    output wire [1:0]                      m_axi_arburst,
    output wire                            m_axi_arlock,
    output wire [3:0]                      m_axi_arcache,
    output wire [2:0]                      m_axi_arprot,
    output wire                            m_axi_arvalid,
    input  wire                            m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]         m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]       m_axi_rdata,
    input  wire [1:0]                      m_axi_rresp,
    input  wire                            m_axi_rlast,
    input  wire                            m_axi_rvalid,
    output wire                            m_axi_rready,

    /*
     * Configuration
     */
    input  wire                            read_enable,
    input  wire                            write_enable,
    input  wire                            ext_tag_enable,
    input  wire [15:0]                     requester_id,
    input  wire                            requester_id_enable,
    input  wire [2:0]                      max_read_request_size,
    input  wire [2:0]                      max_payload_size,

    /*
     * Status
     */
    output wire                            status_error_cor,
    output wire                            status_error_uncor
);

wire [AXIS_PCIE_DATA_WIDTH-1:0] axis_rq_tdata_read;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] axis_rq_tkeep_read;
wire                            axis_rq_tvalid_read;
wire                            axis_rq_tready_read;
wire                            axis_rq_tlast_read;
wire [59:0]                     axis_rq_tuser_read;

pcie_us_axi_dma_rd #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_CLIENT_TAG(PCIE_CLIENT_TAG),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .PCIE_TAG_WIDTH(PCIE_TAG_WIDTH),
    .PCIE_EXT_TAG_ENABLE(PCIE_EXT_TAG_ENABLE),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
)
pcie_us_axi_dma_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI input (RC)
     */
    .s_axis_rc_tdata(s_axis_rc_tdata),
    .s_axis_rc_tkeep(s_axis_rc_tkeep),
    .s_axis_rc_tvalid(s_axis_rc_tvalid),
    .s_axis_rc_tready(s_axis_rc_tready),
    .s_axis_rc_tlast(s_axis_rc_tlast),
    .s_axis_rc_tuser(s_axis_rc_tuser),

    /*
     * AXI output (RQ)
     */
    .m_axis_rq_tdata(axis_rq_tdata_read),
    .m_axis_rq_tkeep(axis_rq_tkeep_read),
    .m_axis_rq_tvalid(axis_rq_tvalid_read),
    .m_axis_rq_tready(axis_rq_tready_read),
    .m_axis_rq_tlast(axis_rq_tlast_read),
    .m_axis_rq_tuser(axis_rq_tuser_read),

    /*
     * Tag input
     */
    .s_axis_pcie_rq_tag(s_axis_pcie_rq_tag),
    .s_axis_pcie_rq_tag_valid(s_axis_pcie_rq_tag_valid),

    /*
     * AXI read descriptor input
     */
    .s_axis_read_desc_pcie_addr(s_axis_read_desc_pcie_addr),
    .s_axis_read_desc_axi_addr(s_axis_read_desc_axi_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),

    /*
     * AXI read descriptor status output
     */
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),

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
     * Configuration
     */
    .enable(read_enable),
    .ext_tag_enable(ext_tag_enable),
    .requester_id(requester_id),
    .requester_id_enable(requester_id_enable),
    .max_read_request_size(max_read_request_size),

    /*
     * Status
     */
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor)
);

pcie_us_axi_dma_wr #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
)
pcie_us_axi_dma_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI input (RQ from read DMA)
     */
    .s_axis_rq_tdata(axis_rq_tdata_read),
    .s_axis_rq_tkeep(axis_rq_tkeep_read),
    .s_axis_rq_tvalid(axis_rq_tvalid_read),
    .s_axis_rq_tready(axis_rq_tready_read),
    .s_axis_rq_tlast(axis_rq_tlast_read),
    .s_axis_rq_tuser(axis_rq_tuser_read),

    /*
     * AXI output (RQ)
     */
    .m_axis_rq_tdata(m_axis_rq_tdata),
    .m_axis_rq_tkeep(m_axis_rq_tkeep),
    .m_axis_rq_tvalid(m_axis_rq_tvalid),
    .m_axis_rq_tready(m_axis_rq_tready),
    .m_axis_rq_tlast(m_axis_rq_tlast),
    .m_axis_rq_tuser(m_axis_rq_tuser),

    /*
     * AXI write descriptor input
     */
    .s_axis_write_desc_pcie_addr(s_axis_write_desc_pcie_addr),
    .s_axis_write_desc_axi_addr(s_axis_write_desc_axi_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),

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
    .enable(write_enable),
    .requester_id(requester_id),
    .requester_id_enable(requester_id_enable),
    .max_payload_size(max_payload_size)
);

endmodule
