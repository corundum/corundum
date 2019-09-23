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
 * Descriptor fetch module
 */
module desc_fetch #
(
    // Number of ports
    parameter PORTS = 2,
    // Select field width
    parameter SELECT_WIDTH = $clog2(PORTS),
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 256,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Width of AXI stream interface in bits
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXI_STRB_WIDTH,
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // PCIe DMA length field width
    parameter PCIE_DMA_LEN_WIDTH = 20,
    // PCIe DMA tag field width
    parameter PCIE_DMA_TAG_WIDTH = 8,
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
    // Descriptor table size (number of in-flight operations)
    parameter DESC_TABLE_SIZE = 8,
    // AXI base address of this module (as seen by PCIe DMA)
    parameter AXI_BASE_ADDR = 16'h0000
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
    input  wire [PORTS*PCIE_ADDR_WIDTH-1:0]       s_axis_desc_dequeue_resp_addr,
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
     * PCIe AXI DMA read descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]             m_axis_pcie_axi_dma_read_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]              m_axis_pcie_axi_dma_read_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]          m_axis_pcie_axi_dma_read_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]          m_axis_pcie_axi_dma_read_desc_tag,
    output wire                                   m_axis_pcie_axi_dma_read_desc_valid,
    input  wire                                   m_axis_pcie_axi_dma_read_desc_ready,

    /*
     * PCIe AXI DMA read descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]          s_axis_pcie_axi_dma_read_desc_status_tag,
    input  wire                                   s_axis_pcie_axi_dma_read_desc_status_valid,

    /*
     * AXI slave interface (write)
     */
    input  wire [AXI_ID_WIDTH-1:0]                s_axi_awid,
    input  wire [AXI_ADDR_WIDTH-1:0]              s_axi_awaddr,
    input  wire [7:0]                             s_axi_awlen,
    input  wire [2:0]                             s_axi_awsize,
    input  wire [1:0]                             s_axi_awburst,
    input  wire                                   s_axi_awlock,
    input  wire [3:0]                             s_axi_awcache,
    input  wire [2:0]                             s_axi_awprot,
    input  wire                                   s_axi_awvalid,
    output wire                                   s_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]              s_axi_wdata,
    input  wire [AXI_STRB_WIDTH-1:0]              s_axi_wstrb,
    input  wire                                   s_axi_wlast,
    input  wire                                   s_axi_wvalid,
    output wire                                   s_axi_wready,
    output wire [AXI_ID_WIDTH-1:0]                s_axi_bid,
    output wire [1:0]                             s_axi_bresp,
    output wire                                   s_axi_bvalid,
    input  wire                                   s_axi_bready,

    /*
     * Configuration
     */
    input  wire                                   enable
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);

parameter CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
parameter DESC_PTR_MASK = {CL_DESC_TABLE_SIZE{1'b1}};

parameter CL_PORTS = $clog2(PORTS);

// bus width assertions
initial begin
    if (PCIE_DMA_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: PCIe tag width insufficient for descriptor table size (instance %m)");
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

    if (AXI_STRB_WIDTH * 8 != AXI_DATA_WIDTH) begin
        $error("Error: AXI interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH < DESC_SIZE) begin
        $error("Error: AXI interface width must be at least as large as one descriptor (instance %m)");
        $finish;
    end

    if (AXI_BASE_ADDR[$clog2(AXI_STRB_WIDTH)-1:0]) begin
        $error("Error: AXI base address must be aligned to interface width (instance %m)");
        $finish;
    end

    if (AXIS_DATA_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: AXI stream interface width must match AXI interface width (instance %m)");
        $finish;
    end

    if (AXIS_KEEP_WIDTH * 8 != AXIS_DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
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

reg [AXIS_DATA_WIDTH-1:0] m_axis_desc_tdata_reg = {AXIS_DATA_WIDTH{1'b0}}, m_axis_desc_tdata_next;
reg [AXIS_KEEP_WIDTH-1:0] m_axis_desc_tkeep_reg = {AXIS_KEEP_WIDTH{1'b0}}, m_axis_desc_tkeep_next;
reg m_axis_desc_tvalid_reg = 1'b0, m_axis_desc_tvalid_next;
reg m_axis_desc_tlast_reg = 1'b0, m_axis_desc_tlast_next;
reg [REQ_TAG_WIDTH-1:0] m_axis_desc_tid_reg = {REQ_TAG_WIDTH{1'b0}}, m_axis_desc_tid_next;
reg m_axis_desc_tuser_reg = 1'b0, m_axis_desc_tuser_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_desc_dequeue_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_desc_dequeue_req_queue_next;
reg [QUEUE_REQ_TAG_WIDTH-1:0] m_axis_desc_dequeue_req_tag_reg = {QUEUE_REQ_TAG_WIDTH{1'b0}}, m_axis_desc_dequeue_req_tag_next;
reg [PORTS-1:0] m_axis_desc_dequeue_req_valid_reg = {PORTS{1'b0}}, m_axis_desc_dequeue_req_valid_next;

reg [PORTS-1:0] s_axis_desc_dequeue_resp_ready_reg = {PORTS{1'b0}}, s_axis_desc_dequeue_resp_ready_next;

reg [QUEUE_OP_TAG_WIDTH-1:0] m_axis_desc_dequeue_commit_op_tag_reg = {QUEUE_OP_TAG_WIDTH{1'b0}}, m_axis_desc_dequeue_commit_op_tag_next;
reg [PORTS-1:0] m_axis_desc_dequeue_commit_valid_reg = {PORTS{1'b0}}, m_axis_desc_dequeue_commit_valid_next;

reg [PCIE_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_axi_addr_next;
reg [PCIE_DMA_LEN_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_len_reg = {PCIE_DMA_LEN_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_len_next;
reg [PCIE_DMA_TAG_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_tag_reg = {PCIE_DMA_TAG_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_tag_next;
reg m_axis_pcie_axi_dma_read_desc_valid_reg = 1'b0, m_axis_pcie_axi_dma_read_desc_valid_next;

reg [CL_DESC_TABLE_SIZE+1-1:0] active_count_reg = 0;
reg inc_active;
reg dec_active_1;
reg dec_active_2;

reg [DESC_TABLE_SIZE-1:0] desc_table_active = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_desc_fetched = 0;
reg [CL_PORTS-1:0] desc_table_sel[DESC_TABLE_SIZE-1:0];
reg [REQ_TAG_WIDTH-1:0] desc_table_tag[DESC_TABLE_SIZE-1:0];
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_queue_op_tag[DESC_TABLE_SIZE-1:0];
reg [DESC_SIZE*8-1:0] desc_table_data[DESC_TABLE_SIZE-1:0];

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr_reg = 0;
reg [CL_PORTS-1:0] desc_table_start_sel;
reg [REQ_TAG_WIDTH-1:0] desc_table_start_tag;
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_start_queue_op_tag;
reg desc_table_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_desc_fetched_ptr;
reg desc_table_desc_fetched_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_finish_ptr_reg = 0;
reg desc_table_finish_en;

assign s_axis_req_ready = s_axis_req_ready_reg;

assign m_axis_req_status_queue = m_axis_req_status_queue_reg;
assign m_axis_req_status_ptr = m_axis_req_status_ptr_reg;
assign m_axis_req_status_cpl = m_axis_req_status_cpl_reg;
assign m_axis_req_status_tag = m_axis_req_status_tag_reg;
assign m_axis_req_status_empty = m_axis_req_status_empty_reg;
assign m_axis_req_status_error = m_axis_req_status_error_reg;
assign m_axis_req_status_valid = m_axis_req_status_valid_reg;

assign m_axis_desc_tdata = m_axis_desc_tdata_reg;
assign m_axis_desc_tkeep = m_axis_desc_tkeep_reg;
assign m_axis_desc_tvalid = m_axis_desc_tvalid_reg;
assign m_axis_desc_tlast = m_axis_desc_tlast_reg;
assign m_axis_desc_tid = m_axis_desc_tid_reg;
assign m_axis_desc_tuser = m_axis_desc_tuser_reg;

assign m_axis_desc_dequeue_req_queue = {PORTS{m_axis_desc_dequeue_req_queue_reg}};
assign m_axis_desc_dequeue_req_tag = {PORTS{m_axis_desc_dequeue_req_tag_reg}};
assign m_axis_desc_dequeue_req_valid = m_axis_desc_dequeue_req_valid_reg;

assign s_axis_desc_dequeue_resp_ready = s_axis_desc_dequeue_resp_ready_reg;

assign m_axis_desc_dequeue_commit_op_tag = {PORTS{m_axis_desc_dequeue_commit_op_tag_reg}};
assign m_axis_desc_dequeue_commit_valid = m_axis_desc_dequeue_commit_valid_reg;

assign m_axis_pcie_axi_dma_read_desc_pcie_addr = m_axis_pcie_axi_dma_read_desc_pcie_addr_reg;
assign m_axis_pcie_axi_dma_read_desc_axi_addr = m_axis_pcie_axi_dma_read_desc_axi_addr_reg;
assign m_axis_pcie_axi_dma_read_desc_len = m_axis_pcie_axi_dma_read_desc_len_reg;
assign m_axis_pcie_axi_dma_read_desc_tag = m_axis_pcie_axi_dma_read_desc_tag_reg;
assign m_axis_pcie_axi_dma_read_desc_valid = m_axis_pcie_axi_dma_read_desc_valid_reg;

wire [CL_PORTS-1:0] dequeue_resp_enc;
wire dequeue_resp_enc_valid;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_PRIORITY("HIGH")
)
op_table_start_enc_inst (
    .input_unencoded(s_axis_desc_dequeue_resp_valid & ~s_axis_desc_dequeue_resp_ready),
    .output_valid(dequeue_resp_enc_valid),
    .output_encoded(dequeue_resp_enc),
    .output_unencoded()
);

wire [AXI_ID_WIDTH-1:0]   ram_wr_cmd_id;
wire [AXI_ADDR_WIDTH-1:0] ram_wr_cmd_addr;
wire [AXI_DATA_WIDTH-1:0] ram_wr_cmd_data;
wire [AXI_STRB_WIDTH-1:0] ram_wr_cmd_strb;
wire                      ram_wr_cmd_en;

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
    .ram_wr_cmd_id(ram_wr_cmd_id),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_lock(),
    .ram_wr_cmd_cache(),
    .ram_wr_cmd_prot(),
    .ram_wr_cmd_qos(),
    .ram_wr_cmd_region(),
    .ram_wr_cmd_auser(),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_strb(ram_wr_cmd_strb),
    .ram_wr_cmd_user(),
    .ram_wr_cmd_en(ram_wr_cmd_en),
    .ram_wr_cmd_last(),
    .ram_wr_cmd_ready(1'b1)
);

always @(posedge clk) begin
    if (ram_wr_cmd_en) begin
        // AXI write
        // TODO byte enables
        desc_table_data[ram_wr_cmd_addr[CL_DESC_TABLE_SIZE+5-1:5]] <= ram_wr_cmd_data;
    end
end

always @* begin
    s_axis_req_ready_next = 1'b0;

    m_axis_req_status_queue_next = m_axis_req_status_queue_reg;
    m_axis_req_status_ptr_next = m_axis_req_status_ptr_reg;
    m_axis_req_status_cpl_next = m_axis_req_status_cpl_reg;
    m_axis_req_status_tag_next = m_axis_req_status_tag_reg;
    m_axis_req_status_empty_next = m_axis_req_status_empty_reg;
    m_axis_req_status_error_next = m_axis_req_status_error_reg;
    m_axis_req_status_valid_next = 1'b0;

    m_axis_desc_tdata_next = m_axis_desc_tdata_reg;
    m_axis_desc_tkeep_next = m_axis_desc_tkeep_reg;
    m_axis_desc_tvalid_next = m_axis_desc_tvalid_reg && !m_axis_desc_tready;
    m_axis_desc_tlast_next = m_axis_desc_tlast_reg;
    m_axis_desc_tid_next = m_axis_desc_tid_reg;
    m_axis_desc_tuser_next = m_axis_desc_tuser_reg;

    m_axis_desc_dequeue_req_queue_next = m_axis_desc_dequeue_req_queue_reg;
    m_axis_desc_dequeue_req_tag_next = m_axis_desc_dequeue_req_tag_reg;
    m_axis_desc_dequeue_req_valid_next = m_axis_desc_dequeue_req_valid_reg & ~m_axis_desc_dequeue_req_ready;

    s_axis_desc_dequeue_resp_ready_next = {PORTS{1'b0}};

    m_axis_desc_dequeue_commit_op_tag_next = m_axis_desc_dequeue_commit_op_tag_reg;
    m_axis_desc_dequeue_commit_valid_next = m_axis_desc_dequeue_commit_valid_reg & ~m_axis_desc_dequeue_commit_ready;

    m_axis_pcie_axi_dma_read_desc_pcie_addr_next = m_axis_pcie_axi_dma_read_desc_pcie_addr_reg;
    m_axis_pcie_axi_dma_read_desc_axi_addr_next = m_axis_pcie_axi_dma_read_desc_axi_addr_reg;
    m_axis_pcie_axi_dma_read_desc_len_next = m_axis_pcie_axi_dma_read_desc_len_reg;
    m_axis_pcie_axi_dma_read_desc_tag_next = m_axis_pcie_axi_dma_read_desc_tag_reg;
    m_axis_pcie_axi_dma_read_desc_valid_next = m_axis_pcie_axi_dma_read_desc_valid_reg && !m_axis_pcie_axi_dma_read_desc_ready;

    inc_active = 1'b0;
    dec_active_1 = 1'b0;
    dec_active_2 = 1'b0;

    desc_table_start_sel = dequeue_resp_enc;
    desc_table_start_tag = s_axis_desc_dequeue_resp_tag[dequeue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH];
    desc_table_start_queue_op_tag = s_axis_desc_dequeue_resp_op_tag[dequeue_resp_enc*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH];
    desc_table_start_en = 1'b0;
    desc_table_desc_fetched_ptr = s_axis_pcie_axi_dma_read_desc_status_tag & DESC_PTR_MASK;
    desc_table_desc_fetched_en = 1'b0;
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
    if (dequeue_resp_enc_valid && !m_axis_pcie_axi_dma_read_desc_valid_reg && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE)) begin
        s_axis_desc_dequeue_resp_ready_next = 1 << dequeue_resp_enc;

        // store in descriptor table
        desc_table_start_sel = dequeue_resp_enc;
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
        m_axis_pcie_axi_dma_read_desc_pcie_addr_next = s_axis_desc_dequeue_resp_addr[dequeue_resp_enc*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH];
        m_axis_pcie_axi_dma_read_desc_axi_addr_next = AXI_BASE_ADDR + ((desc_table_start_ptr_reg & DESC_PTR_MASK) << 5);
        m_axis_pcie_axi_dma_read_desc_len_next = DESC_SIZE;
        m_axis_pcie_axi_dma_read_desc_tag_next = (desc_table_start_ptr_reg & DESC_PTR_MASK);

        if (s_axis_desc_dequeue_resp_error[dequeue_resp_enc*1 +: 1] || s_axis_desc_dequeue_resp_empty[dequeue_resp_enc*1 +: 1]) begin
            // queue empty or not active

            dec_active_1 = 1'b1;
        end else begin
            // descriptor available to dequeue

            // store in descriptor table
            desc_table_start_en = 1'b1;

            // initiate descriptor fetch
            m_axis_pcie_axi_dma_read_desc_valid_next = 1'b1;
        end
    end

    // descriptor fetch completion
    // wait for descriptor fetch completion
    if (s_axis_pcie_axi_dma_read_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_desc_fetched_ptr = s_axis_pcie_axi_dma_read_desc_status_tag & DESC_PTR_MASK;
        desc_table_desc_fetched_en = 1'b1;
    end

    // return descriptor and finish operation
    // wait for descriptor fetch completion
    // TODO descriptor validation?
    if (desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] && desc_table_finish_ptr_reg != desc_table_start_ptr_reg && !m_axis_desc_tvalid) begin
        if (desc_table_desc_fetched[desc_table_finish_ptr_reg & DESC_PTR_MASK] && !(m_axis_desc_dequeue_commit_valid & 1 << desc_table_sel[desc_table_finish_ptr_reg & DESC_PTR_MASK]) && !m_axis_desc_tvalid) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            // commit dequeue operation
            m_axis_desc_dequeue_commit_op_tag_next = desc_table_queue_op_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_desc_dequeue_commit_valid_next = 1 << desc_table_sel[desc_table_finish_ptr_reg & DESC_PTR_MASK];

            // return descriptor
            m_axis_desc_tdata_next = desc_table_data[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_desc_tkeep_next = {AXIS_KEEP_WIDTH{1'b1}};
            m_axis_desc_tlast_next = 1'b1;
            m_axis_desc_tid_next = desc_table_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_desc_tuser_next = 1'b0;
            m_axis_desc_tvalid_next = 1'b1;

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

    m_axis_desc_tdata_reg <= m_axis_desc_tdata_next;
    m_axis_desc_tkeep_reg <= m_axis_desc_tkeep_next;
    m_axis_desc_tvalid_reg <= m_axis_desc_tvalid_next;
    m_axis_desc_tlast_reg <= m_axis_desc_tlast_next;
    m_axis_desc_tid_reg <= m_axis_desc_tid_next;
    m_axis_desc_tuser_reg <= m_axis_desc_tuser_next;

    m_axis_desc_dequeue_req_queue_reg <= m_axis_desc_dequeue_req_queue_next;
    m_axis_desc_dequeue_req_tag_reg <= m_axis_desc_dequeue_req_tag_next;
    m_axis_desc_dequeue_req_valid_reg <= m_axis_desc_dequeue_req_valid_next;

    s_axis_desc_dequeue_resp_ready_reg <= s_axis_desc_dequeue_resp_ready_next;

    m_axis_desc_dequeue_commit_op_tag_reg <= m_axis_desc_dequeue_commit_op_tag_next;
    m_axis_desc_dequeue_commit_valid_reg <= m_axis_desc_dequeue_commit_valid_next;

    m_axis_pcie_axi_dma_read_desc_pcie_addr_reg <= m_axis_pcie_axi_dma_read_desc_pcie_addr_next;
    m_axis_pcie_axi_dma_read_desc_axi_addr_reg <= m_axis_pcie_axi_dma_read_desc_axi_addr_next;
    m_axis_pcie_axi_dma_read_desc_len_reg <= m_axis_pcie_axi_dma_read_desc_len_next;
    m_axis_pcie_axi_dma_read_desc_tag_reg <= m_axis_pcie_axi_dma_read_desc_tag_next;
    m_axis_pcie_axi_dma_read_desc_valid_reg <= m_axis_pcie_axi_dma_read_desc_valid_next;

    active_count_reg <= active_count_reg + inc_active - dec_active_1 - dec_active_2;

    if (desc_table_start_en) begin
        desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b1;
        desc_table_desc_fetched[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_sel[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_sel;
        desc_table_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_tag;
        desc_table_queue_op_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_queue_op_tag;
        desc_table_start_ptr_reg <= desc_table_start_ptr_reg + 1;
    end

    if (desc_table_desc_fetched_en) begin
        desc_table_desc_fetched[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= 1'b1;
    end

    if (desc_table_finish_en) begin
        desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_finish_ptr_reg <= desc_table_finish_ptr_reg + 1;
    end

    if (rst) begin
        s_axis_req_ready_reg <= 1'b0;
        m_axis_req_status_valid_reg <= 1'b0;
        m_axis_desc_tvalid_reg <= 1'b0;
        m_axis_desc_dequeue_req_valid_reg <= {PORTS{1'b0}};
        s_axis_desc_dequeue_resp_ready_reg <= {PORTS{1'b0}};
        m_axis_desc_dequeue_commit_valid_reg <= {PORTS{1'b0}};
        m_axis_pcie_axi_dma_read_desc_valid_reg <= 1'b0;

        active_count_reg <= 0;

        desc_table_active <= 0;
        desc_table_desc_fetched <= 0;

        desc_table_start_ptr_reg <= 0;
        desc_table_finish_ptr_reg <= 0;
    end
end

endmodule
