/*

Copyright 2019-2021, The Regents of the University of California.
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
    parameter BOARD_ID = {16'h1c2c, 16'ha00e},
    parameter BOARD_VER = {16'd0, 16'd1},
    parameter FPGA_ID = 32'h4A56093,

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
    parameter TX_QUEUE_INDEX_WIDTH = 13,
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
    parameter AXIS_PCIE_DATA_WIDTH = 512,
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161,
    parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 62 : 137,
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81,
    parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 64,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 16,
    parameter PCIE_DMA_READ_TX_FC_ENABLE = 1,
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 16,
    parameter PCIE_DMA_WRITE_TX_LIMIT = 3,
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
     * Clock: 100MHz
     */
    input  wire         init_clk,

    /*
     * GPIO
     */
    output wire         led_sreg_d,
    output wire         led_sreg_ld,
    output wire         led_sreg_clk,
    output wire [1:0]   led_bmc,
    output wire [1:0]   led_exp,

    input  wire         pps_in,
    output wire         pps_out,
    output wire         pps_out_en,

    /*
     * BMC interface
     */
    output wire         bmc_clk,
    output wire         bmc_nss,
    output wire         bmc_mosi,
    input  wire         bmc_miso,
    input  wire         bmc_int,

    /*
     * Board status
     */
    input  wire [1:0]   pg,

    /*
     * PCI express
     */
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,
    input  wire         pcie_refclk_p,
    input  wire         pcie_refclk_n,
    input  wire         pcie_rst_n,

    /*
     * Ethernet: QSFP28
     */
    output wire         qsfp_0_tx_0_p,
    output wire         qsfp_0_tx_0_n,
    input  wire         qsfp_0_rx_0_p,
    input  wire         qsfp_0_rx_0_n,
    output wire         qsfp_0_tx_1_p,
    output wire         qsfp_0_tx_1_n,
    input  wire         qsfp_0_rx_1_p,
    input  wire         qsfp_0_rx_1_n,
    output wire         qsfp_0_tx_2_p,
    output wire         qsfp_0_tx_2_n,
    input  wire         qsfp_0_rx_2_p,
    input  wire         qsfp_0_rx_2_n,
    output wire         qsfp_0_tx_3_p,
    output wire         qsfp_0_tx_3_n,
    input  wire         qsfp_0_rx_3_p,
    input  wire         qsfp_0_rx_3_n,
    input  wire         qsfp_0_mgt_refclk_p,
    input  wire         qsfp_0_mgt_refclk_n,
    input  wire         qsfp_0_mod_prsnt_n,
    output wire         qsfp_0_reset_n,
    output wire         qsfp_0_lp_mode,
    input  wire         qsfp_0_intr_n,
    inout  wire         qsfp_0_i2c_scl,
    inout  wire         qsfp_0_i2c_sda,


    output wire         qsfp_1_tx_0_p,
    output wire         qsfp_1_tx_0_n,
    input  wire         qsfp_1_rx_0_p,
    input  wire         qsfp_1_rx_0_n,
    output wire         qsfp_1_tx_1_p,
    output wire         qsfp_1_tx_1_n,
    input  wire         qsfp_1_rx_1_p,
    input  wire         qsfp_1_rx_1_n,
    output wire         qsfp_1_tx_2_p,
    output wire         qsfp_1_tx_2_n,
    input  wire         qsfp_1_rx_2_p,
    input  wire         qsfp_1_rx_2_n,
    output wire         qsfp_1_tx_3_p,
    output wire         qsfp_1_tx_3_n,
    input  wire         qsfp_1_rx_3_p,
    input  wire         qsfp_1_rx_3_n,
    input  wire         qsfp_1_mgt_refclk_p,
    input  wire         qsfp_1_mgt_refclk_n,
    input  wire         qsfp_1_mod_prsnt_n,
    output wire         qsfp_1_reset_n,
    output wire         qsfp_1_lp_mode,
    input  wire         qsfp_1_intr_n,
    inout  wire         qsfp_1_i2c_scl,
    inout  wire         qsfp_1_i2c_sda
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
parameter IF_PTP_PERIOD_NS = 6'h2;
parameter IF_PTP_PERIOD_FNS = 16'h8F5C;

// PCIe interface configuration
parameter MSI_COUNT = 32;

// Ethernet interface configuration
parameter XGMII_DATA_WIDTH = 64;
parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8;
parameter AXIS_ETH_DATA_WIDTH = XGMII_DATA_WIDTH;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH*2;
parameter AXIS_ETH_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire pcie_user_clk;
wire pcie_user_reset;

wire init_clk_bufg;

// Internal 125 MHz clock
wire clk_125mhz_mmcm_out;
wire clk_125mhz_int;
wire rst_125mhz_int;

// Internal 156.25 MHz clock
wire clk_156mhz_int;
wire rst_156mhz_int;

wire mmcm_rst = pcie_user_reset || !pg[0] || !pg[1];
wire mmcm_locked;
wire mmcm_clkfb;

BUFG
init_clk_bufg_inst (
    .I(init_clk),
    .O(init_clk_bufg)
);

// MMCM instance
// 50 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 800 MHz to 1600 MHz
// M = 20, D = 1 sets Fvco = 1000 MHz (in range)
// Divide by 8 to get output frequency of 125 MHz
MMCME3_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(8),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(1),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0),
    .CLKOUT2_DIVIDE(1),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),
    .CLKOUT3_DIVIDE(1),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(0),
    .CLKOUT4_DIVIDE(1),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0),
    .CLKOUT5_DIVIDE(1),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0),
    .CLKOUT6_DIVIDE(1),
    .CLKOUT6_DUTY_CYCLE(0.5),
    .CLKOUT6_PHASE(0),
    .CLKFBOUT_MULT_F(20),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(20.000),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(init_clk_bufg),
    .CLKFBIN(mmcm_clkfb),
    .RST(mmcm_rst),
    .PWRDWN(1'b0),
    .CLKOUT0(clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    .CLKOUT1(),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(mmcm_clkfb),
    .CLKFBOUTB(),
    .LOCKED(mmcm_locked)
);

BUFG
clk_125mhz_bufg_inst (
    .I(clk_125mhz_mmcm_out),
    .O(clk_125mhz_int)
);

sync_reset #(
    .N(4)
)
sync_reset_125mhz_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
);

// GPIO
wire qsfp_0_mod_prsnt_n_int;
wire qsfp_0_intr_n_int;
wire qsfp_0_i2c_scl_i;
wire qsfp_0_i2c_scl_o;
wire qsfp_0_i2c_scl_t;
wire qsfp_0_i2c_sda_i;
wire qsfp_0_i2c_sda_o;
wire qsfp_0_i2c_sda_t;
wire qsfp_1_mod_prsnt_n_int;
wire qsfp_1_intr_n_int;
wire qsfp_1_i2c_scl_i;
wire qsfp_1_i2c_scl_o;
wire qsfp_1_i2c_scl_t;
wire qsfp_1_i2c_sda_i;
wire qsfp_1_i2c_sda_o;
wire qsfp_1_i2c_sda_t;

reg qsfp_0_i2c_scl_o_reg;
reg qsfp_0_i2c_scl_t_reg;
reg qsfp_0_i2c_sda_o_reg;
reg qsfp_0_i2c_sda_t_reg;
reg qsfp_1_i2c_scl_o_reg;
reg qsfp_1_i2c_scl_t_reg;
reg qsfp_1_i2c_sda_o_reg;
reg qsfp_1_i2c_sda_t_reg;

always @(posedge pcie_user_clk) begin
    qsfp_0_i2c_scl_o_reg <= qsfp_0_i2c_scl_o;
    qsfp_0_i2c_scl_t_reg <= qsfp_0_i2c_scl_t;
    qsfp_0_i2c_sda_o_reg <= qsfp_0_i2c_sda_o;
    qsfp_0_i2c_sda_t_reg <= qsfp_0_i2c_sda_t;
    qsfp_1_i2c_scl_o_reg <= qsfp_1_i2c_scl_o;
    qsfp_1_i2c_scl_t_reg <= qsfp_1_i2c_scl_t;
    qsfp_1_i2c_sda_o_reg <= qsfp_1_i2c_sda_o;
    qsfp_1_i2c_sda_t_reg <= qsfp_1_i2c_sda_t;
end

sync_signal #(
    .WIDTH(8),
    .N(2)
)
sync_signal_inst (
    .clk(pcie_user_clk),
    .in({qsfp_0_mod_prsnt_n, qsfp_0_intr_n, qsfp_0_i2c_scl, qsfp_0_i2c_sda,
        qsfp_1_mod_prsnt_n, qsfp_1_intr_n, qsfp_1_i2c_scl, qsfp_1_i2c_sda}),
    .out({qsfp_0_mod_prsnt_n_int, qsfp_0_intr_n_int, qsfp_0_i2c_scl_i, qsfp_0_i2c_sda_i,
        qsfp_1_mod_prsnt_n_int, qsfp_1_intr_n_int, qsfp_1_i2c_scl_i, qsfp_1_i2c_sda_i})
);

assign qsfp_0_i2c_scl = qsfp_0_i2c_scl_t_reg ? 1'bz : qsfp_0_i2c_scl_o_reg;
assign qsfp_0_i2c_sda = qsfp_0_i2c_sda_t_reg ? 1'bz : qsfp_0_i2c_sda_o_reg;
assign qsfp_1_i2c_scl = qsfp_1_i2c_scl_t_reg ? 1'bz : qsfp_1_i2c_scl_o_reg;
assign qsfp_1_i2c_sda = qsfp_1_i2c_sda_t_reg ? 1'bz : qsfp_1_i2c_sda_o_reg;

wire [7:0] led_red;
wire [7:0] led_green;
wire [15:0] led_merged;

assign led_merged[0] = led_red[0];
assign led_merged[1] = led_green[0];
assign led_merged[2] = led_red[1];
assign led_merged[3] = led_green[1];
assign led_merged[4] = led_red[2];
assign led_merged[5] = led_green[2];
assign led_merged[6] = led_red[3];
assign led_merged[7] = led_green[3];
assign led_merged[8] = led_red[4];
assign led_merged[9] = led_green[4];
assign led_merged[10] = led_red[5];
assign led_merged[11] = led_green[5];
assign led_merged[12] = led_red[6];
assign led_merged[13] = led_green[6];
assign led_merged[14] = led_red[7];
assign led_merged[15] = led_green[7];

led_sreg_driver #(
    .COUNT(16),
    .INVERT(1),
    .PRESCALE(63)
)
led_sreg_driver_inst (
    .clk(pcie_user_clk),
    .rst(pcie_user_reset),

    .led(led_merged),

    .sreg_d(led_sreg_d),
    .sreg_ld(led_sreg_ld),
    .sreg_clk(led_sreg_clk)
);

// Flash
wire qspi_clk_int;
wire [3:0] qspi_dq_int;
wire [3:0] qspi_dq_i_int;
wire [3:0] qspi_dq_o_int;
wire [3:0] qspi_dq_oe_int;
wire qspi_cs_int;

reg qspi_clk_reg;
reg [3:0] qspi_dq_o_reg;
reg [3:0] qspi_dq_oe_reg;
reg qspi_cs_reg;

always @(posedge pcie_user_clk) begin
    qspi_clk_reg <= qspi_clk_int;
    qspi_dq_o_reg <= qspi_dq_o_int;
    qspi_dq_oe_reg <= qspi_dq_oe_int;
    qspi_cs_reg <= qspi_cs_int;
end

sync_signal #(
    .WIDTH(4),
    .N(2)
)
flash_sync_signal_inst (
    .clk(pcie_user_clk),
    .in({qspi_dq_int}),
    .out({qspi_dq_i_int})
);

STARTUPE3
startupe3_inst (
    .CFGCLK(),
    .CFGMCLK(),
    .DI(qspi_dq_int),
    .DO(qspi_dq_o_reg),
    .DTS(~qspi_dq_oe_reg),
    .EOS(),
    .FCSBO(qspi_cs_reg),
    .FCSBTS(1'b0),
    .GSR(1'b0),
    .GTS(1'b0),
    .KEYCLEARB(1'b1),
    .PACK(1'b0),
    .PREQ(),
    .USRCCLKO(qspi_clk_reg),
    .USRCCLKTS(1'b0),
    .USRDONEO(1'b0),
    .USRDONETS(1'b1)
);

// FPGA boot
wire fpga_boot;

reg fpga_boot_sync_reg_0 = 1'b0;
reg fpga_boot_sync_reg_1 = 1'b0;
reg fpga_boot_sync_reg_2 = 1'b0;

wire icap_avail;
reg [2:0] icap_state = 0;
reg icap_csib_reg = 1'b1;
reg icap_rdwrb_reg = 1'b0;
reg [31:0] icap_di_reg = 32'hffffffff;

wire [31:0] icap_di_rev;

assign icap_di_rev[ 7] = icap_di_reg[ 0];
assign icap_di_rev[ 6] = icap_di_reg[ 1];
assign icap_di_rev[ 5] = icap_di_reg[ 2];
assign icap_di_rev[ 4] = icap_di_reg[ 3];
assign icap_di_rev[ 3] = icap_di_reg[ 4];
assign icap_di_rev[ 2] = icap_di_reg[ 5];
assign icap_di_rev[ 1] = icap_di_reg[ 6];
assign icap_di_rev[ 0] = icap_di_reg[ 7];

assign icap_di_rev[15] = icap_di_reg[ 8];
assign icap_di_rev[14] = icap_di_reg[ 9];
assign icap_di_rev[13] = icap_di_reg[10];
assign icap_di_rev[12] = icap_di_reg[11];
assign icap_di_rev[11] = icap_di_reg[12];
assign icap_di_rev[10] = icap_di_reg[13];
assign icap_di_rev[ 9] = icap_di_reg[14];
assign icap_di_rev[ 8] = icap_di_reg[15];

assign icap_di_rev[23] = icap_di_reg[16];
assign icap_di_rev[22] = icap_di_reg[17];
assign icap_di_rev[21] = icap_di_reg[18];
assign icap_di_rev[20] = icap_di_reg[19];
assign icap_di_rev[19] = icap_di_reg[20];
assign icap_di_rev[18] = icap_di_reg[21];
assign icap_di_rev[17] = icap_di_reg[22];
assign icap_di_rev[16] = icap_di_reg[23];

assign icap_di_rev[31] = icap_di_reg[24];
assign icap_di_rev[30] = icap_di_reg[25];
assign icap_di_rev[29] = icap_di_reg[26];
assign icap_di_rev[28] = icap_di_reg[27];
assign icap_di_rev[27] = icap_di_reg[28];
assign icap_di_rev[26] = icap_di_reg[29];
assign icap_di_rev[25] = icap_di_reg[30];
assign icap_di_rev[24] = icap_di_reg[31];

always @(posedge clk_125mhz_int) begin
    case (icap_state)
        0: begin
            icap_state <= 0;
            icap_csib_reg <= 1'b1;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'hffffffff; // dummy word

            if (fpga_boot_sync_reg_2 && icap_avail) begin
                icap_state <= 1;
                icap_csib_reg <= 1'b0;
                icap_rdwrb_reg <= 1'b0;
                icap_di_reg <= 32'hffffffff; // dummy word
            end
        end
        1: begin
            icap_state <= 2;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'hAA995566; // sync word
        end
        2: begin
            icap_state <= 3;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h20000000; // type 1 noop
        end
        3: begin
            icap_state <= 4;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h30008001; // write 1 word to CMD
        end
        4: begin
            icap_state <= 5;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h0000000F; // IPROG
        end
        5: begin
            icap_state <= 0;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h20000000; // type 1 noop
        end
    endcase

    fpga_boot_sync_reg_0 <= fpga_boot;
    fpga_boot_sync_reg_1 <= fpga_boot_sync_reg_0;
    fpga_boot_sync_reg_2 <= fpga_boot_sync_reg_1;
end

ICAPE3
icape3_inst (
    .AVAIL(icap_avail),
    .CLK(clk_125mhz_int),
    .CSIB(icap_csib_reg),
    .I(icap_di_rev),
    .O(),
    .PRDONE(),
    .PRERROR(),
    .RDWRB(icap_rdwrb_reg)
);

// PCIe
wire pcie_sys_clk;
wire pcie_sys_clk_gt;

IBUFDS_GTE4 #(
    .REFCLK_HROW_CK_SEL(2'b00)
)
ibufds_gte4_pcie_mgt_refclk_inst (
    .I             (pcie_refclk_p),
    .IB            (pcie_refclk_n),
    .CEB           (1'b0),
    .O             (pcie_sys_clk_gt),
    .ODIV2         (pcie_sys_clk)
);

wire [AXIS_PCIE_DATA_WIDTH-1:0]    axis_rq_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0]    axis_rq_tkeep;
wire                               axis_rq_tlast;
wire                               axis_rq_tready;
wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] axis_rq_tuser;
wire                               axis_rq_tvalid;

wire [AXIS_PCIE_DATA_WIDTH-1:0]    axis_rc_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0]    axis_rc_tkeep;
wire                               axis_rc_tlast;
wire                               axis_rc_tready;
wire [AXIS_PCIE_RC_USER_WIDTH-1:0] axis_rc_tuser;
wire                               axis_rc_tvalid;

wire [AXIS_PCIE_DATA_WIDTH-1:0]    axis_cq_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0]    axis_cq_tkeep;
wire                               axis_cq_tlast;
wire                               axis_cq_tready;
wire [AXIS_PCIE_CQ_USER_WIDTH-1:0] axis_cq_tuser;
wire                               axis_cq_tvalid;

wire [AXIS_PCIE_DATA_WIDTH-1:0]    axis_cc_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0]    axis_cc_tkeep;
wire                               axis_cc_tlast;
wire                               axis_cc_tready;
wire [AXIS_PCIE_CC_USER_WIDTH-1:0] axis_cc_tuser;
wire                               axis_cc_tvalid;

wire [RQ_SEQ_NUM_WIDTH-1:0]        pcie_rq_seq_num0;
wire                               pcie_rq_seq_num_vld0;
wire [RQ_SEQ_NUM_WIDTH-1:0]        pcie_rq_seq_num1;
wire                               pcie_rq_seq_num_vld1;

wire [3:0] pcie_tfc_nph_av;
wire [3:0] pcie_tfc_npd_av;

wire [2:0] cfg_max_payload;
wire [2:0] cfg_max_read_req;

wire [9:0]  cfg_mgmt_addr;
wire [7:0]  cfg_mgmt_function_number;
wire        cfg_mgmt_write;
wire [31:0] cfg_mgmt_write_data;
wire [3:0]  cfg_mgmt_byte_enable;
wire        cfg_mgmt_read;
wire [31:0] cfg_mgmt_read_data;
wire        cfg_mgmt_read_write_done;

wire [7:0]  cfg_fc_ph;
wire [11:0] cfg_fc_pd;
wire [7:0]  cfg_fc_nph;
wire [11:0] cfg_fc_npd;
wire [7:0]  cfg_fc_cplh;
wire [11:0] cfg_fc_cpld;
wire [2:0]  cfg_fc_sel;

wire [3:0]  cfg_interrupt_msi_enable;
wire [11:0] cfg_interrupt_msi_mmenable;
wire        cfg_interrupt_msi_mask_update;
wire [31:0] cfg_interrupt_msi_data;
wire [3:0]  cfg_interrupt_msi_select;
wire [31:0] cfg_interrupt_msi_int;
wire [31:0] cfg_interrupt_msi_pending_status;
wire        cfg_interrupt_msi_pending_status_data_enable;
wire [3:0]  cfg_interrupt_msi_pending_status_function_num;
wire        cfg_interrupt_msi_sent;
wire        cfg_interrupt_msi_fail;
wire [2:0]  cfg_interrupt_msi_attr;
wire        cfg_interrupt_msi_tph_present;
wire [1:0]  cfg_interrupt_msi_tph_type;
wire [8:0]  cfg_interrupt_msi_tph_st_tag;
wire [3:0]  cfg_interrupt_msi_function_number;

wire status_error_cor;
wire status_error_uncor;

// extra register for pcie_user_reset signal
wire pcie_user_reset_int;
(* shreg_extract = "no" *)
reg pcie_user_reset_reg_1 = 1'b1;
(* shreg_extract = "no" *)
reg pcie_user_reset_reg_2 = 1'b1;

always @(posedge pcie_user_clk) begin
    pcie_user_reset_reg_1 <= pcie_user_reset_int;
    pcie_user_reset_reg_2 <= pcie_user_reset_reg_1;
end

assign pcie_user_reset = pcie_user_reset_reg_2;

// ila_0 ila_rq (
//     .clk(pcie_user_clk),
//     .trig_out(),
//     .trig_out_ack(1'b0),
//     .trig_in(1'b0),
//     .trig_in_ack(),
//     .probe0(axis_rq_tdata),
//     .probe1(axis_rq_tkeep),
//     .probe2(axis_rq_tvalid),
//     .probe3(axis_rq_tready),
//     .probe4({pcie_tfc_npd_av, pcie_tfc_nph_av, axis_rq_tuser}),
//     .probe5(axis_rq_tlast)
// );

// ila_0 ila_rc (
//     .clk(pcie_user_clk),
//     .trig_out(),
//     .trig_out_ack(1'b0),
//     .trig_in(1'b0),
//     .trig_in_ack(),
//     .probe0(axis_rc_tdata),
//     .probe1(axis_rc_tkeep),
//     .probe2(axis_rc_tvalid),
//     .probe3(axis_rc_tready),
//     .probe4(axis_rc_tuser),
//     .probe5(axis_rc_tlast)
// );

pcie4_uscale_plus_0
pcie4_uscale_plus_inst (
    .pci_exp_txn(pcie_tx_n),
    .pci_exp_txp(pcie_tx_p),
    .pci_exp_rxn(pcie_rx_n),
    .pci_exp_rxp(pcie_rx_p),
    .user_clk(pcie_user_clk),
    .user_reset(pcie_user_reset_int),
    .user_lnk_up(),

    .s_axis_rq_tdata(axis_rq_tdata),
    .s_axis_rq_tkeep(axis_rq_tkeep),
    .s_axis_rq_tlast(axis_rq_tlast),
    .s_axis_rq_tready(axis_rq_tready),
    .s_axis_rq_tuser(axis_rq_tuser),
    .s_axis_rq_tvalid(axis_rq_tvalid),

    .m_axis_rc_tdata(axis_rc_tdata),
    .m_axis_rc_tkeep(axis_rc_tkeep),
    .m_axis_rc_tlast(axis_rc_tlast),
    .m_axis_rc_tready(axis_rc_tready),
    .m_axis_rc_tuser(axis_rc_tuser),
    .m_axis_rc_tvalid(axis_rc_tvalid),

    .m_axis_cq_tdata(axis_cq_tdata),
    .m_axis_cq_tkeep(axis_cq_tkeep),
    .m_axis_cq_tlast(axis_cq_tlast),
    .m_axis_cq_tready(axis_cq_tready),
    .m_axis_cq_tuser(axis_cq_tuser),
    .m_axis_cq_tvalid(axis_cq_tvalid),

    .s_axis_cc_tdata(axis_cc_tdata),
    .s_axis_cc_tkeep(axis_cc_tkeep),
    .s_axis_cc_tlast(axis_cc_tlast),
    .s_axis_cc_tready(axis_cc_tready),
    .s_axis_cc_tuser(axis_cc_tuser),
    .s_axis_cc_tvalid(axis_cc_tvalid),

    .pcie_rq_seq_num0(pcie_rq_seq_num0),
    .pcie_rq_seq_num_vld0(pcie_rq_seq_num_vld0),
    .pcie_rq_seq_num1(pcie_rq_seq_num1),
    .pcie_rq_seq_num_vld1(pcie_rq_seq_num_vld1),
    .pcie_rq_tag0(),
    .pcie_rq_tag1(),
    .pcie_rq_tag_av(),
    .pcie_rq_tag_vld0(),
    .pcie_rq_tag_vld1(),

    .pcie_tfc_nph_av(pcie_tfc_nph_av),
    .pcie_tfc_npd_av(pcie_tfc_npd_av),

    .pcie_cq_np_req(1'b1),
    .pcie_cq_np_req_count(),

    .cfg_phy_link_down(),
    .cfg_phy_link_status(),
    .cfg_negotiated_width(),
    .cfg_current_speed(),
    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_function_status(),
    .cfg_function_power_state(),
    .cfg_vf_status(),
    .cfg_vf_power_state(),
    .cfg_link_power_state(),

    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),
    .cfg_mgmt_debug_access(1'b0),

    .cfg_err_cor_out(),
    .cfg_err_nonfatal_out(),
    .cfg_err_fatal_out(),
    .cfg_local_error_valid(),
    .cfg_local_error_out(),
    .cfg_ltssm_state(),
    .cfg_rx_pm_state(),
    .cfg_tx_pm_state(),
    .cfg_rcb_status(),
    .cfg_obff_enable(),
    .cfg_pl_status_change(),
    .cfg_tph_requester_enable(),
    .cfg_tph_st_mode(),
    .cfg_vf_tph_requester_enable(),
    .cfg_vf_tph_st_mode(),

    .cfg_msg_received(),
    .cfg_msg_received_data(),
    .cfg_msg_received_type(),
    .cfg_msg_transmit(1'b0),
    .cfg_msg_transmit_type(3'd0),
    .cfg_msg_transmit_data(32'd0),
    .cfg_msg_transmit_done(),

    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    .cfg_dsn(64'd0),

    .cfg_power_state_change_ack(1'b1),
    .cfg_power_state_change_interrupt(),

    .cfg_err_cor_in(status_error_cor),
    .cfg_err_uncor_in(status_error_uncor),
    .cfg_flr_in_process(),
    .cfg_flr_done(4'd0),
    .cfg_vf_flr_in_process(),
    .cfg_vf_flr_func_num(8'd0),
    .cfg_vf_flr_done(8'd0),

    .cfg_link_training_enable(1'b1),

    .cfg_interrupt_int(4'd0),
    .cfg_interrupt_pending(4'd0),
    .cfg_interrupt_sent(),
    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_mmenable(cfg_interrupt_msi_mmenable),
    .cfg_interrupt_msi_mask_update(cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_data(cfg_interrupt_msi_data),
    .cfg_interrupt_msi_select(cfg_interrupt_msi_select),
    .cfg_interrupt_msi_int(cfg_interrupt_msi_int),
    .cfg_interrupt_msi_pending_status(cfg_interrupt_msi_pending_status),
    .cfg_interrupt_msi_pending_status_data_enable(cfg_interrupt_msi_pending_status_data_enable),
    .cfg_interrupt_msi_pending_status_function_num(cfg_interrupt_msi_pending_status_function_num),
    .cfg_interrupt_msi_sent(cfg_interrupt_msi_sent),
    .cfg_interrupt_msi_fail(cfg_interrupt_msi_fail),
    .cfg_interrupt_msi_attr(cfg_interrupt_msi_attr),
    .cfg_interrupt_msi_tph_present(cfg_interrupt_msi_tph_present),
    .cfg_interrupt_msi_tph_type(cfg_interrupt_msi_tph_type),
    .cfg_interrupt_msi_tph_st_tag(cfg_interrupt_msi_tph_st_tag),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    .cfg_pm_aspm_l1_entry_reject(1'b0),
    .cfg_pm_aspm_tx_l0s_entry_disable(1'b0),

    .cfg_hot_reset_out(),

    .cfg_config_space_enable(1'b1),
    .cfg_req_pm_transition_l23_ready(1'b0),
    .cfg_hot_reset_in(1'b0),

    .cfg_ds_port_number(8'd0),
    .cfg_ds_bus_number(8'd0),
    .cfg_ds_device_number(5'd0),

    .sys_clk(pcie_sys_clk),
    .sys_clk_gt(pcie_sys_clk_gt),
    .sys_reset(pcie_rst_n),

    .phy_rdy_out()
);

// XGMII 10G PHY

// QSFP0
wire                         qsfp_0_tx_clk_0_int;
wire                         qsfp_0_tx_rst_0_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_txd_0_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_txc_0_int;
wire                         qsfp_0_tx_prbs31_enable_0_int;
wire                         qsfp_0_rx_clk_0_int;
wire                         qsfp_0_rx_rst_0_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_rxd_0_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_rxc_0_int;
wire                         qsfp_0_rx_prbs31_enable_0_int;
wire [6:0]                   qsfp_0_rx_error_count_0_int;
wire                         qsfp_0_tx_clk_1_int;
wire                         qsfp_0_tx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_txd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_txc_1_int;
wire                         qsfp_0_tx_prbs31_enable_1_int;
wire                         qsfp_0_rx_clk_1_int;
wire                         qsfp_0_rx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_rxd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_rxc_1_int;
wire                         qsfp_0_rx_prbs31_enable_1_int;
wire [6:0]                   qsfp_0_rx_error_count_1_int;
wire                         qsfp_0_tx_clk_2_int;
wire                         qsfp_0_tx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_txd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_txc_2_int;
wire                         qsfp_0_tx_prbs31_enable_2_int;
wire                         qsfp_0_rx_clk_2_int;
wire                         qsfp_0_rx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_rxd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_rxc_2_int;
wire                         qsfp_0_rx_prbs31_enable_2_int;
wire [6:0]                   qsfp_0_rx_error_count_2_int;
wire                         qsfp_0_tx_clk_3_int;
wire                         qsfp_0_tx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_txd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_txc_3_int;
wire                         qsfp_0_tx_prbs31_enable_3_int;
wire                         qsfp_0_rx_clk_3_int;
wire                         qsfp_0_rx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_0_rxd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_0_rxc_3_int;
wire                         qsfp_0_rx_prbs31_enable_3_int;
wire [6:0]                   qsfp_0_rx_error_count_3_int;

wire qsfp_0_rx_block_lock_0;
wire qsfp_0_rx_block_lock_1;
wire qsfp_0_rx_block_lock_2;
wire qsfp_0_rx_block_lock_3;

wire qsfp_0_gtpowergood;

wire qsfp_0_mgt_refclk;
wire qsfp_0_mgt_refclk_int;
wire qsfp_0_mgt_refclk_bufg;

IBUFDS_GTE4 ibufds_gte4_qsfp_0_mgt_refclk_inst (
    .I     (qsfp_0_mgt_refclk_p),
    .IB    (qsfp_0_mgt_refclk_n),
    .CEB   (1'b0),
    .O     (qsfp_0_mgt_refclk),
    .ODIV2 (qsfp_0_mgt_refclk_int)
);

BUFG_GT bufg_gt_qsfp_0_mgt_refclk_inst (
    .CE      (qsfp_0_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (qsfp_0_mgt_refclk_int),
    .O       (qsfp_0_mgt_refclk_bufg)
);

wire qsfp_0_rst;

sync_reset #(
    .N(4)
)
qsfp_0_sync_reset_inst (
    .clk(qsfp_0_mgt_refclk_bufg),
    .rst(rst_125mhz_int),
    .out(qsfp_0_rst)
);

wire qsfp_0_qpll0lock;
wire qsfp_0_qpll0outclk;
wire qsfp_0_qpll0outrefclk;

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(1),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_0_phy_0_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_0_rst),

    // Common
    .xcvr_gtpowergood_out(qsfp_0_gtpowergood),

    // PLL out
    .xcvr_gtrefclk00_in(qsfp_0_mgt_refclk),
    .xcvr_qpll0lock_out(qsfp_0_qpll0lock),
    .xcvr_qpll0outclk_out(qsfp_0_qpll0outclk),
    .xcvr_qpll0outrefclk_out(qsfp_0_qpll0outrefclk),

    // PLL in
    .xcvr_qpll0lock_in(1'b0),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(1'b0),
    .xcvr_qpll0refclk_in(1'b0),

    // Serial data
    .xcvr_txp(qsfp_0_tx_0_p),
    .xcvr_txn(qsfp_0_tx_0_n),
    .xcvr_rxp(qsfp_0_rx_0_p),
    .xcvr_rxn(qsfp_0_rx_0_n),

    // PHY connections
    .phy_tx_clk(qsfp_0_tx_clk_0_int),
    .phy_tx_rst(qsfp_0_tx_rst_0_int),
    .phy_xgmii_txd(qsfp_0_txd_0_int),
    .phy_xgmii_txc(qsfp_0_txc_0_int),
    .phy_rx_clk(qsfp_0_rx_clk_0_int),
    .phy_rx_rst(qsfp_0_rx_rst_0_int),
    .phy_xgmii_rxd(qsfp_0_rxd_0_int),
    .phy_xgmii_rxc(qsfp_0_rxc_0_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_0_rx_error_count_0_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_0_rx_block_lock_0),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_0_tx_prbs31_enable_0_int),
    .phy_rx_prbs31_enable(qsfp_0_rx_prbs31_enable_0_int)
);

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(0),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_0_phy_1_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_0_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0outclk_out(),
    .xcvr_qpll0outrefclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(qsfp_0_qpll0lock),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(qsfp_0_qpll0outclk),
    .xcvr_qpll0refclk_in(qsfp_0_qpll0outrefclk),

    // Serial data
    .xcvr_txp(qsfp_0_tx_1_p),
    .xcvr_txn(qsfp_0_tx_1_n),
    .xcvr_rxp(qsfp_0_rx_1_p),
    .xcvr_rxn(qsfp_0_rx_1_n),

    // PHY connections
    .phy_tx_clk(qsfp_0_tx_clk_1_int),
    .phy_tx_rst(qsfp_0_tx_rst_1_int),
    .phy_xgmii_txd(qsfp_0_txd_1_int),
    .phy_xgmii_txc(qsfp_0_txc_1_int),
    .phy_rx_clk(qsfp_0_rx_clk_1_int),
    .phy_rx_rst(qsfp_0_rx_rst_1_int),
    .phy_xgmii_rxd(qsfp_0_rxd_1_int),
    .phy_xgmii_rxc(qsfp_0_rxc_1_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_0_rx_error_count_1_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_0_rx_block_lock_1),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_0_tx_prbs31_enable_1_int),
    .phy_rx_prbs31_enable(qsfp_0_rx_prbs31_enable_1_int)
);

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(0),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_0_phy_2_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_0_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0outclk_out(),
    .xcvr_qpll0outrefclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(qsfp_0_qpll0lock),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(qsfp_0_qpll0outclk),
    .xcvr_qpll0refclk_in(qsfp_0_qpll0outrefclk),

    // Serial data
    .xcvr_txp(qsfp_0_tx_2_p),
    .xcvr_txn(qsfp_0_tx_2_n),
    .xcvr_rxp(qsfp_0_rx_2_p),
    .xcvr_rxn(qsfp_0_rx_2_n),

    // PHY connections
    .phy_tx_clk(qsfp_0_tx_clk_2_int),
    .phy_tx_rst(qsfp_0_tx_rst_2_int),
    .phy_xgmii_txd(qsfp_0_txd_2_int),
    .phy_xgmii_txc(qsfp_0_txc_2_int),
    .phy_rx_clk(qsfp_0_rx_clk_2_int),
    .phy_rx_rst(qsfp_0_rx_rst_2_int),
    .phy_xgmii_rxd(qsfp_0_rxd_2_int),
    .phy_xgmii_rxc(qsfp_0_rxc_2_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_0_rx_error_count_2_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_0_rx_block_lock_2),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_0_tx_prbs31_enable_2_int),
    .phy_rx_prbs31_enable(qsfp_0_rx_prbs31_enable_2_int)
);

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(0),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_0_phy_3_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_0_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0outclk_out(),
    .xcvr_qpll0outrefclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(qsfp_0_qpll0lock),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(qsfp_0_qpll0outclk),
    .xcvr_qpll0refclk_in(qsfp_0_qpll0outrefclk),

    // Serial data
    .xcvr_txp(qsfp_0_tx_3_p),
    .xcvr_txn(qsfp_0_tx_3_n),
    .xcvr_rxp(qsfp_0_rx_3_p),
    .xcvr_rxn(qsfp_0_rx_3_n),

    // PHY connections
    .phy_tx_clk(qsfp_0_tx_clk_3_int),
    .phy_tx_rst(qsfp_0_tx_rst_3_int),
    .phy_xgmii_txd(qsfp_0_txd_3_int),
    .phy_xgmii_txc(qsfp_0_txc_3_int),
    .phy_rx_clk(qsfp_0_rx_clk_3_int),
    .phy_rx_rst(qsfp_0_rx_rst_3_int),
    .phy_xgmii_rxd(qsfp_0_rxd_3_int),
    .phy_xgmii_rxc(qsfp_0_rxc_3_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_0_rx_error_count_3_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_0_rx_block_lock_3),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_0_tx_prbs31_enable_3_int),
    .phy_rx_prbs31_enable(qsfp_0_rx_prbs31_enable_3_int)
);

// QSFP1
wire                         qsfp_1_tx_clk_0_int;
wire                         qsfp_1_tx_rst_0_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_txd_0_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_txc_0_int;
wire                         qsfp_1_tx_prbs31_enable_0_int;
wire                         qsfp_1_rx_clk_0_int;
wire                         qsfp_1_rx_rst_0_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_rxd_0_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_rxc_0_int;
wire                         qsfp_1_rx_prbs31_enable_0_int;
wire [6:0]                   qsfp_1_rx_error_count_0_int;
wire                         qsfp_1_tx_clk_1_int;
wire                         qsfp_1_tx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_txd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_txc_1_int;
wire                         qsfp_1_tx_prbs31_enable_1_int;
wire                         qsfp_1_rx_clk_1_int;
wire                         qsfp_1_rx_rst_1_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_rxd_1_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_rxc_1_int;
wire                         qsfp_1_rx_prbs31_enable_1_int;
wire [6:0]                   qsfp_1_rx_error_count_1_int;
wire                         qsfp_1_tx_clk_2_int;
wire                         qsfp_1_tx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_txd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_txc_2_int;
wire                         qsfp_1_tx_prbs31_enable_2_int;
wire                         qsfp_1_rx_clk_2_int;
wire                         qsfp_1_rx_rst_2_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_rxd_2_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_rxc_2_int;
wire                         qsfp_1_rx_prbs31_enable_2_int;
wire [6:0]                   qsfp_1_rx_error_count_2_int;
wire                         qsfp_1_tx_clk_3_int;
wire                         qsfp_1_tx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_txd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_txc_3_int;
wire                         qsfp_1_tx_prbs31_enable_3_int;
wire                         qsfp_1_rx_clk_3_int;
wire                         qsfp_1_rx_rst_3_int;
wire [XGMII_DATA_WIDTH-1:0]  qsfp_1_rxd_3_int;
wire [XGMII_CTRL_WIDTH-1:0]  qsfp_1_rxc_3_int;
wire                         qsfp_1_rx_prbs31_enable_3_int;
wire [6:0]                   qsfp_1_rx_error_count_3_int;

wire qsfp_1_rx_block_lock_0;
wire qsfp_1_rx_block_lock_1;
wire qsfp_1_rx_block_lock_2;
wire qsfp_1_rx_block_lock_3;

wire qsfp_1_gtpowergood;

wire qsfp_1_mgt_refclk;
wire qsfp_1_mgt_refclk_int;
wire qsfp_1_mgt_refclk_bufg;

IBUFDS_GTE4 ibufds_gte4_qsfp_1_mgt_refclk_inst (
    .I     (qsfp_1_mgt_refclk_p),
    .IB    (qsfp_1_mgt_refclk_n),
    .CEB   (1'b0),
    .O     (qsfp_1_mgt_refclk),
    .ODIV2 (qsfp_1_mgt_refclk_int)
);

BUFG_GT bufg_gt_qsfp_1_mgt_refclk_inst (
    .CE      (qsfp_1_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (qsfp_1_mgt_refclk_int),
    .O       (qsfp_1_mgt_refclk_bufg)
);

wire qsfp_1_rst;

sync_reset #(
    .N(4)
)
qsfp_1_sync_reset_inst (
    .clk(qsfp_1_mgt_refclk_bufg),
    .rst(rst_125mhz_int),
    .out(qsfp_1_rst)
);

wire qsfp_1_qpll0lock;
wire qsfp_1_qpll0outclk;
wire qsfp_1_qpll0outrefclk;

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(1),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_1_phy_0_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_1_rst),

    // Common
    .xcvr_gtpowergood_out(qsfp_1_gtpowergood),

    // PLL out
    .xcvr_gtrefclk00_in(qsfp_1_mgt_refclk),
    .xcvr_qpll0lock_out(qsfp_1_qpll0lock),
    .xcvr_qpll0outclk_out(qsfp_1_qpll0outclk),
    .xcvr_qpll0outrefclk_out(qsfp_1_qpll0outrefclk),

    // PLL in
    .xcvr_qpll0lock_in(1'b0),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(1'b0),
    .xcvr_qpll0refclk_in(1'b0),

    // Serial data
    .xcvr_txp(qsfp_1_tx_0_p),
    .xcvr_txn(qsfp_1_tx_0_n),
    .xcvr_rxp(qsfp_1_rx_0_p),
    .xcvr_rxn(qsfp_1_rx_0_n),

    // PHY connections
    .phy_tx_clk(qsfp_1_tx_clk_0_int),
    .phy_tx_rst(qsfp_1_tx_rst_0_int),
    .phy_xgmii_txd(qsfp_1_txd_0_int),
    .phy_xgmii_txc(qsfp_1_txc_0_int),
    .phy_rx_clk(qsfp_1_rx_clk_0_int),
    .phy_rx_rst(qsfp_1_rx_rst_0_int),
    .phy_xgmii_rxd(qsfp_1_rxd_0_int),
    .phy_xgmii_rxc(qsfp_1_rxc_0_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_1_rx_error_count_0_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_1_rx_block_lock_0),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_1_tx_prbs31_enable_0_int),
    .phy_rx_prbs31_enable(qsfp_1_rx_prbs31_enable_0_int)
);

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(0),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_1_phy_1_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_1_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0outclk_out(),
    .xcvr_qpll0outrefclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(qsfp_1_qpll0lock),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(qsfp_1_qpll0outclk),
    .xcvr_qpll0refclk_in(qsfp_1_qpll0outrefclk),

    // Serial data
    .xcvr_txp(qsfp_1_tx_1_p),
    .xcvr_txn(qsfp_1_tx_1_n),
    .xcvr_rxp(qsfp_1_rx_1_p),
    .xcvr_rxn(qsfp_1_rx_1_n),

    // PHY connections
    .phy_tx_clk(qsfp_1_tx_clk_1_int),
    .phy_tx_rst(qsfp_1_tx_rst_1_int),
    .phy_xgmii_txd(qsfp_1_txd_1_int),
    .phy_xgmii_txc(qsfp_1_txc_1_int),
    .phy_rx_clk(qsfp_1_rx_clk_1_int),
    .phy_rx_rst(qsfp_1_rx_rst_1_int),
    .phy_xgmii_rxd(qsfp_1_rxd_1_int),
    .phy_xgmii_rxc(qsfp_1_rxc_1_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_1_rx_error_count_1_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_1_rx_block_lock_1),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_1_tx_prbs31_enable_1_int),
    .phy_rx_prbs31_enable(qsfp_1_rx_prbs31_enable_1_int)
);

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(0),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_1_phy_2_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_1_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0outclk_out(),
    .xcvr_qpll0outrefclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(qsfp_1_qpll0lock),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(qsfp_1_qpll0outclk),
    .xcvr_qpll0refclk_in(qsfp_1_qpll0outrefclk),

    // Serial data
    .xcvr_txp(qsfp_1_tx_2_p),
    .xcvr_txn(qsfp_1_tx_2_n),
    .xcvr_rxp(qsfp_1_rx_2_p),
    .xcvr_rxn(qsfp_1_rx_2_n),

    // PHY connections
    .phy_tx_clk(qsfp_1_tx_clk_2_int),
    .phy_tx_rst(qsfp_1_tx_rst_2_int),
    .phy_xgmii_txd(qsfp_1_txd_2_int),
    .phy_xgmii_txc(qsfp_1_txc_2_int),
    .phy_rx_clk(qsfp_1_rx_clk_2_int),
    .phy_rx_rst(qsfp_1_rx_rst_2_int),
    .phy_xgmii_rxd(qsfp_1_rxd_2_int),
    .phy_xgmii_rxc(qsfp_1_rxc_2_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_1_rx_error_count_2_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_1_rx_block_lock_2),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_1_tx_prbs31_enable_2_int),
    .phy_rx_prbs31_enable(qsfp_1_rx_prbs31_enable_2_int)
);

eth_xcvr_phy_wrapper #(
    .HAS_COMMON(0),
    .PRBS31_ENABLE(1),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/2.56)
)
qsfp_1_phy_3_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_1_rst),

    // Common
    .xcvr_gtpowergood_out(),

    // PLL out
    .xcvr_gtrefclk00_in(1'b0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0outclk_out(),
    .xcvr_qpll0outrefclk_out(),

    // PLL in
    .xcvr_qpll0lock_in(qsfp_1_qpll0lock),
    .xcvr_qpll0reset_out(),
    .xcvr_qpll0clk_in(qsfp_1_qpll0outclk),
    .xcvr_qpll0refclk_in(qsfp_1_qpll0outrefclk),

    // Serial data
    .xcvr_txp(qsfp_1_tx_3_p),
    .xcvr_txn(qsfp_1_tx_3_n),
    .xcvr_rxp(qsfp_1_rx_3_p),
    .xcvr_rxn(qsfp_1_rx_3_n),

    // PHY connections
    .phy_tx_clk(qsfp_1_tx_clk_3_int),
    .phy_tx_rst(qsfp_1_tx_rst_3_int),
    .phy_xgmii_txd(qsfp_1_txd_3_int),
    .phy_xgmii_txc(qsfp_1_txc_3_int),
    .phy_rx_clk(qsfp_1_rx_clk_3_int),
    .phy_rx_rst(qsfp_1_rx_rst_3_int),
    .phy_xgmii_rxd(qsfp_1_rxd_3_int),
    .phy_xgmii_rxc(qsfp_1_rxc_3_int),
    .phy_tx_bad_block(),
    .phy_rx_error_count(qsfp_1_rx_error_count_3_int),
    .phy_rx_bad_block(),
    .phy_rx_sequence_error(),
    .phy_rx_block_lock(qsfp_1_rx_block_lock_3),
    .phy_rx_high_ber(),
    .phy_tx_prbs31_enable(qsfp_1_tx_prbs31_enable_3_int),
    .phy_rx_prbs31_enable(qsfp_1_rx_prbs31_enable_3_int)
);

assign led_green[0] = qsfp_0_rx_block_lock_0;
assign led_green[1] = qsfp_0_rx_block_lock_1;
assign led_green[2] = qsfp_0_rx_block_lock_2;
assign led_green[3] = qsfp_0_rx_block_lock_3;
assign led_green[4] = qsfp_1_rx_block_lock_0;
assign led_green[5] = qsfp_1_rx_block_lock_1;
assign led_green[6] = qsfp_1_rx_block_lock_2;
assign led_green[7] = qsfp_1_rx_block_lock_3;

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
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
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
    .clk_250mhz(pcie_user_clk),
    .rst_250mhz(pcie_user_reset),

    /*
     * GPIO
     */
    .led_red(led_red),
    //.led_green(led_green),
    .led_bmc(led_bmc),
    .led_exp(led_exp),

    .pps_in(pps_in),
    .pps_out(pps_out),
    .pps_out_en(pps_out_en),

    /*
     * BMC interface
     */
    .bmc_clk(bmc_clk),
    .bmc_nss(bmc_nss),
    .bmc_mosi(bmc_mosi),
    .bmc_miso(bmc_miso),
    .bmc_int(bmc_int),

    /*
     * PCIe
     */
    .m_axis_rq_tdata(axis_rq_tdata),
    .m_axis_rq_tkeep(axis_rq_tkeep),
    .m_axis_rq_tlast(axis_rq_tlast),
    .m_axis_rq_tready(axis_rq_tready),
    .m_axis_rq_tuser(axis_rq_tuser),
    .m_axis_rq_tvalid(axis_rq_tvalid),

    .s_axis_rc_tdata(axis_rc_tdata),
    .s_axis_rc_tkeep(axis_rc_tkeep),
    .s_axis_rc_tlast(axis_rc_tlast),
    .s_axis_rc_tready(axis_rc_tready),
    .s_axis_rc_tuser(axis_rc_tuser),
    .s_axis_rc_tvalid(axis_rc_tvalid),

    .s_axis_cq_tdata(axis_cq_tdata),
    .s_axis_cq_tkeep(axis_cq_tkeep),
    .s_axis_cq_tlast(axis_cq_tlast),
    .s_axis_cq_tready(axis_cq_tready),
    .s_axis_cq_tuser(axis_cq_tuser),
    .s_axis_cq_tvalid(axis_cq_tvalid),

    .m_axis_cc_tdata(axis_cc_tdata),
    .m_axis_cc_tkeep(axis_cc_tkeep),
    .m_axis_cc_tlast(axis_cc_tlast),
    .m_axis_cc_tready(axis_cc_tready),
    .m_axis_cc_tuser(axis_cc_tuser),
    .m_axis_cc_tvalid(axis_cc_tvalid),

    .s_axis_rq_seq_num_0(pcie_rq_seq_num0),
    .s_axis_rq_seq_num_valid_0(pcie_rq_seq_num_vld0),
    .s_axis_rq_seq_num_1(pcie_rq_seq_num1),
    .s_axis_rq_seq_num_valid_1(pcie_rq_seq_num_vld1),

    .pcie_tfc_nph_av(pcie_tfc_nph_av),
    .pcie_tfc_npd_av(pcie_tfc_npd_av),

    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),

    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_mmenable(cfg_interrupt_msi_mmenable),
    .cfg_interrupt_msi_mask_update(cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_data(cfg_interrupt_msi_data),
    .cfg_interrupt_msi_select(cfg_interrupt_msi_select),
    .cfg_interrupt_msi_int(cfg_interrupt_msi_int),
    .cfg_interrupt_msi_pending_status(cfg_interrupt_msi_pending_status),
    .cfg_interrupt_msi_pending_status_data_enable(cfg_interrupt_msi_pending_status_data_enable),
    .cfg_interrupt_msi_pending_status_function_num(cfg_interrupt_msi_pending_status_function_num),
    .cfg_interrupt_msi_sent(cfg_interrupt_msi_sent),
    .cfg_interrupt_msi_fail(cfg_interrupt_msi_fail),
    .cfg_interrupt_msi_attr(cfg_interrupt_msi_attr),
    .cfg_interrupt_msi_tph_present(cfg_interrupt_msi_tph_present),
    .cfg_interrupt_msi_tph_type(cfg_interrupt_msi_tph_type),
    .cfg_interrupt_msi_tph_st_tag(cfg_interrupt_msi_tph_st_tag),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor),

    /*
     * Ethernet: QSFP28
     */
    .qsfp_0_tx_clk_0(qsfp_0_tx_clk_0_int),
    .qsfp_0_tx_rst_0(qsfp_0_tx_rst_0_int),
    .qsfp_0_txd_0(qsfp_0_txd_0_int),
    .qsfp_0_txc_0(qsfp_0_txc_0_int),
    .qsfp_0_tx_prbs31_enable_0(qsfp_0_tx_prbs31_enable_0_int),
    .qsfp_0_rx_clk_0(qsfp_0_rx_clk_0_int),
    .qsfp_0_rx_rst_0(qsfp_0_rx_rst_0_int),
    .qsfp_0_rxd_0(qsfp_0_rxd_0_int),
    .qsfp_0_rxc_0(qsfp_0_rxc_0_int),
    .qsfp_0_rx_prbs31_enable_0(qsfp_0_rx_prbs31_enable_0_int),
    .qsfp_0_rx_error_count_0(qsfp_0_rx_error_count_0_int),
    .qsfp_0_tx_clk_1(qsfp_0_tx_clk_1_int),
    .qsfp_0_tx_rst_1(qsfp_0_tx_rst_1_int),
    .qsfp_0_txd_1(qsfp_0_txd_1_int),
    .qsfp_0_txc_1(qsfp_0_txc_1_int),
    .qsfp_0_tx_prbs31_enable_1(qsfp_0_tx_prbs31_enable_1_int),
    .qsfp_0_rx_clk_1(qsfp_0_rx_clk_1_int),
    .qsfp_0_rx_rst_1(qsfp_0_rx_rst_1_int),
    .qsfp_0_rxd_1(qsfp_0_rxd_1_int),
    .qsfp_0_rxc_1(qsfp_0_rxc_1_int),
    .qsfp_0_rx_prbs31_enable_1(qsfp_0_rx_prbs31_enable_1_int),
    .qsfp_0_rx_error_count_1(qsfp_0_rx_error_count_1_int),
    .qsfp_0_tx_clk_2(qsfp_0_tx_clk_2_int),
    .qsfp_0_tx_rst_2(qsfp_0_tx_rst_2_int),
    .qsfp_0_txd_2(qsfp_0_txd_2_int),
    .qsfp_0_txc_2(qsfp_0_txc_2_int),
    .qsfp_0_tx_prbs31_enable_2(qsfp_0_tx_prbs31_enable_2_int),
    .qsfp_0_rx_clk_2(qsfp_0_rx_clk_2_int),
    .qsfp_0_rx_rst_2(qsfp_0_rx_rst_2_int),
    .qsfp_0_rxd_2(qsfp_0_rxd_2_int),
    .qsfp_0_rxc_2(qsfp_0_rxc_2_int),
    .qsfp_0_rx_prbs31_enable_2(qsfp_0_rx_prbs31_enable_2_int),
    .qsfp_0_rx_error_count_2(qsfp_0_rx_error_count_2_int),
    .qsfp_0_tx_clk_3(qsfp_0_tx_clk_3_int),
    .qsfp_0_tx_rst_3(qsfp_0_tx_rst_3_int),
    .qsfp_0_txd_3(qsfp_0_txd_3_int),
    .qsfp_0_txc_3(qsfp_0_txc_3_int),
    .qsfp_0_tx_prbs31_enable_3(qsfp_0_tx_prbs31_enable_3_int),
    .qsfp_0_rx_clk_3(qsfp_0_rx_clk_3_int),
    .qsfp_0_rx_rst_3(qsfp_0_rx_rst_3_int),
    .qsfp_0_rxd_3(qsfp_0_rxd_3_int),
    .qsfp_0_rxc_3(qsfp_0_rxc_3_int),
    .qsfp_0_rx_prbs31_enable_3(qsfp_0_rx_prbs31_enable_3_int),
    .qsfp_0_rx_error_count_3(qsfp_0_rx_error_count_3_int),
    .qsfp_0_mod_prsnt_n(qsfp_0_mod_prsnt_n_int),
    .qsfp_0_reset_n(qsfp_0_reset_n),
    .qsfp_0_lp_mode(qsfp_0_lp_mode),
    .qsfp_0_intr_n(qsfp_0_intr_n_int),
    .qsfp_0_i2c_scl_i(qsfp_0_i2c_scl_i),
    .qsfp_0_i2c_scl_o(qsfp_0_i2c_scl_o),
    .qsfp_0_i2c_scl_t(qsfp_0_i2c_scl_t),
    .qsfp_0_i2c_sda_i(qsfp_0_i2c_sda_i),
    .qsfp_0_i2c_sda_o(qsfp_0_i2c_sda_o),
    .qsfp_0_i2c_sda_t(qsfp_0_i2c_sda_t),
    .qsfp_1_tx_clk_0(qsfp_1_tx_clk_0_int),
    .qsfp_1_tx_rst_0(qsfp_1_tx_rst_0_int),
    .qsfp_1_txd_0(qsfp_1_txd_0_int),
    .qsfp_1_txc_0(qsfp_1_txc_0_int),
    .qsfp_1_tx_prbs31_enable_0(qsfp_1_tx_prbs31_enable_0_int),
    .qsfp_1_rx_clk_0(qsfp_1_rx_clk_0_int),
    .qsfp_1_rx_rst_0(qsfp_1_rx_rst_0_int),
    .qsfp_1_rxd_0(qsfp_1_rxd_0_int),
    .qsfp_1_rxc_0(qsfp_1_rxc_0_int),
    .qsfp_1_rx_prbs31_enable_0(qsfp_1_rx_prbs31_enable_0_int),
    .qsfp_1_rx_error_count_0(qsfp_1_rx_error_count_0_int),
    .qsfp_1_tx_clk_1(qsfp_1_tx_clk_1_int),
    .qsfp_1_tx_rst_1(qsfp_1_tx_rst_1_int),
    .qsfp_1_txd_1(qsfp_1_txd_1_int),
    .qsfp_1_txc_1(qsfp_1_txc_1_int),
    .qsfp_1_tx_prbs31_enable_1(qsfp_1_tx_prbs31_enable_1_int),
    .qsfp_1_rx_clk_1(qsfp_1_rx_clk_1_int),
    .qsfp_1_rx_rst_1(qsfp_1_rx_rst_1_int),
    .qsfp_1_rxd_1(qsfp_1_rxd_1_int),
    .qsfp_1_rxc_1(qsfp_1_rxc_1_int),
    .qsfp_1_rx_prbs31_enable_1(qsfp_1_rx_prbs31_enable_1_int),
    .qsfp_1_rx_error_count_1(qsfp_1_rx_error_count_1_int),
    .qsfp_1_tx_clk_2(qsfp_1_tx_clk_2_int),
    .qsfp_1_tx_rst_2(qsfp_1_tx_rst_2_int),
    .qsfp_1_txd_2(qsfp_1_txd_2_int),
    .qsfp_1_txc_2(qsfp_1_txc_2_int),
    .qsfp_1_tx_prbs31_enable_2(qsfp_1_tx_prbs31_enable_2_int),
    .qsfp_1_rx_clk_2(qsfp_1_rx_clk_2_int),
    .qsfp_1_rx_rst_2(qsfp_1_rx_rst_2_int),
    .qsfp_1_rxd_2(qsfp_1_rxd_2_int),
    .qsfp_1_rxc_2(qsfp_1_rxc_2_int),
    .qsfp_1_rx_prbs31_enable_2(qsfp_1_rx_prbs31_enable_2_int),
    .qsfp_1_rx_error_count_2(qsfp_1_rx_error_count_2_int),
    .qsfp_1_tx_clk_3(qsfp_1_tx_clk_3_int),
    .qsfp_1_tx_rst_3(qsfp_1_tx_rst_3_int),
    .qsfp_1_txd_3(qsfp_1_txd_3_int),
    .qsfp_1_txc_3(qsfp_1_txc_3_int),
    .qsfp_1_tx_prbs31_enable_3(qsfp_1_tx_prbs31_enable_3_int),
    .qsfp_1_rx_clk_3(qsfp_1_rx_clk_3_int),
    .qsfp_1_rx_rst_3(qsfp_1_rx_rst_3_int),
    .qsfp_1_rxd_3(qsfp_1_rxd_3_int),
    .qsfp_1_rxc_3(qsfp_1_rxc_3_int),
    .qsfp_1_rx_prbs31_enable_3(qsfp_1_rx_prbs31_enable_3_int),
    .qsfp_1_rx_error_count_3(qsfp_1_rx_error_count_3_int),
    .qsfp_1_mod_prsnt_n(qsfp_1_mod_prsnt_n_int),
    .qsfp_1_reset_n(qsfp_1_reset_n),
    .qsfp_1_lp_mode(qsfp_1_lp_mode),
    .qsfp_1_intr_n(qsfp_1_intr_n_int),
    .qsfp_1_i2c_scl_i(qsfp_1_i2c_scl_i),
    .qsfp_1_i2c_scl_o(qsfp_1_i2c_scl_o),
    .qsfp_1_i2c_scl_t(qsfp_1_i2c_scl_t),
    .qsfp_1_i2c_sda_i(qsfp_1_i2c_sda_i),
    .qsfp_1_i2c_sda_o(qsfp_1_i2c_sda_o),
    .qsfp_1_i2c_sda_t(qsfp_1_i2c_sda_t),

    /*
     * QSPI flash
     */
    .fpga_boot(fpga_boot),
    .qspi_clk(qspi_clk_int),
    .qspi_dq_i(qspi_dq_i_int),
    .qspi_dq_o(qspi_dq_o_int),
    .qspi_dq_oe(qspi_dq_oe_int),
    .qspi_cs(qspi_cs_int)
);

endmodule

`resetall
