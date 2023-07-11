// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
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
    // Structural configuration
    parameter PORTS = 1,

    // PTP configuration
    parameter PTP_TS_WIDTH = 96,

    // Queue manager configuration (interface)
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter QUEUE_INDEX_WIDTH = RX_QUEUE_INDEX_WIDTH,
    parameter CQN_WIDTH = RX_QUEUE_INDEX_WIDTH,
    parameter QUEUE_PTR_WIDTH = 16,
    parameter LOG_QUEUE_SIZE_WIDTH = 4,
    parameter LOG_BLOCK_SIZE_WIDTH = 2,

    // Descriptor management
    parameter RX_MAX_DESC_REQ = 16,
    parameter RX_DESC_FIFO_SIZE = RX_MAX_DESC_REQ*8,
    parameter DESC_SIZE = 16,
    parameter CPL_SIZE = 32,
    parameter AXIS_DESC_DATA_WIDTH = DESC_SIZE*8,
    parameter AXIS_DESC_KEEP_WIDTH = AXIS_DESC_DATA_WIDTH/8,
    parameter DESC_REQ_TAG_WIDTH = 8,
    parameter CPL_REQ_TAG_WIDTH = 8,

    // TX and RX engine configuration
    parameter RX_DESC_TABLE_SIZE = 32,
    parameter DESC_TABLE_DMA_OP_COUNT_WIDTH = 4,
    parameter RX_INDIR_TBL_ADDR_WIDTH = RX_QUEUE_INDEX_WIDTH > 8 ? 8 : RX_QUEUE_INDEX_WIDTH,

    // Interface configuration
    parameter PTP_TS_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter MAX_RX_SIZE = 9214,
    parameter RX_RAM_SIZE = 32768,

    // DMA interface configuration
    parameter DMA_ADDR_WIDTH = 64,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(RX_RAM_SIZE),
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
    parameter RAM_PIPELINE = 2,

    // Register interface configuration
    parameter REG_ADDR_WIDTH = 7,
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    parameter RB_BASE_ADDR = 0,
    parameter RB_NEXT_PTR = 0,

    // AXI lite interface configuration
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = $clog2(PORTS)+RX_INDIR_TBL_ADDR_WIDTH+2,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter AXIL_BASE_ADDR = 0,

    // Streaming interface configuration
    parameter AXIS_DATA_WIDTH = 512*2**$clog2(PORTS),
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_RX_ID_WIDTH = PORTS > 1 ? $clog2(PORTS) : 1,
    parameter AXIS_RX_DEST_WIDTH = RX_QUEUE_INDEX_WIDTH+1,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * Control register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]                    ctrl_reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]                    ctrl_reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]                    ctrl_reg_wr_strb,
    input  wire                                         ctrl_reg_wr_en,
    output wire                                         ctrl_reg_wr_wait,
    output wire                                         ctrl_reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]                    ctrl_reg_rd_addr,
    input  wire                                         ctrl_reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]                    ctrl_reg_rd_data,
    output wire                                         ctrl_reg_rd_wait,
    output wire                                         ctrl_reg_rd_ack,

    /*
     * AXI-Lite slave interface (indirection table)
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_awaddr,
    input  wire [2:0]                                   s_axil_awprot,
    input  wire                                         s_axil_awvalid,
    output wire                                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]                   s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]                   s_axil_wstrb,
    input  wire                                         s_axil_wvalid,
    output wire                                         s_axil_wready,
    output wire [1:0]                                   s_axil_bresp,
    output wire                                         s_axil_bvalid,
    input  wire                                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_araddr,
    input  wire [2:0]                                   s_axil_arprot,
    input  wire                                         s_axil_arvalid,
    output wire                                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]                   s_axil_rdata,
    output wire [1:0]                                   s_axil_rresp,
    output wire                                         s_axil_rvalid,
    input  wire                                         s_axil_rready,

    /*
     * Descriptor request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]                 m_axis_desc_req_queue,
    output wire [DESC_REQ_TAG_WIDTH-1:0]                m_axis_desc_req_tag,
    output wire                                         m_axis_desc_req_valid,
    input  wire                                         m_axis_desc_req_ready,

    /*
     * Descriptor request status input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]                 s_axis_desc_req_status_queue,
    input  wire [QUEUE_PTR_WIDTH-1:0]                   s_axis_desc_req_status_ptr,
    input  wire [CQN_WIDTH-1:0]                         s_axis_desc_req_status_cpl,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]                s_axis_desc_req_status_tag,
    input  wire                                         s_axis_desc_req_status_empty,
    input  wire                                         s_axis_desc_req_status_error,
    input  wire                                         s_axis_desc_req_status_valid,

    /*
     * Descriptor data input
     */
    input  wire [AXIS_DESC_DATA_WIDTH-1:0]              s_axis_desc_tdata,
    input  wire [AXIS_DESC_KEEP_WIDTH-1:0]              s_axis_desc_tkeep,
    input  wire                                         s_axis_desc_tvalid,
    output wire                                         s_axis_desc_tready,
    input  wire                                         s_axis_desc_tlast,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]                s_axis_desc_tid,
    input  wire                                         s_axis_desc_tuser,

    /*
     * Completion request output
     */
    output wire [CQN_WIDTH-1:0]                         m_axis_cpl_req_queue,
    output wire [CPL_REQ_TAG_WIDTH-1:0]                 m_axis_cpl_req_tag,
    output wire [CPL_SIZE*8-1:0]                        m_axis_cpl_req_data,
    output wire                                         m_axis_cpl_req_valid,
    input  wire                                         m_axis_cpl_req_ready,

    /*
     * Completion request status input
     */
    input  wire [CPL_REQ_TAG_WIDTH-1:0]                 s_axis_cpl_req_status_tag,
    input  wire                                         s_axis_cpl_req_status_full,
    input  wire                                         s_axis_cpl_req_status_error,
    input  wire                                         s_axis_cpl_req_status_valid,

    /*
     * DMA write descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_write_desc_tag,
    output wire                                         m_axis_dma_write_desc_valid,
    input  wire                                         m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_write_desc_status_error,
    input  wire                                         s_axis_dma_write_desc_status_valid,

    /*
     * RAM interface (data)
     */
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_ready,

    /*
     * Receive data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]                   s_axis_rx_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]                   s_axis_rx_tkeep,
    input  wire                                         s_axis_rx_tvalid,
    output wire                                         s_axis_rx_tready,
    input  wire                                         s_axis_rx_tlast,
    input  wire [AXIS_RX_ID_WIDTH-1:0]                  s_axis_rx_tid,
    input  wire [AXIS_RX_DEST_WIDTH-1:0]                s_axis_rx_tdest,
    input  wire [AXIS_RX_USER_WIDTH-1:0]                s_axis_rx_tuser,

    /*
     * Configuration
     */
    input  wire [DMA_CLIENT_LEN_WIDTH-1:0]              mtu
);

parameter DMA_CLIENT_TAG_WIDTH = $clog2(RX_DESC_TABLE_SIZE);
parameter DMA_CLIENT_LEN_WIDTH = DMA_LEN_WIDTH;

parameter REQ_TAG_WIDTH = $clog2(RX_DESC_TABLE_SIZE);

localparam RX_HASH_WIDTH = 32;
localparam RX_HASH_TYPE_WIDTH = 4;

localparam TUSER_HASH_OFFSET = AXIS_RX_USER_WIDTH;
localparam TUSER_HASH_TYPE_OFFSET = TUSER_HASH_OFFSET + (RX_HASH_ENABLE ? RX_HASH_WIDTH : 0);
localparam INT_AXIS_RX_USER_WIDTH = TUSER_HASH_TYPE_OFFSET + (RX_HASH_ENABLE ? RX_HASH_TYPE_WIDTH : 0);

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
    .RAM_PIPELINE(2),
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

wire [15:0]  rx_csum;
wire         rx_csum_valid;
wire         rx_csum_ready;

wire [RAM_ADDR_WIDTH-1:0]        dma_rx_desc_addr;
wire [DMA_CLIENT_LEN_WIDTH-1:0]  dma_rx_desc_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0]  dma_rx_desc_tag;
wire                             dma_rx_desc_valid;
wire                             dma_rx_desc_ready;

wire [DMA_CLIENT_LEN_WIDTH-1:0]    dma_rx_desc_status_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0]    dma_rx_desc_status_tag;
wire [AXIS_RX_ID_WIDTH-1:0]        dma_rx_desc_status_id;
wire [AXIS_RX_DEST_WIDTH-1:0]      dma_rx_desc_status_dest;
wire [INT_AXIS_RX_USER_WIDTH-1:0]  dma_rx_desc_status_user;
wire [3:0]                         dma_rx_desc_status_error;
wire                               dma_rx_desc_status_valid;

// Generate RX requests
reg rx_frame_reg = 1'b0;
reg [5:0] rx_req_cnt_reg = 0;

wire rx_req_valid = rx_req_cnt_reg != 0;
wire rx_req_ready;

always @(posedge clk) begin
    if (rx_req_valid && rx_req_ready) begin
        rx_req_cnt_reg <= rx_req_cnt_reg - 1;
    end

    if (s_axis_rx_tvalid) begin
        if (!rx_frame_reg) begin
            if (rx_req_valid && rx_req_ready) begin
                rx_req_cnt_reg <= rx_req_cnt_reg;
            end else begin
                rx_req_cnt_reg <= rx_req_cnt_reg + 1;
            end
            rx_frame_reg <= 1'b1;
        end
        if (s_axis_rx_tready && s_axis_rx_tvalid && s_axis_rx_tlast) begin
            rx_frame_reg <= 1'b0;
        end
    end

    if (rst) begin
        rx_frame_reg <= 1'b0;
        rx_req_cnt_reg <= 0;
    end
end

rx_engine #(
    .PORTS(PORTS),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_CLIENT_LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .DESC_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .CPL_REQ_TAG_WIDTH(CPL_REQ_TAG_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .DMA_CLIENT_TAG_WIDTH(DMA_CLIENT_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CQN_WIDTH(CQN_WIDTH),
    .DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
    .DESC_TABLE_DMA_OP_COUNT_WIDTH(DESC_TABLE_DMA_OP_COUNT_WIDTH),
    .INDIR_TBL_ADDR_WIDTH(RX_INDIR_TBL_ADDR_WIDTH),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .RX_BUFFER_OFFSET(0),
    .RX_BUFFER_SIZE(RX_RAM_SIZE),
    .RX_BUFFER_STEP_SIZE(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .CPL_SIZE(CPL_SIZE),
    .MAX_DESC_REQ(RX_MAX_DESC_REQ),
    .AXIS_DESC_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_DESC_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .REG_DATA_WIDTH(REG_DATA_WIDTH),
    .REG_STRB_WIDTH(REG_STRB_WIDTH),
    .RB_BASE_ADDR(RB_BASE_ADDR),
    .RB_NEXT_PTR(RB_NEXT_PTR),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .AXIL_BASE_ADDR(AXIL_BASE_ADDR),
    .AXIS_RX_ID_WIDTH(AXIS_RX_ID_WIDTH),
    .AXIS_RX_DEST_WIDTH(AXIS_RX_DEST_WIDTH),
    .AXIS_RX_USER_WIDTH(INT_AXIS_RX_USER_WIDTH)
)
rx_engine_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Control register interface
     */
    .ctrl_reg_wr_addr(ctrl_reg_wr_addr),
    .ctrl_reg_wr_data(ctrl_reg_wr_data),
    .ctrl_reg_wr_strb(ctrl_reg_wr_strb),
    .ctrl_reg_wr_en(ctrl_reg_wr_en),
    .ctrl_reg_wr_wait(ctrl_reg_wr_wait),
    .ctrl_reg_wr_ack(ctrl_reg_wr_ack),
    .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
    .ctrl_reg_rd_en(ctrl_reg_rd_en),
    .ctrl_reg_rd_data(ctrl_reg_rd_data),
    .ctrl_reg_rd_wait(ctrl_reg_rd_wait),
    .ctrl_reg_rd_ack(ctrl_reg_rd_ack),

    /*
     * AXI-Lite slave interface (indirection table)
     */
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

    /*
     * Receive request input (queue index)
     */
    .s_axis_rx_req_tag(0),
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

wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be_int;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr_int;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data_int;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_valid_int;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_ready_int;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_done_int;

dma_psdpram #(
    .SIZE(RX_RAM_SIZE),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
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

wire [AXIS_DATA_WIDTH-1:0]         rx_axis_tdata_int;
wire [AXIS_KEEP_WIDTH-1:0]         rx_axis_tkeep_int;
wire                               rx_axis_tvalid_int;
wire                               rx_axis_tready_int;
wire                               rx_axis_tlast_int;
wire [AXIS_RX_ID_WIDTH-1:0]        rx_axis_tid_int;
wire [AXIS_RX_DEST_WIDTH-1:0]      rx_axis_tdest_int;
wire [INT_AXIS_RX_USER_WIDTH-1:0]  rx_axis_tuser_int;

mqnic_ingress #(
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_ID_WIDTH(AXIS_RX_ID_WIDTH),
    .AXIS_DEST_WIDTH(AXIS_RX_DEST_WIDTH),
    .S_AXIS_USER_WIDTH(AXIS_RX_USER_WIDTH),
    .M_AXIS_USER_WIDTH(INT_AXIS_RX_USER_WIDTH),
    .MAX_RX_SIZE(MAX_RX_SIZE)
)
ingress_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Receive data input
     */
    .s_axis_tdata(s_axis_rx_tdata),
    .s_axis_tkeep(s_axis_rx_tkeep),
    .s_axis_tvalid(s_axis_rx_tvalid),
    .s_axis_tready(s_axis_rx_tready),
    .s_axis_tlast(s_axis_rx_tlast),
    .s_axis_tid(s_axis_rx_tid),
    .s_axis_tdest(s_axis_rx_tdest),
    .s_axis_tuser(s_axis_rx_tuser),

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
     * RX checksum output
     */
    .rx_csum(rx_csum),
    .rx_csum_valid(rx_csum_valid),
    .rx_csum_ready(rx_csum_ready)
);

dma_client_axis_sink #(
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(1),
    .AXIS_ID_WIDTH(AXIS_RX_ID_WIDTH),
    .AXIS_DEST_ENABLE(1),
    .AXIS_DEST_WIDTH(AXIS_RX_DEST_WIDTH),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(INT_AXIS_RX_USER_WIDTH),
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
