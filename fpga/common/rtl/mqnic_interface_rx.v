/*

Copyright 2021, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC Interface RX path
 */
module mqnic_interface_rx #
(
    // Number of ports
    parameter PORTS = 1,
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA length field width
    parameter DMA_LEN_WIDTH = 16,
    // DMA tag field width
    parameter DMA_TAG_WIDTH = 8,
    // Descriptor request tag field width
    parameter DESC_REQ_TAG_WIDTH = 8,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Receive queue index width
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    // Max queue index width
    parameter QUEUE_INDEX_WIDTH = RX_QUEUE_INDEX_WIDTH,
    // Receive completion queue index width
    parameter RX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Max completion queue index width
    parameter CPL_QUEUE_INDEX_WIDTH = RX_CPL_QUEUE_INDEX_WIDTH,
    // Receive descriptor table size (number of in-flight operations)
    parameter RX_DESC_TABLE_SIZE = 16,
    // Width of descriptor table field for tracking outstanding DMA operations
    parameter DESC_TABLE_DMA_OP_COUNT_WIDTH = 4,
    // Max number of in-flight descriptor requests (transmit)
    parameter RX_MAX_DESC_REQ = 16,
    // Receive descriptor FIFO size
    parameter RX_DESC_FIFO_SIZE = RX_MAX_DESC_REQ*8,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Queue log size field width
    parameter LOG_QUEUE_SIZE_WIDTH = 4,
    // Log desc block size field width
    parameter LOG_BLOCK_SIZE_WIDTH = 2,
    // Enable PTP timestamping
    parameter PTP_TS_ENABLE = 1,
    // PTP timestamp width
    parameter PTP_TS_WIDTH = 96,
    // PTP tag width
    parameter PTP_TAG_WIDTH = 16,
    // Enable RX RSS
    parameter RX_RSS_ENABLE = 1,
    // Enable RX hashing
    parameter RX_HASH_ENABLE = 1,
    // Enable RX checksum offload
    parameter RX_CHECKSUM_ENABLE = 1,
    // DMA RAM address width
    parameter RAM_ADDR_WIDTH = 18,
    // DMA RAM segment count
    parameter SEG_COUNT = 2,
    // DMA RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // DMA RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // DMA RAM segment address width
    parameter SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(SEG_COUNT*SEG_BE_WIDTH),
    // DMA RAM pipeline stages
    parameter RAM_PIPELINE = 2,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // AXI stream tid signal width
    parameter AXIS_RX_ID_WIDTH = PORTS > 1 ? $clog2(PORTS) : 1,
    // AXI stream tdest signal width
    parameter AXIS_RX_DEST_WIDTH = RX_QUEUE_INDEX_WIDTH,
    // AXI stream tuser signal width
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    // Max receive packet size
    parameter MAX_RX_SIZE = 2048,
    // DMA RX RAM size
    parameter RX_RAM_SIZE = 8*MAX_RX_SIZE,
    // Descriptor size (in bytes)
    parameter DESC_SIZE = 16,
    // Descriptor size (in bytes)
    parameter CPL_SIZE = 32,
    // Width of AXI stream descriptor interfaces in bits
    parameter AXIS_DESC_DATA_WIDTH = DESC_SIZE*8,
    // AXI stream descriptor tkeep signal width (words per cycle)
    parameter AXIS_DESC_KEEP_WIDTH = AXIS_DESC_DATA_WIDTH/8
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * Descriptor request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]         m_axis_desc_req_queue,
    output wire [DESC_REQ_TAG_WIDTH-1:0]        m_axis_desc_req_tag,
    output wire                                 m_axis_desc_req_valid,
    input  wire                                 m_axis_desc_req_ready,

    /*
     * Descriptor request status input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]         s_axis_desc_req_status_queue,
    input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_desc_req_status_ptr,
    input  wire [CPL_QUEUE_INDEX_WIDTH-1:0]     s_axis_desc_req_status_cpl,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]        s_axis_desc_req_status_tag,
    input  wire                                 s_axis_desc_req_status_empty,
    input  wire                                 s_axis_desc_req_status_error,
    input  wire                                 s_axis_desc_req_status_valid,

    /*
     * Descriptor data input
     */
    input  wire [AXIS_DESC_DATA_WIDTH-1:0]      s_axis_desc_tdata,
    input  wire [AXIS_DESC_KEEP_WIDTH-1:0]      s_axis_desc_tkeep,
    input  wire                                 s_axis_desc_tvalid,
    output wire                                 s_axis_desc_tready,
    input  wire                                 s_axis_desc_tlast,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]        s_axis_desc_tid,
    input  wire                                 s_axis_desc_tuser,

    /*
     * Completion request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]         m_axis_cpl_req_queue,
    output wire [DESC_REQ_TAG_WIDTH-1:0]        m_axis_cpl_req_tag,
    output wire [CPL_SIZE*8-1:0]                m_axis_cpl_req_data,
    output wire                                 m_axis_cpl_req_valid,
    input  wire                                 m_axis_cpl_req_ready,

    /*
     * Completion request status input
     */
    input  wire [DESC_REQ_TAG_WIDTH-1:0]        s_axis_cpl_req_status_tag,
    input  wire                                 s_axis_cpl_req_status_full,
    input  wire                                 s_axis_cpl_req_status_error,
    input  wire                                 s_axis_cpl_req_status_valid,

    /*
     * DMA write descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]            m_axis_dma_write_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]            m_axis_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]             m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]             m_axis_dma_write_desc_tag,
    output wire                                 m_axis_dma_write_desc_valid,
    input  wire                                 m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]             s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                           s_axis_dma_write_desc_status_error,
    input  wire                                 s_axis_dma_write_desc_status_valid,

    /*
     * RAM interface (data)
     */
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data,
    output wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_ready,

    /*
     * Receive data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]           rx_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]           rx_axis_tkeep,
    input  wire                                 rx_axis_tvalid,
    output wire                                 rx_axis_tready,
    input  wire                                 rx_axis_tlast,
    input  wire [AXIS_RX_ID_WIDTH-1:0]          rx_axis_tid,
    input  wire [AXIS_RX_DEST_WIDTH-1:0]        rx_axis_tdest,
    input  wire [AXIS_RX_USER_WIDTH-1:0]        rx_axis_tuser,

    /*
     * PTP clock
     */
    input  wire [95:0]                          ptp_ts_96,
    input  wire                                 ptp_ts_step,

    /*
     * Configuration
     */
    input  wire [DMA_CLIENT_LEN_WIDTH-1:0]      mtu,
    input  wire [31:0]                          rss_mask
);

parameter DMA_CLIENT_TAG_WIDTH = $clog2(RX_DESC_TABLE_SIZE);
parameter DMA_CLIENT_LEN_WIDTH = DMA_LEN_WIDTH;

parameter REQ_TAG_WIDTH = $clog2(RX_DESC_TABLE_SIZE);

wire [AXIS_DESC_DATA_WIDTH-1:0]  rx_fifo_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]  rx_fifo_desc_tkeep;
wire                             rx_fifo_desc_tvalid;
wire                             rx_fifo_desc_tready;
wire                             rx_fifo_desc_tlast;
wire [DESC_REQ_TAG_WIDTH-1:0]    rx_fifo_desc_tid;
wire                             rx_fifo_desc_tuser;

axis_fifo #(
    .DEPTH(RX_DESC_FIFO_SIZE*DESC_SIZE),
    .DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(1),
    .ID_WIDTH(DESC_REQ_TAG_WIDTH),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .PIPELINE_OUTPUT(3),
    .FRAME_FIFO(0)
)
rx_desc_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_axis_desc_tdata),
    .s_axis_tkeep(s_axis_desc_tkeep),
    .s_axis_tvalid(s_axis_desc_tvalid),
    .s_axis_tready(s_axis_desc_tready),
    .s_axis_tlast(s_axis_desc_tlast),
    .s_axis_tid(s_axis_desc_tid),
    .s_axis_tdest(0),
    .s_axis_tuser(s_axis_desc_tuser),

    // AXI output
    .m_axis_tdata(rx_fifo_desc_tdata),
    .m_axis_tkeep(rx_fifo_desc_tkeep),
    .m_axis_tvalid(rx_fifo_desc_tvalid),
    .m_axis_tready(rx_fifo_desc_tready),
    .m_axis_tlast(rx_fifo_desc_tlast),
    .m_axis_tid(rx_fifo_desc_tid),
    .m_axis_tdest(),
    .m_axis_tuser(rx_fifo_desc_tuser),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

wire [RX_QUEUE_INDEX_WIDTH-1:0] rx_req_queue;
wire [REQ_TAG_WIDTH-1:0]        rx_req_tag;
wire                            rx_req_valid;
wire                            rx_req_ready;

wire [31:0]  rx_hash;
wire [3:0]   rx_hash_type;
wire         rx_hash_valid;
wire         rx_hash_ready;

wire [15:0]  rx_csum;
wire         rx_csum_valid;
wire         rx_csum_ready;

wire [RAM_ADDR_WIDTH-1:0]        dma_rx_desc_addr;
wire [DMA_CLIENT_LEN_WIDTH-1:0]  dma_rx_desc_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0]  dma_rx_desc_tag;
wire                             dma_rx_desc_valid;
wire                             dma_rx_desc_ready;

wire [DMA_CLIENT_LEN_WIDTH-1:0]  dma_rx_desc_status_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0]  dma_rx_desc_status_tag;
wire [AXIS_RX_ID_WIDTH-1:0]      dma_rx_desc_status_id;
wire [AXIS_RX_DEST_WIDTH-1:0]    dma_rx_desc_status_dest;
wire [AXIS_RX_USER_WIDTH-1:0]    dma_rx_desc_status_user;
wire [3:0]                       dma_rx_desc_status_error;
wire                             dma_rx_desc_status_valid;

rx_engine #(
    .PORTS(PORTS),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_CLIENT_LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .DESC_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .DMA_CLIENT_TAG_WIDTH(DMA_CLIENT_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
    .DESC_TABLE_DMA_OP_COUNT_WIDTH(DESC_TABLE_DMA_OP_COUNT_WIDTH),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .RX_BUFFER_OFFSET(0),
    .RX_BUFFER_SIZE(RX_RAM_SIZE),
    .RX_BUFFER_STEP_SIZE(SEG_COUNT*SEG_BE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .CPL_SIZE(CPL_SIZE),
    .MAX_DESC_REQ(RX_MAX_DESC_REQ),
    .AXIS_DESC_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_DESC_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .AXIS_RX_ID_WIDTH(AXIS_RX_ID_WIDTH),
    .AXIS_RX_DEST_WIDTH(AXIS_RX_DEST_WIDTH),
    .AXIS_RX_USER_WIDTH(AXIS_RX_USER_WIDTH)
)
rx_engine_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Receive request input (queue index)
     */
    .s_axis_rx_req_queue(rx_req_queue),
    .s_axis_rx_req_tag(rx_req_tag),
    .s_axis_rx_req_valid(rx_req_valid),
    .s_axis_rx_req_ready(rx_req_ready),

    /*
     * Receive request status output
     */
    .m_axis_rx_req_status_tag(),
    .m_axis_rx_req_status_len(),
    .m_axis_rx_req_status_valid(),

    /*
     * Descriptor request output
     */
    .m_axis_desc_req_queue(m_axis_desc_req_queue),
    .m_axis_desc_req_tag(m_axis_desc_req_tag),
    .m_axis_desc_req_valid(m_axis_desc_req_valid),
    .m_axis_desc_req_ready(m_axis_desc_req_ready),

    /*
     * Descriptor request status input
     */
    .s_axis_desc_req_status_queue(s_axis_desc_req_status_queue),
    .s_axis_desc_req_status_ptr(s_axis_desc_req_status_ptr),
    .s_axis_desc_req_status_cpl(s_axis_desc_req_status_cpl),
    .s_axis_desc_req_status_tag(s_axis_desc_req_status_tag),
    .s_axis_desc_req_status_empty(s_axis_desc_req_status_empty),
    .s_axis_desc_req_status_error(s_axis_desc_req_status_error),
    .s_axis_desc_req_status_valid(s_axis_desc_req_status_valid),

    /*
     * Descriptor data input
     */
    .s_axis_desc_tdata(rx_fifo_desc_tdata),
    .s_axis_desc_tkeep(rx_fifo_desc_tkeep),
    .s_axis_desc_tvalid(rx_fifo_desc_tvalid),
    .s_axis_desc_tready(rx_fifo_desc_tready),
    .s_axis_desc_tlast(rx_fifo_desc_tlast),
    .s_axis_desc_tid(rx_fifo_desc_tid),
    .s_axis_desc_tuser(rx_fifo_desc_tuser),

    /*
     * Completion request output
     */
    .m_axis_cpl_req_queue(m_axis_cpl_req_queue),
    .m_axis_cpl_req_tag(m_axis_cpl_req_tag),
    .m_axis_cpl_req_data(m_axis_cpl_req_data),
    .m_axis_cpl_req_valid(m_axis_cpl_req_valid),
    .m_axis_cpl_req_ready(m_axis_cpl_req_ready),

    /*
     * Completion request status input
     */
    .s_axis_cpl_req_status_tag(s_axis_cpl_req_status_tag),
    .s_axis_cpl_req_status_full(s_axis_cpl_req_status_full),
    .s_axis_cpl_req_status_error(s_axis_cpl_req_status_error),
    .s_axis_cpl_req_status_valid(s_axis_cpl_req_status_valid),

    /*
     * DMA write descriptor output
     */
    .m_axis_dma_write_desc_dma_addr(m_axis_dma_write_desc_dma_addr),
    .m_axis_dma_write_desc_ram_addr(m_axis_dma_write_desc_ram_addr),
    .m_axis_dma_write_desc_len(m_axis_dma_write_desc_len),
    .m_axis_dma_write_desc_tag(m_axis_dma_write_desc_tag),
    .m_axis_dma_write_desc_valid(m_axis_dma_write_desc_valid),
    .m_axis_dma_write_desc_ready(m_axis_dma_write_desc_ready),

    /*
     * DMA write descriptor status input
     */
    .s_axis_dma_write_desc_status_tag(s_axis_dma_write_desc_status_tag),
    .s_axis_dma_write_desc_status_error(s_axis_dma_write_desc_status_error),
    .s_axis_dma_write_desc_status_valid(s_axis_dma_write_desc_status_valid),

    /*
     * Receive descriptor output
     */
    .m_axis_rx_desc_addr(dma_rx_desc_addr),
    .m_axis_rx_desc_len(dma_rx_desc_len),
    .m_axis_rx_desc_tag(dma_rx_desc_tag),
    .m_axis_rx_desc_valid(dma_rx_desc_valid),
    .m_axis_rx_desc_ready(dma_rx_desc_ready),

    /*
     * Receive descriptor status input
     */
    .s_axis_rx_desc_status_len(dma_rx_desc_status_len),
    .s_axis_rx_desc_status_tag(dma_rx_desc_status_tag),
    .s_axis_rx_desc_status_id(dma_rx_desc_status_id),
    .s_axis_rx_desc_status_dest(dma_rx_desc_status_dest),
    .s_axis_rx_desc_status_user(dma_rx_desc_status_user),
    .s_axis_rx_desc_status_error(dma_rx_desc_status_error),
    .s_axis_rx_desc_status_valid(dma_rx_desc_status_valid),

    /*
     * Receive hash input
     */
    .s_axis_rx_hash(rx_hash),
    .s_axis_rx_hash_type(rx_hash_type),
    .s_axis_rx_hash_valid(rx_hash_valid),
    .s_axis_rx_hash_ready(rx_hash_ready),

    /*
     * Receive checksum input
     */
    .s_axis_rx_csum(rx_csum),
    .s_axis_rx_csum_valid(rx_csum_valid),
    .s_axis_rx_csum_ready(rx_csum_ready),

    /*
     * Configuration
     */
    .mtu(mtu),
    .enable(1'b1)
);

wire [SEG_COUNT*SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be_int;
wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr_int;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data_int;
wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_ready_int;
wire [SEG_COUNT-1:0]                 dma_ram_wr_done_int;

dma_psdpram #(
    .SIZE(RX_RAM_SIZE),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .PIPELINE(RAM_PIPELINE)
)
dma_psdpram_rx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .wr_cmd_be(dma_ram_wr_cmd_be_int),
    .wr_cmd_addr(dma_ram_wr_cmd_addr_int),
    .wr_cmd_data(dma_ram_wr_cmd_data_int),
    .wr_cmd_valid(dma_ram_wr_cmd_valid_int),
    .wr_cmd_ready(dma_ram_wr_cmd_ready_int),
    .wr_done(dma_ram_wr_done_int),

    /*
     * Read port
     */
    .rd_cmd_addr(dma_ram_rd_cmd_addr),
    .rd_cmd_valid(dma_ram_rd_cmd_valid),
    .rd_cmd_ready(dma_ram_rd_cmd_ready),
    .rd_resp_data(dma_ram_rd_resp_data),
    .rd_resp_valid(dma_ram_rd_resp_valid),
    .rd_resp_ready(dma_ram_rd_resp_ready)
);

wire [AXIS_DATA_WIDTH-1:0]     rx_axis_tdata_int;
wire [AXIS_KEEP_WIDTH-1:0]     rx_axis_tkeep_int;
wire                           rx_axis_tvalid_int;
wire                           rx_axis_tready_int;
wire                           rx_axis_tlast_int;
wire [AXIS_RX_ID_WIDTH-1:0]    rx_axis_tid_int;
wire [AXIS_RX_DEST_WIDTH-1:0]  rx_axis_tdest_int;
wire [AXIS_RX_USER_WIDTH-1:0]  rx_axis_tuser_int;

mqnic_ingress #(
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .RX_RSS_ENABLE(RX_RSS_ENABLE),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_ID_WIDTH(AXIS_RX_ID_WIDTH),
    .AXIS_DEST_WIDTH(AXIS_RX_DEST_WIDTH),
    .AXIS_USER_WIDTH(AXIS_RX_USER_WIDTH),
    .MAX_RX_SIZE(MAX_RX_SIZE)
)
ingress_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Receive data input
     */
    .s_axis_tdata(rx_axis_tdata),
    .s_axis_tkeep(rx_axis_tkeep),
    .s_axis_tvalid(rx_axis_tvalid),
    .s_axis_tready(rx_axis_tready),
    .s_axis_tlast(rx_axis_tlast),
    .s_axis_tid(rx_axis_tid),
    .s_axis_tdest(rx_axis_tdest),
    .s_axis_tuser(rx_axis_tuser),

    /*
     * Receive data output
     */
    .m_axis_tdata(rx_axis_tdata_int),
    .m_axis_tkeep(rx_axis_tkeep_int),
    .m_axis_tvalid(rx_axis_tvalid_int),
    .m_axis_tready(rx_axis_tready_int),
    .m_axis_tlast(rx_axis_tlast_int),
    .m_axis_tid(rx_axis_tid_int),
    .m_axis_tdest(rx_axis_tdest_int),
    .m_axis_tuser(rx_axis_tuser_int),

    /*
     * RX command output
     */
    .rx_req_queue(rx_req_queue),
    .rx_req_tag(rx_req_tag),
    .rx_req_valid(rx_req_valid),
    .rx_req_ready(rx_req_ready),

    /*
     * RX hash output
     */
    .rx_hash(rx_hash),
    .rx_hash_type(rx_hash_type),
    .rx_hash_valid(rx_hash_valid),
    .rx_hash_ready(rx_hash_ready),

    /*
     * RX checksum output
     */
    .rx_csum(rx_csum),
    .rx_csum_valid(rx_csum_valid),
    .rx_csum_ready(rx_csum_ready),

    /*
     * Configuration
     */
    .rss_mask(rss_mask)
);

dma_client_axis_sink #(
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(1),
    .AXIS_ID_WIDTH(AXIS_RX_ID_WIDTH),
    .AXIS_DEST_ENABLE(1),
    .AXIS_DEST_WIDTH(AXIS_RX_DEST_WIDTH),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(AXIS_RX_USER_WIDTH),
    .LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .TAG_WIDTH(DMA_CLIENT_TAG_WIDTH)
)
dma_client_axis_sink_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA write descriptor input
     */
    .s_axis_write_desc_ram_addr(dma_rx_desc_addr),
    .s_axis_write_desc_len(dma_rx_desc_len),
    .s_axis_write_desc_tag(dma_rx_desc_tag),
    .s_axis_write_desc_valid(dma_rx_desc_valid),
    .s_axis_write_desc_ready(dma_rx_desc_ready),

    /*
     * DMA write descriptor status output
     */
    .m_axis_write_desc_status_len(dma_rx_desc_status_len),
    .m_axis_write_desc_status_tag(dma_rx_desc_status_tag),
    .m_axis_write_desc_status_id(dma_rx_desc_status_id),
    .m_axis_write_desc_status_dest(dma_rx_desc_status_dest),
    .m_axis_write_desc_status_user(dma_rx_desc_status_user),
    .m_axis_write_desc_status_error(dma_rx_desc_status_error),
    .m_axis_write_desc_status_valid(dma_rx_desc_status_valid),

    /*
     * AXI stream write data input
     */
    .s_axis_write_data_tdata(rx_axis_tdata_int),
    .s_axis_write_data_tkeep(rx_axis_tkeep_int),
    .s_axis_write_data_tvalid(rx_axis_tvalid_int),
    .s_axis_write_data_tready(rx_axis_tready_int),
    .s_axis_write_data_tlast(rx_axis_tlast_int),
    .s_axis_write_data_tid(rx_axis_tid_int),
    .s_axis_write_data_tdest(rx_axis_tdest_int),
    .s_axis_write_data_tuser(rx_axis_tuser_int),

    /*
     * RAM interface
     */
    .ram_wr_cmd_be(dma_ram_wr_cmd_be_int),
    .ram_wr_cmd_addr(dma_ram_wr_cmd_addr_int),
    .ram_wr_cmd_data(dma_ram_wr_cmd_data_int),
    .ram_wr_cmd_valid(dma_ram_wr_cmd_valid_int),
    .ram_wr_cmd_ready(dma_ram_wr_cmd_ready_int),
    .ram_wr_done(dma_ram_wr_done_int),

    /*
     * Configuration
     */
    .enable(1'b1),
    .abort(1'b0)
);

endmodule

`resetall
