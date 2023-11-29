// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * mqnic core logic
 */
module mqnic_core #
(
    // FW and board IDs
    parameter FPGA_ID = 32'hDEADBEEF,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h1234_0000,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

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
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_SEPARATE_TX_CLOCK = 0,
    parameter PTP_SEPARATE_RX_CLOCK = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter CQ_OP_TABLE_SIZE = 32,
    parameter EQN_WIDTH = 5,
    parameter TX_QUEUE_INDEX_WIDTH = 13,
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter CQN_WIDTH = (TX_QUEUE_INDEX_WIDTH > RX_QUEUE_INDEX_WIDTH ? TX_QUEUE_INDEX_WIDTH : RX_QUEUE_INDEX_WIDTH) + 1,
    parameter EQ_PIPELINE = 3,
    parameter TX_QUEUE_PIPELINE = 3+(TX_QUEUE_INDEX_WIDTH > 12 ? TX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter RX_QUEUE_PIPELINE = 3+(RX_QUEUE_INDEX_WIDTH > 12 ? RX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter CQ_PIPELINE = 3+(CQN_WIDTH > 12 ? CQN_WIDTH-12 : 0),

    // TX and RX engine configuration
    parameter TX_DESC_TABLE_SIZE = 32,
    parameter RX_DESC_TABLE_SIZE = 32,
    parameter RX_INDIR_TBL_ADDR_WIDTH = RX_QUEUE_INDEX_WIDTH > 8 ? 8 : RX_QUEUE_INDEX_WIDTH,

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
    parameter PFC_ENABLE = 1,
    parameter LFC_ENABLE = PFC_ENABLE,
    parameter MAC_CTRL_ENABLE = 0,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 32768,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 32768,
    parameter RX_RAM_SIZE = 32768,

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

    // Application block configuration
    parameter APP_ID = 32'h00000000,
    parameter APP_ENABLE = 0,
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
    parameter IF_RAM_SEL_WIDTH = 1,
    parameter RAM_SEL_WIDTH = $clog2(IF_COUNT+(APP_ENABLE && APP_DMA_ENABLE ? 1 : 0))+IF_RAM_SEL_WIDTH+1,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
    parameter RAM_PIPELINE = 2,

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = EQN_WIDTH,
    parameter MSIX_ENABLE = 0,
    parameter AXIL_MSIX_ADDR_WIDTH = 16,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 16,
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),
    parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT),
    parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((SCHED_PER_IF+4+7)/8),
    parameter AXIL_CSR_PASSTHROUGH_ENABLE = 0,
    parameter RB_NEXT_PTR = 0,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 16,
    parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8),

    // Ethernet interface configuration
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_IF_DATA_WIDTH = AXIS_SYNC_DATA_WIDTH*2**$clog2(PORTS_PER_IF),
    parameter AXIS_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_RX_USE_READY = 0,
    parameter AXIS_TX_PIPELINE = 0,
    parameter AXIS_TX_FIFO_PIPELINE = 2,
    parameter AXIS_TX_TS_PIPELINE = 0,
    parameter AXIS_RX_PIPELINE = 0,
    parameter AXIS_RX_FIFO_PIPELINE = 2,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI-Lite slave interface (control)
     */
    input  wire [AXIL_CTRL_ADDR_WIDTH-1:0]              s_axil_ctrl_awaddr,
    input  wire [2:0]                                   s_axil_ctrl_awprot,
    input  wire                                         s_axil_ctrl_awvalid,
    output wire                                         s_axil_ctrl_awready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]              s_axil_ctrl_wdata,
    input  wire [AXIL_CTRL_STRB_WIDTH-1:0]              s_axil_ctrl_wstrb,
    input  wire                                         s_axil_ctrl_wvalid,
    output wire                                         s_axil_ctrl_wready,
    output wire [1:0]                                   s_axil_ctrl_bresp,
    output wire                                         s_axil_ctrl_bvalid,
    input  wire                                         s_axil_ctrl_bready,
    input  wire [AXIL_CTRL_ADDR_WIDTH-1:0]              s_axil_ctrl_araddr,
    input  wire [2:0]                                   s_axil_ctrl_arprot,
    input  wire                                         s_axil_ctrl_arvalid,
    output wire                                         s_axil_ctrl_arready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]              s_axil_ctrl_rdata,
    output wire [1:0]                                   s_axil_ctrl_rresp,
    output wire                                         s_axil_ctrl_rvalid,
    input  wire                                         s_axil_ctrl_rready,

    /*
     * AXI-Lite slave interface (application control)
     */
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]          s_axil_app_ctrl_awaddr,
    input  wire [2:0]                                   s_axil_app_ctrl_awprot,
    input  wire                                         s_axil_app_ctrl_awvalid,
    output wire                                         s_axil_app_ctrl_awready,
    input  wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]          s_axil_app_ctrl_wdata,
    input  wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]          s_axil_app_ctrl_wstrb,
    input  wire                                         s_axil_app_ctrl_wvalid,
    output wire                                         s_axil_app_ctrl_wready,
    output wire [1:0]                                   s_axil_app_ctrl_bresp,
    output wire                                         s_axil_app_ctrl_bvalid,
    input  wire                                         s_axil_app_ctrl_bready,
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]          s_axil_app_ctrl_araddr,
    input  wire [2:0]                                   s_axil_app_ctrl_arprot,
    input  wire                                         s_axil_app_ctrl_arvalid,
    output wire                                         s_axil_app_ctrl_arready,
    output wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]          s_axil_app_ctrl_rdata,
    output wire [1:0]                                   s_axil_app_ctrl_rresp,
    output wire                                         s_axil_app_ctrl_rvalid,
    input  wire                                         s_axil_app_ctrl_rready,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               m_axil_csr_awaddr,
    output wire [2:0]                                   m_axil_csr_awprot,
    output wire                                         m_axil_csr_awvalid,
    input  wire                                         m_axil_csr_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]              m_axil_csr_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]              m_axil_csr_wstrb,
    output wire                                         m_axil_csr_wvalid,
    input  wire                                         m_axil_csr_wready,
    input  wire [1:0]                                   m_axil_csr_bresp,
    input  wire                                         m_axil_csr_bvalid,
    output wire                                         m_axil_csr_bready,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               m_axil_csr_araddr,
    output wire [2:0]                                   m_axil_csr_arprot,
    output wire                                         m_axil_csr_arvalid,
    input  wire                                         m_axil_csr_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]              m_axil_csr_rdata,
    input  wire [1:0]                                   m_axil_csr_rresp,
    input  wire                                         m_axil_csr_rvalid,
    output wire                                         m_axil_csr_rready,

    /*
     * AXI-Lite master interface (MSI-X)
     */
    output wire [AXIL_MSIX_ADDR_WIDTH-1:0]              m_axil_msix_awaddr,
    output wire [2:0]                                   m_axil_msix_awprot,
    output wire                                         m_axil_msix_awvalid,
    input  wire                                         m_axil_msix_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]              m_axil_msix_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]              m_axil_msix_wstrb,
    output wire                                         m_axil_msix_wvalid,
    input  wire                                         m_axil_msix_wready,
    input  wire [1:0]                                   m_axil_msix_bresp,
    input  wire                                         m_axil_msix_bvalid,
    output wire                                         m_axil_msix_bready,
    output wire [AXIL_MSIX_ADDR_WIDTH-1:0]              m_axil_msix_araddr,
    output wire [2:0]                                   m_axil_msix_arprot,
    output wire                                         m_axil_msix_arvalid,
    input  wire                                         m_axil_msix_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]              m_axil_msix_rdata,
    input  wire [1:0]                                   m_axil_msix_rresp,
    input  wire                                         m_axil_msix_rvalid,
    output wire                                         m_axil_msix_rready,

    /*
     * Control register interface
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               ctrl_reg_wr_addr,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]              ctrl_reg_wr_data,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]              ctrl_reg_wr_strb,
    output wire                                         ctrl_reg_wr_en,
    input  wire                                         ctrl_reg_wr_wait,
    input  wire                                         ctrl_reg_wr_ack,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               ctrl_reg_rd_addr,
    output wire                                         ctrl_reg_rd_en,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]              ctrl_reg_rd_data,
    input  wire                                         ctrl_reg_rd_wait,
    input  wire                                         ctrl_reg_rd_ack,

    /*
     * DMA read descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_read_desc_tag,
    output wire                                         m_axis_dma_read_desc_valid,
    input  wire                                         m_axis_dma_read_desc_ready,

    /*
     * DMA read descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_read_desc_status_error,
    input  wire                                         s_axis_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                     m_axis_dma_write_desc_imm,
    output wire                                         m_axis_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_write_desc_tag,
    output wire                                         m_axis_dma_write_desc_valid,
    input  wire                                         m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_write_desc_status_error,
    input  wire                                         s_axis_dma_write_desc_status_valid,

    /*
     * DMA RAM interface
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_ready,

    /*
     * Interrupt request output
     */
    output wire [IRQ_INDEX_WIDTH-1:0]                   irq_index,
    output wire                                         irq_valid,
    input  wire                                         irq_ready,

    /*
     * PTP clock
     */
    input  wire                                         ptp_clk,
    input  wire                                         ptp_rst,
    input  wire                                         ptp_sample_clk,
    output wire                                         ptp_td_sd,
    output wire                                         ptp_pps,
    output wire                                         ptp_pps_str,
    output wire                                         ptp_sync_locked,
    output wire [63:0]                                  ptp_sync_ts_rel,
    output wire                                         ptp_sync_ts_rel_step,
    output wire [96:0]                                  ptp_sync_ts_tod,
    output wire                                         ptp_sync_ts_tod_step,
    output wire                                         ptp_sync_pps,
    output wire                                         ptp_sync_pps_str,
    output wire [PTP_PEROUT_COUNT-1:0]                  ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]                  ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]                  ptp_perout_pulse,

    /*
     * Ethernet
     */
    input  wire [PORT_COUNT-1:0]                        tx_clk,
    input  wire [PORT_COUNT-1:0]                        tx_rst,

    input  wire [PORT_COUNT-1:0]                        tx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                        tx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           tx_ptp_ts_tod,
    output wire [PORT_COUNT-1:0]                        tx_ptp_ts_tod_step,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        m_axis_tx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        m_axis_tx_tkeep,
    output wire [PORT_COUNT-1:0]                        m_axis_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                        m_axis_tx_tready,
    output wire [PORT_COUNT-1:0]                        m_axis_tx_tlast,
    output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]     m_axis_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           s_axis_tx_cpl_ts,
    input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]           s_axis_tx_cpl_tag,
    input  wire [PORT_COUNT-1:0]                        s_axis_tx_cpl_valid,
    output wire [PORT_COUNT-1:0]                        s_axis_tx_cpl_ready,

    output wire [PORT_COUNT-1:0]                        tx_enable,
    input  wire [PORT_COUNT-1:0]                        tx_status,
    output wire [PORT_COUNT-1:0]                        tx_lfc_en,
    output wire [PORT_COUNT-1:0]                        tx_lfc_req,
    output wire [PORT_COUNT*8-1:0]                      tx_pfc_en,
    output wire [PORT_COUNT*8-1:0]                      tx_pfc_req,
    input  wire [PORT_COUNT-1:0]                        tx_fc_quanta_clk_en,

    input  wire [PORT_COUNT-1:0]                        rx_clk,
    input  wire [PORT_COUNT-1:0]                        rx_rst,

    input  wire [PORT_COUNT-1:0]                        rx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                        rx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           rx_ptp_ts_tod,
    output wire [PORT_COUNT-1:0]                        rx_ptp_ts_tod_step,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        s_axis_rx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        s_axis_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                        s_axis_rx_tvalid,
    output wire [PORT_COUNT-1:0]                        s_axis_rx_tready,
    input  wire [PORT_COUNT-1:0]                        s_axis_rx_tlast,
    input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]     s_axis_rx_tuser,

    output wire [PORT_COUNT-1:0]                        rx_enable,
    input  wire [PORT_COUNT-1:0]                        rx_status,
    output wire [PORT_COUNT-1:0]                        rx_lfc_en,
    input  wire [PORT_COUNT-1:0]                        rx_lfc_req,
    output wire [PORT_COUNT-1:0]                        rx_lfc_ack,
    output wire [PORT_COUNT*8-1:0]                      rx_pfc_en,
    input  wire [PORT_COUNT*8-1:0]                      rx_pfc_req,
    output wire [PORT_COUNT*8-1:0]                      rx_pfc_ack,
    input  wire [PORT_COUNT-1:0]                        rx_fc_quanta_clk_en,

    /*
     * DDR
     */
    input  wire [DDR_CH-1:0]                            ddr_clk,
    input  wire [DDR_CH-1:0]                            ddr_rst,

    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           m_axi_ddr_awid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]         m_axi_ddr_awaddr,
    output wire [DDR_CH*8-1:0]                          m_axi_ddr_awlen,
    output wire [DDR_CH*3-1:0]                          m_axi_ddr_awsize,
    output wire [DDR_CH*2-1:0]                          m_axi_ddr_awburst,
    output wire [DDR_CH-1:0]                            m_axi_ddr_awlock,
    output wire [DDR_CH*4-1:0]                          m_axi_ddr_awcache,
    output wire [DDR_CH*3-1:0]                          m_axi_ddr_awprot,
    output wire [DDR_CH*4-1:0]                          m_axi_ddr_awqos,
    output wire [DDR_CH*AXI_DDR_AWUSER_WIDTH-1:0]       m_axi_ddr_awuser,
    output wire [DDR_CH-1:0]                            m_axi_ddr_awvalid,
    input  wire [DDR_CH-1:0]                            m_axi_ddr_awready,
    output wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]         m_axi_ddr_wdata,
    output wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]         m_axi_ddr_wstrb,
    output wire [DDR_CH-1:0]                            m_axi_ddr_wlast,
    output wire [DDR_CH*AXI_DDR_WUSER_WIDTH-1:0]        m_axi_ddr_wuser,
    output wire [DDR_CH-1:0]                            m_axi_ddr_wvalid,
    input  wire [DDR_CH-1:0]                            m_axi_ddr_wready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           m_axi_ddr_bid,
    input  wire [DDR_CH*2-1:0]                          m_axi_ddr_bresp,
    input  wire [DDR_CH*AXI_DDR_BUSER_WIDTH-1:0]        m_axi_ddr_buser,
    input  wire [DDR_CH-1:0]                            m_axi_ddr_bvalid,
    output wire [DDR_CH-1:0]                            m_axi_ddr_bready,
    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           m_axi_ddr_arid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]         m_axi_ddr_araddr,
    output wire [DDR_CH*8-1:0]                          m_axi_ddr_arlen,
    output wire [DDR_CH*3-1:0]                          m_axi_ddr_arsize,
    output wire [DDR_CH*2-1:0]                          m_axi_ddr_arburst,
    output wire [DDR_CH-1:0]                            m_axi_ddr_arlock,
    output wire [DDR_CH*4-1:0]                          m_axi_ddr_arcache,
    output wire [DDR_CH*3-1:0]                          m_axi_ddr_arprot,
    output wire [DDR_CH*4-1:0]                          m_axi_ddr_arqos,
    output wire [DDR_CH*AXI_DDR_ARUSER_WIDTH-1:0]       m_axi_ddr_aruser,
    output wire [DDR_CH-1:0]                            m_axi_ddr_arvalid,
    input  wire [DDR_CH-1:0]                            m_axi_ddr_arready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           m_axi_ddr_rid,
    input  wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]         m_axi_ddr_rdata,
    input  wire [DDR_CH*2-1:0]                          m_axi_ddr_rresp,
    input  wire [DDR_CH-1:0]                            m_axi_ddr_rlast,
    input  wire [DDR_CH*AXI_DDR_RUSER_WIDTH-1:0]        m_axi_ddr_ruser,
    input  wire [DDR_CH-1:0]                            m_axi_ddr_rvalid,
    output wire [DDR_CH-1:0]                            m_axi_ddr_rready,

    input  wire [DDR_CH-1:0]                            ddr_status,

    /*
     * HBM
     */
    input  wire [HBM_CH-1:0]                            hbm_clk,
    input  wire [HBM_CH-1:0]                            hbm_rst,

    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           m_axi_hbm_awid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]         m_axi_hbm_awaddr,
    output wire [HBM_CH*8-1:0]                          m_axi_hbm_awlen,
    output wire [HBM_CH*3-1:0]                          m_axi_hbm_awsize,
    output wire [HBM_CH*2-1:0]                          m_axi_hbm_awburst,
    output wire [HBM_CH-1:0]                            m_axi_hbm_awlock,
    output wire [HBM_CH*4-1:0]                          m_axi_hbm_awcache,
    output wire [HBM_CH*3-1:0]                          m_axi_hbm_awprot,
    output wire [HBM_CH*4-1:0]                          m_axi_hbm_awqos,
    output wire [HBM_CH*AXI_HBM_AWUSER_WIDTH-1:0]       m_axi_hbm_awuser,
    output wire [HBM_CH-1:0]                            m_axi_hbm_awvalid,
    input  wire [HBM_CH-1:0]                            m_axi_hbm_awready,
    output wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]         m_axi_hbm_wdata,
    output wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]         m_axi_hbm_wstrb,
    output wire [HBM_CH-1:0]                            m_axi_hbm_wlast,
    output wire [HBM_CH*AXI_HBM_WUSER_WIDTH-1:0]        m_axi_hbm_wuser,
    output wire [HBM_CH-1:0]                            m_axi_hbm_wvalid,
    input  wire [HBM_CH-1:0]                            m_axi_hbm_wready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           m_axi_hbm_bid,
    input  wire [HBM_CH*2-1:0]                          m_axi_hbm_bresp,
    input  wire [HBM_CH*AXI_HBM_BUSER_WIDTH-1:0]        m_axi_hbm_buser,
    input  wire [HBM_CH-1:0]                            m_axi_hbm_bvalid,
    output wire [HBM_CH-1:0]                            m_axi_hbm_bready,
    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           m_axi_hbm_arid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]         m_axi_hbm_araddr,
    output wire [HBM_CH*8-1:0]                          m_axi_hbm_arlen,
    output wire [HBM_CH*3-1:0]                          m_axi_hbm_arsize,
    output wire [HBM_CH*2-1:0]                          m_axi_hbm_arburst,
    output wire [HBM_CH-1:0]                            m_axi_hbm_arlock,
    output wire [HBM_CH*4-1:0]                          m_axi_hbm_arcache,
    output wire [HBM_CH*3-1:0]                          m_axi_hbm_arprot,
    output wire [HBM_CH*4-1:0]                          m_axi_hbm_arqos,
    output wire [HBM_CH*AXI_HBM_ARUSER_WIDTH-1:0]       m_axi_hbm_aruser,
    output wire [HBM_CH-1:0]                            m_axi_hbm_arvalid,
    input  wire [HBM_CH-1:0]                            m_axi_hbm_arready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           m_axi_hbm_rid,
    input  wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]         m_axi_hbm_rdata,
    input  wire [HBM_CH*2-1:0]                          m_axi_hbm_rresp,
    input  wire [HBM_CH-1:0]                            m_axi_hbm_rlast,
    input  wire [HBM_CH*AXI_HBM_RUSER_WIDTH-1:0]        m_axi_hbm_ruser,
    input  wire [HBM_CH-1:0]                            m_axi_hbm_rvalid,
    output wire [HBM_CH-1:0]                            m_axi_hbm_rready,

    input  wire [HBM_CH-1:0]                            hbm_status,

    /*
     * Statistics increment input
     */
    input  wire [STAT_INC_WIDTH-1:0]                    s_axis_stat_tdata,
    input  wire [STAT_ID_WIDTH-1:0]                     s_axis_stat_tid,
    input  wire                                         s_axis_stat_tvalid,
    output wire                                         s_axis_stat_tready,

    /*
     * GPIO
     */
    input  wire [APP_GPIO_IN_WIDTH-1:0]                 app_gpio_in,
    output wire [APP_GPIO_OUT_WIDTH-1:0]                app_gpio_out,

    /*
     * JTAG
     */
    input  wire                                         app_jtag_tdi,
    output wire                                         app_jtag_tdo,
    input  wire                                         app_jtag_tms,
    input  wire                                         app_jtag_tck
);

parameter IF_COUNT_INT = IF_COUNT+(APP_ENABLE && APP_DMA_ENABLE ? 1 : 0);

parameter IF_DMA_TAG_WIDTH = DMA_TAG_WIDTH-$clog2(IF_COUNT_INT)-1;

parameter AXIS_TX_ID_WIDTH = TX_QUEUE_INDEX_WIDTH;
parameter AXIS_TX_DEST_WIDTH = 4;
parameter AXIS_RX_DEST_WIDTH = RX_QUEUE_INDEX_WIDTH+1;

parameter AXIS_SYNC_KEEP_WIDTH = AXIS_SYNC_DATA_WIDTH/(AXIS_DATA_WIDTH/AXIS_KEEP_WIDTH);

parameter AXIS_IF_KEEP_WIDTH = AXIS_IF_DATA_WIDTH/(AXIS_DATA_WIDTH/AXIS_KEEP_WIDTH);

parameter AXIS_IF_TX_ID_WIDTH = AXIS_TX_ID_WIDTH;
parameter AXIS_IF_RX_ID_WIDTH = PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1;
parameter AXIS_IF_TX_DEST_WIDTH = $clog2(PORTS_PER_IF)+AXIS_TX_DEST_WIDTH;
parameter AXIS_IF_RX_DEST_WIDTH = AXIS_RX_DEST_WIDTH;
parameter AXIS_IF_TX_USER_WIDTH = AXIS_TX_USER_WIDTH;
parameter AXIS_IF_RX_USER_WIDTH = AXIS_RX_USER_WIDTH;

localparam CLK_CYCLES_PER_US = (1000*CLK_PERIOD_NS_DENOM)/CLK_PERIOD_NS_NUM;

localparam PHC_RB_BASE_ADDR = 32'h100;
localparam CLK_RB_BASE_ADDR = PHC_RB_BASE_ADDR + 32'h100;

genvar m, n;

// check configuration
initial begin
    if (RB_NEXT_PTR > 0 && RB_NEXT_PTR < 16'h200) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end
end

// parameter sizing helpers
function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

// AXI lite connections
wire [AXIL_CSR_ADDR_WIDTH-1:0]   axil_csr_awaddr;
wire [2:0]                       axil_csr_awprot;
wire                             axil_csr_awvalid;
wire                             axil_csr_awready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_csr_wdata;
wire [AXIL_CTRL_STRB_WIDTH-1:0]  axil_csr_wstrb;
wire                             axil_csr_wvalid;
wire                             axil_csr_wready;
wire [1:0]                       axil_csr_bresp;
wire                             axil_csr_bvalid;
wire                             axil_csr_bready;
wire [AXIL_CSR_ADDR_WIDTH-1:0]   axil_csr_araddr;
wire [2:0]                       axil_csr_arprot;
wire                             axil_csr_arvalid;
wire                             axil_csr_arready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_csr_rdata;
wire [1:0]                       axil_csr_rresp;
wire                             axil_csr_rvalid;
wire                             axil_csr_rready;

wire [AXIL_CSR_ADDR_WIDTH-1:0]   axil_stats_awaddr;
wire [2:0]                       axil_stats_awprot;
wire                             axil_stats_awvalid;
wire                             axil_stats_awready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_stats_wdata;
wire [AXIL_CTRL_STRB_WIDTH-1:0]  axil_stats_wstrb;
wire                             axil_stats_wvalid;
wire                             axil_stats_wready;
wire [1:0]                       axil_stats_bresp;
wire                             axil_stats_bvalid;
wire                             axil_stats_bready;
wire [AXIL_CSR_ADDR_WIDTH-1:0]   axil_stats_araddr;
wire [2:0]                       axil_stats_arprot;
wire                             axil_stats_arvalid;
wire                             axil_stats_arready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_stats_rdata;
wire [1:0]                       axil_stats_rresp;
wire                             axil_stats_rvalid;
wire                             axil_stats_rready;

wire [AXIL_CTRL_ADDR_WIDTH-1:0]  axil_ctrl_app_awaddr;
wire [2:0]                       axil_ctrl_app_awprot;
wire                             axil_ctrl_app_awvalid;
wire                             axil_ctrl_app_awready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_ctrl_app_wdata;
wire [AXIL_CTRL_STRB_WIDTH-1:0]  axil_ctrl_app_wstrb;
wire                             axil_ctrl_app_wvalid;
wire                             axil_ctrl_app_wready;
wire [1:0]                       axil_ctrl_app_bresp;
wire                             axil_ctrl_app_bvalid;
wire                             axil_ctrl_app_bready;
wire [AXIL_CTRL_ADDR_WIDTH-1:0]  axil_ctrl_app_araddr;
wire [2:0]                       axil_ctrl_app_arprot;
wire                             axil_ctrl_app_arvalid;
wire                             axil_ctrl_app_arready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_ctrl_app_rdata;
wire [1:0]                       axil_ctrl_app_rresp;
wire                             axil_ctrl_app_rvalid;
wire                             axil_ctrl_app_rready;

// control registers
wire ctrl_reg_wr_wait_int;
wire ctrl_reg_wr_ack_int;
wire [AXIL_CTRL_DATA_WIDTH-1:0] ctrl_reg_rd_data_int;
wire ctrl_reg_rd_wait_int;
wire ctrl_reg_rd_ack_int;

axil_reg_if #(
    .DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .TIMEOUT(4)
)
axil_reg_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_csr_awaddr),
    .s_axil_awprot(axil_csr_awprot),
    .s_axil_awvalid(axil_csr_awvalid),
    .s_axil_awready(axil_csr_awready),
    .s_axil_wdata(axil_csr_wdata),
    .s_axil_wstrb(axil_csr_wstrb),
    .s_axil_wvalid(axil_csr_wvalid),
    .s_axil_wready(axil_csr_wready),
    .s_axil_bresp(axil_csr_bresp),
    .s_axil_bvalid(axil_csr_bvalid),
    .s_axil_bready(axil_csr_bready),
    .s_axil_araddr(axil_csr_araddr),
    .s_axil_arprot(axil_csr_arprot),
    .s_axil_arvalid(axil_csr_arvalid),
    .s_axil_arready(axil_csr_arready),
    .s_axil_rdata(axil_csr_rdata),
    .s_axil_rresp(axil_csr_rresp),
    .s_axil_rvalid(axil_csr_rvalid),
    .s_axil_rready(axil_csr_rready),

    /*
     * Register interface
     */
    .reg_wr_addr(ctrl_reg_wr_addr),
    .reg_wr_data(ctrl_reg_wr_data),
    .reg_wr_strb(ctrl_reg_wr_strb),
    .reg_wr_en(ctrl_reg_wr_en),
    .reg_wr_wait(ctrl_reg_wr_wait_int),
    .reg_wr_ack(ctrl_reg_wr_ack_int),
    .reg_rd_addr(ctrl_reg_rd_addr),
    .reg_rd_en(ctrl_reg_rd_en),
    .reg_rd_data(ctrl_reg_rd_data_int),
    .reg_rd_wait(ctrl_reg_rd_wait_int),
    .reg_rd_ack(ctrl_reg_rd_ack_int)
);

wire ptp_ctrl_reg_wr_wait;
wire ptp_ctrl_reg_wr_ack;
wire [AXIL_CTRL_DATA_WIDTH-1:0] ptp_ctrl_reg_rd_data;
wire ptp_ctrl_reg_rd_wait;
wire ptp_ctrl_reg_rd_ack;

wire clk_ctrl_reg_wr_wait;
wire clk_ctrl_reg_wr_ack;
wire [AXIL_CTRL_DATA_WIDTH-1:0] clk_ctrl_reg_rd_data;
wire clk_ctrl_reg_rd_wait;
wire clk_ctrl_reg_rd_ack;

reg ctrl_reg_wr_ack_reg = 1'b0;
reg [AXIL_CTRL_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = {AXIL_CTRL_DATA_WIDTH{1'b0}};
reg ctrl_reg_rd_ack_reg = 1'b0;

reg [15:0] irq_rate_limit_min_interval_reg = 10;

assign ctrl_reg_wr_wait_int = ctrl_reg_wr_wait | ptp_ctrl_reg_wr_wait | clk_ctrl_reg_wr_wait;
assign ctrl_reg_wr_ack_int = ctrl_reg_wr_ack | ctrl_reg_wr_ack_reg | ptp_ctrl_reg_wr_ack | clk_ctrl_reg_wr_ack;
assign ctrl_reg_rd_data_int = ctrl_reg_rd_data | ctrl_reg_rd_data_reg | ptp_ctrl_reg_rd_data | clk_ctrl_reg_rd_data;
assign ctrl_reg_rd_wait_int = ctrl_reg_rd_wait | ptp_ctrl_reg_rd_wait | clk_ctrl_reg_rd_wait;
assign ctrl_reg_rd_ack_int = ctrl_reg_rd_ack | ctrl_reg_rd_ack_reg | ptp_ctrl_reg_rd_ack | clk_ctrl_reg_rd_ack;

always @(posedge clk) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_CTRL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b0;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            // IRQ configuration
            8'h4C: irq_rate_limit_min_interval_reg <= ctrl_reg_wr_data;  // IRQ config: Min interval
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            // FW ID
            8'h00: ctrl_reg_rd_data_reg <= 32'hffffffff;  // FW ID: Type
            8'h04: ctrl_reg_rd_data_reg <= 32'h00000100;  // FW ID: Version
            8'h08: ctrl_reg_rd_data_reg <= 32'h40;        // FW ID: Next header
            8'h0C: ctrl_reg_rd_data_reg <= FPGA_ID;       // FW ID: FPGA JTAG ID
            8'h10: ctrl_reg_rd_data_reg <= FW_ID;         // FW ID: Firmware ID
            8'h14: ctrl_reg_rd_data_reg <= FW_VER;        // FW ID: Firmware version
            8'h18: ctrl_reg_rd_data_reg <= BOARD_ID;      // FW ID: Board ID
            8'h1C: ctrl_reg_rd_data_reg <= BOARD_VER;     // FW ID: Board version
            8'h20: ctrl_reg_rd_data_reg <= BUILD_DATE;    // FW ID: Build date
            8'h24: ctrl_reg_rd_data_reg <= GIT_HASH;      // FW ID: Git commit hash
            8'h28: ctrl_reg_rd_data_reg <= RELEASE_INFO;  // FW ID: Release info
            // IRQ configuration
            8'h40: ctrl_reg_rd_data_reg <= 32'h0000C007;  // IRQ config: Type
            8'h44: ctrl_reg_rd_data_reg <= 32'h00000100;  // IRQ config: Version
            8'h48: ctrl_reg_rd_data_reg <= 32'h50;        // IRQ config: Next header
            8'h4C: ctrl_reg_rd_data_reg <= irq_rate_limit_min_interval_reg;  // IRQ config: Min interval
            // Interface
            8'h50: ctrl_reg_rd_data_reg <= 32'h0000C000;  // Interface: Type
            8'h54: ctrl_reg_rd_data_reg <= 32'h00000100;  // Interface: Version
            8'h58: ctrl_reg_rd_data_reg <= 32'h70;        // Interface: Next header
            8'h5C: ctrl_reg_rd_data_reg <= 32'h0;         // Interface: Offset
            8'h60: ctrl_reg_rd_data_reg <= IF_COUNT;      // Interface: Count
            8'h64: ctrl_reg_rd_data_reg <= 2**AXIL_IF_CTRL_ADDR_WIDTH;  // Interface: Stride
            8'h68: ctrl_reg_rd_data_reg <= 2**AXIL_CSR_ADDR_WIDTH;      // Interface: CSR offset
            // App info
            8'h70: ctrl_reg_rd_data_reg <= APP_ENABLE ? 32'h0000C005 : 0;  // App info: Type
            8'h74: ctrl_reg_rd_data_reg <= APP_ENABLE ? 32'h00000200 : 0;  // App info: Version
            8'h78: ctrl_reg_rd_data_reg <= 32'h80;                         // App info: Next header
            8'h7C: ctrl_reg_rd_data_reg <= APP_ENABLE ? APP_ID : 0;        // App info: ID
            // Stats
            8'h80: ctrl_reg_rd_data_reg <= STAT_ENABLE ? 32'h0000C006 : 0;      // Stats: Type
            8'h84: ctrl_reg_rd_data_reg <= STAT_ENABLE ? 32'h00000100 : 0;      // Stats: Version
            8'h88: ctrl_reg_rd_data_reg <= PHC_RB_BASE_ADDR;                    // Stats: Next header
            8'h8C: ctrl_reg_rd_data_reg <= STAT_ENABLE ? (MSIX_ENABLE ? 2 : 1)*2**16 : 0;  // Stats: Offset
            8'h90: ctrl_reg_rd_data_reg <= STAT_ENABLE ? 2**STAT_ID_WIDTH : 0;  // Stats: Count
            8'h94: ctrl_reg_rd_data_reg <= STAT_ENABLE ? 8 : 0;                 // Stats: Stride
            8'h98: ctrl_reg_rd_data_reg <= STAT_ENABLE ? 32'h00000000 : 0;      // Stats: Flags
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        irq_rate_limit_min_interval_reg <= 10;
    end
end

mqnic_ptp #(
    .PTP_CLK_PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
    .PTP_CLK_PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM),
    .PTP_CLOCK_CDC_PIPELINE(PTP_CLOCK_CDC_PIPELINE),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),
    .REG_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .REG_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .REG_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .RB_BASE_ADDR(PHC_RB_BASE_ADDR),
    .RB_NEXT_PTR(CLK_RB_BASE_ADDR)
)
mqnic_ptp_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Register interface
     */
    .reg_wr_addr(ctrl_reg_wr_addr),
    .reg_wr_data(ctrl_reg_wr_data),
    .reg_wr_strb(ctrl_reg_wr_strb),
    .reg_wr_en(ctrl_reg_wr_en),
    .reg_wr_wait(ptp_ctrl_reg_wr_wait),
    .reg_wr_ack(ptp_ctrl_reg_wr_ack),
    .reg_rd_addr(ctrl_reg_rd_addr),
    .reg_rd_en(ctrl_reg_rd_en),
    .reg_rd_data(ptp_ctrl_reg_rd_data),
    .reg_rd_wait(ptp_ctrl_reg_rd_wait),
    .reg_rd_ack(ptp_ctrl_reg_rd_ack),

    /*
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sd(ptp_td_sd),
    .ptp_pps(ptp_pps),
    .ptp_pps_str(ptp_pps_str),
    .ptp_sync_locked(ptp_sync_locked),
    .ptp_sync_ts_rel(ptp_sync_ts_rel),
    .ptp_sync_ts_rel_step(ptp_sync_ts_rel_step),
    .ptp_sync_ts_tod(ptp_sync_ts_tod),
    .ptp_sync_ts_tod_step(ptp_sync_ts_tod_step),
    .ptp_sync_pps(ptp_sync_pps),
    .ptp_sync_pps_str(ptp_sync_pps_str),
    .ptp_perout_locked(ptp_perout_locked),
    .ptp_perout_error(ptp_perout_error),
    .ptp_perout_pulse(ptp_perout_pulse)
);

localparam CLK_CNT = PORT_COUNT*2 + (DDR_ENABLE ? DDR_CH : 0) + (HBM_ENABLE ? HBM_CH : 0);

wire [CLK_CNT-1:0] all_clocks;

mqnic_rb_clk_info #(
    .CLK_PERIOD_NS_NUM(CLK_PERIOD_NS_NUM),
    .CLK_PERIOD_NS_DENOM(CLK_PERIOD_NS_DENOM),
    .REF_CLK_PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
    .REF_CLK_PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM),
    .CH_CNT(CLK_CNT),
    .REG_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .REG_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .REG_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .RB_BASE_ADDR(CLK_RB_BASE_ADDR),
    .RB_NEXT_PTR(RB_NEXT_PTR)
)
mqnic_rb_clk_info_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Register interface
     */
    .reg_wr_addr(ctrl_reg_wr_addr),
    .reg_wr_data(ctrl_reg_wr_data),
    .reg_wr_strb(ctrl_reg_wr_strb),
    .reg_wr_en(ctrl_reg_wr_en),
    .reg_wr_wait(clk_ctrl_reg_wr_wait),
    .reg_wr_ack(clk_ctrl_reg_wr_ack),
    .reg_rd_addr(ctrl_reg_rd_addr),
    .reg_rd_en(ctrl_reg_rd_en),
    .reg_rd_data(clk_ctrl_reg_rd_data),
    .reg_rd_wait(clk_ctrl_reg_rd_wait),
    .reg_rd_ack(clk_ctrl_reg_rd_ack),

    /*
     * Clock inputs
     */
    .ref_clk(ptp_clk),

    .ch_clk(all_clocks)
);

localparam CTRL_XBAR_MAIN_OFFSET = 0;
localparam CTRL_XBAR_APP_OFFSET = CTRL_XBAR_MAIN_OFFSET + 1;
localparam CTRL_XBAR_S_COUNT = CTRL_XBAR_APP_OFFSET + (APP_ENABLE && APP_CTRL_ENABLE ? 1 : 0);

wire [CTRL_XBAR_S_COUNT*AXIL_CTRL_ADDR_WIDTH-1:0]  axil_ctrl_xbar_awaddr;
wire [CTRL_XBAR_S_COUNT*3-1:0]                     axil_ctrl_xbar_awprot;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_awvalid;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_awready;
wire [CTRL_XBAR_S_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_ctrl_xbar_wdata;
wire [CTRL_XBAR_S_COUNT*AXIL_CTRL_STRB_WIDTH-1:0]  axil_ctrl_xbar_wstrb;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_wvalid;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_wready;
wire [CTRL_XBAR_S_COUNT*2-1:0]                     axil_ctrl_xbar_bresp;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_bvalid;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_bready;
wire [CTRL_XBAR_S_COUNT*AXIL_CTRL_ADDR_WIDTH-1:0]  axil_ctrl_xbar_araddr;
wire [CTRL_XBAR_S_COUNT*3-1:0]                     axil_ctrl_xbar_arprot;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_arvalid;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_arready;
wire [CTRL_XBAR_S_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_ctrl_xbar_rdata;
wire [CTRL_XBAR_S_COUNT*2-1:0]                     axil_ctrl_xbar_rresp;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_rvalid;
wire [CTRL_XBAR_S_COUNT-1:0]                       axil_ctrl_xbar_rready;

generate

assign axil_ctrl_xbar_awaddr[CTRL_XBAR_MAIN_OFFSET*AXIL_CTRL_ADDR_WIDTH +: AXIL_CTRL_ADDR_WIDTH] = s_axil_ctrl_awaddr;
assign axil_ctrl_xbar_awprot[CTRL_XBAR_MAIN_OFFSET*3 +: 3] = s_axil_ctrl_awprot;
assign axil_ctrl_xbar_awvalid[CTRL_XBAR_MAIN_OFFSET +: 1] = s_axil_ctrl_awvalid;
assign s_axil_ctrl_awready = axil_ctrl_xbar_awready[CTRL_XBAR_MAIN_OFFSET +: 1];
assign axil_ctrl_xbar_wdata[CTRL_XBAR_MAIN_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH] = s_axil_ctrl_wdata;
assign axil_ctrl_xbar_wstrb[CTRL_XBAR_MAIN_OFFSET*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH] = s_axil_ctrl_wstrb;
assign axil_ctrl_xbar_wvalid[CTRL_XBAR_MAIN_OFFSET +: 1] = s_axil_ctrl_wvalid;
assign s_axil_ctrl_wready = axil_ctrl_xbar_wready[CTRL_XBAR_MAIN_OFFSET +: 1];
assign s_axil_ctrl_bresp = axil_ctrl_xbar_bresp[CTRL_XBAR_MAIN_OFFSET*2 +: 2];
assign s_axil_ctrl_bvalid = axil_ctrl_xbar_bvalid[CTRL_XBAR_MAIN_OFFSET +: 1];
assign axil_ctrl_xbar_bready[CTRL_XBAR_MAIN_OFFSET +: 1] = s_axil_ctrl_bready;
assign axil_ctrl_xbar_araddr[CTRL_XBAR_MAIN_OFFSET*AXIL_CTRL_ADDR_WIDTH +: AXIL_CTRL_ADDR_WIDTH] = s_axil_ctrl_araddr;
assign axil_ctrl_xbar_arprot[CTRL_XBAR_MAIN_OFFSET*3 +: 3] = s_axil_ctrl_arprot;
assign axil_ctrl_xbar_arvalid[CTRL_XBAR_MAIN_OFFSET +: 1] = s_axil_ctrl_arvalid;
assign s_axil_ctrl_arready = axil_ctrl_xbar_arready[CTRL_XBAR_MAIN_OFFSET +: 1];
assign s_axil_ctrl_rdata = axil_ctrl_xbar_rdata[CTRL_XBAR_MAIN_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH];
assign s_axil_ctrl_rresp = axil_ctrl_xbar_rresp[CTRL_XBAR_MAIN_OFFSET*2 +: 2];
assign s_axil_ctrl_rvalid = axil_ctrl_xbar_rvalid[CTRL_XBAR_MAIN_OFFSET +: 1];
assign axil_ctrl_xbar_rready[CTRL_XBAR_MAIN_OFFSET +: 1] = s_axil_ctrl_rready;

if (APP_ENABLE && APP_CTRL_ENABLE) begin

    assign axil_ctrl_xbar_awaddr[CTRL_XBAR_APP_OFFSET*AXIL_CTRL_ADDR_WIDTH +: AXIL_CTRL_ADDR_WIDTH] = axil_ctrl_app_awaddr;
    assign axil_ctrl_xbar_awprot[CTRL_XBAR_APP_OFFSET*3 +: 3] = axil_ctrl_app_awprot;
    assign axil_ctrl_xbar_awvalid[CTRL_XBAR_APP_OFFSET +: 1] = axil_ctrl_app_awvalid;
    assign axil_ctrl_app_awready = axil_ctrl_xbar_awready[CTRL_XBAR_APP_OFFSET +: 1];
    assign axil_ctrl_xbar_wdata[CTRL_XBAR_APP_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH] = axil_ctrl_app_wdata;
    assign axil_ctrl_xbar_wstrb[CTRL_XBAR_APP_OFFSET*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH] = axil_ctrl_app_wstrb;
    assign axil_ctrl_xbar_wvalid[CTRL_XBAR_APP_OFFSET +: 1] = axil_ctrl_app_wvalid;
    assign axil_ctrl_app_wready = axil_ctrl_xbar_wready[CTRL_XBAR_APP_OFFSET +: 1];
    assign axil_ctrl_app_bresp = axil_ctrl_xbar_bresp[CTRL_XBAR_APP_OFFSET*2 +: 2];
    assign axil_ctrl_app_bvalid = axil_ctrl_xbar_bvalid[CTRL_XBAR_APP_OFFSET +: 1];
    assign axil_ctrl_xbar_bready[CTRL_XBAR_APP_OFFSET +: 1] = axil_ctrl_app_bready;
    assign axil_ctrl_xbar_araddr[CTRL_XBAR_APP_OFFSET*AXIL_CTRL_ADDR_WIDTH +: AXIL_CTRL_ADDR_WIDTH] = axil_ctrl_app_araddr;
    assign axil_ctrl_xbar_arprot[CTRL_XBAR_APP_OFFSET*3 +: 3] = axil_ctrl_app_arprot;
    assign axil_ctrl_xbar_arvalid[CTRL_XBAR_APP_OFFSET +: 1] = axil_ctrl_app_arvalid;
    assign axil_ctrl_app_arready = axil_ctrl_xbar_arready[CTRL_XBAR_APP_OFFSET +: 1];
    assign axil_ctrl_app_rdata = axil_ctrl_xbar_rdata[CTRL_XBAR_APP_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH];
    assign axil_ctrl_app_rresp = axil_ctrl_xbar_rresp[CTRL_XBAR_APP_OFFSET*2 +: 2];
    assign axil_ctrl_app_rvalid = axil_ctrl_xbar_rvalid[CTRL_XBAR_APP_OFFSET +: 1];
    assign axil_ctrl_xbar_rready[CTRL_XBAR_APP_OFFSET +: 1] = axil_ctrl_app_rready;

end else begin

    assign axil_ctrl_app_awready = 0;
    assign axil_ctrl_app_wready = 0;
    assign axil_ctrl_app_bresp = 0;
    assign axil_ctrl_app_bvalid = 0;
    assign axil_ctrl_app_arready = 0;
    assign axil_ctrl_app_rdata = 0;
    assign axil_ctrl_app_rresp = 0;
    assign axil_ctrl_app_rvalid = 0;

end

endgenerate

wire [IF_COUNT*AXIL_CTRL_ADDR_WIDTH-1:0]  axil_if_ctrl_awaddr;
wire [IF_COUNT*3-1:0]                     axil_if_ctrl_awprot;
wire [IF_COUNT-1:0]                       axil_if_ctrl_awvalid;
wire [IF_COUNT-1:0]                       axil_if_ctrl_awready;
wire [IF_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_if_ctrl_wdata;
wire [IF_COUNT*AXIL_CTRL_STRB_WIDTH-1:0]  axil_if_ctrl_wstrb;
wire [IF_COUNT-1:0]                       axil_if_ctrl_wvalid;
wire [IF_COUNT-1:0]                       axil_if_ctrl_wready;
wire [IF_COUNT*2-1:0]                     axil_if_ctrl_bresp;
wire [IF_COUNT-1:0]                       axil_if_ctrl_bvalid;
wire [IF_COUNT-1:0]                       axil_if_ctrl_bready;
wire [IF_COUNT*AXIL_CTRL_ADDR_WIDTH-1:0]  axil_if_ctrl_araddr;
wire [IF_COUNT*3-1:0]                     axil_if_ctrl_arprot;
wire [IF_COUNT-1:0]                       axil_if_ctrl_arvalid;
wire [IF_COUNT-1:0]                       axil_if_ctrl_arready;
wire [IF_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_if_ctrl_rdata;
wire [IF_COUNT*2-1:0]                     axil_if_ctrl_rresp;
wire [IF_COUNT-1:0]                       axil_if_ctrl_rvalid;
wire [IF_COUNT-1:0]                       axil_if_ctrl_rready;

axil_crossbar #(
    .DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .S_COUNT(CTRL_XBAR_S_COUNT),
    .M_COUNT(IF_COUNT),
    .M_BASE_ADDR(0),
    .M_ADDR_WIDTH({IF_COUNT{w_32(AXIL_IF_CTRL_ADDR_WIDTH)}}),
    .M_CONNECT_READ({IF_COUNT{{CTRL_XBAR_S_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({IF_COUNT{{CTRL_XBAR_S_COUNT{1'b1}}}})
)
axil_crossbar_inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(axil_ctrl_xbar_awaddr),
    .s_axil_awprot(axil_ctrl_xbar_awprot),
    .s_axil_awvalid(axil_ctrl_xbar_awvalid),
    .s_axil_awready(axil_ctrl_xbar_awready),
    .s_axil_wdata(axil_ctrl_xbar_wdata),
    .s_axil_wstrb(axil_ctrl_xbar_wstrb),
    .s_axil_wvalid(axil_ctrl_xbar_wvalid),
    .s_axil_wready(axil_ctrl_xbar_wready),
    .s_axil_bresp(axil_ctrl_xbar_bresp),
    .s_axil_bvalid(axil_ctrl_xbar_bvalid),
    .s_axil_bready(axil_ctrl_xbar_bready),
    .s_axil_araddr(axil_ctrl_xbar_araddr),
    .s_axil_arprot(axil_ctrl_xbar_arprot),
    .s_axil_arvalid(axil_ctrl_xbar_arvalid),
    .s_axil_arready(axil_ctrl_xbar_arready),
    .s_axil_rdata(axil_ctrl_xbar_rdata),
    .s_axil_rresp(axil_ctrl_xbar_rresp),
    .s_axil_rvalid(axil_ctrl_xbar_rvalid),
    .s_axil_rready(axil_ctrl_xbar_rready),
    .m_axil_awaddr(axil_if_ctrl_awaddr),
    .m_axil_awprot(axil_if_ctrl_awprot),
    .m_axil_awvalid(axil_if_ctrl_awvalid),
    .m_axil_awready(axil_if_ctrl_awready),
    .m_axil_wdata(axil_if_ctrl_wdata),
    .m_axil_wstrb(axil_if_ctrl_wstrb),
    .m_axil_wvalid(axil_if_ctrl_wvalid),
    .m_axil_wready(axil_if_ctrl_wready),
    .m_axil_bresp(axil_if_ctrl_bresp),
    .m_axil_bvalid(axil_if_ctrl_bvalid),
    .m_axil_bready(axil_if_ctrl_bready),
    .m_axil_araddr(axil_if_ctrl_araddr),
    .m_axil_arprot(axil_if_ctrl_arprot),
    .m_axil_arvalid(axil_if_ctrl_arvalid),
    .m_axil_arready(axil_if_ctrl_arready),
    .m_axil_rdata(axil_if_ctrl_rdata),
    .m_axil_rresp(axil_if_ctrl_rresp),
    .m_axil_rvalid(axil_if_ctrl_rvalid),
    .m_axil_rready(axil_if_ctrl_rready)
);

wire [IF_COUNT*AXIL_CSR_ADDR_WIDTH-1:0]   axil_if_csr_awaddr;
wire [IF_COUNT*3-1:0]                     axil_if_csr_awprot;
wire [IF_COUNT-1:0]                       axil_if_csr_awvalid;
wire [IF_COUNT-1:0]                       axil_if_csr_awready;
wire [IF_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_if_csr_wdata;
wire [IF_COUNT*AXIL_CTRL_STRB_WIDTH-1:0]  axil_if_csr_wstrb;
wire [IF_COUNT-1:0]                       axil_if_csr_wvalid;
wire [IF_COUNT-1:0]                       axil_if_csr_wready;
wire [IF_COUNT*2-1:0]                     axil_if_csr_bresp;
wire [IF_COUNT-1:0]                       axil_if_csr_bvalid;
wire [IF_COUNT-1:0]                       axil_if_csr_bready;
wire [IF_COUNT*AXIL_CSR_ADDR_WIDTH-1:0]   axil_if_csr_araddr;
wire [IF_COUNT*3-1:0]                     axil_if_csr_arprot;
wire [IF_COUNT-1:0]                       axil_if_csr_arvalid;
wire [IF_COUNT-1:0]                       axil_if_csr_arready;
wire [IF_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_if_csr_rdata;
wire [IF_COUNT*2-1:0]                     axil_if_csr_rresp;
wire [IF_COUNT-1:0]                       axil_if_csr_rvalid;
wire [IF_COUNT-1:0]                       axil_if_csr_rready;

localparam CSR_XBAR_CSR_OFFSET = 0;
localparam CSR_XBAR_MSIX_OFFSET = CSR_XBAR_CSR_OFFSET + 1;
localparam CSR_XBAR_STAT_OFFSET = CSR_XBAR_MSIX_OFFSET + (MSIX_ENABLE ? 1 : 0);
localparam CSR_XBAR_PASSTHROUGH_OFFSET = CSR_XBAR_STAT_OFFSET + (STAT_ENABLE ? 1 : 0);
localparam CSR_XBAR_M_COUNT = CSR_XBAR_PASSTHROUGH_OFFSET + (AXIL_CSR_PASSTHROUGH_ENABLE ? 1 : 0);

function [CSR_XBAR_M_COUNT*32-1:0] calcCsrXbarWidths(input [31:0] dummy);
    begin
        calcCsrXbarWidths[CSR_XBAR_CSR_OFFSET*32 +: 32] = 16;
        if (MSIX_ENABLE) begin
            calcCsrXbarWidths[CSR_XBAR_MSIX_OFFSET*32 +: 32] = 16;
        end
        if (STAT_ENABLE) begin
            calcCsrXbarWidths[CSR_XBAR_STAT_OFFSET*32 +: 32] = 16;
        end
        if (AXIL_CSR_PASSTHROUGH_ENABLE) begin
            calcCsrXbarWidths[CSR_XBAR_PASSTHROUGH_OFFSET*32 +: 32] = AXIL_CSR_ADDR_WIDTH-1;
        end
    end
endfunction

wire [CSR_XBAR_M_COUNT*AXIL_CSR_ADDR_WIDTH-1:0]   axil_csr_xbar_awaddr;
wire [CSR_XBAR_M_COUNT*3-1:0]                     axil_csr_xbar_awprot;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_awvalid;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_awready;
wire [CSR_XBAR_M_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_csr_xbar_wdata;
wire [CSR_XBAR_M_COUNT*AXIL_CTRL_STRB_WIDTH-1:0]  axil_csr_xbar_wstrb;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_wvalid;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_wready;
wire [CSR_XBAR_M_COUNT*2-1:0]                     axil_csr_xbar_bresp;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_bvalid;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_bready;
wire [CSR_XBAR_M_COUNT*AXIL_CSR_ADDR_WIDTH-1:0]   axil_csr_xbar_araddr;
wire [CSR_XBAR_M_COUNT*3-1:0]                     axil_csr_xbar_arprot;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_arvalid;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_arready;
wire [CSR_XBAR_M_COUNT*AXIL_CTRL_DATA_WIDTH-1:0]  axil_csr_xbar_rdata;
wire [CSR_XBAR_M_COUNT*2-1:0]                     axil_csr_xbar_rresp;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_rvalid;
wire [CSR_XBAR_M_COUNT-1:0]                       axil_csr_xbar_rready;

generate

assign axil_csr_awaddr = axil_csr_xbar_awaddr[CSR_XBAR_CSR_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
assign axil_csr_awprot = axil_csr_xbar_awprot[CSR_XBAR_CSR_OFFSET*3 +: 3];
assign axil_csr_awvalid = axil_csr_xbar_awvalid[CSR_XBAR_CSR_OFFSET +: 1];
assign axil_csr_xbar_awready[CSR_XBAR_CSR_OFFSET +: 1] = axil_csr_awready;
assign axil_csr_wdata = axil_csr_xbar_wdata[CSR_XBAR_CSR_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH];
assign axil_csr_wstrb = axil_csr_xbar_wstrb[CSR_XBAR_CSR_OFFSET*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH];
assign axil_csr_wvalid = axil_csr_xbar_wvalid[CSR_XBAR_CSR_OFFSET +: 1];
assign axil_csr_xbar_wready[CSR_XBAR_CSR_OFFSET +: 1] = axil_csr_wready;
assign axil_csr_xbar_bresp[CSR_XBAR_CSR_OFFSET*2 +: 2] = axil_csr_bresp;
assign axil_csr_xbar_bvalid[CSR_XBAR_CSR_OFFSET +: 1] = axil_csr_bvalid;
assign axil_csr_bready = axil_csr_xbar_bready[CSR_XBAR_CSR_OFFSET +: 1];
assign axil_csr_araddr = axil_csr_xbar_araddr[CSR_XBAR_CSR_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
assign axil_csr_arprot = axil_csr_xbar_arprot[CSR_XBAR_CSR_OFFSET*3 +: 3];
assign axil_csr_arvalid = axil_csr_xbar_arvalid[CSR_XBAR_CSR_OFFSET +: 1];
assign axil_csr_xbar_arready[CSR_XBAR_CSR_OFFSET +: 1] = axil_csr_arready;
assign axil_csr_xbar_rdata[CSR_XBAR_CSR_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH] = axil_csr_rdata;
assign axil_csr_xbar_rresp[CSR_XBAR_CSR_OFFSET*2 +: 2] = axil_csr_rresp;
assign axil_csr_xbar_rvalid[CSR_XBAR_CSR_OFFSET +: 1] = axil_csr_rvalid;
assign axil_csr_rready = axil_csr_xbar_rready[CSR_XBAR_CSR_OFFSET +: 1];

if (MSIX_ENABLE) begin

    assign m_axil_msix_awaddr = axil_csr_xbar_awaddr[CSR_XBAR_MSIX_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
    assign m_axil_msix_awprot = axil_csr_xbar_awprot[CSR_XBAR_MSIX_OFFSET*3 +: 3];
    assign m_axil_msix_awvalid = axil_csr_xbar_awvalid[CSR_XBAR_MSIX_OFFSET +: 1];
    assign axil_csr_xbar_awready[CSR_XBAR_MSIX_OFFSET +: 1] = m_axil_msix_awready;
    assign m_axil_msix_wdata = axil_csr_xbar_wdata[CSR_XBAR_MSIX_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH];
    assign m_axil_msix_wstrb = axil_csr_xbar_wstrb[CSR_XBAR_MSIX_OFFSET*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH];
    assign m_axil_msix_wvalid = axil_csr_xbar_wvalid[CSR_XBAR_MSIX_OFFSET +: 1];
    assign axil_csr_xbar_wready[CSR_XBAR_MSIX_OFFSET +: 1] = m_axil_msix_wready;
    assign axil_csr_xbar_bresp[CSR_XBAR_MSIX_OFFSET*2 +: 2] = m_axil_msix_bresp;
    assign axil_csr_xbar_bvalid[CSR_XBAR_MSIX_OFFSET +: 1] = m_axil_msix_bvalid;
    assign m_axil_msix_bready = axil_csr_xbar_bready[CSR_XBAR_MSIX_OFFSET +: 1];
    assign m_axil_msix_araddr = axil_csr_xbar_araddr[CSR_XBAR_MSIX_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
    assign m_axil_msix_arprot = axil_csr_xbar_arprot[CSR_XBAR_MSIX_OFFSET*3 +: 3];
    assign m_axil_msix_arvalid = axil_csr_xbar_arvalid[CSR_XBAR_MSIX_OFFSET +: 1];
    assign axil_csr_xbar_arready[CSR_XBAR_MSIX_OFFSET +: 1] = m_axil_msix_arready;
    assign axil_csr_xbar_rdata[CSR_XBAR_MSIX_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH] = m_axil_msix_rdata;
    assign axil_csr_xbar_rresp[CSR_XBAR_MSIX_OFFSET*2 +: 2] = m_axil_msix_rresp;
    assign axil_csr_xbar_rvalid[CSR_XBAR_MSIX_OFFSET +: 1] = m_axil_msix_rvalid;
    assign m_axil_msix_rready = axil_csr_xbar_rready[CSR_XBAR_MSIX_OFFSET +: 1];

end else begin

    assign m_axil_msix_awaddr = 0;
    assign m_axil_msix_awprot = 0;
    assign m_axil_msix_awvalid = 0;
    assign m_axil_msix_wdata = 0;
    assign m_axil_msix_wstrb = 0;
    assign m_axil_msix_wvalid = 0;
    assign m_axil_msix_bready = 0;
    assign m_axil_msix_araddr = 0;
    assign m_axil_msix_arprot = 0;
    assign m_axil_msix_arvalid = 0;
    assign m_axil_msix_rready = 0;

end

if (STAT_ENABLE) begin

    assign axil_stats_awaddr = axil_csr_xbar_awaddr[CSR_XBAR_STAT_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
    assign axil_stats_awprot = axil_csr_xbar_awprot[CSR_XBAR_STAT_OFFSET*3 +: 3];
    assign axil_stats_awvalid = axil_csr_xbar_awvalid[CSR_XBAR_STAT_OFFSET +: 1];
    assign axil_csr_xbar_awready[CSR_XBAR_STAT_OFFSET +: 1] = axil_stats_awready;
    assign axil_stats_wdata = axil_csr_xbar_wdata[CSR_XBAR_STAT_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH];
    assign axil_stats_wstrb = axil_csr_xbar_wstrb[CSR_XBAR_STAT_OFFSET*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH];
    assign axil_stats_wvalid = axil_csr_xbar_wvalid[CSR_XBAR_STAT_OFFSET +: 1];
    assign axil_csr_xbar_wready[CSR_XBAR_STAT_OFFSET +: 1] = axil_stats_wready;
    assign axil_csr_xbar_bresp[CSR_XBAR_STAT_OFFSET*2 +: 2] = axil_stats_bresp;
    assign axil_csr_xbar_bvalid[CSR_XBAR_STAT_OFFSET +: 1] = axil_stats_bvalid;
    assign axil_stats_bready = axil_csr_xbar_bready[CSR_XBAR_STAT_OFFSET +: 1];
    assign axil_stats_araddr = axil_csr_xbar_araddr[CSR_XBAR_STAT_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
    assign axil_stats_arprot = axil_csr_xbar_arprot[CSR_XBAR_STAT_OFFSET*3 +: 3];
    assign axil_stats_arvalid = axil_csr_xbar_arvalid[CSR_XBAR_STAT_OFFSET +: 1];
    assign axil_csr_xbar_arready[CSR_XBAR_STAT_OFFSET +: 1] = axil_stats_arready;
    assign axil_csr_xbar_rdata[CSR_XBAR_STAT_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH] = axil_stats_rdata;
    assign axil_csr_xbar_rresp[CSR_XBAR_STAT_OFFSET*2 +: 2] = axil_stats_rresp;
    assign axil_csr_xbar_rvalid[CSR_XBAR_STAT_OFFSET +: 1] = axil_stats_rvalid;
    assign axil_stats_rready = axil_csr_xbar_rready[CSR_XBAR_STAT_OFFSET +: 1];

end else begin

    assign axil_stats_awaddr = 0;
    assign axil_stats_awprot = 0;
    assign axil_stats_awvalid = 0;
    assign axil_stats_wdata = 0;
    assign axil_stats_wstrb = 0;
    assign axil_stats_wvalid = 0;
    assign axil_stats_bready = 0;
    assign axil_stats_araddr = 0;
    assign axil_stats_arprot = 0;
    assign axil_stats_arvalid = 0;
    assign axil_stats_rready = 0;

end

if (AXIL_CSR_PASSTHROUGH_ENABLE) begin

    assign m_axil_csr_awaddr = axil_csr_xbar_awaddr[CSR_XBAR_PASSTHROUGH_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
    assign m_axil_csr_awprot = axil_csr_xbar_awprot[CSR_XBAR_PASSTHROUGH_OFFSET*3 +: 3];
    assign m_axil_csr_awvalid = axil_csr_xbar_awvalid[CSR_XBAR_PASSTHROUGH_OFFSET +: 1];
    assign axil_csr_xbar_awready[CSR_XBAR_PASSTHROUGH_OFFSET +: 1] = m_axil_csr_awready;
    assign m_axil_csr_wdata = axil_csr_xbar_wdata[CSR_XBAR_PASSTHROUGH_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH];
    assign m_axil_csr_wstrb = axil_csr_xbar_wstrb[CSR_XBAR_PASSTHROUGH_OFFSET*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH];
    assign m_axil_csr_wvalid = axil_csr_xbar_wvalid[CSR_XBAR_PASSTHROUGH_OFFSET +: 1];
    assign axil_csr_xbar_wready[CSR_XBAR_PASSTHROUGH_OFFSET +: 1] = m_axil_csr_wready;
    assign axil_csr_xbar_bresp[CSR_XBAR_PASSTHROUGH_OFFSET*2 +: 2] = m_axil_csr_bresp;
    assign axil_csr_xbar_bvalid[CSR_XBAR_PASSTHROUGH_OFFSET +: 1] = m_axil_csr_bvalid;
    assign m_axil_csr_bready = axil_csr_xbar_bready[CSR_XBAR_PASSTHROUGH_OFFSET +: 1];
    assign m_axil_csr_araddr = axil_csr_xbar_araddr[CSR_XBAR_PASSTHROUGH_OFFSET*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH];
    assign m_axil_csr_arprot = axil_csr_xbar_arprot[CSR_XBAR_PASSTHROUGH_OFFSET*3 +: 3];
    assign m_axil_csr_arvalid = axil_csr_xbar_arvalid[CSR_XBAR_PASSTHROUGH_OFFSET +: 1];
    assign axil_csr_xbar_arready[CSR_XBAR_PASSTHROUGH_OFFSET +: 1] = m_axil_csr_arready;
    assign axil_csr_xbar_rdata[CSR_XBAR_PASSTHROUGH_OFFSET*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH] = m_axil_csr_rdata;
    assign axil_csr_xbar_rresp[CSR_XBAR_PASSTHROUGH_OFFSET*2 +: 2] = m_axil_csr_rresp;
    assign axil_csr_xbar_rvalid[CSR_XBAR_PASSTHROUGH_OFFSET +: 1] = m_axil_csr_rvalid;
    assign m_axil_csr_rready = axil_csr_xbar_rready[CSR_XBAR_PASSTHROUGH_OFFSET +: 1];

end else begin

    assign m_axil_csr_awaddr = 0;
    assign m_axil_csr_awprot = 0;
    assign m_axil_csr_awvalid = 0;
    assign m_axil_csr_wdata = 0;
    assign m_axil_csr_wstrb = 0;
    assign m_axil_csr_wvalid = 0;
    assign m_axil_csr_bready = 0;
    assign m_axil_csr_araddr = 0;
    assign m_axil_csr_arprot = 0;
    assign m_axil_csr_arvalid = 0;
    assign m_axil_csr_rready = 0;

end

endgenerate

axil_crossbar #(
    .DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .S_COUNT(IF_COUNT),
    .M_COUNT(CSR_XBAR_M_COUNT),
    .M_BASE_ADDR(0),
    .M_ADDR_WIDTH(calcCsrXbarWidths(0)),
    .M_CONNECT_READ({CSR_XBAR_M_COUNT{{IF_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({CSR_XBAR_M_COUNT{{IF_COUNT{1'b1}}}})
)
axil_csr_crossbar_inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(axil_if_csr_awaddr),
    .s_axil_awprot(axil_if_csr_awprot),
    .s_axil_awvalid(axil_if_csr_awvalid),
    .s_axil_awready(axil_if_csr_awready),
    .s_axil_wdata(axil_if_csr_wdata),
    .s_axil_wstrb(axil_if_csr_wstrb),
    .s_axil_wvalid(axil_if_csr_wvalid),
    .s_axil_wready(axil_if_csr_wready),
    .s_axil_bresp(axil_if_csr_bresp),
    .s_axil_bvalid(axil_if_csr_bvalid),
    .s_axil_bready(axil_if_csr_bready),
    .s_axil_araddr(axil_if_csr_araddr),
    .s_axil_arprot(axil_if_csr_arprot),
    .s_axil_arvalid(axil_if_csr_arvalid),
    .s_axil_arready(axil_if_csr_arready),
    .s_axil_rdata(axil_if_csr_rdata),
    .s_axil_rresp(axil_if_csr_rresp),
    .s_axil_rvalid(axil_if_csr_rvalid),
    .s_axil_rready(axil_if_csr_rready),
    .m_axil_awaddr(axil_csr_xbar_awaddr),
    .m_axil_awprot(axil_csr_xbar_awprot),
    .m_axil_awvalid(axil_csr_xbar_awvalid),
    .m_axil_awready(axil_csr_xbar_awready),
    .m_axil_wdata(axil_csr_xbar_wdata),
    .m_axil_wstrb(axil_csr_xbar_wstrb),
    .m_axil_wvalid(axil_csr_xbar_wvalid),
    .m_axil_wready(axil_csr_xbar_wready),
    .m_axil_bresp(axil_csr_xbar_bresp),
    .m_axil_bvalid(axil_csr_xbar_bvalid),
    .m_axil_bready(axil_csr_xbar_bready),
    .m_axil_araddr(axil_csr_xbar_araddr),
    .m_axil_arprot(axil_csr_xbar_arprot),
    .m_axil_arvalid(axil_csr_xbar_arvalid),
    .m_axil_arready(axil_csr_xbar_arready),
    .m_axil_rdata(axil_csr_xbar_rdata),
    .m_axil_rresp(axil_csr_xbar_rresp),
    .m_axil_rvalid(axil_csr_xbar_rvalid),
    .m_axil_rready(axil_csr_xbar_rready)
);

wire [STAT_INC_WIDTH-1:0]  axis_stat_tdata;
wire [STAT_ID_WIDTH-1:0]   axis_stat_tid;
wire                       axis_stat_tvalid;
wire                       axis_stat_tready;

wire [STAT_INC_WIDTH-1:0]  axis_app_stat_tdata;
wire [STAT_ID_WIDTH-1:0]   axis_app_stat_tid;
wire                       axis_app_stat_tvalid;
wire                       axis_app_stat_tready;

generate

if (STAT_ENABLE && (APP_ENABLE && APP_STAT_ENABLE)) begin

    axis_arb_mux #(
        .S_COUNT(2),
        .DATA_WIDTH(STAT_INC_WIDTH),
        .KEEP_ENABLE(0),
        .ID_ENABLE(1),
        .S_ID_WIDTH(STAT_ID_WIDTH),
        .M_ID_WIDTH(STAT_ID_WIDTH),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .LAST_ENABLE(0),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    axis_stat_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI Stream inputs
         */
        .s_axis_tdata({axis_app_stat_tdata, s_axis_stat_tdata}),
        .s_axis_tkeep(0),
        .s_axis_tvalid({axis_app_stat_tvalid, s_axis_stat_tvalid}),
        .s_axis_tready({axis_app_stat_tready, s_axis_stat_tready}),
        .s_axis_tlast(0),
        .s_axis_tid({axis_app_stat_tid, s_axis_stat_tid}),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        /*
         * AXI Stream output
         */
        .m_axis_tdata(axis_stat_tdata),
        .m_axis_tkeep(),
        .m_axis_tvalid(axis_stat_tvalid),
        .m_axis_tready(axis_stat_tready),
        .m_axis_tlast(),
        .m_axis_tid(axis_stat_tid),
        .m_axis_tdest(),
        .m_axis_tuser()
    );

end else begin

    assign axis_stat_tdata = s_axis_stat_tdata;
    assign axis_stat_tid = s_axis_stat_tid;
    assign axis_stat_tvalid = s_axis_stat_tvalid;
    assign s_axis_stat_tready = axis_stat_tready;

    assign axis_app_stat_tready = 1'b1;

end

if (STAT_ENABLE) begin

    stats_counter #(
        .STAT_INC_WIDTH(STAT_INC_WIDTH),
        .STAT_ID_WIDTH(STAT_ID_WIDTH),
        .STAT_COUNT_WIDTH(64),
        .AXIL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(16),
        .AXIL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH)
    )
    stats_counter_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Statistics increment input
         */
        .s_axis_stat_tdata(axis_stat_tdata),
        .s_axis_stat_tid(axis_stat_tid),
        .s_axis_stat_tvalid(axis_stat_tvalid),
        .s_axis_stat_tready(axis_stat_tready),

        /*
         * AXI Lite register interface
         */
        .s_axil_awaddr(axil_stats_awaddr),
        .s_axil_awprot(axil_stats_awprot),
        .s_axil_awvalid(axil_stats_awvalid),
        .s_axil_awready(axil_stats_awready),
        .s_axil_wdata(axil_stats_wdata),
        .s_axil_wstrb(axil_stats_wstrb),
        .s_axil_wvalid(axil_stats_wvalid),
        .s_axil_wready(axil_stats_wready),
        .s_axil_bresp(axil_stats_bresp),
        .s_axil_bvalid(axil_stats_bvalid),
        .s_axil_bready(axil_stats_bready),
        .s_axil_araddr(axil_stats_araddr),
        .s_axil_arprot(axil_stats_arprot),
        .s_axil_arvalid(axil_stats_arvalid),
        .s_axil_arready(axil_stats_arready),
        .s_axil_rdata(axil_stats_rdata),
        .s_axil_rresp(axil_stats_rresp),
        .s_axil_rvalid(axil_stats_rvalid),
        .s_axil_rready(axil_stats_rready)
    );

end else begin

    assign axis_stat_tready = 1'b1;

end

endgenerate

// data/control DMA mux (priority)
wire [DMA_ADDR_WIDTH-1:0]  ctrl_dma_read_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   ctrl_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  ctrl_dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   ctrl_dma_read_desc_len;
wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_read_desc_tag;
wire                       ctrl_dma_read_desc_valid;
wire                       ctrl_dma_read_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_read_desc_status_tag;
wire [3:0]                 ctrl_dma_read_desc_status_error;
wire                       ctrl_dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  ctrl_dma_write_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   ctrl_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  ctrl_dma_write_desc_ram_addr;
wire [DMA_IMM_WIDTH-1:0]   ctrl_dma_write_desc_imm;
wire                       ctrl_dma_write_desc_imm_en;
wire [DMA_LEN_WIDTH-1:0]   ctrl_dma_write_desc_len;
wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_write_desc_tag;
wire                       ctrl_dma_write_desc_valid;
wire                       ctrl_dma_write_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_write_desc_status_tag;
wire [3:0]                 ctrl_dma_write_desc_status_error;
wire                       ctrl_dma_write_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  data_dma_read_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   data_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  data_dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   data_dma_read_desc_len;
wire [DMA_TAG_WIDTH-2:0]   data_dma_read_desc_tag;
wire                       data_dma_read_desc_valid;
wire                       data_dma_read_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   data_dma_read_desc_status_tag;
wire [3:0]                 data_dma_read_desc_status_error;
wire                       data_dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  data_dma_write_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   data_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  data_dma_write_desc_ram_addr;
wire [DMA_IMM_WIDTH-1:0]   data_dma_write_desc_imm;
wire                       data_dma_write_desc_imm_en;
wire [DMA_LEN_WIDTH-1:0]   data_dma_write_desc_len;
wire [DMA_TAG_WIDTH-2:0]   data_dma_write_desc_tag;
wire                       data_dma_write_desc_valid;
wire                       data_dma_write_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   data_dma_write_desc_status_tag;
wire [3:0]                 data_dma_write_desc_status_error;
wire                       data_dma_write_desc_status_valid;

wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   ctrl_dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    ctrl_dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ctrl_dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ctrl_dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_done;
wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   ctrl_dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ctrl_dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ctrl_dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_resp_ready;

wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   data_dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    data_dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  data_dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  data_dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_done;
wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   data_dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  data_dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  data_dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_resp_ready;

dma_if_mux #(
    .PORTS(2),
    .S_RAM_SEL_WIDTH(RAM_SEL_WIDTH-1),
    .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .IMM_ENABLE(DMA_IMM_ENABLE),
    .IMM_WIDTH(DMA_IMM_WIDTH),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .S_TAG_WIDTH(DMA_TAG_WIDTH-1),
    .M_TAG_WIDTH(DMA_TAG_WIDTH),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(1)
)
dma_if_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Read descriptor output (to DMA interface)
     */
    .m_axis_read_desc_dma_addr(m_axis_dma_read_desc_dma_addr),
    .m_axis_read_desc_ram_sel(m_axis_dma_read_desc_ram_sel),
    .m_axis_read_desc_ram_addr(m_axis_dma_read_desc_ram_addr),
    .m_axis_read_desc_len(m_axis_dma_read_desc_len),
    .m_axis_read_desc_tag(m_axis_dma_read_desc_tag),
    .m_axis_read_desc_valid(m_axis_dma_read_desc_valid),
    .m_axis_read_desc_ready(m_axis_dma_read_desc_ready),

    /*
     * Read descriptor status input (from DMA interface)
     */
    .s_axis_read_desc_status_tag(s_axis_dma_read_desc_status_tag),
    .s_axis_read_desc_status_error(s_axis_dma_read_desc_status_error),
    .s_axis_read_desc_status_valid(s_axis_dma_read_desc_status_valid),

    /*
     * Read descriptor input
     */
    .s_axis_read_desc_dma_addr({data_dma_read_desc_dma_addr, ctrl_dma_read_desc_dma_addr}),
    .s_axis_read_desc_ram_sel({data_dma_read_desc_ram_sel, ctrl_dma_read_desc_ram_sel}),
    .s_axis_read_desc_ram_addr({data_dma_read_desc_ram_addr, ctrl_dma_read_desc_ram_addr}),
    .s_axis_read_desc_len({data_dma_read_desc_len, ctrl_dma_read_desc_len}),
    .s_axis_read_desc_tag({data_dma_read_desc_tag, ctrl_dma_read_desc_tag}),
    .s_axis_read_desc_valid({data_dma_read_desc_valid, ctrl_dma_read_desc_valid}),
    .s_axis_read_desc_ready({data_dma_read_desc_ready, ctrl_dma_read_desc_ready}),

    /*
     * Read descriptor status output
     */
    .m_axis_read_desc_status_tag({data_dma_read_desc_status_tag, ctrl_dma_read_desc_status_tag}),
    .m_axis_read_desc_status_error({data_dma_read_desc_status_error, ctrl_dma_read_desc_status_error}),
    .m_axis_read_desc_status_valid({data_dma_read_desc_status_valid, ctrl_dma_read_desc_status_valid}),

    /*
     * Write descriptor output (to DMA interface)
     */
    .m_axis_write_desc_dma_addr(m_axis_dma_write_desc_dma_addr),
    .m_axis_write_desc_ram_sel(m_axis_dma_write_desc_ram_sel),
    .m_axis_write_desc_ram_addr(m_axis_dma_write_desc_ram_addr),
    .m_axis_write_desc_imm(m_axis_dma_write_desc_imm),
    .m_axis_write_desc_imm_en(m_axis_dma_write_desc_imm_en),
    .m_axis_write_desc_len(m_axis_dma_write_desc_len),
    .m_axis_write_desc_tag(m_axis_dma_write_desc_tag),
    .m_axis_write_desc_valid(m_axis_dma_write_desc_valid),
    .m_axis_write_desc_ready(m_axis_dma_write_desc_ready),

    /*
     * Write descriptor status input (from DMA interface)
     */
    .s_axis_write_desc_status_tag(s_axis_dma_write_desc_status_tag),
    .s_axis_write_desc_status_error(s_axis_dma_write_desc_status_error),
    .s_axis_write_desc_status_valid(s_axis_dma_write_desc_status_valid),

    /*
     * Write descriptor input
     */
    .s_axis_write_desc_dma_addr({data_dma_write_desc_dma_addr, ctrl_dma_write_desc_dma_addr}),
    .s_axis_write_desc_ram_sel({data_dma_write_desc_ram_sel, ctrl_dma_write_desc_ram_sel}),
    .s_axis_write_desc_ram_addr({data_dma_write_desc_ram_addr, ctrl_dma_write_desc_ram_addr}),
    .s_axis_write_desc_imm({data_dma_write_desc_imm, ctrl_dma_write_desc_imm}),
    .s_axis_write_desc_imm_en({data_dma_write_desc_imm_en, ctrl_dma_write_desc_imm_en}),
    .s_axis_write_desc_len({data_dma_write_desc_len, ctrl_dma_write_desc_len}),
    .s_axis_write_desc_tag({data_dma_write_desc_tag, ctrl_dma_write_desc_tag}),
    .s_axis_write_desc_valid({data_dma_write_desc_valid, ctrl_dma_write_desc_valid}),
    .s_axis_write_desc_ready({data_dma_write_desc_ready, ctrl_dma_write_desc_ready}),

    /*
     * Write descriptor status output
     */
    .m_axis_write_desc_status_tag({data_dma_write_desc_status_tag, ctrl_dma_write_desc_status_tag}),
    .m_axis_write_desc_status_error({data_dma_write_desc_status_error, ctrl_dma_write_desc_status_error}),
    .m_axis_write_desc_status_valid({data_dma_write_desc_status_valid, ctrl_dma_write_desc_status_valid}),

    /*
     * RAM interface (from DMA interface)
     */
    .if_ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .if_ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .if_ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .if_ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .if_ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .if_ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .if_ram_wr_done(dma_ram_wr_done),
    .if_ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .if_ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .if_ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .if_ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .if_ram_rd_resp_data(dma_ram_rd_resp_data),
    .if_ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .if_ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel({data_dma_ram_wr_cmd_sel, ctrl_dma_ram_wr_cmd_sel}),
    .ram_wr_cmd_be({data_dma_ram_wr_cmd_be, ctrl_dma_ram_wr_cmd_be}),
    .ram_wr_cmd_addr({data_dma_ram_wr_cmd_addr, ctrl_dma_ram_wr_cmd_addr}),
    .ram_wr_cmd_data({data_dma_ram_wr_cmd_data, ctrl_dma_ram_wr_cmd_data}),
    .ram_wr_cmd_valid({data_dma_ram_wr_cmd_valid, ctrl_dma_ram_wr_cmd_valid}),
    .ram_wr_cmd_ready({data_dma_ram_wr_cmd_ready, ctrl_dma_ram_wr_cmd_ready}),
    .ram_wr_done({data_dma_ram_wr_done, ctrl_dma_ram_wr_done}),
    .ram_rd_cmd_sel({data_dma_ram_rd_cmd_sel, ctrl_dma_ram_rd_cmd_sel}),
    .ram_rd_cmd_addr({data_dma_ram_rd_cmd_addr, ctrl_dma_ram_rd_cmd_addr}),
    .ram_rd_cmd_valid({data_dma_ram_rd_cmd_valid, ctrl_dma_ram_rd_cmd_valid}),
    .ram_rd_cmd_ready({data_dma_ram_rd_cmd_ready, ctrl_dma_ram_rd_cmd_ready}),
    .ram_rd_resp_data({data_dma_ram_rd_resp_data, ctrl_dma_ram_rd_resp_data}),
    .ram_rd_resp_valid({data_dma_ram_rd_resp_valid, ctrl_dma_ram_rd_resp_valid}),
    .ram_rd_resp_ready({data_dma_ram_rd_resp_ready, ctrl_dma_ram_rd_resp_ready})
);

// interface DMA mux (round-robin)
wire [IF_COUNT_INT*DMA_ADDR_WIDTH-1:0]    if_ctrl_dma_read_desc_dma_addr;
wire [IF_COUNT_INT*IF_RAM_SEL_WIDTH-1:0]  if_ctrl_dma_read_desc_ram_sel;
wire [IF_COUNT_INT*RAM_ADDR_WIDTH-1:0]    if_ctrl_dma_read_desc_ram_addr;
wire [IF_COUNT_INT*DMA_LEN_WIDTH-1:0]     if_ctrl_dma_read_desc_len;
wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_read_desc_tag;
wire [IF_COUNT_INT-1:0]                   if_ctrl_dma_read_desc_valid;
wire [IF_COUNT_INT-1:0]                   if_ctrl_dma_read_desc_ready;

wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_read_desc_status_tag;
wire [IF_COUNT_INT*4-1:0]                 if_ctrl_dma_read_desc_status_error;
wire [IF_COUNT_INT-1:0]                   if_ctrl_dma_read_desc_status_valid;

wire [IF_COUNT_INT*DMA_ADDR_WIDTH-1:0]    if_ctrl_dma_write_desc_dma_addr;
wire [IF_COUNT_INT*IF_RAM_SEL_WIDTH-1:0]  if_ctrl_dma_write_desc_ram_sel;
wire [IF_COUNT_INT*RAM_ADDR_WIDTH-1:0]    if_ctrl_dma_write_desc_ram_addr;
wire [IF_COUNT_INT*DMA_IMM_WIDTH-1:0]     if_ctrl_dma_write_desc_imm;
wire [IF_COUNT_INT-1:0]                   if_ctrl_dma_write_desc_imm_en;
wire [IF_COUNT_INT*DMA_LEN_WIDTH-1:0]     if_ctrl_dma_write_desc_len;
wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_write_desc_tag;
wire [IF_COUNT_INT-1:0]                   if_ctrl_dma_write_desc_valid;
wire [IF_COUNT_INT-1:0]                   if_ctrl_dma_write_desc_ready;

wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_write_desc_status_tag;
wire [IF_COUNT_INT*4-1:0]                 if_ctrl_dma_write_desc_status_error;
wire [IF_COUNT_INT-1:0]                   if_ctrl_dma_write_desc_status_valid;

wire [IF_COUNT_INT*DMA_ADDR_WIDTH-1:0]    if_data_dma_read_desc_dma_addr;
wire [IF_COUNT_INT*IF_RAM_SEL_WIDTH-1:0]  if_data_dma_read_desc_ram_sel;
wire [IF_COUNT_INT*RAM_ADDR_WIDTH-1:0]    if_data_dma_read_desc_ram_addr;
wire [IF_COUNT_INT*DMA_LEN_WIDTH-1:0]     if_data_dma_read_desc_len;
wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_read_desc_tag;
wire [IF_COUNT_INT-1:0]                   if_data_dma_read_desc_valid;
wire [IF_COUNT_INT-1:0]                   if_data_dma_read_desc_ready;

wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_read_desc_status_tag;
wire [IF_COUNT_INT*4-1:0]                 if_data_dma_read_desc_status_error;
wire [IF_COUNT_INT-1:0]                   if_data_dma_read_desc_status_valid;

wire [IF_COUNT_INT*DMA_ADDR_WIDTH-1:0]    if_data_dma_write_desc_dma_addr;
wire [IF_COUNT_INT*IF_RAM_SEL_WIDTH-1:0]  if_data_dma_write_desc_ram_sel;
wire [IF_COUNT_INT*RAM_ADDR_WIDTH-1:0]    if_data_dma_write_desc_ram_addr;
wire [IF_COUNT_INT*DMA_IMM_WIDTH-1:0]     if_data_dma_write_desc_imm;
wire [IF_COUNT_INT-1:0]                   if_data_dma_write_desc_imm_en;
wire [IF_COUNT_INT*DMA_LEN_WIDTH-1:0]     if_data_dma_write_desc_len;
wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_write_desc_tag;
wire [IF_COUNT_INT-1:0]                   if_data_dma_write_desc_valid;
wire [IF_COUNT_INT-1:0]                   if_data_dma_write_desc_ready;

wire [IF_COUNT_INT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_write_desc_status_tag;
wire [IF_COUNT_INT*4-1:0]                 if_data_dma_write_desc_status_error;
wire [IF_COUNT_INT-1:0]                   if_data_dma_write_desc_status_valid;

wire [IF_COUNT_INT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_ctrl_dma_ram_wr_cmd_sel;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    if_ctrl_dma_ram_wr_cmd_be;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_ctrl_dma_ram_wr_cmd_addr;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_ctrl_dma_ram_wr_cmd_data;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_wr_cmd_valid;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_wr_cmd_ready;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_wr_done;
wire [IF_COUNT_INT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_ctrl_dma_ram_rd_cmd_sel;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_ctrl_dma_ram_rd_cmd_addr;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_cmd_valid;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_cmd_ready;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_ctrl_dma_ram_rd_resp_data;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_resp_valid;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_resp_ready;

wire [IF_COUNT_INT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_data_dma_ram_wr_cmd_sel;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    if_data_dma_ram_wr_cmd_be;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_data_dma_ram_wr_cmd_addr;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_data_dma_ram_wr_cmd_data;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_wr_cmd_valid;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_wr_cmd_ready;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_wr_done;
wire [IF_COUNT_INT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_data_dma_ram_rd_cmd_sel;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_data_dma_ram_rd_cmd_addr;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_cmd_valid;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_cmd_ready;
wire [IF_COUNT_INT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_data_dma_ram_rd_resp_data;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_resp_valid;
wire [IF_COUNT_INT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_resp_ready;

generate

if (IF_COUNT_INT > 1) begin : dma_if_mux

    dma_if_mux #(
        .PORTS(IF_COUNT_INT),
        .S_RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
        .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH-1),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .SEG_COUNT(RAM_SEG_COUNT),
        .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
        .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
        .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
        .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
        .IMM_ENABLE(DMA_IMM_ENABLE),
        .IMM_WIDTH(DMA_IMM_WIDTH),
        .LEN_WIDTH(DMA_LEN_WIDTH),
        .S_TAG_WIDTH(IF_DMA_TAG_WIDTH),
        .M_TAG_WIDTH(DMA_TAG_WIDTH-1),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    dma_if_mux_ctrl_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Read descriptor output (to DMA interface)
         */
        .m_axis_read_desc_dma_addr(ctrl_dma_read_desc_dma_addr),
        .m_axis_read_desc_ram_sel(ctrl_dma_read_desc_ram_sel),
        .m_axis_read_desc_ram_addr(ctrl_dma_read_desc_ram_addr),
        .m_axis_read_desc_len(ctrl_dma_read_desc_len),
        .m_axis_read_desc_tag(ctrl_dma_read_desc_tag),
        .m_axis_read_desc_valid(ctrl_dma_read_desc_valid),
        .m_axis_read_desc_ready(ctrl_dma_read_desc_ready),

        /*
         * Read descriptor status input (from DMA interface)
         */
        .s_axis_read_desc_status_tag(ctrl_dma_read_desc_status_tag),
        .s_axis_read_desc_status_error(ctrl_dma_read_desc_status_error),
        .s_axis_read_desc_status_valid(ctrl_dma_read_desc_status_valid),

        /*
         * Read descriptor input
         */
        .s_axis_read_desc_dma_addr(if_ctrl_dma_read_desc_dma_addr),
        .s_axis_read_desc_ram_sel(if_ctrl_dma_read_desc_ram_sel),
        .s_axis_read_desc_ram_addr(if_ctrl_dma_read_desc_ram_addr),
        .s_axis_read_desc_len(if_ctrl_dma_read_desc_len),
        .s_axis_read_desc_tag(if_ctrl_dma_read_desc_tag),
        .s_axis_read_desc_valid(if_ctrl_dma_read_desc_valid),
        .s_axis_read_desc_ready(if_ctrl_dma_read_desc_ready),

        /*
         * Read descriptor status output
         */
        .m_axis_read_desc_status_tag(if_ctrl_dma_read_desc_status_tag),
        .m_axis_read_desc_status_error(if_ctrl_dma_read_desc_status_error),
        .m_axis_read_desc_status_valid(if_ctrl_dma_read_desc_status_valid),

        /*
         * Write descriptor output (to DMA interface)
         */
        .m_axis_write_desc_dma_addr(ctrl_dma_write_desc_dma_addr),
        .m_axis_write_desc_ram_sel(ctrl_dma_write_desc_ram_sel),
        .m_axis_write_desc_ram_addr(ctrl_dma_write_desc_ram_addr),
        .m_axis_write_desc_imm(ctrl_dma_write_desc_imm),
        .m_axis_write_desc_imm_en(ctrl_dma_write_desc_imm_en),
        .m_axis_write_desc_len(ctrl_dma_write_desc_len),
        .m_axis_write_desc_tag(ctrl_dma_write_desc_tag),
        .m_axis_write_desc_valid(ctrl_dma_write_desc_valid),
        .m_axis_write_desc_ready(ctrl_dma_write_desc_ready),

        /*
         * Write descriptor status input (from DMA interface)
         */
        .s_axis_write_desc_status_tag(ctrl_dma_write_desc_status_tag),
        .s_axis_write_desc_status_error(ctrl_dma_write_desc_status_error),
        .s_axis_write_desc_status_valid(ctrl_dma_write_desc_status_valid),

        /*
         * Write descriptor input
         */
        .s_axis_write_desc_dma_addr(if_ctrl_dma_write_desc_dma_addr),
        .s_axis_write_desc_ram_sel(if_ctrl_dma_write_desc_ram_sel),
        .s_axis_write_desc_ram_addr(if_ctrl_dma_write_desc_ram_addr),
        .s_axis_write_desc_imm(if_ctrl_dma_write_desc_imm),
        .s_axis_write_desc_imm_en(if_ctrl_dma_write_desc_imm_en),
        .s_axis_write_desc_len(if_ctrl_dma_write_desc_len),
        .s_axis_write_desc_tag(if_ctrl_dma_write_desc_tag),
        .s_axis_write_desc_valid(if_ctrl_dma_write_desc_valid),
        .s_axis_write_desc_ready(if_ctrl_dma_write_desc_ready),

        /*
         * Write descriptor status output
         */
        .m_axis_write_desc_status_tag(if_ctrl_dma_write_desc_status_tag),
        .m_axis_write_desc_status_error(if_ctrl_dma_write_desc_status_error),
        .m_axis_write_desc_status_valid(if_ctrl_dma_write_desc_status_valid),

        /*
         * RAM interface (from DMA interface)
         */
        .if_ram_wr_cmd_sel(ctrl_dma_ram_wr_cmd_sel),
        .if_ram_wr_cmd_be(ctrl_dma_ram_wr_cmd_be),
        .if_ram_wr_cmd_addr(ctrl_dma_ram_wr_cmd_addr),
        .if_ram_wr_cmd_data(ctrl_dma_ram_wr_cmd_data),
        .if_ram_wr_cmd_valid(ctrl_dma_ram_wr_cmd_valid),
        .if_ram_wr_cmd_ready(ctrl_dma_ram_wr_cmd_ready),
        .if_ram_wr_done(ctrl_dma_ram_wr_done),
        .if_ram_rd_cmd_sel(ctrl_dma_ram_rd_cmd_sel),
        .if_ram_rd_cmd_addr(ctrl_dma_ram_rd_cmd_addr),
        .if_ram_rd_cmd_valid(ctrl_dma_ram_rd_cmd_valid),
        .if_ram_rd_cmd_ready(ctrl_dma_ram_rd_cmd_ready),
        .if_ram_rd_resp_data(ctrl_dma_ram_rd_resp_data),
        .if_ram_rd_resp_valid(ctrl_dma_ram_rd_resp_valid),
        .if_ram_rd_resp_ready(ctrl_dma_ram_rd_resp_ready),

        /*
         * RAM interface
         */
        .ram_wr_cmd_sel(if_ctrl_dma_ram_wr_cmd_sel),
        .ram_wr_cmd_be(if_ctrl_dma_ram_wr_cmd_be),
        .ram_wr_cmd_addr(if_ctrl_dma_ram_wr_cmd_addr),
        .ram_wr_cmd_data(if_ctrl_dma_ram_wr_cmd_data),
        .ram_wr_cmd_valid(if_ctrl_dma_ram_wr_cmd_valid),
        .ram_wr_cmd_ready(if_ctrl_dma_ram_wr_cmd_ready),
        .ram_wr_done(if_ctrl_dma_ram_wr_done),
        .ram_rd_cmd_sel(if_ctrl_dma_ram_rd_cmd_sel),
        .ram_rd_cmd_addr(if_ctrl_dma_ram_rd_cmd_addr),
        .ram_rd_cmd_valid(if_ctrl_dma_ram_rd_cmd_valid),
        .ram_rd_cmd_ready(if_ctrl_dma_ram_rd_cmd_ready),
        .ram_rd_resp_data(if_ctrl_dma_ram_rd_resp_data),
        .ram_rd_resp_valid(if_ctrl_dma_ram_rd_resp_valid),
        .ram_rd_resp_ready(if_ctrl_dma_ram_rd_resp_ready)
    );

    dma_if_mux #(
        .PORTS(IF_COUNT_INT),
        .S_RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
        .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH-1),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .SEG_COUNT(RAM_SEG_COUNT),
        .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
        .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
        .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
        .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
        .IMM_ENABLE(DMA_IMM_ENABLE),
        .IMM_WIDTH(DMA_IMM_WIDTH),
        .LEN_WIDTH(DMA_LEN_WIDTH),
        .S_TAG_WIDTH(IF_DMA_TAG_WIDTH),
        .M_TAG_WIDTH(DMA_TAG_WIDTH-1),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    dma_if_mux_data_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Read descriptor output (to DMA interface)
         */
        .m_axis_read_desc_dma_addr(data_dma_read_desc_dma_addr),
        .m_axis_read_desc_ram_sel(data_dma_read_desc_ram_sel),
        .m_axis_read_desc_ram_addr(data_dma_read_desc_ram_addr),
        .m_axis_read_desc_len(data_dma_read_desc_len),
        .m_axis_read_desc_tag(data_dma_read_desc_tag),
        .m_axis_read_desc_valid(data_dma_read_desc_valid),
        .m_axis_read_desc_ready(data_dma_read_desc_ready),

        /*
         * Read descriptor status input (from DMA interface)
         */
        .s_axis_read_desc_status_tag(data_dma_read_desc_status_tag),
        .s_axis_read_desc_status_error(data_dma_read_desc_status_error),
        .s_axis_read_desc_status_valid(data_dma_read_desc_status_valid),

        /*
         * Read descriptor input
         */
        .s_axis_read_desc_dma_addr(if_data_dma_read_desc_dma_addr),
        .s_axis_read_desc_ram_sel(if_data_dma_read_desc_ram_sel),
        .s_axis_read_desc_ram_addr(if_data_dma_read_desc_ram_addr),
        .s_axis_read_desc_len(if_data_dma_read_desc_len),
        .s_axis_read_desc_tag(if_data_dma_read_desc_tag),
        .s_axis_read_desc_valid(if_data_dma_read_desc_valid),
        .s_axis_read_desc_ready(if_data_dma_read_desc_ready),

        /*
         * Read descriptor status output
         */
        .m_axis_read_desc_status_tag(if_data_dma_read_desc_status_tag),
        .m_axis_read_desc_status_error(if_data_dma_read_desc_status_error),
        .m_axis_read_desc_status_valid(if_data_dma_read_desc_status_valid),

        /*
         * Write descriptor output (to DMA interface)
         */
        .m_axis_write_desc_dma_addr(data_dma_write_desc_dma_addr),
        .m_axis_write_desc_ram_sel(data_dma_write_desc_ram_sel),
        .m_axis_write_desc_ram_addr(data_dma_write_desc_ram_addr),
        .m_axis_write_desc_imm(data_dma_write_desc_imm),
        .m_axis_write_desc_imm_en(data_dma_write_desc_imm_en),
        .m_axis_write_desc_len(data_dma_write_desc_len),
        .m_axis_write_desc_tag(data_dma_write_desc_tag),
        .m_axis_write_desc_valid(data_dma_write_desc_valid),
        .m_axis_write_desc_ready(data_dma_write_desc_ready),

        /*
         * Write descriptor status input (from DMA interface)
         */
        .s_axis_write_desc_status_tag(data_dma_write_desc_status_tag),
        .s_axis_write_desc_status_error(data_dma_write_desc_status_error),
        .s_axis_write_desc_status_valid(data_dma_write_desc_status_valid),

        /*
         * Write descriptor input
         */
        .s_axis_write_desc_dma_addr(if_data_dma_write_desc_dma_addr),
        .s_axis_write_desc_ram_sel(if_data_dma_write_desc_ram_sel),
        .s_axis_write_desc_ram_addr(if_data_dma_write_desc_ram_addr),
        .s_axis_write_desc_imm(if_data_dma_write_desc_imm),
        .s_axis_write_desc_imm_en(if_data_dma_write_desc_imm_en),
        .s_axis_write_desc_len(if_data_dma_write_desc_len),
        .s_axis_write_desc_tag(if_data_dma_write_desc_tag),
        .s_axis_write_desc_valid(if_data_dma_write_desc_valid),
        .s_axis_write_desc_ready(if_data_dma_write_desc_ready),

        /*
         * Write descriptor status output
         */
        .m_axis_write_desc_status_tag(if_data_dma_write_desc_status_tag),
        .m_axis_write_desc_status_error(if_data_dma_write_desc_status_error),
        .m_axis_write_desc_status_valid(if_data_dma_write_desc_status_valid),

        /*
         * RAM interface (from DMA interface)
         */
        .if_ram_wr_cmd_sel(data_dma_ram_wr_cmd_sel),
        .if_ram_wr_cmd_be(data_dma_ram_wr_cmd_be),
        .if_ram_wr_cmd_addr(data_dma_ram_wr_cmd_addr),
        .if_ram_wr_cmd_data(data_dma_ram_wr_cmd_data),
        .if_ram_wr_cmd_valid(data_dma_ram_wr_cmd_valid),
        .if_ram_wr_cmd_ready(data_dma_ram_wr_cmd_ready),
        .if_ram_wr_done(data_dma_ram_wr_done),
        .if_ram_rd_cmd_sel(data_dma_ram_rd_cmd_sel),
        .if_ram_rd_cmd_addr(data_dma_ram_rd_cmd_addr),
        .if_ram_rd_cmd_valid(data_dma_ram_rd_cmd_valid),
        .if_ram_rd_cmd_ready(data_dma_ram_rd_cmd_ready),
        .if_ram_rd_resp_data(data_dma_ram_rd_resp_data),
        .if_ram_rd_resp_valid(data_dma_ram_rd_resp_valid),
        .if_ram_rd_resp_ready(data_dma_ram_rd_resp_ready),

        /*
         * RAM interface
         */
        .ram_wr_cmd_sel(if_data_dma_ram_wr_cmd_sel),
        .ram_wr_cmd_be(if_data_dma_ram_wr_cmd_be),
        .ram_wr_cmd_addr(if_data_dma_ram_wr_cmd_addr),
        .ram_wr_cmd_data(if_data_dma_ram_wr_cmd_data),
        .ram_wr_cmd_valid(if_data_dma_ram_wr_cmd_valid),
        .ram_wr_cmd_ready(if_data_dma_ram_wr_cmd_ready),
        .ram_wr_done(if_data_dma_ram_wr_done),
        .ram_rd_cmd_sel(if_data_dma_ram_rd_cmd_sel),
        .ram_rd_cmd_addr(if_data_dma_ram_rd_cmd_addr),
        .ram_rd_cmd_valid(if_data_dma_ram_rd_cmd_valid),
        .ram_rd_cmd_ready(if_data_dma_ram_rd_cmd_ready),
        .ram_rd_resp_data(if_data_dma_ram_rd_resp_data),
        .ram_rd_resp_valid(if_data_dma_ram_rd_resp_valid),
        .ram_rd_resp_ready(if_data_dma_ram_rd_resp_ready)
    );

end else begin

    assign ctrl_dma_read_desc_dma_addr = if_ctrl_dma_read_desc_dma_addr;
    assign ctrl_dma_read_desc_ram_sel = if_ctrl_dma_read_desc_ram_sel;
    assign ctrl_dma_read_desc_ram_addr = if_ctrl_dma_read_desc_ram_addr;
    assign ctrl_dma_read_desc_len = if_ctrl_dma_read_desc_len;
    assign ctrl_dma_read_desc_tag = if_ctrl_dma_read_desc_tag;
    assign ctrl_dma_read_desc_valid = if_ctrl_dma_read_desc_valid;
    assign if_ctrl_dma_read_desc_ready = ctrl_dma_read_desc_ready;

    assign if_ctrl_dma_read_desc_status_tag = ctrl_dma_read_desc_status_tag;
    assign if_ctrl_dma_read_desc_status_error = ctrl_dma_read_desc_status_error;
    assign if_ctrl_dma_read_desc_status_valid = ctrl_dma_read_desc_status_valid;

    assign ctrl_dma_write_desc_dma_addr = if_ctrl_dma_write_desc_dma_addr;
    assign ctrl_dma_write_desc_ram_sel = if_ctrl_dma_write_desc_ram_sel;
    assign ctrl_dma_write_desc_ram_addr = if_ctrl_dma_write_desc_ram_addr;
    assign ctrl_dma_write_desc_imm = if_ctrl_dma_write_desc_imm;
    assign ctrl_dma_write_desc_imm_en = if_ctrl_dma_write_desc_imm_en;
    assign ctrl_dma_write_desc_len = if_ctrl_dma_write_desc_len;
    assign ctrl_dma_write_desc_tag = if_ctrl_dma_write_desc_tag;
    assign ctrl_dma_write_desc_valid = if_ctrl_dma_write_desc_valid;
    assign if_ctrl_dma_write_desc_ready = ctrl_dma_write_desc_ready;

    assign if_ctrl_dma_write_desc_status_tag = ctrl_dma_write_desc_status_tag;
    assign if_ctrl_dma_write_desc_status_error = ctrl_dma_write_desc_status_error;
    assign if_ctrl_dma_write_desc_status_valid = ctrl_dma_write_desc_status_valid;

    assign if_ctrl_dma_ram_wr_cmd_sel = ctrl_dma_ram_wr_cmd_sel;
    assign if_ctrl_dma_ram_wr_cmd_be = ctrl_dma_ram_wr_cmd_be;
    assign if_ctrl_dma_ram_wr_cmd_addr = ctrl_dma_ram_wr_cmd_addr;
    assign if_ctrl_dma_ram_wr_cmd_data = ctrl_dma_ram_wr_cmd_data;
    assign if_ctrl_dma_ram_wr_cmd_valid = ctrl_dma_ram_wr_cmd_valid;
    assign ctrl_dma_ram_wr_cmd_ready = if_ctrl_dma_ram_wr_cmd_ready;
    assign ctrl_dma_ram_wr_done = if_ctrl_dma_ram_wr_done;
    assign if_ctrl_dma_ram_rd_cmd_sel = ctrl_dma_ram_rd_cmd_sel;
    assign if_ctrl_dma_ram_rd_cmd_addr = ctrl_dma_ram_rd_cmd_addr;
    assign if_ctrl_dma_ram_rd_cmd_valid = ctrl_dma_ram_rd_cmd_valid;
    assign ctrl_dma_ram_rd_cmd_ready = if_ctrl_dma_ram_rd_cmd_ready;
    assign ctrl_dma_ram_rd_resp_data = if_ctrl_dma_ram_rd_resp_data;
    assign ctrl_dma_ram_rd_resp_valid = if_ctrl_dma_ram_rd_resp_valid;
    assign if_ctrl_dma_ram_rd_resp_ready = ctrl_dma_ram_rd_resp_ready;

    assign data_dma_read_desc_dma_addr = if_data_dma_read_desc_dma_addr;
    assign data_dma_read_desc_ram_sel = if_data_dma_read_desc_ram_sel;
    assign data_dma_read_desc_ram_addr = if_data_dma_read_desc_ram_addr;
    assign data_dma_read_desc_len = if_data_dma_read_desc_len;
    assign data_dma_read_desc_tag = if_data_dma_read_desc_tag;
    assign data_dma_read_desc_valid = if_data_dma_read_desc_valid;
    assign if_data_dma_read_desc_ready = data_dma_read_desc_ready;

    assign if_data_dma_read_desc_status_tag = data_dma_read_desc_status_tag;
    assign if_data_dma_read_desc_status_error = data_dma_read_desc_status_error;
    assign if_data_dma_read_desc_status_valid = data_dma_read_desc_status_valid;

    assign data_dma_write_desc_dma_addr = if_data_dma_write_desc_dma_addr;
    assign data_dma_write_desc_ram_sel = if_data_dma_write_desc_ram_sel;
    assign data_dma_write_desc_ram_addr = if_data_dma_write_desc_ram_addr;
    assign data_dma_write_desc_imm = if_data_dma_write_desc_imm;
    assign data_dma_write_desc_imm_en = if_data_dma_write_desc_imm_en;
    assign data_dma_write_desc_len = if_data_dma_write_desc_len;
    assign data_dma_write_desc_tag = if_data_dma_write_desc_tag;
    assign data_dma_write_desc_valid = if_data_dma_write_desc_valid;
    assign if_data_dma_write_desc_ready = data_dma_write_desc_ready;

    assign if_data_dma_write_desc_status_tag = data_dma_write_desc_status_tag;
    assign if_data_dma_write_desc_status_error = data_dma_write_desc_status_error;
    assign if_data_dma_write_desc_status_valid = data_dma_write_desc_status_valid;

    assign if_data_dma_ram_wr_cmd_sel = data_dma_ram_wr_cmd_sel;
    assign if_data_dma_ram_wr_cmd_be = data_dma_ram_wr_cmd_be;
    assign if_data_dma_ram_wr_cmd_addr = data_dma_ram_wr_cmd_addr;
    assign if_data_dma_ram_wr_cmd_data = data_dma_ram_wr_cmd_data;
    assign if_data_dma_ram_wr_cmd_valid = data_dma_ram_wr_cmd_valid;
    assign data_dma_ram_wr_cmd_ready = if_data_dma_ram_wr_cmd_ready;
    assign data_dma_ram_wr_done = if_data_dma_ram_wr_done;
    assign if_data_dma_ram_rd_cmd_sel = data_dma_ram_rd_cmd_sel;
    assign if_data_dma_ram_rd_cmd_addr = data_dma_ram_rd_cmd_addr;
    assign if_data_dma_ram_rd_cmd_valid = data_dma_ram_rd_cmd_valid;
    assign data_dma_ram_rd_cmd_ready = if_data_dma_ram_rd_cmd_ready;
    assign data_dma_ram_rd_resp_data = if_data_dma_ram_rd_resp_data;
    assign data_dma_ram_rd_resp_valid = if_data_dma_ram_rd_resp_valid;
    assign if_data_dma_ram_rd_resp_ready = data_dma_ram_rd_resp_ready;

end

endgenerate

wire [DMA_ADDR_WIDTH-1:0]    app_ctrl_dma_read_desc_dma_addr;
wire [IF_RAM_SEL_WIDTH-1:0]  app_ctrl_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]    app_ctrl_dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]     app_ctrl_dma_read_desc_len;
wire [IF_DMA_TAG_WIDTH-1:0]  app_ctrl_dma_read_desc_tag;
wire                         app_ctrl_dma_read_desc_valid;
wire                         app_ctrl_dma_read_desc_ready;

wire [IF_DMA_TAG_WIDTH-1:0]  app_ctrl_dma_read_desc_status_tag;
wire [3:0]                   app_ctrl_dma_read_desc_status_error;
wire                         app_ctrl_dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]    app_ctrl_dma_write_desc_dma_addr;
wire [IF_RAM_SEL_WIDTH-1:0]  app_ctrl_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]    app_ctrl_dma_write_desc_ram_addr;
wire [DMA_IMM_WIDTH-1:0]     app_ctrl_dma_write_desc_imm;
wire                         app_ctrl_dma_write_desc_imm_en;
wire [DMA_LEN_WIDTH-1:0]     app_ctrl_dma_write_desc_len;
wire [IF_DMA_TAG_WIDTH-1:0]  app_ctrl_dma_write_desc_tag;
wire                         app_ctrl_dma_write_desc_valid;
wire                         app_ctrl_dma_write_desc_ready;

wire [IF_DMA_TAG_WIDTH-1:0]  app_ctrl_dma_write_desc_status_tag;
wire [3:0]                   app_ctrl_dma_write_desc_status_error;
wire                         app_ctrl_dma_write_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]    app_data_dma_read_desc_dma_addr;
wire [IF_RAM_SEL_WIDTH-1:0]  app_data_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]    app_data_dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]     app_data_dma_read_desc_len;
wire [IF_DMA_TAG_WIDTH-1:0]  app_data_dma_read_desc_tag;
wire                         app_data_dma_read_desc_valid;
wire                         app_data_dma_read_desc_ready;

wire [IF_DMA_TAG_WIDTH-1:0]  app_data_dma_read_desc_status_tag;
wire [3:0]                   app_data_dma_read_desc_status_error;
wire                         app_data_dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]    app_data_dma_write_desc_dma_addr;
wire [IF_RAM_SEL_WIDTH-1:0]  app_data_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]    app_data_dma_write_desc_ram_addr;
wire [DMA_IMM_WIDTH-1:0]     app_data_dma_write_desc_imm;
wire                         app_data_dma_write_desc_imm_en;
wire [DMA_LEN_WIDTH-1:0]     app_data_dma_write_desc_len;
wire [IF_DMA_TAG_WIDTH-1:0]  app_data_dma_write_desc_tag;
wire                         app_data_dma_write_desc_valid;
wire                         app_data_dma_write_desc_ready;

wire [IF_DMA_TAG_WIDTH-1:0]  app_data_dma_write_desc_status_tag;
wire [3:0]                   app_data_dma_write_desc_status_error;
wire                         app_data_dma_write_desc_status_valid;

wire [RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    app_ctrl_dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    app_ctrl_dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  app_ctrl_dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  app_ctrl_dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     app_ctrl_dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     app_ctrl_dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     app_ctrl_dma_ram_wr_done;
wire [RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    app_ctrl_dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  app_ctrl_dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     app_ctrl_dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     app_ctrl_dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  app_ctrl_dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     app_ctrl_dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     app_ctrl_dma_ram_rd_resp_ready;

wire [RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    app_data_dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    app_data_dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  app_data_dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  app_data_dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     app_data_dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     app_data_dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     app_data_dma_ram_wr_done;
wire [RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    app_data_dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  app_data_dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     app_data_dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     app_data_dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  app_data_dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     app_data_dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     app_data_dma_ram_rd_resp_ready;

generate

if (APP_ENABLE && APP_DMA_ENABLE) begin

    assign if_ctrl_dma_read_desc_dma_addr[IF_COUNT*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH] = app_ctrl_dma_read_desc_dma_addr;
    assign if_ctrl_dma_read_desc_ram_sel[IF_COUNT*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH] = app_ctrl_dma_read_desc_ram_sel;
    assign if_ctrl_dma_read_desc_ram_addr[IF_COUNT*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH] = app_ctrl_dma_read_desc_ram_addr;
    assign if_ctrl_dma_read_desc_len[IF_COUNT*DMA_LEN_WIDTH +: DMA_LEN_WIDTH] = app_ctrl_dma_read_desc_len;
    assign if_ctrl_dma_read_desc_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH] = app_ctrl_dma_read_desc_tag;
    assign if_ctrl_dma_read_desc_valid[IF_COUNT] = app_ctrl_dma_read_desc_valid;
    assign app_ctrl_dma_read_desc_ready = if_ctrl_dma_read_desc_ready[IF_COUNT];

    assign app_ctrl_dma_read_desc_status_tag = if_ctrl_dma_read_desc_status_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH];
    assign app_ctrl_dma_read_desc_status_error = if_ctrl_dma_read_desc_status_error[IF_COUNT*4 +: 4];
    assign app_ctrl_dma_read_desc_status_valid = if_ctrl_dma_read_desc_status_valid[IF_COUNT];

    assign if_ctrl_dma_write_desc_dma_addr[IF_COUNT*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH] = app_ctrl_dma_write_desc_dma_addr;
    assign if_ctrl_dma_write_desc_ram_sel[IF_COUNT*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH] = app_ctrl_dma_write_desc_ram_sel;
    assign if_ctrl_dma_write_desc_ram_addr[IF_COUNT*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH] = app_ctrl_dma_write_desc_ram_addr;
    assign if_ctrl_dma_write_desc_imm[IF_COUNT*DMA_IMM_WIDTH +: DMA_IMM_WIDTH] = app_ctrl_dma_write_desc_imm;
    assign if_ctrl_dma_write_desc_imm_en[IF_COUNT] = app_ctrl_dma_write_desc_imm_en;
    assign if_ctrl_dma_write_desc_len[IF_COUNT*DMA_LEN_WIDTH +: DMA_LEN_WIDTH] = app_ctrl_dma_write_desc_len;
    assign if_ctrl_dma_write_desc_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH] = app_ctrl_dma_write_desc_tag;
    assign if_ctrl_dma_write_desc_valid[IF_COUNT] = app_ctrl_dma_write_desc_valid;
    assign app_ctrl_dma_write_desc_ready = if_ctrl_dma_write_desc_ready[IF_COUNT];

    assign app_ctrl_dma_write_desc_status_tag = if_ctrl_dma_write_desc_status_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH];
    assign app_ctrl_dma_write_desc_status_error = if_ctrl_dma_write_desc_status_error[IF_COUNT*4 +: 4];
    assign app_ctrl_dma_write_desc_status_valid = if_ctrl_dma_write_desc_status_valid[IF_COUNT];

    assign if_data_dma_read_desc_dma_addr[IF_COUNT*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH] = app_data_dma_read_desc_dma_addr;
    assign if_data_dma_read_desc_ram_sel[IF_COUNT*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH] = app_data_dma_read_desc_ram_sel;
    assign if_data_dma_read_desc_ram_addr[IF_COUNT*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH] = app_data_dma_read_desc_ram_addr;
    assign if_data_dma_read_desc_len[IF_COUNT*DMA_LEN_WIDTH +: DMA_LEN_WIDTH] = app_data_dma_read_desc_len;
    assign if_data_dma_read_desc_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH] = app_data_dma_read_desc_tag;
    assign if_data_dma_read_desc_valid[IF_COUNT] = app_data_dma_read_desc_valid;
    assign app_data_dma_read_desc_ready = if_data_dma_read_desc_ready[IF_COUNT];

    assign app_data_dma_read_desc_status_tag = if_data_dma_read_desc_status_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH];
    assign app_data_dma_read_desc_status_error = if_data_dma_read_desc_status_error[IF_COUNT*4 +: 4];
    assign app_data_dma_read_desc_status_valid = if_data_dma_read_desc_status_valid[IF_COUNT];

    assign if_data_dma_write_desc_dma_addr[IF_COUNT*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH] = app_data_dma_write_desc_dma_addr;
    assign if_data_dma_write_desc_ram_sel[IF_COUNT*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH] = app_data_dma_write_desc_ram_sel;
    assign if_data_dma_write_desc_ram_addr[IF_COUNT*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH] = app_data_dma_write_desc_ram_addr;
    assign if_data_dma_write_desc_imm[IF_COUNT*DMA_IMM_WIDTH +: DMA_IMM_WIDTH] = app_data_dma_write_desc_imm;
    assign if_data_dma_write_desc_imm_en[IF_COUNT] = app_data_dma_write_desc_imm_en;
    assign if_data_dma_write_desc_len[IF_COUNT*DMA_LEN_WIDTH +: DMA_LEN_WIDTH] = app_data_dma_write_desc_len;
    assign if_data_dma_write_desc_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH] = app_data_dma_write_desc_tag;
    assign if_data_dma_write_desc_valid[IF_COUNT] = app_data_dma_write_desc_valid;
    assign app_data_dma_write_desc_ready = if_data_dma_write_desc_ready[IF_COUNT];

    assign app_data_dma_write_desc_status_tag = if_data_dma_write_desc_status_tag[IF_COUNT*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH];
    assign app_data_dma_write_desc_status_error = if_data_dma_write_desc_status_error[IF_COUNT*4 +: 4];
    assign app_data_dma_write_desc_status_valid = if_data_dma_write_desc_status_valid[IF_COUNT];

    assign app_ctrl_dma_ram_wr_cmd_sel = if_ctrl_dma_ram_wr_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*IF_COUNT +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH];
    assign app_ctrl_dma_ram_wr_cmd_be = if_ctrl_dma_ram_wr_cmd_be[RAM_SEG_COUNT*RAM_SEG_BE_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_BE_WIDTH];
    assign app_ctrl_dma_ram_wr_cmd_addr = if_ctrl_dma_ram_wr_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH];
    assign app_ctrl_dma_ram_wr_cmd_data = if_ctrl_dma_ram_wr_cmd_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH];
    assign app_ctrl_dma_ram_wr_cmd_valid = if_ctrl_dma_ram_wr_cmd_valid[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT];
    assign if_ctrl_dma_ram_wr_cmd_ready[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_ctrl_dma_ram_wr_cmd_ready;
    assign if_ctrl_dma_ram_wr_done[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_ctrl_dma_ram_wr_done;
    assign app_ctrl_dma_ram_rd_cmd_sel = if_ctrl_dma_ram_rd_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*IF_COUNT +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH];
    assign app_ctrl_dma_ram_rd_cmd_addr = if_ctrl_dma_ram_rd_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH];
    assign app_ctrl_dma_ram_rd_cmd_valid = if_ctrl_dma_ram_rd_cmd_valid[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT];
    assign if_ctrl_dma_ram_rd_cmd_ready[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_ctrl_dma_ram_rd_cmd_ready;
    assign if_ctrl_dma_ram_rd_resp_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH] = app_ctrl_dma_ram_rd_resp_data;
    assign if_ctrl_dma_ram_rd_resp_valid[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_ctrl_dma_ram_rd_resp_valid;
    assign app_ctrl_dma_ram_rd_resp_ready = if_ctrl_dma_ram_rd_resp_ready[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT];

    assign app_data_dma_ram_wr_cmd_sel = if_data_dma_ram_wr_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*IF_COUNT +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH];
    assign app_data_dma_ram_wr_cmd_be = if_data_dma_ram_wr_cmd_be[RAM_SEG_COUNT*RAM_SEG_BE_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_BE_WIDTH];
    assign app_data_dma_ram_wr_cmd_addr = if_data_dma_ram_wr_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH];
    assign app_data_dma_ram_wr_cmd_data = if_data_dma_ram_wr_cmd_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH];
    assign app_data_dma_ram_wr_cmd_valid = if_data_dma_ram_wr_cmd_valid[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT];
    assign if_data_dma_ram_wr_cmd_ready[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_data_dma_ram_wr_cmd_ready;
    assign if_data_dma_ram_wr_done[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_data_dma_ram_wr_done;
    assign app_data_dma_ram_rd_cmd_sel = if_data_dma_ram_rd_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*IF_COUNT +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH];
    assign app_data_dma_ram_rd_cmd_addr = if_data_dma_ram_rd_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH];
    assign app_data_dma_ram_rd_cmd_valid = if_data_dma_ram_rd_cmd_valid[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT];
    assign if_data_dma_ram_rd_cmd_ready[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_data_dma_ram_rd_cmd_ready;
    assign if_data_dma_ram_rd_resp_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*IF_COUNT +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH] = app_data_dma_ram_rd_resp_data;
    assign if_data_dma_ram_rd_resp_valid[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT] = app_data_dma_ram_rd_resp_valid;
    assign app_data_dma_ram_rd_resp_ready = if_data_dma_ram_rd_resp_ready[RAM_SEG_COUNT*IF_COUNT +: RAM_SEG_COUNT];

end else begin

    assign app_ctrl_dma_read_desc_ready = 0;

    assign app_ctrl_dma_read_desc_status_tag = 0;
    assign app_ctrl_dma_read_desc_status_error = 0;
    assign app_ctrl_dma_read_desc_status_valid = 0;

    assign app_ctrl_dma_write_desc_ready = 0;

    assign app_ctrl_dma_write_desc_status_tag = 0;
    assign app_ctrl_dma_write_desc_status_error = 0;
    assign app_ctrl_dma_write_desc_status_valid = 0;

    assign app_data_dma_read_desc_ready = 0;

    assign app_data_dma_read_desc_status_tag = 0;
    assign app_data_dma_read_desc_status_error = 0;
    assign app_data_dma_read_desc_status_valid = 0;

    assign app_data_dma_write_desc_ready = 0;

    assign app_data_dma_write_desc_status_tag = 0;
    assign app_data_dma_write_desc_status_error = 0;
    assign app_data_dma_write_desc_status_valid = 0;

    assign app_ctrl_dma_ram_wr_cmd_sel = 0;
    assign app_ctrl_dma_ram_wr_cmd_be = 0;
    assign app_ctrl_dma_ram_wr_cmd_addr = 0;
    assign app_ctrl_dma_ram_wr_cmd_data = 0;
    assign app_ctrl_dma_ram_wr_cmd_valid = 0;
    assign app_ctrl_dma_ram_rd_cmd_sel = 0;
    assign app_ctrl_dma_ram_rd_cmd_addr = 0;
    assign app_ctrl_dma_ram_rd_cmd_valid = 0;
    assign app_ctrl_dma_ram_rd_resp_ready = 0;

    assign app_data_dma_ram_wr_cmd_sel = 0;
    assign app_data_dma_ram_wr_cmd_be = 0;
    assign app_data_dma_ram_wr_cmd_addr = 0;
    assign app_data_dma_ram_wr_cmd_data = 0;
    assign app_data_dma_ram_wr_cmd_valid = 0;
    assign app_data_dma_ram_rd_cmd_sel = 0;
    assign app_data_dma_ram_rd_cmd_addr = 0;
    assign app_data_dma_ram_rd_cmd_valid = 0;
    assign app_data_dma_ram_rd_resp_ready = 0;

end

endgenerate

wire [IRQ_INDEX_WIDTH-1:0]  int_irq_index;
wire                        int_irq_valid;
wire                        int_irq_ready;

irq_rate_limit #(
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH)
)
irq_rate_limit_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Interrupt request input
     */
    .in_irq_index(int_irq_index),
    .in_irq_valid(int_irq_valid),
    .in_irq_ready(int_irq_ready),

    /*
     * Interrupt request output
     */
    .out_irq_index(irq_index),
    .out_irq_valid(irq_valid),
    .out_irq_ready(irq_ready),

    /*
     * Configuration
     */
    .prescale(CLK_CYCLES_PER_US-1),
    .min_interval(irq_rate_limit_min_interval_reg)
);

wire [IF_COUNT*IRQ_INDEX_WIDTH-1:0]  if_irq_index;
wire [IF_COUNT-1:0]                  if_irq_valid;
wire [IF_COUNT-1:0]                  if_irq_ready;

generate

if (IF_COUNT > 1) begin : irq_mux

    axis_arb_mux #(
        .S_COUNT(IF_COUNT),
        .DATA_WIDTH(IRQ_INDEX_WIDTH),
        .KEEP_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .LAST_ENABLE(0),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    axis_irq_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI Stream inputs
         */
        .s_axis_tdata(if_irq_index),
        .s_axis_tkeep(0),
        .s_axis_tvalid(if_irq_valid),
        .s_axis_tready(if_irq_ready),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        /*
         * AXI Stream output
         */
        .m_axis_tdata(int_irq_index),
        .m_axis_tkeep(),
        .m_axis_tvalid(int_irq_valid),
        .m_axis_tready(int_irq_ready),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser()
    );

end else begin

    assign int_irq_index = if_irq_index;
    assign int_irq_valid = if_irq_valid;
    assign if_irq_ready = int_irq_ready;

end

endgenerate

// RAM infrastructure
wire [DDR_CH-1:0]                            app_ddr_clk;
wire [DDR_CH-1:0]                            app_ddr_rst;

wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           app_m_axi_ddr_awid;
wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]         app_m_axi_ddr_awaddr;
wire [DDR_CH*8-1:0]                          app_m_axi_ddr_awlen;
wire [DDR_CH*3-1:0]                          app_m_axi_ddr_awsize;
wire [DDR_CH*2-1:0]                          app_m_axi_ddr_awburst;
wire [DDR_CH-1:0]                            app_m_axi_ddr_awlock;
wire [DDR_CH*4-1:0]                          app_m_axi_ddr_awcache;
wire [DDR_CH*3-1:0]                          app_m_axi_ddr_awprot;
wire [DDR_CH*4-1:0]                          app_m_axi_ddr_awqos;
wire [DDR_CH*AXI_DDR_AWUSER_WIDTH-1:0]       app_m_axi_ddr_awuser;
wire [DDR_CH-1:0]                            app_m_axi_ddr_awvalid;
wire [DDR_CH-1:0]                            app_m_axi_ddr_awready;
wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]         app_m_axi_ddr_wdata;
wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]         app_m_axi_ddr_wstrb;
wire [DDR_CH-1:0]                            app_m_axi_ddr_wlast;
wire [DDR_CH*AXI_DDR_WUSER_WIDTH-1:0]        app_m_axi_ddr_wuser;
wire [DDR_CH-1:0]                            app_m_axi_ddr_wvalid;
wire [DDR_CH-1:0]                            app_m_axi_ddr_wready;
wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           app_m_axi_ddr_bid;
wire [DDR_CH*2-1:0]                          app_m_axi_ddr_bresp;
wire [DDR_CH*AXI_DDR_BUSER_WIDTH-1:0]        app_m_axi_ddr_buser;
wire [DDR_CH-1:0]                            app_m_axi_ddr_bvalid;
wire [DDR_CH-1:0]                            app_m_axi_ddr_bready;
wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           app_m_axi_ddr_arid;
wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]         app_m_axi_ddr_araddr;
wire [DDR_CH*8-1:0]                          app_m_axi_ddr_arlen;
wire [DDR_CH*3-1:0]                          app_m_axi_ddr_arsize;
wire [DDR_CH*2-1:0]                          app_m_axi_ddr_arburst;
wire [DDR_CH-1:0]                            app_m_axi_ddr_arlock;
wire [DDR_CH*4-1:0]                          app_m_axi_ddr_arcache;
wire [DDR_CH*3-1:0]                          app_m_axi_ddr_arprot;
wire [DDR_CH*4-1:0]                          app_m_axi_ddr_arqos;
wire [DDR_CH*AXI_DDR_ARUSER_WIDTH-1:0]       app_m_axi_ddr_aruser;
wire [DDR_CH-1:0]                            app_m_axi_ddr_arvalid;
wire [DDR_CH-1:0]                            app_m_axi_ddr_arready;
wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]           app_m_axi_ddr_rid;
wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]         app_m_axi_ddr_rdata;
wire [DDR_CH*2-1:0]                          app_m_axi_ddr_rresp;
wire [DDR_CH-1:0]                            app_m_axi_ddr_rlast;
wire [DDR_CH*AXI_DDR_RUSER_WIDTH-1:0]        app_m_axi_ddr_ruser;
wire [DDR_CH-1:0]                            app_m_axi_ddr_rvalid;
wire [DDR_CH-1:0]                            app_m_axi_ddr_rready;

wire [DDR_CH-1:0]                            app_ddr_status;

wire [HBM_CH-1:0]                            app_hbm_clk;
wire [HBM_CH-1:0]                            app_hbm_rst;

wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           app_m_axi_hbm_awid;
wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]         app_m_axi_hbm_awaddr;
wire [HBM_CH*8-1:0]                          app_m_axi_hbm_awlen;
wire [HBM_CH*3-1:0]                          app_m_axi_hbm_awsize;
wire [HBM_CH*2-1:0]                          app_m_axi_hbm_awburst;
wire [HBM_CH-1:0]                            app_m_axi_hbm_awlock;
wire [HBM_CH*4-1:0]                          app_m_axi_hbm_awcache;
wire [HBM_CH*3-1:0]                          app_m_axi_hbm_awprot;
wire [HBM_CH*4-1:0]                          app_m_axi_hbm_awqos;
wire [HBM_CH*AXI_HBM_AWUSER_WIDTH-1:0]       app_m_axi_hbm_awuser;
wire [HBM_CH-1:0]                            app_m_axi_hbm_awvalid;
wire [HBM_CH-1:0]                            app_m_axi_hbm_awready;
wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]         app_m_axi_hbm_wdata;
wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]         app_m_axi_hbm_wstrb;
wire [HBM_CH-1:0]                            app_m_axi_hbm_wlast;
wire [HBM_CH*AXI_HBM_WUSER_WIDTH-1:0]        app_m_axi_hbm_wuser;
wire [HBM_CH-1:0]                            app_m_axi_hbm_wvalid;
wire [HBM_CH-1:0]                            app_m_axi_hbm_wready;
wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           app_m_axi_hbm_bid;
wire [HBM_CH*2-1:0]                          app_m_axi_hbm_bresp;
wire [HBM_CH*AXI_HBM_BUSER_WIDTH-1:0]        app_m_axi_hbm_buser;
wire [HBM_CH-1:0]                            app_m_axi_hbm_bvalid;
wire [HBM_CH-1:0]                            app_m_axi_hbm_bready;
wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           app_m_axi_hbm_arid;
wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]         app_m_axi_hbm_araddr;
wire [HBM_CH*8-1:0]                          app_m_axi_hbm_arlen;
wire [HBM_CH*3-1:0]                          app_m_axi_hbm_arsize;
wire [HBM_CH*2-1:0]                          app_m_axi_hbm_arburst;
wire [HBM_CH-1:0]                            app_m_axi_hbm_arlock;
wire [HBM_CH*4-1:0]                          app_m_axi_hbm_arcache;
wire [HBM_CH*3-1:0]                          app_m_axi_hbm_arprot;
wire [HBM_CH*4-1:0]                          app_m_axi_hbm_arqos;
wire [HBM_CH*AXI_HBM_ARUSER_WIDTH-1:0]       app_m_axi_hbm_aruser;
wire [HBM_CH-1:0]                            app_m_axi_hbm_arvalid;
wire [HBM_CH-1:0]                            app_m_axi_hbm_arready;
wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]           app_m_axi_hbm_rid;
wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]         app_m_axi_hbm_rdata;
wire [HBM_CH*2-1:0]                          app_m_axi_hbm_rresp;
wire [HBM_CH-1:0]                            app_m_axi_hbm_rlast;
wire [HBM_CH*AXI_HBM_RUSER_WIDTH-1:0]        app_m_axi_hbm_ruser;
wire [HBM_CH-1:0]                            app_m_axi_hbm_rvalid;
wire [HBM_CH-1:0]                            app_m_axi_hbm_rready;

wire [HBM_CH-1:0]                            app_hbm_status;

generate

if (DDR_ENABLE) begin : ddr

    mqnic_dram_if #(
        // RAM configuration
        .CH(DDR_CH),
        .GROUP_SIZE(DDR_GROUP_SIZE),
        .AXI_DATA_WIDTH(AXI_DDR_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_DDR_ADDR_WIDTH),
        .AXI_STRB_WIDTH(AXI_DDR_STRB_WIDTH),
        .AXI_ID_WIDTH(AXI_DDR_ID_WIDTH),
        .AXI_AWUSER_ENABLE(AXI_DDR_AWUSER_ENABLE),
        .AXI_AWUSER_WIDTH(AXI_DDR_AWUSER_WIDTH),
        .AXI_WUSER_ENABLE(AXI_DDR_WUSER_ENABLE),
        .AXI_WUSER_WIDTH(AXI_DDR_WUSER_WIDTH),
        .AXI_BUSER_ENABLE(AXI_DDR_BUSER_ENABLE),
        .AXI_BUSER_WIDTH(AXI_DDR_BUSER_WIDTH),
        .AXI_ARUSER_ENABLE(AXI_DDR_ARUSER_ENABLE),
        .AXI_ARUSER_WIDTH(AXI_DDR_ARUSER_WIDTH),
        .AXI_RUSER_ENABLE(AXI_DDR_RUSER_ENABLE),
        .AXI_RUSER_WIDTH(AXI_DDR_RUSER_WIDTH),
        .AXI_MAX_BURST_LEN(AXI_DDR_MAX_BURST_LEN),
        .AXI_NARROW_BURST(AXI_DDR_NARROW_BURST),
        .AXI_FIXED_BURST(AXI_DDR_FIXED_BURST),
        .AXI_WRAP_BURST(AXI_DDR_WRAP_BURST)
    )
    dram_if_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI to DRAM
         */
        .m_axi_clk(ddr_clk),
        .m_axi_rst(ddr_rst),

        .m_axi_awid(m_axi_ddr_awid),
        .m_axi_awaddr(m_axi_ddr_awaddr),
        .m_axi_awlen(m_axi_ddr_awlen),
        .m_axi_awsize(m_axi_ddr_awsize),
        .m_axi_awburst(m_axi_ddr_awburst),
        .m_axi_awlock(m_axi_ddr_awlock),
        .m_axi_awcache(m_axi_ddr_awcache),
        .m_axi_awprot(m_axi_ddr_awprot),
        .m_axi_awqos(m_axi_ddr_awqos),
        .m_axi_awuser(m_axi_ddr_awuser),
        .m_axi_awvalid(m_axi_ddr_awvalid),
        .m_axi_awready(m_axi_ddr_awready),
        .m_axi_wdata(m_axi_ddr_wdata),
        .m_axi_wstrb(m_axi_ddr_wstrb),
        .m_axi_wlast(m_axi_ddr_wlast),
        .m_axi_wuser(m_axi_ddr_wuser),
        .m_axi_wvalid(m_axi_ddr_wvalid),
        .m_axi_wready(m_axi_ddr_wready),
        .m_axi_bid(m_axi_ddr_bid),
        .m_axi_bresp(m_axi_ddr_bresp),
        .m_axi_buser(m_axi_ddr_buser),
        .m_axi_bvalid(m_axi_ddr_bvalid),
        .m_axi_bready(m_axi_ddr_bready),
        .m_axi_arid(m_axi_ddr_arid),
        .m_axi_araddr(m_axi_ddr_araddr),
        .m_axi_arlen(m_axi_ddr_arlen),
        .m_axi_arsize(m_axi_ddr_arsize),
        .m_axi_arburst(m_axi_ddr_arburst),
        .m_axi_arlock(m_axi_ddr_arlock),
        .m_axi_arcache(m_axi_ddr_arcache),
        .m_axi_arprot(m_axi_ddr_arprot),
        .m_axi_arqos(m_axi_ddr_arqos),
        .m_axi_aruser(m_axi_ddr_aruser),
        .m_axi_arvalid(m_axi_ddr_arvalid),
        .m_axi_arready(m_axi_ddr_arready),
        .m_axi_rid(m_axi_ddr_rid),
        .m_axi_rdata(m_axi_ddr_rdata),
        .m_axi_rresp(m_axi_ddr_rresp),
        .m_axi_rlast(m_axi_ddr_rlast),
        .m_axi_ruser(m_axi_ddr_ruser),
        .m_axi_rvalid(m_axi_ddr_rvalid),
        .m_axi_rready(m_axi_ddr_rready),

        .status_in(ddr_status),

        /*
         * AXI to application
         */
        .s_axi_app_clk(app_ddr_clk),
        .s_axi_app_rst(app_ddr_rst),

        .s_axi_app_awid(app_m_axi_ddr_awid),
        .s_axi_app_awaddr(app_m_axi_ddr_awaddr),
        .s_axi_app_awlen(app_m_axi_ddr_awlen),
        .s_axi_app_awsize(app_m_axi_ddr_awsize),
        .s_axi_app_awburst(app_m_axi_ddr_awburst),
        .s_axi_app_awlock(app_m_axi_ddr_awlock),
        .s_axi_app_awcache(app_m_axi_ddr_awcache),
        .s_axi_app_awprot(app_m_axi_ddr_awprot),
        .s_axi_app_awqos(app_m_axi_ddr_awqos),
        .s_axi_app_awuser(app_m_axi_ddr_awuser),
        .s_axi_app_awvalid(app_m_axi_ddr_awvalid),
        .s_axi_app_awready(app_m_axi_ddr_awready),
        .s_axi_app_wdata(app_m_axi_ddr_wdata),
        .s_axi_app_wstrb(app_m_axi_ddr_wstrb),
        .s_axi_app_wlast(app_m_axi_ddr_wlast),
        .s_axi_app_wuser(app_m_axi_ddr_wuser),
        .s_axi_app_wvalid(app_m_axi_ddr_wvalid),
        .s_axi_app_wready(app_m_axi_ddr_wready),
        .s_axi_app_bid(app_m_axi_ddr_bid),
        .s_axi_app_bresp(app_m_axi_ddr_bresp),
        .s_axi_app_buser(app_m_axi_ddr_buser),
        .s_axi_app_bvalid(app_m_axi_ddr_bvalid),
        .s_axi_app_bready(app_m_axi_ddr_bready),
        .s_axi_app_arid(app_m_axi_ddr_arid),
        .s_axi_app_araddr(app_m_axi_ddr_araddr),
        .s_axi_app_arlen(app_m_axi_ddr_arlen),
        .s_axi_app_arsize(app_m_axi_ddr_arsize),
        .s_axi_app_arburst(app_m_axi_ddr_arburst),
        .s_axi_app_arlock(app_m_axi_ddr_arlock),
        .s_axi_app_arcache(app_m_axi_ddr_arcache),
        .s_axi_app_arprot(app_m_axi_ddr_arprot),
        .s_axi_app_arqos(app_m_axi_ddr_arqos),
        .s_axi_app_aruser(app_m_axi_ddr_aruser),
        .s_axi_app_arvalid(app_m_axi_ddr_arvalid),
        .s_axi_app_arready(app_m_axi_ddr_arready),
        .s_axi_app_rid(app_m_axi_ddr_rid),
        .s_axi_app_rdata(app_m_axi_ddr_rdata),
        .s_axi_app_rresp(app_m_axi_ddr_rresp),
        .s_axi_app_rlast(app_m_axi_ddr_rlast),
        .s_axi_app_ruser(app_m_axi_ddr_ruser),
        .s_axi_app_rvalid(app_m_axi_ddr_rvalid),
        .s_axi_app_rready(app_m_axi_ddr_rready),

        .app_status(app_ddr_status)
    );

    assign all_clocks[PORT_COUNT*2 +: DDR_CH] = ddr_clk;

end else begin

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

    assign app_ddr_clk = 0;
    assign app_ddr_rst = 0;

    assign app_m_axi_ddr_awready = 0;
    assign app_m_axi_ddr_wready = 0;
    assign app_m_axi_ddr_bid = 0;
    assign app_m_axi_ddr_bresp = 0;
    assign app_m_axi_ddr_buser = 0;
    assign app_m_axi_ddr_bvalid = 0;
    assign app_m_axi_ddr_arready = 0;
    assign app_m_axi_ddr_rid = 0;
    assign app_m_axi_ddr_rdata = 0;
    assign app_m_axi_ddr_rresp = 0;
    assign app_m_axi_ddr_rlast = 0;
    assign app_m_axi_ddr_ruser = 0;
    assign app_m_axi_ddr_rvalid = 0;

    assign app_ddr_status = 0;

end

if (HBM_ENABLE) begin : hbm

    mqnic_dram_if #(
        // RAM configuration
        .CH(HBM_CH),
        .GROUP_SIZE(HBM_GROUP_SIZE),
        .AXI_DATA_WIDTH(AXI_HBM_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_HBM_ADDR_WIDTH),
        .AXI_STRB_WIDTH(AXI_HBM_STRB_WIDTH),
        .AXI_ID_WIDTH(AXI_HBM_ID_WIDTH),
        .AXI_AWUSER_ENABLE(AXI_HBM_AWUSER_ENABLE),
        .AXI_AWUSER_WIDTH(AXI_HBM_AWUSER_WIDTH),
        .AXI_WUSER_ENABLE(AXI_HBM_WUSER_ENABLE),
        .AXI_WUSER_WIDTH(AXI_HBM_WUSER_WIDTH),
        .AXI_BUSER_ENABLE(AXI_HBM_BUSER_ENABLE),
        .AXI_BUSER_WIDTH(AXI_HBM_BUSER_WIDTH),
        .AXI_ARUSER_ENABLE(AXI_HBM_ARUSER_ENABLE),
        .AXI_ARUSER_WIDTH(AXI_HBM_ARUSER_WIDTH),
        .AXI_RUSER_ENABLE(AXI_HBM_RUSER_ENABLE),
        .AXI_RUSER_WIDTH(AXI_HBM_RUSER_WIDTH),
        .AXI_MAX_BURST_LEN(AXI_HBM_MAX_BURST_LEN),
        .AXI_NARROW_BURST(AXI_HBM_NARROW_BURST),
        .AXI_FIXED_BURST(AXI_HBM_FIXED_BURST),
        .AXI_WRAP_BURST(AXI_HBM_WRAP_BURST)
    )
    dram_if_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI to DRAM
         */
        .m_axi_clk(hbm_clk),
        .m_axi_rst(hbm_rst),

        .m_axi_awid(m_axi_hbm_awid),
        .m_axi_awaddr(m_axi_hbm_awaddr),
        .m_axi_awlen(m_axi_hbm_awlen),
        .m_axi_awsize(m_axi_hbm_awsize),
        .m_axi_awburst(m_axi_hbm_awburst),
        .m_axi_awlock(m_axi_hbm_awlock),
        .m_axi_awcache(m_axi_hbm_awcache),
        .m_axi_awprot(m_axi_hbm_awprot),
        .m_axi_awqos(m_axi_hbm_awqos),
        .m_axi_awuser(m_axi_hbm_awuser),
        .m_axi_awvalid(m_axi_hbm_awvalid),
        .m_axi_awready(m_axi_hbm_awready),
        .m_axi_wdata(m_axi_hbm_wdata),
        .m_axi_wstrb(m_axi_hbm_wstrb),
        .m_axi_wlast(m_axi_hbm_wlast),
        .m_axi_wuser(m_axi_hbm_wuser),
        .m_axi_wvalid(m_axi_hbm_wvalid),
        .m_axi_wready(m_axi_hbm_wready),
        .m_axi_bid(m_axi_hbm_bid),
        .m_axi_bresp(m_axi_hbm_bresp),
        .m_axi_buser(m_axi_hbm_buser),
        .m_axi_bvalid(m_axi_hbm_bvalid),
        .m_axi_bready(m_axi_hbm_bready),
        .m_axi_arid(m_axi_hbm_arid),
        .m_axi_araddr(m_axi_hbm_araddr),
        .m_axi_arlen(m_axi_hbm_arlen),
        .m_axi_arsize(m_axi_hbm_arsize),
        .m_axi_arburst(m_axi_hbm_arburst),
        .m_axi_arlock(m_axi_hbm_arlock),
        .m_axi_arcache(m_axi_hbm_arcache),
        .m_axi_arprot(m_axi_hbm_arprot),
        .m_axi_arqos(m_axi_hbm_arqos),
        .m_axi_aruser(m_axi_hbm_aruser),
        .m_axi_arvalid(m_axi_hbm_arvalid),
        .m_axi_arready(m_axi_hbm_arready),
        .m_axi_rid(m_axi_hbm_rid),
        .m_axi_rdata(m_axi_hbm_rdata),
        .m_axi_rresp(m_axi_hbm_rresp),
        .m_axi_rlast(m_axi_hbm_rlast),
        .m_axi_ruser(m_axi_hbm_ruser),
        .m_axi_rvalid(m_axi_hbm_rvalid),
        .m_axi_rready(m_axi_hbm_rready),

        .status_in(hbm_status),

        /*
         * AXI to application
         */
        .s_axi_app_clk(app_hbm_clk),
        .s_axi_app_rst(app_hbm_rst),

        .s_axi_app_awid(app_m_axi_hbm_awid),
        .s_axi_app_awaddr(app_m_axi_hbm_awaddr),
        .s_axi_app_awlen(app_m_axi_hbm_awlen),
        .s_axi_app_awsize(app_m_axi_hbm_awsize),
        .s_axi_app_awburst(app_m_axi_hbm_awburst),
        .s_axi_app_awlock(app_m_axi_hbm_awlock),
        .s_axi_app_awcache(app_m_axi_hbm_awcache),
        .s_axi_app_awprot(app_m_axi_hbm_awprot),
        .s_axi_app_awqos(app_m_axi_hbm_awqos),
        .s_axi_app_awuser(app_m_axi_hbm_awuser),
        .s_axi_app_awvalid(app_m_axi_hbm_awvalid),
        .s_axi_app_awready(app_m_axi_hbm_awready),
        .s_axi_app_wdata(app_m_axi_hbm_wdata),
        .s_axi_app_wstrb(app_m_axi_hbm_wstrb),
        .s_axi_app_wlast(app_m_axi_hbm_wlast),
        .s_axi_app_wuser(app_m_axi_hbm_wuser),
        .s_axi_app_wvalid(app_m_axi_hbm_wvalid),
        .s_axi_app_wready(app_m_axi_hbm_wready),
        .s_axi_app_bid(app_m_axi_hbm_bid),
        .s_axi_app_bresp(app_m_axi_hbm_bresp),
        .s_axi_app_buser(app_m_axi_hbm_buser),
        .s_axi_app_bvalid(app_m_axi_hbm_bvalid),
        .s_axi_app_bready(app_m_axi_hbm_bready),
        .s_axi_app_arid(app_m_axi_hbm_arid),
        .s_axi_app_araddr(app_m_axi_hbm_araddr),
        .s_axi_app_arlen(app_m_axi_hbm_arlen),
        .s_axi_app_arsize(app_m_axi_hbm_arsize),
        .s_axi_app_arburst(app_m_axi_hbm_arburst),
        .s_axi_app_arlock(app_m_axi_hbm_arlock),
        .s_axi_app_arcache(app_m_axi_hbm_arcache),
        .s_axi_app_arprot(app_m_axi_hbm_arprot),
        .s_axi_app_arqos(app_m_axi_hbm_arqos),
        .s_axi_app_aruser(app_m_axi_hbm_aruser),
        .s_axi_app_arvalid(app_m_axi_hbm_arvalid),
        .s_axi_app_arready(app_m_axi_hbm_arready),
        .s_axi_app_rid(app_m_axi_hbm_rid),
        .s_axi_app_rdata(app_m_axi_hbm_rdata),
        .s_axi_app_rresp(app_m_axi_hbm_rresp),
        .s_axi_app_rlast(app_m_axi_hbm_rlast),
        .s_axi_app_ruser(app_m_axi_hbm_ruser),
        .s_axi_app_rvalid(app_m_axi_hbm_rvalid),
        .s_axi_app_rready(app_m_axi_hbm_rready),

        .app_status(app_hbm_status)
    );

    assign all_clocks[PORT_COUNT*2 + (DDR_ENABLE ? DDR_CH : 0) +: HBM_CH] = hbm_clk;

end else begin

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

    assign app_hbm_clk = 0;
    assign app_hbm_rst = 0;

    assign app_m_axi_hbm_awready = 0;
    assign app_m_axi_hbm_wready = 0;
    assign app_m_axi_hbm_bid = 0;
    assign app_m_axi_hbm_bresp = 0;
    assign app_m_axi_hbm_buser = 0;
    assign app_m_axi_hbm_bvalid = 0;
    assign app_m_axi_hbm_arready = 0;
    assign app_m_axi_hbm_rid = 0;
    assign app_m_axi_hbm_rdata = 0;
    assign app_m_axi_hbm_rresp = 0;
    assign app_m_axi_hbm_rlast = 0;
    assign app_m_axi_hbm_ruser = 0;
    assign app_m_axi_hbm_rvalid = 0;

    assign app_hbm_status = 0;

end

endgenerate

// streaming connections to application
wire [PORT_COUNT-1:0]                        app_direct_tx_clk;
wire [PORT_COUNT-1:0]                        app_direct_tx_rst;

wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        app_s_axis_direct_tx_tdata;
wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        app_s_axis_direct_tx_tkeep;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_tx_tvalid;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_tx_tready;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_tx_tlast;
wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]     app_s_axis_direct_tx_tuser;

wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        app_m_axis_direct_tx_tdata;
wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        app_m_axis_direct_tx_tkeep;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_tx_tvalid;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_tx_tready;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_tx_tlast;
wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]     app_m_axis_direct_tx_tuser;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           app_s_axis_direct_tx_cpl_ts;
wire [PORT_COUNT*TX_TAG_WIDTH-1:0]           app_s_axis_direct_tx_cpl_tag;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_tx_cpl_valid;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_tx_cpl_ready;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           app_m_axis_direct_tx_cpl_ts;
wire [PORT_COUNT*TX_TAG_WIDTH-1:0]           app_m_axis_direct_tx_cpl_tag;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_tx_cpl_valid;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_tx_cpl_ready;

wire [PORT_COUNT-1:0]                        app_direct_rx_clk;
wire [PORT_COUNT-1:0]                        app_direct_rx_rst;

wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        app_s_axis_direct_rx_tdata;
wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        app_s_axis_direct_rx_tkeep;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_rx_tvalid;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_rx_tready;
wire [PORT_COUNT-1:0]                        app_s_axis_direct_rx_tlast;
wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]     app_s_axis_direct_rx_tuser;

wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        app_m_axis_direct_rx_tdata;
wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        app_m_axis_direct_rx_tkeep;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_rx_tvalid;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_rx_tready;
wire [PORT_COUNT-1:0]                        app_m_axis_direct_rx_tlast;
wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]     app_m_axis_direct_rx_tuser;

wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]   app_s_axis_sync_tx_tdata;
wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]   app_s_axis_sync_tx_tkeep;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_tx_tvalid;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_tx_tready;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_tx_tlast;
wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]     app_s_axis_sync_tx_tuser;

wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]   app_m_axis_sync_tx_tdata;
wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]   app_m_axis_sync_tx_tkeep;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_tx_tvalid;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_tx_tready;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_tx_tlast;
wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]     app_m_axis_sync_tx_tuser;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           app_s_axis_sync_tx_cpl_ts;
wire [PORT_COUNT*TX_TAG_WIDTH-1:0]           app_s_axis_sync_tx_cpl_tag;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_tx_cpl_valid;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_tx_cpl_ready;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           app_m_axis_sync_tx_cpl_ts;
wire [PORT_COUNT*TX_TAG_WIDTH-1:0]           app_m_axis_sync_tx_cpl_tag;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_tx_cpl_valid;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_tx_cpl_ready;

wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]   app_s_axis_sync_rx_tdata;
wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]   app_s_axis_sync_rx_tkeep;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_rx_tvalid;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_rx_tready;
wire [PORT_COUNT-1:0]                        app_s_axis_sync_rx_tlast;
wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]     app_s_axis_sync_rx_tuser;

wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]   app_m_axis_sync_rx_tdata;
wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]   app_m_axis_sync_rx_tkeep;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_rx_tvalid;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_rx_tready;
wire [PORT_COUNT-1:0]                        app_m_axis_sync_rx_tlast;
wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]     app_m_axis_sync_rx_tuser;

wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]       app_s_axis_if_tx_tdata;
wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]       app_s_axis_if_tx_tkeep;
wire [IF_COUNT-1:0]                          app_s_axis_if_tx_tvalid;
wire [IF_COUNT-1:0]                          app_s_axis_if_tx_tready;
wire [IF_COUNT-1:0]                          app_s_axis_if_tx_tlast;
wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]      app_s_axis_if_tx_tid;
wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]    app_s_axis_if_tx_tdest;
wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]    app_s_axis_if_tx_tuser;

wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]       app_m_axis_if_tx_tdata;
wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]       app_m_axis_if_tx_tkeep;
wire [IF_COUNT-1:0]                          app_m_axis_if_tx_tvalid;
wire [IF_COUNT-1:0]                          app_m_axis_if_tx_tready;
wire [IF_COUNT-1:0]                          app_m_axis_if_tx_tlast;
wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]      app_m_axis_if_tx_tid;
wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]    app_m_axis_if_tx_tdest;
wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]    app_m_axis_if_tx_tuser;

wire [IF_COUNT*PTP_TS_WIDTH-1:0]             app_s_axis_if_tx_cpl_ts;
wire [IF_COUNT*TX_TAG_WIDTH-1:0]             app_s_axis_if_tx_cpl_tag;
wire [IF_COUNT-1:0]                          app_s_axis_if_tx_cpl_valid;
wire [IF_COUNT-1:0]                          app_s_axis_if_tx_cpl_ready;

wire [IF_COUNT*PTP_TS_WIDTH-1:0]             app_m_axis_if_tx_cpl_ts;
wire [IF_COUNT*TX_TAG_WIDTH-1:0]             app_m_axis_if_tx_cpl_tag;
wire [IF_COUNT-1:0]                          app_m_axis_if_tx_cpl_valid;
wire [IF_COUNT-1:0]                          app_m_axis_if_tx_cpl_ready;

wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]       app_s_axis_if_rx_tdata;
wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]       app_s_axis_if_rx_tkeep;
wire [IF_COUNT-1:0]                          app_s_axis_if_rx_tvalid;
wire [IF_COUNT-1:0]                          app_s_axis_if_rx_tready;
wire [IF_COUNT-1:0]                          app_s_axis_if_rx_tlast;
wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]      app_s_axis_if_rx_tid;
wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]    app_s_axis_if_rx_tdest;
wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]    app_s_axis_if_rx_tuser;

wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]       app_m_axis_if_rx_tdata;
wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]       app_m_axis_if_rx_tkeep;
wire [IF_COUNT-1:0]                          app_m_axis_if_rx_tvalid;
wire [IF_COUNT-1:0]                          app_m_axis_if_rx_tready;
wire [IF_COUNT-1:0]                          app_m_axis_if_rx_tlast;
wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]      app_m_axis_if_rx_tid;
wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]    app_m_axis_if_rx_tdest;
wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]    app_m_axis_if_rx_tuser;

generate

    for (n = 0; n < IF_COUNT; n = n + 1) begin : iface

        wire [PORTS_PER_IF-1:0] if_tx_clk;
        wire [PORTS_PER_IF-1:0] if_tx_rst;

        wire [PORTS_PER_IF-1:0] if_rx_clk;
        wire [PORTS_PER_IF-1:0] if_rx_rst;

        mqnic_interface #(
            // Structural configuration
            .PORTS(PORTS_PER_IF),
            .SCHEDULERS(SCHED_PER_IF),

            // Clock configuration
            .CLK_PERIOD_NS_NUM(CLK_PERIOD_NS_NUM),
            .CLK_PERIOD_NS_DENOM(CLK_PERIOD_NS_DENOM),

            // PTP configuration
            .PTP_CLK_PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
            .PTP_CLK_PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM),
            .PTP_TS_WIDTH(PTP_TS_WIDTH),
            .PTP_CLOCK_CDC_PIPELINE(PTP_CLOCK_CDC_PIPELINE),
            .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
            .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

            // Queue manager configuration
            .EVENT_QUEUE_OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
            .TX_QUEUE_OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
            .RX_QUEUE_OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
            .CQ_OP_TABLE_SIZE(CQ_OP_TABLE_SIZE),
            .EQN_WIDTH(EQN_WIDTH),
            .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
            .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
            .CQN_WIDTH(CQN_WIDTH),
            .EQ_PIPELINE(EQ_PIPELINE),
            .TX_QUEUE_PIPELINE(TX_QUEUE_PIPELINE),
            .RX_QUEUE_PIPELINE(RX_QUEUE_PIPELINE),
            .CQ_PIPELINE(CQ_PIPELINE),
            .QUEUE_PTR_WIDTH(16),
            .LOG_QUEUE_SIZE_WIDTH(4),
            .LOG_BLOCK_SIZE_WIDTH(2),

            // Descriptor management
            .TX_MAX_DESC_REQ(16),
            .TX_DESC_FIFO_SIZE(16*8),
            .RX_MAX_DESC_REQ(16),
            .RX_DESC_FIFO_SIZE(16*8),

            // TX and RX engine configuration
            .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
            .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
            .RX_INDIR_TBL_ADDR_WIDTH(RX_INDIR_TBL_ADDR_WIDTH),

            // Scheduler configuration
            .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
            .TX_SCHEDULER_PIPELINE(TX_SCHEDULER_PIPELINE),
            .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),

            // Interface configuration
            .PTP_TS_ENABLE(PTP_TS_ENABLE),
            .TX_CPL_ENABLE(TX_CPL_ENABLE),
            .TX_CPL_FIFO_DEPTH(TX_CPL_FIFO_DEPTH),
            .TX_TAG_WIDTH(TX_TAG_WIDTH),
            .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
            .RX_HASH_ENABLE(RX_HASH_ENABLE),
            .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
            .PFC_ENABLE(PFC_ENABLE),
            .LFC_ENABLE(LFC_ENABLE),
            .MAC_CTRL_ENABLE(MAC_CTRL_ENABLE),
            .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
            .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
            .MAX_TX_SIZE(MAX_TX_SIZE),
            .MAX_RX_SIZE(MAX_RX_SIZE),
            .TX_RAM_SIZE(TX_RAM_SIZE),
            .RX_RAM_SIZE(RX_RAM_SIZE),

            // Application block configuration
            .APP_AXIS_DIRECT_ENABLE(APP_ENABLE && APP_AXIS_DIRECT_ENABLE),
            .APP_AXIS_SYNC_ENABLE(APP_ENABLE && APP_AXIS_SYNC_ENABLE),
            .APP_AXIS_IF_ENABLE(APP_ENABLE && APP_AXIS_IF_ENABLE),

            // DMA interface configuration
            .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
            .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
            .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
            .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
            .DMA_TAG_WIDTH(IF_DMA_TAG_WIDTH),
            .RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
            .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
            .RAM_SEG_COUNT(RAM_SEG_COUNT),
            .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
            .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
            .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
            .RAM_PIPELINE(RAM_PIPELINE),

            // Interrupt configuration
            .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),

            // AXI lite interface configuration
            .AXIL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
            .AXIL_ADDR_WIDTH(AXIL_IF_CTRL_ADDR_WIDTH),
            .AXIL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),

            // Streaming interface configuration (direct, async)
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

            // Streaming interface configuration (direct, sync)
            .AXIS_SYNC_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
            .AXIS_SYNC_KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
            .AXIS_SYNC_TX_USER_WIDTH(AXIS_TX_USER_WIDTH),
            .AXIS_SYNC_RX_USER_WIDTH(AXIS_RX_USER_WIDTH),

            // Streaming interface configuration (interface)
            .AXIS_IF_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
            .AXIS_IF_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
            .AXIS_IF_TX_ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
            .AXIS_IF_RX_ID_WIDTH(AXIS_IF_RX_ID_WIDTH),
            .AXIS_IF_TX_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
            .AXIS_IF_RX_DEST_WIDTH(AXIS_IF_RX_DEST_WIDTH),
            .AXIS_IF_TX_USER_WIDTH(AXIS_IF_TX_USER_WIDTH),
            .AXIS_IF_RX_USER_WIDTH(AXIS_IF_RX_USER_WIDTH)
        )
        interface_inst (
            .clk(clk),
            .rst(rst),

            /*
             * DMA read descriptor output (control)
             */
            .m_axis_ctrl_dma_read_desc_dma_addr(if_ctrl_dma_read_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_ctrl_dma_read_desc_ram_sel(if_ctrl_dma_read_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_ctrl_dma_read_desc_ram_addr(if_ctrl_dma_read_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_ctrl_dma_read_desc_len(if_ctrl_dma_read_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_ctrl_dma_read_desc_tag(if_ctrl_dma_read_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_ctrl_dma_read_desc_valid(if_ctrl_dma_read_desc_valid[n]),
            .m_axis_ctrl_dma_read_desc_ready(if_ctrl_dma_read_desc_ready[n]),

            /*
             * DMA read descriptor status input (control)
             */
            .s_axis_ctrl_dma_read_desc_status_tag(if_ctrl_dma_read_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_ctrl_dma_read_desc_status_error(if_ctrl_dma_read_desc_status_error[n*4 +: 4]),
            .s_axis_ctrl_dma_read_desc_status_valid(if_ctrl_dma_read_desc_status_valid[n]),

            /*
             * DMA write descriptor output (control)
             */
            .m_axis_ctrl_dma_write_desc_dma_addr(if_ctrl_dma_write_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_ctrl_dma_write_desc_ram_sel(if_ctrl_dma_write_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_ctrl_dma_write_desc_ram_addr(if_ctrl_dma_write_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_ctrl_dma_write_desc_imm(if_ctrl_dma_write_desc_imm[n*DMA_IMM_WIDTH +: DMA_IMM_WIDTH]),
            .m_axis_ctrl_dma_write_desc_imm_en(if_ctrl_dma_write_desc_imm_en[n]),
            .m_axis_ctrl_dma_write_desc_len(if_ctrl_dma_write_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_ctrl_dma_write_desc_tag(if_ctrl_dma_write_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_ctrl_dma_write_desc_valid(if_ctrl_dma_write_desc_valid[n]),
            .m_axis_ctrl_dma_write_desc_ready(if_ctrl_dma_write_desc_ready[n]),

            /*
             * DMA write descriptor status input (control)
             */
            .s_axis_ctrl_dma_write_desc_status_tag(if_ctrl_dma_write_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_ctrl_dma_write_desc_status_error(if_ctrl_dma_write_desc_status_error[n*4 +: 4]),
            .s_axis_ctrl_dma_write_desc_status_valid(if_ctrl_dma_write_desc_status_valid[n]),

            /*
             * DMA read descriptor output (data)
             */
            .m_axis_data_dma_read_desc_dma_addr(if_data_dma_read_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_data_dma_read_desc_ram_sel(if_data_dma_read_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_data_dma_read_desc_ram_addr(if_data_dma_read_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_data_dma_read_desc_len(if_data_dma_read_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_data_dma_read_desc_tag(if_data_dma_read_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_data_dma_read_desc_valid(if_data_dma_read_desc_valid[n]),
            .m_axis_data_dma_read_desc_ready(if_data_dma_read_desc_ready[n]),

            /*
             * DMA read descriptor status input (data)
             */
            .s_axis_data_dma_read_desc_status_tag(if_data_dma_read_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_data_dma_read_desc_status_error(if_data_dma_read_desc_status_error[n*4 +: 4]),
            .s_axis_data_dma_read_desc_status_valid(if_data_dma_read_desc_status_valid[n]),

            /*
             * DMA write descriptor output (data)
             */
            .m_axis_data_dma_write_desc_dma_addr(if_data_dma_write_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_data_dma_write_desc_ram_sel(if_data_dma_write_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_data_dma_write_desc_ram_addr(if_data_dma_write_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_data_dma_write_desc_imm(if_data_dma_write_desc_imm[n*DMA_IMM_WIDTH +: DMA_IMM_WIDTH]),
            .m_axis_data_dma_write_desc_imm_en(if_data_dma_write_desc_imm_en[n]),
            .m_axis_data_dma_write_desc_len(if_data_dma_write_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_data_dma_write_desc_tag(if_data_dma_write_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_data_dma_write_desc_valid(if_data_dma_write_desc_valid[n]),
            .m_axis_data_dma_write_desc_ready(if_data_dma_write_desc_ready[n]),

            /*
             * DMA write descriptor status input (data)
             */
            .s_axis_data_dma_write_desc_status_tag(if_data_dma_write_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_data_dma_write_desc_status_error(if_data_dma_write_desc_status_error[n*4 +: 4]),
            .s_axis_data_dma_write_desc_status_valid(if_data_dma_write_desc_status_valid[n]),

            /*
             * AXI-Lite slave interface
             */
            .s_axil_awaddr(axil_if_ctrl_awaddr[n*AXIL_CTRL_ADDR_WIDTH +: AXIL_CTRL_ADDR_WIDTH]),
            .s_axil_awprot(axil_if_ctrl_awprot[n*3 +: 3]),
            .s_axil_awvalid(axil_if_ctrl_awvalid[n]),
            .s_axil_awready(axil_if_ctrl_awready[n]),
            .s_axil_wdata(axil_if_ctrl_wdata[n*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH]),
            .s_axil_wstrb(axil_if_ctrl_wstrb[n*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH]),
            .s_axil_wvalid(axil_if_ctrl_wvalid[n]),
            .s_axil_wready(axil_if_ctrl_wready[n]),
            .s_axil_bresp(axil_if_ctrl_bresp[n*2 +: 2]),
            .s_axil_bvalid(axil_if_ctrl_bvalid[n]),
            .s_axil_bready(axil_if_ctrl_bready[n]),
            .s_axil_araddr(axil_if_ctrl_araddr[n*AXIL_CTRL_ADDR_WIDTH +: AXIL_CTRL_ADDR_WIDTH]),
            .s_axil_arprot(axil_if_ctrl_arprot[n*3 +: 3]),
            .s_axil_arvalid(axil_if_ctrl_arvalid[n]),
            .s_axil_arready(axil_if_ctrl_arready[n]),
            .s_axil_rdata(axil_if_ctrl_rdata[n*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH]),
            .s_axil_rresp(axil_if_ctrl_rresp[n*2 +: 2]),
            .s_axil_rvalid(axil_if_ctrl_rvalid[n]),
            .s_axil_rready(axil_if_ctrl_rready[n]),

            /*
             * AXI-Lite master interface (passthrough for NIC control and status)
             */
            .m_axil_csr_awaddr(axil_if_csr_awaddr[n*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH]),
            .m_axil_csr_awprot(axil_if_csr_awprot[n*3 +: 3]),
            .m_axil_csr_awvalid(axil_if_csr_awvalid[n]),
            .m_axil_csr_awready(axil_if_csr_awready[n]),
            .m_axil_csr_wdata(axil_if_csr_wdata[n*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH]),
            .m_axil_csr_wstrb(axil_if_csr_wstrb[n*AXIL_CTRL_STRB_WIDTH +: AXIL_CTRL_STRB_WIDTH]),
            .m_axil_csr_wvalid(axil_if_csr_wvalid[n]),
            .m_axil_csr_wready(axil_if_csr_wready[n]),
            .m_axil_csr_bresp(axil_if_csr_bresp[n*2 +: 2]),
            .m_axil_csr_bvalid(axil_if_csr_bvalid[n]),
            .m_axil_csr_bready(axil_if_csr_bready[n]),
            .m_axil_csr_araddr(axil_if_csr_araddr[n*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH]),
            .m_axil_csr_arprot(axil_if_csr_arprot[n*3 +: 3]),
            .m_axil_csr_arvalid(axil_if_csr_arvalid[n]),
            .m_axil_csr_arready(axil_if_csr_arready[n]),
            .m_axil_csr_rdata(axil_if_csr_rdata[n*AXIL_CTRL_DATA_WIDTH +: AXIL_CTRL_DATA_WIDTH]),
            .m_axil_csr_rresp(axil_if_csr_rresp[n*2 +: 2]),
            .m_axil_csr_rvalid(axil_if_csr_rvalid[n]),
            .m_axil_csr_rready(axil_if_csr_rready[n]),

            /*
             * RAM interface (control)
             */
            .ctrl_dma_ram_wr_cmd_sel(if_ctrl_dma_ram_wr_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .ctrl_dma_ram_wr_cmd_be(if_ctrl_dma_ram_wr_cmd_be[RAM_SEG_COUNT*RAM_SEG_BE_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_BE_WIDTH]),
            .ctrl_dma_ram_wr_cmd_addr(if_ctrl_dma_ram_wr_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .ctrl_dma_ram_wr_cmd_data(if_ctrl_dma_ram_wr_cmd_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .ctrl_dma_ram_wr_cmd_valid(if_ctrl_dma_ram_wr_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_wr_cmd_ready(if_ctrl_dma_ram_wr_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_wr_done(if_ctrl_dma_ram_wr_done[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_cmd_sel(if_ctrl_dma_ram_rd_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .ctrl_dma_ram_rd_cmd_addr(if_ctrl_dma_ram_rd_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .ctrl_dma_ram_rd_cmd_valid(if_ctrl_dma_ram_rd_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_cmd_ready(if_ctrl_dma_ram_rd_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_resp_data(if_ctrl_dma_ram_rd_resp_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .ctrl_dma_ram_rd_resp_valid(if_ctrl_dma_ram_rd_resp_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_resp_ready(if_ctrl_dma_ram_rd_resp_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),

            /*
             * RAM interface (data)
             */
            .data_dma_ram_wr_cmd_sel(if_data_dma_ram_wr_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .data_dma_ram_wr_cmd_be(if_data_dma_ram_wr_cmd_be[RAM_SEG_COUNT*RAM_SEG_BE_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_BE_WIDTH]),
            .data_dma_ram_wr_cmd_addr(if_data_dma_ram_wr_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .data_dma_ram_wr_cmd_data(if_data_dma_ram_wr_cmd_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .data_dma_ram_wr_cmd_valid(if_data_dma_ram_wr_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_wr_cmd_ready(if_data_dma_ram_wr_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_wr_done(if_data_dma_ram_wr_done[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_cmd_sel(if_data_dma_ram_rd_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .data_dma_ram_rd_cmd_addr(if_data_dma_ram_rd_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .data_dma_ram_rd_cmd_valid(if_data_dma_ram_rd_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_cmd_ready(if_data_dma_ram_rd_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_resp_data(if_data_dma_ram_rd_resp_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .data_dma_ram_rd_resp_valid(if_data_dma_ram_rd_resp_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_resp_ready(if_data_dma_ram_rd_resp_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),

            /*
             * Application section datapath interface (interface-level connection)
             */
            .m_axis_app_if_tx_tdata(app_s_axis_if_tx_tdata[n*AXIS_IF_DATA_WIDTH +: AXIS_IF_DATA_WIDTH]),
            .m_axis_app_if_tx_tkeep(app_s_axis_if_tx_tkeep[n*AXIS_IF_KEEP_WIDTH +: AXIS_IF_KEEP_WIDTH]),
            .m_axis_app_if_tx_tvalid(app_s_axis_if_tx_tvalid[n +: 1]),
            .m_axis_app_if_tx_tready(app_s_axis_if_tx_tready[n +: 1]),
            .m_axis_app_if_tx_tlast(app_s_axis_if_tx_tlast[n +: 1]),
            .m_axis_app_if_tx_tid(app_s_axis_if_tx_tid[n*AXIS_IF_TX_ID_WIDTH +: AXIS_IF_TX_ID_WIDTH]),
            .m_axis_app_if_tx_tdest(app_s_axis_if_tx_tdest[n*AXIS_IF_TX_DEST_WIDTH +: AXIS_IF_TX_DEST_WIDTH]),
            .m_axis_app_if_tx_tuser(app_s_axis_if_tx_tuser[n*AXIS_IF_TX_USER_WIDTH +: AXIS_IF_TX_USER_WIDTH]),

            .s_axis_app_if_tx_tdata(app_m_axis_if_tx_tdata[n*AXIS_IF_DATA_WIDTH +: AXIS_IF_DATA_WIDTH]),
            .s_axis_app_if_tx_tkeep(app_m_axis_if_tx_tkeep[n*AXIS_IF_KEEP_WIDTH +: AXIS_IF_KEEP_WIDTH]),
            .s_axis_app_if_tx_tvalid(app_m_axis_if_tx_tvalid[n +: 1]),
            .s_axis_app_if_tx_tready(app_m_axis_if_tx_tready[n +: 1]),
            .s_axis_app_if_tx_tlast(app_m_axis_if_tx_tlast[n +: 1]),
            .s_axis_app_if_tx_tid(app_m_axis_if_tx_tid[n*AXIS_IF_TX_ID_WIDTH +: AXIS_IF_TX_ID_WIDTH]),
            .s_axis_app_if_tx_tdest(app_m_axis_if_tx_tdest[n*AXIS_IF_TX_DEST_WIDTH +: AXIS_IF_TX_DEST_WIDTH]),
            .s_axis_app_if_tx_tuser(app_m_axis_if_tx_tuser[n*AXIS_IF_TX_USER_WIDTH +: AXIS_IF_TX_USER_WIDTH]),

            .m_axis_app_if_tx_cpl_ts(app_s_axis_if_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
            .m_axis_app_if_tx_cpl_tag(app_s_axis_if_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
            .m_axis_app_if_tx_cpl_valid(app_s_axis_if_tx_cpl_valid[n +: 1]),
            .m_axis_app_if_tx_cpl_ready(app_s_axis_if_tx_cpl_ready[n +: 1]),

            .s_axis_app_if_tx_cpl_ts(app_m_axis_if_tx_cpl_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
            .s_axis_app_if_tx_cpl_tag(app_m_axis_if_tx_cpl_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
            .s_axis_app_if_tx_cpl_valid(app_m_axis_if_tx_cpl_valid[n +: 1]),
            .s_axis_app_if_tx_cpl_ready(app_m_axis_if_tx_cpl_ready[n +: 1]),

            .m_axis_app_if_rx_tdata(app_s_axis_if_rx_tdata[n*AXIS_IF_DATA_WIDTH +: AXIS_IF_DATA_WIDTH]),
            .m_axis_app_if_rx_tkeep(app_s_axis_if_rx_tkeep[n*AXIS_IF_KEEP_WIDTH +: AXIS_IF_KEEP_WIDTH]),
            .m_axis_app_if_rx_tvalid(app_s_axis_if_rx_tvalid[n +: 1]),
            .m_axis_app_if_rx_tready(app_s_axis_if_rx_tready[n +: 1]),
            .m_axis_app_if_rx_tlast(app_s_axis_if_rx_tlast[n +: 1]),
            .m_axis_app_if_rx_tid(app_s_axis_if_rx_tid[n*AXIS_IF_RX_ID_WIDTH +: AXIS_IF_RX_ID_WIDTH]),
            .m_axis_app_if_rx_tdest(app_s_axis_if_rx_tdest[n*AXIS_IF_RX_DEST_WIDTH +: AXIS_IF_RX_DEST_WIDTH]),
            .m_axis_app_if_rx_tuser(app_s_axis_if_rx_tuser[n*AXIS_IF_RX_USER_WIDTH +: AXIS_IF_RX_USER_WIDTH]),

            .s_axis_app_if_rx_tdata(app_m_axis_if_rx_tdata[n*AXIS_IF_DATA_WIDTH +: AXIS_IF_DATA_WIDTH]),
            .s_axis_app_if_rx_tkeep(app_m_axis_if_rx_tkeep[n*AXIS_IF_KEEP_WIDTH +: AXIS_IF_KEEP_WIDTH]),
            .s_axis_app_if_rx_tvalid(app_m_axis_if_rx_tvalid[n +: 1]),
            .s_axis_app_if_rx_tready(app_m_axis_if_rx_tready[n +: 1]),
            .s_axis_app_if_rx_tlast(app_m_axis_if_rx_tlast[n +: 1]),
            .s_axis_app_if_rx_tid(app_m_axis_if_rx_tid[n*AXIS_IF_RX_ID_WIDTH +: AXIS_IF_RX_ID_WIDTH]),
            .s_axis_app_if_rx_tdest(app_m_axis_if_rx_tdest[n*AXIS_IF_RX_DEST_WIDTH +: AXIS_IF_RX_DEST_WIDTH]),
            .s_axis_app_if_rx_tuser(app_m_axis_if_rx_tuser[n*AXIS_IF_RX_USER_WIDTH +: AXIS_IF_RX_USER_WIDTH]),

            /*
             * Application section datapath interface (synchronous MAC connection)
             */
            .m_axis_app_sync_tx_tdata(app_s_axis_sync_tx_tdata[n*PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH +: PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH]),
            .m_axis_app_sync_tx_tkeep(app_s_axis_sync_tx_tkeep[n*PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH +: PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH]),
            .m_axis_app_sync_tx_tvalid(app_s_axis_sync_tx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_sync_tx_tready(app_s_axis_sync_tx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_sync_tx_tlast(app_s_axis_sync_tx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_sync_tx_tuser(app_s_axis_sync_tx_tuser[n*PORTS_PER_IF*AXIS_TX_USER_WIDTH +: PORTS_PER_IF*AXIS_TX_USER_WIDTH]),

            .s_axis_app_sync_tx_tdata(app_m_axis_sync_tx_tdata[n*PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH +: PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH]),
            .s_axis_app_sync_tx_tkeep(app_m_axis_sync_tx_tkeep[n*PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH +: PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH]),
            .s_axis_app_sync_tx_tvalid(app_m_axis_sync_tx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_sync_tx_tready(app_m_axis_sync_tx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_sync_tx_tlast(app_m_axis_sync_tx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_sync_tx_tuser(app_m_axis_sync_tx_tuser[n*PORTS_PER_IF*AXIS_TX_USER_WIDTH +: PORTS_PER_IF*AXIS_TX_USER_WIDTH]),

            .m_axis_app_sync_tx_cpl_ts(app_s_axis_sync_tx_cpl_ts[n*PORTS_PER_IF*PTP_TS_WIDTH +: PORTS_PER_IF*PTP_TS_WIDTH]),
            .m_axis_app_sync_tx_cpl_tag(app_s_axis_sync_tx_cpl_tag[n*PORTS_PER_IF*TX_TAG_WIDTH +: PORTS_PER_IF*TX_TAG_WIDTH]),
            .m_axis_app_sync_tx_cpl_valid(app_s_axis_sync_tx_cpl_valid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_sync_tx_cpl_ready(app_s_axis_sync_tx_cpl_ready[n*PORTS_PER_IF +: PORTS_PER_IF]),

            .s_axis_app_sync_tx_cpl_ts(app_m_axis_sync_tx_cpl_ts[n*PORTS_PER_IF*PTP_TS_WIDTH +: PORTS_PER_IF*PTP_TS_WIDTH]),
            .s_axis_app_sync_tx_cpl_tag(app_m_axis_sync_tx_cpl_tag[n*PORTS_PER_IF*TX_TAG_WIDTH +: PORTS_PER_IF*TX_TAG_WIDTH]),
            .s_axis_app_sync_tx_cpl_valid(app_m_axis_sync_tx_cpl_valid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_sync_tx_cpl_ready(app_m_axis_sync_tx_cpl_ready[n*PORTS_PER_IF +: PORTS_PER_IF]),

            .m_axis_app_sync_rx_tdata(app_s_axis_sync_rx_tdata[n*PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH +: PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH]),
            .m_axis_app_sync_rx_tkeep(app_s_axis_sync_rx_tkeep[n*PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH +: PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH]),
            .m_axis_app_sync_rx_tvalid(app_s_axis_sync_rx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_sync_rx_tready(app_s_axis_sync_rx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_sync_rx_tlast(app_s_axis_sync_rx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_sync_rx_tuser(app_s_axis_sync_rx_tuser[n*PORTS_PER_IF*AXIS_RX_USER_WIDTH +: PORTS_PER_IF*AXIS_RX_USER_WIDTH]),

            .s_axis_app_sync_rx_tdata(app_m_axis_sync_rx_tdata[n*PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH +: PORTS_PER_IF*AXIS_SYNC_DATA_WIDTH]),
            .s_axis_app_sync_rx_tkeep(app_m_axis_sync_rx_tkeep[n*PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH +: PORTS_PER_IF*AXIS_SYNC_KEEP_WIDTH]),
            .s_axis_app_sync_rx_tvalid(app_m_axis_sync_rx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_sync_rx_tready(app_m_axis_sync_rx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_sync_rx_tlast(app_m_axis_sync_rx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_sync_rx_tuser(app_m_axis_sync_rx_tuser[n*PORTS_PER_IF*AXIS_RX_USER_WIDTH +: PORTS_PER_IF*AXIS_RX_USER_WIDTH]),

            /*
             * Application section datapath interface (direct MAC connection)
             */
            .m_axis_app_direct_tx_tdata(app_s_axis_direct_tx_tdata[n*PORTS_PER_IF*AXIS_DATA_WIDTH +: PORTS_PER_IF*AXIS_DATA_WIDTH]),
            .m_axis_app_direct_tx_tkeep(app_s_axis_direct_tx_tkeep[n*PORTS_PER_IF*AXIS_KEEP_WIDTH +: PORTS_PER_IF*AXIS_KEEP_WIDTH]),
            .m_axis_app_direct_tx_tvalid(app_s_axis_direct_tx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_direct_tx_tready(app_s_axis_direct_tx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_direct_tx_tlast(app_s_axis_direct_tx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_direct_tx_tuser(app_s_axis_direct_tx_tuser[n*PORTS_PER_IF*AXIS_TX_USER_WIDTH +: PORTS_PER_IF*AXIS_TX_USER_WIDTH]),

            .s_axis_app_direct_tx_tdata(app_m_axis_direct_tx_tdata[n*PORTS_PER_IF*AXIS_DATA_WIDTH +: PORTS_PER_IF*AXIS_DATA_WIDTH]),
            .s_axis_app_direct_tx_tkeep(app_m_axis_direct_tx_tkeep[n*PORTS_PER_IF*AXIS_KEEP_WIDTH +: PORTS_PER_IF*AXIS_KEEP_WIDTH]),
            .s_axis_app_direct_tx_tvalid(app_m_axis_direct_tx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_direct_tx_tready(app_m_axis_direct_tx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_direct_tx_tlast(app_m_axis_direct_tx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_direct_tx_tuser(app_m_axis_direct_tx_tuser[n*PORTS_PER_IF*AXIS_TX_USER_WIDTH +: PORTS_PER_IF*AXIS_TX_USER_WIDTH]),

            .m_axis_app_direct_tx_cpl_ts(app_s_axis_direct_tx_cpl_ts[n*PORTS_PER_IF*PTP_TS_WIDTH +: PORTS_PER_IF*PTP_TS_WIDTH]),
            .m_axis_app_direct_tx_cpl_tag(app_s_axis_direct_tx_cpl_tag[n*PORTS_PER_IF*TX_TAG_WIDTH +: PORTS_PER_IF*TX_TAG_WIDTH]),
            .m_axis_app_direct_tx_cpl_valid(app_s_axis_direct_tx_cpl_valid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_direct_tx_cpl_ready(app_s_axis_direct_tx_cpl_ready[n*PORTS_PER_IF +: PORTS_PER_IF]),

            .s_axis_app_direct_tx_cpl_ts(app_m_axis_direct_tx_cpl_ts[n*PORTS_PER_IF*PTP_TS_WIDTH +: PORTS_PER_IF*PTP_TS_WIDTH]),
            .s_axis_app_direct_tx_cpl_tag(app_m_axis_direct_tx_cpl_tag[n*PORTS_PER_IF*TX_TAG_WIDTH +: PORTS_PER_IF*TX_TAG_WIDTH]),
            .s_axis_app_direct_tx_cpl_valid(app_m_axis_direct_tx_cpl_valid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_direct_tx_cpl_ready(app_m_axis_direct_tx_cpl_ready[n*PORTS_PER_IF +: PORTS_PER_IF]),

            .m_axis_app_direct_rx_tdata(app_s_axis_direct_rx_tdata[n*PORTS_PER_IF*AXIS_DATA_WIDTH +: PORTS_PER_IF*AXIS_DATA_WIDTH]),
            .m_axis_app_direct_rx_tkeep(app_s_axis_direct_rx_tkeep[n*PORTS_PER_IF*AXIS_KEEP_WIDTH +: PORTS_PER_IF*AXIS_KEEP_WIDTH]),
            .m_axis_app_direct_rx_tvalid(app_s_axis_direct_rx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_direct_rx_tready(app_s_axis_direct_rx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_direct_rx_tlast(app_s_axis_direct_rx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_app_direct_rx_tuser(app_s_axis_direct_rx_tuser[n*PORTS_PER_IF*AXIS_RX_USER_WIDTH +: PORTS_PER_IF*AXIS_RX_USER_WIDTH]),

            .s_axis_app_direct_rx_tdata(app_m_axis_direct_rx_tdata[n*PORTS_PER_IF*AXIS_DATA_WIDTH +: PORTS_PER_IF*AXIS_DATA_WIDTH]),
            .s_axis_app_direct_rx_tkeep(app_m_axis_direct_rx_tkeep[n*PORTS_PER_IF*AXIS_KEEP_WIDTH +: PORTS_PER_IF*AXIS_KEEP_WIDTH]),
            .s_axis_app_direct_rx_tvalid(app_m_axis_direct_rx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_direct_rx_tready(app_m_axis_direct_rx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_direct_rx_tlast(app_m_axis_direct_rx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_app_direct_rx_tuser(app_m_axis_direct_rx_tuser[n*PORTS_PER_IF*AXIS_RX_USER_WIDTH +: PORTS_PER_IF*AXIS_RX_USER_WIDTH]),

            /*
             * Transmit data output
             */
            .tx_clk(if_tx_clk),
            .tx_rst(if_tx_rst),

            .m_axis_tx_tdata(m_axis_tx_tdata[n*PORTS_PER_IF*AXIS_DATA_WIDTH +: PORTS_PER_IF*AXIS_DATA_WIDTH]),
            .m_axis_tx_tkeep(m_axis_tx_tkeep[n*PORTS_PER_IF*AXIS_KEEP_WIDTH +: PORTS_PER_IF*AXIS_KEEP_WIDTH]),
            .m_axis_tx_tvalid(m_axis_tx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_tx_tready(m_axis_tx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_tx_tlast(m_axis_tx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .m_axis_tx_tuser(m_axis_tx_tuser[n*PORTS_PER_IF*AXIS_TX_USER_WIDTH +: PORTS_PER_IF*AXIS_TX_USER_WIDTH]),

            .s_axis_tx_cpl_ts(s_axis_tx_cpl_ts[n*PORTS_PER_IF*PTP_TS_WIDTH +: PORTS_PER_IF*PTP_TS_WIDTH]),
            .s_axis_tx_cpl_tag(s_axis_tx_cpl_tag[n*PORTS_PER_IF*TX_TAG_WIDTH +: PORTS_PER_IF*TX_TAG_WIDTH]),
            .s_axis_tx_cpl_valid(s_axis_tx_cpl_valid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_tx_cpl_ready(s_axis_tx_cpl_ready[n*PORTS_PER_IF +: PORTS_PER_IF]),

            .tx_enable(tx_enable[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .tx_status(tx_status[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .tx_lfc_en(tx_lfc_en[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .tx_lfc_req(tx_lfc_req[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .tx_pfc_en(tx_pfc_en[n*PORTS_PER_IF*8 +: PORTS_PER_IF*8]),
            .tx_pfc_req(tx_pfc_req[n*PORTS_PER_IF*8 +: PORTS_PER_IF*8]),
            .tx_fc_quanta_clk_en(tx_fc_quanta_clk_en[n*PORTS_PER_IF +: PORTS_PER_IF]),

            /*
             * Receive data input
             */
            .rx_clk(if_rx_clk),
            .rx_rst(if_rx_rst),

            .s_axis_rx_tdata(s_axis_rx_tdata[n*PORTS_PER_IF*AXIS_DATA_WIDTH +: PORTS_PER_IF*AXIS_DATA_WIDTH]),
            .s_axis_rx_tkeep(s_axis_rx_tkeep[n*PORTS_PER_IF*AXIS_KEEP_WIDTH +: PORTS_PER_IF*AXIS_KEEP_WIDTH]),
            .s_axis_rx_tvalid(s_axis_rx_tvalid[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_rx_tready(s_axis_rx_tready[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_rx_tlast(s_axis_rx_tlast[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .s_axis_rx_tuser(s_axis_rx_tuser[n*PORTS_PER_IF*AXIS_RX_USER_WIDTH +: PORTS_PER_IF*AXIS_RX_USER_WIDTH]),

            .rx_enable(rx_enable[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .rx_status(rx_status[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .rx_lfc_en(rx_lfc_en[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .rx_lfc_req(rx_lfc_req[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .rx_lfc_ack(rx_lfc_ack[n*PORTS_PER_IF +: PORTS_PER_IF]),
            .rx_pfc_en(rx_pfc_en[n*PORTS_PER_IF*8 +: PORTS_PER_IF*8]),
            .rx_pfc_req(rx_pfc_req[n*PORTS_PER_IF*8 +: PORTS_PER_IF*8]),
            .rx_pfc_ack(rx_pfc_ack[n*PORTS_PER_IF*8 +: PORTS_PER_IF*8]),
            .rx_fc_quanta_clk_en(rx_fc_quanta_clk_en[n*PORTS_PER_IF +: PORTS_PER_IF]),

            /*
             * PTP clock
             */
            .ptp_clk(ptp_clk),
            .ptp_rst(ptp_rst),
            .ptp_sample_clk(ptp_sample_clk),
            .ptp_td_sd(ptp_td_sd),
            .ptp_pps(ptp_pps),
            .ptp_pps_str(ptp_pps_str),
            .ptp_sync_locked(ptp_sync_locked),
            .ptp_sync_ts_rel(ptp_sync_ts_rel),
            .ptp_sync_ts_rel_step(ptp_sync_ts_rel_step),
            .ptp_sync_ts_tod(ptp_sync_ts_tod),
            .ptp_sync_ts_tod_step(ptp_sync_ts_tod_step),
            .ptp_sync_pps(ptp_sync_pps),
            .ptp_sync_pps_str(ptp_sync_pps_str),
            .ptp_perout_locked(ptp_perout_locked),
            .ptp_perout_error(ptp_perout_error),
            .ptp_perout_pulse(ptp_perout_pulse),

            /*
             * Interrupt request output
             */
            .irq_index(if_irq_index[n*IRQ_INDEX_WIDTH +: IRQ_INDEX_WIDTH]),
            .irq_valid(if_irq_valid[n +: 1]),
            .irq_ready(if_irq_ready[n +: 1])
        );

        for (m = 0; m < PORTS_PER_IF; m = m + 1) begin : port

            wire port_tx_clk = tx_clk[n*PORTS_PER_IF+m];
            wire port_tx_rst = tx_rst[n*PORTS_PER_IF+m];

            wire port_rx_clk = rx_clk[n*PORTS_PER_IF+m];
            wire port_rx_rst = rx_rst[n*PORTS_PER_IF+m];

            wire port_tx_ptp_clk = tx_ptp_clk[n*PORTS_PER_IF+m];
            wire port_tx_ptp_rst = tx_ptp_rst[n*PORTS_PER_IF+m];

            wire port_rx_ptp_clk = rx_ptp_clk[n*PORTS_PER_IF+m];
            wire port_rx_ptp_rst = rx_ptp_rst[n*PORTS_PER_IF+m];

            assign if_tx_clk[m] = port_tx_clk;
            assign if_tx_rst[m] = port_tx_rst;

            assign if_rx_clk[m] = port_rx_clk;
            assign if_rx_rst[m] = port_rx_rst;

            assign app_direct_tx_clk[n*PORTS_PER_IF+m] = port_tx_clk;
            assign app_direct_tx_rst[n*PORTS_PER_IF+m] = port_tx_rst;

            assign app_direct_rx_clk[n*PORTS_PER_IF+m] = port_rx_clk;
            assign app_direct_rx_rst[n*PORTS_PER_IF+m] = port_rx_rst;

            assign all_clocks[(n*PORTS_PER_IF+m)*2+0] = port_tx_clk;
            assign all_clocks[(n*PORTS_PER_IF+m)*2+1] = port_rx_clk;

            wire [95:0] port_rx_ptp_ts_tod;
            wire port_rx_ptp_ts_tod_step;

            wire [95:0] port_tx_ptp_ts_tod;
            wire port_tx_ptp_ts_tod_step;

            if (PTP_TS_ENABLE) begin: ptp

                // PTP CDC logic
                ptp_td_leaf #(
                    .TS_REL_EN(0),
                    .TS_TOD_EN(1),
                    .TS_FNS_W(16),
                    .TS_REL_NS_W(48),
                    .TS_TOD_S_W(48),
                    .TS_REL_W(64),
                    .TS_TOD_W(96),
                    .TD_SDI_PIPELINE(PTP_PORT_CDC_PIPELINE)
                )
                tx_ptp_td_leaf_inst (
                    .clk(PTP_SEPARATE_TX_CLOCK ? port_tx_ptp_clk : port_tx_clk),
                    .rst(PTP_SEPARATE_TX_CLOCK ? port_tx_ptp_rst : port_tx_rst),
                    .sample_clk(ptp_sample_clk),

                    /*
                     * PTP clock interface
                     */
                    .ptp_clk(ptp_clk),
                    .ptp_rst(ptp_rst),
                    .ptp_td_sdi(ptp_td_sd),

                    /*
                     * Timestamp output
                     */
                    .output_ts_rel(),
                    .output_ts_rel_step(),
                    .output_ts_tod(port_tx_ptp_ts_tod),
                    .output_ts_tod_step(port_tx_ptp_ts_tod_step),

                    /*
                     * PPS output (ToD format only)
                     */
                    .output_pps(),
                    .output_pps_str(),

                    /*
                     * Status
                     */
                    .locked()
                );

                ptp_td_leaf #(
                    .TS_REL_EN(0),
                    .TS_TOD_EN(1),
                    .TS_FNS_W(16),
                    .TS_REL_NS_W(48),
                    .TS_TOD_S_W(48),
                    .TS_REL_W(64),
                    .TS_TOD_W(96),
                    .TD_SDI_PIPELINE(PTP_PORT_CDC_PIPELINE)
                )
                rx_ptp_td_leaf_inst (
                    .clk(PTP_SEPARATE_RX_CLOCK ? port_rx_ptp_clk : port_rx_clk),
                    .rst(PTP_SEPARATE_RX_CLOCK ? port_rx_ptp_rst : port_rx_rst),
                    .sample_clk(ptp_sample_clk),

                    /*
                     * PTP clock interface
                     */
                    .ptp_clk(ptp_clk),
                    .ptp_rst(ptp_rst),
                    .ptp_td_sdi(ptp_td_sd),

                    /*
                     * Timestamp output
                     */
                    .output_ts_rel(),
                    .output_ts_rel_step(),
                    .output_ts_tod(port_rx_ptp_ts_tod),
                    .output_ts_tod_step(port_rx_ptp_ts_tod_step),

                    /*
                     * PPS output (ToD format only)
                     */
                    .output_pps(),
                    .output_pps_str(),

                    /*
                     * Status
                     */
                    .locked()
                );

            end else begin

                assign port_tx_ptp_ts_tod = 0;
                assign port_tx_ptp_ts_tod_step = 1'b0;

                assign port_rx_ptp_ts_tod = 0;
                assign port_rx_ptp_ts_tod_step = 1'b0;

            end

            assign tx_ptp_ts_tod[(n*PORTS_PER_IF+m)*96 +: 96] = port_tx_ptp_ts_tod;
            assign tx_ptp_ts_tod_step[n*PORTS_PER_IF+m] = port_tx_ptp_ts_tod_step;

            assign rx_ptp_ts_tod[(n*PORTS_PER_IF+m)*96 +: 96] = port_rx_ptp_ts_tod;
            assign rx_ptp_ts_tod_step[n*PORTS_PER_IF+m] = port_rx_ptp_ts_tod_step;

        end

    end

endgenerate

generate

if (APP_ENABLE) begin : app

    mqnic_app_block #(
        // Structural configuration
        .IF_COUNT(IF_COUNT),
        .PORTS_PER_IF(PORTS_PER_IF),
        .SCHED_PER_IF(SCHED_PER_IF),

        .PORT_COUNT(PORT_COUNT),

        // Clock configuration
        .CLK_PERIOD_NS_NUM(CLK_PERIOD_NS_NUM),
        .CLK_PERIOD_NS_DENOM(CLK_PERIOD_NS_DENOM),

        // PTP configuration
        .PTP_CLK_PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
        .PTP_CLK_PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM),
        .PTP_TS_WIDTH(PTP_TS_WIDTH),
        .PTP_PORT_CDC_PIPELINE(PTP_PORT_CDC_PIPELINE),
        .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
        .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

        // Interface configuration
        .PTP_TS_ENABLE(PTP_TS_ENABLE),
        .TX_TAG_WIDTH(TX_TAG_WIDTH),
        .MAX_TX_SIZE(MAX_TX_SIZE),
        .MAX_RX_SIZE(MAX_RX_SIZE),

        // RAM configuration
        .DDR_CH(DDR_CH),
        .DDR_ENABLE(DDR_ENABLE),
        .DDR_GROUP_SIZE(DDR_GROUP_SIZE),
        .AXI_DDR_DATA_WIDTH(AXI_DDR_DATA_WIDTH),
        .AXI_DDR_ADDR_WIDTH(AXI_DDR_ADDR_WIDTH),
        .AXI_DDR_STRB_WIDTH(AXI_DDR_STRB_WIDTH),
        .AXI_DDR_ID_WIDTH(AXI_DDR_ID_WIDTH),
        .AXI_DDR_AWUSER_ENABLE(AXI_DDR_AWUSER_ENABLE),
        .AXI_DDR_AWUSER_WIDTH(AXI_DDR_AWUSER_WIDTH),
        .AXI_DDR_WUSER_ENABLE(AXI_DDR_WUSER_ENABLE),
        .AXI_DDR_WUSER_WIDTH(AXI_DDR_WUSER_WIDTH),
        .AXI_DDR_BUSER_ENABLE(AXI_DDR_BUSER_ENABLE),
        .AXI_DDR_BUSER_WIDTH(AXI_DDR_BUSER_WIDTH),
        .AXI_DDR_ARUSER_ENABLE(AXI_DDR_ARUSER_ENABLE),
        .AXI_DDR_ARUSER_WIDTH(AXI_DDR_ARUSER_WIDTH),
        .AXI_DDR_RUSER_ENABLE(AXI_DDR_RUSER_ENABLE),
        .AXI_DDR_RUSER_WIDTH(AXI_DDR_RUSER_WIDTH),
        .AXI_DDR_MAX_BURST_LEN(AXI_DDR_MAX_BURST_LEN),
        .AXI_DDR_NARROW_BURST(AXI_DDR_NARROW_BURST),
        .AXI_DDR_FIXED_BURST(AXI_DDR_FIXED_BURST),
        .AXI_DDR_WRAP_BURST(AXI_DDR_WRAP_BURST),
        .HBM_CH(HBM_CH),
        .HBM_ENABLE(HBM_ENABLE),
        .HBM_GROUP_SIZE(HBM_GROUP_SIZE),
        .AXI_HBM_DATA_WIDTH(AXI_HBM_DATA_WIDTH),
        .AXI_HBM_ADDR_WIDTH(AXI_HBM_ADDR_WIDTH),
        .AXI_HBM_STRB_WIDTH(AXI_HBM_STRB_WIDTH),
        .AXI_HBM_ID_WIDTH(AXI_HBM_ID_WIDTH),
        .AXI_HBM_AWUSER_ENABLE(AXI_HBM_AWUSER_ENABLE),
        .AXI_HBM_AWUSER_WIDTH(AXI_HBM_AWUSER_WIDTH),
        .AXI_HBM_WUSER_ENABLE(AXI_HBM_WUSER_ENABLE),
        .AXI_HBM_WUSER_WIDTH(AXI_HBM_WUSER_WIDTH),
        .AXI_HBM_BUSER_ENABLE(AXI_HBM_BUSER_ENABLE),
        .AXI_HBM_BUSER_WIDTH(AXI_HBM_BUSER_WIDTH),
        .AXI_HBM_ARUSER_ENABLE(AXI_HBM_ARUSER_ENABLE),
        .AXI_HBM_ARUSER_WIDTH(AXI_HBM_ARUSER_WIDTH),
        .AXI_HBM_RUSER_ENABLE(AXI_HBM_RUSER_ENABLE),
        .AXI_HBM_RUSER_WIDTH(AXI_HBM_RUSER_WIDTH),
        .AXI_HBM_MAX_BURST_LEN(AXI_HBM_MAX_BURST_LEN),
        .AXI_HBM_NARROW_BURST(AXI_HBM_NARROW_BURST),
        .AXI_HBM_FIXED_BURST(AXI_HBM_FIXED_BURST),
        .AXI_HBM_WRAP_BURST(AXI_HBM_WRAP_BURST),

        // Application configuration
        .APP_ID(APP_ID),
        .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
        .APP_DMA_ENABLE(APP_DMA_ENABLE),
        .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
        .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
        .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
        .APP_STAT_ENABLE(APP_STAT_ENABLE && STAT_ENABLE),

        // DMA interface configuration
        .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
        .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
        .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
        .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
        .DMA_TAG_WIDTH(IF_DMA_TAG_WIDTH),
        .RAM_SEG_COUNT(RAM_SEG_COUNT),
        .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
        .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
        .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
        .RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .RAM_PIPELINE(RAM_PIPELINE),

        // AXI lite interface (application control from host)
        .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
        .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),
        .AXIL_APP_CTRL_STRB_WIDTH(AXIL_APP_CTRL_STRB_WIDTH),

        // AXI lite interface (control to NIC)
        .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
        .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
        .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),

        // Ethernet interface configuration (direct, async)
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .AXIS_TX_USER_WIDTH(AXIS_TX_USER_WIDTH),
        .AXIS_RX_USER_WIDTH(AXIS_RX_USER_WIDTH),
        .AXIS_RX_USE_READY(AXIS_RX_USE_READY),

        // Ethernet interface configuration (direct, sync)
        .AXIS_SYNC_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
        .AXIS_SYNC_KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
        .AXIS_SYNC_TX_USER_WIDTH(AXIS_TX_USER_WIDTH),
        .AXIS_SYNC_RX_USER_WIDTH(AXIS_RX_USER_WIDTH),

        // Ethernet interface configuration (interface)
        .AXIS_IF_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
        .AXIS_IF_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
        .AXIS_IF_TX_ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
        .AXIS_IF_RX_ID_WIDTH(AXIS_IF_RX_ID_WIDTH),
        .AXIS_IF_TX_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
        .AXIS_IF_RX_DEST_WIDTH(AXIS_IF_RX_DEST_WIDTH),
        .AXIS_IF_TX_USER_WIDTH(AXIS_IF_TX_USER_WIDTH),
        .AXIS_IF_RX_USER_WIDTH(AXIS_IF_RX_USER_WIDTH),

        // Statistics counter subsystem
        .STAT_ENABLE(STAT_ENABLE),
        .STAT_INC_WIDTH(STAT_INC_WIDTH),
        .STAT_ID_WIDTH(STAT_ID_WIDTH)
    )
    app_block_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI-Lite slave interface (control from host)
         */
        .s_axil_app_ctrl_awaddr(s_axil_app_ctrl_awaddr),
        .s_axil_app_ctrl_awprot(s_axil_app_ctrl_awprot),
        .s_axil_app_ctrl_awvalid(s_axil_app_ctrl_awvalid),
        .s_axil_app_ctrl_awready(s_axil_app_ctrl_awready),
        .s_axil_app_ctrl_wdata(s_axil_app_ctrl_wdata),
        .s_axil_app_ctrl_wstrb(s_axil_app_ctrl_wstrb),
        .s_axil_app_ctrl_wvalid(s_axil_app_ctrl_wvalid),
        .s_axil_app_ctrl_wready(s_axil_app_ctrl_wready),
        .s_axil_app_ctrl_bresp(s_axil_app_ctrl_bresp),
        .s_axil_app_ctrl_bvalid(s_axil_app_ctrl_bvalid),
        .s_axil_app_ctrl_bready(s_axil_app_ctrl_bready),
        .s_axil_app_ctrl_araddr(s_axil_app_ctrl_araddr),
        .s_axil_app_ctrl_arprot(s_axil_app_ctrl_arprot),
        .s_axil_app_ctrl_arvalid(s_axil_app_ctrl_arvalid),
        .s_axil_app_ctrl_arready(s_axil_app_ctrl_arready),
        .s_axil_app_ctrl_rdata(s_axil_app_ctrl_rdata),
        .s_axil_app_ctrl_rresp(s_axil_app_ctrl_rresp),
        .s_axil_app_ctrl_rvalid(s_axil_app_ctrl_rvalid),
        .s_axil_app_ctrl_rready(s_axil_app_ctrl_rready),

        /*
         * AXI-Lite master interface (control to NIC)
         */
        .m_axil_ctrl_awaddr(axil_ctrl_app_awaddr),
        .m_axil_ctrl_awprot(axil_ctrl_app_awprot),
        .m_axil_ctrl_awvalid(axil_ctrl_app_awvalid),
        .m_axil_ctrl_awready(axil_ctrl_app_awready),
        .m_axil_ctrl_wdata(axil_ctrl_app_wdata),
        .m_axil_ctrl_wstrb(axil_ctrl_app_wstrb),
        .m_axil_ctrl_wvalid(axil_ctrl_app_wvalid),
        .m_axil_ctrl_wready(axil_ctrl_app_wready),
        .m_axil_ctrl_bresp(axil_ctrl_app_bresp),
        .m_axil_ctrl_bvalid(axil_ctrl_app_bvalid),
        .m_axil_ctrl_bready(axil_ctrl_app_bready),
        .m_axil_ctrl_araddr(axil_ctrl_app_araddr),
        .m_axil_ctrl_arprot(axil_ctrl_app_arprot),
        .m_axil_ctrl_arvalid(axil_ctrl_app_arvalid),
        .m_axil_ctrl_arready(axil_ctrl_app_arready),
        .m_axil_ctrl_rdata(axil_ctrl_app_rdata),
        .m_axil_ctrl_rresp(axil_ctrl_app_rresp),
        .m_axil_ctrl_rvalid(axil_ctrl_app_rvalid),
        .m_axil_ctrl_rready(axil_ctrl_app_rready),

        /*
         * DMA read descriptor output (control)
         */
        .m_axis_ctrl_dma_read_desc_dma_addr(app_ctrl_dma_read_desc_dma_addr),
        .m_axis_ctrl_dma_read_desc_ram_sel(app_ctrl_dma_read_desc_ram_sel),
        .m_axis_ctrl_dma_read_desc_ram_addr(app_ctrl_dma_read_desc_ram_addr),
        .m_axis_ctrl_dma_read_desc_len(app_ctrl_dma_read_desc_len),
        .m_axis_ctrl_dma_read_desc_tag(app_ctrl_dma_read_desc_tag),
        .m_axis_ctrl_dma_read_desc_valid(app_ctrl_dma_read_desc_valid),
        .m_axis_ctrl_dma_read_desc_ready(app_ctrl_dma_read_desc_ready),

        /*
         * DMA read descriptor status input (control)
         */
        .s_axis_ctrl_dma_read_desc_status_tag(app_ctrl_dma_read_desc_status_tag),
        .s_axis_ctrl_dma_read_desc_status_error(app_ctrl_dma_read_desc_status_error),
        .s_axis_ctrl_dma_read_desc_status_valid(app_ctrl_dma_read_desc_status_valid),

        /*
         * DMA write descriptor output (control)
         */
        .m_axis_ctrl_dma_write_desc_dma_addr(app_ctrl_dma_write_desc_dma_addr),
        .m_axis_ctrl_dma_write_desc_ram_sel(app_ctrl_dma_write_desc_ram_sel),
        .m_axis_ctrl_dma_write_desc_ram_addr(app_ctrl_dma_write_desc_ram_addr),
        .m_axis_ctrl_dma_write_desc_imm(app_ctrl_dma_write_desc_imm),
        .m_axis_ctrl_dma_write_desc_imm_en(app_ctrl_dma_write_desc_imm_en),
        .m_axis_ctrl_dma_write_desc_len(app_ctrl_dma_write_desc_len),
        .m_axis_ctrl_dma_write_desc_tag(app_ctrl_dma_write_desc_tag),
        .m_axis_ctrl_dma_write_desc_valid(app_ctrl_dma_write_desc_valid),
        .m_axis_ctrl_dma_write_desc_ready(app_ctrl_dma_write_desc_ready),

        /*
         * DMA write descriptor status input (control)
         */
        .s_axis_ctrl_dma_write_desc_status_tag(app_ctrl_dma_write_desc_status_tag),
        .s_axis_ctrl_dma_write_desc_status_error(app_ctrl_dma_write_desc_status_error),
        .s_axis_ctrl_dma_write_desc_status_valid(app_ctrl_dma_write_desc_status_valid),

        /*
         * DMA read descriptor output (data)
         */
        .m_axis_data_dma_read_desc_dma_addr(app_data_dma_read_desc_dma_addr),
        .m_axis_data_dma_read_desc_ram_sel(app_data_dma_read_desc_ram_sel),
        .m_axis_data_dma_read_desc_ram_addr(app_data_dma_read_desc_ram_addr),
        .m_axis_data_dma_read_desc_len(app_data_dma_read_desc_len),
        .m_axis_data_dma_read_desc_tag(app_data_dma_read_desc_tag),
        .m_axis_data_dma_read_desc_valid(app_data_dma_read_desc_valid),
        .m_axis_data_dma_read_desc_ready(app_data_dma_read_desc_ready),

        /*
         * DMA read descriptor status input (data)
         */
        .s_axis_data_dma_read_desc_status_tag(app_data_dma_read_desc_status_tag),
        .s_axis_data_dma_read_desc_status_error(app_data_dma_read_desc_status_error),
        .s_axis_data_dma_read_desc_status_valid(app_data_dma_read_desc_status_valid),

        /*
         * DMA write descriptor output (data)
         */
        .m_axis_data_dma_write_desc_dma_addr(app_data_dma_write_desc_dma_addr),
        .m_axis_data_dma_write_desc_ram_sel(app_data_dma_write_desc_ram_sel),
        .m_axis_data_dma_write_desc_ram_addr(app_data_dma_write_desc_ram_addr),
        .m_axis_data_dma_write_desc_imm(app_data_dma_write_desc_imm),
        .m_axis_data_dma_write_desc_imm_en(app_data_dma_write_desc_imm_en),
        .m_axis_data_dma_write_desc_len(app_data_dma_write_desc_len),
        .m_axis_data_dma_write_desc_tag(app_data_dma_write_desc_tag),
        .m_axis_data_dma_write_desc_valid(app_data_dma_write_desc_valid),
        .m_axis_data_dma_write_desc_ready(app_data_dma_write_desc_ready),

        /*
         * DMA write descriptor status input (data)
         */
        .s_axis_data_dma_write_desc_status_tag(app_data_dma_write_desc_status_tag),
        .s_axis_data_dma_write_desc_status_error(app_data_dma_write_desc_status_error),
        .s_axis_data_dma_write_desc_status_valid(app_data_dma_write_desc_status_valid),

        /*
         * RAM interface (control)
         */
        .ctrl_dma_ram_wr_cmd_sel(app_ctrl_dma_ram_wr_cmd_sel),
        .ctrl_dma_ram_wr_cmd_be(app_ctrl_dma_ram_wr_cmd_be),
        .ctrl_dma_ram_wr_cmd_addr(app_ctrl_dma_ram_wr_cmd_addr),
        .ctrl_dma_ram_wr_cmd_data(app_ctrl_dma_ram_wr_cmd_data),
        .ctrl_dma_ram_wr_cmd_valid(app_ctrl_dma_ram_wr_cmd_valid),
        .ctrl_dma_ram_wr_cmd_ready(app_ctrl_dma_ram_wr_cmd_ready),
        .ctrl_dma_ram_wr_done(app_ctrl_dma_ram_wr_done),
        .ctrl_dma_ram_rd_cmd_sel(app_ctrl_dma_ram_rd_cmd_sel),
        .ctrl_dma_ram_rd_cmd_addr(app_ctrl_dma_ram_rd_cmd_addr),
        .ctrl_dma_ram_rd_cmd_valid(app_ctrl_dma_ram_rd_cmd_valid),
        .ctrl_dma_ram_rd_cmd_ready(app_ctrl_dma_ram_rd_cmd_ready),
        .ctrl_dma_ram_rd_resp_data(app_ctrl_dma_ram_rd_resp_data),
        .ctrl_dma_ram_rd_resp_valid(app_ctrl_dma_ram_rd_resp_valid),
        .ctrl_dma_ram_rd_resp_ready(app_ctrl_dma_ram_rd_resp_ready),

        /*
         * RAM interface (data)
         */
        .data_dma_ram_wr_cmd_sel(app_data_dma_ram_wr_cmd_sel),
        .data_dma_ram_wr_cmd_be(app_data_dma_ram_wr_cmd_be),
        .data_dma_ram_wr_cmd_addr(app_data_dma_ram_wr_cmd_addr),
        .data_dma_ram_wr_cmd_data(app_data_dma_ram_wr_cmd_data),
        .data_dma_ram_wr_cmd_valid(app_data_dma_ram_wr_cmd_valid),
        .data_dma_ram_wr_cmd_ready(app_data_dma_ram_wr_cmd_ready),
        .data_dma_ram_wr_done(app_data_dma_ram_wr_done),
        .data_dma_ram_rd_cmd_sel(app_data_dma_ram_rd_cmd_sel),
        .data_dma_ram_rd_cmd_addr(app_data_dma_ram_rd_cmd_addr),
        .data_dma_ram_rd_cmd_valid(app_data_dma_ram_rd_cmd_valid),
        .data_dma_ram_rd_cmd_ready(app_data_dma_ram_rd_cmd_ready),
        .data_dma_ram_rd_resp_data(app_data_dma_ram_rd_resp_data),
        .data_dma_ram_rd_resp_valid(app_data_dma_ram_rd_resp_valid),
        .data_dma_ram_rd_resp_ready(app_data_dma_ram_rd_resp_ready),

        /*
         * PTP clock
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_sample_clk(ptp_sample_clk),
        .ptp_td_sd(ptp_td_sd),
        .ptp_pps(ptp_pps),
        .ptp_pps_str(ptp_pps_str),
        .ptp_sync_locked(ptp_sync_locked),
        .ptp_sync_ts_rel(ptp_sync_ts_rel),
        .ptp_sync_ts_rel_step(ptp_sync_ts_rel_step),
        .ptp_sync_ts_tod(ptp_sync_ts_tod),
        .ptp_sync_ts_tod_step(ptp_sync_ts_tod_step),
        .ptp_sync_pps(ptp_sync_pps),
        .ptp_sync_pps_str(ptp_sync_pps_str),
        .ptp_perout_locked(ptp_perout_locked),
        .ptp_perout_error(ptp_perout_error),
        .ptp_perout_pulse(ptp_perout_pulse),

        /*
         * Ethernet (direct MAC interface - lowest latency raw traffic)
         */
        .direct_tx_clk(app_direct_tx_clk),
        .direct_tx_rst(app_direct_tx_rst),

        .s_axis_direct_tx_tdata(app_s_axis_direct_tx_tdata),
        .s_axis_direct_tx_tkeep(app_s_axis_direct_tx_tkeep),
        .s_axis_direct_tx_tvalid(app_s_axis_direct_tx_tvalid),
        .s_axis_direct_tx_tready(app_s_axis_direct_tx_tready),
        .s_axis_direct_tx_tlast(app_s_axis_direct_tx_tlast),
        .s_axis_direct_tx_tuser(app_s_axis_direct_tx_tuser),

        .m_axis_direct_tx_tdata(app_m_axis_direct_tx_tdata),
        .m_axis_direct_tx_tkeep(app_m_axis_direct_tx_tkeep),
        .m_axis_direct_tx_tvalid(app_m_axis_direct_tx_tvalid),
        .m_axis_direct_tx_tready(app_m_axis_direct_tx_tready),
        .m_axis_direct_tx_tlast(app_m_axis_direct_tx_tlast),
        .m_axis_direct_tx_tuser(app_m_axis_direct_tx_tuser),

        .s_axis_direct_tx_cpl_ts(app_s_axis_direct_tx_cpl_ts),
        .s_axis_direct_tx_cpl_tag(app_s_axis_direct_tx_cpl_tag),
        .s_axis_direct_tx_cpl_valid(app_s_axis_direct_tx_cpl_valid),
        .s_axis_direct_tx_cpl_ready(app_s_axis_direct_tx_cpl_ready),

        .m_axis_direct_tx_cpl_ts(app_m_axis_direct_tx_cpl_ts),
        .m_axis_direct_tx_cpl_tag(app_m_axis_direct_tx_cpl_tag),
        .m_axis_direct_tx_cpl_valid(app_m_axis_direct_tx_cpl_valid),
        .m_axis_direct_tx_cpl_ready(app_m_axis_direct_tx_cpl_ready),

        .direct_rx_clk(app_direct_rx_clk),
        .direct_rx_rst(app_direct_rx_rst),

        .s_axis_direct_rx_tdata(app_s_axis_direct_rx_tdata),
        .s_axis_direct_rx_tkeep(app_s_axis_direct_rx_tkeep),
        .s_axis_direct_rx_tvalid(app_s_axis_direct_rx_tvalid),
        .s_axis_direct_rx_tready(app_s_axis_direct_rx_tready),
        .s_axis_direct_rx_tlast(app_s_axis_direct_rx_tlast),
        .s_axis_direct_rx_tuser(app_s_axis_direct_rx_tuser),

        .m_axis_direct_rx_tdata(app_m_axis_direct_rx_tdata),
        .m_axis_direct_rx_tkeep(app_m_axis_direct_rx_tkeep),
        .m_axis_direct_rx_tvalid(app_m_axis_direct_rx_tvalid),
        .m_axis_direct_rx_tready(app_m_axis_direct_rx_tready),
        .m_axis_direct_rx_tlast(app_m_axis_direct_rx_tlast),
        .m_axis_direct_rx_tuser(app_m_axis_direct_rx_tuser),

        /*
         * Ethernet (synchronous MAC interface - low latency raw traffic)
         */
        .s_axis_sync_tx_tdata(app_s_axis_sync_tx_tdata),
        .s_axis_sync_tx_tkeep(app_s_axis_sync_tx_tkeep),
        .s_axis_sync_tx_tvalid(app_s_axis_sync_tx_tvalid),
        .s_axis_sync_tx_tready(app_s_axis_sync_tx_tready),
        .s_axis_sync_tx_tlast(app_s_axis_sync_tx_tlast),
        .s_axis_sync_tx_tuser(app_s_axis_sync_tx_tuser),

        .m_axis_sync_tx_tdata(app_m_axis_sync_tx_tdata),
        .m_axis_sync_tx_tkeep(app_m_axis_sync_tx_tkeep),
        .m_axis_sync_tx_tvalid(app_m_axis_sync_tx_tvalid),
        .m_axis_sync_tx_tready(app_m_axis_sync_tx_tready),
        .m_axis_sync_tx_tlast(app_m_axis_sync_tx_tlast),
        .m_axis_sync_tx_tuser(app_m_axis_sync_tx_tuser),

        .s_axis_sync_tx_cpl_ts(app_s_axis_sync_tx_cpl_ts),
        .s_axis_sync_tx_cpl_tag(app_s_axis_sync_tx_cpl_tag),
        .s_axis_sync_tx_cpl_valid(app_s_axis_sync_tx_cpl_valid),
        .s_axis_sync_tx_cpl_ready(app_s_axis_sync_tx_cpl_ready),

        .m_axis_sync_tx_cpl_ts(app_m_axis_sync_tx_cpl_ts),
        .m_axis_sync_tx_cpl_tag(app_m_axis_sync_tx_cpl_tag),
        .m_axis_sync_tx_cpl_valid(app_m_axis_sync_tx_cpl_valid),
        .m_axis_sync_tx_cpl_ready(app_m_axis_sync_tx_cpl_ready),

        .s_axis_sync_rx_tdata(app_s_axis_sync_rx_tdata),
        .s_axis_sync_rx_tkeep(app_s_axis_sync_rx_tkeep),
        .s_axis_sync_rx_tvalid(app_s_axis_sync_rx_tvalid),
        .s_axis_sync_rx_tready(app_s_axis_sync_rx_tready),
        .s_axis_sync_rx_tlast(app_s_axis_sync_rx_tlast),
        .s_axis_sync_rx_tuser(app_s_axis_sync_rx_tuser),

        .m_axis_sync_rx_tdata(app_m_axis_sync_rx_tdata),
        .m_axis_sync_rx_tkeep(app_m_axis_sync_rx_tkeep),
        .m_axis_sync_rx_tvalid(app_m_axis_sync_rx_tvalid),
        .m_axis_sync_rx_tready(app_m_axis_sync_rx_tready),
        .m_axis_sync_rx_tlast(app_m_axis_sync_rx_tlast),
        .m_axis_sync_rx_tuser(app_m_axis_sync_rx_tuser),

        /*
         * Ethernet (internal at interface module)
         */
        .s_axis_if_tx_tdata(app_s_axis_if_tx_tdata),
        .s_axis_if_tx_tkeep(app_s_axis_if_tx_tkeep),
        .s_axis_if_tx_tvalid(app_s_axis_if_tx_tvalid),
        .s_axis_if_tx_tready(app_s_axis_if_tx_tready),
        .s_axis_if_tx_tlast(app_s_axis_if_tx_tlast),
        .s_axis_if_tx_tid(app_s_axis_if_tx_tid),
        .s_axis_if_tx_tdest(app_s_axis_if_tx_tdest),
        .s_axis_if_tx_tuser(app_s_axis_if_tx_tuser),

        .m_axis_if_tx_tdata(app_m_axis_if_tx_tdata),
        .m_axis_if_tx_tkeep(app_m_axis_if_tx_tkeep),
        .m_axis_if_tx_tvalid(app_m_axis_if_tx_tvalid),
        .m_axis_if_tx_tready(app_m_axis_if_tx_tready),
        .m_axis_if_tx_tlast(app_m_axis_if_tx_tlast),
        .m_axis_if_tx_tid(app_m_axis_if_tx_tid),
        .m_axis_if_tx_tdest(app_m_axis_if_tx_tdest),
        .m_axis_if_tx_tuser(app_m_axis_if_tx_tuser),

        .s_axis_if_tx_cpl_ts(app_s_axis_if_tx_cpl_ts),
        .s_axis_if_tx_cpl_tag(app_s_axis_if_tx_cpl_tag),
        .s_axis_if_tx_cpl_valid(app_s_axis_if_tx_cpl_valid),
        .s_axis_if_tx_cpl_ready(app_s_axis_if_tx_cpl_ready),

        .m_axis_if_tx_cpl_ts(app_m_axis_if_tx_cpl_ts),
        .m_axis_if_tx_cpl_tag(app_m_axis_if_tx_cpl_tag),
        .m_axis_if_tx_cpl_valid(app_m_axis_if_tx_cpl_valid),
        .m_axis_if_tx_cpl_ready(app_m_axis_if_tx_cpl_ready),

        .s_axis_if_rx_tdata(app_s_axis_if_rx_tdata),
        .s_axis_if_rx_tkeep(app_s_axis_if_rx_tkeep),
        .s_axis_if_rx_tvalid(app_s_axis_if_rx_tvalid),
        .s_axis_if_rx_tready(app_s_axis_if_rx_tready),
        .s_axis_if_rx_tlast(app_s_axis_if_rx_tlast),
        .s_axis_if_rx_tid(app_s_axis_if_rx_tid),
        .s_axis_if_rx_tdest(app_s_axis_if_rx_tdest),
        .s_axis_if_rx_tuser(app_s_axis_if_rx_tuser),

        .m_axis_if_rx_tdata(app_m_axis_if_rx_tdata),
        .m_axis_if_rx_tkeep(app_m_axis_if_rx_tkeep),
        .m_axis_if_rx_tvalid(app_m_axis_if_rx_tvalid),
        .m_axis_if_rx_tready(app_m_axis_if_rx_tready),
        .m_axis_if_rx_tlast(app_m_axis_if_rx_tlast),
        .m_axis_if_rx_tid(app_m_axis_if_rx_tid),
        .m_axis_if_rx_tdest(app_m_axis_if_rx_tdest),
        .m_axis_if_rx_tuser(app_m_axis_if_rx_tuser),

        /*
         * DDR
         */
        .ddr_clk(app_ddr_clk),
        .ddr_rst(app_ddr_rst),

        .m_axi_ddr_awid(app_m_axi_ddr_awid),
        .m_axi_ddr_awaddr(app_m_axi_ddr_awaddr),
        .m_axi_ddr_awlen(app_m_axi_ddr_awlen),
        .m_axi_ddr_awsize(app_m_axi_ddr_awsize),
        .m_axi_ddr_awburst(app_m_axi_ddr_awburst),
        .m_axi_ddr_awlock(app_m_axi_ddr_awlock),
        .m_axi_ddr_awcache(app_m_axi_ddr_awcache),
        .m_axi_ddr_awprot(app_m_axi_ddr_awprot),
        .m_axi_ddr_awqos(app_m_axi_ddr_awqos),
        .m_axi_ddr_awuser(app_m_axi_ddr_awuser),
        .m_axi_ddr_awvalid(app_m_axi_ddr_awvalid),
        .m_axi_ddr_awready(app_m_axi_ddr_awready),
        .m_axi_ddr_wdata(app_m_axi_ddr_wdata),
        .m_axi_ddr_wstrb(app_m_axi_ddr_wstrb),
        .m_axi_ddr_wlast(app_m_axi_ddr_wlast),
        .m_axi_ddr_wuser(app_m_axi_ddr_wuser),
        .m_axi_ddr_wvalid(app_m_axi_ddr_wvalid),
        .m_axi_ddr_wready(app_m_axi_ddr_wready),
        .m_axi_ddr_bid(app_m_axi_ddr_bid),
        .m_axi_ddr_bresp(app_m_axi_ddr_bresp),
        .m_axi_ddr_buser(app_m_axi_ddr_buser),
        .m_axi_ddr_bvalid(app_m_axi_ddr_bvalid),
        .m_axi_ddr_bready(app_m_axi_ddr_bready),
        .m_axi_ddr_arid(app_m_axi_ddr_arid),
        .m_axi_ddr_araddr(app_m_axi_ddr_araddr),
        .m_axi_ddr_arlen(app_m_axi_ddr_arlen),
        .m_axi_ddr_arsize(app_m_axi_ddr_arsize),
        .m_axi_ddr_arburst(app_m_axi_ddr_arburst),
        .m_axi_ddr_arlock(app_m_axi_ddr_arlock),
        .m_axi_ddr_arcache(app_m_axi_ddr_arcache),
        .m_axi_ddr_arprot(app_m_axi_ddr_arprot),
        .m_axi_ddr_arqos(app_m_axi_ddr_arqos),
        .m_axi_ddr_aruser(app_m_axi_ddr_aruser),
        .m_axi_ddr_arvalid(app_m_axi_ddr_arvalid),
        .m_axi_ddr_arready(app_m_axi_ddr_arready),
        .m_axi_ddr_rid(app_m_axi_ddr_rid),
        .m_axi_ddr_rdata(app_m_axi_ddr_rdata),
        .m_axi_ddr_rresp(app_m_axi_ddr_rresp),
        .m_axi_ddr_rlast(app_m_axi_ddr_rlast),
        .m_axi_ddr_ruser(app_m_axi_ddr_ruser),
        .m_axi_ddr_rvalid(app_m_axi_ddr_rvalid),
        .m_axi_ddr_rready(app_m_axi_ddr_rready),

        .ddr_status(ddr_status),

        /*
         * HBM
         */
        .hbm_clk(app_hbm_clk),
        .hbm_rst(app_hbm_rst),

        .m_axi_hbm_awid(app_m_axi_hbm_awid),
        .m_axi_hbm_awaddr(app_m_axi_hbm_awaddr),
        .m_axi_hbm_awlen(app_m_axi_hbm_awlen),
        .m_axi_hbm_awsize(app_m_axi_hbm_awsize),
        .m_axi_hbm_awburst(app_m_axi_hbm_awburst),
        .m_axi_hbm_awlock(app_m_axi_hbm_awlock),
        .m_axi_hbm_awcache(app_m_axi_hbm_awcache),
        .m_axi_hbm_awprot(app_m_axi_hbm_awprot),
        .m_axi_hbm_awqos(app_m_axi_hbm_awqos),
        .m_axi_hbm_awuser(app_m_axi_hbm_awuser),
        .m_axi_hbm_awvalid(app_m_axi_hbm_awvalid),
        .m_axi_hbm_awready(app_m_axi_hbm_awready),
        .m_axi_hbm_wdata(app_m_axi_hbm_wdata),
        .m_axi_hbm_wstrb(app_m_axi_hbm_wstrb),
        .m_axi_hbm_wlast(app_m_axi_hbm_wlast),
        .m_axi_hbm_wuser(app_m_axi_hbm_wuser),
        .m_axi_hbm_wvalid(app_m_axi_hbm_wvalid),
        .m_axi_hbm_wready(app_m_axi_hbm_wready),
        .m_axi_hbm_bid(app_m_axi_hbm_bid),
        .m_axi_hbm_bresp(app_m_axi_hbm_bresp),
        .m_axi_hbm_buser(app_m_axi_hbm_buser),
        .m_axi_hbm_bvalid(app_m_axi_hbm_bvalid),
        .m_axi_hbm_bready(app_m_axi_hbm_bready),
        .m_axi_hbm_arid(app_m_axi_hbm_arid),
        .m_axi_hbm_araddr(app_m_axi_hbm_araddr),
        .m_axi_hbm_arlen(app_m_axi_hbm_arlen),
        .m_axi_hbm_arsize(app_m_axi_hbm_arsize),
        .m_axi_hbm_arburst(app_m_axi_hbm_arburst),
        .m_axi_hbm_arlock(app_m_axi_hbm_arlock),
        .m_axi_hbm_arcache(app_m_axi_hbm_arcache),
        .m_axi_hbm_arprot(app_m_axi_hbm_arprot),
        .m_axi_hbm_arqos(app_m_axi_hbm_arqos),
        .m_axi_hbm_aruser(app_m_axi_hbm_aruser),
        .m_axi_hbm_arvalid(app_m_axi_hbm_arvalid),
        .m_axi_hbm_arready(app_m_axi_hbm_arready),
        .m_axi_hbm_rid(app_m_axi_hbm_rid),
        .m_axi_hbm_rdata(app_m_axi_hbm_rdata),
        .m_axi_hbm_rresp(app_m_axi_hbm_rresp),
        .m_axi_hbm_rlast(app_m_axi_hbm_rlast),
        .m_axi_hbm_ruser(app_m_axi_hbm_ruser),
        .m_axi_hbm_rvalid(app_m_axi_hbm_rvalid),
        .m_axi_hbm_rready(app_m_axi_hbm_rready),

        .hbm_status(hbm_status),

        /*
         * Statistics increment output
         */
        .m_axis_stat_tdata(axis_app_stat_tdata),
        .m_axis_stat_tid(axis_app_stat_tid),
        .m_axis_stat_tvalid(axis_app_stat_tvalid),
        .m_axis_stat_tready(axis_app_stat_tready),

        /*
         * GPIO
         */
        .gpio_in(app_gpio_in),
        .gpio_out(app_gpio_out),

        /*
         * JTAG
         */
        .jtag_tdi(app_jtag_tdi),
        .jtag_tdo(app_jtag_tdo),
        .jtag_tms(app_jtag_tms),
        .jtag_tck(app_jtag_tck)
    );

end else begin

    assign s_axil_app_ctrl_awready = 1'b0;
    assign s_axil_app_ctrl_wready = 1'b0;
    assign s_axil_app_ctrl_bresp = 0;
    assign s_axil_app_ctrl_bvalid = 1'b0;
    assign s_axil_app_ctrl_arready = 1'b0;
    assign s_axil_app_ctrl_rdata = 0;
    assign s_axil_app_ctrl_rresp = 0;
    assign s_axil_app_ctrl_rvalid = 1'b0;

    assign axil_ctrl_app_awaddr = 0;
    assign axil_ctrl_app_awprot = 0;
    assign axil_ctrl_app_awvalid = 1'b0;
    assign axil_ctrl_app_wdata = 0;
    assign axil_ctrl_app_wstrb = 0;
    assign axil_ctrl_app_wvalid = 1'b0;
    assign axil_ctrl_app_bready = 1'b0;
    assign axil_ctrl_app_araddr = 0;
    assign axil_ctrl_app_arprot = 0;
    assign axil_ctrl_app_arvalid = 1'b0;
    assign axil_ctrl_app_rready = 1'b0;

    assign app_ctrl_dma_read_desc_dma_addr = 0;
    assign app_ctrl_dma_read_desc_ram_sel = 0;
    assign app_ctrl_dma_read_desc_ram_addr = 0;
    assign app_ctrl_dma_read_desc_len = 0;
    assign app_ctrl_dma_read_desc_tag = 0;
    assign app_ctrl_dma_read_desc_valid = 0;

    assign app_ctrl_dma_write_desc_dma_addr = 0;
    assign app_ctrl_dma_write_desc_ram_sel = 0;
    assign app_ctrl_dma_write_desc_ram_addr = 0;
    assign app_ctrl_dma_write_desc_imm = 0;
    assign app_ctrl_dma_write_desc_imm_en = 0;
    assign app_ctrl_dma_write_desc_len = 0;
    assign app_ctrl_dma_write_desc_tag = 0;
    assign app_ctrl_dma_write_desc_valid = 0;

    assign app_data_dma_read_desc_dma_addr = 0;
    assign app_data_dma_read_desc_ram_sel = 0;
    assign app_data_dma_read_desc_ram_addr = 0;
    assign app_data_dma_read_desc_len = 0;
    assign app_data_dma_read_desc_tag = 0;
    assign app_data_dma_read_desc_valid = 0;

    assign app_data_dma_write_desc_dma_addr = 0;
    assign app_data_dma_write_desc_ram_sel = 0;
    assign app_data_dma_write_desc_ram_addr = 0;
    assign app_data_dma_write_desc_imm = 0;
    assign app_data_dma_write_desc_imm_en = 0;
    assign app_data_dma_write_desc_len = 0;
    assign app_data_dma_write_desc_tag = 0;
    assign app_data_dma_write_desc_valid = 0;

    assign app_ctrl_dma_ram_wr_cmd_ready = 0;
    assign app_ctrl_dma_ram_wr_done = 0;
    assign app_ctrl_dma_ram_rd_cmd_ready = 0;
    assign app_ctrl_dma_ram_rd_resp_data = 0;
    assign app_ctrl_dma_ram_rd_resp_valid = 0;

    assign app_data_dma_ram_wr_cmd_ready = 0;
    assign app_data_dma_ram_wr_done = 0;
    assign app_data_dma_ram_rd_cmd_ready = 0;
    assign app_data_dma_ram_rd_resp_data = 0;
    assign app_data_dma_ram_rd_resp_valid = 0;

    assign app_s_axis_direct_tx_tready = 0;

    assign app_m_axis_direct_tx_tdata = 0;
    assign app_m_axis_direct_tx_tkeep = 0;
    assign app_m_axis_direct_tx_tvalid = 0;
    assign app_m_axis_direct_tx_tlast = 0;
    assign app_m_axis_direct_tx_tuser = 0;

    assign app_s_axis_direct_tx_cpl_ready = 0;

    assign app_m_axis_direct_tx_cpl_ts = 0;
    assign app_m_axis_direct_tx_cpl_tag = 0;
    assign app_m_axis_direct_tx_cpl_valid = 0;

    assign app_s_axis_direct_rx_tready = 0;

    assign app_m_axis_direct_rx_tdata = 0;
    assign app_m_axis_direct_rx_tkeep = 0;
    assign app_m_axis_direct_rx_tvalid = 0;
    assign app_m_axis_direct_rx_tlast = 0;
    assign app_m_axis_direct_rx_tuser = 0;

    assign app_s_axis_sync_tx_tready = 0;

    assign app_m_axis_sync_tx_tdata = 0;
    assign app_m_axis_sync_tx_tkeep = 0;
    assign app_m_axis_sync_tx_tvalid = 0;
    assign app_m_axis_sync_tx_tlast = 0;
    assign app_m_axis_sync_tx_tuser = 0;

    assign app_s_axis_sync_tx_cpl_ready = 0;

    assign app_m_axis_sync_tx_cpl_ts = 0;
    assign app_m_axis_sync_tx_cpl_tag = 0;
    assign app_m_axis_sync_tx_cpl_valid = 0;

    assign app_s_axis_sync_rx_tready = 0;

    assign app_m_axis_sync_rx_tdata = 0;
    assign app_m_axis_sync_rx_tkeep = 0;
    assign app_m_axis_sync_rx_tvalid = 0;
    assign app_m_axis_sync_rx_tlast = 0;
    assign app_m_axis_sync_rx_tuser = 0;

    assign app_s_axis_if_tx_tready = 0;

    assign app_m_axis_if_tx_tdata = 0;
    assign app_m_axis_if_tx_tkeep = 0;
    assign app_m_axis_if_tx_tvalid = 0;
    assign app_m_axis_if_tx_tlast = 0;
    assign app_m_axis_if_tx_tid = 0;
    assign app_m_axis_if_tx_tdest = 0;
    assign app_m_axis_if_tx_tuser = 0;

    assign app_s_axis_if_tx_cpl_ready = 0;

    assign app_m_axis_if_tx_cpl_ts = 0;
    assign app_m_axis_if_tx_cpl_tag = 0;
    assign app_m_axis_if_tx_cpl_valid = 0;

    assign app_s_axis_if_rx_tready = 0;

    assign app_m_axis_if_rx_tdata = 0;
    assign app_m_axis_if_rx_tkeep = 0;
    assign app_m_axis_if_rx_tvalid = 0;
    assign app_m_axis_if_rx_tlast = 0;
    assign app_m_axis_if_rx_tid = 0;
    assign app_m_axis_if_rx_tdest = 0;
    assign app_m_axis_if_rx_tuser = 0;

    assign app_m_axi_ddr_awid = 0;
    assign app_m_axi_ddr_awaddr = 0;
    assign app_m_axi_ddr_awlen = 0;
    assign app_m_axi_ddr_awsize = 0;
    assign app_m_axi_ddr_awburst = 0;
    assign app_m_axi_ddr_awlock = 0;
    assign app_m_axi_ddr_awcache = 0;
    assign app_m_axi_ddr_awprot = 0;
    assign app_m_axi_ddr_awqos = 0;
    assign app_m_axi_ddr_awuser = 0;
    assign app_m_axi_ddr_awvalid = 0;
    assign app_m_axi_ddr_wdata = 0;
    assign app_m_axi_ddr_wstrb = 0;
    assign app_m_axi_ddr_wlast = 0;
    assign app_m_axi_ddr_wuser = 0;
    assign app_m_axi_ddr_wvalid = 0;
    assign app_m_axi_ddr_bready = 0;
    assign app_m_axi_ddr_arid = 0;
    assign app_m_axi_ddr_araddr = 0;
    assign app_m_axi_ddr_arlen = 0;
    assign app_m_axi_ddr_arsize = 0;
    assign app_m_axi_ddr_arburst = 0;
    assign app_m_axi_ddr_arlock = 0;
    assign app_m_axi_ddr_arcache = 0;
    assign app_m_axi_ddr_arprot = 0;
    assign app_m_axi_ddr_arqos = 0;
    assign app_m_axi_ddr_aruser = 0;
    assign app_m_axi_ddr_arvalid = 0;
    assign app_m_axi_ddr_rready = 0;

    assign app_m_axi_hbm_awid = 0;
    assign app_m_axi_hbm_awaddr = 0;
    assign app_m_axi_hbm_awlen = 0;
    assign app_m_axi_hbm_awsize = 0;
    assign app_m_axi_hbm_awburst = 0;
    assign app_m_axi_hbm_awlock = 0;
    assign app_m_axi_hbm_awcache = 0;
    assign app_m_axi_hbm_awprot = 0;
    assign app_m_axi_hbm_awqos = 0;
    assign app_m_axi_hbm_awuser = 0;
    assign app_m_axi_hbm_awvalid = 0;
    assign app_m_axi_hbm_wdata = 0;
    assign app_m_axi_hbm_wstrb = 0;
    assign app_m_axi_hbm_wlast = 0;
    assign app_m_axi_hbm_wuser = 0;
    assign app_m_axi_hbm_wvalid = 0;
    assign app_m_axi_hbm_bready = 0;
    assign app_m_axi_hbm_arid = 0;
    assign app_m_axi_hbm_araddr = 0;
    assign app_m_axi_hbm_arlen = 0;
    assign app_m_axi_hbm_arsize = 0;
    assign app_m_axi_hbm_arburst = 0;
    assign app_m_axi_hbm_arlock = 0;
    assign app_m_axi_hbm_arcache = 0;
    assign app_m_axi_hbm_arprot = 0;
    assign app_m_axi_hbm_arqos = 0;
    assign app_m_axi_hbm_aruser = 0;
    assign app_m_axi_hbm_arvalid = 0;
    assign app_m_axi_hbm_rready = 0;

    assign axis_app_stat_tdata = 0;
    assign axis_app_stat_tid = 0;
    assign axis_app_stat_tvalid = 1'b0;

    assign app_gpio_out = 0;

    assign app_jtag_tdo = app_jtag_tdi;

end

endgenerate

endmodule

`resetall
