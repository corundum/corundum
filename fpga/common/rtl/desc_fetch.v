/*

Copyright 2019, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Descriptor fetch module
 */
module desc_fetch #
(
    // Number of ports
    parameter PORTS = 2,
    // Select field width
    parameter SELECT_WIDTH = $clog2(PORTS),
    // RAM segment count
    parameter SEG_COUNT = 2,
    // RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // RAM address width
    parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH),
    // DMA RAM pipeline stages
    parameter RAM_PIPELINE = 2,
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA length field width
    parameter DMA_LEN_WIDTH = 20,
    // DMA tag field width
    parameter DMA_TAG_WIDTH = 8,
    // Transmit request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 4,
    // Completion queue index width
    parameter CPL_QUEUE_INDEX_WIDTH = 4,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Descriptor size (in bytes)
    parameter DESC_SIZE = 16,
    // Log desc block size field width
    parameter LOG_BLOCK_SIZE_WIDTH = 2,
    // Descriptor table size (number of in-flight operations)
    parameter DESC_TABLE_SIZE = 8,
    // Width of AXI stream interface in bits
    parameter AXIS_DATA_WIDTH = DESC_SIZE*8,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8
)
(
    input  wire                                   clk,
    input  wire                                   rst,

    /*
     * Descriptor read request input
     */
    input  wire [SELECT_WIDTH-1:0]                s_axis_req_sel,
    input  wire [QUEUE_INDEX_WIDTH-1:0]           s_axis_req_queue,
    input  wire [REQ_TAG_WIDTH-1:0]               s_axis_req_tag,
    input  wire                                   s_axis_req_valid,
    output wire                                   s_axis_req_ready,

    /*
     * Descriptor read request status output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]           m_axis_req_status_queue,
    output wire [QUEUE_PTR_WIDTH-1:0]             m_axis_req_status_ptr,
    output wire [CPL_QUEUE_INDEX_WIDTH-1:0]       m_axis_req_status_cpl,
    output wire [REQ_TAG_WIDTH-1:0]               m_axis_req_status_tag,
    output wire                                   m_axis_req_status_empty,
    output wire                                   m_axis_req_status_error,
    output wire                                   m_axis_req_status_valid,

    /*
     * Descriptor data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]             m_axis_desc_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]             m_axis_desc_tkeep,
    output wire                                   m_axis_desc_tvalid,
    input  wire                                   m_axis_desc_tready,
    output wire                                   m_axis_desc_tlast,
    output wire [REQ_TAG_WIDTH-1:0]               m_axis_desc_tid,
    output wire                                   m_axis_desc_tuser,

    /*
     * Descriptor dequeue request output
     */
    output wire [PORTS*QUEUE_INDEX_WIDTH-1:0]     m_axis_desc_dequeue_req_queue,
    output wire [PORTS*REQ_TAG_WIDTH-1:0]         m_axis_desc_dequeue_req_tag,
    output wire [PORTS-1:0]                       m_axis_desc_dequeue_req_valid,
    input  wire [PORTS-1:0]                       m_axis_desc_dequeue_req_ready,

    /*
     * Descriptor dequeue response input
     */
    input  wire [PORTS*QUEUE_INDEX_WIDTH-1:0]     s_axis_desc_dequeue_resp_queue,
    input  wire [PORTS*QUEUE_PTR_WIDTH-1:0]       s_axis_desc_dequeue_resp_ptr,
    input  wire [PORTS*DMA_ADDR_WIDTH-1:0]        s_axis_desc_dequeue_resp_addr,
    input  wire [PORTS*LOG_BLOCK_SIZE_WIDTH-1:0]  s_axis_desc_dequeue_resp_block_size,
    input  wire [PORTS*CPL_QUEUE_INDEX_WIDTH-1:0] s_axis_desc_dequeue_resp_cpl,
    input  wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]   s_axis_desc_dequeue_resp_tag,
    input  wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]    s_axis_desc_dequeue_resp_op_tag,
    input  wire [PORTS-1:0]                       s_axis_desc_dequeue_resp_empty,
    input  wire [PORTS-1:0]                       s_axis_desc_dequeue_resp_error,
    input  wire [PORTS-1:0]                       s_axis_desc_dequeue_resp_valid,
    output wire [PORTS-1:0]                       s_axis_desc_dequeue_resp_ready,

    /*
     * Descriptor dequeue commit output
     */
    output wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]    m_axis_desc_dequeue_commit_op_tag,
    output wire [PORTS-1:0]                       m_axis_desc_dequeue_commit_valid,
    input  wire [PORTS-1:0]                       m_axis_desc_dequeue_commit_ready,

    /*
     * DMA read descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]              m_axis_dma_read_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]              m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]               m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]               m_axis_dma_read_desc_tag,
    output wire                                   m_axis_dma_read_desc_valid,
    input  wire                                   m_axis_dma_read_desc_ready,

    /*
     * DMA read descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]               s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                             s_axis_dma_read_desc_status_error,
    input  wire                                   s_axis_dma_read_desc_status_valid,

    /*
     * RAM interface
     */
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]      dma_ram_wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]    dma_ram_wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]    dma_ram_wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                   dma_ram_wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                   dma_ram_wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                   dma_ram_wr_done,

    /*
     * Configuration
     */
    input  wire                                   enable
);

parameter CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
parameter DESC_PTR_MASK = {CL_DESC_TABLE_SIZE{1'b1}};

parameter CL_PORTS = $clog2(PORTS);

parameter CL_DESC_SIZE = $clog2(DESC_SIZE);

// bus width assertions
initial begin
    if (DMA_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: DMA tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (QUEUE_REQ_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: Queue request tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (QUEUE_REQ_TAG_WIDTH < REQ_TAG_WIDTH) begin
        $error("Error: QUEUE_REQ_TAG_WIDTH must be at least REQ_TAG_WIDTH (instance %m)");
        $finish;
    end

    if (AXIS_KEEP_WIDTH * 8 != AXIS_DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (2**CL_DESC_SIZE != DESC_SIZE) begin
        $error("Error: Descriptor size must be even power of two (instance %m)");
        $finish;
    end
end

reg s_axis_req_ready_reg = 1'b0, s_axis_req_ready_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_req_status_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_req_status_queue_next;
reg [QUEUE_PTR_WIDTH-1:0] m_axis_req_status_ptr_reg = {QUEUE_PTR_WIDTH{1'b0}}, m_axis_req_status_ptr_next;
reg [CPL_QUEUE_INDEX_WIDTH-1:0] m_axis_req_status_cpl_reg = {CPL_QUEUE_INDEX_WIDTH{1'b0}}, m_axis_req_status_cpl_next;
reg [REQ_TAG_WIDTH-1:0] m_axis_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, m_axis_req_status_tag_next;
reg m_axis_req_status_empty_reg = 1'b0, m_axis_req_status_empty_next;
reg m_axis_req_status_error_reg = 1'b0, m_axis_req_status_error_next;
reg m_axis_req_status_valid_reg = 1'b0, m_axis_req_status_valid_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_desc_dequeue_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_desc_dequeue_req_queue_next;
reg [QUEUE_REQ_TAG_WIDTH-1:0] m_axis_desc_dequeue_req_tag_reg = {QUEUE_REQ_TAG_WIDTH{1'b0}}, m_axis_desc_dequeue_req_tag_next;
reg [PORTS-1:0] m_axis_desc_dequeue_req_valid_reg = {PORTS{1'b0}}, m_axis_desc_dequeue_req_valid_next;

reg [PORTS-1:0] s_axis_desc_dequeue_resp_ready_reg = {PORTS{1'b0}}, s_axis_desc_dequeue_resp_ready_next;

reg [QUEUE_OP_TAG_WIDTH-1:0] m_axis_desc_dequeue_commit_op_tag_reg = {QUEUE_OP_TAG_WIDTH{1'b0}}, m_axis_desc_dequeue_commit_op_tag_next;
reg [PORTS-1:0] m_axis_desc_dequeue_commit_valid_reg = {PORTS{1'b0}}, m_axis_desc_dequeue_commit_valid_next;

reg [DMA_ADDR_WIDTH-1:0] m_axis_dma_read_desc_dma_addr_reg = {DMA_ADDR_WIDTH{1'b0}}, m_axis_dma_read_desc_dma_addr_next;
reg [RAM_ADDR_WIDTH-1:0] m_axis_dma_read_desc_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, m_axis_dma_read_desc_ram_addr_next;
reg [DMA_LEN_WIDTH-1:0] m_axis_dma_read_desc_len_reg = {DMA_LEN_WIDTH{1'b0}}, m_axis_dma_read_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] m_axis_dma_read_desc_tag_reg = {DMA_TAG_WIDTH{1'b0}}, m_axis_dma_read_desc_tag_next;
reg m_axis_dma_read_desc_valid_reg = 1'b0, m_axis_dma_read_desc_valid_next;

reg [CL_DESC_TABLE_SIZE+1-1:0] active_count_reg = 0;
reg inc_active;
reg dec_active_1;
reg dec_active_2;

reg [DESC_TABLE_SIZE-1:0] desc_table_active = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_desc_fetched = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_desc_read_done = 0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [CL_PORTS-1:0] desc_table_sel[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [LOG_BLOCK_SIZE_WIDTH-1:0] desc_table_log_desc_block_size[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [REQ_TAG_WIDTH-1:0] desc_table_tag[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_queue_op_tag[DESC_TABLE_SIZE-1:0];

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr_reg = 0;
reg [CL_PORTS-1:0] desc_table_start_sel;
reg [LOG_BLOCK_SIZE_WIDTH-1:0] desc_table_start_log_desc_block_size;
reg [REQ_TAG_WIDTH-1:0] desc_table_start_tag;
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_start_queue_op_tag;
reg desc_table_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_desc_fetched_ptr;
reg desc_table_desc_fetched_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_desc_read_ptr_reg = 0;
reg desc_table_desc_read_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_desc_read_done_ptr;
reg desc_table_desc_read_done_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_finish_ptr_reg = 0;
reg desc_table_finish_en;

reg [RAM_ADDR_WIDTH-1:0] dma_read_desc_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, dma_read_desc_ram_addr_next;
reg [7:0] dma_read_desc_len_reg = 8'd0, dma_read_desc_len_next;
reg [CL_DESC_TABLE_SIZE-1:0] dma_read_desc_tag_reg = {CL_DESC_TABLE_SIZE{1'b0}}, dma_read_desc_tag_next;
reg [REQ_TAG_WIDTH-1:0] dma_read_desc_id_reg = {REQ_TAG_WIDTH{1'b0}}, dma_read_desc_id_next;
reg dma_read_desc_user_reg = 1'b0, dma_read_desc_user_next;
reg dma_read_desc_valid_reg = 1'b0, dma_read_desc_valid_next;
wire dma_read_desc_ready;

wire [CL_DESC_TABLE_SIZE-1:0] dma_read_desc_status_tag;
wire dma_read_desc_status_valid;

assign s_axis_req_ready = s_axis_req_ready_reg;

assign m_axis_req_status_queue = m_axis_req_status_queue_reg;
assign m_axis_req_status_ptr = m_axis_req_status_ptr_reg;
assign m_axis_req_status_cpl = m_axis_req_status_cpl_reg;
assign m_axis_req_status_tag = m_axis_req_status_tag_reg;
assign m_axis_req_status_empty = m_axis_req_status_empty_reg;
assign m_axis_req_status_error = m_axis_req_status_error_reg;
assign m_axis_req_status_valid = m_axis_req_status_valid_reg;

assign m_axis_desc_dequeue_req_queue = {PORTS{m_axis_desc_dequeue_req_queue_reg}};
assign m_axis_desc_dequeue_req_tag = {PORTS{m_axis_desc_dequeue_req_tag_reg}};
assign m_axis_desc_dequeue_req_valid = m_axis_desc_dequeue_req_valid_reg;

assign s_axis_desc_dequeue_resp_ready = s_axis_desc_dequeue_resp_ready_reg;

assign m_axis_desc_dequeue_commit_op_tag = {PORTS{m_axis_desc_dequeue_commit_op_tag_reg}};
assign m_axis_desc_dequeue_commit_valid = m_axis_desc_dequeue_commit_valid_reg;

assign m_axis_dma_read_desc_dma_addr = m_axis_dma_read_desc_dma_addr_reg;
assign m_axis_dma_read_desc_ram_addr = m_axis_dma_read_desc_ram_addr_reg;
assign m_axis_dma_read_desc_len = m_axis_dma_read_desc_len_reg;
assign m_axis_dma_read_desc_tag = m_axis_dma_read_desc_tag_reg;
assign m_axis_dma_read_desc_valid = m_axis_dma_read_desc_valid_reg;

wire [CL_PORTS-1:0] dequeue_resp_enc;
wire dequeue_resp_enc_valid;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_HIGH_PRIORITY(1)
)
op_table_start_enc_inst (
    .input_unencoded(s_axis_desc_dequeue_resp_valid & ~s_axis_desc_dequeue_resp_ready),
    .output_valid(dequeue_resp_enc_valid),
    .output_encoded(dequeue_resp_enc),
    .output_unencoded()
);

wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_ready_int;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_ready_int;

dma_psdpram #(
    .SIZE(DESC_TABLE_SIZE*DESC_SIZE*(2**((2**LOG_BLOCK_SIZE_WIDTH)-1))),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .PIPELINE(RAM_PIPELINE)
)
dma_psdpram_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .wr_cmd_be(dma_ram_wr_cmd_be),
    .wr_cmd_addr(dma_ram_wr_cmd_addr),
    .wr_cmd_data(dma_ram_wr_cmd_data),
    .wr_cmd_valid(dma_ram_wr_cmd_valid),
    .wr_cmd_ready(dma_ram_wr_cmd_ready),
    .wr_done(dma_ram_wr_done),

    /*
     * Read port
     */
    .rd_cmd_addr(dma_ram_rd_cmd_addr_int),
    .rd_cmd_valid(dma_ram_rd_cmd_valid_int),
    .rd_cmd_ready(dma_ram_rd_cmd_ready_int),
    .rd_resp_data(dma_ram_rd_resp_data_int),
    .rd_resp_valid(dma_ram_rd_resp_valid_int),
    .rd_resp_ready(dma_ram_rd_resp_ready_int)
);

dma_client_axis_source #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(1),
    .AXIS_ID_WIDTH(REQ_TAG_WIDTH),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(8),
    .TAG_WIDTH(CL_DESC_TABLE_SIZE)
)
dma_client_axis_source_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA read descriptor input
     */
    .s_axis_read_desc_ram_addr(dma_read_desc_ram_addr_reg),
    .s_axis_read_desc_len(dma_read_desc_len_reg),
    .s_axis_read_desc_tag(dma_read_desc_tag_reg),
    .s_axis_read_desc_id(dma_read_desc_id_reg),
    .s_axis_read_desc_dest(0),
    .s_axis_read_desc_user(dma_read_desc_user_reg),
    .s_axis_read_desc_valid(dma_read_desc_valid_reg),
    .s_axis_read_desc_ready(dma_read_desc_ready),

    /*
     * DMA read descriptor status output
     */
    .m_axis_read_desc_status_tag(dma_read_desc_status_tag),
    .m_axis_read_desc_status_error(),
    .m_axis_read_desc_status_valid(dma_read_desc_status_valid),

    /*
     * AXI stream read data output
     */
    .m_axis_read_data_tdata(m_axis_desc_tdata),
    .m_axis_read_data_tkeep(m_axis_desc_tkeep),
    .m_axis_read_data_tvalid(m_axis_desc_tvalid),
    .m_axis_read_data_tready(m_axis_desc_tready),
    .m_axis_read_data_tlast(m_axis_desc_tlast),
    .m_axis_read_data_tid(m_axis_desc_tid),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(m_axis_desc_tuser),

    /*
     * RAM interface
     */
    .ram_rd_cmd_addr(dma_ram_rd_cmd_addr_int),
    .ram_rd_cmd_valid(dma_ram_rd_cmd_valid_int),
    .ram_rd_cmd_ready(dma_ram_rd_cmd_ready_int),
    .ram_rd_resp_data(dma_ram_rd_resp_data_int),
    .ram_rd_resp_valid(dma_ram_rd_resp_valid_int),
    .ram_rd_resp_ready(dma_ram_rd_resp_ready_int),

    /*
     * Configuration
     */
    .enable(1'b1)
);

always @* begin
    s_axis_req_ready_next = 1'b0;

    m_axis_req_status_queue_next = m_axis_req_status_queue_reg;
    m_axis_req_status_ptr_next = m_axis_req_status_ptr_reg;
    m_axis_req_status_cpl_next = m_axis_req_status_cpl_reg;
    m_axis_req_status_tag_next = m_axis_req_status_tag_reg;
    m_axis_req_status_empty_next = m_axis_req_status_empty_reg;
    m_axis_req_status_error_next = m_axis_req_status_error_reg;
    m_axis_req_status_valid_next = 1'b0;

    m_axis_desc_dequeue_req_queue_next = m_axis_desc_dequeue_req_queue_reg;
    m_axis_desc_dequeue_req_tag_next = m_axis_desc_dequeue_req_tag_reg;
    m_axis_desc_dequeue_req_valid_next = m_axis_desc_dequeue_req_valid_reg & ~m_axis_desc_dequeue_req_ready;

    s_axis_desc_dequeue_resp_ready_next = {PORTS{1'b0}};

    m_axis_desc_dequeue_commit_op_tag_next = m_axis_desc_dequeue_commit_op_tag_reg;
    m_axis_desc_dequeue_commit_valid_next = m_axis_desc_dequeue_commit_valid_reg & ~m_axis_desc_dequeue_commit_ready;

    m_axis_dma_read_desc_dma_addr_next = m_axis_dma_read_desc_dma_addr_reg;
    m_axis_dma_read_desc_ram_addr_next = m_axis_dma_read_desc_ram_addr_reg;
    m_axis_dma_read_desc_len_next = m_axis_dma_read_desc_len_reg;
    m_axis_dma_read_desc_tag_next = m_axis_dma_read_desc_tag_reg;
    m_axis_dma_read_desc_valid_next = m_axis_dma_read_desc_valid_reg && !m_axis_dma_read_desc_ready;

    dma_read_desc_ram_addr_next = dma_read_desc_ram_addr_reg;
    dma_read_desc_len_next = dma_read_desc_len_reg;
    dma_read_desc_tag_next = dma_read_desc_tag_reg;
    dma_read_desc_id_next = dma_read_desc_id_reg;
    dma_read_desc_user_next = dma_read_desc_user_reg;
    dma_read_desc_valid_next = dma_read_desc_valid_reg && !dma_read_desc_ready;

    inc_active = 1'b0;
    dec_active_1 = 1'b0;
    dec_active_2 = 1'b0;

    desc_table_start_sel = dequeue_resp_enc;
    desc_table_start_log_desc_block_size = s_axis_desc_dequeue_resp_block_size[dequeue_resp_enc*LOG_BLOCK_SIZE_WIDTH +: LOG_BLOCK_SIZE_WIDTH];
    desc_table_start_tag = s_axis_desc_dequeue_resp_tag[dequeue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH];
    desc_table_start_queue_op_tag = s_axis_desc_dequeue_resp_op_tag[dequeue_resp_enc*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH];
    desc_table_start_en = 1'b0;
    desc_table_desc_fetched_ptr = s_axis_dma_read_desc_status_tag & DESC_PTR_MASK;
    desc_table_desc_fetched_en = 1'b0;
    desc_table_desc_read_en = 1'b0;
    desc_table_desc_read_done_ptr = dma_read_desc_status_tag & DESC_PTR_MASK;
    desc_table_desc_read_done_en = 1'b0;
    desc_table_finish_en = 1'b0;

    // queue query
    // wait for descriptor request
    s_axis_req_ready_next = enable && active_count_reg < DESC_TABLE_SIZE && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE) && (!m_axis_desc_dequeue_req_valid_reg || (m_axis_desc_dequeue_req_valid_reg & m_axis_desc_dequeue_req_ready));
    if (s_axis_req_ready && s_axis_req_valid) begin
        s_axis_req_ready_next = 1'b0;

        // initiate queue query
        m_axis_desc_dequeue_req_queue_next = s_axis_req_queue;
        m_axis_desc_dequeue_req_tag_next = s_axis_req_tag;
        m_axis_desc_dequeue_req_valid_next = 1 << s_axis_req_sel;

        inc_active = 1'b1;
    end

    // descriptor fetch
    // wait for queue query response
    if (dequeue_resp_enc_valid && !m_axis_dma_read_desc_valid_reg && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE)) begin
        s_axis_desc_dequeue_resp_ready_next = 1 << dequeue_resp_enc;

        // store in descriptor table
        desc_table_start_sel = dequeue_resp_enc;
        desc_table_start_log_desc_block_size = s_axis_desc_dequeue_resp_block_size[dequeue_resp_enc*LOG_BLOCK_SIZE_WIDTH +: LOG_BLOCK_SIZE_WIDTH];
        desc_table_start_tag = s_axis_desc_dequeue_resp_tag[dequeue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH];
        desc_table_start_queue_op_tag = s_axis_desc_dequeue_resp_op_tag[dequeue_resp_enc*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH];

        // return descriptor request completion
        m_axis_req_status_queue_next = s_axis_desc_dequeue_resp_queue[dequeue_resp_enc*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH];
        m_axis_req_status_ptr_next = s_axis_desc_dequeue_resp_ptr[dequeue_resp_enc*QUEUE_PTR_WIDTH +: QUEUE_PTR_WIDTH];
        m_axis_req_status_cpl_next = s_axis_desc_dequeue_resp_cpl[dequeue_resp_enc*CPL_QUEUE_INDEX_WIDTH +: CPL_QUEUE_INDEX_WIDTH];
        m_axis_req_status_tag_next = s_axis_desc_dequeue_resp_tag[dequeue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH];
        m_axis_req_status_empty_next = s_axis_desc_dequeue_resp_empty[dequeue_resp_enc*1 +: 1];
        m_axis_req_status_error_next = s_axis_desc_dequeue_resp_error[dequeue_resp_enc*1 +: 1];
        m_axis_req_status_valid_next = 1'b1;

        // initiate descriptor fetch
        m_axis_dma_read_desc_dma_addr_next = s_axis_desc_dequeue_resp_addr[dequeue_resp_enc*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH];
        m_axis_dma_read_desc_ram_addr_next = (desc_table_start_ptr_reg & DESC_PTR_MASK) << (CL_DESC_SIZE+(2**LOG_BLOCK_SIZE_WIDTH)-1);
        m_axis_dma_read_desc_len_next = DESC_SIZE << s_axis_desc_dequeue_resp_block_size[dequeue_resp_enc*LOG_BLOCK_SIZE_WIDTH +: LOG_BLOCK_SIZE_WIDTH];
        m_axis_dma_read_desc_tag_next = (desc_table_start_ptr_reg & DESC_PTR_MASK);

        if (s_axis_desc_dequeue_resp_error[dequeue_resp_enc*1 +: 1] || s_axis_desc_dequeue_resp_empty[dequeue_resp_enc*1 +: 1]) begin
            // queue empty or not active

            dec_active_1 = 1'b1;
        end else begin
            // descriptor available to dequeue

            // store in descriptor table
            desc_table_start_en = 1'b1;

            // initiate descriptor fetch
            m_axis_dma_read_desc_valid_next = 1'b1;
        end
    end

    // descriptor fetch completion
    // wait for descriptor fetch completion
    if (s_axis_dma_read_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_desc_fetched_ptr = s_axis_dma_read_desc_status_tag & DESC_PTR_MASK;
        desc_table_desc_fetched_en = 1'b1;
    end

    // return descriptor
    // wait for descriptor fetch completion
    // TODO descriptor validation?
    if (desc_table_active[desc_table_desc_read_ptr_reg & DESC_PTR_MASK] && desc_table_desc_read_ptr_reg != desc_table_start_ptr_reg) begin
        if (desc_table_desc_fetched[desc_table_desc_read_ptr_reg & DESC_PTR_MASK] && !(m_axis_desc_dequeue_commit_valid & 1 << desc_table_sel[desc_table_desc_read_ptr_reg & DESC_PTR_MASK]) && !dma_read_desc_valid_reg) begin
            // update entry in descriptor table
            desc_table_desc_read_en = 1'b1;

            // commit dequeue operation
            m_axis_desc_dequeue_commit_op_tag_next = desc_table_queue_op_tag[desc_table_desc_read_ptr_reg & DESC_PTR_MASK];
            m_axis_desc_dequeue_commit_valid_next = 1 << desc_table_sel[desc_table_desc_read_ptr_reg & DESC_PTR_MASK];

            // initiate descriptor read from DMA RAM
            dma_read_desc_ram_addr_next = (desc_table_desc_read_ptr_reg & DESC_PTR_MASK) << (CL_DESC_SIZE+(2**LOG_BLOCK_SIZE_WIDTH)-1);
            dma_read_desc_len_next = DESC_SIZE << desc_table_log_desc_block_size[desc_table_desc_read_ptr_reg & DESC_PTR_MASK];
            dma_read_desc_tag_next = (desc_table_desc_read_ptr_reg & DESC_PTR_MASK);
            dma_read_desc_id_next = desc_table_tag[desc_table_desc_read_ptr_reg & DESC_PTR_MASK];
            dma_read_desc_user_next = 1'b0;
            dma_read_desc_valid_next = 1'b1;
        end
    end

    // descriptor read completion
    // wait for descriptor read completion
    if (dma_read_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_desc_read_done_ptr = dma_read_desc_status_tag & DESC_PTR_MASK;
        desc_table_desc_read_done_en = 1'b1;
    end

    // finish operation
    // wait for descriptor read completion
    if (desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] && desc_table_finish_ptr_reg != desc_table_start_ptr_reg) begin
        if (desc_table_desc_read_done[desc_table_finish_ptr_reg & DESC_PTR_MASK]) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            dec_active_2 = 1'b1;
        end
    end
end

always @(posedge clk) begin
    s_axis_req_ready_reg <= s_axis_req_ready_next;

    m_axis_req_status_queue_reg <= m_axis_req_status_queue_next;
    m_axis_req_status_ptr_reg <= m_axis_req_status_ptr_next;
    m_axis_req_status_cpl_reg <= m_axis_req_status_cpl_next;
    m_axis_req_status_tag_reg <= m_axis_req_status_tag_next;
    m_axis_req_status_empty_reg <= m_axis_req_status_empty_next;
    m_axis_req_status_error_reg <= m_axis_req_status_error_next;
    m_axis_req_status_valid_reg <= m_axis_req_status_valid_next;

    m_axis_desc_dequeue_req_queue_reg <= m_axis_desc_dequeue_req_queue_next;
    m_axis_desc_dequeue_req_tag_reg <= m_axis_desc_dequeue_req_tag_next;
    m_axis_desc_dequeue_req_valid_reg <= m_axis_desc_dequeue_req_valid_next;

    s_axis_desc_dequeue_resp_ready_reg <= s_axis_desc_dequeue_resp_ready_next;

    m_axis_desc_dequeue_commit_op_tag_reg <= m_axis_desc_dequeue_commit_op_tag_next;
    m_axis_desc_dequeue_commit_valid_reg <= m_axis_desc_dequeue_commit_valid_next;

    m_axis_dma_read_desc_dma_addr_reg <= m_axis_dma_read_desc_dma_addr_next;
    m_axis_dma_read_desc_ram_addr_reg <= m_axis_dma_read_desc_ram_addr_next;
    m_axis_dma_read_desc_len_reg <= m_axis_dma_read_desc_len_next;
    m_axis_dma_read_desc_tag_reg <= m_axis_dma_read_desc_tag_next;
    m_axis_dma_read_desc_valid_reg <= m_axis_dma_read_desc_valid_next;

    dma_read_desc_ram_addr_reg <= dma_read_desc_ram_addr_next;
    dma_read_desc_len_reg <= dma_read_desc_len_next;
    dma_read_desc_tag_reg <= dma_read_desc_tag_next;
    dma_read_desc_id_reg <= dma_read_desc_id_next;
    dma_read_desc_user_reg <= dma_read_desc_user_next;
    dma_read_desc_valid_reg <= dma_read_desc_valid_next;

    active_count_reg <= active_count_reg + inc_active - dec_active_1 - dec_active_2;

    if (desc_table_start_en) begin
        desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b1;
        desc_table_desc_fetched[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_desc_read_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_sel[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_sel;
        desc_table_log_desc_block_size[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_log_desc_block_size;
        desc_table_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_tag;
        desc_table_queue_op_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_queue_op_tag;
        desc_table_start_ptr_reg <= desc_table_start_ptr_reg + 1;
    end

    if (desc_table_desc_fetched_en) begin
        desc_table_desc_fetched[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_desc_read_en) begin
        desc_table_desc_read_ptr_reg <= desc_table_desc_read_ptr_reg + 1;
    end

    if (desc_table_desc_read_done_en) begin
        desc_table_desc_read_done[desc_table_desc_read_done_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_finish_en) begin
        desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_finish_ptr_reg <= desc_table_finish_ptr_reg + 1;
    end

    if (rst) begin
        s_axis_req_ready_reg <= 1'b0;
        m_axis_req_status_valid_reg <= 1'b0;
        m_axis_desc_dequeue_req_valid_reg <= {PORTS{1'b0}};
        s_axis_desc_dequeue_resp_ready_reg <= {PORTS{1'b0}};
        m_axis_desc_dequeue_commit_valid_reg <= {PORTS{1'b0}};
        m_axis_dma_read_desc_valid_reg <= 1'b0;

        dma_read_desc_valid_reg <= 1'b0;

        active_count_reg <= 0;

        desc_table_active <= 0;
        desc_table_desc_fetched <= 0;

        desc_table_start_ptr_reg <= 0;
        desc_table_desc_read_ptr_reg <= 0;
        desc_table_finish_ptr_reg <= 0;
    end
end

endmodule

`resetall
