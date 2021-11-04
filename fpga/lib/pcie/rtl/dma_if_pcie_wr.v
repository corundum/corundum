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
 * PCIe DMA write interface
 */
module dma_if_pcie_wr #
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
    // Length field width
    parameter LEN_WIDTH = 16,
    // Tag field width
    parameter TAG_WIDTH = 8,
    // Operation table size
    parameter OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    // In-flight transmit limit
    parameter TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // Transmit flow control
    parameter TX_FC_ENABLE = 0,
    // Force 64 bit address
    parameter TLP_FORCE_64_BIT_ADDR = 0
)
(
    input  wire                                          clk,
    input  wire                                          rst,

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
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_tx_seq_num_valid,

    /*
     * Transmit flow control
     */
    input  wire [7:0]                                    pcie_tx_fc_ph_av,
    input  wire [11:0]                                   pcie_tx_fc_pd_av,

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

    /*
     * Configuration
     */
    input  wire                                          enable,
    input  wire [15:0]                                   requester_id,
    input  wire [2:0]                                    max_payload_size,

    /*
     * Statistics
     */
    output wire [$clog2(OP_TABLE_SIZE)-1:0]              stat_wr_op_start_tag,
    output wire [LEN_WIDTH-1:0]                          stat_wr_op_start_len,
    output wire                                          stat_wr_op_start_valid,
    output wire [$clog2(OP_TABLE_SIZE)-1:0]              stat_wr_op_finish_tag,
    output wire [3:0]                                    stat_wr_op_finish_status,
    output wire                                          stat_wr_op_finish_valid,
    output wire [$clog2(OP_TABLE_SIZE)-1:0]              stat_wr_req_start_tag,
    output wire [12:0]                                   stat_wr_req_start_len,
    output wire                                          stat_wr_req_start_valid,
    output wire [$clog2(OP_TABLE_SIZE)-1:0]              stat_wr_req_finish_tag,
    output wire [3:0]                                    stat_wr_req_finish_status,
    output wire                                          stat_wr_req_finish_valid,
    output wire                                          stat_wr_op_table_full,
    output wire                                          stat_wr_tx_no_credit,
    output wire                                          stat_wr_tx_limit,
    output wire                                          stat_wr_tx_stall
);

parameter RAM_DATA_WIDTH = RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH;
parameter RAM_WORD_WIDTH = RAM_SEG_BE_WIDTH;
parameter RAM_WORD_SIZE = RAM_SEG_DATA_WIDTH/RAM_WORD_WIDTH;

parameter TLP_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH;
parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter OFFSET_WIDTH = $clog2(TLP_DATA_WIDTH_BYTES);
parameter RAM_OFFSET_WIDTH = $clog2(RAM_DATA_WIDTH/8);
parameter WORD_LEN_WIDTH = LEN_WIDTH - $clog2(TLP_DATA_WIDTH_DWORDS);
parameter CYCLE_COUNT_WIDTH = 13-$clog2(TLP_DATA_WIDTH_DWORDS*4);

parameter MASK_FIFO_ADDR_WIDTH = $clog2(OP_TABLE_SIZE)+1;

parameter OP_TAG_WIDTH = $clog2(OP_TABLE_SIZE);

parameter TX_COUNT_WIDTH = $clog2(TX_LIMIT+1);

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

    if (TLP_STRB_WIDTH*32 != TLP_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end

    if (TX_SEQ_NUM_ENABLE && OP_TABLE_SIZE > 2**TX_SEQ_NUM_WIDTH) begin
        $error("Error: Operation table size out of range (instance %m)");
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
end

localparam [2:0]
    TLP_FMT_3DW = 3'b000,
    TLP_FMT_4DW = 3'b001,
    TLP_FMT_3DW_DATA = 3'b010,
    TLP_FMT_4DW_DATA = 3'b011,
    TLP_FMT_PREFIX = 3'b100;

localparam [0:0]
    REQ_STATE_IDLE = 1'd0,
    REQ_STATE_START = 1'd1;

reg [0:0] req_state_reg = REQ_STATE_IDLE, req_state_next;

localparam [0:0]
    READ_STATE_IDLE = 1'd0,
    READ_STATE_READ = 1'd1;

reg [0:0] read_state_reg = READ_STATE_IDLE, read_state_next;

localparam [0:0]
    TLP_STATE_IDLE = 1'd0,
    TLP_STATE_TRANSFER = 1'd1;

reg [0:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

// datapath control signals
reg mask_fifo_we;

reg read_cmd_ready;

reg [PCIE_ADDR_WIDTH-1:0] pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, pcie_addr_next;
reg [RAM_SEL_WIDTH-1:0] ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, ram_addr_next;
reg [LEN_WIDTH-1:0] op_count_reg = {LEN_WIDTH{1'b0}}, op_count_next;
reg [LEN_WIDTH-1:0] tr_count_reg = {LEN_WIDTH{1'b0}}, tr_count_next;
reg [12:0] tlp_count_reg = 13'd0, tlp_count_next;
reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;
reg zero_len_reg = 1'b0, zero_len_next;

reg [PCIE_ADDR_WIDTH-1:0] read_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, read_pcie_addr_next;
reg [RAM_SEL_WIDTH-1:0] read_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, read_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] read_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, read_ram_addr_next;
reg [LEN_WIDTH-1:0] read_len_reg = {LEN_WIDTH{1'b0}}, read_len_next;
reg [RAM_SEG_COUNT-1:0] read_ram_mask_reg = {RAM_SEG_COUNT{1'b0}}, read_ram_mask_next;
reg [RAM_SEG_COUNT-1:0] read_ram_mask_0_reg = {RAM_SEG_COUNT{1'b0}}, read_ram_mask_0_next;
reg [RAM_SEG_COUNT-1:0] read_ram_mask_1_reg = {RAM_SEG_COUNT{1'b0}}, read_ram_mask_1_next;
reg ram_wrap_reg = 1'b0, ram_wrap_next;
reg [CYCLE_COUNT_WIDTH-1:0] read_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, read_cycle_count_next;
reg read_last_cycle_reg = 1'b0, read_last_cycle_next;
reg [OFFSET_WIDTH+1-1:0] cycle_byte_count_reg = {OFFSET_WIDTH+1{1'b0}}, cycle_byte_count_next;
reg [RAM_OFFSET_WIDTH-1:0] start_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, start_offset_next;
reg [RAM_OFFSET_WIDTH-1:0] end_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, end_offset_next;

reg [PCIE_ADDR_WIDTH-1:0] tlp_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, tlp_addr_next;
reg [11:0] tlp_len_reg = 12'd0, tlp_len_next;
reg tlp_zero_len_reg = 1'b0, tlp_zero_len_next;
reg [RAM_OFFSET_WIDTH-1:0] offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, offset_next;
reg [9:0] dword_count_reg = 10'd0, dword_count_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_next;
reg ram_mask_valid_reg = 1'b0, ram_mask_valid_next;
reg [CYCLE_COUNT_WIDTH-1:0] cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, cycle_count_next;
reg last_cycle_reg = 1'b0, last_cycle_next;
reg tlp_frame_reg = 1'b0, tlp_frame_next;

reg [PCIE_ADDR_WIDTH-1:0] read_cmd_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, read_cmd_pcie_addr_next;
reg [RAM_SEL_WIDTH-1:0] read_cmd_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, read_cmd_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] read_cmd_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, read_cmd_ram_addr_next;
reg [11:0] read_cmd_len_reg = 12'd0, read_cmd_len_next;
reg [CYCLE_COUNT_WIDTH-1:0] read_cmd_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, read_cmd_cycle_count_next;
reg read_cmd_last_cycle_reg = 1'b0, read_cmd_last_cycle_next;
reg read_cmd_valid_reg = 1'b0, read_cmd_valid_next;

reg [127:0] tlp_hdr;

reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_wr_ptr_reg = 0;
reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_rd_ptr_reg = 0, mask_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_SEG_COUNT-1:0] mask_fifo_mask[(2**MASK_FIFO_ADDR_WIDTH)-1:0];
reg [RAM_SEG_COUNT-1:0] mask_fifo_wr_mask;

wire mask_fifo_empty = mask_fifo_wr_ptr_reg == mask_fifo_rd_ptr_reg;
wire mask_fifo_full = mask_fifo_wr_ptr_reg == (mask_fifo_rd_ptr_reg ^ (1 << MASK_FIFO_ADDR_WIDTH));

reg [10:0] max_payload_size_dw_reg = 11'd0;

reg have_credit_reg = 1'b0;

reg [TX_COUNT_WIDTH-1:0] active_tx_count_reg = {TX_COUNT_WIDTH{1'b0}}, active_tx_count_next;
reg active_tx_count_av_reg = 1'b1, active_tx_count_av_next;
reg inc_active_tx;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0] tx_wr_req_tlp_data_reg = 0, tx_wr_req_tlp_data_next;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0] tx_wr_req_tlp_strb_reg = 0, tx_wr_req_tlp_strb_next;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0] tx_wr_req_tlp_hdr_reg = 0, tx_wr_req_tlp_hdr_next;
reg [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0] tx_wr_req_tlp_seq_reg = 0, tx_wr_req_tlp_seq_next;
reg [TLP_SEG_COUNT-1:0] tx_wr_req_tlp_valid_reg = 0, tx_wr_req_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0] tx_wr_req_tlp_sop_reg = 0, tx_wr_req_tlp_sop_next;
reg [TLP_SEG_COUNT-1:0] tx_wr_req_tlp_eop_reg = 0, tx_wr_req_tlp_eop_next;

reg s_axis_write_desc_ready_reg = 1'b0, s_axis_write_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_write_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_write_desc_status_tag_next;
reg m_axis_write_desc_status_valid_reg = 1'b0, m_axis_write_desc_status_valid_next;

reg [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0] ram_rd_cmd_sel_reg = 0, ram_rd_cmd_sel_next;
reg [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0] ram_rd_cmd_addr_reg = 0, ram_rd_cmd_addr_next;
reg [RAM_SEG_COUNT-1:0] ram_rd_cmd_valid_reg = 0, ram_rd_cmd_valid_next;
reg [RAM_SEG_COUNT-1:0] ram_rd_resp_ready_cmb;

reg [OP_TAG_WIDTH-1:0] stat_wr_op_start_tag_reg = 0, stat_wr_op_start_tag_next;
reg [LEN_WIDTH-1:0] stat_wr_op_start_len_reg = 0, stat_wr_op_start_len_next;
reg stat_wr_op_start_valid_reg = 1'b0, stat_wr_op_start_valid_next;
reg [OP_TAG_WIDTH-1:0] stat_wr_op_finish_tag_reg = 0, stat_wr_op_finish_tag_next;
reg stat_wr_op_finish_valid_reg = 1'b0, stat_wr_op_finish_valid_next;
reg [OP_TAG_WIDTH-1:0] stat_wr_req_start_tag_reg = 0, stat_wr_req_start_tag_next;
reg [12:0] stat_wr_req_start_len_reg = 13'd0, stat_wr_req_start_len_next;
reg stat_wr_req_start_valid_reg = 1'b0, stat_wr_req_start_valid_next;
reg [OP_TAG_WIDTH-1:0] stat_wr_req_finish_tag_reg = 0, stat_wr_req_finish_tag_next;
reg stat_wr_req_finish_valid_reg = 1'b0, stat_wr_req_finish_valid_next;
reg stat_wr_op_table_full_reg = 1'b0, stat_wr_op_table_full_next;
reg stat_wr_tx_no_credit_reg = 1'b0, stat_wr_tx_no_credit_next;
reg stat_wr_tx_limit_reg = 1'b0, stat_wr_tx_limit_next;
reg stat_wr_tx_stall_reg = 1'b0, stat_wr_tx_stall_next;

assign tx_wr_req_tlp_data = tx_wr_req_tlp_data_reg;
assign tx_wr_req_tlp_strb = tx_wr_req_tlp_strb_reg;
assign tx_wr_req_tlp_hdr = tx_wr_req_tlp_hdr_reg;
assign tx_wr_req_tlp_seq = tx_wr_req_tlp_seq_reg;
assign tx_wr_req_tlp_valid = tx_wr_req_tlp_valid_reg;
assign tx_wr_req_tlp_sop = tx_wr_req_tlp_sop_reg;
assign tx_wr_req_tlp_eop = tx_wr_req_tlp_eop_reg;

assign s_axis_write_desc_ready = s_axis_write_desc_ready_reg;

assign m_axis_write_desc_status_tag = m_axis_write_desc_status_tag_reg;
assign m_axis_write_desc_status_error = 4'd0;
assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

assign ram_rd_cmd_sel = ram_rd_cmd_sel_reg;
assign ram_rd_cmd_addr = ram_rd_cmd_addr_reg;
assign ram_rd_cmd_valid = ram_rd_cmd_valid_reg;
assign ram_rd_resp_ready = ram_rd_resp_ready_cmb;

assign stat_wr_op_start_tag = stat_wr_op_start_tag_reg;
assign stat_wr_op_start_len = stat_wr_op_start_len_reg;
assign stat_wr_op_start_valid = stat_wr_op_start_valid_reg;
assign stat_wr_op_finish_tag = stat_wr_op_finish_tag_reg;
assign stat_wr_op_finish_status = 4'd0;
assign stat_wr_op_finish_valid = stat_wr_op_finish_valid_reg;
assign stat_wr_req_start_tag = stat_wr_req_start_tag_reg;
assign stat_wr_req_start_len = stat_wr_req_start_len_reg;
assign stat_wr_req_start_valid = stat_wr_req_start_valid_reg;
assign stat_wr_req_finish_tag = stat_wr_req_finish_tag_reg;
assign stat_wr_req_finish_status = 4'd00;
assign stat_wr_req_finish_valid = stat_wr_req_finish_valid_reg;
assign stat_wr_op_table_full = stat_wr_op_table_full_reg;
assign stat_wr_tx_no_credit = stat_wr_tx_no_credit_reg;
assign stat_wr_tx_limit = stat_wr_tx_limit_reg;
assign stat_wr_tx_stall = stat_wr_tx_stall_reg;

// operation tag management
reg [OP_TAG_WIDTH+1-1:0] op_table_start_ptr_reg = 0;
reg [PCIE_ADDR_WIDTH-1:0] op_table_start_pcie_addr;
reg [11:0] op_table_start_len;
reg op_table_start_zero_len;
reg [9:0] op_table_start_dword_len;
reg [CYCLE_COUNT_WIDTH-1:0] op_table_start_cycle_count;
reg [RAM_OFFSET_WIDTH-1:0] op_table_start_offset;
reg [TAG_WIDTH-1:0] op_table_start_tag;
reg op_table_start_last;
reg op_table_start_en;
reg [OP_TAG_WIDTH+1-1:0] op_table_tx_start_ptr_reg = 0;
reg op_table_tx_start_en;
reg [OP_TAG_WIDTH+1-1:0] op_table_tx_finish_ptr_reg = 0;
reg op_table_tx_finish_en;
reg [OP_TAG_WIDTH+1-1:0] op_table_finish_ptr_reg = 0;
reg op_table_finish_en;

reg [2**OP_TAG_WIDTH-1:0] op_table_active = 0;
reg [2**OP_TAG_WIDTH-1:0] op_table_tx_done = 0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [PCIE_ADDR_WIDTH-1:0] op_table_pcie_addr[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [11:0] op_table_len[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_zero_len[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [9:0] op_table_dword_len[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [CYCLE_COUNT_WIDTH-1:0] op_table_cycle_count[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_OFFSET_WIDTH-1:0] op_table_offset[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [TAG_WIDTH-1:0] op_table_tag[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_last[2**OP_TAG_WIDTH-1:0];

integer i;

initial begin
    for (i = 0; i < 2**OP_TAG_WIDTH; i = i + 1) begin
        op_table_pcie_addr[i] = 0;
        op_table_len[i] = 0;
        op_table_zero_len[i] = 0;
        op_table_dword_len[i] = 0;
        op_table_cycle_count[i] = 0;
        op_table_offset[i] = 0;
        op_table_tag[i] = 0;
        op_table_last[i] = 0;
    end
end

always @* begin
    req_state_next = REQ_STATE_IDLE;

    s_axis_write_desc_ready_next = 1'b0;

    stat_wr_op_start_tag_next = stat_wr_op_start_tag_reg;
    stat_wr_op_start_len_next = stat_wr_op_start_len_reg;
    stat_wr_op_start_valid_next = 1'b0;
    stat_wr_req_start_tag_next = stat_wr_req_start_tag_reg;
    stat_wr_req_start_len_next = stat_wr_req_start_len_reg;
    stat_wr_req_start_valid_next = 1'b0;
    stat_wr_op_table_full_next = !(!op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH));
    stat_wr_tx_no_credit_next = !(!TX_FC_ENABLE || have_credit_reg);
    stat_wr_tx_limit_next = !(!TX_SEQ_NUM_ENABLE || active_tx_count_av_reg);
    stat_wr_tx_stall_next = !(!tx_wr_req_tlp_valid_reg || tx_wr_req_tlp_ready);

    pcie_addr_next = pcie_addr_reg;
    ram_sel_next = ram_sel_reg;
    ram_addr_next = ram_addr_reg;
    op_count_next = op_count_reg;
    tr_count_next = tr_count_reg;
    tlp_count_next = tlp_count_reg;
    tag_next = tag_reg;
    zero_len_next = zero_len_reg;

    read_cmd_pcie_addr_next = read_cmd_pcie_addr_reg;
    read_cmd_ram_sel_next = read_cmd_ram_sel_reg;
    read_cmd_ram_addr_next = read_cmd_ram_addr_reg;
    read_cmd_len_next = read_cmd_len_reg;
    read_cmd_cycle_count_next = read_cmd_cycle_count_reg;
    read_cmd_last_cycle_next = read_cmd_last_cycle_reg;
    read_cmd_valid_next = read_cmd_valid_reg && !read_cmd_ready;

    op_table_start_pcie_addr = pcie_addr_reg;
    op_table_start_len = tlp_count_reg;
    op_table_start_zero_len = zero_len_reg;
    op_table_start_dword_len = (tlp_count_reg + pcie_addr_reg[1:0] + 3) >> 2;
    op_table_start_cycle_count = 0;
    op_table_start_offset = pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
    op_table_start_tag = tag_reg;
    op_table_start_last = op_count_reg == tlp_count_reg;
    op_table_start_en = 1'b0;

    // TLP segmentation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            // idle state, wait for incoming descriptor
            s_axis_write_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;

            pcie_addr_next = s_axis_write_desc_pcie_addr;
            ram_sel_next = s_axis_write_desc_ram_sel;
            ram_addr_next = s_axis_write_desc_ram_addr;
            if (s_axis_write_desc_len == 0) begin
                // zero-length operation
                op_count_next = 1;
                zero_len_next = 1'b1;
            end else begin
                op_count_next = s_axis_write_desc_len;
                zero_len_next = 1'b0;
            end
            tag_next = s_axis_write_desc_tag;

            // TLP size computation
            if (op_count_next <= {max_payload_size_dw_reg, 2'b00}-pcie_addr_next[1:0]) begin
                // packet smaller than max payload size
                if (((pcie_addr_next & 12'hfff) + (op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                    // crosses 4k boundary
                    tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary, send one TLP
                    tlp_count_next = op_count_next;
                end
            end else begin
                // packet larger than max payload size
                if (((pcie_addr_next & 12'hfff) + {max_payload_size_dw_reg, 2'b00}) >> 12 != 0) begin
                    // crosses 4k boundary
                    tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary, split on aligned max payload size
                    tlp_count_next = {max_payload_size_dw_reg, 2'b00}-pcie_addr_next[1:0];
                end
            end

            stat_wr_op_start_len_next = s_axis_write_desc_len;

            if (s_axis_write_desc_ready & s_axis_write_desc_valid) begin
                s_axis_write_desc_ready_next = 1'b0;
                stat_wr_op_start_tag_next = stat_wr_op_start_tag_reg+1;
                stat_wr_op_start_valid_next = 1'b1;
                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            // start state, compute TLP length
            if (!op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && (!ram_rd_cmd_valid_reg || ram_rd_cmd_ready) && (!read_cmd_valid_reg || read_cmd_ready)) begin
                read_cmd_pcie_addr_next = pcie_addr_reg;
                read_cmd_ram_sel_next = ram_sel_reg;
                read_cmd_ram_addr_next = ram_addr_reg;
                read_cmd_len_next = tlp_count_reg;
                read_cmd_cycle_count_next = (tlp_count_reg + pcie_addr_reg[1:0] - 1) >> $clog2(TLP_DATA_WIDTH_BYTES);
                op_table_start_cycle_count = read_cmd_cycle_count_next;
                read_cmd_last_cycle_next = read_cmd_cycle_count_next == 0;
                read_cmd_valid_next = 1'b1;

                pcie_addr_next = pcie_addr_reg + tlp_count_reg;
                ram_addr_next = ram_addr_reg + tlp_count_reg;
                op_count_next = op_count_reg - tlp_count_reg;

                op_table_start_pcie_addr = pcie_addr_reg;
                op_table_start_len = tlp_count_reg;
                op_table_start_zero_len = zero_len_reg;
                op_table_start_dword_len = (tlp_count_reg + pcie_addr_reg[1:0] + 3) >> 2;
                op_table_start_offset = pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
                op_table_start_last = op_count_reg == tlp_count_reg;

                op_table_start_tag = tag_reg;
                op_table_start_en = 1'b1;

                stat_wr_req_start_tag_next = op_table_start_ptr_reg;
                stat_wr_req_start_len_next = tlp_count_reg;
                stat_wr_req_start_valid_next = 1'b1;

                // TLP size computation
                if (op_count_next <= {max_payload_size_dw_reg, 2'b00}-pcie_addr_next[1:0]) begin
                    // packet smaller than max payload size
                    if (((pcie_addr_next & 12'hfff) + (op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                        // crosses 4k boundary
                        tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary, send one TLP
                        tlp_count_next = op_count_next;
                    end
                end else begin
                    // packet larger than max payload size
                    if (((pcie_addr_next & 12'hfff) + {max_payload_size_dw_reg, 2'b00}) >> 12 != 0) begin
                        // crosses 4k boundary
                        tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary, split on aligned max payload size
                        tlp_count_next = {max_payload_size_dw_reg, 2'b00}-pcie_addr_next[1:0];
                    end
                end

                if (!op_table_start_last) begin
                    req_state_next = REQ_STATE_START;
                end else begin
                    s_axis_write_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;
                    req_state_next = REQ_STATE_IDLE;
                end
            end else begin
                req_state_next = REQ_STATE_START;
            end
        end
    endcase
end

always @* begin
    read_state_next = READ_STATE_IDLE;

    read_cmd_ready = 1'b0;

    ram_rd_cmd_sel_next = ram_rd_cmd_sel_reg;
    ram_rd_cmd_addr_next = ram_rd_cmd_addr_reg;
    ram_rd_cmd_valid_next = ram_rd_cmd_valid_reg & ~ram_rd_cmd_ready;

    read_pcie_addr_next = read_pcie_addr_reg;
    read_ram_sel_next = read_ram_sel_reg;
    read_ram_addr_next = read_ram_addr_reg;
    read_len_next = read_len_reg;
    read_ram_mask_next = read_ram_mask_reg;
    read_ram_mask_0_next = read_ram_mask_0_reg;
    read_ram_mask_1_next = read_ram_mask_1_reg;
    ram_wrap_next = ram_wrap_reg;
    read_cycle_count_next = read_cycle_count_reg;
    read_last_cycle_next = read_last_cycle_reg;
    cycle_byte_count_next = cycle_byte_count_reg;
    start_offset_next = start_offset_reg;
    end_offset_next = end_offset_reg;

    mask_fifo_wr_mask = read_ram_mask_reg;
    mask_fifo_we = 1'b0;

    // Read request generation
    case (read_state_reg)
        READ_STATE_IDLE: begin
            // idle state, wait for read command

            read_pcie_addr_next = read_cmd_pcie_addr_reg;
            read_ram_sel_next = read_cmd_ram_sel_reg;
            read_ram_addr_next = read_cmd_ram_addr_reg;
            read_len_next = read_cmd_len_reg;
            read_cycle_count_next = read_cmd_cycle_count_reg;
            read_last_cycle_next = read_cmd_last_cycle_reg;

            if (read_len_next > TLP_DATA_WIDTH_BYTES-read_pcie_addr_next[1:0]) begin
                cycle_byte_count_next = TLP_DATA_WIDTH_BYTES-read_pcie_addr_next[1:0];
            end else begin
                cycle_byte_count_next = read_len_next;
            end
            start_offset_next = read_ram_addr_next;
            {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

            read_ram_mask_0_next = {RAM_SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_WIDTH));
            read_ram_mask_1_next = {RAM_SEG_COUNT{1'b1}} >> (RAM_SEG_COUNT-1-(end_offset_next >> $clog2(RAM_SEG_BE_WIDTH)));

            if (!ram_wrap_next) begin
                read_ram_mask_next = read_ram_mask_0_next & read_ram_mask_1_next;
                read_ram_mask_0_next = read_ram_mask_0_next & read_ram_mask_1_next;
                read_ram_mask_1_next = 0;
            end else begin
                read_ram_mask_next = read_ram_mask_0_next | read_ram_mask_1_next;
            end

            if (read_cmd_valid_reg) begin
                read_cmd_ready = 1'b1;
                read_state_next = READ_STATE_READ;
            end else begin
                read_state_next = READ_STATE_IDLE;
            end
        end
        READ_STATE_READ: begin
            // read state - start new read operations

            if (!(ram_rd_cmd_valid & ~ram_rd_cmd_ready & read_ram_mask_reg) && !mask_fifo_full) begin

                // update counters
                read_ram_addr_next = read_ram_addr_reg + cycle_byte_count_reg;
                read_len_next = read_len_reg - cycle_byte_count_reg;
                read_cycle_count_next = read_cycle_count_reg - 1;
                read_last_cycle_next = read_cycle_count_next == 0;

                for (i = 0; i < RAM_SEG_COUNT; i = i + 1) begin
                    if (read_ram_mask_reg[i]) begin
                        ram_rd_cmd_sel_next[i*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = read_ram_sel_reg;
                        ram_rd_cmd_addr_next[i*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-RAM_SEG_ADDR_WIDTH];
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                    if (read_ram_mask_1_reg[i]) begin
                        ram_rd_cmd_addr_next[i*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-RAM_SEG_ADDR_WIDTH]+1;
                    end
                end

                mask_fifo_wr_mask = read_ram_mask_reg;
                mask_fifo_we = 1'b1;

                if (read_len_next > TLP_DATA_WIDTH_BYTES) begin
                    cycle_byte_count_next = TLP_DATA_WIDTH_BYTES;
                end else begin
                    cycle_byte_count_next = read_len_next;
                end
                start_offset_next = read_ram_addr_next;
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                read_ram_mask_0_next = {RAM_SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_WIDTH));
                read_ram_mask_1_next = {RAM_SEG_COUNT{1'b1}} >> (RAM_SEG_COUNT-1-(end_offset_next >> $clog2(RAM_SEG_BE_WIDTH)));

                if (!ram_wrap_next) begin
                    read_ram_mask_next = read_ram_mask_0_next & read_ram_mask_1_next;
                    read_ram_mask_0_next = read_ram_mask_0_next & read_ram_mask_1_next;
                    read_ram_mask_1_next = 0;
                end else begin
                    read_ram_mask_next = read_ram_mask_0_next | read_ram_mask_1_next;
                end

                if (!read_last_cycle_reg) begin
                    read_state_next = READ_STATE_READ;
                end else begin
                    // skip idle state

                    read_pcie_addr_next = read_cmd_pcie_addr_reg;
                    read_ram_sel_next = read_cmd_ram_sel_reg;
                    read_ram_addr_next = read_cmd_ram_addr_reg;
                    read_len_next = read_cmd_len_reg;
                    read_cycle_count_next = read_cmd_cycle_count_reg;
                    read_last_cycle_next = read_cmd_last_cycle_reg;

                    if (read_len_next > TLP_DATA_WIDTH_BYTES-read_pcie_addr_next[1:0]) begin
                        cycle_byte_count_next = TLP_DATA_WIDTH_BYTES-read_pcie_addr_next[1:0];
                    end else begin
                        cycle_byte_count_next = read_len_next;
                    end
                    start_offset_next = read_ram_addr_next;
                    {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                    read_ram_mask_0_next = {RAM_SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_WIDTH));
                    read_ram_mask_1_next = {RAM_SEG_COUNT{1'b1}} >> (RAM_SEG_COUNT-1-(end_offset_next >> $clog2(RAM_SEG_BE_WIDTH)));

                    if (!ram_wrap_next) begin
                        read_ram_mask_next = read_ram_mask_0_next & read_ram_mask_1_next;
                        read_ram_mask_0_next = read_ram_mask_0_next & read_ram_mask_1_next;
                        read_ram_mask_1_next = 0;
                    end else begin
                        read_ram_mask_next = read_ram_mask_0_next | read_ram_mask_1_next;
                    end

                    if (read_cmd_valid_reg) begin
                        read_cmd_ready = 1'b1;
                        read_state_next = READ_STATE_READ;
                    end else begin
                        read_state_next = READ_STATE_IDLE;
                    end
                end
            end else begin
                read_state_next = READ_STATE_READ;
            end
        end
    endcase
end

wire [3:0] first_be = 4'b1111 << tlp_addr_reg[1:0];
wire [3:0] last_be = 4'b1111 >> (3 - ((tlp_addr_reg[1:0] + tlp_len_reg[1:0] - 1) & 3));

always @* begin
    tlp_state_next = TLP_STATE_IDLE;

    ram_rd_resp_ready_cmb = {RAM_SEG_COUNT{1'b0}};

    stat_wr_op_finish_tag_next = stat_wr_op_finish_tag_reg;
    stat_wr_op_finish_valid_next = 1'b0;
    stat_wr_req_finish_tag_next = stat_wr_req_finish_tag_reg;
    stat_wr_req_finish_valid_next = 1'b0;

    tlp_addr_next = tlp_addr_reg;
    tlp_len_next = tlp_len_reg;
    tlp_zero_len_next = tlp_zero_len_reg;
    dword_count_next = dword_count_reg;
    offset_next = offset_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_valid_next = ram_mask_valid_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;
    tlp_frame_next = tlp_frame_reg;

    mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg;

    op_table_tx_start_en = 1'b0;
    op_table_tx_finish_en = 1'b0;

    inc_active_tx = 1'b0;

    tx_wr_req_tlp_data_next = tx_wr_req_tlp_data_reg;
    tx_wr_req_tlp_strb_next = tx_wr_req_tlp_strb_reg;
    tx_wr_req_tlp_hdr_next = tx_wr_req_tlp_hdr_reg;
    tx_wr_req_tlp_seq_next = tx_wr_req_tlp_seq_reg;
    tx_wr_req_tlp_valid_next = tx_wr_req_tlp_valid_reg && !tx_wr_req_tlp_ready;
    tx_wr_req_tlp_sop_next = tx_wr_req_tlp_sop_reg;
    tx_wr_req_tlp_eop_next = tx_wr_req_tlp_eop_reg;

    // TLP header
    // DW 0
    if (((tlp_addr_reg[PCIE_ADDR_WIDTH-1:2] >> 30) != 0) || TLP_FORCE_64_BIT_ADDR) begin
        tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt - 4DW with data
    end else begin
        tlp_hdr[127:125] = TLP_FMT_3DW_DATA; // fmt - 3DW with data
    end
    tlp_hdr[124:120] = 5'b00000; // type - write
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
    tlp_hdr[105:96] = dword_count_reg; // length
    // DW 1
    tlp_hdr[95:80] = requester_id; // requester ID
    tlp_hdr[79:72] = 8'd0; // tag
    tlp_hdr[71:68] = tlp_zero_len_reg ? 4'b0000 : (dword_count_reg == 1 ? 4'b0000 : last_be); // last BE
    tlp_hdr[67:64] = tlp_zero_len_reg ? 4'b0000 : (dword_count_reg == 1 ? first_be & last_be : first_be); // first BE
    if (((tlp_addr_reg[PCIE_ADDR_WIDTH-1:2] >> 30) != 0) || TLP_FORCE_64_BIT_ADDR) begin
        // DW 2+3
        tlp_hdr[63:2] = tlp_addr_reg[PCIE_ADDR_WIDTH-1:2]; // address
        tlp_hdr[1:0] = 2'b00; // PH
    end else begin
        // DW 2
        tlp_hdr[63:34] = tlp_addr_reg[PCIE_ADDR_WIDTH-1:2]; // address
        tlp_hdr[33:32] = 2'b00; // PH
        // DW 3
        tlp_hdr[31:0] = 32'd0;
    end

    // read response processing and TLP generation
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for command
            ram_rd_resp_ready_cmb = {RAM_SEG_COUNT{1'b0}};

            tlp_frame_next = 1'b0;

            tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            tlp_zero_len_next = op_table_zero_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

            if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && (!TX_FC_ENABLE || have_credit_reg) && (!TX_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                op_table_tx_start_en = 1'b1;
                tlp_state_next = TLP_STATE_TRANSFER;
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_TRANSFER: begin
            // transfer state, transfer data

            if (!tx_wr_req_tlp_valid_reg || tx_wr_req_tlp_ready) begin
                tx_wr_req_tlp_data_next = {2{ram_rd_resp_data}} >> (RAM_DATA_WIDTH-offset_reg*8);
                if (dword_count_reg >= TLP_STRB_WIDTH) begin
                    tx_wr_req_tlp_strb_next = {TLP_STRB_WIDTH{1'b1}};
                end else begin
                    tx_wr_req_tlp_strb_next = {TLP_STRB_WIDTH{1'b1}} >> (TLP_STRB_WIDTH - dword_count_reg);
                end
                tx_wr_req_tlp_hdr_next = tlp_hdr;
                tx_wr_req_tlp_seq_next = op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0];
                tx_wr_req_tlp_eop_next = 1'b0;
            end

            ram_rd_resp_ready_cmb = {RAM_SEG_COUNT{1'b0}};

            if (!(ram_mask_reg & ~ram_rd_resp_valid) && ram_mask_valid_reg && (!tx_wr_req_tlp_valid_reg || tx_wr_req_tlp_ready)) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;
                ram_mask_valid_next = 1'b0;

                // update counters
                dword_count_next = dword_count_reg - TLP_DATA_WIDTH_DWORDS;
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;
                offset_next = offset_reg + TLP_DATA_WIDTH_BYTES;

                tx_wr_req_tlp_sop_next = !tlp_frame_reg;
                tx_wr_req_tlp_valid_next = 1'b1;
                tlp_frame_next = 1'b1;

                inc_active_tx = !tlp_frame_reg;

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    tx_wr_req_tlp_eop_next = 1'b1;
                    tlp_frame_next = 1'b0;
                    op_table_tx_finish_en = 1'b1;

                    // skip idle state if possible
                    tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

                    if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && (!TX_FC_ENABLE || have_credit_reg) && (!TX_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                        op_table_tx_start_en = 1'b1;
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end else begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_TRANSFER;
                end
            end else begin
                tlp_state_next = TLP_STATE_TRANSFER;
            end
        end
    endcase

    if (!ram_mask_valid_next && !mask_fifo_empty) begin
        ram_mask_next = mask_fifo_mask[mask_fifo_rd_ptr_reg[MASK_FIFO_ADDR_WIDTH-1:0]];
        ram_mask_valid_next = 1'b1;
        mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg+1;
    end

    m_axis_write_desc_status_tag_next = op_table_tag[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]];
    m_axis_write_desc_status_valid_next = 1'b0;

    op_table_finish_en = 1'b0;

    stat_wr_req_finish_tag_next = op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0];

    if (op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] && (!TX_SEQ_NUM_ENABLE || op_table_tx_done[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) && op_table_finish_ptr_reg != op_table_tx_finish_ptr_reg) begin
        op_table_finish_en = 1'b1;

        stat_wr_req_finish_valid_next = 1'b1;

        if (op_table_last[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) begin
            stat_wr_op_finish_tag_next = stat_wr_op_finish_tag_reg + 1;
            stat_wr_op_finish_valid_next = 1'b1;

            m_axis_write_desc_status_valid_next = 1'b1;
        end
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

integer k;

always @(posedge clk) begin
    req_state_reg <= req_state_next;
    read_state_reg <= read_state_next;
    tlp_state_reg <= tlp_state_next;

    pcie_addr_reg <= pcie_addr_next;
    ram_sel_reg <= ram_sel_next;
    ram_addr_reg <= ram_addr_next;
    op_count_reg <= op_count_next;
    tr_count_reg <= tr_count_next;
    tlp_count_reg <= tlp_count_next;
    tag_reg <= tag_next;
    zero_len_reg <= zero_len_next;

    read_pcie_addr_reg <= read_pcie_addr_next;
    read_ram_sel_reg <= read_ram_sel_next;
    read_ram_addr_reg <= read_ram_addr_next;
    read_len_reg <= read_len_next;
    read_ram_mask_reg <= read_ram_mask_next;
    read_ram_mask_0_reg <= read_ram_mask_0_next;
    read_ram_mask_1_reg <= read_ram_mask_1_next;
    ram_wrap_reg <= ram_wrap_next;
    read_cycle_count_reg <= read_cycle_count_next;
    read_last_cycle_reg <= read_last_cycle_next;
    cycle_byte_count_reg <= cycle_byte_count_next;
    start_offset_reg <= start_offset_next;
    end_offset_reg <= end_offset_next;

    tlp_addr_reg <= tlp_addr_next;
    tlp_len_reg <= tlp_len_next;
    tlp_zero_len_reg <= tlp_zero_len_next;
    dword_count_reg <= dword_count_next;
    offset_reg <= offset_next;
    ram_mask_reg <= ram_mask_next;
    ram_mask_valid_reg <= ram_mask_valid_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;
    tlp_frame_reg <= tlp_frame_next;

    read_cmd_pcie_addr_reg <= read_cmd_pcie_addr_next;
    read_cmd_ram_sel_reg <= read_cmd_ram_sel_next;
    read_cmd_ram_addr_reg <= read_cmd_ram_addr_next;
    read_cmd_len_reg <= read_cmd_len_next;
    read_cmd_cycle_count_reg <= read_cmd_cycle_count_next;
    read_cmd_last_cycle_reg <= read_cmd_last_cycle_next;
    read_cmd_valid_reg <= read_cmd_valid_next;

    tx_wr_req_tlp_data_reg <= tx_wr_req_tlp_data_next;
    tx_wr_req_tlp_strb_reg <= tx_wr_req_tlp_strb_next;
    tx_wr_req_tlp_hdr_reg <= tx_wr_req_tlp_hdr_next;
    tx_wr_req_tlp_seq_reg <= tx_wr_req_tlp_seq_next;
    tx_wr_req_tlp_valid_reg <= tx_wr_req_tlp_valid_next;
    tx_wr_req_tlp_sop_reg <= tx_wr_req_tlp_sop_next;
    tx_wr_req_tlp_eop_reg <= tx_wr_req_tlp_eop_next;

    s_axis_write_desc_ready_reg <= s_axis_write_desc_ready_next;

    m_axis_write_desc_status_valid_reg <= m_axis_write_desc_status_valid_next;
    m_axis_write_desc_status_tag_reg <= m_axis_write_desc_status_tag_next;

    ram_rd_cmd_sel_reg <= ram_rd_cmd_sel_next;
    ram_rd_cmd_addr_reg <= ram_rd_cmd_addr_next;
    ram_rd_cmd_valid_reg <= ram_rd_cmd_valid_next;

    stat_wr_op_start_tag_reg <= stat_wr_op_start_tag_next;
    stat_wr_op_start_len_reg <= stat_wr_op_start_len_next;
    stat_wr_op_start_valid_reg <= stat_wr_op_start_valid_next;
    stat_wr_op_finish_tag_reg <= stat_wr_op_finish_tag_next;
    stat_wr_op_finish_valid_reg <= stat_wr_op_finish_valid_next;
    stat_wr_req_start_tag_reg <= stat_wr_req_start_tag_next;
    stat_wr_req_start_len_reg <= stat_wr_req_start_len_next;
    stat_wr_req_start_valid_reg <= stat_wr_req_start_valid_next;
    stat_wr_req_finish_tag_reg <= stat_wr_req_finish_tag_next;
    stat_wr_req_finish_valid_reg <= stat_wr_req_finish_valid_next;
    stat_wr_op_table_full_reg <= stat_wr_op_table_full_next;
    stat_wr_tx_no_credit_reg <= stat_wr_tx_no_credit_next;
    stat_wr_tx_limit_reg <= stat_wr_tx_limit_next;
    stat_wr_tx_stall_reg <= stat_wr_tx_stall_next;

    max_payload_size_dw_reg <= 11'd32 << (max_payload_size > 5 ? 5 : max_payload_size);

    have_credit_reg <= (pcie_tx_fc_ph_av > 4) && (pcie_tx_fc_pd_av > (max_payload_size_dw_reg >> 1));

    active_tx_count_reg <= active_tx_count_next;
    active_tx_count_av_reg <= active_tx_count_av_next;

    if (mask_fifo_we) begin
        mask_fifo_mask[mask_fifo_wr_ptr_reg[MASK_FIFO_ADDR_WIDTH-1:0]] <= mask_fifo_wr_mask;
        mask_fifo_wr_ptr_reg <= mask_fifo_wr_ptr_reg + 1;
    end
    mask_fifo_rd_ptr_reg <= mask_fifo_rd_ptr_next;

    if (op_table_start_en) begin
        op_table_start_ptr_reg <= op_table_start_ptr_reg + 1;
        op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b1;
        op_table_tx_done[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b0;
        op_table_pcie_addr[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_pcie_addr;
        op_table_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_len;
        op_table_zero_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_zero_len;
        op_table_dword_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_dword_len;
        op_table_cycle_count[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_cycle_count;
        op_table_offset[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_offset;
        op_table_tag[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_tag;
        op_table_last[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_last;
    end

    if (op_table_tx_start_en) begin
        op_table_tx_start_ptr_reg <= op_table_tx_start_ptr_reg + 1;
    end

    if (op_table_tx_finish_en) begin
        op_table_tx_finish_ptr_reg <= op_table_tx_finish_ptr_reg + 1;
    end

    for (k = 0; k < TX_SEQ_NUM_COUNT; k = k + 1) begin
        if (s_axis_tx_seq_num_valid[k]) begin
            op_table_tx_done[s_axis_tx_seq_num[TX_SEQ_NUM_WIDTH*k +: OP_TAG_WIDTH]] <= 1'b1;
        end
    end

    if (op_table_finish_en) begin
        op_table_finish_ptr_reg <= op_table_finish_ptr_reg + 1;
        op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b0;
    end

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        read_state_reg <= READ_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;

        read_cmd_valid_reg <= 1'b0;

        ram_mask_valid_reg <= 1'b0;

        tx_wr_req_tlp_valid_reg <= 0;

        s_axis_write_desc_ready_reg <= 1'b0;

        m_axis_write_desc_status_valid_reg <= 1'b0;

        ram_rd_cmd_valid_reg <= {RAM_SEG_COUNT{1'b0}};

        stat_wr_op_start_tag_reg <= 0;
        stat_wr_op_start_valid_reg <= 1'b0;
        stat_wr_op_finish_tag_reg <= 0;
        stat_wr_op_finish_valid_reg <= 1'b0;
        stat_wr_req_start_valid_reg <= 1'b0;
        stat_wr_req_finish_valid_reg <= 1'b0;
        stat_wr_op_table_full_reg <= 1'b0;
        stat_wr_tx_no_credit_reg <= 1'b0;
        stat_wr_tx_limit_reg <= 1'b0;
        stat_wr_tx_stall_reg <= 1'b0;

        active_tx_count_reg <= {TX_COUNT_WIDTH{1'b0}};
        active_tx_count_av_reg <= 1'b1;

        mask_fifo_wr_ptr_reg <= 0;
        mask_fifo_rd_ptr_reg <= 0;

        op_table_start_ptr_reg <= 0;
        op_table_tx_start_ptr_reg <= 0;
        op_table_tx_finish_ptr_reg <= 0;
        op_table_finish_ptr_reg <= 0;
        op_table_active <= 0;
    end
end

endmodule

`resetall
