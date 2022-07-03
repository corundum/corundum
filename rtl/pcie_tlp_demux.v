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
 * PCIe TLP demultiplexer
 */
module pcie_tlp_demux #
(
    // Output count
    parameter PORTS = 2,
    // TLP data width
    parameter TLP_DATA_WIDTH = 256,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // Sequence number width
    parameter SEQ_NUM_WIDTH = 6,
    // TLP segment count (input)
    parameter IN_TLP_SEG_COUNT = 1,
    // TLP segment count (output)
    parameter OUT_TLP_SEG_COUNT = IN_TLP_SEG_COUNT,
    // Include output FIFOs
    parameter FIFO_ENABLE = 1,
    // FIFO depth
    parameter FIFO_DEPTH = 2048,
    // FIFO watermark level
    parameter FIFO_WATERMARK = FIFO_DEPTH/2
)
(
    input  wire                                              clk,
    input  wire                                              rst,

    /*
     * TLP input
     */
    input  wire [TLP_DATA_WIDTH-1:0]                         in_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                         in_tlp_strb,
    input  wire [IN_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]         in_tlp_hdr,
    input  wire [IN_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]         in_tlp_seq,
    input  wire [IN_TLP_SEG_COUNT*3-1:0]                     in_tlp_bar_id,
    input  wire [IN_TLP_SEG_COUNT*8-1:0]                     in_tlp_func_num,
    input  wire [IN_TLP_SEG_COUNT*4-1:0]                     in_tlp_error,
    input  wire [IN_TLP_SEG_COUNT-1:0]                       in_tlp_valid,
    input  wire [IN_TLP_SEG_COUNT-1:0]                       in_tlp_sop,
    input  wire [IN_TLP_SEG_COUNT-1:0]                       in_tlp_eop,
    output wire                                              in_tlp_ready,

    /*
     * TLP output
     */
    output wire [PORTS*TLP_DATA_WIDTH-1:0]                   out_tlp_data,
    output wire [PORTS*TLP_STRB_WIDTH-1:0]                   out_tlp_strb,
    output wire [PORTS*OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_tlp_hdr,
    output wire [PORTS*OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_tlp_seq,
    output wire [PORTS*OUT_TLP_SEG_COUNT*3-1:0]              out_tlp_bar_id,
    output wire [PORTS*OUT_TLP_SEG_COUNT*8-1:0]              out_tlp_func_num,
    output wire [PORTS*OUT_TLP_SEG_COUNT*4-1:0]              out_tlp_error,
    output wire [PORTS*OUT_TLP_SEG_COUNT-1:0]                out_tlp_valid,
    output wire [PORTS*OUT_TLP_SEG_COUNT-1:0]                out_tlp_sop,
    output wire [PORTS*OUT_TLP_SEG_COUNT-1:0]                out_tlp_eop,
    input  wire [PORTS-1:0]                                  out_tlp_ready,

    /*
     * Fields
     */
    output wire [IN_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]         match_tlp_hdr,
    output wire [IN_TLP_SEG_COUNT*3-1:0]                     match_tlp_bar_id,
    output wire [IN_TLP_SEG_COUNT*8-1:0]                     match_tlp_func_num,

    /*
     * Control
     */
    input  wire                                              enable,
    input  wire [IN_TLP_SEG_COUNT-1:0]                       drop,
    input  wire [PORTS*IN_TLP_SEG_COUNT-1:0]                 select,

    /*
     * Status
     */
    output wire [PORTS-1:0]                                  fifo_half_full,
    output wire [PORTS-1:0]                                  fifo_watermark
);

parameter CL_PORTS = $clog2(PORTS);

parameter TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / IN_TLP_SEG_COUNT;
parameter TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / IN_TLP_SEG_COUNT;

parameter SEG_SEL_WIDTH = $clog2(IN_TLP_SEG_COUNT);

// check configuration
initial begin
    if (!FIFO_ENABLE && IN_TLP_SEG_COUNT != OUT_TLP_SEG_COUNT) begin
        $error("Error: Output FIFO must be enabled for segment count adaptation (instance %m)");
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

reg [CL_PORTS-1:0] select_reg = 0, select_ctl, select_next;
reg drop_reg = 1'b0, drop_ctl, drop_next;
reg frame_reg = 1'b0, frame_ctl, frame_next;

reg [TLP_DATA_WIDTH-1:0] out_tlp_data_reg = 0, out_tlp_data_next;
reg [TLP_STRB_WIDTH-1:0] out_tlp_strb_reg = 0, out_tlp_strb_next;
reg [IN_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] out_tlp_hdr_reg = 0, out_tlp_hdr_next;
reg [IN_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] out_tlp_seq_reg = 0, out_tlp_seq_next;
reg [IN_TLP_SEG_COUNT*3-1:0] out_tlp_bar_id_reg = 0, out_tlp_bar_id_next;
reg [IN_TLP_SEG_COUNT*8-1:0] out_tlp_func_num_reg = 0, out_tlp_func_num_next;
reg [IN_TLP_SEG_COUNT*4-1:0] out_tlp_error_reg = 0, out_tlp_error_next;
reg [PORTS*IN_TLP_SEG_COUNT-1:0] out_tlp_valid_reg = 0, out_tlp_valid_next;
reg [IN_TLP_SEG_COUNT-1:0] out_tlp_sop_reg = 0, out_tlp_sop_next;
reg [IN_TLP_SEG_COUNT-1:0] out_tlp_eop_reg = 0, out_tlp_eop_next;

wire [PORTS-1:0] out_tlp_ready_int;

assign in_tlp_ready = (!out_tlp_valid_reg || &out_tlp_ready_int) && enable;

assign match_tlp_hdr = in_tlp_hdr;
assign match_tlp_bar_id = in_tlp_bar_id;
assign match_tlp_func_num = in_tlp_func_num;

generate

genvar n;

if (FIFO_ENABLE) begin

    for (n = 0; n < PORTS; n = n + 1) begin

        pcie_tlp_fifo #(
            .DEPTH(FIFO_DEPTH),
            .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
            .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
            .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
            .SEQ_NUM_WIDTH(SEQ_NUM_WIDTH),
            .IN_TLP_SEG_COUNT(IN_TLP_SEG_COUNT),
            .OUT_TLP_SEG_COUNT(OUT_TLP_SEG_COUNT),
            .WATERMARK(FIFO_WATERMARK)
        )
        pcie_tlp_fifo_inst (
            .clk(clk),
            .rst(rst),

            /*
             * TLP input
             */
            .in_tlp_data(out_tlp_data_reg),
            .in_tlp_strb(out_tlp_strb_reg),
            .in_tlp_hdr(out_tlp_hdr_reg),
            .in_tlp_seq(out_tlp_seq_reg),
            .in_tlp_bar_id(out_tlp_bar_id_reg),
            .in_tlp_func_num(out_tlp_func_num_reg),
            .in_tlp_error(out_tlp_error_reg),
            .in_tlp_valid(out_tlp_valid_reg[IN_TLP_SEG_COUNT*n +: IN_TLP_SEG_COUNT]),
            .in_tlp_sop(out_tlp_sop_reg),
            .in_tlp_eop(out_tlp_eop_reg),
            .in_tlp_ready(out_tlp_ready_int[n +: 1]),

            /*
             * TLP output
             */
            .out_tlp_data(out_tlp_data[TLP_DATA_WIDTH*n +: TLP_DATA_WIDTH]),
            .out_tlp_strb(out_tlp_strb[TLP_STRB_WIDTH*n +: TLP_STRB_WIDTH]),
            .out_tlp_hdr(out_tlp_hdr[OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH*n +: OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH]),
            .out_tlp_seq(out_tlp_seq[OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH*n +: OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH]),
            .out_tlp_bar_id(out_tlp_bar_id[OUT_TLP_SEG_COUNT*3*n +: OUT_TLP_SEG_COUNT*3]),
            .out_tlp_func_num(out_tlp_func_num[OUT_TLP_SEG_COUNT*8*n +: OUT_TLP_SEG_COUNT*8]),
            .out_tlp_error(out_tlp_error[OUT_TLP_SEG_COUNT*4*n +: OUT_TLP_SEG_COUNT*4]),
            .out_tlp_valid(out_tlp_valid[OUT_TLP_SEG_COUNT*n +: OUT_TLP_SEG_COUNT]),
            .out_tlp_sop(out_tlp_sop[OUT_TLP_SEG_COUNT*n +: OUT_TLP_SEG_COUNT]),
            .out_tlp_eop(out_tlp_eop[OUT_TLP_SEG_COUNT*n +: OUT_TLP_SEG_COUNT]),
            .out_tlp_ready(out_tlp_ready[n +: 1]),

            /*
             * Status
             */
            .half_full(fifo_half_full[n +: 1]),
            .watermark(fifo_watermark[n +: 1])
        );

    end

end else begin

    assign out_tlp_data = {PORTS{out_tlp_data_reg}};
    assign out_tlp_strb = {PORTS{out_tlp_strb_reg}};
    assign out_tlp_hdr = {PORTS{out_tlp_hdr_reg}};
    assign out_tlp_seq = {PORTS{out_tlp_seq_reg}};
    assign out_tlp_bar_id = {PORTS{out_tlp_bar_id_reg}};
    assign out_tlp_func_num = {PORTS{out_tlp_func_num_reg}};
    assign out_tlp_error = {PORTS{out_tlp_error_reg}};
    assign out_tlp_valid = out_tlp_valid_reg;
    assign out_tlp_sop = {PORTS{out_tlp_sop_reg}};
    assign out_tlp_eop = {PORTS{out_tlp_eop_reg}};

    assign out_tlp_ready_int = out_tlp_ready;

    assign fifo_half_full = 0;
    assign fifo_watermark = 0;

end

endgenerate

integer seg, port;

always @* begin
    select_next = select_reg;
    drop_next = drop_reg;
    frame_next = frame_reg;

    out_tlp_data_next = out_tlp_data_reg;
    out_tlp_strb_next = out_tlp_strb_reg;
    out_tlp_hdr_next = out_tlp_hdr_reg;
    out_tlp_seq_next = out_tlp_seq_reg;
    out_tlp_bar_id_next = out_tlp_bar_id_reg;
    out_tlp_func_num_next = out_tlp_func_num_reg;
    out_tlp_error_next = out_tlp_error_reg;
    out_tlp_valid_next = out_tlp_valid_reg;
    for (port = 0; port < PORTS; port = port + 1) begin
        if (out_tlp_ready_int[port]) begin
            out_tlp_valid_next[IN_TLP_SEG_COUNT*port +: IN_TLP_SEG_COUNT] = 0;
        end
    end
    out_tlp_sop_next = out_tlp_sop_reg;
    out_tlp_eop_next = out_tlp_eop_reg;

    if (in_tlp_ready) begin
        out_tlp_data_next = in_tlp_data;
        out_tlp_strb_next = in_tlp_strb;
        out_tlp_hdr_next = in_tlp_hdr;
        out_tlp_seq_next = in_tlp_seq;
        out_tlp_bar_id_next = in_tlp_bar_id;
        out_tlp_func_num_next = in_tlp_func_num;
        out_tlp_error_next = in_tlp_error;
        out_tlp_sop_next = in_tlp_sop;
        out_tlp_eop_next = in_tlp_eop;

        for (seg = 0; seg < IN_TLP_SEG_COUNT; seg = seg + 1) begin
            if (in_tlp_valid[seg]) begin
                if (in_tlp_sop[seg]) begin
                    frame_next = 1'b1;
                    select_next = 0;
                    drop_next = 1'b1;

                    for (port = 0; port < PORTS; port = port + 1) begin
                        if (select[IN_TLP_SEG_COUNT*port + seg]) begin
                            select_next = port;
                            drop_next = 1'b0;
                        end
                    end

                    if (drop[seg]) begin
                        drop_next = 1'b1;
                    end
                end
                if (frame_next && !drop_next) begin
                    out_tlp_valid_next[IN_TLP_SEG_COUNT*select_next + seg] = 1'b1;
                end
                if (in_tlp_eop[seg]) begin
                    frame_next = 1'b0;
                    drop_next = 1'b0;
                end
            end
        end
    end
end

always @(posedge clk) begin
    select_reg <= select_next;
    drop_reg <= drop_next;
    frame_reg <= frame_next;

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

    if (rst) begin
        select_reg <= 0;
        drop_reg <= 1'b0;
        frame_reg <= 1'b0;

        out_tlp_valid_reg <= 0;
    end
end

endmodule

`resetall
