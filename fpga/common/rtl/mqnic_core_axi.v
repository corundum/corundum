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
 * mqnic core logic - AXI DMA wrapper
 */
module mqnic_core_axi #
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

    // AXI interface configuration (DMA)
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,
    parameter AXI_DMA_MAX_BURST_LEN = 256,
    parameter AXI_DMA_READ_USE_ID = 0,
    parameter AXI_DMA_WRITE_USE_ID = 1,
    parameter AXI_DMA_READ_OP_TABLE_SIZE = 2**(AXI_ID_WIDTH),
    parameter AXI_DMA_WRITE_OP_TABLE_SIZE = 2**(AXI_ID_WIDTH),

    // Interrupt configuration
    parameter IRQ_COUNT = 32,

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
    parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8),

    // Ethernet interface configuration
    parameter AXIS_DATA_WIDTH = 64,
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
    parameter STAT_DMA_ENABLE = 1,
    parameter STAT_AXI_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * AXI master interface (DMA)
     */
    output wire [AXI_ID_WIDTH-1:0]                    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]                  m_axi_awaddr,
    output wire [7:0]                                 m_axi_awlen,
    output wire [2:0]                                 m_axi_awsize,
    output wire [1:0]                                 m_axi_awburst,
    output wire                                       m_axi_awlock,
    output wire [3:0]                                 m_axi_awcache,
    output wire [2:0]                                 m_axi_awprot,
    output wire                                       m_axi_awvalid,
    input  wire                                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]                  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]                  m_axi_wstrb,
    output wire                                       m_axi_wlast,
    output wire                                       m_axi_wvalid,
    input  wire                                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]                    m_axi_bid,
    input  wire [1:0]                                 m_axi_bresp,
    input  wire                                       m_axi_bvalid,
    output wire                                       m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]                    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]                  m_axi_araddr,
    output wire [7:0]                                 m_axi_arlen,
    output wire [2:0]                                 m_axi_arsize,
    output wire [1:0]                                 m_axi_arburst,
    output wire                                       m_axi_arlock,
    output wire [3:0]                                 m_axi_arcache,
    output wire [2:0]                                 m_axi_arprot,
    output wire                                       m_axi_arvalid,
    input  wire                                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]                    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]                  m_axi_rdata,
    input  wire [1:0]                                 m_axi_rresp,
    input  wire                                       m_axi_rlast,
    input  wire                                       m_axi_rvalid,
    output wire                                       m_axi_rready,

    /*
     * AXI-Lite slave interface (control)
     */
    input  wire [AXIL_CTRL_ADDR_WIDTH-1:0]            s_axil_ctrl_awaddr,
    input  wire [2:0]                                 s_axil_ctrl_awprot,
    input  wire                                       s_axil_ctrl_awvalid,
    output wire                                       s_axil_ctrl_awready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]            s_axil_ctrl_wdata,
    input  wire [AXIL_CTRL_STRB_WIDTH-1:0]            s_axil_ctrl_wstrb,
    input  wire                                       s_axil_ctrl_wvalid,
    output wire                                       s_axil_ctrl_wready,
    output wire [1:0]                                 s_axil_ctrl_bresp,
    output wire                                       s_axil_ctrl_bvalid,
    input  wire                                       s_axil_ctrl_bready,
    input  wire [AXIL_CTRL_ADDR_WIDTH-1:0]            s_axil_ctrl_araddr,
    input  wire [2:0]                                 s_axil_ctrl_arprot,
    input  wire                                       s_axil_ctrl_arvalid,
    output wire                                       s_axil_ctrl_arready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]            s_axil_ctrl_rdata,
    output wire [1:0]                                 s_axil_ctrl_rresp,
    output wire                                       s_axil_ctrl_rvalid,
    input  wire                                       s_axil_ctrl_rready,

    /*
     * AXI-Lite slave interface (application control)
     */
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]        s_axil_app_ctrl_awaddr,
    input  wire [2:0]                                 s_axil_app_ctrl_awprot,
    input  wire                                       s_axil_app_ctrl_awvalid,
    output wire                                       s_axil_app_ctrl_awready,
    input  wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]        s_axil_app_ctrl_wdata,
    input  wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]        s_axil_app_ctrl_wstrb,
    input  wire                                       s_axil_app_ctrl_wvalid,
    output wire                                       s_axil_app_ctrl_wready,
    output wire [1:0]                                 s_axil_app_ctrl_bresp,
    output wire                                       s_axil_app_ctrl_bvalid,
    input  wire                                       s_axil_app_ctrl_bready,
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]        s_axil_app_ctrl_araddr,
    input  wire [2:0]                                 s_axil_app_ctrl_arprot,
    input  wire                                       s_axil_app_ctrl_arvalid,
    output wire                                       s_axil_app_ctrl_arready,
    output wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]        s_axil_app_ctrl_rdata,
    output wire [1:0]                                 s_axil_app_ctrl_rresp,
    output wire                                       s_axil_app_ctrl_rvalid,
    input  wire                                       s_axil_app_ctrl_rready,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             m_axil_csr_awaddr,
    output wire [2:0]                                 m_axil_csr_awprot,
    output wire                                       m_axil_csr_awvalid,
    input  wire                                       m_axil_csr_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]            m_axil_csr_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]            m_axil_csr_wstrb,
    output wire                                       m_axil_csr_wvalid,
    input  wire                                       m_axil_csr_wready,
    input  wire [1:0]                                 m_axil_csr_bresp,
    input  wire                                       m_axil_csr_bvalid,
    output wire                                       m_axil_csr_bready,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             m_axil_csr_araddr,
    output wire [2:0]                                 m_axil_csr_arprot,
    output wire                                       m_axil_csr_arvalid,
    input  wire                                       m_axil_csr_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]            m_axil_csr_rdata,
    input  wire [1:0]                                 m_axil_csr_rresp,
    input  wire                                       m_axil_csr_rvalid,
    output wire                                       m_axil_csr_rready,

    /*
     * Control register interface
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             ctrl_reg_wr_addr,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]            ctrl_reg_wr_data,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]            ctrl_reg_wr_strb,
    output wire                                       ctrl_reg_wr_en,
    input  wire                                       ctrl_reg_wr_wait,
    input  wire                                       ctrl_reg_wr_ack,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             ctrl_reg_rd_addr,
    output wire                                       ctrl_reg_rd_en,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]            ctrl_reg_rd_data,
    input  wire                                       ctrl_reg_rd_wait,
    input  wire                                       ctrl_reg_rd_ack,

    /*
     * Interrupt outputs
     */
    output wire [IRQ_COUNT-1:0]                       irq,

    /*
     * PTP clock
     */
    input  wire                                       ptp_clk,
    input  wire                                       ptp_rst,
    input  wire                                       ptp_sample_clk,
    output wire                                       ptp_pps,
    output wire                                       ptp_pps_str,
    output wire [PTP_TS_WIDTH-1:0]                    ptp_ts_96,
    output wire                                       ptp_ts_step,
    output wire                                       ptp_sync_pps,
    output wire [PTP_TS_WIDTH-1:0]                    ptp_sync_ts_96,
    output wire                                       ptp_sync_ts_step,
    output wire [PTP_PEROUT_COUNT-1:0]                ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]                ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]                ptp_perout_pulse,

    /*
     * Ethernet
     */
    input  wire [PORT_COUNT-1:0]                      tx_clk,
    input  wire [PORT_COUNT-1:0]                      tx_rst,

    input  wire [PORT_COUNT-1:0]                      tx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                      tx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]         tx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                      tx_ptp_ts_step,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]      m_axis_tx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]      m_axis_tx_tkeep,
    output wire [PORT_COUNT-1:0]                      m_axis_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                      m_axis_tx_tready,
    output wire [PORT_COUNT-1:0]                      m_axis_tx_tlast,
    output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]   m_axis_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]         s_axis_tx_cpl_ts,
    input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]         s_axis_tx_cpl_tag,
    input  wire [PORT_COUNT-1:0]                      s_axis_tx_cpl_valid,
    output wire [PORT_COUNT-1:0]                      s_axis_tx_cpl_ready,

    input  wire [PORT_COUNT-1:0]                      tx_status,

    input  wire [PORT_COUNT-1:0]                      rx_clk,
    input  wire [PORT_COUNT-1:0]                      rx_rst,

    input  wire [PORT_COUNT-1:0]                      rx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                      rx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]         rx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                      rx_ptp_ts_step,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]      s_axis_rx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]      s_axis_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                      s_axis_rx_tvalid,
    output wire [PORT_COUNT-1:0]                      s_axis_rx_tready,
    input  wire [PORT_COUNT-1:0]                      s_axis_rx_tlast,
    input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]   s_axis_rx_tuser,

    input  wire [PORT_COUNT-1:0]                      rx_status,

    /*
     * DDR
     */
    input  wire [DDR_CH-1:0]                          ddr_clk,
    input  wire [DDR_CH-1:0]                          ddr_rst,


    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]         m_axi_ddr_awid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]       m_axi_ddr_awaddr,
    output wire [DDR_CH*8-1:0]                        m_axi_ddr_awlen,
    output wire [DDR_CH*3-1:0]                        m_axi_ddr_awsize,
    output wire [DDR_CH*2-1:0]                        m_axi_ddr_awburst,
    output wire [DDR_CH-1:0]                          m_axi_ddr_awlock,
    output wire [DDR_CH*4-1:0]                        m_axi_ddr_awcache,
    output wire [DDR_CH*3-1:0]                        m_axi_ddr_awprot,
    output wire [DDR_CH*4-1:0]                        m_axi_ddr_awqos,
    output wire [DDR_CH*AXI_DDR_AWUSER_WIDTH-1:0]     m_axi_ddr_awuser,
    output wire [DDR_CH-1:0]                          m_axi_ddr_awvalid,
    input  wire [DDR_CH-1:0]                          m_axi_ddr_awready,
    output wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]       m_axi_ddr_wdata,
    output wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]       m_axi_ddr_wstrb,
    output wire [DDR_CH-1:0]                          m_axi_ddr_wlast,
    output wire [DDR_CH*AXI_DDR_WUSER_WIDTH-1:0]      m_axi_ddr_wuser,
    output wire [DDR_CH-1:0]                          m_axi_ddr_wvalid,
    input  wire [DDR_CH-1:0]                          m_axi_ddr_wready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]         m_axi_ddr_bid,
    input  wire [DDR_CH*2-1:0]                        m_axi_ddr_bresp,
    input  wire [DDR_CH*AXI_DDR_BUSER_WIDTH-1:0]      m_axi_ddr_buser,
    input  wire [DDR_CH-1:0]                          m_axi_ddr_bvalid,
    output wire [DDR_CH-1:0]                          m_axi_ddr_bready,
    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]         m_axi_ddr_arid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]       m_axi_ddr_araddr,
    output wire [DDR_CH*8-1:0]                        m_axi_ddr_arlen,
    output wire [DDR_CH*3-1:0]                        m_axi_ddr_arsize,
    output wire [DDR_CH*2-1:0]                        m_axi_ddr_arburst,
    output wire [DDR_CH-1:0]                          m_axi_ddr_arlock,
    output wire [DDR_CH*4-1:0]                        m_axi_ddr_arcache,
    output wire [DDR_CH*3-1:0]                        m_axi_ddr_arprot,
    output wire [DDR_CH*4-1:0]                        m_axi_ddr_arqos,
    output wire [DDR_CH*AXI_DDR_ARUSER_WIDTH-1:0]     m_axi_ddr_aruser,
    output wire [DDR_CH-1:0]                          m_axi_ddr_arvalid,
    input  wire [DDR_CH-1:0]                          m_axi_ddr_arready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]         m_axi_ddr_rid,
    input  wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]       m_axi_ddr_rdata,
    input  wire [DDR_CH*2-1:0]                        m_axi_ddr_rresp,
    input  wire [DDR_CH-1:0]                          m_axi_ddr_rlast,
    input  wire [DDR_CH*AXI_DDR_RUSER_WIDTH-1:0]      m_axi_ddr_ruser,
    input  wire [DDR_CH-1:0]                          m_axi_ddr_rvalid,
    output wire [DDR_CH-1:0]                          m_axi_ddr_rready,

    input  wire [DDR_CH-1:0]                          ddr_status,

    /*
     * HBM
     */
    input  wire [HBM_CH-1:0]                          hbm_clk,
    input  wire [HBM_CH-1:0]                          hbm_rst,

    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]         m_axi_hbm_awid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]       m_axi_hbm_awaddr,
    output wire [HBM_CH*8-1:0]                        m_axi_hbm_awlen,
    output wire [HBM_CH*3-1:0]                        m_axi_hbm_awsize,
    output wire [HBM_CH*2-1:0]                        m_axi_hbm_awburst,
    output wire [HBM_CH-1:0]                          m_axi_hbm_awlock,
    output wire [HBM_CH*4-1:0]                        m_axi_hbm_awcache,
    output wire [HBM_CH*3-1:0]                        m_axi_hbm_awprot,
    output wire [HBM_CH*4-1:0]                        m_axi_hbm_awqos,
    output wire [HBM_CH*AXI_HBM_AWUSER_WIDTH-1:0]     m_axi_hbm_awuser,
    output wire [HBM_CH-1:0]                          m_axi_hbm_awvalid,
    input  wire [HBM_CH-1:0]                          m_axi_hbm_awready,
    output wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]       m_axi_hbm_wdata,
    output wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]       m_axi_hbm_wstrb,
    output wire [HBM_CH-1:0]                          m_axi_hbm_wlast,
    output wire [HBM_CH*AXI_HBM_WUSER_WIDTH-1:0]      m_axi_hbm_wuser,
    output wire [HBM_CH-1:0]                          m_axi_hbm_wvalid,
    input  wire [HBM_CH-1:0]                          m_axi_hbm_wready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]         m_axi_hbm_bid,
    input  wire [HBM_CH*2-1:0]                        m_axi_hbm_bresp,
    input  wire [HBM_CH*AXI_HBM_BUSER_WIDTH-1:0]      m_axi_hbm_buser,
    input  wire [HBM_CH-1:0]                          m_axi_hbm_bvalid,
    output wire [HBM_CH-1:0]                          m_axi_hbm_bready,
    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]         m_axi_hbm_arid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]       m_axi_hbm_araddr,
    output wire [HBM_CH*8-1:0]                        m_axi_hbm_arlen,
    output wire [HBM_CH*3-1:0]                        m_axi_hbm_arsize,
    output wire [HBM_CH*2-1:0]                        m_axi_hbm_arburst,
    output wire [HBM_CH-1:0]                          m_axi_hbm_arlock,
    output wire [HBM_CH*4-1:0]                        m_axi_hbm_arcache,
    output wire [HBM_CH*3-1:0]                        m_axi_hbm_arprot,
    output wire [HBM_CH*4-1:0]                        m_axi_hbm_arqos,
    output wire [HBM_CH*AXI_HBM_ARUSER_WIDTH-1:0]     m_axi_hbm_aruser,
    output wire [HBM_CH-1:0]                          m_axi_hbm_arvalid,
    input  wire [HBM_CH-1:0]                          m_axi_hbm_arready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]         m_axi_hbm_rid,
    input  wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]       m_axi_hbm_rdata,
    input  wire [HBM_CH*2-1:0]                        m_axi_hbm_rresp,
    input  wire [HBM_CH-1:0]                          m_axi_hbm_rlast,
    input  wire [HBM_CH*AXI_HBM_RUSER_WIDTH-1:0]      m_axi_hbm_ruser,
    input  wire [HBM_CH-1:0]                          m_axi_hbm_rvalid,
    output wire [HBM_CH-1:0]                          m_axi_hbm_rready,

    input  wire [HBM_CH-1:0]                          hbm_status,

    /*
     * Statistics increment input
     */
    input  wire [STAT_INC_WIDTH-1:0]                  s_axis_stat_tdata,
    input  wire [STAT_ID_WIDTH-1:0]                   s_axis_stat_tid,
    input  wire                                       s_axis_stat_tvalid,
    output wire                                       s_axis_stat_tready,

    /*
     * GPIO
     */
    input  wire [APP_GPIO_IN_WIDTH-1:0]               app_gpio_in,
    output wire [APP_GPIO_OUT_WIDTH-1:0]              app_gpio_out,

    /*
     * JTAG
     */
    input  wire                                       app_jtag_tdi,
    output wire                                       app_jtag_tdo,
    input  wire                                       app_jtag_tms,
    input  wire                                       app_jtag_tck
);

parameter DMA_ADDR_WIDTH = AXI_ADDR_WIDTH;

parameter IF_RAM_SEL_WIDTH = 1;
parameter RAM_SEL_WIDTH = $clog2(IF_COUNT+(APP_ENABLE && APP_DMA_ENABLE ? 1 : 0))+IF_RAM_SEL_WIDTH+1;
parameter RAM_SEG_COUNT = 2;
parameter RAM_SEG_DATA_WIDTH = AXI_DATA_WIDTH*2/RAM_SEG_COUNT;
parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8;
parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH);

parameter IRQ_INDEX_WIDTH = $clog2(IRQ_COUNT);

// DMA connections
wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_done;
wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_ready;

// Interrupts
wire [IRQ_INDEX_WIDTH-1:0]  irq_index;
wire                        irq_valid;
wire                        irq_ready;

reg [IRQ_COUNT-1:0] irq_reg;

always @(posedge clk) begin
    irq_reg <= 0;

    if (irq_valid) begin
        irq_reg <= 1 << irq_index;
    end
end

assign irq = irq_reg;
assign irq_ready = 1'b1;

// DMA control
wire [DMA_ADDR_WIDTH-1:0]  dma_read_desc_dma_addr;
wire [RAM_SEL_WIDTH-1:0]   dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   dma_read_desc_len;
wire [DMA_TAG_WIDTH-1:0]   dma_read_desc_tag;
wire                       dma_read_desc_valid;
wire                       dma_read_desc_ready;

wire [DMA_TAG_WIDTH-1:0]   dma_read_desc_status_tag;
wire [3:0]                 dma_read_desc_status_error;
wire                       dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  dma_write_desc_dma_addr;
wire [RAM_SEL_WIDTH-1:0]   dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  dma_write_desc_ram_addr;
wire [DMA_IMM_WIDTH-1:0]   dma_write_desc_imm;
wire                       dma_write_desc_imm_en;
wire [DMA_LEN_WIDTH-1:0]   dma_write_desc_len;
wire [DMA_TAG_WIDTH-1:0]   dma_write_desc_tag;
wire                       dma_write_desc_valid;
wire                       dma_write_desc_ready;

wire [DMA_TAG_WIDTH-1:0]   dma_write_desc_status_tag;
wire [3:0]                 dma_write_desc_status_error;
wire                       dma_write_desc_status_valid;

wire                       dma_enable = 1;

wire [$clog2(AXI_DMA_READ_OP_TABLE_SIZE)-1:0] stat_rd_op_start_tag;
wire [DMA_LEN_WIDTH-1:0] stat_rd_op_start_len;
wire stat_rd_op_start_valid;
wire [$clog2(AXI_DMA_READ_OP_TABLE_SIZE)-1:0] stat_rd_op_finish_tag;
wire [3:0] stat_rd_op_finish_status;
wire stat_rd_op_finish_valid;
wire [$clog2(AXI_DMA_READ_OP_TABLE_SIZE)-1:0] stat_rd_req_start_tag;
wire [12:0] stat_rd_req_start_len;
wire stat_rd_req_start_valid;
wire [$clog2(AXI_DMA_READ_OP_TABLE_SIZE)-1:0] stat_rd_req_finish_tag;
wire [3:0] stat_rd_req_finish_status;
wire stat_rd_req_finish_valid;
wire stat_rd_op_table_full;
wire stat_rd_tx_stall;
wire [$clog2(AXI_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_op_start_tag;
wire [DMA_LEN_WIDTH-1:0] stat_wr_op_start_len;
wire stat_wr_op_start_valid;
wire [$clog2(AXI_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_op_finish_tag;
wire [3:0] stat_wr_op_finish_status;
wire stat_wr_op_finish_valid;
wire [$clog2(AXI_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_req_start_tag;
wire [12:0] stat_wr_req_start_len;
wire stat_wr_req_start_valid;
wire [$clog2(AXI_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_req_finish_tag;
wire [3:0] stat_wr_req_finish_status;
wire stat_wr_req_finish_valid;
wire stat_wr_op_table_full;
wire stat_wr_tx_stall;

dma_if_axi #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_DMA_MAX_BURST_LEN),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .IMM_ENABLE(DMA_IMM_ENABLE),
    .IMM_WIDTH(DMA_IMM_WIDTH),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .TAG_WIDTH(DMA_TAG_WIDTH),
    .READ_OP_TABLE_SIZE(AXI_DMA_READ_OP_TABLE_SIZE),
    .WRITE_OP_TABLE_SIZE(AXI_DMA_WRITE_OP_TABLE_SIZE),
    .READ_USE_AXI_ID(AXI_DMA_READ_USE_ID),
    .WRITE_USE_AXI_ID(AXI_DMA_WRITE_USE_ID)
)
dma_if_axi_inst (
    .clk(clk),
    .rst(rst),

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

    /*
     * AXI read descriptor input
     */
    .s_axis_read_desc_axi_addr(dma_read_desc_dma_addr),
    .s_axis_read_desc_ram_sel(dma_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(dma_read_desc_ram_addr),
    .s_axis_read_desc_len(dma_read_desc_len),
    .s_axis_read_desc_tag(dma_read_desc_tag),
    .s_axis_read_desc_valid(dma_read_desc_valid),
    .s_axis_read_desc_ready(dma_read_desc_ready),

    /*
     * AXI read descriptor status output
     */
    .m_axis_read_desc_status_tag(dma_read_desc_status_tag),
    .m_axis_read_desc_status_error(dma_read_desc_status_error),
    .m_axis_read_desc_status_valid(dma_read_desc_status_valid),

    /*
     * AXI write descriptor input
     */
    .s_axis_write_desc_axi_addr(dma_write_desc_dma_addr),
    .s_axis_write_desc_ram_sel(dma_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(dma_write_desc_ram_addr),
    .s_axis_write_desc_imm(dma_write_desc_imm),
    .s_axis_write_desc_imm_en(dma_write_desc_imm_en),
    .s_axis_write_desc_len(dma_write_desc_len),
    .s_axis_write_desc_tag(dma_write_desc_tag),
    .s_axis_write_desc_valid(dma_write_desc_valid),
    .s_axis_write_desc_ready(dma_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_tag(dma_write_desc_status_tag),
    .m_axis_write_desc_status_error(dma_write_desc_status_error),
    .m_axis_write_desc_status_valid(dma_write_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .ram_wr_done(dma_ram_wr_done),
    .ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .ram_rd_resp_data(dma_ram_rd_resp_data),
    .ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * Configuration
     */
    .read_enable(dma_enable),
    .write_enable(dma_enable),

    /*
     * Statistics
     */
    .stat_rd_op_start_tag(stat_rd_op_start_tag),
    .stat_rd_op_start_len(stat_rd_op_start_len),
    .stat_rd_op_start_valid(stat_rd_op_start_valid),
    .stat_rd_op_finish_tag(stat_rd_op_finish_tag),
    .stat_rd_op_finish_status(stat_rd_op_finish_status),
    .stat_rd_op_finish_valid(stat_rd_op_finish_valid),
    .stat_rd_req_start_tag(stat_rd_req_start_tag),
    .stat_rd_req_start_len(stat_rd_req_start_len),
    .stat_rd_req_start_valid(stat_rd_req_start_valid),
    .stat_rd_req_finish_tag(stat_rd_req_finish_tag),
    .stat_rd_req_finish_status(stat_rd_req_finish_status),
    .stat_rd_req_finish_valid(stat_rd_req_finish_valid),
    .stat_rd_op_table_full(stat_rd_op_table_full),
    .stat_rd_tx_stall(stat_rd_tx_stall),
    .stat_wr_op_start_tag(stat_wr_op_start_tag),
    .stat_wr_op_start_len(stat_wr_op_start_len),
    .stat_wr_op_start_valid(stat_wr_op_start_valid),
    .stat_wr_op_finish_tag(stat_wr_op_finish_tag),
    .stat_wr_op_finish_status(stat_wr_op_finish_status),
    .stat_wr_op_finish_valid(stat_wr_op_finish_valid),
    .stat_wr_req_start_tag(stat_wr_req_start_tag),
    .stat_wr_req_start_len(stat_wr_req_start_len),
    .stat_wr_req_start_valid(stat_wr_req_start_valid),
    .stat_wr_req_finish_tag(stat_wr_req_finish_tag),
    .stat_wr_req_finish_status(stat_wr_req_finish_status),
    .stat_wr_req_finish_valid(stat_wr_req_finish_valid),
    .stat_wr_op_table_full(stat_wr_op_table_full),
    .stat_wr_tx_stall(stat_wr_tx_stall)
);

wire [STAT_INC_WIDTH-1:0]  axis_stat_tdata;
wire [STAT_ID_WIDTH-1:0]   axis_stat_tid;
wire                       axis_stat_tvalid;
wire                       axis_stat_tready;

wire [STAT_INC_WIDTH-1:0]  axis_stat_axi_tdata = 0;
wire [STAT_ID_WIDTH-1:0]   axis_stat_axi_tid = 0;
wire                       axis_stat_axi_tvalid = 0;
wire                       axis_stat_axi_tready;

wire [STAT_INC_WIDTH-1:0]  axis_stat_dma_tdata;
wire [STAT_ID_WIDTH-1:0]   axis_stat_dma_tid;
wire                       axis_stat_dma_tvalid;
wire                       axis_stat_dma_tready;

generate

if (STAT_ENABLE && STAT_DMA_ENABLE) begin : stats_dma_if_axi

    stats_dma_if_axi #(
        .LEN_WIDTH(DMA_LEN_WIDTH),
        .READ_OP_TABLE_SIZE(AXI_DMA_READ_OP_TABLE_SIZE),
        .WRITE_OP_TABLE_SIZE(AXI_DMA_WRITE_OP_TABLE_SIZE),
        .STAT_INC_WIDTH(STAT_INC_WIDTH),
        .STAT_ID_WIDTH(5),
        .UPDATE_PERIOD(1024)
    )
    stats_dma_if_axi_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Statistics from dma_if_axi
         */
        .stat_rd_op_start_tag(stat_rd_op_start_tag),
        .stat_rd_op_start_len(stat_rd_op_start_len),
        .stat_rd_op_start_valid(stat_rd_op_start_valid),
        .stat_rd_op_finish_tag(stat_rd_op_finish_tag),
        .stat_rd_op_finish_status(stat_rd_op_finish_status),
        .stat_rd_op_finish_valid(stat_rd_op_finish_valid),
        .stat_rd_req_start_tag(stat_rd_req_start_tag),
        .stat_rd_req_start_len(stat_rd_req_start_len),
        .stat_rd_req_start_valid(stat_rd_req_start_valid),
        .stat_rd_req_finish_tag(stat_rd_req_finish_tag),
        .stat_rd_req_finish_status(stat_rd_req_finish_status),
        .stat_rd_req_finish_valid(stat_rd_req_finish_valid),
        .stat_rd_op_table_full(stat_rd_op_table_full),
        .stat_rd_tx_stall(stat_rd_tx_stall),
        .stat_wr_op_start_tag(stat_wr_op_start_tag),
        .stat_wr_op_start_len(stat_wr_op_start_len),
        .stat_wr_op_start_valid(stat_wr_op_start_valid),
        .stat_wr_op_finish_tag(stat_wr_op_finish_tag),
        .stat_wr_op_finish_status(stat_wr_op_finish_status),
        .stat_wr_op_finish_valid(stat_wr_op_finish_valid),
        .stat_wr_req_start_tag(stat_wr_req_start_tag),
        .stat_wr_req_start_len(stat_wr_req_start_len),
        .stat_wr_req_start_valid(stat_wr_req_start_valid),
        .stat_wr_req_finish_tag(stat_wr_req_finish_tag),
        .stat_wr_req_finish_status(stat_wr_req_finish_status),
        .stat_wr_req_finish_valid(stat_wr_req_finish_valid),
        .stat_wr_op_table_full(stat_wr_op_table_full),
        .stat_wr_tx_stall(stat_wr_tx_stall),

        /*
         * Statistics output
         */
        .m_axis_stat_tdata(axis_stat_dma_tdata),
        .m_axis_stat_tid(axis_stat_dma_tid[4:0]),
        .m_axis_stat_tvalid(axis_stat_dma_tvalid),
        .m_axis_stat_tready(axis_stat_dma_tready),

        /*
         * Control inputs
         */
        .update(1'b0)
    );

    assign axis_stat_dma_tid[STAT_ID_WIDTH-1:5] = 1;

end else begin

    assign axis_stat_dma_tdata = 0;
    assign axis_stat_dma_tid = 0;
    assign axis_stat_dma_tvalid = 0;

end

if (STAT_ENABLE && (STAT_DMA_ENABLE || STAT_AXI_ENABLE)) begin : stats_mux

    axis_arb_mux #(
        .S_COUNT(3),
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
        .s_axis_tdata({axis_stat_dma_tdata, axis_stat_axi_tdata, s_axis_stat_tdata}),
        .s_axis_tkeep(0),
        .s_axis_tvalid({axis_stat_dma_tvalid, axis_stat_axi_tvalid, s_axis_stat_tvalid}),
        .s_axis_tready({axis_stat_dma_tready, axis_stat_axi_tready, s_axis_stat_tready}),
        .s_axis_tlast(0),
        .s_axis_tid({axis_stat_dma_tid, axis_stat_axi_tid, s_axis_stat_tid}),
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

end

endgenerate

mqnic_core #(
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
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .IF_RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // Interrupt configuration
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),
    .MSIX_ENABLE(0),

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
    .AXIL_APP_CTRL_STRB_WIDTH(AXIL_APP_CTRL_STRB_WIDTH),

    // Ethernet interface configuration
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_SYNC_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .AXIS_IF_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .AXIS_TX_USER_WIDTH(AXIS_TX_USER_WIDTH),
    .AXIS_RX_USER_WIDTH(AXIS_RX_USER_WIDTH),
    .AXIS_RX_USE_READY(AXIS_RX_USE_READY),
    .AXIS_TX_PIPELINE(AXIS_TX_PIPELINE),
    .AXIS_TX_FIFO_PIPELINE(AXIS_TX_FIFO_PIPELINE),
    .AXIS_TX_TS_PIPELINE(AXIS_TX_TS_PIPELINE),
    .AXIS_RX_PIPELINE(AXIS_RX_PIPELINE),
    .AXIS_RX_FIFO_PIPELINE(AXIS_RX_FIFO_PIPELINE),

    // Statistics counter subsystem
    .STAT_ENABLE(STAT_ENABLE),
    .STAT_INC_WIDTH(STAT_INC_WIDTH),
    .STAT_ID_WIDTH(STAT_ID_WIDTH)
)
core_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA read descriptor output
     */
    .m_axis_dma_read_desc_dma_addr(dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_sel(dma_read_desc_ram_sel),
    .m_axis_dma_read_desc_ram_addr(dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(dma_read_desc_len),
    .m_axis_dma_read_desc_tag(dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(dma_read_desc_ready),

    /*
     * DMA read descriptor status input
     */
    .s_axis_dma_read_desc_status_tag(dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(dma_read_desc_status_valid),

    /*
     * DMA write descriptor output
     */
    .m_axis_dma_write_desc_dma_addr(dma_write_desc_dma_addr),
    .m_axis_dma_write_desc_ram_sel(dma_write_desc_ram_sel),
    .m_axis_dma_write_desc_ram_addr(dma_write_desc_ram_addr),
    .m_axis_dma_write_desc_imm(dma_write_desc_imm),
    .m_axis_dma_write_desc_imm_en(dma_write_desc_imm_en),
    .m_axis_dma_write_desc_len(dma_write_desc_len),
    .m_axis_dma_write_desc_tag(dma_write_desc_tag),
    .m_axis_dma_write_desc_valid(dma_write_desc_valid),
    .m_axis_dma_write_desc_ready(dma_write_desc_ready),

    /*
     * DMA write descriptor status input
     */
    .s_axis_dma_write_desc_status_tag(dma_write_desc_status_tag),
    .s_axis_dma_write_desc_status_error(dma_write_desc_status_error),
    .s_axis_dma_write_desc_status_valid(dma_write_desc_status_valid),

    /*
     * AXI-Lite slave interface (control)
     */
    .s_axil_ctrl_awaddr(s_axil_ctrl_awaddr),
    .s_axil_ctrl_awprot(s_axil_ctrl_awprot),
    .s_axil_ctrl_awvalid(s_axil_ctrl_awvalid),
    .s_axil_ctrl_awready(s_axil_ctrl_awready),
    .s_axil_ctrl_wdata(s_axil_ctrl_wdata),
    .s_axil_ctrl_wstrb(s_axil_ctrl_wstrb),
    .s_axil_ctrl_wvalid(s_axil_ctrl_wvalid),
    .s_axil_ctrl_wready(s_axil_ctrl_wready),
    .s_axil_ctrl_bresp(s_axil_ctrl_bresp),
    .s_axil_ctrl_bvalid(s_axil_ctrl_bvalid),
    .s_axil_ctrl_bready(s_axil_ctrl_bready),
    .s_axil_ctrl_araddr(s_axil_ctrl_araddr),
    .s_axil_ctrl_arprot(s_axil_ctrl_arprot),
    .s_axil_ctrl_arvalid(s_axil_ctrl_arvalid),
    .s_axil_ctrl_arready(s_axil_ctrl_arready),
    .s_axil_ctrl_rdata(s_axil_ctrl_rdata),
    .s_axil_ctrl_rresp(s_axil_ctrl_rresp),
    .s_axil_ctrl_rvalid(s_axil_ctrl_rvalid),
    .s_axil_ctrl_rready(s_axil_ctrl_rready),

    /*
     * AXI-Lite slave interface (application control)
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
     * RAM interface
     */
    .dma_ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .dma_ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .dma_ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .dma_ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .dma_ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .dma_ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .dma_ram_wr_done(dma_ram_wr_done),
    .dma_ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .dma_ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .dma_ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .dma_ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .dma_ram_rd_resp_data(dma_ram_rd_resp_data),
    .dma_ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .dma_ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * Interrupt request output
     */
    .irq_index(irq_index),
    .irq_valid(irq_valid),
    .irq_ready(irq_ready),

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
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),

    .tx_ptp_clk(tx_ptp_clk),
    .tx_ptp_rst(tx_ptp_rst),
    .tx_ptp_ts_96(tx_ptp_ts_96),
    .tx_ptp_ts_step(tx_ptp_ts_step),

    .m_axis_tx_tdata(m_axis_tx_tdata),
    .m_axis_tx_tkeep(m_axis_tx_tkeep),
    .m_axis_tx_tvalid(m_axis_tx_tvalid),
    .m_axis_tx_tready(m_axis_tx_tready),
    .m_axis_tx_tlast(m_axis_tx_tlast),
    .m_axis_tx_tuser(m_axis_tx_tuser),

    .s_axis_tx_cpl_ts(s_axis_tx_cpl_ts),
    .s_axis_tx_cpl_tag(s_axis_tx_cpl_tag),
    .s_axis_tx_cpl_valid(s_axis_tx_cpl_valid),
    .s_axis_tx_cpl_ready(s_axis_tx_cpl_ready),

    .tx_status(tx_status),

    .rx_clk(rx_clk),
    .rx_rst(rx_rst),

    .rx_ptp_clk(rx_ptp_clk),
    .rx_ptp_rst(rx_ptp_rst),
    .rx_ptp_ts_96(rx_ptp_ts_96),
    .rx_ptp_ts_step(rx_ptp_ts_step),

    .s_axis_rx_tdata(s_axis_rx_tdata),
    .s_axis_rx_tkeep(s_axis_rx_tkeep),
    .s_axis_rx_tvalid(s_axis_rx_tvalid),
    .s_axis_rx_tready(s_axis_rx_tready),
    .s_axis_rx_tlast(s_axis_rx_tlast),
    .s_axis_rx_tuser(s_axis_rx_tuser),

    .rx_status(rx_status),

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
    .s_axis_stat_tdata(axis_stat_tdata),
    .s_axis_stat_tid(axis_stat_tid),
    .s_axis_stat_tvalid(axis_stat_tvalid),
    .s_axis_stat_tready(axis_stat_tready),

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
