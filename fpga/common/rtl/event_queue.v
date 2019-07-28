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
 * Event queue
 */
module event_queue #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 256,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // PCIe DMA length field width
    parameter PCIE_DMA_LEN_WIDTH = 20,
    // PCIe DMA tag field width
    parameter PCIE_DMA_TAG_WIDTH = 8,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 4,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Event type field width
    parameter EVENT_TYPE_WIDTH = 16,
    // Event source field width
    parameter EVENT_SOURCE_WIDTH = 16,
    // Event table size (number of in-flight operations)
    parameter EVENT_TABLE_SIZE = 8,
    // AXI base address of this module (as seen by PCIe DMA)
    parameter AXI_BASE_ADDR = 16'h0000
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * Transmit request input (queue index)
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]     s_axis_event_queue,
    input  wire [EVENT_TYPE_WIDTH-1:0]      s_axis_event_type,
    input  wire [EVENT_SOURCE_WIDTH-1:0]    s_axis_event_source,
    input  wire                             s_axis_event_valid,
    output wire                             s_axis_event_ready,

    /*
     * Completion enqueue request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]     m_axis_event_enqueue_req_queue,
    output wire [QUEUE_REQ_TAG_WIDTH-1:0]   m_axis_event_enqueue_req_tag,
    output wire                             m_axis_event_enqueue_req_valid,
    input  wire                             m_axis_event_enqueue_req_ready,

    /*
     * Completion enqueue response input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]       s_axis_event_enqueue_resp_addr,
    input  wire [QUEUE_REQ_TAG_WIDTH-1:0]   s_axis_event_enqueue_resp_tag,
    input  wire [QUEUE_OP_TAG_WIDTH-1:0]    s_axis_event_enqueue_resp_op_tag,
    input  wire                             s_axis_event_enqueue_resp_full,
    input  wire                             s_axis_event_enqueue_resp_error,
    input  wire                             s_axis_event_enqueue_resp_valid,
    output wire                             s_axis_event_enqueue_resp_ready,

    /*
     * Completion enqueue commit output
     */
    output wire [QUEUE_OP_TAG_WIDTH-1:0]    m_axis_event_enqueue_commit_op_tag,
    output wire                             m_axis_event_enqueue_commit_valid,
    input  wire                             m_axis_event_enqueue_commit_ready,

    /*
     * PCIe AXI DMA write descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]       m_axis_pcie_axi_dma_write_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]        m_axis_pcie_axi_dma_write_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]    m_axis_pcie_axi_dma_write_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]    m_axis_pcie_axi_dma_write_desc_tag,
    output wire                             m_axis_pcie_axi_dma_write_desc_valid,
    input  wire                             m_axis_pcie_axi_dma_write_desc_ready,

    /*
     * PCIe AXI DMA write descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]    s_axis_pcie_axi_dma_write_desc_status_tag,
    input  wire                             s_axis_pcie_axi_dma_write_desc_status_valid,

    /*
     * AXI slave interface
     */
    input  wire [AXI_ID_WIDTH-1:0]          s_axi_awid,
    input  wire [AXI_ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire [7:0]                       s_axi_awlen,
    input  wire [2:0]                       s_axi_awsize,
    input  wire [1:0]                       s_axi_awburst,
    input  wire                             s_axi_awlock,
    input  wire [3:0]                       s_axi_awcache,
    input  wire [2:0]                       s_axi_awprot,
    input  wire                             s_axi_awvalid,
    output wire                             s_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire [AXI_STRB_WIDTH-1:0]        s_axi_wstrb,
    input  wire                             s_axi_wlast,
    input  wire                             s_axi_wvalid,
    output wire                             s_axi_wready,
    output wire [AXI_ID_WIDTH-1:0]          s_axi_bid,
    output wire [1:0]                       s_axi_bresp,
    output wire                             s_axi_bvalid,
    input  wire                             s_axi_bready,
    input  wire [AXI_ID_WIDTH-1:0]          s_axi_arid,
    input  wire [AXI_ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire [7:0]                       s_axi_arlen,
    input  wire [2:0]                       s_axi_arsize,
    input  wire [1:0]                       s_axi_arburst,
    input  wire                             s_axi_arlock,
    input  wire [3:0]                       s_axi_arcache,
    input  wire [2:0]                       s_axi_arprot,
    input  wire                             s_axi_arvalid,
    output wire                             s_axi_arready,
    output wire [AXI_ID_WIDTH-1:0]          s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]        s_axi_rdata,
    output wire [1:0]                       s_axi_rresp,
    output wire                             s_axi_rlast,
    output wire                             s_axi_rvalid,
    input  wire                             s_axi_rready,

    /*
     * Configuration
     */
    input  wire                             enable
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);

parameter CL_EVENT_TABLE_SIZE = $clog2(EVENT_TABLE_SIZE);
parameter EVENT_PTR_MASK = {CL_EVENT_TABLE_SIZE{1'b1}};

parameter EVENT_SIZE = 32;

// bus width assertions
initial begin
    if (PCIE_DMA_TAG_WIDTH < CL_EVENT_TABLE_SIZE+1) begin
        $error("Error: PCIe tag width insufficient for event table size (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH * 8 != AXI_DATA_WIDTH) begin
        $error("Error: AXI interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH < EVENT_SIZE) begin
        $error("Error: AXI interface width must be at least as large as one event record (instance %m)");
        $finish;
    end

    if (AXI_BASE_ADDR[$clog2(AXI_STRB_WIDTH)-1:0]) begin
        $error("Error: AXI base address must be aligned to interface width (instance %m)");
        $finish;
    end
end

reg s_axis_event_ready_reg = 1'b0, s_axis_event_ready_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_event_enqueue_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_event_enqueue_req_queue_next;
reg [QUEUE_REQ_TAG_WIDTH-1:0] m_axis_event_enqueue_req_tag_reg = {QUEUE_REQ_TAG_WIDTH{1'b0}}, m_axis_event_enqueue_req_tag_next;
reg m_axis_event_enqueue_req_valid_reg = 1'b0, m_axis_event_enqueue_req_valid_next;

reg s_axis_event_enqueue_resp_ready_reg = 1'b0, s_axis_event_enqueue_resp_ready_next;

reg [QUEUE_OP_TAG_WIDTH-1:0] m_axis_event_enqueue_commit_op_tag_reg = {QUEUE_OP_TAG_WIDTH{1'b0}}, m_axis_event_enqueue_commit_op_tag_next;
reg m_axis_event_enqueue_commit_valid_reg = 1'b0, m_axis_event_enqueue_commit_valid_next;

reg [PCIE_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_axi_addr_next;
reg [PCIE_DMA_LEN_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_len_reg = {PCIE_DMA_LEN_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_len_next;
reg [PCIE_DMA_TAG_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_tag_reg = {PCIE_DMA_TAG_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_tag_next;
reg m_axis_pcie_axi_dma_write_desc_valid_reg = 1'b0, m_axis_pcie_axi_dma_write_desc_valid_next;

reg [EVENT_TABLE_SIZE-1:0] event_table_active = 0;
reg [EVENT_TABLE_SIZE-1:0] event_table_invalid = 0;
reg [EVENT_TABLE_SIZE-1:0] event_table_write_done = 0;
reg [EVENT_TYPE_WIDTH-1:0] event_table_type[EVENT_TABLE_SIZE-1:0];
reg [EVENT_SOURCE_WIDTH-1:0] event_table_source[EVENT_TABLE_SIZE-1:0];
reg [QUEUE_OP_TAG_WIDTH-1:0] event_table_queue_op_tag[EVENT_TABLE_SIZE-1:0];

reg [CL_EVENT_TABLE_SIZE+1-1:0] event_table_start_ptr_reg = 0;
reg [EVENT_TYPE_WIDTH-1:0] event_table_start_type;
reg [EVENT_SOURCE_WIDTH-1:0] event_table_start_source;
reg event_table_start_en;
reg [CL_EVENT_TABLE_SIZE-1:0] event_table_write_ptr;
reg [QUEUE_OP_TAG_WIDTH-1:0] event_table_write_queue_op_tag;
reg event_table_write_invalid;
reg event_table_write_en;
reg [CL_EVENT_TABLE_SIZE-1:0] event_table_write_done_ptr;
reg event_table_write_done_en;
reg [CL_EVENT_TABLE_SIZE+1-1:0] event_table_finish_ptr_reg = 0;
reg event_table_finish_en;

assign s_axis_event_ready = s_axis_event_ready_reg;

assign m_axis_event_enqueue_req_queue = m_axis_event_enqueue_req_queue_reg;
assign m_axis_event_enqueue_req_tag = m_axis_event_enqueue_req_tag_reg;
assign m_axis_event_enqueue_req_valid = m_axis_event_enqueue_req_valid_reg;

assign s_axis_event_enqueue_resp_ready = s_axis_event_enqueue_resp_ready_reg;

assign m_axis_event_enqueue_commit_op_tag = m_axis_event_enqueue_commit_op_tag_reg;
assign m_axis_event_enqueue_commit_valid = m_axis_event_enqueue_commit_valid_reg;

assign m_axis_pcie_axi_dma_write_desc_pcie_addr = m_axis_pcie_axi_dma_write_desc_pcie_addr_reg;
assign m_axis_pcie_axi_dma_write_desc_axi_addr = m_axis_pcie_axi_dma_write_desc_axi_addr_reg;
assign m_axis_pcie_axi_dma_write_desc_len = m_axis_pcie_axi_dma_write_desc_len_reg;
assign m_axis_pcie_axi_dma_write_desc_tag = m_axis_pcie_axi_dma_write_desc_tag_reg;
assign m_axis_pcie_axi_dma_write_desc_valid = m_axis_pcie_axi_dma_write_desc_valid_reg;

wire [AXI_ID_WIDTH-1:0]   ram_rd_cmd_id;
wire [AXI_ADDR_WIDTH-1:0] ram_rd_cmd_addr;
wire                      ram_rd_cmd_en;
wire                      ram_rd_cmd_last;
reg                       ram_rd_cmd_ready_reg = 1'b0;
reg  [AXI_ID_WIDTH-1:0]   ram_rd_resp_id_reg = {AXI_ID_WIDTH{1'b0}};
reg  [AXI_DATA_WIDTH-1:0] ram_rd_resp_data_reg = {AXI_DATA_WIDTH{1'b0}};
reg                       ram_rd_resp_last_reg = 1'b0;
reg                       ram_rd_resp_valid_reg = 1'b0;
wire                      ram_rd_resp_ready;

axi_ram_wr_if #(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .STRB_WIDTH(AXI_STRB_WIDTH),
    .ID_WIDTH(AXI_ID_WIDTH),
    .AWUSER_ENABLE(0),
    .WUSER_ENABLE(0),
    .BUSER_ENABLE(0)
)
axi_ram_wr_if_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awqos(0),
    .s_axi_awregion(0),
    .s_axi_awuser(0),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wuser(0),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_buser(),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .ram_wr_cmd_id(),
    .ram_wr_cmd_addr(),
    .ram_wr_cmd_lock(),
    .ram_wr_cmd_cache(),
    .ram_wr_cmd_prot(),
    .ram_wr_cmd_qos(),
    .ram_wr_cmd_region(),
    .ram_wr_cmd_auser(),
    .ram_wr_cmd_data(),
    .ram_wr_cmd_strb(),
    .ram_wr_cmd_user(),
    .ram_wr_cmd_en(),
    .ram_wr_cmd_last(),
    .ram_wr_cmd_ready(1'b1)
);

axi_ram_rd_if #(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .STRB_WIDTH(AXI_STRB_WIDTH),
    .ID_WIDTH(AXI_ID_WIDTH),
    .ARUSER_ENABLE(0),
    .RUSER_ENABLE(0),
    .PIPELINE_OUTPUT(0)
)
axi_ram_rd_if_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arqos(0),
    .s_axi_arregion(0),
    .s_axi_aruser(0),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_ruser(),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .ram_rd_cmd_id(ram_rd_cmd_id),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_lock(),
    .ram_rd_cmd_cache(),
    .ram_rd_cmd_prot(),
    .ram_rd_cmd_qos(),
    .ram_rd_cmd_region(),
    .ram_rd_cmd_auser(),
    .ram_rd_cmd_en(ram_rd_cmd_en),
    .ram_rd_cmd_last(ram_rd_cmd_last),
    .ram_rd_cmd_ready(ram_rd_cmd_ready_reg),
    .ram_rd_resp_id(ram_rd_resp_id_reg),
    .ram_rd_resp_data(ram_rd_resp_data_reg),
    .ram_rd_resp_last(ram_rd_resp_last_reg),
    .ram_rd_resp_user(0),
    .ram_rd_resp_valid(ram_rd_resp_valid_reg),
    .ram_rd_resp_ready(ram_rd_resp_ready)
);

always @(posedge clk) begin
    ram_rd_resp_valid_reg <= ram_rd_resp_valid_reg && !ram_rd_resp_ready;
    ram_rd_cmd_ready_reg <= !ram_rd_resp_valid_reg || ram_rd_resp_ready;

    if (ram_rd_cmd_en && ram_rd_cmd_ready_reg) begin
        // AXI read
        ram_rd_resp_id_reg <= ram_rd_cmd_id;
        ram_rd_resp_data_reg <= 0;
        ram_rd_resp_last_reg <= ram_rd_cmd_last;
        ram_rd_resp_valid_reg <= 1'b1;
        ram_rd_cmd_ready_reg <= ram_rd_resp_ready;

        ram_rd_resp_data_reg[15:0] <= event_table_type[ram_rd_cmd_addr[(CL_EVENT_TABLE_SIZE+5)-1:5]];
        ram_rd_resp_data_reg[31:16] <= event_table_source[ram_rd_cmd_addr[(CL_EVENT_TABLE_SIZE+5)-1:5]];
    end

    if (rst) begin
        ram_rd_cmd_ready_reg <= 1'b1;
        ram_rd_resp_valid_reg <= 1'b0;
    end
end

always @* begin
    s_axis_event_ready_next = 1'b0;

    m_axis_event_enqueue_req_queue_next = m_axis_event_enqueue_req_queue_reg;
    m_axis_event_enqueue_req_tag_next = m_axis_event_enqueue_req_tag_reg;
    m_axis_event_enqueue_req_valid_next = m_axis_event_enqueue_req_valid_reg && !m_axis_event_enqueue_req_ready;

    s_axis_event_enqueue_resp_ready_next = 1'b0;

    m_axis_event_enqueue_commit_op_tag_next = m_axis_event_enqueue_commit_op_tag_reg;
    m_axis_event_enqueue_commit_valid_next = m_axis_event_enqueue_commit_valid_reg && !m_axis_event_enqueue_commit_ready;

    m_axis_pcie_axi_dma_write_desc_pcie_addr_next = m_axis_pcie_axi_dma_write_desc_pcie_addr_reg;
    m_axis_pcie_axi_dma_write_desc_axi_addr_next = m_axis_pcie_axi_dma_write_desc_axi_addr_reg;
    m_axis_pcie_axi_dma_write_desc_len_next = m_axis_pcie_axi_dma_write_desc_len_reg;
    m_axis_pcie_axi_dma_write_desc_tag_next = m_axis_pcie_axi_dma_write_desc_tag_reg;
    m_axis_pcie_axi_dma_write_desc_valid_next = m_axis_pcie_axi_dma_write_desc_valid_reg && !m_axis_pcie_axi_dma_write_desc_ready;

    event_table_start_type = s_axis_event_type;
    event_table_start_source = s_axis_event_source;
    event_table_start_en = 1'b0;
    event_table_write_ptr = s_axis_event_enqueue_resp_tag & EVENT_PTR_MASK;
    event_table_write_queue_op_tag = 0;
    event_table_write_invalid = 1'b0;
    event_table_write_en = 1'b0;
    event_table_write_done_ptr = s_axis_pcie_axi_dma_write_desc_status_tag & EVENT_PTR_MASK;
    event_table_write_done_en = 1'b0;
    event_table_finish_en = 1'b0;

    // wait for event
    s_axis_event_ready_next = enable && !m_axis_event_enqueue_req_valid_next && !event_table_active[event_table_start_ptr_reg & EVENT_PTR_MASK] && ($unsigned(event_table_start_ptr_reg - event_table_finish_ptr_reg) < EVENT_TABLE_SIZE);
    if (s_axis_event_ready && s_axis_event_valid) begin
        s_axis_event_ready_next = 1'b0;

        // store in descriptor table
        event_table_start_type = s_axis_event_type;
        event_table_start_source = s_axis_event_source;
        event_table_start_en = 1'b1;

        // initiate queue query
        m_axis_event_enqueue_req_queue_next = s_axis_event_queue;
        m_axis_event_enqueue_req_tag_next = event_table_start_ptr_reg & EVENT_PTR_MASK;
        m_axis_event_enqueue_req_valid_next = 1'b1;
    end

    // start event write
    // wait for queue query response
    s_axis_event_enqueue_resp_ready_next = !m_axis_pcie_axi_dma_write_desc_valid_reg;
    if (s_axis_event_enqueue_resp_ready && s_axis_event_enqueue_resp_valid) begin
        s_axis_event_enqueue_resp_ready_next = 1'b0;

        // update entry in descriptor table
        event_table_write_ptr = s_axis_event_enqueue_resp_tag & EVENT_PTR_MASK;
        event_table_write_queue_op_tag = s_axis_event_enqueue_resp_op_tag;
        event_table_write_invalid = 1'b0;
        event_table_write_en = 1'b1;

        if (s_axis_event_enqueue_resp_error || s_axis_event_enqueue_resp_full) begin
            // queue full or not active
            // TODO retry if queue full?

            // invalidate entry
            event_table_write_invalid = 1'b1;
        end else begin
            // space for completion available in queue

            // initiate completion write from onboard RAM
            m_axis_pcie_axi_dma_write_desc_pcie_addr_next = s_axis_event_enqueue_resp_addr;
            m_axis_pcie_axi_dma_write_desc_axi_addr_next = AXI_BASE_ADDR + ((s_axis_event_enqueue_resp_tag & EVENT_PTR_MASK) << 5);
            m_axis_pcie_axi_dma_write_desc_len_next = EVENT_SIZE;
            m_axis_pcie_axi_dma_write_desc_tag_next = s_axis_event_enqueue_resp_tag & EVENT_PTR_MASK;
            m_axis_pcie_axi_dma_write_desc_valid_next = 1'b1;
        end
    end

    // finish event write
    if (s_axis_pcie_axi_dma_write_desc_status_valid) begin
        // update entry in descriptor table
        event_table_write_done_ptr = s_axis_pcie_axi_dma_write_desc_status_tag & EVENT_PTR_MASK;
        event_table_write_done_en = 1'b1;
    end

    // operation complete
    if (event_table_active[event_table_finish_ptr_reg & EVENT_PTR_MASK] && event_table_finish_ptr_reg != event_table_start_ptr_reg) begin
        if (event_table_invalid[event_table_finish_ptr_reg & EVENT_PTR_MASK]) begin
            // invalidate entry in descriptor table
            event_table_finish_en = 1'b1;

        end else if (event_table_write_done[event_table_finish_ptr_reg & EVENT_PTR_MASK] && !m_axis_event_enqueue_commit_valid) begin
            // invalidate entry in descriptor table
            event_table_finish_en = 1'b1;

            // commit enqueue operation
            m_axis_event_enqueue_commit_op_tag_next = event_table_queue_op_tag[event_table_finish_ptr_reg & EVENT_PTR_MASK];
            m_axis_event_enqueue_commit_valid_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axis_event_ready_reg <= 1'b0;
        m_axis_event_enqueue_req_valid_reg <= 1'b0;
        s_axis_event_enqueue_resp_ready_reg <= 1'b0;
        m_axis_event_enqueue_commit_valid_reg <= 1'b0;
        m_axis_pcie_axi_dma_write_desc_valid_reg <= 1'b0;

        event_table_active <= 0;
        event_table_invalid <= 0;

        event_table_start_ptr_reg <= 0;
        event_table_finish_ptr_reg <= 0;
    end else begin
        s_axis_event_ready_reg <= s_axis_event_ready_next;
        m_axis_event_enqueue_req_valid_reg <= m_axis_event_enqueue_req_valid_next;
        s_axis_event_enqueue_resp_ready_reg <= s_axis_event_enqueue_resp_ready_next;
        m_axis_event_enqueue_commit_valid_reg <= m_axis_event_enqueue_commit_valid_next;
        m_axis_pcie_axi_dma_write_desc_valid_reg <= m_axis_pcie_axi_dma_write_desc_valid_next;

        if (event_table_start_en) begin
            event_table_active[event_table_start_ptr_reg & EVENT_PTR_MASK] <= 1'b1;
            event_table_invalid[event_table_start_ptr_reg & EVENT_PTR_MASK] <= 1'b0;
            event_table_write_done[event_table_start_ptr_reg & EVENT_PTR_MASK] <= 1'b0;
            event_table_start_ptr_reg <= event_table_start_ptr_reg + 1;
        end
        if (event_table_write_en) begin
            if (event_table_write_invalid) begin
                event_table_invalid[event_table_write_ptr & EVENT_PTR_MASK] <= 1'b1;
            end
        end
        if (event_table_write_done_en) begin
            event_table_write_done[event_table_write_done_ptr & EVENT_PTR_MASK] <= 1'b1;
        end
        if (event_table_finish_en) begin
            event_table_active[event_table_finish_ptr_reg & EVENT_PTR_MASK] <= 1'b0;
            event_table_finish_ptr_reg <= event_table_finish_ptr_reg + 1;
        end
    end

    m_axis_event_enqueue_req_queue_reg <= m_axis_event_enqueue_req_queue_next;
    m_axis_event_enqueue_req_tag_reg <= m_axis_event_enqueue_req_tag_next;
    m_axis_event_enqueue_commit_op_tag_reg <= m_axis_event_enqueue_commit_op_tag_next;

    m_axis_pcie_axi_dma_write_desc_pcie_addr_reg <= m_axis_pcie_axi_dma_write_desc_pcie_addr_next;
    m_axis_pcie_axi_dma_write_desc_axi_addr_reg <= m_axis_pcie_axi_dma_write_desc_axi_addr_next;
    m_axis_pcie_axi_dma_write_desc_len_reg <= m_axis_pcie_axi_dma_write_desc_len_next;
    m_axis_pcie_axi_dma_write_desc_tag_reg <= m_axis_pcie_axi_dma_write_desc_tag_next;

    if (event_table_start_en) begin
        event_table_type[event_table_start_ptr_reg & EVENT_PTR_MASK] <= event_table_start_type;
        event_table_source[event_table_start_ptr_reg & EVENT_PTR_MASK] <= event_table_start_source;
    end
    if (event_table_write_en) begin
        event_table_queue_op_tag[event_table_write_ptr & EVENT_PTR_MASK] <= event_table_write_queue_op_tag;
    end
end

endmodule
