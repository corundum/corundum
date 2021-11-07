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
 * FPGA top-level module
 */
module fpga #
(
    // FW and board IDs
    parameter FW_ID = 32'd0,
    parameter FW_VER = {16'd0, 16'd1},
    parameter BOARD_ID = {16'h1172, 16'h0001},
    parameter BOARD_VER = {16'd0, 16'd1},
    parameter FPGA_ID = 32'h432AC0DD,

    // Structural configuration
    parameter IF_COUNT = 2,
    parameter PORTS_PER_IF = 1,

    // PTP configuration
    parameter PTP_PEROUT_ENABLE = 1,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration (interface)
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = TX_QUEUE_OP_TABLE_SIZE,
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = RX_QUEUE_OP_TABLE_SIZE,
    parameter TX_QUEUE_INDEX_WIDTH = 10,
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter TX_CPL_QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH,
    parameter RX_CPL_QUEUE_INDEX_WIDTH = RX_QUEUE_INDEX_WIDTH,
    parameter EVENT_QUEUE_PIPELINE = 3,
    parameter TX_QUEUE_PIPELINE = 3+(TX_QUEUE_INDEX_WIDTH > 12 ? TX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter RX_QUEUE_PIPELINE = 3+(RX_QUEUE_INDEX_WIDTH > 12 ? RX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter TX_CPL_QUEUE_PIPELINE = TX_QUEUE_PIPELINE,
    parameter RX_CPL_QUEUE_PIPELINE = RX_QUEUE_PIPELINE,

    // TX and RX engine configuration (port)
    parameter TX_DESC_TABLE_SIZE = 32,
    parameter RX_DESC_TABLE_SIZE = 32,

    // Scheduler configuration (port)
    parameter TX_SCHEDULER_OP_TABLE_SIZE = TX_DESC_TABLE_SIZE,
    parameter TX_SCHEDULER_PIPELINE = TX_QUEUE_PIPELINE,
    parameter TDMA_INDEX_WIDTH = 6,

    // Timestamping configuration (port)
    parameter PTP_TS_ENABLE = 1,
    parameter TX_PTP_TS_FIFO_DEPTH = 32,
    parameter RX_PTP_TS_FIFO_DEPTH = 32,

    // Interface configuration (port)
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_RSS_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 32768,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 32768,
    parameter RX_RAM_SIZE = 32768,

    // Application block configuration
    parameter APP_ENABLE = 0,
    parameter APP_CTRL_ENABLE = 1,
    parameter APP_DMA_ENABLE = 1,
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,
    parameter APP_AXIS_IF_ENABLE = 1,
    parameter APP_STAT_ENABLE = 1,

    // DMA interface configuration
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter SEG_COUNT = 1,
    parameter SEG_DATA_WIDTH = 256,
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    parameter TX_SEQ_NUM_WIDTH = 6,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 256,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_READ_TX_FC_ENABLE = 1,
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_WRITE_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_WRITE_TX_FC_ENABLE = 1,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
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
     * Clock: 100 MHz
     * Reset: Push button, active low
     */
    input  wire        clk_sys_100m_p,
    input  wire        cpu_resetn,

    /*
     * GPIO
     */
    output wire [3:0]  user_led,

    /*
     * PCIe: gen 3 x16
     */
    output wire [7:0]  pcie_ep_rx_p,
    input  wire [7:0]  pcie_ep_tx_p,
    input  wire        refclk_pcie_ep_edge_p,
    input  wire        s10_pcie_perstn0,

    /*
     * Ethernet: QSFP28
     */
    output wire [3:0]  qsfp0_tx_p,
    input  wire [3:0]  qsfp0_rx_p,
    input  wire        refclk_qsfp0_p,

    output wire        qsfp0_modsel_l,
    output wire        qsfp0_reset_l,
    input  wire        qsfp0_modprs_l,
    output wire        qsfp0_lpmode,
    input  wire        qsfp0_int_l,

    output wire [3:0]  qsfp1_tx_p,
    input  wire [3:0]  qsfp1_rx_p,
    input  wire        refclk_qsfp1_p,

    output wire        qsfp1_modsel_l,
    output wire        qsfp1_reset_l,
    input  wire        qsfp1_modprs_l,
    output wire        qsfp1_lpmode,
    input  wire        qsfp1_int_l
);

// PTP configuration
parameter PTP_TS_WIDTH = 96;
parameter PTP_TAG_WIDTH = 16;
parameter PTP_PERIOD_NS_WIDTH = 4;
parameter PTP_OFFSET_NS_WIDTH = 32;
parameter PTP_FNS_WIDTH = 32;
parameter PTP_PERIOD_NS = 4'd4;
parameter PTP_PERIOD_FNS = 32'd0;
parameter PTP_USE_SAMPLE_CLOCK = 0;
parameter IF_PTP_PERIOD_NS = 6'h6;
parameter IF_PTP_PERIOD_FNS = 16'h6666;

// PCIe interface configuration
parameter MSI_COUNT = 32;

// Ethernet interface configuration
parameter XGMII_DATA_WIDTH = 64;
parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8;
parameter AXIS_ETH_DATA_WIDTH = XGMII_DATA_WIDTH;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH;
parameter AXIS_ETH_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire ninit_done;

reset_release reset_release_inst (
    .ninit_done (ninit_done)
);

wire clk_100mhz = clk_sys_100m_p;
wire rst_100mhz;

sync_reset #(
    .N(20)
)
sync_reset_100mhz_inst (
    .clk(clk_100mhz),
    .rst(~cpu_resetn || ninit_done),
    .out(rst_100mhz)
);

// PCIe
wire coreclkout_hip;
wire reset_status;

wire                                  pcie_clk = coreclkout_hip;
wire                                  pcie_rst = reset_status;

wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   rx_st_data;
wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]  rx_st_empty;
wire [SEG_COUNT-1:0]                  rx_st_sop;
wire [SEG_COUNT-1:0]                  rx_st_eop;
wire [SEG_COUNT-1:0]                  rx_st_valid;
wire                                  rx_st_ready;
wire [SEG_COUNT-1:0]                  rx_st_vf_active = 0;
wire [SEG_COUNT*3-1:0]                rx_st_func_num = 0;
wire [SEG_COUNT*11-1:0]               rx_st_vf_num = 0;
wire [SEG_COUNT*3-1:0]                rx_st_bar_range;

wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   tx_st_data;
wire [SEG_COUNT-1:0]                  tx_st_sop;
wire [SEG_COUNT-1:0]                  tx_st_eop;
wire [SEG_COUNT-1:0]                  tx_st_valid;
wire                                  tx_st_ready;
wire [SEG_COUNT-1:0]                  tx_st_err;

wire [7:0]                            tx_ph_cdts;
wire [11:0]                           tx_pd_cdts;
wire [7:0]                            tx_nph_cdts;
wire [11:0]                           tx_npd_cdts;
wire [7:0]                            tx_cplh_cdts;
wire [11:0]                           tx_cpld_cdts;
wire [SEG_COUNT-1:0]                  tx_hdr_cdts_consumed;
wire [SEG_COUNT-1:0]                  tx_data_cdts_consumed;
wire [SEG_COUNT*2-1:0]                tx_cdts_type;
wire [SEG_COUNT*1-1:0]                tx_cdts_data_value;

wire                                  app_msi_req;
wire                                  app_msi_ack;
wire [2:0]                            app_msi_tc;
wire [4:0]                            app_msi_num;
wire [1:0]                            app_msi_func_num;

wire [31:0]                           tl_cfg_ctl;
wire [4:0]                            tl_cfg_add;
wire [1:0]                            tl_cfg_func;

pcie pcie_hip_inst (
    .refclk                    (refclk_pcie_ep_edge_p),
    .coreclkout_hip            (coreclkout_hip),
    .npor                      (!rst_100mhz),
    .pin_perst                 (s10_pcie_perstn0),
    .reset_status              (reset_status),
    .serdes_pll_locked         (),
    .pld_core_ready            (1'b1),
    .pld_clk_inuse             (),
    .testin_zero               (),
    .clr_st                    (),
    .ninit_done                (ninit_done),
    .rx_st_ready               (rx_st_ready),
    .rx_st_sop                 (rx_st_sop),
    .rx_st_eop                 (rx_st_eop),
    .rx_st_data                (rx_st_data),
    .rx_st_valid               (rx_st_valid),
    .rx_st_empty               (rx_st_empty),
    .tx_st_sop                 (tx_st_sop),
    .tx_st_eop                 (tx_st_eop),
    .tx_st_data                (tx_st_data),
    .tx_st_valid               (tx_st_valid),
    .tx_st_err                 (tx_st_err),
    .tx_st_ready               (tx_st_ready),
    .rx_st_bar_range           (rx_st_bar_range),
    .tx_cdts_type              (tx_cdts_type),
    .tx_data_cdts_consumed     (tx_data_cdts_consumed),
    .tx_hdr_cdts_consumed      (tx_hdr_cdts_consumed),
    .tx_cdts_data_value        (tx_cdts_data_value),
    .tx_cpld_cdts              (tx_cpld_cdts),
    .tx_pd_cdts                (tx_pd_cdts),
    .tx_npd_cdts               (tx_npd_cdts),
    .tx_cplh_cdts              (tx_cplh_cdts),
    .tx_ph_cdts                (tx_ph_cdts),
    .tx_nph_cdts               (tx_nph_cdts),
    .app_msi_req               (app_msi_req),
    .app_msi_ack               (app_msi_ack),
    .app_msi_tc                (app_msi_tc),
    .app_msi_num               (app_msi_num),
    .app_int_sts               (4'd0),
    .app_msi_func_num          (app_msi_func_num),
    .int_status                (),
    .int_status_common         (),
    .derr_cor_ext_rpl          (),
    .derr_rpl                  (),
    .derr_cor_ext_rcv          (),
    .derr_uncor_ext_rcv        (),
    .rx_par_err                (),
    .tx_par_err                (),
    .ltssmstate                (),
    .link_up                   (),
    .lane_act                  (),
    .tl_cfg_func               (tl_cfg_func),
    .tl_cfg_add                (tl_cfg_add),
    .tl_cfg_ctl                (tl_cfg_ctl),
    .app_err_valid             (0),
    .app_err_hdr               (0),
    .app_err_info              (0),
    .app_err_func_num          (0),
    .test_in                   (0),
    .simu_mode_pipe            (0),
    .currentspeed              (),
    .sim_pipe_pclk_in          (1'b0),
    .sim_pipe_rate             (),
    .sim_ltssmstate            (),
    .txdata0                   (),
    .txdata1                   (),
    .txdata2                   (),
    .txdata3                   (),
    .txdata4                   (),
    .txdata5                   (),
    .txdata6                   (),
    .txdata7                   (),
    .txdatak0                  (),
    .txdatak1                  (),
    .txdatak2                  (),
    .txdatak3                  (),
    .txdatak4                  (),
    .txdatak5                  (),
    .txdatak6                  (),
    .txdatak7                  (),
    .txcompl0                  (),
    .txcompl1                  (),
    .txcompl2                  (),
    .txcompl3                  (),
    .txcompl4                  (),
    .txcompl5                  (),
    .txcompl6                  (),
    .txcompl7                  (),
    .txelecidle0               (),
    .txelecidle1               (),
    .txelecidle2               (),
    .txelecidle3               (),
    .txelecidle4               (),
    .txelecidle5               (),
    .txelecidle6               (),
    .txelecidle7               (),
    .txdetectrx0               (),
    .txdetectrx1               (),
    .txdetectrx2               (),
    .txdetectrx3               (),
    .txdetectrx4               (),
    .txdetectrx5               (),
    .txdetectrx6               (),
    .txdetectrx7               (),
    .powerdown0                (),
    .powerdown1                (),
    .powerdown2                (),
    .powerdown3                (),
    .powerdown4                (),
    .powerdown5                (),
    .powerdown6                (),
    .powerdown7                (),
    .txmargin0                 (),
    .txmargin1                 (),
    .txmargin2                 (),
    .txmargin3                 (),
    .txmargin4                 (),
    .txmargin5                 (),
    .txmargin6                 (),
    .txmargin7                 (),
    .txdeemph0                 (),
    .txdeemph1                 (),
    .txdeemph2                 (),
    .txdeemph3                 (),
    .txdeemph4                 (),
    .txdeemph5                 (),
    .txdeemph6                 (),
    .txdeemph7                 (),
    .txswing0                  (),
    .txswing1                  (),
    .txswing2                  (),
    .txswing3                  (),
    .txswing4                  (),
    .txswing5                  (),
    .txswing6                  (),
    .txswing7                  (),
    .txsynchd0                 (),
    .txsynchd1                 (),
    .txsynchd2                 (),
    .txsynchd3                 (),
    .txsynchd4                 (),
    .txsynchd5                 (),
    .txsynchd6                 (),
    .txsynchd7                 (),
    .txblkst0                  (),
    .txblkst1                  (),
    .txblkst2                  (),
    .txblkst3                  (),
    .txblkst4                  (),
    .txblkst5                  (),
    .txblkst6                  (),
    .txblkst7                  (),
    .txdataskip0               (),
    .txdataskip1               (),
    .txdataskip2               (),
    .txdataskip3               (),
    .txdataskip4               (),
    .txdataskip5               (),
    .txdataskip6               (),
    .txdataskip7               (),
    .rate0                     (),
    .rate1                     (),
    .rate2                     (),
    .rate3                     (),
    .rate4                     (),
    .rate5                     (),
    .rate6                     (),
    .rate7                     (),
    .rxpolarity0               (),
    .rxpolarity1               (),
    .rxpolarity2               (),
    .rxpolarity3               (),
    .rxpolarity4               (),
    .rxpolarity5               (),
    .rxpolarity6               (),
    .rxpolarity7               (),
    .currentrxpreset0          (),
    .currentrxpreset1          (),
    .currentrxpreset2          (),
    .currentrxpreset3          (),
    .currentrxpreset4          (),
    .currentrxpreset5          (),
    .currentrxpreset6          (),
    .currentrxpreset7          (),
    .currentcoeff0             (),
    .currentcoeff1             (),
    .currentcoeff2             (),
    .currentcoeff3             (),
    .currentcoeff4             (),
    .currentcoeff5             (),
    .currentcoeff6             (),
    .currentcoeff7             (),
    .rxeqeval0                 (),
    .rxeqeval1                 (),
    .rxeqeval2                 (),
    .rxeqeval3                 (),
    .rxeqeval4                 (),
    .rxeqeval5                 (),
    .rxeqeval6                 (),
    .rxeqeval7                 (),
    .rxeqinprogress0           (),
    .rxeqinprogress1           (),
    .rxeqinprogress2           (),
    .rxeqinprogress3           (),
    .rxeqinprogress4           (),
    .rxeqinprogress5           (),
    .rxeqinprogress6           (),
    .rxeqinprogress7           (),
    .invalidreq0               (),
    .invalidreq1               (),
    .invalidreq2               (),
    .invalidreq3               (),
    .invalidreq4               (),
    .invalidreq5               (),
    .invalidreq6               (),
    .invalidreq7               (),
    .rxdata0                   (32'd0),
    .rxdata1                   (32'd0),
    .rxdata2                   (32'd0),
    .rxdata3                   (32'd0),
    .rxdata4                   (32'd0),
    .rxdata5                   (32'd0),
    .rxdata6                   (32'd0),
    .rxdata7                   (32'd0),
    .rxdatak0                  (4'd0),
    .rxdatak1                  (4'd0),
    .rxdatak2                  (4'd0),
    .rxdatak3                  (4'd0),
    .rxdatak4                  (4'd0),
    .rxdatak5                  (4'd0),
    .rxdatak6                  (4'd0),
    .rxdatak7                  (4'd0),
    .phystatus0                (1'b0),
    .phystatus1                (1'b0),
    .phystatus2                (1'b0),
    .phystatus3                (1'b0),
    .phystatus4                (1'b0),
    .phystatus5                (1'b0),
    .phystatus6                (1'b0),
    .phystatus7                (1'b0),
    .rxvalid0                  (1'b0),
    .rxvalid1                  (1'b0),
    .rxvalid2                  (1'b0),
    .rxvalid3                  (1'b0),
    .rxvalid4                  (1'b0),
    .rxvalid5                  (1'b0),
    .rxvalid6                  (1'b0),
    .rxvalid7                  (1'b0),
    .rxstatus0                 (3'd0),
    .rxstatus1                 (3'd0),
    .rxstatus2                 (3'd0),
    .rxstatus3                 (3'd0),
    .rxstatus4                 (3'd0),
    .rxstatus5                 (3'd0),
    .rxstatus6                 (3'd0),
    .rxstatus7                 (3'd0),
    .rxelecidle0               (1'b0),
    .rxelecidle1               (1'b0),
    .rxelecidle2               (1'b0),
    .rxelecidle3               (1'b0),
    .rxelecidle4               (1'b0),
    .rxelecidle5               (1'b0),
    .rxelecidle6               (1'b0),
    .rxelecidle7               (1'b0),
    .rxsynchd0                 (2'd0),
    .rxsynchd1                 (2'd0),
    .rxsynchd2                 (2'd0),
    .rxsynchd3                 (2'd0),
    .rxsynchd4                 (2'd0),
    .rxsynchd5                 (2'd0),
    .rxsynchd6                 (2'd0),
    .rxsynchd7                 (2'd0),
    .rxblkst0                  (1'b0),
    .rxblkst1                  (1'b0),
    .rxblkst2                  (1'b0),
    .rxblkst3                  (1'b0),
    .rxblkst4                  (1'b0),
    .rxblkst5                  (1'b0),
    .rxblkst6                  (1'b0),
    .rxblkst7                  (1'b0),
    .rxdataskip0               (1'b0),
    .rxdataskip1               (1'b0),
    .rxdataskip2               (1'b0),
    .rxdataskip3               (1'b0),
    .rxdataskip4               (1'b0),
    .rxdataskip5               (1'b0),
    .rxdataskip6               (1'b0),
    .rxdataskip7               (1'b0),
    .dirfeedback0              (6'd0),
    .dirfeedback1              (6'd0),
    .dirfeedback2              (6'd0),
    .dirfeedback3              (6'd0),
    .dirfeedback4              (6'd0),
    .dirfeedback5              (6'd0),
    .dirfeedback6              (6'd0),
    .dirfeedback7              (6'd0),
    .sim_pipe_mask_tx_pll_lock (1'b0),
    .rx_in0                    (pcie_ep_tx_p[0]),
    .rx_in1                    (pcie_ep_tx_p[1]),
    .rx_in2                    (pcie_ep_tx_p[2]),
    .rx_in3                    (pcie_ep_tx_p[3]),
    .rx_in4                    (pcie_ep_tx_p[4]),
    .rx_in5                    (pcie_ep_tx_p[5]),
    .rx_in6                    (pcie_ep_tx_p[6]),
    .rx_in7                    (pcie_ep_tx_p[7]),
    .tx_out0                   (pcie_ep_rx_p[0]),
    .tx_out1                   (pcie_ep_rx_p[1]),
    .tx_out2                   (pcie_ep_rx_p[2]),
    .tx_out3                   (pcie_ep_rx_p[3]),
    .tx_out4                   (pcie_ep_rx_p[4]),
    .tx_out5                   (pcie_ep_rx_p[5]),
    .tx_out6                   (pcie_ep_rx_p[6]),
    .tx_out7                   (pcie_ep_rx_p[7]),
    .pm_linkst_in_l1           (),
    .pm_linkst_in_l0s          (),
    .pm_state                  (),
    .pm_dstate                 (),
    .apps_pm_xmt_pme           (0),
    .apps_ready_entr_l23       (0),
    .apps_pm_xmt_turnoff       (0),
    .app_init_rst              (0),
    .app_xfer_pending          (0)
);

// XGMII 10G PHY

// QSFP0
assign qsfp0_modsel_l = 1'b0;
assign qsfp0_reset_l = 1'b1;
assign qsfp0_lpmode = 1'b0;

wire                         qsfp0_tx_clk_1_int;
wire                         qsfp0_tx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_txd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_txc_1_int;
wire                         qsfp0_tx_prbs31_enable_1_int;
wire                         qsfp0_rx_clk_1_int;
wire                         qsfp0_rx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_rxd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_rxc_1_int;
wire                         qsfp0_rx_prbs31_enable_1_int;
wire [6:0]                   qsfp0_rx_error_count_1_int;
wire                         qsfp0_tx_clk_2_int;
wire                         qsfp0_tx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_txd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_txc_2_int;
wire                         qsfp0_tx_prbs31_enable_2_int;
wire                         qsfp0_rx_clk_2_int;
wire                         qsfp0_rx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_rxd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_rxc_2_int;
wire                         qsfp0_rx_prbs31_enable_2_int;
wire [6:0]                   qsfp0_rx_error_count_2_int;
wire                         qsfp0_tx_clk_3_int;
wire                         qsfp0_tx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_txd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_txc_3_int;
wire                         qsfp0_tx_prbs31_enable_3_int;
wire                         qsfp0_rx_clk_3_int;
wire                         qsfp0_rx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_rxd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_rxc_3_int;
wire                         qsfp0_rx_prbs31_enable_3_int;
wire [6:0]                   qsfp0_rx_error_count_3_int;
wire                         qsfp0_tx_clk_4_int;
wire                         qsfp0_tx_rst_4_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_txd_4_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_txc_4_int;
wire                         qsfp0_tx_prbs31_enable_4_int;
wire                         qsfp0_rx_clk_4_int;
wire                         qsfp0_rx_rst_4_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp0_rxd_4_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp0_rxc_4_int;
wire                         qsfp0_rx_prbs31_enable_4_int;
wire [6:0]                   qsfp0_rx_error_count_4_int;

wire qsfp0_rx_block_lock_1;
wire qsfp0_rx_block_lock_2;
wire qsfp0_rx_block_lock_3;
wire qsfp0_rx_block_lock_4;

eth_xcvr_phy_quad_wrapper qsfp0_eth_xcvr_phy_quad (
    .xcvr_ctrl_clk(clk_100mhz),
    .xcvr_ctrl_rst(rst_100mhz),
    .xcvr_ref_clk(refclk_qsfp0_p),
    .xcvr_tx_serial_data(qsfp0_tx_p),
    .xcvr_rx_serial_data(qsfp0_rx_p),

    .phy_1_tx_clk(qsfp0_tx_clk_1_int),
    .phy_1_tx_rst(qsfp0_tx_rst_1_int),
    .phy_1_xgmii_txd(qsfp0_txd_1_int),
    .phy_1_xgmii_txc(qsfp0_txc_1_int),
    .phy_1_rx_clk(qsfp0_rx_clk_1_int),
    .phy_1_rx_rst(qsfp0_rx_rst_1_int),
    .phy_1_xgmii_rxd(qsfp0_rxd_1_int),
    .phy_1_xgmii_rxc(qsfp0_rxc_1_int),
    .phy_1_rx_block_lock(qsfp0_rx_block_lock_1),
    .phy_1_rx_high_ber(),
    .phy_2_tx_clk(qsfp0_tx_clk_2_int),
    .phy_2_tx_rst(qsfp0_tx_rst_2_int),
    .phy_2_xgmii_txd(qsfp0_txd_2_int),
    .phy_2_xgmii_txc(qsfp0_txc_2_int),
    .phy_2_rx_clk(qsfp0_rx_clk_2_int),
    .phy_2_rx_rst(qsfp0_rx_rst_2_int),
    .phy_2_xgmii_rxd(qsfp0_rxd_2_int),
    .phy_2_xgmii_rxc(qsfp0_rxc_2_int),
    .phy_2_rx_block_lock(qsfp0_rx_block_lock_2),
    .phy_2_rx_high_ber(),
    .phy_3_tx_clk(qsfp0_tx_clk_3_int),
    .phy_3_tx_rst(qsfp0_tx_rst_3_int),
    .phy_3_xgmii_txd(qsfp0_txd_3_int),
    .phy_3_xgmii_txc(qsfp0_txc_3_int),
    .phy_3_rx_clk(qsfp0_rx_clk_3_int),
    .phy_3_rx_rst(qsfp0_rx_rst_3_int),
    .phy_3_xgmii_rxd(qsfp0_rxd_3_int),
    .phy_3_xgmii_rxc(qsfp0_rxc_3_int),
    .phy_3_rx_block_lock(qsfp0_rx_block_lock_3),
    .phy_3_rx_high_ber(),
    .phy_4_tx_clk(qsfp0_tx_clk_4_int),
    .phy_4_tx_rst(qsfp0_tx_rst_4_int),
    .phy_4_xgmii_txd(qsfp0_txd_4_int),
    .phy_4_xgmii_txc(qsfp0_txc_4_int),
    .phy_4_rx_clk(qsfp0_rx_clk_4_int),
    .phy_4_rx_rst(qsfp0_rx_rst_4_int),
    .phy_4_xgmii_rxd(qsfp0_rxd_4_int),
    .phy_4_xgmii_rxc(qsfp0_rxc_4_int),
    .phy_4_rx_block_lock(qsfp0_rx_block_lock_4),
    .phy_4_rx_high_ber()
);

// QSFP1
assign qsfp1_modsel_l = 1'b0;
assign qsfp1_reset_l = 1'b1;
assign qsfp1_lpmode = 1'b0;

wire                         qsfp1_tx_clk_1_int;
wire                         qsfp1_tx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_txd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_txc_1_int;
wire                         qsfp1_tx_prbs31_enable_1_int;
wire                         qsfp1_rx_clk_1_int;
wire                         qsfp1_rx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_rxd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_rxc_1_int;
wire                         qsfp1_rx_prbs31_enable_1_int;
wire [6:0]                   qsfp1_rx_error_count_1_int;
wire                         qsfp1_tx_clk_2_int;
wire                         qsfp1_tx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_txd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_txc_2_int;
wire                         qsfp1_tx_prbs31_enable_2_int;
wire                         qsfp1_rx_clk_2_int;
wire                         qsfp1_rx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_rxd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_rxc_2_int;
wire                         qsfp1_rx_prbs31_enable_2_int;
wire [6:0]                   qsfp1_rx_error_count_2_int;
wire                         qsfp1_tx_clk_3_int;
wire                         qsfp1_tx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_txd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_txc_3_int;
wire                         qsfp1_tx_prbs31_enable_3_int;
wire                         qsfp1_rx_clk_3_int;
wire                         qsfp1_rx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_rxd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_rxc_3_int;
wire                         qsfp1_rx_prbs31_enable_3_int;
wire [6:0]                   qsfp1_rx_error_count_3_int;
wire                         qsfp1_tx_clk_4_int;
wire                         qsfp1_tx_rst_4_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_txd_4_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_txc_4_int;
wire                         qsfp1_tx_prbs31_enable_4_int;
wire                         qsfp1_rx_clk_4_int;
wire                         qsfp1_rx_rst_4_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp1_rxd_4_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp1_rxc_4_int;
wire                         qsfp1_rx_prbs31_enable_4_int;
wire [6:0]                   qsfp1_rx_error_count_4_int;

wire qsfp1_rx_block_lock_1;
wire qsfp1_rx_block_lock_2;
wire qsfp1_rx_block_lock_3;
wire qsfp1_rx_block_lock_4;

eth_xcvr_phy_quad_wrapper qsfp1_eth_xcvr_phy_quad (
    .xcvr_ctrl_clk(clk_100mhz),
    .xcvr_ctrl_rst(rst_100mhz),
    .xcvr_ref_clk(refclk_qsfp1_p),
    .xcvr_tx_serial_data(qsfp1_tx_p),
    .xcvr_rx_serial_data(qsfp1_rx_p),

    .phy_1_tx_clk(qsfp1_tx_clk_1_int),
    .phy_1_tx_rst(qsfp1_tx_rst_1_int),
    .phy_1_xgmii_txd(qsfp1_txd_1_int),
    .phy_1_xgmii_txc(qsfp1_txc_1_int),
    .phy_1_rx_clk(qsfp1_rx_clk_1_int),
    .phy_1_rx_rst(qsfp1_rx_rst_1_int),
    .phy_1_xgmii_rxd(qsfp1_rxd_1_int),
    .phy_1_xgmii_rxc(qsfp1_rxc_1_int),
    .phy_1_rx_block_lock(qsfp1_rx_block_lock_1),
    .phy_1_rx_high_ber(),
    .phy_2_tx_clk(qsfp1_tx_clk_2_int),
    .phy_2_tx_rst(qsfp1_tx_rst_2_int),
    .phy_2_xgmii_txd(qsfp1_txd_2_int),
    .phy_2_xgmii_txc(qsfp1_txc_2_int),
    .phy_2_rx_clk(qsfp1_rx_clk_2_int),
    .phy_2_rx_rst(qsfp1_rx_rst_2_int),
    .phy_2_xgmii_rxd(qsfp1_rxd_2_int),
    .phy_2_xgmii_rxc(qsfp1_rxc_2_int),
    .phy_2_rx_block_lock(qsfp1_rx_block_lock_2),
    .phy_2_rx_high_ber(),
    .phy_3_tx_clk(qsfp1_tx_clk_3_int),
    .phy_3_tx_rst(qsfp1_tx_rst_3_int),
    .phy_3_xgmii_txd(qsfp1_txd_3_int),
    .phy_3_xgmii_txc(qsfp1_txc_3_int),
    .phy_3_rx_clk(qsfp1_rx_clk_3_int),
    .phy_3_rx_rst(qsfp1_rx_rst_3_int),
    .phy_3_xgmii_rxd(qsfp1_rxd_3_int),
    .phy_3_xgmii_rxc(qsfp1_rxc_3_int),
    .phy_3_rx_block_lock(qsfp1_rx_block_lock_3),
    .phy_3_rx_high_ber(),
    .phy_4_tx_clk(qsfp1_tx_clk_4_int),
    .phy_4_tx_rst(qsfp1_tx_rst_4_int),
    .phy_4_xgmii_txd(qsfp1_txd_4_int),
    .phy_4_xgmii_txc(qsfp1_txc_4_int),
    .phy_4_rx_clk(qsfp1_rx_clk_4_int),
    .phy_4_rx_rst(qsfp1_rx_rst_4_int),
    .phy_4_xgmii_rxd(qsfp1_rxd_4_int),
    .phy_4_xgmii_rxc(qsfp1_rxc_4_int),
    .phy_4_rx_block_lock(qsfp1_rx_block_lock_4),
    .phy_4_rx_high_ber()
);

fpga_core #(
    // FW and board IDs
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .FPGA_ID(FPGA_ID),

    // Structural configuration
    .IF_COUNT(IF_COUNT),
    .PORTS_PER_IF(PORTS_PER_IF),

    // PTP configuration
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .PTP_PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .PTP_OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .PTP_FNS_WIDTH(PTP_FNS_WIDTH),
    .PTP_PERIOD_NS(PTP_PERIOD_NS),
    .PTP_PERIOD_FNS(PTP_PERIOD_FNS),
    .PTP_USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),
    .IF_PTP_PERIOD_NS(IF_PTP_PERIOD_NS),
    .IF_PTP_PERIOD_FNS(IF_PTP_PERIOD_FNS),

    // Queue manager configuration (interface)
    .EVENT_QUEUE_OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .TX_QUEUE_OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .RX_QUEUE_OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .TX_CPL_QUEUE_OP_TABLE_SIZE(TX_CPL_QUEUE_OP_TABLE_SIZE),
    .RX_CPL_QUEUE_OP_TABLE_SIZE(RX_CPL_QUEUE_OP_TABLE_SIZE),
    .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_QUEUE_PIPELINE(EVENT_QUEUE_PIPELINE),
    .TX_QUEUE_PIPELINE(TX_QUEUE_PIPELINE),
    .RX_QUEUE_PIPELINE(RX_QUEUE_PIPELINE),
    .TX_CPL_QUEUE_PIPELINE(TX_CPL_QUEUE_PIPELINE),
    .RX_CPL_QUEUE_PIPELINE(RX_CPL_QUEUE_PIPELINE),

    // TX and RX engine configuration (port)
    .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),

    // Scheduler configuration (port)
    .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
    .TX_SCHEDULER_PIPELINE(TX_SCHEDULER_PIPELINE),
    .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),

    // Timestamping configuration (port)
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .TX_PTP_TS_FIFO_DEPTH(TX_PTP_TS_FIFO_DEPTH),
    .RX_PTP_TS_FIFO_DEPTH(RX_PTP_TS_FIFO_DEPTH),

    // Interface configuration (port)
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .RX_RSS_ENABLE(RX_RSS_ENABLE),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

    // Application block configuration
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),

    // DMA interface configuration
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // PCIe interface configuration
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .PF_COUNT(PF_COUNT),
    .VF_COUNT(VF_COUNT),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .PCIE_DMA_READ_OP_TABLE_SIZE(PCIE_DMA_READ_OP_TABLE_SIZE),
    .PCIE_DMA_READ_TX_LIMIT(PCIE_DMA_READ_TX_LIMIT),
    .PCIE_DMA_READ_TX_FC_ENABLE(PCIE_DMA_READ_TX_FC_ENABLE),
    .PCIE_DMA_WRITE_OP_TABLE_SIZE(PCIE_DMA_WRITE_OP_TABLE_SIZE),
    .PCIE_DMA_WRITE_TX_LIMIT(PCIE_DMA_WRITE_TX_LIMIT),
    .PCIE_DMA_WRITE_TX_FC_ENABLE(PCIE_DMA_WRITE_TX_FC_ENABLE),
    .MSI_COUNT(MSI_COUNT),

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
core_inst (
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    .clk_250mhz(pcie_clk),
    .rst_250mhz(pcie_rst),

    /*
     * GPIO
     */
    .user_led(user_led),

    /*
     * H-tile RX AVST interface
     */
    .rx_st_data(rx_st_data),
    .rx_st_empty(rx_st_empty),
    .rx_st_sop(rx_st_sop),
    .rx_st_eop(rx_st_eop),
    .rx_st_valid(rx_st_valid),
    .rx_st_ready(rx_st_ready),
    .rx_st_vf_active(rx_st_vf_active),
    .rx_st_func_num(rx_st_func_num),
    .rx_st_vf_num(rx_st_vf_num),
    .rx_st_bar_range(rx_st_bar_range),

    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),

    .tx_ph_cdts(tx_ph_cdts),
    .tx_pd_cdts(tx_pd_cdts),
    .tx_nph_cdts(tx_nph_cdts),
    .tx_npd_cdts(tx_npd_cdts),
    .tx_cplh_cdts(tx_cplh_cdts),
    .tx_cpld_cdts(tx_cpld_cdts),
    .tx_hdr_cdts_consumed(tx_hdr_cdts_consumed),
    .tx_data_cdts_consumed(tx_data_cdts_consumed),
    .tx_cdts_type(tx_cdts_type),
    .tx_cdts_data_value(tx_cdts_data_value),

    .app_msi_req(app_msi_req),
    .app_msi_ack(app_msi_ack),
    .app_msi_tc(app_msi_tc),
    .app_msi_num(app_msi_num),
    .app_msi_func_num(app_msi_func_num),

    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * Ethernet: QSFP28
     */
    .qsfp0_tx_clk_1(qsfp0_tx_clk_1_int),
    .qsfp0_tx_rst_1(qsfp0_tx_rst_1_int),
    .qsfp0_txd_1(qsfp0_txd_1_int),
    .qsfp0_txc_1(qsfp0_txc_1_int),
    .qsfp0_tx_prbs31_enable_1(qsfp0_tx_prbs31_enable_1_int),
    .qsfp0_rx_clk_1(qsfp0_rx_clk_1_int),
    .qsfp0_rx_rst_1(qsfp0_rx_rst_1_int),
    .qsfp0_rxd_1(qsfp0_rxd_1_int),
    .qsfp0_rxc_1(qsfp0_rxc_1_int),
    .qsfp0_rx_prbs31_enable_1(qsfp0_rx_prbs31_enable_1_int),
    .qsfp0_rx_error_count_1(qsfp0_rx_error_count_1_int),
    .qsfp0_tx_clk_2(qsfp0_tx_clk_2_int),
    .qsfp0_tx_rst_2(qsfp0_tx_rst_2_int),
    .qsfp0_txd_2(qsfp0_txd_2_int),
    .qsfp0_txc_2(qsfp0_txc_2_int),
    .qsfp0_tx_prbs31_enable_2(qsfp0_tx_prbs31_enable_2_int),
    .qsfp0_rx_clk_2(qsfp0_rx_clk_2_int),
    .qsfp0_rx_rst_2(qsfp0_rx_rst_2_int),
    .qsfp0_rxd_2(qsfp0_rxd_2_int),
    .qsfp0_rxc_2(qsfp0_rxc_2_int),
    .qsfp0_rx_prbs31_enable_2(qsfp0_rx_prbs31_enable_2_int),
    .qsfp0_rx_error_count_2(qsfp0_rx_error_count_2_int),
    .qsfp0_tx_clk_3(qsfp0_tx_clk_3_int),
    .qsfp0_tx_rst_3(qsfp0_tx_rst_3_int),
    .qsfp0_txd_3(qsfp0_txd_3_int),
    .qsfp0_txc_3(qsfp0_txc_3_int),
    .qsfp0_tx_prbs31_enable_3(qsfp0_tx_prbs31_enable_3_int),
    .qsfp0_rx_clk_3(qsfp0_rx_clk_3_int),
    .qsfp0_rx_rst_3(qsfp0_rx_rst_3_int),
    .qsfp0_rxd_3(qsfp0_rxd_3_int),
    .qsfp0_rxc_3(qsfp0_rxc_3_int),
    .qsfp0_rx_prbs31_enable_3(qsfp0_rx_prbs31_enable_3_int),
    .qsfp0_rx_error_count_3(qsfp0_rx_error_count_3_int),
    .qsfp0_tx_clk_4(qsfp0_tx_clk_4_int),
    .qsfp0_tx_rst_4(qsfp0_tx_rst_4_int),
    .qsfp0_txd_4(qsfp0_txd_4_int),
    .qsfp0_txc_4(qsfp0_txc_4_int),
    .qsfp0_tx_prbs31_enable_4(qsfp0_tx_prbs31_enable_4_int),
    .qsfp0_rx_clk_4(qsfp0_rx_clk_4_int),
    .qsfp0_rx_rst_4(qsfp0_rx_rst_4_int),
    .qsfp0_rxd_4(qsfp0_rxd_4_int),
    .qsfp0_rxc_4(qsfp0_rxc_4_int),
    .qsfp0_rx_prbs31_enable_4(qsfp0_rx_prbs31_enable_4_int),
    .qsfp0_rx_error_count_4(qsfp0_rx_error_count_4_int),
    .qsfp1_tx_clk_1(qsfp1_tx_clk_1_int),
    .qsfp1_tx_rst_1(qsfp1_tx_rst_1_int),
    .qsfp1_txd_1(qsfp1_txd_1_int),
    .qsfp1_txc_1(qsfp1_txc_1_int),
    .qsfp1_tx_prbs31_enable_1(qsfp1_tx_prbs31_enable_1_int),
    .qsfp1_rx_clk_1(qsfp1_rx_clk_1_int),
    .qsfp1_rx_rst_1(qsfp1_rx_rst_1_int),
    .qsfp1_rxd_1(qsfp1_rxd_1_int),
    .qsfp1_rxc_1(qsfp1_rxc_1_int),
    .qsfp1_rx_prbs31_enable_1(qsfp1_rx_prbs31_enable_1_int),
    .qsfp1_rx_error_count_1(qsfp1_rx_error_count_1_int),
    .qsfp1_tx_clk_2(qsfp1_tx_clk_2_int),
    .qsfp1_tx_rst_2(qsfp1_tx_rst_2_int),
    .qsfp1_txd_2(qsfp1_txd_2_int),
    .qsfp1_txc_2(qsfp1_txc_2_int),
    .qsfp1_tx_prbs31_enable_2(qsfp1_tx_prbs31_enable_2_int),
    .qsfp1_rx_clk_2(qsfp1_rx_clk_2_int),
    .qsfp1_rx_rst_2(qsfp1_rx_rst_2_int),
    .qsfp1_rxd_2(qsfp1_rxd_2_int),
    .qsfp1_rxc_2(qsfp1_rxc_2_int),
    .qsfp1_rx_prbs31_enable_2(qsfp1_rx_prbs31_enable_2_int),
    .qsfp1_rx_error_count_2(qsfp1_rx_error_count_2_int),
    .qsfp1_tx_clk_3(qsfp1_tx_clk_3_int),
    .qsfp1_tx_rst_3(qsfp1_tx_rst_3_int),
    .qsfp1_txd_3(qsfp1_txd_3_int),
    .qsfp1_txc_3(qsfp1_txc_3_int),
    .qsfp1_tx_prbs31_enable_3(qsfp1_tx_prbs31_enable_3_int),
    .qsfp1_rx_clk_3(qsfp1_rx_clk_3_int),
    .qsfp1_rx_rst_3(qsfp1_rx_rst_3_int),
    .qsfp1_rxd_3(qsfp1_rxd_3_int),
    .qsfp1_rxc_3(qsfp1_rxc_3_int),
    .qsfp1_rx_prbs31_enable_3(qsfp1_rx_prbs31_enable_3_int),
    .qsfp1_rx_error_count_3(qsfp1_rx_error_count_3_int),
    .qsfp1_tx_clk_4(qsfp1_tx_clk_4_int),
    .qsfp1_tx_rst_4(qsfp1_tx_rst_4_int),
    .qsfp1_txd_4(qsfp1_txd_4_int),
    .qsfp1_txc_4(qsfp1_txc_4_int),
    .qsfp1_tx_prbs31_enable_4(qsfp1_tx_prbs31_enable_4_int),
    .qsfp1_rx_clk_4(qsfp1_rx_clk_4_int),
    .qsfp1_rx_rst_4(qsfp1_rx_rst_4_int),
    .qsfp1_rxd_4(qsfp1_rxd_4_int),
    .qsfp1_rxc_4(qsfp1_rxc_4_int),
    .qsfp1_rx_prbs31_enable_4(qsfp1_rx_prbs31_enable_4_int),
    .qsfp1_rx_error_count_4(qsfp1_rx_error_count_4_int)
);

endmodule

`resetall
