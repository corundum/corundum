// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
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
    parameter FPGA_ID = 32'h4B77093,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h10ee_9032,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

    // Board configuration
    parameter CMS_ENABLE = 1,

    // Structural configuration
    parameter IF_COUNT = 1,
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
    parameter CQ_OP_TABLE_SIZE = 32,
    parameter EQN_WIDTH = 5,
    parameter TX_QUEUE_INDEX_WIDTH = 13,
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter CQN_WIDTH = (TX_QUEUE_INDEX_WIDTH > RX_QUEUE_INDEX_WIDTH ? TX_QUEUE_INDEX_WIDTH : RX_QUEUE_INDEX_WIDTH) + 1,
    parameter EQ_PIPELINE = 3,
    parameter TX_QUEUE_PIPELINE = 3+(TX_QUEUE_INDEX_WIDTH > 12 ? TX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter RX_QUEUE_PIPELINE = 3+(RX_QUEUE_INDEX_WIDTH > 12 ? RX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter CQ_PIPELINE = 3+(CQN_WIDTH > 12 ? CQN_WIDTH-12 : 0),

    // TX and RX engine configuration
    parameter TX_DESC_TABLE_SIZE = 32,
    parameter RX_DESC_TABLE_SIZE = 32,
    parameter RX_INDIR_TBL_ADDR_WIDTH = RX_QUEUE_INDEX_WIDTH > 8 ? 8 : RX_QUEUE_INDEX_WIDTH,

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
    parameter PFC_ENABLE = 1,
    parameter LFC_ENABLE = PFC_ENABLE,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 131072,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 131072,
    parameter RX_RAM_SIZE = 131072,

    // RAM configuration
    parameter HBM_CH = 32,
    parameter HBM_ENABLE = 0,
    parameter HBM_GROUP_SIZE = HBM_CH,
    parameter AXI_HBM_ADDR_WIDTH = 33,
    parameter AXI_HBM_MAX_BURST_LEN = 16,

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
    parameter IRQ_INDEX_WIDTH = EQN_WIDTH,

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
    // input  wire         clk_100mhz_0_p,
    // input  wire         clk_100mhz_0_n,
    input  wire         clk_100mhz_1_p,
    input  wire         clk_100mhz_1_n,

    /*
     * GPIO
     */
    output wire         qsfp_led_act,
    output wire         qsfp_led_stat_g,
    output wire         qsfp_led_stat_y,
    output wire         hbm_cattrip,
    input  wire [1:0]   msp_gpio,
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
    output wire [3:0]   qsfp_tx_p,
    output wire [3:0]   qsfp_tx_n,
    input  wire [3:0]   qsfp_rx_p,
    input  wire [3:0]   qsfp_rx_n,
    input  wire         qsfp_mgt_refclk_0_p,
    input  wire         qsfp_mgt_refclk_0_n
    // input  wire         qsfp_mgt_refclk_1_p,
    // input  wire         qsfp_mgt_refclk_1_n
);

// PTP configuration
parameter PTP_CLK_PERIOD_NS_NUM = 1024;
parameter PTP_CLK_PERIOD_NS_DENOM = 165;
parameter PTP_TS_WIDTH = 96;

// Interface configuration
parameter TX_TAG_WIDTH = 16;

// RAM configuration
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

wire clk_100mhz_1_ibufg;
wire clk_100mhz_1_int;

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

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")
)
clk_100mhz_1_ibufg_inst (
   .O   (clk_100mhz_1_ibufg),
   .I   (clk_100mhz_1_p),
   .IB  (clk_100mhz_1_n)
);

BUFG
clk_100mhz_1_bufg_inst (
    .I(clk_100mhz_1_ibufg),
    .O(clk_100mhz_1_int)
);

// MMCM instance
// 100 MHz in, 125 MHz + 50 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 800 MHz to 1600 MHz
// M = 10, D = 1 sets Fvco = 1000 MHz
// Divide by 8 to get output frequency of 125 MHz
// Divide by 20 to get output frequency of 50 MHz
MMCME4_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(8),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(20),
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
    .CLKFBOUT_MULT_F(10),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(10.000),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_100mhz_1_int),
    .CLKFBIN(mmcm_clkfb),
    .RST(mmcm_rst),
    .PWRDWN(1'b0),
    .CLKOUT0(clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    .CLKOUT1(clk_50mhz_mmcm_out),
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

wire [6:0] hbm_temp_1;
wire [6:0] hbm_temp_2;

generate

if (CMS_ENABLE) begin : cms

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

end else begin

    assign axil_cms_awready = 0;
    assign axil_cms_wdata = 0;
    assign axil_cms_wstrb = 0;
    assign axil_cms_wvalid = 0;
    assign axil_cms_bresp = 0;
    assign axil_cms_bvalid = 0;
    assign axil_cms_arready = 0;
    assign axil_cms_rdata = 0;
    assign axil_cms_rresp = 0;
    assign axil_cms_rvalid = 0;

    assign msp_uart_txd = 1'bz;

end

endgenerate

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
wire [3:0] cfg_rcb_status;

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
    .cfg_rcb_status(cfg_rcb_status),
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

// Ethernet
localparam QSFP_CNT = 1;

wire [QSFP_CNT-1:0]                      qsfp_tx_clk;
wire [QSFP_CNT-1:0]                      qsfp_tx_rst;

wire [QSFP_CNT*AXIS_ETH_DATA_WIDTH-1:0]  qsfp_tx_axis_tdata;
wire [QSFP_CNT*AXIS_ETH_KEEP_WIDTH-1:0]  qsfp_tx_axis_tkeep;
wire [QSFP_CNT-1:0]                      qsfp_tx_axis_tvalid;
wire [QSFP_CNT-1:0]                      qsfp_tx_axis_tready;
wire [QSFP_CNT-1:0]                      qsfp_tx_axis_tlast;
wire [QSFP_CNT*(16+1)-1:0]               qsfp_tx_axis_tuser;

wire [QSFP_CNT*80-1:0]                   qsfp_tx_ptp_time;
wire [QSFP_CNT*80-1:0]                   qsfp_tx_ptp_ts;
wire [QSFP_CNT*16-1:0]                   qsfp_tx_ptp_ts_tag;
wire [QSFP_CNT-1:0]                      qsfp_tx_ptp_ts_valid;

wire [QSFP_CNT-1:0]                      qsfp_tx_enable;
wire [QSFP_CNT-1:0]                      qsfp_tx_lfc_en;
wire [QSFP_CNT-1:0]                      qsfp_tx_lfc_req;
wire [QSFP_CNT*8-1:0]                    qsfp_tx_pfc_en;
wire [QSFP_CNT*8-1:0]                    qsfp_tx_pfc_req;

wire [QSFP_CNT-1:0]                      qsfp_rx_clk;
wire [QSFP_CNT-1:0]                      qsfp_rx_rst;

wire [QSFP_CNT*AXIS_ETH_DATA_WIDTH-1:0]  qsfp_rx_axis_tdata;
wire [QSFP_CNT*AXIS_ETH_KEEP_WIDTH-1:0]  qsfp_rx_axis_tkeep;
wire [QSFP_CNT-1:0]                      qsfp_rx_axis_tvalid;
wire [QSFP_CNT-1:0]                      qsfp_rx_axis_tlast;
wire [QSFP_CNT*(80+1)-1:0]               qsfp_rx_axis_tuser;

wire [QSFP_CNT*80-1:0]                   qsfp_rx_ptp_time;

wire [QSFP_CNT-1:0]                      qsfp_rx_enable;
wire [QSFP_CNT-1:0]                      qsfp_rx_status;
wire [QSFP_CNT-1:0]                      qsfp_rx_lfc_en;
wire [QSFP_CNT-1:0]                      qsfp_rx_lfc_req;
wire [QSFP_CNT-1:0]                      qsfp_rx_lfc_ack;
wire [QSFP_CNT*8-1:0]                    qsfp_rx_pfc_en;
wire [QSFP_CNT*8-1:0]                    qsfp_rx_pfc_req;
wire [QSFP_CNT*8-1:0]                    qsfp_rx_pfc_ack;

wire [QSFP_CNT-1:0]                      qsfp_drp_clk;
wire [QSFP_CNT-1:0]                      qsfp_drp_rst;
wire [QSFP_CNT*24-1:0]                   qsfp_drp_addr;
wire [QSFP_CNT*16-1:0]                   qsfp_drp_di;
wire [QSFP_CNT-1:0]                      qsfp_drp_en;
wire [QSFP_CNT-1:0]                      qsfp_drp_we;
wire [QSFP_CNT*16-1:0]                   qsfp_drp_do;
wire [QSFP_CNT-1:0]                      qsfp_drp_rdy;

// CMAC
assign qsfp_drp_clk[0 +: 1] = clk_125mhz_int;
assign qsfp_drp_rst[0 +: 1] = rst_125mhz_int;

wire qsfp_gtpowergood;

wire qsfp_mgt_refclk_0;
wire qsfp_mgt_refclk_0_int;
wire qsfp_mgt_refclk_0_bufg;

IBUFDS_GTE4 ibufds_gte4_qsfp_mgt_refclk_0_inst (
    .I     (qsfp_mgt_refclk_0_p),
    .IB    (qsfp_mgt_refclk_0_n),
    .CEB   (1'b0),
    .O     (qsfp_mgt_refclk_0),
    .ODIV2 (qsfp_mgt_refclk_0_int)
);

BUFG_GT bufg_gt_qsfp_mgt_refclk_0_inst (
    .CE      (qsfp_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (qsfp_mgt_refclk_0_int),
    .O       (qsfp_mgt_refclk_0_bufg)
);

wire qsfp_rst;

sync_reset #(
    .N(4)
)
qsfp_sync_reset_inst (
    .clk(qsfp_mgt_refclk_0_bufg),
    .rst(rst_125mhz_int),
    .out(qsfp_rst)
);

cmac_gty_wrapper #(
    .DRP_CLK_FREQ_HZ(125000000),
    .AXIS_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .TX_SERDES_PIPELINE(0),
    .RX_SERDES_PIPELINE(0),
    .RS_FEC_ENABLE(1)
)
qsfp_cmac_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(qsfp_rst),

    /*
     * Common
     */
    .xcvr_gtpowergood_out(qsfp_gtpowergood),
    .xcvr_ref_clk(qsfp_mgt_refclk_0),

    /*
     * DRP
     */
    .drp_clk(qsfp_drp_clk[0 +: 1]),
    .drp_rst(qsfp_drp_rst[0 +: 1]),
    .drp_addr(qsfp_drp_addr[0*24 +: 24]),
    .drp_di(qsfp_drp_di[0*16 +: 16]),
    .drp_en(qsfp_drp_en[0 +: 1]),
    .drp_we(qsfp_drp_we[0 +: 1]),
    .drp_do(qsfp_drp_do[0*16 +: 16]),
    .drp_rdy(qsfp_drp_rdy[0 +: 1]),

    /*
     * Serial data
     */
    .xcvr_txp(qsfp_tx_p),
    .xcvr_txn(qsfp_tx_n),
    .xcvr_rxp(qsfp_rx_p),
    .xcvr_rxn(qsfp_rx_n),

    /*
     * CMAC connections
     */
    .tx_clk(qsfp_tx_clk[0 +: 1]),
    .tx_rst(qsfp_tx_rst[0 +: 1]),

    .tx_axis_tdata(qsfp_tx_axis_tdata[0*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH]),
    .tx_axis_tkeep(qsfp_tx_axis_tkeep[0*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH]),
    .tx_axis_tvalid(qsfp_tx_axis_tvalid[0 +: 1]),
    .tx_axis_tready(qsfp_tx_axis_tready[0 +: 1]),
    .tx_axis_tlast(qsfp_tx_axis_tlast[0 +: 1]),
    .tx_axis_tuser(qsfp_tx_axis_tuser[0*(16+1) +: (16+1)]),

    .tx_ptp_time(qsfp_tx_ptp_time[0*80 +: 80]),
    .tx_ptp_ts(qsfp_tx_ptp_ts[0*80 +: 80]),
    .tx_ptp_ts_tag(qsfp_tx_ptp_ts_tag[0*16 +: 16]),
    .tx_ptp_ts_valid(qsfp_tx_ptp_ts_valid[0 +: 1]),

    .tx_enable(qsfp_tx_enable[0 +: 1]),
    .tx_lfc_en(qsfp_tx_lfc_en[0 +: 1]),
    .tx_lfc_req(qsfp_tx_lfc_req[0 +: 1]),
    .tx_pfc_en(qsfp_tx_pfc_en[0*8 +: 8]),
    .tx_pfc_req(qsfp_tx_pfc_req[0*8 +: 8]),

    .rx_clk(qsfp_rx_clk[0 +: 1]),
    .rx_rst(qsfp_rx_rst[0 +: 1]),

    .rx_axis_tdata(qsfp_rx_axis_tdata[0*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH]),
    .rx_axis_tkeep(qsfp_rx_axis_tkeep[0*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH]),
    .rx_axis_tvalid(qsfp_rx_axis_tvalid[0 +: 1]),
    .rx_axis_tlast(qsfp_rx_axis_tlast[0 +: 1]),
    .rx_axis_tuser(qsfp_rx_axis_tuser[0*(80+1) +: (80+1)]),

    .rx_ptp_time(qsfp_rx_ptp_time[0*80 +: 80]),

    .rx_enable(qsfp_rx_enable[0 +: 1]),
    .rx_status(qsfp_rx_status[0 +: 1]),
    .rx_lfc_en(qsfp_rx_lfc_en[0 +: 1]),
    .rx_lfc_req(qsfp_rx_lfc_req[0 +: 1]),
    .rx_lfc_ack(qsfp_rx_lfc_ack[0 +: 1]),
    .rx_pfc_en(qsfp_rx_pfc_en[0*8 +: 8]),
    .rx_pfc_req(qsfp_rx_pfc_req[0*8 +: 8]),
    .rx_pfc_ack(qsfp_rx_pfc_ack[0*8 +: 8])
);

wire ptp_clk;
wire ptp_rst;
wire ptp_sample_clk;

assign ptp_clk = qsfp_mgt_refclk_0_bufg;
assign ptp_rst = qsfp_rst;
assign ptp_sample_clk = clk_125mhz_int;

assign qsfp_led_stat_g = qsfp_rx_status;

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

    wire hbm_ref_clk = clk_100mhz_1_int;

    wire hbm_cattrip_1;
    wire hbm_cattrip_2;

    assign hbm_cattrip = hbm_cattrip_1 | hbm_cattrip_2;

    fpga_hbm #(
        .HBM_CH(HBM_CH),
        .HBM_GROUP_SIZE(HBM_GROUP_SIZE),
        .AXI_HBM_DATA_WIDTH(AXI_HBM_DATA_WIDTH),
        .AXI_HBM_ADDR_WIDTH(AXI_HBM_ADDR_WIDTH),
        .AXI_HBM_STRB_WIDTH(AXI_HBM_STRB_WIDTH),
        .AXI_HBM_ID_WIDTH(AXI_HBM_ID_WIDTH),
        .AXI_HBM_MAX_BURST_LEN(AXI_HBM_MAX_BURST_LEN)
    )
    hbm_inst (
        .hbm_ref_clk(hbm_ref_clk),
        .hbm_rst_in(rst_125mhz_int),

        .hbm_cattrip_1(hbm_cattrip_1),
        .hbm_cattrip_2(hbm_cattrip_2),
        .hbm_temp_1(hbm_temp_1),
        .hbm_temp_2(hbm_temp_2),

        .hbm_clk(hbm_clk),
        .hbm_rst(hbm_rst),

        .s_axi_hbm_awid(m_axi_hbm_awid),
        .s_axi_hbm_awaddr(m_axi_hbm_awaddr),
        .s_axi_hbm_awlen(m_axi_hbm_awlen),
        .s_axi_hbm_awsize(m_axi_hbm_awsize),
        .s_axi_hbm_awburst(m_axi_hbm_awburst),
        .s_axi_hbm_awlock(m_axi_hbm_awlock),
        .s_axi_hbm_awcache(m_axi_hbm_awcache),
        .s_axi_hbm_awprot(m_axi_hbm_awprot),
        .s_axi_hbm_awqos(m_axi_hbm_awqos),
        .s_axi_hbm_awvalid(m_axi_hbm_awvalid),
        .s_axi_hbm_awready(m_axi_hbm_awready),
        .s_axi_hbm_wdata(m_axi_hbm_wdata),
        .s_axi_hbm_wstrb(m_axi_hbm_wstrb),
        .s_axi_hbm_wlast(m_axi_hbm_wlast),
        .s_axi_hbm_wvalid(m_axi_hbm_wvalid),
        .s_axi_hbm_wready(m_axi_hbm_wready),
        .s_axi_hbm_bid(m_axi_hbm_bid),
        .s_axi_hbm_bresp(m_axi_hbm_bresp),
        .s_axi_hbm_bvalid(m_axi_hbm_bvalid),
        .s_axi_hbm_bready(m_axi_hbm_bready),
        .s_axi_hbm_arid(m_axi_hbm_arid),
        .s_axi_hbm_araddr(m_axi_hbm_araddr),
        .s_axi_hbm_arlen(m_axi_hbm_arlen),
        .s_axi_hbm_arsize(m_axi_hbm_arsize),
        .s_axi_hbm_arburst(m_axi_hbm_arburst),
        .s_axi_hbm_arlock(m_axi_hbm_arlock),
        .s_axi_hbm_arcache(m_axi_hbm_arcache),
        .s_axi_hbm_arprot(m_axi_hbm_arprot),
        .s_axi_hbm_arqos(m_axi_hbm_arqos),
        .s_axi_hbm_arvalid(m_axi_hbm_arvalid),
        .s_axi_hbm_arready(m_axi_hbm_arready),
        .s_axi_hbm_rid(m_axi_hbm_rid),
        .s_axi_hbm_rdata(m_axi_hbm_rdata),
        .s_axi_hbm_rresp(m_axi_hbm_rresp),
        .s_axi_hbm_rlast(m_axi_hbm_rlast),
        .s_axi_hbm_rvalid(m_axi_hbm_rvalid),
        .s_axi_hbm_rready(m_axi_hbm_rready),

        .hbm_status(hbm_status)
    );

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

    assign hbm_cattrip = 1'b0;

    assign hbm_temp_1 = 7'd0;
    assign hbm_temp_2 = 7'd0;

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

    // Board configuration
    .QSFP_CNT(QSFP_CNT),
    .CH_CNT(QSFP_CNT*4),
    .CMS_ENABLE(CMS_ENABLE),
    .FLASH_SEG_COUNT(2),
    .FLASH_SEG_DEFAULT(1),
    .FLASH_SEG_FALLBACK(0),
    .FLASH_SEG0_SIZE(32'h01002000),

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
    .PTP_PORT_CDC_PIPELINE(PTP_PORT_CDC_PIPELINE),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

    // Queue manager configuration
    .EVENT_QUEUE_OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .TX_QUEUE_OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .RX_QUEUE_OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .CQ_OP_TABLE_SIZE(CQ_OP_TABLE_SIZE),
    .EQN_WIDTH(EQN_WIDTH),
    .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .CQN_WIDTH(CQN_WIDTH),
    .EQ_PIPELINE(EQ_PIPELINE),
    .TX_QUEUE_PIPELINE(TX_QUEUE_PIPELINE),
    .RX_QUEUE_PIPELINE(RX_QUEUE_PIPELINE),
    .CQ_PIPELINE(CQ_PIPELINE),

    // TX and RX engine configuration
    .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
    .RX_INDIR_TBL_ADDR_WIDTH(RX_INDIR_TBL_ADDR_WIDTH),

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
    .PFC_ENABLE(PFC_ENABLE),
    .LFC_ENABLE(LFC_ENABLE),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

    // RAM configuration
    .DDR_ENABLE(0),
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
     * GPIO
     */
    .sw(0),
    .led(),
    .qsfp_led_act(qsfp_led_act),
    //.qsfp_led_stat_g(qsfp_led_stat_g),
    .qsfp_led_stat_y(qsfp_led_stat_y),

    /*
     * I2C
     */
    .i2c_scl_i(1'b1),
    .i2c_scl_o(),
    .i2c_scl_t(),
    .i2c_sda_i(1'b1),
    .i2c_sda_o(),
    .i2c_sda_t(),

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
    .cfg_rcb_status(cfg_rcb_status),

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
    .qsfp_tx_clk(qsfp_tx_clk),
    .qsfp_tx_rst(qsfp_tx_rst),
    .qsfp_tx_axis_tdata(qsfp_tx_axis_tdata),
    .qsfp_tx_axis_tkeep(qsfp_tx_axis_tkeep),
    .qsfp_tx_axis_tvalid(qsfp_tx_axis_tvalid),
    .qsfp_tx_axis_tready(qsfp_tx_axis_tready),
    .qsfp_tx_axis_tlast(qsfp_tx_axis_tlast),
    .qsfp_tx_axis_tuser(qsfp_tx_axis_tuser),
    .qsfp_tx_ptp_time(qsfp_tx_ptp_time),
    .qsfp_tx_ptp_ts(qsfp_tx_ptp_ts),
    .qsfp_tx_ptp_ts_tag(qsfp_tx_ptp_ts_tag),
    .qsfp_tx_ptp_ts_valid(qsfp_tx_ptp_ts_valid),

    .qsfp_tx_enable(qsfp_tx_enable),
    .qsfp_tx_lfc_en(qsfp_tx_lfc_en),
    .qsfp_tx_lfc_req(qsfp_tx_lfc_req),
    .qsfp_tx_pfc_en(qsfp_tx_pfc_en),
    .qsfp_tx_pfc_req(qsfp_tx_pfc_req),

    .qsfp_rx_clk(qsfp_rx_clk),
    .qsfp_rx_rst(qsfp_rx_rst),
    .qsfp_rx_axis_tdata(qsfp_rx_axis_tdata),
    .qsfp_rx_axis_tkeep(qsfp_rx_axis_tkeep),
    .qsfp_rx_axis_tvalid(qsfp_rx_axis_tvalid),
    .qsfp_rx_axis_tlast(qsfp_rx_axis_tlast),
    .qsfp_rx_axis_tuser(qsfp_rx_axis_tuser),
    .qsfp_rx_ptp_time(qsfp_rx_ptp_time),

    .qsfp_rx_enable(qsfp_rx_enable),
    .qsfp_rx_status(qsfp_rx_status),
    .qsfp_rx_lfc_en(qsfp_rx_lfc_en),
    .qsfp_rx_lfc_req(qsfp_rx_lfc_req),
    .qsfp_rx_lfc_ack(qsfp_rx_lfc_ack),
    .qsfp_rx_pfc_en(qsfp_rx_pfc_en),
    .qsfp_rx_pfc_req(qsfp_rx_pfc_req),
    .qsfp_rx_pfc_ack(qsfp_rx_pfc_ack),

    .qsfp_drp_clk(qsfp_drp_clk),
    .qsfp_drp_rst(qsfp_drp_rst),
    .qsfp_drp_addr(qsfp_drp_addr),
    .qsfp_drp_di(qsfp_drp_di),
    .qsfp_drp_en(qsfp_drp_en),
    .qsfp_drp_we(qsfp_drp_we),
    .qsfp_drp_do(qsfp_drp_do),
    .qsfp_drp_rdy(qsfp_drp_rdy),

    .qsfp_modprsl(1'b0),
    .qsfp_modsell(),
    .qsfp_resetl(),
    .qsfp_intl(1'b1),
    .qsfp_lpmode(),

    /*
     * DDR
     */
    .ddr_clk(0),
    .ddr_rst(0),

    .m_axi_ddr_awid(),
    .m_axi_ddr_awaddr(),
    .m_axi_ddr_awlen(),
    .m_axi_ddr_awsize(),
    .m_axi_ddr_awburst(),
    .m_axi_ddr_awlock(),
    .m_axi_ddr_awcache(),
    .m_axi_ddr_awprot(),
    .m_axi_ddr_awqos(),
    .m_axi_ddr_awvalid(),
    .m_axi_ddr_awready(0),
    .m_axi_ddr_wdata(),
    .m_axi_ddr_wstrb(),
    .m_axi_ddr_wlast(),
    .m_axi_ddr_wvalid(),
    .m_axi_ddr_wready(0),
    .m_axi_ddr_bid(0),
    .m_axi_ddr_bresp(0),
    .m_axi_ddr_bvalid(0),
    .m_axi_ddr_bready(),
    .m_axi_ddr_arid(),
    .m_axi_ddr_araddr(),
    .m_axi_ddr_arlen(),
    .m_axi_ddr_arsize(),
    .m_axi_ddr_arburst(),
    .m_axi_ddr_arlock(),
    .m_axi_ddr_arcache(),
    .m_axi_ddr_arprot(),
    .m_axi_ddr_arqos(),
    .m_axi_ddr_arvalid(),
    .m_axi_ddr_arready(0),
    .m_axi_ddr_rid(0),
    .m_axi_ddr_rdata(0),
    .m_axi_ddr_rresp(0),
    .m_axi_ddr_rlast(0),
    .m_axi_ddr_rvalid(0),
    .m_axi_ddr_rready(),

    .ddr_status(0),

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
