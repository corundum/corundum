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
    // PCIe AXI stream RQ tuser signal width
    parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 60 : 137,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH/TLP_SEG_COUNT,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI input (RC)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]              s_axis_rc_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]              s_axis_rc_tkeep,
    input  wire                                         s_axis_rc_tvalid,
    output wire                                         s_axis_rc_tready,
    input  wire                                         s_axis_rc_tlast,
    input  wire [AXIS_PCIE_RC_USER_WIDTH-1:0]           s_axis_rc_tuser,

    /*
     * TLP output (completion to DMA)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_cpl_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT*4-1:0]                   rx_cpl_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     rx_cpl_tlp_eop,
    input  wire                                         rx_cpl_tlp_ready
);

parameter TLP_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH;
parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

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

    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_SEG_HDR_WIDTH != 128) begin
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

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0] rx_cpl_tlp_data_reg = 0, rx_cpl_tlp_data_next;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0] rx_cpl_tlp_hdr_reg = 0, rx_cpl_tlp_hdr_next;
reg [TLP_SEG_COUNT*4-1:0] rx_cpl_tlp_error_reg = 0, rx_cpl_tlp_error_next;
reg [TLP_SEG_COUNT-1:0] rx_cpl_tlp_valid_reg = 0, rx_cpl_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0] rx_cpl_tlp_sop_reg = 0, rx_cpl_tlp_sop_next;
reg [TLP_SEG_COUNT-1:0] rx_cpl_tlp_eop_reg = 0, rx_cpl_tlp_eop_next;

assign rx_cpl_tlp_data = rx_cpl_tlp_data_reg;
assign rx_cpl_tlp_hdr = rx_cpl_tlp_hdr_reg;
assign rx_cpl_tlp_error = rx_cpl_tlp_error_reg;
assign rx_cpl_tlp_valid = rx_cpl_tlp_valid_reg;
assign rx_cpl_tlp_sop = rx_cpl_tlp_sop_reg;
assign rx_cpl_tlp_eop = rx_cpl_tlp_eop_reg;

localparam [1:0]
    TLP_INPUT_STATE_IDLE = 2'd0,
    TLP_INPUT_STATE_HEADER = 2'd1,
    TLP_INPUT_STATE_PAYLOAD = 2'd2;

reg [1:0] tlp_input_state_reg = TLP_INPUT_STATE_IDLE, tlp_input_state_next;

reg s_axis_rc_tready_cmb;

reg tlp_input_frame_reg = 1'b0, tlp_input_frame_next;

reg [AXIS_PCIE_DATA_WIDTH-1:0] rc_tdata_int_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}}, rc_tdata_int_next;
reg rc_tvalid_int_reg = 1'b0, rc_tvalid_int_next;
reg rc_tlast_int_reg = 1'b0, rc_tlast_int_next;

wire [AXIS_PCIE_DATA_WIDTH*2-1:0] rc_tdata = {s_axis_rc_tdata, rc_tdata_int_reg};

assign s_axis_rc_tready = s_axis_rc_tready_cmb;

always @* begin
    tlp_input_state_next = TLP_INPUT_STATE_IDLE;

    rx_cpl_tlp_data_next = rx_cpl_tlp_data_reg;
    rx_cpl_tlp_hdr_next = rx_cpl_tlp_hdr_reg;
    rx_cpl_tlp_error_next = rx_cpl_tlp_error_reg;
    rx_cpl_tlp_valid_next = rx_cpl_tlp_valid_reg && !rx_cpl_tlp_ready;
    rx_cpl_tlp_sop_next = rx_cpl_tlp_sop_reg;
    rx_cpl_tlp_eop_next = rx_cpl_tlp_eop_reg;

    s_axis_rc_tready_cmb = rx_cpl_tlp_ready;

    tlp_input_frame_next = tlp_input_frame_reg;

    rc_tdata_int_next = rc_tdata_int_reg;
    rc_tvalid_int_next = rc_tvalid_int_reg;
    rc_tlast_int_next = rc_tlast_int_reg;

    case (tlp_input_state_reg)
        TLP_INPUT_STATE_IDLE: begin
            s_axis_rc_tready_cmb = rx_cpl_tlp_ready;

            if (rc_tvalid_int_reg && rx_cpl_tlp_ready) begin
                // DW 0
                if (rc_tdata[42:32] != 0) begin
                    rx_cpl_tlp_hdr_next[127:125] = TLP_FMT_3DW_DATA; // fmt - 3DW with data
                end else begin
                    rx_cpl_tlp_hdr_next[127:125] = TLP_FMT_3DW; // fmt - 3DW without data
                end
                rx_cpl_tlp_hdr_next[124:120] = {4'b0101, rc_tdata[29]}; // type - completion
                rx_cpl_tlp_hdr_next[119] = 1'b0; // T9
                rx_cpl_tlp_hdr_next[118:116] = rc_tdata[91:89]; // TC
                rx_cpl_tlp_hdr_next[115] = 1'b0; // T8
                rx_cpl_tlp_hdr_next[114] = rc_tdata[94]; // attr
                rx_cpl_tlp_hdr_next[113] = 1'b0; // LN
                rx_cpl_tlp_hdr_next[112] = 1'b0; // TH
                rx_cpl_tlp_hdr_next[111] = 1'b0; // TD
                rx_cpl_tlp_hdr_next[110] = rc_tdata[46]; // EP
                rx_cpl_tlp_hdr_next[109:108] = rc_tdata[93:92]; // attr
                rx_cpl_tlp_hdr_next[107:106] = 2'b00; // AT
                rx_cpl_tlp_hdr_next[105:96] = rc_tdata[42:32]; // length
                // DW 1
                rx_cpl_tlp_hdr_next[95:80] = rc_tdata[87:72]; // completer ID
                rx_cpl_tlp_hdr_next[79:77] = rc_tdata[45:43]; // completion status
                rx_cpl_tlp_hdr_next[76] = 1'b0; // BCM
                rx_cpl_tlp_hdr_next[75:64] = rc_tdata[28:16]; // byte count
                // DW 2
                rx_cpl_tlp_hdr_next[63:48] = rc_tdata[63:48]; // requester ID
                rx_cpl_tlp_hdr_next[47:40] = rc_tdata[71:64]; // tag
                rx_cpl_tlp_hdr_next[39] = 1'b0;
                rx_cpl_tlp_hdr_next[38:32] = rc_tdata[6:0]; // lower address
                // DW 3
                rx_cpl_tlp_hdr_next[31:0] = 32'd0;

                // error code
                case (rc_tdata[15:12])
                    RC_ERROR_NORMAL_TERMINATION: rx_cpl_tlp_error_next = PCIE_ERROR_NONE;
                    RC_ERROR_POISONED:           rx_cpl_tlp_error_next = PCIE_ERROR_POISONED;
                    RC_ERROR_BAD_STATUS:         rx_cpl_tlp_error_next = PCIE_ERROR_BAD_STATUS;
                    RC_ERROR_INVALID_LENGTH:     rx_cpl_tlp_error_next = PCIE_ERROR_INVALID_LEN;
                    RC_ERROR_MISMATCH:           rx_cpl_tlp_error_next = PCIE_ERROR_MISMATCH;
                    RC_ERROR_INVALID_ADDRESS:    rx_cpl_tlp_error_next = PCIE_ERROR_INVALID_ADDR;
                    RC_ERROR_INVALID_TAG:        rx_cpl_tlp_error_next = PCIE_ERROR_INVALID_TAG;
                    RC_ERROR_FLR:                rx_cpl_tlp_error_next = PCIE_ERROR_FLR;
                    RC_ERROR_TIMEOUT:            rx_cpl_tlp_error_next = PCIE_ERROR_TIMEOUT;
                    default:                     rx_cpl_tlp_error_next = PCIE_ERROR_NONE;
                endcase

                if (AXIS_PCIE_DATA_WIDTH > 64) begin
                    rx_cpl_tlp_data_next = rc_tdata[AXIS_PCIE_DATA_WIDTH+96-1:96];
                    rx_cpl_tlp_sop_next = 1'b1;
                    rx_cpl_tlp_eop_next = 1'b0;

                    tlp_input_frame_next = 1'b1;

                    if (rc_tlast_int_reg) begin
                        rx_cpl_tlp_valid_next = 1'b1;
                        rx_cpl_tlp_eop_next = 1'b1;
                        rc_tvalid_int_next = 1'b0;
                        tlp_input_frame_next = 1'b0;
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end else if (s_axis_rc_tready && s_axis_rc_tvalid) begin
                        rx_cpl_tlp_valid_next = 1'b1;
                        tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                    end else begin
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end
                end else begin
                    if (rc_tlast_int_reg) begin
                        rc_tvalid_int_next = 1'b0;
                        tlp_input_frame_next = 1'b0;
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end else if (s_axis_rc_tready && s_axis_rc_tvalid) begin
                        tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                    end else begin
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end
                end
            end else begin
                tlp_input_state_next = TLP_INPUT_STATE_IDLE;
            end
        end
        TLP_INPUT_STATE_PAYLOAD: begin
            s_axis_rc_tready_cmb = rx_cpl_tlp_ready;

            if (rc_tvalid_int_reg && rx_cpl_tlp_ready) begin

                if (AXIS_PCIE_DATA_WIDTH > 64) begin
                    rx_cpl_tlp_data_next = rc_tdata[AXIS_PCIE_DATA_WIDTH+96-1:96];
                    rx_cpl_tlp_sop_next = 1'b0;
                end else begin
                    rx_cpl_tlp_data_next = rc_tdata[AXIS_PCIE_DATA_WIDTH+32-1:32];
                    rx_cpl_tlp_sop_next = !tlp_input_frame_reg;
                end
                rx_cpl_tlp_eop_next = 1'b0;

                if (rc_tlast_int_reg) begin
                    rx_cpl_tlp_valid_next = 1'b1;
                    rx_cpl_tlp_eop_next = 1'b1;
                    rc_tvalid_int_next = 1'b0;
                    tlp_input_frame_next = 1'b0;
                    tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                end else if (s_axis_rc_tready && s_axis_rc_tvalid) begin
                    rx_cpl_tlp_valid_next = 1'b1;
                    tlp_input_frame_next = 1'b1;
                    tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                end else begin
                    tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                end
            end else begin
                tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
            end
        end
    endcase

    if (s_axis_rc_tready && s_axis_rc_tvalid) begin
        rc_tdata_int_next = s_axis_rc_tdata;
        rc_tvalid_int_next = s_axis_rc_tvalid;
        rc_tlast_int_next = s_axis_rc_tlast;
    end
end

always @(posedge clk) begin
    tlp_input_state_reg <= tlp_input_state_next;

    rx_cpl_tlp_data_reg <= rx_cpl_tlp_data_next;
    rx_cpl_tlp_hdr_reg <= rx_cpl_tlp_hdr_next;
    rx_cpl_tlp_error_reg <= rx_cpl_tlp_error_next;
    rx_cpl_tlp_valid_reg <= rx_cpl_tlp_valid_next;
    rx_cpl_tlp_sop_reg <= rx_cpl_tlp_sop_next;
    rx_cpl_tlp_eop_reg <= rx_cpl_tlp_eop_next;

    tlp_input_frame_reg <= tlp_input_frame_next;

    rc_tdata_int_reg <= rc_tdata_int_next;
    rc_tvalid_int_reg <= rc_tvalid_int_next;
    rc_tlast_int_reg <= rc_tlast_int_next;

    if (rst) begin
        tlp_input_state_reg <= TLP_INPUT_STATE_IDLE;

        rx_cpl_tlp_valid_reg <= 0;

        rc_tvalid_int_reg <= 1'b0;
    end
end

endmodule

`resetall
