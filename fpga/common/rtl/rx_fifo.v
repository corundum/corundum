// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * RX FIFO
 */
module rx_fifo #
(
    // FIFO depth in words (each FIFO)
    // KEEP_WIDTH words per cycle if KEEP_ENABLE set
    // Rounded up to nearest power of 2 cycles
    parameter FIFO_DEPTH = 4096,
    // Width of FIFO depth status signals
    parameter FIFO_DEPTH_WIDTH = $clog2(FIFO_DEPTH)+1,
    // Number of AXI stream inputs
    parameter PORTS = 4,
    // Width of input AXI stream interfaces in bits
    parameter S_DATA_WIDTH = 8,
    // Propagate tkeep signal
    parameter S_KEEP_ENABLE = (S_DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter S_KEEP_WIDTH = (S_DATA_WIDTH/8),
    // Width of output AXI stream interface in bits
    parameter M_DATA_WIDTH = 8*PORTS,
    // Propagate tkeep signal
    parameter M_KEEP_ENABLE = (M_DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter M_KEEP_WIDTH = (M_DATA_WIDTH/8),
    // Propagate tid signal
    parameter ID_ENABLE = 1,
    // input tid signal width
    parameter S_ID_WIDTH = 1,
    // output tid signal width
    parameter M_ID_WIDTH = PORTS > 1 ? $clog2(PORTS) : 1,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // number of RAM pipeline registers
    parameter RAM_PIPELINE = 1
)
(
    input  wire                               clk,
    input  wire                               rst,

    /*
     * AXI Stream inputs
     */
    input  wire [PORTS*S_DATA_WIDTH-1:0]      s_axis_tdata,
    input  wire [PORTS*S_KEEP_WIDTH-1:0]      s_axis_tkeep,
    input  wire [PORTS-1:0]                   s_axis_tvalid,
    output wire [PORTS-1:0]                   s_axis_tready,
    input  wire [PORTS-1:0]                   s_axis_tlast,
    input  wire [PORTS*S_ID_WIDTH-1:0]        s_axis_tid,
    input  wire [PORTS*DEST_WIDTH-1:0]        s_axis_tdest,
    input  wire [PORTS*USER_WIDTH-1:0]        s_axis_tuser,

    /*
     * AXI Stream output
     */
    output wire [M_DATA_WIDTH-1:0]            m_axis_tdata,
    output wire [M_KEEP_WIDTH-1:0]            m_axis_tkeep,
    output wire                               m_axis_tvalid,
    input  wire                               m_axis_tready,
    output wire                               m_axis_tlast,
    output wire [M_ID_WIDTH-1:0]              m_axis_tid,
    output wire [DEST_WIDTH-1:0]              m_axis_tdest,
    output wire [USER_WIDTH-1:0]              m_axis_tuser,

    /*
     * Status
     */
    output wire [FIFO_DEPTH_WIDTH*PORTS-1:0]  status_depth,
    output wire [FIFO_DEPTH_WIDTH*PORTS-1:0]  status_depth_commit,
    output wire [PORTS-1:0]                   status_overflow,
    output wire [PORTS-1:0]                   status_bad_frame,
    output wire [PORTS-1:0]                   status_good_frame
);

wire [PORTS*M_DATA_WIDTH-1:0]  axis_fifo_tdata;
wire [PORTS*M_KEEP_WIDTH-1:0]  axis_fifo_tkeep;
wire [PORTS-1:0]               axis_fifo_tvalid;
wire [PORTS-1:0]               axis_fifo_tready;
wire [PORTS-1:0]               axis_fifo_tlast;
wire [PORTS*S_ID_WIDTH-1:0]    axis_fifo_tid;
wire [PORTS*DEST_WIDTH-1:0]    axis_fifo_tdest;
wire [PORTS*USER_WIDTH-1:0]    axis_fifo_tuser;

generate

genvar n;

for (n = 0; n < PORTS; n = n + 1) begin : fifo

    axis_fifo_adapter #(
        .DEPTH(FIFO_DEPTH),
        .S_DATA_WIDTH(S_DATA_WIDTH),
        .S_KEEP_ENABLE(S_KEEP_ENABLE),
        .S_KEEP_WIDTH(S_KEEP_WIDTH),
        .M_DATA_WIDTH(M_DATA_WIDTH),
        .M_KEEP_ENABLE(M_KEEP_ENABLE),
        .M_KEEP_WIDTH(M_KEEP_WIDTH),
        .ID_ENABLE(ID_ENABLE),
        .ID_WIDTH(S_ID_WIDTH),
        .DEST_ENABLE(DEST_ENABLE),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_ENABLE(USER_ENABLE),
        .USER_WIDTH(USER_WIDTH),
        .RAM_PIPELINE(RAM_PIPELINE),
        .FRAME_FIFO(1),
        .USER_BAD_FRAME_VALUE(1'b1),
        .USER_BAD_FRAME_MASK(1'b1),
        .DROP_OVERSIZE_FRAME(1),
        .DROP_BAD_FRAME(USER_ENABLE),
        .DROP_WHEN_FULL(0),
        .MARK_WHEN_FULL(0),
        .PAUSE_ENABLE(0),
        .FRAME_PAUSE(1)
    )
    fifo_inst (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(s_axis_tdata[n*S_DATA_WIDTH +: S_DATA_WIDTH]),
        .s_axis_tkeep(s_axis_tkeep[n*S_KEEP_WIDTH +: S_KEEP_WIDTH]),
        .s_axis_tvalid(s_axis_tvalid[n +: 1]),
        .s_axis_tready(s_axis_tready[n +: 1]),
        .s_axis_tlast(s_axis_tlast[n +: 1]),
        .s_axis_tid(s_axis_tid[n*S_ID_WIDTH +: S_ID_WIDTH]),
        .s_axis_tdest(s_axis_tdest[n*DEST_WIDTH +: DEST_WIDTH]),
        .s_axis_tuser(s_axis_tuser[n*USER_WIDTH +: USER_WIDTH]),

        // AXI output
        .m_axis_tdata(axis_fifo_tdata[n*M_DATA_WIDTH +: M_DATA_WIDTH]),
        .m_axis_tkeep(axis_fifo_tkeep[n*M_KEEP_WIDTH +: M_KEEP_WIDTH]),
        .m_axis_tvalid(axis_fifo_tvalid[n +: 1]),
        .m_axis_tready(axis_fifo_tready[n +: 1]),
        .m_axis_tlast(axis_fifo_tlast[n +: 1]),
        .m_axis_tid(axis_fifo_tid[n*S_ID_WIDTH +: S_ID_WIDTH]),
        .m_axis_tdest(axis_fifo_tdest[n*DEST_WIDTH +: DEST_WIDTH]),
        .m_axis_tuser(axis_fifo_tuser[n*USER_WIDTH +: USER_WIDTH]),

        // Pause
        .pause_req(1'b0),
        .pause_ack(),

        // Status
        .status_depth(status_depth[n*FIFO_DEPTH_WIDTH +: FIFO_DEPTH_WIDTH]),
        .status_depth_commit(status_depth_commit[n*FIFO_DEPTH_WIDTH +: FIFO_DEPTH_WIDTH]),
        .status_overflow(status_overflow[n]),
        .status_bad_frame(status_bad_frame[n]),
        .status_good_frame(status_good_frame[n])
    );

end

if (PORTS > 1) begin : mux

    axis_arb_mux #(
        .S_COUNT(PORTS),
        .DATA_WIDTH(M_DATA_WIDTH),
        .KEEP_ENABLE(M_KEEP_ENABLE),
        .KEEP_WIDTH(M_KEEP_WIDTH),
        .ID_ENABLE(ID_ENABLE),
        .S_ID_WIDTH(S_ID_WIDTH),
        .M_ID_WIDTH(M_ID_WIDTH),
        .DEST_ENABLE(DEST_ENABLE),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_ENABLE(USER_ENABLE),
        .USER_WIDTH(USER_WIDTH),
        .LAST_ENABLE(1'b1),
        .UPDATE_TID(1),
        .ARB_TYPE_ROUND_ROBIN(1'b1),
        .ARB_LSB_HIGH_PRIORITY(1'b1)
    )
    mux_inst (
        .clk(clk),
        .rst(rst),

        // AXI Stream inputs
        .s_axis_tdata(axis_fifo_tdata),
        .s_axis_tkeep(axis_fifo_tkeep),
        .s_axis_tvalid(axis_fifo_tvalid),
        .s_axis_tready(axis_fifo_tready),
        .s_axis_tlast(axis_fifo_tlast),
        .s_axis_tid(axis_fifo_tid),
        .s_axis_tdest(axis_fifo_tdest),
        .s_axis_tuser(axis_fifo_tuser),

        // AXI Stream output
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tid(m_axis_tid),
        .m_axis_tdest(m_axis_tdest),
        .m_axis_tuser(m_axis_tuser)
    );

end else begin

    assign m_axis_tdata = axis_fifo_tdata;
    assign m_axis_tkeep = axis_fifo_tkeep;
    assign m_axis_tvalid = axis_fifo_tvalid;
    assign axis_fifo_tready = m_axis_tready;
    assign m_axis_tlast = axis_fifo_tlast;
    assign m_axis_tid = axis_fifo_tid;
    assign m_axis_tdest = axis_fifo_tdest;
    assign m_axis_tuser = axis_fifo_tuser;

end

endgenerate

endmodule

`resetall
