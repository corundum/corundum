// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * GTY transceiver and PHY quad wrapper
 */
module eth_xcvr_phy_10g_gty_quad_wrapper #
(
    parameter COUNT = 4,

    // GT type
    parameter GT_GTH = 0,
    parameter GT_USP = 1,

    // PLL parameters
    parameter QPLL0_PD = 1'b0,
    parameter QPLL1_PD = 1'b1,
    parameter QPLL0_EXT_CTRL = 0,
    parameter QPLL1_EXT_CTRL = 0,

    // GT parameters
    parameter GT_1_TX_PD = 1'b0,
    parameter GT_1_TX_QPLL_SEL = 1'b0,
    parameter GT_1_TX_POLARITY = 1'b0,
    parameter GT_1_TX_ELECIDLE = 1'b0,
    parameter GT_1_TX_INHIBIT = 1'b0,
    parameter GT_1_TX_DIFFCTRL = 5'd16,
    parameter GT_1_TX_MAINCURSOR = 7'd64,
    parameter GT_1_TX_POSTCURSOR = 5'd0,
    parameter GT_1_TX_PRECURSOR = 5'd0,
    parameter GT_1_RX_PD = 1'b0,
    parameter GT_1_RX_QPLL_SEL = 1'b0,
    parameter GT_1_RX_LPM_EN = 1'b0,
    parameter GT_1_RX_POLARITY = 1'b0,
    parameter GT_2_TX_PD = 1'b0,
    parameter GT_2_TX_QPLL_SEL = 1'b0,
    parameter GT_2_TX_POLARITY = 1'b0,
    parameter GT_2_TX_ELECIDLE = 1'b0,
    parameter GT_2_TX_INHIBIT = 1'b0,
    parameter GT_2_TX_DIFFCTRL = 5'd16,
    parameter GT_2_TX_MAINCURSOR = 7'd64,
    parameter GT_2_TX_POSTCURSOR = 5'd0,
    parameter GT_2_TX_PRECURSOR = 5'd0,
    parameter GT_2_RX_PD = 1'b0,
    parameter GT_2_RX_QPLL_SEL = 1'b0,
    parameter GT_2_RX_LPM_EN = 1'b0,
    parameter GT_2_RX_POLARITY = 1'b0,
    parameter GT_3_TX_PD = 1'b0,
    parameter GT_3_TX_QPLL_SEL = 1'b0,
    parameter GT_3_TX_POLARITY = 1'b0,
    parameter GT_3_TX_ELECIDLE = 1'b0,
    parameter GT_3_TX_INHIBIT = 1'b0,
    parameter GT_3_TX_DIFFCTRL = 5'd16,
    parameter GT_3_TX_MAINCURSOR = 7'd64,
    parameter GT_3_TX_POSTCURSOR = 5'd0,
    parameter GT_3_TX_PRECURSOR = 5'd0,
    parameter GT_3_RX_PD = 1'b0,
    parameter GT_3_RX_QPLL_SEL = 1'b0,
    parameter GT_3_RX_LPM_EN = 1'b0,
    parameter GT_3_RX_POLARITY = 1'b0,
    parameter GT_4_TX_PD = 1'b0,
    parameter GT_4_TX_QPLL_SEL = 1'b0,
    parameter GT_4_TX_POLARITY = 1'b0,
    parameter GT_4_TX_ELECIDLE = 1'b0,
    parameter GT_4_TX_INHIBIT = 1'b0,
    parameter GT_4_TX_DIFFCTRL = 5'd16,
    parameter GT_4_TX_MAINCURSOR = 7'd64,
    parameter GT_4_TX_POSTCURSOR = 5'd0,
    parameter GT_4_TX_PRECURSOR = 5'd0,
    parameter GT_4_RX_PD = 1'b0,
    parameter GT_4_RX_QPLL_SEL = 1'b0,
    parameter GT_4_RX_LPM_EN = 1'b0,
    parameter GT_4_RX_POLARITY = 1'b0,

    // PHY parameters
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = (DATA_WIDTH/8),
    parameter HDR_WIDTH = 2,
    parameter PRBS31_ENABLE = 0,
    parameter TX_SERDES_PIPELINE = 0,
    parameter RX_SERDES_PIPELINE = 0,
    parameter BITSLIP_HIGH_CYCLES = 1,
    parameter BITSLIP_LOW_CYCLES = 8,
    parameter COUNT_125US = 125000/6.4
)
(
    input  wire                   xcvr_ctrl_clk,
    input  wire                   xcvr_ctrl_rst,

    /*
     * Common
     */
    output wire                   xcvr_gtpowergood_out,
    input  wire                   xcvr_gtrefclk00_in,
    input  wire                   xcvr_qpll0pd_in,
    input  wire                   xcvr_qpll0reset_in,
    input  wire [2:0]             xcvr_qpll0pcierate_in,
    output wire                   xcvr_qpll0lock_out,
    output wire                   xcvr_qpll0clk_out,
    output wire                   xcvr_qpll0refclk_out,
    input  wire                   xcvr_gtrefclk01_in,
    input  wire                   xcvr_qpll1pd_in,
    input  wire                   xcvr_qpll1reset_in,
    input  wire [2:0]             xcvr_qpll1pcierate_in,
    output wire                   xcvr_qpll1lock_out,
    output wire                   xcvr_qpll1clk_out,
    output wire                   xcvr_qpll1refclk_out,

    /*
     * DRP
     */
    input  wire                   drp_clk,
    input  wire                   drp_rst,
    input  wire [23:0]            drp_addr,
    input  wire [15:0]            drp_di,
    input  wire                   drp_en,
    input  wire                   drp_we,
    output wire [15:0]            drp_do,
    output wire                   drp_rdy,

    /*
     * Serial data
     */
    output wire [COUNT-1:0]       xcvr_txp,
    output wire [COUNT-1:0]       xcvr_txn,
    input  wire [COUNT-1:0]       xcvr_rxp,
    input  wire [COUNT-1:0]       xcvr_rxn,

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

generate

reg [23:0] drp_addr_reg = 24'd0;
reg [15:0] drp_di_reg = 16'd0;
reg drp_en_reg_1 = 1'b0;
reg drp_en_reg_2 = 1'b0;
reg drp_en_reg_3 = 1'b0;
reg drp_en_reg_4 = 1'b0;
reg drp_we_reg = 1'b0;
reg [15:0] drp_do_reg = 16'd0;
reg drp_rdy_reg = 1'b0;

wire [15:0] drp_do_1;
wire drp_rdy_1;
wire [15:0] drp_do_2;
wire drp_rdy_2;
wire [15:0] drp_do_3;
wire drp_rdy_3;
wire [15:0] drp_do_4;
wire drp_rdy_4;

assign drp_do = drp_do_reg;
assign drp_rdy = drp_rdy_reg;

always @(posedge drp_clk) begin
    drp_en_reg_1 <= 1'b0;
    drp_en_reg_2 <= 1'b0;
    drp_en_reg_3 <= 1'b0;
    drp_en_reg_4 <= 1'b0;
    drp_we_reg <= 1'b0;
    drp_rdy_reg <= 1'b0;
    drp_do_reg <= 16'd0;

    if (drp_en) begin
        drp_addr_reg <= drp_addr;
        drp_di_reg <= drp_di;
        drp_we_reg <= drp_we;
        if (COUNT > 0 && (drp_addr[19:17] == 3'b000 || drp_addr[19:17] == 3'b100)) begin
            drp_en_reg_1 <= 1'b1;
        end else if (COUNT > 1 && drp_addr[19:17] == 3'b001) begin
            drp_en_reg_2 <= 1'b1;
        end else if (COUNT > 2 && drp_addr[19:17] == 3'b010) begin
            drp_en_reg_3 <= 1'b1;
        end else if (COUNT > 3 && drp_addr[19:17] == 3'b011) begin
            drp_en_reg_4 <= 1'b1;
        end else begin
            drp_rdy_reg <= 1'b1;
        end
    end

    if (drp_rdy_1) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_1;
    end else if (drp_rdy_2) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_2;
    end else if (drp_rdy_3) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_3;
    end else if (drp_rdy_4) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_4;
    end

    if (drp_rst) begin
        drp_en_reg_1 <= 1'b0;
        drp_en_reg_2 <= 1'b0;
        drp_en_reg_3 <= 1'b0;
        drp_en_reg_4 <= 1'b0;
        drp_we_reg <= 1'b0;
        drp_rdy_reg <= 1'b0;
    end
end

if (COUNT > 0) begin : phy1

    eth_xcvr_phy_10g_gty_wrapper #(
        .HAS_COMMON(1),
        .GT_GTH(GT_GTH),
        .GT_USP(GT_USP),
        // PLL
        .QPLL0_PD(QPLL0_PD),
        .QPLL1_PD(QPLL1_PD),
        .QPLL0_EXT_CTRL(QPLL0_EXT_CTRL),
        .QPLL1_EXT_CTRL(QPLL1_EXT_CTRL),
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
        .GT_RX_POLARITY(GT_1_RX_POLARITY),
        // PHY
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

        // Common
        .xcvr_gtpowergood_out(xcvr_gtpowergood_out),

        // DRP
        .drp_clk(drp_clk),
        .drp_rst(drp_rst),
        .drp_addr(drp_addr_reg),
        .drp_di(drp_di_reg),
        .drp_en(drp_en_reg_1),
        .drp_we(drp_we_reg),
        .drp_do(drp_do_1),
        .drp_rdy(drp_rdy_1),

        // PLL out
        .xcvr_gtrefclk00_in(xcvr_gtrefclk00_in),
        .xcvr_qpll0pd_in(xcvr_qpll0pd_in),
        .xcvr_qpll0reset_in(xcvr_qpll0reset_in),
        .xcvr_qpll0pcierate_in(xcvr_qpll0pcierate_in),
        .xcvr_qpll0lock_out(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_out(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_out(xcvr_qpll0refclk_out),
        .xcvr_gtrefclk01_in(xcvr_gtrefclk01_in),
        .xcvr_qpll1pd_in(xcvr_qpll1pd_in),
        .xcvr_qpll1reset_in(xcvr_qpll1reset_in),
        .xcvr_qpll1pcierate_in(xcvr_qpll1pcierate_in),
        .xcvr_qpll1lock_out(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_out(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_out(xcvr_qpll1refclk_out),

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

end else begin
   
    assign drp_do_1 = 16'd0;
    assign drp_rdy_1 = 1'b0;

end

if (COUNT > 1) begin : phy2

    eth_xcvr_phy_10g_gty_wrapper #(
        .HAS_COMMON(0),
        .GT_GTH(GT_GTH),
        .GT_USP(GT_USP),
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
        .GT_RX_POLARITY(GT_2_RX_POLARITY),
        // PHY
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

        // Common
        .xcvr_gtpowergood_out(),

        // DRP
        .drp_clk(drp_clk),
        .drp_rst(drp_rst),
        .drp_addr(drp_addr_reg),
        .drp_di(drp_di_reg),
        .drp_en(drp_en_reg_2),
        .drp_we(drp_we_reg),
        .drp_do(drp_do_2),
        .drp_rdy(drp_rdy_2),

        // PLL out
        .xcvr_gtrefclk00_in(1'b0),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'b000),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(1'b0),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'b000),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        // PLL in
        .xcvr_qpll0lock_in(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_out),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_out),

        // Serial data
        .xcvr_txp(xcvr_txp[1]),
        .xcvr_txn(xcvr_txn[1]),
        .xcvr_rxp(xcvr_rxp[1]),
        .xcvr_rxn(xcvr_rxn[1]),

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

end else begin
   
    assign drp_do_2 = 16'd0;
    assign drp_rdy_2 = 1'b0;

end

if (COUNT > 2) begin : phy3

    eth_xcvr_phy_10g_gty_wrapper #(
        .HAS_COMMON(0),
        .GT_GTH(GT_GTH),
        .GT_USP(GT_USP),
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
        .GT_RX_POLARITY(GT_3_RX_POLARITY),
        // PHY
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

        // Common
        .xcvr_gtpowergood_out(),

        // DRP
        .drp_clk(drp_clk),
        .drp_rst(drp_rst),
        .drp_addr(drp_addr_reg),
        .drp_di(drp_di_reg),
        .drp_en(drp_en_reg_3),
        .drp_we(drp_we_reg),
        .drp_do(drp_do_3),
        .drp_rdy(drp_rdy_3),

        // PLL out
        .xcvr_gtrefclk00_in(1'b0),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'b000),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(1'b0),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'b000),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        // PLL in
        .xcvr_qpll0lock_in(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_out),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_out),

        // Serial data
        .xcvr_txp(xcvr_txp[2]),
        .xcvr_txn(xcvr_txn[2]),
        .xcvr_rxp(xcvr_rxp[2]),
        .xcvr_rxn(xcvr_rxn[2]),

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

end else begin
   
    assign drp_do_3 = 16'd0;
    assign drp_rdy_3 = 1'b0;

end

if (COUNT > 3) begin : phy4

    eth_xcvr_phy_10g_gty_wrapper #(
        .HAS_COMMON(0),
        .GT_GTH(GT_GTH),
        .GT_USP(GT_USP),
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
        .GT_RX_POLARITY(GT_4_RX_POLARITY),
        // PHY
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

        // Common
        .xcvr_gtpowergood_out(),

        // DRP
        .drp_clk(drp_clk),
        .drp_rst(drp_rst),
        .drp_addr(drp_addr_reg),
        .drp_di(drp_di_reg),
        .drp_en(drp_en_reg_4),
        .drp_we(drp_we_reg),
        .drp_do(drp_do_4),
        .drp_rdy(drp_rdy_4),

        // PLL out
        .xcvr_gtrefclk00_in(1'b0),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'b000),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(1'b0),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'b000),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        // PLL in
        .xcvr_qpll0lock_in(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_out),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_out),

        // Serial data
        .xcvr_txp(xcvr_txp[3]),
        .xcvr_txn(xcvr_txn[3]),
        .xcvr_rxp(xcvr_rxp[3]),
        .xcvr_rxn(xcvr_rxn[3]),

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

end else begin
   
    assign drp_do_4 = 16'd0;
    assign drp_rdy_4 = 1'b0;

end

endgenerate

endmodule

`resetall
