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
    parameter FPGA_ID = 32'h4B7D093,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h10ee_9118,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

    // Structural configuration
    parameter IF_COUNT = 2,
    parameter PORTS_PER_IF = 1,
    parameter SCHED_PER_IF = PORTS_PER_IF,
    parameter PORT_MASK = 0,

    // Clock configuration
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,

    // PTP configuration
    parameter PTP_CLOCK_PIPELINE = 1,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_PORT_CDC_PIPELINE = 1,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = TX_QUEUE_OP_TABLE_SIZE,
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = RX_QUEUE_OP_TABLE_SIZE,
    parameter EVENT_QUEUE_INDEX_WIDTH = 5,
    parameter TX_QUEUE_INDEX_WIDTH = 13,
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter TX_CPL_QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH,
    parameter RX_CPL_QUEUE_INDEX_WIDTH = RX_QUEUE_INDEX_WIDTH,
    parameter EVENT_QUEUE_PIPELINE = 3,
    parameter TX_QUEUE_PIPELINE = 3+(TX_QUEUE_INDEX_WIDTH > 12 ? TX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter RX_QUEUE_PIPELINE = 3+(RX_QUEUE_INDEX_WIDTH > 12 ? RX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter TX_CPL_QUEUE_PIPELINE = TX_QUEUE_PIPELINE,
    parameter RX_CPL_QUEUE_PIPELINE = RX_QUEUE_PIPELINE,

    // TX and RX engine configuration
    parameter TX_DESC_TABLE_SIZE = 32,
    parameter RX_DESC_TABLE_SIZE = 32,

    // Scheduler configuration
    parameter TX_SCHEDULER_OP_TABLE_SIZE = TX_DESC_TABLE_SIZE,
    parameter TX_SCHEDULER_PIPELINE = TX_QUEUE_PIPELINE,
    parameter TDMA_INDEX_WIDTH = 6,

    // Interface configuration
    parameter PTP_TS_ENABLE = 1,
    parameter TX_CPL_FIFO_DEPTH = 32,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 131072,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 131072,
    parameter RX_RAM_SIZE = 131072,

    // RAM configuration
    parameter DDR_CH = 2,
    parameter DDR_ENABLE = 0,
    parameter AXI_DDR_DATA_WIDTH = 512,
    parameter AXI_DDR_ADDR_WIDTH = 34,
    parameter AXI_DDR_ID_WIDTH = 8,
    parameter AXI_DDR_MAX_BURST_LEN = 256,
    parameter AXI_DDR_NARROW_BURST = 0,
    parameter HBM_CH = 32,
    parameter HBM_ENABLE = 0,
    parameter HBM_GROUP_SIZE = 32,
    parameter AXI_HBM_ADDR_WIDTH = 33,
    parameter AXI_HBM_MAX_BURST_LEN = 256,

    // Application block configuration
    parameter APP_ID = 32'h00000000,
    parameter APP_ENABLE = 0,
    parameter APP_CTRL_ENABLE = 1,
    parameter APP_DMA_ENABLE = 1,
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,
    parameter APP_AXIS_IF_ENABLE = 1,
    parameter APP_STAT_ENABLE = 1,

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter AXIS_PCIE_DATA_WIDTH = 512,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = EVENT_QUEUE_INDEX_WIDTH,

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
     * Clock and reset
     */
    input  wire         clk_100mhz_0_p,
    input  wire         clk_100mhz_0_n,
    input  wire         clk_100mhz_1_p,
    input  wire         clk_100mhz_1_n,
    input  wire         clk_100mhz_2_p,
    input  wire         clk_100mhz_2_n,

    /*
     * GPIO
     */
    output wire         hbm_cattrip,
    input  wire [3:0]   msp_gpio,
    output wire         msp_uart_txd,
    input  wire         msp_uart_rxd,

    /*
     * PCI express
     */
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,
    input  wire         pcie_refclk_1_p,
    input  wire         pcie_refclk_1_n,
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
    output wire         qsfp0_refclk_oe_b,
    output wire         qsfp0_refclk_fs,

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
    output wire         qsfp1_refclk_oe_b,
    output wire         qsfp1_refclk_fs,

    /*
     * DDR4
     */
    output wire [16:0]  ddr4_c0_adr,
    output wire [1:0]   ddr4_c0_ba,
    output wire [1:0]   ddr4_c0_bg,
    output wire         ddr4_c0_ck_t,
    output wire         ddr4_c0_ck_c,
    output wire         ddr4_c0_cke,
    output wire         ddr4_c0_cs_n,
    output wire         ddr4_c0_act_n,
    output wire         ddr4_c0_odt,
    output wire         ddr4_c0_par,
    output wire         ddr4_c0_reset_n,
    inout  wire [71:0]  ddr4_c0_dq,
    inout  wire [17:0]  ddr4_c0_dqs_t,
    inout  wire [17:0]  ddr4_c0_dqs_c,

    output wire [16:0]  ddr4_c1_adr,
    output wire [1:0]   ddr4_c1_ba,
    output wire [1:0]   ddr4_c1_bg,
    output wire         ddr4_c1_ck_t,
    output wire         ddr4_c1_ck_c,
    output wire         ddr4_c1_cke,
    output wire         ddr4_c1_cs_n,
    output wire         ddr4_c1_act_n,
    output wire         ddr4_c1_odt,
    output wire         ddr4_c1_par,
    output wire         ddr4_c1_reset_n,
    inout  wire [71:0]  ddr4_c1_dq,
    inout  wire [17:0]  ddr4_c1_dqs_t,
    inout  wire [17:0]  ddr4_c1_dqs_c
);

// PTP configuration
parameter PTP_CLK_PERIOD_NS_NUM = 1024;
parameter PTP_CLK_PERIOD_NS_DENOM = 165;
parameter PTP_TS_WIDTH = 96;
parameter PTP_USE_SAMPLE_CLOCK = 1;
parameter PTP_SEPARATE_RX_CLOCK = 1;

// Interface configuration
parameter TX_TAG_WIDTH = 16;

// RAM configuration
parameter AXI_DDR_STRB_WIDTH = (AXI_DDR_DATA_WIDTH/8);
parameter AXI_HBM_DATA_WIDTH = 256;
parameter AXI_HBM_STRB_WIDTH = (AXI_HBM_DATA_WIDTH/8);
parameter AXI_HBM_ID_WIDTH = 6;

// PCIe interface configuration
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161;
parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 62 : 137;
parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183;
parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81;
parameter RC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 256;
parameter RQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512;
parameter CQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512;
parameter CC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512;
parameter RQ_SEQ_NUM_WIDTH = 6;
parameter PCIE_TAG_COUNT = 256;

// Ethernet interface configuration
parameter AXIS_ETH_DATA_WIDTH = 512;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH;
parameter AXIS_ETH_TX_USER_WIDTH = TX_TAG_WIDTH + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire pcie_user_clk;
wire pcie_user_reset;

wire clk_161mhz_ref_int;

wire clk_50mhz_mmcm_out;
wire clk_125mhz_mmcm_out;

// Internal 50 MHz clock
wire clk_50mhz_int;
wire rst_50mhz_int;

// Internal 125 MHz clock
wire clk_125mhz_int;
wire rst_125mhz_int;

wire mmcm_rst = pcie_user_reset;
wire mmcm_locked;
wire mmcm_clkfb;

// MMCM instance
// 161.13 MHz in, 50 MHz + 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 800 MHz to 1600 MHz
// M = 128, D = 15 sets Fvco = 1375 MHz (in range)
// Divide by 27.5 to get output frequency of 50 MHz
// Divide by 11 to get output frequency of 125 MHz
MMCME4_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(27.5),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(11),
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
    .CLKFBOUT_MULT_F(128),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(15),
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
    .CLKOUT0(clk_50mhz_mmcm_out),
    .CLKOUT0B(),
    .CLKOUT1(clk_125mhz_mmcm_out),
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
clk_50mhz_bufg_inst (
    .I(clk_50mhz_mmcm_out),
    .O(clk_50mhz_int)
);

BUFG
clk_125mhz_bufg_inst (
    .I(clk_125mhz_mmcm_out),
    .O(clk_125mhz_int)
);

sync_reset #(
    .N(4)
)
sync_reset_50mhz_inst (
    .clk(clk_50mhz_int),
    .rst(~mmcm_locked),
    .out(rst_50mhz_int)
);

sync_reset #(
    .N(4)
)
sync_reset_125mhz_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
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

// BMC
wire        axil_cms_clk;
wire        axil_cms_rst;
wire [17:0] axil_cms_awaddr;
wire [2:0]  axil_cms_awprot;
wire        axil_cms_awvalid;
wire        axil_cms_awready;
wire [31:0] axil_cms_wdata;
wire [3:0]  axil_cms_wstrb;
wire        axil_cms_wvalid;
wire        axil_cms_wready;
wire [1:0]  axil_cms_bresp;
wire        axil_cms_bvalid;
wire        axil_cms_bready;
wire [17:0] axil_cms_araddr;
wire [2:0]  axil_cms_arprot;
wire        axil_cms_arvalid;
wire        axil_cms_arready;
wire [31:0] axil_cms_rdata;
wire [1:0]  axil_cms_rresp;
wire        axil_cms_rvalid;
wire        axil_cms_rready;

wire [17:0] axil_cms_awaddr_int;
wire [2:0]  axil_cms_awprot_int;
wire        axil_cms_awvalid_int;
wire        axil_cms_awready_int;
wire [31:0] axil_cms_wdata_int;
wire [3:0]  axil_cms_wstrb_int;
wire        axil_cms_wvalid_int;
wire        axil_cms_wready_int;
wire [1:0]  axil_cms_bresp_int;
wire        axil_cms_bvalid_int;
wire        axil_cms_bready_int;
wire [17:0] axil_cms_araddr_int;
wire [2:0]  axil_cms_arprot_int;
wire        axil_cms_arvalid_int;
wire        axil_cms_arready_int;
wire [31:0] axil_cms_rdata_int;
wire [1:0]  axil_cms_rresp_int;
wire        axil_cms_rvalid_int;
wire        axil_cms_rready_int;

wire [7:0] hbm_temp_1;
wire [7:0] hbm_temp_2;

axil_cdc #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(18)
)
cms_axil_cdc_inst (
    .s_clk(axil_cms_clk),
    .s_rst(axil_cms_rst),
    .s_axil_awaddr(axil_cms_awaddr),
    .s_axil_awprot(axil_cms_awprot),
    .s_axil_awvalid(axil_cms_awvalid),
    .s_axil_awready(axil_cms_awready),
    .s_axil_wdata(axil_cms_wdata),
    .s_axil_wstrb(axil_cms_wstrb),
    .s_axil_wvalid(axil_cms_wvalid),
    .s_axil_wready(axil_cms_wready),
    .s_axil_bresp(axil_cms_bresp),
    .s_axil_bvalid(axil_cms_bvalid),
    .s_axil_bready(axil_cms_bready),
    .s_axil_araddr(axil_cms_araddr),
    .s_axil_arprot(axil_cms_arprot),
    .s_axil_arvalid(axil_cms_arvalid),
    .s_axil_arready(axil_cms_arready),
    .s_axil_rdata(axil_cms_rdata),
    .s_axil_rresp(axil_cms_rresp),
    .s_axil_rvalid(axil_cms_rvalid),
    .s_axil_rready(axil_cms_rready),
    .m_clk(clk_50mhz_int),
    .m_rst(rst_50mhz_int),
    .m_axil_awaddr(axil_cms_awaddr_int),
    .m_axil_awprot(axil_cms_awprot_int),
    .m_axil_awvalid(axil_cms_awvalid_int),
    .m_axil_awready(axil_cms_awready_int),
    .m_axil_wdata(axil_cms_wdata_int),
    .m_axil_wstrb(axil_cms_wstrb_int),
    .m_axil_wvalid(axil_cms_wvalid_int),
    .m_axil_wready(axil_cms_wready_int),
    .m_axil_bresp(axil_cms_bresp_int),
    .m_axil_bvalid(axil_cms_bvalid_int),
    .m_axil_bready(axil_cms_bready_int),
    .m_axil_araddr(axil_cms_araddr_int),
    .m_axil_arprot(axil_cms_arprot_int),
    .m_axil_arvalid(axil_cms_arvalid_int),
    .m_axil_arready(axil_cms_arready_int),
    .m_axil_rdata(axil_cms_rdata_int),
    .m_axil_rresp(axil_cms_rresp_int),
    .m_axil_rvalid(axil_cms_rvalid_int),
    .m_axil_rready(axil_cms_rready_int)
);

cms_wrapper
cms_inst (
    .aclk_ctrl_0(clk_50mhz_int),
    .aresetn_ctrl_0(~rst_50mhz_int),
    .hbm_temp_1_0(hbm_temp_1),
    .hbm_temp_2_0(hbm_temp_2),
    .interrupt_hbm_cattrip_0(hbm_cattrip),
    .interrupt_host_0(),
    .s_axi_ctrl_0_araddr(axil_cms_araddr_int),
    .s_axi_ctrl_0_arprot(axil_cms_arprot_int),
    .s_axi_ctrl_0_arready(axil_cms_arready_int),
    .s_axi_ctrl_0_arvalid(axil_cms_arvalid_int),
    .s_axi_ctrl_0_awaddr(axil_cms_awaddr_int),
    .s_axi_ctrl_0_awprot(axil_cms_awprot_int),
    .s_axi_ctrl_0_awready(axil_cms_awready_int),
    .s_axi_ctrl_0_awvalid(axil_cms_awvalid_int),
    .s_axi_ctrl_0_bready(axil_cms_bready_int),
    .s_axi_ctrl_0_bresp(axil_cms_bresp_int),
    .s_axi_ctrl_0_bvalid(axil_cms_bvalid_int),
    .s_axi_ctrl_0_rdata(axil_cms_rdata_int),
    .s_axi_ctrl_0_rready(axil_cms_rready_int),
    .s_axi_ctrl_0_rresp(axil_cms_rresp_int),
    .s_axi_ctrl_0_rvalid(axil_cms_rvalid_int),
    .s_axi_ctrl_0_wdata(axil_cms_wdata_int),
    .s_axi_ctrl_0_wready(axil_cms_wready_int),
    .s_axi_ctrl_0_wstrb(axil_cms_wstrb_int),
    .s_axi_ctrl_0_wvalid(axil_cms_wvalid_int),
    .satellite_gpio_0(msp_gpio),
    .satellite_uart_0_rxd(msp_uart_rxd),
    .satellite_uart_0_txd(msp_uart_txd)
);

// PCIe
wire pcie_sys_clk;
wire pcie_sys_clk_gt;

IBUFDS_GTE4 #(
    .REFCLK_HROW_CK_SEL(2'b00)
)
ibufds_gte4_pcie_mgt_refclk_inst (
    .I             (pcie_refclk_1_p),
    .IB            (pcie_refclk_1_n),
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

wire [3:0]   cfg_interrupt_msix_enable;
wire [3:0]   cfg_interrupt_msix_mask;
wire [251:0] cfg_interrupt_msix_vf_enable;
wire [251:0] cfg_interrupt_msix_vf_mask;
wire [63:0]  cfg_interrupt_msix_address;
wire [31:0]  cfg_interrupt_msix_data;
wire         cfg_interrupt_msix_int;
wire [1:0]   cfg_interrupt_msix_vec_pending;
wire         cfg_interrupt_msix_vec_pending_status;
wire         cfg_interrupt_msix_sent;
wire         cfg_interrupt_msix_fail;
wire [7:0]   cfg_interrupt_msi_function_number;

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

BUFG
pcie_user_reset_bufg_inst (
    .I(pcie_user_reset_reg_2),
    .O(pcie_user_reset)
);

pcie4c_uscale_plus_0
pcie4c_uscale_plus_inst (
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
    .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    .cfg_interrupt_msix_vec_pending(cfg_interrupt_msix_vec_pending),
    .cfg_interrupt_msix_vec_pending_status(cfg_interrupt_msix_vec_pending_status),
    .cfg_interrupt_msi_sent(cfg_interrupt_msix_sent),
    .cfg_interrupt_msi_fail(cfg_interrupt_msix_fail),
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
    .sys_reset(pcie_reset_n),

    .phy_rdy_out()
);

reg [RQ_SEQ_NUM_WIDTH-1:0] pcie_rq_seq_num0_reg;
reg                        pcie_rq_seq_num_vld0_reg;
reg [RQ_SEQ_NUM_WIDTH-1:0] pcie_rq_seq_num1_reg;
reg                        pcie_rq_seq_num_vld1_reg;

always @(posedge pcie_user_clk) begin
    pcie_rq_seq_num0_reg <= pcie_rq_seq_num0;
    pcie_rq_seq_num_vld0_reg <= pcie_rq_seq_num_vld0;
    pcie_rq_seq_num1_reg <= pcie_rq_seq_num1;
    pcie_rq_seq_num_vld1_reg <= pcie_rq_seq_num_vld1;

    if (pcie_user_reset) begin
        pcie_rq_seq_num_vld0_reg <= 1'b0;
        pcie_rq_seq_num_vld1_reg <= 1'b0;
    end
end

// QSFP0 CMAC
assign qsfp0_refclk_oe_b = 1'b0;
assign qsfp0_refclk_fs = 1'b1;

wire                           qsfp0_tx_clk_int;
wire                           qsfp0_tx_rst_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp0_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp0_tx_axis_tkeep_int;
wire                           qsfp0_tx_axis_tvalid_int;
wire                           qsfp0_tx_axis_tready_int;
wire                           qsfp0_tx_axis_tlast_int;
wire [16+1-1:0]                qsfp0_tx_axis_tuser_int;

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

wire        qsfp0_drp_clk = clk_125mhz_int;
wire        qsfp0_drp_rst = rst_125mhz_int;
wire [23:0] qsfp0_drp_addr;
wire [15:0] qsfp0_drp_di;
wire        qsfp0_drp_en;
wire        qsfp0_drp_we;
wire [15:0] qsfp0_drp_do;
wire        qsfp0_drp_rdy;

wire qsfp0_rx_status;

wire qsfp0_gtpowergood;

wire qsfp0_mgt_refclk_1;
wire qsfp0_mgt_refclk_1_int;
wire qsfp0_mgt_refclk_1_bufg;

assign clk_161mhz_ref_int = qsfp0_mgt_refclk_1_bufg;

IBUFDS_GTE4 ibufds_gte4_qsfp0_mgt_refclk_1_inst (
    .I     (qsfp0_mgt_refclk_1_p),
    .IB    (qsfp0_mgt_refclk_1_n),
    .CEB   (1'b0),
    .O     (qsfp0_mgt_refclk_1),
    .ODIV2 (qsfp0_mgt_refclk_1_int)
);

BUFG_GT bufg_gt_qsfp0_mgt_refclk_1_inst (
    .CE      (qsfp0_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (qsfp0_mgt_refclk_1_int),
    .O       (qsfp0_mgt_refclk_1_bufg)
);

wire qsfp0_rst;

sync_reset #(
    .N(4)
)
qsfp0_sync_reset_inst (
    .clk(qsfp0_mgt_refclk_1_bufg),
    .rst(rst_125mhz_int),
    .out(qsfp0_rst)
);

cmac_gty_wrapper #(
    .DRP_CLK_FREQ_HZ(125000000),
    .AXIS_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .TX_SERDES_PIPELINE(0),
    .RX_SERDES_PIPELINE(0),
    .RS_FEC_ENABLE(1)
)
qsfp0_cmac_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp0_rst),

    /*
     * Common
     */
    .xcvr_gtpowergood_out(qsfp0_gtpowergood),
    .xcvr_ref_clk(qsfp0_mgt_refclk_1),

    /*
     * DRP
     */
    .drp_clk(qsfp0_drp_clk),
    .drp_rst(qsfp0_drp_rst),
    .drp_addr(qsfp0_drp_addr),
    .drp_di(qsfp0_drp_di),
    .drp_en(qsfp0_drp_en),
    .drp_we(qsfp0_drp_we),
    .drp_do(qsfp0_drp_do),
    .drp_rdy(qsfp0_drp_rdy),

    /*
     * Serial data
     */
    .xcvr_txp({qsfp0_tx4_p, qsfp0_tx3_p, qsfp0_tx2_p, qsfp0_tx1_p}),
    .xcvr_txn({qsfp0_tx4_n, qsfp0_tx3_n, qsfp0_tx2_n, qsfp0_tx1_n}),
    .xcvr_rxp({qsfp0_rx4_p, qsfp0_rx3_p, qsfp0_rx2_p, qsfp0_rx1_p}),
    .xcvr_rxn({qsfp0_rx4_n, qsfp0_rx3_n, qsfp0_rx2_n, qsfp0_rx1_n}),

    /*
     * CMAC connections
     */
    .tx_clk(qsfp0_tx_clk_int),
    .tx_rst(qsfp0_tx_rst_int),

    .tx_axis_tdata(qsfp0_tx_axis_tdata_int),
    .tx_axis_tkeep(qsfp0_tx_axis_tkeep_int),
    .tx_axis_tvalid(qsfp0_tx_axis_tvalid_int),
    .tx_axis_tready(qsfp0_tx_axis_tready_int),
    .tx_axis_tlast(qsfp0_tx_axis_tlast_int),
    .tx_axis_tuser(qsfp0_tx_axis_tuser_int),

    .tx_ptp_time(qsfp0_tx_ptp_time_int),
    .tx_ptp_ts(qsfp0_tx_ptp_ts_int),
    .tx_ptp_ts_tag(qsfp0_tx_ptp_ts_tag_int),
    .tx_ptp_ts_valid(qsfp0_tx_ptp_ts_valid_int),

    .rx_clk(qsfp0_rx_clk_int),
    .rx_rst(qsfp0_rx_rst_int),

    .rx_axis_tdata(qsfp0_rx_axis_tdata_int),
    .rx_axis_tkeep(qsfp0_rx_axis_tkeep_int),
    .rx_axis_tvalid(qsfp0_rx_axis_tvalid_int),
    .rx_axis_tlast(qsfp0_rx_axis_tlast_int),
    .rx_axis_tuser(qsfp0_rx_axis_tuser_int),

    .rx_ptp_clk(qsfp0_rx_ptp_clk_int),
    .rx_ptp_rst(qsfp0_rx_ptp_rst_int),
    .rx_ptp_time(qsfp0_rx_ptp_time_int),

    .rx_status(qsfp0_rx_status)
);

// QSFP1 CMAC
assign qsfp1_refclk_oe_b = 1'b0;
assign qsfp1_refclk_fs = 1'b1;

wire                           qsfp1_tx_clk_int;
wire                           qsfp1_tx_rst_int;

wire [AXIS_ETH_DATA_WIDTH-1:0] qsfp1_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0] qsfp1_tx_axis_tkeep_int;
wire                           qsfp1_tx_axis_tvalid_int;
wire                           qsfp1_tx_axis_tready_int;
wire                           qsfp1_tx_axis_tlast_int;
wire [16+1-1:0]                qsfp1_tx_axis_tuser_int;

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

wire        qsfp1_drp_clk = clk_125mhz_int;
wire        qsfp1_drp_rst = rst_125mhz_int;
wire [23:0] qsfp1_drp_addr;
wire [15:0] qsfp1_drp_di;
wire        qsfp1_drp_en;
wire        qsfp1_drp_we;
wire [15:0] qsfp1_drp_do;
wire        qsfp1_drp_rdy;

wire qsfp1_rx_status;

wire qsfp1_gtpowergood;

wire qsfp1_mgt_refclk_1;
wire qsfp1_mgt_refclk_1_int;
wire qsfp1_mgt_refclk_1_bufg;

IBUFDS_GTE4 ibufds_gte4_qsfp1_mgt_refclk_1_inst (
    .I     (qsfp1_mgt_refclk_1_p),
    .IB    (qsfp1_mgt_refclk_1_n),
    .CEB   (1'b0),
    .O     (qsfp1_mgt_refclk_1),
    .ODIV2 (qsfp1_mgt_refclk_1_int)
);

BUFG_GT bufg_gt_qsfp1_mgt_refclk_1_inst (
    .CE      (qsfp1_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (qsfp1_mgt_refclk_1_int),
    .O       (qsfp1_mgt_refclk_1_bufg)
);

wire qsfp1_rst;

sync_reset #(
    .N(4)
)
qsfp1_sync_reset_inst (
    .clk(qsfp1_mgt_refclk_1_bufg),
    .rst(rst_125mhz_int),
    .out(qsfp1_rst)
);

cmac_gty_wrapper #(
    .DRP_CLK_FREQ_HZ(125000000),
    .AXIS_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .TX_SERDES_PIPELINE(0),
    .RX_SERDES_PIPELINE(0),
    .RS_FEC_ENABLE(1)
)
qsfp1_cmac_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp1_rst),

    /*
     * Common
     */
    .xcvr_gtpowergood_out(qsfp1_gtpowergood),
    .xcvr_ref_clk(qsfp1_mgt_refclk_1),

    /*
     * DRP
     */
    .drp_clk(qsfp1_drp_clk),
    .drp_rst(qsfp1_drp_rst),
    .drp_addr(qsfp1_drp_addr),
    .drp_di(qsfp1_drp_di),
    .drp_en(qsfp1_drp_en),
    .drp_we(qsfp1_drp_we),
    .drp_do(qsfp1_drp_do),
    .drp_rdy(qsfp1_drp_rdy),

    /*
     * Serial data
     */
    .xcvr_txp({qsfp1_tx4_p, qsfp1_tx3_p, qsfp1_tx2_p, qsfp1_tx1_p}),
    .xcvr_txn({qsfp1_tx4_n, qsfp1_tx3_n, qsfp1_tx2_n, qsfp1_tx1_n}),
    .xcvr_rxp({qsfp1_rx4_p, qsfp1_rx3_p, qsfp1_rx2_p, qsfp1_rx1_p}),
    .xcvr_rxn({qsfp1_rx4_n, qsfp1_rx3_n, qsfp1_rx2_n, qsfp1_rx1_n}),

    /*
     * CMAC connections
     */
    .tx_clk(qsfp1_tx_clk_int),
    .tx_rst(qsfp1_tx_rst_int),

    .tx_axis_tdata(qsfp1_tx_axis_tdata_int),
    .tx_axis_tkeep(qsfp1_tx_axis_tkeep_int),
    .tx_axis_tvalid(qsfp1_tx_axis_tvalid_int),
    .tx_axis_tready(qsfp1_tx_axis_tready_int),
    .tx_axis_tlast(qsfp1_tx_axis_tlast_int),
    .tx_axis_tuser(qsfp1_tx_axis_tuser_int),

    .tx_ptp_time(qsfp1_tx_ptp_time_int),
    .tx_ptp_ts(qsfp1_tx_ptp_ts_int),
    .tx_ptp_ts_tag(qsfp1_tx_ptp_ts_tag_int),
    .tx_ptp_ts_valid(qsfp1_tx_ptp_ts_valid_int),

    .rx_clk(qsfp1_rx_clk_int),
    .rx_rst(qsfp1_rx_rst_int),

    .rx_axis_tdata(qsfp1_rx_axis_tdata_int),
    .rx_axis_tkeep(qsfp1_rx_axis_tkeep_int),
    .rx_axis_tvalid(qsfp1_rx_axis_tvalid_int),
    .rx_axis_tlast(qsfp1_rx_axis_tlast_int),
    .rx_axis_tuser(qsfp1_rx_axis_tuser_int),

    .rx_ptp_clk(qsfp1_rx_ptp_clk_int),
    .rx_ptp_rst(qsfp1_rx_ptp_rst_int),
    .rx_ptp_time(qsfp1_rx_ptp_time_int),

    .rx_status(qsfp1_rx_status)
);

wire ptp_clk;
wire ptp_rst;
wire ptp_sample_clk;

assign ptp_clk = qsfp0_mgt_refclk_1_bufg;
assign ptp_rst = qsfp0_rst;
assign ptp_sample_clk = clk_125mhz_int;

// DDR4
wire [DDR_CH-1:0]                     ddr_clk;
wire [DDR_CH-1:0]                     ddr_rst;

wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_awid;
wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]  m_axi_ddr_awaddr;
wire [DDR_CH*8-1:0]                   m_axi_ddr_awlen;
wire [DDR_CH*3-1:0]                   m_axi_ddr_awsize;
wire [DDR_CH*2-1:0]                   m_axi_ddr_awburst;
wire [DDR_CH-1:0]                     m_axi_ddr_awlock;
wire [DDR_CH*4-1:0]                   m_axi_ddr_awcache;
wire [DDR_CH*3-1:0]                   m_axi_ddr_awprot;
wire [DDR_CH*4-1:0]                   m_axi_ddr_awqos;
wire [DDR_CH-1:0]                     m_axi_ddr_awvalid;
wire [DDR_CH-1:0]                     m_axi_ddr_awready;
wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]  m_axi_ddr_wdata;
wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]  m_axi_ddr_wstrb;
wire [DDR_CH-1:0]                     m_axi_ddr_wlast;
wire [DDR_CH-1:0]                     m_axi_ddr_wvalid;
wire [DDR_CH-1:0]                     m_axi_ddr_wready;
wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_bid;
wire [DDR_CH*2-1:0]                   m_axi_ddr_bresp;
wire [DDR_CH-1:0]                     m_axi_ddr_bvalid;
wire [DDR_CH-1:0]                     m_axi_ddr_bready;
wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_arid;
wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]  m_axi_ddr_araddr;
wire [DDR_CH*8-1:0]                   m_axi_ddr_arlen;
wire [DDR_CH*3-1:0]                   m_axi_ddr_arsize;
wire [DDR_CH*2-1:0]                   m_axi_ddr_arburst;
wire [DDR_CH-1:0]                     m_axi_ddr_arlock;
wire [DDR_CH*4-1:0]                   m_axi_ddr_arcache;
wire [DDR_CH*3-1:0]                   m_axi_ddr_arprot;
wire [DDR_CH*4-1:0]                   m_axi_ddr_arqos;
wire [DDR_CH-1:0]                     m_axi_ddr_arvalid;
wire [DDR_CH-1:0]                     m_axi_ddr_arready;
wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]    m_axi_ddr_rid;
wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]  m_axi_ddr_rdata;
wire [DDR_CH*2-1:0]                   m_axi_ddr_rresp;
wire [DDR_CH-1:0]                     m_axi_ddr_rlast;
wire [DDR_CH-1:0]                     m_axi_ddr_rvalid;
wire [DDR_CH-1:0]                     m_axi_ddr_rready;

wire [DDR_CH-1:0]                     ddr_status;

generate

wire clk_100mhz_0_ibufg;

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")
)
clk_100mhz_0_ibufg_inst (
   .O   (clk_100mhz_0_ibufg),
   .I   (clk_100mhz_0_p),
   .IB  (clk_100mhz_0_n)
);

if (DDR_ENABLE && DDR_CH > 0) begin

ddr4_0 ddr4_c0_inst (
    .c0_sys_clk_i(clk_100mhz_0_ibufg),
    .sys_rst(pcie_user_reset),

    .c0_init_calib_complete(ddr_status[0 +: 1]),
    .c0_ddr4_interrupt(),
    .dbg_clk(),
    .dbg_bus(),

    .c0_ddr4_adr(ddr4_c0_adr),
    .c0_ddr4_ba(ddr4_c0_ba),
    .c0_ddr4_cke(ddr4_c0_cke),
    .c0_ddr4_cs_n(ddr4_c0_cs_n),
    .c0_ddr4_dq(ddr4_c0_dq),
    .c0_ddr4_dqs_t(ddr4_c0_dqs_t),
    .c0_ddr4_dqs_c(ddr4_c0_dqs_c),
    .c0_ddr4_odt(ddr4_c0_odt),
    .c0_ddr4_parity(ddr4_c0_par),
    .c0_ddr4_bg(ddr4_c0_bg),
    .c0_ddr4_reset_n(ddr4_c0_reset_n),
    .c0_ddr4_act_n(ddr4_c0_act_n),
    .c0_ddr4_ck_t(ddr4_c0_ck_t),
    .c0_ddr4_ck_c(ddr4_c0_ck_c),

    .c0_ddr4_ui_clk(ddr_clk[0 +: 1]),
    .c0_ddr4_ui_clk_sync_rst(ddr_rst[0 +: 1]),

    .c0_ddr4_aresetn(!ddr_rst[0 +: 1]),

    .c0_ddr4_s_axi_ctrl_awvalid(1'b0),
    .c0_ddr4_s_axi_ctrl_awready(),
    .c0_ddr4_s_axi_ctrl_awaddr(32'd0),
    .c0_ddr4_s_axi_ctrl_wvalid(1'b0),
    .c0_ddr4_s_axi_ctrl_wready(),
    .c0_ddr4_s_axi_ctrl_wdata(32'd0),
    .c0_ddr4_s_axi_ctrl_bvalid(),
    .c0_ddr4_s_axi_ctrl_bready(1'b1),
    .c0_ddr4_s_axi_ctrl_bresp(),
    .c0_ddr4_s_axi_ctrl_arvalid(1'b0),
    .c0_ddr4_s_axi_ctrl_arready(),
    .c0_ddr4_s_axi_ctrl_araddr(31'd0),
    .c0_ddr4_s_axi_ctrl_rvalid(),
    .c0_ddr4_s_axi_ctrl_rready(1'b1),
    .c0_ddr4_s_axi_ctrl_rdata(),
    .c0_ddr4_s_axi_ctrl_rresp(),

    .c0_ddr4_s_axi_awid(m_axi_ddr_awid[0*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_awaddr(m_axi_ddr_awaddr[0*AXI_DDR_ADDR_WIDTH +: AXI_DDR_ADDR_WIDTH]),
    .c0_ddr4_s_axi_awlen(m_axi_ddr_awlen[0*8 +: 8]),
    .c0_ddr4_s_axi_awsize(m_axi_ddr_awsize[0*3 +: 3]),
    .c0_ddr4_s_axi_awburst(m_axi_ddr_awburst[0*2 +: 2]),
    .c0_ddr4_s_axi_awlock(m_axi_ddr_awlock[0 +: 1]),
    .c0_ddr4_s_axi_awcache(m_axi_ddr_awcache[0*4 +: 4]),
    .c0_ddr4_s_axi_awprot(m_axi_ddr_awprot[0*3 +: 3]),
    .c0_ddr4_s_axi_awqos(m_axi_ddr_awqos[0*4 +: 4]),
    .c0_ddr4_s_axi_awvalid(m_axi_ddr_awvalid[0 +: 1]),
    .c0_ddr4_s_axi_awready(m_axi_ddr_awready[0 +: 1]),
    .c0_ddr4_s_axi_wdata(m_axi_ddr_wdata[0*AXI_DDR_DATA_WIDTH +: AXI_DDR_DATA_WIDTH]),
    .c0_ddr4_s_axi_wstrb(m_axi_ddr_wstrb[0*AXI_DDR_STRB_WIDTH +: AXI_DDR_STRB_WIDTH]),
    .c0_ddr4_s_axi_wlast(m_axi_ddr_wlast[0 +: 1]),
    .c0_ddr4_s_axi_wvalid(m_axi_ddr_wvalid[0 +: 1]),
    .c0_ddr4_s_axi_wready(m_axi_ddr_wready[0 +: 1]),
    .c0_ddr4_s_axi_bready(m_axi_ddr_bready[0 +: 1]),
    .c0_ddr4_s_axi_bid(m_axi_ddr_bid[0*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_bresp(m_axi_ddr_bresp[0*2 +: 2]),
    .c0_ddr4_s_axi_bvalid(m_axi_ddr_bvalid[0 +: 1]),
    .c0_ddr4_s_axi_arid(m_axi_ddr_arid[0*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_araddr(m_axi_ddr_araddr[0*AXI_DDR_ADDR_WIDTH +: AXI_DDR_ADDR_WIDTH]),
    .c0_ddr4_s_axi_arlen(m_axi_ddr_arlen[0*8 +: 8]),
    .c0_ddr4_s_axi_arsize(m_axi_ddr_arsize[0*3 +: 3]),
    .c0_ddr4_s_axi_arburst(m_axi_ddr_arburst[0*2 +: 2]),
    .c0_ddr4_s_axi_arlock(m_axi_ddr_arlock[0 +: 1]),
    .c0_ddr4_s_axi_arcache(m_axi_ddr_arcache[0*4 +: 4]),
    .c0_ddr4_s_axi_arprot(m_axi_ddr_arprot[0*3 +: 3]),
    .c0_ddr4_s_axi_arqos(m_axi_ddr_arqos[0*4 +: 4]),
    .c0_ddr4_s_axi_arvalid(m_axi_ddr_arvalid[0 +: 1]),
    .c0_ddr4_s_axi_arready(m_axi_ddr_arready[0 +: 1]),
    .c0_ddr4_s_axi_rready(m_axi_ddr_rready[0 +: 1]),
    .c0_ddr4_s_axi_rlast(m_axi_ddr_rlast[0 +: 1]),
    .c0_ddr4_s_axi_rvalid(m_axi_ddr_rvalid[0 +: 1]),
    .c0_ddr4_s_axi_rresp(m_axi_ddr_rresp[0*2 +: 2]),
    .c0_ddr4_s_axi_rid(m_axi_ddr_rid[0*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_rdata(m_axi_ddr_rdata[0*AXI_DDR_DATA_WIDTH +: AXI_DDR_DATA_WIDTH])
);

end else begin

assign ddr4_c0_adr = {17{1'bz}};
assign ddr4_c0_ba = {2{1'bz}};
assign ddr4_c0_bg = {2{1'bz}};
assign ddr4_c0_cke = 1'bz;
assign ddr4_c0_cs_n = 1'bz;
assign ddr4_c0_act_n = 1'bz;
assign ddr4_c0_odt = 1'bz;
assign ddr4_c0_par = 1'bz;
assign ddr4_c0_reset_n = 1'b0;
assign ddr4_c0_dq = {72{1'bz}};
assign ddr4_c0_dqs_t = {18{1'bz}};
assign ddr4_c0_dqs_c = {18{1'bz}};

OBUFTDS ddr4_c0_ck_obuftds_inst (
    .I(1'b0),
    .T(1'b1),
    .O(ddr4_c0_ck_t),
    .OB(ddr4_c0_ck_c)
);

assign ddr_clk = 0;
assign ddr_rst = 0;

assign m_axi_ddr_awready = 0;
assign m_axi_ddr_wready = 0;
assign m_axi_ddr_bid = 0;
assign m_axi_ddr_bresp = 0;
assign m_axi_ddr_bvalid = 0;
assign m_axi_ddr_arready = 0;
assign m_axi_ddr_rid = 0;
assign m_axi_ddr_rdata = 0;
assign m_axi_ddr_rresp = 0;
assign m_axi_ddr_rlast = 0;
assign m_axi_ddr_rvalid = 0;

assign ddr_status = 0;

end

wire clk_100mhz_1_ibufg;

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")
)
clk_100mhz_1_ibufg_inst (
   .O   (clk_100mhz_1_ibufg),
   .I   (clk_100mhz_1_p),
   .IB  (clk_100mhz_1_n)
);

if (DDR_ENABLE && DDR_CH > 1) begin

ddr4_0 ddr4_c1_inst (
    .c0_sys_clk_i(clk_100mhz_1_ibufg),
    .sys_rst(pcie_user_reset),

    .c0_init_calib_complete(ddr_status[1 +: 1]),
    .c0_ddr4_interrupt(),
    .dbg_clk(),
    .dbg_bus(),

    .c0_ddr4_adr(ddr4_c1_adr),
    .c0_ddr4_ba(ddr4_c1_ba),
    .c0_ddr4_cke(ddr4_c1_cke),
    .c0_ddr4_cs_n(ddr4_c1_cs_n),
    .c0_ddr4_dq(ddr4_c1_dq),
    .c0_ddr4_dqs_t(ddr4_c1_dqs_t),
    .c0_ddr4_dqs_c(ddr4_c1_dqs_c),
    .c0_ddr4_odt(ddr4_c1_odt),
    .c0_ddr4_parity(ddr4_c1_par),
    .c0_ddr4_bg(ddr4_c1_bg),
    .c0_ddr4_reset_n(ddr4_c1_reset_n),
    .c0_ddr4_act_n(ddr4_c1_act_n),
    .c0_ddr4_ck_t(ddr4_c1_ck_t),
    .c0_ddr4_ck_c(ddr4_c1_ck_c),

    .c0_ddr4_ui_clk(ddr_clk[1 +: 1]),
    .c0_ddr4_ui_clk_sync_rst(ddr_rst[1 +: 1]),

    .c0_ddr4_aresetn(!ddr_rst[1 +: 1]),

    .c0_ddr4_s_axi_ctrl_awvalid(1'b0),
    .c0_ddr4_s_axi_ctrl_awready(),
    .c0_ddr4_s_axi_ctrl_awaddr(32'd0),
    .c0_ddr4_s_axi_ctrl_wvalid(1'b0),
    .c0_ddr4_s_axi_ctrl_wready(),
    .c0_ddr4_s_axi_ctrl_wdata(32'd0),
    .c0_ddr4_s_axi_ctrl_bvalid(),
    .c0_ddr4_s_axi_ctrl_bready(1'b1),
    .c0_ddr4_s_axi_ctrl_bresp(),
    .c0_ddr4_s_axi_ctrl_arvalid(1'b0),
    .c0_ddr4_s_axi_ctrl_arready(),
    .c0_ddr4_s_axi_ctrl_araddr(31'd0),
    .c0_ddr4_s_axi_ctrl_rvalid(),
    .c0_ddr4_s_axi_ctrl_rready(1'b1),
    .c0_ddr4_s_axi_ctrl_rdata(),
    .c0_ddr4_s_axi_ctrl_rresp(),

    .c0_ddr4_s_axi_awid(m_axi_ddr_awid[1*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_awaddr(m_axi_ddr_awaddr[1*AXI_DDR_ADDR_WIDTH +: AXI_DDR_ADDR_WIDTH]),
    .c0_ddr4_s_axi_awlen(m_axi_ddr_awlen[1*8 +: 8]),
    .c0_ddr4_s_axi_awsize(m_axi_ddr_awsize[1*3 +: 3]),
    .c0_ddr4_s_axi_awburst(m_axi_ddr_awburst[1*2 +: 2]),
    .c0_ddr4_s_axi_awlock(m_axi_ddr_awlock[1 +: 1]),
    .c0_ddr4_s_axi_awcache(m_axi_ddr_awcache[1*4 +: 4]),
    .c0_ddr4_s_axi_awprot(m_axi_ddr_awprot[1*3 +: 3]),
    .c0_ddr4_s_axi_awqos(m_axi_ddr_awqos[1*4 +: 4]),
    .c0_ddr4_s_axi_awvalid(m_axi_ddr_awvalid[1 +: 1]),
    .c0_ddr4_s_axi_awready(m_axi_ddr_awready[1 +: 1]),
    .c0_ddr4_s_axi_wdata(m_axi_ddr_wdata[1*AXI_DDR_DATA_WIDTH +: AXI_DDR_DATA_WIDTH]),
    .c0_ddr4_s_axi_wstrb(m_axi_ddr_wstrb[1*AXI_DDR_STRB_WIDTH +: AXI_DDR_STRB_WIDTH]),
    .c0_ddr4_s_axi_wlast(m_axi_ddr_wlast[1 +: 1]),
    .c0_ddr4_s_axi_wvalid(m_axi_ddr_wvalid[1 +: 1]),
    .c0_ddr4_s_axi_wready(m_axi_ddr_wready[1 +: 1]),
    .c0_ddr4_s_axi_bready(m_axi_ddr_bready[1 +: 1]),
    .c0_ddr4_s_axi_bid(m_axi_ddr_bid[1*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_bresp(m_axi_ddr_bresp[1*2 +: 2]),
    .c0_ddr4_s_axi_bvalid(m_axi_ddr_bvalid[1 +: 1]),
    .c0_ddr4_s_axi_arid(m_axi_ddr_arid[1*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_araddr(m_axi_ddr_araddr[1*AXI_DDR_ADDR_WIDTH +: AXI_DDR_ADDR_WIDTH]),
    .c0_ddr4_s_axi_arlen(m_axi_ddr_arlen[1*8 +: 8]),
    .c0_ddr4_s_axi_arsize(m_axi_ddr_arsize[1*3 +: 3]),
    .c0_ddr4_s_axi_arburst(m_axi_ddr_arburst[1*2 +: 2]),
    .c0_ddr4_s_axi_arlock(m_axi_ddr_arlock[1 +: 1]),
    .c0_ddr4_s_axi_arcache(m_axi_ddr_arcache[1*4 +: 4]),
    .c0_ddr4_s_axi_arprot(m_axi_ddr_arprot[1*3 +: 3]),
    .c0_ddr4_s_axi_arqos(m_axi_ddr_arqos[1*4 +: 4]),
    .c0_ddr4_s_axi_arvalid(m_axi_ddr_arvalid[1 +: 1]),
    .c0_ddr4_s_axi_arready(m_axi_ddr_arready[1 +: 1]),
    .c0_ddr4_s_axi_rready(m_axi_ddr_rready[1 +: 1]),
    .c0_ddr4_s_axi_rlast(m_axi_ddr_rlast[1 +: 1]),
    .c0_ddr4_s_axi_rvalid(m_axi_ddr_rvalid[1 +: 1]),
    .c0_ddr4_s_axi_rresp(m_axi_ddr_rresp[1*2 +: 2]),
    .c0_ddr4_s_axi_rid(m_axi_ddr_rid[1*AXI_DDR_ID_WIDTH +: AXI_DDR_ID_WIDTH]),
    .c0_ddr4_s_axi_rdata(m_axi_ddr_rdata[1*AXI_DDR_DATA_WIDTH +: AXI_DDR_DATA_WIDTH])
);

end else begin

assign ddr4_c1_adr = {17{1'bz}};
assign ddr4_c1_ba = {2{1'bz}};
assign ddr4_c1_bg = {2{1'bz}};
assign ddr4_c1_cke = 1'bz;
assign ddr4_c1_cs_n = 1'bz;
assign ddr4_c1_act_n = 1'bz;
assign ddr4_c1_odt = 1'bz;
assign ddr4_c1_par = 1'bz;
assign ddr4_c1_reset_n = 1'b0;
assign ddr4_c1_dq = {72{1'bz}};
assign ddr4_c1_dqs_t = {18{1'bz}};
assign ddr4_c1_dqs_c = {18{1'bz}};

OBUFTDS ddr4_c1_ck_obuftds_inst (
    .I(1'b0),
    .T(1'b1),
    .O(ddr4_c1_ck_t),
    .OB(ddr4_c1_ck_c)
);

end

endgenerate

// HBM
wire [HBM_CH-1:0]                     hbm_clk;
wire [HBM_CH-1:0]                     hbm_rst;

wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_awid;
wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]  m_axi_hbm_awaddr;
wire [HBM_CH*8-1:0]                   m_axi_hbm_awlen;
wire [HBM_CH*3-1:0]                   m_axi_hbm_awsize;
wire [HBM_CH*2-1:0]                   m_axi_hbm_awburst;
wire [HBM_CH-1:0]                     m_axi_hbm_awlock;
wire [HBM_CH*4-1:0]                   m_axi_hbm_awcache;
wire [HBM_CH*3-1:0]                   m_axi_hbm_awprot;
wire [HBM_CH*4-1:0]                   m_axi_hbm_awqos;
wire [HBM_CH-1:0]                     m_axi_hbm_awvalid;
wire [HBM_CH-1:0]                     m_axi_hbm_awready;
wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]  m_axi_hbm_wdata;
wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]  m_axi_hbm_wstrb;
wire [HBM_CH-1:0]                     m_axi_hbm_wlast;
wire [HBM_CH-1:0]                     m_axi_hbm_wvalid;
wire [HBM_CH-1:0]                     m_axi_hbm_wready;
wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_bid;
wire [HBM_CH*2-1:0]                   m_axi_hbm_bresp;
wire [HBM_CH-1:0]                     m_axi_hbm_bvalid;
wire [HBM_CH-1:0]                     m_axi_hbm_bready;
wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_arid;
wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]  m_axi_hbm_araddr;
wire [HBM_CH*8-1:0]                   m_axi_hbm_arlen;
wire [HBM_CH*3-1:0]                   m_axi_hbm_arsize;
wire [HBM_CH*2-1:0]                   m_axi_hbm_arburst;
wire [HBM_CH-1:0]                     m_axi_hbm_arlock;
wire [HBM_CH*4-1:0]                   m_axi_hbm_arcache;
wire [HBM_CH*3-1:0]                   m_axi_hbm_arprot;
wire [HBM_CH*4-1:0]                   m_axi_hbm_arqos;
wire [HBM_CH-1:0]                     m_axi_hbm_arvalid;
wire [HBM_CH-1:0]                     m_axi_hbm_arready;
wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]    m_axi_hbm_rid;
wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]  m_axi_hbm_rdata;
wire [HBM_CH*2-1:0]                   m_axi_hbm_rresp;
wire [HBM_CH-1:0]                     m_axi_hbm_rlast;
wire [HBM_CH-1:0]                     m_axi_hbm_rvalid;
wire [HBM_CH-1:0]                     m_axi_hbm_rready;

wire [HBM_CH-1:0]                     hbm_status;

generate

if (HBM_ENABLE) begin

wire hbm_ref_clk;

wire hbm_mmcm_rst;
wire hbm_mmcm_locked;
wire hbm_mmcm_clkfb;

wire hbm_axi_clk_mmcm;
wire hbm_axi_clk;
wire hbm_axi_rst_int;
wire hbm_axi_rst;

BUFG
hbm_ref_clk_bufg_inst (
    .I(clk_100mhz_0_ibufg),
    .O(hbm_ref_clk)
);

// HBM MMCM instance
// 100 MHz in, 450 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 800 MHz to 1600 MHz
// M = 9, D = 1 sets Fvco = 900 MHz
// Divide by 2 to get output frequency of 450 MHz
MMCME4_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(2),
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
    .CLKFBOUT_MULT_F(9),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(10.000),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
hbm_mmcm_inst (
    .CLKIN1(clk_100mhz_0_ibufg),
    .CLKFBIN(hbm_mmcm_clkfb),
    .RST(hbm_mmcm_rst),
    .PWRDWN(1'b0),
    .CLKOUT0(hbm_axi_clk_mmcm),
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
    .CLKFBOUT(hbm_mmcm_clkfb),
    .CLKFBOUTB(),
    .LOCKED(hbm_mmcm_locked)
);

BUFG
hbm_axi_clk_bufg_inst (
    .I(hbm_axi_clk_mmcm),
    .O(hbm_axi_clk)
);

sync_reset #(
    .N(4)
)
sync_reset_hbm_axi_inst (
    .clk(hbm_axi_clk),
    .rst(~hbm_mmcm_locked),
    .out(hbm_axi_rst_int)
);

// extra register for hbm_axi_rst signal
(* shreg_extract = "no" *)
reg hbm_axi_rst_reg_1 = 1'b1;
(* shreg_extract = "no" *)
reg hbm_axi_rst_reg_2 = 1'b1;

assign hbm_axi_rst = hbm_axi_rst_reg_2;

always @(posedge hbm_axi_clk) begin
    hbm_axi_rst_reg_1 <= hbm_axi_rst_int;
    hbm_axi_rst_reg_2 <= hbm_axi_rst_reg_1;
end

wire hbm_cattrip_1;
wire hbm_cattrip_2;

assign hbm_cattrip = hbm_cattrip_1 | hbm_cattrip_2;

assign hbm_clk = {HBM_CH{hbm_axi_clk}};
assign hbm_rst = {HBM_CH{hbm_axi_rst}};

hbm_0 hbm_inst (
    .HBM_REF_CLK_0(hbm_ref_clk),
    .HBM_REF_CLK_1(hbm_ref_clk),

    .APB_0_PWDATA(32'd0),
    .APB_0_PADDR(22'd0),
    .APB_0_PCLK(hbm_ref_clk),
    .APB_0_PENABLE(1'b0),
    .APB_0_PRESET_N(1'b1),
    .APB_0_PSEL(1'b0),
    .APB_0_PWRITE(1'b0),
    .APB_0_PRDATA(),
    .APB_0_PREADY(),
    .APB_0_PSLVERR(),
    .apb_complete_0(),

    .APB_1_PWDATA(32'd0),
    .APB_1_PADDR(22'd0),
    .APB_1_PCLK(hbm_ref_clk),
    .APB_1_PENABLE(1'b0),
    .APB_1_PRESET_N(1'b1),
    .APB_1_PSEL(1'b0),
    .APB_1_PWRITE(1'b0),
    .APB_1_PRDATA(),
    .APB_1_PREADY(),
    .APB_1_PSLVERR(),
    .apb_complete_1(),

    .AXI_00_ACLK(hbm_clk[0 +: 1]),
    .AXI_00_ARESET_N(!hbm_rst[0 +: 1]),

    .AXI_00_ARADDR(m_axi_hbm_araddr[0*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_00_ARBURST(m_axi_hbm_arburst[0*2 +: 2]),
    .AXI_00_ARID(m_axi_hbm_arid[0*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_00_ARLEN(m_axi_hbm_arlen[0*8 +: 8]),
    .AXI_00_ARSIZE(m_axi_hbm_arsize[0*3 +: 3]),
    .AXI_00_ARVALID(m_axi_hbm_arvalid[0 +: 1]),
    .AXI_00_ARREADY(m_axi_hbm_arready[0 +: 1]),
    .AXI_00_RDATA_PARITY(),
    .AXI_00_RDATA(m_axi_hbm_rdata[0*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_00_RID(m_axi_hbm_rid[0 +: 1]),
    .AXI_00_RLAST(m_axi_hbm_rlast[0 +: 1]),
    .AXI_00_RRESP(m_axi_hbm_rresp[0*2 +: 2]),
    .AXI_00_RVALID(m_axi_hbm_rvalid[0 +: 1]),
    .AXI_00_RREADY(m_axi_hbm_rready[0 +: 1]),
    .AXI_00_AWADDR(m_axi_hbm_awaddr[0*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_00_AWBURST(m_axi_hbm_awburst[0*2 +: 2]),
    .AXI_00_AWID(m_axi_hbm_awid[0*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_00_AWLEN(m_axi_hbm_awlen[0*8 +: 8]),
    .AXI_00_AWSIZE(m_axi_hbm_awsize[0*3 +: 3]),
    .AXI_00_AWVALID(m_axi_hbm_awvalid[0 +: 1]),
    .AXI_00_AWREADY(m_axi_hbm_awready[0 +: 1]),
    .AXI_00_WDATA(m_axi_hbm_wdata[0*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_00_WLAST(m_axi_hbm_wlast[0 +: 1]),
    .AXI_00_WSTRB(m_axi_hbm_wstrb[0*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_00_WDATA_PARITY(32'd0),
    .AXI_00_WVALID(m_axi_hbm_wvalid[0 +: 1]),
    .AXI_00_WREADY(m_axi_hbm_wready[0 +: 1]),
    .AXI_00_BID(m_axi_hbm_bid[0*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_00_BRESP(m_axi_hbm_bresp[0*2 +: 2]),
    .AXI_00_BVALID(m_axi_hbm_bvalid[0 +: 1]),
    .AXI_00_BREADY(m_axi_hbm_bready[0 +: 1]),

    .AXI_01_ACLK(hbm_clk[1 +: 1]),
    .AXI_01_ARESET_N(!hbm_rst[1 +: 1]),

    .AXI_01_ARADDR(m_axi_hbm_araddr[1*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_01_ARBURST(m_axi_hbm_arburst[1*2 +: 2]),
    .AXI_01_ARID(m_axi_hbm_arid[1*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_01_ARLEN(m_axi_hbm_arlen[1*8 +: 8]),
    .AXI_01_ARSIZE(m_axi_hbm_arsize[1*3 +: 3]),
    .AXI_01_ARVALID(m_axi_hbm_arvalid[1 +: 1]),
    .AXI_01_ARREADY(m_axi_hbm_arready[1 +: 1]),
    .AXI_01_RDATA_PARITY(),
    .AXI_01_RDATA(m_axi_hbm_rdata[1*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_01_RID(m_axi_hbm_rid[1 +: 1]),
    .AXI_01_RLAST(m_axi_hbm_rlast[1 +: 1]),
    .AXI_01_RRESP(m_axi_hbm_rresp[1*2 +: 2]),
    .AXI_01_RVALID(m_axi_hbm_rvalid[1 +: 1]),
    .AXI_01_RREADY(m_axi_hbm_rready[1 +: 1]),
    .AXI_01_AWADDR(m_axi_hbm_awaddr[1*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_01_AWBURST(m_axi_hbm_awburst[1*2 +: 2]),
    .AXI_01_AWID(m_axi_hbm_awid[1*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_01_AWLEN(m_axi_hbm_awlen[1*8 +: 8]),
    .AXI_01_AWSIZE(m_axi_hbm_awsize[1*3 +: 3]),
    .AXI_01_AWVALID(m_axi_hbm_awvalid[1 +: 1]),
    .AXI_01_AWREADY(m_axi_hbm_awready[1 +: 1]),
    .AXI_01_WDATA(m_axi_hbm_wdata[1*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_01_WLAST(m_axi_hbm_wlast[1 +: 1]),
    .AXI_01_WSTRB(m_axi_hbm_wstrb[1*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_01_WDATA_PARITY(32'd0),
    .AXI_01_WVALID(m_axi_hbm_wvalid[1 +: 1]),
    .AXI_01_WREADY(m_axi_hbm_wready[1 +: 1]),
    .AXI_01_BID(m_axi_hbm_bid[1*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_01_BRESP(m_axi_hbm_bresp[1*2 +: 2]),
    .AXI_01_BVALID(m_axi_hbm_bvalid[1 +: 1]),
    .AXI_01_BREADY(m_axi_hbm_bready[1 +: 1]),

    .AXI_02_ACLK(hbm_clk[2 +: 1]),
    .AXI_02_ARESET_N(!hbm_rst[2 +: 1]),

    .AXI_02_ARADDR(m_axi_hbm_araddr[2*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_02_ARBURST(m_axi_hbm_arburst[2*2 +: 2]),
    .AXI_02_ARID(m_axi_hbm_arid[2*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_02_ARLEN(m_axi_hbm_arlen[2*8 +: 8]),
    .AXI_02_ARSIZE(m_axi_hbm_arsize[2*3 +: 3]),
    .AXI_02_ARVALID(m_axi_hbm_arvalid[2 +: 1]),
    .AXI_02_ARREADY(m_axi_hbm_arready[2 +: 1]),
    .AXI_02_RDATA_PARITY(),
    .AXI_02_RDATA(m_axi_hbm_rdata[2*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_02_RID(m_axi_hbm_rid[2 +: 1]),
    .AXI_02_RLAST(m_axi_hbm_rlast[2 +: 1]),
    .AXI_02_RRESP(m_axi_hbm_rresp[2*2 +: 2]),
    .AXI_02_RVALID(m_axi_hbm_rvalid[2 +: 1]),
    .AXI_02_RREADY(m_axi_hbm_rready[2 +: 1]),
    .AXI_02_AWADDR(m_axi_hbm_awaddr[2*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_02_AWBURST(m_axi_hbm_awburst[2*2 +: 2]),
    .AXI_02_AWID(m_axi_hbm_awid[2*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_02_AWLEN(m_axi_hbm_awlen[2*8 +: 8]),
    .AXI_02_AWSIZE(m_axi_hbm_awsize[2*3 +: 3]),
    .AXI_02_AWVALID(m_axi_hbm_awvalid[2 +: 1]),
    .AXI_02_AWREADY(m_axi_hbm_awready[2 +: 1]),
    .AXI_02_WDATA(m_axi_hbm_wdata[2*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_02_WLAST(m_axi_hbm_wlast[2 +: 1]),
    .AXI_02_WSTRB(m_axi_hbm_wstrb[2*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_02_WDATA_PARITY(32'd0),
    .AXI_02_WVALID(m_axi_hbm_wvalid[2 +: 1]),
    .AXI_02_WREADY(m_axi_hbm_wready[2 +: 1]),
    .AXI_02_BID(m_axi_hbm_bid[2*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_02_BRESP(m_axi_hbm_bresp[2*2 +: 2]),
    .AXI_02_BVALID(m_axi_hbm_bvalid[2 +: 1]),
    .AXI_02_BREADY(m_axi_hbm_bready[2 +: 1]),

    .AXI_03_ACLK(hbm_clk[3 +: 1]),
    .AXI_03_ARESET_N(!hbm_rst[3 +: 1]),

    .AXI_03_ARADDR(m_axi_hbm_araddr[3*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_03_ARBURST(m_axi_hbm_arburst[3*2 +: 2]),
    .AXI_03_ARID(m_axi_hbm_arid[3*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_03_ARLEN(m_axi_hbm_arlen[3*8 +: 8]),
    .AXI_03_ARSIZE(m_axi_hbm_arsize[3*3 +: 3]),
    .AXI_03_ARVALID(m_axi_hbm_arvalid[3 +: 1]),
    .AXI_03_ARREADY(m_axi_hbm_arready[3 +: 1]),
    .AXI_03_RDATA_PARITY(),
    .AXI_03_RDATA(m_axi_hbm_rdata[3*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_03_RID(m_axi_hbm_rid[3 +: 1]),
    .AXI_03_RLAST(m_axi_hbm_rlast[3 +: 1]),
    .AXI_03_RRESP(m_axi_hbm_rresp[3*2 +: 2]),
    .AXI_03_RVALID(m_axi_hbm_rvalid[3 +: 1]),
    .AXI_03_RREADY(m_axi_hbm_rready[3 +: 1]),
    .AXI_03_AWADDR(m_axi_hbm_awaddr[3*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_03_AWBURST(m_axi_hbm_awburst[3*2 +: 2]),
    .AXI_03_AWID(m_axi_hbm_awid[3*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_03_AWLEN(m_axi_hbm_awlen[3*8 +: 8]),
    .AXI_03_AWSIZE(m_axi_hbm_awsize[3*3 +: 3]),
    .AXI_03_AWVALID(m_axi_hbm_awvalid[3 +: 1]),
    .AXI_03_AWREADY(m_axi_hbm_awready[3 +: 1]),
    .AXI_03_WDATA(m_axi_hbm_wdata[3*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_03_WLAST(m_axi_hbm_wlast[3 +: 1]),
    .AXI_03_WSTRB(m_axi_hbm_wstrb[3*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_03_WDATA_PARITY(32'd0),
    .AXI_03_WVALID(m_axi_hbm_wvalid[3 +: 1]),
    .AXI_03_WREADY(m_axi_hbm_wready[3 +: 1]),
    .AXI_03_BID(m_axi_hbm_bid[3*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_03_BRESP(m_axi_hbm_bresp[3*2 +: 2]),
    .AXI_03_BVALID(m_axi_hbm_bvalid[3 +: 1]),
    .AXI_03_BREADY(m_axi_hbm_bready[3 +: 1]),

    .AXI_04_ACLK(hbm_clk[4 +: 1]),
    .AXI_04_ARESET_N(!hbm_rst[4 +: 1]),

    .AXI_04_ARADDR(m_axi_hbm_araddr[4*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_04_ARBURST(m_axi_hbm_arburst[4*2 +: 2]),
    .AXI_04_ARID(m_axi_hbm_arid[4*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_04_ARLEN(m_axi_hbm_arlen[4*8 +: 8]),
    .AXI_04_ARSIZE(m_axi_hbm_arsize[4*3 +: 3]),
    .AXI_04_ARVALID(m_axi_hbm_arvalid[4 +: 1]),
    .AXI_04_ARREADY(m_axi_hbm_arready[4 +: 1]),
    .AXI_04_RDATA_PARITY(),
    .AXI_04_RDATA(m_axi_hbm_rdata[4*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_04_RID(m_axi_hbm_rid[4 +: 1]),
    .AXI_04_RLAST(m_axi_hbm_rlast[4 +: 1]),
    .AXI_04_RRESP(m_axi_hbm_rresp[4*2 +: 2]),
    .AXI_04_RVALID(m_axi_hbm_rvalid[4 +: 1]),
    .AXI_04_RREADY(m_axi_hbm_rready[4 +: 1]),
    .AXI_04_AWADDR(m_axi_hbm_awaddr[4*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_04_AWBURST(m_axi_hbm_awburst[4*2 +: 2]),
    .AXI_04_AWID(m_axi_hbm_awid[4*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_04_AWLEN(m_axi_hbm_awlen[4*8 +: 8]),
    .AXI_04_AWSIZE(m_axi_hbm_awsize[4*3 +: 3]),
    .AXI_04_AWVALID(m_axi_hbm_awvalid[4 +: 1]),
    .AXI_04_AWREADY(m_axi_hbm_awready[4 +: 1]),
    .AXI_04_WDATA(m_axi_hbm_wdata[4*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_04_WLAST(m_axi_hbm_wlast[4 +: 1]),
    .AXI_04_WSTRB(m_axi_hbm_wstrb[4*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_04_WDATA_PARITY(32'd0),
    .AXI_04_WVALID(m_axi_hbm_wvalid[4 +: 1]),
    .AXI_04_WREADY(m_axi_hbm_wready[4 +: 1]),
    .AXI_04_BID(m_axi_hbm_bid[4*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_04_BRESP(m_axi_hbm_bresp[4*2 +: 2]),
    .AXI_04_BVALID(m_axi_hbm_bvalid[4 +: 1]),
    .AXI_04_BREADY(m_axi_hbm_bready[4 +: 1]),

    .AXI_05_ACLK(hbm_clk[5 +: 1]),
    .AXI_05_ARESET_N(!hbm_rst[5 +: 1]),

    .AXI_05_ARADDR(m_axi_hbm_araddr[5*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_05_ARBURST(m_axi_hbm_arburst[5*2 +: 2]),
    .AXI_05_ARID(m_axi_hbm_arid[5*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_05_ARLEN(m_axi_hbm_arlen[5*8 +: 8]),
    .AXI_05_ARSIZE(m_axi_hbm_arsize[5*3 +: 3]),
    .AXI_05_ARVALID(m_axi_hbm_arvalid[5 +: 1]),
    .AXI_05_ARREADY(m_axi_hbm_arready[5 +: 1]),
    .AXI_05_RDATA_PARITY(),
    .AXI_05_RDATA(m_axi_hbm_rdata[5*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_05_RID(m_axi_hbm_rid[5 +: 1]),
    .AXI_05_RLAST(m_axi_hbm_rlast[5 +: 1]),
    .AXI_05_RRESP(m_axi_hbm_rresp[5*2 +: 2]),
    .AXI_05_RVALID(m_axi_hbm_rvalid[5 +: 1]),
    .AXI_05_RREADY(m_axi_hbm_rready[5 +: 1]),
    .AXI_05_AWADDR(m_axi_hbm_awaddr[5*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_05_AWBURST(m_axi_hbm_awburst[5*2 +: 2]),
    .AXI_05_AWID(m_axi_hbm_awid[5*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_05_AWLEN(m_axi_hbm_awlen[5*8 +: 8]),
    .AXI_05_AWSIZE(m_axi_hbm_awsize[5*3 +: 3]),
    .AXI_05_AWVALID(m_axi_hbm_awvalid[5 +: 1]),
    .AXI_05_AWREADY(m_axi_hbm_awready[5 +: 1]),
    .AXI_05_WDATA(m_axi_hbm_wdata[5*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_05_WLAST(m_axi_hbm_wlast[5 +: 1]),
    .AXI_05_WSTRB(m_axi_hbm_wstrb[5*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_05_WDATA_PARITY(32'd0),
    .AXI_05_WVALID(m_axi_hbm_wvalid[5 +: 1]),
    .AXI_05_WREADY(m_axi_hbm_wready[5 +: 1]),
    .AXI_05_BID(m_axi_hbm_bid[5*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_05_BRESP(m_axi_hbm_bresp[5*2 +: 2]),
    .AXI_05_BVALID(m_axi_hbm_bvalid[5 +: 1]),
    .AXI_05_BREADY(m_axi_hbm_bready[5 +: 1]),

    .AXI_06_ACLK(hbm_clk[6 +: 1]),
    .AXI_06_ARESET_N(!hbm_rst[6 +: 1]),

    .AXI_06_ARADDR(m_axi_hbm_araddr[6*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_06_ARBURST(m_axi_hbm_arburst[6*2 +: 2]),
    .AXI_06_ARID(m_axi_hbm_arid[6*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_06_ARLEN(m_axi_hbm_arlen[6*8 +: 8]),
    .AXI_06_ARSIZE(m_axi_hbm_arsize[6*3 +: 3]),
    .AXI_06_ARVALID(m_axi_hbm_arvalid[6 +: 1]),
    .AXI_06_ARREADY(m_axi_hbm_arready[6 +: 1]),
    .AXI_06_RDATA_PARITY(),
    .AXI_06_RDATA(m_axi_hbm_rdata[6*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_06_RID(m_axi_hbm_rid[6 +: 1]),
    .AXI_06_RLAST(m_axi_hbm_rlast[6 +: 1]),
    .AXI_06_RRESP(m_axi_hbm_rresp[6*2 +: 2]),
    .AXI_06_RVALID(m_axi_hbm_rvalid[6 +: 1]),
    .AXI_06_RREADY(m_axi_hbm_rready[6 +: 1]),
    .AXI_06_AWADDR(m_axi_hbm_awaddr[6*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_06_AWBURST(m_axi_hbm_awburst[6*2 +: 2]),
    .AXI_06_AWID(m_axi_hbm_awid[6*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_06_AWLEN(m_axi_hbm_awlen[6*8 +: 8]),
    .AXI_06_AWSIZE(m_axi_hbm_awsize[6*3 +: 3]),
    .AXI_06_AWVALID(m_axi_hbm_awvalid[6 +: 1]),
    .AXI_06_AWREADY(m_axi_hbm_awready[6 +: 1]),
    .AXI_06_WDATA(m_axi_hbm_wdata[6*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_06_WLAST(m_axi_hbm_wlast[6 +: 1]),
    .AXI_06_WSTRB(m_axi_hbm_wstrb[6*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_06_WDATA_PARITY(32'd0),
    .AXI_06_WVALID(m_axi_hbm_wvalid[6 +: 1]),
    .AXI_06_WREADY(m_axi_hbm_wready[6 +: 1]),
    .AXI_06_BID(m_axi_hbm_bid[6*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_06_BRESP(m_axi_hbm_bresp[6*2 +: 2]),
    .AXI_06_BVALID(m_axi_hbm_bvalid[6 +: 1]),
    .AXI_06_BREADY(m_axi_hbm_bready[6 +: 1]),

    .AXI_07_ACLK(hbm_clk[7 +: 1]),
    .AXI_07_ARESET_N(!hbm_rst[7 +: 1]),

    .AXI_07_ARADDR(m_axi_hbm_araddr[7*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_07_ARBURST(m_axi_hbm_arburst[7*2 +: 2]),
    .AXI_07_ARID(m_axi_hbm_arid[7*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_07_ARLEN(m_axi_hbm_arlen[7*8 +: 8]),
    .AXI_07_ARSIZE(m_axi_hbm_arsize[7*3 +: 3]),
    .AXI_07_ARVALID(m_axi_hbm_arvalid[7 +: 1]),
    .AXI_07_ARREADY(m_axi_hbm_arready[7 +: 1]),
    .AXI_07_RDATA_PARITY(),
    .AXI_07_RDATA(m_axi_hbm_rdata[7*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_07_RID(m_axi_hbm_rid[7 +: 1]),
    .AXI_07_RLAST(m_axi_hbm_rlast[7 +: 1]),
    .AXI_07_RRESP(m_axi_hbm_rresp[7*2 +: 2]),
    .AXI_07_RVALID(m_axi_hbm_rvalid[7 +: 1]),
    .AXI_07_RREADY(m_axi_hbm_rready[7 +: 1]),
    .AXI_07_AWADDR(m_axi_hbm_awaddr[7*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_07_AWBURST(m_axi_hbm_awburst[7*2 +: 2]),
    .AXI_07_AWID(m_axi_hbm_awid[7*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_07_AWLEN(m_axi_hbm_awlen[7*8 +: 8]),
    .AXI_07_AWSIZE(m_axi_hbm_awsize[7*3 +: 3]),
    .AXI_07_AWVALID(m_axi_hbm_awvalid[7 +: 1]),
    .AXI_07_AWREADY(m_axi_hbm_awready[7 +: 1]),
    .AXI_07_WDATA(m_axi_hbm_wdata[7*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_07_WLAST(m_axi_hbm_wlast[7 +: 1]),
    .AXI_07_WSTRB(m_axi_hbm_wstrb[7*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_07_WDATA_PARITY(32'd0),
    .AXI_07_WVALID(m_axi_hbm_wvalid[7 +: 1]),
    .AXI_07_WREADY(m_axi_hbm_wready[7 +: 1]),
    .AXI_07_BID(m_axi_hbm_bid[7*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_07_BRESP(m_axi_hbm_bresp[7*2 +: 2]),
    .AXI_07_BVALID(m_axi_hbm_bvalid[7 +: 1]),
    .AXI_07_BREADY(m_axi_hbm_bready[7 +: 1]),

    .AXI_08_ACLK(hbm_clk[8 +: 1]),
    .AXI_08_ARESET_N(!hbm_rst[8 +: 1]),

    .AXI_08_ARADDR(m_axi_hbm_araddr[8*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_08_ARBURST(m_axi_hbm_arburst[8*2 +: 2]),
    .AXI_08_ARID(m_axi_hbm_arid[8*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_08_ARLEN(m_axi_hbm_arlen[8*8 +: 8]),
    .AXI_08_ARSIZE(m_axi_hbm_arsize[8*3 +: 3]),
    .AXI_08_ARVALID(m_axi_hbm_arvalid[8 +: 1]),
    .AXI_08_ARREADY(m_axi_hbm_arready[8 +: 1]),
    .AXI_08_RDATA_PARITY(),
    .AXI_08_RDATA(m_axi_hbm_rdata[8*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_08_RID(m_axi_hbm_rid[8 +: 1]),
    .AXI_08_RLAST(m_axi_hbm_rlast[8 +: 1]),
    .AXI_08_RRESP(m_axi_hbm_rresp[8*2 +: 2]),
    .AXI_08_RVALID(m_axi_hbm_rvalid[8 +: 1]),
    .AXI_08_RREADY(m_axi_hbm_rready[8 +: 1]),
    .AXI_08_AWADDR(m_axi_hbm_awaddr[8*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_08_AWBURST(m_axi_hbm_awburst[8*2 +: 2]),
    .AXI_08_AWID(m_axi_hbm_awid[8*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_08_AWLEN(m_axi_hbm_awlen[8*8 +: 8]),
    .AXI_08_AWSIZE(m_axi_hbm_awsize[8*3 +: 3]),
    .AXI_08_AWVALID(m_axi_hbm_awvalid[8 +: 1]),
    .AXI_08_AWREADY(m_axi_hbm_awready[8 +: 1]),
    .AXI_08_WDATA(m_axi_hbm_wdata[8*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_08_WLAST(m_axi_hbm_wlast[8 +: 1]),
    .AXI_08_WSTRB(m_axi_hbm_wstrb[8*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_08_WDATA_PARITY(32'd0),
    .AXI_08_WVALID(m_axi_hbm_wvalid[8 +: 1]),
    .AXI_08_WREADY(m_axi_hbm_wready[8 +: 1]),
    .AXI_08_BID(m_axi_hbm_bid[8*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_08_BRESP(m_axi_hbm_bresp[8*2 +: 2]),
    .AXI_08_BVALID(m_axi_hbm_bvalid[8 +: 1]),
    .AXI_08_BREADY(m_axi_hbm_bready[8 +: 1]),

    .AXI_09_ACLK(hbm_clk[9 +: 1]),
    .AXI_09_ARESET_N(!hbm_rst[9 +: 1]),

    .AXI_09_ARADDR(m_axi_hbm_araddr[9*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_09_ARBURST(m_axi_hbm_arburst[9*2 +: 2]),
    .AXI_09_ARID(m_axi_hbm_arid[9*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_09_ARLEN(m_axi_hbm_arlen[9*8 +: 8]),
    .AXI_09_ARSIZE(m_axi_hbm_arsize[9*3 +: 3]),
    .AXI_09_ARVALID(m_axi_hbm_arvalid[9 +: 1]),
    .AXI_09_ARREADY(m_axi_hbm_arready[9 +: 1]),
    .AXI_09_RDATA_PARITY(),
    .AXI_09_RDATA(m_axi_hbm_rdata[9*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_09_RID(m_axi_hbm_rid[9 +: 1]),
    .AXI_09_RLAST(m_axi_hbm_rlast[9 +: 1]),
    .AXI_09_RRESP(m_axi_hbm_rresp[9*2 +: 2]),
    .AXI_09_RVALID(m_axi_hbm_rvalid[9 +: 1]),
    .AXI_09_RREADY(m_axi_hbm_rready[9 +: 1]),
    .AXI_09_AWADDR(m_axi_hbm_awaddr[9*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_09_AWBURST(m_axi_hbm_awburst[9*2 +: 2]),
    .AXI_09_AWID(m_axi_hbm_awid[9*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_09_AWLEN(m_axi_hbm_awlen[9*8 +: 8]),
    .AXI_09_AWSIZE(m_axi_hbm_awsize[9*3 +: 3]),
    .AXI_09_AWVALID(m_axi_hbm_awvalid[9 +: 1]),
    .AXI_09_AWREADY(m_axi_hbm_awready[9 +: 1]),
    .AXI_09_WDATA(m_axi_hbm_wdata[9*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_09_WLAST(m_axi_hbm_wlast[9 +: 1]),
    .AXI_09_WSTRB(m_axi_hbm_wstrb[9*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_09_WDATA_PARITY(32'd0),
    .AXI_09_WVALID(m_axi_hbm_wvalid[9 +: 1]),
    .AXI_09_WREADY(m_axi_hbm_wready[9 +: 1]),
    .AXI_09_BID(m_axi_hbm_bid[9*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_09_BRESP(m_axi_hbm_bresp[9*2 +: 2]),
    .AXI_09_BVALID(m_axi_hbm_bvalid[9 +: 1]),
    .AXI_09_BREADY(m_axi_hbm_bready[9 +: 1]),

    .AXI_10_ACLK(hbm_clk[10 +: 1]),
    .AXI_10_ARESET_N(!hbm_rst[10 +: 1]),

    .AXI_10_ARADDR(m_axi_hbm_araddr[10*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_10_ARBURST(m_axi_hbm_arburst[10*2 +: 2]),
    .AXI_10_ARID(m_axi_hbm_arid[10*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_10_ARLEN(m_axi_hbm_arlen[10*8 +: 8]),
    .AXI_10_ARSIZE(m_axi_hbm_arsize[10*3 +: 3]),
    .AXI_10_ARVALID(m_axi_hbm_arvalid[10 +: 1]),
    .AXI_10_ARREADY(m_axi_hbm_arready[10 +: 1]),
    .AXI_10_RDATA_PARITY(),
    .AXI_10_RDATA(m_axi_hbm_rdata[10*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_10_RID(m_axi_hbm_rid[10 +: 1]),
    .AXI_10_RLAST(m_axi_hbm_rlast[10 +: 1]),
    .AXI_10_RRESP(m_axi_hbm_rresp[10*2 +: 2]),
    .AXI_10_RVALID(m_axi_hbm_rvalid[10 +: 1]),
    .AXI_10_RREADY(m_axi_hbm_rready[10 +: 1]),
    .AXI_10_AWADDR(m_axi_hbm_awaddr[10*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_10_AWBURST(m_axi_hbm_awburst[10*2 +: 2]),
    .AXI_10_AWID(m_axi_hbm_awid[10*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_10_AWLEN(m_axi_hbm_awlen[10*8 +: 8]),
    .AXI_10_AWSIZE(m_axi_hbm_awsize[10*3 +: 3]),
    .AXI_10_AWVALID(m_axi_hbm_awvalid[10 +: 1]),
    .AXI_10_AWREADY(m_axi_hbm_awready[10 +: 1]),
    .AXI_10_WDATA(m_axi_hbm_wdata[10*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_10_WLAST(m_axi_hbm_wlast[10 +: 1]),
    .AXI_10_WSTRB(m_axi_hbm_wstrb[10*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_10_WDATA_PARITY(32'd0),
    .AXI_10_WVALID(m_axi_hbm_wvalid[10 +: 1]),
    .AXI_10_WREADY(m_axi_hbm_wready[10 +: 1]),
    .AXI_10_BID(m_axi_hbm_bid[10*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_10_BRESP(m_axi_hbm_bresp[10*2 +: 2]),
    .AXI_10_BVALID(m_axi_hbm_bvalid[10 +: 1]),
    .AXI_10_BREADY(m_axi_hbm_bready[10 +: 1]),

    .AXI_11_ACLK(hbm_clk[11 +: 1]),
    .AXI_11_ARESET_N(!hbm_rst[11 +: 1]),

    .AXI_11_ARADDR(m_axi_hbm_araddr[11*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_11_ARBURST(m_axi_hbm_arburst[11*2 +: 2]),
    .AXI_11_ARID(m_axi_hbm_arid[11*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_11_ARLEN(m_axi_hbm_arlen[11*8 +: 8]),
    .AXI_11_ARSIZE(m_axi_hbm_arsize[11*3 +: 3]),
    .AXI_11_ARVALID(m_axi_hbm_arvalid[11 +: 1]),
    .AXI_11_ARREADY(m_axi_hbm_arready[11 +: 1]),
    .AXI_11_RDATA_PARITY(),
    .AXI_11_RDATA(m_axi_hbm_rdata[11*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_11_RID(m_axi_hbm_rid[11 +: 1]),
    .AXI_11_RLAST(m_axi_hbm_rlast[11 +: 1]),
    .AXI_11_RRESP(m_axi_hbm_rresp[11*2 +: 2]),
    .AXI_11_RVALID(m_axi_hbm_rvalid[11 +: 1]),
    .AXI_11_RREADY(m_axi_hbm_rready[11 +: 1]),
    .AXI_11_AWADDR(m_axi_hbm_awaddr[11*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_11_AWBURST(m_axi_hbm_awburst[11*2 +: 2]),
    .AXI_11_AWID(m_axi_hbm_awid[11*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_11_AWLEN(m_axi_hbm_awlen[11*8 +: 8]),
    .AXI_11_AWSIZE(m_axi_hbm_awsize[11*3 +: 3]),
    .AXI_11_AWVALID(m_axi_hbm_awvalid[11 +: 1]),
    .AXI_11_AWREADY(m_axi_hbm_awready[11 +: 1]),
    .AXI_11_WDATA(m_axi_hbm_wdata[11*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_11_WLAST(m_axi_hbm_wlast[11 +: 1]),
    .AXI_11_WSTRB(m_axi_hbm_wstrb[11*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_11_WDATA_PARITY(32'd0),
    .AXI_11_WVALID(m_axi_hbm_wvalid[11 +: 1]),
    .AXI_11_WREADY(m_axi_hbm_wready[11 +: 1]),
    .AXI_11_BID(m_axi_hbm_bid[11*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_11_BRESP(m_axi_hbm_bresp[11*2 +: 2]),
    .AXI_11_BVALID(m_axi_hbm_bvalid[11 +: 1]),
    .AXI_11_BREADY(m_axi_hbm_bready[11 +: 1]),

    .AXI_12_ACLK(hbm_clk[12 +: 1]),
    .AXI_12_ARESET_N(!hbm_rst[12 +: 1]),

    .AXI_12_ARADDR(m_axi_hbm_araddr[12*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_12_ARBURST(m_axi_hbm_arburst[12*2 +: 2]),
    .AXI_12_ARID(m_axi_hbm_arid[12*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_12_ARLEN(m_axi_hbm_arlen[12*8 +: 8]),
    .AXI_12_ARSIZE(m_axi_hbm_arsize[12*3 +: 3]),
    .AXI_12_ARVALID(m_axi_hbm_arvalid[12 +: 1]),
    .AXI_12_ARREADY(m_axi_hbm_arready[12 +: 1]),
    .AXI_12_RDATA_PARITY(),
    .AXI_12_RDATA(m_axi_hbm_rdata[12*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_12_RID(m_axi_hbm_rid[12 +: 1]),
    .AXI_12_RLAST(m_axi_hbm_rlast[12 +: 1]),
    .AXI_12_RRESP(m_axi_hbm_rresp[12*2 +: 2]),
    .AXI_12_RVALID(m_axi_hbm_rvalid[12 +: 1]),
    .AXI_12_RREADY(m_axi_hbm_rready[12 +: 1]),
    .AXI_12_AWADDR(m_axi_hbm_awaddr[12*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_12_AWBURST(m_axi_hbm_awburst[12*2 +: 2]),
    .AXI_12_AWID(m_axi_hbm_awid[12*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_12_AWLEN(m_axi_hbm_awlen[12*8 +: 8]),
    .AXI_12_AWSIZE(m_axi_hbm_awsize[12*3 +: 3]),
    .AXI_12_AWVALID(m_axi_hbm_awvalid[12 +: 1]),
    .AXI_12_AWREADY(m_axi_hbm_awready[12 +: 1]),
    .AXI_12_WDATA(m_axi_hbm_wdata[12*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_12_WLAST(m_axi_hbm_wlast[12 +: 1]),
    .AXI_12_WSTRB(m_axi_hbm_wstrb[12*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_12_WDATA_PARITY(32'd0),
    .AXI_12_WVALID(m_axi_hbm_wvalid[12 +: 1]),
    .AXI_12_WREADY(m_axi_hbm_wready[12 +: 1]),
    .AXI_12_BID(m_axi_hbm_bid[12*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_12_BRESP(m_axi_hbm_bresp[12*2 +: 2]),
    .AXI_12_BVALID(m_axi_hbm_bvalid[12 +: 1]),
    .AXI_12_BREADY(m_axi_hbm_bready[12 +: 1]),

    .AXI_13_ACLK(hbm_clk[13 +: 1]),
    .AXI_13_ARESET_N(!hbm_rst[13 +: 1]),

    .AXI_13_ARADDR(m_axi_hbm_araddr[13*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_13_ARBURST(m_axi_hbm_arburst[13*2 +: 2]),
    .AXI_13_ARID(m_axi_hbm_arid[13*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_13_ARLEN(m_axi_hbm_arlen[13*8 +: 8]),
    .AXI_13_ARSIZE(m_axi_hbm_arsize[13*3 +: 3]),
    .AXI_13_ARVALID(m_axi_hbm_arvalid[13 +: 1]),
    .AXI_13_ARREADY(m_axi_hbm_arready[13 +: 1]),
    .AXI_13_RDATA_PARITY(),
    .AXI_13_RDATA(m_axi_hbm_rdata[13*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_13_RID(m_axi_hbm_rid[13 +: 1]),
    .AXI_13_RLAST(m_axi_hbm_rlast[13 +: 1]),
    .AXI_13_RRESP(m_axi_hbm_rresp[13*2 +: 2]),
    .AXI_13_RVALID(m_axi_hbm_rvalid[13 +: 1]),
    .AXI_13_RREADY(m_axi_hbm_rready[13 +: 1]),
    .AXI_13_AWADDR(m_axi_hbm_awaddr[13*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_13_AWBURST(m_axi_hbm_awburst[13*2 +: 2]),
    .AXI_13_AWID(m_axi_hbm_awid[13*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_13_AWLEN(m_axi_hbm_awlen[13*8 +: 8]),
    .AXI_13_AWSIZE(m_axi_hbm_awsize[13*3 +: 3]),
    .AXI_13_AWVALID(m_axi_hbm_awvalid[13 +: 1]),
    .AXI_13_AWREADY(m_axi_hbm_awready[13 +: 1]),
    .AXI_13_WDATA(m_axi_hbm_wdata[13*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_13_WLAST(m_axi_hbm_wlast[13 +: 1]),
    .AXI_13_WSTRB(m_axi_hbm_wstrb[13*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_13_WDATA_PARITY(32'd0),
    .AXI_13_WVALID(m_axi_hbm_wvalid[13 +: 1]),
    .AXI_13_WREADY(m_axi_hbm_wready[13 +: 1]),
    .AXI_13_BID(m_axi_hbm_bid[13*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_13_BRESP(m_axi_hbm_bresp[13*2 +: 2]),
    .AXI_13_BVALID(m_axi_hbm_bvalid[13 +: 1]),
    .AXI_13_BREADY(m_axi_hbm_bready[13 +: 1]),

    .AXI_14_ACLK(hbm_clk[14 +: 1]),
    .AXI_14_ARESET_N(!hbm_rst[14 +: 1]),

    .AXI_14_ARADDR(m_axi_hbm_araddr[14*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_14_ARBURST(m_axi_hbm_arburst[14*2 +: 2]),
    .AXI_14_ARID(m_axi_hbm_arid[14*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_14_ARLEN(m_axi_hbm_arlen[14*8 +: 8]),
    .AXI_14_ARSIZE(m_axi_hbm_arsize[14*3 +: 3]),
    .AXI_14_ARVALID(m_axi_hbm_arvalid[14 +: 1]),
    .AXI_14_ARREADY(m_axi_hbm_arready[14 +: 1]),
    .AXI_14_RDATA_PARITY(),
    .AXI_14_RDATA(m_axi_hbm_rdata[14*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_14_RID(m_axi_hbm_rid[14 +: 1]),
    .AXI_14_RLAST(m_axi_hbm_rlast[14 +: 1]),
    .AXI_14_RRESP(m_axi_hbm_rresp[14*2 +: 2]),
    .AXI_14_RVALID(m_axi_hbm_rvalid[14 +: 1]),
    .AXI_14_RREADY(m_axi_hbm_rready[14 +: 1]),
    .AXI_14_AWADDR(m_axi_hbm_awaddr[14*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_14_AWBURST(m_axi_hbm_awburst[14*2 +: 2]),
    .AXI_14_AWID(m_axi_hbm_awid[14*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_14_AWLEN(m_axi_hbm_awlen[14*8 +: 8]),
    .AXI_14_AWSIZE(m_axi_hbm_awsize[14*3 +: 3]),
    .AXI_14_AWVALID(m_axi_hbm_awvalid[14 +: 1]),
    .AXI_14_AWREADY(m_axi_hbm_awready[14 +: 1]),
    .AXI_14_WDATA(m_axi_hbm_wdata[14*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_14_WLAST(m_axi_hbm_wlast[14 +: 1]),
    .AXI_14_WSTRB(m_axi_hbm_wstrb[14*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_14_WDATA_PARITY(32'd0),
    .AXI_14_WVALID(m_axi_hbm_wvalid[14 +: 1]),
    .AXI_14_WREADY(m_axi_hbm_wready[14 +: 1]),
    .AXI_14_BID(m_axi_hbm_bid[14*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_14_BRESP(m_axi_hbm_bresp[14*2 +: 2]),
    .AXI_14_BVALID(m_axi_hbm_bvalid[14 +: 1]),
    .AXI_14_BREADY(m_axi_hbm_bready[14 +: 1]),

    .AXI_15_ACLK(hbm_clk[15 +: 1]),
    .AXI_15_ARESET_N(!hbm_rst[15 +: 1]),

    .AXI_15_ARADDR(m_axi_hbm_araddr[15*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_15_ARBURST(m_axi_hbm_arburst[15*2 +: 2]),
    .AXI_15_ARID(m_axi_hbm_arid[15*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_15_ARLEN(m_axi_hbm_arlen[15*8 +: 8]),
    .AXI_15_ARSIZE(m_axi_hbm_arsize[15*3 +: 3]),
    .AXI_15_ARVALID(m_axi_hbm_arvalid[15 +: 1]),
    .AXI_15_ARREADY(m_axi_hbm_arready[15 +: 1]),
    .AXI_15_RDATA_PARITY(),
    .AXI_15_RDATA(m_axi_hbm_rdata[15*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_15_RID(m_axi_hbm_rid[15 +: 1]),
    .AXI_15_RLAST(m_axi_hbm_rlast[15 +: 1]),
    .AXI_15_RRESP(m_axi_hbm_rresp[15*2 +: 2]),
    .AXI_15_RVALID(m_axi_hbm_rvalid[15 +: 1]),
    .AXI_15_RREADY(m_axi_hbm_rready[15 +: 1]),
    .AXI_15_AWADDR(m_axi_hbm_awaddr[15*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_15_AWBURST(m_axi_hbm_awburst[15*2 +: 2]),
    .AXI_15_AWID(m_axi_hbm_awid[15*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_15_AWLEN(m_axi_hbm_awlen[15*8 +: 8]),
    .AXI_15_AWSIZE(m_axi_hbm_awsize[15*3 +: 3]),
    .AXI_15_AWVALID(m_axi_hbm_awvalid[15 +: 1]),
    .AXI_15_AWREADY(m_axi_hbm_awready[15 +: 1]),
    .AXI_15_WDATA(m_axi_hbm_wdata[15*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_15_WLAST(m_axi_hbm_wlast[15 +: 1]),
    .AXI_15_WSTRB(m_axi_hbm_wstrb[15*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_15_WDATA_PARITY(32'd0),
    .AXI_15_WVALID(m_axi_hbm_wvalid[15 +: 1]),
    .AXI_15_WREADY(m_axi_hbm_wready[15 +: 1]),
    .AXI_15_BID(m_axi_hbm_bid[15*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_15_BRESP(m_axi_hbm_bresp[15*2 +: 2]),
    .AXI_15_BVALID(m_axi_hbm_bvalid[15 +: 1]),
    .AXI_15_BREADY(m_axi_hbm_bready[15 +: 1]),

    .AXI_16_ACLK(hbm_clk[16 +: 1]),
    .AXI_16_ARESET_N(!hbm_rst[16 +: 1]),

    .AXI_16_ARADDR(m_axi_hbm_araddr[16*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_16_ARBURST(m_axi_hbm_arburst[16*2 +: 2]),
    .AXI_16_ARID(m_axi_hbm_arid[16*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_16_ARLEN(m_axi_hbm_arlen[16*8 +: 8]),
    .AXI_16_ARSIZE(m_axi_hbm_arsize[16*3 +: 3]),
    .AXI_16_ARVALID(m_axi_hbm_arvalid[16 +: 1]),
    .AXI_16_ARREADY(m_axi_hbm_arready[16 +: 1]),
    .AXI_16_RDATA_PARITY(),
    .AXI_16_RDATA(m_axi_hbm_rdata[16*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_16_RID(m_axi_hbm_rid[16 +: 1]),
    .AXI_16_RLAST(m_axi_hbm_rlast[16 +: 1]),
    .AXI_16_RRESP(m_axi_hbm_rresp[16*2 +: 2]),
    .AXI_16_RVALID(m_axi_hbm_rvalid[16 +: 1]),
    .AXI_16_RREADY(m_axi_hbm_rready[16 +: 1]),
    .AXI_16_AWADDR(m_axi_hbm_awaddr[16*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_16_AWBURST(m_axi_hbm_awburst[16*2 +: 2]),
    .AXI_16_AWID(m_axi_hbm_awid[16*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_16_AWLEN(m_axi_hbm_awlen[16*8 +: 8]),
    .AXI_16_AWSIZE(m_axi_hbm_awsize[16*3 +: 3]),
    .AXI_16_AWVALID(m_axi_hbm_awvalid[16 +: 1]),
    .AXI_16_AWREADY(m_axi_hbm_awready[16 +: 1]),
    .AXI_16_WDATA(m_axi_hbm_wdata[16*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_16_WLAST(m_axi_hbm_wlast[16 +: 1]),
    .AXI_16_WSTRB(m_axi_hbm_wstrb[16*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_16_WDATA_PARITY(32'd0),
    .AXI_16_WVALID(m_axi_hbm_wvalid[16 +: 1]),
    .AXI_16_WREADY(m_axi_hbm_wready[16 +: 1]),
    .AXI_16_BID(m_axi_hbm_bid[16*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_16_BRESP(m_axi_hbm_bresp[16*2 +: 2]),
    .AXI_16_BVALID(m_axi_hbm_bvalid[16 +: 1]),
    .AXI_16_BREADY(m_axi_hbm_bready[16 +: 1]),

    .AXI_17_ACLK(hbm_clk[17 +: 1]),
    .AXI_17_ARESET_N(!hbm_rst[17 +: 1]),

    .AXI_17_ARADDR(m_axi_hbm_araddr[17*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_17_ARBURST(m_axi_hbm_arburst[17*2 +: 2]),
    .AXI_17_ARID(m_axi_hbm_arid[17*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_17_ARLEN(m_axi_hbm_arlen[17*8 +: 8]),
    .AXI_17_ARSIZE(m_axi_hbm_arsize[17*3 +: 3]),
    .AXI_17_ARVALID(m_axi_hbm_arvalid[17 +: 1]),
    .AXI_17_ARREADY(m_axi_hbm_arready[17 +: 1]),
    .AXI_17_RDATA_PARITY(),
    .AXI_17_RDATA(m_axi_hbm_rdata[17*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_17_RID(m_axi_hbm_rid[17 +: 1]),
    .AXI_17_RLAST(m_axi_hbm_rlast[17 +: 1]),
    .AXI_17_RRESP(m_axi_hbm_rresp[17*2 +: 2]),
    .AXI_17_RVALID(m_axi_hbm_rvalid[17 +: 1]),
    .AXI_17_RREADY(m_axi_hbm_rready[17 +: 1]),
    .AXI_17_AWADDR(m_axi_hbm_awaddr[17*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_17_AWBURST(m_axi_hbm_awburst[17*2 +: 2]),
    .AXI_17_AWID(m_axi_hbm_awid[17*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_17_AWLEN(m_axi_hbm_awlen[17*8 +: 8]),
    .AXI_17_AWSIZE(m_axi_hbm_awsize[17*3 +: 3]),
    .AXI_17_AWVALID(m_axi_hbm_awvalid[17 +: 1]),
    .AXI_17_AWREADY(m_axi_hbm_awready[17 +: 1]),
    .AXI_17_WDATA(m_axi_hbm_wdata[17*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_17_WLAST(m_axi_hbm_wlast[17 +: 1]),
    .AXI_17_WSTRB(m_axi_hbm_wstrb[17*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_17_WDATA_PARITY(32'd0),
    .AXI_17_WVALID(m_axi_hbm_wvalid[17 +: 1]),
    .AXI_17_WREADY(m_axi_hbm_wready[17 +: 1]),
    .AXI_17_BID(m_axi_hbm_bid[17*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_17_BRESP(m_axi_hbm_bresp[17*2 +: 2]),
    .AXI_17_BVALID(m_axi_hbm_bvalid[17 +: 1]),
    .AXI_17_BREADY(m_axi_hbm_bready[17 +: 1]),

    .AXI_18_ACLK(hbm_clk[18 +: 1]),
    .AXI_18_ARESET_N(!hbm_rst[18 +: 1]),

    .AXI_18_ARADDR(m_axi_hbm_araddr[18*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_18_ARBURST(m_axi_hbm_arburst[18*2 +: 2]),
    .AXI_18_ARID(m_axi_hbm_arid[18*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_18_ARLEN(m_axi_hbm_arlen[18*8 +: 8]),
    .AXI_18_ARSIZE(m_axi_hbm_arsize[18*3 +: 3]),
    .AXI_18_ARVALID(m_axi_hbm_arvalid[18 +: 1]),
    .AXI_18_ARREADY(m_axi_hbm_arready[18 +: 1]),
    .AXI_18_RDATA_PARITY(),
    .AXI_18_RDATA(m_axi_hbm_rdata[18*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_18_RID(m_axi_hbm_rid[18 +: 1]),
    .AXI_18_RLAST(m_axi_hbm_rlast[18 +: 1]),
    .AXI_18_RRESP(m_axi_hbm_rresp[18*2 +: 2]),
    .AXI_18_RVALID(m_axi_hbm_rvalid[18 +: 1]),
    .AXI_18_RREADY(m_axi_hbm_rready[18 +: 1]),
    .AXI_18_AWADDR(m_axi_hbm_awaddr[18*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_18_AWBURST(m_axi_hbm_awburst[18*2 +: 2]),
    .AXI_18_AWID(m_axi_hbm_awid[18*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_18_AWLEN(m_axi_hbm_awlen[18*8 +: 8]),
    .AXI_18_AWSIZE(m_axi_hbm_awsize[18*3 +: 3]),
    .AXI_18_AWVALID(m_axi_hbm_awvalid[18 +: 1]),
    .AXI_18_AWREADY(m_axi_hbm_awready[18 +: 1]),
    .AXI_18_WDATA(m_axi_hbm_wdata[18*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_18_WLAST(m_axi_hbm_wlast[18 +: 1]),
    .AXI_18_WSTRB(m_axi_hbm_wstrb[18*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_18_WDATA_PARITY(32'd0),
    .AXI_18_WVALID(m_axi_hbm_wvalid[18 +: 1]),
    .AXI_18_WREADY(m_axi_hbm_wready[18 +: 1]),
    .AXI_18_BID(m_axi_hbm_bid[18*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_18_BRESP(m_axi_hbm_bresp[18*2 +: 2]),
    .AXI_18_BVALID(m_axi_hbm_bvalid[18 +: 1]),
    .AXI_18_BREADY(m_axi_hbm_bready[18 +: 1]),

    .AXI_19_ACLK(hbm_clk[19 +: 1]),
    .AXI_19_ARESET_N(!hbm_rst[19 +: 1]),

    .AXI_19_ARADDR(m_axi_hbm_araddr[19*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_19_ARBURST(m_axi_hbm_arburst[19*2 +: 2]),
    .AXI_19_ARID(m_axi_hbm_arid[19*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_19_ARLEN(m_axi_hbm_arlen[19*8 +: 8]),
    .AXI_19_ARSIZE(m_axi_hbm_arsize[19*3 +: 3]),
    .AXI_19_ARVALID(m_axi_hbm_arvalid[19 +: 1]),
    .AXI_19_ARREADY(m_axi_hbm_arready[19 +: 1]),
    .AXI_19_RDATA_PARITY(),
    .AXI_19_RDATA(m_axi_hbm_rdata[19*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_19_RID(m_axi_hbm_rid[19 +: 1]),
    .AXI_19_RLAST(m_axi_hbm_rlast[19 +: 1]),
    .AXI_19_RRESP(m_axi_hbm_rresp[19*2 +: 2]),
    .AXI_19_RVALID(m_axi_hbm_rvalid[19 +: 1]),
    .AXI_19_RREADY(m_axi_hbm_rready[19 +: 1]),
    .AXI_19_AWADDR(m_axi_hbm_awaddr[19*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_19_AWBURST(m_axi_hbm_awburst[19*2 +: 2]),
    .AXI_19_AWID(m_axi_hbm_awid[19*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_19_AWLEN(m_axi_hbm_awlen[19*8 +: 8]),
    .AXI_19_AWSIZE(m_axi_hbm_awsize[19*3 +: 3]),
    .AXI_19_AWVALID(m_axi_hbm_awvalid[19 +: 1]),
    .AXI_19_AWREADY(m_axi_hbm_awready[19 +: 1]),
    .AXI_19_WDATA(m_axi_hbm_wdata[19*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_19_WLAST(m_axi_hbm_wlast[19 +: 1]),
    .AXI_19_WSTRB(m_axi_hbm_wstrb[19*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_19_WDATA_PARITY(32'd0),
    .AXI_19_WVALID(m_axi_hbm_wvalid[19 +: 1]),
    .AXI_19_WREADY(m_axi_hbm_wready[19 +: 1]),
    .AXI_19_BID(m_axi_hbm_bid[19*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_19_BRESP(m_axi_hbm_bresp[19*2 +: 2]),
    .AXI_19_BVALID(m_axi_hbm_bvalid[19 +: 1]),
    .AXI_19_BREADY(m_axi_hbm_bready[19 +: 1]),

    .AXI_20_ACLK(hbm_clk[20 +: 1]),
    .AXI_20_ARESET_N(!hbm_rst[20 +: 1]),

    .AXI_20_ARADDR(m_axi_hbm_araddr[20*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_20_ARBURST(m_axi_hbm_arburst[20*2 +: 2]),
    .AXI_20_ARID(m_axi_hbm_arid[20*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_20_ARLEN(m_axi_hbm_arlen[20*8 +: 8]),
    .AXI_20_ARSIZE(m_axi_hbm_arsize[20*3 +: 3]),
    .AXI_20_ARVALID(m_axi_hbm_arvalid[20 +: 1]),
    .AXI_20_ARREADY(m_axi_hbm_arready[20 +: 1]),
    .AXI_20_RDATA_PARITY(),
    .AXI_20_RDATA(m_axi_hbm_rdata[20*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_20_RID(m_axi_hbm_rid[20 +: 1]),
    .AXI_20_RLAST(m_axi_hbm_rlast[20 +: 1]),
    .AXI_20_RRESP(m_axi_hbm_rresp[20*2 +: 2]),
    .AXI_20_RVALID(m_axi_hbm_rvalid[20 +: 1]),
    .AXI_20_RREADY(m_axi_hbm_rready[20 +: 1]),
    .AXI_20_AWADDR(m_axi_hbm_awaddr[20*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_20_AWBURST(m_axi_hbm_awburst[20*2 +: 2]),
    .AXI_20_AWID(m_axi_hbm_awid[20*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_20_AWLEN(m_axi_hbm_awlen[20*8 +: 8]),
    .AXI_20_AWSIZE(m_axi_hbm_awsize[20*3 +: 3]),
    .AXI_20_AWVALID(m_axi_hbm_awvalid[20 +: 1]),
    .AXI_20_AWREADY(m_axi_hbm_awready[20 +: 1]),
    .AXI_20_WDATA(m_axi_hbm_wdata[20*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_20_WLAST(m_axi_hbm_wlast[20 +: 1]),
    .AXI_20_WSTRB(m_axi_hbm_wstrb[20*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_20_WDATA_PARITY(32'd0),
    .AXI_20_WVALID(m_axi_hbm_wvalid[20 +: 1]),
    .AXI_20_WREADY(m_axi_hbm_wready[20 +: 1]),
    .AXI_20_BID(m_axi_hbm_bid[20*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_20_BRESP(m_axi_hbm_bresp[20*2 +: 2]),
    .AXI_20_BVALID(m_axi_hbm_bvalid[20 +: 1]),
    .AXI_20_BREADY(m_axi_hbm_bready[20 +: 1]),

    .AXI_21_ACLK(hbm_clk[21 +: 1]),
    .AXI_21_ARESET_N(!hbm_rst[21 +: 1]),

    .AXI_21_ARADDR(m_axi_hbm_araddr[21*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_21_ARBURST(m_axi_hbm_arburst[21*2 +: 2]),
    .AXI_21_ARID(m_axi_hbm_arid[21*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_21_ARLEN(m_axi_hbm_arlen[21*8 +: 8]),
    .AXI_21_ARSIZE(m_axi_hbm_arsize[21*3 +: 3]),
    .AXI_21_ARVALID(m_axi_hbm_arvalid[21 +: 1]),
    .AXI_21_ARREADY(m_axi_hbm_arready[21 +: 1]),
    .AXI_21_RDATA_PARITY(),
    .AXI_21_RDATA(m_axi_hbm_rdata[21*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_21_RID(m_axi_hbm_rid[21 +: 1]),
    .AXI_21_RLAST(m_axi_hbm_rlast[21 +: 1]),
    .AXI_21_RRESP(m_axi_hbm_rresp[21*2 +: 2]),
    .AXI_21_RVALID(m_axi_hbm_rvalid[21 +: 1]),
    .AXI_21_RREADY(m_axi_hbm_rready[21 +: 1]),
    .AXI_21_AWADDR(m_axi_hbm_awaddr[21*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_21_AWBURST(m_axi_hbm_awburst[21*2 +: 2]),
    .AXI_21_AWID(m_axi_hbm_awid[21*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_21_AWLEN(m_axi_hbm_awlen[21*8 +: 8]),
    .AXI_21_AWSIZE(m_axi_hbm_awsize[21*3 +: 3]),
    .AXI_21_AWVALID(m_axi_hbm_awvalid[21 +: 1]),
    .AXI_21_AWREADY(m_axi_hbm_awready[21 +: 1]),
    .AXI_21_WDATA(m_axi_hbm_wdata[21*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_21_WLAST(m_axi_hbm_wlast[21 +: 1]),
    .AXI_21_WSTRB(m_axi_hbm_wstrb[21*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_21_WDATA_PARITY(32'd0),
    .AXI_21_WVALID(m_axi_hbm_wvalid[21 +: 1]),
    .AXI_21_WREADY(m_axi_hbm_wready[21 +: 1]),
    .AXI_21_BID(m_axi_hbm_bid[21*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_21_BRESP(m_axi_hbm_bresp[21*2 +: 2]),
    .AXI_21_BVALID(m_axi_hbm_bvalid[21 +: 1]),
    .AXI_21_BREADY(m_axi_hbm_bready[21 +: 1]),

    .AXI_22_ACLK(hbm_clk[22 +: 1]),
    .AXI_22_ARESET_N(!hbm_rst[22 +: 1]),

    .AXI_22_ARADDR(m_axi_hbm_araddr[22*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_22_ARBURST(m_axi_hbm_arburst[22*2 +: 2]),
    .AXI_22_ARID(m_axi_hbm_arid[22*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_22_ARLEN(m_axi_hbm_arlen[22*8 +: 8]),
    .AXI_22_ARSIZE(m_axi_hbm_arsize[22*3 +: 3]),
    .AXI_22_ARVALID(m_axi_hbm_arvalid[22 +: 1]),
    .AXI_22_ARREADY(m_axi_hbm_arready[22 +: 1]),
    .AXI_22_RDATA_PARITY(),
    .AXI_22_RDATA(m_axi_hbm_rdata[22*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_22_RID(m_axi_hbm_rid[22 +: 1]),
    .AXI_22_RLAST(m_axi_hbm_rlast[22 +: 1]),
    .AXI_22_RRESP(m_axi_hbm_rresp[22*2 +: 2]),
    .AXI_22_RVALID(m_axi_hbm_rvalid[22 +: 1]),
    .AXI_22_RREADY(m_axi_hbm_rready[22 +: 1]),
    .AXI_22_AWADDR(m_axi_hbm_awaddr[22*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_22_AWBURST(m_axi_hbm_awburst[22*2 +: 2]),
    .AXI_22_AWID(m_axi_hbm_awid[22*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_22_AWLEN(m_axi_hbm_awlen[22*8 +: 8]),
    .AXI_22_AWSIZE(m_axi_hbm_awsize[22*3 +: 3]),
    .AXI_22_AWVALID(m_axi_hbm_awvalid[22 +: 1]),
    .AXI_22_AWREADY(m_axi_hbm_awready[22 +: 1]),
    .AXI_22_WDATA(m_axi_hbm_wdata[22*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_22_WLAST(m_axi_hbm_wlast[22 +: 1]),
    .AXI_22_WSTRB(m_axi_hbm_wstrb[22*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_22_WDATA_PARITY(32'd0),
    .AXI_22_WVALID(m_axi_hbm_wvalid[22 +: 1]),
    .AXI_22_WREADY(m_axi_hbm_wready[22 +: 1]),
    .AXI_22_BID(m_axi_hbm_bid[22*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_22_BRESP(m_axi_hbm_bresp[22*2 +: 2]),
    .AXI_22_BVALID(m_axi_hbm_bvalid[22 +: 1]),
    .AXI_22_BREADY(m_axi_hbm_bready[22 +: 1]),

    .AXI_23_ACLK(hbm_clk[23 +: 1]),
    .AXI_23_ARESET_N(!hbm_rst[23 +: 1]),

    .AXI_23_ARADDR(m_axi_hbm_araddr[23*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_23_ARBURST(m_axi_hbm_arburst[23*2 +: 2]),
    .AXI_23_ARID(m_axi_hbm_arid[23*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_23_ARLEN(m_axi_hbm_arlen[23*8 +: 8]),
    .AXI_23_ARSIZE(m_axi_hbm_arsize[23*3 +: 3]),
    .AXI_23_ARVALID(m_axi_hbm_arvalid[23 +: 1]),
    .AXI_23_ARREADY(m_axi_hbm_arready[23 +: 1]),
    .AXI_23_RDATA_PARITY(),
    .AXI_23_RDATA(m_axi_hbm_rdata[23*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_23_RID(m_axi_hbm_rid[23 +: 1]),
    .AXI_23_RLAST(m_axi_hbm_rlast[23 +: 1]),
    .AXI_23_RRESP(m_axi_hbm_rresp[23*2 +: 2]),
    .AXI_23_RVALID(m_axi_hbm_rvalid[23 +: 1]),
    .AXI_23_RREADY(m_axi_hbm_rready[23 +: 1]),
    .AXI_23_AWADDR(m_axi_hbm_awaddr[23*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_23_AWBURST(m_axi_hbm_awburst[23*2 +: 2]),
    .AXI_23_AWID(m_axi_hbm_awid[23*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_23_AWLEN(m_axi_hbm_awlen[23*8 +: 8]),
    .AXI_23_AWSIZE(m_axi_hbm_awsize[23*3 +: 3]),
    .AXI_23_AWVALID(m_axi_hbm_awvalid[23 +: 1]),
    .AXI_23_AWREADY(m_axi_hbm_awready[23 +: 1]),
    .AXI_23_WDATA(m_axi_hbm_wdata[23*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_23_WLAST(m_axi_hbm_wlast[23 +: 1]),
    .AXI_23_WSTRB(m_axi_hbm_wstrb[23*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_23_WDATA_PARITY(32'd0),
    .AXI_23_WVALID(m_axi_hbm_wvalid[23 +: 1]),
    .AXI_23_WREADY(m_axi_hbm_wready[23 +: 1]),
    .AXI_23_BID(m_axi_hbm_bid[23*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_23_BRESP(m_axi_hbm_bresp[23*2 +: 2]),
    .AXI_23_BVALID(m_axi_hbm_bvalid[23 +: 1]),
    .AXI_23_BREADY(m_axi_hbm_bready[23 +: 1]),

    .AXI_24_ACLK(hbm_clk[24 +: 1]),
    .AXI_24_ARESET_N(!hbm_rst[24 +: 1]),

    .AXI_24_ARADDR(m_axi_hbm_araddr[24*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_24_ARBURST(m_axi_hbm_arburst[24*2 +: 2]),
    .AXI_24_ARID(m_axi_hbm_arid[24*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_24_ARLEN(m_axi_hbm_arlen[24*8 +: 8]),
    .AXI_24_ARSIZE(m_axi_hbm_arsize[24*3 +: 3]),
    .AXI_24_ARVALID(m_axi_hbm_arvalid[24 +: 1]),
    .AXI_24_ARREADY(m_axi_hbm_arready[24 +: 1]),
    .AXI_24_RDATA_PARITY(),
    .AXI_24_RDATA(m_axi_hbm_rdata[24*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_24_RID(m_axi_hbm_rid[24 +: 1]),
    .AXI_24_RLAST(m_axi_hbm_rlast[24 +: 1]),
    .AXI_24_RRESP(m_axi_hbm_rresp[24*2 +: 2]),
    .AXI_24_RVALID(m_axi_hbm_rvalid[24 +: 1]),
    .AXI_24_RREADY(m_axi_hbm_rready[24 +: 1]),
    .AXI_24_AWADDR(m_axi_hbm_awaddr[24*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_24_AWBURST(m_axi_hbm_awburst[24*2 +: 2]),
    .AXI_24_AWID(m_axi_hbm_awid[24*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_24_AWLEN(m_axi_hbm_awlen[24*8 +: 8]),
    .AXI_24_AWSIZE(m_axi_hbm_awsize[24*3 +: 3]),
    .AXI_24_AWVALID(m_axi_hbm_awvalid[24 +: 1]),
    .AXI_24_AWREADY(m_axi_hbm_awready[24 +: 1]),
    .AXI_24_WDATA(m_axi_hbm_wdata[24*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_24_WLAST(m_axi_hbm_wlast[24 +: 1]),
    .AXI_24_WSTRB(m_axi_hbm_wstrb[24*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_24_WDATA_PARITY(32'd0),
    .AXI_24_WVALID(m_axi_hbm_wvalid[24 +: 1]),
    .AXI_24_WREADY(m_axi_hbm_wready[24 +: 1]),
    .AXI_24_BID(m_axi_hbm_bid[24*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_24_BRESP(m_axi_hbm_bresp[24*2 +: 2]),
    .AXI_24_BVALID(m_axi_hbm_bvalid[24 +: 1]),
    .AXI_24_BREADY(m_axi_hbm_bready[24 +: 1]),

    .AXI_25_ACLK(hbm_clk[25 +: 1]),
    .AXI_25_ARESET_N(!hbm_rst[25 +: 1]),

    .AXI_25_ARADDR(m_axi_hbm_araddr[25*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_25_ARBURST(m_axi_hbm_arburst[25*2 +: 2]),
    .AXI_25_ARID(m_axi_hbm_arid[25*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_25_ARLEN(m_axi_hbm_arlen[25*8 +: 8]),
    .AXI_25_ARSIZE(m_axi_hbm_arsize[25*3 +: 3]),
    .AXI_25_ARVALID(m_axi_hbm_arvalid[25 +: 1]),
    .AXI_25_ARREADY(m_axi_hbm_arready[25 +: 1]),
    .AXI_25_RDATA_PARITY(),
    .AXI_25_RDATA(m_axi_hbm_rdata[25*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_25_RID(m_axi_hbm_rid[25 +: 1]),
    .AXI_25_RLAST(m_axi_hbm_rlast[25 +: 1]),
    .AXI_25_RRESP(m_axi_hbm_rresp[25*2 +: 2]),
    .AXI_25_RVALID(m_axi_hbm_rvalid[25 +: 1]),
    .AXI_25_RREADY(m_axi_hbm_rready[25 +: 1]),
    .AXI_25_AWADDR(m_axi_hbm_awaddr[25*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_25_AWBURST(m_axi_hbm_awburst[25*2 +: 2]),
    .AXI_25_AWID(m_axi_hbm_awid[25*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_25_AWLEN(m_axi_hbm_awlen[25*8 +: 8]),
    .AXI_25_AWSIZE(m_axi_hbm_awsize[25*3 +: 3]),
    .AXI_25_AWVALID(m_axi_hbm_awvalid[25 +: 1]),
    .AXI_25_AWREADY(m_axi_hbm_awready[25 +: 1]),
    .AXI_25_WDATA(m_axi_hbm_wdata[25*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_25_WLAST(m_axi_hbm_wlast[25 +: 1]),
    .AXI_25_WSTRB(m_axi_hbm_wstrb[25*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_25_WDATA_PARITY(32'd0),
    .AXI_25_WVALID(m_axi_hbm_wvalid[25 +: 1]),
    .AXI_25_WREADY(m_axi_hbm_wready[25 +: 1]),
    .AXI_25_BID(m_axi_hbm_bid[25*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_25_BRESP(m_axi_hbm_bresp[25*2 +: 2]),
    .AXI_25_BVALID(m_axi_hbm_bvalid[25 +: 1]),
    .AXI_25_BREADY(m_axi_hbm_bready[25 +: 1]),

    .AXI_26_ACLK(hbm_clk[26 +: 1]),
    .AXI_26_ARESET_N(!hbm_rst[26 +: 1]),

    .AXI_26_ARADDR(m_axi_hbm_araddr[26*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_26_ARBURST(m_axi_hbm_arburst[26*2 +: 2]),
    .AXI_26_ARID(m_axi_hbm_arid[26*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_26_ARLEN(m_axi_hbm_arlen[26*8 +: 8]),
    .AXI_26_ARSIZE(m_axi_hbm_arsize[26*3 +: 3]),
    .AXI_26_ARVALID(m_axi_hbm_arvalid[26 +: 1]),
    .AXI_26_ARREADY(m_axi_hbm_arready[26 +: 1]),
    .AXI_26_RDATA_PARITY(),
    .AXI_26_RDATA(m_axi_hbm_rdata[26*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_26_RID(m_axi_hbm_rid[26 +: 1]),
    .AXI_26_RLAST(m_axi_hbm_rlast[26 +: 1]),
    .AXI_26_RRESP(m_axi_hbm_rresp[26*2 +: 2]),
    .AXI_26_RVALID(m_axi_hbm_rvalid[26 +: 1]),
    .AXI_26_RREADY(m_axi_hbm_rready[26 +: 1]),
    .AXI_26_AWADDR(m_axi_hbm_awaddr[26*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_26_AWBURST(m_axi_hbm_awburst[26*2 +: 2]),
    .AXI_26_AWID(m_axi_hbm_awid[26*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_26_AWLEN(m_axi_hbm_awlen[26*8 +: 8]),
    .AXI_26_AWSIZE(m_axi_hbm_awsize[26*3 +: 3]),
    .AXI_26_AWVALID(m_axi_hbm_awvalid[26 +: 1]),
    .AXI_26_AWREADY(m_axi_hbm_awready[26 +: 1]),
    .AXI_26_WDATA(m_axi_hbm_wdata[26*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_26_WLAST(m_axi_hbm_wlast[26 +: 1]),
    .AXI_26_WSTRB(m_axi_hbm_wstrb[26*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_26_WDATA_PARITY(32'd0),
    .AXI_26_WVALID(m_axi_hbm_wvalid[26 +: 1]),
    .AXI_26_WREADY(m_axi_hbm_wready[26 +: 1]),
    .AXI_26_BID(m_axi_hbm_bid[26*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_26_BRESP(m_axi_hbm_bresp[26*2 +: 2]),
    .AXI_26_BVALID(m_axi_hbm_bvalid[26 +: 1]),
    .AXI_26_BREADY(m_axi_hbm_bready[26 +: 1]),

    .AXI_27_ACLK(hbm_clk[27 +: 1]),
    .AXI_27_ARESET_N(!hbm_rst[27 +: 1]),

    .AXI_27_ARADDR(m_axi_hbm_araddr[27*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_27_ARBURST(m_axi_hbm_arburst[27*2 +: 2]),
    .AXI_27_ARID(m_axi_hbm_arid[27*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_27_ARLEN(m_axi_hbm_arlen[27*8 +: 8]),
    .AXI_27_ARSIZE(m_axi_hbm_arsize[27*3 +: 3]),
    .AXI_27_ARVALID(m_axi_hbm_arvalid[27 +: 1]),
    .AXI_27_ARREADY(m_axi_hbm_arready[27 +: 1]),
    .AXI_27_RDATA_PARITY(),
    .AXI_27_RDATA(m_axi_hbm_rdata[27*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_27_RID(m_axi_hbm_rid[27 +: 1]),
    .AXI_27_RLAST(m_axi_hbm_rlast[27 +: 1]),
    .AXI_27_RRESP(m_axi_hbm_rresp[27*2 +: 2]),
    .AXI_27_RVALID(m_axi_hbm_rvalid[27 +: 1]),
    .AXI_27_RREADY(m_axi_hbm_rready[27 +: 1]),
    .AXI_27_AWADDR(m_axi_hbm_awaddr[27*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_27_AWBURST(m_axi_hbm_awburst[27*2 +: 2]),
    .AXI_27_AWID(m_axi_hbm_awid[27*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_27_AWLEN(m_axi_hbm_awlen[27*8 +: 8]),
    .AXI_27_AWSIZE(m_axi_hbm_awsize[27*3 +: 3]),
    .AXI_27_AWVALID(m_axi_hbm_awvalid[27 +: 1]),
    .AXI_27_AWREADY(m_axi_hbm_awready[27 +: 1]),
    .AXI_27_WDATA(m_axi_hbm_wdata[27*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_27_WLAST(m_axi_hbm_wlast[27 +: 1]),
    .AXI_27_WSTRB(m_axi_hbm_wstrb[27*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_27_WDATA_PARITY(32'd0),
    .AXI_27_WVALID(m_axi_hbm_wvalid[27 +: 1]),
    .AXI_27_WREADY(m_axi_hbm_wready[27 +: 1]),
    .AXI_27_BID(m_axi_hbm_bid[27*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_27_BRESP(m_axi_hbm_bresp[27*2 +: 2]),
    .AXI_27_BVALID(m_axi_hbm_bvalid[27 +: 1]),
    .AXI_27_BREADY(m_axi_hbm_bready[27 +: 1]),

    .AXI_28_ACLK(hbm_clk[28 +: 1]),
    .AXI_28_ARESET_N(!hbm_rst[28 +: 1]),

    .AXI_28_ARADDR(m_axi_hbm_araddr[28*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_28_ARBURST(m_axi_hbm_arburst[28*2 +: 2]),
    .AXI_28_ARID(m_axi_hbm_arid[28*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_28_ARLEN(m_axi_hbm_arlen[28*8 +: 8]),
    .AXI_28_ARSIZE(m_axi_hbm_arsize[28*3 +: 3]),
    .AXI_28_ARVALID(m_axi_hbm_arvalid[28 +: 1]),
    .AXI_28_ARREADY(m_axi_hbm_arready[28 +: 1]),
    .AXI_28_RDATA_PARITY(),
    .AXI_28_RDATA(m_axi_hbm_rdata[28*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_28_RID(m_axi_hbm_rid[28 +: 1]),
    .AXI_28_RLAST(m_axi_hbm_rlast[28 +: 1]),
    .AXI_28_RRESP(m_axi_hbm_rresp[28*2 +: 2]),
    .AXI_28_RVALID(m_axi_hbm_rvalid[28 +: 1]),
    .AXI_28_RREADY(m_axi_hbm_rready[28 +: 1]),
    .AXI_28_AWADDR(m_axi_hbm_awaddr[28*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_28_AWBURST(m_axi_hbm_awburst[28*2 +: 2]),
    .AXI_28_AWID(m_axi_hbm_awid[28*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_28_AWLEN(m_axi_hbm_awlen[28*8 +: 8]),
    .AXI_28_AWSIZE(m_axi_hbm_awsize[28*3 +: 3]),
    .AXI_28_AWVALID(m_axi_hbm_awvalid[28 +: 1]),
    .AXI_28_AWREADY(m_axi_hbm_awready[28 +: 1]),
    .AXI_28_WDATA(m_axi_hbm_wdata[28*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_28_WLAST(m_axi_hbm_wlast[28 +: 1]),
    .AXI_28_WSTRB(m_axi_hbm_wstrb[28*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_28_WDATA_PARITY(32'd0),
    .AXI_28_WVALID(m_axi_hbm_wvalid[28 +: 1]),
    .AXI_28_WREADY(m_axi_hbm_wready[28 +: 1]),
    .AXI_28_BID(m_axi_hbm_bid[28*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_28_BRESP(m_axi_hbm_bresp[28*2 +: 2]),
    .AXI_28_BVALID(m_axi_hbm_bvalid[28 +: 1]),
    .AXI_28_BREADY(m_axi_hbm_bready[28 +: 1]),

    .AXI_29_ACLK(hbm_clk[29 +: 1]),
    .AXI_29_ARESET_N(!hbm_rst[29 +: 1]),

    .AXI_29_ARADDR(m_axi_hbm_araddr[29*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_29_ARBURST(m_axi_hbm_arburst[29*2 +: 2]),
    .AXI_29_ARID(m_axi_hbm_arid[29*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_29_ARLEN(m_axi_hbm_arlen[29*8 +: 8]),
    .AXI_29_ARSIZE(m_axi_hbm_arsize[29*3 +: 3]),
    .AXI_29_ARVALID(m_axi_hbm_arvalid[29 +: 1]),
    .AXI_29_ARREADY(m_axi_hbm_arready[29 +: 1]),
    .AXI_29_RDATA_PARITY(),
    .AXI_29_RDATA(m_axi_hbm_rdata[29*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_29_RID(m_axi_hbm_rid[29 +: 1]),
    .AXI_29_RLAST(m_axi_hbm_rlast[29 +: 1]),
    .AXI_29_RRESP(m_axi_hbm_rresp[29*2 +: 2]),
    .AXI_29_RVALID(m_axi_hbm_rvalid[29 +: 1]),
    .AXI_29_RREADY(m_axi_hbm_rready[29 +: 1]),
    .AXI_29_AWADDR(m_axi_hbm_awaddr[29*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_29_AWBURST(m_axi_hbm_awburst[29*2 +: 2]),
    .AXI_29_AWID(m_axi_hbm_awid[29*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_29_AWLEN(m_axi_hbm_awlen[29*8 +: 8]),
    .AXI_29_AWSIZE(m_axi_hbm_awsize[29*3 +: 3]),
    .AXI_29_AWVALID(m_axi_hbm_awvalid[29 +: 1]),
    .AXI_29_AWREADY(m_axi_hbm_awready[29 +: 1]),
    .AXI_29_WDATA(m_axi_hbm_wdata[29*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_29_WLAST(m_axi_hbm_wlast[29 +: 1]),
    .AXI_29_WSTRB(m_axi_hbm_wstrb[29*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_29_WDATA_PARITY(32'd0),
    .AXI_29_WVALID(m_axi_hbm_wvalid[29 +: 1]),
    .AXI_29_WREADY(m_axi_hbm_wready[29 +: 1]),
    .AXI_29_BID(m_axi_hbm_bid[29*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_29_BRESP(m_axi_hbm_bresp[29*2 +: 2]),
    .AXI_29_BVALID(m_axi_hbm_bvalid[29 +: 1]),
    .AXI_29_BREADY(m_axi_hbm_bready[29 +: 1]),

    .AXI_30_ACLK(hbm_clk[30 +: 1]),
    .AXI_30_ARESET_N(!hbm_rst[30 +: 1]),

    .AXI_30_ARADDR(m_axi_hbm_araddr[30*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_30_ARBURST(m_axi_hbm_arburst[30*2 +: 2]),
    .AXI_30_ARID(m_axi_hbm_arid[30*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_30_ARLEN(m_axi_hbm_arlen[30*8 +: 8]),
    .AXI_30_ARSIZE(m_axi_hbm_arsize[30*3 +: 3]),
    .AXI_30_ARVALID(m_axi_hbm_arvalid[30 +: 1]),
    .AXI_30_ARREADY(m_axi_hbm_arready[30 +: 1]),
    .AXI_30_RDATA_PARITY(),
    .AXI_30_RDATA(m_axi_hbm_rdata[30*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_30_RID(m_axi_hbm_rid[30 +: 1]),
    .AXI_30_RLAST(m_axi_hbm_rlast[30 +: 1]),
    .AXI_30_RRESP(m_axi_hbm_rresp[30*2 +: 2]),
    .AXI_30_RVALID(m_axi_hbm_rvalid[30 +: 1]),
    .AXI_30_RREADY(m_axi_hbm_rready[30 +: 1]),
    .AXI_30_AWADDR(m_axi_hbm_awaddr[30*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_30_AWBURST(m_axi_hbm_awburst[30*2 +: 2]),
    .AXI_30_AWID(m_axi_hbm_awid[30*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_30_AWLEN(m_axi_hbm_awlen[30*8 +: 8]),
    .AXI_30_AWSIZE(m_axi_hbm_awsize[30*3 +: 3]),
    .AXI_30_AWVALID(m_axi_hbm_awvalid[30 +: 1]),
    .AXI_30_AWREADY(m_axi_hbm_awready[30 +: 1]),
    .AXI_30_WDATA(m_axi_hbm_wdata[30*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_30_WLAST(m_axi_hbm_wlast[30 +: 1]),
    .AXI_30_WSTRB(m_axi_hbm_wstrb[30*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_30_WDATA_PARITY(32'd0),
    .AXI_30_WVALID(m_axi_hbm_wvalid[30 +: 1]),
    .AXI_30_WREADY(m_axi_hbm_wready[30 +: 1]),
    .AXI_30_BID(m_axi_hbm_bid[30*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_30_BRESP(m_axi_hbm_bresp[30*2 +: 2]),
    .AXI_30_BVALID(m_axi_hbm_bvalid[30 +: 1]),
    .AXI_30_BREADY(m_axi_hbm_bready[30 +: 1]),

    .AXI_31_ACLK(hbm_clk[31 +: 1]),
    .AXI_31_ARESET_N(!hbm_rst[31 +: 1]),

    .AXI_31_ARADDR(m_axi_hbm_araddr[31*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_31_ARBURST(m_axi_hbm_arburst[31*2 +: 2]),
    .AXI_31_ARID(m_axi_hbm_arid[31*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_31_ARLEN(m_axi_hbm_arlen[31*8 +: 8]),
    .AXI_31_ARSIZE(m_axi_hbm_arsize[31*3 +: 3]),
    .AXI_31_ARVALID(m_axi_hbm_arvalid[31 +: 1]),
    .AXI_31_ARREADY(m_axi_hbm_arready[31 +: 1]),
    .AXI_31_RDATA_PARITY(),
    .AXI_31_RDATA(m_axi_hbm_rdata[31*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_31_RID(m_axi_hbm_rid[31 +: 1]),
    .AXI_31_RLAST(m_axi_hbm_rlast[31 +: 1]),
    .AXI_31_RRESP(m_axi_hbm_rresp[31*2 +: 2]),
    .AXI_31_RVALID(m_axi_hbm_rvalid[31 +: 1]),
    .AXI_31_RREADY(m_axi_hbm_rready[31 +: 1]),
    .AXI_31_AWADDR(m_axi_hbm_awaddr[31*AXI_HBM_ADDR_WIDTH +: AXI_HBM_ADDR_WIDTH]),
    .AXI_31_AWBURST(m_axi_hbm_awburst[31*2 +: 2]),
    .AXI_31_AWID(m_axi_hbm_awid[31*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_31_AWLEN(m_axi_hbm_awlen[31*8 +: 8]),
    .AXI_31_AWSIZE(m_axi_hbm_awsize[31*3 +: 3]),
    .AXI_31_AWVALID(m_axi_hbm_awvalid[31 +: 1]),
    .AXI_31_AWREADY(m_axi_hbm_awready[31 +: 1]),
    .AXI_31_WDATA(m_axi_hbm_wdata[31*AXI_HBM_DATA_WIDTH +: AXI_HBM_DATA_WIDTH]),
    .AXI_31_WLAST(m_axi_hbm_wlast[31 +: 1]),
    .AXI_31_WSTRB(m_axi_hbm_wstrb[31*AXI_HBM_STRB_WIDTH +: AXI_HBM_STRB_WIDTH]),
    .AXI_31_WDATA_PARITY(32'd0),
    .AXI_31_WVALID(m_axi_hbm_wvalid[31 +: 1]),
    .AXI_31_WREADY(m_axi_hbm_wready[31 +: 1]),
    .AXI_31_BID(m_axi_hbm_bid[31*AXI_HBM_ID_WIDTH +: AXI_HBM_ID_WIDTH]),
    .AXI_31_BRESP(m_axi_hbm_bresp[31*2 +: 2]),
    .AXI_31_BVALID(m_axi_hbm_bvalid[31 +: 1]),
    .AXI_31_BREADY(m_axi_hbm_bready[31 +: 1]),

    .DRAM_0_STAT_CATTRIP(hbm_cattrip_1),
    .DRAM_0_STAT_TEMP(hbm_temp_1),
    .DRAM_1_STAT_CATTRIP(hbm_cattrip_2),
    .DRAM_1_STAT_TEMP(hbm_temp_2)
);

assign hbm_status = {HBM_CH{1'b1}};

end else begin

assign hbm_clk = 0;
assign hbm_rst = 0;

assign m_axi_hbm_awready = 0;
assign m_axi_hbm_wready = 0;
assign m_axi_hbm_bid = 0;
assign m_axi_hbm_bresp = 0;
assign m_axi_hbm_bvalid = 0;
assign m_axi_hbm_arready = 0;
assign m_axi_hbm_rid = 0;
assign m_axi_hbm_rdata = 0;
assign m_axi_hbm_rresp = 0;
assign m_axi_hbm_rlast = 0;
assign m_axi_hbm_rvalid = 0;

assign hbm_status = 0;

end

endgenerate

fpga_core #(
    // FW and board IDs
    .FPGA_ID(FPGA_ID),
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .BUILD_DATE(BUILD_DATE),
    .GIT_HASH(GIT_HASH),
    .RELEASE_INFO(RELEASE_INFO),

    // Structural configuration
    .IF_COUNT(IF_COUNT),
    .PORTS_PER_IF(PORTS_PER_IF),
    .SCHED_PER_IF(SCHED_PER_IF),
    .PORT_MASK(PORT_MASK),

    // Clock configuration
    .CLK_PERIOD_NS_NUM(CLK_PERIOD_NS_NUM),
    .CLK_PERIOD_NS_DENOM(CLK_PERIOD_NS_DENOM),

    // PTP configuration
    .PTP_CLK_PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
    .PTP_CLK_PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_CLOCK_PIPELINE(PTP_CLOCK_PIPELINE),
    .PTP_CLOCK_CDC_PIPELINE(PTP_CLOCK_CDC_PIPELINE),
    .PTP_USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK),
    .PTP_SEPARATE_RX_CLOCK(PTP_SEPARATE_RX_CLOCK),
    .PTP_PORT_CDC_PIPELINE(PTP_PORT_CDC_PIPELINE),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

    // Queue manager configuration
    .EVENT_QUEUE_OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .TX_QUEUE_OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .RX_QUEUE_OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .TX_CPL_QUEUE_OP_TABLE_SIZE(TX_CPL_QUEUE_OP_TABLE_SIZE),
    .RX_CPL_QUEUE_OP_TABLE_SIZE(RX_CPL_QUEUE_OP_TABLE_SIZE),
    .EVENT_QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_QUEUE_PIPELINE(EVENT_QUEUE_PIPELINE),
    .TX_QUEUE_PIPELINE(TX_QUEUE_PIPELINE),
    .RX_QUEUE_PIPELINE(RX_QUEUE_PIPELINE),
    .TX_CPL_QUEUE_PIPELINE(TX_CPL_QUEUE_PIPELINE),
    .RX_CPL_QUEUE_PIPELINE(RX_CPL_QUEUE_PIPELINE),

    // TX and RX engine configuration
    .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),

    // Scheduler configuration
    .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
    .TX_SCHEDULER_PIPELINE(TX_SCHEDULER_PIPELINE),
    .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),

    // Interface configuration
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .TX_CPL_FIFO_DEPTH(TX_CPL_FIFO_DEPTH),
    .TX_TAG_WIDTH(TX_TAG_WIDTH),
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

    // RAM configuration
    .DDR_CH(DDR_CH),
    .DDR_ENABLE(DDR_ENABLE),
    .AXI_DDR_DATA_WIDTH(AXI_DDR_DATA_WIDTH),
    .AXI_DDR_ADDR_WIDTH(AXI_DDR_ADDR_WIDTH),
    .AXI_DDR_STRB_WIDTH(AXI_DDR_STRB_WIDTH),
    .AXI_DDR_ID_WIDTH(AXI_DDR_ID_WIDTH),
    .AXI_DDR_MAX_BURST_LEN(AXI_DDR_MAX_BURST_LEN),
    .AXI_DDR_NARROW_BURST(AXI_DDR_NARROW_BURST),
    .HBM_CH(HBM_CH),
    .HBM_ENABLE(HBM_ENABLE),
    .HBM_GROUP_SIZE(HBM_GROUP_SIZE),
    .AXI_HBM_DATA_WIDTH(AXI_HBM_DATA_WIDTH),
    .AXI_HBM_ADDR_WIDTH(AXI_HBM_ADDR_WIDTH),
    .AXI_HBM_STRB_WIDTH(AXI_HBM_STRB_WIDTH),
    .AXI_HBM_ID_WIDTH(AXI_HBM_ID_WIDTH),
    .AXI_HBM_MAX_BURST_LEN(AXI_HBM_MAX_BURST_LEN),

    // Application block configuration
    .APP_ID(APP_ID),
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),

    // DMA interface configuration
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // PCIe interface configuration
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .RC_STRADDLE(RC_STRADDLE),
    .RQ_STRADDLE(RQ_STRADDLE),
    .CQ_STRADDLE(CQ_STRADDLE),
    .CC_STRADDLE(CC_STRADDLE),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .PF_COUNT(PF_COUNT),
    .VF_COUNT(VF_COUNT),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),

    // Interrupt configuration
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),

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
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),

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

    .s_axis_rq_seq_num_0(pcie_rq_seq_num0_reg),
    .s_axis_rq_seq_num_valid_0(pcie_rq_seq_num_vld0_reg),
    .s_axis_rq_seq_num_1(pcie_rq_seq_num1_reg),
    .s_axis_rq_seq_num_valid_1(pcie_rq_seq_num_vld1_reg),

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

    .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    .cfg_interrupt_msix_vec_pending(cfg_interrupt_msix_vec_pending),
    .cfg_interrupt_msix_vec_pending_status(cfg_interrupt_msix_vec_pending_status),
    .cfg_interrupt_msix_sent(cfg_interrupt_msix_sent),
    .cfg_interrupt_msix_fail(cfg_interrupt_msix_fail),
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

    .qsfp0_rx_status(qsfp0_rx_status),

    .qsfp0_drp_clk(qsfp0_drp_clk),
    .qsfp0_drp_rst(qsfp0_drp_rst),
    .qsfp0_drp_addr(qsfp0_drp_addr),
    .qsfp0_drp_di(qsfp0_drp_di),
    .qsfp0_drp_en(qsfp0_drp_en),
    .qsfp0_drp_we(qsfp0_drp_we),
    .qsfp0_drp_do(qsfp0_drp_do),
    .qsfp0_drp_rdy(qsfp0_drp_rdy),

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

    .qsfp1_rx_status(qsfp1_rx_status),

    .qsfp1_drp_clk(qsfp1_drp_clk),
    .qsfp1_drp_rst(qsfp1_drp_rst),
    .qsfp1_drp_addr(qsfp1_drp_addr),
    .qsfp1_drp_di(qsfp1_drp_di),
    .qsfp1_drp_en(qsfp1_drp_en),
    .qsfp1_drp_we(qsfp1_drp_we),
    .qsfp1_drp_do(qsfp1_drp_do),
    .qsfp1_drp_rdy(qsfp1_drp_rdy),

    /*
     * DDR
     */
    .ddr_clk(ddr_clk),
    .ddr_rst(ddr_rst),

    .m_axi_ddr_awid(m_axi_ddr_awid),
    .m_axi_ddr_awaddr(m_axi_ddr_awaddr),
    .m_axi_ddr_awlen(m_axi_ddr_awlen),
    .m_axi_ddr_awsize(m_axi_ddr_awsize),
    .m_axi_ddr_awburst(m_axi_ddr_awburst),
    .m_axi_ddr_awlock(m_axi_ddr_awlock),
    .m_axi_ddr_awcache(m_axi_ddr_awcache),
    .m_axi_ddr_awprot(m_axi_ddr_awprot),
    .m_axi_ddr_awqos(m_axi_ddr_awqos),
    .m_axi_ddr_awvalid(m_axi_ddr_awvalid),
    .m_axi_ddr_awready(m_axi_ddr_awready),
    .m_axi_ddr_wdata(m_axi_ddr_wdata),
    .m_axi_ddr_wstrb(m_axi_ddr_wstrb),
    .m_axi_ddr_wlast(m_axi_ddr_wlast),
    .m_axi_ddr_wvalid(m_axi_ddr_wvalid),
    .m_axi_ddr_wready(m_axi_ddr_wready),
    .m_axi_ddr_bid(m_axi_ddr_bid),
    .m_axi_ddr_bresp(m_axi_ddr_bresp),
    .m_axi_ddr_bvalid(m_axi_ddr_bvalid),
    .m_axi_ddr_bready(m_axi_ddr_bready),
    .m_axi_ddr_arid(m_axi_ddr_arid),
    .m_axi_ddr_araddr(m_axi_ddr_araddr),
    .m_axi_ddr_arlen(m_axi_ddr_arlen),
    .m_axi_ddr_arsize(m_axi_ddr_arsize),
    .m_axi_ddr_arburst(m_axi_ddr_arburst),
    .m_axi_ddr_arlock(m_axi_ddr_arlock),
    .m_axi_ddr_arcache(m_axi_ddr_arcache),
    .m_axi_ddr_arprot(m_axi_ddr_arprot),
    .m_axi_ddr_arqos(m_axi_ddr_arqos),
    .m_axi_ddr_arvalid(m_axi_ddr_arvalid),
    .m_axi_ddr_arready(m_axi_ddr_arready),
    .m_axi_ddr_rid(m_axi_ddr_rid),
    .m_axi_ddr_rdata(m_axi_ddr_rdata),
    .m_axi_ddr_rresp(m_axi_ddr_rresp),
    .m_axi_ddr_rlast(m_axi_ddr_rlast),
    .m_axi_ddr_rvalid(m_axi_ddr_rvalid),
    .m_axi_ddr_rready(m_axi_ddr_rready),

    .ddr_status(ddr_status),

    /*
     * HBM
     */
    .hbm_clk(hbm_clk),
    .hbm_rst(hbm_rst),
    .m_axi_hbm_awid(m_axi_hbm_awid),
    .m_axi_hbm_awaddr(m_axi_hbm_awaddr),
    .m_axi_hbm_awlen(m_axi_hbm_awlen),
    .m_axi_hbm_awsize(m_axi_hbm_awsize),
    .m_axi_hbm_awburst(m_axi_hbm_awburst),
    .m_axi_hbm_awlock(m_axi_hbm_awlock),
    .m_axi_hbm_awcache(m_axi_hbm_awcache),
    .m_axi_hbm_awprot(m_axi_hbm_awprot),
    .m_axi_hbm_awqos(m_axi_hbm_awqos),
    .m_axi_hbm_awvalid(m_axi_hbm_awvalid),
    .m_axi_hbm_awready(m_axi_hbm_awready),
    .m_axi_hbm_wdata(m_axi_hbm_wdata),
    .m_axi_hbm_wstrb(m_axi_hbm_wstrb),
    .m_axi_hbm_wlast(m_axi_hbm_wlast),
    .m_axi_hbm_wvalid(m_axi_hbm_wvalid),
    .m_axi_hbm_wready(m_axi_hbm_wready),
    .m_axi_hbm_bid(m_axi_hbm_bid),
    .m_axi_hbm_bresp(m_axi_hbm_bresp),
    .m_axi_hbm_bvalid(m_axi_hbm_bvalid),
    .m_axi_hbm_bready(m_axi_hbm_bready),
    .m_axi_hbm_arid(m_axi_hbm_arid),
    .m_axi_hbm_araddr(m_axi_hbm_araddr),
    .m_axi_hbm_arlen(m_axi_hbm_arlen),
    .m_axi_hbm_arsize(m_axi_hbm_arsize),
    .m_axi_hbm_arburst(m_axi_hbm_arburst),
    .m_axi_hbm_arlock(m_axi_hbm_arlock),
    .m_axi_hbm_arcache(m_axi_hbm_arcache),
    .m_axi_hbm_arprot(m_axi_hbm_arprot),
    .m_axi_hbm_arqos(m_axi_hbm_arqos),
    .m_axi_hbm_arvalid(m_axi_hbm_arvalid),
    .m_axi_hbm_arready(m_axi_hbm_arready),
    .m_axi_hbm_rid(m_axi_hbm_rid),
    .m_axi_hbm_rdata(m_axi_hbm_rdata),
    .m_axi_hbm_rresp(m_axi_hbm_rresp),
    .m_axi_hbm_rlast(m_axi_hbm_rlast),
    .m_axi_hbm_rvalid(m_axi_hbm_rvalid),
    .m_axi_hbm_rready(m_axi_hbm_rready),

    .hbm_status(hbm_status),

    /*
     * QSPI flash
     */
    .fpga_boot(fpga_boot),
    .qspi_clk(qspi_clk_int),
    .qspi_dq_i(qspi_dq_i_int),
    .qspi_dq_o(qspi_dq_o_int),
    .qspi_dq_oe(qspi_dq_oe_int),
    .qspi_cs(qspi_cs_int),

    /*
     * AXI-Lite interface to CMS
     */
    .m_axil_cms_clk(axil_cms_clk),
    .m_axil_cms_rst(axil_cms_rst),
    .m_axil_cms_awaddr(axil_cms_awaddr),
    .m_axil_cms_awprot(axil_cms_awprot),
    .m_axil_cms_awvalid(axil_cms_awvalid),
    .m_axil_cms_awready(axil_cms_awready),
    .m_axil_cms_wdata(axil_cms_wdata),
    .m_axil_cms_wstrb(axil_cms_wstrb),
    .m_axil_cms_wvalid(axil_cms_wvalid),
    .m_axil_cms_wready(axil_cms_wready),
    .m_axil_cms_bresp(axil_cms_bresp),
    .m_axil_cms_bvalid(axil_cms_bvalid),
    .m_axil_cms_bready(axil_cms_bready),
    .m_axil_cms_araddr(axil_cms_araddr),
    .m_axil_cms_arprot(axil_cms_arprot),
    .m_axil_cms_arvalid(axil_cms_arvalid),
    .m_axil_cms_arready(axil_cms_arready),
    .m_axil_cms_rdata(axil_cms_rdata),
    .m_axil_cms_rresp(axil_cms_rresp),
    .m_axil_cms_rvalid(axil_cms_rvalid),
    .m_axil_cms_rready(axil_cms_rready)
);

endmodule

`resetall
