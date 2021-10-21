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
 * Xilinx UltraScale PCIe interface adapter
 */
module pcie_us_if #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream RC tuser signal width
    parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161,
    // PCIe AXI stream RQ tuser signal width
    parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 60 : 137,
    // PCIe AXI stream CQ tuser signal width
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
    // PCIe AXI stream CC tuser signal width
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81,
    // RQ sequence number width
    parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH/TLP_SEG_COUNT,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // TX sequence number count
    parameter TX_SEQ_NUM_COUNT = AXIS_PCIE_DATA_WIDTH < 512 ? 1 : 2,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = RQ_SEQ_NUM_WIDTH-1,
    // Number of PFs
    parameter PF_COUNT = 1,
    // Number of VFs
    parameter VF_COUNT = 0,
    // Total number of functions
    parameter F_COUNT = PF_COUNT+VF_COUNT,
    // Read extended tag enable bit
    parameter READ_EXT_TAG_ENABLE = 1,
    // Read max read request size field
    parameter READ_MAX_READ_REQ_SIZE = 1,
    // Read max payload size field
    parameter READ_MAX_PAYLOAD_SIZE = 1,
    // enable MSI support
    parameter MSI_ENABLE = 1,
    // MSI vector count
    parameter MSI_COUNT = 32
)
(
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * AXI input (RC)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]               s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]               s_axis_rc_tkeep,
    input  wire                                          s_axis_rc_tvalid,
    output wire                                          s_axis_rc_tready,
    input  wire                                          s_axis_rc_tlast,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0]            s_axis_rc_tuser,

    /*
     * AXI output (RQ)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]               m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]               m_axis_rq_tkeep,
    output wire                                          m_axis_rq_tvalid,
    input  wire                                          m_axis_rq_tready,
    output wire                                          m_axis_rq_tlast,
    output wire [AXIS_PCIE_RQ_USER_WIDTH-1:0]            m_axis_rq_tuser,

    /*
     * AXI input (CQ)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]               s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]               s_axis_cq_tkeep,
    input  wire                                          s_axis_cq_tvalid,
    output wire                                          s_axis_cq_tready,
    input  wire                                          s_axis_cq_tlast,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0]            s_axis_cq_tuser,

    /*
     * AXI output (CC)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]               m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]               m_axis_cc_tkeep,
    output wire                                          m_axis_cc_tvalid,
    input  wire                                          m_axis_cc_tready,
    output wire                                          m_axis_cc_tlast,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0]            m_axis_cc_tuser,

    /*
     * Transmit sequence number input
     */
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]                   s_axis_rq_seq_num_0,
    input  wire                                          s_axis_rq_seq_num_valid_0,
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]                   s_axis_rq_seq_num_1,
    input  wire                                          s_axis_rq_seq_num_valid_1,

    /*
     * Flow control
     */
    input  wire [7:0]                                    cfg_fc_ph,
    input  wire [11:0]                                   cfg_fc_pd,
    input  wire [7:0]                                    cfg_fc_nph,
    input  wire [11:0]                                   cfg_fc_npd,
    input  wire [7:0]                                    cfg_fc_cplh,
    input  wire [11:0]                                   cfg_fc_cpld,
    output wire [2:0]                                    cfg_fc_sel,

    /*
     * Configuration interface
     */
    output wire [9:0]                                    cfg_mgmt_addr,
    output wire [7:0]                                    cfg_mgmt_function_number,
    output wire                                          cfg_mgmt_write,
    output wire [31:0]                                   cfg_mgmt_write_data,
    output wire [3:0]                                    cfg_mgmt_byte_enable,
    output wire                                          cfg_mgmt_read,
    input  wire [31:0]                                   cfg_mgmt_read_data,
    input  wire                                          cfg_mgmt_read_write_done,

    /*
     * Interrupt interface
     */
    input  wire [3:0]                                    cfg_interrupt_msi_enable,
    input  wire [7:0]                                    cfg_interrupt_msi_vf_enable,
    input  wire [11:0]                                   cfg_interrupt_msi_mmenable,
    input  wire                                          cfg_interrupt_msi_mask_update,
    input  wire [31:0]                                   cfg_interrupt_msi_data,
    output wire [3:0]                                    cfg_interrupt_msi_select,
    output wire [31:0]                                   cfg_interrupt_msi_int,
    output wire [31:0]                                   cfg_interrupt_msi_pending_status,
    output wire                                          cfg_interrupt_msi_pending_status_data_enable,
    output wire [3:0]                                    cfg_interrupt_msi_pending_status_function_num,
    input  wire                                          cfg_interrupt_msi_sent,
    input  wire                                          cfg_interrupt_msi_fail,
    output wire [2:0]                                    cfg_interrupt_msi_attr,
    output wire                                          cfg_interrupt_msi_tph_present,
    output wire [1:0]                                    cfg_interrupt_msi_tph_type,
    output wire [8:0]                                    cfg_interrupt_msi_tph_st_tag,
    output wire [3:0]                                    cfg_interrupt_msi_function_number,

    /*
     * TLP output (request to BAR)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   rx_req_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    rx_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]                    rx_req_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]                    rx_req_tlp_func_num,
    output wire [TLP_SEG_COUNT-1:0]                      rx_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      rx_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      rx_req_tlp_eop,
    input  wire                                          rx_req_tlp_ready,

    /*
     * TLP output (completion to DMA)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   rx_cpl_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    rx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT*4-1:0]                    rx_cpl_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_eop,
    input  wire                                          rx_cpl_tlp_ready,

    /*
     * TLP input (read request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    tx_rd_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_rd_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_eop,
    output wire                                          tx_rd_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA read request)
     */
    output wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  m_axis_rd_req_tx_seq_num,
    output wire [TX_SEQ_NUM_COUNT-1:0]                   m_axis_rd_req_tx_seq_num_valid,

    /*
     * TLP input (write request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   tx_wr_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   tx_wr_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    tx_wr_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_wr_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_eop,
    output wire                                          tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA write request)
     */
    output wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  m_axis_wr_req_tx_seq_num,
    output wire [TX_SEQ_NUM_COUNT-1:0]                   m_axis_wr_req_tx_seq_num_valid,

    /*
     * TLP input (completion from BAR)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   tx_cpl_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   tx_cpl_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    tx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_cpl_tlp_eop,
    output wire                                          tx_cpl_tlp_ready,

    /*
     * Flow control
     */
    output wire [7:0]                                    tx_fc_ph_av,
    output wire [11:0]                                   tx_fc_pd_av,
    output wire [7:0]                                    tx_fc_nph_av,
    output wire [11:0]                                   tx_fc_npd_av,
    output wire [7:0]                                    tx_fc_cplh_av,
    output wire [11:0]                                   tx_fc_cpld_av,

    /*
     * Configuration outputs
     */
    output wire [F_COUNT-1:0]                            ext_tag_enable,
    output wire [F_COUNT*3-1:0]                          max_read_request_size,
    output wire [F_COUNT*3-1:0]                          max_payload_size,

    /*
     * MSI request inputs
     */
    input  wire [MSI_COUNT-1:0]                          msi_irq
);

pcie_us_if_rc #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH)
)
pcie_us_if_rc_inst
(
    .clk(clk),
    .rst(rst),

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

pcie_us_if_rq #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH)
)
pcie_us_if_rq_inst
(
    .clk(clk),
    .rst(rst),

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
     * Transmit sequence number input
     */
    .s_axis_rq_seq_num_0(s_axis_rq_seq_num_0),
    .s_axis_rq_seq_num_valid_0(s_axis_rq_seq_num_valid_0),
    .s_axis_rq_seq_num_1(s_axis_rq_seq_num_1),
    .s_axis_rq_seq_num_valid_1(s_axis_rq_seq_num_valid_1),

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
    .m_axis_wr_req_tx_seq_num_valid(m_axis_wr_req_tx_seq_num_valid)
);

pcie_us_if_cq #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CQ_USER_WIDTH(AXIS_PCIE_CQ_USER_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH)
)
pcie_us_if_cq_inst
(
    .clk(clk),
    .rst(rst),

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
     * TLP output (request to BAR)
     */
    .rx_req_tlp_data(rx_req_tlp_data),
    .rx_req_tlp_hdr(rx_req_tlp_hdr),
    .rx_req_tlp_bar_id(rx_req_tlp_bar_id),
    .rx_req_tlp_func_num(rx_req_tlp_func_num),
    .rx_req_tlp_valid(rx_req_tlp_valid),
    .rx_req_tlp_sop(rx_req_tlp_sop),
    .rx_req_tlp_eop(rx_req_tlp_eop),
    .rx_req_tlp_ready(rx_req_tlp_ready)
);

pcie_us_if_cc #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_CC_USER_WIDTH(AXIS_PCIE_CC_USER_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH)
)
pcie_us_if_cc_inst
(
    .clk(clk),
    .rst(rst),

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

assign tx_fc_ph_av = cfg_fc_ph;
assign tx_fc_pd_av = cfg_fc_pd;
assign tx_fc_nph_av = cfg_fc_nph;
assign tx_fc_npd_av = cfg_fc_npd;
assign tx_fc_cplh_av = cfg_fc_cplh;
assign tx_fc_cpld_av = cfg_fc_cpld;

assign cfg_fc_sel = 3'b100;

generate

if (READ_EXT_TAG_ENABLE || READ_MAX_READ_REQ_SIZE || READ_MAX_PAYLOAD_SIZE) begin

    pcie_us_cfg #(
        .PF_COUNT(PF_COUNT),
        .VF_COUNT(VF_COUNT),
        .VF_OFFSET(AXIS_PCIE_RQ_USER_WIDTH == 60 ? 64 : 4),
        .PCIE_CAP_OFFSET(AXIS_PCIE_RQ_USER_WIDTH == 60 ? 12'h0C0 : 12'h070)
    )
    pcie_us_cfg_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Configuration outputs
         */
        .ext_tag_enable(ext_tag_enable),
        .max_read_request_size(max_read_request_size),
        .max_payload_size(max_payload_size),

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

end else begin

    assign ext_tag_enable = 0;
    assign max_read_request_size = 0;
    assign max_payload_size = 0;

    assign cfg_mgmt_addr = 0;
    assign cfg_mgmt_function_number = 0;
    assign cfg_mgmt_write = 0;
    assign cfg_mgmt_write_data = 0;
    assign cfg_mgmt_byte_enable = 0;
    assign cfg_mgmt_read = 0;

end

if (MSI_ENABLE) begin
    
    pcie_us_msi #(
        .MSI_COUNT(MSI_COUNT)
    )
    pcie_us_msi_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Interrupt request inputs
         */
        .msi_irq(msi_irq),

        /*
         * Interface to Ultrascale PCIe IP core
         */
        .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
        .cfg_interrupt_msi_vf_enable(cfg_interrupt_msi_vf_enable),
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

end else begin

    assign cfg_interrupt_msi_select = 0;
    assign cfg_interrupt_msi_int = 0;
    assign cfg_interrupt_msi_pending_status = 0;
    assign cfg_interrupt_msi_pending_status_data_enable = 0;
    assign cfg_interrupt_msi_pending_status_function_num = 0;
    assign cfg_interrupt_msi_attr = 0;
    assign cfg_interrupt_msi_tph_present = 0;
    assign cfg_interrupt_msi_tph_type = 0;
    assign cfg_interrupt_msi_tph_st_tag = 0;
    assign cfg_interrupt_msi_function_number = 0;

end

endgenerate

endmodule

`resetall
