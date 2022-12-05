/*

Copyright 2022, The Regents of the University of California.
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
    parameter FPGA_ID = 32'hC34120DD,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h1172_B00A,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd1563227611,
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
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 1,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = TX_QUEUE_OP_TABLE_SIZE,
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = RX_QUEUE_OP_TABLE_SIZE,
    parameter EVENT_QUEUE_INDEX_WIDTH = 5,
    parameter TX_QUEUE_INDEX_WIDTH = 10,
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

    // DMA interface configuration
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = $clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE),
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter SEG_COUNT = 2,
    parameter SEG_DATA_WIDTH = 256,
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
    parameter AXIS_ETH_SYNC_DATA_WIDTH_DOUBLE = 1,
    parameter AXIS_ETH_TX_PIPELINE = 0,
    parameter AXIS_ETH_TX_FIFO_PIPELINE = 2,
    parameter AXIS_ETH_TX_TS_PIPELINE = 0,
    parameter AXIS_ETH_RX_PIPELINE = 0,
    parameter AXIS_ETH_RX_FIFO_PIPELINE = 2,
    parameter MAC_RSFEC = 1,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_DMA_ENABLE = 1,
    parameter STAT_PCIE_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    /*
     * Clock: 100 MHz
     * Reset: Push button, active low
     */
    input  wire       clk_100_b2a,
    // input  wire       clk_50_b3a,
    // input  wire       clk_50_b3c,
    // input  wire       cpu_reset_n,

    /*
     * GPIO
     */
    input  wire [1:0]   button,
    input  wire [1:0]   sw,
    output wire [3:0]   led,
    output wire [3:0]   led_bracket,

    /*
     * PCIe: gen 4 x16
     */
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    input  wire [1:0]   pcie_refclk_p,
    input  wire         pcie_perst_n,

    /*
     * Ethernet: QSFP-DD
     */
    output wire [7:0]   qsfpdda_tx_p,
    output wire [7:0]   qsfpdda_tx_n,
    input  wire [7:0]   qsfpdda_rx_p,
    input  wire [7:0]   qsfpdda_rx_n,
    output wire [7:0]   qsfpddb_tx_p,
    output wire [7:0]   qsfpddb_tx_n,
    input  wire [7:0]   qsfpddb_rx_p,
    input  wire [7:0]   qsfpddb_rx_n,
    input  wire         qsfpdda_refclk_p,
    input  wire         qsfpddb_refclk_p,
    input  wire         qsfpddrsv_refclk_p,
    output wire         qsfpdda_initmode,
    input  wire         qsfpdda_interrupt_n,
    input  wire         qsfpdda_mod_prs_n,
    output wire         qsfpdda_mod_sel_n,
    output wire         qsfpdda_rst_n,
    inout  wire         qsfpdda_scl,
    inout  wire         qsfpdda_sda,
    output wire         qsfpddb_initmode,
    input  wire         qsfpddb_interrupt_n,
    input  wire         qsfpddb_mod_prs_n,
    output wire         qsfpddb_mod_sel_n,
    output wire         qsfpddb_rst_n,
    inout  wire         qsfpddb_scl,
    inout  wire         qsfpddb_sda
);

// PTP configuration
parameter PTP_CLK_PERIOD_NS_NUM = 2048;
parameter PTP_CLK_PERIOD_NS_DENOM = 825;
parameter PTP_TS_WIDTH = 96;
parameter PTP_TAG_WIDTH = 8;
parameter PTP_USE_SAMPLE_CLOCK = 1;

// Interface configuration
parameter TX_TAG_WIDTH = PTP_TAG_WIDTH;

// PCIe interface configuration
parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32);
parameter SEG_HDR_WIDTH = 128;
parameter SEG_PRFX_WIDTH = 32;
parameter TX_SEQ_NUM_WIDTH = 6;
parameter PCIE_TAG_COUNT = 256;

// Ethernet interface configuration
parameter AXIS_ETH_DATA_WIDTH = 64;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH*(AXIS_ETH_SYNC_DATA_WIDTH_DOUBLE ? 2 : 1);
parameter AXIS_ETH_TX_USER_WIDTH = TX_TAG_WIDTH + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire ninit_done;

wire pcie_clk;
wire pcie_rst;

reset_release reset_release_inst (
    .ninit_done (ninit_done)
);

wire clk_100mhz = clk_100_b2a;
wire rst_100mhz;

sync_reset #(
    .N(20)
)
sync_reset_100mhz_inst (
    .clk(clk_100mhz),
    .rst(pcie_rst),
    .out(rst_100mhz)
);

// GPIO
wire [1:0] button_int;
wire [1:0] sw_int;
wire qsfpdda_interrupt_n_int;
wire qsfpdda_mod_prs_n_int;
wire qsfpdda_scl_i;
wire qsfpdda_scl_o;
wire qsfpdda_scl_t;
wire qsfpdda_sda_i;
wire qsfpdda_sda_o;
wire qsfpdda_sda_t;
wire qsfpddb_interrupt_n_int;
wire qsfpddb_mod_prs_n_int;
wire qsfpddb_scl_i;
wire qsfpddb_scl_o;
wire qsfpddb_scl_t;
wire qsfpddb_sda_i;
wire qsfpddb_sda_o;
wire qsfpddb_sda_t;

reg qsfpdda_scl_o_reg;
reg qsfpdda_scl_t_reg;
reg qsfpdda_sda_o_reg;
reg qsfpdda_sda_t_reg;
reg qsfpddb_scl_o_reg;
reg qsfpddb_scl_t_reg;
reg qsfpddb_sda_o_reg;
reg qsfpddb_sda_t_reg;

always @(posedge pcie_clk) begin
    qsfpdda_scl_o_reg <= qsfpdda_scl_o;
    qsfpdda_scl_t_reg <= qsfpdda_scl_t;
    qsfpdda_sda_o_reg <= qsfpdda_sda_o;
    qsfpdda_sda_t_reg <= qsfpdda_sda_t;
    qsfpddb_scl_o_reg <= qsfpddb_scl_o;
    qsfpddb_scl_t_reg <= qsfpddb_scl_t;
    qsfpddb_sda_o_reg <= qsfpddb_sda_o;
    qsfpddb_sda_t_reg <= qsfpddb_sda_t;
end

debounce_switch #(
    .WIDTH(4),
    .N(4),
    .RATE(250000)
)
debounce_switch_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),
    .in({button, sw}),
    .out({button_int, sw_int})
);

sync_signal #(
    .WIDTH(8),
    .N(2)
)
sync_signal_inst (
    .clk(pcie_clk),
    .in({qsfpdda_interrupt_n, qsfpdda_mod_prs_n, qsfpdda_scl, qsfpdda_sda,
        qsfpddb_interrupt_n, qsfpddb_mod_prs_n, qsfpddb_scl, qsfpddb_sda}),
    .out({qsfpdda_interrupt_n_int, qsfpdda_mod_prs_n_int, qsfpdda_scl_i, qsfpdda_sda_i,
        qsfpddb_interrupt_n_int, qsfpddb_mod_prs_n_int, qsfpddb_scl_i, qsfpddb_sda_i})
);

assign qsfpdda_scl = qsfpdda_scl_t_reg ? 1'bz : qsfpdda_scl_o_reg;
assign qsfpdda_sda = qsfpdda_sda_t_reg ? 1'bz : qsfpdda_sda_o_reg;

assign qsfpddb_scl = qsfpddb_scl_t_reg ? 1'bz : qsfpddb_scl_o_reg;
assign qsfpddb_sda = qsfpddb_sda_t_reg ? 1'bz : qsfpddb_sda_o_reg;

// PCIe
wire coreclkout_hip;
wire reset_status_n;

wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   rx_st_data;
wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]  rx_st_empty;
wire [SEG_COUNT-1:0]                  rx_st_sop;
wire [SEG_COUNT-1:0]                  rx_st_eop;
wire [SEG_COUNT-1:0]                  rx_st_valid;
wire                                  rx_st_ready;
wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    rx_st_hdr;
wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   rx_st_tlp_prfx;
wire [SEG_COUNT-1:0]                  rx_st_vf_active = 0;
wire [SEG_COUNT*3-1:0]                rx_st_func_num = 0;
wire [SEG_COUNT*11-1:0]               rx_st_vf_num = 0;
wire [SEG_COUNT*3-1:0]                rx_st_bar_range;
wire [SEG_COUNT-1:0]                  rx_st_tlp_abort;

wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   tx_st_data;
wire [SEG_COUNT-1:0]                  tx_st_sop;
wire [SEG_COUNT-1:0]                  tx_st_eop;
wire [SEG_COUNT-1:0]                  tx_st_valid;
wire                                  tx_st_ready;
wire [SEG_COUNT-1:0]                  tx_st_err;
wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    tx_st_hdr;
wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   tx_st_tlp_prfx;

wire [11:0]                           rx_buffer_limit;
wire [1:0]                            rx_buffer_limit_tdm_idx;

wire [15:0]                           tx_cdts_limit;
wire [2:0]                            tx_cdts_limit_tdm_idx;

wire [15:0]                           tl_cfg_ctl;
wire [4:0]                            tl_cfg_add;
wire [2:0]                            tl_cfg_func;

assign pcie_clk = coreclkout_hip;
assign pcie_rst = !reset_status_n;

pcie pcie_hip_inst (
    .p0_rx_st_ready_i(rx_st_ready),
    .p0_rx_st_sop_o(rx_st_sop),
    .p0_rx_st_eop_o(rx_st_eop),
    .p0_rx_st_data_o(rx_st_data),
    .p0_rx_st_valid_o(rx_st_valid),
    .p0_rx_st_empty_o(rx_st_empty),
    .p0_rx_st_hdr_o(rx_st_hdr),
    .p0_rx_st_tlp_prfx_o(rx_st_tlp_prfx),
    .p0_rx_st_bar_range_o(rx_st_bar_range),
    .p0_rx_st_tlp_abort_o(rx_st_tlp_abort),
    .p0_rx_par_err_o(),
    .p0_tx_st_sop_i(tx_st_sop),
    .p0_tx_st_eop_i(tx_st_eop),
    .p0_tx_st_data_i(tx_st_data),
    .p0_tx_st_valid_i(tx_st_valid),
    .p0_tx_st_err_i(tx_st_err),
    .p0_tx_st_ready_o(tx_st_ready),
    .p0_tx_st_hdr_i(tx_st_hdr),
    .p0_tx_st_tlp_prfx_i(tx_st_tlp_prfx),
    .p0_tx_par_err_o(),
    .p0_tx_cdts_limit_o(tx_cdts_limit),
    .p0_tx_cdts_limit_tdm_idx_o(tx_cdts_limit_tdm_idx),
    .p0_tl_cfg_func_o(tl_cfg_func),
    .p0_tl_cfg_add_o(tl_cfg_add),
    .p0_tl_cfg_ctl_o(tl_cfg_ctl),
    .p0_dl_timer_update_o(),
    .p0_reset_status_n(reset_status_n),
    .p0_pin_perst_n(),
    .p0_link_up_o(),
    .p0_dl_up_o(),
    .p0_surprise_down_err_o(),
    .p0_ltssm_state_o(),
    .rx_n_in0(pcie_rx_n[0]),
    .rx_n_in1(pcie_rx_n[1]),
    .rx_n_in2(pcie_rx_n[2]),
    .rx_n_in3(pcie_rx_n[3]),
    .rx_n_in4(pcie_rx_n[4]),
    .rx_n_in5(pcie_rx_n[5]),
    .rx_n_in6(pcie_rx_n[6]),
    .rx_n_in7(pcie_rx_n[7]),
    .rx_n_in8(pcie_rx_n[8]),
    .rx_n_in9(pcie_rx_n[9]),
    .rx_n_in10(pcie_rx_n[10]),
    .rx_n_in11(pcie_rx_n[11]),
    .rx_n_in12(pcie_rx_n[12]),
    .rx_n_in13(pcie_rx_n[13]),
    .rx_n_in14(pcie_rx_n[14]),
    .rx_n_in15(pcie_rx_n[15]),
    .rx_p_in0(pcie_rx_p[0]),
    .rx_p_in1(pcie_rx_p[1]),
    .rx_p_in2(pcie_rx_p[2]),
    .rx_p_in3(pcie_rx_p[3]),
    .rx_p_in4(pcie_rx_p[4]),
    .rx_p_in5(pcie_rx_p[5]),
    .rx_p_in6(pcie_rx_p[6]),
    .rx_p_in7(pcie_rx_p[7]),
    .rx_p_in8(pcie_rx_p[8]),
    .rx_p_in9(pcie_rx_p[9]),
    .rx_p_in10(pcie_rx_p[10]),
    .rx_p_in11(pcie_rx_p[11]),
    .rx_p_in12(pcie_rx_p[12]),
    .rx_p_in13(pcie_rx_p[13]),
    .rx_p_in14(pcie_rx_p[14]),
    .rx_p_in15(pcie_rx_p[15]),
    .tx_n_out0(pcie_tx_n[0]),
    .tx_n_out1(pcie_tx_n[1]),
    .tx_n_out2(pcie_tx_n[2]),
    .tx_n_out3(pcie_tx_n[3]),
    .tx_n_out4(pcie_tx_n[4]),
    .tx_n_out5(pcie_tx_n[5]),
    .tx_n_out6(pcie_tx_n[6]),
    .tx_n_out7(pcie_tx_n[7]),
    .tx_n_out8(pcie_tx_n[8]),
    .tx_n_out9(pcie_tx_n[9]),
    .tx_n_out10(pcie_tx_n[10]),
    .tx_n_out11(pcie_tx_n[11]),
    .tx_n_out12(pcie_tx_n[12]),
    .tx_n_out13(pcie_tx_n[13]),
    .tx_n_out14(pcie_tx_n[14]),
    .tx_n_out15(pcie_tx_n[15]),
    .tx_p_out0(pcie_tx_p[0]),
    .tx_p_out1(pcie_tx_p[1]),
    .tx_p_out2(pcie_tx_p[2]),
    .tx_p_out3(pcie_tx_p[3]),
    .tx_p_out4(pcie_tx_p[4]),
    .tx_p_out5(pcie_tx_p[5]),
    .tx_p_out6(pcie_tx_p[6]),
    .tx_p_out7(pcie_tx_p[7]),
    .tx_p_out8(pcie_tx_p[8]),
    .tx_p_out9(pcie_tx_p[9]),
    .tx_p_out10(pcie_tx_p[10]),
    .tx_p_out11(pcie_tx_p[11]),
    .tx_p_out12(pcie_tx_p[12]),
    .tx_p_out13(pcie_tx_p[13]),
    .tx_p_out14(pcie_tx_p[14]),
    .tx_p_out15(pcie_tx_p[15]),
    .coreclkout_hip(coreclkout_hip),
    .refclk0(pcie_refclk_p[0]),
    .refclk1(pcie_refclk_p[1]),
    .pin_perst_n(pcie_perst_n),
    .ninit_done(ninit_done)
);

// QSFP28 interfaces

wire etile_iopll_locked;
wire etile_ptp_sample_clk;

iopll_etile_ptp iopll_etile_ptp_inst (
    .rst      (rst_100mhz),
    .refclk   (clk_100mhz),
    .locked   (etile_iopll_locked),
    .outclk_0 (etile_ptp_sample_clk)
);

// QSFP-DD A
wire                               qsfpdda_mac_1_tx_clk_int;
wire                               qsfpdda_mac_1_tx_rst_int;

wire                               qsfpdda_mac_1_tx_ptp_clk_int;
wire                               qsfpdda_mac_1_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_1_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_1_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_1_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_1_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_1_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_1_tx_axis_tkeep_int;
wire                               qsfpdda_mac_1_tx_axis_tvalid_int;
wire                               qsfpdda_mac_1_tx_axis_tready_int;
wire                               qsfpdda_mac_1_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_1_tx_axis_tuser_int;

wire                               qsfpdda_mac_1_rx_clk_int;
wire                               qsfpdda_mac_1_rx_rst_int;

wire                               qsfpdda_mac_1_rx_ptp_clk_int;
wire                               qsfpdda_mac_1_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_1_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_1_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_1_rx_axis_tkeep_int;
wire                               qsfpdda_mac_1_rx_axis_tvalid_int;
wire                               qsfpdda_mac_1_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_1_rx_axis_tuser_int;

wire                               qsfpdda_mac_1_rx_status_int;

wire                               qsfpdda_mac_2_tx_clk_int;
wire                               qsfpdda_mac_2_tx_rst_int;

wire                               qsfpdda_mac_2_tx_ptp_clk_int;
wire                               qsfpdda_mac_2_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_2_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_2_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_2_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_2_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_2_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_2_tx_axis_tkeep_int;
wire                               qsfpdda_mac_2_tx_axis_tvalid_int;
wire                               qsfpdda_mac_2_tx_axis_tready_int;
wire                               qsfpdda_mac_2_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_2_tx_axis_tuser_int;

wire                               qsfpdda_mac_2_rx_clk_int;
wire                               qsfpdda_mac_2_rx_rst_int;

wire                               qsfpdda_mac_2_rx_ptp_clk_int;
wire                               qsfpdda_mac_2_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_2_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_2_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_2_rx_axis_tkeep_int;
wire                               qsfpdda_mac_2_rx_axis_tvalid_int;
wire                               qsfpdda_mac_2_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_2_rx_axis_tuser_int;

wire                               qsfpdda_mac_2_rx_status_int;

wire                               qsfpdda_mac_3_tx_clk_int;
wire                               qsfpdda_mac_3_tx_rst_int;

wire                               qsfpdda_mac_3_tx_ptp_clk_int;
wire                               qsfpdda_mac_3_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_3_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_3_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_3_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_3_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_3_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_3_tx_axis_tkeep_int;
wire                               qsfpdda_mac_3_tx_axis_tvalid_int;
wire                               qsfpdda_mac_3_tx_axis_tready_int;
wire                               qsfpdda_mac_3_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_3_tx_axis_tuser_int;

wire                               qsfpdda_mac_3_rx_clk_int;
wire                               qsfpdda_mac_3_rx_rst_int;

wire                               qsfpdda_mac_3_rx_ptp_clk_int;
wire                               qsfpdda_mac_3_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_3_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_3_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_3_rx_axis_tkeep_int;
wire                               qsfpdda_mac_3_rx_axis_tvalid_int;
wire                               qsfpdda_mac_3_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_3_rx_axis_tuser_int;

wire                               qsfpdda_mac_3_rx_status_int;

wire                               qsfpdda_mac_4_tx_clk_int;
wire                               qsfpdda_mac_4_tx_rst_int;

wire                               qsfpdda_mac_4_tx_ptp_clk_int;
wire                               qsfpdda_mac_4_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_4_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_4_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_4_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_4_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_4_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_4_tx_axis_tkeep_int;
wire                               qsfpdda_mac_4_tx_axis_tvalid_int;
wire                               qsfpdda_mac_4_tx_axis_tready_int;
wire                               qsfpdda_mac_4_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_4_tx_axis_tuser_int;

wire                               qsfpdda_mac_4_rx_clk_int;
wire                               qsfpdda_mac_4_rx_rst_int;

wire                               qsfpdda_mac_4_rx_ptp_clk_int;
wire                               qsfpdda_mac_4_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_4_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_4_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_4_rx_axis_tkeep_int;
wire                               qsfpdda_mac_4_rx_axis_tvalid_int;
wire                               qsfpdda_mac_4_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_4_rx_axis_tuser_int;

wire                               qsfpdda_mac_4_rx_status_int;

wire                               qsfpdda_mac_5_tx_clk_int;
wire                               qsfpdda_mac_5_tx_rst_int;

wire                               qsfpdda_mac_5_tx_ptp_clk_int;
wire                               qsfpdda_mac_5_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_5_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_5_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_5_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_5_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_5_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_5_tx_axis_tkeep_int;
wire                               qsfpdda_mac_5_tx_axis_tvalid_int;
wire                               qsfpdda_mac_5_tx_axis_tready_int;
wire                               qsfpdda_mac_5_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_5_tx_axis_tuser_int;

wire                               qsfpdda_mac_5_rx_clk_int;
wire                               qsfpdda_mac_5_rx_rst_int;

wire                               qsfpdda_mac_5_rx_ptp_clk_int;
wire                               qsfpdda_mac_5_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_5_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_5_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_5_rx_axis_tkeep_int;
wire                               qsfpdda_mac_5_rx_axis_tvalid_int;
wire                               qsfpdda_mac_5_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_5_rx_axis_tuser_int;

wire                               qsfpdda_mac_5_rx_status_int;

wire                               qsfpdda_mac_6_tx_clk_int;
wire                               qsfpdda_mac_6_tx_rst_int;

wire                               qsfpdda_mac_6_tx_ptp_clk_int;
wire                               qsfpdda_mac_6_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_6_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_6_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_6_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_6_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_6_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_6_tx_axis_tkeep_int;
wire                               qsfpdda_mac_6_tx_axis_tvalid_int;
wire                               qsfpdda_mac_6_tx_axis_tready_int;
wire                               qsfpdda_mac_6_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_6_tx_axis_tuser_int;

wire                               qsfpdda_mac_6_rx_clk_int;
wire                               qsfpdda_mac_6_rx_rst_int;

wire                               qsfpdda_mac_6_rx_ptp_clk_int;
wire                               qsfpdda_mac_6_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_6_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_6_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_6_rx_axis_tkeep_int;
wire                               qsfpdda_mac_6_rx_axis_tvalid_int;
wire                               qsfpdda_mac_6_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_6_rx_axis_tuser_int;

wire                               qsfpdda_mac_6_rx_status_int;

wire                               qsfpdda_mac_7_tx_clk_int;
wire                               qsfpdda_mac_7_tx_rst_int;

wire                               qsfpdda_mac_7_tx_ptp_clk_int;
wire                               qsfpdda_mac_7_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_7_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_7_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_7_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_7_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_7_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_7_tx_axis_tkeep_int;
wire                               qsfpdda_mac_7_tx_axis_tvalid_int;
wire                               qsfpdda_mac_7_tx_axis_tready_int;
wire                               qsfpdda_mac_7_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_7_tx_axis_tuser_int;

wire                               qsfpdda_mac_7_rx_clk_int;
wire                               qsfpdda_mac_7_rx_rst_int;

wire                               qsfpdda_mac_7_rx_ptp_clk_int;
wire                               qsfpdda_mac_7_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_7_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_7_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_7_rx_axis_tkeep_int;
wire                               qsfpdda_mac_7_rx_axis_tvalid_int;
wire                               qsfpdda_mac_7_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_7_rx_axis_tuser_int;

wire                               qsfpdda_mac_7_rx_status_int;

wire                               qsfpdda_mac_8_tx_clk_int;
wire                               qsfpdda_mac_8_tx_rst_int;

wire                               qsfpdda_mac_8_tx_ptp_clk_int;
wire                               qsfpdda_mac_8_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_8_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_8_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpdda_mac_8_tx_ptp_ts_tag_int;
wire                               qsfpdda_mac_8_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_8_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_8_tx_axis_tkeep_int;
wire                               qsfpdda_mac_8_tx_axis_tvalid_int;
wire                               qsfpdda_mac_8_tx_axis_tready_int;
wire                               qsfpdda_mac_8_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpdda_mac_8_tx_axis_tuser_int;

wire                               qsfpdda_mac_8_rx_clk_int;
wire                               qsfpdda_mac_8_rx_rst_int;

wire                               qsfpdda_mac_8_rx_ptp_clk_int;
wire                               qsfpdda_mac_8_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpdda_mac_8_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpdda_mac_8_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpdda_mac_8_rx_axis_tkeep_int;
wire                               qsfpdda_mac_8_rx_axis_tvalid_int;
wire                               qsfpdda_mac_8_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpdda_mac_8_rx_axis_tuser_int;

wire                               qsfpdda_mac_8_rx_status_int;

eth_mac_dual_quad_wrapper #(
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH),
    .MAC_RSFEC(MAC_RSFEC)
)
qsfpdda_mac_inst (
    .ctrl_clk(clk_100mhz),
    .ctrl_rst(rst_100mhz),

    .tx_serial_data_p({qsfpdda_tx_p[7], qsfpdda_tx_p[5], qsfpdda_tx_p[6], qsfpdda_tx_p[4], qsfpdda_tx_p[3], qsfpdda_tx_p[1], qsfpdda_tx_p[2], qsfpdda_tx_p[0]}),
    .tx_serial_data_n({qsfpdda_tx_n[7], qsfpdda_tx_n[5], qsfpdda_tx_n[6], qsfpdda_tx_n[4], qsfpdda_tx_n[3], qsfpdda_tx_n[1], qsfpdda_tx_n[2], qsfpdda_tx_n[0]}),
    .rx_serial_data_p({qsfpdda_rx_p[7], qsfpdda_rx_p[5], qsfpdda_rx_p[6], qsfpdda_rx_p[4], qsfpdda_rx_p[3], qsfpdda_rx_p[1], qsfpdda_rx_p[2], qsfpdda_rx_p[0]}),
    .rx_serial_data_n({qsfpdda_rx_n[7], qsfpdda_rx_n[5], qsfpdda_rx_n[6], qsfpdda_rx_n[4], qsfpdda_rx_n[3], qsfpdda_rx_n[1], qsfpdda_rx_n[2], qsfpdda_rx_n[0]}),
    .ref_clk(qsfpddb_refclk_p),
    .ptp_sample_clk(etile_ptp_sample_clk),

    .mac_1_tx_clk(qsfpdda_mac_1_tx_clk_int),
    .mac_1_tx_rst(qsfpdda_mac_1_tx_rst_int),

    .mac_1_tx_ptp_clk(qsfpdda_mac_1_tx_ptp_clk_int),
    .mac_1_tx_ptp_rst(qsfpdda_mac_1_tx_ptp_rst_int),
    .mac_1_tx_ptp_time(qsfpdda_mac_1_tx_ptp_time_int),

    .mac_1_tx_ptp_ts(qsfpdda_mac_1_tx_ptp_ts_int),
    .mac_1_tx_ptp_ts_tag(qsfpdda_mac_1_tx_ptp_ts_tag_int),
    .mac_1_tx_ptp_ts_valid(qsfpdda_mac_1_tx_ptp_ts_valid_int),

    .mac_1_tx_axis_tdata(qsfpdda_mac_1_tx_axis_tdata_int),
    .mac_1_tx_axis_tkeep(qsfpdda_mac_1_tx_axis_tkeep_int),
    .mac_1_tx_axis_tvalid(qsfpdda_mac_1_tx_axis_tvalid_int),
    .mac_1_tx_axis_tready(qsfpdda_mac_1_tx_axis_tready_int),
    .mac_1_tx_axis_tlast(qsfpdda_mac_1_tx_axis_tlast_int),
    .mac_1_tx_axis_tuser(qsfpdda_mac_1_tx_axis_tuser_int),

    .mac_1_rx_clk(qsfpdda_mac_1_rx_clk_int),
    .mac_1_rx_rst(qsfpdda_mac_1_rx_rst_int),

    .mac_1_rx_ptp_clk(qsfpdda_mac_1_rx_ptp_clk_int),
    .mac_1_rx_ptp_rst(qsfpdda_mac_1_rx_ptp_rst_int),
    .mac_1_rx_ptp_time(qsfpdda_mac_1_rx_ptp_time_int),

    .mac_1_rx_axis_tdata(qsfpdda_mac_1_rx_axis_tdata_int),
    .mac_1_rx_axis_tkeep(qsfpdda_mac_1_rx_axis_tkeep_int),
    .mac_1_rx_axis_tvalid(qsfpdda_mac_1_rx_axis_tvalid_int),
    .mac_1_rx_axis_tlast(qsfpdda_mac_1_rx_axis_tlast_int),
    .mac_1_rx_axis_tuser(qsfpdda_mac_1_rx_axis_tuser_int),

    .mac_1_rx_status(qsfpdda_mac_1_rx_status_int),

    .mac_2_tx_clk(qsfpdda_mac_3_tx_clk_int),
    .mac_2_tx_rst(qsfpdda_mac_3_tx_rst_int),

    .mac_2_tx_ptp_clk(qsfpdda_mac_3_tx_ptp_clk_int),
    .mac_2_tx_ptp_rst(qsfpdda_mac_3_tx_ptp_rst_int),
    .mac_2_tx_ptp_time(qsfpdda_mac_3_tx_ptp_time_int),

    .mac_2_tx_ptp_ts(qsfpdda_mac_3_tx_ptp_ts_int),
    .mac_2_tx_ptp_ts_tag(qsfpdda_mac_3_tx_ptp_ts_tag_int),
    .mac_2_tx_ptp_ts_valid(qsfpdda_mac_3_tx_ptp_ts_valid_int),

    .mac_2_tx_axis_tdata(qsfpdda_mac_3_tx_axis_tdata_int),
    .mac_2_tx_axis_tkeep(qsfpdda_mac_3_tx_axis_tkeep_int),
    .mac_2_tx_axis_tvalid(qsfpdda_mac_3_tx_axis_tvalid_int),
    .mac_2_tx_axis_tready(qsfpdda_mac_3_tx_axis_tready_int),
    .mac_2_tx_axis_tlast(qsfpdda_mac_3_tx_axis_tlast_int),
    .mac_2_tx_axis_tuser(qsfpdda_mac_3_tx_axis_tuser_int),

    .mac_2_rx_clk(qsfpdda_mac_3_rx_clk_int),
    .mac_2_rx_rst(qsfpdda_mac_3_rx_rst_int),

    .mac_2_rx_ptp_clk(qsfpdda_mac_3_rx_ptp_clk_int),
    .mac_2_rx_ptp_rst(qsfpdda_mac_3_rx_ptp_rst_int),
    .mac_2_rx_ptp_time(qsfpdda_mac_3_rx_ptp_time_int),

    .mac_2_rx_axis_tdata(qsfpdda_mac_3_rx_axis_tdata_int),
    .mac_2_rx_axis_tkeep(qsfpdda_mac_3_rx_axis_tkeep_int),
    .mac_2_rx_axis_tvalid(qsfpdda_mac_3_rx_axis_tvalid_int),
    .mac_2_rx_axis_tlast(qsfpdda_mac_3_rx_axis_tlast_int),
    .mac_2_rx_axis_tuser(qsfpdda_mac_3_rx_axis_tuser_int),

    .mac_2_rx_status(qsfpdda_mac_3_rx_status_int),

    .mac_3_tx_clk(qsfpdda_mac_2_tx_clk_int),
    .mac_3_tx_rst(qsfpdda_mac_2_tx_rst_int),

    .mac_3_tx_ptp_clk(qsfpdda_mac_2_tx_ptp_clk_int),
    .mac_3_tx_ptp_rst(qsfpdda_mac_2_tx_ptp_rst_int),
    .mac_3_tx_ptp_time(qsfpdda_mac_2_tx_ptp_time_int),

    .mac_3_tx_ptp_ts(qsfpdda_mac_2_tx_ptp_ts_int),
    .mac_3_tx_ptp_ts_tag(qsfpdda_mac_2_tx_ptp_ts_tag_int),
    .mac_3_tx_ptp_ts_valid(qsfpdda_mac_2_tx_ptp_ts_valid_int),

    .mac_3_tx_axis_tdata(qsfpdda_mac_2_tx_axis_tdata_int),
    .mac_3_tx_axis_tkeep(qsfpdda_mac_2_tx_axis_tkeep_int),
    .mac_3_tx_axis_tvalid(qsfpdda_mac_2_tx_axis_tvalid_int),
    .mac_3_tx_axis_tready(qsfpdda_mac_2_tx_axis_tready_int),
    .mac_3_tx_axis_tlast(qsfpdda_mac_2_tx_axis_tlast_int),
    .mac_3_tx_axis_tuser(qsfpdda_mac_2_tx_axis_tuser_int),

    .mac_3_rx_clk(qsfpdda_mac_2_rx_clk_int),
    .mac_3_rx_rst(qsfpdda_mac_2_rx_rst_int),

    .mac_3_rx_ptp_clk(qsfpdda_mac_2_rx_ptp_clk_int),
    .mac_3_rx_ptp_rst(qsfpdda_mac_2_rx_ptp_rst_int),
    .mac_3_rx_ptp_time(qsfpdda_mac_2_rx_ptp_time_int),

    .mac_3_rx_axis_tdata(qsfpdda_mac_2_rx_axis_tdata_int),
    .mac_3_rx_axis_tkeep(qsfpdda_mac_2_rx_axis_tkeep_int),
    .mac_3_rx_axis_tvalid(qsfpdda_mac_2_rx_axis_tvalid_int),
    .mac_3_rx_axis_tlast(qsfpdda_mac_2_rx_axis_tlast_int),
    .mac_3_rx_axis_tuser(qsfpdda_mac_2_rx_axis_tuser_int),

    .mac_3_rx_status(qsfpdda_mac_2_rx_status_int),

    .mac_4_tx_clk(qsfpdda_mac_4_tx_clk_int),
    .mac_4_tx_rst(qsfpdda_mac_4_tx_rst_int),

    .mac_4_tx_ptp_clk(qsfpdda_mac_4_tx_ptp_clk_int),
    .mac_4_tx_ptp_rst(qsfpdda_mac_4_tx_ptp_rst_int),
    .mac_4_tx_ptp_time(qsfpdda_mac_4_tx_ptp_time_int),

    .mac_4_tx_ptp_ts(qsfpdda_mac_4_tx_ptp_ts_int),
    .mac_4_tx_ptp_ts_tag(qsfpdda_mac_4_tx_ptp_ts_tag_int),
    .mac_4_tx_ptp_ts_valid(qsfpdda_mac_4_tx_ptp_ts_valid_int),

    .mac_4_tx_axis_tdata(qsfpdda_mac_4_tx_axis_tdata_int),
    .mac_4_tx_axis_tkeep(qsfpdda_mac_4_tx_axis_tkeep_int),
    .mac_4_tx_axis_tvalid(qsfpdda_mac_4_tx_axis_tvalid_int),
    .mac_4_tx_axis_tready(qsfpdda_mac_4_tx_axis_tready_int),
    .mac_4_tx_axis_tlast(qsfpdda_mac_4_tx_axis_tlast_int),
    .mac_4_tx_axis_tuser(qsfpdda_mac_4_tx_axis_tuser_int),

    .mac_4_rx_clk(qsfpdda_mac_4_rx_clk_int),
    .mac_4_rx_rst(qsfpdda_mac_4_rx_rst_int),

    .mac_4_rx_ptp_clk(qsfpdda_mac_4_rx_ptp_clk_int),
    .mac_4_rx_ptp_rst(qsfpdda_mac_4_rx_ptp_rst_int),
    .mac_4_rx_ptp_time(qsfpdda_mac_4_rx_ptp_time_int),

    .mac_4_rx_axis_tdata(qsfpdda_mac_4_rx_axis_tdata_int),
    .mac_4_rx_axis_tkeep(qsfpdda_mac_4_rx_axis_tkeep_int),
    .mac_4_rx_axis_tvalid(qsfpdda_mac_4_rx_axis_tvalid_int),
    .mac_4_rx_axis_tlast(qsfpdda_mac_4_rx_axis_tlast_int),
    .mac_4_rx_axis_tuser(qsfpdda_mac_4_rx_axis_tuser_int),

    .mac_4_rx_status(qsfpdda_mac_4_rx_status_int),

    .mac_5_tx_clk(qsfpdda_mac_5_tx_clk_int),
    .mac_5_tx_rst(qsfpdda_mac_5_tx_rst_int),

    .mac_5_tx_ptp_clk(qsfpdda_mac_5_tx_ptp_clk_int),
    .mac_5_tx_ptp_rst(qsfpdda_mac_5_tx_ptp_rst_int),
    .mac_5_tx_ptp_time(qsfpdda_mac_5_tx_ptp_time_int),

    .mac_5_tx_ptp_ts(qsfpdda_mac_5_tx_ptp_ts_int),
    .mac_5_tx_ptp_ts_tag(qsfpdda_mac_5_tx_ptp_ts_tag_int),
    .mac_5_tx_ptp_ts_valid(qsfpdda_mac_5_tx_ptp_ts_valid_int),

    .mac_5_tx_axis_tdata(qsfpdda_mac_5_tx_axis_tdata_int),
    .mac_5_tx_axis_tkeep(qsfpdda_mac_5_tx_axis_tkeep_int),
    .mac_5_tx_axis_tvalid(qsfpdda_mac_5_tx_axis_tvalid_int),
    .mac_5_tx_axis_tready(qsfpdda_mac_5_tx_axis_tready_int),
    .mac_5_tx_axis_tlast(qsfpdda_mac_5_tx_axis_tlast_int),
    .mac_5_tx_axis_tuser(qsfpdda_mac_5_tx_axis_tuser_int),

    .mac_5_rx_clk(qsfpdda_mac_5_rx_clk_int),
    .mac_5_rx_rst(qsfpdda_mac_5_rx_rst_int),

    .mac_5_rx_ptp_clk(qsfpdda_mac_5_rx_ptp_clk_int),
    .mac_5_rx_ptp_rst(qsfpdda_mac_5_rx_ptp_rst_int),
    .mac_5_rx_ptp_time(qsfpdda_mac_5_rx_ptp_time_int),

    .mac_5_rx_axis_tdata(qsfpdda_mac_5_rx_axis_tdata_int),
    .mac_5_rx_axis_tkeep(qsfpdda_mac_5_rx_axis_tkeep_int),
    .mac_5_rx_axis_tvalid(qsfpdda_mac_5_rx_axis_tvalid_int),
    .mac_5_rx_axis_tlast(qsfpdda_mac_5_rx_axis_tlast_int),
    .mac_5_rx_axis_tuser(qsfpdda_mac_5_rx_axis_tuser_int),

    .mac_5_rx_status(qsfpdda_mac_5_rx_status_int),

    .mac_6_tx_clk(qsfpdda_mac_7_tx_clk_int),
    .mac_6_tx_rst(qsfpdda_mac_7_tx_rst_int),

    .mac_6_tx_ptp_clk(qsfpdda_mac_7_tx_ptp_clk_int),
    .mac_6_tx_ptp_rst(qsfpdda_mac_7_tx_ptp_rst_int),
    .mac_6_tx_ptp_time(qsfpdda_mac_7_tx_ptp_time_int),

    .mac_6_tx_ptp_ts(qsfpdda_mac_7_tx_ptp_ts_int),
    .mac_6_tx_ptp_ts_tag(qsfpdda_mac_7_tx_ptp_ts_tag_int),
    .mac_6_tx_ptp_ts_valid(qsfpdda_mac_7_tx_ptp_ts_valid_int),

    .mac_6_tx_axis_tdata(qsfpdda_mac_7_tx_axis_tdata_int),
    .mac_6_tx_axis_tkeep(qsfpdda_mac_7_tx_axis_tkeep_int),
    .mac_6_tx_axis_tvalid(qsfpdda_mac_7_tx_axis_tvalid_int),
    .mac_6_tx_axis_tready(qsfpdda_mac_7_tx_axis_tready_int),
    .mac_6_tx_axis_tlast(qsfpdda_mac_7_tx_axis_tlast_int),
    .mac_6_tx_axis_tuser(qsfpdda_mac_7_tx_axis_tuser_int),

    .mac_6_rx_clk(qsfpdda_mac_7_rx_clk_int),
    .mac_6_rx_rst(qsfpdda_mac_7_rx_rst_int),

    .mac_6_rx_ptp_clk(qsfpdda_mac_7_rx_ptp_clk_int),
    .mac_6_rx_ptp_rst(qsfpdda_mac_7_rx_ptp_rst_int),
    .mac_6_rx_ptp_time(qsfpdda_mac_7_rx_ptp_time_int),

    .mac_6_rx_axis_tdata(qsfpdda_mac_7_rx_axis_tdata_int),
    .mac_6_rx_axis_tkeep(qsfpdda_mac_7_rx_axis_tkeep_int),
    .mac_6_rx_axis_tvalid(qsfpdda_mac_7_rx_axis_tvalid_int),
    .mac_6_rx_axis_tlast(qsfpdda_mac_7_rx_axis_tlast_int),
    .mac_6_rx_axis_tuser(qsfpdda_mac_7_rx_axis_tuser_int),

    .mac_6_rx_status(qsfpdda_mac_7_rx_status_int),

    .mac_7_tx_clk(qsfpdda_mac_6_tx_clk_int),
    .mac_7_tx_rst(qsfpdda_mac_6_tx_rst_int),

    .mac_7_tx_ptp_clk(qsfpdda_mac_6_tx_ptp_clk_int),
    .mac_7_tx_ptp_rst(qsfpdda_mac_6_tx_ptp_rst_int),
    .mac_7_tx_ptp_time(qsfpdda_mac_6_tx_ptp_time_int),

    .mac_7_tx_ptp_ts(qsfpdda_mac_6_tx_ptp_ts_int),
    .mac_7_tx_ptp_ts_tag(qsfpdda_mac_6_tx_ptp_ts_tag_int),
    .mac_7_tx_ptp_ts_valid(qsfpdda_mac_6_tx_ptp_ts_valid_int),

    .mac_7_tx_axis_tdata(qsfpdda_mac_6_tx_axis_tdata_int),
    .mac_7_tx_axis_tkeep(qsfpdda_mac_6_tx_axis_tkeep_int),
    .mac_7_tx_axis_tvalid(qsfpdda_mac_6_tx_axis_tvalid_int),
    .mac_7_tx_axis_tready(qsfpdda_mac_6_tx_axis_tready_int),
    .mac_7_tx_axis_tlast(qsfpdda_mac_6_tx_axis_tlast_int),
    .mac_7_tx_axis_tuser(qsfpdda_mac_6_tx_axis_tuser_int),

    .mac_7_rx_clk(qsfpdda_mac_6_rx_clk_int),
    .mac_7_rx_rst(qsfpdda_mac_6_rx_rst_int),

    .mac_7_rx_ptp_clk(qsfpdda_mac_6_rx_ptp_clk_int),
    .mac_7_rx_ptp_rst(qsfpdda_mac_6_rx_ptp_rst_int),
    .mac_7_rx_ptp_time(qsfpdda_mac_6_rx_ptp_time_int),

    .mac_7_rx_axis_tdata(qsfpdda_mac_6_rx_axis_tdata_int),
    .mac_7_rx_axis_tkeep(qsfpdda_mac_6_rx_axis_tkeep_int),
    .mac_7_rx_axis_tvalid(qsfpdda_mac_6_rx_axis_tvalid_int),
    .mac_7_rx_axis_tlast(qsfpdda_mac_6_rx_axis_tlast_int),
    .mac_7_rx_axis_tuser(qsfpdda_mac_6_rx_axis_tuser_int),

    .mac_7_rx_status(qsfpdda_mac_6_rx_status_int),

    .mac_8_tx_clk(qsfpdda_mac_8_tx_clk_int),
    .mac_8_tx_rst(qsfpdda_mac_8_tx_rst_int),

    .mac_8_tx_ptp_clk(qsfpdda_mac_8_tx_ptp_clk_int),
    .mac_8_tx_ptp_rst(qsfpdda_mac_8_tx_ptp_rst_int),
    .mac_8_tx_ptp_time(qsfpdda_mac_8_tx_ptp_time_int),

    .mac_8_tx_ptp_ts(qsfpdda_mac_8_tx_ptp_ts_int),
    .mac_8_tx_ptp_ts_tag(qsfpdda_mac_8_tx_ptp_ts_tag_int),
    .mac_8_tx_ptp_ts_valid(qsfpdda_mac_8_tx_ptp_ts_valid_int),

    .mac_8_tx_axis_tdata(qsfpdda_mac_8_tx_axis_tdata_int),
    .mac_8_tx_axis_tkeep(qsfpdda_mac_8_tx_axis_tkeep_int),
    .mac_8_tx_axis_tvalid(qsfpdda_mac_8_tx_axis_tvalid_int),
    .mac_8_tx_axis_tready(qsfpdda_mac_8_tx_axis_tready_int),
    .mac_8_tx_axis_tlast(qsfpdda_mac_8_tx_axis_tlast_int),
    .mac_8_tx_axis_tuser(qsfpdda_mac_8_tx_axis_tuser_int),

    .mac_8_rx_clk(qsfpdda_mac_8_rx_clk_int),
    .mac_8_rx_rst(qsfpdda_mac_8_rx_rst_int),

    .mac_8_rx_ptp_clk(qsfpdda_mac_8_rx_ptp_clk_int),
    .mac_8_rx_ptp_rst(qsfpdda_mac_8_rx_ptp_rst_int),
    .mac_8_rx_ptp_time(qsfpdda_mac_8_rx_ptp_time_int),

    .mac_8_rx_axis_tdata(qsfpdda_mac_8_rx_axis_tdata_int),
    .mac_8_rx_axis_tkeep(qsfpdda_mac_8_rx_axis_tkeep_int),
    .mac_8_rx_axis_tvalid(qsfpdda_mac_8_rx_axis_tvalid_int),
    .mac_8_rx_axis_tlast(qsfpdda_mac_8_rx_axis_tlast_int),
    .mac_8_rx_axis_tuser(qsfpdda_mac_8_rx_axis_tuser_int),

    .mac_8_rx_status(qsfpdda_mac_8_rx_status_int)
);

// QSFP-DD B
wire                               qsfpddb_mac_1_tx_clk_int;
wire                               qsfpddb_mac_1_tx_rst_int;

wire                               qsfpddb_mac_1_tx_ptp_clk_int;
wire                               qsfpddb_mac_1_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_1_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_1_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_1_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_1_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_1_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_1_tx_axis_tkeep_int;
wire                               qsfpddb_mac_1_tx_axis_tvalid_int;
wire                               qsfpddb_mac_1_tx_axis_tready_int;
wire                               qsfpddb_mac_1_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_1_tx_axis_tuser_int;

wire                               qsfpddb_mac_1_rx_clk_int;
wire                               qsfpddb_mac_1_rx_rst_int;

wire                               qsfpddb_mac_1_rx_ptp_clk_int;
wire                               qsfpddb_mac_1_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_1_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_1_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_1_rx_axis_tkeep_int;
wire                               qsfpddb_mac_1_rx_axis_tvalid_int;
wire                               qsfpddb_mac_1_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_1_rx_axis_tuser_int;

wire                               qsfpddb_mac_1_rx_status_int;

wire                               qsfpddb_mac_2_tx_clk_int;
wire                               qsfpddb_mac_2_tx_rst_int;

wire                               qsfpddb_mac_2_tx_ptp_clk_int;
wire                               qsfpddb_mac_2_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_2_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_2_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_2_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_2_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_2_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_2_tx_axis_tkeep_int;
wire                               qsfpddb_mac_2_tx_axis_tvalid_int;
wire                               qsfpddb_mac_2_tx_axis_tready_int;
wire                               qsfpddb_mac_2_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_2_tx_axis_tuser_int;

wire                               qsfpddb_mac_2_rx_clk_int;
wire                               qsfpddb_mac_2_rx_rst_int;

wire                               qsfpddb_mac_2_rx_ptp_clk_int;
wire                               qsfpddb_mac_2_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_2_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_2_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_2_rx_axis_tkeep_int;
wire                               qsfpddb_mac_2_rx_axis_tvalid_int;
wire                               qsfpddb_mac_2_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_2_rx_axis_tuser_int;

wire                               qsfpddb_mac_2_rx_status_int;

wire                               qsfpddb_mac_3_tx_clk_int;
wire                               qsfpddb_mac_3_tx_rst_int;

wire                               qsfpddb_mac_3_tx_ptp_clk_int;
wire                               qsfpddb_mac_3_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_3_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_3_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_3_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_3_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_3_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_3_tx_axis_tkeep_int;
wire                               qsfpddb_mac_3_tx_axis_tvalid_int;
wire                               qsfpddb_mac_3_tx_axis_tready_int;
wire                               qsfpddb_mac_3_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_3_tx_axis_tuser_int;

wire                               qsfpddb_mac_3_rx_clk_int;
wire                               qsfpddb_mac_3_rx_rst_int;

wire                               qsfpddb_mac_3_rx_ptp_clk_int;
wire                               qsfpddb_mac_3_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_3_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_3_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_3_rx_axis_tkeep_int;
wire                               qsfpddb_mac_3_rx_axis_tvalid_int;
wire                               qsfpddb_mac_3_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_3_rx_axis_tuser_int;

wire                               qsfpddb_mac_3_rx_status_int;

wire                               qsfpddb_mac_4_tx_clk_int;
wire                               qsfpddb_mac_4_tx_rst_int;

wire                               qsfpddb_mac_4_tx_ptp_clk_int;
wire                               qsfpddb_mac_4_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_4_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_4_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_4_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_4_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_4_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_4_tx_axis_tkeep_int;
wire                               qsfpddb_mac_4_tx_axis_tvalid_int;
wire                               qsfpddb_mac_4_tx_axis_tready_int;
wire                               qsfpddb_mac_4_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_4_tx_axis_tuser_int;

wire                               qsfpddb_mac_4_rx_clk_int;
wire                               qsfpddb_mac_4_rx_rst_int;

wire                               qsfpddb_mac_4_rx_ptp_clk_int;
wire                               qsfpddb_mac_4_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_4_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_4_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_4_rx_axis_tkeep_int;
wire                               qsfpddb_mac_4_rx_axis_tvalid_int;
wire                               qsfpddb_mac_4_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_4_rx_axis_tuser_int;

wire                               qsfpddb_mac_4_rx_status_int;

wire                               qsfpddb_mac_5_tx_clk_int;
wire                               qsfpddb_mac_5_tx_rst_int;

wire                               qsfpddb_mac_5_tx_ptp_clk_int;
wire                               qsfpddb_mac_5_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_5_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_5_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_5_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_5_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_5_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_5_tx_axis_tkeep_int;
wire                               qsfpddb_mac_5_tx_axis_tvalid_int;
wire                               qsfpddb_mac_5_tx_axis_tready_int;
wire                               qsfpddb_mac_5_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_5_tx_axis_tuser_int;

wire                               qsfpddb_mac_5_rx_clk_int;
wire                               qsfpddb_mac_5_rx_rst_int;

wire                               qsfpddb_mac_5_rx_ptp_clk_int;
wire                               qsfpddb_mac_5_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_5_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_5_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_5_rx_axis_tkeep_int;
wire                               qsfpddb_mac_5_rx_axis_tvalid_int;
wire                               qsfpddb_mac_5_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_5_rx_axis_tuser_int;

wire                               qsfpddb_mac_5_rx_status_int;

wire                               qsfpddb_mac_6_tx_clk_int;
wire                               qsfpddb_mac_6_tx_rst_int;

wire                               qsfpddb_mac_6_tx_ptp_clk_int;
wire                               qsfpddb_mac_6_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_6_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_6_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_6_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_6_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_6_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_6_tx_axis_tkeep_int;
wire                               qsfpddb_mac_6_tx_axis_tvalid_int;
wire                               qsfpddb_mac_6_tx_axis_tready_int;
wire                               qsfpddb_mac_6_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_6_tx_axis_tuser_int;

wire                               qsfpddb_mac_6_rx_clk_int;
wire                               qsfpddb_mac_6_rx_rst_int;

wire                               qsfpddb_mac_6_rx_ptp_clk_int;
wire                               qsfpddb_mac_6_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_6_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_6_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_6_rx_axis_tkeep_int;
wire                               qsfpddb_mac_6_rx_axis_tvalid_int;
wire                               qsfpddb_mac_6_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_6_rx_axis_tuser_int;

wire                               qsfpddb_mac_6_rx_status_int;

wire                               qsfpddb_mac_7_tx_clk_int;
wire                               qsfpddb_mac_7_tx_rst_int;

wire                               qsfpddb_mac_7_tx_ptp_clk_int;
wire                               qsfpddb_mac_7_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_7_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_7_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_7_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_7_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_7_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_7_tx_axis_tkeep_int;
wire                               qsfpddb_mac_7_tx_axis_tvalid_int;
wire                               qsfpddb_mac_7_tx_axis_tready_int;
wire                               qsfpddb_mac_7_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_7_tx_axis_tuser_int;

wire                               qsfpddb_mac_7_rx_clk_int;
wire                               qsfpddb_mac_7_rx_rst_int;

wire                               qsfpddb_mac_7_rx_ptp_clk_int;
wire                               qsfpddb_mac_7_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_7_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_7_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_7_rx_axis_tkeep_int;
wire                               qsfpddb_mac_7_rx_axis_tvalid_int;
wire                               qsfpddb_mac_7_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_7_rx_axis_tuser_int;

wire                               qsfpddb_mac_7_rx_status_int;

wire                               qsfpddb_mac_8_tx_clk_int;
wire                               qsfpddb_mac_8_tx_rst_int;

wire                               qsfpddb_mac_8_tx_ptp_clk_int;
wire                               qsfpddb_mac_8_tx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_8_tx_ptp_time_int;

wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_8_tx_ptp_ts_int;
wire [PTP_TAG_WIDTH-1:0]           qsfpddb_mac_8_tx_ptp_ts_tag_int;
wire                               qsfpddb_mac_8_tx_ptp_ts_valid_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_8_tx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_8_tx_axis_tkeep_int;
wire                               qsfpddb_mac_8_tx_axis_tvalid_int;
wire                               qsfpddb_mac_8_tx_axis_tready_int;
wire                               qsfpddb_mac_8_tx_axis_tlast_int;
wire [AXIS_ETH_TX_USER_WIDTH-1:0]  qsfpddb_mac_8_tx_axis_tuser_int;

wire                               qsfpddb_mac_8_rx_clk_int;
wire                               qsfpddb_mac_8_rx_rst_int;

wire                               qsfpddb_mac_8_rx_ptp_clk_int;
wire                               qsfpddb_mac_8_rx_ptp_rst_int;
wire [PTP_TS_WIDTH-1:0]            qsfpddb_mac_8_rx_ptp_time_int;

wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfpddb_mac_8_rx_axis_tdata_int;
wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfpddb_mac_8_rx_axis_tkeep_int;
wire                               qsfpddb_mac_8_rx_axis_tvalid_int;
wire                               qsfpddb_mac_8_rx_axis_tlast_int;
wire [AXIS_ETH_RX_USER_WIDTH-1:0]  qsfpddb_mac_8_rx_axis_tuser_int;

wire                               qsfpddb_mac_8_rx_status_int;

eth_mac_dual_quad_wrapper #(
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH),
    .MAC_RSFEC(MAC_RSFEC)
)
qsfpddb_mac_inst (
    .ctrl_clk(clk_100mhz),
    .ctrl_rst(rst_100mhz),

    .tx_serial_data_p({qsfpddb_tx_p[7], qsfpddb_tx_p[5], qsfpddb_tx_p[6], qsfpddb_tx_p[4], qsfpddb_tx_p[3], qsfpddb_tx_p[1], qsfpddb_tx_p[2], qsfpddb_tx_p[0]}),
    .tx_serial_data_n({qsfpddb_tx_n[7], qsfpddb_tx_n[5], qsfpddb_tx_n[6], qsfpddb_tx_n[4], qsfpddb_tx_n[3], qsfpddb_tx_n[1], qsfpddb_tx_n[2], qsfpddb_tx_n[0]}),
    .rx_serial_data_p({qsfpddb_rx_p[7], qsfpddb_rx_p[5], qsfpddb_rx_p[6], qsfpddb_rx_p[4], qsfpddb_rx_p[3], qsfpddb_rx_p[1], qsfpddb_rx_p[2], qsfpddb_rx_p[0]}),
    .rx_serial_data_n({qsfpddb_rx_n[7], qsfpddb_rx_n[5], qsfpddb_rx_n[6], qsfpddb_rx_n[4], qsfpddb_rx_n[3], qsfpddb_rx_n[1], qsfpddb_rx_n[2], qsfpddb_rx_n[0]}),
    .ref_clk(qsfpddb_refclk_p),
    .ptp_sample_clk(etile_ptp_sample_clk),

    .mac_1_tx_clk(qsfpddb_mac_1_tx_clk_int),
    .mac_1_tx_rst(qsfpddb_mac_1_tx_rst_int),

    .mac_1_tx_ptp_clk(qsfpddb_mac_1_tx_ptp_clk_int),
    .mac_1_tx_ptp_rst(qsfpddb_mac_1_tx_ptp_rst_int),
    .mac_1_tx_ptp_time(qsfpddb_mac_1_tx_ptp_time_int),

    .mac_1_tx_ptp_ts(qsfpddb_mac_1_tx_ptp_ts_int),
    .mac_1_tx_ptp_ts_tag(qsfpddb_mac_1_tx_ptp_ts_tag_int),
    .mac_1_tx_ptp_ts_valid(qsfpddb_mac_1_tx_ptp_ts_valid_int),

    .mac_1_tx_axis_tdata(qsfpddb_mac_1_tx_axis_tdata_int),
    .mac_1_tx_axis_tkeep(qsfpddb_mac_1_tx_axis_tkeep_int),
    .mac_1_tx_axis_tvalid(qsfpddb_mac_1_tx_axis_tvalid_int),
    .mac_1_tx_axis_tready(qsfpddb_mac_1_tx_axis_tready_int),
    .mac_1_tx_axis_tlast(qsfpddb_mac_1_tx_axis_tlast_int),
    .mac_1_tx_axis_tuser(qsfpddb_mac_1_tx_axis_tuser_int),

    .mac_1_rx_clk(qsfpddb_mac_1_rx_clk_int),
    .mac_1_rx_rst(qsfpddb_mac_1_rx_rst_int),

    .mac_1_rx_ptp_clk(qsfpddb_mac_1_rx_ptp_clk_int),
    .mac_1_rx_ptp_rst(qsfpddb_mac_1_rx_ptp_rst_int),
    .mac_1_rx_ptp_time(qsfpddb_mac_1_rx_ptp_time_int),

    .mac_1_rx_axis_tdata(qsfpddb_mac_1_rx_axis_tdata_int),
    .mac_1_rx_axis_tkeep(qsfpddb_mac_1_rx_axis_tkeep_int),
    .mac_1_rx_axis_tvalid(qsfpddb_mac_1_rx_axis_tvalid_int),
    .mac_1_rx_axis_tlast(qsfpddb_mac_1_rx_axis_tlast_int),
    .mac_1_rx_axis_tuser(qsfpddb_mac_1_rx_axis_tuser_int),

    .mac_1_rx_status(qsfpddb_mac_1_rx_status_int),

    .mac_2_tx_clk(qsfpddb_mac_3_tx_clk_int),
    .mac_2_tx_rst(qsfpddb_mac_3_tx_rst_int),

    .mac_2_tx_ptp_clk(qsfpddb_mac_3_tx_ptp_clk_int),
    .mac_2_tx_ptp_rst(qsfpddb_mac_3_tx_ptp_rst_int),
    .mac_2_tx_ptp_time(qsfpddb_mac_3_tx_ptp_time_int),

    .mac_2_tx_ptp_ts(qsfpddb_mac_3_tx_ptp_ts_int),
    .mac_2_tx_ptp_ts_tag(qsfpddb_mac_3_tx_ptp_ts_tag_int),
    .mac_2_tx_ptp_ts_valid(qsfpddb_mac_3_tx_ptp_ts_valid_int),

    .mac_2_tx_axis_tdata(qsfpddb_mac_3_tx_axis_tdata_int),
    .mac_2_tx_axis_tkeep(qsfpddb_mac_3_tx_axis_tkeep_int),
    .mac_2_tx_axis_tvalid(qsfpddb_mac_3_tx_axis_tvalid_int),
    .mac_2_tx_axis_tready(qsfpddb_mac_3_tx_axis_tready_int),
    .mac_2_tx_axis_tlast(qsfpddb_mac_3_tx_axis_tlast_int),
    .mac_2_tx_axis_tuser(qsfpddb_mac_3_tx_axis_tuser_int),

    .mac_2_rx_clk(qsfpddb_mac_3_rx_clk_int),
    .mac_2_rx_rst(qsfpddb_mac_3_rx_rst_int),

    .mac_2_rx_ptp_clk(qsfpddb_mac_3_rx_ptp_clk_int),
    .mac_2_rx_ptp_rst(qsfpddb_mac_3_rx_ptp_rst_int),
    .mac_2_rx_ptp_time(qsfpddb_mac_3_rx_ptp_time_int),

    .mac_2_rx_axis_tdata(qsfpddb_mac_3_rx_axis_tdata_int),
    .mac_2_rx_axis_tkeep(qsfpddb_mac_3_rx_axis_tkeep_int),
    .mac_2_rx_axis_tvalid(qsfpddb_mac_3_rx_axis_tvalid_int),
    .mac_2_rx_axis_tlast(qsfpddb_mac_3_rx_axis_tlast_int),
    .mac_2_rx_axis_tuser(qsfpddb_mac_3_rx_axis_tuser_int),

    .mac_2_rx_status(qsfpddb_mac_3_rx_status_int),

    .mac_3_tx_clk(qsfpddb_mac_2_tx_clk_int),
    .mac_3_tx_rst(qsfpddb_mac_2_tx_rst_int),

    .mac_3_tx_ptp_clk(qsfpddb_mac_2_tx_ptp_clk_int),
    .mac_3_tx_ptp_rst(qsfpddb_mac_2_tx_ptp_rst_int),
    .mac_3_tx_ptp_time(qsfpddb_mac_2_tx_ptp_time_int),

    .mac_3_tx_ptp_ts(qsfpddb_mac_2_tx_ptp_ts_int),
    .mac_3_tx_ptp_ts_tag(qsfpddb_mac_2_tx_ptp_ts_tag_int),
    .mac_3_tx_ptp_ts_valid(qsfpddb_mac_2_tx_ptp_ts_valid_int),

    .mac_3_tx_axis_tdata(qsfpddb_mac_2_tx_axis_tdata_int),
    .mac_3_tx_axis_tkeep(qsfpddb_mac_2_tx_axis_tkeep_int),
    .mac_3_tx_axis_tvalid(qsfpddb_mac_2_tx_axis_tvalid_int),
    .mac_3_tx_axis_tready(qsfpddb_mac_2_tx_axis_tready_int),
    .mac_3_tx_axis_tlast(qsfpddb_mac_2_tx_axis_tlast_int),
    .mac_3_tx_axis_tuser(qsfpddb_mac_2_tx_axis_tuser_int),

    .mac_3_rx_clk(qsfpddb_mac_2_rx_clk_int),
    .mac_3_rx_rst(qsfpddb_mac_2_rx_rst_int),

    .mac_3_rx_ptp_clk(qsfpddb_mac_2_rx_ptp_clk_int),
    .mac_3_rx_ptp_rst(qsfpddb_mac_2_rx_ptp_rst_int),
    .mac_3_rx_ptp_time(qsfpddb_mac_2_rx_ptp_time_int),

    .mac_3_rx_axis_tdata(qsfpddb_mac_2_rx_axis_tdata_int),
    .mac_3_rx_axis_tkeep(qsfpddb_mac_2_rx_axis_tkeep_int),
    .mac_3_rx_axis_tvalid(qsfpddb_mac_2_rx_axis_tvalid_int),
    .mac_3_rx_axis_tlast(qsfpddb_mac_2_rx_axis_tlast_int),
    .mac_3_rx_axis_tuser(qsfpddb_mac_2_rx_axis_tuser_int),

    .mac_3_rx_status(qsfpddb_mac_2_rx_status_int),

    .mac_4_tx_clk(qsfpddb_mac_4_tx_clk_int),
    .mac_4_tx_rst(qsfpddb_mac_4_tx_rst_int),

    .mac_4_tx_ptp_clk(qsfpddb_mac_4_tx_ptp_clk_int),
    .mac_4_tx_ptp_rst(qsfpddb_mac_4_tx_ptp_rst_int),
    .mac_4_tx_ptp_time(qsfpddb_mac_4_tx_ptp_time_int),

    .mac_4_tx_ptp_ts(qsfpddb_mac_4_tx_ptp_ts_int),
    .mac_4_tx_ptp_ts_tag(qsfpddb_mac_4_tx_ptp_ts_tag_int),
    .mac_4_tx_ptp_ts_valid(qsfpddb_mac_4_tx_ptp_ts_valid_int),

    .mac_4_tx_axis_tdata(qsfpddb_mac_4_tx_axis_tdata_int),
    .mac_4_tx_axis_tkeep(qsfpddb_mac_4_tx_axis_tkeep_int),
    .mac_4_tx_axis_tvalid(qsfpddb_mac_4_tx_axis_tvalid_int),
    .mac_4_tx_axis_tready(qsfpddb_mac_4_tx_axis_tready_int),
    .mac_4_tx_axis_tlast(qsfpddb_mac_4_tx_axis_tlast_int),
    .mac_4_tx_axis_tuser(qsfpddb_mac_4_tx_axis_tuser_int),

    .mac_4_rx_clk(qsfpddb_mac_4_rx_clk_int),
    .mac_4_rx_rst(qsfpddb_mac_4_rx_rst_int),

    .mac_4_rx_ptp_clk(qsfpddb_mac_4_rx_ptp_clk_int),
    .mac_4_rx_ptp_rst(qsfpddb_mac_4_rx_ptp_rst_int),
    .mac_4_rx_ptp_time(qsfpddb_mac_4_rx_ptp_time_int),

    .mac_4_rx_axis_tdata(qsfpddb_mac_4_rx_axis_tdata_int),
    .mac_4_rx_axis_tkeep(qsfpddb_mac_4_rx_axis_tkeep_int),
    .mac_4_rx_axis_tvalid(qsfpddb_mac_4_rx_axis_tvalid_int),
    .mac_4_rx_axis_tlast(qsfpddb_mac_4_rx_axis_tlast_int),
    .mac_4_rx_axis_tuser(qsfpddb_mac_4_rx_axis_tuser_int),

    .mac_4_rx_status(qsfpddb_mac_4_rx_status_int),

    .mac_5_tx_clk(qsfpddb_mac_5_tx_clk_int),
    .mac_5_tx_rst(qsfpddb_mac_5_tx_rst_int),

    .mac_5_tx_ptp_clk(qsfpddb_mac_5_tx_ptp_clk_int),
    .mac_5_tx_ptp_rst(qsfpddb_mac_5_tx_ptp_rst_int),
    .mac_5_tx_ptp_time(qsfpddb_mac_5_tx_ptp_time_int),

    .mac_5_tx_ptp_ts(qsfpddb_mac_5_tx_ptp_ts_int),
    .mac_5_tx_ptp_ts_tag(qsfpddb_mac_5_tx_ptp_ts_tag_int),
    .mac_5_tx_ptp_ts_valid(qsfpddb_mac_5_tx_ptp_ts_valid_int),

    .mac_5_tx_axis_tdata(qsfpddb_mac_5_tx_axis_tdata_int),
    .mac_5_tx_axis_tkeep(qsfpddb_mac_5_tx_axis_tkeep_int),
    .mac_5_tx_axis_tvalid(qsfpddb_mac_5_tx_axis_tvalid_int),
    .mac_5_tx_axis_tready(qsfpddb_mac_5_tx_axis_tready_int),
    .mac_5_tx_axis_tlast(qsfpddb_mac_5_tx_axis_tlast_int),
    .mac_5_tx_axis_tuser(qsfpddb_mac_5_tx_axis_tuser_int),

    .mac_5_rx_clk(qsfpddb_mac_5_rx_clk_int),
    .mac_5_rx_rst(qsfpddb_mac_5_rx_rst_int),

    .mac_5_rx_ptp_clk(qsfpddb_mac_5_rx_ptp_clk_int),
    .mac_5_rx_ptp_rst(qsfpddb_mac_5_rx_ptp_rst_int),
    .mac_5_rx_ptp_time(qsfpddb_mac_5_rx_ptp_time_int),

    .mac_5_rx_axis_tdata(qsfpddb_mac_5_rx_axis_tdata_int),
    .mac_5_rx_axis_tkeep(qsfpddb_mac_5_rx_axis_tkeep_int),
    .mac_5_rx_axis_tvalid(qsfpddb_mac_5_rx_axis_tvalid_int),
    .mac_5_rx_axis_tlast(qsfpddb_mac_5_rx_axis_tlast_int),
    .mac_5_rx_axis_tuser(qsfpddb_mac_5_rx_axis_tuser_int),

    .mac_5_rx_status(qsfpddb_mac_5_rx_status_int),

    .mac_6_tx_clk(qsfpddb_mac_7_tx_clk_int),
    .mac_6_tx_rst(qsfpddb_mac_7_tx_rst_int),

    .mac_6_tx_ptp_clk(qsfpddb_mac_7_tx_ptp_clk_int),
    .mac_6_tx_ptp_rst(qsfpddb_mac_7_tx_ptp_rst_int),
    .mac_6_tx_ptp_time(qsfpddb_mac_7_tx_ptp_time_int),

    .mac_6_tx_ptp_ts(qsfpddb_mac_7_tx_ptp_ts_int),
    .mac_6_tx_ptp_ts_tag(qsfpddb_mac_7_tx_ptp_ts_tag_int),
    .mac_6_tx_ptp_ts_valid(qsfpddb_mac_7_tx_ptp_ts_valid_int),

    .mac_6_tx_axis_tdata(qsfpddb_mac_7_tx_axis_tdata_int),
    .mac_6_tx_axis_tkeep(qsfpddb_mac_7_tx_axis_tkeep_int),
    .mac_6_tx_axis_tvalid(qsfpddb_mac_7_tx_axis_tvalid_int),
    .mac_6_tx_axis_tready(qsfpddb_mac_7_tx_axis_tready_int),
    .mac_6_tx_axis_tlast(qsfpddb_mac_7_tx_axis_tlast_int),
    .mac_6_tx_axis_tuser(qsfpddb_mac_7_tx_axis_tuser_int),

    .mac_6_rx_clk(qsfpddb_mac_7_rx_clk_int),
    .mac_6_rx_rst(qsfpddb_mac_7_rx_rst_int),

    .mac_6_rx_ptp_clk(qsfpddb_mac_7_rx_ptp_clk_int),
    .mac_6_rx_ptp_rst(qsfpddb_mac_7_rx_ptp_rst_int),
    .mac_6_rx_ptp_time(qsfpddb_mac_7_rx_ptp_time_int),

    .mac_6_rx_axis_tdata(qsfpddb_mac_7_rx_axis_tdata_int),
    .mac_6_rx_axis_tkeep(qsfpddb_mac_7_rx_axis_tkeep_int),
    .mac_6_rx_axis_tvalid(qsfpddb_mac_7_rx_axis_tvalid_int),
    .mac_6_rx_axis_tlast(qsfpddb_mac_7_rx_axis_tlast_int),
    .mac_6_rx_axis_tuser(qsfpddb_mac_7_rx_axis_tuser_int),

    .mac_6_rx_status(qsfpddb_mac_7_rx_status_int),

    .mac_7_tx_clk(qsfpddb_mac_6_tx_clk_int),
    .mac_7_tx_rst(qsfpddb_mac_6_tx_rst_int),

    .mac_7_tx_ptp_clk(qsfpddb_mac_6_tx_ptp_clk_int),
    .mac_7_tx_ptp_rst(qsfpddb_mac_6_tx_ptp_rst_int),
    .mac_7_tx_ptp_time(qsfpddb_mac_6_tx_ptp_time_int),

    .mac_7_tx_ptp_ts(qsfpddb_mac_6_tx_ptp_ts_int),
    .mac_7_tx_ptp_ts_tag(qsfpddb_mac_6_tx_ptp_ts_tag_int),
    .mac_7_tx_ptp_ts_valid(qsfpddb_mac_6_tx_ptp_ts_valid_int),

    .mac_7_tx_axis_tdata(qsfpddb_mac_6_tx_axis_tdata_int),
    .mac_7_tx_axis_tkeep(qsfpddb_mac_6_tx_axis_tkeep_int),
    .mac_7_tx_axis_tvalid(qsfpddb_mac_6_tx_axis_tvalid_int),
    .mac_7_tx_axis_tready(qsfpddb_mac_6_tx_axis_tready_int),
    .mac_7_tx_axis_tlast(qsfpddb_mac_6_tx_axis_tlast_int),
    .mac_7_tx_axis_tuser(qsfpddb_mac_6_tx_axis_tuser_int),

    .mac_7_rx_clk(qsfpddb_mac_6_rx_clk_int),
    .mac_7_rx_rst(qsfpddb_mac_6_rx_rst_int),

    .mac_7_rx_ptp_clk(qsfpddb_mac_6_rx_ptp_clk_int),
    .mac_7_rx_ptp_rst(qsfpddb_mac_6_rx_ptp_rst_int),
    .mac_7_rx_ptp_time(qsfpddb_mac_6_rx_ptp_time_int),

    .mac_7_rx_axis_tdata(qsfpddb_mac_6_rx_axis_tdata_int),
    .mac_7_rx_axis_tkeep(qsfpddb_mac_6_rx_axis_tkeep_int),
    .mac_7_rx_axis_tvalid(qsfpddb_mac_6_rx_axis_tvalid_int),
    .mac_7_rx_axis_tlast(qsfpddb_mac_6_rx_axis_tlast_int),
    .mac_7_rx_axis_tuser(qsfpddb_mac_6_rx_axis_tuser_int),

    .mac_7_rx_status(qsfpddb_mac_6_rx_status_int),

    .mac_8_tx_clk(qsfpddb_mac_8_tx_clk_int),
    .mac_8_tx_rst(qsfpddb_mac_8_tx_rst_int),

    .mac_8_tx_ptp_clk(qsfpddb_mac_8_tx_ptp_clk_int),
    .mac_8_tx_ptp_rst(qsfpddb_mac_8_tx_ptp_rst_int),
    .mac_8_tx_ptp_time(qsfpddb_mac_8_tx_ptp_time_int),

    .mac_8_tx_ptp_ts(qsfpddb_mac_8_tx_ptp_ts_int),
    .mac_8_tx_ptp_ts_tag(qsfpddb_mac_8_tx_ptp_ts_tag_int),
    .mac_8_tx_ptp_ts_valid(qsfpddb_mac_8_tx_ptp_ts_valid_int),

    .mac_8_tx_axis_tdata(qsfpddb_mac_8_tx_axis_tdata_int),
    .mac_8_tx_axis_tkeep(qsfpddb_mac_8_tx_axis_tkeep_int),
    .mac_8_tx_axis_tvalid(qsfpddb_mac_8_tx_axis_tvalid_int),
    .mac_8_tx_axis_tready(qsfpddb_mac_8_tx_axis_tready_int),
    .mac_8_tx_axis_tlast(qsfpddb_mac_8_tx_axis_tlast_int),
    .mac_8_tx_axis_tuser(qsfpddb_mac_8_tx_axis_tuser_int),

    .mac_8_rx_clk(qsfpddb_mac_8_rx_clk_int),
    .mac_8_rx_rst(qsfpddb_mac_8_rx_rst_int),

    .mac_8_rx_ptp_clk(qsfpddb_mac_8_rx_ptp_clk_int),
    .mac_8_rx_ptp_rst(qsfpddb_mac_8_rx_ptp_rst_int),
    .mac_8_rx_ptp_time(qsfpddb_mac_8_rx_ptp_time_int),

    .mac_8_rx_axis_tdata(qsfpddb_mac_8_rx_axis_tdata_int),
    .mac_8_rx_axis_tkeep(qsfpddb_mac_8_rx_axis_tkeep_int),
    .mac_8_rx_axis_tvalid(qsfpddb_mac_8_rx_axis_tvalid_int),
    .mac_8_rx_axis_tlast(qsfpddb_mac_8_rx_axis_tlast_int),
    .mac_8_rx_axis_tuser(qsfpddb_mac_8_rx_axis_tuser_int),

    .mac_8_rx_status(qsfpddb_mac_8_rx_status_int)
);

wire ptp_clk;
wire ptp_rst;
wire ptp_sample_clk;

assign ptp_sample_clk = clk_100mhz;

assign ptp_clk = qsfpdda_mac_1_tx_clk_int;
assign ptp_rst = qsfpdda_mac_1_tx_rst_int;

// ref_div ref_div_inst (
//     .inclk(etile_clk_402),
//     .clock_div1x(),
//     .clock_div2x(ptp_clk),
//     .clock_div4x()
// );

// sync_reset #(
//     .N(4)
// )
// ptp_rst_reset_sync_inst (
//     .clk(ptp_clk),
//     .rst(rst_100mhz),
//     .out(ptp_rst)
// );

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
    .PTP_SEPARATE_TX_CLOCK(1),
    .PTP_SEPARATE_RX_CLOCK(1),
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
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .SEG_HDR_WIDTH(SEG_HDR_WIDTH),
    .SEG_PRFX_WIDTH(SEG_PRFX_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
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
    .clk_250mhz(pcie_clk),
    .rst_250mhz(pcie_rst),

    /*
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),

    /*
     * GPIO
     */
    .button(button),
    .sw(sw),
    .led(led),
    .led_bracket(led_bracket),

    /*
     * P-Tile interface
     */
    .rx_st_data(rx_st_data),
    .rx_st_empty(rx_st_empty),
    .rx_st_sop(rx_st_sop),
    .rx_st_eop(rx_st_eop),
    .rx_st_valid(rx_st_valid),
    .rx_st_ready(rx_st_ready),
    .rx_st_hdr(rx_st_hdr),
    .rx_st_tlp_prfx(rx_st_tlp_prfx),
    .rx_st_vf_active(rx_st_vf_active),
    .rx_st_func_num(rx_st_func_num),
    .rx_st_vf_num(rx_st_vf_num),
    .rx_st_bar_range(rx_st_bar_range),
    .rx_st_tlp_abort(rx_st_tlp_abort),

    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),
    .tx_st_hdr(tx_st_hdr),
    .tx_st_tlp_prfx(tx_st_tlp_prfx),

    .rx_buffer_limit(rx_buffer_limit),
    .rx_buffer_limit_tdm_idx(rx_buffer_limit_tdm_idx),

    .tx_cdts_limit(tx_cdts_limit),
    .tx_cdts_limit_tdm_idx(tx_cdts_limit_tdm_idx),

    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * Ethernet: QSFP-DD
     */
    .qsfpdda_mac_1_tx_clk(qsfpdda_mac_1_tx_clk_int),
    .qsfpdda_mac_1_tx_rst(qsfpdda_mac_1_tx_rst_int),

    .qsfpdda_mac_1_tx_ptp_clk(qsfpdda_mac_1_tx_ptp_clk_int),
    .qsfpdda_mac_1_tx_ptp_rst(qsfpdda_mac_1_tx_ptp_rst_int),
    .qsfpdda_mac_1_tx_ptp_time(qsfpdda_mac_1_tx_ptp_time_int),

    .qsfpdda_mac_1_tx_ptp_ts(qsfpdda_mac_1_tx_ptp_ts_int),
    .qsfpdda_mac_1_tx_ptp_ts_tag(qsfpdda_mac_1_tx_ptp_ts_tag_int),
    .qsfpdda_mac_1_tx_ptp_ts_valid(qsfpdda_mac_1_tx_ptp_ts_valid_int),

    .qsfpdda_mac_1_tx_axis_tdata(qsfpdda_mac_1_tx_axis_tdata_int),
    .qsfpdda_mac_1_tx_axis_tkeep(qsfpdda_mac_1_tx_axis_tkeep_int),
    .qsfpdda_mac_1_tx_axis_tvalid(qsfpdda_mac_1_tx_axis_tvalid_int),
    .qsfpdda_mac_1_tx_axis_tready(qsfpdda_mac_1_tx_axis_tready_int),
    .qsfpdda_mac_1_tx_axis_tlast(qsfpdda_mac_1_tx_axis_tlast_int),
    .qsfpdda_mac_1_tx_axis_tuser(qsfpdda_mac_1_tx_axis_tuser_int),

    .qsfpdda_mac_1_rx_clk(qsfpdda_mac_1_rx_clk_int),
    .qsfpdda_mac_1_rx_rst(qsfpdda_mac_1_rx_rst_int),

    .qsfpdda_mac_1_rx_ptp_clk(qsfpdda_mac_1_rx_ptp_clk_int),
    .qsfpdda_mac_1_rx_ptp_rst(qsfpdda_mac_1_rx_ptp_rst_int),
    .qsfpdda_mac_1_rx_ptp_time(qsfpdda_mac_1_rx_ptp_time_int),

    .qsfpdda_mac_1_rx_axis_tdata(qsfpdda_mac_1_rx_axis_tdata_int),
    .qsfpdda_mac_1_rx_axis_tkeep(qsfpdda_mac_1_rx_axis_tkeep_int),
    .qsfpdda_mac_1_rx_axis_tvalid(qsfpdda_mac_1_rx_axis_tvalid_int),
    .qsfpdda_mac_1_rx_axis_tlast(qsfpdda_mac_1_rx_axis_tlast_int),
    .qsfpdda_mac_1_rx_axis_tuser(qsfpdda_mac_1_rx_axis_tuser_int),

    .qsfpdda_mac_1_rx_status(qsfpdda_mac_1_rx_status_int),

    .qsfpdda_mac_2_tx_clk(qsfpdda_mac_2_tx_clk_int),
    .qsfpdda_mac_2_tx_rst(qsfpdda_mac_2_tx_rst_int),

    .qsfpdda_mac_2_tx_ptp_clk(qsfpdda_mac_2_tx_ptp_clk_int),
    .qsfpdda_mac_2_tx_ptp_rst(qsfpdda_mac_2_tx_ptp_rst_int),
    .qsfpdda_mac_2_tx_ptp_time(qsfpdda_mac_2_tx_ptp_time_int),

    .qsfpdda_mac_2_tx_ptp_ts(qsfpdda_mac_2_tx_ptp_ts_int),
    .qsfpdda_mac_2_tx_ptp_ts_tag(qsfpdda_mac_2_tx_ptp_ts_tag_int),
    .qsfpdda_mac_2_tx_ptp_ts_valid(qsfpdda_mac_2_tx_ptp_ts_valid_int),

    .qsfpdda_mac_2_tx_axis_tdata(qsfpdda_mac_2_tx_axis_tdata_int),
    .qsfpdda_mac_2_tx_axis_tkeep(qsfpdda_mac_2_tx_axis_tkeep_int),
    .qsfpdda_mac_2_tx_axis_tvalid(qsfpdda_mac_2_tx_axis_tvalid_int),
    .qsfpdda_mac_2_tx_axis_tready(qsfpdda_mac_2_tx_axis_tready_int),
    .qsfpdda_mac_2_tx_axis_tlast(qsfpdda_mac_2_tx_axis_tlast_int),
    .qsfpdda_mac_2_tx_axis_tuser(qsfpdda_mac_2_tx_axis_tuser_int),

    .qsfpdda_mac_2_rx_clk(qsfpdda_mac_2_rx_clk_int),
    .qsfpdda_mac_2_rx_rst(qsfpdda_mac_2_rx_rst_int),

    .qsfpdda_mac_2_rx_ptp_clk(qsfpdda_mac_2_rx_ptp_clk_int),
    .qsfpdda_mac_2_rx_ptp_rst(qsfpdda_mac_2_rx_ptp_rst_int),
    .qsfpdda_mac_2_rx_ptp_time(qsfpdda_mac_2_rx_ptp_time_int),

    .qsfpdda_mac_2_rx_axis_tdata(qsfpdda_mac_2_rx_axis_tdata_int),
    .qsfpdda_mac_2_rx_axis_tkeep(qsfpdda_mac_2_rx_axis_tkeep_int),
    .qsfpdda_mac_2_rx_axis_tvalid(qsfpdda_mac_2_rx_axis_tvalid_int),
    .qsfpdda_mac_2_rx_axis_tlast(qsfpdda_mac_2_rx_axis_tlast_int),
    .qsfpdda_mac_2_rx_axis_tuser(qsfpdda_mac_2_rx_axis_tuser_int),

    .qsfpdda_mac_2_rx_status(qsfpdda_mac_2_rx_status_int),

    .qsfpdda_mac_3_tx_clk(qsfpdda_mac_3_tx_clk_int),
    .qsfpdda_mac_3_tx_rst(qsfpdda_mac_3_tx_rst_int),

    .qsfpdda_mac_3_tx_ptp_clk(qsfpdda_mac_3_tx_ptp_clk_int),
    .qsfpdda_mac_3_tx_ptp_rst(qsfpdda_mac_3_tx_ptp_rst_int),
    .qsfpdda_mac_3_tx_ptp_time(qsfpdda_mac_3_tx_ptp_time_int),

    .qsfpdda_mac_3_tx_ptp_ts(qsfpdda_mac_3_tx_ptp_ts_int),
    .qsfpdda_mac_3_tx_ptp_ts_tag(qsfpdda_mac_3_tx_ptp_ts_tag_int),
    .qsfpdda_mac_3_tx_ptp_ts_valid(qsfpdda_mac_3_tx_ptp_ts_valid_int),

    .qsfpdda_mac_3_tx_axis_tdata(qsfpdda_mac_3_tx_axis_tdata_int),
    .qsfpdda_mac_3_tx_axis_tkeep(qsfpdda_mac_3_tx_axis_tkeep_int),
    .qsfpdda_mac_3_tx_axis_tvalid(qsfpdda_mac_3_tx_axis_tvalid_int),
    .qsfpdda_mac_3_tx_axis_tready(qsfpdda_mac_3_tx_axis_tready_int),
    .qsfpdda_mac_3_tx_axis_tlast(qsfpdda_mac_3_tx_axis_tlast_int),
    .qsfpdda_mac_3_tx_axis_tuser(qsfpdda_mac_3_tx_axis_tuser_int),

    .qsfpdda_mac_3_rx_clk(qsfpdda_mac_3_rx_clk_int),
    .qsfpdda_mac_3_rx_rst(qsfpdda_mac_3_rx_rst_int),

    .qsfpdda_mac_3_rx_ptp_clk(qsfpdda_mac_3_rx_ptp_clk_int),
    .qsfpdda_mac_3_rx_ptp_rst(qsfpdda_mac_3_rx_ptp_rst_int),
    .qsfpdda_mac_3_rx_ptp_time(qsfpdda_mac_3_rx_ptp_time_int),

    .qsfpdda_mac_3_rx_axis_tdata(qsfpdda_mac_3_rx_axis_tdata_int),
    .qsfpdda_mac_3_rx_axis_tkeep(qsfpdda_mac_3_rx_axis_tkeep_int),
    .qsfpdda_mac_3_rx_axis_tvalid(qsfpdda_mac_3_rx_axis_tvalid_int),
    .qsfpdda_mac_3_rx_axis_tlast(qsfpdda_mac_3_rx_axis_tlast_int),
    .qsfpdda_mac_3_rx_axis_tuser(qsfpdda_mac_3_rx_axis_tuser_int),

    .qsfpdda_mac_3_rx_status(qsfpdda_mac_3_rx_status_int),

    .qsfpdda_mac_4_tx_clk(qsfpdda_mac_4_tx_clk_int),
    .qsfpdda_mac_4_tx_rst(qsfpdda_mac_4_tx_rst_int),

    .qsfpdda_mac_4_tx_ptp_clk(qsfpdda_mac_4_tx_ptp_clk_int),
    .qsfpdda_mac_4_tx_ptp_rst(qsfpdda_mac_4_tx_ptp_rst_int),
    .qsfpdda_mac_4_tx_ptp_time(qsfpdda_mac_4_tx_ptp_time_int),

    .qsfpdda_mac_4_tx_ptp_ts(qsfpdda_mac_4_tx_ptp_ts_int),
    .qsfpdda_mac_4_tx_ptp_ts_tag(qsfpdda_mac_4_tx_ptp_ts_tag_int),
    .qsfpdda_mac_4_tx_ptp_ts_valid(qsfpdda_mac_4_tx_ptp_ts_valid_int),

    .qsfpdda_mac_4_tx_axis_tdata(qsfpdda_mac_4_tx_axis_tdata_int),
    .qsfpdda_mac_4_tx_axis_tkeep(qsfpdda_mac_4_tx_axis_tkeep_int),
    .qsfpdda_mac_4_tx_axis_tvalid(qsfpdda_mac_4_tx_axis_tvalid_int),
    .qsfpdda_mac_4_tx_axis_tready(qsfpdda_mac_4_tx_axis_tready_int),
    .qsfpdda_mac_4_tx_axis_tlast(qsfpdda_mac_4_tx_axis_tlast_int),
    .qsfpdda_mac_4_tx_axis_tuser(qsfpdda_mac_4_tx_axis_tuser_int),

    .qsfpdda_mac_4_rx_clk(qsfpdda_mac_4_rx_clk_int),
    .qsfpdda_mac_4_rx_rst(qsfpdda_mac_4_rx_rst_int),

    .qsfpdda_mac_4_rx_ptp_clk(qsfpdda_mac_4_rx_ptp_clk_int),
    .qsfpdda_mac_4_rx_ptp_rst(qsfpdda_mac_4_rx_ptp_rst_int),
    .qsfpdda_mac_4_rx_ptp_time(qsfpdda_mac_4_rx_ptp_time_int),

    .qsfpdda_mac_4_rx_axis_tdata(qsfpdda_mac_4_rx_axis_tdata_int),
    .qsfpdda_mac_4_rx_axis_tkeep(qsfpdda_mac_4_rx_axis_tkeep_int),
    .qsfpdda_mac_4_rx_axis_tvalid(qsfpdda_mac_4_rx_axis_tvalid_int),
    .qsfpdda_mac_4_rx_axis_tlast(qsfpdda_mac_4_rx_axis_tlast_int),
    .qsfpdda_mac_4_rx_axis_tuser(qsfpdda_mac_4_rx_axis_tuser_int),

    .qsfpdda_mac_4_rx_status(qsfpdda_mac_4_rx_status_int),

    .qsfpdda_mac_5_tx_clk(qsfpdda_mac_5_tx_clk_int),
    .qsfpdda_mac_5_tx_rst(qsfpdda_mac_5_tx_rst_int),

    .qsfpdda_mac_5_tx_ptp_clk(qsfpdda_mac_5_tx_ptp_clk_int),
    .qsfpdda_mac_5_tx_ptp_rst(qsfpdda_mac_5_tx_ptp_rst_int),
    .qsfpdda_mac_5_tx_ptp_time(qsfpdda_mac_5_tx_ptp_time_int),

    .qsfpdda_mac_5_tx_ptp_ts(qsfpdda_mac_5_tx_ptp_ts_int),
    .qsfpdda_mac_5_tx_ptp_ts_tag(qsfpdda_mac_5_tx_ptp_ts_tag_int),
    .qsfpdda_mac_5_tx_ptp_ts_valid(qsfpdda_mac_5_tx_ptp_ts_valid_int),

    .qsfpdda_mac_5_tx_axis_tdata(qsfpdda_mac_5_tx_axis_tdata_int),
    .qsfpdda_mac_5_tx_axis_tkeep(qsfpdda_mac_5_tx_axis_tkeep_int),
    .qsfpdda_mac_5_tx_axis_tvalid(qsfpdda_mac_5_tx_axis_tvalid_int),
    .qsfpdda_mac_5_tx_axis_tready(qsfpdda_mac_5_tx_axis_tready_int),
    .qsfpdda_mac_5_tx_axis_tlast(qsfpdda_mac_5_tx_axis_tlast_int),
    .qsfpdda_mac_5_tx_axis_tuser(qsfpdda_mac_5_tx_axis_tuser_int),

    .qsfpdda_mac_5_rx_clk(qsfpdda_mac_5_rx_clk_int),
    .qsfpdda_mac_5_rx_rst(qsfpdda_mac_5_rx_rst_int),

    .qsfpdda_mac_5_rx_ptp_clk(qsfpdda_mac_5_rx_ptp_clk_int),
    .qsfpdda_mac_5_rx_ptp_rst(qsfpdda_mac_5_rx_ptp_rst_int),
    .qsfpdda_mac_5_rx_ptp_time(qsfpdda_mac_5_rx_ptp_time_int),

    .qsfpdda_mac_5_rx_axis_tdata(qsfpdda_mac_5_rx_axis_tdata_int),
    .qsfpdda_mac_5_rx_axis_tkeep(qsfpdda_mac_5_rx_axis_tkeep_int),
    .qsfpdda_mac_5_rx_axis_tvalid(qsfpdda_mac_5_rx_axis_tvalid_int),
    .qsfpdda_mac_5_rx_axis_tlast(qsfpdda_mac_5_rx_axis_tlast_int),
    .qsfpdda_mac_5_rx_axis_tuser(qsfpdda_mac_5_rx_axis_tuser_int),

    .qsfpdda_mac_5_rx_status(qsfpdda_mac_5_rx_status_int),

    .qsfpdda_mac_6_tx_clk(qsfpdda_mac_6_tx_clk_int),
    .qsfpdda_mac_6_tx_rst(qsfpdda_mac_6_tx_rst_int),

    .qsfpdda_mac_6_tx_ptp_clk(qsfpdda_mac_6_tx_ptp_clk_int),
    .qsfpdda_mac_6_tx_ptp_rst(qsfpdda_mac_6_tx_ptp_rst_int),
    .qsfpdda_mac_6_tx_ptp_time(qsfpdda_mac_6_tx_ptp_time_int),

    .qsfpdda_mac_6_tx_ptp_ts(qsfpdda_mac_6_tx_ptp_ts_int),
    .qsfpdda_mac_6_tx_ptp_ts_tag(qsfpdda_mac_6_tx_ptp_ts_tag_int),
    .qsfpdda_mac_6_tx_ptp_ts_valid(qsfpdda_mac_6_tx_ptp_ts_valid_int),

    .qsfpdda_mac_6_tx_axis_tdata(qsfpdda_mac_6_tx_axis_tdata_int),
    .qsfpdda_mac_6_tx_axis_tkeep(qsfpdda_mac_6_tx_axis_tkeep_int),
    .qsfpdda_mac_6_tx_axis_tvalid(qsfpdda_mac_6_tx_axis_tvalid_int),
    .qsfpdda_mac_6_tx_axis_tready(qsfpdda_mac_6_tx_axis_tready_int),
    .qsfpdda_mac_6_tx_axis_tlast(qsfpdda_mac_6_tx_axis_tlast_int),
    .qsfpdda_mac_6_tx_axis_tuser(qsfpdda_mac_6_tx_axis_tuser_int),

    .qsfpdda_mac_6_rx_clk(qsfpdda_mac_6_rx_clk_int),
    .qsfpdda_mac_6_rx_rst(qsfpdda_mac_6_rx_rst_int),

    .qsfpdda_mac_6_rx_ptp_clk(qsfpdda_mac_6_rx_ptp_clk_int),
    .qsfpdda_mac_6_rx_ptp_rst(qsfpdda_mac_6_rx_ptp_rst_int),
    .qsfpdda_mac_6_rx_ptp_time(qsfpdda_mac_6_rx_ptp_time_int),

    .qsfpdda_mac_6_rx_axis_tdata(qsfpdda_mac_6_rx_axis_tdata_int),
    .qsfpdda_mac_6_rx_axis_tkeep(qsfpdda_mac_6_rx_axis_tkeep_int),
    .qsfpdda_mac_6_rx_axis_tvalid(qsfpdda_mac_6_rx_axis_tvalid_int),
    .qsfpdda_mac_6_rx_axis_tlast(qsfpdda_mac_6_rx_axis_tlast_int),
    .qsfpdda_mac_6_rx_axis_tuser(qsfpdda_mac_6_rx_axis_tuser_int),

    .qsfpdda_mac_6_rx_status(qsfpdda_mac_6_rx_status_int),

    .qsfpdda_mac_7_tx_clk(qsfpdda_mac_7_tx_clk_int),
    .qsfpdda_mac_7_tx_rst(qsfpdda_mac_7_tx_rst_int),

    .qsfpdda_mac_7_tx_ptp_clk(qsfpdda_mac_7_tx_ptp_clk_int),
    .qsfpdda_mac_7_tx_ptp_rst(qsfpdda_mac_7_tx_ptp_rst_int),
    .qsfpdda_mac_7_tx_ptp_time(qsfpdda_mac_7_tx_ptp_time_int),

    .qsfpdda_mac_7_tx_ptp_ts(qsfpdda_mac_7_tx_ptp_ts_int),
    .qsfpdda_mac_7_tx_ptp_ts_tag(qsfpdda_mac_7_tx_ptp_ts_tag_int),
    .qsfpdda_mac_7_tx_ptp_ts_valid(qsfpdda_mac_7_tx_ptp_ts_valid_int),

    .qsfpdda_mac_7_tx_axis_tdata(qsfpdda_mac_7_tx_axis_tdata_int),
    .qsfpdda_mac_7_tx_axis_tkeep(qsfpdda_mac_7_tx_axis_tkeep_int),
    .qsfpdda_mac_7_tx_axis_tvalid(qsfpdda_mac_7_tx_axis_tvalid_int),
    .qsfpdda_mac_7_tx_axis_tready(qsfpdda_mac_7_tx_axis_tready_int),
    .qsfpdda_mac_7_tx_axis_tlast(qsfpdda_mac_7_tx_axis_tlast_int),
    .qsfpdda_mac_7_tx_axis_tuser(qsfpdda_mac_7_tx_axis_tuser_int),

    .qsfpdda_mac_7_rx_clk(qsfpdda_mac_7_rx_clk_int),
    .qsfpdda_mac_7_rx_rst(qsfpdda_mac_7_rx_rst_int),

    .qsfpdda_mac_7_rx_ptp_clk(qsfpdda_mac_7_rx_ptp_clk_int),
    .qsfpdda_mac_7_rx_ptp_rst(qsfpdda_mac_7_rx_ptp_rst_int),
    .qsfpdda_mac_7_rx_ptp_time(qsfpdda_mac_7_rx_ptp_time_int),

    .qsfpdda_mac_7_rx_axis_tdata(qsfpdda_mac_7_rx_axis_tdata_int),
    .qsfpdda_mac_7_rx_axis_tkeep(qsfpdda_mac_7_rx_axis_tkeep_int),
    .qsfpdda_mac_7_rx_axis_tvalid(qsfpdda_mac_7_rx_axis_tvalid_int),
    .qsfpdda_mac_7_rx_axis_tlast(qsfpdda_mac_7_rx_axis_tlast_int),
    .qsfpdda_mac_7_rx_axis_tuser(qsfpdda_mac_7_rx_axis_tuser_int),

    .qsfpdda_mac_7_rx_status(qsfpdda_mac_7_rx_status_int),

    .qsfpdda_mac_8_tx_clk(qsfpdda_mac_8_tx_clk_int),
    .qsfpdda_mac_8_tx_rst(qsfpdda_mac_8_tx_rst_int),

    .qsfpdda_mac_8_tx_ptp_clk(qsfpdda_mac_8_tx_ptp_clk_int),
    .qsfpdda_mac_8_tx_ptp_rst(qsfpdda_mac_8_tx_ptp_rst_int),
    .qsfpdda_mac_8_tx_ptp_time(qsfpdda_mac_8_tx_ptp_time_int),

    .qsfpdda_mac_8_tx_ptp_ts(qsfpdda_mac_8_tx_ptp_ts_int),
    .qsfpdda_mac_8_tx_ptp_ts_tag(qsfpdda_mac_8_tx_ptp_ts_tag_int),
    .qsfpdda_mac_8_tx_ptp_ts_valid(qsfpdda_mac_8_tx_ptp_ts_valid_int),

    .qsfpdda_mac_8_tx_axis_tdata(qsfpdda_mac_8_tx_axis_tdata_int),
    .qsfpdda_mac_8_tx_axis_tkeep(qsfpdda_mac_8_tx_axis_tkeep_int),
    .qsfpdda_mac_8_tx_axis_tvalid(qsfpdda_mac_8_tx_axis_tvalid_int),
    .qsfpdda_mac_8_tx_axis_tready(qsfpdda_mac_8_tx_axis_tready_int),
    .qsfpdda_mac_8_tx_axis_tlast(qsfpdda_mac_8_tx_axis_tlast_int),
    .qsfpdda_mac_8_tx_axis_tuser(qsfpdda_mac_8_tx_axis_tuser_int),

    .qsfpdda_mac_8_rx_clk(qsfpdda_mac_8_rx_clk_int),
    .qsfpdda_mac_8_rx_rst(qsfpdda_mac_8_rx_rst_int),

    .qsfpdda_mac_8_rx_ptp_clk(qsfpdda_mac_8_rx_ptp_clk_int),
    .qsfpdda_mac_8_rx_ptp_rst(qsfpdda_mac_8_rx_ptp_rst_int),
    .qsfpdda_mac_8_rx_ptp_time(qsfpdda_mac_8_rx_ptp_time_int),

    .qsfpdda_mac_8_rx_axis_tdata(qsfpdda_mac_8_rx_axis_tdata_int),
    .qsfpdda_mac_8_rx_axis_tkeep(qsfpdda_mac_8_rx_axis_tkeep_int),
    .qsfpdda_mac_8_rx_axis_tvalid(qsfpdda_mac_8_rx_axis_tvalid_int),
    .qsfpdda_mac_8_rx_axis_tlast(qsfpdda_mac_8_rx_axis_tlast_int),
    .qsfpdda_mac_8_rx_axis_tuser(qsfpdda_mac_8_rx_axis_tuser_int),

    .qsfpdda_mac_8_rx_status(qsfpdda_mac_8_rx_status_int),

    .qsfpdda_initmode(qsfpdda_initmode),
    .qsfpdda_interrupt_n(qsfpdda_interrupt_n_int),
    .qsfpdda_mod_prs_n(qsfpdda_mod_prs_n_int),
    .qsfpdda_mod_sel_n(qsfpdda_mod_sel_n),
    .qsfpdda_rst_n(qsfpdda_rst_n),
    .qsfpdda_scl_i(qsfpdda_scl_i),
    .qsfpdda_scl_o(qsfpdda_scl_o),
    .qsfpdda_scl_t(qsfpdda_scl_t),
    .qsfpdda_sda_i(qsfpdda_sda_i),
    .qsfpdda_sda_o(qsfpdda_sda_o),
    .qsfpdda_sda_t(qsfpdda_sda_t),

    .qsfpddb_mac_1_tx_clk(qsfpddb_mac_1_tx_clk_int),
    .qsfpddb_mac_1_tx_rst(qsfpddb_mac_1_tx_rst_int),

    .qsfpddb_mac_1_tx_ptp_clk(qsfpddb_mac_1_tx_ptp_clk_int),
    .qsfpddb_mac_1_tx_ptp_rst(qsfpddb_mac_1_tx_ptp_rst_int),
    .qsfpddb_mac_1_tx_ptp_time(qsfpddb_mac_1_tx_ptp_time_int),

    .qsfpddb_mac_1_tx_ptp_ts(qsfpddb_mac_1_tx_ptp_ts_int),
    .qsfpddb_mac_1_tx_ptp_ts_tag(qsfpddb_mac_1_tx_ptp_ts_tag_int),
    .qsfpddb_mac_1_tx_ptp_ts_valid(qsfpddb_mac_1_tx_ptp_ts_valid_int),

    .qsfpddb_mac_1_tx_axis_tdata(qsfpddb_mac_1_tx_axis_tdata_int),
    .qsfpddb_mac_1_tx_axis_tkeep(qsfpddb_mac_1_tx_axis_tkeep_int),
    .qsfpddb_mac_1_tx_axis_tvalid(qsfpddb_mac_1_tx_axis_tvalid_int),
    .qsfpddb_mac_1_tx_axis_tready(qsfpddb_mac_1_tx_axis_tready_int),
    .qsfpddb_mac_1_tx_axis_tlast(qsfpddb_mac_1_tx_axis_tlast_int),
    .qsfpddb_mac_1_tx_axis_tuser(qsfpddb_mac_1_tx_axis_tuser_int),

    .qsfpddb_mac_1_rx_clk(qsfpddb_mac_1_rx_clk_int),
    .qsfpddb_mac_1_rx_rst(qsfpddb_mac_1_rx_rst_int),

    .qsfpddb_mac_1_rx_ptp_clk(qsfpddb_mac_1_rx_ptp_clk_int),
    .qsfpddb_mac_1_rx_ptp_rst(qsfpddb_mac_1_rx_ptp_rst_int),
    .qsfpddb_mac_1_rx_ptp_time(qsfpddb_mac_1_rx_ptp_time_int),

    .qsfpddb_mac_1_rx_axis_tdata(qsfpddb_mac_1_rx_axis_tdata_int),
    .qsfpddb_mac_1_rx_axis_tkeep(qsfpddb_mac_1_rx_axis_tkeep_int),
    .qsfpddb_mac_1_rx_axis_tvalid(qsfpddb_mac_1_rx_axis_tvalid_int),
    .qsfpddb_mac_1_rx_axis_tlast(qsfpddb_mac_1_rx_axis_tlast_int),
    .qsfpddb_mac_1_rx_axis_tuser(qsfpddb_mac_1_rx_axis_tuser_int),

    .qsfpddb_mac_1_rx_status(qsfpddb_mac_1_rx_status_int),

    .qsfpddb_mac_2_tx_clk(qsfpddb_mac_2_tx_clk_int),
    .qsfpddb_mac_2_tx_rst(qsfpddb_mac_2_tx_rst_int),

    .qsfpddb_mac_2_tx_ptp_clk(qsfpddb_mac_2_tx_ptp_clk_int),
    .qsfpddb_mac_2_tx_ptp_rst(qsfpddb_mac_2_tx_ptp_rst_int),
    .qsfpddb_mac_2_tx_ptp_time(qsfpddb_mac_2_tx_ptp_time_int),

    .qsfpddb_mac_2_tx_ptp_ts(qsfpddb_mac_2_tx_ptp_ts_int),
    .qsfpddb_mac_2_tx_ptp_ts_tag(qsfpddb_mac_2_tx_ptp_ts_tag_int),
    .qsfpddb_mac_2_tx_ptp_ts_valid(qsfpddb_mac_2_tx_ptp_ts_valid_int),

    .qsfpddb_mac_2_tx_axis_tdata(qsfpddb_mac_2_tx_axis_tdata_int),
    .qsfpddb_mac_2_tx_axis_tkeep(qsfpddb_mac_2_tx_axis_tkeep_int),
    .qsfpddb_mac_2_tx_axis_tvalid(qsfpddb_mac_2_tx_axis_tvalid_int),
    .qsfpddb_mac_2_tx_axis_tready(qsfpddb_mac_2_tx_axis_tready_int),
    .qsfpddb_mac_2_tx_axis_tlast(qsfpddb_mac_2_tx_axis_tlast_int),
    .qsfpddb_mac_2_tx_axis_tuser(qsfpddb_mac_2_tx_axis_tuser_int),

    .qsfpddb_mac_2_rx_clk(qsfpddb_mac_2_rx_clk_int),
    .qsfpddb_mac_2_rx_rst(qsfpddb_mac_2_rx_rst_int),

    .qsfpddb_mac_2_rx_ptp_clk(qsfpddb_mac_2_rx_ptp_clk_int),
    .qsfpddb_mac_2_rx_ptp_rst(qsfpddb_mac_2_rx_ptp_rst_int),
    .qsfpddb_mac_2_rx_ptp_time(qsfpddb_mac_2_rx_ptp_time_int),

    .qsfpddb_mac_2_rx_axis_tdata(qsfpddb_mac_2_rx_axis_tdata_int),
    .qsfpddb_mac_2_rx_axis_tkeep(qsfpddb_mac_2_rx_axis_tkeep_int),
    .qsfpddb_mac_2_rx_axis_tvalid(qsfpddb_mac_2_rx_axis_tvalid_int),
    .qsfpddb_mac_2_rx_axis_tlast(qsfpddb_mac_2_rx_axis_tlast_int),
    .qsfpddb_mac_2_rx_axis_tuser(qsfpddb_mac_2_rx_axis_tuser_int),

    .qsfpddb_mac_2_rx_status(qsfpddb_mac_2_rx_status_int),

    .qsfpddb_mac_3_tx_clk(qsfpddb_mac_3_tx_clk_int),
    .qsfpddb_mac_3_tx_rst(qsfpddb_mac_3_tx_rst_int),

    .qsfpddb_mac_3_tx_ptp_clk(qsfpddb_mac_3_tx_ptp_clk_int),
    .qsfpddb_mac_3_tx_ptp_rst(qsfpddb_mac_3_tx_ptp_rst_int),
    .qsfpddb_mac_3_tx_ptp_time(qsfpddb_mac_3_tx_ptp_time_int),

    .qsfpddb_mac_3_tx_ptp_ts(qsfpddb_mac_3_tx_ptp_ts_int),
    .qsfpddb_mac_3_tx_ptp_ts_tag(qsfpddb_mac_3_tx_ptp_ts_tag_int),
    .qsfpddb_mac_3_tx_ptp_ts_valid(qsfpddb_mac_3_tx_ptp_ts_valid_int),

    .qsfpddb_mac_3_tx_axis_tdata(qsfpddb_mac_3_tx_axis_tdata_int),
    .qsfpddb_mac_3_tx_axis_tkeep(qsfpddb_mac_3_tx_axis_tkeep_int),
    .qsfpddb_mac_3_tx_axis_tvalid(qsfpddb_mac_3_tx_axis_tvalid_int),
    .qsfpddb_mac_3_tx_axis_tready(qsfpddb_mac_3_tx_axis_tready_int),
    .qsfpddb_mac_3_tx_axis_tlast(qsfpddb_mac_3_tx_axis_tlast_int),
    .qsfpddb_mac_3_tx_axis_tuser(qsfpddb_mac_3_tx_axis_tuser_int),

    .qsfpddb_mac_3_rx_clk(qsfpddb_mac_3_rx_clk_int),
    .qsfpddb_mac_3_rx_rst(qsfpddb_mac_3_rx_rst_int),

    .qsfpddb_mac_3_rx_ptp_clk(qsfpddb_mac_3_rx_ptp_clk_int),
    .qsfpddb_mac_3_rx_ptp_rst(qsfpddb_mac_3_rx_ptp_rst_int),
    .qsfpddb_mac_3_rx_ptp_time(qsfpddb_mac_3_rx_ptp_time_int),

    .qsfpddb_mac_3_rx_axis_tdata(qsfpddb_mac_3_rx_axis_tdata_int),
    .qsfpddb_mac_3_rx_axis_tkeep(qsfpddb_mac_3_rx_axis_tkeep_int),
    .qsfpddb_mac_3_rx_axis_tvalid(qsfpddb_mac_3_rx_axis_tvalid_int),
    .qsfpddb_mac_3_rx_axis_tlast(qsfpddb_mac_3_rx_axis_tlast_int),
    .qsfpddb_mac_3_rx_axis_tuser(qsfpddb_mac_3_rx_axis_tuser_int),

    .qsfpddb_mac_3_rx_status(qsfpddb_mac_3_rx_status_int),

    .qsfpddb_mac_4_tx_clk(qsfpddb_mac_4_tx_clk_int),
    .qsfpddb_mac_4_tx_rst(qsfpddb_mac_4_tx_rst_int),

    .qsfpddb_mac_4_tx_ptp_clk(qsfpddb_mac_4_tx_ptp_clk_int),
    .qsfpddb_mac_4_tx_ptp_rst(qsfpddb_mac_4_tx_ptp_rst_int),
    .qsfpddb_mac_4_tx_ptp_time(qsfpddb_mac_4_tx_ptp_time_int),

    .qsfpddb_mac_4_tx_ptp_ts(qsfpddb_mac_4_tx_ptp_ts_int),
    .qsfpddb_mac_4_tx_ptp_ts_tag(qsfpddb_mac_4_tx_ptp_ts_tag_int),
    .qsfpddb_mac_4_tx_ptp_ts_valid(qsfpddb_mac_4_tx_ptp_ts_valid_int),

    .qsfpddb_mac_4_tx_axis_tdata(qsfpddb_mac_4_tx_axis_tdata_int),
    .qsfpddb_mac_4_tx_axis_tkeep(qsfpddb_mac_4_tx_axis_tkeep_int),
    .qsfpddb_mac_4_tx_axis_tvalid(qsfpddb_mac_4_tx_axis_tvalid_int),
    .qsfpddb_mac_4_tx_axis_tready(qsfpddb_mac_4_tx_axis_tready_int),
    .qsfpddb_mac_4_tx_axis_tlast(qsfpddb_mac_4_tx_axis_tlast_int),
    .qsfpddb_mac_4_tx_axis_tuser(qsfpddb_mac_4_tx_axis_tuser_int),

    .qsfpddb_mac_4_rx_clk(qsfpddb_mac_4_rx_clk_int),
    .qsfpddb_mac_4_rx_rst(qsfpddb_mac_4_rx_rst_int),

    .qsfpddb_mac_4_rx_ptp_clk(qsfpddb_mac_4_rx_ptp_clk_int),
    .qsfpddb_mac_4_rx_ptp_rst(qsfpddb_mac_4_rx_ptp_rst_int),
    .qsfpddb_mac_4_rx_ptp_time(qsfpddb_mac_4_rx_ptp_time_int),

    .qsfpddb_mac_4_rx_axis_tdata(qsfpddb_mac_4_rx_axis_tdata_int),
    .qsfpddb_mac_4_rx_axis_tkeep(qsfpddb_mac_4_rx_axis_tkeep_int),
    .qsfpddb_mac_4_rx_axis_tvalid(qsfpddb_mac_4_rx_axis_tvalid_int),
    .qsfpddb_mac_4_rx_axis_tlast(qsfpddb_mac_4_rx_axis_tlast_int),
    .qsfpddb_mac_4_rx_axis_tuser(qsfpddb_mac_4_rx_axis_tuser_int),

    .qsfpddb_mac_4_rx_status(qsfpddb_mac_4_rx_status_int),

    .qsfpddb_mac_5_tx_clk(qsfpddb_mac_5_tx_clk_int),
    .qsfpddb_mac_5_tx_rst(qsfpddb_mac_5_tx_rst_int),

    .qsfpddb_mac_5_tx_ptp_clk(qsfpddb_mac_5_tx_ptp_clk_int),
    .qsfpddb_mac_5_tx_ptp_rst(qsfpddb_mac_5_tx_ptp_rst_int),
    .qsfpddb_mac_5_tx_ptp_time(qsfpddb_mac_5_tx_ptp_time_int),

    .qsfpddb_mac_5_tx_ptp_ts(qsfpddb_mac_5_tx_ptp_ts_int),
    .qsfpddb_mac_5_tx_ptp_ts_tag(qsfpddb_mac_5_tx_ptp_ts_tag_int),
    .qsfpddb_mac_5_tx_ptp_ts_valid(qsfpddb_mac_5_tx_ptp_ts_valid_int),

    .qsfpddb_mac_5_tx_axis_tdata(qsfpddb_mac_5_tx_axis_tdata_int),
    .qsfpddb_mac_5_tx_axis_tkeep(qsfpddb_mac_5_tx_axis_tkeep_int),
    .qsfpddb_mac_5_tx_axis_tvalid(qsfpddb_mac_5_tx_axis_tvalid_int),
    .qsfpddb_mac_5_tx_axis_tready(qsfpddb_mac_5_tx_axis_tready_int),
    .qsfpddb_mac_5_tx_axis_tlast(qsfpddb_mac_5_tx_axis_tlast_int),
    .qsfpddb_mac_5_tx_axis_tuser(qsfpddb_mac_5_tx_axis_tuser_int),

    .qsfpddb_mac_5_rx_clk(qsfpddb_mac_5_rx_clk_int),
    .qsfpddb_mac_5_rx_rst(qsfpddb_mac_5_rx_rst_int),

    .qsfpddb_mac_5_rx_ptp_clk(qsfpddb_mac_5_rx_ptp_clk_int),
    .qsfpddb_mac_5_rx_ptp_rst(qsfpddb_mac_5_rx_ptp_rst_int),
    .qsfpddb_mac_5_rx_ptp_time(qsfpddb_mac_5_rx_ptp_time_int),

    .qsfpddb_mac_5_rx_axis_tdata(qsfpddb_mac_5_rx_axis_tdata_int),
    .qsfpddb_mac_5_rx_axis_tkeep(qsfpddb_mac_5_rx_axis_tkeep_int),
    .qsfpddb_mac_5_rx_axis_tvalid(qsfpddb_mac_5_rx_axis_tvalid_int),
    .qsfpddb_mac_5_rx_axis_tlast(qsfpddb_mac_5_rx_axis_tlast_int),
    .qsfpddb_mac_5_rx_axis_tuser(qsfpddb_mac_5_rx_axis_tuser_int),

    .qsfpddb_mac_5_rx_status(qsfpddb_mac_5_rx_status_int),

    .qsfpddb_mac_6_tx_clk(qsfpddb_mac_6_tx_clk_int),
    .qsfpddb_mac_6_tx_rst(qsfpddb_mac_6_tx_rst_int),

    .qsfpddb_mac_6_tx_ptp_clk(qsfpddb_mac_6_tx_ptp_clk_int),
    .qsfpddb_mac_6_tx_ptp_rst(qsfpddb_mac_6_tx_ptp_rst_int),
    .qsfpddb_mac_6_tx_ptp_time(qsfpddb_mac_6_tx_ptp_time_int),

    .qsfpddb_mac_6_tx_ptp_ts(qsfpddb_mac_6_tx_ptp_ts_int),
    .qsfpddb_mac_6_tx_ptp_ts_tag(qsfpddb_mac_6_tx_ptp_ts_tag_int),
    .qsfpddb_mac_6_tx_ptp_ts_valid(qsfpddb_mac_6_tx_ptp_ts_valid_int),

    .qsfpddb_mac_6_tx_axis_tdata(qsfpddb_mac_6_tx_axis_tdata_int),
    .qsfpddb_mac_6_tx_axis_tkeep(qsfpddb_mac_6_tx_axis_tkeep_int),
    .qsfpddb_mac_6_tx_axis_tvalid(qsfpddb_mac_6_tx_axis_tvalid_int),
    .qsfpddb_mac_6_tx_axis_tready(qsfpddb_mac_6_tx_axis_tready_int),
    .qsfpddb_mac_6_tx_axis_tlast(qsfpddb_mac_6_tx_axis_tlast_int),
    .qsfpddb_mac_6_tx_axis_tuser(qsfpddb_mac_6_tx_axis_tuser_int),

    .qsfpddb_mac_6_rx_clk(qsfpddb_mac_6_rx_clk_int),
    .qsfpddb_mac_6_rx_rst(qsfpddb_mac_6_rx_rst_int),

    .qsfpddb_mac_6_rx_ptp_clk(qsfpddb_mac_6_rx_ptp_clk_int),
    .qsfpddb_mac_6_rx_ptp_rst(qsfpddb_mac_6_rx_ptp_rst_int),
    .qsfpddb_mac_6_rx_ptp_time(qsfpddb_mac_6_rx_ptp_time_int),

    .qsfpddb_mac_6_rx_axis_tdata(qsfpddb_mac_6_rx_axis_tdata_int),
    .qsfpddb_mac_6_rx_axis_tkeep(qsfpddb_mac_6_rx_axis_tkeep_int),
    .qsfpddb_mac_6_rx_axis_tvalid(qsfpddb_mac_6_rx_axis_tvalid_int),
    .qsfpddb_mac_6_rx_axis_tlast(qsfpddb_mac_6_rx_axis_tlast_int),
    .qsfpddb_mac_6_rx_axis_tuser(qsfpddb_mac_6_rx_axis_tuser_int),

    .qsfpddb_mac_6_rx_status(qsfpddb_mac_6_rx_status_int),

    .qsfpddb_mac_7_tx_clk(qsfpddb_mac_7_tx_clk_int),
    .qsfpddb_mac_7_tx_rst(qsfpddb_mac_7_tx_rst_int),

    .qsfpddb_mac_7_tx_ptp_clk(qsfpddb_mac_7_tx_ptp_clk_int),
    .qsfpddb_mac_7_tx_ptp_rst(qsfpddb_mac_7_tx_ptp_rst_int),
    .qsfpddb_mac_7_tx_ptp_time(qsfpddb_mac_7_tx_ptp_time_int),

    .qsfpddb_mac_7_tx_ptp_ts(qsfpddb_mac_7_tx_ptp_ts_int),
    .qsfpddb_mac_7_tx_ptp_ts_tag(qsfpddb_mac_7_tx_ptp_ts_tag_int),
    .qsfpddb_mac_7_tx_ptp_ts_valid(qsfpddb_mac_7_tx_ptp_ts_valid_int),

    .qsfpddb_mac_7_tx_axis_tdata(qsfpddb_mac_7_tx_axis_tdata_int),
    .qsfpddb_mac_7_tx_axis_tkeep(qsfpddb_mac_7_tx_axis_tkeep_int),
    .qsfpddb_mac_7_tx_axis_tvalid(qsfpddb_mac_7_tx_axis_tvalid_int),
    .qsfpddb_mac_7_tx_axis_tready(qsfpddb_mac_7_tx_axis_tready_int),
    .qsfpddb_mac_7_tx_axis_tlast(qsfpddb_mac_7_tx_axis_tlast_int),
    .qsfpddb_mac_7_tx_axis_tuser(qsfpddb_mac_7_tx_axis_tuser_int),

    .qsfpddb_mac_7_rx_clk(qsfpddb_mac_7_rx_clk_int),
    .qsfpddb_mac_7_rx_rst(qsfpddb_mac_7_rx_rst_int),

    .qsfpddb_mac_7_rx_ptp_clk(qsfpddb_mac_7_rx_ptp_clk_int),
    .qsfpddb_mac_7_rx_ptp_rst(qsfpddb_mac_7_rx_ptp_rst_int),
    .qsfpddb_mac_7_rx_ptp_time(qsfpddb_mac_7_rx_ptp_time_int),

    .qsfpddb_mac_7_rx_axis_tdata(qsfpddb_mac_7_rx_axis_tdata_int),
    .qsfpddb_mac_7_rx_axis_tkeep(qsfpddb_mac_7_rx_axis_tkeep_int),
    .qsfpddb_mac_7_rx_axis_tvalid(qsfpddb_mac_7_rx_axis_tvalid_int),
    .qsfpddb_mac_7_rx_axis_tlast(qsfpddb_mac_7_rx_axis_tlast_int),
    .qsfpddb_mac_7_rx_axis_tuser(qsfpddb_mac_7_rx_axis_tuser_int),

    .qsfpddb_mac_7_rx_status(qsfpddb_mac_7_rx_status_int),

    .qsfpddb_mac_8_tx_clk(qsfpddb_mac_8_tx_clk_int),
    .qsfpddb_mac_8_tx_rst(qsfpddb_mac_8_tx_rst_int),

    .qsfpddb_mac_8_tx_ptp_clk(qsfpddb_mac_8_tx_ptp_clk_int),
    .qsfpddb_mac_8_tx_ptp_rst(qsfpddb_mac_8_tx_ptp_rst_int),
    .qsfpddb_mac_8_tx_ptp_time(qsfpddb_mac_8_tx_ptp_time_int),

    .qsfpddb_mac_8_tx_ptp_ts(qsfpddb_mac_8_tx_ptp_ts_int),
    .qsfpddb_mac_8_tx_ptp_ts_tag(qsfpddb_mac_8_tx_ptp_ts_tag_int),
    .qsfpddb_mac_8_tx_ptp_ts_valid(qsfpddb_mac_8_tx_ptp_ts_valid_int),

    .qsfpddb_mac_8_tx_axis_tdata(qsfpddb_mac_8_tx_axis_tdata_int),
    .qsfpddb_mac_8_tx_axis_tkeep(qsfpddb_mac_8_tx_axis_tkeep_int),
    .qsfpddb_mac_8_tx_axis_tvalid(qsfpddb_mac_8_tx_axis_tvalid_int),
    .qsfpddb_mac_8_tx_axis_tready(qsfpddb_mac_8_tx_axis_tready_int),
    .qsfpddb_mac_8_tx_axis_tlast(qsfpddb_mac_8_tx_axis_tlast_int),
    .qsfpddb_mac_8_tx_axis_tuser(qsfpddb_mac_8_tx_axis_tuser_int),

    .qsfpddb_mac_8_rx_clk(qsfpddb_mac_8_rx_clk_int),
    .qsfpddb_mac_8_rx_rst(qsfpddb_mac_8_rx_rst_int),

    .qsfpddb_mac_8_rx_ptp_clk(qsfpddb_mac_8_rx_ptp_clk_int),
    .qsfpddb_mac_8_rx_ptp_rst(qsfpddb_mac_8_rx_ptp_rst_int),
    .qsfpddb_mac_8_rx_ptp_time(qsfpddb_mac_8_rx_ptp_time_int),

    .qsfpddb_mac_8_rx_axis_tdata(qsfpddb_mac_8_rx_axis_tdata_int),
    .qsfpddb_mac_8_rx_axis_tkeep(qsfpddb_mac_8_rx_axis_tkeep_int),
    .qsfpddb_mac_8_rx_axis_tvalid(qsfpddb_mac_8_rx_axis_tvalid_int),
    .qsfpddb_mac_8_rx_axis_tlast(qsfpddb_mac_8_rx_axis_tlast_int),
    .qsfpddb_mac_8_rx_axis_tuser(qsfpddb_mac_8_rx_axis_tuser_int),

    .qsfpddb_mac_8_rx_status(qsfpddb_mac_8_rx_status_int),

    .qsfpddb_initmode(qsfpddb_initmode),
    .qsfpddb_interrupt_n(qsfpddb_interrupt_n_int),
    .qsfpddb_mod_prs_n(qsfpddb_mod_prs_n_int),
    .qsfpddb_mod_sel_n(qsfpddb_mod_sel_n),
    .qsfpddb_rst_n(qsfpddb_rst_n),
    .qsfpddb_scl_i(qsfpddb_scl_i),
    .qsfpddb_scl_o(qsfpddb_scl_o),
    .qsfpddb_scl_t(qsfpddb_scl_t),
    .qsfpddb_sda_i(qsfpddb_sda_i),
    .qsfpddb_sda_o(qsfpddb_sda_o),
    .qsfpddb_sda_t(qsfpddb_sda_t)
);

endmodule

`resetall
