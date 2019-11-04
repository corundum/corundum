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
parameter AXIS_PCIE_DATA_WIDTH = 256;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_RC_USER_WIDTH = 75;
parameter AXIS_PCIE_RQ_USER_WIDTH = 62;
parameter AXIS_PCIE_CQ_USER_WIDTH = 88;
parameter AXIS_PCIE_CC_USER_WIDTH = 33;
parameter BAR0_APERTURE = 24;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg clk_156mhz = 0;
reg rst_156mhz = 0;
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
reg sfp_1_tx_clk = 0;
reg sfp_1_tx_rst = 0;
reg sfp_1_rx_clk = 0;
reg sfp_1_rx_rst = 0;
reg [63:0] sfp_1_rxd = 0;
reg [7:0] sfp_1_rxc = 0;
reg sfp_2_tx_clk = 0;
reg sfp_2_tx_rst = 0;
reg sfp_2_rx_clk = 0;
reg sfp_2_rx_rst = 0;
reg [63:0] sfp_2_rxd = 0;
reg [7:0]  sfp_2_rxc = 0;
reg sfp_i2c_scl_i = 1;
reg sfp_1_i2c_sda_i = 1;
reg sfp_2_i2c_sda_i = 1;
reg eeprom_i2c_scl_i = 1;
reg eeprom_i2c_sda_i = 1;
reg [15:0] flash_dq_i = 0;

// Outputs
wire [1:0] sfp_1_led;
wire [1:0] sfp_2_led;
wire [1:0] sma_led;
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
wire [63:0] sfp_1_txd;
wire [7:0] sfp_1_txc;
wire [63:0] sfp_2_txd;
wire [7:0] sfp_2_txc;
wire sfp_i2c_scl_o;
wire sfp_i2c_scl_t;
wire sfp_1_i2c_sda_o;
wire sfp_1_i2c_sda_t;
wire sfp_2_i2c_sda_o;
wire sfp_2_i2c_sda_t;
wire eeprom_i2c_scl_o;
wire eeprom_i2c_scl_t;
wire eeprom_i2c_sda_o;
wire eeprom_i2c_sda_t;
wire [15:0] flash_dq_o;
wire flash_dq_oe;
wire [22:0] flash_addr;
wire flash_region;
wire flash_region_oe;
wire flash_ce_n;
wire flash_oe_n;
wire flash_we_n;
wire flash_adv_n;

initial begin
    // myhdl integration
    $from_myhdl(
        clk_156mhz,
        rst_156mhz,
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
        sfp_1_tx_clk,
        sfp_1_tx_rst,
        sfp_1_rx_clk,
        sfp_1_rx_rst,
        sfp_1_rxd,
        sfp_1_rxc,
        sfp_2_tx_clk,
        sfp_2_tx_rst,
        sfp_2_rx_clk,
        sfp_2_rx_rst,
        sfp_2_rxd,
        sfp_2_rxc,
        sfp_i2c_scl_i,
        sfp_1_i2c_sda_i,
        sfp_2_i2c_sda_i,
        eeprom_i2c_scl_i,
        eeprom_i2c_sda_i,
        flash_dq_i
    );
    $to_myhdl(
        sfp_1_led,
        sfp_2_led,
        sma_led,
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
        sfp_1_txd,
        sfp_1_txc,
        sfp_2_txd,
        sfp_2_txc,
        sfp_i2c_scl_o,
        sfp_i2c_scl_t,
        sfp_1_i2c_sda_o,
        sfp_1_i2c_sda_t,
        sfp_2_i2c_sda_o,
        sfp_2_i2c_sda_t,
        eeprom_i2c_scl_o,
        eeprom_i2c_scl_t,
        eeprom_i2c_sda_o,
        eeprom_i2c_sda_t,
        flash_dq_o,
        flash_dq_oe,
        flash_addr,
        flash_region,
        flash_region_oe,
        flash_ce_n,
        flash_oe_n,
        flash_we_n,
        flash_adv_n
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
    .BAR0_APERTURE(BAR0_APERTURE)
)
UUT (
    .clk_156mhz(clk_156mhz),
    .rst_156mhz(rst_156mhz),
    .clk_250mhz(clk_250mhz),
    .rst_250mhz(rst_250mhz),
    .sfp_1_led(sfp_1_led),
    .sfp_2_led(sfp_2_led),
    .sma_led(sma_led),
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
    .sfp_1_tx_clk(sfp_1_tx_clk),
    .sfp_1_tx_rst(sfp_1_tx_rst),
    .sfp_1_txd(sfp_1_txd),
    .sfp_1_txc(sfp_1_txc),
    .sfp_1_rx_clk(sfp_1_rx_clk),
    .sfp_1_rx_rst(sfp_1_rx_rst),
    .sfp_1_rxd(sfp_1_rxd),
    .sfp_1_rxc(sfp_1_rxc),
    .sfp_2_tx_clk(sfp_2_tx_clk),
    .sfp_2_tx_rst(sfp_2_tx_rst),
    .sfp_2_txd(sfp_2_txd),
    .sfp_2_txc(sfp_2_txc),
    .sfp_2_rx_clk(sfp_2_rx_clk),
    .sfp_2_rx_rst(sfp_2_rx_rst),
    .sfp_2_rxd(sfp_2_rxd),
    .sfp_2_rxc(sfp_2_rxc),
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
    .flash_dq_i(flash_dq_i),
    .flash_dq_o(flash_dq_o),
    .flash_dq_oe(flash_dq_oe),
    .flash_addr(flash_addr),
    .flash_region(flash_region),
    .flash_region_oe(flash_region_oe),
    .flash_ce_n(flash_ce_n),
    .flash_oe_n(flash_oe_n),
    .flash_we_n(flash_we_n),
    .flash_adv_n(flash_adv_n)
);

endmodule
