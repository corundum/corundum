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
 * NIC port TX path
 */
module mqnic_port_tx #
(
    // PTP configuration
    parameter PTP_TS_WIDTH = 96,

    // Interface configuration
    parameter PTP_TS_ENABLE = 1,
    parameter TX_CPL_ENABLE = 1,
    parameter TX_CPL_FIFO_DEPTH = 32,
    parameter TX_TAG_WIDTH = 16,
    parameter MAX_TX_SIZE = 9214,

    // Application block configuration
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,

    // Streaming interface configuration
    parameter AXIS_DATA_WIDTH = 256,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_TX_PIPELINE = 0,
    parameter AXIS_TX_FIFO_PIPELINE = 2,
    parameter AXIS_TX_TS_PIPELINE = 0,
    parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_SYNC_KEEP_WIDTH = AXIS_SYNC_DATA_WIDTH/8,
    parameter AXIS_SYNC_TX_USER_WIDTH = AXIS_TX_USER_WIDTH
)
(
    input  wire                                clk,
    input  wire                                rst,

    /*
     * Transmit data from interface FIFO
     */
    input  wire [AXIS_SYNC_DATA_WIDTH-1:0]     s_axis_if_tx_tdata,
    input  wire [AXIS_SYNC_KEEP_WIDTH-1:0]     s_axis_if_tx_tkeep,
    input  wire                                s_axis_if_tx_tvalid,
    output wire                                s_axis_if_tx_tready,
    input  wire                                s_axis_if_tx_tlast,
    input  wire [AXIS_SYNC_TX_USER_WIDTH-1:0]  s_axis_if_tx_tuser,

    output wire [PTP_TS_WIDTH-1:0]             m_axis_if_tx_cpl_ts,
    output wire [TX_TAG_WIDTH-1:0]             m_axis_if_tx_cpl_tag,
    output wire                                m_axis_if_tx_cpl_valid,
    input  wire                                m_axis_if_tx_cpl_ready,

    /*
     * Application section datapath interface (synchronous MAC interface)
     */
    output wire [AXIS_SYNC_DATA_WIDTH-1:0]     m_axis_app_sync_tx_tdata,
    output wire [AXIS_SYNC_KEEP_WIDTH-1:0]     m_axis_app_sync_tx_tkeep,
    output wire                                m_axis_app_sync_tx_tvalid,
    input  wire                                m_axis_app_sync_tx_tready,
    output wire                                m_axis_app_sync_tx_tlast,
    output wire [AXIS_SYNC_TX_USER_WIDTH-1:0]  m_axis_app_sync_tx_tuser,

    input  wire [AXIS_SYNC_DATA_WIDTH-1:0]     s_axis_app_sync_tx_tdata,
    input  wire [AXIS_SYNC_KEEP_WIDTH-1:0]     s_axis_app_sync_tx_tkeep,
    input  wire                                s_axis_app_sync_tx_tvalid,
    output wire                                s_axis_app_sync_tx_tready,
    input  wire                                s_axis_app_sync_tx_tlast,
    input  wire [AXIS_SYNC_TX_USER_WIDTH-1:0]  s_axis_app_sync_tx_tuser,

    output wire [PTP_TS_WIDTH-1:0]             m_axis_app_sync_tx_cpl_ts,
    output wire [TX_TAG_WIDTH-1:0]             m_axis_app_sync_tx_cpl_tag,
    output wire                                m_axis_app_sync_tx_cpl_valid,
    input  wire                                m_axis_app_sync_tx_cpl_ready,

    input  wire [PTP_TS_WIDTH-1:0]             s_axis_app_sync_tx_cpl_ts,
    input  wire [TX_TAG_WIDTH-1:0]             s_axis_app_sync_tx_cpl_tag,
    input  wire                                s_axis_app_sync_tx_cpl_valid,
    output wire                                s_axis_app_sync_tx_cpl_ready,

    /*
     * Application section datapath interface (direct MAC interface)
     */
    output wire [AXIS_DATA_WIDTH-1:0]          m_axis_app_direct_tx_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]          m_axis_app_direct_tx_tkeep,
    output wire                                m_axis_app_direct_tx_tvalid,
    input  wire                                m_axis_app_direct_tx_tready,
    output wire                                m_axis_app_direct_tx_tlast,
    output wire [AXIS_TX_USER_WIDTH-1:0]       m_axis_app_direct_tx_tuser,

    input  wire [AXIS_DATA_WIDTH-1:0]          s_axis_app_direct_tx_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]          s_axis_app_direct_tx_tkeep,
    input  wire                                s_axis_app_direct_tx_tvalid,
    output wire                                s_axis_app_direct_tx_tready,
    input  wire                                s_axis_app_direct_tx_tlast,
    input  wire [AXIS_TX_USER_WIDTH-1:0]       s_axis_app_direct_tx_tuser,

    output wire [PTP_TS_WIDTH-1:0]             m_axis_app_direct_tx_cpl_ts,
    output wire [TX_TAG_WIDTH-1:0]             m_axis_app_direct_tx_cpl_tag,
    output wire                                m_axis_app_direct_tx_cpl_valid,
    input  wire                                m_axis_app_direct_tx_cpl_ready,

    input  wire [PTP_TS_WIDTH-1:0]             s_axis_app_direct_tx_cpl_ts,
    input  wire [TX_TAG_WIDTH-1:0]             s_axis_app_direct_tx_cpl_tag,
    input  wire                                s_axis_app_direct_tx_cpl_valid,
    output wire                                s_axis_app_direct_tx_cpl_ready,

    /*
     * Transmit data output
     */
    input  wire                                tx_clk,
    input  wire                                tx_rst,

    output wire [AXIS_DATA_WIDTH-1:0]          m_axis_tx_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]          m_axis_tx_tkeep,
    output wire                                m_axis_tx_tvalid,
    input  wire                                m_axis_tx_tready,
    output wire                                m_axis_tx_tlast,
    output wire [AXIS_TX_USER_WIDTH-1:0]       m_axis_tx_tuser,

    input  wire [PTP_TS_WIDTH-1:0]             s_axis_tx_cpl_ts,
    input  wire [TX_TAG_WIDTH-1:0]             s_axis_tx_cpl_tag,
    input  wire                                s_axis_tx_cpl_valid,
    output wire                                s_axis_tx_cpl_ready
);

initial begin
    if (PTP_TS_ENABLE) begin
        if (!TX_CPL_ENABLE) begin
            $error("Error: PTP timestamping requires TX completions to be enabled (instance %m)");
            $finish;
        end
    end
end

generate

// TX completion FIFO
wire [PTP_TS_WIDTH-1:0] axis_tx_in_cpl_ts;
wire [TX_TAG_WIDTH-1:0] axis_tx_in_cpl_tag;
wire axis_tx_in_cpl_valid;
wire axis_tx_in_cpl_ready;

wire [PTP_TS_WIDTH-1:0] axis_tx_fifo_cpl_ts;
wire [TX_TAG_WIDTH-1:0] axis_tx_fifo_cpl_tag;
wire axis_tx_fifo_cpl_valid;
wire axis_tx_fifo_cpl_ready;

wire [PTP_TS_WIDTH-1:0] axis_tx_pipe_cpl_ts;
wire [TX_TAG_WIDTH-1:0] axis_tx_pipe_cpl_tag;
wire axis_tx_pipe_cpl_valid;
wire axis_tx_pipe_cpl_ready;

if (APP_AXIS_DIRECT_ENABLE) begin

    if (TX_CPL_ENABLE) begin

        assign m_axis_app_direct_tx_cpl_ts = PTP_TS_ENABLE ? s_axis_tx_cpl_ts : 0;
        assign m_axis_app_direct_tx_cpl_tag = s_axis_tx_cpl_tag;
        assign m_axis_app_direct_tx_cpl_valid = s_axis_tx_cpl_valid;
        assign s_axis_tx_cpl_ready = m_axis_app_direct_tx_cpl_ready;

    end else begin

        assign m_axis_app_direct_tx_cpl_ts = 0;
        assign m_axis_app_direct_tx_cpl_tag = m_axis_tx_tuser[1 +: TX_TAG_WIDTH];
        assign m_axis_app_direct_tx_cpl_valid = m_axis_tx_tvalid && m_axis_tx_tready && m_axis_tx_tlast;
        assign s_axis_tx_cpl_ready = 1'b1;

    end

    assign axis_tx_in_cpl_ts = PTP_TS_ENABLE ? s_axis_app_direct_tx_cpl_ts : 0;
    assign axis_tx_in_cpl_tag = s_axis_app_direct_tx_cpl_tag;
    assign axis_tx_in_cpl_valid = s_axis_app_direct_tx_cpl_valid;
    assign s_axis_app_direct_tx_cpl_ready = axis_tx_in_cpl_ready;

end else begin

    assign m_axis_app_direct_tx_cpl_ts = 0;
    assign m_axis_app_direct_tx_cpl_tag = 0;
    assign m_axis_app_direct_tx_cpl_valid = 0;

    assign s_axis_app_direct_tx_cpl_ready = 0;

    if (TX_CPL_ENABLE) begin

        assign axis_tx_in_cpl_ts = PTP_TS_ENABLE ? s_axis_tx_cpl_ts : 0;
        assign axis_tx_in_cpl_tag = s_axis_tx_cpl_tag;
        assign axis_tx_in_cpl_valid = s_axis_tx_cpl_valid;
        assign s_axis_tx_cpl_ready = axis_tx_in_cpl_ready;
        
    end else begin

        assign axis_tx_in_cpl_ts = 0;
        assign axis_tx_in_cpl_tag = m_axis_tx_tuser[1 +: TX_TAG_WIDTH];
        assign axis_tx_in_cpl_valid = m_axis_tx_tvalid && m_axis_tx_tready && m_axis_tx_tlast;
        assign s_axis_tx_cpl_ready = 1'b1;

    end

end

axis_async_fifo #(
    .DEPTH(TX_CPL_FIFO_DEPTH),
    .DATA_WIDTH(PTP_TS_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(1),
    .ID_WIDTH(TX_TAG_WIDTH),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
tx_cpl_fifo_inst (
    // AXI input
    .s_clk(tx_clk),
    .s_rst(tx_rst),
    .s_axis_tdata(axis_tx_in_cpl_ts),
    .s_axis_tkeep(0),
    .s_axis_tvalid(axis_tx_in_cpl_valid),
    .s_axis_tready(axis_tx_in_cpl_ready),
    .s_axis_tlast(0),
    .s_axis_tid(axis_tx_in_cpl_tag),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_clk(clk),
    .m_rst(rst),
    .m_axis_tdata(axis_tx_fifo_cpl_ts),
    .m_axis_tkeep(),
    .m_axis_tvalid(axis_tx_fifo_cpl_valid),
    .m_axis_tready(axis_tx_fifo_cpl_ready),
    .m_axis_tlast(),
    .m_axis_tid(axis_tx_fifo_cpl_tag),
    .m_axis_tdest(),
    .m_axis_tuser(),

    // Status
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

axis_pipeline_fifo #(
    .DATA_WIDTH(PTP_TS_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(1),
    .ID_WIDTH(TX_TAG_WIDTH),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .LENGTH(AXIS_TX_TS_PIPELINE)
)
tx_cpl_pipeline_fifo_inst (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(axis_tx_fifo_cpl_ts),
    .s_axis_tkeep(0),
    .s_axis_tvalid(axis_tx_fifo_cpl_valid),
    .s_axis_tready(axis_tx_fifo_cpl_ready),
    .s_axis_tlast(0),
    .s_axis_tid(axis_tx_fifo_cpl_tag),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_axis_tdata(axis_tx_pipe_cpl_ts),
    .m_axis_tkeep(),
    .m_axis_tvalid(axis_tx_pipe_cpl_valid),
    .m_axis_tready(axis_tx_pipe_cpl_ready),
    .m_axis_tlast(),
    .m_axis_tid(axis_tx_pipe_cpl_tag),
    .m_axis_tdest(),
    .m_axis_tuser()
);

if (APP_AXIS_SYNC_ENABLE) begin

    assign m_axis_app_sync_tx_cpl_ts = PTP_TS_ENABLE ? axis_tx_pipe_cpl_ts : 0;
    assign m_axis_app_sync_tx_cpl_tag = axis_tx_pipe_cpl_tag;
    assign m_axis_app_sync_tx_cpl_valid = axis_tx_pipe_cpl_valid;
    assign axis_tx_pipe_cpl_ready = m_axis_app_sync_tx_cpl_ready;

    assign m_axis_if_tx_cpl_ts = PTP_TS_ENABLE ? s_axis_app_sync_tx_cpl_ts : 0;
    assign m_axis_if_tx_cpl_tag = s_axis_app_sync_tx_cpl_tag;
    assign m_axis_if_tx_cpl_valid = s_axis_app_sync_tx_cpl_valid;
    assign s_axis_app_sync_tx_cpl_ready = m_axis_if_tx_cpl_ready;

end else begin

    assign m_axis_app_sync_tx_cpl_ts = 0;
    assign m_axis_app_sync_tx_cpl_tag = 0;
    assign m_axis_app_sync_tx_cpl_valid = 0;

    assign s_axis_app_sync_tx_cpl_ready = 0;

    assign m_axis_if_tx_cpl_ts = PTP_TS_ENABLE ? axis_tx_pipe_cpl_ts : 0;
    assign m_axis_if_tx_cpl_tag = axis_tx_pipe_cpl_tag;
    assign m_axis_if_tx_cpl_valid = axis_tx_pipe_cpl_valid;
    assign axis_tx_pipe_cpl_ready = m_axis_if_tx_cpl_ready;

end

// TX FIFOs
wire [AXIS_SYNC_DATA_WIDTH-1:0] axis_tx_pipe_tdata;
wire [AXIS_SYNC_KEEP_WIDTH-1:0] axis_tx_pipe_tkeep;
wire axis_tx_pipe_tvalid;
wire axis_tx_pipe_tready;
wire axis_tx_pipe_tlast;
wire [AXIS_TX_USER_WIDTH-1:0] axis_tx_pipe_tuser;

wire [AXIS_SYNC_DATA_WIDTH-1:0] axis_tx_async_fifo_tdata;
wire [AXIS_SYNC_KEEP_WIDTH-1:0] axis_tx_async_fifo_tkeep;
wire axis_tx_async_fifo_tvalid;
wire axis_tx_async_fifo_tready;
wire axis_tx_async_fifo_tlast;
wire [AXIS_TX_USER_WIDTH-1:0] axis_tx_async_fifo_tuser;

wire [AXIS_DATA_WIDTH-1:0] axis_tx_out_tdata;
wire [AXIS_KEEP_WIDTH-1:0] axis_tx_out_tkeep;
wire axis_tx_out_tvalid;
wire axis_tx_out_tready;
wire axis_tx_out_tlast;
wire [AXIS_TX_USER_WIDTH-1:0] axis_tx_out_tuser;

wire [AXIS_DATA_WIDTH-1:0] axis_tx_l2_tdata;
wire [AXIS_KEEP_WIDTH-1:0] axis_tx_l2_tkeep;
wire axis_tx_l2_tvalid;
wire axis_tx_l2_tready;
wire axis_tx_l2_tlast;
wire [AXIS_TX_USER_WIDTH-1:0] axis_tx_l2_tuser;

if (APP_AXIS_SYNC_ENABLE) begin

    assign m_axis_app_sync_tx_tdata = s_axis_if_tx_tdata;
    assign m_axis_app_sync_tx_tkeep = s_axis_if_tx_tkeep;
    assign m_axis_app_sync_tx_tvalid = s_axis_if_tx_tvalid;
    assign s_axis_if_tx_tready = m_axis_app_sync_tx_tready;
    assign m_axis_app_sync_tx_tlast = s_axis_if_tx_tlast;
    assign m_axis_app_sync_tx_tuser = s_axis_if_tx_tuser;

    assign axis_tx_pipe_tdata = s_axis_app_sync_tx_tdata;
    assign axis_tx_pipe_tkeep = s_axis_app_sync_tx_tkeep;
    assign axis_tx_pipe_tvalid = s_axis_app_sync_tx_tvalid;
    assign s_axis_app_sync_tx_tready = axis_tx_pipe_tready;
    assign axis_tx_pipe_tlast = s_axis_app_sync_tx_tlast;
    assign axis_tx_pipe_tuser = s_axis_app_sync_tx_tuser;

end else begin

    assign m_axis_app_sync_tx_tdata = 0;
    assign m_axis_app_sync_tx_tkeep = 0;
    assign m_axis_app_sync_tx_tvalid = 0;
    assign m_axis_app_sync_tx_tlast = 0;
    assign m_axis_app_sync_tx_tuser = 0;

    assign s_axis_app_sync_tx_tready = 0;

    assign axis_tx_pipe_tdata = s_axis_if_tx_tdata;
    assign axis_tx_pipe_tkeep = s_axis_if_tx_tkeep;
    assign axis_tx_pipe_tvalid = s_axis_if_tx_tvalid;
    assign s_axis_if_tx_tready = axis_tx_pipe_tready;
    assign axis_tx_pipe_tlast = s_axis_if_tx_tlast;
    assign axis_tx_pipe_tuser = s_axis_if_tx_tuser;

end

axis_pipeline_fifo #(
    .DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .KEEP_ENABLE(AXIS_SYNC_KEEP_WIDTH > 1),
    .KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_TX_USER_WIDTH),
    .LENGTH(AXIS_TX_PIPELINE)
)
tx_pipeline_fifo_inst (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(axis_tx_pipe_tdata),
    .s_axis_tkeep(axis_tx_pipe_tkeep),
    .s_axis_tvalid(axis_tx_pipe_tvalid),
    .s_axis_tready(axis_tx_pipe_tready),
    .s_axis_tlast(axis_tx_pipe_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(axis_tx_pipe_tuser),

    // AXI output
    .m_axis_tdata(axis_tx_async_fifo_tdata),
    .m_axis_tkeep(axis_tx_async_fifo_tkeep),
    .m_axis_tvalid(axis_tx_async_fifo_tvalid),
    .m_axis_tready(axis_tx_async_fifo_tready),
    .m_axis_tlast(axis_tx_async_fifo_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(axis_tx_async_fifo_tuser)
);

axis_async_fifo_adapter #(
    .DEPTH(MAX_TX_SIZE),
    .S_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .S_KEEP_ENABLE(AXIS_SYNC_KEEP_WIDTH > 1),
    .S_KEEP_WIDTH(AXIS_SYNC_KEEP_WIDTH),
    .M_DATA_WIDTH(AXIS_DATA_WIDTH),
    .M_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
    .M_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_TX_USER_WIDTH),
    .FRAME_FIFO(1),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_BAD_FRAME(1),
    .DROP_WHEN_FULL(0)
)
tx_async_fifo_inst (
    // AXI input
    .s_clk(clk),
    .s_rst(rst),
    .s_axis_tdata(axis_tx_async_fifo_tdata),
    .s_axis_tkeep(axis_tx_async_fifo_tkeep),
    .s_axis_tvalid(axis_tx_async_fifo_tvalid),
    .s_axis_tready(axis_tx_async_fifo_tready),
    .s_axis_tlast(axis_tx_async_fifo_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(axis_tx_async_fifo_tuser),

    // AXI output
    .m_clk(tx_clk),
    .m_rst(tx_rst),
    .m_axis_tdata(axis_tx_out_tdata),
    .m_axis_tkeep(axis_tx_out_tkeep),
    .m_axis_tvalid(axis_tx_out_tvalid),
    .m_axis_tready(axis_tx_out_tready),
    .m_axis_tlast(axis_tx_out_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(axis_tx_out_tuser),

    // Status
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

if (APP_AXIS_DIRECT_ENABLE) begin

    assign m_axis_app_direct_tx_tdata = axis_tx_out_tdata;
    assign m_axis_app_direct_tx_tkeep = axis_tx_out_tkeep;
    assign m_axis_app_direct_tx_tvalid = axis_tx_out_tvalid;
    assign axis_tx_out_tready = m_axis_app_direct_tx_tready;
    assign m_axis_app_direct_tx_tlast = axis_tx_out_tlast;
    assign m_axis_app_direct_tx_tuser = axis_tx_out_tuser;

    assign axis_tx_l2_tdata = s_axis_app_direct_tx_tdata;
    assign axis_tx_l2_tkeep = s_axis_app_direct_tx_tkeep;
    assign axis_tx_l2_tvalid = s_axis_app_direct_tx_tvalid;
    assign s_axis_app_direct_tx_tready = axis_tx_l2_tready;
    assign axis_tx_l2_tlast = s_axis_app_direct_tx_tlast;
    assign axis_tx_l2_tuser = s_axis_app_direct_tx_tuser;

end else begin

    assign m_axis_app_direct_tx_tdata = 0;
    assign m_axis_app_direct_tx_tkeep = 0;
    assign m_axis_app_direct_tx_tvalid = 0;
    assign m_axis_app_direct_tx_tlast = 0;
    assign m_axis_app_direct_tx_tuser = 0;

    assign s_axis_app_direct_tx_tready = 0;

    assign axis_tx_l2_tdata = axis_tx_out_tdata;
    assign axis_tx_l2_tkeep = axis_tx_out_tkeep;
    assign axis_tx_l2_tvalid = axis_tx_out_tvalid;
    assign axis_tx_out_tready = axis_tx_l2_tready;
    assign axis_tx_l2_tlast = axis_tx_out_tlast;
    assign axis_tx_l2_tuser = axis_tx_out_tuser;

end

mqnic_l2_egress #(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_USER_WIDTH(AXIS_TX_USER_WIDTH)
)
mqnic_l2_egress_inst (
    .clk(tx_clk),
    .rst(tx_rst),

    /*
     * Transmit data input
     */
    .s_axis_tdata(axis_tx_l2_tdata),
    .s_axis_tkeep(axis_tx_l2_tkeep),
    .s_axis_tvalid(axis_tx_l2_tvalid),
    .s_axis_tready(axis_tx_l2_tready),
    .s_axis_tlast(axis_tx_l2_tlast),
    .s_axis_tuser(axis_tx_l2_tuser),

    /*
     * Transmit data output
     */
    .m_axis_tdata(m_axis_tx_tdata),
    .m_axis_tkeep(m_axis_tx_tkeep),
    .m_axis_tvalid(m_axis_tx_tvalid),
    .m_axis_tready(m_axis_tx_tready),
    .m_axis_tlast(m_axis_tx_tlast),
    .m_axis_tuser(m_axis_tx_tuser)
);

endgenerate

endmodule

`resetall
