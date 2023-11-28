// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * GTY transceiver and PHY wrapper
 */
module eth_xcvr_phy_10g_gty_wrapper #
(
    parameter INDEX = 0,
    parameter HAS_COMMON = (INDEX == 0),

    // GT type
    parameter GT_GTH = 0,
    parameter GT_USP = 1,

    // PLL parameters
    parameter QPLL0_PD = 1'b0,
    parameter QPLL1_PD = 1'b1,
    parameter QPLL0_EXT_CTRL = 0,
    parameter QPLL1_EXT_CTRL = 0,

    // GT parameters
    parameter GT_TX_PD = 1'b0,
    parameter GT_TX_QPLL_SEL = 1'b0,
    parameter GT_TX_POLARITY = 1'b0,
    parameter GT_TX_ELECIDLE = 1'b0,
    parameter GT_TX_INHIBIT = 1'b0,
    parameter GT_TX_DIFFCTRL = 5'd16,
    parameter GT_TX_MAINCURSOR = 7'd64,
    parameter GT_TX_POSTCURSOR = 5'd0,
    parameter GT_TX_PRECURSOR = 5'd0,
    parameter GT_RX_PD = 1'b0,
    parameter GT_RX_QPLL_SEL = 1'b0,
    parameter GT_RX_LPM_EN = 1'b0,
    parameter GT_RX_POLARITY = 1'b0,

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
     * PLL out
     */
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
     * PLL in
     */
    input  wire                   xcvr_qpll0lock_in,
    input  wire                   xcvr_qpll0clk_in,
    input  wire                   xcvr_qpll0refclk_in,
    input  wire                   xcvr_qpll1lock_in,
    input  wire                   xcvr_qpll1clk_in,
    input  wire                   xcvr_qpll1refclk_in,

    /*
     * Serial data
     */
    output wire                   xcvr_txp,
    output wire                   xcvr_txn,
    input  wire                   xcvr_rxp,
    input  wire                   xcvr_rxn,

    /*
     * PHY connections
     */
    output wire                   phy_tx_clk,
    output wire                   phy_tx_rst,
    input  wire [DATA_WIDTH-1:0]  phy_xgmii_txd,
    input  wire [CTRL_WIDTH-1:0]  phy_xgmii_txc,
    output wire                   phy_rx_clk,
    output wire                   phy_rx_rst,
    output wire [DATA_WIDTH-1:0]  phy_xgmii_rxd,
    output wire [CTRL_WIDTH-1:0]  phy_xgmii_rxc,
    output wire                   phy_tx_bad_block,
    output wire [6:0]             phy_rx_error_count,
    output wire                   phy_rx_bad_block,
    output wire                   phy_rx_sequence_error,
    output wire                   phy_rx_block_lock,
    output wire                   phy_rx_high_ber,
    output wire                   phy_rx_status,
    input  wire                   phy_cfg_tx_prbs31_enable,
    input  wire                   phy_cfg_rx_prbs31_enable
);

// DRP
reg [23:0] drp_addr_reg = 24'd0;
reg [15:0] drp_di_reg = 16'd0;
reg drp_en_reg_1 = 1'b0;
reg drp_en_reg_2 = 1'b0;
reg drp_we_reg = 1'b0;
reg [15:0] drp_do_reg = 16'd0;
reg drp_rdy_reg = 1'b0;

wire [15:0] drp_do_1;
wire drp_rdy_1;
wire [15:0] drp_do_2;
wire drp_rdy_2;

assign drp_do = drp_do_reg;
assign drp_rdy = drp_rdy_reg;

// PLL
wire qpll0_lock;
wire qpll0_clk;
wire qpll0_refclk;
wire qpll1_lock;
wire qpll1_clk;
wire qpll1_refclk;

wire tx_sel_pll_lock;
wire rx_sel_pll_lock;

// GT
wire gt_txusrclk2;
wire gt_userclk_tx_active;
wire gt_rxusrclk2;
wire gt_userclk_rx_active;

wire gt_tx_reset_done;
wire gt_tx_pma_reset_done;
wire gt_tx_prgdiv_reset_done;
wire gt_rx_reset_done;
wire gt_rx_pma_reset_done;
wire gt_rx_prgdiv_reset_done;

wire gt_rxcdrlock;
wire gt_rxprbserr;
wire gt_rxprbslocked;

wire [15:0] gt_dmonitorout;

wire [5:0] gt_txheader;
wire [63:0] gt_txdata;
wire gt_rxgearboxslip;
wire [5:0] gt_rxheader;
wire [1:0] gt_rxheadervalid;
wire [63:0] gt_rxdata;
wire [1:0] gt_rxdatavalid;

// PHY
wire phy_rx_reset_req;

// PHY interface
reg phy_rx_reset_req_sync_1_reg = 1'b0, phy_rx_reset_req_sync_2_reg = 1'b0, phy_rx_reset_req_sync_3_reg = 1'b0, phy_rx_reset_req_sync_4_reg = 1'b0;
reg phy_rx_reset_req_drp_reg = 1'b0;
reg phy_rx_reset_req_en_drp_reg = 1'b1;

reg phy_rx_block_lock_reg = 1'b0;
reg phy_rx_block_lock_sync_1_reg = 1'b0, phy_rx_block_lock_sync_2_reg = 1'b0;
reg phy_rx_high_ber_reg = 1'b0;
reg phy_rx_high_ber_sync_1_reg = 1'b0, phy_rx_high_ber_sync_2_reg = 1'b0;
reg phy_rx_status_reg = 1'b0;
reg phy_rx_status_sync_1_reg = 1'b0, phy_rx_status_sync_2_reg = 1'b0;

always @(posedge gt_rxusrclk2) begin
    phy_rx_reset_req_sync_1_reg <= phy_rx_reset_req_sync_1_reg ^ phy_rx_reset_req;
    phy_rx_block_lock_reg <= phy_rx_block_lock;
    phy_rx_high_ber_reg <= phy_rx_high_ber;
    phy_rx_status_reg <= phy_rx_status;
end

always @(posedge drp_clk) begin
    phy_rx_reset_req_sync_2_reg <= phy_rx_reset_req_sync_1_reg;
    phy_rx_reset_req_sync_3_reg <= phy_rx_reset_req_sync_2_reg;
    phy_rx_reset_req_sync_4_reg <= phy_rx_reset_req_sync_3_reg;
    phy_rx_block_lock_sync_1_reg <= phy_rx_block_lock_reg;
    phy_rx_block_lock_sync_2_reg <= phy_rx_block_lock_sync_1_reg;
    phy_rx_high_ber_sync_1_reg <= phy_rx_high_ber_reg;
    phy_rx_high_ber_sync_2_reg <= phy_rx_high_ber_sync_1_reg;
    phy_rx_status_sync_1_reg <= phy_rx_status_reg;
    phy_rx_status_sync_2_reg <= phy_rx_status_sync_1_reg;
end

wire common_reset_in_int;

sync_reset #(
    .N(4)
)
sync_reset_common_reset_inst (
    .clk(drp_clk),
    .rst(drp_rst || xcvr_ctrl_rst),
    .out(common_reset_in_int)
);

// QPLL0 reset and power down
reg qpll0_reset_drp_reg = 1'b0;
reg qpll0_reset_reg = 1'b1;
reg qpll0_pd_drp_reg = QPLL0_PD;
reg qpll0_pd_reg = QPLL0_PD;

reg [7:0] qpll0_reset_counter_reg = 0;

always @(posedge drp_clk) begin
    qpll0_pd_reg <= qpll0_pd_drp_reg;
    qpll0_reset_reg <= 1'b1;

    if (&qpll0_reset_counter_reg) begin
        qpll0_reset_reg <= 1'b0;
    end else begin
        qpll0_reset_counter_reg <= qpll0_reset_counter_reg + 1;
    end

    if (qpll0_reset_drp_reg || qpll0_pd_reg || qpll0_pd_drp_reg) begin
        qpll0_reset_counter_reg <= 0;
    end

    if (common_reset_in_int) begin
        qpll0_reset_counter_reg <= 0;
    end

    if (drp_rst) begin
        qpll0_reset_reg <= 1'b1;
        qpll0_pd_reg <= QPLL0_PD;
        qpll0_reset_counter_reg <= 0;
    end
end

reg qpll0_lock_sync_1_reg = 1'b0,  qpll0_lock_sync_2_reg = 1'b0;

always @(posedge drp_clk) begin
    qpll0_lock_sync_1_reg <= qpll0_lock;
    qpll0_lock_sync_2_reg <= qpll0_lock_sync_1_reg;
end

// QPLL1 reset and power down
reg qpll1_reset_drp_reg = 1'b0;
reg qpll1_reset_reg = 1'b1;
reg qpll1_pd_drp_reg = QPLL1_PD;
reg qpll1_pd_reg = QPLL1_PD;

reg [7:0] qpll1_reset_counter_reg = 0;

always @(posedge drp_clk) begin
    qpll1_pd_reg <= qpll1_pd_drp_reg;
    qpll1_reset_reg <= 1'b1;

    if (&qpll1_reset_counter_reg) begin
        qpll1_reset_reg <= 1'b0;
    end else begin
        qpll1_reset_counter_reg <= qpll1_reset_counter_reg + 1;
    end

    if (qpll1_reset_drp_reg || qpll1_pd_reg || qpll1_pd_drp_reg) begin
        qpll1_reset_counter_reg <= 0;
    end

    if (common_reset_in_int) begin
        qpll1_reset_counter_reg <= 0;
    end

    if (drp_rst) begin
        qpll1_reset_reg <= 1'b1;
        qpll1_pd_reg <= QPLL1_PD;
        qpll1_reset_counter_reg <= 0;
    end
end

reg qpll1_lock_sync_1_reg = 1'b0,  qpll1_lock_sync_2_reg = 1'b0;

always @(posedge drp_clk) begin
    qpll1_lock_sync_1_reg <= qpll1_lock;
    qpll1_lock_sync_2_reg <= qpll1_lock_sync_1_reg;
end

// TX reset, clock selection, and power down
reg gt_tx_reset_drp_reg = 1'b0;
reg gt_tx_reset_reg = 1'b1;
reg gt_tx_pma_reset_drp_reg = 1'b0;
reg gt_tx_pma_reset_reg = 1'b0;
reg gt_tx_pcs_reset_drp_reg = 1'b0;
reg gt_tx_pcs_reset_reg = 1'b0;

reg gt_tx_prgdiv_reset_reg = 1'b0;
reg gt_tx_userrdy_reg = 1'b0;

reg gt_tx_pd_drp_reg = GT_TX_PD;
reg gt_tx_pd_reg = GT_TX_PD;

reg gt_tx_qpll_sel_drp_reg = GT_TX_QPLL_SEL;
reg gt_tx_qpll_sel_reg = GT_TX_QPLL_SEL;

reg gt_tx_reset_done_reg = 1'b0;
reg gt_tx_reset_done_sync_1_reg = 1'b0, gt_tx_reset_done_sync_2_reg = 1'b0;
reg gt_tx_pma_reset_done_sync_1_reg = 1'b0, gt_tx_pma_reset_done_sync_2_reg = 1'b0;
reg gt_tx_prgdiv_reset_done_sync_1_reg = 1'b0, gt_tx_prgdiv_reset_done_sync_2_reg = 1'b0;
reg gt_userclk_tx_active_reg = 1'b0;
reg gt_userclk_tx_active_sync_1_reg = 1'b0, gt_userclk_tx_active_sync_2_reg = 1'b0;

always @(posedge gt_txusrclk2) begin
    gt_tx_reset_done_reg <= gt_tx_reset_done;
    gt_userclk_tx_active_reg <= gt_userclk_tx_active;
end

always @(posedge drp_clk) begin
    gt_tx_reset_done_sync_1_reg <= gt_tx_reset_done_reg;
    gt_tx_reset_done_sync_2_reg <= gt_tx_reset_done_sync_1_reg;
    gt_tx_pma_reset_done_sync_1_reg <= gt_tx_pma_reset_done;
    gt_tx_pma_reset_done_sync_2_reg <= gt_tx_pma_reset_done_sync_1_reg;
    gt_tx_prgdiv_reset_done_sync_1_reg <= gt_tx_prgdiv_reset_done;
    gt_tx_prgdiv_reset_done_sync_2_reg <= gt_tx_prgdiv_reset_done_sync_1_reg;
    gt_userclk_tx_active_sync_1_reg <= gt_userclk_tx_active_reg;
    gt_userclk_tx_active_sync_2_reg <= gt_userclk_tx_active_sync_1_reg;
end

localparam [1:0]
    TX_RESET_STATE_RESET = 2'd0,
    TX_RESET_STATE_WAIT_LOCK = 2'd1,
    TX_RESET_STATE_WAIT_USRCLK = 2'd2,
    TX_RESET_STATE_DONE = 2'd3;

reg [1:0] tx_reset_state_reg = TX_RESET_STATE_RESET;
reg [7:0] tx_reset_counter_reg = 0;
reg tx_reset_done_reg = 1'b0;

assign tx_sel_pll_lock = gt_tx_qpll_sel_drp_reg ? qpll1_lock_sync_2_reg : qpll0_lock_sync_2_reg;

always @(posedge drp_clk) begin
    gt_tx_reset_reg <= 1'b1;
    gt_tx_pma_reset_reg <= gt_tx_pma_reset_drp_reg;
    gt_tx_pcs_reset_reg <= gt_tx_pcs_reset_drp_reg;

    gt_tx_prgdiv_reset_reg <= 1'b1;
    gt_tx_userrdy_reg <= 1'b0;

    gt_tx_pd_reg <= gt_tx_pd_drp_reg;
    gt_tx_qpll_sel_reg <= gt_tx_qpll_sel_drp_reg;

    tx_reset_state_reg <= TX_RESET_STATE_RESET;
    tx_reset_counter_reg <= 0;
    tx_reset_done_reg <= 1'b0;

    case (tx_reset_state_reg)
        TX_RESET_STATE_RESET: begin
            gt_tx_reset_reg <= 1'b1;
            gt_tx_prgdiv_reset_reg <= 1'b1;
            gt_tx_userrdy_reg <= 1'b0;

            tx_reset_state_reg <= TX_RESET_STATE_WAIT_LOCK;
        end
        TX_RESET_STATE_WAIT_LOCK: begin
            gt_tx_reset_reg <= 1'b1;
            gt_tx_prgdiv_reset_reg <= 1'b1;
            gt_tx_userrdy_reg <= 1'b0;

            tx_reset_state_reg <= TX_RESET_STATE_WAIT_LOCK;
            if (tx_sel_pll_lock) begin
                // QPLL locked
                if (&tx_reset_counter_reg) begin
                    tx_reset_state_reg <= TX_RESET_STATE_WAIT_USRCLK;
                end else begin
                    tx_reset_counter_reg <= tx_reset_counter_reg + 1;
                end
            end
        end
        TX_RESET_STATE_WAIT_USRCLK: begin
            gt_tx_reset_reg <= 1'b0;
            gt_tx_prgdiv_reset_reg <= 1'b0;
            gt_tx_userrdy_reg <= 1'b0;

            tx_reset_state_reg <= TX_RESET_STATE_WAIT_USRCLK;
            if (gt_userclk_tx_active_sync_2_reg) begin
                // user clock running
                if (&tx_reset_counter_reg) begin
                    tx_reset_state_reg <= TX_RESET_STATE_DONE;
                end else begin
                    tx_reset_counter_reg <= tx_reset_counter_reg + 1;
                end
            end
        end
        TX_RESET_STATE_DONE: begin
            gt_tx_reset_reg <= 1'b0;
            gt_tx_prgdiv_reset_reg <= 1'b0;
            gt_tx_userrdy_reg <= 1'b1;

            tx_reset_done_reg <= gt_tx_reset_done_sync_2_reg && gt_tx_prgdiv_reset_done_sync_2_reg;

            tx_reset_state_reg <= TX_RESET_STATE_DONE;
        end
    endcase

    if (gt_tx_reset_drp_reg || gt_tx_pd_drp_reg || !tx_sel_pll_lock || (gt_tx_qpll_sel_reg != gt_tx_qpll_sel_drp_reg)) begin
        tx_reset_state_reg <= TX_RESET_STATE_RESET;
    end

    if (drp_rst) begin
        gt_tx_reset_reg <= 1'b1;
        gt_tx_pma_reset_reg <= 1'b0;
        gt_tx_pcs_reset_reg <= 1'b0;

        gt_tx_prgdiv_reset_reg <= 1'b1;
        gt_tx_userrdy_reg <= 1'b0;

        gt_tx_pd_reg <= GT_TX_PD;
        gt_tx_qpll_sel_reg <= GT_TX_QPLL_SEL;

        tx_reset_state_reg <= TX_RESET_STATE_RESET;
        tx_reset_done_reg <= 1'b0;
    end
end

// RX reset, clock selection, CDR, EQ, and power down
reg gt_rx_reset_drp_reg = 1'b0;
reg gt_rx_reset_reg = 1'b1;
reg gt_rx_pma_reset_drp_reg = 1'b0;
reg gt_rx_pma_reset_reg = 1'b0;
reg gt_rx_pcs_reset_drp_reg = 1'b0;
reg gt_rx_pcs_reset_reg = 1'b0;
reg gt_rx_dfe_lpm_reset_drp_reg = 1'b0;
reg gt_rx_dfe_lpm_reset_reg = 1'b0;
reg gt_eyescan_reset_drp_reg = 1'b0;
reg gt_eyescan_reset_reg = 1'b0;

reg gt_rx_prgdiv_reset_reg = 1'b0;
reg gt_rx_userrdy_reg = 1'b0;

reg gt_rx_pd_drp_reg = GT_RX_PD;
reg gt_rx_pd_reg = GT_RX_PD;

reg gt_rx_qpll_sel_drp_reg = GT_RX_QPLL_SEL;
reg gt_rx_qpll_sel_reg = GT_RX_QPLL_SEL;

reg gt_rxcdrhold_drp_reg = 1'b0;
reg gt_rxcdrhold_reg = 1'b0;
reg gt_rxlpmen_drp_reg = GT_RX_LPM_EN;
reg gt_rxlpmen_reg = GT_RX_LPM_EN;

reg gt_rx_reset_done_reg = 1'b0;
reg gt_rx_reset_done_sync_1_reg = 1'b0, gt_rx_reset_done_sync_2_reg = 1'b0;
reg gt_rx_pma_reset_done_sync_1_reg = 1'b0, gt_rx_pma_reset_done_sync_2_reg = 1'b0;
reg gt_rx_prgdiv_reset_done_sync_1_reg = 1'b0, gt_rx_prgdiv_reset_done_sync_2_reg = 1'b0;
reg gt_userclk_rx_active_reg = 1'b0;
reg gt_userclk_rx_active_sync_1_reg = 1'b0, gt_userclk_rx_active_sync_2_reg = 1'b0;
reg gt_rxcdrlock_sync_1_reg = 1'b0, gt_rxcdrlock_sync_2_reg = 1'b0;

always @(posedge gt_rxusrclk2) begin
    gt_rx_reset_done_reg <= gt_rx_reset_done;
    gt_userclk_rx_active_reg <= gt_userclk_rx_active;
end

always @(posedge drp_clk) begin
    gt_rx_reset_done_sync_1_reg <= gt_rx_reset_done_reg;
    gt_rx_reset_done_sync_2_reg <= gt_rx_reset_done_sync_1_reg;
    gt_rx_pma_reset_done_sync_1_reg <= gt_rx_pma_reset_done;
    gt_rx_pma_reset_done_sync_2_reg <= gt_rx_pma_reset_done_sync_1_reg;
    gt_rx_prgdiv_reset_done_sync_1_reg <= gt_rx_prgdiv_reset_done;
    gt_rx_prgdiv_reset_done_sync_2_reg <= gt_rx_prgdiv_reset_done_sync_1_reg;
    gt_userclk_rx_active_sync_1_reg <= gt_userclk_rx_active_reg;
    gt_userclk_rx_active_sync_2_reg <= gt_userclk_rx_active_sync_1_reg;
    gt_rxcdrlock_sync_1_reg <= gt_rxcdrlock;
    gt_rxcdrlock_sync_2_reg <= gt_rxcdrlock_sync_1_reg;
end

localparam [2:0]
    RX_RESET_STATE_RESET = 3'd0,
    RX_RESET_STATE_WAIT_LOCK = 3'd1,
    RX_RESET_STATE_WAIT_CDR = 3'd2,
    RX_RESET_STATE_WAIT_USRCLK = 3'd3,
    RX_RESET_STATE_DONE = 3'd4;

reg [2:0] rx_reset_state_reg = RX_RESET_STATE_RESET;
reg [7:0] rx_reset_counter_reg = 0;
reg [19:0] rx_reset_cdr_counter_reg = 0;
reg rx_reset_done_reg = 1'b0;

assign rx_sel_pll_lock = gt_rx_qpll_sel_drp_reg ? qpll1_lock_sync_2_reg : qpll0_lock_sync_2_reg;

always @(posedge drp_clk) begin
    gt_rx_reset_reg <= 1'b1;
    gt_rx_pma_reset_reg <= gt_rx_pma_reset_drp_reg;
    gt_rx_pcs_reset_reg <= gt_rx_pcs_reset_drp_reg;
    gt_rx_dfe_lpm_reset_reg <= gt_rx_dfe_lpm_reset_drp_reg;
    gt_eyescan_reset_reg <= gt_eyescan_reset_drp_reg;

    gt_rx_prgdiv_reset_reg <= 1'b1;
    gt_rx_userrdy_reg <= 1'b0;

    gt_rx_pd_reg <= gt_rx_pd_drp_reg;
    gt_rx_qpll_sel_reg <= gt_rx_qpll_sel_drp_reg;

    gt_rxcdrhold_reg <= gt_rxcdrhold_drp_reg;
    gt_rxlpmen_reg <= gt_rxlpmen_drp_reg;

    rx_reset_state_reg <= RX_RESET_STATE_RESET;
    rx_reset_counter_reg <= 0;
    rx_reset_cdr_counter_reg <= 0;
    rx_reset_done_reg <= 1'b0;

    case (rx_reset_state_reg)
        RX_RESET_STATE_RESET: begin
            gt_rx_reset_reg <= 1'b1;
            gt_rx_prgdiv_reset_reg <= 1'b1;
            gt_rx_userrdy_reg <= 1'b0;

            rx_reset_state_reg <= RX_RESET_STATE_WAIT_LOCK;
        end
        RX_RESET_STATE_WAIT_LOCK: begin
            gt_rx_reset_reg <= 1'b1;
            gt_rx_prgdiv_reset_reg <= 1'b1;
            gt_rx_userrdy_reg <= 1'b0;

            rx_reset_state_reg <= RX_RESET_STATE_WAIT_LOCK;
            if (rx_sel_pll_lock) begin
                // QPLL locked
                if (&rx_reset_counter_reg) begin
                    rx_reset_state_reg <= RX_RESET_STATE_WAIT_CDR;
                end else begin
                    rx_reset_counter_reg <= rx_reset_counter_reg + 1;
                end
            end
        end
        RX_RESET_STATE_WAIT_CDR: begin
            gt_rx_reset_reg <= 1'b0;
            gt_rx_prgdiv_reset_reg <= 1'b1;
            gt_rx_userrdy_reg <= 1'b0;

            rx_reset_state_reg <= RX_RESET_STATE_WAIT_CDR;

            if (&rx_reset_cdr_counter_reg) begin
                rx_reset_state_reg <= RX_RESET_STATE_WAIT_USRCLK;
            end else begin
                rx_reset_cdr_counter_reg <= rx_reset_cdr_counter_reg + 1;
            end

            if (gt_rxcdrlock_sync_2_reg) begin
                // CDR locked
                if (&rx_reset_counter_reg) begin
                    rx_reset_state_reg <= RX_RESET_STATE_WAIT_USRCLK;
                end else begin
                    rx_reset_counter_reg <= rx_reset_counter_reg + 1;
                end
            end
        end
        RX_RESET_STATE_WAIT_USRCLK: begin
            gt_rx_reset_reg <= 1'b0;
            gt_rx_prgdiv_reset_reg <= 1'b0;
            gt_rx_userrdy_reg <= 1'b0;

            rx_reset_state_reg <= RX_RESET_STATE_WAIT_USRCLK;
            if (gt_userclk_rx_active_sync_2_reg) begin
                // user clock running
                if (&rx_reset_counter_reg) begin
                    rx_reset_state_reg <= RX_RESET_STATE_DONE;
                end else begin
                    rx_reset_counter_reg <= rx_reset_counter_reg + 1;
                end
            end
        end
        RX_RESET_STATE_DONE: begin
            gt_rx_reset_reg <= 1'b0;
            gt_rx_prgdiv_reset_reg <= 1'b0;
            gt_rx_userrdy_reg <= 1'b1;

            rx_reset_done_reg <= gt_rx_reset_done_sync_2_reg && gt_rx_prgdiv_reset_done_sync_2_reg;

            rx_reset_state_reg <= RX_RESET_STATE_DONE;
        end
    endcase

    if (gt_rx_reset_drp_reg || gt_rx_pd_drp_reg || !rx_sel_pll_lock || (gt_rx_qpll_sel_reg != gt_rx_qpll_sel_drp_reg) || (gt_rxlpmen_reg != gt_rxlpmen_drp_reg)) begin
        rx_reset_state_reg <= RX_RESET_STATE_RESET;
    end

    if (phy_rx_reset_req_en_drp_reg && (phy_rx_reset_req_sync_3_reg ^ phy_rx_reset_req_sync_4_reg) && rx_reset_done_reg) begin
        rx_reset_state_reg <= RX_RESET_STATE_RESET;
    end

    if (drp_rst) begin
        gt_rx_reset_reg <= 1'b1;
        gt_rx_pma_reset_reg <= 1'b0;
        gt_rx_pcs_reset_reg <= 1'b0;
        gt_rx_dfe_lpm_reset_reg <= 1'b0;
        gt_eyescan_reset_reg <= 1'b0;

        gt_rx_prgdiv_reset_reg <= 1'b1;
        gt_rx_userrdy_reg <= 1'b0;

        gt_rx_pd_reg <= GT_RX_PD;
        gt_rx_qpll_sel_reg <= GT_RX_QPLL_SEL;

        rx_reset_state_reg <= RX_RESET_STATE_RESET;
        rx_reset_done_reg <= 1'b0;
    end
end

// Loopback
reg [2:0] gt_loopback_drp_reg = 3'b000;
reg [2:0] gt_loopback_reg = 3'b000;

always @(posedge drp_clk) begin
    gt_loopback_reg <= gt_loopback_drp_reg;
end

// Digital monitor
reg [7:0] gt_dmonitorout_drp_reg = 8'd0;
reg [7:0] gt_dmonitorout_sync_1_reg = 8'd0, gt_dmonitorout_sync_2_reg = 8'd0, gt_dmonitorout_sync_3_reg = 8'd0;

always @(posedge drp_clk) begin
    gt_dmonitorout_sync_1_reg <= gt_dmonitorout;
    gt_dmonitorout_sync_2_reg <= gt_dmonitorout_sync_1_reg;
    gt_dmonitorout_sync_3_reg <= gt_dmonitorout_sync_2_reg;

    if (gt_dmonitorout_sync_3_reg == gt_dmonitorout_sync_2_reg) begin
        gt_dmonitorout_drp_reg <= gt_dmonitorout_sync_3_reg;
    end
end

// TX PRBS and driver control
reg [3:0] gt_txprbssel_drp_reg = 4'd0;
reg [3:0] gt_txprbssel_sync_reg = 4'd0;
reg gt_txprbsforceerr_drp_reg = 1'b0;
reg gt_txprbsforceerr_sync_1_reg = 1'b0, gt_txprbsforceerr_sync_2_reg = 1'b0, gt_txprbsforceerr_sync_3_reg = 1'b0;
reg gt_txpolarity_drp_reg = GT_TX_POLARITY;
reg gt_txpolarity_sync_reg = GT_TX_POLARITY;
reg gt_txelecidle_drp_reg = GT_TX_ELECIDLE;
reg gt_txelecidle_reg = GT_TX_ELECIDLE;
reg gt_txinhibit_drp_reg = GT_TX_INHIBIT;
reg gt_txinhibit_sync_reg = GT_TX_INHIBIT;
reg [4:0] gt_txdiffctrl_drp_reg = GT_TX_DIFFCTRL;
reg [4:0] gt_txdiffctrl_reg = GT_TX_DIFFCTRL;
reg [6:0] gt_txmaincursor_drp_reg = GT_TX_MAINCURSOR;
reg [6:0] gt_txmaincursor_reg = GT_TX_MAINCURSOR;
reg [4:0] gt_txpostcursor_drp_reg = GT_TX_POSTCURSOR;
reg [4:0] gt_txpostcursor_reg = GT_TX_POSTCURSOR;
reg [4:0] gt_txprecursor_drp_reg = GT_TX_PRECURSOR;
reg [4:0] gt_txprecursor_reg = GT_TX_PRECURSOR;

always @(posedge gt_txusrclk2) begin
    gt_txprbssel_sync_reg <= gt_txprbssel_drp_reg;
    gt_txprbsforceerr_sync_1_reg <= gt_txprbsforceerr_drp_reg;
    gt_txprbsforceerr_sync_2_reg <= gt_txprbsforceerr_sync_1_reg;
    gt_txprbsforceerr_sync_3_reg <= gt_txprbsforceerr_sync_2_reg;
    gt_txpolarity_sync_reg <= gt_txpolarity_drp_reg;
    gt_txinhibit_sync_reg <= gt_txinhibit_drp_reg;
end

always @(posedge drp_clk) begin
    gt_txelecidle_reg <= gt_tx_pd_drp_reg ? 1'b1 : gt_txelecidle_drp_reg;
    gt_txdiffctrl_reg <= gt_txdiffctrl_drp_reg;
    gt_txmaincursor_reg <= gt_txmaincursor_drp_reg;
    gt_txpostcursor_reg <= gt_txpostcursor_drp_reg;
    gt_txprecursor_reg <= gt_txprecursor_drp_reg;
end

// RX PRBS and buffer control
reg gt_rxpolarity_drp_reg = GT_RX_POLARITY;
reg gt_rxpolarity_sync_reg = GT_RX_POLARITY;
reg gt_rxprbscntreset_drp_reg = 1'b0;
reg gt_rxprbscntreset_sync_1_reg = 1'b0, gt_rxprbscntreset_sync_2_reg = 1'b0, gt_rxprbscntreset_sync_3_reg = 1'b0;
reg [3:0] gt_rxprbssel_drp_reg = 4'd0;
reg [3:0] gt_rxprbssel_sync_reg = 4'd0;
reg gt_rxprbserr_drp_reg = 1'b0;
reg gt_rxprbserr_sync_1_reg = 1'b0, gt_rxprbserr_sync_2_reg = 1'b0, gt_rxprbserr_sync_3_reg = 1'b0;
reg gt_rxprbserr_sync_4_reg = 1'b0, gt_rxprbserr_sync_5_reg = 1'b0;
reg gt_rxprbslocked_reg = 1'b0;
reg gt_rxprbslocked_sync_1_reg = 1'b0, gt_rxprbslocked_sync_2_reg = 1'b0;

always @(posedge gt_rxusrclk2) begin
    gt_rxpolarity_sync_reg <= gt_rxpolarity_drp_reg;
    gt_rxprbscntreset_sync_1_reg <= gt_rxprbscntreset_drp_reg;
    gt_rxprbscntreset_sync_2_reg <= gt_rxprbscntreset_sync_1_reg;
    gt_rxprbscntreset_sync_3_reg <= gt_rxprbscntreset_sync_2_reg;
    gt_rxprbssel_sync_reg <= gt_rxprbssel_drp_reg;
    gt_rxprbserr_sync_1_reg <= (gt_rxprbserr_sync_1_reg && !gt_rxprbserr_sync_5_reg) || gt_rxprbserr;
    gt_rxprbserr_sync_4_reg <= gt_rxprbserr_sync_3_reg;
    gt_rxprbserr_sync_5_reg <= gt_rxprbserr_sync_4_reg;
    gt_rxprbslocked_reg <= gt_rxprbslocked;
end

always @(posedge drp_clk) begin
    gt_rxprbserr_sync_2_reg <= gt_rxprbserr_sync_1_reg;
    gt_rxprbserr_sync_3_reg <= gt_rxprbserr_sync_2_reg;
    gt_rxprbslocked_sync_1_reg <= gt_rxprbslocked_reg;
    gt_rxprbslocked_sync_2_reg <= gt_rxprbslocked_sync_1_reg;
end

// DRP interface
always @(posedge drp_clk) begin
    drp_en_reg_1 <= 1'b0;
    drp_en_reg_2 <= 1'b0;
    drp_we_reg <= 1'b0;
    drp_rdy_reg <= 1'b0;
    drp_do_reg <= 16'd0;

    gt_rxprbserr_drp_reg <= gt_rxprbserr_drp_reg || gt_rxprbserr_sync_3_reg;

    phy_rx_reset_req_drp_reg <= phy_rx_reset_req_drp_reg || (phy_rx_reset_req_sync_3_reg ^ phy_rx_reset_req_sync_4_reg);

    if (drp_en) begin
        drp_addr_reg <= drp_addr;
        drp_di_reg <= drp_di;
        drp_we_reg <= drp_we;
        if (HAS_COMMON && drp_addr[19] == 1'b1) begin
            // common
            if (drp_addr[16]) begin
                // control registers
                drp_rdy_reg <= 1'b1;
                if (drp_we) begin
                    case (drp_addr[15:0])
                        // QPLL0
                        16'h0000: begin
                            qpll0_reset_drp_reg <= drp_di[0];
                        end
                        16'h0001: begin
                            qpll0_pd_drp_reg <= drp_di[0];
                        end
                        // QPLL1
                        16'h1000: begin
                            qpll1_reset_drp_reg <= drp_di[0];
                        end
                        16'h1001: begin
                            qpll1_pd_drp_reg <= drp_di[0];
                        end
                    endcase
                end
                case (drp_addr[15:0])
                    // QPLL0
                    16'h0000: begin
                        drp_do_reg[0] <= qpll0_reset_drp_reg;
                        drp_do_reg[8] <= qpll0_lock_sync_2_reg;
                    end
                    16'h0001: begin
                        drp_do_reg[0] <= qpll0_pd_drp_reg;
                    end
                    // QPLL1
                    16'h1000: begin
                        drp_do_reg[0] <= qpll1_reset_drp_reg;
                        drp_do_reg[8] <= qpll1_lock_sync_2_reg;
                    end
                    16'h1001: begin
                        drp_do_reg[0] <= qpll1_pd_drp_reg;
                    end
                endcase
            end else begin
                // common DRP interface
                drp_en_reg_2 <= 1'b1;
            end
        end else begin
            // channel
            if (drp_addr[16]) begin
                // control registers
                drp_rdy_reg <= 1'b1;
                if (drp_we) begin
                    case (drp_addr[15:0])
                        // TX
                        16'h0000: begin
                            gt_tx_reset_drp_reg <= drp_di[0];
                            gt_tx_pma_reset_drp_reg <= drp_di[1];
                            gt_tx_pcs_reset_drp_reg <= drp_di[2];
                        end
                        16'h0001: begin
                            gt_tx_pd_drp_reg <= drp_di[0];
                            gt_tx_qpll_sel_drp_reg <= drp_di[1];
                        end
                        16'h0010: begin
                            gt_txpolarity_drp_reg <= drp_di[0];
                            gt_txelecidle_drp_reg <= drp_di[1];
                            gt_txinhibit_drp_reg <= drp_di[2];
                        end
                        16'h0011: gt_txdiffctrl_drp_reg <= drp_di;
                        16'h0012: gt_txmaincursor_drp_reg <= drp_di;
                        16'h0013: gt_txprecursor_drp_reg <= drp_di;
                        16'h0014: gt_txpostcursor_drp_reg <= drp_di;
                        16'h0040: gt_txprbssel_drp_reg <= drp_di;
                        16'h0041: gt_txprbsforceerr_drp_reg <= gt_txprbsforceerr_drp_reg ^ drp_di[0];
                        // RX
                        16'h1000: begin
                            gt_rx_reset_drp_reg <= drp_di[0];
                            gt_rx_pma_reset_drp_reg <= drp_di[1];
                            gt_rx_pcs_reset_drp_reg <= drp_di[2];
                            gt_rx_dfe_lpm_reset_drp_reg <= drp_di[3];
                            gt_eyescan_reset_drp_reg <= drp_di[4];
                        end
                        16'h1001: begin
                            gt_rx_pd_drp_reg <= drp_di[0];
                            gt_rx_qpll_sel_drp_reg <= drp_di[1];
                        end
                        16'h1002: begin
                            gt_loopback_drp_reg <= drp_di[2:0];
                        end
                        16'h1010: begin
                            gt_rxpolarity_drp_reg <= drp_di[0];
                        end
                        16'h1020: begin
                            gt_rxcdrhold_drp_reg <= drp_di[0];
                        end
                        16'h1024: begin
                            gt_rxlpmen_drp_reg <= drp_di[0];
                        end
                        16'h1040: gt_rxprbssel_drp_reg <= drp_di;
                        16'h1041: gt_rxprbscntreset_drp_reg <= gt_rxprbscntreset_drp_reg ^ drp_di[0];
                        // PHY
                        16'h8101: begin
                            phy_rx_reset_req_en_drp_reg <= drp_di[0];
                        end
                    endcase
                end
                case (drp_addr[15:0])
                    // TX
                    16'h0000: begin
                        drp_do_reg[0] <= gt_tx_reset_drp_reg;
                        drp_do_reg[1] <= gt_tx_pma_reset_drp_reg;
                        drp_do_reg[2] <= gt_tx_pcs_reset_drp_reg;
                        drp_do_reg[8] <= tx_reset_done_reg;
                        drp_do_reg[9] <= gt_tx_reset_done_sync_2_reg;
                        drp_do_reg[10] <= gt_tx_pma_reset_done_sync_2_reg;
                        drp_do_reg[11] <= gt_tx_prgdiv_reset_done_sync_2_reg;
                        drp_do_reg[12] <= gt_userclk_tx_active_sync_2_reg;
                    end
                    16'h0001: begin
                        drp_do_reg[0] <= gt_tx_pd_drp_reg;
                        drp_do_reg[1] <= gt_tx_qpll_sel_drp_reg;
                    end
                    16'h0010: begin
                        drp_do_reg[0] <= gt_txpolarity_drp_reg;
                        drp_do_reg[1] <= gt_txelecidle_drp_reg;
                        drp_do_reg[2] <= gt_txinhibit_drp_reg;
                    end
                    16'h0011: drp_do_reg <= gt_txdiffctrl_drp_reg;
                    16'h0012: drp_do_reg <= gt_txmaincursor_drp_reg;
                    16'h0013: drp_do_reg <= gt_txprecursor_drp_reg;
                    16'h0014: drp_do_reg <= gt_txpostcursor_drp_reg;
                    16'h0040: drp_do_reg <= gt_txprbssel_drp_reg;
                    // RX
                    16'h1000: begin
                        drp_do_reg[0] <= gt_rx_reset_drp_reg;
                        drp_do_reg[1] <= gt_rx_pma_reset_drp_reg;
                        drp_do_reg[2] <= gt_rx_pcs_reset_drp_reg;
                        drp_do_reg[3] <= gt_rx_dfe_lpm_reset_drp_reg;
                        drp_do_reg[4] <= gt_eyescan_reset_drp_reg;
                        drp_do_reg[8] <= rx_reset_done_reg;
                        drp_do_reg[9] <= gt_rx_reset_done_sync_2_reg;
                        drp_do_reg[10] <= gt_rx_pma_reset_done_sync_2_reg;
                        drp_do_reg[11] <= gt_rx_prgdiv_reset_done_sync_2_reg;
                        drp_do_reg[12] <= gt_userclk_rx_active_sync_2_reg;
                    end
                    16'h1001: begin
                        drp_do_reg[0] <= gt_rx_pd_drp_reg;
                        drp_do_reg[1] <= gt_rx_qpll_sel_drp_reg;
                    end
                    16'h1002: begin
                        drp_do_reg[2:0] <= gt_loopback_drp_reg;
                    end
                    16'h1010: begin
                        drp_do_reg[0] <= gt_rxpolarity_drp_reg;
                    end
                    16'h1020: begin
                        drp_do_reg[0] <= gt_rxcdrhold_drp_reg;
                        drp_do_reg[8] <= gt_rxcdrlock_sync_2_reg;
                    end
                    16'h1024: begin
                        drp_do_reg[0] <= gt_rxlpmen_drp_reg;
                    end
                    16'h1028: drp_do_reg <= gt_dmonitorout_drp_reg;
                    16'h1040: drp_do_reg <= gt_rxprbssel_drp_reg;
                    16'h1041: begin
                        drp_do_reg[8] <= gt_rxprbslocked_sync_2_reg;
                        drp_do_reg[9] <= gt_rxprbserr_drp_reg;

                        gt_rxprbserr_drp_reg <= gt_rxprbserr_sync_3_reg;
                    end
                    // PHY
                    16'h8000: begin
                        drp_do_reg[0] <= tx_reset_done_reg;
                    end
                    16'h8100: begin
                        drp_do_reg[0] <= rx_reset_done_reg;
                        drp_do_reg[8] <= phy_rx_block_lock_sync_2_reg;
                        drp_do_reg[9] <= phy_rx_high_ber_sync_2_reg;
                        drp_do_reg[10] <= phy_rx_status_sync_2_reg;
                    end
                    16'h8101: begin
                        drp_do_reg[0] <= phy_rx_reset_req_en_drp_reg;
                        drp_do_reg[8] <= phy_rx_reset_req_drp_reg;

                        phy_rx_reset_req_drp_reg <= phy_rx_reset_req_sync_3_reg ^ phy_rx_reset_req_sync_4_reg;
                    end
                endcase
            end else begin
                // channel DRP interface
                drp_en_reg_1 <= 1'b1;
            end
        end
    end

    if (drp_rdy_1) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_1;
    end else if (drp_rdy_2) begin
        drp_rdy_reg <= 1'b1;
        drp_do_reg <= drp_do_2;
    end

    if (drp_rst) begin
        drp_en_reg_1 <= 1'b0;
        drp_en_reg_2 <= 1'b0;
        drp_we_reg <= 1'b0;
        drp_rdy_reg <= 1'b0;

        qpll0_reset_drp_reg <= 1'b0;
        qpll0_pd_drp_reg <= QPLL0_PD;
        qpll1_reset_drp_reg <= 1'b0;
        qpll1_pd_drp_reg <= QPLL1_PD;

        gt_loopback_drp_reg <= 3'b000;

        gt_tx_reset_drp_reg <= 1'b0;
        gt_tx_pma_reset_drp_reg <= 1'b0;
        gt_tx_pcs_reset_drp_reg <= 1'b0;
        gt_rx_reset_drp_reg <= 1'b0;
        gt_rx_pma_reset_drp_reg <= 1'b0;
        gt_rx_pcs_reset_drp_reg <= 1'b0;
        gt_rx_dfe_lpm_reset_drp_reg <= 1'b0;
        gt_eyescan_reset_drp_reg <= 1'b0;

        gt_rxcdrhold_drp_reg <= 1'b0;
        gt_rxlpmen_drp_reg <= GT_RX_LPM_EN;

        gt_txprbssel_drp_reg <= 4'd0;
        gt_txprbsforceerr_drp_reg <= 1'b0;
        gt_txpolarity_drp_reg <= GT_TX_POLARITY;
        gt_txelecidle_drp_reg <= GT_TX_ELECIDLE;
        gt_txinhibit_drp_reg <= GT_TX_INHIBIT;
        gt_txdiffctrl_drp_reg <= GT_TX_DIFFCTRL;
        gt_txmaincursor_drp_reg <= GT_TX_MAINCURSOR;
        gt_txpostcursor_drp_reg <= GT_TX_POSTCURSOR;
        gt_txprecursor_drp_reg <= GT_TX_PRECURSOR;

        gt_rxpolarity_drp_reg <= GT_RX_POLARITY;
        gt_rxprbscntreset_drp_reg <= 1'b0;
        gt_rxprbssel_drp_reg <= 4'd0;

        gt_rxprbserr_drp_reg <= 1'b0;

        phy_rx_reset_req_drp_reg <= 1'b0;
        phy_rx_reset_req_en_drp_reg <= 1'b1;
    end
end

generate

if (HAS_COMMON && !GT_GTH && GT_USP) begin : xcvr_gty_com_usp

    eth_xcvr_gty_full
    eth_xcvr_gty_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),
        .loopback_in(gt_loopback_reg),

        // DRP
        .drpclk_common_in(drp_clk),
        .drpaddr_common_in(drp_addr_reg),
        .drpdi_common_in(drp_di_reg),
        .drpen_common_in(drp_en_reg_2),
        .drpwe_common_in(drp_we_reg),
        .drpdo_common_out(drp_do_2),
        .drprdy_common_out(drp_rdy_2),

        .drpclk_in(drp_clk),
        .drpaddr_in(drp_addr_reg),
        .drpdi_in(drp_di_reg),
        .drpen_in(drp_en_reg_1),
        .drpwe_in(drp_we_reg),
        .drpdo_out(drp_do_1),
        .drprdy_out(drp_rdy_1),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(qpll0_lock),
        .qpll0outclk_out(qpll0_clk),
        .qpll0outrefclk_out(qpll0_refclk),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(qpll1_lock),
        .qpll1outclk_out(qpll1_clk),
        .qpll1outrefclk_out(qpll1_refclk),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : qpll0_pd_reg),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : qpll0_reset_reg),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : qpll1_pd_reg),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : qpll1_reset_reg),

        .pcierateqpll0_in(QPLL0_EXT_CTRL ? xcvr_qpll0pcierate_in : 3'd0),
        .pcierateqpll1_in(QPLL1_EXT_CTRL ? xcvr_qpll1pcierate_in : 3'd0),

        // Serial data
        .gtytxp_out(xcvr_txp),
        .gtytxn_out(xcvr_txn),
        .gtyrxp_in(xcvr_rxp),
        .gtyrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset_reg),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(gt_txusrclk2),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done_reg),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd_reg ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset_reg),
        .txpmareset_in(gt_tx_pma_reset_reg),
        .txpcsreset_in(gt_tx_pcs_reset_reg),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset_reg),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel_reg ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel_reg ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy_reg),

        .txpolarity_in(gt_txpolarity_sync_reg),
        .txelecidle_in(gt_txelecidle_reg),
        .txinhibit_in(gt_txinhibit_sync_reg),
        .txdiffctrl_in(gt_txdiffctrl_reg),
        .txmaincursor_in(gt_txmaincursor_reg),
        .txprecursor_in(gt_txprecursor_reg),
        .txpostcursor_in(gt_txpostcursor_reg),

        .txprbsforceerr_in(gt_txprbsforceerr_sync_2_reg ^ gt_txprbsforceerr_sync_3_reg),
        .txprbssel_in(gt_txprbssel_sync_reg),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(7'b0),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset_reg),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(gt_rxusrclk2),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done_reg),
        .rxpd_in(gt_rx_pd_reg ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset_reg),
        .rxpmareset_in(gt_rx_pma_reset_reg),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset_reg),
        .eyescanreset_in(gt_eyescan_reset_reg),
        .rxpcsreset_in(gt_rx_pcs_reset_reg),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset_reg),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel_reg ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel_reg ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy_reg),

        .rxcdrlock_out(gt_rxcdrlock),
        .rxcdrhold_in(gt_rxcdrhold_reg),

        .rxlpmen_in(gt_rxlpmen_reg),

        .dmonitorout_out(gt_dmonitorout),

        .rxpolarity_in(gt_rxpolarity_sync_reg),

        .rxprbscntreset_in(gt_rxprbscntreset_sync_2_reg ^ gt_rxprbscntreset_sync_3_reg),
        .rxprbssel_in(gt_rxprbssel_sync_reg),
        .rxprbserr_out(gt_rxprbserr),
        .rxprbslocked_out(gt_rxprbslocked),

        .eyescandataerror_out(),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = qpll0_lock;
    assign xcvr_qpll0clk_out = qpll0_clk;
    assign xcvr_qpll0refclk_out = qpll0_refclk;
    assign xcvr_qpll1lock_out = qpll1_lock;
    assign xcvr_qpll1clk_out = qpll1_clk;
    assign xcvr_qpll1refclk_out = qpll1_refclk;

end else if (HAS_COMMON && GT_GTH && GT_USP) begin : xcvr_gth_com_usp

    eth_xcvr_gth_full
    eth_xcvr_gth_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),
        .loopback_in(gt_loopback_reg),

        // DRP
        .drpclk_common_in(drp_clk),
        .drpaddr_common_in(drp_addr_reg),
        .drpdi_common_in(drp_di_reg),
        .drpen_common_in(drp_en_reg_2),
        .drpwe_common_in(drp_we_reg),
        .drpdo_common_out(drp_do_2),
        .drprdy_common_out(drp_rdy_2),

        .drpclk_in(drp_clk),
        .drpaddr_in(drp_addr_reg),
        .drpdi_in(drp_di_reg),
        .drpen_in(drp_en_reg_1),
        .drpwe_in(drp_we_reg),
        .drpdo_out(drp_do_1),
        .drprdy_out(drp_rdy_1),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(qpll0_lock),
        .qpll0outclk_out(qpll0_clk),
        .qpll0outrefclk_out(qpll0_refclk),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(qpll1_lock),
        .qpll1outclk_out(qpll1_clk),
        .qpll1outrefclk_out(qpll1_refclk),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : qpll0_pd_reg),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : qpll0_reset_reg),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : qpll1_pd_reg),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : qpll1_reset_reg),

        .pcierateqpll0_in(QPLL0_EXT_CTRL ? xcvr_qpll0pcierate_in : 3'd0),
        .pcierateqpll1_in(QPLL1_EXT_CTRL ? xcvr_qpll1pcierate_in : 3'd0),

        // Serial data
        .gthtxp_out(xcvr_txp),
        .gthtxn_out(xcvr_txn),
        .gthrxp_in(xcvr_rxp),
        .gthrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset_reg),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(gt_txusrclk2),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done_reg),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd_reg ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset_reg),
        .txpmareset_in(gt_tx_pma_reset_reg),
        .txpcsreset_in(gt_tx_pcs_reset_reg),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset_reg),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel_reg ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel_reg ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy_reg),

        .txpolarity_in(gt_txpolarity_sync_reg),
        .txelecidle_in(gt_txelecidle_reg),
        .txinhibit_in(gt_txinhibit_sync_reg),
        .txdiffctrl_in(gt_txdiffctrl_reg),
        .txmaincursor_in(gt_txmaincursor_reg),
        .txprecursor_in(gt_txprecursor_reg),
        .txpostcursor_in(gt_txpostcursor_reg),

        .txprbsforceerr_in(gt_txprbsforceerr_sync_2_reg ^ gt_txprbsforceerr_sync_3_reg),
        .txprbssel_in(gt_txprbssel_sync_reg),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(7'b0),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset_reg),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(gt_rxusrclk2),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done_reg),
        .rxpd_in(gt_rx_pd_reg ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset_reg),
        .rxpmareset_in(gt_rx_pma_reset_reg),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset_reg),
        .eyescanreset_in(gt_eyescan_reset_reg),
        .rxpcsreset_in(gt_rx_pcs_reset_reg),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset_reg),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel_reg ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel_reg ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy_reg),

        .rxcdrlock_out(gt_rxcdrlock),
        .rxcdrhold_in(gt_rxcdrhold_reg),

        .rxlpmen_in(gt_rxlpmen_reg),

        .dmonitorout_out(gt_dmonitorout),

        .rxpolarity_in(gt_rxpolarity_sync_reg),

        .rxprbscntreset_in(gt_rxprbscntreset_sync_2_reg ^ gt_rxprbscntreset_sync_3_reg),
        .rxprbssel_in(gt_rxprbssel_sync_reg),
        .rxprbserr_out(gt_rxprbserr),
        .rxprbslocked_out(gt_rxprbslocked),

        .eyescandataerror_out(),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = qpll0_lock;
    assign xcvr_qpll0clk_out = qpll0_clk;
    assign xcvr_qpll0refclk_out = qpll0_refclk;
    assign xcvr_qpll1lock_out = qpll1_lock;
    assign xcvr_qpll1clk_out = qpll1_clk;
    assign xcvr_qpll1refclk_out = qpll1_refclk;

end else if (HAS_COMMON && !GT_GTH && !GT_USP) begin : xcvr_gty_com_us

    eth_xcvr_gty_full
    eth_xcvr_gty_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),
        .loopback_in(gt_loopback_reg),

        // DRP
        .drpclk_common_in(drp_clk),
        .drpaddr_common_in(drp_addr_reg),
        .drpdi_common_in(drp_di_reg),
        .drpen_common_in(drp_en_reg_2),
        .drpwe_common_in(drp_we_reg),
        .drpdo_common_out(drp_do_2),
        .drprdy_common_out(drp_rdy_2),

        .drpclk_in(drp_clk),
        .drpaddr_in(drp_addr_reg),
        .drpdi_in(drp_di_reg),
        .drpen_in(drp_en_reg_1),
        .drpwe_in(drp_we_reg),
        .drpdo_out(drp_do_1),
        .drprdy_out(drp_rdy_1),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(qpll0_lock),
        .qpll0outclk_out(qpll0_clk),
        .qpll0outrefclk_out(qpll0_refclk),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(qpll1_lock),
        .qpll1outclk_out(qpll1_clk),
        .qpll1outrefclk_out(qpll1_refclk),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : qpll0_pd_reg),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : qpll0_reset_reg),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : qpll1_pd_reg),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : qpll1_reset_reg),

        .qpllrsvd2_in(QPLL0_EXT_CTRL ? {2'd0, xcvr_qpll0pcierate_in} : 5'd0), // [2:0] : QPLL0 rate
        .qpllrsvd3_in(QPLL1_EXT_CTRL ? {2'd0, xcvr_qpll1pcierate_in} : 5'd0), // [2:0] : QPLL1 rate

        // Serial data
        .gtytxp_out(xcvr_txp),
        .gtytxn_out(xcvr_txn),
        .gtyrxp_in(xcvr_rxp),
        .gtyrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset_reg),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(gt_txusrclk2),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done_reg),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd_reg ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset_reg),
        .txpmareset_in(gt_tx_pma_reset_reg),
        .txpcsreset_in(gt_tx_pcs_reset_reg),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset_reg),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel_reg ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel_reg ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy_reg),

        .txpolarity_in(gt_txpolarity_sync_reg),
        .txelecidle_in(gt_txelecidle_reg),
        .txinhibit_in(gt_txinhibit_sync_reg),
        .txdiffctrl_in(gt_txdiffctrl_reg),
        .txmaincursor_in(gt_txmaincursor_reg),
        .txprecursor_in(gt_txprecursor_reg),
        .txpostcursor_in(gt_txpostcursor_reg),

        .txprbsforceerr_in(gt_txprbsforceerr_sync_2_reg ^ gt_txprbsforceerr_sync_3_reg),
        .txprbssel_in(gt_txprbssel_sync_reg),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(7'b0),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset_reg),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(gt_rxusrclk2),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done_reg),
        .rxpd_in(gt_rx_pd_reg ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset_reg),
        .rxpmareset_in(gt_rx_pma_reset_reg),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset_reg),
        .eyescanreset_in(gt_eyescan_reset_reg),
        .rxpcsreset_in(gt_rx_pcs_reset_reg),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset_reg),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel_reg ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel_reg ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy_reg),

        .rxcdrlock_out(gt_rxcdrlock),
        .rxcdrhold_in(gt_rxcdrhold_reg),

        .rxlpmen_in(gt_rxlpmen_reg),

        .dmonitorout_out(gt_dmonitorout),

        .rxpolarity_in(gt_rxpolarity_sync_reg),

        .rxprbscntreset_in(gt_rxprbscntreset_sync_2_reg ^ gt_rxprbscntreset_sync_3_reg),
        .rxprbssel_in(gt_rxprbssel_sync_reg),
        .rxprbserr_out(gt_rxprbserr),
        .rxprbslocked_out(gt_rxprbslocked),

        .eyescandataerror_out(),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = qpll0_lock;
    assign xcvr_qpll0clk_out = qpll0_clk;
    assign xcvr_qpll0refclk_out = qpll0_refclk;
    assign xcvr_qpll1lock_out = qpll1_lock;
    assign xcvr_qpll1clk_out = qpll1_clk;
    assign xcvr_qpll1refclk_out = qpll1_refclk;

end else if (HAS_COMMON && GT_GTH && !GT_USP) begin : xcvr_gth_com_us

    eth_xcvr_gth_full
    eth_xcvr_gth_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),
        .loopback_in(gt_loopback_reg),

        // DRP
        .drpclk_common_in(drp_clk),
        .drpaddr_common_in(drp_addr_reg),
        .drpdi_common_in(drp_di_reg),
        .drpen_common_in(drp_en_reg_2),
        .drpwe_common_in(drp_we_reg),
        .drpdo_common_out(drp_do_2),
        .drprdy_common_out(drp_rdy_2),

        .drpclk_in(drp_clk),
        .drpaddr_in(drp_addr_reg),
        .drpdi_in(drp_di_reg),
        .drpen_in(drp_en_reg_1),
        .drpwe_in(drp_we_reg),
        .drpdo_out(drp_do_1),
        .drprdy_out(drp_rdy_1),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(qpll0_lock),
        .qpll0outclk_out(qpll0_clk),
        .qpll0outrefclk_out(qpll0_refclk),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(qpll1_lock),
        .qpll1outclk_out(qpll1_clk),
        .qpll1outrefclk_out(qpll1_refclk),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : qpll0_pd_reg),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : qpll0_reset_reg),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : qpll1_pd_reg),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : qpll1_reset_reg),

        .qpllrsvd2_in(QPLL0_EXT_CTRL ? {2'd0, xcvr_qpll0pcierate_in} : 5'd0), // [2:0] : QPLL0 rate
        .qpllrsvd3_in(QPLL1_EXT_CTRL ? {2'd0, xcvr_qpll1pcierate_in} : 5'd0), // [2:0] : QPLL1 rate

        // Serial data
        .gthtxp_out(xcvr_txp),
        .gthtxn_out(xcvr_txn),
        .gthrxp_in(xcvr_rxp),
        .gthrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset_reg),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(gt_txusrclk2),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done_reg),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd_reg ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset_reg),
        .txpmareset_in(gt_tx_pma_reset_reg),
        .txpcsreset_in(gt_tx_pcs_reset_reg),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset_reg),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel_reg ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel_reg ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy_reg),

        .txpolarity_in(gt_txpolarity_sync_reg),
        .txelecidle_in(gt_txelecidle_reg),
        .txinhibit_in(gt_txinhibit_sync_reg),
        .txdiffctrl_in(gt_txdiffctrl_reg),
        .txmaincursor_in(gt_txmaincursor_reg),
        .txprecursor_in(gt_txprecursor_reg),
        .txpostcursor_in(gt_txpostcursor_reg),

        .txprbsforceerr_in(gt_txprbsforceerr_sync_2_reg ^ gt_txprbsforceerr_sync_3_reg),
        .txprbssel_in(gt_txprbssel_sync_reg),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(7'b0),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset_reg),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(gt_rxusrclk2),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done_reg),
        .rxpd_in(gt_rx_pd_reg ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset_reg),
        .rxpmareset_in(gt_rx_pma_reset_reg),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset_reg),
        .eyescanreset_in(gt_eyescan_reset_reg),
        .rxpcsreset_in(gt_rx_pcs_reset_reg),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset_reg),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel_reg ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel_reg ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy_reg),

        .rxcdrlock_out(gt_rxcdrlock),
        .rxcdrhold_in(gt_rxcdrhold_reg),

        .rxlpmen_in(gt_rxlpmen_reg),

        .dmonitorout_out(gt_dmonitorout),

        .rxpolarity_in(gt_rxpolarity_sync_reg),

        .rxprbscntreset_in(gt_rxprbscntreset_sync_2_reg ^ gt_rxprbscntreset_sync_3_reg),
        .rxprbssel_in(gt_rxprbssel_sync_reg),
        .rxprbserr_out(gt_rxprbserr),
        .rxprbslocked_out(gt_rxprbslocked),

        .eyescandataerror_out(),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = qpll0_lock;
    assign xcvr_qpll0clk_out = qpll0_clk;
    assign xcvr_qpll0refclk_out = qpll0_refclk;
    assign xcvr_qpll1lock_out = qpll1_lock;
    assign xcvr_qpll1clk_out = qpll1_clk;
    assign xcvr_qpll1refclk_out = qpll1_refclk;

end else if (!GT_GTH) begin : xcvr_gty

    eth_xcvr_gty_channel
    eth_xcvr_gty_channel_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),
        .loopback_in(gt_loopback_reg),

        // DRP
        .drpclk_in(drp_clk),
        .drpaddr_in(drp_addr_reg),
        .drpdi_in(drp_di_reg),
        .drpen_in(drp_en_reg_1),
        .drpwe_in(drp_we_reg),
        .drpdo_out(drp_do_1),
        .drprdy_out(drp_rdy_1),

        // PLL
        .qpll0clk_in(qpll0_clk),
        .qpll0refclk_in(qpll0_refclk),
        .qpll1clk_in(qpll1_clk),
        .qpll1refclk_in(qpll1_refclk),

        // Serial data
        .gtytxp_out(xcvr_txp),
        .gtytxn_out(xcvr_txn),
        .gtyrxp_in(xcvr_rxp),
        .gtyrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset_reg),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(gt_txusrclk2),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done_reg),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd_reg ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset_reg),
        .txpmareset_in(gt_tx_pma_reset_reg),
        .txpcsreset_in(gt_tx_pcs_reset_reg),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset_reg),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel_reg ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel_reg ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy_reg),

        .txpolarity_in(gt_txpolarity_sync_reg),
        .txelecidle_in(gt_txelecidle_reg),
        .txinhibit_in(gt_txinhibit_sync_reg),
        .txdiffctrl_in(gt_txdiffctrl_reg),
        .txmaincursor_in(gt_txmaincursor_reg),
        .txprecursor_in(gt_txprecursor_reg),
        .txpostcursor_in(gt_txpostcursor_reg),

        .txprbsforceerr_in(gt_txprbsforceerr_sync_2_reg ^ gt_txprbsforceerr_sync_3_reg),
        .txprbssel_in(gt_txprbssel_sync_reg),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(7'b0),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset_reg),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(gt_rxusrclk2),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done_reg),
        .rxpd_in(gt_rx_pd_reg ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset_reg),
        .rxpmareset_in(gt_rx_pma_reset_reg),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset_reg),
        .eyescanreset_in(gt_eyescan_reset_reg),
        .rxpcsreset_in(gt_rx_pcs_reset_reg),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset_reg),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel_reg ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel_reg ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy_reg),

        .rxcdrlock_out(gt_rxcdrlock),
        .rxcdrhold_in(gt_rxcdrhold_reg),

        .rxlpmen_in(gt_rxlpmen_reg),

        .dmonitorout_out(gt_dmonitorout),

        .rxpolarity_in(gt_rxpolarity_sync_reg),

        .rxprbscntreset_in(gt_rxprbscntreset_sync_2_reg ^ gt_rxprbscntreset_sync_3_reg),
        .rxprbssel_in(gt_rxprbssel_sync_reg),
        .rxprbserr_out(gt_rxprbserr),
        .rxprbslocked_out(gt_rxprbslocked),

        .eyescandataerror_out(),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = 1'b0;
    assign xcvr_qpll0clk_out = 1'b0;
    assign xcvr_qpll0refclk_out = 1'b0;
    assign xcvr_qpll1lock_out = 1'b0;
    assign xcvr_qpll1clk_out = 1'b0;
    assign xcvr_qpll1refclk_out = 1'b0;

    assign qpll0_lock = xcvr_qpll0lock_in;
    assign qpll0_clk = xcvr_qpll0clk_in;
    assign qpll0_refclk = xcvr_qpll0refclk_in;
    assign qpll1_lock = xcvr_qpll1lock_in;
    assign qpll1_clk = xcvr_qpll1clk_in;
    assign qpll1_refclk = xcvr_qpll1refclk_in;

    assign drp_do_2 = 16'd0;
    assign drp_rdy_2 = 1'b0;

end else begin : xcvr_gth

    eth_xcvr_gth_channel
    eth_xcvr_gth_channel_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),
        .loopback_in(gt_loopback_reg),

        // DRP
        .drpclk_in(drp_clk),
        .drpaddr_in(drp_addr_reg),
        .drpdi_in(drp_di_reg),
        .drpen_in(drp_en_reg_1),
        .drpwe_in(drp_we_reg),
        .drpdo_out(drp_do_1),
        .drprdy_out(drp_rdy_1),

        // PLL
        .qpll0clk_in(qpll0_clk),
        .qpll0refclk_in(qpll0_refclk),
        .qpll1clk_in(qpll1_clk),
        .qpll1refclk_in(qpll1_refclk),

        // Serial data
        .gthtxp_out(xcvr_txp),
        .gthtxn_out(xcvr_txn),
        .gthrxp_in(xcvr_rxp),
        .gthrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset_reg),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(gt_txusrclk2),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done_reg),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd_reg ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset_reg),
        .txpmareset_in(gt_tx_pma_reset_reg),
        .txpcsreset_in(gt_tx_pcs_reset_reg),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset_reg),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel_reg ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel_reg ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy_reg),

        .txpolarity_in(gt_txpolarity_sync_reg),
        .txelecidle_in(gt_txelecidle_reg),
        .txinhibit_in(gt_txinhibit_sync_reg),
        .txdiffctrl_in(gt_txdiffctrl_reg),
        .txmaincursor_in(gt_txmaincursor_reg),
        .txprecursor_in(gt_txprecursor_reg),
        .txpostcursor_in(gt_txpostcursor_reg),

        .txprbsforceerr_in(gt_txprbsforceerr_sync_2_reg ^ gt_txprbsforceerr_sync_3_reg),
        .txprbssel_in(gt_txprbssel_sync_reg),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(7'b0),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset_reg),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(gt_rxusrclk2),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done_reg),
        .rxpd_in(gt_rx_pd_reg ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset_reg),
        .rxpmareset_in(gt_rx_pma_reset_reg),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset_reg),
        .eyescanreset_in(gt_eyescan_reset_reg),
        .rxpcsreset_in(gt_rx_pcs_reset_reg),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset_reg),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel_reg ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel_reg ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy_reg),

        .rxcdrlock_out(gt_rxcdrlock),
        .rxcdrhold_in(gt_rxcdrhold_reg),

        .rxlpmen_in(gt_rxlpmen_reg),

        .dmonitorout_out(gt_dmonitorout),

        .rxpolarity_in(gt_rxpolarity_sync_reg),

        .rxprbscntreset_in(gt_rxprbscntreset_sync_2_reg ^ gt_rxprbscntreset_sync_3_reg),
        .rxprbssel_in(gt_rxprbssel_sync_reg),
        .rxprbserr_out(gt_rxprbserr),
        .rxprbslocked_out(gt_rxprbslocked),

        .eyescandataerror_out(),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = 1'b0;
    assign xcvr_qpll0clk_out = 1'b0;
    assign xcvr_qpll0refclk_out = 1'b0;
    assign xcvr_qpll1lock_out = 1'b0;
    assign xcvr_qpll1clk_out = 1'b0;
    assign xcvr_qpll1refclk_out = 1'b0;

    assign qpll0_lock = xcvr_qpll0lock_in;
    assign qpll0_clk = xcvr_qpll0clk_in;
    assign qpll0_refclk = xcvr_qpll0refclk_in;
    assign qpll1_lock = xcvr_qpll1lock_in;
    assign qpll1_clk = xcvr_qpll1clk_in;
    assign qpll1_refclk = xcvr_qpll1refclk_in;

    assign drp_do_2 = 16'd0;
    assign drp_rdy_2 = 1'b0;

end

endgenerate

assign phy_tx_clk = gt_txusrclk2;

wire phy_tx_rst_int;

sync_reset #(
    .N(4)
)
tx_reset_sync_inst (
    .clk(phy_tx_clk),
    .rst(!tx_reset_done_reg),
    .out(phy_tx_rst_int)
);

// extra register for phy_tx_rst signal
(* shreg_extract = "no" *)
reg phy_tx_rst_reg_1 = 1'b1;
(* shreg_extract = "no" *)
reg phy_tx_rst_reg_2 = 1'b1;

always @(posedge phy_tx_clk) begin
    phy_tx_rst_reg_1 <= phy_tx_rst_int;
    phy_tx_rst_reg_2 <= phy_tx_rst_reg_1;
end

assign phy_tx_rst = phy_tx_rst_reg_2;

assign phy_rx_clk = gt_rxusrclk2;

wire phy_rx_rst_int;

sync_reset #(
    .N(4)
)
rx_reset_sync_inst (
    .clk(phy_rx_clk),
    .rst(!rx_reset_done_reg),
    .out(phy_rx_rst_int)
);

// extra register for phy_rx_rst signal
(* shreg_extract = "no" *)
reg phy_rx_rst_reg_1 = 1'b1;
(* shreg_extract = "no" *)
reg phy_rx_rst_reg_2 = 1'b1;

always @(posedge phy_rx_clk) begin
    phy_rx_rst_reg_1 <= phy_rx_rst_int;
    phy_rx_rst_reg_2 <= phy_rx_rst_reg_1;
end

assign phy_rx_rst = phy_rx_rst_reg_2;

eth_phy_10g #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .BIT_REVERSE(1),
    .SCRAMBLER_DISABLE(0),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
    .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
phy_inst (
    .tx_clk(phy_tx_clk),
    .tx_rst(phy_tx_rst),
    .rx_clk(phy_rx_clk),
    .rx_rst(phy_rx_rst),
    .xgmii_txd(phy_xgmii_txd),
    .xgmii_txc(phy_xgmii_txc),
    .xgmii_rxd(phy_xgmii_rxd),
    .xgmii_rxc(phy_xgmii_rxc),
    .serdes_tx_data(gt_txdata),
    .serdes_tx_hdr(gt_txheader),
    .serdes_rx_data(gt_rxdata),
    .serdes_rx_hdr(gt_rxheader),
    .serdes_rx_bitslip(gt_rxgearboxslip),
    .serdes_rx_reset_req(phy_rx_reset_req),
    .tx_bad_block(phy_tx_bad_block),
    .rx_error_count(phy_rx_error_count),
    .rx_bad_block(phy_rx_bad_block),
    .rx_sequence_error(phy_rx_sequence_error),
    .rx_block_lock(phy_rx_block_lock),
    .rx_high_ber(phy_rx_high_ber),
    .rx_status(phy_rx_status),
    .cfg_tx_prbs31_enable(phy_cfg_tx_prbs31_enable),
    .cfg_rx_prbs31_enable(phy_cfg_rx_prbs31_enable)
);

endmodule

`resetall
