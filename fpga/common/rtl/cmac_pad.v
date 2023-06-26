// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * CMAC frame pad module
 */
module cmac_pad #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 512,
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    // tuser signal width
    parameter USER_WIDTH = 1
)
(
    input  wire                   clk,
    input  wire                   rst,
    
    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [USER_WIDTH-1:0]  m_axis_tuser
);

// check configuration
initial begin
    if (DATA_WIDTH != 512) begin
        $error("Error: AXI stream data width must be 512 (instance %m)");
        $finish;
    end

    if (KEEP_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

reg frame_reg = 1'b0;

generate
    genvar k;

    for (k = 0; k < KEEP_WIDTH; k = k + 1) begin
        assign m_axis_tdata[k*8 +: 8] = s_axis_tkeep[k] ? s_axis_tdata[k*8 +: 8] : 8'd0;
    end
endgenerate

assign m_axis_tkeep = (frame_reg ? {KEEP_WIDTH{1'b0}} : {60{1'b1}}) | s_axis_tkeep;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tuser = s_axis_tuser;

always @(posedge clk) begin
    if (s_axis_tvalid && s_axis_tready) begin
        frame_reg <= !s_axis_tlast;
    end

    if (rst) begin
        frame_reg <= 1'b0;
    end
end

endmodule

`resetall
