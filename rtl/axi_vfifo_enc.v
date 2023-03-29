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
 * AXI4 virtual FIFO (encoder)
 */
module axi_vfifo_enc #
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
     * AXI stream data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]    s_axis_tkeep,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,
    input  wire [AXIS_ID_WIDTH-1:0]      s_axis_tid,
    input  wire [AXIS_DEST_WIDTH-1:0]    s_axis_tdest,
    input  wire [AXIS_USER_WIDTH-1:0]    s_axis_tuser,

    /*
     * Segmented data output (to virtual FIFO channel)
     */
    input  wire                          fifo_rst_in,
    output wire [SEG_CNT*SEG_WIDTH-1:0]  output_data,
    output wire [SEG_CNT-1:0]            output_valid,
    input  wire                          fifo_watermark_in
);

parameter AXIS_KEEP_WIDTH_INT = AXIS_KEEP_ENABLE ? AXIS_KEEP_WIDTH : 1;
parameter AXIS_BYTE_LANES = AXIS_KEEP_WIDTH_INT;
parameter AXIS_BYTE_SIZE = AXIS_DATA_WIDTH/AXIS_BYTE_LANES;
parameter CL_AXIS_BYTE_LANES = $clog2(AXIS_BYTE_LANES);

parameter BYTE_SIZE = AXIS_BYTE_SIZE;

parameter SEG_BYTE_LANES = SEG_WIDTH / BYTE_SIZE;

parameter EXPAND_OUTPUT = SEG_CNT < 2;

parameter SEG_CNT_INT = EXPAND_OUTPUT ? SEG_CNT*2 : SEG_CNT;

parameter SEG_IDX_WIDTH = $clog2(SEG_CNT_INT);
parameter SEG_BYTE_IDX_WIDTH = $clog2(SEG_BYTE_LANES);

parameter AXIS_SEG_CNT = (AXIS_DATA_WIDTH + SEG_WIDTH-1) / SEG_WIDTH;
parameter AXIS_SEG_IDX_WIDTH = AXIS_SEG_CNT > 1 ? $clog2(AXIS_SEG_CNT) : 1;
parameter AXIS_LEN_MASK = AXIS_BYTE_LANES-1;

parameter IN_OFFS_WIDTH = AXIS_SEG_IDX_WIDTH;

parameter META_ID_OFFSET = 0;
parameter META_DEST_OFFSET = META_ID_OFFSET + (AXIS_ID_ENABLE ? AXIS_ID_WIDTH : 0);
parameter META_USER_OFFSET = META_DEST_OFFSET + (AXIS_DEST_ENABLE ? AXIS_DEST_WIDTH : 0);
parameter META_WIDTH = META_USER_OFFSET + (AXIS_USER_ENABLE ? AXIS_USER_WIDTH : 0);
parameter HDR_SIZE = (16 + META_WIDTH + BYTE_SIZE-1) / BYTE_SIZE;
parameter HDR_WIDTH = HDR_SIZE * BYTE_SIZE;

parameter HDR_LEN_WIDTH = 12;
parameter HDR_SEG_LEN_WIDTH = HDR_LEN_WIDTH-SEG_BYTE_IDX_WIDTH;

parameter INPUT_FIFO_ADDR_WIDTH = 5;
parameter HDR_FIFO_ADDR_WIDTH = INPUT_FIFO_ADDR_WIDTH + SEG_IDX_WIDTH;

parameter INPUT_FIFO_PTR_WIDTH = INPUT_FIFO_ADDR_WIDTH + SEG_IDX_WIDTH;
parameter HDR_FIFO_PTR_WIDTH = HDR_FIFO_ADDR_WIDTH;

parameter INPUT_FIFO_SIZE = SEG_BYTE_LANES * SEG_CNT_INT * 2**INPUT_FIFO_ADDR_WIDTH;

parameter MAX_BLOCK_LEN = INPUT_FIFO_SIZE / 2 > 4096 ? 4096 : INPUT_FIFO_SIZE / 2;

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

    if (SEG_WIDTH < HDR_SIZE*BYTE_SIZE) begin
        $error("Error: Segment smaller than header (instance %m)");
        $finish;
    end
end

reg [INPUT_FIFO_PTR_WIDTH+1-1:0] input_fifo_wr_ptr_reg = 0, input_fifo_wr_ptr_next;
reg [INPUT_FIFO_PTR_WIDTH+1-1:0] input_fifo_rd_ptr_reg = 0, input_fifo_rd_ptr_next;
reg [HDR_FIFO_PTR_WIDTH+1-1:0] hdr_fifo_wr_ptr_reg = 0, hdr_fifo_wr_ptr_next;
reg [HDR_FIFO_PTR_WIDTH+1-1:0] hdr_fifo_rd_ptr_reg = 0, hdr_fifo_rd_ptr_next;

reg [SEG_CNT_INT-1:0] mem_rd_data_valid_reg = 0, mem_rd_data_valid_next;
reg hdr_mem_rd_data_valid_reg = 0, hdr_mem_rd_data_valid_next;

reg [AXIS_DATA_WIDTH-1:0] int_seg_data;
reg [AXIS_SEG_CNT-1:0] int_seg_valid;

reg [SEG_CNT_INT*SEG_WIDTH-1:0] seg_mem_wr_data;
reg [SEG_CNT_INT-1:0] seg_mem_wr_valid;
reg [SEG_CNT_INT*INPUT_FIFO_ADDR_WIDTH-1:0] seg_mem_wr_addr_reg = 0, seg_mem_wr_addr_next;
reg [SEG_CNT_INT-1:0] seg_mem_wr_en;
reg [SEG_CNT_INT*SEG_IDX_WIDTH-1:0] seg_mem_wr_sel;

wire [SEG_CNT_INT*SEG_WIDTH-1:0] seg_mem_rd_data;
reg [SEG_CNT_INT*INPUT_FIFO_ADDR_WIDTH-1:0] seg_mem_rd_addr_reg = 0, seg_mem_rd_addr_next;
reg [SEG_CNT_INT-1:0] seg_mem_rd_en;

reg [HDR_LEN_WIDTH-1:0] hdr_mem_wr_len;
reg hdr_mem_wr_last;
reg [META_WIDTH-1:0] hdr_mem_wr_meta;
reg [HDR_FIFO_ADDR_WIDTH-1:0] hdr_mem_wr_addr;
reg hdr_mem_wr_en;

wire [HDR_LEN_WIDTH-1:0] hdr_mem_rd_len;
wire hdr_mem_rd_last;
wire [META_WIDTH-1:0] hdr_mem_rd_meta;
reg [HDR_FIFO_ADDR_WIDTH-1:0] hdr_mem_rd_addr_reg = 0, hdr_mem_rd_addr_next;
reg hdr_mem_rd_en;

reg input_fifo_full_reg = 1'b0;
reg input_fifo_half_full_reg = 1'b0;
reg input_fifo_empty_reg = 1'b1;
reg [INPUT_FIFO_PTR_WIDTH+1-1:0] input_fifo_count_reg = 0;
reg hdr_fifo_full_reg = 1'b0;
reg hdr_fifo_half_full_reg = 1'b0;
reg hdr_fifo_empty_reg = 1'b1;
reg [HDR_FIFO_PTR_WIDTH+1-1:0] hdr_fifo_count_reg = 0;

reg [SEG_CNT*SEG_WIDTH-1:0] output_data_reg = 0, output_data_next;
reg [SEG_CNT-1:0] output_valid_reg = 0, output_valid_next;

assign s_axis_tready = !input_fifo_full_reg && !hdr_fifo_full_reg && !fifo_rst_in;

assign output_data = output_data_reg;
assign output_valid = output_valid_reg;

generate

genvar n;

for (n = 0; n < SEG_CNT_INT; n = n + 1) begin : seg_ram

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEG_WIDTH-1:0] seg_mem_data[2**INPUT_FIFO_ADDR_WIDTH-1:0];

    wire wr_en = seg_mem_wr_en[n];
    wire [INPUT_FIFO_ADDR_WIDTH-1:0] wr_addr = seg_mem_wr_addr_reg[n*INPUT_FIFO_ADDR_WIDTH +: INPUT_FIFO_ADDR_WIDTH];
    wire [SEG_WIDTH-1:0] wr_data = seg_mem_wr_data[n*SEG_WIDTH +: SEG_WIDTH];

    wire rd_en = seg_mem_rd_en[n];
    wire [INPUT_FIFO_ADDR_WIDTH-1:0] rd_addr = seg_mem_rd_addr_reg[n*INPUT_FIFO_ADDR_WIDTH +: INPUT_FIFO_ADDR_WIDTH];
    reg [SEG_WIDTH-1:0] rd_data_reg = 0;

    assign seg_mem_rd_data[n*SEG_WIDTH +: SEG_WIDTH] = rd_data_reg;

    always @(posedge clk) begin
        if (wr_en) begin
            seg_mem_data[wr_addr] <= wr_data;
        end
    end

    always @(posedge clk) begin
        if (rd_en) begin
            rd_data_reg <= seg_mem_data[rd_addr];
        end
    end

end

endgenerate

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [HDR_LEN_WIDTH-1:0] hdr_mem_len[2**HDR_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg hdr_mem_last[2**HDR_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [META_WIDTH-1:0] hdr_mem_meta[2**HDR_FIFO_ADDR_WIDTH-1:0];

reg [HDR_LEN_WIDTH-1:0] hdr_mem_rd_len_reg = 0;
reg hdr_mem_rd_last_reg = 1'b0;
reg [META_WIDTH-1:0] hdr_mem_rd_meta_reg = 0;

assign hdr_mem_rd_len = hdr_mem_rd_len_reg;
assign hdr_mem_rd_last = hdr_mem_rd_last_reg;
assign hdr_mem_rd_meta = hdr_mem_rd_meta_reg;

always @(posedge clk) begin
    if (hdr_mem_wr_en) begin
        hdr_mem_len[hdr_mem_wr_addr] <= hdr_mem_wr_len;
        hdr_mem_last[hdr_mem_wr_addr] <= hdr_mem_wr_last;
        hdr_mem_meta[hdr_mem_wr_addr] <= hdr_mem_wr_meta;
    end
end

always @(posedge clk) begin
    if (hdr_mem_rd_en) begin
        hdr_mem_rd_len_reg <= hdr_mem_len[hdr_mem_rd_addr_reg];
        hdr_mem_rd_last_reg <= hdr_mem_last[hdr_mem_rd_addr_reg];
        hdr_mem_rd_meta_reg <= hdr_mem_meta[hdr_mem_rd_addr_reg];
    end
end

// limits
always @(posedge clk) begin
    input_fifo_full_reg <= $unsigned(input_fifo_wr_ptr_reg - input_fifo_rd_ptr_reg) >= (2**INPUT_FIFO_ADDR_WIDTH*SEG_CNT_INT)-SEG_CNT_INT*2;
    input_fifo_half_full_reg <= $unsigned(input_fifo_wr_ptr_reg - input_fifo_rd_ptr_reg) >= (2**INPUT_FIFO_ADDR_WIDTH*SEG_CNT_INT)/2;
    hdr_fifo_full_reg <= $unsigned(hdr_fifo_wr_ptr_reg - hdr_fifo_rd_ptr_reg) >= 2**HDR_FIFO_ADDR_WIDTH-4;
    hdr_fifo_half_full_reg <= $unsigned(hdr_fifo_wr_ptr_reg - hdr_fifo_rd_ptr_reg) >= 2**HDR_FIFO_ADDR_WIDTH/2;

    if (rst) begin
        input_fifo_full_reg <= 1'b0;
        input_fifo_half_full_reg <= 1'b0;
        hdr_fifo_full_reg <= 1'b0;
        hdr_fifo_half_full_reg <= 1'b0;
    end
end

// Split input segments
integer si;

always @* begin
    int_seg_data = s_axis_tdata;
    int_seg_valid = 0;

    if (s_axis_tvalid) begin
        if (s_axis_tlast) begin
            for (si = 0; si < AXIS_SEG_CNT; si = si + 1) begin
                int_seg_valid[si] = s_axis_tkeep[SEG_BYTE_LANES*si +: SEG_BYTE_LANES] != 0;
            end
        end else begin
            int_seg_valid = {AXIS_SEG_CNT{1'b1}};
        end
    end else begin
        int_seg_valid = 0;
    end
end

// Write logic
integer seg, k;
reg [SEG_IDX_WIDTH+1-1:0] seg_count;
reg [SEG_IDX_WIDTH-1:0] cur_seg;

reg frame_reg = 1'b0, frame_next;
reg [HDR_LEN_WIDTH-1:0] len_reg = 0, len_next;

reg cycle_valid_reg = 1'b0, cycle_valid_next;
reg cycle_last_reg = 1'b0, cycle_last_next;
reg [CL_AXIS_BYTE_LANES+1-1:0] cycle_len_reg = 0, cycle_len_next;
reg [META_WIDTH-1:0] cycle_meta_reg = 0, cycle_meta_next;

reg [CL_AXIS_BYTE_LANES+1-1:0] cycle_len;

reg [HDR_LEN_WIDTH-1:0] hdr_len_reg = 0, hdr_len_next;
reg [META_WIDTH-1:0] hdr_meta_reg = 0, hdr_meta_next;
reg hdr_last_reg = 0, hdr_last_next;
reg hdr_commit_reg = 0, hdr_commit_next;
reg hdr_commit_prev_reg = 0, hdr_commit_prev_next;
reg hdr_valid_reg = 0, hdr_valid_next;

wire [META_WIDTH-1:0] s_axis_meta;

generate

if (AXIS_ID_ENABLE) assign s_axis_meta[META_ID_OFFSET +: AXIS_ID_WIDTH] = s_axis_tid;
if (AXIS_DEST_ENABLE) assign s_axis_meta[META_DEST_OFFSET +: AXIS_DEST_WIDTH] = s_axis_tdest;
if (AXIS_USER_ENABLE) assign s_axis_meta[META_USER_OFFSET +: AXIS_USER_WIDTH] = s_axis_tuser;

endgenerate

always @* begin
    input_fifo_wr_ptr_next = input_fifo_wr_ptr_reg;
    hdr_fifo_wr_ptr_next = hdr_fifo_wr_ptr_reg;

    if (AXIS_KEEP_ENABLE) begin
        cycle_len = 0;
        for (k = 0; k < AXIS_BYTE_LANES; k = k + 1) begin
            cycle_len = cycle_len + s_axis_tkeep[k];
        end
    end else begin
        cycle_len = AXIS_BYTE_LANES;
    end

    // pack segments
    seg_mem_wr_valid = 0;
    seg_mem_wr_sel = 0;
    cur_seg = input_fifo_wr_ptr_reg[SEG_IDX_WIDTH-1:0];
    seg_count = 0;
    for (seg = 0; seg < AXIS_SEG_CNT; seg = seg + 1) begin
        if (int_seg_valid[seg]) begin
            seg_mem_wr_valid[cur_seg +: 1] = 1'b1;
            seg_mem_wr_sel[cur_seg*SEG_IDX_WIDTH +: SEG_IDX_WIDTH] = seg;
            cur_seg = cur_seg + 1;
            seg_count = seg_count + 1;
        end
    end

    for (seg = 0; seg < SEG_CNT_INT; seg = seg + 1) begin
        seg_mem_wr_data[seg*SEG_WIDTH +: SEG_WIDTH] = int_seg_data[seg_mem_wr_sel[seg*SEG_IDX_WIDTH +: SEG_IDX_WIDTH]*SEG_WIDTH +: SEG_WIDTH];
    end

    seg_mem_wr_addr_next = seg_mem_wr_addr_reg;
    seg_mem_wr_en = 0;

    hdr_mem_wr_len = hdr_len_reg;
    hdr_mem_wr_last = hdr_last_reg;
    hdr_mem_wr_meta = hdr_meta_reg;
    hdr_mem_wr_addr = hdr_fifo_wr_ptr_reg;
    hdr_mem_wr_en = 1'b0;

    frame_next = frame_reg;
    len_next = len_reg;

    cycle_valid_next = 1'b0;
    cycle_last_next = cycle_last_reg;
    cycle_len_next = cycle_len_reg;
    cycle_meta_next = cycle_meta_reg;

    hdr_len_next = len_reg;
    hdr_meta_next = cycle_meta_reg;
    hdr_last_next = cycle_last_reg;
    hdr_commit_next = 1'b0;
    hdr_commit_prev_next = 1'b0;
    hdr_valid_next = 1'b0;

    if (s_axis_tvalid && s_axis_tready) begin
        // transfer data
        seg_mem_wr_en = seg_mem_wr_valid;
        input_fifo_wr_ptr_next = input_fifo_wr_ptr_reg + seg_count;
        for (seg = 0; seg < SEG_CNT_INT; seg = seg + 1) begin
            seg_mem_wr_addr_next[seg*INPUT_FIFO_ADDR_WIDTH +: INPUT_FIFO_ADDR_WIDTH] = (input_fifo_wr_ptr_next + (SEG_CNT_INT-1 - seg)) >> SEG_IDX_WIDTH;
        end

        cycle_valid_next = 1'b1;
        cycle_last_next = s_axis_tlast;
        cycle_len_next = cycle_len;
        cycle_meta_next = s_axis_meta;
    end

    if (cycle_valid_reg) begin
        // process packets
        if (!frame_reg) begin
            frame_next = 1'b1;

            if (cycle_last_reg) begin
                len_next = cycle_len_reg;
            end else begin
                len_next = AXIS_BYTE_LANES;
            end

            hdr_len_next = len_next-1;
            hdr_meta_next = cycle_meta_reg;
            hdr_last_next = cycle_last_reg;
            hdr_valid_next = 1'b1;

            if (cycle_last_reg) begin
                // end of frame

                hdr_commit_next = 1'b1;

                frame_next = 1'b0;
            end
        end else begin
            if (cycle_meta_reg != hdr_meta_reg) begin
                if (cycle_last_reg) begin
                    len_next = cycle_len_reg;
                end else begin
                    len_next = AXIS_BYTE_LANES;
                end
            end else begin
                if (cycle_last_reg) begin
                    len_next = len_reg + cycle_len_reg;
                end else begin
                    len_next = len_reg + AXIS_BYTE_LANES;
                end
            end

            hdr_len_next = len_next-1;
            hdr_meta_next = cycle_meta_reg;
            hdr_last_next = cycle_last_reg;
            hdr_valid_next = 1'b1;

            if (cycle_meta_reg != hdr_meta_reg) begin
                // meta changed

                hdr_commit_prev_next = 1'b1;

                if (cycle_last_reg) begin
                    hdr_commit_next = 1'b1;
                    frame_next = 1'b0;
                end
            end else if (cycle_last_reg || len_next >= MAX_BLOCK_LEN) begin
                // end of frame or block is full

                hdr_commit_next = 1'b1;

                frame_next = 1'b0;
            end
        end
    end

    if (hdr_valid_reg) begin
        hdr_mem_wr_len = hdr_len_reg;
        hdr_mem_wr_last = hdr_last_reg;
        hdr_mem_wr_meta = hdr_meta_reg;
        hdr_mem_wr_addr = hdr_fifo_wr_ptr_reg;
        hdr_mem_wr_en = 1'b1;

        if (hdr_commit_prev_reg) begin
            if (hdr_commit_reg) begin
                hdr_fifo_wr_ptr_next = hdr_fifo_wr_ptr_reg + 2;
                hdr_mem_wr_addr = hdr_fifo_wr_ptr_reg + 1;
            end else begin
                hdr_fifo_wr_ptr_next = hdr_fifo_wr_ptr_reg + 1;
                hdr_mem_wr_addr = hdr_fifo_wr_ptr_reg + 1;
            end
        end else begin
            if (hdr_commit_reg) begin
                hdr_fifo_wr_ptr_next = hdr_fifo_wr_ptr_reg + 1;
                hdr_mem_wr_addr = hdr_fifo_wr_ptr_reg;
            end
        end
    end
end

always @(posedge clk) begin
    input_fifo_wr_ptr_reg <= input_fifo_wr_ptr_next;
    hdr_fifo_wr_ptr_reg <= hdr_fifo_wr_ptr_next;

    seg_mem_wr_addr_reg <= seg_mem_wr_addr_next;

    frame_reg <= frame_next;
    len_reg <= len_next;

    cycle_valid_reg <= cycle_valid_next;
    cycle_last_reg <= cycle_last_next;
    cycle_len_reg <= cycle_len_next;
    cycle_meta_reg <= cycle_meta_next;

    hdr_len_reg <= hdr_len_next;
    hdr_meta_reg <= hdr_meta_next;
    hdr_last_reg <= hdr_last_next;
    hdr_commit_reg <= hdr_commit_next;
    hdr_commit_prev_reg <= hdr_commit_prev_next;
    hdr_valid_reg <= hdr_valid_next;

    if (rst || fifo_rst_in) begin
        input_fifo_wr_ptr_reg <= 0;
        hdr_fifo_wr_ptr_reg <= 0;

        seg_mem_wr_addr_reg <= 0;

        frame_reg <= 1'b0;

        cycle_valid_reg <= 1'b0;
        hdr_valid_reg <= 1'b0;
    end
end

// Read logic
integer rd_seg;
reg [SEG_IDX_WIDTH-1:0] cur_rd_seg;
reg rd_valid;

reg out_frame_reg = 1'b0, out_frame_next;
reg [HDR_LEN_WIDTH-1:0] out_len_reg = 0, out_len_next;
reg out_split1_reg = 1'b0, out_split1_next;
reg [HDR_SEG_LEN_WIDTH-1:0] out_seg_cnt_in_reg = 0, out_seg_cnt_in_next;
reg out_seg_last_straddle_reg = 1'b0, out_seg_last_straddle_next;
reg [SEG_IDX_WIDTH-1:0] out_seg_offset_reg = 0, out_seg_offset_next;
reg [SEG_IDX_WIDTH-1:0] out_seg_fifo_offset_reg = 0, out_seg_fifo_offset_next;
reg [SEG_IDX_WIDTH+1-1:0] out_seg_count_reg = 0, out_seg_count_next;

reg [HDR_WIDTH-1:0] out_hdr_reg = 0, out_hdr_next;

reg [SEG_CNT_INT-1:0] out_ctl_seg_hdr_reg = 0, out_ctl_seg_hdr_next, out_ctl_seg_hdr_raw;
reg [SEG_CNT_INT-1:0] out_ctl_seg_split1_reg = 0, out_ctl_seg_split1_next, out_ctl_seg_split1_raw;
reg [SEG_CNT_INT-1:0] out_ctl_seg_en_reg = 0, out_ctl_seg_en_next, out_ctl_seg_en_raw;
reg [SEG_IDX_WIDTH-1:0] out_ctl_seg_idx_reg[SEG_CNT_INT-1:0], out_ctl_seg_idx_next[SEG_CNT_INT-1:0];
reg [SEG_IDX_WIDTH-1:0] out_ctl_seg_offset_reg = 0, out_ctl_seg_offset_next;

reg [HDR_WIDTH-1:0] out_shift_reg = 0, out_shift_next;

reg [7:0] block_timeout_count_reg = 0, block_timeout_count_next;
reg block_timeout_reg = 0, block_timeout_next;

always @* begin
    input_fifo_rd_ptr_next = input_fifo_rd_ptr_reg;
    hdr_fifo_rd_ptr_next = hdr_fifo_rd_ptr_reg;

    mem_rd_data_valid_next = mem_rd_data_valid_reg;
    hdr_mem_rd_data_valid_next = hdr_mem_rd_data_valid_reg;

    output_data_next = output_data_reg;
    output_valid_next = 0;

    seg_mem_rd_addr_next = seg_mem_rd_addr_reg;
    seg_mem_rd_en = 0;

    hdr_mem_rd_addr_next = hdr_mem_rd_addr_reg;
    hdr_mem_rd_en = 0;

    out_frame_next = out_frame_reg;
    out_len_next = out_len_reg;
    out_split1_next = out_split1_reg;
    out_seg_cnt_in_next = out_seg_cnt_in_reg;
    out_seg_last_straddle_next = out_seg_last_straddle_reg;
    out_seg_offset_next = out_seg_offset_reg;
    out_seg_fifo_offset_next = out_seg_fifo_offset_reg;

    out_hdr_next = out_hdr_reg;

    out_ctl_seg_hdr_raw = 0;
    out_ctl_seg_hdr_next = 0;
    out_ctl_seg_split1_raw = 0;
    out_ctl_seg_split1_next = 0;
    out_ctl_seg_en_raw = 0;
    out_ctl_seg_en_next = 0;
    out_ctl_seg_offset_next = out_seg_offset_reg;

    for (seg = 0; seg < SEG_CNT_INT; seg = seg + 1) begin
        out_ctl_seg_idx_next[seg] = out_seg_fifo_offset_reg - out_seg_offset_reg + seg;
    end

    // partial block timeout handling
    block_timeout_count_next = block_timeout_count_reg;
    block_timeout_next = block_timeout_count_reg == 0;
    if (output_valid || out_seg_offset_reg == 0) begin
        block_timeout_count_next = 8'hff;
        block_timeout_next = 1'b0;
    end else if (block_timeout_count_reg > 0) begin
        block_timeout_count_next = block_timeout_count_reg - 1;
    end

    // process headers and generate output commands
    if (!fifo_watermark_in) begin
        if (out_frame_reg) begin
            if (out_seg_cnt_in_next >= SEG_CNT_INT) begin
                out_frame_next = out_seg_last_straddle_next || out_seg_cnt_in_next > SEG_CNT_INT;
                out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}};
                out_seg_offset_next = out_seg_offset_reg + SEG_CNT_INT;
                out_seg_fifo_offset_next = out_seg_fifo_offset_reg + SEG_CNT_INT;
            end else begin
                out_frame_next = 1'b0;
                if (out_seg_last_straddle_next) begin
                    out_ctl_seg_split1_raw = 1 << out_seg_cnt_in_next;
                    if (out_seg_cnt_in_next == SEG_CNT_INT-1) begin
                        out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}};
                    end else begin
                        out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}} >> (SEG_CNT_INT - (out_seg_cnt_in_next+1));
                    end
                    out_seg_offset_next = out_seg_offset_reg + out_seg_cnt_in_next+1;
                end else begin
                    out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}} >> (SEG_CNT_INT - out_seg_cnt_in_next);
                    out_seg_offset_next = out_seg_offset_reg + out_seg_cnt_in_next;
                end
                out_seg_fifo_offset_next = out_seg_fifo_offset_reg + out_seg_cnt_in_next;
            end

            out_seg_cnt_in_next = out_seg_cnt_in_next - SEG_CNT_INT;
        end else begin
            out_len_next = hdr_mem_rd_len;
            out_seg_cnt_in_next = (hdr_mem_rd_len + SEG_BYTE_LANES) >> SEG_BYTE_IDX_WIDTH;
            out_seg_last_straddle_next = ((hdr_mem_rd_len & (SEG_BYTE_LANES-1)) + HDR_SIZE) >> SEG_BYTE_IDX_WIDTH != 0;
            out_hdr_next = 0;
            out_hdr_next[0] = 1'b1;
            out_hdr_next[1] = hdr_mem_rd_last;
            out_hdr_next[2] = !hdr_mem_rd_last;
            out_hdr_next[15:4] = hdr_mem_rd_len;
            out_hdr_next[3] = ^hdr_mem_rd_len;
            if (META_WIDTH > 0) begin
                out_hdr_next[16 +: META_WIDTH] = hdr_mem_rd_meta;
            end

            out_ctl_seg_hdr_raw = 1;

            if (hdr_mem_rd_data_valid_reg) begin
                if (out_seg_cnt_in_next >= SEG_CNT_INT) begin
                    out_frame_next = out_seg_last_straddle_next || out_seg_cnt_in_next > SEG_CNT_INT;
                    out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}};
                    out_seg_offset_next = out_seg_offset_reg + SEG_CNT_INT;
                    out_seg_fifo_offset_next = out_seg_fifo_offset_reg + SEG_CNT_INT;
                end else begin
                    out_frame_next = 1'b0;
                    if (out_seg_last_straddle_next) begin
                        out_ctl_seg_split1_raw = 1 << out_seg_cnt_in_next;
                        if (out_seg_cnt_in_next == SEG_CNT_INT-1) begin
                            out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}};
                        end else begin
                            out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}} >> (SEG_CNT_INT - (out_seg_cnt_in_next+1));
                        end
                        out_seg_offset_next = out_seg_offset_reg + out_seg_cnt_in_next+1;
                    end else begin
                        out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}} >> (SEG_CNT_INT - out_seg_cnt_in_next);
                        out_seg_offset_next = out_seg_offset_reg + out_seg_cnt_in_next;
                    end
                    out_seg_fifo_offset_next = out_seg_fifo_offset_reg + out_seg_cnt_in_next;
                end

                out_seg_cnt_in_next = out_seg_cnt_in_next - SEG_CNT_INT;

                hdr_mem_rd_data_valid_next = 1'b0;
            end else if (block_timeout_reg && out_seg_offset_reg) begin
                // insert padding
                out_hdr_next[15:0] = 0;

                out_ctl_seg_en_raw = {SEG_CNT_INT{1'b1}} >> out_seg_offset_reg;
                out_ctl_seg_hdr_raw = {SEG_CNT_INT{1'b1}};
                out_ctl_seg_split1_raw = {SEG_CNT_INT{1'b1}};

                out_seg_offset_next = 0;
            end
        end
    end

    out_ctl_seg_hdr_next = {2{out_ctl_seg_hdr_raw}} >> (SEG_CNT_INT - out_seg_offset_reg);
    out_ctl_seg_split1_next = {2{out_ctl_seg_split1_raw}} >> (SEG_CNT_INT - out_seg_offset_reg);
    out_ctl_seg_en_next = {2{out_ctl_seg_en_raw}} >> (SEG_CNT_INT - out_seg_offset_reg);

    out_shift_next = out_shift_reg;

    // mux segments
    cur_rd_seg = out_ctl_seg_offset_reg;
    for (rd_seg = 0; rd_seg < SEG_CNT_INT; rd_seg = rd_seg + 1) begin
        output_data_next[cur_rd_seg*SEG_WIDTH +: SEG_WIDTH] = out_shift_next;
        output_data_next[cur_rd_seg*SEG_WIDTH+HDR_WIDTH +: SEG_WIDTH-HDR_WIDTH] = seg_mem_rd_data[out_ctl_seg_idx_reg[cur_rd_seg]*SEG_WIDTH +: SEG_WIDTH-HDR_WIDTH];

        if (out_ctl_seg_hdr_reg[cur_rd_seg]) begin
            output_data_next[cur_rd_seg*SEG_WIDTH +: HDR_WIDTH] = out_hdr_reg;
        end

        output_valid_next[cur_rd_seg] = out_ctl_seg_en_reg[cur_rd_seg];

        if (out_ctl_seg_en_reg[cur_rd_seg] && !out_ctl_seg_split1_reg[cur_rd_seg]) begin
            mem_rd_data_valid_next[out_ctl_seg_idx_reg[cur_rd_seg]] = 1'b0;
        end

        if (out_ctl_seg_en_reg[cur_rd_seg]) begin
            out_shift_next = seg_mem_rd_data[(out_ctl_seg_idx_reg[cur_rd_seg]+1)*SEG_WIDTH-HDR_WIDTH +: HDR_WIDTH];
        end

        cur_rd_seg = cur_rd_seg + 1;
    end

    // read segments
    cur_rd_seg = input_fifo_rd_ptr_reg[SEG_IDX_WIDTH-1:0];
    rd_valid = 1;
    for (rd_seg = 0; rd_seg < SEG_CNT_INT; rd_seg = rd_seg + 1) begin
        if (!mem_rd_data_valid_next[cur_rd_seg] && input_fifo_count_reg > rd_seg && rd_valid) begin
            input_fifo_rd_ptr_next = input_fifo_rd_ptr_reg + rd_seg+1;
            seg_mem_rd_en[cur_rd_seg] = 1'b1;
            seg_mem_rd_addr_next[cur_rd_seg*INPUT_FIFO_ADDR_WIDTH +: INPUT_FIFO_ADDR_WIDTH] = ((input_fifo_rd_ptr_reg + rd_seg) >> SEG_IDX_WIDTH) + 1;
            mem_rd_data_valid_next[cur_rd_seg] = 1'b1;
        end else begin
            rd_valid = 0;
        end
        cur_rd_seg = cur_rd_seg + 1;
    end

    // read header
    if (!hdr_mem_rd_data_valid_next && !hdr_fifo_empty_reg) begin
        hdr_fifo_rd_ptr_next = hdr_fifo_rd_ptr_reg + 1;
        hdr_mem_rd_en = 1'b1;
        hdr_mem_rd_addr_next = hdr_fifo_rd_ptr_next;
        hdr_mem_rd_data_valid_next = 1'b1;
    end
end

integer i;

always @(posedge clk) begin
    input_fifo_rd_ptr_reg <= input_fifo_rd_ptr_next;
    input_fifo_count_reg <= input_fifo_wr_ptr_next - input_fifo_rd_ptr_next;
    input_fifo_empty_reg <= input_fifo_wr_ptr_next == input_fifo_rd_ptr_next;
    hdr_fifo_rd_ptr_reg <= hdr_fifo_rd_ptr_next;
    hdr_fifo_count_reg <= hdr_fifo_wr_ptr_next - hdr_fifo_rd_ptr_next;
    hdr_fifo_empty_reg <= hdr_fifo_wr_ptr_next == hdr_fifo_rd_ptr_next;

    seg_mem_rd_addr_reg <= seg_mem_rd_addr_next;
    hdr_mem_rd_addr_reg <= hdr_mem_rd_addr_next;

    mem_rd_data_valid_reg <= mem_rd_data_valid_next;
    hdr_mem_rd_data_valid_reg <= hdr_mem_rd_data_valid_next;

    output_data_reg <= output_data_next;
    output_valid_reg <= output_valid_next;

    out_frame_reg <= out_frame_next;
    out_len_reg <= out_len_next;
    out_split1_reg <= out_split1_next;
    out_seg_cnt_in_reg <= out_seg_cnt_in_next;
    out_seg_last_straddle_reg <= out_seg_last_straddle_next;
    out_seg_offset_reg <= out_seg_offset_next;
    out_seg_fifo_offset_reg <= out_seg_fifo_offset_next;

    out_hdr_reg <= out_hdr_next;

    out_ctl_seg_hdr_reg <= out_ctl_seg_hdr_next;
    out_ctl_seg_split1_reg <= out_ctl_seg_split1_next;
    out_ctl_seg_en_reg <= out_ctl_seg_en_next;
    for (i = 0; i < SEG_CNT_INT; i = i + 1) begin
        out_ctl_seg_idx_reg[i] <= out_ctl_seg_idx_next[i];
    end
    out_ctl_seg_offset_reg <= out_ctl_seg_offset_next;

    out_shift_reg <= out_shift_next;

    block_timeout_count_reg <= block_timeout_count_next;
    block_timeout_reg <= block_timeout_next;

    if (rst || fifo_rst_in) begin
        input_fifo_rd_ptr_reg <= 0;
        input_fifo_count_reg <= 0;
        input_fifo_empty_reg <= 1'b1;
        hdr_fifo_rd_ptr_reg <= 0;
        hdr_fifo_count_reg <= 0;
        hdr_fifo_empty_reg <= 1'b1;

        seg_mem_rd_addr_reg <= 0;
        hdr_mem_rd_addr_reg <= 0;

        mem_rd_data_valid_reg <= 0;
        hdr_mem_rd_data_valid_reg <= 0;

        out_frame_reg <= 1'b0;
        out_len_reg <= 0;
        out_split1_reg <= 0;
        out_seg_offset_reg <= 0;
        out_seg_fifo_offset_reg <= 0;
        out_seg_count_reg <= 0;
    end
end

endmodule

`resetall
