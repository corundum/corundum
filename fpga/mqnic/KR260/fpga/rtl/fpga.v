// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 The Regents of the University of California
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
    parameter FPGA_ID = 32'h4A49093,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h10ee_9104,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

    // Board configuration
    parameter TDMA_BER_ENABLE = 0,

    // Structural configuration
    parameter IF_COUNT = 1,
    parameter PORTS_PER_IF = 1,
    parameter SCHED_PER_IF = PORTS_PER_IF,
    parameter PORT_MASK = 0,

    // Clock configuration
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,

    // PTP configuration
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 1,
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
    parameter ENABLE_PADDING = 1,
    parameter ENABLE_DIC = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 32768,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 32768,
    parameter RX_RAM_SIZE = 32768,

    // Application block configuration
    parameter APP_ID = 32'h00000000,
    parameter APP_ENABLE = 0,
    parameter APP_CTRL_ENABLE = 1,
    parameter APP_DMA_ENABLE = 1,
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,
    parameter APP_AXIS_IF_ENABLE = 1,
    parameter APP_STAT_ENABLE = 1,

    // AXI interface configuration (DMA)
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,
    parameter AXI_DMA_MAX_BURST_LEN = 256,

    // Interrupts
    parameter IRQ_COUNT = 32,
    parameter IRQ_STRETCH = 10,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,
    parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8),

    // Ethernet interface configuration
    parameter AXIS_ETH_TX_PIPELINE = 0,
    parameter AXIS_ETH_TX_FIFO_PIPELINE = 2,
    parameter AXIS_ETH_TX_TS_PIPELINE = 0,
    parameter AXIS_ETH_RX_PIPELINE = 0,
    parameter AXIS_ETH_RX_FIFO_PIPELINE = 2,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_DMA_ENABLE = 1,
    parameter STAT_AXI_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    /*
     * Clock: 125MHz LVDS
     */
    input  wire         clk_125mhz_p,
    input  wire         clk_125mhz_n,

    /*
     * GPIO
     */
    output wire [1:0]   led,
    output wire [1:0]   sfp_led,

    /*
     * Ethernet: SFP+
     */
    input  wire         sfp_rx_p,
    input  wire         sfp_rx_n,
    output wire         sfp_tx_p,
    output wire         sfp_tx_n,
    input  wire         sfp_mgt_refclk_p,
    input  wire         sfp_mgt_refclk_n,

    output wire         sfp_tx_disable,
    input  wire         sfp_tx_fault,
    input  wire         sfp_rx_los,
    input  wire         sfp_mod_abs,
    inout  wire         sfp_i2c_scl,
    inout  wire         sfp_i2c_sda
);

// PTP configuration
parameter PTP_CLK_PERIOD_NS_NUM = 32;
parameter PTP_CLK_PERIOD_NS_DENOM = 5;
parameter PTP_TS_WIDTH = 96;
parameter IF_PTP_PERIOD_NS = 6'h6;
parameter IF_PTP_PERIOD_FNS = 16'h6666;

// Interface configuration
parameter TX_TAG_WIDTH = 16;

// Ethernet interface configuration
parameter XGMII_DATA_WIDTH = 64;
parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8;
parameter AXIS_ETH_DATA_WIDTH = XGMII_DATA_WIDTH;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH;
parameter AXIS_ETH_TX_USER_WIDTH = TX_TAG_WIDTH + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire zynq_pl_clk;
wire zynq_pl_reset;

wire clk_156mhz_int;

wire clk_125mhz_mmcm_out;

// Internal 125 MHz clock
wire clk_125mhz_int;
wire rst_125mhz_int;

wire mmcm_rst = zynq_pl_reset;
wire mmcm_locked;
wire mmcm_clkfb;

// MMCM instance
// 156.25 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 800 MHz to 1600 MHz
// M = 8, D = 1 sets Fvco = 1250 MHz
// Divide by 10 to get output frequency of 125 MHz
MMCME4_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(10),
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
    .CLKFBOUT_MULT_F(8),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(6.4),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_156mhz_int),
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
wire sfp_tx_fault_int;
wire sfp_rx_los_int;
wire sfp_mod_abs_int;

wire sfp_i2c_scl_i;
wire sfp_i2c_scl_o;
wire sfp_i2c_scl_t;
wire sfp_i2c_sda_i;
wire sfp_i2c_sda_o;
wire sfp_i2c_sda_t;

reg sfp_i2c_scl_o_reg;
reg sfp_i2c_scl_t_reg;
reg sfp_i2c_sda_o_reg;
reg sfp_i2c_sda_t_reg;

always @(posedge zynq_pl_clk) begin
    sfp_i2c_scl_o_reg <= sfp_i2c_scl_o;
    sfp_i2c_scl_t_reg <= sfp_i2c_scl_t;
    sfp_i2c_sda_o_reg <= sfp_i2c_sda_o;
    sfp_i2c_sda_t_reg <= sfp_i2c_sda_t;
end

sync_signal #(
    .WIDTH(5),
    .N(2)
)
sync_signal_inst (
    .clk(zynq_pl_clk),
    .in({sfp_tx_fault, sfp_rx_los, sfp_mod_abs, sfp_i2c_scl, sfp_i2c_sda}),
    .out({sfp_tx_fault_int, sfp_rx_los_int, sfp_mod_abs_int, sfp_i2c_scl_i, sfp_i2c_sda_i})
);

assign sfp_i2c_scl = sfp_i2c_scl_t_reg ? 1'bz : sfp_i2c_scl_o_reg;
assign sfp_i2c_sda = sfp_i2c_sda_t_reg ? 1'bz : sfp_i2c_sda_o_reg;

// Zynq AXI MM
wire [IRQ_COUNT-1:0]                 irq;

wire [AXI_ID_WIDTH-1:0]              axi_awid;
wire [AXI_ADDR_WIDTH-1:0]            axi_awaddr;
wire [7:0]                           axi_awlen;
wire [2:0]                           axi_awsize;
wire [1:0]                           axi_awburst;
wire                                 axi_awlock;
wire [3:0]                           axi_awcache;
wire [2:0]                           axi_awprot;
wire                                 axi_awvalid;
wire                                 axi_awready;
wire [AXI_DATA_WIDTH-1:0]            axi_wdata;
wire [AXI_STRB_WIDTH-1:0]            axi_wstrb;
wire                                 axi_wlast;
wire                                 axi_wvalid;
wire                                 axi_wready;
wire [AXI_ID_WIDTH-1:0]              axi_bid;
wire [1:0]                           axi_bresp;
wire                                 axi_bvalid;
wire                                 axi_bready;
wire [AXI_ID_WIDTH-1:0]              axi_arid;
wire [AXI_ADDR_WIDTH-1:0]            axi_araddr;
wire [7:0]                           axi_arlen;
wire [2:0]                           axi_arsize;
wire [1:0]                           axi_arburst;
wire                                 axi_arlock;
wire [3:0]                           axi_arcache;
wire [2:0]                           axi_arprot;
wire                                 axi_arvalid;
wire                                 axi_arready;
wire [AXI_ID_WIDTH-1:0]              axi_rid;
wire [AXI_DATA_WIDTH-1:0]            axi_rdata;
wire [1:0]                           axi_rresp;
wire                                 axi_rlast;
wire                                 axi_rvalid;
wire                                 axi_rready;

// AXI lite connections
wire [AXIL_CTRL_ADDR_WIDTH-1:0]      axil_ctrl_awaddr;
wire [2:0]                           axil_ctrl_awprot;
wire                                 axil_ctrl_awvalid;
wire                                 axil_ctrl_awready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]      axil_ctrl_wdata;
wire [AXIL_CTRL_STRB_WIDTH-1:0]      axil_ctrl_wstrb;
wire                                 axil_ctrl_wvalid;
wire                                 axil_ctrl_wready;
wire [1:0]                           axil_ctrl_bresp;
wire                                 axil_ctrl_bvalid;
wire                                 axil_ctrl_bready;
wire [AXIL_CTRL_ADDR_WIDTH-1:0]      axil_ctrl_araddr;
wire [2:0]                           axil_ctrl_arprot;
wire                                 axil_ctrl_arvalid;
wire                                 axil_ctrl_arready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]      axil_ctrl_rdata;
wire [1:0]                           axil_ctrl_rresp;
wire                                 axil_ctrl_rvalid;
wire                                 axil_ctrl_rready;

wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]  axil_app_ctrl_awaddr;
wire [2:0]                           axil_app_ctrl_awprot;
wire                                 axil_app_ctrl_awvalid;
wire                                 axil_app_ctrl_awready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]  axil_app_ctrl_wdata;
wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]  axil_app_ctrl_wstrb;
wire                                 axil_app_ctrl_wvalid;
wire                                 axil_app_ctrl_wready;
wire [1:0]                           axil_app_ctrl_bresp;
wire                                 axil_app_ctrl_bvalid;
wire                                 axil_app_ctrl_bready;
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]  axil_app_ctrl_araddr;
wire [2:0]                           axil_app_ctrl_arprot;
wire                                 axil_app_ctrl_arvalid;
wire                                 axil_app_ctrl_arready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]  axil_app_ctrl_rdata;
wire [1:0]                           axil_app_ctrl_rresp;
wire                                 axil_app_ctrl_rvalid;
wire                                 axil_app_ctrl_rready;

reg [(IRQ_COUNT*IRQ_STRETCH)-1:0] irq_stretch = {(IRQ_COUNT*IRQ_STRETCH){1'b0}};
always @(posedge zynq_pl_clk) begin
    if (zynq_pl_reset) begin
        irq_stretch <= {(IRQ_COUNT*IRQ_STRETCH){1'b0}};
    end else begin
        /* IRQ shift vector */
        irq_stretch <= {irq_stretch[0 +: (IRQ_COUNT*IRQ_STRETCH)-IRQ_COUNT], irq};
    end
end

reg [IRQ_COUNT-1:0] zynq_irq;
integer i, k;
always @* begin
    for (k = 0; k < IRQ_COUNT; k = k + 1) begin
        zynq_irq[k] = 1'b0;
        for (i = 0; i < (IRQ_COUNT*IRQ_STRETCH); i = i + IRQ_COUNT) begin
            zynq_irq[k] = zynq_irq[k] | irq_stretch[k + i];
        end
    end
end

zynq_ps zynq_ps_inst (
    .pl_clk0(zynq_pl_clk),
    .pl_reset(zynq_pl_reset),
    .pl_ps_irq0(zynq_irq),

    .m_axil_ctrl_araddr(axil_ctrl_araddr),
    .m_axil_ctrl_arprot(axil_ctrl_arprot),
    .m_axil_ctrl_arready(axil_ctrl_arready),
    .m_axil_ctrl_arvalid(axil_ctrl_arvalid),
    .m_axil_ctrl_awaddr(axil_ctrl_awaddr),
    .m_axil_ctrl_awprot(axil_ctrl_awprot),
    .m_axil_ctrl_awready(axil_ctrl_awready),
    .m_axil_ctrl_awvalid(axil_ctrl_awvalid),
    .m_axil_ctrl_bready(axil_ctrl_bready),
    .m_axil_ctrl_bresp(axil_ctrl_bresp),
    .m_axil_ctrl_bvalid(axil_ctrl_bvalid),
    .m_axil_ctrl_rdata(axil_ctrl_rdata),
    .m_axil_ctrl_rready(axil_ctrl_rready),
    .m_axil_ctrl_rresp(axil_ctrl_rresp),
    .m_axil_ctrl_rvalid(axil_ctrl_rvalid),
    .m_axil_ctrl_wdata(axil_ctrl_wdata),
    .m_axil_ctrl_wready(axil_ctrl_wready),
    .m_axil_ctrl_wstrb(axil_ctrl_wstrb),
    .m_axil_ctrl_wvalid(axil_ctrl_wvalid),

    .m_axil_app_ctrl_araddr(axil_app_ctrl_araddr),
    .m_axil_app_ctrl_arprot(axil_app_ctrl_arprot),
    .m_axil_app_ctrl_arready(axil_app_ctrl_arready),
    .m_axil_app_ctrl_arvalid(axil_app_ctrl_arvalid),
    .m_axil_app_ctrl_awaddr(axil_app_ctrl_awaddr),
    .m_axil_app_ctrl_awprot(axil_app_ctrl_awprot),
    .m_axil_app_ctrl_awready(axil_app_ctrl_awready),
    .m_axil_app_ctrl_awvalid(axil_app_ctrl_awvalid),
    .m_axil_app_ctrl_bready(axil_app_ctrl_bready),
    .m_axil_app_ctrl_bresp(axil_app_ctrl_bresp),
    .m_axil_app_ctrl_bvalid(axil_app_ctrl_bvalid),
    .m_axil_app_ctrl_rdata(axil_app_ctrl_rdata),
    .m_axil_app_ctrl_rready(axil_app_ctrl_rready),
    .m_axil_app_ctrl_rresp(axil_app_ctrl_rresp),
    .m_axil_app_ctrl_rvalid(axil_app_ctrl_rvalid),
    .m_axil_app_ctrl_wdata(axil_app_ctrl_wdata),
    .m_axil_app_ctrl_wready(axil_app_ctrl_wready),
    .m_axil_app_ctrl_wstrb(axil_app_ctrl_wstrb),
    .m_axil_app_ctrl_wvalid(axil_app_ctrl_wvalid),

    .s_axi_dma_araddr(axi_araddr),
    .s_axi_dma_arburst(axi_arburst),
    .s_axi_dma_arcache(axi_arcache),
    .s_axi_dma_arid(axi_arid),
    .s_axi_dma_arlen(axi_arlen),
    .s_axi_dma_arlock(axi_arlock),
    .s_axi_dma_arprot(axi_arprot),
    .s_axi_dma_arqos({4{1'b0}}),
    .s_axi_dma_arready(axi_arready),
    .s_axi_dma_arsize(axi_arsize),
    .s_axi_dma_aruser(1'b0),
    .s_axi_dma_arvalid(axi_arvalid),
    .s_axi_dma_awaddr(axi_awaddr),
    .s_axi_dma_awburst(axi_awburst),
    .s_axi_dma_awcache(axi_awcache),
    .s_axi_dma_awid(axi_awid),
    .s_axi_dma_awlen(axi_awlen),
    .s_axi_dma_awlock(axi_awlock),
    .s_axi_dma_awprot(axi_awprot),
    .s_axi_dma_awqos({4{1'b0}}),
    .s_axi_dma_awready(axi_awready),
    .s_axi_dma_awsize(axi_awsize),
    .s_axi_dma_awuser(1'b0),
    .s_axi_dma_awvalid(axi_awvalid),
    .s_axi_dma_bid(axi_bid),
    .s_axi_dma_bready(axi_bready),
    .s_axi_dma_bresp(axi_bresp),
    .s_axi_dma_bvalid(axi_bvalid),
    .s_axi_dma_rdata(axi_rdata),
    .s_axi_dma_rid(axi_rid),
    .s_axi_dma_rlast(axi_rlast),
    .s_axi_dma_rready(axi_rready),
    .s_axi_dma_rresp(axi_rresp),
    .s_axi_dma_rvalid(axi_rvalid),
    .s_axi_dma_wdata(axi_wdata),
    .s_axi_dma_wlast(axi_wlast),
    .s_axi_dma_wready(axi_wready),
    .s_axi_dma_wstrb(axi_wstrb),
    .s_axi_dma_wvalid(axi_wvalid)
);

// XGMII 10G PHY
wire                         sfp_tx_clk_int;
wire                         sfp_tx_rst_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_txd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_txc_int;
wire                         sfp_cfg_tx_prbs31_enable_int;
wire                         sfp_rx_clk_int;
wire                         sfp_rx_rst_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_rxd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_rxc_int;
wire                         sfp_cfg_rx_prbs31_enable_int;
wire [6:0]                   sfp_rx_error_count_int;

wire        sfp_drp_clk = clk_125mhz_int;
wire        sfp_drp_rst = rst_125mhz_int;
wire [23:0] sfp_drp_addr;
wire [15:0] sfp_drp_di;
wire        sfp_drp_en;
wire        sfp_drp_we;
wire [15:0] sfp_drp_do;
wire        sfp_drp_rdy;

wire sfp_rx_block_lock;
wire sfp_rx_status;
wire sfp_gtpowergood;

wire sfp_mgt_refclk;
wire sfp_mgt_refclk_int;
wire sfp_mgt_refclk_bufg;

assign clk_156mhz_int = sfp_mgt_refclk_bufg;

IBUFDS_GTE4 ibufds_gte4_sfp_mgt_refclk_inst (
    .I     (sfp_mgt_refclk_p),
    .IB    (sfp_mgt_refclk_n),
    .CEB   (1'b0),
    .O     (sfp_mgt_refclk),
    .ODIV2 (sfp_mgt_refclk_int)
);

BUFG_GT bufg_gt_sfp_mgt_refclk_inst (
    .CE      (sfp_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (sfp_mgt_refclk_int),
    .O       (sfp_mgt_refclk_bufg)
);

wire sfp_rst;

sync_reset #(
    .N(4)
)
sfp_sync_reset_inst (
    .clk(sfp_mgt_refclk_bufg),
    .rst(rst_125mhz_int),
    .out(sfp_rst)
);

eth_xcvr_phy_10g_gty_quad_wrapper #(
    .COUNT(1),
    .GT_GTH(1),
    .PRBS31_ENABLE(1)
)
sfp_phy_quad_inst (
    .xcvr_ctrl_clk(clk_125mhz_int),
    .xcvr_ctrl_rst(sfp_rst),

    /*
     * Common
     */
    .xcvr_gtpowergood_out(sfp_gtpowergood),
    .xcvr_gtrefclk00_in(sfp_mgt_refclk),
    .xcvr_qpll0pd_in(1'b0),
    .xcvr_qpll0reset_in(1'b0),
    .xcvr_qpll0pcierate_in(3'd0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0clk_out(),
    .xcvr_qpll0refclk_out(),
    .xcvr_gtrefclk01_in(sfp_mgt_refclk),
    .xcvr_qpll1pd_in(1'b0),
    .xcvr_qpll1reset_in(1'b0),
    .xcvr_qpll1pcierate_in(3'd0),
    .xcvr_qpll1lock_out(),
    .xcvr_qpll1clk_out(),
    .xcvr_qpll1refclk_out(),

    /*
     * DRP
     */
    .drp_clk(sfp_drp_clk),
    .drp_rst(sfp_drp_rst),
    .drp_addr(sfp_drp_addr),
    .drp_di(sfp_drp_di),
    .drp_en(sfp_drp_en),
    .drp_we(sfp_drp_we),
    .drp_do(sfp_drp_do),
    .drp_rdy(sfp_drp_rdy),

    /*
     * Serial data
     */
    .xcvr_txp({sfp_tx_p}),
    .xcvr_txn({sfp_tx_n}),
    .xcvr_rxp({sfp_rx_p}),
    .xcvr_rxn({sfp_rx_n}),

    /*
     * PHY connections
     */
    .phy_1_tx_clk(sfp_tx_clk_int),
    .phy_1_tx_rst(sfp_tx_rst_int),
    .phy_1_xgmii_txd(sfp_txd_int),
    .phy_1_xgmii_txc(sfp_txc_int),
    .phy_1_rx_clk(sfp_rx_clk_int),
    .phy_1_rx_rst(sfp_rx_rst_int),
    .phy_1_xgmii_rxd(sfp_rxd_int),
    .phy_1_xgmii_rxc(sfp_rxc_int),
    .phy_1_tx_bad_block(),
    .phy_1_rx_error_count(sfp_rx_error_count_int),
    .phy_1_rx_bad_block(),
    .phy_1_rx_sequence_error(),
    .phy_1_rx_block_lock(sfp_rx_block_lock),
    .phy_1_rx_high_ber(),
    .phy_1_rx_status(sfp_rx_status),
    .phy_1_cfg_tx_prbs31_enable(sfp_cfg_tx_prbs31_enable_int),
    .phy_1_cfg_rx_prbs31_enable(sfp_cfg_rx_prbs31_enable_int)
);

wire ptp_clk;
wire ptp_rst;
wire ptp_sample_clk;

assign ptp_clk = sfp_mgt_refclk_bufg;
assign ptp_rst = sfp_rst;
assign ptp_sample_clk = clk_125mhz_int;

assign sfp_led[0] = sfp_rx_status;
assign sfp_led[1] = 1'b0;

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
    .TDMA_BER_ENABLE(TDMA_BER_ENABLE),

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
    .ENABLE_PADDING(ENABLE_PADDING),
    .ENABLE_DIC(ENABLE_DIC),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

    // Application block configuration
    .APP_ID(APP_ID),
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),

    // AXI interface configuration (DMA)
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),

    // DMA interface configuration
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),
    .AXI_DMA_MAX_BURST_LEN(AXI_DMA_MAX_BURST_LEN),

    // Interrupts
    .IRQ_COUNT(IRQ_COUNT),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),

    // AXI lite interface configuration (application control)
    .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),
    .AXIL_APP_CTRL_STRB_WIDTH(AXIL_APP_CTRL_STRB_WIDTH),

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
    .STAT_AXI_ENABLE(STAT_AXI_ENABLE),
    .STAT_INC_WIDTH(STAT_INC_WIDTH),
    .STAT_ID_WIDTH(STAT_ID_WIDTH)
)
core_inst (
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    .clk_250mhz(zynq_pl_clk),
    .rst_250mhz(zynq_pl_reset),

    /*
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),

    /*
     * GPIO
     */
    .led(led),
    // .sfp_led(sfp_led),

    /*
     * Interrupt outputs
     */
    .irq(irq),

    /*
     * AXI master interface (DMA)
     */
    .m_axi_awid(axi_awid),
    .m_axi_awaddr(axi_awaddr),
    .m_axi_awlen(axi_awlen),
    .m_axi_awsize(axi_awsize),
    .m_axi_awburst(axi_awburst),
    .m_axi_awlock(axi_awlock),
    .m_axi_awcache(axi_awcache),
    .m_axi_awprot(axi_awprot),
    .m_axi_awvalid(axi_awvalid),
    .m_axi_awready(axi_awready),
    .m_axi_wdata(axi_wdata),
    .m_axi_wstrb(axi_wstrb),
    .m_axi_wlast(axi_wlast),
    .m_axi_wvalid(axi_wvalid),
    .m_axi_wready(axi_wready),
    .m_axi_bid(axi_bid),
    .m_axi_bresp(axi_bresp),
    .m_axi_bvalid(axi_bvalid),
    .m_axi_bready(axi_bready),
    .m_axi_arid(axi_arid),
    .m_axi_araddr(axi_araddr),
    .m_axi_arlen(axi_arlen),
    .m_axi_arsize(axi_arsize),
    .m_axi_arburst(axi_arburst),
    .m_axi_arlock(axi_arlock),
    .m_axi_arcache(axi_arcache),
    .m_axi_arprot(axi_arprot),
    .m_axi_arvalid(axi_arvalid),
    .m_axi_arready(axi_arready),
    .m_axi_rid(axi_rid),
    .m_axi_rdata(axi_rdata),
    .m_axi_rresp(axi_rresp),
    .m_axi_rlast(axi_rlast),
    .m_axi_rvalid(axi_rvalid),
    .m_axi_rready(axi_rready),

    /*
     * AXI lite interface configuration (control)
     */
    .s_axil_ctrl_awaddr(axil_ctrl_awaddr),
    .s_axil_ctrl_awprot(axil_ctrl_awprot),
    .s_axil_ctrl_awvalid(axil_ctrl_awvalid),
    .s_axil_ctrl_awready(axil_ctrl_awready),
    .s_axil_ctrl_wdata(axil_ctrl_wdata),
    .s_axil_ctrl_wstrb(axil_ctrl_wstrb),
    .s_axil_ctrl_wvalid(axil_ctrl_wvalid),
    .s_axil_ctrl_wready(axil_ctrl_wready),
    .s_axil_ctrl_bresp(axil_ctrl_bresp),
    .s_axil_ctrl_bvalid(axil_ctrl_bvalid),
    .s_axil_ctrl_bready(axil_ctrl_bready),
    .s_axil_ctrl_araddr(axil_ctrl_araddr),
    .s_axil_ctrl_arprot(axil_ctrl_arprot),
    .s_axil_ctrl_arvalid(axil_ctrl_arvalid),
    .s_axil_ctrl_arready(axil_ctrl_arready),
    .s_axil_ctrl_rdata(axil_ctrl_rdata),
    .s_axil_ctrl_rresp(axil_ctrl_rresp),
    .s_axil_ctrl_rvalid(axil_ctrl_rvalid),
    .s_axil_ctrl_rready(axil_ctrl_rready),

    /*
     * AXI lite interface configuration (application control)
     */
    .s_axil_app_ctrl_awaddr(axil_app_ctrl_awaddr),
    .s_axil_app_ctrl_awprot(axil_app_ctrl_awprot),
    .s_axil_app_ctrl_awvalid(axil_app_ctrl_awvalid),
    .s_axil_app_ctrl_awready(axil_app_ctrl_awready),
    .s_axil_app_ctrl_wdata(axil_app_ctrl_wdata),
    .s_axil_app_ctrl_wstrb(axil_app_ctrl_wstrb),
    .s_axil_app_ctrl_wvalid(axil_app_ctrl_wvalid),
    .s_axil_app_ctrl_wready(axil_app_ctrl_wready),
    .s_axil_app_ctrl_bresp(axil_app_ctrl_bresp),
    .s_axil_app_ctrl_bvalid(axil_app_ctrl_bvalid),
    .s_axil_app_ctrl_bready(axil_app_ctrl_bready),
    .s_axil_app_ctrl_araddr(axil_app_ctrl_araddr),
    .s_axil_app_ctrl_arprot(axil_app_ctrl_arprot),
    .s_axil_app_ctrl_arvalid(axil_app_ctrl_arvalid),
    .s_axil_app_ctrl_arready(axil_app_ctrl_arready),
    .s_axil_app_ctrl_rdata(axil_app_ctrl_rdata),
    .s_axil_app_ctrl_rresp(axil_app_ctrl_rresp),
    .s_axil_app_ctrl_rvalid(axil_app_ctrl_rvalid),
    .s_axil_app_ctrl_rready(axil_app_ctrl_rready),

    /*
     * Ethernet: SFP+
     */
    .sfp_tx_clk(sfp_tx_clk_int),
    .sfp_tx_rst(sfp_tx_rst_int),
    .sfp_txd(sfp_txd_int),
    .sfp_txc(sfp_txc_int),
    .sfp_cfg_tx_prbs31_enable(sfp_cfg_tx_prbs31_enable_int),
    .sfp_rx_clk(sfp_rx_clk_int),
    .sfp_rx_rst(sfp_rx_rst_int),
    .sfp_rxd(sfp_rxd_int),
    .sfp_rxc(sfp_rxc_int),
    .sfp_cfg_rx_prbs31_enable(sfp_cfg_rx_prbs31_enable_int),
    .sfp_rx_error_count(sfp_rx_error_count_int),
    .sfp_rx_status(sfp_rx_status),

    .sfp_tx_disable(sfp_tx_disable),
    .sfp_tx_fault(sfp_tx_fault_int),
    .sfp_rx_los(sfp_rx_los_int),
    .sfp_mod_abs(sfp_mod_abs_int),
    .sfp_i2c_scl_i(sfp_i2c_scl_i),
    .sfp_i2c_scl_o(sfp_i2c_scl_o),
    .sfp_i2c_scl_t(sfp_i2c_scl_t),
    .sfp_i2c_sda_i(sfp_i2c_sda_i),
    .sfp_i2c_sda_o(sfp_i2c_sda_o),
    .sfp_i2c_sda_t(sfp_i2c_sda_t),

    .sfp_drp_clk(sfp_drp_clk),
    .sfp_drp_rst(sfp_drp_rst),
    .sfp_drp_addr(sfp_drp_addr),
    .sfp_drp_di(sfp_drp_di),
    .sfp_drp_en(sfp_drp_en),
    .sfp_drp_we(sfp_drp_we),
    .sfp_drp_do(sfp_drp_do),
    .sfp_drp_rdy(sfp_drp_rdy)
);

endmodule

`resetall
