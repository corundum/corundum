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
 * FPGA core logic
 */
module fpga_core #
(
    parameter TARGET = "XILINX",
    parameter AXIS_PCIE_DATA_WIDTH = 512,
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    parameter AXIS_PCIE_RC_USER_WIDTH = 161,
    parameter AXIS_PCIE_RQ_USER_WIDTH = 137,
    parameter AXIS_PCIE_CQ_USER_WIDTH = 183,
    parameter AXIS_PCIE_CC_USER_WIDTH = 81
)
(
    /*
     * Clock: 156.25 MHz, 250 MHz
     * Synchronous reset
     */
    input  wire                               clk_156mhz,
    input  wire                               rst_156mhz,
    input  wire                               clk_250mhz,
    input  wire                               rst_250mhz,

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
    input  wire                               qsfp1_tx_clk_1,
    input  wire                               qsfp1_tx_rst_1,
    output wire [63:0]                        qsfp1_txd_1,
    output wire [7:0]                         qsfp1_txc_1,
    output wire                               qsfp1_tx_prbs31_enable_1,
    input  wire                               qsfp1_rx_clk_1,
    input  wire                               qsfp1_rx_rst_1,
    input  wire [63:0]                        qsfp1_rxd_1,
    input  wire [7:0]                         qsfp1_rxc_1,
    output wire                               qsfp1_rx_prbs31_enable_1,
    input  wire [6:0]                         qsfp1_rx_error_count_1,
    input  wire                               qsfp1_tx_clk_2,
    input  wire                               qsfp1_tx_rst_2,
    output wire [63:0]                        qsfp1_txd_2,
    output wire [7:0]                         qsfp1_txc_2,
    output wire                               qsfp1_tx_prbs31_enable_2,
    input  wire                               qsfp1_rx_clk_2,
    input  wire                               qsfp1_rx_rst_2,
    input  wire [63:0]                        qsfp1_rxd_2,
    input  wire [7:0]                         qsfp1_rxc_2,
    output wire                               qsfp1_rx_prbs31_enable_2,
    input  wire [6:0]                         qsfp1_rx_error_count_2,
    input  wire                               qsfp1_tx_clk_3,
    input  wire                               qsfp1_tx_rst_3,
    output wire [63:0]                        qsfp1_txd_3,
    output wire [7:0]                         qsfp1_txc_3,
    output wire                               qsfp1_tx_prbs31_enable_3,
    input  wire                               qsfp1_rx_clk_3,
    input  wire                               qsfp1_rx_rst_3,
    input  wire [63:0]                        qsfp1_rxd_3,
    input  wire [7:0]                         qsfp1_rxc_3,
    output wire                               qsfp1_rx_prbs31_enable_3,
    input  wire [6:0]                         qsfp1_rx_error_count_3,
    input  wire                               qsfp1_tx_clk_4,
    input  wire                               qsfp1_tx_rst_4,
    output wire [63:0]                        qsfp1_txd_4,
    output wire [7:0]                         qsfp1_txc_4,
    output wire                               qsfp1_tx_prbs31_enable_4,
    input  wire                               qsfp1_rx_clk_4,
    input  wire                               qsfp1_rx_rst_4,
    input  wire [63:0]                        qsfp1_rxd_4,
    input  wire [7:0]                         qsfp1_rxc_4,
    output wire                               qsfp1_rx_prbs31_enable_4,
    input  wire [6:0]                         qsfp1_rx_error_count_4,

    output wire                               qsfp1_modsell,
    output wire                               qsfp1_resetl,
    input  wire                               qsfp1_modprsl,
    input  wire                               qsfp1_intl,
    output wire                               qsfp1_lpmode,

    input  wire                               qsfp2_tx_clk_1,
    input  wire                               qsfp2_tx_rst_1,
    output wire [63:0]                        qsfp2_txd_1,
    output wire [7:0]                         qsfp2_txc_1,
    output wire                               qsfp2_tx_prbs31_enable_1,
    input  wire                               qsfp2_rx_clk_1,
    input  wire                               qsfp2_rx_rst_1,
    input  wire [63:0]                        qsfp2_rxd_1,
    input  wire [7:0]                         qsfp2_rxc_1,
    output wire                               qsfp2_rx_prbs31_enable_1,
    input  wire [6:0]                         qsfp2_rx_error_count_1,
    input  wire                               qsfp2_tx_clk_2,
    input  wire                               qsfp2_tx_rst_2,
    output wire [63:0]                        qsfp2_txd_2,
    output wire [7:0]                         qsfp2_txc_2,
    output wire                               qsfp2_tx_prbs31_enable_2,
    input  wire                               qsfp2_rx_clk_2,
    input  wire                               qsfp2_rx_rst_2,
    input  wire [63:0]                        qsfp2_rxd_2,
    input  wire [7:0]                         qsfp2_rxc_2,
    output wire                               qsfp2_rx_prbs31_enable_2,
    input  wire [6:0]                         qsfp2_rx_error_count_2,
    input  wire                               qsfp2_tx_clk_3,
    input  wire                               qsfp2_tx_rst_3,
    output wire [63:0]                        qsfp2_txd_3,
    output wire [7:0]                         qsfp2_txc_3,
    output wire                               qsfp2_tx_prbs31_enable_3,
    input  wire                               qsfp2_rx_clk_3,
    input  wire                               qsfp2_rx_rst_3,
    input  wire [63:0]                        qsfp2_rxd_3,
    input  wire [7:0]                         qsfp2_rxc_3,
    output wire                               qsfp2_rx_prbs31_enable_3,
    input  wire [6:0]                         qsfp2_rx_error_count_3,
    input  wire                               qsfp2_tx_clk_4,
    input  wire                               qsfp2_tx_rst_4,
    output wire [63:0]                        qsfp2_txd_4,
    output wire [7:0]                         qsfp2_txc_4,
    output wire                               qsfp2_tx_prbs31_enable_4,
    input  wire                               qsfp2_rx_clk_4,
    input  wire                               qsfp2_rx_rst_4,
    input  wire [63:0]                        qsfp2_rxd_4,
    input  wire [7:0]                         qsfp2_rxc_4,
    output wire                               qsfp2_rx_prbs31_enable_4,
    input  wire [6:0]                         qsfp2_rx_error_count_4,

    output wire                               qsfp2_modsell,
    output wire                               qsfp2_resetl,
    input  wire                               qsfp2_modprsl,
    input  wire                               qsfp2_intl,
    output wire                               qsfp2_lpmode
);

parameter PCIE_ADDR_WIDTH = 64;

// AXI lite interface parameters
parameter AXIL_DATA_WIDTH = 32;
parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8);
parameter AXIL_ADDR_WIDTH = 24;

// AXI stream interface parameters
parameter AXIS_DATA_WIDTH = 256;
parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8;

// PCIe DMA parameters
parameter PCIE_DMA_LEN_WIDTH = 16;
parameter PCIE_DMA_TAG_WIDTH = 16;

// PHC parameters
parameter PTP_PERIOD_NS_WIDTH = 4;
parameter PTP_OFFSET_NS_WIDTH = 32;
parameter PTP_FNS_WIDTH = 32;
parameter PTP_PERIOD_NS = 4'd4;
parameter PTP_PERIOD_FNS = 32'd0;

// FW and board IDs
parameter FW_ID = 32'd0;
parameter FW_VER = {16'd0, 16'd1};
parameter BOARD_ID = {16'h10ee, 16'h907a};
parameter BOARD_VER = {16'd0, 16'd1};

// Structural parameters
parameter IF_COUNT = 2;
parameter PORTS_PER_IF = 1;

parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF;

// Queue manager parameters (interface)
parameter EVENT_QUEUE_OP_TABLE_SIZE = 32;
parameter TX_QUEUE_OP_TABLE_SIZE = 32;
parameter RX_QUEUE_OP_TABLE_SIZE = 32;
parameter TX_CPL_QUEUE_OP_TABLE_SIZE = 32;
parameter RX_CPL_QUEUE_OP_TABLE_SIZE = 32;
parameter TX_QUEUE_INDEX_WIDTH = 8;
parameter RX_QUEUE_INDEX_WIDTH = 8;
parameter TX_CPL_QUEUE_INDEX_WIDTH = 8;
parameter RX_CPL_QUEUE_INDEX_WIDTH = 8;

// TX and RX engine parameters (port)
parameter TX_DESC_TABLE_SIZE = 32;
parameter TX_PKT_TABLE_SIZE = 8;
parameter RX_DESC_TABLE_SIZE = 32;
parameter RX_PKT_TABLE_SIZE = 8;

// Scheduler parameters (port)
parameter TX_SCHEDULER = "RR";
parameter TX_SCHEDULER_OP_TABLE_SIZE = 32;
parameter TDMA_INDEX_WIDTH = 6;

// Timstamping parameters (port)
parameter LOGIC_PTP_PERIOD_NS = 6'h4;
parameter LOGIC_PTP_PERIOD_FNS = 16'h0000;
parameter IF_PTP_PERIOD_NS = 6'h6;
parameter IF_PTP_PERIOD_FNS = 16'h6666;
parameter PTP_TS_ENABLE = 1;
parameter PTP_TS_WIDTH = 96;
parameter TX_PTP_TS_FIFO_DEPTH = 32;
parameter RX_PTP_TS_FIFO_DEPTH = 32;

// Interface parameters (port)
parameter TX_CHECKSUM_ENABLE = 1;
parameter RX_CHECKSUM_ENABLE = 1;
parameter ENABLE_PADDING = 1;
parameter ENABLE_DIC = 1;
parameter MIN_FRAME_LENGTH = 64;
parameter TX_FIFO_DEPTH = 32768;
parameter RX_FIFO_DEPTH = 32768;
parameter MAX_TX_SIZE = 2048;
parameter MAX_RX_SIZE = 2048;

// PCIe DMA parameters
parameter SEG_COUNT = AXIS_PCIE_DATA_WIDTH > 64 ? AXIS_PCIE_DATA_WIDTH*2 / 128 : 2;
parameter SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH*2/SEG_COUNT;
parameter SEG_ADDR_WIDTH = 12;
parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8;
parameter RAM_SEL_WIDTH = $clog2(IF_COUNT)+$clog2(PORTS_PER_IF+1);
parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH);
parameter RAM_PIPELINE = 2;

parameter TX_RAM_SIZE = TX_PKT_TABLE_SIZE*MAX_TX_SIZE;
parameter RX_RAM_SIZE = RX_PKT_TABLE_SIZE*MAX_RX_SIZE;

// AXI lite connections
wire [AXIL_ADDR_WIDTH-1:0] axil_pcie_awaddr;
wire [2:0]                 axil_pcie_awprot;
wire                       axil_pcie_awvalid;
wire                       axil_pcie_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_pcie_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_pcie_wstrb;
wire                       axil_pcie_wvalid;
wire                       axil_pcie_wready;
wire [1:0]                 axil_pcie_bresp;
wire                       axil_pcie_bvalid;
wire                       axil_pcie_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_pcie_araddr;
wire [2:0]                 axil_pcie_arprot;
wire                       axil_pcie_arvalid;
wire                       axil_pcie_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_pcie_rdata;
wire [1:0]                 axil_pcie_rresp;
wire                       axil_pcie_rvalid;
wire                       axil_pcie_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_csr_awaddr;
wire [2:0]                 axil_csr_awprot;
wire                       axil_csr_awvalid;
wire                       axil_csr_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_csr_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_csr_wstrb;
wire                       axil_csr_wvalid;
wire                       axil_csr_wready;
wire [1:0]                 axil_csr_bresp;
wire                       axil_csr_bvalid;
wire                       axil_csr_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_csr_araddr;
wire [2:0]                 axil_csr_arprot;
wire                       axil_csr_arvalid;
wire                       axil_csr_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_csr_rdata;
wire [1:0]                 axil_csr_rresp;
wire                       axil_csr_rvalid;
wire                       axil_csr_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_ber_awaddr;
wire [2:0]                 axil_ber_awprot;
wire                       axil_ber_awvalid;
wire                       axil_ber_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_ber_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_ber_wstrb;
wire                       axil_ber_wvalid;
wire                       axil_ber_wready;
wire [1:0]                 axil_ber_bresp;
wire                       axil_ber_bvalid;
wire                       axil_ber_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_ber_araddr;
wire [2:0]                 axil_ber_arprot;
wire                       axil_ber_arvalid;
wire                       axil_ber_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_ber_rdata;
wire [1:0]                 axil_ber_rresp;
wire                       axil_ber_rvalid;
wire                       axil_ber_rready;

// DMA connections
wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]   dma_ram_wr_cmd_sel;
wire [SEG_COUNT*SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be;
wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data;
wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_valid;
wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_ready;
wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]   dma_ram_rd_cmd_sel;
wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_valid;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_ready;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_valid;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_ready;

// Error handling
wire [1:0] status_error_uncor_int;
wire [1:0] status_error_cor_int;

wire [31:0] msi_irq;

wire ext_tag_enable;

// PCIe DMA control
wire [PCIE_ADDR_WIDTH-1:0]     pcie_dma_read_desc_pcie_addr;
wire [RAM_SEL_WIDTH-1:0]       pcie_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]      pcie_dma_read_desc_ram_addr;
wire [PCIE_DMA_LEN_WIDTH-1:0]  pcie_dma_read_desc_len;
wire [PCIE_DMA_TAG_WIDTH-1:0]  pcie_dma_read_desc_tag;
wire                           pcie_dma_read_desc_valid;
wire                           pcie_dma_read_desc_ready;

wire [PCIE_DMA_TAG_WIDTH-1:0]  pcie_dma_read_desc_status_tag;
wire                           pcie_dma_read_desc_status_valid;

wire [PCIE_ADDR_WIDTH-1:0]     pcie_dma_write_desc_pcie_addr;
wire [RAM_SEL_WIDTH-1:0]       pcie_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]      pcie_dma_write_desc_ram_addr;
wire [PCIE_DMA_LEN_WIDTH-1:0]  pcie_dma_write_desc_len;
wire [PCIE_DMA_TAG_WIDTH-1:0]  pcie_dma_write_desc_tag;
wire                           pcie_dma_write_desc_valid;
wire                           pcie_dma_write_desc_ready;

wire [PCIE_DMA_TAG_WIDTH-1:0]  pcie_dma_write_desc_status_tag;
wire                           pcie_dma_write_desc_status_valid;

wire                           pcie_dma_enable = 1;

wire [95:0] ptp_ts_96;
wire ptp_ts_step;
wire ptp_pps;

reg ptp_perout_enable_reg = 1'b0;
wire ptp_perout_locked;
wire ptp_perout_error;
wire ptp_perout_pulse;

// control registers
reg axil_csr_awready_reg = 1'b0;
reg axil_csr_wready_reg = 1'b0;
reg axil_csr_bvalid_reg = 1'b0;
reg axil_csr_arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] axil_csr_rdata_reg = {AXIL_DATA_WIDTH{1'b0}};
reg axil_csr_rvalid_reg = 1'b0;

reg qsfp1_modsell_reg = 1'b0;
reg qsfp2_modsell_reg = 1'b0;

reg qsfp1_lpmode_reg = 1'b0;
reg qsfp2_lpmode_reg = 1'b0;

reg qsfp1_resetl_reg = 1'b1;
reg qsfp2_resetl_reg = 1'b1;

reg i2c_scl_o_reg = 1'b1;
reg i2c_sda_o_reg = 1'b1;

reg pcie_dma_enable_reg = 0;

reg [95:0] get_ptp_ts_96_reg = 0;
reg [95:0] set_ptp_ts_96_reg = 0;
reg set_ptp_ts_96_valid_reg = 0;
reg [PTP_PERIOD_NS_WIDTH-1:0] set_ptp_period_ns_reg = 0;
reg [PTP_FNS_WIDTH-1:0] set_ptp_period_fns_reg = 0;
reg set_ptp_period_valid_reg = 0;
reg [PTP_OFFSET_NS_WIDTH-1:0] set_ptp_offset_ns_reg = 0;
reg [PTP_FNS_WIDTH-1:0] set_ptp_offset_fns_reg = 0;
reg [15:0] set_ptp_offset_count_reg = 0;
reg set_ptp_offset_valid_reg = 0;
wire set_ptp_offset_active;

reg [95:0] set_ptp_perout_start_ts_96_reg = 0;
reg set_ptp_perout_start_ts_96_valid_reg = 0;
reg [95:0] set_ptp_perout_period_ts_96_reg = 0;
reg set_ptp_perout_period_ts_96_valid_reg = 0;
reg [95:0] set_ptp_perout_width_ts_96_reg = 0;
reg set_ptp_perout_width_ts_96_valid_reg = 0;

assign axil_csr_awready = axil_csr_awready_reg;
assign axil_csr_wready = axil_csr_wready_reg;
assign axil_csr_bresp = 2'b00;
assign axil_csr_bvalid = axil_csr_bvalid_reg;
assign axil_csr_arready = axil_csr_arready_reg;
assign axil_csr_rdata = axil_csr_rdata_reg;
assign axil_csr_rresp = 2'b00;
assign axil_csr_rvalid = axil_csr_rvalid_reg;

assign qsfp1_modsell = qsfp1_modsell_reg;
assign qsfp2_modsell = qsfp2_modsell_reg;

assign qsfp1_resetl = qsfp1_resetl_reg;
assign qsfp2_resetl = qsfp2_resetl_reg;

assign i2c_scl_o = i2c_scl_o_reg;
assign i2c_scl_t = i2c_scl_o_reg;
assign i2c_sda_o = i2c_sda_o_reg;
assign i2c_sda_t = i2c_sda_o_reg;

//assign pcie_dma_enable = pcie_dma_enable_reg;

always @(posedge clk_250mhz) begin
    axil_csr_awready_reg <= 1'b0;
    axil_csr_wready_reg <= 1'b0;
    axil_csr_bvalid_reg <= axil_csr_bvalid_reg && !axil_csr_bready;
    axil_csr_arready_reg <= 1'b0;
    axil_csr_rvalid_reg <= axil_csr_rvalid_reg && !axil_csr_rready;

    pcie_dma_enable_reg <= pcie_dma_enable_reg;

    set_ptp_ts_96_valid_reg <= 1'b0;
    set_ptp_period_valid_reg <= 1'b0;
    set_ptp_offset_valid_reg <= 1'b0;

    set_ptp_perout_start_ts_96_valid_reg <= 1'b0;
    set_ptp_perout_period_ts_96_valid_reg <= 1'b0;
    set_ptp_perout_width_ts_96_valid_reg <= 1'b0;

    if (axil_csr_awvalid && axil_csr_wvalid && !axil_csr_bvalid) begin
        // write operation
        axil_csr_awready_reg <= 1'b1;
        axil_csr_wready_reg <= 1'b1;
        axil_csr_bvalid_reg <= 1'b1;

        case ({axil_csr_awaddr[15:2], 2'b00})
            // GPIO
            16'h0100: begin
                // GPIO out
                if (axil_csr_wstrb[1]) begin
                    qsfp1_modsell_reg <= axil_csr_wdata[9];
                    qsfp2_modsell_reg <= axil_csr_wdata[11];
                end
                if (axil_csr_wstrb[0]) begin
                    qsfp1_resetl_reg <= axil_csr_wdata[0];
                    qsfp1_lpmode_reg <= axil_csr_wdata[2];
                    qsfp2_resetl_reg <= axil_csr_wdata[4];
                    qsfp2_lpmode_reg <= axil_csr_wdata[6];
                end
                if (axil_csr_wstrb[2]) begin
                    i2c_scl_o_reg <= axil_csr_wdata[16];
                    i2c_sda_o_reg <= axil_csr_wdata[17];
                end
            end
            // PHC
            16'h0230: set_ptp_ts_96_reg[15:0] <= axil_csr_wdata;  // PTP set fns
            16'h0234: set_ptp_ts_96_reg[45:16] <= axil_csr_wdata; // PTP set ns
            16'h0238: set_ptp_ts_96_reg[79:48] <= axil_csr_wdata; // PTP set sec l
            16'h023C: begin
                // PTP set sec h
                set_ptp_ts_96_reg[95:80] <= axil_csr_wdata;
                set_ptp_ts_96_valid_reg <= 1'b1;
            end
            16'h0240: set_ptp_period_fns_reg <= axil_csr_wdata; // PTP period fns
            16'h0244: begin
                // PTP period ns
                set_ptp_period_ns_reg <= axil_csr_wdata;
                set_ptp_period_valid_reg <= 1'b1;
            end
            16'h0250: set_ptp_offset_fns_reg <= axil_csr_wdata; // PTP offset fns
            16'h0254: set_ptp_offset_ns_reg <= axil_csr_wdata;  // PTP offset ns
            16'h0258: begin
                // PTP offset count
                set_ptp_offset_count_reg <= axil_csr_wdata;
                set_ptp_offset_valid_reg <= 1'b1;
            end
            16'h0260: begin
                // PTP perout control
                ptp_perout_enable_reg <= axil_csr_wdata[0];
            end
            16'h0270: set_ptp_perout_start_ts_96_reg[15:0] <= axil_csr_wdata;  // PTP perout start fns
            16'h0274: set_ptp_perout_start_ts_96_reg[45:16] <= axil_csr_wdata; // PTP perout start ns
            16'h0278: set_ptp_perout_start_ts_96_reg[79:48] <= axil_csr_wdata; // PTP perout start sec l
            16'h027C: begin
                // PTP perout start sec h
                set_ptp_perout_start_ts_96_reg[95:80] <= axil_csr_wdata;
                set_ptp_perout_start_ts_96_valid_reg <= 1'b1;
            end
            16'h0280: set_ptp_perout_period_ts_96_reg[15:0] <= axil_csr_wdata;  // PTP perout period fns
            16'h0284: set_ptp_perout_period_ts_96_reg[45:16] <= axil_csr_wdata; // PTP perout period ns
            16'h0288: set_ptp_perout_period_ts_96_reg[79:48] <= axil_csr_wdata; // PTP perout period sec l
            16'h028C: begin
                // PTP perout period sec h
                set_ptp_perout_period_ts_96_reg[95:80] <= axil_csr_wdata;
                set_ptp_perout_period_ts_96_valid_reg <= 1'b1;
            end
            16'h0290: set_ptp_perout_width_ts_96_reg[15:0] <= axil_csr_wdata;  // PTP perout width fns
            16'h0294: set_ptp_perout_width_ts_96_reg[45:16] <= axil_csr_wdata; // PTP perout width ns
            16'h0298: set_ptp_perout_width_ts_96_reg[79:48] <= axil_csr_wdata; // PTP perout width sec l
            16'h029C: begin
                // PTP perout width sec h
                set_ptp_perout_width_ts_96_reg[95:80] <= axil_csr_wdata;
                set_ptp_perout_width_ts_96_valid_reg <= 1'b1;
            end
        endcase
    end

    if (axil_csr_arvalid && !axil_csr_rvalid) begin
        // read operation
        axil_csr_arready_reg <= 1'b1;
        axil_csr_rvalid_reg <= 1'b1;
        axil_csr_rdata_reg <= {AXIL_DATA_WIDTH{1'b0}};

        case ({axil_csr_araddr[15:2], 2'b00})
            16'h0000: axil_csr_rdata_reg <= FW_ID;      // fw_id
            16'h0004: axil_csr_rdata_reg <= FW_VER;     // fw_ver
            16'h0008: axil_csr_rdata_reg <= BOARD_ID;   // board_id
            16'h000C: axil_csr_rdata_reg <= BOARD_VER;  // board_ver
            16'h0010: axil_csr_rdata_reg <= 1;          // phc_count
            16'h0014: axil_csr_rdata_reg <= 16'h0200;   // phc_offset
            16'h0018: axil_csr_rdata_reg <= 16'h0080;   // phc_stride
            16'h0020: axil_csr_rdata_reg <= IF_COUNT;   // if_count
            16'h0024: axil_csr_rdata_reg <= 24'h800000; // if_stride
            16'h002C: axil_csr_rdata_reg <= 24'h040000; // if_csr_offset
            // GPIO
            16'h0100: begin
                // GPIO out
                axil_csr_rdata_reg[9] <= qsfp1_modsell_reg;
                axil_csr_rdata_reg[11] <= qsfp2_modsell_reg;
                axil_csr_rdata_reg[0] <= qsfp1_resetl_reg;
                axil_csr_rdata_reg[2] <= qsfp1_lpmode_reg;
                axil_csr_rdata_reg[4] <= qsfp2_resetl_reg;
                axil_csr_rdata_reg[6] <= qsfp2_lpmode_reg;
                axil_csr_rdata_reg[16] <= i2c_scl_o_reg;
                axil_csr_rdata_reg[17] <= i2c_sda_o_reg;
            end
            16'h0104: begin
                // GPIO in
                axil_csr_rdata_reg[8] <= qsfp1_modprsl;
                axil_csr_rdata_reg[9] <= qsfp1_modsell;
                axil_csr_rdata_reg[10] <= qsfp2_modprsl;
                axil_csr_rdata_reg[11] <= qsfp2_modsell;
                axil_csr_rdata_reg[0] <= qsfp1_resetl;
                axil_csr_rdata_reg[1] <= qsfp1_intl;
                axil_csr_rdata_reg[2] <= qsfp1_lpmode;
                axil_csr_rdata_reg[4] <= qsfp2_resetl;
                axil_csr_rdata_reg[5] <= qsfp2_intl;
                axil_csr_rdata_reg[6] <= qsfp2_lpmode;
                axil_csr_rdata_reg[16] <= i2c_scl_i;
                axil_csr_rdata_reg[17] <= i2c_sda_i;
            end
            // PHC
            16'h0200: axil_csr_rdata_reg <= {8'd0, 8'd0, 8'd0, 8'd1};  // PHC features
            16'h0210: axil_csr_rdata_reg <= ptp_ts_96[15:0];  // PTP cur fns
            16'h0214: axil_csr_rdata_reg <= ptp_ts_96[45:16]; // PTP cur ns
            16'h0218: axil_csr_rdata_reg <= ptp_ts_96[79:48]; // PTP cur sec l
            16'h021C: axil_csr_rdata_reg <= ptp_ts_96[95:80]; // PTP cur sec h
            16'h0220: begin
                // PTP get fns
                get_ptp_ts_96_reg <= ptp_ts_96;
                axil_csr_rdata_reg <= ptp_ts_96[15:0];
            end
            16'h0224: axil_csr_rdata_reg <= get_ptp_ts_96_reg[45:16]; // PTP get ns
            16'h0228: axil_csr_rdata_reg <= get_ptp_ts_96_reg[79:48]; // PTP get sec l
            16'h022C: axil_csr_rdata_reg <= get_ptp_ts_96_reg[95:80]; // PTP get sec h
            16'h0230: axil_csr_rdata_reg <= set_ptp_ts_96_reg[15:0];  // PTP set fns
            16'h0234: axil_csr_rdata_reg <= set_ptp_ts_96_reg[45:16]; // PTP set ns
            16'h0238: axil_csr_rdata_reg <= set_ptp_ts_96_reg[79:48]; // PTP set sec l
            16'h023C: axil_csr_rdata_reg <= set_ptp_ts_96_reg[95:80]; // PTP set sec h
            16'h0240: axil_csr_rdata_reg <= set_ptp_period_fns_reg;   // PTP period fns
            16'h0244: axil_csr_rdata_reg <= set_ptp_period_ns_reg;    // PTP period ns
            16'h0248: axil_csr_rdata_reg <= PTP_PERIOD_FNS;           // PTP nom period fns
            16'h024C: axil_csr_rdata_reg <= PTP_PERIOD_NS;            // PTP nom period ns
            16'h0250: axil_csr_rdata_reg <= set_ptp_offset_fns_reg;   // PTP offset fns
            16'h0254: axil_csr_rdata_reg <= set_ptp_offset_ns_reg;    // PTP offset ns
            16'h0258: axil_csr_rdata_reg <= set_ptp_offset_count_reg; // PTP offset count
            16'h025C: axil_csr_rdata_reg <= set_ptp_offset_active;    // PTP offset status
            16'h0260: begin
                // PTP perout control
                axil_csr_rdata_reg[0] <= ptp_perout_enable_reg;
            end
            16'h0264: begin
                // PTP perout status
                axil_csr_rdata_reg[0] <= ptp_perout_locked;
                axil_csr_rdata_reg[1] <= ptp_perout_error;
            end
            16'h0270: axil_csr_rdata_reg <= set_ptp_perout_start_ts_96_reg[15:0];  // PTP perout start fns
            16'h0274: axil_csr_rdata_reg <= set_ptp_perout_start_ts_96_reg[45:16]; // PTP perout start ns
            16'h0278: axil_csr_rdata_reg <= set_ptp_perout_start_ts_96_reg[79:48]; // PTP perout start sec l
            16'h027C: axil_csr_rdata_reg <= set_ptp_perout_start_ts_96_reg[95:80]; // PTP perout start sec h
            16'h0280: axil_csr_rdata_reg <= set_ptp_perout_period_ts_96_reg[15:0];  // PTP perout period fns
            16'h0284: axil_csr_rdata_reg <= set_ptp_perout_period_ts_96_reg[45:16]; // PTP perout period ns
            16'h0288: axil_csr_rdata_reg <= set_ptp_perout_period_ts_96_reg[79:48]; // PTP perout period sec l
            16'h028C: axil_csr_rdata_reg <= set_ptp_perout_period_ts_96_reg[95:80]; // PTP perout period sec h
            16'h0290: axil_csr_rdata_reg <= set_ptp_perout_width_ts_96_reg[15:0];  // PTP perout width fns
            16'h0294: axil_csr_rdata_reg <= set_ptp_perout_width_ts_96_reg[45:16]; // PTP perout width ns
            16'h0298: axil_csr_rdata_reg <= set_ptp_perout_width_ts_96_reg[79:48]; // PTP perout width sec l
            16'h029C: axil_csr_rdata_reg <= set_ptp_perout_width_ts_96_reg[95:80]; // PTP perout width sec h
        endcase
    end

    if (rst_250mhz) begin
        axil_csr_awready_reg <= 1'b0;
        axil_csr_wready_reg <= 1'b0;
        axil_csr_bvalid_reg <= 1'b0;
        axil_csr_arready_reg <= 1'b0;
        axil_csr_rvalid_reg <= 1'b0;

        qsfp1_modsell_reg <= 1'b1;
        qsfp2_modsell_reg <= 1'b1;

        qsfp1_lpmode_reg <= 1'b0;
        qsfp2_lpmode_reg <= 1'b0;

        qsfp1_resetl_reg <= 1'b1;
        qsfp2_resetl_reg <= 1'b1;

        i2c_scl_o_reg <= 1'b1;
        i2c_sda_o_reg <= 1'b1;

        pcie_dma_enable_reg <= 1'b0;

        ptp_perout_enable_reg <= 1'b0;
    end
end

pcie_us_cfg #(
    .PF_COUNT(1),
    .VF_COUNT(0),
    .VF_OFFSET(4),
    .PCIE_CAP_OFFSET(12'h070)
)
pcie_us_cfg_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    /*
     * Configuration outputs
     */
    .ext_tag_enable(ext_tag_enable),
    .max_read_request_size(),
    .max_payload_size(),

    /*
     * Interface to Ultrascale PCIe IP core
     */
    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done)
);

pcie_us_axil_master #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .AXI_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .ENABLE_PARITY(0)
)
pcie_us_axil_master_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

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
     * AXI input (CC)
     */
    .m_axis_cc_tdata(m_axis_cc_tdata),
    .m_axis_cc_tkeep(m_axis_cc_tkeep),
    .m_axis_cc_tvalid(m_axis_cc_tvalid),
    .m_axis_cc_tready(m_axis_cc_tready),
    .m_axis_cc_tlast(m_axis_cc_tlast),
    .m_axis_cc_tuser(m_axis_cc_tuser),

    /*
     * AXI Lite Master output
     */
    .m_axil_awaddr(axil_pcie_awaddr),
    .m_axil_awprot(axil_pcie_awprot),
    .m_axil_awvalid(axil_pcie_awvalid),
    .m_axil_awready(axil_pcie_awready),
    .m_axil_wdata(axil_pcie_wdata),
    .m_axil_wstrb(axil_pcie_wstrb),
    .m_axil_wvalid(axil_pcie_wvalid),
    .m_axil_wready(axil_pcie_wready),
    .m_axil_bresp(axil_pcie_bresp),
    .m_axil_bvalid(axil_pcie_bvalid),
    .m_axil_bready(axil_pcie_bready),
    .m_axil_araddr(axil_pcie_araddr),
    .m_axil_arprot(axil_pcie_arprot),
    .m_axil_arvalid(axil_pcie_arvalid),
    .m_axil_arready(axil_pcie_arready),
    .m_axil_rdata(axil_pcie_rdata),
    .m_axil_rresp(axil_pcie_rresp),
    .m_axil_rvalid(axil_pcie_rvalid),
    .m_axil_rready(axil_pcie_rready),

    /*
     * Configuration
     */
    .completer_id({8'd0, 5'd0, 3'd0}),
    .completer_id_enable(1'b0),

    /*
     * Status
     */
    .status_error_cor(status_error_cor_int[0]),
    .status_error_uncor(status_error_uncor_int[0])
);

wire [AXIS_PCIE_DATA_WIDTH-1:0]    axis_rc_tdata_r;
wire [AXIS_PCIE_KEEP_WIDTH-1:0]    axis_rc_tkeep_r;
wire                               axis_rc_tlast_r;
wire                               axis_rc_tready_r;
wire [AXIS_PCIE_RC_USER_WIDTH-1:0] axis_rc_tuser_r;
wire                               axis_rc_tvalid_r;

axis_register #(
    .DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH)
)
rc_reg (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    /*
     * AXI input
     */
    .s_axis_tdata(s_axis_rc_tdata),
    .s_axis_tkeep(s_axis_rc_tkeep),
    .s_axis_tvalid(s_axis_rc_tvalid),
    .s_axis_tready(s_axis_rc_tready),
    .s_axis_tlast(s_axis_rc_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(s_axis_rc_tuser),

    /*
     * AXI output
     */
    .m_axis_tdata(axis_rc_tdata_r),
    .m_axis_tkeep(axis_rc_tkeep_r),
    .m_axis_tvalid(axis_rc_tvalid_r),
    .m_axis_tready(axis_rc_tready_r),
    .m_axis_tlast(axis_rc_tlast_r),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(axis_rc_tuser_r)
);

dma_if_pcie_us #
(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_TAG_COUNT(64),
    .PCIE_EXT_TAG_ENABLE(1),
    .LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .TAG_WIDTH(PCIE_DMA_TAG_WIDTH)
)
dma_if_pcie_us_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    /*
     * AXI input (RC)
     */
    .s_axis_rc_tdata(axis_rc_tdata_r),
    .s_axis_rc_tkeep(axis_rc_tkeep_r),
    .s_axis_rc_tvalid(axis_rc_tvalid_r),
    .s_axis_rc_tready(axis_rc_tready_r),
    .s_axis_rc_tlast(axis_rc_tlast_r),
    .s_axis_rc_tuser(axis_rc_tuser_r),

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
     * AXI read descriptor input
     */
    .s_axis_read_desc_pcie_addr(pcie_dma_read_desc_pcie_addr),
    .s_axis_read_desc_ram_sel(pcie_dma_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(pcie_dma_read_desc_ram_addr),
    .s_axis_read_desc_len(pcie_dma_read_desc_len),
    .s_axis_read_desc_tag(pcie_dma_read_desc_tag),
    .s_axis_read_desc_valid(pcie_dma_read_desc_valid),
    .s_axis_read_desc_ready(pcie_dma_read_desc_ready),

    /*
     * AXI read descriptor status output
     */
    .m_axis_read_desc_status_tag(pcie_dma_read_desc_status_tag),
    .m_axis_read_desc_status_valid(pcie_dma_read_desc_status_valid),

    /*
     * AXI write descriptor input
     */
    .s_axis_write_desc_pcie_addr(pcie_dma_write_desc_pcie_addr),
    .s_axis_write_desc_ram_sel(pcie_dma_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(pcie_dma_write_desc_ram_addr),
    .s_axis_write_desc_len(pcie_dma_write_desc_len),
    .s_axis_write_desc_tag(pcie_dma_write_desc_tag),
    .s_axis_write_desc_valid(pcie_dma_write_desc_valid),
    .s_axis_write_desc_ready(pcie_dma_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_tag(pcie_dma_write_desc_status_tag),
    .m_axis_write_desc_status_valid(pcie_dma_write_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .ram_rd_resp_data(dma_ram_rd_resp_data),
    .ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * Configuration
     */
    .read_enable(pcie_dma_enable),
    .write_enable(pcie_dma_enable),
    .ext_tag_enable(ext_tag_enable),
    .requester_id({8'd0, 5'd0, 3'd0}),
    .requester_id_enable(1'b0),
    .max_read_request_size(cfg_max_read_req),
    .max_payload_size(cfg_max_payload),

    /*
     * Status
     */
    .status_error_cor(status_error_cor_int[1]),
    .status_error_uncor(status_error_uncor_int[1])
);

pulse_merge #(
    .INPUT_WIDTH(2),
    .COUNT_WIDTH(4)
)
status_error_cor_pm_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    .pulse_in(status_error_cor_int),
    .count_out(),
    .pulse_out(status_error_cor)
);

pulse_merge #(
    .INPUT_WIDTH(2),
    .COUNT_WIDTH(4)
)
status_error_uncor_pm_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    .pulse_in(status_error_uncor_int),
    .count_out(),
    .pulse_out(status_error_uncor)
);

pcie_us_msi #(
    .MSI_COUNT(32)
)
pcie_us_msi_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    .msi_irq(msi_irq),

    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_vf_enable(0),
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
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number)
);

parameter IF_AXIL_ADDR_WIDTH = 32'd23;
parameter IF_AXIL_BASE_ADDR_WIDTH = IF_COUNT*AXIL_ADDR_WIDTH;
parameter IF_AXIL_BASE_ADDR = calcIFAxiLiteBaseAddrs(IF_AXIL_ADDR_WIDTH);

function [IF_AXIL_BASE_ADDR_WIDTH-1:0] calcIFAxiLiteBaseAddrs(input [31:0] if_addr_width);
    integer i;
    begin
        calcIFAxiLiteBaseAddrs = {IF_AXIL_BASE_ADDR_WIDTH{1'b0}};
        for (i = 0; i < IF_COUNT; i = i + 1) begin
            calcIFAxiLiteBaseAddrs[i * AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH] = i * (2**if_addr_width);
        end
    end
endfunction

wire [IF_COUNT*AXIL_ADDR_WIDTH-1:0] axil_if_awaddr;
wire [IF_COUNT*3-1:0]               axil_if_awprot;
wire [IF_COUNT-1:0]                 axil_if_awvalid;
wire [IF_COUNT-1:0]                 axil_if_awready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0] axil_if_wdata;
wire [IF_COUNT*AXIL_STRB_WIDTH-1:0] axil_if_wstrb;
wire [IF_COUNT-1:0]                 axil_if_wvalid;
wire [IF_COUNT-1:0]                 axil_if_wready;
wire [IF_COUNT*2-1:0]               axil_if_bresp;
wire [IF_COUNT-1:0]                 axil_if_bvalid;
wire [IF_COUNT-1:0]                 axil_if_bready;
wire [IF_COUNT*AXIL_ADDR_WIDTH-1:0] axil_if_araddr;
wire [IF_COUNT*3-1:0]               axil_if_arprot;
wire [IF_COUNT-1:0]                 axil_if_arvalid;
wire [IF_COUNT-1:0]                 axil_if_arready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0] axil_if_rdata;
wire [IF_COUNT*2-1:0]               axil_if_rresp;
wire [IF_COUNT-1:0]                 axil_if_rvalid;
wire [IF_COUNT-1:0]                 axil_if_rready;

wire [IF_COUNT*AXIL_ADDR_WIDTH-1:0] axil_if_csr_awaddr;
wire [IF_COUNT*3-1:0]               axil_if_csr_awprot;
wire [IF_COUNT-1:0]                 axil_if_csr_awvalid;
wire [IF_COUNT-1:0]                 axil_if_csr_awready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0] axil_if_csr_wdata;
wire [IF_COUNT*AXIL_STRB_WIDTH-1:0] axil_if_csr_wstrb;
wire [IF_COUNT-1:0]                 axil_if_csr_wvalid;
wire [IF_COUNT-1:0]                 axil_if_csr_wready;
wire [IF_COUNT*2-1:0]               axil_if_csr_bresp;
wire [IF_COUNT-1:0]                 axil_if_csr_bvalid;
wire [IF_COUNT-1:0]                 axil_if_csr_bready;
wire [IF_COUNT*AXIL_ADDR_WIDTH-1:0] axil_if_csr_araddr;
wire [IF_COUNT*3-1:0]               axil_if_csr_arprot;
wire [IF_COUNT-1:0]                 axil_if_csr_arvalid;
wire [IF_COUNT-1:0]                 axil_if_csr_arready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0] axil_if_csr_rdata;
wire [IF_COUNT*2-1:0]               axil_if_csr_rresp;
wire [IF_COUNT-1:0]                 axil_if_csr_rvalid;
wire [IF_COUNT-1:0]                 axil_if_csr_rready;

axil_interconnect #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .S_COUNT(1),
    .M_COUNT(IF_COUNT),
    .M_BASE_ADDR(IF_AXIL_BASE_ADDR),
    .M_ADDR_WIDTH({IF_COUNT{IF_AXIL_ADDR_WIDTH}}),
    .M_CONNECT_READ({IF_COUNT{1'b1}}),
    .M_CONNECT_WRITE({IF_COUNT{1'b1}})
)
axil_interconnect_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),
    .s_axil_awaddr(axil_pcie_awaddr),
    .s_axil_awprot(axil_pcie_awprot),
    .s_axil_awvalid(axil_pcie_awvalid),
    .s_axil_awready(axil_pcie_awready),
    .s_axil_wdata(axil_pcie_wdata),
    .s_axil_wstrb(axil_pcie_wstrb),
    .s_axil_wvalid(axil_pcie_wvalid),
    .s_axil_wready(axil_pcie_wready),
    .s_axil_bresp(axil_pcie_bresp),
    .s_axil_bvalid(axil_pcie_bvalid),
    .s_axil_bready(axil_pcie_bready),
    .s_axil_araddr(axil_pcie_araddr),
    .s_axil_arprot(axil_pcie_arprot),
    .s_axil_arvalid(axil_pcie_arvalid),
    .s_axil_arready(axil_pcie_arready),
    .s_axil_rdata(axil_pcie_rdata),
    .s_axil_rresp(axil_pcie_rresp),
    .s_axil_rvalid(axil_pcie_rvalid),
    .s_axil_rready(axil_pcie_rready),
    .m_axil_awaddr(axil_if_awaddr),
    .m_axil_awprot(axil_if_awprot),
    .m_axil_awvalid(axil_if_awvalid),
    .m_axil_awready(axil_if_awready),
    .m_axil_wdata(axil_if_wdata),
    .m_axil_wstrb(axil_if_wstrb),
    .m_axil_wvalid(axil_if_wvalid),
    .m_axil_wready(axil_if_wready),
    .m_axil_bresp(axil_if_bresp),
    .m_axil_bvalid(axil_if_bvalid),
    .m_axil_bready(axil_if_bready),
    .m_axil_araddr(axil_if_araddr),
    .m_axil_arprot(axil_if_arprot),
    .m_axil_arvalid(axil_if_arvalid),
    .m_axil_arready(axil_if_arready),
    .m_axil_rdata(axil_if_rdata),
    .m_axil_rresp(axil_if_rresp),
    .m_axil_rvalid(axil_if_rvalid),
    .m_axil_rready(axil_if_rready)
);

function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

axil_interconnect #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .S_COUNT(IF_COUNT),
    .M_COUNT(2),
    .M_BASE_ADDR({24'h020000, 24'h000000}),
    .M_ADDR_WIDTH({w_32(8+6+$clog2(8)), w_32(17)}),
    .M_CONNECT_READ({2{{IF_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({2{{IF_COUNT{1'b1}}}})
)
axil_csr_interconnect_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),
    .s_axil_awaddr(axil_if_csr_awaddr & {IF_COUNT{23'h03ffff}}),
    .s_axil_awprot(axil_if_csr_awprot),
    .s_axil_awvalid(axil_if_csr_awvalid),
    .s_axil_awready(axil_if_csr_awready),
    .s_axil_wdata(axil_if_csr_wdata),
    .s_axil_wstrb(axil_if_csr_wstrb),
    .s_axil_wvalid(axil_if_csr_wvalid),
    .s_axil_wready(axil_if_csr_wready),
    .s_axil_bresp(axil_if_csr_bresp),
    .s_axil_bvalid(axil_if_csr_bvalid),
    .s_axil_bready(axil_if_csr_bready),
    .s_axil_araddr(axil_if_csr_araddr & {IF_COUNT{23'h03ffff}}),
    .s_axil_arprot(axil_if_csr_arprot),
    .s_axil_arvalid(axil_if_csr_arvalid),
    .s_axil_arready(axil_if_csr_arready),
    .s_axil_rdata(axil_if_csr_rdata),
    .s_axil_rresp(axil_if_csr_rresp),
    .s_axil_rvalid(axil_if_csr_rvalid),
    .s_axil_rready(axil_if_csr_rready),
    .m_axil_awaddr(  {axil_ber_awaddr,  axil_csr_awaddr}),
    .m_axil_awprot(  {axil_ber_awprot,  axil_csr_awprot}),
    .m_axil_awvalid( {axil_ber_awvalid, axil_csr_awvalid}),
    .m_axil_awready( {axil_ber_awready, axil_csr_awready}),
    .m_axil_wdata(   {axil_ber_wdata,   axil_csr_wdata}),
    .m_axil_wstrb(   {axil_ber_wstrb,   axil_csr_wstrb}),
    .m_axil_wvalid(  {axil_ber_wvalid,  axil_csr_wvalid}),
    .m_axil_wready(  {axil_ber_wready,  axil_csr_wready}),
    .m_axil_bresp(   {axil_ber_bresp,   axil_csr_bresp}),
    .m_axil_bvalid(  {axil_ber_bvalid,  axil_csr_bvalid}),
    .m_axil_bready(  {axil_ber_bready,  axil_csr_bready}),
    .m_axil_araddr(  {axil_ber_araddr,  axil_csr_araddr}),
    .m_axil_arprot(  {axil_ber_arprot,  axil_csr_arprot}),
    .m_axil_arvalid( {axil_ber_arvalid, axil_csr_arvalid}),
    .m_axil_arready( {axil_ber_arready, axil_csr_arready}),
    .m_axil_rdata(   {axil_ber_rdata,   axil_csr_rdata}),
    .m_axil_rresp(   {axil_ber_rresp,   axil_csr_rresp}),
    .m_axil_rvalid(  {axil_ber_rvalid,  axil_csr_rvalid}),
    .m_axil_rready(  {axil_ber_rready,  axil_csr_rready})
);

parameter IF_RAM_SEL_WIDTH = $clog2(PORTS_PER_IF+1);
parameter IF_PCIE_DMA_TAG_WIDTH = PCIE_DMA_TAG_WIDTH-$clog2(IF_COUNT);

wire [IF_COUNT*PCIE_ADDR_WIDTH-1:0]        if_pcie_dma_read_desc_pcie_addr;
wire [IF_COUNT*RAM_SEL_WIDTH-1:0]          if_pcie_dma_read_desc_ram_sel;
wire [IF_COUNT*RAM_ADDR_WIDTH-1:0]         if_pcie_dma_read_desc_ram_addr;
wire [IF_COUNT*PCIE_DMA_LEN_WIDTH-1:0]     if_pcie_dma_read_desc_len;
wire [IF_COUNT*IF_PCIE_DMA_TAG_WIDTH-1:0]  if_pcie_dma_read_desc_tag;
wire [IF_COUNT-1:0]                        if_pcie_dma_read_desc_valid;
wire [IF_COUNT-1:0]                        if_pcie_dma_read_desc_ready;

wire [IF_COUNT*IF_PCIE_DMA_TAG_WIDTH-1:0]  if_pcie_dma_read_desc_status_tag;
wire [IF_COUNT-1:0]                        if_pcie_dma_read_desc_status_valid;

wire [IF_COUNT*PCIE_ADDR_WIDTH-1:0]        if_pcie_dma_write_desc_pcie_addr;
wire [IF_COUNT*RAM_SEL_WIDTH-1:0]          if_pcie_dma_write_desc_ram_sel;
wire [IF_COUNT*RAM_ADDR_WIDTH-1:0]         if_pcie_dma_write_desc_ram_addr;
wire [IF_COUNT*PCIE_DMA_LEN_WIDTH-1:0]     if_pcie_dma_write_desc_len;
wire [IF_COUNT*IF_PCIE_DMA_TAG_WIDTH-1:0]  if_pcie_dma_write_desc_tag;
wire [IF_COUNT-1:0]                        if_pcie_dma_write_desc_valid;
wire [IF_COUNT-1:0]                        if_pcie_dma_write_desc_ready;

wire [IF_COUNT*IF_PCIE_DMA_TAG_WIDTH-1:0]  if_pcie_dma_write_desc_status_tag;
wire [IF_COUNT-1:0]                        if_pcie_dma_write_desc_status_valid;

wire [IF_COUNT*SEG_COUNT*IF_RAM_SEL_WIDTH-1:0] if_dma_ram_wr_cmd_sel;
wire [IF_COUNT*SEG_COUNT*SEG_BE_WIDTH-1:0]     if_dma_ram_wr_cmd_be;
wire [IF_COUNT*SEG_COUNT*SEG_ADDR_WIDTH-1:0]   if_dma_ram_wr_cmd_addr;
wire [IF_COUNT*SEG_COUNT*SEG_DATA_WIDTH-1:0]   if_dma_ram_wr_cmd_data;
wire [IF_COUNT*SEG_COUNT-1:0]                  if_dma_ram_wr_cmd_valid;
wire [IF_COUNT*SEG_COUNT-1:0]                  if_dma_ram_wr_cmd_ready;
wire [IF_COUNT*SEG_COUNT*IF_RAM_SEL_WIDTH-1:0] if_dma_ram_rd_cmd_sel;
wire [IF_COUNT*SEG_COUNT*SEG_ADDR_WIDTH-1:0]   if_dma_ram_rd_cmd_addr;
wire [IF_COUNT*SEG_COUNT-1:0]                  if_dma_ram_rd_cmd_valid;
wire [IF_COUNT*SEG_COUNT-1:0]                  if_dma_ram_rd_cmd_ready;
wire [IF_COUNT*SEG_COUNT*SEG_DATA_WIDTH-1:0]   if_dma_ram_rd_resp_data;
wire [IF_COUNT*SEG_COUNT-1:0]                  if_dma_ram_rd_resp_valid;
wire [IF_COUNT*SEG_COUNT-1:0]                  if_dma_ram_rd_resp_ready;

dma_if_mux #
(
    .PORTS(IF_COUNT),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .S_RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
    .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .S_TAG_WIDTH(IF_PCIE_DMA_TAG_WIDTH),
    .M_TAG_WIDTH(PCIE_DMA_TAG_WIDTH),
    .ARB_TYPE("ROUND_ROBIN"),
    .LSB_PRIORITY("HIGH")
)
dma_if_mux_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    /*
     * Read descriptor output (to DMA interface)
     */
    .m_axis_read_desc_dma_addr(pcie_dma_read_desc_pcie_addr),
    .m_axis_read_desc_ram_sel(pcie_dma_read_desc_ram_sel),
    .m_axis_read_desc_ram_addr(pcie_dma_read_desc_ram_addr),
    .m_axis_read_desc_len(pcie_dma_read_desc_len),
    .m_axis_read_desc_tag(pcie_dma_read_desc_tag),
    .m_axis_read_desc_valid(pcie_dma_read_desc_valid),
    .m_axis_read_desc_ready(pcie_dma_read_desc_ready),

    /*
     * Read descriptor status input (from DMA interface)
     */
    .s_axis_read_desc_status_tag(pcie_dma_read_desc_status_tag),
    .s_axis_read_desc_status_valid(pcie_dma_read_desc_status_valid),

    /*
     * Read descriptor input
     */
    .s_axis_read_desc_dma_addr(if_pcie_dma_read_desc_pcie_addr),
    .s_axis_read_desc_ram_sel(if_pcie_dma_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(if_pcie_dma_read_desc_ram_addr),
    .s_axis_read_desc_len(if_pcie_dma_read_desc_len),
    .s_axis_read_desc_tag(if_pcie_dma_read_desc_tag),
    .s_axis_read_desc_valid(if_pcie_dma_read_desc_valid),
    .s_axis_read_desc_ready(if_pcie_dma_read_desc_ready),

    /*
     * Read descriptor status output
     */
    .m_axis_read_desc_status_tag(if_pcie_dma_read_desc_status_tag),
    .m_axis_read_desc_status_valid(if_pcie_dma_read_desc_status_valid),

    /*
     * Write descriptor output (to DMA interface)
     */
    .m_axis_write_desc_dma_addr(pcie_dma_write_desc_pcie_addr),
    .m_axis_write_desc_ram_sel(pcie_dma_write_desc_ram_sel),
    .m_axis_write_desc_ram_addr(pcie_dma_write_desc_ram_addr),
    .m_axis_write_desc_len(pcie_dma_write_desc_len),
    .m_axis_write_desc_tag(pcie_dma_write_desc_tag),
    .m_axis_write_desc_valid(pcie_dma_write_desc_valid),
    .m_axis_write_desc_ready(pcie_dma_write_desc_ready),

    /*
     * Write descriptor status input (from DMA interface)
     */
    .s_axis_write_desc_status_tag(pcie_dma_write_desc_status_tag),
    .s_axis_write_desc_status_valid(pcie_dma_write_desc_status_valid),

    /*
     * Write descriptor input
     */
    .s_axis_write_desc_dma_addr(if_pcie_dma_write_desc_pcie_addr),
    .s_axis_write_desc_ram_sel(if_pcie_dma_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(if_pcie_dma_write_desc_ram_addr),
    .s_axis_write_desc_len(if_pcie_dma_write_desc_len),
    .s_axis_write_desc_tag(if_pcie_dma_write_desc_tag),
    .s_axis_write_desc_valid(if_pcie_dma_write_desc_valid),
    .s_axis_write_desc_ready(if_pcie_dma_write_desc_ready),

    /*
     * Write descriptor status output
     */
    .m_axis_write_desc_status_tag(if_pcie_dma_write_desc_status_tag),
    .m_axis_write_desc_status_valid(if_pcie_dma_write_desc_status_valid),

    /*
     * RAM interface (from DMA interface)
     */
    .if_ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .if_ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .if_ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .if_ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .if_ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .if_ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .if_ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .if_ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .if_ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .if_ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .if_ram_rd_resp_data(dma_ram_rd_resp_data),
    .if_ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .if_ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel(if_dma_ram_wr_cmd_sel),
    .ram_wr_cmd_be(if_dma_ram_wr_cmd_be),
    .ram_wr_cmd_addr(if_dma_ram_wr_cmd_addr),
    .ram_wr_cmd_data(if_dma_ram_wr_cmd_data),
    .ram_wr_cmd_valid(if_dma_ram_wr_cmd_valid),
    .ram_wr_cmd_ready(if_dma_ram_wr_cmd_ready),
    .ram_rd_cmd_sel(if_dma_ram_rd_cmd_sel),
    .ram_rd_cmd_addr(if_dma_ram_rd_cmd_addr),
    .ram_rd_cmd_valid(if_dma_ram_rd_cmd_valid),
    .ram_rd_cmd_ready(if_dma_ram_rd_cmd_ready),
    .ram_rd_resp_data(if_dma_ram_rd_resp_data),
    .ram_rd_resp_valid(if_dma_ram_rd_resp_valid),
    .ram_rd_resp_ready(if_dma_ram_rd_resp_ready)
);

// PTP clock
ptp_clock #(
    .PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .FNS_WIDTH(PTP_FNS_WIDTH),
    .PERIOD_NS(PTP_PERIOD_NS),
    .PERIOD_FNS(PTP_PERIOD_FNS),
    .DRIFT_ENABLE(0)
)
ptp_clock_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),

    /*
     * Timestamp inputs for synchronization
     */
    .input_ts_96(set_ptp_ts_96_reg),
    .input_ts_96_valid(set_ptp_ts_96_valid_reg),
    .input_ts_64(0),
    .input_ts_64_valid(1'b0),

    /*
     * Period adjustment
     */
    .input_period_ns(set_ptp_period_ns_reg),
    .input_period_fns(set_ptp_period_fns_reg),
    .input_period_valid(set_ptp_period_valid_reg),

    /*
     * Offset adjustment
     */
    .input_adj_ns(set_ptp_offset_ns_reg),
    .input_adj_fns(set_ptp_offset_fns_reg),
    .input_adj_count(set_ptp_offset_count_reg),
    .input_adj_valid(set_ptp_offset_valid_reg),
    .input_adj_active(set_ptp_offset_active),

    /*
     * Drift adjustment
     */
    .input_drift_ns(0),
    .input_drift_fns(0),
    .input_drift_rate(0),
    .input_drift_valid(0),

    /*
     * Timestamp outputs
     */
    .output_ts_96(ptp_ts_96),
    .output_ts_64(),
    .output_ts_step(ptp_ts_step),

    /*
     * PPS output
     */
    .output_pps(ptp_pps)
);

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

ptp_perout #(
    .FNS_ENABLE(0),
    .OUT_START_S(0),
    .OUT_START_NS(0),
    .OUT_START_FNS(0),
    .OUT_PERIOD_S(1),
    .OUT_PERIOD_NS(0),
    .OUT_PERIOD_FNS(0),
    .OUT_WIDTH_S(0),
    .OUT_WIDTH_NS(500000000),
    .OUT_WIDTH_FNS(0)
)
ptp_perout_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),
    .input_ts_96(ptp_ts_96),
    .input_ts_step(ptp_ts_step),
    .enable(ptp_perout_enable_reg),
    .input_start(set_ptp_perout_start_ts_96_reg),
    .input_start_valid(set_ptp_perout_start_ts_96_valid_reg),
    .input_period(set_ptp_perout_period_ts_96_reg),
    .input_period_valid(set_ptp_perout_period_ts_96_valid_reg),
    .input_width(set_ptp_perout_width_ts_96_reg),
    .input_width_valid(set_ptp_perout_width_ts_96_valid_reg),
    .locked(ptp_perout_locked),
    .error(ptp_perout_error),
    .output_pulse(ptp_perout_pulse)
);


// BER tester
tdma_ber #(
    .COUNT(8),
    .INDEX_WIDTH(6),
    .SLICE_WIDTH(5),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(8+6+$clog2(8)),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .SCHEDULE_START_S(0),
    .SCHEDULE_START_NS(0),
    .SCHEDULE_PERIOD_S(0),
    .SCHEDULE_PERIOD_NS(1000000),
    .TIMESLOT_PERIOD_S(0),
    .TIMESLOT_PERIOD_NS(100000),
    .ACTIVE_PERIOD_S(0),
    .ACTIVE_PERIOD_NS(90000)
)
tdma_ber_inst (
    .clk(clk_250mhz),
    .rst(rst_250mhz),
    .phy_tx_clk({qsfp2_tx_clk_4, qsfp2_tx_clk_3, qsfp2_tx_clk_2, qsfp2_tx_clk_1, qsfp1_tx_clk_4, qsfp1_tx_clk_3, qsfp1_tx_clk_2, qsfp1_tx_clk_1}),
    .phy_rx_clk({qsfp2_rx_clk_4, qsfp2_rx_clk_3, qsfp2_rx_clk_2, qsfp2_rx_clk_1, qsfp1_rx_clk_4, qsfp1_rx_clk_3, qsfp1_rx_clk_2, qsfp1_rx_clk_1}),
    .phy_rx_error_count({qsfp2_rx_error_count_4, qsfp2_rx_error_count_3, qsfp2_rx_error_count_2, qsfp2_rx_error_count_1, qsfp1_rx_error_count_4, qsfp1_rx_error_count_3, qsfp1_rx_error_count_2, qsfp1_rx_error_count_1}),
    .phy_tx_prbs31_enable({qsfp2_tx_prbs31_enable_4, qsfp2_tx_prbs31_enable_3, qsfp2_tx_prbs31_enable_2, qsfp2_tx_prbs31_enable_1, qsfp1_tx_prbs31_enable_4, qsfp1_tx_prbs31_enable_3, qsfp1_tx_prbs31_enable_2, qsfp1_tx_prbs31_enable_1}),
    .phy_rx_prbs31_enable({qsfp2_rx_prbs31_enable_4, qsfp2_rx_prbs31_enable_3, qsfp2_rx_prbs31_enable_2, qsfp2_rx_prbs31_enable_1, qsfp1_rx_prbs31_enable_4, qsfp1_rx_prbs31_enable_3, qsfp1_rx_prbs31_enable_2, qsfp1_rx_prbs31_enable_1}),
    .s_axil_awaddr(axil_ber_awaddr),
    .s_axil_awprot(axil_ber_awprot),
    .s_axil_awvalid(axil_ber_awvalid),
    .s_axil_awready(axil_ber_awready),
    .s_axil_wdata(axil_ber_wdata),
    .s_axil_wstrb(axil_ber_wstrb),
    .s_axil_wvalid(axil_ber_wvalid),
    .s_axil_wready(axil_ber_wready),
    .s_axil_bresp(axil_ber_bresp),
    .s_axil_bvalid(axil_ber_bvalid),
    .s_axil_bready(axil_ber_bready),
    .s_axil_araddr(axil_ber_araddr),
    .s_axil_arprot(axil_ber_arprot),
    .s_axil_arvalid(axil_ber_arvalid),
    .s_axil_arready(axil_ber_arready),
    .s_axil_rdata(axil_ber_rdata),
    .s_axil_rresp(axil_ber_rresp),
    .s_axil_rvalid(axil_ber_rvalid),
    .s_axil_rready(axil_ber_rready),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step)
);

wire [PORT_COUNT-1:0] port_xgmii_tx_clk;
wire [PORT_COUNT-1:0] port_xgmii_tx_rst;
wire [PORT_COUNT-1:0] port_xgmii_rx_clk;
wire [PORT_COUNT-1:0] port_xgmii_rx_rst;
wire [PORT_COUNT*64-1:0] port_xgmii_txd;
wire [PORT_COUNT*8-1:0] port_xgmii_txc;
wire [PORT_COUNT*64-1:0] port_xgmii_rxd;
wire [PORT_COUNT*8-1:0] port_xgmii_rxc;


wire [IF_COUNT*32-1:0] if_msi_irq;

//  counts    QSFP 1                                QSFP 2
// IF  PORT   1_1      1_2      1_3      1_4        2_1      2_2      2_3      2_4
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

localparam QSFP1_1_IND = 0;
localparam QSFP1_2_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 1 ? 1 : -1) : 1;
localparam QSFP1_3_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 2 ? 2 : -1) : 2;
localparam QSFP1_4_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 3 ? 3 : -1) : 3;
localparam QSFP2_1_IND = IF_COUNT == 2 ? PORTS_PER_IF : 4;
localparam QSFP2_2_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 1 ? PORTS_PER_IF+1 : -1) : 5;
localparam QSFP2_3_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 2 ? PORTS_PER_IF+2 : -1) : 6;
localparam QSFP2_4_IND = IF_COUNT == 2 ? (PORTS_PER_IF > 3 ? PORTS_PER_IF+3 : -1) : 7;

generate
    genvar m, n;

    if (QSFP1_1_IND >= 0 && QSFP1_1_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_1_IND] = qsfp1_tx_clk_1;
        assign port_xgmii_tx_rst[QSFP1_1_IND] = qsfp1_tx_rst_1;
        assign port_xgmii_rx_clk[QSFP1_1_IND] = qsfp1_rx_clk_1;
        assign port_xgmii_rx_rst[QSFP1_1_IND] = qsfp1_rx_rst_1;
        assign port_xgmii_rxd[QSFP1_1_IND*64 +: 64] = qsfp1_rxd_1;
        assign port_xgmii_rxc[QSFP1_1_IND*8 +: 8] = qsfp1_rxc_1;

        assign qsfp1_txd_1 = port_xgmii_txd[QSFP1_1_IND*64 +: 64];
        assign qsfp1_txc_1 = port_xgmii_txc[QSFP1_1_IND*8 +: 8];
    end else begin
        assign qsfp1_txd_1 = 64'h0707070707070707;
        assign qsfp1_txc_1 = 8'hff;
    end

    if (QSFP1_2_IND >= 0 && QSFP1_2_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_2_IND] = qsfp1_tx_clk_2;
        assign port_xgmii_tx_rst[QSFP1_2_IND] = qsfp1_tx_rst_2;
        assign port_xgmii_rx_clk[QSFP1_2_IND] = qsfp1_rx_clk_2;
        assign port_xgmii_rx_rst[QSFP1_2_IND] = qsfp1_rx_rst_2;
        assign port_xgmii_rxd[QSFP1_2_IND*64 +: 64] = qsfp1_rxd_2;
        assign port_xgmii_rxc[QSFP1_2_IND*8 +: 8] = qsfp1_rxc_2;

        assign qsfp1_txd_2 = port_xgmii_txd[QSFP1_2_IND*64 +: 64];
        assign qsfp1_txc_2 = port_xgmii_txc[QSFP1_2_IND*8 +: 8];
    end else begin
        assign qsfp1_txd_2 = 64'h0707070707070707;
        assign qsfp1_txc_2 = 8'hff;
    end

    if (QSFP1_3_IND >= 0 && QSFP1_3_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_3_IND] = qsfp1_tx_clk_3;
        assign port_xgmii_tx_rst[QSFP1_3_IND] = qsfp1_tx_rst_3;
        assign port_xgmii_rx_clk[QSFP1_3_IND] = qsfp1_rx_clk_3;
        assign port_xgmii_rx_rst[QSFP1_3_IND] = qsfp1_rx_rst_3;
        assign port_xgmii_rxd[QSFP1_3_IND*64 +: 64] = qsfp1_rxd_3;
        assign port_xgmii_rxc[QSFP1_3_IND*8 +: 8] = qsfp1_rxc_3;

        assign qsfp1_txd_3 = port_xgmii_txd[QSFP1_3_IND*64 +: 64];
        assign qsfp1_txc_3 = port_xgmii_txc[QSFP1_3_IND*8 +: 8];
    end else begin
        assign qsfp1_txd_3 = 64'h0707070707070707;
        assign qsfp1_txc_3 = 8'hff;
    end

    if (QSFP1_4_IND >= 0 && QSFP1_4_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP1_4_IND] = qsfp1_tx_clk_4;
        assign port_xgmii_tx_rst[QSFP1_4_IND] = qsfp1_tx_rst_4;
        assign port_xgmii_rx_clk[QSFP1_4_IND] = qsfp1_rx_clk_4;
        assign port_xgmii_rx_rst[QSFP1_4_IND] = qsfp1_rx_rst_4;
        assign port_xgmii_rxd[QSFP1_4_IND*64 +: 64] = qsfp1_rxd_4;
        assign port_xgmii_rxc[QSFP1_4_IND*8 +: 8] = qsfp1_rxc_4;

        assign qsfp1_txd_4 = port_xgmii_txd[QSFP1_4_IND*64 +: 64];
        assign qsfp1_txc_4 = port_xgmii_txc[QSFP1_4_IND*8 +: 8];
    end else begin
        assign qsfp1_txd_4 = 64'h0707070707070707;
        assign qsfp1_txc_4 = 8'hff;
    end

    if (QSFP2_1_IND >= 0 && QSFP2_1_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP2_1_IND] = qsfp2_tx_clk_1;
        assign port_xgmii_tx_rst[QSFP2_1_IND] = qsfp2_tx_rst_1;
        assign port_xgmii_rx_clk[QSFP2_1_IND] = qsfp2_rx_clk_1;
        assign port_xgmii_rx_rst[QSFP2_1_IND] = qsfp2_rx_rst_1;
        assign port_xgmii_rxd[QSFP2_1_IND*64 +: 64] = qsfp2_rxd_1;
        assign port_xgmii_rxc[QSFP2_1_IND*8 +: 8] = qsfp2_rxc_1;

        assign qsfp2_txd_1 = port_xgmii_txd[QSFP2_1_IND*64 +: 64];
        assign qsfp2_txc_1 = port_xgmii_txc[QSFP2_1_IND*8 +: 8];
    end else begin
        assign qsfp2_txd_1 = 64'h0707070707070707;
        assign qsfp2_txc_1 = 8'hff;
    end

    if (QSFP2_2_IND >= 0 && QSFP2_2_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP2_2_IND] = qsfp2_tx_clk_2;
        assign port_xgmii_tx_rst[QSFP2_2_IND] = qsfp2_tx_rst_2;
        assign port_xgmii_rx_clk[QSFP2_2_IND] = qsfp2_rx_clk_2;
        assign port_xgmii_rx_rst[QSFP2_2_IND] = qsfp2_rx_rst_2;
        assign port_xgmii_rxd[QSFP2_2_IND*64 +: 64] = qsfp2_rxd_2;
        assign port_xgmii_rxc[QSFP2_2_IND*8 +: 8] = qsfp2_rxc_2;

        assign qsfp2_txd_2 = port_xgmii_txd[QSFP2_2_IND*64 +: 64];
        assign qsfp2_txc_2 = port_xgmii_txc[QSFP2_2_IND*8 +: 8];
    end else begin
        assign qsfp2_txd_2 = 64'h0707070707070707;
        assign qsfp2_txc_2 = 8'hff;
    end

    if (QSFP2_3_IND >= 0 && QSFP2_3_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP2_3_IND] = qsfp2_tx_clk_3;
        assign port_xgmii_tx_rst[QSFP2_3_IND] = qsfp2_tx_rst_3;
        assign port_xgmii_rx_clk[QSFP2_3_IND] = qsfp2_rx_clk_3;
        assign port_xgmii_rx_rst[QSFP2_3_IND] = qsfp2_rx_rst_3;
        assign port_xgmii_rxd[QSFP2_3_IND*64 +: 64] = qsfp2_rxd_3;
        assign port_xgmii_rxc[QSFP2_3_IND*8 +: 8] = qsfp2_rxc_3;

        assign qsfp2_txd_3 = port_xgmii_txd[QSFP2_3_IND*64 +: 64];
        assign qsfp2_txc_3 = port_xgmii_txc[QSFP2_3_IND*8 +: 8];
    end else begin
        assign qsfp2_txd_3 = 64'h0707070707070707;
        assign qsfp2_txc_3 = 8'hff;
    end

    if (QSFP2_4_IND >= 0 && QSFP2_4_IND < PORT_COUNT) begin
        assign port_xgmii_tx_clk[QSFP2_4_IND] = qsfp2_tx_clk_4;
        assign port_xgmii_tx_rst[QSFP2_4_IND] = qsfp2_tx_rst_4;
        assign port_xgmii_rx_clk[QSFP2_4_IND] = qsfp2_rx_clk_4;
        assign port_xgmii_rx_rst[QSFP2_4_IND] = qsfp2_rx_rst_4;
        assign port_xgmii_rxd[QSFP2_4_IND*64 +: 64] = qsfp2_rxd_4;
        assign port_xgmii_rxc[QSFP2_4_IND*8 +: 8] = qsfp2_rxc_4;

        assign qsfp2_txd_4 = port_xgmii_txd[QSFP2_4_IND*64 +: 64];
        assign qsfp2_txc_4 = port_xgmii_txc[QSFP2_4_IND*8 +: 8];
    end else begin
        assign qsfp2_txd_4 = 64'h0707070707070707;
        assign qsfp2_txc_4 = 8'hff;
    end

    case (IF_COUNT)
        1: assign msi_irq = if_msi_irq[0*32+:32];
        2: assign msi_irq = if_msi_irq[0*32+:32] | if_msi_irq[1*32+:32];
        3: assign msi_irq = if_msi_irq[0*32+:32] | if_msi_irq[1*32+:32] | if_msi_irq[2*32+:32];
        4: assign msi_irq = if_msi_irq[0*32+:32] | if_msi_irq[1*32+:32] | if_msi_irq[2*32+:32] | if_msi_irq[3*32+:32];
        5: assign msi_irq = if_msi_irq[0*32+:32] | if_msi_irq[1*32+:32] | if_msi_irq[2*32+:32] | if_msi_irq[3*32+:32] | if_msi_irq[4*32+:32];
        6: assign msi_irq = if_msi_irq[0*32+:32] | if_msi_irq[1*32+:32] | if_msi_irq[2*32+:32] | if_msi_irq[3*32+:32] | if_msi_irq[4*32+:32] | if_msi_irq[5*32+:32];
        7: assign msi_irq = if_msi_irq[0*32+:32] | if_msi_irq[1*32+:32] | if_msi_irq[2*32+:32] | if_msi_irq[3*32+:32] | if_msi_irq[4*32+:32] | if_msi_irq[5*32+:32] | if_msi_irq[6*32+:32];
        8: assign msi_irq = if_msi_irq[0*32+:32] | if_msi_irq[1*32+:32] | if_msi_irq[2*32+:32] | if_msi_irq[3*32+:32] | if_msi_irq[4*32+:32] | if_msi_irq[5*32+:32] | if_msi_irq[6*32+:32] | if_msi_irq[7*32+:32];
    endcase

    for (n = 0; n < IF_COUNT; n = n + 1) begin : iface

        wire [PORTS_PER_IF*AXIS_DATA_WIDTH-1:0] tx_axis_tdata;
        wire [PORTS_PER_IF*AXIS_KEEP_WIDTH-1:0] tx_axis_tkeep;
        wire [PORTS_PER_IF-1:0] tx_axis_tvalid;
        wire [PORTS_PER_IF-1:0] tx_axis_tready;
        wire [PORTS_PER_IF-1:0] tx_axis_tlast;
        wire [PORTS_PER_IF-1:0] tx_axis_tuser;

        wire [PORTS_PER_IF*PTP_TS_WIDTH-1:0] tx_ptp_ts_96;
        wire [PORTS_PER_IF-1:0] tx_ptp_ts_valid;
        wire [PORTS_PER_IF-1:0] tx_ptp_ts_ready;

        wire [PORTS_PER_IF*AXIS_DATA_WIDTH-1:0] rx_axis_tdata;
        wire [PORTS_PER_IF*AXIS_KEEP_WIDTH-1:0] rx_axis_tkeep;
        wire [PORTS_PER_IF-1:0] rx_axis_tvalid;
        wire [PORTS_PER_IF-1:0] rx_axis_tready;
        wire [PORTS_PER_IF-1:0] rx_axis_tlast;
        wire [PORTS_PER_IF-1:0] rx_axis_tuser;

        wire [PORTS_PER_IF*PTP_TS_WIDTH-1:0] rx_ptp_ts_96;
        wire [PORTS_PER_IF-1:0] rx_ptp_ts_valid;
        wire [PORTS_PER_IF-1:0] rx_ptp_ts_ready;

        interface #(
            .PORTS(PORTS_PER_IF),
            .DMA_ADDR_WIDTH(PCIE_ADDR_WIDTH),
            .DMA_LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
            .DMA_TAG_WIDTH(IF_PCIE_DMA_TAG_WIDTH),
            .EVENT_QUEUE_OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
            .TX_QUEUE_OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
            .RX_QUEUE_OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
            .TX_CPL_QUEUE_OP_TABLE_SIZE(TX_CPL_QUEUE_OP_TABLE_SIZE),
            .RX_CPL_QUEUE_OP_TABLE_SIZE(RX_CPL_QUEUE_OP_TABLE_SIZE),
            .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
            .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
            .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
            .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
            .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
            .TX_PKT_TABLE_SIZE(TX_PKT_TABLE_SIZE),
            .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
            .RX_PKT_TABLE_SIZE(RX_PKT_TABLE_SIZE),
            .TX_SCHEDULER(TX_SCHEDULER),
            .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
            .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),
            .INT_WIDTH(8),
            .QUEUE_PTR_WIDTH(16),
            .QUEUE_LOG_SIZE_WIDTH(4),
            .PTP_TS_ENABLE(PTP_TS_ENABLE),
            .PTP_TS_WIDTH(PTP_TS_WIDTH),
            .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
            .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
            .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
            .AXIL_ADDR_WIDTH(IF_AXIL_ADDR_WIDTH),
            .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
            .SEG_COUNT(SEG_COUNT),
            .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
            .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
            .SEG_BE_WIDTH(SEG_BE_WIDTH),
            .RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
            .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
            .RAM_PIPELINE(RAM_PIPELINE),
            .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
            .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
            .MAX_TX_SIZE(MAX_TX_SIZE),
            .MAX_RX_SIZE(MAX_RX_SIZE),
            .TX_RAM_SIZE(TX_RAM_SIZE),
            .RX_RAM_SIZE(RX_RAM_SIZE)
        )
        interface_inst (
            .clk(clk_250mhz),
            .rst(rst_250mhz),

            /*
             * DMA read descriptor output
             */
            .m_axis_dma_read_desc_dma_addr(if_pcie_dma_read_desc_pcie_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            .m_axis_dma_read_desc_ram_sel(if_pcie_dma_read_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_dma_read_desc_ram_addr(if_pcie_dma_read_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_dma_read_desc_len(if_pcie_dma_read_desc_len[n*PCIE_DMA_LEN_WIDTH +: PCIE_DMA_LEN_WIDTH]),
            .m_axis_dma_read_desc_tag(if_pcie_dma_read_desc_tag[n*IF_PCIE_DMA_TAG_WIDTH +: IF_PCIE_DMA_TAG_WIDTH]),
            .m_axis_dma_read_desc_valid(if_pcie_dma_read_desc_valid[n]),
            .m_axis_dma_read_desc_ready(if_pcie_dma_read_desc_ready[n]),

            /*
             * DMA read descriptor status input
             */
            .s_axis_dma_read_desc_status_tag(if_pcie_dma_read_desc_status_tag[n*IF_PCIE_DMA_TAG_WIDTH +: IF_PCIE_DMA_TAG_WIDTH]),
            .s_axis_dma_read_desc_status_valid(if_pcie_dma_read_desc_status_valid[n]),

            /*
             * DMA write descriptor output
             */
            .m_axis_dma_write_desc_dma_addr(if_pcie_dma_write_desc_pcie_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            .m_axis_dma_write_desc_ram_sel(if_pcie_dma_write_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_dma_write_desc_ram_addr(if_pcie_dma_write_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_dma_write_desc_len(if_pcie_dma_write_desc_len[n*PCIE_DMA_LEN_WIDTH +: PCIE_DMA_LEN_WIDTH]),
            .m_axis_dma_write_desc_tag(if_pcie_dma_write_desc_tag[n*IF_PCIE_DMA_TAG_WIDTH +: IF_PCIE_DMA_TAG_WIDTH]),
            .m_axis_dma_write_desc_valid(if_pcie_dma_write_desc_valid[n]),
            .m_axis_dma_write_desc_ready(if_pcie_dma_write_desc_ready[n]),

            /*
             * DMA write descriptor status input
             */
            .s_axis_dma_write_desc_status_tag(if_pcie_dma_write_desc_status_tag[n*IF_PCIE_DMA_TAG_WIDTH +: IF_PCIE_DMA_TAG_WIDTH]),
            .s_axis_dma_write_desc_status_valid(if_pcie_dma_write_desc_status_valid[n]),

            /*
             * AXI-Lite slave interface
             */
            .s_axil_awaddr(axil_if_awaddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_awprot(axil_if_awprot[n*3 +: 3]),
            .s_axil_awvalid(axil_if_awvalid[n]),
            .s_axil_awready(axil_if_awready[n]),
            .s_axil_wdata(axil_if_wdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_wstrb(axil_if_wstrb[n*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
            .s_axil_wvalid(axil_if_wvalid[n]),
            .s_axil_wready(axil_if_wready[n]),
            .s_axil_bresp(axil_if_bresp[n*2 +: 2]),
            .s_axil_bvalid(axil_if_bvalid[n]),
            .s_axil_bready(axil_if_bready[n]),
            .s_axil_araddr(axil_if_araddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_arprot(axil_if_arprot[n*3 +: 3]),
            .s_axil_arvalid(axil_if_arvalid[n]),
            .s_axil_arready(axil_if_arready[n]),
            .s_axil_rdata(axil_if_rdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_rresp(axil_if_rresp[n*2 +: 2]),
            .s_axil_rvalid(axil_if_rvalid[n]),
            .s_axil_rready(axil_if_rready[n]),

            /*
             * AXI-Lite master interface (passthrough for NIC control and status)
             */
            .m_axil_csr_awaddr(axil_if_csr_awaddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .m_axil_csr_awprot(axil_if_csr_awprot[n*3 +: 3]),
            .m_axil_csr_awvalid(axil_if_csr_awvalid[n]),
            .m_axil_csr_awready(axil_if_csr_awready[n]),
            .m_axil_csr_wdata(axil_if_csr_wdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .m_axil_csr_wstrb(axil_if_csr_wstrb[n*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
            .m_axil_csr_wvalid(axil_if_csr_wvalid[n]),
            .m_axil_csr_wready(axil_if_csr_wready[n]),
            .m_axil_csr_bresp(axil_if_csr_bresp[n*2 +: 2]),
            .m_axil_csr_bvalid(axil_if_csr_bvalid[n]),
            .m_axil_csr_bready(axil_if_csr_bready[n]),
            .m_axil_csr_araddr(axil_if_csr_araddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .m_axil_csr_arprot(axil_if_csr_arprot[n*3 +: 3]),
            .m_axil_csr_arvalid(axil_if_csr_arvalid[n]),
            .m_axil_csr_arready(axil_if_csr_arready[n]),
            .m_axil_csr_rdata(axil_if_csr_rdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .m_axil_csr_rresp(axil_if_csr_rresp[n*2 +: 2]),
            .m_axil_csr_rvalid(axil_if_csr_rvalid[n]),
            .m_axil_csr_rready(axil_if_csr_rready[n]),

            /*
             * RAM interface
             */
            .dma_ram_wr_cmd_sel(if_dma_ram_wr_cmd_sel[SEG_COUNT*IF_RAM_SEL_WIDTH*n +: SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .dma_ram_wr_cmd_be(if_dma_ram_wr_cmd_be[SEG_COUNT*SEG_BE_WIDTH*n +: SEG_COUNT*SEG_BE_WIDTH]),
            .dma_ram_wr_cmd_addr(if_dma_ram_wr_cmd_addr[SEG_COUNT*SEG_ADDR_WIDTH*n +: SEG_COUNT*SEG_ADDR_WIDTH]),
            .dma_ram_wr_cmd_data(if_dma_ram_wr_cmd_data[SEG_COUNT*SEG_DATA_WIDTH*n +: SEG_COUNT*SEG_DATA_WIDTH]),
            .dma_ram_wr_cmd_valid(if_dma_ram_wr_cmd_valid[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_wr_cmd_ready(if_dma_ram_wr_cmd_ready[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_cmd_sel(if_dma_ram_rd_cmd_sel[SEG_COUNT*IF_RAM_SEL_WIDTH*n +: SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .dma_ram_rd_cmd_addr(if_dma_ram_rd_cmd_addr[SEG_COUNT*SEG_ADDR_WIDTH*n +: SEG_COUNT*SEG_ADDR_WIDTH]),
            .dma_ram_rd_cmd_valid(if_dma_ram_rd_cmd_valid[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_cmd_ready(if_dma_ram_rd_cmd_ready[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_resp_data(if_dma_ram_rd_resp_data[SEG_COUNT*SEG_DATA_WIDTH*n +: SEG_COUNT*SEG_DATA_WIDTH]),
            .dma_ram_rd_resp_valid(if_dma_ram_rd_resp_valid[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_resp_ready(if_dma_ram_rd_resp_ready[SEG_COUNT*n +: SEG_COUNT]),

            /*
             * Transmit data output
             */
            .tx_axis_tdata(tx_axis_tdata),
            .tx_axis_tkeep(tx_axis_tkeep),
            .tx_axis_tvalid(tx_axis_tvalid),
            .tx_axis_tready(tx_axis_tready),
            .tx_axis_tlast(tx_axis_tlast),
            .tx_axis_tuser(tx_axis_tuser),

            /*
             * Transmit timestamp input
             */
            .s_axis_tx_ptp_ts_96(tx_ptp_ts_96),
            .s_axis_tx_ptp_ts_valid(tx_ptp_ts_valid),
            .s_axis_tx_ptp_ts_ready(tx_ptp_ts_ready),

            /*
             * Receive data input
             */
            .rx_axis_tdata(rx_axis_tdata),
            .rx_axis_tkeep(rx_axis_tkeep),
            .rx_axis_tvalid(rx_axis_tvalid),
            .rx_axis_tready(rx_axis_tready),
            .rx_axis_tlast(rx_axis_tlast),
            .rx_axis_tuser(rx_axis_tuser),

            /*
             * Receive timestamp input
             */
            .s_axis_rx_ptp_ts_96(rx_ptp_ts_96),
            .s_axis_rx_ptp_ts_valid(rx_ptp_ts_valid),
            .s_axis_rx_ptp_ts_ready(rx_ptp_ts_ready),

            /*
             * PTP clock
             */
            .ptp_ts_96(ptp_ts_96),
            .ptp_ts_step(ptp_ts_step),

            /*
             * MSI interrupts
             */
            .msi_irq(if_msi_irq[n*32 +: 32])
        );

        for (m = 0; m < PORTS_PER_IF; m = m + 1) begin : mac

            eth_mac_10g_fifo #(
                .DATA_WIDTH(64),
                .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
                .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
                .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
                .ENABLE_PADDING(ENABLE_PADDING),
                .ENABLE_DIC(ENABLE_DIC),
                .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH),
                .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
                .TX_FRAME_FIFO(1),
                .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
                .RX_FRAME_FIFO(1),
                .LOGIC_PTP_PERIOD_NS(LOGIC_PTP_PERIOD_NS),
                .LOGIC_PTP_PERIOD_FNS(LOGIC_PTP_PERIOD_FNS),
                .PTP_PERIOD_NS(IF_PTP_PERIOD_NS),
                .PTP_PERIOD_FNS(IF_PTP_PERIOD_FNS),
                .PTP_USE_SAMPLE_CLOCK(0),
                .TX_PTP_TS_ENABLE(PTP_TS_ENABLE),
                .RX_PTP_TS_ENABLE(PTP_TS_ENABLE),
                .TX_PTP_TS_FIFO_DEPTH(TX_PTP_TS_FIFO_DEPTH),
                .RX_PTP_TS_FIFO_DEPTH(RX_PTP_TS_FIFO_DEPTH),
                .PTP_TS_WIDTH(PTP_TS_WIDTH),
                .TX_PTP_TAG_ENABLE(0),
                .PTP_TAG_WIDTH(16)
            )
            eth_mac_inst (
                .rx_clk(port_xgmii_rx_clk[n*PORTS_PER_IF+m]),
                .rx_rst(port_xgmii_rx_rst[n*PORTS_PER_IF+m]),
                .tx_clk(port_xgmii_tx_clk[n*PORTS_PER_IF+m]),
                .tx_rst(port_xgmii_tx_rst[n*PORTS_PER_IF+m]),
                .logic_clk(clk_250mhz),
                .logic_rst(rst_250mhz),
                .ptp_sample_clk(clk_250mhz),

                .tx_axis_tdata(tx_axis_tdata[m*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
                .tx_axis_tkeep(tx_axis_tkeep[m*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
                .tx_axis_tvalid(tx_axis_tvalid[m +: 1]),
                .tx_axis_tready(tx_axis_tready[m +: 1]),
                .tx_axis_tlast(tx_axis_tlast[m +: 1]),
                .tx_axis_tuser(tx_axis_tuser[m +: 1]),

                .s_axis_tx_ptp_ts_tag(0),
                .s_axis_tx_ptp_ts_valid(0),
                .s_axis_tx_ptp_ts_ready(),

                .m_axis_tx_ptp_ts_96(tx_ptp_ts_96[m*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
                .m_axis_tx_ptp_ts_tag(),
                .m_axis_tx_ptp_ts_valid(tx_ptp_ts_valid[m +: 1]),
                .m_axis_tx_ptp_ts_ready(tx_ptp_ts_ready[m +: 1]),

                .rx_axis_tdata(rx_axis_tdata[m*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
                .rx_axis_tkeep(rx_axis_tkeep[m*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
                .rx_axis_tvalid(rx_axis_tvalid[m +: 1]),
                .rx_axis_tready(rx_axis_tready[m +: 1]),
                .rx_axis_tlast(rx_axis_tlast[m +: 1]),
                .rx_axis_tuser(rx_axis_tuser[m +: 1]),

                .m_axis_rx_ptp_ts_96(rx_ptp_ts_96[m*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
                .m_axis_rx_ptp_ts_valid(rx_ptp_ts_valid[m +: 1]),
                .m_axis_rx_ptp_ts_ready(rx_ptp_ts_ready[m +: 1]),

                .xgmii_rxd(port_xgmii_rxd[(n*PORTS_PER_IF+m)*64 +: 64]),
                .xgmii_rxc(port_xgmii_rxc[(n*PORTS_PER_IF+m)*8 +: 8]),
                .xgmii_txd(port_xgmii_txd[(n*PORTS_PER_IF+m)*64 +: 64]),
                .xgmii_txc(port_xgmii_txc[(n*PORTS_PER_IF+m)*8 +: 8]),

                .tx_error_underflow(),
                .tx_fifo_overflow(),
                .tx_fifo_bad_frame(),
                .tx_fifo_good_frame(),
                .rx_error_bad_frame(),
                .rx_error_bad_fcs(),
                .rx_fifo_overflow(),
                .rx_fifo_bad_frame(),
                .rx_fifo_good_frame(),

                .ptp_ts_96(ptp_ts_96),

                .ifg_delay(8'd12)
            );

        end

    end

endgenerate

endmodule
