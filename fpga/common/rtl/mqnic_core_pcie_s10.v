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
 * mqnic core logic - Intel Stratix 10 H-Tile/L-Tile wrapper
 */
module mqnic_core_pcie_s10 #
(
    // FW and board IDs
    parameter FW_ID = 32'd0,
    parameter FW_VER = {16'd0, 16'd1},
    parameter BOARD_ID = {16'h1234, 16'h0000},
    parameter BOARD_VER = {16'd0, 16'd1},

    // Structural configuration
    parameter IF_COUNT = 1,
    parameter PORTS_PER_IF = 1,

    parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF,

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
    parameter TX_SEQ_NUM_ENABLE = 1,
    parameter L_TILE = 0,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter F_COUNT = PF_COUNT+VF_COUNT,
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
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),
    parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT),
    parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8),
    parameter AXIL_CSR_PASSTHROUGH_ENABLE = 0,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,

    // Ethernet interface configuration
    parameter AXIS_ETH_DATA_WIDTH = 512,
    parameter AXIS_ETH_KEEP_WIDTH = AXIS_ETH_DATA_WIDTH/8,
    parameter AXIS_ETH_SYNC_DATA_WIDTH = AXIS_ETH_DATA_WIDTH,
    parameter AXIS_ETH_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1,
    parameter AXIS_ETH_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_ETH_RX_USE_READY = 0,
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
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * H-Tile/L-Tile RX AVST interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]           rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]          rx_st_empty,
    input  wire [SEG_COUNT-1:0]                          rx_st_sop,
    input  wire [SEG_COUNT-1:0]                          rx_st_eop,
    input  wire [SEG_COUNT-1:0]                          rx_st_valid,
    output wire                                          rx_st_ready,
    input  wire [SEG_COUNT-1:0]                          rx_st_vf_active,
    input  wire [SEG_COUNT*2-1:0]                        rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]                       rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                        rx_st_bar_range,

    /*
     * H-Tile/L-Tile TX AVST interface
     */
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]           tx_st_data,
    output wire [SEG_COUNT-1:0]                          tx_st_sop,
    output wire [SEG_COUNT-1:0]                          tx_st_eop,
    output wire [SEG_COUNT-1:0]                          tx_st_valid,
    input  wire                                          tx_st_ready,
    output wire [SEG_COUNT-1:0]                          tx_st_err,

    /*
     * H-Tile/L-Tile TX flow control
     */
    input  wire [7:0]                                    tx_ph_cdts,
    input  wire [11:0]                                   tx_pd_cdts,
    input  wire [7:0]                                    tx_nph_cdts,
    input  wire [11:0]                                   tx_npd_cdts,
    input  wire [7:0]                                    tx_cplh_cdts,
    input  wire [11:0]                                   tx_cpld_cdts,
    input  wire [SEG_COUNT-1:0]                          tx_hdr_cdts_consumed,
    input  wire [SEG_COUNT-1:0]                          tx_data_cdts_consumed,
    input  wire [SEG_COUNT*2-1:0]                        tx_cdts_type,
    input  wire [SEG_COUNT*1-1:0]                        tx_cdts_data_value,

    /*
     * H-Tile/L-Tile MSI interrupt interface
     */
    output wire                                          app_msi_req,
    input  wire                                          app_msi_ack,
    output wire [2:0]                                    app_msi_tc,
    output wire [4:0]                                    app_msi_num,
    output wire [1:0]                                    app_msi_func_num,

    /*
     * H-Tile/L-Tile configuration interface
     */
    input  wire [31:0]                                   tl_cfg_ctl,
    input  wire [4:0]                                    tl_cfg_add,
    input  wire [1:0]                                    tl_cfg_func,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                m_axil_csr_awaddr,
    output wire [2:0]                                    m_axil_csr_awprot,
    output wire                                          m_axil_csr_awvalid,
    input  wire                                          m_axil_csr_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]               m_axil_csr_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]               m_axil_csr_wstrb,
    output wire                                          m_axil_csr_wvalid,
    input  wire                                          m_axil_csr_wready,
    input  wire [1:0]                                    m_axil_csr_bresp,
    input  wire                                          m_axil_csr_bvalid,
    output wire                                          m_axil_csr_bready,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                m_axil_csr_araddr,
    output wire [2:0]                                    m_axil_csr_arprot,
    output wire                                          m_axil_csr_arvalid,
    input  wire                                          m_axil_csr_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]               m_axil_csr_rdata,
    input  wire [1:0]                                    m_axil_csr_rresp,
    input  wire                                          m_axil_csr_rvalid,
    output wire                                          m_axil_csr_rready,

    /*
     * Control register interface
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                ctrl_reg_wr_addr,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]               ctrl_reg_wr_data,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]               ctrl_reg_wr_strb,
    output wire                                          ctrl_reg_wr_en,
    input  wire                                          ctrl_reg_wr_wait,
    input  wire                                          ctrl_reg_wr_ack,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                ctrl_reg_rd_addr,
    output wire                                          ctrl_reg_rd_en,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]               ctrl_reg_rd_data,
    input  wire                                          ctrl_reg_rd_wait,
    input  wire                                          ctrl_reg_rd_ack,

    /*
     * PTP clock
     */
    input  wire                                          ptp_sample_clk,
    output wire                                          ptp_pps,
    output wire [PTP_TS_WIDTH-1:0]                       ptp_ts_96,
    output wire                                          ptp_ts_step,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_pulse,

    /*
     * Ethernet
     */
    input  wire [PORT_COUNT-1:0]                         eth_tx_clk,
    input  wire [PORT_COUNT-1:0]                         eth_tx_rst,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_tx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                         eth_tx_ptp_ts_step,

    output wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     m_axis_eth_tx_tdata,
    output wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     m_axis_eth_tx_tkeep,
    output wire [PORT_COUNT-1:0]                         m_axis_eth_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                         m_axis_eth_tx_tready,
    output wire [PORT_COUNT-1:0]                         m_axis_eth_tx_tlast,
    output wire [PORT_COUNT*AXIS_ETH_TX_USER_WIDTH-1:0]  m_axis_eth_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            s_axis_eth_tx_ptp_ts,
    input  wire [PORT_COUNT*PTP_TAG_WIDTH-1:0]           s_axis_eth_tx_ptp_ts_tag,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_tx_ptp_ts_valid,
    output wire [PORT_COUNT-1:0]                         s_axis_eth_tx_ptp_ts_ready,

    input  wire [PORT_COUNT-1:0]                         eth_rx_clk,
    input  wire [PORT_COUNT-1:0]                         eth_rx_rst,

    input  wire [PORT_COUNT-1:0]                         eth_rx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                         eth_rx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            eth_rx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                         eth_rx_ptp_ts_step,

    input  wire [PORT_COUNT*AXIS_ETH_DATA_WIDTH-1:0]     s_axis_eth_rx_tdata,
    input  wire [PORT_COUNT*AXIS_ETH_KEEP_WIDTH-1:0]     s_axis_eth_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tvalid,
    output wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tready,
    input  wire [PORT_COUNT-1:0]                         s_axis_eth_rx_tlast,
    input  wire [PORT_COUNT*AXIS_ETH_RX_USER_WIDTH-1:0]  s_axis_eth_rx_tuser,

    /*
     * Statistics increment input
     */
    input  wire [STAT_INC_WIDTH-1:0]                     s_axis_stat_tdata,
    input  wire [STAT_ID_WIDTH-1:0]                      s_axis_stat_tid,
    input  wire                                          s_axis_stat_tvalid,
    output wire                                          s_axis_stat_tready
);

parameter TLP_SEG_COUNT = 1;
parameter TLP_SEG_DATA_WIDTH = (SEG_COUNT*SEG_DATA_WIDTH)/TLP_SEG_COUNT;
parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32;
parameter TLP_SEG_HDR_WIDTH = 128;
parameter TX_SEQ_NUM_COUNT = SEG_COUNT;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_rx_req_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]                    pcie_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]                    pcie_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_eop;
wire                                          pcie_rx_req_tlp_ready;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_rx_cpl_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_rx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT*4-1:0]                    pcie_rx_cpl_tlp_error;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_eop;
wire                                          pcie_rx_cpl_tlp_ready;

wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_tx_rd_req_tlp_hdr;
wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_rd_req_tlp_seq;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_eop;
wire                                          pcie_tx_rd_req_tlp_ready;

wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  pcie_rd_req_tx_seq_num;
wire [TX_SEQ_NUM_COUNT-1:0]                   pcie_rd_req_tx_seq_num_valid;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_tx_wr_req_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   pcie_tx_wr_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_tx_wr_req_tlp_hdr;
wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_wr_req_tlp_seq;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_eop;
wire                                          pcie_tx_wr_req_tlp_ready;

wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  pcie_wr_req_tx_seq_num;
wire [TX_SEQ_NUM_COUNT-1:0]                   pcie_wr_req_tx_seq_num_valid;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_tx_cpl_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   pcie_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_eop;
wire                                          pcie_tx_cpl_tlp_ready;

wire [7:0]   pcie_tx_fc_ph_av;
wire [11:0]  pcie_tx_fc_pd_av;
wire [7:0]   pcie_tx_fc_nph_av;

wire [F_COUNT-1:0] ext_tag_enable;
wire [7:0] bus_num;
wire [F_COUNT*3-1:0] max_read_request_size;
wire [F_COUNT*3-1:0] max_payload_size;

wire [MSI_COUNT-1:0] msi_irq;

pcie_s10_if #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .L_TILE(L_TILE),
    .PF_COUNT(1),
    .VF_COUNT(0),
    .F_COUNT(PF_COUNT+VF_COUNT),
    .IO_BAR_INDEX(5),
    .MSI_ENABLE(1),
    .MSI_COUNT(MSI_COUNT)
)
pcie_s10_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * H-Tile/L-Tile RX AVST interface
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

    /*
     * H-Tile/L-Tile TX AVST interface
     */
    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),

    /*
     * H-Tile/L-Tile TX flow control
     */
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

    /*
     * H-Tile/L-Tile MSI interrupt interface
     */
    .app_msi_req(app_msi_req),
    .app_msi_ack(app_msi_ack),
    .app_msi_tc(app_msi_tc),
    .app_msi_num(app_msi_num),
    .app_msi_func_num(app_msi_func_num),

    /*
     * H-Tile/L-Tile configuration interface
     */
    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * TLP output (request to BAR)
     */
    .rx_req_tlp_data(pcie_rx_req_tlp_data),
    .rx_req_tlp_hdr(pcie_rx_req_tlp_hdr),
    .rx_req_tlp_bar_id(pcie_rx_req_tlp_bar_id),
    .rx_req_tlp_func_num(pcie_rx_req_tlp_func_num),
    .rx_req_tlp_valid(pcie_rx_req_tlp_valid),
    .rx_req_tlp_sop(pcie_rx_req_tlp_sop),
    .rx_req_tlp_eop(pcie_rx_req_tlp_eop),
    .rx_req_tlp_ready(pcie_rx_req_tlp_ready),

    /*
     * TLP output (completion to DMA)
     */
    .rx_cpl_tlp_data(pcie_rx_cpl_tlp_data),
    .rx_cpl_tlp_hdr(pcie_rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(pcie_rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(pcie_rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(pcie_rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(pcie_rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(pcie_rx_cpl_tlp_ready),

    /*
     * TLP input (read request from DMA)
     */
    .tx_rd_req_tlp_hdr(pcie_tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(pcie_tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(pcie_tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(pcie_tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(pcie_tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(pcie_tx_rd_req_tlp_ready),

    /*
     * Transmit sequence number output (DMA read request)
     */
    .m_axis_rd_req_tx_seq_num(pcie_rd_req_tx_seq_num),
    .m_axis_rd_req_tx_seq_num_valid(pcie_rd_req_tx_seq_num_valid),

    /*
     * TLP input (write request from DMA)
     */
    .tx_wr_req_tlp_data(pcie_tx_wr_req_tlp_data),
    .tx_wr_req_tlp_strb(pcie_tx_wr_req_tlp_strb),
    .tx_wr_req_tlp_hdr(pcie_tx_wr_req_tlp_hdr),
    .tx_wr_req_tlp_seq(pcie_tx_wr_req_tlp_seq),
    .tx_wr_req_tlp_valid(pcie_tx_wr_req_tlp_valid),
    .tx_wr_req_tlp_sop(pcie_tx_wr_req_tlp_sop),
    .tx_wr_req_tlp_eop(pcie_tx_wr_req_tlp_eop),
    .tx_wr_req_tlp_ready(pcie_tx_wr_req_tlp_ready),

    /*
     * Transmit sequence number output (DMA write request)
     */
    .m_axis_wr_req_tx_seq_num(pcie_wr_req_tx_seq_num),
    .m_axis_wr_req_tx_seq_num_valid(pcie_wr_req_tx_seq_num_valid),

    /*
     * TLP input (completion from BAR)
     */
    .tx_cpl_tlp_data(pcie_tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(pcie_tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(pcie_tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(pcie_tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(pcie_tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(pcie_tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(pcie_tx_cpl_tlp_ready),

    /*
     * Flow control
     */
    .tx_fc_ph_av(pcie_tx_fc_ph_av),
    .tx_fc_pd_av(pcie_tx_fc_pd_av),
    .tx_fc_nph_av(pcie_tx_fc_nph_av),
    .tx_fc_npd_av(),
    .tx_fc_cplh_av(),
    .tx_fc_cpld_av(),

    /*
     * Configuration outputs
     */
    .ext_tag_enable(ext_tag_enable),
    .bus_num(bus_num),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),

    /*
     * MSI request inputs
     */
    .msi_irq(msi_irq)
);

mqnic_core_pcie #(
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
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(1),
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
    .TLP_FORCE_64_BIT_ADDR(0),
    .CHECK_BUS_NUMBER(1),
    .MSI_COUNT(MSI_COUNT),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .AXIL_IF_CTRL_ADDR_WIDTH(AXIL_IF_CTRL_ADDR_WIDTH),
    .AXIL_CSR_ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .AXIL_CSR_PASSTHROUGH_ENABLE(AXIL_CSR_PASSTHROUGH_ENABLE),

    // AXI lite interface configuration (application control)
    .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),

    // Ethernet interface configuration
    .AXIS_DATA_WIDTH(AXIS_ETH_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_ETH_KEEP_WIDTH),
    .AXIS_SYNC_DATA_WIDTH(AXIS_ETH_SYNC_DATA_WIDTH),
    .AXIS_TX_USER_WIDTH(AXIS_ETH_TX_USER_WIDTH),
    .AXIS_RX_USER_WIDTH(AXIS_ETH_RX_USER_WIDTH),
    .AXIS_RX_USE_READY(AXIS_ETH_RX_USE_READY),
    .AXIS_TX_PIPELINE(AXIS_ETH_TX_PIPELINE),
    .AXIS_TX_FIFO_PIPELINE(AXIS_ETH_TX_FIFO_PIPELINE),
    .AXIS_TX_TS_PIPELINE(AXIS_ETH_TX_TS_PIPELINE),
    .AXIS_RX_PIPELINE(AXIS_ETH_RX_PIPELINE),
    .AXIS_RX_FIFO_PIPELINE(AXIS_ETH_RX_FIFO_PIPELINE),

    // Statistics counter subsystem
    .STAT_ENABLE(STAT_ENABLE),
    .STAT_DMA_ENABLE(STAT_DMA_ENABLE),
    .STAT_PCIE_ENABLE(STAT_PCIE_ENABLE),
    .STAT_INC_WIDTH(STAT_INC_WIDTH),
    .STAT_ID_WIDTH(STAT_ID_WIDTH)
)
core_pcie_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request to BAR)
     */
    .pcie_rx_req_tlp_data(pcie_rx_req_tlp_data),
    .pcie_rx_req_tlp_hdr(pcie_rx_req_tlp_hdr),
    .pcie_rx_req_tlp_bar_id(pcie_rx_req_tlp_bar_id),
    .pcie_rx_req_tlp_func_num(pcie_rx_req_tlp_func_num),
    .pcie_rx_req_tlp_valid(pcie_rx_req_tlp_valid),
    .pcie_rx_req_tlp_sop(pcie_rx_req_tlp_sop),
    .pcie_rx_req_tlp_eop(pcie_rx_req_tlp_eop),
    .pcie_rx_req_tlp_ready(pcie_rx_req_tlp_ready),

    /*
     * TLP input (completion to DMA)
     */
    .pcie_rx_cpl_tlp_data(pcie_rx_cpl_tlp_data),
    .pcie_rx_cpl_tlp_hdr(pcie_rx_cpl_tlp_hdr),
    .pcie_rx_cpl_tlp_error(pcie_rx_cpl_tlp_error),
    .pcie_rx_cpl_tlp_valid(pcie_rx_cpl_tlp_valid),
    .pcie_rx_cpl_tlp_sop(pcie_rx_cpl_tlp_sop),
    .pcie_rx_cpl_tlp_eop(pcie_rx_cpl_tlp_eop),
    .pcie_rx_cpl_tlp_ready(pcie_rx_cpl_tlp_ready),

    /*
     * TLP output (read request from DMA)
     */
    .pcie_tx_rd_req_tlp_hdr(pcie_tx_rd_req_tlp_hdr),
    .pcie_tx_rd_req_tlp_seq(pcie_tx_rd_req_tlp_seq),
    .pcie_tx_rd_req_tlp_valid(pcie_tx_rd_req_tlp_valid),
    .pcie_tx_rd_req_tlp_sop(pcie_tx_rd_req_tlp_sop),
    .pcie_tx_rd_req_tlp_eop(pcie_tx_rd_req_tlp_eop),
    .pcie_tx_rd_req_tlp_ready(pcie_tx_rd_req_tlp_ready),

    /*
     * Transmit sequence number input (DMA read request)
     */
    .s_axis_pcie_rd_req_tx_seq_num(pcie_rd_req_tx_seq_num),
    .s_axis_pcie_rd_req_tx_seq_num_valid(pcie_rd_req_tx_seq_num_valid),

    /*
     * TLP output (write request from DMA)
     */
    .pcie_tx_wr_req_tlp_data(pcie_tx_wr_req_tlp_data),
    .pcie_tx_wr_req_tlp_strb(pcie_tx_wr_req_tlp_strb),
    .pcie_tx_wr_req_tlp_hdr(pcie_tx_wr_req_tlp_hdr),
    .pcie_tx_wr_req_tlp_seq(pcie_tx_wr_req_tlp_seq),
    .pcie_tx_wr_req_tlp_valid(pcie_tx_wr_req_tlp_valid),
    .pcie_tx_wr_req_tlp_sop(pcie_tx_wr_req_tlp_sop),
    .pcie_tx_wr_req_tlp_eop(pcie_tx_wr_req_tlp_eop),
    .pcie_tx_wr_req_tlp_ready(pcie_tx_wr_req_tlp_ready),

    /*
     * Transmit sequence number input (DMA write request)
     */
    .s_axis_pcie_wr_req_tx_seq_num(pcie_wr_req_tx_seq_num),
    .s_axis_pcie_wr_req_tx_seq_num_valid(pcie_wr_req_tx_seq_num_valid),

    /*
     * TLP output (completion from BAR)
     */
    .pcie_tx_cpl_tlp_data(pcie_tx_cpl_tlp_data),
    .pcie_tx_cpl_tlp_strb(pcie_tx_cpl_tlp_strb),
    .pcie_tx_cpl_tlp_hdr(pcie_tx_cpl_tlp_hdr),
    .pcie_tx_cpl_tlp_valid(pcie_tx_cpl_tlp_valid),
    .pcie_tx_cpl_tlp_sop(pcie_tx_cpl_tlp_sop),
    .pcie_tx_cpl_tlp_eop(pcie_tx_cpl_tlp_eop),
    .pcie_tx_cpl_tlp_ready(pcie_tx_cpl_tlp_ready),

    /*
     * Flow control credits
     */
    .pcie_tx_fc_ph_av(pcie_tx_fc_ph_av),
    .pcie_tx_fc_pd_av(pcie_tx_fc_pd_av),
    .pcie_tx_fc_nph_av(pcie_tx_fc_nph_av),

    /*
     * Configuration inputs
     */
    .bus_num(bus_num),
    .ext_tag_enable(ext_tag_enable),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),

    /*
     * PCIe error outputs
     */
    .pcie_error_cor(),
    .pcie_error_uncor(),

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    .m_axil_csr_awaddr(m_axil_csr_awaddr),
    .m_axil_csr_awprot(m_axil_csr_awprot),
    .m_axil_csr_awvalid(m_axil_csr_awvalid),
    .m_axil_csr_awready(m_axil_csr_awready),
    .m_axil_csr_wdata(m_axil_csr_wdata),
    .m_axil_csr_wstrb(m_axil_csr_wstrb),
    .m_axil_csr_wvalid(m_axil_csr_wvalid),
    .m_axil_csr_wready(m_axil_csr_wready),
    .m_axil_csr_bresp(m_axil_csr_bresp),
    .m_axil_csr_bvalid(m_axil_csr_bvalid),
    .m_axil_csr_bready(m_axil_csr_bready),
    .m_axil_csr_araddr(m_axil_csr_araddr),
    .m_axil_csr_arprot(m_axil_csr_arprot),
    .m_axil_csr_arvalid(m_axil_csr_arvalid),
    .m_axil_csr_arready(m_axil_csr_arready),
    .m_axil_csr_rdata(m_axil_csr_rdata),
    .m_axil_csr_rresp(m_axil_csr_rresp),
    .m_axil_csr_rvalid(m_axil_csr_rvalid),
    .m_axil_csr_rready(m_axil_csr_rready),

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
     * MSI request outputs
     */
    .msi_irq(msi_irq),

    /*
     * PTP clock
     */
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_pps(ptp_pps),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step),
    .ptp_perout_locked(ptp_perout_locked),
    .ptp_perout_error(ptp_perout_error),
    .ptp_perout_pulse(ptp_perout_pulse),

    /*
     * Ethernet
     */
    .tx_clk(eth_tx_clk),
    .tx_rst(eth_tx_rst),

    .tx_ptp_ts_96(eth_tx_ptp_ts_96),
    .tx_ptp_ts_step(eth_tx_ptp_ts_step),

    .m_axis_tx_tdata(m_axis_eth_tx_tdata),
    .m_axis_tx_tkeep(m_axis_eth_tx_tkeep),
    .m_axis_tx_tvalid(m_axis_eth_tx_tvalid),
    .m_axis_tx_tready(m_axis_eth_tx_tready),
    .m_axis_tx_tlast(m_axis_eth_tx_tlast),
    .m_axis_tx_tuser(m_axis_eth_tx_tuser),

    .s_axis_tx_ptp_ts(s_axis_eth_tx_ptp_ts),
    .s_axis_tx_ptp_ts_tag(s_axis_eth_tx_ptp_ts_tag),
    .s_axis_tx_ptp_ts_valid(s_axis_eth_tx_ptp_ts_valid),
    .s_axis_tx_ptp_ts_ready(s_axis_eth_tx_ptp_ts_ready),

    .rx_clk(eth_rx_clk),
    .rx_rst(eth_rx_rst),

    .rx_ptp_clk(eth_rx_ptp_clk),
    .rx_ptp_rst(eth_rx_ptp_rst),
    .rx_ptp_ts_96(eth_rx_ptp_ts_96),
    .rx_ptp_ts_step(eth_rx_ptp_ts_step),

    .s_axis_rx_tdata(s_axis_eth_rx_tdata),
    .s_axis_rx_tkeep(s_axis_eth_rx_tkeep),
    .s_axis_rx_tvalid(s_axis_eth_rx_tvalid),
    .s_axis_rx_tready(s_axis_eth_rx_tready),
    .s_axis_rx_tlast(s_axis_eth_rx_tlast),
    .s_axis_rx_tuser(s_axis_eth_rx_tuser),

    /*
     * Statistics input
     */
    .s_axis_stat_tdata(s_axis_stat_tdata),
    .s_axis_stat_tid(s_axis_stat_tid),
    .s_axis_stat_tvalid(s_axis_stat_tvalid),
    .s_axis_stat_tready(s_axis_stat_tready)
);

endmodule

`resetall
