/*

Copyright (c) 2019 Alex Forencich

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

`timescale 1ns / 1ps

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

localparam [2:0]
    TLP_STATE_IDLE = 3'd0,
    TLP_STATE_HEADER_1 = 3'd1,
    TLP_STATE_HEADER_2 = 3'd2,
    TLP_STATE_TRANSFER = 3'd3,
    TLP_STATE_PASSTHROUGH = 3'd4;

reg [2:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

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

reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_wr_ptr_reg = 0;
reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_rd_ptr_reg = 0, mask_fifo_rd_ptr_next;
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
reg                                m_axis_rq_tready_int_reg = 1'b0;
reg                                m_axis_rq_tlast_int;
reg  [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser_int;
wire                               m_axis_rq_tready_int_early;

assign s_axis_rq_tready = s_axis_rq_tready_reg;

assign m_axis_rq_seq_num_0 = s_axis_rq_seq_num_0 & SEQ_NUM_MASK;
assign m_axis_rq_seq_num_valid_0 = s_axis_rq_seq_num_valid_0 && (s_axis_rq_seq_num_0 & SEQ_NUM_FLAG);
assign m_axis_rq_seq_num_1 = s_axis_rq_seq_num_1 & SEQ_NUM_MASK;
assign m_axis_rq_seq_num_valid_1 = s_axis_rq_seq_num_valid_1 && (s_axis_rq_seq_num_1 & SEQ_NUM_FLAG);

wire axis_rq_seq_num_valid_0_int = s_axis_rq_seq_num_valid_0 && !(s_axis_rq_seq_num_0 & SEQ_NUM_FLAG);
wire axis_rq_seq_num_valid_1_int = s_axis_rq_seq_num_valid_1 && !(s_axis_rq_seq_num_1 & SEQ_NUM_FLAG);

assign s_axis_write_desc_ready = s_axis_write_desc_ready_reg;

assign m_axis_write_desc_status_tag = m_axis_write_desc_status_tag_reg;
assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

assign ram_rd_cmd_sel = ram_rd_cmd_sel_reg;
assign ram_rd_cmd_addr = ram_rd_cmd_addr_reg;
assign ram_rd_cmd_valid = ram_rd_cmd_valid_reg;
assign ram_rd_resp_ready = ram_rd_resp_ready_cmb;

// operation tag management
reg [OP_TAG_WIDTH+1-1:0] op_table_start_ptr_reg = 0;
reg [PCIE_ADDR_WIDTH-1:0] op_table_start_pcie_addr;
reg [11:0] op_table_start_len;
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
reg [PCIE_ADDR_WIDTH-1:0] op_table_pcie_addr[2**OP_TAG_WIDTH-1:0];
reg [11:0] op_table_len[2**OP_TAG_WIDTH-1:0];
reg [9:0] op_table_dword_len[2**OP_TAG_WIDTH-1:0];
reg [CYCLE_COUNT_WIDTH-1:0] op_table_cycle_count[2**OP_TAG_WIDTH-1:0];
reg [RAM_OFFSET_WIDTH-1:0] op_table_offset[2**OP_TAG_WIDTH-1:0];
reg [TAG_WIDTH-1:0] op_table_tag[2**OP_TAG_WIDTH-1:0];
reg op_table_last[2**OP_TAG_WIDTH-1:0];

integer i;

initial begin
    for (i = 0; i < 2**OP_TAG_WIDTH; i = i + 1) begin
        op_table_pcie_addr[i] = 0;
        op_table_len[i] = 0;
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
    tag_next = tag_reg;

    read_cmd_pcie_addr_next = read_cmd_pcie_addr_reg;
    read_cmd_ram_sel_next = read_cmd_ram_sel_reg;
    read_cmd_ram_addr_next = read_cmd_ram_addr_reg;
    read_cmd_len_next = read_cmd_len_reg;
    read_cmd_cycle_count_next = read_cmd_cycle_count_reg;
    read_cmd_last_cycle_next = read_cmd_last_cycle_reg;
    read_cmd_valid_next = read_cmd_valid_reg && !read_cmd_ready;

    op_table_start_pcie_addr = pcie_addr_reg;
    op_table_start_len = 0;
    op_table_start_dword_len = 0;
    op_table_start_cycle_count = 0;
    if (AXIS_PCIE_DATA_WIDTH >= 256) begin
        op_table_start_offset = 16+pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
    end else begin
        op_table_start_offset = pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
    end
    op_table_start_tag = tag_reg;
    op_table_start_last = 0;
    op_table_start_en = 1'b0;

    // TLP segmentation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            // idle state, wait for incoming descriptor
            s_axis_write_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;

            pcie_addr_next = s_axis_write_desc_pcie_addr;
            ram_sel_next = s_axis_write_desc_ram_sel;
            ram_addr_next = s_axis_write_desc_ram_addr;
            op_count_next = s_axis_write_desc_len;
            tag_next = s_axis_write_desc_tag;

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
                read_cmd_len_next = tlp_count_next;
                if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                    read_cmd_cycle_count_next = (tlp_count_next + 16+pcie_addr_reg[1:0] - 1) >> $clog2(AXIS_PCIE_DATA_WIDTH/8);
                    end else begin
                    read_cmd_cycle_count_next = (tlp_count_next + pcie_addr_reg[1:0] - 1) >> $clog2(AXIS_PCIE_DATA_WIDTH/8);
                end
                op_table_start_cycle_count = read_cmd_cycle_count_next;
                read_cmd_last_cycle_next = read_cmd_cycle_count_next == 0;
                read_cmd_valid_next = 1'b1;

                pcie_addr_next = pcie_addr_reg + tlp_count_next;
                ram_addr_next = ram_addr_reg + tlp_count_next;
                op_count_next = op_count_reg - tlp_count_next;

                op_table_start_pcie_addr = pcie_addr_reg;
                op_table_start_len = tlp_count_next;
                op_table_start_dword_len = (tlp_count_next + pcie_addr_reg[1:0] + 3) >> 2;
                if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                    op_table_start_offset = 16+pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
                end else begin
                    op_table_start_offset = pcie_addr_reg[1:0]-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
                end
                op_table_start_last = op_count_reg == tlp_count_next;

                op_table_start_tag = tag_reg;
                op_table_start_en = 1'b1;

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
                    if (read_ram_mask_0_reg[i]) begin
                        ram_rd_cmd_sel_next[i*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = read_ram_sel_reg;
                        ram_rd_cmd_addr_next[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH];
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                    if (read_ram_mask_1_reg[i]) begin
                        ram_rd_cmd_sel_next[i*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = read_ram_sel_reg;
                        ram_rd_cmd_addr_next[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]+1;
                        ram_rd_cmd_valid_next[i] = 1'b1;
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
                end else if (read_cmd_valid_reg) begin

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

                    read_cmd_ready = 1'b1;

                    read_state_next = READ_STATE_READ;
                end else begin
                    read_state_next = READ_STATE_IDLE;
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

    m_axis_write_desc_status_tag_next = m_axis_write_desc_status_tag_reg;
    m_axis_write_desc_status_valid_next = 1'b0;

    ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

    tlp_addr_next = tlp_addr_reg;
    tlp_len_next = tlp_len_reg;
    dword_count_next = dword_count_reg;
    offset_next = offset_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_valid_next = ram_mask_valid_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg;

    op_table_tx_start_en = 1'b0;
    op_table_tx_finish_en = 1'b0;

    inc_active_tx = 1'b0;

    s_axis_rq_tready_next = 1'b0;

    m_axis_rq_tdata_int = {AXIS_PCIE_DATA_WIDTH{1'b0}};
    m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
    m_axis_rq_tvalid_int = 1'b0;
    m_axis_rq_tlast_int = 1'b0;
    m_axis_rq_tuser_int = {AXIS_PCIE_RQ_USER_WIDTH{1'b0}};

    m_axis_rq_tdata_int[1:0] = 2'b0; // address type
    m_axis_rq_tdata_int[63:2] = tlp_addr_reg[PCIE_ADDR_WIDTH-1:2]; // address
    if (AXIS_PCIE_DATA_WIDTH > 64) begin
        m_axis_rq_tdata_int[74:64] = dword_count_reg; // DWORD count
        m_axis_rq_tdata_int[78:75] = REQ_MEM_WRITE; // request type - memory write
        m_axis_rq_tdata_int[79] = 1'b0; // poisoned request
        m_axis_rq_tdata_int[95:80] = requester_id;
        m_axis_rq_tdata_int[103:96] = 8'd0; // tag
        m_axis_rq_tdata_int[119:104] = 16'd0; // completer ID
        m_axis_rq_tdata_int[120] = requester_id_enable; // requester ID enable
        m_axis_rq_tdata_int[123:121] = 3'b000; // traffic class
        m_axis_rq_tdata_int[126:124] = 3'b000; // attr
        m_axis_rq_tdata_int[127] = 1'b0; // force ECRC
    end

    if (AXIS_PCIE_DATA_WIDTH == 256) begin
        m_axis_rq_tkeep_int = 8'b00001111;
    end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
        m_axis_rq_tkeep_int = 4'b1111;
    end else if (AXIS_PCIE_DATA_WIDTH == 64) begin
        m_axis_rq_tkeep_int = 2'b11;
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        m_axis_rq_tuser_int[3:0] = dword_count_reg == 1 ? first_be & last_be : first_be; // first BE 0
        m_axis_rq_tuser_int[7:4] = 4'd0; // first BE 1
        m_axis_rq_tuser_int[11:8] = dword_count_reg == 1 ? 4'b0000 : last_be; // last BE 0
        m_axis_rq_tuser_int[15:12] = 4'd0; // last BE 1
        m_axis_rq_tuser_int[19:16] = 3'd0; // addr_offset
        m_axis_rq_tuser_int[21:20] = 2'b01; // is_sop
        m_axis_rq_tuser_int[23:22] = 2'd0; // is_sop0_ptr
        m_axis_rq_tuser_int[25:24] = 2'd0; // is_sop1_ptr
        m_axis_rq_tuser_int[27:26] = 2'b01; // is_eop
        m_axis_rq_tuser_int[31:28]  = 4'd3; // is_eop0_ptr
        m_axis_rq_tuser_int[35:32] = 4'd0; // is_eop1_ptr
        m_axis_rq_tuser_int[36] = 1'b0; // discontinue
        m_axis_rq_tuser_int[38:37] = 2'b00; // tph_present
        m_axis_rq_tuser_int[42:39] = 4'b0000; // tph_type
        m_axis_rq_tuser_int[44:43] = 2'b00; // tph_indirect_tag_en
        m_axis_rq_tuser_int[60:45] = 16'd0; // tph_st_tag
        m_axis_rq_tuser_int[66:61] = op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0] & SEQ_NUM_MASK; // seq_num0
        m_axis_rq_tuser_int[72:67] = 6'd0; // seq_num1
        m_axis_rq_tuser_int[136:73] = 64'd0; // parity
    end else begin
        m_axis_rq_tuser_int[3:0] = dword_count_reg == 1 ? first_be & last_be : first_be; // first BE
        m_axis_rq_tuser_int[7:4] = dword_count_reg == 1 ? 4'b0000 : last_be; // last BE
        m_axis_rq_tuser_int[10:8] = 3'd0; // addr_offset
        m_axis_rq_tuser_int[11] = 1'b0; // discontinue
        m_axis_rq_tuser_int[12] = 1'b0; // tph_present
        m_axis_rq_tuser_int[14:13] = 2'b00; // tph_type
        m_axis_rq_tuser_int[15] = 1'b0; // tph_indirect_tag_en
        m_axis_rq_tuser_int[23:16] = 8'd0; // tph_st_tag
        m_axis_rq_tuser_int[27:24] = op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0] & SEQ_NUM_MASK; // seq_num
        m_axis_rq_tuser_int[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_WIDTH == 62) begin
            m_axis_rq_tuser_int[61:60] = (op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0] & SEQ_NUM_MASK) >> 4; // seq_num
        end
    end

    // read response processing and TLP generation
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for command
            s_axis_rq_tready_next = m_axis_rq_tready_int_early;

            // pass through read request TLP
            m_axis_rq_tdata_int = s_axis_rq_tdata;
            m_axis_rq_tkeep_int = s_axis_rq_tkeep;
            m_axis_rq_tvalid_int = s_axis_rq_tready && s_axis_rq_tvalid;
            m_axis_rq_tlast_int = s_axis_rq_tlast;
            m_axis_rq_tuser_int = s_axis_rq_tuser;
            if (AXIS_PCIE_DATA_WIDTH == 512) begin
                m_axis_rq_tuser_int[61+RQ_SEQ_NUM_WIDTH-1] = 1'b1;
            end else begin
                if (RQ_SEQ_NUM_WIDTH > 4) begin
                    m_axis_rq_tuser_int[60+RQ_SEQ_NUM_WIDTH-4-1] = 1'b1;
                end else begin
                    m_axis_rq_tuser_int[24+RQ_SEQ_NUM_WIDTH-1] = 1'b1;
                end
            end

            ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

            tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

            if (s_axis_rq_tready && s_axis_rq_tvalid) begin
                // pass through read request TLP
                if (s_axis_rq_tlast) begin
                    tlp_state_next = TLP_STATE_IDLE;
                end else begin
                    tlp_state_next = TLP_STATE_PASSTHROUGH;
                end
            end else if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && (!TX_FC_ENABLE || have_credit_reg) && (!RQ_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                s_axis_rq_tready_next = 1'b0;
                op_table_tx_start_en = 1'b1;
                tlp_state_next = TLP_STATE_HEADER_1;
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_HEADER_1: begin
            // header 1 state, send TLP header
            if (AXIS_PCIE_DATA_WIDTH >= 256) begin

                ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

                if (!(ram_mask_reg & ~ram_rd_resp_valid) && ram_mask_valid_reg && m_axis_rq_tready_int_reg) begin
                    // transfer in read data
                    ram_rd_resp_ready_cmb = ram_mask_reg;
                    ram_mask_valid_next = 1'b0;

                    // update counters
                    dword_count_next = dword_count_reg - (AXIS_PCIE_KEEP_WIDTH-4);
                    cycle_count_next = cycle_count_reg - 1;
                    last_cycle_next = cycle_count_next == 0;
                    offset_next = offset_reg + AXIS_PCIE_DATA_WIDTH/8;

                    m_axis_rq_tdata_int[AXIS_PCIE_DATA_WIDTH-1:128] = {2{ram_rd_resp_data}} >> (SEG_COUNT*SEG_DATA_WIDTH-offset_reg*8 + 128);
                    m_axis_rq_tvalid_int = 1'b1;
                    if (dword_count_reg >= AXIS_PCIE_KEEP_WIDTH-4) begin
                        m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}};
                    end else begin
                        m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}} >> (AXIS_PCIE_KEEP_WIDTH-4 - dword_count_reg);
                    end

                    inc_active_tx = 1'b1;

                    if (last_cycle_reg) begin
                        m_axis_rq_tlast_int = 1'b1;
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
                            tlp_state_next = TLP_STATE_HEADER_1;
                        end else begin
                            s_axis_rq_tready_next = m_axis_rq_tready_int_early;
                            tlp_state_next = TLP_STATE_IDLE;
                        end
                    end else begin
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER_1;
                end
            end else begin
                if (m_axis_rq_tready_int_reg) begin
                    m_axis_rq_tvalid_int = 1'b1;

                    inc_active_tx = 1'b1;

                    if (AXIS_PCIE_DATA_WIDTH == 128) begin
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end else begin
                        tlp_state_next = TLP_STATE_HEADER_2;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER_1;
                end
            end
        end
        TLP_STATE_HEADER_2: begin
            // header 2 state, send rest of TLP header (64 bit interface only)
            if (m_axis_rq_tready_int_reg) begin
                m_axis_rq_tdata_int[10:0] = dword_count_reg; // DWORD count
                m_axis_rq_tdata_int[14:11] = 4'b0001; // request type - memory write
                m_axis_rq_tdata_int[15] = 1'b0; // poisoned request
                m_axis_rq_tdata_int[31:16] = requester_id;
                m_axis_rq_tdata_int[39:32] = 8'd0; // tag
                m_axis_rq_tdata_int[55:40] = 16'd0; // completer ID
                m_axis_rq_tdata_int[56] = requester_id_enable; // requester ID enable
                m_axis_rq_tdata_int[59:57] = 3'b000; // traffic class
                m_axis_rq_tdata_int[62:60] = 3'b000; // attr
                m_axis_rq_tdata_int[63] = 1'b0; // force ECRC
                m_axis_rq_tvalid_int = 1'b1;
                m_axis_rq_tkeep_int = 2'b11;

                tlp_state_next = TLP_STATE_TRANSFER;
            end else begin
                tlp_state_next = TLP_STATE_HEADER_2;
            end
        end
        TLP_STATE_TRANSFER: begin
            // transfer state, transfer data

            ram_rd_resp_ready_cmb = {SEG_COUNT{1'b0}};

            if (!(ram_mask_reg & ~ram_rd_resp_valid) && ram_mask_valid_reg && m_axis_rq_tready_int_reg) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;
                ram_mask_valid_next = 1'b0;

                // update counters
                dword_count_next = dword_count_reg - AXIS_PCIE_KEEP_WIDTH;
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;
                offset_next = offset_reg + AXIS_PCIE_DATA_WIDTH/8;

                m_axis_rq_tdata_int = {2{ram_rd_resp_data}} >> (SEG_COUNT*SEG_DATA_WIDTH-offset_reg*8);
                m_axis_rq_tvalid_int = 1'b1;
                if (dword_count_reg >= AXIS_PCIE_KEEP_WIDTH) begin
                    m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}};
                end else begin
                    m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}} >> (AXIS_PCIE_KEEP_WIDTH - dword_count_reg);
                end

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    m_axis_rq_tlast_int = 1'b1;
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
                        tlp_state_next = TLP_STATE_HEADER_1;
                    end else begin
                        s_axis_rq_tready_next = m_axis_rq_tready_int_early;
                        tlp_state_next = TLP_STATE_IDLE;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_TRANSFER;
                end
            end else begin
                tlp_state_next = TLP_STATE_TRANSFER;
            end
        end
        TLP_STATE_PASSTHROUGH: begin
            // passthrough state, pass through read request TLP
            s_axis_rq_tready_next = m_axis_rq_tready_int_early;

            // pass through read request TLP
            m_axis_rq_tdata_int = s_axis_rq_tdata;
            m_axis_rq_tkeep_int = s_axis_rq_tkeep;
            m_axis_rq_tvalid_int = s_axis_rq_tready && s_axis_rq_tvalid;
            m_axis_rq_tlast_int = s_axis_rq_tlast;
            m_axis_rq_tuser_int = s_axis_rq_tuser;
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
                tlp_state_next = TLP_STATE_IDLE;
            end else begin
                tlp_state_next = TLP_STATE_PASSTHROUGH;
            end
        end
    endcase

    if (!ram_mask_valid_next && !mask_fifo_empty) begin
        ram_mask_next = mask_fifo_mask[mask_fifo_rd_ptr_reg[MASK_FIFO_ADDR_WIDTH-1:0]];
        ram_mask_valid_next = 1'b1;
        mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg+1;
    end

    op_table_finish_en = 1'b0;

    if (op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] && (!RQ_SEQ_NUM_ENABLE || op_table_tx_done[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) && op_table_finish_ptr_reg != op_table_tx_finish_ptr_reg) begin
        op_table_finish_en = 1'b1;

        if (op_table_last[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) begin
            m_axis_write_desc_status_tag_next = op_table_tag[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]];
            m_axis_write_desc_status_valid_next = 1'b1;
        end
    end
end

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

        read_cmd_valid_reg <= 1'b0;

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

reg [AXIS_PCIE_DATA_WIDTH-1:0]    temp_m_axis_rq_tdata_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    temp_m_axis_rq_tkeep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg                               temp_m_axis_rq_tvalid_reg = 1'b0, temp_m_axis_rq_tvalid_next;
reg                               temp_m_axis_rq_tlast_reg = 1'b0;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] temp_m_axis_rq_tuser_reg = {AXIS_PCIE_RQ_USER_WIDTH{1'b0}};

// datapath control
reg store_axis_rq_int_to_output;
reg store_axis_rq_int_to_temp;
reg store_axis_rq_temp_to_output;

assign m_axis_rq_tdata = m_axis_rq_tdata_reg;
assign m_axis_rq_tkeep = m_axis_rq_tkeep_reg;
assign m_axis_rq_tvalid = m_axis_rq_tvalid_reg;
assign m_axis_rq_tlast = m_axis_rq_tlast_reg;
assign m_axis_rq_tuser = m_axis_rq_tuser_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_rq_tready_int_early = m_axis_rq_tready || (!temp_m_axis_rq_tvalid_reg && (!m_axis_rq_tvalid_reg || !m_axis_rq_tvalid_int));

always @* begin
    // transfer sink ready state to source
    m_axis_rq_tvalid_next = m_axis_rq_tvalid_reg;
    temp_m_axis_rq_tvalid_next = temp_m_axis_rq_tvalid_reg;

    store_axis_rq_int_to_output = 1'b0;
    store_axis_rq_int_to_temp = 1'b0;
    store_axis_rq_temp_to_output = 1'b0;

    if (m_axis_rq_tready_int_reg) begin
        // input is ready
        if (m_axis_rq_tready || !m_axis_rq_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_rq_tvalid_next = m_axis_rq_tvalid_int;
            store_axis_rq_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_rq_tvalid_next = m_axis_rq_tvalid_int;
            store_axis_rq_int_to_temp = 1'b1;
        end
    end else if (m_axis_rq_tready) begin
        // input is not ready, but output is ready
        m_axis_rq_tvalid_next = temp_m_axis_rq_tvalid_reg;
        temp_m_axis_rq_tvalid_next = 1'b0;
        store_axis_rq_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_rq_tvalid_reg <= 1'b0;
        m_axis_rq_tready_int_reg <= 1'b0;
        temp_m_axis_rq_tvalid_reg <= 1'b0;
    end else begin
        m_axis_rq_tvalid_reg <= m_axis_rq_tvalid_next;
        m_axis_rq_tready_int_reg <= m_axis_rq_tready_int_early;
        temp_m_axis_rq_tvalid_reg <= temp_m_axis_rq_tvalid_next;
    end

    // datapath
    if (store_axis_rq_int_to_output) begin
        m_axis_rq_tdata_reg <= m_axis_rq_tdata_int;
        m_axis_rq_tkeep_reg <= m_axis_rq_tkeep_int;
        m_axis_rq_tlast_reg <= m_axis_rq_tlast_int;
        m_axis_rq_tuser_reg <= m_axis_rq_tuser_int;
    end else if (store_axis_rq_temp_to_output) begin
        m_axis_rq_tdata_reg <= temp_m_axis_rq_tdata_reg;
        m_axis_rq_tkeep_reg <= temp_m_axis_rq_tkeep_reg;
        m_axis_rq_tlast_reg <= temp_m_axis_rq_tlast_reg;
        m_axis_rq_tuser_reg <= temp_m_axis_rq_tuser_reg;
    end

    if (store_axis_rq_int_to_temp) begin
        temp_m_axis_rq_tdata_reg <= m_axis_rq_tdata_int;
        temp_m_axis_rq_tkeep_reg <= m_axis_rq_tkeep_int;
        temp_m_axis_rq_tlast_reg <= m_axis_rq_tlast_int;
        temp_m_axis_rq_tuser_reg <= m_axis_rq_tuser_int;
    end
end

endmodule
