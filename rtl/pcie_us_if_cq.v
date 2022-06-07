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

    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
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
reg [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] rx_req_tlp_hdr_reg = 0, rx_req_tlp_hdr_next;
reg [TLP_SEG_COUNT*3-1:0] rx_req_tlp_bar_id_reg = 0, rx_req_tlp_bar_id_next;
reg [TLP_SEG_COUNT*7-1:0] rx_req_tlp_func_num_reg = 0, rx_req_tlp_func_num_next;
reg [TLP_SEG_COUNT-1:0] rx_req_tlp_valid_reg = 0, rx_req_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0] rx_req_tlp_sop_reg = 0, rx_req_tlp_sop_next;
reg [TLP_SEG_COUNT-1:0] rx_req_tlp_eop_reg = 0, rx_req_tlp_eop_next;

assign rx_req_tlp_data = rx_req_tlp_data_reg;
assign rx_req_tlp_strb = rx_req_tlp_strb_reg;
assign rx_req_tlp_hdr = rx_req_tlp_hdr_reg;
assign rx_req_tlp_bar_id = rx_req_tlp_bar_id_reg;
assign rx_req_tlp_func_num = rx_req_tlp_func_num_reg;
assign rx_req_tlp_valid = rx_req_tlp_valid_reg;
assign rx_req_tlp_sop = rx_req_tlp_sop_reg;
assign rx_req_tlp_eop = rx_req_tlp_eop_reg;

localparam [1:0]
    TLP_INPUT_STATE_IDLE = 2'd0,
    TLP_INPUT_STATE_HEADER = 2'd1,
    TLP_INPUT_STATE_PAYLOAD = 2'd2;

reg [1:0] tlp_input_state_reg = TLP_INPUT_STATE_IDLE, tlp_input_state_next;

reg s_axis_cq_tready_cmb;

reg tlp_input_frame_reg = 1'b0, tlp_input_frame_next;

reg [AXIS_PCIE_DATA_WIDTH-1:0] cq_tdata_int_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}}, cq_tdata_int_next;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] cq_tkeep_int_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}}, cq_tkeep_int_next;
reg cq_tvalid_int_reg = 1'b0, cq_tvalid_int_next;
reg cq_tlast_int_reg = 1'b0, cq_tlast_int_next;
reg [AXIS_PCIE_CQ_USER_WIDTH-1:0] cq_tuser_int_reg = {AXIS_PCIE_CQ_USER_WIDTH{1'b0}}, cq_tuser_int_next;

wire [AXIS_PCIE_DATA_WIDTH*2-1:0] cq_tdata = {s_axis_cq_tdata, cq_tdata_int_reg};
wire [AXIS_PCIE_KEEP_WIDTH*2-1:0] cq_tkeep = {s_axis_cq_tkeep, cq_tkeep_int_reg};

reg [127:0] tlp_hdr;
reg [2:0] tlp_bar_id;
reg [7:0] tlp_func_num;

assign s_axis_cq_tready = s_axis_cq_tready_cmb;

always @* begin
    tlp_input_state_next = TLP_INPUT_STATE_IDLE;

    rx_req_tlp_data_next = rx_req_tlp_data_reg;
    rx_req_tlp_strb_next = rx_req_tlp_strb_reg;
    rx_req_tlp_hdr_next = rx_req_tlp_hdr_reg;
    rx_req_tlp_bar_id_next = rx_req_tlp_bar_id_reg;
    rx_req_tlp_func_num_next = rx_req_tlp_func_num_reg;
    rx_req_tlp_valid_next = rx_req_tlp_valid_reg && !rx_req_tlp_ready;
    rx_req_tlp_sop_next = rx_req_tlp_sop_reg;
    rx_req_tlp_eop_next = rx_req_tlp_eop_reg;

    s_axis_cq_tready_cmb = rx_req_tlp_ready;

    tlp_input_frame_next = tlp_input_frame_reg;

    cq_tdata_int_next = cq_tdata_int_reg;
    cq_tkeep_int_next = cq_tkeep_int_reg;
    cq_tvalid_int_next = cq_tvalid_int_reg;
    cq_tlast_int_next = cq_tlast_int_reg;
    cq_tuser_int_next = cq_tuser_int_reg;

    if (s_axis_cq_tready && s_axis_cq_tvalid) begin
        cq_tdata_int_next = s_axis_cq_tdata;
        cq_tkeep_int_next = s_axis_cq_tkeep;
        cq_tvalid_int_next = s_axis_cq_tvalid;
        cq_tlast_int_next = s_axis_cq_tlast;
        cq_tuser_int_next = s_axis_cq_tuser;
    end

    // parse header
    // DW 0
    case (cq_tdata[78:75])
        REQ_MEM_READ: begin
            tlp_hdr[127:125] = TLP_FMT_4DW; // fmt
            tlp_hdr[124:120] = {5'b00000}; // type
        end
        REQ_MEM_WRITE: begin
            tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            tlp_hdr[124:120] = {5'b00000}; // type
        end
        REQ_IO_READ: begin
            tlp_hdr[127:125] = TLP_FMT_4DW; // fmt
            tlp_hdr[124:120] = {5'b00010}; // type
        end
        REQ_IO_WRITE: begin
            tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            tlp_hdr[124:120] = {5'b00010}; // type
        end
        REQ_MEM_FETCH_ADD: begin
            tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            tlp_hdr[124:120] = {5'b01100}; // type
        end
        REQ_MEM_SWAP: begin
            tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            tlp_hdr[124:120] = {5'b01101}; // type
        end
        REQ_MEM_CAS: begin
            tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            tlp_hdr[124:120] = {5'b01110}; // type
        end
        REQ_MEM_READ_LOCKED: begin
            tlp_hdr[127:125] = TLP_FMT_4DW; // fmt
            tlp_hdr[124:120] = {5'b00001}; // type
        end
        REQ_MSG: begin
            if (cq_tdata[74:64]) begin
                tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            end else begin
                tlp_hdr[127:125] = TLP_FMT_4DW; // fmt
            end
            tlp_hdr[124:120] = {2'b10, cq_tdata[114:112]}; // type
        end
        REQ_MSG_VENDOR: begin
            if (cq_tdata[74:64]) begin
                tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            end else begin
                tlp_hdr[127:125] = TLP_FMT_4DW; // fmt
            end
            tlp_hdr[124:120] = {2'b10, cq_tdata[114:112]}; // type
        end
        REQ_MSG_ATS: begin
            if (cq_tdata[74:64]) begin
                tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt
            end else begin
                tlp_hdr[127:125] = TLP_FMT_4DW; // fmt
            end
            tlp_hdr[124:120] = {2'b10, cq_tdata[114:112]}; // type
        end
        default: begin
            tlp_hdr[127:125] = TLP_FMT_4DW; // fmt
            tlp_hdr[124:120] = {5'b00000}; // type
        end
    endcase
    tlp_hdr[119] = 1'b0; // T9
    tlp_hdr[118:116] = cq_tdata[123:121]; // TC
    tlp_hdr[115] = 1'b0; // T8
    tlp_hdr[114] = cq_tdata[126]; // attr
    tlp_hdr[113] = 1'b0; // LN
    tlp_hdr[112] = 1'b0; // TH
    tlp_hdr[111] = 1'b0; // TD
    tlp_hdr[110] = 1'b0; // EP
    tlp_hdr[109:108] = cq_tdata[125:124]; // attr
    tlp_hdr[107:106] = cq_tdata[1:0]; // AT
    tlp_hdr[105:96] = cq_tdata[74:64]; // length
    // DW 1
    tlp_hdr[95:80] = cq_tdata[95:80]; // requester ID
    tlp_hdr[79:72] = cq_tdata[103:96]; // tag
    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        tlp_hdr[71:68] = cq_tuser_int_reg[11:8]; // last BE
        tlp_hdr[67:64] = cq_tuser_int_reg[3:0]; // first BE
    end else begin
        tlp_hdr[71:68] = cq_tuser_int_reg[7:4]; // last BE
        tlp_hdr[67:64] = cq_tuser_int_reg[3:0]; // first BE
    end
    // DW 2+3
    tlp_hdr[63:2] = cq_tdata[63:2]; // address
    tlp_hdr[1:0] = 2'b00; // PH

    tlp_bar_id = cq_tdata[114:112];
    tlp_func_num = cq_tdata[111:104];

    case (tlp_input_state_reg)
        TLP_INPUT_STATE_IDLE: begin
            s_axis_cq_tready_cmb = rx_req_tlp_ready;

            if (cq_tvalid_int_reg && rx_req_tlp_ready) begin

                rx_req_tlp_hdr_next = tlp_hdr;
                rx_req_tlp_bar_id_next = tlp_bar_id;
                rx_req_tlp_func_num_next = tlp_func_num;

                if (AXIS_PCIE_DATA_WIDTH > 64) begin
                    rx_req_tlp_data_next = cq_tdata >> 128;
                    rx_req_tlp_strb_next = cq_tkeep >> 4;
                    rx_req_tlp_sop_next = 1'b1;
                    rx_req_tlp_eop_next = 1'b0;

                    tlp_input_frame_next = 1'b1;

                    if (cq_tlast_int_reg) begin
                        rx_req_tlp_valid_next = 1'b1;
                        rx_req_tlp_strb_next = cq_tkeep_int_reg >> 4;
                        rx_req_tlp_eop_next = 1'b1;
                        cq_tvalid_int_next = s_axis_cq_tready && s_axis_cq_tvalid;
                        tlp_input_frame_next = 1'b0;
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end else if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                        if (s_axis_cq_tlast && s_axis_cq_tkeep >> 4 == 0) begin
                            rx_req_tlp_valid_next = 1'b1;
                            rx_req_tlp_eop_next = 1'b1;
                            cq_tvalid_int_next = 1'b0;
                            tlp_input_frame_next = 1'b0;
                            tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                        end else begin
                            rx_req_tlp_valid_next = 1'b1;
                            tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                        end
                    end else begin
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end
                end else begin
                    rx_req_tlp_data_next = 0;
                    rx_req_tlp_strb_next = 0;
                    rx_req_tlp_sop_next = 1'b1;
                    rx_req_tlp_eop_next = 1'b0;

                    if (cq_tlast_int_reg) begin
                        cq_tvalid_int_next = s_axis_cq_tready && s_axis_cq_tvalid;
                        tlp_input_frame_next = 1'b0;
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end else if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                        if (s_axis_cq_tlast) begin
                            rx_req_tlp_valid_next = 1'b1;
                            rx_req_tlp_strb_next = 0;
                            rx_req_tlp_eop_next = 1'b1;
                            cq_tvalid_int_next = 1'b0;
                            tlp_input_frame_next = 1'b0;
                            tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                        end else begin
                            tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                        end
                    end else begin
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end
                end
            end else begin
                tlp_input_state_next = TLP_INPUT_STATE_IDLE;
            end
        end
        TLP_INPUT_STATE_PAYLOAD: begin
            s_axis_cq_tready_cmb = rx_req_tlp_ready;

            if (cq_tvalid_int_reg && rx_req_tlp_ready) begin

                if (AXIS_PCIE_DATA_WIDTH > 128) begin
                    rx_req_tlp_data_next = cq_tdata >> 128;
                    rx_req_tlp_strb_next = cq_tkeep >> 4;
                    rx_req_tlp_sop_next = 1'b0;
                end else begin
                    rx_req_tlp_data_next = s_axis_cq_tdata;
                    rx_req_tlp_strb_next = s_axis_cq_tkeep;
                    rx_req_tlp_sop_next = !tlp_input_frame_reg;
                end
                rx_req_tlp_eop_next = 1'b0;

                if (cq_tlast_int_reg) begin
                    rx_req_tlp_valid_next = 1'b1;
                    rx_req_tlp_strb_next = cq_tkeep_int_reg >> 4;
                    rx_req_tlp_eop_next = 1'b1;
                    cq_tvalid_int_next = s_axis_cq_tready && s_axis_cq_tvalid;
                    tlp_input_frame_next = 1'b0;
                    tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                end else if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                    if (s_axis_cq_tlast && s_axis_cq_tkeep >> 4 == 0) begin
                        rx_req_tlp_valid_next = 1'b1;
                        rx_req_tlp_eop_next = 1'b1;
                        cq_tvalid_int_next = 1'b0;
                        tlp_input_frame_next = 1'b0;
                        tlp_input_state_next = TLP_INPUT_STATE_IDLE;
                    end else begin
                        rx_req_tlp_valid_next = 1'b1;
                        tlp_input_frame_next = 1'b1;
                        tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                    end
                end else begin
                    tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
                end
            end else begin
                tlp_input_state_next = TLP_INPUT_STATE_PAYLOAD;
            end
        end
    endcase
end

always @(posedge clk) begin
    tlp_input_state_reg <= tlp_input_state_next;

    rx_req_tlp_data_reg <= rx_req_tlp_data_next;
    rx_req_tlp_strb_reg <= rx_req_tlp_strb_next;
    rx_req_tlp_hdr_reg <= rx_req_tlp_hdr_next;
    rx_req_tlp_bar_id_reg <= rx_req_tlp_bar_id_next;
    rx_req_tlp_func_num_reg <= rx_req_tlp_func_num_next;
    rx_req_tlp_valid_reg <= rx_req_tlp_valid_next;
    rx_req_tlp_sop_reg <= rx_req_tlp_sop_next;
    rx_req_tlp_eop_reg <= rx_req_tlp_eop_next;

    tlp_input_frame_reg <= tlp_input_frame_next;

    cq_tdata_int_reg <= cq_tdata_int_next;
    cq_tkeep_int_reg <= cq_tkeep_int_next;
    cq_tvalid_int_reg <= cq_tvalid_int_next;
    cq_tlast_int_reg <= cq_tlast_int_next;
    cq_tuser_int_reg <= cq_tuser_int_next;

    if (rst) begin
        tlp_input_state_reg <= TLP_INPUT_STATE_IDLE;

        rx_req_tlp_valid_reg <= 0;

        cq_tvalid_int_reg <= 1'b0;
    end
end

endmodule

`resetall
