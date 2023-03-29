/*

Copyright (c) 2023 Alex Forencich

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
 * AXI4 virtual FIFO (raw, write side)
 */
module axi_vfifo_raw_wr #
(
    // Width of input segment
    parameter SEG_WIDTH = 32,
    // Segment count
    parameter SEG_CNT = 2,
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = SEG_WIDTH*SEG_CNT,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
    // Width of length field
    parameter LEN_WIDTH = AXI_ADDR_WIDTH,
    // Input FIFO depth for AXI write data (full-width words)
    parameter WRITE_FIFO_DEPTH = 64,
    // Max AXI write burst length
    parameter WRITE_MAX_BURST_LEN = WRITE_FIFO_DEPTH/4,
    // Watermark level
    parameter WATERMARK_LEVEL = WRITE_FIFO_DEPTH/2
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Segmented data input (from encode logic)
     */
    input  wire                          input_clk,
    input  wire                          input_rst,
    output wire                          input_rst_out,
    output wire                          input_watermark,
    input  wire [SEG_CNT*SEG_WIDTH-1:0]  input_data,
    input  wire [SEG_CNT-1:0]            input_valid,
    output wire [SEG_CNT-1:0]            input_ready,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]       m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]     m_axi_awaddr,
    output wire [7:0]                    m_axi_awlen,
    output wire [2:0]                    m_axi_awsize,
    output wire [1:0]                    m_axi_awburst,
    output wire                          m_axi_awlock,
    output wire [3:0]                    m_axi_awcache,
    output wire [2:0]                    m_axi_awprot,
    output wire                          m_axi_awvalid,
    input  wire                          m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]     m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]     m_axi_wstrb,
    output wire                          m_axi_wlast,
    output wire                          m_axi_wvalid,
    input  wire                          m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]       m_axi_bid,
    input  wire [1:0]                    m_axi_bresp,
    input  wire                          m_axi_bvalid,
    output wire                          m_axi_bready,

    /*
     * FIFO control
     */
    output wire [LEN_WIDTH+1-1:0]        wr_start_ptr_out,
    output wire [LEN_WIDTH+1-1:0]        wr_finish_ptr_out,
    input  wire [LEN_WIDTH+1-1:0]        rd_start_ptr_in,
    input  wire [LEN_WIDTH+1-1:0]        rd_finish_ptr_in,

    /*
     * Configuration
     */
    input  wire [AXI_ADDR_WIDTH-1:0]     cfg_fifo_base_addr,
    input  wire [LEN_WIDTH-1:0]          cfg_fifo_size_mask,
    input  wire                          cfg_enable,
    input  wire                          cfg_reset,

    /*
     * Status
     */
    output wire [LEN_WIDTH+1-1:0]        sts_fifo_occupancy,
    output wire                          sts_fifo_empty,
    output wire                          sts_fifo_full,
    output wire                          sts_write_active
);

localparam AXI_BYTE_LANES = AXI_STRB_WIDTH;
localparam AXI_BYTE_SIZE = AXI_DATA_WIDTH/AXI_BYTE_LANES;
localparam AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
localparam AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

localparam OFFSET_ADDR_WIDTH = AXI_STRB_WIDTH > 1 ? $clog2(AXI_STRB_WIDTH) : 1;
localparam OFFSET_ADDR_MASK = AXI_STRB_WIDTH > 1 ? {OFFSET_ADDR_WIDTH{1'b1}} : 0;
localparam ADDR_MASK = {AXI_ADDR_WIDTH{1'b1}} << $clog2(AXI_STRB_WIDTH);
localparam CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1;

localparam WRITE_FIFO_ADDR_WIDTH = $clog2(WRITE_FIFO_DEPTH);
localparam RESP_FIFO_ADDR_WIDTH = 5;

// mask(x) = (2**$clog2(x))-1
// log2(min(x, y, z)) = (mask & mask & mask)+1
// floor(log2(x)) = $clog2(x+1)-1
// floor(log2(min(AXI_MAX_BURST_LEN, WRITE_MAX_BURST_LEN, 2**(WRITE_FIFO_ADDR_WIDTH-1), 4096/AXI_BYTE_LANES)))
localparam WRITE_MAX_BURST_LEN_INT = ((2**($clog2(AXI_MAX_BURST_LEN+1)-1)-1) & (2**($clog2(WRITE_MAX_BURST_LEN+1)-1)-1) & (2**(WRITE_FIFO_ADDR_WIDTH-1)-1) & ((4096/AXI_BYTE_LANES)-1)) + 1;
localparam WRITE_MAX_BURST_SIZE_INT = WRITE_MAX_BURST_LEN_INT << AXI_BURST_SIZE;
localparam WRITE_BURST_LEN_WIDTH = $clog2(WRITE_MAX_BURST_LEN_INT);
localparam WRITE_BURST_ADDR_WIDTH = $clog2(WRITE_MAX_BURST_SIZE_INT);
localparam WRITE_BURST_ADDR_MASK = WRITE_BURST_ADDR_WIDTH > 1 ? {WRITE_BURST_ADDR_WIDTH{1'b1}} : 0;

// validate parameters
initial begin
    if (AXI_BYTE_SIZE * AXI_STRB_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisible (instance %m)");
        $finish;
    end

    if (2**$clog2(AXI_BYTE_LANES) != AXI_BYTE_LANES) begin
        $error("Error: AXI byte lane count must be even power of two (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
        $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
        $finish;
    end

    if (SEG_CNT * SEG_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: Width mismatch (instance %m)");
        $finish;
    end
end

localparam [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_awaddr_next;
reg [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
reg m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;
reg [AXI_DATA_WIDTH-1:0] m_axi_wdata_reg = {AXI_DATA_WIDTH{1'b0}}, m_axi_wdata_next;
reg [AXI_STRB_WIDTH-1:0] m_axi_wstrb_reg = {AXI_STRB_WIDTH{1'b0}}, m_axi_wstrb_next;
reg m_axi_wlast_reg = 1'b0, m_axi_wlast_next;
reg m_axi_wvalid_reg = 1'b0, m_axi_wvalid_next;
reg m_axi_bready_reg = 1'b0, m_axi_bready_next;

assign m_axi_awid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_awaddr = m_axi_awaddr_reg;
assign m_axi_awlen = m_axi_awlen_reg;
assign m_axi_awsize = AXI_BURST_SIZE;
assign m_axi_awburst = 2'b01;
assign m_axi_awlock = 1'b0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot = 3'b010;
assign m_axi_awvalid = m_axi_awvalid_reg;
assign m_axi_wdata = m_axi_wdata_reg;
assign m_axi_wstrb = m_axi_wstrb_reg;
assign m_axi_wvalid = m_axi_wvalid_reg;
assign m_axi_wlast = m_axi_wlast_reg;
assign m_axi_bready = m_axi_bready_reg;

// reset synchronization
wire rst_req_int = cfg_reset;

(* shreg_extract = "no" *)
reg rst_sync_1_reg = 1'b1,  rst_sync_2_reg = 1'b1, rst_sync_3_reg = 1'b1;

assign input_rst_out = rst_sync_3_reg;

always @(posedge input_clk or posedge rst_req_int) begin
    if (rst_req_int) begin
        rst_sync_1_reg <= 1'b1;
    end else begin
        rst_sync_1_reg <= 1'b0;
    end
end

always @(posedge input_clk) begin
    rst_sync_2_reg <= rst_sync_1_reg;
    rst_sync_3_reg <= rst_sync_2_reg;
end

// input datapath logic (write data)
wire [AXI_DATA_WIDTH-1:0] input_data_int;
reg input_valid_int_reg = 1'b0;

reg input_read_en;

wire [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_wr_ptr;
wire [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_wr_ptr_gray;
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_rd_ptr_reg = 0;
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_rd_ptr_gray_reg = 0;

reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_rd_ptr_temp;

(* shreg_extract = "no" *)
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_wr_ptr_gray_sync_1_reg = 0;
(* shreg_extract = "no" *)
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_wr_ptr_gray_sync_2_reg = 0;
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_wr_ptr_sync_reg = 0;

(* shreg_extract = "no" *)
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_rd_ptr_gray_sync_1_reg = 0;
(* shreg_extract = "no" *)
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_rd_ptr_gray_sync_2_reg = 0;
reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_rd_ptr_sync_reg = 0;

reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] write_fifo_occupancy_reg = 0;

wire [SEG_CNT-1:0] write_fifo_seg_full;
wire [SEG_CNT-1:0] write_fifo_seg_empty;
wire [SEG_CNT-1:0] write_fifo_seg_watermark;

wire write_fifo_full = |write_fifo_seg_full;
wire write_fifo_empty = |write_fifo_seg_empty;

assign input_watermark = |write_fifo_seg_watermark | input_rst_out;

genvar n;
integer k;

generate

for (n = 0; n < SEG_CNT; n = n + 1) begin : write_fifo_seg

    reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] seg_wr_ptr_reg = 0;
    reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] seg_wr_ptr_gray_reg = 0;

    reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] seg_wr_ptr_temp;

    reg [WRITE_FIFO_ADDR_WIDTH+1-1:0] seg_occupancy_reg = 0;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEG_WIDTH-1:0] seg_mem_data[2**WRITE_FIFO_ADDR_WIDTH-1:0];

    reg [SEG_WIDTH-1:0] seg_rd_data_reg = 0;

    wire seg_full = seg_wr_ptr_gray_reg == (write_fifo_rd_ptr_gray_sync_2_reg ^ {2'b11, {WRITE_FIFO_ADDR_WIDTH-1{1'b0}}});
    wire seg_empty = write_fifo_rd_ptr_reg == write_fifo_wr_ptr_sync_reg;
    wire seg_watermark = seg_occupancy_reg > WATERMARK_LEVEL;

    assign input_data_int[n*SEG_WIDTH +: SEG_WIDTH] = seg_rd_data_reg;

    assign input_ready[n] = !seg_full && !input_rst_out;

    assign write_fifo_seg_full[n] = seg_full;
    assign write_fifo_seg_empty[n] = seg_empty;
    assign write_fifo_seg_watermark[n] = seg_watermark;

    if (n == SEG_CNT-1) begin
        assign write_fifo_wr_ptr = seg_wr_ptr_reg;
        assign write_fifo_wr_ptr_gray = seg_wr_ptr_gray_reg;
    end

    // per-segment write logic
    always @(posedge input_clk) begin
        seg_occupancy_reg <= seg_wr_ptr_reg - write_fifo_rd_ptr_sync_reg;

        if (input_ready[n] && input_valid[n]) begin
            seg_mem_data[seg_wr_ptr_reg[WRITE_FIFO_ADDR_WIDTH-1:0]] <= input_data[n*SEG_WIDTH +: SEG_WIDTH];

            seg_wr_ptr_temp = seg_wr_ptr_reg + 1;
            seg_wr_ptr_reg <= seg_wr_ptr_temp;
            seg_wr_ptr_gray_reg <= seg_wr_ptr_temp ^ (seg_wr_ptr_temp >> 1);
        end

        if (input_rst || input_rst_out) begin
            seg_wr_ptr_reg <= 0;
            seg_wr_ptr_gray_reg <= 0;
        end
    end

    always @(posedge clk) begin
        if (!write_fifo_empty && (!input_valid_int_reg || input_read_en)) begin
            seg_rd_data_reg <= seg_mem_data[write_fifo_rd_ptr_reg[WRITE_FIFO_ADDR_WIDTH-1:0]];
        end
    end

end

endgenerate

// pointer synchronization
always @(posedge input_clk) begin
    write_fifo_rd_ptr_gray_sync_1_reg <= write_fifo_rd_ptr_gray_reg;
    write_fifo_rd_ptr_gray_sync_2_reg <= write_fifo_rd_ptr_gray_sync_1_reg;

    for (k = 0; k < WRITE_FIFO_ADDR_WIDTH+1; k = k + 1) begin
        write_fifo_rd_ptr_sync_reg[k] <= ^(write_fifo_rd_ptr_gray_sync_2_reg >> k);
    end

    if (input_rst || input_rst_out) begin
        write_fifo_rd_ptr_gray_sync_1_reg <= 0;
        write_fifo_rd_ptr_gray_sync_2_reg <= 0;
        write_fifo_rd_ptr_sync_reg <= 0;
    end
end

always @(posedge clk) begin
    write_fifo_wr_ptr_gray_sync_1_reg <= write_fifo_wr_ptr_gray;
    write_fifo_wr_ptr_gray_sync_2_reg <= write_fifo_wr_ptr_gray_sync_1_reg;

    for (k = 0; k < WRITE_FIFO_ADDR_WIDTH+1; k = k + 1) begin
        write_fifo_wr_ptr_sync_reg[k] <= ^(write_fifo_wr_ptr_gray_sync_2_reg >> k);
    end

    if (rst || cfg_reset) begin
        write_fifo_wr_ptr_gray_sync_1_reg <= 0;
        write_fifo_wr_ptr_gray_sync_2_reg <= 0;
        write_fifo_wr_ptr_sync_reg <= 0;
    end
end

// read logic
always @(posedge clk) begin
    write_fifo_occupancy_reg <= write_fifo_wr_ptr_sync_reg - write_fifo_rd_ptr_reg + input_valid_int_reg;

    if (input_read_en) begin
        input_valid_int_reg <= 1'b0;
        write_fifo_occupancy_reg <= write_fifo_wr_ptr_sync_reg - write_fifo_rd_ptr_reg;
    end

    if (!write_fifo_empty && (!input_valid_int_reg || input_read_en)) begin
        input_valid_int_reg <= 1'b1;

        write_fifo_rd_ptr_temp = write_fifo_rd_ptr_reg + 1;
        write_fifo_rd_ptr_reg <= write_fifo_rd_ptr_temp;
        write_fifo_rd_ptr_gray_reg <= write_fifo_rd_ptr_temp ^ (write_fifo_rd_ptr_temp >> 1);

        write_fifo_occupancy_reg <= write_fifo_wr_ptr_sync_reg - write_fifo_rd_ptr_reg;
    end

    if (rst || cfg_reset) begin
        write_fifo_rd_ptr_reg <= 0;
        write_fifo_rd_ptr_gray_reg <= 0;
        input_valid_int_reg <= 1'b0;
    end
end

reg [WRITE_BURST_LEN_WIDTH+1-1:0] wr_burst_len;
reg [LEN_WIDTH+1-1:0] wr_start_ptr;
reg [LEN_WIDTH+1-1:0] wr_start_ptr_blk_adj;
reg wr_burst_reg = 1'b0, wr_burst_next;
reg [WRITE_BURST_LEN_WIDTH-1:0] wr_burst_len_reg = 0, wr_burst_len_next;
reg [7:0] wr_timeout_count_reg = 0, wr_timeout_count_next;
reg wr_timeout_reg = 0, wr_timeout_next;
reg fifo_full_wr_blk_adj_reg = 1'b0, fifo_full_wr_blk_adj_next;

reg [LEN_WIDTH+1-1:0] wr_start_ptr_reg = 0, wr_start_ptr_next;
reg [LEN_WIDTH+1-1:0] wr_start_ptr_blk_adj_reg = 0, wr_start_ptr_blk_adj_next;
reg [LEN_WIDTH+1-1:0] wr_finish_ptr_reg = 0, wr_finish_ptr_next;

reg resp_fifo_we_reg = 1'b0, resp_fifo_we_next;
reg [RESP_FIFO_ADDR_WIDTH+1-1:0] resp_fifo_wr_ptr_reg = 0;
reg [RESP_FIFO_ADDR_WIDTH+1-1:0] resp_fifo_rd_ptr_reg = 0, resp_fifo_rd_ptr_next;
reg [WRITE_BURST_LEN_WIDTH+1-1:0] resp_fifo_burst_len[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
reg [WRITE_BURST_LEN_WIDTH+1-1:0] resp_fifo_wr_burst_len_reg = 0, resp_fifo_wr_burst_len_next;

assign wr_start_ptr_out = wr_start_ptr_reg;
assign wr_finish_ptr_out = wr_finish_ptr_reg;

// FIFO occupancy using adjusted write start pointer
wire [LEN_WIDTH+1-1:0] fifo_occupancy_wr_blk_adj = wr_start_ptr_blk_adj_reg - rd_finish_ptr_in;
// FIFO full indication - no space to start writing a complete block
wire fifo_full_wr_blk_adj = (fifo_occupancy_wr_blk_adj & ~cfg_fifo_size_mask) || ((~fifo_occupancy_wr_blk_adj & cfg_fifo_size_mask & ~WRITE_BURST_ADDR_MASK) == 0 && (fifo_occupancy_wr_blk_adj & WRITE_BURST_ADDR_MASK));

// FIFO occupancy (including all in-progress reads and writes)
assign sts_fifo_occupancy = wr_start_ptr_reg - rd_finish_ptr_in;
// FIFO empty (including all in-progress reads and writes)
assign sts_fifo_empty = wr_start_ptr_reg == rd_finish_ptr_in;
// FIFO full
assign sts_fifo_full = fifo_full_wr_blk_adj_reg;

assign sts_write_active = wr_burst_reg || resp_fifo_we_reg || (resp_fifo_wr_ptr_reg != resp_fifo_rd_ptr_reg);

// write logic
always @* begin
    wr_start_ptr_next = wr_start_ptr_reg;
    wr_start_ptr_blk_adj_next = wr_start_ptr_blk_adj_reg;
    wr_finish_ptr_next = wr_finish_ptr_reg;

    wr_burst_next = wr_burst_reg;
    wr_burst_len_next = wr_burst_len_reg;
    wr_timeout_count_next = wr_timeout_count_reg;
    wr_timeout_next = wr_timeout_reg;

    fifo_full_wr_blk_adj_next = fifo_full_wr_blk_adj;

    resp_fifo_we_next = 1'b0;
    resp_fifo_rd_ptr_next = resp_fifo_rd_ptr_reg;
    resp_fifo_wr_burst_len_next = wr_burst_len_reg;

    input_read_en = 1'b0;

    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;

    m_axi_wdata_next = m_axi_wdata_reg;
    m_axi_wstrb_next = m_axi_wstrb_reg;
    m_axi_wlast_next = m_axi_wlast_reg;
    m_axi_wvalid_next = m_axi_wvalid_reg && !m_axi_wready;

    m_axi_bready_next = 1'b0;

    // partial burst timeout handling
    wr_timeout_next = wr_timeout_count_reg == 0;
    if (!input_valid_int_reg || m_axi_awvalid) begin
        wr_timeout_count_next = 8'hff;
        wr_timeout_next = 1'b0;
    end else if (wr_timeout_count_reg > 0) begin
        wr_timeout_count_next = wr_timeout_count_reg - 1;
    end

    // compute length based on input FIFO occupancy
    if ((((wr_start_ptr_reg & WRITE_BURST_ADDR_MASK) >> AXI_BURST_SIZE) + write_fifo_occupancy_reg) >> WRITE_BURST_LEN_WIDTH != 0) begin
        // crosses burst boundary, write up to burst boundary
        wr_burst_len = WRITE_MAX_BURST_LEN_INT-1 - ((wr_start_ptr_reg & WRITE_BURST_ADDR_MASK) >> AXI_BURST_SIZE);
        wr_start_ptr = (wr_start_ptr_reg & ~WRITE_BURST_ADDR_MASK) + (1 << WRITE_BURST_ADDR_WIDTH);
        wr_start_ptr_blk_adj = (wr_start_ptr_reg & ~WRITE_BURST_ADDR_MASK) + (1 << WRITE_BURST_ADDR_WIDTH);
    end else begin
        // does not cross burst boundary, write available data
        wr_burst_len = write_fifo_occupancy_reg-1;
        wr_start_ptr = wr_start_ptr_reg + (write_fifo_occupancy_reg << AXI_BURST_SIZE);
        wr_start_ptr_blk_adj = (wr_start_ptr_reg & ~WRITE_BURST_ADDR_MASK) + (1 << WRITE_BURST_ADDR_WIDTH);
    end

    resp_fifo_wr_burst_len_next = wr_burst_len;

    // generate AXI write bursts
    if (!m_axi_awvalid_reg && !wr_burst_reg) begin
        // ready to start new burst

        wr_burst_len_next = wr_burst_len;

        m_axi_awaddr_next = cfg_fifo_base_addr + (wr_start_ptr_reg & cfg_fifo_size_mask);
        m_axi_awlen_next = wr_burst_len;

        if (cfg_enable && input_valid_int_reg && !fifo_full_wr_blk_adj_reg) begin
            // enabled, have data to write, have space for data
            if ((write_fifo_occupancy_reg) >> WRITE_BURST_LEN_WIDTH != 0 || wr_timeout_reg) begin
                // have full burst or timed out
                wr_burst_next = 1'b1;
                m_axi_awvalid_next = 1'b1;
                resp_fifo_we_next = 1'b1;
                wr_start_ptr_next = wr_start_ptr;
                wr_start_ptr_blk_adj_next = wr_start_ptr_blk_adj;
            end
        end
    end

    if (!m_axi_wvalid_reg || m_axi_wready) begin
        // transfer data
        m_axi_wdata_next = input_data_int;
        m_axi_wlast_next = wr_burst_len_reg == 0;

        if (wr_burst_reg) begin
            m_axi_wstrb_next = {AXI_STRB_WIDTH{1'b1}};
            if (cfg_reset) begin
                m_axi_wstrb_next = 0;
                m_axi_wvalid_next = 1'b1;
                wr_burst_len_next = wr_burst_len_reg - 1;
                wr_burst_next = wr_burst_len_reg != 0;
            end else if (input_valid_int_reg) begin
                input_read_en = 1'b1;
                m_axi_wvalid_next = 1'b1;
                wr_burst_len_next = wr_burst_len_reg - 1;
                wr_burst_next = wr_burst_len_reg != 0;
            end
        end
    end

    // handle AXI write completions
    m_axi_bready_next = 1'b1;
    if (m_axi_bvalid) begin
        wr_finish_ptr_next = wr_finish_ptr_reg + ((resp_fifo_burst_len[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]]+1) << AXI_BURST_SIZE);
        resp_fifo_rd_ptr_next = resp_fifo_rd_ptr_reg + 1;
    end

    if (cfg_reset) begin
        wr_start_ptr_next = 0;
        wr_start_ptr_blk_adj_next = 0;
        wr_finish_ptr_next = 0;
    end
end

always @(posedge clk) begin
    wr_start_ptr_reg <= wr_start_ptr_next;
    wr_start_ptr_blk_adj_reg <= wr_start_ptr_blk_adj_next;
    wr_finish_ptr_reg <= wr_finish_ptr_next;

    wr_burst_reg <= wr_burst_next;
    wr_burst_len_reg <= wr_burst_len_next;
    wr_timeout_count_reg <= wr_timeout_count_next;
    wr_timeout_reg <= wr_timeout_next;
    fifo_full_wr_blk_adj_reg <= fifo_full_wr_blk_adj_next;

    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;
    m_axi_awvalid_reg <= m_axi_awvalid_next;

    m_axi_wdata_reg <= m_axi_wdata_next;
    m_axi_wstrb_reg <= m_axi_wstrb_next;
    m_axi_wlast_reg <= m_axi_wlast_next;
    m_axi_wvalid_reg <= m_axi_wvalid_next;

    m_axi_bready_reg <= m_axi_bready_next;

    resp_fifo_we_reg <= resp_fifo_we_next;
    resp_fifo_wr_burst_len_reg <= resp_fifo_wr_burst_len_next;

    if (resp_fifo_we_reg) begin
        resp_fifo_burst_len[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_burst_len_reg;
        resp_fifo_wr_ptr_reg <= resp_fifo_wr_ptr_reg + 1;
    end
    resp_fifo_rd_ptr_reg <= resp_fifo_rd_ptr_next;

    if (rst) begin
        wr_burst_reg <= 1'b0;
        m_axi_awvalid_reg <= 1'b0;
        m_axi_wvalid_reg <= 1'b0;
        m_axi_bready_reg <= 1'b0;
        resp_fifo_we_reg <= 1'b0;
        resp_fifo_wr_ptr_reg <= 0;
        resp_fifo_rd_ptr_reg <= 0;
    end
end

endmodule

`resetall
