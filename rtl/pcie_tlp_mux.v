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
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = 256,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                                               clk,
    input  wire                                               rst,

    /*
     * TLP input
     */
    input  wire [PORTS*TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  in_tlp_data,
    input  wire [PORTS*TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  in_tlp_strb,
    input  wire [PORTS*TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   in_tlp_hdr,
    input  wire [PORTS*TLP_SEG_COUNT*3-1:0]                   in_tlp_bar_id,
    input  wire [PORTS*TLP_SEG_COUNT*8-1:0]                   in_tlp_func_num,
    input  wire [PORTS*TLP_SEG_COUNT*4-1:0]                   in_tlp_error,
    input  wire [PORTS*TLP_SEG_COUNT-1:0]                     in_tlp_valid,
    input  wire [PORTS*TLP_SEG_COUNT-1:0]                     in_tlp_sop,
    input  wire [PORTS*TLP_SEG_COUNT-1:0]                     in_tlp_eop,
    output wire [PORTS-1:0]                                   in_tlp_ready,

    /*
     * TLP output
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]        out_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]        out_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]         out_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]                         out_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]                         out_tlp_func_num,
    output wire [TLP_SEG_COUNT*4-1:0]                         out_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                           out_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                           out_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                           out_tlp_eop,
    input  wire                                               out_tlp_ready
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

wire [PORTS-1:0] request;
wire [PORTS-1:0] acknowledge;
wire [PORTS-1:0] grant;
wire grant_valid;
wire [CL_PORTS-1:0] grant_encoded;

// internal datapath
reg  [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  out_tlp_data_int;
reg  [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  out_tlp_strb_int;
reg  [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   out_tlp_hdr_int;
reg  [TLP_SEG_COUNT*3-1:0]                   out_tlp_bar_id_int;
reg  [TLP_SEG_COUNT*8-1:0]                   out_tlp_func_num_int;
reg  [TLP_SEG_COUNT*4-1:0]                   out_tlp_error_int;
reg  [TLP_SEG_COUNT-1:0]                     out_tlp_valid_int;
reg  [TLP_SEG_COUNT-1:0]                     out_tlp_sop_int;
reg  [TLP_SEG_COUNT-1:0]                     out_tlp_eop_int;
reg                                          out_tlp_ready_int_reg = 1'b0;
wire                                         out_tlp_ready_int_early;

assign in_tlp_ready = (out_tlp_ready_int_reg && grant_valid) << grant_encoded;

// mux for incoming packet
wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  current_in_tlp_data     = in_tlp_data[grant_encoded*TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH +: TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH];
wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  current_in_tlp_strb     = in_tlp_strb[grant_encoded*TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH +: TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH];
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   current_in_tlp_hdr      = in_tlp_hdr[grant_encoded*TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH +: TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH];
wire [TLP_SEG_COUNT*3-1:0]                   current_in_tlp_bar_id   = in_tlp_bar_id[grant_encoded*TLP_SEG_COUNT*3 +: TLP_SEG_COUNT*3];
wire [TLP_SEG_COUNT*8-1:0]                   current_in_tlp_func_num = in_tlp_func_num[grant_encoded*TLP_SEG_COUNT*8 +: TLP_SEG_COUNT*8];
wire [TLP_SEG_COUNT*4-1:0]                   current_in_tlp_error    = in_tlp_error[grant_encoded*TLP_SEG_COUNT*4 +: TLP_SEG_COUNT*4];
wire [TLP_SEG_COUNT-1:0]                     current_in_tlp_valid    = in_tlp_valid[grant_encoded*TLP_SEG_COUNT +: TLP_SEG_COUNT];
wire [TLP_SEG_COUNT-1:0]                     current_in_tlp_sop      = in_tlp_sop[grant_encoded*TLP_SEG_COUNT +: TLP_SEG_COUNT];
wire [TLP_SEG_COUNT-1:0]                     current_in_tlp_eop      = in_tlp_eop[grant_encoded*TLP_SEG_COUNT +: TLP_SEG_COUNT];
wire                                         current_in_tlp_ready    = in_tlp_ready[grant_encoded];

// arbiter instance
arbiter #(
    .PORTS(PORTS),
    .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
arb_inst (
    .clk(clk),
    .rst(rst),
    .request(request),
    .acknowledge(acknowledge),
    .grant(grant),
    .grant_valid(grant_valid),
    .grant_encoded(grant_encoded)
);

assign request = in_tlp_valid & ~grant;
assign acknowledge = grant & in_tlp_valid & in_tlp_ready & in_tlp_eop;

always @* begin
    // pass through selected packet data
    out_tlp_data_int  = current_in_tlp_data;
    out_tlp_strb_int  = current_in_tlp_strb;
    out_tlp_hdr_int  = current_in_tlp_hdr;
    out_tlp_bar_id_int  = current_in_tlp_bar_id;
    out_tlp_func_num_int  = current_in_tlp_func_num;
    out_tlp_error_int  = current_in_tlp_error;
    out_tlp_valid_int = out_tlp_ready_int_reg && grant_valid ? current_in_tlp_valid : 0;
    out_tlp_sop_int  = current_in_tlp_sop;
    out_tlp_eop_int  = current_in_tlp_eop;
end

// output datapath logic
reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  out_tlp_data_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  out_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   out_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT*3-1:0]                   out_tlp_bar_id_reg = 0;
reg [TLP_SEG_COUNT*8-1:0]                   out_tlp_func_num_reg = 0;
reg [TLP_SEG_COUNT*4-1:0]                   out_tlp_error_reg = 0;
reg [TLP_SEG_COUNT-1:0]                     out_tlp_valid_reg = 0, out_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                     out_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                     out_tlp_eop_reg = 0;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  temp_out_tlp_data_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  temp_out_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   temp_out_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT*3-1:0]                   temp_out_tlp_bar_id_reg = 0;
reg [TLP_SEG_COUNT*8-1:0]                   temp_out_tlp_func_num_reg = 0;
reg [TLP_SEG_COUNT*4-1:0]                   temp_out_tlp_error_reg = 0;
reg [TLP_SEG_COUNT-1:0]                     temp_out_tlp_valid_reg = 0, temp_out_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                     temp_out_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                     temp_out_tlp_eop_reg = 0;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign out_tlp_data      = out_tlp_data_reg;
assign out_tlp_strb      = out_tlp_strb_reg;
assign out_tlp_hdr       = out_tlp_hdr_reg;
assign out_tlp_bar_id    = out_tlp_bar_id_reg;
assign out_tlp_func_num  = out_tlp_func_num_reg;
assign out_tlp_error     = out_tlp_error_reg;
assign out_tlp_valid     = out_tlp_valid_reg;
assign out_tlp_sop       = out_tlp_sop_reg;
assign out_tlp_eop       = out_tlp_eop_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign out_tlp_ready_int_early = out_tlp_ready || (!temp_out_tlp_valid_reg && (!out_tlp_valid_reg || !out_tlp_valid_int));

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
    if (rst) begin
        out_tlp_valid_reg <= 1'b0;
        out_tlp_ready_int_reg <= 1'b0;
        temp_out_tlp_valid_reg <= 1'b0;
    end else begin
        out_tlp_valid_reg <= out_tlp_valid_next;
        out_tlp_ready_int_reg <= out_tlp_ready_int_early;
        temp_out_tlp_valid_reg <= temp_out_tlp_valid_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        out_tlp_data_reg <= out_tlp_data_int;
        out_tlp_strb_reg <= out_tlp_strb_int;
        out_tlp_hdr_reg <= out_tlp_hdr_int;
        out_tlp_bar_id_reg <= out_tlp_bar_id_int;
        out_tlp_func_num_reg <= out_tlp_func_num_int;
        out_tlp_error_reg <= out_tlp_error_int;
        out_tlp_sop_reg <= out_tlp_sop_int;
        out_tlp_eop_reg <= out_tlp_eop_int;
    end else if (store_axis_temp_to_output) begin
        out_tlp_data_reg <= temp_out_tlp_data_reg;
        out_tlp_strb_reg <= temp_out_tlp_strb_reg;
        out_tlp_hdr_reg <= temp_out_tlp_hdr_reg;
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
        temp_out_tlp_bar_id_reg <= out_tlp_bar_id_int;
        temp_out_tlp_func_num_reg <= out_tlp_func_num_int;
        temp_out_tlp_error_reg <= out_tlp_error_int;
        temp_out_tlp_sop_reg <= out_tlp_sop_int;
        temp_out_tlp_eop_reg <= out_tlp_eop_int;
    end
end

endmodule

`resetall
