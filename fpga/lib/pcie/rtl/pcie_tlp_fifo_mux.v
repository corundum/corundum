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
 * PCIe TLP multiplexer with input FIFOs
 */
module pcie_tlp_fifo_mux #
(
    // Input count
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
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1,
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
    input  wire [PORTS*TLP_DATA_WIDTH-1:0]                   in_tlp_data,
    input  wire [PORTS*TLP_STRB_WIDTH-1:0]                   in_tlp_strb,
    input  wire [PORTS*IN_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]   in_tlp_hdr,
    input  wire [PORTS*IN_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]   in_tlp_seq,
    input  wire [PORTS*IN_TLP_SEG_COUNT*3-1:0]               in_tlp_bar_id,
    input  wire [PORTS*IN_TLP_SEG_COUNT*8-1:0]               in_tlp_func_num,
    input  wire [PORTS*IN_TLP_SEG_COUNT*4-1:0]               in_tlp_error,
    input  wire [PORTS*IN_TLP_SEG_COUNT-1:0]                 in_tlp_valid,
    input  wire [PORTS*IN_TLP_SEG_COUNT-1:0]                 in_tlp_sop,
    input  wire [PORTS*IN_TLP_SEG_COUNT-1:0]                 in_tlp_eop,
    output wire [PORTS-1:0]                                  in_tlp_ready,

    /*
     * TLP output
     */
    output wire [TLP_DATA_WIDTH-1:0]                         out_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]                         out_tlp_strb,
    output wire [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        out_tlp_hdr,
    output wire [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]        out_tlp_seq,
    output wire [OUT_TLP_SEG_COUNT*3-1:0]                    out_tlp_bar_id,
    output wire [OUT_TLP_SEG_COUNT*8-1:0]                    out_tlp_func_num,
    output wire [OUT_TLP_SEG_COUNT*4-1:0]                    out_tlp_error,
    output wire [OUT_TLP_SEG_COUNT-1:0]                      out_tlp_valid,
    output wire [OUT_TLP_SEG_COUNT-1:0]                      out_tlp_sop,
    output wire [OUT_TLP_SEG_COUNT-1:0]                      out_tlp_eop,
    input  wire                                              out_tlp_ready,

    /*
     * Flow control count output
     */
    output wire [3:0]                                        out_fc_ph,
    output wire [8:0]                                        out_fc_pd,
    output wire [3:0]                                        out_fc_nph,
    output wire [8:0]                                        out_fc_npd,
    output wire [3:0]                                        out_fc_cplh,
    output wire [8:0]                                        out_fc_cpld,

    /*
     * Control
     */
    input  wire [PORTS-1:0]                                  pause,

    /*
     * Status
     */
    output wire [PORTS*OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  sel_tlp_seq,
    output wire [PORTS*OUT_TLP_SEG_COUNT-1:0]                sel_tlp_seq_valid,
    output wire [PORTS-1:0]                                  fifo_half_full,
    output wire [PORTS-1:0]                                  fifo_watermark
);

parameter CL_PORTS = $clog2(PORTS);

parameter TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / OUT_TLP_SEG_COUNT;
parameter TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / OUT_TLP_SEG_COUNT;

parameter SEG_SEL_WIDTH = $clog2(OUT_TLP_SEG_COUNT);

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

reg frame_reg = 1'b0, frame_next, frame_cyc;
reg [CL_PORTS-1:0] port_reg = 0, port_next, port_cyc;
reg [SEG_SEL_WIDTH-1:0] seg_offset_cyc;
reg [SEG_SEL_WIDTH+1-1:0] seg_count_cyc;
reg valid, eop;
reg frame, abort;
reg [SEG_SEL_WIDTH-1:0] port_seg_offset_cyc[0:PORTS-1];
reg [SEG_SEL_WIDTH+1-1:0] port_seg_count_cyc[0:PORTS-1];

reg [OUT_TLP_SEG_COUNT-1:0] port_seg_valid[0:PORTS-1];
reg [OUT_TLP_SEG_COUNT-1:0] port_seg_eop[0:PORTS-1];

reg [OUT_TLP_SEG_COUNT-1:0] out_sel_reg = 0, out_sel_next, out_sel_cyc;
reg [CL_PORTS-1:0] out_sel_port_reg[0:OUT_TLP_SEG_COUNT-1], out_sel_port_next[0:OUT_TLP_SEG_COUNT-1];
reg [SEG_SEL_WIDTH+1-1:0] out_sel_seg_reg[0:OUT_TLP_SEG_COUNT-1], out_sel_seg_next[0:OUT_TLP_SEG_COUNT-1];

reg [PORTS*OUT_TLP_SEG_COUNT-1:0] sel_tlp_seq_valid_reg = 0, sel_tlp_seq_valid_next, sel_tlp_seq_valid_cyc;
reg [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] out_sel_tlp_seq_reg = 0, out_sel_tlp_seq_next;
reg [PORTS*OUT_TLP_SEG_COUNT-1:0] out_sel_tlp_seq_valid_reg = 0, out_sel_tlp_seq_valid_next;

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

wire [TLP_DATA_WIDTH-1:0] fifo_tlp_data[0:PORTS-1];
wire [TLP_STRB_WIDTH-1:0] fifo_tlp_strb[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] fifo_tlp_hdr[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] fifo_tlp_seq[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT*3-1:0] fifo_tlp_bar_id[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT*8-1:0] fifo_tlp_func_num[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT*4-1:0] fifo_tlp_error[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT-1:0] fifo_tlp_valid[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT-1:0] fifo_tlp_sop[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT-1:0] fifo_tlp_eop[0:PORTS-1];
wire [SEG_SEL_WIDTH-1:0] fifo_seg_offset[0:PORTS-1];
wire [SEG_SEL_WIDTH+1-1:0] fifo_seg_count[0:PORTS-1];
reg [PORTS-1:0] fifo_read_en_reg = 0, fifo_read_en_next;
reg [SEG_SEL_WIDTH+1-1:0] fifo_read_seg_count_reg[0:PORTS-1], fifo_read_seg_count_next[0:PORTS-1];

wire [OUT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_valid[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_sop[0:PORTS-1];
wire [OUT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_eop[0:PORTS-1];
wire [SEG_SEL_WIDTH-1:0] fifo_ctrl_seg_offset[0:PORTS-1];
wire [SEG_SEL_WIDTH+1-1:0] fifo_ctrl_seg_count[0:PORTS-1];
reg [PORTS-1:0] fifo_ctrl_read_en;
reg [SEG_SEL_WIDTH+1-1:0] fifo_ctrl_read_seg_count[0:PORTS-1];

generate

genvar n;

for (n = 0; n < PORTS; n = n + 1) begin

    pcie_tlp_fifo_raw #(
        .DEPTH(FIFO_DEPTH),
        .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
        .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
        .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
        .SEQ_NUM_WIDTH(SEQ_NUM_WIDTH),
        .IN_TLP_SEG_COUNT(IN_TLP_SEG_COUNT),
        .OUT_TLP_SEG_COUNT(OUT_TLP_SEG_COUNT),
        .WATERMARK(FIFO_WATERMARK),
        .CTRL_OUT_EN(1)
    )
    pcie_tlp_fifo_inst (
        .clk(clk),
        .rst(rst),

        /*
         * TLP input
         */
        .in_tlp_data(in_tlp_data[TLP_DATA_WIDTH*n +: TLP_DATA_WIDTH]),
        .in_tlp_strb(in_tlp_strb[TLP_STRB_WIDTH*n +: TLP_STRB_WIDTH]),
        .in_tlp_hdr(in_tlp_hdr[IN_TLP_SEG_COUNT*TLP_HDR_WIDTH*n +: IN_TLP_SEG_COUNT*TLP_HDR_WIDTH]),
        .in_tlp_seq(in_tlp_seq[IN_TLP_SEG_COUNT*SEQ_NUM_WIDTH*n +: IN_TLP_SEG_COUNT*SEQ_NUM_WIDTH]),
        .in_tlp_bar_id(in_tlp_bar_id[IN_TLP_SEG_COUNT*3*n +: IN_TLP_SEG_COUNT*3]),
        .in_tlp_func_num(in_tlp_func_num[IN_TLP_SEG_COUNT*8*n +: IN_TLP_SEG_COUNT*8]),
        .in_tlp_error(in_tlp_error[IN_TLP_SEG_COUNT*4*n +: IN_TLP_SEG_COUNT*4]),
        .in_tlp_valid(in_tlp_valid[IN_TLP_SEG_COUNT*n +: IN_TLP_SEG_COUNT]),
        .in_tlp_sop(in_tlp_sop[IN_TLP_SEG_COUNT*n +: IN_TLP_SEG_COUNT]),
        .in_tlp_eop(in_tlp_eop[IN_TLP_SEG_COUNT*n +: IN_TLP_SEG_COUNT]),
        .in_tlp_ready(in_tlp_ready[n +: 1]),

        /*
         * TLP output
         */
        .out_tlp_data(fifo_tlp_data[n]),
        .out_tlp_strb(fifo_tlp_strb[n]),
        .out_tlp_hdr(fifo_tlp_hdr[n]),
        .out_tlp_seq(fifo_tlp_seq[n]),
        .out_tlp_bar_id(fifo_tlp_bar_id[n]),
        .out_tlp_func_num(fifo_tlp_func_num[n]),
        .out_tlp_error(fifo_tlp_error[n]),
        .out_tlp_valid(fifo_tlp_valid[n]),
        .out_tlp_sop(fifo_tlp_sop[n]),
        .out_tlp_eop(fifo_tlp_eop[n]),
        .out_seg_offset(fifo_seg_offset[n]),
        .out_seg_count(fifo_seg_count[n]),
        .out_read_en(fifo_read_en_reg[n]),
        .out_read_seg_count(fifo_read_seg_count_reg[n]),

        .out_ctrl_tlp_strb(),
        .out_ctrl_tlp_hdr(),
        .out_ctrl_tlp_valid(fifo_ctrl_tlp_valid[n]),
        .out_ctrl_tlp_sop(fifo_ctrl_tlp_sop[n]),
        .out_ctrl_tlp_eop(fifo_ctrl_tlp_eop[n]),
        .out_ctrl_seg_offset(fifo_ctrl_seg_offset[n]),
        .out_ctrl_seg_count(fifo_ctrl_seg_count[n]),
        .out_ctrl_read_en(fifo_ctrl_read_en[n]),
        .out_ctrl_read_seg_count(fifo_ctrl_read_seg_count[n]),

        /*
         * Status
         */
        .half_full(fifo_half_full[n +: 1]),
        .watermark(fifo_watermark[n +: 1])
    );

end

endgenerate

assign sel_tlp_seq = {PORTS{out_sel_tlp_seq_reg}};
assign sel_tlp_seq_valid = out_sel_tlp_seq_valid_reg;

pcie_tlp_fc_count #(
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(OUT_TLP_SEG_COUNT)
)
fc_count_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP monitor
     */
    .tlp_hdr(out_tlp_hdr_int),
    .tlp_valid(out_tlp_valid_int),
    .tlp_sop(out_tlp_sop_int),
    .tlp_ready(1'b1),

    /*
     * Flow control count output
     */
    .out_fc_ph(out_fc_ph),
    .out_fc_pd(out_fc_pd),
    .out_fc_nph(out_fc_nph),
    .out_fc_npd(out_fc_npd),
    .out_fc_cplh(out_fc_cplh),
    .out_fc_cpld(out_fc_cpld)
);

integer port, cur_port, seg, cur_seg;

always @* begin
    frame_next = frame_reg;
    port_next = port_reg;

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

    fifo_read_en_next = 0;
    fifo_ctrl_read_en = 0;

    frame_cyc = frame_reg;
    port_cyc = port_reg;
    seg_offset_cyc = fifo_ctrl_seg_offset[port_reg];
    seg_count_cyc = 0;
    valid = 0;
    eop = 0;
    frame = frame_cyc;
    abort = 0;

    for (port = 0; port < PORTS; port = port + 1) begin
        port_seg_offset_cyc[port] = fifo_ctrl_seg_offset[port];
        port_seg_count_cyc[port] = 0;
        fifo_ctrl_read_seg_count[port] = 0;
        fifo_read_seg_count_next[port] = 0;
    end

    out_sel_next = 0;
    out_sel_cyc = 0;
    for (seg = 0; seg < OUT_TLP_SEG_COUNT; seg = seg + 1) begin
        out_sel_port_next[seg] = 0;
        out_sel_seg_next[seg] = 0;
    end

    sel_tlp_seq_valid_next = 0;
    sel_tlp_seq_valid_cyc = 0;
    out_sel_tlp_seq_next = 0;
    out_sel_tlp_seq_valid_next = 0;

    // compute mux settings
    for (port = 0; port < PORTS; port = port + 1) begin
        port_seg_valid[port] = {2{fifo_ctrl_tlp_valid[port]}} >> fifo_ctrl_seg_offset[port];
        port_seg_eop[port] = {2{fifo_ctrl_tlp_eop[port]}} >> fifo_ctrl_seg_offset[port];
    end

    for (seg = 0; seg < OUT_TLP_SEG_COUNT; seg = seg + 1) begin
        // select port
        if (!frame_cyc) begin
            if (ARB_TYPE_ROUND_ROBIN) begin
                // round robin arb - start checking after previously-selected port
                if (ARB_LSB_HIGH_PRIORITY) begin
                    if (port_cyc < PORTS-1) begin
                        cur_port = port_cyc + 1;
                    end else begin
                        cur_port = 0;
                    end
                end else begin
                    if (port_cyc > 0) begin
                        cur_port = port_cyc - 1;
                    end else begin
                        cur_port = PORTS-1;
                    end
                end
            end else begin
                // priority arb - start from high priority end
                if (ARB_LSB_HIGH_PRIORITY) begin
                    cur_port = 0;
                end else begin
                    cur_port = PORTS-1;
                end
            end
            for (port = 0; port < PORTS; port = port + 1) begin
                if (!frame_cyc) begin
                    // select port
                    port_cyc = cur_port;
                    seg_offset_cyc = port_seg_offset_cyc[cur_port];
                    seg_count_cyc = port_seg_count_cyc[cur_port];
                    if (!pause[cur_port] && port_seg_valid[cur_port][0]) begin
                        // set frame
                        frame_cyc = 1;
                        sel_tlp_seq_valid_cyc[OUT_TLP_SEG_COUNT*cur_port+seg] = 1'b1;
                    end
                end
                // next port
                if (ARB_LSB_HIGH_PRIORITY) begin
                    if (cur_port < PORTS-1) begin
                        cur_port = cur_port + 1;
                    end else begin
                        cur_port = 0;
                    end
                end else begin
                    if (cur_port > 0) begin
                        cur_port = cur_port - 1;
                    end else begin
                        cur_port = PORTS-1;
                    end
                end
            end
        end

        // route segment
        valid = port_seg_valid[port_cyc][0];
        eop = port_seg_eop[port_cyc][0];
        frame = frame_cyc;

        out_sel_cyc[seg] = 1'b1;
        out_sel_port_next[seg] = port_cyc;
        out_sel_seg_next[seg] = seg_offset_cyc;
        if (eop) begin
            // end of packet, clear frame
            frame_cyc = 0;
        end
        seg_offset_cyc = seg_offset_cyc + 1;
        seg_count_cyc = seg_count_cyc + 1;
        port_seg_offset_cyc[port_cyc] = seg_offset_cyc;
        port_seg_count_cyc[port_cyc] = seg_count_cyc;
        port_seg_valid[port_cyc] = port_seg_valid[port_cyc] >> 1;
        port_seg_eop[port_cyc] = port_seg_eop[port_cyc] >> 1;

        if (frame && !abort) begin
            if (valid) begin
                if (eop || seg == OUT_TLP_SEG_COUNT-1) begin
                    // end of packet or end of cycle, commit
                    fifo_read_seg_count_next[port_cyc] = seg_count_cyc;
                    fifo_ctrl_read_seg_count[port_cyc] = seg_count_cyc;
                    if (out_tlp_ready_int) begin
                        frame_next = frame_cyc;
                        port_next = port_cyc;
                        out_sel_next = out_sel_cyc;
                        fifo_read_en_next[port_cyc] = 1'b1;
                        fifo_ctrl_read_en[port_cyc] = 1'b1;
                        sel_tlp_seq_valid_next = sel_tlp_seq_valid_cyc;
                    end
                end
            end else begin
                // input has stalled, wait
                abort = 1;
            end
        end
    end

    // mux for output segments
    for (seg = 0; seg < OUT_TLP_SEG_COUNT; seg = seg + 1) begin
        out_tlp_data_int[seg*TLP_SEG_DATA_WIDTH +: TLP_SEG_DATA_WIDTH] = fifo_tlp_data[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*TLP_SEG_DATA_WIDTH +: TLP_SEG_DATA_WIDTH];
        out_tlp_strb_int[seg*TLP_SEG_STRB_WIDTH +: TLP_SEG_STRB_WIDTH] = fifo_tlp_strb[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*TLP_SEG_STRB_WIDTH +: TLP_SEG_STRB_WIDTH];
        out_tlp_hdr_int[seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = fifo_tlp_hdr[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
        out_tlp_seq_int[seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = fifo_tlp_seq[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
        out_tlp_bar_id_int[seg*3 +: 3] = fifo_tlp_bar_id[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*3 +: 3];
        out_tlp_func_num_int[seg*8 +: 8] = fifo_tlp_func_num[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*8 +: 8];
        out_tlp_error_int[seg*4 +: 4] = fifo_tlp_error[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*4 +: 4];
        if (out_sel_reg[seg]) begin
            out_tlp_valid_int[seg +: 1] = fifo_tlp_valid[out_sel_port_reg[seg]][out_sel_seg_reg[seg] +: 1];
        end
        out_tlp_sop_int[seg +: 1] = fifo_tlp_sop[out_sel_port_reg[seg]][out_sel_seg_reg[seg] +: 1];
        out_tlp_eop_int[seg +: 1] = fifo_tlp_eop[out_sel_port_reg[seg]][out_sel_seg_reg[seg] +: 1];

        out_sel_tlp_seq_next[seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = fifo_tlp_seq[out_sel_port_reg[seg]][out_sel_seg_reg[seg]*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
    end
    out_sel_tlp_seq_valid_next = sel_tlp_seq_valid_reg;
end

integer i;

always @(posedge clk) begin
    frame_reg <= frame_next;
    port_reg <= port_next;

    out_sel_reg <= out_sel_next;
    for (i = 0; i < OUT_TLP_SEG_COUNT; i = i + 1) begin
        out_sel_port_reg[i] <= out_sel_port_next[i];
        out_sel_seg_reg[i] <= out_sel_seg_next[i];
    end

    fifo_read_en_reg <= fifo_read_en_next;
    for (i = 0; i < PORTS; i = i + 1) begin
        fifo_read_seg_count_reg[i] <= fifo_read_seg_count_next[i];
    end

    sel_tlp_seq_valid_reg <= sel_tlp_seq_valid_next;
    out_sel_tlp_seq_reg <= out_sel_tlp_seq_next;
    out_sel_tlp_seq_valid_reg <= out_sel_tlp_seq_valid_next;

    if (rst) begin
        frame_reg <= 1'b0;
        port_reg <= 0;

        out_sel_reg <= 0;

        fifo_read_en_reg <= 0;

        sel_tlp_seq_valid_reg <= 0;
        out_sel_tlp_seq_valid_reg <= 0;
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

endmodule

`resetall
