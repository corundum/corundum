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
 * Statistics for PCIe TLP traffic
 */
module stats_pcie_tlp #
(
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128
)
(
    input  wire                                        clk,
    input  wire                                        rst,

    /*
     * TLP monitor input
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]  tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                    tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                    tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                    tlp_eop,

    /*
     * Statistics outputs
     */
    output wire                                        stat_tlp_mem_rd,
    output wire                                        stat_tlp_mem_wr,
    output wire                                        stat_tlp_io,
    output wire                                        stat_tlp_cfg,
    output wire                                        stat_tlp_msg,
    output wire                                        stat_tlp_cpl,
    output wire                                        stat_tlp_cpl_ur,
    output wire                                        stat_tlp_cpl_ca,
    output wire                                        stat_tlp_atomic,
    output wire                                        stat_tlp_ep,
    output wire [2:0]                                  stat_tlp_hdr_dw,
    output wire [10:0]                                 stat_tlp_req_dw,
    output wire [10:0]                                 stat_tlp_payload_dw,
    output wire [10:0]                                 stat_tlp_cpl_dw
);

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

reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]  tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT-1:0]                    tlp_valid_reg = 0;
reg [TLP_SEG_COUNT-1:0]                    tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                    tlp_eop_reg = 0;

reg stat_tlp_mem_rd_reg = 1'b0;
reg stat_tlp_mem_wr_reg = 1'b0;
reg stat_tlp_io_reg = 1'b0;
reg stat_tlp_cfg_reg = 1'b0;
reg stat_tlp_msg_reg = 1'b0;
reg stat_tlp_cpl_reg = 1'b0;
reg stat_tlp_cpl_ur_reg = 1'b0;
reg stat_tlp_cpl_ca_reg = 1'b0;
reg stat_tlp_atomic_reg = 1'b0;
reg stat_tlp_ep_reg = 1'b0;
reg [2:0] stat_tlp_hdr_dw_reg = 3'd0;
reg [10:0] stat_tlp_req_dw_reg = 11'd0;
reg [10:0] stat_tlp_payload_dw_reg = 11'd0;
reg [10:0] stat_tlp_cpl_dw_reg = 11'd0;

wire tlp_hdr_valid = tlp_valid_reg && tlp_sop_reg;
wire [7:0] tlp_hdr_fmt_type = tlp_hdr_reg[127:120];
wire [2:0] tlp_hdr_fmt = tlp_hdr_reg[127:125];
wire [4:0] tlp_hdr_type = tlp_hdr_reg[124:120];
wire tlp_hdr_ep = tlp_hdr_reg[110];
wire [9:0] tlp_hdr_length = tlp_hdr_reg[105:96];
wire [3:0] tlp_hdr_cpl_status = tlp_hdr_reg[79:77];

assign stat_tlp_mem_rd = stat_tlp_mem_rd_reg;
assign stat_tlp_mem_wr = stat_tlp_mem_wr_reg;
assign stat_tlp_io = stat_tlp_io_reg;
assign stat_tlp_cfg = stat_tlp_cfg_reg;
assign stat_tlp_msg = stat_tlp_msg_reg;
assign stat_tlp_cpl = stat_tlp_cpl_reg;
assign stat_tlp_cpl_ur = stat_tlp_cpl_ur_reg;
assign stat_tlp_cpl_ca = stat_tlp_cpl_ca_reg;
assign stat_tlp_atomic = stat_tlp_atomic_reg;
assign stat_tlp_ep = stat_tlp_ep_reg;
assign stat_tlp_hdr_dw = stat_tlp_hdr_dw_reg;
assign stat_tlp_req_dw = stat_tlp_req_dw_reg;
assign stat_tlp_payload_dw = stat_tlp_payload_dw_reg;
assign stat_tlp_cpl_dw = stat_tlp_cpl_dw_reg;

always @(posedge clk) begin
    tlp_hdr_reg <= tlp_hdr;
    tlp_valid_reg <= tlp_valid;
    tlp_sop_reg <= tlp_sop;
    tlp_eop_reg <= tlp_eop;

    stat_tlp_mem_rd_reg <= 1'b0;
    stat_tlp_mem_wr_reg <= 1'b0;
    stat_tlp_io_reg <= 1'b0;
    stat_tlp_cfg_reg <= 1'b0;
    stat_tlp_msg_reg <= 1'b0;
    stat_tlp_cpl_reg <= 1'b0;
    stat_tlp_cpl_ur_reg <= 1'b0;
    stat_tlp_cpl_ca_reg <= 1'b0;
    stat_tlp_atomic_reg <= 1'b0;
    stat_tlp_ep_reg <= 1'b0;
    stat_tlp_hdr_dw_reg <= 0;
    stat_tlp_req_dw_reg <= 0;
    stat_tlp_payload_dw_reg <= 0;
    stat_tlp_cpl_dw_reg <= 0;

    if (tlp_hdr_valid) begin

        casez (tlp_hdr_fmt_type)
            8'b00z_0000z: stat_tlp_mem_rd_reg <= 1'b1;
            8'b01z_00000: stat_tlp_mem_wr_reg <= 1'b1;
            8'b0z0_00010: stat_tlp_io_reg <= 1'b1;
            8'b0z0_0010z: stat_tlp_cfg_reg <= 1'b1;
            8'b0z1_10zzz: stat_tlp_msg_reg <= 1'b1;
            8'b0z0_0101z: begin
                stat_tlp_cpl_reg <= 1'b1;
                stat_tlp_cpl_ur_reg <= tlp_hdr_cpl_status == CPL_STATUS_UR;
                stat_tlp_cpl_ca_reg <= tlp_hdr_cpl_status == CPL_STATUS_CA;
            end
            8'b01z_01100: stat_tlp_atomic_reg <= 1'b1;
            8'b01z_01101: stat_tlp_atomic_reg <= 1'b1;
            8'b01z_01110: stat_tlp_atomic_reg <= 1'b1;
        endcase

        stat_tlp_ep_reg <= tlp_hdr_ep;

        stat_tlp_hdr_dw_reg <= tlp_hdr_fmt[0] ? 3'd4 : 3'd3;

        if (tlp_hdr_fmt[1]) begin
            if (tlp_hdr_type == 5'b01010 || tlp_hdr_type == 5'b01011) begin
                stat_tlp_cpl_dw_reg <= tlp_hdr_length == 0 ? 11'd1024 : tlp_hdr_length;
            end else begin
                stat_tlp_payload_dw_reg <= tlp_hdr_length == 0 ? 11'd1024 : tlp_hdr_length;
            end
        end else begin
            stat_tlp_req_dw_reg <= tlp_hdr_length == 0 ? 11'd1024 : tlp_hdr_length;
        end
    end

    if (rst) begin
        tlp_valid_reg <= 0;
        tlp_sop_reg <= 0;
        tlp_eop_reg <= 0;

        stat_tlp_mem_rd_reg <= 0;
        stat_tlp_mem_wr_reg <= 0;
        stat_tlp_io_reg <= 0;
        stat_tlp_cfg_reg <= 0;
        stat_tlp_msg_reg <= 0;
        stat_tlp_cpl_reg <= 0;
        stat_tlp_cpl_ur_reg <= 0;
        stat_tlp_cpl_ca_reg <= 0;
        stat_tlp_atomic_reg <= 0;
        stat_tlp_ep_reg <= 0;
        stat_tlp_hdr_dw_reg <= 0;
        stat_tlp_req_dw_reg <= 0;
        stat_tlp_payload_dw_reg <= 0;
        stat_tlp_cpl_dw_reg <= 0;
    end
end

endmodule

`resetall
