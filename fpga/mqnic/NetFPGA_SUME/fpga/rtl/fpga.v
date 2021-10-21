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
    parameter BOARD_ID = {16'h10ee, 16'h7028},
    parameter BOARD_VER = {16'd0, 16'd1},
    parameter FPGA_ID = 32'h3691093,

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
    parameter TX_QUEUE_INDEX_WIDTH = 9,
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
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    parameter AXIS_PCIE_RC_USER_WIDTH = 75,
    parameter AXIS_PCIE_RQ_USER_WIDTH = 60,
    parameter AXIS_PCIE_CQ_USER_WIDTH = 85,
    parameter AXIS_PCIE_CC_USER_WIDTH = 33,
    parameter RQ_SEQ_NUM_WIDTH = 4,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 64,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 8,
    parameter PCIE_DMA_READ_TX_FC_ENABLE = 1,
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 8,
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
    parameter STAT_ID_WIDTH = 10
)
(
    /*
     * Clock: 200MHz LVDS
     * Reset: Push button, active low
     */
    input  wire         clk_200mhz_p,
    input  wire         clk_200mhz_n,

    /*
     * GPIO
     */
    input  wire [1:0]   btn,
    output wire [1:0]   sfp_1_led,
    output wire [1:0]   sfp_2_led,
    output wire [1:0]   sfp_3_led,
    output wire [1:0]   sfp_4_led,
    output wire [1:0]   led,

    /*
     * I2C
     */
    inout  wire         i2c_scl,
    inout  wire         i2c_sda,
    output wire         i2c_mux_reset,

    /*
     * PCI express
     */
    input  wire [7:0]   pcie_rx_p,
    input  wire [7:0]   pcie_rx_n,
    output wire [7:0]   pcie_tx_p,
    output wire [7:0]   pcie_tx_n,
    input  wire         pcie_mgt_refclk_p,
    input  wire         pcie_mgt_refclk_n,
    input  wire         pcie_reset_n,

    /*
     * Ethernet: SFP+
     */
    input  wire         sfp_1_rx_p,
    input  wire         sfp_1_rx_n,
    output wire         sfp_1_tx_p,
    output wire         sfp_1_tx_n,
    input  wire         sfp_2_rx_p,
    input  wire         sfp_2_rx_n,
    output wire         sfp_2_tx_p,
    output wire         sfp_2_tx_n,
    input  wire         sfp_3_rx_p,
    input  wire         sfp_3_rx_n,
    output wire         sfp_3_tx_p,
    output wire         sfp_3_tx_n,
    input  wire         sfp_4_rx_p,
    input  wire         sfp_4_rx_n,
    output wire         sfp_4_tx_p,
    output wire         sfp_4_tx_n,
    input  wire         sfp_mgt_refclk_p,
    input  wire         sfp_mgt_refclk_n,
    output wire         sfp_clk_rst,
    input  wire         sfp_1_mod_detect,
    input  wire         sfp_2_mod_detect,
    input  wire         sfp_3_mod_detect,
    input  wire         sfp_4_mod_detect,
    output wire [1:0]   sfp_1_rs,
    output wire [1:0]   sfp_2_rs,
    output wire [1:0]   sfp_3_rs,
    output wire [1:0]   sfp_4_rs,
    input  wire         sfp_1_los,
    input  wire         sfp_2_los,
    input  wire         sfp_3_los,
    input  wire         sfp_4_los,
    output wire         sfp_1_tx_disable,
    output wire         sfp_2_tx_disable,
    output wire         sfp_3_tx_disable,
    output wire         sfp_4_tx_disable,
    input  wire         sfp_1_tx_fault,
    input  wire         sfp_2_tx_fault,
    input  wire         sfp_3_tx_fault,
    input  wire         sfp_4_tx_fault
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

// PCIe interface configuration
parameter MSI_COUNT = 32;

// Ethernet interface configuration
parameter XGMII_DATA_WIDTH = 64;
parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8;
parameter AXIS_ETH_DATA_WIDTH = XGMII_DATA_WIDTH;
parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8;
parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH;
parameter AXIS_ETH_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1;
parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

// Clock and reset
wire pcie_user_clk;
wire pcie_user_reset;

wire clk_200mhz_ibufg;
wire clk_125mhz_mmcm_out;

// Internal 125 MHz clock
wire clk_125mhz_int;
wire rst_125mhz_int;

// Internal 156.25 MHz clock
wire clk_156mhz_int;
wire rst_156mhz_int;

wire mmcm_rst = 1'b0;
wire mmcm_locked;
wire mmcm_clkfb;

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")   
)
clk_200mhz_ibufg_inst (
   .O   (clk_200mhz_ibufg),
   .I   (clk_200mhz_p),
   .IB  (clk_200mhz_n) 
);

// MMCM instance
// 200 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 600 MHz to 1440 MHz
// M = 5, D = 1 sets Fvco = 1000 MHz (in range)
// Divide by 8 to get output frequency of 125 MHz
MMCME2_BASE #(
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
    .CLKFBOUT_MULT_F(5),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(5.0),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_200mhz_ibufg),
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
wire [1:0] btn_int;
wire [1:0] sfp_1_led_int;
wire [1:0] sfp_2_led_int;
wire [1:0] sfp_3_led_int;
wire [1:0] sfp_4_led_int;
wire [1:0] led_int;

debounce_switch #(
    .WIDTH(2),
    .N(4),
    .RATE(250000)
)
debounce_switch_inst (
    .clk(pcie_user_clk),
    .rst(pcie_user_reset),
    .in({btn}),
    .out({btn_int})
);

// I2C
wire i2c_scl_i;
wire i2c_scl_o;
wire i2c_scl_t;
wire i2c_sda_i;
wire i2c_sda_o;
wire i2c_sda_t;

wire i2c_scl_i_init;
wire i2c_scl_o_init;
wire i2c_scl_t_init;
wire i2c_sda_i_init;
wire i2c_sda_o_init;
wire i2c_sda_t_init;

wire i2c_scl_i_int;
wire i2c_scl_o_int;
wire i2c_scl_t_int;
wire i2c_sda_i_int;
wire i2c_sda_o_int;
wire i2c_sda_t_int;

reg i2c_scl_o_reg;
reg i2c_scl_t_reg;
reg i2c_sda_o_reg;
reg i2c_sda_t_reg;

always @(posedge pcie_user_clk) begin
    i2c_scl_o_reg <= i2c_scl_o_int;
    i2c_scl_t_reg <= i2c_scl_t_int;
    i2c_sda_o_reg <= i2c_sda_o_int;
    i2c_sda_t_reg <= i2c_sda_t_int;
end

wire sfp_1_mod_detect_int;
wire sfp_2_mod_detect_int;
wire sfp_3_mod_detect_int;
wire sfp_4_mod_detect_int;

wire sfp_1_los_int;
wire sfp_2_los_int;
wire sfp_3_los_int;
wire sfp_4_los_int;

wire sfp_1_tx_fault_int;
wire sfp_2_tx_fault_int;
wire sfp_3_tx_fault_int;
wire sfp_4_tx_fault_int;

sync_signal #(
    .WIDTH(14),
    .N(2)
)
sync_signal_inst (
    .clk(pcie_user_clk),
    .in({sfp_1_mod_detect, sfp_2_mod_detect, sfp_3_mod_detect, sfp_4_mod_detect,
        sfp_1_los, sfp_2_los, sfp_3_los, sfp_4_los,
        sfp_1_tx_fault, sfp_2_tx_fault, sfp_3_tx_fault, sfp_4_tx_fault,
        i2c_scl_i, i2c_sda_i}),
    .out({sfp_1_mod_detect_int, sfp_2_mod_detect_int, sfp_3_mod_detect_int, sfp_4_mod_detect_int,
        sfp_1_los_int, sfp_2_los_int, sfp_3_los_int, sfp_4_los_int,
        sfp_1_tx_fault_int, sfp_2_tx_fault_int, sfp_3_tx_fault_int, sfp_4_tx_fault_int,
        i2c_scl_i_int, i2c_sda_i_int})
);

assign i2c_scl_i = i2c_scl;
assign i2c_scl = i2c_scl_t ? 1'bz : i2c_scl_o;
assign i2c_sda_i = i2c_sda;
assign i2c_sda = i2c_sda_t ? 1'bz : i2c_sda_o;

assign i2c_scl_o = i2c_scl_o_init && i2c_scl_o_reg;
assign i2c_scl_t = i2c_scl_t_init && i2c_scl_t_reg;
assign i2c_sda_o = i2c_sda_o_init && i2c_sda_o_reg;
assign i2c_sda_t = i2c_sda_t_init && i2c_sda_t_reg;

assign i2c_scl_i_init = i2c_scl_i;
assign i2c_sda_i_init = i2c_sda_i;

wire [6:0] si5324_i2c_cmd_address;
wire si5324_i2c_cmd_start;
wire si5324_i2c_cmd_read;
wire si5324_i2c_cmd_write;
wire si5324_i2c_cmd_write_multiple;
wire si5324_i2c_cmd_stop;
wire si5324_i2c_cmd_valid;
wire si5324_i2c_cmd_ready;

wire [7:0] si5324_i2c_data;
wire si5324_i2c_data_valid;
wire si5324_i2c_data_ready;
wire si5324_i2c_data_last;

wire si5324_i2c_init_busy;

assign i2c_mux_reset = rst_125mhz_int;
assign sfp_clk_rst = rst_125mhz_int;

// delay start by ~10 ms
reg [20:0] si5324_i2c_init_start_delay = 21'd0;

always @(posedge clk_125mhz_int) begin
    if (rst_125mhz_int) begin
        si5324_i2c_init_start_delay <= 21'd0;
    end else begin
        if (!si5324_i2c_init_start_delay[20]) begin
            si5324_i2c_init_start_delay <= si5324_i2c_init_start_delay + 21'd1;
        end
    end
end

si5324_i2c_init
si5324_i2c_init_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),
    .cmd_address(si5324_i2c_cmd_address),
    .cmd_start(si5324_i2c_cmd_start),
    .cmd_read(si5324_i2c_cmd_read),
    .cmd_write(si5324_i2c_cmd_write),
    .cmd_write_multiple(si5324_i2c_cmd_write_multiple),
    .cmd_stop(si5324_i2c_cmd_stop),
    .cmd_valid(si5324_i2c_cmd_valid),
    .cmd_ready(si5324_i2c_cmd_ready),
    .data_out(si5324_i2c_data),
    .data_out_valid(si5324_i2c_data_valid),
    .data_out_ready(si5324_i2c_data_ready),
    .data_out_last(si5324_i2c_data_last),
    .busy(si5324_i2c_init_busy),
    .start(si5324_i2c_init_start_delay[20])
);

i2c_master
si5324_i2c_master_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),
    .cmd_address(si5324_i2c_cmd_address),
    .cmd_start(si5324_i2c_cmd_start),
    .cmd_read(si5324_i2c_cmd_read),
    .cmd_write(si5324_i2c_cmd_write),
    .cmd_write_multiple(si5324_i2c_cmd_write_multiple),
    .cmd_stop(si5324_i2c_cmd_stop),
    .cmd_valid(si5324_i2c_cmd_valid),
    .cmd_ready(si5324_i2c_cmd_ready),
    .data_in(si5324_i2c_data),
    .data_in_valid(si5324_i2c_data_valid),
    .data_in_ready(si5324_i2c_data_ready),
    .data_in_last(si5324_i2c_data_last),
    .data_out(),
    .data_out_valid(),
    .data_out_ready(1),
    .data_out_last(),
    .scl_i(i2c_scl_i_init),
    .scl_o(i2c_scl_o_init),
    .scl_t(i2c_scl_t_init),
    .sda_i(i2c_sda_i_init),
    .sda_o(i2c_sda_o_init),
    .sda_t(i2c_sda_t_init),
    .busy(),
    .bus_control(),
    .bus_active(),
    .missed_ack(),
    .prescale(312),
    .stop_on_idle(1)
);

// PCIe
wire pcie_sys_clk;

IBUFDS_GTE2
ibufds_gte2_pcie_mgt_refclk_inst (
    .I             (pcie_mgt_refclk_p),
    .IB            (pcie_mgt_refclk_n),
    .CEB           (1'b0),
    .O             (pcie_sys_clk),
    .ODIV2         ()
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

wire [RQ_SEQ_NUM_WIDTH-1:0]        pcie_rq_seq_num;
wire                               pcie_rq_seq_num_vld;

wire [3:0] pcie_tfc_nph_av;
wire [3:0] pcie_tfc_npd_av;

wire [2:0] cfg_max_payload;
wire [2:0] cfg_max_read_req;

wire [18:0] cfg_mgmt_addr;
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

wire [1:0]  cfg_interrupt_msi_enable;
wire [5:0]  cfg_interrupt_msi_vf_enable;
wire [5:0]  cfg_interrupt_msi_mmenable;
wire        cfg_interrupt_msi_mask_update;
wire [31:0] cfg_interrupt_msi_data;
wire [3:0]  cfg_interrupt_msi_select;
wire [31:0] cfg_interrupt_msi_int;
wire [63:0] cfg_interrupt_msi_pending_status;
wire        cfg_interrupt_msi_sent;
wire        cfg_interrupt_msi_fail;
wire [2:0]  cfg_interrupt_msi_attr;
wire        cfg_interrupt_msi_tph_present;
wire [1:0]  cfg_interrupt_msi_tph_type;
wire [8:0]  cfg_interrupt_msi_tph_st_tag;
wire [2:0]  cfg_interrupt_msi_function_number;

wire status_error_cor;
wire status_error_uncor;

wire pcie_pipe_txoutclk;
wire [7:0] pcie_pipe_rxoutclk;
wire [7:0] pcie_pipe_pclk_sel;

wire pcie_pipe_clk_125mhz_mmcm_out;
wire pcie_pipe_clk_250mhz_mmcm_out;
wire pcie_pipe_userclk1_mmcm_out;
wire pcie_pipe_userclk2_mmcm_out;

wire pcie_pipe_pclk;
wire pcie_pipe_dclk;
wire pcie_pipe_userclk1;
wire pcie_pipe_userclk2;

wire pcie_pipe_mmcm_rst;
wire pcie_pipe_mmcm_locked;

wire pcie_pipe_mmcm_clkfb;

// MMCM instance
// 100 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 600 MHz to 1440 MHz
// M = 10, D = 1 sets Fvco = 1000 MHz (in range)
// Divide by 8 to get output frequency of 125 MHz (pcie_pipe_clk_125mhz)
// Divide by 4 to get output frequency of 250 MHz (pcie_pipe_clk_250mhz)
// Divide by 2 to get output frequency of 500 MHz (pcie_pipe_userclk1)
// Divide by 4 to get output frequency of 250 MHz (pcie_pipe_userclk2)
MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(8),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(4),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0),
    .CLKOUT2_DIVIDE(2),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),
    .CLKOUT3_DIVIDE(4),
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
    .CLKIN1_PERIOD(10.0),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
pcie_pipe_mmcm_inst (
    .CLKIN1(pcie_pipe_txoutclk),
    .CLKFBIN(pcie_pipe_mmcm_clkfb),
    .RST(pcie_pipe_mmcm_rst),
    .PWRDWN(1'b0),
    .CLKOUT0(pcie_pipe_clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    .CLKOUT1(pcie_pipe_clk_250mhz_mmcm_out),
    .CLKOUT1B(),
    .CLKOUT2(pcie_pipe_userclk1_mmcm_out),
    .CLKOUT2B(),
    .CLKOUT3(pcie_pipe_userclk2_mmcm_out),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(pcie_pipe_mmcm_clkfb),
    .CLKFBOUTB(),
    .LOCKED(pcie_pipe_mmcm_locked)
);

(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *)
reg [7:0] pcie_pipe_pclk_sel_reg_1 = 8'd0;
(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *)
reg [7:0] pcie_pipe_pclk_sel_reg_2 = 8'd0;

reg pcie_pipe_pclk_sel_reg = 1'b0;

always @ (posedge pcie_pipe_pclk) begin
    if (pcie_pipe_mmcm_rst) begin
        pcie_pipe_pclk_sel_reg_1 <= 8'd0;
        pcie_pipe_pclk_sel_reg_2 <= 8'd0;
    end else begin  
        pcie_pipe_pclk_sel_reg_1 <= pcie_pipe_pclk_sel;
        pcie_pipe_pclk_sel_reg_2 <= pcie_pipe_pclk_sel_reg_1;
    end
end

always @ (posedge pcie_pipe_pclk) begin
    if (pcie_pipe_mmcm_rst) begin
        pcie_pipe_pclk_sel_reg <= 1'b0;
    end else begin 
        if (&pcie_pipe_pclk_sel_reg_2) begin
            pcie_pipe_pclk_sel_reg <= 1'b1;
        end else if (&(~pcie_pipe_pclk_sel_reg_2)) begin
            pcie_pipe_pclk_sel_reg <= 1'b0;  
        end else begin
            pcie_pipe_pclk_sel_reg <= pcie_pipe_pclk_sel_reg;
        end
    end
end

BUFGCTRL pcie_pipe_pclk_bufgctrl_inst (
    .CE0(1'b1),
    .CE1(1'b1),
    .I0(pcie_pipe_clk_125mhz_mmcm_out),
    .I1(pcie_pipe_clk_250mhz_mmcm_out),
    .IGNORE0(1'b0),
    .IGNORE1(1'b0),
    .S0(!pcie_pipe_pclk_sel_reg),
    .S1(pcie_pipe_pclk_sel_reg),
    .O(pcie_pipe_pclk)
);

BUFG pcie_pipe_dclk_bufg_inst (
    .I(pcie_pipe_clk_125mhz_mmcm_out),
    .O(pcie_pipe_dclk)
);

BUFG pcie_usrclk1_bufg_inst (
    .I(pcie_pipe_userclk1_mmcm_out),
    .O(pcie_pipe_userclk1)
);

BUFG pcie_usrclk2_bufg_inst (
    .I(pcie_pipe_userclk2_mmcm_out),
    .O(pcie_pipe_userclk2)
);

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

pcie3_7x_0
pcie3_7x_inst (
    .pci_exp_txn(pcie_tx_n),
    .pci_exp_txp(pcie_tx_p),
    .pci_exp_rxn(pcie_rx_n),
    .pci_exp_rxp(pcie_rx_p),

    .pipe_pclk_in(pcie_pipe_pclk),
    .pipe_rxusrclk_in(pcie_pipe_pclk),
    .pipe_rxoutclk_in(8'd0),
    .pipe_dclk_in(pcie_pipe_dclk),
    .pipe_userclk1_in(pcie_pipe_userclk1),
    .pipe_userclk2_in(pcie_pipe_userclk2),
    .pipe_oobclk_in(pcie_pipe_pclk),
    .pipe_mmcm_lock_in(pcie_pipe_mmcm_locked),
    .pipe_txoutclk_out(pcie_pipe_txoutclk),
    .pipe_rxoutclk_out(pcie_pipe_rxoutclk),
    .pipe_pclk_sel_out(pcie_pipe_pclk_sel),
    .pipe_gen3_out(),
    .pipe_mmcm_rst_n(1'b1),

    .mmcm_lock(),
    .user_clk(pcie_user_clk),
    .user_reset(pcie_user_reset_int),
    .user_lnk_up(),
    .user_app_rdy(),

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

    .pcie_rq_seq_num(pcie_rq_seq_num),
    .pcie_rq_seq_num_vld(pcie_rq_seq_num_vld),
    .pcie_rq_tag(),
    .pcie_rq_tag_vld(),

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
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),
    .cfg_mgmt_type1_cfg_reg_access(1'b0),

    .cfg_err_cor_out(),
    .cfg_err_nonfatal_out(),
    .cfg_err_fatal_out(),
    .cfg_ltr_enable(),
    .cfg_ltssm_state(),
    .cfg_rcb_status(),
    .cfg_dpa_substate_change(),
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

    .cfg_per_func_status_control(3'd0),
    .cfg_per_func_status_data(),
    .cfg_per_function_number(4'd0),
    .cfg_per_function_output_request(1'b0),
    .cfg_per_function_update_done(),

    .cfg_dsn(64'd0),

    .cfg_power_state_change_ack(1'b1),
    .cfg_power_state_change_interrupt(),

    .cfg_err_cor_in(status_error_cor),
    .cfg_err_uncor_in(status_error_uncor),
    .cfg_flr_in_process(),
    .cfg_flr_done(4'd0),
    .cfg_vf_flr_in_process(),
    .cfg_vf_flr_done(8'd0),

    .cfg_link_training_enable(1'b1),

    .cfg_interrupt_int(4'd0),
    .cfg_interrupt_pending(4'd0),
    .cfg_interrupt_sent(),
    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_vf_enable(cfg_interrupt_msi_vf_enable),
    .cfg_interrupt_msi_mmenable(cfg_interrupt_msi_mmenable),
    .cfg_interrupt_msi_mask_update(cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_data(cfg_interrupt_msi_data),
    .cfg_interrupt_msi_select(cfg_interrupt_msi_select),
    .cfg_interrupt_msi_int(cfg_interrupt_msi_int),
    .cfg_interrupt_msi_pending_status(cfg_interrupt_msi_pending_status),
    .cfg_interrupt_msi_sent(cfg_interrupt_msi_sent),
    .cfg_interrupt_msi_fail(cfg_interrupt_msi_fail),
    .cfg_interrupt_msi_attr(cfg_interrupt_msi_attr),
    .cfg_interrupt_msi_tph_present(cfg_interrupt_msi_tph_present),
    .cfg_interrupt_msi_tph_type(cfg_interrupt_msi_tph_type),
    .cfg_interrupt_msi_tph_st_tag(cfg_interrupt_msi_tph_st_tag),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    .cfg_hot_reset_out(),

    .cfg_config_space_enable(1'b1),
    .cfg_req_pm_transition_l23_ready(1'b0),
    .cfg_hot_reset_in(1'b0),

    .cfg_ds_port_number(8'd0),
    .cfg_ds_bus_number(8'd0),
    .cfg_ds_device_number(5'd0),
    .cfg_ds_function_number(3'd0),

    .cfg_subsys_vend_id(16'h1234),

    .sys_clk(pcie_sys_clk),
    .sys_reset(!pcie_reset_n)
);

// XGMII 10G PHY
wire                         sfp_1_tx_clk_int = clk_156mhz_int;
wire                         sfp_1_tx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_1_txd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_1_txc_int;
wire                         sfp_1_rx_clk_int = clk_156mhz_int;
wire                         sfp_1_rx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_1_rxd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_1_rxc_int;
wire                         sfp_2_tx_clk_int = clk_156mhz_int;
wire                         sfp_2_tx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_2_txd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_2_txc_int;
wire                         sfp_2_rx_clk_int = clk_156mhz_int;
wire                         sfp_2_rx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_2_rxd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_2_rxc_int;
wire                         sfp_3_tx_clk_int = clk_156mhz_int;
wire                         sfp_3_tx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_3_txd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_3_txc_int;
wire                         sfp_3_rx_clk_int = clk_156mhz_int;
wire                         sfp_3_rx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_3_rxd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_3_rxc_int;
wire                         sfp_4_tx_clk_int = clk_156mhz_int;
wire                         sfp_4_tx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_4_txd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_4_txc_int;
wire                         sfp_4_rx_clk_int = clk_156mhz_int;
wire                         sfp_4_rx_rst_int = rst_156mhz_int;
wire [XGMII_DATA_WIDTH-1:0]  sfp_4_rxd_int;
wire [XGMII_CTRL_WIDTH-1:0]  sfp_4_rxc_int;

wire sfp_reset_in;
wire sfp_txusrclk;
wire sfp_txusrclk2;
wire sfp_coreclk;
wire sfp_qplloutclk;
wire sfp_qplloutrefclk;
wire sfp_qplllock;
wire sfp_gttxreset;
wire sfp_gtrxreset;
wire sfp_txuserrdy;
wire sfp_areset_datapathclk;
wire sfp_resetdone;
wire sfp_reset_counter_done;

sync_reset #(
    .N(4)
)
sync_reset_sfp_inst (
    .clk(sfp_coreclk),
    .rst(rst_125mhz_int || si5324_i2c_init_busy || pcie_user_reset),
    .out(sfp_reset_in)
);

assign clk_156mhz_int = sfp_coreclk;

sync_reset #(
    .N(4)
)
sync_reset_156mhz_inst (
    .clk(clk_156mhz_int),
    .rst(!sfp_resetdone),
    .out(rst_156mhz_int)
);

wire [535:0] sfp_config_vector;

assign sfp_config_vector[14:1]    = 0;
assign sfp_config_vector[79:17]   = 0;
assign sfp_config_vector[109:84]  = 0;
assign sfp_config_vector[175:170] = 0;
assign sfp_config_vector[239:234] = 0;
assign sfp_config_vector[269:246] = 0;
assign sfp_config_vector[511:272] = 0;
assign sfp_config_vector[515:513] = 0;
assign sfp_config_vector[517:517] = 0;
assign sfp_config_vector[0]       = 0; // pma_loopback;
assign sfp_config_vector[15]      = 0; // pma_reset;
assign sfp_config_vector[16]      = 0; // global_tx_disable;
assign sfp_config_vector[83:80]   = 0; // pma_vs_loopback;
assign sfp_config_vector[110]     = 0; // pcs_loopback;
assign sfp_config_vector[111]     = 0; // pcs_reset;
assign sfp_config_vector[169:112] = 0; // test_patt_a;
assign sfp_config_vector[233:176] = 0; // test_patt_b;
assign sfp_config_vector[240]     = 0; // data_patt_sel;
assign sfp_config_vector[241]     = 0; // test_patt_sel;
assign sfp_config_vector[242]     = 0; // rx_test_patt_en;
assign sfp_config_vector[243]     = 0; // tx_test_patt_en;
assign sfp_config_vector[244]     = 0; // prbs31_tx_en;
assign sfp_config_vector[245]     = 0; // prbs31_rx_en;
assign sfp_config_vector[271:270] = 0; // pcs_vs_loopback;
assign sfp_config_vector[512]     = 0; // set_pma_link_status;
assign sfp_config_vector[516]     = 0; // set_pcs_link_status;
assign sfp_config_vector[518]     = 0; // clear_pcs_status2;
assign sfp_config_vector[519]     = 0; // clear_test_patt_err_count;
assign sfp_config_vector[535:520] = 0;

wire [447:0] sfp_1_status_vector;
wire [447:0] sfp_2_status_vector;
wire [447:0] sfp_3_status_vector;
wire [447:0] sfp_4_status_vector;

wire sfp_1_rx_block_lock = sfp_1_status_vector[256];
wire sfp_2_rx_block_lock = sfp_2_status_vector[256];
wire sfp_3_rx_block_lock = sfp_3_status_vector[256];
wire sfp_4_rx_block_lock = sfp_4_status_vector[256];

wire [7:0] sfp_1_core_status;
wire [7:0] sfp_2_core_status;
wire [7:0] sfp_3_core_status;
wire [7:0] sfp_4_core_status;

ten_gig_eth_pcs_pma_0
sfp_1_pcs_pma_inst (
    .dclk(clk_125mhz_int),
    .rxrecclk_out(),
    .refclk_p(sfp_mgt_refclk_p),
    .refclk_n(sfp_mgt_refclk_n),
    .sim_speedup_control(1'b0),
    .coreclk_out(sfp_coreclk),
    .qplloutclk_out(sfp_qplloutclk),
    .qplloutrefclk_out(sfp_qplloutrefclk),
    .qplllock_out(sfp_qplllock),
    .txusrclk_out(sfp_txusrclk),
    .txusrclk2_out(sfp_txusrclk2),
    .areset_datapathclk_out(sfp_areset_datapathclk),
    .gttxreset_out(sfp_gttxreset),
    .gtrxreset_out(sfp_gtrxreset),
    .txuserrdy_out(sfp_txuserrdy),
    .reset_counter_done_out(sfp_reset_counter_done),
    .reset(sfp_reset_in),
    .xgmii_txd(sfp_1_txd_int),
    .xgmii_txc(sfp_1_txc_int),
    .xgmii_rxd(sfp_1_rxd_int),
    .xgmii_rxc(sfp_1_rxc_int),
    .txp(sfp_1_tx_p),
    .txn(sfp_1_tx_n),
    .rxp(sfp_1_rx_p),
    .rxn(sfp_1_rx_n),
    .configuration_vector(sfp_config_vector),
    .status_vector(sfp_1_status_vector),
    .core_status(sfp_1_core_status),
    .resetdone_out(sfp_resetdone),
    .signal_detect(1'b1),
    .tx_fault(1'b0),
    .drp_req(),
    .drp_gnt(1'b1),
    .drp_den_o(),
    .drp_dwe_o(),
    .drp_daddr_o(),
    .drp_di_o(),
    .drp_drdy_o(),
    .drp_drpdo_o(),
    .drp_den_i(1'b0),
    .drp_dwe_i(1'b0),
    .drp_daddr_i(16'd0),
    .drp_di_i(16'd0),
    .drp_drdy_i(1'b0),
    .drp_drpdo_i(16'd0),
    .pma_pmd_type(3'd0),
    .tx_disable()
);

ten_gig_eth_pcs_pma_1
sfp_2_pcs_pma_inst (
    .dclk(clk_125mhz_int),
    .rxrecclk_out(),
    .coreclk(sfp_coreclk),
    .txusrclk(sfp_txusrclk),
    .txusrclk2(sfp_txusrclk2),
    .txoutclk(),
    .areset(sfp_reset_in),
    .areset_coreclk(sfp_areset_datapathclk),
    .gttxreset(sfp_gttxreset),
    .gtrxreset(sfp_gtrxreset),
    .sim_speedup_control(1'b0),
    .txuserrdy(sfp_txuserrdy),
    .qplllock(sfp_qplllock),
    .qplloutclk(sfp_qplloutclk),
    .qplloutrefclk(sfp_qplloutrefclk),
    .reset_counter_done(sfp_reset_counter_done),
    .xgmii_txd(sfp_2_txd_int),
    .xgmii_txc(sfp_2_txc_int),
    .xgmii_rxd(sfp_2_rxd_int),
    .xgmii_rxc(sfp_2_rxc_int),
    .txp(sfp_2_tx_p),
    .txn(sfp_2_tx_n),
    .rxp(sfp_2_rx_p),
    .rxn(sfp_2_rx_n),
    .configuration_vector(sfp_config_vector),
    .status_vector(sfp_2_status_vector),
    .core_status(sfp_2_core_status),
    .tx_resetdone(),
    .rx_resetdone(),
    .signal_detect(1'b1),
    .tx_fault(1'b0),
    .drp_req(),
    .drp_gnt(1'b1),
    .drp_den_o(),
    .drp_dwe_o(),
    .drp_daddr_o(),
    .drp_di_o(),
    .drp_drdy_o(),
    .drp_drpdo_o(),
    .drp_den_i(1'b0),
    .drp_dwe_i(1'b0),
    .drp_daddr_i(16'd0),
    .drp_di_i(16'd0),
    .drp_drdy_i(1'b0),
    .drp_drpdo_i(16'd0),
    .pma_pmd_type(3'd0),
    .tx_disable()
);

ten_gig_eth_pcs_pma_1
sfp_3_pcs_pma_inst (
    .dclk(clk_125mhz_int),
    .rxrecclk_out(),
    .coreclk(sfp_coreclk),
    .txusrclk(sfp_txusrclk),
    .txusrclk2(sfp_txusrclk2),
    .txoutclk(),
    .areset(sfp_reset_in),
    .areset_coreclk(sfp_areset_datapathclk),
    .gttxreset(sfp_gttxreset),
    .gtrxreset(sfp_gtrxreset),
    .sim_speedup_control(1'b0),
    .txuserrdy(sfp_txuserrdy),
    .qplllock(sfp_qplllock),
    .qplloutclk(sfp_qplloutclk),
    .qplloutrefclk(sfp_qplloutrefclk),
    .reset_counter_done(sfp_reset_counter_done),
    .xgmii_txd(sfp_3_txd_int),
    .xgmii_txc(sfp_3_txc_int),
    .xgmii_rxd(sfp_3_rxd_int),
    .xgmii_rxc(sfp_3_rxc_int),
    .txp(sfp_3_tx_p),
    .txn(sfp_3_tx_n),
    .rxp(sfp_3_rx_p),
    .rxn(sfp_3_rx_n),
    .configuration_vector(sfp_config_vector),
    .status_vector(sfp_3_status_vector),
    .core_status(sfp_3_core_status),
    .tx_resetdone(),
    .rx_resetdone(),
    .signal_detect(1'b1),
    .tx_fault(1'b0),
    .drp_req(),
    .drp_gnt(1'b1),
    .drp_den_o(),
    .drp_dwe_o(),
    .drp_daddr_o(),
    .drp_di_o(),
    .drp_drdy_o(),
    .drp_drpdo_o(),
    .drp_den_i(1'b0),
    .drp_dwe_i(1'b0),
    .drp_daddr_i(16'd0),
    .drp_di_i(16'd0),
    .drp_drdy_i(1'b0),
    .drp_drpdo_i(16'd0),
    .pma_pmd_type(3'd0),
    .tx_disable()
);

ten_gig_eth_pcs_pma_1
sfp_4_pcs_pma_inst (
    .dclk(clk_125mhz_int),
    .rxrecclk_out(),
    .coreclk(sfp_coreclk),
    .txusrclk(sfp_txusrclk),
    .txusrclk2(sfp_txusrclk2),
    .txoutclk(),
    .areset(sfp_reset_in),
    .areset_coreclk(sfp_areset_datapathclk),
    .gttxreset(sfp_gttxreset),
    .gtrxreset(sfp_gtrxreset),
    .sim_speedup_control(1'b0),
    .txuserrdy(sfp_txuserrdy),
    .qplllock(sfp_qplllock),
    .qplloutclk(sfp_qplloutclk),
    .qplloutrefclk(sfp_qplloutrefclk),
    .reset_counter_done(sfp_reset_counter_done),
    .xgmii_txd(sfp_4_txd_int),
    .xgmii_txc(sfp_4_txc_int),
    .xgmii_rxd(sfp_4_rxd_int),
    .xgmii_rxc(sfp_4_rxc_int),
    .txp(sfp_4_tx_p),
    .txn(sfp_4_tx_n),
    .rxp(sfp_4_rx_p),
    .rxn(sfp_4_rx_n),
    .configuration_vector(sfp_config_vector),
    .status_vector(sfp_4_status_vector),
    .core_status(sfp_4_core_status),
    .tx_resetdone(),
    .rx_resetdone(),
    .signal_detect(1'b1),
    .tx_fault(1'b0),
    .drp_req(),
    .drp_gnt(1'b1),
    .drp_den_o(),
    .drp_dwe_o(),
    .drp_daddr_o(),
    .drp_di_o(),
    .drp_drdy_o(),
    .drp_drpdo_o(),
    .drp_den_i(1'b0),
    .drp_dwe_i(1'b0),
    .drp_daddr_i(16'd0),
    .drp_di_i(16'd0),
    .drp_drdy_i(1'b0),
    .drp_drpdo_i(16'd0),
    .pma_pmd_type(3'd0),
    .tx_disable()
);

assign sfp_1_led[0] = sfp_1_rx_block_lock;
assign sfp_1_led[1] = 1'b0;
assign sfp_2_led[0] = sfp_2_rx_block_lock;
assign sfp_2_led[1] = 1'b0;
assign sfp_3_led[0] = sfp_3_rx_block_lock;
assign sfp_3_led[1] = 1'b0;
assign sfp_4_led[0] = sfp_4_rx_block_lock;
assign sfp_4_led[1] = 1'b0;
assign led = led_int;

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
    .btn(btn_int),
    // .sfp_1_led(sfp_1_led_int),
    // .sfp_2_led(sfp_2_led_int),
    // .sfp_3_led(sfp_3_led_int),
    // .sfp_4_led(sfp_4_led_int),
    .led(led_int),

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

    .s_axis_rq_seq_num(pcie_rq_seq_num),
    .s_axis_rq_seq_num_valid(pcie_rq_seq_num_vld),

    .pcie_tfc_nph_av(pcie_tfc_nph_av),
    .pcie_tfc_npd_av(pcie_tfc_npd_av),

    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),

    .cfg_mgmt_addr(cfg_mgmt_addr),
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
    .cfg_interrupt_msi_vf_enable(cfg_interrupt_msi_vf_enable),
    .cfg_interrupt_msi_mmenable(cfg_interrupt_msi_mmenable),
    .cfg_interrupt_msi_mask_update(cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_data(cfg_interrupt_msi_data),
    .cfg_interrupt_msi_select(cfg_interrupt_msi_select),
    .cfg_interrupt_msi_int(cfg_interrupt_msi_int),
    .cfg_interrupt_msi_pending_status(cfg_interrupt_msi_pending_status),
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
     * Ethernet: SFP+
     */
    .sfp_1_tx_clk(sfp_1_tx_clk_int),
    .sfp_1_tx_rst(sfp_1_tx_rst_int),
    .sfp_1_txd(sfp_1_txd_int),
    .sfp_1_txc(sfp_1_txc_int),
    .sfp_1_rx_clk(sfp_1_rx_clk_int),
    .sfp_1_rx_rst(sfp_1_rx_rst_int),
    .sfp_1_rxd(sfp_1_rxd_int),
    .sfp_1_rxc(sfp_1_rxc_int),
    .sfp_2_tx_clk(sfp_2_tx_clk_int),
    .sfp_2_tx_rst(sfp_2_tx_rst_int),
    .sfp_2_txd(sfp_2_txd_int),
    .sfp_2_txc(sfp_2_txc_int),
    .sfp_2_rx_clk(sfp_2_rx_clk_int),
    .sfp_2_rx_rst(sfp_2_rx_rst_int),
    .sfp_2_rxd(sfp_2_rxd_int),
    .sfp_2_rxc(sfp_2_rxc_int),
    .sfp_3_tx_clk(sfp_3_tx_clk_int),
    .sfp_3_tx_rst(sfp_3_tx_rst_int),
    .sfp_3_txd(sfp_3_txd_int),
    .sfp_3_txc(sfp_3_txc_int),
    .sfp_3_rx_clk(sfp_3_rx_clk_int),
    .sfp_3_rx_rst(sfp_3_rx_rst_int),
    .sfp_3_rxd(sfp_3_rxd_int),
    .sfp_3_rxc(sfp_3_rxc_int),
    .sfp_4_tx_clk(sfp_4_tx_clk_int),
    .sfp_4_tx_rst(sfp_4_tx_rst_int),
    .sfp_4_txd(sfp_4_txd_int),
    .sfp_4_txc(sfp_4_txc_int),
    .sfp_4_rx_clk(sfp_4_rx_clk_int),
    .sfp_4_rx_rst(sfp_4_rx_rst_int),
    .sfp_4_rxd(sfp_4_rxd_int),
    .sfp_4_rxc(sfp_4_rxc_int),

    .sfp_1_mod_detect(sfp_1_mod_detect_int),
    .sfp_2_mod_detect(sfp_2_mod_detect_int),
    .sfp_3_mod_detect(sfp_3_mod_detect_int),
    .sfp_4_mod_detect(sfp_4_mod_detect_int),
    .sfp_1_rs(sfp_1_rs),
    .sfp_2_rs(sfp_2_rs),
    .sfp_3_rs(sfp_3_rs),
    .sfp_4_rs(sfp_4_rs),
    .sfp_1_los(sfp_1_los_int),
    .sfp_2_los(sfp_2_los_int),
    .sfp_3_los(sfp_3_los_int),
    .sfp_4_los(sfp_4_los_int),
    .sfp_1_tx_disable(sfp_1_tx_disable),
    .sfp_2_tx_disable(sfp_2_tx_disable),
    .sfp_3_tx_disable(sfp_3_tx_disable),
    .sfp_4_tx_disable(sfp_4_tx_disable),
    .sfp_1_tx_fault(sfp_1_tx_fault_int),
    .sfp_2_tx_fault(sfp_2_tx_fault_int),
    .sfp_3_tx_fault(sfp_3_tx_fault_int),
    .sfp_4_tx_fault(sfp_4_tx_fault_int),

    .i2c_scl_i(i2c_scl_i_int),
    .i2c_scl_o(i2c_scl_o_int),
    .i2c_scl_t(i2c_scl_t_int),
    .i2c_sda_i(i2c_sda_i_int),
    .i2c_sda_o(i2c_sda_o_int),
    .i2c_sda_t(i2c_sda_t_int)
);

endmodule

`resetall
