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
    parameter PCIE_ADDR_WIDTH = 64,
    parameter PCIE_DMA_LEN_WIDTH = 16,
    parameter PCIE_DMA_TAG_WIDTH = 8,
    parameter REQ_TAG_WIDTH = 8,
    parameter OP_TAG_WIDTH = 8,
    parameter TX_QUEUE_INDEX_WIDTH = 8,
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter TX_CPL_QUEUE_INDEX_WIDTH = 8,
    parameter RX_CPL_QUEUE_INDEX_WIDTH = 8,
    parameter TX_DESC_TABLE_SIZE = 16,
    parameter TX_PKT_TABLE_SIZE = 8,
    parameter RX_DESC_TABLE_SIZE = 16,
    parameter RX_PKT_TABLE_SIZE = 8,
    parameter TX_SCHEDULER = "RR",
    parameter TDMA_INDEX_WIDTH = 8,
    parameter QUEUE_PTR_WIDTH = 16,
    parameter QUEUE_LOG_SIZE_WIDTH = 4,
    parameter PTP_TS_ENABLE = 1,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter AXI_DATA_WIDTH = 256,
    parameter AXI_ADDR_WIDTH = 16,
    parameter AXI_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_BASE_ADDR = 0,
    parameter XGMII_DATA_WIDTH = 64,
    parameter XGMII_CTRL_WIDTH = (XGMII_DATA_WIDTH/8),
    parameter TX_FIFO_DEPTH = 4096,
    parameter RX_FIFO_DEPTH = 4096
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * TX descriptor dequeue request output
     */
    output wire [TX_QUEUE_INDEX_WIDTH-1:0]      m_axis_tx_desc_dequeue_req_queue,
    output wire [REQ_TAG_WIDTH-1:0]             m_axis_tx_desc_dequeue_req_tag,
    output wire                                 m_axis_tx_desc_dequeue_req_valid,
    input  wire                                 m_axis_tx_desc_dequeue_req_ready,

    /*
     * TX descriptor dequeue response input
     */
    input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_tx_desc_dequeue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_tx_desc_dequeue_resp_addr,
    input  wire [TX_CPL_QUEUE_INDEX_WIDTH-1:0]  s_axis_tx_desc_dequeue_resp_cpl,
    input  wire [REQ_TAG_WIDTH-1:0]             s_axis_tx_desc_dequeue_resp_tag,
    input  wire [OP_TAG_WIDTH-1:0]              s_axis_tx_desc_dequeue_resp_op_tag,
    input  wire                                 s_axis_tx_desc_dequeue_resp_empty,
    input  wire                                 s_axis_tx_desc_dequeue_resp_error,
    input  wire                                 s_axis_tx_desc_dequeue_resp_valid,
    output wire                                 s_axis_tx_desc_dequeue_resp_ready,

    /*
     * TX descriptor dequeue commit output
     */
    output wire [OP_TAG_WIDTH-1:0]              m_axis_tx_desc_dequeue_commit_op_tag,
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
    output wire [REQ_TAG_WIDTH-1:0]             m_axis_tx_cpl_enqueue_req_tag,
    output wire                                 m_axis_tx_cpl_enqueue_req_valid,
    input  wire                                 m_axis_tx_cpl_enqueue_req_ready,

    /*
     * TX completion enqueue response input
     */
    //input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_tx_cpl_enqueue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_tx_cpl_enqueue_resp_addr,
    //input  wire [EVENT_WIDTH-1:0]               s_axis_tx_cpl_enqueue_resp_event,
    input  wire [REQ_TAG_WIDTH-1:0]             s_axis_tx_cpl_enqueue_resp_tag,
    input  wire [OP_TAG_WIDTH-1:0]              s_axis_tx_cpl_enqueue_resp_op_tag,
    input  wire                                 s_axis_tx_cpl_enqueue_resp_full,
    input  wire                                 s_axis_tx_cpl_enqueue_resp_error,
    input  wire                                 s_axis_tx_cpl_enqueue_resp_valid,
    output wire                                 s_axis_tx_cpl_enqueue_resp_ready,

    /*
     * TX completion enqueue commit output
     */
    output wire [OP_TAG_WIDTH-1:0]              m_axis_tx_cpl_enqueue_commit_op_tag,
    output wire                                 m_axis_tx_cpl_enqueue_commit_valid,
    input  wire                                 m_axis_tx_cpl_enqueue_commit_ready,

    /*
     * RX descriptor dequeue request output
     */
    output wire [RX_QUEUE_INDEX_WIDTH-1:0]      m_axis_rx_desc_dequeue_req_queue,
    output wire [REQ_TAG_WIDTH-1:0]             m_axis_rx_desc_dequeue_req_tag,
    output wire                                 m_axis_rx_desc_dequeue_req_valid,
    input  wire                                 m_axis_rx_desc_dequeue_req_ready,

    /*
     * RX descriptor dequeue response input
     */
    input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_rx_desc_dequeue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_rx_desc_dequeue_resp_addr,
    input  wire [RX_CPL_QUEUE_INDEX_WIDTH-1:0]  s_axis_rx_desc_dequeue_resp_cpl,
    input  wire [REQ_TAG_WIDTH-1:0]             s_axis_rx_desc_dequeue_resp_tag,
    input  wire [OP_TAG_WIDTH-1:0]              s_axis_rx_desc_dequeue_resp_op_tag,
    input  wire                                 s_axis_rx_desc_dequeue_resp_empty,
    input  wire                                 s_axis_rx_desc_dequeue_resp_error,
    input  wire                                 s_axis_rx_desc_dequeue_resp_valid,
    output wire                                 s_axis_rx_desc_dequeue_resp_ready,

    /*
     * RX descriptor dequeue commit output
     */
    output wire [OP_TAG_WIDTH-1:0]              m_axis_rx_desc_dequeue_commit_op_tag,
    output wire                                 m_axis_rx_desc_dequeue_commit_valid,
    input  wire                                 m_axis_rx_desc_dequeue_commit_ready,

    /*
     * RX completion enqueue request output
     */
    output wire [RX_CPL_QUEUE_INDEX_WIDTH-1:0]  m_axis_rx_cpl_enqueue_req_queue,
    output wire [REQ_TAG_WIDTH-1:0]             m_axis_rx_cpl_enqueue_req_tag,
    output wire                                 m_axis_rx_cpl_enqueue_req_valid,
    input  wire                                 m_axis_rx_cpl_enqueue_req_ready,

    /*
     * RX completion enqueue response input
     */
    //input  wire [QUEUE_PTR_WIDTH-1:0]           s_axis_rx_cpl_enqueue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_rx_cpl_enqueue_resp_addr,
    //input  wire [EVENT_WIDTH-1:0]               s_axis_rx_cpl_enqueue_resp_event,
    input  wire [REQ_TAG_WIDTH-1:0]             s_axis_rx_cpl_enqueue_resp_tag,
    input  wire [OP_TAG_WIDTH-1:0]              s_axis_rx_cpl_enqueue_resp_op_tag,
    input  wire                                 s_axis_rx_cpl_enqueue_resp_full,
    input  wire                                 s_axis_rx_cpl_enqueue_resp_error,
    input  wire                                 s_axis_rx_cpl_enqueue_resp_valid,
    output wire                                 s_axis_rx_cpl_enqueue_resp_ready,

    /*
     * RX completion enqueue commit output
     */
    output wire [OP_TAG_WIDTH-1:0]              m_axis_rx_cpl_enqueue_commit_op_tag,
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
     * XGMII interface
     */
    input  wire                                 xgmii_rx_clk,
    input  wire                                 xgmii_rx_rst,
    input  wire                                 xgmii_tx_clk,
    input  wire                                 xgmii_tx_rst,
    input  wire [XGMII_DATA_WIDTH-1:0]          xgmii_rxd,
    input  wire [XGMII_CTRL_WIDTH-1:0]          xgmii_rxc,
    output wire [XGMII_DATA_WIDTH-1:0]          xgmii_txd,
    output wire [XGMII_CTRL_WIDTH-1:0]          xgmii_txc,

    /*
     * PTP clock
     */
    input  wire [95:0]                          ptp_ts_96,
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
reg [7:0] rx_pkt_cnt_reg = 0;

wire [RX_QUEUE_INDEX_WIDTH-1:0] rx_req_queue = 0; // TODO RSS of some form
wire [REQ_TAG_WIDTH-1:0]        rx_req_tag = 0;
wire                            rx_req_valid = rx_pkt_cnt_reg > 0;
wire                            rx_req_ready;

wire [REQ_TAG_WIDTH-1:0]        rx_req_status_tag;
wire                            rx_req_status_valid;

always @(posedge clk) begin
    if (rst) begin
        rx_pkt_cnt_reg <= 0;
    end else begin
        if (rx_pkt_cnt_reg > 0 && rx_req_ready) begin
            if (!eth_rx_fifo_good_frame) begin
                rx_pkt_cnt_reg <= rx_pkt_cnt_reg - 1;
            end
        end else begin
            if (eth_rx_fifo_good_frame) begin
                rx_pkt_cnt_reg <= rx_pkt_cnt_reg + 1;
            end
        end
    end
end

// Timestamps
wire [96:0]              rx_ptp_ts_96;
wire                     rx_ptp_ts_valid;
wire                     rx_ptp_ts_ready;

wire [96:0]              tx_ptp_ts_96;
wire                     tx_ptp_ts_valid;
wire                     tx_ptp_ts_ready;

// Checksums
wire [96:0]              rx_csum;
wire                     rx_csum_valid;

wire [96:0]              rx_fifo_csum;
wire                     rx_fifo_csum_valid;
wire                     rx_fifo_csum_ready;

// wire [96:0]              tx_csum;
// wire                     tx_csum_valid;

// wire [96:0]              tx_fifo_csum;
// wire                     tx_fifo_csum_valid;
// wire                     tx_fifo_csum_ready;

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

// 
wire eth_tx_fifo_overflow;
wire eth_tx_fifo_bad_frame;
wire eth_tx_fifo_good_frame;
wire eth_rx_error_bad_frame;
wire eth_rx_error_bad_fcs;
wire eth_rx_fifo_overflow;
wire eth_rx_fifo_bad_frame;
wire eth_rx_fifo_good_frame;

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
        .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH)
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
        .s_axil_rready(s_axil_rready)
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
    .QUEUE_REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .PKT_TABLE_SIZE(TX_PKT_TABLE_SIZE),
    .AXI_BASE_ADDR(AXI_BASE_ADDR + 24'h004000),
    .SCRATCH_DESC_AXI_ADDR(AXI_BASE_ADDR + 24'h004000),
    .SCRATCH_PKT_AXI_ADDR(AXI_BASE_ADDR + 24'h010000),
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
     * Transmit timestamp input
     */
    .s_axis_tx_ptp_ts_96(tx_ptp_ts_96),
    .s_axis_tx_ptp_ts_valid(tx_ptp_ts_valid),
    .s_axis_tx_ptp_ts_ready(tx_ptp_ts_ready),

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
    .QUEUE_REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
    .PKT_TABLE_SIZE(RX_PKT_TABLE_SIZE),
    .AXI_BASE_ADDR(AXI_BASE_ADDR + 24'h006000),
    .SCRATCH_DESC_AXI_ADDR(AXI_BASE_ADDR + 24'h006000),
    .SCRATCH_PKT_AXI_ADDR(AXI_BASE_ADDR + 24'h020000),
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
    .s_axis_rx_ptp_ts_96(rx_ptp_ts_96),
    .s_axis_rx_ptp_ts_valid(rx_ptp_ts_valid),
    .s_axis_rx_ptp_ts_ready(rx_ptp_ts_ready),

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

eth_interface #(
    .DATA_WIDTH(XGMII_DATA_WIDTH),
    .CTRL_WIDTH(XGMII_CTRL_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(16),
    .LEN_WIDTH(AXI_DMA_LEN_WIDTH),
    .TAG_WIDTH(AXI_DMA_TAG_WIDTH),
    .ENABLE_SG(0),
    .ENABLE_UNALIGNED(1),
    .ENABLE_PADDING(1),
    .ENABLE_DIC(1),
    .MIN_FRAME_LENGTH(64),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .LOGIC_PTP_PERIOD_NS(4'h4),
    .LOGIC_PTP_PERIOD_FNS(16'h0000),
    .PTP_PERIOD_NS(4'h6),
    .PTP_PERIOD_FNS(16'h6666),
    .TX_PTP_TS_ENABLE(1),
    .RX_PTP_TS_ENABLE(1)//,
    //.PTP_TS_WIDTH(96),
    //.TX_PTP_TAG_ENABLE(1),
    //.PTP_TAG_WIDTH(PTP_TAG_WIDTH)
)
eth_interface_inst (
    .rx_clk(xgmii_rx_clk),
    .rx_rst(xgmii_rx_rst),
    .tx_clk(xgmii_tx_clk),
    .tx_rst(xgmii_tx_rst),
    .logic_clk(clk),
    .logic_rst(rst),

    /*
     * Transmit descriptor input
     */
    .s_axis_tx_desc_addr(dma_tx_desc_addr),
    .s_axis_tx_desc_len(dma_tx_desc_len),
    .s_axis_tx_desc_tag(dma_tx_desc_tag),
    .s_axis_tx_desc_user(dma_tx_desc_user),
    .s_axis_tx_desc_valid(dma_tx_desc_valid),
    .s_axis_tx_desc_ready(dma_tx_desc_ready),

    /*
     * Transmit descriptor status output
     */
    .m_axis_tx_desc_status_tag(dma_tx_desc_status_tag),
    .m_axis_tx_desc_status_valid(dma_tx_desc_status_valid),

    /*
     * Transmit timestamp tag input
     */
    .s_axis_tx_ptp_ts_tag(0),
    .s_axis_tx_ptp_ts_valid(1'b0),
    .s_axis_tx_ptp_ts_ready(),

    /*
     * Transmit timestamp output
     */
    .m_axis_tx_ptp_ts_96(tx_ptp_ts_96),
    .m_axis_tx_ptp_ts_tag(),
    .m_axis_tx_ptp_ts_valid(tx_ptp_ts_valid),
    .m_axis_tx_ptp_ts_ready(tx_ptp_ts_ready),

    /*
     * Receive descriptor input
     */
    .s_axis_rx_desc_addr(dma_rx_desc_addr),
    .s_axis_rx_desc_len(dma_rx_desc_len),
    .s_axis_rx_desc_tag(dma_rx_desc_tag),
    .s_axis_rx_desc_valid(dma_rx_desc_valid),
    .s_axis_rx_desc_ready(dma_rx_desc_ready),

    /*
     * Receive descriptor status output
     */
    .m_axis_rx_desc_status_len(dma_rx_desc_status_len),
    .m_axis_rx_desc_status_tag(dma_rx_desc_status_tag),
    .m_axis_rx_desc_status_user(dma_rx_desc_status_user),
    .m_axis_rx_desc_status_valid(dma_rx_desc_status_valid),

    /*
     * Receive timestamp output
     */
    .m_axis_rx_ptp_ts_96(rx_ptp_ts_96),
    .m_axis_rx_ptp_ts_valid(rx_ptp_ts_valid),
    .m_axis_rx_ptp_ts_ready(rx_ptp_ts_ready),

    /*
     * Receive checksum output
     */
    .m_axis_rx_csum(rx_csum),
    .m_axis_rx_csum_valid(rx_csum_valid),

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

    .xgmii_rxd(xgmii_rxd),
    .xgmii_rxc(xgmii_rxc),
    .xgmii_txd(xgmii_txd),
    .xgmii_txc(xgmii_txc),

    .tx_fifo_overflow(eth_tx_fifo_overflow),
    .tx_fifo_bad_frame(eth_tx_fifo_bad_frame),
    .tx_fifo_good_frame(eth_tx_fifo_good_frame),
    .rx_error_bad_frame(eth_rx_error_bad_frame),
    .rx_error_bad_fcs(eth_rx_error_bad_fcs),
    .rx_fifo_overflow(eth_rx_fifo_overflow),
    .rx_fifo_bad_frame(eth_rx_fifo_bad_frame),
    .rx_fifo_good_frame(eth_rx_fifo_good_frame),

    .ptp_ts_96(ptp_ts_96),

    .tx_enable(dma_enable),
    .rx_enable(dma_enable),
    .rx_abort(1'b0),
    .ifg_delay(8'd12)
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
