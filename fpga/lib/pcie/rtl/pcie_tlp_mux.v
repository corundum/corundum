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
 * PCIe TLP multiplexer
 */
module pcie_tlp_mux #
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
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * TLP input
     */
    input  wire [PORTS*TLP_DATA_WIDTH-1:0]               in_tlp_data,
    input  wire [PORTS*TLP_STRB_WIDTH-1:0]               in_tlp_strb,
    input  wire [PORTS*TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  in_tlp_hdr,
    input  wire [PORTS*TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  in_tlp_seq,
    input  wire [PORTS*TLP_SEG_COUNT*3-1:0]              in_tlp_bar_id,
    input  wire [PORTS*TLP_SEG_COUNT*8-1:0]              in_tlp_func_num,
    input  wire [PORTS*TLP_SEG_COUNT*4-1:0]              in_tlp_error,
    input  wire [PORTS*TLP_SEG_COUNT-1:0]                in_tlp_valid,
    input  wire [PORTS*TLP_SEG_COUNT-1:0]                in_tlp_sop,
    input  wire [PORTS*TLP_SEG_COUNT-1:0]                in_tlp_eop,
    output wire [PORTS-1:0]                              in_tlp_ready,

    /*
     * TLP output
     */
    output wire [TLP_DATA_WIDTH-1:0]                     out_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]                     out_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        out_tlp_hdr,
    output wire [TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]        out_tlp_seq,
    output wire [TLP_SEG_COUNT*3-1:0]                    out_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]                    out_tlp_func_num,
    output wire [TLP_SEG_COUNT*4-1:0]                    out_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                      out_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      out_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      out_tlp_eop,
    input  wire                                          out_tlp_ready,

    /*
     * Control
     */
    input  wire [PORTS-1:0]                              pause,

    /*
     * Status
     */
    output wire [PORTS*TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  sel_tlp_seq,
    output wire [PORTS*TLP_SEG_COUNT-1:0]                sel_tlp_seq_valid
);

parameter CL_PORTS = $clog2(PORTS);

parameter TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / TLP_SEG_COUNT;
parameter TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / TLP_SEG_COUNT;

parameter SEG_SEL_WIDTH = $clog2(TLP_SEG_COUNT);

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

reg [PORTS-1:0] in_tlp_ready_cmb;

reg frame_reg = 1'b0, frame_next, frame_cyc;
reg [CL_PORTS-1:0] port_reg = 0, port_next, port_cyc;
reg [SEG_SEL_WIDTH+1-1:0] seg_offset_cyc;
reg valid, eop;
reg frame, abort;

reg [TLP_SEG_COUNT*2-1:0] port_seg_valid[0:PORTS-1];
reg [TLP_SEG_COUNT*2-1:0] port_seg_eop[0:PORTS-1];

reg [TLP_SEG_COUNT-1:0] out_sel, out_sel_cyc;
reg [CL_PORTS-1:0] out_sel_port[0:TLP_SEG_COUNT-1];
reg [SEG_SEL_WIDTH+1-1:0] out_sel_seg[0:TLP_SEG_COUNT-1];

reg [SEG_SEL_WIDTH+1-1:0] port_seg_offset_reg[0:PORTS-1], port_seg_offset_next[0:PORTS-1];

reg [TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] sel_tlp_seq_reg = 0, sel_tlp_seq_next;
reg [PORTS*TLP_SEG_COUNT-1:0] sel_tlp_seq_valid_reg = 0, sel_tlp_seq_valid_next, sel_tlp_seq_valid_cyc;

reg [TLP_DATA_WIDTH-1:0] in_tlp_data_reg[0:PORTS-1], in_tlp_data_next[0:PORTS-1];
reg [TLP_STRB_WIDTH-1:0] in_tlp_strb_reg[0:PORTS-1], in_tlp_strb_next[0:PORTS-1];
reg [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] in_tlp_hdr_reg[0:PORTS-1], in_tlp_hdr_next[0:PORTS-1];
reg [TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0] in_tlp_seq_reg[0:PORTS-1], in_tlp_seq_next[0:PORTS-1];
reg [TLP_SEG_COUNT*3-1:0] in_tlp_bar_id_reg[0:PORTS-1], in_tlp_bar_id_next[0:PORTS-1];
reg [TLP_SEG_COUNT*8-1:0] in_tlp_func_num_reg[0:PORTS-1], in_tlp_func_num_next[0:PORTS-1];
reg [TLP_SEG_COUNT*4-1:0] in_tlp_error_reg[0:PORTS-1], in_tlp_error_next[0:PORTS-1];
reg [TLP_SEG_COUNT-1:0] in_tlp_valid_reg[0:PORTS-1], in_tlp_valid_next[0:PORTS-1];
reg [TLP_SEG_COUNT-1:0] in_tlp_sop_reg[0:PORTS-1], in_tlp_sop_next[0:PORTS-1];
reg [TLP_SEG_COUNT-1:0] in_tlp_eop_reg[0:PORTS-1], in_tlp_eop_next[0:PORTS-1];

reg [TLP_DATA_WIDTH*2-1:0] in_tlp_data_full[0:PORTS-1];
reg [TLP_STRB_WIDTH*2-1:0] in_tlp_strb_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2*TLP_HDR_WIDTH-1:0] in_tlp_hdr_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2*SEQ_NUM_WIDTH-1:0] in_tlp_seq_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2*3-1:0] in_tlp_bar_id_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2*8-1:0] in_tlp_func_num_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2*4-1:0] in_tlp_error_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2-1:0] in_tlp_valid_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2-1:0] in_tlp_sop_full[0:PORTS-1];
reg [TLP_SEG_COUNT*2-1:0] in_tlp_eop_full[0:PORTS-1];

// internal datapath
reg  [TLP_DATA_WIDTH-1:0]               out_tlp_data_int;
reg  [TLP_STRB_WIDTH-1:0]               out_tlp_strb_int;
reg  [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_tlp_hdr_int;
reg  [TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_tlp_seq_int;
reg  [TLP_SEG_COUNT*3-1:0]              out_tlp_bar_id_int;
reg  [TLP_SEG_COUNT*8-1:0]              out_tlp_func_num_int;
reg  [TLP_SEG_COUNT*4-1:0]              out_tlp_error_int;
reg  [TLP_SEG_COUNT-1:0]                out_tlp_valid_int;
reg  [TLP_SEG_COUNT-1:0]                out_tlp_sop_int;
reg  [TLP_SEG_COUNT-1:0]                out_tlp_eop_int;
reg                                     out_tlp_ready_int_reg = 1'b0;
wire                                    out_tlp_ready_int_early;

assign in_tlp_ready = in_tlp_ready_cmb;

assign sel_tlp_seq = {PORTS{sel_tlp_seq_reg}};
assign sel_tlp_seq_valid = sel_tlp_seq_valid_reg;

integer port, cur_port, seg, cur_seg;

always @* begin
    frame_next = frame_reg;
    port_next = port_reg;

    for (port = 0; port < PORTS; port = port + 1) begin
        port_seg_offset_next[port] = port_seg_offset_reg[port];

        in_tlp_data_next[port] = in_tlp_data_reg[port];
        in_tlp_strb_next[port] = in_tlp_strb_reg[port];
        in_tlp_hdr_next[port] = in_tlp_hdr_reg[port];
        in_tlp_seq_next[port] = in_tlp_seq_reg[port];
        in_tlp_bar_id_next[port] = in_tlp_bar_id_reg[port];
        in_tlp_func_num_next[port] = in_tlp_func_num_reg[port];
        in_tlp_error_next[port] = in_tlp_error_reg[port];
        in_tlp_valid_next[port] = in_tlp_valid_reg[port];
        in_tlp_sop_next[port] = in_tlp_sop_reg[port];
        in_tlp_eop_next[port] = in_tlp_eop_reg[port];

        in_tlp_data_full[port] = {in_tlp_data[port*TLP_DATA_WIDTH +: TLP_DATA_WIDTH], in_tlp_data_reg[port]};
        in_tlp_strb_full[port] = {in_tlp_strb[port*TLP_STRB_WIDTH +: TLP_STRB_WIDTH], in_tlp_strb_reg[port]};
        in_tlp_hdr_full[port] = {in_tlp_hdr[port*TLP_SEG_COUNT*TLP_HDR_WIDTH +: TLP_SEG_COUNT*TLP_HDR_WIDTH], in_tlp_hdr_reg[port]};
        in_tlp_seq_full[port] = {in_tlp_seq[port*TLP_SEG_COUNT*SEQ_NUM_WIDTH +: TLP_SEG_COUNT*SEQ_NUM_WIDTH], in_tlp_seq_reg[port]};
        in_tlp_bar_id_full[port] = {in_tlp_bar_id[port*TLP_SEG_COUNT*3 +: TLP_SEG_COUNT*3], in_tlp_bar_id_reg[port]};
        in_tlp_func_num_full[port] = {in_tlp_func_num[port*TLP_SEG_COUNT*8 +: TLP_SEG_COUNT*8], in_tlp_func_num_reg[port]};
        in_tlp_error_full[port] = {in_tlp_error[port*TLP_SEG_COUNT*4 +: TLP_SEG_COUNT*4], in_tlp_error_reg[port]};
        in_tlp_valid_full[port] = {in_tlp_valid[port*TLP_SEG_COUNT +: TLP_SEG_COUNT], in_tlp_valid_reg[port]};
        in_tlp_sop_full[port] = {in_tlp_sop[port*TLP_SEG_COUNT +: TLP_SEG_COUNT], in_tlp_sop_reg[port]};
        in_tlp_eop_full[port] = {in_tlp_eop[port*TLP_SEG_COUNT +: TLP_SEG_COUNT], in_tlp_eop_reg[port]};
    end

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

    frame_cyc = frame_reg;
    port_cyc = port_reg;
    seg_offset_cyc = port_seg_offset_reg[port_reg];
    valid = 0;
    eop = 0;
    frame = frame_cyc;
    abort = 0;

    out_sel = 0;
    out_sel_cyc = 0;
    for (seg = 0; seg < TLP_SEG_COUNT; seg = seg + 1) begin
        out_sel_port[seg] = 0;
        out_sel_seg[seg] = 0;
    end

    sel_tlp_seq_next = 0;
    sel_tlp_seq_valid_next = 0;
    sel_tlp_seq_valid_cyc = 0;

    // compute mux settings
    for (port = 0; port < PORTS; port = port + 1) begin
        port_seg_valid[port] = pause[port] ? 0 : {2{in_tlp_valid_full[port]}} >> port_seg_offset_reg[port];
        port_seg_eop[port] = {2{in_tlp_eop_full[port]}} >> port_seg_offset_reg[port];
    end

    for (seg = 0; seg < TLP_SEG_COUNT; seg = seg + 1) begin
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
                    seg_offset_cyc = port_seg_offset_next[cur_port];
                    if (port_seg_valid[cur_port][0]) begin
                        // set frame
                        frame_cyc = 1;
                        sel_tlp_seq_valid_cyc[TLP_SEG_COUNT*cur_port+seg] = 1'b1;
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
        out_sel_port[seg] = port_cyc;
        out_sel_seg[seg] = seg_offset_cyc;
        if (eop) begin
            // end of packet, clear frame
            frame_cyc = 0;
        end
        seg_offset_cyc = seg_offset_cyc + 1;
        port_seg_valid[port_cyc] = port_seg_valid[port_cyc] >> 1;
        port_seg_eop[port_cyc] = port_seg_eop[port_cyc] >> 1;

        if (frame && !abort) begin
            if (valid) begin
                if (eop || seg == TLP_SEG_COUNT-1) begin
                    // end of packet or end of cycle, commit
                    if (out_tlp_ready_int_reg) begin
                        frame_next = frame_cyc;
                        port_next = port_cyc;
                        port_seg_offset_next[port_cyc] = seg_offset_cyc;
                        out_sel = out_sel_cyc;
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
    for (seg = 0; seg < TLP_SEG_COUNT; seg = seg + 1) begin
        out_tlp_data_int[seg*TLP_SEG_DATA_WIDTH +: TLP_SEG_DATA_WIDTH] = in_tlp_data_full[out_sel_port[seg]][out_sel_seg[seg]*TLP_SEG_DATA_WIDTH +: TLP_SEG_DATA_WIDTH];
        out_tlp_strb_int[seg*TLP_SEG_STRB_WIDTH +: TLP_SEG_STRB_WIDTH] = in_tlp_strb_full[out_sel_port[seg]][out_sel_seg[seg]*TLP_SEG_STRB_WIDTH +: TLP_SEG_STRB_WIDTH];
        out_tlp_hdr_int[seg*TLP_HDR_WIDTH +: TLP_HDR_WIDTH] = in_tlp_hdr_full[out_sel_port[seg]][out_sel_seg[seg]*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
        out_tlp_seq_int[seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = in_tlp_seq_full[out_sel_port[seg]][out_sel_seg[seg]*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
        out_tlp_bar_id_int[seg*3 +: 3] = in_tlp_bar_id_full[out_sel_port[seg]][out_sel_seg[seg]*3 +: 3];
        out_tlp_func_num_int[seg*8 +: 8] = in_tlp_func_num_full[out_sel_port[seg]][out_sel_seg[seg]*8 +: 8];
        out_tlp_error_int[seg*4 +: 4] = in_tlp_error_full[out_sel_port[seg]][out_sel_seg[seg]*4 +: 4];
        if (out_sel[seg]) begin
            out_tlp_valid_int[seg +: 1] = in_tlp_valid_full[out_sel_port[seg]][out_sel_seg[seg] +: 1];
        end
        out_tlp_sop_int[seg +: 1] = in_tlp_sop_full[out_sel_port[seg]][out_sel_seg[seg] +: 1];
        out_tlp_eop_int[seg +: 1] = in_tlp_eop_full[out_sel_port[seg]][out_sel_seg[seg] +: 1];

        sel_tlp_seq_next[seg*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH] = in_tlp_seq_full[out_sel_port[seg]][out_sel_seg[seg]*SEQ_NUM_WIDTH +: SEQ_NUM_WIDTH];
    end

    in_tlp_ready_cmb = 0;
    for (port = 0; port < PORTS; port = port + 1) begin
        in_tlp_valid_next[port] = in_tlp_valid_reg[port] & ({TLP_SEG_COUNT{1'b1}} << port_seg_offset_next[port]);

        if (port_seg_offset_next[port] >= TLP_SEG_COUNT) begin
            port_seg_offset_next[port] = port_seg_offset_next[port] - TLP_SEG_COUNT;
        end else if (in_tlp_valid_reg[port] && (in_tlp_valid_next[port] == 0)) begin
            port_seg_offset_next[port] = 0;
        end

        if (!in_tlp_valid_next[port]) begin
            in_tlp_ready_cmb[port] = 1;
            in_tlp_data_next[port] = in_tlp_data[port*TLP_DATA_WIDTH +: TLP_DATA_WIDTH];
            in_tlp_strb_next[port] = in_tlp_strb[port*TLP_STRB_WIDTH +: TLP_STRB_WIDTH];
            in_tlp_hdr_next[port] = in_tlp_hdr[port*TLP_SEG_COUNT*TLP_HDR_WIDTH +: TLP_SEG_COUNT*TLP_HDR_WIDTH];
            in_tlp_seq_next[port] = in_tlp_seq[port*TLP_SEG_COUNT*SEQ_NUM_WIDTH +: TLP_SEG_COUNT*SEQ_NUM_WIDTH];
            in_tlp_bar_id_next[port] = in_tlp_bar_id[port*TLP_SEG_COUNT*3 +: TLP_SEG_COUNT*3];
            in_tlp_func_num_next[port] = in_tlp_func_num[port*TLP_SEG_COUNT*8 +: TLP_SEG_COUNT*8];
            in_tlp_error_next[port] = in_tlp_error[port*TLP_SEG_COUNT*4 +: TLP_SEG_COUNT*4];
            in_tlp_valid_next[port] = in_tlp_valid[port*TLP_SEG_COUNT +: TLP_SEG_COUNT];
            in_tlp_sop_next[port] = in_tlp_sop[port*TLP_SEG_COUNT +: TLP_SEG_COUNT];
            in_tlp_eop_next[port] = in_tlp_eop[port*TLP_SEG_COUNT +: TLP_SEG_COUNT];
        end
    end
end

integer i;

always @(posedge clk) begin
    frame_reg <= frame_next;
    port_reg <= port_next;

    sel_tlp_seq_reg <= sel_tlp_seq_next;
    sel_tlp_seq_valid_reg <= sel_tlp_seq_valid_next;

    for (i = 0; i < PORTS; i = i + 1) begin
        port_seg_offset_reg[i] <= port_seg_offset_next[i];

        in_tlp_data_reg[i] <= in_tlp_data_next[i];
        in_tlp_strb_reg[i] <= in_tlp_strb_next[i];
        in_tlp_hdr_reg[i] <= in_tlp_hdr_next[i];
        in_tlp_seq_reg[i] <= in_tlp_seq_next[i];
        in_tlp_bar_id_reg[i] <= in_tlp_bar_id_next[i];
        in_tlp_func_num_reg[i] <= in_tlp_func_num_next[i];
        in_tlp_error_reg[i] <= in_tlp_error_next[i];
        in_tlp_valid_reg[i] <= in_tlp_valid_next[i];
        in_tlp_sop_reg[i] <= in_tlp_sop_next[i];
        in_tlp_eop_reg[i] <= in_tlp_eop_next[i];
    end

    if (rst) begin
        frame_reg <= 1'b0;
        port_reg <= 0;

        sel_tlp_seq_valid_reg <= 0;

        for (i = 0; i < PORTS; i = i + 1) begin
            port_seg_offset_reg[i] <= 0;
            in_tlp_valid_reg[i] <= 0;
        end
    end
end

// output datapath logic
reg [TLP_DATA_WIDTH-1:0]               out_tlp_data_reg = 0;
reg [TLP_STRB_WIDTH-1:0]               out_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  out_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  out_tlp_seq_reg = 0;
reg [TLP_SEG_COUNT*3-1:0]              out_tlp_bar_id_reg = 0;
reg [TLP_SEG_COUNT*8-1:0]              out_tlp_func_num_reg = 0;
reg [TLP_SEG_COUNT*4-1:0]              out_tlp_error_reg = 0;
reg [TLP_SEG_COUNT-1:0]                out_tlp_valid_reg = 0, out_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                out_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                out_tlp_eop_reg = 0;

reg [TLP_DATA_WIDTH-1:0]               temp_out_tlp_data_reg = 0;
reg [TLP_STRB_WIDTH-1:0]               temp_out_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  temp_out_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT*SEQ_NUM_WIDTH-1:0]  temp_out_tlp_seq_reg = 0;
reg [TLP_SEG_COUNT*3-1:0]              temp_out_tlp_bar_id_reg = 0;
reg [TLP_SEG_COUNT*8-1:0]              temp_out_tlp_func_num_reg = 0;
reg [TLP_SEG_COUNT*4-1:0]              temp_out_tlp_error_reg = 0;
reg [TLP_SEG_COUNT-1:0]                temp_out_tlp_valid_reg = 0, temp_out_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                temp_out_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                temp_out_tlp_eop_reg = 0;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign out_tlp_data      = out_tlp_data_reg;
assign out_tlp_strb      = out_tlp_strb_reg;
assign out_tlp_hdr       = out_tlp_hdr_reg;
assign out_tlp_seq       = out_tlp_seq_reg;
assign out_tlp_bar_id    = out_tlp_bar_id_reg;
assign out_tlp_func_num  = out_tlp_func_num_reg;
assign out_tlp_error     = out_tlp_error_reg;
assign out_tlp_valid     = out_tlp_valid_reg;
assign out_tlp_sop       = out_tlp_sop_reg;
assign out_tlp_eop       = out_tlp_eop_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign out_tlp_ready_int_early = out_tlp_ready || (!temp_out_tlp_valid_reg && !out_tlp_valid_reg);

always @* begin
    // transfer sink ready state to source
    out_tlp_valid_next = out_tlp_valid_reg;
    temp_out_tlp_valid_next = temp_out_tlp_valid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (out_tlp_ready_int_reg) begin
        // input is ready
        if (out_tlp_ready || !out_tlp_valid_reg) begin
            // output is ready or currently not valid, transfer data to output
            out_tlp_valid_next = out_tlp_valid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_out_tlp_valid_next = out_tlp_valid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (out_tlp_ready) begin
        // input is not ready, but output is ready
        out_tlp_valid_next = temp_out_tlp_valid_reg;
        temp_out_tlp_valid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    out_tlp_valid_reg <= out_tlp_valid_next;
    out_tlp_ready_int_reg <= out_tlp_ready_int_early;
    temp_out_tlp_valid_reg <= temp_out_tlp_valid_next;

    // datapath
    if (store_axis_int_to_output) begin
        out_tlp_data_reg <= out_tlp_data_int;
        out_tlp_strb_reg <= out_tlp_strb_int;
        out_tlp_hdr_reg <= out_tlp_hdr_int;
        out_tlp_seq_reg <= out_tlp_seq_int;
        out_tlp_bar_id_reg <= out_tlp_bar_id_int;
        out_tlp_func_num_reg <= out_tlp_func_num_int;
        out_tlp_error_reg <= out_tlp_error_int;
        out_tlp_sop_reg <= out_tlp_sop_int;
        out_tlp_eop_reg <= out_tlp_eop_int;
    end else if (store_axis_temp_to_output) begin
        out_tlp_data_reg <= temp_out_tlp_data_reg;
        out_tlp_strb_reg <= temp_out_tlp_strb_reg;
        out_tlp_hdr_reg <= temp_out_tlp_hdr_reg;
        out_tlp_seq_reg <= temp_out_tlp_seq_reg;
        out_tlp_bar_id_reg <= temp_out_tlp_bar_id_reg;
        out_tlp_func_num_reg <= temp_out_tlp_func_num_reg;
        out_tlp_error_reg <= temp_out_tlp_error_reg;
        out_tlp_sop_reg <= temp_out_tlp_sop_reg;
        out_tlp_eop_reg <= temp_out_tlp_eop_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_out_tlp_data_reg <= out_tlp_data_int;
        temp_out_tlp_strb_reg <= out_tlp_strb_int;
        temp_out_tlp_hdr_reg <= out_tlp_hdr_int;
        temp_out_tlp_seq_reg <= out_tlp_seq_int;
        temp_out_tlp_bar_id_reg <= out_tlp_bar_id_int;
        temp_out_tlp_func_num_reg <= out_tlp_func_num_int;
        temp_out_tlp_error_reg <= out_tlp_error_int;
        temp_out_tlp_sop_reg <= out_tlp_sop_int;
        temp_out_tlp_eop_reg <= out_tlp_eop_int;
    end

    if (rst) begin
        out_tlp_valid_reg <= 1'b0;
        out_tlp_ready_int_reg <= 1'b0;
        temp_out_tlp_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
