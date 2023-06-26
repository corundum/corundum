// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */


// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * DMA benchmark module
 */
module dma_bench #
(
    // DMA interface configuration
    parameter DMA_ADDR_WIDTH = 64,
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_SEL_WIDTH = 4,
    parameter RAM_ADDR_WIDTH = 16,
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
    parameter RAM_PIPELINE = 2,

    // Register interface
    parameter REG_ADDR_WIDTH = 7,
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    parameter RB_BASE_ADDR = 0,
    parameter RB_NEXT_PTR = 0
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * Register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]                    reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]                    reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]                    reg_wr_strb,
    input  wire                                         reg_wr_en,
    output wire                                         reg_wr_wait,
    output wire                                         reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]                    reg_rd_addr,
    input  wire                                         reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]                    reg_rd_data,
    output wire                                         reg_rd_wait,
    output wire                                         reg_rd_ack,

    /*
     * DMA read descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_read_desc_tag,
    output wire                                         m_axis_dma_read_desc_valid,
    input  wire                                         m_axis_dma_read_desc_ready,

    /*
     * DMA read descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_read_desc_status_error,
    input  wire                                         s_axis_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                     m_axis_dma_write_desc_imm,
    output wire                                         m_axis_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_write_desc_tag,
    output wire                                         m_axis_dma_write_desc_valid,
    input  wire                                         m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_write_desc_status_error,
    input  wire                                         s_axis_dma_write_desc_status_valid,

    /*
     * DMA RAM interface
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_ready
);

localparam RAM_ADDR_IMM_WIDTH = (DMA_IMM_ENABLE && (DMA_IMM_WIDTH > RAM_ADDR_WIDTH)) ? DMA_IMM_WIDTH : RAM_ADDR_WIDTH;

localparam RBB = RB_BASE_ADDR & {REG_ADDR_WIDTH{1'b1}};

// check configuration
initial begin
    if (REG_DATA_WIDTH != 32) begin
        $error("Error: Register interface width must be 32 (instance %m)");
        $finish;
    end

    if (REG_STRB_WIDTH * 8 != REG_DATA_WIDTH) begin
        $error("Error: Register interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (REG_ADDR_WIDTH < 12) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end

    if (RB_NEXT_PTR && RB_NEXT_PTR >= RB_BASE_ADDR && RB_NEXT_PTR < RB_BASE_ADDR + 13'h1000) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end
end

// control registers
reg reg_wr_ack_reg = 1'b0, reg_wr_ack_next;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0, reg_rd_data_next;
reg reg_rd_ack_reg = 1'b0, reg_rd_ack_next;

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
reg [RAM_ADDR_IMM_WIDTH-1:0] dma_write_desc_ram_addr_imm_reg = 0, dma_write_desc_ram_addr_imm_next;
reg dma_write_desc_imm_en_reg = 0, dma_write_desc_imm_en_next;
reg [DMA_LEN_WIDTH-1:0] dma_write_desc_len_reg = 0, dma_write_desc_len_next;
reg [DMA_TAG_WIDTH-1:0] dma_write_desc_tag_reg = 0, dma_write_desc_tag_next;
reg dma_write_desc_valid_reg = 0, dma_write_desc_valid_next;

reg [DMA_TAG_WIDTH-1:0] dma_write_desc_status_tag_reg = 0, dma_write_desc_status_tag_next;
reg [3:0] dma_write_desc_status_error_reg = 0, dma_write_desc_status_error_next;
reg dma_write_desc_status_valid_reg = 0, dma_write_desc_status_valid_next;

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

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

assign m_axis_dma_read_desc_dma_addr = dma_read_desc_dma_addr_reg;
assign m_axis_dma_read_desc_ram_sel = 0;
assign m_axis_dma_read_desc_ram_addr = dma_read_desc_ram_addr_reg;
assign m_axis_dma_read_desc_len = dma_read_desc_len_reg;
assign m_axis_dma_read_desc_tag = dma_read_desc_tag_reg;
assign m_axis_dma_read_desc_valid = dma_read_desc_valid_reg;

assign m_axis_dma_write_desc_dma_addr = dma_write_desc_dma_addr_reg;
assign m_axis_dma_write_desc_ram_sel = 0;
assign m_axis_dma_write_desc_ram_addr = dma_write_desc_ram_addr_imm_reg;
assign m_axis_dma_write_desc_imm = dma_write_desc_ram_addr_imm_reg;
assign m_axis_dma_write_desc_imm_en = dma_write_desc_imm_en_reg;
assign m_axis_dma_write_desc_len = dma_write_desc_len_reg;
assign m_axis_dma_write_desc_tag = dma_write_desc_tag_reg;
assign m_axis_dma_write_desc_valid = dma_write_desc_valid_reg;

always @* begin
    reg_wr_ack_next = 1'b0;
    reg_rd_data_next = 0;
    reg_rd_ack_next = 1'b0;

    dma_read_desc_dma_addr_next = dma_read_desc_dma_addr_reg;
    dma_read_desc_ram_addr_next = dma_read_desc_ram_addr_reg;
    dma_read_desc_len_next = dma_read_desc_len_reg;
    dma_read_desc_tag_next = dma_read_desc_tag_reg;
    dma_read_desc_valid_next = dma_read_desc_valid_reg && !m_axis_dma_read_desc_ready;

    dma_read_desc_status_tag_next = dma_read_desc_status_tag_reg;
    dma_read_desc_status_error_next = dma_read_desc_status_error_reg;
    dma_read_desc_status_valid_next = dma_read_desc_status_valid_reg;

    dma_write_desc_dma_addr_next = dma_write_desc_dma_addr_reg;
    dma_write_desc_ram_addr_imm_next = dma_write_desc_ram_addr_imm_reg;
    dma_write_desc_imm_en_next = dma_write_desc_imm_en_reg;
    dma_write_desc_len_next = dma_write_desc_len_reg;
    dma_write_desc_tag_next = dma_write_desc_tag_reg;
    dma_write_desc_valid_next = dma_write_desc_valid_reg && !m_axis_dma_write_desc_ready;

    dma_write_desc_status_tag_next = dma_write_desc_status_tag_reg;
    dma_write_desc_status_error_next = dma_write_desc_status_error_reg;
    dma_write_desc_status_valid_next = dma_write_desc_status_valid_reg;

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

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_next = 1'b1;
        case ({reg_wr_addr >> 2, 2'b00})
            // control
            RBB+12'h00c: begin
                dma_rd_int_en_next = reg_wr_data[0];
                dma_wr_int_en_next = reg_wr_data[1];
            end
            // single read
            RBB+12'h100: dma_read_desc_dma_addr_next[31:0] = reg_wr_data;
            RBB+12'h104: dma_read_desc_dma_addr_next[63:32] = reg_wr_data;
            RBB+12'h108: dma_read_desc_ram_addr_next = reg_wr_data;
            RBB+12'h110: dma_read_desc_len_next = reg_wr_data;
            RBB+12'h114: begin
                dma_read_desc_tag_next = reg_wr_data;
                dma_read_desc_valid_next = 1'b1;
            end
            // single write
            RBB+12'h200: dma_write_desc_dma_addr_next[31:0] = reg_wr_data;
            RBB+12'h204: dma_write_desc_dma_addr_next[63:32] = reg_wr_data;
            RBB+12'h208: dma_write_desc_ram_addr_imm_next = reg_wr_data;
            RBB+12'h210: dma_write_desc_len_next = reg_wr_data;
            RBB+12'h214: begin
                dma_write_desc_tag_next = reg_wr_data[23:0];
                dma_write_desc_imm_en_next = reg_wr_data[31];
                dma_write_desc_valid_next = 1'b1;
            end
            // block read
            RBB+12'h300: begin
                dma_read_block_run_next = reg_wr_data[0];
            end
            RBB+12'h308: dma_read_block_cycle_count_next[31:0] = reg_wr_data;
            RBB+12'h30c: dma_read_block_cycle_count_next[63:32] = reg_wr_data;
            RBB+12'h310: dma_read_block_len_next = reg_wr_data;
            RBB+12'h318: dma_read_block_count_next[31:0] = reg_wr_data;
            RBB+12'h380: dma_read_block_dma_base_addr_next[31:0] = reg_wr_data;
            RBB+12'h384: dma_read_block_dma_base_addr_next[63:32] = reg_wr_data;
            RBB+12'h388: dma_read_block_dma_offset_next[31:0] = reg_wr_data;
            RBB+12'h38c: dma_read_block_dma_offset_next[63:32] = reg_wr_data;
            RBB+12'h390: dma_read_block_dma_offset_mask_next[31:0] = reg_wr_data;
            RBB+12'h394: dma_read_block_dma_offset_mask_next[63:32] = reg_wr_data;
            RBB+12'h398: dma_read_block_dma_stride_next[31:0] = reg_wr_data;
            RBB+12'h39c: dma_read_block_dma_stride_next[63:32] = reg_wr_data;
            RBB+12'h3c0: dma_read_block_ram_base_addr_next = reg_wr_data;
            RBB+12'h3c8: dma_read_block_ram_offset_next = reg_wr_data;
            RBB+12'h3d0: dma_read_block_ram_offset_mask_next = reg_wr_data;
            RBB+12'h3d8: dma_read_block_ram_stride_next = reg_wr_data;
            // block write
            RBB+12'h400: begin
                dma_write_block_run_next = reg_wr_data[0];
            end
            RBB+12'h408: dma_write_block_cycle_count_next[31:0] = reg_wr_data;
            RBB+12'h40c: dma_write_block_cycle_count_next[63:32] = reg_wr_data;
            RBB+12'h410: dma_write_block_len_next = reg_wr_data;
            RBB+12'h418: dma_write_block_count_next[31:0] = reg_wr_data;
            RBB+12'h480: dma_write_block_dma_base_addr_next[31:0] = reg_wr_data;
            RBB+12'h484: dma_write_block_dma_base_addr_next[63:32] = reg_wr_data;
            RBB+12'h488: dma_write_block_dma_offset_next[31:0] = reg_wr_data;
            RBB+12'h48c: dma_write_block_dma_offset_next[63:32] = reg_wr_data;
            RBB+12'h490: dma_write_block_dma_offset_mask_next[31:0] = reg_wr_data;
            RBB+12'h494: dma_write_block_dma_offset_mask_next[63:32] = reg_wr_data;
            RBB+12'h498: dma_write_block_dma_stride_next[31:0] = reg_wr_data;
            RBB+12'h49c: dma_write_block_dma_stride_next[63:32] = reg_wr_data;
            RBB+12'h4c0: dma_write_block_ram_base_addr_next = reg_wr_data;
            RBB+12'h4c8: dma_write_block_ram_offset_next = reg_wr_data;
            RBB+12'h4d0: dma_write_block_ram_offset_mask_next = reg_wr_data;
            RBB+12'h4d8: dma_write_block_ram_stride_next = reg_wr_data;
            default: reg_wr_ack_next = 1'b0;
        endcase
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_next = 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            RBB+12'h000: reg_rd_data_next = 32'h12348101;  // Type
            RBB+12'h004: reg_rd_data_next = 32'h00000100;  // Version
            RBB+12'h008: reg_rd_data_next = RB_NEXT_PTR;   // Next header
            // control
            RBB+12'h00c: begin
                reg_rd_data_next[0] = dma_rd_int_en_reg;
                reg_rd_data_next[1] = dma_wr_int_en_reg;
            end
            RBB+12'h010: reg_rd_data_next = cycle_count_reg;
            RBB+12'h014: reg_rd_data_next = cycle_count_reg >> 32;
            RBB+12'h020: reg_rd_data_next = dma_read_active_count_reg;
            RBB+12'h028: reg_rd_data_next = dma_write_active_count_reg;
            // single read
            RBB+12'h100: reg_rd_data_next = dma_read_desc_dma_addr_reg;
            RBB+12'h104: reg_rd_data_next = dma_read_desc_dma_addr_reg >> 32;
            RBB+12'h108: reg_rd_data_next = dma_read_desc_ram_addr_reg;
            RBB+12'h10c: reg_rd_data_next = dma_read_desc_ram_addr_reg >> 32;
            RBB+12'h110: reg_rd_data_next = dma_read_desc_len_reg;
            RBB+12'h114: reg_rd_data_next = dma_read_desc_tag_reg;
            RBB+12'h118: begin
                reg_rd_data_next[15:0] = dma_read_desc_status_tag_reg;
                reg_rd_data_next[27:24] = dma_read_desc_status_error_reg;
                reg_rd_data_next[31] = dma_read_desc_status_valid_reg;
                dma_read_desc_status_valid_next = 1'b0;
            end
            // single write
            RBB+12'h200: reg_rd_data_next = dma_write_desc_dma_addr_reg;
            RBB+12'h204: reg_rd_data_next = dma_write_desc_dma_addr_reg >> 32;
            RBB+12'h208: reg_rd_data_next = dma_write_desc_ram_addr_imm_reg;
            RBB+12'h20c: reg_rd_data_next = dma_write_desc_ram_addr_imm_reg >> 32;
            RBB+12'h210: reg_rd_data_next = dma_write_desc_len_reg;
            RBB+12'h214: begin
                reg_rd_data_next[23:0] = dma_write_desc_tag_reg;
                reg_rd_data_next[31] = dma_write_desc_imm_en_reg;
            end
            RBB+12'h218: begin
                reg_rd_data_next[15:0] = dma_write_desc_status_tag_reg;
                reg_rd_data_next[27:24] = dma_write_desc_status_error_reg;
                reg_rd_data_next[31] = dma_write_desc_status_valid_reg;
                dma_write_desc_status_valid_next = 1'b0;
            end
            // block read
            RBB+12'h300: begin
                reg_rd_data_next[0] = dma_read_block_run_reg;
            end
            RBB+12'h308: reg_rd_data_next = dma_read_block_cycle_count_reg;
            RBB+12'h30c: reg_rd_data_next = dma_read_block_cycle_count_reg >> 32;
            RBB+12'h310: reg_rd_data_next = dma_read_block_len_reg;
            RBB+12'h318: reg_rd_data_next = dma_read_block_count_reg;
            RBB+12'h31c: reg_rd_data_next = dma_read_block_count_reg >> 32;
            RBB+12'h380: reg_rd_data_next = dma_read_block_dma_base_addr_reg;
            RBB+12'h384: reg_rd_data_next = dma_read_block_dma_base_addr_reg >> 32;
            RBB+12'h388: reg_rd_data_next = dma_read_block_dma_offset_reg;
            RBB+12'h38c: reg_rd_data_next = dma_read_block_dma_offset_reg >> 32;
            RBB+12'h390: reg_rd_data_next = dma_read_block_dma_offset_mask_reg;
            RBB+12'h394: reg_rd_data_next = dma_read_block_dma_offset_mask_reg >> 32;
            RBB+12'h398: reg_rd_data_next = dma_read_block_dma_stride_reg;
            RBB+12'h39c: reg_rd_data_next = dma_read_block_dma_stride_reg >> 32;
            RBB+12'h3c0: reg_rd_data_next = dma_read_block_ram_base_addr_reg;
            RBB+12'h3c4: reg_rd_data_next = dma_read_block_ram_base_addr_reg >> 32;
            RBB+12'h3c8: reg_rd_data_next = dma_read_block_ram_offset_reg;
            RBB+12'h3cc: reg_rd_data_next = dma_read_block_ram_offset_reg >> 32;
            RBB+12'h3d0: reg_rd_data_next = dma_read_block_ram_offset_mask_reg;
            RBB+12'h3d4: reg_rd_data_next = dma_read_block_ram_offset_mask_reg >> 32;
            RBB+12'h3d8: reg_rd_data_next = dma_read_block_ram_stride_reg;
            RBB+12'h3dc: reg_rd_data_next = dma_read_block_ram_stride_reg >> 32;
            // block write
            RBB+12'h400: begin
                reg_rd_data_next[0] = dma_write_block_run_reg;
            end
            RBB+12'h408: reg_rd_data_next = dma_write_block_cycle_count_reg;
            RBB+12'h40c: reg_rd_data_next = dma_write_block_cycle_count_reg >> 32;
            RBB+12'h410: reg_rd_data_next = dma_write_block_len_reg;
            RBB+12'h418: reg_rd_data_next = dma_write_block_count_reg;
            RBB+12'h41c: reg_rd_data_next = dma_write_block_count_reg >> 32;
            RBB+12'h480: reg_rd_data_next = dma_write_block_dma_base_addr_reg;
            RBB+12'h484: reg_rd_data_next = dma_write_block_dma_base_addr_reg >> 32;
            RBB+12'h488: reg_rd_data_next = dma_write_block_dma_offset_reg;
            RBB+12'h48c: reg_rd_data_next = dma_write_block_dma_offset_reg >> 32;
            RBB+12'h490: reg_rd_data_next = dma_write_block_dma_offset_mask_reg;
            RBB+12'h494: reg_rd_data_next = dma_write_block_dma_offset_mask_reg >> 32;
            RBB+12'h498: reg_rd_data_next = dma_write_block_dma_stride_reg;
            RBB+12'h49c: reg_rd_data_next = dma_write_block_dma_stride_reg >> 32;
            RBB+12'h4c0: reg_rd_data_next = dma_write_block_ram_base_addr_reg;
            RBB+12'h4c4: reg_rd_data_next = dma_write_block_ram_base_addr_reg >> 32;
            RBB+12'h4c8: reg_rd_data_next = dma_write_block_ram_offset_reg;
            RBB+12'h4cc: reg_rd_data_next = dma_write_block_ram_offset_reg >> 32;
            RBB+12'h4d0: reg_rd_data_next = dma_write_block_ram_offset_mask_reg;
            RBB+12'h4d4: reg_rd_data_next = dma_write_block_ram_offset_mask_reg >> 32;
            RBB+12'h4d8: reg_rd_data_next = dma_write_block_ram_stride_reg;
            RBB+12'h4dc: reg_rd_data_next = dma_write_block_ram_stride_reg >> 32;
            default: reg_rd_ack_next = 1'b0;
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
                dma_write_desc_ram_addr_imm_next = dma_write_block_ram_base_addr_reg + (dma_write_block_ram_offset_reg & dma_write_block_ram_offset_mask_reg);
                dma_write_desc_imm_en_next = 1'b0;
                dma_write_desc_len_next = dma_write_block_len_reg;
                dma_write_block_count_next = dma_write_block_count_reg - 1;
                dma_write_desc_tag_next = dma_write_block_count_reg;
                dma_write_desc_valid_next = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    reg_wr_ack_reg <= reg_wr_ack_next;
    reg_rd_data_reg <= reg_rd_data_next;
    reg_rd_ack_reg <= reg_rd_ack_next;

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
    dma_write_desc_ram_addr_imm_reg <= dma_write_desc_ram_addr_imm_next;
    dma_write_desc_imm_en_reg <= dma_write_desc_imm_en_next;
    dma_write_desc_len_reg <= dma_write_desc_len_next;
    dma_write_desc_tag_reg <= dma_write_desc_tag_next;
    dma_write_desc_valid_reg <= dma_write_desc_valid_next;

    dma_write_desc_status_tag_reg <= dma_write_desc_status_tag_next;
    dma_write_desc_status_error_reg <= dma_write_desc_status_error_next;
    dma_write_desc_status_valid_reg <= dma_write_desc_status_valid_next;

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
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        cycle_count_reg <= 0;
        dma_read_active_count_reg <= 0;
        dma_write_active_count_reg <= 0;

        dma_read_desc_valid_reg <= 1'b0;
        dma_read_desc_status_valid_reg <= 1'b0;
        dma_write_desc_valid_reg <= 1'b0;
        dma_write_desc_status_valid_reg <= 1'b0;
        dma_rd_int_en_reg <= 1'b0;
        dma_wr_int_en_reg <= 1'b0;
        dma_read_block_run_reg <= 1'b0;
        dma_write_block_run_reg <= 1'b0;
    end
end

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
    .wr_cmd_be(dma_ram_wr_cmd_be),
    .wr_cmd_addr(dma_ram_wr_cmd_addr),
    .wr_cmd_data(dma_ram_wr_cmd_data),
    .wr_cmd_valid(dma_ram_wr_cmd_valid),
    .wr_cmd_ready(dma_ram_wr_cmd_ready),
    .wr_done(dma_ram_wr_done),

    /*
     * Read port
     */
    .rd_cmd_addr(dma_ram_rd_cmd_addr),
    .rd_cmd_valid(dma_ram_rd_cmd_valid),
    .rd_cmd_ready(dma_ram_rd_cmd_ready),
    .rd_resp_data(dma_ram_rd_resp_data),
    .rd_resp_valid(dma_ram_rd_resp_valid),
    .rd_resp_ready(dma_ram_rd_resp_ready)
);

endmodule

`resetall
