/*

Copyright 2021, The Regents of the University of California.
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
    parameter BOARD_ID = {16'h1c2c, 16'ha00e},
    parameter BOARD_VER = {16'd0, 16'd1},
    parameter FPGA_ID = 32'h432AC0DD,

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
    parameter PTP_PEROUT_ENABLE = 1,
    parameter PTP_PEROUT_COUNT = 1,
    parameter IF_PTP_PERIOD_NS = 6'h6,
    parameter IF_PTP_PERIOD_FNS = 16'h6666,

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
    parameter SEG_COUNT = 1,
    parameter SEG_DATA_WIDTH = 256,
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    parameter TX_SEQ_NUM_WIDTH = 6,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter PCIE_TAG_COUNT = 256,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_READ_TX_FC_ENABLE = 1,
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_WRITE_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_WRITE_TX_FC_ENABLE = 1,
    parameter MSI_COUNT = 32,

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
    input  wire                                  clk_250mhz,
    input  wire                                  rst_250mhz,

    /*
     * GPIO
     */
    output wire [3:0]                            user_led,

    /*
     * H-Tile interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]  rx_st_empty,
    input  wire [SEG_COUNT-1:0]                  rx_st_sop,
    input  wire [SEG_COUNT-1:0]                  rx_st_eop,
    input  wire [SEG_COUNT-1:0]                  rx_st_valid,
    output wire                                  rx_st_ready,
    input  wire [SEG_COUNT-1:0]                  rx_st_vf_active,
    input  wire [SEG_COUNT*2-1:0]                rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]               rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                rx_st_bar_range,

    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   tx_st_data,
    output wire [SEG_COUNT-1:0]                  tx_st_sop,
    output wire [SEG_COUNT-1:0]                  tx_st_eop,
    output wire [SEG_COUNT-1:0]                  tx_st_valid,
    input  wire                                  tx_st_ready,
    output wire [SEG_COUNT-1:0]                  tx_st_err,

    input  wire [7:0]                            tx_ph_cdts,
    input  wire [11:0]                           tx_pd_cdts,
    input  wire [7:0]                            tx_nph_cdts,
    input  wire [11:0]                           tx_npd_cdts,
    input  wire [7:0]                            tx_cplh_cdts,
    input  wire [11:0]                           tx_cpld_cdts,
    input  wire [SEG_COUNT-1:0]                  tx_hdr_cdts_consumed,
    input  wire [SEG_COUNT-1:0]                  tx_data_cdts_consumed,
    input  wire [SEG_COUNT*2-1:0]                tx_cdts_type,
    input  wire [SEG_COUNT*1-1:0]                tx_cdts_data_value,

    output wire                                  app_msi_req,
    input  wire                                  app_msi_ack,
    output wire [2:0]                            app_msi_tc,
    output wire [4:0]                            app_msi_num,
    output wire [1:0]                            app_msi_func_num,

    input  wire [31:0]                           tl_cfg_ctl,
    input  wire [4:0]                            tl_cfg_add,
    input  wire [1:0]                            tl_cfg_func,

    /*
     * Ethernet: QSFP28
     */
    input  wire                                  qsfp0_tx_clk_1,
    input  wire                                  qsfp0_tx_rst_1,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp0_txd_1,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_txc_1,
    output wire                                  qsfp0_tx_prbs31_enable_1,
    input  wire                                  qsfp0_rx_clk_1,
    input  wire                                  qsfp0_rx_rst_1,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp0_rxd_1,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_rxc_1,
    output wire                                  qsfp0_rx_prbs31_enable_1,
    input  wire [6:0]                            qsfp0_rx_error_count_1,
    input  wire                                  qsfp0_tx_clk_2,
    input  wire                                  qsfp0_tx_rst_2,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp0_txd_2,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_txc_2,
    output wire                                  qsfp0_tx_prbs31_enable_2,
    input  wire                                  qsfp0_rx_clk_2,
    input  wire                                  qsfp0_rx_rst_2,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp0_rxd_2,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_rxc_2,
    output wire                                  qsfp0_rx_prbs31_enable_2,
    input  wire [6:0]                            qsfp0_rx_error_count_2,
    input  wire                                  qsfp0_tx_clk_3,
    input  wire                                  qsfp0_tx_rst_3,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp0_txd_3,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_txc_3,
    output wire                                  qsfp0_tx_prbs31_enable_3,
    input  wire                                  qsfp0_rx_clk_3,
    input  wire                                  qsfp0_rx_rst_3,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp0_rxd_3,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_rxc_3,
    output wire                                  qsfp0_rx_prbs31_enable_3,
    input  wire [6:0]                            qsfp0_rx_error_count_3,
    input  wire                                  qsfp0_tx_clk_4,
    input  wire                                  qsfp0_tx_rst_4,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp0_txd_4,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_txc_4,
    output wire                                  qsfp0_tx_prbs31_enable_4,
    input  wire                                  qsfp0_rx_clk_4,
    input  wire                                  qsfp0_rx_rst_4,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp0_rxd_4,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp0_rxc_4,
    output wire                                  qsfp0_rx_prbs31_enable_4,
    input  wire [6:0]                            qsfp0_rx_error_count_4,
    input  wire                                  qsfp1_tx_clk_1,
    input  wire                                  qsfp1_tx_rst_1,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp1_txd_1,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_txc_1,
    output wire                                  qsfp1_tx_prbs31_enable_1,
    input  wire                                  qsfp1_rx_clk_1,
    input  wire                                  qsfp1_rx_rst_1,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp1_rxd_1,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_rxc_1,
    output wire                                  qsfp1_rx_prbs31_enable_1,
    input  wire [6:0]                            qsfp1_rx_error_count_1,
    input  wire                                  qsfp1_tx_clk_2,
    input  wire                                  qsfp1_tx_rst_2,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp1_txd_2,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_txc_2,
    output wire                                  qsfp1_tx_prbs31_enable_2,
    input  wire                                  qsfp1_rx_clk_2,
    input  wire                                  qsfp1_rx_rst_2,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp1_rxd_2,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_rxc_2,
    output wire                                  qsfp1_rx_prbs31_enable_2,
    input  wire [6:0]                            qsfp1_rx_error_count_2,
    input  wire                                  qsfp1_tx_clk_3,
    input  wire                                  qsfp1_tx_rst_3,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp1_txd_3,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_txc_3,
    output wire                                  qsfp1_tx_prbs31_enable_3,
    input  wire                                  qsfp1_rx_clk_3,
    input  wire                                  qsfp1_rx_rst_3,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp1_rxd_3,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_rxc_3,
    output wire                                  qsfp1_rx_prbs31_enable_3,
    input  wire [6:0]                            qsfp1_rx_error_count_3,
    input  wire                                  qsfp1_tx_clk_4,
    input  wire                                  qsfp1_tx_rst_4,
    output wire [XGMII_DATA_WIDTH-1:0]           qsfp1_txd_4,
    output wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_txc_4,
    output wire                                  qsfp1_tx_prbs31_enable_4,
    input  wire                                  qsfp1_rx_clk_4,
    input  wire                                  qsfp1_rx_rst_4,
    input  wire [XGMII_DATA_WIDTH-1:0]           qsfp1_rxd_4,
    input  wire [XGMII_CTRL_WIDTH-1:0]           qsfp1_rxc_4,
    output wire                                  qsfp1_rx_prbs31_enable_4,
    input  wire [6:0]                            qsfp1_rx_error_count_4
);

parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF;

parameter F_COUNT = PF_COUNT+VF_COUNT;

parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8);
parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT);
parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8);

initial begin
    if (PORT_COUNT > 8) begin
        $error("Error: Max port count exceeded (instance %m)");
        $finish;
    end
end

// AXI lite connections
wire [AXIL_CSR_ADDR_WIDTH-1:0]   axil_csr_awaddr;
wire [2:0]                       axil_csr_awprot;
wire                             axil_csr_awvalid;
wire                             axil_csr_awready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_csr_wdata;
wire [AXIL_CTRL_STRB_WIDTH-1:0]  axil_csr_wstrb;
wire                             axil_csr_wvalid;
wire                             axil_csr_wready;
wire [1:0]                       axil_csr_bresp;
wire                             axil_csr_bvalid;
wire                             axil_csr_bready;
wire [AXIL_CSR_ADDR_WIDTH-1:0]   axil_csr_araddr;
wire [2:0]                       axil_csr_arprot;
wire                             axil_csr_arvalid;
wire                             axil_csr_arready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_csr_rdata;
wire [1:0]                       axil_csr_rresp;
wire                             axil_csr_rvalid;
wire                             axil_csr_rready;

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

reg qsfp0_reset_reg = 1'b0;
reg qsfp0_lp_mode_reg = 1'b0;
// reg qsfp0_i2c_scl_o_reg = 1'b1;
// reg qsfp0_i2c_sda_o_reg = 1'b1;

reg qsfp1_reset_reg = 1'b0;
reg qsfp1_lp_mode_reg = 1'b0;
// reg qsfp1_i2c_scl_o_reg = 1'b1;
// reg qsfp1_i2c_sda_o_reg = 1'b1;

// reg fpga_boot_reg = 1'b0;

// reg qspi_clk_reg = 1'b0;
// reg qspi_cs_reg = 1'b1;
// reg [3:0] qspi_dq_o_reg = 4'd0;
// reg [3:0] qspi_dq_oe_reg = 4'd0;

assign ctrl_reg_wr_wait = 1'b0;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_reg;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_reg;
assign ctrl_reg_rd_wait = 1'b0;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_reg;

// assign qsfp0_reset_n = !qsfp0_reset_reg;
// assign qsfp0_lp_mode = qsfp0_lp_mode_reg;
// assign qsfp0_i2c_scl_o = qsfp0_i2c_scl_o_reg;
// assign qsfp0_i2c_scl_t = qsfp0_i2c_scl_o_reg;
// assign qsfp0_i2c_sda_o = qsfp0_i2c_sda_o_reg;
// assign qsfp0_i2c_sda_t = qsfp0_i2c_sda_o_reg;

// assign qsfp1_reset_n = !qsfp1_reset_reg;
// assign qsfp1_lp_mode = qsfp1_lp_mode_reg;
// assign qsfp1_i2c_scl_o = qsfp1_i2c_scl_o_reg;
// assign qsfp1_i2c_scl_t = qsfp1_i2c_scl_o_reg;
// assign qsfp1_i2c_sda_o = qsfp1_i2c_sda_o_reg;
// assign qsfp1_i2c_sda_t = qsfp1_i2c_sda_o_reg;

// assign fpga_boot = fpga_boot_reg;

// assign qspi_clk = qspi_clk_reg;
// assign qspi_cs = qspi_cs_reg;
// assign qspi_dq_o = qspi_dq_o_reg;
// assign qspi_dq_oe = qspi_dq_oe_reg;

always @(posedge clk_250mhz) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_CTRL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b0;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            // 16'h0040: begin
            //     // FPGA ID
            //     fpga_boot_reg <= ctrl_reg_wr_data == 32'hFEE1DEAD;
            // end
            // GPIO
            // 16'h0110: begin
            //     // GPIO I2C 0
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qsfp0_i2c_scl_o_reg <= ctrl_reg_wr_data[1];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qsfp0_i2c_sda_o_reg <= ctrl_reg_wr_data[9];
            //     end
            // end
            // 16'h0114: begin
            //     // GPIO I2C 1
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qsfp1_i2c_scl_o_reg <= ctrl_reg_wr_data[1];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qsfp1_i2c_sda_o_reg <= ctrl_reg_wr_data[9];
            //     end
            // end
            // 16'h0120: begin
            //     // GPIO XCVR 0123
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qsfp0_reset_reg <= ctrl_reg_wr_data[4];
            //         qsfp0_lp_mode_reg <= ctrl_reg_wr_data[5];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qsfp1_reset_reg <= ctrl_reg_wr_data[12];
            //         qsfp1_lp_mode_reg <= ctrl_reg_wr_data[13];
            //     end
            // end
            // Flash
            // 16'h0144: begin
            //     // QSPI control
            //     if (ctrl_reg_wr_strb[0]) begin
            //         qspi_dq_o_reg <= ctrl_reg_wr_data[3:0];
            //     end
            //     if (ctrl_reg_wr_strb[1]) begin
            //         qspi_dq_oe_reg <= ctrl_reg_wr_data[11:8];
            //     end
            //     if (ctrl_reg_wr_strb[2]) begin
            //         qspi_clk_reg <= ctrl_reg_wr_data[16];
            //         qspi_cs_reg <= ctrl_reg_wr_data[17];
            //     end
            // end
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            16'h0040: ctrl_reg_rd_data_reg <= FPGA_ID; // FPGA ID
            // GPIO
            // 16'h0110: begin
            //     // GPIO I2C 0
            //     ctrl_reg_rd_data_reg[0] <= qsfp0_i2c_scl_i;
            //     ctrl_reg_rd_data_reg[1] <= qsfp0_i2c_scl_o_reg;
            //     ctrl_reg_rd_data_reg[8] <= qsfp0_i2c_sda_i;
            //     ctrl_reg_rd_data_reg[9] <= qsfp0_i2c_sda_o_reg;
            // end
            // 16'h0114: begin
            //     // GPIO I2C 1
            //     ctrl_reg_rd_data_reg[0] <= qsfp1_i2c_scl_i;
            //     ctrl_reg_rd_data_reg[1] <= qsfp1_i2c_scl_o_reg;
            //     ctrl_reg_rd_data_reg[8] <= qsfp1_i2c_sda_i;
            //     ctrl_reg_rd_data_reg[9] <= qsfp1_i2c_sda_o_reg;
            // end
            // 16'h0120: begin
            //     // GPIO XCVR 0123
            //     ctrl_reg_rd_data_reg[0] <= !qsfp0_mod_prsnt_n;
            //     ctrl_reg_rd_data_reg[1] <= !qsfp0_intr_n;
            //     ctrl_reg_rd_data_reg[4] <= qsfp0_reset_reg;
            //     ctrl_reg_rd_data_reg[5] <= qsfp0_lp_mode_reg;
            //     ctrl_reg_rd_data_reg[8] <= !qsfp1_mod_prsnt_n;
            //     ctrl_reg_rd_data_reg[9] <= !qsfp1_intr_n;
            //     ctrl_reg_rd_data_reg[12] <= qsfp1_reset_reg;
            //     ctrl_reg_rd_data_reg[13] <= qsfp1_lp_mode_reg;
            // end
            // Flash
            // 16'h0140: begin
            //     // Flash ID
            //     ctrl_reg_rd_data_reg[7:0]   <= 0; // type (SPI)
            //     ctrl_reg_rd_data_reg[15:8]  <= 1; // configuration (one segment)
            //     ctrl_reg_rd_data_reg[23:16] <= 4; // data width (QSPI)
            //     ctrl_reg_rd_data_reg[31:24] <= 0; // address width (N/A for SPI)
            // end
            // 16'h0144: begin
            //     // QSPI control
            //     ctrl_reg_rd_data_reg[3:0] <= qspi_dq_i;
            //     ctrl_reg_rd_data_reg[11:8] <= qspi_dq_oe;
            //     ctrl_reg_rd_data_reg[16] <= qspi_clk;
            //     ctrl_reg_rd_data_reg[17] <= qspi_cs;
            // end
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst_250mhz) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        qsfp0_reset_reg <= 1'b0;
        qsfp0_lp_mode_reg <= 1'b0;
        // qsfp0_i2c_scl_o_reg <= 1'b1;
        // qsfp0_i2c_sda_o_reg <= 1'b1;

        qsfp1_reset_reg <= 1'b0;
        qsfp1_lp_mode_reg <= 1'b0;
        // qsfp1_i2c_scl_o_reg <= 1'b1;
        // qsfp1_i2c_sda_o_reg <= 1'b1;

        // qspi_clk_reg <= 1'b0;
        // qspi_cs_reg <= 1'b1;
        // qspi_dq_o_reg <= 4'd0;
        // qspi_dq_oe_reg <= 4'd0;
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

// // BER tester
// tdma_ber #(
//     .COUNT(8),
//     .INDEX_WIDTH(6),
//     .SLICE_WIDTH(5),
//     .AXIL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
//     .AXIL_ADDR_WIDTH(8+6+$clog2(8)),
//     .AXIL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
//     .SCHEDULE_START_S(0),
//     .SCHEDULE_START_NS(0),
//     .SCHEDULE_PERIOD_S(0),
//     .SCHEDULE_PERIOD_NS(1000000),
//     .TIMESLOT_PERIOD_S(0),
//     .TIMESLOT_PERIOD_NS(100000),
//     .ACTIVE_PERIOD_S(0),
//     .ACTIVE_PERIOD_NS(90000)
// )
// tdma_ber_inst (
//     .clk(clk_250mhz),
//     .rst(rst_250mhz),
//     .phy_tx_clk({qsfp1_tx_clk_4, qsfp1_tx_clk_3, qsfp1_tx_clk_2, qsfp1_tx_clk_1, qsfp0_tx_clk_4, qsfp0_tx_clk_3, qsfp0_tx_clk_2, qsfp0_tx_clk_1}),
//     .phy_rx_clk({qsfp1_rx_clk_4, qsfp1_rx_clk_3, qsfp1_rx_clk_2, qsfp1_rx_clk_1, qsfp0_rx_clk_4, qsfp0_rx_clk_3, qsfp0_rx_clk_2, qsfp0_rx_clk_1}),
//     .phy_rx_error_count({qsfp1_rx_error_count_4, qsfp1_rx_error_count_3, qsfp1_rx_error_count_2, qsfp1_rx_error_count_1, qsfp0_rx_error_count_4, qsfp0_rx_error_count_3, qsfp0_rx_error_count_2, qsfp0_rx_error_count_1}),
//     .phy_tx_prbs31_enable({qsfp1_tx_prbs31_enable_4, qsfp1_tx_prbs31_enable_3, qsfp1_tx_prbs31_enable_2, qsfp1_tx_prbs31_enable_1, qsfp0_tx_prbs31_enable_4, qsfp0_tx_prbs31_enable_3, qsfp0_tx_prbs31_enable_2, qsfp0_tx_prbs31_enable_1}),
//     .phy_rx_prbs31_enable({qsfp1_rx_prbs31_enable_4, qsfp1_rx_prbs31_enable_3, qsfp1_rx_prbs31_enable_2, qsfp1_rx_prbs31_enable_1, qsfp0_rx_prbs31_enable_4, qsfp0_rx_prbs31_enable_3, qsfp0_rx_prbs31_enable_2, qsfp0_rx_prbs31_enable_1}),
//     .s_axil_awaddr(axil_csr_awaddr),
//     .s_axil_awprot(axil_csr_awprot),
//     .s_axil_awvalid(axil_csr_awvalid),
//     .s_axil_awready(axil_csr_awready),
//     .s_axil_wdata(axil_csr_wdata),
//     .s_axil_wstrb(axil_csr_wstrb),
//     .s_axil_wvalid(axil_csr_wvalid),
//     .s_axil_wready(axil_csr_wready),
//     .s_axil_bresp(axil_csr_bresp),
//     .s_axil_bvalid(axil_csr_bvalid),
//     .s_axil_bready(axil_csr_bready),
//     .s_axil_araddr(axil_csr_araddr),
//     .s_axil_arprot(axil_csr_arprot),
//     .s_axil_arvalid(axil_csr_arvalid),
//     .s_axil_arready(axil_csr_arready),
//     .s_axil_rdata(axil_csr_rdata),
//     .s_axil_rresp(axil_csr_rresp),
//     .s_axil_rvalid(axil_csr_rvalid),
//     .s_axil_rready(axil_csr_rready),
//     .ptp_ts_96(ptp_ts_96),
//     .ptp_ts_step(ptp_ts_step)
// );

assign user_led[0] = pps_led_reg;
assign user_led[1] = 1'b0;
assign user_led[2] = 1'b0;
assign user_led[3] = 1'b0;

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

wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_rx_ptp_ts_96;
wire [PORT_COUNT-1:0]                         eth_rx_ptp_ts_step;

wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     axis_eth_rx_tdata;
wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     axis_eth_rx_tkeep;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tvalid;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tready;
wire [PORT_COUNT-1:0]                         axis_eth_rx_tlast;
wire [PORT_COUNT*AXIS_ETH_RX_USER_WIDTH-1:0]  axis_eth_rx_tuser;

wire [PORT_COUNT-1:0]                   port_xgmii_tx_clk;
wire [PORT_COUNT-1:0]                   port_xgmii_tx_rst;
wire [PORT_COUNT*XGMII_DATA_WIDTH-1:0]  port_xgmii_txd;
wire [PORT_COUNT*XGMII_CTRL_WIDTH-1:0]  port_xgmii_txc;

wire [PORT_COUNT-1:0]                   port_xgmii_rx_clk;
wire [PORT_COUNT-1:0]                   port_xgmii_rx_rst;
wire [PORT_COUNT*XGMII_DATA_WIDTH-1:0]  port_xgmii_rxd;
wire [PORT_COUNT*XGMII_CTRL_WIDTH-1:0]  port_xgmii_rxc;

//  counts    QSFP 0                                QSFP 1
// IF  PORT   0_1      0_2      0_3      0_4        1_1      1_2      1_3      1_4  
// 1   1      0 (0.0)
// 1   2      0 (0.0)  1 (0.1)
// 1   3      0 (0.0)  1 (0.1)  2 (0.2)
// 1   4      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)
// 1   5      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)
// 1   6      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)  5 (0.5)
// 1   7      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)  5 (0.5)  6 (0.6)
// 1   8      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)  5 (0.5)  6 (0.6)  7 (0.7)
// 2   1      0 (0.0)                               1 (1.0)
// 2   2      0 (0.0)  1 (0.1)                      2 (1.0)  3 (1.1)
// 2   3      0 (0.0)  1 (0.1)  2 (0.2)             3 (1.0)  4 (1.1)  5 (1.2)
// 2   4      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (1.0)  5 (1.1)  6 (1.2)  7 (1.3)
// 3   1      0 (0.0)  1 (1.0)  2 (2.0)
// 3   2      0 (0.0)  1 (0.1)  2 (1.0)  3 (1.1)    4 (2.0)  5 (2.1)
// 4   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)
// 4   2      0 (0.0)  1 (0.1)  2 (1.0)  3 (1.1)    4 (2.0)  5 (2.1)  6 (3.0)  7 (3.1)
// 5   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)
// 6   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)  5 (5.0)
// 7   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)  5 (5.0)  6 (6.0)
// 8   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)  5 (5.0)  6 (6.0)  7 (7.0)

localparam QSFP0_1_IND = 0;
localparam QSFP0_2_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 1 ? 1 : -1) : 1;
localparam QSFP0_3_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 2 ? 2 : -1) : 2;
localparam QSFP0_4_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 3 ? 3 : -1) : 3;
localparam QSFP1_1_IND = IF_COUNT == 2 ? PORTS_PER_IF : 4;
localparam QSFP1_2_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 1 ? PORTS_PER_IF+1 : -1) : 5;
localparam QSFP1_3_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 2 ? PORTS_PER_IF+2 : -1) : 6;
localparam QSFP1_4_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 3 ? PORTS_PER_IF+3 : -1) : 7;

generate
    genvar m, n;

    if (QSFP0_1_IND >= 0 && QSFP0_1_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP0_1_IND] = qsfp0_tx_clk_1;
        assign port_xgmii_tx_rst[QSFP0_1_IND] = qsfp0_tx_rst_1;
        assign port_xgmii_rx_clk[QSFP0_1_IND] = qsfp0_rx_clk_1;
        assign port_xgmii_rx_rst[QSFP0_1_IND] = qsfp0_rx_rst_1;
        assign port_xgmii_rxd[QSFP0_1_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp0_rxd_1;
        assign port_xgmii_rxc[QSFP0_1_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp0_rxc_1;

        assign qsfp0_txd_1 = port_xgmii_txd[QSFP0_1_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp0_txc_1 = port_xgmii_txc[QSFP0_1_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp0_txd_1 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp0_txc_1 = {XGMII_CTRL_WIDTH{1'b1}};
    end

    if (QSFP0_2_IND >= 0 && QSFP0_2_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP0_2_IND] = qsfp0_tx_clk_2;
        assign port_xgmii_tx_rst[QSFP0_2_IND] = qsfp0_tx_rst_2;
        assign port_xgmii_rx_clk[QSFP0_2_IND] = qsfp0_rx_clk_2;
        assign port_xgmii_rx_rst[QSFP0_2_IND] = qsfp0_rx_rst_2;
        assign port_xgmii_rxd[QSFP0_2_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp0_rxd_2;
        assign port_xgmii_rxc[QSFP0_2_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp0_rxc_2;

        assign qsfp0_txd_2 = port_xgmii_txd[QSFP0_2_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp0_txc_2 = port_xgmii_txc[QSFP0_2_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp0_txd_2 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp0_txc_2 = {XGMII_CTRL_WIDTH{1'b1}};
    end

    if (QSFP0_3_IND >= 0 && QSFP0_3_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP0_3_IND] = qsfp0_tx_clk_3;
        assign port_xgmii_tx_rst[QSFP0_3_IND] = qsfp0_tx_rst_3;
        assign port_xgmii_rx_clk[QSFP0_3_IND] = qsfp0_rx_clk_3;
        assign port_xgmii_rx_rst[QSFP0_3_IND] = qsfp0_rx_rst_3;
        assign port_xgmii_rxd[QSFP0_3_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp0_rxd_3;
        assign port_xgmii_rxc[QSFP0_3_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp0_rxc_3;

        assign qsfp0_txd_3 = port_xgmii_txd[QSFP0_3_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp0_txc_3 = port_xgmii_txc[QSFP0_3_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp0_txd_3 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp0_txc_3 = {XGMII_CTRL_WIDTH{1'b1}};
    end

    if (QSFP0_4_IND >= 0 && QSFP0_4_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP0_4_IND] = qsfp0_tx_clk_4;
        assign port_xgmii_tx_rst[QSFP0_4_IND] = qsfp0_tx_rst_4;
        assign port_xgmii_rx_clk[QSFP0_4_IND] = qsfp0_rx_clk_4;
        assign port_xgmii_rx_rst[QSFP0_4_IND] = qsfp0_rx_rst_4;
        assign port_xgmii_rxd[QSFP0_4_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp0_rxd_4;
        assign port_xgmii_rxc[QSFP0_4_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp0_rxc_4;

        assign qsfp0_txd_4 = port_xgmii_txd[QSFP0_4_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp0_txc_4 = port_xgmii_txc[QSFP0_4_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp0_txd_4 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp0_txc_4 = {XGMII_CTRL_WIDTH{1'b1}};
    end

    if (QSFP1_1_IND >= 0 && QSFP1_1_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_1_IND] = qsfp1_tx_clk_1;
        assign port_xgmii_tx_rst[QSFP1_1_IND] = qsfp1_tx_rst_1;
        assign port_xgmii_rx_clk[QSFP1_1_IND] = qsfp1_rx_clk_1;
        assign port_xgmii_rx_rst[QSFP1_1_IND] = qsfp1_rx_rst_1;
        assign port_xgmii_rxd[QSFP1_1_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp1_rxd_1;
        assign port_xgmii_rxc[QSFP1_1_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp1_rxc_1;

        assign qsfp1_txd_1 = port_xgmii_txd[QSFP1_1_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp1_txc_1 = port_xgmii_txc[QSFP1_1_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp1_txd_1 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp1_txc_1 = {XGMII_CTRL_WIDTH{1'b1}};
    end

    if (QSFP1_2_IND >= 0 && QSFP1_2_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_2_IND] = qsfp1_tx_clk_2;
        assign port_xgmii_tx_rst[QSFP1_2_IND] = qsfp1_tx_rst_2;
        assign port_xgmii_rx_clk[QSFP1_2_IND] = qsfp1_rx_clk_2;
        assign port_xgmii_rx_rst[QSFP1_2_IND] = qsfp1_rx_rst_2;
        assign port_xgmii_rxd[QSFP1_2_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp1_rxd_2;
        assign port_xgmii_rxc[QSFP1_2_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp1_rxc_2;

        assign qsfp1_txd_2 = port_xgmii_txd[QSFP1_2_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp1_txc_2 = port_xgmii_txc[QSFP1_2_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp1_txd_2 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp1_txc_2 = {XGMII_CTRL_WIDTH{1'b1}};
    end

    if (QSFP1_3_IND >= 0 && QSFP1_3_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_3_IND] = qsfp1_tx_clk_3;
        assign port_xgmii_tx_rst[QSFP1_3_IND] = qsfp1_tx_rst_3;
        assign port_xgmii_rx_clk[QSFP1_3_IND] = qsfp1_rx_clk_3;
        assign port_xgmii_rx_rst[QSFP1_3_IND] = qsfp1_rx_rst_3;
        assign port_xgmii_rxd[QSFP1_3_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp1_rxd_3;
        assign port_xgmii_rxc[QSFP1_3_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp1_rxc_3;

        assign qsfp1_txd_3 = port_xgmii_txd[QSFP1_3_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp1_txc_3 = port_xgmii_txc[QSFP1_3_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp1_txd_3 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp1_txc_3 = {XGMII_CTRL_WIDTH{1'b1}};
    end

    if (QSFP1_4_IND >= 0 && QSFP1_4_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_4_IND] = qsfp1_tx_clk_4;
        assign port_xgmii_tx_rst[QSFP1_4_IND] = qsfp1_tx_rst_4;
        assign port_xgmii_rx_clk[QSFP1_4_IND] = qsfp1_rx_clk_4;
        assign port_xgmii_rx_rst[QSFP1_4_IND] = qsfp1_rx_rst_4;
        assign port_xgmii_rxd[QSFP1_4_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = qsfp1_rxd_4;
        assign port_xgmii_rxc[QSFP1_4_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = qsfp1_rxc_4;

        assign qsfp1_txd_4 = port_xgmii_txd[QSFP1_4_IND*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
        assign qsfp1_txc_4 = port_xgmii_txc[QSFP1_4_IND*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];
    end else begin
        assign qsfp1_txd_4 = {XGMII_CTRL_WIDTH{8'h07}};
        assign qsfp1_txc_4 = {XGMII_CTRL_WIDTH{1'b1}};
    end

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
            .TX_PTP_TAG_WIDTH(PTP_TAG_WIDTH),
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
            .tx_axis_ptp_ts_tag(axis_eth_tx_ptp_ts_tag[n*PTP_TAG_WIDTH +: PTP_TAG_WIDTH]),
            .tx_axis_ptp_ts_valid(axis_eth_tx_ptp_ts_valid[n +: 1]),

            .tx_error_underflow(),
            .rx_error_bad_frame(),
            .rx_error_bad_fcs(),

            .ifg_delay(8'd12)
        );

    end

endgenerate

mqnic_core_pcie_s10 #(
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
    .PTP_SEPARATE_RX_CLOCK(0),
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
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
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
     * H-tile RX AVST interface
     */
    .rx_st_data(rx_st_data),
    .rx_st_empty(rx_st_empty),
    .rx_st_sop(rx_st_sop),
    .rx_st_eop(rx_st_eop),
    .rx_st_valid(rx_st_valid),
    .rx_st_ready(rx_st_ready),
    .rx_st_vf_active(rx_st_vf_active),
    .rx_st_func_num(rx_st_func_num),
    .rx_st_vf_num(rx_st_vf_num),
    .rx_st_bar_range(rx_st_bar_range),

    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),

    .tx_ph_cdts(tx_ph_cdts),
    .tx_pd_cdts(tx_pd_cdts),
    .tx_nph_cdts(tx_nph_cdts),
    .tx_npd_cdts(tx_npd_cdts),
    .tx_cplh_cdts(tx_cplh_cdts),
    .tx_cpld_cdts(tx_cpld_cdts),
    .tx_hdr_cdts_consumed(tx_hdr_cdts_consumed),
    .tx_data_cdts_consumed(tx_data_cdts_consumed),
    .tx_cdts_type(tx_cdts_type),
    .tx_cdts_data_value(tx_cdts_data_value),

    .app_msi_req(app_msi_req),
    .app_msi_ack(app_msi_ack),
    .app_msi_tc(app_msi_tc),
    .app_msi_num(app_msi_num),
    .app_msi_func_num(app_msi_func_num),

    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    .m_axil_csr_awaddr(axil_csr_awaddr),
    .m_axil_csr_awprot(axil_csr_awprot),
    .m_axil_csr_awvalid(axil_csr_awvalid),
    .m_axil_csr_awready(axil_csr_awready),
    .m_axil_csr_wdata(axil_csr_wdata),
    .m_axil_csr_wstrb(axil_csr_wstrb),
    .m_axil_csr_wvalid(axil_csr_wvalid),
    .m_axil_csr_wready(axil_csr_wready),
    .m_axil_csr_bresp(axil_csr_bresp),
    .m_axil_csr_bvalid(axil_csr_bvalid),
    .m_axil_csr_bready(axil_csr_bready),
    .m_axil_csr_araddr(axil_csr_araddr),
    .m_axil_csr_arprot(axil_csr_arprot),
    .m_axil_csr_arvalid(axil_csr_arvalid),
    .m_axil_csr_arready(axil_csr_arready),
    .m_axil_csr_rdata(axil_csr_rdata),
    .m_axil_csr_rresp(axil_csr_rresp),
    .m_axil_csr_rvalid(axil_csr_rvalid),
    .m_axil_csr_rready(axil_csr_rready),

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

    .eth_rx_ptp_clk(0),
    .eth_rx_ptp_rst(0),
    .eth_rx_clk(eth_rx_clk),
    .eth_rx_rst(eth_rx_rst),

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
