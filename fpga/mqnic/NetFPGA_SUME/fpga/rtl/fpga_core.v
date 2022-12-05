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
    parameter FPGA_ID = 32'h3691093,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h00_00_01_00,
    parameter BOARD_ID = 32'h10ee_7028,
    parameter BOARD_VER = 32'h01_00_00_00,
    parameter BUILD_DATE = 32'd602976000,
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
    parameter PTP_CLK_PERIOD_NS_NUM = 32,
    parameter PTP_CLK_PERIOD_NS_DENOM = 5,
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_USE_SAMPLE_CLOCK = 1,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,
    parameter IF_PTP_PERIOD_NS = 6'h6,
    parameter IF_PTP_PERIOD_FNS = 16'h6666,

    // Queue manager configuration
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = TX_QUEUE_OP_TABLE_SIZE,
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = RX_QUEUE_OP_TABLE_SIZE,
    parameter EVENT_QUEUE_INDEX_WIDTH = 5,
    parameter TX_QUEUE_INDEX_WIDTH = 9,
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
    parameter TX_TAG_WIDTH = 16,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter ENABLE_PADDING = 1,
    parameter ENABLE_DIC = 1,
    parameter MIN_FRAME_LENGTH = 64,
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
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    parameter AXIS_PCIE_RC_USER_WIDTH = 75,
    parameter AXIS_PCIE_RQ_USER_WIDTH = 60,
    parameter AXIS_PCIE_CQ_USER_WIDTH = 85,
    parameter AXIS_PCIE_CC_USER_WIDTH = 33,
    parameter RC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 256,
    parameter RQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    parameter CQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    parameter CC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    parameter RQ_SEQ_NUM_WIDTH = 4,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 64,

    // Interrupt configuration
    parameter IRQ_INDEX_WIDTH = EVENT_QUEUE_INDEX_WIDTH,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
    parameter XGMII_DATA_WIDTH = 64,
    parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8,
    parameter AXIS_ETH_DATA_WIDTH = XGMII_DATA_WIDTH,
    parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8,
    parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH,
    parameter AXIS_ETH_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
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
    parameter STAT_ID_WIDTH = 10
)
(
    /*
     * Clock: 250 MHz
     * Synchronous reset
     */
    input  wire                               clk_250mhz,
    input  wire                               rst_250mhz,

    /*
     * PTP clock
     */
    input  wire                               ptp_clk,
    input  wire                               ptp_rst,
    input  wire                               ptp_sample_clk,

    /*
     * GPIO
     */
    input  wire [1:0]                         btn,
    output wire [1:0]                         sfp_1_led,
    output wire [1:0]                         sfp_2_led,
    output wire [1:0]                         sfp_3_led,
    output wire [1:0]                         sfp_4_led,
    output wire [1:0]                         led,

    /*
     * I2C
     */

    input  wire                               i2c_scl_i,
    output wire                               i2c_scl_o,
    output wire                               i2c_scl_t,
    input  wire                               i2c_sda_i,
    output wire                               i2c_sda_o,
    output wire                               i2c_sda_t,

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

    input  wire [RQ_SEQ_NUM_WIDTH-1:0]        s_axis_rq_seq_num,
    input  wire                               s_axis_rq_seq_num_valid,

    input  wire [1:0]                         pcie_tfc_nph_av,
    input  wire [1:0]                         pcie_tfc_npd_av,

    input  wire [2:0]                         cfg_max_payload,
    input  wire [2:0]                         cfg_max_read_req,

    output wire [18:0]                        cfg_mgmt_addr,
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

    input  wire [1:0]                         cfg_interrupt_msix_enable,
    input  wire [1:0]                         cfg_interrupt_msix_mask,
    input  wire [7:0]                         cfg_interrupt_msix_vf_enable,
    input  wire [7:0]                         cfg_interrupt_msix_vf_mask,
    output wire [63:0]                        cfg_interrupt_msix_address,
    output wire [31:0]                        cfg_interrupt_msix_data,
    output wire                               cfg_interrupt_msix_int,
    input  wire                               cfg_interrupt_msix_sent,
    input  wire                               cfg_interrupt_msix_fail,
    output wire [3:0]                         cfg_interrupt_msi_function_number,

    output wire                               status_error_cor,
    output wire                               status_error_uncor,

    /*
     * Ethernet: SFP+
     */
    input  wire                               sfp_1_tx_clk,
    input  wire                               sfp_1_tx_rst,
    output wire [XGMII_DATA_WIDTH-1:0]        sfp_1_txd,
    output wire [XGMII_CTRL_WIDTH-1:0]        sfp_1_txc,
    input  wire                               sfp_1_rx_clk,
    input  wire                               sfp_1_rx_rst,
    input  wire [XGMII_DATA_WIDTH-1:0]        sfp_1_rxd,
    input  wire [XGMII_CTRL_WIDTH-1:0]        sfp_1_rxc,
    input  wire                               sfp_1_rx_status,

    input  wire                               sfp_2_tx_clk,
    input  wire                               sfp_2_tx_rst,
    output wire [XGMII_DATA_WIDTH-1:0]        sfp_2_txd,
    output wire [XGMII_CTRL_WIDTH-1:0]        sfp_2_txc,
    input  wire                               sfp_2_rx_clk,
    input  wire                               sfp_2_rx_rst,
    input  wire [XGMII_DATA_WIDTH-1:0]        sfp_2_rxd,
    input  wire [XGMII_CTRL_WIDTH-1:0]        sfp_2_rxc,
    input  wire                               sfp_2_rx_status,

    input  wire                               sfp_3_tx_clk,
    input  wire                               sfp_3_tx_rst,
    output wire [XGMII_DATA_WIDTH-1:0]        sfp_3_txd,
    output wire [XGMII_CTRL_WIDTH-1:0]        sfp_3_txc,
    input  wire                               sfp_3_rx_clk,
    input  wire                               sfp_3_rx_rst,
    input  wire [XGMII_DATA_WIDTH-1:0]        sfp_3_rxd,
    input  wire [XGMII_CTRL_WIDTH-1:0]        sfp_3_rxc,
    input  wire                               sfp_3_rx_status,

    input  wire                               sfp_4_tx_clk,
    input  wire                               sfp_4_tx_rst,
    output wire [XGMII_DATA_WIDTH-1:0]        sfp_4_txd,
    output wire [XGMII_CTRL_WIDTH-1:0]        sfp_4_txc,
    input  wire                               sfp_4_rx_clk,
    input  wire                               sfp_4_rx_rst,
    input  wire [XGMII_DATA_WIDTH-1:0]        sfp_4_rxd,
    input  wire [XGMII_CTRL_WIDTH-1:0]        sfp_4_rxc,
    input  wire                               sfp_4_rx_status,

    input  wire                               sfp_1_mod_detect,
    input  wire                               sfp_2_mod_detect,
    input  wire                               sfp_3_mod_detect,
    input  wire                               sfp_4_mod_detect,
    output wire [1:0]                         sfp_1_rs,
    output wire [1:0]                         sfp_2_rs,
    output wire [1:0]                         sfp_3_rs,
    output wire [1:0]                         sfp_4_rs,
    input  wire                               sfp_1_los,
    input  wire                               sfp_2_los,
    input  wire                               sfp_3_los,
    input  wire                               sfp_4_los,
    output wire                               sfp_1_tx_disable,
    output wire                               sfp_2_tx_disable,
    output wire                               sfp_3_tx_disable,
    output wire                               sfp_4_tx_disable,
    input  wire                               sfp_1_tx_fault,
    input  wire                               sfp_2_tx_fault,
    input  wire                               sfp_3_tx_fault,
    input  wire                               sfp_4_tx_fault
);

parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF;

parameter F_COUNT = PF_COUNT+VF_COUNT;

parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8);
parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT);
parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8);

localparam RB_BASE_ADDR = 16'h1000;
localparam RBB = RB_BASE_ADDR & {AXIL_CTRL_ADDR_WIDTH{1'b1}};

initial begin
    if (PORT_COUNT > 4) begin
        $error("Error: Max port count exceeded (instance %m)");
        $finish;
    end
end

// PTP
wire [PTP_TS_WIDTH-1:0]     ptp_ts_96;
wire                        ptp_ts_step;
wire                        ptp_pps;
wire                        ptp_pps_str;
wire [PTP_TS_WIDTH-1:0]     ptp_sync_ts_96;
wire                        ptp_sync_ts_step;
wire                        ptp_sync_pps;

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

reg [1:0] sfp_1_rs_reg = 2'b11;
reg [1:0] sfp_2_rs_reg = 2'b11;
reg [1:0] sfp_3_rs_reg = 2'b11;
reg [1:0] sfp_4_rs_reg = 2'b11;

reg sfp_1_tx_disable_reg = 1'b0;
reg sfp_2_tx_disable_reg = 1'b0;
reg sfp_3_tx_disable_reg = 1'b0;
reg sfp_4_tx_disable_reg = 1'b0;

reg i2c_scl_o_reg = 1'b1;
reg i2c_sda_o_reg = 1'b1;

assign ctrl_reg_wr_wait = 1'b0;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_reg;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_reg;
assign ctrl_reg_rd_wait = 1'b0;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_reg;

assign sfp_1_rs = sfp_1_rs_reg;
assign sfp_2_rs = sfp_2_rs_reg;
assign sfp_3_rs = sfp_3_rs_reg;
assign sfp_4_rs = sfp_4_rs_reg;

assign sfp_1_tx_disable = sfp_1_tx_disable_reg;
assign sfp_2_tx_disable = sfp_2_tx_disable_reg;
assign sfp_3_tx_disable = sfp_3_tx_disable_reg;
assign sfp_4_tx_disable = sfp_4_tx_disable_reg;

assign i2c_scl_o = i2c_scl_o_reg;
assign i2c_scl_t = i2c_scl_o_reg;
assign i2c_sda_o = i2c_sda_o_reg;
assign i2c_sda_t = i2c_sda_o_reg;

always @(posedge clk_250mhz) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_CTRL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b0;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            // I2C 0
            RBB+8'h0C: begin
                // I2C ctrl: control
                if (ctrl_reg_wr_strb[0]) begin
                    i2c_scl_o_reg <= ctrl_reg_wr_data[1];
                end
                if (ctrl_reg_wr_strb[1]) begin
                    i2c_sda_o_reg <= ctrl_reg_wr_data[9];
                end
            end
            // XCVR GPIO
            RBB+8'h1C: begin
                // XCVR GPIO: control 0123
                if (ctrl_reg_wr_strb[0]) begin
                    sfp_1_tx_disable_reg <= ctrl_reg_wr_data[5];
                    sfp_1_rs_reg <= ctrl_reg_wr_data[7:6];
                end
                if (ctrl_reg_wr_strb[1]) begin
                    sfp_2_tx_disable_reg <= ctrl_reg_wr_data[13];
                    sfp_2_rs_reg <= ctrl_reg_wr_data[15:14];
                end
                if (ctrl_reg_wr_strb[2]) begin
                    sfp_3_tx_disable_reg <= ctrl_reg_wr_data[21];
                    sfp_3_rs_reg <= ctrl_reg_wr_data[23:22];
                end
                if (ctrl_reg_wr_strb[3]) begin
                    sfp_4_tx_disable_reg <= ctrl_reg_wr_data[29];
                    sfp_4_rs_reg <= ctrl_reg_wr_data[31:30];
                end
            end
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            // I2C 0
            RBB+8'h00: ctrl_reg_rd_data_reg <= 32'h0000C110;             // I2C ctrl: Type
            RBB+8'h04: ctrl_reg_rd_data_reg <= 32'h00000100;             // I2C ctrl: Version
            RBB+8'h08: ctrl_reg_rd_data_reg <= RB_BASE_ADDR+8'h10;       // I2C ctrl: Next header
            RBB+8'h0C: begin
                // I2C ctrl: control
                ctrl_reg_rd_data_reg[0] <= i2c_scl_i;
                ctrl_reg_rd_data_reg[1] <= i2c_scl_o_reg;
                ctrl_reg_rd_data_reg[8] <= i2c_sda_i;
                ctrl_reg_rd_data_reg[9] <= i2c_sda_o_reg;
            end
            // XCVR GPIO
            RBB+8'h10: ctrl_reg_rd_data_reg <= 32'h0000C101;             // XCVR GPIO: Type
            RBB+8'h14: ctrl_reg_rd_data_reg <= 32'h00000100;             // XCVR GPIO: Version
            RBB+8'h18: ctrl_reg_rd_data_reg <= 0;                        // XCVR GPIO: Next header
            RBB+8'h1C: begin
                // XCVR GPIO: control 0123
                ctrl_reg_rd_data_reg[0] <= sfp_1_mod_detect;
                ctrl_reg_rd_data_reg[1] <= sfp_1_tx_fault;
                ctrl_reg_rd_data_reg[2] <= sfp_1_los;
                ctrl_reg_rd_data_reg[5] <= sfp_1_tx_disable_reg;
                ctrl_reg_rd_data_reg[7:6] <= sfp_1_rs_reg;

                ctrl_reg_rd_data_reg[8] <= sfp_2_mod_detect;
                ctrl_reg_rd_data_reg[9] <= sfp_2_tx_fault;
                ctrl_reg_rd_data_reg[10] <= sfp_2_los;
                ctrl_reg_rd_data_reg[13] <= sfp_2_tx_disable_reg;
                ctrl_reg_rd_data_reg[15:14] <= sfp_2_rs_reg;

                ctrl_reg_rd_data_reg[16] <= sfp_3_mod_detect;
                ctrl_reg_rd_data_reg[17] <= sfp_3_tx_fault;
                ctrl_reg_rd_data_reg[18] <= sfp_3_los;
                ctrl_reg_rd_data_reg[21] <= sfp_3_tx_disable_reg;
                ctrl_reg_rd_data_reg[23:22] <= sfp_3_rs_reg;

                ctrl_reg_rd_data_reg[24] <= sfp_4_mod_detect;
                ctrl_reg_rd_data_reg[25] <= sfp_4_tx_fault;
                ctrl_reg_rd_data_reg[26] <= sfp_4_los;
                ctrl_reg_rd_data_reg[29] <= sfp_4_tx_disable_reg;
                ctrl_reg_rd_data_reg[31:30] <= sfp_4_rs_reg;
            end
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst_250mhz) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        sfp_1_rs_reg <= 2'b11;
        sfp_2_rs_reg <= 2'b11;
        sfp_3_rs_reg <= 2'b11;
        sfp_4_rs_reg <= 2'b11;

        sfp_1_tx_disable_reg <= 1'b0;
        sfp_2_tx_disable_reg <= 1'b0;
        sfp_3_tx_disable_reg <= 1'b0;
        sfp_4_tx_disable_reg <= 1'b0;

        i2c_scl_o_reg <= 1'b1;
        i2c_sda_o_reg <= 1'b1;
    end
end

assign sfp_1_led = 2'b00;
assign sfp_2_led = 2'b00;
assign sfp_3_led = 2'b00;
assign sfp_4_led = 2'b00;
assign led[0] = ptp_pps_str;
assign led[1] = 1'b0;

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
wire [PORT_COUNT*TX_TAG_WIDTH-1:0]            axis_eth_tx_ptp_ts_tag;
wire [PORT_COUNT-1:0]                         axis_eth_tx_ptp_ts_valid;
wire [PORT_COUNT-1:0]                         axis_eth_tx_ptp_ts_ready;

wire [PORT_COUNT-1:0]                         eth_tx_status;

wire [PORT_COUNT-1:0]                         eth_rx_clk;
wire [PORT_COUNT-1:0]                         eth_rx_rst;

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_rx_ptp_ts_96;
wire [PORT_COUNT-1:0]                         eth_rx_ptp_ts_step;

wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     axis_eth_rx_tdata;
wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     axis_eth_rx_tkeep;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tvalid;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tready;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tlast;
wire [PORT_COUNT*AXIS_ETH_RX_USER_WIDTH-1:0]  axis_eth_rx_tuser;

wire [PORT_COUNT-1:0]                         eth_rx_status;

wire [PORT_COUNT-1:0]                   port_xgmii_tx_clk;
wire [PORT_COUNT-1:0]                   port_xgmii_tx_rst;
wire [PORT_COUNT*XGMII_DATA_WIDTH-1:0]  port_xgmii_txd;
wire [PORT_COUNT*XGMII_CTRL_WIDTH-1:0]  port_xgmii_txc;

wire [PORT_COUNT-1:0]                   port_xgmii_rx_clk;
wire [PORT_COUNT-1:0]                   port_xgmii_rx_rst;
wire [PORT_COUNT*XGMII_DATA_WIDTH-1:0]  port_xgmii_rxd;
wire [PORT_COUNT*XGMII_CTRL_WIDTH-1:0]  port_xgmii_rxc;

mqnic_port_map_phy_xgmii #(
    .PHY_COUNT(4),
    .PORT_MASK(PORT_MASK),
    .PORT_GROUP_SIZE(1),

    .IF_COUNT(IF_COUNT),
    .PORTS_PER_IF(PORTS_PER_IF),

    .PORT_COUNT(PORT_COUNT),

    .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
    .XGMII_CTRL_WIDTH(XGMII_CTRL_WIDTH)
)
mqnic_port_map_phy_xgmii_inst (
    // towards PHY
    .phy_xgmii_tx_clk({sfp_4_tx_clk, sfp_3_tx_clk, sfp_2_tx_clk, sfp_1_tx_clk}),
    .phy_xgmii_tx_rst({sfp_4_tx_rst, sfp_3_tx_rst, sfp_2_tx_rst, sfp_1_tx_rst}),
    .phy_xgmii_txd({sfp_4_txd, sfp_3_txd, sfp_2_txd, sfp_1_txd}),
    .phy_xgmii_txc({sfp_4_txc, sfp_3_txc, sfp_2_txc, sfp_1_txc}),
    .phy_tx_status(4'hf),

    .phy_xgmii_rx_clk({sfp_4_rx_clk, sfp_3_rx_clk, sfp_2_rx_clk, sfp_1_rx_clk}),
    .phy_xgmii_rx_rst({sfp_4_rx_rst, sfp_3_rx_rst, sfp_2_rx_rst, sfp_1_rx_rst}),
    .phy_xgmii_rxd({sfp_4_rxd, sfp_3_rxd, sfp_2_rxd, sfp_1_rxd}),
    .phy_xgmii_rxc({sfp_4_rxc, sfp_3_rxc, sfp_2_rxc, sfp_1_rxc}),
    .phy_rx_status({sfp_4_rx_status, sfp_3_rx_status, sfp_2_rx_status, sfp_1_rx_status}),

    // towards MAC
    .port_xgmii_tx_clk(port_xgmii_tx_clk),
    .port_xgmii_tx_rst(port_xgmii_tx_rst),
    .port_xgmii_txd(port_xgmii_txd),
    .port_xgmii_txc(port_xgmii_txc),
    .port_tx_status(eth_tx_status),

    .port_xgmii_rx_clk(port_xgmii_rx_clk),
    .port_xgmii_rx_rst(port_xgmii_rx_rst),
    .port_xgmii_rxd(port_xgmii_rxd),
    .port_xgmii_rxc(port_xgmii_rxc),
    .port_rx_status(eth_rx_status)
);

generate
    genvar n;

    for (n = 0; n < PORT_COUNT; n = n + 1) begin : mac

        assign eth_tx_clk[n] = port_xgmii_tx_clk[n];
        assign eth_tx_rst[n] = port_xgmii_tx_rst[n];
        assign eth_rx_clk[n] = port_xgmii_rx_clk[n];
        assign eth_rx_rst[n] = port_xgmii_rx_rst[n];

        eth_mac_10g #(
            .DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
            .KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
            .ENABLE_PADDING(ENABLE_PADDING),
            .ENABLE_DIC(ENABLE_DIC),
            .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH),
            .PTP_PERIOD_NS(IF_PTP_PERIOD_NS),
            .PTP_PERIOD_FNS(IF_PTP_PERIOD_FNS),
            .TX_PTP_TS_ENABLE(PTP_TS_ENABLE),
            .TX_PTP_TS_WIDTH(PTP_TS_WIDTH),
            .TX_PTP_TAG_ENABLE(PTP_TS_ENABLE),
            .TX_PTP_TAG_WIDTH(TX_TAG_WIDTH),
            .RX_PTP_TS_ENABLE(PTP_TS_ENABLE),
            .RX_PTP_TS_WIDTH(PTP_TS_WIDTH),
            .TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
            .RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH)
        )
        eth_mac_inst (
            .tx_clk(port_xgmii_tx_clk[n]),
            .tx_rst(port_xgmii_tx_rst[n]),
            .rx_clk(port_xgmii_rx_clk[n]),
            .rx_rst(port_xgmii_rx_rst[n]),

            .tx_axis_tdata(axis_eth_tx_tdata[n*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH]),
            .tx_axis_tkeep(axis_eth_tx_tkeep[n*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH]),
            .tx_axis_tvalid(axis_eth_tx_tvalid[n +: 1]),
            .tx_axis_tready(axis_eth_tx_tready[n +: 1]),
            .tx_axis_tlast(axis_eth_tx_tlast[n +: 1]),
            .tx_axis_tuser(axis_eth_tx_tuser[n*AXIS_ETH_TX_USER_WIDTH +: AXIS_ETH_TX_USER_WIDTH]),

            .rx_axis_tdata(axis_eth_rx_tdata[n*AXIS_ETH_DATA_WIDTH +: AXIS_ETH_DATA_WIDTH]),
            .rx_axis_tkeep(axis_eth_rx_tkeep[n*AXIS_ETH_KEEP_WIDTH +: AXIS_ETH_KEEP_WIDTH]),
            .rx_axis_tvalid(axis_eth_rx_tvalid[n +: 1]),
            .rx_axis_tlast(axis_eth_rx_tlast[n +: 1]),
            .rx_axis_tuser(axis_eth_rx_tuser[n*AXIS_ETH_RX_USER_WIDTH +: AXIS_ETH_RX_USER_WIDTH]),

            .xgmii_rxd(port_xgmii_rxd[n*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH]),
            .xgmii_rxc(port_xgmii_rxc[n*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH]),
            .xgmii_txd(port_xgmii_txd[n*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH]),
            .xgmii_txc(port_xgmii_txc[n*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH]),

            .tx_ptp_ts(eth_tx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
            .rx_ptp_ts(eth_rx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
            .tx_axis_ptp_ts(axis_eth_tx_ptp_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
            .tx_axis_ptp_ts_tag(axis_eth_tx_ptp_ts_tag[n*TX_TAG_WIDTH +: TX_TAG_WIDTH]),
            .tx_axis_ptp_ts_valid(axis_eth_tx_ptp_ts_valid[n +: 1]),

            .tx_error_underflow(),
            .rx_error_bad_frame(),
            .rx_error_bad_fcs(),

            .ifg_delay(8'd12)
        );

    end

endgenerate

mqnic_core_pcie_us #(
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

    .PORT_COUNT(PORT_COUNT),

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
    .PTP_SEPARATE_TX_CLOCK(0),
    .PTP_SEPARATE_RX_CLOCK(0),
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
    .TX_CPL_ENABLE(PTP_TS_ENABLE),
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

    // RAM configuration
    .DDR_ENABLE(0),
    .HBM_ENABLE(0),

    // Application block configuration
    .APP_ID(APP_ID),
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),
    .APP_GPIO_IN_WIDTH(32),
    .APP_GPIO_OUT_WIDTH(32),

    // DMA interface configuration
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    // PCIe interface configuration
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .RC_STRADDLE(RC_STRADDLE),
    .RQ_STRADDLE(RQ_STRADDLE),
    .CQ_STRADDLE(CQ_STRADDLE),
    .CC_STRADDLE(CC_STRADDLE),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .PF_COUNT(PF_COUNT),
    .VF_COUNT(VF_COUNT),
    .F_COUNT(F_COUNT),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),

    // Interrupt configuration
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .AXIL_IF_CTRL_ADDR_WIDTH(AXIL_IF_CTRL_ADDR_WIDTH),
    .AXIL_CSR_ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .AXIL_CSR_PASSTHROUGH_ENABLE(0),
    .RB_NEXT_PTR(RB_BASE_ADDR),

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
    .s_axis_rq_seq_num_0(s_axis_rq_seq_num),
    .s_axis_rq_seq_num_valid_0(s_axis_rq_seq_num_valid),
    .s_axis_rq_seq_num_1(4'd0),
    .s_axis_rq_seq_num_valid_1(1'b0),

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
    .cfg_mgmt_addr(cfg_mgmt_addr[9:0]),
    .cfg_mgmt_function_number(cfg_mgmt_addr[17:10]),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    /*
     * Interrupt interface
     */
    .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    .cfg_interrupt_msix_vec_pending(),
    .cfg_interrupt_msix_vec_pending_status(1'b0),
    .cfg_interrupt_msix_sent(cfg_interrupt_msix_sent),
    .cfg_interrupt_msix_fail(cfg_interrupt_msix_fail),
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
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_pps(ptp_pps),
    .ptp_pps_str(ptp_pps_str),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step),
    .ptp_sync_pps(ptp_sync_pps),
    .ptp_sync_ts_96(ptp_sync_ts_96),
    .ptp_sync_ts_step(ptp_sync_ts_step),
    .ptp_perout_locked(ptp_perout_locked),
    .ptp_perout_error(ptp_perout_error),
    .ptp_perout_pulse(ptp_perout_pulse),

    /*
     * Ethernet
     */
    .eth_tx_clk(eth_tx_clk),
    .eth_tx_rst(eth_tx_rst),

    .eth_tx_ptp_clk(0),
    .eth_tx_ptp_rst(0),
    .eth_tx_ptp_ts_96(eth_tx_ptp_ts_96),
    .eth_tx_ptp_ts_step(eth_tx_ptp_ts_step),

    .m_axis_eth_tx_tdata(axis_eth_tx_tdata),
    .m_axis_eth_tx_tkeep(axis_eth_tx_tkeep),
    .m_axis_eth_tx_tvalid(axis_eth_tx_tvalid),
    .m_axis_eth_tx_tready(axis_eth_tx_tready),
    .m_axis_eth_tx_tlast(axis_eth_tx_tlast),
    .m_axis_eth_tx_tuser(axis_eth_tx_tuser),

    .s_axis_eth_tx_cpl_ts(axis_eth_tx_ptp_ts),
    .s_axis_eth_tx_cpl_tag(axis_eth_tx_ptp_ts_tag),
    .s_axis_eth_tx_cpl_valid(axis_eth_tx_ptp_ts_valid),
    .s_axis_eth_tx_cpl_ready(axis_eth_tx_ptp_ts_ready),

    .eth_tx_status(eth_tx_status),

    .eth_rx_clk(eth_rx_clk),
    .eth_rx_rst(eth_rx_rst),

    .eth_rx_ptp_clk(0),
    .eth_rx_ptp_rst(0),
    .eth_rx_ptp_ts_96(eth_rx_ptp_ts_96),
    .eth_rx_ptp_ts_step(eth_rx_ptp_ts_step),

    .s_axis_eth_rx_tdata(axis_eth_rx_tdata),
    .s_axis_eth_rx_tkeep(axis_eth_rx_tkeep),
    .s_axis_eth_rx_tvalid(axis_eth_rx_tvalid),
    .s_axis_eth_rx_tready(axis_eth_rx_tready),
    .s_axis_eth_rx_tlast(axis_eth_rx_tlast),
    .s_axis_eth_rx_tuser(axis_eth_rx_tuser),

    .eth_rx_status(eth_rx_status),

    /*
     * DDR
     */
    .ddr_clk(0),
    .ddr_rst(0),

    .m_axi_ddr_awid(),
    .m_axi_ddr_awaddr(),
    .m_axi_ddr_awlen(),
    .m_axi_ddr_awsize(),
    .m_axi_ddr_awburst(),
    .m_axi_ddr_awlock(),
    .m_axi_ddr_awcache(),
    .m_axi_ddr_awprot(),
    .m_axi_ddr_awqos(),
    .m_axi_ddr_awuser(),
    .m_axi_ddr_awvalid(),
    .m_axi_ddr_awready(0),
    .m_axi_ddr_wdata(),
    .m_axi_ddr_wstrb(),
    .m_axi_ddr_wlast(),
    .m_axi_ddr_wuser(),
    .m_axi_ddr_wvalid(),
    .m_axi_ddr_wready(0),
    .m_axi_ddr_bid(0),
    .m_axi_ddr_bresp(0),
    .m_axi_ddr_buser(0),
    .m_axi_ddr_bvalid(0),
    .m_axi_ddr_bready(),
    .m_axi_ddr_arid(),
    .m_axi_ddr_araddr(),
    .m_axi_ddr_arlen(),
    .m_axi_ddr_arsize(),
    .m_axi_ddr_arburst(),
    .m_axi_ddr_arlock(),
    .m_axi_ddr_arcache(),
    .m_axi_ddr_arprot(),
    .m_axi_ddr_arqos(),
    .m_axi_ddr_aruser(),
    .m_axi_ddr_arvalid(),
    .m_axi_ddr_arready(0),
    .m_axi_ddr_rid(0),
    .m_axi_ddr_rdata(0),
    .m_axi_ddr_rresp(0),
    .m_axi_ddr_rlast(0),
    .m_axi_ddr_ruser(0),
    .m_axi_ddr_rvalid(0),
    .m_axi_ddr_rready(),

    .ddr_status(0),

    /*
     * HBM
     */
    .hbm_clk(0),
    .hbm_rst(0),

    .m_axi_hbm_awid(),
    .m_axi_hbm_awaddr(),
    .m_axi_hbm_awlen(),
    .m_axi_hbm_awsize(),
    .m_axi_hbm_awburst(),
    .m_axi_hbm_awlock(),
    .m_axi_hbm_awcache(),
    .m_axi_hbm_awprot(),
    .m_axi_hbm_awqos(),
    .m_axi_hbm_awuser(),
    .m_axi_hbm_awvalid(),
    .m_axi_hbm_awready(0),
    .m_axi_hbm_wdata(),
    .m_axi_hbm_wstrb(),
    .m_axi_hbm_wlast(),
    .m_axi_hbm_wuser(),
    .m_axi_hbm_wvalid(),
    .m_axi_hbm_wready(0),
    .m_axi_hbm_bid(0),
    .m_axi_hbm_bresp(0),
    .m_axi_hbm_buser(0),
    .m_axi_hbm_bvalid(0),
    .m_axi_hbm_bready(),
    .m_axi_hbm_arid(),
    .m_axi_hbm_araddr(),
    .m_axi_hbm_arlen(),
    .m_axi_hbm_arsize(),
    .m_axi_hbm_arburst(),
    .m_axi_hbm_arlock(),
    .m_axi_hbm_arcache(),
    .m_axi_hbm_arprot(),
    .m_axi_hbm_arqos(),
    .m_axi_hbm_aruser(),
    .m_axi_hbm_arvalid(),
    .m_axi_hbm_arready(0),
    .m_axi_hbm_rid(0),
    .m_axi_hbm_rdata(0),
    .m_axi_hbm_rresp(0),
    .m_axi_hbm_rlast(0),
    .m_axi_hbm_ruser(0),
    .m_axi_hbm_rvalid(0),
    .m_axi_hbm_rready(),

    .hbm_status(0),

    /*
     * Statistics input
     */
    .s_axis_stat_tdata(0),
    .s_axis_stat_tid(0),
    .s_axis_stat_tvalid(1'b0),
    .s_axis_stat_tready(),

    /*
     * GPIO
     */
    .app_gpio_in(0),
    .app_gpio_out(),

    /*
     * JTAG
     */
    .app_jtag_tdi(1'b0),
    .app_jtag_tdo(),
    .app_jtag_tms(1'b0),
    .app_jtag_tck(1'b0)
);

assign cfg_mgmt_addr[18] = 1'b0;

endmodule

`resetall
