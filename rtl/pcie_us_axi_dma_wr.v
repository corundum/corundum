/*

Copyright (c) 2018-2021 Alex Forencich

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
 * Ultrascale PCIe AXI DMA Write
 */
module pcie_us_axi_dma_wr #
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
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 64,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // Length field width
    parameter LEN_WIDTH = 20,
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
    input  wire                               clk,
    input  wire                               rst,

    /*
     * AXI input (RQ from read DMA)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]    s_axis_rq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]    s_axis_rq_tkeep,
    input  wire                               s_axis_rq_tvalid,
    output wire                               s_axis_rq_tready,
    input  wire                               s_axis_rq_tlast,
    input  wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] s_axis_rq_tuser,

    /*
     * AXI output (RQ)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep,
    output wire                               m_axis_rq_tvalid,
    input  wire                               m_axis_rq_tready,
    output wire                               m_axis_rq_tlast,
    output wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser,

    /*
     * Transmit sequence number input
     */
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]        s_axis_rq_seq_num_0,
    input  wire                               s_axis_rq_seq_num_valid_0,
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]        s_axis_rq_seq_num_1,
    input  wire                               s_axis_rq_seq_num_valid_1,

    /*
     * Transmit sequence number output (to read DMA)
     */
    output wire [RQ_SEQ_NUM_WIDTH-1:0]        m_axis_rq_seq_num_0,
    output wire                               m_axis_rq_seq_num_valid_0,
    output wire [RQ_SEQ_NUM_WIDTH-1:0]        m_axis_rq_seq_num_1,
    output wire                               m_axis_rq_seq_num_valid_1,

    /*
     * Transmit flow control
     */
    input  wire [7:0]                         pcie_tx_fc_ph_av,
    input  wire [11:0]                        pcie_tx_fc_pd_av,

    /*
     * AXI write descriptor input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]         s_axis_write_desc_pcie_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]          s_axis_write_desc_axi_addr,
    input  wire [LEN_WIDTH-1:0]               s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]               s_axis_write_desc_tag,
    input  wire                               s_axis_write_desc_valid,
    output wire                               s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [TAG_WIDTH-1:0]               m_axis_write_desc_status_tag,
    output wire [3:0]                         m_axis_write_desc_status_error,
    output wire                               m_axis_write_desc_status_valid,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]            m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axi_araddr,
    output wire [7:0]                         m_axi_arlen,
    output wire [2:0]                         m_axi_arsize,
    output wire [1:0]                         m_axi_arburst,
    output wire                               m_axi_arlock,
    output wire [3:0]                         m_axi_arcache,
    output wire [2:0]                         m_axi_arprot,
    output wire                               m_axi_arvalid,
    input  wire                               m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]            m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]          m_axi_rdata,
    input  wire [1:0]                         m_axi_rresp,
    input  wire                               m_axi_rlast,
    input  wire                               m_axi_rvalid,
    output wire                               m_axi_rready,

    /*
     * Configuration
     */
    input  wire                               enable,
    input  wire [15:0]                        requester_id,
    input  wire                               requester_id_enable,
    input  wire [2:0]                         max_payload_size
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN*AXI_WORD_WIDTH;

parameter AXIS_PCIE_WORD_WIDTH = AXIS_PCIE_KEEP_WIDTH;
parameter AXIS_PCIE_WORD_SIZE = AXIS_PCIE_DATA_WIDTH/AXIS_PCIE_WORD_WIDTH;

parameter OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH/8);
parameter WORD_LEN_WIDTH = LEN_WIDTH - $clog2(AXIS_PCIE_KEEP_WIDTH);
parameter CYCLE_COUNT_WIDTH = 13-AXI_BURST_SIZE;

parameter SEQ_NUM_MASK = {RQ_SEQ_NUM_WIDTH-1{1'b1}};
parameter SEQ_NUM_FLAG = {1'b1, {RQ_SEQ_NUM_WIDTH-1{1'b0}}};

parameter OP_TAG_WIDTH = $clog2(OP_TABLE_SIZE);

// bus width assertions
initial begin
    if (AXIS_PCIE_DATA_WIDTH != 64 && AXIS_PCIE_DATA_WIDTH != 128 && AXIS_PCIE_DATA_WIDTH != 256 && AXIS_PCIE_DATA_WIDTH != 512) begin
        $error("Error: PCIe interface width must be 64, 128, 256, or 512 (instance %m)");
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
        if (RQ_SEQ_NUM_ENABLE && RQ_SEQ_NUM_WIDTH != 4) begin
            $error("Error: RQ sequence number width must be 4 (instance %m)");
            $finish;
        end
    end else begin
        if (RQ_SEQ_NUM_ENABLE && RQ_SEQ_NUM_WIDTH != 6) begin
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

    if (AXI_DATA_WIDTH != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: AXI interface width must match PCIe interface width (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH * 8 != AXI_DATA_WIDTH) begin
        $error("Error: AXI interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
        $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
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

localparam [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

localparam [3:0]
    DMA_ERROR_NONE = 4'd0,
    DMA_ERROR_PARITY = 4'd1,
    DMA_ERROR_CPL_POISONED = 4'd2,
    DMA_ERROR_CPL_STATUS_UR = 4'd3,
    DMA_ERROR_CPL_STATUS_CRS = 4'd4,
    DMA_ERROR_CPL_STATUS_CA = 4'd5,
    DMA_ERROR_PCIE_FLR = 4'd6,
    DMA_ERROR_AXI_RD_SLVERR = 4'd8,
    DMA_ERROR_AXI_RD_DECERR = 4'd9,
    DMA_ERROR_AXI_WR_SLVERR = 4'd10,
    DMA_ERROR_AXI_WR_DECERR = 4'd11,
    DMA_ERROR_TIMEOUT = 4'd15;

localparam [1:0]
    AXI_STATE_IDLE = 2'd0,
    AXI_STATE_START = 2'd1,
    AXI_STATE_REQ = 2'd2;

reg [1:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

localparam [2:0]
    TLP_STATE_IDLE = 3'd0,
    TLP_STATE_HEADER_1 = 3'd1,
    TLP_STATE_HEADER_2 = 3'd2,
    TLP_STATE_TRANSFER = 3'd3,
    TLP_STATE_PASSTHROUGH = 3'd4;

reg [2:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

// datapath control signals
reg transfer_in_save;

reg [12:0] tlp_count;
reg [10:0] dword_count;
reg last_tlp;
reg [PCIE_ADDR_WIDTH-1:0] pcie_addr;

reg [12:0] tr_count;
reg last_tr;
reg [AXI_ADDR_WIDTH-1:0] axi_addr;

reg [PCIE_ADDR_WIDTH-1:0] pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, axi_addr_next;
reg [LEN_WIDTH-1:0] op_count_reg = {LEN_WIDTH{1'b0}}, op_count_next;
reg [LEN_WIDTH-1:0] tr_count_reg = {LEN_WIDTH{1'b0}}, tr_count_next;
reg [12:0] tlp_count_reg = 13'd0, tlp_count_next;
reg zero_len_reg = 1'b0, zero_len_next;

reg [PCIE_ADDR_WIDTH-1:0] tlp_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, tlp_addr_next;
reg [11:0] tlp_len_reg = 12'd0, tlp_len_next;
reg tlp_zero_len_reg = 1'b0, tlp_zero_len_next;
reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
reg [9:0] dword_count_reg = 10'd0, dword_count_next;
reg [CYCLE_COUNT_WIDTH-1:0] input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, input_cycle_count_next;
reg [CYCLE_COUNT_WIDTH-1:0] output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, output_cycle_count_next;
reg input_active_reg = 1'b0, input_active_next;
reg bubble_cycle_reg = 1'b0, bubble_cycle_next;
reg last_cycle_reg = 1'b0, last_cycle_next;
reg [1:0] rresp_reg = AXI_RESP_OKAY, rresp_next;

reg [TAG_WIDTH-1:0] tlp_cmd_tag_reg = {TAG_WIDTH{1'b0}}, tlp_cmd_tag_next;
reg tlp_cmd_last_reg = 1'b0, tlp_cmd_last_next;

reg [127:0] tlp_header_data;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] tlp_tuser;

reg [10:0] max_payload_size_dw_reg = 11'd0;

reg have_credit_reg = 1'b0;

reg [RQ_SEQ_NUM_WIDTH-1:0] active_tx_count_reg = {RQ_SEQ_NUM_WIDTH{1'b0}};
reg active_tx_count_av_reg = 1'b1;
reg inc_active_tx;

reg s_axis_rq_tready_reg = 1'b0, s_axis_rq_tready_next;

reg s_axis_write_desc_ready_reg = 1'b0, s_axis_write_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_write_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_write_desc_status_tag_next;
reg [3:0] m_axis_write_desc_status_error_reg = 4'd0, m_axis_write_desc_status_error_next;
reg m_axis_write_desc_status_valid_reg = 1'b0, m_axis_write_desc_status_valid_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
reg m_axi_rready_reg = 1'b0, m_axi_rready_next;

reg [AXI_DATA_WIDTH-1:0] save_axi_rdata_reg = {AXI_DATA_WIDTH{1'b0}};

wire [AXI_DATA_WIDTH-1:0] shift_axi_rdata = {m_axi_rdata, save_axi_rdata_reg} >> ((AXI_STRB_WIDTH-offset_reg)*AXI_WORD_SIZE);

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
assign m_axis_write_desc_status_error = m_axis_write_desc_status_error_reg;
assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

assign m_axi_arid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_araddr = m_axi_araddr_reg;
assign m_axi_arlen = m_axi_arlen_reg;
assign m_axi_arsize = AXI_BURST_SIZE;
assign m_axi_arburst = 2'b01;
assign m_axi_arlock = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot = 3'b010;
assign m_axi_arvalid = m_axi_arvalid_reg;
assign m_axi_rready = m_axi_rready_reg;

// operation tag management
reg [OP_TAG_WIDTH+1-1:0] op_table_start_ptr_reg = 0;
reg [PCIE_ADDR_WIDTH-1:0] op_table_start_pcie_addr;
reg [11:0] op_table_start_len;
reg op_table_start_zero_len;
reg [9:0] op_table_start_dword_len;
reg [CYCLE_COUNT_WIDTH-1:0] op_table_start_input_cycle_count;
reg [CYCLE_COUNT_WIDTH-1:0] op_table_start_output_cycle_count;
reg [OFFSET_WIDTH-1:0] op_table_start_offset;
reg op_table_start_bubble_cycle;
reg [TAG_WIDTH-1:0] op_table_start_tag;
reg op_table_start_last;
reg op_table_start_en;
reg [OP_TAG_WIDTH+1-1:0] op_table_tx_start_ptr_reg = 0;
reg op_table_tx_start_en;
reg [OP_TAG_WIDTH+1-1:0] op_table_tx_finish_ptr_reg = 0;
reg [1:0] op_table_tx_finish_resp = 0;
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
reg [CYCLE_COUNT_WIDTH-1:0] op_table_input_cycle_count[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [CYCLE_COUNT_WIDTH-1:0] op_table_output_cycle_count[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [OFFSET_WIDTH-1:0] op_table_offset[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_bubble_cycle[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [TAG_WIDTH-1:0] op_table_tag[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_last[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [1:0] op_table_resp[2**OP_TAG_WIDTH-1:0];

integer i;

initial begin
    for (i = 0; i < 2**OP_TAG_WIDTH; i = i + 1) begin
        op_table_pcie_addr[i] = 0;
        op_table_len[i] = 0;
        op_table_zero_len[i] = 0;
        op_table_dword_len[i] = 0;
        op_table_input_cycle_count[i] = 0;
        op_table_output_cycle_count[i] = 0;
        op_table_offset[i] = 0;
        op_table_tag[i] = 0;
        op_table_bubble_cycle[i] = 0;
        op_table_last[i] = 0;
        op_table_resp[i] = 0;
    end
end

always @* begin
    axi_state_next = AXI_STATE_IDLE;

    s_axis_write_desc_ready_next = 1'b0;

    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;

    pcie_addr_next = pcie_addr_reg;
    axi_addr_next = axi_addr_reg;
    op_count_next = op_count_reg;
    tr_count_next = tr_count_reg;
    tlp_count_next = tlp_count_reg;
    zero_len_next = zero_len_reg;

    tlp_cmd_tag_next = tlp_cmd_tag_reg;
    tlp_cmd_last_next = tlp_cmd_last_reg;

    // TLP size computation
    if (op_count_reg <= {max_payload_size_dw_reg, 2'b00}-pcie_addr_reg[1:0]) begin
        // packet smaller than max read request size
        if (((pcie_addr_reg & 12'hfff) + (op_count_reg & 12'hfff)) >> 12 != 0 || op_count_reg >> 12 != 0) begin
            // crosses 4k boundary
            tlp_count = 13'h1000 - pcie_addr_reg[11:0];
            dword_count = 11'h400 - pcie_addr_reg[11:2];
            last_tlp = (((pcie_addr_reg & 12'hfff) + (op_count_reg & 12'hfff)) & 12'hfff) == 0;
            // optimized pcie_addr = pcie_addr_reg + tlp_count
            pcie_addr[PCIE_ADDR_WIDTH-1:12] = pcie_addr_reg[PCIE_ADDR_WIDTH-1:12]+1;
            pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            tlp_count = op_count_reg;
            dword_count = (op_count_reg + pcie_addr_reg[1:0] + 3) >> 2;
            last_tlp = 1'b1;
            // optimized pcie_addr = pcie_addr_reg + tlp_count
            pcie_addr[PCIE_ADDR_WIDTH-1:12] = pcie_addr_reg[PCIE_ADDR_WIDTH-1:12];
            pcie_addr[11:0] = pcie_addr_reg[11:0] + op_count_reg;
        end
    end else begin
        // packet larger than max read request size
        if (((pcie_addr_reg & 12'hfff) + {max_payload_size_dw_reg, 2'b00}) >> 12 != 0) begin
            // crosses 4k boundary
            tlp_count = 13'h1000 - pcie_addr_reg[11:0];
            dword_count = 11'h400 - pcie_addr_reg[11:2];
            last_tlp = 1'b0;
            // optimized pcie_addr = pcie_addr_reg + tlp_count
            pcie_addr[PCIE_ADDR_WIDTH-1:12] = pcie_addr_reg[PCIE_ADDR_WIDTH-1:12]+1;
            pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            tlp_count = {max_payload_size_dw_reg, 2'b00}-pcie_addr_reg[1:0];
            dword_count = max_payload_size_dw_reg;
            last_tlp = 1'b0;
            // optimized pcie_addr = pcie_addr_reg + tlp_count
            pcie_addr[PCIE_ADDR_WIDTH-1:12] = pcie_addr_reg[PCIE_ADDR_WIDTH-1:12];
            pcie_addr[11:0] = {pcie_addr_reg[11:2] + max_payload_size_dw_reg, 2'b00};
        end
    end

    // AXI transfer size computation
    if (tlp_count_reg <= AXI_MAX_BURST_SIZE-axi_addr_reg[OFFSET_WIDTH-1:0] || AXI_MAX_BURST_SIZE >= 4096) begin
        // packet smaller than max read request size
        if (((axi_addr_reg & 12'hfff) + (tlp_count_reg & 12'hfff)) >> 12 != 0 || tlp_count_reg >> 12 != 0) begin
            // crosses 4k boundary
            tr_count = 13'h1000 - axi_addr_reg[11:0];
            last_tr = (((axi_addr_reg & 12'hfff) + (tlp_count_reg & 12'hfff)) & 12'hfff) == 0;
            // optimized axi_addr = axi_addr_reg + tr_count
            axi_addr[AXI_ADDR_WIDTH-1:12] = axi_addr_reg[AXI_ADDR_WIDTH-1:12]+1;
            axi_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            tr_count = tlp_count_reg;
            last_tr = 1'b1;
            // optimized axi_addr = axi_addr_reg + tr_count
            axi_addr[AXI_ADDR_WIDTH-1:12] = axi_addr_reg[AXI_ADDR_WIDTH-1:12];
            axi_addr[11:0] = axi_addr_reg[11:0] + tlp_count_reg;
        end
    end else begin
        // packet larger than max read request size
        if (((axi_addr_reg & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
            // crosses 4k boundary
            tr_count = 13'h1000 - axi_addr_reg[11:0];
            last_tr = 1'b0;
            // optimized axi_addr = axi_addr_reg + tr_count
            axi_addr[AXI_ADDR_WIDTH-1:12] = axi_addr_reg[AXI_ADDR_WIDTH-1:12]+1;
            axi_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            tr_count = AXI_MAX_BURST_SIZE-axi_addr_reg[1:0];
            last_tr = 1'b0;
            // optimized axi_addr = axi_addr_reg + tr_count
            axi_addr[AXI_ADDR_WIDTH-1:12] = axi_addr_reg[AXI_ADDR_WIDTH-1:12];
            axi_addr[11:0] = {axi_addr_reg[11:2], 2'b00} + AXI_MAX_BURST_SIZE;
        end
    end

    op_table_start_pcie_addr = pcie_addr_reg;
    op_table_start_len = tlp_count;
    op_table_start_zero_len = zero_len_reg;
    op_table_start_dword_len = dword_count;
    op_table_start_input_cycle_count = (tlp_count + axi_addr_reg[OFFSET_WIDTH-1:0] - 1) >> AXI_BURST_SIZE;
    if (AXIS_PCIE_DATA_WIDTH >= 256) begin
        op_table_start_output_cycle_count = (tlp_count + 16+pcie_addr_reg[1:0] - 1) >> AXI_BURST_SIZE;
    end else begin
        op_table_start_output_cycle_count = (tlp_count + pcie_addr_reg[1:0] - 1) >> AXI_BURST_SIZE;
    end
    if (AXIS_PCIE_DATA_WIDTH >= 256) begin
        op_table_start_offset = 16+pcie_addr_reg[1:0]-axi_addr_reg[OFFSET_WIDTH-1:0];
        op_table_start_bubble_cycle = axi_addr_reg[OFFSET_WIDTH-1:0] > 16+pcie_addr_reg[1:0];
    end else begin
        op_table_start_offset = pcie_addr_reg[1:0]-axi_addr_reg[OFFSET_WIDTH-1:0];
        op_table_start_bubble_cycle = axi_addr_reg[OFFSET_WIDTH-1:0] > pcie_addr_reg[1:0];
    end
    op_table_start_tag = tlp_cmd_tag_reg;
    op_table_start_last = last_tlp;
    op_table_start_en = 1'b0;

    // TLP segmentation and AXI read request generation
    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state, wait for incoming descriptor
            s_axis_write_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;

            pcie_addr_next = s_axis_write_desc_pcie_addr;
            axi_addr_next = s_axis_write_desc_axi_addr;
            if (s_axis_write_desc_len == 0) begin
                // zero-length operation
                op_count_next = 1;
                zero_len_next = 1'b1;
            end else begin
                op_count_next = s_axis_write_desc_len;
                zero_len_next = 1'b0;
            end

            if (s_axis_write_desc_ready & s_axis_write_desc_valid) begin
                s_axis_write_desc_ready_next = 1'b0;
                tlp_cmd_tag_next = s_axis_write_desc_tag;
                axi_state_next = AXI_STATE_START;
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_START: begin
            // start state, compute TLP length
            tlp_count_next = tlp_count;

            op_table_start_pcie_addr = pcie_addr_reg;
            op_table_start_len = tlp_count;
            op_table_start_zero_len = zero_len_reg;
            op_table_start_dword_len = dword_count;
            op_table_start_input_cycle_count = (tlp_count + axi_addr_reg[OFFSET_WIDTH-1:0] - 1) >> AXI_BURST_SIZE;
            if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                op_table_start_output_cycle_count = (tlp_count + 16+pcie_addr_reg[1:0] - 1) >> AXI_BURST_SIZE;
            end else begin
                op_table_start_output_cycle_count = (tlp_count + pcie_addr_reg[1:0] - 1) >> AXI_BURST_SIZE;
            end
            if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                op_table_start_offset = 16+pcie_addr_reg[1:0]-axi_addr_reg[OFFSET_WIDTH-1:0];
                op_table_start_bubble_cycle = axi_addr_reg[OFFSET_WIDTH-1:0] > 16+pcie_addr_reg[1:0];
            end else begin
                op_table_start_offset = pcie_addr_reg[1:0]-axi_addr_reg[OFFSET_WIDTH-1:0];
                op_table_start_bubble_cycle = axi_addr_reg[OFFSET_WIDTH-1:0] > pcie_addr_reg[1:0];
            end
            op_table_start_tag = tlp_cmd_tag_reg;
            op_table_start_last = last_tlp;

            if (!op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH)) begin
                pcie_addr_next = pcie_addr;
                op_count_next = op_count_reg - tlp_count_next;

                tlp_cmd_last_next = last_tlp;

                op_table_start_en = 1'b1;

                axi_state_next = AXI_STATE_REQ;
            end else begin
                axi_state_next = AXI_STATE_START;
            end
        end
        AXI_STATE_REQ: begin
            // request state, generate AXI read requests
            if (!m_axi_arvalid) begin
                tr_count_next = tr_count;

                m_axi_araddr_next = axi_addr_reg;
                m_axi_arlen_next = (tr_count_next + axi_addr_reg[OFFSET_WIDTH-1:0] - 1) >> AXI_BURST_SIZE;
                m_axi_arvalid_next = 1;

                axi_addr_next = axi_addr;
                tlp_count_next = tlp_count_reg - tr_count_next;

                if (!last_tr) begin
                    axi_state_next = AXI_STATE_REQ;
                end else if (!tlp_cmd_last_reg) begin
                    axi_state_next = AXI_STATE_START;
                end else begin
                    s_axis_write_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;
                    axi_state_next = AXI_STATE_IDLE;
                end
            end else begin
                axi_state_next = AXI_STATE_REQ;
            end
        end
    endcase
end

wire [3:0] first_be = 4'b1111 << tlp_addr_reg[1:0];
wire [3:0] last_be = 4'b1111 >> (3 - ((tlp_addr_reg[1:0] + tlp_len_reg[1:0] - 1) & 3));

always @* begin
    tlp_state_next = TLP_STATE_IDLE;

    transfer_in_save = 1'b0;

    s_axis_rq_tready_next = 1'b0;

    m_axi_rready_next = 1'b0;

    tlp_addr_next = tlp_addr_reg;
    tlp_len_next = tlp_len_reg;
    tlp_zero_len_next = tlp_zero_len_reg;
    dword_count_next = dword_count_reg;
    offset_next = offset_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    bubble_cycle_next = bubble_cycle_reg;
    last_cycle_next = last_cycle_reg;

    if (m_axi_rready && m_axi_rvalid && (m_axi_rresp == AXI_RESP_SLVERR || m_axi_rresp == AXI_RESP_DECERR)) begin
        rresp_next = m_axi_rresp;
    end else begin
        rresp_next = rresp_reg;
    end

    op_table_tx_start_en = 1'b0;
    op_table_tx_finish_resp = rresp_next;
    op_table_tx_finish_en = 1'b0;

    inc_active_tx = 1'b0;

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
        tlp_tuser[3:0] = tlp_zero_len_reg ? 4'b0000 : (dword_count_reg == 1 ? first_be & last_be : first_be); // first BE 0
        tlp_tuser[7:4] = 4'd0; // first BE 1
        tlp_tuser[11:8] = tlp_zero_len_reg ? 4'b0000 : (dword_count_reg == 1 ? 4'b0000 : last_be); // last BE 0
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
        tlp_tuser[66:61] = op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0] & SEQ_NUM_MASK; // seq_num0
        tlp_tuser[72:67] = 6'd0; // seq_num1
        tlp_tuser[136:73] = 64'd0; // parity
    end else begin
        tlp_tuser[3:0] = tlp_zero_len_reg ? 4'b0000 : (dword_count_reg == 1 ? first_be & last_be : first_be); // first BE
        tlp_tuser[7:4] = tlp_zero_len_reg ? 4'b0000 : (dword_count_reg == 1 ? 4'b0000 : last_be); // last BE
        tlp_tuser[10:8] = 3'd0; // addr_offset
        tlp_tuser[11] = 1'b0; // discontinue
        tlp_tuser[12] = 1'b0; // tph_present
        tlp_tuser[14:13] = 2'b00; // tph_type
        tlp_tuser[15] = 1'b0; // tph_indirect_tag_en
        tlp_tuser[23:16] = 8'd0; // tph_st_tag
        tlp_tuser[27:24] = op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0] & SEQ_NUM_MASK; // seq_num
        tlp_tuser[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_WIDTH == 62) begin
            tlp_tuser[61:60] = (op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0] & SEQ_NUM_MASK) >> 4; // seq_num
        end
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        m_axis_rq_tdata_int = tlp_header_data;
        m_axis_rq_tkeep_int = 16'b0000000000001111;
    end else if (AXIS_PCIE_DATA_WIDTH == 256) begin
        m_axis_rq_tdata_int = tlp_header_data;
        m_axis_rq_tkeep_int = 8'b00001111;
    end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
        m_axis_rq_tdata_int = tlp_header_data;
        m_axis_rq_tkeep_int = 4'b1111;
    end else if (AXIS_PCIE_DATA_WIDTH == 64) begin
        m_axis_rq_tdata_int = tlp_header_data[63:0];
        m_axis_rq_tkeep_int = 2'b11;
    end
    m_axis_rq_tvalid_int = 1'b0;
    m_axis_rq_tlast_int = 1'b0;
    m_axis_rq_tuser_int = tlp_tuser;

    // AXI read response processing and TLP generation
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

            m_axi_rready_next = 1'b0;

            tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            tlp_zero_len_next = op_table_zero_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            input_cycle_count_next = op_table_input_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            output_cycle_count_next = op_table_output_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            input_active_next = 1'b1;
            bubble_cycle_next = op_table_bubble_cycle[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            last_cycle_next = op_table_output_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

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
                if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                    m_axi_rready_next = m_axis_rq_tready_int_early;
                end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
                    m_axi_rready_next = m_axis_rq_tready_int_early && bubble_cycle_next;
                end else begin
                    m_axi_rready_next = 1'b0;
                end
                tlp_state_next = TLP_STATE_HEADER_1;
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_HEADER_1: begin
            // header 1 state, send TLP header
            if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                m_axi_rready_next = m_axis_rq_tready_int_early && input_active_reg;

                m_axis_rq_tdata_int[AXIS_PCIE_DATA_WIDTH-1:128] = shift_axi_rdata[AXIS_PCIE_DATA_WIDTH-1:128];
                if (dword_count_reg >= AXIS_PCIE_KEEP_WIDTH-4) begin
                    m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}};
                end else begin
                    m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}} >> (AXIS_PCIE_KEEP_WIDTH-4 - dword_count_reg);
                end

                if (m_axis_rq_tready_int_reg && ((m_axi_rready && m_axi_rvalid) || !input_active_reg)) begin
                    transfer_in_save = m_axi_rready && m_axi_rvalid;

                    if (bubble_cycle_reg) begin
                        if (input_active_reg) begin
                            input_cycle_count_next = input_cycle_count_reg - 1;
                            input_active_next = input_cycle_count_reg != 0;
                        end
                        bubble_cycle_next = 1'b0;
                        m_axi_rready_next = m_axis_rq_tready_int_early && input_active_next;
                        tlp_state_next = TLP_STATE_HEADER_1;
                    end else begin
                        dword_count_next = dword_count_reg - (AXIS_PCIE_KEEP_WIDTH-4);
                        if (input_active_reg) begin
                            input_cycle_count_next = input_cycle_count_reg - 1;
                            input_active_next = input_cycle_count_reg != 0;
                        end
                        output_cycle_count_next = output_cycle_count_reg - 1;
                        last_cycle_next = output_cycle_count_next == 0;

                        m_axis_rq_tvalid_int = 1'b1;

                        inc_active_tx = 1'b1;

                        if (last_cycle_reg) begin
                            m_axis_rq_tlast_int = 1'b1;
                            op_table_tx_finish_resp = rresp_next;
                            op_table_tx_finish_en = 1'b1;

                            rresp_next = AXI_RESP_OKAY;

                            // skip idle state if possible
                            tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                            tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                            dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                            offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                            input_cycle_count_next = op_table_input_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                            output_cycle_count_next = op_table_output_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                            input_active_next = 1'b1;
                            bubble_cycle_next = op_table_bubble_cycle[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                            last_cycle_next = op_table_output_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

                            if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && !s_axis_rq_tvalid && (!TX_FC_ENABLE || have_credit_reg) && (!RQ_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                                op_table_tx_start_en = 1'b1;
                                if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                                    m_axi_rready_next = m_axis_rq_tready_int_early;
                                end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
                                    m_axi_rready_next = m_axis_rq_tready_int_early && bubble_cycle_next;
                                end else begin
                                    m_axi_rready_next = 1'b0;
                                end
                                tlp_state_next = TLP_STATE_HEADER_1;
                            end else begin
                                s_axis_rq_tready_next = m_axis_rq_tready_int_early;
                                m_axi_rready_next = 0;
                                tlp_state_next = TLP_STATE_IDLE;
                            end
                        end else begin
                            m_axi_rready_next = m_axis_rq_tready_int_early && input_active_next;
                            tlp_state_next = TLP_STATE_TRANSFER;
                        end
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER_1;
                end
            end else begin
                if (m_axis_rq_tready_int_reg) begin
                    m_axis_rq_tvalid_int = 1'b1;

                    inc_active_tx = 1'b1;

                    if (AXIS_PCIE_DATA_WIDTH == 128) begin
                        m_axi_rready_next = m_axis_rq_tready_int_early;
                        if ((m_axi_rready && m_axi_rvalid) && bubble_cycle_reg) begin
                            transfer_in_save = 1'b1;
                            if (input_active_reg) begin
                                input_cycle_count_next = input_cycle_count_reg - 1;
                                input_active_next = input_cycle_count_reg != 0;
                            end
                            bubble_cycle_next = 1'b0;
                            m_axi_rready_next = m_axis_rq_tready_int_early && input_active_next;
                        end
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end else begin
                        m_axi_rready_next = m_axis_rq_tready_int_early && bubble_cycle_reg;
                        tlp_state_next = TLP_STATE_HEADER_2;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER_1;
                end
            end
        end
        TLP_STATE_HEADER_2: begin
            // header 2 state, send rest of TLP header (64 bit interface only)
            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axis_rq_tdata_int = tlp_header_data[127:64];
                m_axis_rq_tkeep_int = 2'b11;

                if (m_axis_rq_tready_int_reg) begin
                    m_axis_rq_tvalid_int = 1'b1;

                    m_axi_rready_next = m_axis_rq_tready_int_early;
                    if ((m_axi_rready && m_axi_rvalid) && bubble_cycle_reg) begin
                        transfer_in_save = 1'b1;
                        if (input_active_reg) begin
                            input_cycle_count_next = input_cycle_count_reg - 1;
                            input_active_next = input_cycle_count_reg != 0;
                        end
                        bubble_cycle_next = 1'b0;
                        m_axi_rready_next = m_axis_rq_tready_int_early && input_active_next;
                    end
                    tlp_state_next = TLP_STATE_TRANSFER;
                end else begin
                    tlp_state_next = TLP_STATE_HEADER_2;
                end
            end
        end
        TLP_STATE_TRANSFER: begin
            // transfer state, transfer data
            m_axi_rready_next = m_axis_rq_tready_int_early && input_active_reg;

            m_axis_rq_tdata_int = shift_axi_rdata;
            if (dword_count_reg >= AXIS_PCIE_KEEP_WIDTH) begin
                m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}};
            end else begin
                m_axis_rq_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b1}} >> (AXIS_PCIE_KEEP_WIDTH - dword_count_reg);
            end

            if (m_axis_rq_tready_int_reg && ((m_axi_rready && m_axi_rvalid) || !input_active_reg)) begin
                transfer_in_save = 1'b1;

                if (bubble_cycle_reg) begin
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg != 0;
                    end
                    bubble_cycle_next = 1'b0;
                    m_axi_rready_next = m_axis_rq_tready_int_early && input_active_next;
                    tlp_state_next = TLP_STATE_TRANSFER;
                end else begin
                    dword_count_next = dword_count_reg - AXIS_PCIE_KEEP_WIDTH;
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg != 0;
                    end
                    output_cycle_count_next = output_cycle_count_reg - 1;
                    last_cycle_next = output_cycle_count_next == 0;

                    m_axis_rq_tvalid_int = 1'b1;

                    if (last_cycle_reg) begin
                        m_axis_rq_tlast_int = 1'b1;
                        op_table_tx_finish_resp = rresp_next;
                        op_table_tx_finish_en = 1'b1;

                        rresp_next = AXI_RESP_OKAY;

                        // skip idle state if possible
                        tlp_addr_next = op_table_pcie_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        tlp_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        dword_count_next = op_table_dword_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        input_cycle_count_next = op_table_input_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        output_cycle_count_next = op_table_output_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        input_active_next = 1'b1;
                        bubble_cycle_next = op_table_bubble_cycle[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                        last_cycle_next = op_table_output_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

                        if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && !s_axis_rq_tvalid && (!TX_FC_ENABLE || have_credit_reg) && (!RQ_SEQ_NUM_ENABLE || active_tx_count_av_reg)) begin
                            op_table_tx_start_en = 1'b1;
                            if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                                m_axi_rready_next = m_axis_rq_tready_int_early;
                            end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
                                m_axi_rready_next = m_axis_rq_tready_int_early && bubble_cycle_next;
                            end else begin
                                m_axi_rready_next = 1'b0;
                            end
                            tlp_state_next = TLP_STATE_HEADER_1;
                        end else begin
                            s_axis_rq_tready_next = m_axis_rq_tready_int_early;
                            m_axi_rready_next = 0;
                            tlp_state_next = TLP_STATE_IDLE;
                        end
                    end else begin
                        m_axi_rready_next = m_axis_rq_tready_int_early && input_active_next;
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end
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

    m_axis_write_desc_status_tag_next = op_table_tag[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]];
    if (op_table_resp[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] == AXI_RESP_SLVERR) begin
        m_axis_write_desc_status_error_next = DMA_ERROR_AXI_RD_SLVERR;
    end else if (op_table_resp[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] == AXI_RESP_DECERR) begin
        m_axis_write_desc_status_error_next = DMA_ERROR_AXI_RD_DECERR;
    end else begin
        m_axis_write_desc_status_error_next = DMA_ERROR_NONE;
    end
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
    axi_state_reg <= axi_state_next;
    tlp_state_reg <= tlp_state_next;

    pcie_addr_reg <= pcie_addr_next;
    axi_addr_reg <= axi_addr_next;
    op_count_reg <= op_count_next;
    tr_count_reg <= tr_count_next;
    tlp_count_reg <= tlp_count_next;
    zero_len_reg <= zero_len_next;

    tlp_addr_reg <= tlp_addr_next;
    tlp_len_reg <= tlp_len_next;
    tlp_zero_len_reg <= tlp_zero_len_next;
    dword_count_reg <= dword_count_next;
    offset_reg <= offset_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    bubble_cycle_reg <= bubble_cycle_next;
    last_cycle_reg <= last_cycle_next;
    rresp_reg <= rresp_next;

    tlp_cmd_tag_reg <= tlp_cmd_tag_next;
    tlp_cmd_last_reg <= tlp_cmd_last_next;

    s_axis_rq_tready_reg <= s_axis_rq_tready_next;

    s_axis_write_desc_ready_reg <= s_axis_write_desc_ready_next;

    m_axis_write_desc_status_tag_reg <= m_axis_write_desc_status_tag_next;
    m_axis_write_desc_status_error_reg <= m_axis_write_desc_status_error_next;
    m_axis_write_desc_status_valid_reg <= m_axis_write_desc_status_valid_next;

    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;
    m_axi_arvalid_reg <= m_axi_arvalid_next;
    m_axi_rready_reg <= m_axi_rready_next;

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

    if (op_table_start_en) begin
        op_table_start_ptr_reg <= op_table_start_ptr_reg + 1;
        op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b1;
        op_table_tx_done[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b0;
        op_table_pcie_addr[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_pcie_addr;
        op_table_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_len;
        op_table_zero_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_zero_len;
        op_table_dword_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_dword_len;
        op_table_input_cycle_count[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_input_cycle_count;
        op_table_output_cycle_count[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_output_cycle_count;
        op_table_offset[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_offset;
        op_table_bubble_cycle[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_bubble_cycle;
        op_table_tag[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_tag;
        op_table_last[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_last;
    end

    if (op_table_tx_start_en) begin
        op_table_tx_start_ptr_reg <= op_table_tx_start_ptr_reg + 1;
    end

    if (op_table_tx_finish_en) begin
        op_table_tx_finish_ptr_reg <= op_table_tx_finish_ptr_reg + 1;
        op_table_resp[op_table_tx_finish_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_tx_finish_resp;
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

    if (transfer_in_save) begin
        save_axi_rdata_reg <= m_axi_rdata;
    end

    if (rst) begin
        axi_state_reg <= AXI_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;

        s_axis_rq_tready_reg <= 1'b0;
        s_axis_write_desc_ready_reg <= 1'b0;
        m_axis_write_desc_status_valid_reg <= 1'b0;
        m_axi_arvalid_reg <= 1'b0;
        m_axi_rready_reg <= 1'b0;

        rresp_reg <= AXI_RESP_OKAY;

        active_tx_count_reg <= {RQ_SEQ_NUM_WIDTH{1'b0}};
        active_tx_count_av_reg <= 1'b1;

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

`resetall
