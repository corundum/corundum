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
 * PCIe DMA interface
 */
module dma_if_pcie #
(
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = 256,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // TX sequence number count
    parameter TX_SEQ_NUM_COUNT = 1,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 5,
    // TX sequence number tracking enable
    parameter TX_SEQ_NUM_ENABLE = 0,
    // RAM segment count
    parameter RAM_SEG_COUNT = TLP_SEG_COUNT*2,
    // RAM segment data width
    parameter RAM_SEG_DATA_WIDTH = (TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH)*2/RAM_SEG_COUNT,
    // RAM segment address width
    parameter RAM_SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    // RAM select width
    parameter RAM_SEL_WIDTH = 2,
    // RAM address width
    parameter RAM_ADDR_WIDTH = RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH),
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // PCIe tag count
    parameter PCIE_TAG_COUNT = 256,
    // Length field width
    parameter LEN_WIDTH = 16,
    // Tag field width
    parameter TAG_WIDTH = 8,
    // Operation table size (read)
    parameter READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    // In-flight transmit limit (read)
    parameter READ_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // Transmit flow control (read)
    parameter READ_TX_FC_ENABLE = 0,
    // Operation table size (write)
    parameter WRITE_OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    // In-flight transmit limit (write)
    parameter WRITE_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // Transmit flow control (write)
    parameter WRITE_TX_FC_ENABLE = 0,
    // Force 64 bit address
    parameter TLP_FORCE_64_BIT_ADDR = 0,
    // Requester ID mash
    parameter CHECK_BUS_NUMBER = 1
)
(
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * TLP input (completion)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   rx_cpl_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    rx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT*4-1:0]                    rx_cpl_tlp_error,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_eop,
    output wire                                          rx_cpl_tlp_ready,

    /*
     * TLP output (read request)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    tx_rd_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_rd_req_tlp_seq,
    output wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_eop,
    input  wire                                          tx_rd_req_tlp_ready,

    /*
     * TLP output (write request)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   tx_wr_req_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   tx_wr_req_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    tx_wr_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_wr_req_tlp_seq,
    output wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_eop,
    input  wire                                          tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number input
     */
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_rd_req_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_rd_req_tx_seq_num_valid,
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_wr_req_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_wr_req_tx_seq_num_valid,

    /*
     * Transmit flow control
     */
    input  wire [7:0]                                    pcie_tx_fc_ph_av,
    input  wire [11:0]                                   pcie_tx_fc_pd_av,
    input  wire [7:0]                                    pcie_tx_fc_nph_av,

    /*
     * AXI read descriptor input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]                    s_axis_read_desc_pcie_addr,
    input  wire [RAM_SEL_WIDTH-1:0]                      s_axis_read_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]                     s_axis_read_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                          s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]                          s_axis_read_desc_tag,
    input  wire                                          s_axis_read_desc_valid,
    output wire                                          s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                          m_axis_read_desc_status_tag,
    output wire [3:0]                                    m_axis_read_desc_status_error,
    output wire                                          m_axis_read_desc_status_valid,

    /*
     * AXI write descriptor input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]                    s_axis_write_desc_pcie_addr,
    input  wire [RAM_SEL_WIDTH-1:0]                      s_axis_write_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]                     s_axis_write_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                          s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]                          s_axis_write_desc_tag,
    input  wire                                          s_axis_write_desc_valid,
    output wire                                          s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                          m_axis_write_desc_status_tag,
    output wire [3:0]                                    m_axis_write_desc_status_error,
    output wire                                          m_axis_write_desc_status_valid,

    /*
     * RAM interface
     */
    output wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]        ram_rd_cmd_sel,
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]   ram_rd_cmd_addr,
    output wire [RAM_SEG_COUNT-1:0]                      ram_rd_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                      ram_rd_cmd_ready,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]   ram_rd_resp_data,
    input  wire [RAM_SEG_COUNT-1:0]                      ram_rd_resp_valid,
    output wire [RAM_SEG_COUNT-1:0]                      ram_rd_resp_ready,
    output wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]        ram_wr_cmd_sel,
    output wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]     ram_wr_cmd_be,
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]   ram_wr_cmd_addr,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]   ram_wr_cmd_data,
    output wire [RAM_SEG_COUNT-1:0]                      ram_wr_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                      ram_wr_cmd_ready,
    input  wire [RAM_SEG_COUNT-1:0]                      ram_wr_done,

    /*
     * Configuration
     */
    input  wire                                          read_enable,
    input  wire                                          write_enable,
    input  wire                                          ext_tag_enable,
    input  wire [15:0]                                   requester_id,
    input  wire [2:0]                                    max_read_request_size,
    input  wire [2:0]                                    max_payload_size,

    /*
     * Status
     */
    output wire                                          status_error_cor,
    output wire                                          status_error_uncor,

    /*
     * Statistics
     */
    output wire [$clog2(READ_OP_TABLE_SIZE)-1:0]         stat_rd_op_start_tag,
    output wire [LEN_WIDTH-1:0]                          stat_rd_op_start_len,
    output wire                                          stat_rd_op_start_valid,
    output wire [$clog2(READ_OP_TABLE_SIZE)-1:0]         stat_rd_op_finish_tag,
    output wire [3:0]                                    stat_rd_op_finish_status,
    output wire                                          stat_rd_op_finish_valid,
    output wire [$clog2(PCIE_TAG_COUNT)-1:0]             stat_rd_req_start_tag,
    output wire [12:0]                                   stat_rd_req_start_len,
    output wire                                          stat_rd_req_start_valid,
    output wire [$clog2(PCIE_TAG_COUNT)-1:0]             stat_rd_req_finish_tag,
    output wire [3:0]                                    stat_rd_req_finish_status,
    output wire                                          stat_rd_req_finish_valid,
    output wire                                          stat_rd_req_timeout,
    output wire                                          stat_rd_op_table_full,
    output wire                                          stat_rd_no_tags,
    output wire                                          stat_rd_tx_no_credit,
    output wire                                          stat_rd_tx_limit,
    output wire                                          stat_rd_tx_stall,
    output wire [$clog2(WRITE_OP_TABLE_SIZE)-1:0]        stat_wr_op_start_tag,
    output wire [LEN_WIDTH-1:0]                          stat_wr_op_start_len,
    output wire                                          stat_wr_op_start_valid,
    output wire [$clog2(WRITE_OP_TABLE_SIZE)-1:0]        stat_wr_op_finish_tag,
    output wire [3:0]                                    stat_wr_op_finish_status,
    output wire                                          stat_wr_op_finish_valid,
    output wire [$clog2(WRITE_OP_TABLE_SIZE)-1:0]        stat_wr_req_start_tag,
    output wire [12:0]                                   stat_wr_req_start_len,
    output wire                                          stat_wr_req_start_valid,
    output wire [$clog2(WRITE_OP_TABLE_SIZE)-1:0]        stat_wr_req_finish_tag,
    output wire [3:0]                                    stat_wr_req_finish_status,
    output wire                                          stat_wr_req_finish_valid,
    output wire                                          stat_wr_op_table_full,
    output wire                                          stat_wr_tx_no_credit,
    output wire                                          stat_wr_tx_limit,
    output wire                                          stat_wr_tx_stall
);

dma_if_pcie_rd #(
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(TX_SEQ_NUM_ENABLE),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .OP_TABLE_SIZE(READ_OP_TABLE_SIZE),
    .TX_LIMIT(READ_TX_LIMIT),
    .TX_FC_ENABLE(READ_TX_FC_ENABLE),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR),
    .CHECK_BUS_NUMBER(CHECK_BUS_NUMBER)
)
dma_if_pcie_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (completion)
     */
    .rx_cpl_tlp_data(rx_cpl_tlp_data),
    .rx_cpl_tlp_hdr(rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(rx_cpl_tlp_ready),

    /*
     * TLP output (read request)
     */
    .tx_rd_req_tlp_hdr(tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(tx_rd_req_tlp_ready),

    /*
     * Transmit sequence number input
     */
    .s_axis_tx_seq_num(s_axis_rd_req_tx_seq_num),
    .s_axis_tx_seq_num_valid(s_axis_rd_req_tx_seq_num_valid),

    /*
     * Transmit flow control
     */
    .pcie_tx_fc_nph_av(pcie_tx_fc_nph_av),

    /*
     * AXI read descriptor input
     */
    .s_axis_read_desc_pcie_addr(s_axis_read_desc_pcie_addr),
    .s_axis_read_desc_ram_sel(s_axis_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(s_axis_read_desc_ram_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),

    /*
     * AXI read descriptor status output
     */
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_error(m_axis_read_desc_status_error),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel(ram_wr_cmd_sel),
    .ram_wr_cmd_be(ram_wr_cmd_be),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_valid(ram_wr_cmd_valid),
    .ram_wr_cmd_ready(ram_wr_cmd_ready),
    .ram_wr_done(ram_wr_done),

    /*
     * Configuration
     */
    .enable(read_enable),
    .ext_tag_enable(ext_tag_enable),
    .requester_id(requester_id),
    .max_read_request_size(max_read_request_size),

    /*
     * Status
     */
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor),

    /*
     * Statistics
     */
    .stat_rd_op_start_tag(stat_rd_op_start_tag),
    .stat_rd_op_start_len(stat_rd_op_start_len),
    .stat_rd_op_start_valid(stat_rd_op_start_valid),
    .stat_rd_op_finish_tag(stat_rd_op_finish_tag),
    .stat_rd_op_finish_status(stat_rd_op_finish_status),
    .stat_rd_op_finish_valid(stat_rd_op_finish_valid),
    .stat_rd_req_start_tag(stat_rd_req_start_tag),
    .stat_rd_req_start_len(stat_rd_req_start_len),
    .stat_rd_req_start_valid(stat_rd_req_start_valid),
    .stat_rd_req_finish_tag(stat_rd_req_finish_tag),
    .stat_rd_req_finish_status(stat_rd_req_finish_status),
    .stat_rd_req_finish_valid(stat_rd_req_finish_valid),
    .stat_rd_req_timeout(stat_rd_req_timeout),
    .stat_rd_op_table_full(stat_rd_op_table_full),
    .stat_rd_no_tags(stat_rd_no_tags),
    .stat_rd_tx_no_credit(stat_rd_tx_no_credit),
    .stat_rd_tx_limit(stat_rd_tx_limit),
    .stat_rd_tx_stall(stat_rd_tx_stall)
);

dma_if_pcie_wr #(
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(TX_SEQ_NUM_ENABLE),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .OP_TABLE_SIZE(WRITE_OP_TABLE_SIZE),
    .TX_LIMIT(WRITE_TX_LIMIT),
    .TX_FC_ENABLE(WRITE_TX_FC_ENABLE),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
dma_if_pcie_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP output (write request)
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
     * Transmit sequence number input
     */
    .s_axis_tx_seq_num(s_axis_wr_req_tx_seq_num),
    .s_axis_tx_seq_num_valid(s_axis_wr_req_tx_seq_num_valid),

    /*
     * Transmit flow control
     */
    .pcie_tx_fc_ph_av(pcie_tx_fc_ph_av),
    .pcie_tx_fc_pd_av(pcie_tx_fc_pd_av),

    /*
     * AXI write descriptor input
     */
    .s_axis_write_desc_pcie_addr(s_axis_write_desc_pcie_addr),
    .s_axis_write_desc_ram_sel(s_axis_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(s_axis_write_desc_ram_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_error(m_axis_write_desc_status_error),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_rd_cmd_sel(ram_rd_cmd_sel),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_valid(ram_rd_cmd_valid),
    .ram_rd_cmd_ready(ram_rd_cmd_ready),
    .ram_rd_resp_data(ram_rd_resp_data),
    .ram_rd_resp_valid(ram_rd_resp_valid),
    .ram_rd_resp_ready(ram_rd_resp_ready),

    /*
     * Configuration
     */
    .enable(write_enable),
    .requester_id(requester_id),
    .max_payload_size(max_payload_size),

    /*
     * Statistics
     */
    .stat_wr_op_start_tag(stat_wr_op_start_tag),
    .stat_wr_op_start_len(stat_wr_op_start_len),
    .stat_wr_op_start_valid(stat_wr_op_start_valid),
    .stat_wr_op_finish_tag(stat_wr_op_finish_tag),
    .stat_wr_op_finish_status(stat_wr_op_finish_status),
    .stat_wr_op_finish_valid(stat_wr_op_finish_valid),
    .stat_wr_req_start_tag(stat_wr_req_start_tag),
    .stat_wr_req_start_len(stat_wr_req_start_len),
    .stat_wr_req_start_valid(stat_wr_req_start_valid),
    .stat_wr_req_finish_tag(stat_wr_req_finish_tag),
    .stat_wr_req_finish_status(stat_wr_req_finish_status),
    .stat_wr_req_finish_valid(stat_wr_req_finish_valid),
    .stat_wr_op_table_full(stat_wr_op_table_full),
    .stat_wr_tx_no_credit(stat_wr_tx_no_credit),
    .stat_wr_tx_limit(stat_wr_tx_limit),
    .stat_wr_tx_stall(stat_wr_tx_stall)
);

endmodule

`resetall
