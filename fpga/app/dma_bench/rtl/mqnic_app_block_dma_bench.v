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
 * Application block (DMA benchmark application)
 */
module mqnic_app_block #
(
    // Structural configuration
    parameter IF_COUNT = 1,
    parameter PORTS_PER_IF = 1,
    parameter SCHED_PER_IF = PORTS_PER_IF,

    parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF,

    // Clock configuration
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,

    // PTP configuration
    parameter PTP_CLK_PERIOD_NS_NUM = 4,
    parameter PTP_CLK_PERIOD_NS_DENOM = 1,
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_USE_SAMPLE_CLOCK = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Interface configuration
    parameter PTP_TS_ENABLE = 1,
    parameter TX_TAG_WIDTH = 16,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,

    // RAM configuration
    parameter DDR_CH = 1,
    parameter DDR_ENABLE = 0,
    parameter DDR_GROUP_SIZE = 1,
    parameter AXI_DDR_DATA_WIDTH = 256,
    parameter AXI_DDR_ADDR_WIDTH = 32,
    parameter AXI_DDR_STRB_WIDTH = (AXI_DDR_DATA_WIDTH/8),
    parameter AXI_DDR_ID_WIDTH = 8,
    parameter AXI_DDR_AWUSER_ENABLE = 0,
    parameter AXI_DDR_AWUSER_WIDTH = 1,
    parameter AXI_DDR_WUSER_ENABLE = 0,
    parameter AXI_DDR_WUSER_WIDTH = 1,
    parameter AXI_DDR_BUSER_ENABLE = 0,
    parameter AXI_DDR_BUSER_WIDTH = 1,
    parameter AXI_DDR_ARUSER_ENABLE = 0,
    parameter AXI_DDR_ARUSER_WIDTH = 1,
    parameter AXI_DDR_RUSER_ENABLE = 0,
    parameter AXI_DDR_RUSER_WIDTH = 1,
    parameter AXI_DDR_MAX_BURST_LEN = 256,
    parameter AXI_DDR_NARROW_BURST = 0,
    parameter AXI_DDR_FIXED_BURST = 0,
    parameter AXI_DDR_WRAP_BURST = 0,
    parameter HBM_CH = 1,
    parameter HBM_ENABLE = 0,
    parameter HBM_GROUP_SIZE = 1,
    parameter AXI_HBM_DATA_WIDTH = 256,
    parameter AXI_HBM_ADDR_WIDTH = 32,
    parameter AXI_HBM_STRB_WIDTH = (AXI_HBM_DATA_WIDTH/8),
    parameter AXI_HBM_ID_WIDTH = 8,
    parameter AXI_HBM_AWUSER_ENABLE = 0,
    parameter AXI_HBM_AWUSER_WIDTH = 1,
    parameter AXI_HBM_WUSER_ENABLE = 0,
    parameter AXI_HBM_WUSER_WIDTH = 1,
    parameter AXI_HBM_BUSER_ENABLE = 0,
    parameter AXI_HBM_BUSER_WIDTH = 1,
    parameter AXI_HBM_ARUSER_ENABLE = 0,
    parameter AXI_HBM_ARUSER_WIDTH = 1,
    parameter AXI_HBM_RUSER_ENABLE = 0,
    parameter AXI_HBM_RUSER_WIDTH = 1,
    parameter AXI_HBM_MAX_BURST_LEN = 256,
    parameter AXI_HBM_NARROW_BURST = 0,
    parameter AXI_HBM_FIXED_BURST = 0,
    parameter AXI_HBM_WRAP_BURST = 0,

    // Application configuration
    parameter APP_ID = 32'h12348001,
    parameter APP_CTRL_ENABLE = 1,
    parameter APP_DMA_ENABLE = 1,
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,
    parameter APP_AXIS_IF_ENABLE = 1,
    parameter APP_STAT_ENABLE = 1,
    parameter APP_GPIO_IN_WIDTH = 32,
    parameter APP_GPIO_OUT_WIDTH = 32,

    // DMA interface configuration
    parameter DMA_ADDR_WIDTH = 64,
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_SEL_WIDTH = 4,
    parameter RAM_ADDR_WIDTH = 16,
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
    parameter RAM_PIPELINE = 2,

    // AXI lite interface (application control from host)
    parameter AXIL_APP_CTRL_DATA_WIDTH = 32,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 16,
    parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8),

    // AXI lite interface (control to NIC)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 16,
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),

    // Ethernet interface configuration (direct, async)
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_RX_USE_READY = 0,

    // Ethernet interface configuration (direct, sync)
    parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_SYNC_KEEP_WIDTH = AXIS_SYNC_DATA_WIDTH/8,
    parameter AXIS_SYNC_TX_USER_WIDTH = AXIS_TX_USER_WIDTH,
    parameter AXIS_SYNC_RX_USER_WIDTH = AXIS_RX_USER_WIDTH,

    // Ethernet interface configuration (interface)
    parameter AXIS_IF_DATA_WIDTH = AXIS_SYNC_DATA_WIDTH*2**$clog2(PORTS_PER_IF),
    parameter AXIS_IF_KEEP_WIDTH = AXIS_IF_DATA_WIDTH/8,
    parameter AXIS_IF_TX_ID_WIDTH = 12,
    parameter AXIS_IF_RX_ID_WIDTH = PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1,
    parameter AXIS_IF_TX_DEST_WIDTH = $clog2(PORTS_PER_IF)+4,
    parameter AXIS_IF_RX_DEST_WIDTH = 8,
    parameter AXIS_IF_TX_USER_WIDTH = AXIS_SYNC_TX_USER_WIDTH,
    parameter AXIS_IF_RX_USER_WIDTH = AXIS_SYNC_RX_USER_WIDTH,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    input  wire                                           clk,
    input  wire                                           rst,

    /*
     * AXI-Lite slave interface (control from host)
     */
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]            s_axil_app_ctrl_awaddr,
    input  wire [2:0]                                     s_axil_app_ctrl_awprot,
    input  wire                                           s_axil_app_ctrl_awvalid,
    output wire                                           s_axil_app_ctrl_awready,
    input  wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]            s_axil_app_ctrl_wdata,
    input  wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]            s_axil_app_ctrl_wstrb,
    input  wire                                           s_axil_app_ctrl_wvalid,
    output wire                                           s_axil_app_ctrl_wready,
    output wire [1:0]                                     s_axil_app_ctrl_bresp,
    output wire                                           s_axil_app_ctrl_bvalid,
    input  wire                                           s_axil_app_ctrl_bready,
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]            s_axil_app_ctrl_araddr,
    input  wire [2:0]                                     s_axil_app_ctrl_arprot,
    input  wire                                           s_axil_app_ctrl_arvalid,
    output wire                                           s_axil_app_ctrl_arready,
    output wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]            s_axil_app_ctrl_rdata,
    output wire [1:0]                                     s_axil_app_ctrl_rresp,
    output wire                                           s_axil_app_ctrl_rvalid,
    input  wire                                           s_axil_app_ctrl_rready,

    /*
     * AXI-Lite master interface (control to NIC)
     */
    output wire [AXIL_CTRL_ADDR_WIDTH-1:0]                m_axil_ctrl_awaddr,
    output wire [2:0]                                     m_axil_ctrl_awprot,
    output wire                                           m_axil_ctrl_awvalid,
    input  wire                                           m_axil_ctrl_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]                m_axil_ctrl_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]                m_axil_ctrl_wstrb,
    output wire                                           m_axil_ctrl_wvalid,
    input  wire                                           m_axil_ctrl_wready,
    input  wire [1:0]                                     m_axil_ctrl_bresp,
    input  wire                                           m_axil_ctrl_bvalid,
    output wire                                           m_axil_ctrl_bready,
    output wire [AXIL_CTRL_ADDR_WIDTH-1:0]                m_axil_ctrl_araddr,
    output wire [2:0]                                     m_axil_ctrl_arprot,
    output wire                                           m_axil_ctrl_arvalid,
    input  wire                                           m_axil_ctrl_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]                m_axil_ctrl_rdata,
    input  wire [1:0]                                     m_axil_ctrl_rresp,
    input  wire                                           m_axil_ctrl_rvalid,
    output wire                                           m_axil_ctrl_rready,

    /*
     * DMA read descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_ctrl_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_ctrl_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_ctrl_dma_read_desc_tag,
    output wire                                           m_axis_ctrl_dma_read_desc_valid,
    input  wire                                           m_axis_ctrl_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_ctrl_dma_read_desc_status_tag,
    input  wire [3:0]                                     s_axis_ctrl_dma_read_desc_status_error,
    input  wire                                           s_axis_ctrl_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_imm,
    output wire                                           m_axis_ctrl_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_tag,
    output wire                                           m_axis_ctrl_dma_write_desc_valid,
    input  wire                                           m_axis_ctrl_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_ctrl_dma_write_desc_status_tag,
    input  wire [3:0]                                     s_axis_ctrl_dma_write_desc_status_error,
    input  wire                                           s_axis_ctrl_dma_write_desc_status_valid,

    /*
     * DMA read descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_data_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_data_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_data_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_data_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_data_dma_read_desc_tag,
    output wire                                           m_axis_data_dma_read_desc_valid,
    input  wire                                           m_axis_data_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_data_dma_read_desc_status_tag,
    input  wire [3:0]                                     s_axis_data_dma_read_desc_status_error,
    input  wire                                           s_axis_data_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_data_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_data_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_data_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                       m_axis_data_dma_write_desc_imm,
    output wire                                           m_axis_data_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_data_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_data_dma_write_desc_tag,
    output wire                                           m_axis_data_dma_write_desc_valid,
    input  wire                                           m_axis_data_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_data_dma_write_desc_status_tag,
    input  wire [3:0]                                     s_axis_data_dma_write_desc_status_error,
    input  wire                                           s_axis_data_dma_write_desc_status_valid,

    /*
     * DMA RAM interface (control)
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         ctrl_dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]      ctrl_dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    ctrl_dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    ctrl_dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         ctrl_dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    ctrl_dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    ctrl_dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_resp_ready,

    /*
     * DMA RAM interface (data)
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         data_dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]      data_dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    data_dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    data_dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         data_dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    data_dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    data_dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_resp_ready,

    /*
     * PTP clock
     */
    input  wire                                           ptp_clk,
    input  wire                                           ptp_rst,
    input  wire                                           ptp_sample_clk,
    input  wire                                           ptp_pps,
    input  wire                                           ptp_pps_str,
    input  wire [PTP_TS_WIDTH-1:0]                        ptp_ts_96,
    input  wire                                           ptp_ts_step,
    input  wire                                           ptp_sync_pps,
    input  wire [PTP_TS_WIDTH-1:0]                        ptp_sync_ts_96,
    input  wire                                           ptp_sync_ts_step,
    input  wire [PTP_PEROUT_COUNT-1:0]                    ptp_perout_locked,
    input  wire [PTP_PEROUT_COUNT-1:0]                    ptp_perout_error,
    input  wire [PTP_PEROUT_COUNT-1:0]                    ptp_perout_pulse,

    /*
     * Ethernet (direct MAC interface - lowest latency raw traffic)
     */
    input  wire [PORT_COUNT-1:0]                          direct_tx_clk,
    input  wire [PORT_COUNT-1:0]                          direct_tx_rst,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          s_axis_direct_tx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          s_axis_direct_tx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_tx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_direct_tx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_tx_tlast,
    input  wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]       s_axis_direct_tx_tuser,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          m_axis_direct_tx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          m_axis_direct_tx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_direct_tx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_tx_tlast,
    output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]       m_axis_direct_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             s_axis_direct_tx_cpl_ts,
    input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             s_axis_direct_tx_cpl_tag,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_tx_cpl_valid,
    output wire [PORT_COUNT-1:0]                          s_axis_direct_tx_cpl_ready,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             m_axis_direct_tx_cpl_ts,
    output wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             m_axis_direct_tx_cpl_tag,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_tx_cpl_valid,
    input  wire [PORT_COUNT-1:0]                          m_axis_direct_tx_cpl_ready,

    input  wire [PORT_COUNT-1:0]                          direct_rx_clk,
    input  wire [PORT_COUNT-1:0]                          direct_rx_rst,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          s_axis_direct_rx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          s_axis_direct_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_rx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_direct_rx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_rx_tlast,
    input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]       s_axis_direct_rx_tuser,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          m_axis_direct_rx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          m_axis_direct_rx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_rx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_direct_rx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_rx_tlast,
    output wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]       m_axis_direct_rx_tuser,

    /*
     * Ethernet (synchronous MAC interface - low latency raw traffic)
     */
    input  wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     s_axis_sync_tx_tdata,
    input  wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     s_axis_sync_tx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_tx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_sync_tx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_tx_tlast,
    input  wire [PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH-1:0]  s_axis_sync_tx_tuser,

    output wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     m_axis_sync_tx_tdata,
    output wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     m_axis_sync_tx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_sync_tx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_tx_tlast,
    output wire [PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH-1:0]  m_axis_sync_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             s_axis_sync_tx_cpl_ts,
    input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             s_axis_sync_tx_cpl_tag,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_tx_cpl_valid,
    output wire [PORT_COUNT-1:0]                          s_axis_sync_tx_cpl_ready,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             m_axis_sync_tx_cpl_ts,
    output wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             m_axis_sync_tx_cpl_tag,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_tx_cpl_valid,
    input  wire [PORT_COUNT-1:0]                          m_axis_sync_tx_cpl_ready,

    input  wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     s_axis_sync_rx_tdata,
    input  wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     s_axis_sync_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_rx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_sync_rx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_rx_tlast,
    input  wire [PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH-1:0]  s_axis_sync_rx_tuser,

    output wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     m_axis_sync_rx_tdata,
    output wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     m_axis_sync_rx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_rx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_sync_rx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_rx_tlast,
    output wire [PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH-1:0]  m_axis_sync_rx_tuser,

    /*
     * Ethernet (internal at interface module)
     */
    input  wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         s_axis_if_tx_tdata,
    input  wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         s_axis_if_tx_tkeep,
    input  wire [IF_COUNT-1:0]                            s_axis_if_tx_tvalid,
    output wire [IF_COUNT-1:0]                            s_axis_if_tx_tready,
    input  wire [IF_COUNT-1:0]                            s_axis_if_tx_tlast,
    input  wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]        s_axis_if_tx_tid,
    input  wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]      s_axis_if_tx_tdest,
    input  wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]      s_axis_if_tx_tuser,

    output wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         m_axis_if_tx_tdata,
    output wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         m_axis_if_tx_tkeep,
    output wire [IF_COUNT-1:0]                            m_axis_if_tx_tvalid,
    input  wire [IF_COUNT-1:0]                            m_axis_if_tx_tready,
    output wire [IF_COUNT-1:0]                            m_axis_if_tx_tlast,
    output wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]        m_axis_if_tx_tid,
    output wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]      m_axis_if_tx_tdest,
    output wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]      m_axis_if_tx_tuser,

    input  wire [IF_COUNT*PTP_TS_WIDTH-1:0]               s_axis_if_tx_cpl_ts,
    input  wire [IF_COUNT*TX_TAG_WIDTH-1:0]               s_axis_if_tx_cpl_tag,
    input  wire [IF_COUNT-1:0]                            s_axis_if_tx_cpl_valid,
    output wire [IF_COUNT-1:0]                            s_axis_if_tx_cpl_ready,

    output wire [IF_COUNT*PTP_TS_WIDTH-1:0]               m_axis_if_tx_cpl_ts,
    output wire [IF_COUNT*TX_TAG_WIDTH-1:0]               m_axis_if_tx_cpl_tag,
    output wire [IF_COUNT-1:0]                            m_axis_if_tx_cpl_valid,
    input  wire [IF_COUNT-1:0]                            m_axis_if_tx_cpl_ready,

    input  wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         s_axis_if_rx_tdata,
    input  wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         s_axis_if_rx_tkeep,
    input  wire [IF_COUNT-1:0]                            s_axis_if_rx_tvalid,
    output wire [IF_COUNT-1:0]                            s_axis_if_rx_tready,
    input  wire [IF_COUNT-1:0]                            s_axis_if_rx_tlast,
    input  wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]        s_axis_if_rx_tid,
    input  wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]      s_axis_if_rx_tdest,
    input  wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]      s_axis_if_rx_tuser,

    output wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         m_axis_if_rx_tdata,
    output wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         m_axis_if_rx_tkeep,
    output wire [IF_COUNT-1:0]                            m_axis_if_rx_tvalid,
    input  wire [IF_COUNT-1:0]                            m_axis_if_rx_tready,
    output wire [IF_COUNT-1:0]                            m_axis_if_rx_tlast,
    output wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]        m_axis_if_rx_tid,
    output wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]      m_axis_if_rx_tdest,
    output wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]      m_axis_if_rx_tuser,

    /*
     * DDR
     */
    input  wire [DDR_CH-1:0]                              ddr_clk,
    input  wire [DDR_CH-1:0]                              ddr_rst,

    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_awid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]           m_axi_ddr_awaddr,
    output wire [DDR_CH*8-1:0]                            m_axi_ddr_awlen,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_awsize,
    output wire [DDR_CH*2-1:0]                            m_axi_ddr_awburst,
    output wire [DDR_CH-1:0]                              m_axi_ddr_awlock,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_awcache,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_awprot,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_awqos,
    output wire [DDR_CH*AXI_DDR_AWUSER_WIDTH-1:0]         m_axi_ddr_awuser,
    output wire [DDR_CH-1:0]                              m_axi_ddr_awvalid,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_awready,
    output wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]           m_axi_ddr_wdata,
    output wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]           m_axi_ddr_wstrb,
    output wire [DDR_CH-1:0]                              m_axi_ddr_wlast,
    output wire [DDR_CH*AXI_DDR_WUSER_WIDTH-1:0]          m_axi_ddr_wuser,
    output wire [DDR_CH-1:0]                              m_axi_ddr_wvalid,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_wready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_bid,
    input  wire [DDR_CH*2-1:0]                            m_axi_ddr_bresp,
    input  wire [DDR_CH*AXI_DDR_BUSER_WIDTH-1:0]          m_axi_ddr_buser,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_bvalid,
    output wire [DDR_CH-1:0]                              m_axi_ddr_bready,
    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_arid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]           m_axi_ddr_araddr,
    output wire [DDR_CH*8-1:0]                            m_axi_ddr_arlen,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_arsize,
    output wire [DDR_CH*2-1:0]                            m_axi_ddr_arburst,
    output wire [DDR_CH-1:0]                              m_axi_ddr_arlock,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_arcache,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_arprot,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_arqos,
    output wire [DDR_CH*AXI_DDR_ARUSER_WIDTH-1:0]         m_axi_ddr_aruser,
    output wire [DDR_CH-1:0]                              m_axi_ddr_arvalid,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_arready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_rid,
    input  wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]           m_axi_ddr_rdata,
    input  wire [DDR_CH*2-1:0]                            m_axi_ddr_rresp,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_rlast,
    input  wire [DDR_CH*AXI_DDR_RUSER_WIDTH-1:0]          m_axi_ddr_ruser,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_rvalid,
    output wire [DDR_CH-1:0]                              m_axi_ddr_rready,

    input  wire [DDR_CH-1:0]                              ddr_status,

    /*
     * HBM
     */
    input  wire [HBM_CH-1:0]                              hbm_clk,
    input  wire [HBM_CH-1:0]                              hbm_rst,

    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_awid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]           m_axi_hbm_awaddr,
    output wire [HBM_CH*8-1:0]                            m_axi_hbm_awlen,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_awsize,
    output wire [HBM_CH*2-1:0]                            m_axi_hbm_awburst,
    output wire [HBM_CH-1:0]                              m_axi_hbm_awlock,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_awcache,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_awprot,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_awqos,
    output wire [HBM_CH*AXI_HBM_AWUSER_WIDTH-1:0]         m_axi_hbm_awuser,
    output wire [HBM_CH-1:0]                              m_axi_hbm_awvalid,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_awready,
    output wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]           m_axi_hbm_wdata,
    output wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]           m_axi_hbm_wstrb,
    output wire [HBM_CH-1:0]                              m_axi_hbm_wlast,
    output wire [HBM_CH*AXI_HBM_WUSER_WIDTH-1:0]          m_axi_hbm_wuser,
    output wire [HBM_CH-1:0]                              m_axi_hbm_wvalid,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_wready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_bid,
    input  wire [HBM_CH*2-1:0]                            m_axi_hbm_bresp,
    input  wire [HBM_CH*AXI_HBM_BUSER_WIDTH-1:0]          m_axi_hbm_buser,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_bvalid,
    output wire [HBM_CH-1:0]                              m_axi_hbm_bready,
    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_arid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]           m_axi_hbm_araddr,
    output wire [HBM_CH*8-1:0]                            m_axi_hbm_arlen,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_arsize,
    output wire [HBM_CH*2-1:0]                            m_axi_hbm_arburst,
    output wire [HBM_CH-1:0]                              m_axi_hbm_arlock,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_arcache,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_arprot,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_arqos,
    output wire [HBM_CH*AXI_HBM_ARUSER_WIDTH-1:0]         m_axi_hbm_aruser,
    output wire [HBM_CH-1:0]                              m_axi_hbm_arvalid,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_arready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_rid,
    input  wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]           m_axi_hbm_rdata,
    input  wire [HBM_CH*2-1:0]                            m_axi_hbm_rresp,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_rlast,
    input  wire [HBM_CH*AXI_HBM_RUSER_WIDTH-1:0]          m_axi_hbm_ruser,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_rvalid,
    output wire [HBM_CH-1:0]                              m_axi_hbm_rready,

    input  wire [HBM_CH-1:0]                              hbm_status,

    /*
     * Statistics increment output
     */
    output wire [STAT_INC_WIDTH-1:0]                      m_axis_stat_tdata,
    output wire [STAT_ID_WIDTH-1:0]                       m_axis_stat_tid,
    output wire                                           m_axis_stat_tvalid,
    input  wire                                           m_axis_stat_tready,

    /*
     * GPIO
     */
    input  wire [APP_GPIO_IN_WIDTH-1:0]                   gpio_in,
    output wire [APP_GPIO_OUT_WIDTH-1:0]                  gpio_out,

    /*
     * JTAG
     */
    input  wire                                           jtag_tdi,
    output wire                                           jtag_tdo,
    input  wire                                           jtag_tms,
    input  wire                                           jtag_tck
);

// check configuration
initial begin
    if (APP_ID != 32'h12348001) begin
        $error("Error: Invalid APP_ID (expected 32'h12348001, got 32'h%x) (instance %m)", APP_ID);
        $finish;
    end

    if (!APP_DMA_ENABLE) begin
        $error("Error: APP_DMA_ENABLE required (instance %m)");
        $finish;
    end
end

localparam RAM_ADDR_IMM_WIDTH = (DMA_IMM_ENABLE && (DMA_IMM_WIDTH > RAM_ADDR_WIDTH)) ? DMA_IMM_WIDTH : RAM_ADDR_WIDTH;

/*
 * AXI-Lite master interface (control to NIC)
 */
assign m_axil_ctrl_awaddr = 0;
assign m_axil_ctrl_awprot = 0;
assign m_axil_ctrl_awvalid = 1'b0;
assign m_axil_ctrl_wdata = 0;
assign m_axil_ctrl_wstrb = 0;
assign m_axil_ctrl_wvalid = 1'b0;
assign m_axil_ctrl_bready = 1'b1;
assign m_axil_ctrl_araddr = 0;
assign m_axil_ctrl_arprot = 0;
assign m_axil_ctrl_arvalid = 1'b0;
assign m_axil_ctrl_rready = 1'b1;

/*
 * DMA interface (control)
 */
assign m_axis_ctrl_dma_read_desc_dma_addr = 0;
assign m_axis_ctrl_dma_read_desc_ram_sel = 0;
assign m_axis_ctrl_dma_read_desc_ram_addr = 0;
assign m_axis_ctrl_dma_read_desc_len = 0;
assign m_axis_ctrl_dma_read_desc_tag = 0;
assign m_axis_ctrl_dma_read_desc_valid = 1'b0;
assign m_axis_ctrl_dma_write_desc_dma_addr = 0;
assign m_axis_ctrl_dma_write_desc_ram_sel = 0;
assign m_axis_ctrl_dma_write_desc_ram_addr = 0;
assign m_axis_ctrl_dma_write_desc_imm = 0;
assign m_axis_ctrl_dma_write_desc_imm_en = 0;
assign m_axis_ctrl_dma_write_desc_len = 0;
assign m_axis_ctrl_dma_write_desc_tag = 0;
assign m_axis_ctrl_dma_write_desc_valid = 1'b0;

assign ctrl_dma_ram_wr_cmd_ready = 1'b1;
assign ctrl_dma_ram_wr_done = ctrl_dma_ram_wr_cmd_valid;
assign ctrl_dma_ram_rd_cmd_ready = ctrl_dma_ram_rd_resp_ready;
assign ctrl_dma_ram_rd_resp_data = 0;
assign ctrl_dma_ram_rd_resp_valid = ctrl_dma_ram_rd_cmd_valid;

/*
 * Ethernet (direct MAC interface - lowest latency raw traffic)
 */
assign m_axis_direct_tx_tdata = s_axis_direct_tx_tdata;
assign m_axis_direct_tx_tkeep = s_axis_direct_tx_tkeep;
assign m_axis_direct_tx_tvalid = s_axis_direct_tx_tvalid;
assign s_axis_direct_tx_tready = m_axis_direct_tx_tready;
assign m_axis_direct_tx_tlast = s_axis_direct_tx_tlast;
assign m_axis_direct_tx_tuser = s_axis_direct_tx_tuser;

assign m_axis_direct_tx_cpl_ts = s_axis_direct_tx_cpl_ts;
assign m_axis_direct_tx_cpl_tag = s_axis_direct_tx_cpl_tag;
assign m_axis_direct_tx_cpl_valid = s_axis_direct_tx_cpl_valid;
assign s_axis_direct_tx_cpl_ready = m_axis_direct_tx_cpl_ready;

assign m_axis_direct_rx_tdata = s_axis_direct_rx_tdata;
assign m_axis_direct_rx_tkeep = s_axis_direct_rx_tkeep;
assign m_axis_direct_rx_tvalid = s_axis_direct_rx_tvalid;
assign s_axis_direct_rx_tready = m_axis_direct_rx_tready;
assign m_axis_direct_rx_tlast = s_axis_direct_rx_tlast;
assign m_axis_direct_rx_tuser = s_axis_direct_rx_tuser;

/*
 * Ethernet (synchronous MAC interface - low latency raw traffic)
 */
assign m_axis_sync_tx_tdata = s_axis_sync_tx_tdata;
assign m_axis_sync_tx_tkeep = s_axis_sync_tx_tkeep;
assign m_axis_sync_tx_tvalid = s_axis_sync_tx_tvalid;
assign s_axis_sync_tx_tready = m_axis_sync_tx_tready;
assign m_axis_sync_tx_tlast = s_axis_sync_tx_tlast;
assign m_axis_sync_tx_tuser = s_axis_sync_tx_tuser;

assign m_axis_sync_tx_cpl_ts = s_axis_sync_tx_cpl_ts;
assign m_axis_sync_tx_cpl_tag = s_axis_sync_tx_cpl_tag;
assign m_axis_sync_tx_cpl_valid = s_axis_sync_tx_cpl_valid;
assign s_axis_sync_tx_cpl_ready = m_axis_sync_tx_cpl_ready;

assign m_axis_sync_rx_tdata = s_axis_sync_rx_tdata;
assign m_axis_sync_rx_tkeep = s_axis_sync_rx_tkeep;
assign m_axis_sync_rx_tvalid = s_axis_sync_rx_tvalid;
assign s_axis_sync_rx_tready = m_axis_sync_rx_tready;
assign m_axis_sync_rx_tlast = s_axis_sync_rx_tlast;
assign m_axis_sync_rx_tuser = s_axis_sync_rx_tuser;

/*
 * Ethernet (internal at interface module)
 */
assign m_axis_if_tx_tdata = s_axis_if_tx_tdata;
assign m_axis_if_tx_tkeep = s_axis_if_tx_tkeep;
assign m_axis_if_tx_tvalid = s_axis_if_tx_tvalid;
assign s_axis_if_tx_tready = m_axis_if_tx_tready;
assign m_axis_if_tx_tlast = s_axis_if_tx_tlast;
assign m_axis_if_tx_tid = s_axis_if_tx_tid;
assign m_axis_if_tx_tdest = s_axis_if_tx_tdest;
assign m_axis_if_tx_tuser = s_axis_if_tx_tuser;

assign m_axis_if_tx_cpl_ts = s_axis_if_tx_cpl_ts;
assign m_axis_if_tx_cpl_tag = s_axis_if_tx_cpl_tag;
assign m_axis_if_tx_cpl_valid = s_axis_if_tx_cpl_valid;
assign s_axis_if_tx_cpl_ready = m_axis_if_tx_cpl_ready;

assign m_axis_if_rx_tdata = s_axis_if_rx_tdata;
assign m_axis_if_rx_tkeep = s_axis_if_rx_tkeep;
assign m_axis_if_rx_tvalid = s_axis_if_rx_tvalid;
assign s_axis_if_rx_tready = m_axis_if_rx_tready;
assign m_axis_if_rx_tlast = s_axis_if_rx_tlast;
assign m_axis_if_rx_tid = s_axis_if_rx_tid;
assign m_axis_if_rx_tdest = s_axis_if_rx_tdest;
assign m_axis_if_rx_tuser = s_axis_if_rx_tuser;

/*
 * DDR
 */
assign m_axi_ddr_awid = 0;
assign m_axi_ddr_awaddr = 0;
assign m_axi_ddr_awlen = 0;
assign m_axi_ddr_awsize = 0;
assign m_axi_ddr_awburst = 0;
assign m_axi_ddr_awlock = 0;
assign m_axi_ddr_awcache = 0;
assign m_axi_ddr_awprot = 0;
assign m_axi_ddr_awqos = 0;
assign m_axi_ddr_awuser = 0;
assign m_axi_ddr_awvalid = 0;
assign m_axi_ddr_wdata = 0;
assign m_axi_ddr_wstrb = 0;
assign m_axi_ddr_wlast = 0;
assign m_axi_ddr_wuser = 0;
assign m_axi_ddr_wvalid = 0;
assign m_axi_ddr_bready = 0;
assign m_axi_ddr_arid = 0;
assign m_axi_ddr_araddr = 0;
assign m_axi_ddr_arlen = 0;
assign m_axi_ddr_arsize = 0;
assign m_axi_ddr_arburst = 0;
assign m_axi_ddr_arlock = 0;
assign m_axi_ddr_arcache = 0;
assign m_axi_ddr_arprot = 0;
assign m_axi_ddr_arqos = 0;
assign m_axi_ddr_aruser = 0;
assign m_axi_ddr_arvalid = 0;
assign m_axi_ddr_rready = 0;

/*
 * HBM
 */
assign m_axi_hbm_awid = 0;
assign m_axi_hbm_awaddr = 0;
assign m_axi_hbm_awlen = 0;
assign m_axi_hbm_awsize = 0;
assign m_axi_hbm_awburst = 0;
assign m_axi_hbm_awlock = 0;
assign m_axi_hbm_awcache = 0;
assign m_axi_hbm_awprot = 0;
assign m_axi_hbm_awqos = 0;
assign m_axi_hbm_awuser = 0;
assign m_axi_hbm_awvalid = 0;
assign m_axi_hbm_wdata = 0;
assign m_axi_hbm_wstrb = 0;
assign m_axi_hbm_wlast = 0;
assign m_axi_hbm_wuser = 0;
assign m_axi_hbm_wvalid = 0;
assign m_axi_hbm_bready = 0;
assign m_axi_hbm_arid = 0;
assign m_axi_hbm_araddr = 0;
assign m_axi_hbm_arlen = 0;
assign m_axi_hbm_arsize = 0;
assign m_axi_hbm_arburst = 0;
assign m_axi_hbm_arlock = 0;
assign m_axi_hbm_arcache = 0;
assign m_axi_hbm_arprot = 0;
assign m_axi_hbm_arqos = 0;
assign m_axi_hbm_aruser = 0;
assign m_axi_hbm_arvalid = 0;
assign m_axi_hbm_rready = 0;

/*
 * Statistics increment output
 */
assign m_axis_stat_tdata = 0;
assign m_axis_stat_tid = 0;
assign m_axis_stat_tvalid = 1'b0;

/*
 * GPIO
 */
assign gpio_out = 0;

/*
 * JTAG
 */
assign jtag_tdo = jtag_tdi;


// AXI lite connections
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]  axil_csr_awaddr;
wire [2:0]                           axil_csr_awprot;
wire                                 axil_csr_awvalid;
wire                                 axil_csr_awready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]  axil_csr_wdata;
wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]  axil_csr_wstrb;
wire                                 axil_csr_wvalid;
wire                                 axil_csr_wready;
wire [1:0]                           axil_csr_bresp;
wire                                 axil_csr_bvalid;
wire                                 axil_csr_bready;
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]  axil_csr_araddr;
wire [2:0]                           axil_csr_arprot;
wire                                 axil_csr_arvalid;
wire                                 axil_csr_arready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]  axil_csr_rdata;
wire [1:0]                           axil_csr_rresp;
wire                                 axil_csr_rvalid;
wire                                 axil_csr_rready;

assign axil_csr_awaddr = s_axil_app_ctrl_awaddr;
assign axil_csr_awprot = s_axil_app_ctrl_awprot;
assign axil_csr_awvalid = s_axil_app_ctrl_awvalid;
assign s_axil_app_ctrl_awready = axil_csr_awready;
assign axil_csr_wdata = s_axil_app_ctrl_wdata;
assign axil_csr_wstrb = s_axil_app_ctrl_wstrb;
assign axil_csr_wvalid = s_axil_app_ctrl_wvalid;
assign s_axil_app_ctrl_wready = axil_csr_wready;
assign s_axil_app_ctrl_bresp = axil_csr_bresp;
assign s_axil_app_ctrl_bvalid = axil_csr_bvalid;
assign axil_csr_bready = s_axil_app_ctrl_bready;
assign axil_csr_araddr = s_axil_app_ctrl_araddr;
assign axil_csr_arprot = s_axil_app_ctrl_arprot;
assign axil_csr_arvalid = s_axil_app_ctrl_arvalid;
assign s_axil_app_ctrl_arready = axil_csr_arready;
assign s_axil_app_ctrl_rdata = axil_csr_rdata;
assign s_axil_app_ctrl_rresp = axil_csr_rresp;
assign s_axil_app_ctrl_rvalid = axil_csr_rvalid;
assign axil_csr_rready = s_axil_app_ctrl_rready;

// control registers
reg axil_csr_awready_reg = 1'b0, axil_csr_awready_next;
reg axil_csr_wready_reg = 1'b0, axil_csr_wready_next;
reg [1:0] axil_csr_bresp_reg = 2'b00, axil_csr_bresp_next;
reg axil_csr_bvalid_reg = 1'b0, axil_csr_bvalid_next;
reg axil_csr_arready_reg = 1'b0, axil_csr_arready_next;
reg [AXIL_APP_CTRL_DATA_WIDTH-1:0] axil_csr_rdata_reg = 0, axil_csr_rdata_next;
reg [1:0] axil_csr_rresp_reg = 2'b00, axil_csr_rresp_next;
reg axil_csr_rvalid_reg = 1'b0, axil_csr_rvalid_next;

reg [63:0] cycle_count_reg = 0;
reg [15:0] dma_read_active_count_reg = 0;
reg [15:0] dma_write_active_count_reg = 0;

reg [DMA_ADDR_WIDTH-1:0] dma_read_desc_dma_addr_reg = 0, dma_read_desc_dma_addr_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_desc_ram_addr_reg = 0, dma_read_desc_ram_addr_next;
reg [DMA_LEN_WIDTH-1:0] dma_read_desc_len_reg = 0, dma_read_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] dma_read_desc_tag_reg = 0, dma_read_desc_tag_next;
reg dma_read_desc_valid_reg = 0, dma_read_desc_valid_next;

reg [DMA_TAG_WIDTH-1:0] dma_read_desc_status_tag_reg = 0, dma_read_desc_status_tag_next;
reg [3:0] dma_read_desc_status_error_reg = 0, dma_read_desc_status_error_next;
reg dma_read_desc_status_valid_reg = 0, dma_read_desc_status_valid_next;

reg [DMA_ADDR_WIDTH-1:0] dma_write_desc_dma_addr_reg = 0, dma_write_desc_dma_addr_next;
reg [RAM_ADDR_IMM_WIDTH-1:0] dma_write_desc_ram_addr_imm_reg = 0, dma_write_desc_ram_addr_imm_next;
reg dma_write_desc_imm_en_reg = 0, dma_write_desc_imm_en_next;
reg [DMA_LEN_WIDTH-1:0] dma_write_desc_len_reg = 0, dma_write_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] dma_write_desc_tag_reg = 0, dma_write_desc_tag_next;
reg dma_write_desc_valid_reg = 0, dma_write_desc_valid_next;

reg [DMA_TAG_WIDTH-1:0] dma_write_desc_status_tag_reg = 0, dma_write_desc_status_tag_next;
reg [3:0] dma_write_desc_status_error_reg = 0, dma_write_desc_status_error_next;
reg dma_write_desc_status_valid_reg = 0, dma_write_desc_status_valid_next;

reg dma_rd_int_en_reg = 0, dma_rd_int_en_next;
reg dma_wr_int_en_reg = 0, dma_wr_int_en_next;

reg dma_read_block_run_reg = 1'b0, dma_read_block_run_next;
reg [DMA_LEN_WIDTH-1:0] dma_read_block_len_reg = 0, dma_read_block_len_next;
reg [31:0] dma_read_block_count_reg = 0, dma_read_block_count_next;
reg [63:0] dma_read_block_cycle_count_reg = 0, dma_read_block_cycle_count_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_base_addr_reg = 0, dma_read_block_dma_base_addr_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_offset_reg = 0, dma_read_block_dma_offset_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_offset_mask_reg = 0, dma_read_block_dma_offset_mask_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_stride_reg = 0, dma_read_block_dma_stride_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_base_addr_reg = 0, dma_read_block_ram_base_addr_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_offset_reg = 0, dma_read_block_ram_offset_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_offset_mask_reg = 0, dma_read_block_ram_offset_mask_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_stride_reg = 0, dma_read_block_ram_stride_next;

reg dma_write_block_run_reg = 1'b0, dma_write_block_run_next;
reg [DMA_LEN_WIDTH-1:0] dma_write_block_len_reg = 0, dma_write_block_len_next;
reg [31:0] dma_write_block_count_reg = 0, dma_write_block_count_next;
reg [63:0] dma_write_block_cycle_count_reg = 0, dma_write_block_cycle_count_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_base_addr_reg = 0, dma_write_block_dma_base_addr_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_offset_reg = 0, dma_write_block_dma_offset_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_offset_mask_reg = 0, dma_write_block_dma_offset_mask_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_stride_reg = 0, dma_write_block_dma_stride_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_base_addr_reg = 0, dma_write_block_ram_base_addr_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_offset_reg = 0, dma_write_block_ram_offset_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_offset_mask_reg = 0, dma_write_block_ram_offset_mask_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_stride_reg = 0, dma_write_block_ram_stride_next;

assign axil_csr_awready = axil_csr_awready_reg;
assign axil_csr_wready = axil_csr_wready_reg;
assign axil_csr_bresp = axil_csr_bresp_reg;
assign axil_csr_bvalid = axil_csr_bvalid_reg;
assign axil_csr_arready = axil_csr_arready_reg;
assign axil_csr_rdata = axil_csr_rdata_reg;
assign axil_csr_rresp = axil_csr_rresp_reg;
assign axil_csr_rvalid = axil_csr_rvalid_reg;

assign m_axis_data_dma_read_desc_dma_addr = dma_read_desc_dma_addr_reg;
assign m_axis_data_dma_read_desc_ram_sel = 0;
assign m_axis_data_dma_read_desc_ram_addr = dma_read_desc_ram_addr_reg;
assign m_axis_data_dma_read_desc_len = dma_read_desc_len_reg;
assign m_axis_data_dma_read_desc_tag = dma_read_desc_tag_reg;
assign m_axis_data_dma_read_desc_valid = dma_read_desc_valid_reg;

assign m_axis_data_dma_write_desc_dma_addr = dma_write_desc_dma_addr_reg;
assign m_axis_data_dma_write_desc_ram_sel = 0;
assign m_axis_data_dma_write_desc_ram_addr = dma_write_desc_ram_addr_imm_reg;
assign m_axis_data_dma_write_desc_imm = dma_write_desc_ram_addr_imm_reg;
assign m_axis_data_dma_write_desc_imm_en = dma_write_desc_imm_en_reg;
assign m_axis_data_dma_write_desc_len = dma_write_desc_len_reg;
assign m_axis_data_dma_write_desc_tag = dma_write_desc_tag_reg;
assign m_axis_data_dma_write_desc_valid = dma_write_desc_valid_reg;

always @* begin
    axil_csr_awready_next = 1'b0;
    axil_csr_wready_next = 1'b0;
    axil_csr_bresp_next = 2'b00;
    axil_csr_bvalid_next = axil_csr_bvalid_reg && !axil_csr_bready;
    axil_csr_arready_next = 1'b0;
    axil_csr_rdata_next = axil_csr_rdata_reg;
    axil_csr_rresp_next = 2'b00;
    axil_csr_rvalid_next = axil_csr_rvalid_reg && !axil_csr_rready;

    dma_read_desc_dma_addr_next = dma_read_desc_dma_addr_reg;
    dma_read_desc_ram_addr_next = dma_read_desc_ram_addr_reg;
    dma_read_desc_len_next = dma_read_desc_len_reg;
    dma_read_desc_tag_next = dma_read_desc_tag_reg;
    dma_read_desc_valid_next = dma_read_desc_valid_reg && !m_axis_data_dma_read_desc_ready;

    dma_read_desc_status_tag_next = dma_read_desc_status_tag_reg;
    dma_read_desc_status_error_next = dma_read_desc_status_error_reg;
    dma_read_desc_status_valid_next = dma_read_desc_status_valid_reg;

    dma_write_desc_dma_addr_next = dma_write_desc_dma_addr_reg;
    dma_write_desc_ram_addr_imm_next = dma_write_desc_ram_addr_imm_reg;
    dma_write_desc_imm_en_next = dma_write_desc_imm_en_reg;
    dma_write_desc_len_next = dma_write_desc_len_reg;
    dma_write_desc_tag_next = dma_write_desc_tag_reg;
    dma_write_desc_valid_next = dma_write_desc_valid_reg && !m_axis_data_dma_write_desc_ready;

    dma_write_desc_status_tag_next = dma_write_desc_status_tag_reg;
    dma_write_desc_status_error_next = dma_write_desc_status_error_reg;
    dma_write_desc_status_valid_next = dma_write_desc_status_valid_reg;

    dma_rd_int_en_next = dma_rd_int_en_reg;
    dma_wr_int_en_next = dma_wr_int_en_reg;

    dma_read_block_run_next = dma_read_block_run_reg;
    dma_read_block_len_next = dma_read_block_len_reg;
    dma_read_block_count_next = dma_read_block_count_reg;
    dma_read_block_cycle_count_next = dma_read_block_cycle_count_reg;
    dma_read_block_dma_base_addr_next = dma_read_block_dma_base_addr_reg;
    dma_read_block_dma_offset_next = dma_read_block_dma_offset_reg;
    dma_read_block_dma_offset_mask_next = dma_read_block_dma_offset_mask_reg;
    dma_read_block_dma_stride_next = dma_read_block_dma_stride_reg;
    dma_read_block_ram_base_addr_next = dma_read_block_ram_base_addr_reg;
    dma_read_block_ram_offset_next = dma_read_block_ram_offset_reg;
    dma_read_block_ram_offset_mask_next = dma_read_block_ram_offset_mask_reg;
    dma_read_block_ram_stride_next = dma_read_block_ram_stride_reg;

    dma_write_block_run_next = dma_write_block_run_reg;
    dma_write_block_len_next = dma_write_block_len_reg;
    dma_write_block_count_next = dma_write_block_count_reg;
    dma_write_block_cycle_count_next = dma_write_block_cycle_count_reg;
    dma_write_block_dma_base_addr_next = dma_write_block_dma_base_addr_reg;
    dma_write_block_dma_offset_next = dma_write_block_dma_offset_reg;
    dma_write_block_dma_offset_mask_next = dma_write_block_dma_offset_mask_reg;
    dma_write_block_dma_stride_next = dma_write_block_dma_stride_reg;
    dma_write_block_ram_base_addr_next = dma_write_block_ram_base_addr_reg;
    dma_write_block_ram_offset_next = dma_write_block_ram_offset_reg;
    dma_write_block_ram_offset_mask_next = dma_write_block_ram_offset_mask_reg;
    dma_write_block_ram_stride_next = dma_write_block_ram_stride_reg;

    if (axil_csr_awvalid && axil_csr_wvalid && !axil_csr_bvalid_reg) begin
        // write operation
        axil_csr_awready_next = 1'b1;
        axil_csr_wready_next = 1'b1;
        axil_csr_bresp_next = 2'b00;
        axil_csr_bvalid_next = 1'b1;

        case ({axil_csr_awaddr[15:2], 2'b00})
            // control
            16'h0000: begin
            end
            16'h0008: begin
                dma_rd_int_en_next = axil_csr_wdata[0];
                dma_wr_int_en_next = axil_csr_wdata[1];
            end
            // single read
            16'h0100: dma_read_desc_dma_addr_next[31:0] = axil_csr_wdata;
            16'h0104: dma_read_desc_dma_addr_next[63:32] = axil_csr_wdata;
            16'h0108: dma_read_desc_ram_addr_next = axil_csr_wdata;
            16'h0110: dma_read_desc_len_next = axil_csr_wdata;
            16'h0114: begin
                dma_read_desc_tag_next = axil_csr_wdata;
                dma_read_desc_valid_next = 1'b1;
            end
            // single write
            16'h0200: dma_write_desc_dma_addr_next[31:0] = axil_csr_wdata;
            16'h0204: dma_write_desc_dma_addr_next[63:32] = axil_csr_wdata;
            16'h0208: dma_write_desc_ram_addr_imm_next = axil_csr_wdata;
            16'h0210: dma_write_desc_len_next = axil_csr_wdata;
            16'h0214: begin
                dma_write_desc_tag_next = axil_csr_wdata[23:0];
                dma_write_desc_imm_en_next = axil_csr_wdata[31];
                dma_write_desc_valid_next = 1'b1;
            end
            // block read
            16'h1000: begin
                dma_read_block_run_next = axil_csr_wdata[0];
            end
            16'h1008: dma_read_block_cycle_count_next[31:0] = axil_csr_wdata;
            16'h100c: dma_read_block_cycle_count_next[63:32] = axil_csr_wdata;
            16'h1010: dma_read_block_len_next = axil_csr_wdata;
            16'h1018: dma_read_block_count_next[31:0] = axil_csr_wdata;
            16'h1080: dma_read_block_dma_base_addr_next[31:0] = axil_csr_wdata;
            16'h1084: dma_read_block_dma_base_addr_next[63:32] = axil_csr_wdata;
            16'h1088: dma_read_block_dma_offset_next[31:0] = axil_csr_wdata;
            16'h108c: dma_read_block_dma_offset_next[63:32] = axil_csr_wdata;
            16'h1090: dma_read_block_dma_offset_mask_next[31:0] = axil_csr_wdata;
            16'h1094: dma_read_block_dma_offset_mask_next[63:32] = axil_csr_wdata;
            16'h1098: dma_read_block_dma_stride_next[31:0] = axil_csr_wdata;
            16'h109c: dma_read_block_dma_stride_next[63:32] = axil_csr_wdata;
            16'h10c0: dma_read_block_ram_base_addr_next = axil_csr_wdata;
            16'h10c8: dma_read_block_ram_offset_next = axil_csr_wdata;
            16'h10d0: dma_read_block_ram_offset_mask_next = axil_csr_wdata;
            16'h10d8: dma_read_block_ram_stride_next = axil_csr_wdata;
            // block write
            16'h1100: begin
                dma_write_block_run_next = axil_csr_wdata[0];
            end
            16'h1108: dma_write_block_cycle_count_next[31:0] = axil_csr_wdata;
            16'h110c: dma_write_block_cycle_count_next[63:32] = axil_csr_wdata;
            16'h1110: dma_write_block_len_next = axil_csr_wdata;
            16'h1118: dma_write_block_count_next[31:0] = axil_csr_wdata;
            16'h1180: dma_write_block_dma_base_addr_next[31:0] = axil_csr_wdata;
            16'h1184: dma_write_block_dma_base_addr_next[63:32] = axil_csr_wdata;
            16'h1188: dma_write_block_dma_offset_next[31:0] = axil_csr_wdata;
            16'h118c: dma_write_block_dma_offset_next[63:32] = axil_csr_wdata;
            16'h1190: dma_write_block_dma_offset_mask_next[31:0] = axil_csr_wdata;
            16'h1194: dma_write_block_dma_offset_mask_next[63:32] = axil_csr_wdata;
            16'h1198: dma_write_block_dma_stride_next[31:0] = axil_csr_wdata;
            16'h119c: dma_write_block_dma_stride_next[63:32] = axil_csr_wdata;
            16'h11c0: dma_write_block_ram_base_addr_next = axil_csr_wdata;
            16'h11c8: dma_write_block_ram_offset_next = axil_csr_wdata;
            16'h11d0: dma_write_block_ram_offset_mask_next = axil_csr_wdata;
            16'h11d8: dma_write_block_ram_stride_next = axil_csr_wdata;
        endcase
    end

    if (axil_csr_arvalid && !axil_csr_rvalid_reg) begin
        // read operation
        axil_csr_arready_next = 1'b1;
        axil_csr_rresp_next = 2'b00;
        axil_csr_rvalid_next = 1'b1;
        axil_csr_rdata_next = 32'd0;

        case ({axil_csr_araddr[15:2], 2'b00})
            // control
            16'h0000: begin
            end
            16'h0008: begin
                axil_csr_rdata_next[0] = dma_rd_int_en_reg;
                axil_csr_rdata_next[1] = dma_wr_int_en_reg;
            end
            16'h0010: axil_csr_rdata_next = cycle_count_reg;
            16'h0014: axil_csr_rdata_next = cycle_count_reg >> 32;
            16'h0020: axil_csr_rdata_next = dma_read_active_count_reg;
            16'h0028: axil_csr_rdata_next = dma_write_active_count_reg;
            // single read
            16'h0100: axil_csr_rdata_next = dma_read_desc_dma_addr_reg;
            16'h0104: axil_csr_rdata_next = dma_read_desc_dma_addr_reg >> 32;
            16'h0108: axil_csr_rdata_next = dma_read_desc_ram_addr_reg;
            16'h010c: axil_csr_rdata_next = dma_read_desc_ram_addr_reg >> 32;
            16'h0110: axil_csr_rdata_next = dma_read_desc_len_reg;
            16'h0114: axil_csr_rdata_next = dma_read_desc_tag_reg;
            16'h0118: begin
                axil_csr_rdata_next[15:0] = dma_read_desc_status_tag_reg;
                axil_csr_rdata_next[27:24] = dma_read_desc_status_error_reg;
                axil_csr_rdata_next[31] = dma_read_desc_status_valid_reg;
                dma_read_desc_status_valid_next = 1'b0;
            end
            // single write
            16'h0200: axil_csr_rdata_next = dma_write_desc_dma_addr_reg;
            16'h0204: axil_csr_rdata_next = dma_write_desc_dma_addr_reg >> 32;
            16'h0208: axil_csr_rdata_next = dma_write_desc_ram_addr_imm_reg;
            16'h020c: axil_csr_rdata_next = dma_write_desc_ram_addr_imm_reg >> 32;
            16'h0210: axil_csr_rdata_next = dma_write_desc_len_reg;
            16'h0214: begin
                axil_csr_rdata_next[23:0] = dma_write_desc_tag_reg;
                axil_csr_rdata_next[31] = dma_write_desc_imm_en_reg;
            end
            16'h0218: begin
                axil_csr_rdata_next[15:0] = dma_write_desc_status_tag_reg;
                axil_csr_rdata_next[27:24] = dma_write_desc_status_error_reg;
                axil_csr_rdata_next[31] = dma_write_desc_status_valid_reg;
                dma_write_desc_status_valid_next = 1'b0;
            end
            // block read
            16'h1000: begin
                axil_csr_rdata_next[0] = dma_read_block_run_reg;
            end
            16'h1008: axil_csr_rdata_next = dma_read_block_cycle_count_reg;
            16'h100c: axil_csr_rdata_next = dma_read_block_cycle_count_reg >> 32;
            16'h1010: axil_csr_rdata_next = dma_read_block_len_reg;
            16'h1018: axil_csr_rdata_next = dma_read_block_count_reg;
            16'h101c: axil_csr_rdata_next = dma_read_block_count_reg >> 32;
            16'h1080: axil_csr_rdata_next = dma_read_block_dma_base_addr_reg;
            16'h1084: axil_csr_rdata_next = dma_read_block_dma_base_addr_reg >> 32;
            16'h1088: axil_csr_rdata_next = dma_read_block_dma_offset_reg;
            16'h108c: axil_csr_rdata_next = dma_read_block_dma_offset_reg >> 32;
            16'h1090: axil_csr_rdata_next = dma_read_block_dma_offset_mask_reg;
            16'h1094: axil_csr_rdata_next = dma_read_block_dma_offset_mask_reg >> 32;
            16'h1098: axil_csr_rdata_next = dma_read_block_dma_stride_reg;
            16'h109c: axil_csr_rdata_next = dma_read_block_dma_stride_reg >> 32;
            16'h10c0: axil_csr_rdata_next = dma_read_block_ram_base_addr_reg;
            16'h10c4: axil_csr_rdata_next = dma_read_block_ram_base_addr_reg >> 32;
            16'h10c8: axil_csr_rdata_next = dma_read_block_ram_offset_reg;
            16'h10cc: axil_csr_rdata_next = dma_read_block_ram_offset_reg >> 32;
            16'h10d0: axil_csr_rdata_next = dma_read_block_ram_offset_mask_reg;
            16'h10d4: axil_csr_rdata_next = dma_read_block_ram_offset_mask_reg >> 32;
            16'h10d8: axil_csr_rdata_next = dma_read_block_ram_stride_reg;
            16'h10dc: axil_csr_rdata_next = dma_read_block_ram_stride_reg >> 32;
            // block write
            16'h1100: begin
                axil_csr_rdata_next[0] = dma_write_block_run_reg;
            end
            16'h1108: axil_csr_rdata_next = dma_write_block_cycle_count_reg;
            16'h110c: axil_csr_rdata_next = dma_write_block_cycle_count_reg >> 32;
            16'h1110: axil_csr_rdata_next = dma_write_block_len_reg;
            16'h1118: axil_csr_rdata_next = dma_write_block_count_reg;
            16'h111c: axil_csr_rdata_next = dma_write_block_count_reg >> 32;
            16'h1180: axil_csr_rdata_next = dma_write_block_dma_base_addr_reg;
            16'h1184: axil_csr_rdata_next = dma_write_block_dma_base_addr_reg >> 32;
            16'h1188: axil_csr_rdata_next = dma_write_block_dma_offset_reg;
            16'h118c: axil_csr_rdata_next = dma_write_block_dma_offset_reg >> 32;
            16'h1190: axil_csr_rdata_next = dma_write_block_dma_offset_mask_reg;
            16'h1194: axil_csr_rdata_next = dma_write_block_dma_offset_mask_reg >> 32;
            16'h1198: axil_csr_rdata_next = dma_write_block_dma_stride_reg;
            16'h119c: axil_csr_rdata_next = dma_write_block_dma_stride_reg >> 32;
            16'h11c0: axil_csr_rdata_next = dma_write_block_ram_base_addr_reg;
            16'h11c4: axil_csr_rdata_next = dma_write_block_ram_base_addr_reg >> 32;
            16'h11c8: axil_csr_rdata_next = dma_write_block_ram_offset_reg;
            16'h11cc: axil_csr_rdata_next = dma_write_block_ram_offset_reg >> 32;
            16'h11d0: axil_csr_rdata_next = dma_write_block_ram_offset_mask_reg;
            16'h11d4: axil_csr_rdata_next = dma_write_block_ram_offset_mask_reg >> 32;
            16'h11d8: axil_csr_rdata_next = dma_write_block_ram_stride_reg;
            16'h11dc: axil_csr_rdata_next = dma_write_block_ram_stride_reg >> 32;
        endcase
    end

    // store read response
    if (s_axis_data_dma_read_desc_status_valid) begin
        dma_read_desc_status_tag_next = s_axis_data_dma_read_desc_status_tag;
        dma_read_desc_status_error_next = s_axis_data_dma_read_desc_status_error;
        dma_read_desc_status_valid_next = s_axis_data_dma_read_desc_status_valid;
    end

    // store write response
    if (s_axis_data_dma_write_desc_status_valid) begin
        dma_write_desc_status_tag_next = s_axis_data_dma_write_desc_status_tag;
        dma_write_desc_status_error_next = s_axis_data_dma_write_desc_status_error;
        dma_write_desc_status_valid_next = s_axis_data_dma_write_desc_status_valid;
    end

    // block read
    if (dma_read_block_run_reg) begin
        dma_read_block_cycle_count_next = dma_read_block_cycle_count_reg + 1;

        if (dma_read_block_count_reg == 0) begin
            if (dma_read_active_count_reg == 0) begin
                dma_read_block_run_next = 1'b0;
            end
        end else begin
            if (!dma_read_desc_valid_reg || m_axis_data_dma_read_desc_ready) begin
                dma_read_block_dma_offset_next = dma_read_block_dma_offset_reg + dma_read_block_dma_stride_reg;
                dma_read_desc_dma_addr_next = dma_read_block_dma_base_addr_reg + (dma_read_block_dma_offset_reg & dma_read_block_dma_offset_mask_reg);
                dma_read_block_ram_offset_next = dma_read_block_ram_offset_reg + dma_read_block_ram_stride_reg;
                dma_read_desc_ram_addr_next = dma_read_block_ram_base_addr_reg + (dma_read_block_ram_offset_reg & dma_read_block_ram_offset_mask_reg);
                dma_read_desc_len_next = dma_read_block_len_reg;
                dma_read_block_count_next = dma_read_block_count_reg - 1;
                dma_read_desc_tag_next = dma_read_block_count_reg;
                dma_read_desc_valid_next = 1'b1;
            end
        end
    end

    // block write
    if (dma_write_block_run_reg) begin
        dma_write_block_cycle_count_next = dma_write_block_cycle_count_reg + 1;

        if (dma_write_block_count_reg == 0) begin
            if (dma_write_active_count_reg == 0) begin
                dma_write_block_run_next = 1'b0;
            end
        end else begin
            if (!dma_write_desc_valid_reg || m_axis_data_dma_write_desc_ready) begin
                dma_write_block_dma_offset_next = dma_write_block_dma_offset_reg + dma_write_block_dma_stride_reg;
                dma_write_desc_dma_addr_next = dma_write_block_dma_base_addr_reg + (dma_write_block_dma_offset_reg & dma_write_block_dma_offset_mask_reg);
                dma_write_block_ram_offset_next = dma_write_block_ram_offset_reg + dma_write_block_ram_stride_reg;
                dma_write_desc_ram_addr_imm_next = dma_write_block_ram_base_addr_reg + (dma_write_block_ram_offset_reg & dma_write_block_ram_offset_mask_reg);
                dma_write_desc_imm_en_next = 1'b0;
                dma_write_desc_len_next = dma_write_block_len_reg;
                dma_write_block_count_next = dma_write_block_count_reg - 1;
                dma_write_desc_tag_next = dma_write_block_count_reg;
                dma_write_desc_valid_next = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    axil_csr_awready_reg <= axil_csr_awready_next;
    axil_csr_wready_reg <= axil_csr_wready_next;
    axil_csr_bresp_reg <= axil_csr_bresp_next;
    axil_csr_bvalid_reg <= axil_csr_bvalid_next;
    axil_csr_arready_reg <= axil_csr_arready_next;
    axil_csr_rdata_reg <= axil_csr_rdata_next;
    axil_csr_rresp_reg <= axil_csr_rresp_next;
    axil_csr_rvalid_reg <= axil_csr_rvalid_next;

    cycle_count_reg <= cycle_count_reg + 1;

    dma_read_active_count_reg <= dma_read_active_count_reg
        + (m_axis_data_dma_read_desc_valid && m_axis_data_dma_read_desc_ready)
        - s_axis_data_dma_read_desc_status_valid;
    dma_write_active_count_reg <= dma_write_active_count_reg
        + (m_axis_data_dma_write_desc_valid && m_axis_data_dma_write_desc_ready)
        - s_axis_data_dma_write_desc_status_valid;

    dma_read_desc_dma_addr_reg <= dma_read_desc_dma_addr_next;
    dma_read_desc_ram_addr_reg <= dma_read_desc_ram_addr_next;
    dma_read_desc_len_reg <= dma_read_desc_len_next;
    dma_read_desc_tag_reg <= dma_read_desc_tag_next;
    dma_read_desc_valid_reg <= dma_read_desc_valid_next;

    dma_read_desc_status_tag_reg <= dma_read_desc_status_tag_next;
    dma_read_desc_status_error_reg <= dma_read_desc_status_error_next;
    dma_read_desc_status_valid_reg <= dma_read_desc_status_valid_next;

    dma_write_desc_dma_addr_reg <= dma_write_desc_dma_addr_next;
    dma_write_desc_ram_addr_imm_reg <= dma_write_desc_ram_addr_imm_next;
    dma_write_desc_imm_en_reg <= dma_write_desc_imm_en_next;
    dma_write_desc_len_reg <= dma_write_desc_len_next;
    dma_write_desc_tag_reg <= dma_write_desc_tag_next;
    dma_write_desc_valid_reg <= dma_write_desc_valid_next;

    dma_write_desc_status_tag_reg <= dma_write_desc_status_tag_next;
    dma_write_desc_status_error_reg <= dma_write_desc_status_error_next;
    dma_write_desc_status_valid_reg <= dma_write_desc_status_valid_next;

    dma_rd_int_en_reg <= dma_rd_int_en_next;
    dma_wr_int_en_reg <= dma_wr_int_en_next;

    dma_read_block_run_reg <= dma_read_block_run_next;
    dma_read_block_len_reg <= dma_read_block_len_next;
    dma_read_block_count_reg <= dma_read_block_count_next;
    dma_read_block_cycle_count_reg <= dma_read_block_cycle_count_next;
    dma_read_block_dma_base_addr_reg <= dma_read_block_dma_base_addr_next;
    dma_read_block_dma_offset_reg <= dma_read_block_dma_offset_next;
    dma_read_block_dma_offset_mask_reg <= dma_read_block_dma_offset_mask_next;
    dma_read_block_dma_stride_reg <= dma_read_block_dma_stride_next;
    dma_read_block_ram_base_addr_reg <= dma_read_block_ram_base_addr_next;
    dma_read_block_ram_offset_reg <= dma_read_block_ram_offset_next;
    dma_read_block_ram_offset_mask_reg <= dma_read_block_ram_offset_mask_next;
    dma_read_block_ram_stride_reg <= dma_read_block_ram_stride_next;

    dma_write_block_run_reg <= dma_write_block_run_next;
    dma_write_block_len_reg <= dma_write_block_len_next;
    dma_write_block_count_reg <= dma_write_block_count_next;
    dma_write_block_cycle_count_reg <= dma_write_block_cycle_count_next;
    dma_write_block_dma_base_addr_reg <= dma_write_block_dma_base_addr_next;
    dma_write_block_dma_offset_reg <= dma_write_block_dma_offset_next;
    dma_write_block_dma_offset_mask_reg <= dma_write_block_dma_offset_mask_next;
    dma_write_block_dma_stride_reg <= dma_write_block_dma_stride_next;
    dma_write_block_ram_base_addr_reg <= dma_write_block_ram_base_addr_next;
    dma_write_block_ram_offset_reg <= dma_write_block_ram_offset_next;
    dma_write_block_ram_offset_mask_reg <= dma_write_block_ram_offset_mask_next;
    dma_write_block_ram_stride_reg <= dma_write_block_ram_stride_next;

    if (rst) begin
        axil_csr_awready_reg <= 1'b0;
        axil_csr_wready_reg <= 1'b0;
        axil_csr_bvalid_reg <= 1'b0;
        axil_csr_arready_reg <= 1'b0;
        axil_csr_rvalid_reg <= 1'b0;

        cycle_count_reg <= 0;
        dma_read_active_count_reg <= 0;
        dma_write_active_count_reg <= 0;

        dma_read_desc_valid_reg <= 1'b0;
        dma_read_desc_status_valid_reg <= 1'b0;
        dma_write_desc_valid_reg <= 1'b0;
        dma_write_desc_status_valid_reg <= 1'b0;
        dma_rd_int_en_reg <= 1'b0;
        dma_wr_int_en_reg <= 1'b0;
        dma_read_block_run_reg <= 1'b0;
        dma_write_block_run_reg <= 1'b0;
    end
end

dma_psdpram #(
    .SIZE(16384),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .PIPELINE(2)
)
dma_ram_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .wr_cmd_be(data_dma_ram_wr_cmd_be),
    .wr_cmd_addr(data_dma_ram_wr_cmd_addr),
    .wr_cmd_data(data_dma_ram_wr_cmd_data),
    .wr_cmd_valid(data_dma_ram_wr_cmd_valid),
    .wr_cmd_ready(data_dma_ram_wr_cmd_ready),
    .wr_done(data_dma_ram_wr_done),

    /*
     * Read port
     */
    .rd_cmd_addr(data_dma_ram_rd_cmd_addr),
    .rd_cmd_valid(data_dma_ram_rd_cmd_valid),
    .rd_cmd_ready(data_dma_ram_rd_cmd_ready),
    .rd_resp_data(data_dma_ram_rd_resp_data),
    .rd_resp_valid(data_dma_ram_rd_resp_valid),
    .rd_resp_ready(data_dma_ram_rd_resp_ready)
);

endmodule

`resetall
