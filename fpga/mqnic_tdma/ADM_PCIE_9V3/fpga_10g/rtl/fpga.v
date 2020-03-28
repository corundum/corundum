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
     * Clock: 300MHz LVDS
     */
    input  wire         clk_300mhz_p,
    input  wire         clk_300mhz_n,

    /*
     * GPIO
     */
    output wire [1:0]   user_led_g,
    output wire         user_led_r,
    output wire [1:0]   front_led,
    input  wire [1:0]   user_sw,

    /*
     * PCI express
     */
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,
    input  wire         pcie_refclk_1_p,
    input  wire         pcie_refclk_1_n,
    input  wire         perst_0,

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
    input  wire         qsfp_0_modprs_l,
    output wire         qsfp_0_sel_l,

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
    input  wire         qsfp_1_modprs_l,
    output wire         qsfp_1_sel_l,

    output wire         qsfp_reset_l,
    input  wire         qsfp_int_l,

    inout  wire         qsfp_i2c_scl,
    inout  wire         qsfp_i2c_sda,

    inout  wire         eeprom_i2c_scl,
    inout  wire         eeprom_i2c_sda,
    output wire         eeprom_wp,

    inout  wire [3:0]   qspi_1_dq,
    output wire         qspi_1_cs
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

wire clk_300mhz_ibufg;
wire clk_125mhz_mmcm_out;

// Internal 125 MHz clock
wire clk_125mhz_int;
wire rst_125mhz_int;

// Internal 156.25 MHz clock
wire clk_156mhz_int;
wire rst_156mhz_int;

wire mmcm_rst = pcie_user_reset;
wire mmcm_locked;
wire mmcm_clkfb;

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")   
)
clk_300mhz_ibufg_inst (
   .O   (clk_300mhz_ibufg),
   .I   (clk_300mhz_p),
   .IB  (clk_300mhz_n) 
);

// MMCM instance
// 300 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 600 MHz to 1440 MHz
// M = 10, D = 3 sets Fvco = 1000 MHz (in range)
// Divide by 8 to get output frequency of 125 MHz
MMCME4_BASE #(
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
    .CLKFBOUT_MULT_F(10),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(3),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(3.333),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_300mhz_ibufg),
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
wire [1:0] user_sw_int;
wire qsfp_0_modprs_l_int;
wire qsfp_1_modprs_l_int;
wire qsfp_int_l_int;
wire qsfp_i2c_scl_i;
wire qsfp_i2c_scl_o;
wire qsfp_i2c_scl_t;
wire qsfp_i2c_sda_i;
wire qsfp_i2c_sda_o;
wire qsfp_i2c_sda_t;
wire eeprom_i2c_scl_i;
wire eeprom_i2c_scl_o;
wire eeprom_i2c_scl_t;
wire eeprom_i2c_sda_i;
wire eeprom_i2c_sda_o;
wire eeprom_i2c_sda_t;

debounce_switch #(
    .WIDTH(2),
    .N(4),
    .RATE(250000)
)
debounce_switch_inst (
    .clk(pcie_user_clk),
    .rst(pcie_user_reset),
    .in({user_sw}),
    .out({user_sw_int})
);

sync_signal #(
    .WIDTH(7),
    .N(2)
)
sync_signal_inst (
    .clk(pcie_user_clk),
    .in({qsfp_0_modprs_l, qsfp_1_modprs_l, qsfp_int_l, 
        qsfp_i2c_scl, qsfp_i2c_sda,
        eeprom_i2c_scl, eeprom_i2c_sda}),
    .out({qsfp_0_modprs_l_int, qsfp_1_modprs_l_int, qsfp_int_l_int, 
        qsfp_i2c_scl_i, qsfp_i2c_sda_i,
        eeprom_i2c_scl_i, eeprom_i2c_sda_i})
);

assign qsfp_i2c_scl = qsfp_i2c_scl_t ? 1'bz : qsfp_i2c_scl_o;
assign qsfp_i2c_sda = qsfp_i2c_sda_t ? 1'bz : qsfp_i2c_sda_o;
assign eeprom_i2c_scl = eeprom_i2c_scl_t ? 1'bz : eeprom_i2c_scl_o;
assign eeprom_i2c_sda = eeprom_i2c_sda_t ? 1'bz : eeprom_i2c_sda_o;

// Flash
wire qspi_clk_int;
wire [3:0] qspi_0_dq_int;
wire [3:0] qspi_0_dq_i_int;
wire [3:0] qspi_0_dq_o_int;
wire [3:0] qspi_0_dq_oe_int;
wire qspi_0_cs_int;
wire [3:0] qspi_1_dq_i_int;
wire [3:0] qspi_1_dq_o_int;
wire [3:0] qspi_1_dq_oe_int;
wire qspi_1_cs_int;

assign qspi_1_dq[0] = qspi_1_dq_oe_int[0] ? qspi_1_dq_o_int[0] : 1'bz;
assign qspi_1_dq[1] = qspi_1_dq_oe_int[1] ? qspi_1_dq_o_int[1] : 1'bz;
assign qspi_1_dq[2] = qspi_1_dq_oe_int[2] ? qspi_1_dq_o_int[2] : 1'bz;
assign qspi_1_dq[3] = qspi_1_dq_oe_int[3] ? qspi_1_dq_o_int[3] : 1'bz;
assign qspi_1_cs = qspi_1_cs_int;

sync_signal #(
    .WIDTH(8),
    .N(2)
)
flash_sync_signal_inst (
    .clk(pcie_user_clk),
    .in({qspi_1_dq, qspi_0_dq_int}),
    .out({qspi_1_dq_i_int, qspi_0_dq_i_int})
);

STARTUPE3
startupe3_inst (
    .CFGCLK(),
    .CFGMCLK(),
    .DI(qspi_0_dq_int),
    .DO(qspi_0_dq_o_int),
    .DTS(~qspi_0_dq_oe_int),
    .EOS(),
    .FCSBO(qspi_0_cs_int),
    .FCSBTS(1'b0),
    .GSR(1'b0),
    .GTS(1'b0),
    .KEYCLEARB(1'b1),
    .PACK(1'b0),
    .PREQ(),
    .USRCCLKO(qspi_clk_int),
    .USRCCLKTS(1'b0),
    .USRDONEO(1'b0),
    .USRDONETS(1'b1)
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
    .user_reset(pcie_user_reset),
    .user_lnk_up(),

    .s_axis_rq_tdata(axis_rq_tdata),
    .s_axis_rq_tkeep(axis_rq_tkeep),
    .s_axis_rq_tlast(axis_rq_tlast),
    .s_axis_rq_tready(axis_rq_tready),
    .s_axis_rq_tuser(axis_rq_tuser), // width change
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
    .m_axis_cq_tuser(axis_cq_tuser), // width change
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
    .sys_reset(perst_0),

    .int_qpll0lock_out(),
    .int_qpll0outrefclk_out(),
    .int_qpll0outclk_out(),
    .int_qpll1lock_out(),
    .int_qpll1outrefclk_out(),
    .int_qpll1outclk_out(),
    .phy_rdy_out()
);

// XGMII 10G PHY
wire        qsfp_0_tx_clk_0_int;
wire        qsfp_0_tx_rst_0_int;
wire [63:0] qsfp_0_txd_0_int;
wire [7:0]  qsfp_0_txc_0_int;
wire        qsfp_0_tx_prbs31_enable_0_int;
wire        qsfp_0_rx_clk_0_int;
wire        qsfp_0_rx_rst_0_int;
wire [63:0] qsfp_0_rxd_0_int;
wire [7:0]  qsfp_0_rxc_0_int;
wire        qsfp_0_rx_prbs31_enable_0_int;
wire [6:0]  qsfp_0_rx_error_count_0_int;
wire        qsfp_0_tx_clk_1_int;
wire        qsfp_0_tx_rst_1_int;
wire [63:0] qsfp_0_txd_1_int;
wire [7:0]  qsfp_0_txc_1_int;
wire        qsfp_0_tx_prbs31_enable_1_int;
wire        qsfp_0_rx_clk_1_int;
wire        qsfp_0_rx_rst_1_int;
wire [63:0] qsfp_0_rxd_1_int;
wire [7:0]  qsfp_0_rxc_1_int;
wire        qsfp_0_rx_prbs31_enable_1_int;
wire [6:0]  qsfp_0_rx_error_count_1_int;
wire        qsfp_0_tx_clk_2_int;
wire        qsfp_0_tx_rst_2_int;
wire [63:0] qsfp_0_txd_2_int;
wire [7:0]  qsfp_0_txc_2_int;
wire        qsfp_0_tx_prbs31_enable_2_int;
wire        qsfp_0_rx_clk_2_int;
wire        qsfp_0_rx_rst_2_int;
wire [63:0] qsfp_0_rxd_2_int;
wire [7:0]  qsfp_0_rxc_2_int;
wire        qsfp_0_rx_prbs31_enable_2_int;
wire [6:0]  qsfp_0_rx_error_count_2_int;
wire        qsfp_0_tx_clk_3_int;
wire        qsfp_0_tx_rst_3_int;
wire [63:0] qsfp_0_txd_3_int;
wire [7:0]  qsfp_0_txc_3_int;
wire        qsfp_0_tx_prbs31_enable_3_int;
wire        qsfp_0_rx_clk_3_int;
wire        qsfp_0_rx_rst_3_int;
wire [63:0] qsfp_0_rxd_3_int;
wire [7:0]  qsfp_0_rxc_3_int;
wire        qsfp_0_rx_prbs31_enable_3_int;
wire [6:0]  qsfp_0_rx_error_count_3_int;

wire        qsfp_1_tx_clk_0_int;
wire        qsfp_1_tx_rst_0_int;
wire [63:0] qsfp_1_txd_0_int;
wire [7:0]  qsfp_1_txc_0_int;
wire        qsfp_1_tx_prbs31_enable_0_int;
wire        qsfp_1_rx_clk_0_int;
wire        qsfp_1_rx_rst_0_int;
wire [63:0] qsfp_1_rxd_0_int;
wire [7:0]  qsfp_1_rxc_0_int;
wire        qsfp_1_rx_prbs31_enable_0_int;
wire [6:0]  qsfp_1_rx_error_count_0_int;
wire        qsfp_1_tx_clk_1_int;
wire        qsfp_1_tx_rst_1_int;
wire [63:0] qsfp_1_txd_1_int;
wire [7:0]  qsfp_1_txc_1_int;
wire        qsfp_1_tx_prbs31_enable_1_int;
wire        qsfp_1_rx_clk_1_int;
wire        qsfp_1_rx_rst_1_int;
wire [63:0] qsfp_1_rxd_1_int;
wire [7:0]  qsfp_1_rxc_1_int;
wire        qsfp_1_rx_prbs31_enable_1_int;
wire [6:0]  qsfp_1_rx_error_count_1_int;
wire        qsfp_1_tx_clk_2_int;
wire        qsfp_1_tx_rst_2_int;
wire [63:0] qsfp_1_txd_2_int;
wire [7:0]  qsfp_1_txc_2_int;
wire        qsfp_1_tx_prbs31_enable_2_int;
wire        qsfp_1_rx_clk_2_int;
wire        qsfp_1_rx_rst_2_int;
wire [63:0] qsfp_1_rxd_2_int;
wire [7:0]  qsfp_1_rxc_2_int;
wire        qsfp_1_rx_prbs31_enable_2_int;
wire [6:0]  qsfp_1_rx_error_count_2_int;
wire        qsfp_1_tx_clk_3_int;
wire        qsfp_1_tx_rst_3_int;
wire [63:0] qsfp_1_txd_3_int;
wire [7:0]  qsfp_1_txc_3_int;
wire        qsfp_1_tx_prbs31_enable_3_int;
wire        qsfp_1_rx_clk_3_int;
wire        qsfp_1_rx_rst_3_int;
wire [63:0] qsfp_1_rxd_3_int;
wire [7:0]  qsfp_1_rxc_3_int;
wire        qsfp_1_rx_prbs31_enable_3_int;
wire [6:0]  qsfp_1_rx_error_count_3_int;

wire qsfp_0_rx_block_lock_0;
wire qsfp_0_rx_block_lock_1;
wire qsfp_0_rx_block_lock_2;
wire qsfp_0_rx_block_lock_3;

wire qsfp_1_rx_block_lock_0;
wire qsfp_1_rx_block_lock_1;
wire qsfp_1_rx_block_lock_2;
wire qsfp_1_rx_block_lock_3;

wire qsfp_0_mgt_refclk;
wire qsfp_1_mgt_refclk;

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

IBUFDS_GTE4 ibufds_gte4_qsfp_0_mgt_refclk_inst (
    .I             (qsfp_0_mgt_refclk_p),
    .IB            (qsfp_0_mgt_refclk_n),
    .CEB           (1'b0),
    .O             (qsfp_0_mgt_refclk),
    .ODIV2         ()
);

IBUFDS_GTE4 ibufds_gte4_qsfp_1_mgt_refclk_inst (
    .I             (qsfp_1_mgt_refclk_p),
    .IB            (qsfp_1_mgt_refclk_n),
    .CEB           (1'b0),
    .O             (qsfp_1_mgt_refclk),
    .ODIV2         ()
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

generate

genvar n;

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

wire [5:0] qsfp_0_gt_txheader_0;
wire [63:0] qsfp_0_gt_txdata_0;
wire qsfp_0_gt_rxgearboxslip_0;
wire [5:0] qsfp_0_gt_rxheader_0;
wire [1:0] qsfp_0_gt_rxheadervalid_0;
wire [63:0] qsfp_0_gt_rxdata_0;
wire [1:0] qsfp_0_gt_rxdatavalid_0;

wire [5:0] qsfp_0_gt_txheader_1;
wire [63:0] qsfp_0_gt_txdata_1;
wire qsfp_0_gt_rxgearboxslip_1;
wire [5:0] qsfp_0_gt_rxheader_1;
wire [1:0] qsfp_0_gt_rxheadervalid_1;
wire [63:0] qsfp_0_gt_rxdata_1;
wire [1:0] qsfp_0_gt_rxdatavalid_1;

wire [5:0] qsfp_0_gt_txheader_2;
wire [63:0] qsfp_0_gt_txdata_2;
wire qsfp_0_gt_rxgearboxslip_2;
wire [5:0] qsfp_0_gt_rxheader_2;
wire [1:0] qsfp_0_gt_rxheadervalid_2;
wire [63:0] qsfp_0_gt_rxdata_2;
wire [1:0] qsfp_0_gt_rxdatavalid_2;

wire [5:0] qsfp_0_gt_txheader_3;
wire [63:0] qsfp_0_gt_txdata_3;
wire qsfp_0_gt_rxgearboxslip_3;
wire [5:0] qsfp_0_gt_rxheader_3;
wire [1:0] qsfp_0_gt_rxheadervalid_3;
wire [63:0] qsfp_0_gt_rxdata_3;
wire [1:0] qsfp_0_gt_rxdatavalid_3;

wire [5:0] qsfp_1_gt_txheader_0;
wire [63:0] qsfp_1_gt_txdata_0;
wire qsfp_1_gt_rxgearboxslip_0;
wire [5:0] qsfp_1_gt_rxheader_0;
wire [1:0] qsfp_1_gt_rxheadervalid_0;
wire [63:0] qsfp_1_gt_rxdata_0;
wire [1:0] qsfp_1_gt_rxdatavalid_0;

wire [5:0] qsfp_1_gt_txheader_1;
wire [63:0] qsfp_1_gt_txdata_1;
wire qsfp_1_gt_rxgearboxslip_1;
wire [5:0] qsfp_1_gt_rxheader_1;
wire [1:0] qsfp_1_gt_rxheadervalid_1;
wire [63:0] qsfp_1_gt_rxdata_1;
wire [1:0] qsfp_1_gt_rxdatavalid_1;

wire [5:0] qsfp_1_gt_txheader_2;
wire [63:0] qsfp_1_gt_txdata_2;
wire qsfp_1_gt_rxgearboxslip_2;
wire [5:0] qsfp_1_gt_rxheader_2;
wire [1:0] qsfp_1_gt_rxheadervalid_2;
wire [63:0] qsfp_1_gt_rxdata_2;
wire [1:0] qsfp_1_gt_rxdatavalid_2;

wire [5:0] qsfp_1_gt_txheader_3;
wire [63:0] qsfp_1_gt_txdata_3;
wire qsfp_1_gt_rxgearboxslip_3;
wire [5:0] qsfp_1_gt_rxheader_3;
wire [1:0] qsfp_1_gt_rxheadervalid_3;
wire [63:0] qsfp_1_gt_rxdata_3;
wire [1:0] qsfp_1_gt_rxdatavalid_3;

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

    .gtrefclk00_in({qsfp_0_mgt_refclk, qsfp_1_mgt_refclk}),

    .qpll0outclk_out(),
    .qpll0outrefclk_out(),

    .rxpmareset_in(8'd0),

    .gtyrxn_in({qsfp_0_rx_3_n, qsfp_0_rx_2_n, qsfp_0_rx_1_n, qsfp_0_rx_0_n, qsfp_1_rx_3_n, qsfp_1_rx_2_n, qsfp_1_rx_1_n, qsfp_1_rx_0_n}),
    .gtyrxp_in({qsfp_0_rx_3_p, qsfp_0_rx_2_p, qsfp_0_rx_1_p, qsfp_0_rx_0_p, qsfp_1_rx_3_p, qsfp_1_rx_2_p, qsfp_1_rx_1_p, qsfp_1_rx_0_p}),

    .rxusrclk_in(gt_rxusrclk),
    .rxusrclk2_in(gt_rxusrclk),

    .gtwiz_userdata_tx_in({qsfp_0_gt_txdata_3, qsfp_0_gt_txdata_2, qsfp_0_gt_txdata_1, qsfp_0_gt_txdata_0, qsfp_1_gt_txdata_3, qsfp_1_gt_txdata_2, qsfp_1_gt_txdata_1, qsfp_1_gt_txdata_0}),
    .txheader_in({qsfp_0_gt_txheader_3, qsfp_0_gt_txheader_2, qsfp_0_gt_txheader_1, qsfp_0_gt_txheader_0, qsfp_1_gt_txheader_3, qsfp_1_gt_txheader_2, qsfp_1_gt_txheader_1, qsfp_1_gt_txheader_0}),
    .txsequence_in({8{1'b0}}),

    .txusrclk_in({8{gt_txusrclk}}),
    .txusrclk2_in({8{gt_txusrclk}}),

    .gtpowergood_out(),

    .gtytxn_out({qsfp_0_tx_3_n, qsfp_0_tx_2_n, qsfp_0_tx_1_n, qsfp_0_tx_0_n, qsfp_1_tx_3_n, qsfp_1_tx_2_n, qsfp_1_tx_1_n, qsfp_1_tx_0_n}),
    .gtytxp_out({qsfp_0_tx_3_p, qsfp_0_tx_2_p, qsfp_0_tx_1_p, qsfp_0_tx_0_p, qsfp_1_tx_3_p, qsfp_1_tx_2_p, qsfp_1_tx_1_p, qsfp_1_tx_0_p}),

    .rxgearboxslip_in({qsfp_0_gt_rxgearboxslip_3, qsfp_0_gt_rxgearboxslip_2, qsfp_0_gt_rxgearboxslip_1, qsfp_0_gt_rxgearboxslip_0, qsfp_1_gt_rxgearboxslip_3, qsfp_1_gt_rxgearboxslip_2, qsfp_1_gt_rxgearboxslip_1, qsfp_1_gt_rxgearboxslip_0}),
    .gtwiz_userdata_rx_out({qsfp_0_gt_rxdata_3, qsfp_0_gt_rxdata_2, qsfp_0_gt_rxdata_1, qsfp_0_gt_rxdata_0, qsfp_1_gt_rxdata_3, qsfp_1_gt_rxdata_2, qsfp_1_gt_rxdata_1, qsfp_1_gt_rxdata_0}),
    .rxdatavalid_out({qsfp_0_gt_rxdatavalid_3, qsfp_0_gt_rxdatavalid_2, qsfp_0_gt_rxdatavalid_1, qsfp_0_gt_rxdatavalid_0, qsfp_1_gt_rxdatavalid_3, qsfp_1_gt_rxdatavalid_2, qsfp_1_gt_rxdatavalid_1, qsfp_1_gt_rxdatavalid_0}),
    .rxheader_out({qsfp_0_gt_rxheader_3, qsfp_0_gt_rxheader_2, qsfp_0_gt_rxheader_1, qsfp_0_gt_rxheader_0, qsfp_1_gt_rxheader_3, qsfp_1_gt_rxheader_2, qsfp_1_gt_rxheader_1, qsfp_1_gt_rxheader_0}),
    .rxheadervalid_out({qsfp_0_gt_rxheadervalid_3, qsfp_0_gt_rxheadervalid_2, qsfp_0_gt_rxheadervalid_1, qsfp_0_gt_rxheadervalid_0, qsfp_1_gt_rxheadervalid_3, qsfp_1_gt_rxheadervalid_2, qsfp_1_gt_rxheadervalid_1, qsfp_1_gt_rxheadervalid_0}),
    .rxoutclk_out(gt_rxclkout),
    .rxpmaresetdone_out(gt_rxpmaresetdone),
    .rxprgdivresetdone_out(gt_rxprgdivresetdone),
    .rxstartofseq_out(),

    .txoutclk_out(gt_txclkout),
    .txpmaresetdone_out(gt_txpmaresetdone),
    .txprgdivresetdone_out(gt_txprgdivresetdone)
);

assign qsfp_0_tx_clk_0_int = clk_156mhz_int;
assign qsfp_0_tx_rst_0_int = rst_156mhz_int;

assign qsfp_0_rx_clk_0_int = gt_rxusrclk[4];

sync_reset #(
    .N(4)
)
qsfp_0_rx_rst_0_reset_sync_inst (
    .clk(qsfp_0_rx_clk_0_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_0_rx_rst_0_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_0_phy_0_inst (
    .tx_clk(qsfp_0_tx_clk_0_int),
    .tx_rst(qsfp_0_tx_rst_0_int),
    .rx_clk(qsfp_0_rx_clk_0_int),
    .rx_rst(qsfp_0_rx_rst_0_int),
    .xgmii_txd(qsfp_0_txd_0_int),
    .xgmii_txc(qsfp_0_txc_0_int),
    .xgmii_rxd(qsfp_0_rxd_0_int),
    .xgmii_rxc(qsfp_0_rxc_0_int),
    .serdes_tx_data(qsfp_0_gt_txdata_0),
    .serdes_tx_hdr(qsfp_0_gt_txheader_0),
    .serdes_rx_data(qsfp_0_gt_rxdata_0),
    .serdes_rx_hdr(qsfp_0_gt_rxheader_0),
    .serdes_rx_bitslip(qsfp_0_gt_rxgearboxslip_0),
    .rx_error_count(qsfp_0_rx_error_count_0_int),
    .rx_block_lock(qsfp_0_rx_block_lock_0),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_0_tx_prbs31_enable_0_int),
    .rx_prbs31_enable(qsfp_0_rx_prbs31_enable_0_int)
);

assign qsfp_0_tx_clk_1_int = clk_156mhz_int;
assign qsfp_0_tx_rst_1_int = rst_156mhz_int;

assign qsfp_0_rx_clk_1_int = gt_rxusrclk[5];

sync_reset #(
    .N(4)
)
qsfp_0_rx_rst_1_reset_sync_inst (
    .clk(qsfp_0_rx_clk_1_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_0_rx_rst_1_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_0_phy_1_inst (
    .tx_clk(qsfp_0_tx_clk_1_int),
    .tx_rst(qsfp_0_tx_rst_1_int),
    .rx_clk(qsfp_0_rx_clk_1_int),
    .rx_rst(qsfp_0_rx_rst_1_int),
    .xgmii_txd(qsfp_0_txd_1_int),
    .xgmii_txc(qsfp_0_txc_1_int),
    .xgmii_rxd(qsfp_0_rxd_1_int),
    .xgmii_rxc(qsfp_0_rxc_1_int),
    .serdes_tx_data(qsfp_0_gt_txdata_1),
    .serdes_tx_hdr(qsfp_0_gt_txheader_1),
    .serdes_rx_data(qsfp_0_gt_rxdata_1),
    .serdes_rx_hdr(qsfp_0_gt_rxheader_1),
    .serdes_rx_bitslip(qsfp_0_gt_rxgearboxslip_1),
    .rx_error_count(qsfp_0_rx_error_count_1_int),
    .rx_block_lock(qsfp_0_rx_block_lock_1),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_0_tx_prbs31_enable_1_int),
    .rx_prbs31_enable(qsfp_0_rx_prbs31_enable_1_int)
);

assign qsfp_0_tx_clk_2_int = clk_156mhz_int;
assign qsfp_0_tx_rst_2_int = rst_156mhz_int;

assign qsfp_0_rx_clk_2_int = gt_rxusrclk[6];

sync_reset #(
    .N(4)
)
qsfp_0_rx_rst_2_reset_sync_inst (
    .clk(qsfp_0_rx_clk_2_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_0_rx_rst_2_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_0_phy_2_inst (
    .tx_clk(qsfp_0_tx_clk_2_int),
    .tx_rst(qsfp_0_tx_rst_2_int),
    .rx_clk(qsfp_0_rx_clk_2_int),
    .rx_rst(qsfp_0_rx_rst_2_int),
    .xgmii_txd(qsfp_0_txd_2_int),
    .xgmii_txc(qsfp_0_txc_2_int),
    .xgmii_rxd(qsfp_0_rxd_2_int),
    .xgmii_rxc(qsfp_0_rxc_2_int),
    .serdes_tx_data(qsfp_0_gt_txdata_2),
    .serdes_tx_hdr(qsfp_0_gt_txheader_2),
    .serdes_rx_data(qsfp_0_gt_rxdata_2),
    .serdes_rx_hdr(qsfp_0_gt_rxheader_2),
    .serdes_rx_bitslip(qsfp_0_gt_rxgearboxslip_2),
    .rx_error_count(qsfp_0_rx_error_count_2_int),
    .rx_block_lock(qsfp_0_rx_block_lock_2),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_0_tx_prbs31_enable_2_int),
    .rx_prbs31_enable(qsfp_0_rx_prbs31_enable_2_int)
);

assign qsfp_0_tx_clk_3_int = clk_156mhz_int;
assign qsfp_0_tx_rst_3_int = rst_156mhz_int;

assign qsfp_0_rx_clk_3_int = gt_rxusrclk[7];

sync_reset #(
    .N(4)
)
qsfp_0_rx_rst_3_reset_sync_inst (
    .clk(qsfp_0_rx_clk_3_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_0_rx_rst_3_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_0_phy_3_inst (
    .tx_clk(qsfp_0_tx_clk_3_int),
    .tx_rst(qsfp_0_tx_rst_3_int),
    .rx_clk(qsfp_0_rx_clk_3_int),
    .rx_rst(qsfp_0_rx_rst_3_int),
    .xgmii_txd(qsfp_0_txd_3_int),
    .xgmii_txc(qsfp_0_txc_3_int),
    .xgmii_rxd(qsfp_0_rxd_3_int),
    .xgmii_rxc(qsfp_0_rxc_3_int),
    .serdes_tx_data(qsfp_0_gt_txdata_3),
    .serdes_tx_hdr(qsfp_0_gt_txheader_3),
    .serdes_rx_data(qsfp_0_gt_rxdata_3),
    .serdes_rx_hdr(qsfp_0_gt_rxheader_3),
    .serdes_rx_bitslip(qsfp_0_gt_rxgearboxslip_3),
    .rx_error_count(qsfp_0_rx_error_count_3_int),
    .rx_block_lock(qsfp_0_rx_block_lock_3),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_0_tx_prbs31_enable_3_int),
    .rx_prbs31_enable(qsfp_0_rx_prbs31_enable_3_int)
);

assign qsfp_1_tx_clk_0_int = clk_156mhz_int;
assign qsfp_1_tx_rst_0_int = rst_156mhz_int;

assign qsfp_1_rx_clk_0_int = gt_rxusrclk[0];

sync_reset #(
    .N(4)
)
qsfp_1_rx_rst_0_reset_sync_inst (
    .clk(qsfp_1_rx_clk_0_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_1_rx_rst_0_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_1_phy_0_inst (
    .tx_clk(qsfp_1_tx_clk_0_int),
    .tx_rst(qsfp_1_tx_rst_0_int),
    .rx_clk(qsfp_1_rx_clk_0_int),
    .rx_rst(qsfp_1_rx_rst_0_int),
    .xgmii_txd(qsfp_1_txd_0_int),
    .xgmii_txc(qsfp_1_txc_0_int),
    .xgmii_rxd(qsfp_1_rxd_0_int),
    .xgmii_rxc(qsfp_1_rxc_0_int),
    .serdes_tx_data(qsfp_1_gt_txdata_0),
    .serdes_tx_hdr(qsfp_1_gt_txheader_0),
    .serdes_rx_data(qsfp_1_gt_rxdata_0),
    .serdes_rx_hdr(qsfp_1_gt_rxheader_0),
    .serdes_rx_bitslip(qsfp_1_gt_rxgearboxslip_0),
    .rx_error_count(qsfp_1_rx_error_count_0_int),
    .rx_block_lock(qsfp_1_rx_block_lock_0),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_1_tx_prbs31_enable_0_int),
    .rx_prbs31_enable(qsfp_1_rx_prbs31_enable_0_int)
);

assign qsfp_1_tx_clk_1_int = clk_156mhz_int;
assign qsfp_1_tx_rst_1_int = rst_156mhz_int;

assign qsfp_1_rx_clk_1_int = gt_rxusrclk[1];

sync_reset #(
    .N(4)
)
qsfp_1_rx_rst_1_reset_sync_inst (
    .clk(qsfp_1_rx_clk_1_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_1_rx_rst_1_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_1_phy_1_inst (
    .tx_clk(qsfp_1_tx_clk_1_int),
    .tx_rst(qsfp_1_tx_rst_1_int),
    .rx_clk(qsfp_1_rx_clk_1_int),
    .rx_rst(qsfp_1_rx_rst_1_int),
    .xgmii_txd(qsfp_1_txd_1_int),
    .xgmii_txc(qsfp_1_txc_1_int),
    .xgmii_rxd(qsfp_1_rxd_1_int),
    .xgmii_rxc(qsfp_1_rxc_1_int),
    .serdes_tx_data(qsfp_1_gt_txdata_1),
    .serdes_tx_hdr(qsfp_1_gt_txheader_1),
    .serdes_rx_data(qsfp_1_gt_rxdata_1),
    .serdes_rx_hdr(qsfp_1_gt_rxheader_1),
    .serdes_rx_bitslip(qsfp_1_gt_rxgearboxslip_1),
    .rx_error_count(qsfp_1_rx_error_count_1_int),
    .rx_block_lock(qsfp_1_rx_block_lock_1),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_1_tx_prbs31_enable_1_int),
    .rx_prbs31_enable(qsfp_1_rx_prbs31_enable_1_int)
);

assign qsfp_1_tx_clk_2_int = clk_156mhz_int;
assign qsfp_1_tx_rst_2_int = rst_156mhz_int;

assign qsfp_1_rx_clk_2_int = gt_rxusrclk[2];

sync_reset #(
    .N(4)
)
qsfp_1_rx_rst_2_reset_sync_inst (
    .clk(qsfp_1_rx_clk_2_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_1_rx_rst_2_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_1_phy_2_inst (
    .tx_clk(qsfp_1_tx_clk_2_int),
    .tx_rst(qsfp_1_tx_rst_2_int),
    .rx_clk(qsfp_1_rx_clk_2_int),
    .rx_rst(qsfp_1_rx_rst_2_int),
    .xgmii_txd(qsfp_1_txd_2_int),
    .xgmii_txc(qsfp_1_txc_2_int),
    .xgmii_rxd(qsfp_1_rxd_2_int),
    .xgmii_rxc(qsfp_1_rxc_2_int),
    .serdes_tx_data(qsfp_1_gt_txdata_2),
    .serdes_tx_hdr(qsfp_1_gt_txheader_2),
    .serdes_rx_data(qsfp_1_gt_rxdata_2),
    .serdes_rx_hdr(qsfp_1_gt_rxheader_2),
    .serdes_rx_bitslip(qsfp_1_gt_rxgearboxslip_2),
    .rx_error_count(qsfp_1_rx_error_count_2_int),
    .rx_block_lock(qsfp_1_rx_block_lock_2),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_1_tx_prbs31_enable_2_int),
    .rx_prbs31_enable(qsfp_1_rx_prbs31_enable_2_int)
);

assign qsfp_1_tx_clk_3_int = clk_156mhz_int;
assign qsfp_1_tx_rst_3_int = rst_156mhz_int;

assign qsfp_1_rx_clk_3_int = gt_rxusrclk[3];

sync_reset #(
    .N(4)
)
qsfp_1_rx_rst_3_reset_sync_inst (
    .clk(qsfp_1_rx_clk_3_int),
    .rst(~gt_reset_rx_done),
    .out(qsfp_1_rx_rst_3_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1),
    .PRBS31_ENABLE(1)
)
qsfp_1_phy_3_inst (
    .tx_clk(qsfp_1_tx_clk_3_int),
    .tx_rst(qsfp_1_tx_rst_3_int),
    .rx_clk(qsfp_1_rx_clk_3_int),
    .rx_rst(qsfp_1_rx_rst_3_int),
    .xgmii_txd(qsfp_1_txd_3_int),
    .xgmii_txc(qsfp_1_txc_3_int),
    .xgmii_rxd(qsfp_1_rxd_3_int),
    .xgmii_rxc(qsfp_1_rxc_3_int),
    .serdes_tx_data(qsfp_1_gt_txdata_3),
    .serdes_tx_hdr(qsfp_1_gt_txheader_3),
    .serdes_rx_data(qsfp_1_gt_rxdata_3),
    .serdes_rx_hdr(qsfp_1_gt_rxheader_3),
    .serdes_rx_bitslip(qsfp_1_gt_rxgearboxslip_3),
    .rx_error_count(qsfp_1_rx_error_count_3_int),
    .rx_block_lock(qsfp_1_rx_block_lock_3),
    .rx_high_ber(),
    .tx_prbs31_enable(qsfp_1_tx_prbs31_enable_3_int),
    .rx_prbs31_enable(qsfp_1_rx_prbs31_enable_3_int)
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
    .clk_156mhz(clk_156mhz_int),
    .rst_156mhz(rst_156mhz_int),
    .clk_250mhz(pcie_user_clk),
    .rst_250mhz(pcie_user_reset),

    /*
     * GPIO
     */
    .user_led_g(user_led_g),
    .user_led_r(user_led_r),
    .front_led(front_led),
    .user_sw(user_sw_int),

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
    .qsfp_0_modprs_l(qsfp_0_modprs_l_int),
    .qsfp_0_sel_l(qsfp_0_sel_l),
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
    .qsfp_1_modprs_l(qsfp_1_modprs_l_int),
    .qsfp_1_sel_l(qsfp_1_sel_l),
    .qsfp_reset_l(qsfp_reset_l),
    .qsfp_int_l(qsfp_int_l_int),
    .qsfp_i2c_scl_i(qsfp_i2c_scl_i),
    .qsfp_i2c_scl_o(qsfp_i2c_scl_o),
    .qsfp_i2c_scl_t(qsfp_i2c_scl_t),
    .qsfp_i2c_sda_i(qsfp_i2c_sda_i),
    .qsfp_i2c_sda_o(qsfp_i2c_sda_o),
    .qsfp_i2c_sda_t(qsfp_i2c_sda_t),
    .eeprom_i2c_scl_i(eeprom_i2c_scl_i),
    .eeprom_i2c_scl_o(eeprom_i2c_scl_o),
    .eeprom_i2c_scl_t(eeprom_i2c_scl_t),
    .eeprom_i2c_sda_i(eeprom_i2c_sda_i),
    .eeprom_i2c_sda_o(eeprom_i2c_sda_o),
    .eeprom_i2c_sda_t(eeprom_i2c_sda_t),
    .eeprom_wp(eeprom_wp),

    /*
     * QSPI flash
     */
    .qspi_clk(qspi_clk_int),
    .qspi_0_dq_i(qspi_0_dq_i_int),
    .qspi_0_dq_o(qspi_0_dq_o_int),
    .qspi_0_dq_oe(qspi_0_dq_oe_int),
    .qspi_0_cs(qspi_0_cs_int),
    .qspi_1_dq_i(qspi_1_dq_i_int),
    .qspi_1_dq_o(qspi_1_dq_o_int),
    .qspi_1_dq_oe(qspi_1_dq_oe_int),
    .qspi_1_cs(qspi_1_cs_int)
);

endmodule
