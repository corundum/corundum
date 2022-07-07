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
 * Xilinx UltraScale PCIe interface adapter (Requester Completion)
 */
module pcie_us_if_rc #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream RC tuser signal width
    parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161,
    // RC interface TLP straddling
    parameter RC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 256,
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
    input  wire                                    clk,
    input  wire                                    rst,

    /*
     * AXI input (RC)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]         s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]         s_axis_rc_tkeep,
    input  wire                                    s_axis_rc_tvalid,
    output wire                                    s_axis_rc_tready,
    input  wire                                    s_axis_rc_tlast,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0]      s_axis_rc_tuser,

    /*
     * TLP output (completion to DMA)
     */
    output wire [TLP_DATA_WIDTH-1:0]               rx_cpl_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]               rx_cpl_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  rx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT*4-1:0]              rx_cpl_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                rx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                rx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                rx_cpl_tlp_eop,
    input  wire                                    rx_cpl_tlp_ready
);

parameter INT_TLP_SEG_COUNT = (RC_STRADDLE && AXIS_PCIE_DATA_WIDTH >= 256) ? (AXIS_PCIE_DATA_WIDTH == 512 ? 4 : 2) : 1;
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
        if (AXIS_PCIE_RC_USER_WIDTH != 161) begin
            $error("Error: PCIe RC tuser width must be 161 (instance %m)");
            $finish;
        end
    end else begin
        if (AXIS_PCIE_RC_USER_WIDTH != 75) begin
            $error("Error: PCIe RC tuser width must be 75 (instance %m)");
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

localparam [2:0]
    CPL_STATUS_SC  = 3'b000, // successful completion
    CPL_STATUS_UR  = 3'b001, // unsupported request
    CPL_STATUS_CRS = 3'b010, // configuration request retry status
    CPL_STATUS_CA  = 3'b100; // completer abort

localparam [3:0]
    RC_ERROR_NORMAL_TERMINATION = 4'b0000,
    RC_ERROR_POISONED = 4'b0001,
    RC_ERROR_BAD_STATUS = 4'b0010,
    RC_ERROR_INVALID_LENGTH = 4'b0011,
    RC_ERROR_MISMATCH = 4'b0100,
    RC_ERROR_INVALID_ADDRESS = 4'b0101,
    RC_ERROR_INVALID_TAG = 4'b0110,
    RC_ERROR_TIMEOUT = 4'b1001,
    RC_ERROR_FLR = 4'b1000;

localparam [3:0]
    PCIE_ERROR_NONE = 4'd0,
    PCIE_ERROR_POISONED = 4'd1,
    PCIE_ERROR_BAD_STATUS = 4'd2,
    PCIE_ERROR_MISMATCH = 4'd3,
    PCIE_ERROR_INVALID_LEN = 4'd4,
    PCIE_ERROR_INVALID_ADDR = 4'd5,
    PCIE_ERROR_INVALID_TAG = 4'd6,
    PCIE_ERROR_FLR = 4'd8,
    PCIE_ERROR_TIMEOUT = 4'd15;

reg [TLP_DATA_WIDTH-1:0] rx_cpl_tlp_data_reg = 0, rx_cpl_tlp_data_next;
reg [TLP_STRB_WIDTH-1:0] rx_cpl_tlp_strb_reg = 0, rx_cpl_tlp_strb_next;
reg [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] rx_cpl_tlp_hdr_reg = 0, rx_cpl_tlp_hdr_next;
reg [INT_TLP_SEG_COUNT*4-1:0] rx_cpl_tlp_error_reg = 0, rx_cpl_tlp_error_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_cpl_tlp_valid_reg = 0, rx_cpl_tlp_valid_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_cpl_tlp_sop_reg = 0, rx_cpl_tlp_sop_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_cpl_tlp_eop_reg = 0, rx_cpl_tlp_eop_next;
reg tlp_frame_reg = 0, tlp_frame_next;

wire fifo_tlp_ready;

reg tlp_input_frame_reg = 1'b0, tlp_input_frame_next;

reg [TLP_DATA_WIDTH-1:0] rc_data;
reg [TLP_STRB_WIDTH-1:0] rc_strb;
reg [INT_TLP_SEG_COUNT-1:0] rc_valid;
reg [TLP_STRB_WIDTH-1:0] rc_strb_sop;
reg [TLP_STRB_WIDTH-1:0] rc_strb_eop;
reg [INT_TLP_SEG_COUNT-1:0] rc_sop;
reg [INT_TLP_SEG_COUNT-1:0] rc_eop;
reg rc_frame_reg = 1'b0, rc_frame_next;

reg [TLP_DATA_WIDTH-1:0] rc_data_int_reg = 0, rc_data_int_next;
reg [TLP_STRB_WIDTH-1:0] rc_strb_int_reg = 0, rc_strb_int_next;
reg [INT_TLP_SEG_COUNT-1:0] rc_valid_int_reg = 0, rc_valid_int_next;
reg [TLP_STRB_WIDTH-1:0] rc_strb_eop_int_reg = 0, rc_strb_eop_int_next;
reg [INT_TLP_SEG_COUNT-1:0] rc_sop_int_reg = 0, rc_sop_int_next;
reg [INT_TLP_SEG_COUNT-1:0] rc_eop_int_reg = 0, rc_eop_int_next;

wire [TLP_DATA_WIDTH*2-1:0] rc_data_full = {rc_data, rc_data_int_reg};
wire [TLP_STRB_WIDTH*2-1:0] rc_strb_full = {rc_strb, rc_strb_int_reg};
wire [INT_TLP_SEG_COUNT*2-1:0] rc_valid_full = {rc_valid, rc_valid_int_reg};
wire [TLP_STRB_WIDTH*2-1:0] rc_strb_eop_full = {rc_strb_eop, rc_strb_eop_int_reg};
wire [INT_TLP_SEG_COUNT*2-1:0] rc_sop_full = {rc_sop, rc_sop_int_reg};
wire [INT_TLP_SEG_COUNT*2-1:0] rc_eop_full = {rc_eop, rc_eop_int_reg};

reg [INT_TLP_SEG_COUNT*128-1:0] tlp_hdr;
reg [INT_TLP_SEG_COUNT*4-1:0] tlp_error;

assign s_axis_rc_tready = fifo_tlp_ready;

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
    .in_tlp_data(rx_cpl_tlp_data_reg),
    .in_tlp_strb(rx_cpl_tlp_strb_reg),
    .in_tlp_hdr(rx_cpl_tlp_hdr_reg),
    .in_tlp_seq(0),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(rx_cpl_tlp_error_reg),
    .in_tlp_valid(rx_cpl_tlp_valid_reg),
    .in_tlp_sop(rx_cpl_tlp_sop_reg),
    .in_tlp_eop(rx_cpl_tlp_eop_reg),
    .in_tlp_ready(fifo_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(rx_cpl_tlp_data),
    .out_tlp_strb(rx_cpl_tlp_strb),
    .out_tlp_hdr(rx_cpl_tlp_hdr),
    .out_tlp_seq(),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(rx_cpl_tlp_error),
    .out_tlp_valid(rx_cpl_tlp_valid),
    .out_tlp_sop(rx_cpl_tlp_sop),
    .out_tlp_eop(rx_cpl_tlp_eop),
    .out_tlp_ready(rx_cpl_tlp_ready),

    /*
     * Status
     */
    .half_full(),
    .watermark()
);

integer seg, lane;
reg valid;

always @* begin
    rx_cpl_tlp_data_next = rx_cpl_tlp_data_reg;
    rx_cpl_tlp_strb_next = rx_cpl_tlp_strb_reg;
    rx_cpl_tlp_hdr_next = rx_cpl_tlp_hdr_reg;
    rx_cpl_tlp_error_next = rx_cpl_tlp_error_reg;
    rx_cpl_tlp_valid_next = fifo_tlp_ready ? 0 : rx_cpl_tlp_valid_reg;
    rx_cpl_tlp_sop_next = rx_cpl_tlp_sop_reg;
    rx_cpl_tlp_eop_next = rx_cpl_tlp_eop_reg;
    tlp_frame_next = tlp_frame_reg;

    rc_frame_next = rc_frame_reg;

    rc_data_int_next = rc_data_int_reg;
    rc_strb_int_next = rc_strb_int_reg;
    rc_valid_int_next = rc_valid_int_reg;
    rc_strb_eop_int_next = rc_strb_eop_int_reg;
    rc_sop_int_next = rc_sop_int_reg;
    rc_eop_int_next = rc_eop_int_reg;

    // decode framing
    if (RC_STRADDLE && AXIS_PCIE_DATA_WIDTH >= 256) begin
        rc_data = s_axis_rc_tdata;
        rc_strb = 0;
        rc_valid = 0;
        rc_strb_sop = 0;
        rc_strb_eop = 0;
        rc_sop = 0;
        rc_eop = 0;
        if (AXIS_PCIE_DATA_WIDTH == 256) begin
            if (INT_TLP_SEG_COUNT == 1) begin
                if (s_axis_rc_tuser[32]) begin
                    rc_strb_sop[0] = 1'b1;
                end
            end else begin
                if (s_axis_rc_tuser[32]) begin
                    if (rc_frame_reg) begin
                        rc_strb_sop[4] = 1'b1;
                    end else begin
                        rc_strb_sop[0] = 1'b1;
                    end
                end
                if (s_axis_rc_tuser[33]) begin
                    rc_strb_sop[4] = 1'b1;
                end
            end
            for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
                if (s_axis_rc_tuser[34+seg*4]) begin
                    rc_strb_eop[s_axis_rc_tuser[35+seg*4 +: 3]] = 1'b1;
                end
            end
        end else if (AXIS_PCIE_DATA_WIDTH == 512) begin
            for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
                if (s_axis_rc_tuser[64+seg]) begin
                    rc_strb_sop[s_axis_rc_tuser[68+seg*2 +: 2]*4] = 1'b1;
                end
                if (s_axis_rc_tuser[76+seg]) begin
                    rc_strb_eop[s_axis_rc_tuser[80+seg*4 +: 4]] = 1'b1;
                end
            end
        end
        valid = 1;
        for (lane = 0; lane < TLP_STRB_WIDTH; lane = lane + 1) begin
            if (rc_strb_sop[lane]) begin
                valid = 1;
                rc_sop[lane/INT_TLP_SEG_STRB_WIDTH] = 1'b1;
            end
            if (valid) begin
                rc_strb[lane] = 1'b1;
                rc_valid[lane/INT_TLP_SEG_STRB_WIDTH] = s_axis_rc_tvalid;
            end
            if (rc_strb_eop[lane]) begin
                valid = 0;
                rc_eop[lane/INT_TLP_SEG_STRB_WIDTH] = 1'b1;
            end
        end
        if (s_axis_rc_tready && s_axis_rc_tvalid) begin
            rc_frame_next = valid;
        end
    end else begin
        rc_data = s_axis_rc_tdata;
        rc_strb = s_axis_rc_tvalid ? s_axis_rc_tkeep : 0;
        rc_valid = s_axis_rc_tvalid;
        rc_sop = !rc_frame_reg;
        rc_eop = s_axis_rc_tlast;
        rc_strb_sop = rc_sop;
        rc_strb_eop = 0;
        for (lane = 0; lane < TLP_STRB_WIDTH; lane = lane + 1) begin
            if (rc_strb[lane]) begin
                rc_strb_eop = (rc_eop) << lane;
            end
        end
        if (s_axis_rc_tready && s_axis_rc_tvalid) begin
            rc_frame_next = !s_axis_rc_tlast;
        end
    end

    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        // parse header
        // DW 0
        if (rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+32 +: 11] != 0) begin
            tlp_hdr[128*seg+125 +: 3] = TLP_FMT_3DW_DATA; // fmt - 3DW with data
        end else begin
            tlp_hdr[128*seg+125 +: 3] = TLP_FMT_3DW; // fmt - 3DW without data
        end
        tlp_hdr[128*seg+120 +: 5] = {4'b0101, rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+29]}; // type - completion
        tlp_hdr[128*seg+119] = 1'b0; // T9
        tlp_hdr[128*seg+116 +: 3] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+89 +: 3]; // TC
        tlp_hdr[128*seg+115] = 1'b0; // T8
        tlp_hdr[128*seg+114] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+94]; // attr
        tlp_hdr[128*seg+113] = 1'b0; // LN
        tlp_hdr[128*seg+112] = 1'b0; // TH
        tlp_hdr[128*seg+111] = 1'b0; // TD
        tlp_hdr[128*seg+110] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+46]; // EP
        tlp_hdr[128*seg+108 +: 2] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+92 +: 2]; // attr
        tlp_hdr[128*seg+106 +: 2] = 2'b00; // AT
        tlp_hdr[128*seg+96 +: 10] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+32 +: 11]; // length
        // DW 1
        tlp_hdr[128*seg+80 +: 16] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+72 +: 16]; // completer ID
        tlp_hdr[128*seg+77 +: 3] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+43 +: 3]; // completion status
        tlp_hdr[128*seg+76] = 1'b0; // BCM
        tlp_hdr[128*seg+64 +: 12] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+16 +: 13]; // byte count
        // DW 2
        tlp_hdr[128*seg+48 +: 16] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+48 +: 16]; // requester ID
        tlp_hdr[128*seg+40 +: 8] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+64 +: 8]; // tag
        tlp_hdr[128*seg+39] = 1'b0;
        tlp_hdr[128*seg+32 +: 7] = rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+0 +: 7]; // lower address
        // DW 3
        tlp_hdr[128*seg+0 +: 32] = 32'd0;

        // error code
        case (rc_data_full[INT_TLP_SEG_DATA_WIDTH*seg+12 +: 4])
            RC_ERROR_NORMAL_TERMINATION: tlp_error[4*seg +: 4] = PCIE_ERROR_NONE;
            RC_ERROR_POISONED:           tlp_error[4*seg +: 4] = PCIE_ERROR_POISONED;
            RC_ERROR_BAD_STATUS:         tlp_error[4*seg +: 4] = PCIE_ERROR_BAD_STATUS;
            RC_ERROR_INVALID_LENGTH:     tlp_error[4*seg +: 4] = PCIE_ERROR_INVALID_LEN;
            RC_ERROR_MISMATCH:           tlp_error[4*seg +: 4] = PCIE_ERROR_MISMATCH;
            RC_ERROR_INVALID_ADDRESS:    tlp_error[4*seg +: 4] = PCIE_ERROR_INVALID_ADDR;
            RC_ERROR_INVALID_TAG:        tlp_error[4*seg +: 4] = PCIE_ERROR_INVALID_TAG;
            RC_ERROR_FLR:                tlp_error[4*seg +: 4] = PCIE_ERROR_FLR;
            RC_ERROR_TIMEOUT:            tlp_error[4*seg +: 4] = PCIE_ERROR_TIMEOUT;
            default:                     tlp_error[4*seg +: 4] = PCIE_ERROR_NONE;
        endcase
    end

    if (fifo_tlp_ready) begin
        rx_cpl_tlp_strb_next = 0;
        rx_cpl_tlp_valid_next = 0;
        rx_cpl_tlp_sop_next = 0;
        rx_cpl_tlp_eop_next = 0;
        if (TLP_DATA_WIDTH == 64) begin
            if (rc_valid_full[0]) begin
                rx_cpl_tlp_data_next = rc_data_full >> 32;
                rx_cpl_tlp_strb_next = rc_strb_full >> 1;
                if (rc_sop_full[0]) begin
                    tlp_frame_next = 1'b0;
                    rx_cpl_tlp_hdr_next = tlp_hdr;
                    rx_cpl_tlp_error_next = tlp_error;
                    if (rc_eop_full[0]) begin
                        rc_valid_int_next[0] = 1'b0;
                    end else if (rc_valid_full[1]) begin
                        rc_valid_int_next[0] = 1'b0;
                    end
                end else begin
                    rx_cpl_tlp_sop_next = !tlp_frame_reg;
                    rx_cpl_tlp_eop_next = 1'b0;
                    if (rc_eop_full[0]) begin
                        rx_cpl_tlp_strb_next = rc_strb_full[1];
                        rx_cpl_tlp_valid_next = 1'b1;
                        rc_valid_int_next[0] = 1'b0;
                        rx_cpl_tlp_eop_next = 1'b1;
                    end else if (rc_valid_full[1]) begin
                        rx_cpl_tlp_valid_next = 1'b1;
                        rc_valid_int_next[0] = 1'b0;
                        tlp_frame_next = 1'b1;
                    end
                end
            end
        end else begin
            for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
                if (rc_valid_full[seg]) begin
                    rx_cpl_tlp_data_next[INT_TLP_SEG_DATA_WIDTH*seg +: INT_TLP_SEG_DATA_WIDTH] = rc_data_full >> (96 + INT_TLP_SEG_DATA_WIDTH*seg);
                    if (rc_sop_full[seg]) begin
                        rx_cpl_tlp_hdr_next[TLP_HDR_WIDTH*seg +: TLP_HDR_WIDTH] = tlp_hdr[128*seg +: 128];
                        rx_cpl_tlp_error_next[4*seg +: 4] = tlp_error[4*seg +: 4];
                    end
                    rx_cpl_tlp_sop_next[seg] = rc_sop_full[seg];
                    if (rc_eop_full[seg]) begin
                        rx_cpl_tlp_strb_next[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] = rc_strb_full[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] >> 3;
                        if (rc_sop_full[seg] || rc_strb_eop_full[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] >> 3) begin
                            rx_cpl_tlp_eop_next[seg] = 1'b1;
                            rx_cpl_tlp_valid_next[seg] = 1'b1;
                        end
                        rc_valid_int_next[seg] = 1'b0;
                    end else begin
                        rx_cpl_tlp_strb_next[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] = rc_strb_full >> (3 + INT_TLP_SEG_STRB_WIDTH*seg);
                        if (rc_valid_full[seg+1]) begin
                            rx_cpl_tlp_eop_next[seg] = (rc_strb_eop_full[INT_TLP_SEG_STRB_WIDTH*(seg+1) +: INT_TLP_SEG_STRB_WIDTH] & 3'h7) != 0;
                            rx_cpl_tlp_valid_next[seg] = 1'b1;
                            rc_valid_int_next[seg] = 1'b0;
                        end
                    end
                end
            end
        end
    end

    if (s_axis_rc_tready && s_axis_rc_tvalid) begin
        rc_data_int_next = rc_data;
        rc_strb_int_next = rc_strb;
        rc_valid_int_next = rc_valid;
        rc_strb_eop_int_next = rc_strb_eop;
        rc_sop_int_next = rc_sop;
        rc_eop_int_next = rc_eop;
    end
end

always @(posedge clk) begin
    rx_cpl_tlp_data_reg <= rx_cpl_tlp_data_next;
    rx_cpl_tlp_strb_reg <= rx_cpl_tlp_strb_next;
    rx_cpl_tlp_hdr_reg <= rx_cpl_tlp_hdr_next;
    rx_cpl_tlp_error_reg <= rx_cpl_tlp_error_next;
    rx_cpl_tlp_valid_reg <= rx_cpl_tlp_valid_next;
    rx_cpl_tlp_sop_reg <= rx_cpl_tlp_sop_next;
    rx_cpl_tlp_eop_reg <= rx_cpl_tlp_eop_next;
    tlp_frame_reg <= tlp_frame_next;

    rc_frame_reg <= rc_frame_next;

    rc_data_int_reg <= rc_data_int_next;
    rc_strb_int_reg <= rc_strb_int_next;
    rc_valid_int_reg <= rc_valid_int_next;
    rc_strb_eop_int_reg <= rc_strb_eop_int_next;
    rc_sop_int_reg <= rc_sop_int_next;
    rc_eop_int_reg <= rc_eop_int_next;

    if (rst) begin
        rx_cpl_tlp_valid_reg <= 0;

        rc_frame_reg <= 1'b0;
        rc_valid_int_reg <= 0;
    end
end

endmodule

`resetall
