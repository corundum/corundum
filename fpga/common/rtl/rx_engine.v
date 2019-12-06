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

`timescale 1ns / 1ps

/*
 * Receive engine
 */
module rx_engine #
(
    // DMA RAM address width
    parameter RAM_ADDR_WIDTH = 16,
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA length field width
    parameter DMA_LEN_WIDTH = 20,
    // DMA client length field width
    parameter DMA_CLIENT_LEN_WIDTH = 20,
    // Receive request tag field width
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
    // Packet table size (number of in-progress packets)
    parameter PKT_TABLE_SIZE = 8,
    // Max receive packet size
    parameter MAX_RX_SIZE = 2048,
    // Descriptor size (in bytes)
    parameter DESC_SIZE = 16,
    // Descriptor size (in bytes)
    parameter CPL_SIZE = 32,
    // Width of AXI stream descriptor interfaces in bits
    parameter AXIS_DESC_DATA_WIDTH = DESC_SIZE*8,
    // AXI stream descriptor tkeep signal width (words per cycle)
    parameter AXIS_DESC_KEEP_WIDTH = AXIS_DESC_DATA_WIDTH/8,
    // Enable PTP timestamping
    parameter PTP_TS_ENABLE = 1,
    // Enable RX hashing
    parameter RX_HASH_ENABLE = 1,
    // Enable RX checksum offload
    parameter RX_CHECKSUM_ENABLE = 1
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * Receive request input (queue index)
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]     s_axis_rx_req_queue,
    input  wire [REQ_TAG_WIDTH-1:0]         s_axis_rx_req_tag,
    input  wire                             s_axis_rx_req_valid,
    output wire                             s_axis_rx_req_ready,

    /*
     * Receive request status output
     */
    output wire [DMA_CLIENT_LEN_WIDTH-1:0]  m_axis_rx_req_status_len,
    output wire [REQ_TAG_WIDTH-1:0]         m_axis_rx_req_status_tag,
    output wire                             m_axis_rx_req_status_valid,

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
    output wire [CPL_QUEUE_INDEX_WIDTH-1:0] m_axis_cpl_req_queue,
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
     * DMA write descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]        m_axis_dma_write_desc_dma_addr,
    output wire [RAM_ADDR_WIDTH-1:0]        m_axis_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]         m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]         m_axis_dma_write_desc_tag,
    output wire                             m_axis_dma_write_desc_valid,
    input  wire                             m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]         s_axis_dma_write_desc_status_tag,
    input  wire                             s_axis_dma_write_desc_status_valid,

    /*
     * Receive descriptor output
     */
    output wire [RAM_ADDR_WIDTH-1:0]        m_axis_rx_desc_addr,
    output wire [DMA_CLIENT_LEN_WIDTH-1:0]  m_axis_rx_desc_len,
    output wire [DMA_CLIENT_TAG_WIDTH-1:0]  m_axis_rx_desc_tag,
    output wire                             m_axis_rx_desc_valid,
    input  wire                             m_axis_rx_desc_ready,

    /*
     * Receive descriptor status input
     */
    input  wire [DMA_CLIENT_LEN_WIDTH-1:0]  s_axis_rx_desc_status_len,
    input  wire [DMA_CLIENT_TAG_WIDTH-1:0]  s_axis_rx_desc_status_tag,
    input  wire                             s_axis_rx_desc_status_user,
    input  wire                             s_axis_rx_desc_status_valid,

    /*
     * Receive timestamp input
     */
    input  wire [95:0]                      s_axis_rx_ptp_ts_96,
    input  wire                             s_axis_rx_ptp_ts_valid,
    output wire                             s_axis_rx_ptp_ts_ready,

    /*
     * Receive hash input
     */
    input  wire [31:0]                      s_axis_rx_hash,
    input  wire [3:0]                       s_axis_rx_hash_type,
    input  wire                             s_axis_rx_hash_valid,
    output wire                             s_axis_rx_hash_ready,

    /*
     * Receive checksum input
     */
    input  wire [15:0]                      s_axis_rx_csum,
    input  wire                             s_axis_rx_csum_valid,
    output wire                             s_axis_rx_csum_ready,

    /*
     * Configuration
     */
    input  wire                             enable
);

parameter CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
parameter DESC_PTR_MASK = {CL_DESC_TABLE_SIZE{1'b1}};
parameter CL_PKT_TABLE_SIZE = $clog2(PKT_TABLE_SIZE);

parameter CL_MAX_RX_SIZE = $clog2(MAX_RX_SIZE);

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
end

reg s_axis_rx_req_ready_reg = 1'b0, s_axis_rx_req_ready_next;

reg [DMA_CLIENT_LEN_WIDTH-1:0] m_axis_rx_req_status_len_reg = {DMA_CLIENT_LEN_WIDTH{1'b0}}, m_axis_rx_req_status_len_next;
reg [REQ_TAG_WIDTH-1:0] m_axis_rx_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, m_axis_rx_req_status_tag_next;
reg m_axis_rx_req_status_valid_reg = 1'b0, m_axis_rx_req_status_valid_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_desc_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_desc_req_queue_next;
reg [DESC_REQ_TAG_WIDTH-1:0] m_axis_desc_req_tag_reg = {DESC_REQ_TAG_WIDTH{1'b0}}, m_axis_desc_req_tag_next;
reg m_axis_desc_req_valid_reg = 1'b0, m_axis_desc_req_valid_next;

reg s_axis_desc_tready_reg = 1'b0, s_axis_desc_tready_next;

reg [CPL_QUEUE_INDEX_WIDTH-1:0] m_axis_cpl_req_queue_reg = {CPL_QUEUE_INDEX_WIDTH{1'b0}}, m_axis_cpl_req_queue_next;
reg [DESC_REQ_TAG_WIDTH-1:0] m_axis_cpl_req_tag_reg = {DESC_REQ_TAG_WIDTH{1'b0}}, m_axis_cpl_req_tag_next;
reg [CPL_SIZE*8-1:0] m_axis_cpl_req_data_reg = {CPL_SIZE*8{1'b0}}, m_axis_cpl_req_data_next;
reg m_axis_cpl_req_valid_reg = 1'b0, m_axis_cpl_req_valid_next;

reg [DMA_ADDR_WIDTH-1:0] m_axis_dma_write_desc_dma_addr_reg = {DMA_ADDR_WIDTH{1'b0}}, m_axis_dma_write_desc_dma_addr_next;
reg [RAM_ADDR_WIDTH-1:0] m_axis_dma_write_desc_ram_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, m_axis_dma_write_desc_ram_addr_next;
reg [DMA_LEN_WIDTH-1:0] m_axis_dma_write_desc_len_reg = {DMA_LEN_WIDTH{1'b0}}, m_axis_dma_write_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] m_axis_dma_write_desc_tag_reg = {DMA_TAG_WIDTH{1'b0}}, m_axis_dma_write_desc_tag_next;
reg m_axis_dma_write_desc_valid_reg = 1'b0, m_axis_dma_write_desc_valid_next;

reg [RAM_ADDR_WIDTH-1:0] m_axis_rx_desc_addr_reg = {RAM_ADDR_WIDTH{1'b0}}, m_axis_rx_desc_addr_next;
reg [DMA_CLIENT_LEN_WIDTH-1:0] m_axis_rx_desc_len_reg = {DMA_CLIENT_LEN_WIDTH{1'b0}}, m_axis_rx_desc_len_next;
reg [DMA_CLIENT_TAG_WIDTH-1:0] m_axis_rx_desc_tag_reg = {DMA_CLIENT_TAG_WIDTH{1'b0}}, m_axis_rx_desc_tag_next;
reg m_axis_rx_desc_valid_reg = 1'b0, m_axis_rx_desc_valid_next;

reg s_axis_rx_ptp_ts_ready_reg = 1'b0, s_axis_rx_ptp_ts_ready_next;

reg s_axis_rx_hash_ready_reg = 1'b0, s_axis_rx_hash_ready_next;

reg s_axis_rx_csum_ready_reg = 1'b0, s_axis_rx_csum_ready_next;

reg [DESC_TABLE_SIZE-1:0] desc_table_active = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_rx_done = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_invalid = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_desc_fetched = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_data_written = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done = 0;
reg [REQ_TAG_WIDTH-1:0] desc_table_tag[DESC_TABLE_SIZE-1:0];
reg [QUEUE_INDEX_WIDTH-1:0] desc_table_queue[DESC_TABLE_SIZE-1:0];
reg [QUEUE_PTR_WIDTH-1:0] desc_table_queue_ptr[DESC_TABLE_SIZE-1:0];
reg [CPL_QUEUE_INDEX_WIDTH-1:0] desc_table_cpl_queue[DESC_TABLE_SIZE-1:0];
reg [DMA_CLIENT_LEN_WIDTH-1:0] desc_table_dma_len[DESC_TABLE_SIZE-1:0];
reg [DMA_CLIENT_LEN_WIDTH-1:0] desc_table_desc_len[DESC_TABLE_SIZE-1:0];
reg [DMA_ADDR_WIDTH-1:0] desc_table_dma_addr[DESC_TABLE_SIZE-1:0];
reg [CL_PKT_TABLE_SIZE-1:0] desc_table_pkt[DESC_TABLE_SIZE-1:0];
reg [95:0] desc_table_ptp_ts[DESC_TABLE_SIZE-1:0];
reg [31:0] desc_table_hash[DESC_TABLE_SIZE-1:0];
reg [3:0] desc_table_hash_type[DESC_TABLE_SIZE-1:0];
reg [15:0] desc_table_csum[DESC_TABLE_SIZE-1:0];

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr_reg = 0;
reg [QUEUE_INDEX_WIDTH-1:0] desc_table_start_queue;
reg [REQ_TAG_WIDTH-1:0] desc_table_start_tag;
reg [CL_PKT_TABLE_SIZE-1:0] desc_table_start_pkt;
reg desc_table_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_rx_finish_ptr;
reg [DMA_CLIENT_LEN_WIDTH-1:0] desc_table_rx_finish_len;
reg desc_table_rx_finish_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_dequeue_start_ptr_reg = 0;
reg desc_table_dequeue_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_dequeue_ptr;
reg [QUEUE_PTR_WIDTH-1:0] desc_table_dequeue_queue_ptr;
reg [CPL_QUEUE_INDEX_WIDTH-1:0] desc_table_dequeue_cpl_queue;
reg desc_table_dequeue_invalid;
reg desc_table_dequeue_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_desc_fetched_ptr;
reg [DMA_CLIENT_LEN_WIDTH-1:0] desc_table_desc_fetched_len;
reg [DMA_ADDR_WIDTH-1:0] desc_table_desc_fetched_dma_addr;
reg desc_table_desc_fetched_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_data_write_start_ptr_reg = 0;
reg desc_table_data_write_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_data_written_ptr;
reg desc_table_data_written_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_store_ptp_ts_ptr_reg = 0;
reg [95:0] desc_table_store_ptp_ts;
reg desc_table_store_ptp_ts_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_store_hash_ptr_reg = 0;
reg [31:0] desc_table_store_hash;
reg [3:0] desc_table_store_hash_type;
reg desc_table_store_hash_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_store_csum_ptr_reg = 0;
reg [15:0] desc_table_store_csum;
reg desc_table_store_csum_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_cpl_enqueue_start_ptr_reg = 0;
reg desc_table_cpl_enqueue_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done_ptr;
reg desc_table_cpl_write_done_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_finish_ptr_reg = 0;
reg desc_table_finish_en;

reg [PKT_TABLE_SIZE-1:0] pkt_table_active = 0;
reg [CL_PKT_TABLE_SIZE-1:0] pkt_table_start_ptr;
reg pkt_table_start_en;
reg [CL_PKT_TABLE_SIZE-1:0] pkt_table_finish_ptr;
reg pkt_table_finish_en;

assign s_axis_rx_req_ready = s_axis_rx_req_ready_reg;

assign m_axis_rx_req_status_len = m_axis_rx_req_status_len_reg;
assign m_axis_rx_req_status_tag = m_axis_rx_req_status_tag_reg;
assign m_axis_rx_req_status_valid = m_axis_rx_req_status_valid_reg;

assign m_axis_desc_req_queue = m_axis_desc_req_queue_reg;
assign m_axis_desc_req_tag = m_axis_desc_req_tag_reg;
assign m_axis_desc_req_valid = m_axis_desc_req_valid_reg;

assign s_axis_desc_tready = s_axis_desc_tready_reg;

assign m_axis_cpl_req_queue = m_axis_cpl_req_queue_reg;
assign m_axis_cpl_req_tag = m_axis_cpl_req_tag_reg;
assign m_axis_cpl_req_data = m_axis_cpl_req_data_reg;
assign m_axis_cpl_req_valid = m_axis_cpl_req_valid_reg;

assign m_axis_dma_write_desc_dma_addr = m_axis_dma_write_desc_dma_addr_reg;
assign m_axis_dma_write_desc_ram_addr = m_axis_dma_write_desc_ram_addr_reg;
assign m_axis_dma_write_desc_len = m_axis_dma_write_desc_len_reg;
assign m_axis_dma_write_desc_tag = m_axis_dma_write_desc_tag_reg;
assign m_axis_dma_write_desc_valid = m_axis_dma_write_desc_valid_reg;

assign m_axis_rx_desc_addr = m_axis_rx_desc_addr_reg;
assign m_axis_rx_desc_len = m_axis_rx_desc_len_reg;
assign m_axis_rx_desc_tag = m_axis_rx_desc_tag_reg;
assign m_axis_rx_desc_valid = m_axis_rx_desc_valid_reg;

assign s_axis_rx_ptp_ts_ready = s_axis_rx_ptp_ts_ready_reg;

assign s_axis_rx_hash_ready = s_axis_rx_hash_ready_reg;

assign s_axis_rx_csum_ready = s_axis_rx_csum_ready_reg;

wire pkt_table_free_ptr_valid;
wire [CL_PKT_TABLE_SIZE-1:0] pkt_table_free_ptr;

priority_encoder #(
    .WIDTH(PKT_TABLE_SIZE),
    .LSB_PRIORITY("HIGH")
)
pkt_table_free_enc_inst (
    .input_unencoded(~pkt_table_active),
    .output_valid(pkt_table_free_ptr_valid),
    .output_encoded(pkt_table_free_ptr),
    .output_unencoded()
);

// reg [15:0] stall_cnt = 0;
// wire stalled = stall_cnt[12];

// // assign dbg = stalled;

// always @(posedge clk) begin
//     if (rst) begin
//         stall_cnt <= 0;
//     end else begin
//         if (s_axis_rx_req_ready) begin
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
//     .probe0({desc_table_active, desc_table_rx_done, desc_table_invalid, desc_table_desc_fetched, desc_table_data_written, desc_table_cpl_write_done, pkt_table_active,
//         m_axis_dma_read_desc_len, m_axis_dma_read_desc_tag, m_axis_dma_read_desc_valid, m_axis_dma_read_desc_ready,
//         s_axis_dma_read_desc_status_tag, s_axis_dma_read_desc_status_valid,
//         m_axis_dma_write_desc_len, m_axis_dma_write_desc_tag, m_axis_dma_write_desc_valid, m_axis_dma_write_desc_ready,
//         s_axis_dma_write_desc_status_tag, s_axis_dma_write_desc_status_valid}),
//     .probe1(0),
//     .probe2(0),
//     .probe3(s_axis_rx_req_ready),
//     .probe4({desc_table_start_ptr_reg, desc_table_rx_finish_ptr, desc_table_desc_read_start_ptr_reg, desc_table_data_write_start_ptr_reg, desc_table_cpl_enqueue_start_ptr_reg, desc_table_finish_ptr_reg, stall_cnt}),
//     .probe5(0)
// );

always @* begin
    s_axis_rx_req_ready_next = 1'b0;

    m_axis_rx_req_status_len_next = m_axis_rx_req_status_len_reg;
    m_axis_rx_req_status_tag_next = m_axis_rx_req_status_tag_reg;
    m_axis_rx_req_status_valid_next = 1'b0;

    m_axis_desc_req_queue_next = m_axis_desc_req_queue_reg;
    m_axis_desc_req_tag_next = m_axis_desc_req_tag_reg;
    m_axis_desc_req_valid_next = m_axis_desc_req_valid_reg && !m_axis_desc_req_ready;

    s_axis_desc_tready_next = 1'b0;

    m_axis_cpl_req_queue_next = m_axis_cpl_req_queue_reg;
    m_axis_cpl_req_tag_next = m_axis_cpl_req_tag_reg;
    m_axis_cpl_req_data_next = m_axis_cpl_req_data_reg;
    m_axis_cpl_req_valid_next = m_axis_cpl_req_valid_reg && !m_axis_cpl_req_ready;

    m_axis_dma_write_desc_dma_addr_next = m_axis_dma_write_desc_dma_addr_reg;
    m_axis_dma_write_desc_ram_addr_next = m_axis_dma_write_desc_ram_addr_reg;
    m_axis_dma_write_desc_len_next = m_axis_dma_write_desc_len_reg;
    m_axis_dma_write_desc_tag_next = m_axis_dma_write_desc_tag_reg;
    m_axis_dma_write_desc_valid_next = m_axis_dma_write_desc_valid_reg && !m_axis_dma_write_desc_ready;

    m_axis_rx_desc_addr_next = m_axis_rx_desc_addr_reg;
    m_axis_rx_desc_len_next = m_axis_rx_desc_len_reg;
    m_axis_rx_desc_tag_next = m_axis_rx_desc_tag_reg;
    m_axis_rx_desc_valid_next = m_axis_rx_desc_valid_reg && !m_axis_rx_desc_ready;

    s_axis_rx_ptp_ts_ready_next = 1'b0;

    s_axis_rx_hash_ready_next = 1'b0;

    s_axis_rx_csum_ready_next = 1'b0;

    desc_table_start_tag = s_axis_rx_req_tag;
    desc_table_start_queue = s_axis_rx_req_queue;
    desc_table_start_pkt = pkt_table_free_ptr;
    desc_table_start_en = 1'b0;
    desc_table_rx_finish_ptr = s_axis_rx_desc_status_tag;
    desc_table_rx_finish_len = s_axis_rx_desc_status_len;
    desc_table_rx_finish_en = 1'b0;
    desc_table_dequeue_start_en = 1'b0;
    desc_table_dequeue_ptr = s_axis_desc_req_status_tag;
    desc_table_dequeue_queue_ptr = s_axis_desc_req_status_ptr;
    desc_table_dequeue_cpl_queue = s_axis_desc_req_status_cpl;
    desc_table_dequeue_invalid = 1'b0;
    desc_table_dequeue_en = 1'b0;
    desc_table_desc_fetched_ptr = s_axis_desc_tid & DESC_PTR_MASK;
    desc_table_desc_fetched_len = s_axis_desc_tdata[64:32];
    desc_table_desc_fetched_dma_addr = s_axis_desc_tdata[127:64];
    desc_table_desc_fetched_en = 1'b0;
    desc_table_data_write_start_en = 1'b0;
    desc_table_data_written_ptr = s_axis_dma_write_desc_status_tag & DESC_PTR_MASK;
    desc_table_data_written_en = 1'b0;
    desc_table_store_ptp_ts = s_axis_rx_ptp_ts_96;
    desc_table_store_ptp_ts_en = 1'b0;
    desc_table_store_hash = s_axis_rx_hash;
    desc_table_store_hash_type = s_axis_rx_hash_type;
    desc_table_store_hash_en = 1'b0;
    desc_table_store_csum = s_axis_rx_csum;
    desc_table_store_csum_en = 1'b0;
    desc_table_cpl_enqueue_start_en = 1'b0;
    desc_table_cpl_write_done_ptr = s_axis_cpl_req_status_tag & DESC_PTR_MASK;
    desc_table_cpl_write_done_en = 1'b0;
    desc_table_finish_en = 1'b0;

    pkt_table_start_ptr = pkt_table_free_ptr;
    pkt_table_start_en = 1'b0;
    pkt_table_finish_ptr = desc_table_pkt[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
    pkt_table_finish_en = 1'b0;

    // receive packet
    // wait for receive request
    s_axis_rx_req_ready_next = enable && pkt_table_free_ptr_valid && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE) && (!m_axis_rx_desc_valid_reg || m_axis_rx_desc_ready);
    if (s_axis_rx_req_ready && s_axis_rx_req_valid) begin
        s_axis_rx_req_ready_next = 1'b0;

        // store in descriptor table
        desc_table_start_tag = s_axis_rx_req_tag;
        desc_table_start_queue = s_axis_rx_req_queue;
        desc_table_start_pkt = pkt_table_free_ptr;
        desc_table_start_en = 1'b1;

        // store in packet table
        pkt_table_start_ptr = pkt_table_free_ptr;
        pkt_table_start_en = 1'b1;

        // initiate receive operation
        m_axis_rx_desc_addr_next = pkt_table_free_ptr << CL_MAX_RX_SIZE;
        m_axis_rx_desc_len_next = MAX_RX_SIZE;
        m_axis_rx_desc_tag_next = desc_table_start_ptr_reg & DESC_PTR_MASK;
        m_axis_rx_desc_valid_next = 1'b1;
    end

    // receive done
    // wait for receive completion
    if (s_axis_rx_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_rx_finish_ptr = s_axis_rx_desc_status_tag;
        desc_table_rx_finish_len = s_axis_rx_desc_status_len;
        desc_table_rx_finish_en = 1'b1;
    end

    // descriptor fetch
    if (desc_table_active[desc_table_dequeue_start_ptr_reg & DESC_PTR_MASK] && desc_table_dequeue_start_ptr_reg != desc_table_start_ptr_reg) begin
        if (desc_table_rx_done[desc_table_dequeue_start_ptr_reg & DESC_PTR_MASK] && !m_axis_desc_req_valid) begin
            // update entry in descriptor table
            desc_table_dequeue_start_en = 1'b1;

            // initiate descriptor fetch
            m_axis_desc_req_queue_next = desc_table_queue[desc_table_dequeue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_desc_req_tag_next = desc_table_dequeue_start_ptr_reg & DESC_PTR_MASK;
            m_axis_desc_req_valid_next = 1'b1;
        end
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
            // TODO retry if empty?

            // invalidate entry
            desc_table_dequeue_invalid = 1'b1;
        end else begin
            // descriptor available to dequeue

            // wait for descriptor
        end
    end

    // descriptor data write
    s_axis_desc_tready_next = 1'b1;
    if (s_axis_desc_tready && s_axis_desc_tvalid) begin
        // update entry in descriptor table
        desc_table_desc_fetched_ptr = s_axis_desc_tid & DESC_PTR_MASK;
        desc_table_desc_fetched_len = s_axis_desc_tdata[64:32];
        desc_table_desc_fetched_dma_addr = s_axis_desc_tdata[127:64];
        desc_table_desc_fetched_en = 1'b1;
    end

    // data write
    // wait for descriptor fetch completion
    // TODO descriptor validation?
    if (desc_table_active[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK] && desc_table_data_write_start_ptr_reg != desc_table_start_ptr_reg && desc_table_data_write_start_ptr_reg != desc_table_dequeue_start_ptr_reg) begin
        if (desc_table_invalid[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_data_write_start_en = 1'b1;
        end else if (desc_table_desc_fetched[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK] && !m_axis_dma_write_desc_valid_reg) begin
            // update entry in descriptor table
            desc_table_data_write_start_en = 1'b1;

            // initiate data write
            m_axis_dma_write_desc_dma_addr_next = desc_table_dma_addr[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK];
            m_axis_dma_write_desc_ram_addr_next = (desc_table_pkt[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK] & DESC_PTR_MASK) << CL_MAX_RX_SIZE;
            if (desc_table_desc_len[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK] < desc_table_dma_len[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK]) begin
                // limit write to length provided in descriptor
                m_axis_dma_write_desc_len_next = desc_table_desc_len[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK];
            end else begin
                // write actual packet length
                m_axis_dma_write_desc_len_next = desc_table_dma_len[desc_table_data_write_start_ptr_reg & DESC_PTR_MASK];
            end
            m_axis_dma_write_desc_tag_next = desc_table_data_write_start_ptr_reg & DESC_PTR_MASK;
            m_axis_dma_write_desc_valid_next = 1'b1;
        end
    end

    // data write completion
    // wait for data write completion
    if (s_axis_dma_write_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_data_written_ptr = s_axis_dma_write_desc_status_tag & DESC_PTR_MASK;
        desc_table_data_written_en = 1'b1;
    end

    // store PTP timestamp
    if (desc_table_active[desc_table_store_ptp_ts_ptr_reg & DESC_PTR_MASK] && desc_table_store_ptp_ts_ptr_reg != desc_table_start_ptr_reg && PTP_TS_ENABLE) begin
        s_axis_rx_ptp_ts_ready_next = 1'b1;
        if (desc_table_invalid[desc_table_store_ptp_ts_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_store_ptp_ts_en = 1'b1;

            s_axis_rx_ptp_ts_ready_next = 1'b0;
        end else if (s_axis_rx_ptp_ts_ready && s_axis_rx_ptp_ts_valid) begin
            // update entry in descriptor table
            desc_table_store_ptp_ts = s_axis_rx_ptp_ts_96;
            desc_table_store_ptp_ts_en = 1'b1;

            s_axis_rx_ptp_ts_ready_next = 1'b0;
        end
    end

    // store RX hash
    if (desc_table_active[desc_table_store_hash_ptr_reg & DESC_PTR_MASK] && desc_table_store_hash_ptr_reg != desc_table_start_ptr_reg && RX_HASH_ENABLE) begin
        s_axis_rx_hash_ready_next = 1'b1;
        if (desc_table_invalid[desc_table_store_hash_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_store_hash_en = 1'b1;

            s_axis_rx_hash_ready_next = 1'b0;
        end else if (s_axis_rx_hash_ready && s_axis_rx_hash_valid) begin
            // update entry in descriptor table
            desc_table_store_hash = s_axis_rx_hash;
            desc_table_store_hash_type = s_axis_rx_hash_type;
            desc_table_store_hash_en = 1'b1;

            s_axis_rx_hash_ready_next = 1'b0;
        end
    end

    // store RX checksum
    if (desc_table_active[desc_table_store_csum_ptr_reg & DESC_PTR_MASK] && desc_table_store_csum_ptr_reg != desc_table_start_ptr_reg && RX_CHECKSUM_ENABLE) begin
        s_axis_rx_csum_ready_next = 1'b1;
        if (desc_table_invalid[desc_table_store_csum_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_store_csum_en = 1'b1;

            s_axis_rx_csum_ready_next = 1'b0;
        end else if (s_axis_rx_csum_ready && s_axis_rx_csum_valid) begin
            // update entry in descriptor table
            desc_table_store_csum = s_axis_rx_csum;
            desc_table_store_csum_en = 1'b1;

            s_axis_rx_csum_ready_next = 1'b0;
        end
    end

    // finish write data; start completion enqueue
    if (desc_table_active[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] &&
            desc_table_cpl_enqueue_start_ptr_reg != desc_table_start_ptr_reg &&
            desc_table_cpl_enqueue_start_ptr_reg != desc_table_data_write_start_ptr_reg &&
            (desc_table_cpl_enqueue_start_ptr_reg != desc_table_store_ptp_ts_ptr_reg || !PTP_TS_ENABLE) &&
            (desc_table_cpl_enqueue_start_ptr_reg != desc_table_store_hash_ptr_reg || !RX_HASH_ENABLE) &&
            (desc_table_cpl_enqueue_start_ptr_reg != desc_table_store_csum_ptr_reg || !RX_CHECKSUM_ENABLE)) begin
        if (desc_table_invalid[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_cpl_enqueue_start_en = 1'b1;

            // invalidate entry in packet table
            pkt_table_finish_ptr = desc_table_pkt[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            pkt_table_finish_en = 1'b1;

        end else if (desc_table_data_written[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] && !m_axis_cpl_req_valid_next) begin
            // update entry in descriptor table
            desc_table_cpl_enqueue_start_en = 1'b1;

            // invalidate entry in packet table
            pkt_table_finish_ptr = desc_table_pkt[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            pkt_table_finish_en = 1'b1;

            // initiate completion write
            m_axis_cpl_req_queue_next = desc_table_cpl_queue[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_req_tag_next = desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK;
            m_axis_cpl_req_data_next = 0;
            m_axis_cpl_req_data_next[15:0]  = desc_table_queue[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_req_data_next[31:16] = desc_table_queue_ptr[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_req_data_next[47:32] = desc_table_dma_len[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            if (PTP_TS_ENABLE) begin
                //m_axis_cpl_req_data_next[127:64] = desc_table_ptp_ts[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] >> 16;
                m_axis_cpl_req_data_next[111:64] = desc_table_ptp_ts[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] >> 16;
            end
            if (RX_HASH_ENABLE) begin
                m_axis_cpl_req_data_next[159:128] = desc_table_hash[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
                m_axis_cpl_req_data_next[167:160] = desc_table_hash_type[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            end
            if (RX_CHECKSUM_ENABLE) begin
                m_axis_cpl_req_data_next[127:112] = desc_table_csum[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
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
    if (desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] && desc_table_finish_ptr_reg != desc_table_start_ptr_reg && desc_table_finish_ptr_reg != desc_table_cpl_enqueue_start_ptr_reg) begin
        if (desc_table_invalid[desc_table_finish_ptr_reg & DESC_PTR_MASK]) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            // return receive request completion
            m_axis_rx_req_status_len_next = 0;
            m_axis_rx_req_status_tag_next = desc_table_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_rx_req_status_valid_next = 1'b1;
        end else if (desc_table_cpl_write_done[desc_table_finish_ptr_reg & DESC_PTR_MASK]) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            // return receive request completion
            m_axis_rx_req_status_len_next = desc_table_dma_len[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_rx_req_status_tag_next = desc_table_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_rx_req_status_valid_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axis_rx_req_ready_reg <= 1'b0;
        m_axis_rx_req_status_valid_reg <= 1'b0;
        m_axis_desc_req_valid_reg <= 1'b0;
        s_axis_desc_tready_reg <= 1'b0;
        m_axis_cpl_req_valid_reg <= 1'b0;
        m_axis_dma_write_desc_valid_reg <= 1'b0;
        m_axis_rx_desc_valid_reg <= 1'b0;
        s_axis_rx_ptp_ts_ready_reg <= 1'b0;
        s_axis_rx_hash_ready_reg <= 1'b0;
        s_axis_rx_csum_ready_reg <= 1'b0;

        desc_table_active <= 0;
        desc_table_invalid <= 0;
        desc_table_desc_fetched <= 0;
        desc_table_data_written <= 0;
        desc_table_rx_done <= 0;

        desc_table_start_ptr_reg <= 0;
        desc_table_dequeue_start_ptr_reg <= 0;
        desc_table_data_write_start_ptr_reg <= 0;
        desc_table_store_ptp_ts_ptr_reg <= 0;
        desc_table_store_hash_ptr_reg <= 0;
        desc_table_store_csum_ptr_reg <= 0;
        desc_table_cpl_enqueue_start_ptr_reg <= 0;
        desc_table_finish_ptr_reg <= 0;

        pkt_table_active <= 0;
    end else begin
        s_axis_rx_req_ready_reg <= s_axis_rx_req_ready_next;
        m_axis_rx_req_status_valid_reg <= m_axis_rx_req_status_valid_next;
        m_axis_desc_req_valid_reg <= m_axis_desc_req_valid_next;
        s_axis_desc_tready_reg <= s_axis_desc_tready_next;
        m_axis_cpl_req_valid_reg <= m_axis_cpl_req_valid_next;
        m_axis_dma_write_desc_valid_reg <= m_axis_dma_write_desc_valid_next;
        m_axis_rx_desc_valid_reg <= m_axis_rx_desc_valid_next;
        s_axis_rx_ptp_ts_ready_reg <= s_axis_rx_ptp_ts_ready_next;
        s_axis_rx_hash_ready_reg <= s_axis_rx_hash_ready_next;
        s_axis_rx_csum_ready_reg <= s_axis_rx_csum_ready_next;
        
        if (desc_table_start_en) begin
            desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b1;
            desc_table_invalid[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_desc_fetched[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_data_written[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_rx_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_cpl_write_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_start_ptr_reg <= desc_table_start_ptr_reg + 1;
        end
        if (desc_table_rx_finish_en) begin
            desc_table_rx_done[desc_table_rx_finish_ptr & DESC_PTR_MASK] <= 1'b1;
        end
        if (desc_table_dequeue_start_en) begin
            desc_table_dequeue_start_ptr_reg <= desc_table_dequeue_start_ptr_reg + 1;
        end
        if (desc_table_dequeue_en) begin
            if (desc_table_dequeue_invalid) begin
                desc_table_invalid[desc_table_dequeue_ptr & DESC_PTR_MASK] <= 1'b1;
            end
        end
        if (desc_table_desc_fetched_en) begin
            desc_table_desc_fetched[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= 1'b1;
        end
        if (desc_table_data_write_start_en) begin
            desc_table_data_write_start_ptr_reg <= desc_table_data_write_start_ptr_reg + 1;
        end
        if (desc_table_data_written_en) begin
            desc_table_data_written[desc_table_data_written_ptr & DESC_PTR_MASK] <= 1'b1;
        end
        if (desc_table_store_ptp_ts_en) begin
            desc_table_store_ptp_ts_ptr_reg <= desc_table_store_ptp_ts_ptr_reg + 1;
        end
        if (desc_table_store_hash_en) begin
            desc_table_store_hash_ptr_reg <= desc_table_store_hash_ptr_reg + 1;
        end
        if (desc_table_store_csum_en) begin
            desc_table_store_csum_ptr_reg <= desc_table_store_csum_ptr_reg + 1;
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

        if (pkt_table_start_en) begin
            pkt_table_active[pkt_table_start_ptr] <= 1'b1;
        end
        if (pkt_table_finish_en) begin
            pkt_table_active[pkt_table_finish_ptr] <= 1'b0;
        end
    end

    m_axis_rx_req_status_len_reg <= m_axis_rx_req_status_len_next;
    m_axis_rx_req_status_tag_reg <= m_axis_rx_req_status_tag_next;

    m_axis_desc_req_queue_reg <= m_axis_desc_req_queue_next;
    m_axis_desc_req_tag_reg <= m_axis_desc_req_tag_next;

    m_axis_cpl_req_queue_reg <= m_axis_cpl_req_queue_next;
    m_axis_cpl_req_tag_reg <= m_axis_cpl_req_tag_next;
    m_axis_cpl_req_data_reg <= m_axis_cpl_req_data_next;

    m_axis_dma_write_desc_dma_addr_reg <= m_axis_dma_write_desc_dma_addr_next;
    m_axis_dma_write_desc_ram_addr_reg <= m_axis_dma_write_desc_ram_addr_next;
    m_axis_dma_write_desc_len_reg <= m_axis_dma_write_desc_len_next;
    m_axis_dma_write_desc_tag_reg <= m_axis_dma_write_desc_tag_next;

    m_axis_rx_desc_addr_reg <= m_axis_rx_desc_addr_next;
    m_axis_rx_desc_len_reg <= m_axis_rx_desc_len_next;
    m_axis_rx_desc_tag_reg <= m_axis_rx_desc_tag_next;

    if (desc_table_start_en) begin
        desc_table_queue[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_queue;
        desc_table_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_tag;
        desc_table_pkt[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_pkt;
    end
    if (desc_table_rx_finish_en) begin
        desc_table_dma_len[desc_table_rx_finish_ptr & DESC_PTR_MASK] <= desc_table_rx_finish_len;
    end
    if (desc_table_dequeue_en) begin
        desc_table_queue_ptr[desc_table_dequeue_ptr & DESC_PTR_MASK] <= desc_table_dequeue_queue_ptr;
        desc_table_cpl_queue[desc_table_dequeue_ptr & DESC_PTR_MASK] <= desc_table_dequeue_cpl_queue;
    end
    if (desc_table_desc_fetched_en) begin
        desc_table_desc_len[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= desc_table_desc_fetched_len;
        desc_table_dma_addr[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= desc_table_desc_fetched_dma_addr;
    end
    if (desc_table_store_ptp_ts_en) begin
        desc_table_ptp_ts[desc_table_store_ptp_ts_ptr_reg & DESC_PTR_MASK] <= desc_table_store_ptp_ts;
    end
    if (desc_table_store_hash_en) begin
        desc_table_hash[desc_table_store_hash_ptr_reg & DESC_PTR_MASK] <= desc_table_store_hash;
        desc_table_hash_type[desc_table_store_hash_ptr_reg & DESC_PTR_MASK] <= desc_table_store_hash_type;
    end
    if (desc_table_store_csum_en) begin
        desc_table_csum[desc_table_store_csum_ptr_reg & DESC_PTR_MASK] <= desc_table_store_csum;
    end
end

endmodule
