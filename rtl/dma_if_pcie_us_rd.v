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
 * Ultrascale PCIe DMA read interface
 */
module dma_if_pcie_us_rd #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream RC tuser signal width
    parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161,
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
    // PCIe tag count
    parameter PCIE_TAG_COUNT = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 64 : 256,
    // PCIe tag field width
    parameter PCIE_TAG_WIDTH = $clog2(PCIE_TAG_COUNT),
    // Support PCIe extended tags
    parameter PCIE_EXT_TAG_ENABLE = (PCIE_TAG_COUNT>32),
    // Length field width
    parameter LEN_WIDTH = 16,
    // Tag field width
    parameter TAG_WIDTH = 8,
    // Operation table size
    parameter OP_TABLE_SIZE = PCIE_TAG_COUNT,
    // In-flight transmit limit
    parameter TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1),
    // Transmit flow control
    parameter TX_FC_ENABLE = 0
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * AXI input (RC)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]      s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]      s_axis_rc_tkeep,
    input  wire                                 s_axis_rc_tvalid,
    output wire                                 s_axis_rc_tready,
    input  wire                                 s_axis_rc_tlast,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0]   s_axis_rc_tuser,

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
     * Transmit flow control
     */
    input  wire [7:0]                           pcie_tx_fc_nph_av,

    /*
     * AXI read descriptor input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]           s_axis_read_desc_pcie_addr,
    input  wire [RAM_SEL_WIDTH-1:0]             s_axis_read_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]            s_axis_read_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                 s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]                 s_axis_read_desc_tag,
    input  wire                                 s_axis_read_desc_valid,
    output wire                                 s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                 m_axis_read_desc_status_tag,
    output wire                                 m_axis_read_desc_status_valid,

    /*
     * RAM interface
     */
    output wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]   ram_wr_cmd_sel,
    output wire [SEG_COUNT*SEG_BE_WIDTH-1:0]    ram_wr_cmd_be,
    output wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  ram_wr_cmd_addr,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  ram_wr_cmd_data,
    output wire [SEG_COUNT-1:0]                 ram_wr_cmd_valid,
    input  wire [SEG_COUNT-1:0]                 ram_wr_cmd_ready,

    /*
     * Configuration
     */
    input  wire                                 enable,
    input  wire                                 ext_tag_enable,
    input  wire [15:0]                          requester_id,
    input  wire                                 requester_id_enable,
    input  wire [2:0]                           max_read_request_size,

    /*
     * Status
     */
    output wire                                 status_error_cor,
    output wire                                 status_error_uncor
);

parameter RAM_WORD_WIDTH = SEG_BE_WIDTH;
parameter RAM_WORD_SIZE = SEG_DATA_WIDTH/RAM_WORD_WIDTH;

parameter AXIS_PCIE_WORD_WIDTH = AXIS_PCIE_KEEP_WIDTH;
parameter AXIS_PCIE_WORD_SIZE = AXIS_PCIE_DATA_WIDTH/AXIS_PCIE_WORD_WIDTH;

parameter OFFSET_WIDTH = $clog2(AXIS_PCIE_DATA_WIDTH/8);
parameter RAM_OFFSET_WIDTH = $clog2(SEG_COUNT*SEG_DATA_WIDTH/8);

parameter OP_TAG_WIDTH = $clog2(OP_TABLE_SIZE);
parameter OP_TABLE_READ_COUNT_WIDTH = PCIE_TAG_WIDTH+1;
parameter OP_TABLE_WRITE_COUNT_WIDTH = LEN_WIDTH;

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
        if (AXIS_PCIE_RC_USER_WIDTH != 161) begin
            $error("Error: PCIe RC tuser width must be 161 (instance %m)");
            $finish;
        end

        if (AXIS_PCIE_RQ_USER_WIDTH != 137) begin
            $error("Error: PCIe RQ tuser width must be 137 (instance %m)");
            $finish;
        end
    end else begin
        if (AXIS_PCIE_RC_USER_WIDTH != 75) begin
            $error("Error: PCIe RC tuser width must be 75 (instance %m)");
            $finish;
        end

        if (AXIS_PCIE_RQ_USER_WIDTH != 60 && AXIS_PCIE_RQ_USER_WIDTH != 62) begin
            $error("Error: PCIe RQ tuser width must be 60 or 62 (instance %m)");
            $finish;
        end
    end

    if (AXIS_PCIE_RQ_USER_WIDTH == 60) begin
        if (RQ_SEQ_NUM_ENABLE && RQ_SEQ_NUM_WIDTH != 4) begin
            $error("Error: RQ sequence number width must be 4 (instance %m)");
            $finish;
        end

        if (PCIE_TAG_COUNT > 64) begin
            $error("Error: PCIe tag count must be no larger than 64 (instance %m)");
            $finish;
        end
    end else begin
        if (RQ_SEQ_NUM_ENABLE && RQ_SEQ_NUM_WIDTH != 6) begin
            $error("Error: RQ sequence number width must be 6 (instance %m)");
            $finish;
        end

        if (PCIE_TAG_COUNT > 256) begin
            $error("Error: PCIe tag count must be no larger than 256 (instance %m)");
            $finish;
        end
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

localparam [4:0]
    RC_ERROR_NORMAL_TERMINATION = 4'b0000,
    RC_ERROR_POISONED = 4'b0001,
    RC_ERROR_BAD_STATUS = 4'b0010,
    RC_ERROR_INVALID_LENGTH = 4'b0011,
    RC_ERROR_MISMATCH = 4'b0100,
    RC_ERROR_INVALID_ADDRESS = 4'b0101,
    RC_ERROR_INVALID_TAG = 4'b0110,
    RC_ERROR_TIMEOUT = 4'b1001,
    RC_ERROR_FLR = 4'b1000;

localparam [1:0]
    REQ_STATE_IDLE = 2'd0,
    REQ_STATE_START = 2'd1,
    REQ_STATE_HEADER = 2'd2;

reg [1:0] req_state_reg = REQ_STATE_IDLE, req_state_next;

localparam [1:0]
    TLP_STATE_IDLE = 3'd0,
    TLP_STATE_HEADER = 3'd1,
    TLP_STATE_WRITE = 3'd2,
    TLP_STATE_WAIT_END = 3'd3;

reg [1:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

// // datapath control signals
reg tag_table_we_req;

reg tlp_cmd_ready;

reg last_cycle;

reg [3:0] first_be;
reg [3:0] last_be;
reg [10:0] dword_count;
reg req_last_tlp;
reg [PCIE_ADDR_WIDTH-1:0] req_pcie_addr;

reg [PCIE_ADDR_WIDTH-1:0] req_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, req_pcie_addr_next;
reg [RAM_ADDR_WIDTH-1:0] req_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, req_addr_next;
reg [LEN_WIDTH-1:0] req_op_count_reg = {LEN_WIDTH{1'b0}}, req_op_count_next;
reg [12:0] req_tlp_count_reg = 13'd0, req_tlp_count_next;

reg [11:0] lower_addr_reg = 12'd0, lower_addr_next;
reg [12:0] byte_count_reg = 13'd0, byte_count_next;
reg [3:0] error_code_reg = 4'd0, error_code_next;
reg [RAM_SEL_WIDTH-1:0] ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] addr_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_next;
reg [RAM_ADDR_WIDTH-1:0] addr_delay_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_delay_next;
reg addr_valid_reg = 1'b0, addr_valid_next;
reg [9:0] op_dword_count_reg = 10'd0, op_dword_count_next;
reg [12:0] op_count_reg = 13'd0, op_count_next;
reg [SEG_COUNT-1:0] ram_mask_reg = {SEG_COUNT{1'b0}}, ram_mask_next;
reg [SEG_COUNT-1:0] ram_mask_0_reg = {SEG_COUNT{1'b0}}, ram_mask_0_next;
reg [SEG_COUNT-1:0] ram_mask_1_reg = {SEG_COUNT{1'b0}}, ram_mask_1_next;
reg ram_wrap_reg = 1'b0, ram_wrap_next;
reg [OFFSET_WIDTH+1-1:0] cycle_byte_count_reg = {OFFSET_WIDTH+1{1'b0}}, cycle_byte_count_next;
reg [RAM_OFFSET_WIDTH-1:0] start_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, start_offset_next;
reg [RAM_OFFSET_WIDTH-1:0] end_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, end_offset_next;
reg [PCIE_TAG_WIDTH-1:0] pcie_tag_reg = {PCIE_TAG_WIDTH{1'b0}}, pcie_tag_next;
reg [OP_TAG_WIDTH-1:0] op_tag_reg = {OP_TAG_WIDTH{1'b0}}, op_tag_next;
reg final_cpl_reg = 1'b0, final_cpl_next;
reg finish_tag_reg = 1'b0, finish_tag_next;

reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;

reg [AXIS_PCIE_DATA_WIDTH-1:0] rc_tdata_int_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}}, rc_tdata_int_next;
reg rc_tvalid_int_reg = 1'b0, rc_tvalid_int_next;

reg [RAM_SEL_WIDTH-1:0] tlp_cmd_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, tlp_cmd_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] tlp_cmd_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, tlp_cmd_addr_next;
reg [OP_TAG_WIDTH-1:0] tlp_cmd_op_tag_reg = {OP_TAG_WIDTH{1'b0}}, tlp_cmd_op_tag_next;
reg [TAG_WIDTH-1:0] tlp_cmd_tag_reg = {TAG_WIDTH{1'b0}}, tlp_cmd_tag_next;
reg [PCIE_TAG_WIDTH-1:0] tlp_cmd_pcie_tag_reg = {PCIE_TAG_WIDTH{1'b0}}, tlp_cmd_pcie_tag_next;
reg tlp_cmd_last_reg = 1'b0, tlp_cmd_last_next;
reg tlp_cmd_valid_reg = 1'b0, tlp_cmd_valid_next;

reg [RAM_SEL_WIDTH-1:0] tag_table_sel[(2**PCIE_TAG_WIDTH)-1:0];
reg [RAM_ADDR_WIDTH-1:0] tag_table_addr[(2**PCIE_TAG_WIDTH)-1:0];
reg [OP_TAG_WIDTH-1:0] tag_table_op_tag[(2**PCIE_TAG_WIDTH)-1:0];
reg tag_table_we_tlp_reg = 1'b0, tag_table_we_tlp_next;

reg [10:0] max_read_request_size_dw_reg = 11'd0;

reg have_credit_reg = 1'b0;

reg [RQ_SEQ_NUM_WIDTH-1:0] active_tx_count_reg = {RQ_SEQ_NUM_WIDTH{1'b0}};
reg active_tx_count_av_reg = 1'b1;
reg inc_active_tx;

reg s_axis_rc_tready_reg = 1'b0, s_axis_rc_tready_next;
reg s_axis_read_desc_ready_reg = 1'b0, s_axis_read_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_read_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_read_desc_status_tag_next;
reg m_axis_read_desc_status_valid_reg = 1'b0, m_axis_read_desc_status_valid_next;

reg status_error_cor_reg = 1'b0, status_error_cor_next;
reg status_error_uncor_reg = 1'b0, status_error_uncor_next;

// internal datapath
reg  [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata_int;
reg  [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep_int;
reg                                m_axis_rq_tvalid_int;
reg                                m_axis_rq_tready_int_reg = 1'b0;
reg                                m_axis_rq_tlast_int;
reg  [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser_int;
wire                               m_axis_rq_tready_int_early;

reg  [SEG_COUNT*RAM_SEL_WIDTH-1:0]  ram_wr_cmd_sel_int;
reg  [SEG_COUNT*SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_int;
reg  [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_int;
reg  [SEG_COUNT*SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_int;
reg  [SEG_COUNT-1:0]                ram_wr_cmd_valid_int;
reg  [SEG_COUNT-1:0]                ram_wr_cmd_ready_int_reg = 1'b0;
wire [SEG_COUNT-1:0]                ram_wr_cmd_ready_int_early;

assign s_axis_rc_tready = s_axis_rc_tready_reg;
assign s_axis_read_desc_ready = s_axis_read_desc_ready_reg;

assign m_axis_read_desc_status_tag = m_axis_read_desc_status_tag_reg;
assign m_axis_read_desc_status_valid = m_axis_read_desc_status_valid_reg;

assign status_error_cor = status_error_cor_reg;
assign status_error_uncor = status_error_uncor_reg;

wire [PCIE_ADDR_WIDTH-1:0] req_pcie_addr_plus_max_read_request = req_pcie_addr_reg + {max_read_request_size_dw_reg, 2'b00};
wire [PCIE_ADDR_WIDTH-1:0] req_pcie_addr_plus_op_count = req_pcie_addr_reg + req_op_count_reg;

// PCIe tag management
wire [PCIE_TAG_WIDTH-1:0] new_tag;
wire new_tag_valid;
reg new_tag_ready;

wire [PCIE_TAG_COUNT-1:0] active_tags;

pcie_tag_manager #(
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .PCIE_TAG_WIDTH(PCIE_TAG_WIDTH),
    .PCIE_EXT_TAG_ENABLE(PCIE_EXT_TAG_ENABLE)
)
pcie_tag_manager_inst (
    .clk(clk),
    .rst(rst),

    .m_axis_tag(new_tag),
    .m_axis_tag_valid(new_tag_valid),
    .m_axis_tag_ready(new_tag_ready),

    .s_axis_tag(pcie_tag_reg),
    .s_axis_tag_valid(finish_tag_reg),

    .ext_tag_enable(ext_tag_enable),

    .active_tags(active_tags)
);

// operation tag management
wire [OP_TAG_WIDTH-1:0] op_table_start_ptr;
wire op_table_start_ptr_valid;
reg [TAG_WIDTH-1:0] op_table_start_tag;
reg op_table_start_en;
reg [OP_TAG_WIDTH-1:0] op_table_finish_ptr;
reg op_table_finish_en;
reg [OP_TAG_WIDTH-1:0] op_table_read_start_ptr;
reg op_table_read_start_commit;
reg op_table_read_start_en;
reg [OP_TAG_WIDTH-1:0] op_table_read_finish_ptr;
reg op_table_read_finish_en;

reg [2**OP_TAG_WIDTH-1:0] op_table_active = 0;
reg [TAG_WIDTH-1:0] op_table_tag [2**OP_TAG_WIDTH-1:0];
reg op_table_init [2**OP_TAG_WIDTH-1:0];
reg op_table_read_init [2**OP_TAG_WIDTH-1:0];
reg op_table_read_commit [2**OP_TAG_WIDTH-1:0];
reg [OP_TABLE_READ_COUNT_WIDTH-1:0] op_table_read_count_start [2**OP_TAG_WIDTH-1:0];
reg [OP_TABLE_READ_COUNT_WIDTH-1:0] op_table_read_count_finish [2**OP_TAG_WIDTH-1:0];

priority_encoder #(
    .WIDTH(2**OP_TAG_WIDTH),
    .LSB_PRIORITY("HIGH")
)
op_table_start_ptr_enc_inst (
    .input_unencoded(~op_table_active),
    .output_valid(op_table_start_ptr_valid),
    .output_encoded(op_table_start_ptr),
    .output_unencoded()
);

integer i;

initial begin
    for (i = 0; i < 2**OP_TAG_WIDTH; i = i + 1) begin
        op_table_tag[i] = 0;
        op_table_init[i] = 0;
        op_table_read_init[i] = 0;
        op_table_read_commit[i] = 0;
        op_table_read_count_start[i] = 0;
        op_table_read_count_finish[i] = 0;
    end

    for (i = 0; i < 2**PCIE_TAG_WIDTH; i = i + 1) begin
        tag_table_addr[i] = 0;
        tag_table_op_tag[i] = 0;
    end
end

always @* begin
    req_state_next = REQ_STATE_IDLE;

    s_axis_read_desc_ready_next = 1'b0;

    req_pcie_addr_next = req_pcie_addr_reg;
    req_addr_next = req_addr_reg;
    req_op_count_next = req_op_count_reg;
    req_tlp_count_next = req_tlp_count_reg;

    tlp_cmd_ram_sel_next = tlp_cmd_ram_sel_reg;
    tlp_cmd_addr_next = tlp_cmd_addr_reg;
    tlp_cmd_op_tag_next = tlp_cmd_op_tag_reg;
    tlp_cmd_tag_next = tlp_cmd_tag_reg;
    tlp_cmd_pcie_tag_next = tlp_cmd_pcie_tag_reg;
    tlp_cmd_last_next = tlp_cmd_last_reg;
    tlp_cmd_valid_next = tlp_cmd_valid_reg && !tlp_cmd_ready;

    inc_active_tx = 1'b0;

    m_axis_rq_tdata_int = {AXIS_PCIE_DATA_WIDTH{1'b0}};
    m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
    m_axis_rq_tvalid_int = 1'b0;
    if (AXIS_PCIE_DATA_WIDTH > 64) begin
        m_axis_rq_tlast_int = 1'b1;
    end else begin
        m_axis_rq_tlast_int = 1'b0;
    end
    m_axis_rq_tuser_int = {AXIS_PCIE_RQ_USER_WIDTH{1'b0}};

    m_axis_rq_tdata_int[1:0] = 2'b0; // address type
    m_axis_rq_tdata_int[63:2] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:2]; // address
    if (AXIS_PCIE_DATA_WIDTH > 64) begin
        m_axis_rq_tdata_int[74:64] = 11'd0; // DWORD count
        m_axis_rq_tdata_int[78:75] = REQ_MEM_READ; // request type - memory read
        m_axis_rq_tdata_int[79] = 1'b0; // poisoned request
        m_axis_rq_tdata_int[95:80] = requester_id;
        m_axis_rq_tdata_int[103:96] = new_tag;
        m_axis_rq_tdata_int[119:104] = 16'd0; // completer ID
        m_axis_rq_tdata_int[120] = requester_id_enable;
        m_axis_rq_tdata_int[123:121] = 3'b000; // traffic class
        m_axis_rq_tdata_int[126:124] = 3'b000; // attr
        m_axis_rq_tdata_int[127] = 1'b0; // force ECRC
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        m_axis_rq_tkeep_int = 16'b0000000000001111;
    end else if (AXIS_PCIE_DATA_WIDTH == 256) begin
        m_axis_rq_tkeep_int = 8'b00001111;
    end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
        m_axis_rq_tkeep_int = 4'b1111;
    end else begin
        m_axis_rq_tkeep_int = 2'b11;
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        m_axis_rq_tuser_int[3:0] = 4'd0; // first BE 0
        m_axis_rq_tuser_int[7:4] = 4'd0; // first BE 1
        m_axis_rq_tuser_int[11:8] = 4'd0; // last BE 0
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
        m_axis_rq_tuser_int[66:61] = 6'd0; // seq_num0
        m_axis_rq_tuser_int[72:67] = 6'd0; // seq_num1
        m_axis_rq_tuser_int[136:73] = 64'd0; // parity
    end else begin
        m_axis_rq_tuser_int[3:0] = 4'd0; // first BE
        m_axis_rq_tuser_int[7:4] = 4'd0; // last BE
        m_axis_rq_tuser_int[10:8] = 3'd0; // addr_offset
        m_axis_rq_tuser_int[11] = 1'b0; // discontinue
        m_axis_rq_tuser_int[12] = 1'b0; // tph_present
        m_axis_rq_tuser_int[14:13] = 2'b00; // tph_type
        m_axis_rq_tuser_int[15] = 1'b0; // tph_indirect_tag_en
        m_axis_rq_tuser_int[23:16] = 8'd0; // tph_st_tag
        m_axis_rq_tuser_int[27:24] = 4'd0; // seq_num
        m_axis_rq_tuser_int[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_WIDTH == 62) begin
            m_axis_rq_tuser_int[61:60] = 2'd0; // seq_num
        end
    end

    new_tag_ready = 1'b0;
    op_table_start_tag = s_axis_read_desc_tag;
    op_table_start_en = 1'b0;

    op_table_read_start_ptr = tlp_cmd_op_tag_reg;
    op_table_read_start_commit = 1'b0;
    op_table_read_start_en = 1'b0;

    // TLP size computation
    if (req_op_count_reg + req_pcie_addr_reg[1:0] <= {max_read_request_size_dw_reg, 2'b00}) begin
        // packet smaller than max read request size
        if (req_pcie_addr_reg[12] != req_pcie_addr_plus_op_count[12]) begin
            // crosses 4k boundary
            req_tlp_count_next = 13'h1000 - req_pcie_addr_reg[11:0];
            dword_count = 11'h400 - req_pcie_addr_reg[11:2];
            req_last_tlp = req_pcie_addr_plus_op_count[11:0] == 0;
            // optimized req_pcie_addr = req_addr_reg + req_tlp_count_next
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12]+1;
            req_pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            req_tlp_count_next = req_op_count_reg;
            dword_count = (req_op_count_reg + req_pcie_addr_reg[1:0] + 3) >> 2;
            req_last_tlp = 1'b1;
            // optimized req_pcie_addr = req_addr_reg + req_tlp_count_next
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12];
            req_pcie_addr[11:0] = req_pcie_addr_reg[11:0] + req_op_count_reg;
        end
    end else begin
        // packet larger than max read request size
        if (req_pcie_addr_reg[12] != req_pcie_addr_plus_max_read_request[12]) begin
            // crosses 4k boundary
            req_tlp_count_next = 13'h1000 - req_pcie_addr_reg[11:0];
            dword_count = 11'h400 - req_pcie_addr_reg[11:2];
            req_last_tlp = 1'b0;
            // optimized req_pcie_addr = req_addr_reg + req_tlp_count_next
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12]+1;
            req_pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            req_tlp_count_next = {max_read_request_size_dw_reg, 2'b00} - req_pcie_addr_reg[1:0];
            dword_count = max_read_request_size_dw_reg;
            req_last_tlp = 1'b0;
            // optimized req_pcie_addr = req_addr_reg + req_tlp_count_next
            req_pcie_addr[PCIE_ADDR_WIDTH-1:12] = req_pcie_addr_reg[PCIE_ADDR_WIDTH-1:12];
            req_pcie_addr[11:0] = {req_pcie_addr_reg[11:2] + max_read_request_size_dw_reg, 2'b00};
        end
    end

    first_be = 4'b1111 << req_pcie_addr_reg[1:0];
    last_be = 4'b1111 >> (3 - ((req_pcie_addr_reg[1:0] + req_tlp_count_next[1:0] - 1) & 3));

    if (AXIS_PCIE_DATA_WIDTH > 64) begin
        m_axis_rq_tdata_int[74:64] = dword_count; // DWORD count
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        m_axis_rq_tuser_int[3:0] = dword_count == 1 ? first_be & last_be : first_be; // first BE 0
        m_axis_rq_tuser_int[7:4] = 4'd0; // first BE 1
        m_axis_rq_tuser_int[11:8] = dword_count == 1 ? 4'b0000 : last_be; // last BE 0
        m_axis_rq_tuser_int[15:12] = 4'd0; // last BE 1
    end else begin
        m_axis_rq_tuser_int[3:0] = dword_count == 1 ? first_be & last_be : first_be; // first BE
        m_axis_rq_tuser_int[7:4] = dword_count == 1 ? 4'b0000 : last_be; // last BE
    end

    // TLP segmentation and request generation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            s_axis_read_desc_ready_next = enable && !tlp_cmd_valid_reg && op_table_start_ptr_valid;

            if (s_axis_read_desc_ready && s_axis_read_desc_valid) begin
                s_axis_read_desc_ready_next = 1'b0;
                tlp_cmd_ram_sel_next = s_axis_read_desc_ram_sel;
                req_pcie_addr_next = s_axis_read_desc_pcie_addr;
                req_addr_next = s_axis_read_desc_ram_addr;
                req_op_count_next = s_axis_read_desc_len;
                tlp_cmd_tag_next = s_axis_read_desc_tag;
                tlp_cmd_op_tag_next = op_table_start_ptr;
                op_table_start_tag = s_axis_read_desc_tag;
                op_table_start_en = 1'b1;
                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            if (m_axis_rq_tready_int_reg && !tlp_cmd_valid_reg && new_tag_valid && (!TX_FC_ENABLE || have_credit_reg) && (!RQ_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                m_axis_rq_tvalid_int = 1'b1;

                inc_active_tx = 1'b1;

                if (AXIS_PCIE_DATA_WIDTH > 64) begin
                    req_pcie_addr_next = req_pcie_addr;
                    req_addr_next = req_addr_reg + req_tlp_count_next;
                    req_op_count_next = req_op_count_reg - req_tlp_count_next;

                    new_tag_ready = 1'b1;

                    tlp_cmd_addr_next = req_addr_reg;
                    tlp_cmd_pcie_tag_next = new_tag;
                    tlp_cmd_last_next = req_last_tlp;
                    tlp_cmd_valid_next = 1'b1;

                    op_table_read_start_ptr = tlp_cmd_op_tag_reg;
                    op_table_read_start_commit = req_last_tlp;
                    op_table_read_start_en = 1'b1;

                    if (!req_last_tlp) begin
                        req_state_next = REQ_STATE_START;
                    end else begin
                        s_axis_read_desc_ready_next = 1'b0;
                        req_state_next = REQ_STATE_IDLE;
                    end
                end else begin
                    req_state_next = REQ_STATE_HEADER;
                end
            end else begin
                req_state_next = REQ_STATE_START;
            end
        end
        REQ_STATE_HEADER: begin
            if (m_axis_rq_tready_int_reg && !tlp_cmd_valid_reg && new_tag_valid) begin
                req_pcie_addr_next = req_pcie_addr;
                req_addr_next = req_addr_reg + req_tlp_count_next;
                req_op_count_next = req_op_count_reg - req_tlp_count_next;

                new_tag_ready = 1'b1;

                m_axis_rq_tdata_int[10:0] = dword_count; // DWORD count
                m_axis_rq_tdata_int[14:11] = REQ_MEM_READ; // request type - memory read
                m_axis_rq_tdata_int[15] = 1'b0; // poisoned request
                m_axis_rq_tdata_int[31:16] = requester_id;
                m_axis_rq_tdata_int[40:32] = new_tag;
                m_axis_rq_tdata_int[55:41] = 16'd0; // completer ID
                m_axis_rq_tdata_int[56] = requester_id_enable;
                m_axis_rq_tdata_int[59:57] = 3'b000; // traffic class
                m_axis_rq_tdata_int[62:60] = 3'b000; // attr
                m_axis_rq_tdata_int[63] = 1'b0; // force ECRC
                m_axis_rq_tlast_int = 1'b1;
                m_axis_rq_tvalid_int = 1'b1;

                tlp_cmd_addr_next = req_addr_reg;
                tlp_cmd_pcie_tag_next = new_tag;
                tlp_cmd_last_next = req_last_tlp;
                tlp_cmd_valid_next = 1'b1;

                op_table_read_start_ptr = tlp_cmd_op_tag_reg;
                op_table_read_start_commit = req_last_tlp;
                op_table_read_start_en = 1'b1;

                if (!req_last_tlp) begin
                    req_state_next = REQ_STATE_START;
                end else begin
                    s_axis_read_desc_ready_next = 1'b0;
                    req_state_next = REQ_STATE_IDLE;
                end
            end else begin
                req_state_next = REQ_STATE_HEADER;
            end
        end
    endcase
end

always @* begin
    tlp_state_next = TLP_STATE_IDLE;

    last_cycle = 1'b0;

    tag_table_we_tlp_next = 1'b0;

    s_axis_rc_tready_next = 1'b0;

    lower_addr_next = lower_addr_reg;
    byte_count_next = byte_count_reg;
    error_code_next = error_code_reg;
    ram_sel_next = ram_sel_reg;
    addr_next = addr_reg;
    addr_delay_next = addr_delay_reg;
    addr_valid_next = addr_valid_reg;
    op_count_next = op_count_reg;
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

    rc_tdata_int_next = rc_tdata_int_reg;
    rc_tvalid_int_next = rc_tvalid_int_reg;

    ram_wr_cmd_sel_int = {SEG_COUNT{ram_sel_reg}};
    if (!ram_wrap_reg) begin
        ram_wr_cmd_be_int = ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} << start_offset_reg) & ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} >> (SEG_COUNT*SEG_BE_WIDTH-1-end_offset_reg));
    end else begin
        ram_wr_cmd_be_int = ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} << start_offset_reg) | ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} >> (SEG_COUNT*SEG_BE_WIDTH-1-end_offset_reg));
    end
    for (i = 0; i < SEG_COUNT; i = i + 1) begin
        ram_wr_cmd_addr_int[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = addr_delay_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH];
        if (ram_mask_1_reg[i]) begin
            ram_wr_cmd_addr_int[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = addr_delay_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]+1;
        end
    end
    ram_wr_cmd_data_int = {3{rc_tdata_int_reg}} >> (AXIS_PCIE_DATA_WIDTH - offset_reg*8);
    ram_wr_cmd_valid_int = {SEG_COUNT{1'b0}};

    status_error_cor_next = 1'b0;
    status_error_uncor_next = 1'b0;

    // Write generation
    if (rc_tvalid_int_reg && !(~ram_wr_cmd_ready_int_reg & ram_mask_reg)) begin
        rc_tvalid_int_next = 1'b0;

        ram_wr_cmd_sel_int = {SEG_COUNT{ram_sel_reg}};
        if (!ram_wrap_reg) begin
            ram_wr_cmd_be_int = ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} << start_offset_reg) & ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} >> (SEG_COUNT*SEG_BE_WIDTH-1-end_offset_reg));
        end else begin
            ram_wr_cmd_be_int = ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} << start_offset_reg) | ({SEG_COUNT*SEG_BE_WIDTH{1'b1}} >> (SEG_COUNT*SEG_BE_WIDTH-1-end_offset_reg));
        end
        for (i = 0; i < SEG_COUNT; i = i + 1) begin
            if (ram_mask_0_reg[i]) begin
                ram_wr_cmd_addr_int[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = addr_delay_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH];
            end
            if (ram_mask_1_reg[i]) begin
                ram_wr_cmd_addr_int[i*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = addr_delay_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-SEG_ADDR_WIDTH]+1;
            end
        end
        ram_wr_cmd_data_int = {3{rc_tdata_int_reg}} >> (AXIS_PCIE_DATA_WIDTH - offset_reg*8);
        ram_wr_cmd_valid_int = ram_mask_reg;
    end

    // TLP response handling
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for completion
            if (AXIS_PCIE_DATA_WIDTH > 64) begin
                s_axis_rc_tready_next = !rc_tvalid_int_next;

                if (s_axis_rc_tready && s_axis_rc_tvalid) begin
                    // header fields
                    lower_addr_next = s_axis_rc_tdata[11:0]; // lower address
                    error_code_next = s_axis_rc_tdata[15:12]; // error code
                    byte_count_next = s_axis_rc_tdata[28:16]; // byte count
                    //s_axis_rc_tdata[29]; // locked read
                    //s_axis_rc_tdata[30]; // request completed
                    op_dword_count_next = s_axis_rc_tdata[42:32]; // DWORD count
                    //s_axis_rc_tdata[45:43]; // completion status
                    //s_axis_rc_tdata[46]; // poisoned completion
                    //s_axis_rc_tdata[63:48]; // requester ID
                    pcie_tag_next = s_axis_rc_tdata[71:64]; // tag
                    //s_axis_rc_tdata[87:72]; // completer ID
                    //s_axis_rc_tdata[91:89]; // attr
                    //s_axis_rc_tdata[94:92]; // tc

                    // tuser fields
                    //s_axis_rc_tuser[31:0]; // byte enables
                    //s_axis_rc_tuser[32]; // is_sof_0
                    //s_axis_rc_tuser[33]; // is_sof_1
                    //s_axis_rc_tuser[37:34]; // is_eof_0
                    //s_axis_rc_tuser[41:38]; // is_eof_1
                    //s_axis_rc_tuser[42]; // discontinue
                    //s_axis_rc_tuser[74:43]; // parity

                    ram_sel_next = tag_table_sel[pcie_tag_next];
                    if (!addr_valid_reg || pcie_tag_reg != pcie_tag_next) begin
                        // current AXI address not valid, so read it from table
                        addr_next = tag_table_addr[pcie_tag_next];
                    end

                    offset_next = addr_next[OFFSET_WIDTH-1:0] - (12+lower_addr_next[1:0]);

                    if (byte_count_next > (op_dword_count_next << 2) - lower_addr_next[1:0]) begin
                        // more completions to follow
                        op_count_next = (op_dword_count_next << 2) - lower_addr_next[1:0];
                        final_cpl_next = 1'b0;

                        if (op_dword_count_next > (AXIS_PCIE_DATA_WIDTH/32-3)) begin
                            // more than one cycle
                            cycle_byte_count_next = (AXIS_PCIE_DATA_WIDTH/8-12)-lower_addr_next[1:0];
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
                        op_count_next = byte_count_next;
                        final_cpl_next = 1'b1;

                        if (op_count_next > (AXIS_PCIE_DATA_WIDTH/8-12)-lower_addr_next[1:0]) begin
                            // more than one cycle
                            cycle_byte_count_next = (AXIS_PCIE_DATA_WIDTH/8-12)-lower_addr_next[1:0];
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

                    ram_mask_0_next = {SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(SEG_BE_WIDTH));
                    ram_mask_1_next = {SEG_COUNT{1'b1}} >> (SEG_COUNT-1-(end_offset_next >> $clog2(SEG_BE_WIDTH)));

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

                    op_tag_next = tag_table_op_tag[pcie_tag_next];

                    if (active_tags[pcie_tag_next] && error_code_next == RC_ERROR_NORMAL_TERMINATION) begin
                        // no error
                        addr_valid_next = !final_cpl_next;
                        rc_tdata_int_next = s_axis_rc_tdata;
                        rc_tvalid_int_next = 1'b1;
                        if (last_cycle) begin
                            if (final_cpl_next) begin
                                // last completion in current read request (PCIe tag)

                                // release tag
                                finish_tag_next = 1'b1;
                            end else begin
                                // more completions to come, store current address
                                tag_table_we_tlp_next = 1'b1;
                            end
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            tlp_state_next = TLP_STATE_WRITE;
                        end
                    end else if (error_code_next == RC_ERROR_MISMATCH) begin
                        // mismatched fields
                        // Handle as malformed TLP (2.3.2)
                        // drop TLP and report uncorrectable error
                        status_error_uncor_next = 1'b1;
                        addr_valid_next = 1'b0;
                        if (s_axis_rc_tlast) begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            s_axis_rc_tready_next = 1'b1;
                            tlp_state_next = TLP_STATE_WAIT_END;
                        end
                    end else if (!active_tags[pcie_tag_next] || error_code_next == RC_ERROR_INVALID_TAG) begin
                        // invalid tag
                        // Handle as unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                        // drop TLP and report correctable error
                        status_error_cor_next = 1'b1;
                        addr_valid_next = 1'b0;
                        if (s_axis_rc_tlast) begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            s_axis_rc_tready_next = 1'b1;
                            tlp_state_next = TLP_STATE_WAIT_END;
                        end
                    end else begin
                        // request terminated by other error (tag valid)
                        // report error
                        case (error_code_next)
                            RC_ERROR_POISONED: status_error_cor_next = 1'b1; // advisory non-fatal (6.2.3.2.4.3)
                            RC_ERROR_BAD_STATUS: status_error_cor_next = 1'b1; // advisory non-fatal (6.2.3.2.4.1)
                            RC_ERROR_INVALID_LENGTH: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                            RC_ERROR_MISMATCH: status_error_uncor_next = 1'b1; // malformed TLP (2.3.2)
                            RC_ERROR_INVALID_ADDRESS: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                            RC_ERROR_INVALID_TAG: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                            RC_ERROR_TIMEOUT: status_error_uncor_next = 1'b1; // uncorrectable (6.2.3.2.4.4)
                            RC_ERROR_FLR: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                            default: status_error_uncor_next = 1'b1;
                        endcase
                        // last request in current transfer
                        addr_valid_next = 1'b0;

                        // release tag
                        finish_tag_next = 1'b1;

                        // drop TLP
                        if (s_axis_rc_tlast) begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            s_axis_rc_tready_next = 1'b1;
                            tlp_state_next = TLP_STATE_WAIT_END;
                        end
                    end
                end else begin
                    tlp_state_next = TLP_STATE_IDLE;
                end
            end else begin
                s_axis_rc_tready_next = 1'b1;

                if (s_axis_rc_tready && s_axis_rc_tvalid) begin
                    // header fields
                    lower_addr_next = s_axis_rc_tdata[11:0]; // lower address
                    error_code_next = s_axis_rc_tdata[15:12]; // error code
                    byte_count_next = s_axis_rc_tdata[28:16]; // byte count
                    //s_axis_rc_tdata[29]; // locked read
                    //s_axis_rc_tdata[30]; // request completed
                    op_dword_count_next = s_axis_rc_tdata[42:32]; // DWORD count
                    //s_axis_rc_tdata[45:43]; // completion status
                    //s_axis_rc_tdata[46]; // poisoned completion
                    //s_axis_rc_tdata[63:48]; // requester ID

                    // tuser fields
                    //s_axis_rc_tuser[31:0]; // byte enables
                    //s_axis_rc_tuser[32]; // is_sof_0
                    //s_axis_rc_tuser[33]; // is_sof_1
                    //s_axis_rc_tuser[37:34]; // is_eof_0
                    //s_axis_rc_tuser[41:38]; // is_eof_1
                    //s_axis_rc_tuser[42]; // discontinue
                    //s_axis_rc_tuser[74:43]; // parity

                    if (byte_count_next > (op_dword_count_next << 2) - lower_addr_next[1:0]) begin
                        // more completions to follow
                        op_count_next = (op_dword_count_next << 2) - lower_addr_next[1:0];
                        final_cpl_next = 1'b0;
                    end else begin
                        // last completion
                        op_count_next = byte_count_next;
                        final_cpl_next = 1'b1;
                    end

                    if (s_axis_rc_tlast) begin
                        s_axis_rc_tready_next = 1'b1;
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        s_axis_rc_tready_next = !rc_tvalid_int_next;
                        tlp_state_next = TLP_STATE_HEADER;
                    end
                end else begin
                    s_axis_rc_tready_next = 1'b1;
                    tlp_state_next = TLP_STATE_IDLE;
                end
            end
        end
        TLP_STATE_HEADER: begin
            // header state; process header (64 bit interface only)
            s_axis_rc_tready_next = !rc_tvalid_int_next;

            if (s_axis_rc_tready && s_axis_rc_tvalid) begin
                pcie_tag_next = s_axis_rc_tdata[7:0]; // tag
                //s_axis_rc_tdata[23:8]; // completer ID
                //s_axis_rc_tdata[27:25]; // attr
                //s_axis_rc_tdata[30:28]; // tc

                ram_sel_next = tag_table_sel[pcie_tag_next];
                if (!addr_valid_reg || pcie_tag_reg != pcie_tag_next) begin
                    // current AXI address not valid, so read it from table
                    addr_next = tag_table_addr[pcie_tag_next];
                end

                offset_next = addr_next[OFFSET_WIDTH-1:0] - (4+lower_addr_reg[1:0]);

                if (op_count_next > 4-lower_addr_reg[1:0]) begin
                    // more than one cycle
                    cycle_byte_count_next = 4-lower_addr_reg[1:0];
                    last_cycle = 1'b0;
                end else begin
                    // one cycle
                    cycle_byte_count_next = op_count_next;
                    last_cycle = 1'b1;
                end
                start_offset_next = addr_next;
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                ram_mask_0_next = {SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(SEG_BE_WIDTH));
                ram_mask_1_next = {SEG_COUNT{1'b1}} >> (SEG_COUNT-1-(end_offset_next >> $clog2(SEG_BE_WIDTH)));

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

                op_tag_next = tag_table_op_tag[pcie_tag_next];

                if (active_tags[pcie_tag_next] && error_code_reg == RC_ERROR_NORMAL_TERMINATION) begin
                    // no error
                    addr_valid_next = !final_cpl_next;
                    rc_tdata_int_next = s_axis_rc_tdata;
                    rc_tvalid_int_next = 1'b1;
                    if (last_cycle) begin
                        if (final_cpl_next) begin
                            // last completion in current read request (PCIe tag)

                            // release tag
                            finish_tag_next = 1'b1;
                        end else begin
                            // more completions to come, store current address
                            tag_table_we_tlp_next = 1'b1;
                        end
                        s_axis_rc_tready_next = 1'b1;
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        tlp_state_next = TLP_STATE_WRITE;
                    end
                end else if (error_code_next == RC_ERROR_MISMATCH) begin
                    // mismatched fields
                    // Handle as malformed TLP (2.3.2)
                    // drop TLP and report uncorrectable error
                    status_error_uncor_next = 1'b1;
                    addr_valid_next = 1'b0;
                    s_axis_rc_tready_next = 1'b1;
                    if (s_axis_rc_tlast) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else if (!active_tags[pcie_tag_next] || error_code_next == RC_ERROR_INVALID_TAG) begin
                    // invalid tag or mismatched fields (tag invalid)
                    // Handle as unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                    // drop TLP and report correctable error
                    status_error_cor_next = 1'b1;
                    addr_valid_next = 1'b0;
                    s_axis_rc_tready_next = 1'b1;
                    if (s_axis_rc_tlast) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else begin
                    // request terminated by other error (tag valid)
                    // report error
                    case (error_code_next)
                        RC_ERROR_POISONED: status_error_cor_next = 1'b1; // advisory non-fatal (6.2.3.2.4.3)
                        RC_ERROR_BAD_STATUS: status_error_cor_next = 1'b1; // advisory non-fatal (6.2.3.2.4.1)
                        RC_ERROR_INVALID_LENGTH: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                        RC_ERROR_MISMATCH: status_error_uncor_next = 1'b1; // malformed TLP (2.3.2)
                        RC_ERROR_INVALID_ADDRESS: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                        RC_ERROR_INVALID_TAG: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                        RC_ERROR_TIMEOUT: status_error_uncor_next = 1'b1; // uncorrectable (6.2.3.2.4.4)
                        RC_ERROR_FLR: status_error_cor_next = 1'b1; // unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)
                        default: status_error_uncor_next = 1'b1;
                    endcase
                    // last request in current transfer
                    addr_valid_next = 1'b0;

                    // release tag
                    finish_tag_next = 1'b1;

                    // drop TLP
                    s_axis_rc_tready_next = 1'b1;
                    if (s_axis_rc_tlast) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end
            end else begin
                tlp_state_next = TLP_STATE_HEADER;
            end
        end
        TLP_STATE_WRITE: begin
            // write state - generate write operations
            s_axis_rc_tready_next = !rc_tvalid_int_next;

            if (s_axis_rc_tready && s_axis_rc_tvalid) begin
                rc_tdata_int_next = s_axis_rc_tdata;
                rc_tvalid_int_next = 1'b1;

                if (op_count_next > AXIS_PCIE_DATA_WIDTH/8) begin
                    // more cycles after this one
                    cycle_byte_count_next = AXIS_PCIE_DATA_WIDTH/8;
                    last_cycle = 1'b0;
                end else begin
                    // last cycle
                    cycle_byte_count_next = op_count_next;
                    last_cycle = 1'b1;
                end
                start_offset_next = addr_next;
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                ram_mask_0_next = {SEG_COUNT{1'b1}} << (start_offset_next >> $clog2(SEG_BE_WIDTH));
                ram_mask_1_next = {SEG_COUNT{1'b1}} >> (SEG_COUNT-1-(end_offset_next >> $clog2(SEG_BE_WIDTH)));

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

                s_axis_rc_tready_next = !(~ram_wr_cmd_ready_int_early & ram_mask_next);

                if (last_cycle) begin
                    if (final_cpl_reg) begin
                        // last completion in current read request (PCIe tag)

                        // release tag
                        finish_tag_next = 1'b1;
                    end else begin
                        // more completions to come, store current address
                        tag_table_we_tlp_next = 1'b1;
                    end

                    if (AXIS_PCIE_DATA_WIDTH == 64) begin
                        s_axis_rc_tready_next = 1'b1;
                    end
                    tlp_state_next = TLP_STATE_IDLE;
                end else begin
                    tlp_state_next = TLP_STATE_WRITE;
                end
            end else begin
                tlp_state_next = TLP_STATE_WRITE;
            end
        end
        TLP_STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            s_axis_rc_tready_next = 1'b1;

            if (s_axis_rc_tready & s_axis_rc_tvalid) begin
                if (s_axis_rc_tlast) begin
                    if (AXIS_PCIE_DATA_WIDTH > 64) begin
                        s_axis_rc_tready_next = !rc_tvalid_int_next;
                    end else begin
                        s_axis_rc_tready_next = 1'b1;
                    end
                    tlp_state_next = TLP_STATE_IDLE;
                end else begin
                    tlp_state_next = TLP_STATE_WAIT_END;
                end
            end else begin
                tlp_state_next = TLP_STATE_WAIT_END;
            end
        end
    endcase

    m_axis_read_desc_status_tag_next = m_axis_read_desc_status_tag_reg;
    m_axis_read_desc_status_valid_next = 1'b0;

    op_table_finish_ptr = op_tag_reg;
    op_table_finish_en = 1'b0;
    op_table_read_finish_ptr = op_tag_reg;
    op_table_read_finish_en = 1'b0;

    // finish handling
    if (finish_tag_reg) begin
        // mark done
        op_table_read_finish_ptr = op_tag_reg;
        op_table_read_finish_en = 1'b1;

        op_table_finish_ptr = op_tag_reg;

        m_axis_read_desc_status_tag_next = op_table_tag[op_tag_reg];

        if (op_table_read_commit[op_table_read_finish_ptr] && (op_table_read_count_start[op_table_read_finish_ptr] == op_table_read_count_finish[op_table_read_finish_ptr])) begin
            op_table_finish_en = 1'b1;
            m_axis_read_desc_status_valid_next = 1'b1;
        end
    end
end

always @* begin
    tag_table_we_req = 1'b0;
    tlp_cmd_ready = 1'b0;

    // tag table write management
    if (tag_table_we_tlp_reg) begin
        
    end else if (tlp_cmd_valid_reg) begin
        tlp_cmd_ready = 1'b1;
        tag_table_we_req = 1'b1;
    end
end

always @(posedge clk) begin
    req_state_reg <= req_state_next;
    tlp_state_reg <= tlp_state_next;

    status_error_cor_reg <= status_error_cor_next;
    status_error_uncor_reg <= status_error_uncor_next;

    req_pcie_addr_reg <= req_pcie_addr_next;
    req_addr_reg <= req_addr_next;
    req_op_count_reg <= req_op_count_next;
    req_tlp_count_reg <= req_tlp_count_next;

    lower_addr_reg <= lower_addr_next;
    byte_count_reg <= byte_count_next;
    error_code_reg <= error_code_next;
    ram_sel_reg <= ram_sel_next;
    addr_reg <= addr_next;
    addr_delay_reg <= addr_delay_next;
    addr_valid_reg <= addr_valid_next;
    op_count_reg <= op_count_next;
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

    tlp_cmd_ram_sel_reg <= tlp_cmd_ram_sel_next;
    tlp_cmd_addr_reg <= tlp_cmd_addr_next;
    tlp_cmd_op_tag_reg <= tlp_cmd_op_tag_next;
    tlp_cmd_tag_reg <= tlp_cmd_tag_next;
    tlp_cmd_pcie_tag_reg <= tlp_cmd_pcie_tag_next;
    tlp_cmd_last_reg <= tlp_cmd_last_next;
    tlp_cmd_valid_reg <= tlp_cmd_valid_next;

    rc_tdata_int_reg <= rc_tdata_int_next;
    rc_tvalid_int_reg <= rc_tvalid_int_next;

    s_axis_rc_tready_reg <= s_axis_rc_tready_next;
    s_axis_read_desc_ready_reg <= s_axis_read_desc_ready_next;

    m_axis_read_desc_status_tag_reg <= m_axis_read_desc_status_tag_next;
    m_axis_read_desc_status_valid_reg <= m_axis_read_desc_status_valid_next;

    max_read_request_size_dw_reg <= 11'd32 << (max_read_request_size > 5 ? 5 : max_read_request_size);

    have_credit_reg <= pcie_tx_fc_nph_av > 4;

    if (active_tx_count_reg < TX_LIMIT && inc_active_tx && !s_axis_rq_seq_num_valid_0 && !s_axis_rq_seq_num_valid_1) begin
        // inc by 1
        active_tx_count_reg <= active_tx_count_reg + 1;
        active_tx_count_av_reg <= active_tx_count_reg < (TX_LIMIT-1);
    end else if (active_tx_count_reg > 0 && ((inc_active_tx && s_axis_rq_seq_num_valid_0 && s_axis_rq_seq_num_valid_1) || (!inc_active_tx && (s_axis_rq_seq_num_valid_0 ^ s_axis_rq_seq_num_valid_1)))) begin
        // dec by 1
        active_tx_count_reg <= active_tx_count_reg - 1;
        active_tx_count_av_reg <= 1'b1;
    end else if (active_tx_count_reg > 1 && !inc_active_tx && s_axis_rq_seq_num_valid_0 && s_axis_rq_seq_num_valid_1) begin
        // dec by 2
        active_tx_count_reg <= active_tx_count_reg - 2;
        active_tx_count_av_reg <= 1'b1;
    end else begin
        active_tx_count_av_reg <= active_tx_count_reg < TX_LIMIT;
    end

    tag_table_we_tlp_reg <= tag_table_we_tlp_next;

    if (tag_table_we_tlp_reg) begin
        tag_table_addr[pcie_tag_reg] <= addr_reg;
    end else if (tlp_cmd_valid_reg && tag_table_we_req) begin
        tag_table_sel[tlp_cmd_pcie_tag_reg] <= tlp_cmd_ram_sel_reg;
        tag_table_addr[tlp_cmd_pcie_tag_reg] <= tlp_cmd_addr_reg;
        tag_table_op_tag[tlp_cmd_pcie_tag_reg] <= tlp_cmd_op_tag_reg;
    end

    if (op_table_start_en) begin
        op_table_active[op_table_start_ptr] <= 1'b1;
        op_table_tag[op_table_start_ptr] <= op_table_start_tag;
        op_table_init[op_table_start_ptr] <= !op_table_init[op_table_start_ptr];
    end

    if (op_table_finish_en) begin
        op_table_active[op_table_finish_ptr] <= 1'b0;
    end

    if (op_table_read_start_en) begin
        op_table_read_init[op_table_read_start_ptr] <= op_table_init[op_table_read_start_ptr];
        op_table_read_commit[op_table_read_start_ptr] <= op_table_read_start_commit;
        if (op_table_read_init[op_table_read_start_ptr] != op_table_init[op_table_read_start_ptr]) begin
            op_table_read_count_start[op_table_read_start_ptr] <= op_table_read_count_finish[op_table_read_start_ptr];
        end else begin
            op_table_read_count_start[op_table_read_start_ptr] <= op_table_read_count_start[op_table_read_start_ptr] + 1;
        end
    end

    if (op_table_read_finish_en) begin
        op_table_read_count_finish[op_table_read_finish_ptr] <= op_table_read_count_finish[op_table_read_finish_ptr] + 1;
    end

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;

        addr_valid_reg <= 1'b0;
        tlp_cmd_valid_reg <= 1'b0;
        finish_tag_reg <= 1'b0;

        rc_tvalid_int_reg <= 1'b0;

        s_axis_rc_tready_reg <= 1'b0;
        s_axis_read_desc_ready_reg <= 1'b0;
        m_axis_read_desc_status_valid_reg <= 1'b0;

        active_tx_count_reg <= {RQ_SEQ_NUM_WIDTH{1'b0}};
        active_tx_count_av_reg <= 1'b1;

        tag_table_we_tlp_reg <= 1'b0;
        op_table_active <= 0;

        status_error_cor_reg <= 1'b0;
        status_error_uncor_reg <= 1'b0;
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

// output datapath logic (write data)
generate

genvar n;

for (n = 0; n < SEG_COUNT; n = n + 1) begin

    reg [RAM_SEL_WIDTH-1:0]  ram_wr_cmd_sel_reg = {RAM_SEL_WIDTH{1'b0}};
    reg [SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_reg = {SEG_BE_WIDTH{1'b0}};
    reg [SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_reg = {SEG_ADDR_WIDTH{1'b0}};
    reg [SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_reg = {SEG_DATA_WIDTH{1'b0}};
    reg                      ram_wr_cmd_valid_reg = 1'b0, ram_wr_cmd_valid_next;

    reg [RAM_SEL_WIDTH-1:0]  temp_ram_wr_cmd_sel_reg = {RAM_SEL_WIDTH{1'b0}};
    reg [SEG_BE_WIDTH-1:0]   temp_ram_wr_cmd_be_reg = {SEG_BE_WIDTH{1'b0}};
    reg [SEG_ADDR_WIDTH-1:0] temp_ram_wr_cmd_addr_reg = {SEG_ADDR_WIDTH{1'b0}};
    reg [SEG_DATA_WIDTH-1:0] temp_ram_wr_cmd_data_reg = {SEG_DATA_WIDTH{1'b0}};
    reg                      temp_ram_wr_cmd_valid_reg = 1'b0, temp_ram_wr_cmd_valid_next;

    // datapath control
    reg store_axi_w_int_to_output;
    reg store_axi_w_int_to_temp;
    reg store_axi_w_temp_to_output;

    assign ram_wr_cmd_sel[n*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = ram_wr_cmd_sel_reg;
    assign ram_wr_cmd_be[n*SEG_BE_WIDTH +: SEG_BE_WIDTH] = ram_wr_cmd_be_reg;
    assign ram_wr_cmd_addr[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = ram_wr_cmd_addr_reg;
    assign ram_wr_cmd_data[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH] = ram_wr_cmd_data_reg;
    assign ram_wr_cmd_valid[n +: 1] = ram_wr_cmd_valid_reg;

    // enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
    assign ram_wr_cmd_ready_int_early[n +: 1] = ram_wr_cmd_ready[n +: 1] || (!temp_ram_wr_cmd_valid_reg && (!ram_wr_cmd_valid_reg || !ram_wr_cmd_valid_int[n +: 1]));

    always @* begin
        // transfer sink ready state to source
        ram_wr_cmd_valid_next = ram_wr_cmd_valid_reg;
        temp_ram_wr_cmd_valid_next = temp_ram_wr_cmd_valid_reg;

        store_axi_w_int_to_output = 1'b0;
        store_axi_w_int_to_temp = 1'b0;
        store_axi_w_temp_to_output = 1'b0;
        
        if (ram_wr_cmd_ready_int_reg[n +: 1]) begin
            // input is ready
            if (ram_wr_cmd_ready[n +: 1] || !ram_wr_cmd_valid_reg) begin
                // output is ready or currently not valid, transfer data to output
                ram_wr_cmd_valid_next = ram_wr_cmd_valid_int[n +: 1];
                store_axi_w_int_to_output = 1'b1;
            end else begin
                // output is not ready, store input in temp
                temp_ram_wr_cmd_valid_next = ram_wr_cmd_valid_int[n +: 1];
                store_axi_w_int_to_temp = 1'b1;
            end
        end else if (ram_wr_cmd_ready[n +: 1]) begin
            // input is not ready, but output is ready
            ram_wr_cmd_valid_next = temp_ram_wr_cmd_valid_reg;
            temp_ram_wr_cmd_valid_next = 1'b0;
            store_axi_w_temp_to_output = 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            ram_wr_cmd_valid_reg <= 1'b0;
            ram_wr_cmd_ready_int_reg[n +: 1] <= 1'b0;
            temp_ram_wr_cmd_valid_reg <= 1'b0;
        end else begin
            ram_wr_cmd_valid_reg <= ram_wr_cmd_valid_next;
            ram_wr_cmd_ready_int_reg[n +: 1] <= ram_wr_cmd_ready_int_early[n +: 1];
            temp_ram_wr_cmd_valid_reg <= temp_ram_wr_cmd_valid_next;
        end

        // datapath
        if (store_axi_w_int_to_output) begin
            ram_wr_cmd_sel_reg <= ram_wr_cmd_sel_int[n*RAM_SEL_WIDTH +: RAM_SEL_WIDTH];
            ram_wr_cmd_be_reg <= ram_wr_cmd_be_int[n*SEG_BE_WIDTH +: SEG_BE_WIDTH];
            ram_wr_cmd_addr_reg <= ram_wr_cmd_addr_int[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH];
            ram_wr_cmd_data_reg <= ram_wr_cmd_data_int[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH];
        end else if (store_axi_w_temp_to_output) begin
            ram_wr_cmd_sel_reg <= temp_ram_wr_cmd_sel_reg;
            ram_wr_cmd_be_reg <= temp_ram_wr_cmd_be_reg;
            ram_wr_cmd_addr_reg <= temp_ram_wr_cmd_addr_reg;
            ram_wr_cmd_data_reg <= temp_ram_wr_cmd_data_reg;
        end

        if (store_axi_w_int_to_temp) begin
            temp_ram_wr_cmd_sel_reg <= ram_wr_cmd_sel_int[n*RAM_SEL_WIDTH +: RAM_SEL_WIDTH];
            temp_ram_wr_cmd_be_reg <= ram_wr_cmd_be_int[n*SEG_BE_WIDTH +: SEG_BE_WIDTH];
            temp_ram_wr_cmd_addr_reg <= ram_wr_cmd_addr_int[n*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH];
            temp_ram_wr_cmd_data_reg <= ram_wr_cmd_data_int[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH];
        end
    end

end

endgenerate

endmodule
