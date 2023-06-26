// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC egress processing
 */
module mqnic_egress #
(
    // Enable TX checksum offload
    parameter TX_CHECKSUM_ENABLE = 1,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // AXI stream tid signal width
    parameter AXIS_ID_WIDTH = 8,
    // AXI stream tdest signal width
    parameter AXIS_DEST_WIDTH = 8,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1,
    // Max transmit packet size
    parameter MAX_TX_SIZE = 2048
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * Transmit data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                        s_axis_tvalid,
    output wire                        s_axis_tready,
    input  wire                        s_axis_tlast,
    input  wire [AXIS_ID_WIDTH-1:0]    s_axis_tid,
    input  wire [AXIS_DEST_WIDTH-1:0]  s_axis_tdest,
    input  wire [AXIS_USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * Transmit data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                        m_axis_tvalid,
    input  wire                        m_axis_tready,
    output wire                        m_axis_tlast,
    output wire [AXIS_ID_WIDTH-1:0]    m_axis_tid,
    output wire [AXIS_DEST_WIDTH-1:0]  m_axis_tdest,
    output wire [AXIS_USER_WIDTH-1:0]  m_axis_tuser,

    /*
     * Transmit checksum command
     */
    input  wire                        tx_csum_cmd_csum_enable,
    input  wire [7:0]                  tx_csum_cmd_csum_start,
    input  wire [7:0]                  tx_csum_cmd_csum_offset,
    input  wire                        tx_csum_cmd_valid,
    output wire                        tx_csum_cmd_ready
);

generate

if (TX_CHECKSUM_ENABLE) begin

    wire        tx_csum_cmd_csum_enable_int;
    wire [7:0]  tx_csum_cmd_csum_start_int;
    wire [7:0]  tx_csum_cmd_csum_offset_int;
    wire        tx_csum_cmd_valid_int;
    wire        tx_csum_cmd_ready_int;

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(1+8+8),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    tx_csum_cmd_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata({tx_csum_cmd_csum_enable, tx_csum_cmd_csum_start, tx_csum_cmd_csum_offset}),
        .s_axis_tkeep(0),
        .s_axis_tvalid(tx_csum_cmd_valid),
        .s_axis_tready(tx_csum_cmd_ready),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata({tx_csum_cmd_csum_enable_int, tx_csum_cmd_csum_start_int, tx_csum_cmd_csum_offset_int}),
        .m_axis_tkeep(),
        .m_axis_tvalid(tx_csum_cmd_valid_int),
        .m_axis_tready(tx_csum_cmd_ready_int),
        .m_axis_tlast(),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

    tx_checksum #(
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .ID_ENABLE(1),
        .ID_WIDTH(AXIS_ID_WIDTH),
        .DEST_ENABLE(1),
        .DEST_WIDTH(AXIS_DEST_WIDTH),
        .USER_ENABLE(1),
        .USER_WIDTH(AXIS_USER_WIDTH),
        .USE_INIT_VALUE(0),
        .DATA_FIFO_DEPTH(MAX_TX_SIZE),
        .CHECKSUM_FIFO_DEPTH(64)
    )
    tx_checksum_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI input
         */
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tid(s_axis_tid),
        .s_axis_tdest(s_axis_tdest),
        .s_axis_tuser(s_axis_tuser),

        /*
         * AXI output
         */
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tid(m_axis_tid),
        .m_axis_tdest(m_axis_tdest),
        .m_axis_tuser(m_axis_tuser),

        /*
         * Control
         */
        .s_axis_cmd_csum_enable(tx_csum_cmd_csum_enable_int),
        .s_axis_cmd_csum_start(tx_csum_cmd_csum_start_int),
        .s_axis_cmd_csum_offset(tx_csum_cmd_csum_offset_int),
        .s_axis_cmd_csum_init(16'd0),
        .s_axis_cmd_valid(tx_csum_cmd_valid_int),
        .s_axis_cmd_ready(tx_csum_cmd_ready_int)
    );

end else begin

    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tkeep = s_axis_tkeep;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tlast = s_axis_tlast;
    assign m_axis_tid = s_axis_tid;
    assign m_axis_tdest = s_axis_tdest;
    assign m_axis_tuser = s_axis_tuser;

    assign tx_csum_cmd_ready = 1'b1;

end

endgenerate

endmodule

`resetall
