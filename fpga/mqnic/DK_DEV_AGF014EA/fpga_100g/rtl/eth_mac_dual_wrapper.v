/*

Copyright (c) 2022 Alex Forencich

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
 * Dual Ethernet MAC wrapper
 */
module eth_mac_dual_wrapper #
(
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_TAG_WIDTH = 8,
    parameter DATA_WIDTH = 512,
    parameter KEEP_WIDTH = DATA_WIDTH/8,
    parameter TX_USER_WIDTH = PTP_TAG_WIDTH+1,
    parameter RX_USER_WIDTH = PTP_TS_WIDTH+1
)
(
    input  wire                      ctrl_clk,
    input  wire                      ctrl_rst,

    output wire [7:0]                tx_serial_data_p,
    output wire [7:0]                tx_serial_data_n,
    input  wire [7:0]                rx_serial_data_p,
    input  wire [7:0]                rx_serial_data_n,
    input  wire                      ref_clk,

    output wire                      mac_1_clk,
    output wire                      mac_1_rst,

    input  wire [PTP_TS_WIDTH-1:0]   mac_1_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_1_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_1_tx_ptp_ts_tag,
    output wire                      mac_1_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_1_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_1_tx_axis_tkeep,
    input  wire                      mac_1_tx_axis_tvalid,
    output wire                      mac_1_tx_axis_tready,
    input  wire                      mac_1_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_1_tx_axis_tuser,

    output wire [DATA_WIDTH-1:0]     mac_1_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_1_rx_axis_tkeep,
    output wire                      mac_1_rx_axis_tvalid,
    output wire                      mac_1_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_1_rx_axis_tuser,

    output wire                      mac_1_rx_status,

    output wire                      mac_2_clk,
    output wire                      mac_2_rst,

    input  wire [PTP_TS_WIDTH-1:0]   mac_2_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_2_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_2_tx_ptp_ts_tag,
    output wire                      mac_2_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_2_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_2_tx_axis_tkeep,
    input  wire                      mac_2_tx_axis_tvalid,
    output wire                      mac_2_tx_axis_tready,
    input  wire                      mac_2_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_2_tx_axis_tuser,

    output wire [DATA_WIDTH-1:0]     mac_2_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_2_rx_axis_tkeep,
    output wire                      mac_2_rx_axis_tvalid,
    output wire                      mac_2_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_2_rx_axis_tuser,

    output wire                      mac_2_rx_status
);

parameter N_CH = 2;
parameter XCVR_PER_MAC = 4;
parameter XCVR_CH = N_CH*XCVR_PER_MAC;

wire [N_CH*6-1:0]  mac_pll_clk_d64;
wire [N_CH*6-1:0]  mac_pll_clk_d66;
wire [N_CH*6-1:0]  mac_rec_clk_d64;
wire [N_CH*6-1:0]  mac_rec_clk_d66;

wire [N_CH-1:0]  mac_tx_pll_locked;

wire [N_CH-1:0]  mac_clk;
wire [N_CH-1:0]  mac_rst;

wire [XCVR_CH*19-1:0]  xcvr_reconfig_address;
wire [XCVR_CH-1:0]     xcvr_reconfig_read;
wire [XCVR_CH-1:0]     xcvr_reconfig_write;
wire [XCVR_CH*8-1:0]   xcvr_reconfig_readdata;
wire [XCVR_CH*8-1:0]   xcvr_reconfig_writedata;
wire [XCVR_CH-1:0]     xcvr_reconfig_waitrequest;

wire [N_CH-1:0]  mac_tx_lanes_stable;
wire [N_CH-1:0]  mac_rx_pcs_ready;
wire [N_CH-1:0]  mac_ehip_ready;

wire [N_CH*PTP_TS_WIDTH-1:0]   mac_ptp_tod;
wire [N_CH*PTP_TAG_WIDTH-1:0]  mac_ptp_fp;
wire [N_CH-1:0]                mac_ptp_ets_valid;
wire [N_CH*PTP_TS_WIDTH-1:0]   mac_ptp_ets;
wire [N_CH*PTP_TAG_WIDTH-1:0]  mac_ptp_ets_fp;
wire [N_CH*PTP_TS_WIDTH-1:0]   mac_ptp_rx_its;

wire [N_CH-1:0]                mac_tx_ready;
wire [N_CH-1:0]                mac_tx_valid;
wire [N_CH*DATA_WIDTH-1:0]     mac_tx_data;
wire [N_CH-1:0]                mac_tx_error;
wire [N_CH-1:0]                mac_tx_startofpacket;
wire [N_CH-1:0]                mac_tx_endofpacket;
wire [N_CH*6-1:0]              mac_tx_empty;

wire [N_CH-1:0]                mac_rx_valid;
wire [N_CH*DATA_WIDTH-1:0]     mac_rx_data;
wire [N_CH-1:0]                mac_rx_startofpacket;
wire [N_CH-1:0]                mac_rx_endofpacket;
wire [N_CH*6-1:0]              mac_rx_empty;
wire [N_CH*6-1:0]              mac_rx_error;

mac_02 mac_02_inst (
    .i_stats_snapshot               (1'b0),
    .o_cdr_lock                     (),
    .o_tx_pll_locked                (mac_tx_pll_locked[0*1 +: 1]),
    .i_eth_reconfig_addr            (21'd0),
    .i_eth_reconfig_read            (1'b0),
    .i_eth_reconfig_write           (1'b0),
    .o_eth_reconfig_readdata        (),
    .o_eth_reconfig_readdata_valid  (),
    .i_eth_reconfig_writedata       (32'd0),
    .o_eth_reconfig_waitrequest     (),
    .i_rsfec_reconfig_addr          (11'd0),
    .i_rsfec_reconfig_read          (1'b0),
    .i_rsfec_reconfig_write         (1'b0),
    .o_rsfec_reconfig_readdata      (),
    .i_rsfec_reconfig_writedata     (8'd0),
    .o_rsfec_reconfig_waitrequest   (),
    .i_ptp_reconfig_address         ({2{19'd0}}),
    .i_ptp_reconfig_read            ({2{1'b0}}),
    .i_ptp_reconfig_write           ({2{1'b0}}),
    .o_ptp_reconfig_readdata        (),
    .i_ptp_reconfig_writedata       ({2{8'd0}}),
    .o_ptp_reconfig_waitrequest     (),
    .o_tx_lanes_stable              (mac_tx_lanes_stable[0*1 +: 1]),
    .o_rx_pcs_ready                 (mac_rx_pcs_ready[0*1 +: 1]),
    .o_ehip_ready                   (mac_ehip_ready[0*1 +: 1]),
    .o_rx_block_lock                (),
    .o_rx_am_lock                   (),
    .o_rx_hi_ber                    (),
    .o_local_fault_status           (),
    .o_remote_fault_status          (),
    .i_clk_ref                      (ref_clk),
    .i_clk_tx                       (mac_clk[0*1 +: 1]),
    .i_clk_rx                       (mac_clk[0*1 +: 1]),
    .o_clk_pll_div64                (mac_pll_clk_d64[0*6*1 +: 6*1]),
    .o_clk_pll_div66                (mac_pll_clk_d66[0*6*1 +: 6*1]),
    .o_clk_rec_div64                (mac_rec_clk_d64[0*6*1 +: 6*1]),
    .o_clk_rec_div66                (mac_rec_clk_d66[0*6*1 +: 6*1]),
    .i_csr_rst_n                    (!ctrl_rst),
    .i_tx_rst_n                     (mac_tx_pll_locked[0*1 +: 1]),
    .i_rx_rst_n                     (mac_tx_pll_locked[0*1 +: 1]),
    .o_tx_serial                    (tx_serial_data_p[0*4*1 +: 4*1]),
    .i_rx_serial                    (rx_serial_data_p[0*4*1 +: 4*1]),
    .o_tx_serial_n                  (tx_serial_data_n[0*4*1 +: 4*1]),
    .i_rx_serial_n                  (rx_serial_data_n[0*4*1 +: 4*1]),
    .i_reconfig_clk                 (ctrl_clk),
    .i_reconfig_reset               (ctrl_rst),
    .i_xcvr_reconfig_address        (xcvr_reconfig_address[0*4*19 +: 4*19]),
    .i_xcvr_reconfig_read           (xcvr_reconfig_read[0*4*1 +: 4*1]),
    .i_xcvr_reconfig_write          (xcvr_reconfig_write[0*4*1 +: 4*1]),
    .o_xcvr_reconfig_readdata       (xcvr_reconfig_readdata[0*4*8 +: 4*8]),
    .i_xcvr_reconfig_writedata      (xcvr_reconfig_writedata[0*4*8 +: 4*8]),
    .o_xcvr_reconfig_waitrequest    (xcvr_reconfig_waitrequest[0*4*1 +: 4*1]),
    .i_ptp_tod                      (mac_ptp_tod[0*96 +: 96]),
    .i_ptp_ts_req                   (1'b1),
    .i_ptp_fp                       (mac_ptp_fp[0*8 +: 8]),
    .o_ptp_ets_valid                (mac_ptp_ets_valid[0*1 +: 1]),
    .o_ptp_ets                      (mac_ptp_ets[0*96 +: 96]),
    .o_ptp_ets_fp                   (mac_ptp_ets_fp[0*8 +: 8]),
    .o_ptp_rx_its                   (mac_ptp_rx_its[0*96 +: 96]),
    .o_tx_ptp_ready                 (),
    .o_rx_ptp_ready                 (),
    .i_ptp_ins_ets                  (1'b0),
    .i_ptp_ins_cf                   (1'b0),
    .i_ptp_zero_csum                (1'b0),
    .i_ptp_update_eb                (1'b0),
    .i_ptp_ts_format                (1'b0),
    .i_ptp_ts_offset                (16'd0),
    .i_ptp_cf_offset                (16'd0),
    .i_ptp_csum_offset              (16'd0),
    .i_ptp_eb_offset                (16'd0),
    .i_ptp_tx_its                   (96'd0),
    .o_tx_ready                     (mac_tx_ready[0*1 +: 1]),
    .i_tx_valid                     (mac_tx_valid[0*1 +: 1]),
    .i_tx_data                      (mac_tx_data[0*DATA_WIDTH +: DATA_WIDTH]),
    .i_tx_error                     (mac_tx_error[0*1 +: 1]),
    .i_tx_startofpacket             (mac_tx_startofpacket[0*1 +: 1]),
    .i_tx_endofpacket               (mac_tx_endofpacket[0*1 +: 1]),
    .i_tx_empty                     (mac_tx_empty[0*6 +: 6]),
    .i_tx_skip_crc                  (1'b0),
    .o_rx_valid                     (mac_rx_valid[0*1 +: 1]),
    .o_rx_data                      (mac_rx_data[0*DATA_WIDTH +: DATA_WIDTH]),
    .o_rx_startofpacket             (mac_rx_startofpacket[0*1 +: 1]),
    .o_rx_endofpacket               (mac_rx_endofpacket[0*1 +: 1]),
    .o_rx_empty                     (mac_rx_empty[0*6 +: 6]),
    .o_rx_error                     (mac_rx_error[0*6 +: 6]),
    .o_rxstatus_data                (),
    .o_rxstatus_valid               (),
    .i_tx_pfc                       (8'd0),
    .o_rx_pfc                       (),
    .i_tx_pause                     (1'b0),
    .o_rx_pause                     ()
);

mac_13 mac_13_inst (
    .i_stats_snapshot               (1'b0),
    .o_cdr_lock                     (),
    .o_tx_pll_locked                (mac_tx_pll_locked[1*1 +: 1]),
    .i_eth_reconfig_addr            (21'd0),
    .i_eth_reconfig_read            (1'b0),
    .i_eth_reconfig_write           (1'b0),
    .o_eth_reconfig_readdata        (),
    .o_eth_reconfig_readdata_valid  (),
    .i_eth_reconfig_writedata       (32'd0),
    .o_eth_reconfig_waitrequest     (),
    .i_rsfec_reconfig_addr          (11'd0),
    .i_rsfec_reconfig_read          (1'b0),
    .i_rsfec_reconfig_write         (1'b0),
    .o_rsfec_reconfig_readdata      (),
    .i_rsfec_reconfig_writedata     (8'd0),
    .o_rsfec_reconfig_waitrequest   (),
    .i_ptp_reconfig_address         ({2{19'd0}}),
    .i_ptp_reconfig_read            ({2{1'b0}}),
    .i_ptp_reconfig_write           ({2{1'b0}}),
    .o_ptp_reconfig_readdata        (),
    .i_ptp_reconfig_writedata       ({2{8'd0}}),
    .o_ptp_reconfig_waitrequest     (),
    .o_tx_lanes_stable              (mac_tx_lanes_stable[1*1 +: 1]),
    .o_rx_pcs_ready                 (mac_rx_pcs_ready[1*1 +: 1]),
    .o_ehip_ready                   (mac_ehip_ready[1*1 +: 1]),
    .o_rx_block_lock                (),
    .o_rx_am_lock                   (),
    .o_rx_hi_ber                    (),
    .o_local_fault_status           (),
    .o_remote_fault_status          (),
    .i_clk_ref                      (ref_clk),
    .i_clk_tx                       (mac_clk[1*1 +: 1]),
    .i_clk_rx                       (mac_clk[1*1 +: 1]),
    .o_clk_pll_div64                (mac_pll_clk_d64[1*6*1 +: 6*1]),
    .o_clk_pll_div66                (mac_pll_clk_d66[1*6*1 +: 6*1]),
    .o_clk_rec_div64                (mac_rec_clk_d64[1*6*1 +: 6*1]),
    .o_clk_rec_div66                (mac_rec_clk_d66[1*6*1 +: 6*1]),
    .i_csr_rst_n                    (!ctrl_rst),
    .i_tx_rst_n                     (mac_tx_pll_locked[1*1 +: 1]),
    .i_rx_rst_n                     (mac_tx_pll_locked[1*1 +: 1]),
    .o_tx_serial                    (tx_serial_data_p[1*4*1 +: 4*1]),
    .i_rx_serial                    (rx_serial_data_p[1*4*1 +: 4*1]),
    .o_tx_serial_n                  (tx_serial_data_n[1*4*1 +: 4*1]),
    .i_rx_serial_n                  (rx_serial_data_n[1*4*1 +: 4*1]),
    .i_reconfig_clk                 (ctrl_clk),
    .i_reconfig_reset               (ctrl_rst),
    .i_xcvr_reconfig_address        (xcvr_reconfig_address[1*4*19 +: 4*19]),
    .i_xcvr_reconfig_read           (xcvr_reconfig_read[1*4*1 +: 4*1]),
    .i_xcvr_reconfig_write          (xcvr_reconfig_write[1*4*1 +: 4*1]),
    .o_xcvr_reconfig_readdata       (xcvr_reconfig_readdata[1*4*8 +: 4*8]),
    .i_xcvr_reconfig_writedata      (xcvr_reconfig_writedata[1*4*8 +: 4*8]),
    .o_xcvr_reconfig_waitrequest    (xcvr_reconfig_waitrequest[1*4*1 +: 4*1]),
    .i_ptp_tod                      (mac_ptp_tod[1*96 +: 96]),
    .i_ptp_ts_req                   (1'b1),
    .i_ptp_fp                       (mac_ptp_fp[1*8 +: 8]),
    .o_ptp_ets_valid                (mac_ptp_ets_valid[1*1 +: 1]),
    .o_ptp_ets                      (mac_ptp_ets[1*96 +: 96]),
    .o_ptp_ets_fp                   (mac_ptp_ets_fp[1*8 +: 8]),
    .o_ptp_rx_its                   (mac_ptp_rx_its[1*96 +: 96]),
    .o_tx_ptp_ready                 (),
    .o_rx_ptp_ready                 (),
    .i_ptp_ins_ets                  (1'b0),
    .i_ptp_ins_cf                   (1'b0),
    .i_ptp_zero_csum                (1'b0),
    .i_ptp_update_eb                (1'b0),
    .i_ptp_ts_format                (1'b0),
    .i_ptp_ts_offset                (16'd0),
    .i_ptp_cf_offset                (16'd0),
    .i_ptp_csum_offset              (16'd0),
    .i_ptp_eb_offset                (16'd0),
    .i_ptp_tx_its                   (96'd0),
    .o_tx_ready                     (mac_tx_ready[1*1 +: 1]),
    .i_tx_valid                     (mac_tx_valid[1*1 +: 1]),
    .i_tx_data                      (mac_tx_data[1*DATA_WIDTH +: DATA_WIDTH]),
    .i_tx_error                     (mac_tx_error[1*1 +: 1]),
    .i_tx_startofpacket             (mac_tx_startofpacket[1*1 +: 1]),
    .i_tx_endofpacket               (mac_tx_endofpacket[1*1 +: 1]),
    .i_tx_empty                     (mac_tx_empty[1*6 +: 6]),
    .i_tx_skip_crc                  (1'b0),
    .o_rx_valid                     (mac_rx_valid[1*1 +: 1]),
    .o_rx_data                      (mac_rx_data[1*DATA_WIDTH +: DATA_WIDTH]),
    .o_rx_startofpacket             (mac_rx_startofpacket[1*1 +: 1]),
    .o_rx_endofpacket               (mac_rx_endofpacket[1*1 +: 1]),
    .o_rx_empty                     (mac_rx_empty[1*6 +: 6]),
    .o_rx_error                     (mac_rx_error[1*6 +: 6]),
    .o_rxstatus_data                (),
    .o_rxstatus_valid               (),
    .i_tx_pfc                       (8'd0),
    .o_rx_pfc                       (),
    .i_tx_pause                     (1'b0),
    .o_rx_pause                     ()
);

wire [N_CH*DATA_WIDTH-1:0]     mac_rx_axis_tdata;
wire [N_CH*KEEP_WIDTH-1:0]     mac_rx_axis_tkeep;
wire [N_CH-1:0]                mac_rx_axis_tvalid;
wire [N_CH-1:0]                mac_rx_axis_tlast;
wire [N_CH*RX_USER_WIDTH-1:0]  mac_rx_axis_tuser;

wire [N_CH*DATA_WIDTH-1:0]     mac_tx_axis_tdata;
wire [N_CH*KEEP_WIDTH-1:0]     mac_tx_axis_tkeep;
wire [N_CH-1:0]                mac_tx_axis_tvalid;
wire [N_CH-1:0]                mac_tx_axis_tready;
wire [N_CH-1:0]                mac_tx_axis_tlast;
wire [N_CH*TX_USER_WIDTH-1:0]  mac_tx_axis_tuser;

assign mac_clk[0] = mac_pll_clk_d64[4];
assign mac_clk[1] = mac_pll_clk_d64[10];

assign mac_1_clk = mac_clk[0];
assign mac_1_rst = mac_rst[0];

assign mac_ptp_tod[0*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_1_ptp_time;

assign mac_1_tx_ptp_ts = mac_ptp_ets[0*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_1_tx_ptp_ts_tag = mac_ptp_ets_fp[0*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_1_tx_ptp_ts_valid = mac_ptp_ets_valid[0];

assign mac_tx_axis_tdata[0*DATA_WIDTH +: DATA_WIDTH] = mac_1_tx_axis_tdata;
assign mac_tx_axis_tkeep[0*KEEP_WIDTH +: KEEP_WIDTH] = mac_1_tx_axis_tkeep;
assign mac_tx_axis_tvalid[0] = mac_1_tx_axis_tvalid;
assign mac_1_tx_axis_tready = mac_tx_axis_tready[0];
assign mac_tx_axis_tlast[0] = mac_1_tx_axis_tlast;
assign mac_tx_axis_tuser[0*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_1_tx_axis_tuser;

assign mac_1_rx_axis_tdata = mac_rx_axis_tdata[0*DATA_WIDTH +: DATA_WIDTH];
assign mac_1_rx_axis_tkeep = mac_rx_axis_tkeep[0*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_1_rx_axis_tvalid = mac_rx_axis_tvalid[0];
assign mac_1_rx_axis_tlast = mac_rx_axis_tlast[0];
assign mac_1_rx_axis_tuser = mac_rx_axis_tuser[0*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_1_rx_status = mac_rx_pcs_ready[0];

assign mac_2_clk = mac_clk[1];
assign mac_2_rst = mac_rst[1];

assign mac_ptp_tod[1*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_2_ptp_time;

assign mac_2_tx_ptp_ts = mac_ptp_ets[1*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_2_tx_ptp_ts_tag = mac_ptp_ets_fp[1*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_2_tx_ptp_ts_valid = mac_ptp_ets_valid[1];

assign mac_tx_axis_tdata[1*DATA_WIDTH +: DATA_WIDTH] = mac_2_tx_axis_tdata;
assign mac_tx_axis_tkeep[1*KEEP_WIDTH +: KEEP_WIDTH] = mac_2_tx_axis_tkeep;
assign mac_tx_axis_tvalid[1] = mac_2_tx_axis_tvalid;
assign mac_2_tx_axis_tready = mac_tx_axis_tready[1];
assign mac_tx_axis_tlast[1] = mac_2_tx_axis_tlast;
assign mac_tx_axis_tuser[1*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_2_tx_axis_tuser;

assign mac_2_rx_axis_tdata = mac_rx_axis_tdata[1*DATA_WIDTH +: DATA_WIDTH];
assign mac_2_rx_axis_tkeep = mac_rx_axis_tkeep[1*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_2_rx_axis_tvalid = mac_rx_axis_tvalid[1];
assign mac_2_rx_axis_tlast = mac_rx_axis_tlast[1];
assign mac_2_rx_axis_tuser = mac_rx_axis_tuser[1*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_2_rx_status = mac_rx_pcs_ready[1];

generate

genvar m, n;

for (n = 0; n < N_CH; n = n + 1) begin : mac_ch

    sync_reset #(
        .N(4)
    )
    mac_tx_reset_sync_inst (
        .clk(mac_clk[n]),
        .rst(ctrl_rst || !mac_tx_lanes_stable[n] || !mac_ehip_ready[n]),
        .out(mac_rst[n])
    );

    for (m = 0; m < XCVR_PER_MAC; m = m + 1) begin : xcvr_ch

        xcvr_ctrl xcvr_ctrl_inst (
            .reconfig_clk(ctrl_clk),
            .reconfig_rst(ctrl_rst),

            .pll_locked_in(mac_tx_pll_locked[n]),

            .xcvr_reconfig_address(xcvr_reconfig_address[(n*XCVR_PER_MAC+m)*19 +: 19]),
            .xcvr_reconfig_read(xcvr_reconfig_read[(n*XCVR_PER_MAC+m)]),
            .xcvr_reconfig_write(xcvr_reconfig_write[(n*XCVR_PER_MAC+m)]),
            .xcvr_reconfig_readdata(xcvr_reconfig_readdata[(n*XCVR_PER_MAC+m)*8 +: 8]),
            .xcvr_reconfig_writedata(xcvr_reconfig_writedata[(n*XCVR_PER_MAC+m)*8 +: 8]),
            .xcvr_reconfig_waitrequest(xcvr_reconfig_waitrequest[(n*XCVR_PER_MAC+m)])
        );

    end

    axis2avst #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .KEEP_ENABLE(1),
        .EMPTY_WIDTH(6),
        .BYTE_REVERSE(1)
    )
    mac_tx_axis2avst (
        .clk(mac_clk[n]),
        .rst(mac_rst[n]),

        .axis_tdata(mac_tx_axis_tdata[n*DATA_WIDTH +: DATA_WIDTH]),
        .axis_tkeep(mac_tx_axis_tkeep[n*KEEP_WIDTH +: KEEP_WIDTH]),
        .axis_tvalid(mac_tx_axis_tvalid[n]),
        .axis_tready(mac_tx_axis_tready[n]),
        .axis_tlast(mac_tx_axis_tlast[n]),
        .axis_tuser(mac_tx_axis_tuser[n*TX_USER_WIDTH +: 1]),

        .avst_ready(mac_tx_ready[n]),
        .avst_valid(mac_tx_valid[n]),
        .avst_data(mac_tx_data[n*DATA_WIDTH +: DATA_WIDTH]),
        .avst_startofpacket(mac_tx_startofpacket[n]),
        .avst_endofpacket(mac_tx_endofpacket[n]),
        .avst_empty(mac_tx_empty[n*6 +: 6]),
        .avst_error(mac_tx_error[n])
    );

    assign mac_ptp_fp[n*PTP_TAG_WIDTH +: PTP_TAG_WIDTH] = mac_tx_axis_tuser[n*TX_USER_WIDTH+1 +: PTP_TAG_WIDTH];

    wire [DATA_WIDTH-1:0] mac_rx_axis_tdata_int;
    wire [KEEP_WIDTH-1:0] mac_rx_axis_tkeep_int;
    wire                  mac_rx_axis_tvalid_int;
    wire                  mac_rx_axis_tlast_int;
    wire                  mac_rx_axis_tuser_int;

    avst2axis #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .KEEP_ENABLE(1),
        .EMPTY_WIDTH(6),
        .BYTE_REVERSE(1)
    )
    mac_rx_avst2axis (
        .clk(mac_clk[n]),
        .rst(mac_rst[n]),

        .avst_ready(),
        .avst_valid(mac_rx_valid[n]),
        .avst_data(mac_rx_data[n*DATA_WIDTH +: DATA_WIDTH]),
        .avst_startofpacket(mac_rx_startofpacket[n]),
        .avst_endofpacket(mac_rx_endofpacket[n]),
        .avst_empty(mac_rx_empty[n*6 +: 6]),
        .avst_error(mac_rx_error[n*6 +: 6] != 0),

        .axis_tdata(mac_rx_axis_tdata_int),
        .axis_tkeep(mac_rx_axis_tkeep_int),
        .axis_tvalid(mac_rx_axis_tvalid_int),
        .axis_tready(1'b1),
        .axis_tlast(mac_rx_axis_tlast_int),
        .axis_tuser(mac_rx_axis_tuser_int)
    );

    mac_ts_insert #(
        .PTP_TS_WIDTH(PTP_TS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .S_USER_WIDTH(1),
        .M_USER_WIDTH(PTP_TS_WIDTH+1)
    )
    mac_ts_insert_inst (
        .clk(mac_clk[n]),
        .rst(mac_rst[n]),

        /*
         * PTP TS input
         */
        .ptp_ts(mac_ptp_rx_its[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),

        /*
         * AXI input
         */
        .s_axis_tdata(mac_rx_axis_tdata_int),
        .s_axis_tkeep(mac_rx_axis_tkeep_int),
        .s_axis_tvalid(mac_rx_axis_tvalid_int),
        .s_axis_tready(),
        .s_axis_tlast(mac_rx_axis_tlast_int),
        .s_axis_tuser(mac_rx_axis_tuser_int),

        /*
         * AXI output
         */
        .m_axis_tdata(mac_rx_axis_tdata[n*DATA_WIDTH +: DATA_WIDTH]),
        .m_axis_tkeep(mac_rx_axis_tkeep[n*KEEP_WIDTH +: KEEP_WIDTH]),
        .m_axis_tvalid(mac_rx_axis_tvalid[n]),
        .m_axis_tready(1'b1),
        .m_axis_tlast(mac_rx_axis_tlast[n]),
        .m_axis_tuser(mac_rx_axis_tuser[n*RX_USER_WIDTH +: RX_USER_WIDTH])
    );

end

endgenerate

endmodule

`resetall
