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
 * Completion write module
 */
module cpl_write #
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
    // Completion size (in bytes)
    parameter CPL_SIZE = 32,
    // Descriptor table size (number of in-flight operations)
    parameter DESC_TABLE_SIZE = 8,
    // AXI base address of this module (as seen by PCIe DMA)
    parameter AXI_BASE_ADDR = 16'h0000
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
    input  wire [PORTS*PCIE_ADDR_WIDTH-1:0]     s_axis_cpl_enqueue_resp_addr,
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
     * PCIe AXI DMA write descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]           m_axis_pcie_axi_dma_write_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]            m_axis_pcie_axi_dma_write_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]        m_axis_pcie_axi_dma_write_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]        m_axis_pcie_axi_dma_write_desc_tag,
    output wire                                 m_axis_pcie_axi_dma_write_desc_valid,
    input  wire                                 m_axis_pcie_axi_dma_write_desc_ready,

    /*
     * PCIe AXI DMA write descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]        s_axis_pcie_axi_dma_write_desc_status_tag,
    input  wire                                 s_axis_pcie_axi_dma_write_desc_status_valid,

    /*
     * AXI slave interface (read)
     */
    input  wire [AXI_ID_WIDTH-1:0]              s_axi_arid,
    input  wire [AXI_ADDR_WIDTH-1:0]            s_axi_araddr,
    input  wire [7:0]                           s_axi_arlen,
    input  wire [2:0]                           s_axi_arsize,
    input  wire [1:0]                           s_axi_arburst,
    input  wire                                 s_axi_arlock,
    input  wire [3:0]                           s_axi_arcache,
    input  wire [2:0]                           s_axi_arprot,
    input  wire                                 s_axi_arvalid,
    output wire                                 s_axi_arready,
    output wire [AXI_ID_WIDTH-1:0]              s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]            s_axi_rdata,
    output wire [1:0]                           s_axi_rresp,
    output wire                                 s_axi_rlast,
    output wire                                 s_axi_rvalid,
    input  wire                                 s_axi_rready,

    /*
     * Configuration
     */
    input  wire                                 enable
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);

parameter CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
parameter DESC_PTR_MASK = {CL_DESC_TABLE_SIZE{1'b1}};

parameter CL_PORTS = $clog2(PORTS);

// bus width assertions
initial begin
    if (PCIE_DMA_TAG_WIDTH < CL_DESC_TABLE_SIZE+1) begin
        $error("Error: PCIe tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (QUEUE_REQ_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: Queue request tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH * 8 != AXI_DATA_WIDTH) begin
        $error("Error: AXI interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH < CPL_SIZE) begin
        $error("Error: AXI interface width must be at least as large as one descriptor (instance %m)");
        $finish;
    end

    if (AXI_BASE_ADDR[$clog2(AXI_STRB_WIDTH)-1:0]) begin
        $error("Error: AXI base address must be aligned to interface width (instance %m)");
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

reg [PCIE_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_axi_addr_next;
reg [PCIE_DMA_LEN_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_len_reg = {PCIE_DMA_LEN_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_len_next;
reg [PCIE_DMA_TAG_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_tag_reg = {PCIE_DMA_TAG_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_tag_next;
reg m_axis_pcie_axi_dma_write_desc_valid_reg = 1'b0, m_axis_pcie_axi_dma_write_desc_valid_next;

reg [DESC_TABLE_SIZE-1:0] desc_table_active = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_invalid = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done = 0;
reg [CL_PORTS-1:0] desc_table_sel[DESC_TABLE_SIZE-1:0];
reg [REQ_TAG_WIDTH-1:0] desc_table_tag[DESC_TABLE_SIZE-1:0];
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_queue_op_tag[DESC_TABLE_SIZE-1:0];
reg [CPL_SIZE*8-1:0] desc_table_data[DESC_TABLE_SIZE-1:0];

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr_reg = 0;
reg [CL_PORTS-1:0] desc_table_start_sel;
reg [REQ_TAG_WIDTH-1:0] desc_table_start_tag;
reg [CPL_SIZE*8-1:0] desc_table_start_data;
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

assign m_axis_pcie_axi_dma_write_desc_pcie_addr = m_axis_pcie_axi_dma_write_desc_pcie_addr_reg;
assign m_axis_pcie_axi_dma_write_desc_axi_addr = m_axis_pcie_axi_dma_write_desc_axi_addr_reg;
assign m_axis_pcie_axi_dma_write_desc_len = m_axis_pcie_axi_dma_write_desc_len_reg;
assign m_axis_pcie_axi_dma_write_desc_tag = m_axis_pcie_axi_dma_write_desc_tag_reg;
assign m_axis_pcie_axi_dma_write_desc_valid = m_axis_pcie_axi_dma_write_desc_valid_reg;

wire [CL_PORTS-1:0] enqueue_resp_enc;
wire enqueue_resp_enc_valid;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_PRIORITY("HIGH")
)
op_table_start_enc_inst (
    .input_unencoded(s_axis_cpl_enqueue_resp_valid & ~s_axis_cpl_enqueue_resp_ready),
    .output_valid(enqueue_resp_enc_valid),
    .output_encoded(enqueue_resp_enc),
    .output_unencoded()
);

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

        ram_rd_resp_data_reg <= desc_table_data[ram_rd_cmd_addr[CL_DESC_TABLE_SIZE+5-1:5]];
    end

    if (rst) begin
        ram_rd_cmd_ready_reg <= 1'b1;
        ram_rd_resp_valid_reg <= 1'b0;
    end
end

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

    m_axis_pcie_axi_dma_write_desc_pcie_addr_next = m_axis_pcie_axi_dma_write_desc_pcie_addr_reg;
    m_axis_pcie_axi_dma_write_desc_axi_addr_next = m_axis_pcie_axi_dma_write_desc_axi_addr_reg;
    m_axis_pcie_axi_dma_write_desc_len_next = m_axis_pcie_axi_dma_write_desc_len_reg;
    m_axis_pcie_axi_dma_write_desc_tag_next = m_axis_pcie_axi_dma_write_desc_tag_reg;
    m_axis_pcie_axi_dma_write_desc_valid_next = m_axis_pcie_axi_dma_write_desc_valid_reg && !m_axis_pcie_axi_dma_write_desc_ready;

    desc_table_start_sel = s_axis_req_sel;
    desc_table_start_tag = s_axis_req_tag;
    desc_table_start_data = s_axis_req_data;
    desc_table_start_en = 1'b0;
    desc_table_enqueue_ptr = s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK;
    desc_table_enqueue_queue_op_tag = s_axis_cpl_enqueue_resp_op_tag[enqueue_resp_enc*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH];
    desc_table_enqueue_invalid = 1'b0;
    desc_table_enqueue_en = 1'b0;
    desc_table_cpl_write_done_ptr = s_axis_pcie_axi_dma_write_desc_status_tag & DESC_PTR_MASK;
    desc_table_cpl_write_done_en = 1'b0;
    desc_table_finish_en = 1'b0;

    // queue query
    // wait for descriptor request
    s_axis_req_ready_next = enable && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE) && (!m_axis_cpl_enqueue_req_valid || (m_axis_cpl_enqueue_req_valid & m_axis_cpl_enqueue_req_ready));
    if (s_axis_req_ready && s_axis_req_valid) begin
        s_axis_req_ready_next = 1'b0;

        // store in descriptor table
        desc_table_start_sel = s_axis_req_sel;
        desc_table_start_tag = s_axis_req_tag;
        desc_table_start_data = s_axis_req_data;
        desc_table_start_en = 1'b1;

        // initiate queue query
        m_axis_cpl_enqueue_req_queue_next = s_axis_req_queue;
        m_axis_cpl_enqueue_req_tag_next = desc_table_start_ptr_reg & DESC_PTR_MASK;
        m_axis_cpl_enqueue_req_valid_next = 1 << s_axis_req_sel;
    end

    // start completion write
    // wait for queue query response
    if (enqueue_resp_enc_valid && !m_axis_pcie_axi_dma_write_desc_valid_reg) begin
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
        m_axis_pcie_axi_dma_write_desc_pcie_addr_next = s_axis_cpl_enqueue_resp_addr[enqueue_resp_enc*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH];
        m_axis_pcie_axi_dma_write_desc_axi_addr_next = AXI_BASE_ADDR + ((s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK) << 5);
        m_axis_pcie_axi_dma_write_desc_len_next = CPL_SIZE;
        m_axis_pcie_axi_dma_write_desc_tag_next = (s_axis_cpl_enqueue_resp_tag[enqueue_resp_enc*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH] & DESC_PTR_MASK);

        if (s_axis_cpl_enqueue_resp_error[enqueue_resp_enc*1 +: 1] || s_axis_cpl_enqueue_resp_full[enqueue_resp_enc*1 +: 1]) begin
            // queue empty or not active

            // invalidate entry
            desc_table_enqueue_invalid = 1'b1;
        end else begin
            // descriptor available to enqueue

            // initiate completion write
            m_axis_pcie_axi_dma_write_desc_valid_next = 1'b1;
        end
    end

    // finish completion write
    if (s_axis_pcie_axi_dma_write_desc_status_valid) begin
        // update entry in descriptor table
        desc_table_cpl_write_done_ptr = s_axis_pcie_axi_dma_write_desc_status_tag & DESC_PTR_MASK;
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

    m_axis_pcie_axi_dma_write_desc_pcie_addr_reg <= m_axis_pcie_axi_dma_write_desc_pcie_addr_next;
    m_axis_pcie_axi_dma_write_desc_axi_addr_reg <= m_axis_pcie_axi_dma_write_desc_axi_addr_next;
    m_axis_pcie_axi_dma_write_desc_len_reg <= m_axis_pcie_axi_dma_write_desc_len_next;
    m_axis_pcie_axi_dma_write_desc_tag_reg <= m_axis_pcie_axi_dma_write_desc_tag_next;
    m_axis_pcie_axi_dma_write_desc_valid_reg <= m_axis_pcie_axi_dma_write_desc_valid_next;

    if (desc_table_start_en) begin
        desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b1;
        desc_table_invalid[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_cpl_write_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
        desc_table_sel[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_sel;
        desc_table_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_tag;
        desc_table_data[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_data;
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
        m_axis_pcie_axi_dma_write_desc_valid_reg <= 1'b0;

        desc_table_active <= 0;
        desc_table_invalid <= 0;

        desc_table_start_ptr_reg <= 0;
        desc_table_finish_ptr_reg <= 0;
    end
end

endmodule
