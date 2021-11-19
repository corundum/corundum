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
 * FPGA core logic
 */
module fpga_core #
(
    // FW and board IDs
    parameter FW_ID = 32'd0,
    parameter FW_VER = {16'd0, 16'd1},
    parameter BOARD_ID = {16'h4144, 16'h9003},
    parameter BOARD_VER = {16'd0, 16'd1},
    parameter FPGA_ID = 32'h4B39093,

    // Structural configuration
    parameter IF_COUNT = 2,
    parameter PORTS_PER_IF = 1,

    // PTP configuration
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_TAG_WIDTH = 16,
    parameter PTP_PERIOD_NS_WIDTH = 4,
    parameter PTP_OFFSET_NS_WIDTH = 32,
    parameter PTP_FNS_WIDTH = 32,
    parameter PTP_PERIOD_NS = 4'd4,
    parameter PTP_PERIOD_FNS = 32'd0,
    parameter PTP_USE_SAMPLE_CLOCK = 0,
    parameter PTP_SEPARATE_RX_CLOCK = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration (interface)
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = TX_QUEUE_OP_TABLE_SIZE,
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = RX_QUEUE_OP_TABLE_SIZE,
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
    parameter RX_FIFO_DEPTH = 131072,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 131072,
    parameter RX_RAM_SIZE = 131072,

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
    parameter AXIS_PCIE_DATA_WIDTH = 512,
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161,
    parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 62 : 137,
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81,
    parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 64,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 16,
    parameter PCIE_DMA_READ_TX_FC_ENABLE = 1,
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 16,
    parameter PCIE_DMA_WRITE_TX_LIMIT = 3,
    parameter PCIE_DMA_WRITE_TX_FC_ENABLE = 1,
    parameter MSI_COUNT = 32,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
    parameter AXIS_ETH_DATA_WIDTH = 512,
    parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8,
    parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH,
    parameter AXIS_ETH_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1,
    parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
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
    parameter STAT_ID_WIDTH = 12
)
(
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    input  wire                               clk_250mhz,
    input  wire                               rst_250mhz,

    /*
     * GPIO
     */
    output wire [1:0]                         user_led_g,
    output wire                               user_led_r,
    output wire [1:0]                         front_led,
    input  wire [1:0]                         user_sw,

    /*
     * PCIe
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep,
    output wire                               m_axis_rq_tlast,
    input  wire                               m_axis_rq_tready,
    output wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser,
    output wire                               m_axis_rq_tvalid,

    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]    s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]    s_axis_rc_tkeep,
    input  wire                               s_axis_rc_tlast,
    output wire                               s_axis_rc_tready,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0] s_axis_rc_tuser,
    input  wire                               s_axis_rc_tvalid,

    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]    s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]    s_axis_cq_tkeep,
    input  wire                               s_axis_cq_tlast,
    output wire                               s_axis_cq_tready,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0] s_axis_cq_tuser,
    input  wire                               s_axis_cq_tvalid,

    output wire [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep,
    output wire                               m_axis_cc_tlast,
    input  wire                               m_axis_cc_tready,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser,
    output wire                               m_axis_cc_tvalid,

    input  wire [RQ_SEQ_NUM_WIDTH-1:0]        s_axis_rq_seq_num_0,
    input  wire                               s_axis_rq_seq_num_valid_0,
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]        s_axis_rq_seq_num_1,
    input  wire                               s_axis_rq_seq_num_valid_1,

    input  wire [1:0]                         pcie_tfc_nph_av,
    input  wire [1:0]                         pcie_tfc_npd_av,

    input  wire [2:0]                         cfg_max_payload,
    input  wire [2:0]                         cfg_max_read_req,

    output wire [9:0]                         cfg_mgmt_addr,
    output wire [7:0]                         cfg_mgmt_function_number,
    output wire                               cfg_mgmt_write,
    output wire [31:0]                        cfg_mgmt_write_data,
    output wire [3:0]                         cfg_mgmt_byte_enable,
    output wire                               cfg_mgmt_read,
    input  wire [31:0]                        cfg_mgmt_read_data,
    input  wire                               cfg_mgmt_read_write_done,

    input  wire [7:0]                         cfg_fc_ph,
    input  wire [11:0]                        cfg_fc_pd,
    input  wire [7:0]                         cfg_fc_nph,
    input  wire [11:0]                        cfg_fc_npd,
    input  wire [7:0]                         cfg_fc_cplh,
    input  wire [11:0]                        cfg_fc_cpld,
    output wire [2:0]                         cfg_fc_sel,

    input  wire [3:0]                         cfg_interrupt_msi_enable,
    input  wire [11:0]                        cfg_interrupt_msi_mmenable,
    input  wire                               cfg_interrupt_msi_mask_update,
    input  wire [31:0]                        cfg_interrupt_msi_data,
    output wire [3:0]                         cfg_interrupt_msi_select,
    output wire [31:0]                        cfg_interrupt_msi_int,
    output wire [31:0]                        cfg_interrupt_msi_pending_status,
    output wire                               cfg_interrupt_msi_pending_status_data_enable,
    output wire [3:0]                         cfg_interrupt_msi_pending_status_function_num,
    input  wire                               cfg_interrupt_msi_sent,
    input  wire                               cfg_interrupt_msi_fail,
    output wire [2:0]                         cfg_interrupt_msi_attr,
    output wire                               cfg_interrupt_msi_tph_present,
    output wire [1:0]                         cfg_interrupt_msi_tph_type,
    output wire [8:0]                         cfg_interrupt_msi_tph_st_tag,
    output wire [3:0]                         cfg_interrupt_msi_function_number,

    output wire                               status_error_cor,
    output wire                               status_error_uncor,

    /*
     * Ethernet: QSFP28
     */
    input  wire                               qsfp_0_tx_clk,
    input  wire                               qsfp_0_tx_rst,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfp_0_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_0_tx_axis_tkeep,
    output wire                               qsfp_0_tx_axis_tvalid,
    input  wire                               qsfp_0_tx_axis_tready,
    output wire                               qsfp_0_tx_axis_tlast,
    output wire [16+1-1:0]                    qsfp_0_tx_axis_tuser,

    output wire [79:0]                        qsfp_0_tx_ptp_time,
    input  wire [79:0]                        qsfp_0_tx_ptp_ts,
    input  wire [15:0]                        qsfp_0_tx_ptp_ts_tag,
    input  wire                               qsfp_0_tx_ptp_ts_valid,

    input  wire                               qsfp_0_rx_clk,
    input  wire                               qsfp_0_rx_rst,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfp_0_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_0_rx_axis_tkeep,
    input  wire                               qsfp_0_rx_axis_tvalid,
    input  wire                               qsfp_0_rx_axis_tlast,
    input  wire [80+1-1:0]                    qsfp_0_rx_axis_tuser,

    input  wire                               qsfp_0_rx_ptp_clk,
    input  wire                               qsfp_0_rx_ptp_rst,
    output wire [79:0]                        qsfp_0_rx_ptp_time,

    input  wire                               qsfp_0_modprs_l,
    output wire                               qsfp_0_sel_l,

    input  wire                               qsfp_1_tx_clk,
    input  wire                               qsfp_1_tx_rst,

    output wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfp_1_tx_axis_tdata,
    output wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_1_tx_axis_tkeep,
    output wire                               qsfp_1_tx_axis_tvalid,
    input  wire                               qsfp_1_tx_axis_tready,
    output wire                               qsfp_1_tx_axis_tlast,
    output wire [16+1-1:0]                    qsfp_1_tx_axis_tuser,

    output wire [79:0]                        qsfp_1_tx_ptp_time,
    input  wire [79:0]                        qsfp_1_tx_ptp_ts,
    input  wire [15:0]                        qsfp_1_tx_ptp_ts_tag,
    input  wire                               qsfp_1_tx_ptp_ts_valid,

    input  wire                               qsfp_1_rx_ptp_clk,
    input  wire                               qsfp_1_rx_ptp_rst,
    input  wire                               qsfp_1_rx_clk,
    input  wire                               qsfp_1_rx_rst,

    input  wire [AXIS_ETH_DATA_WIDTH-1:0]     qsfp_1_rx_axis_tdata,
    input  wire [AXIS_ETH_KEEP_WIDTH-1:0]     qsfp_1_rx_axis_tkeep,
    input  wire                               qsfp_1_rx_axis_tvalid,
    input  wire                               qsfp_1_rx_axis_tlast,
    input  wire [80+1-1:0]                    qsfp_1_rx_axis_tuser,

    output wire [79:0]                        qsfp_1_rx_ptp_time,

    input  wire                               qsfp_1_modprs_l,
    output wire                               qsfp_1_sel_l,

    output wire                               qsfp_reset_l,
    input  wire                               qsfp_int_l,

    input  wire                               qsfp_i2c_scl_i,
    output wire                               qsfp_i2c_scl_o,
    output wire                               qsfp_i2c_scl_t,
    input  wire                               qsfp_i2c_sda_i,
    output wire                               qsfp_i2c_sda_o,
    output wire                               qsfp_i2c_sda_t,

    input  wire                               eeprom_i2c_scl_i,
    output wire                               eeprom_i2c_scl_o,
    output wire                               eeprom_i2c_scl_t,
    input  wire                               eeprom_i2c_sda_i,
    output wire                               eeprom_i2c_sda_o,
    output wire                               eeprom_i2c_sda_t,
    output wire                               eeprom_wp,

    /*
     * QSPI flash
     */
    output wire                               fpga_boot,
    output wire                               qspi_clk,
    input  wire [3:0]                         qspi_0_dq_i,
    output wire [3:0]                         qspi_0_dq_o,
    output wire [3:0]                         qspi_0_dq_oe,
    output wire                               qspi_0_cs,
    input  wire [3:0]                         qspi_1_dq_i,
    output wire [3:0]                         qspi_1_dq_o,
    output wire [3:0]                         qspi_1_dq_oe,
    output wire                               qspi_1_cs
);

parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF;

parameter F_COUNT = PF_COUNT+VF_COUNT;

parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8);
parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT);
parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8);

initial begin
    if (PORT_COUNT > 2) begin
        $error("Error: Max port count exceeded (instance %m)");
        $finish;
    end
end

// PTP
wire [PTP_TS_WIDTH-1:0]     ptp_ts_96;
wire                        ptp_ts_step;
wire                        ptp_pps;

wire [PTP_PEROUT_COUNT-1:0] ptp_perout_locked;
wire [PTP_PEROUT_COUNT-1:0] ptp_perout_error;
wire [PTP_PEROUT_COUNT-1:0] ptp_perout_pulse;

// control registers
wire [AXIL_CSR_ADDR_WIDTH-1:0]   ctrl_reg_wr_addr;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  ctrl_reg_wr_data;
wire [AXIL_CTRL_STRB_WIDTH-1:0]  ctrl_reg_wr_strb;
wire                             ctrl_reg_wr_en;
wire                             ctrl_reg_wr_wait;
wire                             ctrl_reg_wr_ack;
wire [AXIL_CSR_ADDR_WIDTH-1:0]   ctrl_reg_rd_addr;
wire                             ctrl_reg_rd_en;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  ctrl_reg_rd_data;
wire                             ctrl_reg_rd_wait;
wire                             ctrl_reg_rd_ack;

reg ctrl_reg_wr_ack_reg = 1'b0;
reg [AXIL_CTRL_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = {AXIL_CTRL_DATA_WIDTH{1'b0}};
reg ctrl_reg_rd_ack_reg = 1'b0;

reg qsfp_0_sel_reg = 1'b0;
reg qsfp_1_sel_reg = 1'b0;

reg qsfp_reset_reg = 1'b0;

reg qsfp_i2c_scl_o_reg = 1'b1;
reg qsfp_i2c_sda_o_reg = 1'b1;

reg eeprom_i2c_scl_o_reg = 1'b1;
reg eeprom_i2c_sda_o_reg = 1'b1;

reg fpga_boot_reg = 1'b0;

reg qspi_clk_reg = 1'b0;
reg qspi_0_cs_reg = 1'b1;
reg [3:0] qspi_0_dq_o_reg = 4'd0;
reg [3:0] qspi_0_dq_oe_reg = 4'd0;
reg qspi_1_cs_reg = 1'b1;
reg [3:0] qspi_1_dq_o_reg = 4'd0;
reg [3:0] qspi_1_dq_oe_reg = 4'd0;

assign ctrl_reg_wr_wait = 1'b0;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_reg;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_reg;
assign ctrl_reg_rd_wait = 1'b0;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_reg;

assign qsfp_0_sel_l = !qsfp_0_sel_reg;
assign qsfp_1_sel_l = !qsfp_1_sel_reg;

assign qsfp_reset_l = !qsfp_reset_reg;

assign qsfp_i2c_scl_o = qsfp_i2c_scl_o_reg;
assign qsfp_i2c_scl_t = qsfp_i2c_scl_o_reg;
assign qsfp_i2c_sda_o = qsfp_i2c_sda_o_reg;
assign qsfp_i2c_sda_t = qsfp_i2c_sda_o_reg;

assign eeprom_i2c_scl_o = eeprom_i2c_scl_o_reg;
assign eeprom_i2c_scl_t = eeprom_i2c_scl_o_reg;
assign eeprom_i2c_sda_o = eeprom_i2c_sda_o_reg;
assign eeprom_i2c_sda_t = eeprom_i2c_sda_o_reg;
assign eeprom_wp = 1'b0;

assign fpga_boot = fpga_boot_reg;

assign qspi_clk = qspi_clk_reg;
assign qspi_0_cs = qspi_0_cs_reg;
assign qspi_0_dq_o = qspi_0_dq_o_reg;
assign qspi_0_dq_oe = qspi_0_dq_oe_reg;
assign qspi_1_cs = qspi_1_cs_reg;
assign qspi_1_dq_o = qspi_1_dq_o_reg;
assign qspi_1_dq_oe = qspi_1_dq_oe_reg;

always @(posedge clk_250mhz) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_CTRL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b0;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            16'h0040: begin
                // FPGA ID
                fpga_boot_reg <= ctrl_reg_wr_data == 32'hFEE1DEAD;
            end
            // GPIO
            16'h0110: begin
                // GPIO I2C 0
                if (ctrl_reg_wr_strb[0]) begin
                    qsfp_i2c_scl_o_reg <= ctrl_reg_wr_data[1];
                end
                if (ctrl_reg_wr_strb[1]) begin
                    qsfp_i2c_sda_o_reg <= ctrl_reg_wr_data[9];
                end
                if (ctrl_reg_wr_strb[2]) begin
                    qsfp_0_sel_reg <= ctrl_reg_wr_data[16];
                    qsfp_1_sel_reg <= ctrl_reg_wr_data[17];
                end
            end
            16'h0114: begin
                // GPIO I2C 1
                if (ctrl_reg_wr_strb[0]) begin
                    eeprom_i2c_scl_o_reg <= ctrl_reg_wr_data[1];
                end
                if (ctrl_reg_wr_strb[1]) begin
                    eeprom_i2c_sda_o_reg <= ctrl_reg_wr_data[9];
                end
            end
            16'h0120: begin
                // GPIO XCVR 0123
                if (ctrl_reg_wr_strb[0]) begin
                    qsfp_reset_reg <= ctrl_reg_wr_data[4];
                end
                if (ctrl_reg_wr_strb[1]) begin
                    qsfp_reset_reg <= ctrl_reg_wr_data[12];
                end
            end
            // Flash
            16'h0144: begin
                // QSPI 0 control
                if (ctrl_reg_wr_strb[0]) begin
                    qspi_0_dq_o_reg <= ctrl_reg_wr_data[3:0];
                end
                if (ctrl_reg_wr_strb[1]) begin
                    qspi_0_dq_oe_reg <= ctrl_reg_wr_data[11:8];
                end
                if (ctrl_reg_wr_strb[2]) begin
                    qspi_clk_reg <= ctrl_reg_wr_data[16];
                    qspi_0_cs_reg <= ctrl_reg_wr_data[17];
                end
            end
            16'h0148: begin
                // QSPI 1 control
                if (ctrl_reg_wr_strb[0]) begin
                    qspi_1_dq_o_reg <= ctrl_reg_wr_data[3:0];
                end
                if (ctrl_reg_wr_strb[1]) begin
                    qspi_1_dq_oe_reg <= ctrl_reg_wr_data[11:8];
                end
                if (ctrl_reg_wr_strb[2]) begin
                    qspi_clk_reg <= ctrl_reg_wr_data[16];
                    qspi_1_cs_reg <= ctrl_reg_wr_data[17];
                end
            end
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            16'h0040: ctrl_reg_rd_data_reg <= FPGA_ID; // FPGA ID
            // GPIO
            16'h0110: begin
                // GPIO I2C 0
                ctrl_reg_rd_data_reg[0] <= qsfp_i2c_scl_i;
                ctrl_reg_rd_data_reg[1] <= qsfp_i2c_scl_o_reg;
                ctrl_reg_rd_data_reg[8] <= qsfp_i2c_sda_i;
                ctrl_reg_rd_data_reg[9] <= qsfp_i2c_sda_o_reg;
                ctrl_reg_rd_data_reg[16] <= qsfp_0_sel_reg;
                ctrl_reg_rd_data_reg[17] <= qsfp_1_sel_reg;
            end
            16'h0114: begin
                // GPIO I2C 1
                ctrl_reg_rd_data_reg[0] <= eeprom_i2c_scl_i;
                ctrl_reg_rd_data_reg[1] <= eeprom_i2c_scl_o_reg;
                ctrl_reg_rd_data_reg[8] <= eeprom_i2c_sda_i;
                ctrl_reg_rd_data_reg[9] <= eeprom_i2c_sda_o_reg;
            end
            16'h0120: begin
                // GPIO XCVR 0123
                ctrl_reg_rd_data_reg[0] <= !qsfp_0_modprs_l;
                ctrl_reg_rd_data_reg[1] <= !qsfp_int_l;
                ctrl_reg_rd_data_reg[4] <= qsfp_reset_reg;
                ctrl_reg_rd_data_reg[8] <= !qsfp_1_modprs_l;
                ctrl_reg_rd_data_reg[9] <= !qsfp_int_l;
                ctrl_reg_rd_data_reg[12] <= qsfp_reset_reg;
            end
            // Flash
            16'h0140: begin
                // Flash ID
                ctrl_reg_rd_data_reg[7:0]   <= 0;  // type (SPI)
                ctrl_reg_rd_data_reg[15:8]  <= 2;  // configuration (two segments)
                ctrl_reg_rd_data_reg[23:16] <= 8;  // data width (dual QSPI)
                ctrl_reg_rd_data_reg[31:24] <= 0;  // address width (N/A for SPI)
            end
            16'h0144: begin
                // QSPI 0 control
                ctrl_reg_rd_data_reg[3:0] <= qspi_0_dq_i;
                ctrl_reg_rd_data_reg[11:8] <= qspi_0_dq_oe;
                ctrl_reg_rd_data_reg[16] <= qspi_clk;
                ctrl_reg_rd_data_reg[17] <= qspi_0_cs;
            end
            16'h0148: begin
                // QSPI 1 control
                ctrl_reg_rd_data_reg[3:0] <= qspi_1_dq_i;
                ctrl_reg_rd_data_reg[11:8] <= qspi_1_dq_oe;
                ctrl_reg_rd_data_reg[16] <= qspi_clk;
                ctrl_reg_rd_data_reg[17] <= qspi_1_cs;
            end
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst_250mhz) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        qsfp_0_sel_reg <= 1'b0;
        qsfp_1_sel_reg <= 1'b0;

        qsfp_reset_reg <= 1'b0;

        qsfp_i2c_scl_o_reg <= 1'b1;
        qsfp_i2c_sda_o_reg <= 1'b1;

        eeprom_i2c_scl_o_reg <= 1'b1;
        eeprom_i2c_sda_o_reg <= 1'b1;

        fpga_boot_reg <= 1'b0;

        qspi_clk_reg <= 1'b0;
        qspi_0_cs_reg <= 1'b1;
        qspi_0_dq_o_reg <= 4'd0;
        qspi_0_dq_oe_reg <= 4'd0;
        qspi_1_cs_reg <= 1'b1;
        qspi_1_dq_o_reg <= 4'd0;
        qspi_1_dq_oe_reg <= 4'd0;
    end
end

reg [26:0] pps_led_counter_reg = 0;
reg pps_led_reg = 0;

always @(posedge clk_250mhz) begin
    if (ptp_pps) begin
        pps_led_counter_reg <= 125000000;
    end else if (pps_led_counter_reg > 0) begin
        pps_led_counter_reg <= pps_led_counter_reg - 1;
    end

    pps_led_reg <= pps_led_counter_reg > 0;
end

assign user_led_g[0] = 1'b1;
assign user_led_g[1] = !pps_led_reg;
assign user_led_r = 1'b1;
assign front_led[0] = !pps_led_reg;
assign front_led[1] = 1'b0;

wire [PORT_COUNT-1:0]                         eth_tx_clk;
wire [PORT_COUNT-1:0]                         eth_tx_rst;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_tx_ptp_ts_96;
wire [PORT_COUNT-1:0]                         eth_tx_ptp_ts_step;

wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     axis_eth_tx_tdata;
wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     axis_eth_tx_tkeep;
wire [PORT_COUNT-1:0]                         axis_eth_tx_tvalid;
wire [PORT_COUNT-1:0]                         axis_eth_tx_tready;
wire [PORT_COUNT-1:0]                         axis_eth_tx_tlast;
wire [PORT_COUNT*AXIS_ETH_TX_USER_WIDTH-1:0]  axis_eth_tx_tuser;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            axis_eth_tx_ptp_ts;
wire [PORT_COUNT*PTP_TAG_WIDTH-1:0]           axis_eth_tx_ptp_ts_tag;
wire [PORT_COUNT-1:0]                         axis_eth_tx_ptp_ts_valid;
wire [PORT_COUNT-1:0]                         axis_eth_tx_ptp_ts_ready;

wire [PORT_COUNT-1:0]                         eth_rx_clk;
wire [PORT_COUNT-1:0]                         eth_rx_rst;

wire [PORT_COUNT-1:0]                         eth_rx_ptp_clk;
wire [PORT_COUNT-1:0]                         eth_rx_ptp_rst;
wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_rx_ptp_ts_96;
wire [PORT_COUNT-1:0]                         eth_rx_ptp_ts_step;

wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     axis_eth_rx_tdata;
wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     axis_eth_rx_tkeep;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tvalid;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tready;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tlast;
wire [PORT_COUNT*AXIS_ETH_RX_USER_WIDTH-1:0]  axis_eth_rx_tuser;

//  counts    QSFP 0   QSFP 1
// IF  PORT   0_1234   1_1234
// 1   1      0 (0.0)
// 1   2      0 (0.0)  1 (0.1)
// 2   1      0 (0.0)  1 (1.0)

localparam QSFP_0_IND = 0;
localparam QSFP_1_IND = 1;

generate
    genvar n;

    if (QSFP_0_IND >= 0 && QSFP_0_IND < PORT_COUNT) begin : qsfp_0
        assign eth_tx_clk[QSFP_0_IND] = qsfp_0_tx_clk;
        assign eth_tx_rst[QSFP_0_IND] = qsfp_0_tx_rst;

        assign qsfp_0_tx_axis_tdata = axis_eth_tx_tdata[QSFP_0_IND*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH];
        assign qsfp_0_tx_axis_tkeep = axis_eth_tx_tkeep[QSFP_0_IND*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH];
        assign qsfp_0_tx_axis_tvalid = axis_eth_tx_tvalid[QSFP_0_IND];
        assign axis_eth_tx_tready[QSFP_0_IND] = qsfp_0_tx_axis_tready;
        assign qsfp_0_tx_axis_tlast = axis_eth_tx_tlast[QSFP_0_IND];
        assign qsfp_0_tx_axis_tuser = axis_eth_tx_tuser[QSFP_0_IND*17 +: 17];

        assign axis_eth_tx_ptp_ts[QSFP_0_IND*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {qsfp_0_tx_ptp_ts, 16'd0};
        assign axis_eth_tx_ptp_ts_tag[QSFP_0_IND*PTP_TAG_WIDTH +: PTP_TAG_WIDTH] = qsfp_0_tx_ptp_ts_tag;
        assign axis_eth_tx_ptp_ts_valid[QSFP_0_IND] = qsfp_0_tx_ptp_ts_valid;

        assign eth_rx_clk[QSFP_0_IND] = qsfp_0_rx_clk;
        assign eth_rx_rst[QSFP_0_IND] = qsfp_0_rx_rst;

        assign axis_eth_rx_tdata[QSFP_0_IND*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH] = qsfp_0_rx_axis_tdata;
        assign axis_eth_rx_tkeep[QSFP_0_IND*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH] = qsfp_0_rx_axis_tkeep;
        assign axis_eth_rx_tvalid[QSFP_0_IND] = qsfp_0_rx_axis_tvalid;
        assign axis_eth_rx_tlast[QSFP_0_IND] = qsfp_0_rx_axis_tlast;
        assign axis_eth_rx_tuser[QSFP_0_IND*AXIS_ETH_RX_USER_WIDTH +: AXIS_ETH_RX_USER_WIDTH] = {qsfp_0_rx_axis_tuser[80:1], 16'd0, qsfp_0_rx_axis_tuser[0]};

        assign eth_rx_ptp_clk[QSFP_0_IND] = qsfp_0_rx_ptp_clk;
        assign eth_rx_ptp_rst[QSFP_0_IND] = qsfp_0_rx_ptp_rst;
        assign qsfp_0_tx_ptp_time = eth_tx_ptp_ts_96[QSFP_0_IND*PTP_TS_WIDTH+16 +: 80];
        assign qsfp_0_rx_ptp_time = eth_rx_ptp_ts_96[QSFP_0_IND*PTP_TS_WIDTH+16 +: 80];
    end else begin
        assign qsfp_0_tx_axis_tdata = {AXIS_ETH_DATA_WIDTH{1'b0}};
        assign qsfp_0_tx_axis_tkeep = {AXIS_ETH_KEEP_WIDTH{1'b0}};
        assign qsfp_0_tx_axis_tvalid = 1'b0;
        assign qsfp_0_tx_axis_tlast = 1'b0;
        assign qsfp_0_tx_axis_tuser = 1'b0;
        assign qsfp_0_tx_ptp_time = 80'd0;
        assign qsfp_0_rx_ptp_time = 80'd0;
    end

    if (QSFP_1_IND >= 0 && QSFP_1_IND < PORT_COUNT) begin : qsfp_1
        assign eth_tx_clk[QSFP_1_IND] = qsfp_1_tx_clk;
        assign eth_tx_rst[QSFP_1_IND] = qsfp_1_tx_rst;

        assign qsfp_1_tx_axis_tdata = axis_eth_tx_tdata[QSFP_1_IND*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH];
        assign qsfp_1_tx_axis_tkeep = axis_eth_tx_tkeep[QSFP_1_IND*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH];
        assign qsfp_1_tx_axis_tvalid = axis_eth_tx_tvalid[QSFP_1_IND];
        assign axis_eth_tx_tready[QSFP_1_IND] = qsfp_1_tx_axis_tready;
        assign qsfp_1_tx_axis_tlast = axis_eth_tx_tlast[QSFP_1_IND];
        assign qsfp_1_tx_axis_tuser = axis_eth_tx_tuser[QSFP_1_IND*17 +: 17];

        assign axis_eth_tx_ptp_ts[QSFP_1_IND*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {qsfp_1_tx_ptp_ts, 16'd0};
        assign axis_eth_tx_ptp_ts_tag[QSFP_1_IND*PTP_TAG_WIDTH +: PTP_TAG_WIDTH] = qsfp_1_tx_ptp_ts_tag;
        assign axis_eth_tx_ptp_ts_valid[QSFP_1_IND] = qsfp_1_tx_ptp_ts_valid;

        assign eth_rx_clk[QSFP_1_IND] = qsfp_1_rx_clk;
        assign eth_rx_rst[QSFP_1_IND] = qsfp_1_rx_rst;

        assign axis_eth_rx_tdata[QSFP_1_IND*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH] = qsfp_1_rx_axis_tdata;
        assign axis_eth_rx_tkeep[QSFP_1_IND*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH] = qsfp_1_rx_axis_tkeep;
        assign axis_eth_rx_tvalid[QSFP_1_IND] = qsfp_1_rx_axis_tvalid;
        assign axis_eth_rx_tlast[QSFP_1_IND] = qsfp_1_rx_axis_tlast;
        assign axis_eth_rx_tuser[QSFP_1_IND*AXIS_ETH_RX_USER_WIDTH +: AXIS_ETH_RX_USER_WIDTH] = {qsfp_1_rx_axis_tuser[80:1], 16'd0, qsfp_1_rx_axis_tuser[0]};

        assign eth_rx_ptp_clk[QSFP_1_IND] = qsfp_1_rx_ptp_clk;
        assign eth_rx_ptp_rst[QSFP_1_IND] = qsfp_1_rx_ptp_rst;
        assign qsfp_1_tx_ptp_time = eth_tx_ptp_ts_96[QSFP_1_IND*PTP_TS_WIDTH+16 +: 80];
        assign qsfp_1_rx_ptp_time = eth_rx_ptp_ts_96[QSFP_1_IND*PTP_TS_WIDTH+16 +: 80];
    end else begin
        assign qsfp_1_tx_axis_tdata = {AXIS_ETH_DATA_WIDTH{1'b0}};
        assign qsfp_1_tx_axis_tkeep = {AXIS_ETH_KEEP_WIDTH{1'b0}};
        assign qsfp_1_tx_axis_tvalid = 1'b0;
        assign qsfp_1_tx_axis_tlast = 1'b0;
        assign qsfp_1_tx_axis_tuser = 1'b0;
        assign qsfp_1_tx_ptp_time = 80'd0;
        assign qsfp_1_rx_ptp_time = 80'd0;
    end

endgenerate

mqnic_core_pcie_us #(
    // FW and board IDs
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),

    // Structural configuration
    .IF_COUNT(IF_COUNT),
    .PORTS_PER_IF(PORTS_PER_IF),

    .PORT_COUNT(PORT_COUNT),

    // PTP configuration
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .PTP_PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .PTP_OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .PTP_FNS_WIDTH(PTP_FNS_WIDTH),
    .PTP_PERIOD_NS(PTP_PERIOD_NS),
    .PTP_PERIOD_FNS(PTP_PERIOD_FNS),
    .PTP_USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK),
    .PTP_SEPARATE_RX_CLOCK(PTP_SEPARATE_RX_CLOCK),
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
    .F_COUNT(F_COUNT),
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
    .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .AXIL_IF_CTRL_ADDR_WIDTH(AXIL_IF_CTRL_ADDR_WIDTH),
    .AXIL_CSR_ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .AXIL_CSR_PASSTHROUGH_ENABLE(0),

    // AXI lite interface configuration (application control)
    .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),

    // Ethernet interface configuration
    .AXIS_ETH_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_ETH_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .AXIS_ETH_SYNC_DATA_WIDTH(AXIS_ETH_SYNC_DATA_WIDTH),
    .AXIS_ETH_TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .AXIS_ETH_RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH),
    .AXIS_ETH_RX_USE_READY(0),
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
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    /*
     * AXI input (RC)
     */
    .s_axis_rc_tdata(s_axis_rc_tdata),
    .s_axis_rc_tkeep(s_axis_rc_tkeep),
    .s_axis_rc_tvalid(s_axis_rc_tvalid),
    .s_axis_rc_tready(s_axis_rc_tready),
    .s_axis_rc_tlast(s_axis_rc_tlast),
    .s_axis_rc_tuser(s_axis_rc_tuser),

    /*
     * AXI output (RQ)
     */
    .m_axis_rq_tdata(m_axis_rq_tdata),
    .m_axis_rq_tkeep(m_axis_rq_tkeep),
    .m_axis_rq_tvalid(m_axis_rq_tvalid),
    .m_axis_rq_tready(m_axis_rq_tready),
    .m_axis_rq_tlast(m_axis_rq_tlast),
    .m_axis_rq_tuser(m_axis_rq_tuser),

    /*
     * AXI input (CQ)
     */
    .s_axis_cq_tdata(s_axis_cq_tdata),
    .s_axis_cq_tkeep(s_axis_cq_tkeep),
    .s_axis_cq_tvalid(s_axis_cq_tvalid),
    .s_axis_cq_tready(s_axis_cq_tready),
    .s_axis_cq_tlast(s_axis_cq_tlast),
    .s_axis_cq_tuser(s_axis_cq_tuser),

    /*
     * AXI output (CC)
     */
    .m_axis_cc_tdata(m_axis_cc_tdata),
    .m_axis_cc_tkeep(m_axis_cc_tkeep),
    .m_axis_cc_tvalid(m_axis_cc_tvalid),
    .m_axis_cc_tready(m_axis_cc_tready),
    .m_axis_cc_tlast(m_axis_cc_tlast),
    .m_axis_cc_tuser(m_axis_cc_tuser),

    /*
     * Transmit sequence number input
     */
    .s_axis_rq_seq_num_0(s_axis_rq_seq_num_0),
    .s_axis_rq_seq_num_valid_0(s_axis_rq_seq_num_valid_0),
    .s_axis_rq_seq_num_1(s_axis_rq_seq_num_1),
    .s_axis_rq_seq_num_valid_1(s_axis_rq_seq_num_valid_1),

    /*
     * Flow control
     */
    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    /*
     * Configuration inputs
     */
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_max_payload(cfg_max_payload),

    /*
     * Configuration interface
     */
    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    /*
     * Interrupt interface
     */
    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_vf_enable(8'd0),
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

    /*
     * PCIe error outputs
     */
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor),

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    .m_axil_csr_awaddr(),
    .m_axil_csr_awprot(),
    .m_axil_csr_awvalid(),
    .m_axil_csr_awready(1),
    .m_axil_csr_wdata(),
    .m_axil_csr_wstrb(),
    .m_axil_csr_wvalid(),
    .m_axil_csr_wready(1),
    .m_axil_csr_bresp(0),
    .m_axil_csr_bvalid(0),
    .m_axil_csr_bready(),
    .m_axil_csr_araddr(),
    .m_axil_csr_arprot(),
    .m_axil_csr_arvalid(),
    .m_axil_csr_arready(1),
    .m_axil_csr_rdata(0),
    .m_axil_csr_rresp(0),
    .m_axil_csr_rvalid(0),
    .m_axil_csr_rready(),

    /*
     * Control register interface
     */
    .ctrl_reg_wr_addr(ctrl_reg_wr_addr),
    .ctrl_reg_wr_data(ctrl_reg_wr_data),
    .ctrl_reg_wr_strb(ctrl_reg_wr_strb),
    .ctrl_reg_wr_en(ctrl_reg_wr_en),
    .ctrl_reg_wr_wait(ctrl_reg_wr_wait),
    .ctrl_reg_wr_ack(ctrl_reg_wr_ack),
    .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
    .ctrl_reg_rd_en(ctrl_reg_rd_en),
    .ctrl_reg_rd_data(ctrl_reg_rd_data),
    .ctrl_reg_rd_wait(ctrl_reg_rd_wait),
    .ctrl_reg_rd_ack(ctrl_reg_rd_ack),

    /*
     * PTP clock
     */
    .ptp_sample_clk(clk_250mhz),
    .ptp_pps(ptp_pps),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step),
    .ptp_perout_locked(ptp_perout_locked),
    .ptp_perout_error(ptp_perout_error),
    .ptp_perout_pulse(ptp_perout_pulse),

    /*
     * Ethernet
     */
    .eth_tx_clk(eth_tx_clk),
    .eth_tx_rst(eth_tx_rst),

    .eth_tx_ptp_ts_96(eth_tx_ptp_ts_96),
    .eth_tx_ptp_ts_step(eth_tx_ptp_ts_step),

    .m_axis_eth_tx_tdata(axis_eth_tx_tdata),
    .m_axis_eth_tx_tkeep(axis_eth_tx_tkeep),
    .m_axis_eth_tx_tvalid(axis_eth_tx_tvalid),
    .m_axis_eth_tx_tready(axis_eth_tx_tready),
    .m_axis_eth_tx_tlast(axis_eth_tx_tlast),
    .m_axis_eth_tx_tuser(axis_eth_tx_tuser),

    .s_axis_eth_tx_ptp_ts(axis_eth_tx_ptp_ts),
    .s_axis_eth_tx_ptp_ts_tag(axis_eth_tx_ptp_ts_tag),
    .s_axis_eth_tx_ptp_ts_valid(axis_eth_tx_ptp_ts_valid),
    .s_axis_eth_tx_ptp_ts_ready(axis_eth_tx_ptp_ts_ready),

    .eth_rx_clk(eth_rx_clk),
    .eth_rx_rst(eth_rx_rst),

    .eth_rx_ptp_clk(eth_rx_ptp_clk),
    .eth_rx_ptp_rst(eth_rx_ptp_rst),
    .eth_rx_ptp_ts_96(eth_rx_ptp_ts_96),
    .eth_rx_ptp_ts_step(eth_rx_ptp_ts_step),

    .s_axis_eth_rx_tdata(axis_eth_rx_tdata),
    .s_axis_eth_rx_tkeep(axis_eth_rx_tkeep),
    .s_axis_eth_rx_tvalid(axis_eth_rx_tvalid),
    .s_axis_eth_rx_tready(axis_eth_rx_tready),
    .s_axis_eth_rx_tlast(axis_eth_rx_tlast),
    .s_axis_eth_rx_tuser(axis_eth_rx_tuser),

    /*
     * Statistics input
     */
    .s_axis_stat_tdata(0),
    .s_axis_stat_tid(0),
    .s_axis_stat_tvalid(1'b0),
    .s_axis_stat_tready()
);

endmodule

`resetall
