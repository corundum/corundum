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
 * mqnic core logic - Xilinx UltraScale/UltraScale+ wrapper
 */
module mqnic_core_pcie_us #
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
    parameter PTP_USE_SAMPLE_CLOCK = 0,
    parameter PTP_SEPARATE_TX_CLOCK = 0,
    parameter PTP_SEPARATE_RX_CLOCK = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration
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

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter AXIS_PCIE_DATA_WIDTH = 256,
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
    parameter F_COUNT = PF_COUNT+VF_COUNT,
    parameter PCIE_TAG_COUNT = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 64 : 256,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1),
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 2**(RQ_SEQ_NUM_WIDTH-1),
    parameter PCIE_DMA_WRITE_TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1),

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = EVENT_QUEUE_INDEX_WIDTH,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),
    parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT),
    parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8),
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
     * AXI input (RC)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]               s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]               s_axis_rc_tkeep,
    input  wire                                          s_axis_rc_tvalid,
    output wire                                          s_axis_rc_tready,
    input  wire                                          s_axis_rc_tlast,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0]            s_axis_rc_tuser,

    /*
     * AXI output (RQ)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]               m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]               m_axis_rq_tkeep,
    output wire                                          m_axis_rq_tvalid,
    input  wire                                          m_axis_rq_tready,
    output wire                                          m_axis_rq_tlast,
    output wire [AXIS_PCIE_RQ_USER_WIDTH-1:0]            m_axis_rq_tuser,

    /*
     * AXI input (CQ)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]               s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]               s_axis_cq_tkeep,
    input  wire                                          s_axis_cq_tvalid,
    output wire                                          s_axis_cq_tready,
    input  wire                                          s_axis_cq_tlast,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0]            s_axis_cq_tuser,

    /*
     * AXI output (CC)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]               m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]               m_axis_cc_tkeep,
    output wire                                          m_axis_cc_tvalid,
    input  wire                                          m_axis_cc_tready,
    output wire                                          m_axis_cc_tlast,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0]            m_axis_cc_tuser,

    /*
     * Transmit sequence number input
     */
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]                   s_axis_rq_seq_num_0,
    input  wire                                          s_axis_rq_seq_num_valid_0,
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]                   s_axis_rq_seq_num_1,
    input  wire                                          s_axis_rq_seq_num_valid_1,

    /*
     * Configuration management interface
     */
    output wire [9:0]                                    cfg_mgmt_addr,
    output wire [7:0]                                    cfg_mgmt_function_number,
    output wire                                          cfg_mgmt_write,
    output wire [31:0]                                   cfg_mgmt_write_data,
    output wire [3:0]                                    cfg_mgmt_byte_enable,
    output wire                                          cfg_mgmt_read,
    input  wire [31:0]                                   cfg_mgmt_read_data,
    input  wire                                          cfg_mgmt_read_write_done,

    /*
     * Configuration status interface
     */
    input  wire [2:0]                                    cfg_max_read_req,
    input  wire [2:0]                                    cfg_max_payload,

    /*
     * Configuration flow control interface
     */
    input  wire [7:0]                                    cfg_fc_ph,
    input  wire [11:0]                                   cfg_fc_pd,
    input  wire [7:0]                                    cfg_fc_nph,
    input  wire [11:0]                                   cfg_fc_npd,
    input  wire [7:0]                                    cfg_fc_cplh,
    input  wire [11:0]                                   cfg_fc_cpld,
    output wire [2:0]                                    cfg_fc_sel,

    /*
     * Configuration interrupt interface
     */
    input  wire [3:0]                                    cfg_interrupt_msix_enable,
    input  wire [3:0]                                    cfg_interrupt_msix_mask,
    input  wire [251:0]                                  cfg_interrupt_msix_vf_enable,
    input  wire [251:0]                                  cfg_interrupt_msix_vf_mask,
    output wire [63:0]                                   cfg_interrupt_msix_address,
    output wire [31:0]                                   cfg_interrupt_msix_data,
    output wire                                          cfg_interrupt_msix_int,
    output wire [1:0]                                    cfg_interrupt_msix_vec_pending,
    input  wire                                          cfg_interrupt_msix_vec_pending_status,
    input  wire                                          cfg_interrupt_msix_sent,
    input  wire                                          cfg_interrupt_msix_fail,
    output wire [7:0]                                    cfg_interrupt_msi_function_number,

    /*
     * PCIe error outputs
     */
    output wire                                          status_error_cor,
    output wire                                          status_error_uncor,

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
    output wire                                          ptp_pps,
    output wire                                          ptp_pps_str,
    output wire [PTP_TS_WIDTH-1:0]                       ptp_ts_96,
    output wire                                          ptp_ts_step,
    output wire                                          ptp_sync_pps,
    output wire [PTP_TS_WIDTH-1:0]                       ptp_sync_ts_96,
    output wire                                          ptp_sync_ts_step,
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
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_tx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                         eth_tx_ptp_ts_step,

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

    input  wire [PORT_COUNT-1:0]                         eth_tx_status,

    input  wire [PORT_COUNT-1:0]                         eth_rx_clk,
    input  wire [PORT_COUNT-1:0]                         eth_rx_rst,

    input  wire [PORT_COUNT-1:0]                         eth_rx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                         eth_rx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_rx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                         eth_rx_ptp_ts_step,

    input  wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     s_axis_eth_rx_tdata,
    input  wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     s_axis_eth_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tvalid,
    output wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tready,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tlast,
    input  wire [PORT_COUNT*AXIS_ETH_RX_USER_WIDTH-1:0]  s_axis_eth_rx_tuser,

    input  wire [PORT_COUNT-1:0]                         eth_rx_status,

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
     * JTAG
     */
    input  wire                                          app_jtag_tdi,
    output wire                                          app_jtag_tdo,
    input  wire                                          app_jtag_tms,
    input  wire                                          app_jtag_tck
);

parameter TLP_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32;
parameter TLP_HDR_WIDTH = 128;
parameter TLP_SEG_COUNT = 1;
parameter TX_SEQ_NUM_COUNT = AXIS_PCIE_DATA_WIDTH < 512 ? 1 : 2;
parameter TX_SEQ_NUM_WIDTH = RQ_SEQ_NUM_WIDTH-1;

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
wire [F_COUNT-1:0] msix_enable;
wire [F_COUNT-1:0] msix_mask;

pcie_us_if #(
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
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .PF_COUNT(1),
    .VF_COUNT(0),
    .READ_EXT_TAG_ENABLE(1),
    .READ_MAX_READ_REQ_SIZE(1),
    .READ_MAX_PAYLOAD_SIZE(1),
    .MSIX_ENABLE(1),
    .MSI_ENABLE(0)
)
pcie_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI input (RC)
     */
    .s_axis_rc_tdata(s_axis_rc_tdata),
    .s_axis_rc_tkeep(s_axis_rc_tkeep),
    .s_axis_rc_tvalid(s_axis_rc_tvalid),
    .s_axis_rc_tready(s_axis_rc_tready),
    .s_axis_rc_tlast(s_axis_rc_tlast),
    .s_axis_rc_tuser(s_axis_rc_tuser),

    /*
     * AXI output (RQ)
     */
    .m_axis_rq_tdata(m_axis_rq_tdata),
    .m_axis_rq_tkeep(m_axis_rq_tkeep),
    .m_axis_rq_tvalid(m_axis_rq_tvalid),
    .m_axis_rq_tready(m_axis_rq_tready),
    .m_axis_rq_tlast(m_axis_rq_tlast),
    .m_axis_rq_tuser(m_axis_rq_tuser),

    /*
     * AXI input (CQ)
     */
    .s_axis_cq_tdata(s_axis_cq_tdata),
    .s_axis_cq_tkeep(s_axis_cq_tkeep),
    .s_axis_cq_tvalid(s_axis_cq_tvalid),
    .s_axis_cq_tready(s_axis_cq_tready),
    .s_axis_cq_tlast(s_axis_cq_tlast),
    .s_axis_cq_tuser(s_axis_cq_tuser),

    /*
     * AXI output (CC)
     */
    .m_axis_cc_tdata(m_axis_cc_tdata),
    .m_axis_cc_tkeep(m_axis_cc_tkeep),
    .m_axis_cc_tvalid(m_axis_cc_tvalid),
    .m_axis_cc_tready(m_axis_cc_tready),
    .m_axis_cc_tlast(m_axis_cc_tlast),
    .m_axis_cc_tuser(m_axis_cc_tuser),

    /*
     * Transmit sequence number input
     */
    .s_axis_rq_seq_num_0(s_axis_rq_seq_num_0),
    .s_axis_rq_seq_num_valid_0(s_axis_rq_seq_num_valid_0),
    .s_axis_rq_seq_num_1(s_axis_rq_seq_num_1),
    .s_axis_rq_seq_num_valid_1(s_axis_rq_seq_num_valid_1),

    /*
     * Configuration management interface
     */
    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    /*
     * Configuration status interface
     */
    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),

    /*
     * Configuration flow control interface
     */
    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    /*
     * Configuration interrupt interface
     */
    .cfg_interrupt_msi_enable(),
    .cfg_interrupt_msi_vf_enable(),
    .cfg_interrupt_msi_mmenable(),
    .cfg_interrupt_msi_mask_update(),
    .cfg_interrupt_msi_data(),
    .cfg_interrupt_msi_select(),
    .cfg_interrupt_msi_int(),
    .cfg_interrupt_msi_pending_status(),
    .cfg_interrupt_msi_pending_status_data_enable(),
    .cfg_interrupt_msi_pending_status_function_num(),
    .cfg_interrupt_msi_sent(),
    .cfg_interrupt_msi_fail(),
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
    .cfg_interrupt_msi_attr(),
    .cfg_interrupt_msi_tph_present(),
    .cfg_interrupt_msi_tph_type(),
    .cfg_interrupt_msi_tph_st_tag(),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

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
    .tx_msix_wr_req_tlp_data(pcie_tx_msix_wr_req_tlp_data),
    .tx_msix_wr_req_tlp_strb(pcie_tx_msix_wr_req_tlp_strb),
    .tx_msix_wr_req_tlp_hdr(pcie_tx_msix_wr_req_tlp_hdr),
    .tx_msix_wr_req_tlp_valid(pcie_tx_msix_wr_req_tlp_valid),
    .tx_msix_wr_req_tlp_sop(pcie_tx_msix_wr_req_tlp_sop),
    .tx_msix_wr_req_tlp_eop(pcie_tx_msix_wr_req_tlp_eop),
    .tx_msix_wr_req_tlp_ready(pcie_tx_msix_wr_req_tlp_ready),

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
    .max_read_request_size(),
    .max_payload_size(),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask),

    /*
     * MSI request inputs
     */
    .msi_irq(32'd0)
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
    .PTP_USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK),
    .PTP_SEPARATE_TX_CLOCK(PTP_SEPARATE_TX_CLOCK),
    .PTP_SEPARATE_RX_CLOCK(PTP_SEPARATE_RX_CLOCK),
    .PTP_PORT_CDC_PIPELINE(PTP_PORT_CDC_PIPELINE),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

    // Queue manager configuration
    .EVENT_QUEUE_OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .TX_QUEUE_OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .RX_QUEUE_OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .TX_CPL_QUEUE_OP_TABLE_SIZE(TX_CPL_QUEUE_OP_TABLE_SIZE),
    .RX_CPL_QUEUE_OP_TABLE_SIZE(RX_CPL_QUEUE_OP_TABLE_SIZE),
    .EVENT_QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_QUEUE_PIPELINE(EVENT_QUEUE_PIPELINE),
    .TX_QUEUE_PIPELINE(TX_QUEUE_PIPELINE),
    .RX_QUEUE_PIPELINE(RX_QUEUE_PIPELINE),
    .TX_CPL_QUEUE_PIPELINE(TX_CPL_QUEUE_PIPELINE),
    .RX_CPL_QUEUE_PIPELINE(RX_CPL_QUEUE_PIPELINE),

    // TX and RX engine configuration
    .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),

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
    .PCIE_DMA_WRITE_OP_TABLE_SIZE(PCIE_DMA_WRITE_OP_TABLE_SIZE),
    .PCIE_DMA_WRITE_TX_LIMIT(PCIE_DMA_WRITE_TX_LIMIT),
    .TLP_FORCE_64_BIT_ADDR(1),
    .CHECK_BUS_NUMBER(0),

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
    .bus_num(8'd0),
    .ext_tag_enable(ext_tag_enable),
    .max_read_request_size(cfg_max_read_req),
    .max_payload_size(cfg_max_payload),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask),

    /*
     * PCIe error outputs
     */
    .pcie_error_cor(status_error_cor),
    .pcie_error_uncor(status_error_uncor),

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
    .ptp_pps(ptp_pps),
    .ptp_pps_str(ptp_pps_str),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step),
    .ptp_sync_pps(ptp_sync_pps),
    .ptp_sync_ts_96(ptp_sync_ts_96),
    .ptp_sync_ts_step(ptp_sync_ts_step),
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
    .tx_ptp_ts_96(eth_tx_ptp_ts_96),
    .tx_ptp_ts_step(eth_tx_ptp_ts_step),

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

    .tx_status(eth_tx_status),

    .rx_clk(eth_rx_clk),
    .rx_rst(eth_rx_rst),

    .rx_ptp_clk(eth_rx_ptp_clk),
    .rx_ptp_rst(eth_rx_ptp_rst),
    .rx_ptp_ts_96(eth_rx_ptp_ts_96),
    .rx_ptp_ts_step(eth_rx_ptp_ts_step),

    .s_axis_rx_tdata(s_axis_eth_rx_tdata),
    .s_axis_rx_tkeep(s_axis_eth_rx_tkeep),
    .s_axis_rx_tvalid(s_axis_eth_rx_tvalid),
    .s_axis_rx_tready(s_axis_eth_rx_tready),
    .s_axis_rx_tlast(s_axis_eth_rx_tlast),
    .s_axis_rx_tuser(s_axis_eth_rx_tuser),

    .rx_status(eth_rx_status),

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
     * JTAG
     */
    .app_jtag_tdi(app_jtag_tdi),
    .app_jtag_tdo(app_jtag_tdo),
    .app_jtag_tms(app_jtag_tms),
    .app_jtag_tck(app_jtag_tck)
);

endmodule

`resetall
