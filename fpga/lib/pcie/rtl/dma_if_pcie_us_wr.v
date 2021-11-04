/*

Copyright (c) 2019-2021 Alex Forencich

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
 * Ultrascale PCIe DMA write interface
 */
module dma_if_pcie_us_wr #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream RQ tuser signal width
    parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 60 : 137,
    // RQ sequence number width
    parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6,
    // RQ sequence number tracking enable
    parameter RQ_SEQ_NUM_ENABLE = 0,
    // RAM segment count
    parameter SEG_COUNT = AXIS_PCIE_DATA_WIDTH > 64 ? AXIS_PCIE_DATA_WIDTH*2 / 128 : 2,
    // RAM segment data width
    parameter SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH*2/SEG_COUNT,
    // RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // RAM select width
    parameter RAM_SEL_WIDTH = 2,
    // RAM address width
    parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH),
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // Length field width
    parameter LEN_WIDTH = 16,
    // Tag field width
    parameter TAG_WIDTH = 8,
    // Operation table size
    parameter OP_TABLE_SIZE = 2**(RQ_SEQ_NUM_WIDTH-1),
    // In-flight transmit limit
    parameter TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1),
    // Transmit flow control
    parameter TX_FC_ENABLE = 0
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * AXI input (RQ from read DMA IF)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]      s_axis_rq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]      s_axis_rq_tkeep,
    input  wire                                 s_axis_rq_tvalid,
    output wire                                 s_axis_rq_tready,
    input  wire                                 s_axis_rq_tlast,
    input  wire [AXIS_PCIE_RQ_USER_WIDTH-1:0]   s_axis_rq_tuser,

    /*
     * AXI output (RQ)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]      m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]      m_axis_rq_tkeep,
    output wire                                 m_axis_rq_tvalid,
    input  wire                                 m_axis_rq_tready,
    output wire                                 m_axis_rq_tlast,
    output wire [AXIS_PCIE_RQ_USER_WIDTH-1:0]   m_axis_rq_tuser,

    /*
     * Transmit sequence number input
     */
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]          s_axis_rq_seq_num_0,
    input  wire                                 s_axis_rq_seq_num_valid_0,
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]          s_axis_rq_seq_num_1,
    input  wire                                 s_axis_rq_seq_num_valid_1,

    /*
     * Transmit sequence number output (to read DMA IF)
     */
    output wire [RQ_SEQ_NUM_WIDTH-1:0]          m_axis_rq_seq_num_0,
    output wire                                 m_axis_rq_seq_num_valid_0,
    output wire [RQ_SEQ_NUM_WIDTH-1:0]          m_axis_rq_seq_num_1,
    output wire                                 m_axis_rq_seq_num_valid_1,

    /*
     * Transmit flow control
     */
    input  wire [7:0]                           pcie_tx_fc_ph_av,
    input  wire [11:0]                          pcie_tx_fc_pd_av,

    /*
     * AXI write descriptor input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_write_desc_pcie_addr,
    input  wire [RAM_SEL_WIDTH-1:0]             s_axis_write_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]            s_axis_write_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                 s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]                 s_axis_write_desc_tag,
    input  wire                                 s_axis_write_desc_valid,
    output wire                                 s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                 m_axis_write_desc_status_tag,
    output wire [3:0]                           m_axis_write_desc_status_error,
    output wire                                 m_axis_write_desc_status_valid,

    /*
     * RAM interface
     */
    output wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]   ram_rd_cmd_sel,
    output wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    output wire [SEG_COUNT-1:0]                 ram_rd_cmd_valid,
    input  wire [SEG_COUNT-1:0]                 ram_rd_cmd_ready,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire [SEG_COUNT-1:0]                 ram_rd_resp_valid,
    output wire [SEG_COUNT-1:0]                 ram_rd_resp_ready,

    /*
     * Configuration
     */
    input  wire                                 enable,
    input  wire [15:0]                          requester_id,
    input  wire                                 requester_id_enable,
    input  wire [2:0]                           max_payload_size
);

parameter RAM_WORD_WIDTH = SEG_BE_WIDTH;
parameter RAM_WORD_SIZE = SEG_DATA_WIDTH/RAM_WORD_WIDTH;

parameter AXIS_PCIE_WORD_WIDTH = AXIS_PCIE_KEEP_WIDTH;
parameter AXIS_PCIE_WORD_SIZE = AXIS_PCIE_DATA_WIDTH/AXIS_PCIE_WORD_WIDTH;

parameter OFFSET_WIDTH = $clog2(AXIS_PCIE_DATA_WIDTH/8);
parameter RAM_OFFSET_WIDTH = $clog2(SEG_COUNT*SEG_DATA_WIDTH/8);
parameter WORD_LEN_WIDTH = LEN_WIDTH - $clog2(AXIS_PCIE_KEEP_WIDTH);
parameter CYCLE_COUNT_WIDTH = 13-$clog2(AXIS_PCIE_KEEP_WIDTH*4);

parameter SEQ_NUM_MASK = {RQ_SEQ_NUM_WIDTH-1{1'b1}};
parameter SEQ_NUM_FLAG = {1'b1, {RQ_SEQ_NUM_WIDTH-1{1'b0}}};

parameter MASK_FIFO_ADDR_WIDTH = $clog2(OP_TABLE_SIZE)+1;

parameter OP_TAG_WIDTH = $clog2(OP_TABLE_SIZE);

parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

// bus width assertions
initial begin
    if (AXIS_PCIE_DATA_WIDTH != 64 && AXIS_PCIE_DATA_WIDTH != 128 && AXIS_PCIE_DATA_WIDTH != 256 && AXIS_PCIE_DATA_WIDTH != 512) begin
        $error("Error: PCIe interface width must be 64, 128, or 256 (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_KEEP_WIDTH * 32 != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        if (AXIS_PCIE_RQ_USER_WIDTH != 137) begin
            $error("Error: PCIe RQ tuser width must be 137 (instance %m)");
            $finish;
        end
    end else begin
        if (AXIS_PCIE_RQ_USER_WIDTH != 60 && AXIS_PCIE_RQ_USER_WIDTH != 62) begin
            $error("Error: PCIe RQ tuser width must be 60 or 62 (instance %m)");
            $finish;
        end
    end

    if (AXIS_PCIE_RQ_USER_WIDTH == 60) begin
        if (RQ_SEQ_NUM_WIDTH != 4) begin
            $error("Error: RQ sequence number width must be 4 (instance %m)");
            $finish;
        end
    end else begin
        if (RQ_SEQ_NUM_WIDTH != 6) begin
            $error("Error: RQ sequence number width must be 6 (instance %m)");
            $finish;
        end
    end

    if (RQ_SEQ_NUM_ENABLE && OP_TABLE_SIZE > 2**(RQ_SEQ_NUM_WIDTH-1)) begin
        $error("Error: Operation table size of range (instance %m)");
        $finish;
    end

    if (RQ_SEQ_NUM_ENABLE && TX_LIMIT > 2**(RQ_SEQ_NUM_WIDTH-1)) begin
        $error("Error: TX limit out of range (instance %m)");
        $finish;
    end

    if (SEG_COUNT < 2) begin
        $error("Error: RAM interface requires at least 2 segments (instance %m)");
        $finish;
    end

    if (SEG_COUNT*SEG_DATA_WIDTH != AXIS_PCIE_DATA_WIDTH*2) begin
        $error("Error: RAM interface width must be double the PCIe interface width (instance %m)");
        $finish;
    end

    if (SEG_BE_WIDTH * 8 != SEG_DATA_WIDTH) begin
        $error("Error: RAM interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (2**$clog2(RAM_WORD_WIDTH) != RAM_WORD_WIDTH) begin
        $error("Error: RAM word width must be even power of two (instance %m)");
        $finish;
    end

    if (RAM_ADDR_WIDTH != SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH)) begin
        $error("Error: RAM_ADDR_WIDTH does not match RAM configuration (instance %m)");
        $finish;
    end
end

localparam [3:0]
    REQ_MEM_READ = 4'b0000,
    REQ_MEM_WRITE = 4'b0001,
    REQ_IO_READ = 4'b0010,
    REQ_IO_WRITE = 4'b0011,
    REQ_MEM_FETCH_ADD = 4'b0100,
    REQ_MEM_SWAP = 4'b0101,
    REQ_MEM_CAS = 4'b0110,
    REQ_MEM_READ_LOCKED = 4'b0111,
    REQ_CFG_READ_0 = 4'b1000,
    REQ_CFG_READ_1 = 4'b1001,
    REQ_CFG_WRITE_0 = 4'b1010,
    REQ_CFG_WRITE_1 = 4'b1011,
    REQ_MSG = 4'b1100,
    REQ_MSG_VENDOR = 4'b1101,
    REQ_MSG_ATS = 4'b1110;

localparam [2:0]
    CPL_STATUS_SC  = 3'b000, // successful completion
    CPL_STATUS_UR  = 3'b001, // unsupported request
    CPL_STATUS_CRS = 3'b010, // configuration request retry status
    CPL_STATUS_CA  = 3'b100; // completer abort

localparam [0:0]
    REQ_STATE_IDLE = 1'd0,
    REQ_STATE_START = 1'd1;

reg [0:0] req_state_reg = REQ_STATE_IDLE, req_state_next;

localparam [0:0]
    READ_STATE_IDLE = 1'd0,
    READ_STATE_READ = 1'd1;

reg [0:0] read_state_reg = READ_STATE_IDLE, read_state_next;

localparam [1:0]
    TLP_STATE_IDLE = 2'd0,
    TLP_STATE_HEADER = 2'd1,
    TLP_STATE_TRANSFER = 2'd2;

reg [1:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

localparam [1:0]
    TLP_OUTPUT_STATE_IDLE = 2'd0,
    TLP_OUTPUT_STATE_HEADER = 2'd1,
    TLP_OUTPUT_STATE_PAYLOAD = 2'd2,
    TLP_OUTPUT_STATE_PASSTHROUGH = 2'd3;

reg [1:0] tlp_output_state_reg = TLP_OUTPUT_STATE_IDLE, tlp_output_state_next;

// datapath control signals
reg mask_fifo_we;

reg read_cmd_ready;

reg [PCIE_ADDR_WIDTH-1:0] pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, pcie_addr_next;
reg [RAM_SEL_WIDTH-1:0] ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, ram_addr_next;
reg [LEN_WIDTH-1:0] op_count_reg = {LEN_WIDTH{1'b0}}, op_count_next;
reg [LEN_WIDTH-1:0] tr_count_reg = {LEN_WIDTH{1'b0}}, tr_count_next;
reg [12:0] tlp_count_reg = 13'd0, tlp_count_next;
reg zero_len_reg = 1'b0, zero_len_next;
reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;

reg [PCIE_ADDR_WIDTH-1:0] read_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, read_pcie_addr_next;
reg [RAM_SEL_WIDTH-1:0] read_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, read_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] read_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, read_ram_addr_next;
reg [LEN_WIDTH-1:0] read_len_reg = {LEN_WIDTH{1'b0}}, read_len_next;
reg [SEG_COUNT-1:0] read_ram_mask_reg = {SEG_COUNT{1'b0}}, read_ram_mask_next;
reg [SEG_COUNT-1:0] read_ram_mask_0_reg = {SEG_COUNT{1'b0}}, read_ram_mask_0_next;
reg [SEG_COUNT-1:0] read_ram_mask_1_reg = {SEG_COUNT{1'b0}}, read_ram_mask_1_next;
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
reg [SEG_COUNT-1:0] ram_mask_reg = {SEG_COUNT{1'b0}}, ram_mask_next;
reg ram_mask_valid_reg = 1'b0, ram_mask_valid_next;
reg [CYCLE_COUNT_WIDTH-1:0] cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, cycle_count_next;
reg last_cycle_reg = 1'b0, last_cycle_next;

reg [PCIE_ADDR_WIDTH-1:0] read_cmd_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, read_cmd_pcie_addr_next;
reg [RAM_SEL_WIDTH-1:0] read_cmd_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, read_cmd_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] read_cmd_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, read_cmd_ram_addr_next;
reg [11:0] read_cmd_len_reg = 12'd0, read_cmd_len_next;
reg [CYCLE_COUNT_WIDTH-1:0] read_cmd_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, read_cmd_cycle_count_next;
reg read_cmd_last_cycle_reg = 1'b0, read_cmd_last_cycle_next;
reg read_cmd_valid_reg = 1'b0, read_cmd_valid_next;

reg [127:0] tlp_header_data;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] tlp_tuser;
reg [127:0] tlp_header_data_reg = 128'd0, tlp_header_data_next;
reg tlp_header_valid_reg = 1'b0, tlp_header_valid_next;
reg [AXIS_PCIE_DATA_WIDTH-1:0] tlp_payload_data_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}}, tlp_payload_data_next;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] tlp_payload_keep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}}, tlp_payload_keep_next;
reg tlp_payload_valid_reg = 1'b0, tlp_payload_valid_next;
reg tlp_payload_last_reg = 1'b0, tlp_payload_last_next;
reg [3:0] tlp_first_be_reg = 4'd0, tlp_first_be_next;
reg [3:0] tlp_last_be_reg = 4'd0, tlp_last_be_next;
reg [RQ_SEQ_NUM_WIDTH-1:0] tlp_seq_num_reg = {RQ_SEQ_NUM_WIDTH{1'b0}}, tlp_seq_num_next;

reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_wr_ptr_reg = 0;
reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_rd_ptr_reg = 0, mask_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [SEG_COUNT-1:0] mask_fifo_mask[(2**MASK_FIFO_ADDR_WIDTH)-1:0];
reg [SEG_COUNT-1:0] mask_fifo_wr_mask;

wire mask_fifo_empty = mask_fifo_wr_ptr_reg == mask_fifo_rd_ptr_reg;
wire mask_fifo_full = mask_fifo_wr_ptr_reg == (mask_fifo_rd_ptr_reg ^ (1 << MASK_FIFO_ADDR_WIDTH));

reg [10:0] max_payload_size_dw_reg = 11'd0;

reg have_credit_reg = 1'b0;

reg [RQ_SEQ_NUM_WIDTH-1:0] active_tx_count_reg = {RQ_SEQ_NUM_WIDTH{1'b0}};
reg active_tx_count_av_reg = 1'b1;
reg inc_active_tx;

reg s_axis_rq_tready_reg = 1'b0, s_axis_rq_tready_next;

reg s_axis_write_desc_ready_reg = 1'b0, s_axis_write_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_write_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_write_desc_status_tag_next;
reg m_axis_write_desc_status_valid_reg = 1'b0, m_axis_write_desc_status_valid_next;

reg [SEG_COUNT*RAM_SEL_WIDTH-1:0] ram_rd_cmd_sel_reg = 0, ram_rd_cmd_sel_next;
reg [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ram_rd_cmd_addr_reg = 0, ram_rd_cmd_addr_next;
reg [SEG_COUNT-1:0] ram_rd_cmd_valid_reg = 0, ram_rd_cmd_valid_next;
reg [SEG_COUNT-1:0] ram_rd_resp_ready_cmb;

// internal datapath
reg  [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata_int;
reg  [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep_int;
reg                                m_axis_rq_tvalid_int;
wire                               m_axis_rq_tready_int;
reg                                m_axis_rq_tlast_int;
reg  [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser_int;

assign s_axis_rq_tready = s_axis_rq_tready_reg;

assign m_axis_rq_seq_num_0 = s_axis_rq_seq_num_0 & SEQ_NUM_MASK;
assign m_axis_rq_seq_num_valid_0 = s_axis_rq_seq_num_valid_0 && (s_axis_rq_seq_num_0 & SEQ_NUM_FLAG);
assign m_axis_rq_seq_num_1 = s_axis_rq_seq_num_1 & SEQ_NUM_MASK;
assign m_axis_rq_seq_num_valid_1 = s_axis_rq_seq_num_valid_1 && (s_axis_rq_seq_num_1 & SEQ_NUM_FLAG);

wire axis_rq_seq_num_valid_0_int = s_axis_rq_seq_num_valid_0 && !(s_axis_rq_seq_num_0 & SEQ_NUM_FLAG);
wire axis_rq_seq_num_valid_1_int = s_axis_rq_seq_num_valid_1 && !(s_axis_rq_seq_num_1 & SEQ_NUM_FLAG);

assign s_axis_write_desc_ready = s_axis_write_desc_ready_reg;

assign m_axis_write_desc_status_tag = m_axis_write_desc_status_tag_reg;
assign m_axis_write_desc_status_error = 4'd0;
assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

assign ram_rd_cmd_sel = ram_rd_cmd_sel_reg;
assign ram_rd_cmd_addr = ram_rd_cmd_addr_reg;
assign ram_rd_cmd_valid = ram_rd_cmd_valid_reg;
assign ram_rd_resp_ready = ram_rd_resp_ready_cmb;

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

    pcie_addr_next = pcie_addr_reg;
    ram_sel_next = ram_sel_reg;
    ram_addr_next = ram_addr_reg;
    op_count_next = op_count_reg;
    tr_count_next = tr_count_reg;
    tlp_count_next = tlp_count_reg;
    zero_len_next = zero_len_reg;
    tag_next = tag_reg;

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
    if (AXIS_PCIE_DATA_WIDTH >= 256) begin
        op_table_start_offset = 16+pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
    end else begin
        op_table_start_offset = pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
    end
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
                    // does not cross 4k boundary, send one TLP
                    tlp_count_next = {max_payload_size_dw_reg, 2'b00}-pcie_addr_next[1:0];
                end
            end

            if (s_axis_write_desc_ready & s_axis_write_desc_valid) begin
                s_axis_write_desc_ready_next = 1'b0;
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
                if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                    read_cmd_cycle_count_next = (tlp_count_reg + 16+pcie_addr_reg[1:0] - 1) >> $clog2(AXIS_PCIE_DATA_WIDTH/8);
                    end else begin
                    read_cmd_cycle_count_next = (tlp_count_reg + pcie_addr_reg[1:0] - 1) >> $clog2(AXIS_PCIE_DATA_WIDTH/8);
                end
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
                if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                    op_table_start_offset = 16+pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
                end else begin
                    op_table_start_offset = pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
                end
                op_table_start_last = op_count_reg == tlp_count_reg;

                op_table_start_tag = tag_reg;
                op_table_start_en = 1'b1;

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
                        // does not cross 4k boundary, send one TLP
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

            if (AXIS_PCIE_DATA_WIDTH >= 256 && read_len_next > (AXIS_PCIE_DATA_WIDTH/8-16)-read_pcie_addr_next[1:0]) begin
                cycle_byte_count_next = (AXIS_PCIE_DATA_WIDTH/8-16)-read_pcie_addr_next[1:0];
            end else if (AXIS_PCIE_DATA_WIDTH <= 128 && read_len_next > AXIS_PCIE_DATA_WIDTH/8-read_pcie_addr_next[1:0]) begin
                cycle_byte_count_next = AXIS_PCIE_DATA_WIDTH/8-read_pcie_addr_next[1:0];
            end else begin
                cycle_byte_count_next = read_len_next;
            end
            start_offset_next = read_ram_addr_next;
            {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

            read_ram_mask_0_next = {SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(SEG_BE_WIDTH));
            read_ram_mask_1_next = {SEG_COUNT{1'b1}} >> (SEG_COUNT-1-(end_offset_next >> $clog2(SEG_BE_WIDTH)));

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

                for (i = 0; i < SEG_COUNT; i = i + 1) begin
                    if (read_ram_mask_reg[i]) begin
                        ram_rd_cmd_sel_next[i*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = read_ram_sel_reg;
                        ram_rd_cmd_addr_next[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH];
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                    if (read_ram_mask_1_reg[i]) begin
                        ram_rd_cmd_addr_next[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]+1;
                    end
                end

                mask_fifo_wr_mask = read_ram_mask_reg;
                mask_fifo_we = 1'b1;

                if (read_len_next > AXIS_PCIE_DATA_WIDTH/8) begin
                    cycle_byte_count_next = AXIS_PCIE_DATA_WIDTH/8;
                end else begin
                    cycle_byte_count_next = read_len_next;
                end
                start_offset_next = read_ram_addr_next;
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                read_ram_mask_0_next = {SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(SEG_BE_WIDTH));
                read_ram_mask_1_next = {SEG_COUNT{1'b1}} >> (SEG_COUNT-1-(end_offset_next >> $clog2(SEG_BE_WIDTH)));

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

                    if (AXIS_PCIE_DATA_WIDTH >= 256 && read_len_next > (AXIS_PCIE_DATA_WIDTH/8-16)-read_pcie_addr_next[1:0]) begin
                        cycle_byte_count_next = (AXIS_PCIE_DATA_WIDTH/8-16)-read_pcie_addr_next[1:0];
                    end else if (AXIS_PCIE_DATA_WIDTH <= 128 && read_len_next > AXIS_PCIE_DATA_WIDTH/8-read_pcie_addr_next[1:0]) begin
                        cycle_byte_count_next = AXIS_PCIE_DATA_WIDTH/8-read_pcie_addr_next[1:0];
                    end else begin
                        cycle_byte_count_next = read_len_next;
                    end
                    start_offset_next = read_ram_addr_next;
                    {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                    read_ram_mask_0_next = {SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(SEG_BE_WIDTH));
                    read_ram_mask_1_next = {SEG_COUNT{1'b1}} >> (SEG_COUNT-1-(end_offset_next >> $clog2(SEG_BE_WIDTH)));

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
    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;

    ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

    tlp_addr_next = tlp_addr_reg;
    tlp_len_next = tlp_len_reg;
    tlp_zero_len_next = tlp_zero_len_reg;
    dword_count_next = dword_count_reg;
    offset_next = offset_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_valid_next = ram_mask_valid_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    tlp_header_data_next = tlp_header_data_reg;
    tlp_header_valid_next = tlp_header_valid_reg;
    tlp_payload_data_next = tlp_payload_data_reg;
    tlp_payload_keep_next = tlp_payload_keep_reg;
    tlp_payload_valid_next = tlp_payload_valid_reg;
    tlp_payload_last_next = tlp_payload_last_reg;
    tlp_first_be_next = tlp_first_be_reg;
    tlp_last_be_next = tlp_last_be_reg;
    tlp_seq_num_next = tlp_seq_num_reg;

    mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg;

    op_table_tx_start_en = 1'b0;
    op_table_tx_finish_en = 1'b0;

    inc_active_tx = 1'b0;

    s_axis_rq_tready_next = 1'b0;

    // TLP header and sideband data
    tlp_header_data[1:0] = 2'b0; // address type
    tlp_header_data[63:2] = tlp_addr_reg[PCIE_ADDR_WIDTH-1:2]; // address
    tlp_header_data[74:64] = dword_count_reg; // DWORD count
    tlp_header_data[78:75] = REQ_MEM_WRITE; // request type - memory write
    tlp_header_data[79] = 1'b0; // poisoned request
    tlp_header_data[95:80] = requester_id;
    tlp_header_data[103:96] = 8'd0; // tag
    tlp_header_data[119:104] = 16'd0; // completer ID
    tlp_header_data[120] = requester_id_enable; // requester ID enable
    tlp_header_data[123:121] = 3'b000; // traffic class
    tlp_header_data[126:124] = 3'b000; // attr
    tlp_header_data[127] = 1'b0; // force ECRC

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        tlp_tuser[3:0] = tlp_first_be_reg; // first BE 0
        tlp_tuser[7:4] = 4'd0; // first BE 1
        tlp_tuser[11:8] = tlp_last_be_reg; // last BE 0
        tlp_tuser[15:12] = 4'd0; // last BE 1
        tlp_tuser[19:16] = 3'd0; // addr_offset
        tlp_tuser[21:20] = 2'b01; // is_sop
        tlp_tuser[23:22] = 2'd0; // is_sop0_ptr
        tlp_tuser[25:24] = 2'd0; // is_sop1_ptr
        tlp_tuser[27:26] = 2'b01; // is_eop
        tlp_tuser[31:28]  = 4'd3; // is_eop0_ptr
        tlp_tuser[35:32] = 4'd0; // is_eop1_ptr
        tlp_tuser[36] = 1'b0; // discontinue
        tlp_tuser[38:37] = 2'b00; // tph_present
        tlp_tuser[42:39] = 4'b0000; // tph_type
        tlp_tuser[44:43] = 2'b00; // tph_indirect_tag_en
        tlp_tuser[60:45] = 16'd0; // tph_st_tag
        tlp_tuser[66:61] = tlp_seq_num_reg; // seq_num0
        tlp_tuser[72:67] = 6'd0; // seq_num1
        tlp_tuser[136:73] = 64'd0; // parity
    end else begin
        tlp_tuser[3:0] = tlp_first_be_reg; // first BE
        tlp_tuser[7:4] = tlp_last_be_reg; // last BE
        tlp_tuser[10:8] = 3'd0; // addr_offset
        tlp_tuser[11] = 1'b0; // discontinue
        tlp_tuser[12] = 1'b0; // tph_present
        tlp_tuser[14:13] = 2'b00; // tph_type
        tlp_tuser[15] = 1'b0; // tph_indirect_tag_en
        tlp_tuser[23:16] = 8'd0; // tph_st_tag
        tlp_tuser[27:24] = tlp_seq_num_reg; // seq_num
        tlp_tuser[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_WIDTH == 62) begin
            tlp_tuser[61:60] = tlp_seq_num_reg >> 4; // seq_num
        end
    end

    // TLP output
    m_axis_rq_tdata_int = tlp_payload_data_reg;
    m_axis_rq_tkeep_int = tlp_payload_keep_reg;
    m_axis_rq_tvalid_int = 1'b0;
    m_axis_rq_tlast_int = tlp_payload_last_reg;
    m_axis_rq_tuser_int = tlp_tuser;

    // combine header and payload, merge in read request TLPs
    case (tlp_output_state_reg)
        TLP_OUTPUT_STATE_IDLE: begin
            // idle state
            s_axis_rq_tready_next = m_axis_rq_tready_int;

            if (s_axis_rq_tready && s_axis_rq_tvalid) begin
                // transfer read request through

                m_axis_rq_tdata_int = s_axis_rq_tdata;
                m_axis_rq_tkeep_int = s_axis_rq_tkeep;
                m_axis_rq_tvalid_int = s_axis_rq_tready && s_axis_rq_tvalid;
                m_axis_rq_tlast_int = s_axis_rq_tlast;
                m_axis_rq_tuser_int = s_axis_rq_tuser;

                // set MSB of TX sequence number
                if (AXIS_PCIE_DATA_WIDTH == 512) begin
                    m_axis_rq_tuser_int[61+RQ_SEQ_NUM_WIDTH-1] = 1'b1;
                end else begin
                    if (RQ_SEQ_NUM_WIDTH > 4) begin
                        m_axis_rq_tuser_int[60+RQ_SEQ_NUM_WIDTH-4-1] = 1'b1;
                    end else begin
                        m_axis_rq_tuser_int[24+RQ_SEQ_NUM_WIDTH-1] = 1'b1;
                    end
                end

                if (s_axis_rq_tready && s_axis_rq_tvalid && s_axis_rq_tlast) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_PASSTHROUGH;
                end
            end else if (AXIS_PCIE_DATA_WIDTH == 64 && tlp_header_valid_reg) begin
                // 64 bit interface, send first half of header
                m_axis_rq_tdata_int = tlp_header_data_reg[63:0];
                m_axis_rq_tkeep_int = 2'b11;
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser;

                s_axis_rq_tready_next = 1'b0;
                tlp_output_state_next = TLP_OUTPUT_STATE_HEADER;
            end else if (AXIS_PCIE_DATA_WIDTH == 128 && tlp_header_valid_reg) begin
                // 128 bit interface, send complete header
                m_axis_rq_tdata_int = tlp_header_data_reg;
                m_axis_rq_tkeep_int = 4'b1111;
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser;
                tlp_header_valid_next = 1'b0;

                s_axis_rq_tready_next = 1'b0;
                tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
            end else if (AXIS_PCIE_DATA_WIDTH >= 256 && tlp_header_valid_reg && tlp_payload_valid_reg) begin
                // send header and start of payload
                m_axis_rq_tdata_int = tlp_payload_data_reg;
                m_axis_rq_tdata_int[127:0] = tlp_header_data_reg;
                m_axis_rq_tkeep_int = {tlp_payload_keep_reg, 4'b1111};
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = tlp_payload_last_reg;
                m_axis_rq_tuser_int = tlp_tuser;
                tlp_header_valid_next = 1'b0;
                tlp_payload_valid_next = 1'b0;

                if (tlp_payload_last_reg) begin
                    s_axis_rq_tready_next = m_axis_rq_tready_int;
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    s_axis_rq_tready_next = 1'b0;
                    tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                end
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end
        end
        TLP_OUTPUT_STATE_HEADER: begin
            // second cycle of header
            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axis_rq_tdata_int = tlp_header_data_reg[127:64];
                m_axis_rq_tkeep_int = 2'b11;
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser;
                tlp_header_valid_next = 1'b0;

                if (tlp_header_valid_reg) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_HEADER;
                end
            end
        end
        TLP_OUTPUT_STATE_PAYLOAD: begin
            // transfer payload
            m_axis_rq_tdata_int = tlp_payload_data_reg;
            m_axis_rq_tkeep_int = tlp_payload_keep_reg;
            m_axis_rq_tvalid_int = tlp_payload_valid_reg;
            m_axis_rq_tlast_int = tlp_payload_last_reg;
            m_axis_rq_tuser_int = tlp_tuser;
            tlp_payload_valid_next = 1'b0;

            if (tlp_payload_valid_reg && tlp_payload_last_reg) begin
                s_axis_rq_tready_next = m_axis_rq_tready_int;
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
            end
        end
        TLP_OUTPUT_STATE_PASSTHROUGH: begin
            // pass through read request TLP
            s_axis_rq_tready_next = m_axis_rq_tready_int;

            m_axis_rq_tdata_int = s_axis_rq_tdata;
            m_axis_rq_tkeep_int = s_axis_rq_tkeep;
            m_axis_rq_tvalid_int = s_axis_rq_tready && s_axis_rq_tvalid;
            m_axis_rq_tlast_int = s_axis_rq_tlast;
            m_axis_rq_tuser_int = s_axis_rq_tuser;

            // set MSB of TX sequence number
            if (AXIS_PCIE_DATA_WIDTH == 512) begin
                m_axis_rq_tuser_int[61+RQ_SEQ_NUM_WIDTH-1] = 1'b1;
            end else begin
                if (RQ_SEQ_NUM_WIDTH > 4) begin
                    m_axis_rq_tuser_int[60+RQ_SEQ_NUM_WIDTH-4-1] = 1'b1;
                end else begin
                    m_axis_rq_tuser_int[24+RQ_SEQ_NUM_WIDTH-1] = 1'b1;
                end
            end

            if (s_axis_rq_tready && s_axis_rq_tvalid && s_axis_rq_tlast) begin
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_PASSTHROUGH;
            end
        end
    endcase

    // read response processing and TLP generation
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for command
            ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

            tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            tlp_zero_len_next = op_table_zero_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

            if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && (!TX_FC_ENABLE || have_credit_reg) && (!RQ_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                op_table_tx_start_en = 1'b1;
                tlp_state_next = TLP_STATE_HEADER;
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_HEADER: begin
            // header state, send TLP header
            if (!tlp_header_valid_next) begin
                tlp_header_data_next = tlp_header_data;

                if (tlp_zero_len_reg) begin
                    tlp_first_be_next = 4'b0000;
                    tlp_last_be_next = 4'b0000;
                end else begin
                    tlp_first_be_next = dword_count_reg == 1 ? first_be & last_be : first_be;
                    tlp_last_be_next = dword_count_reg == 1 ? 4'b0000 : last_be;
                end
                tlp_seq_num_next = op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0] & SEQ_NUM_MASK;
            end

            if (AXIS_PCIE_DATA_WIDTH >= 256) begin

                if (!tlp_payload_valid_next) begin
                    tlp_payload_data_next = {2{ram_rd_resp_data}} >> (SEG_COUNT*SEG_DATA_WIDTH-offset_reg*8);
                    if (dword_count_reg >= AXIS_PCIE_KEEP_WIDTH) begin
                        tlp_payload_keep_next = {AXIS_PCIE_KEEP_WIDTH{1'b1}};
                    end else begin
                        tlp_payload_keep_next = {AXIS_PCIE_KEEP_WIDTH{1'b1}} >> (AXIS_PCIE_KEEP_WIDTH - dword_count_reg);
                    end
                    tlp_payload_last_next = 1'b0;
                end

                ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

                if (!(ram_mask_reg & ~ram_rd_resp_valid) && ram_mask_valid_reg && m_axis_rq_tready_int && !tlp_header_valid_next && !tlp_payload_valid_next) begin
                    // transfer in read data
                    ram_rd_resp_ready_cmb = ram_mask_reg;
                    ram_mask_valid_next = 1'b0;

                    // update counters
                    dword_count_next = dword_count_reg - (AXIS_PCIE_KEEP_WIDTH-4);
                    cycle_count_next = cycle_count_reg - 1;
                    last_cycle_next = cycle_count_next == 0;
                    offset_next = offset_reg + AXIS_PCIE_DATA_WIDTH/8;

                    tlp_header_valid_next = 1'b1;
                    tlp_payload_valid_next = 1'b1;

                    inc_active_tx = 1'b1;

                    if (last_cycle_reg) begin
                        tlp_payload_last_next = 1'b1;
                        op_table_tx_finish_en = 1'b1;

                        // skip idle state if possible
                        tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

                        if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && !s_axis_rq_tvalid && (!TX_FC_ENABLE || have_credit_reg) && (!RQ_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                            op_table_tx_start_en = 1'b1;
                            tlp_state_next = TLP_STATE_HEADER;
                        end else begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end
                    end else begin
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER;
                end
            end else begin
                if (m_axis_rq_tready_int && !tlp_header_valid_next) begin
                    tlp_header_valid_next = 1'b1;

                    inc_active_tx = 1'b1;

                    tlp_state_next = TLP_STATE_TRANSFER;
                end else begin
                    tlp_state_next = TLP_STATE_HEADER;
                end
            end
        end
        TLP_STATE_TRANSFER: begin
            // transfer state, transfer data

            if (!tlp_payload_valid_next) begin
                tlp_payload_data_next = {2{ram_rd_resp_data}} >> (SEG_COUNT*SEG_DATA_WIDTH-offset_reg*8);
                if (dword_count_reg >= AXIS_PCIE_KEEP_WIDTH) begin
                    tlp_payload_keep_next = {AXIS_PCIE_KEEP_WIDTH{1'b1}};
                end else begin
                    tlp_payload_keep_next = {AXIS_PCIE_KEEP_WIDTH{1'b1}} >> (AXIS_PCIE_KEEP_WIDTH - dword_count_reg);
                end
                tlp_payload_last_next = 1'b0;
            end

            ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

            if (!(ram_mask_reg & ~ram_rd_resp_valid) && ram_mask_valid_reg && m_axis_rq_tready_int && !tlp_payload_valid_next) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;
                ram_mask_valid_next = 1'b0;

                // update counters
                dword_count_next = dword_count_reg - AXIS_PCIE_KEEP_WIDTH;
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;
                offset_next = offset_reg + AXIS_PCIE_DATA_WIDTH/8;

                tlp_payload_valid_next = 1'b1;

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    tlp_payload_last_next = 1'b1;
                    op_table_tx_finish_en = 1'b1;

                    // skip idle state if possible
                    tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

                    if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && !s_axis_rq_tvalid && (!TX_FC_ENABLE || have_credit_reg) && (!RQ_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                        op_table_tx_start_en = 1'b1;
                        tlp_state_next = TLP_STATE_HEADER;
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

    if (op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] && (!RQ_SEQ_NUM_ENABLE || op_table_tx_done[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) && op_table_finish_ptr_reg != op_table_tx_finish_ptr_reg) begin
        op_table_finish_en = 1'b1;

        if (op_table_last[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) begin
            m_axis_write_desc_status_valid_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    req_state_reg <= req_state_next;
    read_state_reg <= read_state_next;
    tlp_state_reg <= tlp_state_next;
    tlp_output_state_reg <= tlp_output_state_next;

    pcie_addr_reg <= pcie_addr_next;
    ram_sel_reg <= ram_sel_next;
    ram_addr_reg <= ram_addr_next;
    op_count_reg <= op_count_next;
    tr_count_reg <= tr_count_next;
    tlp_count_reg <= tlp_count_next;
    zero_len_reg <= zero_len_next;
    tag_reg <= tag_next;

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

    read_cmd_pcie_addr_reg <= read_cmd_pcie_addr_next;
    read_cmd_ram_sel_reg <= read_cmd_ram_sel_next;
    read_cmd_ram_addr_reg <= read_cmd_ram_addr_next;
    read_cmd_len_reg <= read_cmd_len_next;
    read_cmd_cycle_count_reg <= read_cmd_cycle_count_next;
    read_cmd_last_cycle_reg <= read_cmd_last_cycle_next;
    read_cmd_valid_reg <= read_cmd_valid_next;

    tlp_header_data_reg <= tlp_header_data_next;
    tlp_header_valid_reg <= tlp_header_valid_next;
    tlp_payload_data_reg <= tlp_payload_data_next;
    tlp_payload_keep_reg <= tlp_payload_keep_next;
    tlp_payload_valid_reg <= tlp_payload_valid_next;
    tlp_payload_last_reg <= tlp_payload_last_next;
    tlp_first_be_reg <= tlp_first_be_next;
    tlp_last_be_reg <= tlp_last_be_next;
    tlp_seq_num_reg <= tlp_seq_num_next;

    s_axis_rq_tready_reg <= s_axis_rq_tready_next;

    s_axis_write_desc_ready_reg <= s_axis_write_desc_ready_next;

    m_axis_write_desc_status_valid_reg <= m_axis_write_desc_status_valid_next;
    m_axis_write_desc_status_tag_reg <= m_axis_write_desc_status_tag_next;

    ram_rd_cmd_sel_reg <= ram_rd_cmd_sel_next;
    ram_rd_cmd_addr_reg <= ram_rd_cmd_addr_next;
    ram_rd_cmd_valid_reg <= ram_rd_cmd_valid_next;

    max_payload_size_dw_reg <= 11'd32 << (max_payload_size > 5 ? 5 : max_payload_size);

    have_credit_reg <= (pcie_tx_fc_ph_av > 4) && (pcie_tx_fc_pd_av > (max_payload_size_dw_reg >> 1));

    if (active_tx_count_reg < TX_LIMIT && inc_active_tx && !axis_rq_seq_num_valid_0_int && !axis_rq_seq_num_valid_1_int) begin
        // inc by 1
        active_tx_count_reg <= active_tx_count_reg + 1;
        active_tx_count_av_reg <= active_tx_count_reg < (TX_LIMIT-1);
    end else if (active_tx_count_reg > 0 && ((inc_active_tx && axis_rq_seq_num_valid_0_int && axis_rq_seq_num_valid_1_int) || (!inc_active_tx && (axis_rq_seq_num_valid_0_int ^ axis_rq_seq_num_valid_1_int)))) begin
        // dec by 1
        active_tx_count_reg <= active_tx_count_reg - 1;
        active_tx_count_av_reg <= 1'b1;
    end else if (active_tx_count_reg > 1 && !inc_active_tx && axis_rq_seq_num_valid_0_int && axis_rq_seq_num_valid_1_int) begin
        // dec by 2
        active_tx_count_reg <= active_tx_count_reg - 2;
        active_tx_count_av_reg <= 1'b1;
    end else begin
        active_tx_count_av_reg <= active_tx_count_reg < TX_LIMIT;
    end

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

    if (axis_rq_seq_num_valid_0_int) begin
        op_table_tx_done[s_axis_rq_seq_num_0[OP_TAG_WIDTH-1:0]] <= 1'b1;
    end

    if (axis_rq_seq_num_valid_1_int) begin
        op_table_tx_done[s_axis_rq_seq_num_1[OP_TAG_WIDTH-1:0]] <= 1'b1;
    end

    if (op_table_finish_en) begin
        op_table_finish_ptr_reg <= op_table_finish_ptr_reg + 1;
        op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b0;
    end

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        read_state_reg <= READ_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;
        tlp_output_state_reg <= TLP_OUTPUT_STATE_IDLE;

        read_cmd_valid_reg <= 1'b0;

        tlp_header_valid_reg <= 1'b0;
        tlp_payload_valid_reg <= 1'b0;

        ram_mask_valid_reg <= 1'b0;

        s_axis_rq_tready_reg <= 1'b0;
        s_axis_write_desc_ready_reg <= 1'b0;
        m_axis_write_desc_status_valid_reg <= 1'b0;
        ram_rd_cmd_valid_reg <= {SEG_COUNT{1'b0}};

        active_tx_count_reg <= {RQ_SEQ_NUM_WIDTH{1'b0}};
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

// output datapath logic (PCIe TLP)
reg [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg                               m_axis_rq_tvalid_reg = 1'b0, m_axis_rq_tvalid_next;
reg                               m_axis_rq_tlast_reg = 1'b0;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser_reg = {AXIS_PCIE_RQ_USER_WIDTH{1'b0}};

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed" *)
reg [AXIS_PCIE_DATA_WIDTH-1:0]    out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
reg                               out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axis_rq_tready_int = !out_fifo_half_full_reg;

assign m_axis_rq_tdata = m_axis_rq_tdata_reg;
assign m_axis_rq_tkeep = m_axis_rq_tkeep_reg;
assign m_axis_rq_tvalid = m_axis_rq_tvalid_reg;
assign m_axis_rq_tlast = m_axis_rq_tlast_reg;
assign m_axis_rq_tuser = m_axis_rq_tuser_reg;

always @(posedge clk) begin
    m_axis_rq_tvalid_reg <= m_axis_rq_tvalid_reg && !m_axis_rq_tready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axis_rq_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tdata_int;
        out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tkeep_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tlast_int;
        out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tuser_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axis_rq_tvalid_reg || m_axis_rq_tready)) begin
        m_axis_rq_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_rq_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_rq_tvalid_reg <= 1'b1;
        m_axis_rq_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_rq_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axis_rq_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
