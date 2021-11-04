/*

Copyright (c) 2021 Alex Forencich

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
 * Intel Stratix 10 H-Tile/L-Tile PCIe interface adapter
 */
module pcie_s10_if #
(
    // H-Tile/L-Tile AVST segment count
    parameter SEG_COUNT = 1,
    // H-Tile/L-Tile AVST segment data width
    parameter SEG_DATA_WIDTH = 256,
    // H-Tile/L-Tile AVST segment empty signal width
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = (SEG_COUNT*SEG_DATA_WIDTH)/TLP_SEG_COUNT,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 6,
    // Tile selection (0 for H-Tile, 1 for L-Tile)
    parameter L_TILE = 0,
    // Number of PFs
    parameter PF_COUNT = 1,
    // Number of VFs
    parameter VF_COUNT = 0,
    // Total number of functions
    parameter F_COUNT = PF_COUNT+VF_COUNT,
    // IO bar index
    // rx_st_bar_range = 6 is mapped to IO_BAR_INDEX on rx_req_tlp_bar_id
    parameter IO_BAR_INDEX = 5,
    // enable MSI support
    parameter MSI_ENABLE = 1,
    // MSI vector count
    parameter MSI_COUNT = 32
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * H-Tile/L-Tile RX AVST interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]          rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]         rx_st_empty,
    input  wire [SEG_COUNT-1:0]                         rx_st_sop,
    input  wire [SEG_COUNT-1:0]                         rx_st_eop,
    input  wire [SEG_COUNT-1:0]                         rx_st_valid,
    output wire                                         rx_st_ready,
    input  wire [SEG_COUNT-1:0]                         rx_st_vf_active,
    input  wire [SEG_COUNT*2-1:0]                       rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]                      rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                       rx_st_bar_range,

    /*
     * H-Tile/L-Tile TX AVST interface
     */
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]          tx_st_data,
    output wire [SEG_COUNT-1:0]                         tx_st_sop,
    output wire [SEG_COUNT-1:0]                         tx_st_eop,
    output wire [SEG_COUNT-1:0]                         tx_st_valid,
    input  wire                                         tx_st_ready,
    output wire [SEG_COUNT-1:0]                         tx_st_err,

    /*
     * H-Tile/L-Tile TX flow control
     */
    input  wire [7:0]                                   tx_ph_cdts,
    input  wire [11:0]                                  tx_pd_cdts,
    input  wire [7:0]                                   tx_nph_cdts,
    input  wire [11:0]                                  tx_npd_cdts,
    input  wire [7:0]                                   tx_cplh_cdts,
    input  wire [11:0]                                  tx_cpld_cdts,
    input  wire [SEG_COUNT-1:0]                         tx_hdr_cdts_consumed,
    input  wire [SEG_COUNT-1:0]                         tx_data_cdts_consumed,
    input  wire [SEG_COUNT*2-1:0]                       tx_cdts_type,
    input  wire [SEG_COUNT*1-1:0]                       tx_cdts_data_value,

    /*
     * H-Tile/L-Tile MSI interrupt interface
     */
    output wire                                         app_msi_req,
    input  wire                                         app_msi_ack,
    output wire [2:0]                                   app_msi_tc,
    output wire [4:0]                                   app_msi_num,
    output wire [1:0]                                   app_msi_func_num,

    /*
     * H-Tile/L-Tile configuration interface
     */
    input  wire [31:0]                                  tl_cfg_ctl,
    input  wire [4:0]                                   tl_cfg_add,
    input  wire [1:0]                                   tl_cfg_func,

    /*
     * TLP output (request to BAR)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_req_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]                   rx_req_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]                   rx_req_tlp_func_num,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_eop,
    input  wire                                         rx_req_tlp_ready,

    /*
     * TLP output (completion to DMA)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_cpl_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT*4-1:0]                   rx_cpl_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_eop,
    input  wire                                         rx_cpl_tlp_ready,

    /*
     * TLP input (read request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_rd_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]    tx_rd_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_rd_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_rd_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_rd_req_tlp_eop,
    output wire                                         tx_rd_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA read request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]        m_axis_rd_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                         m_axis_rd_req_tx_seq_num_valid,

    /*
     * TLP input (write request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  tx_wr_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  tx_wr_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_wr_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]    tx_wr_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_wr_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_wr_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_wr_req_tlp_eop,
    output wire                                         tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA write request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]        m_axis_wr_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                         m_axis_wr_req_tx_seq_num_valid,

    /*
     * TLP input (completion from BAR)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  tx_cpl_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  tx_cpl_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_eop,
    output wire                                         tx_cpl_tlp_ready,

    /*
     * Flow control
     */
    output wire [7:0]                                   tx_fc_ph_av,
    output wire [11:0]                                  tx_fc_pd_av,
    output wire [7:0]                                   tx_fc_nph_av,
    output wire [11:0]                                  tx_fc_npd_av,
    output wire [7:0]                                   tx_fc_cplh_av,
    output wire [11:0]                                  tx_fc_cpld_av,

    /*
     * Configuration outputs
     */
    output wire [F_COUNT-1:0]                           ext_tag_enable,
    output wire [7:0]                                   bus_num,
    output wire [F_COUNT*3-1:0]                         max_read_request_size,
    output wire [F_COUNT*3-1:0]                         max_payload_size,

    /*
     * MSI request inputs
     */
    input  wire [MSI_COUNT-1:0]                         msi_irq
);

wire [PF_COUNT-1:0]     cfg_msi_enable;
wire [PF_COUNT*3-1:0]   cfg_multiple_msi_enable;
wire [PF_COUNT*32-1:0]  cfg_msi_mask;

pcie_s10_if_rx #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .IO_BAR_INDEX(IO_BAR_INDEX)
)
pcie_s10_if_rx_inst (
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
     * TLP output (request to BAR)
     */
    .rx_req_tlp_data(rx_req_tlp_data),
    .rx_req_tlp_hdr(rx_req_tlp_hdr),
    .rx_req_tlp_bar_id(rx_req_tlp_bar_id),
    .rx_req_tlp_func_num(rx_req_tlp_func_num),
    .rx_req_tlp_valid(rx_req_tlp_valid),
    .rx_req_tlp_sop(rx_req_tlp_sop),
    .rx_req_tlp_eop(rx_req_tlp_eop),
    .rx_req_tlp_ready(rx_req_tlp_ready),

    /*
     * TLP output (completion to DMA)
     */
    .rx_cpl_tlp_data(rx_cpl_tlp_data),
    .rx_cpl_tlp_hdr(rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(rx_cpl_tlp_ready)
);

pcie_s10_if_tx #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH)
)
pcie_s10_if_tx_inst (
    .clk(clk),
    .rst(rst),

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
     * TLP input (read request from DMA)
     */
    .tx_rd_req_tlp_hdr(tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(tx_rd_req_tlp_ready),

    /*
     * Transmit sequence number output (DMA read request)
     */
    .m_axis_rd_req_tx_seq_num(m_axis_rd_req_tx_seq_num),
    .m_axis_rd_req_tx_seq_num_valid(m_axis_rd_req_tx_seq_num_valid),

    /*
     * TLP input (write request from DMA)
     */
    .tx_wr_req_tlp_data(tx_wr_req_tlp_data),
    .tx_wr_req_tlp_strb(tx_wr_req_tlp_strb),
    .tx_wr_req_tlp_hdr(tx_wr_req_tlp_hdr),
    .tx_wr_req_tlp_seq(tx_wr_req_tlp_seq),
    .tx_wr_req_tlp_valid(tx_wr_req_tlp_valid),
    .tx_wr_req_tlp_sop(tx_wr_req_tlp_sop),
    .tx_wr_req_tlp_eop(tx_wr_req_tlp_eop),
    .tx_wr_req_tlp_ready(tx_wr_req_tlp_ready),

    /*
     * Transmit sequence number output (DMA write request)
     */
    .m_axis_wr_req_tx_seq_num(m_axis_wr_req_tx_seq_num),
    .m_axis_wr_req_tx_seq_num_valid(m_axis_wr_req_tx_seq_num_valid),

    /*
     * TLP input (completion from BAR)
     */
    .tx_cpl_tlp_data(tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(tx_cpl_tlp_ready)
);

pcie_s10_cfg #(
    .L_TILE(L_TILE),
    .PF_COUNT(PF_COUNT)
)
pcie_s10_cfg_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Configuration input from H-Tile/L-Tile
     */
    .tl_cfg_ctl(tl_cfg_ctl),
    .tl_cfg_add(tl_cfg_add),
    .tl_cfg_func(tl_cfg_func),

    /*
     * Configuration output
     */
    .cfg_memory_space_en(),
    .cfg_ido_cpl_en(),
    .cfg_perr_en(),
    .cfg_serr_en(),
    .cfg_fatal_err_rpt_en(),
    .cfg_nonfatal_err_rpt_en(),
    .cfg_corr_err_rpt_en(),
    .cfg_unsupported_req_rpt_en(),
    .cfg_bus_master_en(),
    .cfg_ext_tag_en(ext_tag_enable),
    .cfg_max_read_request_size(max_read_request_size),
    .cfg_max_payload_size(max_payload_size),
    .cfg_ido_request_en(),
    .cfg_no_snoop_en(),
    .cfg_relaxed_ordering_en(),
    .cfg_device_num(),
    .cfg_bus_num(bus_num),
    .cfg_pm_no_soft_rst(),
    .cfg_rcb_ctrl(),
    .cfg_irq_disable(),
    .cfg_pcie_cap_irq_msg_num(),
    .cfg_sys_pwr_ctrl(),
    .cfg_sys_atten_ind_ctrl(),
    .cfg_sys_pwr_ind_ctrl(),
    .cfg_num_vf(),
    .cfg_ats_stu(),
    .cfg_ats_cache_en(),
    .cfg_ari_forward_en(),
    .cfg_atomic_request_en(),
    .cfg_tph_st_mode(),
    .cfg_tph_en(),
    .cfg_vf_en(),
    .cfg_an_link_speed(),
    .cfg_start_vf_index(),
    .cfg_msi_address(),
    .cfg_msi_mask(cfg_msi_mask),
    .cfg_send_f_err(),
    .cfg_send_nf_err(),
    .cfg_send_cor_err(),
    .cfg_aer_irq_msg_num(),
    .cfg_msix_func_mask(),
    .cfg_msix_enable(),
    .cfg_multiple_msi_enable(cfg_multiple_msi_enable),
    .cfg_64bit_msi(),
    .cfg_msi_enable(cfg_msi_enable),
    .cfg_msi_data(),
    .cfg_aer_uncor_err_mask(),
    .cfg_aer_corr_err_mask(),
    .cfg_aer_uncor_err_severity()
);

assign tx_fc_ph_av = tx_ph_cdts;
assign tx_fc_pd_av = tx_pd_cdts;
assign tx_fc_nph_av = tx_nph_cdts;
assign tx_fc_npd_av = L_TILE ? tx_npd_cdts : 0;
assign tx_fc_cplh_av = tx_cplh_cdts;
assign tx_fc_cpld_av = L_TILE ? tx_cpld_cdts : 0;

generate

if (MSI_ENABLE) begin

    pcie_s10_msi #(
        .MSI_COUNT(MSI_COUNT)
    )
    pcie_s10_msi_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Interrupt request inputs
         */
        .msi_irq(msi_irq),

        /*
         * Interface to H-Tile/L-Tile PCIe IP core
         */
        .app_msi_req(app_msi_req),
        .app_msi_ack(app_msi_ack),
        .app_msi_tc(app_msi_tc),
        .app_msi_num(app_msi_num),
        .app_msi_func_num(app_msi_func_num),

        /*
         * Configuration
         */
        .cfg_msi_enable(cfg_msi_enable),
        .cfg_multiple_msi_enable(cfg_multiple_msi_enable),
        .cfg_msi_mask(cfg_msi_mask)
    );

end else begin

    assign app_msi_req = 0;
    assign app_msi_tc = 0;
    assign app_msi_num = 0;
    assign app_msi_func_num = 0;

end

endgenerate

endmodule

`resetall
