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
 * PCIe TLP demultiplexer
 */
module pcie_tlp_demux #
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
    parameter TLP_SEG_HDR_WIDTH = 128
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
     * Fields
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]         match_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]                         match_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]                         match_tlp_func_num,

    /*
     * Control
     */
    input  wire                                               enable,
    input  wire [TLP_SEG_COUNT-1:0]                           drop,
    input  wire [TLP_SEG_COUNT*PORTS-1:0]                     select
);

parameter CL_PORTS = $clog2(PORTS);

// check configuration
initial begin
    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_SEG_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end

    if (TLP_SEG_STRB_WIDTH*32 != TLP_SEG_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end
end

reg [CL_PORTS-1:0] select_reg = {CL_PORTS{1'b0}}, select_ctl, select_next;
reg drop_reg = 1'b0, drop_ctl, drop_next;
reg frame_reg = 1'b0, frame_ctl, frame_next;

reg in_tlp_ready_reg = 1'b0, in_tlp_ready_next;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  temp_in_tlp_data_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  temp_in_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   temp_in_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT*3-1:0]                   temp_in_tlp_bar_id_reg = 0;
reg [TLP_SEG_COUNT*8-1:0]                   temp_in_tlp_func_num_reg = 0;
reg [TLP_SEG_COUNT*4-1:0]                   temp_in_tlp_error_reg = 0;
reg [TLP_SEG_COUNT-1:0]                     temp_in_tlp_valid_reg = 1'b0;
reg [TLP_SEG_COUNT-1:0]                     temp_in_tlp_sop_reg = 1'b0;
reg [TLP_SEG_COUNT-1:0]                     temp_in_tlp_eop_reg = 1'b0;

// internal datapath
reg  [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  out_tlp_data_int;
reg  [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  out_tlp_strb_int;
reg  [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   out_tlp_hdr_int;
reg  [TLP_SEG_COUNT*3-1:0]                   out_tlp_bar_id_int;
reg  [TLP_SEG_COUNT*8-1:0]                   out_tlp_func_num_int;
reg  [TLP_SEG_COUNT*4-1:0]                   out_tlp_error_int;
reg  [PORTS*TLP_SEG_COUNT-1:0]               out_tlp_valid_int;
reg  [TLP_SEG_COUNT-1:0]                     out_tlp_sop_int;
reg  [TLP_SEG_COUNT-1:0]                     out_tlp_eop_int;
reg                                          out_tlp_ready_int_reg = 1'b0;
wire                                         out_tlp_ready_int_early;

assign in_tlp_ready = in_tlp_ready_reg && enable;

assign match_tlp_hdr = in_tlp_hdr;
assign match_tlp_bar_id = in_tlp_bar_id;
assign match_tlp_func_num = in_tlp_func_num;

integer i;

always @* begin
    select_next = select_reg;
    select_ctl = select_reg;
    drop_next = drop_reg;
    drop_ctl = drop_reg;
    frame_next = frame_reg;
    frame_ctl = frame_reg;

    in_tlp_ready_next = 1'b0;

    if (in_tlp_valid && in_tlp_ready) begin
        // end of frame detection
        if (in_tlp_eop) begin
            frame_next = 1'b0;
            drop_next = 1'b0;
        end
    end

    if (!frame_reg && in_tlp_valid && in_tlp_ready) begin
        // start of frame, grab select value
        select_ctl = 0;
        drop_ctl = 1'b1;
        frame_ctl = 1'b1;
        for (i = PORTS-1; i >= 0; i = i - 1) begin
            if (select[i]) begin
                select_ctl = i;
                drop_ctl = 1'b0;
            end
        end
        drop_ctl = drop_ctl || drop;
        if (!(in_tlp_ready && in_tlp_valid && in_tlp_eop)) begin
            select_next = select_ctl;
            drop_next = drop_ctl;
            frame_next = 1'b1;
        end
    end

    in_tlp_ready_next = out_tlp_ready_int_early || drop_ctl;

    out_tlp_data_int     = in_tlp_data;
    out_tlp_strb_int     = in_tlp_strb;
    out_tlp_hdr_int      = in_tlp_hdr;
    out_tlp_bar_id_int   = in_tlp_bar_id;
    out_tlp_func_num_int = in_tlp_func_num;
    out_tlp_error_int    = in_tlp_error;
    out_tlp_valid_int    = (in_tlp_valid && in_tlp_ready && !drop_ctl && frame_ctl) << select_ctl;
    out_tlp_sop_int      = in_tlp_sop;
    out_tlp_eop_int      = in_tlp_eop;
end

always @(posedge clk) begin
    select_reg <= select_next;
    drop_reg <= drop_next;
    frame_reg <= frame_next;
    in_tlp_ready_reg <= in_tlp_ready_next;

    if (rst) begin
        select_reg <= 2'd0;
        drop_reg <= 1'b0;
        frame_reg <= 1'b0;
        in_tlp_ready_reg <= 1'b0;
    end
end

// output datapath logic
reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  out_tlp_data_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  out_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   out_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT*3-1:0]                   out_tlp_bar_id_reg = 0;
reg [TLP_SEG_COUNT*8-1:0]                   out_tlp_func_num_reg = 0;
reg [TLP_SEG_COUNT*4-1:0]                   out_tlp_error_reg = 0;
reg [PORTS*TLP_SEG_COUNT-1:0]               out_tlp_valid_reg = 1, out_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                     out_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                     out_tlp_eop_reg = 0;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  temp_out_tlp_data_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  temp_out_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   temp_out_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT*3-1:0]                   temp_out_tlp_bar_id_reg = 0;
reg [TLP_SEG_COUNT*8-1:0]                   temp_out_tlp_func_num_reg = 0;
reg [TLP_SEG_COUNT*4-1:0]                   temp_out_tlp_error_reg = 0;
reg [PORTS*TLP_SEG_COUNT-1:0]               temp_out_tlp_valid_reg = 0, temp_out_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                     temp_out_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                     temp_out_tlp_eop_reg = 0;

// datapath control
reg store_int_to_output;
reg store_int_to_temp;
reg store_temp_to_output;

assign out_tlp_data      = {PORTS{out_tlp_data_reg}};
assign out_tlp_strb      = {PORTS{out_tlp_strb_reg}};
assign out_tlp_hdr       = {PORTS{out_tlp_hdr_reg}};
assign out_tlp_bar_id    = {PORTS{out_tlp_bar_id_reg}};
assign out_tlp_func_num  = {PORTS{out_tlp_func_num_reg}};
assign out_tlp_error     = {PORTS{out_tlp_error_reg}};
assign out_tlp_valid     = out_tlp_valid_reg;
assign out_tlp_sop       = {PORTS{out_tlp_sop_reg}};
assign out_tlp_eop       = {PORTS{out_tlp_eop_reg}};

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign out_tlp_ready_int_early = (out_tlp_ready & out_tlp_valid) || (!temp_out_tlp_valid_reg && (!out_tlp_valid || !out_tlp_valid_int));

always @* begin
    // transfer sink ready state to source
    out_tlp_valid_next = out_tlp_valid_reg;
    temp_out_tlp_valid_next = temp_out_tlp_valid_reg;

    store_int_to_output = 1'b0;
    store_int_to_temp = 1'b0;
    store_temp_to_output = 1'b0;

    if (out_tlp_ready_int_reg) begin
        // input is ready
        if ((out_tlp_ready & out_tlp_valid) || !out_tlp_valid) begin
            // output is ready or currently not valid, transfer data to output
            out_tlp_valid_next = out_tlp_valid_int;
            store_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_out_tlp_valid_next = out_tlp_valid_int;
            store_int_to_temp = 1'b1;
        end
    end else if (out_tlp_ready & out_tlp_valid) begin
        // input is not ready, but output is ready
        out_tlp_valid_next = temp_out_tlp_valid_reg;
        temp_out_tlp_valid_next = 1'b0;
        store_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        out_tlp_valid_reg <= {PORTS{1'b0}};
        out_tlp_ready_int_reg <= 1'b0;
        temp_out_tlp_valid_reg <= 1'b0;
    end else begin
        out_tlp_valid_reg <= out_tlp_valid_next;
        out_tlp_ready_int_reg <= out_tlp_ready_int_early;
        temp_out_tlp_valid_reg <= temp_out_tlp_valid_next;
    end

    // datapath
    if (store_int_to_output) begin
        out_tlp_data_reg <= out_tlp_data_int;
        out_tlp_strb_reg <= out_tlp_strb_int;
        out_tlp_hdr_reg <= out_tlp_hdr_int;
        out_tlp_bar_id_reg <= out_tlp_bar_id_int;
        out_tlp_func_num_reg <= out_tlp_func_num_int;
        out_tlp_error_reg <= out_tlp_error_int;
        out_tlp_sop_reg <= out_tlp_sop_int;
        out_tlp_eop_reg <= out_tlp_eop_int;
    end else if (store_temp_to_output) begin
        out_tlp_data_reg <= temp_out_tlp_data_reg;
        out_tlp_strb_reg <= temp_out_tlp_strb_reg;
        out_tlp_hdr_reg <= temp_out_tlp_hdr_reg;
        out_tlp_bar_id_reg <= temp_out_tlp_bar_id_reg;
        out_tlp_func_num_reg <= temp_out_tlp_func_num_reg;
        out_tlp_error_reg <= temp_out_tlp_error_reg;
        out_tlp_sop_reg <= temp_out_tlp_sop_reg;
        out_tlp_eop_reg <= temp_out_tlp_eop_reg;
    end

    if (store_int_to_temp) begin
        temp_out_tlp_data_reg <= out_tlp_data_int;
        temp_out_tlp_strb_reg <= out_tlp_strb_int;
        temp_out_tlp_hdr_reg <= out_tlp_hdr_int;
        temp_out_tlp_bar_id_reg <= out_tlp_bar_id_int;
        temp_out_tlp_func_num_reg <= out_tlp_func_num_int;
        temp_out_tlp_error_reg <= out_tlp_error_int;
        temp_out_tlp_sop_reg <= out_tlp_sop_int;
        temp_out_tlp_eop_reg <= out_tlp_eop_int;
    end
end

endmodule

`resetall
