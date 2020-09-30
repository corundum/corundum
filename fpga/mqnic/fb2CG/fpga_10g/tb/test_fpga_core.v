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
 * Testbench for fpga_core
 */
module test_fpga_core;

// Parameters
parameter AXIS_PCIE_DATA_WIDTH = 512;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_RC_USER_WIDTH = 161;
parameter AXIS_PCIE_RQ_USER_WIDTH = 137;
parameter AXIS_PCIE_CQ_USER_WIDTH = 183;
parameter AXIS_PCIE_CC_USER_WIDTH = 81;
parameter RQ_SEQ_NUM_WIDTH = 6;
parameter BAR0_APERTURE = 24;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg clk_250mhz = 0;
reg rst_250mhz = 0;
reg m_axis_rq_tready = 0;
reg [AXIS_PCIE_DATA_WIDTH-1:0] s_axis_rc_tdata = 0;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] s_axis_rc_tkeep = 0;
reg s_axis_rc_tlast = 0;
reg [AXIS_PCIE_RC_USER_WIDTH-1:0] s_axis_rc_tuser = 0;
reg s_axis_rc_tvalid = 0;
reg [AXIS_PCIE_DATA_WIDTH-1:0] s_axis_cq_tdata = 0;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] s_axis_cq_tkeep = 0;
reg s_axis_cq_tlast = 0;
reg [AXIS_PCIE_CQ_USER_WIDTH-1:0] s_axis_cq_tuser = 0;
reg s_axis_cq_tvalid = 0;
reg m_axis_cc_tready = 0;
reg [RQ_SEQ_NUM_WIDTH-1:0] s_axis_rq_seq_num_0 = 0;
reg s_axis_rq_seq_num_valid_0 = 0;
reg [RQ_SEQ_NUM_WIDTH-1:0] s_axis_rq_seq_num_1 = 0;
reg s_axis_rq_seq_num_valid_1 = 0;
reg [3:0] pcie_tfc_nph_av = 0;
reg [3:0] pcie_tfc_npd_av = 0;
reg [2:0] cfg_max_payload = 0;
reg [2:0] cfg_max_read_req = 0;
reg [31:0] cfg_mgmt_read_data = 0;
reg cfg_mgmt_read_write_done = 0;
reg [7:0] cfg_fc_ph = 0;
reg [11:0] cfg_fc_pd = 0;
reg [7:0] cfg_fc_nph = 0;
reg [11:0] cfg_fc_npd = 0;
reg [7:0] cfg_fc_cplh = 0;
reg [11:0] cfg_fc_cpld = 0;
reg [3:0] cfg_interrupt_msi_enable = 0;
reg [11:0] cfg_interrupt_msi_mmenable = 0;
reg cfg_interrupt_msi_mask_update = 0;
reg [31:0] cfg_interrupt_msi_data = 0;
reg cfg_interrupt_msi_sent = 0;
reg cfg_interrupt_msi_fail = 0;
reg qsfp_0_tx_clk_0 = 0;
reg qsfp_0_tx_rst_0 = 0;
reg qsfp_0_rx_clk_0 = 0;
reg qsfp_0_rx_rst_0 = 0;
reg [63:0] qsfp_0_rxd_0 = 0;
reg [7:0] qsfp_0_rxc_0 = 0;
reg qsfp_0_tx_clk_1 = 0;
reg qsfp_0_tx_rst_1 = 0;
reg qsfp_0_rx_clk_1 = 0;
reg qsfp_0_rx_rst_1 = 0;
reg [63:0] qsfp_0_rxd_1 = 0;
reg [7:0] qsfp_0_rxc_1 = 0;
reg qsfp_0_tx_clk_2 = 0;
reg qsfp_0_tx_rst_2 = 0;
reg qsfp_0_rx_clk_2 = 0;
reg qsfp_0_rx_rst_2 = 0;
reg [63:0] qsfp_0_rxd_2 = 0;
reg [7:0] qsfp_0_rxc_2 = 0;
reg qsfp_0_tx_clk_3 = 0;
reg qsfp_0_tx_rst_3 = 0;
reg qsfp_0_rx_clk_3 = 0;
reg qsfp_0_rx_rst_3 = 0;
reg [63:0] qsfp_0_rxd_3 = 0;
reg [7:0] qsfp_0_rxc_3 = 0;
reg qsfp_0_mod_prsnt_n = 0;
reg qsfp_0_intr_n = 0;
reg qsfp_0_i2c_scl_i = 1;
reg qsfp_0_i2c_sda_i = 1;
reg qsfp_1_tx_clk_0 = 0;
reg qsfp_1_tx_rst_0 = 0;
reg qsfp_1_rx_clk_0 = 0;
reg qsfp_1_rx_rst_0 = 0;
reg [63:0] qsfp_1_rxd_0 = 0;
reg [7:0] qsfp_1_rxc_0 = 0;
reg qsfp_1_tx_clk_1 = 0;
reg qsfp_1_tx_rst_1 = 0;
reg qsfp_1_rx_clk_1 = 0;
reg qsfp_1_rx_rst_1 = 0;
reg [63:0] qsfp_1_rxd_1 = 0;
reg [7:0] qsfp_1_rxc_1 = 0;
reg qsfp_1_tx_clk_2 = 0;
reg qsfp_1_tx_rst_2 = 0;
reg qsfp_1_rx_clk_2 = 0;
reg qsfp_1_rx_rst_2 = 0;
reg [63:0] qsfp_1_rxd_2 = 0;
reg [7:0] qsfp_1_rxc_2 = 0;
reg qsfp_1_tx_clk_3 = 0;
reg qsfp_1_tx_rst_3 = 0;
reg qsfp_1_rx_clk_3 = 0;
reg qsfp_1_rx_rst_3 = 0;
reg [63:0] qsfp_1_rxd_3 = 0;
reg [7:0] qsfp_1_rxc_3 = 0;
reg qsfp_1_mod_prsnt_n = 0;
reg qsfp_1_intr_n = 0;
reg qsfp_1_i2c_scl_i = 1;
reg qsfp_1_i2c_sda_i = 1;
reg [3:0] qspi_dq_i = 0;

// Outputs
wire [7:0] led_red;
wire [7:0] led_green;
wire [1:0] led_bmc;
wire [1:0] led_exp;
wire [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_rq_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_rq_tkeep;
wire m_axis_rq_tlast;
wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser;
wire m_axis_rq_tvalid;
wire s_axis_rc_tready;
wire s_axis_cq_tready;
wire [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_cc_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_cc_tkeep;
wire m_axis_cc_tlast;
wire [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser;
wire m_axis_cc_tvalid;
wire [9:0] cfg_mgmt_addr;
wire [7:0] cfg_mgmt_function_number;
wire cfg_mgmt_write;
wire [31:0] cfg_mgmt_write_data;
wire [3:0] cfg_mgmt_byte_enable;
wire cfg_mgmt_read;
wire [2:0] cfg_fc_sel;
wire [3:0] cfg_interrupt_msi_select;
wire [31:0] cfg_interrupt_msi_int;
wire [31:0] cfg_interrupt_msi_pending_status;
wire cfg_interrupt_msi_pending_status_data_enable;
wire [3:0] cfg_interrupt_msi_pending_status_function_num;
wire [2:0] cfg_interrupt_msi_attr;
wire cfg_interrupt_msi_tph_present;
wire [1:0] cfg_interrupt_msi_tph_type;
wire [8:0] cfg_interrupt_msi_tph_st_tag;
wire [3:0] cfg_interrupt_msi_function_number;
wire status_error_cor;
wire status_error_uncor;
wire [63:0] qsfp_0_txd_0;
wire [7:0] qsfp_0_txc_0;
wire [63:0] qsfp_0_txd_1;
wire [7:0] qsfp_0_txc_1;
wire [63:0] qsfp_0_txd_2;
wire [7:0] qsfp_0_txc_2;
wire [63:0] qsfp_0_txd_3;
wire [7:0] qsfp_0_txc_3;
wire qsfp_0_reset_n;
wire qsfp_0_lp_mode;
wire qsfp_0_i2c_scl_o;
wire qsfp_0_i2c_scl_t;
wire qsfp_0_i2c_sda_o;
wire qsfp_0_i2c_sda_t;
wire [63:0] qsfp_1_txd_0;
wire [7:0] qsfp_1_txc_0;
wire [63:0] qsfp_1_txd_1;
wire [7:0] qsfp_1_txc_1;
wire [63:0] qsfp_1_txd_2;
wire [7:0] qsfp_1_txc_2;
wire [63:0] qsfp_1_txd_3;
wire [7:0] qsfp_1_txc_3;
wire qsfp_1_reset_n;
wire qsfp_1_lp_mode;
wire qsfp_1_i2c_scl_o;
wire qsfp_1_i2c_scl_t;
wire qsfp_1_i2c_sda_o;
wire qsfp_1_i2c_sda_t;
wire fpga_boot;
wire qspi_clk;
wire [3:0] qspi_dq_o;
wire [3:0] qspi_dq_oe;
wire qspi_cs;

initial begin
    // myhdl integration
    $from_myhdl(
        clk_250mhz,
        rst_250mhz,
        current_test,
        m_axis_rq_tready,
        s_axis_rc_tdata,
        s_axis_rc_tkeep,
        s_axis_rc_tlast,
        s_axis_rc_tuser,
        s_axis_rc_tvalid,
        s_axis_cq_tdata,
        s_axis_cq_tkeep,
        s_axis_cq_tlast,
        s_axis_cq_tuser,
        s_axis_cq_tvalid,
        m_axis_cc_tready,
        s_axis_rq_seq_num_0,
        s_axis_rq_seq_num_valid_0,
        s_axis_rq_seq_num_1,
        s_axis_rq_seq_num_valid_1,
        pcie_tfc_nph_av,
        pcie_tfc_npd_av,
        cfg_max_payload,
        cfg_max_read_req,
        cfg_mgmt_read_data,
        cfg_mgmt_read_write_done,
        cfg_fc_ph,
        cfg_fc_pd,
        cfg_fc_nph,
        cfg_fc_npd,
        cfg_fc_cplh,
        cfg_fc_cpld,
        cfg_interrupt_msi_enable,
        cfg_interrupt_msi_mmenable,
        cfg_interrupt_msi_mask_update,
        cfg_interrupt_msi_data,
        cfg_interrupt_msi_sent,
        cfg_interrupt_msi_fail,
        qsfp_0_tx_clk_0,
        qsfp_0_tx_rst_0,
        qsfp_0_rx_clk_0,
        qsfp_0_rx_rst_0,
        qsfp_0_rxd_0,
        qsfp_0_rxc_0,
        qsfp_0_tx_clk_1,
        qsfp_0_tx_rst_1,
        qsfp_0_rx_clk_1,
        qsfp_0_rx_rst_1,
        qsfp_0_rxd_1,
        qsfp_0_rxc_1,
        qsfp_0_tx_clk_2,
        qsfp_0_tx_rst_2,
        qsfp_0_rx_clk_2,
        qsfp_0_rx_rst_2,
        qsfp_0_rxd_2,
        qsfp_0_rxc_2,
        qsfp_0_tx_clk_3,
        qsfp_0_tx_rst_3,
        qsfp_0_rx_clk_3,
        qsfp_0_rx_rst_3,
        qsfp_0_rxd_3,
        qsfp_0_rxc_3,
        qsfp_0_mod_prsnt_n,
        qsfp_0_intr_n,
        qsfp_0_i2c_scl_i,
        qsfp_0_i2c_sda_i,
        qsfp_1_tx_clk_0,
        qsfp_1_tx_rst_0,
        qsfp_1_rx_clk_0,
        qsfp_1_rx_rst_0,
        qsfp_1_rxd_0,
        qsfp_1_rxc_0,
        qsfp_1_tx_clk_1,
        qsfp_1_tx_rst_1,
        qsfp_1_rx_clk_1,
        qsfp_1_rx_rst_1,
        qsfp_1_rxd_1,
        qsfp_1_rxc_1,
        qsfp_1_tx_clk_2,
        qsfp_1_tx_rst_2,
        qsfp_1_rx_clk_2,
        qsfp_1_rx_rst_2,
        qsfp_1_rxd_2,
        qsfp_1_rxc_2,
        qsfp_1_tx_clk_3,
        qsfp_1_tx_rst_3,
        qsfp_1_rx_clk_3,
        qsfp_1_rx_rst_3,
        qsfp_1_rxd_3,
        qsfp_1_rxc_3,
        qsfp_1_mod_prsnt_n,
        qsfp_1_intr_n,
        qsfp_1_i2c_scl_i,
        qsfp_1_i2c_sda_i,
        qspi_dq_i
    );
    $to_myhdl(
        led_red,
        led_green,
        led_bmc,
        led_exp,
        m_axis_rq_tdata,
        m_axis_rq_tkeep,
        m_axis_rq_tlast,
        m_axis_rq_tuser,
        m_axis_rq_tvalid,
        s_axis_rc_tready,
        s_axis_cq_tready,
        m_axis_cc_tdata,
        m_axis_cc_tkeep,
        m_axis_cc_tlast,
        m_axis_cc_tuser,
        m_axis_cc_tvalid,
        cfg_mgmt_addr,
        cfg_mgmt_function_number,
        cfg_mgmt_write,
        cfg_mgmt_write_data,
        cfg_mgmt_byte_enable,
        cfg_mgmt_read,
        cfg_fc_sel,
        cfg_interrupt_msi_select,
        cfg_interrupt_msi_int,
        cfg_interrupt_msi_pending_status,
        cfg_interrupt_msi_pending_status_data_enable,
        cfg_interrupt_msi_pending_status_function_num,
        cfg_interrupt_msi_attr,
        cfg_interrupt_msi_tph_present,
        cfg_interrupt_msi_tph_type,
        cfg_interrupt_msi_tph_st_tag,
        cfg_interrupt_msi_function_number,
        status_error_cor,
        status_error_uncor,
        qsfp_0_txd_0,
        qsfp_0_txc_0,
        qsfp_0_txd_1,
        qsfp_0_txc_1,
        qsfp_0_txd_2,
        qsfp_0_txc_2,
        qsfp_0_txd_3,
        qsfp_0_txc_3,
        qsfp_0_reset_n,
        qsfp_0_lp_mode,
        qsfp_0_i2c_scl_o,
        qsfp_0_i2c_scl_t,
        qsfp_0_i2c_sda_o,
        qsfp_0_i2c_sda_t,
        qsfp_1_txd_0,
        qsfp_1_txc_0,
        qsfp_1_txd_1,
        qsfp_1_txc_1,
        qsfp_1_txd_2,
        qsfp_1_txc_2,
        qsfp_1_txd_3,
        qsfp_1_txc_3,
        qsfp_1_reset_n,
        qsfp_1_lp_mode,
        qsfp_1_i2c_scl_o,
        qsfp_1_i2c_scl_t,
        qsfp_1_i2c_sda_o,
        qsfp_1_i2c_sda_t,
        fpga_boot,
        qspi_clk,
        qspi_dq_o,
        qspi_dq_oe,
        qspi_cs
    );

    // dump file
    $dumpfile("test_fpga_core.lxt");
    $dumpvars(0, test_fpga_core);
end

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
UUT (
    .clk_250mhz(clk_250mhz),
    .rst_250mhz(rst_250mhz),
    .led_red(led_red),
    .led_green(led_green),
    .led_bmc(led_bmc),
    .led_exp(led_exp),
    .m_axis_rq_tdata(m_axis_rq_tdata),
    .m_axis_rq_tkeep(m_axis_rq_tkeep),
    .m_axis_rq_tlast(m_axis_rq_tlast),
    .m_axis_rq_tready(m_axis_rq_tready),
    .m_axis_rq_tuser(m_axis_rq_tuser),
    .m_axis_rq_tvalid(m_axis_rq_tvalid),
    .s_axis_rc_tdata(s_axis_rc_tdata),
    .s_axis_rc_tkeep(s_axis_rc_tkeep),
    .s_axis_rc_tlast(s_axis_rc_tlast),
    .s_axis_rc_tready(s_axis_rc_tready),
    .s_axis_rc_tuser(s_axis_rc_tuser),
    .s_axis_rc_tvalid(s_axis_rc_tvalid),
    .s_axis_cq_tdata(s_axis_cq_tdata),
    .s_axis_cq_tkeep(s_axis_cq_tkeep),
    .s_axis_cq_tlast(s_axis_cq_tlast),
    .s_axis_cq_tready(s_axis_cq_tready),
    .s_axis_cq_tuser(s_axis_cq_tuser),
    .s_axis_cq_tvalid(s_axis_cq_tvalid),
    .m_axis_cc_tdata(m_axis_cc_tdata),
    .m_axis_cc_tkeep(m_axis_cc_tkeep),
    .m_axis_cc_tlast(m_axis_cc_tlast),
    .m_axis_cc_tready(m_axis_cc_tready),
    .m_axis_cc_tuser(m_axis_cc_tuser),
    .m_axis_cc_tvalid(m_axis_cc_tvalid),
    .s_axis_rq_seq_num_0(s_axis_rq_seq_num_0),
    .s_axis_rq_seq_num_valid_0(s_axis_rq_seq_num_valid_0),
    .s_axis_rq_seq_num_1(s_axis_rq_seq_num_1),
    .s_axis_rq_seq_num_valid_1(s_axis_rq_seq_num_valid_1),
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
    .qsfp_0_tx_clk_0(qsfp_0_tx_clk_0),
    .qsfp_0_tx_rst_0(qsfp_0_tx_rst_0),
    .qsfp_0_txd_0(qsfp_0_txd_0),
    .qsfp_0_txc_0(qsfp_0_txc_0),
    .qsfp_0_rx_clk_0(qsfp_0_rx_clk_0),
    .qsfp_0_rx_rst_0(qsfp_0_rx_rst_0),
    .qsfp_0_rxd_0(qsfp_0_rxd_0),
    .qsfp_0_rxc_0(qsfp_0_rxc_0),
    .qsfp_0_tx_clk_1(qsfp_0_tx_clk_1),
    .qsfp_0_tx_rst_1(qsfp_0_tx_rst_1),
    .qsfp_0_txd_1(qsfp_0_txd_1),
    .qsfp_0_txc_1(qsfp_0_txc_1),
    .qsfp_0_rx_clk_1(qsfp_0_rx_clk_1),
    .qsfp_0_rx_rst_1(qsfp_0_rx_rst_1),
    .qsfp_0_rxd_1(qsfp_0_rxd_1),
    .qsfp_0_rxc_1(qsfp_0_rxc_1),
    .qsfp_0_tx_clk_2(qsfp_0_tx_clk_2),
    .qsfp_0_tx_rst_2(qsfp_0_tx_rst_2),
    .qsfp_0_txd_2(qsfp_0_txd_2),
    .qsfp_0_txc_2(qsfp_0_txc_2),
    .qsfp_0_rx_clk_2(qsfp_0_rx_clk_2),
    .qsfp_0_rx_rst_2(qsfp_0_rx_rst_2),
    .qsfp_0_rxd_2(qsfp_0_rxd_2),
    .qsfp_0_rxc_2(qsfp_0_rxc_2),
    .qsfp_0_tx_clk_3(qsfp_0_tx_clk_3),
    .qsfp_0_tx_rst_3(qsfp_0_tx_rst_3),
    .qsfp_0_txd_3(qsfp_0_txd_3),
    .qsfp_0_txc_3(qsfp_0_txc_3),
    .qsfp_0_rx_clk_3(qsfp_0_rx_clk_3),
    .qsfp_0_rx_rst_3(qsfp_0_rx_rst_3),
    .qsfp_0_rxd_3(qsfp_0_rxd_3),
    .qsfp_0_rxc_3(qsfp_0_rxc_3),
    .qsfp_0_mod_prsnt_n(qsfp_0_mod_prsnt_n),
    .qsfp_0_reset_n(qsfp_0_reset_n),
    .qsfp_0_lp_mode(qsfp_0_lp_mode),
    .qsfp_0_intr_n(qsfp_0_intr_n),
    .qsfp_0_i2c_scl_i(qsfp_0_i2c_scl_i),
    .qsfp_0_i2c_scl_o(qsfp_0_i2c_scl_o),
    .qsfp_0_i2c_scl_t(qsfp_0_i2c_scl_t),
    .qsfp_0_i2c_sda_i(qsfp_0_i2c_sda_i),
    .qsfp_0_i2c_sda_o(qsfp_0_i2c_sda_o),
    .qsfp_0_i2c_sda_t(qsfp_0_i2c_sda_t),
    .qsfp_1_tx_clk_0(qsfp_1_tx_clk_0),
    .qsfp_1_tx_rst_0(qsfp_1_tx_rst_0),
    .qsfp_1_txd_0(qsfp_1_txd_0),
    .qsfp_1_txc_0(qsfp_1_txc_0),
    .qsfp_1_rx_clk_0(qsfp_1_rx_clk_0),
    .qsfp_1_rx_rst_0(qsfp_1_rx_rst_0),
    .qsfp_1_rxd_0(qsfp_1_rxd_0),
    .qsfp_1_rxc_0(qsfp_1_rxc_0),
    .qsfp_1_tx_clk_1(qsfp_1_tx_clk_1),
    .qsfp_1_tx_rst_1(qsfp_1_tx_rst_1),
    .qsfp_1_txd_1(qsfp_1_txd_1),
    .qsfp_1_txc_1(qsfp_1_txc_1),
    .qsfp_1_rx_clk_1(qsfp_1_rx_clk_1),
    .qsfp_1_rx_rst_1(qsfp_1_rx_rst_1),
    .qsfp_1_rxd_1(qsfp_1_rxd_1),
    .qsfp_1_rxc_1(qsfp_1_rxc_1),
    .qsfp_1_tx_clk_2(qsfp_1_tx_clk_2),
    .qsfp_1_tx_rst_2(qsfp_1_tx_rst_2),
    .qsfp_1_txd_2(qsfp_1_txd_2),
    .qsfp_1_txc_2(qsfp_1_txc_2),
    .qsfp_1_rx_clk_2(qsfp_1_rx_clk_2),
    .qsfp_1_rx_rst_2(qsfp_1_rx_rst_2),
    .qsfp_1_rxd_2(qsfp_1_rxd_2),
    .qsfp_1_rxc_2(qsfp_1_rxc_2),
    .qsfp_1_tx_clk_3(qsfp_1_tx_clk_3),
    .qsfp_1_tx_rst_3(qsfp_1_tx_rst_3),
    .qsfp_1_txd_3(qsfp_1_txd_3),
    .qsfp_1_txc_3(qsfp_1_txc_3),
    .qsfp_1_rx_clk_3(qsfp_1_rx_clk_3),
    .qsfp_1_rx_rst_3(qsfp_1_rx_rst_3),
    .qsfp_1_rxd_3(qsfp_1_rxd_3),
    .qsfp_1_rxc_3(qsfp_1_rxc_3),
    .qsfp_1_mod_prsnt_n(qsfp_1_mod_prsnt_n),
    .qsfp_1_reset_n(qsfp_1_reset_n),
    .qsfp_1_lp_mode(qsfp_1_lp_mode),
    .qsfp_1_intr_n(qsfp_1_intr_n),
    .qsfp_1_i2c_scl_i(qsfp_1_i2c_scl_i),
    .qsfp_1_i2c_scl_o(qsfp_1_i2c_scl_o),
    .qsfp_1_i2c_scl_t(qsfp_1_i2c_scl_t),
    .qsfp_1_i2c_sda_i(qsfp_1_i2c_sda_i),
    .qsfp_1_i2c_sda_o(qsfp_1_i2c_sda_o),
    .qsfp_1_i2c_sda_t(qsfp_1_i2c_sda_t),
    .fpga_boot(fpga_boot),
    .qspi_clk(qspi_clk),
    .qspi_dq_i(qspi_dq_i),
    .qspi_dq_o(qspi_dq_o),
    .qspi_dq_oe(qspi_dq_oe),
    .qspi_cs(qspi_cs)
);

endmodule
