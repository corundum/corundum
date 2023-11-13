/*

Copyright (c) 2023 Alex Forencich

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
 * Testbench top-level module
 */
module test_fpga_core #
(
    // FW and board IDs
    parameter FPGA_ID = 32'h4B37093,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h10ee_90c8,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

    // Board configuration
    parameter QSFP_CNT = 2,
    parameter CH_CNT = QSFP_CNT*4,
    parameter CMS_ENABLE = 1,
    parameter TDMA_BER_ENABLE = 0,
    parameter FLASH_SEG_COUNT = 2,
    parameter FLASH_SEG_DEFAULT = 1,
    parameter FLASH_SEG_FALLBACK = 0,
    parameter FLASH_SEG0_SIZE = 32'h01002000,

    // Structural configuration
    parameter IF_COUNT = 2,
    parameter PORTS_PER_IF = 1,
    parameter SCHED_PER_IF = PORTS_PER_IF,
    parameter PORT_MASK = 0,

    // Clock configuration
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,

    // PTP configuration
    parameter PTP_CLK_PERIOD_NS_NUM = 1024,
    parameter PTP_CLK_PERIOD_NS_DENOM = 165,
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,
    parameter IF_PTP_PERIOD_NS = 6'h6,
    parameter IF_PTP_PERIOD_FNS = 16'h6666,

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
    parameter TX_CPL_FIFO_DEPTH = 32,
    parameter TX_TAG_WIDTH = 16,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter PFC_ENABLE = 1,
    parameter LFC_ENABLE = PFC_ENABLE,
    parameter ENABLE_PADDING = 1,
    parameter ENABLE_DIC = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 32768,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 32768,
    parameter RX_RAM_SIZE = 32768,

    // RAM configuration
    parameter DDR_CH = 4,
    parameter DDR_ENABLE = 0,
    parameter AXI_DDR_DATA_WIDTH = 512,
    parameter AXI_DDR_ADDR_WIDTH = 34,
    parameter AXI_DDR_STRB_WIDTH = (AXI_DDR_DATA_WIDTH/8),
    parameter AXI_DDR_ID_WIDTH = 8,
    parameter AXI_DDR_MAX_BURST_LEN = 256,
    parameter AXI_DDR_NARROW_BURST = 0,
    parameter HBM_CH = 32,
    parameter HBM_ENABLE = 0,
    parameter HBM_GROUP_SIZE = HBM_CH,
    parameter AXI_HBM_DATA_WIDTH = 256,
    parameter AXI_HBM_ADDR_WIDTH = 33,
    parameter AXI_HBM_STRB_WIDTH = (AXI_HBM_DATA_WIDTH/8),
    parameter AXI_HBM_ID_WIDTH = 6,
    parameter AXI_HBM_MAX_BURST_LEN = 16,

    // Application block configuration
    parameter APP_ID = 32'h00000000,
    parameter APP_ENABLE = 0,
    parameter APP_CTRL_ENABLE = 1,
    parameter APP_DMA_ENABLE = 1,
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,
    parameter APP_AXIS_IF_ENABLE = 1,
    parameter APP_STAT_ENABLE = 1,

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter AXIS_PCIE_DATA_WIDTH = 512,
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161,
    parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 62 : 137,
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81,
    parameter RC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 256,
    parameter RQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    parameter CQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    parameter CC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 256,

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = EQN_WIDTH,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
    parameter XGMII_DATA_WIDTH = 64,
    parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8,
    parameter AXIS_ETH_DATA_WIDTH = XGMII_DATA_WIDTH,
    parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8,
    parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH*2,
    parameter AXIS_ETH_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_ETH_TX_PIPELINE = 4,
    parameter AXIS_ETH_TX_FIFO_PIPELINE = 4,
    parameter AXIS_ETH_TX_TS_PIPELINE = 4,
    parameter AXIS_ETH_RX_PIPELINE = 4,
    parameter AXIS_ETH_RX_FIFO_PIPELINE = 4,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_DMA_ENABLE = 1,
    parameter STAT_PCIE_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    input  wire                               clk_250mhz,
    input  wire                               rst_250mhz,

    /*
     * PTP clock
     */
    input  wire                               ptp_clk,
    input  wire                               ptp_rst,
    input  wire                               ptp_sample_clk,

    /*
     * GPIO
     */
    input  wire [3:0]                         sw,
    output wire [2:0]                         led,
    output wire [QSFP_CNT-1:0]                qsfp_led_act,
    output wire [QSFP_CNT-1:0]                qsfp_led_stat_g,
    output wire [QSFP_CNT-1:0]                qsfp_led_stat_y,

    /*
     * I2C
     */
    input  wire                               i2c_scl_i,
    output wire                               i2c_scl_o,
    output wire                               i2c_scl_t,
    input  wire                               i2c_sda_i,
    output wire                               i2c_sda_o,
    output wire                               i2c_sda_t,

    /*
     * PCIe
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep,
    output wire                               m_axis_rq_tlast,
    input  wire                               m_axis_rq_tready,
    output wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser,
    output wire                               m_axis_rq_tvalid,

    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]    s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]    s_axis_rc_tkeep,
    input  wire                               s_axis_rc_tlast,
    output wire                               s_axis_rc_tready,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0] s_axis_rc_tuser,
    input  wire                               s_axis_rc_tvalid,

    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]    s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]    s_axis_cq_tkeep,
    input  wire                               s_axis_cq_tlast,
    output wire                               s_axis_cq_tready,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0] s_axis_cq_tuser,
    input  wire                               s_axis_cq_tvalid,

    output wire [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep,
    output wire                               m_axis_cc_tlast,
    input  wire                               m_axis_cc_tready,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser,
    output wire                               m_axis_cc_tvalid,

    input  wire [RQ_SEQ_NUM_WIDTH-1:0]        s_axis_rq_seq_num_0,
    input  wire                               s_axis_rq_seq_num_valid_0,
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]        s_axis_rq_seq_num_1,
    input  wire                               s_axis_rq_seq_num_valid_1,

    input  wire [1:0]                         pcie_tfc_nph_av,
    input  wire [1:0]                         pcie_tfc_npd_av,

    input  wire [2:0]                         cfg_max_payload,
    input  wire [2:0]                         cfg_max_read_req,
    input  wire [3:0]                         cfg_rcb_status,

    output wire [9:0]                         cfg_mgmt_addr,
    output wire [7:0]                         cfg_mgmt_function_number,
    output wire                               cfg_mgmt_write,
    output wire [31:0]                        cfg_mgmt_write_data,
    output wire [3:0]                         cfg_mgmt_byte_enable,
    output wire                               cfg_mgmt_read,
    input  wire [31:0]                        cfg_mgmt_read_data,
    input  wire                               cfg_mgmt_read_write_done,

    input  wire [7:0]                         cfg_fc_ph,
    input  wire [11:0]                        cfg_fc_pd,
    input  wire [7:0]                         cfg_fc_nph,
    input  wire [11:0]                        cfg_fc_npd,
    input  wire [7:0]                         cfg_fc_cplh,
    input  wire [11:0]                        cfg_fc_cpld,
    output wire [2:0]                         cfg_fc_sel,

    input  wire [3:0]                         cfg_interrupt_msix_enable,
    input  wire [3:0]                         cfg_interrupt_msix_mask,
    input  wire [251:0]                       cfg_interrupt_msix_vf_enable,
    input  wire [251:0]                       cfg_interrupt_msix_vf_mask,
    output wire [63:0]                        cfg_interrupt_msix_address,
    output wire [31:0]                        cfg_interrupt_msix_data,
    output wire                               cfg_interrupt_msix_int,
    output wire [1:0]                         cfg_interrupt_msix_vec_pending,
    input  wire                               cfg_interrupt_msix_vec_pending_status,
    input  wire                               cfg_interrupt_msix_sent,
    input  wire                               cfg_interrupt_msix_fail,
    output wire [7:0]                         cfg_interrupt_msi_function_number,

    output wire                               status_error_cor,
    output wire                               status_error_uncor,

    /*
     * Ethernet: QSFP28
     */
    // input  wire [CH_CNT-1:0]                     qsfp_tx_clk,
    // input  wire [CH_CNT-1:0]                     qsfp_tx_rst,
    // output wire [CH_CNT*XGMII_DATA_WIDTH-1:0]    qsfp_txd,
    // output wire [CH_CNT*XGMII_CTRL_WIDTH-1:0]    qsfp_txc,
    // output wire [CH_CNT-1:0]                     qsfp_cfg_tx_prbs31_enable,
    // input  wire [CH_CNT-1:0]                     qsfp_rx_clk,
    // input  wire [CH_CNT-1:0]                     qsfp_rx_rst,
    // input  wire [CH_CNT*XGMII_DATA_WIDTH-1:0]    qsfp_rxd,
    // input  wire [CH_CNT*XGMII_CTRL_WIDTH-1:0]    qsfp_rxc,
    // output wire [CH_CNT-1:0]                     qsfp_cfg_rx_prbs31_enable,
    // input  wire [CH_CNT*7-1:0]                   qsfp_rx_error_count,
    // input  wire [CH_CNT-1:0]                     qsfp_rx_status,

    input  wire [QSFP_CNT-1:0]                   qsfp_drp_clk,
    input  wire [QSFP_CNT-1:0]                   qsfp_drp_rst,
    output wire [QSFP_CNT*24-1:0]                qsfp_drp_addr,
    output wire [QSFP_CNT*16-1:0]                qsfp_drp_di,
    output wire [QSFP_CNT-1:0]                   qsfp_drp_en,
    output wire [QSFP_CNT-1:0]                   qsfp_drp_we,
    input  wire [QSFP_CNT*16-1:0]                qsfp_drp_do,
    input  wire [QSFP_CNT-1:0]                   qsfp_drp_rdy,

    output wire [QSFP_CNT-1:0]                   qsfp_modsell,
    output wire [QSFP_CNT-1:0]                   qsfp_resetl,
    input  wire [QSFP_CNT-1:0]                   qsfp_modprsl,
    input  wire [QSFP_CNT-1:0]                   qsfp_intl,
    output wire [QSFP_CNT-1:0]                   qsfp_lpmode,

    /*
     * DDR
     */
    input  wire [DDR_CH-1:0]                     ddr_clk,
    input  wire [DDR_CH-1:0]                     ddr_rst,

    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_awid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]  m_axi_ddr_awaddr,
    output wire [DDR_CH*8-1:0]                   m_axi_ddr_awlen,
    output wire [DDR_CH*3-1:0]                   m_axi_ddr_awsize,
    output wire [DDR_CH*2-1:0]                   m_axi_ddr_awburst,
    output wire [DDR_CH-1:0]                     m_axi_ddr_awlock,
    output wire [DDR_CH*4-1:0]                   m_axi_ddr_awcache,
    output wire [DDR_CH*3-1:0]                   m_axi_ddr_awprot,
    output wire [DDR_CH*4-1:0]                   m_axi_ddr_awqos,
    output wire [DDR_CH-1:0]                     m_axi_ddr_awvalid,
    input  wire [DDR_CH-1:0]                     m_axi_ddr_awready,
    output wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]  m_axi_ddr_wdata,
    output wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]  m_axi_ddr_wstrb,
    output wire [DDR_CH-1:0]                     m_axi_ddr_wlast,
    output wire [DDR_CH-1:0]                     m_axi_ddr_wvalid,
    input  wire [DDR_CH-1:0]                     m_axi_ddr_wready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_bid,
    input  wire [DDR_CH*2-1:0]                   m_axi_ddr_bresp,
    input  wire [DDR_CH-1:0]                     m_axi_ddr_bvalid,
    output wire [DDR_CH-1:0]                     m_axi_ddr_bready,
    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_arid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]  m_axi_ddr_araddr,
    output wire [DDR_CH*8-1:0]                   m_axi_ddr_arlen,
    output wire [DDR_CH*3-1:0]                   m_axi_ddr_arsize,
    output wire [DDR_CH*2-1:0]                   m_axi_ddr_arburst,
    output wire [DDR_CH-1:0]                     m_axi_ddr_arlock,
    output wire [DDR_CH*4-1:0]                   m_axi_ddr_arcache,
    output wire [DDR_CH*3-1:0]                   m_axi_ddr_arprot,
    output wire [DDR_CH*4-1:0]                   m_axi_ddr_arqos,
    output wire [DDR_CH-1:0]                     m_axi_ddr_arvalid,
    input  wire [DDR_CH-1:0]                     m_axi_ddr_arready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_rid,
    input  wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]  m_axi_ddr_rdata,
    input  wire [DDR_CH*2-1:0]                   m_axi_ddr_rresp,
    input  wire [DDR_CH-1:0]                     m_axi_ddr_rlast,
    input  wire [DDR_CH-1:0]                     m_axi_ddr_rvalid,
    output wire [DDR_CH-1:0]                     m_axi_ddr_rready,

    input  wire [DDR_CH-1:0]                     ddr_status,

    /*
     * HBM
     */
    input  wire [HBM_CH-1:0]                     hbm_clk,
    input  wire [HBM_CH-1:0]                     hbm_rst,

    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_awid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]  m_axi_hbm_awaddr,
    output wire [HBM_CH*8-1:0]                   m_axi_hbm_awlen,
    output wire [HBM_CH*3-1:0]                   m_axi_hbm_awsize,
    output wire [HBM_CH*2-1:0]                   m_axi_hbm_awburst,
    output wire [HBM_CH-1:0]                     m_axi_hbm_awlock,
    output wire [HBM_CH*4-1:0]                   m_axi_hbm_awcache,
    output wire [HBM_CH*3-1:0]                   m_axi_hbm_awprot,
    output wire [HBM_CH*4-1:0]                   m_axi_hbm_awqos,
    output wire [HBM_CH-1:0]                     m_axi_hbm_awvalid,
    input  wire [HBM_CH-1:0]                     m_axi_hbm_awready,
    output wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]  m_axi_hbm_wdata,
    output wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]  m_axi_hbm_wstrb,
    output wire [HBM_CH-1:0]                     m_axi_hbm_wlast,
    output wire [HBM_CH-1:0]                     m_axi_hbm_wvalid,
    input  wire [HBM_CH-1:0]                     m_axi_hbm_wready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_bid,
    input  wire [HBM_CH*2-1:0]                   m_axi_hbm_bresp,
    input  wire [HBM_CH-1:0]                     m_axi_hbm_bvalid,
    output wire [HBM_CH-1:0]                     m_axi_hbm_bready,
    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_arid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]  m_axi_hbm_araddr,
    output wire [HBM_CH*8-1:0]                   m_axi_hbm_arlen,
    output wire [HBM_CH*3-1:0]                   m_axi_hbm_arsize,
    output wire [HBM_CH*2-1:0]                   m_axi_hbm_arburst,
    output wire [HBM_CH-1:0]                     m_axi_hbm_arlock,
    output wire [HBM_CH*4-1:0]                   m_axi_hbm_arcache,
    output wire [HBM_CH*3-1:0]                   m_axi_hbm_arprot,
    output wire [HBM_CH*4-1:0]                   m_axi_hbm_arqos,
    output wire [HBM_CH-1:0]                     m_axi_hbm_arvalid,
    input  wire [HBM_CH-1:0]                     m_axi_hbm_arready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_rid,
    input  wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]  m_axi_hbm_rdata,
    input  wire [HBM_CH*2-1:0]                   m_axi_hbm_rresp,
    input  wire [HBM_CH-1:0]                     m_axi_hbm_rlast,
    input  wire [HBM_CH-1:0]                     m_axi_hbm_rvalid,
    output wire [HBM_CH-1:0]                     m_axi_hbm_rready,

    input  wire [HBM_CH-1:0]                     hbm_status,

    /*
     * QSPI flash
     */
    output wire                               fpga_boot,
    output wire                               qspi_clk,
    input  wire [3:0]                         qspi_dq_i,
    output wire [3:0]                         qspi_dq_o,
    output wire [3:0]                         qspi_dq_oe,
    output wire                               qspi_cs,

    /*
     * AXI-Lite interface to CMS
     */
    output wire                               m_axil_cms_clk,
    output wire                               m_axil_cms_rst,
    output wire [17:0]                        m_axil_cms_awaddr,
    output wire [2:0]                         m_axil_cms_awprot,
    output wire                               m_axil_cms_awvalid,
    input  wire                               m_axil_cms_awready,
    output wire [31:0]                        m_axil_cms_wdata,
    output wire [3:0]                         m_axil_cms_wstrb,
    output wire                               m_axil_cms_wvalid,
    input  wire                               m_axil_cms_wready,
    input  wire [1:0]                         m_axil_cms_bresp,
    input  wire                               m_axil_cms_bvalid,
    output wire                               m_axil_cms_bready,
    output wire [17:0]                        m_axil_cms_araddr,
    output wire [2:0]                         m_axil_cms_arprot,
    output wire                               m_axil_cms_arvalid,
    input  wire                               m_axil_cms_arready,
    input  wire [31:0]                        m_axil_cms_rdata,
    input  wire [1:0]                         m_axil_cms_rresp,
    input  wire                               m_axil_cms_rvalid,
    output wire                               m_axil_cms_rready
);

genvar n;

wire [CH_CNT-1:0]                   qsfp_tx_clk;
wire [CH_CNT-1:0]                   qsfp_tx_rst;
wire [CH_CNT*XGMII_DATA_WIDTH-1:0]  qsfp_txd;
wire [CH_CNT*XGMII_CTRL_WIDTH-1:0]  qsfp_txc;
wire [CH_CNT-1:0]                   qsfp_cfg_tx_prbs31_enable;
wire [CH_CNT-1:0]                   qsfp_rx_clk;
wire [CH_CNT-1:0]                   qsfp_rx_rst;
wire [CH_CNT*XGMII_DATA_WIDTH-1:0]  qsfp_rxd;
wire [CH_CNT*XGMII_CTRL_WIDTH-1:0]  qsfp_rxc;
wire [CH_CNT-1:0]                   qsfp_cfg_rx_prbs31_enable;
wire [CH_CNT*7-1:0]                 qsfp_rx_error_count;
wire [CH_CNT-1:0]                   qsfp_rx_status;

generate

for (n = 0; n < CH_CNT; n = n + 1) begin : ch

    wire                         ch_tx_clk;
    wire                         ch_tx_rst;
    wire [XGMII_DATA_WIDTH-1:0]  ch_txd;
    wire [XGMII_CTRL_WIDTH-1:0]  ch_txc;
    wire                         ch_cfg_tx_prbs31_enable;
    wire                         ch_rx_clk;
    wire                         ch_rx_rst;
    wire [XGMII_DATA_WIDTH-1:0]  ch_rxd;
    wire [XGMII_CTRL_WIDTH-1:0]  ch_rxc;
    wire                         ch_cfg_rx_prbs31_enable;
    wire [6:0]                   ch_rx_error_count;
    wire                         ch_rx_status;

    assign qsfp_tx_clk[n +: 1] = ch_tx_clk;
    assign qsfp_tx_rst[n +: 1] = ch_tx_rst;
    assign ch_txd = qsfp_txd[n*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
    assign ch_txc = qsfp_txc[n*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    assign ch_cfg_tx_prbs31_enable = qsfp_cfg_tx_prbs31_enable[n +: 1];
    assign qsfp_rx_clk[n +: 1] = ch_rx_clk;
    assign qsfp_rx_rst[n +: 1] = ch_rx_rst;
    assign qsfp_rxd[n*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = ch_rxd;
    assign qsfp_rxc[n*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = ch_rxc;
    assign ch_cfg_rx_prbs31_enable = qsfp_cfg_rx_prbs31_enable[n +: 1];
    assign qsfp_rx_error_count[n*7 +: 7] = ch_rx_error_count;
    assign qsfp_rx_status[n +: 1] = ch_rx_status;

end

endgenerate

fpga_core #(
    // FW and board IDs
    .FPGA_ID(FPGA_ID),
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .BUILD_DATE(BUILD_DATE),
    .GIT_HASH(GIT_HASH),
    .RELEASE_INFO(RELEASE_INFO),

    // Board configuration
    .QSFP_CNT(QSFP_CNT),
    .CH_CNT(CH_CNT),
    .CMS_ENABLE(CMS_ENABLE),
    .TDMA_BER_ENABLE(TDMA_BER_ENABLE),
    .FLASH_SEG_COUNT(2),
    .FLASH_SEG_DEFAULT(1),
    .FLASH_SEG_FALLBACK(0),
    .FLASH_SEG0_SIZE(32'h01002000),

    // Structural configuration
    .IF_COUNT(IF_COUNT),
    .PORTS_PER_IF(PORTS_PER_IF),
    .SCHED_PER_IF(SCHED_PER_IF),
    .PORT_MASK(PORT_MASK),

    // Clock configuration
    .CLK_PERIOD_NS_NUM(CLK_PERIOD_NS_NUM),
    .CLK_PERIOD_NS_DENOM(CLK_PERIOD_NS_DENOM),

    // PTP configuration
    .PTP_CLK_PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
    .PTP_CLK_PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_CLOCK_PIPELINE(PTP_CLOCK_PIPELINE),
    .PTP_CLOCK_CDC_PIPELINE(PTP_CLOCK_CDC_PIPELINE),
    .PTP_PORT_CDC_PIPELINE(PTP_PORT_CDC_PIPELINE),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),
    .IF_PTP_PERIOD_NS(IF_PTP_PERIOD_NS),
    .IF_PTP_PERIOD_FNS(IF_PTP_PERIOD_FNS),

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
    .TX_CPL_FIFO_DEPTH(TX_CPL_FIFO_DEPTH),
    .TX_TAG_WIDTH(TX_TAG_WIDTH),
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .PFC_ENABLE(PFC_ENABLE),
    .LFC_ENABLE(LFC_ENABLE),
    .ENABLE_PADDING(ENABLE_PADDING),
    .ENABLE_DIC(ENABLE_DIC),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

    // RAM configuration
    .DDR_CH(DDR_CH),
    .DDR_ENABLE(DDR_ENABLE),
    .AXI_DDR_DATA_WIDTH(AXI_DDR_DATA_WIDTH),
    .AXI_DDR_ADDR_WIDTH(AXI_DDR_ADDR_WIDTH),
    .AXI_DDR_STRB_WIDTH(AXI_DDR_STRB_WIDTH),
    .AXI_DDR_ID_WIDTH(AXI_DDR_ID_WIDTH),
    .AXI_DDR_MAX_BURST_LEN(AXI_DDR_MAX_BURST_LEN),
    .AXI_DDR_NARROW_BURST(AXI_DDR_NARROW_BURST),
    .HBM_CH(HBM_CH),
    .HBM_ENABLE(HBM_ENABLE),
    .HBM_GROUP_SIZE(HBM_GROUP_SIZE),
    .AXI_HBM_DATA_WIDTH(AXI_HBM_DATA_WIDTH),
    .AXI_HBM_ADDR_WIDTH(AXI_HBM_ADDR_WIDTH),
    .AXI_HBM_STRB_WIDTH(AXI_HBM_STRB_WIDTH),
    .AXI_HBM_ID_WIDTH(AXI_HBM_ID_WIDTH),
    .AXI_HBM_MAX_BURST_LEN(AXI_HBM_MAX_BURST_LEN),

    // Application block configuration
    .APP_ID(APP_ID),
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),

    // DMA interface configuration
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // PCIe interface configuration
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .RC_STRADDLE(RC_STRADDLE),
    .RQ_STRADDLE(RQ_STRADDLE),
    .CQ_STRADDLE(CQ_STRADDLE),
    .CC_STRADDLE(CC_STRADDLE),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .PF_COUNT(PF_COUNT),
    .VF_COUNT(VF_COUNT),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),

    // Interrupt configuration
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),

    // AXI lite interface configuration (application control)
    .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),

    // Ethernet interface configuration
    .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
    .XGMII_CTRL_WIDTH(XGMII_CTRL_WIDTH),
    .AXIS_ETH_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_ETH_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .AXIS_ETH_SYNC_DATA_WIDTH(AXIS_ETH_SYNC_DATA_WIDTH),
    .AXIS_ETH_TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .AXIS_ETH_RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH),
    .AXIS_ETH_TX_PIPELINE(AXIS_ETH_TX_PIPELINE),
    .AXIS_ETH_TX_FIFO_PIPELINE(AXIS_ETH_TX_FIFO_PIPELINE),
    .AXIS_ETH_TX_TS_PIPELINE(AXIS_ETH_TX_TS_PIPELINE),
    .AXIS_ETH_RX_PIPELINE(AXIS_ETH_RX_PIPELINE),
    .AXIS_ETH_RX_FIFO_PIPELINE(AXIS_ETH_RX_FIFO_PIPELINE),

    // Statistics counter subsystem
    .STAT_ENABLE(STAT_ENABLE),
    .STAT_DMA_ENABLE(STAT_DMA_ENABLE),
    .STAT_PCIE_ENABLE(STAT_PCIE_ENABLE),
    .STAT_INC_WIDTH(STAT_INC_WIDTH),
    .STAT_ID_WIDTH(STAT_ID_WIDTH)
)
uut (
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    .clk_250mhz(clk_250mhz),
    .rst_250mhz(rst_250mhz),

    /*
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),

    /*
     * GPIO
     */
    .sw(sw),
    .led(led),
    .qsfp_led_act(qsfp_led_act),
    .qsfp_led_stat_g(qsfp_led_stat_g),
    .qsfp_led_stat_y(qsfp_led_stat_y),

    /*
     * I2C
     */
    .i2c_scl_i(i2c_scl_i),
    .i2c_scl_o(i2c_scl_o),
    .i2c_scl_t(i2c_scl_t),
    .i2c_sda_i(i2c_sda_i),
    .i2c_sda_o(i2c_sda_o),
    .i2c_sda_t(i2c_sda_t),

    /*
     * PCIe
     */
    .m_axis_rq_tdata(m_axis_rq_tdata),
    .m_axis_rq_tkeep(m_axis_rq_tkeep),
    .m_axis_rq_tlast(m_axis_rq_tlast),
    .m_axis_rq_tready(m_axis_rq_tready),
    .m_axis_rq_tuser(m_axis_rq_tuser),
    .m_axis_rq_tvalid(m_axis_rq_tvalid),

    .s_axis_rc_tdata(s_axis_rc_tdata),
    .s_axis_rc_tkeep(s_axis_rc_tkeep),
    .s_axis_rc_tlast(s_axis_rc_tlast),
    .s_axis_rc_tready(s_axis_rc_tready),
    .s_axis_rc_tuser(s_axis_rc_tuser),
    .s_axis_rc_tvalid(s_axis_rc_tvalid),

    .s_axis_cq_tdata(s_axis_cq_tdata),
    .s_axis_cq_tkeep(s_axis_cq_tkeep),
    .s_axis_cq_tlast(s_axis_cq_tlast),
    .s_axis_cq_tready(s_axis_cq_tready),
    .s_axis_cq_tuser(s_axis_cq_tuser),
    .s_axis_cq_tvalid(s_axis_cq_tvalid),

    .m_axis_cc_tdata(m_axis_cc_tdata),
    .m_axis_cc_tkeep(m_axis_cc_tkeep),
    .m_axis_cc_tlast(m_axis_cc_tlast),
    .m_axis_cc_tready(m_axis_cc_tready),
    .m_axis_cc_tuser(m_axis_cc_tuser),
    .m_axis_cc_tvalid(m_axis_cc_tvalid),

    .s_axis_rq_seq_num_0(s_axis_rq_seq_num_0),
    .s_axis_rq_seq_num_valid_0(s_axis_rq_seq_num_valid_0),
    .s_axis_rq_seq_num_1(s_axis_rq_seq_num_1),
    .s_axis_rq_seq_num_valid_1(s_axis_rq_seq_num_valid_1),

    .pcie_tfc_nph_av(pcie_tfc_nph_av),
    .pcie_tfc_npd_av(pcie_tfc_npd_av),

    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_rcb_status(cfg_rcb_status),

    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    .cfg_interrupt_msix_vec_pending(cfg_interrupt_msix_vec_pending),
    .cfg_interrupt_msix_vec_pending_status(cfg_interrupt_msix_vec_pending_status),
    .cfg_interrupt_msix_sent(cfg_interrupt_msix_sent),
    .cfg_interrupt_msix_fail(cfg_interrupt_msix_fail),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor),

    /*
     * Ethernet: QSFP28
     */
    .qsfp_tx_clk(qsfp_tx_clk),
    .qsfp_tx_rst(qsfp_tx_rst),
    .qsfp_txd(qsfp_txd),
    .qsfp_txc(qsfp_txc),
    .qsfp_cfg_tx_prbs31_enable(qsfp_cfg_tx_prbs31_enable),
    .qsfp_rx_clk(qsfp_rx_clk),
    .qsfp_rx_rst(qsfp_rx_rst),
    .qsfp_rxd(qsfp_rxd),
    .qsfp_rxc(qsfp_rxc),
    .qsfp_cfg_rx_prbs31_enable(qsfp_cfg_rx_prbs31_enable),
    .qsfp_rx_error_count(qsfp_rx_error_count),
    .qsfp_rx_status(qsfp_rx_status),

    .qsfp_drp_clk(qsfp_drp_clk),
    .qsfp_drp_rst(qsfp_drp_rst),
    .qsfp_drp_addr(qsfp_drp_addr),
    .qsfp_drp_di(qsfp_drp_di),
    .qsfp_drp_en(qsfp_drp_en),
    .qsfp_drp_we(qsfp_drp_we),
    .qsfp_drp_do(qsfp_drp_do),
    .qsfp_drp_rdy(qsfp_drp_rdy),

    .qsfp_modsell(qsfp_modsell),
    .qsfp_resetl(qsfp_resetl),
    .qsfp_modprsl(qsfp_modprsl),
    .qsfp_intl(qsfp_intl),
    .qsfp_lpmode(qsfp_lpmode),

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
    .m_axi_ddr_awvalid(m_axi_ddr_awvalid),
    .m_axi_ddr_awready(m_axi_ddr_awready),
    .m_axi_ddr_wdata(m_axi_ddr_wdata),
    .m_axi_ddr_wstrb(m_axi_ddr_wstrb),
    .m_axi_ddr_wlast(m_axi_ddr_wlast),
    .m_axi_ddr_wvalid(m_axi_ddr_wvalid),
    .m_axi_ddr_wready(m_axi_ddr_wready),
    .m_axi_ddr_bid(m_axi_ddr_bid),
    .m_axi_ddr_bresp(m_axi_ddr_bresp),
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
    .m_axi_ddr_arvalid(m_axi_ddr_arvalid),
    .m_axi_ddr_arready(m_axi_ddr_arready),
    .m_axi_ddr_rid(m_axi_ddr_rid),
    .m_axi_ddr_rdata(m_axi_ddr_rdata),
    .m_axi_ddr_rresp(m_axi_ddr_rresp),
    .m_axi_ddr_rlast(m_axi_ddr_rlast),
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
    .m_axi_hbm_awvalid(m_axi_hbm_awvalid),
    .m_axi_hbm_awready(m_axi_hbm_awready),
    .m_axi_hbm_wdata(m_axi_hbm_wdata),
    .m_axi_hbm_wstrb(m_axi_hbm_wstrb),
    .m_axi_hbm_wlast(m_axi_hbm_wlast),
    .m_axi_hbm_wvalid(m_axi_hbm_wvalid),
    .m_axi_hbm_wready(m_axi_hbm_wready),
    .m_axi_hbm_bid(m_axi_hbm_bid),
    .m_axi_hbm_bresp(m_axi_hbm_bresp),
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
    .m_axi_hbm_arvalid(m_axi_hbm_arvalid),
    .m_axi_hbm_arready(m_axi_hbm_arready),
    .m_axi_hbm_rid(m_axi_hbm_rid),
    .m_axi_hbm_rdata(m_axi_hbm_rdata),
    .m_axi_hbm_rresp(m_axi_hbm_rresp),
    .m_axi_hbm_rlast(m_axi_hbm_rlast),
    .m_axi_hbm_rvalid(m_axi_hbm_rvalid),
    .m_axi_hbm_rready(m_axi_hbm_rready),

    .hbm_status(hbm_status),

    /*
     * QSPI flash
     */
    .fpga_boot(fpga_boot),
    .qspi_clk(qspi_clk),
    .qspi_dq_i(qspi_dq_i),
    .qspi_dq_o(qspi_dq_o),
    .qspi_dq_oe(qspi_dq_oe),
    .qspi_cs(qspi_cs),

    /*
     * AXI-Lite interface to CMS
     */
    .m_axil_cms_clk(m_axil_cms_clk),
    .m_axil_cms_rst(m_axil_cms_rst),
    .m_axil_cms_awaddr(m_axil_cms_awaddr),
    .m_axil_cms_awprot(m_axil_cms_awprot),
    .m_axil_cms_awvalid(m_axil_cms_awvalid),
    .m_axil_cms_awready(m_axil_cms_awready),
    .m_axil_cms_wdata(m_axil_cms_wdata),
    .m_axil_cms_wstrb(m_axil_cms_wstrb),
    .m_axil_cms_wvalid(m_axil_cms_wvalid),
    .m_axil_cms_wready(m_axil_cms_wready),
    .m_axil_cms_bresp(m_axil_cms_bresp),
    .m_axil_cms_bvalid(m_axil_cms_bvalid),
    .m_axil_cms_bready(m_axil_cms_bready),
    .m_axil_cms_araddr(m_axil_cms_araddr),
    .m_axil_cms_arprot(m_axil_cms_arprot),
    .m_axil_cms_arvalid(m_axil_cms_arvalid),
    .m_axil_cms_arready(m_axil_cms_arready),
    .m_axil_cms_rdata(m_axil_cms_rdata),
    .m_axil_cms_rresp(m_axil_cms_rresp),
    .m_axil_cms_rvalid(m_axil_cms_rvalid),
    .m_axil_cms_rready(m_axil_cms_rready)
);

endmodule

`resetall
