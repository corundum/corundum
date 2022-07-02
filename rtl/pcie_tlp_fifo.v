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
 * PCIe TLP FIFO
 */
module pcie_tlp_fifo #
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
    parameter OUT_TLP_SEG_COUNT = IN_TLP_SEG_COUNT,
    // Watermark level
    parameter WATERMARK = DEPTH/2
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
    input  wire                                        out_tlp_ready,

    /*
     * Status
     */
    output wire                                        half_full,
    output wire                                        watermark
);

parameter INT_TLP_SEG_COUNT = IN_TLP_SEG_COUNT > OUT_TLP_SEG_COUNT ? IN_TLP_SEG_COUNT : OUT_TLP_SEG_COUNT;

parameter IN_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / IN_TLP_SEG_COUNT;
parameter IN_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / IN_TLP_SEG_COUNT;

parameter INT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / INT_TLP_SEG_COUNT;
parameter INT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / INT_TLP_SEG_COUNT;

parameter OUT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / OUT_TLP_SEG_COUNT;
parameter OUT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / OUT_TLP_SEG_COUNT;

parameter SEG_RATIO = INT_TLP_SEG_COUNT / OUT_TLP_SEG_COUNT;
parameter SEG_SEL_WIDTH = $clog2(INT_TLP_SEG_COUNT);

parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

// check configuration
initial begin
    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end

    if (TLP_STRB_WIDTH*32 != TLP_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end
end

wire [TLP_DATA_WIDTH-1:0] fifo_tlp_data;
wire [TLP_STRB_WIDTH-1:0] fifo_tlp_strb;
wire [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] fifo_tlp_hdr;
wire [INT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] fifo_tlp_seq;
wire [INT_TLP_SEG_COUNT*3-1:0] fifo_tlp_bar_id;
wire [INT_TLP_SEG_COUNT*8-1:0] fifo_tlp_func_num;
wire [INT_TLP_SEG_COUNT*4-1:0] fifo_tlp_error;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_valid;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_sop;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_eop;
wire [SEG_SEL_WIDTH-1:0] fifo_seg_offset;
wire [SEG_SEL_WIDTH+1-1:0] fifo_seg_count;
wire fifo_read_en;
wire [SEG_SEL_WIDTH+1-1:0] fifo_read_seg_count;

wire [TLP_STRB_WIDTH-1:0] fifo_ctrl_tlp_strb;
wire [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_valid;
wire [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_sop;
wire [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_eop;
wire [SEG_SEL_WIDTH-1:0] fifo_ctrl_seg_offset;
wire [SEG_SEL_WIDTH+1-1:0] fifo_ctrl_seg_count;
wire fifo_ctrl_read_en;
wire [SEG_SEL_WIDTH+1-1:0] fifo_ctrl_read_seg_count;

pcie_tlp_fifo_raw #(
    .DEPTH(DEPTH),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(SEQ_NUM_WIDTH),
    .IN_TLP_SEG_COUNT(IN_TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .SEG_SEL_WIDTH(SEG_SEL_WIDTH),
    .WATERMARK(WATERMARK),
    .CTRL_OUT_EN(INT_TLP_SEG_COUNT != 1)
)
pcie_tlp_fifo_raw_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(in_tlp_data),
    .in_tlp_strb(in_tlp_strb),
    .in_tlp_hdr(in_tlp_hdr),
    .in_tlp_seq(in_tlp_seq),
    .in_tlp_bar_id(in_tlp_bar_id),
    .in_tlp_func_num(in_tlp_func_num),
    .in_tlp_error(in_tlp_error),
    .in_tlp_valid(in_tlp_valid),
    .in_tlp_sop(in_tlp_sop),
    .in_tlp_eop(in_tlp_eop),
    .in_tlp_ready(in_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(fifo_tlp_data),
    .out_tlp_strb(fifo_tlp_strb),
    .out_tlp_hdr(fifo_tlp_hdr),
    .out_tlp_seq(fifo_tlp_seq),
    .out_tlp_bar_id(fifo_tlp_bar_id),
    .out_tlp_func_num(fifo_tlp_func_num),
    .out_tlp_error(fifo_tlp_error),
    .out_tlp_valid(fifo_tlp_valid),
    .out_tlp_sop(fifo_tlp_sop),
    .out_tlp_eop(fifo_tlp_eop),
    .out_seg_offset(fifo_seg_offset),
    .out_seg_count(fifo_seg_count),
    .out_read_en(fifo_read_en),
    .out_read_seg_count(fifo_read_seg_count),

    .out_ctrl_tlp_strb(fifo_ctrl_tlp_strb),
    .out_ctrl_tlp_hdr(),
    .out_ctrl_tlp_valid(fifo_ctrl_tlp_valid),
    .out_ctrl_tlp_sop(fifo_ctrl_tlp_sop),
    .out_ctrl_tlp_eop(fifo_ctrl_tlp_eop),
    .out_ctrl_seg_offset(fifo_ctrl_seg_offset),
    .out_ctrl_seg_count(fifo_ctrl_seg_count),
    .out_ctrl_read_en(fifo_ctrl_read_en),
    .out_ctrl_read_seg_count(fifo_ctrl_read_seg_count),

    /*
     * Status
     */
    .half_full(half_full),
    .watermark(watermark)
);

generate

if (INT_TLP_SEG_COUNT == 1) begin

    assign fifo_read_en = out_tlp_ready;
    assign fifo_read_seg_count = 1;

    assign fifo_ctrl_read_en = 0;
    assign fifo_ctrl_read_seg_count = 0;

    assign out_tlp_data = fifo_tlp_data;
    assign out_tlp_strb = fifo_tlp_strb;
    assign out_tlp_hdr = fifo_tlp_hdr;
    assign out_tlp_seq = fifo_tlp_seq;
    assign out_tlp_bar_id = fifo_tlp_bar_id;
    assign out_tlp_func_num = fifo_tlp_func_num;
    assign out_tlp_error = fifo_tlp_error;
    assign out_tlp_valid = fifo_tlp_valid;
    assign out_tlp_sop = fifo_tlp_sop;
    assign out_tlp_eop = fifo_tlp_eop;

end else begin

    // internal datapath
    reg  [TLP_DATA_WIDTH-1:0]                   out_tlp_data_int;
    reg  [TLP_STRB_WIDTH-1:0]                   out_tlp_strb_int;
    reg  [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_tlp_hdr_int;
    reg  [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_tlp_seq_int;
    reg  [OUT_TLP_SEG_COUNT*3-1:0]              out_tlp_bar_id_int;
    reg  [OUT_TLP_SEG_COUNT*8-1:0]              out_tlp_func_num_int;
    reg  [OUT_TLP_SEG_COUNT*4-1:0]              out_tlp_error_int;
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_tlp_valid_int;
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_tlp_sop_int;
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_tlp_eop_int;
    wire                                        out_tlp_ready_int;

    reg [SEG_SEL_WIDTH+1-1:0] out_sel_data_seg_reg[0:INT_TLP_SEG_COUNT-1], out_sel_data_seg_next[0:INT_TLP_SEG_COUNT-1];
    reg [SEG_SEL_WIDTH+1-1:0] out_sel_seg_reg[0:OUT_TLP_SEG_COUNT-1], out_sel_seg_next[0:OUT_TLP_SEG_COUNT-1];

    reg fifo_read_en_reg = 0, fifo_read_en_next;
    reg [SEG_SEL_WIDTH+1-1:0] fifo_read_seg_count_reg = 0, fifo_read_seg_count_next;

    reg fifo_ctrl_read_en_cmb;
    reg [SEG_SEL_WIDTH+1-1:0] fifo_ctrl_read_seg_count_cmb;

    reg [TLP_STRB_WIDTH-1:0] tlp_strb_reg = 0, tlp_strb_next;
    reg [OUT_TLP_SEG_COUNT-1:0] tlp_valid_reg = 0, tlp_valid_next;
    reg [OUT_TLP_SEG_COUNT-1:0] tlp_sop_reg = 0, tlp_sop_next;
    reg [OUT_TLP_SEG_COUNT-1:0] tlp_eop_reg = 0, tlp_eop_next;

    assign fifo_read_en = fifo_read_en_reg;
    assign fifo_read_seg_count = fifo_read_seg_count_reg;

    assign fifo_ctrl_read_en = fifo_ctrl_read_en_cmb;
    assign fifo_ctrl_read_seg_count = fifo_ctrl_read_seg_count_cmb;

    // Read logic
    integer seg, out_seg;
    reg out_valid, seg_valid;
    reg [SEG_SEL_WIDTH+1-1:0] seg_count;
    reg [SEG_SEL_WIDTH-1:0] cur_seg;

    always @* begin
        fifo_read_seg_count_next = 0;
        fifo_read_en_next = 1'b0;

        fifo_ctrl_read_seg_count_cmb = 0;
        fifo_ctrl_read_en_cmb = 1'b0;

        out_tlp_data_int = 0;
        out_tlp_strb_int = 0;
        out_tlp_hdr_int = 0;
        out_tlp_seq_int = 0;
        out_tlp_bar_id_int = 0;
        out_tlp_func_num_int = 0;
        out_tlp_error_int = 0;
        out_tlp_valid_int = 0;
        out_tlp_sop_int = 0;
        out_tlp_eop_int = 0;

        tlp_strb_next = 0;
        tlp_valid_next = 0;
        tlp_sop_next = 0;
        tlp_eop_next = 0;

        for (out_seg = 0; out_seg < OUT_TLP_SEG_COUNT; out_seg = out_seg + 1) begin
            out_sel_seg_next[out_seg] = 0;
        end

        for (out_seg = 0; out_seg < INT_TLP_SEG_COUNT; out_seg = out_seg + 1) begin
            out_sel_data_seg_next[out_seg] = 0;
        end

        // pack segments
        if (out_tlp_ready_int) begin
            cur_seg = fifo_ctrl_seg_offset;
            fifo_ctrl_read_seg_count_cmb = 0;
            fifo_read_seg_count_next = 0;
            out_valid = 1;
            for (out_seg = 0; out_seg < OUT_TLP_SEG_COUNT; out_seg = out_seg + 1) begin
                if (fifo_ctrl_tlp_valid[cur_seg +: 1] && out_valid) begin
                    out_sel_seg_next[out_seg] = cur_seg;
                    tlp_strb_next[out_seg*OUT_TLP_SEG_STRB_WIDTH +: OUT_TLP_SEG_STRB_WIDTH] = fifo_ctrl_tlp_strb[cur_seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH];
                    tlp_valid_next[out_seg +: 1] = fifo_ctrl_tlp_valid[cur_seg +: 1];
                    tlp_sop_next[out_seg +: 1] = fifo_ctrl_tlp_sop[cur_seg +: 1];
                    tlp_eop_next[out_seg +: 1] = fifo_ctrl_tlp_eop[cur_seg +: 1];
                    seg_valid = 1;
                    for (seg = 0; seg < SEG_RATIO; seg = seg + 1) begin
                        if (fifo_ctrl_tlp_valid[cur_seg +: 1] && seg_valid) begin
                            out_sel_data_seg_next[out_seg*SEG_RATIO+seg] = cur_seg;
                            tlp_strb_next[out_seg*OUT_TLP_SEG_STRB_WIDTH+seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = fifo_ctrl_tlp_strb[cur_seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH];
                            tlp_eop_next[out_seg +: 1] = fifo_ctrl_tlp_eop[cur_seg +: 1];
                            fifo_ctrl_read_seg_count_cmb = fifo_ctrl_read_seg_count_cmb + 1;
                            fifo_read_seg_count_next = fifo_read_seg_count_next + 1;
                            fifo_ctrl_read_en_cmb = 1'b1;
                            fifo_read_en_next = 1'b1;
                            if (fifo_ctrl_tlp_eop[cur_seg +: 1]) begin
                                seg_valid = 0;
                            end
                            cur_seg = cur_seg + 1;
                        end else begin
                            seg_valid = 0;
                        end
                    end
                end else begin
                    out_valid = 0;
                end
            end
        end

        // mux
        for (out_seg = 0; out_seg < OUT_TLP_SEG_COUNT; out_seg = out_seg + 1) begin
            out_tlp_hdr_int[out_seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = fifo_tlp_hdr[out_sel_seg_reg[out_seg]*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
            out_tlp_seq_int[out_seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = fifo_tlp_seq[out_sel_seg_reg[out_seg]*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
            out_tlp_bar_id_int[out_seg*3 +: 3] = fifo_tlp_bar_id[out_sel_seg_reg[out_seg]*3 +: 3];
            out_tlp_func_num_int[out_seg*8 +: 8] = fifo_tlp_func_num[out_sel_seg_reg[out_seg]*8 +: 8];
            out_tlp_error_int[out_seg*4 +: 4] = fifo_tlp_error[out_sel_seg_reg[out_seg]*4 +: 4];
        end

        for (out_seg = 0; out_seg < INT_TLP_SEG_COUNT; out_seg = out_seg + 1) begin
            out_tlp_data_int[out_seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = fifo_tlp_data[out_sel_data_seg_reg[out_seg]*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH];
        end

        out_tlp_strb_int = tlp_strb_reg;
        out_tlp_valid_int = tlp_valid_reg;
        out_tlp_sop_int = tlp_sop_reg;
        out_tlp_eop_int = tlp_eop_reg;
    end

    integer i;

    always @(posedge clk) begin
        fifo_read_seg_count_reg <= fifo_read_seg_count_next;
        fifo_read_en_reg <= fifo_read_en_next;

        tlp_strb_reg <= tlp_strb_next;
        tlp_valid_reg <= tlp_valid_next;
        tlp_sop_reg <= tlp_sop_next;
        tlp_eop_reg <= tlp_eop_next;

        for (i = 0; i < OUT_TLP_SEG_COUNT; i = i + 1) begin
            out_sel_seg_reg[i] <= out_sel_seg_next[i];
        end

        for (i = 0; i < INT_TLP_SEG_COUNT; i = i + 1) begin
            out_sel_data_seg_reg[i] <= out_sel_data_seg_next[i];
        end

        if (rst) begin
            fifo_read_en_reg <= 0;

            tlp_valid_reg <= 0;
        end
    end

    // output datapath logic
    reg  [TLP_DATA_WIDTH-1:0]                   out_tlp_data_reg = 0;
    reg  [TLP_STRB_WIDTH-1:0]                   out_tlp_strb_reg = 0;
    reg  [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_tlp_hdr_reg = 0;
    reg  [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_tlp_seq_reg = 0;
    reg  [OUT_TLP_SEG_COUNT*3-1:0]              out_tlp_bar_id_reg = 0;
    reg  [OUT_TLP_SEG_COUNT*8-1:0]              out_tlp_func_num_reg = 0;
    reg  [OUT_TLP_SEG_COUNT*4-1:0]              out_tlp_error_reg = 0;
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_tlp_valid_reg = 0;
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_tlp_sop_reg = 0;
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_tlp_eop_reg = 0;

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
    reg out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ramstyle = "no_rw_check, mlab" *)
    reg  [TLP_DATA_WIDTH-1:0]                   out_fifo_out_tlp_data[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [TLP_STRB_WIDTH-1:0]                   out_fifo_out_tlp_strb[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_fifo_out_tlp_hdr[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_fifo_out_tlp_seq[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT*3-1:0]              out_fifo_out_tlp_bar_id[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT*8-1:0]              out_fifo_out_tlp_func_num[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT*4-1:0]              out_fifo_out_tlp_error[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_fifo_out_tlp_valid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_fifo_out_tlp_sop[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ramstyle = "no_rw_check, mlab" *)
    reg  [OUT_TLP_SEG_COUNT-1:0]                out_fifo_out_tlp_eop[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

    assign out_tlp_ready_int = !out_fifo_half_full_reg;

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

    always @(posedge clk) begin
        out_tlp_valid_reg <= out_tlp_ready ? 0 : out_tlp_valid_reg;

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

        if (!out_fifo_full && out_tlp_valid_int) begin
            out_fifo_out_tlp_data[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_data_int;
            out_fifo_out_tlp_strb[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_strb_int;
            out_fifo_out_tlp_hdr[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_hdr_int;
            out_fifo_out_tlp_seq[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_seq_int;
            out_fifo_out_tlp_bar_id[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_bar_id_int;
            out_fifo_out_tlp_func_num[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_func_num_int;
            out_fifo_out_tlp_error[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_error_int;
            out_fifo_out_tlp_valid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_valid_int;
            out_fifo_out_tlp_sop[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_sop_int;
            out_fifo_out_tlp_eop[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= out_tlp_eop_int;
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!out_tlp_valid_reg || out_tlp_ready)) begin
            out_tlp_data_reg <= out_fifo_out_tlp_data[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_tlp_strb_reg <= out_fifo_out_tlp_strb[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_tlp_hdr_reg <= out_fifo_out_tlp_hdr[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_tlp_seq_reg <= out_fifo_out_tlp_seq[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_tlp_bar_id_reg <= out_fifo_out_tlp_bar_id[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_tlp_func_num_reg <= out_fifo_out_tlp_func_num[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_tlp_error_reg <= out_fifo_out_tlp_error[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            if (OUT_TLP_SEG_COUNT == 1) begin
                out_tlp_valid_reg <= 1'b1;
            end else begin
                out_tlp_valid_reg <= out_fifo_out_tlp_valid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            end
            out_tlp_sop_reg <= out_fifo_out_tlp_sop[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_tlp_eop_reg <= out_fifo_out_tlp_eop[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (rst) begin
            out_fifo_wr_ptr_reg <= 0;
            out_fifo_rd_ptr_reg <= 0;
            out_tlp_valid_reg <= 1'b0;
        end
    end

end

endgenerate

endmodule

`resetall
