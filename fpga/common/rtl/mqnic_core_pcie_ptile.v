// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

`ifdef APP_CUSTOM_PARAMS_ENABLE
    `include "mqnic_app_custom_params.vh"
`endif

`ifdef APP_CUSTOM_PORTS_ENABLE
    `include "mqnic_app_custom_ports.vh"
`endif

/*
 * mqnic core logic - Intel P-Tile wrapper
 */
module mqnic_core_pcie_ptile #
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

    // Custom application block parameters
    `ifdef APP_CUSTOM_PARAMS_ENABLE
        `APP_CUSTOM_PARAMS_DECL
    `endif

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter SEG_COUNT = 1,
    parameter SEG_DATA_WIDTH = 256,
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    parameter SEG_HDR_WIDTH = 128,
    parameter SEG_PRFX_WIDTH = 32,
    parameter TX_SEQ_NUM_WIDTH = 6,
    parameter TX_SEQ_NUM_ENABLE = 1,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter F_COUNT = PF_COUNT+VF_COUNT,
    parameter PCIE_TAG_COUNT = 256,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_READ_CPLH_FC_LIMIT = 1144,
    parameter PCIE_DMA_READ_CPLD_FC_LIMIT = 2888,
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_WRITE_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = EQN_WIDTH,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),
    parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT),
    parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((SCHED_PER_IF+4+7)/8),
    parameter AXIL_CSR_PASSTHROUGH_ENABLE = 0,
    parameter RB_NEXT_PTR = 0,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
    parameter AXIS_ETH_DATA_WIDTH = 512,
    parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8,
    parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH,
    parameter AXIS_ETH_IF_DATA_WIDTH = AXIS_ETH_SYNC_DATA_WIDTH*2**$clog2(PORTS_PER_IF),
    parameter AXIS_ETH_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_ETH_RX_USE_READY = 0,
    parameter AXIS_ETH_TX_PIPELINE = 0,
    parameter AXIS_ETH_TX_FIFO_PIPELINE = 2,
    parameter AXIS_ETH_TX_TS_PIPELINE = 0,
    parameter AXIS_ETH_RX_PIPELINE = 0,
    parameter AXIS_ETH_RX_FIFO_PIPELINE = 2,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_DMA_ENABLE = 1,
    parameter STAT_PCIE_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * P-Tile RX AVST interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]           rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]          rx_st_empty,
    input  wire [SEG_COUNT-1:0]                          rx_st_sop,
    input  wire [SEG_COUNT-1:0]                          rx_st_eop,
    input  wire [SEG_COUNT-1:0]                          rx_st_valid,
    output wire                                          rx_st_ready,
    input  wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]            rx_st_hdr,
    input  wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]           rx_st_tlp_prfx,
    input  wire [SEG_COUNT-1:0]                          rx_st_vf_active,
    input  wire [SEG_COUNT*3-1:0]                        rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]                       rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                        rx_st_bar_range,
    input  wire [SEG_COUNT-1:0]                          rx_st_tlp_abort,

    /*
     * P-Tile TX AVST interface
     */
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]           tx_st_data,
    output wire [SEG_COUNT-1:0]                          tx_st_sop,
    output wire [SEG_COUNT-1:0]                          tx_st_eop,
    output wire [SEG_COUNT-1:0]                          tx_st_valid,
    input  wire                                          tx_st_ready,
    output wire [SEG_COUNT-1:0]                          tx_st_err,
    output wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]            tx_st_hdr,
    output wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]           tx_st_tlp_prfx,

    /*
     * P-Tile RX flow control
     */
    output wire [11:0]                                   rx_buffer_limit,
    output wire [1:0]                                    rx_buffer_limit_tdm_idx,

    /*
     * P-Tile TX flow control
     */
    input  wire [15:0]                                   tx_cdts_limit,
    input  wire [2:0]                                    tx_cdts_limit_tdm_idx,

    /*
     * P-Tile configuration interface
     */
    input  wire [15:0]                                   tl_cfg_ctl,
    input  wire [4:0]                                    tl_cfg_add,
    input  wire [2:0]                                    tl_cfg_func,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                m_axil_csr_awaddr,
    output wire [2:0]                                    m_axil_csr_awprot,
    output wire                                          m_axil_csr_awvalid,
    input  wire                                          m_axil_csr_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]               m_axil_csr_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]               m_axil_csr_wstrb,
    output wire                                          m_axil_csr_wvalid,
    input  wire                                          m_axil_csr_wready,
    input  wire [1:0]                                    m_axil_csr_bresp,
    input  wire                                          m_axil_csr_bvalid,
    output wire                                          m_axil_csr_bready,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                m_axil_csr_araddr,
    output wire [2:0]                                    m_axil_csr_arprot,
    output wire                                          m_axil_csr_arvalid,
    input  wire                                          m_axil_csr_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]               m_axil_csr_rdata,
    input  wire [1:0]                                    m_axil_csr_rresp,
    input  wire                                          m_axil_csr_rvalid,
    output wire                                          m_axil_csr_rready,

    /*
     * Control register interface
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                ctrl_reg_wr_addr,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]               ctrl_reg_wr_data,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]               ctrl_reg_wr_strb,
    output wire                                          ctrl_reg_wr_en,
    input  wire                                          ctrl_reg_wr_wait,
    input  wire                                          ctrl_reg_wr_ack,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                ctrl_reg_rd_addr,
    output wire                                          ctrl_reg_rd_en,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]               ctrl_reg_rd_data,
    input  wire                                          ctrl_reg_rd_wait,
    input  wire                                          ctrl_reg_rd_ack,

    /*
     * PTP clock
     */
    input  wire                                          ptp_clk,
    input  wire                                          ptp_rst,
    input  wire                                          ptp_sample_clk,
    output wire                                          ptp_td_sd,
    output wire                                          ptp_pps,
    output wire                                          ptp_pps_str,
    output wire                                          ptp_sync_locked,
    output wire [63:0]                                   ptp_sync_ts_rel,
    output wire                                          ptp_sync_ts_rel_step,
    output wire [96:0]                                   ptp_sync_ts_tod,
    output wire                                          ptp_sync_ts_tod_step,
    output wire                                          ptp_sync_pps,
    output wire                                          ptp_sync_pps_str,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_pulse,

    /*
     * Ethernet
     */
    input  wire [PORT_COUNT-1:0]                         eth_tx_clk,
    input  wire [PORT_COUNT-1:0]                         eth_tx_rst,

    input  wire [PORT_COUNT-1:0]                         eth_tx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                         eth_tx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_tx_ptp_ts_tod,
    output wire [PORT_COUNT-1:0]                         eth_tx_ptp_ts_tod_step,

    output wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     m_axis_eth_tx_tdata,
    output wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     m_axis_eth_tx_tkeep,
    output wire [PORT_COUNT-1:0]                         m_axis_eth_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                         m_axis_eth_tx_tready,
    output wire [PORT_COUNT-1:0]                         m_axis_eth_tx_tlast,
    output wire [PORT_COUNT*AXIS_ETH_TX_USER_WIDTH-1:0]  m_axis_eth_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            s_axis_eth_tx_cpl_ts,
    input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]            s_axis_eth_tx_cpl_tag,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_tx_cpl_valid,
    output wire [PORT_COUNT-1:0]                         s_axis_eth_tx_cpl_ready,

    output wire [PORT_COUNT-1:0]                         eth_tx_enable,
    input  wire [PORT_COUNT-1:0]                         eth_tx_status,
    output wire [PORT_COUNT-1:0]                         eth_tx_lfc_en,
    output wire [PORT_COUNT-1:0]                         eth_tx_lfc_req,
    output wire [PORT_COUNT*8-1:0]                       eth_tx_pfc_en,
    output wire [PORT_COUNT*8-1:0]                       eth_tx_pfc_req,
    input  wire [PORT_COUNT-1:0]                         eth_tx_fc_quanta_clk_en,

    input  wire [PORT_COUNT-1:0]                         eth_rx_clk,
    input  wire [PORT_COUNT-1:0]                         eth_rx_rst,

    input  wire [PORT_COUNT-1:0]                         eth_rx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                         eth_rx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_rx_ptp_ts_tod,
    output wire [PORT_COUNT-1:0]                         eth_rx_ptp_ts_tod_step,

    input  wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     s_axis_eth_rx_tdata,
    input  wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     s_axis_eth_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tvalid,
    output wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tready,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tlast,
    input  wire [PORT_COUNT*AXIS_ETH_RX_USER_WIDTH-1:0]  s_axis_eth_rx_tuser,

    output wire [PORT_COUNT-1:0]                         eth_rx_enable,
    input  wire [PORT_COUNT-1:0]                         eth_rx_status,
    output wire [PORT_COUNT-1:0]                         eth_rx_lfc_en,
    input  wire [PORT_COUNT-1:0]                         eth_rx_lfc_req,
    output wire [PORT_COUNT-1:0]                         eth_rx_lfc_ack,
    output wire [PORT_COUNT*8-1:0]                       eth_rx_pfc_en,
    input  wire [PORT_COUNT*8-1:0]                       eth_rx_pfc_req,
    output wire [PORT_COUNT*8-1:0]                       eth_rx_pfc_ack,
    input  wire [PORT_COUNT-1:0]                         eth_rx_fc_quanta_clk_en,

    /*
     * DDR
     */
    input  wire [DDR_CH-1:0]                             ddr_clk,
    input  wire [DDR_CH-1:0]                             ddr_rst,

    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]            m_axi_ddr_awid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]          m_axi_ddr_awaddr,
    output wire [DDR_CH*8-1:0]                           m_axi_ddr_awlen,
    output wire [DDR_CH*3-1:0]                           m_axi_ddr_awsize,
    output wire [DDR_CH*2-1:0]                           m_axi_ddr_awburst,
    output wire [DDR_CH-1:0]                             m_axi_ddr_awlock,
    output wire [DDR_CH*4-1:0]                           m_axi_ddr_awcache,
    output wire [DDR_CH*3-1:0]                           m_axi_ddr_awprot,
    output wire [DDR_CH*4-1:0]                           m_axi_ddr_awqos,
    output wire [DDR_CH*AXI_DDR_AWUSER_WIDTH-1:0]        m_axi_ddr_awuser,
    output wire [DDR_CH-1:0]                             m_axi_ddr_awvalid,
    input  wire [DDR_CH-1:0]                             m_axi_ddr_awready,
    output wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]          m_axi_ddr_wdata,
    output wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]          m_axi_ddr_wstrb,
    output wire [DDR_CH-1:0]                             m_axi_ddr_wlast,
    output wire [DDR_CH*AXI_DDR_WUSER_WIDTH-1:0]         m_axi_ddr_wuser,
    output wire [DDR_CH-1:0]                             m_axi_ddr_wvalid,
    input  wire [DDR_CH-1:0]                             m_axi_ddr_wready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]            m_axi_ddr_bid,
    input  wire [DDR_CH*2-1:0]                           m_axi_ddr_bresp,
    input  wire [DDR_CH*AXI_DDR_BUSER_WIDTH-1:0]         m_axi_ddr_buser,
    input  wire [DDR_CH-1:0]                             m_axi_ddr_bvalid,
    output wire [DDR_CH-1:0]                             m_axi_ddr_bready,
    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]            m_axi_ddr_arid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]          m_axi_ddr_araddr,
    output wire [DDR_CH*8-1:0]                           m_axi_ddr_arlen,
    output wire [DDR_CH*3-1:0]                           m_axi_ddr_arsize,
    output wire [DDR_CH*2-1:0]                           m_axi_ddr_arburst,
    output wire [DDR_CH-1:0]                             m_axi_ddr_arlock,
    output wire [DDR_CH*4-1:0]                           m_axi_ddr_arcache,
    output wire [DDR_CH*3-1:0]                           m_axi_ddr_arprot,
    output wire [DDR_CH*4-1:0]                           m_axi_ddr_arqos,
    output wire [DDR_CH*AXI_DDR_ARUSER_WIDTH-1:0]        m_axi_ddr_aruser,
    output wire [DDR_CH-1:0]                             m_axi_ddr_arvalid,
    input  wire [DDR_CH-1:0]                             m_axi_ddr_arready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]            m_axi_ddr_rid,
    input  wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]          m_axi_ddr_rdata,
    input  wire [DDR_CH*2-1:0]                           m_axi_ddr_rresp,
    input  wire [DDR_CH-1:0]                             m_axi_ddr_rlast,
    input  wire [DDR_CH*AXI_DDR_RUSER_WIDTH-1:0]         m_axi_ddr_ruser,
    input  wire [DDR_CH-1:0]                             m_axi_ddr_rvalid,
    output wire [DDR_CH-1:0]                             m_axi_ddr_rready,

    input  wire [DDR_CH-1:0]                             ddr_status,

    /*
     * HBM
     */
    input  wire [HBM_CH-1:0]                             hbm_clk,
    input  wire [HBM_CH-1:0]                             hbm_rst,

    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]            m_axi_hbm_awid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]          m_axi_hbm_awaddr,
    output wire [HBM_CH*8-1:0]                           m_axi_hbm_awlen,
    output wire [HBM_CH*3-1:0]                           m_axi_hbm_awsize,
    output wire [HBM_CH*2-1:0]                           m_axi_hbm_awburst,
    output wire [HBM_CH-1:0]                             m_axi_hbm_awlock,
    output wire [HBM_CH*4-1:0]                           m_axi_hbm_awcache,
    output wire [HBM_CH*3-1:0]                           m_axi_hbm_awprot,
    output wire [HBM_CH*4-1:0]                           m_axi_hbm_awqos,
    output wire [HBM_CH*AXI_HBM_AWUSER_WIDTH-1:0]        m_axi_hbm_awuser,
    output wire [HBM_CH-1:0]                             m_axi_hbm_awvalid,
    input  wire [HBM_CH-1:0]                             m_axi_hbm_awready,
    output wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]          m_axi_hbm_wdata,
    output wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]          m_axi_hbm_wstrb,
    output wire [HBM_CH-1:0]                             m_axi_hbm_wlast,
    output wire [HBM_CH*AXI_HBM_WUSER_WIDTH-1:0]         m_axi_hbm_wuser,
    output wire [HBM_CH-1:0]                             m_axi_hbm_wvalid,
    input  wire [HBM_CH-1:0]                             m_axi_hbm_wready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]            m_axi_hbm_bid,
    input  wire [HBM_CH*2-1:0]                           m_axi_hbm_bresp,
    input  wire [HBM_CH*AXI_HBM_BUSER_WIDTH-1:0]         m_axi_hbm_buser,
    input  wire [HBM_CH-1:0]                             m_axi_hbm_bvalid,
    output wire [HBM_CH-1:0]                             m_axi_hbm_bready,
    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]            m_axi_hbm_arid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]          m_axi_hbm_araddr,
    output wire [HBM_CH*8-1:0]                           m_axi_hbm_arlen,
    output wire [HBM_CH*3-1:0]                           m_axi_hbm_arsize,
    output wire [HBM_CH*2-1:0]                           m_axi_hbm_arburst,
    output wire [HBM_CH-1:0]                             m_axi_hbm_arlock,
    output wire [HBM_CH*4-1:0]                           m_axi_hbm_arcache,
    output wire [HBM_CH*3-1:0]                           m_axi_hbm_arprot,
    output wire [HBM_CH*4-1:0]                           m_axi_hbm_arqos,
    output wire [HBM_CH*AXI_HBM_ARUSER_WIDTH-1:0]        m_axi_hbm_aruser,
    output wire [HBM_CH-1:0]                             m_axi_hbm_arvalid,
    input  wire [HBM_CH-1:0]                             m_axi_hbm_arready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]            m_axi_hbm_rid,
    input  wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]          m_axi_hbm_rdata,
    input  wire [HBM_CH*2-1:0]                           m_axi_hbm_rresp,
    input  wire [HBM_CH-1:0]                             m_axi_hbm_rlast,
    input  wire [HBM_CH*AXI_HBM_RUSER_WIDTH-1:0]         m_axi_hbm_ruser,
    input  wire [HBM_CH-1:0]                             m_axi_hbm_rvalid,
    output wire [HBM_CH-1:0]                             m_axi_hbm_rready,

    input  wire [HBM_CH-1:0]                             hbm_status,

    /*
     * Statistics increment input
     */
    input  wire [STAT_INC_WIDTH-1:0]                     s_axis_stat_tdata,
    input  wire [STAT_ID_WIDTH-1:0]                      s_axis_stat_tid,
    input  wire                                          s_axis_stat_tvalid,
    output wire                                          s_axis_stat_tready,

    /*
     * GPIO
     */
    input  wire [APP_GPIO_IN_WIDTH-1:0]                  app_gpio_in,
    output wire [APP_GPIO_OUT_WIDTH-1:0]                 app_gpio_out,

    /*
     * Custom application block ports
     */
    `ifdef APP_CUSTOM_PORTS_ENABLE
        `APP_CUSTOM_PORTS_DECL
    `endif

    /*
     * JTAG
     */
    input  wire                                          app_jtag_tdi,
    output wire                                          app_jtag_tdo,
    input  wire                                          app_jtag_tms,
    input  wire                                          app_jtag_tck
);

parameter TLP_DATA_WIDTH = SEG_COUNT*SEG_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32;
parameter TLP_HDR_WIDTH = 128;
parameter TLP_SEG_COUNT = 1;
parameter TX_SEQ_NUM_COUNT = SEG_COUNT;

wire [TLP_DATA_WIDTH-1:0]                     pcie_rx_req_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_rx_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]                    pcie_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]                    pcie_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_eop;
wire                                          pcie_rx_req_tlp_ready;

wire [TLP_DATA_WIDTH-1:0]                     pcie_rx_cpl_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_rx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_rx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT*4-1:0]                    pcie_rx_cpl_tlp_error;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_eop;
wire                                          pcie_rx_cpl_tlp_ready;

wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_tx_rd_req_tlp_hdr;
wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_rd_req_tlp_seq;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_eop;
wire                                          pcie_tx_rd_req_tlp_ready;

wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  pcie_rd_req_tx_seq_num;
wire [TX_SEQ_NUM_COUNT-1:0]                   pcie_rd_req_tx_seq_num_valid;

wire [TLP_DATA_WIDTH-1:0]                     pcie_tx_wr_req_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_tx_wr_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_tx_wr_req_tlp_hdr;
wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_wr_req_tlp_seq;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_eop;
wire                                          pcie_tx_wr_req_tlp_ready;

wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  pcie_wr_req_tx_seq_num;
wire [TX_SEQ_NUM_COUNT-1:0]                   pcie_wr_req_tx_seq_num_valid;

wire [TLP_DATA_WIDTH-1:0]                     pcie_tx_cpl_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_eop;
wire                                          pcie_tx_cpl_tlp_ready;

wire [31:0]                                   pcie_tx_msix_wr_req_tlp_data;
wire                                          pcie_tx_msix_wr_req_tlp_strb;
wire [TLP_HDR_WIDTH-1:0]                      pcie_tx_msix_wr_req_tlp_hdr;
wire                                          pcie_tx_msix_wr_req_tlp_valid;
wire                                          pcie_tx_msix_wr_req_tlp_sop;
wire                                          pcie_tx_msix_wr_req_tlp_eop;
wire                                          pcie_tx_msix_wr_req_tlp_ready;

wire [F_COUNT-1:0] ext_tag_enable;
wire [F_COUNT-1:0] rcb_128b;
wire [7:0] bus_num;
wire [F_COUNT*3-1:0] max_read_request_size;
wire [F_COUNT*3-1:0] max_payload_size;
wire [F_COUNT-1:0] msix_enable;
wire [F_COUNT-1:0] msix_mask;

pcie_ptile_if #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .PF_COUNT(1),
    .VF_COUNT(0),
    .F_COUNT(PF_COUNT+VF_COUNT),
    .IO_BAR_INDEX(5)
)
pcie_ptile_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * P-Tile RX AVST interface
     */
    .rx_st_data(rx_st_data),
    .rx_st_empty(rx_st_empty),
    .rx_st_sop(rx_st_sop),
    .rx_st_eop(rx_st_eop),
    .rx_st_valid(rx_st_valid),
    .rx_st_ready(rx_st_ready),
    .rx_st_hdr(rx_st_hdr),
    .rx_st_tlp_prfx(rx_st_tlp_prfx),
    .rx_st_vf_active(rx_st_vf_active),
    .rx_st_func_num(rx_st_func_num),
    .rx_st_vf_num(rx_st_vf_num),
    .rx_st_bar_range(rx_st_bar_range),
    .rx_st_tlp_abort(rx_st_tlp_abort),

    /*
     * P-Tile TX AVST interface
     */
    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),
    .tx_st_hdr(tx_st_hdr),
    .tx_st_tlp_prfx(tx_st_tlp_prfx),

    /*
     * P-Tile RX flow control
     */
    .rx_buffer_limit(rx_buffer_limit),
    .rx_buffer_limit_tdm_idx(rx_buffer_limit_tdm_idx),

    /*
     * P-Tile TX flow control
     */
    .tx_cdts_limit(tx_cdts_limit),
    .tx_cdts_limit_tdm_idx(tx_cdts_limit_tdm_idx),

    /*
     * P-Tile configuration interface
     */
    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * TLP output (request to BAR)
     */
    .rx_req_tlp_data(pcie_rx_req_tlp_data),
    .rx_req_tlp_strb(pcie_rx_req_tlp_strb),
    .rx_req_tlp_hdr(pcie_rx_req_tlp_hdr),
    .rx_req_tlp_bar_id(pcie_rx_req_tlp_bar_id),
    .rx_req_tlp_func_num(pcie_rx_req_tlp_func_num),
    .rx_req_tlp_valid(pcie_rx_req_tlp_valid),
    .rx_req_tlp_sop(pcie_rx_req_tlp_sop),
    .rx_req_tlp_eop(pcie_rx_req_tlp_eop),
    .rx_req_tlp_ready(pcie_rx_req_tlp_ready),

    /*
     * TLP output (completion to DMA)
     */
    .rx_cpl_tlp_data(pcie_rx_cpl_tlp_data),
    .rx_cpl_tlp_strb(pcie_rx_cpl_tlp_strb),
    .rx_cpl_tlp_hdr(pcie_rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(pcie_rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(pcie_rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(pcie_rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(pcie_rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(pcie_rx_cpl_tlp_ready),

    /*
     * TLP input (read request from DMA)
     */
    .tx_rd_req_tlp_hdr(pcie_tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(pcie_tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(pcie_tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(pcie_tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(pcie_tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(pcie_tx_rd_req_tlp_ready),

    /*
     * Transmit sequence number output (DMA read request)
     */
    .m_axis_rd_req_tx_seq_num(pcie_rd_req_tx_seq_num),
    .m_axis_rd_req_tx_seq_num_valid(pcie_rd_req_tx_seq_num_valid),

    /*
     * TLP input (write request from DMA)
     */
    .tx_wr_req_tlp_data(pcie_tx_wr_req_tlp_data),
    .tx_wr_req_tlp_strb(pcie_tx_wr_req_tlp_strb),
    .tx_wr_req_tlp_hdr(pcie_tx_wr_req_tlp_hdr),
    .tx_wr_req_tlp_seq(pcie_tx_wr_req_tlp_seq),
    .tx_wr_req_tlp_valid(pcie_tx_wr_req_tlp_valid),
    .tx_wr_req_tlp_sop(pcie_tx_wr_req_tlp_sop),
    .tx_wr_req_tlp_eop(pcie_tx_wr_req_tlp_eop),
    .tx_wr_req_tlp_ready(pcie_tx_wr_req_tlp_ready),

    /*
     * Transmit sequence number output (DMA write request)
     */
    .m_axis_wr_req_tx_seq_num(pcie_wr_req_tx_seq_num),
    .m_axis_wr_req_tx_seq_num_valid(pcie_wr_req_tx_seq_num_valid),

    /*
     * TLP input (completion from BAR)
     */
    .tx_cpl_tlp_data(pcie_tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(pcie_tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(pcie_tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(pcie_tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(pcie_tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(pcie_tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(pcie_tx_cpl_tlp_ready),

    /*
     * TLP input (write request from MSI)
     */
    .tx_msi_wr_req_tlp_data(pcie_tx_msix_wr_req_tlp_data),
    .tx_msi_wr_req_tlp_strb(pcie_tx_msix_wr_req_tlp_strb),
    .tx_msi_wr_req_tlp_hdr(pcie_tx_msix_wr_req_tlp_hdr),
    .tx_msi_wr_req_tlp_valid(pcie_tx_msix_wr_req_tlp_valid),
    .tx_msi_wr_req_tlp_sop(pcie_tx_msix_wr_req_tlp_sop),
    .tx_msi_wr_req_tlp_eop(pcie_tx_msix_wr_req_tlp_eop),
    .tx_msi_wr_req_tlp_ready(pcie_tx_msix_wr_req_tlp_ready),

    /*
     * Flow control
     */
    .tx_fc_ph_av(),
    .tx_fc_pd_av(),
    .tx_fc_nph_av(),
    .tx_fc_npd_av(),
    .tx_fc_cplh_av(),
    .tx_fc_cpld_av(),

    /*
     * Configuration outputs
     */
    .ext_tag_enable(ext_tag_enable),
    .rcb_128b(rcb_128b),
    .bus_num(bus_num),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask)
);

mqnic_core_pcie #(
    // FW and board IDs
    .FPGA_ID(FPGA_ID),
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .BUILD_DATE(BUILD_DATE),
    .GIT_HASH(GIT_HASH),
    .RELEASE_INFO(RELEASE_INFO),

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
    .PTP_CLOCK_PIPELINE(PTP_CLOCK_PIPELINE),
    .PTP_CLOCK_CDC_PIPELINE(PTP_CLOCK_CDC_PIPELINE),
    .PTP_SEPARATE_TX_CLOCK(PTP_SEPARATE_TX_CLOCK),
    .PTP_SEPARATE_RX_CLOCK(PTP_SEPARATE_RX_CLOCK),
    .PTP_PORT_CDC_PIPELINE(PTP_PORT_CDC_PIPELINE),
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

    // Application block configuration
    .APP_ID(APP_ID),
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),

    // Custom application block parameters
    `ifdef APP_CUSTOM_PARAMS_ENABLE
        `APP_CUSTOM_PARAMS_MAP
    `endif

    // DMA interface configuration
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // PCIe interface configuration
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(1),
    .PF_COUNT(PF_COUNT),
    .VF_COUNT(VF_COUNT),
    .F_COUNT(F_COUNT),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .PCIE_DMA_READ_OP_TABLE_SIZE(PCIE_DMA_READ_OP_TABLE_SIZE),
    .PCIE_DMA_READ_TX_LIMIT(PCIE_DMA_READ_TX_LIMIT),
    .PCIE_DMA_READ_CPLH_FC_LIMIT(PCIE_DMA_READ_CPLH_FC_LIMIT),
    .PCIE_DMA_READ_CPLD_FC_LIMIT(PCIE_DMA_READ_CPLD_FC_LIMIT),
    .PCIE_DMA_WRITE_OP_TABLE_SIZE(PCIE_DMA_WRITE_OP_TABLE_SIZE),
    .PCIE_DMA_WRITE_TX_LIMIT(PCIE_DMA_WRITE_TX_LIMIT),
    .TLP_FORCE_64_BIT_ADDR(0),
    .CHECK_BUS_NUMBER(1),

    // Interrupt configuration
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .AXIL_IF_CTRL_ADDR_WIDTH(AXIL_IF_CTRL_ADDR_WIDTH),
    .AXIL_CSR_ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .AXIL_CSR_PASSTHROUGH_ENABLE(AXIL_CSR_PASSTHROUGH_ENABLE),
    .RB_NEXT_PTR(RB_NEXT_PTR),

    // AXI lite interface configuration (application control)
    .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),

    // Ethernet interface configuration
    .AXIS_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .AXIS_SYNC_DATA_WIDTH(AXIS_ETH_SYNC_DATA_WIDTH),
    .AXIS_IF_DATA_WIDTH(AXIS_ETH_IF_DATA_WIDTH),
    .AXIS_TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .AXIS_RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH),
    .AXIS_RX_USE_READY(AXIS_ETH_RX_USE_READY),
    .AXIS_TX_PIPELINE(AXIS_ETH_TX_PIPELINE),
    .AXIS_TX_FIFO_PIPELINE(AXIS_ETH_TX_FIFO_PIPELINE),
    .AXIS_TX_TS_PIPELINE(AXIS_ETH_TX_TS_PIPELINE),
    .AXIS_RX_PIPELINE(AXIS_ETH_RX_PIPELINE),
    .AXIS_RX_FIFO_PIPELINE(AXIS_ETH_RX_FIFO_PIPELINE),

    // Statistics counter subsystem
    .STAT_ENABLE(STAT_ENABLE),
    .STAT_DMA_ENABLE(STAT_DMA_ENABLE),
    .STAT_PCIE_ENABLE(STAT_PCIE_ENABLE),
    .STAT_INC_WIDTH(STAT_INC_WIDTH),
    .STAT_ID_WIDTH(STAT_ID_WIDTH)
)
core_pcie_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request to BAR)
     */
    .pcie_rx_req_tlp_data(pcie_rx_req_tlp_data),
    .pcie_rx_req_tlp_strb(pcie_rx_req_tlp_strb),
    .pcie_rx_req_tlp_hdr(pcie_rx_req_tlp_hdr),
    .pcie_rx_req_tlp_bar_id(pcie_rx_req_tlp_bar_id),
    .pcie_rx_req_tlp_func_num(pcie_rx_req_tlp_func_num),
    .pcie_rx_req_tlp_valid(pcie_rx_req_tlp_valid),
    .pcie_rx_req_tlp_sop(pcie_rx_req_tlp_sop),
    .pcie_rx_req_tlp_eop(pcie_rx_req_tlp_eop),
    .pcie_rx_req_tlp_ready(pcie_rx_req_tlp_ready),

    /*
     * TLP input (completion to DMA)
     */
    .pcie_rx_cpl_tlp_data(pcie_rx_cpl_tlp_data),
    .pcie_rx_cpl_tlp_strb(pcie_rx_cpl_tlp_strb),
    .pcie_rx_cpl_tlp_hdr(pcie_rx_cpl_tlp_hdr),
    .pcie_rx_cpl_tlp_error(pcie_rx_cpl_tlp_error),
    .pcie_rx_cpl_tlp_valid(pcie_rx_cpl_tlp_valid),
    .pcie_rx_cpl_tlp_sop(pcie_rx_cpl_tlp_sop),
    .pcie_rx_cpl_tlp_eop(pcie_rx_cpl_tlp_eop),
    .pcie_rx_cpl_tlp_ready(pcie_rx_cpl_tlp_ready),

    /*
     * TLP output (read request from DMA)
     */
    .pcie_tx_rd_req_tlp_hdr(pcie_tx_rd_req_tlp_hdr),
    .pcie_tx_rd_req_tlp_seq(pcie_tx_rd_req_tlp_seq),
    .pcie_tx_rd_req_tlp_valid(pcie_tx_rd_req_tlp_valid),
    .pcie_tx_rd_req_tlp_sop(pcie_tx_rd_req_tlp_sop),
    .pcie_tx_rd_req_tlp_eop(pcie_tx_rd_req_tlp_eop),
    .pcie_tx_rd_req_tlp_ready(pcie_tx_rd_req_tlp_ready),

    /*
     * Transmit sequence number input (DMA read request)
     */
    .s_axis_pcie_rd_req_tx_seq_num(pcie_rd_req_tx_seq_num),
    .s_axis_pcie_rd_req_tx_seq_num_valid(pcie_rd_req_tx_seq_num_valid),

    /*
     * TLP output (write request from DMA)
     */
    .pcie_tx_wr_req_tlp_data(pcie_tx_wr_req_tlp_data),
    .pcie_tx_wr_req_tlp_strb(pcie_tx_wr_req_tlp_strb),
    .pcie_tx_wr_req_tlp_hdr(pcie_tx_wr_req_tlp_hdr),
    .pcie_tx_wr_req_tlp_seq(pcie_tx_wr_req_tlp_seq),
    .pcie_tx_wr_req_tlp_valid(pcie_tx_wr_req_tlp_valid),
    .pcie_tx_wr_req_tlp_sop(pcie_tx_wr_req_tlp_sop),
    .pcie_tx_wr_req_tlp_eop(pcie_tx_wr_req_tlp_eop),
    .pcie_tx_wr_req_tlp_ready(pcie_tx_wr_req_tlp_ready),

    /*
     * Transmit sequence number input (DMA write request)
     */
    .s_axis_pcie_wr_req_tx_seq_num(pcie_wr_req_tx_seq_num),
    .s_axis_pcie_wr_req_tx_seq_num_valid(pcie_wr_req_tx_seq_num_valid),

    /*
     * TLP output (completion from BAR)
     */
    .pcie_tx_cpl_tlp_data(pcie_tx_cpl_tlp_data),
    .pcie_tx_cpl_tlp_strb(pcie_tx_cpl_tlp_strb),
    .pcie_tx_cpl_tlp_hdr(pcie_tx_cpl_tlp_hdr),
    .pcie_tx_cpl_tlp_valid(pcie_tx_cpl_tlp_valid),
    .pcie_tx_cpl_tlp_sop(pcie_tx_cpl_tlp_sop),
    .pcie_tx_cpl_tlp_eop(pcie_tx_cpl_tlp_eop),
    .pcie_tx_cpl_tlp_ready(pcie_tx_cpl_tlp_ready),

    /*
     * TLP output (MSI-X write request)
     */
    .pcie_tx_msix_wr_req_tlp_data(pcie_tx_msix_wr_req_tlp_data),
    .pcie_tx_msix_wr_req_tlp_strb(pcie_tx_msix_wr_req_tlp_strb),
    .pcie_tx_msix_wr_req_tlp_hdr(pcie_tx_msix_wr_req_tlp_hdr),
    .pcie_tx_msix_wr_req_tlp_valid(pcie_tx_msix_wr_req_tlp_valid),
    .pcie_tx_msix_wr_req_tlp_sop(pcie_tx_msix_wr_req_tlp_sop),
    .pcie_tx_msix_wr_req_tlp_eop(pcie_tx_msix_wr_req_tlp_eop),
    .pcie_tx_msix_wr_req_tlp_ready(pcie_tx_msix_wr_req_tlp_ready),

    /*
     * Configuration inputs
     */
    .bus_num(bus_num),
    .ext_tag_enable(ext_tag_enable),
    .rcb_128b(rcb_128b),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask),

    /*
     * PCIe error outputs
     */
    .pcie_error_cor(),
    .pcie_error_uncor(),

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    .m_axil_csr_awaddr(m_axil_csr_awaddr),
    .m_axil_csr_awprot(m_axil_csr_awprot),
    .m_axil_csr_awvalid(m_axil_csr_awvalid),
    .m_axil_csr_awready(m_axil_csr_awready),
    .m_axil_csr_wdata(m_axil_csr_wdata),
    .m_axil_csr_wstrb(m_axil_csr_wstrb),
    .m_axil_csr_wvalid(m_axil_csr_wvalid),
    .m_axil_csr_wready(m_axil_csr_wready),
    .m_axil_csr_bresp(m_axil_csr_bresp),
    .m_axil_csr_bvalid(m_axil_csr_bvalid),
    .m_axil_csr_bready(m_axil_csr_bready),
    .m_axil_csr_araddr(m_axil_csr_araddr),
    .m_axil_csr_arprot(m_axil_csr_arprot),
    .m_axil_csr_arvalid(m_axil_csr_arvalid),
    .m_axil_csr_arready(m_axil_csr_arready),
    .m_axil_csr_rdata(m_axil_csr_rdata),
    .m_axil_csr_rresp(m_axil_csr_rresp),
    .m_axil_csr_rvalid(m_axil_csr_rvalid),
    .m_axil_csr_rready(m_axil_csr_rready),

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
     * Ethernet
     */
    .tx_clk(eth_tx_clk),
    .tx_rst(eth_tx_rst),

    .tx_ptp_clk(eth_tx_ptp_clk),
    .tx_ptp_rst(eth_tx_ptp_rst),
    .tx_ptp_ts_tod(eth_tx_ptp_ts_tod),
    .tx_ptp_ts_tod_step(eth_tx_ptp_ts_tod_step),

    .m_axis_tx_tdata(m_axis_eth_tx_tdata),
    .m_axis_tx_tkeep(m_axis_eth_tx_tkeep),
    .m_axis_tx_tvalid(m_axis_eth_tx_tvalid),
    .m_axis_tx_tready(m_axis_eth_tx_tready),
    .m_axis_tx_tlast(m_axis_eth_tx_tlast),
    .m_axis_tx_tuser(m_axis_eth_tx_tuser),

    .s_axis_tx_cpl_ts(s_axis_eth_tx_cpl_ts),
    .s_axis_tx_cpl_tag(s_axis_eth_tx_cpl_tag),
    .s_axis_tx_cpl_valid(s_axis_eth_tx_cpl_valid),
    .s_axis_tx_cpl_ready(s_axis_eth_tx_cpl_ready),

    .tx_enable(eth_tx_enable),
    .tx_status(eth_tx_status),
    .tx_lfc_en(eth_tx_lfc_en),
    .tx_lfc_req(eth_tx_lfc_req),
    .tx_pfc_en(eth_tx_pfc_en),
    .tx_pfc_req(eth_tx_pfc_req),
    .tx_fc_quanta_clk_en(eth_tx_fc_quanta_clk_en),

    .rx_clk(eth_rx_clk),
    .rx_rst(eth_rx_rst),

    .rx_ptp_clk(eth_rx_ptp_clk),
    .rx_ptp_rst(eth_rx_ptp_rst),
    .rx_ptp_ts_tod(eth_rx_ptp_ts_tod),
    .rx_ptp_ts_tod_step(eth_rx_ptp_ts_tod_step),

    .s_axis_rx_tdata(s_axis_eth_rx_tdata),
    .s_axis_rx_tkeep(s_axis_eth_rx_tkeep),
    .s_axis_rx_tvalid(s_axis_eth_rx_tvalid),
    .s_axis_rx_tready(s_axis_eth_rx_tready),
    .s_axis_rx_tlast(s_axis_eth_rx_tlast),
    .s_axis_rx_tuser(s_axis_eth_rx_tuser),

    .rx_enable(eth_rx_enable),
    .rx_status(eth_rx_status),
    .rx_lfc_en(eth_rx_lfc_en),
    .rx_lfc_req(eth_rx_lfc_req),
    .rx_lfc_ack(eth_rx_lfc_ack),
    .rx_pfc_en(eth_rx_pfc_en),
    .rx_pfc_req(eth_rx_pfc_req),
    .rx_pfc_ack(eth_rx_pfc_ack),
    .rx_fc_quanta_clk_en(eth_rx_fc_quanta_clk_en),

    /*
     * DDR
     */
    .ddr_clk(ddr_clk),
    .ddr_rst(ddr_rst),

    .m_axi_ddr_awid(m_axi_ddr_awid),
    .m_axi_ddr_awaddr(m_axi_ddr_awaddr),
    .m_axi_ddr_awlen(m_axi_ddr_awlen),
    .m_axi_ddr_awsize(m_axi_ddr_awsize),
    .m_axi_ddr_awburst(m_axi_ddr_awburst),
    .m_axi_ddr_awlock(m_axi_ddr_awlock),
    .m_axi_ddr_awcache(m_axi_ddr_awcache),
    .m_axi_ddr_awprot(m_axi_ddr_awprot),
    .m_axi_ddr_awqos(m_axi_ddr_awqos),
    .m_axi_ddr_awuser(m_axi_ddr_awuser),
    .m_axi_ddr_awvalid(m_axi_ddr_awvalid),
    .m_axi_ddr_awready(m_axi_ddr_awready),
    .m_axi_ddr_wdata(m_axi_ddr_wdata),
    .m_axi_ddr_wstrb(m_axi_ddr_wstrb),
    .m_axi_ddr_wlast(m_axi_ddr_wlast),
    .m_axi_ddr_wuser(m_axi_ddr_wuser),
    .m_axi_ddr_wvalid(m_axi_ddr_wvalid),
    .m_axi_ddr_wready(m_axi_ddr_wready),
    .m_axi_ddr_bid(m_axi_ddr_bid),
    .m_axi_ddr_bresp(m_axi_ddr_bresp),
    .m_axi_ddr_buser(m_axi_ddr_buser),
    .m_axi_ddr_bvalid(m_axi_ddr_bvalid),
    .m_axi_ddr_bready(m_axi_ddr_bready),
    .m_axi_ddr_arid(m_axi_ddr_arid),
    .m_axi_ddr_araddr(m_axi_ddr_araddr),
    .m_axi_ddr_arlen(m_axi_ddr_arlen),
    .m_axi_ddr_arsize(m_axi_ddr_arsize),
    .m_axi_ddr_arburst(m_axi_ddr_arburst),
    .m_axi_ddr_arlock(m_axi_ddr_arlock),
    .m_axi_ddr_arcache(m_axi_ddr_arcache),
    .m_axi_ddr_arprot(m_axi_ddr_arprot),
    .m_axi_ddr_arqos(m_axi_ddr_arqos),
    .m_axi_ddr_aruser(m_axi_ddr_aruser),
    .m_axi_ddr_arvalid(m_axi_ddr_arvalid),
    .m_axi_ddr_arready(m_axi_ddr_arready),
    .m_axi_ddr_rid(m_axi_ddr_rid),
    .m_axi_ddr_rdata(m_axi_ddr_rdata),
    .m_axi_ddr_rresp(m_axi_ddr_rresp),
    .m_axi_ddr_rlast(m_axi_ddr_rlast),
    .m_axi_ddr_ruser(m_axi_ddr_ruser),
    .m_axi_ddr_rvalid(m_axi_ddr_rvalid),
    .m_axi_ddr_rready(m_axi_ddr_rready),

    .ddr_status(ddr_status),

    /*
     * HBM
     */
    .hbm_clk(hbm_clk),
    .hbm_rst(hbm_rst),

    .m_axi_hbm_awid(m_axi_hbm_awid),
    .m_axi_hbm_awaddr(m_axi_hbm_awaddr),
    .m_axi_hbm_awlen(m_axi_hbm_awlen),
    .m_axi_hbm_awsize(m_axi_hbm_awsize),
    .m_axi_hbm_awburst(m_axi_hbm_awburst),
    .m_axi_hbm_awlock(m_axi_hbm_awlock),
    .m_axi_hbm_awcache(m_axi_hbm_awcache),
    .m_axi_hbm_awprot(m_axi_hbm_awprot),
    .m_axi_hbm_awqos(m_axi_hbm_awqos),
    .m_axi_hbm_awuser(m_axi_hbm_awuser),
    .m_axi_hbm_awvalid(m_axi_hbm_awvalid),
    .m_axi_hbm_awready(m_axi_hbm_awready),
    .m_axi_hbm_wdata(m_axi_hbm_wdata),
    .m_axi_hbm_wstrb(m_axi_hbm_wstrb),
    .m_axi_hbm_wlast(m_axi_hbm_wlast),
    .m_axi_hbm_wuser(m_axi_hbm_wuser),
    .m_axi_hbm_wvalid(m_axi_hbm_wvalid),
    .m_axi_hbm_wready(m_axi_hbm_wready),
    .m_axi_hbm_bid(m_axi_hbm_bid),
    .m_axi_hbm_bresp(m_axi_hbm_bresp),
    .m_axi_hbm_buser(m_axi_hbm_buser),
    .m_axi_hbm_bvalid(m_axi_hbm_bvalid),
    .m_axi_hbm_bready(m_axi_hbm_bready),
    .m_axi_hbm_arid(m_axi_hbm_arid),
    .m_axi_hbm_araddr(m_axi_hbm_araddr),
    .m_axi_hbm_arlen(m_axi_hbm_arlen),
    .m_axi_hbm_arsize(m_axi_hbm_arsize),
    .m_axi_hbm_arburst(m_axi_hbm_arburst),
    .m_axi_hbm_arlock(m_axi_hbm_arlock),
    .m_axi_hbm_arcache(m_axi_hbm_arcache),
    .m_axi_hbm_arprot(m_axi_hbm_arprot),
    .m_axi_hbm_arqos(m_axi_hbm_arqos),
    .m_axi_hbm_aruser(m_axi_hbm_aruser),
    .m_axi_hbm_arvalid(m_axi_hbm_arvalid),
    .m_axi_hbm_arready(m_axi_hbm_arready),
    .m_axi_hbm_rid(m_axi_hbm_rid),
    .m_axi_hbm_rdata(m_axi_hbm_rdata),
    .m_axi_hbm_rresp(m_axi_hbm_rresp),
    .m_axi_hbm_rlast(m_axi_hbm_rlast),
    .m_axi_hbm_ruser(m_axi_hbm_ruser),
    .m_axi_hbm_rvalid(m_axi_hbm_rvalid),
    .m_axi_hbm_rready(m_axi_hbm_rready),

    .hbm_status(hbm_status),

    /*
     * Statistics input
     */
    .s_axis_stat_tdata(s_axis_stat_tdata),
    .s_axis_stat_tid(s_axis_stat_tid),
    .s_axis_stat_tvalid(s_axis_stat_tvalid),
    .s_axis_stat_tready(s_axis_stat_tready),

    /*
     * GPIO
     */
    .app_gpio_in(app_gpio_in),
    .app_gpio_out(app_gpio_out),

    /*
     * Custom application block ports
     */
    `ifdef APP_CUSTOM_PORTS_ENABLE
        `APP_CUSTOM_PORTS_MAP
    `endif

    /*
     * JTAG
     */
    .app_jtag_tdi(app_jtag_tdi),
    .app_jtag_tdo(app_jtag_tdo),
    .app_jtag_tms(app_jtag_tms),
    .app_jtag_tck(app_jtag_tck)
);

endmodule

`resetall
