/*

Copyright 2019-2022, The Regents of the University of California.
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
 * NIC Interface
 */
module mqnic_interface #
(
    // Structural configuration
    parameter PORTS = 1,
    parameter SCHEDULERS = 1,

    // PTP configuration
    parameter PTP_TS_WIDTH = 96,

    // Queue manager configuration (interface)
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = TX_QUEUE_OP_TABLE_SIZE,
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = RX_QUEUE_OP_TABLE_SIZE,
    parameter EVENT_QUEUE_INDEX_WIDTH = 5,
    parameter TX_QUEUE_INDEX_WIDTH = 13,
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter TX_CPL_QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH,
    parameter RX_CPL_QUEUE_INDEX_WIDTH = RX_QUEUE_INDEX_WIDTH,
    parameter EVENT_QUEUE_PIPELINE = 3,
    parameter TX_QUEUE_PIPELINE = 3+(TX_QUEUE_INDEX_WIDTH > 12 ? TX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter RX_QUEUE_PIPELINE = 3+(RX_QUEUE_INDEX_WIDTH > 12 ? RX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter TX_CPL_QUEUE_PIPELINE = TX_QUEUE_PIPELINE,
    parameter RX_CPL_QUEUE_PIPELINE = RX_QUEUE_PIPELINE,
    parameter QUEUE_PTR_WIDTH = 16,
    parameter LOG_QUEUE_SIZE_WIDTH = 4,
    parameter LOG_BLOCK_SIZE_WIDTH = 2,

    // Descriptor management
    parameter TX_MAX_DESC_REQ = 16,
    parameter TX_DESC_FIFO_SIZE = TX_MAX_DESC_REQ*8,
    parameter RX_MAX_DESC_REQ = 16,
    parameter RX_DESC_FIFO_SIZE = RX_MAX_DESC_REQ*8,

    // TX and RX engine configuration
    parameter TX_DESC_TABLE_SIZE = 32,
    parameter RX_DESC_TABLE_SIZE = 32,

    // Scheduler configuration
    parameter TX_SCHEDULER_OP_TABLE_SIZE = TX_DESC_TABLE_SIZE,
    parameter TX_SCHEDULER_PIPELINE = TX_QUEUE_PIPELINE,
    parameter TDMA_INDEX_WIDTH = 6,

    // Interface configuration
    parameter PTP_TS_ENABLE = 1,
    parameter TX_CPL_ENABLE = PTP_TS_ENABLE,
    parameter TX_CPL_FIFO_DEPTH = 32,
    parameter TX_TAG_WIDTH = $clog2(TX_DESC_TABLE_SIZE)+1,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 32768,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 32768,
    parameter RX_RAM_SIZE = 32768,

    // Application block configuration
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,
    parameter APP_AXIS_IF_ENABLE = 1,

    // DMA interface configuration
    parameter DMA_ADDR_WIDTH = 64,
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_SEL_WIDTH = 1,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
    parameter RAM_PIPELINE = 2,

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = 8,

    // AXI lite interface configuration
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),

    // Streaming interface configuration (direct, async)
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_RX_USE_READY = 0,
    parameter AXIS_TX_PIPELINE = 0,
    parameter AXIS_TX_FIFO_PIPELINE = 2,
    parameter AXIS_TX_TS_PIPELINE = 0,
    parameter AXIS_RX_PIPELINE = 0,
    parameter AXIS_RX_FIFO_PIPELINE = 2,

    // Streaming interface configuration (direct, sync)
    parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_SYNC_KEEP_WIDTH = AXIS_SYNC_DATA_WIDTH/8,
    parameter AXIS_SYNC_TX_USER_WIDTH = AXIS_TX_USER_WIDTH,
    parameter AXIS_SYNC_RX_USER_WIDTH = AXIS_RX_USER_WIDTH,

    // Streaming interface configuration (interface)
    parameter AXIS_IF_DATA_WIDTH = AXIS_SYNC_DATA_WIDTH*2**$clog2(PORTS),
    parameter AXIS_IF_KEEP_WIDTH = AXIS_IF_DATA_WIDTH/8,
    parameter AXIS_IF_TX_ID_WIDTH = TX_QUEUE_INDEX_WIDTH,
    parameter AXIS_IF_RX_ID_WIDTH = PORTS > 1 ? $clog2(PORTS) : 1,
    parameter AXIS_IF_TX_DEST_WIDTH = $clog2(PORTS)+4,
    parameter AXIS_IF_RX_DEST_WIDTH = RX_QUEUE_INDEX_WIDTH,
    parameter AXIS_IF_TX_USER_WIDTH = AXIS_SYNC_TX_USER_WIDTH,
    parameter AXIS_IF_RX_USER_WIDTH = AXIS_SYNC_RX_USER_WIDTH
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * DMA read descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_ctrl_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_ctrl_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_ctrl_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_ctrl_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_ctrl_dma_read_desc_tag,
    output wire                                         m_axis_ctrl_dma_read_desc_valid,
    input  wire                                         m_axis_ctrl_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_ctrl_dma_read_desc_status_tag,
    input  wire [3:0]                                   s_axis_ctrl_dma_read_desc_status_error,
    input  wire                                         s_axis_ctrl_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_ctrl_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_ctrl_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_ctrl_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                     m_axis_ctrl_dma_write_desc_imm,
    output wire                                         m_axis_ctrl_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_ctrl_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_ctrl_dma_write_desc_tag,
    output wire                                         m_axis_ctrl_dma_write_desc_valid,
    input  wire                                         m_axis_ctrl_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_ctrl_dma_write_desc_status_tag,
    input  wire [3:0]                                   s_axis_ctrl_dma_write_desc_status_error,
    input  wire                                         s_axis_ctrl_dma_write_desc_status_valid,

    /*
     * DMA read descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_data_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_data_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_data_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_data_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_data_dma_read_desc_tag,
    output wire                                         m_axis_data_dma_read_desc_valid,
    input  wire                                         m_axis_data_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_data_dma_read_desc_status_tag,
    input  wire [3:0]                                   s_axis_data_dma_read_desc_status_error,
    input  wire                                         s_axis_data_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_data_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_data_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_data_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                     m_axis_data_dma_write_desc_imm,
    output wire                                         m_axis_data_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_data_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_data_dma_write_desc_tag,
    output wire                                         m_axis_data_dma_write_desc_valid,
    input  wire                                         m_axis_data_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_data_dma_write_desc_status_tag,
    input  wire [3:0]                                   s_axis_data_dma_write_desc_status_error,
    input  wire                                         s_axis_data_dma_write_desc_status_valid,

    /*
     * AXI-Lite slave interface
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
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_ADDR_WIDTH-1:0]                   m_axil_csr_awaddr,
    output wire [2:0]                                   m_axil_csr_awprot,
    output wire                                         m_axil_csr_awvalid,
    input  wire                                         m_axil_csr_awready,
    output wire [AXIL_DATA_WIDTH-1:0]                   m_axil_csr_wdata,
    output wire [AXIL_STRB_WIDTH-1:0]                   m_axil_csr_wstrb,
    output wire                                         m_axil_csr_wvalid,
    input  wire                                         m_axil_csr_wready,
    input  wire [1:0]                                   m_axil_csr_bresp,
    input  wire                                         m_axil_csr_bvalid,
    output wire                                         m_axil_csr_bready,
    output wire [AXIL_ADDR_WIDTH-1:0]                   m_axil_csr_araddr,
    output wire [2:0]                                   m_axil_csr_arprot,
    output wire                                         m_axil_csr_arvalid,
    input  wire                                         m_axil_csr_arready,
    input  wire [AXIL_DATA_WIDTH-1:0]                   m_axil_csr_rdata,
    input  wire [1:0]                                   m_axil_csr_rresp,
    input  wire                                         m_axil_csr_rvalid,
    output wire                                         m_axil_csr_rready,

    /*
     * RAM interface (control)
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ctrl_dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    ctrl_dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ctrl_dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ctrl_dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ctrl_dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ctrl_dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ctrl_dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_resp_ready,

    /*
     * RAM interface (data)
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       data_dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    data_dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  data_dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  data_dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       data_dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  data_dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  data_dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_resp_ready,

    /*
     * Application section datapath interface (internal aggregate interface-level)
     */
    output wire [AXIS_IF_DATA_WIDTH-1:0]                m_axis_app_if_tx_tdata,
    output wire [AXIS_IF_KEEP_WIDTH-1:0]                m_axis_app_if_tx_tkeep,
    output wire                                         m_axis_app_if_tx_tvalid,
    input  wire                                         m_axis_app_if_tx_tready,
    output wire                                         m_axis_app_if_tx_tlast,
    output wire [AXIS_IF_TX_ID_WIDTH-1:0]               m_axis_app_if_tx_tid,
    output wire [AXIS_IF_TX_DEST_WIDTH-1:0]             m_axis_app_if_tx_tdest,
    output wire [AXIS_IF_TX_USER_WIDTH-1:0]             m_axis_app_if_tx_tuser,

    input  wire [AXIS_IF_DATA_WIDTH-1:0]                s_axis_app_if_tx_tdata,
    input  wire [AXIS_IF_KEEP_WIDTH-1:0]                s_axis_app_if_tx_tkeep,
    input  wire                                         s_axis_app_if_tx_tvalid,
    output wire                                         s_axis_app_if_tx_tready,
    input  wire                                         s_axis_app_if_tx_tlast,
    input  wire [AXIS_IF_TX_ID_WIDTH-1:0]               s_axis_app_if_tx_tid,
    input  wire [AXIS_IF_TX_DEST_WIDTH-1:0]             s_axis_app_if_tx_tdest,
    input  wire [AXIS_IF_TX_USER_WIDTH-1:0]             s_axis_app_if_tx_tuser,

    output wire [PTP_TS_WIDTH-1:0]                      m_axis_app_if_tx_cpl_ts,
    output wire [TX_TAG_WIDTH-1:0]                      m_axis_app_if_tx_cpl_tag,
    output wire                                         m_axis_app_if_tx_cpl_valid,
    input  wire                                         m_axis_app_if_tx_cpl_ready,

    input  wire [PTP_TS_WIDTH-1:0]                      s_axis_app_if_tx_cpl_ts,
    input  wire [TX_TAG_WIDTH-1:0]                      s_axis_app_if_tx_cpl_tag,
    input  wire                                         s_axis_app_if_tx_cpl_valid,
    output wire                                         s_axis_app_if_tx_cpl_ready,

    output wire [AXIS_IF_DATA_WIDTH-1:0]                m_axis_app_if_rx_tdata,
    output wire [AXIS_IF_KEEP_WIDTH-1:0]                m_axis_app_if_rx_tkeep,
    output wire                                         m_axis_app_if_rx_tvalid,
    input  wire                                         m_axis_app_if_rx_tready,
    output wire                                         m_axis_app_if_rx_tlast,
    output wire [AXIS_IF_RX_ID_WIDTH-1:0]               m_axis_app_if_rx_tid,
    output wire [AXIS_IF_RX_DEST_WIDTH-1:0]             m_axis_app_if_rx_tdest,
    output wire [AXIS_IF_RX_USER_WIDTH-1:0]             m_axis_app_if_rx_tuser,

    input  wire [AXIS_IF_DATA_WIDTH-1:0]                s_axis_app_if_rx_tdata,
    input  wire [AXIS_IF_KEEP_WIDTH-1:0]                s_axis_app_if_rx_tkeep,
    input  wire                                         s_axis_app_if_rx_tvalid,
    output wire                                         s_axis_app_if_rx_tready,
    input  wire                                         s_axis_app_if_rx_tlast,
    input  wire [AXIS_IF_RX_ID_WIDTH-1:0]               s_axis_app_if_rx_tid,
    input  wire [AXIS_IF_RX_DEST_WIDTH-1:0]             s_axis_app_if_rx_tdest,
    input  wire [AXIS_IF_RX_USER_WIDTH-1:0]             s_axis_app_if_rx_tuser,

    /*
     * Application section datapath interface (synchronous MAC interface)
     */
    output wire [PORTS*AXIS_SYNC_DATA_WIDTH-1:0]        m_axis_app_sync_tx_tdata,
    output wire [PORTS*AXIS_SYNC_KEEP_WIDTH-1:0]        m_axis_app_sync_tx_tkeep,
    output wire [PORTS-1:0]                             m_axis_app_sync_tx_tvalid,
    input  wire [PORTS-1:0]                             m_axis_app_sync_tx_tready,
    output wire [PORTS-1:0]                             m_axis_app_sync_tx_tlast,
    output wire [PORTS*AXIS_SYNC_TX_USER_WIDTH-1:0]     m_axis_app_sync_tx_tuser,

    input  wire [PORTS*AXIS_SYNC_DATA_WIDTH-1:0]        s_axis_app_sync_tx_tdata,
    input  wire [PORTS*AXIS_SYNC_KEEP_WIDTH-1:0]        s_axis_app_sync_tx_tkeep,
    input  wire [PORTS-1:0]                             s_axis_app_sync_tx_tvalid,
    output wire [PORTS-1:0]                             s_axis_app_sync_tx_tready,
    input  wire [PORTS-1:0]                             s_axis_app_sync_tx_tlast,
    input  wire [PORTS*AXIS_SYNC_TX_USER_WIDTH-1:0]     s_axis_app_sync_tx_tuser,

    output wire [PORTS*PTP_TS_WIDTH-1:0]                m_axis_app_sync_tx_cpl_ts,
    output wire [PORTS*TX_TAG_WIDTH-1:0]                m_axis_app_sync_tx_cpl_tag,
    output wire [PORTS-1:0]                             m_axis_app_sync_tx_cpl_valid,
    input  wire [PORTS-1:0]                             m_axis_app_sync_tx_cpl_ready,

    input  wire [PORTS*PTP_TS_WIDTH-1:0]                s_axis_app_sync_tx_cpl_ts,
    input  wire [PORTS*TX_TAG_WIDTH-1:0]                s_axis_app_sync_tx_cpl_tag,
    input  wire [PORTS-1:0]                             s_axis_app_sync_tx_cpl_valid,
    output wire [PORTS-1:0]                             s_axis_app_sync_tx_cpl_ready,

    output wire [PORTS*AXIS_SYNC_DATA_WIDTH-1:0]        m_axis_app_sync_rx_tdata,
    output wire [PORTS*AXIS_SYNC_KEEP_WIDTH-1:0]        m_axis_app_sync_rx_tkeep,
    output wire [PORTS-1:0]                             m_axis_app_sync_rx_tvalid,
    input  wire [PORTS-1:0]                             m_axis_app_sync_rx_tready,
    output wire [PORTS-1:0]                             m_axis_app_sync_rx_tlast,
    output wire [PORTS*AXIS_SYNC_RX_USER_WIDTH-1:0]     m_axis_app_sync_rx_tuser,

    input  wire [PORTS*AXIS_SYNC_DATA_WIDTH-1:0]        s_axis_app_sync_rx_tdata,
    input  wire [PORTS*AXIS_SYNC_KEEP_WIDTH-1:0]        s_axis_app_sync_rx_tkeep,
    input  wire [PORTS-1:0]                             s_axis_app_sync_rx_tvalid,
    output wire [PORTS-1:0]                             s_axis_app_sync_rx_tready,
    input  wire [PORTS-1:0]                             s_axis_app_sync_rx_tlast,
    input  wire [PORTS*AXIS_SYNC_RX_USER_WIDTH-1:0]     s_axis_app_sync_rx_tuser,

    /*
     * Application section datapath interface (direct MAC interface)
     */
    output wire [PORTS*AXIS_DATA_WIDTH-1:0]             m_axis_app_direct_tx_tdata,
    output wire [PORTS*AXIS_KEEP_WIDTH-1:0]             m_axis_app_direct_tx_tkeep,
    output wire [PORTS-1:0]                             m_axis_app_direct_tx_tvalid,
    input  wire [PORTS-1:0]                             m_axis_app_direct_tx_tready,
    output wire [PORTS-1:0]                             m_axis_app_direct_tx_tlast,
    output wire [PORTS*AXIS_TX_USER_WIDTH-1:0]          m_axis_app_direct_tx_tuser,

    input  wire [PORTS*AXIS_DATA_WIDTH-1:0]             s_axis_app_direct_tx_tdata,
    input  wire [PORTS*AXIS_KEEP_WIDTH-1:0]             s_axis_app_direct_tx_tkeep,
    input  wire [PORTS-1:0]                             s_axis_app_direct_tx_tvalid,
    output wire [PORTS-1:0]                             s_axis_app_direct_tx_tready,
    input  wire [PORTS-1:0]                             s_axis_app_direct_tx_tlast,
    input  wire [PORTS*AXIS_TX_USER_WIDTH-1:0]          s_axis_app_direct_tx_tuser,

    output wire [PORTS*PTP_TS_WIDTH-1:0]                m_axis_app_direct_tx_cpl_ts,
    output wire [PORTS*TX_TAG_WIDTH-1:0]                m_axis_app_direct_tx_cpl_tag,
    output wire [PORTS-1:0]                             m_axis_app_direct_tx_cpl_valid,
    input  wire [PORTS-1:0]                             m_axis_app_direct_tx_cpl_ready,

    input  wire [PORTS*PTP_TS_WIDTH-1:0]                s_axis_app_direct_tx_cpl_ts,
    input  wire [PORTS*TX_TAG_WIDTH-1:0]                s_axis_app_direct_tx_cpl_tag,
    input  wire [PORTS-1:0]                             s_axis_app_direct_tx_cpl_valid,
    output wire [PORTS-1:0]                             s_axis_app_direct_tx_cpl_ready,

    output wire [PORTS*AXIS_DATA_WIDTH-1:0]             m_axis_app_direct_rx_tdata,
    output wire [PORTS*AXIS_KEEP_WIDTH-1:0]             m_axis_app_direct_rx_tkeep,
    output wire [PORTS-1:0]                             m_axis_app_direct_rx_tvalid,
    input  wire [PORTS-1:0]                             m_axis_app_direct_rx_tready,
    output wire [PORTS-1:0]                             m_axis_app_direct_rx_tlast,
    output wire [PORTS*AXIS_RX_USER_WIDTH-1:0]          m_axis_app_direct_rx_tuser,

    input  wire [PORTS*AXIS_DATA_WIDTH-1:0]             s_axis_app_direct_rx_tdata,
    input  wire [PORTS*AXIS_KEEP_WIDTH-1:0]             s_axis_app_direct_rx_tkeep,
    input  wire [PORTS-1:0]                             s_axis_app_direct_rx_tvalid,
    output wire [PORTS-1:0]                             s_axis_app_direct_rx_tready,
    input  wire [PORTS-1:0]                             s_axis_app_direct_rx_tlast,
    input  wire [PORTS*AXIS_RX_USER_WIDTH-1:0]          s_axis_app_direct_rx_tuser,

    /*
     * Transmit data output
     */
    input  wire [PORTS-1:0]                             tx_clk,
    input  wire [PORTS-1:0]                             tx_rst,

    output wire [PORTS*AXIS_DATA_WIDTH-1:0]             m_axis_tx_tdata,
    output wire [PORTS*AXIS_KEEP_WIDTH-1:0]             m_axis_tx_tkeep,
    output wire [PORTS-1:0]                             m_axis_tx_tvalid,
    input  wire [PORTS-1:0]                             m_axis_tx_tready,
    output wire [PORTS-1:0]                             m_axis_tx_tlast,
    output wire [PORTS*AXIS_TX_USER_WIDTH-1:0]          m_axis_tx_tuser,

    input  wire [PORTS*PTP_TS_WIDTH-1:0]                s_axis_tx_cpl_ts,
    input  wire [PORTS*TX_TAG_WIDTH-1:0]                s_axis_tx_cpl_tag,
    input  wire [PORTS-1:0]                             s_axis_tx_cpl_valid,
    output wire [PORTS-1:0]                             s_axis_tx_cpl_ready,

    input  wire [PORTS-1:0]                             tx_status,

    /*
     * Receive data input
     */
    input  wire [PORTS-1:0]                             rx_clk,
    input  wire [PORTS-1:0]                             rx_rst,

    input  wire [PORTS*AXIS_DATA_WIDTH-1:0]             s_axis_rx_tdata,
    input  wire [PORTS*AXIS_KEEP_WIDTH-1:0]             s_axis_rx_tkeep,
    input  wire [PORTS-1:0]                             s_axis_rx_tvalid,
    output wire [PORTS-1:0]                             s_axis_rx_tready,
    input  wire [PORTS-1:0]                             s_axis_rx_tlast,
    input  wire [PORTS*AXIS_RX_USER_WIDTH-1:0]          s_axis_rx_tuser,

    input  wire [PORTS-1:0]                             rx_status,

    /*
     * PTP clock
     */
    input  wire [95:0]                                  ptp_ts_96,
    input  wire                                         ptp_ts_step,

    /*
     * Interrupt request output
     */
    output wire [IRQ_INDEX_WIDTH-1:0]                   irq_index,
    output wire                                         irq_valid,
    input  wire                                         irq_ready
);

parameter DESC_SIZE = 16;
parameter CPL_SIZE = 32;
parameter EVENT_SIZE = 32;

parameter AXIS_DESC_DATA_WIDTH = DESC_SIZE*8;
parameter AXIS_DESC_KEEP_WIDTH = AXIS_DESC_DATA_WIDTH/8;

parameter EVENT_SOURCE_WIDTH = 16;
parameter EVENT_TYPE_WIDTH = 16;

parameter MAX_DESC_TABLE_SIZE = TX_DESC_TABLE_SIZE > RX_DESC_TABLE_SIZE ? TX_DESC_TABLE_SIZE : RX_DESC_TABLE_SIZE;

parameter REQ_TAG_WIDTH_INT = $clog2(MAX_DESC_TABLE_SIZE);
parameter REQ_TAG_WIDTH = REQ_TAG_WIDTH_INT + $clog2(SCHEDULERS);

parameter DESC_REQ_TAG_WIDTH_INT = REQ_TAG_WIDTH;
parameter DESC_REQ_TAG_WIDTH = DESC_REQ_TAG_WIDTH_INT + $clog2(2);

parameter CPL_REQ_TAG_WIDTH_INT = $clog2(MAX_DESC_TABLE_SIZE);
parameter CPL_REQ_TAG_WIDTH = CPL_REQ_TAG_WIDTH_INT + $clog2(3);

parameter QUEUE_REQ_TAG_WIDTH = DESC_REQ_TAG_WIDTH;
parameter CPL_QUEUE_REQ_TAG_WIDTH = CPL_REQ_TAG_WIDTH;
parameter QUEUE_OP_TAG_WIDTH = 6;

parameter DMA_CLIENT_LEN_WIDTH = DMA_LEN_WIDTH;

parameter QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH > RX_QUEUE_INDEX_WIDTH ? TX_QUEUE_INDEX_WIDTH : RX_QUEUE_INDEX_WIDTH;
parameter CPL_QUEUE_INDEX_WIDTH = TX_CPL_QUEUE_INDEX_WIDTH > RX_CPL_QUEUE_INDEX_WIDTH ? TX_CPL_QUEUE_INDEX_WIDTH : RX_CPL_QUEUE_INDEX_WIDTH;

parameter AXIL_CSR_ADDR_WIDTH = AXIL_ADDR_WIDTH-5-$clog2((SCHEDULERS+3)/8);
parameter AXIL_CTRL_ADDR_WIDTH = AXIL_ADDR_WIDTH-5-$clog2((SCHEDULERS+3)/8);
parameter AXIL_EQM_ADDR_WIDTH = AXIL_ADDR_WIDTH-4-$clog2((SCHEDULERS+3)/8);
parameter AXIL_TX_QM_ADDR_WIDTH = AXIL_ADDR_WIDTH-3-$clog2((SCHEDULERS+3)/8);
parameter AXIL_TX_CQM_ADDR_WIDTH = AXIL_ADDR_WIDTH-3-$clog2((SCHEDULERS+3)/8);
parameter AXIL_RX_QM_ADDR_WIDTH = AXIL_ADDR_WIDTH-4-$clog2((SCHEDULERS+3)/8);
parameter AXIL_RX_CQM_ADDR_WIDTH = AXIL_ADDR_WIDTH-4-$clog2((SCHEDULERS+3)/8);
parameter AXIL_SCHED_ADDR_WIDTH = AXIL_ADDR_WIDTH-3-$clog2((SCHEDULERS+3)/8);

parameter AXIL_CSR_BASE_ADDR = 0;
parameter AXIL_CTRL_BASE_ADDR = AXIL_CSR_BASE_ADDR + 2**AXIL_CSR_ADDR_WIDTH;
parameter AXIL_EQM_BASE_ADDR = AXIL_CTRL_BASE_ADDR + 2**AXIL_CTRL_ADDR_WIDTH;
parameter AXIL_TX_QM_BASE_ADDR = AXIL_EQM_BASE_ADDR + 2**AXIL_EQM_ADDR_WIDTH;
parameter AXIL_TX_CQM_BASE_ADDR = AXIL_TX_QM_BASE_ADDR + 2**AXIL_TX_QM_ADDR_WIDTH;
parameter AXIL_RX_QM_BASE_ADDR = AXIL_TX_CQM_BASE_ADDR + 2**AXIL_TX_CQM_ADDR_WIDTH;
parameter AXIL_RX_CQM_BASE_ADDR = AXIL_RX_QM_BASE_ADDR + 2**AXIL_RX_QM_ADDR_WIDTH;
parameter AXIL_SCHED_BASE_ADDR = AXIL_RX_CQM_BASE_ADDR + 2**AXIL_RX_CQM_ADDR_WIDTH;

localparam REG_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH;
localparam REG_DATA_WIDTH = AXIL_DATA_WIDTH;
localparam REG_STRB_WIDTH = AXIL_STRB_WIDTH;

localparam RB_BASE_ADDR = AXIL_CTRL_BASE_ADDR;
localparam RBB = RB_BASE_ADDR & {AXIL_CTRL_ADDR_WIDTH{1'b1}};

localparam RX_RB_BASE_ADDR = RB_BASE_ADDR + 16'h100;

localparam PORT_RB_BASE_ADDR = RB_BASE_ADDR + 16'h1000;
localparam PORT_RB_STRIDE = 16'h1000;

localparam SCHED_RB_BASE_ADDR = (PORT_RB_BASE_ADDR + PORT_RB_STRIDE*PORTS);
localparam SCHED_RB_STRIDE = 16'h1000;

// parameter sizing helpers
function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

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

wire [AXIL_ADDR_WIDTH-1:0] axil_event_queue_manager_awaddr;
wire [2:0]                 axil_event_queue_manager_awprot;
wire                       axil_event_queue_manager_awvalid;
wire                       axil_event_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_event_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_event_queue_manager_wstrb;
wire                       axil_event_queue_manager_wvalid;
wire                       axil_event_queue_manager_wready;
wire [1:0]                 axil_event_queue_manager_bresp;
wire                       axil_event_queue_manager_bvalid;
wire                       axil_event_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_event_queue_manager_araddr;
wire [2:0]                 axil_event_queue_manager_arprot;
wire                       axil_event_queue_manager_arvalid;
wire                       axil_event_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_event_queue_manager_rdata;
wire [1:0]                 axil_event_queue_manager_rresp;
wire                       axil_event_queue_manager_rvalid;
wire                       axil_event_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_tx_queue_manager_awaddr;
wire [2:0]                 axil_tx_queue_manager_awprot;
wire                       axil_tx_queue_manager_awvalid;
wire                       axil_tx_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_tx_queue_manager_wstrb;
wire                       axil_tx_queue_manager_wvalid;
wire                       axil_tx_queue_manager_wready;
wire [1:0]                 axil_tx_queue_manager_bresp;
wire                       axil_tx_queue_manager_bvalid;
wire                       axil_tx_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_tx_queue_manager_araddr;
wire [2:0]                 axil_tx_queue_manager_arprot;
wire                       axil_tx_queue_manager_arvalid;
wire                       axil_tx_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_queue_manager_rdata;
wire [1:0]                 axil_tx_queue_manager_rresp;
wire                       axil_tx_queue_manager_rvalid;
wire                       axil_tx_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_tx_cpl_queue_manager_awaddr;
wire [2:0]                 axil_tx_cpl_queue_manager_awprot;
wire                       axil_tx_cpl_queue_manager_awvalid;
wire                       axil_tx_cpl_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_cpl_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_tx_cpl_queue_manager_wstrb;
wire                       axil_tx_cpl_queue_manager_wvalid;
wire                       axil_tx_cpl_queue_manager_wready;
wire [1:0]                 axil_tx_cpl_queue_manager_bresp;
wire                       axil_tx_cpl_queue_manager_bvalid;
wire                       axil_tx_cpl_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_tx_cpl_queue_manager_araddr;
wire [2:0]                 axil_tx_cpl_queue_manager_arprot;
wire                       axil_tx_cpl_queue_manager_arvalid;
wire                       axil_tx_cpl_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_cpl_queue_manager_rdata;
wire [1:0]                 axil_tx_cpl_queue_manager_rresp;
wire                       axil_tx_cpl_queue_manager_rvalid;
wire                       axil_tx_cpl_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_rx_queue_manager_awaddr;
wire [2:0]                 axil_rx_queue_manager_awprot;
wire                       axil_rx_queue_manager_awvalid;
wire                       axil_rx_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_rx_queue_manager_wstrb;
wire                       axil_rx_queue_manager_wvalid;
wire                       axil_rx_queue_manager_wready;
wire [1:0]                 axil_rx_queue_manager_bresp;
wire                       axil_rx_queue_manager_bvalid;
wire                       axil_rx_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_rx_queue_manager_araddr;
wire [2:0]                 axil_rx_queue_manager_arprot;
wire                       axil_rx_queue_manager_arvalid;
wire                       axil_rx_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_queue_manager_rdata;
wire [1:0]                 axil_rx_queue_manager_rresp;
wire                       axil_rx_queue_manager_rvalid;
wire                       axil_rx_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_rx_cpl_queue_manager_awaddr;
wire [2:0]                 axil_rx_cpl_queue_manager_awprot;
wire                       axil_rx_cpl_queue_manager_awvalid;
wire                       axil_rx_cpl_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_cpl_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_rx_cpl_queue_manager_wstrb;
wire                       axil_rx_cpl_queue_manager_wvalid;
wire                       axil_rx_cpl_queue_manager_wready;
wire [1:0]                 axil_rx_cpl_queue_manager_bresp;
wire                       axil_rx_cpl_queue_manager_bvalid;
wire                       axil_rx_cpl_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_rx_cpl_queue_manager_araddr;
wire [2:0]                 axil_rx_cpl_queue_manager_arprot;
wire                       axil_rx_cpl_queue_manager_arvalid;
wire                       axil_rx_cpl_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_cpl_queue_manager_rdata;
wire [1:0]                 axil_rx_cpl_queue_manager_rresp;
wire                       axil_rx_cpl_queue_manager_rvalid;
wire                       axil_rx_cpl_queue_manager_rready;

wire [SCHEDULERS*AXIL_ADDR_WIDTH-1:0] axil_sched_awaddr;
wire [SCHEDULERS*3-1:0]               axil_sched_awprot;
wire [SCHEDULERS-1:0]                 axil_sched_awvalid;
wire [SCHEDULERS-1:0]                 axil_sched_awready;
wire [SCHEDULERS*AXIL_DATA_WIDTH-1:0] axil_sched_wdata;
wire [SCHEDULERS*AXIL_STRB_WIDTH-1:0] axil_sched_wstrb;
wire [SCHEDULERS-1:0]                 axil_sched_wvalid;
wire [SCHEDULERS-1:0]                 axil_sched_wready;
wire [SCHEDULERS*2-1:0]               axil_sched_bresp;
wire [SCHEDULERS-1:0]                 axil_sched_bvalid;
wire [SCHEDULERS-1:0]                 axil_sched_bready;
wire [SCHEDULERS*AXIL_ADDR_WIDTH-1:0] axil_sched_araddr;
wire [SCHEDULERS*3-1:0]               axil_sched_arprot;
wire [SCHEDULERS-1:0]                 axil_sched_arvalid;
wire [SCHEDULERS-1:0]                 axil_sched_arready;
wire [SCHEDULERS*AXIL_DATA_WIDTH-1:0] axil_sched_rdata;
wire [SCHEDULERS*2-1:0]               axil_sched_rresp;
wire [SCHEDULERS-1:0]                 axil_sched_rvalid;
wire [SCHEDULERS-1:0]                 axil_sched_rready;

// Queue management
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    event_enqueue_req_queue;
wire [CPL_QUEUE_REQ_TAG_WIDTH-1:0]  event_enqueue_req_tag;
wire                                event_enqueue_req_valid;
wire                                event_enqueue_req_ready;

wire [DMA_ADDR_WIDTH-1:0]           event_enqueue_resp_addr;
wire [CPL_QUEUE_REQ_TAG_WIDTH-1:0]  event_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       event_enqueue_resp_op_tag;
wire                                event_enqueue_resp_full;
wire                                event_enqueue_resp_error;
wire                                event_enqueue_resp_valid;
wire                                event_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       event_enqueue_commit_op_tag;
wire                                event_enqueue_commit_valid;
wire                                event_enqueue_commit_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        tx_desc_dequeue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_desc_dequeue_req_tag;
wire                                tx_desc_dequeue_req_valid;
wire                                tx_desc_dequeue_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        tx_desc_dequeue_resp_queue;
wire [QUEUE_PTR_WIDTH-1:0]          tx_desc_dequeue_resp_ptr;
wire [DMA_ADDR_WIDTH-1:0]           tx_desc_dequeue_resp_addr;
wire [LOG_BLOCK_SIZE_WIDTH-1:0]     tx_desc_dequeue_resp_block_size;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    tx_desc_dequeue_resp_cpl;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_desc_dequeue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_desc_dequeue_resp_op_tag;
wire                                tx_desc_dequeue_resp_empty;
wire                                tx_desc_dequeue_resp_error;
wire                                tx_desc_dequeue_resp_valid;
wire                                tx_desc_dequeue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_desc_dequeue_commit_op_tag;
wire                                tx_desc_dequeue_commit_valid;
wire                                tx_desc_dequeue_commit_ready;

wire [TX_QUEUE_INDEX_WIDTH-1:0]     tx_doorbell_queue;
wire                                tx_doorbell_valid;

wire [CPL_QUEUE_INDEX_WIDTH-1:0]    tx_cpl_enqueue_req_queue;
wire [CPL_QUEUE_REQ_TAG_WIDTH-1:0]  tx_cpl_enqueue_req_tag;
wire                                tx_cpl_enqueue_req_valid;
wire                                tx_cpl_enqueue_req_ready;

wire [DMA_ADDR_WIDTH-1:0]           tx_cpl_enqueue_resp_addr;
wire [CPL_QUEUE_REQ_TAG_WIDTH-1:0]  tx_cpl_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_cpl_enqueue_resp_op_tag;
wire                                tx_cpl_enqueue_resp_full;
wire                                tx_cpl_enqueue_resp_error;
wire                                tx_cpl_enqueue_resp_valid;
wire                                tx_cpl_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_cpl_enqueue_commit_op_tag;
wire                                tx_cpl_enqueue_commit_valid;
wire                                tx_cpl_enqueue_commit_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        rx_desc_dequeue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_desc_dequeue_req_tag;
wire                                rx_desc_dequeue_req_valid;
wire                                rx_desc_dequeue_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        rx_desc_dequeue_resp_queue;
wire [QUEUE_PTR_WIDTH-1:0]          rx_desc_dequeue_resp_ptr;
wire [DMA_ADDR_WIDTH-1:0]           rx_desc_dequeue_resp_addr;
wire [LOG_BLOCK_SIZE_WIDTH-1:0]     rx_desc_dequeue_resp_block_size;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    rx_desc_dequeue_resp_cpl;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_desc_dequeue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_desc_dequeue_resp_op_tag;
wire                                rx_desc_dequeue_resp_empty;
wire                                rx_desc_dequeue_resp_error;
wire                                rx_desc_dequeue_resp_valid;
wire                                rx_desc_dequeue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_desc_dequeue_commit_op_tag;
wire                                rx_desc_dequeue_commit_valid;
wire                                rx_desc_dequeue_commit_ready;

wire [CPL_QUEUE_INDEX_WIDTH-1:0]    rx_cpl_enqueue_req_queue;
wire [CPL_QUEUE_REQ_TAG_WIDTH-1:0]  rx_cpl_enqueue_req_tag;
wire                                rx_cpl_enqueue_req_valid;
wire                                rx_cpl_enqueue_req_ready;

wire [DMA_ADDR_WIDTH-1:0]           rx_cpl_enqueue_resp_addr;
wire [CPL_QUEUE_REQ_TAG_WIDTH-1:0]  rx_cpl_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_cpl_enqueue_resp_op_tag;
wire                                rx_cpl_enqueue_resp_full;
wire                                rx_cpl_enqueue_resp_error;
wire                                rx_cpl_enqueue_resp_valid;
wire                                rx_cpl_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_cpl_enqueue_commit_op_tag;
wire                                rx_cpl_enqueue_commit_valid;
wire                                rx_cpl_enqueue_commit_ready;

// descriptors
wire [0:0]                          desc_req_sel;
wire [QUEUE_INDEX_WIDTH-1:0]        desc_req_queue;
wire [DESC_REQ_TAG_WIDTH-1:0]       desc_req_tag;
wire                                desc_req_valid;
wire                                desc_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        desc_req_status_queue;
wire [QUEUE_PTR_WIDTH-1:0]          desc_req_status_ptr;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    desc_req_status_cpl;
wire [DESC_REQ_TAG_WIDTH-1:0]       desc_req_status_tag;
wire                                desc_req_status_empty;
wire                                desc_req_status_error;
wire                                desc_req_status_valid;

wire [AXIS_DESC_DATA_WIDTH-1:0]     axis_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]     axis_desc_tkeep;
wire                                axis_desc_tvalid;
wire                                axis_desc_tready;
wire                                axis_desc_tlast;
wire [DESC_REQ_TAG_WIDTH-1:0]       axis_desc_tid;
wire                                axis_desc_tuser;

wire [0:0]                          rx_desc_req_sel = 1'b1;
wire [QUEUE_INDEX_WIDTH-1:0]        rx_desc_req_queue;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]   rx_desc_req_tag;
wire                                rx_desc_req_valid;
wire                                rx_desc_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        rx_desc_req_status_queue;
wire [QUEUE_PTR_WIDTH-1:0]          rx_desc_req_status_ptr;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    rx_desc_req_status_cpl;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]   rx_desc_req_status_tag;
wire                                rx_desc_req_status_empty;
wire                                rx_desc_req_status_error;
wire                                rx_desc_req_status_valid;

wire [AXIS_DESC_DATA_WIDTH-1:0]     rx_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]     rx_desc_tkeep;
wire                                rx_desc_tvalid;
wire                                rx_desc_tready;
wire                                rx_desc_tlast;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]   rx_desc_tid;
wire                                rx_desc_tuser;

wire [0:0]                          tx_desc_req_sel = 1'b0;
wire [QUEUE_INDEX_WIDTH-1:0]        tx_desc_req_queue;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]   tx_desc_req_tag;
wire                                tx_desc_req_valid;
wire                                tx_desc_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        tx_desc_req_status_queue;
wire [QUEUE_PTR_WIDTH-1:0]          tx_desc_req_status_ptr;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    tx_desc_req_status_cpl;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]   tx_desc_req_status_tag;
wire                                tx_desc_req_status_empty;
wire                                tx_desc_req_status_error;
wire                                tx_desc_req_status_valid;

wire [AXIS_DESC_DATA_WIDTH-1:0]     tx_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]     tx_desc_tkeep;
wire                                tx_desc_tvalid;
wire                                tx_desc_tready;
wire                                tx_desc_tlast;
wire [DESC_REQ_TAG_WIDTH_INT-1:0]   tx_desc_tid;
wire                                tx_desc_tuser;

// completions
wire [1:0]                          cpl_req_sel;
wire [QUEUE_INDEX_WIDTH-1:0]        cpl_req_queue;
wire [CPL_REQ_TAG_WIDTH-1:0]        cpl_req_tag;
wire [CPL_SIZE*8-1:0]               cpl_req_data;
wire                                cpl_req_valid;
wire                                cpl_req_ready;

wire [CPL_REQ_TAG_WIDTH-1:0]        cpl_req_status_tag;
wire                                cpl_req_status_full;
wire                                cpl_req_status_error;
wire                                cpl_req_status_valid;

wire [1:0]                          event_cpl_req_sel = 2'd2;
wire [QUEUE_INDEX_WIDTH-1:0]        event_cpl_req_queue;
wire [CPL_REQ_TAG_WIDTH_INT-1:0]    event_cpl_req_tag;
wire [CPL_SIZE*8-1:0]               event_cpl_req_data;
wire                                event_cpl_req_valid;
wire                                event_cpl_req_ready;

wire [CPL_REQ_TAG_WIDTH_INT-1:0]    event_cpl_req_status_tag;
wire                                event_cpl_req_status_full;
wire                                event_cpl_req_status_error;
wire                                event_cpl_req_status_valid;

wire [1:0]                          rx_cpl_req_sel = 2'd1;
wire [QUEUE_INDEX_WIDTH-1:0]        rx_cpl_req_queue;
wire [CPL_REQ_TAG_WIDTH_INT-1:0]    rx_cpl_req_tag;
wire [CPL_SIZE*8-1:0]               rx_cpl_req_data;
wire                                rx_cpl_req_valid;
wire                                rx_cpl_req_ready;

wire [CPL_REQ_TAG_WIDTH_INT-1:0]    rx_cpl_req_status_tag;
wire                                rx_cpl_req_status_full;
wire                                rx_cpl_req_status_error;
wire                                rx_cpl_req_status_valid;

wire [1:0]                          tx_cpl_req_sel = 2'd0;
wire [QUEUE_INDEX_WIDTH-1:0]        tx_cpl_req_queue;
wire [CPL_REQ_TAG_WIDTH_INT-1:0]    tx_cpl_req_tag;
wire [CPL_SIZE*8-1:0]               tx_cpl_req_data;
wire                                tx_cpl_req_valid;
wire                                tx_cpl_req_ready;

wire [CPL_REQ_TAG_WIDTH_INT-1:0]    tx_cpl_req_status_tag;
wire                                tx_cpl_req_status_full;
wire                                tx_cpl_req_status_error;
wire                                tx_cpl_req_status_valid;

// events
wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  axis_event_queue;
wire [EVENT_TYPE_WIDTH-1:0]         axis_event_type;
wire [EVENT_SOURCE_WIDTH-1:0]       axis_event_source;
wire                                axis_event_valid;
wire                                axis_event_ready;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  tx_fifo_event;
wire [EVENT_TYPE_WIDTH-1:0]         tx_fifo_event_type;
wire [EVENT_SOURCE_WIDTH-1:0]       tx_fifo_event_source;
wire                                tx_fifo_event_valid;
wire                                tx_fifo_event_ready;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  rx_fifo_event;
wire [EVENT_TYPE_WIDTH-1:0]         rx_fifo_event_type;
wire [EVENT_SOURCE_WIDTH-1:0]       rx_fifo_event_source;
wire                                rx_fifo_event_valid;
wire                                rx_fifo_event_ready;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  tx_event;
wire [EVENT_TYPE_WIDTH-1:0]         tx_event_type = 16'd0;
wire [EVENT_SOURCE_WIDTH-1:0]       tx_event_source;
wire                                tx_event_valid;
wire                                tx_event_ready;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  rx_event;
wire [EVENT_TYPE_WIDTH-1:0]         rx_event_type = 16'd1;
wire [EVENT_SOURCE_WIDTH-1:0]       rx_event_source;
wire                                rx_event_valid;
wire                                rx_event_ready;

// interrupts
wire [IRQ_INDEX_WIDTH-1:0]  event_irq_index;
wire                        event_irq_valid;
wire                        event_irq_ready;

axis_fifo #(
    .DEPTH(128),
    .DATA_WIDTH(IRQ_INDEX_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
irq_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(event_irq_index),
    .s_axis_tkeep(0),
    .s_axis_tvalid(event_irq_valid),
    .s_axis_tready(event_irq_ready),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_axis_tdata(irq_index),
    .m_axis_tkeep(),
    .m_axis_tvalid(irq_valid),
    .m_axis_tready(irq_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

// control registers
wire [REG_ADDR_WIDTH-1:0]  ctrl_reg_wr_addr;
wire [REG_DATA_WIDTH-1:0]  ctrl_reg_wr_data;
wire [REG_STRB_WIDTH-1:0]  ctrl_reg_wr_strb;
wire                       ctrl_reg_wr_en;
wire                       ctrl_reg_wr_wait;
wire                       ctrl_reg_wr_ack;
wire [REG_ADDR_WIDTH-1:0]  ctrl_reg_rd_addr;
wire                       ctrl_reg_rd_en;
wire [REG_DATA_WIDTH-1:0]  ctrl_reg_rd_data;
wire                       ctrl_reg_rd_wait;
wire                       ctrl_reg_rd_ack;

axil_reg_if #(
    .DATA_WIDTH(REG_DATA_WIDTH),
    .ADDR_WIDTH(REG_ADDR_WIDTH),
    .STRB_WIDTH(REG_STRB_WIDTH),
    .TIMEOUT(4)
)
axil_reg_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_ctrl_awaddr),
    .s_axil_awprot(axil_ctrl_awprot),
    .s_axil_awvalid(axil_ctrl_awvalid),
    .s_axil_awready(axil_ctrl_awready),
    .s_axil_wdata(axil_ctrl_wdata),
    .s_axil_wstrb(axil_ctrl_wstrb),
    .s_axil_wvalid(axil_ctrl_wvalid),
    .s_axil_wready(axil_ctrl_wready),
    .s_axil_bresp(axil_ctrl_bresp),
    .s_axil_bvalid(axil_ctrl_bvalid),
    .s_axil_bready(axil_ctrl_bready),
    .s_axil_araddr(axil_ctrl_araddr),
    .s_axil_arprot(axil_ctrl_arprot),
    .s_axil_arvalid(axil_ctrl_arvalid),
    .s_axil_arready(axil_ctrl_arready),
    .s_axil_rdata(axil_ctrl_rdata),
    .s_axil_rresp(axil_ctrl_rresp),
    .s_axil_rvalid(axil_ctrl_rvalid),
    .s_axil_rready(axil_ctrl_rready),

    /*
     * Register interface
     */
    .reg_wr_addr(ctrl_reg_wr_addr),
    .reg_wr_data(ctrl_reg_wr_data),
    .reg_wr_strb(ctrl_reg_wr_strb),
    .reg_wr_en(ctrl_reg_wr_en),
    .reg_wr_wait(ctrl_reg_wr_wait),
    .reg_wr_ack(ctrl_reg_wr_ack),
    .reg_rd_addr(ctrl_reg_rd_addr),
    .reg_rd_en(ctrl_reg_rd_en),
    .reg_rd_data(ctrl_reg_rd_data),
    .reg_rd_wait(ctrl_reg_rd_wait),
    .reg_rd_ack(ctrl_reg_rd_ack)
);

reg ctrl_reg_wr_ack_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = {AXIL_DATA_WIDTH{1'b0}};
reg ctrl_reg_rd_ack_reg = 1'b0;

wire if_rx_ctrl_reg_wr_wait;
wire if_rx_ctrl_reg_wr_ack;
wire [AXIL_DATA_WIDTH-1:0] if_rx_ctrl_reg_rd_data;
wire if_rx_ctrl_reg_rd_wait;
wire if_rx_ctrl_reg_rd_ack;

wire sched_ctrl_reg_wr_wait[SCHEDULERS-1:0];
wire sched_ctrl_reg_wr_ack[SCHEDULERS-1:0];
wire [AXIL_DATA_WIDTH-1:0] sched_ctrl_reg_rd_data[SCHEDULERS-1:0];
wire sched_ctrl_reg_rd_wait[SCHEDULERS-1:0];
wire sched_ctrl_reg_rd_ack[SCHEDULERS-1:0];

wire port_ctrl_reg_wr_wait[PORTS-1:0];
wire port_ctrl_reg_wr_ack[PORTS-1:0];
wire [AXIL_DATA_WIDTH-1:0] port_ctrl_reg_rd_data[PORTS-1:0];
wire port_ctrl_reg_rd_wait[PORTS-1:0];
wire port_ctrl_reg_rd_ack[PORTS-1:0];

reg ctrl_reg_wr_wait_cmb;
reg ctrl_reg_wr_ack_cmb;
reg [AXIL_DATA_WIDTH-1:0] ctrl_reg_rd_data_cmb;
reg ctrl_reg_rd_wait_cmb;
reg ctrl_reg_rd_ack_cmb;

assign ctrl_reg_wr_wait = ctrl_reg_wr_wait_cmb;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_cmb;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_cmb;
assign ctrl_reg_rd_wait = ctrl_reg_rd_wait_cmb;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_cmb;

integer k;

always @* begin
    ctrl_reg_wr_wait_cmb = if_rx_ctrl_reg_wr_wait;
    ctrl_reg_wr_ack_cmb = ctrl_reg_wr_ack_reg | if_rx_ctrl_reg_wr_ack;
    ctrl_reg_rd_data_cmb = ctrl_reg_rd_data_reg | if_rx_ctrl_reg_rd_data;
    ctrl_reg_rd_wait_cmb = if_rx_ctrl_reg_rd_wait;
    ctrl_reg_rd_ack_cmb = ctrl_reg_rd_ack_reg | if_rx_ctrl_reg_rd_ack;

    for (k = 0; k < SCHEDULERS; k = k + 1) begin
        ctrl_reg_wr_wait_cmb = ctrl_reg_wr_wait_cmb | sched_ctrl_reg_wr_wait[k];
        ctrl_reg_wr_ack_cmb = ctrl_reg_wr_ack_cmb | sched_ctrl_reg_wr_ack[k];
        ctrl_reg_rd_data_cmb = ctrl_reg_rd_data_cmb | sched_ctrl_reg_rd_data[k];
        ctrl_reg_rd_wait_cmb = ctrl_reg_rd_wait_cmb | sched_ctrl_reg_rd_wait[k];
        ctrl_reg_rd_ack_cmb = ctrl_reg_rd_ack_cmb | sched_ctrl_reg_rd_ack[k];
    end

    for (k = 0; k < PORTS; k = k + 1) begin
        ctrl_reg_wr_wait_cmb = ctrl_reg_wr_wait_cmb | port_ctrl_reg_wr_wait[k];
        ctrl_reg_wr_ack_cmb = ctrl_reg_wr_ack_cmb | port_ctrl_reg_wr_ack[k];
        ctrl_reg_rd_data_cmb = ctrl_reg_rd_data_cmb | port_ctrl_reg_rd_data[k];
        ctrl_reg_rd_wait_cmb = ctrl_reg_rd_wait_cmb | port_ctrl_reg_rd_wait[k];
        ctrl_reg_rd_ack_cmb = ctrl_reg_rd_ack_cmb | port_ctrl_reg_rd_ack[k];
    end
end

reg [DMA_CLIENT_LEN_WIDTH-1:0] tx_mtu_reg = MAX_TX_SIZE;
reg [DMA_CLIENT_LEN_WIDTH-1:0] rx_mtu_reg = MAX_RX_SIZE;

always @(posedge clk) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b1;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            // Interface control
            RBB+8'h28: tx_mtu_reg <= ctrl_reg_wr_data;                      // IF ctrl: TX MTU
            RBB+8'h2C: rx_mtu_reg <= ctrl_reg_wr_data;                      // IF ctrl: RX MTU
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            // Interface control
            RBB+8'h00: ctrl_reg_rd_data_reg <= 32'h0000C001;                // IF ctrl: Type
            RBB+8'h04: ctrl_reg_rd_data_reg <= 32'h00000400;                // IF ctrl: Version
            RBB+8'h08: ctrl_reg_rd_data_reg <= RB_BASE_ADDR+8'h40;          // IF ctrl: Next header
            RBB+8'h0C: begin
                // IF ctrl: features
                ctrl_reg_rd_data_reg[0] <= RX_HASH_ENABLE;
                ctrl_reg_rd_data_reg[4] <= PTP_TS_ENABLE;
                ctrl_reg_rd_data_reg[8] <= TX_CHECKSUM_ENABLE;
                ctrl_reg_rd_data_reg[9] <= RX_CHECKSUM_ENABLE;
                ctrl_reg_rd_data_reg[10] <= RX_HASH_ENABLE;
            end
            RBB+8'h10: ctrl_reg_rd_data_reg <= PORTS;                       // IF ctrl: Port count
            RBB+8'h14: ctrl_reg_rd_data_reg <= SCHEDULERS;                  // IF ctrl: Scheduler count
            RBB+8'h20: ctrl_reg_rd_data_reg <= MAX_TX_SIZE;                 // IF ctrl: Max TX MTU
            RBB+8'h24: ctrl_reg_rd_data_reg <= MAX_RX_SIZE;                 // IF ctrl: Max RX MTU
            RBB+8'h28: ctrl_reg_rd_data_reg <= tx_mtu_reg;                  // IF ctrl: TX MTU
            RBB+8'h2C: ctrl_reg_rd_data_reg <= rx_mtu_reg;                  // IF ctrl: RX MTU
            // Queue manager (Event)
            RBB+8'h40: ctrl_reg_rd_data_reg <= 32'h0000C010;                // Event QM: Type
            RBB+8'h44: ctrl_reg_rd_data_reg <= 32'h00000100;                // Event QM: Version
            RBB+8'h48: ctrl_reg_rd_data_reg <= RB_BASE_ADDR+8'h60;          // Event QM: Next header
            RBB+8'h4C: ctrl_reg_rd_data_reg <= AXIL_EQM_BASE_ADDR;          // Event QM: Offset
            RBB+8'h50: ctrl_reg_rd_data_reg <= 2**EVENT_QUEUE_INDEX_WIDTH;  // Event QM: Count
            RBB+8'h54: ctrl_reg_rd_data_reg <= 32;                          // Event QM: Stride
            // Queue manager (TX)
            RBB+8'h60: ctrl_reg_rd_data_reg <= 32'h0000C020;                // TX QM: Type
            RBB+8'h64: ctrl_reg_rd_data_reg <= 32'h00000100;                // TX QM: Version
            RBB+8'h68: ctrl_reg_rd_data_reg <= RB_BASE_ADDR+8'h80;          // TX QM: Next header
            RBB+8'h6C: ctrl_reg_rd_data_reg <= AXIL_TX_QM_BASE_ADDR;        // TX QM: Offset
            RBB+8'h70: ctrl_reg_rd_data_reg <= 2**TX_QUEUE_INDEX_WIDTH;     // TX QM: Count
            RBB+8'h74: ctrl_reg_rd_data_reg <= 32;                          // TX QM: Stride
            // Queue manager (TX CPL)
            RBB+8'h80: ctrl_reg_rd_data_reg <= 32'h0000C030;                // TX CPL QM: Type
            RBB+8'h84: ctrl_reg_rd_data_reg <= 32'h00000100;                // TX CPL QM: Version
            RBB+8'h88: ctrl_reg_rd_data_reg <= RB_BASE_ADDR+8'hA0;          // TX CPL QM: Next header
            RBB+8'h8C: ctrl_reg_rd_data_reg <= AXIL_TX_CQM_BASE_ADDR;       // TX CPL QM: Offset
            RBB+8'h90: ctrl_reg_rd_data_reg <= 2**TX_CPL_QUEUE_INDEX_WIDTH; // TX CPL QM: Count
            RBB+8'h94: ctrl_reg_rd_data_reg <= 32;                          // TX CPL QM: Stride
            // Queue manager (RX)
            RBB+8'hA0: ctrl_reg_rd_data_reg <= 32'h0000C021;                // RX QM: Type
            RBB+8'hA4: ctrl_reg_rd_data_reg <= 32'h00000100;                // RX QM: Version
            RBB+8'hA8: ctrl_reg_rd_data_reg <= RB_BASE_ADDR+8'hC0;          // RX QM: Next header
            RBB+8'hAC: ctrl_reg_rd_data_reg <= AXIL_RX_QM_BASE_ADDR;        // RX QM: Offset
            RBB+8'hB0: ctrl_reg_rd_data_reg <= 2**RX_QUEUE_INDEX_WIDTH;     // RX QM: Count
            RBB+8'hB4: ctrl_reg_rd_data_reg <= 32;                          // RX QM: Stride
            // Queue manager (RX CPL)
            RBB+8'hC0: ctrl_reg_rd_data_reg <= 32'h0000C031;                // RX CPL QM: Type
            RBB+8'hC4: ctrl_reg_rd_data_reg <= 32'h00000100;                // RX CPL QM: Version
            RBB+8'hC8: ctrl_reg_rd_data_reg <= RX_RB_BASE_ADDR;             // RX CPL QM: Next header
            RBB+8'hCC: ctrl_reg_rd_data_reg <= AXIL_RX_CQM_BASE_ADDR;       // RX CPL QM: Offset
            RBB+8'hD0: ctrl_reg_rd_data_reg <= 2**RX_CPL_QUEUE_INDEX_WIDTH; // RX CPL QM: Count
            RBB+8'hD4: ctrl_reg_rd_data_reg <= 32;                          // RX CPL QM: Stride
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        tx_mtu_reg <= MAX_TX_SIZE;
        rx_mtu_reg <= MAX_RX_SIZE;
    end
end

// AXI lite crossbar
parameter AXIL_S_COUNT = 1;
parameter AXIL_M_COUNT = 7+SCHEDULERS;

axil_crossbar #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .S_COUNT(AXIL_S_COUNT),
    .M_COUNT(AXIL_M_COUNT),
    .M_ADDR_WIDTH({{SCHEDULERS{w_32(AXIL_SCHED_ADDR_WIDTH)}}, w_32(AXIL_RX_CQM_ADDR_WIDTH), w_32(AXIL_RX_QM_ADDR_WIDTH), w_32(AXIL_TX_CQM_ADDR_WIDTH), w_32(AXIL_TX_QM_ADDR_WIDTH), w_32(AXIL_EQM_ADDR_WIDTH), w_32(AXIL_CTRL_ADDR_WIDTH), w_32(AXIL_CSR_ADDR_WIDTH)}),
    .M_CONNECT_READ({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}})
)
axil_crossbar_inst (
    .clk(clk),
    .rst(rst),
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
    .m_axil_awaddr( {axil_sched_awaddr,  axil_rx_cpl_queue_manager_awaddr,  axil_rx_queue_manager_awaddr,  axil_tx_cpl_queue_manager_awaddr,  axil_tx_queue_manager_awaddr,  axil_event_queue_manager_awaddr,  axil_ctrl_awaddr,  m_axil_csr_awaddr}),
    .m_axil_awprot( {axil_sched_awprot,  axil_rx_cpl_queue_manager_awprot,  axil_rx_queue_manager_awprot,  axil_tx_cpl_queue_manager_awprot,  axil_tx_queue_manager_awprot,  axil_event_queue_manager_awprot,  axil_ctrl_awprot,  m_axil_csr_awprot}),
    .m_axil_awvalid({axil_sched_awvalid, axil_rx_cpl_queue_manager_awvalid, axil_rx_queue_manager_awvalid, axil_tx_cpl_queue_manager_awvalid, axil_tx_queue_manager_awvalid, axil_event_queue_manager_awvalid, axil_ctrl_awvalid, m_axil_csr_awvalid}),
    .m_axil_awready({axil_sched_awready, axil_rx_cpl_queue_manager_awready, axil_rx_queue_manager_awready, axil_tx_cpl_queue_manager_awready, axil_tx_queue_manager_awready, axil_event_queue_manager_awready, axil_ctrl_awready, m_axil_csr_awready}),
    .m_axil_wdata(  {axil_sched_wdata,   axil_rx_cpl_queue_manager_wdata,   axil_rx_queue_manager_wdata,   axil_tx_cpl_queue_manager_wdata,   axil_tx_queue_manager_wdata,   axil_event_queue_manager_wdata,   axil_ctrl_wdata,   m_axil_csr_wdata}),
    .m_axil_wstrb(  {axil_sched_wstrb,   axil_rx_cpl_queue_manager_wstrb,   axil_rx_queue_manager_wstrb,   axil_tx_cpl_queue_manager_wstrb,   axil_tx_queue_manager_wstrb,   axil_event_queue_manager_wstrb,   axil_ctrl_wstrb,   m_axil_csr_wstrb}),
    .m_axil_wvalid( {axil_sched_wvalid,  axil_rx_cpl_queue_manager_wvalid,  axil_rx_queue_manager_wvalid,  axil_tx_cpl_queue_manager_wvalid,  axil_tx_queue_manager_wvalid,  axil_event_queue_manager_wvalid,  axil_ctrl_wvalid,  m_axil_csr_wvalid}),
    .m_axil_wready( {axil_sched_wready,  axil_rx_cpl_queue_manager_wready,  axil_rx_queue_manager_wready,  axil_tx_cpl_queue_manager_wready,  axil_tx_queue_manager_wready,  axil_event_queue_manager_wready,  axil_ctrl_wready,  m_axil_csr_wready}),
    .m_axil_bresp(  {axil_sched_bresp,   axil_rx_cpl_queue_manager_bresp,   axil_rx_queue_manager_bresp,   axil_tx_cpl_queue_manager_bresp,   axil_tx_queue_manager_bresp,   axil_event_queue_manager_bresp,   axil_ctrl_bresp,   m_axil_csr_bresp}),
    .m_axil_bvalid( {axil_sched_bvalid,  axil_rx_cpl_queue_manager_bvalid,  axil_rx_queue_manager_bvalid,  axil_tx_cpl_queue_manager_bvalid,  axil_tx_queue_manager_bvalid,  axil_event_queue_manager_bvalid,  axil_ctrl_bvalid,  m_axil_csr_bvalid}),
    .m_axil_bready( {axil_sched_bready,  axil_rx_cpl_queue_manager_bready,  axil_rx_queue_manager_bready,  axil_tx_cpl_queue_manager_bready,  axil_tx_queue_manager_bready,  axil_event_queue_manager_bready,  axil_ctrl_bready,  m_axil_csr_bready}),
    .m_axil_araddr( {axil_sched_araddr,  axil_rx_cpl_queue_manager_araddr,  axil_rx_queue_manager_araddr,  axil_tx_cpl_queue_manager_araddr,  axil_tx_queue_manager_araddr,  axil_event_queue_manager_araddr,  axil_ctrl_araddr,  m_axil_csr_araddr}),
    .m_axil_arprot( {axil_sched_arprot,  axil_rx_cpl_queue_manager_arprot,  axil_rx_queue_manager_arprot,  axil_tx_cpl_queue_manager_arprot,  axil_tx_queue_manager_arprot,  axil_event_queue_manager_arprot,  axil_ctrl_arprot,  m_axil_csr_arprot}),
    .m_axil_arvalid({axil_sched_arvalid, axil_rx_cpl_queue_manager_arvalid, axil_rx_queue_manager_arvalid, axil_tx_cpl_queue_manager_arvalid, axil_tx_queue_manager_arvalid, axil_event_queue_manager_arvalid, axil_ctrl_arvalid, m_axil_csr_arvalid}),
    .m_axil_arready({axil_sched_arready, axil_rx_cpl_queue_manager_arready, axil_rx_queue_manager_arready, axil_tx_cpl_queue_manager_arready, axil_tx_queue_manager_arready, axil_event_queue_manager_arready, axil_ctrl_arready, m_axil_csr_arready}),
    .m_axil_rdata(  {axil_sched_rdata,   axil_rx_cpl_queue_manager_rdata,   axil_rx_queue_manager_rdata,   axil_tx_cpl_queue_manager_rdata,   axil_tx_queue_manager_rdata,   axil_event_queue_manager_rdata,   axil_ctrl_rdata,   m_axil_csr_rdata}),
    .m_axil_rresp(  {axil_sched_rresp,   axil_rx_cpl_queue_manager_rresp,   axil_rx_queue_manager_rresp,   axil_tx_cpl_queue_manager_rresp,   axil_tx_queue_manager_rresp,   axil_event_queue_manager_rresp,   axil_ctrl_rresp,   m_axil_csr_rresp}),
    .m_axil_rvalid( {axil_sched_rvalid,  axil_rx_cpl_queue_manager_rvalid,  axil_rx_queue_manager_rvalid,  axil_tx_cpl_queue_manager_rvalid,  axil_tx_queue_manager_rvalid,  axil_event_queue_manager_rvalid,  axil_ctrl_rvalid,  m_axil_csr_rvalid}),
    .m_axil_rready( {axil_sched_rready,  axil_rx_cpl_queue_manager_rready,  axil_rx_queue_manager_rready,  axil_tx_cpl_queue_manager_rready,  axil_tx_queue_manager_rready,  axil_event_queue_manager_rready,  axil_ctrl_rready,  m_axil_csr_rready})
);

// Queue managers

cpl_queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(CPL_QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(IRQ_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .CPL_SIZE(EVENT_SIZE),
    .PIPELINE(EVENT_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_EQM_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
event_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Enqueue request input
     */
    .s_axis_enqueue_req_queue(event_enqueue_req_queue),
    .s_axis_enqueue_req_tag(event_enqueue_req_tag),
    .s_axis_enqueue_req_valid(event_enqueue_req_valid),
    .s_axis_enqueue_req_ready(event_enqueue_req_ready),

    /*
     * Enqueue response output
     */
    .m_axis_enqueue_resp_queue(),
    .m_axis_enqueue_resp_ptr(),
    .m_axis_enqueue_resp_addr(event_enqueue_resp_addr),
    .m_axis_enqueue_resp_event(),
    .m_axis_enqueue_resp_tag(event_enqueue_resp_tag),
    .m_axis_enqueue_resp_op_tag(event_enqueue_resp_op_tag),
    .m_axis_enqueue_resp_full(event_enqueue_resp_full),
    .m_axis_enqueue_resp_error(event_enqueue_resp_error),
    .m_axis_enqueue_resp_valid(event_enqueue_resp_valid),
    .m_axis_enqueue_resp_ready(event_enqueue_resp_ready),

    /*
     * Enqueue commit input
     */
    .s_axis_enqueue_commit_op_tag(event_enqueue_commit_op_tag),
    .s_axis_enqueue_commit_valid(event_enqueue_commit_valid),
    .s_axis_enqueue_commit_ready(event_enqueue_commit_ready),

    /*
     * Event output
     */
    .m_axis_event(event_irq_index),
    .m_axis_event_source(),
    .m_axis_event_valid(event_irq_valid),
    .m_axis_event_ready(event_irq_ready),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_event_queue_manager_awaddr),
    .s_axil_awprot(axil_event_queue_manager_awprot),
    .s_axil_awvalid(axil_event_queue_manager_awvalid),
    .s_axil_awready(axil_event_queue_manager_awready),
    .s_axil_wdata(axil_event_queue_manager_wdata),
    .s_axil_wstrb(axil_event_queue_manager_wstrb),
    .s_axil_wvalid(axil_event_queue_manager_wvalid),
    .s_axil_wready(axil_event_queue_manager_wready),
    .s_axil_bresp(axil_event_queue_manager_bresp),
    .s_axil_bvalid(axil_event_queue_manager_bvalid),
    .s_axil_bready(axil_event_queue_manager_bready),
    .s_axil_araddr(axil_event_queue_manager_araddr),
    .s_axil_arprot(axil_event_queue_manager_arprot),
    .s_axil_arvalid(axil_event_queue_manager_arvalid),
    .s_axil_arready(axil_event_queue_manager_arready),
    .s_axil_rdata(axil_event_queue_manager_rdata),
    .s_axil_rresp(axil_event_queue_manager_rresp),
    .s_axil_rvalid(axil_event_queue_manager_rvalid),
    .s_axil_rready(axil_event_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .CPL_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),
    .PIPELINE(TX_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_TX_QM_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
tx_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Dequeue request input
     */
    .s_axis_dequeue_req_queue(tx_desc_dequeue_req_queue),
    .s_axis_dequeue_req_tag(tx_desc_dequeue_req_tag),
    .s_axis_dequeue_req_valid(tx_desc_dequeue_req_valid),
    .s_axis_dequeue_req_ready(tx_desc_dequeue_req_ready),

    /*
     * Dequeue response output
     */
    .m_axis_dequeue_resp_queue(tx_desc_dequeue_resp_queue),
    .m_axis_dequeue_resp_ptr(tx_desc_dequeue_resp_ptr),
    .m_axis_dequeue_resp_addr(tx_desc_dequeue_resp_addr),
    .m_axis_dequeue_resp_block_size(tx_desc_dequeue_resp_block_size),
    .m_axis_dequeue_resp_cpl(tx_desc_dequeue_resp_cpl),
    .m_axis_dequeue_resp_tag(tx_desc_dequeue_resp_tag),
    .m_axis_dequeue_resp_op_tag(tx_desc_dequeue_resp_op_tag),
    .m_axis_dequeue_resp_empty(tx_desc_dequeue_resp_empty),
    .m_axis_dequeue_resp_error(tx_desc_dequeue_resp_error),
    .m_axis_dequeue_resp_valid(tx_desc_dequeue_resp_valid),
    .m_axis_dequeue_resp_ready(tx_desc_dequeue_resp_ready),

    /*
     * Dequeue commit input
     */
    .s_axis_dequeue_commit_op_tag(tx_desc_dequeue_commit_op_tag),
    .s_axis_dequeue_commit_valid(tx_desc_dequeue_commit_valid),
    .s_axis_dequeue_commit_ready(tx_desc_dequeue_commit_ready),

    /*
     * Doorbell output
     */
    .m_axis_doorbell_queue(tx_doorbell_queue),
    .m_axis_doorbell_valid(tx_doorbell_valid),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_tx_queue_manager_awaddr),
    .s_axil_awprot(axil_tx_queue_manager_awprot),
    .s_axil_awvalid(axil_tx_queue_manager_awvalid),
    .s_axil_awready(axil_tx_queue_manager_awready),
    .s_axil_wdata(axil_tx_queue_manager_wdata),
    .s_axil_wstrb(axil_tx_queue_manager_wstrb),
    .s_axil_wvalid(axil_tx_queue_manager_wvalid),
    .s_axil_wready(axil_tx_queue_manager_wready),
    .s_axil_bresp(axil_tx_queue_manager_bresp),
    .s_axil_bvalid(axil_tx_queue_manager_bvalid),
    .s_axil_bready(axil_tx_queue_manager_bready),
    .s_axil_araddr(axil_tx_queue_manager_araddr),
    .s_axil_arprot(axil_tx_queue_manager_arprot),
    .s_axil_arvalid(axil_tx_queue_manager_arvalid),
    .s_axil_arready(axil_tx_queue_manager_arready),
    .s_axil_rdata(axil_tx_queue_manager_rdata),
    .s_axil_rresp(axil_tx_queue_manager_rresp),
    .s_axil_rvalid(axil_tx_queue_manager_rvalid),
    .s_axil_rready(axil_tx_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

cpl_queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(CPL_QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .PIPELINE(TX_CPL_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_TX_CQM_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
tx_cpl_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Enqueue request input
     */
    .s_axis_enqueue_req_queue(tx_cpl_enqueue_req_queue),
    .s_axis_enqueue_req_tag(tx_cpl_enqueue_req_tag),
    .s_axis_enqueue_req_valid(tx_cpl_enqueue_req_valid),
    .s_axis_enqueue_req_ready(tx_cpl_enqueue_req_ready),

    /*
     * Enqueue response output
     */
    .m_axis_enqueue_resp_queue(),
    .m_axis_enqueue_resp_ptr(),
    .m_axis_enqueue_resp_addr(tx_cpl_enqueue_resp_addr),
    .m_axis_enqueue_resp_event(),
    .m_axis_enqueue_resp_tag(tx_cpl_enqueue_resp_tag),
    .m_axis_enqueue_resp_op_tag(tx_cpl_enqueue_resp_op_tag),
    .m_axis_enqueue_resp_full(tx_cpl_enqueue_resp_full),
    .m_axis_enqueue_resp_error(tx_cpl_enqueue_resp_error),
    .m_axis_enqueue_resp_valid(tx_cpl_enqueue_resp_valid),
    .m_axis_enqueue_resp_ready(tx_cpl_enqueue_resp_ready),

    /*
     * Enqueue commit input
     */
    .s_axis_enqueue_commit_op_tag(tx_cpl_enqueue_commit_op_tag),
    .s_axis_enqueue_commit_valid(tx_cpl_enqueue_commit_valid),
    .s_axis_enqueue_commit_ready(tx_cpl_enqueue_commit_ready),

    /*
     * Event output
     */
    .m_axis_event(tx_event),
    .m_axis_event_source(tx_event_source),
    .m_axis_event_valid(tx_event_valid),
    .m_axis_event_ready(tx_event_ready),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_tx_cpl_queue_manager_awaddr),
    .s_axil_awprot(axil_tx_cpl_queue_manager_awprot),
    .s_axil_awvalid(axil_tx_cpl_queue_manager_awvalid),
    .s_axil_awready(axil_tx_cpl_queue_manager_awready),
    .s_axil_wdata(axil_tx_cpl_queue_manager_wdata),
    .s_axil_wstrb(axil_tx_cpl_queue_manager_wstrb),
    .s_axil_wvalid(axil_tx_cpl_queue_manager_wvalid),
    .s_axil_wready(axil_tx_cpl_queue_manager_wready),
    .s_axil_bresp(axil_tx_cpl_queue_manager_bresp),
    .s_axil_bvalid(axil_tx_cpl_queue_manager_bvalid),
    .s_axil_bready(axil_tx_cpl_queue_manager_bready),
    .s_axil_araddr(axil_tx_cpl_queue_manager_araddr),
    .s_axil_arprot(axil_tx_cpl_queue_manager_arprot),
    .s_axil_arvalid(axil_tx_cpl_queue_manager_arvalid),
    .s_axil_arready(axil_tx_cpl_queue_manager_arready),
    .s_axil_rdata(axil_tx_cpl_queue_manager_rdata),
    .s_axil_rresp(axil_tx_cpl_queue_manager_rresp),
    .s_axil_rvalid(axil_tx_cpl_queue_manager_rvalid),
    .s_axil_rready(axil_tx_cpl_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .CPL_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),
    .PIPELINE(RX_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_RX_QM_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
rx_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Dequeue request input
     */
    .s_axis_dequeue_req_queue(rx_desc_dequeue_req_queue),
    .s_axis_dequeue_req_tag(rx_desc_dequeue_req_tag),
    .s_axis_dequeue_req_valid(rx_desc_dequeue_req_valid),
    .s_axis_dequeue_req_ready(rx_desc_dequeue_req_ready),

    /*
     * Dequeue response output
     */
    .m_axis_dequeue_resp_queue(rx_desc_dequeue_resp_queue),
    .m_axis_dequeue_resp_ptr(rx_desc_dequeue_resp_ptr),
    .m_axis_dequeue_resp_addr(rx_desc_dequeue_resp_addr),
    .m_axis_dequeue_resp_block_size(rx_desc_dequeue_resp_block_size),
    .m_axis_dequeue_resp_cpl(rx_desc_dequeue_resp_cpl),
    .m_axis_dequeue_resp_tag(rx_desc_dequeue_resp_tag),
    .m_axis_dequeue_resp_op_tag(rx_desc_dequeue_resp_op_tag),
    .m_axis_dequeue_resp_empty(rx_desc_dequeue_resp_empty),
    .m_axis_dequeue_resp_error(rx_desc_dequeue_resp_error),
    .m_axis_dequeue_resp_valid(rx_desc_dequeue_resp_valid),
    .m_axis_dequeue_resp_ready(rx_desc_dequeue_resp_ready),

    /*
     * Dequeue commit input
     */
    .s_axis_dequeue_commit_op_tag(rx_desc_dequeue_commit_op_tag),
    .s_axis_dequeue_commit_valid(rx_desc_dequeue_commit_valid),
    .s_axis_dequeue_commit_ready(rx_desc_dequeue_commit_ready),

    /*
     * Doorbell output
     */
    .m_axis_doorbell_queue(),
    .m_axis_doorbell_valid(),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_rx_queue_manager_awaddr),
    .s_axil_awprot(axil_rx_queue_manager_awprot),
    .s_axil_awvalid(axil_rx_queue_manager_awvalid),
    .s_axil_awready(axil_rx_queue_manager_awready),
    .s_axil_wdata(axil_rx_queue_manager_wdata),
    .s_axil_wstrb(axil_rx_queue_manager_wstrb),
    .s_axil_wvalid(axil_rx_queue_manager_wvalid),
    .s_axil_wready(axil_rx_queue_manager_wready),
    .s_axil_bresp(axil_rx_queue_manager_bresp),
    .s_axil_bvalid(axil_rx_queue_manager_bvalid),
    .s_axil_bready(axil_rx_queue_manager_bready),
    .s_axil_araddr(axil_rx_queue_manager_araddr),
    .s_axil_arprot(axil_rx_queue_manager_arprot),
    .s_axil_arvalid(axil_rx_queue_manager_arvalid),
    .s_axil_arready(axil_rx_queue_manager_arready),
    .s_axil_rdata(axil_rx_queue_manager_rdata),
    .s_axil_rresp(axil_rx_queue_manager_rresp),
    .s_axil_rvalid(axil_rx_queue_manager_rvalid),
    .s_axil_rready(axil_rx_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

cpl_queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(CPL_QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .PIPELINE(RX_CPL_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_RX_CQM_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
rx_cpl_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Enqueue request input
     */
    .s_axis_enqueue_req_queue(rx_cpl_enqueue_req_queue),
    .s_axis_enqueue_req_tag(rx_cpl_enqueue_req_tag),
    .s_axis_enqueue_req_valid(rx_cpl_enqueue_req_valid),
    .s_axis_enqueue_req_ready(rx_cpl_enqueue_req_ready),

    /*
     * Enqueue response output
     */
    .m_axis_enqueue_resp_queue(),
    .m_axis_enqueue_resp_ptr(),
    .m_axis_enqueue_resp_addr(rx_cpl_enqueue_resp_addr),
    .m_axis_enqueue_resp_event(),
    .m_axis_enqueue_resp_tag(rx_cpl_enqueue_resp_tag),
    .m_axis_enqueue_resp_op_tag(rx_cpl_enqueue_resp_op_tag),
    .m_axis_enqueue_resp_full(rx_cpl_enqueue_resp_full),
    .m_axis_enqueue_resp_error(rx_cpl_enqueue_resp_error),
    .m_axis_enqueue_resp_valid(rx_cpl_enqueue_resp_valid),
    .m_axis_enqueue_resp_ready(rx_cpl_enqueue_resp_ready),

    /*
     * Enqueue commit input
     */
    .s_axis_enqueue_commit_op_tag(rx_cpl_enqueue_commit_op_tag),
    .s_axis_enqueue_commit_valid(rx_cpl_enqueue_commit_valid),
    .s_axis_enqueue_commit_ready(rx_cpl_enqueue_commit_ready),

    /*
     * Event output
     */
    .m_axis_event(rx_event),
    .m_axis_event_source(rx_event_source),
    .m_axis_event_valid(rx_event_valid),
    .m_axis_event_ready(rx_event_ready),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_rx_cpl_queue_manager_awaddr),
    .s_axil_awprot(axil_rx_cpl_queue_manager_awprot),
    .s_axil_awvalid(axil_rx_cpl_queue_manager_awvalid),
    .s_axil_awready(axil_rx_cpl_queue_manager_awready),
    .s_axil_wdata(axil_rx_cpl_queue_manager_wdata),
    .s_axil_wstrb(axil_rx_cpl_queue_manager_wstrb),
    .s_axil_wvalid(axil_rx_cpl_queue_manager_wvalid),
    .s_axil_wready(axil_rx_cpl_queue_manager_wready),
    .s_axil_bresp(axil_rx_cpl_queue_manager_bresp),
    .s_axil_bvalid(axil_rx_cpl_queue_manager_bvalid),
    .s_axil_bready(axil_rx_cpl_queue_manager_bready),
    .s_axil_araddr(axil_rx_cpl_queue_manager_araddr),
    .s_axil_arprot(axil_rx_cpl_queue_manager_arprot),
    .s_axil_arvalid(axil_rx_cpl_queue_manager_arvalid),
    .s_axil_arready(axil_rx_cpl_queue_manager_arready),
    .s_axil_rdata(axil_rx_cpl_queue_manager_rdata),
    .s_axil_rresp(axil_rx_cpl_queue_manager_rresp),
    .s_axil_rvalid(axil_rx_cpl_queue_manager_rvalid),
    .s_axil_rready(axil_rx_cpl_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

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
    .m_axis_req_sel(desc_req_sel),
    .m_axis_req_queue(desc_req_queue),
    .m_axis_req_tag(desc_req_tag),
    .m_axis_req_valid(desc_req_valid),
    .m_axis_req_ready(desc_req_ready),

    /*
     * Descriptor request status input
     */
    .s_axis_req_status_queue(desc_req_status_queue),
    .s_axis_req_status_ptr(desc_req_status_ptr),
    .s_axis_req_status_cpl(desc_req_status_cpl),
    .s_axis_req_status_tag(desc_req_status_tag),
    .s_axis_req_status_empty(desc_req_status_empty),
    .s_axis_req_status_error(desc_req_status_error),
    .s_axis_req_status_valid(desc_req_status_valid),

    /*
     * Descriptor data input
     */
    .s_axis_desc_tdata(axis_desc_tdata),
    .s_axis_desc_tkeep(axis_desc_tkeep),
    .s_axis_desc_tvalid(axis_desc_tvalid),
    .s_axis_desc_tready(axis_desc_tready),
    .s_axis_desc_tlast(axis_desc_tlast),
    .s_axis_desc_tid(axis_desc_tid),
    .s_axis_desc_tuser(axis_desc_tuser),

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

desc_fetch #(
    .PORTS(2),
    .SELECT_WIDTH(1),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),
    .AXIS_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),
    .DESC_TABLE_SIZE(32)
)
desc_fetch_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor read request input
     */
    .s_axis_req_sel(desc_req_sel),
    .s_axis_req_queue(desc_req_queue),
    .s_axis_req_tag(desc_req_tag),
    .s_axis_req_valid(desc_req_valid),
    .s_axis_req_ready(desc_req_ready),

    /*
     * Descriptor read request status output
     */
    .m_axis_req_status_queue(desc_req_status_queue),
    .m_axis_req_status_ptr(desc_req_status_ptr),
    .m_axis_req_status_cpl(desc_req_status_cpl),
    .m_axis_req_status_tag(desc_req_status_tag),
    .m_axis_req_status_empty(desc_req_status_empty),
    .m_axis_req_status_error(desc_req_status_error),
    .m_axis_req_status_valid(desc_req_status_valid),

    /*
     * Descriptor data output
     */
    .m_axis_desc_tdata(axis_desc_tdata),
    .m_axis_desc_tkeep(axis_desc_tkeep),
    .m_axis_desc_tvalid(axis_desc_tvalid),
    .m_axis_desc_tready(axis_desc_tready),
    .m_axis_desc_tlast(axis_desc_tlast),
    .m_axis_desc_tid(axis_desc_tid),
    .m_axis_desc_tuser(axis_desc_tuser),

    /*
     * Descriptor dequeue request output
     */
    .m_axis_desc_dequeue_req_queue({rx_desc_dequeue_req_queue, tx_desc_dequeue_req_queue}),
    .m_axis_desc_dequeue_req_tag({rx_desc_dequeue_req_tag, tx_desc_dequeue_req_tag}),
    .m_axis_desc_dequeue_req_valid({rx_desc_dequeue_req_valid, tx_desc_dequeue_req_valid}),
    .m_axis_desc_dequeue_req_ready({rx_desc_dequeue_req_ready, tx_desc_dequeue_req_ready}),

    /*
     * Descriptor dequeue response input
     */
    .s_axis_desc_dequeue_resp_queue({rx_desc_dequeue_resp_queue, tx_desc_dequeue_resp_queue}),
    .s_axis_desc_dequeue_resp_ptr({rx_desc_dequeue_resp_ptr, tx_desc_dequeue_resp_ptr}),
    .s_axis_desc_dequeue_resp_addr({rx_desc_dequeue_resp_addr, tx_desc_dequeue_resp_addr}),
    .s_axis_desc_dequeue_resp_block_size({rx_desc_dequeue_resp_block_size, tx_desc_dequeue_resp_block_size}),
    .s_axis_desc_dequeue_resp_cpl({rx_desc_dequeue_resp_cpl, tx_desc_dequeue_resp_cpl}),
    .s_axis_desc_dequeue_resp_tag({rx_desc_dequeue_resp_tag, tx_desc_dequeue_resp_tag}),
    .s_axis_desc_dequeue_resp_op_tag({rx_desc_dequeue_resp_op_tag, tx_desc_dequeue_resp_op_tag}),
    .s_axis_desc_dequeue_resp_empty({rx_desc_dequeue_resp_empty, tx_desc_dequeue_resp_empty}),
    .s_axis_desc_dequeue_resp_error({rx_desc_dequeue_resp_error, tx_desc_dequeue_resp_error}),
    .s_axis_desc_dequeue_resp_valid({rx_desc_dequeue_resp_valid, tx_desc_dequeue_resp_valid}),
    .s_axis_desc_dequeue_resp_ready({rx_desc_dequeue_resp_ready, tx_desc_dequeue_resp_ready}),

    /*
     * Descriptor dequeue commit output
     */
    .m_axis_desc_dequeue_commit_op_tag({rx_desc_dequeue_commit_op_tag, tx_desc_dequeue_commit_op_tag}),
    .m_axis_desc_dequeue_commit_valid({rx_desc_dequeue_commit_valid, tx_desc_dequeue_commit_valid}),
    .m_axis_desc_dequeue_commit_ready({rx_desc_dequeue_commit_ready, tx_desc_dequeue_commit_ready}),

    /*
     * DMA read descriptor output
     */
    .m_axis_dma_read_desc_dma_addr(m_axis_ctrl_dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_addr(m_axis_ctrl_dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(m_axis_ctrl_dma_read_desc_len),
    .m_axis_dma_read_desc_tag(m_axis_ctrl_dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(m_axis_ctrl_dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(m_axis_ctrl_dma_read_desc_ready),

    /*
     * DMA read descriptor status input
     */
    .s_axis_dma_read_desc_status_tag(s_axis_ctrl_dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(s_axis_ctrl_dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(s_axis_ctrl_dma_read_desc_status_valid),

    /*
     * RAM interface
     */
    .dma_ram_wr_cmd_be(ctrl_dma_ram_wr_cmd_be),
    .dma_ram_wr_cmd_addr(ctrl_dma_ram_wr_cmd_addr),
    .dma_ram_wr_cmd_data(ctrl_dma_ram_wr_cmd_data),
    .dma_ram_wr_cmd_valid(ctrl_dma_ram_wr_cmd_valid),
    .dma_ram_wr_cmd_ready(ctrl_dma_ram_wr_cmd_ready),
    .dma_ram_wr_done(ctrl_dma_ram_wr_done),

    /*
     * Configuration
     */
    .enable(1'b1)
);

assign m_axis_ctrl_dma_read_desc_ram_sel = 0;

cpl_op_mux #(
    .PORTS(3),
    .SELECT_WIDTH(2),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .S_REQ_TAG_WIDTH(CPL_REQ_TAG_WIDTH_INT),
    .M_REQ_TAG_WIDTH(CPL_REQ_TAG_WIDTH),
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
    .m_axis_req_sel(cpl_req_sel),
    .m_axis_req_queue(cpl_req_queue),
    .m_axis_req_tag(cpl_req_tag),
    .m_axis_req_data(cpl_req_data),
    .m_axis_req_valid(cpl_req_valid),
    .m_axis_req_ready(cpl_req_ready),

    /*
     * Completion request status input
     */
    .s_axis_req_status_tag(cpl_req_status_tag),
    .s_axis_req_status_full(cpl_req_status_full),
    .s_axis_req_status_error(cpl_req_status_error),
    .s_axis_req_status_valid(cpl_req_status_valid),

    /*
     * Completion request input
     */
    .s_axis_req_sel({event_cpl_req_sel, rx_cpl_req_sel, tx_cpl_req_sel}),
    .s_axis_req_queue({event_cpl_req_queue, rx_cpl_req_queue, tx_cpl_req_queue}),
    .s_axis_req_tag({event_cpl_req_tag, rx_cpl_req_tag, tx_cpl_req_tag}),
    .s_axis_req_data({event_cpl_req_data, rx_cpl_req_data, tx_cpl_req_data}),
    .s_axis_req_valid({event_cpl_req_valid, rx_cpl_req_valid, tx_cpl_req_valid}),
    .s_axis_req_ready({event_cpl_req_ready, rx_cpl_req_ready, tx_cpl_req_ready}),

    /*
     * Completion response output
     */
    .m_axis_req_status_tag({event_cpl_req_status_tag, rx_cpl_req_status_tag, tx_cpl_req_status_tag}),
    .m_axis_req_status_full({event_cpl_req_status_full, rx_cpl_req_status_full, tx_cpl_req_status_full}),
    .m_axis_req_status_error({event_cpl_req_status_error, rx_cpl_req_status_error, tx_cpl_req_status_error}),
    .m_axis_req_status_valid({event_cpl_req_status_valid, rx_cpl_req_status_valid, tx_cpl_req_status_valid})
);

cpl_write #(
    .PORTS(3),
    .SELECT_WIDTH(2),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .REQ_TAG_WIDTH(CPL_REQ_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(CPL_QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .DESC_TABLE_SIZE(32)
)
cpl_write_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Completion read request input
     */
    .s_axis_req_sel(cpl_req_sel),
    .s_axis_req_queue(cpl_req_queue),
    .s_axis_req_tag(cpl_req_tag),
    .s_axis_req_data(cpl_req_data),
    .s_axis_req_valid(cpl_req_valid),
    .s_axis_req_ready(cpl_req_ready),

    /*
     * Completion read request status output
     */
    .m_axis_req_status_tag(cpl_req_status_tag),
    .m_axis_req_status_full(cpl_req_status_full),
    .m_axis_req_status_error(cpl_req_status_error),
    .m_axis_req_status_valid(cpl_req_status_valid),

    /*
     * Completion enqueue request output
     */
    .m_axis_cpl_enqueue_req_queue({event_enqueue_req_queue, rx_cpl_enqueue_req_queue, tx_cpl_enqueue_req_queue}),
    .m_axis_cpl_enqueue_req_tag({event_enqueue_req_tag, rx_cpl_enqueue_req_tag, tx_cpl_enqueue_req_tag}),
    .m_axis_cpl_enqueue_req_valid({event_enqueue_req_valid, rx_cpl_enqueue_req_valid, tx_cpl_enqueue_req_valid}),
    .m_axis_cpl_enqueue_req_ready({event_enqueue_req_ready, rx_cpl_enqueue_req_ready, tx_cpl_enqueue_req_ready}),

    /*
     * Completion enqueue response input
     */
    .s_axis_cpl_enqueue_resp_addr({event_enqueue_resp_addr, rx_cpl_enqueue_resp_addr, tx_cpl_enqueue_resp_addr}),
    .s_axis_cpl_enqueue_resp_tag({event_enqueue_resp_tag, rx_cpl_enqueue_resp_tag, tx_cpl_enqueue_resp_tag}),
    .s_axis_cpl_enqueue_resp_op_tag({event_enqueue_resp_op_tag, rx_cpl_enqueue_resp_op_tag, tx_cpl_enqueue_resp_op_tag}),
    .s_axis_cpl_enqueue_resp_full({event_enqueue_resp_full, rx_cpl_enqueue_resp_full, tx_cpl_enqueue_resp_full}),
    .s_axis_cpl_enqueue_resp_error({event_enqueue_resp_error, rx_cpl_enqueue_resp_error, tx_cpl_enqueue_resp_error}),
    .s_axis_cpl_enqueue_resp_valid({event_enqueue_resp_valid, rx_cpl_enqueue_resp_valid, tx_cpl_enqueue_resp_valid}),
    .s_axis_cpl_enqueue_resp_ready({event_enqueue_resp_ready, rx_cpl_enqueue_resp_ready, tx_cpl_enqueue_resp_ready}),

    /*
     * Completion enqueue commit output
     */
    .m_axis_cpl_enqueue_commit_op_tag({event_enqueue_commit_op_tag, rx_cpl_enqueue_commit_op_tag, tx_cpl_enqueue_commit_op_tag}),
    .m_axis_cpl_enqueue_commit_valid({event_enqueue_commit_valid, rx_cpl_enqueue_commit_valid, tx_cpl_enqueue_commit_valid}),
    .m_axis_cpl_enqueue_commit_ready({event_enqueue_commit_ready, rx_cpl_enqueue_commit_ready, tx_cpl_enqueue_commit_ready}),

    /*
     * DMA write descriptor output
     */
    .m_axis_dma_write_desc_dma_addr(m_axis_ctrl_dma_write_desc_dma_addr),
    .m_axis_dma_write_desc_ram_addr(m_axis_ctrl_dma_write_desc_ram_addr),
    .m_axis_dma_write_desc_len(m_axis_ctrl_dma_write_desc_len),
    .m_axis_dma_write_desc_tag(m_axis_ctrl_dma_write_desc_tag),
    .m_axis_dma_write_desc_valid(m_axis_ctrl_dma_write_desc_valid),
    .m_axis_dma_write_desc_ready(m_axis_ctrl_dma_write_desc_ready),

    /*
     * DMA write descriptor status input
     */
    .s_axis_dma_write_desc_status_tag(s_axis_ctrl_dma_write_desc_status_tag),
    .s_axis_dma_write_desc_status_error(s_axis_ctrl_dma_write_desc_status_error),
    .s_axis_dma_write_desc_status_valid(s_axis_ctrl_dma_write_desc_status_valid),

    /*
     * RAM interface
     */
    .dma_ram_rd_cmd_addr(ctrl_dma_ram_rd_cmd_addr),
    .dma_ram_rd_cmd_valid(ctrl_dma_ram_rd_cmd_valid),
    .dma_ram_rd_cmd_ready(ctrl_dma_ram_rd_cmd_ready),
    .dma_ram_rd_resp_data(ctrl_dma_ram_rd_resp_data),
    .dma_ram_rd_resp_valid(ctrl_dma_ram_rd_resp_valid),
    .dma_ram_rd_resp_ready(ctrl_dma_ram_rd_resp_ready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

assign m_axis_ctrl_dma_write_desc_ram_sel = 0;
assign m_axis_ctrl_dma_write_desc_imm = 0;
assign m_axis_ctrl_dma_write_desc_imm_en = 0;

event_mux #(
    .PORTS(2),
    .QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .EVENT_TYPE_WIDTH(EVENT_TYPE_WIDTH),
    .EVENT_SOURCE_WIDTH(EVENT_SOURCE_WIDTH),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
event_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Event output
     */
    .m_axis_event_queue(axis_event_queue),
    .m_axis_event_type(axis_event_type),
    .m_axis_event_source(axis_event_source),
    .m_axis_event_valid(axis_event_valid),
    .m_axis_event_ready(axis_event_ready),

    /*
     * Event input
     */
    .s_axis_event_queue({rx_fifo_event, tx_fifo_event}),
    .s_axis_event_type({rx_fifo_event_type, tx_fifo_event_type}),
    .s_axis_event_source({rx_fifo_event_source, tx_fifo_event_source}),
    .s_axis_event_valid({rx_fifo_event_valid, tx_fifo_event_valid}),
    .s_axis_event_ready({rx_fifo_event_ready, tx_fifo_event_ready})
);

assign event_cpl_req_queue = axis_event_queue;
assign event_cpl_req_tag = 0;
assign event_cpl_req_data[15:0] = axis_event_type;
assign event_cpl_req_data[31:16] = axis_event_source;
assign event_cpl_req_data[255:32] = 0;
assign event_cpl_req_valid = axis_event_valid;
assign axis_event_ready = event_cpl_req_ready;

axis_fifo #(
    .DEPTH(32),
    .DATA_WIDTH(EVENT_SOURCE_WIDTH+EVENT_TYPE_WIDTH+EVENT_QUEUE_INDEX_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
tx_event_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata({tx_event_source, tx_event_type, tx_event}),
    .s_axis_tkeep(0),
    .s_axis_tvalid(tx_event_valid),
    .s_axis_tready(tx_event_ready),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_axis_tdata({tx_fifo_event_source, tx_fifo_event_type, tx_fifo_event}),
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_fifo_event_valid),
    .m_axis_tready(tx_fifo_event_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

axis_fifo #(
    .DEPTH(32),
    .DATA_WIDTH(EVENT_SOURCE_WIDTH+EVENT_TYPE_WIDTH+EVENT_QUEUE_INDEX_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
rx_event_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata({rx_event_source, rx_event_type, rx_event}),
    .s_axis_tkeep(0),
    .s_axis_tvalid(rx_event_valid),
    .s_axis_tready(rx_event_ready),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_axis_tdata({rx_fifo_event_source, rx_fifo_event_type, rx_fifo_event}),
    .m_axis_tkeep(),
    .m_axis_tvalid(rx_fifo_event_valid),
    .m_axis_tready(rx_fifo_event_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

// TX

wire [SCHEDULERS*TX_QUEUE_INDEX_WIDTH-1:0]  tx_sched_req_queue;
wire [SCHEDULERS*REQ_TAG_WIDTH_INT-1:0]     tx_sched_req_tag;
wire [SCHEDULERS*AXIS_IF_TX_DEST_WIDTH-1:0] tx_sched_req_dest;
wire [SCHEDULERS-1:0]                       tx_sched_req_valid;
wire [SCHEDULERS-1:0]                       tx_sched_req_ready;

wire [SCHEDULERS*DMA_CLIENT_LEN_WIDTH-1:0]  tx_sched_req_status_len;
wire [SCHEDULERS*REQ_TAG_WIDTH_INT-1:0]     tx_sched_req_status_tag;
wire [SCHEDULERS-1:0]                       tx_sched_req_status_valid;

wire [TX_QUEUE_INDEX_WIDTH-1:0]  tx_req_queue;
wire [REQ_TAG_WIDTH-1:0]         tx_req_tag;
wire [AXIS_IF_TX_DEST_WIDTH-1:0] tx_req_dest;
wire                             tx_req_valid;
wire                             tx_req_ready;

wire [DMA_CLIENT_LEN_WIDTH-1:0]  tx_req_status_len;
wire [REQ_TAG_WIDTH-1:0]         tx_req_status_tag;
wire                             tx_req_status_valid;

generate

genvar n;

for (n = 0; n < SCHEDULERS; n = n + 1) begin : sched

    mqnic_tx_scheduler_block #(
        .PORTS(PORTS),
        .INDEX(n),
        .REG_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
        .REG_DATA_WIDTH(AXIL_DATA_WIDTH),
        .REG_STRB_WIDTH(AXIL_STRB_WIDTH),
        .RB_BASE_ADDR(SCHED_RB_BASE_ADDR + SCHED_RB_STRIDE*n),
        .RB_NEXT_PTR(n < SCHEDULERS-1 ? SCHED_RB_BASE_ADDR + SCHED_RB_STRIDE*(n+1) : 0),
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_SCHED_ADDR_WIDTH),
        .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
        .AXIL_OFFSET(AXIL_SCHED_BASE_ADDR + (2**AXIL_SCHED_ADDR_WIDTH)*n),
        .LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
        .REQ_TAG_WIDTH(REQ_TAG_WIDTH_INT),
        .OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
        .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
        .PIPELINE(TX_SCHEDULER_PIPELINE),
        .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),
        .PTP_TS_WIDTH(PTP_TS_WIDTH),
        .AXIS_TX_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
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
        .ctrl_reg_wr_wait(sched_ctrl_reg_wr_wait[n]),
        .ctrl_reg_wr_ack(sched_ctrl_reg_wr_ack[n]),
        .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
        .ctrl_reg_rd_en(ctrl_reg_rd_en),
        .ctrl_reg_rd_data(sched_ctrl_reg_rd_data[n]),
        .ctrl_reg_rd_wait(sched_ctrl_reg_rd_wait[n]),
        .ctrl_reg_rd_ack(sched_ctrl_reg_rd_ack[n]),

        /*
         * AXI-Lite slave interface
         */
        .s_axil_awaddr(axil_sched_awaddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
        .s_axil_awprot(axil_sched_awprot[n*3 +: 3]),
        .s_axil_awvalid(axil_sched_awvalid[n +: 1]),
        .s_axil_awready(axil_sched_awready[n +: 1]),
        .s_axil_wdata(axil_sched_wdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
        .s_axil_wstrb(axil_sched_wstrb[n*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
        .s_axil_wvalid(axil_sched_wvalid[n +: 1]),
        .s_axil_wready(axil_sched_wready[n +: 1]),
        .s_axil_bresp(axil_sched_bresp[n*2 +: 2]),
        .s_axil_bvalid(axil_sched_bvalid[n +: 1]),
        .s_axil_bready(axil_sched_bready[n +: 1]),
        .s_axil_araddr(axil_sched_araddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
        .s_axil_arprot(axil_sched_arprot[n*3 +: 3]),
        .s_axil_arvalid(axil_sched_arvalid[n +: 1]),
        .s_axil_arready(axil_sched_arready[n +: 1]),
        .s_axil_rdata(axil_sched_rdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
        .s_axil_rresp(axil_sched_rresp[n*2 +: 2]),
        .s_axil_rvalid(axil_sched_rvalid[n +: 1]),
        .s_axil_rready(axil_sched_rready[n +: 1]),

        /*
         * Transmit request output (queue index)
         */
        .m_axis_tx_req_queue(tx_sched_req_queue[n*TX_QUEUE_INDEX_WIDTH +: TX_QUEUE_INDEX_WIDTH]),
        .m_axis_tx_req_tag(tx_sched_req_tag[n*REQ_TAG_WIDTH_INT +: REQ_TAG_WIDTH_INT]),
        .m_axis_tx_req_dest(tx_sched_req_dest[n*AXIS_IF_TX_DEST_WIDTH +: AXIS_IF_TX_DEST_WIDTH]),
        .m_axis_tx_req_valid(tx_sched_req_valid[n +: 1]),
        .m_axis_tx_req_ready(tx_sched_req_ready[n +: 1]),

        /*
         * Transmit request status input
         */
        .s_axis_tx_req_status_len(tx_sched_req_status_len[n*DMA_CLIENT_LEN_WIDTH +: DMA_CLIENT_LEN_WIDTH]),
        .s_axis_tx_req_status_tag(tx_sched_req_status_tag[n*REQ_TAG_WIDTH_INT +: REQ_TAG_WIDTH_INT]),
        .s_axis_tx_req_status_valid(tx_sched_req_status_valid[n +: 1]),

        /*
         * Doorbell input
         */
        .s_axis_doorbell_queue(tx_doorbell_queue),
        .s_axis_doorbell_valid(tx_doorbell_valid),

        /*
         * PTP clock
         */
        .ptp_ts_96(ptp_ts_96),
        .ptp_ts_step(ptp_ts_step),

        /*
         * Configuration
         */
        .mtu(tx_mtu_reg)
    );

end

if (SCHEDULERS > 1) begin

    tx_req_mux #(
        .PORTS(SCHEDULERS),
        .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
        .S_REQ_TAG_WIDTH(REQ_TAG_WIDTH_INT),
        .M_REQ_TAG_WIDTH(REQ_TAG_WIDTH),
        .DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
        .LEN_WIDTH(DMA_CLIENT_LEN_WIDTH),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(0)
    )
    tx_req_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Transmit request output (to transmit engine)
         */
        .m_axis_req_queue(tx_req_queue),
        .m_axis_req_tag(tx_req_tag),
        .m_axis_req_dest(tx_req_dest),
        .m_axis_req_valid(tx_req_valid),
        .m_axis_req_ready(tx_req_ready),

        /*
         * Transmit request status input (from transmit engine)
         */
        .s_axis_req_status_len(tx_req_status_len),
        .s_axis_req_status_tag(tx_req_status_tag),
        // .s_axis_req_status_empty(tx_req_status_empty),
        // .s_axis_req_status_error(tx_req_status_error),
        .s_axis_req_status_valid(tx_req_status_valid),

        /*
         * Transmit request input
         */
        .s_axis_req_queue(tx_sched_req_queue),
        .s_axis_req_tag(tx_sched_req_tag),
        .s_axis_req_dest(tx_sched_req_dest),
        .s_axis_req_valid(tx_sched_req_valid),
        .s_axis_req_ready(tx_sched_req_ready),

        /*
         * Transmit request status output
         */
        .m_axis_req_status_len(tx_sched_req_status_len),
        .m_axis_req_status_tag(tx_sched_req_status_tag),
        // .m_axis_req_status_empty(tx_sched_req_status_empty),
        // .m_axis_req_status_error(tx_sched_req_status_error),
        .m_axis_req_status_valid(tx_sched_req_status_valid)
    );

end else begin

    assign tx_req_queue = tx_sched_req_queue;
    assign tx_req_tag = tx_sched_req_tag;
    assign tx_req_dest = tx_sched_req_dest;
    assign tx_req_valid = tx_sched_req_valid;
    assign tx_sched_req_ready = tx_req_ready;

    assign tx_sched_req_status_len = tx_req_status_len;
    assign tx_sched_req_status_tag = tx_req_status_tag;
    assign tx_sched_req_status_valid = tx_req_status_valid;

end

endgenerate

wire [AXIS_IF_DATA_WIDTH-1:0] if_tx_axis_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0] if_tx_axis_tkeep;
wire if_tx_axis_tvalid;
wire if_tx_axis_tready;
wire if_tx_axis_tlast;
wire [AXIS_IF_TX_ID_WIDTH-1:0] if_tx_axis_tid;
wire [AXIS_IF_TX_DEST_WIDTH-1:0] if_tx_axis_tdest;
wire [AXIS_IF_TX_USER_WIDTH-1:0] if_tx_axis_tuser;

wire [PTP_TS_WIDTH-1:0] if_tx_cpl_ts;
wire [TX_TAG_WIDTH-1:0] if_tx_cpl_tag;
wire if_tx_cpl_valid;
wire if_tx_cpl_ready;

mqnic_interface_tx #(
    // Structural configuration
    .PORTS(PORTS),

    // PTP configuration
    .PTP_TS_WIDTH(PTP_TS_WIDTH),

    // Queue manager configuration
    .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),

    // Descriptor management
    .TX_MAX_DESC_REQ(TX_MAX_DESC_REQ),
    .TX_DESC_FIFO_SIZE(TX_DESC_FIFO_SIZE),
    .DESC_SIZE(DESC_SIZE),
    .CPL_SIZE(CPL_SIZE),
    .AXIS_DESC_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_DESC_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .DESC_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH_INT),
    .CPL_REQ_TAG_WIDTH(CPL_REQ_TAG_WIDTH_INT),

    // TX and RX engine configuration
    .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .DESC_TABLE_DMA_OP_COUNT_WIDTH(((2**LOG_BLOCK_SIZE_WIDTH)-1)+1),

    // Interface configuration
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .TX_TAG_WIDTH(TX_TAG_WIDTH),
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),

    // DMA interface configuration
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // Streaming interface configuration
    .AXIS_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .AXIS_TX_ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
    .AXIS_TX_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
    .AXIS_TX_USER_WIDTH(AXIS_IF_TX_USER_WIDTH)
)
interface_tx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Transmit request input (queue index)
     */
    .s_axis_tx_req_queue(tx_req_queue),
    .s_axis_tx_req_tag(tx_req_tag),
    .s_axis_tx_req_dest(tx_req_dest),
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
    .s_axis_desc_tdata(tx_desc_tdata),
    .s_axis_desc_tkeep(tx_desc_tkeep),
    .s_axis_desc_tvalid(tx_desc_tvalid),
    .s_axis_desc_tready(tx_desc_tready),
    .s_axis_desc_tlast(tx_desc_tlast),
    .s_axis_desc_tid(tx_desc_tid),
    .s_axis_desc_tuser(tx_desc_tuser),

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
     * DMA read descriptor output (data)
     */
    .m_axis_dma_read_desc_dma_addr(m_axis_data_dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_addr(m_axis_data_dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(m_axis_data_dma_read_desc_len),
    .m_axis_dma_read_desc_tag(m_axis_data_dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(m_axis_data_dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(m_axis_data_dma_read_desc_ready),

    /*
     * DMA read descriptor status input (data)
     */
    .s_axis_dma_read_desc_status_tag(s_axis_data_dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(s_axis_data_dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(s_axis_data_dma_read_desc_status_valid),

    /*
     * RAM interface (data)
     */
    .dma_ram_wr_cmd_be(data_dma_ram_wr_cmd_be),
    .dma_ram_wr_cmd_addr(data_dma_ram_wr_cmd_addr),
    .dma_ram_wr_cmd_data(data_dma_ram_wr_cmd_data),
    .dma_ram_wr_cmd_valid(data_dma_ram_wr_cmd_valid),
    .dma_ram_wr_cmd_ready(data_dma_ram_wr_cmd_ready),
    .dma_ram_wr_done(data_dma_ram_wr_done),

    /*
     * Transmit data output
     */
    .m_axis_tx_tdata(if_tx_axis_tdata),
    .m_axis_tx_tkeep(if_tx_axis_tkeep),
    .m_axis_tx_tvalid(if_tx_axis_tvalid),
    .m_axis_tx_tready(if_tx_axis_tready),
    .m_axis_tx_tlast(if_tx_axis_tlast),
    .m_axis_tx_tid(if_tx_axis_tid),
    .m_axis_tx_tdest(if_tx_axis_tdest),
    .m_axis_tx_tuser(if_tx_axis_tuser),

    /*
     * Transmit completion input
     */
    .s_axis_tx_cpl_ts(if_tx_cpl_ts),
    .s_axis_tx_cpl_tag(if_tx_cpl_tag),
    .s_axis_tx_cpl_valid(if_tx_cpl_valid),
    .s_axis_tx_cpl_ready(if_tx_cpl_ready),

    /*
     * Configuration
     */
    .mtu(tx_mtu_reg)
);

assign m_axis_data_dma_read_desc_ram_sel = 0;

// RX

wire [AXIS_IF_DATA_WIDTH-1:0] if_rx_axis_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0] if_rx_axis_tkeep;
wire if_rx_axis_tvalid;
wire if_rx_axis_tready;
wire if_rx_axis_tlast;
wire [AXIS_IF_RX_ID_WIDTH-1:0] if_rx_axis_tid;
wire [AXIS_IF_RX_DEST_WIDTH-1:0] if_rx_axis_tdest;
wire [AXIS_IF_RX_USER_WIDTH-1:0] if_rx_axis_tuser;

mqnic_interface_rx #(
    // Structural configuration
    .PORTS(PORTS),

    // PTP configuration
    .PTP_TS_WIDTH(PTP_TS_WIDTH),

    // Queue manager configuration
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),

    // Descriptor management
    .RX_MAX_DESC_REQ(RX_MAX_DESC_REQ),
    .RX_DESC_FIFO_SIZE(RX_DESC_FIFO_SIZE),
    .DESC_SIZE(DESC_SIZE),
    .CPL_SIZE(CPL_SIZE),
    .AXIS_DESC_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_DESC_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .DESC_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH_INT),
    .CPL_REQ_TAG_WIDTH(CPL_REQ_TAG_WIDTH_INT),

    // TX and RX engine configuration
    .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
    .DESC_TABLE_DMA_OP_COUNT_WIDTH(((2**LOG_BLOCK_SIZE_WIDTH)-1)+1),

    // Interface configuration
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

    // DMA interface configuration
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // Register interface configuration
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .REG_DATA_WIDTH(REG_DATA_WIDTH),
    .REG_STRB_WIDTH(REG_STRB_WIDTH),
    .RB_BASE_ADDR(RX_RB_BASE_ADDR),
    .RB_NEXT_PTR(PORT_RB_BASE_ADDR),

    // Streaming interface configuration
    .AXIS_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .AXIS_RX_ID_WIDTH(AXIS_IF_RX_ID_WIDTH),
    .AXIS_RX_DEST_WIDTH(AXIS_IF_RX_DEST_WIDTH),
    .AXIS_RX_USER_WIDTH(AXIS_IF_RX_USER_WIDTH)
)
interface_rx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Control register interface
     */
    .ctrl_reg_wr_addr(ctrl_reg_wr_addr),
    .ctrl_reg_wr_data(ctrl_reg_wr_data),
    .ctrl_reg_wr_strb(ctrl_reg_wr_strb),
    .ctrl_reg_wr_en(ctrl_reg_wr_en),
    .ctrl_reg_wr_wait(if_rx_ctrl_reg_wr_wait),
    .ctrl_reg_wr_ack(if_rx_ctrl_reg_wr_ack),
    .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
    .ctrl_reg_rd_en(ctrl_reg_rd_en),
    .ctrl_reg_rd_data(if_rx_ctrl_reg_rd_data),
    .ctrl_reg_rd_wait(if_rx_ctrl_reg_rd_wait),
    .ctrl_reg_rd_ack(if_rx_ctrl_reg_rd_ack),

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
    .s_axis_desc_tdata(rx_desc_tdata),
    .s_axis_desc_tkeep(rx_desc_tkeep),
    .s_axis_desc_tvalid(rx_desc_tvalid),
    .s_axis_desc_tready(rx_desc_tready),
    .s_axis_desc_tlast(rx_desc_tlast),
    .s_axis_desc_tid(rx_desc_tid),
    .s_axis_desc_tuser(rx_desc_tuser),

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
     * DMA write descriptor output (data)
     */
    .m_axis_dma_write_desc_dma_addr(m_axis_data_dma_write_desc_dma_addr),
    .m_axis_dma_write_desc_ram_addr(m_axis_data_dma_write_desc_ram_addr),
    .m_axis_dma_write_desc_len(m_axis_data_dma_write_desc_len),
    .m_axis_dma_write_desc_tag(m_axis_data_dma_write_desc_tag),
    .m_axis_dma_write_desc_valid(m_axis_data_dma_write_desc_valid),
    .m_axis_dma_write_desc_ready(m_axis_data_dma_write_desc_ready),

    /*
     * DMA write descriptor status input (data)
     */
    .s_axis_dma_write_desc_status_tag(s_axis_data_dma_write_desc_status_tag),
    .s_axis_dma_write_desc_status_error(s_axis_data_dma_write_desc_status_error),
    .s_axis_dma_write_desc_status_valid(s_axis_data_dma_write_desc_status_valid),

    /*
     * RAM interface (data)
     */
    .dma_ram_rd_cmd_addr(data_dma_ram_rd_cmd_addr),
    .dma_ram_rd_cmd_valid(data_dma_ram_rd_cmd_valid),
    .dma_ram_rd_cmd_ready(data_dma_ram_rd_cmd_ready),
    .dma_ram_rd_resp_data(data_dma_ram_rd_resp_data),
    .dma_ram_rd_resp_valid(data_dma_ram_rd_resp_valid),
    .dma_ram_rd_resp_ready(data_dma_ram_rd_resp_ready),

    /*
     * Receive data input
     */
    .s_axis_rx_tdata(if_rx_axis_tdata),
    .s_axis_rx_tkeep(if_rx_axis_tkeep),
    .s_axis_rx_tvalid(if_rx_axis_tvalid),
    .s_axis_rx_tready(if_rx_axis_tready),
    .s_axis_rx_tlast(if_rx_axis_tlast),
    .s_axis_rx_tid(if_rx_axis_tid),
    .s_axis_rx_tdest(if_rx_axis_tdest),
    .s_axis_rx_tuser(if_rx_axis_tuser),

    /*
     * Configuration
     */
    .mtu(rx_mtu_reg)
);

assign m_axis_data_dma_write_desc_ram_sel = 0;
assign m_axis_data_dma_write_desc_imm = 0;
assign m_axis_data_dma_write_desc_imm_en = 0;

generate

wire [PORTS*PTP_TS_WIDTH-1:0] axis_if_tx_cpl_ts;
wire [PORTS*TX_TAG_WIDTH-1:0] axis_if_tx_cpl_tag;
wire [PORTS-1:0] axis_if_tx_cpl_valid;
wire [PORTS-1:0] axis_if_tx_cpl_ready;

wire [PTP_TS_WIDTH-1:0] axis_tx_cpl_ts;
wire [TX_TAG_WIDTH-1:0] axis_tx_cpl_tag;
wire axis_tx_cpl_valid;
wire axis_tx_cpl_ready;

if (PORTS > 1) begin

    axis_arb_mux #(
        .S_COUNT(PORTS),
        .DATA_WIDTH(PTP_TS_WIDTH),
        .KEEP_ENABLE(0),
        .ID_ENABLE(1),
        .S_ID_WIDTH(TX_TAG_WIDTH),
        .M_ID_WIDTH(TX_TAG_WIDTH),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .LAST_ENABLE(0),
        .UPDATE_TID(0),
        .ARB_TYPE_ROUND_ROBIN(1'b1),
        .ARB_LSB_HIGH_PRIORITY(1'b1)
    )
    tx_cpl_mux_inst (
        .clk(clk),
        .rst(rst),

        // AXI Stream inputs
        .s_axis_tkeep(0),
        .s_axis_tdata(PTP_TS_ENABLE ? axis_if_tx_cpl_ts : 0),
        .s_axis_tvalid(axis_if_tx_cpl_valid),
        .s_axis_tready(axis_if_tx_cpl_ready),
        .s_axis_tlast(0),
        .s_axis_tdest(0),
        .s_axis_tid(axis_if_tx_cpl_tag),
        .s_axis_tuser(0),

        // AXI Stream output
        .m_axis_tdata(axis_tx_cpl_ts),
        .m_axis_tkeep(),
        .m_axis_tvalid(axis_tx_cpl_valid),
        .m_axis_tready(axis_tx_cpl_ready),
        .m_axis_tlast(),
        .m_axis_tid(axis_tx_cpl_tag),
        .m_axis_tdest(),
        .m_axis_tuser()
    );

end else begin

    assign axis_tx_cpl_ts = PTP_TS_ENABLE ? axis_if_tx_cpl_ts : 0;
    assign axis_tx_cpl_tag = axis_if_tx_cpl_tag;
    assign axis_tx_cpl_valid = axis_if_tx_cpl_valid;
    assign axis_if_tx_cpl_ready = axis_tx_cpl_ready;

end

if (APP_AXIS_IF_ENABLE) begin

    assign m_axis_app_if_tx_cpl_ts = PTP_TS_ENABLE ? axis_tx_cpl_ts : 0;
    assign m_axis_app_if_tx_cpl_tag = axis_tx_cpl_tag;
    assign m_axis_app_if_tx_cpl_valid = axis_tx_cpl_valid;
    assign axis_tx_cpl_ready = m_axis_app_if_tx_cpl_ready;

    assign if_tx_cpl_ts = PTP_TS_ENABLE ? s_axis_app_if_tx_cpl_ts : 0;
    assign if_tx_cpl_tag = s_axis_app_if_tx_cpl_tag;
    assign if_tx_cpl_valid = s_axis_app_if_tx_cpl_valid;
    assign s_axis_app_if_tx_cpl_ready = if_tx_cpl_ready;

end else begin

    assign m_axis_app_if_tx_cpl_ts = 0;
    assign m_axis_app_if_tx_cpl_tag = 0;
    assign m_axis_app_if_tx_cpl_valid = 0;

    assign s_axis_app_if_tx_cpl_ready = 0;

    assign if_tx_cpl_ts = PTP_TS_ENABLE ? axis_tx_cpl_ts : 0;
    assign if_tx_cpl_tag = axis_tx_cpl_tag;
    assign if_tx_cpl_valid = axis_tx_cpl_valid;
    assign axis_tx_cpl_ready = if_tx_cpl_ready;

end

wire [AXIS_IF_DATA_WIDTH-1:0] axis_if_tx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0] axis_if_tx_tkeep;
wire axis_if_tx_tvalid;
wire axis_if_tx_tready;
wire axis_if_tx_tlast;
wire [AXIS_IF_TX_ID_WIDTH-1:0] axis_if_tx_tid;
wire [AXIS_IF_TX_DEST_WIDTH-1:0] axis_if_tx_tdest;
wire [AXIS_IF_TX_USER_WIDTH-1:0] axis_if_tx_tuser;

wire [PORTS*AXIS_SYNC_DATA_WIDTH-1:0] axis_if_tx_fifo_tdata;
wire [PORTS*AXIS_SYNC_KEEP_WIDTH-1:0] axis_if_tx_fifo_tkeep;
wire [PORTS-1:0] axis_if_tx_fifo_tvalid;
wire [PORTS-1:0] axis_if_tx_fifo_tready;
wire [PORTS-1:0] axis_if_tx_fifo_tlast;
wire [PORTS*AXIS_IF_TX_ID_WIDTH-1:0] axis_if_tx_fifo_tid;
wire [PORTS*AXIS_IF_TX_USER_WIDTH-1:0] axis_if_tx_fifo_tuser;

if (APP_AXIS_IF_ENABLE) begin

    assign m_axis_app_if_tx_tdata = if_tx_axis_tdata;
    assign m_axis_app_if_tx_tkeep = if_tx_axis_tkeep;
    assign m_axis_app_if_tx_tvalid = if_tx_axis_tvalid;
    assign if_tx_axis_tready = m_axis_app_if_tx_tready;
    assign m_axis_app_if_tx_tlast = if_tx_axis_tlast;
    assign m_axis_app_if_tx_tid = if_tx_axis_tid;
    assign m_axis_app_if_tx_tdest = if_tx_axis_tdest;
    assign m_axis_app_if_tx_tuser = if_tx_axis_tuser;

    assign axis_if_tx_tdata = s_axis_app_if_tx_tdata;
    assign axis_if_tx_tkeep = s_axis_app_if_tx_tkeep;
    assign axis_if_tx_tvalid = s_axis_app_if_tx_tvalid;
    assign s_axis_app_if_tx_tready = axis_if_tx_tready;
    assign axis_if_tx_tlast = s_axis_app_if_tx_tlast;
    assign axis_if_tx_tid = s_axis_app_if_tx_tid;
    assign axis_if_tx_tdest = s_axis_app_if_tx_tdest;
    assign axis_if_tx_tuser = s_axis_app_if_tx_tuser;

end else begin

    assign m_axis_app_if_tx_tdata = 0;
    assign m_axis_app_if_tx_tkeep = 0;
    assign m_axis_app_if_tx_tvalid = 0;
    assign m_axis_app_if_tx_tlast = 0;
    assign m_axis_app_if_tx_tid = 0;
    assign m_axis_app_if_tx_tdest = 0;
    assign m_axis_app_if_tx_tuser = 0;

    assign s_axis_app_if_tx_tready = 0;

    assign axis_if_tx_tdata = if_tx_axis_tdata;
    assign axis_if_tx_tkeep = if_tx_axis_tkeep;
    assign axis_if_tx_tvalid = if_tx_axis_tvalid;
    assign if_tx_axis_tready = axis_if_tx_tready;
    assign axis_if_tx_tlast = if_tx_axis_tlast;
    assign axis_if_tx_tid = if_tx_axis_tid;
    assign axis_if_tx_tdest = if_tx_axis_tdest;
    assign axis_if_tx_tuser = if_tx_axis_tuser;

end

tx_fifo #(
    .FIFO_DEPTH(TX_FIFO_DEPTH),
    .PORTS(PORTS),
    .S_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .S_KEEP_ENABLE(AXIS_IF_KEEP_WIDTH > 1),
    .S_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .M_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .M_KEEP_ENABLE(AXIS_SYNC_KEEP_WIDTH > 1),
    .M_KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
    .ID_ENABLE(1),
    .ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
    .S_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
    .M_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_IF_TX_USER_WIDTH),
    .RAM_PIPELINE(AXIS_TX_FIFO_PIPELINE)
)
tx_fifo_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI Stream input
     */
    .s_axis_tdata(axis_if_tx_tdata),
    .s_axis_tkeep(axis_if_tx_tkeep),
    .s_axis_tvalid(axis_if_tx_tvalid),
    .s_axis_tready(axis_if_tx_tready),
    .s_axis_tlast(axis_if_tx_tlast),
    .s_axis_tid(axis_if_tx_tid),
    .s_axis_tdest(axis_if_tx_tdest),
    .s_axis_tuser(axis_if_tx_tuser),

    /*
     * AXI Stream outputs
     */
    .m_axis_tdata(axis_if_tx_fifo_tdata),
    .m_axis_tkeep(axis_if_tx_fifo_tkeep),
    .m_axis_tvalid(axis_if_tx_fifo_tvalid),
    .m_axis_tready(axis_if_tx_fifo_tready),
    .m_axis_tlast(axis_if_tx_fifo_tlast),
    .m_axis_tid(axis_if_tx_fifo_tid),
    .m_axis_tdest(),
    .m_axis_tuser(axis_if_tx_fifo_tuser),

    /*
     * Status
     */
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

// RX FIFO

wire [PORTS*AXIS_SYNC_DATA_WIDTH-1:0] axis_if_rx_fifo_tdata;
wire [PORTS*AXIS_SYNC_KEEP_WIDTH-1:0] axis_if_rx_fifo_tkeep;
wire [PORTS-1:0] axis_if_rx_fifo_tvalid;
wire [PORTS-1:0] axis_if_rx_fifo_tready;
wire [PORTS-1:0] axis_if_rx_fifo_tlast;
wire [PORTS*AXIS_IF_RX_DEST_WIDTH-1:0] axis_if_rx_fifo_tdest = 0;
wire [PORTS*AXIS_IF_RX_USER_WIDTH-1:0] axis_if_rx_fifo_tuser;

wire [AXIS_IF_DATA_WIDTH-1:0] axis_if_rx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0] axis_if_rx_tkeep;
wire axis_if_rx_tvalid;
wire axis_if_rx_tready;
wire axis_if_rx_tlast;
wire [AXIS_IF_RX_ID_WIDTH-1:0] axis_if_rx_tid;
wire [AXIS_IF_RX_DEST_WIDTH-1:0] axis_if_rx_tdest;
wire [AXIS_IF_RX_USER_WIDTH-1:0] axis_if_rx_tuser;

rx_fifo #(
    .FIFO_DEPTH(RX_FIFO_DEPTH),
    .PORTS(PORTS),
    .S_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .S_KEEP_ENABLE(AXIS_SYNC_KEEP_WIDTH > 1),
    .S_KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
    .M_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .M_KEEP_ENABLE(AXIS_IF_KEEP_WIDTH > 1),
    .M_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .ID_ENABLE(1),
    .M_ID_WIDTH(AXIS_IF_RX_ID_WIDTH),
    .DEST_WIDTH(AXIS_IF_RX_DEST_WIDTH),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_IF_RX_USER_WIDTH),
    .RAM_PIPELINE(AXIS_RX_FIFO_PIPELINE)
)
rx_fifo_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI Stream input
     */
    .s_axis_tdata(axis_if_rx_fifo_tdata),
    .s_axis_tkeep(axis_if_rx_fifo_tkeep),
    .s_axis_tvalid(axis_if_rx_fifo_tvalid),
    .s_axis_tready(axis_if_rx_fifo_tready),
    .s_axis_tlast(axis_if_rx_fifo_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(axis_if_rx_fifo_tdest),
    .s_axis_tuser(axis_if_rx_fifo_tuser),

    /*
     * AXI Stream outputs
     */
    .m_axis_tdata(axis_if_rx_tdata),
    .m_axis_tkeep(axis_if_rx_tkeep),
    .m_axis_tvalid(axis_if_rx_tvalid),
    .m_axis_tready(axis_if_rx_tready),
    .m_axis_tlast(axis_if_rx_tlast),
    .m_axis_tid(axis_if_rx_tid),
    .m_axis_tdest(axis_if_rx_tdest),
    .m_axis_tuser(axis_if_rx_tuser),

    /*
     * Status
     */
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

if (APP_AXIS_IF_ENABLE) begin

    assign m_axis_app_if_rx_tdata = axis_if_rx_tdata;
    assign m_axis_app_if_rx_tkeep = axis_if_rx_tkeep;
    assign m_axis_app_if_rx_tvalid = axis_if_rx_tvalid;
    assign axis_if_rx_tready = m_axis_app_if_rx_tready;
    assign m_axis_app_if_rx_tlast = axis_if_rx_tlast;
    assign m_axis_app_if_rx_tid = axis_if_rx_tid;
    assign m_axis_app_if_rx_tdest = axis_if_rx_tdest;
    assign m_axis_app_if_rx_tuser = axis_if_rx_tuser;

    assign if_rx_axis_tdata = s_axis_app_if_rx_tdata;
    assign if_rx_axis_tkeep = s_axis_app_if_rx_tkeep;
    assign if_rx_axis_tvalid = s_axis_app_if_rx_tvalid;
    assign s_axis_app_if_rx_tready = if_rx_axis_tready;
    assign if_rx_axis_tlast = s_axis_app_if_rx_tlast;
    assign if_rx_axis_tid = s_axis_app_if_rx_tid;
    assign if_rx_axis_tdest = s_axis_app_if_rx_tdest;
    assign if_rx_axis_tuser = s_axis_app_if_rx_tuser;

end else begin

    assign m_axis_app_if_rx_tdata = 0;
    assign m_axis_app_if_rx_tkeep = 0;
    assign m_axis_app_if_rx_tvalid = 0;
    assign m_axis_app_if_rx_tlast = 0;
    assign m_axis_app_if_rx_tid = 0;
    assign m_axis_app_if_rx_tdest = 0;
    assign m_axis_app_if_rx_tuser = 0;

    assign s_axis_app_if_rx_tready = 0;

    assign if_rx_axis_tdata = axis_if_rx_tdata;
    assign if_rx_axis_tkeep = axis_if_rx_tkeep;
    assign if_rx_axis_tvalid = axis_if_rx_tvalid;
    assign axis_if_rx_tready = if_rx_axis_tready;
    assign if_rx_axis_tlast = axis_if_rx_tlast;
    assign if_rx_axis_tid = axis_if_rx_tid;
    assign if_rx_axis_tdest = axis_if_rx_tdest;
    assign if_rx_axis_tuser = axis_if_rx_tuser;

end

for (n = 0; n < PORTS; n = n + 1) begin : port

    mqnic_port #(
        // PTP configuration
        .PTP_TS_WIDTH(PTP_TS_WIDTH),

        // Interface configuration
        .PTP_TS_ENABLE(PTP_TS_ENABLE),
        .TX_CPL_ENABLE(TX_CPL_ENABLE),
        .TX_CPL_FIFO_DEPTH(TX_CPL_FIFO_DEPTH),
        .TX_TAG_WIDTH(TX_TAG_WIDTH),
        .MAX_TX_SIZE(MAX_TX_SIZE),
        .MAX_RX_SIZE(MAX_RX_SIZE),

        // Application block configuration
        .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
        .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),

        // Register interface configuration
        .REG_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
        .REG_DATA_WIDTH(AXIL_DATA_WIDTH),
        .REG_STRB_WIDTH(AXIL_STRB_WIDTH),
        .RB_BASE_ADDR(PORT_RB_BASE_ADDR + PORT_RB_STRIDE*n),
        .RB_NEXT_PTR(n < PORTS-1 ? PORT_RB_BASE_ADDR + PORT_RB_STRIDE*(n+1) : SCHED_RB_BASE_ADDR),

        // Streaming interface configuration
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .AXIS_TX_USER_WIDTH(AXIS_TX_USER_WIDTH),
        .AXIS_RX_USER_WIDTH(AXIS_RX_USER_WIDTH),
        .AXIS_RX_USE_READY(AXIS_RX_USE_READY),
        .AXIS_TX_PIPELINE(AXIS_TX_PIPELINE),
        .AXIS_TX_FIFO_PIPELINE(AXIS_TX_FIFO_PIPELINE),
        .AXIS_TX_TS_PIPELINE(AXIS_TX_TS_PIPELINE),
        .AXIS_RX_PIPELINE(AXIS_RX_PIPELINE),
        .AXIS_RX_FIFO_PIPELINE(AXIS_RX_FIFO_PIPELINE),
        .AXIS_SYNC_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
        .AXIS_SYNC_KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
        .AXIS_SYNC_TX_USER_WIDTH(AXIS_SYNC_TX_USER_WIDTH),
        .AXIS_SYNC_RX_USER_WIDTH(AXIS_SYNC_RX_USER_WIDTH)
    )
    port_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Control register interface
         */
        .ctrl_reg_wr_addr(ctrl_reg_wr_addr),
        .ctrl_reg_wr_data(ctrl_reg_wr_data),
        .ctrl_reg_wr_strb(ctrl_reg_wr_strb),
        .ctrl_reg_wr_en(ctrl_reg_wr_en),
        .ctrl_reg_wr_wait(port_ctrl_reg_wr_wait[n]),
        .ctrl_reg_wr_ack(port_ctrl_reg_wr_ack[n]),
        .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
        .ctrl_reg_rd_en(ctrl_reg_rd_en),
        .ctrl_reg_rd_data(port_ctrl_reg_rd_data[n]),
        .ctrl_reg_rd_wait(port_ctrl_reg_rd_wait[n]),
        .ctrl_reg_rd_ack(port_ctrl_reg_rd_ack[n]),

        /*
         * Transmit data from interface FIFO
         */
        .s_axis_if_tx_tdata(axis_if_tx_fifo_tdata[n*AXIS_SYNC_DATA_WIDTH +: AXIS_SYNC_DATA_WIDTH]),
        .s_axis_if_tx_tkeep(axis_if_tx_fifo_tkeep[n*AXIS_SYNC_KEEP_WIDTH +: AXIS_SYNC_KEEP_WIDTH]),
        .s_axis_if_tx_tvalid(axis_if_tx_fifo_tvalid[n +: 1]),
        .s_axis_if_tx_tready(axis_if_tx_fifo_tready[n +: 1]),
        .s_axis_if_tx_tlast(axis_if_tx_fifo_tlast[n +: 1]),
        .s_axis_if_tx_tuser(axis_if_tx_fifo_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),

        .m_axis_if_tx_cpl_ts(axis_if_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
        .m_axis_if_tx_cpl_tag(axis_if_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
        .m_axis_if_tx_cpl_valid(axis_if_tx_cpl_valid[n +: 1]),
        .m_axis_if_tx_cpl_ready(axis_if_tx_cpl_ready[n +: 1]),

        /*
         * Receive data to interface FIFO
         */
        .m_axis_if_rx_tdata(axis_if_rx_fifo_tdata[n*AXIS_SYNC_DATA_WIDTH +: AXIS_SYNC_DATA_WIDTH]),
        .m_axis_if_rx_tkeep(axis_if_rx_fifo_tkeep[n*AXIS_SYNC_KEEP_WIDTH +: AXIS_SYNC_KEEP_WIDTH]),
        .m_axis_if_rx_tvalid(axis_if_rx_fifo_tvalid[n +: 1]),
        .m_axis_if_rx_tready(axis_if_rx_fifo_tready[n +: 1]),
        .m_axis_if_rx_tlast(axis_if_rx_fifo_tlast[n +: 1]),
        .m_axis_if_rx_tuser(axis_if_rx_fifo_tuser[n*AXIS_SYNC_RX_USER_WIDTH +: AXIS_SYNC_RX_USER_WIDTH]),

        /*
         * Application section datapath interface (synchronous MAC interface)
         */
        .m_axis_app_sync_tx_tdata(m_axis_app_sync_tx_tdata[n*AXIS_SYNC_DATA_WIDTH +: AXIS_SYNC_DATA_WIDTH]),
        .m_axis_app_sync_tx_tkeep(m_axis_app_sync_tx_tkeep[n*AXIS_SYNC_KEEP_WIDTH +: AXIS_SYNC_KEEP_WIDTH]),
        .m_axis_app_sync_tx_tvalid(m_axis_app_sync_tx_tvalid[n +: 1]),
        .m_axis_app_sync_tx_tready(m_axis_app_sync_tx_tready[n +: 1]),
        .m_axis_app_sync_tx_tlast(m_axis_app_sync_tx_tlast[n +: 1]),
        .m_axis_app_sync_tx_tuser(m_axis_app_sync_tx_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),

        .s_axis_app_sync_tx_tdata(s_axis_app_sync_tx_tdata[n*AXIS_SYNC_DATA_WIDTH +: AXIS_SYNC_DATA_WIDTH]),
        .s_axis_app_sync_tx_tkeep(s_axis_app_sync_tx_tkeep[n*AXIS_SYNC_KEEP_WIDTH +: AXIS_SYNC_KEEP_WIDTH]),
        .s_axis_app_sync_tx_tvalid(s_axis_app_sync_tx_tvalid[n +: 1]),
        .s_axis_app_sync_tx_tready(s_axis_app_sync_tx_tready[n +: 1]),
        .s_axis_app_sync_tx_tlast(s_axis_app_sync_tx_tlast[n +: 1]),
        .s_axis_app_sync_tx_tuser(s_axis_app_sync_tx_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),

        .m_axis_app_sync_tx_cpl_ts(m_axis_app_sync_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
        .m_axis_app_sync_tx_cpl_tag(m_axis_app_sync_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
        .m_axis_app_sync_tx_cpl_valid(m_axis_app_sync_tx_cpl_valid[n +: 1]),
        .m_axis_app_sync_tx_cpl_ready(m_axis_app_sync_tx_cpl_ready[n +: 1]),

        .s_axis_app_sync_tx_cpl_ts(s_axis_app_sync_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
        .s_axis_app_sync_tx_cpl_tag(s_axis_app_sync_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
        .s_axis_app_sync_tx_cpl_valid(s_axis_app_sync_tx_cpl_valid[n +: 1]),
        .s_axis_app_sync_tx_cpl_ready(s_axis_app_sync_tx_cpl_ready[n +: 1]),

        .m_axis_app_sync_rx_tdata(m_axis_app_sync_rx_tdata[n*AXIS_SYNC_DATA_WIDTH +: AXIS_SYNC_DATA_WIDTH]),
        .m_axis_app_sync_rx_tkeep(m_axis_app_sync_rx_tkeep[n*AXIS_SYNC_KEEP_WIDTH +: AXIS_SYNC_KEEP_WIDTH]),
        .m_axis_app_sync_rx_tvalid(m_axis_app_sync_rx_tvalid[n +: 1]),
        .m_axis_app_sync_rx_tready(m_axis_app_sync_rx_tready[n +: 1]),
        .m_axis_app_sync_rx_tlast(m_axis_app_sync_rx_tlast[n +: 1]),
        .m_axis_app_sync_rx_tuser(m_axis_app_sync_rx_tuser[n*AXIS_SYNC_RX_USER_WIDTH +: AXIS_SYNC_RX_USER_WIDTH]),

        .s_axis_app_sync_rx_tdata(s_axis_app_sync_rx_tdata[n*AXIS_SYNC_DATA_WIDTH +: AXIS_SYNC_DATA_WIDTH]),
        .s_axis_app_sync_rx_tkeep(s_axis_app_sync_rx_tkeep[n*AXIS_SYNC_KEEP_WIDTH +: AXIS_SYNC_KEEP_WIDTH]),
        .s_axis_app_sync_rx_tvalid(s_axis_app_sync_rx_tvalid[n +: 1]),
        .s_axis_app_sync_rx_tready(s_axis_app_sync_rx_tready[n +: 1]),
        .s_axis_app_sync_rx_tlast(s_axis_app_sync_rx_tlast[n +: 1]),
        .s_axis_app_sync_rx_tuser(s_axis_app_sync_rx_tuser[n*AXIS_SYNC_RX_USER_WIDTH +: AXIS_SYNC_RX_USER_WIDTH]),

        /*
         * Application section datapath interface (direct MAC interface)
         */
        .m_axis_app_direct_tx_tdata(m_axis_app_direct_tx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
        .m_axis_app_direct_tx_tkeep(m_axis_app_direct_tx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
        .m_axis_app_direct_tx_tvalid(m_axis_app_direct_tx_tvalid[n +: 1]),
        .m_axis_app_direct_tx_tready(m_axis_app_direct_tx_tready[n +: 1]),
        .m_axis_app_direct_tx_tlast(m_axis_app_direct_tx_tlast[n +: 1]),
        .m_axis_app_direct_tx_tuser(m_axis_app_direct_tx_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),

        .s_axis_app_direct_tx_tdata(s_axis_app_direct_tx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
        .s_axis_app_direct_tx_tkeep(s_axis_app_direct_tx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
        .s_axis_app_direct_tx_tvalid(s_axis_app_direct_tx_tvalid[n +: 1]),
        .s_axis_app_direct_tx_tready(s_axis_app_direct_tx_tready[n +: 1]),
        .s_axis_app_direct_tx_tlast(s_axis_app_direct_tx_tlast[n +: 1]),
        .s_axis_app_direct_tx_tuser(s_axis_app_direct_tx_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),

        .m_axis_app_direct_tx_cpl_ts(m_axis_app_direct_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
        .m_axis_app_direct_tx_cpl_tag(m_axis_app_direct_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
        .m_axis_app_direct_tx_cpl_valid(m_axis_app_direct_tx_cpl_valid[n +: 1]),
        .m_axis_app_direct_tx_cpl_ready(m_axis_app_direct_tx_cpl_ready[n +: 1]),

        .s_axis_app_direct_tx_cpl_ts(s_axis_app_direct_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
        .s_axis_app_direct_tx_cpl_tag(s_axis_app_direct_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
        .s_axis_app_direct_tx_cpl_valid(s_axis_app_direct_tx_cpl_valid[n +: 1]),
        .s_axis_app_direct_tx_cpl_ready(s_axis_app_direct_tx_cpl_ready[n +: 1]),

        .m_axis_app_direct_rx_tdata(m_axis_app_direct_rx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
        .m_axis_app_direct_rx_tkeep(m_axis_app_direct_rx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
        .m_axis_app_direct_rx_tvalid(m_axis_app_direct_rx_tvalid[n +: 1]),
        .m_axis_app_direct_rx_tready(m_axis_app_direct_rx_tready[n +: 1]),
        .m_axis_app_direct_rx_tlast(m_axis_app_direct_rx_tlast[n +: 1]),
        .m_axis_app_direct_rx_tuser(m_axis_app_direct_rx_tuser[n*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH]),

        .s_axis_app_direct_rx_tdata(s_axis_app_direct_rx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
        .s_axis_app_direct_rx_tkeep(s_axis_app_direct_rx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
        .s_axis_app_direct_rx_tvalid(s_axis_app_direct_rx_tvalid[n +: 1]),
        .s_axis_app_direct_rx_tready(s_axis_app_direct_rx_tready[n +: 1]),
        .s_axis_app_direct_rx_tlast(s_axis_app_direct_rx_tlast[n +: 1]),
        .s_axis_app_direct_rx_tuser(s_axis_app_direct_rx_tuser[n*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH]),

        /*
         * Transmit data output
         */
        .tx_clk(tx_clk[n +: 1]),
        .tx_rst(tx_rst[n +: 1]),

        .m_axis_tx_tdata(m_axis_tx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
        .m_axis_tx_tkeep(m_axis_tx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
        .m_axis_tx_tvalid(m_axis_tx_tvalid[n +: 1]),
        .m_axis_tx_tready(m_axis_tx_tready[n +: 1]),
        .m_axis_tx_tlast(m_axis_tx_tlast[n +: 1]),
        .m_axis_tx_tuser(m_axis_tx_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),

        .s_axis_tx_cpl_ts(s_axis_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
        .s_axis_tx_cpl_tag(s_axis_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
        .s_axis_tx_cpl_valid(s_axis_tx_cpl_valid[n +: 1]),
        .s_axis_tx_cpl_ready(s_axis_tx_cpl_ready[n +: 1]),

        .tx_status(tx_status[n +: 1]),

        /*
         * Receive data input
         */
        .rx_clk(rx_clk[n +: 1]),
        .rx_rst(rx_rst[n +: 1]),

        .s_axis_rx_tdata(s_axis_rx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
        .s_axis_rx_tkeep(s_axis_rx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
        .s_axis_rx_tvalid(s_axis_rx_tvalid[n +: 1]),
        .s_axis_rx_tready(s_axis_rx_tready[n +: 1]),
        .s_axis_rx_tlast(s_axis_rx_tlast[n +: 1]),
        .s_axis_rx_tuser(s_axis_rx_tuser[n*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH]),

        .rx_status(rx_status[n +: 1])
    );

end

endgenerate

endmodule

`resetall
