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
 * Completion write module
 */
module cpl_write #
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
    // Completion size (in bytes)
    parameter CPL_SIZE = 32,
    // Descriptor table size (number of in-flight operations)
    parameter DESC_TABLE_SIZE = 8
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    /*
     * Completion write request input
     */
    input  wire [SELECT_WIDTH-1:0]              s_axis_req_sel,
    input  wire [QUEUE_INDEX_WIDTH-1:0]         s_axis_req_queue,
    input  wire [REQ_TAG_WIDTH-1:0]             s_axis_req_tag,
    input  wire [CPL_SIZE*8-1:0]                s_axis_req_data,
    input  wire                                 s_axis_req_valid,
    output wire                                 s_axis_req_ready,

    /*
     * Completion write request status output
     */
    output wire [REQ_TAG_WIDTH-1:0]             m_axis_req_status_tag,
    output wire                                 m_axis_req_status_full,
    output wire                                 m_axis_req_status_error,
    output wire                                 m_axis_req_status_valid,

    /*
     * Completion enqueue request output
     */
    output wire [PORTS*QUEUE_INDEX_WIDTH-1:0]   m_axis_cpl_enqueue_req_queue,
    output wire [PORTS*REQ_TAG_WIDTH-1:0]       m_axis_cpl_enqueue_req_tag,
    output wire [PORTS-1:0]                     m_axis_cpl_enqueue_req_valid,
    input  wire [PORTS-1:0]                     m_axis_cpl_enqueue_req_ready,

    /*
     * Completion enqueue response input
     */
    input  wire [PORTS*DMA_ADDR_WIDTH-1:0]      s_axis_cpl_enqueue_resp_addr,
    input  wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0] s_axis_cpl_enqueue_resp_tag,
    input  wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]  s_axis_cpl_enqueue_resp_op_tag,
    input  wire [PORTS-1:0]                     s_axis_cpl_enqueue_resp_full,
    input  wire [PORTS-1:0]                     s_axis_cpl_enqueue_resp_error,
    input  wire [PORTS-1:0]                     s_axis_cpl_enqueue_resp_valid,
    output wire [PORTS-1:0]                     s_axis_cpl_enqueue_resp_ready,

    /*
     * Completion enqueue commit output
     */
    output wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]  m_axis_cpl_enqueue_commit_op_tag,
    output wire [PORTS-1:0]                     m_axis_cpl_enqueue_commit_valid,
    input  wire [PORTS-1:0]                     m_axis_cpl_enqueue_commit_ready,

    /*
     * DMA write descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]            m_axis_dma_write_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]            m_axis_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]             m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]             m_axis_dma_write_desc_tag,
    output wire                                 m_axis_dma_write_desc_valid,
    input  wire                                 m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]             s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                           s_axis_dma_write_desc_status_error,
    input  wire                                 s_axis_dma_write_desc_status_valid,

    /*
     * RAM interface
     */
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                 dma_ram_rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data,
    output wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                 dma_ram_rd_resp_ready,

    /*
     * Configuration
     */
    input  wire                                 enable
);

parameter CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
parameter DESC_PTR_MASK = {CL_DESC_TABLE_SIZE{1'b1}};

parameter CL_PORTS = $clog2(PORTS);

// bus width assertions
initial begin
    if (DMA_TAG_WIDTH < CL_DESC_TABLE_SIZE+1) begin
        $error("Error: DMA tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (QUEUE_REQ_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: Queue request tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end
end

reg s_axis_req_ready_reg = 1'b0, s_axis_req_ready_next;

reg [REQ_TAG_WIDTH-1:0] m_axis_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, m_axis_req_status_tag_next;
reg m_axis_req_status_full_reg = 1'b0, m_axis_req_status_full_next;
reg m_axis_req_status_error_reg = 1'b0, m_axis_req_status_error_next;
reg m_axis_req_status_valid_reg = 1'b0, m_axis_req_status_valid_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_cpl_enqueue_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_cpl_enqueue_req_queue_next;
reg [QUEUE_REQ_TAG_WIDTH-1:0] m_axis_cpl_enqueue_req_tag_reg = {QUEUE_REQ_TAG_WIDTH{1'b0}}, m_axis_cpl_enqueue_req_tag_next;
reg [PORTS-1:0] m_axis_cpl_enqueue_req_valid_reg = {PORTS{1'b0}}, m_axis_cpl_enqueue_req_valid_next;

reg [PORTS-1:0] s_axis_cpl_enqueue_resp_ready_reg = {PORTS{1'b0}}, s_axis_cpl_enqueue_resp_ready_next;

reg [QUEUE_OP_TAG_WIDTH-1:0] m_axis_cpl_enqueue_commit_op_tag_reg = {QUEUE_OP_TAG_WIDTH{1'b0}}, m_axis_cpl_enqueue_commit_op_tag_next;
reg [PORTS-1:0] m_axis_cpl_enqueue_commit_valid_reg = {PORTS{1'b0}}, m_axis_cpl_enqueue_commit_valid_next;

reg [DMA_ADDR_WIDTH-1:0] m_axis_dma_write_desc_dma_addr_reg = {DMA_ADDR_WIDTH{1'b0}}, m_axis_dma_write_desc_dma_addr_next;
reg [RAM_ADDR_WIDTH-1:0] m_axis_dma_write_desc_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, m_axis_dma_write_desc_ram_addr_next;
reg [DMA_LEN_WIDTH-1:0] m_axis_dma_write_desc_len_reg = {DMA_LEN_WIDTH{1'b0}}, m_axis_dma_write_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] m_axis_dma_write_desc_tag_reg = {DMA_TAG_WIDTH{1'b0}}, m_axis_dma_write_desc_tag_next;
reg m_axis_dma_write_desc_valid_reg = 1'b0, m_axis_dma_write_desc_valid_next;

reg [DESC_TABLE_SIZE-1:0] desc_table_active = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_invalid = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done = 0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [CL_PORTS-1:0] desc_table_sel[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [REQ_TAG_WIDTH-1:0] desc_table_tag[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_queue_op_tag[DESC_TABLE_SIZE-1:0];

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr_reg = 0;
reg [CL_PORTS-1:0] desc_table_start_sel;
reg [REQ_TAG_WIDTH-1:0] desc_table_start_tag;
reg [QUEUE_INDEX_WIDTH-1:0] desc_table_start_cpl_queue;
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_start_queue_op_tag;
reg desc_table_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_enqueue_ptr;
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_enqueue_queue_op_tag;
reg desc_table_enqueue_invalid;
reg desc_table_enqueue_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done_ptr;
reg desc_table_cpl_write_done_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_finish_ptr_reg = 0;
reg desc_table_finish_en;

reg [RAM_ADDR_WIDTH-1:0] dma_write_desc_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, dma_write_desc_ram_addr_next;
reg [7:0] dma_write_desc_len_reg = 8'd0, dma_write_desc_len_next;
reg [CL_DESC_TABLE_SIZE-1:0] dma_write_desc_tag_reg = {CL_DESC_TABLE_SIZE{1'b0}}, dma_write_desc_tag_next;
reg dma_write_desc_user_reg = 1'b0, dma_write_desc_user_next;
reg dma_write_desc_valid_reg = 1'b0, dma_write_desc_valid_next;
wire dma_write_desc_ready;

wire [CL_DESC_TABLE_SIZE-1:0] dma_write_desc_status_tag;
wire dma_write_desc_status_valid;

reg [CPL_SIZE*8-1:0] cpl_data_reg = 0, cpl_data_next;
reg cpl_data_valid_reg = 1'b0, cpl_data_valid_next;
wire cpl_data_ready;

assign s_axis_req_ready = s_axis_req_ready_reg;

assign m_axis_req_status_tag = m_axis_req_status_tag_reg;
assign m_axis_req_status_full = m_axis_req_status_full_reg;
assign m_axis_req_status_error = m_axis_req_status_error_reg;
assign m_axis_req_status_valid = m_axis_req_status_valid_reg;

assign m_axis_cpl_enqueue_req_queue = {PORTS{m_axis_cpl_enqueue_req_queue_reg}};
assign m_axis_cpl_enqueue_req_tag = {PORTS{m_axis_cpl_enqueue_req_tag_reg}};
assign m_axis_cpl_enqueue_req_valid = m_axis_cpl_enqueue_req_valid_reg;

assign s_axis_cpl_enqueue_resp_ready = s_axis_cpl_enqueue_resp_ready_reg;

assign m_axis_cpl_enqueue_commit_op_tag = {PORTS{m_axis_cpl_enqueue_commit_op_tag_reg}};
assign m_axis_cpl_enqueue_commit_valid = m_axis_cpl_enqueue_commit_valid_reg;

assign m_axis_dma_write_desc_dma_addr = m_axis_dma_write_desc_dma_addr_reg;
assign m_axis_dma_write_desc_ram_addr = m_axis_dma_write_desc_ram_addr_reg;
assign m_axis_dma_write_desc_len = m_axis_dma_write_desc_len_reg;
assign m_axis_dma_write_desc_tag = m_axis_dma_write_desc_tag_reg;
assign m_axis_dma_write_desc_valid = m_axis_dma_write_desc_valid_reg;

wire [CL_PORTS-1:0] enqueue_resp_enc;
wire enqueue_resp_enc_valid;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_HIGH_PRIORITY(1)
)
op_table_start_enc_inst (
    .input_unencoded(s_axis_cpl_enqueue_resp_valid & ~s_axis_cpl_enqueue_resp_ready),
    .output_valid(enqueue_resp_enc_valid),
    .output_encoded(enqueue_resp_enc),
    .output_unencoded()
);

wire [SEG_COUNT*SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be_int;
wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr_int;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data_int;
wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_valid_int;
wire [SEG_COUNT-1:0]                 dma_ram_wr_cmd_ready_int;
wire [SEG_COUNT-1:0]                 dma_ram_wr_done_int;

dma_psdpram #(
    .SIZE(DESC_TABLE_SIZE*SEG_COUNT*SEG_BE_WIDTH),
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
    .wr_cmd_be(dma_ram_wr_cmd_be_int),
    .wr_cmd_addr(dma_ram_wr_cmd_addr_int),
    .wr_cmd_data(dma_ram_wr_cmd_data_int),
    .wr_cmd_valid(dma_ram_wr_cmd_valid_int),
    .wr_cmd_ready(dma_ram_wr_cmd_ready_int),
    .wr_done(dma_ram_wr_done_int),

    /*
     * Read port
     */
    .rd_cmd_addr(dma_ram_rd_cmd_addr),
    .rd_cmd_valid(dma_ram_rd_cmd_valid),
    .rd_cmd_ready(dma_ram_rd_cmd_ready),
    .rd_resp_data(dma_ram_rd_resp_data),
    .rd_resp_valid(dma_ram_rd_resp_valid),
    .rd_resp_ready(dma_ram_rd_resp_ready)
);

dma_client_axis_sink #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(CPL_SIZE*8),
    .AXIS_KEEP_ENABLE(CPL_SIZE > 1),
    .AXIS_KEEP_WIDTH(CPL_SIZE),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(8),
    .TAG_WIDTH(CL_DESC_TABLE_SIZE)
)
dma_client_axis_sink_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA write descriptor input
     */
    .s_axis_write_desc_ram_addr(dma_write_desc_ram_addr_reg),
    .s_axis_write_desc_len(dma_write_desc_len_reg),
    .s_axis_write_desc_tag(dma_write_desc_tag_reg),
    .s_axis_write_desc_valid(dma_write_desc_valid_reg),
    .s_axis_write_desc_ready(dma_write_desc_ready),

    /*
     * DMA write descriptor status output
     */
    .m_axis_write_desc_status_len(),
    .m_axis_write_desc_status_tag(dma_write_desc_status_tag),
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
    .m_axis_write_desc_status_user(),
    .m_axis_write_desc_status_error(),
    .m_axis_write_desc_status_valid(dma_write_desc_status_valid),

    /*
     * AXI stream write data input
     */
    .s_axis_write_data_tdata(cpl_data_reg),
    .s_axis_write_data_tkeep({CPL_SIZE{1'b1}}),
    .s_axis_write_data_tvalid(cpl_data_valid_reg),
    .s_axis_write_data_tready(cpl_data_ready),
    .s_axis_write_data_tlast(1'b1),
    .s_axis_write_data_tid(0),
    .s_axis_write_data_tdest(0),
    .s_axis_write_data_tuser(1'b0),

    /*
     * RAM interface
     */
    .ram_wr_cmd_be(dma_ram_wr_cmd_be_int),
    .ram_wr_cmd_addr(dma_ram_wr_cmd_addr_int),
    .ram_wr_cmd_data(dma_ram_wr_cmd_data_int),
    .ram_wr_cmd_valid(dma_ram_wr_cmd_valid_int),
    .ram_wr_cmd_ready(dma_ram_wr_cmd_ready_int),
    .ram_wr_done(dma_ram_wr_done_int),

    /*
     * Configuration
     */
    .enable(1'b1),
    .abort(1'b0)
);

always @* begin
    s_axis_req_ready_next = 1'b0;

    m_axis_req_status_tag_next = m_axis_req_status_tag_reg;
    m_axis_req_status_full_next = m_axis_req_status_full_reg;
    m_axis_req_status_error_next = m_axis_req_status_error_reg;
    m_axis_req_status_valid_next = 1'b0;

    m_axis_cpl_enqueue_req_queue_next = m_axis_cpl_enqueue_req_queue_reg;
    m_axis_cpl_enqueue_req_tag_next = m_axis_cpl_enqueue_req_tag_reg;
    m_axis_cpl_enqueue_req_valid_next = m_axis_cpl_enqueue_req_valid_reg & ~m_axis_cpl_enqueue_req_ready;

    s_axis_cpl_enqueue_resp_ready_next = 1'b0;

    m_axis_cpl_enqueue_commit_op_tag_next = m_axis_cpl_enqueue_commit_op_tag_reg;
    m_axis_cpl_enqueue_commit_valid_next = m_axis_cpl_enqueue_commit_valid_reg & ~m_axis_cpl_enqueue_commit_ready;

    m_axis_dma_write_desc_dma_addr_next = m_axis_dma_write_desc_dma_addr_reg;
    m_axis_dma_write_desc_ram_addr_next = m_axis_dma_write_desc_ram_addr_reg;
    m_axis_dma_write_desc_len_next = m_axis_dma_write_desc_len_reg;
    m_axis_dma_write_desc_tag_next = m_axis_dma_write_desc_tag_reg;
    m_axis_dma_write_desc_valid_next = m_axis_dma_write_desc_valid_reg && !m_axis_dma_write_desc_ready;

    dma_write_desc_ram_addr_next = dma_write_desc_ram_addr_reg;
    dma_write_desc_len_next = dma_write_desc_len_reg;
    dma_write_desc_tag_next = dma_write_desc_tag_reg;
    dma_write_desc_user_next = dma_write_desc_user_reg;
    dma_write_desc_valid_next = dma_write_desc_valid_reg && !dma_write_desc_ready;

    cpl_data_next = cpl_data_reg;
    cpl_data_valid_next = cpl_data_valid_reg && !cpl_data_ready;

    desc_table_start_sel = s_axis_req_sel;
    desc_table_start_tag = s_axis_req_tag;
    desc_table_start_en = 1'b0;
    desc_table_enqueue_ptr = s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK;
    desc_table_enqueue_queue_op_tag = s_axis_cpl_enqueue_resp_op_tag[enqueue_resp_enc*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH];
    desc_table_enqueue_invalid = 1'b0;
    desc_table_enqueue_en = 1'b0;
    desc_table_cpl_write_done_ptr = s_axis_dma_write_desc_status_tag & DESC_PTR_MASK;
    desc_table_cpl_write_done_en = 1'b0;
    desc_table_finish_en = 1'b0;

    // queue query
    // wait for descriptor request
    s_axis_req_ready_next = enable && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE) && (!m_axis_cpl_enqueue_req_valid || (m_axis_cpl_enqueue_req_valid & m_axis_cpl_enqueue_req_ready)) && (!dma_write_desc_valid_reg) && (!cpl_data_valid_reg);
    if (s_axis_req_ready && s_axis_req_valid) begin
        s_axis_req_ready_next = 1'b0;

        // store in descriptor table
        desc_table_start_sel = s_axis_req_sel;
        desc_table_start_tag = s_axis_req_tag;
        desc_table_start_en = 1'b1;

        // initiate queue query
        m_axis_cpl_enqueue_req_queue_next = s_axis_req_queue;
        m_axis_cpl_enqueue_req_tag_next = desc_table_start_ptr_reg & DESC_PTR_MASK;
        m_axis_cpl_enqueue_req_valid_next = 1 << s_axis_req_sel;

        // initiate completion write to DMA RAM
        cpl_data_next = s_axis_req_data;
        cpl_data_valid_next = 1'b1;

        dma_write_desc_ram_addr_next = (desc_table_start_ptr_reg & DESC_PTR_MASK) << 5;
        dma_write_desc_len_next = CPL_SIZE;
        dma_write_desc_tag_next = (desc_table_start_ptr_reg & DESC_PTR_MASK);
        dma_write_desc_valid_next = 1'b1;
    end

    // finish completion write to DMA RAM
    if (dma_write_desc_status_valid) begin
        // update entry in descriptor table
        // desc_table_cpl_write_done_ptr = s_axis_dma_write_desc_status_tag & DESC_PTR_MASK;
        // desc_table_cpl_write_done_en = 1'b1;
    end

    // start completion write
    // wait for queue query response
    if (enqueue_resp_enc_valid && !m_axis_dma_write_desc_valid_reg) begin
        s_axis_cpl_enqueue_resp_ready_next = 1 << enqueue_resp_enc;

        // update entry in descriptor table
        desc_table_enqueue_ptr = s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK;
        desc_table_enqueue_queue_op_tag = s_axis_cpl_enqueue_resp_op_tag[enqueue_resp_enc*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH];
        desc_table_enqueue_invalid = 1'b0;
        desc_table_enqueue_en = 1'b1;

        // return descriptor request completion
        m_axis_req_status_tag_next = desc_table_tag[s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK];
        m_axis_req_status_full_next = s_axis_cpl_enqueue_resp_full[enqueue_resp_enc*1 +: 1];
        m_axis_req_status_error_next = s_axis_cpl_enqueue_resp_error[enqueue_resp_enc*1 +: 1];
        m_axis_req_status_valid_next = 1'b1;

        // initiate completion write
        m_axis_dma_write_desc_dma_addr_next = s_axis_cpl_enqueue_resp_addr[enqueue_resp_enc*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH];
        m_axis_dma_write_desc_ram_addr_next = (s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK) << 5;
        m_axis_dma_write_desc_len_next = CPL_SIZE;
        m_axis_dma_write_desc_tag_next = (s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK);

        if (s_axis_cpl_enqueue_resp_error[enqueue_resp_enc*1 +: 1] || s_axis_cpl_enqueue_resp_full[enqueue_resp_enc*1 +: 1]) begin
            // queue empty or not active

            // invalidate entry
            desc_table_enqueue_invalid = 1'b1;
        end else begin
            // descriptor available to enqueue

            // initiate completion write
            m_axis_dma_write_desc_valid_next = 1'b1;
        end
    end

    // finish completion write
    if (s_axis_dma_write_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_cpl_write_done_ptr = s_axis_dma_write_desc_status_tag & DESC_PTR_MASK;
        desc_table_cpl_write_done_en = 1'b1;
    end

    // operation complete
    if (desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] && desc_table_finish_ptr_reg != desc_table_start_ptr_reg) begin
        if (desc_table_invalid[desc_table_finish_ptr_reg & DESC_PTR_MASK]) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

        end else if (desc_table_cpl_write_done[desc_table_finish_ptr_reg & DESC_PTR_MASK] && !m_axis_cpl_enqueue_commit_valid) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            // commit enqueue operation
            m_axis_cpl_enqueue_commit_op_tag_next = desc_table_queue_op_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_enqueue_commit_valid_next = 1 << desc_table_sel[desc_table_finish_ptr_reg & DESC_PTR_MASK];
        end
    end
end

always @(posedge clk) begin
    s_axis_req_ready_reg <= s_axis_req_ready_next;

    m_axis_req_status_tag_reg <= m_axis_req_status_tag_next;
    m_axis_req_status_full_reg <= m_axis_req_status_full_next;
    m_axis_req_status_error_reg <= m_axis_req_status_error_next;
    m_axis_req_status_valid_reg <= m_axis_req_status_valid_next;

    m_axis_cpl_enqueue_req_queue_reg <= m_axis_cpl_enqueue_req_queue_next;
    m_axis_cpl_enqueue_req_tag_reg <= m_axis_cpl_enqueue_req_tag_next;
    m_axis_cpl_enqueue_req_valid_reg <= m_axis_cpl_enqueue_req_valid_next;

    s_axis_cpl_enqueue_resp_ready_reg <= s_axis_cpl_enqueue_resp_ready_next;

    m_axis_cpl_enqueue_commit_op_tag_reg <= m_axis_cpl_enqueue_commit_op_tag_next;
    m_axis_cpl_enqueue_commit_valid_reg <= m_axis_cpl_enqueue_commit_valid_next;

    m_axis_dma_write_desc_dma_addr_reg <= m_axis_dma_write_desc_dma_addr_next;
    m_axis_dma_write_desc_ram_addr_reg <= m_axis_dma_write_desc_ram_addr_next;
    m_axis_dma_write_desc_len_reg <= m_axis_dma_write_desc_len_next;
    m_axis_dma_write_desc_tag_reg <= m_axis_dma_write_desc_tag_next;
    m_axis_dma_write_desc_valid_reg <= m_axis_dma_write_desc_valid_next;

    dma_write_desc_ram_addr_reg <= dma_write_desc_ram_addr_next;
    dma_write_desc_len_reg <= dma_write_desc_len_next;
    dma_write_desc_tag_reg <= dma_write_desc_tag_next;
    dma_write_desc_user_reg <= dma_write_desc_user_next;
    dma_write_desc_valid_reg <= dma_write_desc_valid_next;

    cpl_data_reg <= cpl_data_next;
    cpl_data_valid_reg <= cpl_data_valid_next;

    if (desc_table_start_en) begin
        desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b1;
        desc_table_invalid[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_cpl_write_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_sel[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_sel;
        desc_table_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_tag;
        desc_table_start_ptr_reg <= desc_table_start_ptr_reg + 1;
    end

    if (desc_table_enqueue_en) begin
        desc_table_queue_op_tag[desc_table_enqueue_ptr & DESC_PTR_MASK] <= desc_table_enqueue_queue_op_tag;
        desc_table_invalid[desc_table_enqueue_ptr & DESC_PTR_MASK] <= desc_table_enqueue_invalid;
    end

    if (desc_table_cpl_write_done_en) begin
        desc_table_cpl_write_done[desc_table_cpl_write_done_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_finish_en) begin
        desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_finish_ptr_reg <= desc_table_finish_ptr_reg + 1;
    end

    if (rst) begin
        s_axis_req_ready_reg <= 1'b0;
        m_axis_req_status_valid_reg <= 1'b0;
        m_axis_cpl_enqueue_req_valid_reg <= 1'b0;
        s_axis_cpl_enqueue_resp_ready_reg <= 1'b0;
        m_axis_cpl_enqueue_commit_valid_reg <= 1'b0;
        m_axis_dma_write_desc_valid_reg <= 1'b0;

        dma_write_desc_valid_reg <= 1'b0;
        cpl_data_valid_reg <= 1'b0;

        desc_table_active <= 0;
        desc_table_invalid <= 0;

        desc_table_start_ptr_reg <= 0;
        desc_table_finish_ptr_reg <= 0;
    end
end

endmodule

`resetall
