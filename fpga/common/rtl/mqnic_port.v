/*

Copyright 2019, The Regents of the University of California.
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
 * NIC Port
 */
module mqnic_port #
(
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA length field width
    parameter DMA_LEN_WIDTH = 16,
    // DMA tag field width
    parameter DMA_TAG_WIDTH = 8,
    // Request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Descriptor request tag field width
    parameter DESC_REQ_TAG_WIDTH = 8,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Transmit queue index width
    parameter TX_QUEUE_INDEX_WIDTH = 8,
    // Receive queue index width
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    // Max queue index width
    parameter QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH > RX_QUEUE_INDEX_WIDTH ? TX_QUEUE_INDEX_WIDTH : RX_QUEUE_INDEX_WIDTH,
    // Transmit completion queue index width
    parameter TX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Receive completion queue index width
    parameter RX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Max completion queue index width
    parameter CPL_QUEUE_INDEX_WIDTH = TX_CPL_QUEUE_INDEX_WIDTH > RX_CPL_QUEUE_INDEX_WIDTH ? TX_CPL_QUEUE_INDEX_WIDTH : RX_CPL_QUEUE_INDEX_WIDTH,
    // Transmit descriptor table size (number of in-flight operations)
    parameter TX_DESC_TABLE_SIZE = 16,
    // Receive descriptor table size (number of in-flight operations)
    parameter RX_DESC_TABLE_SIZE = 16,
    // Width of descriptor table field for tracking outstanding DMA operations
    parameter DESC_TABLE_DMA_OP_COUNT_WIDTH = 4,
    // Max number of in-flight descriptor requests (transmit)
    parameter TX_MAX_DESC_REQ = 16,
    // Transmit descriptor FIFO size
    parameter TX_DESC_FIFO_SIZE = TX_MAX_DESC_REQ*8,
    // Max number of in-flight descriptor requests (transmit)
    parameter RX_MAX_DESC_REQ = 16,
    // Receive descriptor FIFO size
    parameter RX_DESC_FIFO_SIZE = RX_MAX_DESC_REQ*8,
    // Scheduler operation table size
    parameter TX_SCHEDULER_OP_TABLE_SIZE = 32,
    // Scheduler pipeline setting
    parameter TX_SCHEDULER_PIPELINE = 3,
    // Scheduler TDMA index width
    parameter TDMA_INDEX_WIDTH = 8,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Enable PTP timestamping
    parameter PTP_TS_ENABLE = 1,
    // PTP timestamp width
    parameter PTP_TS_WIDTH = 96,
    // Enable TX checksum offload
    parameter TX_CHECKSUM_ENABLE = 1,
    // Enable RX RSS
    parameter RX_RSS_ENABLE = 1,
    // Enable RX hashing
    parameter RX_HASH_ENABLE = 1,
    // Enable RX checksum offload
    parameter RX_CHECKSUM_ENABLE = 1,
    // Width of control register interface address in bits
    parameter REG_ADDR_WIDTH = 16,
    // Width of control register interface data in bits
    parameter REG_DATA_WIDTH = 32,
    // Width of control register interface strb
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Offset to AXI lite interface
    parameter AXIL_OFFSET = 0,
    // DMA RAM segment count
    parameter SEG_COUNT = 2,
    // DMA RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // DMA RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // DMA RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // DMA RAM address width
    parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH),
    // DMA RAM pipeline stages
    parameter RAM_PIPELINE = 2,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // Max transmit packet size
    parameter MAX_TX_SIZE = 2048,
    // Max receive packet size
    parameter MAX_RX_SIZE = 2048,
    // DMA TX RAM size
    parameter TX_RAM_SIZE = 8*MAX_TX_SIZE,
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
    output wire [0:0]                           m_axis_desc_req_sel,
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
    output wire [0:0]                           m_axis_cpl_req_sel,
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
     * TX doorbell input
     */
    input  wire [TX_QUEUE_INDEX_WIDTH-1:0]      s_axis_tx_doorbell_queue,
    input  wire                                 s_axis_tx_doorbell_valid,

    /*
     * DMA read descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]            m_axis_dma_read_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]            m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]             m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]             m_axis_dma_read_desc_tag,
    output wire                                 m_axis_dma_read_desc_valid,
    input  wire                                 m_axis_dma_read_desc_ready,

    /*
     * DMA read descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]             s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                           s_axis_dma_read_desc_status_error,
    input  wire                                 s_axis_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]            m_axis_dma_write_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]            m_axis_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]             m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]             m_axis_dma_write_desc_tag,
    output wire                                 m_axis_dma_write_desc_valid,
    input  wire                                 m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]             s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                           s_axis_dma_write_desc_status_error,
    input  wire                                 s_axis_dma_write_desc_status_valid,

    /*
     * Control register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]            ctrl_reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]            ctrl_reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]            ctrl_reg_wr_strb,
    input  wire                                 ctrl_reg_wr_en,
    output wire                                 ctrl_reg_wr_wait,
    output wire                                 ctrl_reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]            ctrl_reg_rd_addr,
    input  wire                                 ctrl_reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]            ctrl_reg_rd_data,
    output wire                                 ctrl_reg_rd_wait,
    output wire                                 ctrl_reg_rd_ack,

    /*
     * AXI-Lite slave interface (schedulers)
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]           s_axil_awaddr,
    input  wire [2:0]                           s_axil_awprot,
    input  wire                                 s_axil_awvalid,
    output wire                                 s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]           s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]           s_axil_wstrb,
    input  wire                                 s_axil_wvalid,
    output wire                                 s_axil_wready,
    output wire [1:0]                           s_axil_bresp,
    output wire                                 s_axil_bvalid,
    input  wire                                 s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]           s_axil_araddr,
    input  wire [2:0]                           s_axil_arprot,
    input  wire                                 s_axil_arvalid,
    output wire                                 s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]           s_axil_rdata,
    output wire [1:0]                           s_axil_rresp,
    output wire                                 s_axil_rvalid,
    input  wire                                 s_axil_rready,

    /*
     * RAM interface
     */
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                 dma_ram_wr_done,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data,
    output wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_ready,

    /*
     * Transmit data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]           tx_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]           tx_axis_tkeep,
    output wire                                 tx_axis_tvalid,
    input  wire                                 tx_axis_tready,
    output wire                                 tx_axis_tlast,
    output wire                                 tx_axis_tuser,

    /*
     * Transmit PTP timestamp input
     */
    input  wire [PTP_TS_WIDTH-1:0]              s_axis_tx_ptp_ts_96,
    input  wire                                 s_axis_tx_ptp_ts_valid,
    output wire                                 s_axis_tx_ptp_ts_ready,

    /*
     * Receive data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]           rx_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]           rx_axis_tkeep,
    input  wire                                 rx_axis_tvalid,
    output wire                                 rx_axis_tready,
    input  wire                                 rx_axis_tlast,
    input  wire                                 rx_axis_tuser,

    /*
     * Receive PTP timestamp input
     */
    input  wire [PTP_TS_WIDTH-1:0]              s_axis_rx_ptp_ts_96,
    input  wire                                 s_axis_rx_ptp_ts_valid,
    output wire                                 s_axis_rx_ptp_ts_ready,

    /*
     * PTP clock
     */
    input  wire [PTP_TS_WIDTH-1:0]              ptp_ts_96,
    input  wire                                 ptp_ts_step
);

parameter DMA_CLIENT_TAG_WIDTH = $clog2(TX_DESC_TABLE_SIZE > RX_DESC_TABLE_SIZE ? TX_DESC_TABLE_SIZE : RX_DESC_TABLE_SIZE);
parameter DMA_CLIENT_LEN_WIDTH = DMA_LEN_WIDTH;

parameter DESC_REQ_TAG_WIDTH_INT = DESC_REQ_TAG_WIDTH - $clog2(2);

// Checksumming and RSS
wire [AXIS_DATA_WIDTH-1:0] rx_axis_tdata_int;
wire [AXIS_KEEP_WIDTH-1:0] rx_axis_tkeep_int;
wire                       rx_axis_tvalid_int;
wire                       rx_axis_tready_int;
wire                       rx_axis_tlast_int;
wire                       rx_axis_tuser_int;

wire [AXIS_DATA_WIDTH-1:0] tx_axis_tdata_int;
wire [AXIS_KEEP_WIDTH-1:0] tx_axis_tkeep_int;
wire                       tx_axis_tvalid_int;
wire                       tx_axis_tready_int;
wire                       tx_axis_tlast_int;
wire                       tx_axis_tuser_int;

// Descriptor and completion
wire [0:0]                           rx_desc_req_sel = 1'b1;
wire [QUEUE_INDEX_WIDTH-1:0]         rx_desc_req_queue;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    rx_desc_req_tag;
wire                                 rx_desc_req_valid;
wire                                 rx_desc_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]         rx_desc_req_status_queue;
wire [QUEUE_PTR_WIDTH-1:0]           rx_desc_req_status_ptr;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]     rx_desc_req_status_cpl;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    rx_desc_req_status_tag;
wire                                 rx_desc_req_status_empty;
wire                                 rx_desc_req_status_error;
wire                                 rx_desc_req_status_valid;

wire [AXIS_DESC_DATA_WIDTH-1:0]      rx_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]      rx_desc_tkeep;
wire                                 rx_desc_tvalid;
wire                                 rx_desc_tready;
wire                                 rx_desc_tlast;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    rx_desc_tid;
wire                                 rx_desc_tuser;

wire [AXIS_DESC_DATA_WIDTH-1:0]      rx_fifo_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]      rx_fifo_desc_tkeep;
wire                                 rx_fifo_desc_tvalid;
wire                                 rx_fifo_desc_tready;
wire                                 rx_fifo_desc_tlast;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    rx_fifo_desc_tid;
wire                                 rx_fifo_desc_tuser;

wire [0:0]                           tx_desc_req_sel = 1'b0;
wire [QUEUE_INDEX_WIDTH-1:0]         tx_desc_req_queue;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    tx_desc_req_tag;
wire                                 tx_desc_req_valid;
wire                                 tx_desc_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]         tx_desc_req_status_queue;
wire [QUEUE_PTR_WIDTH-1:0]           tx_desc_req_status_ptr;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]     tx_desc_req_status_cpl;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    tx_desc_req_status_tag;
wire                                 tx_desc_req_status_empty;
wire                                 tx_desc_req_status_error;
wire                                 tx_desc_req_status_valid;

wire [AXIS_DESC_DATA_WIDTH-1:0]      tx_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]      tx_desc_tkeep;
wire                                 tx_desc_tvalid;
wire                                 tx_desc_tready;
wire                                 tx_desc_tlast;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    tx_desc_tid;
wire                                 tx_desc_tuser;

wire [AXIS_DESC_DATA_WIDTH-1:0]      tx_fifo_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]      tx_fifo_desc_tkeep;
wire                                 tx_fifo_desc_tvalid;
wire                                 tx_fifo_desc_tready;
wire                                 tx_fifo_desc_tlast;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    tx_fifo_desc_tid;
wire                                 tx_fifo_desc_tuser;

wire [0:0]                           rx_cpl_req_sel = 1'b1;
wire [QUEUE_INDEX_WIDTH-1:0]         rx_cpl_req_queue;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    rx_cpl_req_tag;
wire [CPL_SIZE*8-1:0]                rx_cpl_req_data;
wire                                 rx_cpl_req_valid;
wire                                 rx_cpl_req_ready;

wire [DESC_REQ_TAG_WIDTH_INT-1:0]    rx_cpl_req_status_tag;
wire                                 rx_cpl_req_status_full;
wire                                 rx_cpl_req_status_error;
wire                                 rx_cpl_req_status_valid;

wire [0:0]                           tx_cpl_req_sel = 1'b0;
wire [QUEUE_INDEX_WIDTH-1:0]         tx_cpl_req_queue;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]    tx_cpl_req_tag;
wire [CPL_SIZE*8-1:0]                tx_cpl_req_data;
wire                                 tx_cpl_req_valid;
wire                                 tx_cpl_req_ready;

wire [DESC_REQ_TAG_WIDTH_INT-1:0]    tx_cpl_req_status_tag;
wire                                 tx_cpl_req_status_full;
wire                                 tx_cpl_req_status_error;
wire                                 tx_cpl_req_status_valid;

// Scheduler
wire [TX_QUEUE_INDEX_WIDTH-1:0] tx_sched_ctrl_queue;
wire                            tx_sched_ctrl_enable;
wire                            tx_sched_ctrl_valid;
wire                            tx_sched_ctrl_ready;

// TX engine
wire [TX_QUEUE_INDEX_WIDTH-1:0] tx_req_queue;
wire [REQ_TAG_WIDTH-1:0]        tx_req_tag;
wire                            tx_req_valid;
wire                            tx_req_ready;

wire [DMA_CLIENT_LEN_WIDTH-1:0] tx_req_status_len;
wire [REQ_TAG_WIDTH-1:0]        tx_req_status_tag;
wire                            tx_req_status_valid;

// RX engine
wire [RX_QUEUE_INDEX_WIDTH-1:0] rx_req_queue;
wire [REQ_TAG_WIDTH-1:0]        rx_req_tag;
wire                            rx_req_valid;
wire                            rx_req_ready;

wire [REQ_TAG_WIDTH-1:0]        rx_req_status_tag;
wire                            rx_req_status_valid;

// Timestamps
wire [95:0]              rx_ptp_ts_96;
wire                     rx_ptp_ts_valid;
wire                     rx_ptp_ts_ready;

wire [95:0]              tx_ptp_ts_96;
wire                     tx_ptp_ts_valid;
wire                     tx_ptp_ts_ready;

// RX hashing
wire [31:0]              rx_hash;
wire [3:0]               rx_hash_type;
wire                     rx_hash_valid;

wire [31:0]              rx_fifo_hash;
wire [3:0]               rx_fifo_hash_type;
wire                     rx_fifo_hash_valid;
wire                     rx_fifo_hash_ready;

// Checksums
wire [15:0]              rx_csum;
wire                     rx_csum_valid;

wire [15:0]              rx_fifo_csum;
wire                     rx_fifo_csum_valid;
wire                     rx_fifo_csum_ready;

wire                     tx_csum_cmd_csum_enable;
wire [7:0]               tx_csum_cmd_csum_start;
wire [7:0]               tx_csum_cmd_csum_offset;
wire                     tx_csum_cmd_valid;
wire                     tx_csum_cmd_ready;

wire                     tx_fifo_csum_cmd_csum_enable;
wire [7:0]               tx_fifo_csum_cmd_csum_start;
wire [7:0]               tx_fifo_csum_cmd_csum_offset;
wire                     tx_fifo_csum_cmd_valid;
wire                     tx_fifo_csum_cmd_ready;

// Interface DMA control
wire [RAM_ADDR_WIDTH-1:0]       dma_tx_desc_addr;
wire [DMA_CLIENT_LEN_WIDTH-1:0] dma_tx_desc_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0] dma_tx_desc_tag;
wire                            dma_tx_desc_user;
wire                            dma_tx_desc_valid;
wire                            dma_tx_desc_ready;

wire [DMA_CLIENT_TAG_WIDTH-1:0] dma_tx_desc_status_tag;
wire [3:0]                      dma_tx_desc_status_error;
wire                            dma_tx_desc_status_valid;

wire [RAM_ADDR_WIDTH-1:0]       dma_rx_desc_addr;
wire [DMA_CLIENT_LEN_WIDTH-1:0] dma_rx_desc_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0] dma_rx_desc_tag;
wire                            dma_rx_desc_valid;
wire                            dma_rx_desc_ready;

wire [DMA_CLIENT_LEN_WIDTH-1:0] dma_rx_desc_status_len;
wire [DMA_CLIENT_TAG_WIDTH-1:0] dma_rx_desc_status_tag;
wire                            dma_rx_desc_status_user;
wire [3:0]                      dma_rx_desc_status_error;
wire                            dma_rx_desc_status_valid;

wire sched_ctrl_reg_wr_wait;
wire sched_ctrl_reg_wr_ack;
wire [AXIL_DATA_WIDTH-1:0] sched_ctrl_reg_rd_data;
wire sched_ctrl_reg_rd_wait;
wire sched_ctrl_reg_rd_ack;

reg ctrl_reg_wr_ack_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = {AXIL_DATA_WIDTH{1'b0}};
reg ctrl_reg_rd_ack_reg = 1'b0;

reg [RX_QUEUE_INDEX_WIDTH-1:0] rss_mask_reg = 0;

reg [DMA_CLIENT_LEN_WIDTH-1:0] tx_mtu_reg = MAX_TX_SIZE;
reg [DMA_CLIENT_LEN_WIDTH-1:0] rx_mtu_reg = MAX_RX_SIZE;

assign ctrl_reg_wr_wait = sched_ctrl_reg_wr_wait;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_reg | sched_ctrl_reg_wr_ack;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_reg | sched_ctrl_reg_rd_data;
assign ctrl_reg_rd_wait = sched_ctrl_reg_rd_wait;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_reg | sched_ctrl_reg_rd_ack;

always @(posedge clk) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b1;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            16'h0080: rss_mask_reg <= ctrl_reg_wr_data; // RSS mask
            16'h0100: tx_mtu_reg <= ctrl_reg_wr_data; // TX MTU
            16'h0200: rx_mtu_reg <= ctrl_reg_wr_data; // RX MTU
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            16'h0000: ctrl_reg_rd_data_reg <= 32'd0;       // port_id
            16'h0004: begin
                // port_features
                ctrl_reg_rd_data_reg[0] <= RX_RSS_ENABLE && RX_HASH_ENABLE;
                ctrl_reg_rd_data_reg[4] <= PTP_TS_ENABLE;
                ctrl_reg_rd_data_reg[8] <= TX_CHECKSUM_ENABLE;
                ctrl_reg_rd_data_reg[9] <= RX_CHECKSUM_ENABLE;
                ctrl_reg_rd_data_reg[10] <= RX_HASH_ENABLE;
            end
            16'h0008: ctrl_reg_rd_data_reg <= MAX_TX_SIZE; // port_mtu
            16'h0080: ctrl_reg_rd_data_reg <= rss_mask_reg; // RSS mask
            16'h0100: ctrl_reg_rd_data_reg <= tx_mtu_reg; // TX MTU
            16'h0200: ctrl_reg_rd_data_reg <= rx_mtu_reg; // RX MTU
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        rss_mask_reg <= 0;
        tx_mtu_reg <= MAX_TX_SIZE;
        rx_mtu_reg <= MAX_RX_SIZE;
    end
end

desc_op_mux #(
    .PORTS(2),
    .SELECT_WIDTH(1),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(CPL_QUEUE_INDEX_WIDTH),
    .S_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH_INT),
    .M_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
desc_op_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor request output
     */
    .m_axis_req_sel(m_axis_desc_req_sel),
    .m_axis_req_queue(m_axis_desc_req_queue),
    .m_axis_req_tag(m_axis_desc_req_tag),
    .m_axis_req_valid(m_axis_desc_req_valid),
    .m_axis_req_ready(m_axis_desc_req_ready),

    /*
     * Descriptor request status input
     */
    .s_axis_req_status_queue(s_axis_desc_req_status_queue),
    .s_axis_req_status_ptr(s_axis_desc_req_status_ptr),
    .s_axis_req_status_cpl(s_axis_desc_req_status_cpl),
    .s_axis_req_status_tag(s_axis_desc_req_status_tag),
    .s_axis_req_status_empty(s_axis_desc_req_status_empty),
    .s_axis_req_status_error(s_axis_desc_req_status_error),
    .s_axis_req_status_valid(s_axis_desc_req_status_valid),

    /*
     * Descriptor data input
     */
    .s_axis_desc_tdata(s_axis_desc_tdata),
    .s_axis_desc_tkeep(s_axis_desc_tkeep),
    .s_axis_desc_tvalid(s_axis_desc_tvalid),
    .s_axis_desc_tready(s_axis_desc_tready),
    .s_axis_desc_tlast(s_axis_desc_tlast),
    .s_axis_desc_tid(s_axis_desc_tid),
    .s_axis_desc_tuser(s_axis_desc_tuser),

    /*
     * Descriptor request input
     */
    .s_axis_req_sel({rx_desc_req_sel, tx_desc_req_sel}),
    .s_axis_req_queue({rx_desc_req_queue, tx_desc_req_queue}),
    .s_axis_req_tag({rx_desc_req_tag, tx_desc_req_tag}),
    .s_axis_req_valid({rx_desc_req_valid, tx_desc_req_valid}),
    .s_axis_req_ready({rx_desc_req_ready, tx_desc_req_ready}),

    /*
     * Descriptor response output
     */
    .m_axis_req_status_queue({rx_desc_req_status_queue, tx_desc_req_status_queue}),
    .m_axis_req_status_ptr({rx_desc_req_status_ptr, tx_desc_req_status_ptr}),
    .m_axis_req_status_cpl({rx_desc_req_status_cpl, tx_desc_req_status_cpl}),
    .m_axis_req_status_tag({rx_desc_req_status_tag, tx_desc_req_status_tag}),
    .m_axis_req_status_empty({rx_desc_req_status_empty, tx_desc_req_status_empty}),
    .m_axis_req_status_error({rx_desc_req_status_error, tx_desc_req_status_error}),
    .m_axis_req_status_valid({rx_desc_req_status_valid, tx_desc_req_status_valid}),

    /*
     * Descriptor data output
     */
    .m_axis_desc_tdata({rx_desc_tdata, tx_desc_tdata}),
    .m_axis_desc_tkeep({rx_desc_tkeep, tx_desc_tkeep}),
    .m_axis_desc_tvalid({rx_desc_tvalid, tx_desc_tvalid}),
    .m_axis_desc_tready({rx_desc_tready, tx_desc_tready}),
    .m_axis_desc_tlast({rx_desc_tlast, tx_desc_tlast}),
    .m_axis_desc_tid({rx_desc_tid, tx_desc_tid}),
    .m_axis_desc_tuser({rx_desc_tuser, tx_desc_tuser})
);

cpl_op_mux #(
    .PORTS(2),
    .SELECT_WIDTH(1),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .S_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH_INT),
    .M_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
cpl_op_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Completion request output
     */
    .m_axis_req_sel(m_axis_cpl_req_sel),
    .m_axis_req_queue(m_axis_cpl_req_queue),
    .m_axis_req_tag(m_axis_cpl_req_tag),
    .m_axis_req_data(m_axis_cpl_req_data),
    .m_axis_req_valid(m_axis_cpl_req_valid),
    .m_axis_req_ready(m_axis_cpl_req_ready),

    /*
     * Completion request status input
     */
    .s_axis_req_status_tag(s_axis_cpl_req_status_tag),
    .s_axis_req_status_full(s_axis_cpl_req_status_full),
    .s_axis_req_status_error(s_axis_cpl_req_status_error),
    .s_axis_req_status_valid(s_axis_cpl_req_status_valid),

    /*
     * Completion request input
     */
    .s_axis_req_sel({rx_cpl_req_sel, tx_cpl_req_sel}),
    .s_axis_req_queue({rx_cpl_req_queue, tx_cpl_req_queue}),
    .s_axis_req_tag({rx_cpl_req_tag, tx_cpl_req_tag}),
    .s_axis_req_data({rx_cpl_req_data, tx_cpl_req_data}),
    .s_axis_req_valid({rx_cpl_req_valid, tx_cpl_req_valid}),
    .s_axis_req_ready({rx_cpl_req_ready, tx_cpl_req_ready}),

    /*
     * Completion response output
     */
    .m_axis_req_status_tag({rx_cpl_req_status_tag, tx_cpl_req_status_tag}),
    .m_axis_req_status_full({rx_cpl_req_status_full, tx_cpl_req_status_full}),
    .m_axis_req_status_error({rx_cpl_req_status_error, tx_cpl_req_status_error}),
    .m_axis_req_status_valid({rx_cpl_req_status_valid, tx_cpl_req_status_valid})
);

mqnic_tx_scheduler_block #(
    .REG_DATA_WIDTH(REG_DATA_WIDTH),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .REG_STRB_WIDTH(REG_STRB_WIDTH),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .AXIL_OFFSET(AXIL_OFFSET),
    .LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .PIPELINE(TX_SCHEDULER_PIPELINE),
    .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .MAX_TX_SIZE(MAX_TX_SIZE)
)
scheduler_block (
    .clk(clk),
    .rst(rst),

    /*
     * Control register interface
     */
    .ctrl_reg_wr_addr(ctrl_reg_wr_addr),
    .ctrl_reg_wr_data(ctrl_reg_wr_data),
    .ctrl_reg_wr_strb(ctrl_reg_wr_strb),
    .ctrl_reg_wr_en(ctrl_reg_wr_en),
    .ctrl_reg_wr_wait(sched_ctrl_reg_wr_wait),
    .ctrl_reg_wr_ack(sched_ctrl_reg_wr_ack),
    .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
    .ctrl_reg_rd_en(ctrl_reg_rd_en),
    .ctrl_reg_rd_data(sched_ctrl_reg_rd_data),
    .ctrl_reg_rd_wait(sched_ctrl_reg_rd_wait),
    .ctrl_reg_rd_ack(sched_ctrl_reg_rd_ack),

    /*
     * AXI-Lite slave interface
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
     * Transmit request output (queue index)
     */
    .m_axis_tx_req_queue(tx_req_queue),
    .m_axis_tx_req_tag(tx_req_tag),
    .m_axis_tx_req_valid(tx_req_valid),
    .m_axis_tx_req_ready(tx_req_ready),

    /*
     * Transmit request status input
     */
    .s_axis_tx_req_status_len(tx_req_status_len),
    .s_axis_tx_req_status_tag(tx_req_status_tag),
    .s_axis_tx_req_status_valid(tx_req_status_valid),

    /*
     * Doorbell input
     */
    .s_axis_doorbell_queue(s_axis_tx_doorbell_queue),
    .s_axis_doorbell_valid(s_axis_tx_doorbell_valid),

    /*
     * PTP clock
     */
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step)
);

axis_fifo #(
    .DEPTH(TX_DESC_FIFO_SIZE*DESC_SIZE),
    .DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(1),
    .ID_WIDTH(DESC_REQ_TAG_WIDTH_INT),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .PIPELINE_OUTPUT(3),
    .FRAME_FIFO(0)
)
tx_desc_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(tx_desc_tdata),
    .s_axis_tkeep(tx_desc_tkeep),
    .s_axis_tvalid(tx_desc_tvalid),
    .s_axis_tready(tx_desc_tready),
    .s_axis_tlast(tx_desc_tlast),
    .s_axis_tid(tx_desc_tid),
    .s_axis_tdest(0),
    .s_axis_tuser(tx_desc_tuser),

    // AXI output
    .m_axis_tdata(tx_fifo_desc_tdata),
    .m_axis_tkeep(tx_fifo_desc_tkeep),
    .m_axis_tvalid(tx_fifo_desc_tvalid),
    .m_axis_tready(tx_fifo_desc_tready),
    .m_axis_tlast(tx_fifo_desc_tlast),
    .m_axis_tid(tx_fifo_desc_tid),
    .m_axis_tdest(),
    .m_axis_tuser(tx_fifo_desc_tuser),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

tx_engine #(
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_CLIENT_LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .DESC_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH_INT),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .DMA_CLIENT_TAG_WIDTH(DMA_CLIENT_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .DESC_TABLE_DMA_OP_COUNT_WIDTH(DESC_TABLE_DMA_OP_COUNT_WIDTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .TX_BUFFER_OFFSET(0),
    .TX_BUFFER_SIZE(TX_RAM_SIZE),
    .TX_BUFFER_STEP_SIZE(SEG_COUNT*SEG_BE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .CPL_SIZE(CPL_SIZE),
    .MAX_DESC_REQ(TX_MAX_DESC_REQ),
    .AXIS_DESC_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_DESC_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE)
)
tx_engine_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Transmit request input (queue index)
     */
    .s_axis_tx_req_queue(tx_req_queue),
    .s_axis_tx_req_tag(tx_req_tag),
    .s_axis_tx_req_valid(tx_req_valid),
    .s_axis_tx_req_ready(tx_req_ready),

    /*
     * Transmit request status output
     */
    .m_axis_tx_req_status_len(tx_req_status_len),
    .m_axis_tx_req_status_tag(tx_req_status_tag),
    .m_axis_tx_req_status_valid(tx_req_status_valid),

    /*
     * Descriptor request output
     */
    .m_axis_desc_req_queue(tx_desc_req_queue),
    .m_axis_desc_req_tag(tx_desc_req_tag),
    .m_axis_desc_req_valid(tx_desc_req_valid),
    .m_axis_desc_req_ready(tx_desc_req_ready),

    /*
     * Descriptor request status input
     */
    .s_axis_desc_req_status_queue(tx_desc_req_status_queue),
    .s_axis_desc_req_status_ptr(tx_desc_req_status_ptr),
    .s_axis_desc_req_status_cpl(tx_desc_req_status_cpl),
    .s_axis_desc_req_status_tag(tx_desc_req_status_tag),
    .s_axis_desc_req_status_empty(tx_desc_req_status_empty),
    .s_axis_desc_req_status_error(tx_desc_req_status_error),
    .s_axis_desc_req_status_valid(tx_desc_req_status_valid),

    /*
     * Descriptor data input
     */
    .s_axis_desc_tdata(tx_fifo_desc_tdata),
    .s_axis_desc_tkeep(tx_fifo_desc_tkeep),
    .s_axis_desc_tvalid(tx_fifo_desc_tvalid),
    .s_axis_desc_tready(tx_fifo_desc_tready),
    .s_axis_desc_tlast(tx_fifo_desc_tlast),
    .s_axis_desc_tid(tx_fifo_desc_tid),
    .s_axis_desc_tuser(tx_fifo_desc_tuser),

    /*
     * Completion request output
     */
    .m_axis_cpl_req_queue(tx_cpl_req_queue),
    .m_axis_cpl_req_tag(tx_cpl_req_tag),
    .m_axis_cpl_req_data(tx_cpl_req_data),
    .m_axis_cpl_req_valid(tx_cpl_req_valid),
    .m_axis_cpl_req_ready(tx_cpl_req_ready),

    /*
     * Completion request status input
     */
    .s_axis_cpl_req_status_tag(tx_cpl_req_status_tag),
    .s_axis_cpl_req_status_full(tx_cpl_req_status_full),
    .s_axis_cpl_req_status_error(tx_cpl_req_status_error),
    .s_axis_cpl_req_status_valid(tx_cpl_req_status_valid),

    /*
     * DMA read descriptor output
     */
    .m_axis_dma_read_desc_dma_addr(m_axis_dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_addr(m_axis_dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(m_axis_dma_read_desc_len),
    .m_axis_dma_read_desc_tag(m_axis_dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(m_axis_dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(m_axis_dma_read_desc_ready),

    /*
     * DMA read descriptor status input
     */
    .s_axis_dma_read_desc_status_tag(s_axis_dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(s_axis_dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(s_axis_dma_read_desc_status_valid),

    /*
     * Transmit descriptor output
     */
    .m_axis_tx_desc_addr(dma_tx_desc_addr),
    .m_axis_tx_desc_len(dma_tx_desc_len),
    .m_axis_tx_desc_tag(dma_tx_desc_tag),
    .m_axis_tx_desc_user(dma_tx_desc_user),
    .m_axis_tx_desc_valid(dma_tx_desc_valid),
    .m_axis_tx_desc_ready(dma_tx_desc_ready),

    /*
     * Transmit descriptor status input
     */
    .s_axis_tx_desc_status_tag(dma_tx_desc_status_tag),
    .s_axis_tx_desc_status_error(dma_tx_desc_status_error),
    .s_axis_tx_desc_status_valid(dma_tx_desc_status_valid),

    /*
     * Transmit checksum command output
     */
    .m_axis_tx_csum_cmd_csum_enable(tx_csum_cmd_csum_enable),
    .m_axis_tx_csum_cmd_csum_start(tx_csum_cmd_csum_start),
    .m_axis_tx_csum_cmd_csum_offset(tx_csum_cmd_csum_offset),
    .m_axis_tx_csum_cmd_valid(tx_csum_cmd_valid),
    .m_axis_tx_csum_cmd_ready(tx_csum_cmd_ready),

    /*
     * Transmit timestamp input
     */
    .s_axis_tx_ptp_ts_96(s_axis_tx_ptp_ts_96),
    .s_axis_tx_ptp_ts_valid(s_axis_tx_ptp_ts_valid),
    .s_axis_tx_ptp_ts_ready(s_axis_tx_ptp_ts_ready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

axis_fifo #(
    .DEPTH(RX_DESC_FIFO_SIZE*DESC_SIZE),
    .DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(1),
    .ID_WIDTH(DESC_REQ_TAG_WIDTH_INT),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .PIPELINE_OUTPUT(3),
    .FRAME_FIFO(0)
)
rx_desc_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(rx_desc_tdata),
    .s_axis_tkeep(rx_desc_tkeep),
    .s_axis_tvalid(rx_desc_tvalid),
    .s_axis_tready(rx_desc_tready),
    .s_axis_tlast(rx_desc_tlast),
    .s_axis_tid(rx_desc_tid),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_desc_tuser),

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

rx_engine #(
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_CLIENT_LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .DESC_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH_INT),
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
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE)
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
    .m_axis_rx_req_status_tag(rx_req_status_tag),
    .m_axis_rx_req_status_valid(rx_req_status_valid),

    /*
     * Descriptor request output
     */
    .m_axis_desc_req_queue(rx_desc_req_queue),
    .m_axis_desc_req_tag(rx_desc_req_tag),
    .m_axis_desc_req_valid(rx_desc_req_valid),
    .m_axis_desc_req_ready(rx_desc_req_ready),

    /*
     * Descriptor request status input
     */
    .s_axis_desc_req_status_queue(rx_desc_req_status_queue),
    .s_axis_desc_req_status_ptr(rx_desc_req_status_ptr),
    .s_axis_desc_req_status_cpl(rx_desc_req_status_cpl),
    .s_axis_desc_req_status_tag(rx_desc_req_status_tag),
    .s_axis_desc_req_status_empty(rx_desc_req_status_empty),
    .s_axis_desc_req_status_error(rx_desc_req_status_error),
    .s_axis_desc_req_status_valid(rx_desc_req_status_valid),

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
    .m_axis_cpl_req_queue(rx_cpl_req_queue),
    .m_axis_cpl_req_tag(rx_cpl_req_tag),
    .m_axis_cpl_req_data(rx_cpl_req_data),
    .m_axis_cpl_req_valid(rx_cpl_req_valid),
    .m_axis_cpl_req_ready(rx_cpl_req_ready),

    /*
     * Completion request status input
     */
    .s_axis_cpl_req_status_tag(rx_cpl_req_status_tag),
    .s_axis_cpl_req_status_full(rx_cpl_req_status_full),
    .s_axis_cpl_req_status_error(rx_cpl_req_status_error),
    .s_axis_cpl_req_status_valid(rx_cpl_req_status_valid),

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
    .s_axis_rx_desc_status_user(dma_rx_desc_status_user),
    .s_axis_rx_desc_status_error(dma_rx_desc_status_error),
    .s_axis_rx_desc_status_valid(dma_rx_desc_status_valid),

    /*
     * Receive timestamp input
     */
    .s_axis_rx_ptp_ts_96(s_axis_rx_ptp_ts_96),
    .s_axis_rx_ptp_ts_valid(s_axis_rx_ptp_ts_valid),
    .s_axis_rx_ptp_ts_ready(s_axis_rx_ptp_ts_ready),

    /*
     * Receive hash input
     */
    .s_axis_rx_hash(rx_fifo_hash),
    .s_axis_rx_hash_type(rx_fifo_hash_type),
    .s_axis_rx_hash_valid(rx_fifo_hash_valid),
    .s_axis_rx_hash_ready(rx_fifo_hash_ready),

    /*
     * Receive checksum input
     */
    .s_axis_rx_csum(rx_fifo_csum),
    .s_axis_rx_csum_valid(rx_fifo_csum_valid),
    .s_axis_rx_csum_ready(rx_fifo_csum_ready),

    /*
     * Configuration
     */
    .mtu(rx_mtu_reg),
    .enable(1'b1)
);

generate

if (RX_HASH_ENABLE) begin

    rx_hash #(
        .DATA_WIDTH(AXIS_DATA_WIDTH)
    )
    rx_hash_inst (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(rx_axis_tdata),
        .s_axis_tkeep(rx_axis_tkeep),
        .s_axis_tvalid(rx_axis_tvalid & rx_axis_tready),
        .s_axis_tlast(rx_axis_tlast),
        .hash_key(320'h6d5a56da255b0ec24167253d43a38fb0d0ca2bcbae7b30b477cb2da38030f20c6a42b73bbeac01fa),
        .m_axis_hash(rx_hash),
        .m_axis_hash_type(rx_hash_type),
        .m_axis_hash_valid(rx_hash_valid)
    );

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(32+4),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    rx_hash_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata({rx_hash_type, rx_hash}),
        .s_axis_tkeep(0),
        .s_axis_tvalid(rx_hash_valid),
        .s_axis_tready(),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata({rx_fifo_hash_type, rx_fifo_hash}),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_fifo_hash_valid),
        .m_axis_tready(rx_fifo_hash_ready),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

end else begin

    assign rx_fifo_hash = 32'd0;
    assign rx_fifo_hash_type = 4'd0;
    assign rx_fifo_hash_valid = 1'b0;

end

if (RX_RSS_ENABLE && RX_HASH_ENABLE) begin

    axis_fifo #(
        .DEPTH(AXIS_KEEP_WIDTH*32),
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
        .KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .LAST_ENABLE(1),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(1),
        .USER_WIDTH(1),
        .FRAME_FIFO(0)
    )
    rx_hash_data_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(rx_axis_tdata),
        .s_axis_tkeep(rx_axis_tkeep),
        .s_axis_tvalid(rx_axis_tvalid),
        .s_axis_tready(rx_axis_tready),
        .s_axis_tlast(rx_axis_tlast),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(rx_axis_tuser),

        // AXI output
        .m_axis_tdata(rx_axis_tdata_int),
        .m_axis_tkeep(rx_axis_tkeep_int),
        .m_axis_tvalid(rx_axis_tvalid_int),
        .m_axis_tready(rx_axis_tready_int),
        .m_axis_tlast(rx_axis_tlast_int),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(rx_axis_tuser_int),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

    // Generate RX requests (RSS)
    assign rx_req_tag = 0;

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(RX_QUEUE_INDEX_WIDTH),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    rx_req_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(rx_hash & rss_mask_reg),
        .s_axis_tkeep(0),
        .s_axis_tvalid(rx_hash_valid),
        .s_axis_tready(),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata(rx_req_queue),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_req_valid),
        .m_axis_tready(rx_req_ready),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

end else begin

    assign rx_axis_tdata_int = rx_axis_tdata;
    assign rx_axis_tkeep_int = rx_axis_tkeep;
    assign rx_axis_tvalid_int = rx_axis_tvalid;
    assign rx_axis_tready = rx_axis_tready_int;
    assign rx_axis_tlast_int = rx_axis_tlast;
    assign rx_axis_tuser_int = rx_axis_tuser;

    // Generate RX requests (no RSS)
    reg rx_frame_reg = 1'b0;
    reg rx_req_valid_reg = 1'b0;

    assign rx_req_queue = 0;
    assign rx_req_tag = 0;
    assign rx_req_valid = rx_axis_tvalid_int && !rx_frame_reg;

    always @(posedge clk) begin
        if (rx_req_ready) begin
            rx_req_valid_reg <= 1'b0;
        end

        if (rx_axis_tready_int && rx_axis_tvalid_int) begin
            if (!rx_frame_reg) begin
                rx_req_valid_reg <= 1'b1;
            end
            rx_frame_reg <= !rx_axis_tlast_int;
        end

        if (rst) begin
            rx_frame_reg <= 1'b0;
            rx_req_valid_reg <= 1'b0;
        end
    end

end

if (RX_CHECKSUM_ENABLE) begin

    rx_checksum #(
        .DATA_WIDTH(AXIS_DATA_WIDTH)
    )
    rx_checksum_inst (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(rx_axis_tdata_int),
        .s_axis_tkeep(rx_axis_tkeep_int),
        .s_axis_tvalid(rx_axis_tvalid_int & rx_axis_tready_int),
        .s_axis_tlast(rx_axis_tlast_int),
        .m_axis_csum(rx_csum),
        .m_axis_csum_valid(rx_csum_valid)
    );

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(16),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    rx_csum_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(rx_csum),
        .s_axis_tkeep(0),
        .s_axis_tvalid(rx_csum_valid),
        .s_axis_tready(),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata(rx_fifo_csum),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_fifo_csum_valid),
        .m_axis_tready(rx_fifo_csum_ready),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

end else begin

    assign rx_fifo_csum = 16'd0;
    assign rx_fifo_csum_valid = 1'b0;

end

if (TX_CHECKSUM_ENABLE) begin

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(1+8+8),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    tx_csum_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata({tx_csum_cmd_csum_enable, tx_csum_cmd_csum_start, tx_csum_cmd_csum_offset}),
        .s_axis_tkeep(0),
        .s_axis_tvalid(tx_csum_cmd_valid),
        .s_axis_tready(tx_csum_cmd_ready),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata({tx_fifo_csum_cmd_csum_enable, tx_fifo_csum_cmd_csum_start, tx_fifo_csum_cmd_csum_offset}),
        .m_axis_tkeep(),
        .m_axis_tvalid(tx_fifo_csum_cmd_valid),
        .m_axis_tready(tx_fifo_csum_cmd_ready),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

    tx_checksum #(
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(1),
        .USER_WIDTH(1),
        .USE_INIT_VALUE(0),
        .DATA_FIFO_DEPTH(MAX_TX_SIZE),
        .CHECKSUM_FIFO_DEPTH(64)
    )
    tx_checksum_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI input
         */
        .s_axis_tdata(tx_axis_tdata_int),
        .s_axis_tkeep(tx_axis_tkeep_int),
        .s_axis_tvalid(tx_axis_tvalid_int),
        .s_axis_tready(tx_axis_tready_int),
        .s_axis_tlast(tx_axis_tlast_int),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(tx_axis_tuser_int),

        /*
         * AXI output
         */
        .m_axis_tdata(tx_axis_tdata),
        .m_axis_tkeep(tx_axis_tkeep),
        .m_axis_tvalid(tx_axis_tvalid),
        .m_axis_tready(tx_axis_tready),
        .m_axis_tlast(tx_axis_tlast),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(tx_axis_tuser),

        /*
         * Control
         */
        .s_axis_cmd_csum_enable(tx_fifo_csum_cmd_csum_enable),
        .s_axis_cmd_csum_start(tx_fifo_csum_cmd_csum_start),
        .s_axis_cmd_csum_offset(tx_fifo_csum_cmd_csum_offset),
        .s_axis_cmd_csum_init(16'd0),
        .s_axis_cmd_valid(tx_fifo_csum_cmd_valid),
        .s_axis_cmd_ready(tx_fifo_csum_cmd_ready)
    );

end else begin

    assign tx_axis_tdata = tx_axis_tdata_int;
    assign tx_axis_tkeep = tx_axis_tkeep_int;
    assign tx_axis_tvalid = tx_axis_tvalid_int;
    assign tx_axis_tready_int = tx_axis_tready;
    assign tx_axis_tlast = tx_axis_tlast_int;
    assign tx_axis_tuser = tx_axis_tuser_int;

    assign tx_csum_cmd_ready = 1'b1;

end

endgenerate

wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_ready_int;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_ready_int;

dma_psdpram #(
    .SIZE(TX_RAM_SIZE),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .PIPELINE(RAM_PIPELINE)
)
dma_psdpram_tx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .wr_cmd_be(dma_ram_wr_cmd_be),
    .wr_cmd_addr(dma_ram_wr_cmd_addr),
    .wr_cmd_data(dma_ram_wr_cmd_data),
    .wr_cmd_valid(dma_ram_wr_cmd_valid),
    .wr_cmd_ready(dma_ram_wr_cmd_ready),
    .wr_done(dma_ram_wr_done),

    /*
     * Read port
     */
    .rd_cmd_addr(dma_ram_rd_cmd_addr_int),
    .rd_cmd_valid(dma_ram_rd_cmd_valid_int),
    .rd_cmd_ready(dma_ram_rd_cmd_ready_int),
    .rd_resp_data(dma_ram_rd_resp_data_int),
    .rd_resp_valid(dma_ram_rd_resp_valid_int),
    .rd_resp_ready(dma_ram_rd_resp_ready_int)
);

dma_client_axis_source #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
    .TAG_WIDTH(DMA_CLIENT_TAG_WIDTH)
)
dma_client_axis_source_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA read descriptor input
     */
    .s_axis_read_desc_ram_addr(dma_tx_desc_addr),
    .s_axis_read_desc_len(dma_tx_desc_len),
    .s_axis_read_desc_tag(dma_tx_desc_tag),
    .s_axis_read_desc_id(0),
    .s_axis_read_desc_dest(0),
    .s_axis_read_desc_user(dma_tx_desc_user),
    .s_axis_read_desc_valid(dma_tx_desc_valid),
    .s_axis_read_desc_ready(dma_tx_desc_ready),

    /*
     * DMA read descriptor status output
     */
    .m_axis_read_desc_status_tag(dma_tx_desc_status_tag),
    .m_axis_read_desc_status_error(dma_tx_desc_status_error),
    .m_axis_read_desc_status_valid(dma_tx_desc_status_valid),

    /*
     * AXI stream read data output
     */
    .m_axis_read_data_tdata(tx_axis_tdata_int),
    .m_axis_read_data_tkeep(tx_axis_tkeep_int),
    .m_axis_read_data_tvalid(tx_axis_tvalid_int),
    .m_axis_read_data_tready(tx_axis_tready_int),
    .m_axis_read_data_tlast(tx_axis_tlast_int),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(tx_axis_tuser_int),

    /*
     * RAM interface
     */
    .ram_rd_cmd_addr(dma_ram_rd_cmd_addr_int),
    .ram_rd_cmd_valid(dma_ram_rd_cmd_valid_int),
    .ram_rd_cmd_ready(dma_ram_rd_cmd_ready_int),
    .ram_rd_resp_data(dma_ram_rd_resp_data_int),
    .ram_rd_resp_valid(dma_ram_rd_resp_valid_int),
    .ram_rd_resp_ready(dma_ram_rd_resp_ready_int),

    /*
     * Configuration
     */
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
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
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

dma_client_axis_sink #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(1),
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
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
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
    .s_axis_write_data_tid(0),
    .s_axis_write_data_tdest(0),
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
