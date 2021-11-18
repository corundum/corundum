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
 * AXI DMA read interface
 */
module dma_if_axi_rd #
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
    // RAM segment count
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
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr,
    output wire [7:0]                                   m_axi_arlen,
    output wire [2:0]                                   m_axi_arsize,
    output wire [1:0]                                   m_axi_arburst,
    output wire                                         m_axi_arlock,
    output wire [3:0]                                   m_axi_arcache,
    output wire [2:0]                                   m_axi_arprot,
    output wire                                         m_axi_arvalid,
    input  wire                                         m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]                    m_axi_rdata,
    input  wire [1:0]                                   m_axi_rresp,
    input  wire                                         m_axi_rlast,
    input  wire                                         m_axi_rvalid,
    output wire                                         m_axi_rready,

    /*
     * AXI read descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]                    s_axis_read_desc_axi_addr,
    input  wire [RAM_SEL_WIDTH-1:0]                     s_axis_read_desc_ram_sel,
    input  wire [RAM_ADDR_WIDTH-1:0]                    s_axis_read_desc_ram_addr,
    input  wire [LEN_WIDTH-1:0]                         s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]                         s_axis_read_desc_tag,
    input  wire                                         s_axis_read_desc_valid,
    output wire                                         s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [TAG_WIDTH-1:0]                         m_axis_read_desc_status_tag,
    output wire [3:0]                                   m_axis_read_desc_status_error,
    output wire                                         m_axis_read_desc_status_valid,

    /*
     * RAM interface
     */
    output wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_wr_cmd_sel,
    output wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    ram_wr_cmd_be,
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_wr_cmd_addr,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_wr_cmd_data,
    output wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_ready,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_wr_done,

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

parameter OP_TAG_WIDTH = $clog2(OP_TABLE_SIZE);
parameter OP_TABLE_READ_COUNT_WIDTH = AXI_ID_WIDTH+1;
parameter OP_TABLE_WRITE_COUNT_WIDTH = LEN_WIDTH;

parameter STATUS_FIFO_ADDR_WIDTH = 5;
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
    AXI_STATE_IDLE = 1'd0,
    AXI_STATE_WRITE = 1'd1;

reg [0:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

reg [AXI_ADDR_WIDTH-1:0] req_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, req_axi_addr_next;
reg [RAM_SEL_WIDTH-1:0] req_ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, req_ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] req_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, req_ram_addr_next;
reg [LEN_WIDTH-1:0] req_op_count_reg = {LEN_WIDTH{1'b0}}, req_op_count_next;
reg [LEN_WIDTH-1:0] req_tr_count_reg = {LEN_WIDTH{1'b0}}, req_tr_count_next;
reg [TAG_WIDTH-1:0] req_tag_reg = {TAG_WIDTH{1'b0}}, req_tag_next;

reg [RAM_SEL_WIDTH-1:0] ram_sel_reg = {RAM_SEL_WIDTH{1'b0}}, ram_sel_next;
reg [RAM_ADDR_WIDTH-1:0] addr_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_next;
reg [RAM_ADDR_WIDTH-1:0] addr_delay_reg = {RAM_ADDR_WIDTH{1'b0}}, addr_delay_next;
reg [12:0] op_count_reg = 13'd0, op_count_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_0_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_0_next;
reg [RAM_SEG_COUNT-1:0] ram_mask_1_reg = {RAM_SEG_COUNT{1'b0}}, ram_mask_1_next;
reg ram_wrap_reg = 1'b0, ram_wrap_next;
reg [OFFSET_WIDTH+1-1:0] cycle_byte_count_reg = {OFFSET_WIDTH+1{1'b0}}, cycle_byte_count_next;
reg [RAM_OFFSET_WIDTH-1:0] start_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, start_offset_next;
reg [RAM_OFFSET_WIDTH-1:0] end_offset_reg = {RAM_OFFSET_WIDTH{1'b0}}, end_offset_next;
reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
reg [OP_TAG_WIDTH-1:0] op_tag_reg = {OP_TAG_WIDTH{1'b0}}, op_tag_next;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_wr_ptr_reg = 0;
reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_rd_ptr_reg = 0, status_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [OP_TAG_WIDTH-1:0] status_fifo_op_tag[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_SEG_COUNT-1:0] status_fifo_mask[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg status_fifo_finish[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [OP_TAG_WIDTH-1:0] status_fifo_wr_op_tag;
reg [RAM_SEG_COUNT-1:0] status_fifo_wr_mask;
reg status_fifo_wr_finish;
reg status_fifo_we;
reg status_fifo_finish_reg = 1'b0, status_fifo_finish_next;
reg status_fifo_we_reg = 1'b0, status_fifo_we_next;
reg status_fifo_half_full_reg = 1'b0;
reg [OP_TAG_WIDTH-1:0] status_fifo_rd_op_tag_reg = 0, status_fifo_rd_op_tag_next;
reg [RAM_SEG_COUNT-1:0] status_fifo_rd_mask_reg = 0, status_fifo_rd_mask_next;
reg status_fifo_rd_finish_reg = 1'b0, status_fifo_rd_finish_next;
reg status_fifo_rd_valid_reg = 1'b0, status_fifo_rd_valid_next;

reg [AXI_DATA_WIDTH-1:0] m_axi_rdata_int_reg = {AXI_DATA_WIDTH{1'b0}}, m_axi_rdata_int_next;
reg m_axi_rvalid_int_reg = 1'b0, m_axi_rvalid_int_next;

reg [AXI_ID_WIDTH-1:0] m_axi_arid_reg = {AXI_ID_WIDTH{1'b0}}, m_axi_arid_next;
reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
reg m_axi_rready_reg = 1'b0, m_axi_rready_next;

reg s_axis_read_desc_ready_reg = 1'b0, s_axis_read_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_read_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_read_desc_status_tag_next;
reg [3:0] m_axis_read_desc_status_error_reg = 4'd0, m_axis_read_desc_status_error_next;
reg m_axis_read_desc_status_valid_reg = 1'b0, m_axis_read_desc_status_valid_next;

// internal datapath
reg  [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]  ram_wr_cmd_sel_int;
reg  [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_int;
reg  [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_int;
reg  [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_int;
reg  [RAM_SEG_COUNT-1:0]                ram_wr_cmd_valid_int;
reg  [RAM_SEG_COUNT-1:0]                ram_wr_cmd_ready_int;

wire [RAM_SEG_COUNT-1:0] out_done;
reg [RAM_SEG_COUNT-1:0] out_done_ack;

assign m_axi_arid = m_axi_arid_reg;
assign m_axi_araddr = m_axi_araddr_reg;
assign m_axi_arlen = m_axi_arlen_reg;
assign m_axi_arsize = AXI_BURST_SIZE;
assign m_axi_arburst = 2'b01;
assign m_axi_arlock = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot = 3'b010;
assign m_axi_arvalid = m_axi_arvalid_reg;
assign m_axi_rready = m_axi_rready_reg;

assign s_axis_read_desc_ready = s_axis_read_desc_ready_reg;

assign m_axis_read_desc_status_tag = m_axis_read_desc_status_tag_reg;
assign m_axis_read_desc_status_error = m_axis_read_desc_status_error_reg;
assign m_axis_read_desc_status_valid = m_axis_read_desc_status_valid_reg;

// operation tag management
reg [OP_TAG_WIDTH+1-1:0] op_table_start_ptr_reg = 0;
reg [AXI_ADDR_WIDTH-1:0] op_table_start_axi_addr;
reg [RAM_SEL_WIDTH-1:0] op_table_start_ram_sel;
reg [RAM_ADDR_WIDTH-1:0] op_table_start_ram_addr;
reg [11:0] op_table_start_len;
reg [CYCLE_COUNT_WIDTH-1:0] op_table_start_cycle_count;
reg [TAG_WIDTH-1:0] op_table_start_tag;
reg op_table_start_last;
reg op_table_start_en;
reg op_table_write_complete_en;
reg [OP_TAG_WIDTH-1:0] op_table_write_complete_ptr;
reg [OP_TAG_WIDTH+1-1:0] op_table_finish_ptr_reg = 0;
reg op_table_finish_en;

reg [2**OP_TAG_WIDTH-1:0] op_table_active = 0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_ADDR_WIDTH-1:0] op_table_axi_addr [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_SEL_WIDTH-1:0] op_table_ram_sel [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [RAM_ADDR_WIDTH-1:0] op_table_ram_addr [2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [11:0] op_table_len[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [CYCLE_COUNT_WIDTH-1:0] op_table_cycle_count[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [TAG_WIDTH-1:0] op_table_tag[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_last[2**OP_TAG_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg op_table_write_complete[2**OP_TAG_WIDTH-1:0];

integer i;

initial begin
    for (i = 0; i < 2**OP_TAG_WIDTH; i = i + 1) begin
        op_table_axi_addr[i] = 0;
        op_table_ram_sel[i] = 0;
        op_table_ram_addr[i] = 0;
        op_table_len[i] = 0;
        op_table_cycle_count[i] = 0;
        op_table_tag[i] = 0;
        op_table_last[i] = 0;
        op_table_write_complete[i] = 0;
    end
end

always @* begin
    req_state_next = REQ_STATE_IDLE;

    s_axis_read_desc_ready_next = 1'b0;

    req_axi_addr_next = req_axi_addr_reg;
    req_ram_sel_next = req_ram_sel_reg;
    req_ram_addr_next = req_ram_addr_reg;
    req_op_count_next = req_op_count_reg;
    req_tr_count_next = req_tr_count_reg;
    req_tag_next = req_tag_reg;

    m_axi_arid_next = m_axi_arid_reg;
    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;

    op_table_start_axi_addr = req_axi_addr_reg;
    op_table_start_ram_sel = req_ram_sel_reg;
    op_table_start_ram_addr = req_ram_addr_reg;
    op_table_start_len = 0;
    op_table_start_tag = req_tag_reg;
    op_table_start_cycle_count = 0;
    op_table_start_last = 0;
    op_table_start_en = 1'b0;

    // segmentation and request generation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            s_axis_read_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;

            req_axi_addr_next = s_axis_read_desc_axi_addr;
            req_ram_sel_next = s_axis_read_desc_ram_sel;
            req_ram_addr_next = s_axis_read_desc_ram_addr;
            req_op_count_next = s_axis_read_desc_len;
            req_tag_next = s_axis_read_desc_tag;

            if (req_op_count_next <= AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                // packet smaller than max burst size
                if (((req_axi_addr_next & 12'hfff) + (req_op_count_next & 12'hfff)) >> 12 != 0 || req_op_count_next >> 12 != 0) begin
                    // crosses 4k boundary
                    req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    req_tr_count_next = req_op_count_next;
                end
            end else begin
                // packet larger than max burst size
                if (((req_axi_addr_next & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
                    // crosses 4k boundary
                    req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    req_tr_count_next = AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK);
                end
            end

            if (s_axis_read_desc_ready && s_axis_read_desc_valid) begin
                s_axis_read_desc_ready_next = 1'b0;
                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            if (!op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && (!m_axi_arvalid || m_axi_arready)) begin
                req_axi_addr_next = req_axi_addr_reg + req_tr_count_reg;
                req_ram_addr_next = req_ram_addr_reg + req_tr_count_reg;
                req_op_count_next = req_op_count_reg - req_tr_count_reg;

                op_table_start_axi_addr = req_axi_addr_reg;
                op_table_start_ram_sel = req_ram_sel_reg;
                op_table_start_ram_addr = req_ram_addr_reg;
                op_table_start_len = req_tr_count_next;
                op_table_start_tag = req_tag_reg;
                op_table_start_cycle_count = (req_tr_count_next + (req_axi_addr_reg & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
                op_table_start_last = req_op_count_reg == req_tr_count_next;
                op_table_start_en = 1'b1;

                m_axi_arid_next = op_table_start_ptr_reg[OP_TAG_WIDTH-1:0];
                m_axi_araddr_next = req_axi_addr_reg;
                m_axi_arlen_next = op_table_start_cycle_count;
                m_axi_arvalid_next = 1'b1;

                if (req_op_count_next <= AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                    // packet smaller than max burst size
                    if (((req_axi_addr_next & 12'hfff) + (req_op_count_next & 12'hfff)) >> 12 != 0 || req_op_count_next >> 12 != 0) begin
                        // crosses 4k boundary
                        req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        req_tr_count_next = req_op_count_next;
                    end
                end else begin
                    // packet larger than max burst size
                    if (((req_axi_addr_next & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
                        // crosses 4k boundary
                        req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        req_tr_count_next = AXI_MAX_BURST_SIZE - (req_axi_addr_next & OFFSET_MASK);
                    end
                end

                if (!op_table_start_last) begin
                    req_state_next = REQ_STATE_START;
                end else begin
                    s_axis_read_desc_ready_next = !op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] && ($unsigned(op_table_start_ptr_reg - op_table_finish_ptr_reg) < 2**OP_TAG_WIDTH) && enable;
                    req_state_next = REQ_STATE_IDLE;
                end
            end else begin
                req_state_next = REQ_STATE_START;
            end
        end
    endcase
end

always @* begin
    axi_state_next = AXI_STATE_IDLE;

    m_axi_rready_next = 1'b0;

    ram_sel_next = ram_sel_reg;
    addr_next = addr_reg;
    addr_delay_next = addr_delay_reg;
    op_count_next = op_count_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_0_next = ram_mask_0_reg;
    ram_mask_1_next = ram_mask_1_reg;
    ram_wrap_next = ram_wrap_reg;
    cycle_byte_count_next = cycle_byte_count_reg;
    start_offset_next = start_offset_reg;
    end_offset_next = end_offset_reg;
    offset_next = offset_reg;
    op_tag_next = op_tag_reg;

    op_table_write_complete_en = 1'b0;
    op_table_write_complete_ptr = m_axi_rid;

    m_axi_rdata_int_next = m_axi_rdata_int_reg;
    m_axi_rvalid_int_next = 1'b0;

    status_fifo_finish_next = 1'b0;
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
    ram_wr_cmd_data_int = {3{m_axi_rdata_int_reg}} >> (AXI_DATA_WIDTH - offset_reg*AXI_WORD_SIZE);
    ram_wr_cmd_valid_int = {RAM_SEG_COUNT{1'b0}};

    if (m_axi_rvalid_int_reg) begin
        ram_wr_cmd_valid_int = ram_mask_reg;
    end

    // AXI read response handling
    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state, wait for read data
            m_axi_rready_next = &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

            op_tag_next = m_axi_rid[OP_TAG_WIDTH-1:0];
            ram_sel_next = op_table_ram_sel[op_tag_next];
            addr_next = op_table_ram_addr[op_tag_next];
            op_count_next = op_table_len[op_tag_next];
            offset_next = op_table_ram_addr[op_tag_next][RAM_OFFSET_WIDTH-1:0]-(op_table_axi_addr[op_tag_next] & OFFSET_MASK);

            if (m_axi_rready && m_axi_rvalid) begin
                if (op_count_next > AXI_WORD_WIDTH-(op_table_axi_addr[m_axi_rid[OP_TAG_WIDTH-1:0]] & OFFSET_MASK)) begin
                    cycle_byte_count_next = AXI_WORD_WIDTH-(op_table_axi_addr[m_axi_rid[OP_TAG_WIDTH-1:0]] & OFFSET_MASK);
                end else begin
                    cycle_byte_count_next = op_count_next;
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

                addr_delay_next = addr_next;
                addr_next = addr_next + cycle_byte_count_next;
                op_count_next = op_count_next - cycle_byte_count_next;

                m_axi_rdata_int_next = m_axi_rdata;
                m_axi_rvalid_int_next = 1'b1;

                status_fifo_finish_next = 1'b0;
                status_fifo_we_next = 1'b1;

                if (m_axi_rlast) begin
                    status_fifo_finish_next = 1'b1;
                    axi_state_next = AXI_STATE_IDLE;
                end else begin
                    axi_state_next = AXI_STATE_WRITE;
                end
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_WRITE: begin
            // write state - generate write operations
            m_axi_rready_next = &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

            if (m_axi_rready && m_axi_rvalid) begin

                if (op_count_next > AXI_WORD_WIDTH) begin
                    cycle_byte_count_next = AXI_WORD_WIDTH;
                end else begin
                    cycle_byte_count_next = op_count_next;
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

                addr_delay_next = addr_next;
                addr_next = addr_next + cycle_byte_count_next;
                op_count_next = op_count_next - cycle_byte_count_next;

                m_axi_rdata_int_next = m_axi_rdata;
                m_axi_rvalid_int_next = 1'b1;

                status_fifo_finish_next = 1'b0;
                status_fifo_we_next = 1'b1;

                if (m_axi_rlast) begin
                    status_fifo_finish_next = 1'b1;
                    axi_state_next = AXI_STATE_IDLE;
                end else begin
                    axi_state_next = AXI_STATE_WRITE;
                end
            end else begin
                axi_state_next = AXI_STATE_WRITE;
            end
        end
    endcase

    status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg;

    status_fifo_wr_op_tag = op_tag_reg;
    status_fifo_wr_mask = ram_mask_reg;
    status_fifo_wr_finish = status_fifo_finish_reg;
    status_fifo_we = 1'b0;

    if (status_fifo_we_reg) begin
        status_fifo_wr_op_tag = op_tag_reg;
        status_fifo_wr_mask = ram_mask_reg;
        status_fifo_wr_finish = status_fifo_finish_reg;
        status_fifo_we = 1'b1;
    end

    status_fifo_rd_op_tag_next = status_fifo_rd_op_tag_reg;
    status_fifo_rd_mask_next = status_fifo_rd_mask_reg;
    status_fifo_rd_finish_next = status_fifo_rd_finish_reg;
    status_fifo_rd_valid_next = status_fifo_rd_valid_reg;

    op_table_write_complete_ptr = status_fifo_rd_op_tag_reg;
    op_table_write_complete_en = 1'b0;

    if (status_fifo_rd_valid_reg && (status_fifo_rd_mask_reg & ~out_done) == 0) begin
        // got write completion, pop and return status
        status_fifo_rd_valid_next = 1'b0;

        out_done_ack = status_fifo_rd_mask_reg;

        if (status_fifo_rd_finish_reg) begin
            // mark done
            op_table_write_complete_ptr = status_fifo_rd_op_tag_reg;
            op_table_write_complete_en = 1'b1;
        end
    end

    if (!status_fifo_rd_valid_next && status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin
        // status FIFO not empty
        status_fifo_rd_op_tag_next = status_fifo_op_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
        status_fifo_rd_mask_next = status_fifo_mask[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
        status_fifo_rd_finish_next = status_fifo_finish[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
        status_fifo_rd_valid_next = 1'b1;
        status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg + 1;
    end

    // commit operations in-order
    op_table_finish_en = 1'b0;

    m_axis_read_desc_status_tag_next = op_table_tag[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]];
    m_axis_read_desc_status_error_next = 0;
    m_axis_read_desc_status_valid_next = 1'b0;

    if (op_table_active[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_write_complete[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]] && op_table_finish_ptr_reg != op_table_start_ptr_reg) begin
        op_table_finish_en = 1'b1;

        if (op_table_last[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]]) begin
            m_axis_read_desc_status_tag_next = op_table_tag[op_table_finish_ptr_reg[OP_TAG_WIDTH-1:0]];
            m_axis_read_desc_status_error_next = 0;
            m_axis_read_desc_status_valid_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    req_state_reg <= req_state_next;
    axi_state_reg <= axi_state_next;

    req_axi_addr_reg <= req_axi_addr_next;
    req_ram_sel_reg <= req_ram_sel_next;
    req_ram_addr_reg <= req_ram_addr_next;
    req_op_count_reg <= req_op_count_next;
    req_tr_count_reg <= req_tr_count_next;
    req_tag_reg <= req_tag_next;

    ram_sel_reg <= ram_sel_next;
    addr_reg <= addr_next;
    addr_delay_reg <= addr_delay_next;
    op_count_reg <= op_count_next;
    ram_mask_reg <= ram_mask_next;
    ram_mask_0_reg <= ram_mask_0_next;
    ram_mask_1_reg <= ram_mask_1_next;
    ram_wrap_reg <= ram_wrap_next;
    cycle_byte_count_reg <= cycle_byte_count_next;
    start_offset_reg <= start_offset_next;
    end_offset_reg <= end_offset_next;
    offset_reg <= offset_next;
    op_tag_reg <= op_tag_next;

    m_axi_rdata_int_reg <= m_axi_rdata_int_next;
    m_axi_rvalid_int_reg <= m_axi_rvalid_int_next;

    m_axi_arid_reg <= m_axi_arid_next;
    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;
    m_axi_arvalid_reg <= m_axi_arvalid_next;
    m_axi_rready_reg <= m_axi_rready_next;

    s_axis_read_desc_ready_reg <= s_axis_read_desc_ready_next;

    m_axis_read_desc_status_tag_reg <= m_axis_read_desc_status_tag_next;
    m_axis_read_desc_status_error_reg <= m_axis_read_desc_status_error_next;
    m_axis_read_desc_status_valid_reg <= m_axis_read_desc_status_valid_next;

    if (status_fifo_we) begin
        status_fifo_op_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_op_tag;
        status_fifo_mask[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_mask;
        status_fifo_finish[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_finish;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end
    status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_next;

    status_fifo_finish_reg <= status_fifo_finish_next;
    status_fifo_we_reg <= status_fifo_we_next;

    status_fifo_rd_op_tag_reg <= status_fifo_rd_op_tag_next;
    status_fifo_rd_mask_reg <= status_fifo_rd_mask_next;
    status_fifo_rd_finish_reg <= status_fifo_rd_finish_next;
    status_fifo_rd_valid_reg <= status_fifo_rd_valid_next;

    status_fifo_half_full_reg <= $unsigned(status_fifo_wr_ptr_reg - status_fifo_rd_ptr_reg) >= 2**(STATUS_FIFO_ADDR_WIDTH-1);

    if (op_table_start_en) begin
        op_table_start_ptr_reg <= op_table_start_ptr_reg + 1;
        op_table_active[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b1;
        op_table_axi_addr[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_axi_addr;
        op_table_ram_sel[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_ram_sel;
        op_table_ram_addr[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_ram_addr;
        op_table_len[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_len;
        op_table_cycle_count[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_cycle_count;
        op_table_tag[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_tag;
        op_table_last[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= op_table_start_last;
        op_table_write_complete[op_table_start_ptr_reg[OP_TAG_WIDTH-1:0]] <= 1'b0;
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
        axi_state_reg <= AXI_STATE_IDLE;

        m_axi_rdata_int_reg <= 1'b0;

        m_axi_arvalid_reg <= 1'b0;
        m_axi_rready_reg <= 1'b0;

        s_axis_read_desc_ready_reg <= 1'b0;
        m_axis_read_desc_status_valid_reg <= 1'b0;

        status_fifo_wr_ptr_reg <= 0;
        status_fifo_rd_ptr_reg <= 0;
        status_fifo_we_reg <= 1'b0;
        status_fifo_rd_valid_reg <= 1'b0;

        op_table_active <= 0;
    end
end

// output datapath logic (write data)
generate

genvar n;

for (n = 0; n < RAM_SEG_COUNT; n = n + 1) begin

    reg [RAM_SEL_WIDTH-1:0]  ram_wr_cmd_sel_reg = {RAM_SEL_WIDTH{1'b0}};
    reg [RAM_SEG_BE_WIDTH-1:0]   ram_wr_cmd_be_reg = {RAM_SEG_BE_WIDTH{1'b0}};
    reg [RAM_SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr_reg = {RAM_SEG_ADDR_WIDTH{1'b0}};
    reg [RAM_SEG_DATA_WIDTH-1:0] ram_wr_cmd_data_reg = {RAM_SEG_DATA_WIDTH{1'b0}};
    reg                      ram_wr_cmd_valid_reg = 1'b0;

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
