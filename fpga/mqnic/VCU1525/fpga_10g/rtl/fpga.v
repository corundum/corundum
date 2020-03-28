/*

Copyright 2019, The Regents of the University of California.
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

`timescale 1ns / 1ps

/*
 * FPGA top-level module
 */
module fpga (
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
    // input  wire         qsfp1_mgt_refclk_1_p,
    // input  wire         qsfp1_mgt_refclk_1_n,
    output wire         qsfp1_modsell,
    output wire         qsfp1_resetl,
    input  wire         qsfp1_modprsl,
    input  wire         qsfp1_intl,
    output wire         qsfp1_lpmode,
    output wire         qsfp1_refclk_reset,
    output wire [1:0]   qsfp1_fs
);

parameter AXIS_PCIE_DATA_WIDTH = 512;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_RC_USER_WIDTH = 161;
parameter AXIS_PCIE_RQ_USER_WIDTH = 137;
parameter AXIS_PCIE_CQ_USER_WIDTH = 183;
parameter AXIS_PCIE_CC_USER_WIDTH = 81;
parameter RQ_SEQ_NUM_WIDTH = 6;
parameter BAR0_APERTURE = 24;

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

assign i2c_scl = i2c_scl_t ? 1'bz : i2c_scl_o;
assign i2c_sda = i2c_sda_t ? 1'bz : i2c_sda_o;

// startupe3 instance
wire cfgmclk;

STARTUPE3
startupe3_inst (
    .CFGCLK(),
    .CFGMCLK(cfgmclk),
    .DI(),
    .DO(4'd0),
    .DTS(1'b1),
    .EOS(),
    .FCSBO(1'b0),
    .FCSBTS(1'b1),
    .GSR(1'b0),
    .GTS(1'b0),
    .KEYCLEARB(1'b1),
    .PACK(1'b0),
    .PREQ(),
    .USRCCLKO(1'b0),
    .USRCCLKTS(1'b1),
    .USRDONEO(1'b0),
    .USRDONETS(1'b1)
);

BUFG
cfgmclk_bufg_inst (
    .I(cfgmclk),
    .O(cfgmclk_int)
);

// configure SI5335 clock generators
reg qsfp_refclk_reset_reg = 1'b1;
reg sys_reset_reg = 1'b1;

reg [9:0] reset_timer_reg = 0;

assign mmcm_rst = sys_reset_reg;

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

    if (pcie_user_reset) begin
        qsfp_refclk_reset_reg <= 1'b1;
        sys_reset_reg <= 1'b1;
        reset_timer_reg <= 0;
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

pcie4_uscale_plus_0
pcie4_uscale_plus_inst (
    .pci_exp_txn(pcie_tx_n),
    .pci_exp_txp(pcie_tx_p),
    .pci_exp_rxn(pcie_rx_n),
    .pci_exp_rxp(pcie_rx_p),
    .user_clk(pcie_user_clk),
    .user_reset(pcie_user_reset),
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

// XGMII 10G PHY
assign qsfp0_refclk_reset = qsfp_refclk_reset_reg;
assign qsfp0_fs = 2'b10;

wire        qsfp0_tx_clk_1_int;
wire        qsfp0_tx_rst_1_int;
wire [63:0] qsfp0_txd_1_int;
wire [7:0]  qsfp0_txc_1_int;
wire        qsfp0_tx_prbs31_enable_1_int;
wire        qsfp0_rx_clk_1_int;
wire        qsfp0_rx_rst_1_int;
wire [63:0] qsfp0_rxd_1_int;
wire [7:0]  qsfp0_rxc_1_int;
wire        qsfp0_rx_prbs31_enable_1_int;
wire [6:0]  qsfp0_rx_error_count_1_int;
wire        qsfp0_tx_clk_2_int;
wire        qsfp0_tx_rst_2_int;
wire [63:0] qsfp0_txd_2_int;
wire [7:0]  qsfp0_txc_2_int;
wire        qsfp0_tx_prbs31_enable_2_int;
wire        qsfp0_rx_clk_2_int;
wire        qsfp0_rx_rst_2_int;
wire [63:0] qsfp0_rxd_2_int;
wire [7:0]  qsfp0_rxc_2_int;
wire        qsfp0_rx_prbs31_enable_2_int;
wire [6:0]  qsfp0_rx_error_count_2_int;
wire        qsfp0_tx_clk_3_int;
wire        qsfp0_tx_rst_3_int;
wire [63:0] qsfp0_txd_3_int;
wire [7:0]  qsfp0_txc_3_int;
wire        qsfp0_tx_prbs31_enable_3_int;
wire        qsfp0_rx_clk_3_int;
wire        qsfp0_rx_rst_3_int;
wire [63:0] qsfp0_rxd_3_int;
wire [7:0]  qsfp0_rxc_3_int;
wire        qsfp0_rx_prbs31_enable_3_int;
wire [6:0]  qsfp0_rx_error_count_3_int;
wire        qsfp0_tx_clk_4_int;
wire        qsfp0_tx_rst_4_int;
wire [63:0] qsfp0_txd_4_int;
wire [7:0]  qsfp0_txc_4_int;
wire        qsfp0_tx_prbs31_enable_4_int;
wire        qsfp0_rx_clk_4_int;
wire        qsfp0_rx_rst_4_int;
wire [63:0] qsfp0_rxd_4_int;
wire [7:0]  qsfp0_rxc_4_int;
wire        qsfp0_rx_prbs31_enable_4_int;
wire [6:0]  qsfp0_rx_error_count_4_int;

assign qsfp1_refclk_reset = qsfp_refclk_reset_reg;
assign qsfp1_fs = 2'b10;

wire        qsfp1_tx_clk_1_int;
wire        qsfp1_tx_rst_1_int;
wire [63:0] qsfp1_txd_1_int;
wire [7:0]  qsfp1_txc_1_int;
wire        qsfp1_tx_prbs31_enable_1_int;
wire        qsfp1_rx_clk_1_int;
wire        qsfp1_rx_rst_1_int;
wire [63:0] qsfp1_rxd_1_int;
wire [7:0]  qsfp1_rxc_1_int;
wire        qsfp1_rx_prbs31_enable_1_int;
wire [6:0]  qsfp1_rx_error_count_1_int;
wire        qsfp1_tx_clk_2_int;
wire        qsfp1_tx_rst_2_int;
wire [63:0] qsfp1_txd_2_int;
wire [7:0]  qsfp1_txc_2_int;
wire        qsfp1_tx_prbs31_enable_2_int;
wire        qsfp1_rx_clk_2_int;
wire        qsfp1_rx_rst_2_int;
wire [63:0] qsfp1_rxd_2_int;
wire [7:0]  qsfp1_rxc_2_int;
wire        qsfp1_rx_prbs31_enable_2_int;
wire [6:0]  qsfp1_rx_error_count_2_int;
wire        qsfp1_tx_clk_3_int;
wire        qsfp1_tx_rst_3_int;
wire [63:0] qsfp1_txd_3_int;
wire [7:0]  qsfp1_txc_3_int;
wire        qsfp1_tx_prbs31_enable_3_int;
wire        qsfp1_rx_clk_3_int;
wire        qsfp1_rx_rst_3_int;
wire [63:0] qsfp1_rxd_3_int;
wire [7:0]  qsfp1_rxc_3_int;
wire        qsfp1_rx_prbs31_enable_3_int;
wire [6:0]  qsfp1_rx_error_count_3_int;
wire        qsfp1_tx_clk_4_int;
wire        qsfp1_tx_rst_4_int;
wire [63:0] qsfp1_txd_4_int;
wire [7:0]  qsfp1_txc_4_int;
wire        qsfp1_tx_prbs31_enable_4_int;
wire        qsfp1_rx_clk_4_int;
wire        qsfp1_rx_rst_4_int;
wire [63:0] qsfp1_rxd_4_int;
wire [7:0]  qsfp1_rxc_4_int;
wire        qsfp1_rx_prbs31_enable_4_int;
wire [6:0]  qsfp1_rx_error_count_4_int;

wire qsfp0_rx_block_lock_1;
wire qsfp0_rx_block_lock_2;
wire qsfp0_rx_block_lock_3;
wire qsfp0_rx_block_lock_4;

wire qsfp1_rx_block_lock_1;
wire qsfp1_rx_block_lock_2;
wire qsfp1_rx_block_lock_3;
wire qsfp1_rx_block_lock_4;

wire [7:0] qsfp_gtpowergood;

wire qsfp0_mgt_refclk_1;
wire qsfp0_mgt_refclk_1_int;
wire qsfp0_mgt_refclk_1_bufg;

assign clk_161mhz_ref_int = qsfp0_mgt_refclk_1_bufg;

wire [7:0] gt_txclkout;
wire gt_txusrclk;

wire [7:0] gt_rxclkout;
wire [7:0] gt_rxusrclk;

wire gt_reset_tx_done;
wire gt_reset_rx_done;

wire [7:0] gt_txprgdivresetdone;
wire [7:0] gt_txpmaresetdone;
wire [7:0] gt_rxprgdivresetdone;
wire [7:0] gt_rxpmaresetdone;

wire gt_tx_reset = ~((&gt_txprgdivresetdone) & (&gt_txpmaresetdone));
wire gt_rx_reset = ~&gt_rxpmaresetdone;

reg gt_userclk_tx_active = 1'b0;
reg [7:0] gt_userclk_rx_active = 1'b0;

IBUFDS_GTE4 ibufds_gte4_qsfp0_mgt_refclk_1_inst (
    .I             (qsfp0_mgt_refclk_1_p),
    .IB            (qsfp0_mgt_refclk_1_n),
    .CEB           (1'b0),
    .O             (qsfp0_mgt_refclk_1),
    .ODIV2         (qsfp0_mgt_refclk_1_int)
);

BUFG_GT bufg_gt_refclk_inst (
    .CE      (&qsfp_gtpowergood),
    .CEMASK  (1'b1),
    .CLR     (1'b0),
    .CLRMASK (1'b1),
    .DIV     (3'd0),
    .I       (qsfp0_mgt_refclk_1_int),
    .O       (qsfp0_mgt_refclk_1_bufg)
);

BUFG_GT bufg_gt_tx_usrclk_inst (
    .CE      (1'b1),
    .CEMASK  (1'b0),
    .CLR     (gt_tx_reset),
    .CLRMASK (1'b0),
    .DIV     (3'd0),
    .I       (gt_txclkout[0]),
    .O       (gt_txusrclk)
);

assign clk_156mhz_int = gt_txusrclk;

always @(posedge gt_txusrclk, posedge gt_tx_reset) begin
    if (gt_tx_reset) begin
        gt_userclk_tx_active <= 1'b0;
    end else begin
        gt_userclk_tx_active <= 1'b1;
    end
end

genvar n;

generate

for (n = 0; n < 8; n = n + 1) begin

    BUFG_GT bufg_gt_rx_usrclk_inst (
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (gt_rx_reset),
        .CLRMASK (1'b0),
        .DIV     (3'd0),
        .I       (gt_rxclkout[n]),
        .O       (gt_rxusrclk[n])
    );

    always @(posedge gt_rxusrclk[n], posedge gt_rx_reset) begin
        if (gt_rx_reset) begin
            gt_userclk_rx_active[n] <= 1'b0;
        end else begin
            gt_userclk_rx_active[n] <= 1'b1;
        end
    end

end

endgenerate

sync_reset #(
    .N(4)
)
sync_reset_156mhz_inst (
    .clk(clk_156mhz_int),
    .rst(~gt_reset_tx_done),
    .out(rst_156mhz_int)
);

wire [5:0] qsfp0_gt_txheader_1;
wire [127:0] qsfp0_gt_txdata_1;
wire qsfp0_gt_rxgearboxslip_1;
wire [5:0] qsfp0_gt_rxheader_1;
wire [1:0] qsfp0_gt_rxheadervalid_1;
wire [127:0] qsfp0_gt_rxdata_1;
wire [1:0] qsfp0_gt_rxdatavalid_1;

wire [5:0] qsfp0_gt_txheader_2;
wire [127:0] qsfp0_gt_txdata_2;
wire qsfp0_gt_rxgearboxslip_2;
wire [5:0] qsfp0_gt_rxheader_2;
wire [1:0] qsfp0_gt_rxheadervalid_2;
wire [127:0] qsfp0_gt_rxdata_2;
wire [1:0] qsfp0_gt_rxdatavalid_2;

wire [5:0] qsfp0_gt_txheader_3;
wire [127:0] qsfp0_gt_txdata_3;
wire qsfp0_gt_rxgearboxslip_3;
wire [5:0] qsfp0_gt_rxheader_3;
wire [1:0] qsfp0_gt_rxheadervalid_3;
wire [127:0] qsfp0_gt_rxdata_3;
wire [1:0] qsfp0_gt_rxdatavalid_3;

wire [5:0] qsfp0_gt_txheader_4;
wire [127:0] qsfp0_gt_txdata_4;
wire qsfp0_gt_rxgearboxslip_4;
wire [5:0] qsfp0_gt_rxheader_4;
wire [1:0] qsfp0_gt_rxheadervalid_4;
wire [127:0] qsfp0_gt_rxdata_4;
wire [1:0] qsfp0_gt_rxdatavalid_4;

wire [5:0] qsfp1_gt_txheader_1;
wire [127:0] qsfp1_gt_txdata_1;
wire qsfp1_gt_rxgearboxslip_1;
wire [5:0] qsfp1_gt_rxheader_1;
wire [1:0] qsfp1_gt_rxheadervalid_1;
wire [127:0] qsfp1_gt_rxdata_1;
wire [1:0] qsfp1_gt_rxdatavalid_1;

wire [5:0] qsfp1_gt_txheader_2;
wire [127:0] qsfp1_gt_txdata_2;
wire qsfp1_gt_rxgearboxslip_2;
wire [5:0] qsfp1_gt_rxheader_2;
wire [1:0] qsfp1_gt_rxheadervalid_2;
wire [127:0] qsfp1_gt_rxdata_2;
wire [1:0] qsfp1_gt_rxdatavalid_2;

wire [5:0] qsfp1_gt_txheader_3;
wire [127:0] qsfp1_gt_txdata_3;
wire qsfp1_gt_rxgearboxslip_3;
wire [5:0] qsfp1_gt_rxheader_3;
wire [1:0] qsfp1_gt_rxheadervalid_3;
wire [127:0] qsfp1_gt_rxdata_3;
wire [1:0] qsfp1_gt_rxdatavalid_3;

wire [5:0] qsfp1_gt_txheader_4;
wire [127:0] qsfp1_gt_txdata_4;
wire qsfp1_gt_rxgearboxslip_4;
wire [5:0] qsfp1_gt_rxheader_4;
wire [1:0] qsfp1_gt_rxheadervalid_4;
wire [127:0] qsfp1_gt_rxdata_4;
wire [1:0] qsfp1_gt_rxdatavalid_4;

gtwizard_ultrascale_0
qsfp_gty_inst (
    .gtwiz_userclk_tx_active_in(&gt_userclk_tx_active),
    .gtwiz_userclk_rx_active_in(&gt_userclk_rx_active),

    .gtwiz_reset_clk_freerun_in(clk_125mhz_int),
    .gtwiz_reset_all_in(rst_125mhz_int),

    .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_tx_datapath_in(1'b0),

    .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_rx_datapath_in(1'b0),

    .gtwiz_reset_rx_cdr_stable_out(),

    .gtwiz_reset_tx_done_out(gt_reset_tx_done),
    .gtwiz_reset_rx_done_out(gt_reset_rx_done),

    .gtrefclk00_in({2{qsfp0_mgt_refclk_1}}),

    .qpll0outclk_out(),
    .qpll0outrefclk_out(),

    .gtyrxn_in({qsfp0_rx4_n, qsfp0_rx3_n, qsfp0_rx2_n, qsfp0_rx1_n, qsfp1_rx4_n, qsfp1_rx3_n, qsfp1_rx2_n, qsfp1_rx1_n}),
    .gtyrxp_in({qsfp0_rx4_p, qsfp0_rx3_p, qsfp0_rx2_p, qsfp0_rx1_p, qsfp1_rx4_p, qsfp1_rx3_p, qsfp1_rx2_p, qsfp1_rx1_p}),

    .rxusrclk_in(gt_rxusrclk),
    .rxusrclk2_in(gt_rxusrclk),

    .txdata_in({qsfp0_gt_txdata_4, qsfp0_gt_txdata_3, qsfp0_gt_txdata_2, qsfp0_gt_txdata_1, qsfp1_gt_txdata_4, qsfp1_gt_txdata_3, qsfp1_gt_txdata_2, qsfp1_gt_txdata_1}),
    .txheader_in({qsfp0_gt_txheader_4, qsfp0_gt_txheader_3, qsfp0_gt_txheader_2, qsfp0_gt_txheader_1, qsfp1_gt_txheader_4, qsfp1_gt_txheader_3, qsfp1_gt_txheader_2, qsfp1_gt_txheader_1}),
    .txsequence_in({8{1'b0}}),

    .txusrclk_in({8{gt_txusrclk}}),
    .txusrclk2_in({8{gt_txusrclk}}),

    .gtpowergood_out(qsfp_gtpowergood),

    .gtytxn_out({qsfp0_tx4_n, qsfp0_tx3_n, qsfp0_tx2_n, qsfp0_tx1_n, qsfp1_tx4_n, qsfp1_tx3_n, qsfp1_tx2_n, qsfp1_tx1_n}),
    .gtytxp_out({qsfp0_tx4_p, qsfp0_tx3_p, qsfp0_tx2_p, qsfp0_tx1_p, qsfp1_tx4_p, qsfp1_tx3_p, qsfp1_tx2_p, qsfp1_tx1_p}),

    .rxgearboxslip_in({qsfp0_gt_rxgearboxslip_4, qsfp0_gt_rxgearboxslip_3, qsfp0_gt_rxgearboxslip_2, qsfp0_gt_rxgearboxslip_1, qsfp1_gt_rxgearboxslip_4, qsfp1_gt_rxgearboxslip_3, qsfp1_gt_rxgearboxslip_2, qsfp1_gt_rxgearboxslip_1}),
    .rxdata_out({qsfp0_gt_rxdata_4, qsfp0_gt_rxdata_3, qsfp0_gt_rxdata_2, qsfp0_gt_rxdata_1, qsfp1_gt_rxdata_4, qsfp1_gt_rxdata_3, qsfp1_gt_rxdata_2, qsfp1_gt_rxdata_1}),
    .rxdatavalid_out({qsfp0_gt_rxdatavalid_4, qsfp0_gt_rxdatavalid_3, qsfp0_gt_rxdatavalid_2, qsfp0_gt_rxdatavalid_1, qsfp1_gt_rxdatavalid_4, qsfp1_gt_rxdatavalid_3, qsfp1_gt_rxdatavalid_2, qsfp1_gt_rxdatavalid_1}),
    .rxheader_out({qsfp0_gt_rxheader_4, qsfp0_gt_rxheader_3, qsfp0_gt_rxheader_2, qsfp0_gt_rxheader_1, qsfp1_gt_rxheader_4, qsfp1_gt_rxheader_3, qsfp1_gt_rxheader_2, qsfp1_gt_rxheader_1}),
    .rxheadervalid_out({qsfp0_gt_rxheadervalid_4, qsfp0_gt_rxheadervalid_3, qsfp0_gt_rxheadervalid_2, qsfp0_gt_rxheadervalid_1, qsfp1_gt_rxheadervalid_4, qsfp1_gt_rxheadervalid_3, qsfp1_gt_rxheadervalid_2, qsfp1_gt_rxheadervalid_1}),
    .rxoutclk_out(gt_rxclkout),
    .rxpmaresetdone_out(gt_rxpmaresetdone),
    .rxprgdivresetdone_out(gt_rxprgdivresetdone),
    .rxstartofseq_out(),

    .txoutclk_out(gt_txclkout),
    .txpmaresetdone_out(gt_txpmaresetdone),
    .txprgdivresetdone_out(gt_txprgdivresetdone)
);

assign qsfp0_tx_clk_1_int = clk_156mhz_int;
assign qsfp0_tx_rst_1_int = rst_156mhz_int;

assign qsfp0_rx_clk_1_int = gt_rxusrclk[4];

sync_reset #(
    .N(4)
)
qsfp0_rx_rst_1_reset_sync_inst (
    .clk(qsfp0_rx_clk_1_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp0_rx_rst_1_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp0_phy_1_inst (
    .tx_clk(qsfp0_tx_clk_1_int),
    .tx_rst(qsfp0_tx_rst_1_int),
    .rx_clk(qsfp0_rx_clk_1_int),
    .rx_rst(qsfp0_rx_rst_1_int),
    .xgmii_txd(qsfp0_txd_1_int),
    .xgmii_txc(qsfp0_txc_1_int),
    .xgmii_rxd(qsfp0_rxd_1_int),
    .xgmii_rxc(qsfp0_rxc_1_int),
    .serdes_tx_data(qsfp0_gt_txdata_1),
    .serdes_tx_hdr(qsfp0_gt_txheader_1),
    .serdes_rx_data(qsfp0_gt_rxdata_1),
    .serdes_rx_hdr(qsfp0_gt_rxheader_1),
    .serdes_rx_bitslip(qsfp0_gt_rxgearboxslip_1),
    .rx_error_count(qsfp0_rx_error_count_1_int),
    .rx_block_lock(qsfp0_rx_block_lock_1),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp0_tx_prbs31_enable_1_int),
    .rx_prbs31_enable(qsfp0_rx_prbs31_enable_1_int)
);

assign qsfp0_tx_clk_2_int = clk_156mhz_int;
assign qsfp0_tx_rst_2_int = rst_156mhz_int;

assign qsfp0_rx_clk_2_int = gt_rxusrclk[5];

sync_reset #(
    .N(4)
)
qsfp0_rx_rst_2_reset_sync_inst (
    .clk(qsfp0_rx_clk_2_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp0_rx_rst_2_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp0_phy_2_inst (
    .tx_clk(qsfp0_tx_clk_2_int),
    .tx_rst(qsfp0_tx_rst_2_int),
    .rx_clk(qsfp0_rx_clk_2_int),
    .rx_rst(qsfp0_rx_rst_2_int),
    .xgmii_txd(qsfp0_txd_2_int),
    .xgmii_txc(qsfp0_txc_2_int),
    .xgmii_rxd(qsfp0_rxd_2_int),
    .xgmii_rxc(qsfp0_rxc_2_int),
    .serdes_tx_data(qsfp0_gt_txdata_2),
    .serdes_tx_hdr(qsfp0_gt_txheader_2),
    .serdes_rx_data(qsfp0_gt_rxdata_2),
    .serdes_rx_hdr(qsfp0_gt_rxheader_2),
    .serdes_rx_bitslip(qsfp0_gt_rxgearboxslip_2),
    .rx_error_count(qsfp0_rx_error_count_2_int),
    .rx_block_lock(qsfp0_rx_block_lock_2),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp0_tx_prbs31_enable_2_int),
    .rx_prbs31_enable(qsfp0_rx_prbs31_enable_2_int)
);

assign qsfp0_tx_clk_3_int = clk_156mhz_int;
assign qsfp0_tx_rst_3_int = rst_156mhz_int;

assign qsfp0_rx_clk_3_int = gt_rxusrclk[6];

sync_reset #(
    .N(4)
)
qsfp0_rx_rst_3_reset_sync_inst (
    .clk(qsfp0_rx_clk_3_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp0_rx_rst_3_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp0_phy_3_inst (
    .tx_clk(qsfp0_tx_clk_3_int),
    .tx_rst(qsfp0_tx_rst_3_int),
    .rx_clk(qsfp0_rx_clk_3_int),
    .rx_rst(qsfp0_rx_rst_3_int),
    .xgmii_txd(qsfp0_txd_3_int),
    .xgmii_txc(qsfp0_txc_3_int),
    .xgmii_rxd(qsfp0_rxd_3_int),
    .xgmii_rxc(qsfp0_rxc_3_int),
    .serdes_tx_data(qsfp0_gt_txdata_3),
    .serdes_tx_hdr(qsfp0_gt_txheader_3),
    .serdes_rx_data(qsfp0_gt_rxdata_3),
    .serdes_rx_hdr(qsfp0_gt_rxheader_3),
    .serdes_rx_bitslip(qsfp0_gt_rxgearboxslip_3),
    .rx_error_count(qsfp0_rx_error_count_3_int),
    .rx_block_lock(qsfp0_rx_block_lock_3),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp0_tx_prbs31_enable_3_int),
    .rx_prbs31_enable(qsfp0_rx_prbs31_enable_3_int)
);

assign qsfp0_tx_clk_4_int = clk_156mhz_int;
assign qsfp0_tx_rst_4_int = rst_156mhz_int;

assign qsfp0_rx_clk_4_int = gt_rxusrclk[7];

sync_reset #(
    .N(4)
)
qsfp0_rx_rst_4_reset_sync_inst (
    .clk(qsfp0_rx_clk_4_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp0_rx_rst_4_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp0_phy_4_inst (
    .tx_clk(qsfp0_tx_clk_4_int),
    .tx_rst(qsfp0_tx_rst_4_int),
    .rx_clk(qsfp0_rx_clk_4_int),
    .rx_rst(qsfp0_rx_rst_4_int),
    .xgmii_txd(qsfp0_txd_4_int),
    .xgmii_txc(qsfp0_txc_4_int),
    .xgmii_rxd(qsfp0_rxd_4_int),
    .xgmii_rxc(qsfp0_rxc_4_int),
    .serdes_tx_data(qsfp0_gt_txdata_4),
    .serdes_tx_hdr(qsfp0_gt_txheader_4),
    .serdes_rx_data(qsfp0_gt_rxdata_4),
    .serdes_rx_hdr(qsfp0_gt_rxheader_4),
    .serdes_rx_bitslip(qsfp0_gt_rxgearboxslip_4),
    .rx_error_count(qsfp0_rx_error_count_4_int),
    .rx_block_lock(qsfp0_rx_block_lock_4),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp0_tx_prbs31_enable_4_int),
    .rx_prbs31_enable(qsfp0_rx_prbs31_enable_4_int)
);

assign qsfp1_tx_clk_1_int = clk_156mhz_int;
assign qsfp1_tx_rst_1_int = rst_156mhz_int;

assign qsfp1_rx_clk_1_int = gt_rxusrclk[0];

sync_reset #(
    .N(4)
)
qsfp1_rx_rst_1_reset_sync_inst (
    .clk(qsfp1_rx_clk_1_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp1_rx_rst_1_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp1_phy_1_inst (
    .tx_clk(qsfp1_tx_clk_1_int),
    .tx_rst(qsfp1_tx_rst_1_int),
    .rx_clk(qsfp1_rx_clk_1_int),
    .rx_rst(qsfp1_rx_rst_1_int),
    .xgmii_txd(qsfp1_txd_1_int),
    .xgmii_txc(qsfp1_txc_1_int),
    .xgmii_rxd(qsfp1_rxd_1_int),
    .xgmii_rxc(qsfp1_rxc_1_int),
    .serdes_tx_data(qsfp1_gt_txdata_1),
    .serdes_tx_hdr(qsfp1_gt_txheader_1),
    .serdes_rx_data(qsfp1_gt_rxdata_1),
    .serdes_rx_hdr(qsfp1_gt_rxheader_1),
    .serdes_rx_bitslip(qsfp1_gt_rxgearboxslip_1),
    .rx_error_count(qsfp1_rx_error_count_1_int),
    .rx_block_lock(qsfp1_rx_block_lock_1),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp1_tx_prbs31_enable_1_int),
    .rx_prbs31_enable(qsfp1_rx_prbs31_enable_1_int)
);

assign qsfp1_tx_clk_2_int = clk_156mhz_int;
assign qsfp1_tx_rst_2_int = rst_156mhz_int;

assign qsfp1_rx_clk_2_int = gt_rxusrclk[1];

sync_reset #(
    .N(4)
)
qsfp1_rx_rst_2_reset_sync_inst (
    .clk(qsfp1_rx_clk_2_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp1_rx_rst_2_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp1_phy_2_inst (
    .tx_clk(qsfp1_tx_clk_2_int),
    .tx_rst(qsfp1_tx_rst_2_int),
    .rx_clk(qsfp1_rx_clk_2_int),
    .rx_rst(qsfp1_rx_rst_2_int),
    .xgmii_txd(qsfp1_txd_2_int),
    .xgmii_txc(qsfp1_txc_2_int),
    .xgmii_rxd(qsfp1_rxd_2_int),
    .xgmii_rxc(qsfp1_rxc_2_int),
    .serdes_tx_data(qsfp1_gt_txdata_2),
    .serdes_tx_hdr(qsfp1_gt_txheader_2),
    .serdes_rx_data(qsfp1_gt_rxdata_2),
    .serdes_rx_hdr(qsfp1_gt_rxheader_2),
    .serdes_rx_bitslip(qsfp1_gt_rxgearboxslip_2),
    .rx_error_count(qsfp1_rx_error_count_2_int),
    .rx_block_lock(qsfp1_rx_block_lock_2),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp1_tx_prbs31_enable_2_int),
    .rx_prbs31_enable(qsfp1_rx_prbs31_enable_2_int)
);

assign qsfp1_tx_clk_3_int = clk_156mhz_int;
assign qsfp1_tx_rst_3_int = rst_156mhz_int;

assign qsfp1_rx_clk_3_int = gt_rxusrclk[2];

sync_reset #(
    .N(4)
)
qsfp1_rx_rst_3_reset_sync_inst (
    .clk(qsfp1_rx_clk_3_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp1_rx_rst_3_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp1_phy_3_inst (
    .tx_clk(qsfp1_tx_clk_3_int),
    .tx_rst(qsfp1_tx_rst_3_int),
    .rx_clk(qsfp1_rx_clk_3_int),
    .rx_rst(qsfp1_rx_rst_3_int),
    .xgmii_txd(qsfp1_txd_3_int),
    .xgmii_txc(qsfp1_txc_3_int),
    .xgmii_rxd(qsfp1_rxd_3_int),
    .xgmii_rxc(qsfp1_rxc_3_int),
    .serdes_tx_data(qsfp1_gt_txdata_3),
    .serdes_tx_hdr(qsfp1_gt_txheader_3),
    .serdes_rx_data(qsfp1_gt_rxdata_3),
    .serdes_rx_hdr(qsfp1_gt_rxheader_3),
    .serdes_rx_bitslip(qsfp1_gt_rxgearboxslip_3),
    .rx_error_count(qsfp1_rx_error_count_3_int),
    .rx_block_lock(qsfp1_rx_block_lock_3),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp1_tx_prbs31_enable_3_int),
    .rx_prbs31_enable(qsfp1_rx_prbs31_enable_3_int)
);

assign qsfp1_tx_clk_4_int = clk_156mhz_int;
assign qsfp1_tx_rst_4_int = rst_156mhz_int;

assign qsfp1_rx_clk_4_int = gt_rxusrclk[3];

sync_reset #(
    .N(4)
)
qsfp1_rx_rst_4_reset_sync_inst (
    .clk(qsfp1_rx_clk_4_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp1_rx_rst_4_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp1_phy_4_inst (
    .tx_clk(qsfp1_tx_clk_4_int),
    .tx_rst(qsfp1_tx_rst_4_int),
    .rx_clk(qsfp1_rx_clk_4_int),
    .rx_rst(qsfp1_rx_rst_4_int),
    .xgmii_txd(qsfp1_txd_4_int),
    .xgmii_txc(qsfp1_txc_4_int),
    .xgmii_rxd(qsfp1_rxd_4_int),
    .xgmii_rxc(qsfp1_rxc_4_int),
    .serdes_tx_data(qsfp1_gt_txdata_4),
    .serdes_tx_hdr(qsfp1_gt_txheader_4),
    .serdes_rx_data(qsfp1_gt_rxdata_4),
    .serdes_rx_hdr(qsfp1_gt_rxheader_4),
    .serdes_rx_bitslip(qsfp1_gt_rxgearboxslip_4),
    .rx_error_count(qsfp1_rx_error_count_4_int),
    .rx_block_lock(qsfp1_rx_block_lock_4),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp1_tx_prbs31_enable_4_int),
    .rx_prbs31_enable(qsfp1_rx_prbs31_enable_4_int)
);

fpga_core #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .BAR0_APERTURE(BAR0_APERTURE)
)
core_inst (
    /*
     * Clock: 156.25 MHz, 250 MHz
     * Synchronous reset
     */
    .clk_250mhz(pcie_user_clk),
    .rst_250mhz(pcie_user_reset),

    /*
     * GPIO
     */
    .sw(sw_int),
    .led(led),

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
     * Ethernet: QSFP18
     */
    .qsfp0_tx_clk_1(qsfp0_tx_clk_1_int),
    .qsfp0_tx_rst_1(qsfp0_tx_rst_1_int),
    .qsfp0_txd_1(qsfp0_txd_1_int),
    .qsfp0_txc_1(qsfp0_txc_1_int),
    .qsfp0_tx_prbs31_enable_1(qsfp0_tx_prbs31_enable_1_int),
    .qsfp0_rx_clk_1(qsfp0_rx_clk_1_int),
    .qsfp0_rx_rst_1(qsfp0_rx_rst_1_int),
    .qsfp0_rxd_1(qsfp0_rxd_1_int),
    .qsfp0_rxc_1(qsfp0_rxc_1_int),
    .qsfp0_rx_prbs31_enable_1(qsfp0_rx_prbs31_enable_1_int),
    .qsfp0_rx_error_count_1(qsfp0_rx_error_count_1_int),
    .qsfp0_tx_clk_2(qsfp0_tx_clk_2_int),
    .qsfp0_tx_rst_2(qsfp0_tx_rst_2_int),
    .qsfp0_txd_2(qsfp0_txd_2_int),
    .qsfp0_txc_2(qsfp0_txc_2_int),
    .qsfp0_tx_prbs31_enable_2(qsfp0_tx_prbs31_enable_2_int),
    .qsfp0_rx_clk_2(qsfp0_rx_clk_2_int),
    .qsfp0_rx_rst_2(qsfp0_rx_rst_2_int),
    .qsfp0_rxd_2(qsfp0_rxd_2_int),
    .qsfp0_rxc_2(qsfp0_rxc_2_int),
    .qsfp0_rx_prbs31_enable_2(qsfp0_rx_prbs31_enable_2_int),
    .qsfp0_rx_error_count_2(qsfp0_rx_error_count_2_int),
    .qsfp0_tx_clk_3(qsfp0_tx_clk_3_int),
    .qsfp0_tx_rst_3(qsfp0_tx_rst_3_int),
    .qsfp0_txd_3(qsfp0_txd_3_int),
    .qsfp0_txc_3(qsfp0_txc_3_int),
    .qsfp0_tx_prbs31_enable_3(qsfp0_tx_prbs31_enable_3_int),
    .qsfp0_rx_clk_3(qsfp0_rx_clk_3_int),
    .qsfp0_rx_rst_3(qsfp0_rx_rst_3_int),
    .qsfp0_rxd_3(qsfp0_rxd_3_int),
    .qsfp0_rxc_3(qsfp0_rxc_3_int),
    .qsfp0_rx_prbs31_enable_3(qsfp0_rx_prbs31_enable_3_int),
    .qsfp0_rx_error_count_3(qsfp0_rx_error_count_3_int),
    .qsfp0_tx_clk_4(qsfp0_tx_clk_4_int),
    .qsfp0_tx_rst_4(qsfp0_tx_rst_4_int),
    .qsfp0_txd_4(qsfp0_txd_4_int),
    .qsfp0_txc_4(qsfp0_txc_4_int),
    .qsfp0_tx_prbs31_enable_4(qsfp0_tx_prbs31_enable_4_int),
    .qsfp0_rx_clk_4(qsfp0_rx_clk_4_int),
    .qsfp0_rx_rst_4(qsfp0_rx_rst_4_int),
    .qsfp0_rxd_4(qsfp0_rxd_4_int),
    .qsfp0_rxc_4(qsfp0_rxc_4_int),
    .qsfp0_rx_prbs31_enable_4(qsfp0_rx_prbs31_enable_4_int),
    .qsfp0_rx_error_count_4(qsfp0_rx_error_count_4_int),
    .qsfp0_modprsl(qsfp0_modprsl_int),
    .qsfp0_modsell(qsfp0_modsell),
    .qsfp0_resetl(qsfp0_resetl),
    .qsfp0_intl(qsfp0_intl_int),
    .qsfp0_lpmode(qsfp0_lpmode),

    .qsfp1_tx_clk_1(qsfp1_tx_clk_1_int),
    .qsfp1_tx_rst_1(qsfp1_tx_rst_1_int),
    .qsfp1_txd_1(qsfp1_txd_1_int),
    .qsfp1_txc_1(qsfp1_txc_1_int),
    .qsfp1_tx_prbs31_enable_1(qsfp1_tx_prbs31_enable_1_int),
    .qsfp1_rx_clk_1(qsfp1_rx_clk_1_int),
    .qsfp1_rx_rst_1(qsfp1_rx_rst_1_int),
    .qsfp1_rxd_1(qsfp1_rxd_1_int),
    .qsfp1_rxc_1(qsfp1_rxc_1_int),
    .qsfp1_rx_prbs31_enable_1(qsfp1_rx_prbs31_enable_1_int),
    .qsfp1_rx_error_count_1(qsfp1_rx_error_count_1_int),
    .qsfp1_tx_clk_2(qsfp1_tx_clk_2_int),
    .qsfp1_tx_rst_2(qsfp1_tx_rst_2_int),
    .qsfp1_txd_2(qsfp1_txd_2_int),
    .qsfp1_txc_2(qsfp1_txc_2_int),
    .qsfp1_tx_prbs31_enable_2(qsfp1_tx_prbs31_enable_2_int),
    .qsfp1_rx_clk_2(qsfp1_rx_clk_2_int),
    .qsfp1_rx_rst_2(qsfp1_rx_rst_2_int),
    .qsfp1_rxd_2(qsfp1_rxd_2_int),
    .qsfp1_rxc_2(qsfp1_rxc_2_int),
    .qsfp1_rx_prbs31_enable_2(qsfp1_rx_prbs31_enable_2_int),
    .qsfp1_rx_error_count_2(qsfp1_rx_error_count_2_int),
    .qsfp1_tx_clk_3(qsfp1_tx_clk_3_int),
    .qsfp1_tx_rst_3(qsfp1_tx_rst_3_int),
    .qsfp1_txd_3(qsfp1_txd_3_int),
    .qsfp1_txc_3(qsfp1_txc_3_int),
    .qsfp1_tx_prbs31_enable_3(qsfp1_tx_prbs31_enable_3_int),
    .qsfp1_rx_clk_3(qsfp1_rx_clk_3_int),
    .qsfp1_rx_rst_3(qsfp1_rx_rst_3_int),
    .qsfp1_rxd_3(qsfp1_rxd_3_int),
    .qsfp1_rxc_3(qsfp1_rxc_3_int),
    .qsfp1_rx_prbs31_enable_3(qsfp1_rx_prbs31_enable_3_int),
    .qsfp1_rx_error_count_3(qsfp1_rx_error_count_3_int),
    .qsfp1_tx_clk_4(qsfp1_tx_clk_4_int),
    .qsfp1_tx_rst_4(qsfp1_tx_rst_4_int),
    .qsfp1_txd_4(qsfp1_txd_4_int),
    .qsfp1_txc_4(qsfp1_txc_4_int),
    .qsfp1_tx_prbs31_enable_4(qsfp1_tx_prbs31_enable_4_int),
    .qsfp1_rx_clk_4(qsfp1_rx_clk_4_int),
    .qsfp1_rx_rst_4(qsfp1_rx_rst_4_int),
    .qsfp1_rxd_4(qsfp1_rxd_4_int),
    .qsfp1_rxc_4(qsfp1_rxc_4_int),
    .qsfp1_rx_prbs31_enable_4(qsfp1_rx_prbs31_enable_4_int),
    .qsfp1_rx_error_count_4(qsfp1_rx_error_count_4_int),
    .qsfp1_modprsl(qsfp1_modprsl_int),
    .qsfp1_modsell(qsfp1_modsell),
    .qsfp1_resetl(qsfp1_resetl),
    .qsfp1_intl(qsfp1_intl_int),
    .qsfp1_lpmode(qsfp1_lpmode)
);

endmodule
