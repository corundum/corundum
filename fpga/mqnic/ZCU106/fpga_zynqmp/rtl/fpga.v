/*

Copyright 2021-2022, MissingLinkElectronics Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY MISSINGLINKELECTRONICS INC. ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL MISSINGLINKELECTRONICS INC. OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of MissingLinkElectronics Inc.

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
    parameter FPGA_ID = 32'h4730093,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h10ee_906a,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'hdce357bf,
    parameter RELEASE_INFO = 32'h00000000,

    // Structural configuration
    parameter IF_COUNT = 2,
    parameter PORTS_PER_IF = 1,
    parameter SCHED_PER_IF = PORTS_PER_IF,

    // PTP configuration
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 1,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration (interface)
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

    // AXI interface configuration (DMA)
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,

    // DMA interface configuration
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
    input  wire         btnu,
    input  wire         btnl,
    input  wire         btnd,
    input  wire         btnr,
    input  wire         btnc,
    input  wire [7:0]   sw,
    output wire [7:0]   led,

    /*
     * Ethernet: SFP+
     */
    input  wire         sfp0_rx_p,
    input  wire         sfp0_rx_n,
    output wire         sfp0_tx_p,
    output wire         sfp0_tx_n,
    input  wire         sfp1_rx_p,
    input  wire         sfp1_rx_n,
    output wire         sfp1_tx_p,
    output wire         sfp1_tx_n,
    input  wire         sfp_mgt_refclk_0_p,
    input  wire         sfp_mgt_refclk_0_n,
    output wire         sfp0_tx_disable_b,
    output wire         sfp1_tx_disable_b
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
parameter IF_PTP_PERIOD_NS = 6'h6;
parameter IF_PTP_PERIOD_FNS = 16'h6666;

// Ethernet interface configuration
parameter XGMII_DATA_WIDTH = 64;
parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8;
parameter AXIS_ETH_DATA_WIDTH = XGMII_DATA_WIDTH;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH;
parameter AXIS_ETH_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire zynq_user_clk;
wire zynq_user_reset;

wire clk_125mhz_ibufg;
wire clk_125mhz_mmcm_out;

// Internal 125 MHz clock
wire clk_125mhz_int;
wire rst_125mhz_int;

// Internal 156.25 MHz clock
wire clk_156mhz_int;
wire rst_156mhz_int;

wire mmcm_rst = zynq_user_reset;
wire mmcm_locked;
wire mmcm_clkfb;

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")
)
clk_125mhz_ibufg_inst (
   .O   (clk_125mhz_ibufg),
   .I   (clk_125mhz_p),
   .IB  (clk_125mhz_n)
);

// MMCM instance
// 125 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 800 MHz to 1600 MHz
// M = 8, D = 1 sets Fvco = 1000 MHz (in range)
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
    .CLKFBOUT_MULT_F(8),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(8.0),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_125mhz_ibufg),
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
wire [7:0] sw_int;
wire qsfp1_modprsl_int;
wire qsfp2_modprsl_int;
wire qsfp1_intl_int;
wire qsfp2_intl_int;

debounce_switch #(
    .WIDTH(13),
    .N(4),
    .RATE(250000)
)
debounce_switch_inst (
    .clk(zynq_user_clk),
    .rst(zynq_user_reset),
    .in({btnu,
        btnl,
        btnd,
        btnr,
        btnc,
        sw}),
    .out({btnu_int,
        btnl_int,
        btnd_int,
        btnr_int,
        btnc_int,
        sw_int})
);

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
always @(posedge zynq_user_clk) begin
    if (zynq_user_reset) begin
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

bd_zynq bd_zynq_inst (
    .clk(zynq_user_clk),
    .rst(zynq_user_reset),

    .irq(zynq_irq),

    .m_axil_0_araddr(axil_ctrl_araddr),
    .m_axil_0_arprot(axil_ctrl_arprot),
    .m_axil_0_arready(axil_ctrl_arready),
    .m_axil_0_arvalid(axil_ctrl_arvalid),
    .m_axil_0_awaddr(axil_ctrl_awaddr),
    .m_axil_0_awprot(axil_ctrl_awprot),
    .m_axil_0_awready(axil_ctrl_awready),
    .m_axil_0_awvalid(axil_ctrl_awvalid),
    .m_axil_0_bready(axil_ctrl_bready),
    .m_axil_0_bresp(axil_ctrl_bresp),
    .m_axil_0_bvalid(axil_ctrl_bvalid),
    .m_axil_0_rdata(axil_ctrl_rdata),
    .m_axil_0_rready(axil_ctrl_rready),
    .m_axil_0_rresp(axil_ctrl_rresp),
    .m_axil_0_rvalid(axil_ctrl_rvalid),
    .m_axil_0_wdata(axil_ctrl_wdata),
    .m_axil_0_wready(axil_ctrl_wready),
    .m_axil_0_wstrb(axil_ctrl_wstrb),
    .m_axil_0_wvalid(axil_ctrl_wvalid),

    .m_axil_1_araddr(axil_app_ctrl_araddr),
    .m_axil_1_arprot(axil_app_ctrl_arprot),
    .m_axil_1_arready(axil_app_ctrl_arready),
    .m_axil_1_arvalid(axil_app_ctrl_arvalid),
    .m_axil_1_awaddr(axil_app_ctrl_awaddr),
    .m_axil_1_awprot(axil_app_ctrl_awprot),
    .m_axil_1_awready(axil_app_ctrl_awready),
    .m_axil_1_awvalid(axil_app_ctrl_awvalid),
    .m_axil_1_bready(axil_app_ctrl_bready),
    .m_axil_1_bresp(axil_app_ctrl_bresp),
    .m_axil_1_bvalid(axil_app_ctrl_bvalid),
    .m_axil_1_rdata(axil_app_ctrl_rdata),
    .m_axil_1_rready(axil_app_ctrl_rready),
    .m_axil_1_rresp(axil_app_ctrl_rresp),
    .m_axil_1_rvalid(axil_app_ctrl_rvalid),
    .m_axil_1_wdata(axil_app_ctrl_wdata),
    .m_axil_1_wready(axil_app_ctrl_wready),
    .m_axil_1_wstrb(axil_app_ctrl_wstrb),
    .m_axil_1_wvalid(axil_app_ctrl_wvalid),

    .s_axi_mm_araddr(axi_araddr),
    .s_axi_mm_arburst(axi_arburst),
    .s_axi_mm_arcache(axi_arcache),
    .s_axi_mm_arid(axi_arid),
    .s_axi_mm_arlen(axi_arlen),
    .s_axi_mm_arlock(axi_arlock),
    .s_axi_mm_arprot(axi_arprot),
    .s_axi_mm_arqos({4{1'b0}}),
    .s_axi_mm_arready(axi_arready),
    .s_axi_mm_arsize(axi_arsize),
    .s_axi_mm_aruser(1'b0),
    .s_axi_mm_arvalid(axi_arvalid),
    .s_axi_mm_awaddr(axi_awaddr),
    .s_axi_mm_awburst(axi_awburst),
    .s_axi_mm_awcache(axi_awcache),
    .s_axi_mm_awid(axi_awid),
    .s_axi_mm_awlen(axi_awlen),
    .s_axi_mm_awlock(axi_awlock),
    .s_axi_mm_awprot(axi_awprot),
    .s_axi_mm_awqos({4{1'b0}}),
    .s_axi_mm_awready(axi_awready),
    .s_axi_mm_awsize(axi_awsize),
    .s_axi_mm_awuser(1'b0),
    .s_axi_mm_awvalid(axi_awvalid),
    .s_axi_mm_bid(axi_bid),
    .s_axi_mm_bready(axi_bready),
    .s_axi_mm_bresp(axi_bresp),
    .s_axi_mm_bvalid(axi_bvalid),
    .s_axi_mm_rdata(axi_rdata),
    .s_axi_mm_rid(axi_rid),
    .s_axi_mm_rlast(axi_rlast),
    .s_axi_mm_rready(axi_rready),
    .s_axi_mm_rresp(axi_rresp),
    .s_axi_mm_rvalid(axi_rvalid),
    .s_axi_mm_wdata(axi_wdata),
    .s_axi_mm_wlast(axi_wlast),
    .s_axi_mm_wready(axi_wready),
    .s_axi_mm_wstrb(axi_wstrb),
    .s_axi_mm_wvalid(axi_wvalid)
);

// XGMII 10G PHY
wire                         sfp0_tx_clk_int;
wire                         sfp0_tx_rst_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp0_txd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp0_txc_int;
wire                         sfp0_tx_prbs31_enable_int;
wire                         sfp0_rx_clk_int;
wire                         sfp0_rx_rst_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp0_rxd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp0_rxc_int;
wire                         sfp0_rx_prbs31_enable_int;
wire [6:0]                   sfp0_rx_error_count_int;

wire                         sfp1_tx_clk_int;
wire                         sfp1_tx_rst_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp1_txd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp1_txc_int;
wire                         sfp1_tx_prbs31_enable_int;
wire                         sfp1_rx_clk_int;
wire                         sfp1_rx_rst_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp1_rxd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp1_rxc_int;
wire                         sfp1_rx_prbs31_enable_int;
wire [6:0]                   sfp1_rx_error_count_int;

wire        sfp_drp_clk = clk_125mhz_int;
wire        sfp_drp_rst = rst_125mhz_int;
wire [23:0] sfp_drp_addr;
wire [15:0] sfp_drp_di;
wire        sfp_drp_en;
wire        sfp_drp_we;
wire [15:0] sfp_drp_do;
wire        sfp_drp_rdy;

wire sfp0_rx_block_lock;
wire sfp1_rx_block_lock;

wire sfp_gtpowergood;

wire sfp_mgt_refclk_0;
wire sfp_mgt_refclk_0_int;
wire sfp_mgt_refclk_0_bufg;

IBUFDS_GTE4 ibufds_gte4_sfp_mgt_refclk_0_inst (
    .I     (sfp_mgt_refclk_0_p),
    .IB    (sfp_mgt_refclk_0_n),
    .CEB   (1'b0),
    .O     (sfp_mgt_refclk_0),
    .ODIV2 (sfp_mgt_refclk_0_int)
);

BUFG_GT bufg_gt_sfp_mgt_refclk_0_inst (
    .CE      (sfp_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (sfp_mgt_refclk_0_int),
    .O       (sfp_mgt_refclk_0_bufg)
);

wire sfp_rst;

sync_reset #(
    .N(4)
)
sfp_sync_reset_inst (
    .clk(sfp_mgt_refclk_0_bufg),
    .rst(rst_125mhz_int),
    .out(sfp_rst)
);

eth_xcvr_phy_10g_gty_quad_wrapper #(
    .COUNT(2),
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
    .xcvr_ref_clk(sfp_mgt_refclk_0),

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
    .xcvr_txp({sfp1_tx_p, sfp0_tx_p}),
    .xcvr_txn({sfp1_tx_n, sfp0_tx_n}),
    .xcvr_rxp({sfp1_rx_p, sfp0_rx_p}),
    .xcvr_rxn({sfp1_rx_n, sfp0_rx_n}),

    /*
     * PHY connections
     */
    .phy_1_tx_clk(sfp0_tx_clk_int),
    .phy_1_tx_rst(sfp0_tx_rst_int),
    .phy_1_xgmii_txd(sfp0_txd_int),
    .phy_1_xgmii_txc(sfp0_txc_int),
    .phy_1_rx_clk(sfp0_rx_clk_int),
    .phy_1_rx_rst(sfp0_rx_rst_int),
    .phy_1_xgmii_rxd(sfp0_rxd_int),
    .phy_1_xgmii_rxc(sfp0_rxc_int),
    .phy_1_tx_bad_block(),
    .phy_1_rx_error_count(sfp0_rx_error_count_int),
    .phy_1_rx_bad_block(),
    .phy_1_rx_sequence_error(),
    .phy_1_rx_block_lock(sfp0_rx_block_lock),
    .phy_1_rx_high_ber(),
    .phy_1_tx_prbs31_enable(sfp0_tx_prbs31_enable_int),
    .phy_1_rx_prbs31_enable(sfp0_rx_prbs31_enable_int),

    .phy_2_tx_clk(sfp1_tx_clk_int),
    .phy_2_tx_rst(sfp1_tx_rst_int),
    .phy_2_xgmii_txd(sfp1_txd_int),
    .phy_2_xgmii_txc(sfp1_txc_int),
    .phy_2_rx_clk(sfp1_rx_clk_int),
    .phy_2_rx_rst(sfp1_rx_rst_int),
    .phy_2_xgmii_rxd(sfp1_rxd_int),
    .phy_2_xgmii_rxc(sfp1_rxc_int),
    .phy_2_tx_bad_block(),
    .phy_2_rx_error_count(sfp1_rx_error_count_int),
    .phy_2_rx_bad_block(),
    .phy_2_rx_sequence_error(),
    .phy_2_rx_block_lock(sfp1_rx_block_lock),
    .phy_2_rx_high_ber(),
    .phy_2_tx_prbs31_enable(sfp1_tx_prbs31_enable_int),
    .phy_2_rx_prbs31_enable(sfp1_rx_prbs31_enable_int)
);

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

    // PTP configuration
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .PTP_PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .PTP_OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .PTP_FNS_WIDTH(PTP_FNS_WIDTH),
    .PTP_PERIOD_NS(PTP_PERIOD_NS),
    .PTP_PERIOD_FNS(PTP_PERIOD_FNS),
    .PTP_CLOCK_PIPELINE(PTP_CLOCK_PIPELINE),
    .PTP_USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK),
    .PTP_PORT_CDC_PIPELINE(PTP_PORT_CDC_PIPELINE),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

    // Queue manager configuration (interface)
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

    // AXI interface configuration (DMA)
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),

    // DMA interface configuration
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
    .STAT_INC_WIDTH(STAT_INC_WIDTH),
    .STAT_ID_WIDTH(STAT_ID_WIDTH)
)
core_inst (
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    .clk_250mhz(zynq_user_clk),
    .rst_250mhz(zynq_user_reset),

    /*
     * GPIO
     */
    .btnu(btnu_int),
    .btnl(btnl_int),
    .btnd(btnd_int),
    .btnr(btnr_int),
    .btnc(btnc_int),
    .sw(sw_int),
    .led(led),

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
    .sfp0_tx_clk(sfp0_tx_clk_int),
    .sfp0_tx_rst(sfp0_tx_rst_int),
    .sfp0_txd(sfp0_txd_int),
    .sfp0_txc(sfp0_txc_int),
    .sfp0_tx_prbs31_enable(sfp0_tx_prbs31_enable_int),
    .sfp0_rx_clk(sfp0_rx_clk_int),
    .sfp0_rx_rst(sfp0_rx_rst_int),
    .sfp0_rxd(sfp0_rxd_int),
    .sfp0_rxc(sfp0_rxc_int),
    .sfp0_rx_prbs31_enable(sfp0_rx_prbs31_enable_int),
    .sfp0_rx_error_count(sfp0_rx_error_count_int),
    .sfp0_tx_disable_b(sfp0_tx_disable_b),

    .sfp1_tx_clk(sfp1_tx_clk_int),
    .sfp1_tx_rst(sfp1_tx_rst_int),
    .sfp1_txd(sfp1_txd_int),
    .sfp1_txc(sfp1_txc_int),
    .sfp1_tx_prbs31_enable(sfp1_tx_prbs31_enable_int),
    .sfp1_rx_clk(sfp1_rx_clk_int),
    .sfp1_rx_rst(sfp1_rx_rst_int),
    .sfp1_rxd(sfp1_rxd_int),
    .sfp1_rxc(sfp1_rxc_int),
    .sfp1_rx_prbs31_enable(sfp1_rx_prbs31_enable_int),
    .sfp1_rx_error_count(sfp1_rx_error_count_int),
    .sfp1_tx_disable_b(sfp1_tx_disable_b),

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
