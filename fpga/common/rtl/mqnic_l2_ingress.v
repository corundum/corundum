// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC layer 2 ingress processing
 */
module mqnic_l2_ingress #
(
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1,
    // Can apply backpressure with tready
    parameter AXIS_USE_READY = 0
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * Receive data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]       s_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]       s_axis_tkeep,
    input  wire                             s_axis_tvalid,
    output wire                             s_axis_tready,
    input  wire                             s_axis_tlast,
    input  wire [AXIS_USER_WIDTH-1:0]       s_axis_tuser,

    /*
     * Receive data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]       m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]       m_axis_tkeep,
    output wire                             m_axis_tvalid,
    input  wire                             m_axis_tready,
    output wire                             m_axis_tlast,
    output wire [AXIS_USER_WIDTH-1:0]       m_axis_tuser
);

// placeholder
assign m_axis_tdata = s_axis_tdata;
assign m_axis_tkeep = s_axis_tkeep;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tuser = s_axis_tuser;

endmodule

`resetall
