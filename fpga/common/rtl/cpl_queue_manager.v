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
 * Completion queue manager
 */
module cpl_queue_manager #
(
    // Base address width
    parameter ADDR_WIDTH = 64,
    // Request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Number of outstanding operations
    parameter OP_TABLE_SIZE = 16,
    // Operation tag field width
    parameter OP_TAG_WIDTH = 8,
    // Queue index width (log2 of number of queues)
    parameter QUEUE_INDEX_WIDTH = 8,
    // Event index width
    parameter EVENT_WIDTH = 8,
    // Queue element pointer width (log2 of number of elements)
    parameter QUEUE_PTR_WIDTH = 16,
    // Log queue size field width
    parameter LOG_QUEUE_SIZE_WIDTH = $clog2(QUEUE_PTR_WIDTH),
    // Queue element size
    parameter CPL_SIZE = 16,
    // Pipeline stages
    parameter PIPELINE = 2,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)
)
(
    input  wire                         clk,
    input  wire                         rst,

    /*
     * Enqueue request input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0] s_axis_enqueue_req_queue,
    input  wire [REQ_TAG_WIDTH-1:0]     s_axis_enqueue_req_tag,
    input  wire                         s_axis_enqueue_req_valid,
    output wire                         s_axis_enqueue_req_ready,

    /*
     * Enqueue response output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0] m_axis_enqueue_resp_queue,
    output wire [QUEUE_PTR_WIDTH-1:0]   m_axis_enqueue_resp_ptr,
    output wire [ADDR_WIDTH-1:0]        m_axis_enqueue_resp_addr,
    output wire [EVENT_WIDTH-1:0]       m_axis_enqueue_resp_event,
    output wire [REQ_TAG_WIDTH-1:0]     m_axis_enqueue_resp_tag,
    output wire [OP_TAG_WIDTH-1:0]      m_axis_enqueue_resp_op_tag,
    output wire                         m_axis_enqueue_resp_full,
    output wire                         m_axis_enqueue_resp_error,
    output wire                         m_axis_enqueue_resp_valid,
    input  wire                         m_axis_enqueue_resp_ready,

    /*
     * Enqueue commit input
     */
    input  wire [OP_TAG_WIDTH-1:0]      s_axis_enqueue_commit_op_tag,
    input  wire                         s_axis_enqueue_commit_valid,
    output wire                         s_axis_enqueue_commit_ready,

    /*
     * Event output
     */
    output wire [EVENT_WIDTH-1:0]       m_axis_event,
    output wire [QUEUE_INDEX_WIDTH-1:0] m_axis_event_source,
    output wire                         m_axis_event_valid,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]   s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,

    /*
     * Configuration
     */
    input  wire                         enable
);

parameter QUEUE_COUNT = 2**QUEUE_INDEX_WIDTH;

parameter CL_OP_TABLE_SIZE = $clog2(OP_TABLE_SIZE);

parameter CL_CPL_SIZE = $clog2(CPL_SIZE);

parameter QUEUE_RAM_BE_WIDTH = 16;
parameter QUEUE_RAM_WIDTH = QUEUE_RAM_BE_WIDTH*8;

// bus width assertions
initial begin
    if (OP_TAG_WIDTH < CL_OP_TABLE_SIZE) begin
        $error("Error: OP_TAG_WIDTH insufficient for OP_TABLE_SIZE (instance %m)");
        $finish;
    end

    if (AXIL_DATA_WIDTH != 32) begin
        $error("Error: AXI lite interface width must be 32 (instance %m)");
        $finish;
    end

    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: AXI lite interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIL_ADDR_WIDTH < QUEUE_INDEX_WIDTH+5) begin
        $error("Error: AXI lite address width too narrow (instance %m)");
        $finish;
    end

    if (2**$clog2(CPL_SIZE) != CPL_SIZE) begin
        $error("Error: Completion size must be even power of two (instance %m)");
        $finish;
    end

    if (PIPELINE < 2) begin
        $error("Error: PIPELINE must be at least 2 (instance %m)");
        $finish;
    end
end

reg op_axil_write_pipe_hazard;
reg op_axil_read_pipe_hazard;
reg op_req_pipe_hazard;
reg op_commit_pipe_hazard;
reg stage_active;

reg [PIPELINE-1:0] op_axil_write_pipe_reg = {PIPELINE{1'b0}}, op_axil_write_pipe_next;
reg [PIPELINE-1:0] op_axil_read_pipe_reg = {PIPELINE{1'b0}}, op_axil_read_pipe_next;
reg [PIPELINE-1:0] op_req_pipe_reg = {PIPELINE{1'b0}}, op_req_pipe_next;
reg [PIPELINE-1:0] op_commit_pipe_reg = {PIPELINE{1'b0}}, op_commit_pipe_next;

reg [QUEUE_INDEX_WIDTH-1:0] queue_ram_addr_pipeline_reg[PIPELINE-1:0], queue_ram_addr_pipeline_next[PIPELINE-1:0];
reg [2:0] axil_reg_pipeline_reg[PIPELINE-1:0], axil_reg_pipeline_next[PIPELINE-1:0];
reg [AXIL_DATA_WIDTH-1:0] write_data_pipeline_reg[PIPELINE-1:0], write_data_pipeline_next[PIPELINE-1:0];
reg [AXIL_STRB_WIDTH-1:0] write_strobe_pipeline_reg[PIPELINE-1:0], write_strobe_pipeline_next[PIPELINE-1:0];
reg [REQ_TAG_WIDTH-1:0] req_tag_pipeline_reg[PIPELINE-1:0], req_tag_pipeline_next[PIPELINE-1:0];

reg s_axis_enqueue_req_ready_reg = 1'b0, s_axis_enqueue_req_ready_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_enqueue_resp_queue_reg = 0, m_axis_enqueue_resp_queue_next;
reg [QUEUE_PTR_WIDTH-1:0] m_axis_enqueue_resp_ptr_reg = 0, m_axis_enqueue_resp_ptr_next;
reg [ADDR_WIDTH-1:0] m_axis_enqueue_resp_addr_reg = 0, m_axis_enqueue_resp_addr_next;
reg [EVENT_WIDTH-1:0] m_axis_enqueue_resp_event_reg = 0, m_axis_enqueue_resp_event_next;
reg [REQ_TAG_WIDTH-1:0] m_axis_enqueue_resp_tag_reg = 0, m_axis_enqueue_resp_tag_next;
reg [OP_TAG_WIDTH-1:0] m_axis_enqueue_resp_op_tag_reg = 0, m_axis_enqueue_resp_op_tag_next;
reg m_axis_enqueue_resp_full_reg = 1'b0, m_axis_enqueue_resp_full_next;
reg m_axis_enqueue_resp_error_reg = 1'b0, m_axis_enqueue_resp_error_next;
reg m_axis_enqueue_resp_valid_reg = 1'b0, m_axis_enqueue_resp_valid_next;

reg s_axis_enqueue_commit_ready_reg = 1'b0, s_axis_enqueue_commit_ready_next;

reg [EVENT_WIDTH-1:0] m_axis_event_reg = 0, m_axis_event_next;
reg [QUEUE_INDEX_WIDTH-1:0] m_axis_event_source_reg = 0, m_axis_event_source_next;
reg m_axis_event_valid_reg = 1'b0, m_axis_event_valid_next;

reg s_axil_awready_reg = 0, s_axil_awready_next;
reg s_axil_wready_reg = 0, s_axil_wready_next;
reg s_axil_bvalid_reg = 0, s_axil_bvalid_next;
reg s_axil_arready_reg = 0, s_axil_arready_next;
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_reg = 0, s_axil_rdata_next;
reg s_axil_rvalid_reg = 0, s_axil_rvalid_next;

(* ramstyle = "no_rw_check" *)
reg [QUEUE_RAM_WIDTH-1:0] queue_ram[QUEUE_COUNT-1:0];
reg [QUEUE_INDEX_WIDTH-1:0] queue_ram_read_ptr;
reg [QUEUE_INDEX_WIDTH-1:0] queue_ram_write_ptr;
reg [QUEUE_RAM_WIDTH-1:0] queue_ram_write_data;
reg queue_ram_wr_en;
reg [QUEUE_RAM_BE_WIDTH-1:0] queue_ram_be;
reg [QUEUE_RAM_WIDTH-1:0] queue_ram_read_data_reg = 0;
reg [QUEUE_RAM_WIDTH-1:0] queue_ram_read_data_pipeline_reg[PIPELINE-1:1];

wire [QUEUE_PTR_WIDTH-1:0] queue_ram_read_data_head_ptr = queue_ram_read_data_pipeline_reg[PIPELINE-1][15:0];
wire [QUEUE_PTR_WIDTH-1:0] queue_ram_read_data_tail_ptr = queue_ram_read_data_pipeline_reg[PIPELINE-1][31:16];
wire [EVENT_WIDTH-1:0] queue_ram_read_data_event = queue_ram_read_data_pipeline_reg[PIPELINE-1][47:32];
wire [LOG_QUEUE_SIZE_WIDTH-1:0] queue_ram_read_data_log_size = queue_ram_read_data_pipeline_reg[PIPELINE-1][51:48];
wire queue_ram_read_data_continuous = queue_ram_read_data_pipeline_reg[PIPELINE-1][53];
wire queue_ram_read_data_armed = queue_ram_read_data_pipeline_reg[PIPELINE-1][54];
wire queue_ram_read_data_active = queue_ram_read_data_pipeline_reg[PIPELINE-1][55];
wire [CL_OP_TABLE_SIZE-1:0] queue_ram_read_data_op_index = queue_ram_read_data_pipeline_reg[PIPELINE-1][63:56];
wire [ADDR_WIDTH-1:0] queue_ram_read_data_base_addr = queue_ram_read_data_pipeline_reg[PIPELINE-1][127:64];

reg [OP_TABLE_SIZE-1:0] op_table_active = 0;
reg [OP_TABLE_SIZE-1:0] op_table_commit = 0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [QUEUE_INDEX_WIDTH-1:0] op_table_queue[OP_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [QUEUE_PTR_WIDTH-1:0] op_table_queue_ptr[OP_TABLE_SIZE-1:0];
reg [CL_OP_TABLE_SIZE-1:0] op_table_start_ptr_reg = 0;
reg [QUEUE_INDEX_WIDTH-1:0] op_table_start_queue;
reg [QUEUE_PTR_WIDTH-1:0] op_table_start_queue_ptr;
reg op_table_start_en;
reg [CL_OP_TABLE_SIZE-1:0] op_table_commit_ptr;
reg op_table_commit_en;
reg [CL_OP_TABLE_SIZE-1:0] op_table_finish_ptr_reg = 0;
reg op_table_finish_en;

assign s_axis_enqueue_req_ready = s_axis_enqueue_req_ready_reg;

assign m_axis_enqueue_resp_queue = m_axis_enqueue_resp_queue_reg;
assign m_axis_enqueue_resp_ptr = m_axis_enqueue_resp_ptr_reg;
assign m_axis_enqueue_resp_addr = m_axis_enqueue_resp_addr_reg;
assign m_axis_enqueue_resp_event = m_axis_enqueue_resp_event_reg;
assign m_axis_enqueue_resp_tag = m_axis_enqueue_resp_tag_reg;
assign m_axis_enqueue_resp_op_tag = m_axis_enqueue_resp_op_tag_reg;
assign m_axis_enqueue_resp_full = m_axis_enqueue_resp_full_reg;
assign m_axis_enqueue_resp_error = m_axis_enqueue_resp_error_reg;
assign m_axis_enqueue_resp_valid = m_axis_enqueue_resp_valid_reg;

assign s_axis_enqueue_commit_ready = s_axis_enqueue_commit_ready_reg;

assign m_axis_event = m_axis_event_reg;
assign m_axis_event_source = m_axis_event_source_reg;
assign m_axis_event_valid = m_axis_event_valid_reg;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

wire [QUEUE_INDEX_WIDTH-1:0] s_axil_awaddr_queue = s_axil_awaddr >> 5;
wire [2:0] s_axil_awaddr_reg = s_axil_awaddr >> 2;
wire [QUEUE_INDEX_WIDTH-1:0] s_axil_araddr_queue = s_axil_araddr >> 5;
wire [2:0] s_axil_araddr_reg = s_axil_araddr >> 2;

wire queue_active = op_table_active[queue_ram_read_data_op_index] && op_table_queue[queue_ram_read_data_op_index] == queue_ram_addr_pipeline_reg[PIPELINE-1];
wire queue_full_idle = ($unsigned(queue_ram_read_data_head_ptr - queue_ram_read_data_tail_ptr) & ({QUEUE_PTR_WIDTH{1'b1}} << queue_ram_read_data_log_size)) != 0;
wire queue_full_active = ($unsigned(op_table_queue_ptr[queue_ram_read_data_op_index] - queue_ram_read_data_tail_ptr) & ({QUEUE_PTR_WIDTH{1'b1}} << queue_ram_read_data_log_size)) != 0;
wire queue_full = queue_active ? queue_full_active : queue_full_idle;
wire [QUEUE_PTR_WIDTH-1:0] queue_ram_read_active_head_ptr = queue_active ? op_table_queue_ptr[queue_ram_read_data_op_index] : queue_ram_read_data_head_ptr;

integer i, j;

initial begin
    // break up loop to work around iteration termination
    for (i = 0; i < QUEUE_INDEX_WIDTH; i = i + 2**(QUEUE_INDEX_WIDTH/2)) begin
        for (j = i; j < i + 2**(QUEUE_INDEX_WIDTH/2); j = j + 1) begin
            queue_ram[j] = 0;
        end
    end

    for (i = 0; i < PIPELINE; i = i + 1) begin
        queue_ram_addr_pipeline_reg[i] = 0;
        axil_reg_pipeline_reg[i] = 0;
        write_data_pipeline_reg[i] = 0;
        write_strobe_pipeline_reg[i] = 0;
        req_tag_pipeline_reg[i] = 0;
    end

    for (i = 0; i < OP_TABLE_SIZE; i = i + 1) begin
        op_table_queue[i] = 0;
        op_table_queue_ptr[i] = 0;
    end
end

always @* begin
    op_axil_write_pipe_next = {op_axil_write_pipe_reg, 1'b0};
    op_axil_read_pipe_next = {op_axil_read_pipe_reg, 1'b0};
    op_req_pipe_next = {op_req_pipe_reg, 1'b0};
    op_commit_pipe_next = {op_commit_pipe_reg, 1'b0};

    queue_ram_addr_pipeline_next[0] = 0;
    axil_reg_pipeline_next[0] = 0;
    write_data_pipeline_next[0] = 0;
    write_strobe_pipeline_next[0] = 0;
    req_tag_pipeline_next[0] = 0;
    for (j = 1; j < PIPELINE; j = j + 1) begin
        queue_ram_addr_pipeline_next[j] = queue_ram_addr_pipeline_reg[j-1];
        axil_reg_pipeline_next[j] = axil_reg_pipeline_reg[j-1];
        write_data_pipeline_next[j] = write_data_pipeline_reg[j-1];
        write_strobe_pipeline_next[j] = write_strobe_pipeline_reg[j-1];
        req_tag_pipeline_next[j] = req_tag_pipeline_reg[j-1];
    end

    s_axis_enqueue_req_ready_next = 1'b0;

    m_axis_enqueue_resp_queue_next = m_axis_enqueue_resp_queue_reg;
    m_axis_enqueue_resp_ptr_next = m_axis_enqueue_resp_ptr_reg;
    m_axis_enqueue_resp_addr_next = m_axis_enqueue_resp_addr_reg;
    m_axis_enqueue_resp_event_next = m_axis_enqueue_resp_event_reg;
    m_axis_enqueue_resp_tag_next = m_axis_enqueue_resp_tag_reg;
    m_axis_enqueue_resp_op_tag_next = m_axis_enqueue_resp_op_tag_reg;
    m_axis_enqueue_resp_full_next = m_axis_enqueue_resp_full_reg;
    m_axis_enqueue_resp_error_next = m_axis_enqueue_resp_error_reg;
    m_axis_enqueue_resp_valid_next = m_axis_enqueue_resp_valid_reg && !m_axis_enqueue_resp_ready;

    s_axis_enqueue_commit_ready_next = 1'b0;

    m_axis_event_next = m_axis_event_reg;
    m_axis_event_source_next = m_axis_event_source_reg;
    m_axis_event_valid_next = 1'b0;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;

    queue_ram_read_ptr = 0;
    queue_ram_write_ptr = queue_ram_addr_pipeline_reg[PIPELINE-1];
    queue_ram_write_data = queue_ram_read_data_pipeline_reg[PIPELINE-1];
    queue_ram_wr_en = 0;
    queue_ram_be = 0;

    op_table_start_queue = queue_ram_addr_pipeline_reg[PIPELINE-1];
    op_table_start_queue_ptr = queue_ram_read_active_head_ptr + 1;
    op_table_start_en = 1'b0;
    op_table_commit_ptr = s_axis_enqueue_commit_op_tag;
    op_table_commit_en = 1'b0;
    op_table_finish_en = 1'b0;

    op_axil_write_pipe_hazard = 1'b0;
    op_axil_read_pipe_hazard = 1'b0;
    op_req_pipe_hazard = 1'b0;
    op_commit_pipe_hazard = 1'b0;
    stage_active = 1'b0;

    for (j = 0; j < PIPELINE; j = j + 1) begin
        stage_active = op_axil_write_pipe_reg[j] || op_axil_read_pipe_reg[j] || op_req_pipe_reg[j] || op_commit_pipe_reg[j];
        op_axil_write_pipe_hazard = op_axil_write_pipe_hazard || (stage_active && queue_ram_addr_pipeline_reg[j] == s_axil_awaddr_queue);
        op_axil_read_pipe_hazard = op_axil_read_pipe_hazard || (stage_active && queue_ram_addr_pipeline_reg[j] == s_axil_araddr_queue);
        op_req_pipe_hazard = op_req_pipe_hazard || (stage_active && queue_ram_addr_pipeline_reg[j] == s_axis_enqueue_req_queue);
        op_commit_pipe_hazard = op_commit_pipe_hazard || (stage_active && queue_ram_addr_pipeline_reg[j] == op_table_queue[op_table_finish_ptr_reg]);
    end

    // pipeline stage 0 - receive request
    if (s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && !op_axil_write_pipe_reg && !op_axil_write_pipe_hazard) begin
        // AXIL write
        op_axil_write_pipe_next[0] = 1'b1;

        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;

        write_data_pipeline_next[0] = s_axil_wdata;
        write_strobe_pipeline_next[0] = s_axil_wstrb;

        queue_ram_read_ptr = s_axil_awaddr_queue;
        queue_ram_addr_pipeline_next[0] = s_axil_awaddr_queue;
        axil_reg_pipeline_next[0] = s_axil_awaddr_reg;
    end else if (s_axil_arvalid && (!s_axil_rvalid || s_axil_rready) && !op_axil_read_pipe_reg && !op_axil_read_pipe_hazard) begin
        // AXIL read
        op_axil_read_pipe_next[0] = 1'b1;

        s_axil_arready_next = 1'b1;

        queue_ram_read_ptr = s_axil_araddr_queue;
        queue_ram_addr_pipeline_next[0] = s_axil_araddr_queue;
        axil_reg_pipeline_next[0] = s_axil_araddr_reg;
    end else if (op_table_active[op_table_finish_ptr_reg] && op_table_commit[op_table_finish_ptr_reg] && !op_commit_pipe_reg[0] && !op_commit_pipe_hazard) begin
        // enqueue commit finalize (update pointer)
        op_commit_pipe_next[0] = 1'b1;

        op_table_finish_en = 1'b1;

        write_data_pipeline_next[0] = op_table_queue_ptr[op_table_finish_ptr_reg];

        queue_ram_read_ptr = op_table_queue[op_table_finish_ptr_reg];
        queue_ram_addr_pipeline_next[0] = op_table_queue[op_table_finish_ptr_reg];
    end else if (enable && !op_table_active[op_table_start_ptr_reg] && s_axis_enqueue_req_valid && (!m_axis_enqueue_resp_valid || m_axis_enqueue_resp_ready) && !op_req_pipe_reg && !op_req_pipe_hazard) begin
        // enqueue request
        op_req_pipe_next[0] = 1'b1;

        s_axis_enqueue_req_ready_next = 1'b1;

        req_tag_pipeline_next[0] = s_axis_enqueue_req_tag;

        queue_ram_read_ptr = s_axis_enqueue_req_queue;
        queue_ram_addr_pipeline_next[0] = s_axis_enqueue_req_queue;
    end

    // read complete, perform operation
    if (op_req_pipe_reg[PIPELINE-1]) begin
        // request
        m_axis_enqueue_resp_queue_next = queue_ram_addr_pipeline_reg[PIPELINE-1];
        m_axis_enqueue_resp_ptr_next = queue_ram_read_active_head_ptr;
        m_axis_enqueue_resp_addr_next = queue_ram_read_data_base_addr + ((queue_ram_read_active_head_ptr & ({QUEUE_PTR_WIDTH{1'b1}} >> (QUEUE_PTR_WIDTH - queue_ram_read_data_log_size))) * CPL_SIZE);
        m_axis_enqueue_resp_event_next = queue_ram_read_data_event;
        m_axis_enqueue_resp_tag_next = req_tag_pipeline_reg[PIPELINE-1];
        m_axis_enqueue_resp_op_tag_next = op_table_start_ptr_reg;
        m_axis_enqueue_resp_full_next = 1'b0;
        m_axis_enqueue_resp_error_next = 1'b0;

        queue_ram_write_ptr = queue_ram_addr_pipeline_reg[PIPELINE-1];
        queue_ram_write_data[63:56] = op_table_start_ptr_reg;
        queue_ram_wr_en = 1'b1;

        op_table_start_queue = queue_ram_addr_pipeline_reg[PIPELINE-1];
        op_table_start_queue_ptr = queue_ram_read_active_head_ptr + 1;

        if (!queue_ram_read_data_active) begin
            // queue inactive
            m_axis_enqueue_resp_error_next = 1'b1;
            m_axis_enqueue_resp_valid_next = 1'b1;
        end else if (queue_full) begin
            // queue full
            m_axis_enqueue_resp_full_next = 1'b1;
            m_axis_enqueue_resp_valid_next = 1'b1;
        end else begin
            // start enqueue
            m_axis_enqueue_resp_valid_next = 1'b1;

            queue_ram_be[7] = 1'b1;

            op_table_start_en = 1'b1;
        end
    end else if (op_commit_pipe_reg[PIPELINE-1]) begin
        // commit

        // update head pointer
        queue_ram_write_ptr = queue_ram_addr_pipeline_reg[PIPELINE-1];
        queue_ram_write_data[15:0] = write_data_pipeline_reg[PIPELINE-1];
        queue_ram_be[1:0] = 2'b11;
        queue_ram_wr_en = 1'b1;

        queue_ram_write_data[55:48] = queue_ram_read_data_pipeline_reg[PIPELINE-1][55:48];
        // generate event on head pointer update
        if (queue_ram_read_data_armed) begin
            m_axis_event_next = queue_ram_read_data_event;
            m_axis_event_source_next = queue_ram_addr_pipeline_reg[PIPELINE-1];
            m_axis_event_valid_next = 1'b1;

            if (!queue_ram_read_data_continuous) begin
                queue_ram_write_data[54] = 1'b0;
                queue_ram_be[6] = 1'b1;
            end
        end
    end else if (op_axil_write_pipe_reg[PIPELINE-1]) begin
        // AXIL write
        s_axil_bvalid_next = 1'b1;

        queue_ram_write_data = queue_ram_read_data_pipeline_reg[PIPELINE-1];
        queue_ram_write_ptr = queue_ram_addr_pipeline_reg[PIPELINE-1];
        queue_ram_wr_en = 1'b1;

        // TODO parametrize
        case (axil_reg_pipeline_reg[PIPELINE-1])
            3'd0: begin
                // base address lower 32
                // base address is read-only when queue is active
                if (!queue_ram_read_data_active) begin
                    queue_ram_write_data[95:64] = write_data_pipeline_reg[PIPELINE-1];
                    queue_ram_be[11:8] = write_strobe_pipeline_reg[PIPELINE-1];
                end
            end
            3'd1: begin
                // base address upper 32
                // base address is read-only when queue is active
                if (!queue_ram_read_data_active) begin
                    queue_ram_write_data[127:96] = write_data_pipeline_reg[PIPELINE-1];
                    queue_ram_be[15:12] = write_strobe_pipeline_reg[PIPELINE-1];
                end
            end
            3'd2: begin
                queue_ram_write_data[55:48] = queue_ram_read_data_pipeline_reg[PIPELINE-1][55:48];
                // log size
                // log size is read-only when queue is active
                if (!queue_ram_read_data_active) begin
                    if (write_strobe_pipeline_reg[PIPELINE-1][0]) begin
                        queue_ram_write_data[51:48] = write_data_pipeline_reg[PIPELINE-1][3:0];
                        queue_ram_be[6] = 1'b1;
                    end
                end
                // active
                if (write_strobe_pipeline_reg[PIPELINE-1][3]) begin
                    queue_ram_write_data[55] = write_data_pipeline_reg[PIPELINE-1][31];
                    queue_ram_be[6] = 1'b1;
                end
            end
            3'd3: begin
                // event index
                // event index is read-only when queue is active
                if (!queue_ram_read_data_active) begin
                    queue_ram_write_data[47:32] = write_data_pipeline_reg[PIPELINE-1];
                    queue_ram_be[5:4] = write_strobe_pipeline_reg[PIPELINE-1];
                end

                queue_ram_write_data[55:48] = queue_ram_read_data_pipeline_reg[PIPELINE-1][55:48];
                // continuous
                if (write_strobe_pipeline_reg[PIPELINE-1][3]) begin
                    queue_ram_write_data[53] = write_data_pipeline_reg[PIPELINE-1][30];
                    queue_ram_be[6] = 1'b1;
                end
                // armed
                if (write_strobe_pipeline_reg[PIPELINE-1][3]) begin
                    queue_ram_write_data[54] = write_data_pipeline_reg[PIPELINE-1][31];
                    queue_ram_be[6] = 1'b1;

                    if (write_data_pipeline_reg[PIPELINE-1][31] && (queue_ram_read_data_head_ptr != queue_ram_read_data_tail_ptr)) begin
                        // armed and queue not empty
                        // so generate event
                        m_axis_event_next = queue_ram_read_data_event;
                        m_axis_event_source_next = queue_ram_addr_pipeline_reg[PIPELINE-1];
                        m_axis_event_valid_next = 1'b1;

                        if (!write_data_pipeline_reg[PIPELINE-1][30]) begin
                            queue_ram_write_data[54] = 1'b0;
                            queue_ram_be[6] = 1'b1;
                        end
                    end
                end
            end
            3'd4: begin
                // head pointer
                // tail pointer is read-only when queue is active
                if (!queue_ram_read_data_active) begin
                    queue_ram_write_data[15:0] = write_data_pipeline_reg[PIPELINE-1];
                    queue_ram_be[1:0] = write_strobe_pipeline_reg[PIPELINE-1];
                end
            end
            3'd6: begin
                // tail pointer
                queue_ram_write_data[31:16] = write_data_pipeline_reg[PIPELINE-1];
                queue_ram_be[3:2] = write_strobe_pipeline_reg[PIPELINE-1];
            end
        endcase
    end else if (op_axil_read_pipe_reg[PIPELINE-1]) begin
        // AXIL read
        s_axil_rvalid_next = 1'b1;
        s_axil_rdata_next = 0;

        // TODO parametrize
        case (axil_reg_pipeline_reg[PIPELINE-1])
            3'd0: begin
                // base address lower 32
                s_axil_rdata_next = queue_ram_read_data_base_addr[31:0];
            end
            3'd1: begin
                // base address upper 32
                s_axil_rdata_next = queue_ram_read_data_base_addr[63:32];
            end
            3'd2: begin
                // log size
                s_axil_rdata_next[3:0] = queue_ram_read_data_log_size;
                // active
                s_axil_rdata_next[31] = queue_ram_read_data_active;
            end
            3'd3: begin
                // event index
                s_axil_rdata_next[29:0] = queue_ram_read_data_event;
                s_axil_rdata_next[30] = queue_ram_read_data_continuous;
                s_axil_rdata_next[31] = queue_ram_read_data_armed;
            end
            3'd4: begin
                // head pointer
                s_axil_rdata_next = queue_ram_read_data_head_ptr;
            end
            3'd6: begin
                // tail pointer
                s_axil_rdata_next = queue_ram_read_data_tail_ptr;
            end
        endcase
    end

    // enqueue commit (record in table)
    s_axis_enqueue_commit_ready_next = enable;
    if (s_axis_enqueue_commit_ready && s_axis_enqueue_commit_valid) begin
        op_table_commit_ptr = s_axis_enqueue_commit_op_tag;
        op_table_commit_en = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        op_axil_write_pipe_reg <= {PIPELINE{1'b0}};
        op_axil_read_pipe_reg <= {PIPELINE{1'b0}};
        op_req_pipe_reg <= {PIPELINE{1'b0}};
        op_commit_pipe_reg <= {PIPELINE{1'b0}};

        s_axis_enqueue_req_ready_reg <= 1'b0;
        m_axis_enqueue_resp_valid_reg <= 1'b0;
        s_axis_enqueue_commit_ready_reg <= 1'b0;
        m_axis_event_valid_reg <= 1'b0;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        op_table_active <= 0;

        op_table_start_ptr_reg <= 0;
        op_table_finish_ptr_reg <= 0;
    end else begin
        op_axil_write_pipe_reg <= op_axil_write_pipe_next;
        op_axil_read_pipe_reg <= op_axil_read_pipe_next;
        op_req_pipe_reg <= op_req_pipe_next;
        op_commit_pipe_reg <= op_commit_pipe_next;

        s_axis_enqueue_req_ready_reg <= s_axis_enqueue_req_ready_next;
        m_axis_enqueue_resp_valid_reg <= m_axis_enqueue_resp_valid_next;
        s_axis_enqueue_commit_ready_reg <= s_axis_enqueue_commit_ready_next;
        m_axis_event_valid_reg <= m_axis_event_valid_next;

        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;
        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;

        if (op_table_start_en) begin
            op_table_start_ptr_reg <= op_table_start_ptr_reg + 1;
            op_table_active[op_table_start_ptr_reg] <= 1'b1;
        end
        if (op_table_finish_en) begin
            op_table_finish_ptr_reg <= op_table_finish_ptr_reg + 1;
            op_table_active[op_table_finish_ptr_reg] <= 1'b0;
        end
    end

    for (i = 0; i < PIPELINE; i = i + 1) begin
        queue_ram_addr_pipeline_reg[i] <= queue_ram_addr_pipeline_next[i];
        axil_reg_pipeline_reg[i] <= axil_reg_pipeline_next[i];
        write_data_pipeline_reg[i] <= write_data_pipeline_next[i];
        write_strobe_pipeline_reg[i] <= write_strobe_pipeline_next[i];
        req_tag_pipeline_reg[i] <= req_tag_pipeline_next[i];
    end

    m_axis_enqueue_resp_queue_reg <= m_axis_enqueue_resp_queue_next;
    m_axis_enqueue_resp_ptr_reg <= m_axis_enqueue_resp_ptr_next;
    m_axis_enqueue_resp_addr_reg <= m_axis_enqueue_resp_addr_next;
    m_axis_enqueue_resp_event_reg <= m_axis_enqueue_resp_event_next;
    m_axis_enqueue_resp_tag_reg <= m_axis_enqueue_resp_tag_next;
    m_axis_enqueue_resp_op_tag_reg <= m_axis_enqueue_resp_op_tag_next;
    m_axis_enqueue_resp_full_reg <= m_axis_enqueue_resp_full_next;
    m_axis_enqueue_resp_error_reg <= m_axis_enqueue_resp_error_next;
    m_axis_event_reg <= m_axis_event_next;
    m_axis_event_source_reg <= m_axis_event_source_next;

    s_axil_rdata_reg <= s_axil_rdata_next;

    if (queue_ram_wr_en) begin
        for (i = 0; i < QUEUE_RAM_BE_WIDTH; i = i + 1) begin
            if (queue_ram_be[i]) begin
                queue_ram[queue_ram_write_ptr][i*8 +: 8] <= queue_ram_write_data[i*8 +: 8];
            end
        end
    end
    queue_ram_read_data_reg <= queue_ram[queue_ram_read_ptr];
    queue_ram_read_data_pipeline_reg[1] <= queue_ram_read_data_reg;
    for (i = 2; i < PIPELINE; i = i + 1) begin
        queue_ram_read_data_pipeline_reg[i] <= queue_ram_read_data_pipeline_reg[i-1];
    end

    if (op_table_start_en) begin
        op_table_commit[op_table_start_ptr_reg] <= 1'b0;
        op_table_queue[op_table_start_ptr_reg] <= op_table_start_queue;
        op_table_queue_ptr[op_table_start_ptr_reg] <= op_table_start_queue_ptr;
    end
    if (op_table_commit_en) begin
        op_table_commit[op_table_commit_ptr] <= 1'b1;
    end
end

endmodule

`resetall
