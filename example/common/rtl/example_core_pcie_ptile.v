/*

Copyright (c) 2022 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Example design core logic - Intel P-Tile wrapper
 */
module example_core_pcie_ptile #
(
    // P-Tile AVST segment count
    parameter SEG_COUNT = 1,
    // P-Tile AVST segment data width
    parameter SEG_DATA_WIDTH = 128,
    // P-Tile AVST segment empty signal width
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    // P-Tile AVST segment header width
    parameter SEG_HDR_WIDTH = 128,
    // P-Tile AVST segment TLP prefix width
    parameter SEG_PRFX_WIDTH = 32,
    // Immediate enable
    parameter IMM_ENABLE = 1,
    // Immediate width
    parameter IMM_WIDTH = 32,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 6,
    // TX sequence number tracking enable
    parameter TX_SEQ_NUM_ENABLE = 1,
    // PCIe tag count
    parameter PCIE_TAG_COUNT = 256,
    // Operation table size (read)
    parameter READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    // In-flight transmit limit (read)
    parameter READ_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // Completion header flow control credit limit (read)
    parameter READ_CPLH_FC_LIMIT = 1144,
    // Completion data flow control credit limit (read)
    parameter READ_CPLD_FC_LIMIT = 2888,
    // Operation table size (write)
    parameter WRITE_OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    // In-flight transmit limit (write)
    parameter WRITE_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // BAR0 aperture (log2 size)
    parameter BAR0_APERTURE = 24,
    // BAR2 aperture (log2 size)
    parameter BAR2_APERTURE = 24,
    // BAR4 aperture (log2 size)
    parameter BAR4_APERTURE = 16
)
(
    input  wire                                  clk,
    input  wire                                  rst,

    /*
     * P-Tile RX AVST interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]  rx_st_empty,
    input  wire [SEG_COUNT-1:0]                  rx_st_sop,
    input  wire [SEG_COUNT-1:0]                  rx_st_eop,
    input  wire [SEG_COUNT-1:0]                  rx_st_valid,
    output wire                                  rx_st_ready,
    input  wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    rx_st_hdr,
    input  wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   rx_st_tlp_prfx,
    input  wire [SEG_COUNT-1:0]                  rx_st_vf_active,
    input  wire [SEG_COUNT*3-1:0]                rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]               rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                rx_st_bar_range,
    input  wire [SEG_COUNT-1:0]                  rx_st_tlp_abort,

    /*
     * P-Tile TX AVST interface
     */
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]   tx_st_data,
    output wire [SEG_COUNT-1:0]                  tx_st_sop,
    output wire [SEG_COUNT-1:0]                  tx_st_eop,
    output wire [SEG_COUNT-1:0]                  tx_st_valid,
    input  wire                                  tx_st_ready,
    output wire [SEG_COUNT-1:0]                  tx_st_err,
    output wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]    tx_st_hdr,
    output wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]   tx_st_tlp_prfx,

    /*
     * P-Tile RX flow control
     */
    output wire [11:0]                           rx_buffer_limit,
    output wire [1:0]                            rx_buffer_limit_tdm_idx,

    /*
     * P-Tile TX flow control
     */
    input  wire [15:0]                           tx_cdts_limit,
    input  wire [2:0]                            tx_cdts_limit_tdm_idx,

    /*
     * P-Tile configuration interface
     */
    input  wire [15:0]                           tl_cfg_ctl,
    input  wire [4:0]                            tl_cfg_add,
    input  wire [2:0]                            tl_cfg_func
);

parameter TLP_DATA_WIDTH = SEG_COUNT*SEG_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32;
parameter TLP_HDR_WIDTH = 128;
parameter TLP_SEG_COUNT = 1;
parameter TX_SEQ_NUM_COUNT = SEG_COUNT;
parameter PF_COUNT = 1;
parameter VF_COUNT = 0;
parameter F_COUNT = PF_COUNT+VF_COUNT;
parameter MSI_COUNT = 32;

wire [TLP_DATA_WIDTH-1:0]                     pcie_rx_req_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_rx_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]                    pcie_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]                    pcie_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_eop;
wire                                          pcie_rx_req_tlp_ready;

wire [TLP_DATA_WIDTH-1:0]                     pcie_rx_cpl_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_rx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_rx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT*4-1:0]                    pcie_rx_cpl_tlp_error;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_eop;
wire                                          pcie_rx_cpl_tlp_ready;

wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_tx_rd_req_tlp_hdr;
wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_rd_req_tlp_seq;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_eop;
wire                                          pcie_tx_rd_req_tlp_ready;

wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  axis_pcie_rd_req_tx_seq_num;
wire [TX_SEQ_NUM_COUNT-1:0]                   axis_pcie_rd_req_tx_seq_num_valid;

wire [TLP_DATA_WIDTH-1:0]                     pcie_tx_wr_req_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_tx_wr_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_tx_wr_req_tlp_hdr;
wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_wr_req_tlp_seq;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_eop;
wire                                          pcie_tx_wr_req_tlp_ready;

wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  axis_pcie_wr_req_tx_seq_num;
wire [TX_SEQ_NUM_COUNT-1:0]                   axis_pcie_wr_req_tx_seq_num_valid;

wire [TLP_DATA_WIDTH-1:0]                     pcie_tx_cpl_tlp_data;
wire [TLP_STRB_WIDTH-1:0]                     pcie_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        pcie_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_eop;
wire                                          pcie_tx_cpl_tlp_ready;

wire [31:0]                                   pcie_tx_msix_wr_req_tlp_data;
wire                                          pcie_tx_msix_wr_req_tlp_strb;
wire [TLP_HDR_WIDTH-1:0]                      pcie_tx_msix_wr_req_tlp_hdr;
wire                                          pcie_tx_msix_wr_req_tlp_valid;
wire                                          pcie_tx_msix_wr_req_tlp_sop;
wire                                          pcie_tx_msix_wr_req_tlp_eop;
wire                                          pcie_tx_msix_wr_req_tlp_ready;

wire ext_tag_enable;
wire rcb_128b;
wire [7:0] bus_num;
wire [2:0] max_read_request_size;
wire [2:0] max_payload_size;
wire msix_enable;
wire msix_mask;

wire rx_cpl_stall;

wire rx_st_ready_int;

assign rx_st_ready = rx_st_ready_int & !rx_cpl_stall;

pcie_ptile_if #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .PF_COUNT(1),
    .VF_COUNT(0),
    .F_COUNT(PF_COUNT+VF_COUNT),
    .IO_BAR_INDEX(5)
)
pcie_ptile_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * P-Tile RX AVST interface
     */
    .rx_st_data(rx_st_data),
    .rx_st_empty(rx_st_empty),
    .rx_st_sop(rx_st_sop),
    .rx_st_eop(rx_st_eop),
    .rx_st_valid(rx_st_valid),
    .rx_st_ready(rx_st_ready_int),
    .rx_st_hdr(rx_st_hdr),
    .rx_st_tlp_prfx(rx_st_tlp_prfx),
    .rx_st_vf_active(rx_st_vf_active),
    .rx_st_func_num(rx_st_func_num),
    .rx_st_vf_num(rx_st_vf_num),
    .rx_st_bar_range(rx_st_bar_range),
    .rx_st_tlp_abort(rx_st_tlp_abort),

    /*
     * P-Tile TX AVST interface
     */
    .tx_st_data(tx_st_data),
    .tx_st_sop(tx_st_sop),
    .tx_st_eop(tx_st_eop),
    .tx_st_valid(tx_st_valid),
    .tx_st_ready(tx_st_ready),
    .tx_st_err(tx_st_err),
    .tx_st_hdr(tx_st_hdr),
    .tx_st_tlp_prfx(tx_st_tlp_prfx),

    /*
     * P-Tile RX flow control
     */
    .rx_buffer_limit(rx_buffer_limit),
    .rx_buffer_limit_tdm_idx(rx_buffer_limit_tdm_idx),

    /*
     * P-Tile TX flow control
     */
    .tx_cdts_limit(tx_cdts_limit),
    .tx_cdts_limit_tdm_idx(tx_cdts_limit_tdm_idx),

    /*
     * P-Tile configuration interface
     */
    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * TLP output (request to BAR)
     */
    .rx_req_tlp_data(pcie_rx_req_tlp_data),
    .rx_req_tlp_strb(pcie_rx_req_tlp_strb),
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
    .rx_cpl_tlp_strb(pcie_rx_cpl_tlp_strb),
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
    .m_axis_rd_req_tx_seq_num(axis_pcie_rd_req_tx_seq_num),
    .m_axis_rd_req_tx_seq_num_valid(axis_pcie_rd_req_tx_seq_num_valid),

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
    .m_axis_wr_req_tx_seq_num(axis_pcie_wr_req_tx_seq_num),
    .m_axis_wr_req_tx_seq_num_valid(axis_pcie_wr_req_tx_seq_num_valid),

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
     * TLP input (write request from MSI)
     */
    .tx_msi_wr_req_tlp_data(pcie_tx_msix_wr_req_tlp_data),
    .tx_msi_wr_req_tlp_strb(pcie_tx_msix_wr_req_tlp_strb),
    .tx_msi_wr_req_tlp_hdr(pcie_tx_msix_wr_req_tlp_hdr),
    .tx_msi_wr_req_tlp_valid(pcie_tx_msix_wr_req_tlp_valid),
    .tx_msi_wr_req_tlp_sop(pcie_tx_msix_wr_req_tlp_sop),
    .tx_msi_wr_req_tlp_eop(pcie_tx_msix_wr_req_tlp_eop),
    .tx_msi_wr_req_tlp_ready(pcie_tx_msix_wr_req_tlp_ready),

    /*
     * Flow control
     */
    .tx_fc_ph_av(),
    .tx_fc_pd_av(),
    .tx_fc_nph_av(),
    .tx_fc_npd_av(),
    .tx_fc_cplh_av(),
    .tx_fc_cpld_av(),

    /*
     * Configuration outputs
     */
    .ext_tag_enable(ext_tag_enable),
    .rcb_128b(rcb_128b),
    .bus_num(bus_num),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask)
);

example_core_pcie #(
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(TX_SEQ_NUM_ENABLE),
    .IMM_ENABLE(IMM_ENABLE),
    .IMM_WIDTH(IMM_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .READ_OP_TABLE_SIZE(READ_OP_TABLE_SIZE),
    .READ_TX_LIMIT(READ_TX_LIMIT),
    .READ_CPLH_FC_LIMIT(READ_CPLH_FC_LIMIT),
    .READ_CPLD_FC_LIMIT(READ_CPLD_FC_LIMIT),
    .WRITE_OP_TABLE_SIZE(WRITE_OP_TABLE_SIZE),
    .WRITE_TX_LIMIT(WRITE_TX_LIMIT),
    .TLP_FORCE_64_BIT_ADDR(0),
    .CHECK_BUS_NUMBER(1),
    .BAR0_APERTURE(BAR0_APERTURE),
    .BAR2_APERTURE(BAR2_APERTURE),
    .BAR4_APERTURE(BAR4_APERTURE)
)
core_pcie_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request)
     */
    .rx_req_tlp_data(pcie_rx_req_tlp_data),
    .rx_req_tlp_strb(pcie_rx_req_tlp_strb),
    .rx_req_tlp_hdr(pcie_rx_req_tlp_hdr),
    .rx_req_tlp_valid(pcie_rx_req_tlp_valid),
    .rx_req_tlp_bar_id(pcie_rx_req_tlp_bar_id),
    .rx_req_tlp_func_num(pcie_rx_req_tlp_func_num),
    .rx_req_tlp_sop(pcie_rx_req_tlp_sop),
    .rx_req_tlp_eop(pcie_rx_req_tlp_eop),
    .rx_req_tlp_ready(pcie_rx_req_tlp_ready),

    /*
     * TLP output (completion)
     */
    .tx_cpl_tlp_data(pcie_tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(pcie_tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(pcie_tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(pcie_tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(pcie_tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(pcie_tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(pcie_tx_cpl_tlp_ready),

    /*
     * TLP input (completion)
     */
    .rx_cpl_tlp_data(pcie_rx_cpl_tlp_data),
    .rx_cpl_tlp_strb(pcie_rx_cpl_tlp_strb),
    .rx_cpl_tlp_hdr(pcie_rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(pcie_rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(pcie_rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(pcie_rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(pcie_rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(pcie_rx_cpl_tlp_ready),

    /*
     * TLP output (read request)
     */
    .tx_rd_req_tlp_hdr(pcie_tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(pcie_tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(pcie_tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(pcie_tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(pcie_tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(pcie_tx_rd_req_tlp_ready),

    /*
     * TLP output (write request)
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
     * Transmit sequence number input
     */
    .s_axis_rd_req_tx_seq_num(axis_pcie_rd_req_tx_seq_num),
    .s_axis_rd_req_tx_seq_num_valid(axis_pcie_rd_req_tx_seq_num_valid),
    .s_axis_wr_req_tx_seq_num(axis_pcie_wr_req_tx_seq_num),
    .s_axis_wr_req_tx_seq_num_valid(axis_pcie_wr_req_tx_seq_num_valid),

    /*
     * TLP output (MSI-X write request)
     */
    .tx_msix_wr_req_tlp_data(pcie_tx_msix_wr_req_tlp_data),
    .tx_msix_wr_req_tlp_strb(pcie_tx_msix_wr_req_tlp_strb),
    .tx_msix_wr_req_tlp_hdr(pcie_tx_msix_wr_req_tlp_hdr),
    .tx_msix_wr_req_tlp_valid(pcie_tx_msix_wr_req_tlp_valid),
    .tx_msix_wr_req_tlp_sop(pcie_tx_msix_wr_req_tlp_sop),
    .tx_msix_wr_req_tlp_eop(pcie_tx_msix_wr_req_tlp_eop),
    .tx_msix_wr_req_tlp_ready(pcie_tx_msix_wr_req_tlp_ready),

    /*
     * Configuration
     */
    .bus_num(bus_num),
    .ext_tag_enable(ext_tag_enable),
    .rcb_128b(rcb_128b),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask),

    /*
     * Status
     */
    .status_error_cor(),
    .status_error_uncor(),

    /*
     * Control and status
     */
    .rx_cpl_stall(rx_cpl_stall)
);

endmodule

`resetall
