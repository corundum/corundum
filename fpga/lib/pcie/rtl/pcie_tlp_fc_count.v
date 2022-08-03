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
 * PCIe TLP flow control credit counter
 */
module pcie_tlp_fc_count #
(
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1
)
(
    input  wire                                    clk,
    input  wire                                    rst,

    /*
     * TLP monitor
     */
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                tlp_sop,
    input  wire                                    tlp_ready,

    /*
     * Flow control count output
     */
    output wire [3:0]                              out_fc_ph,
    output wire [8:0]                              out_fc_pd,
    output wire [3:0]                              out_fc_nph,
    output wire [8:0]                              out_fc_npd,
    output wire [3:0]                              out_fc_cplh,
    output wire [8:0]                              out_fc_cpld
);

// check configuration
initial begin
    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end
end

localparam [1:0]
    FC_TYPE_P = 2'b00,
    FC_TYPE_NP = 2'b01,
    FC_TYPE_CPL = 2'b10;

function [1:0] tlp_fc_type;
    input [7:0] fmt_type;
    case (fmt_type)
        8'b000_00000: tlp_fc_type = FC_TYPE_NP;  // MEM_READ
        8'b001_00000: tlp_fc_type = FC_TYPE_NP;  // MEM_READ_64
        8'b000_00001: tlp_fc_type = FC_TYPE_NP;  // MEM_READ_LOCKED
        8'b001_00001: tlp_fc_type = FC_TYPE_NP;  // MEM_READ_LOCKED_64
        8'b010_00000: tlp_fc_type = FC_TYPE_P;   // MEM_WRITE
        8'b011_00000: tlp_fc_type = FC_TYPE_P;   // MEM_WRITE_64
        8'b000_00010: tlp_fc_type = FC_TYPE_NP;  // IO_READ
        8'b010_00010: tlp_fc_type = FC_TYPE_NP;  // IO_WRITE
        8'b000_00100: tlp_fc_type = FC_TYPE_NP;  // CFG_READ_0
        8'b010_00100: tlp_fc_type = FC_TYPE_NP;  // CFG_WRITE_0
        8'b000_00101: tlp_fc_type = FC_TYPE_NP;  // CFG_READ_1
        8'b010_00101: tlp_fc_type = FC_TYPE_NP;  // CFG_WRITE_1
        8'b001_10000: tlp_fc_type = FC_TYPE_P;   // MSG_TO_RC
        8'b001_10001: tlp_fc_type = FC_TYPE_P;   // MSG_ADDR
        8'b001_10010: tlp_fc_type = FC_TYPE_P;   // MSG_ID
        8'b001_10011: tlp_fc_type = FC_TYPE_P;   // MSG_BCAST
        8'b001_10100: tlp_fc_type = FC_TYPE_P;   // MSG_LOCAL
        8'b001_10101: tlp_fc_type = FC_TYPE_P;   // MSG_GATHER
        8'b011_10000: tlp_fc_type = FC_TYPE_P;   // MSG_DATA_TO_RC
        8'b011_10001: tlp_fc_type = FC_TYPE_P;   // MSG_DATA_ADDR
        8'b011_10010: tlp_fc_type = FC_TYPE_P;   // MSG_DATA_ID
        8'b011_10011: tlp_fc_type = FC_TYPE_P;   // MSG_DATA_BCAST
        8'b011_10100: tlp_fc_type = FC_TYPE_P;   // MSG_DATA_LOCAL
        8'b011_10101: tlp_fc_type = FC_TYPE_P;   // MSG_DATA_GATHER
        8'b000_01010: tlp_fc_type = FC_TYPE_CPL; // CPL
        8'b010_01010: tlp_fc_type = FC_TYPE_CPL; // CPL_DATA
        8'b000_01011: tlp_fc_type = FC_TYPE_CPL; // CPL_LOCKED
        8'b010_01011: tlp_fc_type = FC_TYPE_CPL; // CPL_LOCKED_DATA
        8'b010_01100: tlp_fc_type = FC_TYPE_NP;  // FETCH_ADD
        8'b011_01100: tlp_fc_type = FC_TYPE_NP;  // FETCH_ADD_64
        8'b010_01101: tlp_fc_type = FC_TYPE_NP;  // SWAP
        8'b011_01101: tlp_fc_type = FC_TYPE_NP;  // SWAP_64
        8'b010_01110: tlp_fc_type = FC_TYPE_NP;  // CAS
        8'b011_01110: tlp_fc_type = FC_TYPE_NP;  // CAS_64
        default: tlp_fc_type = 2'bxx;
    endcase
endfunction

reg [1:0] seg_fc_type;
reg [11:0] seg_fc_d;

reg [3:0] fc_ph_reg = 0, fc_ph_next;
reg [8:0] fc_pd_reg = 0, fc_pd_next;
reg [3:0] fc_nph_reg = 0, fc_nph_next;
reg [8:0] fc_npd_reg = 0, fc_npd_next;
reg [3:0] fc_cplh_reg = 0, fc_cplh_next;
reg [8:0] fc_cpld_reg = 0, fc_cpld_next;

assign out_fc_ph = fc_ph_reg;
assign out_fc_pd = fc_pd_reg;
assign out_fc_nph = fc_nph_reg;
assign out_fc_npd = fc_npd_reg;
assign out_fc_cplh = fc_cplh_reg;
assign out_fc_cpld = fc_cpld_reg;

integer seg;

always @* begin
    fc_ph_next = 0;
    fc_pd_next = 0;
    fc_nph_next = 0;
    fc_npd_next = 0;
    fc_cplh_next = 0;
    fc_cpld_next = 0;

    for (seg = 0; seg < TLP_SEG_COUNT; seg = seg + 1) begin
        seg_fc_type = tlp_fc_type(tlp_hdr[seg*TLP_HDR_WIDTH+120 +: 8]);
        seg_fc_d = 0;
        if (tlp_hdr[seg*TLP_HDR_WIDTH+126]) begin
            seg_fc_d = ({tlp_hdr[seg*TLP_HDR_WIDTH+96 +: 9] == 0, tlp_hdr[seg*TLP_HDR_WIDTH+96 +: 9]}+3) >> 2;
        end

        if (tlp_sop[seg] && tlp_valid[seg] && tlp_ready) begin
            if (seg_fc_type == FC_TYPE_P) begin
                fc_ph_next = fc_ph_next + 1;
                fc_pd_next = fc_pd_next + seg_fc_d;
            end else if (seg_fc_type == FC_TYPE_NP) begin
                fc_nph_next = fc_nph_next + 1;
                fc_npd_next = fc_npd_next + seg_fc_d;
            end else if (seg_fc_type == FC_TYPE_CPL) begin
                fc_cplh_next = fc_cplh_next + 1;
                fc_cpld_next = fc_cpld_next + seg_fc_d;
            end
        end
    end
end

always @(posedge clk) begin
    fc_ph_reg <= fc_ph_next;
    fc_pd_reg <= fc_pd_next;
    fc_nph_reg <= fc_nph_next;
    fc_npd_reg <= fc_npd_next;
    fc_cplh_reg <= fc_cplh_next;
    fc_cpld_reg <= fc_cpld_next;

    if (rst) begin
        fc_ph_reg <= 0;
        fc_pd_reg <= 0;
        fc_nph_reg <= 0;
        fc_npd_reg <= 0;
        fc_cplh_reg <= 0;
        fc_cpld_reg <= 0;
    end
end

endmodule

`resetall
