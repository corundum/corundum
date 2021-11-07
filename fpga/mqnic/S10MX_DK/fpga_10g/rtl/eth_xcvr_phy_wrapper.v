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
 * Transceiver and PHY wrapper
 */
module eth_xcvr_phy_wrapper (
    input  wire        xcvr_ctrl_clk,
    input  wire        xcvr_ctrl_rst,

    input  wire        xcvr_tx_analogreset,
    input  wire        xcvr_rx_analogreset,
    input  wire        xcvr_tx_digitalreset,
    input  wire        xcvr_rx_digitalreset,
    output wire        xcvr_tx_analogreset_stat,
    output wire        xcvr_rx_analogreset_stat,
    output wire        xcvr_tx_digitalreset_stat,
    output wire        xcvr_rx_digitalreset_stat,
    output wire        xcvr_tx_cal_busy,
    output wire        xcvr_rx_cal_busy,
    input  wire        xcvr_tx_serial_clk,
    input  wire        xcvr_rx_cdr_refclk,
    output wire        xcvr_tx_serial_data,
    input  wire        xcvr_rx_serial_data,
    output wire        xcvr_rx_is_lockedtoref,
    output wire        xcvr_rx_is_lockedtodata,
    input  wire        xcvr_tx_ready,
    input  wire        xcvr_rx_ready,

    output wire        phy_tx_clk,
    output wire        phy_tx_rst,
    input  wire [63:0] phy_xgmii_txd,
    input  wire [7:0]  phy_xgmii_txc,
    output wire        phy_rx_clk,
    output wire        phy_rx_rst,
    output wire [63:0] phy_xgmii_rxd,
    output wire [7:0]  phy_xgmii_rxc,
    output wire        phy_rx_block_lock,
    output wire        phy_rx_high_ber
);

wire xcvr_tx_clk;
wire xcvr_rx_clk;

assign phy_tx_clk = xcvr_tx_clk;
assign phy_rx_clk = xcvr_rx_clk;

wire [1:0] xcvr_tx_hdr;
wire [63:0] xcvr_tx_data;
wire [1:0] xcvr_rx_hdr;
wire [63:0] xcvr_rx_data;

wire [1:0] phy_tx_hdr;
wire [63:0] phy_tx_data;
wire [1:0] phy_rx_hdr;
wire [63:0] phy_rx_data;

wire xcvr_rx_bitslip;

assign {xcvr_tx_hdr, xcvr_tx_data} = {phy_tx_data, phy_tx_hdr};
assign {phy_rx_data, phy_rx_hdr} = {xcvr_rx_hdr, xcvr_rx_data};

eth_xcvr eth_xcvr_inst (
    .tx_analogreset          (xcvr_tx_analogreset),
    .rx_analogreset          (xcvr_rx_analogreset),
    .tx_digitalreset         (xcvr_tx_digitalreset),
    .rx_digitalreset         (xcvr_rx_digitalreset),
    .tx_analogreset_stat     (xcvr_tx_analogreset_stat),
    .rx_analogreset_stat     (xcvr_rx_analogreset_stat),
    .tx_digitalreset_stat    (xcvr_tx_digitalreset_stat),
    .rx_digitalreset_stat    (xcvr_rx_digitalreset_stat),
    .tx_cal_busy             (xcvr_tx_cal_busy),
    .rx_cal_busy             (xcvr_rx_cal_busy),
    .tx_serial_clk0          (xcvr_tx_serial_clk),
    .rx_cdr_refclk0          (xcvr_rx_cdr_refclk),
    .tx_serial_data          (xcvr_tx_serial_data),
    .rx_serial_data          (xcvr_rx_serial_data),
    .rx_is_lockedtoref       (xcvr_rx_is_lockedtoref),
    .rx_is_lockedtodata      (xcvr_rx_is_lockedtodata),
    .tx_coreclkin            (xcvr_tx_clk),
    .rx_coreclkin            (xcvr_rx_clk),
    .tx_clkout               (xcvr_tx_clk),
    .tx_clkout2              (),
    .rx_clkout               (xcvr_rx_clk),
    .rx_clkout2              (),
    .tx_parallel_data        (xcvr_tx_data),
    .tx_control              (xcvr_tx_hdr),
    .tx_enh_data_valid       (1'b1),
    .unused_tx_parallel_data (13'd0),
    .rx_parallel_data        (xcvr_rx_data),
    .rx_control              (xcvr_rx_hdr),
    .rx_enh_data_valid       (),
    .unused_rx_parallel_data (),
    .rx_bitslip              (xcvr_rx_bitslip)
);

sync_reset #(
    .N(4)
)
phy_tx_rst_reset_sync_inst (
    .clk(phy_tx_clk),
    .rst(~xcvr_tx_ready),
    .out(phy_tx_rst)
);

sync_reset #(
    .N(4)
)
phy_rx_rst_reset_sync_inst (
    .clk(phy_rx_clk),
    .rst(~xcvr_rx_ready),
    .out(phy_rx_rst)
);

eth_phy_10g #(
    .BIT_REVERSE(0),
    .BITSLIP_HIGH_CYCLES(32),
    .BITSLIP_LOW_CYCLES(32)
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
    .serdes_tx_data(phy_tx_data),
    .serdes_tx_hdr(phy_tx_hdr),
    .serdes_rx_data(phy_rx_data),
    .serdes_rx_hdr(phy_rx_hdr),
    .serdes_rx_bitslip(xcvr_rx_bitslip),
    .rx_block_lock(phy_rx_block_lock),
    .rx_high_ber(phy_rx_high_ber)
);

endmodule

`resetall
