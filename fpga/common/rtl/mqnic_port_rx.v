/*

Copyright 2022, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC port RX path
 */
module mqnic_port_rx #
(
    // PTP configuration
    parameter PTP_TS_WIDTH = 96,

    // Interface configuration
    parameter PTP_TS_ENABLE = 1,
    parameter MAX_RX_SIZE = 9214,

    // Application block configuration
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,

    // Streaming interface configuration
    parameter AXIS_DATA_WIDTH = 256,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_RX_USE_READY = 0,
    parameter AXIS_RX_PIPELINE = 0,
    parameter AXIS_RX_FIFO_PIPELINE = 2,
    parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_SYNC_KEEP_WIDTH = AXIS_SYNC_DATA_WIDTH/8,
    parameter AXIS_SYNC_RX_USER_WIDTH = AXIS_RX_USER_WIDTH
)
(
    input  wire                                clk,
    input  wire                                rst,

    /*
     * Receive data to interface FIFO
     */
    output wire [AXIS_SYNC_DATA_WIDTH-1:0]     m_axis_if_rx_tdata,
    output wire [AXIS_SYNC_KEEP_WIDTH-1:0]     m_axis_if_rx_tkeep,
    output wire                                m_axis_if_rx_tvalid,
    input  wire                                m_axis_if_rx_tready,
    output wire                                m_axis_if_rx_tlast,
    output wire [AXIS_SYNC_RX_USER_WIDTH-1:0]  m_axis_if_rx_tuser,

    /*
     * Application section datapath interface (synchronous MAC interface)
     */
    output wire [AXIS_SYNC_DATA_WIDTH-1:0]     m_axis_app_sync_rx_tdata,
    output wire [AXIS_SYNC_KEEP_WIDTH-1:0]     m_axis_app_sync_rx_tkeep,
    output wire                                m_axis_app_sync_rx_tvalid,
    input  wire                                m_axis_app_sync_rx_tready,
    output wire                                m_axis_app_sync_rx_tlast,
    output wire [AXIS_SYNC_RX_USER_WIDTH-1:0]  m_axis_app_sync_rx_tuser,

    input  wire [AXIS_SYNC_DATA_WIDTH-1:0]     s_axis_app_sync_rx_tdata,
    input  wire [AXIS_SYNC_KEEP_WIDTH-1:0]     s_axis_app_sync_rx_tkeep,
    input  wire                                s_axis_app_sync_rx_tvalid,
    output wire                                s_axis_app_sync_rx_tready,
    input  wire                                s_axis_app_sync_rx_tlast,
    input  wire [AXIS_SYNC_RX_USER_WIDTH-1:0]  s_axis_app_sync_rx_tuser,

    /*
     * Application section datapath interface (direct MAC interface)
     */
    output wire [AXIS_DATA_WIDTH-1:0]          m_axis_app_direct_rx_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]          m_axis_app_direct_rx_tkeep,
    output wire                                m_axis_app_direct_rx_tvalid,
    input  wire                                m_axis_app_direct_rx_tready,
    output wire                                m_axis_app_direct_rx_tlast,
    output wire [AXIS_RX_USER_WIDTH-1:0]       m_axis_app_direct_rx_tuser,

    input  wire [AXIS_DATA_WIDTH-1:0]          s_axis_app_direct_rx_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]          s_axis_app_direct_rx_tkeep,
    input  wire                                s_axis_app_direct_rx_tvalid,
    output wire                                s_axis_app_direct_rx_tready,
    input  wire                                s_axis_app_direct_rx_tlast,
    input  wire [AXIS_RX_USER_WIDTH-1:0]       s_axis_app_direct_rx_tuser,

    /*
     * Receive data input
     */
    input  wire                                rx_clk,
    input  wire                                rx_rst,

    input  wire [AXIS_DATA_WIDTH-1:0]          s_axis_rx_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]          s_axis_rx_tkeep,
    input  wire                                s_axis_rx_tvalid,
    output wire                                s_axis_rx_tready,
    input  wire                                s_axis_rx_tlast,
    input  wire [AXIS_RX_USER_WIDTH-1:0]       s_axis_rx_tuser
);

generate

// RX FIFOs
wire [AXIS_DATA_WIDTH-1:0] axis_rx_l2_tdata;
wire [AXIS_KEEP_WIDTH-1:0] axis_rx_l2_tkeep;
wire axis_rx_l2_tvalid;
wire axis_rx_l2_tready;
wire axis_rx_l2_tlast;
wire [AXIS_RX_USER_WIDTH-1:0] axis_rx_l2_tuser;

wire [AXIS_DATA_WIDTH-1:0] axis_rx_in_tdata;
wire [AXIS_KEEP_WIDTH-1:0] axis_rx_in_tkeep;
wire axis_rx_in_tvalid;
wire axis_rx_in_tready;
wire axis_rx_in_tlast;
wire [AXIS_RX_USER_WIDTH-1:0] axis_rx_in_tuser;

wire [AXIS_SYNC_DATA_WIDTH-1:0] axis_rx_async_fifo_tdata;
wire [AXIS_SYNC_KEEP_WIDTH-1:0] axis_rx_async_fifo_tkeep;
wire axis_rx_async_fifo_tvalid;
wire axis_rx_async_fifo_tready;
wire axis_rx_async_fifo_tlast;
wire [AXIS_RX_USER_WIDTH-1:0] axis_rx_async_fifo_tuser;

wire [AXIS_SYNC_DATA_WIDTH-1:0] axis_rx_pipe_tdata;
wire [AXIS_SYNC_KEEP_WIDTH-1:0] axis_rx_pipe_tkeep;
wire axis_rx_pipe_tvalid;
wire axis_rx_pipe_tready;
wire axis_rx_pipe_tlast;
wire [AXIS_RX_USER_WIDTH-1:0] axis_rx_pipe_tuser;

wire [AXIS_SYNC_DATA_WIDTH-1:0] axis_if_rx_tdata;
wire [AXIS_SYNC_KEEP_WIDTH-1:0] axis_if_rx_tkeep;
wire axis_if_rx_tvalid;
wire axis_if_rx_tready;
wire axis_if_rx_tlast;
wire [AXIS_RX_USER_WIDTH-1:0] axis_if_rx_tuser;

mqnic_l2_ingress #(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_USER_WIDTH(AXIS_RX_USER_WIDTH),
    .AXIS_USE_READY(AXIS_RX_USE_READY)
)
mqnic_l2_ingress_inst (
    .clk(rx_clk),
    .rst(rx_rst),

    /*
     * Receive data input
     */
    .s_axis_tdata(s_axis_rx_tdata),
    .s_axis_tkeep(s_axis_rx_tkeep),
    .s_axis_tvalid(s_axis_rx_tvalid),
    .s_axis_tready(s_axis_rx_tready),
    .s_axis_tlast(s_axis_rx_tlast),
    .s_axis_tuser(s_axis_rx_tuser),

    /*
     * Receive data output
     */
    .m_axis_tdata(axis_rx_l2_tdata),
    .m_axis_tkeep(axis_rx_l2_tkeep),
    .m_axis_tvalid(axis_rx_l2_tvalid),
    .m_axis_tready(axis_rx_l2_tready),
    .m_axis_tlast(axis_rx_l2_tlast),
    .m_axis_tuser(axis_rx_l2_tuser)
);

if (APP_AXIS_DIRECT_ENABLE) begin

    assign m_axis_app_direct_rx_tdata = axis_rx_l2_tdata;
    assign m_axis_app_direct_rx_tkeep = axis_rx_l2_tkeep;
    assign m_axis_app_direct_rx_tvalid = axis_rx_l2_tvalid;
    assign axis_rx_l2_tready = m_axis_app_direct_rx_tready;
    assign m_axis_app_direct_rx_tlast = axis_rx_l2_tlast;
    assign m_axis_app_direct_rx_tuser = axis_rx_l2_tuser;

    assign axis_rx_in_tdata = s_axis_app_direct_rx_tdata;
    assign axis_rx_in_tkeep = s_axis_app_direct_rx_tkeep;
    assign axis_rx_in_tvalid = s_axis_app_direct_rx_tvalid;
    assign s_axis_app_direct_rx_tready = axis_rx_in_tready;
    assign axis_rx_in_tlast = s_axis_app_direct_rx_tlast;
    assign axis_rx_in_tuser = s_axis_app_direct_rx_tuser;

end else begin

    assign m_axis_app_direct_rx_tdata = 0;
    assign m_axis_app_direct_rx_tkeep = 0;
    assign m_axis_app_direct_rx_tvalid = 0;
    assign m_axis_app_direct_rx_tlast = 0;
    assign m_axis_app_direct_rx_tuser = 0;

    assign s_axis_app_direct_rx_tready = 0;

    assign axis_rx_in_tdata = axis_rx_l2_tdata;
    assign axis_rx_in_tkeep = axis_rx_l2_tkeep;
    assign axis_rx_in_tvalid = axis_rx_l2_tvalid;
    assign axis_rx_l2_tready = axis_rx_in_tready;
    assign axis_rx_in_tlast = axis_rx_l2_tlast;
    assign axis_rx_in_tuser = axis_rx_l2_tuser;

end

axis_async_fifo_adapter #(
    .DEPTH(MAX_RX_SIZE),
    .S_DATA_WIDTH(AXIS_DATA_WIDTH),
    .S_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .S_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .M_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .M_KEEP_ENABLE(AXIS_SYNC_KEEP_WIDTH > 1),
    .M_KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_RX_USER_WIDTH),
    .FRAME_FIFO(1),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_BAD_FRAME(1),
    .DROP_WHEN_FULL(!AXIS_RX_USE_READY)
)
rx_async_fifo_inst (
    // AXI input
    .s_clk(rx_clk),
    .s_rst(rx_rst),
    .s_axis_tdata(axis_rx_in_tdata),
    .s_axis_tkeep(axis_rx_in_tkeep),
    .s_axis_tvalid(axis_rx_in_tvalid),
    .s_axis_tready(axis_rx_in_tready),
    .s_axis_tlast(axis_rx_in_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(axis_rx_in_tuser),

    // AXI output
    .m_clk(clk),
    .m_rst(rst),
    .m_axis_tdata(axis_rx_async_fifo_tdata),
    .m_axis_tkeep(axis_rx_async_fifo_tkeep),
    .m_axis_tvalid(axis_rx_async_fifo_tvalid),
    .m_axis_tready(axis_rx_async_fifo_tready),
    .m_axis_tlast(axis_rx_async_fifo_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(axis_rx_async_fifo_tuser),

    // Status
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

axis_pipeline_fifo #(
    .DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .KEEP_ENABLE(AXIS_SYNC_KEEP_WIDTH > 1),
    .KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_RX_USER_WIDTH),
    .LENGTH(AXIS_RX_PIPELINE)
)
rx_pipeline_fifo_inst (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(axis_rx_async_fifo_tdata),
    .s_axis_tkeep(axis_rx_async_fifo_tkeep),
    .s_axis_tvalid(axis_rx_async_fifo_tvalid),
    .s_axis_tready(axis_rx_async_fifo_tready),
    .s_axis_tlast(axis_rx_async_fifo_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(axis_rx_async_fifo_tuser),

    // AXI output
    .m_axis_tdata(axis_rx_pipe_tdata),
    .m_axis_tkeep(axis_rx_pipe_tkeep),
    .m_axis_tvalid(axis_rx_pipe_tvalid),
    .m_axis_tready(axis_rx_pipe_tready),
    .m_axis_tlast(axis_rx_pipe_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(axis_rx_pipe_tuser)
);

if (APP_AXIS_SYNC_ENABLE) begin

    assign m_axis_app_sync_rx_tdata = axis_rx_pipe_tdata;
    assign m_axis_app_sync_rx_tkeep = axis_rx_pipe_tkeep;
    assign m_axis_app_sync_rx_tvalid = axis_rx_pipe_tvalid;
    assign axis_rx_pipe_tready = m_axis_app_sync_rx_tready;
    assign m_axis_app_sync_rx_tlast = axis_rx_pipe_tlast;
    assign m_axis_app_sync_rx_tuser = axis_rx_pipe_tuser;

    assign m_axis_if_rx_tdata = s_axis_app_sync_rx_tdata;
    assign m_axis_if_rx_tkeep = s_axis_app_sync_rx_tkeep;
    assign m_axis_if_rx_tvalid = s_axis_app_sync_rx_tvalid;
    assign s_axis_app_sync_rx_tready = m_axis_if_rx_tready;
    assign m_axis_if_rx_tlast = s_axis_app_sync_rx_tlast;
    assign m_axis_if_rx_tuser = s_axis_app_sync_rx_tuser;

end else begin

    assign m_axis_app_sync_rx_tdata = 0;
    assign m_axis_app_sync_rx_tkeep = 0;
    assign m_axis_app_sync_rx_tvalid = 0;
    assign m_axis_app_sync_rx_tlast = 0;
    assign m_axis_app_sync_rx_tuser = 0;

    assign s_axis_app_sync_rx_tready = 0;

    assign m_axis_if_rx_tdata = axis_rx_pipe_tdata;
    assign m_axis_if_rx_tkeep = axis_rx_pipe_tkeep;
    assign m_axis_if_rx_tvalid = axis_rx_pipe_tvalid;
    assign axis_rx_pipe_tready = m_axis_if_rx_tready;
    assign m_axis_if_rx_tlast = axis_rx_pipe_tlast;
    assign m_axis_if_rx_tuser = axis_rx_pipe_tuser;

end

endgenerate

endmodule

`resetall
