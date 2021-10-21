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
 * PCIe TLP demultiplexer (BAR ID)
 */
module pcie_tlp_demux_bar #
(
    // Output count
    parameter PORTS = 2,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = 256,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // Base BAR
    parameter BAR_BASE = 0,
    // BAR stride
    parameter BAR_STRIDE = 1,
    // Explicit BAR numbers (set to 0 to use base/stride)
    parameter BAR_IDS = 0
)
(
    input  wire                                               clk,
    input  wire                                               rst,

    /*
     * TLP input
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]        in_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]        in_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]         in_tlp_hdr,
    input  wire [TLP_SEG_COUNT*3-1:0]                         in_tlp_bar_id,
    input  wire [TLP_SEG_COUNT*8-1:0]                         in_tlp_func_num,
    input  wire [TLP_SEG_COUNT*4-1:0]                         in_tlp_error,
    input  wire [TLP_SEG_COUNT-1:0]                           in_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                           in_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                           in_tlp_eop,
    output wire                                               in_tlp_ready,

    /*
     * TLP output
     */
    output wire [PORTS*TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  out_tlp_data,
    output wire [PORTS*TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  out_tlp_strb,
    output wire [PORTS*TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   out_tlp_hdr,
    output wire [PORTS*TLP_SEG_COUNT*3-1:0]                   out_tlp_bar_id,
    output wire [PORTS*TLP_SEG_COUNT*8-1:0]                   out_tlp_func_num,
    output wire [PORTS*TLP_SEG_COUNT*4-1:0]                   out_tlp_error,
    output wire [PORTS*TLP_SEG_COUNT-1:0]                     out_tlp_valid,
    output wire [PORTS*TLP_SEG_COUNT-1:0]                     out_tlp_sop,
    output wire [PORTS*TLP_SEG_COUNT-1:0]                     out_tlp_eop,
    input  wire [PORTS-1:0]                                   out_tlp_ready,

    /*
     * Control
     */
    input  wire                                               enable
);

// default BAR number computation
function [PORTS*3-1:0] calcBarIds(input [2:0] base, input [2:0] stride);
    integer i;
    reg [2:0] bar;
    begin
        calcBarIds = {PORTS*3{1'b0}};
        bar = base;
        for (i = 0; i < PORTS; i = i + 1) begin
            calcBarIds[i*3 +: 3] = bar;
            bar = bar + stride;
        end
    end
endfunction

parameter BAR_IDS_INT = BAR_IDS ? BAR_IDS : calcBarIds(BAR_BASE, BAR_STRIDE);

integer i, j;

// check configuration
initial begin
    for (i = 0; i < PORTS; i = i + 1) begin
        if (BAR_IDS_INT[i*3 +: 3] > 5) begin
            $error("Error: BAR out of range (instance %m)");
            $finish;
        end
    end

    for (i = 0; i < PORTS; i = i + 1) begin
        for (j = i+1; j < PORTS; j = j + 1) begin
            if (BAR_IDS_INT[i*3 +: 3] == BAR_IDS_INT[j*3 +: 3]) begin
                $display("Duplicate BAR:");
                $display("%d: %d", i, BAR_IDS_INT[i*3 +: 3]);
                $display("%d: %d", j, BAR_IDS_INT[j*3 +: 3]);
                $error("Error: Duplicate BAR (instance %m)");
                $finish;
            end
        end
    end
end

wire [TLP_SEG_COUNT*3-1:0] match_tlp_bar_id;

wire [TLP_SEG_COUNT-1:0] drop;
wire [TLP_SEG_COUNT*PORTS-1:0] select;

generate

    genvar m, n;

    for (n = 0; n < TLP_SEG_COUNT; n = n + 1) begin
        for (m = 0; m < PORTS; m = m + 1) begin
            assign select[n*PORTS+m] = match_tlp_bar_id[n*3 +: 3] == BAR_IDS_INT[m*3 +: 3];
        end
        assign drop[n] = select[n*PORTS +: PORTS] == 0;
    end

endgenerate

pcie_tlp_demux #(
    .PORTS(PORTS),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH)
)
pcie_tlp_demux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(in_tlp_data),
    .in_tlp_strb(in_tlp_strb),
    .in_tlp_hdr(in_tlp_hdr),
    .in_tlp_bar_id(in_tlp_bar_id),
    .in_tlp_func_num(in_tlp_func_num),
    .in_tlp_error(in_tlp_error),
    .in_tlp_valid(in_tlp_valid),
    .in_tlp_sop(in_tlp_sop),
    .in_tlp_eop(in_tlp_eop),
    .in_tlp_ready(in_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(out_tlp_data),
    .out_tlp_strb(out_tlp_strb),
    .out_tlp_hdr(out_tlp_hdr),
    .out_tlp_bar_id(out_tlp_bar_id),
    .out_tlp_func_num(out_tlp_func_num),
    .out_tlp_error(out_tlp_error),
    .out_tlp_valid(out_tlp_valid),
    .out_tlp_sop(out_tlp_sop),
    .out_tlp_eop(out_tlp_eop),
    .out_tlp_ready(out_tlp_ready),

    /*
     * Fields
     */
    .match_tlp_hdr(),
    .match_tlp_bar_id(match_tlp_bar_id),
    .match_tlp_func_num(),

    /*
     * Control
     */
    .enable(enable),
    .drop(drop),
    .select(select)
);

endmodule

`resetall
