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
 * AXI4 virtual FIFO (decoder)
 */
module axi_vfifo_dec #
(
    // Width of input segment
    parameter SEG_WIDTH = 32,
    // Segment count
    parameter SEG_CNT = 2,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = SEG_WIDTH*SEG_CNT/2,
    // Use AXI stream tkeep signal
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8),
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    // Use AXI stream tlast signal
    parameter AXIS_LAST_ENABLE = 1,
    // Propagate AXI stream tid signal
    parameter AXIS_ID_ENABLE = 0,
    // AXI stream tid signal width
    parameter AXIS_ID_WIDTH = 8,
    // Propagate AXI stream tdest signal
    parameter AXIS_DEST_ENABLE = 0,
    // AXI stream tdest signal width
    parameter AXIS_DEST_WIDTH = 8,
    // Propagate AXI stream tuser signal
    parameter AXIS_USER_ENABLE = 1,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Segmented data input (from virtual FIFO channel)
     */
    input  wire                          fifo_rst_in,
    input  wire [SEG_CNT*SEG_WIDTH-1:0]  input_data,
    input  wire [SEG_CNT-1:0]            input_valid,
    output wire [SEG_CNT-1:0]            input_ready,
    input  wire [SEG_CNT*SEG_WIDTH-1:0]  input_ctrl_data,
    input  wire [SEG_CNT-1:0]            input_ctrl_valid,
    output wire [SEG_CNT-1:0]            input_ctrl_ready,

    /*
     * AXI stream data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]    m_axis_tkeep,
    output wire                          m_axis_tvalid,
    input  wire                          m_axis_tready,
    output wire                          m_axis_tlast,
    output wire [AXIS_ID_WIDTH-1:0]      m_axis_tid,
    output wire [AXIS_DEST_WIDTH-1:0]    m_axis_tdest,
    output wire [AXIS_USER_WIDTH-1:0]    m_axis_tuser,

    /*
     * Status
     */
    output wire                          sts_hdr_parity_err
);

parameter AXIS_KEEP_WIDTH_INT = AXIS_KEEP_ENABLE ? AXIS_KEEP_WIDTH : 1;
parameter AXIS_BYTE_LANES = AXIS_KEEP_WIDTH_INT;
parameter AXIS_BYTE_SIZE = AXIS_DATA_WIDTH/AXIS_BYTE_LANES;
parameter AXIS_BYTE_IDX_WIDTH = $clog2(AXIS_BYTE_LANES);

parameter BYTE_SIZE = AXIS_BYTE_SIZE;

parameter SEG_BYTE_LANES = SEG_WIDTH / BYTE_SIZE;

parameter EXPAND_INPUT = SEG_CNT < 2;

parameter SEG_CNT_INT = EXPAND_INPUT ? SEG_CNT*2 : SEG_CNT;

parameter SEG_IDX_WIDTH = $clog2(SEG_CNT_INT);
parameter SEG_BYTE_IDX_WIDTH = $clog2(SEG_BYTE_LANES);

parameter AXIS_SEG_CNT = (AXIS_DATA_WIDTH + SEG_WIDTH-1) / SEG_WIDTH;
parameter AXIS_SEG_IDX_WIDTH = AXIS_SEG_CNT > 1 ? $clog2(AXIS_SEG_CNT) : 1;
parameter AXIS_LEN_MASK = AXIS_BYTE_LANES-1;

parameter OUT_OFFS_WIDTH = AXIS_SEG_IDX_WIDTH;

parameter META_ID_OFFSET = 0;
parameter META_DEST_OFFSET = META_ID_OFFSET + (AXIS_ID_ENABLE ? AXIS_ID_WIDTH : 0);
parameter META_USER_OFFSET = META_DEST_OFFSET + (AXIS_DEST_ENABLE ? AXIS_DEST_WIDTH : 0);
parameter META_WIDTH = META_USER_OFFSET + (AXIS_USER_ENABLE ? AXIS_USER_WIDTH : 0);
parameter HDR_SIZE = (16 + META_WIDTH + BYTE_SIZE-1) / BYTE_SIZE;
parameter HDR_WIDTH = HDR_SIZE * BYTE_SIZE;

parameter HDR_LEN_WIDTH = 12;
parameter HDR_SEG_LEN_WIDTH = HDR_LEN_WIDTH-SEG_BYTE_IDX_WIDTH;

parameter CTRL_FIFO_ADDR_WIDTH = 5;
parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

parameter CTRL_FIFO_PTR_WIDTH = CTRL_FIFO_ADDR_WIDTH + SEG_IDX_WIDTH;

// validate parameters
initial begin
    if (AXIS_BYTE_SIZE * AXIS_KEEP_WIDTH_INT != AXIS_DATA_WIDTH) begin
        $error("Error: AXI stream data width not evenly divisible (instance %m)");
        $finish;
    end

    if (AXIS_SEG_CNT * SEG_WIDTH != AXIS_DATA_WIDTH) begin
        $error("Error: AXI stream data width not evenly divisible into segments (instance %m)");
        $finish;
    end

    if (SEG_WIDTH < HDR_WIDTH) begin
        $error("Error: Segment smaller than header (instance %m)");
        $finish;
    end
end

reg frame_reg = 1'b0, frame_next, frame_cyc;
reg last_reg = 1'b0, last_next, last_cyc;
reg extra_cycle_reg = 1'b0, extra_cycle_next, extra_cycle_cyc;
reg last_straddle_reg = 1'b0, last_straddle_next, last_straddle_cyc;
reg [HDR_SEG_LEN_WIDTH-1:0] seg_cnt_reg = 0, seg_cnt_next, seg_cnt_cyc;
reg hdr_parity_err_reg = 1'b0, hdr_parity_err_next, hdr_parity_err_cyc;

reg out_frame_reg = 1'b0, out_frame_next, out_frame_cyc;
reg [SEG_IDX_WIDTH-1:0] out_seg_offset_reg = 0, out_seg_offset_next, out_seg_offset_cyc;
reg [OUT_OFFS_WIDTH-1:0] output_offset_reg = 0, output_offset_next, output_offset_cyc;
reg [SEG_CNT_INT-1:0] out_seg_consumed;
reg [SEG_CNT_INT-1:0] out_seg_consumed_reg = 0, out_seg_consumed_next;
reg out_valid, out_valid_straddle, out_frame, out_last, out_abort, out_done;

reg [SEG_CNT_INT-1:0] seg_valid;
reg [SEG_CNT_INT-1:0] seg_valid_straddle;
reg [SEG_CNT_INT-1:0] seg_hdr_start_pkt;
reg [SEG_CNT_INT-1:0] seg_hdr_last;
reg [SEG_CNT_INT-1:0] seg_hdr_last_straddle;
reg [SEG_CNT_INT-1:0] seg_hdr_parity_err;
reg [HDR_LEN_WIDTH-1:0] seg_hdr_len[SEG_CNT_INT-1:0];
reg [HDR_SEG_LEN_WIDTH-1:0] seg_hdr_seg_cnt[SEG_CNT_INT-1:0];

reg [SEG_CNT_INT-1:0] shift_out_seg_valid;
reg [SEG_CNT_INT-1:0] shift_out_seg_valid_straddle;
reg [SEG_CNT_INT-1:0] shift_out_seg_sop;
reg [SEG_CNT_INT-1:0] shift_out_seg_eop;
reg [SEG_CNT_INT-1:0] shift_out_seg_end;
reg [SEG_CNT_INT-1:0] shift_out_seg_last;

reg [SEG_CNT-1:0] input_ready_cmb;
reg [SEG_CNT-1:0] input_ctrl_ready_cmb;

reg [SEG_CNT*SEG_WIDTH-1:0] input_data_int_reg = 0, input_data_int_next;
reg [SEG_CNT-1:0] input_valid_int_reg = 0, input_valid_int_next;

wire [SEG_CNT_INT*SEG_WIDTH*2-1:0] input_data_full = EXPAND_INPUT ? {2{{input_data, input_data_int_reg}}} : {2{input_data}};
wire [SEG_CNT_INT-1:0] input_valid_full = EXPAND_INPUT ? {input_valid, input_valid_int_reg} : input_valid;

reg out_ctrl_en_reg = 0, out_ctrl_en_next;
reg out_ctrl_hdr_reg = 0, out_ctrl_hdr_next;
reg out_ctrl_last_reg = 0, out_ctrl_last_next;
reg [AXIS_BYTE_IDX_WIDTH-1:0] out_ctrl_last_len_reg = 0, out_ctrl_last_len_next;
reg [SEG_IDX_WIDTH-1:0] out_ctrl_seg_offset_reg = 0, out_ctrl_seg_offset_next;

reg [AXIS_ID_WIDTH-1:0] axis_tid_reg = 0, axis_tid_next;
reg [AXIS_DEST_WIDTH-1:0] axis_tdest_reg = 0, axis_tdest_next;
reg [AXIS_USER_WIDTH-1:0] axis_tuser_reg = 0, axis_tuser_next;

// internal datapath
reg  [AXIS_DATA_WIDTH-1:0] m_axis_tdata_int;
reg  [AXIS_KEEP_WIDTH-1:0] m_axis_tkeep_int;
reg                        m_axis_tvalid_int;
wire                       m_axis_tready_int;
reg                        m_axis_tlast_int;
reg  [AXIS_ID_WIDTH-1:0]   m_axis_tid_int;
reg  [AXIS_DEST_WIDTH-1:0] m_axis_tdest_int;
reg  [AXIS_USER_WIDTH-1:0] m_axis_tuser_int;

assign input_ready = input_ready_cmb;
assign input_ctrl_ready = input_ctrl_ready_cmb;

assign sts_hdr_parity_err = hdr_parity_err_reg;

// segmented control FIFO
reg [CTRL_FIFO_PTR_WIDTH+1-1:0] ctrl_fifo_wr_ptr_reg = 0, ctrl_fifo_wr_ptr_next;
reg [CTRL_FIFO_PTR_WIDTH+1-1:0] ctrl_fifo_rd_ptr_reg = 0, ctrl_fifo_rd_ptr_next;

reg [SEG_CNT-1:0] ctrl_mem_rd_data_valid_reg = 0, ctrl_mem_rd_data_valid_next;

reg [SEG_CNT-1:0] ctrl_fifo_wr_sop;
reg [SEG_CNT-1:0] ctrl_fifo_wr_eop;
reg [SEG_CNT-1:0] ctrl_fifo_wr_end;
reg [SEG_CNT-1:0] ctrl_fifo_wr_last;
reg [SEG_CNT*AXIS_BYTE_IDX_WIDTH-1:0] ctrl_fifo_wr_last_len;
reg [SEG_CNT-1:0] ctrl_fifo_wr_en;

wire [SEG_CNT-1:0] ctrl_fifo_rd_sop;
wire [SEG_CNT-1:0] ctrl_fifo_rd_eop;
wire [SEG_CNT-1:0] ctrl_fifo_rd_end;
wire [SEG_CNT-1:0] ctrl_fifo_rd_last;
wire [SEG_CNT*AXIS_BYTE_IDX_WIDTH-1:0] ctrl_fifo_rd_last_len;
wire [SEG_CNT-1:0] ctrl_fifo_rd_valid;
reg [SEG_CNT-1:0] ctrl_fifo_rd_en;

wire [SEG_CNT-1:0] ctrl_fifo_seg_full;
wire [SEG_CNT-1:0] ctrl_fifo_seg_half_full;
wire [SEG_CNT-1:0] ctrl_fifo_seg_empty;

wire ctrl_fifo_full = |ctrl_fifo_seg_full;
wire ctrl_fifo_half_full = |ctrl_fifo_seg_half_full;
wire ctrl_fifo_empty = |ctrl_fifo_seg_empty;

generate

genvar n;

for (n = 0; n < SEG_CNT; n = n + 1) begin : ctrl_fifo_seg

    reg [CTRL_FIFO_ADDR_WIDTH+1-1:0] seg_wr_ptr_reg = 0;
    reg [CTRL_FIFO_ADDR_WIDTH+1-1:0] seg_rd_ptr_reg = 0;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg seg_mem_sop[2**CTRL_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg seg_mem_eop[2**CTRL_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg seg_mem_end[2**CTRL_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg seg_mem_last[2**CTRL_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [AXIS_BYTE_IDX_WIDTH-1:0] seg_mem_last_len[2**CTRL_FIFO_ADDR_WIDTH-1:0];

    reg seg_rd_sop_reg = 0;
    reg seg_rd_eop_reg = 0;
    reg seg_rd_end_reg = 0;
    reg seg_rd_last_reg = 0;
    reg [AXIS_BYTE_IDX_WIDTH-1:0] seg_rd_last_len_reg = 0;
    reg seg_rd_valid_reg = 0;

    reg seg_half_full_reg = 1'b0;

    assign ctrl_fifo_rd_sop[n] = seg_rd_sop_reg;
    assign ctrl_fifo_rd_eop[n] = seg_rd_eop_reg;
    assign ctrl_fifo_rd_end[n] = seg_rd_end_reg;
    assign ctrl_fifo_rd_last[n] = seg_rd_last_reg;
    assign ctrl_fifo_rd_last_len[AXIS_BYTE_IDX_WIDTH*n +: AXIS_BYTE_IDX_WIDTH] = seg_rd_last_len_reg;
    assign ctrl_fifo_rd_valid[n] = seg_rd_valid_reg;

    wire seg_full = seg_wr_ptr_reg == (seg_rd_ptr_reg ^ {1'b1, {CTRL_FIFO_ADDR_WIDTH{1'b0}}});
    wire seg_empty = seg_wr_ptr_reg == seg_rd_ptr_reg;

    assign ctrl_fifo_seg_full[n] = seg_full;
    assign ctrl_fifo_seg_half_full[n] = seg_half_full_reg;
    assign ctrl_fifo_seg_empty[n] = seg_empty;

    always @(posedge clk) begin
        seg_rd_valid_reg <= seg_rd_valid_reg && !ctrl_fifo_rd_en[n];

        seg_half_full_reg <= $unsigned(seg_wr_ptr_reg - seg_rd_ptr_reg) >= 2**(CTRL_FIFO_ADDR_WIDTH-1);

        if (ctrl_fifo_wr_en[n]) begin
            seg_mem_sop[seg_wr_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]] <= ctrl_fifo_wr_sop[n];
            seg_mem_eop[seg_wr_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]] <= ctrl_fifo_wr_eop[n];
            seg_mem_end[seg_wr_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]] <= ctrl_fifo_wr_end[n];
            seg_mem_last[seg_wr_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]] <= ctrl_fifo_wr_last[n];
            seg_mem_last_len[seg_wr_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]] <= ctrl_fifo_wr_last_len[AXIS_BYTE_IDX_WIDTH*n +: AXIS_BYTE_IDX_WIDTH];

            seg_wr_ptr_reg <= seg_wr_ptr_reg + 1;
        end

        if (!seg_empty && (!seg_rd_valid_reg || ctrl_fifo_rd_en[n])) begin
            seg_rd_sop_reg <= seg_mem_sop[seg_rd_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]];
            seg_rd_eop_reg <= seg_mem_eop[seg_rd_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]];
            seg_rd_end_reg <= seg_mem_end[seg_rd_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]];
            seg_rd_last_reg <= seg_mem_last[seg_rd_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]];
            seg_rd_last_len_reg <= seg_mem_last_len[seg_rd_ptr_reg[CTRL_FIFO_ADDR_WIDTH-1:0]];
            seg_rd_valid_reg <= 1'b1;

            seg_rd_ptr_reg <= seg_rd_ptr_reg + 1;
        end

        if (rst || fifo_rst_in) begin
            seg_wr_ptr_reg <= 0;
            seg_rd_ptr_reg <= 0;
            seg_rd_valid_reg <= 1'b0;
        end
    end

end

endgenerate

// parse segment headers
integer seg;

always @* begin
    input_ctrl_ready_cmb = 0;

    frame_next = frame_reg;
    frame_cyc = frame_reg;
    last_next = last_reg;
    last_cyc = last_reg;
    extra_cycle_next = extra_cycle_reg;
    extra_cycle_cyc = extra_cycle_reg;
    last_straddle_next = last_straddle_reg;
    last_straddle_cyc = last_straddle_reg;
    seg_cnt_next = seg_cnt_reg;
    seg_cnt_cyc = seg_cnt_reg;
    hdr_parity_err_next = 1'b0;
    hdr_parity_err_cyc = 1'b0;

    ctrl_fifo_wr_sop = 0;
    ctrl_fifo_wr_eop = 0;
    ctrl_fifo_wr_end = 0;
    ctrl_fifo_wr_last = 0;
    ctrl_fifo_wr_last_len = 0;
    ctrl_fifo_wr_en = 0;

    // decode segment headers
    for (seg = 0; seg < SEG_CNT; seg = seg + 1) begin
        seg_valid[seg] = input_ctrl_valid[seg];
        seg_hdr_start_pkt[seg] = input_ctrl_data[SEG_WIDTH*seg + 0 +: 1];
        seg_hdr_last[seg] = input_ctrl_data[SEG_WIDTH*seg + 1 +: 1];
        seg_hdr_len[seg] = input_ctrl_data[SEG_WIDTH*seg + 4 +: 12];
        seg_hdr_seg_cnt[seg] = (seg_hdr_len[seg] + SEG_BYTE_LANES) >> SEG_BYTE_IDX_WIDTH;
        seg_hdr_last_straddle[seg] = ((seg_hdr_len[seg] & (SEG_BYTE_LANES-1)) + HDR_SIZE) >> SEG_BYTE_IDX_WIDTH != 0;
        seg_hdr_parity_err[seg] = ^input_ctrl_data[SEG_WIDTH*seg + 0 +: 3] || ^input_ctrl_data[SEG_WIDTH*seg + 3 +: 13];
    end
    seg_valid_straddle = {2{seg_valid}} >> 1;

    for (seg = 0; seg < SEG_CNT; seg = seg + 1) begin
        if (!frame_cyc) begin
            if (seg_valid[seg]) begin
                if (seg_hdr_start_pkt[seg]) begin
                    // start of frame
                    last_cyc = seg_hdr_last[seg];
                    extra_cycle_cyc = 1'b0;
                    last_straddle_cyc = seg_hdr_last_straddle[seg];
                    seg_cnt_cyc = seg_hdr_seg_cnt[seg];

                    ctrl_fifo_wr_sop[seg] = 1'b1;
                    ctrl_fifo_wr_last_len[AXIS_BYTE_IDX_WIDTH*seg +: AXIS_BYTE_IDX_WIDTH] = seg_hdr_len[seg];

                    frame_cyc = 1'b1;
                end else  begin
                    // consume null segment
                end

                if (seg_hdr_parity_err[seg]) begin
                    hdr_parity_err_cyc = 1'b1;
                end
            end
        end

        if (frame_cyc) begin
            if (extra_cycle_cyc) begin
                // extra cycle
                frame_cyc = 0;
                extra_cycle_cyc = 0;

                ctrl_fifo_wr_eop[seg] = 1'b1;
            end else if (seg_cnt_cyc == 1) begin
                // last output cycle
                if (last_cyc) begin
                    ctrl_fifo_wr_last[seg] = 1'b1;
                end

                if (last_straddle_cyc) begin
                    // last output cycle, with segment straddle
                    extra_cycle_cyc = 1'b1;

                    ctrl_fifo_wr_end[seg] = 1'b1;
                end else begin
                    // last output cycle, no segment straddle
                    frame_cyc = 0;

                    ctrl_fifo_wr_eop[seg] = 1'b1;
                    ctrl_fifo_wr_end[seg] = 1'b1;
                end
            end else begin
                // middle cycle
            end
        end

        seg_cnt_cyc = seg_cnt_cyc - 1;
    end

    if (&seg_valid && !ctrl_fifo_half_full) begin
        input_ctrl_ready_cmb = {SEG_CNT{1'b1}};

        ctrl_fifo_wr_en = {SEG_CNT{1'b1}};

        frame_next = frame_cyc;
        last_next = last_cyc;
        extra_cycle_next = extra_cycle_cyc;
        last_straddle_next = last_straddle_cyc;
        seg_cnt_next = seg_cnt_cyc;
        hdr_parity_err_next = hdr_parity_err_cyc;
    end
end

// re-pack data
integer out_seg;
reg [SEG_IDX_WIDTH-1:0] out_cur_seg;

always @* begin
    input_ready_cmb = 0;

    out_frame_next = out_frame_reg;
    out_frame_cyc = out_frame_reg;
    out_seg_offset_next = out_seg_offset_reg;
    out_seg_offset_cyc = out_seg_offset_reg;
    output_offset_next = output_offset_reg;
    // output_offset_cyc = output_offset_reg;
    output_offset_cyc = 0;
    out_seg_consumed_next = 0;


    out_ctrl_en_next = 0;
    out_ctrl_hdr_next = 0;
    out_ctrl_last_next = 0;
    out_ctrl_last_len_next = out_ctrl_last_len_reg;
    out_ctrl_seg_offset_next = out_ctrl_seg_offset_reg;

    axis_tid_next = axis_tid_reg;
    axis_tdest_next = axis_tdest_reg;
    axis_tuser_next = axis_tuser_reg;

    input_data_int_next = input_data_int_reg;
    input_valid_int_next = input_valid_int_reg;

    ctrl_fifo_rd_en = 0;

    // apply segment offset
    shift_out_seg_valid = {2{ctrl_fifo_rd_valid}} >> out_seg_offset_reg;
    shift_out_seg_valid_straddle = {2{ctrl_fifo_rd_valid}} >> (out_seg_offset_reg+1);
    shift_out_seg_valid_straddle[SEG_CNT-1] = 1'b0; // wrapped, so cannot be consumed
    shift_out_seg_sop = {2{ctrl_fifo_rd_sop}} >> out_seg_offset_reg;
    shift_out_seg_eop = {2{ctrl_fifo_rd_eop}} >> out_seg_offset_reg;
    shift_out_seg_end = {2{ctrl_fifo_rd_end}} >> out_seg_offset_reg;
    shift_out_seg_last = {2{ctrl_fifo_rd_last}} >> out_seg_offset_reg;

    // extract data
    out_valid = 0;
    out_valid_straddle = 0;
    out_frame = out_frame_cyc;
    out_abort = 0;
    out_done = 0;
    out_seg_consumed = 0;

    out_ctrl_seg_offset_next = out_seg_offset_reg;

    out_cur_seg = out_seg_offset_reg;
    for (out_seg = 0; out_seg < SEG_CNT; out_seg = out_seg + 1) begin
        out_seg_offset_cyc = out_seg_offset_cyc + 1;

        // check for contiguous valid segments
        out_valid = (~shift_out_seg_valid & ({SEG_CNT{1'b1}} >> (SEG_CNT-1 - out_seg))) == 0;
        out_valid_straddle = shift_out_seg_valid_straddle[0];

        if (!out_frame_cyc) begin
            if (out_valid) begin
                if (shift_out_seg_sop[0]) begin
                    // start of frame
                    out_frame_cyc = 1'b1;

                    if (!out_done) begin
                        out_ctrl_hdr_next = 1'b1;
                        out_ctrl_last_len_next = ctrl_fifo_rd_last_len[AXIS_BYTE_IDX_WIDTH*out_cur_seg +: AXIS_BYTE_IDX_WIDTH];
                        out_ctrl_seg_offset_next = out_cur_seg;
                    end
                end else if (!out_abort) begin
                    // consume null segment
                    out_seg_consumed[out_cur_seg] = 1'b1;
                    out_seg_consumed_next = out_seg_consumed;
                    ctrl_fifo_rd_en = out_seg_consumed;

                    out_seg_offset_next = out_seg_offset_cyc;
                end
            end
        end
        out_frame = out_frame_cyc;

        if (out_frame && !out_done) begin
            if (shift_out_seg_end[0]) begin
                // last output cycle
                out_frame_cyc = 0;
                out_done = 1;

                if (shift_out_seg_last[0]) begin
                    out_ctrl_last_next = 1'b1;
                end

                if (out_valid && (out_valid_straddle || shift_out_seg_eop[0]) && m_axis_tready_int) begin
                    out_ctrl_en_next = 1'b1;
                    out_seg_consumed[out_cur_seg] = 1'b1;
                    out_seg_consumed_next = out_seg_consumed;
                    ctrl_fifo_rd_en = out_seg_consumed;
                    out_frame_next = out_frame_cyc;
                    out_seg_offset_next = out_seg_offset_cyc;
                end else begin
                    out_abort = 1'b1;
                end
            end else if (output_offset_cyc == AXIS_SEG_CNT-1) begin
                // output full
                out_done = 1;

                if (out_valid && out_valid_straddle && m_axis_tready_int) begin
                    out_ctrl_en_next = 1'b1;
                    out_seg_consumed[out_cur_seg] = 1'b1;
                    out_seg_consumed_next = out_seg_consumed;
                    ctrl_fifo_rd_en = out_seg_consumed;
                    out_frame_next = out_frame_cyc;
                    out_seg_offset_next = out_seg_offset_cyc;
                end else begin
                    out_abort = 1'b1;
                end
            end else begin
                // middle cycle

                if (out_valid && out_valid_straddle && m_axis_tready_int) begin
                    out_seg_consumed[out_cur_seg] = 1'b1;
                end else begin
                    out_abort = 1'b1;
                end
            end

            if (output_offset_cyc == AXIS_SEG_CNT-1) begin
                output_offset_cyc = 0;
            end else begin
                output_offset_cyc = output_offset_cyc + 1;
            end
        end

        out_cur_seg = out_cur_seg + 1;

        // shift_out_seg_valid = shift_out_seg_valid >> 1;
        shift_out_seg_valid_straddle = shift_out_seg_valid_straddle >> 1;
        shift_out_seg_sop = shift_out_seg_sop >> 1;
        shift_out_seg_eop = shift_out_seg_eop >> 1;
        shift_out_seg_end = shift_out_seg_end >> 1;
        shift_out_seg_last = shift_out_seg_last >> 1;
    end

    // construct output
    input_ready_cmb = out_seg_consumed_reg;

    m_axis_tdata_int = input_data_full >> (SEG_WIDTH*out_ctrl_seg_offset_reg + HDR_WIDTH);

    if (out_ctrl_last_reg) begin
        m_axis_tkeep_int = {AXIS_KEEP_WIDTH{1'b1}} >> (AXIS_KEEP_WIDTH-1 - out_ctrl_last_len_reg);
    end else begin
        m_axis_tkeep_int = {AXIS_KEEP_WIDTH{1'b1}};
    end
    m_axis_tlast_int = out_ctrl_last_reg;

    if (out_ctrl_hdr_reg) begin
        axis_tid_next = input_data_full >> (SEG_WIDTH*out_ctrl_seg_offset_reg + 16 + META_ID_OFFSET);
        axis_tdest_next = input_data_full >> (SEG_WIDTH*out_ctrl_seg_offset_reg + 16 + META_DEST_OFFSET);
        axis_tuser_next = input_data_full >> (SEG_WIDTH*out_ctrl_seg_offset_reg + 16 + META_USER_OFFSET);
    end

    m_axis_tvalid_int = out_ctrl_en_reg;

    m_axis_tid_int = axis_tid_next;
    m_axis_tdest_int = axis_tdest_next;
    m_axis_tuser_int = axis_tuser_next;

    if (EXPAND_INPUT) begin
        for (seg = 0; seg < SEG_CNT; seg = seg + 1) begin
            if (input_ready[seg] && input_valid[seg]) begin
                input_data_int_next[SEG_WIDTH*seg +: SEG_WIDTH] = input_data[SEG_WIDTH*seg +: SEG_WIDTH];
                input_valid_int_next[seg] = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    frame_reg <= frame_next;
    last_reg <= last_next;
    extra_cycle_reg <= extra_cycle_next;
    last_straddle_reg <= last_straddle_next;
    seg_cnt_reg <= seg_cnt_next;
    hdr_parity_err_reg <= hdr_parity_err_next;

    out_frame_reg <= out_frame_next;
    out_seg_offset_reg <= out_seg_offset_next;
    output_offset_reg <= output_offset_next;
    out_seg_consumed_reg <= out_seg_consumed_next;

    input_data_int_reg <= input_data_int_next;
    input_valid_int_reg <= input_valid_int_next;

    out_ctrl_en_reg <= out_ctrl_en_next;
    out_ctrl_hdr_reg <= out_ctrl_hdr_next;
    out_ctrl_last_reg <= out_ctrl_last_next;
    out_ctrl_last_len_reg <= out_ctrl_last_len_next;
    out_ctrl_seg_offset_reg <= out_ctrl_seg_offset_next;

    axis_tid_reg <= axis_tid_next;
    axis_tdest_reg <= axis_tdest_next;
    axis_tuser_reg <= axis_tuser_next;

    if (rst || fifo_rst_in) begin
        frame_reg <= 1'b0;
        hdr_parity_err_reg <= 1'b0;
        out_frame_reg <= 1'b0;
        out_seg_offset_reg <= 0;
        output_offset_reg <= 0;
        out_seg_consumed_reg <= 0;
        input_valid_int_next <= 1'b0;
        out_ctrl_en_reg <= 1'b0;
    end
end

// output datapath logic
reg [AXIS_DATA_WIDTH-1:0] m_axis_tdata_reg  = {AXIS_DATA_WIDTH{1'b0}};
reg [AXIS_KEEP_WIDTH-1:0] m_axis_tkeep_reg  = {AXIS_KEEP_WIDTH{1'b0}};
reg                       m_axis_tvalid_reg = 1'b0;
reg                       m_axis_tlast_reg  = 1'b0;
reg [AXIS_ID_WIDTH-1:0]   m_axis_tid_reg    = {AXIS_ID_WIDTH{1'b0}};
reg [AXIS_DEST_WIDTH-1:0] m_axis_tdest_reg  = {AXIS_DEST_WIDTH{1'b0}};
reg [AXIS_USER_WIDTH-1:0] m_axis_tuser_reg  = {AXIS_USER_WIDTH{1'b0}};

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_DATA_WIDTH-1:0] out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_KEEP_WIDTH-1:0] out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg                       out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_ID_WIDTH-1:0]   out_fifo_tid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_DEST_WIDTH-1:0] out_fifo_tdest[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXIS_USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axis_tready_int = !out_fifo_half_full_reg;

assign m_axis_tdata  = m_axis_tdata_reg;
assign m_axis_tkeep  = AXIS_KEEP_ENABLE ? m_axis_tkeep_reg : {AXIS_KEEP_WIDTH{1'b1}};
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast  = AXIS_LAST_ENABLE ? m_axis_tlast_reg : 1'b1;
assign m_axis_tid    = AXIS_ID_ENABLE   ? m_axis_tid_reg   : {AXIS_ID_WIDTH{1'b0}};
assign m_axis_tdest  = AXIS_DEST_ENABLE ? m_axis_tdest_reg : {AXIS_DEST_WIDTH{1'b0}};
assign m_axis_tuser  = AXIS_USER_ENABLE ? m_axis_tuser_reg : {AXIS_USER_WIDTH{1'b0}};

always @(posedge clk) begin
    m_axis_tvalid_reg <= m_axis_tvalid_reg && !m_axis_tready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axis_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdata_int;
        out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tkeep_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tlast_int;
        out_fifo_tid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tid_int;
        out_fifo_tdest[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdest_int;
        out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tuser_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axis_tvalid_reg || m_axis_tready)) begin
        m_axis_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_tvalid_reg <= 1'b1;
        m_axis_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_tid_reg <= out_fifo_tid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_tdest_reg <= out_fifo_tdest[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst || fifo_rst_in) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
