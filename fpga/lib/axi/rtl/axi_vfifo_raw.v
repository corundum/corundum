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
 * AXI4 virtual FIFO (raw)
 */
module axi_vfifo_raw #
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
    // Output FIFO depth for AXI read data (full-width words)
    parameter READ_FIFO_DEPTH = 128,
    // Max AXI read burst length
    parameter READ_MAX_BURST_LEN = WRITE_MAX_BURST_LEN,
    // Watermark level
    parameter WATERMARK_LEVEL = WRITE_FIFO_DEPTH/2,
    // Use control output
    parameter CTRL_OUT_EN = 0
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
     * Segmented data output (to decode logic)
     */
    input  wire                          output_clk,
    input  wire                          output_rst,
    output wire                          output_rst_out,
    output wire [SEG_CNT*SEG_WIDTH-1:0]  output_data,
    output wire [SEG_CNT-1:0]            output_valid,
    input  wire [SEG_CNT-1:0]            output_ready,
    output wire [SEG_CNT*SEG_WIDTH-1:0]  output_ctrl_data,
    output wire [SEG_CNT-1:0]            output_ctrl_valid,
    input  wire [SEG_CNT-1:0]            output_ctrl_ready,

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
    output wire [AXI_ID_WIDTH-1:0]       m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]     m_axi_araddr,
    output wire [7:0]                    m_axi_arlen,
    output wire [2:0]                    m_axi_arsize,
    output wire [1:0]                    m_axi_arburst,
    output wire                          m_axi_arlock,
    output wire [3:0]                    m_axi_arcache,
    output wire [2:0]                    m_axi_arprot,
    output wire                          m_axi_arvalid,
    input  wire                          m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]       m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata,
    input  wire [1:0]                    m_axi_rresp,
    input  wire                          m_axi_rlast,
    input  wire                          m_axi_rvalid,
    output wire                          m_axi_rready,

    /*
     * Reset sync
     */
    output wire                          rst_req_out,
    input  wire                          rst_req_in,

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
    output wire                          sts_reset,
    output wire                          sts_active,
    output wire                          sts_write_active,
    output wire                          sts_read_active
);

localparam ADDR_MASK = {AXI_ADDR_WIDTH{1'b1}} << $clog2(AXI_STRB_WIDTH);

reg fifo_reset_reg = 1'b1, fifo_reset_next;
reg fifo_enable_reg = 1'b0, fifo_enable_next;
reg [AXI_ADDR_WIDTH-1:0] fifo_base_addr_reg = 0, fifo_base_addr_next;
reg [LEN_WIDTH-1:0] fifo_size_mask_reg = 0, fifo_size_mask_next;

assign sts_reset = fifo_reset_reg;
assign sts_active = fifo_enable_reg;

wire [LEN_WIDTH+1-1:0] wr_start_ptr;
wire [LEN_WIDTH+1-1:0] wr_finish_ptr;
wire [LEN_WIDTH+1-1:0] rd_start_ptr;
wire [LEN_WIDTH+1-1:0] rd_finish_ptr;

axi_vfifo_raw_wr #(
    .SEG_WIDTH(SEG_WIDTH),
    .SEG_CNT(SEG_CNT),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .LEN_WIDTH(LEN_WIDTH),
    .WRITE_FIFO_DEPTH(WRITE_FIFO_DEPTH),
    .WRITE_MAX_BURST_LEN(WRITE_MAX_BURST_LEN),
    .WATERMARK_LEVEL(WATERMARK_LEVEL)
)
axi_vfifo_raw_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Segmented data input (from encode logic)
     */
    .input_clk(input_clk),
    .input_rst(input_rst),
    .input_rst_out(input_rst_out),
    .input_watermark(input_watermark),
    .input_data(input_data),
    .input_valid(input_valid),
    .input_ready(input_ready),

    /*
     * AXI master interface
     */
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),

    /*
     * FIFO control
     */
    .wr_start_ptr_out(wr_start_ptr),
    .wr_finish_ptr_out(wr_finish_ptr),
    .rd_start_ptr_in(rd_start_ptr),
    .rd_finish_ptr_in(rd_finish_ptr),

    /*
     * Configuration
     */
    .cfg_fifo_base_addr(fifo_base_addr_reg),
    .cfg_fifo_size_mask(fifo_size_mask_reg),
    .cfg_enable(fifo_enable_reg),
    .cfg_reset(fifo_reset_reg),

    /*
     * Status
     */
    .sts_fifo_occupancy(sts_fifo_occupancy),
    .sts_fifo_empty(sts_fifo_empty),
    .sts_fifo_full(sts_fifo_full),
    .sts_write_active(sts_write_active)
);

axi_vfifo_raw_rd #(
    .SEG_WIDTH(SEG_WIDTH),
    .SEG_CNT(SEG_CNT),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .LEN_WIDTH(LEN_WIDTH),
    .READ_FIFO_DEPTH(READ_FIFO_DEPTH),
    .READ_MAX_BURST_LEN(READ_MAX_BURST_LEN),
    .CTRL_OUT_EN(CTRL_OUT_EN)
)
axi_vfifo_raw_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Segmented data output (to decode logic)
     */
    .output_clk(output_clk),
    .output_rst(output_rst),
    .output_rst_out(output_rst_out),
    .output_data(output_data),
    .output_valid(output_valid),
    .output_ready(output_ready),
    .output_ctrl_data(output_ctrl_data),
    .output_ctrl_valid(output_ctrl_valid),
    .output_ctrl_ready(output_ctrl_ready),

    /*
     * AXI master interface
     */
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    /*
     * FIFO control
     */
    .wr_start_ptr_in(wr_start_ptr),
    .wr_finish_ptr_in(wr_finish_ptr),
    .rd_start_ptr_out(rd_start_ptr),
    .rd_finish_ptr_out(rd_finish_ptr),

    /*
     * Configuration
     */
    .cfg_fifo_base_addr(fifo_base_addr_reg),
    .cfg_fifo_size_mask(fifo_size_mask_reg),
    .cfg_enable(fifo_enable_reg),
    .cfg_reset(fifo_reset_reg),

    /*
     * Status
     */
    .sts_read_active(sts_read_active)
);

// reset synchronization
assign rst_req_out = rst | input_rst | output_rst | cfg_reset;

wire rst_req_int = rst_req_in | rst_req_out;

(* shreg_extract = "no" *)
reg rst_sync_1_reg = 1'b1,  rst_sync_2_reg = 1'b1, rst_sync_3_reg = 1'b1;

always @(posedge clk or posedge rst_req_int) begin
    if (rst_req_int) begin
        rst_sync_1_reg <= 1'b1;
    end else begin
        rst_sync_1_reg <= 1'b0;
    end
end

always @(posedge clk) begin
    rst_sync_2_reg <= rst_sync_1_reg;
    rst_sync_3_reg <= rst_sync_2_reg;
end

// reset and enable logic
always @* begin
    fifo_reset_next = 1'b0;
    fifo_enable_next = fifo_enable_reg;
    fifo_base_addr_next = fifo_base_addr_reg;
    fifo_size_mask_next = fifo_size_mask_reg;

    if (cfg_reset || rst_sync_3_reg) begin
        fifo_reset_next = 1'b1;
    end

    if (fifo_reset_reg) begin
        fifo_enable_next = 1'b0;
        // hold reset until everything is flushed
        if (sts_write_active || sts_read_active) begin
            fifo_reset_next = 1'b1;
        end
    end else if (!fifo_enable_reg && cfg_enable) begin
        fifo_base_addr_next = cfg_fifo_base_addr & ADDR_MASK;
        fifo_size_mask_next = cfg_fifo_size_mask | ~ADDR_MASK;

        fifo_enable_next = 1'b1;
    end
end

always @(posedge clk) begin
    fifo_reset_reg <= fifo_reset_next;
    fifo_enable_reg <= fifo_enable_next;
    fifo_base_addr_reg <= fifo_base_addr_next;
    fifo_size_mask_reg <= fifo_size_mask_next;

    if (rst) begin
        fifo_reset_reg <= 1'b1;
        fifo_enable_reg <= 1'b0;
    end
end

endmodule

`resetall
