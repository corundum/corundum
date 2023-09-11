// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * TX FIFO
 */
module tx_fifo #
(
    // FIFO depth in words (each FIFO)
    // KEEP_WIDTH words per cycle if KEEP_ENABLE set
    // Rounded up to nearest power of 2 cycles
    parameter FIFO_DEPTH = 4096,
    // Width of FIFO depth status signals
    parameter FIFO_DEPTH_WIDTH = $clog2(FIFO_DEPTH)+1,
    // Number of AXI stream outputs
    parameter PORTS = 4,
    // Width of input AXI stream interfaces in bits
    parameter S_DATA_WIDTH = 8,
    // Propagate tkeep signal
    parameter S_KEEP_ENABLE = (S_DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter S_KEEP_WIDTH = (S_DATA_WIDTH/8),
    // Width of output AXI stream interfaces in bits
    parameter M_DATA_WIDTH = 8,
    // Propagate tkeep signal
    parameter M_KEEP_ENABLE = (M_DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter M_KEEP_WIDTH = (M_DATA_WIDTH/8),
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // output tdest signal width
    parameter M_DEST_WIDTH = 3,
    // input tdest signal width
    // must be wide enough to uniquely address outputs
    parameter S_DEST_WIDTH = M_DEST_WIDTH+$clog2(PORTS),
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
     * AXI Stream input
     */
    input  wire [S_DATA_WIDTH-1:0]            s_axis_tdata,
    input  wire [S_KEEP_WIDTH-1:0]            s_axis_tkeep,
    input  wire                               s_axis_tvalid,
    output wire                               s_axis_tready,
    input  wire                               s_axis_tlast,
    input  wire [ID_WIDTH-1:0]                s_axis_tid,
    input  wire [S_DEST_WIDTH-1:0]            s_axis_tdest,
    input  wire [USER_WIDTH-1:0]              s_axis_tuser,

    /*
     * AXI Stream outputs
     */
    output wire [PORTS*M_DATA_WIDTH-1:0]      m_axis_tdata,
    output wire [PORTS*M_KEEP_WIDTH-1:0]      m_axis_tkeep,
    output wire [PORTS-1:0]                   m_axis_tvalid,
    input  wire [PORTS-1:0]                   m_axis_tready,
    output wire [PORTS-1:0]                   m_axis_tlast,
    output wire [PORTS*ID_WIDTH-1:0]          m_axis_tid,
    output wire [PORTS*M_DEST_WIDTH-1:0]      m_axis_tdest,
    output wire [PORTS*USER_WIDTH-1:0]        m_axis_tuser,

    /*
     * Status
     */
    output wire [FIFO_DEPTH_WIDTH*PORTS-1:0]  status_depth,
    output wire [FIFO_DEPTH_WIDTH*PORTS-1:0]  status_depth_commit,
    output wire [PORTS-1:0]                   status_overflow,
    output wire [PORTS-1:0]                   status_bad_frame,
    output wire [PORTS-1:0]                   status_good_frame
);

wire [PORTS*S_DATA_WIDTH-1:0]  axis_fifo_tdata;
wire [PORTS*S_KEEP_WIDTH-1:0]  axis_fifo_tkeep;
wire [PORTS-1:0]               axis_fifo_tvalid;
wire [PORTS-1:0]               axis_fifo_tready;
wire [PORTS-1:0]               axis_fifo_tlast;
wire [PORTS*ID_WIDTH-1:0]      axis_fifo_tid;
wire [PORTS*M_DEST_WIDTH-1:0]  axis_fifo_tdest;
wire [PORTS*USER_WIDTH-1:0]    axis_fifo_tuser;

generate

genvar n;

if (PORTS > 1) begin : demux
    
    axis_demux #(
        .M_COUNT(PORTS),
        .DATA_WIDTH(S_DATA_WIDTH),
        .KEEP_ENABLE(S_KEEP_ENABLE),
        .KEEP_WIDTH(S_KEEP_WIDTH),
        .ID_ENABLE(ID_ENABLE),
        .ID_WIDTH(ID_WIDTH),
        .DEST_ENABLE(1),
        .S_DEST_WIDTH(S_DEST_WIDTH),
        .M_DEST_WIDTH(M_DEST_WIDTH),
        .USER_ENABLE(USER_ENABLE),
        .USER_WIDTH(USER_WIDTH),
        .TDEST_ROUTE(1)
    )
    switch_inst (
        .clk(clk),
        .rst(rst),

        // AXI Stream input
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tid(s_axis_tid),
        .s_axis_tdest(s_axis_tdest),
        .s_axis_tuser(s_axis_tuser),

        // AXI Stream outputs
        .m_axis_tdata(axis_fifo_tdata),
        .m_axis_tkeep(axis_fifo_tkeep),
        .m_axis_tvalid(axis_fifo_tvalid),
        .m_axis_tready(axis_fifo_tready),
        .m_axis_tlast(axis_fifo_tlast),
        .m_axis_tid(axis_fifo_tid),
        .m_axis_tdest(axis_fifo_tdest),
        .m_axis_tuser(axis_fifo_tuser),

        // Control
        .enable(1),
        .drop(0),
        .select(0)
    );

end else begin

    assign axis_fifo_tdata = s_axis_tdata;
    assign axis_fifo_tkeep = s_axis_tkeep;
    assign axis_fifo_tvalid = s_axis_tvalid;
    assign s_axis_tready = axis_fifo_tready;
    assign axis_fifo_tlast = s_axis_tlast;
    assign axis_fifo_tid = s_axis_tid;
    assign axis_fifo_tdest = s_axis_tdest;
    assign axis_fifo_tuser = s_axis_tuser;

end

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
        .ID_WIDTH(ID_WIDTH),
        .DEST_ENABLE(1),
        .DEST_WIDTH(M_DEST_WIDTH),
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
        .s_axis_tdata(axis_fifo_tdata[n*S_DATA_WIDTH +: S_DATA_WIDTH]),
        .s_axis_tkeep(axis_fifo_tkeep[n*S_KEEP_WIDTH +: S_KEEP_WIDTH]),
        .s_axis_tvalid(axis_fifo_tvalid[n +: 1]),
        .s_axis_tready(axis_fifo_tready[n +: 1]),
        .s_axis_tlast(axis_fifo_tlast[n +: 1]),
        .s_axis_tid(axis_fifo_tid[n*ID_WIDTH +: ID_WIDTH]),
        .s_axis_tdest(axis_fifo_tdest[n*M_DEST_WIDTH +: M_DEST_WIDTH]),
        .s_axis_tuser(axis_fifo_tuser[n*USER_WIDTH +: USER_WIDTH]),

        // AXI output
        .m_axis_tdata(m_axis_tdata[n*M_DATA_WIDTH +: M_DATA_WIDTH]),
        .m_axis_tkeep(m_axis_tkeep[n*M_KEEP_WIDTH +: M_KEEP_WIDTH]),
        .m_axis_tvalid(m_axis_tvalid[n +: 1]),
        .m_axis_tready(m_axis_tready[n +: 1]),
        .m_axis_tlast(m_axis_tlast[n +: 1]),
        .m_axis_tid(m_axis_tid[n*ID_WIDTH +: ID_WIDTH]),
        .m_axis_tdest(m_axis_tdest[n*M_DEST_WIDTH +: M_DEST_WIDTH]),
        .m_axis_tuser(m_axis_tuser[n*USER_WIDTH +: USER_WIDTH]),

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

endgenerate

endmodule

`resetall
