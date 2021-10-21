/*

Copyright (c) 2021 Alex Forencich

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
 * AXI DMA interface
 */
module dma_if_axi #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // RAM segment count
    parameter RAM_SEG_COUNT = 2,
    // RAM segment data width
    parameter RAM_SEG_DATA_WIDTH = AXI_DATA_WIDTH*2/RAM_SEG_COUNT,
    // RAM segment address width
    parameter RAM_SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    // RAM select width
    parameter RAM_SEL_WIDTH = 2,
    // RAM address width
    parameter RAM_ADDR_WIDTH = RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH),
    // Length field width
    parameter LEN_WIDTH = 16,
    // Tag field width
    parameter TAG_WIDTH = 8,
    // Operation table size (read)
    parameter READ_OP_TABLE_SIZE = 2**(AXI_ID_WIDTH),
    // Operation table size (write)
    parameter WRITE_OP_TABLE_SIZE = 2**(AXI_ID_WIDTH),
    // Use AXI ID signals
    parameter USE_AXI_ID = 1
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr,
    output wire [7:0]                                   m_axi_awlen,
    output wire [2:0]                                   m_axi_awsize,
    output wire [1:0]                                   m_axi_awburst,
    output wire                                         m_axi_awlock,
    output wire [3:0]                                   m_axi_awcache,
    output wire [2:0]                                   m_axi_awprot,
    output wire                                         m_axi_awvalid,
    input  wire                                         m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]                    m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]                    m_axi_wstrb,
    output wire                                         m_axi_wlast,
    output wire                                         m_axi_wvalid,
    input  wire                                         m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_bid,
    input  wire [1:0]                                   m_axi_bresp,
    input  wire                                         m_axi_bvalid,
    output wire                                         m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr,
    output wire [7:0]                                   m_axi_arlen,
    output wire [2:0]                                   m_axi_arsize,
    output wire [1:0]                                   m_axi_arburst,
    output wire                                         m_axi_arlock,
    output wire [3:0]                                   m_axi_arcache,
    output wire [2:0]                                   m_axi_arprot,
    output wire                                         m_axi_arvalid,
    input  wire                                         m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]                    m_axi_rdata,
    input  wire [1:0]                                   m_axi_rresp,
    input  wire                                         m_axi_rlast,
    input  wire                                         m_axi_rvalid,
    output wire                                         m_axi_rready,

    /*
     * AXI read descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]                    s_axis_read_desc_axi_addr,
    input  wire [RAM_SEL_WIDTH-1:0]                     s_axis_read_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]                    s_axis_read_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                         s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]                         s_axis_read_desc_tag,
    input  wire                                         s_axis_read_desc_valid,
    output wire                                         s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                         m_axis_read_desc_status_tag,
    output wire [3:0]                                   m_axis_read_desc_status_error,
    output wire                                         m_axis_read_desc_status_valid,

    /*
     * AXI write descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]                    s_axis_write_desc_axi_addr,
    input  wire [RAM_SEL_WIDTH-1:0]                     s_axis_write_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]                    s_axis_write_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                         s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]                         s_axis_write_desc_tag,
    input  wire                                         s_axis_write_desc_valid,
    output wire                                         s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                         m_axis_write_desc_status_tag,
    output wire [3:0]                                   m_axis_write_desc_status_error,
    output wire                                         m_axis_write_desc_status_valid,

    /*
     * RAM interface
     */
    output wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_wr_cmd_sel,
    output wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    ram_wr_cmd_be,
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_wr_cmd_addr,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_wr_cmd_data,
    output wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_ready,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_wr_done,
    output wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_rd_cmd_sel,
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_ready,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_valid,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_ready,

    /*
     * Configuration
     */
    input  wire                                         read_enable,
    input  wire                                         write_enable
);

dma_if_axi_rd #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .OP_TABLE_SIZE(READ_OP_TABLE_SIZE),
    .USE_AXI_ID(USE_AXI_ID)
)
dma_if_axi_rd_inst (
    .clk(clk),
    .rst(rst),

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
     * AXI read descriptor input
     */
    .s_axis_read_desc_axi_addr(s_axis_read_desc_axi_addr),
    .s_axis_read_desc_ram_sel(s_axis_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(s_axis_read_desc_ram_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),

    /*
     * AXI read descriptor status output
     */
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_error(m_axis_read_desc_status_error),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel(ram_wr_cmd_sel),
    .ram_wr_cmd_be(ram_wr_cmd_be),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_valid(ram_wr_cmd_valid),
    .ram_wr_cmd_ready(ram_wr_cmd_ready),
    .ram_wr_done(ram_wr_done),

    /*
     * Configuration
     */
    .enable(read_enable)
);

dma_if_axi_wr #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .OP_TABLE_SIZE(WRITE_OP_TABLE_SIZE),
    .USE_AXI_ID(USE_AXI_ID)
)
dma_if_axi_wr_inst (
    .clk(clk),
    .rst(rst),

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
     * AXI write descriptor input
     */
    .s_axis_write_desc_axi_addr(s_axis_write_desc_axi_addr),
    .s_axis_write_desc_ram_sel(s_axis_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(s_axis_write_desc_ram_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_error(m_axis_write_desc_status_error),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_rd_cmd_sel(ram_rd_cmd_sel),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_valid(ram_rd_cmd_valid),
    .ram_rd_cmd_ready(ram_rd_cmd_ready),
    .ram_rd_resp_data(ram_rd_resp_data),
    .ram_rd_resp_valid(ram_rd_resp_valid),
    .ram_rd_resp_ready(ram_rd_resp_ready),

    /*
     * Configuration
     */
    .enable(write_enable)
);

endmodule

`resetall
