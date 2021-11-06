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
 * Transmit engine
 */
module tx_engine #
(
    // DMA RAM address width
    parameter RAM_ADDR_WIDTH = 16,
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA length field width
    parameter DMA_LEN_WIDTH = 20,
    // DMA client length field width
    parameter DMA_CLIENT_LEN_WIDTH = 20,
    // Transmit request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Descriptor request tag field width
    parameter DESC_REQ_TAG_WIDTH = 8,
    // DMA tag field width
    parameter DMA_TAG_WIDTH = 8,
    // DMA client tag field width
    parameter DMA_CLIENT_TAG_WIDTH = 8,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 4,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Completion queue index width
    parameter CPL_QUEUE_INDEX_WIDTH = 4,
    // Descriptor table size (number of in-flight operations)
    parameter DESC_TABLE_SIZE = 8,
    // Width of descriptor table field for tracking outstanding DMA operations
    parameter DESC_TABLE_DMA_OP_COUNT_WIDTH = 4,
    // Max transmit packet size
    parameter MAX_TX_SIZE = 2048,
    // Transmit buffer offset
    parameter TX_BUFFER_OFFSET = 0,
    // Transmit buffer size
    parameter TX_BUFFER_SIZE = 16*MAX_TX_SIZE,
    // Transmit buffer step size
    parameter TX_BUFFER_STEP_SIZE = 128,
    // Descriptor size (in bytes)
    parameter DESC_SIZE = 16,
    // Descriptor size (in bytes)
    parameter CPL_SIZE = 32,
    // Max number of in-flight descriptor requests
    parameter MAX_DESC_REQ = 16,
    // Width of AXI stream descriptor interfaces in bits
    parameter AXIS_DESC_DATA_WIDTH = DESC_SIZE*8,
    // AXI stream descriptor tkeep signal width (words per cycle)
    parameter AXIS_DESC_KEEP_WIDTH = AXIS_DESC_DATA_WIDTH/8,
    // Enable PTP timestamping
    parameter PTP_TS_ENABLE = 1,
    // Enable TX checksum offload
    parameter TX_CHECKSUM_ENABLE = 1
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * Transmit request input (queue index)
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]     s_axis_tx_req_queue,
    input  wire [REQ_TAG_WIDTH-1:0]         s_axis_tx_req_tag,
    input  wire                             s_axis_tx_req_valid,
    output wire                             s_axis_tx_req_ready,

    /*
     * Transmit request status output
     */
    output wire [DMA_CLIENT_LEN_WIDTH-1:0]  m_axis_tx_req_status_len,
    output wire [REQ_TAG_WIDTH-1:0]         m_axis_tx_req_status_tag,
    output wire                             m_axis_tx_req_status_valid,

    /*
     * Descriptor request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]     m_axis_desc_req_queue,
    output wire [DESC_REQ_TAG_WIDTH-1:0]    m_axis_desc_req_tag,
    output wire                             m_axis_desc_req_valid,
    input  wire                             m_axis_desc_req_ready,

    /*
     * Descriptor request status input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]     s_axis_desc_req_status_queue,
    input  wire [QUEUE_PTR_WIDTH-1:0]       s_axis_desc_req_status_ptr,
    input  wire [CPL_QUEUE_INDEX_WIDTH-1:0] s_axis_desc_req_status_cpl,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]    s_axis_desc_req_status_tag,
    input  wire                             s_axis_desc_req_status_empty,
    input  wire                             s_axis_desc_req_status_error,
    input  wire                             s_axis_desc_req_status_valid,

    /*
     * Descriptor data input
     */
    input  wire [AXIS_DESC_DATA_WIDTH-1:0]  s_axis_desc_tdata,
    input  wire [AXIS_DESC_KEEP_WIDTH-1:0]  s_axis_desc_tkeep,
    input  wire                             s_axis_desc_tvalid,
    output wire                             s_axis_desc_tready,
    input  wire                             s_axis_desc_tlast,
    input  wire [DESC_REQ_TAG_WIDTH-1:0]    s_axis_desc_tid,
    input  wire                             s_axis_desc_tuser,

    /*
     * Completion request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]     m_axis_cpl_req_queue,
    output wire [DESC_REQ_TAG_WIDTH-1:0]    m_axis_cpl_req_tag,
    output wire [CPL_SIZE*8-1:0]            m_axis_cpl_req_data,
    output wire                             m_axis_cpl_req_valid,
    input  wire                             m_axis_cpl_req_ready,

    /*
     * Completion request status input
     */
    input  wire [DESC_REQ_TAG_WIDTH-1:0]    s_axis_cpl_req_status_tag,
    input  wire                             s_axis_cpl_req_status_full,
    input  wire                             s_axis_cpl_req_status_error,
    input  wire                             s_axis_cpl_req_status_valid,

    /*
     * DMA read descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]        m_axis_dma_read_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]        m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]         m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]         m_axis_dma_read_desc_tag,
    output wire                             m_axis_dma_read_desc_valid,
    input  wire                             m_axis_dma_read_desc_ready,

    /*
     * DMA read descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]         s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                       s_axis_dma_read_desc_status_error,
    input  wire                             s_axis_dma_read_desc_status_valid,

    /*
     * Transmit descriptor output
     */
    output wire [RAM_ADDR_WIDTH-1:0]        m_axis_tx_desc_addr,
    output wire [DMA_CLIENT_LEN_WIDTH-1:0]  m_axis_tx_desc_len,
    output wire [DMA_CLIENT_TAG_WIDTH-1:0]  m_axis_tx_desc_tag,
    output wire                             m_axis_tx_desc_user,
    output wire                             m_axis_tx_desc_valid,
    input  wire                             m_axis_tx_desc_ready,

    /*
     * Transmit descriptor status input
     */
    input  wire [DMA_CLIENT_TAG_WIDTH-1:0]  s_axis_tx_desc_status_tag,
    input  wire [3:0]                       s_axis_tx_desc_status_error,
    input  wire                             s_axis_tx_desc_status_valid,

    /*
     * Transmit checksum command output
     */
    output wire                             m_axis_tx_csum_cmd_csum_enable,
    output wire [7:0]                       m_axis_tx_csum_cmd_csum_start,
    output wire [7:0]                       m_axis_tx_csum_cmd_csum_offset,
    output wire                             m_axis_tx_csum_cmd_valid,
    input  wire                             m_axis_tx_csum_cmd_ready,

    /*
     * Transmit timestamp input
     */
    input  wire [95:0]                      s_axis_tx_ptp_ts_96,
    input  wire                             s_axis_tx_ptp_ts_valid,
    output wire                             s_axis_tx_ptp_ts_ready,

    /*
     * Configuration
     */
    input  wire                             enable
);

parameter CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
parameter DESC_PTR_MASK = {CL_DESC_TABLE_SIZE{1'b1}};

parameter CL_MAX_TX_SIZE = $clog2(MAX_TX_SIZE);
parameter CL_TX_BUFFER_SIZE = $clog2(TX_BUFFER_SIZE);
parameter TX_BUFFER_PTR_MASK = {CL_TX_BUFFER_SIZE{1'b1}};
parameter TX_BUFFER_PTR_MASK_LOWER = {$clog2(TX_BUFFER_STEP_SIZE){1'b1}};
parameter TX_BUFFER_PTR_MASK_UPPER = TX_BUFFER_PTR_MASK & ~TX_BUFFER_PTR_MASK_LOWER;

parameter CL_MAX_DESC_REQ = $clog2(MAX_DESC_REQ);

// bus width assertions
initial begin
    if (DMA_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: DMA tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (DMA_CLIENT_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: DMA client tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (QUEUE_REQ_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: QUEUE_REQ_TAG_WIDTH must be at least $clog2(DESC_TABLE_SIZE) (instance %m)");
        $finish;
    end

    if (DESC_REQ_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: DESC_REQ_TAG_WIDTH must be at least $clog2(DESC_TABLE_SIZE) (instance %m)");
        $finish;
    end

    if (QUEUE_REQ_TAG_WIDTH < REQ_TAG_WIDTH) begin
        $error("Error: QUEUE_REQ_TAG_WIDTH must be at least REQ_TAG_WIDTH (instance %m)");
        $finish;
    end
end

reg s_axis_tx_req_ready_reg = 1'b0, s_axis_tx_req_ready_next;

reg [DMA_CLIENT_LEN_WIDTH-1:0] m_axis_tx_req_status_len_reg = {DMA_CLIENT_LEN_WIDTH{1'b0}}, m_axis_tx_req_status_len_next;
reg [REQ_TAG_WIDTH-1:0] m_axis_tx_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, m_axis_tx_req_status_tag_next;
reg m_axis_tx_req_status_valid_reg = 1'b0, m_axis_tx_req_status_valid_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_desc_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_desc_req_queue_next;
reg [DESC_REQ_TAG_WIDTH-1:0] m_axis_desc_req_tag_reg = {DESC_REQ_TAG_WIDTH{1'b0}}, m_axis_desc_req_tag_next;
reg m_axis_desc_req_valid_reg = 1'b0, m_axis_desc_req_valid_next;

reg s_axis_desc_tready_reg = 1'b0, s_axis_desc_tready_next;

reg [CPL_QUEUE_INDEX_WIDTH-1:0] m_axis_cpl_req_queue_reg = {CPL_QUEUE_INDEX_WIDTH{1'b0}}, m_axis_cpl_req_queue_next;
reg [DESC_REQ_TAG_WIDTH-1:0] m_axis_cpl_req_tag_reg = {DESC_REQ_TAG_WIDTH{1'b0}}, m_axis_cpl_req_tag_next;
reg [CPL_SIZE*8-1:0] m_axis_cpl_req_data_reg = {CPL_SIZE*8{1'b0}}, m_axis_cpl_req_data_next;
reg m_axis_cpl_req_valid_reg = 1'b0, m_axis_cpl_req_valid_next;

reg [DMA_ADDR_WIDTH-1:0] m_axis_dma_read_desc_dma_addr_reg = {DMA_ADDR_WIDTH{1'b0}}, m_axis_dma_read_desc_dma_addr_next;
reg [RAM_ADDR_WIDTH-1:0] m_axis_dma_read_desc_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, m_axis_dma_read_desc_ram_addr_next;
reg [DMA_LEN_WIDTH-1:0] m_axis_dma_read_desc_len_reg = {DMA_LEN_WIDTH{1'b0}}, m_axis_dma_read_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] m_axis_dma_read_desc_tag_reg = {DMA_TAG_WIDTH{1'b0}}, m_axis_dma_read_desc_tag_next;
reg m_axis_dma_read_desc_valid_reg = 1'b0, m_axis_dma_read_desc_valid_next;

reg [RAM_ADDR_WIDTH-1:0] m_axis_tx_desc_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, m_axis_tx_desc_addr_next;
reg [DMA_CLIENT_LEN_WIDTH-1:0] m_axis_tx_desc_len_reg = {DMA_CLIENT_LEN_WIDTH{1'b0}}, m_axis_tx_desc_len_next;
reg [DMA_CLIENT_TAG_WIDTH-1:0] m_axis_tx_desc_tag_reg = {DMA_CLIENT_TAG_WIDTH{1'b0}}, m_axis_tx_desc_tag_next;
reg m_axis_tx_desc_user_reg = 1'b0, m_axis_tx_desc_user_next;
reg m_axis_tx_desc_valid_reg = 1'b0, m_axis_tx_desc_valid_next;

reg m_axis_tx_csum_cmd_csum_enable_reg = 1'b0, m_axis_tx_csum_cmd_csum_enable_next;
reg [7:0] m_axis_tx_csum_cmd_csum_start_reg = 7'd0, m_axis_tx_csum_cmd_csum_start_next;
reg [7:0] m_axis_tx_csum_cmd_csum_offset_reg = 7'd0, m_axis_tx_csum_cmd_csum_offset_next;
reg m_axis_tx_csum_cmd_valid_reg = 1'b0, m_axis_tx_csum_cmd_valid_next;

reg s_axis_tx_ptp_ts_ready_reg = 1'b0, s_axis_tx_ptp_ts_ready_next;

reg [CL_TX_BUFFER_SIZE+1-1:0] buf_wr_ptr_reg = 0, buf_wr_ptr_next;
reg [CL_TX_BUFFER_SIZE+1-1:0] buf_rd_ptr_reg = 0, buf_rd_ptr_next;

reg desc_start_reg = 1'b1, desc_start_next;
reg [DMA_CLIENT_LEN_WIDTH-1:0] desc_len_reg = {DMA_CLIENT_LEN_WIDTH{1'b0}}, desc_len_next;

reg [DMA_CLIENT_LEN_WIDTH-1:0] early_tx_req_status_len_reg = {DMA_CLIENT_LEN_WIDTH{1'b0}}, early_tx_req_status_len_next;
reg [REQ_TAG_WIDTH-1:0] early_tx_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, early_tx_req_status_tag_next;
reg early_tx_req_status_valid_reg = 1'b0, early_tx_req_status_valid_next;

reg [DMA_CLIENT_LEN_WIDTH-1:0] finish_tx_req_status_len_reg = {DMA_CLIENT_LEN_WIDTH{1'b0}}, finish_tx_req_status_len_next;
reg [REQ_TAG_WIDTH-1:0] finish_tx_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, finish_tx_req_status_tag_next;
reg finish_tx_req_status_valid_reg = 1'b0, finish_tx_req_status_valid_next;

reg [CL_MAX_DESC_REQ+1-1:0] active_desc_req_count_reg = 0;
reg inc_active_desc_req;
reg dec_active_desc_req_1;
reg dec_active_desc_req_2;

reg [DESC_TABLE_SIZE-1:0] desc_table_active = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_invalid = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_desc_fetched = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_data_fetched = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_tx_done = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done = 0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [REQ_TAG_WIDTH-1:0] desc_table_tag[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [QUEUE_INDEX_WIDTH-1:0] desc_table_queue[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [QUEUE_PTR_WIDTH-1:0] desc_table_queue_ptr[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [CPL_QUEUE_INDEX_WIDTH-1:0] desc_table_cpl_queue[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [6:0] desc_table_csum_start[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [7:0] desc_table_csum_offset[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg desc_table_csum_enable[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [DMA_CLIENT_LEN_WIDTH-1:0] desc_table_len[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [CL_TX_BUFFER_SIZE+1-1:0] desc_table_buf_ptr[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [95:0] desc_table_ptp_ts[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg desc_table_read_commit[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [DESC_TABLE_DMA_OP_COUNT_WIDTH-1:0] desc_table_read_count_start[DESC_TABLE_SIZE-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [DESC_TABLE_DMA_OP_COUNT_WIDTH-1:0] desc_table_read_count_finish[DESC_TABLE_SIZE-1:0];

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr_reg = 0;
reg [QUEUE_INDEX_WIDTH-1:0] desc_table_start_queue;
reg [REQ_TAG_WIDTH-1:0] desc_table_start_tag;
reg desc_table_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_dequeue_ptr;
reg [QUEUE_PTR_WIDTH-1:0] desc_table_dequeue_queue_ptr;
reg [CPL_QUEUE_INDEX_WIDTH-1:0] desc_table_dequeue_cpl_queue;
reg desc_table_dequeue_invalid;
reg desc_table_dequeue_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_desc_ctrl_ptr;
reg [CL_TX_BUFFER_SIZE+1-1:0] desc_table_desc_ctrl_buf_ptr;
reg [6:0] desc_table_desc_ctrl_csum_start;
reg [7:0] desc_table_desc_ctrl_csum_offset;
reg desc_table_desc_ctrl_csum_enable;
reg desc_table_desc_ctrl_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_desc_fetched_ptr;
reg [DMA_CLIENT_LEN_WIDTH-1:0] desc_table_desc_fetched_len;
reg desc_table_desc_fetched_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_data_fetched_ptr;
reg desc_table_data_fetched_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_tx_start_ptr_reg = 0;
reg desc_table_tx_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_tx_finish_ptr;
reg desc_table_tx_finish_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_store_ptp_ts_ptr_reg = 0;
reg [95:0] desc_table_store_ptp_ts;
reg desc_table_store_ptp_ts_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_cpl_enqueue_start_ptr_reg = 0;
reg desc_table_cpl_enqueue_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done_ptr;
reg desc_table_cpl_write_done_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_finish_ptr_reg = 0;
reg desc_table_finish_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_read_start_ptr;
reg desc_table_read_start_commit;
reg desc_table_read_start_init;
reg desc_table_read_start_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_read_finish_ptr;
reg desc_table_read_finish_en;

assign s_axis_tx_req_ready = s_axis_tx_req_ready_reg;

assign m_axis_tx_req_status_len = m_axis_tx_req_status_len_reg;
assign m_axis_tx_req_status_tag = m_axis_tx_req_status_tag_reg;
assign m_axis_tx_req_status_valid = m_axis_tx_req_status_valid_reg;

assign m_axis_desc_req_queue = m_axis_desc_req_queue_reg;
assign m_axis_desc_req_tag = m_axis_desc_req_tag_reg;
assign m_axis_desc_req_valid = m_axis_desc_req_valid_reg;

assign s_axis_desc_tready = s_axis_desc_tready_reg;

assign m_axis_cpl_req_queue = m_axis_cpl_req_queue_reg;
assign m_axis_cpl_req_tag = m_axis_cpl_req_tag_reg;
assign m_axis_cpl_req_data = m_axis_cpl_req_data_reg;
assign m_axis_cpl_req_valid = m_axis_cpl_req_valid_reg;

assign m_axis_dma_read_desc_dma_addr = m_axis_dma_read_desc_dma_addr_reg;
assign m_axis_dma_read_desc_ram_addr = m_axis_dma_read_desc_ram_addr_reg;
assign m_axis_dma_read_desc_len = m_axis_dma_read_desc_len_reg;
assign m_axis_dma_read_desc_tag = m_axis_dma_read_desc_tag_reg;
assign m_axis_dma_read_desc_valid = m_axis_dma_read_desc_valid_reg;

assign m_axis_tx_desc_addr = m_axis_tx_desc_addr_reg;
assign m_axis_tx_desc_len = m_axis_tx_desc_len_reg;
assign m_axis_tx_desc_tag = m_axis_tx_desc_tag_reg;
assign m_axis_tx_desc_user = m_axis_tx_desc_user_reg;
assign m_axis_tx_desc_valid = m_axis_tx_desc_valid_reg;

assign m_axis_tx_csum_cmd_csum_enable = m_axis_tx_csum_cmd_csum_enable_reg;
assign m_axis_tx_csum_cmd_csum_start = m_axis_tx_csum_cmd_csum_start_reg;
assign m_axis_tx_csum_cmd_csum_offset = m_axis_tx_csum_cmd_csum_offset_reg;
assign m_axis_tx_csum_cmd_valid = m_axis_tx_csum_cmd_valid_reg;

assign s_axis_tx_ptp_ts_ready = s_axis_tx_ptp_ts_ready_reg;

// reg [15:0] stall_cnt = 0;
// wire stalled = stall_cnt[12];

// // assign dbg = stalled;

// always @(posedge clk) begin
//     if (rst) begin
//         stall_cnt <= 0;
//     end else begin
//         if (s_axis_tx_req_ready) begin
//             stall_cnt <= 0;
//         end else begin
//             stall_cnt <= stall_cnt + 1;
//         end
//     end
// end

// ila_0 ila_inst (
//     .clk(clk),
//     .trig_out(),
//     .trig_out_ack(1'b0),
//     .trig_in(1'b0),
//     .trig_in_ack(),
//     .probe0({desc_table_active, desc_table_invalid, desc_table_desc_fetched, desc_table_data_fetched, desc_table_tx_done, desc_table_cpl_write_done, pkt_table_active,
//         m_axis_dma_read_desc_len, m_axis_dma_read_desc_tag, m_axis_dma_read_desc_valid, m_axis_dma_read_desc_ready,
//         s_axis_dma_read_desc_status_tag, s_axis_dma_read_desc_status_valid,
//         m_axis_dma_write_desc_len, m_axis_dma_write_desc_tag, m_axis_dma_write_desc_valid, m_axis_dma_write_desc_ready,
//         s_axis_dma_write_desc_status_tag, s_axis_dma_write_desc_status_valid}),
//     .probe1(0),
//     .probe2(0),
//     .probe3(s_axis_tx_req_ready),
//     .probe4({desc_table_start_ptr_reg, desc_table_desc_read_start_ptr_reg, desc_table_data_fetch_start_ptr_reg, desc_table_tx_start_ptr_reg, desc_table_cpl_enqueue_start_ptr_reg, desc_table_finish_ptr_reg, stall_cnt}),
//     .probe5(0)
// );

integer i;

initial begin
    for (i = 0; i < DESC_TABLE_SIZE; i = i + 1) begin
        desc_table_tag[i] = 0;
        desc_table_queue[i] = 0;
        desc_table_queue_ptr[i] = 0;
        desc_table_cpl_queue[i] = 0;
        desc_table_csum_start[i] = 0;
        desc_table_csum_offset[i] = 0;
        desc_table_csum_enable[i] = 0;
        desc_table_len[i] = 0;
        desc_table_buf_ptr[i] = 0;
        desc_table_ptp_ts[i] = 0;
        desc_table_read_commit[i] = 0;
        desc_table_read_count_start[i] = 0;
        desc_table_read_count_finish[i] = 0;
    end
end

always @* begin
    s_axis_tx_req_ready_next = 1'b0;

    m_axis_tx_req_status_len_next = m_axis_tx_req_status_len_reg;
    m_axis_tx_req_status_tag_next = m_axis_tx_req_status_tag_reg;
    m_axis_tx_req_status_valid_next = 1'b0;

    m_axis_desc_req_queue_next = m_axis_desc_req_queue_reg;
    m_axis_desc_req_tag_next = m_axis_desc_req_tag_reg;
    m_axis_desc_req_valid_next = m_axis_desc_req_valid_reg && !m_axis_desc_req_ready;

    s_axis_desc_tready_next = 1'b0;

    m_axis_cpl_req_queue_next = m_axis_cpl_req_queue_reg;
    m_axis_cpl_req_tag_next = m_axis_cpl_req_tag_reg;
    m_axis_cpl_req_data_next = m_axis_cpl_req_data_reg;
    m_axis_cpl_req_valid_next = m_axis_cpl_req_valid_reg && !m_axis_cpl_req_ready;

    m_axis_dma_read_desc_dma_addr_next = m_axis_dma_read_desc_dma_addr_reg;
    m_axis_dma_read_desc_ram_addr_next = m_axis_dma_read_desc_ram_addr_reg;
    m_axis_dma_read_desc_len_next = m_axis_dma_read_desc_len_reg;
    m_axis_dma_read_desc_tag_next = m_axis_dma_read_desc_tag_reg;
    m_axis_dma_read_desc_valid_next = m_axis_dma_read_desc_valid_reg && !m_axis_dma_read_desc_ready;

    m_axis_tx_desc_addr_next = m_axis_tx_desc_addr_reg;
    m_axis_tx_desc_len_next = m_axis_tx_desc_len_reg;
    m_axis_tx_desc_tag_next = m_axis_tx_desc_tag_reg;
    m_axis_tx_desc_user_next = m_axis_tx_desc_user_reg;
    m_axis_tx_desc_valid_next = m_axis_tx_desc_valid_reg && !m_axis_tx_desc_ready;

    m_axis_tx_csum_cmd_csum_enable_next = m_axis_tx_csum_cmd_csum_enable_reg;
    m_axis_tx_csum_cmd_csum_start_next = m_axis_tx_csum_cmd_csum_start_reg;
    m_axis_tx_csum_cmd_csum_offset_next = m_axis_tx_csum_cmd_csum_offset_reg;
    m_axis_tx_csum_cmd_valid_next = m_axis_tx_csum_cmd_valid_reg && !m_axis_tx_csum_cmd_ready;

    s_axis_tx_ptp_ts_ready_next = 1'b0;

    buf_wr_ptr_next = buf_wr_ptr_reg;
    buf_rd_ptr_next = buf_rd_ptr_reg;

    desc_start_next = desc_start_reg;
    desc_len_next = desc_len_reg;

    early_tx_req_status_len_next = early_tx_req_status_len_reg;
    early_tx_req_status_tag_next = early_tx_req_status_tag_reg;
    early_tx_req_status_valid_next = early_tx_req_status_valid_reg;

    finish_tx_req_status_len_next = finish_tx_req_status_len_reg;
    finish_tx_req_status_tag_next = finish_tx_req_status_tag_reg;
    finish_tx_req_status_valid_next = finish_tx_req_status_valid_reg;

    inc_active_desc_req = 1'b0;
    dec_active_desc_req_1 = 1'b0;
    dec_active_desc_req_2 = 1'b0;

    desc_table_start_tag = s_axis_tx_req_tag;
    desc_table_start_queue = s_axis_tx_req_queue;
    desc_table_start_en = 1'b0;
    desc_table_dequeue_ptr = s_axis_desc_req_status_tag;
    desc_table_dequeue_queue_ptr = s_axis_desc_req_status_ptr;
    desc_table_dequeue_cpl_queue = s_axis_desc_req_status_cpl;
    desc_table_dequeue_invalid = 1'b0;
    desc_table_dequeue_en = 1'b0;
    desc_table_desc_ctrl_ptr = s_axis_desc_tid & DESC_PTR_MASK;
    desc_table_desc_ctrl_buf_ptr = buf_wr_ptr_reg;
    if (TX_CHECKSUM_ENABLE) begin
        desc_table_desc_ctrl_csum_start = s_axis_desc_tdata[23:16];
        desc_table_desc_ctrl_csum_offset = s_axis_desc_tdata[30:24];
        desc_table_desc_ctrl_csum_enable = s_axis_desc_tdata[31];
    end else begin
        desc_table_desc_ctrl_csum_start = 0;
        desc_table_desc_ctrl_csum_offset = 0;
        desc_table_desc_ctrl_csum_enable = 0;
    end
    desc_table_desc_ctrl_en = 1'b0;
    desc_table_desc_fetched_ptr = s_axis_desc_tid & DESC_PTR_MASK;
    desc_table_desc_fetched_len = desc_len_reg + s_axis_desc_tdata[63:32];
    desc_table_desc_fetched_en = 1'b0;
    desc_table_data_fetched_ptr = s_axis_dma_read_desc_status_tag & DESC_PTR_MASK;
    desc_table_data_fetched_en = 1'b0;
    desc_table_tx_start_en = 1'b0;
    desc_table_tx_finish_ptr = s_axis_tx_desc_status_tag;
    desc_table_tx_finish_en = 1'b0;
    desc_table_store_ptp_ts = s_axis_tx_ptp_ts_96;
    desc_table_store_ptp_ts_en = 1'b0;
    desc_table_cpl_enqueue_start_en = 1'b0;
    desc_table_cpl_write_done_ptr = s_axis_cpl_req_status_tag & DESC_PTR_MASK;
    desc_table_cpl_write_done_en = 1'b0;
    desc_table_finish_en = 1'b0;
    desc_table_read_start_ptr = s_axis_desc_tid;
    desc_table_read_start_commit = 1'b0;
    desc_table_read_start_init = 1'b0;
    desc_table_read_start_en = 1'b0;
    desc_table_read_finish_ptr = s_axis_dma_read_desc_status_tag;
    desc_table_read_finish_en = 1'b0;

    // descriptor fetch
    // wait for transmit request
    s_axis_tx_req_ready_next = enable && active_desc_req_count_reg < MAX_DESC_REQ && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE) && (!m_axis_desc_req_valid || m_axis_desc_req_ready);
    if (s_axis_tx_req_ready && s_axis_tx_req_valid) begin
        s_axis_tx_req_ready_next = 1'b0;
 
        // store in descriptor table
        desc_table_start_tag = s_axis_tx_req_tag;
        desc_table_start_queue = s_axis_tx_req_queue;
        desc_table_start_en = 1'b1;

        // initiate descriptor fetch
        m_axis_desc_req_queue_next = s_axis_tx_req_queue;
        m_axis_desc_req_tag_next = desc_table_start_ptr_reg & DESC_PTR_MASK;
        m_axis_desc_req_valid_next = 1'b1;

        inc_active_desc_req = 1'b1;
    end

    // descriptor fetch
    // wait for queue query response
    if (s_axis_desc_req_status_valid) begin

        // update entry in descriptor table
        desc_table_dequeue_ptr = s_axis_desc_req_status_tag & DESC_PTR_MASK;
        desc_table_dequeue_queue_ptr = s_axis_desc_req_status_ptr;
        desc_table_dequeue_cpl_queue = s_axis_desc_req_status_cpl;
        desc_table_dequeue_invalid = 1'b0;
        desc_table_dequeue_en = 1'b1;

        if (s_axis_desc_req_status_error || s_axis_desc_req_status_empty) begin
            // queue empty or not active

            // invalidate entry
            desc_table_dequeue_invalid = 1'b1;

            // return transmit request completion
            early_tx_req_status_len_next = 0;
            early_tx_req_status_tag_next = desc_table_tag[s_axis_desc_req_status_tag & DESC_PTR_MASK];
            early_tx_req_status_valid_next = 1'b1;

            dec_active_desc_req_1 = 1'b1;
        end else begin
            // descriptor available to dequeue

            // wait for descriptor
        end
    end

    // descriptor processing and DMA request generation
    // TODO descriptor validation?
    s_axis_desc_tready_next = !m_axis_dma_read_desc_valid && ($unsigned(buf_wr_ptr_reg - buf_rd_ptr_reg) < TX_BUFFER_SIZE - MAX_TX_SIZE);
    if (s_axis_desc_tready && s_axis_desc_tvalid) begin
        if (desc_table_active[s_axis_desc_tid & DESC_PTR_MASK]) begin
            desc_start_next = 1'b0;
            desc_len_next = desc_len_reg + s_axis_desc_tdata[63:32];

            if (desc_len_next > MAX_TX_SIZE) begin
                desc_len_next = MAX_TX_SIZE;
            end

            desc_table_read_start_init = desc_start_reg;

            // update entry in descriptor table
            desc_table_desc_ctrl_ptr = s_axis_desc_tid & DESC_PTR_MASK;
            desc_table_desc_ctrl_buf_ptr = buf_wr_ptr_reg;
            if (TX_CHECKSUM_ENABLE) begin
                desc_table_desc_ctrl_csum_start = s_axis_desc_tdata[23:16];
                desc_table_desc_ctrl_csum_offset = s_axis_desc_tdata[30:24];
                desc_table_desc_ctrl_csum_enable = s_axis_desc_tdata[31];
            end
            desc_table_desc_ctrl_en = desc_start_reg;

            // initiate data fetch to onboard RAM
            m_axis_dma_read_desc_dma_addr_next = s_axis_desc_tdata[127:64];
            m_axis_dma_read_desc_ram_addr_next = (buf_wr_ptr_reg & TX_BUFFER_PTR_MASK) + desc_len_reg + TX_BUFFER_OFFSET;
            m_axis_dma_read_desc_len_next = s_axis_desc_tdata[63:32];
            m_axis_dma_read_desc_tag_next = s_axis_desc_tid & DESC_PTR_MASK;

            desc_table_read_start_ptr = s_axis_desc_tid;

            if (m_axis_dma_read_desc_len_next != 0) begin
                m_axis_dma_read_desc_valid_next = 1'b1;

                // read start
                desc_table_read_start_en = 1'b1;

                s_axis_desc_tready_next = 1'b0;
            end

            if (s_axis_desc_tlast) begin
                // update entry in descriptor table
                desc_table_desc_fetched_ptr = s_axis_desc_tid & DESC_PTR_MASK;
                desc_table_desc_fetched_len = desc_len_next;
                desc_table_desc_fetched_en = 1'b1;

                // read commit
                desc_table_read_start_commit = 1'b1;

                // update write pointer
                buf_wr_ptr_next = (buf_wr_ptr_reg + desc_len_next + TX_BUFFER_PTR_MASK_LOWER) & ~TX_BUFFER_PTR_MASK_LOWER;

                if ((buf_wr_ptr_reg & TX_BUFFER_PTR_MASK) + desc_len_next > TX_BUFFER_SIZE - MAX_TX_SIZE) begin
                    buf_wr_ptr_next = ~buf_wr_ptr_reg & ~TX_BUFFER_PTR_MASK;
                end

                dec_active_desc_req_2 = 1'b1;

                desc_start_next = 1'b1;
                desc_len_next = 0;
            end
        end
    end

    // data fetch completion
    // wait for data fetch completion
    if (s_axis_dma_read_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_data_fetched_ptr = s_axis_dma_read_desc_status_tag & DESC_PTR_MASK;
        desc_table_data_fetched_en = 1'b1;

        // read finish
        desc_table_read_finish_ptr = s_axis_dma_read_desc_status_tag;
        desc_table_read_finish_en = 1'b1;
    end

    // transmit
    // wait for data fetch completion
    if (desc_table_active[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] && desc_table_tx_start_ptr_reg != desc_table_start_ptr_reg) begin
        if (desc_table_invalid[desc_table_tx_start_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_tx_start_en = 1'b1;
        //end else if (desc_table_data_fetched[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] && !m_axis_tx_desc_valid && (!m_axis_tx_csum_cmd_valid || !TX_CHECKSUM_ENABLE)) begin
        end else if (desc_table_desc_fetched[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] && desc_table_read_commit[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] && (desc_table_read_count_start[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] == desc_table_read_count_finish[desc_table_tx_start_ptr_reg & DESC_PTR_MASK]) && !m_axis_tx_desc_valid && (!m_axis_tx_csum_cmd_valid || !TX_CHECKSUM_ENABLE)) begin
            // update entry in descriptor table
            desc_table_tx_start_en = 1'b1;

            // initiate transmit operation
            m_axis_tx_desc_addr_next = desc_table_buf_ptr[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] & TX_BUFFER_PTR_MASK + TX_BUFFER_OFFSET;
            m_axis_tx_desc_len_next = desc_table_len[desc_table_tx_start_ptr_reg & DESC_PTR_MASK];
            m_axis_tx_desc_tag_next = desc_table_tx_start_ptr_reg & DESC_PTR_MASK;
            m_axis_tx_desc_user_next = 1'b0;
            m_axis_tx_desc_valid_next = 1'b1;

            // send TX checksum command
            if (TX_CHECKSUM_ENABLE) begin
                m_axis_tx_csum_cmd_csum_enable_next = desc_table_csum_enable[desc_table_tx_start_ptr_reg & DESC_PTR_MASK];
                m_axis_tx_csum_cmd_csum_start_next = desc_table_csum_start[desc_table_tx_start_ptr_reg & DESC_PTR_MASK];
                m_axis_tx_csum_cmd_csum_offset_next = desc_table_csum_start[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] + desc_table_csum_offset[desc_table_tx_start_ptr_reg & DESC_PTR_MASK];
                m_axis_tx_csum_cmd_valid_next = 1'b1;
            end
        end
    end

    // transmit done
    // wait for transmit completion
    if (s_axis_tx_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_tx_finish_ptr = s_axis_tx_desc_status_tag;
        desc_table_tx_finish_en = 1'b1;

        // update read pointer
        buf_rd_ptr_next = (desc_table_buf_ptr[s_axis_tx_desc_status_tag & DESC_PTR_MASK] + desc_table_len[s_axis_tx_desc_status_tag & DESC_PTR_MASK] + TX_BUFFER_PTR_MASK_LOWER) & ~TX_BUFFER_PTR_MASK_LOWER;

        if ((desc_table_buf_ptr[s_axis_tx_desc_status_tag & DESC_PTR_MASK] & TX_BUFFER_PTR_MASK) + desc_table_len[s_axis_tx_desc_status_tag & DESC_PTR_MASK] > TX_BUFFER_SIZE - MAX_TX_SIZE) begin
            buf_rd_ptr_next = ~desc_table_buf_ptr[s_axis_tx_desc_status_tag & DESC_PTR_MASK] & ~TX_BUFFER_PTR_MASK;
        end
    end

    // store PTP timestamp
    if (desc_table_active[desc_table_store_ptp_ts_ptr_reg & DESC_PTR_MASK] && desc_table_store_ptp_ts_ptr_reg != desc_table_start_ptr_reg && desc_table_store_ptp_ts_ptr_reg != desc_table_tx_start_ptr_reg && PTP_TS_ENABLE) begin
        s_axis_tx_ptp_ts_ready_next = 1'b1;
        if (desc_table_invalid[desc_table_store_ptp_ts_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_store_ptp_ts_en = 1'b1;

            s_axis_tx_ptp_ts_ready_next = 1'b0;
        end else if (s_axis_tx_ptp_ts_ready && s_axis_tx_ptp_ts_valid) begin
            // update entry in descriptor table
            desc_table_store_ptp_ts = s_axis_tx_ptp_ts_96;
            desc_table_store_ptp_ts_en = 1'b1;

            s_axis_tx_ptp_ts_ready_next = 1'b0;
        end
    end

    // finish transmit; start completion enqueue
    if (desc_table_active[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] && desc_table_cpl_enqueue_start_ptr_reg != desc_table_start_ptr_reg && desc_table_cpl_enqueue_start_ptr_reg != desc_table_tx_start_ptr_reg && (desc_table_cpl_enqueue_start_ptr_reg != desc_table_store_ptp_ts_ptr_reg || !PTP_TS_ENABLE)) begin
        if (desc_table_invalid[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_cpl_enqueue_start_en = 1'b1;
        end else if (desc_table_tx_done[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] && !m_axis_cpl_req_valid_next) begin
            // update entry in descriptor table
            desc_table_cpl_enqueue_start_en = 1'b1;

            // initiate queue query
            m_axis_cpl_req_queue_next = desc_table_cpl_queue[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_req_tag_next = desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK;
            m_axis_cpl_req_data_next = 0;
            m_axis_cpl_req_data_next[15:0]  = desc_table_queue[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_req_data_next[31:16] = desc_table_queue_ptr[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_req_data_next[47:32] = desc_table_len[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            if (PTP_TS_ENABLE) begin
                //m_axis_cpl_req_data_next[127:64] = desc_table_ptp_ts[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] >> 16;
                m_axis_cpl_req_data_next[111:64] = desc_table_ptp_ts[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] >> 16;
            end
            m_axis_cpl_req_valid_next = 1'b1;
        end
    end

    // start completion write
    // wait for queue query response
    if (s_axis_cpl_req_status_valid) begin
        // update entry in descriptor table
        desc_table_cpl_write_done_ptr = s_axis_cpl_req_status_tag & DESC_PTR_MASK;
        desc_table_cpl_write_done_en = 1'b1;
    end

    // operation complete
    if (desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] && desc_table_finish_ptr_reg != desc_table_start_ptr_reg && desc_table_finish_ptr_reg != desc_table_cpl_enqueue_start_ptr_reg && !finish_tx_req_status_valid_reg) begin
        if (desc_table_invalid[desc_table_finish_ptr_reg & DESC_PTR_MASK]) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;
        end else if (desc_table_cpl_write_done[desc_table_finish_ptr_reg & DESC_PTR_MASK]) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            // return transmit request completion
            finish_tx_req_status_len_next = desc_table_len[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            finish_tx_req_status_tag_next = desc_table_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            finish_tx_req_status_valid_next = 1'b1;
        end
    end

    // transmit request completion arbitration
    if (finish_tx_req_status_valid_next && !m_axis_tx_req_status_valid_reg) begin
        m_axis_tx_req_status_len_next = finish_tx_req_status_len_next;
        m_axis_tx_req_status_tag_next = finish_tx_req_status_tag_next;
        m_axis_tx_req_status_valid_next = 1'b1;
        finish_tx_req_status_valid_next = 1'b0;
    end else if (early_tx_req_status_valid_next && !m_axis_tx_req_status_valid_reg) begin
        m_axis_tx_req_status_len_next = early_tx_req_status_len_next;
        m_axis_tx_req_status_tag_next = early_tx_req_status_tag_next;
        m_axis_tx_req_status_valid_next = 1'b1;
        early_tx_req_status_valid_next = 1'b0;
    end
end

always @(posedge clk) begin
    s_axis_tx_req_ready_reg <= s_axis_tx_req_ready_next;

    m_axis_tx_req_status_len_reg <= m_axis_tx_req_status_len_next;
    m_axis_tx_req_status_tag_reg <= m_axis_tx_req_status_tag_next;
    m_axis_tx_req_status_valid_reg <= m_axis_tx_req_status_valid_next;

    m_axis_desc_req_queue_reg <= m_axis_desc_req_queue_next;
    m_axis_desc_req_tag_reg <= m_axis_desc_req_tag_next;
    m_axis_desc_req_valid_reg <= m_axis_desc_req_valid_next;

    s_axis_desc_tready_reg <= s_axis_desc_tready_next;

    m_axis_cpl_req_queue_reg <= m_axis_cpl_req_queue_next;
    m_axis_cpl_req_tag_reg <= m_axis_cpl_req_tag_next;
    m_axis_cpl_req_data_reg <= m_axis_cpl_req_data_next;
    m_axis_cpl_req_valid_reg <= m_axis_cpl_req_valid_next;

    m_axis_dma_read_desc_dma_addr_reg <= m_axis_dma_read_desc_dma_addr_next;
    m_axis_dma_read_desc_ram_addr_reg <= m_axis_dma_read_desc_ram_addr_next;
    m_axis_dma_read_desc_len_reg <= m_axis_dma_read_desc_len_next;
    m_axis_dma_read_desc_tag_reg <= m_axis_dma_read_desc_tag_next;
    m_axis_dma_read_desc_valid_reg <= m_axis_dma_read_desc_valid_next;

    m_axis_tx_desc_addr_reg <= m_axis_tx_desc_addr_next;
    m_axis_tx_desc_len_reg <= m_axis_tx_desc_len_next;
    m_axis_tx_desc_tag_reg <= m_axis_tx_desc_tag_next;
    m_axis_tx_desc_user_reg <= m_axis_tx_desc_user_next;
    m_axis_tx_desc_valid_reg <= m_axis_tx_desc_valid_next;

    s_axis_tx_ptp_ts_ready_reg <= s_axis_tx_ptp_ts_ready_next;

    m_axis_tx_csum_cmd_csum_enable_reg <= m_axis_tx_csum_cmd_csum_enable_next;
    m_axis_tx_csum_cmd_csum_start_reg <= m_axis_tx_csum_cmd_csum_start_next;
    m_axis_tx_csum_cmd_csum_offset_reg <= m_axis_tx_csum_cmd_csum_offset_next;
    m_axis_tx_csum_cmd_valid_reg <= m_axis_tx_csum_cmd_valid_next;

    buf_wr_ptr_reg <= buf_wr_ptr_next;
    buf_rd_ptr_reg <= buf_rd_ptr_next;

    desc_start_reg <= desc_start_next;
    desc_len_reg <= desc_len_next;

    early_tx_req_status_len_reg <= early_tx_req_status_len_next;
    early_tx_req_status_tag_reg <= early_tx_req_status_tag_next;
    early_tx_req_status_valid_reg <= early_tx_req_status_valid_next;

    finish_tx_req_status_len_reg <= finish_tx_req_status_len_next;
    finish_tx_req_status_tag_reg <= finish_tx_req_status_tag_next;
    finish_tx_req_status_valid_reg <= finish_tx_req_status_valid_next;

    active_desc_req_count_reg <= active_desc_req_count_reg + inc_active_desc_req - dec_active_desc_req_1 - dec_active_desc_req_2;

    // descriptor table operations
    if (desc_table_start_en) begin
        desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b1;
        desc_table_invalid[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_desc_fetched[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_data_fetched[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_tx_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_cpl_write_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_queue[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_queue;
        desc_table_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_tag;
        desc_table_start_ptr_reg <= desc_table_start_ptr_reg + 1;
    end

    if (desc_table_dequeue_en) begin
        desc_table_queue_ptr[desc_table_dequeue_ptr & DESC_PTR_MASK] <= desc_table_dequeue_queue_ptr;
        desc_table_cpl_queue[desc_table_dequeue_ptr & DESC_PTR_MASK] <= desc_table_dequeue_cpl_queue;
        if (desc_table_dequeue_invalid) begin
            desc_table_invalid[desc_table_dequeue_ptr & DESC_PTR_MASK] <= 1'b1;
        end
    end

    if (desc_table_desc_ctrl_en) begin
        desc_table_buf_ptr[desc_table_desc_ctrl_ptr & DESC_PTR_MASK] <= desc_table_desc_ctrl_buf_ptr;
        desc_table_csum_start[desc_table_desc_ctrl_ptr & DESC_PTR_MASK] <= desc_table_desc_ctrl_csum_start;
        desc_table_csum_offset[desc_table_desc_ctrl_ptr & DESC_PTR_MASK] <= desc_table_desc_ctrl_csum_offset;
        desc_table_csum_enable[desc_table_desc_ctrl_ptr & DESC_PTR_MASK] <= desc_table_desc_ctrl_csum_enable;
    end

    if (desc_table_desc_fetched_en) begin
        desc_table_len[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= desc_table_desc_fetched_len;
        desc_table_desc_fetched[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_data_fetched_en) begin
        desc_table_data_fetched[desc_table_data_fetched_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_tx_start_en) begin
        desc_table_data_fetched[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_tx_start_ptr_reg <= desc_table_tx_start_ptr_reg + 1;
    end

    if (desc_table_tx_finish_en) begin
        desc_table_tx_done[desc_table_tx_finish_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_store_ptp_ts_en) begin
        desc_table_ptp_ts[desc_table_store_ptp_ts_ptr_reg & DESC_PTR_MASK] <= desc_table_store_ptp_ts;
        desc_table_store_ptp_ts_ptr_reg <= desc_table_store_ptp_ts_ptr_reg + 1;
    end

    if (desc_table_cpl_enqueue_start_en) begin
        desc_table_cpl_enqueue_start_ptr_reg <= desc_table_cpl_enqueue_start_ptr_reg + 1;
    end

    if (desc_table_cpl_write_done_en) begin
        desc_table_cpl_write_done[desc_table_cpl_write_done_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_finish_en) begin
        desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_finish_ptr_reg <= desc_table_finish_ptr_reg + 1;
    end

    if (desc_table_read_start_en) begin
        desc_table_read_commit[desc_table_read_start_ptr] <= desc_table_read_start_commit;
        if (desc_table_read_start_init) begin
            desc_table_read_count_start[desc_table_read_start_ptr] <= desc_table_read_count_finish[desc_table_read_start_ptr] + 1;
        end else begin
            desc_table_read_count_start[desc_table_read_start_ptr] <= desc_table_read_count_start[desc_table_read_start_ptr] + 1;
        end
    end else if (desc_table_read_start_commit || desc_table_read_start_init) begin
        desc_table_read_commit[desc_table_read_start_ptr] <= desc_table_read_start_commit;
        if (desc_table_read_start_init) begin
            desc_table_read_count_start[desc_table_read_start_ptr] <= desc_table_read_count_finish[desc_table_read_start_ptr];
        end
    end

    if (desc_table_read_finish_en) begin
        desc_table_read_count_finish[desc_table_read_finish_ptr] <= desc_table_read_count_finish[desc_table_read_finish_ptr] + 1;
    end

    if (rst) begin
        s_axis_tx_req_ready_reg <= 1'b0;
        m_axis_tx_req_status_valid_reg <= 1'b0;
        m_axis_desc_req_valid_reg <= 1'b0;
        s_axis_desc_tready_reg <= 1'b0;
        m_axis_cpl_req_valid_reg <= 1'b0;
        m_axis_dma_read_desc_valid_reg <= 1'b0;
        m_axis_tx_desc_valid_reg <= 1'b0;
        s_axis_tx_ptp_ts_ready_reg <= 1'b0;
        m_axis_tx_csum_cmd_valid_reg <= 1'b0;

        buf_wr_ptr_reg <= 0;
        buf_rd_ptr_reg <= 0;

        desc_start_reg <= 1'b1;
        desc_len_reg <= 0;

        early_tx_req_status_valid_reg <= 1'b0;
        finish_tx_req_status_valid_reg <= 1'b0;

        active_desc_req_count_reg <= 0;

        desc_table_active <= 0;
        desc_table_invalid <= 0;
        desc_table_desc_fetched <= 0;
        desc_table_data_fetched <= 0;
        desc_table_tx_done <= 0;

        desc_table_start_ptr_reg <= 0;
        desc_table_tx_start_ptr_reg <= 0;
        desc_table_store_ptp_ts_ptr_reg <= 0;
        desc_table_cpl_enqueue_start_ptr_reg <= 0;
        desc_table_finish_ptr_reg <= 0;
    end
end

endmodule

`resetall
