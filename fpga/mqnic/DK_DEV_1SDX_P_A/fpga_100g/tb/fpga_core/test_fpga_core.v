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
    parameter FPGA_ID = 32'hC32450DD,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h1172_A00D,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd1563227611,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

    // Board configuration
    parameter QSFP_CNT = 2,
    parameter CH_CNT = QSFP_CNT,
    parameter PORT_GROUP_SIZE = 2,

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
    parameter PTP_SEPARATE_TX_CLOCK = 0,
    parameter PTP_SEPARATE_RX_CLOCK = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 1,
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
    parameter TX_CPL_FIFO_DEPTH = 32,
    parameter TX_TAG_WIDTH = 8,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter PFC_ENABLE = 1,
    parameter LFC_ENABLE = PFC_ENABLE,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 131072,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 131072,
    parameter RX_RAM_SIZE = 131072,

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
    parameter IRQ_INDEX_WIDTH = EQN_WIDTH,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
    parameter AXIS_ETH_DATA_WIDTH = 512,
    parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8,
    parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH,
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
    input  wire                                      clk_250mhz,
    input  wire                                      rst_250mhz,

    /*
     * PTP clock
     */
    input  wire                                      ptp_clk,
    input  wire                                      ptp_rst,
    input  wire                                      ptp_sample_clk,

    /*
     * GPIO
     */
    input  wire                                      user_pb,
    output wire [3:0]                                user_led_g,

    /*
     * I2C
     */
    input  wire                                      i2c2_scl_i,
    output wire                                      i2c2_scl_o,
    output wire                                      i2c2_scl_t,
    input  wire                                      i2c2_sda_i,
    output wire                                      i2c2_sda_o,
    output wire                                      i2c2_sda_t,
    output wire                                      bmc_i2c2_disable,

    /*
     * P-Tile interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]       rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]      rx_st_empty,
    input  wire [SEG_COUNT-1:0]                      rx_st_sop,
    input  wire [SEG_COUNT-1:0]                      rx_st_eop,
    input  wire [SEG_COUNT-1:0]                      rx_st_valid,
    output wire                                      rx_st_ready,
    input  wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]        rx_st_hdr,
    input  wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]       rx_st_tlp_prfx,
    input  wire [SEG_COUNT-1:0]                      rx_st_vf_active,
    input  wire [SEG_COUNT*3-1:0]                    rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]                   rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                    rx_st_bar_range,
    input  wire [SEG_COUNT-1:0]                      rx_st_tlp_abort,

    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]       tx_st_data,
    output wire [SEG_COUNT-1:0]                      tx_st_sop,
    output wire [SEG_COUNT-1:0]                      tx_st_eop,
    output wire [SEG_COUNT-1:0]                      tx_st_valid,
    input  wire                                      tx_st_ready,
    output wire [SEG_COUNT-1:0]                      tx_st_err,
    output wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]        tx_st_hdr,
    output wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]       tx_st_tlp_prfx,

    output wire [11:0]                               rx_buffer_limit,
    output wire [1:0]                                rx_buffer_limit_tdm_idx,

    input  wire [15:0]                               tx_cdts_limit,
    input  wire [2:0]                                tx_cdts_limit_tdm_idx,

    input  wire [15:0]                               tl_cfg_ctl,
    input  wire [4:0]                                tl_cfg_add,
    input  wire [2:0]                                tl_cfg_func

    /*
     * Ethernet: QSFP28
     */
    // input  wire [CH_CNT-1:0]                         qsfp_mac_tx_clk,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_tx_rst,

    // output wire [CH_CNT*AXIS_ETH_DATA_WIDTH-1:0]     qsfp_mac_tx_axis_tdata,
    // output wire [CH_CNT*AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_mac_tx_axis_tkeep,
    // output wire [CH_CNT-1:0]                         qsfp_mac_tx_axis_tvalid,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_tx_axis_tready,
    // output wire [CH_CNT-1:0]                         qsfp_mac_tx_axis_tlast,
    // output wire [CH_CNT*AXIS_ETH_TX_USER_WIDTH-1:0]  qsfp_mac_tx_axis_tuser,

    // input  wire [CH_CNT-1:0]                         qsfp_mac_tx_ptp_clk,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_tx_ptp_rst,
    // output wire [CH_CNT*PTP_TS_WIDTH-1:0]            qsfp_mac_tx_ptp_time,

    // input  wire [CH_CNT*PTP_TS_WIDTH-1:0]            qsfp_mac_tx_ptp_ts,
    // input  wire [CH_CNT*TX_TAG_WIDTH-1:0]            qsfp_mac_tx_ptp_ts_tag,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_tx_ptp_ts_valid,

    // input  wire [CH_CNT-1:0]                         qsfp_mac_tx_status,
    // output wire [CH_CNT-1:0]                         qsfp_mac_tx_lfc_req,
    // output wire [CH_CNT*8-1:0]                       qsfp_mac_tx_pfc_req,

    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_clk,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_rst,

    // input  wire [CH_CNT*AXIS_ETH_DATA_WIDTH-1:0]     qsfp_mac_rx_axis_tdata,
    // input  wire [CH_CNT*AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_mac_rx_axis_tkeep,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_axis_tvalid,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_axis_tlast,
    // input  wire [CH_CNT*AXIS_ETH_RX_USER_WIDTH-1:0]  qsfp_mac_rx_axis_tuser,

    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_ptp_clk,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_ptp_rst,
    // output wire [CH_CNT*PTP_TS_WIDTH-1:0]            qsfp_mac_rx_ptp_time,

    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_status,
    // input  wire [CH_CNT-1:0]                         qsfp_mac_rx_lfc_req,
    // input  wire [CH_CNT*8-1:0]                       qsfp_mac_rx_pfc_req
);

genvar n;

wire [CH_CNT-1:0]                         qsfp_mac_tx_clk;
wire [CH_CNT-1:0]                         qsfp_mac_tx_rst;

wire [CH_CNT*AXIS_ETH_DATA_WIDTH-1:0]     qsfp_mac_tx_axis_tdata;
wire [CH_CNT*AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_mac_tx_axis_tkeep;
wire [CH_CNT-1:0]                         qsfp_mac_tx_axis_tvalid;
wire [CH_CNT-1:0]                         qsfp_mac_tx_axis_tready;
wire [CH_CNT-1:0]                         qsfp_mac_tx_axis_tlast;
wire [CH_CNT*AXIS_ETH_TX_USER_WIDTH-1:0]  qsfp_mac_tx_axis_tuser;

wire [CH_CNT-1:0]                         qsfp_mac_tx_ptp_clk;
wire [CH_CNT-1:0]                         qsfp_mac_tx_ptp_rst;
wire [CH_CNT*PTP_TS_WIDTH-1:0]            qsfp_mac_tx_ptp_time;

wire [CH_CNT*PTP_TS_WIDTH-1:0]            qsfp_mac_tx_ptp_ts;
wire [CH_CNT*TX_TAG_WIDTH-1:0]            qsfp_mac_tx_ptp_ts_tag;
wire [CH_CNT-1:0]                         qsfp_mac_tx_ptp_ts_valid;

wire [CH_CNT-1:0]                         qsfp_mac_tx_status;
wire [CH_CNT-1:0]                         qsfp_mac_tx_lfc_req;
wire [CH_CNT*8-1:0]                       qsfp_mac_tx_pfc_req;

wire [CH_CNT-1:0]                         qsfp_mac_rx_clk;
wire [CH_CNT-1:0]                         qsfp_mac_rx_rst;

wire [CH_CNT*AXIS_ETH_DATA_WIDTH-1:0]     qsfp_mac_rx_axis_tdata;
wire [CH_CNT*AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_mac_rx_axis_tkeep;
wire [CH_CNT-1:0]                         qsfp_mac_rx_axis_tvalid;
wire [CH_CNT-1:0]                         qsfp_mac_rx_axis_tlast;
wire [CH_CNT*AXIS_ETH_RX_USER_WIDTH-1:0]  qsfp_mac_rx_axis_tuser;

wire [CH_CNT-1:0]                         qsfp_mac_rx_ptp_clk;
wire [CH_CNT-1:0]                         qsfp_mac_rx_ptp_rst;
wire [CH_CNT*PTP_TS_WIDTH-1:0]            qsfp_mac_rx_ptp_time;

wire [CH_CNT-1:0]                         qsfp_mac_rx_status;
wire [CH_CNT-1:0]                         qsfp_mac_rx_lfc_req;
wire [CH_CNT*8-1:0]                       qsfp_mac_rx_pfc_req;

generate

for (n = 0; n < QSFP_CNT; n = n + 1) begin : ch

    wire                               ch_mac_tx_clk;
    wire                               ch_mac_tx_rst;

    wire [AXIS_ETH_DATA_WIDTH-1:0]     ch_mac_tx_axis_tdata;
    wire [AXIS_ETH_KEEP_WIDTH-1:0]     ch_mac_tx_axis_tkeep;
    wire                               ch_mac_tx_axis_tvalid;
    wire                               ch_mac_tx_axis_tready;
    wire                               ch_mac_tx_axis_tlast;
    wire [AXIS_ETH_TX_USER_WIDTH-1:0]  ch_mac_tx_axis_tuser;

    wire                               ch_mac_tx_ptp_clk;
    wire                               ch_mac_tx_ptp_rst;
    wire [PTP_TS_WIDTH-1:0]            ch_mac_tx_ptp_time;

    wire [PTP_TS_WIDTH-1:0]            ch_mac_tx_ptp_ts;
    wire [15:0]                        ch_mac_tx_ptp_ts_tag;
    wire                               ch_mac_tx_ptp_ts_valid;

    wire                               ch_mac_tx_status;
    wire                               ch_mac_tx_lfc_req;
    wire [7:0]                         ch_mac_tx_pfc_req;

    wire                               ch_mac_rx_clk;
    wire                               ch_mac_rx_rst;

    wire [AXIS_ETH_DATA_WIDTH-1:0]     ch_mac_rx_axis_tdata;
    wire [AXIS_ETH_KEEP_WIDTH-1:0]     ch_mac_rx_axis_tkeep;
    wire                               ch_mac_rx_axis_tvalid;
    wire                               ch_mac_rx_axis_tlast;
    wire [AXIS_ETH_RX_USER_WIDTH-1:0]  ch_mac_rx_axis_tuser;

    wire                               ch_mac_rx_ptp_clk;
    wire                               ch_mac_rx_ptp_rst;
    wire [PTP_TS_WIDTH-1:0]            ch_mac_rx_ptp_time;

    wire                               ch_mac_rx_status;
    wire                               ch_mac_rx_lfc_req;
    wire [7:0]                         ch_mac_rx_pfc_req;

    assign qsfp_mac_tx_clk[n +: 1] = ch_mac_tx_clk;
    assign qsfp_mac_tx_rst[n +: 1] = ch_mac_tx_rst;

    assign ch_mac_tx_axis_tdata = qsfp_mac_tx_axis_tdata[n*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH];
    assign ch_mac_tx_axis_tkeep = qsfp_mac_tx_axis_tkeep[n*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH];
    assign ch_mac_tx_axis_tvalid = qsfp_mac_tx_axis_tvalid[n +: 1];
    assign qsfp_mac_tx_axis_tready[n +: 1] = ch_mac_tx_axis_tready;
    assign ch_mac_tx_axis_tlast = qsfp_mac_tx_axis_tlast[n +: 1];
    assign ch_mac_tx_axis_tuser = qsfp_mac_tx_axis_tuser[n*AXIS_ETH_TX_USER_WIDTH +: AXIS_ETH_TX_USER_WIDTH];

    assign qsfp_mac_tx_ptp_clk[n +: 1] = ch_mac_tx_ptp_clk;
    assign qsfp_mac_tx_ptp_rst[n +: 1] = ch_mac_tx_ptp_rst;
    assign ch_mac_tx_ptp_time = qsfp_mac_tx_ptp_time[n*PTP_TS_WIDTH +: PTP_TS_WIDTH];

    assign qsfp_mac_tx_ptp_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH] = ch_mac_tx_ptp_ts;
    assign qsfp_mac_tx_ptp_ts_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH] = ch_mac_tx_ptp_ts_tag;
    assign qsfp_mac_tx_ptp_ts_valid[n +: 1] = ch_mac_tx_ptp_ts_valid;

    assign qsfp_mac_tx_status[n +: 1] = ch_mac_tx_status;
    assign ch_mac_tx_lfc_req = qsfp_mac_tx_lfc_req[n +: 1];
    assign ch_mac_tx_pfc_req = qsfp_mac_tx_pfc_req[n*8 +: 8];

    assign qsfp_mac_rx_clk[n +: 1] = ch_mac_rx_clk;
    assign qsfp_mac_rx_rst[n +: 1] = ch_mac_rx_rst;

    assign qsfp_mac_rx_axis_tdata[n*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH] = ch_mac_rx_axis_tdata;
    assign qsfp_mac_rx_axis_tkeep[n*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH] = ch_mac_rx_axis_tkeep;
    assign qsfp_mac_rx_axis_tvalid[n +: 1] = ch_mac_rx_axis_tvalid;
    assign qsfp_mac_rx_axis_tlast[n +: 1] = ch_mac_rx_axis_tlast;
    assign qsfp_mac_rx_axis_tuser[n*AXIS_ETH_RX_USER_WIDTH +: AXIS_ETH_RX_USER_WIDTH] = ch_mac_rx_axis_tuser;

    assign qsfp_mac_rx_ptp_clk[n +: 1] = ch_mac_rx_ptp_clk;
    assign qsfp_mac_rx_ptp_rst[n +: 1] = ch_mac_rx_ptp_rst;
    assign ch_mac_rx_ptp_time = qsfp_mac_rx_ptp_time[n*PTP_TS_WIDTH +: PTP_TS_WIDTH];

    assign qsfp_mac_rx_status[n +: 1] = ch_mac_rx_status;
    assign qsfp_mac_rx_lfc_req[n +: 1] = ch_mac_rx_lfc_req;
    assign qsfp_mac_rx_pfc_req[n*8 +: 8] = ch_mac_rx_pfc_req;

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
    .PORT_GROUP_SIZE(PORT_GROUP_SIZE),

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
    .TX_CPL_FIFO_DEPTH(TX_CPL_FIFO_DEPTH),
    .TX_TAG_WIDTH(TX_TAG_WIDTH),
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .PFC_ENABLE(PFC_ENABLE),
    .LFC_ENABLE(LFC_ENABLE),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

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
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .SEG_HDR_WIDTH(SEG_HDR_WIDTH),
    .SEG_PRFX_WIDTH(SEG_PRFX_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
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
    .user_pb(user_pb),
    .user_led_g(user_led_g),

    /*
     * I2C
     */
    .i2c2_scl_i(i2c2_scl_i),
    .i2c2_scl_o(i2c2_scl_o),
    .i2c2_scl_t(i2c2_scl_t),
    .i2c2_sda_i(i2c2_sda_i),
    .i2c2_sda_o(i2c2_sda_o),
    .i2c2_sda_t(i2c2_sda_t),
    .bmc_i2c2_disable(bmc_i2c2_disable),

    /*
     * P-Tile interface
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

    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),
    .tx_st_hdr(tx_st_hdr),
    .tx_st_tlp_prfx(tx_st_tlp_prfx),

    .rx_buffer_limit(rx_buffer_limit),
    .rx_buffer_limit_tdm_idx(rx_buffer_limit_tdm_idx),

    .tx_cdts_limit(tx_cdts_limit),
    .tx_cdts_limit_tdm_idx(tx_cdts_limit_tdm_idx),

    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * Ethernet: QSFP28
     */
    .qsfp_mac_tx_clk(qsfp_mac_tx_clk),
    .qsfp_mac_tx_rst(qsfp_mac_tx_rst),

    .qsfp_mac_tx_axis_tdata(qsfp_mac_tx_axis_tdata),
    .qsfp_mac_tx_axis_tkeep(qsfp_mac_tx_axis_tkeep),
    .qsfp_mac_tx_axis_tvalid(qsfp_mac_tx_axis_tvalid),
    .qsfp_mac_tx_axis_tready(qsfp_mac_tx_axis_tready),
    .qsfp_mac_tx_axis_tlast(qsfp_mac_tx_axis_tlast),
    .qsfp_mac_tx_axis_tuser(qsfp_mac_tx_axis_tuser),

    .qsfp_mac_tx_ptp_clk(qsfp_mac_tx_ptp_clk),
    .qsfp_mac_tx_ptp_rst(qsfp_mac_tx_ptp_rst),
    .qsfp_mac_tx_ptp_time(qsfp_mac_tx_ptp_time),

    .qsfp_mac_tx_ptp_ts(qsfp_mac_tx_ptp_ts),
    .qsfp_mac_tx_ptp_ts_tag(qsfp_mac_tx_ptp_ts_tag),
    .qsfp_mac_tx_ptp_ts_valid(qsfp_mac_tx_ptp_ts_valid),

    .qsfp_mac_tx_status(qsfp_mac_tx_status),
    .qsfp_mac_tx_lfc_req(qsfp_mac_tx_lfc_req),
    .qsfp_mac_tx_pfc_req(qsfp_mac_tx_pfc_req),

    .qsfp_mac_rx_clk(qsfp_mac_rx_clk),
    .qsfp_mac_rx_rst(qsfp_mac_rx_rst),

    .qsfp_mac_rx_axis_tdata(qsfp_mac_rx_axis_tdata),
    .qsfp_mac_rx_axis_tkeep(qsfp_mac_rx_axis_tkeep),
    .qsfp_mac_rx_axis_tvalid(qsfp_mac_rx_axis_tvalid),
    .qsfp_mac_rx_axis_tlast(qsfp_mac_rx_axis_tlast),
    .qsfp_mac_rx_axis_tuser(qsfp_mac_rx_axis_tuser),

    .qsfp_mac_rx_ptp_clk(qsfp_mac_rx_ptp_clk),
    .qsfp_mac_rx_ptp_rst(qsfp_mac_rx_ptp_rst),
    .qsfp_mac_rx_ptp_time(qsfp_mac_rx_ptp_time),

    .qsfp_mac_rx_status(qsfp_mac_rx_status),
    .qsfp_mac_rx_lfc_req(qsfp_mac_rx_lfc_req),
    .qsfp_mac_rx_pfc_req(qsfp_mac_rx_pfc_req)
);

endmodule

`resetall
