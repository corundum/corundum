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

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg clk_156mhz = 0;
reg rst_156mhz = 0;
reg clk_250mhz = 0;
reg rst_250mhz = 0;
reg btnu = 0;
reg btnl = 0;
reg btnd = 0;
reg btnr = 0;
reg btnc = 0;
reg [3:0] sw = 0;
reg i2c_scl_i = 1;
reg i2c_sda_i = 1;
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
reg [3:0] pcie_tfc_nph_av = 0;
reg [3:0] pcie_tfc_npd_av = 0;
reg [2:0] cfg_max_payload = 0;
reg [2:0] cfg_max_read_req = 0;
reg [31:0] cfg_mgmt_read_data = 0;
reg cfg_mgmt_read_write_done = 0;
reg [3:0] cfg_interrupt_msi_enable = 0;
reg [11:0] cfg_interrupt_msi_mmenable = 0;
reg cfg_interrupt_msi_mask_update = 0;
reg [31:0] cfg_interrupt_msi_data = 0;
reg cfg_interrupt_msi_sent = 0;
reg cfg_interrupt_msi_fail = 0;
reg qsfp1_tx_clk_1 = 0;
reg qsfp1_tx_rst_1 = 0;
reg qsfp1_rx_clk_1 = 0;
reg qsfp1_rx_rst_1 = 0;
reg [63:0] qsfp1_rxd_1 = 0;
reg [7:0] qsfp1_rxc_1 = 0;
reg qsfp1_tx_clk_2 = 0;
reg qsfp1_tx_rst_2 = 0;
reg qsfp1_rx_clk_2 = 0;
reg qsfp1_rx_rst_2 = 0;
reg [63:0] qsfp1_rxd_2 = 0;
reg [7:0] qsfp1_rxc_2 = 0;
reg qsfp1_tx_clk_3 = 0;
reg qsfp1_tx_rst_3 = 0;
reg qsfp1_rx_clk_3 = 0;
reg qsfp1_rx_rst_3 = 0;
reg [63:0] qsfp1_rxd_3 = 0;
reg [7:0] qsfp1_rxc_3 = 0;
reg qsfp1_tx_clk_4 = 0;
reg qsfp1_tx_rst_4 = 0;
reg qsfp1_rx_clk_4 = 0;
reg qsfp1_rx_rst_4 = 0;
reg [63:0] qsfp1_rxd_4 = 0;
reg [7:0] qsfp1_rxc_4 = 0;
reg qsfp1_modprsl = 1;
reg qsfp1_intl = 1;
reg qsfp2_tx_clk_1 = 0;
reg qsfp2_tx_rst_1 = 0;
reg qsfp2_rx_clk_1 = 0;
reg qsfp2_rx_rst_1 = 0;
reg [63:0] qsfp2_rxd_1 = 0;
reg [7:0] qsfp2_rxc_1 = 0;
reg qsfp2_tx_clk_2 = 0;
reg qsfp2_tx_rst_2 = 0;
reg qsfp2_rx_clk_2 = 0;
reg qsfp2_rx_rst_2 = 0;
reg [63:0] qsfp2_rxd_2 = 0;
reg [7:0] qsfp2_rxc_2 = 0;
reg qsfp2_tx_clk_3 = 0;
reg qsfp2_tx_rst_3 = 0;
reg qsfp2_rx_clk_3 = 0;
reg qsfp2_rx_rst_3 = 0;
reg [63:0] qsfp2_rxd_3 = 0;
reg [7:0] qsfp2_rxc_3 = 0;
reg qsfp2_tx_clk_4 = 0;
reg qsfp2_tx_rst_4 = 0;
reg qsfp2_rx_clk_4 = 0;
reg qsfp2_rx_rst_4 = 0;
reg [63:0] qsfp2_rxd_4 = 0;
reg [7:0] qsfp2_rxc_4 = 0;
reg qsfp2_modprsl = 1;
reg qsfp2_intl = 1;

// Outputs
wire [7:0] led;
wire i2c_scl_o;
wire i2c_scl_t;
wire i2c_sda_o;
wire i2c_sda_t;
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
wire [63:0] qsfp1_txd_1;
wire [7:0] qsfp1_txc_1;
wire [63:0] qsfp1_txd_2;
wire [7:0] qsfp1_txc_2;
wire [63:0] qsfp1_txd_3;
wire [7:0] qsfp1_txc_3;
wire [63:0] qsfp1_txd_4;
wire [7:0] qsfp1_txc_4;
wire qsfp1_modsell;
wire qsfp1_resetl;
wire qsfp1_lpmode;
wire [63:0] qsfp2_txd_1;
wire [7:0] qsfp2_txc_1;
wire [63:0] qsfp2_txd_2;
wire [7:0] qsfp2_txc_2;
wire [63:0] qsfp2_txd_3;
wire [7:0] qsfp2_txc_3;
wire [63:0] qsfp2_txd_4;
wire [7:0] qsfp2_txc_4;
wire qsfp2_modsell;
wire qsfp2_resetl;
wire qsfp2_lpmode;

initial begin
    // myhdl integration
    $from_myhdl(
        clk_156mhz,
        rst_156mhz,
        clk_250mhz,
        rst_250mhz,
        current_test,
        btnu,
        btnl,
        btnd,
        btnr,
        btnc,
        sw,
        i2c_scl_i,
        i2c_sda_i,
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
        pcie_tfc_nph_av,
        pcie_tfc_npd_av,
        cfg_max_payload,
        cfg_max_read_req,
        cfg_mgmt_read_data,
        cfg_mgmt_read_write_done,
        cfg_interrupt_msi_enable,
        cfg_interrupt_msi_mmenable,
        cfg_interrupt_msi_mask_update,
        cfg_interrupt_msi_data,
        cfg_interrupt_msi_sent,
        cfg_interrupt_msi_fail,
        qsfp1_tx_clk_1,
        qsfp1_tx_rst_1,
        qsfp1_rx_clk_1,
        qsfp1_rx_rst_1,
        qsfp1_rxd_1,
        qsfp1_rxc_1,
        qsfp1_tx_clk_2,
        qsfp1_tx_rst_2,
        qsfp1_rx_clk_2,
        qsfp1_rx_rst_2,
        qsfp1_rxd_2,
        qsfp1_rxc_2,
        qsfp1_tx_clk_3,
        qsfp1_tx_rst_3,
        qsfp1_rx_clk_3,
        qsfp1_rx_rst_3,
        qsfp1_rxd_3,
        qsfp1_rxc_3,
        qsfp1_tx_clk_4,
        qsfp1_tx_rst_4,
        qsfp1_rx_clk_4,
        qsfp1_rx_rst_4,
        qsfp1_rxd_4,
        qsfp1_rxc_4,
        qsfp1_modprsl,
        qsfp1_intl,
        qsfp2_tx_clk_1,
        qsfp2_tx_rst_1,
        qsfp2_rx_clk_1,
        qsfp2_rx_rst_1,
        qsfp2_rxd_1,
        qsfp2_rxc_1,
        qsfp2_tx_clk_2,
        qsfp2_tx_rst_2,
        qsfp2_rx_clk_2,
        qsfp2_rx_rst_2,
        qsfp2_rxd_2,
        qsfp2_rxc_2,
        qsfp2_tx_clk_3,
        qsfp2_tx_rst_3,
        qsfp2_rx_clk_3,
        qsfp2_rx_rst_3,
        qsfp2_rxd_3,
        qsfp2_rxc_3,
        qsfp2_tx_clk_4,
        qsfp2_tx_rst_4,
        qsfp2_rx_clk_4,
        qsfp2_rx_rst_4,
        qsfp2_rxd_4,
        qsfp2_rxc_4,
        qsfp2_modprsl,
        qsfp2_intl
    );
    $to_myhdl(
        led,
        i2c_scl_o,
        i2c_scl_t,
        i2c_sda_o,
        i2c_sda_t,
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
        qsfp1_txd_1,
        qsfp1_txc_1,
        qsfp1_txd_2,
        qsfp1_txc_2,
        qsfp1_txd_3,
        qsfp1_txc_3,
        qsfp1_txd_4,
        qsfp1_txc_4,
        qsfp1_modsell,
        qsfp1_resetl,
        qsfp1_lpmode,
        qsfp2_txd_1,
        qsfp2_txc_1,
        qsfp2_txd_2,
        qsfp2_txc_2,
        qsfp2_txd_3,
        qsfp2_txc_3,
        qsfp2_txd_4,
        qsfp2_txc_4,
        qsfp2_modsell,
        qsfp2_resetl,
        qsfp2_lpmode
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
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH)
)
UUT (
    .clk_156mhz(clk_156mhz),
    .rst_156mhz(rst_156mhz),
    .clk_250mhz(clk_250mhz),
    .rst_250mhz(rst_250mhz),
    .btnu(btnu),
    .btnl(btnl),
    .btnd(btnd),
    .btnr(btnr),
    .btnc(btnc),
    .sw(sw),
    .led(led),
    .i2c_scl_i(i2c_scl_i),
    .i2c_scl_o(i2c_scl_o),
    .i2c_scl_t(i2c_scl_t),
    .i2c_sda_i(i2c_sda_i),
    .i2c_sda_o(i2c_sda_o),
    .i2c_sda_t(i2c_sda_t),
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
    .qsfp1_tx_clk_1(qsfp1_tx_clk_1),
    .qsfp1_tx_rst_1(qsfp1_tx_rst_1),
    .qsfp1_txd_1(qsfp1_txd_1),
    .qsfp1_txc_1(qsfp1_txc_1),
    .qsfp1_rx_clk_1(qsfp1_rx_clk_1),
    .qsfp1_rx_rst_1(qsfp1_rx_rst_1),
    .qsfp1_rxd_1(qsfp1_rxd_1),
    .qsfp1_rxc_1(qsfp1_rxc_1),
    .qsfp1_tx_clk_2(qsfp1_tx_clk_2),
    .qsfp1_tx_rst_2(qsfp1_tx_rst_2),
    .qsfp1_txd_2(qsfp1_txd_2),
    .qsfp1_txc_2(qsfp1_txc_2),
    .qsfp1_rx_clk_2(qsfp1_rx_clk_2),
    .qsfp1_rx_rst_2(qsfp1_rx_rst_2),
    .qsfp1_rxd_2(qsfp1_rxd_2),
    .qsfp1_rxc_2(qsfp1_rxc_2),
    .qsfp1_tx_clk_3(qsfp1_tx_clk_3),
    .qsfp1_tx_rst_3(qsfp1_tx_rst_3),
    .qsfp1_txd_3(qsfp1_txd_3),
    .qsfp1_txc_3(qsfp1_txc_3),
    .qsfp1_rx_clk_3(qsfp1_rx_clk_3),
    .qsfp1_rx_rst_3(qsfp1_rx_rst_3),
    .qsfp1_rxd_3(qsfp1_rxd_3),
    .qsfp1_rxc_3(qsfp1_rxc_3),
    .qsfp1_tx_clk_4(qsfp1_tx_clk_4),
    .qsfp1_tx_rst_4(qsfp1_tx_rst_4),
    .qsfp1_txd_4(qsfp1_txd_4),
    .qsfp1_txc_4(qsfp1_txc_4),
    .qsfp1_rx_clk_4(qsfp1_rx_clk_4),
    .qsfp1_rx_rst_4(qsfp1_rx_rst_4),
    .qsfp1_rxd_4(qsfp1_rxd_4),
    .qsfp1_rxc_4(qsfp1_rxc_4),
    .qsfp1_modprsl(qsfp1_modprsl_int),
    .qsfp1_modsell(qsfp1_modsell),
    .qsfp1_resetl(qsfp1_resetl),
    .qsfp1_intl(qsfp1_intl_int),
    .qsfp1_lpmode(qsfp1_lpmode_int),
    .qsfp2_tx_clk_1(qsfp2_tx_clk_1),
    .qsfp2_tx_rst_1(qsfp2_tx_rst_1),
    .qsfp2_txd_1(qsfp2_txd_1),
    .qsfp2_txc_1(qsfp2_txc_1),
    .qsfp2_rx_clk_1(qsfp2_rx_clk_1),
    .qsfp2_rx_rst_1(qsfp2_rx_rst_1),
    .qsfp2_rxd_1(qsfp2_rxd_1),
    .qsfp2_rxc_1(qsfp2_rxc_1),
    .qsfp2_tx_clk_2(qsfp2_tx_clk_2),
    .qsfp2_tx_rst_2(qsfp2_tx_rst_2),
    .qsfp2_txd_2(qsfp2_txd_2),
    .qsfp2_txc_2(qsfp2_txc_2),
    .qsfp2_rx_clk_2(qsfp2_rx_clk_2),
    .qsfp2_rx_rst_2(qsfp2_rx_rst_2),
    .qsfp2_rxd_2(qsfp2_rxd_2),
    .qsfp2_rxc_2(qsfp2_rxc_2),
    .qsfp2_tx_clk_3(qsfp2_tx_clk_3),
    .qsfp2_tx_rst_3(qsfp2_tx_rst_3),
    .qsfp2_txd_3(qsfp2_txd_3),
    .qsfp2_txc_3(qsfp2_txc_3),
    .qsfp2_rx_clk_3(qsfp2_rx_clk_3),
    .qsfp2_rx_rst_3(qsfp2_rx_rst_3),
    .qsfp2_rxd_3(qsfp2_rxd_3),
    .qsfp2_rxc_3(qsfp2_rxc_3),
    .qsfp2_tx_clk_4(qsfp2_tx_clk_4),
    .qsfp2_tx_rst_4(qsfp2_tx_rst_4),
    .qsfp2_txd_4(qsfp2_txd_4),
    .qsfp2_txc_4(qsfp2_txc_4),
    .qsfp2_rx_clk_4(qsfp2_rx_clk_4),
    .qsfp2_rx_rst_4(qsfp2_rx_rst_4),
    .qsfp2_rxd_4(qsfp2_rxd_4),
    .qsfp2_rxc_4(qsfp2_rxc_4),
    .qsfp2_modprsl(qsfp2_modprsl_int),
    .qsfp2_modsell(qsfp2_modsell),
    .qsfp2_resetl(qsfp2_resetl),
    .qsfp2_intl(qsfp2_intl_int),
    .qsfp2_lpmode(qsfp2_lpmode_int)
);

endmodule
