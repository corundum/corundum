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
 * FPGA core logic
 */
module fpga_core #
(
    // FW and board IDs
    parameter FPGA_ID = 32'hC32450DD,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h1172_A00D,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd1563227611,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

    // Structural configuration
    parameter IF_COUNT = 2,
    parameter PORTS_PER_IF = 1,
    parameter SCHED_PER_IF = PORTS_PER_IF,
    parameter PORT_MASK = 0,

    // Clock configuration
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,

    // PTP configuration
    parameter PTP_CLK_PERIOD_NS_NUM = 4096,
    parameter PTP_CLK_PERIOD_NS_DENOM = 825,
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_USE_SAMPLE_CLOCK = 1,
    parameter PTP_SEPARATE_TX_CLOCK = 1,
    parameter PTP_SEPARATE_RX_CLOCK = 1,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 1,
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
    parameter TX_CPL_FIFO_DEPTH = 32,
    parameter TX_TAG_WIDTH = 16,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter ENABLE_PADDING = 1,
    parameter ENABLE_DIC = 1,
    parameter MIN_FRAME_LENGTH = 64,
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

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter SEG_COUNT = 2,
    parameter SEG_DATA_WIDTH = 256,
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    parameter SEG_HDR_WIDTH = 128,
    parameter SEG_PRFX_WIDTH = 32,
    parameter TX_SEQ_NUM_WIDTH = 6,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 256,

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = EVENT_QUEUE_INDEX_WIDTH,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
    parameter AXIS_ETH_DATA_WIDTH = 64,
    parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8,
    parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH*2,
    parameter AXIS_ETH_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
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
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    input  wire                                  clk_250mhz,
    input  wire                                  rst_250mhz,

    /*
     * PTP clock
     */
    input  wire                                  ptp_clk,
    input  wire                                  ptp_rst,
    input  wire                                  ptp_sample_clk,

    /*
     * GPIO
     */
    input  wire                                  user_pb,
    output wire [3:0]                            user_led_g,

    /*
     * P-Tile interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]  rx_st_empty,
    input  wire [SEG_COUNT-1:0]                  rx_st_sop,
    input  wire [SEG_COUNT-1:0]                  rx_st_eop,
    input  wire [SEG_COUNT-1:0]                  rx_st_valid,
    output wire                                  rx_st_ready,
    input  wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    rx_st_hdr,
    input  wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   rx_st_tlp_prfx,
    input  wire [SEG_COUNT-1:0]                  rx_st_vf_active,
    input  wire [SEG_COUNT*3-1:0]                rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]               rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                rx_st_bar_range,
    input  wire [SEG_COUNT-1:0]                  rx_st_tlp_abort,

    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   tx_st_data,
    output wire [SEG_COUNT-1:0]                  tx_st_sop,
    output wire [SEG_COUNT-1:0]                  tx_st_eop,
    output wire [SEG_COUNT-1:0]                  tx_st_valid,
    input  wire                                  tx_st_ready,
    output wire [SEG_COUNT-1:0]                  tx_st_err,
    output wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    tx_st_hdr,
    output wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   tx_st_tlp_prfx,

    output wire [11:0]                           rx_buffer_limit,
    output wire [1:0]                            rx_buffer_limit_tdm_idx,

    input  wire [15:0]                           tx_cdts_limit,
    input  wire [2:0]                            tx_cdts_limit_tdm_idx,

    input  wire [15:0]                           tl_cfg_ctl,
    input  wire [4:0]                            tl_cfg_add,
    input  wire [2:0]                            tl_cfg_func,

    /*
     * Ethernet: QSFP28
     */
    input  wire                                  qsfp1_mac_1_tx_clk,
    input  wire                                  qsfp1_mac_1_tx_rst,

    input  wire                                  qsfp1_mac_1_tx_ptp_clk,
    input  wire                                  qsfp1_mac_1_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_1_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_1_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp1_mac_1_tx_ptp_ts_tag,
    input  wire                                  qsfp1_mac_1_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_1_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_1_tx_axis_tkeep,
    output wire                                  qsfp1_mac_1_tx_axis_tvalid,
    input  wire                                  qsfp1_mac_1_tx_axis_tready,
    output wire                                  qsfp1_mac_1_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp1_mac_1_tx_axis_tuser,

    input  wire                                  qsfp1_mac_1_rx_clk,
    input  wire                                  qsfp1_mac_1_rx_rst,

    input  wire                                  qsfp1_mac_1_rx_ptp_clk,
    input  wire                                  qsfp1_mac_1_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_1_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_1_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_1_rx_axis_tkeep,
    input  wire                                  qsfp1_mac_1_rx_axis_tvalid,
    input  wire                                  qsfp1_mac_1_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp1_mac_1_rx_axis_tuser,

    input  wire                                  qsfp1_mac_1_rx_status,

    input  wire                                  qsfp1_mac_2_tx_clk,
    input  wire                                  qsfp1_mac_2_tx_rst,

    input  wire                                  qsfp1_mac_2_tx_ptp_clk,
    input  wire                                  qsfp1_mac_2_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_2_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_2_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp1_mac_2_tx_ptp_ts_tag,
    input  wire                                  qsfp1_mac_2_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_2_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_2_tx_axis_tkeep,
    output wire                                  qsfp1_mac_2_tx_axis_tvalid,
    input  wire                                  qsfp1_mac_2_tx_axis_tready,
    output wire                                  qsfp1_mac_2_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp1_mac_2_tx_axis_tuser,

    input  wire                                  qsfp1_mac_2_rx_clk,
    input  wire                                  qsfp1_mac_2_rx_rst,

    input  wire                                  qsfp1_mac_2_rx_ptp_clk,
    input  wire                                  qsfp1_mac_2_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_2_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_2_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_2_rx_axis_tkeep,
    input  wire                                  qsfp1_mac_2_rx_axis_tvalid,
    input  wire                                  qsfp1_mac_2_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp1_mac_2_rx_axis_tuser,

    input  wire                                  qsfp1_mac_2_rx_status,

    input  wire                                  qsfp1_mac_3_tx_clk,
    input  wire                                  qsfp1_mac_3_tx_rst,

    input  wire                                  qsfp1_mac_3_tx_ptp_clk,
    input  wire                                  qsfp1_mac_3_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_3_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_3_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp1_mac_3_tx_ptp_ts_tag,
    input  wire                                  qsfp1_mac_3_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_3_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_3_tx_axis_tkeep,
    output wire                                  qsfp1_mac_3_tx_axis_tvalid,
    input  wire                                  qsfp1_mac_3_tx_axis_tready,
    output wire                                  qsfp1_mac_3_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp1_mac_3_tx_axis_tuser,

    input  wire                                  qsfp1_mac_3_rx_clk,
    input  wire                                  qsfp1_mac_3_rx_rst,

    input  wire                                  qsfp1_mac_3_rx_ptp_clk,
    input  wire                                  qsfp1_mac_3_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_3_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_3_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_3_rx_axis_tkeep,
    input  wire                                  qsfp1_mac_3_rx_axis_tvalid,
    input  wire                                  qsfp1_mac_3_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp1_mac_3_rx_axis_tuser,

    input  wire                                  qsfp1_mac_3_rx_status,

    input  wire                                  qsfp1_mac_4_tx_clk,
    input  wire                                  qsfp1_mac_4_tx_rst,

    input  wire                                  qsfp1_mac_4_tx_ptp_clk,
    input  wire                                  qsfp1_mac_4_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_4_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_4_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp1_mac_4_tx_ptp_ts_tag,
    input  wire                                  qsfp1_mac_4_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_4_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_4_tx_axis_tkeep,
    output wire                                  qsfp1_mac_4_tx_axis_tvalid,
    input  wire                                  qsfp1_mac_4_tx_axis_tready,
    output wire                                  qsfp1_mac_4_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp1_mac_4_tx_axis_tuser,

    input  wire                                  qsfp1_mac_4_rx_clk,
    input  wire                                  qsfp1_mac_4_rx_rst,

    input  wire                                  qsfp1_mac_4_rx_ptp_clk,
    input  wire                                  qsfp1_mac_4_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp1_mac_4_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp1_mac_4_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp1_mac_4_rx_axis_tkeep,
    input  wire                                  qsfp1_mac_4_rx_axis_tvalid,
    input  wire                                  qsfp1_mac_4_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp1_mac_4_rx_axis_tuser,

    input  wire                                  qsfp1_mac_4_rx_status,

    input  wire                                  qsfp2_mac_1_tx_clk,
    input  wire                                  qsfp2_mac_1_tx_rst,

    input  wire                                  qsfp2_mac_1_tx_ptp_clk,
    input  wire                                  qsfp2_mac_1_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_1_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_1_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp2_mac_1_tx_ptp_ts_tag,
    input  wire                                  qsfp2_mac_1_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_1_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_1_tx_axis_tkeep,
    output wire                                  qsfp2_mac_1_tx_axis_tvalid,
    input  wire                                  qsfp2_mac_1_tx_axis_tready,
    output wire                                  qsfp2_mac_1_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp2_mac_1_tx_axis_tuser,

    input  wire                                  qsfp2_mac_1_rx_clk,
    input  wire                                  qsfp2_mac_1_rx_rst,

    input  wire                                  qsfp2_mac_1_rx_ptp_clk,
    input  wire                                  qsfp2_mac_1_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_1_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_1_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_1_rx_axis_tkeep,
    input  wire                                  qsfp2_mac_1_rx_axis_tvalid,
    input  wire                                  qsfp2_mac_1_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp2_mac_1_rx_axis_tuser,

    input  wire                                  qsfp2_mac_1_rx_status,

    input  wire                                  qsfp2_mac_2_tx_clk,
    input  wire                                  qsfp2_mac_2_tx_rst,

    input  wire                                  qsfp2_mac_2_tx_ptp_clk,
    input  wire                                  qsfp2_mac_2_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_2_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_2_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp2_mac_2_tx_ptp_ts_tag,
    input  wire                                  qsfp2_mac_2_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_2_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_2_tx_axis_tkeep,
    output wire                                  qsfp2_mac_2_tx_axis_tvalid,
    input  wire                                  qsfp2_mac_2_tx_axis_tready,
    output wire                                  qsfp2_mac_2_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp2_mac_2_tx_axis_tuser,

    input  wire                                  qsfp2_mac_2_rx_clk,
    input  wire                                  qsfp2_mac_2_rx_rst,

    input  wire                                  qsfp2_mac_2_rx_ptp_clk,
    input  wire                                  qsfp2_mac_2_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_2_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_2_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_2_rx_axis_tkeep,
    input  wire                                  qsfp2_mac_2_rx_axis_tvalid,
    input  wire                                  qsfp2_mac_2_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp2_mac_2_rx_axis_tuser,

    input  wire                                  qsfp2_mac_2_rx_status,

    input  wire                                  qsfp2_mac_3_tx_clk,
    input  wire                                  qsfp2_mac_3_tx_rst,

    input  wire                                  qsfp2_mac_3_tx_ptp_clk,
    input  wire                                  qsfp2_mac_3_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_3_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_3_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp2_mac_3_tx_ptp_ts_tag,
    input  wire                                  qsfp2_mac_3_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_3_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_3_tx_axis_tkeep,
    output wire                                  qsfp2_mac_3_tx_axis_tvalid,
    input  wire                                  qsfp2_mac_3_tx_axis_tready,
    output wire                                  qsfp2_mac_3_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp2_mac_3_tx_axis_tuser,

    input  wire                                  qsfp2_mac_3_rx_clk,
    input  wire                                  qsfp2_mac_3_rx_rst,

    input  wire                                  qsfp2_mac_3_rx_ptp_clk,
    input  wire                                  qsfp2_mac_3_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_3_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_3_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_3_rx_axis_tkeep,
    input  wire                                  qsfp2_mac_3_rx_axis_tvalid,
    input  wire                                  qsfp2_mac_3_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp2_mac_3_rx_axis_tuser,

    input  wire                                  qsfp2_mac_3_rx_status,

    input  wire                                  qsfp2_mac_4_tx_clk,
    input  wire                                  qsfp2_mac_4_tx_rst,

    input  wire                                  qsfp2_mac_4_tx_ptp_clk,
    input  wire                                  qsfp2_mac_4_tx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_4_tx_ptp_time,

    input  wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_4_tx_ptp_ts,
    input  wire [TX_TAG_WIDTH-1:0]               qsfp2_mac_4_tx_ptp_ts_tag,
    input  wire                                  qsfp2_mac_4_tx_ptp_ts_valid,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_4_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_4_tx_axis_tkeep,
    output wire                                  qsfp2_mac_4_tx_axis_tvalid,
    input  wire                                  qsfp2_mac_4_tx_axis_tready,
    output wire                                  qsfp2_mac_4_tx_axis_tlast,
    output wire [AXIS_ETH_TX_USER_WIDTH-1:0]     qsfp2_mac_4_tx_axis_tuser,

    input  wire                                  qsfp2_mac_4_rx_clk,
    input  wire                                  qsfp2_mac_4_rx_rst,

    input  wire                                  qsfp2_mac_4_rx_ptp_clk,
    input  wire                                  qsfp2_mac_4_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]               qsfp2_mac_4_rx_ptp_time,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]        qsfp2_mac_4_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]        qsfp2_mac_4_rx_axis_tkeep,
    input  wire                                  qsfp2_mac_4_rx_axis_tvalid,
    input  wire                                  qsfp2_mac_4_rx_axis_tlast,
    input  wire [AXIS_ETH_RX_USER_WIDTH-1:0]     qsfp2_mac_4_rx_axis_tuser,

    input  wire                                  qsfp2_mac_4_rx_status
);

parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF;

parameter F_COUNT = PF_COUNT+VF_COUNT;

parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8);
parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT);
parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8);

localparam RB_BASE_ADDR = 16'h1000;
localparam RBB = RB_BASE_ADDR & {AXIL_CTRL_ADDR_WIDTH{1'b1}};

initial begin
    if (PORT_COUNT > 8) begin
        $error("Error: Max port count exceeded (instance %m)");
        $finish;
    end
end

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

// PTP
wire [PTP_TS_WIDTH-1:0]     ptp_ts_96;
wire                        ptp_ts_step;
wire                        ptp_pps;
wire                        ptp_pps_str;
wire [PTP_TS_WIDTH-1:0]     ptp_sync_ts_96;
wire                        ptp_sync_ts_step;
wire                        ptp_sync_pps;

wire [PTP_PEROUT_COUNT-1:0] ptp_perout_locked;
wire [PTP_PEROUT_COUNT-1:0] ptp_perout_error;
wire [PTP_PEROUT_COUNT-1:0] ptp_perout_pulse;

// control registers
wire [AXIL_CSR_ADDR_WIDTH-1:0]   ctrl_reg_wr_addr;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  ctrl_reg_wr_data;
wire [AXIL_CTRL_STRB_WIDTH-1:0]  ctrl_reg_wr_strb;
wire                             ctrl_reg_wr_en;
wire                             ctrl_reg_wr_wait;
wire                             ctrl_reg_wr_ack;
wire [AXIL_CSR_ADDR_WIDTH-1:0]   ctrl_reg_rd_addr;
wire                             ctrl_reg_rd_en;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  ctrl_reg_rd_data;
wire                             ctrl_reg_rd_wait;
wire                             ctrl_reg_rd_ack;

reg ctrl_reg_wr_ack_reg = 1'b0;
reg [AXIL_CTRL_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = {AXIL_CTRL_DATA_WIDTH{1'b0}};
reg ctrl_reg_rd_ack_reg = 1'b0;

reg qsfp0_reset_reg = 1'b0;
reg qsfp0_lp_mode_reg = 1'b0;
// reg qsfp0_i2c_scl_o_reg = 1'b1;
// reg qsfp0_i2c_sda_o_reg = 1'b1;

reg qsfp1_reset_reg = 1'b0;
reg qsfp1_lp_mode_reg = 1'b0;
// reg qsfp1_i2c_scl_o_reg = 1'b1;
// reg qsfp1_i2c_sda_o_reg = 1'b1;

// reg fpga_boot_reg = 1'b0;

// reg qspi_clk_reg = 1'b0;
// reg qspi_cs_reg = 1'b1;
// reg [3:0] qspi_dq_o_reg = 4'd0;
// reg [3:0] qspi_dq_oe_reg = 4'd0;

assign ctrl_reg_wr_wait = 1'b0;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_reg;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_reg;
assign ctrl_reg_rd_wait = 1'b0;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_reg;

// assign qsfp0_reset_n = !qsfp0_reset_reg;
// assign qsfp0_lp_mode = qsfp0_lp_mode_reg;
// assign qsfp0_i2c_scl_o = qsfp0_i2c_scl_o_reg;
// assign qsfp0_i2c_scl_t = qsfp0_i2c_scl_o_reg;
// assign qsfp0_i2c_sda_o = qsfp0_i2c_sda_o_reg;
// assign qsfp0_i2c_sda_t = qsfp0_i2c_sda_o_reg;

// assign qsfp1_reset_n = !qsfp1_reset_reg;
// assign qsfp1_lp_mode = qsfp1_lp_mode_reg;
// assign qsfp1_i2c_scl_o = qsfp1_i2c_scl_o_reg;
// assign qsfp1_i2c_scl_t = qsfp1_i2c_scl_o_reg;
// assign qsfp1_i2c_sda_o = qsfp1_i2c_sda_o_reg;
// assign qsfp1_i2c_sda_t = qsfp1_i2c_sda_o_reg;

// assign fpga_boot = fpga_boot_reg;

// assign qspi_clk = qspi_clk_reg;
// assign qspi_cs = qspi_cs_reg;
// assign qspi_dq_o = qspi_dq_o_reg;
// assign qspi_dq_oe = qspi_dq_oe_reg;

always @(posedge clk_250mhz) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_CTRL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b0;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            // 16'h0040: begin
            //     // FPGA ID
            //     fpga_boot_reg <= ctrl_reg_wr_data == 32'hFEE1DEAD;
            // end
            // GPIO
            // 16'h0110: begin
            //     // GPIO I2C 0
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qsfp0_i2c_scl_o_reg <= ctrl_reg_wr_data[1];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qsfp0_i2c_sda_o_reg <= ctrl_reg_wr_data[9];
            //     end
            // end
            // 16'h0114: begin
            //     // GPIO I2C 1
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qsfp1_i2c_scl_o_reg <= ctrl_reg_wr_data[1];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qsfp1_i2c_sda_o_reg <= ctrl_reg_wr_data[9];
            //     end
            // end
            // 16'h0120: begin
            //     // GPIO XCVR 0123
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qsfp0_reset_reg <= ctrl_reg_wr_data[4];
            //         qsfp0_lp_mode_reg <= ctrl_reg_wr_data[5];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qsfp1_reset_reg <= ctrl_reg_wr_data[12];
            //         qsfp1_lp_mode_reg <= ctrl_reg_wr_data[13];
            //     end
            // end
            // Flash
            // 16'h0144: begin
            //     // QSPI control
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qspi_dq_o_reg <= ctrl_reg_wr_data[3:0];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qspi_dq_oe_reg <= ctrl_reg_wr_data[11:8];
            //     end
            //     if (ctrl_reg_wr_strb[2]) begin
            //         qspi_clk_reg <= ctrl_reg_wr_data[16];
            //         qspi_cs_reg <= ctrl_reg_wr_data[17];
            //     end
            // end
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            // 16'h0040: ctrl_reg_rd_data_reg <= FPGA_ID; // FPGA ID
            // GPIO
            // 16'h0110: begin
            //     // GPIO I2C 0
            //     ctrl_reg_rd_data_reg[0] <= qsfp0_i2c_scl_i;
            //     ctrl_reg_rd_data_reg[1] <= qsfp0_i2c_scl_o_reg;
            //     ctrl_reg_rd_data_reg[8] <= qsfp0_i2c_sda_i;
            //     ctrl_reg_rd_data_reg[9] <= qsfp0_i2c_sda_o_reg;
            // end
            // 16'h0114: begin
            //     // GPIO I2C 1
            //     ctrl_reg_rd_data_reg[0] <= qsfp1_i2c_scl_i;
            //     ctrl_reg_rd_data_reg[1] <= qsfp1_i2c_scl_o_reg;
            //     ctrl_reg_rd_data_reg[8] <= qsfp1_i2c_sda_i;
            //     ctrl_reg_rd_data_reg[9] <= qsfp1_i2c_sda_o_reg;
            // end
            // 16'h0120: begin
            //     // GPIO XCVR 0123
            //     ctrl_reg_rd_data_reg[0] <= !qsfp0_mod_prsnt_n;
            //     ctrl_reg_rd_data_reg[1] <= !qsfp0_intr_n;
            //     ctrl_reg_rd_data_reg[4] <= qsfp0_reset_reg;
            //     ctrl_reg_rd_data_reg[5] <= qsfp0_lp_mode_reg;
            //     ctrl_reg_rd_data_reg[8] <= !qsfp1_mod_prsnt_n;
            //     ctrl_reg_rd_data_reg[9] <= !qsfp1_intr_n;
            //     ctrl_reg_rd_data_reg[12] <= qsfp1_reset_reg;
            //     ctrl_reg_rd_data_reg[13] <= qsfp1_lp_mode_reg;
            // end
            // Flash
            // 16'h0140: begin
            //     // Flash ID
            //     ctrl_reg_rd_data_reg[7:0]   <= 0; // type (SPI)
            //     ctrl_reg_rd_data_reg[15:8]  <= 1; // configuration (one segment)
            //     ctrl_reg_rd_data_reg[23:16] <= 4; // data width (QSPI)
            //     ctrl_reg_rd_data_reg[31:24] <= 0; // address width (N/A for SPI)
            // end
            // 16'h0144: begin
            //     // QSPI control
            //     ctrl_reg_rd_data_reg[3:0] <= qspi_dq_i;
            //     ctrl_reg_rd_data_reg[11:8] <= qspi_dq_oe;
            //     ctrl_reg_rd_data_reg[16] <= qspi_clk;
            //     ctrl_reg_rd_data_reg[17] <= qspi_cs;
            // end
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst_250mhz) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        qsfp0_reset_reg <= 1'b0;
        qsfp0_lp_mode_reg <= 1'b0;
        // qsfp0_i2c_scl_o_reg <= 1'b1;
        // qsfp0_i2c_sda_o_reg <= 1'b1;

        qsfp1_reset_reg <= 1'b0;
        qsfp1_lp_mode_reg <= 1'b0;
        // qsfp1_i2c_scl_o_reg <= 1'b1;
        // qsfp1_i2c_sda_o_reg <= 1'b1;

        // qspi_clk_reg <= 1'b0;
        // qspi_cs_reg <= 1'b1;
        // qspi_dq_o_reg <= 4'd0;
        // qspi_dq_oe_reg <= 4'd0;
    end
end

assign user_led_g[0] = 1'b0;
assign user_led_g[1] = 1'b0;
assign user_led_g[2] = 1'b0;
assign user_led_g[3] = ptp_pps_str;

wire [PORT_COUNT-1:0]                         eth_tx_clk;
wire [PORT_COUNT-1:0]                         eth_tx_rst;

wire [PORT_COUNT-1:0]                         eth_tx_ptp_clk;
wire [PORT_COUNT-1:0]                         eth_tx_ptp_rst;
wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_tx_ptp_ts_96;
wire [PORT_COUNT-1:0]                         eth_tx_ptp_ts_step;

wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     axis_eth_tx_tdata;
wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     axis_eth_tx_tkeep;
wire [PORT_COUNT-1:0]                         axis_eth_tx_tvalid;
wire [PORT_COUNT-1:0]                         axis_eth_tx_tready;
wire [PORT_COUNT-1:0]                         axis_eth_tx_tlast;
wire [PORT_COUNT*AXIS_ETH_TX_USER_WIDTH-1:0]  axis_eth_tx_tuser;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            axis_eth_tx_ptp_ts;
wire [PORT_COUNT*TX_TAG_WIDTH-1:0]            axis_eth_tx_ptp_ts_tag;
wire [PORT_COUNT-1:0]                         axis_eth_tx_ptp_ts_valid;
wire [PORT_COUNT-1:0]                         axis_eth_tx_ptp_ts_ready;

wire [PORT_COUNT-1:0]                         eth_tx_status;

wire [PORT_COUNT-1:0]                         eth_rx_clk;
wire [PORT_COUNT-1:0]                         eth_rx_rst;

wire [PORT_COUNT-1:0]                         eth_rx_ptp_clk;
wire [PORT_COUNT-1:0]                         eth_rx_ptp_rst;
wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_rx_ptp_ts_96;
wire [PORT_COUNT-1:0]                         eth_rx_ptp_ts_step;

wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     axis_eth_rx_tdata;
wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     axis_eth_rx_tkeep;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tvalid;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tready;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tlast;
wire [PORT_COUNT*AXIS_ETH_RX_USER_WIDTH-1:0]  axis_eth_rx_tuser;

wire [PORT_COUNT-1:0]                         eth_rx_status;

mqnic_port_map_mac_axis #(
    .MAC_COUNT(8),
    .PORT_MASK(PORT_MASK),
    .PORT_GROUP_SIZE(4),

    .IF_COUNT(IF_COUNT),
    .PORTS_PER_IF(PORTS_PER_IF),

    .PORT_COUNT(PORT_COUNT),

    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(TX_TAG_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .AXIS_TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .AXIS_RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH)
)
mqnic_port_map_mac_axis_inst (
    // towards MAC
    .mac_tx_clk({qsfp2_mac_4_tx_clk, qsfp2_mac_3_tx_clk, qsfp2_mac_2_tx_clk, qsfp2_mac_1_tx_clk, qsfp1_mac_4_tx_clk, qsfp1_mac_3_tx_clk, qsfp1_mac_2_tx_clk, qsfp1_mac_1_tx_clk}),
    .mac_tx_rst({qsfp2_mac_4_tx_rst, qsfp2_mac_3_tx_rst, qsfp2_mac_2_tx_rst, qsfp2_mac_1_tx_rst, qsfp1_mac_4_tx_rst, qsfp1_mac_3_tx_rst, qsfp1_mac_2_tx_rst, qsfp1_mac_1_tx_rst}),

    .mac_tx_ptp_clk({qsfp2_mac_4_tx_ptp_clk, qsfp2_mac_3_tx_ptp_clk, qsfp2_mac_2_tx_ptp_clk, qsfp2_mac_1_tx_ptp_clk, qsfp1_mac_4_tx_ptp_clk, qsfp1_mac_3_tx_ptp_clk, qsfp1_mac_2_tx_ptp_clk, qsfp1_mac_1_tx_ptp_clk}),
    .mac_tx_ptp_rst({qsfp2_mac_4_tx_ptp_rst, qsfp2_mac_3_tx_ptp_rst, qsfp2_mac_2_tx_ptp_rst, qsfp2_mac_1_tx_ptp_rst, qsfp1_mac_4_tx_ptp_rst, qsfp1_mac_3_tx_ptp_rst, qsfp1_mac_2_tx_ptp_rst, qsfp1_mac_1_tx_ptp_rst}),
    .mac_tx_ptp_ts_96({qsfp2_mac_4_tx_ptp_time, qsfp2_mac_3_tx_ptp_time, qsfp2_mac_2_tx_ptp_time, qsfp2_mac_1_tx_ptp_time, qsfp1_mac_4_tx_ptp_time, qsfp1_mac_3_tx_ptp_time, qsfp1_mac_2_tx_ptp_time, qsfp1_mac_1_tx_ptp_time}),
    .mac_tx_ptp_ts_step(),

    .m_axis_mac_tx_tdata({qsfp2_mac_4_tx_axis_tdata, qsfp2_mac_3_tx_axis_tdata, qsfp2_mac_2_tx_axis_tdata, qsfp2_mac_1_tx_axis_tdata, qsfp1_mac_4_tx_axis_tdata, qsfp1_mac_3_tx_axis_tdata, qsfp1_mac_2_tx_axis_tdata, qsfp1_mac_1_tx_axis_tdata}),
    .m_axis_mac_tx_tkeep({qsfp2_mac_4_tx_axis_tkeep, qsfp2_mac_3_tx_axis_tkeep, qsfp2_mac_2_tx_axis_tkeep, qsfp2_mac_1_tx_axis_tkeep, qsfp1_mac_4_tx_axis_tkeep, qsfp1_mac_3_tx_axis_tkeep, qsfp1_mac_2_tx_axis_tkeep, qsfp1_mac_1_tx_axis_tkeep}),
    .m_axis_mac_tx_tvalid({qsfp2_mac_4_tx_axis_tvalid, qsfp2_mac_3_tx_axis_tvalid, qsfp2_mac_2_tx_axis_tvalid, qsfp2_mac_1_tx_axis_tvalid, qsfp1_mac_4_tx_axis_tvalid, qsfp1_mac_3_tx_axis_tvalid, qsfp1_mac_2_tx_axis_tvalid, qsfp1_mac_1_tx_axis_tvalid}),
    .m_axis_mac_tx_tready({qsfp2_mac_4_tx_axis_tready, qsfp2_mac_3_tx_axis_tready, qsfp2_mac_2_tx_axis_tready, qsfp2_mac_1_tx_axis_tready, qsfp1_mac_4_tx_axis_tready, qsfp1_mac_3_tx_axis_tready, qsfp1_mac_2_tx_axis_tready, qsfp1_mac_1_tx_axis_tready}),
    .m_axis_mac_tx_tlast({qsfp2_mac_4_tx_axis_tlast, qsfp2_mac_3_tx_axis_tlast, qsfp2_mac_2_tx_axis_tlast, qsfp2_mac_1_tx_axis_tlast, qsfp1_mac_4_tx_axis_tlast, qsfp1_mac_3_tx_axis_tlast, qsfp1_mac_2_tx_axis_tlast, qsfp1_mac_1_tx_axis_tlast}),
    .m_axis_mac_tx_tuser({qsfp2_mac_4_tx_axis_tuser, qsfp2_mac_3_tx_axis_tuser, qsfp2_mac_2_tx_axis_tuser, qsfp2_mac_1_tx_axis_tuser, qsfp1_mac_4_tx_axis_tuser, qsfp1_mac_3_tx_axis_tuser, qsfp1_mac_2_tx_axis_tuser, qsfp1_mac_1_tx_axis_tuser}),

    .s_axis_mac_tx_ptp_ts({qsfp2_mac_4_tx_ptp_ts, qsfp2_mac_3_tx_ptp_ts, qsfp2_mac_2_tx_ptp_ts, qsfp2_mac_1_tx_ptp_ts, qsfp1_mac_4_tx_ptp_ts, qsfp1_mac_3_tx_ptp_ts, qsfp1_mac_2_tx_ptp_ts, qsfp1_mac_1_tx_ptp_ts}),
    .s_axis_mac_tx_ptp_ts_tag({qsfp2_mac_4_tx_ptp_ts_tag, qsfp2_mac_3_tx_ptp_ts_tag, qsfp2_mac_2_tx_ptp_ts_tag, qsfp2_mac_1_tx_ptp_ts_tag, qsfp1_mac_4_tx_ptp_ts_tag, qsfp1_mac_3_tx_ptp_ts_tag, qsfp1_mac_2_tx_ptp_ts_tag, qsfp1_mac_1_tx_ptp_ts_tag}),
    .s_axis_mac_tx_ptp_ts_valid({qsfp2_mac_4_tx_ptp_ts_valid, qsfp2_mac_3_tx_ptp_ts_valid, qsfp2_mac_2_tx_ptp_ts_valid, qsfp2_mac_1_tx_ptp_ts_valid, qsfp1_mac_4_tx_ptp_ts_valid, qsfp1_mac_3_tx_ptp_ts_valid, qsfp1_mac_2_tx_ptp_ts_valid, qsfp1_mac_1_tx_ptp_ts_valid}),
    .s_axis_mac_tx_ptp_ts_ready(),

    .mac_tx_status(8'hff),

    .mac_rx_clk({qsfp2_mac_4_rx_clk, qsfp2_mac_3_rx_clk, qsfp2_mac_2_rx_clk, qsfp2_mac_1_rx_clk, qsfp1_mac_4_rx_clk, qsfp1_mac_3_rx_clk, qsfp1_mac_2_rx_clk, qsfp1_mac_1_rx_clk}),
    .mac_rx_rst({qsfp2_mac_4_rx_rst, qsfp2_mac_3_rx_rst, qsfp2_mac_2_rx_rst, qsfp2_mac_1_rx_rst, qsfp1_mac_4_rx_rst, qsfp1_mac_3_rx_rst, qsfp1_mac_2_rx_rst, qsfp1_mac_1_rx_rst}),

    .mac_rx_ptp_clk({qsfp2_mac_4_rx_ptp_clk, qsfp2_mac_3_rx_ptp_clk, qsfp2_mac_2_rx_ptp_clk, qsfp2_mac_1_rx_ptp_clk, qsfp1_mac_4_rx_ptp_clk, qsfp1_mac_3_rx_ptp_clk, qsfp1_mac_2_rx_ptp_clk, qsfp1_mac_1_rx_ptp_clk}),
    .mac_rx_ptp_rst({qsfp2_mac_4_rx_ptp_rst, qsfp2_mac_3_rx_ptp_rst, qsfp2_mac_2_rx_ptp_rst, qsfp2_mac_1_rx_ptp_rst, qsfp1_mac_4_rx_ptp_rst, qsfp1_mac_3_rx_ptp_rst, qsfp1_mac_2_rx_ptp_rst, qsfp1_mac_1_rx_ptp_rst}),
    .mac_rx_ptp_ts_96({qsfp2_mac_4_rx_ptp_time, qsfp2_mac_3_rx_ptp_time, qsfp2_mac_2_rx_ptp_time, qsfp2_mac_1_rx_ptp_time, qsfp1_mac_4_rx_ptp_time, qsfp1_mac_3_rx_ptp_time, qsfp1_mac_2_rx_ptp_time, qsfp1_mac_1_rx_ptp_time}),
    .mac_rx_ptp_ts_step(),

    .s_axis_mac_rx_tdata({qsfp2_mac_4_rx_axis_tdata, qsfp2_mac_3_rx_axis_tdata, qsfp2_mac_2_rx_axis_tdata, qsfp2_mac_1_rx_axis_tdata, qsfp1_mac_4_rx_axis_tdata, qsfp1_mac_3_rx_axis_tdata, qsfp1_mac_2_rx_axis_tdata, qsfp1_mac_1_rx_axis_tdata}),
    .s_axis_mac_rx_tkeep({qsfp2_mac_4_rx_axis_tkeep, qsfp2_mac_3_rx_axis_tkeep, qsfp2_mac_2_rx_axis_tkeep, qsfp2_mac_1_rx_axis_tkeep, qsfp1_mac_4_rx_axis_tkeep, qsfp1_mac_3_rx_axis_tkeep, qsfp1_mac_2_rx_axis_tkeep, qsfp1_mac_1_rx_axis_tkeep}),
    .s_axis_mac_rx_tvalid({qsfp2_mac_4_rx_axis_tvalid, qsfp2_mac_3_rx_axis_tvalid, qsfp2_mac_2_rx_axis_tvalid, qsfp2_mac_1_rx_axis_tvalid, qsfp1_mac_4_rx_axis_tvalid, qsfp1_mac_3_rx_axis_tvalid, qsfp1_mac_2_rx_axis_tvalid, qsfp1_mac_1_rx_axis_tvalid}),
    .s_axis_mac_rx_tready(),
    .s_axis_mac_rx_tlast({qsfp2_mac_4_rx_axis_tlast, qsfp2_mac_3_rx_axis_tlast, qsfp2_mac_2_rx_axis_tlast, qsfp2_mac_1_rx_axis_tlast, qsfp1_mac_4_rx_axis_tlast, qsfp1_mac_3_rx_axis_tlast, qsfp1_mac_2_rx_axis_tlast, qsfp1_mac_1_rx_axis_tlast}),
    .s_axis_mac_rx_tuser({qsfp2_mac_4_rx_axis_tuser, qsfp2_mac_3_rx_axis_tuser, qsfp2_mac_2_rx_axis_tuser, qsfp2_mac_1_rx_axis_tuser, qsfp1_mac_4_rx_axis_tuser, qsfp1_mac_3_rx_axis_tuser, qsfp1_mac_2_rx_axis_tuser, qsfp1_mac_1_rx_axis_tuser}),

    .mac_rx_status({qsfp2_mac_4_rx_status, qsfp2_mac_3_rx_status, qsfp2_mac_2_rx_status, qsfp2_mac_1_rx_status, qsfp1_mac_4_rx_status, qsfp1_mac_3_rx_status, qsfp1_mac_2_rx_status, qsfp1_mac_1_rx_status}),

    // towards datapath
    .tx_clk(eth_tx_clk),
    .tx_rst(eth_tx_rst),

    .tx_ptp_clk(eth_tx_ptp_clk),
    .tx_ptp_rst(eth_tx_ptp_rst),
    .tx_ptp_ts_96(eth_tx_ptp_ts_96),
    .tx_ptp_ts_step(eth_tx_ptp_ts_step),

    .s_axis_tx_tdata(axis_eth_tx_tdata),
    .s_axis_tx_tkeep(axis_eth_tx_tkeep),
    .s_axis_tx_tvalid(axis_eth_tx_tvalid),
    .s_axis_tx_tready(axis_eth_tx_tready),
    .s_axis_tx_tlast(axis_eth_tx_tlast),
    .s_axis_tx_tuser(axis_eth_tx_tuser),

    .m_axis_tx_ptp_ts(axis_eth_tx_ptp_ts),
    .m_axis_tx_ptp_ts_tag(axis_eth_tx_ptp_ts_tag),
    .m_axis_tx_ptp_ts_valid(axis_eth_tx_ptp_ts_valid),
    .m_axis_tx_ptp_ts_ready(axis_eth_tx_ptp_ts_ready),

    .tx_status(eth_tx_status),

    .rx_clk(eth_rx_clk),
    .rx_rst(eth_rx_rst),

    .rx_ptp_clk(eth_rx_ptp_clk),
    .rx_ptp_rst(eth_rx_ptp_rst),
    .rx_ptp_ts_96(eth_rx_ptp_ts_96),
    .rx_ptp_ts_step(eth_rx_ptp_ts_step),

    .m_axis_rx_tdata(axis_eth_rx_tdata),
    .m_axis_rx_tkeep(axis_eth_rx_tkeep),
    .m_axis_rx_tvalid(axis_eth_rx_tvalid),
    .m_axis_rx_tready(axis_eth_rx_tready),
    .m_axis_rx_tlast(axis_eth_rx_tlast),
    .m_axis_rx_tuser(axis_eth_rx_tuser),

    .rx_status(eth_rx_status)
);

mqnic_core_pcie_ptile #(
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
    .TX_CPL_ENABLE(PTP_TS_ENABLE),
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
    .DDR_ENABLE(0),
    .HBM_ENABLE(0),

    // Application block configuration
    .APP_ID(APP_ID),
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),
    .APP_GPIO_IN_WIDTH(32),
    .APP_GPIO_OUT_WIDTH(32),

    // DMA interface configuration
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // PCIe interface configuration
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .PF_COUNT(PF_COUNT),
    .VF_COUNT(VF_COUNT),
    .F_COUNT(F_COUNT),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),

    // Interrupt configuration
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .AXIL_IF_CTRL_ADDR_WIDTH(AXIL_IF_CTRL_ADDR_WIDTH),
    .AXIL_CSR_ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .AXIL_CSR_PASSTHROUGH_ENABLE(0),
    .RB_NEXT_PTR(RB_BASE_ADDR),

    // AXI lite interface configuration (application control)
    .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),

    // Ethernet interface configuration
    .AXIS_ETH_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_ETH_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .AXIS_ETH_SYNC_DATA_WIDTH(AXIS_ETH_SYNC_DATA_WIDTH),
    .AXIS_ETH_TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .AXIS_ETH_RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH),
    .AXIS_ETH_RX_USE_READY(0),
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
core_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

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
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    .m_axil_csr_awaddr(axil_csr_awaddr),
    .m_axil_csr_awprot(axil_csr_awprot),
    .m_axil_csr_awvalid(axil_csr_awvalid),
    .m_axil_csr_awready(axil_csr_awready),
    .m_axil_csr_wdata(axil_csr_wdata),
    .m_axil_csr_wstrb(axil_csr_wstrb),
    .m_axil_csr_wvalid(axil_csr_wvalid),
    .m_axil_csr_wready(axil_csr_wready),
    .m_axil_csr_bresp(axil_csr_bresp),
    .m_axil_csr_bvalid(axil_csr_bvalid),
    .m_axil_csr_bready(axil_csr_bready),
    .m_axil_csr_araddr(axil_csr_araddr),
    .m_axil_csr_arprot(axil_csr_arprot),
    .m_axil_csr_arvalid(axil_csr_arvalid),
    .m_axil_csr_arready(axil_csr_arready),
    .m_axil_csr_rdata(axil_csr_rdata),
    .m_axil_csr_rresp(axil_csr_rresp),
    .m_axil_csr_rvalid(axil_csr_rvalid),
    .m_axil_csr_rready(axil_csr_rready),

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
    .eth_tx_clk(eth_tx_clk),
    .eth_tx_rst(eth_tx_rst),

    .eth_tx_ptp_clk(eth_tx_ptp_clk),
    .eth_tx_ptp_rst(eth_tx_ptp_rst),
    .eth_tx_ptp_ts_96(eth_tx_ptp_ts_96),
    .eth_tx_ptp_ts_step(eth_tx_ptp_ts_step),

    .m_axis_eth_tx_tdata(axis_eth_tx_tdata),
    .m_axis_eth_tx_tkeep(axis_eth_tx_tkeep),
    .m_axis_eth_tx_tvalid(axis_eth_tx_tvalid),
    .m_axis_eth_tx_tready(axis_eth_tx_tready),
    .m_axis_eth_tx_tlast(axis_eth_tx_tlast),
    .m_axis_eth_tx_tuser(axis_eth_tx_tuser),

    .s_axis_eth_tx_cpl_ts(axis_eth_tx_ptp_ts),
    .s_axis_eth_tx_cpl_tag(axis_eth_tx_ptp_ts_tag),
    .s_axis_eth_tx_cpl_valid(axis_eth_tx_ptp_ts_valid),
    .s_axis_eth_tx_cpl_ready(axis_eth_tx_ptp_ts_ready),

    .eth_tx_status(eth_tx_status),

    .eth_rx_clk(eth_rx_clk),
    .eth_rx_rst(eth_rx_rst),

    .eth_rx_ptp_clk(eth_rx_ptp_clk),
    .eth_rx_ptp_rst(eth_rx_ptp_rst),
    .eth_rx_ptp_ts_96(eth_rx_ptp_ts_96),
    .eth_rx_ptp_ts_step(eth_rx_ptp_ts_step),

    .s_axis_eth_rx_tdata(axis_eth_rx_tdata),
    .s_axis_eth_rx_tkeep(axis_eth_rx_tkeep),
    .s_axis_eth_rx_tvalid(axis_eth_rx_tvalid),
    .s_axis_eth_rx_tready(axis_eth_rx_tready),
    .s_axis_eth_rx_tlast(axis_eth_rx_tlast),
    .s_axis_eth_rx_tuser(axis_eth_rx_tuser),

    .eth_rx_status(eth_rx_status),

    /*
     * DDR
     */
    .ddr_clk(0),
    .ddr_rst(0),

    .m_axi_ddr_awid(),
    .m_axi_ddr_awaddr(),
    .m_axi_ddr_awlen(),
    .m_axi_ddr_awsize(),
    .m_axi_ddr_awburst(),
    .m_axi_ddr_awlock(),
    .m_axi_ddr_awcache(),
    .m_axi_ddr_awprot(),
    .m_axi_ddr_awqos(),
    .m_axi_ddr_awuser(),
    .m_axi_ddr_awvalid(),
    .m_axi_ddr_awready(0),
    .m_axi_ddr_wdata(),
    .m_axi_ddr_wstrb(),
    .m_axi_ddr_wlast(),
    .m_axi_ddr_wuser(),
    .m_axi_ddr_wvalid(),
    .m_axi_ddr_wready(0),
    .m_axi_ddr_bid(0),
    .m_axi_ddr_bresp(0),
    .m_axi_ddr_buser(0),
    .m_axi_ddr_bvalid(0),
    .m_axi_ddr_bready(),
    .m_axi_ddr_arid(),
    .m_axi_ddr_araddr(),
    .m_axi_ddr_arlen(),
    .m_axi_ddr_arsize(),
    .m_axi_ddr_arburst(),
    .m_axi_ddr_arlock(),
    .m_axi_ddr_arcache(),
    .m_axi_ddr_arprot(),
    .m_axi_ddr_arqos(),
    .m_axi_ddr_aruser(),
    .m_axi_ddr_arvalid(),
    .m_axi_ddr_arready(0),
    .m_axi_ddr_rid(0),
    .m_axi_ddr_rdata(0),
    .m_axi_ddr_rresp(0),
    .m_axi_ddr_rlast(0),
    .m_axi_ddr_ruser(0),
    .m_axi_ddr_rvalid(0),
    .m_axi_ddr_rready(),

    .ddr_status(0),

    /*
     * HBM
     */
    .hbm_clk(0),
    .hbm_rst(0),

    .m_axi_hbm_awid(),
    .m_axi_hbm_awaddr(),
    .m_axi_hbm_awlen(),
    .m_axi_hbm_awsize(),
    .m_axi_hbm_awburst(),
    .m_axi_hbm_awlock(),
    .m_axi_hbm_awcache(),
    .m_axi_hbm_awprot(),
    .m_axi_hbm_awqos(),
    .m_axi_hbm_awuser(),
    .m_axi_hbm_awvalid(),
    .m_axi_hbm_awready(0),
    .m_axi_hbm_wdata(),
    .m_axi_hbm_wstrb(),
    .m_axi_hbm_wlast(),
    .m_axi_hbm_wuser(),
    .m_axi_hbm_wvalid(),
    .m_axi_hbm_wready(0),
    .m_axi_hbm_bid(0),
    .m_axi_hbm_bresp(0),
    .m_axi_hbm_buser(0),
    .m_axi_hbm_bvalid(0),
    .m_axi_hbm_bready(),
    .m_axi_hbm_arid(),
    .m_axi_hbm_araddr(),
    .m_axi_hbm_arlen(),
    .m_axi_hbm_arsize(),
    .m_axi_hbm_arburst(),
    .m_axi_hbm_arlock(),
    .m_axi_hbm_arcache(),
    .m_axi_hbm_arprot(),
    .m_axi_hbm_arqos(),
    .m_axi_hbm_aruser(),
    .m_axi_hbm_arvalid(),
    .m_axi_hbm_arready(0),
    .m_axi_hbm_rid(0),
    .m_axi_hbm_rdata(0),
    .m_axi_hbm_rresp(0),
    .m_axi_hbm_rlast(0),
    .m_axi_hbm_ruser(0),
    .m_axi_hbm_rvalid(0),
    .m_axi_hbm_rready(),

    .hbm_status(0),

    /*
     * Statistics input
     */
    .s_axis_stat_tdata(0),
    .s_axis_stat_tid(0),
    .s_axis_stat_tvalid(1'b0),
    .s_axis_stat_tready(),

    /*
     * GPIO
     */
    .app_gpio_in(0),
    .app_gpio_out(),

    /*
     * JTAG
     */
    .app_jtag_tdi(1'b0),
    .app_jtag_tdo(),
    .app_jtag_tms(1'b0),
    .app_jtag_tck(1'b0)
);

endmodule

`resetall
