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
 * AXI DMA write interface
 */
module dma_if_axi_wr #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // RAM segment countm_axis_read_desc_status_error
    parameter RAM_SEG_COUNT = 2,
    // RAM segment data width
    parameter RAM_SEG_DATA_WIDTH = AXI_DATA_WIDTH*2/RAM_SEG_COUNT,
    // RAM segment address width
    parameter RAM_SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    // RAM select width
    parameter RAM_SEL_WIDTH = 2,
    // RAM address width
    parameter RAM_ADDR_WIDTH = RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH),
    // Length field width
    parameter LEN_WIDTH = 16,
    // Tag field width
    parameter TAG_WIDTH = 8,
    // Operation table size
    parameter OP_TABLE_SIZE = 2**(AXI_ID_WIDTH),
    // Use AXI ID signals
    parameter USE_AXI_ID = 1
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr,
    output wire [7:0]                                   m_axi_awlen,
    output wire [2:0]                                   m_axi_awsize,
    output wire [1:0]                                   m_axi_awburst,
    output wire                                         m_axi_awlock,
    output wire [3:0]                                   m_axi_awcache,
    output wire [2:0]                                   m_axi_awprot,
    output wire                                         m_axi_awvalid,
    input  wire                                         m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]                    m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]                    m_axi_wstrb,
    output wire                                         m_axi_wlast,
    output wire                                         m_axi_wvalid,
    input  wire                                         m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_bid,
    input  wire [1:0]                                   m_axi_bresp,
    input  wire                                         m_axi_bvalid,
    output wire                                         m_axi_bready,

    /*
     * AXI write descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]                    s_axis_write_desc_axi_addr,
    input  wire [RAM_SEL_WIDTH-1:0]                     s_axis_write_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]                    s_axis_write_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                         s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]                         s_axis_write_desc_tag,
    input  wire                                         s_axis_write_desc_valid,
    output wire                                         s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                         m_axis_write_desc_status_tag,
    output wire [3:0]                                   m_axis_write_desc_status_error,
    output wire                                         m_axis_write_desc_status_valid,

    /*
     * RAM interface
     */
    output wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_rd_cmd_sel,
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_ready,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_valid,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_ready,

    /*
     * Configuration
     */
    input  wire                                         enable
);

parameter RAM_WORD_WIDTH = RAM_SEG_BE_WIDTH;
parameter RAM_WORD_SIZE = RAM_SEG_DATA_WIDTH/RAM_WORD_WIDTH;

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

parameter OFFSET_WIDTH = AXI_STRB_WIDTH > 1 ? $clog2(AXI_STRB_WIDTH) : 1;
parameter OFFSET_MASK = AXI_STRB_WIDTH > 1 ? {OFFSET_WIDTH{1'b1}} : 0;
parameter RAM_OFFSET_WIDTH = $clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH);
parameter ADDR_MASK = {AXI_ADDR_WIDTH{1'b1}} << $clog2(AXI_STRB_WIDTH);
parameter CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1;

parameter MASK_FIFO_ADDR_WIDTH = $clog2(OP_TABLE_SIZE)+1;

parameter OP_TAG_WIDTH = $clog2(OP_TABLE_SIZE);

parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

// bus width assertions
initial begin
    if (AXI_WORD_SIZE * AXI_STRB_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisble (instance %m)");
        $finish;
    end

    if (AXI_WORD_SIZE != RAM_WORD_SIZE) begin
        $error("Error: word size mismatch (instance %m)");
        $finish;
    end

    if (2**$clog2(AXI_WORD_WIDTH) != AXI_WORD_WIDTH) begin
        $error("Error: AXI word width must be even power of two (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
        $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
        $finish;
    end

    if (RAM_SEG_COUNT < 2) begin
        $error("Error: RAM interface requires at least 2 segments (instance %m)");
        $finish;
    end

    if (RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH != AXI_DATA_WIDTH*2) begin
        $error("Error: RAM interface width must be double the AXI interface width (instance %m)");
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

localparam [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

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

localparam [0:0]
    READ_STATE_IDLE = 1'd0,
    READ_STATE_READ = 1'd1;

reg [0:0] read_state_reg = READ_STATE_IDLE, read_state_next;

localparam [0:0]
    AXI_STATE_IDLE = 1'd0,
    AXI_STATE_TRANSFER = 1'd1;

reg [0:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

// datapath control signals
reg mask_fifo_we;

reg read_cmd_ready;

reg [AXI_ADDR_WIDTH-1:0] req_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, req_axi_addr_next;
reg [RAM_SEL_WIDTH-1:0] ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, ram_addr_next;
reg [LEN_WIDTH-1:0] op_count_reg = {LEN_WIDTH{1'b0}}, op_count_next;
reg [LEN_WIDTH-1:0] tr_count_reg = {LEN_WIDTH{1'b0}}, tr_count_next;
reg [12:0] tr_word_count_reg = 13'd0, tr_word_count_next;
reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;

reg [AXI_ADDR_WIDTH-1:0] read_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, read_axi_addr_next;
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

reg [AXI_ADDR_WIDTH-1:0] axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, axi_addr_next;
reg [12:0] axi_len_reg = 13'd0, axi_len_next;
reg [RAM_OFFSET_WIDTH-1:0] offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, offset_next;
reg [AXI_STRB_WIDTH-1:0] strb_offset_mask_reg = {AXI_STRB_WIDTH{1'b1}}, strb_offset_mask_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_next;
reg ram_mask_valid_reg = 1'b0, ram_mask_valid_next;
reg [CYCLE_COUNT_WIDTH-1:0] cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, cycle_count_next;
reg last_cycle_reg = 1'b0, last_cycle_next;

reg [AXI_ADDR_WIDTH-1:0] read_cmd_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, read_cmd_axi_addr_next;
reg [RAM_SEL_WIDTH-1:0] read_cmd_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, read_cmd_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] read_cmd_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, read_cmd_ram_addr_next;
reg [12:0] read_cmd_len_reg = 13'd0, read_cmd_len_next;
reg [CYCLE_COUNT_WIDTH-1:0] read_cmd_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, read_cmd_cycle_count_next;
reg read_cmd_last_cycle_reg = 1'b0, read_cmd_last_cycle_next;
reg read_cmd_valid_reg = 1'b0, read_cmd_valid_next;

reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_wr_ptr_reg = 0;
reg [MASK_FIFO_ADDR_WIDTH+1-1:0] mask_fifo_rd_ptr_reg = 0, mask_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_SEG_COUNT-1:0] mask_fifo_mask[(2**MASK_FIFO_ADDR_WIDTH)-1:0];
reg [RAM_SEG_COUNT-1:0] mask_fifo_wr_mask;

wire mask_fifo_empty = mask_fifo_wr_ptr_reg == mask_fifo_rd_ptr_reg;
wire mask_fifo_full = mask_fifo_wr_ptr_reg == (mask_fifo_rd_ptr_reg ^ (1 << MASK_FIFO_ADDR_WIDTH));

reg [AXI_ID_WIDTH-1:0] m_axi_awid_reg = {AXI_ID_WIDTH{1'b0}}, m_axi_awid_next;
reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_awaddr_next;
reg [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
reg m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;
reg m_axi_bready_reg = 1'b0, m_axi_bready_next;

reg s_axis_write_desc_ready_reg = 1'b0, s_axis_write_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_write_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_write_desc_status_tag_next;
reg [3:0] m_axis_write_desc_status_error_reg = 4'd0, m_axis_write_desc_status_error_next;
reg m_axis_write_desc_status_valid_reg = 1'b0, m_axis_write_desc_status_valid_next;

reg [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0] ram_rd_cmd_sel_reg = 0, ram_rd_cmd_sel_next;
reg [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0] ram_rd_cmd_addr_reg = 0, ram_rd_cmd_addr_next;
reg [RAM_SEG_COUNT-1:0] ram_rd_cmd_valid_reg = 0, ram_rd_cmd_valid_next;
reg [RAM_SEG_COUNT-1:0] ram_rd_resp_ready_cmb;

// internal datapath
reg  [AXI_DATA_WIDTH-1:0] m_axi_wdata_int;
reg  [AXI_STRB_WIDTH-1:0] m_axi_wstrb_int;
reg                       m_axi_wlast_int;
reg                       m_axi_wvalid_int;
wire                      m_axi_wready_int;

assign m_axi_awid = m_axi_awid_reg;
assign m_axi_awaddr = m_axi_awaddr_reg;
assign m_axi_awlen = m_axi_awlen_reg;
assign m_axi_awsize = AXI_BURST_SIZE;
assign m_axi_awburst = 2'b01;
assign m_axi_awlock = 1'b0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot = 3'b010;
assign m_axi_awvalid = m_axi_awvalid_reg;
assign m_axi_bready = m_axi_bready_reg;

assign s_axis_write_desc_ready = s_axis_write_desc_ready_reg;

assign m_axis_write_desc_status_tag = m_axis_write_desc_status_tag_reg;
assign m_axis_write_desc_status_error = m_axis_write_desc_status_error_reg;
assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

assign ram_rd_cmd_sel = ram_rd_cmd_sel_reg;
assign ram_rd_cmd_addr = ram_rd_cmd_addr_reg;
assign ram_rd_cmd_valid = ram_rd_cmd_valid_reg;
assign ram_rd_resp_ready = ram_rd_resp_ready_cmb;

// operation tag management
reg [OP_TAG_WIDTH+1-1:0] op_table_start_ptr_reg = 0;
reg [AXI_ADDR_WIDTH-1:0] op_table_start_axi_addr;
reg [11:0] op_table_start_len;
reg [CYCLE_COUNT_WIDTH-1:0] op_table_start_cycle_count;
reg [RAM_OFFSET_WIDTH-1:0] op_table_start_offset;
reg [TAG_WIDTH-1:0] op_table_start_tag;
reg op_table_start_last;
reg op_table_start_en;
reg [OP_TAG_WIDTH+1-1:0] op_table_tx_start_ptr_reg = 0;
reg op_table_tx_start_en;
reg [OP_TAG_WIDTH+1-1:0] op_table_tx_finish_ptr_reg = 0;
reg op_table_tx_finish_en;
reg op_table_write_complete_en;
reg [OP_TAG_WIDTH-1:0] op_table_write_complete_ptr;
reg [OP_TAG_WIDTH+1-1:0] op_table_finish_ptr_reg = 0;
reg op_table_finish_en;

reg [2**OP_TAG_WIDTH-1:0] op_table_active = 0;
reg [2**OP_TAG_WIDTH-1:0] op_table_write_complete = 0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_ADDR_WIDTH-1:0] op_table_axi_addr[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [11:0] op_table_len[2**OP_TAG_WIDTH-1:0];
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
        op_table_axi_addr[i] = 0;
        op_table_len[i] = 0;
        op_table_cycle_count[i] = 0;
        op_table_offset[i] = 0;
        op_table_tag[i] = 0;
        op_table_last[i] = 0;
    end
end

always @* begin
    req_state_next = REQ_STATE_IDLE;

    s_axis_write_desc_ready_next = 1'b0;

    tag_next = tag_reg;
    req_axi_addr_next = req_axi_addr_reg;
    ram_sel_next = ram_sel_reg;
    ram_addr_next = ram_addr_reg;
    op_count_next = op_count_reg;
    tr_count_next = tr_count_reg;
    tr_word_count_next = tr_word_count_reg;

    read_cmd_axi_addr_next = read_cmd_axi_addr_reg;
    read_cmd_ram_sel_next = read_cmd_ram_sel_reg;
    read_cmd_ram_addr_next = read_cmd_ram_addr_reg;
    read_cmd_len_next = read_cmd_len_reg;
    read_cmd_cycle_count_next = read_cmd_cycle_count_reg;
    read_cmd_last_cycle_next = read_cmd_last_cycle_reg;
    read_cmd_valid_next = read_cmd_valid_reg && !read_cmd_ready;

    op_table_start_axi_addr = req_axi_addr_reg;
    op_table_start_len = 0;
    op_table_start_cycle_count = 0;
    op_table_start_offset = (req_axi_addr_reg & OFFSET_MASK)-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
    op_table_start_tag = tag_reg;
    op_table_start_last = 0;
    op_table_start_en = 1'b0;

    // TLP segmentation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            // idle state, wait for incoming descriptor
            s_axis_write_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;

            req_axi_addr_next = s_axis_write_desc_axi_addr;
            ram_sel_next = s_axis_write_desc_ram_sel;
            ram_addr_next = s_axis_write_desc_ram_addr;
            op_count_next = s_axis_write_desc_len;
            tag_next = s_axis_write_desc_tag;

            if (op_count_next <= AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                // packet smaller than max burst size
                if (((req_axi_addr_next & 12'hfff) + (op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    tr_word_count_next = op_count_next;
                end
            end else begin
                // packet larger than max burst size
                if (((req_axi_addr_next & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    tr_word_count_next = AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK);
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
            // start state, compute length
            if (!op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && (!ram_rd_cmd_valid_reg || ram_rd_cmd_ready) && (!read_cmd_valid_reg || read_cmd_ready)) begin
                read_cmd_axi_addr_next = req_axi_addr_reg;
                read_cmd_ram_sel_next = ram_sel_reg;
                read_cmd_ram_addr_next = ram_addr_reg;
                read_cmd_len_next = tr_word_count_next;
                read_cmd_cycle_count_next = (tr_word_count_next + (req_axi_addr_reg & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
                op_table_start_cycle_count = read_cmd_cycle_count_next;
                read_cmd_last_cycle_next = read_cmd_cycle_count_next == 0;
                read_cmd_valid_next = 1'b1;

                req_axi_addr_next = req_axi_addr_reg + tr_word_count_next;
                ram_addr_next = ram_addr_reg + tr_word_count_next;
                op_count_next = op_count_reg - tr_word_count_next;

                op_table_start_axi_addr = req_axi_addr_reg;
                op_table_start_len = tr_word_count_next;
                op_table_start_offset = (req_axi_addr_reg & OFFSET_MASK)-ram_addr_reg[RAM_OFFSET_WIDTH-1:0];
                op_table_start_tag = tag_reg;
                op_table_start_last = op_count_reg == tr_word_count_next;
                op_table_start_en = 1'b1;

                if (op_count_next <= AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                    // packet smaller than max burst size
                    if (((req_axi_addr_next & 12'hfff) + (op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                        // crosses 4k boundary
                        tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        tr_word_count_next = op_count_next;
                    end
                end else begin
                    // packet larger than max burst size
                    if (((req_axi_addr_next & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
                        // crosses 4k boundary
                        tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        tr_word_count_next = AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK);
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

    read_axi_addr_next = read_axi_addr_reg;
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

            read_axi_addr_next = read_cmd_axi_addr_reg;
            read_ram_sel_next = read_cmd_ram_sel_reg;
            read_ram_addr_next = read_cmd_ram_addr_reg;
            read_len_next = read_cmd_len_reg;
            read_cycle_count_next = read_cmd_cycle_count_reg;
            read_last_cycle_next = read_cmd_last_cycle_reg;

            if (read_len_next > AXI_STRB_WIDTH-(read_axi_addr_next & OFFSET_MASK)) begin
                cycle_byte_count_next = AXI_STRB_WIDTH-(read_axi_addr_next & OFFSET_MASK);
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
                    if (read_ram_mask_0_reg[i]) begin
                        ram_rd_cmd_sel_next[i*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = read_ram_sel_reg;
                        ram_rd_cmd_addr_next[i*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-RAM_SEG_ADDR_WIDTH];
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                    if (read_ram_mask_1_reg[i]) begin
                        ram_rd_cmd_sel_next[i*RAM_SEL_WIDTH +: RAM_SEL_WIDTH] = read_ram_sel_reg;
                        ram_rd_cmd_addr_next[i*RAM_SEG_ADDR_WIDTH +: RAM_SEG_ADDR_WIDTH] = read_ram_addr_reg[RAM_ADDR_WIDTH-1:RAM_ADDR_WIDTH-RAM_SEG_ADDR_WIDTH]+1;
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                end

                mask_fifo_wr_mask = read_ram_mask_reg;
                mask_fifo_we = 1'b1;

                if (read_len_next > AXI_STRB_WIDTH) begin
                    cycle_byte_count_next = AXI_STRB_WIDTH;
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
                end else if (read_cmd_valid_reg) begin

                    read_axi_addr_next = read_cmd_axi_addr_reg;
                    read_ram_sel_next = read_cmd_ram_sel_reg;
                    read_ram_addr_next = read_cmd_ram_addr_reg;
                    read_len_next = read_cmd_len_reg;
                    read_cycle_count_next = read_cmd_cycle_count_reg;
                    read_last_cycle_next = read_cmd_last_cycle_reg;

                    if (read_len_next > AXI_STRB_WIDTH-(read_axi_addr_next & OFFSET_MASK)) begin
                        cycle_byte_count_next = AXI_STRB_WIDTH-(read_axi_addr_next & OFFSET_MASK);
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

always @* begin
    axi_state_next = AXI_STATE_IDLE;

    ram_rd_resp_ready_cmb = {RAM_SEG_COUNT{1'b0}};

    axi_addr_next = axi_addr_reg;
    axi_len_next = axi_len_reg;
    offset_next = offset_reg;
    strb_offset_mask_next = strb_offset_mask_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_valid_next = ram_mask_valid_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg;

    op_table_tx_start_en = 1'b0;
    op_table_tx_finish_en = 1'b0;

    op_table_write_complete_en = 1'b0;
    op_table_write_complete_ptr = m_axi_bid;

    m_axi_awid_next = m_axi_awid_reg;
    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;
    m_axi_bready_next = 1'b0;

    m_axi_wdata_int = 0;
    m_axi_wstrb_int = 0;
    m_axi_wlast_int = 1'b0;
    m_axi_wvalid_int = 1'b0;

    // read response processing and AXI write generation
    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state, wait for command
            ram_rd_resp_ready_cmb = {RAM_SEG_COUNT{1'b0}};

            axi_addr_next = op_table_axi_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            axi_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            strb_offset_mask_next = {AXI_STRB_WIDTH{1'b1}} << (axi_addr_next & OFFSET_MASK);
            last_cycle_offset_next = axi_addr_next + (axi_len_next & OFFSET_MASK);
            cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
            last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

            if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && (!m_axi_awvalid_reg || m_axi_awready)) begin
                m_axi_awid_next = op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0];
                m_axi_awaddr_next = axi_addr_next;
                m_axi_awlen_next = cycle_count_next;
                m_axi_awvalid_next = 1'b1;
                op_table_tx_start_en = 1'b1;
                axi_state_next = AXI_STATE_TRANSFER;
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_TRANSFER: begin
            // transfer state, transfer data
            ram_rd_resp_ready_cmb = {RAM_SEG_COUNT{1'b0}};

            if (!(ram_mask_reg & ~ram_rd_resp_valid) && ram_mask_valid_reg && m_axi_wready_int) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;
                ram_mask_valid_next = 1'b0;

                // update counters
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;
                offset_next = offset_reg + AXI_STRB_WIDTH;
                strb_offset_mask_next = {AXI_STRB_WIDTH{1'b1}};

                m_axi_wdata_int = {2{ram_rd_resp_data}} >> (RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-offset_reg*AXI_WORD_SIZE);
                m_axi_wstrb_int = strb_offset_mask_reg;
                m_axi_wvalid_int = 1'b1;

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    m_axi_wlast_int = 1'b1;
                    op_table_tx_finish_en = 1'b1;

                    if (last_cycle_offset_reg) begin
                        m_axi_wstrb_int = strb_offset_mask_reg & {AXI_STRB_WIDTH{1'b1}} >> (AXI_STRB_WIDTH - last_cycle_offset_reg);
                    end

                    // skip idle state if possible
                    axi_addr_next = op_table_axi_addr[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    axi_len_next = op_table_len[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    offset_next = op_table_offset[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    strb_offset_mask_next = {AXI_STRB_WIDTH{1'b1}} << (axi_addr_next & OFFSET_MASK);
                    last_cycle_offset_next = axi_addr_next + (axi_len_next & OFFSET_MASK);
                    cycle_count_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]];
                    last_cycle_next = op_table_cycle_count[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] == 0;

                    if (op_table_active[op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_tx_start_ptr_reg != op_table_start_ptr_reg && (!m_axi_awvalid_reg || m_axi_awready)) begin
                        m_axi_awid_next = op_table_tx_start_ptr_reg[OP_TAG_WIDTH-1:0];
                        m_axi_awaddr_next = axi_addr_next;
                        m_axi_awlen_next = cycle_count_next;
                        m_axi_awvalid_next = 1'b1;
                        op_table_tx_start_en = 1'b1;
                        axi_state_next = AXI_STATE_TRANSFER;
                    end else begin
                        axi_state_next = AXI_STATE_IDLE;
                    end
                end else begin
                    axi_state_next = AXI_STATE_TRANSFER;
                end
            end else begin
                axi_state_next = AXI_STATE_TRANSFER;
            end
        end
    endcase

    if (!ram_mask_valid_next && !mask_fifo_empty) begin
        ram_mask_next = mask_fifo_mask[mask_fifo_rd_ptr_reg[MASK_FIFO_ADDR_WIDTH-1:0]];
        ram_mask_valid_next = 1'b1;
        mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg+1;
    end

    // accept write completions
    m_axi_bready_next = 1'b1;
    if (m_axi_bready && m_axi_bvalid) begin
        op_table_write_complete_en = 1'b1;
        op_table_write_complete_ptr = m_axi_bid;
    end

    // commit operations in-order
    op_table_finish_en = 1'b0;

    m_axis_write_desc_status_tag_next = op_table_tag[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]];
    m_axis_write_desc_status_error_next = 0;
    m_axis_write_desc_status_valid_next = 1'b0;

    if (op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_write_complete[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_finish_ptr_reg != op_table_tx_finish_ptr_reg) begin
        op_table_finish_en = 1'b1;

        if (op_table_last[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) begin
            m_axis_write_desc_status_tag_next = op_table_tag[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]];
            m_axis_write_desc_status_error_next = 0;
            m_axis_write_desc_status_valid_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    req_state_reg <= req_state_next;
    read_state_reg <= read_state_next;
    axi_state_reg <= axi_state_next;

    req_axi_addr_reg <= req_axi_addr_next;
    ram_sel_reg <= ram_sel_next;
    ram_addr_reg <= ram_addr_next;
    op_count_reg <= op_count_next;
    tr_count_reg <= tr_count_next;
    tr_word_count_reg <= tr_word_count_next;
    tag_reg <= tag_next;

    read_axi_addr_reg <= read_axi_addr_next;
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

    axi_addr_reg <= axi_addr_next;
    axi_len_reg <= axi_len_next;
    offset_reg <= offset_next;
    strb_offset_mask_reg <= strb_offset_mask_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    ram_mask_reg <= ram_mask_next;
    ram_mask_valid_reg <= ram_mask_valid_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;

    read_cmd_axi_addr_reg <= read_cmd_axi_addr_next;
    read_cmd_ram_sel_reg <= read_cmd_ram_sel_next;
    read_cmd_ram_addr_reg <= read_cmd_ram_addr_next;
    read_cmd_len_reg <= read_cmd_len_next;
    read_cmd_cycle_count_reg <= read_cmd_cycle_count_next;
    read_cmd_last_cycle_reg <= read_cmd_last_cycle_next;
    read_cmd_valid_reg <= read_cmd_valid_next;

    m_axi_awid_reg <= m_axi_awid_next;
    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;
    m_axi_awvalid_reg <= m_axi_awvalid_next;
    m_axi_bready_reg <= m_axi_bready_next;

    s_axis_write_desc_ready_reg <= s_axis_write_desc_ready_next;

    m_axis_write_desc_status_tag_reg <= m_axis_write_desc_status_tag_next;
    m_axis_write_desc_status_error_reg <= m_axis_write_desc_status_error_next;
    m_axis_write_desc_status_valid_reg <= m_axis_write_desc_status_valid_next;

    ram_rd_cmd_sel_reg <= ram_rd_cmd_sel_next;
    ram_rd_cmd_addr_reg <= ram_rd_cmd_addr_next;
    ram_rd_cmd_valid_reg <= ram_rd_cmd_valid_next;

    if (mask_fifo_we) begin
        mask_fifo_mask[mask_fifo_wr_ptr_reg[MASK_FIFO_ADDR_WIDTH-1:0]] <= mask_fifo_wr_mask;
        mask_fifo_wr_ptr_reg <= mask_fifo_wr_ptr_reg + 1;
    end
    mask_fifo_rd_ptr_reg <= mask_fifo_rd_ptr_next;

    if (op_table_start_en) begin
        op_table_start_ptr_reg <= op_table_start_ptr_reg + 1;
        op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b1;
        op_table_write_complete[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b0;
        op_table_axi_addr[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_axi_addr;
        op_table_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_len;
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

    if (op_table_write_complete_en) begin
        op_table_write_complete[op_table_write_complete_ptr] <= 1'b1;
    end

    if (op_table_finish_en) begin
        op_table_finish_ptr_reg <= op_table_finish_ptr_reg + 1;
        op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b0;
    end

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        read_state_reg <= READ_STATE_IDLE;
        axi_state_reg <= AXI_STATE_IDLE;

        read_cmd_valid_reg <= 1'b0;

        ram_mask_valid_reg <= 1'b0;

        m_axi_awvalid_reg <= 1'b0;
        m_axi_bready_reg <= 1'b0;

        s_axis_write_desc_ready_reg <= 1'b0;
        m_axis_write_desc_status_valid_reg <= 1'b0;

        ram_rd_cmd_valid_reg <= {RAM_SEG_COUNT{1'b0}};

        mask_fifo_wr_ptr_reg <= 0;
        mask_fifo_rd_ptr_reg <= 0;

        op_table_start_ptr_reg <= 0;
        op_table_tx_start_ptr_reg <= 0;
        op_table_tx_finish_ptr_reg <= 0;
        op_table_finish_ptr_reg <= 0;
        op_table_active <= 0;
    end
end

// output datapath logic
reg [AXI_DATA_WIDTH-1:0] m_axi_wdata_reg  = {AXI_DATA_WIDTH{1'b0}};
reg [AXI_STRB_WIDTH-1:0] m_axi_wstrb_reg  = {AXI_STRB_WIDTH{1'b0}};
reg                      m_axi_wlast_reg  = 1'b0;
reg                      m_axi_wvalid_reg = 1'b0;

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_DATA_WIDTH-1:0] out_fifo_wdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_STRB_WIDTH-1:0] out_fifo_wstrb[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg                      out_fifo_wlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axi_wready_int = !out_fifo_half_full_reg;

assign m_axi_wdata  = m_axi_wdata_reg;
assign m_axi_wstrb  = m_axi_wstrb_reg;
assign m_axi_wvalid = m_axi_wvalid_reg;
assign m_axi_wlast  = m_axi_wlast_reg;

always @(posedge clk) begin
    m_axi_wvalid_reg <= m_axi_wvalid_reg && !m_axi_wready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axi_wvalid_int) begin
        out_fifo_wdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wdata_int;
        out_fifo_wstrb[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wstrb_int;
        out_fifo_wlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wlast_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axi_wvalid_reg || m_axi_wready)) begin
        m_axi_wdata_reg <= out_fifo_wdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wstrb_reg <= out_fifo_wstrb[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wlast_reg <= out_fifo_wlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wvalid_reg <= 1'b1;
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axi_wvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
