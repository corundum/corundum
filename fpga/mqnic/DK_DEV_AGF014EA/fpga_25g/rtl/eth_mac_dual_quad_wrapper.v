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
 * Dual Quad Ethernet MAC wrapper
 */
module eth_mac_dual_quad_wrapper #
(
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_TAG_WIDTH = 8,
    parameter DATA_WIDTH = 64,
    parameter KEEP_WIDTH = DATA_WIDTH/8,
    parameter TX_USER_WIDTH = PTP_TAG_WIDTH+1,
    parameter RX_USER_WIDTH = PTP_TS_WIDTH+1,
    parameter MAC_RSFEC = 0
)
(
    input  wire                      ctrl_clk,
    input  wire                      ctrl_rst,

    output wire [7:0]                tx_serial_data_p,
    output wire [7:0]                tx_serial_data_n,
    input  wire [7:0]                rx_serial_data_p,
    input  wire [7:0]                rx_serial_data_n,
    input  wire                      ref_clk,
    input  wire                      ptp_sample_clk,

    output wire                      mac_1_tx_clk,
    output wire                      mac_1_tx_rst,

    output wire                      mac_1_tx_ptp_clk,
    output wire                      mac_1_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_1_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_1_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_1_tx_ptp_ts_tag,
    output wire                      mac_1_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_1_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_1_tx_axis_tkeep,
    input  wire                      mac_1_tx_axis_tvalid,
    output wire                      mac_1_tx_axis_tready,
    input  wire                      mac_1_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_1_tx_axis_tuser,

    output wire                      mac_1_rx_clk,
    output wire                      mac_1_rx_rst,

    output wire                      mac_1_rx_ptp_clk,
    output wire                      mac_1_rx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_1_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_1_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_1_rx_axis_tkeep,
    output wire                      mac_1_rx_axis_tvalid,
    output wire                      mac_1_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_1_rx_axis_tuser,

    output wire                      mac_1_rx_status,

    output wire                      mac_2_tx_clk,
    output wire                      mac_2_tx_rst,

    output wire                      mac_2_tx_ptp_clk,
    output wire                      mac_2_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_2_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_2_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_2_tx_ptp_ts_tag,
    output wire                      mac_2_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_2_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_2_tx_axis_tkeep,
    input  wire                      mac_2_tx_axis_tvalid,
    output wire                      mac_2_tx_axis_tready,
    input  wire                      mac_2_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_2_tx_axis_tuser,

    output wire                      mac_2_rx_clk,
    output wire                      mac_2_rx_rst,

    output wire                      mac_2_rx_ptp_clk,
    output wire                      mac_2_rx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_2_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_2_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_2_rx_axis_tkeep,
    output wire                      mac_2_rx_axis_tvalid,
    output wire                      mac_2_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_2_rx_axis_tuser,

    output wire                      mac_2_rx_status,

    output wire                      mac_3_tx_clk,
    output wire                      mac_3_tx_rst,

    output wire                      mac_3_tx_ptp_clk,
    output wire                      mac_3_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_3_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_3_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_3_tx_ptp_ts_tag,
    output wire                      mac_3_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_3_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_3_tx_axis_tkeep,
    input  wire                      mac_3_tx_axis_tvalid,
    output wire                      mac_3_tx_axis_tready,
    input  wire                      mac_3_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_3_tx_axis_tuser,

    output wire                      mac_3_rx_clk,
    output wire                      mac_3_rx_rst,

    output wire                      mac_3_rx_ptp_clk,
    output wire                      mac_3_rx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_3_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_3_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_3_rx_axis_tkeep,
    output wire                      mac_3_rx_axis_tvalid,
    output wire                      mac_3_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_3_rx_axis_tuser,

    output wire                      mac_3_rx_status,

    output wire                      mac_4_tx_clk,
    output wire                      mac_4_tx_rst,

    output wire                      mac_4_tx_ptp_clk,
    output wire                      mac_4_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_4_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_4_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_4_tx_ptp_ts_tag,
    output wire                      mac_4_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_4_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_4_tx_axis_tkeep,
    input  wire                      mac_4_tx_axis_tvalid,
    output wire                      mac_4_tx_axis_tready,
    input  wire                      mac_4_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_4_tx_axis_tuser,

    output wire                      mac_4_rx_clk,
    output wire                      mac_4_rx_rst,

    output wire                      mac_4_rx_ptp_clk,
    output wire                      mac_4_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]   mac_4_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_4_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_4_rx_axis_tkeep,
    output wire                      mac_4_rx_axis_tvalid,
    output wire                      mac_4_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_4_rx_axis_tuser,

    output wire                      mac_4_rx_status,

    output wire                      mac_5_tx_clk,
    output wire                      mac_5_tx_rst,

    output wire                      mac_5_tx_ptp_clk,
    output wire                      mac_5_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_5_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_5_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_5_tx_ptp_ts_tag,
    output wire                      mac_5_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_5_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_5_tx_axis_tkeep,
    input  wire                      mac_5_tx_axis_tvalid,
    output wire                      mac_5_tx_axis_tready,
    input  wire                      mac_5_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_5_tx_axis_tuser,

    output wire                      mac_5_rx_clk,
    output wire                      mac_5_rx_rst,

    output wire                      mac_5_rx_ptp_clk,
    output wire                      mac_5_rx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_5_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_5_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_5_rx_axis_tkeep,
    output wire                      mac_5_rx_axis_tvalid,
    output wire                      mac_5_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_5_rx_axis_tuser,

    output wire                      mac_5_rx_status,

    output wire                      mac_6_tx_clk,
    output wire                      mac_6_tx_rst,

    output wire                      mac_6_tx_ptp_clk,
    output wire                      mac_6_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_6_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_6_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_6_tx_ptp_ts_tag,
    output wire                      mac_6_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_6_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_6_tx_axis_tkeep,
    input  wire                      mac_6_tx_axis_tvalid,
    output wire                      mac_6_tx_axis_tready,
    input  wire                      mac_6_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_6_tx_axis_tuser,

    output wire                      mac_6_rx_clk,
    output wire                      mac_6_rx_rst,

    output wire                      mac_6_rx_ptp_clk,
    output wire                      mac_6_rx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_6_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_6_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_6_rx_axis_tkeep,
    output wire                      mac_6_rx_axis_tvalid,
    output wire                      mac_6_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_6_rx_axis_tuser,

    output wire                      mac_6_rx_status,

    output wire                      mac_7_tx_clk,
    output wire                      mac_7_tx_rst,

    output wire                      mac_7_tx_ptp_clk,
    output wire                      mac_7_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_7_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_7_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_7_tx_ptp_ts_tag,
    output wire                      mac_7_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_7_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_7_tx_axis_tkeep,
    input  wire                      mac_7_tx_axis_tvalid,
    output wire                      mac_7_tx_axis_tready,
    input  wire                      mac_7_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_7_tx_axis_tuser,

    output wire                      mac_7_rx_clk,
    output wire                      mac_7_rx_rst,

    output wire                      mac_7_rx_ptp_clk,
    output wire                      mac_7_rx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_7_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_7_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_7_rx_axis_tkeep,
    output wire                      mac_7_rx_axis_tvalid,
    output wire                      mac_7_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_7_rx_axis_tuser,

    output wire                      mac_7_rx_status,

    output wire                      mac_8_tx_clk,
    output wire                      mac_8_tx_rst,

    output wire                      mac_8_tx_ptp_clk,
    output wire                      mac_8_tx_ptp_rst,
    input  wire [PTP_TS_WIDTH-1:0]   mac_8_tx_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_8_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_8_tx_ptp_ts_tag,
    output wire                      mac_8_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_8_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_8_tx_axis_tkeep,
    input  wire                      mac_8_tx_axis_tvalid,
    output wire                      mac_8_tx_axis_tready,
    input  wire                      mac_8_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_8_tx_axis_tuser,

    output wire                      mac_8_rx_clk,
    output wire                      mac_8_rx_rst,

    output wire                      mac_8_rx_ptp_clk,
    output wire                      mac_8_rx_ptp_rst,
    output wire [PTP_TS_WIDTH-1:0]   mac_8_rx_ptp_time,

    output wire [DATA_WIDTH-1:0]     mac_8_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_8_rx_axis_tkeep,
    output wire                      mac_8_rx_axis_tvalid,
    output wire                      mac_8_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_8_rx_axis_tuser,

    output wire                      mac_8_rx_status
);

parameter N_CH = 8;

wire [11:0]  mac_pll_clk_d64;
wire [11:0]  mac_pll_clk_d66;
wire [11:0]  mac_rec_clk_d64;
wire [11:0]  mac_rec_clk_d66;

wire [N_CH-1:0]  mac_tx_pll_locked;

wire [N_CH-1:0]  mac_rx_clk;
wire [N_CH-1:0]  mac_rx_rst;
wire [N_CH-1:0]  mac_tx_clk;
wire [N_CH-1:0]  mac_tx_rst;

wire [N_CH-1:0]  mac_rx_ptp_clk;
wire [N_CH-1:0]  mac_rx_ptp_rst;
wire [N_CH-1:0]  mac_tx_ptp_clk;
wire [N_CH-1:0]  mac_tx_ptp_rst;

wire [N_CH*19-1:0]  xcvr_reconfig_address;
wire [N_CH-1:0]     xcvr_reconfig_read;
wire [N_CH-1:0]     xcvr_reconfig_write;
wire [N_CH*8-1:0]   xcvr_reconfig_readdata;
wire [N_CH*8-1:0]   xcvr_reconfig_writedata;
wire [N_CH-1:0]     xcvr_reconfig_waitrequest;

wire [N_CH-1:0]  mac_tx_lanes_stable;
wire [N_CH-1:0]  mac_rx_pcs_ready;
wire [N_CH-1:0]  mac_ehip_ready;

wire [N_CH*PTP_TS_WIDTH-1:0]   mac_ptp_tx_tod;
wire [N_CH*PTP_TS_WIDTH-1:0]   mac_ptp_rx_tod;
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
wire [N_CH*3-1:0]              mac_tx_empty;

wire [N_CH-1:0]                mac_rx_valid;
wire [N_CH*DATA_WIDTH-1:0]     mac_rx_data;
wire [N_CH-1:0]                mac_rx_startofpacket;
wire [N_CH-1:0]                mac_rx_endofpacket;
wire [N_CH*3-1:0]              mac_rx_empty;
wire [N_CH*6-1:0]              mac_rx_error;

generate

if (MAC_RSFEC) begin

    mac_rsfec_02 mac_02_inst (
        .o_cdr_lock                       (),
        .o_tx_pll_locked                  (mac_tx_pll_locked[0*4*1 +: 4*1]),
        .i_eth_reconfig_addr              (21'd0),
        .i_eth_reconfig_read              (1'b0),
        .i_eth_reconfig_write             (1'b0),
        .o_eth_reconfig_readdata          (),
        .o_eth_reconfig_readdata_valid    (),
        .i_eth_reconfig_writedata         (32'd0),
        .o_eth_reconfig_waitrequest       (),
        .i_rsfec_reconfig_addr            (11'd0),
        .i_rsfec_reconfig_read            (1'b0),
        .i_rsfec_reconfig_write           (1'b0),
        .o_rsfec_reconfig_readdata        (),
        .i_rsfec_reconfig_writedata       (8'd0),
        .o_rsfec_reconfig_waitrequest     (),
        .i_ptp_reconfig_address           ({2{19'd0}}),
        .i_ptp_reconfig_read              ({2{1'b0}}),
        .i_ptp_reconfig_write             ({2{1'b0}}),
        .o_ptp_reconfig_readdata          (),
        .i_ptp_reconfig_writedata         ({2{8'd0}}),
        .o_ptp_reconfig_waitrequest       (),
        .i_clk_ref                        ({4{ref_clk}}),
        .o_clk_pll_div64                  (mac_pll_clk_d64[0*6*1 +: 6*1]),
        .o_clk_pll_div66                  (mac_pll_clk_d66[0*6*1 +: 6*1]),
        .o_clk_rec_div64                  (mac_rec_clk_d64[0*6*1 +: 6*1]),
        .o_clk_rec_div66                  (mac_rec_clk_d66[0*6*1 +: 6*1]),
        .i_csr_rst_n                      (~ctrl_rst),
        .o_tx_serial                      (tx_serial_data_p[0*4*1 +: 4*1]),
        .i_rx_serial                      (rx_serial_data_p[0*4*1 +: 4*1]),
        .o_tx_serial_n                    (tx_serial_data_n[0*4*1 +: 4*1]),
        .i_rx_serial_n                    (rx_serial_data_n[0*4*1 +: 4*1]),
        .i_reconfig_clk                   (ctrl_clk),
        .i_reconfig_reset                 (ctrl_rst),
        .i_xcvr_reconfig_address          (xcvr_reconfig_address[0*4*19 +: 4*19]),
        .i_xcvr_reconfig_read             (xcvr_reconfig_read[0*4*1 +: 4*1]),
        .i_xcvr_reconfig_write            (xcvr_reconfig_write[0*4*1 +: 4*1]),
        .o_xcvr_reconfig_readdata         (xcvr_reconfig_readdata[0*4*8 +: 4*8]),
        .i_xcvr_reconfig_writedata        (xcvr_reconfig_writedata[0*4*8 +: 4*8]),
        .o_xcvr_reconfig_waitrequest      (xcvr_reconfig_waitrequest[0*4*1 +: 4*1]),
        .i_sl_stats_snapshot              ({4{1'b0}}),
        .o_sl_rx_hi_ber                   (),
        .i_sl_eth_reconfig_addr           ({4{19'd0}}),
        .i_sl_eth_reconfig_read           ({4{1'b0}}),
        .i_sl_eth_reconfig_write          ({4{1'b0}}),
        .o_sl_eth_reconfig_readdata       (),
        .o_sl_eth_reconfig_readdata_valid (),
        .i_sl_eth_reconfig_writedata      ({4{32'd0}}),
        .o_sl_eth_reconfig_waitrequest    (),
        .o_sl_tx_lanes_stable             (mac_tx_lanes_stable[0*4*1 +: 4*1]),
        .o_sl_rx_pcs_ready                (mac_rx_pcs_ready[0*4*1 +: 4*1]),
        .o_sl_ehip_ready                  (mac_ehip_ready[0*4*1 +: 4*1]),
        .o_sl_rx_block_lock               (),
        .o_sl_local_fault_status          (),
        .o_sl_remote_fault_status         (),
        .i_sl_clk_tx                      (mac_tx_clk[0*4*1 +: 4*1]),
        .i_sl_clk_rx                      (mac_rx_clk[0*4*1 +: 4*1]),
        .i_sl_clk_tx_tod                  (mac_tx_ptp_clk[0*4*1 +: 4*1]),
        .i_sl_clk_rx_tod                  (mac_rx_ptp_clk[0*4*1 +: 4*1]),
        .i_sl_csr_rst_n                   ({4{!ctrl_rst}}),
        .i_sl_tx_rst_n                    (mac_tx_pll_locked[0*4*1 +: 4*1]),
        .i_sl_rx_rst_n                    (mac_tx_pll_locked[0*4*1 +: 4*1]),
        .o_sl_txfifo_pfull                (),
        .o_sl_txfifo_pempty               (),
        .o_sl_txfifo_overflow             (),
        .o_sl_txfifo_underflow            (),
        .o_sl_tx_ready                    (mac_tx_ready[0*4*1 +: 4*1]),
        .o_sl_rx_valid                    (mac_rx_valid[0*4*1 +: 4*1]),
        .i_sl_tx_valid                    (mac_tx_valid[0*4*1 +: 4*1]),
        .i_sl_tx_data                     (mac_tx_data[0*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .o_sl_rx_data                     (mac_rx_data[0*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .i_sl_tx_error                    (mac_tx_error[0*4*1 +: 4*1]),
        .i_sl_tx_startofpacket            (mac_tx_startofpacket[0*4*1 +: 4*1]),
        .i_sl_tx_endofpacket              (mac_tx_endofpacket[0*4*1 +: 4*1]),
        .i_sl_tx_empty                    (mac_tx_empty[0*4*3 +: 4*3]),
        .i_sl_tx_skip_crc                 ({4{1'b0}}),
        .o_sl_rx_startofpacket            (mac_rx_startofpacket[0*4*1 +: 4*1]),
        .o_sl_rx_endofpacket              (mac_rx_endofpacket[0*4*1 +: 4*1]),
        .o_sl_rx_empty                    (mac_rx_empty[0*4*3 +: 4*3]),
        .o_sl_rx_error                    (mac_rx_error[0*4*6 +: 4*6]),
        .o_sl_rxstatus_data               (),
        .o_sl_rxstatus_valid              (),
        .i_sl_tx_pfc                      ({4{8'd0}}),
        .o_sl_rx_pfc                      (),
        .i_sl_tx_pause                    ({4{1'b0}}),
        .o_sl_rx_pause                    (),
        .i_sl_ptp_tx_tod                  (mac_ptp_tx_tod[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_rx_tod                  (mac_ptp_rx_tod[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_ts_req                  ({4{1'b1}}),
        .i_sl_ptp_fp                      (mac_ptp_fp[0*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_ets_valid               (mac_ptp_ets_valid[0*4*1 +: 4*1]),
        .o_sl_ptp_ets                     (mac_ptp_ets[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_ptp_ets_fp                  (mac_ptp_ets_fp[0*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_rx_its                  (mac_ptp_rx_its[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_tx_ptp_ready                (),
        .o_sl_rx_ptp_ready                (),
        .i_clk_ptp_sample                 (ptp_sample_clk),
        .i_sl_ptp_ins_ets                 ({4{1'b0}}),
        .i_sl_ptp_ins_cf                  ({4{1'b0}}),
        .i_sl_ptp_zero_csum               ({4{1'b0}}),
        .i_sl_ptp_update_eb               ({4{1'b0}}),
        .i_sl_ptp_ts_format               ({4{1'b0}}),
        .i_sl_ptp_ts_offset               ({4{16'd0}}),
        .i_sl_ptp_cf_offset               ({4{16'd0}}),
        .i_sl_ptp_csum_offset             ({4{16'd0}}),
        .i_sl_ptp_eb_offset               ({4{16'd0}}),
        .i_sl_ptp_tx_its                  ({4{96'd0}})
    );

    mac_rsfec_13 mac_13_inst (
        .o_cdr_lock                       (),
        .o_tx_pll_locked                  (mac_tx_pll_locked[1*4*1 +: 4*1]),
        .i_eth_reconfig_addr              (21'd0),
        .i_eth_reconfig_read              (1'b0),
        .i_eth_reconfig_write             (1'b0),
        .o_eth_reconfig_readdata          (),
        .o_eth_reconfig_readdata_valid    (),
        .i_eth_reconfig_writedata         (32'd0),
        .o_eth_reconfig_waitrequest       (),
        .i_rsfec_reconfig_addr            (11'd0),
        .i_rsfec_reconfig_read            (1'b0),
        .i_rsfec_reconfig_write           (1'b0),
        .o_rsfec_reconfig_readdata        (),
        .i_rsfec_reconfig_writedata       (8'd0),
        .o_rsfec_reconfig_waitrequest     (),
        .i_ptp_reconfig_address           ({2{19'd0}}),
        .i_ptp_reconfig_read              ({2{1'b0}}),
        .i_ptp_reconfig_write             ({2{1'b0}}),
        .o_ptp_reconfig_readdata          (),
        .i_ptp_reconfig_writedata         ({2{8'd0}}),
        .o_ptp_reconfig_waitrequest       (),
        .i_clk_ref                        ({4{ref_clk}}),
        .o_clk_pll_div64                  (mac_pll_clk_d64[1*6*1 +: 6*1]),
        .o_clk_pll_div66                  (mac_pll_clk_d66[1*6*1 +: 6*1]),
        .o_clk_rec_div64                  (mac_rec_clk_d64[1*6*1 +: 6*1]),
        .o_clk_rec_div66                  (mac_rec_clk_d66[1*6*1 +: 6*1]),
        .i_csr_rst_n                      (~ctrl_rst),
        .o_tx_serial                      (tx_serial_data_p[1*4*1 +: 4*1]),
        .i_rx_serial                      (rx_serial_data_p[1*4*1 +: 4*1]),
        .o_tx_serial_n                    (tx_serial_data_n[1*4*1 +: 4*1]),
        .i_rx_serial_n                    (rx_serial_data_n[1*4*1 +: 4*1]),
        .i_reconfig_clk                   (ctrl_clk),
        .i_reconfig_reset                 (ctrl_rst),
        .i_xcvr_reconfig_address          (xcvr_reconfig_address[1*4*19 +: 4*19]),
        .i_xcvr_reconfig_read             (xcvr_reconfig_read[1*4*1 +: 4*1]),
        .i_xcvr_reconfig_write            (xcvr_reconfig_write[1*4*1 +: 4*1]),
        .o_xcvr_reconfig_readdata         (xcvr_reconfig_readdata[1*4*8 +: 4*8]),
        .i_xcvr_reconfig_writedata        (xcvr_reconfig_writedata[1*4*8 +: 4*8]),
        .o_xcvr_reconfig_waitrequest      (xcvr_reconfig_waitrequest[1*4*1 +: 4*1]),
        .i_sl_stats_snapshot              ({4{1'b0}}),
        .o_sl_rx_hi_ber                   (),
        .i_sl_eth_reconfig_addr           ({4{19'd0}}),
        .i_sl_eth_reconfig_read           ({4{1'b0}}),
        .i_sl_eth_reconfig_write          ({4{1'b0}}),
        .o_sl_eth_reconfig_readdata       (),
        .o_sl_eth_reconfig_readdata_valid (),
        .i_sl_eth_reconfig_writedata      ({4{32'd0}}),
        .o_sl_eth_reconfig_waitrequest    (),
        .o_sl_tx_lanes_stable             (mac_tx_lanes_stable[1*4*1 +: 4*1]),
        .o_sl_rx_pcs_ready                (mac_rx_pcs_ready[1*4*1 +: 4*1]),
        .o_sl_ehip_ready                  (mac_ehip_ready[1*4*1 +: 4*1]),
        .o_sl_rx_block_lock               (),
        .o_sl_local_fault_status          (),
        .o_sl_remote_fault_status         (),
        .i_sl_clk_tx                      (mac_tx_clk[1*4*1 +: 4*1]),
        .i_sl_clk_rx                      (mac_rx_clk[1*4*1 +: 4*1]),
        .i_sl_clk_tx_tod                  (mac_tx_ptp_clk[1*4*1 +: 4*1]),
        .i_sl_clk_rx_tod                  (mac_rx_ptp_clk[1*4*1 +: 4*1]),
        .i_sl_csr_rst_n                   ({4{!ctrl_rst}}),
        .i_sl_tx_rst_n                    (mac_tx_pll_locked[1*4*1 +: 4*1]),
        .i_sl_rx_rst_n                    (mac_tx_pll_locked[1*4*1 +: 4*1]),
        .o_sl_txfifo_pfull                (),
        .o_sl_txfifo_pempty               (),
        .o_sl_txfifo_overflow             (),
        .o_sl_txfifo_underflow            (),
        .o_sl_tx_ready                    (mac_tx_ready[1*4*1 +: 4*1]),
        .o_sl_rx_valid                    (mac_rx_valid[1*4*1 +: 4*1]),
        .i_sl_tx_valid                    (mac_tx_valid[1*4*1 +: 4*1]),
        .i_sl_tx_data                     (mac_tx_data[1*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .o_sl_rx_data                     (mac_rx_data[1*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .i_sl_tx_error                    (mac_tx_error[1*4*1 +: 4*1]),
        .i_sl_tx_startofpacket            (mac_tx_startofpacket[1*4*1 +: 4*1]),
        .i_sl_tx_endofpacket              (mac_tx_endofpacket[1*4*1 +: 4*1]),
        .i_sl_tx_empty                    (mac_tx_empty[1*4*3 +: 4*3]),
        .i_sl_tx_skip_crc                 ({4{1'b0}}),
        .o_sl_rx_startofpacket            (mac_rx_startofpacket[1*4*1 +: 4*1]),
        .o_sl_rx_endofpacket              (mac_rx_endofpacket[1*4*1 +: 4*1]),
        .o_sl_rx_empty                    (mac_rx_empty[1*4*3 +: 4*3]),
        .o_sl_rx_error                    (mac_rx_error[1*4*6 +: 4*6]),
        .o_sl_rxstatus_data               (),
        .o_sl_rxstatus_valid              (),
        .i_sl_tx_pfc                      ({4{8'd0}}),
        .o_sl_rx_pfc                      (),
        .i_sl_tx_pause                    ({4{1'b0}}),
        .o_sl_rx_pause                    (),
        .i_sl_ptp_tx_tod                  (mac_ptp_tx_tod[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_rx_tod                  (mac_ptp_rx_tod[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_ts_req                  ({4{1'b1}}),
        .i_sl_ptp_fp                      (mac_ptp_fp[1*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_ets_valid               (mac_ptp_ets_valid[1*4*1 +: 4*1]),
        .o_sl_ptp_ets                     (mac_ptp_ets[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_ptp_ets_fp                  (mac_ptp_ets_fp[1*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_rx_its                  (mac_ptp_rx_its[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_tx_ptp_ready                (),
        .o_sl_rx_ptp_ready                (),
        .i_clk_ptp_sample                 (ptp_sample_clk),
        .i_sl_ptp_ins_ets                 ({4{1'b0}}),
        .i_sl_ptp_ins_cf                  ({4{1'b0}}),
        .i_sl_ptp_zero_csum               ({4{1'b0}}),
        .i_sl_ptp_update_eb               ({4{1'b0}}),
        .i_sl_ptp_ts_format               ({4{1'b0}}),
        .i_sl_ptp_ts_offset               ({4{16'd0}}),
        .i_sl_ptp_cf_offset               ({4{16'd0}}),
        .i_sl_ptp_csum_offset             ({4{16'd0}}),
        .i_sl_ptp_eb_offset               ({4{16'd0}}),
        .i_sl_ptp_tx_its                  ({4{96'd0}})
    );

end else begin

    mac_02 mac_02_inst (
        .o_cdr_lock                       (),
        .o_tx_pll_locked                  (mac_tx_pll_locked[0*4*1 +: 4*1]),
        .i_eth_reconfig_addr              (21'd0),
        .i_eth_reconfig_read              (1'b0),
        .i_eth_reconfig_write             (1'b0),
        .o_eth_reconfig_readdata          (),
        .o_eth_reconfig_readdata_valid    (),
        .i_eth_reconfig_writedata         (32'd0),
        .o_eth_reconfig_waitrequest       (),
        .i_ptp_reconfig_address           ({2{19'd0}}),
        .i_ptp_reconfig_read              ({2{1'b0}}),
        .i_ptp_reconfig_write             ({2{1'b0}}),
        .o_ptp_reconfig_readdata          (),
        .i_ptp_reconfig_writedata         ({2{8'd0}}),
        .o_ptp_reconfig_waitrequest       (),
        .i_clk_ref                        ({4{ref_clk}}),
        .o_clk_pll_div64                  (mac_pll_clk_d64[0*6*1 +: 6*1]),
        .o_clk_pll_div66                  (mac_pll_clk_d66[0*6*1 +: 6*1]),
        .o_clk_rec_div64                  (mac_rec_clk_d64[0*6*1 +: 6*1]),
        .o_clk_rec_div66                  (mac_rec_clk_d66[0*6*1 +: 6*1]),
        .i_csr_rst_n                      (~ctrl_rst),
        .o_tx_serial                      (tx_serial_data_p[0*4*1 +: 4*1]),
        .i_rx_serial                      (rx_serial_data_p[0*4*1 +: 4*1]),
        .o_tx_serial_n                    (tx_serial_data_n[0*4*1 +: 4*1]),
        .i_rx_serial_n                    (rx_serial_data_n[0*4*1 +: 4*1]),
        .i_reconfig_clk                   (ctrl_clk),
        .i_reconfig_reset                 (ctrl_rst),
        .i_xcvr_reconfig_address          (xcvr_reconfig_address[0*4*19 +: 4*19]),
        .i_xcvr_reconfig_read             (xcvr_reconfig_read[0*4*1 +: 4*1]),
        .i_xcvr_reconfig_write            (xcvr_reconfig_write[0*4*1 +: 4*1]),
        .o_xcvr_reconfig_readdata         (xcvr_reconfig_readdata[0*4*8 +: 4*8]),
        .i_xcvr_reconfig_writedata        (xcvr_reconfig_writedata[0*4*8 +: 4*8]),
        .o_xcvr_reconfig_waitrequest      (xcvr_reconfig_waitrequest[0*4*1 +: 4*1]),
        .i_sl_stats_snapshot              ({4{1'b0}}),
        .o_sl_rx_hi_ber                   (),
        .i_sl_eth_reconfig_addr           ({4{19'd0}}),
        .i_sl_eth_reconfig_read           ({4{1'b0}}),
        .i_sl_eth_reconfig_write          ({4{1'b0}}),
        .o_sl_eth_reconfig_readdata       (),
        .o_sl_eth_reconfig_readdata_valid (),
        .i_sl_eth_reconfig_writedata      ({4{32'd0}}),
        .o_sl_eth_reconfig_waitrequest    (),
        .o_sl_tx_lanes_stable             (mac_tx_lanes_stable[0*4*1 +: 4*1]),
        .o_sl_rx_pcs_ready                (mac_rx_pcs_ready[0*4*1 +: 4*1]),
        .o_sl_ehip_ready                  (mac_ehip_ready[0*4*1 +: 4*1]),
        .o_sl_rx_block_lock               (),
        .o_sl_local_fault_status          (),
        .o_sl_remote_fault_status         (),
        .i_sl_clk_tx                      (mac_tx_clk[0*4*1 +: 4*1]),
        .i_sl_clk_rx                      (mac_rx_clk[0*4*1 +: 4*1]),
        .i_sl_clk_tx_tod                  (mac_tx_ptp_clk[0*4*1 +: 4*1]),
        .i_sl_clk_rx_tod                  (mac_rx_ptp_clk[0*4*1 +: 4*1]),
        .i_sl_csr_rst_n                   ({4{!ctrl_rst}}),
        .i_sl_tx_rst_n                    (mac_tx_pll_locked[0*4*1 +: 4*1]),
        .i_sl_rx_rst_n                    (mac_tx_pll_locked[0*4*1 +: 4*1]),
        .o_sl_txfifo_pfull                (),
        .o_sl_txfifo_pempty               (),
        .o_sl_txfifo_overflow             (),
        .o_sl_txfifo_underflow            (),
        .o_sl_tx_ready                    (mac_tx_ready[0*4*1 +: 4*1]),
        .o_sl_rx_valid                    (mac_rx_valid[0*4*1 +: 4*1]),
        .i_sl_tx_valid                    (mac_tx_valid[0*4*1 +: 4*1]),
        .i_sl_tx_data                     (mac_tx_data[0*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .o_sl_rx_data                     (mac_rx_data[0*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .i_sl_tx_error                    (mac_tx_error[0*4*1 +: 4*1]),
        .i_sl_tx_startofpacket            (mac_tx_startofpacket[0*4*1 +: 4*1]),
        .i_sl_tx_endofpacket              (mac_tx_endofpacket[0*4*1 +: 4*1]),
        .i_sl_tx_empty                    (mac_tx_empty[0*4*3 +: 4*3]),
        .i_sl_tx_skip_crc                 ({4{1'b0}}),
        .o_sl_rx_startofpacket            (mac_rx_startofpacket[0*4*1 +: 4*1]),
        .o_sl_rx_endofpacket              (mac_rx_endofpacket[0*4*1 +: 4*1]),
        .o_sl_rx_empty                    (mac_rx_empty[0*4*3 +: 4*3]),
        .o_sl_rx_error                    (mac_rx_error[0*4*6 +: 4*6]),
        .o_sl_rxstatus_data               (),
        .o_sl_rxstatus_valid              (),
        .i_sl_tx_pfc                      ({4{8'd0}}),
        .o_sl_rx_pfc                      (),
        .i_sl_tx_pause                    ({4{1'b0}}),
        .o_sl_rx_pause                    (),
        .i_sl_ptp_tx_tod                  (mac_ptp_tx_tod[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_rx_tod                  (mac_ptp_rx_tod[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_ts_req                  ({4{1'b1}}),
        .i_sl_ptp_fp                      (mac_ptp_fp[0*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_ets_valid               (mac_ptp_ets_valid[0*4*1 +: 4*1]),
        .o_sl_ptp_ets                     (mac_ptp_ets[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_ptp_ets_fp                  (mac_ptp_ets_fp[0*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_rx_its                  (mac_ptp_rx_its[0*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_tx_ptp_ready                (),
        .o_sl_rx_ptp_ready                (),
        .i_clk_ptp_sample                 (ptp_sample_clk),
        .i_sl_ptp_ins_ets                 ({4{1'b0}}),
        .i_sl_ptp_ins_cf                  ({4{1'b0}}),
        .i_sl_ptp_zero_csum               ({4{1'b0}}),
        .i_sl_ptp_update_eb               ({4{1'b0}}),
        .i_sl_ptp_ts_format               ({4{1'b0}}),
        .i_sl_ptp_ts_offset               ({4{16'd0}}),
        .i_sl_ptp_cf_offset               ({4{16'd0}}),
        .i_sl_ptp_csum_offset             ({4{16'd0}}),
        .i_sl_ptp_eb_offset               ({4{16'd0}}),
        .i_sl_ptp_tx_its                  ({4{96'd0}})
    );

    mac_13 mac_13_inst (
        .o_cdr_lock                       (),
        .o_tx_pll_locked                  (mac_tx_pll_locked[1*4*1 +: 4*1]),
        .i_eth_reconfig_addr              (21'd0),
        .i_eth_reconfig_read              (1'b0),
        .i_eth_reconfig_write             (1'b0),
        .o_eth_reconfig_readdata          (),
        .o_eth_reconfig_readdata_valid    (),
        .i_eth_reconfig_writedata         (32'd0),
        .o_eth_reconfig_waitrequest       (),
        .i_ptp_reconfig_address           ({2{19'd0}}),
        .i_ptp_reconfig_read              ({2{1'b0}}),
        .i_ptp_reconfig_write             ({2{1'b0}}),
        .o_ptp_reconfig_readdata          (),
        .i_ptp_reconfig_writedata         ({2{8'd0}}),
        .o_ptp_reconfig_waitrequest       (),
        .i_clk_ref                        ({4{ref_clk}}),
        .o_clk_pll_div64                  (mac_pll_clk_d64[1*6*1 +: 6*1]),
        .o_clk_pll_div66                  (mac_pll_clk_d66[1*6*1 +: 6*1]),
        .o_clk_rec_div64                  (mac_rec_clk_d64[1*6*1 +: 6*1]),
        .o_clk_rec_div66                  (mac_rec_clk_d66[1*6*1 +: 6*1]),
        .i_csr_rst_n                      (~ctrl_rst),
        .o_tx_serial                      (tx_serial_data_p[1*4*1 +: 4*1]),
        .i_rx_serial                      (rx_serial_data_p[1*4*1 +: 4*1]),
        .o_tx_serial_n                    (tx_serial_data_n[1*4*1 +: 4*1]),
        .i_rx_serial_n                    (rx_serial_data_n[1*4*1 +: 4*1]),
        .i_reconfig_clk                   (ctrl_clk),
        .i_reconfig_reset                 (ctrl_rst),
        .i_xcvr_reconfig_address          (xcvr_reconfig_address[1*4*19 +: 4*19]),
        .i_xcvr_reconfig_read             (xcvr_reconfig_read[1*4*1 +: 4*1]),
        .i_xcvr_reconfig_write            (xcvr_reconfig_write[1*4*1 +: 4*1]),
        .o_xcvr_reconfig_readdata         (xcvr_reconfig_readdata[1*4*8 +: 4*8]),
        .i_xcvr_reconfig_writedata        (xcvr_reconfig_writedata[1*4*8 +: 4*8]),
        .o_xcvr_reconfig_waitrequest      (xcvr_reconfig_waitrequest[1*4*1 +: 4*1]),
        .i_sl_stats_snapshot              ({4{1'b0}}),
        .o_sl_rx_hi_ber                   (),
        .i_sl_eth_reconfig_addr           ({4{19'd0}}),
        .i_sl_eth_reconfig_read           ({4{1'b0}}),
        .i_sl_eth_reconfig_write          ({4{1'b0}}),
        .o_sl_eth_reconfig_readdata       (),
        .o_sl_eth_reconfig_readdata_valid (),
        .i_sl_eth_reconfig_writedata      ({4{32'd0}}),
        .o_sl_eth_reconfig_waitrequest    (),
        .o_sl_tx_lanes_stable             (mac_tx_lanes_stable[1*4*1 +: 4*1]),
        .o_sl_rx_pcs_ready                (mac_rx_pcs_ready[1*4*1 +: 4*1]),
        .o_sl_ehip_ready                  (mac_ehip_ready[1*4*1 +: 4*1]),
        .o_sl_rx_block_lock               (),
        .o_sl_local_fault_status          (),
        .o_sl_remote_fault_status         (),
        .i_sl_clk_tx                      (mac_tx_clk[1*4*1 +: 4*1]),
        .i_sl_clk_rx                      (mac_rx_clk[1*4*1 +: 4*1]),
        .i_sl_clk_tx_tod                  (mac_tx_ptp_clk[1*4*1 +: 4*1]),
        .i_sl_clk_rx_tod                  (mac_rx_ptp_clk[1*4*1 +: 4*1]),
        .i_sl_csr_rst_n                   ({4{!ctrl_rst}}),
        .i_sl_tx_rst_n                    (mac_tx_pll_locked[1*4*1 +: 4*1]),
        .i_sl_rx_rst_n                    (mac_tx_pll_locked[1*4*1 +: 4*1]),
        .o_sl_txfifo_pfull                (),
        .o_sl_txfifo_pempty               (),
        .o_sl_txfifo_overflow             (),
        .o_sl_txfifo_underflow            (),
        .o_sl_tx_ready                    (mac_tx_ready[1*4*1 +: 4*1]),
        .o_sl_rx_valid                    (mac_rx_valid[1*4*1 +: 4*1]),
        .i_sl_tx_valid                    (mac_tx_valid[1*4*1 +: 4*1]),
        .i_sl_tx_data                     (mac_tx_data[1*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .o_sl_rx_data                     (mac_rx_data[1*4*DATA_WIDTH +: 4*DATA_WIDTH]),
        .i_sl_tx_error                    (mac_tx_error[1*4*1 +: 4*1]),
        .i_sl_tx_startofpacket            (mac_tx_startofpacket[1*4*1 +: 4*1]),
        .i_sl_tx_endofpacket              (mac_tx_endofpacket[1*4*1 +: 4*1]),
        .i_sl_tx_empty                    (mac_tx_empty[1*4*3 +: 4*3]),
        .i_sl_tx_skip_crc                 ({4{1'b0}}),
        .o_sl_rx_startofpacket            (mac_rx_startofpacket[1*4*1 +: 4*1]),
        .o_sl_rx_endofpacket              (mac_rx_endofpacket[1*4*1 +: 4*1]),
        .o_sl_rx_empty                    (mac_rx_empty[1*4*3 +: 4*3]),
        .o_sl_rx_error                    (mac_rx_error[1*4*6 +: 4*6]),
        .o_sl_rxstatus_data               (),
        .o_sl_rxstatus_valid              (),
        .i_sl_tx_pfc                      ({4{8'd0}}),
        .o_sl_rx_pfc                      (),
        .i_sl_tx_pause                    ({4{1'b0}}),
        .o_sl_rx_pause                    (),
        .i_sl_ptp_tx_tod                  (mac_ptp_tx_tod[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_rx_tod                  (mac_ptp_rx_tod[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .i_sl_ptp_ts_req                  ({4{1'b1}}),
        .i_sl_ptp_fp                      (mac_ptp_fp[1*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_ets_valid               (mac_ptp_ets_valid[1*4*1 +: 4*1]),
        .o_sl_ptp_ets                     (mac_ptp_ets[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_ptp_ets_fp                  (mac_ptp_ets_fp[1*4*PTP_TAG_WIDTH +: 4*PTP_TAG_WIDTH]),
        .o_sl_ptp_rx_its                  (mac_ptp_rx_its[1*4*PTP_TS_WIDTH +: 4*PTP_TS_WIDTH]),
        .o_sl_tx_ptp_ready                (),
        .o_sl_rx_ptp_ready                (),
        .i_clk_ptp_sample                 (ptp_sample_clk),
        .i_sl_ptp_ins_ets                 ({4{1'b0}}),
        .i_sl_ptp_ins_cf                  ({4{1'b0}}),
        .i_sl_ptp_zero_csum               ({4{1'b0}}),
        .i_sl_ptp_update_eb               ({4{1'b0}}),
        .i_sl_ptp_ts_format               ({4{1'b0}}),
        .i_sl_ptp_ts_offset               ({4{16'd0}}),
        .i_sl_ptp_cf_offset               ({4{16'd0}}),
        .i_sl_ptp_csum_offset             ({4{16'd0}}),
        .i_sl_ptp_eb_offset               ({4{16'd0}}),
        .i_sl_ptp_tx_its                  ({4{96'd0}})
    );

end

endgenerate

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

assign mac_tx_clk[3:0] = {4{mac_pll_clk_d64[4]}};
assign mac_rx_clk[3:0] = mac_tx_clk[3:0];

assign mac_tx_ptp_clk[3:0] = mac_pll_clk_d66[3:0];
assign mac_rx_ptp_clk[3:0] = mac_rec_clk_d66[3:0];

assign mac_tx_clk[7:4] = {4{mac_pll_clk_d64[10]}};
assign mac_rx_clk[7:4] = mac_tx_clk[7:4];

assign mac_tx_ptp_clk[7:4] = mac_pll_clk_d66[9:6];
assign mac_rx_ptp_clk[7:4] = mac_rec_clk_d66[9:6];

assign mac_1_tx_clk = mac_tx_clk[0];
assign mac_1_tx_rst = mac_tx_rst[0];

assign mac_1_tx_ptp_clk = mac_tx_ptp_clk[0];
assign mac_1_tx_ptp_rst = mac_tx_ptp_rst[0];
assign mac_ptp_tx_tod[0*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_1_tx_ptp_time;

assign mac_1_tx_ptp_ts = mac_ptp_ets[0*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_1_tx_ptp_ts_tag = mac_ptp_ets_fp[0*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_1_tx_ptp_ts_valid = mac_ptp_ets_valid[0];

assign mac_tx_axis_tdata[0*DATA_WIDTH +: DATA_WIDTH] = mac_1_tx_axis_tdata;
assign mac_tx_axis_tkeep[0*KEEP_WIDTH +: KEEP_WIDTH] = mac_1_tx_axis_tkeep;
assign mac_tx_axis_tvalid[0] = mac_1_tx_axis_tvalid;
assign mac_1_tx_axis_tready = mac_tx_axis_tready[0];
assign mac_tx_axis_tlast[0] = mac_1_tx_axis_tlast;
assign mac_tx_axis_tuser[0*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_1_tx_axis_tuser;

assign mac_1_rx_clk = mac_rx_clk[0];
assign mac_1_rx_rst = mac_rx_rst[0];

assign mac_1_rx_ptp_clk = mac_rx_ptp_clk[0];
assign mac_1_rx_ptp_rst = mac_rx_ptp_rst[0];
assign mac_ptp_rx_tod[0*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_1_rx_ptp_time;

assign mac_1_rx_axis_tdata = mac_rx_axis_tdata[0*DATA_WIDTH +: DATA_WIDTH];
assign mac_1_rx_axis_tkeep = mac_rx_axis_tkeep[0*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_1_rx_axis_tvalid = mac_rx_axis_tvalid[0];
assign mac_1_rx_axis_tlast = mac_rx_axis_tlast[0];
assign mac_1_rx_axis_tuser = mac_rx_axis_tuser[0*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_1_rx_status = mac_rx_pcs_ready[0];

assign mac_2_tx_clk = mac_tx_clk[1];
assign mac_2_tx_rst = mac_tx_rst[1];

assign mac_2_tx_ptp_clk = mac_tx_ptp_clk[1];
assign mac_2_tx_ptp_rst = mac_tx_ptp_rst[1];
assign mac_ptp_tx_tod[1*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_2_tx_ptp_time;

assign mac_2_tx_ptp_ts = mac_ptp_ets[1*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_2_tx_ptp_ts_tag = mac_ptp_ets_fp[1*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_2_tx_ptp_ts_valid = mac_ptp_ets_valid[1];

assign mac_tx_axis_tdata[1*DATA_WIDTH +: DATA_WIDTH] = mac_2_tx_axis_tdata;
assign mac_tx_axis_tkeep[1*KEEP_WIDTH +: KEEP_WIDTH] = mac_2_tx_axis_tkeep;
assign mac_tx_axis_tvalid[1] = mac_2_tx_axis_tvalid;
assign mac_2_tx_axis_tready = mac_tx_axis_tready[1];
assign mac_tx_axis_tlast[1] = mac_2_tx_axis_tlast;
assign mac_tx_axis_tuser[1*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_2_tx_axis_tuser;

assign mac_2_rx_clk = mac_rx_clk[1];
assign mac_2_rx_rst = mac_rx_rst[1];

assign mac_2_rx_ptp_clk = mac_rx_ptp_clk[1];
assign mac_2_rx_ptp_rst = mac_rx_ptp_rst[1];
assign mac_ptp_rx_tod[1*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_2_rx_ptp_time;

assign mac_2_rx_axis_tdata = mac_rx_axis_tdata[1*DATA_WIDTH +: DATA_WIDTH];
assign mac_2_rx_axis_tkeep = mac_rx_axis_tkeep[1*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_2_rx_axis_tvalid = mac_rx_axis_tvalid[1];
assign mac_2_rx_axis_tlast = mac_rx_axis_tlast[1];
assign mac_2_rx_axis_tuser = mac_rx_axis_tuser[1*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_2_rx_status = mac_rx_pcs_ready[1];

assign mac_3_tx_clk = mac_tx_clk[2];
assign mac_3_tx_rst = mac_tx_rst[2];

assign mac_3_tx_ptp_clk = mac_tx_ptp_clk[2];
assign mac_3_tx_ptp_rst = mac_tx_ptp_rst[2];
assign mac_ptp_tx_tod[2*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_3_tx_ptp_time;

assign mac_3_tx_ptp_ts = mac_ptp_ets[2*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_3_tx_ptp_ts_tag = mac_ptp_ets_fp[2*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_3_tx_ptp_ts_valid = mac_ptp_ets_valid[2];

assign mac_tx_axis_tdata[2*DATA_WIDTH +: DATA_WIDTH] = mac_3_tx_axis_tdata;
assign mac_tx_axis_tkeep[2*KEEP_WIDTH +: KEEP_WIDTH] = mac_3_tx_axis_tkeep;
assign mac_tx_axis_tvalid[2] = mac_3_tx_axis_tvalid;
assign mac_3_tx_axis_tready = mac_tx_axis_tready[2];
assign mac_tx_axis_tlast[2] = mac_3_tx_axis_tlast;
assign mac_tx_axis_tuser[2*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_3_tx_axis_tuser;

assign mac_3_rx_clk = mac_rx_clk[2];
assign mac_3_rx_rst = mac_rx_rst[2];

assign mac_3_rx_ptp_clk = mac_rx_ptp_clk[2];
assign mac_3_rx_ptp_rst = mac_rx_ptp_rst[2];
assign mac_ptp_rx_tod[2*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_3_rx_ptp_time;

assign mac_3_rx_axis_tdata = mac_rx_axis_tdata[2*DATA_WIDTH +: DATA_WIDTH];
assign mac_3_rx_axis_tkeep = mac_rx_axis_tkeep[2*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_3_rx_axis_tvalid = mac_rx_axis_tvalid[2];
assign mac_3_rx_axis_tlast = mac_rx_axis_tlast[2];
assign mac_3_rx_axis_tuser = mac_rx_axis_tuser[2*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_3_rx_status = mac_rx_pcs_ready[2];

assign mac_4_tx_clk = mac_tx_clk[3];
assign mac_4_tx_rst = mac_tx_rst[3];

assign mac_4_tx_ptp_clk = mac_tx_ptp_clk[3];
assign mac_4_tx_ptp_rst = mac_tx_ptp_rst[3];
assign mac_ptp_tx_tod[3*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_4_tx_ptp_time;

assign mac_4_tx_ptp_ts = mac_ptp_ets[3*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_4_tx_ptp_ts_tag = mac_ptp_ets_fp[3*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_4_tx_ptp_ts_valid = mac_ptp_ets_valid[3];

assign mac_tx_axis_tdata[3*DATA_WIDTH +: DATA_WIDTH] = mac_4_tx_axis_tdata;
assign mac_tx_axis_tkeep[3*KEEP_WIDTH +: KEEP_WIDTH] = mac_4_tx_axis_tkeep;
assign mac_tx_axis_tvalid[3] = mac_4_tx_axis_tvalid;
assign mac_4_tx_axis_tready = mac_tx_axis_tready[3];
assign mac_tx_axis_tlast[3] = mac_4_tx_axis_tlast;
assign mac_tx_axis_tuser[3*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_4_tx_axis_tuser;

assign mac_4_rx_clk = mac_rx_clk[3];
assign mac_4_rx_rst = mac_rx_rst[3];

assign mac_4_rx_ptp_clk = mac_rx_ptp_clk[3];
assign mac_4_rx_ptp_rst = mac_rx_ptp_rst[3];
assign mac_ptp_rx_tod[3*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_4_rx_ptp_time;

assign mac_4_rx_axis_tdata = mac_rx_axis_tdata[3*DATA_WIDTH +: DATA_WIDTH];
assign mac_4_rx_axis_tkeep = mac_rx_axis_tkeep[3*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_4_rx_axis_tvalid = mac_rx_axis_tvalid[3];
assign mac_4_rx_axis_tlast = mac_rx_axis_tlast[3];
assign mac_4_rx_axis_tuser = mac_rx_axis_tuser[3*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_4_rx_status = mac_rx_pcs_ready[3];

assign mac_5_tx_clk = mac_tx_clk[4];
assign mac_5_tx_rst = mac_tx_rst[4];

assign mac_5_tx_ptp_clk = mac_tx_ptp_clk[4];
assign mac_5_tx_ptp_rst = mac_tx_ptp_rst[4];
assign mac_ptp_tx_tod[4*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_5_tx_ptp_time;

assign mac_5_tx_ptp_ts = mac_ptp_ets[4*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_5_tx_ptp_ts_tag = mac_ptp_ets_fp[4*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_5_tx_ptp_ts_valid = mac_ptp_ets_valid[4];

assign mac_tx_axis_tdata[4*DATA_WIDTH +: DATA_WIDTH] = mac_5_tx_axis_tdata;
assign mac_tx_axis_tkeep[4*KEEP_WIDTH +: KEEP_WIDTH] = mac_5_tx_axis_tkeep;
assign mac_tx_axis_tvalid[4] = mac_5_tx_axis_tvalid;
assign mac_5_tx_axis_tready = mac_tx_axis_tready[4];
assign mac_tx_axis_tlast[4] = mac_5_tx_axis_tlast;
assign mac_tx_axis_tuser[4*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_5_tx_axis_tuser;

assign mac_5_rx_clk = mac_rx_clk[4];
assign mac_5_rx_rst = mac_rx_rst[4];

assign mac_5_rx_ptp_clk = mac_rx_ptp_clk[4];
assign mac_5_rx_ptp_rst = mac_rx_ptp_rst[4];
assign mac_ptp_rx_tod[4*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_5_rx_ptp_time;

assign mac_5_rx_axis_tdata = mac_rx_axis_tdata[4*DATA_WIDTH +: DATA_WIDTH];
assign mac_5_rx_axis_tkeep = mac_rx_axis_tkeep[4*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_5_rx_axis_tvalid = mac_rx_axis_tvalid[4];
assign mac_5_rx_axis_tlast = mac_rx_axis_tlast[4];
assign mac_5_rx_axis_tuser = mac_rx_axis_tuser[4*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_5_rx_status = mac_rx_pcs_ready[4];

assign mac_6_tx_clk = mac_tx_clk[5];
assign mac_6_tx_rst = mac_tx_rst[5];

assign mac_6_tx_ptp_clk = mac_tx_ptp_clk[5];
assign mac_6_tx_ptp_rst = mac_tx_ptp_rst[5];
assign mac_ptp_tx_tod[5*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_6_tx_ptp_time;

assign mac_6_tx_ptp_ts = mac_ptp_ets[5*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_6_tx_ptp_ts_tag = mac_ptp_ets_fp[5*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_6_tx_ptp_ts_valid = mac_ptp_ets_valid[5];

assign mac_tx_axis_tdata[5*DATA_WIDTH +: DATA_WIDTH] = mac_6_tx_axis_tdata;
assign mac_tx_axis_tkeep[5*KEEP_WIDTH +: KEEP_WIDTH] = mac_6_tx_axis_tkeep;
assign mac_tx_axis_tvalid[5] = mac_6_tx_axis_tvalid;
assign mac_6_tx_axis_tready = mac_tx_axis_tready[5];
assign mac_tx_axis_tlast[5] = mac_6_tx_axis_tlast;
assign mac_tx_axis_tuser[5*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_6_tx_axis_tuser;

assign mac_6_rx_clk = mac_rx_clk[5];
assign mac_6_rx_rst = mac_rx_rst[5];

assign mac_6_rx_ptp_clk = mac_rx_ptp_clk[5];
assign mac_6_rx_ptp_rst = mac_rx_ptp_rst[5];
assign mac_ptp_rx_tod[5*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_6_rx_ptp_time;

assign mac_6_rx_axis_tdata = mac_rx_axis_tdata[5*DATA_WIDTH +: DATA_WIDTH];
assign mac_6_rx_axis_tkeep = mac_rx_axis_tkeep[5*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_6_rx_axis_tvalid = mac_rx_axis_tvalid[5];
assign mac_6_rx_axis_tlast = mac_rx_axis_tlast[5];
assign mac_6_rx_axis_tuser = mac_rx_axis_tuser[5*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_6_rx_status = mac_rx_pcs_ready[5];

assign mac_7_tx_clk = mac_tx_clk[6];
assign mac_7_tx_rst = mac_tx_rst[6];

assign mac_7_tx_ptp_clk = mac_tx_ptp_clk[6];
assign mac_7_tx_ptp_rst = mac_tx_ptp_rst[6];
assign mac_ptp_tx_tod[6*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_7_tx_ptp_time;

assign mac_7_tx_ptp_ts = mac_ptp_ets[6*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_7_tx_ptp_ts_tag = mac_ptp_ets_fp[6*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_7_tx_ptp_ts_valid = mac_ptp_ets_valid[6];

assign mac_tx_axis_tdata[6*DATA_WIDTH +: DATA_WIDTH] = mac_7_tx_axis_tdata;
assign mac_tx_axis_tkeep[6*KEEP_WIDTH +: KEEP_WIDTH] = mac_7_tx_axis_tkeep;
assign mac_tx_axis_tvalid[6] = mac_7_tx_axis_tvalid;
assign mac_7_tx_axis_tready = mac_tx_axis_tready[6];
assign mac_tx_axis_tlast[6] = mac_7_tx_axis_tlast;
assign mac_tx_axis_tuser[6*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_7_tx_axis_tuser;

assign mac_7_rx_clk = mac_rx_clk[6];
assign mac_7_rx_rst = mac_rx_rst[6];

assign mac_7_rx_ptp_clk = mac_rx_ptp_clk[6];
assign mac_7_rx_ptp_rst = mac_rx_ptp_rst[6];
assign mac_ptp_rx_tod[6*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_7_rx_ptp_time;

assign mac_7_rx_axis_tdata = mac_rx_axis_tdata[6*DATA_WIDTH +: DATA_WIDTH];
assign mac_7_rx_axis_tkeep = mac_rx_axis_tkeep[6*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_7_rx_axis_tvalid = mac_rx_axis_tvalid[6];
assign mac_7_rx_axis_tlast = mac_rx_axis_tlast[6];
assign mac_7_rx_axis_tuser = mac_rx_axis_tuser[6*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_7_rx_status = mac_rx_pcs_ready[6];

assign mac_8_tx_clk = mac_tx_clk[7];
assign mac_8_tx_rst = mac_tx_rst[7];

assign mac_8_tx_ptp_clk = mac_tx_ptp_clk[7];
assign mac_8_tx_ptp_rst = mac_tx_ptp_rst[7];
assign mac_ptp_tx_tod[7*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_8_tx_ptp_time;

assign mac_8_tx_ptp_ts = mac_ptp_ets[7*PTP_TS_WIDTH +: PTP_TS_WIDTH];
assign mac_8_tx_ptp_ts_tag = mac_ptp_ets_fp[7*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
assign mac_8_tx_ptp_ts_valid = mac_ptp_ets_valid[7];

assign mac_tx_axis_tdata[7*DATA_WIDTH +: DATA_WIDTH] = mac_8_tx_axis_tdata;
assign mac_tx_axis_tkeep[7*KEEP_WIDTH +: KEEP_WIDTH] = mac_8_tx_axis_tkeep;
assign mac_tx_axis_tvalid[7] = mac_8_tx_axis_tvalid;
assign mac_8_tx_axis_tready = mac_tx_axis_tready[7];
assign mac_tx_axis_tlast[7] = mac_8_tx_axis_tlast;
assign mac_tx_axis_tuser[7*TX_USER_WIDTH +: TX_USER_WIDTH] = mac_8_tx_axis_tuser;

assign mac_8_rx_clk = mac_rx_clk[7];
assign mac_8_rx_rst = mac_rx_rst[7];

assign mac_8_rx_ptp_clk = mac_rx_ptp_clk[7];
assign mac_8_rx_ptp_rst = mac_rx_ptp_rst[7];
assign mac_ptp_rx_tod[7*PTP_TS_WIDTH +: PTP_TS_WIDTH] = mac_8_rx_ptp_time;

assign mac_8_rx_axis_tdata = mac_rx_axis_tdata[7*DATA_WIDTH +: DATA_WIDTH];
assign mac_8_rx_axis_tkeep = mac_rx_axis_tkeep[7*KEEP_WIDTH +: KEEP_WIDTH];
assign mac_8_rx_axis_tvalid = mac_rx_axis_tvalid[7];
assign mac_8_rx_axis_tlast = mac_rx_axis_tlast[7];
assign mac_8_rx_axis_tuser = mac_rx_axis_tuser[7*RX_USER_WIDTH +: RX_USER_WIDTH];

assign mac_8_rx_status = mac_rx_pcs_ready[7];

generate

genvar n;

for (n = 0; n < N_CH; n = n + 1) begin : mac_ch

    sync_reset #(
        .N(4)
    )
    mac_tx_reset_sync_inst (
        .clk(mac_tx_clk[n]),
        .rst(ctrl_rst || !mac_tx_lanes_stable[n] || !mac_ehip_ready[n]),
        .out(mac_tx_rst[n])
    );

    sync_reset #(
        .N(4)
    )
    mac_rx_reset_sync_inst (
        .clk(mac_rx_clk[n]),
        .rst(ctrl_rst || !mac_rx_pcs_ready[n]),
        .out(mac_rx_rst[n])
    );

    sync_reset #(
        .N(4)
    )
    mac_tx_ptp_reset_sync_inst (
        .clk(mac_tx_ptp_clk[n]),
        .rst(ctrl_rst || !mac_tx_lanes_stable[n]),
        .out(mac_tx_ptp_rst[n])
    );

    sync_reset #(
        .N(4)
    )
    mac_rx_ptp_reset_sync_inst (
        .clk(mac_rx_ptp_clk[n]),
        .rst(ctrl_rst || !mac_rx_pcs_ready[n]),
        .out(mac_rx_ptp_rst[n])
    );

    xcvr_ctrl xcvr_ctrl_inst (
        .reconfig_clk(ctrl_clk),
        .reconfig_rst(ctrl_rst),

        .pll_locked_in(mac_tx_pll_locked[n]),

        .xcvr_reconfig_address(xcvr_reconfig_address[n*19 +: 19]),
        .xcvr_reconfig_read(xcvr_reconfig_read[n]),
        .xcvr_reconfig_write(xcvr_reconfig_write[n]),
        .xcvr_reconfig_readdata(xcvr_reconfig_readdata[n*8 +: 8]),
        .xcvr_reconfig_writedata(xcvr_reconfig_writedata[n*8 +: 8]),
        .xcvr_reconfig_waitrequest(xcvr_reconfig_waitrequest[n])
    );

    axis2avst #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .KEEP_ENABLE(1),
        .EMPTY_WIDTH(3),
        .BYTE_REVERSE(1)
    )
    mac_tx_axis2avst (
        .clk(mac_tx_clk[n]),
        .rst(mac_tx_rst[n]),

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
        .avst_empty(mac_tx_empty[n*3 +: 3]),
        .avst_error(mac_tx_error[n])
    );

    assign mac_ptp_fp[n*PTP_TAG_WIDTH +: PTP_TAG_WIDTH] = mac_tx_axis_tuser[n*TX_USER_WIDTH+1 +: PTP_TAG_WIDTH];

    wire [DATA_WIDTH-1:0]     mac_rx_axis_tdata_int;
    wire [KEEP_WIDTH-1:0]     mac_rx_axis_tkeep_int;
    wire                      mac_rx_axis_tvalid_int;
    wire                      mac_rx_axis_tlast_int;
    wire                      mac_rx_axis_tuser_int;

    avst2axis #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .KEEP_ENABLE(1),
        .EMPTY_WIDTH(3),
        .BYTE_REVERSE(1)
    )
    mac_rx_avst2axis (
        .clk(mac_rx_clk[n]),
        .rst(mac_rx_rst[n]),

        .avst_ready(),
        .avst_valid(mac_rx_valid[n]),
        .avst_data(mac_rx_data[n*DATA_WIDTH +: DATA_WIDTH]),
        .avst_startofpacket(mac_rx_startofpacket[n]),
        .avst_endofpacket(mac_rx_endofpacket[n]),
        .avst_empty(mac_rx_empty[n*3 +: 3]),
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
        .M_USER_WIDTH(RX_USER_WIDTH)
    )
    mac_ts_insert_inst (
        .clk(mac_rx_clk[n]),
        .rst(mac_rx_rst[n]),

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
