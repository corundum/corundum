/*

Copyright 2021, The Regents of the University of California.
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
 * NIC ingress processing
 */
module mqnic_ingress #
(
    // Request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Receive queue index width
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    // Enable RX RSS
    parameter RX_RSS_ENABLE = 1,
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
    parameter AXIS_USER_WIDTH = 1,
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
    input  wire [AXIS_USER_WIDTH-1:0]       s_axis_tuser,

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
    output wire [AXIS_USER_WIDTH-1:0]       m_axis_tuser,

    /*
     * RX command output
     */
    output wire [RX_QUEUE_INDEX_WIDTH-1:0]  rx_req_queue,
    output wire [REQ_TAG_WIDTH-1:0]         rx_req_tag,
    output wire                             rx_req_valid,
    input  wire                             rx_req_ready,

    /*
     * RX hash output
     */
    output wire [31:0]                      rx_hash,
    output wire [3:0]                       rx_hash_type,
    output wire                             rx_hash_valid,
    input  wire                             rx_hash_ready,

    /*
     * RX checksum output
     */
    output wire [15:0]                      rx_csum,
    output wire                             rx_csum_valid,
    input  wire                             rx_csum_ready,

    /*
     * Configuration
     */
    input  wire [31:0]                      rss_mask
);

generate

wire [31:0]  rx_hash_int;
wire [3:0]   rx_hash_type_int;
wire         rx_hash_valid_int;

if (RX_HASH_ENABLE) begin


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
        .m_axis_tdata({rx_hash_type, rx_hash}),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_hash_valid),
        .m_axis_tready(rx_hash_ready),
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

    assign rx_hash = 32'd0;
    assign rx_hash_type = 4'd0;
    assign rx_hash_valid = 1'b0;

end

if (RX_RSS_ENABLE && RX_HASH_ENABLE) begin

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
        .USER_WIDTH(AXIS_USER_WIDTH),
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
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tid(m_axis_tid),
        .m_axis_tdest(m_axis_tdest),
        .m_axis_tuser(m_axis_tuser),

        // Status
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

    // Generate RX requests (RSS)
    assign rx_req_tag = 0;

    axis_fifo #(
        .DEPTH(32),
        .DATA_WIDTH(RX_QUEUE_INDEX_WIDTH),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .FRAME_FIFO(0)
    )
    rx_req_fifo (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(rx_hash_int & rss_mask),
        .s_axis_tkeep(0),
        .s_axis_tvalid(rx_hash_valid_int),
        .s_axis_tready(),
        .s_axis_tlast(0),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        // AXI output
        .m_axis_tdata(rx_req_queue),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_req_valid),
        .m_axis_tready(rx_req_ready),
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

    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tkeep = s_axis_tkeep;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tlast = s_axis_tlast;
    assign m_axis_tid = s_axis_tid;
    assign m_axis_tdest = s_axis_tdest;
    assign m_axis_tuser = s_axis_tuser;

    // Generate RX requests (no RSS)
    reg rx_frame_reg = 1'b0;
    reg rx_req_valid_reg = 1'b0;

    assign rx_req_queue = 0;
    assign rx_req_tag = 0;
    assign rx_req_valid = s_axis_tvalid && !rx_frame_reg;

    always @(posedge clk) begin
        if (rx_req_ready) begin
            rx_req_valid_reg <= 1'b0;
        end

        if (s_axis_tready && s_axis_tvalid) begin
            if (!rx_frame_reg) begin
                rx_req_valid_reg <= 1'b1;
            end
            rx_frame_reg <= !s_axis_tlast;
        end

        if (rst) begin
            rx_frame_reg <= 1'b0;
            rx_req_valid_reg <= 1'b0;
        end
    end

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

endgenerate

endmodule

`resetall
