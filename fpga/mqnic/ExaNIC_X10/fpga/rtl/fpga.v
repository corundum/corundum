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
     * Clock: 100MHz LVDS
     * Reset: Push button, active low
     */
    input  wire         clk_100mhz_p,
    input  wire         clk_100mhz_n,

    /*
     * GPIO
     */
    output wire [1:0]   sfp_1_led,
    output wire [1:0]   sfp_2_led,
    output wire [1:0]   sma_led,

    input  wire         sma_in,
    output wire         sma_out,
    output wire         sma_out_en,
    output wire         sma_term_en,

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
    input  wire         sfp_mgt_refclk_p,
    input  wire         sfp_mgt_refclk_n,
    output wire         sfp_1_tx_disable,
    output wire         sfp_2_tx_disable,
    input  wire         sfp_1_npres,
    input  wire         sfp_2_npres,
    input  wire         sfp_1_los,
    input  wire         sfp_2_los,
    output wire         sfp_1_rs,
    output wire         sfp_2_rs,

    inout  wire         sfp_i2c_scl,
    inout  wire         sfp_1_i2c_sda,
    inout  wire         sfp_2_i2c_sda,

    inout  wire         eeprom_i2c_scl,
    inout  wire         eeprom_i2c_sda,

    /*
     * BPI Flash
     */
    inout  wire [15:0]  flash_dq,
    output wire [22:0]  flash_addr,
    output wire         flash_region,
    output wire         flash_ce_n,
    output wire         flash_oe_n,
    output wire         flash_we_n,
    output wire         flash_adv_n
);

parameter AXIS_PCIE_DATA_WIDTH = 256;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);

// Clock and reset
wire pcie_user_clk;
wire pcie_user_reset;

wire clk_100mhz_ibufg;
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
clk_100mhz_ibufg_inst (
   .O   (clk_100mhz_ibufg),
   .I   (clk_100mhz_p),
   .IB  (clk_100mhz_n) 
);

// MMCM instance
// 100 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 600 MHz to 1440 MHz
// M = 10, D = 1 sets Fvco = 1000 MHz (in range)
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
    .CLKFBOUT_MULT_F(10),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(10.0),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_100mhz_ibufg),
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
    .sync_reset_out(rst_125mhz_int)
);

// GPIO
wire sfp_i2c_scl_i;
wire sfp_i2c_scl_o;
wire sfp_i2c_scl_t;
wire sfp_1_i2c_sda_i;
wire sfp_1_i2c_sda_o;
wire sfp_1_i2c_sda_t;
wire sfp_2_i2c_sda_i;
wire sfp_2_i2c_sda_o;
wire sfp_2_i2c_sda_t;
wire eeprom_i2c_scl_i;
wire eeprom_i2c_scl_o;
wire eeprom_i2c_scl_t;
wire eeprom_i2c_sda_i;
wire eeprom_i2c_sda_o;
wire eeprom_i2c_sda_t;

sync_signal #(
    .WIDTH(5),
    .N(2)
)
sync_signal_inst (
    .clk(pcie_user_clk),
    .in({sfp_i2c_scl, sfp_1_i2c_sda, sfp_2_i2c_sda,
        eeprom_i2c_scl, eeprom_i2c_sda}),
    .out({sfp_i2c_scl_i, sfp_1_i2c_sda_i, sfp_2_i2c_sda_i,
        eeprom_i2c_scl_i, eeprom_i2c_sda_i})
);

assign sfp_i2c_scl = sfp_i2c_scl_t ? 1'bz : sfp_i2c_scl_o;
assign sfp_1_i2c_sda = sfp_1_i2c_sda_t ? 1'bz : sfp_1_i2c_sda_o;
assign sfp_2_i2c_sda = sfp_2_i2c_sda_t ? 1'bz : sfp_2_i2c_sda_o;
assign eeprom_i2c_scl = eeprom_i2c_scl_t ? 1'bz : eeprom_i2c_scl_o;
assign eeprom_i2c_sda = eeprom_i2c_sda_t ? 1'bz : eeprom_i2c_sda_o;

// Flash
wire [15:0] flash_dq_i_int;
wire [15:0] flash_dq_o_int;
wire flash_dq_oe_int;
wire [22:0] flash_addr_int;
wire flash_region_int;
wire flash_region_oe_int;
wire flash_ce_n_int;
wire flash_oe_n_int;
wire flash_we_n_int;
wire flash_adv_n_int;

assign flash_dq = flash_dq_oe_int ? flash_dq_o_int : 16'hzzzz;
assign flash_addr = flash_addr_int;
assign flash_region = flash_region_oe_int ? flash_region_int : 1'bz;
assign flash_ce_n = flash_ce_n_int;
assign flash_oe_n = flash_oe_n_int;
assign flash_we_n = flash_we_n_int;
assign flash_adv_n = flash_adv_n_int;

sync_signal #(
    .WIDTH(16),
    .N(2)
)
flash_sync_signal_inst (
    .clk(pcie_user_clk),
    .in(flash_dq),
    .out(flash_dq_i_int)
);

// PCIe
wire pcie_sys_clk;
wire pcie_sys_clk_gt;

IBUFDS_GTE3 #(
    .REFCLK_HROW_CK_SEL(2'b00)
)
ibufds_gte3_pcie_mgt_refclk_inst (
    .I             (pcie_mgt_refclk_p),
    .IB            (pcie_mgt_refclk_n),
    .CEB           (1'b0),
    .O             (pcie_sys_clk_gt),
    .ODIV2         (pcie_sys_clk)
);

wire [AXIS_PCIE_DATA_WIDTH-1:0] axis_rq_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] axis_rq_tkeep;
wire                            axis_rq_tlast;
wire                            axis_rq_tready;
wire [59:0]                     axis_rq_tuser;
wire                            axis_rq_tvalid;

wire [AXIS_PCIE_DATA_WIDTH-1:0] axis_rc_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] axis_rc_tkeep;
wire                            axis_rc_tlast;
wire                            axis_rc_tready;
wire [74:0]                     axis_rc_tuser;
wire                            axis_rc_tvalid;

wire [AXIS_PCIE_DATA_WIDTH-1:0] axis_cq_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] axis_cq_tkeep;
wire                            axis_cq_tlast;
wire                            axis_cq_tready;
wire [84:0]                     axis_cq_tuser;
wire                            axis_cq_tvalid;

wire [AXIS_PCIE_DATA_WIDTH-1:0] axis_cc_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] axis_cc_tkeep;
wire                            axis_cc_tlast;
wire                            axis_cc_tready;
wire [32:0]                     axis_cc_tuser;
wire                            axis_cc_tvalid;

wire [1:0] pcie_tfc_nph_av;
wire [1:0] pcie_tfc_npd_av;

wire [2:0] cfg_max_payload;
wire [2:0] cfg_max_read_req;

wire [18:0] cfg_mgmt_addr;
wire        cfg_mgmt_write;
wire [31:0] cfg_mgmt_write_data;
wire [3:0]  cfg_mgmt_byte_enable;
wire        cfg_mgmt_read;
wire [31:0] cfg_mgmt_read_data;
wire        cfg_mgmt_read_write_done;

wire [3:0]  cfg_interrupt_msi_enable;
wire [7:0]  cfg_interrupt_msi_vf_enable;
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

pcie3_ultrascale_0
pcie3_ultrascale_inst (
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

    .pcie_rq_seq_num(),
    .pcie_rq_seq_num_vld(),
    .pcie_rq_tag(),
    .pcie_rq_tag_av(),
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
    .cfg_local_error(),
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

    .cfg_fc_ph(),
    .cfg_fc_pd(),
    .cfg_fc_nph(),
    .cfg_fc_npd(),
    .cfg_fc_cplh(),
    .cfg_fc_cpld(),
    .cfg_fc_sel(3'd0),

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
    .cfg_interrupt_msi_pending_status_data_enable(cfg_interrupt_msi_pending_status_data_enable),
    .cfg_interrupt_msi_pending_status_function_num(cfg_interrupt_msi_pending_status_function_num),
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
    .sys_clk_gt(pcie_sys_clk_gt),
    .sys_reset(pcie_reset_n),
    .pcie_perstn1_in(1'b0),
    .pcie_perstn0_out(),
    .pcie_perstn1_out(),

    .int_qpll1lock_out(),
    .int_qpll1outrefclk_out(),
    .int_qpll1outclk_out(),
    .phy_rdy_out()
);

// XGMII 10G PHY

assign sfp_1_tx_disable = 1'b1;
assign sfp_2_tx_disable = 1'b1;
assign sfp_1_rs = 1'b0;
assign sfp_2_rs = 1'b0;

wire        sfp_1_tx_clk_int;
wire        sfp_1_tx_rst_int;
wire [63:0] sfp_1_txd_int;
wire [7:0]  sfp_1_txc_int;
wire        sfp_1_rx_clk_int;
wire        sfp_1_rx_rst_int;
wire [63:0] sfp_1_rxd_int;
wire [7:0]  sfp_1_rxc_int;
wire        sfp_2_tx_clk_int;
wire        sfp_2_tx_rst_int;
wire [63:0] sfp_2_txd_int;
wire [7:0]  sfp_2_txc_int;
wire        sfp_2_rx_clk_int;
wire        sfp_2_rx_rst_int;
wire [63:0] sfp_2_rxd_int;
wire [7:0]  sfp_2_rxc_int;

wire sfp_1_rx_block_lock;
wire sfp_2_rx_block_lock;

wire sfp_mgt_refclk;

wire [1:0] gt_txclkout;
wire gt_txusrclk;
wire gt_txusrclk2;

wire [1:0] gt_rxclkout;
wire [1:0] gt_rxusrclk;
wire [1:0] gt_rxusrclk2;

wire gt_reset_tx_done;
wire gt_reset_rx_done;

wire [1:0] gt_txprgdivresetdone;
wire [1:0] gt_txpmaresetdone;
wire [1:0] gt_rxprgdivresetdone;
wire [1:0] gt_rxpmaresetdone;

wire gt_tx_reset = ~((&gt_txprgdivresetdone) & (&gt_txpmaresetdone));
wire gt_rx_reset = ~&gt_rxpmaresetdone;

reg gt_userclk_tx_active = 1'b0;
reg [1:0] gt_userclk_rx_active = 1'b0;

IBUFDS_GTE3 ibufds_gte3_sfp_mgt_refclk_inst (
    .I             (sfp_mgt_refclk_p),
    .IB            (sfp_mgt_refclk_n),
    .CEB           (1'b0),
    .O             (sfp_mgt_refclk),
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

BUFG_GT bufg_gt_tx_usrclk2_inst (
    .CE      (1'b1),
    .CEMASK  (1'b0),
    .CLR     (gt_tx_reset),
    .CLRMASK (1'b0),
    .DIV     (3'd1),
    .I       (gt_txclkout[0]),
    .O       (gt_txusrclk2)
);

assign clk_156mhz_int = gt_txusrclk2;

always @(posedge gt_txusrclk, posedge gt_tx_reset) begin
    if (gt_tx_reset) begin
        gt_userclk_tx_active <= 1'b0;
    end else begin
        gt_userclk_tx_active <= 1'b1;
    end
end

generate

genvar n;

for (n = 0 ; n < 2; n = n + 1) begin

    BUFG_GT bufg_gt_rx_usrclk_0_inst (
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (gt_rx_reset),
        .CLRMASK (1'b0),
        .DIV     (3'd0),
        .I       (gt_rxclkout[n]),
        .O       (gt_rxusrclk[n])
    );

    BUFG_GT bufg_gt_rx_usrclk2_0_inst (
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (gt_rx_reset),
        .CLRMASK (1'b0),
        .DIV     (3'd1),
        .I       (gt_rxclkout[n]),
        .O       (gt_rxusrclk2[n])
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
    .sync_reset_out(rst_156mhz_int)
);

wire [5:0] sfp_1_gt_txheader;
wire [127:0] sfp_1_gt_txdata;
wire sfp_1_gt_rxgearboxslip;
wire [5:0] sfp_1_gt_rxheader;
wire [1:0] sfp_1_gt_rxheadervalid;
wire [127:0] sfp_1_gt_rxdata;
wire [1:0] sfp_1_gt_rxdatavalid;

wire [5:0] sfp_2_gt_txheader;
wire [127:0] sfp_2_gt_txdata;
wire sfp_2_gt_rxgearboxslip;
wire [5:0] sfp_2_gt_rxheader;
wire [1:0] sfp_2_gt_rxheadervalid;
wire [127:0] sfp_2_gt_rxdata;
wire [1:0] sfp_2_gt_rxdatavalid;

gtwizard_ultrascale_0
sfp_gth_inst (
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

    .gtrefclk00_in(sfp_mgt_refclk),

    .qpll0outclk_out(),
    .qpll0outrefclk_out(),

    .rxpmareset_in(2'd0),

    .gthrxn_in({sfp_2_rx_n, sfp_1_rx_n}),
    .gthrxp_in({sfp_2_rx_p, sfp_1_rx_p}),

    .rxusrclk_in(gt_rxusrclk),
    .rxusrclk2_in(gt_rxusrclk2),

    .txdata_in({sfp_2_gt_txdata, sfp_1_gt_txdata}),
    .txheader_in({sfp_2_gt_txheader, sfp_1_gt_txheader}),
    .txsequence_in({2{7'b0}}),

    .txusrclk_in({2{gt_txusrclk}}),
    .txusrclk2_in({2{gt_txusrclk2}}),

    .gtpowergood_out(),

    .gthtxn_out({sfp_2_tx_n, sfp_1_tx_n}),
    .gthtxp_out({sfp_2_tx_p, sfp_1_tx_p}),

    .txpolarity_in(2'b11),
    .rxpolarity_in(2'b00),

    .rxgearboxslip_in({sfp_2_gt_rxgearboxslip, sfp_1_gt_rxgearboxslip}),
    .rxdata_out({sfp_2_gt_rxdata, sfp_1_gt_rxdata}),
    .rxdatavalid_out({sfp_2_gt_rxdatavalid, sfp_1_gt_rxdatavalid}),
    .rxheader_out({sfp_2_gt_rxheader, sfp_1_gt_rxheader}),
    .rxheadervalid_out({sfp_2_gt_rxheadervalid, sfp_1_gt_rxheadervalid}),
    .rxoutclk_out(gt_rxclkout),
    .rxpmaresetdone_out(gt_rxpmaresetdone),
    .rxprgdivresetdone_out(gt_rxprgdivresetdone),
    .rxstartofseq_out(),

    .txoutclk_out(gt_txclkout),
    .txpmaresetdone_out(gt_txpmaresetdone),
    .txprgdivresetdone_out(gt_txprgdivresetdone)
);

assign sfp_1_tx_clk_int = clk_156mhz_int;
assign sfp_1_tx_rst_int = rst_156mhz_int;

assign sfp_1_rx_clk_int = gt_rxusrclk2[0];

sync_reset #(
    .N(4)
)
sfp_1_rx_rst_reset_sync_inst (
    .clk(sfp_1_rx_clk_int),
    .rst(~gt_reset_rx_done),
    .sync_reset_out(sfp_1_rx_rst_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1)
)
sfp_1_phy_inst (
    .tx_clk(sfp_1_tx_clk_int),
    .tx_rst(sfp_1_tx_rst_int),
    .rx_clk(sfp_1_rx_clk_int),
    .rx_rst(sfp_1_rx_rst_int),
    .xgmii_txd(sfp_1_txd_int),
    .xgmii_txc(sfp_1_txc_int),
    .xgmii_rxd(sfp_1_rxd_int),
    .xgmii_rxc(sfp_1_rxc_int),
    .serdes_tx_data(sfp_1_gt_txdata),
    .serdes_tx_hdr(sfp_1_gt_txheader),
    .serdes_rx_data(sfp_1_gt_rxdata),
    .serdes_rx_hdr(sfp_1_gt_rxheader),
    .serdes_rx_bitslip(sfp_1_gt_rxgearboxslip),
    .rx_block_lock(sfp_1_rx_block_lock),
    .rx_high_ber()
);

assign sfp_2_tx_clk_int = clk_156mhz_int;
assign sfp_2_tx_rst_int = rst_156mhz_int;

assign sfp_2_rx_clk_int = gt_rxusrclk2[1];

sync_reset #(
    .N(4)
)
sfp_2_rx_rst_reset_sync_inst (
    .clk(sfp_2_rx_clk_int),
    .rst(~gt_reset_rx_done),
    .sync_reset_out(sfp_2_rx_rst_int)
);

eth_phy_10g #(
    .BIT_REVERSE(1)
)
sfp_2_phy_inst (
    .tx_clk(sfp_2_tx_clk_int),
    .tx_rst(sfp_2_tx_rst_int),
    .rx_clk(sfp_2_rx_clk_int),
    .rx_rst(sfp_2_rx_rst_int),
    .xgmii_txd(sfp_2_txd_int),
    .xgmii_txc(sfp_2_txc_int),
    .xgmii_rxd(sfp_2_rxd_int),
    .xgmii_rxc(sfp_2_rxc_int),
    .serdes_tx_data(sfp_2_gt_txdata),
    .serdes_tx_hdr(sfp_2_gt_txheader),
    .serdes_rx_data(sfp_2_gt_rxdata),
    .serdes_rx_hdr(sfp_2_gt_rxheader),
    .serdes_rx_bitslip(sfp_2_gt_rxgearboxslip),
    .rx_block_lock(sfp_2_rx_block_lock),
    .rx_high_ber()
);

assign sfp_1_led[0] = sfp_1_rx_block_lock;
assign sfp_1_led[1] = 1'b0;
assign sfp_2_led[0] = sfp_2_rx_block_lock;
assign sfp_2_led[1] = 1'b0;

fpga_core #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH)
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
    //.sfp_1_led(sfp_1_led),
    //.sfp_2_led(sfp_2_led),
    .sma_led(sma_led),

    .sma_in(sma_in),
    .sma_out(sma_out),
    .sma_out_en(sma_out_en),
    .sma_term_en(sma_term_en),

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

    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_vf_enable(cfg_interrupt_msi_vf_enable),
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

    .sfp_i2c_scl_i(sfp_i2c_scl_i),
    .sfp_i2c_scl_o(sfp_i2c_scl_o),
    .sfp_i2c_scl_t(sfp_i2c_scl_t),
    .sfp_1_i2c_sda_i(sfp_1_i2c_sda_i),
    .sfp_1_i2c_sda_o(sfp_1_i2c_sda_o),
    .sfp_1_i2c_sda_t(sfp_1_i2c_sda_t),
    .sfp_2_i2c_sda_i(sfp_2_i2c_sda_i),
    .sfp_2_i2c_sda_o(sfp_2_i2c_sda_o),
    .sfp_2_i2c_sda_t(sfp_2_i2c_sda_t),

    .eeprom_i2c_scl_i(eeprom_i2c_scl_i),
    .eeprom_i2c_scl_o(eeprom_i2c_scl_o),
    .eeprom_i2c_scl_t(eeprom_i2c_scl_t),
    .eeprom_i2c_sda_i(eeprom_i2c_sda_i),
    .eeprom_i2c_sda_o(eeprom_i2c_sda_o),
    .eeprom_i2c_sda_t(eeprom_i2c_sda_t),

    /*
     * BPI flash
     */
    .flash_dq_i(flash_dq_i_int),
    .flash_dq_o(flash_dq_o_int),
    .flash_dq_oe(flash_dq_oe_int),
    .flash_addr(flash_addr_int),
    .flash_region(flash_region_int),
    .flash_region_oe(flash_region_oe_int),
    .flash_ce_n(flash_ce_n_int),
    .flash_oe_n(flash_oe_n_int),
    .flash_we_n(flash_we_n_int),
    .flash_adv_n(flash_adv_n_int)
);

endmodule
