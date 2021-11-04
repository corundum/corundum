/*

Copyright (c) 2021 Alex Forencich

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
 * Example design core logic
 */
module example_core #
(
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 64,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA Length field width
    parameter DMA_LEN_WIDTH = 16,
    // DMA Tag field width
    parameter DMA_TAG_WIDTH = 8,
    // RAM segment count
    parameter RAM_SEG_COUNT = 2,
    // RAM segment data width
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    // RAM segment address width
    parameter RAM_SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    // RAM select width
    parameter RAM_SEL_WIDTH = 2,
    // RAM address width
    parameter RAM_ADDR_WIDTH = RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH)
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI Lite control interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_ctrl_awaddr,
    input  wire [2:0]                                   s_axil_ctrl_awprot,
    input  wire                                         s_axil_ctrl_awvalid,
    output wire                                         s_axil_ctrl_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]                   s_axil_ctrl_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]                   s_axil_ctrl_wstrb,
    input  wire                                         s_axil_ctrl_wvalid,
    output wire                                         s_axil_ctrl_wready,
    output wire [1:0]                                   s_axil_ctrl_bresp,
    output wire                                         s_axil_ctrl_bvalid,
    input  wire                                         s_axil_ctrl_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_ctrl_araddr,
    input  wire [2:0]                                   s_axil_ctrl_arprot,
    input  wire                                         s_axil_ctrl_arvalid,
    output wire                                         s_axil_ctrl_arready,
    output wire [AXIL_DATA_WIDTH-1:0]                   s_axil_ctrl_rdata,
    output wire [1:0]                                   s_axil_ctrl_rresp,
    output wire                                         s_axil_ctrl_rvalid,
    input  wire                                         s_axil_ctrl_rready,

    /*
     * AXI read descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_read_desc_tag,
    output wire                                         m_axis_dma_read_desc_valid,
    input  wire                                         m_axis_dma_read_desc_ready,

    /*
     * AXI read descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_read_desc_status_error,
    input  wire                                         s_axis_dma_read_desc_status_valid,

    /*
     * AXI write descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_write_desc_tag,
    output wire                                         m_axis_dma_write_desc_valid,
    input  wire                                         m_axis_dma_write_desc_ready,

    /*
     * AXI write descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_write_desc_status_error,
    input  wire                                         s_axis_dma_write_desc_status_valid,

    /*
     * RAM interface
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_ready,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                     ram_wr_done,

    /*
     * MSI request outputs
     */
    output wire [31:0]                                  msi_irq
);

dma_psdpram #(
    .SIZE(16384),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .PIPELINE(2)
)
dma_ram_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .wr_cmd_be(ram_wr_cmd_be),
    .wr_cmd_addr(ram_wr_cmd_addr),
    .wr_cmd_data(ram_wr_cmd_data),
    .wr_cmd_valid(ram_wr_cmd_valid),
    .wr_cmd_ready(ram_wr_cmd_ready),
    .wr_done(ram_wr_done),

    /*
     * Read port
     */
    .rd_cmd_addr(ram_rd_cmd_addr),
    .rd_cmd_valid(ram_rd_cmd_valid),
    .rd_cmd_ready(ram_rd_cmd_ready),
    .rd_resp_data(ram_rd_resp_data),
    .rd_resp_valid(ram_rd_resp_valid),
    .rd_resp_ready(ram_rd_resp_ready)
);

// control registers
reg axil_ctrl_awready_reg = 1'b0, axil_ctrl_awready_next;
reg axil_ctrl_wready_reg = 1'b0, axil_ctrl_wready_next;
reg [1:0] axil_ctrl_bresp_reg = 2'b00, axil_ctrl_bresp_next;
reg axil_ctrl_bvalid_reg = 1'b0, axil_ctrl_bvalid_next;
reg axil_ctrl_arready_reg = 1'b0, axil_ctrl_arready_next;
reg [AXIL_DATA_WIDTH-1:0] axil_ctrl_rdata_reg = {AXIL_DATA_WIDTH{1'b0}}, axil_ctrl_rdata_next;
reg [1:0] axil_ctrl_rresp_reg = 2'b00, axil_ctrl_rresp_next;
reg axil_ctrl_rvalid_reg = 1'b0, axil_ctrl_rvalid_next;

reg [63:0] cycle_count_reg = 0;
reg [15:0] dma_read_active_count_reg = 0;
reg [15:0] dma_write_active_count_reg = 0;

reg [DMA_ADDR_WIDTH-1:0] dma_read_desc_dma_addr_reg = 0, dma_read_desc_dma_addr_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_desc_ram_addr_reg = 0, dma_read_desc_ram_addr_next;
reg [DMA_LEN_WIDTH-1:0] dma_read_desc_len_reg = 0, dma_read_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] dma_read_desc_tag_reg = 0, dma_read_desc_tag_next;
reg dma_read_desc_valid_reg = 0, dma_read_desc_valid_next;

reg [DMA_TAG_WIDTH-1:0] dma_read_desc_status_tag_reg = 0, dma_read_desc_status_tag_next;
reg [3:0] dma_read_desc_status_error_reg = 0, dma_read_desc_status_error_next;
reg dma_read_desc_status_valid_reg = 0, dma_read_desc_status_valid_next;

reg [DMA_ADDR_WIDTH-1:0] dma_write_desc_dma_addr_reg = 0, dma_write_desc_dma_addr_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_desc_ram_addr_reg = 0, dma_write_desc_ram_addr_next;
reg [DMA_LEN_WIDTH-1:0] dma_write_desc_len_reg = 0, dma_write_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] dma_write_desc_tag_reg = 0, dma_write_desc_tag_next;
reg dma_write_desc_valid_reg = 0, dma_write_desc_valid_next;

reg [DMA_TAG_WIDTH-1:0] dma_write_desc_status_tag_reg = 0, dma_write_desc_status_tag_next;
reg [3:0] dma_write_desc_status_error_reg = 0, dma_write_desc_status_error_next;
reg dma_write_desc_status_valid_reg = 0, dma_write_desc_status_valid_next;

reg dma_enable_reg = 0, dma_enable_next;
reg dma_rd_int_en_reg = 0, dma_rd_int_en_next;
reg dma_wr_int_en_reg = 0, dma_wr_int_en_next;

reg dma_read_block_run_reg = 1'b0, dma_read_block_run_next;
reg [DMA_LEN_WIDTH-1:0] dma_read_block_len_reg = 0, dma_read_block_len_next;
reg [31:0] dma_read_block_count_reg = 0, dma_read_block_count_next;
reg [63:0] dma_read_block_cycle_count_reg = 0, dma_read_block_cycle_count_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_base_addr_reg = 0, dma_read_block_dma_base_addr_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_offset_reg = 0, dma_read_block_dma_offset_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_offset_mask_reg = 0, dma_read_block_dma_offset_mask_next;
reg [DMA_ADDR_WIDTH-1:0] dma_read_block_dma_stride_reg = 0, dma_read_block_dma_stride_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_base_addr_reg = 0, dma_read_block_ram_base_addr_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_offset_reg = 0, dma_read_block_ram_offset_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_offset_mask_reg = 0, dma_read_block_ram_offset_mask_next;
reg [RAM_ADDR_WIDTH-1:0] dma_read_block_ram_stride_reg = 0, dma_read_block_ram_stride_next;

reg dma_write_block_run_reg = 1'b0, dma_write_block_run_next;
reg [DMA_LEN_WIDTH-1:0] dma_write_block_len_reg = 0, dma_write_block_len_next;
reg [31:0] dma_write_block_count_reg = 0, dma_write_block_count_next;
reg [63:0] dma_write_block_cycle_count_reg = 0, dma_write_block_cycle_count_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_base_addr_reg = 0, dma_write_block_dma_base_addr_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_offset_reg = 0, dma_write_block_dma_offset_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_offset_mask_reg = 0, dma_write_block_dma_offset_mask_next;
reg [DMA_ADDR_WIDTH-1:0] dma_write_block_dma_stride_reg = 0, dma_write_block_dma_stride_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_base_addr_reg = 0, dma_write_block_ram_base_addr_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_offset_reg = 0, dma_write_block_ram_offset_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_offset_mask_reg = 0, dma_write_block_ram_offset_mask_next;
reg [RAM_ADDR_WIDTH-1:0] dma_write_block_ram_stride_reg = 0, dma_write_block_ram_stride_next;

assign s_axil_ctrl_awready = axil_ctrl_awready_reg;
assign s_axil_ctrl_wready = axil_ctrl_wready_reg;
assign s_axil_ctrl_bresp = axil_ctrl_bresp_reg;
assign s_axil_ctrl_bvalid = axil_ctrl_bvalid_reg;
assign s_axil_ctrl_arready = axil_ctrl_arready_reg;
assign s_axil_ctrl_rdata = axil_ctrl_rdata_reg;
assign s_axil_ctrl_rresp = axil_ctrl_rresp_reg;
assign s_axil_ctrl_rvalid = axil_ctrl_rvalid_reg;

assign m_axis_dma_read_desc_dma_addr = dma_read_desc_dma_addr_reg;
assign m_axis_dma_read_desc_ram_sel = 0;
assign m_axis_dma_read_desc_ram_addr = dma_read_desc_ram_addr_reg;
assign m_axis_dma_read_desc_len = dma_read_desc_len_reg;
assign m_axis_dma_read_desc_tag = dma_read_desc_tag_reg;
assign m_axis_dma_read_desc_valid = dma_read_desc_valid_reg;

assign m_axis_dma_write_desc_dma_addr = dma_write_desc_dma_addr_reg;
assign m_axis_dma_write_desc_ram_sel = 0;
assign m_axis_dma_write_desc_ram_addr = dma_write_desc_ram_addr_reg;
assign m_axis_dma_write_desc_len = dma_write_desc_len_reg;
assign m_axis_dma_write_desc_tag = dma_write_desc_tag_reg;
assign m_axis_dma_write_desc_valid = dma_write_desc_valid_reg;

assign msi_irq[0] = (s_axis_dma_read_desc_status_valid && dma_rd_int_en_reg) || (s_axis_dma_write_desc_status_valid && dma_wr_int_en_reg);
assign msi_irq[31:1] = 31'd0;

always @* begin
    axil_ctrl_awready_next = 1'b0;
    axil_ctrl_wready_next = 1'b0;
    axil_ctrl_bresp_next = 2'b00;
    axil_ctrl_bvalid_next = axil_ctrl_bvalid_reg && !s_axil_ctrl_bready;
    axil_ctrl_arready_next = 1'b0;
    axil_ctrl_rdata_next = axil_ctrl_rdata_reg;
    axil_ctrl_rresp_next = 2'b00;
    axil_ctrl_rvalid_next = axil_ctrl_rvalid_reg && !s_axil_ctrl_rready;

    dma_read_desc_dma_addr_next = dma_read_desc_dma_addr_reg;
    dma_read_desc_ram_addr_next = dma_read_desc_ram_addr_reg;
    dma_read_desc_len_next = dma_read_desc_len_reg;
    dma_read_desc_tag_next = dma_read_desc_tag_reg;
    dma_read_desc_valid_next = dma_read_desc_valid_reg && !m_axis_dma_read_desc_ready;

    dma_read_desc_status_tag_next = dma_read_desc_status_tag_reg;
    dma_read_desc_status_error_next = dma_read_desc_status_error_reg;
    dma_read_desc_status_valid_next = dma_read_desc_status_valid_reg;

    dma_write_desc_dma_addr_next = dma_write_desc_dma_addr_reg;
    dma_write_desc_ram_addr_next = dma_write_desc_ram_addr_reg;
    dma_write_desc_len_next = dma_write_desc_len_reg;
    dma_write_desc_tag_next = dma_write_desc_tag_reg;
    dma_write_desc_valid_next = dma_write_desc_valid_reg && !m_axis_dma_read_desc_ready;

    dma_write_desc_status_tag_next = dma_write_desc_status_tag_reg;
    dma_write_desc_status_error_next = dma_write_desc_status_error_reg;
    dma_write_desc_status_valid_next = dma_write_desc_status_valid_reg;

    dma_enable_next = dma_enable_reg;

    dma_rd_int_en_next = dma_rd_int_en_reg;
    dma_wr_int_en_next = dma_wr_int_en_reg;

    dma_read_block_run_next = dma_read_block_run_reg;
    dma_read_block_len_next = dma_read_block_len_reg;
    dma_read_block_count_next = dma_read_block_count_reg;
    dma_read_block_cycle_count_next = dma_read_block_cycle_count_reg;
    dma_read_block_dma_base_addr_next = dma_read_block_dma_base_addr_reg;
    dma_read_block_dma_offset_next = dma_read_block_dma_offset_reg;
    dma_read_block_dma_offset_mask_next = dma_read_block_dma_offset_mask_reg;
    dma_read_block_dma_stride_next = dma_read_block_dma_stride_reg;
    dma_read_block_ram_base_addr_next = dma_read_block_ram_base_addr_reg;
    dma_read_block_ram_offset_next = dma_read_block_ram_offset_reg;
    dma_read_block_ram_offset_mask_next = dma_read_block_ram_offset_mask_reg;
    dma_read_block_ram_stride_next = dma_read_block_ram_stride_reg;

    dma_write_block_run_next = dma_write_block_run_reg;
    dma_write_block_len_next = dma_write_block_len_reg;
    dma_write_block_count_next = dma_write_block_count_reg;
    dma_write_block_cycle_count_next = dma_write_block_cycle_count_reg;
    dma_write_block_dma_base_addr_next = dma_write_block_dma_base_addr_reg;
    dma_write_block_dma_offset_next = dma_write_block_dma_offset_reg;
    dma_write_block_dma_offset_mask_next = dma_write_block_dma_offset_mask_reg;
    dma_write_block_dma_stride_next = dma_write_block_dma_stride_reg;
    dma_write_block_ram_base_addr_next = dma_write_block_ram_base_addr_reg;
    dma_write_block_ram_offset_next = dma_write_block_ram_offset_reg;
    dma_write_block_ram_offset_mask_next = dma_write_block_ram_offset_mask_reg;
    dma_write_block_ram_stride_next = dma_write_block_ram_stride_reg;

    if (s_axil_ctrl_awvalid && s_axil_ctrl_wvalid && !axil_ctrl_bvalid_reg) begin
        // write operation
        axil_ctrl_awready_next = 1'b1;
        axil_ctrl_wready_next = 1'b1;
        axil_ctrl_bresp_next = 2'b00;
        axil_ctrl_bvalid_next = 1'b1;

        case ({s_axil_ctrl_awaddr[15:2], 2'b00})
            // control
            16'h0000: begin
                dma_enable_next = s_axil_ctrl_wdata[0];
            end
            16'h0008: begin
                dma_rd_int_en_next = s_axil_ctrl_wdata[0];
                dma_wr_int_en_next = s_axil_ctrl_wdata[1];
            end
            // single read
            16'h0100: dma_read_desc_dma_addr_next[31:0] = s_axil_ctrl_wdata;
            16'h0104: dma_read_desc_dma_addr_next[63:32] = s_axil_ctrl_wdata;
            16'h0108: dma_read_desc_ram_addr_next = s_axil_ctrl_wdata;
            16'h0110: dma_read_desc_len_next = s_axil_ctrl_wdata;
            16'h0114: begin
                dma_read_desc_tag_next = s_axil_ctrl_wdata;
                dma_read_desc_valid_next = 1'b1;
            end
            // single write
            16'h0200: dma_write_desc_dma_addr_next[31:0] = s_axil_ctrl_wdata;
            16'h0204: dma_write_desc_dma_addr_next[63:32] = s_axil_ctrl_wdata;
            16'h0208: dma_write_desc_ram_addr_next = s_axil_ctrl_wdata;
            16'h0210: dma_write_desc_len_next = s_axil_ctrl_wdata;
            16'h0214: begin
                dma_write_desc_tag_next = s_axil_ctrl_wdata;
                dma_write_desc_valid_next = 1'b1;
            end
            // block read
            16'h1000: begin
                dma_read_block_run_next = s_axil_ctrl_wdata[0];
            end
            16'h1008: dma_read_block_cycle_count_next[31:0] = s_axil_ctrl_wdata;
            16'h100c: dma_read_block_cycle_count_next[63:32] = s_axil_ctrl_wdata;
            16'h1010: dma_read_block_len_next = s_axil_ctrl_wdata;
            16'h1018: dma_read_block_count_next[31:0] = s_axil_ctrl_wdata;
            16'h1080: dma_read_block_dma_base_addr_next[31:0] = s_axil_ctrl_wdata;
            16'h1084: dma_read_block_dma_base_addr_next[63:32] = s_axil_ctrl_wdata;
            16'h1088: dma_read_block_dma_offset_next[31:0] = s_axil_ctrl_wdata;
            16'h108c: dma_read_block_dma_offset_next[63:32] = s_axil_ctrl_wdata;
            16'h1090: dma_read_block_dma_offset_mask_next[31:0] = s_axil_ctrl_wdata;
            16'h1094: dma_read_block_dma_offset_mask_next[63:32] = s_axil_ctrl_wdata;
            16'h1098: dma_read_block_dma_stride_next[31:0] = s_axil_ctrl_wdata;
            16'h109c: dma_read_block_dma_stride_next[63:32] = s_axil_ctrl_wdata;
            16'h10c0: dma_read_block_ram_base_addr_next = s_axil_ctrl_wdata;
            16'h10c8: dma_read_block_ram_offset_next = s_axil_ctrl_wdata;
            16'h10d0: dma_read_block_ram_offset_mask_next = s_axil_ctrl_wdata;
            16'h10d8: dma_read_block_ram_stride_next = s_axil_ctrl_wdata;
            // block write
            16'h1100: begin
                dma_write_block_run_next = s_axil_ctrl_wdata[0];
            end
            16'h1108: dma_write_block_cycle_count_next[31:0] = s_axil_ctrl_wdata;
            16'h110c: dma_write_block_cycle_count_next[63:32] = s_axil_ctrl_wdata;
            16'h1110: dma_write_block_len_next = s_axil_ctrl_wdata;
            16'h1118: dma_write_block_count_next[31:0] = s_axil_ctrl_wdata;
            16'h1180: dma_write_block_dma_base_addr_next[31:0] = s_axil_ctrl_wdata;
            16'h1184: dma_write_block_dma_base_addr_next[63:32] = s_axil_ctrl_wdata;
            16'h1188: dma_write_block_dma_offset_next[31:0] = s_axil_ctrl_wdata;
            16'h118c: dma_write_block_dma_offset_next[63:32] = s_axil_ctrl_wdata;
            16'h1190: dma_write_block_dma_offset_mask_next[31:0] = s_axil_ctrl_wdata;
            16'h1194: dma_write_block_dma_offset_mask_next[63:32] = s_axil_ctrl_wdata;
            16'h1198: dma_write_block_dma_stride_next[31:0] = s_axil_ctrl_wdata;
            16'h119c: dma_write_block_dma_stride_next[63:32] = s_axil_ctrl_wdata;
            16'h11c0: dma_write_block_ram_base_addr_next = s_axil_ctrl_wdata;
            16'h11c8: dma_write_block_ram_offset_next = s_axil_ctrl_wdata;
            16'h11d0: dma_write_block_ram_offset_mask_next = s_axil_ctrl_wdata;
            16'h11d8: dma_write_block_ram_stride_next = s_axil_ctrl_wdata;
        endcase
    end

    if (s_axil_ctrl_arvalid && !axil_ctrl_rvalid_reg) begin
        // read operation
        axil_ctrl_arready_next = 1'b1;
        axil_ctrl_rresp_next = 2'b00;
        axil_ctrl_rvalid_next = 1'b1;

        case ({s_axil_ctrl_araddr[15:2], 2'b00})
            // control
            16'h0000: begin
                axil_ctrl_rdata_next[0] = dma_enable_reg;
            end
            16'h0008: begin
                axil_ctrl_rdata_next[0] = dma_rd_int_en_reg;
                axil_ctrl_rdata_next[1] = dma_wr_int_en_reg;
            end
            16'h0010: axil_ctrl_rdata_next = cycle_count_reg;
            16'h0014: axil_ctrl_rdata_next = cycle_count_reg >> 32;
            16'h0020: axil_ctrl_rdata_next = dma_read_active_count_reg;
            16'h0028: axil_ctrl_rdata_next = dma_write_active_count_reg;
            // single read
            16'h0100: axil_ctrl_rdata_next = dma_read_desc_dma_addr_reg;
            16'h0104: axil_ctrl_rdata_next = dma_read_desc_dma_addr_reg >> 32;
            16'h0108: axil_ctrl_rdata_next = dma_read_desc_ram_addr_reg;
            16'h010c: axil_ctrl_rdata_next = dma_read_desc_ram_addr_reg >> 32;
            16'h0110: axil_ctrl_rdata_next = dma_read_desc_len_reg;
            16'h0114: axil_ctrl_rdata_next = dma_read_desc_tag_reg;
            16'h0118: begin
                axil_ctrl_rdata_next[15:0] = dma_read_desc_status_tag_reg;
                axil_ctrl_rdata_next[27:24] = dma_read_desc_status_error_reg;
                axil_ctrl_rdata_next[31] = dma_read_desc_status_valid_reg;
                dma_read_desc_status_valid_next = 1'b0;
            end
            // single write
            16'h0200: axil_ctrl_rdata_next = dma_write_desc_dma_addr_reg;
            16'h0204: axil_ctrl_rdata_next = dma_write_desc_dma_addr_reg >> 32;
            16'h0208: axil_ctrl_rdata_next = dma_write_desc_ram_addr_reg;
            16'h020c: axil_ctrl_rdata_next = dma_write_desc_ram_addr_reg >> 32;
            16'h0210: axil_ctrl_rdata_next = dma_write_desc_len_reg;
            16'h0214: axil_ctrl_rdata_next = dma_write_desc_tag_reg;
            16'h0218: begin
                axil_ctrl_rdata_next[15:0] = dma_write_desc_status_tag_reg;
                axil_ctrl_rdata_next[27:24] = dma_write_desc_status_error_reg;
                axil_ctrl_rdata_next[31] = dma_write_desc_status_valid_reg;
                dma_write_desc_status_valid_next = 1'b0;
            end
            // block read
            16'h1000: begin
                axil_ctrl_rdata_next[0] = dma_read_block_run_reg;
            end
            16'h1008: axil_ctrl_rdata_next = dma_read_block_cycle_count_reg;
            16'h100c: axil_ctrl_rdata_next = dma_read_block_cycle_count_reg >> 32;
            16'h1010: axil_ctrl_rdata_next = dma_read_block_len_reg;
            16'h1018: axil_ctrl_rdata_next = dma_read_block_count_reg;
            16'h101c: axil_ctrl_rdata_next = dma_read_block_count_reg >> 32;
            16'h1080: axil_ctrl_rdata_next = dma_read_block_dma_base_addr_reg;
            16'h1084: axil_ctrl_rdata_next = dma_read_block_dma_base_addr_reg >> 32;
            16'h1088: axil_ctrl_rdata_next = dma_read_block_dma_offset_reg;
            16'h108c: axil_ctrl_rdata_next = dma_read_block_dma_offset_reg >> 32;
            16'h1090: axil_ctrl_rdata_next = dma_read_block_dma_offset_mask_reg;
            16'h1094: axil_ctrl_rdata_next = dma_read_block_dma_offset_mask_reg >> 32;
            16'h1098: axil_ctrl_rdata_next = dma_read_block_dma_stride_reg;
            16'h109c: axil_ctrl_rdata_next = dma_read_block_dma_stride_reg >> 32;
            16'h10c0: axil_ctrl_rdata_next = dma_read_block_ram_base_addr_reg;
            16'h10c4: axil_ctrl_rdata_next = dma_read_block_ram_base_addr_reg >> 32;
            16'h10c8: axil_ctrl_rdata_next = dma_read_block_ram_offset_reg;
            16'h10cc: axil_ctrl_rdata_next = dma_read_block_ram_offset_reg >> 32;
            16'h10d0: axil_ctrl_rdata_next = dma_read_block_ram_offset_mask_reg;
            16'h10d4: axil_ctrl_rdata_next = dma_read_block_ram_offset_mask_reg >> 32;
            16'h10d8: axil_ctrl_rdata_next = dma_read_block_ram_stride_reg;
            16'h10dc: axil_ctrl_rdata_next = dma_read_block_ram_stride_reg >> 32;
            // block write
            16'h1100: begin
                axil_ctrl_rdata_next[0] = dma_write_block_run_reg;
            end
            16'h1108: axil_ctrl_rdata_next = dma_write_block_cycle_count_reg;
            16'h110c: axil_ctrl_rdata_next = dma_write_block_cycle_count_reg >> 32;
            16'h1110: axil_ctrl_rdata_next = dma_write_block_len_reg;
            16'h1118: axil_ctrl_rdata_next = dma_write_block_count_reg;
            16'h111c: axil_ctrl_rdata_next = dma_write_block_count_reg >> 32;
            16'h1180: axil_ctrl_rdata_next = dma_write_block_dma_base_addr_reg;
            16'h1184: axil_ctrl_rdata_next = dma_write_block_dma_base_addr_reg >> 32;
            16'h1188: axil_ctrl_rdata_next = dma_write_block_dma_offset_reg;
            16'h118c: axil_ctrl_rdata_next = dma_write_block_dma_offset_reg >> 32;
            16'h1190: axil_ctrl_rdata_next = dma_write_block_dma_offset_mask_reg;
            16'h1194: axil_ctrl_rdata_next = dma_write_block_dma_offset_mask_reg >> 32;
            16'h1198: axil_ctrl_rdata_next = dma_write_block_dma_stride_reg;
            16'h119c: axil_ctrl_rdata_next = dma_write_block_dma_stride_reg >> 32;
            16'h11c0: axil_ctrl_rdata_next = dma_write_block_ram_base_addr_reg;
            16'h11c4: axil_ctrl_rdata_next = dma_write_block_ram_base_addr_reg >> 32;
            16'h11c8: axil_ctrl_rdata_next = dma_write_block_ram_offset_reg;
            16'h11cc: axil_ctrl_rdata_next = dma_write_block_ram_offset_reg >> 32;
            16'h11d0: axil_ctrl_rdata_next = dma_write_block_ram_offset_mask_reg;
            16'h11d4: axil_ctrl_rdata_next = dma_write_block_ram_offset_mask_reg >> 32;
            16'h11d8: axil_ctrl_rdata_next = dma_write_block_ram_stride_reg;
            16'h11dc: axil_ctrl_rdata_next = dma_write_block_ram_stride_reg >> 32;
        endcase
    end

    // store read response
    if (s_axis_dma_read_desc_status_valid) begin
        dma_read_desc_status_tag_next = s_axis_dma_read_desc_status_tag;
        dma_read_desc_status_error_next = s_axis_dma_read_desc_status_error;
        dma_read_desc_status_valid_next = s_axis_dma_read_desc_status_valid;
    end

    // store write response
    if (s_axis_dma_write_desc_status_valid) begin
        dma_write_desc_status_tag_next = s_axis_dma_write_desc_status_tag;
        dma_write_desc_status_error_next = s_axis_dma_write_desc_status_error;
        dma_write_desc_status_valid_next = s_axis_dma_write_desc_status_valid;
    end

    // block read
    if (dma_read_block_run_reg) begin
        dma_read_block_cycle_count_next = dma_read_block_cycle_count_reg + 1;

        if (dma_read_block_count_reg == 0) begin
            if (dma_read_active_count_reg == 0) begin
                dma_read_block_run_next = 1'b0;
            end
        end else begin
            if (!dma_read_desc_valid_reg || m_axis_dma_read_desc_ready) begin
                dma_read_block_dma_offset_next = dma_read_block_dma_offset_reg + dma_read_block_dma_stride_reg;
                dma_read_desc_dma_addr_next = dma_read_block_dma_base_addr_reg + (dma_read_block_dma_offset_reg & dma_read_block_dma_offset_mask_reg);
                dma_read_block_ram_offset_next = dma_read_block_ram_offset_reg + dma_read_block_ram_stride_reg;
                dma_read_desc_ram_addr_next = dma_read_block_ram_base_addr_reg + (dma_read_block_ram_offset_reg & dma_read_block_ram_offset_mask_reg);
                dma_read_desc_len_next = dma_read_block_len_reg;
                dma_read_block_count_next = dma_read_block_count_reg - 1;
                dma_read_desc_tag_next = dma_read_block_count_reg;
                dma_read_desc_valid_next = 1'b1;
            end
        end
    end

    // block write
    if (dma_write_block_run_reg) begin
        dma_write_block_cycle_count_next = dma_write_block_cycle_count_reg + 1;

        if (dma_write_block_count_reg == 0) begin
            if (dma_write_active_count_reg == 0) begin
                dma_write_block_run_next = 1'b0;
            end
        end else begin
            if (!dma_write_desc_valid_reg || m_axis_dma_write_desc_ready) begin
                dma_write_block_dma_offset_next = dma_write_block_dma_offset_reg + dma_write_block_dma_stride_reg;
                dma_write_desc_dma_addr_next = dma_write_block_dma_base_addr_reg + (dma_write_block_dma_offset_reg & dma_write_block_dma_offset_mask_reg);
                dma_write_block_ram_offset_next = dma_write_block_ram_offset_reg + dma_write_block_ram_stride_reg;
                dma_write_desc_ram_addr_next = dma_write_block_ram_base_addr_reg + (dma_write_block_ram_offset_reg & dma_write_block_ram_offset_mask_reg);
                dma_write_desc_len_next = dma_write_block_len_reg;
                dma_write_block_count_next = dma_write_block_count_reg - 1;
                dma_write_desc_tag_next = dma_write_block_count_reg;
                dma_write_desc_valid_next = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    axil_ctrl_awready_reg <= axil_ctrl_awready_next;
    axil_ctrl_wready_reg <= axil_ctrl_wready_next;
    axil_ctrl_bresp_reg <= axil_ctrl_bresp_next;
    axil_ctrl_bvalid_reg <= axil_ctrl_bvalid_next;
    axil_ctrl_arready_reg <= axil_ctrl_arready_next;
    axil_ctrl_rdata_reg <= axil_ctrl_rdata_next;
    axil_ctrl_rresp_reg <= axil_ctrl_rresp_next;
    axil_ctrl_rvalid_reg <= axil_ctrl_rvalid_next;

    cycle_count_reg <= cycle_count_reg + 1;

    dma_read_active_count_reg <= dma_read_active_count_reg
        + (m_axis_dma_read_desc_valid && m_axis_dma_read_desc_ready)
        - s_axis_dma_read_desc_status_valid;
    dma_write_active_count_reg <= dma_write_active_count_reg
        + (m_axis_dma_write_desc_valid && m_axis_dma_write_desc_ready)
        - s_axis_dma_write_desc_status_valid;

    dma_read_desc_dma_addr_reg <= dma_read_desc_dma_addr_next;
    dma_read_desc_ram_addr_reg <= dma_read_desc_ram_addr_next;
    dma_read_desc_len_reg <= dma_read_desc_len_next;
    dma_read_desc_tag_reg <= dma_read_desc_tag_next;
    dma_read_desc_valid_reg <= dma_read_desc_valid_next;

    dma_read_desc_status_tag_reg <= dma_read_desc_status_tag_next;
    dma_read_desc_status_error_reg <= dma_read_desc_status_error_next;
    dma_read_desc_status_valid_reg <= dma_read_desc_status_valid_next;

    dma_write_desc_dma_addr_reg <= dma_write_desc_dma_addr_next;
    dma_write_desc_ram_addr_reg <= dma_write_desc_ram_addr_next;
    dma_write_desc_len_reg <= dma_write_desc_len_next;
    dma_write_desc_tag_reg <= dma_write_desc_tag_next;
    dma_write_desc_valid_reg <= dma_write_desc_valid_next;

    dma_write_desc_status_tag_reg <= dma_write_desc_status_tag_next;
    dma_write_desc_status_error_reg <= dma_write_desc_status_error_next;
    dma_write_desc_status_valid_reg <= dma_write_desc_status_valid_next;

    dma_enable_reg <= dma_enable_next;

    dma_rd_int_en_reg <= dma_rd_int_en_next;
    dma_wr_int_en_reg <= dma_wr_int_en_next;

    dma_read_block_run_reg <= dma_read_block_run_next;
    dma_read_block_len_reg <= dma_read_block_len_next;
    dma_read_block_count_reg <= dma_read_block_count_next;
    dma_read_block_cycle_count_reg <= dma_read_block_cycle_count_next;
    dma_read_block_dma_base_addr_reg <= dma_read_block_dma_base_addr_next;
    dma_read_block_dma_offset_reg <= dma_read_block_dma_offset_next;
    dma_read_block_dma_offset_mask_reg <= dma_read_block_dma_offset_mask_next;
    dma_read_block_dma_stride_reg <= dma_read_block_dma_stride_next;
    dma_read_block_ram_base_addr_reg <= dma_read_block_ram_base_addr_next;
    dma_read_block_ram_offset_reg <= dma_read_block_ram_offset_next;
    dma_read_block_ram_offset_mask_reg <= dma_read_block_ram_offset_mask_next;
    dma_read_block_ram_stride_reg <= dma_read_block_ram_stride_next;

    dma_write_block_run_reg <= dma_write_block_run_next;
    dma_write_block_len_reg <= dma_write_block_len_next;
    dma_write_block_count_reg <= dma_write_block_count_next;
    dma_write_block_cycle_count_reg <= dma_write_block_cycle_count_next;
    dma_write_block_dma_base_addr_reg <= dma_write_block_dma_base_addr_next;
    dma_write_block_dma_offset_reg <= dma_write_block_dma_offset_next;
    dma_write_block_dma_offset_mask_reg <= dma_write_block_dma_offset_mask_next;
    dma_write_block_dma_stride_reg <= dma_write_block_dma_stride_next;
    dma_write_block_ram_base_addr_reg <= dma_write_block_ram_base_addr_next;
    dma_write_block_ram_offset_reg <= dma_write_block_ram_offset_next;
    dma_write_block_ram_offset_mask_reg <= dma_write_block_ram_offset_mask_next;
    dma_write_block_ram_stride_reg <= dma_write_block_ram_stride_next;

    if (rst) begin
        axil_ctrl_awready_reg <= 1'b0;
        axil_ctrl_wready_reg <= 1'b0;
        axil_ctrl_bvalid_reg <= 1'b0;
        axil_ctrl_arready_reg <= 1'b0;
        axil_ctrl_rvalid_reg <= 1'b0;

        cycle_count_reg <= 0;
        dma_read_active_count_reg <= 0;
        dma_write_active_count_reg <= 0;

        dma_read_desc_valid_reg <= 1'b0;
        dma_read_desc_status_valid_reg <= 1'b0;
        dma_write_desc_valid_reg <= 1'b0;
        dma_write_desc_status_valid_reg <= 1'b0;
        dma_enable_reg <= 1'b0;
        dma_rd_int_en_reg <= 1'b0;
        dma_wr_int_en_reg <= 1'b0;
        dma_read_block_run_reg <= 1'b0;
        dma_write_block_run_reg <= 1'b0;
    end
end

endmodule

`resetall
