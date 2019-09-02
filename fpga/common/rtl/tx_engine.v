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
 * Transmit engine
 */
module tx_engine #
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
    // AXI DMA length field width
    parameter AXI_DMA_LEN_WIDTH = 20,
    // Transmit request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // PCIe DMA tag field width
    parameter PCIE_DMA_TAG_WIDTH = 8,
    // AXI DMA tag field width
    parameter AXI_DMA_TAG_WIDTH = 8,
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
    // AXI base address of this module (as seen by PCIe DMA)
    parameter AXI_BASE_ADDR = 16'h0000,
    // AXI address of packet scratchpad RAM (as seen by PCIe DMA and port AXI DMA)
    parameter SCRATCH_PKT_AXI_ADDR = 16'h1000,
    // Packet scratchpad RAM log segment size
    parameter SCRATCH_PKT_AXI_ADDR_SHIFT = 12,
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
    output wire [AXI_DMA_LEN_WIDTH-1:0]     m_axis_tx_req_status_len,
    output wire [REQ_TAG_WIDTH-1:0]         m_axis_tx_req_status_tag,
    output wire                             m_axis_tx_req_status_valid,

    /*
     * Descriptor dequeue request output
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]     m_axis_desc_dequeue_req_queue,
    output wire [QUEUE_REQ_TAG_WIDTH-1:0]   m_axis_desc_dequeue_req_tag,
    output wire                             m_axis_desc_dequeue_req_valid,
    input  wire                             m_axis_desc_dequeue_req_ready,

    /*
     * Descriptor dequeue response input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]     s_axis_desc_dequeue_resp_queue,
    input  wire [QUEUE_PTR_WIDTH-1:0]       s_axis_desc_dequeue_resp_ptr,
    input  wire [PCIE_ADDR_WIDTH-1:0]       s_axis_desc_dequeue_resp_addr,
    input  wire [CPL_QUEUE_INDEX_WIDTH-1:0] s_axis_desc_dequeue_resp_cpl,
    input  wire [QUEUE_REQ_TAG_WIDTH-1:0]   s_axis_desc_dequeue_resp_tag,
    input  wire [QUEUE_OP_TAG_WIDTH-1:0]    s_axis_desc_dequeue_resp_op_tag,
    input  wire                             s_axis_desc_dequeue_resp_empty,
    input  wire                             s_axis_desc_dequeue_resp_error,
    input  wire                             s_axis_desc_dequeue_resp_valid,
    output wire                             s_axis_desc_dequeue_resp_ready,

    /*
     * Descriptor dequeue commit output
     */
    output wire [QUEUE_OP_TAG_WIDTH-1:0]    m_axis_desc_dequeue_commit_op_tag,
    output wire                             m_axis_desc_dequeue_commit_valid,
    input  wire                             m_axis_desc_dequeue_commit_ready,

    /*
     * Completion enqueue request output
     */
    output wire [CPL_QUEUE_INDEX_WIDTH-1:0] m_axis_cpl_enqueue_req_queue,
    output wire [QUEUE_REQ_TAG_WIDTH-1:0]   m_axis_cpl_enqueue_req_tag,
    output wire                             m_axis_cpl_enqueue_req_valid,
    input  wire                             m_axis_cpl_enqueue_req_ready,

    /*
     * Completion enqueue response input
     */
    input  wire [PCIE_ADDR_WIDTH-1:0]       s_axis_cpl_enqueue_resp_addr,
    input  wire [QUEUE_REQ_TAG_WIDTH-1:0]   s_axis_cpl_enqueue_resp_tag,
    input  wire [QUEUE_OP_TAG_WIDTH-1:0]    s_axis_cpl_enqueue_resp_op_tag,
    input  wire                             s_axis_cpl_enqueue_resp_full,
    input  wire                             s_axis_cpl_enqueue_resp_error,
    input  wire                             s_axis_cpl_enqueue_resp_valid,
    output wire                             s_axis_cpl_enqueue_resp_ready,

    /*
     * Completion enqueue commit output
     */
    output wire [QUEUE_OP_TAG_WIDTH-1:0]    m_axis_cpl_enqueue_commit_op_tag,
    output wire                             m_axis_cpl_enqueue_commit_valid,
    input  wire                             m_axis_cpl_enqueue_commit_ready,

    /*
     * PCIe AXI DMA read descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]       m_axis_pcie_axi_dma_read_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]        m_axis_pcie_axi_dma_read_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]    m_axis_pcie_axi_dma_read_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]    m_axis_pcie_axi_dma_read_desc_tag,
    output wire                             m_axis_pcie_axi_dma_read_desc_valid,
    input  wire                             m_axis_pcie_axi_dma_read_desc_ready,

    /*
     * PCIe AXI DMA read descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]    s_axis_pcie_axi_dma_read_desc_status_tag,
    input  wire                             s_axis_pcie_axi_dma_read_desc_status_valid,

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
     * Transmit descriptor output
     */
    output wire [AXI_ADDR_WIDTH-1:0]        m_axis_tx_desc_addr,
    output wire [AXI_DMA_LEN_WIDTH-1:0]     m_axis_tx_desc_len,
    output wire [AXI_DMA_TAG_WIDTH-1:0]     m_axis_tx_desc_tag,
    output wire                             m_axis_tx_desc_user,
    output wire                             m_axis_tx_desc_valid,
    input  wire                             m_axis_tx_desc_ready,

    /*
     * Transmit descriptor status input
     */
    input  wire [AXI_DMA_TAG_WIDTH-1:0]     s_axis_tx_desc_status_tag,
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

parameter CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
parameter DESC_PTR_MASK = {CL_DESC_TABLE_SIZE{1'b1}};
parameter CL_PKT_TABLE_SIZE = $clog2(PKT_TABLE_SIZE);
parameter PKT_TAG_MASK = {CL_PKT_TABLE_SIZE{1'b1}};

parameter DATA_FLAG = 1 << CL_DESC_TABLE_SIZE;

parameter DESC_SIZE = 16;
parameter CPL_SIZE = 32;

parameter BLOCK_SIZE = DESC_SIZE > CPL_SIZE ? DESC_SIZE : CPL_SIZE;

// bus width assertions
initial begin
    if (PCIE_DMA_TAG_WIDTH < CL_DESC_TABLE_SIZE+1) begin
        $error("Error: PCIe tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (AXI_DMA_TAG_WIDTH < CL_DESC_TABLE_SIZE) begin
        $error("Error: AXI tag width insufficient for descriptor table size (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH * 8 != AXI_DATA_WIDTH) begin
        $error("Error: AXI interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH < BLOCK_SIZE) begin
        $error("Error: AXI interface width must be at least as large as one descriptor (instance %m)");
        $finish;
    end

    if (AXI_BASE_ADDR[$clog2(AXI_STRB_WIDTH)-1:0]) begin
        $error("Error: AXI base address must be aligned to interface width (instance %m)");
        $finish;
    end

    if (SCRATCH_PKT_AXI_ADDR[$clog2(AXI_STRB_WIDTH)-1:0]) begin
        $error("Error: AXI base address must be aligned to interface width (instance %m)");
        $finish;
    end

    if (SCRATCH_PKT_AXI_ADDR_SHIFT < $clog2(AXI_STRB_WIDTH)) begin
        $error("Error: Packet scratch address increment must be aligned to interface width (instance %m)");
        $finish;
    end

    if (QUEUE_REQ_TAG_WIDTH < REQ_TAG_WIDTH) begin
        $error("Error: QUEUE_REQ_TAG_WIDTH must be at least REQ_TAG_WIDTH (instance %m)");
        $finish;
    end
end

reg [REQ_TAG_WIDTH-1:0] s_axis_tx_req_tag_reg = {REQ_TAG_WIDTH{1'b0}}, s_axis_tx_req_tag_next;
reg s_axis_tx_req_ready_reg = 1'b0, s_axis_tx_req_ready_next;

reg [AXI_DMA_LEN_WIDTH-1:0] m_axis_tx_req_status_len_reg = {AXI_DMA_LEN_WIDTH{1'b0}}, m_axis_tx_req_status_len_next;
reg [REQ_TAG_WIDTH-1:0] m_axis_tx_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, m_axis_tx_req_status_tag_next;
reg m_axis_tx_req_status_valid_reg = 1'b0, m_axis_tx_req_status_valid_next;

reg [QUEUE_INDEX_WIDTH-1:0] m_axis_desc_dequeue_req_queue_reg = {QUEUE_INDEX_WIDTH{1'b0}}, m_axis_desc_dequeue_req_queue_next;
reg [QUEUE_REQ_TAG_WIDTH-1:0] m_axis_desc_dequeue_req_tag_reg = {QUEUE_REQ_TAG_WIDTH{1'b0}}, m_axis_desc_dequeue_req_tag_next;
reg m_axis_desc_dequeue_req_valid_reg = 1'b0, m_axis_desc_dequeue_req_valid_next;

reg s_axis_desc_dequeue_resp_ready_reg = 1'b0, s_axis_desc_dequeue_resp_ready_next;

reg [QUEUE_OP_TAG_WIDTH-1:0] m_axis_desc_dequeue_commit_op_tag_reg = {QUEUE_OP_TAG_WIDTH{1'b0}}, m_axis_desc_dequeue_commit_op_tag_next;
reg m_axis_desc_dequeue_commit_valid_reg = 1'b0, m_axis_desc_dequeue_commit_valid_next;

reg [CPL_QUEUE_INDEX_WIDTH-1:0] m_axis_cpl_enqueue_req_queue_reg = {CPL_QUEUE_INDEX_WIDTH{1'b0}}, m_axis_cpl_enqueue_req_queue_next;
reg [QUEUE_REQ_TAG_WIDTH-1:0] m_axis_cpl_enqueue_req_tag_reg = {QUEUE_REQ_TAG_WIDTH{1'b0}}, m_axis_cpl_enqueue_req_tag_next;
reg m_axis_cpl_enqueue_req_valid_reg = 1'b0, m_axis_cpl_enqueue_req_valid_next;

reg s_axis_cpl_enqueue_resp_ready_reg = 1'b0, s_axis_cpl_enqueue_resp_ready_next;

reg [QUEUE_OP_TAG_WIDTH-1:0] m_axis_cpl_enqueue_commit_op_tag_reg = {QUEUE_OP_TAG_WIDTH{1'b0}}, m_axis_cpl_enqueue_commit_op_tag_next;
reg m_axis_cpl_enqueue_commit_valid_reg = 1'b0, m_axis_cpl_enqueue_commit_valid_next;

reg [PCIE_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_axi_addr_next;
reg [PCIE_DMA_LEN_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_len_reg = {PCIE_DMA_LEN_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_len_next;
reg [PCIE_DMA_TAG_WIDTH-1:0] m_axis_pcie_axi_dma_read_desc_tag_reg = {PCIE_DMA_TAG_WIDTH{1'b0}}, m_axis_pcie_axi_dma_read_desc_tag_next;
reg m_axis_pcie_axi_dma_read_desc_valid_reg = 1'b0, m_axis_pcie_axi_dma_read_desc_valid_next;

reg [PCIE_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_axi_addr_next;
reg [PCIE_DMA_LEN_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_len_reg = {PCIE_DMA_LEN_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_len_next;
reg [PCIE_DMA_TAG_WIDTH-1:0] m_axis_pcie_axi_dma_write_desc_tag_reg = {PCIE_DMA_TAG_WIDTH{1'b0}}, m_axis_pcie_axi_dma_write_desc_tag_next;
reg m_axis_pcie_axi_dma_write_desc_valid_reg = 1'b0, m_axis_pcie_axi_dma_write_desc_valid_next;

reg [AXI_ADDR_WIDTH-1:0] m_axis_tx_desc_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axis_tx_desc_addr_next;
reg [AXI_DMA_LEN_WIDTH-1:0] m_axis_tx_desc_len_reg = {AXI_DMA_LEN_WIDTH{1'b0}}, m_axis_tx_desc_len_next;
reg [AXI_DMA_TAG_WIDTH-1:0] m_axis_tx_desc_tag_reg = {AXI_DMA_TAG_WIDTH{1'b0}}, m_axis_tx_desc_tag_next;
reg m_axis_tx_desc_user_reg = 1'b0, m_axis_tx_desc_user_next;
reg m_axis_tx_desc_valid_reg = 1'b0, m_axis_tx_desc_valid_next;

reg m_axis_tx_csum_cmd_csum_enable_reg = 1'b0, m_axis_tx_csum_cmd_csum_enable_next;
reg [7:0] m_axis_tx_csum_cmd_csum_start_reg = 7'd0, m_axis_tx_csum_cmd_csum_start_next;
reg [7:0] m_axis_tx_csum_cmd_csum_offset_reg = 7'd0, m_axis_tx_csum_cmd_csum_offset_next;
reg m_axis_tx_csum_cmd_valid_reg = 1'b0, m_axis_tx_csum_cmd_valid_next;

reg s_axis_tx_ptp_ts_ready_reg = 1'b0, s_axis_tx_ptp_ts_ready_next;

reg [AXI_DMA_LEN_WIDTH-1:0] early_tx_req_status_len_reg = {AXI_DMA_LEN_WIDTH{1'b0}}, early_tx_req_status_len_next;
reg [REQ_TAG_WIDTH-1:0] early_tx_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, early_tx_req_status_tag_next;
reg early_tx_req_status_valid_reg = 1'b0, early_tx_req_status_valid_next;

reg [AXI_DMA_LEN_WIDTH-1:0] finish_tx_req_status_len_reg = {AXI_DMA_LEN_WIDTH{1'b0}}, finish_tx_req_status_len_next;
reg [REQ_TAG_WIDTH-1:0] finish_tx_req_status_tag_reg = {REQ_TAG_WIDTH{1'b0}}, finish_tx_req_status_tag_next;
reg finish_tx_req_status_valid_reg = 1'b0, finish_tx_req_status_valid_next;

reg [PCIE_ADDR_WIDTH-1:0] desc_fetch_pcie_axi_dma_read_desc_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, desc_fetch_pcie_axi_dma_read_desc_pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] desc_fetch_pcie_axi_dma_read_desc_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, desc_fetch_pcie_axi_dma_read_desc_axi_addr_next;
reg [PCIE_DMA_LEN_WIDTH-1:0] desc_fetch_pcie_axi_dma_read_desc_len_reg = {PCIE_DMA_LEN_WIDTH{1'b0}}, desc_fetch_pcie_axi_dma_read_desc_len_next;
reg [PCIE_DMA_TAG_WIDTH-1:0] desc_fetch_pcie_axi_dma_read_desc_tag_reg = {PCIE_DMA_TAG_WIDTH{1'b0}}, desc_fetch_pcie_axi_dma_read_desc_tag_next;
reg desc_fetch_pcie_axi_dma_read_desc_valid_reg = 1'b0, desc_fetch_pcie_axi_dma_read_desc_valid_next;

reg [PCIE_ADDR_WIDTH-1:0] pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] pkt_fetch_pcie_axi_dma_read_desc_axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, pkt_fetch_pcie_axi_dma_read_desc_axi_addr_next;
reg [PCIE_DMA_LEN_WIDTH-1:0] pkt_fetch_pcie_axi_dma_read_desc_len_reg = {PCIE_DMA_LEN_WIDTH{1'b0}}, pkt_fetch_pcie_axi_dma_read_desc_len_next;
reg [PCIE_DMA_TAG_WIDTH-1:0] pkt_fetch_pcie_axi_dma_read_desc_tag_reg = {PCIE_DMA_TAG_WIDTH{1'b0}}, pkt_fetch_pcie_axi_dma_read_desc_tag_next;
reg pkt_fetch_pcie_axi_dma_read_desc_valid_reg = 1'b0, pkt_fetch_pcie_axi_dma_read_desc_valid_next;

reg [CL_DESC_TABLE_SIZE+1-1:0] active_count_reg = 0;
reg inc_active;
reg dec_active_1;
reg dec_active_2;

reg [DESC_TABLE_SIZE-1:0] desc_table_active = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_invalid = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_desc_fetched = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_data_fetched = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_tx_done = 0;
reg [DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done = 0;
reg [REQ_TAG_WIDTH-1:0] desc_table_tag[DESC_TABLE_SIZE-1:0];
reg [QUEUE_INDEX_WIDTH-1:0] desc_table_queue[DESC_TABLE_SIZE-1:0];
reg [QUEUE_PTR_WIDTH-1:0] desc_table_queue_ptr[DESC_TABLE_SIZE-1:0];
reg [CPL_QUEUE_INDEX_WIDTH-1:0] desc_table_cpl_queue[DESC_TABLE_SIZE-1:0];
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_queue_op_tag[DESC_TABLE_SIZE-1:0];
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_cpl_queue_op_tag[DESC_TABLE_SIZE-1:0];
reg [6:0] desc_table_csum_start[DESC_TABLE_SIZE-1:0];
reg [7:0] desc_table_csum_offset[DESC_TABLE_SIZE-1:0];
reg desc_table_csum_enable[DESC_TABLE_SIZE-1:0];
reg [AXI_DMA_LEN_WIDTH-1:0] desc_table_len[DESC_TABLE_SIZE-1:0];
reg [PCIE_ADDR_WIDTH-1:0] desc_table_pcie_addr[DESC_TABLE_SIZE-1:0];
reg [CL_PKT_TABLE_SIZE-1:0] desc_table_pkt[DESC_TABLE_SIZE-1:0];
reg [95:0] desc_table_ptp_ts[DESC_TABLE_SIZE-1:0];

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr_reg = 0;
reg [QUEUE_INDEX_WIDTH-1:0] desc_table_start_queue;
reg [REQ_TAG_WIDTH-1:0] desc_table_start_tag;
reg [QUEUE_PTR_WIDTH-1:0] desc_table_start_queue_ptr;
reg [CPL_QUEUE_INDEX_WIDTH-1:0] desc_table_start_cpl_queue;
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_start_queue_op_tag;
reg desc_table_start_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_desc_fetched_ptr;
reg desc_table_desc_fetched_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_data_fetch_start_ptr_reg = 0;
reg [CL_PKT_TABLE_SIZE-1:0] desc_table_data_fetch_start_pkt;
reg desc_table_data_fetch_start_en;
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
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_cpl_write_ptr;
reg [QUEUE_OP_TAG_WIDTH-1:0] desc_table_cpl_write_queue_op_tag;
reg desc_table_cpl_write_invalid;
reg desc_table_cpl_write_en;
reg [CL_DESC_TABLE_SIZE-1:0] desc_table_cpl_write_done_ptr;
reg desc_table_cpl_write_done_en;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_finish_ptr_reg = 0;
reg desc_table_finish_en;

reg [PKT_TABLE_SIZE-1:0] pkt_table_active = 0;
reg [CL_PKT_TABLE_SIZE-1:0] pkt_table_start_ptr;
reg pkt_table_start_en;
reg [CL_PKT_TABLE_SIZE-1:0] pkt_table_finish_ptr;
reg pkt_table_finish_en;

assign s_axis_tx_req_ready = s_axis_tx_req_ready_reg;

assign m_axis_tx_req_status_len = m_axis_tx_req_status_len_reg;
assign m_axis_tx_req_status_tag = m_axis_tx_req_status_tag_reg;
assign m_axis_tx_req_status_valid = m_axis_tx_req_status_valid_reg;

assign m_axis_desc_dequeue_req_queue = m_axis_desc_dequeue_req_queue_reg;
assign m_axis_desc_dequeue_req_tag = m_axis_desc_dequeue_req_tag_reg;
assign m_axis_desc_dequeue_req_valid = m_axis_desc_dequeue_req_valid_reg;

assign s_axis_desc_dequeue_resp_ready = s_axis_desc_dequeue_resp_ready_reg;

assign m_axis_desc_dequeue_commit_op_tag = m_axis_desc_dequeue_commit_op_tag_reg;
assign m_axis_desc_dequeue_commit_valid = m_axis_desc_dequeue_commit_valid_reg;

assign m_axis_cpl_enqueue_req_queue = m_axis_cpl_enqueue_req_queue_reg;
assign m_axis_cpl_enqueue_req_tag = m_axis_cpl_enqueue_req_tag_reg;
assign m_axis_cpl_enqueue_req_valid = m_axis_cpl_enqueue_req_valid_reg;

assign s_axis_cpl_enqueue_resp_ready = s_axis_cpl_enqueue_resp_ready_reg;

assign m_axis_cpl_enqueue_commit_op_tag = m_axis_cpl_enqueue_commit_op_tag_reg;
assign m_axis_cpl_enqueue_commit_valid = m_axis_cpl_enqueue_commit_valid_reg;

assign m_axis_pcie_axi_dma_read_desc_pcie_addr = m_axis_pcie_axi_dma_read_desc_pcie_addr_reg;
assign m_axis_pcie_axi_dma_read_desc_axi_addr = m_axis_pcie_axi_dma_read_desc_axi_addr_reg;
assign m_axis_pcie_axi_dma_read_desc_len = m_axis_pcie_axi_dma_read_desc_len_reg;
assign m_axis_pcie_axi_dma_read_desc_tag = m_axis_pcie_axi_dma_read_desc_tag_reg;
assign m_axis_pcie_axi_dma_read_desc_valid = m_axis_pcie_axi_dma_read_desc_valid_reg;

assign m_axis_pcie_axi_dma_write_desc_pcie_addr = m_axis_pcie_axi_dma_write_desc_pcie_addr_reg;
assign m_axis_pcie_axi_dma_write_desc_axi_addr = m_axis_pcie_axi_dma_write_desc_axi_addr_reg;
assign m_axis_pcie_axi_dma_write_desc_len = m_axis_pcie_axi_dma_write_desc_len_reg;
assign m_axis_pcie_axi_dma_write_desc_tag = m_axis_pcie_axi_dma_write_desc_tag_reg;
assign m_axis_pcie_axi_dma_write_desc_valid = m_axis_pcie_axi_dma_write_desc_valid_reg;

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

wire [AXI_ID_WIDTH-1:0]   ram_wr_cmd_id;
wire [AXI_ADDR_WIDTH-1:0] ram_wr_cmd_addr;
wire [AXI_DATA_WIDTH-1:0] ram_wr_cmd_data;
wire [AXI_STRB_WIDTH-1:0] ram_wr_cmd_strb;
wire                      ram_wr_cmd_en;

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
    if (ram_wr_cmd_en) begin
        // AXI write
        if (ram_wr_cmd_addr[CL_DESC_TABLE_SIZE+5] == 0) begin
            // descriptors
            // TODO byte enables
            if (TX_CHECKSUM_ENABLE) begin
                desc_table_csum_start[ram_wr_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]] <= ram_wr_cmd_data[23:16];
                desc_table_csum_offset[ram_wr_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]] <= ram_wr_cmd_data[30:24];
                desc_table_csum_enable[ram_wr_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]] <= ram_wr_cmd_data[31];
            end
            desc_table_len[ram_wr_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]] <= ram_wr_cmd_data[64:32];
            desc_table_pcie_addr[ram_wr_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]] <= ram_wr_cmd_data[127:64];
        end
    end

    ram_rd_resp_valid_reg <= ram_rd_resp_valid_reg && !ram_rd_resp_ready;
    ram_rd_cmd_ready_reg <= !ram_rd_resp_valid_reg || ram_rd_resp_ready;

    if (ram_rd_cmd_en && ram_rd_cmd_ready_reg) begin
        // AXI read
        ram_rd_resp_id_reg <= ram_rd_cmd_id;
        ram_rd_resp_data_reg <= 0;
        ram_rd_resp_last_reg <= ram_rd_cmd_last;
        ram_rd_resp_valid_reg <= 1'b1;
        ram_rd_cmd_ready_reg <= ram_rd_resp_ready;

        if (ram_rd_cmd_addr[CL_DESC_TABLE_SIZE+5] == 0) begin
            // descriptors
            ram_rd_resp_data_reg[64:32] <= desc_table_len[ram_rd_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]];
            ram_rd_resp_data_reg[127:64] <= desc_table_pcie_addr[ram_rd_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]];
        end else begin
            // completions
            ram_rd_resp_data_reg[15:0]  <= desc_table_queue[ram_rd_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]];
            ram_rd_resp_data_reg[31:16] <= desc_table_queue_ptr[ram_rd_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]];
            ram_rd_resp_data_reg[47:32] <= desc_table_len[ram_rd_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]];
            if (PTP_TS_ENABLE) begin
                //ram_rd_resp_data_reg[127:64] <= desc_table_ptp_ts[ram_rd_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]] >> 16;
                ram_rd_resp_data_reg[111:64] <= desc_table_ptp_ts[ram_rd_cmd_addr[(CL_DESC_TABLE_SIZE+5)-1:5]] >> 16;
            end
        end
    end

    if (rst) begin
        ram_rd_cmd_ready_reg <= 1'b1;
        ram_rd_resp_valid_reg <= 1'b0;
    end
end

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
//         m_axis_pcie_axi_dma_read_desc_len, m_axis_pcie_axi_dma_read_desc_tag, m_axis_pcie_axi_dma_read_desc_valid, m_axis_pcie_axi_dma_read_desc_ready,
//         s_axis_pcie_axi_dma_read_desc_status_tag, s_axis_pcie_axi_dma_read_desc_status_valid,
//         m_axis_pcie_axi_dma_write_desc_len, m_axis_pcie_axi_dma_write_desc_tag, m_axis_pcie_axi_dma_write_desc_valid, m_axis_pcie_axi_dma_write_desc_ready,
//         s_axis_pcie_axi_dma_write_desc_status_tag, s_axis_pcie_axi_dma_write_desc_status_valid}),
//     .probe1(0),
//     .probe2(0),
//     .probe3(s_axis_tx_req_ready),
//     .probe4({desc_table_start_ptr_reg, desc_table_desc_read_start_ptr_reg, desc_table_data_fetch_start_ptr_reg, desc_table_tx_start_ptr_reg, desc_table_cpl_enqueue_start_ptr_reg, desc_table_finish_ptr_reg, stall_cnt}),
//     .probe5(0)
// );

always @* begin
    s_axis_tx_req_tag_next = s_axis_tx_req_tag_reg;
    s_axis_tx_req_ready_next = 1'b0;

    m_axis_tx_req_status_len_next = m_axis_tx_req_status_len_reg;
    m_axis_tx_req_status_tag_next = m_axis_tx_req_status_tag_reg;
    m_axis_tx_req_status_valid_next = 1'b0;

    m_axis_desc_dequeue_req_queue_next = m_axis_desc_dequeue_req_queue_reg;
    m_axis_desc_dequeue_req_tag_next = m_axis_desc_dequeue_req_tag_reg;
    m_axis_desc_dequeue_req_valid_next = m_axis_desc_dequeue_req_valid_reg && !m_axis_desc_dequeue_req_ready;

    s_axis_desc_dequeue_resp_ready_next = 1'b0;

    m_axis_desc_dequeue_commit_op_tag_next = m_axis_desc_dequeue_commit_op_tag_reg;
    m_axis_desc_dequeue_commit_valid_next = m_axis_desc_dequeue_commit_valid_reg && !m_axis_desc_dequeue_commit_ready;

    m_axis_cpl_enqueue_req_queue_next = m_axis_cpl_enqueue_req_queue_reg;
    m_axis_cpl_enqueue_req_tag_next = m_axis_cpl_enqueue_req_tag_reg;
    m_axis_cpl_enqueue_req_valid_next = m_axis_cpl_enqueue_req_valid_reg && !m_axis_cpl_enqueue_req_ready;

    s_axis_cpl_enqueue_resp_ready_next = 1'b0;

    m_axis_cpl_enqueue_commit_op_tag_next = m_axis_cpl_enqueue_commit_op_tag_reg;
    m_axis_cpl_enqueue_commit_valid_next = m_axis_cpl_enqueue_commit_valid_reg && !m_axis_cpl_enqueue_commit_ready;

    m_axis_pcie_axi_dma_read_desc_pcie_addr_next = m_axis_pcie_axi_dma_read_desc_pcie_addr_reg;
    m_axis_pcie_axi_dma_read_desc_axi_addr_next = m_axis_pcie_axi_dma_read_desc_axi_addr_reg;
    m_axis_pcie_axi_dma_read_desc_len_next = m_axis_pcie_axi_dma_read_desc_len_reg;
    m_axis_pcie_axi_dma_read_desc_tag_next = m_axis_pcie_axi_dma_read_desc_tag_reg;
    m_axis_pcie_axi_dma_read_desc_valid_next = m_axis_pcie_axi_dma_read_desc_valid_reg && !m_axis_pcie_axi_dma_read_desc_ready;

    m_axis_pcie_axi_dma_write_desc_pcie_addr_next = m_axis_pcie_axi_dma_write_desc_pcie_addr_reg;
    m_axis_pcie_axi_dma_write_desc_axi_addr_next = m_axis_pcie_axi_dma_write_desc_axi_addr_reg;
    m_axis_pcie_axi_dma_write_desc_len_next = m_axis_pcie_axi_dma_write_desc_len_reg;
    m_axis_pcie_axi_dma_write_desc_tag_next = m_axis_pcie_axi_dma_write_desc_tag_reg;
    m_axis_pcie_axi_dma_write_desc_valid_next = m_axis_pcie_axi_dma_write_desc_valid_reg && !m_axis_pcie_axi_dma_write_desc_ready;

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

    early_tx_req_status_len_next = early_tx_req_status_len_reg;
    early_tx_req_status_tag_next = early_tx_req_status_tag_reg;
    early_tx_req_status_valid_next = early_tx_req_status_valid_reg;

    finish_tx_req_status_len_next = finish_tx_req_status_len_reg;
    finish_tx_req_status_tag_next = finish_tx_req_status_tag_reg;
    finish_tx_req_status_valid_next = finish_tx_req_status_valid_reg;

    desc_fetch_pcie_axi_dma_read_desc_pcie_addr_next = desc_fetch_pcie_axi_dma_read_desc_pcie_addr_reg;
    desc_fetch_pcie_axi_dma_read_desc_axi_addr_next = desc_fetch_pcie_axi_dma_read_desc_axi_addr_reg;
    desc_fetch_pcie_axi_dma_read_desc_len_next = desc_fetch_pcie_axi_dma_read_desc_len_reg;
    desc_fetch_pcie_axi_dma_read_desc_tag_next = desc_fetch_pcie_axi_dma_read_desc_tag_reg;
    desc_fetch_pcie_axi_dma_read_desc_valid_next = desc_fetch_pcie_axi_dma_read_desc_valid_reg;

    pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_next = pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_reg;
    pkt_fetch_pcie_axi_dma_read_desc_axi_addr_next = pkt_fetch_pcie_axi_dma_read_desc_axi_addr_reg;
    pkt_fetch_pcie_axi_dma_read_desc_len_next = pkt_fetch_pcie_axi_dma_read_desc_len_reg;
    pkt_fetch_pcie_axi_dma_read_desc_tag_next = pkt_fetch_pcie_axi_dma_read_desc_tag_reg;
    pkt_fetch_pcie_axi_dma_read_desc_valid_next = pkt_fetch_pcie_axi_dma_read_desc_valid_reg;

    inc_active = 1'b0;
    dec_active_1 = 1'b0;
    dec_active_2 = 1'b0;

    desc_table_start_tag = s_axis_desc_dequeue_resp_tag;
    desc_table_start_queue = s_axis_desc_dequeue_resp_queue;
    desc_table_start_queue_ptr = s_axis_desc_dequeue_resp_ptr;
    desc_table_start_cpl_queue = s_axis_desc_dequeue_resp_cpl;
    desc_table_start_queue_op_tag = s_axis_desc_dequeue_resp_op_tag;
    desc_table_start_en = 1'b0;
    desc_table_desc_fetched_ptr = s_axis_pcie_axi_dma_read_desc_status_tag & DESC_PTR_MASK;
    desc_table_desc_fetched_en = 1'b0;
    desc_table_data_fetch_start_pkt = 0;
    desc_table_data_fetch_start_en = 1'b0;
    desc_table_data_fetched_ptr = s_axis_pcie_axi_dma_read_desc_status_tag & DESC_PTR_MASK;
    desc_table_data_fetched_en = 1'b0;
    desc_table_tx_start_en = 1'b0;
    desc_table_tx_finish_ptr = s_axis_tx_desc_status_tag;
    desc_table_tx_finish_en = 1'b0;
    desc_table_store_ptp_ts = s_axis_tx_ptp_ts_96;
    desc_table_store_ptp_ts_en = 1'b0;
    desc_table_cpl_enqueue_start_en = 1'b0;
    desc_table_cpl_write_ptr = s_axis_cpl_enqueue_resp_tag & DESC_PTR_MASK;
    desc_table_cpl_write_queue_op_tag = s_axis_cpl_enqueue_resp_op_tag;
    desc_table_cpl_write_invalid = 1'b0;
    desc_table_cpl_write_en = 1'b0;
    desc_table_cpl_write_done_ptr = s_axis_pcie_axi_dma_write_desc_status_tag & DESC_PTR_MASK;
    desc_table_cpl_write_done_en = 1'b0;
    desc_table_finish_en = 1'b0;

    pkt_table_start_ptr = pkt_table_free_ptr;
    pkt_table_start_en = 1'b0;
    pkt_table_finish_ptr = desc_table_pkt[s_axis_tx_desc_status_tag & DESC_PTR_MASK];
    pkt_table_finish_en = 1'b0;

    // queue query
    // wait for transmit request
    s_axis_tx_req_ready_next = enable && active_count_reg < DESC_TABLE_SIZE && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE) && (!m_axis_desc_dequeue_req_valid_reg || m_axis_desc_dequeue_req_ready);
    if (s_axis_tx_req_ready && s_axis_tx_req_valid) begin
        s_axis_tx_req_ready_next = 1'b0;

        // initiate queue query
        m_axis_desc_dequeue_req_queue_next = s_axis_tx_req_queue;
        m_axis_desc_dequeue_req_tag_next = s_axis_tx_req_tag;
        m_axis_desc_dequeue_req_valid_next = 1'b1;

        inc_active = 1'b1;
    end

    // descriptor fetch
    // wait for queue query response
    s_axis_desc_dequeue_resp_ready_next = !desc_fetch_pcie_axi_dma_read_desc_valid_reg && !desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] && ($unsigned(desc_table_start_ptr_reg - desc_table_finish_ptr_reg) < DESC_TABLE_SIZE);
    if (s_axis_desc_dequeue_resp_ready && s_axis_desc_dequeue_resp_valid) begin
        s_axis_desc_dequeue_resp_ready_next = 1'b0;

        // store in descriptor table
        desc_table_start_tag = s_axis_desc_dequeue_resp_tag;
        desc_table_start_queue = s_axis_desc_dequeue_resp_queue;
        desc_table_start_queue_ptr = s_axis_desc_dequeue_resp_ptr;
        desc_table_start_cpl_queue = s_axis_desc_dequeue_resp_cpl;
        desc_table_start_queue_op_tag = s_axis_desc_dequeue_resp_op_tag;

        if (s_axis_desc_dequeue_resp_error || s_axis_desc_dequeue_resp_empty) begin
            // queue empty or not active

            // return transmit request completion
            early_tx_req_status_len_next = 0;
            early_tx_req_status_tag_next = s_axis_desc_dequeue_resp_tag;
            early_tx_req_status_valid_next = 1'b1;

            dec_active_1 = 1'b1;
        end else begin
            // descriptor available to dequeue
            
            // store in descriptor table
            desc_table_start_en = 1'b1;

            // initiate descriptor fetch to onboard RAM
            desc_fetch_pcie_axi_dma_read_desc_pcie_addr_next = s_axis_desc_dequeue_resp_addr;
            desc_fetch_pcie_axi_dma_read_desc_axi_addr_next = AXI_BASE_ADDR + ((desc_table_start_ptr_reg & DESC_PTR_MASK) << 5);
            desc_fetch_pcie_axi_dma_read_desc_len_next = DESC_SIZE;
            desc_fetch_pcie_axi_dma_read_desc_tag_next = (desc_table_start_ptr_reg & DESC_PTR_MASK);
            desc_fetch_pcie_axi_dma_read_desc_valid_next = 1'b1;
        end
    end

    // descriptor fetch completion
    // wait for descriptor fetch completion
    if (s_axis_pcie_axi_dma_read_desc_status_valid && !(s_axis_pcie_axi_dma_read_desc_status_tag & DATA_FLAG)) begin
        // update entry in descriptor table
        desc_table_desc_fetched_ptr = s_axis_pcie_axi_dma_read_desc_status_tag & DESC_PTR_MASK;
        desc_table_desc_fetched_en = 1'b1;
    end

    // data fetch
    // wait for descriptor fetch completion
    // TODO descriptor validation?
    if (desc_table_active[desc_table_data_fetch_start_ptr_reg & DESC_PTR_MASK] && desc_table_data_fetch_start_ptr_reg != desc_table_start_ptr_reg && desc_table_data_fetch_start_ptr_reg == desc_table_tx_start_ptr_reg) begin
        if (desc_table_invalid[desc_table_data_fetch_start_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_data_fetch_start_en = 1'b1;
        end else if (desc_table_desc_fetched[desc_table_data_fetch_start_ptr_reg & DESC_PTR_MASK] && pkt_table_free_ptr_valid && !pkt_fetch_pcie_axi_dma_read_desc_valid_reg) begin
            // update entry in descriptor table
            desc_table_data_fetch_start_pkt = pkt_table_free_ptr;
            desc_table_data_fetch_start_en = 1'b1;

            // store in packet table
            pkt_table_start_ptr = pkt_table_free_ptr;
            pkt_table_start_en = 1'b1;

            // initiate data fetch to onboard RAM
            pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_next = desc_table_pcie_addr[desc_table_data_fetch_start_ptr_reg & DESC_PTR_MASK];
            pkt_fetch_pcie_axi_dma_read_desc_axi_addr_next = SCRATCH_PKT_AXI_ADDR + (pkt_table_free_ptr << SCRATCH_PKT_AXI_ADDR_SHIFT);
            pkt_fetch_pcie_axi_dma_read_desc_len_next = desc_table_len[desc_table_data_fetch_start_ptr_reg & DESC_PTR_MASK];
            pkt_fetch_pcie_axi_dma_read_desc_tag_next = (desc_table_data_fetch_start_ptr_reg & DESC_PTR_MASK) | DATA_FLAG;
            pkt_fetch_pcie_axi_dma_read_desc_valid_next = 1'b1;
        end
    end

    // data fetch completion
    // wait for data fetch completion
    if (s_axis_pcie_axi_dma_read_desc_status_valid && (s_axis_pcie_axi_dma_read_desc_status_tag & DATA_FLAG)) begin
        // update entry in descriptor table
        desc_table_data_fetched_ptr = s_axis_pcie_axi_dma_read_desc_status_tag & DESC_PTR_MASK;
        desc_table_data_fetched_en = 1'b1;
    end

    // transmit
    // wait for data fetch completion
    if (desc_table_active[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] && desc_table_tx_start_ptr_reg != desc_table_start_ptr_reg && desc_table_tx_start_ptr_reg != desc_table_data_fetch_start_ptr_reg) begin
        if (desc_table_invalid[desc_table_tx_start_ptr_reg & DESC_PTR_MASK]) begin
            // invalid entry; skip
            desc_table_tx_start_en = 1'b1;
        end else if (desc_table_data_fetched[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] && !m_axis_tx_desc_valid && (!m_axis_tx_csum_cmd_valid || !TX_CHECKSUM_ENABLE)) begin
            // update entry in descriptor table
            desc_table_tx_start_en = 1'b1;

            // initiate transmit operation
            m_axis_tx_desc_addr_next = SCRATCH_PKT_AXI_ADDR + (desc_table_pkt[desc_table_tx_start_ptr_reg & DESC_PTR_MASK] << SCRATCH_PKT_AXI_ADDR_SHIFT);
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

        // invalidate entry in packet table
        pkt_table_finish_ptr = desc_table_pkt[s_axis_tx_desc_status_tag & DESC_PTR_MASK];
        pkt_table_finish_en = 1'b1;
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
        end else if (desc_table_tx_done[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK] && !m_axis_desc_dequeue_commit_valid && !m_axis_cpl_enqueue_req_valid_next && !m_axis_pcie_axi_dma_write_desc_valid_reg) begin
            // update entry in descriptor table
            desc_table_cpl_enqueue_start_en = 1'b1;

            // initiate queue query
            m_axis_cpl_enqueue_req_queue_next = desc_table_cpl_queue[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_enqueue_req_tag_next = desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK;
            m_axis_cpl_enqueue_req_valid_next = 1'b1;

            // commit dequeue operation
            m_axis_desc_dequeue_commit_op_tag_next = desc_table_queue_op_tag[desc_table_cpl_enqueue_start_ptr_reg & DESC_PTR_MASK];
            m_axis_desc_dequeue_commit_valid_next = 1'b1;
        end
    end

    // start completion write
    // wait for queue query response
    s_axis_cpl_enqueue_resp_ready_next = !m_axis_pcie_axi_dma_write_desc_valid_reg;
    if (s_axis_cpl_enqueue_resp_ready && s_axis_cpl_enqueue_resp_valid) begin
        s_axis_cpl_enqueue_resp_ready_next = 1'b0;

        // update entry in descriptor table
        desc_table_cpl_write_ptr = s_axis_cpl_enqueue_resp_tag & DESC_PTR_MASK;
        desc_table_cpl_write_queue_op_tag = s_axis_cpl_enqueue_resp_op_tag;
        desc_table_cpl_write_invalid = 1'b0;
        desc_table_cpl_write_en = 1'b1;

        if (s_axis_cpl_enqueue_resp_error || s_axis_cpl_enqueue_resp_full) begin
            // queue full or not active
            // TODO retry if queue full?

            // invalidate entry
            desc_table_cpl_write_invalid = 1'b1;
        end else begin
            // space for completion available in queue

            // initiate completion write from onboard RAM
            m_axis_pcie_axi_dma_write_desc_pcie_addr_next = s_axis_cpl_enqueue_resp_addr;
            m_axis_pcie_axi_dma_write_desc_axi_addr_next = AXI_BASE_ADDR + ((s_axis_cpl_enqueue_resp_tag & DESC_PTR_MASK) + 2**CL_DESC_TABLE_SIZE << 5);
            m_axis_pcie_axi_dma_write_desc_len_next = CPL_SIZE;
            m_axis_pcie_axi_dma_write_desc_tag_next = s_axis_cpl_enqueue_resp_tag & DESC_PTR_MASK;
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
    if (desc_table_active[desc_table_finish_ptr_reg & DESC_PTR_MASK] && desc_table_finish_ptr_reg != desc_table_start_ptr_reg && desc_table_finish_ptr_reg != desc_table_cpl_enqueue_start_ptr_reg && !finish_tx_req_status_valid_reg) begin
        if (desc_table_invalid[desc_table_finish_ptr_reg & DESC_PTR_MASK]) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            // return transmit request completion
            m_axis_tx_req_status_len_next = 0;
            m_axis_tx_req_status_tag_next = desc_table_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_tx_req_status_valid_next = 1'b1;

            dec_active_2 = 1'b1;
        end else if (desc_table_cpl_write_done[desc_table_finish_ptr_reg & DESC_PTR_MASK] && !m_axis_cpl_enqueue_commit_valid) begin
            // invalidate entry in descriptor table
            desc_table_finish_en = 1'b1;

            // commit enqueue operation
            m_axis_cpl_enqueue_commit_op_tag_next = desc_table_cpl_queue_op_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            m_axis_cpl_enqueue_commit_valid_next = 1'b1;

            // return transmit request completion
            finish_tx_req_status_len_next = desc_table_len[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            finish_tx_req_status_tag_next = desc_table_tag[desc_table_finish_ptr_reg & DESC_PTR_MASK];
            finish_tx_req_status_valid_next = 1'b1;

            dec_active_2 = 1'b1;
        end
    end

    // PCIe AXI DMA read request arbitration
    if (desc_fetch_pcie_axi_dma_read_desc_valid_next && (!m_axis_pcie_axi_dma_read_desc_valid_reg || m_axis_pcie_axi_dma_read_desc_ready)) begin
        m_axis_pcie_axi_dma_read_desc_pcie_addr_next = desc_fetch_pcie_axi_dma_read_desc_pcie_addr_next;
        m_axis_pcie_axi_dma_read_desc_axi_addr_next = desc_fetch_pcie_axi_dma_read_desc_axi_addr_next;
        m_axis_pcie_axi_dma_read_desc_len_next = desc_fetch_pcie_axi_dma_read_desc_len_next;
        m_axis_pcie_axi_dma_read_desc_tag_next = desc_fetch_pcie_axi_dma_read_desc_tag_next;
        m_axis_pcie_axi_dma_read_desc_valid_next = 1'b1;
        desc_fetch_pcie_axi_dma_read_desc_valid_next = 1'b0;
    end else if (pkt_fetch_pcie_axi_dma_read_desc_valid_next && (!m_axis_pcie_axi_dma_read_desc_valid_reg || m_axis_pcie_axi_dma_read_desc_ready)) begin
        m_axis_pcie_axi_dma_read_desc_pcie_addr_next = pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_next;
        m_axis_pcie_axi_dma_read_desc_axi_addr_next = pkt_fetch_pcie_axi_dma_read_desc_axi_addr_next;
        m_axis_pcie_axi_dma_read_desc_len_next = pkt_fetch_pcie_axi_dma_read_desc_len_next;
        m_axis_pcie_axi_dma_read_desc_tag_next = pkt_fetch_pcie_axi_dma_read_desc_tag_next;
        m_axis_pcie_axi_dma_read_desc_valid_next = 1'b1;
        pkt_fetch_pcie_axi_dma_read_desc_valid_next = 1'b0;
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
    if (rst) begin
        s_axis_tx_req_ready_reg <= 1'b0;
        m_axis_tx_req_status_valid_reg <= 1'b0;
        m_axis_desc_dequeue_req_valid_reg <= 1'b0;
        s_axis_desc_dequeue_resp_ready_reg <= 1'b0;
        m_axis_desc_dequeue_commit_valid_reg <= 1'b0;
        m_axis_cpl_enqueue_req_valid_reg <= 1'b0;
        s_axis_cpl_enqueue_resp_ready_reg <= 1'b0;
        m_axis_cpl_enqueue_commit_valid_reg <= 1'b0;
        m_axis_pcie_axi_dma_read_desc_valid_reg <= 1'b0;
        m_axis_pcie_axi_dma_write_desc_valid_reg <= 1'b0;
        m_axis_tx_desc_valid_reg <= 1'b0;
        s_axis_tx_ptp_ts_ready_reg <= 1'b0;
        m_axis_tx_csum_cmd_valid_reg <= 1'b0;

        early_tx_req_status_valid_reg <= 1'b0;
        finish_tx_req_status_valid_reg <= 1'b0;
        desc_fetch_pcie_axi_dma_read_desc_valid_reg <= 1'b0;
        pkt_fetch_pcie_axi_dma_read_desc_valid_reg <= 1'b0;

        active_count_reg <= 0;

        desc_table_active <= 0;
        desc_table_invalid <= 0;
        desc_table_desc_fetched <= 0;
        desc_table_data_fetched <= 0;
        desc_table_tx_done <= 0;

        desc_table_start_ptr_reg <= 0;
        desc_table_data_fetch_start_ptr_reg <= 0;
        desc_table_tx_start_ptr_reg <= 0;
        desc_table_store_ptp_ts_ptr_reg <= 0;
        desc_table_cpl_enqueue_start_ptr_reg <= 0;
        desc_table_finish_ptr_reg <= 0;

        pkt_table_active <= 0;
    end else begin
        s_axis_tx_req_ready_reg <= s_axis_tx_req_ready_next;
        m_axis_tx_req_status_valid_reg <= m_axis_tx_req_status_valid_next;
        m_axis_desc_dequeue_req_valid_reg <= m_axis_desc_dequeue_req_valid_next;
        s_axis_desc_dequeue_resp_ready_reg <= s_axis_desc_dequeue_resp_ready_next;
        m_axis_desc_dequeue_commit_valid_reg <= m_axis_desc_dequeue_commit_valid_next;
        m_axis_cpl_enqueue_req_valid_reg <= m_axis_cpl_enqueue_req_valid_next;
        s_axis_cpl_enqueue_resp_ready_reg <= s_axis_cpl_enqueue_resp_ready_next;
        m_axis_cpl_enqueue_commit_valid_reg <= m_axis_cpl_enqueue_commit_valid_next;
        m_axis_pcie_axi_dma_read_desc_valid_reg <= m_axis_pcie_axi_dma_read_desc_valid_next;
        m_axis_pcie_axi_dma_write_desc_valid_reg <= m_axis_pcie_axi_dma_write_desc_valid_next;
        m_axis_tx_desc_valid_reg <= m_axis_tx_desc_valid_next;
        s_axis_tx_ptp_ts_ready_reg <= s_axis_tx_ptp_ts_ready_next;
        m_axis_tx_csum_cmd_valid_reg <= m_axis_tx_csum_cmd_valid_next;

        early_tx_req_status_valid_reg <= early_tx_req_status_valid_next;
        finish_tx_req_status_valid_reg <= finish_tx_req_status_valid_next;
        desc_fetch_pcie_axi_dma_read_desc_valid_reg <= desc_fetch_pcie_axi_dma_read_desc_valid_next;
        pkt_fetch_pcie_axi_dma_read_desc_valid_reg <= pkt_fetch_pcie_axi_dma_read_desc_valid_next;
        
        active_count_reg <= active_count_reg + inc_active - dec_active_1 - dec_active_2;

        if (desc_table_start_en) begin
            desc_table_active[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b1;
            desc_table_invalid[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_desc_fetched[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_data_fetched[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_tx_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_cpl_write_done[desc_table_start_ptr_reg & DESC_PTR_MASK] <= 1'b0;
            desc_table_start_ptr_reg <= desc_table_start_ptr_reg + 1;
        end
        if (desc_table_desc_fetched_en) begin
            desc_table_desc_fetched[desc_table_desc_fetched_ptr & DESC_PTR_MASK] <= 1'b1;
        end
        if (desc_table_data_fetch_start_en) begin
            desc_table_data_fetch_start_ptr_reg <= desc_table_data_fetch_start_ptr_reg + 1;
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
            desc_table_store_ptp_ts_ptr_reg <= desc_table_store_ptp_ts_ptr_reg + 1;
        end
        if (desc_table_cpl_enqueue_start_en) begin
            desc_table_cpl_enqueue_start_ptr_reg <= desc_table_cpl_enqueue_start_ptr_reg + 1;
        end
        if (desc_table_cpl_write_en) begin
            if (desc_table_cpl_write_invalid) begin
                desc_table_invalid[desc_table_cpl_write_ptr & DESC_PTR_MASK] <= 1'b1;
            end
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

    s_axis_tx_req_tag_reg <= s_axis_tx_req_tag_next;

    m_axis_tx_req_status_len_reg <= m_axis_tx_req_status_len_next;
    m_axis_tx_req_status_tag_reg <= m_axis_tx_req_status_tag_next;

    m_axis_desc_dequeue_req_queue_reg <= m_axis_desc_dequeue_req_queue_next;
    m_axis_desc_dequeue_req_tag_reg <= m_axis_desc_dequeue_req_tag_next;
    m_axis_desc_dequeue_commit_op_tag_reg <= m_axis_desc_dequeue_commit_op_tag_next;
    m_axis_cpl_enqueue_req_queue_reg <= m_axis_cpl_enqueue_req_queue_next;
    m_axis_cpl_enqueue_req_tag_reg <= m_axis_cpl_enqueue_req_tag_next;
    m_axis_cpl_enqueue_commit_op_tag_reg <= m_axis_cpl_enqueue_commit_op_tag_next;

    m_axis_pcie_axi_dma_read_desc_pcie_addr_reg <= m_axis_pcie_axi_dma_read_desc_pcie_addr_next;
    m_axis_pcie_axi_dma_read_desc_axi_addr_reg <= m_axis_pcie_axi_dma_read_desc_axi_addr_next;
    m_axis_pcie_axi_dma_read_desc_len_reg <= m_axis_pcie_axi_dma_read_desc_len_next;
    m_axis_pcie_axi_dma_read_desc_tag_reg <= m_axis_pcie_axi_dma_read_desc_tag_next;

    m_axis_pcie_axi_dma_write_desc_pcie_addr_reg <= m_axis_pcie_axi_dma_write_desc_pcie_addr_next;
    m_axis_pcie_axi_dma_write_desc_axi_addr_reg <= m_axis_pcie_axi_dma_write_desc_axi_addr_next;
    m_axis_pcie_axi_dma_write_desc_len_reg <= m_axis_pcie_axi_dma_write_desc_len_next;
    m_axis_pcie_axi_dma_write_desc_tag_reg <= m_axis_pcie_axi_dma_write_desc_tag_next;

    m_axis_tx_desc_addr_reg <= m_axis_tx_desc_addr_next;
    m_axis_tx_desc_len_reg <= m_axis_tx_desc_len_next;
    m_axis_tx_desc_tag_reg <= m_axis_tx_desc_tag_next;
    m_axis_tx_desc_user_reg <= m_axis_tx_desc_user_next;

    m_axis_tx_csum_cmd_csum_enable_reg <= m_axis_tx_csum_cmd_csum_enable_next;
    m_axis_tx_csum_cmd_csum_start_reg <= m_axis_tx_csum_cmd_csum_start_next;
    m_axis_tx_csum_cmd_csum_offset_reg <= m_axis_tx_csum_cmd_csum_offset_next;

    early_tx_req_status_len_reg <= early_tx_req_status_len_next;
    early_tx_req_status_tag_reg <= early_tx_req_status_tag_next;

    finish_tx_req_status_len_reg <= finish_tx_req_status_len_next;
    finish_tx_req_status_tag_reg <= finish_tx_req_status_tag_next;

    desc_fetch_pcie_axi_dma_read_desc_pcie_addr_reg <= desc_fetch_pcie_axi_dma_read_desc_pcie_addr_next;
    desc_fetch_pcie_axi_dma_read_desc_axi_addr_reg <= desc_fetch_pcie_axi_dma_read_desc_axi_addr_next;
    desc_fetch_pcie_axi_dma_read_desc_len_reg <= desc_fetch_pcie_axi_dma_read_desc_len_next;
    desc_fetch_pcie_axi_dma_read_desc_tag_reg <= desc_fetch_pcie_axi_dma_read_desc_tag_next;

    pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_reg <= pkt_fetch_pcie_axi_dma_read_desc_pcie_addr_next;
    pkt_fetch_pcie_axi_dma_read_desc_axi_addr_reg <= pkt_fetch_pcie_axi_dma_read_desc_axi_addr_next;
    pkt_fetch_pcie_axi_dma_read_desc_len_reg <= pkt_fetch_pcie_axi_dma_read_desc_len_next;
    pkt_fetch_pcie_axi_dma_read_desc_tag_reg <= pkt_fetch_pcie_axi_dma_read_desc_tag_next;

    if (desc_table_start_en) begin
        desc_table_queue[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_queue;
        desc_table_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_tag;
        desc_table_queue_ptr[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_queue_ptr;
        desc_table_cpl_queue[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_cpl_queue;
        desc_table_queue_op_tag[desc_table_start_ptr_reg & DESC_PTR_MASK] <= desc_table_start_queue_op_tag;
    end
    if (desc_table_data_fetch_start_en) begin
        desc_table_pkt[desc_table_data_fetch_start_ptr_reg & DESC_PTR_MASK] <= desc_table_data_fetch_start_pkt;
    end
    if (desc_table_store_ptp_ts_en) begin
        desc_table_ptp_ts[desc_table_store_ptp_ts_ptr_reg & DESC_PTR_MASK] <= desc_table_store_ptp_ts;
    end
    if (desc_table_cpl_write_en) begin
        desc_table_cpl_queue_op_tag[desc_table_cpl_write_ptr & DESC_PTR_MASK] <= desc_table_cpl_write_queue_op_tag;
    end
end

endmodule
