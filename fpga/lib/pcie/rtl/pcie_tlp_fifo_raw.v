/*

Copyright (c) 2022 Alex Forencich

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
 * PCIe TLP FIFO (raw output)
 */
module pcie_tlp_fifo_raw #
(
    // FIFO depth
    parameter DEPTH = 2048,
    // TLP data width
    parameter TLP_DATA_WIDTH = 256,
    // TLP strobe width (input)
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // Sequence number width
    parameter SEQ_NUM_WIDTH = 6,
    // TLP segment count (input)
    parameter IN_TLP_SEG_COUNT = 1,
    // TLP segment count (output)
    parameter OUT_TLP_SEG_COUNT = 1,
    // Segment select width
    parameter SEG_SEL_WIDTH = $clog2(OUT_TLP_SEG_COUNT),
    // Watermark level
    parameter WATERMARK = DEPTH/2,
    // Use control output
    parameter CTRL_OUT_EN = 0
)
(
    input  wire                                        clk,
    input  wire                                        rst,

    /*
     * TLP input
     */
    input  wire [TLP_DATA_WIDTH-1:0]                   in_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                   in_tlp_strb,
    input  wire [IN_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]   in_tlp_hdr,
    input  wire [IN_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]   in_tlp_seq,
    input  wire [IN_TLP_SEG_COUNT*3-1:0]               in_tlp_bar_id,
    input  wire [IN_TLP_SEG_COUNT*8-1:0]               in_tlp_func_num,
    input  wire [IN_TLP_SEG_COUNT*4-1:0]               in_tlp_error,
    input  wire [IN_TLP_SEG_COUNT-1:0]                 in_tlp_valid,
    input  wire [IN_TLP_SEG_COUNT-1:0]                 in_tlp_sop,
    input  wire [IN_TLP_SEG_COUNT-1:0]                 in_tlp_eop,
    output wire                                        in_tlp_ready,

    /*
     * TLP output
     */
    output wire [TLP_DATA_WIDTH-1:0]                   out_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]                   out_tlp_strb,
    output wire [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_tlp_hdr,
    output wire [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_tlp_seq,
    output wire [OUT_TLP_SEG_COUNT*3-1:0]              out_tlp_bar_id,
    output wire [OUT_TLP_SEG_COUNT*8-1:0]              out_tlp_func_num,
    output wire [OUT_TLP_SEG_COUNT*4-1:0]              out_tlp_error,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_tlp_valid,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_tlp_sop,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_tlp_eop,
    output wire [SEG_SEL_WIDTH-1:0]                    out_seg_offset,
    output wire [SEG_SEL_WIDTH+1-1:0]                  out_seg_count,
    input  wire                                        out_read_en,
    input  wire [SEG_SEL_WIDTH+1-1:0]                  out_read_seg_count,

    output wire [TLP_STRB_WIDTH-1:0]                   out_ctrl_tlp_strb,
    output wire [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_ctrl_tlp_hdr,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_ctrl_tlp_valid,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_ctrl_tlp_sop,
    output wire [OUT_TLP_SEG_COUNT-1:0]                out_ctrl_tlp_eop,
    output wire [SEG_SEL_WIDTH-1:0]                    out_ctrl_seg_offset,
    output wire [SEG_SEL_WIDTH+1-1:0]                  out_ctrl_seg_count,
    input  wire                                        out_ctrl_read_en,
    input  wire [SEG_SEL_WIDTH+1-1:0]                  out_ctrl_read_seg_count,

    /*
     * Status
     */
    output wire                                        half_full,
    output wire                                        watermark
);

parameter IN_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / IN_TLP_SEG_COUNT;
parameter IN_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / IN_TLP_SEG_COUNT;

parameter OUT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / OUT_TLP_SEG_COUNT;
parameter OUT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / OUT_TLP_SEG_COUNT;

parameter SEG_RATIO = OUT_TLP_SEG_COUNT / IN_TLP_SEG_COUNT;
parameter ADDR_WIDTH = $clog2(DEPTH/TLP_STRB_WIDTH);
parameter PTR_WIDTH = ADDR_WIDTH+SEG_SEL_WIDTH;

// check configuration
initial begin
    if (OUT_TLP_SEG_COUNT < IN_TLP_SEG_COUNT) begin
        $error("Error: Output segment count must be not be less than input segment count (instance %m)");
        $finish;
    end

    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end

    if (TLP_STRB_WIDTH*32 != TLP_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end
end

reg [PTR_WIDTH:0] wr_ptr_reg = 0, wr_ptr_next;
reg [PTR_WIDTH:0] wr_ptr_cur_reg = 0, wr_ptr_cur_next;
reg [PTR_WIDTH:0] rd_ptr_reg = 0, rd_ptr_next;
reg [PTR_WIDTH:0] rd_ptr_ctrl_reg = 0, rd_ptr_ctrl_next;

reg [OUT_TLP_SEG_COUNT-1:0] mem_rd_data_valid_reg = 0, mem_rd_data_valid_next;
reg [OUT_TLP_SEG_COUNT-1:0] ctrl_mem_rd_data_valid_reg = 0, ctrl_mem_rd_data_valid_next;

reg [TLP_DATA_WIDTH-1:0] int_tlp_data;
reg [TLP_STRB_WIDTH-1:0] int_tlp_strb;
reg [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] int_tlp_hdr;
reg [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] int_tlp_seq;
reg [OUT_TLP_SEG_COUNT*3-1:0] int_tlp_bar_id;
reg [OUT_TLP_SEG_COUNT*8-1:0] int_tlp_func_num;
reg [OUT_TLP_SEG_COUNT*4-1:0] int_tlp_error;
reg [OUT_TLP_SEG_COUNT-1:0] int_tlp_valid;
reg [OUT_TLP_SEG_COUNT-1:0] int_tlp_sop;
reg [OUT_TLP_SEG_COUNT-1:0] int_tlp_eop;

reg [TLP_DATA_WIDTH-1:0] seg_mem_wr_data;
reg [TLP_STRB_WIDTH-1:0] seg_mem_wr_strb;
reg [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] seg_mem_wr_hdr;
reg [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] seg_mem_wr_seq;
reg [OUT_TLP_SEG_COUNT*3-1:0] seg_mem_wr_bar_id;
reg [OUT_TLP_SEG_COUNT*8-1:0] seg_mem_wr_func_num;
reg [OUT_TLP_SEG_COUNT*4-1:0] seg_mem_wr_error;
reg [OUT_TLP_SEG_COUNT*1-1:0] seg_mem_wr_valid;
reg [OUT_TLP_SEG_COUNT*1-1:0] seg_mem_wr_sop;
reg [OUT_TLP_SEG_COUNT*1-1:0] seg_mem_wr_eop;
reg [OUT_TLP_SEG_COUNT*ADDR_WIDTH-1:0] seg_mem_wr_addr_reg = 0, seg_mem_wr_addr_next;
reg [OUT_TLP_SEG_COUNT-1:0] seg_mem_wr_en;
reg [OUT_TLP_SEG_COUNT*SEG_SEL_WIDTH-1:0] seg_mem_wr_sel;

wire [TLP_DATA_WIDTH-1:0] seg_mem_rd_data;
wire [TLP_STRB_WIDTH-1:0] seg_mem_rd_strb;
wire [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] seg_mem_rd_hdr;
wire [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] seg_mem_rd_seq;
wire [OUT_TLP_SEG_COUNT*3-1:0] seg_mem_rd_bar_id;
wire [OUT_TLP_SEG_COUNT*8-1:0] seg_mem_rd_func_num;
wire [OUT_TLP_SEG_COUNT*4-1:0] seg_mem_rd_error;
wire [OUT_TLP_SEG_COUNT*1-1:0] seg_mem_rd_sop;
wire [OUT_TLP_SEG_COUNT*1-1:0] seg_mem_rd_eop;
reg [OUT_TLP_SEG_COUNT*ADDR_WIDTH-1:0] seg_mem_rd_addr_reg = 0, seg_mem_rd_addr_next;
reg [OUT_TLP_SEG_COUNT-1:0] seg_mem_rd_en;

wire [TLP_STRB_WIDTH-1:0] seg_ctrl_mem_rd_strb;
wire [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] seg_ctrl_mem_rd_hdr;
wire [OUT_TLP_SEG_COUNT*1-1:0] seg_ctrl_mem_rd_sop;
wire [OUT_TLP_SEG_COUNT*1-1:0] seg_ctrl_mem_rd_eop;
reg [OUT_TLP_SEG_COUNT*ADDR_WIDTH-1:0] seg_ctrl_mem_rd_addr_reg = 0, seg_ctrl_mem_rd_addr_next;
reg [OUT_TLP_SEG_COUNT-1:0] seg_ctrl_mem_rd_en;

reg full_cur_reg = 1'b0;
reg half_full_reg = 1'b0;
reg watermark_reg = 1'b0;
reg [PTR_WIDTH:0] count_reg = 0;
reg full_cur_ctrl_reg = 1'b0;
reg half_full_ctrl_reg = 1'b0;
reg watermark_ctrl_reg = 1'b0;
reg [PTR_WIDTH:0] count_ctrl_reg = 0;

reg [TLP_DATA_WIDTH-1:0] out_tlp_data_reg = 0, out_tlp_data_next;
reg [TLP_STRB_WIDTH-1:0] out_tlp_strb_reg = 0, out_tlp_strb_next;
reg [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] out_tlp_hdr_reg = 0, out_tlp_hdr_next;
reg [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] out_tlp_seq_reg = 0, out_tlp_seq_next;
reg [OUT_TLP_SEG_COUNT*3-1:0] out_tlp_bar_id_reg = 0, out_tlp_bar_id_next;
reg [OUT_TLP_SEG_COUNT*8-1:0] out_tlp_func_num_reg = 0, out_tlp_func_num_next;
reg [OUT_TLP_SEG_COUNT*4-1:0] out_tlp_error_reg = 0, out_tlp_error_next;
reg [OUT_TLP_SEG_COUNT-1:0] out_tlp_valid_reg = 0, out_tlp_valid_next;
reg [OUT_TLP_SEG_COUNT-1:0] out_tlp_sop_reg = 0, out_tlp_sop_next;
reg [OUT_TLP_SEG_COUNT-1:0] out_tlp_eop_reg = 0, out_tlp_eop_next;
reg [SEG_SEL_WIDTH-1:0] out_seg_offset_reg = 0, out_seg_offset_next;
reg [SEG_SEL_WIDTH+1-1:0] out_seg_count_reg = 0, out_seg_count_next;

reg [TLP_STRB_WIDTH-1:0] out_ctrl_tlp_strb_reg = 0, out_ctrl_tlp_strb_next;
reg [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] out_ctrl_tlp_hdr_reg = 0, out_ctrl_tlp_hdr_next;
reg [OUT_TLP_SEG_COUNT-1:0] out_ctrl_tlp_valid_reg = 0, out_ctrl_tlp_valid_next;
reg [OUT_TLP_SEG_COUNT-1:0] out_ctrl_tlp_sop_reg = 0, out_ctrl_tlp_sop_next;
reg [OUT_TLP_SEG_COUNT-1:0] out_ctrl_tlp_eop_reg = 0, out_ctrl_tlp_eop_next;
reg [SEG_SEL_WIDTH-1:0] out_ctrl_seg_offset_reg = 0, out_ctrl_seg_offset_next;
reg [SEG_SEL_WIDTH+1-1:0] out_ctrl_seg_count_reg = 0, out_ctrl_seg_count_next;
reg [OUT_TLP_SEG_COUNT-1:0] out_ctrl_tlp_ready_int_reg = 0, out_ctrl_tlp_ready_int_next;

reg [TLP_STRB_WIDTH-1:0] temp_out_ctrl_tlp_strb_reg = 0, temp_out_ctrl_tlp_strb_next;
reg [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] temp_out_ctrl_tlp_hdr_reg = 0, temp_out_ctrl_tlp_hdr_next;
reg [OUT_TLP_SEG_COUNT-1:0] temp_out_ctrl_tlp_valid_reg = 0, temp_out_ctrl_tlp_valid_next;
reg [OUT_TLP_SEG_COUNT-1:0] temp_out_ctrl_tlp_sop_reg = 0, temp_out_ctrl_tlp_sop_next;
reg [OUT_TLP_SEG_COUNT-1:0] temp_out_ctrl_tlp_eop_reg = 0, temp_out_ctrl_tlp_eop_next;

reg [TLP_STRB_WIDTH-1:0] pipe_out_ctrl_tlp_strb_reg = 0, pipe_out_ctrl_tlp_strb_next;
reg [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] pipe_out_ctrl_tlp_hdr_reg = 0, pipe_out_ctrl_tlp_hdr_next;
reg [OUT_TLP_SEG_COUNT-1:0] pipe_out_ctrl_tlp_valid_reg = 0, pipe_out_ctrl_tlp_valid_next;
reg [OUT_TLP_SEG_COUNT-1:0] pipe_out_ctrl_tlp_sop_reg = 0, pipe_out_ctrl_tlp_sop_next;
reg [OUT_TLP_SEG_COUNT-1:0] pipe_out_ctrl_tlp_eop_reg = 0, pipe_out_ctrl_tlp_eop_next;

assign in_tlp_ready = !(full_cur_reg | (CTRL_OUT_EN ? full_cur_ctrl_reg : 0));

assign out_tlp_data = out_tlp_data_reg;
assign out_tlp_strb = out_tlp_strb_reg;
assign out_tlp_hdr = out_tlp_hdr_reg;
assign out_tlp_seq = out_tlp_seq_reg;
assign out_tlp_bar_id = out_tlp_bar_id_reg;
assign out_tlp_func_num = out_tlp_func_num_reg;
assign out_tlp_error = out_tlp_error_reg;
assign out_tlp_valid = out_tlp_valid_reg;
assign out_tlp_sop = out_tlp_sop_reg;
assign out_tlp_eop = out_tlp_eop_reg;
assign out_seg_offset = out_seg_offset_reg;
assign out_seg_count = out_seg_count_reg;

assign out_ctrl_tlp_strb = out_ctrl_tlp_strb_reg;
assign out_ctrl_tlp_hdr = out_ctrl_tlp_hdr_reg;
assign out_ctrl_tlp_valid = out_ctrl_tlp_valid_reg;
assign out_ctrl_tlp_sop = out_ctrl_tlp_sop_reg;
assign out_ctrl_tlp_eop = out_ctrl_tlp_eop_reg;
assign out_ctrl_seg_offset = out_ctrl_seg_offset_reg;
assign out_ctrl_seg_count = out_ctrl_seg_count_reg;

assign half_full = half_full_reg | (CTRL_OUT_EN ? half_full_ctrl_reg : 0);
assign watermark = watermark_reg | (CTRL_OUT_EN ? watermark_ctrl_reg : 0);

generate

genvar n;

for (n = 0; n < OUT_TLP_SEG_COUNT; n = n + 1) begin : seg_ram

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [OUT_TLP_SEG_DATA_WIDTH-1:0] seg_mem_data[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [OUT_TLP_SEG_STRB_WIDTH-1:0] seg_mem_strb[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [TLP_HDR_WIDTH-1:0] seg_mem_hdr[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEQ_NUM_WIDTH-1:0] seg_mem_seq[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [2:0] seg_mem_bar_id[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [7:0] seg_mem_func_num[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [3:0] seg_mem_error[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg seg_mem_sop[2**ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg seg_mem_eop[2**ADDR_WIDTH-1:0];

    wire wr_en = seg_mem_wr_en[n];
    wire [ADDR_WIDTH-1:0] wr_addr = seg_mem_wr_addr_reg[n*ADDR_WIDTH +: ADDR_WIDTH];
    wire [OUT_TLP_SEG_DATA_WIDTH-1:0] wr_data = seg_mem_wr_data[n*OUT_TLP_SEG_DATA_WIDTH +: OUT_TLP_SEG_DATA_WIDTH];
    wire [OUT_TLP_SEG_STRB_WIDTH-1:0] wr_strb = seg_mem_wr_strb[n*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH];
    wire [TLP_HDR_WIDTH-1:0] wr_hdr = seg_mem_wr_hdr[n*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
    wire [SEQ_NUM_WIDTH-1:0] wr_seq = seg_mem_wr_seq[n*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
    wire [2:0] wr_bar_id = seg_mem_wr_bar_id[n*3 +: 3];
    wire [7:0] wr_func_num = seg_mem_wr_func_num[n*8 +: 8];
    wire [3:0] wr_error = seg_mem_wr_error[n*4 +: 4];
    wire wr_sop = seg_mem_wr_sop[n*1 +: 1];
    wire wr_eop = seg_mem_wr_eop[n*1 +: 1];

    wire rd_en = seg_mem_rd_en[n];
    wire [ADDR_WIDTH-1:0] rd_addr = seg_mem_rd_addr_reg[n*ADDR_WIDTH +: ADDR_WIDTH];
    reg [OUT_TLP_SEG_DATA_WIDTH-1:0] rd_data_reg = 0;
    reg [OUT_TLP_SEG_STRB_WIDTH-1:0] rd_strb_reg = 0;
    reg [TLP_HDR_WIDTH-1:0] rd_hdr_reg = 0;
    reg [SEQ_NUM_WIDTH-1:0] rd_seq_reg = 0;
    reg [2:0] rd_bar_id_reg = 0;
    reg [7:0] rd_func_num_reg = 0;
    reg [3:0] rd_error_reg = 0;
    reg rd_sop_reg = 0;
    reg rd_eop_reg = 0;

    assign seg_mem_rd_data[n*OUT_TLP_SEG_DATA_WIDTH +: OUT_TLP_SEG_DATA_WIDTH] = rd_data_reg;
    assign seg_mem_rd_strb[n*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = rd_strb_reg;
    assign seg_mem_rd_hdr[n*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = rd_hdr_reg;
    assign seg_mem_rd_seq[n*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = rd_seq_reg;
    assign seg_mem_rd_bar_id[n*3 +: 3] = rd_bar_id_reg;
    assign seg_mem_rd_func_num[n*8 +: 8] = rd_func_num_reg;
    assign seg_mem_rd_error[n*4 +: 4] = rd_error_reg;
    assign seg_mem_rd_sop[n*1 +: 1] = rd_sop_reg;
    assign seg_mem_rd_eop[n*1 +: 1] = rd_eop_reg;

    always @(posedge clk) begin
        if (wr_en) begin
            seg_mem_data[wr_addr] <= wr_data;
            seg_mem_strb[wr_addr] <= wr_strb;
            seg_mem_hdr[wr_addr] <= wr_hdr;
            seg_mem_seq[wr_addr] <= wr_seq;
            seg_mem_bar_id[wr_addr] <= wr_bar_id;
            seg_mem_func_num[wr_addr] <= wr_func_num;
            seg_mem_error[wr_addr] <= wr_error;
            seg_mem_sop[wr_addr] <= wr_sop;
            seg_mem_eop[wr_addr] <= wr_eop;
        end
    end

    always @(posedge clk) begin
        if (rd_en) begin
            rd_data_reg <= seg_mem_data[rd_addr];
            rd_strb_reg <= seg_mem_strb[rd_addr];
            rd_hdr_reg <= seg_mem_hdr[rd_addr];
            rd_seq_reg <= seg_mem_seq[rd_addr];
            rd_bar_id_reg <= seg_mem_bar_id[rd_addr];
            rd_func_num_reg <= seg_mem_func_num[rd_addr];
            rd_error_reg <= seg_mem_error[rd_addr];
            rd_sop_reg <= seg_mem_sop[rd_addr];
            rd_eop_reg <= seg_mem_eop[rd_addr];
        end
    end

    if (CTRL_OUT_EN) begin

        wire ctrl_rd_en = seg_ctrl_mem_rd_en[n];
        wire [ADDR_WIDTH-1:0] ctrl_rd_addr = seg_ctrl_mem_rd_addr_reg[n*ADDR_WIDTH +: ADDR_WIDTH];
        reg [OUT_TLP_SEG_STRB_WIDTH-1:0] ctrl_rd_strb_reg = 0;
        reg [TLP_HDR_WIDTH-1:0] ctrl_rd_hdr_reg = 0;
        reg ctrl_rd_sop_reg = 0;
        reg ctrl_rd_eop_reg = 0;

        assign seg_ctrl_mem_rd_strb[n*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = ctrl_rd_strb_reg;
        assign seg_ctrl_mem_rd_hdr[n*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = ctrl_rd_hdr_reg;
        assign seg_ctrl_mem_rd_sop[n*1 +: 1] = ctrl_rd_sop_reg;
        assign seg_ctrl_mem_rd_eop[n*1 +: 1] = ctrl_rd_eop_reg;

        always @(posedge clk) begin
            if (ctrl_rd_en) begin
                ctrl_rd_strb_reg <= seg_mem_strb[ctrl_rd_addr];
                ctrl_rd_hdr_reg <= seg_mem_hdr[ctrl_rd_addr];
                ctrl_rd_sop_reg <= seg_mem_sop[ctrl_rd_addr];
                ctrl_rd_eop_reg <= seg_mem_eop[ctrl_rd_addr];
            end
        end

    end

end

endgenerate

// limits
always @(posedge clk) begin
    full_cur_reg <= $unsigned(wr_ptr_cur_reg - rd_ptr_reg) >= DEPTH/TLP_STRB_WIDTH*OUT_TLP_SEG_COUNT-OUT_TLP_SEG_COUNT*2;
    half_full_reg <= $unsigned(wr_ptr_cur_reg - rd_ptr_reg) >= DEPTH/TLP_STRB_WIDTH*OUT_TLP_SEG_COUNT/2;
    watermark_reg <= $unsigned(wr_ptr_cur_reg - rd_ptr_reg) >= WATERMARK/TLP_STRB_WIDTH*OUT_TLP_SEG_COUNT;
    full_cur_ctrl_reg <= $unsigned(wr_ptr_cur_reg - rd_ptr_ctrl_reg) >= DEPTH/TLP_STRB_WIDTH*OUT_TLP_SEG_COUNT-OUT_TLP_SEG_COUNT*2;
    half_full_ctrl_reg <= $unsigned(wr_ptr_cur_reg - rd_ptr_ctrl_reg) >= DEPTH/TLP_STRB_WIDTH*OUT_TLP_SEG_COUNT/2;
    watermark_ctrl_reg <= $unsigned(wr_ptr_cur_reg - rd_ptr_ctrl_reg) >= WATERMARK/TLP_STRB_WIDTH*OUT_TLP_SEG_COUNT;

    if (rst) begin
        full_cur_reg <= 1'b0;
        half_full_reg <= 1'b0;
        watermark_reg <= 1'b0;
        full_cur_ctrl_reg <= 1'b0;
        half_full_ctrl_reg <= 1'b0;
        watermark_ctrl_reg <= 1'b0;
    end
end

// Split input segments
integer si, so;

always @* begin
    int_tlp_data = in_tlp_data;
    int_tlp_strb = in_tlp_strb;
    if (IN_TLP_SEG_COUNT != OUT_TLP_SEG_COUNT) begin
        for (si = 0; si < IN_TLP_SEG_COUNT; si = si + 1) begin
            int_tlp_hdr[si*TLP_HDR_WIDTH*SEG_RATIO +: TLP_HDR_WIDTH*SEG_RATIO] = in_tlp_hdr[si*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
            int_tlp_seq[si*SEQ_NUM_WIDTH*SEG_RATIO +: SEQ_NUM_WIDTH*SEG_RATIO] = in_tlp_seq[si*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
            int_tlp_bar_id[si*3*SEG_RATIO +: 3*SEG_RATIO] = in_tlp_bar_id[si*3 +: 3];
            int_tlp_func_num[si*8*SEG_RATIO +: 8*SEG_RATIO] = in_tlp_func_num[si*8 +: 8];
            int_tlp_error[si*4*SEG_RATIO +: 4*SEG_RATIO] = in_tlp_error[si*4 +: 4];
            int_tlp_valid[si*SEG_RATIO +: SEG_RATIO] = in_tlp_valid[si +: 1];
            int_tlp_sop[si*SEG_RATIO +: SEG_RATIO] = in_tlp_sop[si +: 1];
            int_tlp_eop[si*SEG_RATIO +: SEG_RATIO] = in_tlp_eop[si +: 1];
            for (so = 0; so < SEG_RATIO; so = so + 1) begin
                if (in_tlp_strb[si*IN_TLP_SEG_STRB_WIDTH+so*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH]) begin
                    int_tlp_valid[si*SEG_RATIO+so] = in_tlp_valid[si +: 1];
                    int_tlp_eop[si*SEG_RATIO +: SEG_RATIO] = in_tlp_eop[si +: 1] << so;
                end
            end
        end
    end else begin
        int_tlp_hdr = in_tlp_hdr;
        int_tlp_seq = in_tlp_seq;
        int_tlp_bar_id = in_tlp_bar_id;
        int_tlp_func_num = in_tlp_func_num;
        int_tlp_error = in_tlp_error;
        int_tlp_valid = in_tlp_valid;
        int_tlp_sop = in_tlp_sop;
        int_tlp_eop = in_tlp_eop;
    end
end

// Write logic
integer seg;
reg [SEG_SEL_WIDTH+1-1:0] seg_count;
reg [SEG_SEL_WIDTH-1:0] cur_seg;
reg [SEG_SEL_WIDTH-1:0] eop_seg;

always @* begin
    wr_ptr_next = wr_ptr_reg;
    wr_ptr_cur_next = wr_ptr_cur_reg;

    if (OUT_TLP_SEG_COUNT > 1) begin
        // pack segments
        seg_mem_wr_valid = 0;
        seg_mem_wr_sel = 0;
        cur_seg = wr_ptr_cur_reg[SEG_SEL_WIDTH-1:0];
        eop_seg = 0;
        seg_count = 0;
        for (seg = 0; seg < OUT_TLP_SEG_COUNT; seg = seg + 1) begin
            if (int_tlp_valid[seg]) begin
                seg_mem_wr_valid[cur_seg +: 1] = 1'b1;
                seg_mem_wr_sel[cur_seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH] = seg;
                cur_seg = cur_seg + 1;
                if (int_tlp_eop[seg]) begin
                    eop_seg = seg_count;
                end
                seg_count = seg_count + 1;
            end
        end

        for (seg = 0; seg < OUT_TLP_SEG_COUNT; seg = seg + 1) begin
            seg_mem_wr_data[seg*OUT_TLP_SEG_DATA_WIDTH +: OUT_TLP_SEG_DATA_WIDTH] = int_tlp_data[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH]*OUT_TLP_SEG_DATA_WIDTH +: OUT_TLP_SEG_DATA_WIDTH];
            seg_mem_wr_strb[seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = int_tlp_strb[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH]*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH];
            seg_mem_wr_hdr[seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = int_tlp_hdr[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH]*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
            seg_mem_wr_seq[seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = int_tlp_seq[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH]*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
            seg_mem_wr_bar_id[seg*3 +: 3] = int_tlp_bar_id[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH]*3 +: 3];
            seg_mem_wr_func_num[seg*8 +: 8] = int_tlp_func_num[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH]*8 +: 8];
            seg_mem_wr_error[seg*4 +: 4] = int_tlp_error[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH]*4 +: 4];
            seg_mem_wr_sop[seg +: 1] = int_tlp_sop[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH] +: 1];
            seg_mem_wr_eop[seg +: 1] = int_tlp_eop[seg_mem_wr_sel[seg*SEG_SEL_WIDTH +: SEG_SEL_WIDTH] +: 1];
        end
    end else begin
        seg_mem_wr_data = in_tlp_data;
        seg_mem_wr_strb = in_tlp_strb;
        seg_mem_wr_hdr = in_tlp_hdr;
        seg_mem_wr_seq = in_tlp_seq;
        seg_mem_wr_bar_id = in_tlp_bar_id;
        seg_mem_wr_func_num = in_tlp_func_num;
        seg_mem_wr_error = in_tlp_error;
        seg_mem_wr_sop = in_tlp_sop;
        seg_mem_wr_eop = in_tlp_eop;
    end

    seg_mem_wr_addr_next = seg_mem_wr_addr_reg;
    seg_mem_wr_en = 0;

    if (in_tlp_ready && in_tlp_valid) begin
        // transfer in
        if (OUT_TLP_SEG_COUNT == 1) begin
            seg_mem_wr_en = 1'b1;
            wr_ptr_cur_next = wr_ptr_cur_reg + 1;
            seg_mem_wr_addr_next = wr_ptr_cur_next;
            if (in_tlp_eop) begin
                // end of frame
                wr_ptr_next = wr_ptr_cur_next;
            end
        end else begin
            seg_mem_wr_en = seg_mem_wr_valid;
            wr_ptr_cur_next = wr_ptr_cur_reg + seg_count;
            for (seg = 0; seg < OUT_TLP_SEG_COUNT; seg = seg + 1) begin
                seg_mem_wr_addr_next[seg*ADDR_WIDTH +: ADDR_WIDTH] = (wr_ptr_cur_next + (OUT_TLP_SEG_COUNT-1 - seg)) >> SEG_SEL_WIDTH;
            end
            if (in_tlp_eop & in_tlp_valid) begin
                // end of frame
                if (IN_TLP_SEG_COUNT > 1) begin
                    wr_ptr_next = wr_ptr_cur_reg + eop_seg + 1;
                end else begin
                    wr_ptr_next = wr_ptr_cur_next;
                end
            end
        end
    end
end

always @(posedge clk) begin
    wr_ptr_reg <= wr_ptr_next;
    wr_ptr_cur_reg <= wr_ptr_cur_next;

    seg_mem_wr_addr_reg <= seg_mem_wr_addr_next;

    if (rst) begin
        wr_ptr_reg <= 0;
        wr_ptr_cur_reg <= 0;

        seg_mem_wr_addr_reg <= 0;
    end
end

// Read logic
integer rd_seg;
reg [SEG_SEL_WIDTH-1:0] cur_rd_seg;
reg rd_valid;

always @* begin
    rd_ptr_next = rd_ptr_reg;
    rd_ptr_ctrl_next = rd_ptr_ctrl_reg;

    mem_rd_data_valid_next = mem_rd_data_valid_reg;
    ctrl_mem_rd_data_valid_next = ctrl_mem_rd_data_valid_reg;

    out_tlp_data_next = out_tlp_data_reg;
    out_tlp_strb_next = out_tlp_strb_reg;
    out_tlp_hdr_next = out_tlp_hdr_reg;
    out_tlp_seq_next = out_tlp_seq_reg;
    out_tlp_bar_id_next = out_tlp_bar_id_reg;
    out_tlp_func_num_next = out_tlp_func_num_reg;
    out_tlp_error_next = out_tlp_error_reg;
    out_tlp_valid_next = out_tlp_valid_reg;
    out_tlp_sop_next = out_tlp_sop_reg;
    out_tlp_eop_next = out_tlp_eop_reg;
    out_seg_offset_next = out_seg_offset_reg;
    out_seg_count_next = out_seg_count_reg;

    out_ctrl_tlp_strb_next = out_ctrl_tlp_strb_reg;
    out_ctrl_tlp_hdr_next = out_ctrl_tlp_hdr_reg;
    out_ctrl_tlp_valid_next = out_ctrl_tlp_valid_reg;
    out_ctrl_tlp_sop_next = out_ctrl_tlp_sop_reg;
    out_ctrl_tlp_eop_next = out_ctrl_tlp_eop_reg;
    out_ctrl_seg_offset_next = out_ctrl_seg_offset_reg;
    out_ctrl_seg_count_next = out_ctrl_seg_count_reg;
    out_ctrl_tlp_ready_int_next = out_ctrl_tlp_ready_int_reg;

    temp_out_ctrl_tlp_strb_next = temp_out_ctrl_tlp_strb_reg;
    temp_out_ctrl_tlp_hdr_next = temp_out_ctrl_tlp_hdr_reg;
    temp_out_ctrl_tlp_valid_next = temp_out_ctrl_tlp_valid_reg;
    temp_out_ctrl_tlp_sop_next = temp_out_ctrl_tlp_sop_reg;
    temp_out_ctrl_tlp_eop_next = temp_out_ctrl_tlp_eop_reg;

    pipe_out_ctrl_tlp_strb_next = pipe_out_ctrl_tlp_strb_reg;
    pipe_out_ctrl_tlp_hdr_next = pipe_out_ctrl_tlp_hdr_reg;
    pipe_out_ctrl_tlp_valid_next = pipe_out_ctrl_tlp_valid_reg;
    pipe_out_ctrl_tlp_sop_next = pipe_out_ctrl_tlp_sop_reg;
    pipe_out_ctrl_tlp_eop_next = pipe_out_ctrl_tlp_eop_reg;

    seg_mem_rd_addr_next = seg_mem_rd_addr_reg;
    seg_mem_rd_en = 0;
    seg_ctrl_mem_rd_addr_next = seg_ctrl_mem_rd_addr_reg;
    seg_ctrl_mem_rd_en = 0;

    if (OUT_TLP_SEG_COUNT == 1) begin
        if (!out_tlp_valid || out_read_en) begin
            out_tlp_data_next = seg_mem_rd_data;
            out_tlp_strb_next = seg_mem_rd_strb;
            out_tlp_hdr_next = seg_mem_rd_hdr;
            out_tlp_seq_next = seg_mem_rd_seq;
            out_tlp_bar_id_next = seg_mem_rd_bar_id;
            out_tlp_func_num_next = seg_mem_rd_func_num;
            out_tlp_error_next = seg_mem_rd_error;
            out_tlp_valid_next = mem_rd_data_valid_reg;
            out_tlp_sop_next = seg_mem_rd_sop;
            out_tlp_eop_next = seg_mem_rd_eop;
            out_seg_offset_next = 0;
            out_seg_count_next = 1;
        end

        if (!mem_rd_data_valid_reg || (!out_tlp_valid || out_read_en)) begin
            if (wr_ptr_reg != rd_ptr_reg) begin
                seg_mem_rd_en = 1'b1;
                mem_rd_data_valid_next = 1'b1;
                rd_ptr_next = rd_ptr_reg + 1;
                seg_mem_rd_addr_next = rd_ptr_next;
            end else begin
                mem_rd_data_valid_next = 1'b0;
            end
        end

        if (CTRL_OUT_EN) begin
            if (!out_ctrl_tlp_valid || out_ctrl_read_en) begin
                out_ctrl_tlp_strb_next = seg_ctrl_mem_rd_strb;
                out_ctrl_tlp_hdr_next = seg_ctrl_mem_rd_hdr;
                out_ctrl_tlp_valid_next = ctrl_mem_rd_data_valid_reg;
                out_ctrl_tlp_sop_next = seg_ctrl_mem_rd_sop;
                out_ctrl_tlp_eop_next = seg_ctrl_mem_rd_eop;
                out_ctrl_seg_offset_next = 0;
                out_ctrl_seg_count_next = 1;
            end

            if (!ctrl_mem_rd_data_valid_reg || (!out_ctrl_tlp_valid || out_ctrl_read_en)) begin
                if (wr_ptr_reg != rd_ptr_ctrl_reg) begin
                    seg_ctrl_mem_rd_en = 1'b1;
                    ctrl_mem_rd_data_valid_next = 1'b1;
                    rd_ptr_ctrl_next = rd_ptr_ctrl_reg + 1;
                    seg_ctrl_mem_rd_addr_next = rd_ptr_ctrl_next;
                end else begin
                    ctrl_mem_rd_data_valid_next = 1'b0;
                end
            end
        end
    end else begin
        // invalidate segments
        cur_rd_seg = out_seg_offset_reg;
        rd_valid = 1;
        if (out_read_en) begin
            for (rd_seg = 0; rd_seg < OUT_TLP_SEG_COUNT; rd_seg = rd_seg + 1) begin
                if (out_tlp_valid_reg[cur_rd_seg] && rd_seg < out_read_seg_count && rd_valid) begin
                    out_tlp_valid_next[cur_rd_seg] = 1'b0;
                    out_seg_offset_next = cur_rd_seg + 1;
                end else begin
                    rd_valid = 0;
                end
                cur_rd_seg = cur_rd_seg + 1;
            end
        end

        // register segments
        out_seg_count_next = 0;
        for (rd_seg = 0; rd_seg < OUT_TLP_SEG_COUNT; rd_seg = rd_seg + 1) begin
            if (!out_tlp_valid_next[rd_seg]) begin
                out_tlp_data_next[rd_seg*OUT_TLP_SEG_DATA_WIDTH +: OUT_TLP_SEG_DATA_WIDTH] = seg_mem_rd_data[rd_seg*OUT_TLP_SEG_DATA_WIDTH +: OUT_TLP_SEG_DATA_WIDTH];
                out_tlp_strb_next[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = seg_mem_rd_strb[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH];
                out_tlp_hdr_next[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = seg_mem_rd_hdr[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
                out_tlp_seq_next[rd_seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = seg_mem_rd_seq[rd_seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
                out_tlp_bar_id_next[rd_seg*3 +: 3] = seg_mem_rd_bar_id[rd_seg*3 +: 3];
                out_tlp_func_num_next[rd_seg*8 +: 8] = seg_mem_rd_func_num[rd_seg*8 +: 8];
                out_tlp_error_next[rd_seg*4 +: 4] = seg_mem_rd_error[rd_seg*4 +: 4];
                out_tlp_valid_next[rd_seg +: 1] = mem_rd_data_valid_reg[rd_seg +: 1];
                out_tlp_sop_next[rd_seg +: 1] = seg_mem_rd_sop[rd_seg +: 1];
                out_tlp_eop_next[rd_seg +: 1] = seg_mem_rd_eop[rd_seg +: 1];
                mem_rd_data_valid_next[rd_seg +: 1] = 1'b0;
            end

            if (out_tlp_valid_next[rd_seg]) begin
                out_seg_count_next = out_seg_count_next + 1;
            end
        end

        // read segments
        cur_rd_seg = rd_ptr_reg[SEG_SEL_WIDTH-1:0];
        rd_valid = 1;
        for (rd_seg = 0; rd_seg < OUT_TLP_SEG_COUNT; rd_seg = rd_seg + 1) begin
            if (!mem_rd_data_valid_next[cur_rd_seg] && count_reg > rd_seg && rd_valid) begin
                rd_ptr_next = rd_ptr_reg + rd_seg+1;
                seg_mem_rd_en[cur_rd_seg] = 1'b1;
                seg_mem_rd_addr_next[cur_rd_seg*ADDR_WIDTH +: ADDR_WIDTH] = ((rd_ptr_reg + rd_seg) >> SEG_SEL_WIDTH) + 1;
                mem_rd_data_valid_next[cur_rd_seg] = 1'b1;
            end else begin
                rd_valid = 0;
            end
            cur_rd_seg = cur_rd_seg + 1;
        end

        if (CTRL_OUT_EN) begin
            // invalidate segments
            cur_rd_seg = out_ctrl_seg_offset_reg;
            rd_valid = 1;
            if (out_ctrl_read_en) begin
                for (rd_seg = 0; rd_seg < OUT_TLP_SEG_COUNT; rd_seg = rd_seg + 1) begin
                    if (out_ctrl_tlp_valid_reg[cur_rd_seg] && rd_seg < out_ctrl_read_seg_count && rd_valid) begin
                        out_ctrl_tlp_valid_next[cur_rd_seg] = 1'b0;
                        out_ctrl_seg_offset_next = cur_rd_seg + 1;
                    end else begin
                        rd_valid = 0;
                    end
                    cur_rd_seg = cur_rd_seg + 1;
                end
            end

            // skid buffer
            out_ctrl_seg_count_next = 0;
            for (rd_seg = 0; rd_seg < OUT_TLP_SEG_COUNT; rd_seg = rd_seg + 1) begin
                out_ctrl_tlp_ready_int_next[rd_seg] = !out_ctrl_tlp_valid_next[rd_seg] || (!temp_out_ctrl_tlp_valid_reg[rd_seg] && (!out_ctrl_tlp_valid_reg[rd_seg] || !pipe_out_ctrl_tlp_valid_reg[rd_seg +: 1]));

                if (out_ctrl_tlp_ready_int_reg[rd_seg]) begin
                    if (!out_ctrl_tlp_valid_next[rd_seg] || !out_ctrl_tlp_valid_reg[rd_seg]) begin
                        if (pipe_out_ctrl_tlp_valid_reg[rd_seg +: 1]) begin
                            out_ctrl_tlp_strb_next[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = pipe_out_ctrl_tlp_strb_reg[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH];
                            out_ctrl_tlp_hdr_next[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = pipe_out_ctrl_tlp_hdr_reg[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
                            out_ctrl_tlp_valid_next[rd_seg +: 1] = pipe_out_ctrl_tlp_valid_reg[rd_seg +: 1];
                            out_ctrl_tlp_sop_next[rd_seg +: 1] = pipe_out_ctrl_tlp_sop_reg[rd_seg +: 1];
                            out_ctrl_tlp_eop_next[rd_seg +: 1] = pipe_out_ctrl_tlp_eop_reg[rd_seg +: 1];
                        end
                    end else begin
                        if (pipe_out_ctrl_tlp_valid_reg[rd_seg +: 1]) begin
                            temp_out_ctrl_tlp_strb_next[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = pipe_out_ctrl_tlp_strb_reg[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH];
                            temp_out_ctrl_tlp_hdr_next[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = pipe_out_ctrl_tlp_hdr_reg[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
                            temp_out_ctrl_tlp_valid_next[rd_seg +: 1] = pipe_out_ctrl_tlp_valid_reg[rd_seg +: 1];
                            temp_out_ctrl_tlp_sop_next[rd_seg +: 1] = pipe_out_ctrl_tlp_sop_reg[rd_seg +: 1];
                            temp_out_ctrl_tlp_eop_next[rd_seg +: 1] = pipe_out_ctrl_tlp_eop_reg[rd_seg +: 1];
                        end
                    end
                end else if (!out_ctrl_tlp_valid_next[rd_seg]) begin
                    if (temp_out_ctrl_tlp_valid_reg[rd_seg +: 1]) begin
                        out_ctrl_tlp_strb_next[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = temp_out_ctrl_tlp_strb_reg[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH];
                        out_ctrl_tlp_hdr_next[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = temp_out_ctrl_tlp_hdr_reg[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
                        out_ctrl_tlp_valid_next[rd_seg +: 1] = temp_out_ctrl_tlp_valid_reg[rd_seg +: 1];
                        out_ctrl_tlp_sop_next[rd_seg +: 1] = temp_out_ctrl_tlp_sop_reg[rd_seg +: 1];
                        out_ctrl_tlp_eop_next[rd_seg +: 1] = temp_out_ctrl_tlp_eop_reg[rd_seg +: 1];
                        temp_out_ctrl_tlp_valid_next[rd_seg +: 1] = 1'b0;
                    end
                end

                if (out_ctrl_tlp_valid_next[rd_seg]) begin
                    out_ctrl_seg_count_next = out_ctrl_seg_count_next + 1;
                end
            end

            // register segments (RAM output pipeline)
            for (rd_seg = 0; rd_seg < OUT_TLP_SEG_COUNT; rd_seg = rd_seg + 1) begin
                if (out_ctrl_tlp_ready_int_reg[rd_seg] || !pipe_out_ctrl_tlp_valid_reg[rd_seg +: 1]) begin
                    pipe_out_ctrl_tlp_strb_next[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = seg_ctrl_mem_rd_strb[rd_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH];
                    pipe_out_ctrl_tlp_hdr_next[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = seg_ctrl_mem_rd_hdr[rd_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
                    pipe_out_ctrl_tlp_valid_next[rd_seg +: 1] = ctrl_mem_rd_data_valid_reg[rd_seg +: 1];
                    pipe_out_ctrl_tlp_sop_next[rd_seg +: 1] = seg_ctrl_mem_rd_sop[rd_seg +: 1];
                    pipe_out_ctrl_tlp_eop_next[rd_seg +: 1] = seg_ctrl_mem_rd_eop[rd_seg +: 1];
                    ctrl_mem_rd_data_valid_next[rd_seg +: 1] = 1'b0;
                end
            end

            // read segments (RAM read)
            cur_rd_seg = rd_ptr_ctrl_reg[SEG_SEL_WIDTH-1:0];
            rd_valid = 1;
            for (rd_seg = 0; rd_seg < OUT_TLP_SEG_COUNT; rd_seg = rd_seg + 1) begin
                if (!ctrl_mem_rd_data_valid_next[cur_rd_seg] && count_ctrl_reg > rd_seg && rd_valid) begin
                    rd_ptr_ctrl_next = rd_ptr_ctrl_reg + rd_seg+1;
                    seg_ctrl_mem_rd_en[cur_rd_seg] = 1'b1;
                    seg_ctrl_mem_rd_addr_next[cur_rd_seg*ADDR_WIDTH +: ADDR_WIDTH] = ((rd_ptr_ctrl_reg + rd_seg) >> SEG_SEL_WIDTH) + 1;
                    ctrl_mem_rd_data_valid_next[cur_rd_seg] = 1'b1;
                end else begin
                    rd_valid = 0;
                end
                cur_rd_seg = cur_rd_seg + 1;
            end
        end
    end
end

always @(posedge clk) begin
    rd_ptr_reg <= rd_ptr_next;
    rd_ptr_ctrl_reg <= rd_ptr_ctrl_next;
    count_reg <= wr_ptr_next - rd_ptr_next;
    count_ctrl_reg <= wr_ptr_next - rd_ptr_ctrl_next;

    seg_mem_rd_addr_reg <= seg_mem_rd_addr_next;
    seg_ctrl_mem_rd_addr_reg <= seg_ctrl_mem_rd_addr_next;

    mem_rd_data_valid_reg <= mem_rd_data_valid_next;
    ctrl_mem_rd_data_valid_reg <= ctrl_mem_rd_data_valid_next;

    out_tlp_data_reg <= out_tlp_data_next;
    out_tlp_strb_reg <= out_tlp_strb_next;
    out_tlp_hdr_reg <= out_tlp_hdr_next;
    out_tlp_seq_reg <= out_tlp_seq_next;
    out_tlp_bar_id_reg <= out_tlp_bar_id_next;
    out_tlp_func_num_reg <= out_tlp_func_num_next;
    out_tlp_error_reg <= out_tlp_error_next;
    out_tlp_valid_reg <= out_tlp_valid_next;
    out_tlp_sop_reg <= out_tlp_sop_next;
    out_tlp_eop_reg <= out_tlp_eop_next;
    out_seg_offset_reg <= out_seg_offset_next;
    out_seg_count_reg <= out_seg_count_next;

    out_ctrl_tlp_strb_reg <= out_ctrl_tlp_strb_next;
    out_ctrl_tlp_hdr_reg <= out_ctrl_tlp_hdr_next;
    out_ctrl_tlp_valid_reg <= out_ctrl_tlp_valid_next;
    out_ctrl_tlp_sop_reg <= out_ctrl_tlp_sop_next;
    out_ctrl_tlp_eop_reg <= out_ctrl_tlp_eop_next;
    out_ctrl_seg_offset_reg <= out_ctrl_seg_offset_next;
    out_ctrl_seg_count_reg <= out_ctrl_seg_count_next;
    out_ctrl_tlp_ready_int_reg <= out_ctrl_tlp_ready_int_next;

    temp_out_ctrl_tlp_strb_reg <= temp_out_ctrl_tlp_strb_next;
    temp_out_ctrl_tlp_hdr_reg <= temp_out_ctrl_tlp_hdr_next;
    temp_out_ctrl_tlp_valid_reg <= temp_out_ctrl_tlp_valid_next;
    temp_out_ctrl_tlp_sop_reg <= temp_out_ctrl_tlp_sop_next;
    temp_out_ctrl_tlp_eop_reg <= temp_out_ctrl_tlp_eop_next;

    pipe_out_ctrl_tlp_strb_reg <= pipe_out_ctrl_tlp_strb_next;
    pipe_out_ctrl_tlp_hdr_reg <= pipe_out_ctrl_tlp_hdr_next;
    pipe_out_ctrl_tlp_valid_reg <= pipe_out_ctrl_tlp_valid_next;
    pipe_out_ctrl_tlp_sop_reg <= pipe_out_ctrl_tlp_sop_next;
    pipe_out_ctrl_tlp_eop_reg <= pipe_out_ctrl_tlp_eop_next;

    if (rst) begin
        rd_ptr_reg <= 0;
        rd_ptr_ctrl_reg <= 0;
        count_reg <= 0;
        count_ctrl_reg <= 0;

        seg_mem_rd_addr_reg <= 0;
        seg_ctrl_mem_rd_addr_reg <= 0;

        mem_rd_data_valid_reg <= 0;
        ctrl_mem_rd_data_valid_reg <= 0;

        out_tlp_valid_reg <= 0;
        out_seg_offset_reg <= 0;

        out_ctrl_tlp_valid_reg <= 0;
        out_ctrl_seg_offset_reg <= 0;
        out_ctrl_tlp_ready_int_reg <= 0;
        temp_out_ctrl_tlp_valid_reg <= 0;
        pipe_out_ctrl_tlp_valid_reg <= 0;
    end
end

endmodule

`resetall
