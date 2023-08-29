// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Transceiver and PHY quad wrapper
 */
module eth_xcvr_phy_quad_wrapper #
(
    parameter GXT = 0,

    // PHY parameters
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = (DATA_WIDTH/8),
    parameter HDR_WIDTH = 2,
    parameter PRBS31_ENABLE = 0,
    parameter TX_SERDES_PIPELINE = 0,
    parameter RX_SERDES_PIPELINE = 0,
    parameter BITSLIP_HIGH_CYCLES = 32,
    parameter BITSLIP_LOW_CYCLES = 32,
    parameter COUNT_125US = 125000/6.4
)
(
    input  wire                   xcvr_ctrl_clk,
    input  wire                   xcvr_ctrl_rst,

    /*
     * Common
     */
    input  wire                   xcvr_ref_clk,

    /*
     * Serial data
     */
    output wire [3:0]             xcvr_tx_serial_data,
    input  wire [3:0]             xcvr_rx_serial_data,

    /*
     * PHY connections
     */
    output wire                   phy_1_tx_clk,
    output wire                   phy_1_tx_rst,
    input  wire [DATA_WIDTH-1:0]  phy_1_xgmii_txd,
    input  wire [CTRL_WIDTH-1:0]  phy_1_xgmii_txc,
    output wire                   phy_1_rx_clk,
    output wire                   phy_1_rx_rst,
    output wire [DATA_WIDTH-1:0]  phy_1_xgmii_rxd,
    output wire [CTRL_WIDTH-1:0]  phy_1_xgmii_rxc,
    output wire                   phy_1_tx_bad_block,
    output wire [6:0]             phy_1_rx_error_count,
    output wire                   phy_1_rx_bad_block,
    output wire                   phy_1_rx_sequence_error,
    output wire                   phy_1_rx_block_lock,
    output wire                   phy_1_rx_high_ber,
    output wire                   phy_1_rx_status,
    input  wire                   phy_1_cfg_tx_prbs31_enable,
    input  wire                   phy_1_cfg_rx_prbs31_enable,

    output wire                   phy_2_tx_clk,
    output wire                   phy_2_tx_rst,
    input  wire [DATA_WIDTH-1:0]  phy_2_xgmii_txd,
    input  wire [CTRL_WIDTH-1:0]  phy_2_xgmii_txc,
    output wire                   phy_2_rx_clk,
    output wire                   phy_2_rx_rst,
    output wire [DATA_WIDTH-1:0]  phy_2_xgmii_rxd,
    output wire [CTRL_WIDTH-1:0]  phy_2_xgmii_rxc,
    output wire                   phy_2_tx_bad_block,
    output wire [6:0]             phy_2_rx_error_count,
    output wire                   phy_2_rx_bad_block,
    output wire                   phy_2_rx_sequence_error,
    output wire                   phy_2_rx_block_lock,
    output wire                   phy_2_rx_high_ber,
    output wire                   phy_2_rx_status,
    input  wire                   phy_2_cfg_tx_prbs31_enable,
    input  wire                   phy_2_cfg_rx_prbs31_enable,

    output wire                   phy_3_tx_clk,
    output wire                   phy_3_tx_rst,
    input  wire [DATA_WIDTH-1:0]  phy_3_xgmii_txd,
    input  wire [CTRL_WIDTH-1:0]  phy_3_xgmii_txc,
    output wire                   phy_3_rx_clk,
    output wire                   phy_3_rx_rst,
    output wire [DATA_WIDTH-1:0]  phy_3_xgmii_rxd,
    output wire [CTRL_WIDTH-1:0]  phy_3_xgmii_rxc,
    output wire                   phy_3_tx_bad_block,
    output wire [6:0]             phy_3_rx_error_count,
    output wire                   phy_3_rx_bad_block,
    output wire                   phy_3_rx_sequence_error,
    output wire                   phy_3_rx_block_lock,
    output wire                   phy_3_rx_high_ber,
    output wire                   phy_3_rx_status,
    input  wire                   phy_3_cfg_tx_prbs31_enable,
    input  wire                   phy_3_cfg_rx_prbs31_enable,

    output wire                   phy_4_tx_clk,
    output wire                   phy_4_tx_rst,
    input  wire [DATA_WIDTH-1:0]  phy_4_xgmii_txd,
    input  wire [CTRL_WIDTH-1:0]  phy_4_xgmii_txc,
    output wire                   phy_4_rx_clk,
    output wire                   phy_4_rx_rst,
    output wire [DATA_WIDTH-1:0]  phy_4_xgmii_rxd,
    output wire [CTRL_WIDTH-1:0]  phy_4_xgmii_rxc,
    output wire                   phy_4_tx_bad_block,
    output wire [6:0]             phy_4_rx_error_count,
    output wire                   phy_4_rx_bad_block,
    output wire                   phy_4_rx_sequence_error,
    output wire                   phy_4_rx_block_lock,
    output wire                   phy_4_rx_high_ber,
    output wire                   phy_4_rx_status,
    input  wire                   phy_4_cfg_tx_prbs31_enable,
    input  wire                   phy_4_cfg_rx_prbs31_enable
);

wire xcvr_gx_pll_locked;
wire xcvr_gx_pll_cal_busy;
wire xcvr_gxt_pll_locked;
wire xcvr_gxt_pll_cal_busy;

wire xcvr_tx_serial_gx_clk;
wire [1:0] xcvr_tx_serial_gxt_clk;

eth_xcvr_gx_pll eth_xcvr_gx_pll_inst (
    .pll_refclk0   (xcvr_ref_clk),
    .tx_serial_clk (xcvr_tx_serial_gx_clk),
    .pll_locked    (xcvr_gx_pll_locked),
    .pll_cal_busy  (xcvr_gx_pll_cal_busy)
);

generate

if (GXT) begin

    wire atx_pll_cascade_clk;

    eth_xcvr_gxt_pll eth_xcvr_gxt_pll_inst (
        .pll_refclk0           (xcvr_ref_clk),
        .tx_serial_clk_gxt     (xcvr_tx_serial_gxt_clk[0]),
        .gxt_output_to_abv_atx (atx_pll_cascade_clk),
        .pll_locked            (xcvr_gxt_pll_locked),
        .pll_cal_busy          (xcvr_gxt_pll_cal_busy)
    );

    eth_xcvr_gxt_buf eth_xcvr_gxt_buf_inst (
        .pll_refclk0            (xcvr_ref_clk),
        .tx_serial_clk_gxt      (xcvr_tx_serial_gxt_clk[1]),
        .gxt_input_from_blw_atx (atx_pll_cascade_clk),
        .pll_locked             (),
        .pll_cal_busy           ()
    );

end else begin

    assign xcvr_tx_serial_gxt_clk = 2'b00;
    assign xcvr_gxt_pll_locked = 1'b1;
    assign xcvr_gxt_pll_cal_busy = 1'b0;

end

endgenerate

eth_xcvr_phy_wrapper #(
    .GXT(GXT),
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
    .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_xcvr_phy_1 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Transceiver connections
    .xcvr_gx_pll_locked(xcvr_gx_pll_locked),
    .xcvr_gxt_pll_locked(xcvr_gxt_pll_locked),
    .xcvr_gx_pll_cal_busy(xcvr_gx_pll_cal_busy),
    .xcvr_gxt_pll_cal_busy(xcvr_gxt_pll_cal_busy),
    .xcvr_tx_serial_gx_clk(xcvr_tx_serial_gx_clk),
    .xcvr_tx_serial_gxt_clk(xcvr_tx_serial_gxt_clk[0]),
    .xcvr_rx_cdr_refclk(xcvr_ref_clk),
    .xcvr_tx_serial_data(xcvr_tx_serial_data[0]),
    .xcvr_rx_serial_data(xcvr_rx_serial_data[0]),

    // PHY connections
    .phy_tx_clk(phy_1_tx_clk),
    .phy_tx_rst(phy_1_tx_rst),
    .phy_xgmii_txd(phy_1_xgmii_txd),
    .phy_xgmii_txc(phy_1_xgmii_txc),
    .phy_rx_clk(phy_1_rx_clk),
    .phy_rx_rst(phy_1_rx_rst),
    .phy_xgmii_rxd(phy_1_xgmii_rxd),
    .phy_xgmii_rxc(phy_1_xgmii_rxc),
    .phy_tx_bad_block(phy_1_tx_bad_block),
    .phy_rx_error_count(phy_1_rx_error_count),
    .phy_rx_bad_block(phy_1_rx_bad_block),
    .phy_rx_sequence_error(phy_1_rx_sequence_error),
    .phy_rx_block_lock(phy_1_rx_block_lock),
    .phy_rx_high_ber(phy_1_rx_high_ber),
    .phy_rx_status(phy_1_rx_status),
    .phy_cfg_tx_prbs31_enable(phy_1_cfg_tx_prbs31_enable),
    .phy_cfg_rx_prbs31_enable(phy_1_cfg_rx_prbs31_enable)
);

eth_xcvr_phy_wrapper #(
    .GXT(GXT),
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
    .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_xcvr_phy_2 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Transceiver connections
    .xcvr_gx_pll_locked(xcvr_gx_pll_locked),
    .xcvr_gxt_pll_locked(xcvr_gxt_pll_locked),
    .xcvr_gx_pll_cal_busy(xcvr_gx_pll_cal_busy),
    .xcvr_gxt_pll_cal_busy(xcvr_gxt_pll_cal_busy),
    .xcvr_tx_serial_gx_clk(xcvr_tx_serial_gx_clk),
    .xcvr_tx_serial_gxt_clk(xcvr_tx_serial_gxt_clk[0]),
    .xcvr_rx_cdr_refclk(xcvr_ref_clk),
    .xcvr_tx_serial_data(xcvr_tx_serial_data[1]),
    .xcvr_rx_serial_data(xcvr_rx_serial_data[1]),

    // PHY connections
    .phy_tx_clk(phy_2_tx_clk),
    .phy_tx_rst(phy_2_tx_rst),
    .phy_xgmii_txd(phy_2_xgmii_txd),
    .phy_xgmii_txc(phy_2_xgmii_txc),
    .phy_rx_clk(phy_2_rx_clk),
    .phy_rx_rst(phy_2_rx_rst),
    .phy_xgmii_rxd(phy_2_xgmii_rxd),
    .phy_xgmii_rxc(phy_2_xgmii_rxc),
    .phy_tx_bad_block(phy_2_tx_bad_block),
    .phy_rx_error_count(phy_2_rx_error_count),
    .phy_rx_bad_block(phy_2_rx_bad_block),
    .phy_rx_sequence_error(phy_2_rx_sequence_error),
    .phy_rx_block_lock(phy_2_rx_block_lock),
    .phy_rx_high_ber(phy_2_rx_high_ber),
    .phy_rx_status(phy_2_rx_status),
    .phy_cfg_tx_prbs31_enable(phy_2_cfg_tx_prbs31_enable),
    .phy_cfg_rx_prbs31_enable(phy_2_cfg_rx_prbs31_enable)
);

eth_xcvr_phy_wrapper #(
    .GXT(GXT),
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
    .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_xcvr_phy_3 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Transceiver connections
    .xcvr_gx_pll_locked(xcvr_gx_pll_locked),
    .xcvr_gxt_pll_locked(xcvr_gxt_pll_locked),
    .xcvr_gx_pll_cal_busy(xcvr_gx_pll_cal_busy),
    .xcvr_gxt_pll_cal_busy(xcvr_gxt_pll_cal_busy),
    .xcvr_tx_serial_gx_clk(xcvr_tx_serial_gx_clk),
    .xcvr_tx_serial_gxt_clk(xcvr_tx_serial_gxt_clk[1]),
    .xcvr_rx_cdr_refclk(xcvr_ref_clk),
    .xcvr_tx_serial_data(xcvr_tx_serial_data[2]),
    .xcvr_rx_serial_data(xcvr_rx_serial_data[2]),

    // PHY connections
    .phy_tx_clk(phy_3_tx_clk),
    .phy_tx_rst(phy_3_tx_rst),
    .phy_xgmii_txd(phy_3_xgmii_txd),
    .phy_xgmii_txc(phy_3_xgmii_txc),
    .phy_rx_clk(phy_3_rx_clk),
    .phy_rx_rst(phy_3_rx_rst),
    .phy_xgmii_rxd(phy_3_xgmii_rxd),
    .phy_xgmii_rxc(phy_3_xgmii_rxc),
    .phy_tx_bad_block(phy_3_tx_bad_block),
    .phy_rx_error_count(phy_3_rx_error_count),
    .phy_rx_bad_block(phy_3_rx_bad_block),
    .phy_rx_sequence_error(phy_3_rx_sequence_error),
    .phy_rx_block_lock(phy_3_rx_block_lock),
    .phy_rx_high_ber(phy_3_rx_high_ber),
    .phy_rx_status(phy_3_rx_status),
    .phy_cfg_tx_prbs31_enable(phy_3_cfg_tx_prbs31_enable),
    .phy_cfg_rx_prbs31_enable(phy_3_cfg_rx_prbs31_enable)
);

eth_xcvr_phy_wrapper #(
    .GXT(GXT),
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
    .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_xcvr_phy_4 (
    .xcvr_ctrl_clk(xcvr_ctrl_clk),
    .xcvr_ctrl_rst(xcvr_ctrl_rst),

    // Transceiver connections
    .xcvr_gx_pll_locked(xcvr_gx_pll_locked),
    .xcvr_gxt_pll_locked(xcvr_gxt_pll_locked),
    .xcvr_gx_pll_cal_busy(xcvr_gx_pll_cal_busy),
    .xcvr_gxt_pll_cal_busy(xcvr_gxt_pll_cal_busy),
    .xcvr_tx_serial_gx_clk(xcvr_tx_serial_gx_clk),
    .xcvr_tx_serial_gxt_clk(xcvr_tx_serial_gxt_clk[1]),
    .xcvr_rx_cdr_refclk(xcvr_ref_clk),
    .xcvr_tx_serial_data(xcvr_tx_serial_data[3]),
    .xcvr_rx_serial_data(xcvr_rx_serial_data[3]),

    // PHY connections
    .phy_tx_clk(phy_4_tx_clk),
    .phy_tx_rst(phy_4_tx_rst),
    .phy_xgmii_txd(phy_4_xgmii_txd),
    .phy_xgmii_txc(phy_4_xgmii_txc),
    .phy_rx_clk(phy_4_rx_clk),
    .phy_rx_rst(phy_4_rx_rst),
    .phy_xgmii_rxd(phy_4_xgmii_rxd),
    .phy_xgmii_rxc(phy_4_xgmii_rxc),
    .phy_tx_bad_block(phy_4_tx_bad_block),
    .phy_rx_error_count(phy_4_rx_error_count),
    .phy_rx_bad_block(phy_4_rx_bad_block),
    .phy_rx_sequence_error(phy_4_rx_sequence_error),
    .phy_rx_block_lock(phy_4_rx_block_lock),
    .phy_rx_high_ber(phy_4_rx_high_ber),
    .phy_rx_status(phy_4_rx_status),
    .phy_cfg_tx_prbs31_enable(phy_4_cfg_tx_prbs31_enable),
    .phy_cfg_rx_prbs31_enable(phy_4_cfg_rx_prbs31_enable)
);

endmodule

`resetall
