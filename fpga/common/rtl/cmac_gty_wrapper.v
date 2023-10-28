// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * GTY transceiver and CMAC wrapper
 */
module cmac_gty_wrapper #
(
    parameter COUNT = 4,
    parameter DRP_CLK_FREQ_HZ = 125000000,

    // PLL parameters
    parameter QPLL0_PD = 1'b0,
    parameter QPLL1_PD = 1'b1,

    // GT parameters
    parameter GT_1_TX_PD = 1'b0,
    parameter GT_1_TX_QPLL_SEL = 1'b0,
    parameter GT_1_TX_POLARITY = 1'b0,
    parameter GT_1_TX_ELECIDLE = 1'b0,
    parameter GT_1_TX_INHIBIT = 1'b0,
    parameter GT_1_TX_DIFFCTRL = 5'd24,
    parameter GT_1_TX_MAINCURSOR = 7'd64,
    parameter GT_1_TX_POSTCURSOR = 5'd0,
    parameter GT_1_TX_PRECURSOR = 5'd0,
    parameter GT_1_RX_PD = 1'b0,
    parameter GT_1_RX_QPLL_SEL = 1'b0,
    parameter GT_1_RX_LPM_EN = 1'b1,
    parameter GT_1_RX_POLARITY = 1'b0,
    parameter GT_2_TX_PD = GT_1_TX_PD,
    parameter GT_2_TX_QPLL_SEL = GT_1_TX_QPLL_SEL,
    parameter GT_2_TX_POLARITY = GT_1_TX_POLARITY,
    parameter GT_2_TX_ELECIDLE = GT_1_TX_ELECIDLE,
    parameter GT_2_TX_INHIBIT = GT_1_TX_INHIBIT,
    parameter GT_2_TX_DIFFCTRL = GT_1_TX_DIFFCTRL,
    parameter GT_2_TX_MAINCURSOR = GT_1_TX_MAINCURSOR,
    parameter GT_2_TX_POSTCURSOR = GT_1_TX_POSTCURSOR,
    parameter GT_2_TX_PRECURSOR = GT_1_TX_PRECURSOR,
    parameter GT_2_RX_PD = GT_1_RX_PD,
    parameter GT_2_RX_QPLL_SEL = GT_1_RX_QPLL_SEL,
    parameter GT_2_RX_LPM_EN = GT_1_RX_LPM_EN,
    parameter GT_2_RX_POLARITY = GT_1_RX_POLARITY,
    parameter GT_3_TX_PD = GT_1_TX_PD,
    parameter GT_3_TX_QPLL_SEL = GT_1_TX_QPLL_SEL,
    parameter GT_3_TX_POLARITY = GT_1_TX_POLARITY,
    parameter GT_3_TX_ELECIDLE = GT_1_TX_ELECIDLE,
    parameter GT_3_TX_INHIBIT = GT_1_TX_INHIBIT,
    parameter GT_3_TX_DIFFCTRL = GT_1_TX_DIFFCTRL,
    parameter GT_3_TX_MAINCURSOR = GT_1_TX_MAINCURSOR,
    parameter GT_3_TX_POSTCURSOR = GT_1_TX_POSTCURSOR,
    parameter GT_3_TX_PRECURSOR = GT_1_TX_PRECURSOR,
    parameter GT_3_RX_PD = GT_1_RX_PD,
    parameter GT_3_RX_QPLL_SEL = GT_1_RX_QPLL_SEL,
    parameter GT_3_RX_LPM_EN = GT_1_RX_LPM_EN,
    parameter GT_3_RX_POLARITY = GT_1_RX_POLARITY,
    parameter GT_4_TX_PD = GT_1_TX_PD,
    parameter GT_4_TX_QPLL_SEL = GT_1_TX_QPLL_SEL,
    parameter GT_4_TX_POLARITY = GT_1_TX_POLARITY,
    parameter GT_4_TX_ELECIDLE = GT_1_TX_ELECIDLE,
    parameter GT_4_TX_INHIBIT = GT_1_TX_INHIBIT,
    parameter GT_4_TX_DIFFCTRL = GT_1_TX_DIFFCTRL,
    parameter GT_4_TX_MAINCURSOR = GT_1_TX_MAINCURSOR,
    parameter GT_4_TX_POSTCURSOR = GT_1_TX_POSTCURSOR,
    parameter GT_4_TX_PRECURSOR = GT_1_TX_PRECURSOR,
    parameter GT_4_RX_PD = GT_1_RX_PD,
    parameter GT_4_RX_QPLL_SEL = GT_1_RX_QPLL_SEL,
    parameter GT_4_RX_LPM_EN = GT_1_RX_LPM_EN,
    parameter GT_4_RX_POLARITY = GT_1_RX_POLARITY,

    // CMAC parameters
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    parameter TX_SERDES_PIPELINE = 1,
    parameter RX_SERDES_PIPELINE = 1,
    parameter RS_FEC_ENABLE = 1
)
(
    input  wire                        xcvr_ctrl_clk,
    input  wire                        xcvr_ctrl_rst,

    /*
     * Common
     */
    output wire                        xcvr_gtpowergood_out,
    input  wire                        xcvr_ref_clk,

    /*
     * DRP
     */
    input  wire                        drp_clk,
    input  wire                        drp_rst,
    input  wire [23:0]                 drp_addr,
    input  wire [15:0]                 drp_di,
    input  wire                        drp_en,
    input  wire                        drp_we,
    output wire [15:0]                 drp_do,
    output wire                        drp_rdy,

    /*
     * Serial data
     */
    output wire [COUNT-1:0]            xcvr_txp,
    output wire [COUNT-1:0]            xcvr_txn,
    input  wire [COUNT-1:0]            xcvr_rxp,
    input  wire [COUNT-1:0]            xcvr_rxn,

    /*
     * CMAC connections
     */
    output wire                        tx_clk,
    output wire                        tx_rst,

    input  wire [AXIS_DATA_WIDTH-1:0]  tx_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]  tx_axis_tkeep,
    input  wire                        tx_axis_tvalid,
    output wire                        tx_axis_tready,
    input  wire                        tx_axis_tlast,
    input  wire [16+1-1:0]             tx_axis_tuser,

    input  wire [79:0]                 tx_ptp_time,
    output wire [79:0]                 tx_ptp_ts,
    output wire [15:0]                 tx_ptp_ts_tag,
    output wire                        tx_ptp_ts_valid,

    input  wire                        tx_enable,
    input  wire                        tx_lfc_en,
    input  wire                        tx_lfc_req,
    input  wire [7:0]                  tx_pfc_en,
    input  wire [7:0]                  tx_pfc_req,

    output wire                        rx_clk,
    output wire                        rx_rst,

    output wire [AXIS_DATA_WIDTH-1:0]  rx_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]  rx_axis_tkeep,
    output wire                        rx_axis_tvalid,
    output wire                        rx_axis_tlast,
    output wire [80+1-1:0]             rx_axis_tuser,

    input  wire [79:0]                 rx_ptp_time,

    input  wire                        rx_enable,
    output wire                        rx_status,
    input  wire                        rx_lfc_en,
    output wire                        rx_lfc_req,
    input  wire                        rx_lfc_ack,
    input  wire [7:0]                  rx_pfc_en,
    output wire [7:0]                  rx_pfc_req,
    input  wire [7:0]                  rx_pfc_ack
);

reg [23:0] drp_addr_reg = 24'd0;
reg [15:0] drp_di_reg = 16'd0;
reg drp_en_gty_reg_1 = 1'b0;
reg drp_en_gty_reg_2 = 1'b0;
reg drp_en_gty_reg_3 = 1'b0;
reg drp_en_gty_reg_4 = 1'b0;
reg drp_en_cmac_reg = 1'b0;
reg drp_en_ctrl_reg = 1'b0;
reg drp_we_reg = 1'b0;
reg [15:0] drp_do_reg = 16'd0;
reg drp_rdy_reg = 1'b0;

wire [15:0] drp_do_gty_1;
wire drp_rdy_gty_1;
wire [15:0] drp_do_gty_2;
wire drp_rdy_gty_2;
wire [15:0] drp_do_gty_3;
wire drp_rdy_gty_3;
wire [15:0] drp_do_gty_4;
wire drp_rdy_gty_4;
wire [15:0] drp_do_cmac;
wire drp_rdy_cmac;
reg [15:0] drp_do_ctrl_reg = 0;
reg drp_rdy_ctrl_reg = 1'b0;

assign drp_do = drp_do_reg;
assign drp_rdy = drp_rdy_reg;

always @(posedge drp_clk) begin
    drp_en_gty_reg_1 <= 1'b0;
    drp_en_gty_reg_2 <= 1'b0;
    drp_en_gty_reg_3 <= 1'b0;
    drp_en_gty_reg_4 <= 1'b0;
    drp_en_cmac_reg <= 1'b0;
    drp_en_ctrl_reg <= 1'b0;
    drp_we_reg <= 1'b0;
    drp_rdy_reg <= 1'b0;
    drp_do_reg <= 16'd0;

    if (drp_en) begin
        drp_addr_reg <= drp_addr;
        drp_di_reg <= drp_di;
        drp_we_reg <= drp_we;
        if (COUNT > 0 && (drp_addr[19:17] == 3'b000 || drp_addr[19:17] == 3'b100)) begin
            drp_en_gty_reg_1 <= 1'b1;
        end else if (COUNT > 1 && drp_addr[19:17] == 3'b001) begin
            drp_en_gty_reg_2 <= 1'b1;
        end else if (COUNT > 2 && drp_addr[19:17] == 3'b010) begin
            drp_en_gty_reg_3 <= 1'b1;
        end else if (COUNT > 3 && drp_addr[19:17] == 3'b011) begin
            drp_en_gty_reg_4 <= 1'b1;
        end else if (drp_addr[19:17] == 3'b101) begin
            if (drp_addr[16]) begin
                drp_en_ctrl_reg <= 1'b1;
            end else begin
                drp_en_cmac_reg <= 1'b1;
            end
        end else begin
            drp_rdy_reg <= 1'b1;
        end
    end

    if (drp_rdy_gty_1) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_gty_1;
    end else if (drp_rdy_gty_2) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_gty_2;
    end else if (drp_rdy_gty_3) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_gty_3;
    end else if (drp_rdy_gty_4) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_gty_4;
    end else if (drp_rdy_cmac) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_cmac;
    end else if (drp_rdy_ctrl_reg) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_ctrl_reg;
    end

    if (drp_rst) begin
        drp_en_gty_reg_1 <= 1'b0;
        drp_en_gty_reg_2 <= 1'b0;
        drp_en_gty_reg_3 <= 1'b0;
        drp_en_gty_reg_4 <= 1'b0;
        drp_en_cmac_reg <= 1'b0;
        drp_en_ctrl_reg <= 1'b0;
        drp_we_reg <= 1'b0;
        drp_rdy_reg <= 1'b0;
    end
end

reg cmac_ctl_tx_rsfec_enable_reg = RS_FEC_ENABLE;
reg cmac_ctl_rx_rsfec_enable_reg = RS_FEC_ENABLE;
reg cmac_ctl_rsfec_ieee_error_indication_mode_reg = 1'b0;
reg cmac_ctl_rx_rsfec_enable_correction_reg = 1'b1;
reg cmac_ctl_rx_rsfec_enable_indication_reg = 1'b1;

wire [3:0] cmac_stat_rx_rsfec_am_lock;
wire [4*3-1:0] cmac_stat_rx_rsfec_err_count_inc;
wire cmac_stat_rx_rsfec_hi_ser;
wire cmac_stat_rx_rsfec_lane_alignment_status;
wire [4*14-1:0] cmac_stat_rx_rsfec_lane_fill;
wire [7:0] cmac_stat_rx_rsfec_lane_mapping;
wire cmac_stat_rx_rsfec_cw_inc;
wire cmac_stat_rx_rsfec_corrected_cw_inc;
wire cmac_stat_rx_rsfec_uncorrected_cw_inc;

wire [20*7-1:0] cmac_rx_lane_aligner_fill;

wire cmac_stat_rx_aligned;
wire cmac_stat_rx_aligned_err;
wire [2:0] cmac_stat_rx_bad_code;
wire [2:0] cmac_stat_rx_bad_fcs;
wire cmac_stat_rx_bad_preamble;
wire cmac_stat_rx_bad_sfd;
wire [19:0] cmac_stat_rx_bip_err;
wire [19:0] cmac_stat_rx_block_lock;
wire cmac_stat_rx_broadcast;
wire [2:0] cmac_stat_rx_fragment;
wire [20*2-1:0] cmac_stat_rx_framing_err;
wire [19:0] cmac_stat_rx_framing_err_valid;
wire cmac_stat_rx_got_signal_os;
wire cmac_stat_rx_hi_ber;
wire cmac_stat_rx_inrangeerr;
wire cmac_stat_rx_internal_local_fault;
wire cmac_stat_rx_jabber;
wire cmac_stat_rx_local_fault;
wire [19:0] cmac_stat_rx_mf_err;
wire [19:0] cmac_stat_rx_mf_len_err;
wire [19:0] cmac_stat_rx_mf_repeat_err;
wire cmac_stat_rx_misaligned;
wire cmac_stat_rx_multicast;
wire cmac_stat_rx_oversize;
wire cmac_stat_rx_packet_64_bytes;
wire cmac_stat_rx_packet_65_127_bytes;
wire cmac_stat_rx_packet_128_255_bytes;
wire cmac_stat_rx_packet_256_511_bytes;
wire cmac_stat_rx_packet_512_1023_bytes;
wire cmac_stat_rx_packet_1024_1518_bytes;
wire cmac_stat_rx_packet_1519_1522_bytes;
wire cmac_stat_rx_packet_1523_1548_bytes;
wire cmac_stat_rx_packet_1549_2047_bytes;
wire cmac_stat_rx_packet_2048_4095_bytes;
wire cmac_stat_rx_packet_4096_8191_bytes;
wire cmac_stat_rx_packet_8192_9215_bytes;
wire cmac_stat_rx_packet_bad_fcs;
wire cmac_stat_rx_packet_large;
wire [2:0] cmac_stat_rx_packet_small;

reg cmac_ctl_rx_enable_reg = 1'b1;
reg cmac_ctl_rx_force_resync_reg = 1'b0;
reg cmac_ctl_rx_test_pattern_reg = 1'b0;

wire cmac_stat_rx_received_local_fault;
wire cmac_stat_rx_remote_fault;
wire cmac_stat_rx_status;
wire [2:0] cmac_stat_rx_stomped_fcs;
wire [19:0] cmac_stat_rx_synced;
wire [19:0] cmac_stat_rx_synced_err;
wire [2:0] cmac_stat_rx_test_pattern_mismatch;
wire cmac_stat_rx_toolong;
wire [6:0] cmac_stat_rx_total_bytes;
wire [13:0] cmac_stat_rx_total_good_bytes;
wire cmac_stat_rx_total_good_packets;
wire [2:0] cmac_stat_rx_total_packets;
wire cmac_stat_rx_truncated;
wire [2:0] cmac_stat_rx_undersize;
wire cmac_stat_rx_unicast;
wire cmac_stat_rx_vlan;
wire [19:0] cmac_stat_rx_pcsl_demuxed;
wire [20*5-1:0] cmac_stat_rx_pcsl_number;

wire cmac_stat_tx_ptp_fifo_read_error;
wire cmac_stat_tx_ptp_fifo_write_error;

wire cmac_stat_tx_bad_fcs;
wire cmac_stat_tx_broadcast;
wire cmac_stat_tx_frame_error;
wire cmac_stat_tx_local_fault;
wire cmac_stat_tx_multicast;
wire cmac_stat_tx_packet_64_bytes;
wire cmac_stat_tx_packet_65_127_bytes;
wire cmac_stat_tx_packet_128_255_bytes;
wire cmac_stat_tx_packet_256_511_bytes;
wire cmac_stat_tx_packet_512_1023_bytes;
wire cmac_stat_tx_packet_1024_1518_bytes;
wire cmac_stat_tx_packet_1519_1522_bytes;
wire cmac_stat_tx_packet_1523_1548_bytes;
wire cmac_stat_tx_packet_1549_2047_bytes;
wire cmac_stat_tx_packet_2048_4095_bytes;
wire cmac_stat_tx_packet_4096_8191_bytes;
wire cmac_stat_tx_packet_8192_9215_bytes;
wire cmac_stat_tx_packet_large;
wire cmac_stat_tx_packet_small;
wire [5:0] cmac_stat_tx_total_bytes;
wire [13:0] cmac_stat_tx_total_good_bytes;
wire cmac_stat_tx_total_good_packets;
wire cmac_stat_tx_total_packets;
wire cmac_stat_tx_unicast;
wire cmac_stat_tx_vlan;

reg cmac_ctl_tx_enable_reg = 1'b1;
reg cmac_ctl_tx_send_idle_reg = 1'b0;
reg cmac_ctl_tx_send_rfi_reg = 1'b0;
reg cmac_ctl_tx_send_lfi_reg = 1'b0;
reg cmac_ctl_tx_test_pattern_reg = 1'b0;

assign rx_status = cmac_stat_rx_status;

reg tx_reset_drp_reg = 1'b0;
reg gt_tx_reset_drp_reg = 1'b0;
reg rx_reset_drp_reg = 1'b0;
reg gt_rx_reset_drp_reg = 1'b0;

reg tx_rst_sync_1_reg = 1'b0, tx_rst_sync_2_reg = 1'b0;
reg rx_rst_sync_1_reg = 1'b0, rx_rst_sync_2_reg = 1'b0;

always @(posedge drp_clk) begin
    tx_rst_sync_1_reg <= tx_rst;
    tx_rst_sync_2_reg <= tx_rst_sync_1_reg;
    rx_rst_sync_1_reg <= rx_rst;
    rx_rst_sync_2_reg <= rx_rst_sync_1_reg;
end

reg cmac_ctl_tx_rsfec_enable_drp_reg = RS_FEC_ENABLE;
reg cmac_ctl_tx_rsfec_enable_sync_reg = RS_FEC_ENABLE;
reg cmac_ctl_rx_rsfec_enable_drp_reg = RS_FEC_ENABLE;
reg cmac_ctl_rx_rsfec_enable_sync_reg = RS_FEC_ENABLE;
reg cmac_ctl_rsfec_ieee_error_indication_mode_drp_reg = 1'b0;
reg cmac_ctl_rsfec_ieee_error_indication_mode_sync_reg = 1'b0;
reg cmac_ctl_rx_rsfec_enable_correction_drp_reg = 1'b1;
reg cmac_ctl_rx_rsfec_enable_correction_sync_reg = 1'b1;
reg cmac_ctl_rx_rsfec_enable_indication_drp_reg = 1'b1;
reg cmac_ctl_rx_rsfec_enable_indication_sync_reg = 1'b1;

always @(posedge tx_clk) begin
    cmac_ctl_tx_rsfec_enable_sync_reg <= cmac_ctl_tx_rsfec_enable_drp_reg;
    cmac_ctl_tx_rsfec_enable_reg <= cmac_ctl_tx_rsfec_enable_sync_reg;
end

always @(posedge rx_clk) begin
    cmac_ctl_rx_rsfec_enable_sync_reg <= cmac_ctl_rx_rsfec_enable_drp_reg;
    cmac_ctl_rx_rsfec_enable_reg <= cmac_ctl_rx_rsfec_enable_sync_reg;
    cmac_ctl_rsfec_ieee_error_indication_mode_sync_reg <= cmac_ctl_rsfec_ieee_error_indication_mode_drp_reg;
    cmac_ctl_rsfec_ieee_error_indication_mode_reg <= cmac_ctl_rsfec_ieee_error_indication_mode_sync_reg;
    cmac_ctl_rx_rsfec_enable_correction_sync_reg <= cmac_ctl_rx_rsfec_enable_correction_drp_reg;
    cmac_ctl_rx_rsfec_enable_correction_reg <= cmac_ctl_rx_rsfec_enable_correction_sync_reg;
    cmac_ctl_rx_rsfec_enable_indication_sync_reg <= cmac_ctl_rx_rsfec_enable_indication_drp_reg;
    cmac_ctl_rx_rsfec_enable_indication_reg <= cmac_ctl_rx_rsfec_enable_indication_sync_reg;
end

reg [3:0] cmac_stat_rx_rsfec_am_lock_sync_1_reg = 0, cmac_stat_rx_rsfec_am_lock_sync_2_reg = 0;
reg cmac_stat_rx_rsfec_hi_ser_sync_1_reg = 1'b0, cmac_stat_rx_rsfec_hi_ser_sync_2_reg = 1'b0;
reg cmac_stat_rx_rsfec_lane_alignment_status_sync_1_reg = 1'b0, cmac_stat_rx_rsfec_lane_alignment_status_sync_2_reg = 1'b0;
reg [4*14-1:0] cmac_stat_rx_rsfec_lane_fill_sync_1_reg = 0, cmac_stat_rx_rsfec_lane_fill_sync_2_reg = 0;
reg [7:0] cmac_stat_rx_rsfec_lane_mapping_sync_1_reg = 0, cmac_stat_rx_rsfec_lane_mapping_sync_2_reg = 0;

always @(posedge drp_clk) begin
    cmac_stat_rx_rsfec_am_lock_sync_1_reg <= cmac_stat_rx_rsfec_am_lock;
    cmac_stat_rx_rsfec_am_lock_sync_2_reg <= cmac_stat_rx_rsfec_am_lock_sync_1_reg;
    cmac_stat_rx_rsfec_hi_ser_sync_1_reg <= cmac_stat_rx_rsfec_hi_ser;
    cmac_stat_rx_rsfec_hi_ser_sync_2_reg <= cmac_stat_rx_rsfec_hi_ser_sync_1_reg;
    cmac_stat_rx_rsfec_lane_alignment_status_sync_1_reg <= cmac_stat_rx_rsfec_lane_alignment_status;
    cmac_stat_rx_rsfec_lane_alignment_status_sync_2_reg <= cmac_stat_rx_rsfec_lane_alignment_status_sync_1_reg;
    cmac_stat_rx_rsfec_lane_fill_sync_1_reg <= cmac_stat_rx_rsfec_lane_fill;
    cmac_stat_rx_rsfec_lane_fill_sync_2_reg <= cmac_stat_rx_rsfec_lane_fill_sync_1_reg;
    cmac_stat_rx_rsfec_lane_mapping_sync_1_reg <= cmac_stat_rx_rsfec_lane_mapping;
    cmac_stat_rx_rsfec_lane_mapping_sync_2_reg <= cmac_stat_rx_rsfec_lane_mapping_sync_1_reg;
end

reg [20*7-1:0] cmac_rx_lane_aligner_fill_sync_1_reg = 0, cmac_rx_lane_aligner_fill_sync_2_reg = 0;

reg cmac_stat_rx_aligned_sync_1_reg = 1'b0, cmac_stat_rx_aligned_sync_2_reg = 1'b0;
reg cmac_stat_rx_aligned_err_sync_1_reg = 1'b0, cmac_stat_rx_aligned_err_sync_2_reg = 1'b0;
reg [19:0] cmac_stat_rx_block_lock_sync_1_reg = 0, cmac_stat_rx_block_lock_sync_2_reg = 0;
reg cmac_stat_rx_hi_ber_sync_1_reg = 1'b0, cmac_stat_rx_hi_ber_sync_2_reg = 1'b0;
reg cmac_stat_rx_internal_local_fault_sync_1_reg = 1'b0, cmac_stat_rx_internal_local_fault_sync_2_reg = 1'b0;
reg cmac_stat_rx_local_fault_sync_1_reg = 1'b0, cmac_stat_rx_local_fault_sync_2_reg = 1'b0;
reg [19:0] cmac_stat_rx_mf_len_err_sync_1_reg = 20'd0, cmac_stat_rx_mf_len_err_sync_2_reg = 20'd0;
reg [19:0] cmac_stat_rx_mf_repeat_err_sync_1_reg = 20'd0, cmac_stat_rx_mf_repeat_err_sync_2_reg = 20'd0;

always @(posedge drp_clk) begin
    cmac_rx_lane_aligner_fill_sync_1_reg <= cmac_rx_lane_aligner_fill;
    cmac_rx_lane_aligner_fill_sync_2_reg <= cmac_rx_lane_aligner_fill_sync_1_reg;
    cmac_stat_rx_aligned_sync_1_reg <= cmac_stat_rx_aligned;
    cmac_stat_rx_aligned_sync_2_reg <= cmac_stat_rx_aligned_sync_1_reg;
    cmac_stat_rx_aligned_err_sync_1_reg <= cmac_stat_rx_aligned_err;
    cmac_stat_rx_aligned_err_sync_2_reg <= cmac_stat_rx_aligned_err_sync_1_reg;
    cmac_stat_rx_block_lock_sync_1_reg <= cmac_stat_rx_block_lock;
    cmac_stat_rx_block_lock_sync_2_reg <= cmac_stat_rx_block_lock_sync_1_reg;
    cmac_stat_rx_hi_ber_sync_1_reg <= cmac_stat_rx_hi_ber;
    cmac_stat_rx_hi_ber_sync_2_reg <= cmac_stat_rx_hi_ber_sync_1_reg;
    cmac_stat_rx_internal_local_fault_sync_1_reg <= cmac_stat_rx_internal_local_fault;
    cmac_stat_rx_internal_local_fault_sync_2_reg <= cmac_stat_rx_internal_local_fault_sync_1_reg;
    cmac_stat_rx_local_fault_sync_1_reg <= cmac_stat_rx_local_fault;
    cmac_stat_rx_local_fault_sync_2_reg <= cmac_stat_rx_local_fault_sync_1_reg;
    cmac_stat_rx_mf_len_err_sync_1_reg <= cmac_stat_rx_mf_len_err;
    cmac_stat_rx_mf_len_err_sync_2_reg <= cmac_stat_rx_mf_len_err_sync_1_reg;
    cmac_stat_rx_mf_repeat_err_sync_1_reg <= cmac_stat_rx_mf_repeat_err;
    cmac_stat_rx_mf_repeat_err_sync_2_reg <= cmac_stat_rx_mf_repeat_err_sync_1_reg;
end

reg cmac_ctl_rx_enable_drp_reg = 1'b1;
reg cmac_ctl_rx_enable_sync_reg = 1'b1;
reg cmac_ctl_rx_force_resync_drp_reg = 1'b0;
reg cmac_ctl_rx_force_resync_sync_reg = 1'b0;
reg cmac_ctl_rx_test_pattern_drp_reg = 1'b0;
reg cmac_ctl_rx_test_pattern_sync_reg = 1'b0;

always @(posedge rx_clk) begin
    cmac_ctl_rx_enable_sync_reg <= cmac_ctl_rx_enable_drp_reg;
    cmac_ctl_rx_enable_reg <= cmac_ctl_rx_enable_sync_reg;
    cmac_ctl_rx_force_resync_sync_reg <= cmac_ctl_rx_force_resync_drp_reg;
    cmac_ctl_rx_force_resync_reg <= cmac_ctl_rx_force_resync_sync_reg;
    cmac_ctl_rx_test_pattern_sync_reg <= cmac_ctl_rx_test_pattern_drp_reg;
    cmac_ctl_rx_test_pattern_reg <= cmac_ctl_rx_test_pattern_sync_reg;
end

reg cmac_stat_rx_received_local_fault_sync_1_reg = 1'b0, cmac_stat_rx_received_local_fault_sync_2_reg = 1'b0;
reg cmac_stat_rx_remote_fault_sync_1_reg = 1'b0, cmac_stat_rx_remote_fault_sync_2_reg = 1'b0;
reg cmac_stat_rx_status_sync_1_reg = 1'b0, cmac_stat_rx_status_sync_2_reg = 1'b0;
reg [19:0] cmac_stat_rx_synced_sync_1_reg = 20'd0, cmac_stat_rx_synced_sync_2_reg = 20'd0;
reg [19:0] cmac_stat_rx_synced_err_sync_1_reg = 20'd0, cmac_stat_rx_synced_err_sync_2_reg = 20'd0;
reg [19:0] cmac_stat_rx_pcsl_demuxed_sync_1_reg = 20'd0, cmac_stat_rx_pcsl_demuxed_sync_2_reg = 20'd0;
reg [20*5-1:0] cmac_stat_rx_pcsl_number_sync_1_reg = 0, cmac_stat_rx_pcsl_number_sync_2_reg = 0;

always @(posedge drp_clk) begin
    cmac_stat_rx_received_local_fault_sync_1_reg <= cmac_stat_rx_received_local_fault;
    cmac_stat_rx_received_local_fault_sync_2_reg <= cmac_stat_rx_received_local_fault_sync_1_reg;
    cmac_stat_rx_remote_fault_sync_1_reg <= cmac_stat_rx_remote_fault;
    cmac_stat_rx_remote_fault_sync_2_reg <= cmac_stat_rx_remote_fault_sync_1_reg;
    cmac_stat_rx_status_sync_1_reg <= cmac_stat_rx_status;
    cmac_stat_rx_status_sync_2_reg <= cmac_stat_rx_status_sync_1_reg;
    cmac_stat_rx_synced_sync_1_reg <= cmac_stat_rx_synced;
    cmac_stat_rx_synced_sync_2_reg <= cmac_stat_rx_synced_sync_1_reg;
    cmac_stat_rx_synced_err_sync_1_reg <= cmac_stat_rx_synced_err;
    cmac_stat_rx_synced_err_sync_2_reg <= cmac_stat_rx_synced_err_sync_1_reg;
    cmac_stat_rx_pcsl_demuxed_sync_1_reg <= cmac_stat_rx_pcsl_demuxed;
    cmac_stat_rx_pcsl_demuxed_sync_2_reg <= cmac_stat_rx_pcsl_demuxed_sync_1_reg;
    cmac_stat_rx_pcsl_number_sync_1_reg <= cmac_stat_rx_pcsl_number;
    cmac_stat_rx_pcsl_number_sync_2_reg <= cmac_stat_rx_pcsl_number_sync_1_reg;
end

reg cmac_stat_tx_ptp_fifo_read_error_sync_1_reg = 1'b0, cmac_stat_tx_ptp_fifo_read_error_sync_2_reg = 1'b0;
reg cmac_stat_tx_ptp_fifo_write_error_sync_1_reg = 1'b0, cmac_stat_tx_ptp_fifo_write_error_sync_2_reg = 1'b0;

reg cmac_stat_tx_local_fault_sync_1_reg = 1'b0, cmac_stat_tx_local_fault_sync_2_reg = 1'b0;

always @(posedge drp_clk) begin
    cmac_stat_tx_ptp_fifo_read_error_sync_1_reg <= cmac_stat_tx_ptp_fifo_read_error;
    cmac_stat_tx_ptp_fifo_read_error_sync_2_reg <= cmac_stat_tx_ptp_fifo_read_error_sync_1_reg;
    cmac_stat_tx_ptp_fifo_write_error_sync_1_reg <= cmac_stat_tx_ptp_fifo_write_error;
    cmac_stat_tx_ptp_fifo_write_error_sync_2_reg <= cmac_stat_tx_ptp_fifo_write_error_sync_1_reg;
    cmac_stat_tx_local_fault_sync_1_reg <= cmac_stat_tx_local_fault;
    cmac_stat_tx_local_fault_sync_2_reg <= cmac_stat_tx_local_fault_sync_1_reg;
end

reg cmac_ctl_tx_enable_drp_reg = 1'b1;
reg cmac_ctl_tx_enable_sync_reg = 1'b1;
reg cmac_ctl_tx_send_idle_drp_reg = 1'b0;
reg cmac_ctl_tx_send_idle_sync_reg = 1'b0;
reg cmac_ctl_tx_send_rfi_drp_reg = 1'b0;
reg cmac_ctl_tx_send_rfi_sync_reg = 1'b0;
reg cmac_ctl_tx_send_lfi_drp_reg = 1'b0;
reg cmac_ctl_tx_send_lfi_sync_reg = 1'b0;
reg cmac_ctl_tx_test_pattern_drp_reg = 1'b0;
reg cmac_ctl_tx_test_pattern_sync_reg = 1'b0;

always @(posedge tx_clk) begin
    cmac_ctl_tx_enable_sync_reg <= cmac_ctl_tx_enable_drp_reg;
    cmac_ctl_tx_enable_reg <= cmac_ctl_tx_enable_sync_reg;
    cmac_ctl_tx_send_idle_sync_reg <= cmac_ctl_tx_send_idle_drp_reg;
    cmac_ctl_tx_send_idle_reg <= cmac_ctl_tx_send_idle_sync_reg;
    cmac_ctl_tx_send_rfi_sync_reg <= cmac_ctl_tx_send_rfi_drp_reg;
    cmac_ctl_tx_send_rfi_reg <= cmac_ctl_tx_send_rfi_sync_reg;
    cmac_ctl_tx_send_lfi_sync_reg <= cmac_ctl_tx_send_lfi_drp_reg;
    cmac_ctl_tx_send_lfi_reg <= cmac_ctl_tx_send_lfi_sync_reg;
    cmac_ctl_tx_test_pattern_sync_reg <= cmac_ctl_tx_test_pattern_drp_reg;
    cmac_ctl_tx_test_pattern_reg <= cmac_ctl_tx_test_pattern_sync_reg;
end

// watchdog
localparam WDT_COUNT = (DRP_CLK_FREQ_HZ * 64'd750) / 1000;
localparam WDT_WIDTH = $clog2(WDT_COUNT + 1);
reg [WDT_WIDTH-1:0] wdt_count_reg = WDT_COUNT;
reg wdt_reset_reg = 1'b0;

always @(posedge drp_clk) begin
    wdt_reset_reg <= 1'b0;

    if (wdt_count_reg == 0) begin
        wdt_count_reg <= WDT_COUNT;
        wdt_reset_reg <= 1'b1;
    end else begin
        wdt_count_reg <= wdt_count_reg - 1;
    end

    if ((!tx_rst_sync_2_reg && !rx_rst_sync_2_reg && cmac_stat_rx_aligned_sync_2_reg)) begin
        wdt_count_reg <= WDT_COUNT;
        wdt_reset_reg <= 1'b0;
    end

    if (drp_rst) begin
        wdt_count_reg <= WDT_COUNT;
        wdt_reset_reg <= 1'b0;
    end
end

// DRP interface
always @(posedge drp_clk) begin
    drp_rdy_ctrl_reg <= 1'b0;
    drp_do_ctrl_reg <= 16'd0;

    if (drp_en_ctrl_reg) begin
        drp_rdy_ctrl_reg <= 1'b1;
        if (drp_we_reg) begin
            case (drp_addr_reg[15:0])
                // TX
                16'h0000: begin
                    cmac_ctl_tx_enable_drp_reg <= drp_di_reg[0];
                    tx_reset_drp_reg <= drp_di_reg[8];
                    gt_tx_reset_drp_reg <= drp_di_reg[9];
                end
                16'h0001: begin
                    cmac_ctl_tx_send_idle_drp_reg <= drp_di_reg[0];
                    cmac_ctl_tx_send_rfi_drp_reg <= drp_di_reg[1];
                    cmac_ctl_tx_send_lfi_drp_reg <= drp_di_reg[2];
                    cmac_ctl_tx_test_pattern_drp_reg <= drp_di_reg[3];
                end
                // RX
                16'h0100: begin
                    cmac_ctl_rx_enable_drp_reg <= drp_di_reg[0];
                    rx_reset_drp_reg <= drp_di_reg[8];
                    gt_rx_reset_drp_reg <= drp_di_reg[9];
                end
                16'h0101: begin
                    cmac_ctl_rx_force_resync_drp_reg <= drp_di_reg[0];
                    cmac_ctl_rx_test_pattern_drp_reg <= drp_di_reg[1];
                end
                // FEC
                16'h0200: begin
                    cmac_ctl_tx_rsfec_enable_drp_reg <= drp_di_reg[0];
                    cmac_ctl_rx_rsfec_enable_drp_reg <= drp_di_reg[1];
                end
                16'h0201: begin
                    cmac_ctl_rx_rsfec_enable_correction_drp_reg <= drp_di_reg[0];
                    cmac_ctl_rx_rsfec_enable_indication_drp_reg <= drp_di_reg[1];
                    cmac_ctl_rsfec_ieee_error_indication_mode_drp_reg <= drp_di_reg[8];
                end
            endcase
        end
        case (drp_addr_reg[15:0])
            // TX
            16'h0000: begin
                drp_do_ctrl_reg[0] <= cmac_ctl_tx_enable_drp_reg;
                drp_do_ctrl_reg[8] <= tx_reset_drp_reg;
                drp_do_ctrl_reg[9] <= gt_tx_reset_drp_reg;
                drp_do_ctrl_reg[15] <= tx_rst_sync_2_reg;
            end
            16'h0001: begin
                drp_do_ctrl_reg[0] <= cmac_ctl_tx_send_idle_drp_reg;
                drp_do_ctrl_reg[1] <= cmac_ctl_tx_send_rfi_drp_reg;
                drp_do_ctrl_reg[2] <= cmac_ctl_tx_send_lfi_drp_reg;
                drp_do_ctrl_reg[3] <= cmac_ctl_tx_test_pattern_drp_reg;
            end
            16'h0002: begin
                drp_do_ctrl_reg[0] <= cmac_stat_tx_local_fault_sync_2_reg;
                drp_do_ctrl_reg[8] <= cmac_stat_tx_ptp_fifo_read_error_sync_2_reg;
                drp_do_ctrl_reg[9] <= cmac_stat_tx_ptp_fifo_write_error_sync_2_reg;
            end
            // RX
            16'h0100: begin
                drp_do_ctrl_reg[0] <= cmac_ctl_rx_enable_drp_reg;
                drp_do_ctrl_reg[8] <= rx_reset_drp_reg;
                drp_do_ctrl_reg[9] <= gt_rx_reset_drp_reg;
                drp_do_ctrl_reg[15] <= rx_rst_sync_2_reg;
            end
            16'h0101: begin
                drp_do_ctrl_reg[0] <= cmac_ctl_rx_force_resync_drp_reg;
                drp_do_ctrl_reg[1] <= cmac_ctl_rx_test_pattern_drp_reg;
            end
            16'h0102: begin
                drp_do_ctrl_reg[0] <= cmac_stat_rx_status_sync_2_reg;
                drp_do_ctrl_reg[1] <= cmac_stat_rx_aligned_sync_2_reg;
                drp_do_ctrl_reg[8] <= cmac_stat_rx_hi_ber_sync_2_reg;
                drp_do_ctrl_reg[9] <= cmac_stat_rx_aligned_err_sync_2_reg;
                drp_do_ctrl_reg[12] <= cmac_stat_rx_internal_local_fault_sync_2_reg;
                drp_do_ctrl_reg[13] <= cmac_stat_rx_local_fault_sync_2_reg;
                drp_do_ctrl_reg[14] <= cmac_stat_rx_received_local_fault_sync_2_reg;
                drp_do_ctrl_reg[15] <= cmac_stat_rx_remote_fault_sync_2_reg;
            end
            16'h0110: drp_do_ctrl_reg <= cmac_stat_rx_block_lock_sync_2_reg[15:0];
            16'h0111: drp_do_ctrl_reg <= cmac_stat_rx_block_lock_sync_2_reg[19:16];
            16'h0112: drp_do_ctrl_reg <= cmac_stat_rx_synced_sync_2_reg[15:0];
            16'h0113: drp_do_ctrl_reg <= cmac_stat_rx_synced_sync_2_reg[19:16];
            16'h0114: drp_do_ctrl_reg <= cmac_stat_rx_synced_err_sync_2_reg[15:0];
            16'h0115: drp_do_ctrl_reg <= cmac_stat_rx_synced_err_sync_2_reg[19:16];
            16'h0116: drp_do_ctrl_reg <= cmac_stat_rx_mf_len_err_sync_2_reg[15:0];
            16'h0117: drp_do_ctrl_reg <= cmac_stat_rx_mf_len_err_sync_2_reg[19:16];
            16'h0118: drp_do_ctrl_reg <= cmac_stat_rx_mf_repeat_err_sync_2_reg[15:0];
            16'h0119: drp_do_ctrl_reg <= cmac_stat_rx_mf_repeat_err_sync_2_reg[19:16];
            16'h0120: drp_do_ctrl_reg <= cmac_stat_rx_pcsl_demuxed_sync_2_reg[15:0];
            16'h0121: drp_do_ctrl_reg <= cmac_stat_rx_pcsl_demuxed_sync_2_reg[19:16];
            16'h0130: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*0 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*1 +: 5];
            end
            16'h0131: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*2 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*3 +: 5];
            end
            16'h0132: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*4 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*5 +: 5];
            end
            16'h0133: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*6 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*7 +: 5];
            end
            16'h0134: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*8 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*9 +: 5];
            end
            16'h0135: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*10 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*11 +: 5];
            end
            16'h0136: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*12 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*13 +: 5];
            end
            16'h0137: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*14 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*15 +: 5];
            end
            16'h0138: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*16 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*17 +: 5];
            end
            16'h0139: begin
                drp_do_ctrl_reg[7:0] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*18 +: 5];
                drp_do_ctrl_reg[15:8] <= cmac_stat_rx_pcsl_number_sync_2_reg[5*19 +: 5];
            end
            16'h0140: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*0 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*1 +: 7];
            end
            16'h0141: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*2 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*3 +: 7];
            end
            16'h0142: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*4 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*5 +: 7];
            end
            16'h0143: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*6 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*7 +: 7];
            end
            16'h0144: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*8 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*9 +: 7];
            end
            16'h0145: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*10 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*11 +: 7];
            end
            16'h0146: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*12 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*13 +: 7];
            end
            16'h0147: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*14 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*15 +: 7];
            end
            16'h0148: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*16 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*17 +: 7];
            end
            16'h0149: begin
                drp_do_ctrl_reg[7:0] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*18 +: 7];
                drp_do_ctrl_reg[15:8] <= cmac_rx_lane_aligner_fill_sync_2_reg[7*19 +: 7];
            end
            // FEC
            16'h0200: begin
                drp_do_ctrl_reg[0] <= cmac_ctl_tx_rsfec_enable_drp_reg;
                drp_do_ctrl_reg[1] <= cmac_ctl_rx_rsfec_enable_drp_reg;
            end
            16'h0201: begin
                drp_do_ctrl_reg[0] <= cmac_ctl_rx_rsfec_enable_correction_drp_reg;
                drp_do_ctrl_reg[1] <= cmac_ctl_rx_rsfec_enable_indication_drp_reg;
                drp_do_ctrl_reg[8] <= cmac_ctl_rsfec_ieee_error_indication_mode_drp_reg;
            end
            16'h0202: begin
                drp_do_ctrl_reg[0] <= cmac_stat_rx_rsfec_lane_alignment_status_sync_2_reg;
                drp_do_ctrl_reg[8] <= cmac_stat_rx_rsfec_hi_ser_sync_2_reg;
            end
            16'h0203: begin
                drp_do_ctrl_reg[3:0] <= cmac_stat_rx_rsfec_am_lock_sync_2_reg;
            end
            16'h0204: begin
                drp_do_ctrl_reg[1:0] <= cmac_stat_rx_rsfec_lane_mapping_sync_2_reg[2*0 +: 2];
                drp_do_ctrl_reg[7:4] <= cmac_stat_rx_rsfec_lane_mapping_sync_2_reg[2*1 +: 2];
                drp_do_ctrl_reg[11:8] <= cmac_stat_rx_rsfec_lane_mapping_sync_2_reg[2*2 +: 2];
                drp_do_ctrl_reg[15:12] <= cmac_stat_rx_rsfec_lane_mapping_sync_2_reg[2*3 +: 2];
            end
            16'h0206: drp_do_ctrl_reg <= cmac_stat_rx_rsfec_lane_fill_sync_2_reg[14*0 +: 14];
            16'h0207: drp_do_ctrl_reg <= cmac_stat_rx_rsfec_lane_fill_sync_2_reg[14*1 +: 14];
            16'h0208: drp_do_ctrl_reg <= cmac_stat_rx_rsfec_lane_fill_sync_2_reg[14*2 +: 14];
            16'h0209: drp_do_ctrl_reg <= cmac_stat_rx_rsfec_lane_fill_sync_2_reg[14*3 +: 14];
        endcase
    end

    if (drp_rst) begin
        drp_rdy_ctrl_reg <= 1'b0;

        tx_reset_drp_reg <= 1'b0;
        gt_tx_reset_drp_reg <= 1'b0;
        rx_reset_drp_reg <= 1'b0;
        gt_rx_reset_drp_reg <= 1'b0;

        cmac_ctl_tx_rsfec_enable_drp_reg <= RS_FEC_ENABLE;
        cmac_ctl_rx_rsfec_enable_drp_reg <= RS_FEC_ENABLE;
        cmac_ctl_rsfec_ieee_error_indication_mode_drp_reg <= 1'b0;
        cmac_ctl_rx_rsfec_enable_correction_drp_reg <= 1'b1;
        cmac_ctl_rx_rsfec_enable_indication_drp_reg <= 1'b1;

        cmac_ctl_rx_enable_drp_reg <= 1'b1;
        cmac_ctl_rx_force_resync_drp_reg <= 1'b0;
        cmac_ctl_rx_test_pattern_drp_reg <= 1'b0;

        cmac_ctl_tx_enable_drp_reg <= 1'b1;
        cmac_ctl_tx_send_idle_drp_reg <= 1'b0;
        cmac_ctl_tx_send_rfi_drp_reg <= 1'b0;
        cmac_ctl_tx_send_lfi_drp_reg <= 1'b0;
        cmac_ctl_tx_test_pattern_drp_reg <= 1'b0;
    end
end

// serdes clock and reset
wire [3:0] gt_tx_reset;
wire [3:0] gt_tx_reset_out;
wire gt_txoutclk;
wire gt_txoutclk_bufg;
wire gt_txusrclk;
wire gt_txusrclk2;
wire [3:0] gt_rx_reset;
wire [3:0] gt_rx_reset_out;
wire gt_rxoutclk;
wire gt_rxoutclk_bufg;
wire [3:0] gt_rxusrclk;
wire [3:0] gt_rxusrclk2;

assign gt_tx_reset[0] = gt_tx_reset_drp_reg;
assign gt_tx_reset[1] = gt_tx_reset_drp_reg || gt_tx_reset_out[0];
assign gt_tx_reset[2] = gt_tx_reset_drp_reg || gt_tx_reset_out[0];
assign gt_tx_reset[3] = gt_tx_reset_drp_reg || gt_tx_reset_out[0];

assign gt_rx_reset[0] = gt_rx_reset_drp_reg || wdt_reset_reg;
assign gt_rx_reset[1] = gt_rx_reset_drp_reg || wdt_reset_reg || gt_rx_reset_out[0];
assign gt_rx_reset[2] = gt_rx_reset_drp_reg || wdt_reset_reg || gt_rx_reset_out[0];
assign gt_rx_reset[3] = gt_rx_reset_drp_reg || wdt_reset_reg || gt_rx_reset_out[0];

BUFG_GT bufg_gt_txusrclk_inst (
    .CE      (1'b1),
    .CEMASK  (1'b0),
    .CLR     (gt_tx_reset_out[0]),
    .CLRMASK (1'b0),
    .DIV     (3'd0),
    .I       (gt_txoutclk),
    .O       (gt_txoutclk_bufg)
);

assign gt_txusrclk = gt_txoutclk_bufg;
assign gt_txusrclk2 = gt_txoutclk_bufg;

BUFG_GT bufg_gt_rxusrclk_inst (
    .CE      (1'b1),
    .CEMASK  (1'b0),
    .CLR     (gt_rx_reset_out[0]),
    .CLRMASK (1'b0),
    .DIV     (3'd0),
    .I       (gt_rxoutclk),
    .O       (gt_rxoutclk_bufg)
);

assign gt_rxusrclk = {4{gt_rxoutclk_bufg}};
assign gt_rxusrclk2 = {4{gt_rxoutclk_bufg}};

assign tx_clk = gt_txusrclk2;

wire tx_rst_int;

sync_reset #(
    .N(4)
)
sync_reset_tx_rst_inst (
    .clk(tx_clk),
    .rst(gt_tx_reset_out[0] || ~gt_tx_reset_done || tx_reset_drp_reg || drp_rst || xcvr_ctrl_rst),
    .out(tx_rst_int)
);

// extra register for tx_rst signal
(* shreg_extract = "no" *)
reg tx_rst_reg_1 = 1'b1;
(* shreg_extract = "no" *)
reg tx_rst_reg_2 = 1'b1;

always @(posedge tx_clk) begin
    tx_rst_reg_1 <= tx_rst_int;
    tx_rst_reg_2 <= tx_rst_reg_1;
end

assign tx_rst = tx_rst_reg_2;

assign rx_clk = gt_rxusrclk2[0];

wire rx_rst_int;

sync_reset #(
    .N(4)
)
sync_reset_rx_rst_inst (
    .clk(rx_clk),
    .rst(gt_tx_reset_out[0] || ~gt_rx_reset_done || rx_reset_drp_reg || drp_rst || xcvr_ctrl_rst),
    .out(rx_rst_int)
);

// extra register for rx_rst signal
(* shreg_extract = "no" *)
reg rx_rst_reg_1 = 1'b1;
(* shreg_extract = "no" *)
reg rx_rst_reg_2 = 1'b1;

always @(posedge rx_clk) begin
    rx_rst_reg_1 <= rx_rst_int;
    rx_rst_reg_2 <= rx_rst_reg_1;
end

assign rx_rst = rx_rst_reg_2;

// serdes data
// 80 bit mode - 64 bits in data, 8 bits each in ctrl0 and ctrl1 (per serdes)
// widths match concatenated GTY ports (not all bits used)
wire [511:0] gt_txdata;
wire [63:0]  gt_txctrl0;
wire [63:0]  gt_txctrl1;
wire [511:0] gt_rxdata;
wire [63:0]  gt_rxctrl0;
wire [63:0]  gt_rxctrl1;

wire [3:0] gt_tx_reset_done;
wire [3:0] gt_rx_reset_done;

wire xcvr_qpll0lock;
wire xcvr_qpll0clk;
wire xcvr_qpll0refclk;

wire xcvr_qpll1lock;
wire xcvr_qpll1clk;
wire xcvr_qpll1refclk;

cmac_gty_ch_wrapper #(
    .HAS_COMMON(1),
    // PLL
    .QPLL0_PD(QPLL0_PD),
    .QPLL1_PD(QPLL1_PD),
    // GT
    .GT_TX_PD(GT_1_TX_PD),
    .GT_TX_QPLL_SEL(GT_1_TX_QPLL_SEL),
    .GT_TX_POLARITY(GT_1_TX_POLARITY),
    .GT_TX_ELECIDLE(GT_1_TX_ELECIDLE),
    .GT_TX_INHIBIT(GT_1_TX_INHIBIT),
    .GT_TX_DIFFCTRL(GT_1_TX_DIFFCTRL),
    .GT_TX_MAINCURSOR(GT_1_TX_MAINCURSOR),
    .GT_TX_POSTCURSOR(GT_1_TX_POSTCURSOR),
    .GT_TX_PRECURSOR(GT_1_TX_PRECURSOR),
    .GT_RX_PD(GT_1_RX_PD),
    .GT_RX_QPLL_SEL(GT_1_RX_QPLL_SEL),
    .GT_RX_LPM_EN(GT_1_RX_LPM_EN),
    .GT_RX_POLARITY(GT_1_RX_POLARITY)
)
gty_ch_1 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Common
    .xcvr_gtpowergood_out(xcvr_gtpowergood_out),

    // DRP
    .drp_clk(drp_clk),
    .drp_rst(drp_rst),
    .drp_addr(drp_addr_reg),
    .drp_di(drp_di_reg),
    .drp_en(drp_en_gty_reg_1),
    .drp_we(drp_we_reg),
    .drp_do(drp_do_gty_1),
    .drp_rdy(drp_rdy_gty_1),

    // PLL out
    .xcvr_gtrefclk00_in(xcvr_ref_clk),
    .xcvr_qpll0lock_out(xcvr_qpll0lock),
    .xcvr_qpll0clk_out(xcvr_qpll0clk),
    .xcvr_qpll0refclk_out(xcvr_qpll0refclk),
    .xcvr_gtrefclk01_in(xcvr_ref_clk),
    .xcvr_qpll1lock_out(xcvr_qpll1lock),
    .xcvr_qpll1clk_out(xcvr_qpll1clk),
    .xcvr_qpll1refclk_out(xcvr_qpll1refclk),
 
    // PLL in
    .xcvr_qpll0lock_in(1'b0),
    .xcvr_qpll0clk_in(1'b0),
    .xcvr_qpll0refclk_in(1'b0),
    .xcvr_qpll1lock_in(1'b0),
    .xcvr_qpll1clk_in(1'b0),
    .xcvr_qpll1refclk_in(1'b0),

    // Serial data
    .xcvr_txp(xcvr_txp[0]),
    .xcvr_txn(xcvr_txn[0]),
    .xcvr_rxp(xcvr_rxp[0]),
    .xcvr_rxn(xcvr_rxn[0]),

    // Parallel data
    .gt_txoutclk(gt_txoutclk),
    .gt_txusrclk(gt_txusrclk),
    .gt_txusrclk2(gt_txusrclk2),
    .tx_reset_in(gt_tx_reset[0]),
    .tx_reset_done(gt_tx_reset_done[0]),
    .gt_tx_reset_out(gt_tx_reset_out[0]),
    .gt_tx_reset_done(),
    .gt_txdata(gt_txdata[0*128 +: 128]),
    .gt_txctrl0(gt_txctrl0[0*16 +: 16]),
    .gt_txctrl1(gt_txctrl1[0*16 +: 16]),
    .gt_rxoutclk(gt_rxoutclk),
    .gt_rxusrclk(gt_rxusrclk[0]),
    .gt_rxusrclk2(gt_rxusrclk2[0]),
    .rx_reset_in(gt_rx_reset[0]),
    .rx_reset_done(gt_rx_reset_done[0]),
    .gt_rx_reset_out(gt_rx_reset_out[0]),
    .gt_rx_reset_done(),
    .gt_rxdata(gt_rxdata[0*128 +: 128]),
    .gt_rxctrl0(gt_rxctrl0[0*16 +: 16]),
    .gt_rxctrl1(gt_rxctrl1[0*16 +: 16])
);

cmac_gty_ch_wrapper #(
    .HAS_COMMON(0),
    // GT
    .GT_TX_PD(GT_2_TX_PD),
    .GT_TX_QPLL_SEL(GT_2_TX_QPLL_SEL),
    .GT_TX_POLARITY(GT_2_TX_POLARITY),
    .GT_TX_ELECIDLE(GT_2_TX_ELECIDLE),
    .GT_TX_INHIBIT(GT_2_TX_INHIBIT),
    .GT_TX_DIFFCTRL(GT_2_TX_DIFFCTRL),
    .GT_TX_MAINCURSOR(GT_2_TX_MAINCURSOR),
    .GT_TX_POSTCURSOR(GT_2_TX_POSTCURSOR),
    .GT_TX_PRECURSOR(GT_2_TX_PRECURSOR),
    .GT_RX_PD(GT_2_RX_PD),
    .GT_RX_QPLL_SEL(GT_2_RX_QPLL_SEL),
    .GT_RX_LPM_EN(GT_2_RX_LPM_EN),
    .GT_RX_POLARITY(GT_2_RX_POLARITY)
)
gty_ch_2 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // DRP
    .drp_clk(drp_clk),
    .drp_rst(drp_rst),
    .drp_addr(drp_addr_reg),
    .drp_di(drp_di_reg),
    .drp_en(drp_en_gty_reg_2),
    .drp_we(drp_we_reg),
    .drp_do(drp_do_gty_2),
    .drp_rdy(drp_rdy_gty_2),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0clk_out(),
    .xcvr_qpll0refclk_out(),
    .xcvr_gtrefclk01_in(1'b0),
    .xcvr_qpll1lock_out(),
    .xcvr_qpll1clk_out(),
    .xcvr_qpll1refclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(xcvr_qpll0lock),
    .xcvr_qpll0clk_in(xcvr_qpll0clk),
    .xcvr_qpll0refclk_in(xcvr_qpll0refclk),
    .xcvr_qpll1lock_in(xcvr_qpll1lock),
    .xcvr_qpll1clk_in(xcvr_qpll1clk),
    .xcvr_qpll1refclk_in(xcvr_qpll1refclk),

    // Serial data
    .xcvr_txp(xcvr_txp[1]),
    .xcvr_txn(xcvr_txn[1]),
    .xcvr_rxp(xcvr_rxp[1]),
    .xcvr_rxn(xcvr_rxn[1]),

    // Parallel data
    .gt_txoutclk(),
    .gt_txusrclk(gt_txusrclk),
    .gt_txusrclk2(gt_txusrclk2),
    .tx_reset_in(gt_tx_reset[1]),
    .tx_reset_done(gt_tx_reset_done[1]),
    .gt_tx_reset_out(gt_tx_reset_out[1]),
    .gt_tx_reset_done(),
    .gt_txdata(gt_txdata[1*128 +: 128]),
    .gt_txctrl0(gt_txctrl0[1*16 +: 16]),
    .gt_txctrl1(gt_txctrl1[1*16 +: 16]),
    .gt_rxoutclk(),
    .gt_rxusrclk(gt_rxusrclk[1]),
    .gt_rxusrclk2(gt_rxusrclk2[1]),
    .rx_reset_in(gt_rx_reset[1]),
    .rx_reset_done(gt_rx_reset_done[1]),
    .gt_rx_reset_out(gt_rx_reset_out[1]),
    .gt_rx_reset_done(),
    .gt_rxdata(gt_rxdata[1*128 +: 128]),
    .gt_rxctrl0(gt_rxctrl0[1*16 +: 16]),
    .gt_rxctrl1(gt_rxctrl1[1*16 +: 16])
);

cmac_gty_ch_wrapper #(
    .HAS_COMMON(0),
    // GT
    .GT_TX_PD(GT_3_TX_PD),
    .GT_TX_QPLL_SEL(GT_3_TX_QPLL_SEL),
    .GT_TX_POLARITY(GT_3_TX_POLARITY),
    .GT_TX_ELECIDLE(GT_3_TX_ELECIDLE),
    .GT_TX_INHIBIT(GT_3_TX_INHIBIT),
    .GT_TX_DIFFCTRL(GT_3_TX_DIFFCTRL),
    .GT_TX_MAINCURSOR(GT_3_TX_MAINCURSOR),
    .GT_TX_POSTCURSOR(GT_3_TX_POSTCURSOR),
    .GT_TX_PRECURSOR(GT_3_TX_PRECURSOR),
    .GT_RX_PD(GT_3_RX_PD),
    .GT_RX_QPLL_SEL(GT_3_RX_QPLL_SEL),
    .GT_RX_LPM_EN(GT_3_RX_LPM_EN),
    .GT_RX_POLARITY(GT_3_RX_POLARITY)
)
gty_ch_3 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // DRP
    .drp_clk(drp_clk),
    .drp_rst(drp_rst),
    .drp_addr(drp_addr_reg),
    .drp_di(drp_di_reg),
    .drp_en(drp_en_gty_reg_3),
    .drp_we(drp_we_reg),
    .drp_do(drp_do_gty_3),
    .drp_rdy(drp_rdy_gty_3),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0clk_out(),
    .xcvr_qpll0refclk_out(),
    .xcvr_gtrefclk01_in(1'b0),
    .xcvr_qpll1lock_out(),
    .xcvr_qpll1clk_out(),
    .xcvr_qpll1refclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(xcvr_qpll0lock),
    .xcvr_qpll0clk_in(xcvr_qpll0clk),
    .xcvr_qpll0refclk_in(xcvr_qpll0refclk),
    .xcvr_qpll1lock_in(xcvr_qpll1lock),
    .xcvr_qpll1clk_in(xcvr_qpll1clk),
    .xcvr_qpll1refclk_in(xcvr_qpll1refclk),

    // Serial data
    .xcvr_txp(xcvr_txp[2]),
    .xcvr_txn(xcvr_txn[2]),
    .xcvr_rxp(xcvr_rxp[2]),
    .xcvr_rxn(xcvr_rxn[2]),

    // Parallel data
    .gt_txoutclk(),
    .gt_txusrclk(gt_txusrclk),
    .gt_txusrclk2(gt_txusrclk2),
    .tx_reset_in(gt_tx_reset[2]),
    .tx_reset_done(gt_tx_reset_done[2]),
    .gt_tx_reset_out(gt_tx_reset_out[2]),
    .gt_tx_reset_done(),
    .gt_txdata(gt_txdata[2*128 +: 128]),
    .gt_txctrl0(gt_txctrl0[2*16 +: 16]),
    .gt_txctrl1(gt_txctrl1[2*16 +: 16]),
    .gt_rxoutclk(),
    .gt_rxusrclk(gt_rxusrclk[2]),
    .gt_rxusrclk2(gt_rxusrclk2[2]),
    .rx_reset_in(gt_rx_reset[2]),
    .rx_reset_done(gt_rx_reset_done[2]),
    .gt_rx_reset_out(gt_rx_reset_out[2]),
    .gt_rx_reset_done(),
    .gt_rxdata(gt_rxdata[2*128 +: 128]),
    .gt_rxctrl0(gt_rxctrl0[2*16 +: 16]),
    .gt_rxctrl1(gt_rxctrl1[2*16 +: 16])
);

cmac_gty_ch_wrapper #(
    .HAS_COMMON(0),
    // GT
    .GT_TX_PD(GT_4_TX_PD),
    .GT_TX_QPLL_SEL(GT_4_TX_QPLL_SEL),
    .GT_TX_POLARITY(GT_4_TX_POLARITY),
    .GT_TX_ELECIDLE(GT_4_TX_ELECIDLE),
    .GT_TX_INHIBIT(GT_4_TX_INHIBIT),
    .GT_TX_DIFFCTRL(GT_4_TX_DIFFCTRL),
    .GT_TX_MAINCURSOR(GT_4_TX_MAINCURSOR),
    .GT_TX_POSTCURSOR(GT_4_TX_POSTCURSOR),
    .GT_TX_PRECURSOR(GT_4_TX_PRECURSOR),
    .GT_RX_PD(GT_4_RX_PD),
    .GT_RX_QPLL_SEL(GT_4_RX_QPLL_SEL),
    .GT_RX_LPM_EN(GT_4_RX_LPM_EN),
    .GT_RX_POLARITY(GT_4_RX_POLARITY)
)
gty_ch_4 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // DRP
    .drp_clk(drp_clk),
    .drp_rst(drp_rst),
    .drp_addr(drp_addr_reg),
    .drp_di(drp_di_reg),
    .drp_en(drp_en_gty_reg_4),
    .drp_we(drp_we_reg),
    .drp_do(drp_do_gty_4),
    .drp_rdy(drp_rdy_gty_4),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0clk_out(),
    .xcvr_qpll0refclk_out(),
    .xcvr_gtrefclk01_in(1'b0),
    .xcvr_qpll1lock_out(),
    .xcvr_qpll1clk_out(),
    .xcvr_qpll1refclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(xcvr_qpll0lock),
    .xcvr_qpll0clk_in(xcvr_qpll0clk),
    .xcvr_qpll0refclk_in(xcvr_qpll0refclk),
    .xcvr_qpll1lock_in(xcvr_qpll1lock),
    .xcvr_qpll1clk_in(xcvr_qpll1clk),
    .xcvr_qpll1refclk_in(xcvr_qpll1refclk),

    // Serial data
    .xcvr_txp(xcvr_txp[3]),
    .xcvr_txn(xcvr_txn[3]),
    .xcvr_rxp(xcvr_rxp[3]),
    .xcvr_rxn(xcvr_rxn[3]),

    // Parallel data
    .gt_txoutclk(),
    .gt_txusrclk(gt_txusrclk),
    .gt_txusrclk2(gt_txusrclk2),
    .tx_reset_in(gt_tx_reset[3]),
    .tx_reset_done(gt_tx_reset_done[3]),
    .gt_tx_reset_out(gt_tx_reset_out[3]),
    .gt_tx_reset_done(),
    .gt_txdata(gt_txdata[3*128 +: 128]),
    .gt_txctrl0(gt_txctrl0[3*16 +: 16]),
    .gt_txctrl1(gt_txctrl1[3*16 +: 16]),
    .gt_rxoutclk(),
    .gt_rxusrclk(gt_rxusrclk[3]),
    .gt_rxusrclk2(gt_rxusrclk2[3]),
    .rx_reset_in(gt_rx_reset[3]),
    .rx_reset_done(gt_rx_reset_done[3]),
    .gt_rx_reset_out(gt_rx_reset_out[3]),
    .gt_rx_reset_done(),
    .gt_rxdata(gt_rxdata[3*128 +: 128]),
    .gt_rxctrl0(gt_rxctrl0[3*16 +: 16]),
    .gt_rxctrl1(gt_rxctrl1[3*16 +: 16])
);

wire [511:0] cmac_txdata;
wire [63:0]  cmac_txctrl0;
wire [63:0]  cmac_txctrl1;
wire [511:0] cmac_rxdata;
wire [63:0]  cmac_rxctrl0;
wire [63:0]  cmac_rxctrl1;

generate

genvar n;

if (TX_SERDES_PIPELINE) begin

    (* shreg_extract = "no" *)
    reg [511:0] cmac_txdata_pipe_reg[TX_SERDES_PIPELINE-1:0];
    (* shreg_extract = "no" *)
    reg [63:0]  cmac_txctrl0_pipe_reg[TX_SERDES_PIPELINE-1:0];
    (* shreg_extract = "no" *)
    reg [63:0]  cmac_txctrl1_pipe_reg[TX_SERDES_PIPELINE-1:0];

    integer i;

    for (n = 0; n < 4; n = n + 1) begin
        always @(posedge gt_txusrclk2) begin
            cmac_txdata_pipe_reg[0][128*n +: 64] <= cmac_txdata[128*n +: 64];
            cmac_txctrl0_pipe_reg[0][16*n +: 8] <= cmac_txctrl0[16*n +: 8];
            cmac_txctrl1_pipe_reg[0][16*n +: 8] <= cmac_txctrl1[16*n +: 8];

            for (i = 1; i < TX_SERDES_PIPELINE; i = i + 1) begin
                cmac_txdata_pipe_reg[i][128*n +: 64] <= cmac_txdata_pipe_reg[i-1][128*n +: 64];
                cmac_txctrl0_pipe_reg[i][16*n +: 8] <= cmac_txctrl0_pipe_reg[i-1][16*n +: 8];
                cmac_txctrl1_pipe_reg[i][16*n +: 8] <= cmac_txctrl1_pipe_reg[i-1][16*n +: 8];
            end
        end
    end

    assign gt_txdata = cmac_txdata_pipe_reg[TX_SERDES_PIPELINE-1];
    assign gt_txctrl0 = cmac_txctrl0_pipe_reg[TX_SERDES_PIPELINE-1];
    assign gt_txctrl1 = cmac_txctrl1_pipe_reg[TX_SERDES_PIPELINE-1];

end else begin

    assign gt_txdata = cmac_txdata;
    assign gt_txctrl0 = cmac_txctrl0;
    assign gt_txctrl1 = cmac_txctrl1;

end

if (RX_SERDES_PIPELINE) begin

    (* shreg_extract = "no" *)
    reg [511:0] cmac_rxdata_pipe_reg[RX_SERDES_PIPELINE-1:0];
    (* shreg_extract = "no" *)
    reg [63:0]  cmac_rxctrl0_pipe_reg[RX_SERDES_PIPELINE-1:0];
    (* shreg_extract = "no" *)
    reg [63:0]  cmac_rxctrl1_pipe_reg[RX_SERDES_PIPELINE-1:0];

    integer i;

    for (n = 0; n < 4; n = n + 1) begin
        always @(posedge gt_rxusrclk2[n]) begin
            cmac_rxdata_pipe_reg[0][128*n +: 64] <= gt_rxdata[128*n +: 64];
            cmac_rxctrl0_pipe_reg[0][16*n +: 8] <= gt_rxctrl0[16*n +: 8];
            cmac_rxctrl1_pipe_reg[0][16*n +: 8] <= gt_rxctrl1[16*n +: 8];

            for (i = 1; i < RX_SERDES_PIPELINE; i = i + 1) begin
                cmac_rxdata_pipe_reg[i][128*n +: 64] <= cmac_rxdata_pipe_reg[i-1][128*n +: 64];
                cmac_rxctrl0_pipe_reg[i][16*n +: 8] <= cmac_rxctrl0_pipe_reg[i-1][16*n +: 8];
                cmac_rxctrl1_pipe_reg[i][16*n +: 8] <= cmac_rxctrl1_pipe_reg[i-1][16*n +: 8];
            end
        end
    end

    assign cmac_rxdata = cmac_rxdata_pipe_reg[RX_SERDES_PIPELINE-1];
    assign cmac_rxctrl0 = cmac_rxctrl0_pipe_reg[RX_SERDES_PIPELINE-1];
    assign cmac_rxctrl1 = cmac_rxctrl1_pipe_reg[RX_SERDES_PIPELINE-1];

end else begin

    assign cmac_rxdata = gt_rxdata;
    assign cmac_rxctrl0 = gt_rxctrl0;
    assign cmac_rxctrl1 = gt_rxctrl1;

end

endgenerate

wire [AXIS_DATA_WIDTH-1:0] cmac_tx_axis_tdata;
wire [AXIS_KEEP_WIDTH-1:0] cmac_tx_axis_tkeep;
wire                       cmac_tx_axis_tvalid;
wire                       cmac_tx_axis_tready;
wire                       cmac_tx_axis_tlast;
wire [16+1-1:0]            cmac_tx_axis_tuser;

wire [AXIS_DATA_WIDTH-1:0] cmac_rx_axis_tdata;
wire [AXIS_KEEP_WIDTH-1:0] cmac_rx_axis_tkeep;
wire                       cmac_rx_axis_tvalid;
wire                       cmac_rx_axis_tlast;
wire                       cmac_rx_axis_tuser;
wire [79:0]                cmac_rx_ptp_ts;

cmac_pad #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .USER_WIDTH(16+1)
)
cmac_pad_inst (
    .clk(tx_clk),
    .rst(tx_rst),

    .s_axis_tdata(tx_axis_tdata),
    .s_axis_tkeep(tx_axis_tkeep),
    .s_axis_tvalid(tx_axis_tvalid),
    .s_axis_tready(tx_axis_tready),
    .s_axis_tlast(tx_axis_tlast),
    .s_axis_tuser(tx_axis_tuser),

    .m_axis_tdata(cmac_tx_axis_tdata),
    .m_axis_tkeep(cmac_tx_axis_tkeep),
    .m_axis_tvalid(cmac_tx_axis_tvalid),
    .m_axis_tready(cmac_tx_axis_tready),
    .m_axis_tlast(cmac_tx_axis_tlast),
    .m_axis_tuser(cmac_tx_axis_tuser)
);

mac_ts_insert #(
    .PTP_TS_WIDTH(80),
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .S_USER_WIDTH(1),
    .M_USER_WIDTH(80+1)
)
mac_ts_insert_inst (
    .clk(rx_clk),
    .rst(rx_rst),

    .ptp_ts(cmac_rx_ptp_ts),

    .s_axis_tdata(cmac_rx_axis_tdata),
    .s_axis_tkeep(cmac_rx_axis_tkeep),
    .s_axis_tvalid(cmac_rx_axis_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(cmac_rx_axis_tlast),
    .s_axis_tuser(cmac_rx_axis_tuser),

    .m_axis_tdata(rx_axis_tdata),
    .m_axis_tkeep(rx_axis_tkeep),
    .m_axis_tvalid(rx_axis_tvalid),
    .m_axis_tready(1'b1),
    .m_axis_tlast(rx_axis_tlast),
    .m_axis_tuser(rx_axis_tuser)
);

cmac_usplus cmac_inst (
    .txdata_in(cmac_txdata),
    .txctrl0_in(cmac_txctrl0),
    .txctrl1_in(cmac_txctrl1),
    .rxdata_out(cmac_rxdata),
    .rxctrl0_out(cmac_rxctrl0),
    .rxctrl1_out(cmac_rxctrl1),

    .ctl_tx_rsfec_enable(cmac_ctl_tx_rsfec_enable_reg),
    .ctl_rx_rsfec_enable(cmac_ctl_rx_rsfec_enable_reg),
    .ctl_rsfec_ieee_error_indication_mode(cmac_ctl_rsfec_ieee_error_indication_mode_reg),
    .ctl_rx_rsfec_enable_correction(cmac_ctl_rx_rsfec_enable_correction_reg),
    .ctl_rx_rsfec_enable_indication(cmac_ctl_rx_rsfec_enable_indication_reg),
    .stat_rx_rsfec_am_lock0(cmac_stat_rx_rsfec_am_lock[0]),
    .stat_rx_rsfec_am_lock1(cmac_stat_rx_rsfec_am_lock[1]),
    .stat_rx_rsfec_am_lock2(cmac_stat_rx_rsfec_am_lock[2]),
    .stat_rx_rsfec_am_lock3(cmac_stat_rx_rsfec_am_lock[3]),
    .stat_rx_rsfec_err_count0_inc(cmac_stat_rx_rsfec_err_count_inc[3*0 +: 3]),
    .stat_rx_rsfec_err_count1_inc(cmac_stat_rx_rsfec_err_count_inc[3*1 +: 3]),
    .stat_rx_rsfec_err_count2_inc(cmac_stat_rx_rsfec_err_count_inc[3*2 +: 3]),
    .stat_rx_rsfec_err_count3_inc(cmac_stat_rx_rsfec_err_count_inc[3*3 +: 3]),
    .stat_rx_rsfec_hi_ser(cmac_stat_rx_rsfec_hi_ser),
    .stat_rx_rsfec_lane_alignment_status(cmac_stat_rx_rsfec_lane_alignment_status),
    .stat_rx_rsfec_lane_fill_0(cmac_stat_rx_rsfec_lane_fill[14*0 +: 14]),
    .stat_rx_rsfec_lane_fill_1(cmac_stat_rx_rsfec_lane_fill[14*1 +: 14]),
    .stat_rx_rsfec_lane_fill_2(cmac_stat_rx_rsfec_lane_fill[14*2 +: 14]),
    .stat_rx_rsfec_lane_fill_3(cmac_stat_rx_rsfec_lane_fill[14*3 +: 14]),
    .stat_rx_rsfec_lane_mapping(cmac_stat_rx_rsfec_lane_mapping),
    .stat_rx_rsfec_cw_inc(cmac_stat_rx_rsfec_cw_inc),
    .stat_rx_rsfec_corrected_cw_inc(cmac_stat_rx_rsfec_corrected_cw_inc),
    .stat_rx_rsfec_uncorrected_cw_inc(cmac_stat_rx_rsfec_uncorrected_cw_inc),

    .rx_axis_tvalid(cmac_rx_axis_tvalid),
    .rx_axis_tdata(cmac_rx_axis_tdata),
    .rx_axis_tlast(cmac_rx_axis_tlast),
    .rx_axis_tkeep(cmac_rx_axis_tkeep),
    .rx_axis_tuser(cmac_rx_axis_tuser),

    .rx_otn_bip8_0(),
    .rx_otn_bip8_1(),
    .rx_otn_bip8_2(),
    .rx_otn_bip8_3(),
    .rx_otn_bip8_4(),
    .rx_otn_data_0(),
    .rx_otn_data_1(),
    .rx_otn_data_2(),
    .rx_otn_data_3(),
    .rx_otn_data_4(),
    .rx_otn_ena(),
    .rx_otn_lane0(),
    .rx_otn_vlmarker(),

    .rx_preambleout(),

    .rx_lane_aligner_fill_0(cmac_rx_lane_aligner_fill[7*0 +: 7]),
    .rx_lane_aligner_fill_1(cmac_rx_lane_aligner_fill[7*1 +: 7]),
    .rx_lane_aligner_fill_2(cmac_rx_lane_aligner_fill[7*2 +: 7]),
    .rx_lane_aligner_fill_3(cmac_rx_lane_aligner_fill[7*3 +: 7]),
    .rx_lane_aligner_fill_4(cmac_rx_lane_aligner_fill[7*4 +: 7]),
    .rx_lane_aligner_fill_5(cmac_rx_lane_aligner_fill[7*5 +: 7]),
    .rx_lane_aligner_fill_6(cmac_rx_lane_aligner_fill[7*6 +: 7]),
    .rx_lane_aligner_fill_7(cmac_rx_lane_aligner_fill[7*7 +: 7]),
    .rx_lane_aligner_fill_8(cmac_rx_lane_aligner_fill[7*8 +: 7]),
    .rx_lane_aligner_fill_9(cmac_rx_lane_aligner_fill[7*9 +: 7]),
    .rx_lane_aligner_fill_10(cmac_rx_lane_aligner_fill[7*10 +: 7]),
    .rx_lane_aligner_fill_11(cmac_rx_lane_aligner_fill[7*11 +: 7]),
    .rx_lane_aligner_fill_12(cmac_rx_lane_aligner_fill[7*12 +: 7]),
    .rx_lane_aligner_fill_13(cmac_rx_lane_aligner_fill[7*13 +: 7]),
    .rx_lane_aligner_fill_14(cmac_rx_lane_aligner_fill[7*14 +: 7]),
    .rx_lane_aligner_fill_15(cmac_rx_lane_aligner_fill[7*15 +: 7]),
    .rx_lane_aligner_fill_16(cmac_rx_lane_aligner_fill[7*16 +: 7]),
    .rx_lane_aligner_fill_17(cmac_rx_lane_aligner_fill[7*17 +: 7]),
    .rx_lane_aligner_fill_18(cmac_rx_lane_aligner_fill[7*18 +: 7]),
    .rx_lane_aligner_fill_19(cmac_rx_lane_aligner_fill[7*19 +: 7]),

    .rx_ptp_tstamp_out(cmac_rx_ptp_ts),
    .rx_ptp_pcslane_out(),
    .ctl_rx_systemtimerin(rx_ptp_time),

    .stat_rx_aligned(cmac_stat_rx_aligned),
    .stat_rx_aligned_err(cmac_stat_rx_aligned_err),
    .stat_rx_bad_code(cmac_stat_rx_bad_code),
    .stat_rx_bad_fcs(cmac_stat_rx_bad_fcs),
    .stat_rx_bad_preamble(cmac_stat_rx_bad_preamble),
    .stat_rx_bad_sfd(cmac_stat_rx_bad_sfd),
    .stat_rx_bip_err_0(cmac_stat_rx_bip_err[0]),
    .stat_rx_bip_err_1(cmac_stat_rx_bip_err[1]),
    .stat_rx_bip_err_2(cmac_stat_rx_bip_err[2]),
    .stat_rx_bip_err_3(cmac_stat_rx_bip_err[3]),
    .stat_rx_bip_err_4(cmac_stat_rx_bip_err[4]),
    .stat_rx_bip_err_5(cmac_stat_rx_bip_err[5]),
    .stat_rx_bip_err_6(cmac_stat_rx_bip_err[6]),
    .stat_rx_bip_err_7(cmac_stat_rx_bip_err[7]),
    .stat_rx_bip_err_8(cmac_stat_rx_bip_err[8]),
    .stat_rx_bip_err_9(cmac_stat_rx_bip_err[9]),
    .stat_rx_bip_err_10(cmac_stat_rx_bip_err[10]),
    .stat_rx_bip_err_11(cmac_stat_rx_bip_err[11]),
    .stat_rx_bip_err_12(cmac_stat_rx_bip_err[12]),
    .stat_rx_bip_err_13(cmac_stat_rx_bip_err[13]),
    .stat_rx_bip_err_14(cmac_stat_rx_bip_err[14]),
    .stat_rx_bip_err_15(cmac_stat_rx_bip_err[15]),
    .stat_rx_bip_err_16(cmac_stat_rx_bip_err[16]),
    .stat_rx_bip_err_17(cmac_stat_rx_bip_err[17]),
    .stat_rx_bip_err_18(cmac_stat_rx_bip_err[18]),
    .stat_rx_bip_err_19(cmac_stat_rx_bip_err[19]),
    .stat_rx_block_lock(cmac_stat_rx_block_lock),
    .stat_rx_broadcast(cmac_stat_rx_broadcast),
    .stat_rx_fragment(cmac_stat_rx_fragment),
    .stat_rx_framing_err_0(cmac_stat_rx_framing_err[2*0 +: 2]),
    .stat_rx_framing_err_1(cmac_stat_rx_framing_err[2*1 +: 2]),
    .stat_rx_framing_err_2(cmac_stat_rx_framing_err[2*2 +: 2]),
    .stat_rx_framing_err_3(cmac_stat_rx_framing_err[2*3 +: 2]),
    .stat_rx_framing_err_4(cmac_stat_rx_framing_err[2*4 +: 2]),
    .stat_rx_framing_err_5(cmac_stat_rx_framing_err[2*5 +: 2]),
    .stat_rx_framing_err_6(cmac_stat_rx_framing_err[2*6 +: 2]),
    .stat_rx_framing_err_7(cmac_stat_rx_framing_err[2*7 +: 2]),
    .stat_rx_framing_err_8(cmac_stat_rx_framing_err[2*8 +: 2]),
    .stat_rx_framing_err_9(cmac_stat_rx_framing_err[2*9 +: 2]),
    .stat_rx_framing_err_10(cmac_stat_rx_framing_err[2*10 +: 2]),
    .stat_rx_framing_err_11(cmac_stat_rx_framing_err[2*11 +: 2]),
    .stat_rx_framing_err_12(cmac_stat_rx_framing_err[2*12 +: 2]),
    .stat_rx_framing_err_13(cmac_stat_rx_framing_err[2*13 +: 2]),
    .stat_rx_framing_err_14(cmac_stat_rx_framing_err[2*14 +: 2]),
    .stat_rx_framing_err_15(cmac_stat_rx_framing_err[2*15 +: 2]),
    .stat_rx_framing_err_16(cmac_stat_rx_framing_err[2*16 +: 2]),
    .stat_rx_framing_err_17(cmac_stat_rx_framing_err[2*17 +: 2]),
    .stat_rx_framing_err_18(cmac_stat_rx_framing_err[2*18 +: 2]),
    .stat_rx_framing_err_19(cmac_stat_rx_framing_err[2*19 +: 2]),
    .stat_rx_framing_err_valid_0(cmac_stat_rx_framing_err_valid[0]),
    .stat_rx_framing_err_valid_1(cmac_stat_rx_framing_err_valid[1]),
    .stat_rx_framing_err_valid_2(cmac_stat_rx_framing_err_valid[2]),
    .stat_rx_framing_err_valid_3(cmac_stat_rx_framing_err_valid[3]),
    .stat_rx_framing_err_valid_4(cmac_stat_rx_framing_err_valid[4]),
    .stat_rx_framing_err_valid_5(cmac_stat_rx_framing_err_valid[5]),
    .stat_rx_framing_err_valid_6(cmac_stat_rx_framing_err_valid[6]),
    .stat_rx_framing_err_valid_7(cmac_stat_rx_framing_err_valid[7]),
    .stat_rx_framing_err_valid_8(cmac_stat_rx_framing_err_valid[8]),
    .stat_rx_framing_err_valid_9(cmac_stat_rx_framing_err_valid[9]),
    .stat_rx_framing_err_valid_10(cmac_stat_rx_framing_err_valid[10]),
    .stat_rx_framing_err_valid_11(cmac_stat_rx_framing_err_valid[11]),
    .stat_rx_framing_err_valid_12(cmac_stat_rx_framing_err_valid[12]),
    .stat_rx_framing_err_valid_13(cmac_stat_rx_framing_err_valid[13]),
    .stat_rx_framing_err_valid_14(cmac_stat_rx_framing_err_valid[14]),
    .stat_rx_framing_err_valid_15(cmac_stat_rx_framing_err_valid[15]),
    .stat_rx_framing_err_valid_16(cmac_stat_rx_framing_err_valid[16]),
    .stat_rx_framing_err_valid_17(cmac_stat_rx_framing_err_valid[17]),
    .stat_rx_framing_err_valid_18(cmac_stat_rx_framing_err_valid[18]),
    .stat_rx_framing_err_valid_19(cmac_stat_rx_framing_err_valid[19]),
    .stat_rx_got_signal_os(cmac_stat_rx_got_signal_os),
    .stat_rx_hi_ber(cmac_stat_rx_hi_ber),
    .stat_rx_inrangeerr(cmac_stat_rx_inrangeerr),
    .stat_rx_internal_local_fault(cmac_stat_rx_internal_local_fault),
    .stat_rx_jabber(cmac_stat_rx_jabber),
    .stat_rx_local_fault(cmac_stat_rx_local_fault),
    .stat_rx_mf_err(cmac_stat_rx_mf_err),
    .stat_rx_mf_len_err(cmac_stat_rx_mf_len_err),
    .stat_rx_mf_repeat_err(cmac_stat_rx_mf_repeat_err),
    .stat_rx_misaligned(cmac_stat_rx_misaligned),
    .stat_rx_multicast(cmac_stat_rx_multicast),
    .stat_rx_oversize(cmac_stat_rx_oversize),
    .stat_rx_packet_64_bytes(cmac_stat_rx_packet_64_bytes),
    .stat_rx_packet_65_127_bytes(cmac_stat_rx_packet_65_127_bytes),
    .stat_rx_packet_128_255_bytes(cmac_stat_rx_packet_128_255_bytes),
    .stat_rx_packet_256_511_bytes(cmac_stat_rx_packet_256_511_bytes),
    .stat_rx_packet_512_1023_bytes(cmac_stat_rx_packet_512_1023_bytes),
    .stat_rx_packet_1024_1518_bytes(cmac_stat_rx_packet_1024_1518_bytes),
    .stat_rx_packet_1519_1522_bytes(cmac_stat_rx_packet_1519_1522_bytes),
    .stat_rx_packet_1523_1548_bytes(cmac_stat_rx_packet_1523_1548_bytes),
    .stat_rx_packet_1549_2047_bytes(cmac_stat_rx_packet_1549_2047_bytes),
    .stat_rx_packet_2048_4095_bytes(cmac_stat_rx_packet_2048_4095_bytes),
    .stat_rx_packet_4096_8191_bytes(cmac_stat_rx_packet_4096_8191_bytes),
    .stat_rx_packet_8192_9215_bytes(cmac_stat_rx_packet_8192_9215_bytes),
    .stat_rx_packet_bad_fcs(cmac_stat_rx_packet_bad_fcs),
    .stat_rx_packet_large(cmac_stat_rx_packet_large),
    .stat_rx_packet_small(cmac_stat_rx_packet_small),

    .stat_rx_pause(),
    .stat_rx_pause_quanta0(),
    .stat_rx_pause_quanta1(),
    .stat_rx_pause_quanta2(),
    .stat_rx_pause_quanta3(),
    .stat_rx_pause_quanta4(),
    .stat_rx_pause_quanta5(),
    .stat_rx_pause_quanta6(),
    .stat_rx_pause_quanta7(),
    .stat_rx_pause_quanta8(),
    .stat_rx_pause_req({rx_lfc_req, rx_pfc_req}),
    .stat_rx_pause_valid(),
    .stat_rx_user_pause(),

    .ctl_rx_check_etype_gcp(1'b1),
    .ctl_rx_check_etype_gpp(1'b1),
    .ctl_rx_check_etype_pcp(1'b1),
    .ctl_rx_check_etype_ppp(1'b1),
    .ctl_rx_check_mcast_gcp(1'b1),
    .ctl_rx_check_mcast_gpp(1'b1),
    .ctl_rx_check_mcast_pcp(1'b1),
    .ctl_rx_check_mcast_ppp(1'b1),
    .ctl_rx_check_opcode_gcp(1'b1),
    .ctl_rx_check_opcode_gpp(1'b1),
    .ctl_rx_check_opcode_pcp(1'b1),
    .ctl_rx_check_opcode_ppp(1'b1),
    .ctl_rx_check_sa_gcp(1'b0),
    .ctl_rx_check_sa_gpp(1'b0),
    .ctl_rx_check_sa_pcp(1'b0),
    .ctl_rx_check_sa_ppp(1'b0),
    .ctl_rx_check_ucast_gcp(1'b0),
    .ctl_rx_check_ucast_gpp(1'b0),
    .ctl_rx_check_ucast_pcp(1'b0),
    .ctl_rx_check_ucast_ppp(1'b0),
    .ctl_rx_enable_gcp(rx_lfc_en),
    .ctl_rx_enable_gpp(rx_lfc_en),
    .ctl_rx_enable_pcp(rx_pfc_en != 0),
    .ctl_rx_enable_ppp(rx_pfc_en != 0),
    .ctl_rx_pause_ack({rx_lfc_ack, rx_pfc_ack}),
    .ctl_rx_pause_enable({rx_lfc_en, rx_pfc_en}),

    .ctl_rx_enable(cmac_ctl_rx_enable_reg && rx_enable),
    .ctl_rx_force_resync(cmac_ctl_rx_force_resync_reg),
    .ctl_rx_test_pattern(cmac_ctl_rx_test_pattern_reg),

    .rx_clk(rx_clk),

    .stat_rx_received_local_fault(cmac_stat_rx_received_local_fault),
    .stat_rx_remote_fault(cmac_stat_rx_remote_fault),
    .stat_rx_status(cmac_stat_rx_status),
    .stat_rx_stomped_fcs(cmac_stat_rx_stomped_fcs),
    .stat_rx_synced(cmac_stat_rx_synced),
    .stat_rx_synced_err(cmac_stat_rx_synced_err),
    .stat_rx_test_pattern_mismatch(cmac_stat_rx_test_pattern_mismatch),
    .stat_rx_toolong(cmac_stat_rx_toolong),
    .stat_rx_total_bytes(cmac_stat_rx_total_bytes),
    .stat_rx_total_good_bytes(cmac_stat_rx_total_good_bytes),
    .stat_rx_total_good_packets(cmac_stat_rx_total_good_packets),
    .stat_rx_total_packets(cmac_stat_rx_total_packets),
    .stat_rx_truncated(cmac_stat_rx_truncated),
    .stat_rx_undersize(cmac_stat_rx_undersize),
    .stat_rx_unicast(cmac_stat_rx_unicast),
    .stat_rx_vlan(cmac_stat_rx_vlan),
    .stat_rx_pcsl_demuxed(cmac_stat_rx_pcsl_demuxed),
    .stat_rx_pcsl_number_0(cmac_stat_rx_pcsl_number[5*0 +: 5]),
    .stat_rx_pcsl_number_1(cmac_stat_rx_pcsl_number[5*1 +: 5]),
    .stat_rx_pcsl_number_2(cmac_stat_rx_pcsl_number[5*2 +: 5]),
    .stat_rx_pcsl_number_3(cmac_stat_rx_pcsl_number[5*3 +: 5]),
    .stat_rx_pcsl_number_4(cmac_stat_rx_pcsl_number[5*4 +: 5]),
    .stat_rx_pcsl_number_5(cmac_stat_rx_pcsl_number[5*5 +: 5]),
    .stat_rx_pcsl_number_6(cmac_stat_rx_pcsl_number[5*6 +: 5]),
    .stat_rx_pcsl_number_7(cmac_stat_rx_pcsl_number[5*7 +: 5]),
    .stat_rx_pcsl_number_8(cmac_stat_rx_pcsl_number[5*8 +: 5]),
    .stat_rx_pcsl_number_9(cmac_stat_rx_pcsl_number[5*9 +: 5]),
    .stat_rx_pcsl_number_10(cmac_stat_rx_pcsl_number[5*10 +: 5]),
    .stat_rx_pcsl_number_11(cmac_stat_rx_pcsl_number[5*11 +: 5]),
    .stat_rx_pcsl_number_12(cmac_stat_rx_pcsl_number[5*12 +: 5]),
    .stat_rx_pcsl_number_13(cmac_stat_rx_pcsl_number[5*13 +: 5]),
    .stat_rx_pcsl_number_14(cmac_stat_rx_pcsl_number[5*14 +: 5]),
    .stat_rx_pcsl_number_15(cmac_stat_rx_pcsl_number[5*15 +: 5]),
    .stat_rx_pcsl_number_16(cmac_stat_rx_pcsl_number[5*16 +: 5]),
    .stat_rx_pcsl_number_17(cmac_stat_rx_pcsl_number[5*17 +: 5]),
    .stat_rx_pcsl_number_18(cmac_stat_rx_pcsl_number[5*18 +: 5]),
    .stat_rx_pcsl_number_19(cmac_stat_rx_pcsl_number[5*19 +: 5]),

    .ctl_tx_systemtimerin(tx_ptp_time),
    .stat_tx_ptp_fifo_read_error(cmac_stat_tx_ptp_fifo_read_error),
    .stat_tx_ptp_fifo_write_error(cmac_stat_tx_ptp_fifo_write_error),
    .tx_ptp_tstamp_valid_out(tx_ptp_ts_valid),
    .tx_ptp_pcslane_out(),
    .tx_ptp_tstamp_tag_out(tx_ptp_ts_tag),
    .tx_ptp_tstamp_out(tx_ptp_ts),
    .tx_ptp_1588op_in(2'b10),
    .tx_ptp_tag_field_in(cmac_tx_axis_tuser[16:1]),

    .stat_tx_bad_fcs(cmac_stat_tx_bad_fcs),
    .stat_tx_broadcast(cmac_stat_tx_broadcast),
    .stat_tx_frame_error(cmac_stat_tx_frame_error),
    .stat_tx_local_fault(cmac_stat_tx_local_fault),
    .stat_tx_multicast(cmac_stat_tx_multicast),
    .stat_tx_packet_64_bytes(cmac_stat_tx_packet_64_bytes),
    .stat_tx_packet_65_127_bytes(cmac_stat_tx_packet_65_127_bytes),
    .stat_tx_packet_128_255_bytes(cmac_stat_tx_packet_128_255_bytes),
    .stat_tx_packet_256_511_bytes(cmac_stat_tx_packet_256_511_bytes),
    .stat_tx_packet_512_1023_bytes(cmac_stat_tx_packet_512_1023_bytes),
    .stat_tx_packet_1024_1518_bytes(cmac_stat_tx_packet_1024_1518_bytes),
    .stat_tx_packet_1519_1522_bytes(cmac_stat_tx_packet_1519_1522_bytes),
    .stat_tx_packet_1523_1548_bytes(cmac_stat_tx_packet_1523_1548_bytes),
    .stat_tx_packet_1549_2047_bytes(cmac_stat_tx_packet_1549_2047_bytes),
    .stat_tx_packet_2048_4095_bytes(cmac_stat_tx_packet_2048_4095_bytes),
    .stat_tx_packet_4096_8191_bytes(cmac_stat_tx_packet_4096_8191_bytes),
    .stat_tx_packet_8192_9215_bytes(cmac_stat_tx_packet_8192_9215_bytes),
    .stat_tx_packet_large(cmac_stat_tx_packet_large),
    .stat_tx_packet_small(cmac_stat_tx_packet_small),
    .stat_tx_total_bytes(cmac_stat_tx_total_bytes),
    .stat_tx_total_good_bytes(cmac_stat_tx_total_good_bytes),
    .stat_tx_total_good_packets(cmac_stat_tx_total_good_packets),
    .stat_tx_total_packets(cmac_stat_tx_total_packets),
    .stat_tx_unicast(cmac_stat_tx_unicast),
    .stat_tx_vlan(cmac_stat_tx_vlan),

    .ctl_tx_enable(cmac_ctl_tx_enable_reg && tx_enable),
    .ctl_tx_send_idle(cmac_ctl_tx_send_idle_reg),
    .ctl_tx_send_rfi(cmac_ctl_tx_send_rfi_reg),
    .ctl_tx_send_lfi(cmac_ctl_tx_send_lfi_reg),
    .ctl_tx_test_pattern(cmac_ctl_tx_test_pattern_reg),

    .tx_clk(tx_clk),

    .stat_tx_pause_valid(),
    .stat_tx_pause(),
    .stat_tx_user_pause(),

    .ctl_tx_pause_enable({tx_lfc_en, tx_pfc_en}),
    .ctl_tx_pause_quanta0(16'hffff),
    .ctl_tx_pause_quanta1(16'hffff),
    .ctl_tx_pause_quanta2(16'hffff),
    .ctl_tx_pause_quanta3(16'hffff),
    .ctl_tx_pause_quanta4(16'hffff),
    .ctl_tx_pause_quanta5(16'hffff),
    .ctl_tx_pause_quanta6(16'hffff),
    .ctl_tx_pause_quanta7(16'hffff),
    .ctl_tx_pause_quanta8(16'hffff),
    .ctl_tx_pause_refresh_timer0(16'h7fff),
    .ctl_tx_pause_refresh_timer1(16'h7fff),
    .ctl_tx_pause_refresh_timer2(16'h7fff),
    .ctl_tx_pause_refresh_timer3(16'h7fff),
    .ctl_tx_pause_refresh_timer4(16'h7fff),
    .ctl_tx_pause_refresh_timer5(16'h7fff),
    .ctl_tx_pause_refresh_timer6(16'h7fff),
    .ctl_tx_pause_refresh_timer7(16'h7fff),
    .ctl_tx_pause_refresh_timer8(16'h7fff),
    .ctl_tx_pause_req({tx_lfc_req, tx_pfc_req}),
    .ctl_tx_resend_pause(1'b0),

    .tx_axis_tready(cmac_tx_axis_tready),
    .tx_axis_tvalid(cmac_tx_axis_tvalid),
    .tx_axis_tdata(cmac_tx_axis_tdata),
    .tx_axis_tlast(cmac_tx_axis_tlast),
    .tx_axis_tkeep(cmac_tx_axis_tkeep),
    .tx_axis_tuser(cmac_tx_axis_tuser[0]),

    .tx_ovfout(),
    .tx_unfout(),
    .tx_preamblein(56'd0),

    .tx_reset_done(tx_rst),
    .rx_reset_done(rx_rst),

    .rx_serdes_reset_done({6'h3f, ~gt_rx_reset_done}),
    .rx_serdes_clk_in({6'd0, gt_rxusrclk2}),

    .drp_clk(drp_clk),
    .drp_addr(drp_addr_reg),
    .drp_di(drp_di_reg),
    .drp_en(drp_en_cmac_reg),
    .drp_we(drp_we_reg),
    .drp_do(drp_do_cmac),
    .drp_rdy(drp_rdy_cmac)
);

endmodule

`resetall
