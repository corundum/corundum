/*

Copyright (c) 2021 Alex Forencich

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
 * FPGA top-level module
 */
module fpga (
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
    input  wire        s10_pcie_perstn0
);

parameter SEG_COUNT = 1;
parameter SEG_DATA_WIDTH = 256;
parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32);

parameter TX_SEQ_NUM_WIDTH = 6;

parameter PCIE_TAG_COUNT = 256;
parameter BAR0_APERTURE = 24;
parameter BAR2_APERTURE = 24;

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
    .rst(!cpu_resetn || ninit_done),
    .out(rst_100mhz)
);

wire coreclkout_hip;
wire reset_status;

wire                                  clk = coreclkout_hip;
wire                                  rst = reset_status;

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

fpga_core #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .BAR0_APERTURE(BAR0_APERTURE),
    .BAR2_APERTURE(BAR2_APERTURE)
)
fpga_core_inst (
    .clk(clk),
    .rst(rst),

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
    .tl_cfg_func(tl_cfg_func)
);

endmodule

`resetall
