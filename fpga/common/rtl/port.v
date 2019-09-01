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

`timescale 1ns / 1ps

/*
 * NIC Port
 */
module port #
(
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // PCIe DMA length field width
    parameter PCIE_DMA_LEN_WIDTH = 16,
    // PCIe DMA tag field width
    parameter PCIE_DMA_TAG_WIDTH = 8,
    // Request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Transmit queue index width
    parameter TX_QUEUE_INDEX_WIDTH = 8,
    // Receive queue index width
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    // Transmit completion queue index width
    parameter TX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Receive completion queue index width
    parameter RX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Transmit descriptor table size (number of in-flight operations)
    parameter TX_DESC_TABLE_SIZE = 16,
    // Transmit packet table size (number of in-progress packets)
    parameter TX_PKT_TABLE_SIZE = 8,
    // Receive descriptor table size (number of in-flight operations)
    parameter RX_DESC_TABLE_SIZE = 16,
    // Receive packet table size (number of in-progress packets)
    parameter RX_PKT_TABLE_SIZE = 8,
    // Transmit scheduler type
    parameter TX_SCHEDULER = "RR",
    // Scheduler operation table size
    parameter TX_SCHEDULER_OP_TABLE_SIZE = 32,
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
    // Enable RX checksum offload
    parameter RX_CHECKSUM_ENABLE = 1,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 256,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
    // AXI base address of this module (as seen by PCIe DMA)
    parameter AXI_BASE_ADDR = 0,
    // AXI base address of TX packet RAM (as seen by PCIe DMA and AXI DMA in this module)
    parameter TX_RAM_AXI_BASE_ADDR = 0,
    // AXI base address of RX packet RAM (as seen by PCIe DMA and AXI DMA in this module)
    parameter RX_RAM_AXI_BASE_ADDR = 0,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXI_STRB_WIDTH
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * TX descriptor dequeue request output
     */
    output wire [TX_QUEUE_INDEX_WIDTH-1:0]      m_axis_tx_desc_dequeue_req_queue,
    output wire [QUEUE_REQ_TAG_WIDTH-1:0]       m_axis_tx_desc_dequeue_req_tag,
    output wire                                 m_axis_tx_desc_dequeue_req_valid,
    input  wire                                 m_axis_tx_desc_dequeue_req_ready,

    /*
     * TX descriptor dequeue response input
     */
    input  wire [TX_QUEUE_INDEX_WIDTH-1:0]      s_axis_tx_desc_dequeue_resp_queue,
    input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_tx_desc_dequeue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_tx_desc_dequeue_resp_addr,
    input  wire [TX_CPL_QUEUE_INDEX_WIDTH-1:0]  s_axis_tx_desc_dequeue_resp_cpl,
    input  wire [QUEUE_REQ_TAG_WIDTH-1:0]       s_axis_tx_desc_dequeue_resp_tag,
    input  wire [QUEUE_OP_TAG_WIDTH-1:0]        s_axis_tx_desc_dequeue_resp_op_tag,
    input  wire                                 s_axis_tx_desc_dequeue_resp_empty,
    input  wire                                 s_axis_tx_desc_dequeue_resp_error,
    input  wire                                 s_axis_tx_desc_dequeue_resp_valid,
    output wire                                 s_axis_tx_desc_dequeue_resp_ready,

    /*
     * TX descriptor dequeue commit output
     */
    output wire [QUEUE_OP_TAG_WIDTH-1:0]        m_axis_tx_desc_dequeue_commit_op_tag,
    output wire                                 m_axis_tx_desc_dequeue_commit_valid,
    input  wire                                 m_axis_tx_desc_dequeue_commit_ready,

    /*
     * TX doorbell input
     */
    input  wire [TX_QUEUE_INDEX_WIDTH-1:0]      s_axis_tx_doorbell_queue,
    input  wire                                 s_axis_tx_doorbell_valid,

    /*
     * TX completion enqueue request output
     */
    output wire [TX_CPL_QUEUE_INDEX_WIDTH-1:0]  m_axis_tx_cpl_enqueue_req_queue,
    output wire [QUEUE_REQ_TAG_WIDTH-1:0]       m_axis_tx_cpl_enqueue_req_tag,
    output wire                                 m_axis_tx_cpl_enqueue_req_valid,
    input  wire                                 m_axis_tx_cpl_enqueue_req_ready,

    /*
     * TX completion enqueue response input
     */
    //input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_tx_cpl_enqueue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_tx_cpl_enqueue_resp_addr,
    //input  wire [EVENT_WIDTH-1:0]               s_axis_tx_cpl_enqueue_resp_event,
    input  wire [QUEUE_REQ_TAG_WIDTH-1:0]       s_axis_tx_cpl_enqueue_resp_tag,
    input  wire [QUEUE_OP_TAG_WIDTH-1:0]        s_axis_tx_cpl_enqueue_resp_op_tag,
    input  wire                                 s_axis_tx_cpl_enqueue_resp_full,
    input  wire                                 s_axis_tx_cpl_enqueue_resp_error,
    input  wire                                 s_axis_tx_cpl_enqueue_resp_valid,
    output wire                                 s_axis_tx_cpl_enqueue_resp_ready,

    /*
     * TX completion enqueue commit output
     */
    output wire [QUEUE_OP_TAG_WIDTH-1:0]        m_axis_tx_cpl_enqueue_commit_op_tag,
    output wire                                 m_axis_tx_cpl_enqueue_commit_valid,
    input  wire                                 m_axis_tx_cpl_enqueue_commit_ready,

    /*
     * RX descriptor dequeue request output
     */
    output wire [RX_QUEUE_INDEX_WIDTH-1:0]      m_axis_rx_desc_dequeue_req_queue,
    output wire [QUEUE_REQ_TAG_WIDTH-1:0]       m_axis_rx_desc_dequeue_req_tag,
    output wire                                 m_axis_rx_desc_dequeue_req_valid,
    input  wire                                 m_axis_rx_desc_dequeue_req_ready,

    /*
     * RX descriptor dequeue response input
     */
    input  wire [RX_QUEUE_INDEX_WIDTH-1:0]      s_axis_rx_desc_dequeue_resp_queue,
    input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_rx_desc_dequeue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_rx_desc_dequeue_resp_addr,
    input  wire [RX_CPL_QUEUE_INDEX_WIDTH-1:0]  s_axis_rx_desc_dequeue_resp_cpl,
    input  wire [QUEUE_REQ_TAG_WIDTH-1:0]       s_axis_rx_desc_dequeue_resp_tag,
    input  wire [QUEUE_OP_TAG_WIDTH-1:0]        s_axis_rx_desc_dequeue_resp_op_tag,
    input  wire                                 s_axis_rx_desc_dequeue_resp_empty,
    input  wire                                 s_axis_rx_desc_dequeue_resp_error,
    input  wire                                 s_axis_rx_desc_dequeue_resp_valid,
    output wire                                 s_axis_rx_desc_dequeue_resp_ready,

    /*
     * RX descriptor dequeue commit output
     */
    output wire [QUEUE_OP_TAG_WIDTH-1:0]        m_axis_rx_desc_dequeue_commit_op_tag,
    output wire                                 m_axis_rx_desc_dequeue_commit_valid,
    input  wire                                 m_axis_rx_desc_dequeue_commit_ready,

    /*
     * RX completion enqueue request output
     */
    output wire [RX_CPL_QUEUE_INDEX_WIDTH-1:0]  m_axis_rx_cpl_enqueue_req_queue,
    output wire [QUEUE_REQ_TAG_WIDTH-1:0]       m_axis_rx_cpl_enqueue_req_tag,
    output wire                                 m_axis_rx_cpl_enqueue_req_valid,
    input  wire                                 m_axis_rx_cpl_enqueue_req_ready,

    /*
     * RX completion enqueue response input
     */
    //input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_rx_cpl_enqueue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_rx_cpl_enqueue_resp_addr,
    //input  wire [EVENT_WIDTH-1:0]               s_axis_rx_cpl_enqueue_resp_event,
    input  wire [QUEUE_REQ_TAG_WIDTH-1:0]       s_axis_rx_cpl_enqueue_resp_tag,
    input  wire [QUEUE_OP_TAG_WIDTH-1:0]        s_axis_rx_cpl_enqueue_resp_op_tag,
    input  wire                                 s_axis_rx_cpl_enqueue_resp_full,
    input  wire                                 s_axis_rx_cpl_enqueue_resp_error,
    input  wire                                 s_axis_rx_cpl_enqueue_resp_valid,
    output wire                                 s_axis_rx_cpl_enqueue_resp_ready,

    /*
     * RX completion enqueue commit output
     */
    output wire [QUEUE_OP_TAG_WIDTH-1:0]        m_axis_rx_cpl_enqueue_commit_op_tag,
    output wire                                 m_axis_rx_cpl_enqueue_commit_valid,
    input  wire                                 m_axis_rx_cpl_enqueue_commit_ready,

    /*
     * PCIe read descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]           m_axis_pcie_axi_dma_read_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]            m_axis_pcie_axi_dma_read_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]        m_axis_pcie_axi_dma_read_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]        m_axis_pcie_axi_dma_read_desc_tag,
    output wire                                 m_axis_pcie_axi_dma_read_desc_valid,
    input  wire                                 m_axis_pcie_axi_dma_read_desc_ready,

    /*
     * PCIe read descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]        s_axis_pcie_axi_dma_read_desc_status_tag,
    input  wire                                 s_axis_pcie_axi_dma_read_desc_status_valid,

    /*
     * PCIe write descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]           m_axis_pcie_axi_dma_write_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]            m_axis_pcie_axi_dma_write_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]        m_axis_pcie_axi_dma_write_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]        m_axis_pcie_axi_dma_write_desc_tag,
    output wire                                 m_axis_pcie_axi_dma_write_desc_valid,
    input  wire                                 m_axis_pcie_axi_dma_write_desc_ready,

    /*
     * PCIe write descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]        s_axis_pcie_axi_dma_write_desc_status_tag,
    input  wire                                 s_axis_pcie_axi_dma_write_desc_status_valid,

    /*
     * AXI-Lite slave interface
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
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]              m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]            m_axi_awaddr,
    output wire [7:0]                           m_axi_awlen,
    output wire [2:0]                           m_axi_awsize,
    output wire [1:0]                           m_axi_awburst,
    output wire                                 m_axi_awlock,
    output wire [3:0]                           m_axi_awcache,
    output wire [2:0]                           m_axi_awprot,
    output wire                                 m_axi_awvalid,
    input  wire                                 m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]            m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]            m_axi_wstrb,
    output wire                                 m_axi_wlast,
    output wire                                 m_axi_wvalid,
    input  wire                                 m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]              m_axi_bid,
    input  wire [1:0]                           m_axi_bresp,
    input  wire                                 m_axi_bvalid,
    output wire                                 m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]              m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]            m_axi_araddr,
    output wire [7:0]                           m_axi_arlen,
    output wire [2:0]                           m_axi_arsize,
    output wire [1:0]                           m_axi_arburst,
    output wire                                 m_axi_arlock,
    output wire [3:0]                           m_axi_arcache,
    output wire [2:0]                           m_axi_arprot,
    output wire                                 m_axi_arvalid,
    input  wire                                 m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]              m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]            m_axi_rdata,
    input  wire [1:0]                           m_axi_rresp,
    input  wire                                 m_axi_rlast,
    input  wire                                 m_axi_rvalid,
    output wire                                 m_axi_rready,

    /*
     * AXI slave inteface
     */
    input  wire [AXI_ID_WIDTH-1:0]              s_axi_awid,
    input  wire [AXI_ADDR_WIDTH-1:0]            s_axi_awaddr,
    input  wire [7:0]                           s_axi_awlen,
    input  wire [2:0]                           s_axi_awsize,
    input  wire [1:0]                           s_axi_awburst,
    input  wire                                 s_axi_awlock,
    input  wire [3:0]                           s_axi_awcache,
    input  wire [2:0]                           s_axi_awprot,
    input  wire                                 s_axi_awvalid,
    output wire                                 s_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]            s_axi_wdata,
    input  wire [AXI_STRB_WIDTH-1:0]            s_axi_wstrb,
    input  wire                                 s_axi_wlast,
    input  wire                                 s_axi_wvalid,
    output wire                                 s_axi_wready,
    output wire [AXI_ID_WIDTH-1:0]              s_axi_bid,
    output wire [1:0]                           s_axi_bresp,
    output wire                                 s_axi_bvalid,
    input  wire                                 s_axi_bready,
    input  wire [AXI_ID_WIDTH-1:0]              s_axi_arid,
    input  wire [AXI_ADDR_WIDTH-1:0]            s_axi_araddr,
    input  wire [7:0]                           s_axi_arlen,
    input  wire [2:0]                           s_axi_arsize,
    input  wire [1:0]                           s_axi_arburst,
    input  wire                                 s_axi_arlock,
    input  wire [3:0]                           s_axi_arcache,
    input  wire [2:0]                           s_axi_arprot,
    input  wire                                 s_axi_arvalid,
    output wire                                 s_axi_arready,
    output wire [AXI_ID_WIDTH-1:0]              s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]            s_axi_rdata,
    output wire [1:0]                           s_axi_rresp,
    output wire                                 s_axi_rlast,
    output wire                                 s_axi_rvalid,
    input  wire                                 s_axi_rready,

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

parameter DESC_SIZE = 16;
parameter CPL_SIZE = 32;

parameter AXI_DMA_TAG_WIDTH = 8;
parameter AXI_DMA_LEN_WIDTH = 16;

parameter PCIE_DMA_TAG_WIDTH_INT = PCIE_DMA_TAG_WIDTH - $clog2(2);

// AXI lite connections
wire [AXIL_ADDR_WIDTH-1:0] axil_ctrl_awaddr;
wire [2:0]                 axil_ctrl_awprot;
wire                       axil_ctrl_awvalid;
wire                       axil_ctrl_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_ctrl_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_ctrl_wstrb;
wire                       axil_ctrl_wvalid;
wire                       axil_ctrl_wready;
wire [1:0]                 axil_ctrl_bresp;
wire                       axil_ctrl_bvalid;
wire                       axil_ctrl_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_ctrl_araddr;
wire [2:0]                 axil_ctrl_arprot;
wire                       axil_ctrl_arvalid;
wire                       axil_ctrl_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_ctrl_rdata;
wire [1:0]                 axil_ctrl_rresp;
wire                       axil_ctrl_rvalid;
wire                       axil_ctrl_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_sched_awaddr;
wire [2:0]                 axil_sched_awprot;
wire                       axil_sched_awvalid;
wire                       axil_sched_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_sched_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_sched_wstrb;
wire                       axil_sched_wvalid;
wire                       axil_sched_wready;
wire [1:0]                 axil_sched_bresp;
wire                       axil_sched_bvalid;
wire                       axil_sched_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_sched_araddr;
wire [2:0]                 axil_sched_arprot;
wire                       axil_sched_arvalid;
wire                       axil_sched_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_sched_rdata;
wire [1:0]                 axil_sched_rresp;
wire                       axil_sched_rvalid;
wire                       axil_sched_rready;

// AXI connections
wire [AXI_ID_WIDTH-1:0]    axi_tx_awid;
wire [AXI_ADDR_WIDTH-1:0]  axi_tx_awaddr;
wire [7:0]                 axi_tx_awlen;
wire [2:0]                 axi_tx_awsize;
wire [1:0]                 axi_tx_awburst;
wire                       axi_tx_awlock;
wire [3:0]                 axi_tx_awcache;
wire [2:0]                 axi_tx_awprot;
wire                       axi_tx_awvalid;
wire                       axi_tx_awready;
wire [AXI_DATA_WIDTH-1:0]  axi_tx_wdata;
wire [AXI_STRB_WIDTH-1:0]  axi_tx_wstrb;
wire                       axi_tx_wlast;
wire                       axi_tx_wvalid;
wire                       axi_tx_wready;
wire [AXI_ID_WIDTH-1:0]    axi_tx_bid;
wire [1:0]                 axi_tx_bresp;
wire                       axi_tx_bvalid;
wire                       axi_tx_bready;
wire [AXI_ID_WIDTH-1:0]    axi_tx_arid;
wire [AXI_ADDR_WIDTH-1:0]  axi_tx_araddr;
wire [7:0]                 axi_tx_arlen;
wire [2:0]                 axi_tx_arsize;
wire [1:0]                 axi_tx_arburst;
wire                       axi_tx_arlock;
wire [3:0]                 axi_tx_arcache;
wire [2:0]                 axi_tx_arprot;
wire                       axi_tx_arvalid;
wire                       axi_tx_arready;
wire [AXI_ID_WIDTH-1:0]    axi_tx_rid;
wire [AXI_DATA_WIDTH-1:0]  axi_tx_rdata;
wire [1:0]                 axi_tx_rresp;
wire                       axi_tx_rlast;
wire                       axi_tx_rvalid;
wire                       axi_tx_rready;

wire [AXI_ID_WIDTH-1:0]    axi_rx_awid;
wire [AXI_ADDR_WIDTH-1:0]  axi_rx_awaddr;
wire [7:0]                 axi_rx_awlen;
wire [2:0]                 axi_rx_awsize;
wire [1:0]                 axi_rx_awburst;
wire                       axi_rx_awlock;
wire [3:0]                 axi_rx_awcache;
wire [2:0]                 axi_rx_awprot;
wire                       axi_rx_awvalid;
wire                       axi_rx_awready;
wire [AXI_DATA_WIDTH-1:0]  axi_rx_wdata;
wire [AXI_STRB_WIDTH-1:0]  axi_rx_wstrb;
wire                       axi_rx_wlast;
wire                       axi_rx_wvalid;
wire                       axi_rx_wready;
wire [AXI_ID_WIDTH-1:0]    axi_rx_bid;
wire [1:0]                 axi_rx_bresp;
wire                       axi_rx_bvalid;
wire                       axi_rx_bready;
wire [AXI_ID_WIDTH-1:0]    axi_rx_arid;
wire [AXI_ADDR_WIDTH-1:0]  axi_rx_araddr;
wire [7:0]                 axi_rx_arlen;
wire [2:0]                 axi_rx_arsize;
wire [1:0]                 axi_rx_arburst;
wire                       axi_rx_arlock;
wire [3:0]                 axi_rx_arcache;
wire [2:0]                 axi_rx_arprot;
wire                       axi_rx_arvalid;
wire                       axi_rx_arready;
wire [AXI_ID_WIDTH-1:0]    axi_rx_rid;
wire [AXI_DATA_WIDTH-1:0]  axi_rx_rdata;
wire [1:0]                 axi_rx_rresp;
wire                       axi_rx_rlast;
wire                       axi_rx_rvalid;
wire                       axi_rx_rready;

// Checksumming
wire [AXIS_DATA_WIDTH-1:0] tx_axis_tdata_int;
wire [AXIS_KEEP_WIDTH-1:0] tx_axis_tkeep_int;
wire                       tx_axis_tvalid_int;
wire                       tx_axis_tready_int;
wire                       tx_axis_tlast_int;
wire                       tx_axis_tuser_int;

// PCIe DMA
wire [PCIE_ADDR_WIDTH-1:0]        tx_pcie_axi_dma_read_desc_pcie_addr;
wire [AXI_ADDR_WIDTH-1:0]         tx_pcie_axi_dma_read_desc_axi_addr;
wire [PCIE_DMA_LEN_WIDTH-1:0]     tx_pcie_axi_dma_read_desc_len;
wire [PCIE_DMA_TAG_WIDTH_INT-1:0] tx_pcie_axi_dma_read_desc_tag;
wire                              tx_pcie_axi_dma_read_desc_valid;
wire                              tx_pcie_axi_dma_read_desc_ready;

wire [PCIE_DMA_TAG_WIDTH_INT-1:0] tx_pcie_axi_dma_read_desc_status_tag;
wire                              tx_pcie_axi_dma_read_desc_status_valid;

wire [PCIE_ADDR_WIDTH-1:0]        tx_pcie_axi_dma_write_desc_pcie_addr;
wire [AXI_ADDR_WIDTH-1:0]         tx_pcie_axi_dma_write_desc_axi_addr;
wire [PCIE_DMA_LEN_WIDTH-1:0]     tx_pcie_axi_dma_write_desc_len;
wire [PCIE_DMA_TAG_WIDTH_INT-1:0] tx_pcie_axi_dma_write_desc_tag;
wire                              tx_pcie_axi_dma_write_desc_valid;
wire                              tx_pcie_axi_dma_write_desc_ready;

wire [PCIE_DMA_TAG_WIDTH_INT-1:0] tx_pcie_axi_dma_write_desc_status_tag;
wire                              tx_pcie_axi_dma_write_desc_status_valid;

wire [PCIE_ADDR_WIDTH-1:0]        rx_pcie_axi_dma_read_desc_pcie_addr;
wire [AXI_ADDR_WIDTH-1:0]         rx_pcie_axi_dma_read_desc_axi_addr;
wire [PCIE_DMA_LEN_WIDTH-1:0]     rx_pcie_axi_dma_read_desc_len;
wire [PCIE_DMA_TAG_WIDTH_INT-1:0] rx_pcie_axi_dma_read_desc_tag;
wire                              rx_pcie_axi_dma_read_desc_valid;
wire                              rx_pcie_axi_dma_read_desc_ready;

wire [PCIE_DMA_TAG_WIDTH_INT-1:0] rx_pcie_axi_dma_read_desc_status_tag;
wire                              rx_pcie_axi_dma_read_desc_status_valid;

wire [PCIE_ADDR_WIDTH-1:0]        rx_pcie_axi_dma_write_desc_pcie_addr;
wire [AXI_ADDR_WIDTH-1:0]         rx_pcie_axi_dma_write_desc_axi_addr;
wire [PCIE_DMA_LEN_WIDTH-1:0]     rx_pcie_axi_dma_write_desc_len;
wire [PCIE_DMA_TAG_WIDTH_INT-1:0] rx_pcie_axi_dma_write_desc_tag;
wire                              rx_pcie_axi_dma_write_desc_valid;
wire                              rx_pcie_axi_dma_write_desc_ready;

wire [PCIE_DMA_TAG_WIDTH_INT-1:0] rx_pcie_axi_dma_write_desc_status_tag;
wire                              rx_pcie_axi_dma_write_desc_status_valid;

// TX engine
wire [TX_QUEUE_INDEX_WIDTH-1:0] tx_req_queue;
wire [REQ_TAG_WIDTH-1:0]        tx_req_tag;
wire                            tx_req_valid;
wire                            tx_req_ready;

wire [AXI_DMA_LEN_WIDTH-1:0]    tx_req_status_len;
wire [REQ_TAG_WIDTH-1:0]        tx_req_status_tag;
wire                            tx_req_status_valid;

// RX engine
reg rx_frame_reg = 0;

wire [RX_QUEUE_INDEX_WIDTH-1:0] rx_req_queue = 0; // TODO RSS of some form
wire [REQ_TAG_WIDTH-1:0]        rx_req_tag = 0;
wire                            rx_req_valid = rx_axis_tvalid && !rx_frame_reg;
wire                            rx_req_ready;

wire [REQ_TAG_WIDTH-1:0]        rx_req_status_tag;
wire                            rx_req_status_valid;

always @(posedge clk) begin
    if (rx_axis_tready && rx_axis_tvalid) begin
        rx_frame_reg <= !rx_axis_tlast;
    end

    if (rst) begin
        rx_frame_reg <= 1'b0;
    end
end

// Timestamps
wire [95:0]              rx_ptp_ts_96;
wire                     rx_ptp_ts_valid;
wire                     rx_ptp_ts_ready;

wire [95:0]              tx_ptp_ts_96;
wire                     tx_ptp_ts_valid;
wire                     tx_ptp_ts_ready;

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
wire [AXI_ADDR_WIDTH-1:0]    dma_tx_desc_addr;
wire [AXI_DMA_LEN_WIDTH-1:0] dma_tx_desc_len;
wire [AXI_DMA_TAG_WIDTH-1:0] dma_tx_desc_tag;
wire                         dma_tx_desc_user;
wire                         dma_tx_desc_valid;
wire                         dma_tx_desc_ready;

wire [AXI_DMA_TAG_WIDTH-1:0] dma_tx_desc_status_tag;
wire                         dma_tx_desc_status_valid;

wire [AXI_ADDR_WIDTH-1:0]    dma_rx_desc_addr;
wire [AXI_DMA_LEN_WIDTH-1:0] dma_rx_desc_len;
wire [AXI_DMA_TAG_WIDTH-1:0] dma_rx_desc_tag;
wire                         dma_rx_desc_valid;
wire                         dma_rx_desc_ready;

wire [AXI_DMA_LEN_WIDTH-1:0] dma_rx_desc_status_len;
wire [AXI_DMA_TAG_WIDTH-1:0] dma_rx_desc_status_tag;
wire                         dma_rx_desc_status_user;
wire                         dma_rx_desc_status_valid;

wire                         dma_enable = 1;

// Port control registers
reg axil_ctrl_awready_reg = 1'b0;
reg axil_ctrl_wready_reg = 1'b0;
reg axil_ctrl_bvalid_reg = 1'b0;
reg axil_ctrl_arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] axil_ctrl_rdata_reg = {AXIL_DATA_WIDTH{1'b0}};
reg axil_ctrl_rvalid_reg = 1'b0;

reg sched_enable_reg = 1'b0;

reg tdma_enable_reg = 1'b0;
wire tdma_locked;
wire tdma_error;

reg [79:0] set_tdma_schedule_start_reg = 0;
reg set_tdma_schedule_start_valid_reg = 0;
reg [79:0] set_tdma_schedule_period_reg = 0;
reg set_tdma_schedule_period_valid_reg = 0;
reg [79:0] set_tdma_timeslot_period_reg = 0;
reg set_tdma_timeslot_period_valid_reg = 0;
reg [79:0] set_tdma_active_period_reg = 0;
reg set_tdma_active_period_valid_reg = 0;

wire tdma_schedule_start;
wire [TDMA_INDEX_WIDTH-1:0] tdma_timeslot_index;
wire tdma_timeslot_start;
wire tdma_timeslot_end;
wire tdma_timeslot_active;

assign axil_ctrl_awready = axil_ctrl_awready_reg;
assign axil_ctrl_wready = axil_ctrl_wready_reg;
assign axil_ctrl_bresp = 2'b00;
assign axil_ctrl_bvalid = axil_ctrl_bvalid_reg;
assign axil_ctrl_arready = axil_ctrl_arready_reg;
assign axil_ctrl_rdata = axil_ctrl_rdata_reg;
assign axil_ctrl_rresp = 2'b00;
assign axil_ctrl_rvalid = axil_ctrl_rvalid_reg;

always @(posedge clk) begin
    axil_ctrl_awready_reg <= 1'b0;
    axil_ctrl_wready_reg <= 1'b0;
    axil_ctrl_bvalid_reg <= axil_ctrl_bvalid_reg && !axil_ctrl_bready;
    axil_ctrl_arready_reg <= 1'b0;
    axil_ctrl_rvalid_reg <= axil_ctrl_rvalid_reg && !axil_ctrl_rready;

    set_tdma_schedule_start_valid_reg <= 1'b0;
    set_tdma_schedule_period_valid_reg <= 1'b0;
    set_tdma_timeslot_period_valid_reg <= 1'b0;
    set_tdma_active_period_valid_reg <= 1'b0;

    if (axil_ctrl_awvalid && axil_ctrl_wvalid && !axil_ctrl_bvalid) begin
        // write operation
        axil_ctrl_awready_reg <= 1'b1;
        axil_ctrl_wready_reg <= 1'b1;
        axil_ctrl_bvalid_reg <= 1'b1;

        case ({axil_ctrl_awaddr[15:2], 2'b00})
            16'h0040: begin
                // Scheduler enable
                if (axil_ctrl_wstrb[0]) begin
                    sched_enable_reg <= axil_ctrl_wdata[0];
                end
            end
            16'h0100: begin
                // TDMA control
                if (axil_ctrl_wstrb[0]) begin
                    tdma_enable_reg <= axil_ctrl_wdata[0];
                end
            end
            16'h0114: set_tdma_schedule_start_reg[29:0] <= axil_ctrl_wdata; // TDMA schedule start ns
            16'h0118: set_tdma_schedule_start_reg[63:32] <= axil_ctrl_wdata; // TDMA schedule start sec l
            16'h011C: begin
                // TDMA schedule start sec h
                set_tdma_schedule_start_reg[79:64] <= axil_ctrl_wdata;
                set_tdma_schedule_start_valid_reg <= 1'b1;
            end
            16'h0124: set_tdma_schedule_period_reg[29:0] <= axil_ctrl_wdata; // TDMA schedule period ns
            16'h0128: set_tdma_schedule_period_reg[63:32] <= axil_ctrl_wdata; // TDMA schedule period sec l
            16'h012C: begin
                // TDMA schedule period sec h
                set_tdma_schedule_period_reg[79:64] <= axil_ctrl_wdata;
                set_tdma_schedule_period_valid_reg <= 1'b1;
            end
            16'h0134: set_tdma_timeslot_period_reg[29:0] <= axil_ctrl_wdata; // TDMA timeslot period ns
            16'h0138: set_tdma_timeslot_period_reg[63:32] <= axil_ctrl_wdata; // TDMA timeslot period sec l
            16'h013C: begin
                // TDMA timeslot period sec h
                set_tdma_timeslot_period_reg[79:64] <= axil_ctrl_wdata;
                set_tdma_timeslot_period_valid_reg <= 1'b1;
            end
            16'h0144: set_tdma_active_period_reg[29:0] <= axil_ctrl_wdata; // TDMA active period ns
            16'h0148: set_tdma_active_period_reg[63:32] <= axil_ctrl_wdata; // TDMA active period sec l
            16'h014C: begin
                // TDMA active period sec h
                set_tdma_active_period_reg[79:64] <= axil_ctrl_wdata;
                set_tdma_active_period_valid_reg <= 1'b1;
            end
        endcase
    end

    if (axil_ctrl_arvalid && !axil_ctrl_rvalid) begin
        // read operation
        axil_ctrl_arready_reg <= 1'b1;
        axil_ctrl_rvalid_reg <= 1'b1;
        axil_ctrl_rdata_reg <= {AXIL_DATA_WIDTH{1'b0}};

        case ({axil_ctrl_araddr[15:2], 2'b00})
            16'h0000: axil_ctrl_rdata_reg <= 32'd0;       // port_id
            16'h0004: begin
                // port_features
                axil_ctrl_rdata_reg[4] <= PTP_TS_ENABLE;
                axil_ctrl_rdata_reg[8] <= TX_CHECKSUM_ENABLE;
                axil_ctrl_rdata_reg[9] <= RX_CHECKSUM_ENABLE;
            end
            16'h0010: axil_ctrl_rdata_reg <= 1;           // scheduler_count
            16'h0014: axil_ctrl_rdata_reg <= 24'h040000;  // scheduler_offset
            16'h0018: axil_ctrl_rdata_reg <= 24'h040000;  // scheduler_stride
            16'h001C: axil_ctrl_rdata_reg <= 32'd0;       // scheduler_type
            16'h0040: begin
                // Scheduler enable
                axil_ctrl_rdata_reg[0] <= sched_enable_reg;
            end
            16'h0100: begin
                // TDMA control
                axil_ctrl_rdata_reg[0] <= tdma_enable_reg;
            end
            16'h0104: begin
                // TDMA status
                axil_ctrl_rdata_reg[0] <= tdma_locked;
                axil_ctrl_rdata_reg[1] <= tdma_error;
            end
            16'h0114: axil_ctrl_rdata_reg <= set_tdma_schedule_start_reg[29:0]; // TDMA schedule start ns
            16'h0118: axil_ctrl_rdata_reg <= set_tdma_schedule_start_reg[63:32]; // TDMA schedule start sec l
            16'h011C: axil_ctrl_rdata_reg <= set_tdma_schedule_start_reg[79:64]; // TDMA schedule start sec h
            16'h0124: axil_ctrl_rdata_reg <= set_tdma_schedule_period_reg[29:0]; // TDMA schedule period ns
            16'h0128: axil_ctrl_rdata_reg <= set_tdma_schedule_period_reg[63:32]; // TDMA schedule period sec l
            16'h012C: axil_ctrl_rdata_reg <= set_tdma_schedule_period_reg[79:64]; // TDMA schedule period sec h
            16'h0134: axil_ctrl_rdata_reg <= set_tdma_timeslot_period_reg[29:0]; // TDMA timeslot period ns
            16'h0138: axil_ctrl_rdata_reg <= set_tdma_timeslot_period_reg[63:32]; // TDMA timeslot period sec l
            16'h013C: axil_ctrl_rdata_reg <= set_tdma_timeslot_period_reg[79:64]; // TDMA timeslot period sec h
            16'h0144: axil_ctrl_rdata_reg <= set_tdma_active_period_reg[29:0]; // TDMA active period ns
            16'h0148: axil_ctrl_rdata_reg <= set_tdma_active_period_reg[63:32]; // TDMA active period sec l
            16'h014C: axil_ctrl_rdata_reg <= set_tdma_active_period_reg[79:64]; // TDMA active period sec h
        endcase
    end

    if (rst) begin
        axil_ctrl_awready_reg <= 1'b0;
        axil_ctrl_wready_reg <= 1'b0;
        axil_ctrl_bvalid_reg <= 1'b0;
        axil_ctrl_arready_reg <= 1'b0;
        axil_ctrl_rvalid_reg <= 1'b0;

        sched_enable_reg <= 1'b0;
        tdma_enable_reg <= 1'b0;
    end
end

// AXI lite interconnect
parameter AXIL_S_COUNT = 1;
parameter AXIL_M_COUNT = 2;

axil_interconnect #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .S_COUNT(AXIL_S_COUNT),
    .M_COUNT(AXIL_M_COUNT),
    .M_BASE_ADDR({23'h040000, 23'h000000}),
    .M_ADDR_WIDTH({32'd18, 32'd18}),
    .M_CONNECT_READ({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}})
)
axil_interconnect_inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(s_axil_awaddr & 23'h0fffff),
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
    .s_axil_araddr(s_axil_araddr & 23'h0fffff),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .m_axil_awaddr( {axil_sched_awaddr,  axil_ctrl_awaddr}),
    .m_axil_awprot( {axil_sched_awprot,  axil_ctrl_awprot}),
    .m_axil_awvalid({axil_sched_awvalid, axil_ctrl_awvalid}),
    .m_axil_awready({axil_sched_awready, axil_ctrl_awready}),
    .m_axil_wdata(  {axil_sched_wdata,   axil_ctrl_wdata}),
    .m_axil_wstrb(  {axil_sched_wstrb,   axil_ctrl_wstrb}),
    .m_axil_wvalid( {axil_sched_wvalid,  axil_ctrl_wvalid}),
    .m_axil_wready( {axil_sched_wready,  axil_ctrl_wready}),
    .m_axil_bresp(  {axil_sched_bresp,   axil_ctrl_bresp}),
    .m_axil_bvalid( {axil_sched_bvalid,  axil_ctrl_bvalid}),
    .m_axil_bready( {axil_sched_bready,  axil_ctrl_bready}),
    .m_axil_araddr( {axil_sched_araddr,  axil_ctrl_araddr}),
    .m_axil_arprot( {axil_sched_arprot,  axil_ctrl_arprot}),
    .m_axil_arvalid({axil_sched_arvalid, axil_ctrl_arvalid}),
    .m_axil_arready({axil_sched_arready, axil_ctrl_arready}),
    .m_axil_rdata(  {axil_sched_rdata,   axil_ctrl_rdata}),
    .m_axil_rresp(  {axil_sched_rresp,   axil_ctrl_rresp}),
    .m_axil_rvalid( {axil_sched_rvalid,  axil_ctrl_rvalid}),
    .m_axil_rready( {axil_sched_rready,  axil_ctrl_rready})
);

pcie_axi_dma_desc_mux #(
    .PORTS(2),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .S_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
    .M_TAG_WIDTH(PCIE_DMA_TAG_WIDTH),
    .ARB_TYPE("ROUND_ROBIN"),
    .LSB_PRIORITY("HIGH")
)
pcie_axi_dma_read_desc_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor output
     */
    .m_axis_desc_pcie_addr(m_axis_pcie_axi_dma_read_desc_pcie_addr),
    .m_axis_desc_axi_addr(m_axis_pcie_axi_dma_read_desc_axi_addr),
    .m_axis_desc_len(m_axis_pcie_axi_dma_read_desc_len),
    .m_axis_desc_tag(m_axis_pcie_axi_dma_read_desc_tag),
    .m_axis_desc_valid(m_axis_pcie_axi_dma_read_desc_valid),
    .m_axis_desc_ready(m_axis_pcie_axi_dma_read_desc_ready),

    /*
     * Descriptor status input
     */
    .s_axis_desc_status_tag(s_axis_pcie_axi_dma_read_desc_status_tag),
    .s_axis_desc_status_valid(s_axis_pcie_axi_dma_read_desc_status_valid),

    /*
     * Descriptor input
     */
    .s_axis_desc_pcie_addr({rx_pcie_axi_dma_read_desc_pcie_addr, tx_pcie_axi_dma_read_desc_pcie_addr}),
    .s_axis_desc_axi_addr({rx_pcie_axi_dma_read_desc_axi_addr, tx_pcie_axi_dma_read_desc_axi_addr}),
    .s_axis_desc_len({rx_pcie_axi_dma_read_desc_len, tx_pcie_axi_dma_read_desc_len}),
    .s_axis_desc_tag({rx_pcie_axi_dma_read_desc_tag, tx_pcie_axi_dma_read_desc_tag}),
    .s_axis_desc_valid({rx_pcie_axi_dma_read_desc_valid, tx_pcie_axi_dma_read_desc_valid}),
    .s_axis_desc_ready({rx_pcie_axi_dma_read_desc_ready, tx_pcie_axi_dma_read_desc_ready}),

    /*
     * Descriptor status output
     */
    .m_axis_desc_status_tag({rx_pcie_axi_dma_read_desc_status_tag, tx_pcie_axi_dma_read_desc_status_tag}),
    .m_axis_desc_status_valid({rx_pcie_axi_dma_read_desc_status_valid, tx_pcie_axi_dma_read_desc_status_valid})
);

pcie_axi_dma_desc_mux #(
    .PORTS(2),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .S_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
    .M_TAG_WIDTH(PCIE_DMA_TAG_WIDTH),
    .ARB_TYPE("ROUND_ROBIN"),
    .LSB_PRIORITY("HIGH")
)
pcie_axi_dma_write_desc_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor output
     */
    .m_axis_desc_pcie_addr(m_axis_pcie_axi_dma_write_desc_pcie_addr),
    .m_axis_desc_axi_addr(m_axis_pcie_axi_dma_write_desc_axi_addr),
    .m_axis_desc_len(m_axis_pcie_axi_dma_write_desc_len),
    .m_axis_desc_tag(m_axis_pcie_axi_dma_write_desc_tag),
    .m_axis_desc_valid(m_axis_pcie_axi_dma_write_desc_valid),
    .m_axis_desc_ready(m_axis_pcie_axi_dma_write_desc_ready),

    /*
     * Descriptor status input
     */
    .s_axis_desc_status_tag(s_axis_pcie_axi_dma_write_desc_status_tag),
    .s_axis_desc_status_valid(s_axis_pcie_axi_dma_write_desc_status_valid),

    /*
     * Descriptor input
     */
    .s_axis_desc_pcie_addr({rx_pcie_axi_dma_write_desc_pcie_addr, tx_pcie_axi_dma_write_desc_pcie_addr}),
    .s_axis_desc_axi_addr({rx_pcie_axi_dma_write_desc_axi_addr, tx_pcie_axi_dma_write_desc_axi_addr}),
    .s_axis_desc_len({rx_pcie_axi_dma_write_desc_len, tx_pcie_axi_dma_write_desc_len}),
    .s_axis_desc_tag({rx_pcie_axi_dma_write_desc_tag, tx_pcie_axi_dma_write_desc_tag}),
    .s_axis_desc_valid({rx_pcie_axi_dma_write_desc_valid, tx_pcie_axi_dma_write_desc_valid}),
    .s_axis_desc_ready({rx_pcie_axi_dma_write_desc_ready, tx_pcie_axi_dma_write_desc_ready}),

    /*
     * Descriptor status output
     */
    .m_axis_desc_status_tag({rx_pcie_axi_dma_write_desc_status_tag, tx_pcie_axi_dma_write_desc_status_tag}),
    .m_axis_desc_status_valid({rx_pcie_axi_dma_write_desc_status_valid, tx_pcie_axi_dma_write_desc_status_valid})
);

generate

if (TX_SCHEDULER == "RR") begin

    tx_scheduler_rr #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(20),
        .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
        .AXI_DMA_LEN_WIDTH(AXI_DMA_LEN_WIDTH),
        .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
        .OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
        .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
        .PIPELINE(3)
    )
    tx_scheduler_inst (
        .clk(clk),
        .rst(rst),

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
         * AXI-Lite slave interface
         */
        .s_axil_awaddr(axil_sched_awaddr),
        .s_axil_awprot(axil_sched_awprot),
        .s_axil_awvalid(axil_sched_awvalid),
        .s_axil_awready(axil_sched_awready),
        .s_axil_wdata(axil_sched_wdata),
        .s_axil_wstrb(axil_sched_wstrb),
        .s_axil_wvalid(axil_sched_wvalid),
        .s_axil_wready(axil_sched_wready),
        .s_axil_bresp(axil_sched_bresp),
        .s_axil_bvalid(axil_sched_bvalid),
        .s_axil_bready(axil_sched_bready),
        .s_axil_araddr(axil_sched_araddr),
        .s_axil_arprot(axil_sched_arprot),
        .s_axil_arvalid(axil_sched_arvalid),
        .s_axil_arready(axil_sched_arready),
        .s_axil_rdata(axil_sched_rdata),
        .s_axil_rresp(axil_sched_rresp),
        .s_axil_rvalid(axil_sched_rvalid),
        .s_axil_rready(axil_sched_rready),

        /*
         * Control
         */
        .enable(sched_enable_reg),
        .active()
    );
    
end else if (TX_SCHEDULER == "TDMA_RR") begin

    tx_scheduler_tdma_rr #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(20),
        .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
        .AXI_DMA_LEN_WIDTH(AXI_DMA_LEN_WIDTH),
        .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
        .TDMA_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
        .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
        .SCHEDULE_START_S(48'h0),
        .SCHEDULE_START_NS(30'h0),
        .SCHEDULE_PERIOD_S(48'd0),
        .SCHEDULE_PERIOD_NS(30'd1000000),
        .TIMESLOT_PERIOD_S(48'd0),
        .TIMESLOT_PERIOD_NS(30'd100000),
        .ACTIVE_PERIOD_S(48'd0),
        .ACTIVE_PERIOD_NS(30'd100000)
    )
    tx_scheduler_inst (
        .clk(clk),
        .rst(rst),

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
         * AXI-Lite slave interface
         */
        .s_axil_awaddr(axil_sched_awaddr),
        .s_axil_awprot(axil_sched_awprot),
        .s_axil_awvalid(axil_sched_awvalid),
        .s_axil_awready(axil_sched_awready),
        .s_axil_wdata(axil_sched_wdata),
        .s_axil_wstrb(axil_sched_wstrb),
        .s_axil_wvalid(axil_sched_wvalid),
        .s_axil_wready(axil_sched_wready),
        .s_axil_bresp(axil_sched_bresp),
        .s_axil_bvalid(axil_sched_bvalid),
        .s_axil_bready(axil_sched_bready),
        .s_axil_araddr(axil_sched_araddr),
        .s_axil_arprot(axil_sched_arprot),
        .s_axil_arvalid(axil_sched_arvalid),
        .s_axil_arready(axil_sched_arready),
        .s_axil_rdata(axil_sched_rdata),
        .s_axil_rresp(axil_sched_rresp),
        .s_axil_rvalid(axil_sched_rvalid),
        .s_axil_rready(axil_sched_rready),

        /*
         * PTP clock
         */
        .ptp_ts_96(ptp_ts_96),
        .ptp_ts_step(ptp_ts_step)
    );

end

endgenerate

tx_engine #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_DMA_LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .AXI_DMA_LEN_WIDTH(AXI_DMA_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .PCIE_DMA_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
    .AXI_DMA_TAG_WIDTH(AXI_DMA_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .PKT_TABLE_SIZE(TX_PKT_TABLE_SIZE),
    .AXI_BASE_ADDR(AXI_BASE_ADDR + 24'h004000),
    .SCRATCH_PKT_AXI_ADDR(TX_RAM_AXI_BASE_ADDR),
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
     * Descriptor dequeue request output
     */
    .m_axis_desc_dequeue_req_queue(m_axis_tx_desc_dequeue_req_queue),
    .m_axis_desc_dequeue_req_tag(m_axis_tx_desc_dequeue_req_tag),
    .m_axis_desc_dequeue_req_valid(m_axis_tx_desc_dequeue_req_valid),
    .m_axis_desc_dequeue_req_ready(m_axis_tx_desc_dequeue_req_ready),

    /*
     * Descriptor dequeue response input
     */
    .s_axis_desc_dequeue_resp_queue(s_axis_tx_desc_dequeue_resp_queue),
    .s_axis_desc_dequeue_resp_ptr(s_axis_tx_desc_dequeue_resp_ptr),
    .s_axis_desc_dequeue_resp_addr(s_axis_tx_desc_dequeue_resp_addr),
    .s_axis_desc_dequeue_resp_cpl(s_axis_tx_desc_dequeue_resp_cpl),
    .s_axis_desc_dequeue_resp_tag(s_axis_tx_desc_dequeue_resp_tag),
    .s_axis_desc_dequeue_resp_op_tag(s_axis_tx_desc_dequeue_resp_op_tag),
    .s_axis_desc_dequeue_resp_empty(s_axis_tx_desc_dequeue_resp_empty),
    .s_axis_desc_dequeue_resp_error(s_axis_tx_desc_dequeue_resp_error),
    .s_axis_desc_dequeue_resp_valid(s_axis_tx_desc_dequeue_resp_valid),
    .s_axis_desc_dequeue_resp_ready(s_axis_tx_desc_dequeue_resp_ready),

    /*
     * Descriptor dequeue commit output
     */
    .m_axis_desc_dequeue_commit_op_tag(m_axis_tx_desc_dequeue_commit_op_tag),
    .m_axis_desc_dequeue_commit_valid(m_axis_tx_desc_dequeue_commit_valid),
    .m_axis_desc_dequeue_commit_ready(m_axis_tx_desc_dequeue_commit_ready),

    /*
     * Completion enqueue request output
     */
    .m_axis_cpl_enqueue_req_queue(m_axis_tx_cpl_enqueue_req_queue),
    .m_axis_cpl_enqueue_req_tag(m_axis_tx_cpl_enqueue_req_tag),
    .m_axis_cpl_enqueue_req_valid(m_axis_tx_cpl_enqueue_req_valid),
    .m_axis_cpl_enqueue_req_ready(m_axis_tx_cpl_enqueue_req_ready),

    /*
     * Completion enqueue response input
     */
    .s_axis_cpl_enqueue_resp_addr(s_axis_tx_cpl_enqueue_resp_addr),
    .s_axis_cpl_enqueue_resp_tag(s_axis_tx_cpl_enqueue_resp_tag),
    .s_axis_cpl_enqueue_resp_op_tag(s_axis_tx_cpl_enqueue_resp_op_tag),
    .s_axis_cpl_enqueue_resp_full(s_axis_tx_cpl_enqueue_resp_full),
    .s_axis_cpl_enqueue_resp_error(s_axis_tx_cpl_enqueue_resp_error),
    .s_axis_cpl_enqueue_resp_valid(s_axis_tx_cpl_enqueue_resp_valid),
    .s_axis_cpl_enqueue_resp_ready(s_axis_tx_cpl_enqueue_resp_ready),

    /*
     * Completion enqueue commit output
     */
    .m_axis_cpl_enqueue_commit_op_tag(m_axis_tx_cpl_enqueue_commit_op_tag),
    .m_axis_cpl_enqueue_commit_valid(m_axis_tx_cpl_enqueue_commit_valid),
    .m_axis_cpl_enqueue_commit_ready(m_axis_tx_cpl_enqueue_commit_ready),

    /*
     * PCIe DMA read descriptor output
     */
    .m_axis_pcie_axi_dma_read_desc_pcie_addr(tx_pcie_axi_dma_read_desc_pcie_addr),
    .m_axis_pcie_axi_dma_read_desc_axi_addr(tx_pcie_axi_dma_read_desc_axi_addr),
    .m_axis_pcie_axi_dma_read_desc_len(tx_pcie_axi_dma_read_desc_len),
    .m_axis_pcie_axi_dma_read_desc_tag(tx_pcie_axi_dma_read_desc_tag),
    .m_axis_pcie_axi_dma_read_desc_valid(tx_pcie_axi_dma_read_desc_valid),
    .m_axis_pcie_axi_dma_read_desc_ready(tx_pcie_axi_dma_read_desc_ready),

    /*
     * PCIe DMA read descriptor status input
     */
    .s_axis_pcie_axi_dma_read_desc_status_tag(tx_pcie_axi_dma_read_desc_status_tag),
    .s_axis_pcie_axi_dma_read_desc_status_valid(tx_pcie_axi_dma_read_desc_status_valid),

    /*
     * PCIe DMA write descriptor output
     */
    .m_axis_pcie_axi_dma_write_desc_pcie_addr(tx_pcie_axi_dma_write_desc_pcie_addr),
    .m_axis_pcie_axi_dma_write_desc_axi_addr(tx_pcie_axi_dma_write_desc_axi_addr),
    .m_axis_pcie_axi_dma_write_desc_len(tx_pcie_axi_dma_write_desc_len),
    .m_axis_pcie_axi_dma_write_desc_tag(tx_pcie_axi_dma_write_desc_tag),
    .m_axis_pcie_axi_dma_write_desc_valid(tx_pcie_axi_dma_write_desc_valid),
    .m_axis_pcie_axi_dma_write_desc_ready(tx_pcie_axi_dma_write_desc_ready),

    /*
     * PCIe DMA write descriptor status input
     */
    .s_axis_pcie_axi_dma_write_desc_status_tag(tx_pcie_axi_dma_write_desc_status_tag),
    .s_axis_pcie_axi_dma_write_desc_status_valid(tx_pcie_axi_dma_write_desc_status_valid),

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
     * AXI slave interface
     */
    .s_axi_awid(axi_tx_awid),
    .s_axi_awaddr(axi_tx_awaddr),
    .s_axi_awlen(axi_tx_awlen),
    .s_axi_awsize(axi_tx_awsize),
    .s_axi_awburst(axi_tx_awburst),
    .s_axi_awlock(axi_tx_awlock),
    .s_axi_awcache(axi_tx_awcache),
    .s_axi_awprot(axi_tx_awprot),
    .s_axi_awvalid(axi_tx_awvalid),
    .s_axi_awready(axi_tx_awready),
    .s_axi_wdata(axi_tx_wdata),
    .s_axi_wstrb(axi_tx_wstrb),
    .s_axi_wlast(axi_tx_wlast),
    .s_axi_wvalid(axi_tx_wvalid),
    .s_axi_wready(axi_tx_wready),
    .s_axi_bid(axi_tx_bid),
    .s_axi_bresp(axi_tx_bresp),
    .s_axi_bvalid(axi_tx_bvalid),
    .s_axi_bready(axi_tx_bready),
    .s_axi_arid(axi_tx_arid),
    .s_axi_araddr(axi_tx_araddr),
    .s_axi_arlen(axi_tx_arlen),
    .s_axi_arsize(axi_tx_arsize),
    .s_axi_arburst(axi_tx_arburst),
    .s_axi_arlock(axi_tx_arlock),
    .s_axi_arcache(axi_tx_arcache),
    .s_axi_arprot(axi_tx_arprot),
    .s_axi_arvalid(axi_tx_arvalid),
    .s_axi_arready(axi_tx_arready),
    .s_axi_rid(axi_tx_rid),
    .s_axi_rdata(axi_tx_rdata),
    .s_axi_rresp(axi_tx_rresp),
    .s_axi_rlast(axi_tx_rlast),
    .s_axi_rvalid(axi_tx_rvalid),
    .s_axi_rready(axi_tx_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

rx_engine #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_DMA_LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .AXI_DMA_LEN_WIDTH(AXI_DMA_LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .PCIE_DMA_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
    .AXI_DMA_TAG_WIDTH(AXI_DMA_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
    .PKT_TABLE_SIZE(RX_PKT_TABLE_SIZE),
    .AXI_BASE_ADDR(AXI_BASE_ADDR + 24'h006000),
    .SCRATCH_PKT_AXI_ADDR(RX_RAM_AXI_BASE_ADDR),
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
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
     * Descriptor dequeue request output
     */
    .m_axis_desc_dequeue_req_queue(m_axis_rx_desc_dequeue_req_queue),
    .m_axis_desc_dequeue_req_tag(m_axis_rx_desc_dequeue_req_tag),
    .m_axis_desc_dequeue_req_valid(m_axis_rx_desc_dequeue_req_valid),
    .m_axis_desc_dequeue_req_ready(m_axis_rx_desc_dequeue_req_ready),

    /*
     * Descriptor dequeue response input
     */
    .s_axis_desc_dequeue_resp_queue(s_axis_rx_desc_dequeue_resp_queue),
    .s_axis_desc_dequeue_resp_ptr(s_axis_rx_desc_dequeue_resp_ptr),
    .s_axis_desc_dequeue_resp_addr(s_axis_rx_desc_dequeue_resp_addr),
    .s_axis_desc_dequeue_resp_cpl(s_axis_rx_desc_dequeue_resp_cpl),
    .s_axis_desc_dequeue_resp_tag(s_axis_rx_desc_dequeue_resp_tag),
    .s_axis_desc_dequeue_resp_op_tag(s_axis_rx_desc_dequeue_resp_op_tag),
    .s_axis_desc_dequeue_resp_empty(s_axis_rx_desc_dequeue_resp_empty),
    .s_axis_desc_dequeue_resp_error(s_axis_rx_desc_dequeue_resp_error),
    .s_axis_desc_dequeue_resp_valid(s_axis_rx_desc_dequeue_resp_valid),
    .s_axis_desc_dequeue_resp_ready(s_axis_rx_desc_dequeue_resp_ready),

    /*
     * Descriptor dequeue commit output
     */
    .m_axis_desc_dequeue_commit_op_tag(m_axis_rx_desc_dequeue_commit_op_tag),
    .m_axis_desc_dequeue_commit_valid(m_axis_rx_desc_dequeue_commit_valid),
    .m_axis_desc_dequeue_commit_ready(m_axis_rx_desc_dequeue_commit_ready),

    /*
     * Completion enqueue request output
     */
    .m_axis_cpl_enqueue_req_queue(m_axis_rx_cpl_enqueue_req_queue),
    .m_axis_cpl_enqueue_req_tag(m_axis_rx_cpl_enqueue_req_tag),
    .m_axis_cpl_enqueue_req_valid(m_axis_rx_cpl_enqueue_req_valid),
    .m_axis_cpl_enqueue_req_ready(m_axis_rx_cpl_enqueue_req_ready),

    /*
     * Completion enqueue response input
     */
    .s_axis_cpl_enqueue_resp_addr(s_axis_rx_cpl_enqueue_resp_addr),
    .s_axis_cpl_enqueue_resp_tag(s_axis_rx_cpl_enqueue_resp_tag),
    .s_axis_cpl_enqueue_resp_op_tag(s_axis_rx_cpl_enqueue_resp_op_tag),
    .s_axis_cpl_enqueue_resp_full(s_axis_rx_cpl_enqueue_resp_full),
    .s_axis_cpl_enqueue_resp_error(s_axis_rx_cpl_enqueue_resp_error),
    .s_axis_cpl_enqueue_resp_valid(s_axis_rx_cpl_enqueue_resp_valid),
    .s_axis_cpl_enqueue_resp_ready(s_axis_rx_cpl_enqueue_resp_ready),

    /*
     * Completion enqueue commit output
     */
    .m_axis_cpl_enqueue_commit_op_tag(m_axis_rx_cpl_enqueue_commit_op_tag),
    .m_axis_cpl_enqueue_commit_valid(m_axis_rx_cpl_enqueue_commit_valid),
    .m_axis_cpl_enqueue_commit_ready(m_axis_rx_cpl_enqueue_commit_ready),

    /*
     * PCIe DMA read descriptor output
     */
    .m_axis_pcie_axi_dma_read_desc_pcie_addr(rx_pcie_axi_dma_read_desc_pcie_addr),
    .m_axis_pcie_axi_dma_read_desc_axi_addr(rx_pcie_axi_dma_read_desc_axi_addr),
    .m_axis_pcie_axi_dma_read_desc_len(rx_pcie_axi_dma_read_desc_len),
    .m_axis_pcie_axi_dma_read_desc_tag(rx_pcie_axi_dma_read_desc_tag),
    .m_axis_pcie_axi_dma_read_desc_valid(rx_pcie_axi_dma_read_desc_valid),
    .m_axis_pcie_axi_dma_read_desc_ready(rx_pcie_axi_dma_read_desc_ready),

    /*
     * PCIe DMA read descriptor status input
     */
    .s_axis_pcie_axi_dma_read_desc_status_tag(rx_pcie_axi_dma_read_desc_status_tag),
    .s_axis_pcie_axi_dma_read_desc_status_valid(rx_pcie_axi_dma_read_desc_status_valid),

    /*
     * PCIe DMA write descriptor output
     */
    .m_axis_pcie_axi_dma_write_desc_pcie_addr(rx_pcie_axi_dma_write_desc_pcie_addr),
    .m_axis_pcie_axi_dma_write_desc_axi_addr(rx_pcie_axi_dma_write_desc_axi_addr),
    .m_axis_pcie_axi_dma_write_desc_len(rx_pcie_axi_dma_write_desc_len),
    .m_axis_pcie_axi_dma_write_desc_tag(rx_pcie_axi_dma_write_desc_tag),
    .m_axis_pcie_axi_dma_write_desc_valid(rx_pcie_axi_dma_write_desc_valid),
    .m_axis_pcie_axi_dma_write_desc_ready(rx_pcie_axi_dma_write_desc_ready),

    /*
     * PCIe DMA write descriptor status input
     */
    .s_axis_pcie_axi_dma_write_desc_status_tag(rx_pcie_axi_dma_write_desc_status_tag),
    .s_axis_pcie_axi_dma_write_desc_status_valid(rx_pcie_axi_dma_write_desc_status_valid),

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
    .s_axis_rx_desc_status_valid(dma_rx_desc_status_valid),

    /*
     * Receive timestamp input
     */
    .s_axis_rx_ptp_ts_96(s_axis_rx_ptp_ts_96),
    .s_axis_rx_ptp_ts_valid(s_axis_rx_ptp_ts_valid),
    .s_axis_rx_ptp_ts_ready(s_axis_rx_ptp_ts_ready),

    /*
     * Receive checksum input
     */
    .s_axis_rx_csum(rx_fifo_csum),
    .s_axis_rx_csum_valid(rx_fifo_csum_valid),
    .s_axis_rx_csum_ready(rx_fifo_csum_ready),

    /*
     * AXI slave interface
     */
    .s_axi_awid(axi_rx_awid),
    .s_axi_awaddr(axi_rx_awaddr),
    .s_axi_awlen(axi_rx_awlen),
    .s_axi_awsize(axi_rx_awsize),
    .s_axi_awburst(axi_rx_awburst),
    .s_axi_awlock(axi_rx_awlock),
    .s_axi_awcache(axi_rx_awcache),
    .s_axi_awprot(axi_rx_awprot),
    .s_axi_awvalid(axi_rx_awvalid),
    .s_axi_awready(axi_rx_awready),
    .s_axi_wdata(axi_rx_wdata),
    .s_axi_wstrb(axi_rx_wstrb),
    .s_axi_wlast(axi_rx_wlast),
    .s_axi_wvalid(axi_rx_wvalid),
    .s_axi_wready(axi_rx_wready),
    .s_axi_bid(axi_rx_bid),
    .s_axi_bresp(axi_rx_bresp),
    .s_axi_bvalid(axi_rx_bvalid),
    .s_axi_bready(axi_rx_bready),
    .s_axi_arid(axi_rx_arid),
    .s_axi_araddr(axi_rx_araddr),
    .s_axi_arlen(axi_rx_arlen),
    .s_axi_arsize(axi_rx_arsize),
    .s_axi_arburst(axi_rx_arburst),
    .s_axi_arlock(axi_rx_arlock),
    .s_axi_arcache(axi_rx_arcache),
    .s_axi_arprot(axi_rx_arprot),
    .s_axi_arvalid(axi_rx_arvalid),
    .s_axi_arready(axi_rx_arready),
    .s_axi_rid(axi_rx_rid),
    .s_axi_rdata(axi_rx_rdata),
    .s_axi_rresp(axi_rx_rresp),
    .s_axi_rlast(axi_rx_rlast),
    .s_axi_rvalid(axi_rx_rvalid),
    .s_axi_rready(axi_rx_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

generate

if (RX_CHECKSUM_ENABLE) begin

    rx_checksum #(
        .DATA_WIDTH(AXI_DATA_WIDTH)
    )
    rx_checksum_inst (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(rx_axis_tdata),
        .s_axis_tkeep(rx_axis_tkeep),
        .s_axis_tvalid(rx_axis_tvalid & rx_axis_tready),
        .s_axis_tlast(rx_axis_tlast),
        .m_axis_csum(rx_csum),
        .m_axis_csum_valid(rx_csum_valid)
    );

    axis_fifo #(
        .DEPTH(16),
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
        .DEPTH(16),
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
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(1),
        .USER_WIDTH(1),
        .USE_INIT_VALUE(0),
        .DATA_FIFO_DEPTH(4096),
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

axi_dma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(AXI_DMA_LEN_WIDTH),
    .TAG_WIDTH(AXI_DMA_TAG_WIDTH),
    .ENABLE_SG(0),
    .ENABLE_UNALIGNED(1)
)
axi_dma_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_read_desc_addr(dma_tx_desc_addr),
    .s_axis_read_desc_len(dma_tx_desc_len),
    .s_axis_read_desc_tag(dma_tx_desc_tag),
    .s_axis_read_desc_id(0),
    .s_axis_read_desc_dest(0),
    .s_axis_read_desc_user(dma_tx_desc_user),
    .s_axis_read_desc_valid(dma_tx_desc_valid),
    .s_axis_read_desc_ready(dma_tx_desc_ready),

    .m_axis_read_desc_status_tag(dma_tx_desc_status_tag),
    .m_axis_read_desc_status_valid(dma_tx_desc_status_valid),

    .m_axis_read_data_tdata(tx_axis_tdata_int),
    .m_axis_read_data_tkeep(tx_axis_tkeep_int),
    .m_axis_read_data_tvalid(tx_axis_tvalid_int),
    .m_axis_read_data_tready(tx_axis_tready_int),
    .m_axis_read_data_tlast(tx_axis_tlast_int),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(tx_axis_tuser_int),

    .s_axis_write_desc_addr(dma_rx_desc_addr),
    .s_axis_write_desc_len(dma_rx_desc_len),
    .s_axis_write_desc_tag(dma_rx_desc_tag),
    .s_axis_write_desc_valid(dma_rx_desc_valid),
    .s_axis_write_desc_ready(dma_rx_desc_ready),

    .m_axis_write_desc_status_len(dma_rx_desc_status_len),
    .m_axis_write_desc_status_tag(dma_rx_desc_status_tag),
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
    .m_axis_write_desc_status_user(dma_rx_desc_status_user),
    .m_axis_write_desc_status_valid(dma_rx_desc_status_valid),

    .s_axis_write_data_tdata(rx_axis_tdata),
    .s_axis_write_data_tkeep(rx_axis_tkeep),
    .s_axis_write_data_tvalid(rx_axis_tvalid),
    .s_axis_write_data_tready(rx_axis_tready),
    .s_axis_write_data_tlast(rx_axis_tlast),
    .s_axis_write_data_tid(0),
    .s_axis_write_data_tdest(0),
    .s_axis_write_data_tuser(rx_axis_tuser),

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

    .read_enable(dma_enable),
    .write_enable(dma_enable),
    .write_abort(1'b0)
);

parameter RAM_COUNT = 3;
parameter RAM_SIZE = 2**16;
parameter RAM_ADDR_WIDTH = $clog2(RAM_SIZE);
parameter RAM_BASE_ADDR_WIDTH = RAM_COUNT*AXI_ADDR_WIDTH;
parameter RAM_BASE_ADDR = calcRAMBaseAddrs(RAM_ADDR_WIDTH);

function [RAM_BASE_ADDR_WIDTH-1:0] calcRAMBaseAddrs(input [31:0] ram_width);
    integer i;
    begin
        calcRAMBaseAddrs = {RAM_BASE_ADDR_WIDTH{1'b0}};
        for (i = 0; i < RAM_COUNT; i = i + 1) begin
            calcRAMBaseAddrs[i * AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = i * (2**ram_width);
        end
    end
endfunction

parameter AXI_S_COUNT = 2;
parameter AXI_M_COUNT = RAM_COUNT+1;

parameter RAM_ID_WIDTH = AXI_ID_WIDTH+$clog2(AXI_S_COUNT);

axi_interconnect #(
    .S_COUNT(1),
    .M_COUNT(2),
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .STRB_WIDTH(AXI_STRB_WIDTH),
    .ID_WIDTH(RAM_ID_WIDTH),
    .AWUSER_ENABLE(0),
    .WUSER_ENABLE(0),
    .BUSER_ENABLE(0),
    .ARUSER_ENABLE(0),
    .RUSER_ENABLE(0),
    .FORWARD_ID(0),
    .M_REGIONS(1),
    .M_BASE_ADDR({23'h006000, 23'h004000}),
    .M_ADDR_WIDTH({2{32'd13}}),
    .M_CONNECT_READ({2{{1{1'b1}}}}),
    .M_CONNECT_WRITE({2{{1{1'b1}}}})
)
axi_interconnect_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awqos(0),
    .s_axi_awuser(0),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wuser(0),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_buser(),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arqos(0),
    .s_axi_aruser(0),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_ruser(),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),

    .m_axi_awid(     {axi_rx_awid,     axi_tx_awid}),
    .m_axi_awaddr(   {axi_rx_awaddr,   axi_tx_awaddr}),
    .m_axi_awlen(    {axi_rx_awlen,    axi_tx_awlen}),
    .m_axi_awsize(   {axi_rx_awsize,   axi_tx_awsize}),
    .m_axi_awburst(  {axi_rx_awburst,  axi_tx_awburst}),
    .m_axi_awlock(   {axi_rx_awlock,   axi_tx_awlock}),
    .m_axi_awcache(  {axi_rx_awcache,  axi_tx_awcache}),
    .m_axi_awprot(   {axi_rx_awprot,   axi_tx_awprot}),
    .m_axi_awqos(),
    .m_axi_awuser(),
    .m_axi_awvalid(  {axi_rx_awvalid,  axi_tx_awvalid}),
    .m_axi_awready(  {axi_rx_awready,  axi_tx_awready}),
    .m_axi_wdata(    {axi_rx_wdata,    axi_tx_wdata}),
    .m_axi_wstrb(    {axi_rx_wstrb,    axi_tx_wstrb}),
    .m_axi_wlast(    {axi_rx_wlast,    axi_tx_wlast}),
    .m_axi_wuser(),
    .m_axi_wvalid(   {axi_rx_wvalid,   axi_tx_wvalid}),
    .m_axi_wready(   {axi_rx_wready,   axi_tx_wready}),
    .m_axi_bid(      {axi_rx_bid,      axi_tx_bid}),
    .m_axi_bresp(    {axi_rx_bresp,    axi_tx_bresp}),
    .m_axi_buser(0),
    .m_axi_bvalid(   {axi_rx_bvalid,   axi_tx_bvalid}),
    .m_axi_bready(   {axi_rx_bready,   axi_tx_bready}),
    .m_axi_arid(     {axi_rx_arid,     axi_tx_arid}),
    .m_axi_araddr(   {axi_rx_araddr,   axi_tx_araddr}),
    .m_axi_arlen(    {axi_rx_arlen,    axi_tx_arlen}),
    .m_axi_arsize(   {axi_rx_arsize,   axi_tx_arsize}),
    .m_axi_arburst(  {axi_rx_arburst,  axi_tx_arburst}),
    .m_axi_arlock(   {axi_rx_arlock,   axi_tx_arlock}),
    .m_axi_arcache(  {axi_rx_arcache,  axi_tx_arcache}),
    .m_axi_arprot(   {axi_rx_arprot,   axi_tx_arprot}),
    .m_axi_arqos(),
    .m_axi_aruser(),
    .m_axi_arvalid(  {axi_rx_arvalid,  axi_tx_arvalid}),
    .m_axi_arready(  {axi_rx_arready,  axi_tx_arready}),
    .m_axi_rid(      {axi_rx_rid,      axi_tx_rid}),
    .m_axi_rdata(    {axi_rx_rdata,    axi_tx_rdata}),
    .m_axi_rresp(    {axi_rx_rresp,    axi_tx_rresp}),
    .m_axi_rlast(    {axi_rx_rlast,    axi_tx_rlast}),
    .m_axi_ruser(0),
    .m_axi_rvalid(   {axi_rx_rvalid,   axi_tx_rvalid}),
    .m_axi_rready(   {axi_rx_rready,   axi_tx_rready})
);

endmodule
