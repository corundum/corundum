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
 * P-Tile PCIe interface adapter (receive)
 */
module pcie_ptile_if_rx #
(
    // P-Tile AVST segment count
    parameter SEG_COUNT = 1,
    // P-Tile AVST segment data width
    parameter SEG_DATA_WIDTH = 128,
    // P-Tile AVST segment empty signal width
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
    // P-Tile AVST segment header width
    parameter SEG_HDR_WIDTH = 128,
    // P-Tile AVST segment TLP prefix width
    parameter SEG_PRFX_WIDTH = 32,
    // TLP data width
    parameter TLP_DATA_WIDTH = SEG_COUNT*SEG_DATA_WIDTH,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // IO bar index
    // rx_st_bar_range = 6 is mapped to IO_BAR_INDEX on rx_req_tlp_bar_id
    parameter IO_BAR_INDEX = 5
)
(
    input  wire                                    clk,
    input  wire                                    rst,

    /*
     * P-Tile RX AVST interface
     */
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]     rx_st_data,
    input  wire [SEG_COUNT*SEG_EMPTY_WIDTH-1:0]    rx_st_empty,
    input  wire [SEG_COUNT-1:0]                    rx_st_sop,
    input  wire [SEG_COUNT-1:0]                    rx_st_eop,
    input  wire [SEG_COUNT-1:0]                    rx_st_valid,
    output wire                                    rx_st_ready,
    input  wire [SEG_COUNT*SEG_HDR_WIDTH-1:0]      rx_st_hdr,
    input  wire [SEG_COUNT*SEG_PRFX_WIDTH-1:0]     rx_st_tlp_prfx,
    input  wire [SEG_COUNT-1:0]                    rx_st_vf_active,
    input  wire [SEG_COUNT*3-1:0]                  rx_st_func_num,
    input  wire [SEG_COUNT*11-1:0]                 rx_st_vf_num,
    input  wire [SEG_COUNT*3-1:0]                  rx_st_bar_range,
    input  wire [SEG_COUNT-1:0]                    rx_st_tlp_abort,

    /*
     * TLP output (request to BAR)
     */
    output wire [TLP_DATA_WIDTH-1:0]               rx_req_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]               rx_req_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  rx_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]              rx_req_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]              rx_req_tlp_func_num,
    output wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_eop,
    input  wire                                    rx_req_tlp_ready,

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

parameter SEG_STRB_WIDTH = SEG_DATA_WIDTH/32;

parameter INT_TLP_SEG_COUNT = SEG_COUNT;
parameter INT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / INT_TLP_SEG_COUNT;
parameter INT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / INT_TLP_SEG_COUNT;

// bus width assertions
initial begin
    if (SEG_HDR_WIDTH != 128) begin
        $error("Error: segment header width must be 128 (instance %m)");
        $finish;
    end

    if (SEG_PRFX_WIDTH != 32) begin
        $error("Error: segment TLP prefix width must be 32 (instance %m)");
        $finish;
    end

    if (TLP_DATA_WIDTH != SEG_COUNT*SEG_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end
end

reg [TLP_DATA_WIDTH-1:0] rx_tlp_data_reg = 0, rx_tlp_data_next;
reg [TLP_STRB_WIDTH-1:0] rx_tlp_strb_reg = 0, rx_tlp_strb_next;
reg [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] rx_tlp_hdr_reg = 0, rx_tlp_hdr_next;
reg [INT_TLP_SEG_COUNT*3-1:0] rx_tlp_bar_id_reg = 0, rx_tlp_bar_id_next;
reg [INT_TLP_SEG_COUNT*8-1:0] rx_tlp_func_num_reg = 0, rx_tlp_func_num_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_tlp_valid_reg = 0, rx_tlp_valid_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_tlp_sop_reg = 0, rx_tlp_sop_next;
reg [INT_TLP_SEG_COUNT-1:0] rx_tlp_eop_reg = 0, rx_tlp_eop_next;

wire fifo_tlp_ready;
wire [1:0] fifo_watermark;

reg [TLP_STRB_WIDTH-1:0] rx_st_strb;
reg [TLP_STRB_WIDTH-1:0] rx_st_strb_sop;
reg [TLP_STRB_WIDTH-1:0] rx_st_strb_eop;

reg [INT_TLP_SEG_COUNT*3-1:0] tlp_bar_id;
reg [INT_TLP_SEG_COUNT*8-1:0] tlp_func_num;

assign rx_st_ready = !fifo_watermark;

// demux w/FIFOs
wire [INT_TLP_SEG_COUNT*128-1:0] demux_match_tlp_hdr;

wire [INT_TLP_SEG_COUNT-1:0] demux_drop = 0;
wire [2*INT_TLP_SEG_COUNT-1:0] demux_select;

generate

    genvar m, n;

    for (n = 0; n < INT_TLP_SEG_COUNT; n = n + 1) begin
        // send completions to port 1 (fmt/type 8'b0x0_0101x)
        assign demux_select[1*INT_TLP_SEG_COUNT+n] = demux_match_tlp_hdr[n*128+121 +: 5] == 5'b00101;
        assign demux_select[0*INT_TLP_SEG_COUNT+n] = !demux_select[1*INT_TLP_SEG_COUNT+n];
    end

endgenerate

wire [TLP_SEG_COUNT*3-1:0] rx_cpl_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0] rx_cpl_tlp_func_num;

pcie_tlp_demux #(
    .PORTS(2),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(1),
    .IN_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .FIFO_ENABLE(1),
    .FIFO_DEPTH((2048/4)*2),
    .FIFO_WATERMARK((2048/4)*2-TLP_STRB_WIDTH*28)
)
pcie_tlp_demux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(rx_tlp_data_reg),
    .in_tlp_strb(rx_tlp_strb_reg),
    .in_tlp_hdr(rx_tlp_hdr_reg),
    .in_tlp_seq(0),
    .in_tlp_bar_id(rx_tlp_bar_id_reg),
    .in_tlp_func_num(rx_tlp_func_num_reg),
    .in_tlp_error(0),
    .in_tlp_valid(rx_tlp_valid_reg),
    .in_tlp_sop(rx_tlp_sop_reg),
    .in_tlp_eop(rx_tlp_eop_reg),
    .in_tlp_ready(fifo_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data({rx_cpl_tlp_data, rx_req_tlp_data}),
    .out_tlp_strb({rx_cpl_tlp_strb, rx_req_tlp_strb}),
    .out_tlp_hdr({rx_cpl_tlp_hdr, rx_req_tlp_hdr}),
    .out_tlp_seq(),
    .out_tlp_bar_id({rx_cpl_tlp_bar_id, rx_req_tlp_bar_id}),
    .out_tlp_func_num({rx_cpl_tlp_func_num, rx_req_tlp_func_num}),
    .out_tlp_error(),
    .out_tlp_valid({rx_cpl_tlp_valid, rx_req_tlp_valid}),
    .out_tlp_sop({rx_cpl_tlp_sop, rx_req_tlp_sop}),
    .out_tlp_eop({rx_cpl_tlp_eop, rx_req_tlp_eop}),
    .out_tlp_ready({rx_cpl_tlp_ready, rx_req_tlp_ready}),

    /*
     * Fields
     */
    .match_tlp_hdr(demux_match_tlp_hdr),
    .match_tlp_bar_id(),
    .match_tlp_func_num(),

    /*
     * Control
     */
    .enable(1'b1),
    .drop(demux_drop),
    .select(demux_select),

    /*
     * Status
     */
    .fifo_half_full(),
    .fifo_watermark(fifo_watermark)
);

assign rx_cpl_tlp_error = 0;

integer seg, lane;
reg valid;

always @* begin
    rx_tlp_data_next = rx_tlp_data_reg;
    rx_tlp_strb_next = rx_tlp_strb_reg;
    rx_tlp_hdr_next = rx_tlp_hdr_reg;
    rx_tlp_bar_id_next = rx_tlp_bar_id_reg;
    rx_tlp_func_num_next = rx_tlp_func_num_reg;
    rx_tlp_valid_next = fifo_tlp_ready ? 0 : rx_tlp_valid_reg;
    rx_tlp_sop_next = rx_tlp_sop_reg;
    rx_tlp_eop_next = rx_tlp_eop_reg;

    for (seg = 0; seg < SEG_COUNT; seg = seg + 1) begin
       // decode framing
        rx_st_strb[SEG_STRB_WIDTH*seg +: SEG_STRB_WIDTH] = {SEG_STRB_WIDTH{1'b1}};
        if (rx_st_eop[seg]) begin
            if (rx_st_sop[seg] && !rx_st_hdr[128*seg+126]) begin
                // Header only
                rx_st_strb[SEG_STRB_WIDTH*seg +: SEG_STRB_WIDTH] = 0;
            end else begin
                // TLP has data
                rx_st_strb[SEG_STRB_WIDTH*seg +: SEG_STRB_WIDTH] = {SEG_STRB_WIDTH{1'b1}} >> rx_st_empty[SEG_EMPTY_WIDTH*seg +: SEG_EMPTY_WIDTH];
            end
        end

        case (rx_st_bar_range[3*seg +: 3])
            3'd6: tlp_bar_id[3*seg +: 3] = IO_BAR_INDEX; // IO BAR
            3'd7: tlp_bar_id[3*seg +: 3] = 6; // expansion ROM BAR
            default: tlp_bar_id[3*seg +: 3] = rx_st_bar_range[3*seg +: 3]; // memory BAR
        endcase

        tlp_func_num[8*seg +: 8] = rx_st_func_num[2*seg +: 2];
    end

    if (fifo_tlp_ready) begin
        rx_tlp_strb_next = 0;
        rx_tlp_valid_next = 0;
        rx_tlp_sop_next = 0;
        rx_tlp_eop_next = 0;
        for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
            if (rx_st_valid[seg]) begin
                rx_tlp_data_next[INT_TLP_SEG_DATA_WIDTH*seg +: INT_TLP_SEG_DATA_WIDTH] = rx_st_data[INT_TLP_SEG_DATA_WIDTH*seg +: INT_TLP_SEG_DATA_WIDTH];
                rx_tlp_strb_next[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH] = rx_st_strb[INT_TLP_SEG_STRB_WIDTH*seg +: INT_TLP_SEG_STRB_WIDTH];
                if (rx_st_sop[seg]) begin
                    rx_tlp_hdr_next[TLP_HDR_WIDTH*seg +: TLP_HDR_WIDTH] = rx_st_hdr[128*seg +: 128];
                    rx_tlp_bar_id_next[3*seg +: 3] = tlp_bar_id[3*seg +: 3];
                    rx_tlp_func_num_next[8*seg +: 8] = tlp_func_num[8*seg +: 8];
                end
                rx_tlp_sop_next[seg] = rx_st_sop[seg];
                rx_tlp_eop_next[seg] = rx_st_eop[seg];
                rx_tlp_valid_next[seg] = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    rx_tlp_data_reg <= rx_tlp_data_next;
    rx_tlp_strb_reg <= rx_tlp_strb_next;
    rx_tlp_hdr_reg <= rx_tlp_hdr_next;
    rx_tlp_bar_id_reg <= rx_tlp_bar_id_next;
    rx_tlp_func_num_reg <= rx_tlp_func_num_next;
    rx_tlp_valid_reg <= rx_tlp_valid_next;
    rx_tlp_sop_reg <= rx_tlp_sop_next;
    rx_tlp_eop_reg <= rx_tlp_eop_next;

    if (rst) begin
        rx_tlp_valid_reg <= 0;
    end
end

endmodule

`resetall
