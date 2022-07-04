/*

Copyright (c) 2021-2022 Alex Forencich

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
 * Xilinx UltraScale PCIe interface adapter (Completer reQuest)
 */
module pcie_us_if_cq #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream CQ tuser signal width
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
    // CQ interface TLP straddling
    parameter CQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    // TLP data width
    parameter TLP_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI input (CQ)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]              s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]              s_axis_cq_tkeep,
    input  wire                                         s_axis_cq_tvalid,
    output wire                                         s_axis_cq_tready,
    input  wire                                         s_axis_cq_tlast,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0]           s_axis_cq_tuser,

    /*
     * TLP output (request to BAR)
     */
    output wire [TLP_DATA_WIDTH-1:0]                    rx_req_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]                    rx_req_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]       rx_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]                   rx_req_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]                   rx_req_tlp_func_num,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_eop,
    input  wire                                         rx_req_tlp_ready
);

parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter INT_TLP_SEG_COUNT = (CQ_STRADDLE && AXIS_PCIE_DATA_WIDTH >= 512) ? 2 : 1;
parameter INT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / INT_TLP_SEG_COUNT;
parameter INT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / INT_TLP_SEG_COUNT;

// bus width assertions
initial begin
    if (AXIS_PCIE_DATA_WIDTH != 64 && AXIS_PCIE_DATA_WIDTH != 128 && AXIS_PCIE_DATA_WIDTH != 256 && AXIS_PCIE_DATA_WIDTH != 512) begin
        $error("Error: PCIe interface width must be 64, 128, 256, or 512 (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_KEEP_WIDTH * 32 != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        if (AXIS_PCIE_CQ_USER_WIDTH != 183) begin
            $error("Error: PCIe CQ tuser width must be 183 (instance %m)");
            $finish;
        end
    end else begin
        if (AXIS_PCIE_CQ_USER_WIDTH != 85 && AXIS_PCIE_CQ_USER_WIDTH != 88) begin
            $error("Error: PCIe CQ tuser width must be 85 or 88 (instance %m)");
            $finish;
        end
    end

    if (TLP_DATA_WIDTH != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end
end

localparam [2:0]
    TLP_FMT_3DW = 3'b000,
    TLP_FMT_4DW = 3'b001,
    TLP_FMT_3DW_DATA = 3'b010,
    TLP_FMT_4DW_DATA = 3'b011,
    TLP_FMT_PREFIX = 3'b100;

localparam [3:0]
    REQ_MEM_READ = 4'b0000,
    REQ_MEM_WRITE = 4'b0001,
    REQ_IO_READ = 4'b0010,
    REQ_IO_WRITE = 4'b0011,
    REQ_MEM_FETCH_ADD = 4'b0100,
    REQ_MEM_SWAP = 4'b0101,
    REQ_MEM_CAS = 4'b0110,
    REQ_MEM_READ_LOCKED = 4'b0111,
    REQ_CFG_READ_0 = 4'b1000,
    REQ_CFG_READ_1 = 4'b1001,
    REQ_CFG_WRITE_0 = 4'b1010,
    REQ_CFG_WRITE_1 = 4'b1011,
    REQ_MSG = 4'b1100,
    REQ_MSG_VENDOR = 4'b1101,
    REQ_MSG_ATS = 4'b1110;

reg [TLP_DATA_WIDTH-1:0] rx_req_tlp_data_reg = 0, rx_req_tlp_data_next;
reg [TLP_STRB_WIDTH-1:0] rx_req_tlp_strb_reg = 0, rx_req_tlp_strb_next;
reg [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] rx_req_tlp_hdr_reg = 0, rx_req_tlp_hdr_next;
reg [INT_TLP_SEG_COUNT*3-1:0] rx_req_tlp_bar_id_reg = 0, rx_req_tlp_bar_id_next;
reg [INT_TLP_SEG_COUNT*8-1:0] rx_req_tlp_func_num_reg = 0, rx_req_tlp_func_num_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_req_tlp_valid_reg = 0, rx_req_tlp_valid_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_req_tlp_sop_reg = 0, rx_req_tlp_sop_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_req_tlp_eop_reg = 0, rx_req_tlp_eop_next;
reg tlp_frame_reg = 0, tlp_frame_next;

wire fifo_tlp_ready;

reg tlp_input_frame_reg = 1'b0, tlp_input_frame_next;

reg [TLP_DATA_WIDTH-1:0] cq_data;
reg [TLP_STRB_WIDTH-1:0] cq_strb;
reg [INT_TLP_SEG_COUNT*8-1:0] cq_hdr_be;
reg [INT_TLP_SEG_COUNT-1:0] cq_valid;
reg [TLP_STRB_WIDTH-1:0] cq_strb_sop;
reg [TLP_STRB_WIDTH-1:0] cq_strb_eop;
reg [INT_TLP_SEG_COUNT-1:0] cq_sop;
reg [INT_TLP_SEG_COUNT-1:0] cq_eop;
reg cq_frame_reg = 1'b0, cq_frame_next;

reg [TLP_DATA_WIDTH-1:0] cq_data_int_reg = 0, cq_data_int_next;
reg [TLP_STRB_WIDTH-1:0] cq_strb_int_reg = 0, cq_strb_int_next;
reg [INT_TLP_SEG_COUNT*8-1:0] cq_hdr_be_int_reg = 0, cq_hdr_be_int_next;
reg [INT_TLP_SEG_COUNT-1:0] cq_valid_int_reg = 0, cq_valid_int_next;
reg [TLP_STRB_WIDTH-1:0] cq_strb_eop_int_reg = 0, cq_strb_eop_int_next;
reg [INT_TLP_SEG_COUNT-1:0] cq_sop_int_reg = 0, cq_sop_int_next;
reg [INT_TLP_SEG_COUNT-1:0] cq_eop_int_reg = 0, cq_eop_int_next;

wire [TLP_DATA_WIDTH*2-1:0] cq_data_full = {cq_data, cq_data_int_reg};
wire [TLP_STRB_WIDTH*2-1:0] cq_strb_full = {cq_strb, cq_strb_int_reg};
wire [INT_TLP_SEG_COUNT*8*2-1:0] cq_hdr_be_full = {cq_hdr_be, cq_hdr_be_int_reg};
wire [INT_TLP_SEG_COUNT*2-1:0] cq_valid_full = {cq_valid, cq_valid_int_reg};
wire [TLP_STRB_WIDTH*2-1:0] cq_strb_eop_full = {cq_strb_eop, cq_strb_eop_int_reg};
wire [INT_TLP_SEG_COUNT*2-1:0] cq_sop_full = {cq_sop, cq_sop_int_reg};
wire [INT_TLP_SEG_COUNT*2-1:0] cq_eop_full = {cq_eop, cq_eop_int_reg};

reg [INT_TLP_SEG_COUNT*128-1:0] tlp_hdr;
reg [INT_TLP_SEG_COUNT*3-1:0] tlp_bar_id;
reg [INT_TLP_SEG_COUNT*8-1:0] tlp_func_num;

assign s_axis_cq_tready = fifo_tlp_ready;

pcie_tlp_fifo #(
    .DEPTH((1024/4)*2),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(1),
    .IN_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(TLP_SEG_COUNT)
)
pcie_tlp_fifo_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(rx_req_tlp_data_reg),
    .in_tlp_strb(rx_req_tlp_strb_reg),
    .in_tlp_hdr(rx_req_tlp_hdr_reg),
    .in_tlp_seq(0),
    .in_tlp_bar_id(rx_req_tlp_bar_id_reg),
    .in_tlp_func_num(rx_req_tlp_func_num_reg),
    .in_tlp_error(0),
    .in_tlp_valid(rx_req_tlp_valid_reg),
    .in_tlp_sop(rx_req_tlp_sop_reg),
    .in_tlp_eop(rx_req_tlp_eop_reg),
    .in_tlp_ready(fifo_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(rx_req_tlp_data),
    .out_tlp_strb(rx_req_tlp_strb),
    .out_tlp_hdr(rx_req_tlp_hdr),
    .out_tlp_seq(),
    .out_tlp_bar_id(rx_req_tlp_bar_id),
    .out_tlp_func_num(rx_req_tlp_func_num),
    .out_tlp_error(),
    .out_tlp_valid(rx_req_tlp_valid),
    .out_tlp_sop(rx_req_tlp_sop),
    .out_tlp_eop(rx_req_tlp_eop),
    .out_tlp_ready(rx_req_tlp_ready),

    /*
     * Status
     */
    .half_full(),
    .watermark()
);

integer seg, lane;
reg valid;

always @* begin
    rx_req_tlp_data_next = rx_req_tlp_data_reg;
    rx_req_tlp_strb_next = rx_req_tlp_strb_reg;
    rx_req_tlp_hdr_next = rx_req_tlp_hdr_reg;
    rx_req_tlp_bar_id_next = rx_req_tlp_bar_id_reg;
    rx_req_tlp_func_num_next = rx_req_tlp_func_num_reg;
    rx_req_tlp_valid_next = fifo_tlp_ready ? 0 : rx_req_tlp_valid_reg;
    rx_req_tlp_sop_next = rx_req_tlp_sop_reg;
    rx_req_tlp_eop_next = rx_req_tlp_eop_reg;
    tlp_frame_next = tlp_frame_reg;

    cq_frame_next = cq_frame_reg;

    cq_data_int_next = cq_data_int_reg;
    cq_strb_int_next = cq_strb_int_reg;
    cq_hdr_be_int_next = cq_hdr_be_int_reg;
    cq_valid_int_next = cq_valid_int_reg;
    cq_strb_eop_int_next = cq_strb_eop_int_reg;
    cq_sop_int_next = cq_sop_int_reg;
    cq_eop_int_next = cq_eop_int_reg;

    // decode framing
    if (CQ_STRADDLE && AXIS_PCIE_DATA_WIDTH >= 512) begin
        cq_data = s_axis_cq_tdata;
        cq_strb = 0;
        cq_hdr_be = {s_axis_cq_tuser[15:12], s_axis_cq_tuser[7:4], s_axis_cq_tuser[11:8], s_axis_cq_tuser[3:0]};
        cq_valid = 0;
        cq_strb_sop = 0;
        cq_strb_eop = 0;
        cq_sop = 0;
        cq_eop = 0;
        for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
            if (s_axis_cq_tuser[80+seg]) begin
                cq_strb_sop[s_axis_cq_tuser[82+seg*2 +: 2]*4] = 1'b1;
            end
            if (s_axis_cq_tuser[86+seg]) begin
                cq_strb_eop[s_axis_cq_tuser[88+seg*4 +: 4]] = 1'b1;
            end
        end
        valid = 1;
        for (lane = 0; lane < TLP_STRB_WIDTH; lane = lane + 1) begin
            if (cq_strb_sop[lane]) begin
                valid = 1;
                cq_sop[lane/INT_TLP_SEG_STRB_WIDTH] = 1'b1;
            end
            if (valid) begin
                cq_strb[lane] = 1'b1;
                cq_valid[lane/INT_TLP_SEG_STRB_WIDTH] = s_axis_cq_tvalid;
            end
            if (cq_strb_eop[lane]) begin
                valid = 0;
                cq_eop[lane/INT_TLP_SEG_STRB_WIDTH] = 1'b1;
            end
        end
    end else begin
        cq_data = s_axis_cq_tdata;
        cq_strb = s_axis_cq_tvalid ? s_axis_cq_tkeep : 0;
        if (AXIS_PCIE_DATA_WIDTH >= 512) begin
            cq_hdr_be = {s_axis_cq_tuser[11:8], s_axis_cq_tuser[3:0]};
        end else begin
            cq_hdr_be = s_axis_cq_tuser[7:0];
        end
        cq_valid = s_axis_cq_tvalid;
        cq_sop = !cq_frame_reg;
        cq_eop = s_axis_cq_tlast;
        cq_strb_sop = cq_sop;
        cq_strb_eop = 0;
        for (lane = 0; lane < TLP_STRB_WIDTH; lane = lane + 1) begin
            if (cq_strb[lane]) begin
                cq_strb_eop = (cq_eop) << lane;
            end
        end
        if (s_axis_cq_tready && s_axis_cq_tvalid) begin
            cq_frame_next = !s_axis_cq_tlast;
        end
    end

    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        // parse header
        // DW 0
        case (cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+75 +: 4])
            REQ_MEM_READ: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b00000}; // type
            end
            REQ_MEM_WRITE: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b00000}; // type
            end
            REQ_IO_READ: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b00010}; // type
            end
            REQ_IO_WRITE: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b00010}; // type
            end
            REQ_MEM_FETCH_ADD: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b01100}; // type
            end
            REQ_MEM_SWAP: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b01101}; // type
            end
            REQ_MEM_CAS: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b01110}; // type
            end
            REQ_MEM_READ_LOCKED: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b00001}; // type
            end
            REQ_MSG: begin
                if (cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+64 +: 11]) begin
                    tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                end else begin
                    tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW; // fmt
                end
                tlp_hdr[128*seg+120 +: 5] = {2'b10, cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+112 +: 3]}; // type
            end
            REQ_MSG_VENDOR: begin
                if (cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+64 +: 11]) begin
                    tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                end else begin
                    tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW; // fmt
                end
                tlp_hdr[128*seg+120 +: 5] = {2'b10, cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+112 +: 3]}; // type
            end
            REQ_MSG_ATS: begin
                if (cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+64 +: 11]) begin
                    tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW_DATA; // fmt
                end else begin
                    tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW; // fmt
                end
                tlp_hdr[128*seg+120 +: 5] = {2'b10, cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+112 +: 3]}; // type
            end
            default: begin
                tlp_hdr[128*seg+125 +: 3] = TLP_FMT_4DW; // fmt
                tlp_hdr[128*seg+120 +: 5] = {5'b00000}; // type
            end
        endcase
        tlp_hdr[128*seg+119] = 1'b0; // T9
        tlp_hdr[128*seg+116 +: 3] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+121 +: 3]; // TC
        tlp_hdr[128*seg+115] = 1'b0; // T8
        tlp_hdr[128*seg+114] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+126]; // attr
        tlp_hdr[128*seg+113] = 1'b0; // LN
        tlp_hdr[128*seg+112] = 1'b0; // TH
        tlp_hdr[128*seg+111] = 1'b0; // TD
        tlp_hdr[128*seg+110] = 1'b0; // EP
        tlp_hdr[128*seg+108 +: 2] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+124 +: 2]; // attr
        tlp_hdr[128*seg+106 +: 2] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+0 +: 2]; // AT
        tlp_hdr[128*seg+96 +: 10] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+64 +: 11]; // length
        // DW 1
        tlp_hdr[128*seg+80 +: 16] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+80 +: 16]; // requester ID
        tlp_hdr[128*seg+72 +: 8] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+96 +: 8]; // tag
        tlp_hdr[128*seg+68 +: 4] = cq_hdr_be_full[8*seg+4 +: 4]; // last BE
        tlp_hdr[128*seg+64 +: 4] = cq_hdr_be_full[8*seg+0 +: 4]; // first BE
        // DW 2+3
        tlp_hdr[128*seg+2 +: 62] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+2 +: 62]; // address
        tlp_hdr[128*seg+0 +: 2] = 2'b00; // PH

        tlp_bar_id[3*seg +: 3] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+112 +: 3];
        tlp_func_num[8*seg +: 8] = cq_data_full[INT_TLP_SEG_DATA_WIDTH*seg+104 +: 8];
    end

    if (fifo_tlp_ready) begin
        rx_req_tlp_strb_next = 0;
        rx_req_tlp_valid_next = 0;
        rx_req_tlp_sop_next = 0;
        rx_req_tlp_eop_next = 0;
        if (TLP_DATA_WIDTH == 64) begin
            if (cq_valid_full[0]) begin
                rx_req_tlp_data_next = cq_data_full >> 64;
                rx_req_tlp_strb_next = cq_strb_full >> 2;
                if (cq_sop_full[0]) begin
                    tlp_frame_next = 1'b0;
                    rx_req_tlp_hdr_next = tlp_hdr;
                    rx_req_tlp_bar_id_next = tlp_bar_id;
                    rx_req_tlp_func_num_next = tlp_func_num;
                    if (cq_eop_full[0]) begin
                        cq_valid_int_next[0] = 1'b0;
                    end else if (cq_valid_full[1]) begin
                        cq_valid_int_next[0] = 1'b0;
                        if (cq_eop_full[1]) begin
                            rx_req_tlp_strb_next = 0;
                            rx_req_tlp_valid_next = 1'b1;
                            rx_req_tlp_sop_next = 1'b1;
                            rx_req_tlp_eop_next = 1'b1;
                        end
                    end
                end else begin
                    rx_req_tlp_sop_next = !tlp_frame_reg;
                    rx_req_tlp_eop_next = 1'b0;
                    if (cq_eop_full[0]) begin
                        cq_valid_int_next[0] = 1'b0;
                    end else if (cq_valid_full[1]) begin
                        rx_req_tlp_valid_next = 1'b1;
                        cq_valid_int_next[0] = 1'b0;
                        tlp_frame_next = 1'b1;
                        rx_req_tlp_eop_next = cq_eop_full[1];
                    end
                end
            end
        end else begin
            for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
                if (cq_valid_full[seg]) begin
                    rx_req_tlp_data_next[INT_TLP_SEG_DATA_WIDTH*seg +: INT_TLP_SEG_DATA_WIDTH] = cq_data_full >> (128 + INT_TLP_SEG_DATA_WIDTH*seg);
                    if (cq_sop_full[seg]) begin
                        rx_req_tlp_hdr_next[TLP_HDR_WIDTH*seg +: TLP_HDR_WIDTH] = tlp_hdr[128*seg +: 128];
                        rx_req_tlp_bar_id_next[3*seg +: 3] = tlp_bar_id[3*seg +: 3];
                        rx_req_tlp_func_num_next[8*seg +: 8] = tlp_func_num[8*seg +: 8];
                    end
                    rx_req_tlp_sop_next[seg] = cq_sop_full[seg];
                    if (cq_eop_full[seg]) begin
                        rx_req_tlp_strb_next[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] = cq_strb_full[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] >> 4;
                        if (cq_sop_full[seg] || cq_strb_eop_full[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] >> 4) begin
                            rx_req_tlp_eop_next[seg] = 1'b1;
                            rx_req_tlp_valid_next[seg] = 1'b1;
                        end
                        cq_valid_int_next[seg] = 1'b0;
                    end else begin
                        rx_req_tlp_strb_next[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] = cq_strb_full >> (4 + INT_TLP_SEG_STRB_WIDTH*seg);
                        if (cq_valid_full[seg+1]) begin
                            rx_req_tlp_eop_next[seg] = cq_strb_eop_full[INT_TLP_SEG_STRB_WIDTH*(seg+1) +: 4] != 0;
                            rx_req_tlp_valid_next[seg] = 1'b1;
                            cq_valid_int_next[seg] = 1'b0;
                        end
                    end
                end
            end
        end
    end

    if (s_axis_cq_tready && s_axis_cq_tvalid) begin
        cq_data_int_next = cq_data;
        cq_strb_int_next = cq_strb;
        cq_hdr_be_int_next = cq_hdr_be;
        cq_valid_int_next = cq_valid;
        cq_strb_eop_int_next = cq_strb_eop;
        cq_sop_int_next = cq_sop;
        cq_eop_int_next = cq_eop;
    end
end

always @(posedge clk) begin
    rx_req_tlp_data_reg <= rx_req_tlp_data_next;
    rx_req_tlp_strb_reg <= rx_req_tlp_strb_next;
    rx_req_tlp_hdr_reg <= rx_req_tlp_hdr_next;
    rx_req_tlp_bar_id_reg <= rx_req_tlp_bar_id_next;
    rx_req_tlp_func_num_reg <= rx_req_tlp_func_num_next;
    rx_req_tlp_valid_reg <= rx_req_tlp_valid_next;
    rx_req_tlp_sop_reg <= rx_req_tlp_sop_next;
    rx_req_tlp_eop_reg <= rx_req_tlp_eop_next;
    tlp_frame_reg <= tlp_frame_next;

    cq_frame_reg <= cq_frame_next;

    cq_data_int_reg <= cq_data_int_next;
    cq_strb_int_reg <= cq_strb_int_next;
    cq_hdr_be_int_reg <= cq_hdr_be_int_next;
    cq_valid_int_reg <= cq_valid_int_next;
    cq_strb_eop_int_reg <= cq_strb_eop_int_next;
    cq_sop_int_reg <= cq_sop_int_next;
    cq_eop_int_reg <= cq_eop_int_next;

    if (rst) begin
        rx_req_tlp_valid_reg <= 0;

        cq_frame_reg <= 1'b0;
        cq_valid_int_reg <= 0;
    end
end

endmodule

`resetall
