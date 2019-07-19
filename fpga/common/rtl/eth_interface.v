/*

Copyright 2019, The Regents of the University of California.
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

`timescale 1ns / 1ps

/*
 * Ethernet interface
 */
module eth_interface #
(
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = (DATA_WIDTH/8),
    parameter AXI_DATA_WIDTH = 256,  // width of data bus in bits
    parameter AXI_ADDR_WIDTH = 16,  // width of address bus in bits
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_MAX_BURST_LEN = 16,
    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 8,
    parameter ENABLE_SG = 0,
    parameter ENABLE_UNALIGNED = 0,
    parameter ENABLE_PADDING = 1,
    parameter ENABLE_DIC = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter TX_FIFO_DEPTH = 4096,
    parameter TX_FRAME_FIFO = 1,
    parameter TX_DROP_BAD_FRAME = TX_FRAME_FIFO,
    parameter TX_DROP_WHEN_FULL = 0,
    parameter RX_FIFO_DEPTH = 4096,
    parameter RX_FRAME_FIFO = 1,
    parameter RX_DROP_BAD_FRAME = RX_FRAME_FIFO,
    parameter RX_DROP_WHEN_FULL = RX_FRAME_FIFO,
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter LOGIC_PTP_PERIOD_NS = 4'h6,
    parameter LOGIC_PTP_PERIOD_FNS = 16'h6666,
    parameter PTP_PERIOD_NS = 4'h6,
    parameter PTP_PERIOD_FNS = 16'h6666,
    parameter TX_PTP_TS_ENABLE = 1,
    parameter RX_PTP_TS_ENABLE = 1,
    parameter PTP_TS_WIDTH = 96,
    parameter TX_PTP_TAG_ENABLE = 1,
    parameter PTP_TAG_WIDTH = 16
)
(
    input  wire                       rx_clk,
    input  wire                       rx_rst,
    input  wire                       tx_clk,
    input  wire                       tx_rst,
    input  wire                       logic_clk,
    input  wire                       logic_rst,

    /*
     * Transmit descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_tx_desc_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_tx_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_tx_desc_tag,
    input  wire                       s_axis_tx_desc_user,
    input  wire                       s_axis_tx_desc_valid,
    output wire                       s_axis_tx_desc_ready,

    /*
     * Transmit descriptor status output
     */
    output wire [TAG_WIDTH-1:0]       m_axis_tx_desc_status_tag,
    output wire                       m_axis_tx_desc_status_valid,

    /*
     * Transmit timestamp tag input
     */
    input  wire [PTP_TAG_WIDTH-1:0]   s_axis_tx_ptp_ts_tag,
    input  wire                       s_axis_tx_ptp_ts_valid,
    output wire                       s_axis_tx_ptp_ts_ready,

    /*
     * Transmit timestamp output
     */
    output wire [PTP_TS_WIDTH-1:0]    m_axis_tx_ptp_ts_96,
    output wire [PTP_TAG_WIDTH-1:0]   m_axis_tx_ptp_ts_tag,
    output wire                       m_axis_tx_ptp_ts_valid,
    input  wire                       m_axis_tx_ptp_ts_ready,

    /*
     * Transmit checksum input
     */

    /*
     * Receive descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_rx_desc_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_rx_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_rx_desc_tag,
    input  wire                       s_axis_rx_desc_valid,
    output wire                       s_axis_rx_desc_ready,

    /*
     * Receive descriptor status output
     */
    output wire [LEN_WIDTH-1:0]       m_axis_rx_desc_status_len,
    output wire [TAG_WIDTH-1:0]       m_axis_rx_desc_status_tag,
    output wire                       m_axis_rx_desc_status_user,
    output wire                       m_axis_rx_desc_status_valid,

    /*
     * Receive timestamp output
     */
    output wire [PTP_TS_WIDTH-1:0]    m_axis_rx_ptp_ts_96,
    output wire                       m_axis_rx_ptp_ts_valid,
    input  wire                       m_axis_rx_ptp_ts_ready,

    /*
     * Receive checksum output
     */
    output wire [15:0]                m_axis_rx_csum,
    output wire                       m_axis_rx_csum_valid,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready,

    /*
     * XGMII interface
     */
    input  wire [DATA_WIDTH-1:0]      xgmii_rxd,
    input  wire [CTRL_WIDTH-1:0]      xgmii_rxc,
    output wire [DATA_WIDTH-1:0]      xgmii_txd,
    output wire [CTRL_WIDTH-1:0]      xgmii_txc,

    /*
     * Status
     */
    output wire                       tx_fifo_overflow,
    output wire                       tx_fifo_bad_frame,
    output wire                       tx_fifo_good_frame,
    output wire                       rx_error_bad_frame,
    output wire                       rx_error_bad_fcs,
    output wire                       rx_fifo_overflow,
    output wire                       rx_fifo_bad_frame,
    output wire                       rx_fifo_good_frame,

    /*
     * PTP clock
     */
    input  wire [PTP_TS_WIDTH-1:0]    ptp_ts_96,

    /*
     * Configuration
     */
    input  wire                       tx_enable,
    input  wire                       rx_enable,
    input  wire                       rx_abort,
    input  wire [7:0]                 ifg_delay
);

localparam KEEP_WIDTH = CTRL_WIDTH;

localparam TX_USER_WIDTH = (TX_PTP_TS_ENABLE && TX_PTP_TAG_ENABLE ? PTP_TAG_WIDTH : 0) + 1;
localparam RX_USER_WIDTH = (RX_PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1;

wire [AXI_DATA_WIDTH-1:0] tx_axis_tdata;
wire [AXI_STRB_WIDTH-1:0] tx_axis_tkeep;
wire                      tx_axis_tvalid;
wire                      tx_axis_tready;
wire                      tx_axis_tlast;
wire [TX_USER_WIDTH-1:0]  tx_axis_tuser;

wire [AXI_DATA_WIDTH-1:0] rx_axis_tdata;
wire [AXI_STRB_WIDTH-1:0] rx_axis_tkeep;
wire                      rx_axis_tvalid;
wire                      rx_axis_tready;
wire                      rx_axis_tlast;
wire [RX_USER_WIDTH-1:0]  rx_axis_tuser;

wire [AXI_DATA_WIDTH-1:0] tx_csum_axis_tdata;
wire [AXI_STRB_WIDTH-1:0] tx_csum_axis_tkeep;
wire                      tx_csum_axis_tvalid;
wire                      tx_csum_axis_tready;
wire                      tx_csum_axis_tlast;
wire [TX_USER_WIDTH-1:0]  tx_csum_axis_tuser;

wire [AXI_DATA_WIDTH-1:0] tx_fifo_axis_tdata;
wire [AXI_STRB_WIDTH-1:0] tx_fifo_axis_tkeep;
wire                      tx_fifo_axis_tvalid;
wire                      tx_fifo_axis_tready;
wire                      tx_fifo_axis_tlast;
wire [TX_USER_WIDTH-1:0]  tx_fifo_axis_tuser;

wire [AXI_DATA_WIDTH-1:0] rx_fifo_axis_tdata;
wire [AXI_STRB_WIDTH-1:0] rx_fifo_axis_tkeep;
wire                      rx_fifo_axis_tvalid;
wire                      rx_fifo_axis_tlast;
wire [RX_USER_WIDTH-1:0]  rx_fifo_axis_tuser;

wire [DATA_WIDTH-1:0]    tx_adapt_axis_tdata;
wire [KEEP_WIDTH-1:0]    tx_adapt_axis_tkeep;
wire                     tx_adapt_axis_tvalid;
wire                     tx_adapt_axis_tready;
wire                     tx_adapt_axis_tlast;
wire [TX_USER_WIDTH-1:0] tx_adapt_axis_tuser;

wire [DATA_WIDTH-1:0]    rx_adapt_axis_tdata;
wire [KEEP_WIDTH-1:0]    rx_adapt_axis_tkeep;
wire                     rx_adapt_axis_tvalid;
wire                     rx_adapt_axis_tlast;
wire [RX_USER_WIDTH-1:0] rx_adapt_axis_tuser;

// synchronize MAC status signals into logic clock domain
wire rx_error_bad_frame_int;
wire rx_error_bad_fcs_int;

reg [1:0] rx_sync_reg_1 = 2'd0;
reg [1:0] rx_sync_reg_2 = 2'd0;
reg [1:0] rx_sync_reg_3 = 2'd0;
reg [1:0] rx_sync_reg_4 = 2'd0;

assign rx_error_bad_frame = rx_sync_reg_3[0] ^ rx_sync_reg_4[0];
assign rx_error_bad_fcs = rx_sync_reg_3[1] ^ rx_sync_reg_4[1];

always @(posedge rx_clk or posedge rx_rst) begin
    if (rx_rst) begin
        rx_sync_reg_1 <= 2'd0;
    end else begin
        rx_sync_reg_1 <= rx_sync_reg_1 ^ {rx_error_bad_frame_int, rx_error_bad_frame_int};
    end
end

always @(posedge logic_clk or posedge logic_rst) begin
    if (logic_rst) begin
        rx_sync_reg_2 <= 2'd0;
        rx_sync_reg_3 <= 2'd0;
        rx_sync_reg_4 <= 2'd0;
    end else begin
        rx_sync_reg_2 <= rx_sync_reg_1;
        rx_sync_reg_3 <= rx_sync_reg_2;
        rx_sync_reg_4 <= rx_sync_reg_3;
    end
end

// PTP timestamping
wire [PTP_TS_WIDTH-1:0] tx_ptp_ts_96;

ptp_clock_cdc #(
    .TS_WIDTH(96),
    .NS_WIDTH(4),
    .FNS_WIDTH(16),
    .INPUT_PERIOD_NS(LOGIC_PTP_PERIOD_NS),
    .INPUT_PERIOD_FNS(LOGIC_PTP_PERIOD_FNS),
    .OUTPUT_PERIOD_NS(PTP_PERIOD_NS),
    .OUTPUT_PERIOD_FNS(PTP_PERIOD_FNS),
    .USE_SAMPLE_CLOCK(0)//,
    //.LOG_FIFO_DEPTH(LOG_FIFO_DEPTH),
    //.LOG_RATE(LOG_RATE)
)
tx_ptp_cdc (
    .input_clk(logic_clk),
    .input_rst(logic_rst),
    .output_clk(tx_clk),
    .output_rst(tx_rst),
    .sample_clk(logic_clk),
    .input_ts(ptp_ts_96),
    .output_ts(tx_ptp_ts_96),
    .output_ts_step(),
    .output_pps()
);

wire [PTP_TS_WIDTH-1:0] rx_ptp_ts_96;

ptp_clock_cdc #(
    .TS_WIDTH(96),
    .NS_WIDTH(4),
    .FNS_WIDTH(16),
    .INPUT_PERIOD_NS(LOGIC_PTP_PERIOD_NS),
    .INPUT_PERIOD_FNS(LOGIC_PTP_PERIOD_FNS),
    .OUTPUT_PERIOD_NS(PTP_PERIOD_NS),
    .OUTPUT_PERIOD_FNS(PTP_PERIOD_FNS),
    .USE_SAMPLE_CLOCK(0)//,
    //.LOG_FIFO_DEPTH(LOG_FIFO_DEPTH),
    //.LOG_RATE(LOG_RATE)
)
rx_ptp_cdc (
    .input_clk(logic_clk),
    .input_rst(logic_rst),
    .output_clk(rx_clk),
    .output_rst(rx_rst),
    .sample_clk(logic_clk),
    .input_ts(ptp_ts_96),
    .output_ts(rx_ptp_ts_96),
    .output_ts_step(),
    .output_pps()
);

wire [PTP_TS_WIDTH-1:0] tx_axis_ptp_ts_96;
wire [PTP_TAG_WIDTH-1:0] tx_axis_ptp_ts_tag;
wire tx_axis_ptp_ts_valid;

axis_async_fifo #(
    .DEPTH(64),
    .DATA_WIDTH(PTP_TAG_WIDTH+PTP_TS_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
tx_ptp_ts_fifo (
    .async_rst(logic_rst | tx_rst),

    // AXI input
    .s_clk(tx_clk),
    .s_axis_tdata({tx_axis_ptp_ts_tag, tx_axis_ptp_ts_96}),
    .s_axis_tkeep(0),
    .s_axis_tvalid(tx_axis_ptp_ts_valid),
    .s_axis_tready(),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_clk(logic_clk),
    .m_axis_tdata({m_axis_tx_ptp_ts_tag, m_axis_tx_ptp_ts_96}),
    .m_axis_tkeep(),
    .m_axis_tvalid(m_axis_tx_ptp_ts_valid),
    .m_axis_tready(m_axis_tx_ptp_ts_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
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

wire [PTP_TS_WIDTH-1:0] rx_axis_ptp_ts_96;
wire rx_axis_ptp_ts_valid;

axis_fifo #(
    .DEPTH(64),
    .DATA_WIDTH(PTP_TS_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
rx_ptp_ts_fifo (
    .clk(logic_clk),
    .rst(logic_rst),

    // AXI input
    .s_axis_tdata(rx_axis_ptp_ts_96),
    .s_axis_tkeep(0),
    .s_axis_tvalid(rx_axis_ptp_ts_valid),
    .s_axis_tready(),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_axis_tdata(m_axis_rx_ptp_ts_96),
    .m_axis_tkeep(),
    .m_axis_tvalid(m_axis_rx_ptp_ts_valid),
    .m_axis_tready(m_axis_rx_ptp_ts_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

ptp_ts_extract #(
    .TS_WIDTH(96),
    .TS_OFFSET(1),
    .USER_WIDTH(RX_USER_WIDTH)
)
rx_ptp_ts_extract (
    .clk(logic_clk),
    .rst(logic_rst),

    // AXI stream input
    .s_axis_tvalid(rx_axis_tvalid && rx_axis_tready),
    .s_axis_tlast(rx_axis_tlast),
    .s_axis_tuser(rx_axis_tuser),

    // Timestamp output
    .m_axis_ts(rx_axis_ptp_ts_96),
    .m_axis_ts_valid(rx_axis_ptp_ts_valid)
);

generate

if (RX_CHECKSUM_ENABLE) begin

    rx_checksum #(
        .DATA_WIDTH(AXI_DATA_WIDTH)
    )
    rx_checksum_inst (
        .clk(logic_clk),
        .rst(logic_rst),
        .s_axis_tdata(rx_axis_tdata),
        .s_axis_tkeep(rx_axis_tkeep),
        .s_axis_tvalid(rx_axis_tvalid & rx_axis_tready),
        .s_axis_tlast(rx_axis_tlast),
        .m_axis_csum(m_axis_rx_csum),
        .m_axis_csum_valid(m_axis_rx_csum_valid)
    );

end else begin

    assign m_axis_rx_csum = 16'd0;
    assign m_axis_rx_csum_valid = 1'b0;

end

if (TX_CHECKSUM_ENABLE) begin
    
    assign tx_csum_axis_tdata = tx_axis_tdata;
    assign tx_csum_axis_tkeep = tx_axis_tkeep;
    assign tx_csum_axis_tvalid = tx_axis_tvalid;
    assign tx_axis_tready = tx_csum_axis_tready;
    assign tx_csum_axis_tlast = tx_axis_tlast;
    assign tx_csum_axis_tuser = tx_axis_tuser;

end else begin

    assign tx_csum_axis_tdata = tx_axis_tdata;
    assign tx_csum_axis_tkeep = tx_axis_tkeep;
    assign tx_csum_axis_tvalid = tx_axis_tvalid;
    assign tx_axis_tready = tx_csum_axis_tready;
    assign tx_csum_axis_tlast = tx_axis_tlast;
    assign tx_csum_axis_tuser = tx_axis_tuser;

end

endgenerate

eth_mac_10g #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .ENABLE_PADDING(ENABLE_PADDING),
    .ENABLE_DIC(ENABLE_DIC),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH),
    .PTP_PERIOD_NS(PTP_PERIOD_NS),
    .PTP_PERIOD_FNS(PTP_PERIOD_FNS),
    .TX_PTP_TS_ENABLE(TX_PTP_TS_ENABLE),
    .TX_PTP_TS_WIDTH(PTP_TS_WIDTH),
    .TX_PTP_TAG_ENABLE(TX_PTP_TAG_ENABLE),
    .TX_PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .RX_PTP_TS_ENABLE(RX_PTP_TS_ENABLE),
    .RX_PTP_TS_WIDTH(PTP_TS_WIDTH),
    .TX_USER_WIDTH(TX_USER_WIDTH),
    .RX_USER_WIDTH(RX_USER_WIDTH)
)
eth_mac_10g_inst (
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),

    .tx_axis_tdata(tx_adapt_axis_tdata),
    .tx_axis_tkeep(tx_adapt_axis_tkeep),
    .tx_axis_tvalid(tx_adapt_axis_tvalid),
    .tx_axis_tready(tx_adapt_axis_tready),
    .tx_axis_tlast(tx_adapt_axis_tlast),
    .tx_axis_tuser(tx_adapt_axis_tuser),

    .rx_axis_tdata(rx_adapt_axis_tdata),
    .rx_axis_tkeep(rx_adapt_axis_tkeep),
    .rx_axis_tvalid(rx_adapt_axis_tvalid),
    .rx_axis_tlast(rx_adapt_axis_tlast),
    .rx_axis_tuser(rx_adapt_axis_tuser),

    .xgmii_rxd(xgmii_rxd),
    .xgmii_rxc(xgmii_rxc),
    .xgmii_txd(xgmii_txd),
    .xgmii_txc(xgmii_txc),

    .tx_ptp_ts(tx_ptp_ts_96),
    .rx_ptp_ts(rx_ptp_ts_96),
    .tx_axis_ptp_ts(tx_axis_ptp_ts_96),
    .tx_axis_ptp_ts_tag(tx_axis_ptp_ts_tag),
    .tx_axis_ptp_ts_valid(tx_axis_ptp_ts_valid),

    .tx_start_packet(),
    .rx_start_packet(),
    .rx_error_bad_frame(rx_error_bad_frame_int),
    .rx_error_bad_fcs(rx_error_bad_fcs_int),

    .ifg_delay(ifg_delay)
);

axis_adapter #(
    .S_DATA_WIDTH(AXI_DATA_WIDTH),
    .S_KEEP_ENABLE(1'b1),
    .S_KEEP_WIDTH(AXI_STRB_WIDTH),
    .M_DATA_WIDTH(DATA_WIDTH),
    .M_KEEP_ENABLE(1'b1),
    .M_KEEP_WIDTH(KEEP_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(TX_USER_WIDTH)
)
tx_adapter (
    .clk(tx_clk),
    .rst(tx_rst),
    // AXI input
    .s_axis_tdata(tx_fifo_axis_tdata),
    .s_axis_tkeep(tx_fifo_axis_tkeep),
    .s_axis_tvalid(tx_fifo_axis_tvalid),
    .s_axis_tready(tx_fifo_axis_tready),
    .s_axis_tlast(tx_fifo_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(tx_fifo_axis_tuser),
    // AXI output
    .m_axis_tdata(tx_adapt_axis_tdata),
    .m_axis_tkeep(tx_adapt_axis_tkeep),
    .m_axis_tvalid(tx_adapt_axis_tvalid),
    .m_axis_tready(tx_adapt_axis_tready),
    .m_axis_tlast(tx_adapt_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_adapt_axis_tuser)
);

axis_async_fifo #(
    .DEPTH(TX_FIFO_DEPTH),
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXI_STRB_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(TX_USER_WIDTH),
    .FRAME_FIFO(TX_FRAME_FIFO),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_BAD_FRAME(TX_DROP_BAD_FRAME),
    .DROP_WHEN_FULL(TX_DROP_WHEN_FULL)
)
tx_fifo (
    // Common reset
    .async_rst(logic_rst | tx_rst),
    // AXI input
    .s_clk(logic_clk),
    .s_axis_tdata(tx_csum_axis_tdata),
    .s_axis_tkeep(tx_csum_axis_tkeep),
    .s_axis_tvalid(tx_csum_axis_tvalid),
    .s_axis_tready(tx_csum_axis_tready),
    .s_axis_tlast(tx_csum_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(tx_csum_axis_tuser),
    // AXI output
    .m_clk(tx_clk),
    .m_axis_tdata(tx_fifo_axis_tdata),
    .m_axis_tkeep(tx_fifo_axis_tkeep),
    .m_axis_tvalid(tx_fifo_axis_tvalid),
    .m_axis_tready(tx_fifo_axis_tready),
    .m_axis_tlast(tx_fifo_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_fifo_axis_tuser),
    // Status
    .s_status_overflow(tx_fifo_overflow),
    .s_status_bad_frame(tx_fifo_bad_frame),
    .s_status_good_frame(tx_fifo_good_frame),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

axis_adapter #(
    .S_DATA_WIDTH(DATA_WIDTH),
    .S_KEEP_ENABLE(1),
    .S_KEEP_WIDTH(KEEP_WIDTH),
    .M_DATA_WIDTH(AXI_DATA_WIDTH),
    .M_KEEP_ENABLE(1),
    .M_KEEP_WIDTH(AXI_STRB_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(RX_USER_WIDTH)
)
rx_adapter (
    .clk(rx_clk),
    .rst(rx_rst),
    // AXI input
    .s_axis_tdata(rx_adapt_axis_tdata),
    .s_axis_tkeep(rx_adapt_axis_tkeep),
    .s_axis_tvalid(rx_adapt_axis_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(rx_adapt_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_adapt_axis_tuser),
    // AXI output
    .m_axis_tdata(rx_fifo_axis_tdata),
    .m_axis_tkeep(rx_fifo_axis_tkeep),
    .m_axis_tvalid(rx_fifo_axis_tvalid),
    .m_axis_tready(1'b1),
    .m_axis_tlast(rx_fifo_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(rx_fifo_axis_tuser)
);

axis_async_fifo #(
    .DEPTH(RX_FIFO_DEPTH),
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXI_STRB_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(RX_USER_WIDTH),
    .FRAME_FIFO(RX_FRAME_FIFO),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_BAD_FRAME(RX_DROP_BAD_FRAME),
    .DROP_WHEN_FULL(RX_DROP_WHEN_FULL)
)
rx_fifo (
    // Common reset
    .async_rst(rx_rst | logic_rst),
    // AXI input
    .s_clk(rx_clk),
    .s_axis_tdata(rx_fifo_axis_tdata),
    .s_axis_tkeep(rx_fifo_axis_tkeep),
    .s_axis_tvalid(rx_fifo_axis_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(rx_fifo_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_fifo_axis_tuser),
    // AXI output
    .m_clk(logic_clk),
    .m_axis_tdata(rx_axis_tdata),
    .m_axis_tkeep(rx_axis_tkeep),
    .m_axis_tvalid(rx_axis_tvalid),
    .m_axis_tready(rx_axis_tready),
    .m_axis_tlast(rx_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(rx_axis_tuser),
    // Status
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(rx_fifo_overflow),
    .m_status_bad_frame(rx_fifo_bad_frame),
    .m_status_good_frame(rx_fifo_good_frame)
);

axi_dma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(1),
    .AXIS_KEEP_WIDTH(AXI_STRB_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
)
axi_dma_inst (
    .clk(logic_clk),
    .rst(logic_rst),

    .s_axis_read_desc_addr(s_axis_tx_desc_addr),
    .s_axis_read_desc_len(s_axis_tx_desc_len),
    .s_axis_read_desc_tag(s_axis_tx_desc_tag),
    .s_axis_read_desc_id(0),
    .s_axis_read_desc_dest(0),
    .s_axis_read_desc_user(s_axis_tx_desc_user),
    .s_axis_read_desc_valid(s_axis_tx_desc_valid),
    .s_axis_read_desc_ready(s_axis_tx_desc_ready),

    .m_axis_read_desc_status_tag(m_axis_tx_desc_status_tag),
    .m_axis_read_desc_status_valid(m_axis_tx_desc_status_valid),

    .m_axis_read_data_tdata(tx_axis_tdata),
    .m_axis_read_data_tkeep(tx_axis_tkeep),
    .m_axis_read_data_tvalid(tx_axis_tvalid),
    .m_axis_read_data_tready(tx_axis_tready),
    .m_axis_read_data_tlast(tx_axis_tlast),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(tx_axis_tuser),

    .s_axis_write_desc_addr(s_axis_rx_desc_addr),
    .s_axis_write_desc_len(s_axis_rx_desc_len),
    .s_axis_write_desc_tag(s_axis_rx_desc_tag),
    .s_axis_write_desc_valid(s_axis_rx_desc_valid),
    .s_axis_write_desc_ready(s_axis_rx_desc_ready),

    .m_axis_write_desc_status_len(m_axis_rx_desc_status_len),
    .m_axis_write_desc_status_tag(m_axis_rx_desc_status_tag),
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
    .m_axis_write_desc_status_user(m_axis_rx_desc_status_user),
    .m_axis_write_desc_status_valid(m_axis_rx_desc_status_valid),

    .s_axis_write_data_tdata(rx_axis_tdata),
    .s_axis_write_data_tkeep(rx_axis_tkeep),
    .s_axis_write_data_tvalid(rx_axis_tvalid),
    .s_axis_write_data_tready(rx_axis_tready),
    .s_axis_write_data_tlast(rx_axis_tlast),
    .s_axis_write_data_tid(0),
    .s_axis_write_data_tdest(0),
    .s_axis_write_data_tuser(rx_axis_tuser),

    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    .read_enable(tx_enable),
    .write_enable(rx_enable),
    .write_abort(rx_abort)
);

endmodule
