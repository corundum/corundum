// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC ingress processing
 */
module mqnic_ingress #
(
    // Request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Receive queue index width
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    // Enable RX RSS
    // Enable RX hashing
    parameter RX_HASH_ENABLE = 1,
    // Enable RX checksum offload
    parameter RX_CHECKSUM_ENABLE = 1,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // AXI stream tid signal width
    parameter AXIS_ID_WIDTH = 8,
    // AXI stream tdest signal width
    parameter AXIS_DEST_WIDTH = 8,
    // AXI stream tuser signal width
    parameter S_AXIS_USER_WIDTH = 1,
    // AXI stream tuser signal width
    parameter M_AXIS_USER_WIDTH = S_AXIS_USER_WIDTH,
    // Max receive packet size
    parameter MAX_RX_SIZE = 2048
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
    input  wire [AXIS_ID_WIDTH-1:0]         s_axis_tid,
    input  wire [AXIS_DEST_WIDTH-1:0]       s_axis_tdest,
    input  wire [S_AXIS_USER_WIDTH-1:0]     s_axis_tuser,

    /*
     * Receive data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]       m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]       m_axis_tkeep,
    output wire                             m_axis_tvalid,
    input  wire                             m_axis_tready,
    output wire                             m_axis_tlast,
    output wire [AXIS_ID_WIDTH-1:0]         m_axis_tid,
    output wire [AXIS_DEST_WIDTH-1:0]       m_axis_tdest,
    output wire [M_AXIS_USER_WIDTH-1:0]     m_axis_tuser,

    /*
     * RX checksum output
     */
    output wire [15:0]                      rx_csum,
    output wire                             rx_csum_valid,
    input  wire                             rx_csum_ready
);

localparam RX_HASH_WIDTH = 32;
localparam RX_HASH_TYPE_WIDTH = 4;

localparam TUSER_HASH_OFFSET = S_AXIS_USER_WIDTH;
localparam TUSER_HASH_TYPE_OFFSET = TUSER_HASH_OFFSET + (RX_HASH_ENABLE ? RX_HASH_WIDTH : 0);
localparam INT_TUSER_WIDTH = TUSER_HASH_TYPE_OFFSET + (RX_HASH_ENABLE ? RX_HASH_TYPE_WIDTH : 0);

generate

wire [31:0]  rx_fifo_hash;
wire [3:0]   rx_fifo_hash_type;
wire         rx_fifo_hash_ready;
wire         rx_fifo_hash_valid;

if (RX_HASH_ENABLE) begin

    wire [31:0]  rx_hash_int;
    wire [3:0]   rx_hash_type_int;
    wire         rx_hash_valid_int;

    rx_hash #(
        .DATA_WIDTH(AXIS_DATA_WIDTH)
    )
    rx_hash_inst (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid & s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .hash_key(320'h6d5a56da255b0ec24167253d43a38fb0d0ca2bcbae7b30b477cb2da38030f20c6a42b73bbeac01fa),
        .m_axis_hash(rx_hash_int),
        .m_axis_hash_type(rx_hash_type_int),
        .m_axis_hash_valid(rx_hash_valid_int)
    );

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(32+4),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    rx_hash_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata({rx_hash_type_int, rx_hash_int}),
        .s_axis_tkeep(0),
        .s_axis_tvalid(rx_hash_valid_int),
        .s_axis_tready(),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata({rx_fifo_hash_type, rx_fifo_hash}),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_fifo_hash_valid),
        .m_axis_tready(rx_fifo_hash_ready),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

end else begin

    assign rx_fifo_hash = 32'd0;
    assign rx_fifo_hash_type = 4'd0;
    assign rx_fifo_hash_valid = 1'b0;

end

if (RX_CHECKSUM_ENABLE) begin

    wire [15:0]  rx_csum_int;
    wire         rx_csum_valid_int;

    rx_checksum #(
        .DATA_WIDTH(AXIS_DATA_WIDTH)
    )
    rx_checksum_inst (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid & s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_csum(rx_csum_int),
        .m_axis_csum_valid(rx_csum_valid_int)
    );

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(16),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    rx_csum_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(rx_csum_int),
        .s_axis_tkeep(0),
        .s_axis_tvalid(rx_csum_valid_int),
        .s_axis_tready(),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata(rx_csum),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_csum_valid),
        .m_axis_tready(rx_csum_ready),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

end else begin

    assign rx_csum = 16'd0;
    assign rx_csum_valid = 1'b0;

end

if (RX_HASH_ENABLE) begin

    wire [AXIS_DATA_WIDTH-1:0]    fifo_axis_tdata;
    wire [AXIS_KEEP_WIDTH-1:0]    fifo_axis_tkeep;
    wire                          fifo_axis_tvalid;
    wire                          fifo_axis_tready;
    wire                          fifo_axis_tlast;
    wire [AXIS_ID_WIDTH-1:0]      fifo_axis_tid;
    wire [AXIS_DEST_WIDTH-1:0]    fifo_axis_tdest;
    wire [S_AXIS_USER_WIDTH-1:0]  fifo_axis_tuser;

    axis_fifo #(
        .DEPTH(AXIS_KEEP_WIDTH*32),
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
        .KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .LAST_ENABLE(1),
        .ID_ENABLE(1),
        .ID_WIDTH(AXIS_ID_WIDTH),
        .DEST_ENABLE(1),
        .DEST_WIDTH(AXIS_DEST_WIDTH),
        .USER_ENABLE(1),
        .USER_WIDTH(S_AXIS_USER_WIDTH),
        .FRAME_FIFO(0)
    )
    rx_hash_data_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tid(s_axis_tid),
        .s_axis_tdest(s_axis_tdest),
        .s_axis_tuser(s_axis_tuser),

        // AXI output
        .m_axis_tdata(fifo_axis_tdata),
        .m_axis_tkeep(fifo_axis_tkeep),
        .m_axis_tvalid(fifo_axis_tvalid),
        .m_axis_tready(fifo_axis_tready),
        .m_axis_tlast(fifo_axis_tlast),
        .m_axis_tid(fifo_axis_tid),
        .m_axis_tdest(fifo_axis_tdest),
        .m_axis_tuser(fifo_axis_tuser),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

    wire sideband_valid = rx_fifo_hash_valid;

    assign rx_fifo_hash_ready = fifo_axis_tready && fifo_axis_tvalid && fifo_axis_tlast;

    assign fifo_axis_tready = m_axis_tready && sideband_valid;

    assign m_axis_tdata = fifo_axis_tdata;
    assign m_axis_tkeep = fifo_axis_tkeep;
    assign m_axis_tvalid = fifo_axis_tvalid && sideband_valid;
    assign m_axis_tlast = fifo_axis_tlast;
    assign m_axis_tid = fifo_axis_tid;
    assign m_axis_tdest = fifo_axis_tdest;
    assign m_axis_tuser = {rx_fifo_hash_type, rx_fifo_hash, fifo_axis_tuser};

end else begin

    // bypass
    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tkeep = s_axis_tkeep;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tlast = s_axis_tlast;
    assign m_axis_tid = s_axis_tid;
    assign m_axis_tdest = s_axis_tdest;
    assign m_axis_tuser = s_axis_tuser;

end

endgenerate

endmodule

`resetall
