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
    parameter BOARD_ID = {16'h10ee, 16'h95f5},
    parameter BOARD_VER = {16'd0, 16'd1},
    parameter FPGA_ID = 32'h4B31093,

    // Structural configuration
    parameter IF_COUNT = 2,
    parameter PORTS_PER_IF = 1,

    // PTP configuration
    parameter PTP_PEROUT_ENABLE = 0,
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
    parameter RX_FIFO_DEPTH = 131072,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 131072,
    parameter RX_RAM_SIZE = 131072,

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
    parameter AXIS_ETH_TX_PIPELINE = 4,
    parameter AXIS_ETH_TX_FIFO_PIPELINE = 4,
    parameter AXIS_ETH_TX_TS_PIPELINE = 4,
    parameter AXIS_ETH_RX_PIPELINE = 4,
    parameter AXIS_ETH_RX_FIFO_PIPELINE = 4,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_DMA_ENABLE = 1,
    parameter STAT_PCIE_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    /*
     * GPIO
     */
    input  wire [3:0]   sw,
    output wire [2:0]   led,

    /*
     * I2C for board management
     */
    inout  wire         i2c_scl,
    inout  wire         i2c_sda,

    /*
     * PCI express
     */
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,
    input  wire         pcie_refclk_p,
    input  wire         pcie_refclk_n,
    input  wire         pcie_reset_n,

    /*
     * Ethernet: QSFP28
     */
    output wire         qsfp0_tx1_p,
    output wire         qsfp0_tx1_n,
    input  wire         qsfp0_rx1_p,
    input  wire         qsfp0_rx1_n,
    output wire         qsfp0_tx2_p,
    output wire         qsfp0_tx2_n,
    input  wire         qsfp0_rx2_p,
    input  wire         qsfp0_rx2_n,
    output wire         qsfp0_tx3_p,
    output wire         qsfp0_tx3_n,
    input  wire         qsfp0_rx3_p,
    input  wire         qsfp0_rx3_n,
    output wire         qsfp0_tx4_p,
    output wire         qsfp0_tx4_n,
    input  wire         qsfp0_rx4_p,
    input  wire         qsfp0_rx4_n,
    // input  wire         qsfp0_mgt_refclk_0_p,
    // input  wire         qsfp0_mgt_refclk_0_n,
    input  wire         qsfp0_mgt_refclk_1_p,
    input  wire         qsfp0_mgt_refclk_1_n,
    output wire         qsfp0_modsell,
    output wire         qsfp0_resetl,
    input  wire         qsfp0_modprsl,
    input  wire         qsfp0_intl,
    output wire         qsfp0_lpmode,
    output wire         qsfp0_refclk_reset,
    output wire [1:0]   qsfp0_fs,

    output wire         qsfp1_tx1_p,
    output wire         qsfp1_tx1_n,
    input  wire         qsfp1_rx1_p,
    input  wire         qsfp1_rx1_n,
    output wire         qsfp1_tx2_p,
    output wire         qsfp1_tx2_n,
    input  wire         qsfp1_rx2_p,
    input  wire         qsfp1_rx2_n,
    output wire         qsfp1_tx3_p,
    output wire         qsfp1_tx3_n,
    input  wire         qsfp1_rx3_p,
    input  wire         qsfp1_rx3_n,
    output wire         qsfp1_tx4_p,
    output wire         qsfp1_tx4_n,
    input  wire         qsfp1_rx4_p,
    input  wire         qsfp1_rx4_n,
    // input  wire         qsfp1_mgt_refclk_0_p,
    // input  wire         qsfp1_mgt_refclk_0_n,
    input  wire         qsfp1_mgt_refclk_1_p,
    input  wire         qsfp1_mgt_refclk_1_n,
    output wire         qsfp1_modsell,
    output wire         qsfp1_resetl,
    input  wire         qsfp1_modprsl,
    input  wire         qsfp1_intl,
    output wire         qsfp1_lpmode,
    output wire         qsfp1_refclk_reset,
    output wire [1:0]   qsfp1_fs
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
parameter PTP_SEPARATE_RX_CLOCK = 1;

// PCIe interface configuration
parameter MSI_COUNT = 32;

// Ethernet interface configuration
parameter AXIS_ETH_DATA_WIDTH = 512;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH;
parameter AXIS_ETH_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire pcie_user_clk;
wire pcie_user_reset;

wire cfgmclk_int;

wire clk_161mhz_ref_int;

wire clk_125mhz_mmcm_out;

// Internal 125 MHz clock
wire clk_125mhz_int;
wire rst_125mhz_int;

// Internal 156.25 MHz clock
wire clk_156mhz_int;
wire rst_156mhz_int;

wire mmcm_rst;
wire mmcm_locked;
wire mmcm_clkfb;

// MMCM instance
// 161.13 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 800 MHz to 1600 MHz
// M = 64, D = 11 sets Fvco = 937.5 MHz (in range)
// Divide by 7.5 to get output frequency of 125 MHz
MMCME4_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(7.5),
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
    .CLKFBOUT_MULT_F(64),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(11),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(6.206),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_161mhz_ref_int),
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
wire btnu_int;
wire btnl_int;
wire btnd_int;
wire btnr_int;
wire btnc_int;
wire [3:0] sw_int;
wire qsfp0_modprsl_int;
wire qsfp1_modprsl_int;
wire qsfp0_intl_int;
wire qsfp1_intl_int;
wire i2c_scl_i;
wire i2c_scl_o;
wire i2c_scl_t;
wire i2c_sda_i;
wire i2c_sda_o;
wire i2c_sda_t;

reg i2c_scl_o_reg;
reg i2c_scl_t_reg;
reg i2c_sda_o_reg;
reg i2c_sda_t_reg;

always @(posedge pcie_user_clk) begin
    i2c_scl_o_reg <= i2c_scl_o;
    i2c_scl_t_reg <= i2c_scl_t;
    i2c_sda_o_reg <= i2c_sda_o;
    i2c_sda_t_reg <= i2c_sda_t;
end

debounce_switch #(
    .WIDTH(4),
    .N(4),
    .RATE(250000)
)
debounce_switch_inst (
    .clk(pcie_user_clk),
    .rst(pcie_user_reset),
    .in({sw}),
    .out({sw_int})
);

sync_signal #(
    .WIDTH(6),
    .N(2)
)
sync_signal_inst (
    .clk(pcie_user_clk),
    .in({qsfp0_modprsl, qsfp1_modprsl, qsfp0_intl, qsfp1_intl,
        i2c_scl, i2c_sda}),
    .out({qsfp0_modprsl_int, qsfp1_modprsl_int, qsfp0_intl_int, qsfp1_intl_int,
        i2c_scl_i, i2c_sda_i})
);

assign i2c_scl = i2c_scl_t_reg ? 1'bz : i2c_scl_o_reg;
assign i2c_sda = i2c_sda_t_reg ? 1'bz : i2c_sda_o_reg;

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

// startupe3 instance
wire cfgmclk;

STARTUPE3
startupe3_inst (
    .CFGCLK(),
    .CFGMCLK(cfgmclk),
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

BUFG
cfgmclk_bufg_inst (
    .I(cfgmclk),
    .O(cfgmclk_int)
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

// configure SI5335 clock generators
reg qsfp_refclk_reset_reg = 1'b1;
reg sys_reset_reg = 1'b1;

reg [9:0] reset_timer_reg = 0;

assign mmcm_rst = sys_reset_reg | pcie_user_reset;

always @(posedge cfgmclk_int) begin
    if (&reset_timer_reg) begin
        if (qsfp_refclk_reset_reg) begin
            qsfp_refclk_reset_reg <= 1'b0;
            reset_timer_reg <= 0;
        end else begin
            qsfp_refclk_reset_reg <= 1'b0;
            sys_reset_reg <= 1'b0;
        end
    end else begin
        reset_timer_reg <= reset_timer_reg + 1;
    end
end

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
    //.cfg_ds_function_number(3'd0),

    //.cfg_subsys_vend_id(16'h1234),

    .sys_clk(pcie_sys_clk),
    .sys_clk_gt(pcie_sys_clk_gt),
    .sys_reset(pcie_reset_n),

    .phy_rdy_out()
);

// CMAC
assign qsfp0_refclk_reset = qsfp_refclk_reset_reg;
assign qsfp0_fs = 2'b10;

wire                           qsfp0_tx_clk_int;
wire                           qsfp0_tx_rst_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp0_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp0_tx_axis_tkeep_int;
wire                           qsfp0_tx_axis_tvalid_int;
wire                           qsfp0_tx_axis_tready_int;
wire                           qsfp0_tx_axis_tlast_int;
wire [16+1-1:0]                qsfp0_tx_axis_tuser_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp0_mac_tx_axis_tdata;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp0_mac_tx_axis_tkeep;
wire                           qsfp0_mac_tx_axis_tvalid;
wire                           qsfp0_mac_tx_axis_tready;
wire                           qsfp0_mac_tx_axis_tlast;
wire [16+1-1:0]                qsfp0_mac_tx_axis_tuser;

wire [79:0]                    qsfp0_tx_ptp_time_int;
wire [79:0]                    qsfp0_tx_ptp_ts_int;
wire [15:0]                    qsfp0_tx_ptp_ts_tag_int;
wire                           qsfp0_tx_ptp_ts_valid_int;

wire                           qsfp0_rx_clk_int;
wire                           qsfp0_rx_rst_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp0_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp0_rx_axis_tkeep_int;
wire                           qsfp0_rx_axis_tvalid_int;
wire                           qsfp0_rx_axis_tlast_int;
wire [80+1-1:0]                qsfp0_rx_axis_tuser_int;

wire                           qsfp0_rx_ptp_clk_int;
wire                           qsfp0_rx_ptp_rst_int;
wire [79:0]                    qsfp0_rx_ptp_time_int;

assign qsfp1_refclk_reset = qsfp_refclk_reset_reg;
assign qsfp1_fs = 2'b10;

wire                           qsfp1_tx_clk_int;
wire                           qsfp1_tx_rst_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp1_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp1_tx_axis_tkeep_int;
wire                           qsfp1_tx_axis_tvalid_int;
wire                           qsfp1_tx_axis_tready_int;
wire                           qsfp1_tx_axis_tlast_int;
wire [16+1-1:0]                qsfp1_tx_axis_tuser_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp1_mac_tx_axis_tdata;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp1_mac_tx_axis_tkeep;
wire                           qsfp1_mac_tx_axis_tvalid;
wire                           qsfp1_mac_tx_axis_tready;
wire                           qsfp1_mac_tx_axis_tlast;
wire [16+1-1:0]                qsfp1_mac_tx_axis_tuser;

wire [79:0]                    qsfp1_tx_ptp_time_int;
wire [79:0]                    qsfp1_tx_ptp_ts_int;
wire [15:0]                    qsfp1_tx_ptp_ts_tag_int;
wire                           qsfp1_tx_ptp_ts_valid_int;

wire                           qsfp1_rx_clk_int;
wire                           qsfp1_rx_rst_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp1_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp1_rx_axis_tkeep_int;
wire                           qsfp1_rx_axis_tvalid_int;
wire                           qsfp1_rx_axis_tlast_int;
wire [80+1-1:0]                qsfp1_rx_axis_tuser_int;

wire                           qsfp1_rx_ptp_clk_int;
wire                           qsfp1_rx_ptp_rst_int;
wire [79:0]                    qsfp1_rx_ptp_time_int;

wire qsfp0_rx_status;
wire qsfp1_rx_status;

wire qsfp0_txuserclk2;
wire qsfp0_rxuserclk2;

assign qsfp0_tx_clk_int = qsfp0_txuserclk2;
assign qsfp0_rx_clk_int = qsfp0_txuserclk2;
assign qsfp0_rx_ptp_clk_int = qsfp0_rxuserclk2;

wire qsfp1_txuserclk2;
wire qsfp1_rxuserclk2;

assign qsfp1_tx_clk_int = qsfp1_txuserclk2;
assign qsfp1_rx_clk_int = qsfp1_txuserclk2;
assign qsfp1_rx_ptp_clk_int = qsfp1_rxuserclk2;

sync_reset #(
    .N(4)
)
sync_reset_qsfp0_rx_ptp_rst_inst (
    .clk(qsfp0_rx_ptp_clk_int),
    .rst(qsfp0_tx_rst_int),
    .out(qsfp0_rx_ptp_rst_int)
);

sync_reset #(
    .N(4)
)
sync_reset_qsfp1_rx_ptp_rst_inst (
    .clk(qsfp1_rx_ptp_clk_int),
    .rst(qsfp1_tx_rst_int),
    .out(qsfp1_rx_ptp_rst_int)
);

cmac_pad #(
    .DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .USER_WIDTH(16+1)
)
qsfp0_cmac_pad_inst (
    .clk(qsfp0_tx_clk_int),
    .rst(qsfp0_tx_rst_int),

    .s_axis_tdata(qsfp0_tx_axis_tdata_int),
    .s_axis_tkeep(qsfp0_tx_axis_tkeep_int),
    .s_axis_tvalid(qsfp0_tx_axis_tvalid_int),
    .s_axis_tready(qsfp0_tx_axis_tready_int),
    .s_axis_tlast(qsfp0_tx_axis_tlast_int),
    .s_axis_tuser(qsfp0_tx_axis_tuser_int),

    .m_axis_tdata(qsfp0_mac_tx_axis_tdata),
    .m_axis_tkeep(qsfp0_mac_tx_axis_tkeep),
    .m_axis_tvalid(qsfp0_mac_tx_axis_tvalid),
    .m_axis_tready(qsfp0_mac_tx_axis_tready),
    .m_axis_tlast(qsfp0_mac_tx_axis_tlast),
    .m_axis_tuser(qsfp0_mac_tx_axis_tuser)
);

cmac_usplus_0
qsfp0_cmac_inst (
    .gt_rxp_in({qsfp0_rx4_p, qsfp0_rx3_p, qsfp0_rx2_p, qsfp0_rx1_p}), // input
    .gt_rxn_in({qsfp0_rx4_n, qsfp0_rx3_n, qsfp0_rx2_n, qsfp0_rx1_n}), // input
    .gt_txp_out({qsfp0_tx4_p, qsfp0_tx3_p, qsfp0_tx2_p, qsfp0_tx1_p}), // output
    .gt_txn_out({qsfp0_tx4_n, qsfp0_tx3_n, qsfp0_tx2_n, qsfp0_tx1_n}), // output
    .gt_txusrclk2(qsfp0_txuserclk2), // output
    .gt_loopback_in(12'd0), // input [11:0]
    .gt_rxrecclkout(), // output [3:0]
    .gt_powergoodout(), // output [3:0]
    .gt_ref_clk_out(clk_161mhz_ref_int), // output
    .gtwiz_reset_tx_datapath(1'b0), // input
    .gtwiz_reset_rx_datapath(1'b0), // input
    .sys_reset(rst_125mhz_int), // input
    .gt_ref_clk_p(qsfp0_mgt_refclk_1_p), // input
    .gt_ref_clk_n(qsfp0_mgt_refclk_1_n), // input
    .init_clk(clk_125mhz_int), // input

    .rx_axis_tvalid(qsfp0_rx_axis_tvalid_int), // output
    .rx_axis_tdata(qsfp0_rx_axis_tdata_int), // output [511:0]
    .rx_axis_tlast(qsfp0_rx_axis_tlast_int), // output
    .rx_axis_tkeep(qsfp0_rx_axis_tkeep_int), // output [63:0]
    .rx_axis_tuser(qsfp0_rx_axis_tuser_int[0]), // output

    .rx_otn_bip8_0(), // output [7:0]
    .rx_otn_bip8_1(), // output [7:0]
    .rx_otn_bip8_2(), // output [7:0]
    .rx_otn_bip8_3(), // output [7:0]
    .rx_otn_bip8_4(), // output [7:0]
    .rx_otn_data_0(), // output [65:0]
    .rx_otn_data_1(), // output [65:0]
    .rx_otn_data_2(), // output [65:0]
    .rx_otn_data_3(), // output [65:0]
    .rx_otn_data_4(), // output [65:0]
    .rx_otn_ena(), // output
    .rx_otn_lane0(), // output
    .rx_otn_vlmarker(), // output
    .rx_preambleout(), // output [55:0]
    .usr_rx_reset(qsfp0_rx_rst_int), // output
    .gt_rxusrclk2(qsfp0_rxuserclk2), // output

    .rx_lane_aligner_fill_0(), // output [6:0]
    .rx_lane_aligner_fill_1(), // output [6:0]
    .rx_lane_aligner_fill_10(), // output [6:0]
    .rx_lane_aligner_fill_11(), // output [6:0]
    .rx_lane_aligner_fill_12(), // output [6:0]
    .rx_lane_aligner_fill_13(), // output [6:0]
    .rx_lane_aligner_fill_14(), // output [6:0]
    .rx_lane_aligner_fill_15(), // output [6:0]
    .rx_lane_aligner_fill_16(), // output [6:0]
    .rx_lane_aligner_fill_17(), // output [6:0]
    .rx_lane_aligner_fill_18(), // output [6:0]
    .rx_lane_aligner_fill_19(), // output [6:0]
    .rx_lane_aligner_fill_2(), // output [6:0]
    .rx_lane_aligner_fill_3(), // output [6:0]
    .rx_lane_aligner_fill_4(), // output [6:0]
    .rx_lane_aligner_fill_5(), // output [6:0]
    .rx_lane_aligner_fill_6(), // output [6:0]
    .rx_lane_aligner_fill_7(), // output [6:0]
    .rx_lane_aligner_fill_8(), // output [6:0]
    .rx_lane_aligner_fill_9(), // output [6:0]
    .rx_ptp_tstamp_out(qsfp0_rx_axis_tuser_int[80:1]), // output [79:0]
    .rx_ptp_pcslane_out(), // output [4:0]
    .ctl_rx_systemtimerin(qsfp0_rx_ptp_time_int), // input [79:0]

    .stat_rx_aligned(), // output
    .stat_rx_aligned_err(), // output
    .stat_rx_bad_code(), // output [2:0]
    .stat_rx_bad_fcs(), // output [2:0]
    .stat_rx_bad_preamble(), // output
    .stat_rx_bad_sfd(), // output
    .stat_rx_bip_err_0(), // output
    .stat_rx_bip_err_1(), // output
    .stat_rx_bip_err_10(), // output
    .stat_rx_bip_err_11(), // output
    .stat_rx_bip_err_12(), // output
    .stat_rx_bip_err_13(), // output
    .stat_rx_bip_err_14(), // output
    .stat_rx_bip_err_15(), // output
    .stat_rx_bip_err_16(), // output
    .stat_rx_bip_err_17(), // output
    .stat_rx_bip_err_18(), // output
    .stat_rx_bip_err_19(), // output
    .stat_rx_bip_err_2(), // output
    .stat_rx_bip_err_3(), // output
    .stat_rx_bip_err_4(), // output
    .stat_rx_bip_err_5(), // output
    .stat_rx_bip_err_6(), // output
    .stat_rx_bip_err_7(), // output
    .stat_rx_bip_err_8(), // output
    .stat_rx_bip_err_9(), // output
    .stat_rx_block_lock(), // output [19:0]
    .stat_rx_broadcast(), // output
    .stat_rx_fragment(), // output [2:0]
    .stat_rx_framing_err_0(), // output [1:0]
    .stat_rx_framing_err_1(), // output [1:0]
    .stat_rx_framing_err_10(), // output [1:0]
    .stat_rx_framing_err_11(), // output [1:0]
    .stat_rx_framing_err_12(), // output [1:0]
    .stat_rx_framing_err_13(), // output [1:0]
    .stat_rx_framing_err_14(), // output [1:0]
    .stat_rx_framing_err_15(), // output [1:0]
    .stat_rx_framing_err_16(), // output [1:0]
    .stat_rx_framing_err_17(), // output [1:0]
    .stat_rx_framing_err_18(), // output [1:0]
    .stat_rx_framing_err_19(), // output [1:0]
    .stat_rx_framing_err_2(), // output [1:0]
    .stat_rx_framing_err_3(), // output [1:0]
    .stat_rx_framing_err_4(), // output [1:0]
    .stat_rx_framing_err_5(), // output [1:0]
    .stat_rx_framing_err_6(), // output [1:0]
    .stat_rx_framing_err_7(), // output [1:0]
    .stat_rx_framing_err_8(), // output [1:0]
    .stat_rx_framing_err_9(), // output [1:0]
    .stat_rx_framing_err_valid_0(), // output
    .stat_rx_framing_err_valid_1(), // output
    .stat_rx_framing_err_valid_10(), // output
    .stat_rx_framing_err_valid_11(), // output
    .stat_rx_framing_err_valid_12(), // output
    .stat_rx_framing_err_valid_13(), // output
    .stat_rx_framing_err_valid_14(), // output
    .stat_rx_framing_err_valid_15(), // output
    .stat_rx_framing_err_valid_16(), // output
    .stat_rx_framing_err_valid_17(), // output
    .stat_rx_framing_err_valid_18(), // output
    .stat_rx_framing_err_valid_19(), // output
    .stat_rx_framing_err_valid_2(), // output
    .stat_rx_framing_err_valid_3(), // output
    .stat_rx_framing_err_valid_4(), // output
    .stat_rx_framing_err_valid_5(), // output
    .stat_rx_framing_err_valid_6(), // output
    .stat_rx_framing_err_valid_7(), // output
    .stat_rx_framing_err_valid_8(), // output
    .stat_rx_framing_err_valid_9(), // output
    .stat_rx_got_signal_os(), // output
    .stat_rx_hi_ber(), // output
    .stat_rx_inrangeerr(), // output
    .stat_rx_internal_local_fault(), // output
    .stat_rx_jabber(), // output
    .stat_rx_local_fault(), // output
    .stat_rx_mf_err(), // output [19:0]
    .stat_rx_mf_len_err(), // output [19:0]
    .stat_rx_mf_repeat_err(), // output [19:0]
    .stat_rx_misaligned(), // output
    .stat_rx_multicast(), // output
    .stat_rx_oversize(), // output
    .stat_rx_packet_1024_1518_bytes(), // output
    .stat_rx_packet_128_255_bytes(), // output
    .stat_rx_packet_1519_1522_bytes(), // output
    .stat_rx_packet_1523_1548_bytes(), // output
    .stat_rx_packet_1549_2047_bytes(), // output
    .stat_rx_packet_2048_4095_bytes(), // output
    .stat_rx_packet_256_511_bytes(), // output
    .stat_rx_packet_4096_8191_bytes(), // output
    .stat_rx_packet_512_1023_bytes(), // output
    .stat_rx_packet_64_bytes(), // output
    .stat_rx_packet_65_127_bytes(), // output
    .stat_rx_packet_8192_9215_bytes(), // output
    .stat_rx_packet_bad_fcs(), // output
    .stat_rx_packet_large(), // output
    .stat_rx_packet_small(), // output [2:0]

    .ctl_rx_enable(1'b1), // input
    .ctl_rx_force_resync(1'b0), // input
    .ctl_rx_test_pattern(1'b0), // input
    .ctl_rsfec_ieee_error_indication_mode(1'b0), // input
    .ctl_rx_rsfec_enable(1'b1), // input
    .ctl_rx_rsfec_enable_correction(1'b1), // input
    .ctl_rx_rsfec_enable_indication(1'b1), // input
    .core_rx_reset(1'b0), // input
    .rx_clk(qsfp0_rx_clk_int), // input

    .stat_rx_received_local_fault(), // output
    .stat_rx_remote_fault(), // output
    .stat_rx_status(qsfp0_rx_status), // output
    .stat_rx_stomped_fcs(), // output [2:0]
    .stat_rx_synced(), // output [19:0]
    .stat_rx_synced_err(), // output [19:0]
    .stat_rx_test_pattern_mismatch(), // output [2:0]
    .stat_rx_toolong(), // output
    .stat_rx_total_bytes(), // output [6:0]
    .stat_rx_total_good_bytes(), // output [13:0]
    .stat_rx_total_good_packets(), // output
    .stat_rx_total_packets(), // output [2:0]
    .stat_rx_truncated(), // output
    .stat_rx_undersize(), // output [2:0]
    .stat_rx_unicast(), // output
    .stat_rx_vlan(), // output
    .stat_rx_pcsl_demuxed(), // output [19:0]
    .stat_rx_pcsl_number_0(), // output [4:0]
    .stat_rx_pcsl_number_1(), // output [4:0]
    .stat_rx_pcsl_number_10(), // output [4:0]
    .stat_rx_pcsl_number_11(), // output [4:0]
    .stat_rx_pcsl_number_12(), // output [4:0]
    .stat_rx_pcsl_number_13(), // output [4:0]
    .stat_rx_pcsl_number_14(), // output [4:0]
    .stat_rx_pcsl_number_15(), // output [4:0]
    .stat_rx_pcsl_number_16(), // output [4:0]
    .stat_rx_pcsl_number_17(), // output [4:0]
    .stat_rx_pcsl_number_18(), // output [4:0]
    .stat_rx_pcsl_number_19(), // output [4:0]
    .stat_rx_pcsl_number_2(), // output [4:0]
    .stat_rx_pcsl_number_3(), // output [4:0]
    .stat_rx_pcsl_number_4(), // output [4:0]
    .stat_rx_pcsl_number_5(), // output [4:0]
    .stat_rx_pcsl_number_6(), // output [4:0]
    .stat_rx_pcsl_number_7(), // output [4:0]
    .stat_rx_pcsl_number_8(), // output [4:0]
    .stat_rx_pcsl_number_9(), // output [4:0]
    .stat_rx_rsfec_am_lock0(), // output
    .stat_rx_rsfec_am_lock1(), // output
    .stat_rx_rsfec_am_lock2(), // output
    .stat_rx_rsfec_am_lock3(), // output
    .stat_rx_rsfec_corrected_cw_inc(), // output
    .stat_rx_rsfec_cw_inc(), // output
    .stat_rx_rsfec_err_count0_inc(), // output [2:0]
    .stat_rx_rsfec_err_count1_inc(), // output [2:0]
    .stat_rx_rsfec_err_count2_inc(), // output [2:0]
    .stat_rx_rsfec_err_count3_inc(), // output [2:0]
    .stat_rx_rsfec_hi_ser(), // output
    .stat_rx_rsfec_lane_alignment_status(), // output
    .stat_rx_rsfec_lane_fill_0(), // output [13:0]
    .stat_rx_rsfec_lane_fill_1(), // output [13:0]
    .stat_rx_rsfec_lane_fill_2(), // output [13:0]
    .stat_rx_rsfec_lane_fill_3(), // output [13:0]
    .stat_rx_rsfec_lane_mapping(), // output [7:0]
    .stat_rx_rsfec_uncorrected_cw_inc(), // output

    .ctl_tx_systemtimerin(qsfp0_tx_ptp_time_int), // input [79:0]

    .stat_tx_ptp_fifo_read_error(), // output
    .stat_tx_ptp_fifo_write_error(), // output

    .tx_ptp_tstamp_valid_out(qsfp0_tx_ptp_ts_valid_int), // output
    .tx_ptp_pcslane_out(), // output [4:0]
    .tx_ptp_tstamp_tag_out(qsfp0_tx_ptp_ts_tag_int), // output [15:0]
    .tx_ptp_tstamp_out(qsfp0_tx_ptp_ts_int), // output [79:0]
    .tx_ptp_1588op_in(2'b10), // input [1:0]
    .tx_ptp_tag_field_in(qsfp0_mac_tx_axis_tuser[16:1]), // input [15:0]

    .stat_tx_bad_fcs(), // output
    .stat_tx_broadcast(), // output
    .stat_tx_frame_error(), // output
    .stat_tx_local_fault(), // output
    .stat_tx_multicast(), // output
    .stat_tx_packet_1024_1518_bytes(), // output
    .stat_tx_packet_128_255_bytes(), // output
    .stat_tx_packet_1519_1522_bytes(), // output
    .stat_tx_packet_1523_1548_bytes(), // output
    .stat_tx_packet_1549_2047_bytes(), // output
    .stat_tx_packet_2048_4095_bytes(), // output
    .stat_tx_packet_256_511_bytes(), // output
    .stat_tx_packet_4096_8191_bytes(), // output
    .stat_tx_packet_512_1023_bytes(), // output
    .stat_tx_packet_64_bytes(), // output
    .stat_tx_packet_65_127_bytes(), // output
    .stat_tx_packet_8192_9215_bytes(), // output
    .stat_tx_packet_large(), // output
    .stat_tx_packet_small(), // output
    .stat_tx_total_bytes(), // output [5:0]
    .stat_tx_total_good_bytes(), // output [13:0]
    .stat_tx_total_good_packets(), // output
    .stat_tx_total_packets(), // output
    .stat_tx_unicast(), // output
    .stat_tx_vlan(), // output

    .ctl_tx_enable(1'b1), // input
    .ctl_tx_test_pattern(1'b0), // input
    .ctl_tx_rsfec_enable(1'b1), // input
    .ctl_tx_send_idle(1'b0), // input
    .ctl_tx_send_rfi(1'b0), // input
    .ctl_tx_send_lfi(1'b0), // input
    .core_tx_reset(1'b0), // input

    .tx_axis_tready(qsfp0_mac_tx_axis_tready), // output
    .tx_axis_tvalid(qsfp0_mac_tx_axis_tvalid), // input
    .tx_axis_tdata(qsfp0_mac_tx_axis_tdata), // input [511:0]
    .tx_axis_tlast(qsfp0_mac_tx_axis_tlast), // input
    .tx_axis_tkeep(qsfp0_mac_tx_axis_tkeep), // input [63:0]
    .tx_axis_tuser(qsfp0_mac_tx_axis_tuser[0]), // input

    .tx_ovfout(), // output
    .tx_unfout(), // output
    .tx_preamblein(56'd0), // input [55:0]
    .usr_tx_reset(qsfp0_tx_rst_int), // output

    .core_drp_reset(1'b0), // input
    .drp_clk(1'b0), // input
    .drp_addr(10'd0), // input [9:0]
    .drp_di(16'd0), // input [15:0]
    .drp_en(1'b0), // input
    .drp_do(), // output [15:0]
    .drp_rdy(), // output
    .drp_we(1'b0) // input
);

cmac_pad #(
    .DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .USER_WIDTH(16+1)
)
qsfp1_cmac_pad_inst (
    .clk(qsfp1_tx_clk_int),
    .rst(qsfp1_tx_rst_int),

    .s_axis_tdata(qsfp1_tx_axis_tdata_int),
    .s_axis_tkeep(qsfp1_tx_axis_tkeep_int),
    .s_axis_tvalid(qsfp1_tx_axis_tvalid_int),
    .s_axis_tready(qsfp1_tx_axis_tready_int),
    .s_axis_tlast(qsfp1_tx_axis_tlast_int),
    .s_axis_tuser(qsfp1_tx_axis_tuser_int),

    .m_axis_tdata(qsfp1_mac_tx_axis_tdata),
    .m_axis_tkeep(qsfp1_mac_tx_axis_tkeep),
    .m_axis_tvalid(qsfp1_mac_tx_axis_tvalid),
    .m_axis_tready(qsfp1_mac_tx_axis_tready),
    .m_axis_tlast(qsfp1_mac_tx_axis_tlast),
    .m_axis_tuser(qsfp1_mac_tx_axis_tuser)
);

cmac_usplus_1
qsfp1_cmac_inst (
    .gt_rxp_in({qsfp1_rx4_p, qsfp1_rx3_p, qsfp1_rx2_p, qsfp1_rx1_p}), // input
    .gt_rxn_in({qsfp1_rx4_n, qsfp1_rx3_n, qsfp1_rx2_n, qsfp1_rx1_n}), // input
    .gt_txp_out({qsfp1_tx4_p, qsfp1_tx3_p, qsfp1_tx2_p, qsfp1_tx1_p}), // output
    .gt_txn_out({qsfp1_tx4_n, qsfp1_tx3_n, qsfp1_tx2_n, qsfp1_tx1_n}), // output
    .gt_txusrclk2(qsfp1_txuserclk2), // output
    .gt_loopback_in(12'd0), // input [11:0]
    .gt_rxrecclkout(), // output [3:0]
    .gt_powergoodout(), // output [3:0]
    .gt_ref_clk_out(), // output
    .gtwiz_reset_tx_datapath(1'b0), // input
    .gtwiz_reset_rx_datapath(1'b0), // input
    .sys_reset(rst_125mhz_int), // input
    .gt_ref_clk_p(qsfp1_mgt_refclk_1_p), // input
    .gt_ref_clk_n(qsfp1_mgt_refclk_1_n), // input
    .init_clk(clk_125mhz_int), // input

    .rx_axis_tvalid(qsfp1_rx_axis_tvalid_int), // output
    .rx_axis_tdata(qsfp1_rx_axis_tdata_int), // output [511:0]
    .rx_axis_tlast(qsfp1_rx_axis_tlast_int), // output
    .rx_axis_tkeep(qsfp1_rx_axis_tkeep_int), // output [63:0]
    .rx_axis_tuser(qsfp1_rx_axis_tuser_int[0]), // output

    .rx_otn_bip8_0(), // output [7:0]
    .rx_otn_bip8_1(), // output [7:0]
    .rx_otn_bip8_2(), // output [7:0]
    .rx_otn_bip8_3(), // output [7:0]
    .rx_otn_bip8_4(), // output [7:0]
    .rx_otn_data_0(), // output [65:0]
    .rx_otn_data_1(), // output [65:0]
    .rx_otn_data_2(), // output [65:0]
    .rx_otn_data_3(), // output [65:0]
    .rx_otn_data_4(), // output [65:0]
    .rx_otn_ena(), // output
    .rx_otn_lane0(), // output
    .rx_otn_vlmarker(), // output
    .rx_preambleout(), // output [55:0]
    .usr_rx_reset(qsfp1_rx_rst_int), // output
    .gt_rxusrclk2(qsfp1_rxuserclk2), // output

    .rx_lane_aligner_fill_0(), // output [6:0]
    .rx_lane_aligner_fill_1(), // output [6:0]
    .rx_lane_aligner_fill_10(), // output [6:0]
    .rx_lane_aligner_fill_11(), // output [6:0]
    .rx_lane_aligner_fill_12(), // output [6:0]
    .rx_lane_aligner_fill_13(), // output [6:0]
    .rx_lane_aligner_fill_14(), // output [6:0]
    .rx_lane_aligner_fill_15(), // output [6:0]
    .rx_lane_aligner_fill_16(), // output [6:0]
    .rx_lane_aligner_fill_17(), // output [6:0]
    .rx_lane_aligner_fill_18(), // output [6:0]
    .rx_lane_aligner_fill_19(), // output [6:0]
    .rx_lane_aligner_fill_2(), // output [6:0]
    .rx_lane_aligner_fill_3(), // output [6:0]
    .rx_lane_aligner_fill_4(), // output [6:0]
    .rx_lane_aligner_fill_5(), // output [6:0]
    .rx_lane_aligner_fill_6(), // output [6:0]
    .rx_lane_aligner_fill_7(), // output [6:0]
    .rx_lane_aligner_fill_8(), // output [6:0]
    .rx_lane_aligner_fill_9(), // output [6:0]
    .rx_ptp_tstamp_out(qsfp1_rx_axis_tuser_int[80:1]), // output [79:0]
    .rx_ptp_pcslane_out(), // output [4:0]
    .ctl_rx_systemtimerin(qsfp1_rx_ptp_time_int), // input [79:0]

    .stat_rx_aligned(), // output
    .stat_rx_aligned_err(), // output
    .stat_rx_bad_code(), // output [2:0]
    .stat_rx_bad_fcs(), // output [2:0]
    .stat_rx_bad_preamble(), // output
    .stat_rx_bad_sfd(), // output
    .stat_rx_bip_err_0(), // output
    .stat_rx_bip_err_1(), // output
    .stat_rx_bip_err_10(), // output
    .stat_rx_bip_err_11(), // output
    .stat_rx_bip_err_12(), // output
    .stat_rx_bip_err_13(), // output
    .stat_rx_bip_err_14(), // output
    .stat_rx_bip_err_15(), // output
    .stat_rx_bip_err_16(), // output
    .stat_rx_bip_err_17(), // output
    .stat_rx_bip_err_18(), // output
    .stat_rx_bip_err_19(), // output
    .stat_rx_bip_err_2(), // output
    .stat_rx_bip_err_3(), // output
    .stat_rx_bip_err_4(), // output
    .stat_rx_bip_err_5(), // output
    .stat_rx_bip_err_6(), // output
    .stat_rx_bip_err_7(), // output
    .stat_rx_bip_err_8(), // output
    .stat_rx_bip_err_9(), // output
    .stat_rx_block_lock(), // output [19:0]
    .stat_rx_broadcast(), // output
    .stat_rx_fragment(), // output [2:0]
    .stat_rx_framing_err_0(), // output [1:0]
    .stat_rx_framing_err_1(), // output [1:0]
    .stat_rx_framing_err_10(), // output [1:0]
    .stat_rx_framing_err_11(), // output [1:0]
    .stat_rx_framing_err_12(), // output [1:0]
    .stat_rx_framing_err_13(), // output [1:0]
    .stat_rx_framing_err_14(), // output [1:0]
    .stat_rx_framing_err_15(), // output [1:0]
    .stat_rx_framing_err_16(), // output [1:0]
    .stat_rx_framing_err_17(), // output [1:0]
    .stat_rx_framing_err_18(), // output [1:0]
    .stat_rx_framing_err_19(), // output [1:0]
    .stat_rx_framing_err_2(), // output [1:0]
    .stat_rx_framing_err_3(), // output [1:0]
    .stat_rx_framing_err_4(), // output [1:0]
    .stat_rx_framing_err_5(), // output [1:0]
    .stat_rx_framing_err_6(), // output [1:0]
    .stat_rx_framing_err_7(), // output [1:0]
    .stat_rx_framing_err_8(), // output [1:0]
    .stat_rx_framing_err_9(), // output [1:0]
    .stat_rx_framing_err_valid_0(), // output
    .stat_rx_framing_err_valid_1(), // output
    .stat_rx_framing_err_valid_10(), // output
    .stat_rx_framing_err_valid_11(), // output
    .stat_rx_framing_err_valid_12(), // output
    .stat_rx_framing_err_valid_13(), // output
    .stat_rx_framing_err_valid_14(), // output
    .stat_rx_framing_err_valid_15(), // output
    .stat_rx_framing_err_valid_16(), // output
    .stat_rx_framing_err_valid_17(), // output
    .stat_rx_framing_err_valid_18(), // output
    .stat_rx_framing_err_valid_19(), // output
    .stat_rx_framing_err_valid_2(), // output
    .stat_rx_framing_err_valid_3(), // output
    .stat_rx_framing_err_valid_4(), // output
    .stat_rx_framing_err_valid_5(), // output
    .stat_rx_framing_err_valid_6(), // output
    .stat_rx_framing_err_valid_7(), // output
    .stat_rx_framing_err_valid_8(), // output
    .stat_rx_framing_err_valid_9(), // output
    .stat_rx_got_signal_os(), // output
    .stat_rx_hi_ber(), // output
    .stat_rx_inrangeerr(), // output
    .stat_rx_internal_local_fault(), // output
    .stat_rx_jabber(), // output
    .stat_rx_local_fault(), // output
    .stat_rx_mf_err(), // output [19:0]
    .stat_rx_mf_len_err(), // output [19:0]
    .stat_rx_mf_repeat_err(), // output [19:0]
    .stat_rx_misaligned(), // output
    .stat_rx_multicast(), // output
    .stat_rx_oversize(), // output
    .stat_rx_packet_1024_1518_bytes(), // output
    .stat_rx_packet_128_255_bytes(), // output
    .stat_rx_packet_1519_1522_bytes(), // output
    .stat_rx_packet_1523_1548_bytes(), // output
    .stat_rx_packet_1549_2047_bytes(), // output
    .stat_rx_packet_2048_4095_bytes(), // output
    .stat_rx_packet_256_511_bytes(), // output
    .stat_rx_packet_4096_8191_bytes(), // output
    .stat_rx_packet_512_1023_bytes(), // output
    .stat_rx_packet_64_bytes(), // output
    .stat_rx_packet_65_127_bytes(), // output
    .stat_rx_packet_8192_9215_bytes(), // output
    .stat_rx_packet_bad_fcs(), // output
    .stat_rx_packet_large(), // output
    .stat_rx_packet_small(), // output [2:0]

    .ctl_rx_enable(1'b1), // input
    .ctl_rx_force_resync(1'b0), // input
    .ctl_rx_test_pattern(1'b0), // input
    .ctl_rsfec_ieee_error_indication_mode(1'b0), // input
    .ctl_rx_rsfec_enable(1'b1), // input
    .ctl_rx_rsfec_enable_correction(1'b1), // input
    .ctl_rx_rsfec_enable_indication(1'b1), // input
    .core_rx_reset(1'b0), // input
    .rx_clk(qsfp1_rx_clk_int), // input

    .stat_rx_received_local_fault(), // output
    .stat_rx_remote_fault(), // output
    .stat_rx_status(qsfp1_rx_status), // output
    .stat_rx_stomped_fcs(), // output [2:0]
    .stat_rx_synced(), // output [19:0]
    .stat_rx_synced_err(), // output [19:0]
    .stat_rx_test_pattern_mismatch(), // output [2:0]
    .stat_rx_toolong(), // output
    .stat_rx_total_bytes(), // output [6:0]
    .stat_rx_total_good_bytes(), // output [13:0]
    .stat_rx_total_good_packets(), // output
    .stat_rx_total_packets(), // output [2:0]
    .stat_rx_truncated(), // output
    .stat_rx_undersize(), // output [2:0]
    .stat_rx_unicast(), // output
    .stat_rx_vlan(), // output
    .stat_rx_pcsl_demuxed(), // output [19:0]
    .stat_rx_pcsl_number_0(), // output [4:0]
    .stat_rx_pcsl_number_1(), // output [4:0]
    .stat_rx_pcsl_number_10(), // output [4:0]
    .stat_rx_pcsl_number_11(), // output [4:0]
    .stat_rx_pcsl_number_12(), // output [4:0]
    .stat_rx_pcsl_number_13(), // output [4:0]
    .stat_rx_pcsl_number_14(), // output [4:0]
    .stat_rx_pcsl_number_15(), // output [4:0]
    .stat_rx_pcsl_number_16(), // output [4:0]
    .stat_rx_pcsl_number_17(), // output [4:0]
    .stat_rx_pcsl_number_18(), // output [4:0]
    .stat_rx_pcsl_number_19(), // output [4:0]
    .stat_rx_pcsl_number_2(), // output [4:0]
    .stat_rx_pcsl_number_3(), // output [4:0]
    .stat_rx_pcsl_number_4(), // output [4:0]
    .stat_rx_pcsl_number_5(), // output [4:0]
    .stat_rx_pcsl_number_6(), // output [4:0]
    .stat_rx_pcsl_number_7(), // output [4:0]
    .stat_rx_pcsl_number_8(), // output [4:0]
    .stat_rx_pcsl_number_9(), // output [4:0]
    .stat_rx_rsfec_am_lock0(), // output
    .stat_rx_rsfec_am_lock1(), // output
    .stat_rx_rsfec_am_lock2(), // output
    .stat_rx_rsfec_am_lock3(), // output
    .stat_rx_rsfec_corrected_cw_inc(), // output
    .stat_rx_rsfec_cw_inc(), // output
    .stat_rx_rsfec_err_count0_inc(), // output [2:0]
    .stat_rx_rsfec_err_count1_inc(), // output [2:0]
    .stat_rx_rsfec_err_count2_inc(), // output [2:0]
    .stat_rx_rsfec_err_count3_inc(), // output [2:0]
    .stat_rx_rsfec_hi_ser(), // output
    .stat_rx_rsfec_lane_alignment_status(), // output
    .stat_rx_rsfec_lane_fill_0(), // output [13:0]
    .stat_rx_rsfec_lane_fill_1(), // output [13:0]
    .stat_rx_rsfec_lane_fill_2(), // output [13:0]
    .stat_rx_rsfec_lane_fill_3(), // output [13:0]
    .stat_rx_rsfec_lane_mapping(), // output [7:0]
    .stat_rx_rsfec_uncorrected_cw_inc(), // output

    .ctl_tx_systemtimerin(qsfp1_tx_ptp_time_int), // input [79:0]

    .stat_tx_ptp_fifo_read_error(), // output
    .stat_tx_ptp_fifo_write_error(), // output

    .tx_ptp_tstamp_valid_out(qsfp1_tx_ptp_ts_valid_int), // output
    .tx_ptp_pcslane_out(), // output [4:0]
    .tx_ptp_tstamp_tag_out(qsfp1_tx_ptp_ts_tag_int), // output [15:0]
    .tx_ptp_tstamp_out(qsfp1_tx_ptp_ts_int), // output [79:0]
    .tx_ptp_1588op_in(2'b10), // input [1:0]
    .tx_ptp_tag_field_in(qsfp1_mac_tx_axis_tuser[16:1]), // input [15:0]

    .stat_tx_bad_fcs(), // output
    .stat_tx_broadcast(), // output
    .stat_tx_frame_error(), // output
    .stat_tx_local_fault(), // output
    .stat_tx_multicast(), // output
    .stat_tx_packet_1024_1518_bytes(), // output
    .stat_tx_packet_128_255_bytes(), // output
    .stat_tx_packet_1519_1522_bytes(), // output
    .stat_tx_packet_1523_1548_bytes(), // output
    .stat_tx_packet_1549_2047_bytes(), // output
    .stat_tx_packet_2048_4095_bytes(), // output
    .stat_tx_packet_256_511_bytes(), // output
    .stat_tx_packet_4096_8191_bytes(), // output
    .stat_tx_packet_512_1023_bytes(), // output
    .stat_tx_packet_64_bytes(), // output
    .stat_tx_packet_65_127_bytes(), // output
    .stat_tx_packet_8192_9215_bytes(), // output
    .stat_tx_packet_large(), // output
    .stat_tx_packet_small(), // output
    .stat_tx_total_bytes(), // output [5:0]
    .stat_tx_total_good_bytes(), // output [13:0]
    .stat_tx_total_good_packets(), // output
    .stat_tx_total_packets(), // output
    .stat_tx_unicast(), // output
    .stat_tx_vlan(), // output

    .ctl_tx_enable(1'b1), // input
    .ctl_tx_test_pattern(1'b0), // input
    .ctl_tx_rsfec_enable(1'b1), // input
    .ctl_tx_send_idle(1'b0), // input
    .ctl_tx_send_rfi(1'b0), // input
    .ctl_tx_send_lfi(1'b0), // input
    .core_tx_reset(1'b0), // input

    .tx_axis_tready(qsfp1_mac_tx_axis_tready), // output
    .tx_axis_tvalid(qsfp1_mac_tx_axis_tvalid), // input
    .tx_axis_tdata(qsfp1_mac_tx_axis_tdata), // input [511:0]
    .tx_axis_tlast(qsfp1_mac_tx_axis_tlast), // input
    .tx_axis_tkeep(qsfp1_mac_tx_axis_tkeep), // input [63:0]
    .tx_axis_tuser(qsfp1_mac_tx_axis_tuser[0]), // input

    .tx_ovfout(), // output
    .tx_unfout(), // output
    .tx_preamblein(56'd0), // input [55:0]
    .usr_tx_reset(qsfp1_tx_rst_int), // output

    .core_drp_reset(1'b0), // input
    .drp_clk(1'b0), // input
    .drp_addr(10'd0), // input [9:0]
    .drp_di(16'd0), // input [15:0]
    .drp_en(1'b0), // input
    .drp_do(), // output [15:0]
    .drp_rdy(), // output
    .drp_we(1'b0) // input
);

wire [2:0] led_int;

assign led[0] = led_int[0]; // red
assign led[1] = qsfp1_rx_status; // yellow
assign led[2] = qsfp0_rx_status; // green

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
    .PTP_SEPARATE_RX_CLOCK(PTP_SEPARATE_RX_CLOCK),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

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
    .sw(sw_int),
    .led(led_int),

    /*
     * I2C
     */
    .i2c_scl_i(i2c_scl_i),
    .i2c_scl_o(i2c_scl_o),
    .i2c_scl_t(i2c_scl_t),
    .i2c_sda_i(i2c_sda_i),
    .i2c_sda_o(i2c_sda_o),
    .i2c_sda_t(i2c_sda_t),

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
    .qsfp0_tx_clk(qsfp0_tx_clk_int),
    .qsfp0_tx_rst(qsfp0_tx_rst_int),
    .qsfp0_tx_axis_tdata(qsfp0_tx_axis_tdata_int),
    .qsfp0_tx_axis_tkeep(qsfp0_tx_axis_tkeep_int),
    .qsfp0_tx_axis_tvalid(qsfp0_tx_axis_tvalid_int),
    .qsfp0_tx_axis_tready(qsfp0_tx_axis_tready_int),
    .qsfp0_tx_axis_tlast(qsfp0_tx_axis_tlast_int),
    .qsfp0_tx_axis_tuser(qsfp0_tx_axis_tuser_int),
    .qsfp0_tx_ptp_time(qsfp0_tx_ptp_time_int),
    .qsfp0_tx_ptp_ts(qsfp0_tx_ptp_ts_int),
    .qsfp0_tx_ptp_ts_tag(qsfp0_tx_ptp_ts_tag_int),
    .qsfp0_tx_ptp_ts_valid(qsfp0_tx_ptp_ts_valid_int),
    .qsfp0_rx_clk(qsfp0_rx_clk_int),
    .qsfp0_rx_rst(qsfp0_rx_rst_int),
    .qsfp0_rx_axis_tdata(qsfp0_rx_axis_tdata_int),
    .qsfp0_rx_axis_tkeep(qsfp0_rx_axis_tkeep_int),
    .qsfp0_rx_axis_tvalid(qsfp0_rx_axis_tvalid_int),
    .qsfp0_rx_axis_tlast(qsfp0_rx_axis_tlast_int),
    .qsfp0_rx_axis_tuser(qsfp0_rx_axis_tuser_int),
    .qsfp0_rx_ptp_clk(qsfp0_rx_ptp_clk_int),
    .qsfp0_rx_ptp_rst(qsfp0_rx_ptp_rst_int),
    .qsfp0_rx_ptp_time(qsfp0_rx_ptp_time_int),
    .qsfp0_modprsl(qsfp0_modprsl_int),
    .qsfp0_modsell(qsfp0_modsell),
    .qsfp0_resetl(qsfp0_resetl),
    .qsfp0_intl(qsfp0_intl_int),
    .qsfp0_lpmode(qsfp0_lpmode),

    .qsfp1_tx_clk(qsfp1_tx_clk_int),
    .qsfp1_tx_rst(qsfp1_tx_rst_int),
    .qsfp1_tx_axis_tdata(qsfp1_tx_axis_tdata_int),
    .qsfp1_tx_axis_tkeep(qsfp1_tx_axis_tkeep_int),
    .qsfp1_tx_axis_tvalid(qsfp1_tx_axis_tvalid_int),
    .qsfp1_tx_axis_tready(qsfp1_tx_axis_tready_int),
    .qsfp1_tx_axis_tlast(qsfp1_tx_axis_tlast_int),
    .qsfp1_tx_axis_tuser(qsfp1_tx_axis_tuser_int),
    .qsfp1_tx_ptp_time(qsfp1_tx_ptp_time_int),
    .qsfp1_tx_ptp_ts(qsfp1_tx_ptp_ts_int),
    .qsfp1_tx_ptp_ts_tag(qsfp1_tx_ptp_ts_tag_int),
    .qsfp1_tx_ptp_ts_valid(qsfp1_tx_ptp_ts_valid_int),
    .qsfp1_rx_clk(qsfp1_rx_clk_int),
    .qsfp1_rx_rst(qsfp1_rx_rst_int),
    .qsfp1_rx_axis_tdata(qsfp1_rx_axis_tdata_int),
    .qsfp1_rx_axis_tkeep(qsfp1_rx_axis_tkeep_int),
    .qsfp1_rx_axis_tvalid(qsfp1_rx_axis_tvalid_int),
    .qsfp1_rx_axis_tlast(qsfp1_rx_axis_tlast_int),
    .qsfp1_rx_axis_tuser(qsfp1_rx_axis_tuser_int),
    .qsfp1_rx_ptp_clk(qsfp1_rx_ptp_clk_int),
    .qsfp1_rx_ptp_rst(qsfp1_rx_ptp_rst_int),
    .qsfp1_rx_ptp_time(qsfp1_rx_ptp_time_int),
    .qsfp1_modprsl(qsfp1_modprsl_int),
    .qsfp1_modsell(qsfp1_modsell),
    .qsfp1_resetl(qsfp1_resetl),
    .qsfp1_intl(qsfp1_intl_int),
    .qsfp1_lpmode(qsfp1_lpmode),

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
