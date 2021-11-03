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
 * PCIe DMA read interface
 */
module dma_if_pcie_rd #
(
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = 256,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // TX sequence number count
    parameter TX_SEQ_NUM_COUNT = 1,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 6,
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
    // Operation table size
    parameter OP_TABLE_SIZE = PCIE_TAG_COUNT,
    // In-flight transmit limit
    parameter TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // Transmit flow control
    parameter TX_FC_ENABLE = 0,
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
     * Transmit sequence number input
     */
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_tx_seq_num_valid,

    /*
     * Transmit flow control
     */
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
     * RAM interface
     */
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
    input  wire                                          enable,
    input  wire                                          ext_tag_enable,
    input  wire [15:0]                                   requester_id,
    input  wire [2:0]                                    max_read_request_size,

    /*
     * Status
     */
    output wire                                          status_error_cor,
    output wire                                          status_error_uncor,

    /*
     * Statistics
     */
    output wire [$clog2(OP_TABLE_SIZE)-1:0]              stat_rd_op_start_tag,
    output wire [LEN_WIDTH-1:0]                          stat_rd_op_start_len,
    output wire                                          stat_rd_op_start_valid,
    output wire [$clog2(OP_TABLE_SIZE)-1:0]              stat_rd_op_finish_tag,
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
    output wire                                          stat_rd_tx_stall
);

parameter RAM_DATA_WIDTH = RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH;
parameter RAM_WORD_WIDTH = RAM_SEG_BE_WIDTH;
parameter RAM_WORD_SIZE = RAM_SEG_DATA_WIDTH/RAM_WORD_WIDTH;

parameter TLP_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH;
parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter OFFSET_WIDTH = $clog2(TLP_DATA_WIDTH_BYTES);
parameter RAM_OFFSET_WIDTH = $clog2(RAM_DATA_WIDTH/8);

parameter PCIE_TAG_WIDTH = $clog2(PCIE_TAG_COUNT);
parameter PCIE_TAG_COUNT_1 = 2**PCIE_TAG_WIDTH > 32 ? 32 : 2**PCIE_TAG_WIDTH;
parameter PCIE_TAG_WIDTH_1 = $clog2(PCIE_TAG_COUNT_1);
parameter PCIE_TAG_COUNT_2 = 2**PCIE_TAG_WIDTH > 32 ? 2**PCIE_TAG_WIDTH-32 : 0;
parameter PCIE_TAG_WIDTH_2 = $clog2(PCIE_TAG_COUNT_2);

parameter OP_TAG_WIDTH = $clog2(OP_TABLE_SIZE);
parameter OP_TABLE_READ_COUNT_WIDTH = PCIE_TAG_WIDTH+1;

parameter TX_COUNT_WIDTH = $clog2(TX_LIMIT+1);

parameter STATUS_FIFO_ADDR_WIDTH = 5;
parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

parameter INIT_COUNT_WIDTH = PCIE_TAG_WIDTH > OP_TAG_WIDTH ? PCIE_TAG_WIDTH : OP_TAG_WIDTH;

// bus width assertions
initial begin
    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_SEG_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end

    if (TX_SEQ_NUM_ENABLE && TX_LIMIT > 2**TX_SEQ_NUM_WIDTH) begin
        $error("Error: TX limit out of range (instance %m)");
        $finish;
    end

    if (RAM_SEG_COUNT < 2) begin
        $error("Error: RAM interface requires at least 2 segments (instance %m)");
        $finish;
    end

    if (RAM_DATA_WIDTH != TLP_DATA_WIDTH*2) begin
        $error("Error: RAM interface width must be double the PCIe interface width (instance %m)");
        $finish;
    end

    if (RAM_SEG_BE_WIDTH * 8 != RAM_SEG_DATA_WIDTH) begin
        $error("Error: RAM interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (2**$clog2(RAM_WORD_WIDTH) != RAM_WORD_WIDTH) begin
        $error("Error: RAM word width must be even power of two (instance %m)");
        $finish;
    end

    if (RAM_ADDR_WIDTH != RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH)) begin
        $error("Error: RAM_ADDR_WIDTH does not match RAM configuration (instance %m)");
        $finish;
    end

    if (PCIE_TAG_COUNT < 1 || PCIE_TAG_COUNT > 256) begin
        $error("Error: PCIe tag count must be between 1 and 256 (instance %m)");
        $finish;
    end
end

localparam [2:0]
    TLP_FMT_3DW = 3'b000,
    TLP_FMT_4DW = 3'b001,
    TLP_FMT_3DW_DATA = 3'b010,
    TLP_FMT_4DW_DATA = 3'b011,
    TLP_FMT_PREFIX = 3'b100;

localparam [2:0]
    CPL_STATUS_SC  = 3'b000, // successful completion
    CPL_STATUS_UR  = 3'b001, // unsupported request
    CPL_STATUS_CRS = 3'b010, // configuration request retry status
    CPL_STATUS_CA  = 3'b100; // completer abort

localparam [3:0]
    PCIE_ERROR_NONE = 4'd0,
    PCIE_ERROR_POISONED = 4'd1,
    PCIE_ERROR_BAD_STATUS = 4'd2,
    PCIE_ERROR_MISMATCH = 4'd3,
    PCIE_ERROR_INVALID_LEN = 4'd4,
    PCIE_ERROR_INVALID_ADDR = 4'd5,
    PCIE_ERROR_INVALID_TAG = 4'd6,
    PCIE_ERROR_FLR = 4'd8,
    PCIE_ERROR_TIMEOUT = 4'd15;

localparam [3:0]
    DMA_ERROR_NONE = 4'd0,
    DMA_ERROR_TIMEOUT = 4'd1,
    DMA_ERROR_PARITY = 4'd2,
    DMA_ERROR_AXI_RD_SLVERR = 4'd4,
    DMA_ERROR_AXI_RD_DECERR = 4'd5,
    DMA_ERROR_AXI_WR_SLVERR = 4'd6,
    DMA_ERROR_AXI_WR_DECERR = 4'd7,
    DMA_ERROR_PCIE_FLR = 4'd8,
    DMA_ERROR_PCIE_CPL_POISONED = 4'd9,
    DMA_ERROR_PCIE_CPL_STATUS_UR = 4'd10,
    DMA_ERROR_PCIE_CPL_STATUS_CA = 4'd11;

localparam [0:0]
    REQ_STATE_IDLE = 1'd0,
    REQ_STATE_START = 1'd1;

reg [0:0] req_state_reg = REQ_STATE_IDLE, req_state_next;

localparam [1:0]
    TLP_STATE_IDLE = 2'd0,
    TLP_STATE_WRITE = 2'd1,
    TLP_STATE_WAIT_END = 2'd2;

reg [1:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

// datapath control signals
reg last_cycle;

reg [3:0] first_be;
reg [3:0] last_be;
reg [10:0] dword_count;
reg req_last_tlp;
reg [PCIE_ADDR_WIDTH-1:0] req_pcie_addr;

reg [INIT_COUNT_WIDTH-1:0] init_count_reg = 0;
reg init_done_reg = 1'b0;
reg init_pcie_tag_reg = 1'b1;
reg init_op_tag_reg = 1'b1;

reg [PCIE_ADDR_WIDTH-1:0] req_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, req_pcie_addr_next;
reg [RAM_SEL_WIDTH-1:0] req_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, req_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] req_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, req_ram_addr_next;
reg [LEN_WIDTH-1:0] req_op_count_reg = {LEN_WIDTH{1'b0}}, req_op_count_next;
reg [12:0] req_tlp_count_reg = 13'd0, req_tlp_count_next;
reg req_zero_len_reg = 1'b0, req_zero_len_next;
reg [OP_TAG_WIDTH-1:0] req_op_tag_reg = {OP_TAG_WIDTH{1'b0}}, req_op_tag_next;
reg req_op_tag_valid_reg = 1'b0, req_op_tag_valid_next;
reg [PCIE_TAG_WIDTH-1:0] req_pcie_tag_reg = {PCIE_TAG_WIDTH{1'b0}}, req_pcie_tag_next;
reg req_pcie_tag_valid_reg = 1'b0, req_pcie_tag_valid_next;

reg [3:0] error_code_reg = 4'd0, error_code_next;
reg [RAM_SEL_WIDTH-1:0] ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] addr_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_next;
reg [RAM_ADDR_WIDTH-1:0] addr_delay_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_delay_next;
reg [10:0] op_dword_count_reg = 11'd0, op_dword_count_next;
reg [12:0] op_count_reg = 13'd0, op_count_next;
reg zero_len_reg = 1'b0, zero_len_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_0_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_0_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_1_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_1_next;
reg ram_wrap_reg = 1'b0, ram_wrap_next;
reg [OFFSET_WIDTH+1-1:0] cycle_byte_count_reg = {OFFSET_WIDTH+1{1'b0}}, cycle_byte_count_next;
reg [RAM_OFFSET_WIDTH-1:0] start_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, start_offset_next;
reg [RAM_OFFSET_WIDTH-1:0] end_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, end_offset_next;
reg [PCIE_TAG_WIDTH-1:0] pcie_tag_reg = {PCIE_TAG_WIDTH{1'b0}}, pcie_tag_next;
reg [OP_TAG_WIDTH-1:0] op_tag_reg = {OP_TAG_WIDTH{1'b0}}, op_tag_next;
reg final_cpl_reg = 1'b0, final_cpl_next;
reg finish_tag_reg = 1'b0, finish_tag_next;

reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;

reg [TLP_DATA_WIDTH-1:0] tlp_data_int_reg = 0, tlp_data_int_next;
reg tlp_data_valid_int_reg = 0, tlp_data_valid_int_next;

reg [2:0] rx_cpl_tlp_hdr_fmt;
reg [4:0] rx_cpl_tlp_hdr_type;
reg [2:0] rx_cpl_tlp_hdr_tc;
reg rx_cpl_tlp_hdr_ln;
reg rx_cpl_tlp_hdr_th;
reg rx_cpl_tlp_hdr_td;
reg rx_cpl_tlp_hdr_ep;
reg [2:0] rx_cpl_tlp_hdr_attr;
reg [1:0] rx_cpl_tlp_hdr_at;
reg [10:0] rx_cpl_tlp_hdr_length;
reg [15:0] rx_cpl_tlp_hdr_completer_id;
reg [2:0] rx_cpl_tlp_hdr_cpl_status;
reg rx_cpl_tlp_hdr_bcm;
reg [12:0] rx_cpl_tlp_hdr_byte_count;
reg [15:0] rx_cpl_tlp_hdr_requester_id;
reg [9:0] rx_cpl_tlp_hdr_tag;
reg [6:0] rx_cpl_tlp_hdr_lower_addr;

reg [127:0] tlp_hdr;

reg [10:0] max_read_request_size_dw_reg = 11'd0;

reg have_credit_reg = 1'b0;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_wr_ptr_reg = 0;
reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_rd_ptr_reg = 0, status_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [OP_TAG_WIDTH-1:0] status_fifo_op_tag[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_SEG_COUNT-1:0] status_fifo_mask[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg status_fifo_finish[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [3:0] status_fifo_error[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [OP_TAG_WIDTH-1:0] status_fifo_wr_op_tag;
reg [RAM_SEG_COUNT-1:0] status_fifo_wr_mask;
reg status_fifo_wr_finish;
reg [3:0] status_fifo_wr_error;
reg status_fifo_we;
reg status_fifo_mask_reg = 1'b0, status_fifo_mask_next;
reg status_fifo_finish_reg = 1'b0, status_fifo_finish_next;
reg [3:0] status_fifo_error_reg = 4'd0, status_fifo_error_next;
reg status_fifo_we_reg = 1'b0, status_fifo_we_next;
reg status_fifo_half_full_reg = 1'b0;
reg [OP_TAG_WIDTH-1:0] status_fifo_rd_op_tag_reg = 0, status_fifo_rd_op_tag_next;
reg [RAM_SEG_COUNT-1:0] status_fifo_rd_mask_reg = 0, status_fifo_rd_mask_next;
reg status_fifo_rd_finish_reg = 1'b0, status_fifo_rd_finish_next;
reg [3:0] status_fifo_rd_error_reg = 4'd0, status_fifo_rd_error_next;
reg status_fifo_rd_valid_reg = 1'b0, status_fifo_rd_valid_next;

reg [TX_COUNT_WIDTH-1:0] active_tx_count_reg = {TX_COUNT_WIDTH{1'b0}}, active_tx_count_next;
reg active_tx_count_av_reg = 1'b1, active_tx_count_av_next;
reg inc_active_tx;

reg rx_cpl_tlp_ready_reg = 1'b0, rx_cpl_tlp_ready_next;

reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0] tx_rd_req_tlp_hdr_reg = 0, tx_rd_req_tlp_hdr_next;
reg [TLP_SEG_COUNT-1:0] tx_rd_req_tlp_valid_reg = 0, tx_rd_req_tlp_valid_next;

reg s_axis_read_desc_ready_reg = 1'b0, s_axis_read_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_read_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_read_desc_status_tag_next;
reg [3:0] m_axis_read_desc_status_error_reg = 4'd0, m_axis_read_desc_status_error_next;
reg m_axis_read_desc_status_valid_reg = 1'b0, m_axis_read_desc_status_valid_next;

reg status_error_cor_reg = 1'b0, status_error_cor_next;
reg status_error_uncor_reg = 1'b0, status_error_uncor_next;

reg [OP_TAG_WIDTH-1:0] stat_rd_op_start_tag_reg = 0, stat_rd_op_start_tag_next;
reg [LEN_WIDTH-1:0] stat_rd_op_start_len_reg = 0, stat_rd_op_start_len_next;
reg stat_rd_op_start_valid_reg = 1'b0, stat_rd_op_start_valid_next;
reg [OP_TAG_WIDTH-1:0] stat_rd_op_finish_tag_reg = 0, stat_rd_op_finish_tag_next;
reg [3:0] stat_rd_op_finish_status_reg = 4'd0, stat_rd_op_finish_status_next;
reg stat_rd_op_finish_valid_reg = 1'b0, stat_rd_op_finish_valid_next;
reg [PCIE_TAG_WIDTH-1:0] stat_rd_req_start_tag_reg = 0, stat_rd_req_start_tag_next;
reg [12:0] stat_rd_req_start_len_reg = 13'd0, stat_rd_req_start_len_next;
reg stat_rd_req_start_valid_reg = 1'b0, stat_rd_req_start_valid_next;
reg [PCIE_TAG_WIDTH-1:0] stat_rd_req_finish_tag_reg = 0, stat_rd_req_finish_tag_next;
reg [3:0] stat_rd_req_finish_status_reg = 4'd0, stat_rd_req_finish_status_next;
reg stat_rd_req_finish_valid_reg = 1'b0, stat_rd_req_finish_valid_next;
reg stat_rd_req_timeout_reg = 1'b0, stat_rd_req_timeout_next;
reg stat_rd_op_table_full_reg = 1'b0, stat_rd_op_table_full_next;
reg stat_rd_no_tags_reg = 1'b0, stat_rd_no_tags_next;
reg stat_rd_tx_no_credit_reg = 1'b0, stat_rd_tx_no_credit_next;
reg stat_rd_tx_limit_reg = 1'b0, stat_rd_tx_limit_next;
reg stat_rd_tx_stall_reg = 1'b0, stat_rd_tx_stall_next;

// internal datapath
reg  [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]      ram_wr_cmd_sel_int = 0;
reg  [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_int = 0;
reg  [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_int = 0;
reg  [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_int = 0;
reg  [RAM_SEG_COUNT-1:0]                    ram_wr_cmd_valid_int = 0;
wire [RAM_SEG_COUNT-1:0]                    ram_wr_cmd_ready_int;

wire [RAM_SEG_COUNT-1:0] out_done;
reg [RAM_SEG_COUNT-1:0] out_done_ack;

assign rx_cpl_tlp_ready = rx_cpl_tlp_ready_reg;

assign tx_rd_req_tlp_hdr = tx_rd_req_tlp_hdr_reg;
assign tx_rd_req_tlp_seq = 0;
assign tx_rd_req_tlp_valid = tx_rd_req_tlp_valid_reg;
assign tx_rd_req_tlp_sop = 1'b1;
assign tx_rd_req_tlp_eop = 1'b1;

assign s_axis_read_desc_ready = s_axis_read_desc_ready_reg;

assign m_axis_read_desc_status_tag = m_axis_read_desc_status_tag_reg;
assign m_axis_read_desc_status_error = m_axis_read_desc_status_error_reg;
assign m_axis_read_desc_status_valid = m_axis_read_desc_status_valid_reg;

assign status_error_cor = status_error_cor_reg;
assign status_error_uncor = status_error_uncor_reg;

assign stat_rd_op_start_tag = stat_rd_op_start_tag_reg;
assign stat_rd_op_start_len = stat_rd_op_start_len_reg;
assign stat_rd_op_start_valid = stat_rd_op_start_valid_reg;
assign stat_rd_op_finish_tag = stat_rd_op_finish_tag_reg;
assign stat_rd_op_finish_status = stat_rd_op_finish_status_reg;
assign stat_rd_op_finish_valid = stat_rd_op_finish_valid_reg;
assign stat_rd_req_start_tag = stat_rd_req_start_tag_reg;
assign stat_rd_req_start_len = stat_rd_req_start_len_reg;
assign stat_rd_req_start_valid = stat_rd_req_start_valid_reg;
assign stat_rd_req_finish_tag = stat_rd_req_finish_tag_reg;
assign stat_rd_req_finish_status = stat_rd_req_finish_status_reg;
assign stat_rd_req_finish_valid = stat_rd_req_finish_valid_reg;
assign stat_rd_req_timeout = stat_rd_req_timeout_reg;
assign stat_rd_op_table_full = stat_rd_op_table_full_reg;
assign stat_rd_no_tags = stat_rd_no_tags_reg;
assign stat_rd_tx_no_credit = stat_rd_tx_no_credit_reg;
assign stat_rd_tx_limit = stat_rd_tx_limit_reg;
assign stat_rd_tx_stall = stat_rd_tx_stall_reg;

// PCIe tag management
reg [PCIE_TAG_WIDTH-1:0] pcie_tag_table_start_ptr_reg = 0, pcie_tag_table_start_ptr_next;
reg [RAM_SEL_WIDTH-1:0] pcie_tag_table_start_ram_sel_reg = 0, pcie_tag_table_start_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] pcie_tag_table_start_ram_addr_reg = 0, pcie_tag_table_start_ram_addr_next;
reg [OP_TAG_WIDTH-1:0] pcie_tag_table_start_op_tag_reg = 0, pcie_tag_table_start_op_tag_next;
reg pcie_tag_table_start_zero_len_reg = 1'b0, pcie_tag_table_start_zero_len_next;
reg pcie_tag_table_start_en_reg = 1'b0, pcie_tag_table_start_en_next;
reg [PCIE_TAG_WIDTH-1:0] pcie_tag_table_finish_ptr;
reg pcie_tag_table_finish_en;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_SEL_WIDTH-1:0] pcie_tag_table_ram_sel[(2**PCIE_TAG_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_ADDR_WIDTH-1:0] pcie_tag_table_ram_addr[(2**PCIE_TAG_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [OP_TAG_WIDTH-1:0] pcie_tag_table_op_tag[(2**PCIE_TAG_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg pcie_tag_table_zero_len[(2**PCIE_TAG_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg pcie_tag_table_active_a[(2**PCIE_TAG_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg pcie_tag_table_active_b[(2**PCIE_TAG_WIDTH)-1:0];

reg [PCIE_TAG_WIDTH-1:0] pcie_tag_fifo_wr_tag;

reg [PCIE_TAG_WIDTH_1+1-1:0] pcie_tag_fifo_1_wr_ptr_reg = 0;
reg [PCIE_TAG_WIDTH_1+1-1:0] pcie_tag_fifo_1_rd_ptr_reg = 0, pcie_tag_fifo_1_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [PCIE_TAG_WIDTH_1-1:0] pcie_tag_fifo_1_mem [2**PCIE_TAG_WIDTH_1-1:0];
reg pcie_tag_fifo_1_we;

reg [PCIE_TAG_WIDTH_2+1-1:0] pcie_tag_fifo_2_wr_ptr_reg = 0;
reg [PCIE_TAG_WIDTH_2+1-1:0] pcie_tag_fifo_2_rd_ptr_reg = 0, pcie_tag_fifo_2_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [PCIE_TAG_WIDTH-1:0] pcie_tag_fifo_2_mem [2**PCIE_TAG_WIDTH_2-1:0];
reg pcie_tag_fifo_2_we;

// operation tag management
reg [OP_TAG_WIDTH-1:0] op_table_start_ptr;
reg [TAG_WIDTH-1:0] op_table_start_tag;
reg op_table_start_en;
reg [OP_TAG_WIDTH-1:0] op_table_read_start_ptr;
reg op_table_read_start_commit;
reg op_table_read_start_en;
reg [OP_TAG_WIDTH-1:0] op_table_update_status_ptr;
reg [3:0] op_table_update_status_error;
reg op_table_update_status_en;
reg [OP_TAG_WIDTH-1:0] op_table_read_finish_ptr;
reg op_table_read_finish_en;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [TAG_WIDTH-1:0] op_table_tag [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_read_init_a [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_read_init_b [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_read_commit [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [OP_TABLE_READ_COUNT_WIDTH-1:0] op_table_read_count_start [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [OP_TABLE_READ_COUNT_WIDTH-1:0] op_table_read_count_finish [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_error_a [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_error_b [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [3:0] op_table_error_code [2**OP_TAG_WIDTH-1:0];

reg [OP_TAG_WIDTH+1-1:0] op_tag_fifo_wr_ptr_reg = 0;
reg [OP_TAG_WIDTH+1-1:0] op_tag_fifo_rd_ptr_reg = 0, op_tag_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [OP_TAG_WIDTH-1:0] op_tag_fifo_mem [2**OP_TAG_WIDTH-1:0];
reg [OP_TAG_WIDTH-1:0] op_tag_fifo_wr_tag;
reg op_tag_fifo_we;

integer i;

initial begin
    for (i = 0; i < 2**OP_TAG_WIDTH; i = i + 1) begin
        op_table_tag[i] = 0;
        op_table_read_init_a[i] = 0;
        op_table_read_init_b[i] = 0;
        op_table_read_commit[i] = 0;
        op_table_read_count_start[i] = 0;
        op_table_read_count_finish[i] = 0;
        op_table_error_a[i] = 0;
        op_table_error_b[i] = 0;
        op_table_error_code[i] = 0;
    end

    for (i = 0; i < 2**PCIE_TAG_WIDTH; i = i + 1) begin
        pcie_tag_table_ram_sel[i] = 0;
        pcie_tag_table_ram_addr[i] = 0;
        pcie_tag_table_op_tag[i] = 0;
        pcie_tag_table_zero_len[i] = 0;
        pcie_tag_table_active_a[i] = 0;
        pcie_tag_table_active_b[i] = 0;
    end
end

always @* begin
    req_state_next = REQ_STATE_IDLE;

    s_axis_read_desc_ready_next = 1'b0;

    stat_rd_op_start_tag_next = stat_rd_op_start_tag_reg;
    stat_rd_op_start_len_next = stat_rd_op_start_len_reg;
    stat_rd_op_start_valid_next = 1'b0;
    stat_rd_req_start_tag_next = stat_rd_req_start_tag_reg;
    stat_rd_req_start_len_next = stat_rd_req_start_len_reg;
    stat_rd_req_start_valid_next = 1'b0;
    stat_rd_op_table_full_next = op_tag_fifo_rd_ptr_reg == op_tag_fifo_wr_ptr_reg;
    stat_rd_no_tags_next = !req_pcie_tag_valid_reg;
    stat_rd_tx_no_credit_next = !(!TX_FC_ENABLE || have_credit_reg);
    stat_rd_tx_limit_next = !(!TX_SEQ_NUM_ENABLE || active_tx_count_av_reg);
    stat_rd_tx_stall_next = !(!tx_rd_req_tlp_valid_reg || tx_rd_req_tlp_ready);

    req_pcie_addr_next = req_pcie_addr_reg;
    req_ram_sel_next = req_ram_sel_reg;
    req_ram_addr_next = req_ram_addr_reg;
    req_op_count_next = req_op_count_reg;
    req_tlp_count_next = req_tlp_count_reg;
    req_zero_len_next = req_zero_len_reg;
    req_op_tag_next = req_op_tag_reg;
    req_op_tag_valid_next = req_op_tag_valid_reg;
    req_pcie_tag_next = req_pcie_tag_reg;
    req_pcie_tag_valid_next = req_pcie_tag_valid_reg;

    inc_active_tx = 1'b0;

    op_table_start_ptr = req_op_tag_reg;
    op_table_start_tag = s_axis_read_desc_tag;
    op_table_start_en = 1'b0;

    op_table_read_start_ptr = req_op_tag_reg;
    op_table_read_start_commit = 1'b0;
    op_table_read_start_en = 1'b0;

    // TLP size computation
    if (req_op_count_reg + req_pcie_addr_reg[1:0] <= {max_read_request_size_dw_reg, 2'b00}) begin
        // packet smaller than max read request size
        if (((req_pcie_addr_reg & 12'hfff) + (req_op_count_reg & 12'hfff)) >> 12 != 0 || req_op_count_reg >> 12 != 0) begin
            // crosses 4k boundary, split on 4K boundary
            req_tlp_count_next = 13'h1000 - req_pcie_addr_reg[11:0];
            dword_count = 11'h400 - req_pcie_addr_reg[11:2];
            req_last_tlp = (((req_pcie_addr_reg & 12'hfff) + (req_op_count_reg & 12'hfff)) & 12'hfff) == 0 && req_op_count_reg >> 12 == 0;
            // optimized req_pcie_addr = req_pcie_addr_reg + req_tlp_count_next
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12]+1;
            req_pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            req_tlp_count_next = req_op_count_reg;
            dword_count = (req_op_count_reg + req_pcie_addr_reg[1:0] + 3) >> 2;
            req_last_tlp = 1'b1;
            // always last TLP, so next address is irrelevant
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12];
            req_pcie_addr[11:0] = 12'd0;
        end
    end else begin
        // packet larger than max read request size
        if (((req_pcie_addr_reg & 12'hfff) + {max_read_request_size_dw_reg, 2'b00}) >> 12 != 0) begin
            // crosses 4k boundary, split on 4K boundary
            req_tlp_count_next = 13'h1000 - req_pcie_addr_reg[11:0];
            dword_count = 11'h400 - req_pcie_addr_reg[11:2];
            req_last_tlp = 1'b0;
            // optimized req_pcie_addr = req_pcie_addr_reg + req_tlp_count_next
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12]+1;
            req_pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, split on 128-byte read completion boundary
            req_tlp_count_next = {max_read_request_size_dw_reg, 2'b00} - req_pcie_addr_reg[6:0];
            dword_count = max_read_request_size_dw_reg - req_pcie_addr_reg[6:2];
            req_last_tlp = 1'b0;
            // optimized req_pcie_addr = req_pcie_addr_reg + req_tlp_count_next
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12];
            req_pcie_addr[11:0] = {{req_pcie_addr_reg[11:7], 5'd0} + max_read_request_size_dw_reg, 2'b00};
        end
    end

    pcie_tag_table_start_ptr_next = req_pcie_tag_reg;
    pcie_tag_table_start_ram_sel_next = req_ram_sel_reg;
    pcie_tag_table_start_ram_addr_next = req_ram_addr_reg + req_tlp_count_next;
    pcie_tag_table_start_op_tag_next = req_op_tag_reg;
    pcie_tag_table_start_zero_len_next = req_zero_len_reg;
    pcie_tag_table_start_en_next = 1'b0;

    first_be = 4'b1111 << req_pcie_addr_reg[1:0];
    last_be = 4'b1111 >> (3 - ((req_pcie_addr_reg[1:0] + req_tlp_count_next[1:0] - 1) & 3));

    tx_rd_req_tlp_hdr_next = tx_rd_req_tlp_hdr_reg;
    tx_rd_req_tlp_valid_next = tx_rd_req_tlp_valid_reg && !tx_rd_req_tlp_ready;

    // TLP header
    // DW 0
    if (((req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:2] >> 30) != 0) || TLP_FORCE_64_BIT_ADDR) begin
        tlp_hdr[127:125] = TLP_FMT_4DW; // fmt - 4DW without data
    end else begin
        tlp_hdr[127:125] = TLP_FMT_3DW; // fmt - 3DW without data
    end
    tlp_hdr[124:120] = 5'b00000; // type - read
    tlp_hdr[119] = 1'b0; // T9
    tlp_hdr[118:116] = 3'b000; // TC
    tlp_hdr[115] = 1'b0; // T8
    tlp_hdr[114] = 1'b0; // attr
    tlp_hdr[113] = 1'b0; // LN
    tlp_hdr[112] = 1'b0; // TH
    tlp_hdr[111] = 1'b0; // TD
    tlp_hdr[110] = 1'b0; // EP
    tlp_hdr[109:108] = 2'b00; // attr
    tlp_hdr[107:106] = 3'b000; // AT
    tlp_hdr[105:96] = dword_count; // length
    // DW 1
    tlp_hdr[95:80] = requester_id; // requester ID
    tlp_hdr[79:72] = req_pcie_tag_reg; // tag
    tlp_hdr[71:68] = req_zero_len_reg ? 4'b0000 : (dword_count == 1 ? 4'b0000 : last_be); // last BE
    tlp_hdr[67:64] = req_zero_len_reg ? 4'b0000 : (dword_count == 1 ? first_be & last_be : first_be); // first BE
    if (((req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:2] >> 30) != 0) || TLP_FORCE_64_BIT_ADDR) begin
        // DW 2+3
        tlp_hdr[63:2] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:2]; // address
        tlp_hdr[1:0] = 2'b00; // PH
    end else begin
        // DW 2
        tlp_hdr[63:34] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:2]; // address
        tlp_hdr[33:32] = 2'b00; // PH
        // DW 3
        tlp_hdr[31:0] = 32'd0;
    end

    // TLP segmentation and request generation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            s_axis_read_desc_ready_next = init_done_reg && enable && req_op_tag_valid_reg;

            if (s_axis_read_desc_ready && s_axis_read_desc_valid) begin
                s_axis_read_desc_ready_next = 1'b0;
                req_ram_sel_next = s_axis_read_desc_ram_sel;
                req_pcie_addr_next = s_axis_read_desc_pcie_addr;
                req_ram_addr_next = s_axis_read_desc_ram_addr;
                if (s_axis_read_desc_len == 0) begin
                    // zero-length operation
                    req_op_count_next = 1;
                    req_zero_len_next = 1'b1;
                end else begin
                    req_op_count_next = s_axis_read_desc_len;
                    req_zero_len_next = 1'b0;
                end
                op_table_start_ptr = req_op_tag_reg;
                op_table_start_tag = s_axis_read_desc_tag;
                op_table_start_en = 1'b1;
                stat_rd_op_start_tag_next = req_op_tag_reg;
                stat_rd_op_start_len_next = s_axis_read_desc_len;
                stat_rd_op_start_valid_next = 1'b1;
                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            if (!tx_rd_req_tlp_valid_reg || tx_rd_req_tlp_ready) begin
                tx_rd_req_tlp_hdr_next = tlp_hdr;
            end

            if ((!tx_rd_req_tlp_valid_reg || tx_rd_req_tlp_ready) && req_pcie_tag_valid_reg && (!TX_FC_ENABLE || have_credit_reg) && (!TX_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                tx_rd_req_tlp_valid_next = 1'b1;

                inc_active_tx = 1'b1;

                req_pcie_addr_next = req_pcie_addr;
                req_ram_addr_next = req_ram_addr_reg + req_tlp_count_next;
                req_op_count_next = req_op_count_reg - req_tlp_count_next;

                pcie_tag_table_start_ptr_next = req_pcie_tag_reg;
                pcie_tag_table_start_ram_sel_next = req_ram_sel_reg;
                pcie_tag_table_start_ram_addr_next = req_ram_addr_reg + req_tlp_count_next;
                pcie_tag_table_start_op_tag_next = req_op_tag_reg;
                pcie_tag_table_start_zero_len_next = req_zero_len_reg;
                pcie_tag_table_start_en_next = 1'b1;

                op_table_read_start_ptr = req_op_tag_reg;
                op_table_read_start_commit = req_last_tlp;
                op_table_read_start_en = 1'b1;

                req_pcie_tag_valid_next = 1'b0;

                stat_rd_req_start_tag_next = req_pcie_tag_reg;
                stat_rd_req_start_len_next = req_tlp_count_next;
                stat_rd_req_start_valid_next = 1'b1;

                if (!req_last_tlp) begin
                    req_state_next = REQ_STATE_START;
                end else begin
                    req_op_tag_valid_next = 1'b0;
                    s_axis_read_desc_ready_next = init_done_reg && enable && (op_tag_fifo_rd_ptr_reg != op_tag_fifo_wr_ptr_reg);
                    req_state_next = REQ_STATE_IDLE;
                end
            end else begin
                req_state_next = REQ_STATE_START;
            end
        end
    endcase

    op_tag_fifo_rd_ptr_next = op_tag_fifo_rd_ptr_reg;

    if (!req_op_tag_valid_next) begin
        if (op_tag_fifo_rd_ptr_reg != op_tag_fifo_wr_ptr_reg) begin
            req_op_tag_next = op_tag_fifo_mem[op_tag_fifo_rd_ptr_reg[OP_TAG_WIDTH-1:0]];
            req_op_tag_valid_next = 1'b1;
            op_tag_fifo_rd_ptr_next = op_tag_fifo_rd_ptr_reg + 1;
        end
    end

    pcie_tag_fifo_1_rd_ptr_next = pcie_tag_fifo_1_rd_ptr_reg;
    pcie_tag_fifo_2_rd_ptr_next = pcie_tag_fifo_2_rd_ptr_reg;

    if (!req_pcie_tag_valid_next) begin
        if (pcie_tag_fifo_1_rd_ptr_reg != pcie_tag_fifo_1_wr_ptr_reg) begin
            req_pcie_tag_next = pcie_tag_fifo_1_mem[pcie_tag_fifo_1_rd_ptr_reg[PCIE_TAG_WIDTH_1-1:0]];
            req_pcie_tag_valid_next = 1'b1;
            pcie_tag_fifo_1_rd_ptr_next = pcie_tag_fifo_1_rd_ptr_reg + 1;
        end else if (PCIE_TAG_COUNT_2 > 0 && ext_tag_enable && pcie_tag_fifo_2_rd_ptr_reg != pcie_tag_fifo_2_wr_ptr_reg) begin
            req_pcie_tag_next = pcie_tag_fifo_2_mem[pcie_tag_fifo_2_rd_ptr_reg[PCIE_TAG_WIDTH_2-1:0]];
            req_pcie_tag_valid_next = 1'b1;
            pcie_tag_fifo_2_rd_ptr_next = pcie_tag_fifo_2_rd_ptr_reg + 1;
        end
    end
end

always @* begin
    tlp_state_next = TLP_STATE_IDLE;

    last_cycle = 1'b0;

    rx_cpl_tlp_ready_next = 1'b0;

    stat_rd_op_finish_tag_next = stat_rd_op_finish_tag_reg;
    stat_rd_op_finish_status_next = stat_rd_op_finish_status_reg;
    stat_rd_op_finish_valid_next = 1'b0;
    stat_rd_req_finish_tag_next = stat_rd_req_finish_tag_reg;
    stat_rd_req_finish_status_next = stat_rd_req_finish_status_reg;
    stat_rd_req_finish_valid_next = 1'b0;
    stat_rd_req_timeout_next = 1'b0;

    error_code_next = error_code_reg;
    ram_sel_next = ram_sel_reg;
    addr_next = addr_reg;
    addr_delay_next = addr_delay_reg;
    op_count_next = op_count_reg;
    zero_len_next = zero_len_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_0_next = ram_mask_0_reg;
    ram_mask_1_next = ram_mask_1_reg;
    ram_wrap_next = ram_wrap_reg;
    cycle_byte_count_next = cycle_byte_count_reg;
    start_offset_next = start_offset_reg;
    end_offset_next = end_offset_reg;
    op_dword_count_next = op_dword_count_reg;
    pcie_tag_next = pcie_tag_reg;
    op_tag_next = op_tag_reg;
    final_cpl_next = final_cpl_reg;
    finish_tag_next = 1'b0;
    offset_next = offset_reg;

    tlp_data_int_next = rx_cpl_tlp_data;
    tlp_data_valid_int_next = 1'b0;

    status_fifo_mask_next = 1'b1;
    status_fifo_finish_next = 1'b0;
    status_fifo_error_next = DMA_ERROR_NONE;
    status_fifo_we_next = 1'b0;

    out_done_ack = {RAM_SEG_COUNT{1'b0}};

    // Write generation
    ram_wr_cmd_sel_int = {RAM_SEG_COUNT{ram_sel_reg}};
    if (!ram_wrap_reg) begin
        ram_wr_cmd_be_int = ({RAM_SEG_COUNT*RAM_SEG_BE_WIDTH{1'b1}} << start_offset_reg) & ({RAM_SEG_COUNT*RAM_SEG_BE_WIDTH{1'b1}} >> (RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1-end_offset_reg));
    end else begin
        ram_wr_cmd_be_int = ({RAM_SEG_COUNT*RAM_SEG_BE_WIDTH{1'b1}} << start_offset_reg) | ({RAM_SEG_COUNT*RAM_SEG_BE_WIDTH{1'b1}} >> (RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1-end_offset_reg));
    end
    for (i = 0; i < RAM_SEG_COUNT; i = i + 1) begin
        ram_wr_cmd_addr_int[i*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH] = addr_delay_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-RAM_SEG_ADDR_WIDTH];
        if (ram_mask_1_reg[i]) begin
            ram_wr_cmd_addr_int[i*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH] = addr_delay_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-RAM_SEG_ADDR_WIDTH]+1;
        end
    end
    ram_wr_cmd_data_int = {3{tlp_data_int_reg}} >> (TLP_DATA_WIDTH - offset_reg*8);
    ram_wr_cmd_valid_int = {RAM_SEG_COUNT{1'b0}};

    if (tlp_data_valid_int_reg) begin
        ram_wr_cmd_valid_int = ram_mask_reg;
    end

    status_error_cor_next = 1'b0;
    status_error_uncor_next = 1'b0;

    // TLP header parsing
    // DW 0
    rx_cpl_tlp_hdr_fmt = rx_cpl_tlp_hdr[127:125]; // fmt
    rx_cpl_tlp_hdr_type = rx_cpl_tlp_hdr[124:120]; // type
    rx_cpl_tlp_hdr_tag[9] = rx_cpl_tlp_hdr[119]; // T9
    rx_cpl_tlp_hdr_tc = rx_cpl_tlp_hdr[118:116]; // TC
    rx_cpl_tlp_hdr_tag[8] = rx_cpl_tlp_hdr[115]; // T8
    rx_cpl_tlp_hdr_attr[2] = rx_cpl_tlp_hdr[114]; // attr
    rx_cpl_tlp_hdr_ln = rx_cpl_tlp_hdr[113]; // LN
    rx_cpl_tlp_hdr_th = rx_cpl_tlp_hdr[112]; // TH
    rx_cpl_tlp_hdr_td = rx_cpl_tlp_hdr[111]; // TD
    rx_cpl_tlp_hdr_ep = rx_cpl_tlp_hdr[110]; // EP
    rx_cpl_tlp_hdr_attr[1:0] = rx_cpl_tlp_hdr[109:108]; // attr
    rx_cpl_tlp_hdr_at = rx_cpl_tlp_hdr[107:106]; // AT
    rx_cpl_tlp_hdr_length = {rx_cpl_tlp_hdr[105:96] == 0, rx_cpl_tlp_hdr[105:96]}; // length
    // DW 1
    rx_cpl_tlp_hdr_completer_id = rx_cpl_tlp_hdr[95:80]; // completer ID
    rx_cpl_tlp_hdr_cpl_status = rx_cpl_tlp_hdr[79:77]; // completion status
    rx_cpl_tlp_hdr_bcm = rx_cpl_tlp_hdr[76]; // BCM
    rx_cpl_tlp_hdr_byte_count = {rx_cpl_tlp_hdr[75:64] == 0, rx_cpl_tlp_hdr[75:64]}; // byte count
    // DW 2
    rx_cpl_tlp_hdr_requester_id = rx_cpl_tlp_hdr[63:48]; // requester ID
    rx_cpl_tlp_hdr_tag[7:0] = rx_cpl_tlp_hdr[47:40]; // tag
    rx_cpl_tlp_hdr_lower_addr = rx_cpl_tlp_hdr[38:32]; // lower address

    // TLP response handling
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for completion
            rx_cpl_tlp_ready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

            if (rx_cpl_tlp_ready && rx_cpl_tlp_valid && rx_cpl_tlp_sop) begin
                op_dword_count_next = rx_cpl_tlp_hdr_length;
                pcie_tag_next = rx_cpl_tlp_hdr_tag;

                ram_sel_next = pcie_tag_table_ram_sel[pcie_tag_next];
                addr_next = pcie_tag_table_ram_addr[pcie_tag_next] - rx_cpl_tlp_hdr_byte_count;
                zero_len_next = pcie_tag_table_zero_len[pcie_tag_next];

                offset_next = addr_next[OFFSET_WIDTH-1:0] - rx_cpl_tlp_hdr_lower_addr[1:0];

                if (rx_cpl_tlp_hdr_byte_count > (op_dword_count_next << 2) - rx_cpl_tlp_hdr_lower_addr[1:0]) begin
                    // more completions to follow
                    op_count_next = (op_dword_count_next << 2) - rx_cpl_tlp_hdr_lower_addr[1:0];
                    final_cpl_next = 1'b0;

                    if (op_dword_count_next > TLP_DATA_WIDTH_DWORDS) begin
                        // more than one cycle
                        cycle_byte_count_next = TLP_DATA_WIDTH_BYTES-rx_cpl_tlp_hdr_lower_addr[1:0];
                        last_cycle = 1'b0;

                        start_offset_next = addr_next;
                        {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                    end else begin
                        // one cycle
                        cycle_byte_count_next = op_count_next;
                        last_cycle = 1'b1;

                        start_offset_next = addr_next;
                        {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                    end
                end else begin
                    // last completion
                    op_count_next = rx_cpl_tlp_hdr_byte_count;
                    final_cpl_next = 1'b1;

                    if (op_count_next > TLP_DATA_WIDTH_BYTES-rx_cpl_tlp_hdr_lower_addr[1:0]) begin
                        // more than one cycle
                        cycle_byte_count_next = TLP_DATA_WIDTH_BYTES-rx_cpl_tlp_hdr_lower_addr[1:0];
                        last_cycle = 1'b0;

                        start_offset_next = addr_next;
                        {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                    end else begin
                        // one cycle
                        cycle_byte_count_next = op_count_next;
                        last_cycle = 1'b1;

                        start_offset_next = addr_next;
                        {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                    end
                end

                ram_mask_0_next = {RAM_SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_WIDTH));
                ram_mask_1_next = {RAM_SEG_COUNT{1'b1}} >> (RAM_SEG_COUNT-1-(end_offset_next >> $clog2(RAM_SEG_BE_WIDTH)));

                if (!ram_wrap_next) begin
                    ram_mask_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_0_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_1_next = 0;
                end else begin
                    ram_mask_next = ram_mask_0_next | ram_mask_1_next;
                end

                addr_delay_next = addr_next;
                addr_next = addr_next + cycle_byte_count_next;
                op_count_next = op_count_next - cycle_byte_count_next;

                op_tag_next = pcie_tag_table_op_tag[pcie_tag_next];

                if ((rx_cpl_tlp_hdr_cpl_status == CPL_STATUS_SC && rx_cpl_tlp_hdr_fmt != TLP_FMT_3DW_DATA) ||
                        // (rx_cpl_tlp_hdr_requester_id & REQUESTER_ID_MASK) != (requester_id & REQUESTER_ID_MASK) ||
                        (CHECK_BUS_NUMBER ? rx_cpl_tlp_hdr_requester_id != requester_id : rx_cpl_tlp_hdr_requester_id[7:0] != requester_id[7:0]) ||
                        pcie_tag_table_active_b[pcie_tag_next] == pcie_tag_table_active_a[pcie_tag_next]) begin
                    // incorrect completion type, handle as unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                    // incorrect requester ID, handle as unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                    // tag not active, handle as unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)

                    // drop TLP and report correctable error
                    status_error_cor_next = 1'b1;
                    if (rx_cpl_tlp_eop) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        rx_cpl_tlp_ready_next = init_done_reg;
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else if ((rx_cpl_tlp_hdr_cpl_status != CPL_STATUS_SC && rx_cpl_tlp_hdr_fmt != TLP_FMT_3DW) ||
                        rx_cpl_tlp_hdr_attr != 3'b000 || rx_cpl_tlp_hdr_tc != 3'b000 || rx_cpl_tlp_error == PCIE_ERROR_MISMATCH) begin
                    // format/status mismatch, handle as malformed TLP (2.3.2)
                    // ATTR or TC mismatch, handle as malformed TLP (2.3.2)

                    // drop TLP and report uncorrectable error
                    status_error_uncor_next = 1'b1;
                    if (rx_cpl_tlp_eop) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        rx_cpl_tlp_ready_next = init_done_reg;
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else if (rx_cpl_tlp_hdr_ep || rx_cpl_tlp_error == PCIE_ERROR_POISONED ||
                        rx_cpl_tlp_hdr_cpl_status != CPL_STATUS_SC || rx_cpl_tlp_error == PCIE_ERROR_BAD_STATUS ||
                        rx_cpl_tlp_error == PCIE_ERROR_TIMEOUT || rx_cpl_tlp_error == PCIE_ERROR_FLR) begin
                    // transfer-terminating error

                    if (rx_cpl_tlp_hdr_ep || rx_cpl_tlp_error == PCIE_ERROR_POISONED) begin
                        // poisoned TLP, handle as advisory non-fatal (6.2.3.2.4.3)
                        // drop TLP and report correctable error
                        status_error_cor_next = 1'b1;
                        status_fifo_error_next = DMA_ERROR_PCIE_CPL_POISONED;
                    end else if (rx_cpl_tlp_hdr_cpl_status != CPL_STATUS_SC || rx_cpl_tlp_error == PCIE_ERROR_BAD_STATUS) begin
                        // bad status, handle as advisory non-fatal (6.2.3.2.4.1)
                        // drop TLP and report correctable error
                        status_error_cor_next = 1'b1;
                        if (rx_cpl_tlp_hdr_cpl_status == CPL_STATUS_CA) begin
                            status_fifo_error_next = DMA_ERROR_PCIE_CPL_STATUS_CA;
                        end else begin
                            status_fifo_error_next = DMA_ERROR_PCIE_CPL_STATUS_UR;
                        end
                    end else if (rx_cpl_tlp_error == PCIE_ERROR_TIMEOUT) begin
                        // timeout, handle as uncorrectable (6.2.3.2.4.4)
                        // drop TLP and report uncorrectable error
                        status_error_uncor_next = 1'b1;
                        status_fifo_error_next = DMA_ERROR_TIMEOUT;
                        stat_rd_req_timeout_next = 1'b1;
                    end else if (rx_cpl_tlp_error == PCIE_ERROR_FLR) begin
                        // FLR; not an actual completion so no error to report
                        // drop TLP
                        status_fifo_error_next = DMA_ERROR_PCIE_FLR;
                    end

                    finish_tag_next = 1'b1;

                    status_fifo_mask_next = 1'b0;
                    status_fifo_finish_next = 1'b1;
                    status_fifo_we_next = 1'b1;

                    stat_rd_req_finish_tag_next = pcie_tag_next;
                    stat_rd_req_finish_status_next = status_fifo_error_next;
                    stat_rd_req_finish_valid_next = 1'b1;

                    if (rx_cpl_tlp_eop) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        rx_cpl_tlp_ready_next = init_done_reg;
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else begin
                    // no error

                    if (zero_len_next) begin
                        status_fifo_mask_next = 1'b0;
                    end else begin
                        tlp_data_int_next = rx_cpl_tlp_data;
                        tlp_data_valid_int_next = 1'b1;

                        status_fifo_mask_next = 1'b1;
                    end

                    status_fifo_finish_next = 1'b0;
                    status_fifo_error_next = DMA_ERROR_NONE;
                    status_fifo_we_next = 1'b1;

                    stat_rd_req_finish_tag_next = pcie_tag_next;
                    stat_rd_req_finish_status_next = DMA_ERROR_NONE;

                    if (last_cycle) begin
                        if (final_cpl_next) begin
                            // last completion in current read request (PCIe tag)

                            // release tag
                            finish_tag_next = 1'b1;
                            status_fifo_finish_next = 1'b1;

                            stat_rd_req_finish_valid_next = 1'b1;
                        end
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        tlp_state_next = TLP_STATE_WRITE;
                    end
                end
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_WRITE: begin
            // write state - generate write operations
            rx_cpl_tlp_ready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

            if (rx_cpl_tlp_ready && rx_cpl_tlp_valid) begin
                tlp_data_int_next = rx_cpl_tlp_data;
                tlp_data_valid_int_next = 1'b1;

                if (op_count_next > TLP_DATA_WIDTH_BYTES) begin
                    // more cycles after this one
                    cycle_byte_count_next = TLP_DATA_WIDTH_BYTES;
                    last_cycle = 1'b0;
                end else begin
                    // last cycle
                    cycle_byte_count_next = op_count_next;
                    last_cycle = 1'b1;
                end
                start_offset_next = addr_next;
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                ram_mask_0_next = {RAM_SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_WIDTH));
                ram_mask_1_next = {RAM_SEG_COUNT{1'b1}} >> (RAM_SEG_COUNT-1-(end_offset_next >> $clog2(RAM_SEG_BE_WIDTH)));

                if (!ram_wrap_next) begin
                    ram_mask_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_0_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_1_next = 0;
                end else begin
                    ram_mask_next = ram_mask_0_next | ram_mask_1_next;
                end

                addr_delay_next = addr_reg;
                addr_next = addr_reg + cycle_byte_count_next;
                op_count_next = op_count_reg - cycle_byte_count_next;

                status_fifo_mask_next = 1'b1;
                status_fifo_finish_next = 1'b0;
                status_fifo_error_next = DMA_ERROR_NONE;
                status_fifo_we_next = 1'b1;

                stat_rd_req_finish_tag_next = pcie_tag_next;
                stat_rd_req_finish_status_next = DMA_ERROR_NONE;

                if (last_cycle || rx_cpl_tlp_eop) begin
                    if (final_cpl_reg) begin
                        // last completion in current read request (PCIe tag)

                        // release tag
                        finish_tag_next = 1'b1;
                        status_fifo_finish_next = 1'b1;

                        stat_rd_req_finish_valid_next = 1'b1;
                    end

                    if (rx_cpl_tlp_eop) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_WRITE;
                end
            end else begin
                tlp_state_next = TLP_STATE_WRITE;
            end
        end
        TLP_STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            rx_cpl_tlp_ready_next = init_done_reg;

            if (rx_cpl_tlp_ready && rx_cpl_tlp_valid) begin
                if (rx_cpl_tlp_eop) begin
                    rx_cpl_tlp_ready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;
                    tlp_state_next = TLP_STATE_IDLE;
                end else begin
                    tlp_state_next = TLP_STATE_WAIT_END;
                end
            end else begin
                tlp_state_next = TLP_STATE_WAIT_END;
            end
        end
    endcase

    pcie_tag_table_finish_ptr = pcie_tag_reg;
    pcie_tag_table_finish_en = 1'b0;

    pcie_tag_fifo_wr_tag = pcie_tag_reg;
    pcie_tag_fifo_1_we = 1'b0;
    pcie_tag_fifo_2_we = 1'b0;

    if (init_pcie_tag_reg) begin
        // initialize FIFO
        pcie_tag_fifo_wr_tag = init_count_reg;
        if (pcie_tag_fifo_wr_tag < PCIE_TAG_COUNT_1) begin
            pcie_tag_fifo_1_we = 1'b1;
        end else if (pcie_tag_fifo_wr_tag) begin
            pcie_tag_fifo_2_we = 1'b1;
        end
    end else if (finish_tag_reg) begin
        pcie_tag_table_finish_ptr = pcie_tag_reg;
        pcie_tag_table_finish_en = 1'b1;

        pcie_tag_fifo_wr_tag = pcie_tag_reg;
        if (pcie_tag_fifo_wr_tag < PCIE_TAG_COUNT_1) begin
            pcie_tag_fifo_1_we = 1'b1;
        end else begin
            pcie_tag_fifo_2_we = 1'b1;
        end
    end

    status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg;

    status_fifo_wr_op_tag = op_tag_reg;
    status_fifo_wr_mask = status_fifo_mask_reg ? ram_mask_reg : 0;
    status_fifo_wr_finish = status_fifo_finish_reg;
    status_fifo_wr_error = status_fifo_error_reg;
    status_fifo_we = 1'b0;

    if (status_fifo_we_reg) begin
        status_fifo_wr_op_tag = op_tag_reg;
        status_fifo_wr_mask = status_fifo_mask_reg ? ram_mask_reg : 0;
        status_fifo_wr_finish = status_fifo_finish_reg;
        status_fifo_wr_error = status_fifo_error_reg;
        status_fifo_we = 1'b1;
    end

    status_fifo_rd_op_tag_next = status_fifo_rd_op_tag_reg;
    status_fifo_rd_mask_next = status_fifo_rd_mask_reg;
    status_fifo_rd_finish_next = status_fifo_rd_finish_reg;
    status_fifo_rd_error_next = status_fifo_rd_error_reg;
    status_fifo_rd_valid_next = status_fifo_rd_valid_reg;

    m_axis_read_desc_status_tag_next = op_table_tag[status_fifo_rd_op_tag_reg];
    if (status_fifo_rd_error_reg != DMA_ERROR_NONE) begin
        m_axis_read_desc_status_error_next = status_fifo_rd_error_reg;
    end else if (op_table_error_a[status_fifo_rd_op_tag_reg] != op_table_error_b[status_fifo_rd_op_tag_reg]) begin
        m_axis_read_desc_status_error_next = op_table_error_code[status_fifo_rd_op_tag_reg];
    end else begin
        m_axis_read_desc_status_error_next = DMA_ERROR_NONE;
    end
    m_axis_read_desc_status_valid_next = 1'b0;

    op_table_update_status_ptr = status_fifo_rd_op_tag_reg;
    if (status_fifo_rd_error_reg != DMA_ERROR_NONE) begin
        op_table_update_status_error = status_fifo_rd_error_reg;
    end else begin
        op_table_update_status_error = DMA_ERROR_NONE;
    end
    op_table_update_status_en = 1'b0;

    op_table_read_finish_ptr = status_fifo_rd_op_tag_reg;
    op_table_read_finish_en = 1'b0;

    op_tag_fifo_wr_tag = status_fifo_rd_op_tag_reg;
    op_tag_fifo_we = 1'b0;

    stat_rd_op_finish_tag_next = status_fifo_rd_op_tag_reg;

    if (init_op_tag_reg) begin
        // initialize FIFO
        op_tag_fifo_wr_tag = init_count_reg;
        op_tag_fifo_we = 1'b1;
    end else if (status_fifo_rd_valid_reg && (status_fifo_rd_mask_reg & ~out_done) == 0) begin
        // got write completion, pop and return status
        status_fifo_rd_valid_next = 1'b0;
        op_table_update_status_en = 1'b1;

        out_done_ack = status_fifo_rd_mask_reg;

        stat_rd_op_finish_status_next = m_axis_read_desc_status_error_next;

        if (status_fifo_rd_finish_reg) begin
            // mark done
            op_table_read_finish_en = 1'b1;

            if (op_table_read_commit[op_table_read_finish_ptr] && (op_table_read_count_start[op_table_read_finish_ptr] == op_table_read_count_finish[op_table_read_finish_ptr])) begin
                op_tag_fifo_we = 1'b1;
                stat_rd_op_finish_valid_next = 1'b1;
                m_axis_read_desc_status_valid_next = 1'b1;
            end
        end
    end

    if (!status_fifo_rd_valid_next && status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin
        // status FIFO not empty
        status_fifo_rd_op_tag_next = status_fifo_op_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
        status_fifo_rd_mask_next = status_fifo_mask[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
        status_fifo_rd_finish_next = status_fifo_finish[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
        status_fifo_rd_error_next = status_fifo_error[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
        status_fifo_rd_valid_next = 1'b1;
        status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg + 1;
    end
end

integer j;

reg [1:0] active_tx_count_ovf;

always @* begin
    {active_tx_count_ovf, active_tx_count_next} = $signed({1'b0, active_tx_count_reg}) + $signed({1'b0, inc_active_tx});

    for (j = 0; j < TX_SEQ_NUM_COUNT; j = j + 1) begin
        {active_tx_count_ovf, active_tx_count_next} = $signed({active_tx_count_ovf, active_tx_count_next}) - $signed({1'b0, s_axis_tx_seq_num_valid[j]});
    end

    // saturate
    if (active_tx_count_ovf[1]) begin
        // sign bit set indicating underflow across zero; saturate to zero
        active_tx_count_next = {TX_COUNT_WIDTH{1'b0}};
    end else if (active_tx_count_ovf[0]) begin
        // sign bit clear but carry bit set indicating overflow; saturate to all 1
        active_tx_count_next = {TX_COUNT_WIDTH{1'b1}};
    end

    active_tx_count_av_next = active_tx_count_next < TX_LIMIT;
end

always @(posedge clk) begin
    req_state_reg <= req_state_next;
    tlp_state_reg <= tlp_state_next;

    if (!init_done_reg) begin
        {init_done_reg, init_count_reg} <= init_count_reg + 1;
        init_pcie_tag_reg <= init_count_reg + 1 < 2**PCIE_TAG_WIDTH;
        init_op_tag_reg <= init_count_reg + 1 < 2**OP_TAG_WIDTH;
    end

    req_pcie_addr_reg <= req_pcie_addr_next;
    req_ram_sel_reg <= req_ram_sel_next;
    req_ram_addr_reg <= req_ram_addr_next;
    req_op_count_reg <= req_op_count_next;
    req_tlp_count_reg <= req_tlp_count_next;
    req_zero_len_reg <= req_zero_len_next;
    req_op_tag_reg <= req_op_tag_next;
    req_op_tag_valid_reg <= req_op_tag_valid_next;
    req_pcie_tag_reg <= req_pcie_tag_next;
    req_pcie_tag_valid_reg <= req_pcie_tag_valid_next;

    error_code_reg <= error_code_next;
    ram_sel_reg <= ram_sel_next;
    addr_reg <= addr_next;
    addr_delay_reg <= addr_delay_next;
    op_count_reg <= op_count_next;
    zero_len_reg <= zero_len_next;
    ram_mask_reg <= ram_mask_next;
    ram_mask_0_reg <= ram_mask_0_next;
    ram_mask_1_reg <= ram_mask_1_next;
    ram_wrap_reg <= ram_wrap_next;
    cycle_byte_count_reg <= cycle_byte_count_next;
    start_offset_reg <= start_offset_next;
    end_offset_reg <= end_offset_next;
    op_dword_count_reg <= op_dword_count_next;
    pcie_tag_reg <= pcie_tag_next;
    op_tag_reg <= op_tag_next;
    final_cpl_reg <= final_cpl_next;
    finish_tag_reg <= finish_tag_next;

    offset_reg <= offset_next;

    tlp_data_int_reg <= tlp_data_int_next;
    tlp_data_valid_int_reg <= tlp_data_valid_int_next;

    tx_rd_req_tlp_hdr_reg <= tx_rd_req_tlp_hdr_next;
    tx_rd_req_tlp_valid_reg <= tx_rd_req_tlp_valid_next;

    rx_cpl_tlp_ready_reg <= rx_cpl_tlp_ready_next;

    s_axis_read_desc_ready_reg <= s_axis_read_desc_ready_next;

    m_axis_read_desc_status_tag_reg <= m_axis_read_desc_status_tag_next;
    m_axis_read_desc_status_error_reg <= m_axis_read_desc_status_error_next;
    m_axis_read_desc_status_valid_reg <= m_axis_read_desc_status_valid_next;

    status_error_cor_reg <= status_error_cor_next;
    status_error_uncor_reg <= status_error_uncor_next;

    stat_rd_op_start_tag_reg <= stat_rd_op_start_tag_next;
    stat_rd_op_start_len_reg <= stat_rd_op_start_len_next;
    stat_rd_op_start_valid_reg <= stat_rd_op_start_valid_next;
    stat_rd_op_finish_tag_reg <= stat_rd_op_finish_tag_next;
    stat_rd_op_finish_status_reg <= stat_rd_op_finish_status_next;
    stat_rd_op_finish_valid_reg <= stat_rd_op_finish_valid_next;
    stat_rd_req_start_tag_reg <= stat_rd_req_start_tag_next;
    stat_rd_req_start_len_reg <= stat_rd_req_start_len_next;
    stat_rd_req_start_valid_reg <= stat_rd_req_start_valid_next;
    stat_rd_req_finish_tag_reg <= stat_rd_req_finish_tag_next;
    stat_rd_req_finish_status_reg <= stat_rd_req_finish_status_next;
    stat_rd_req_finish_valid_reg <= stat_rd_req_finish_valid_next;
    stat_rd_req_timeout_reg <= stat_rd_req_timeout_next;
    stat_rd_op_table_full_reg <= stat_rd_op_table_full_next;
    stat_rd_no_tags_reg <= stat_rd_no_tags_next;
    stat_rd_tx_no_credit_reg <= stat_rd_tx_no_credit_next;
    stat_rd_tx_limit_reg <= stat_rd_tx_limit_next;
    stat_rd_tx_stall_reg <= stat_rd_tx_stall_next;

    max_read_request_size_dw_reg <= 11'd32 << (max_read_request_size > 5 ? 5 : max_read_request_size);

    have_credit_reg <= pcie_tx_fc_nph_av > 4;

    if (status_fifo_we) begin
        status_fifo_op_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_op_tag;
        status_fifo_mask[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_mask;
        status_fifo_finish[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_finish;
        status_fifo_error[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_error;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end
    status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_next;

    status_fifo_mask_reg <= status_fifo_mask_next;
    status_fifo_finish_reg <= status_fifo_finish_next;
    status_fifo_error_reg <= status_fifo_error_next;
    status_fifo_we_reg <= status_fifo_we_next;

    status_fifo_rd_op_tag_reg <= status_fifo_rd_op_tag_next;
    status_fifo_rd_mask_reg <= status_fifo_rd_mask_next;
    status_fifo_rd_finish_reg <= status_fifo_rd_finish_next;
    status_fifo_rd_error_reg <= status_fifo_rd_error_next;
    status_fifo_rd_valid_reg <= status_fifo_rd_valid_next;

    status_fifo_half_full_reg <= $unsigned(status_fifo_wr_ptr_reg - status_fifo_rd_ptr_reg) >= 2**(STATUS_FIFO_ADDR_WIDTH-1);

    active_tx_count_reg <= active_tx_count_next;
    active_tx_count_av_reg <= active_tx_count_av_next;

    pcie_tag_table_start_ptr_reg <= pcie_tag_table_start_ptr_next;
    pcie_tag_table_start_ram_sel_reg <= pcie_tag_table_start_ram_sel_next;
    pcie_tag_table_start_ram_addr_reg <= pcie_tag_table_start_ram_addr_next;
    pcie_tag_table_start_op_tag_reg <= pcie_tag_table_start_op_tag_next;
    pcie_tag_table_start_zero_len_reg <= pcie_tag_table_start_zero_len_next;
    pcie_tag_table_start_en_reg <= pcie_tag_table_start_en_next;

    if (init_pcie_tag_reg) begin
        pcie_tag_table_active_a[init_count_reg] <= 1'b0;
    end else if (pcie_tag_table_start_en_reg) begin
        pcie_tag_table_ram_sel[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_ram_sel_reg;
        pcie_tag_table_ram_addr[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_ram_addr_reg;
        pcie_tag_table_op_tag[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_op_tag_reg;
        pcie_tag_table_zero_len[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_zero_len_reg;
        pcie_tag_table_active_a[pcie_tag_table_start_ptr_reg] <= !pcie_tag_table_active_b[pcie_tag_table_start_ptr_reg];
    end

    if (init_pcie_tag_reg) begin
        pcie_tag_table_active_b[init_count_reg] <= 1'b0;
    end else if (pcie_tag_table_finish_en) begin
        pcie_tag_table_active_b[pcie_tag_table_finish_ptr] <= pcie_tag_table_active_a[pcie_tag_table_finish_ptr];
    end

    if (pcie_tag_fifo_1_we) begin
        pcie_tag_fifo_1_mem[pcie_tag_fifo_1_wr_ptr_reg[PCIE_TAG_WIDTH_1-1:0]] <= pcie_tag_fifo_wr_tag;
        pcie_tag_fifo_1_wr_ptr_reg <= pcie_tag_fifo_1_wr_ptr_reg + 1;
    end
    pcie_tag_fifo_1_rd_ptr_reg <= pcie_tag_fifo_1_rd_ptr_next;
    if (pcie_tag_fifo_2_we) begin
        pcie_tag_fifo_2_mem[pcie_tag_fifo_2_wr_ptr_reg[PCIE_TAG_WIDTH_2-1:0]] <= pcie_tag_fifo_wr_tag;
        pcie_tag_fifo_2_wr_ptr_reg <= pcie_tag_fifo_2_wr_ptr_reg + 1;
    end
    pcie_tag_fifo_2_rd_ptr_reg <= pcie_tag_fifo_2_rd_ptr_next;

    if (init_op_tag_reg) begin
        op_table_read_init_a[init_count_reg] <= 1'b0;
        op_table_error_a[init_count_reg] <= 1'b0;
    end else if (op_table_start_en) begin
        op_table_tag[op_table_start_ptr] <= op_table_start_tag;
        op_table_read_init_a[op_table_start_ptr] <= !op_table_read_init_b[op_table_start_ptr];
        op_table_error_a[op_table_start_ptr] <= op_table_error_b[op_table_start_ptr];
    end

    if (init_op_tag_reg) begin
        op_table_read_init_b[init_count_reg] <= 1'b0;
        op_table_read_count_start[init_count_reg] <= 0;
    end else if (op_table_read_start_en) begin
        op_table_read_init_b[op_table_read_start_ptr] <= op_table_read_init_a[op_table_read_start_ptr];
        op_table_read_commit[op_table_read_start_ptr] <= op_table_read_start_commit;
        if (op_table_read_init_b[op_table_read_start_ptr] != op_table_read_init_a[op_table_read_start_ptr]) begin
            op_table_read_count_start[op_table_read_start_ptr] <= op_table_read_count_finish[op_table_read_start_ptr];
        end else begin
            op_table_read_count_start[op_table_read_start_ptr] <= op_table_read_count_start[op_table_read_start_ptr] + 1;
        end
    end

    if (init_op_tag_reg) begin
        op_table_error_b[init_count_reg] <= 1'b0;
    end else if (op_table_update_status_en) begin
        if (op_table_update_status_error != 0) begin
            op_table_error_code[op_table_update_status_ptr] <= op_table_update_status_error;
            op_table_error_b[op_table_update_status_ptr] <= !op_table_error_a[op_table_update_status_ptr];
        end
    end

    if (init_op_tag_reg) begin
        op_table_read_count_finish[init_count_reg] <= 0;
    end else if (op_table_read_finish_en) begin
        op_table_read_count_finish[op_table_read_finish_ptr] <= op_table_read_count_finish[op_table_read_finish_ptr] + 1;
    end

    if (op_tag_fifo_we) begin
        op_tag_fifo_mem[op_tag_fifo_wr_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_tag_fifo_wr_tag;
        op_tag_fifo_wr_ptr_reg <= op_tag_fifo_wr_ptr_reg + 1;
    end
    op_tag_fifo_rd_ptr_reg <= op_tag_fifo_rd_ptr_next;

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;

        init_count_reg <= 0;
        init_done_reg <= 1'b0;
        init_pcie_tag_reg <= 1'b1;
        init_op_tag_reg <= 1'b1;

        req_op_tag_valid_reg <= 1'b0;
        req_pcie_tag_valid_reg <= 1'b0;

        finish_tag_reg <= 1'b0;

        tlp_data_valid_int_reg <= 1'b0;

        rx_cpl_tlp_ready_reg <= 1'b0;

        tx_rd_req_tlp_valid_reg <= 0;

        s_axis_read_desc_ready_reg <= 1'b0;

        m_axis_read_desc_status_valid_reg <= 1'b0;

        status_error_cor_reg <= 1'b0;
        status_error_uncor_reg <= 1'b0;

        stat_rd_op_start_valid_reg <= 1'b0;
        stat_rd_op_finish_valid_reg <= 1'b0;
        stat_rd_req_start_valid_reg <= 1'b0;
        stat_rd_req_finish_valid_reg <= 1'b0;
        stat_rd_req_timeout_reg <= 1'b0;
        stat_rd_op_table_full_reg <= 1'b0;
        stat_rd_no_tags_reg <= 1'b0;
        stat_rd_tx_no_credit_reg <= 1'b0;
        stat_rd_tx_limit_reg <= 1'b0;
        stat_rd_tx_stall_reg <= 1'b0;

        status_fifo_wr_ptr_reg <= 0;
        status_fifo_rd_ptr_reg <= 0;
        status_fifo_we_reg <= 1'b0;
        status_fifo_rd_valid_reg <= 1'b0;

        active_tx_count_reg <= {TX_COUNT_WIDTH{1'b0}};
        active_tx_count_av_reg <= 1'b1;

        pcie_tag_table_start_en_reg <= 1'b0;

        pcie_tag_fifo_1_wr_ptr_reg <= 0;
        pcie_tag_fifo_1_rd_ptr_reg <= 0;
        pcie_tag_fifo_2_wr_ptr_reg <= 0;
        pcie_tag_fifo_2_rd_ptr_reg <= 0;

        op_tag_fifo_wr_ptr_reg <= 0;
        op_tag_fifo_rd_ptr_reg <= 0;
    end
end

// output datapath logic (write data)
generate

genvar n;

for (n = 0; n < RAM_SEG_COUNT; n = n + 1) begin

    reg [RAM_SEL_WIDTH-1:0]      ram_wr_cmd_sel_reg = {RAM_SEL_WIDTH{1'b0}};
    reg [RAM_SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_reg = {RAM_SEG_BE_WIDTH{1'b0}};
    reg [RAM_SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_reg = {RAM_SEG_ADDR_WIDTH{1'b0}};
    reg [RAM_SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_reg = {RAM_SEG_DATA_WIDTH{1'b0}};
    reg                          ram_wr_cmd_valid_reg = 1'b0;

    reg [OUTPUT_FIFO_ADDR_WIDTH-1:0] out_fifo_wr_ptr_reg = 0;
    reg [OUTPUT_FIFO_ADDR_WIDTH-1:0] out_fifo_rd_ptr_reg = 0;
    reg out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [RAM_SEL_WIDTH-1:0]  out_fifo_wr_cmd_sel[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [RAM_SEG_BE_WIDTH-1:0]   out_fifo_wr_cmd_be[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [RAM_SEG_ADDR_WIDTH-1:0] out_fifo_wr_cmd_addr[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [RAM_SEG_DATA_WIDTH-1:0] out_fifo_wr_cmd_data[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] done_count_reg = 0;
    reg done_reg = 1'b0;

    assign ram_wr_cmd_ready_int[n +: 1] = !out_fifo_half_full_reg;

    assign ram_wr_cmd_sel[n*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = ram_wr_cmd_sel_reg;
    assign ram_wr_cmd_be[n*RAM_SEG_BE_WIDTH +: RAM_SEG_BE_WIDTH] = ram_wr_cmd_be_reg;
    assign ram_wr_cmd_addr[n*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH] = ram_wr_cmd_addr_reg;
    assign ram_wr_cmd_data[n*RAM_SEG_DATA_WIDTH +: RAM_SEG_DATA_WIDTH] = ram_wr_cmd_data_reg;
    assign ram_wr_cmd_valid[n +: 1] = ram_wr_cmd_valid_reg;

    assign out_done[n] = done_reg;

    always @(posedge clk) begin
        ram_wr_cmd_valid_reg <= ram_wr_cmd_valid_reg && !ram_wr_cmd_ready[n +: 1];

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

        if (!out_fifo_full && ram_wr_cmd_valid_int[n +: 1]) begin
            out_fifo_wr_cmd_sel[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= ram_wr_cmd_sel_int[n*RAM_SEL_WIDTH +: RAM_SEL_WIDTH];
            out_fifo_wr_cmd_be[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= ram_wr_cmd_be_int[n*RAM_SEG_BE_WIDTH +: RAM_SEG_BE_WIDTH];
            out_fifo_wr_cmd_addr[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= ram_wr_cmd_addr_int[n*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH];
            out_fifo_wr_cmd_data[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= ram_wr_cmd_data_int[n*RAM_SEG_DATA_WIDTH +: RAM_SEG_DATA_WIDTH];
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!ram_wr_cmd_valid_reg || ram_wr_cmd_ready[n +: 1])) begin
            ram_wr_cmd_sel_reg <= out_fifo_wr_cmd_sel[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            ram_wr_cmd_be_reg <= out_fifo_wr_cmd_be[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            ram_wr_cmd_addr_reg <= out_fifo_wr_cmd_addr[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            ram_wr_cmd_data_reg <= out_fifo_wr_cmd_data[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            ram_wr_cmd_valid_reg <= 1'b1;
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (done_count_reg < 2**OUTPUT_FIFO_ADDR_WIDTH && ram_wr_done[n] && !out_done_ack[n]) begin
            done_count_reg <= done_count_reg + 1;
            done_reg <= 1;
        end else if (done_count_reg > 0 && !ram_wr_done[n] && out_done_ack[n]) begin
            done_count_reg <= done_count_reg - 1;
            done_reg <= done_count_reg > 1;
        end

        if (rst) begin
            out_fifo_wr_ptr_reg <= 0;
            out_fifo_rd_ptr_reg <= 0;
            ram_wr_cmd_valid_reg <= 1'b0;
            done_count_reg <= 0;
            done_reg <= 1'b0;
        end
    end

end

endgenerate

endmodule

`resetall
