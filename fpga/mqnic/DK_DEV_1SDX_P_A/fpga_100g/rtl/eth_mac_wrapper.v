/*

Copyright (c) 2022 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Ethernet MAC wrapper
 */
module eth_mac_wrapper #
(
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_TAG_WIDTH = 8,
    parameter DATA_WIDTH = 512,
    parameter KEEP_WIDTH = DATA_WIDTH/8,
    parameter TX_USER_WIDTH = PTP_TAG_WIDTH+1,
    parameter RX_USER_WIDTH = PTP_TS_WIDTH+1
)
(
    input  wire                      ctrl_clk,
    input  wire                      ctrl_rst,

    output wire [3:0]                tx_serial_data_p,
    output wire [3:0]                tx_serial_data_n,
    input  wire [3:0]                rx_serial_data_p,
    input  wire [3:0]                rx_serial_data_n,
    input  wire                      ref_clk,

    output wire                      mac_clk,
    output wire                      mac_rst,

    input  wire [PTP_TS_WIDTH-1:0]   mac_ptp_time,

    output wire [PTP_TS_WIDTH-1:0]   mac_tx_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  mac_tx_ptp_ts_tag,
    output wire                      mac_tx_ptp_ts_valid,

    input  wire [DATA_WIDTH-1:0]     mac_tx_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]     mac_tx_axis_tkeep,
    input  wire                      mac_tx_axis_tvalid,
    output wire                      mac_tx_axis_tready,
    input  wire                      mac_tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]  mac_tx_axis_tuser,

    output wire                      mac_tx_status,
    input  wire                      mac_tx_lfc_req,
    input  wire [7:0]                mac_tx_pfc_req,

    output wire [DATA_WIDTH-1:0]     mac_rx_axis_tdata,
    output wire [KEEP_WIDTH-1:0]     mac_rx_axis_tkeep,
    output wire                      mac_rx_axis_tvalid,
    output wire                      mac_rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]  mac_rx_axis_tuser,

    output wire                      mac_rx_status,
    output wire                      mac_rx_lfc_req,
    output wire [7:0]                mac_rx_pfc_req
);

parameter XCVR_CH = 4;

wire [5:0] mac_pll_clk_d64;
wire [5:0] mac_pll_clk_d66;
wire [5:0] mac_rec_clk_d64;
wire [5:0] mac_rec_clk_d66;

wire mac_tx_pll_locked;

wire [XCVR_CH*19-1:0]  xcvr_reconfig_address;
wire [XCVR_CH-1:0]     xcvr_reconfig_read;
wire [XCVR_CH-1:0]     xcvr_reconfig_write;
wire [XCVR_CH*8-1:0]   xcvr_reconfig_readdata;
wire [XCVR_CH*8-1:0]   xcvr_reconfig_writedata;
wire [XCVR_CH-1:0]     xcvr_reconfig_waitrequest;

wire mac_tx_lanes_stable;
wire mac_rx_pcs_ready;
wire mac_ehip_ready;

wire [PTP_TS_WIDTH-1:0]   mac_ptp_tod;
wire [PTP_TAG_WIDTH-1:0]  mac_ptp_fp;
wire                      mac_ptp_ets_valid;
wire [PTP_TS_WIDTH-1:0]   mac_ptp_ets;
wire [PTP_TAG_WIDTH-1:0]  mac_ptp_ets_fp;
wire [PTP_TS_WIDTH-1:0]   mac_ptp_rx_its;

wire                   mac_tx_ready;
wire                   mac_tx_ready_int;
wire                   mac_tx_valid;
wire [DATA_WIDTH-1:0]  mac_tx_data;
wire                   mac_tx_error;
wire                   mac_tx_startofpacket;
wire                   mac_tx_endofpacket;
wire [5:0]             mac_tx_empty;

wire                   mac_rx_valid;
wire [DATA_WIDTH-1:0]  mac_rx_data;
wire                   mac_rx_startofpacket;
wire                   mac_rx_endofpacket;
wire [5:0]             mac_rx_empty;
wire [5:0]             mac_rx_error;

// register slice to work around E-Tile soft logic bug
// (PTP input signals must be directly driven by "hyperflex-friendly registers")
reg                      mac_tx_valid_reg = 0;
reg [DATA_WIDTH-1:0]     mac_tx_data_reg = 0;
reg                      mac_tx_error_reg = 0;
reg                      mac_tx_startofpacket_reg = 0;
reg                      mac_tx_endofpacket_reg = 0;
reg [5:0]                mac_tx_empty_reg = 0;
reg [PTP_TAG_WIDTH-1:0]  mac_ptp_fp_reg = 0;

always @(posedge mac_clk) begin
    if (mac_tx_ready_int || !mac_tx_valid_reg) begin
        mac_tx_valid_reg <= mac_tx_valid;
        mac_tx_data_reg <= mac_tx_data;
        mac_tx_error_reg <= mac_tx_error;
        mac_tx_startofpacket_reg <= mac_tx_startofpacket;
        mac_tx_endofpacket_reg <= mac_tx_endofpacket;
        mac_tx_empty_reg <= mac_tx_empty;
        mac_ptp_fp_reg <= mac_ptp_fp;
    end

    if (mac_rst) begin
        mac_tx_valid_reg <= 1'b0;
    end
end

assign mac_tx_ready = mac_tx_ready_int || !mac_tx_valid_reg;

mac mac_inst (
    .i_stats_snapshot               (1'b0),
    .o_cdr_lock                     (),
    .o_tx_pll_locked                (mac_tx_pll_locked),
    .i_eth_reconfig_addr            (21'd0),
    .i_eth_reconfig_read            (1'b0),
    .i_eth_reconfig_write           (1'b0),
    .o_eth_reconfig_readdata        (),
    .o_eth_reconfig_readdata_valid  (),
    .i_eth_reconfig_writedata       (32'd0),
    .o_eth_reconfig_waitrequest     (),
    .i_rsfec_reconfig_addr          (11'd0),
    .i_rsfec_reconfig_read          (1'b0),
    .i_rsfec_reconfig_write         (1'b0),
    .o_rsfec_reconfig_readdata      (),
    .i_rsfec_reconfig_writedata     (8'd0),
    .o_rsfec_reconfig_waitrequest   (),
    .i_ptp_reconfig_address         ({2{19'd0}}),
    .i_ptp_reconfig_read            ({2{1'b0}}),
    .i_ptp_reconfig_write           ({2{1'b0}}),
    .o_ptp_reconfig_readdata        (),
    .i_ptp_reconfig_writedata       ({2{8'd0}}),
    .o_ptp_reconfig_waitrequest     (),
    .o_tx_lanes_stable              (mac_tx_lanes_stable),
    .o_rx_pcs_ready                 (mac_rx_pcs_ready),
    .o_ehip_ready                   (mac_ehip_ready),
    .o_rx_block_lock                (),
    .o_rx_am_lock                   (),
    .o_rx_hi_ber                    (),
    .o_local_fault_status           (),
    .o_remote_fault_status          (),
    .i_clk_ref                      (ref_clk),
    .i_clk_tx                       (mac_clk),
    .i_clk_rx                       (mac_clk),
    .o_clk_pll_div64                (mac_pll_clk_d64),
    .o_clk_pll_div66                (mac_pll_clk_d66),
    .o_clk_rec_div64                (mac_rec_clk_d64),
    .o_clk_rec_div66                (mac_rec_clk_d66),
    .i_csr_rst_n                    (!ctrl_rst),
    .i_tx_rst_n                     (mac_tx_pll_locked),
    .i_rx_rst_n                     (mac_tx_pll_locked),
    .o_tx_serial                    (tx_serial_data_p),
    .i_rx_serial                    (rx_serial_data_p),
    .o_tx_serial_n                  (tx_serial_data_n),
    .i_rx_serial_n                  (rx_serial_data_n),
    .i_reconfig_clk                 (ctrl_clk),
    .i_reconfig_reset               (ctrl_rst),
    .i_xcvr_reconfig_address        (xcvr_reconfig_address),
    .i_xcvr_reconfig_read           (xcvr_reconfig_read),
    .i_xcvr_reconfig_write          (xcvr_reconfig_write),
    .o_xcvr_reconfig_readdata       (xcvr_reconfig_readdata),
    .i_xcvr_reconfig_writedata      (xcvr_reconfig_writedata),
    .o_xcvr_reconfig_waitrequest    (xcvr_reconfig_waitrequest),
    .i_ptp_tod                      (mac_ptp_time),
    .i_ptp_ts_req                   (1'b1),
    .i_ptp_fp                       (mac_ptp_fp_reg),
    .o_ptp_ets_valid                (mac_tx_ptp_ts_valid),
    .o_ptp_ets                      (mac_tx_ptp_ts),
    .o_ptp_ets_fp                   (mac_tx_ptp_ts_tag),
    .o_ptp_rx_its                   (mac_ptp_rx_its),
    .o_tx_ptp_ready                 (),
    .o_rx_ptp_ready                 (),
    .i_ptp_ins_ets                  (1'b0),
    .i_ptp_ins_cf                   (1'b0),
    .i_ptp_zero_csum                (1'b0),
    .i_ptp_update_eb                (1'b0),
    .i_ptp_ts_format                (1'b0),
    .i_ptp_ts_offset                (16'd0),
    .i_ptp_cf_offset                (16'd0),
    .i_ptp_csum_offset              (16'd0),
    .i_ptp_eb_offset                (16'd0),
    .i_ptp_tx_its                   (96'd0),
    .o_tx_ready                     (mac_tx_ready_int),
    .i_tx_valid                     (mac_tx_valid_reg),
    .i_tx_data                      (mac_tx_data_reg),
    .i_tx_error                     (mac_tx_error_reg),
    .i_tx_startofpacket             (mac_tx_startofpacket_reg),
    .i_tx_endofpacket               (mac_tx_endofpacket_reg),
    .i_tx_empty                     (mac_tx_empty_reg),
    .i_tx_skip_crc                  (1'b0),
    .o_rx_valid                     (mac_rx_valid),
    .o_rx_data                      (mac_rx_data),
    .o_rx_startofpacket             (mac_rx_startofpacket),
    .o_rx_endofpacket               (mac_rx_endofpacket),
    .o_rx_empty                     (mac_rx_empty),
    .o_rx_error                     (mac_rx_error),
    .o_rxstatus_data                (),
    .o_rxstatus_valid               (),
    .i_tx_pfc                       (mac_tx_pfc_req),
    .o_rx_pfc                       (mac_rx_pfc_req),
    .i_tx_pause                     (mac_tx_lfc_req),
    .o_rx_pause                     (mac_rx_lfc_req)
);

assign mac_clk = mac_pll_clk_d64[4];

assign mac_tx_status = mac_tx_lanes_stable;

assign mac_rx_status = mac_rx_pcs_ready;

sync_reset #(
    .N(4)
)
mac_tx_reset_sync_inst (
    .clk(mac_clk),
    .rst(ctrl_rst || !mac_tx_lanes_stable || !mac_ehip_ready),
    .out(mac_rst)
);

generate

genvar n;

for (n = 0; n < XCVR_CH; n = n + 1) begin : xcvr_ch

    xcvr_ctrl xcvr_ctrl_inst (
        .reconfig_clk(ctrl_clk),
        .reconfig_rst(ctrl_rst),

        .pll_locked_in(mac_tx_pll_locked),

        .xcvr_reconfig_address(xcvr_reconfig_address[n*19 +: 19]),
        .xcvr_reconfig_read(xcvr_reconfig_read[n]),
        .xcvr_reconfig_write(xcvr_reconfig_write[n]),
        .xcvr_reconfig_readdata(xcvr_reconfig_readdata[n*8 +: 8]),
        .xcvr_reconfig_writedata(xcvr_reconfig_writedata[n*8 +: 8]),
        .xcvr_reconfig_waitrequest(xcvr_reconfig_waitrequest[n])
    );

end

endgenerate

axis2avst #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH),
    .KEEP_ENABLE(1),
    .EMPTY_WIDTH(6),
    .BYTE_REVERSE(1)
)
mac_tx_axis2avst (
    .clk(mac_clk),
    .rst(mac_rst),

    .axis_tdata(mac_tx_axis_tdata),
    .axis_tkeep(mac_tx_axis_tkeep),
    .axis_tvalid(mac_tx_axis_tvalid),
    .axis_tready(mac_tx_axis_tready),
    .axis_tlast(mac_tx_axis_tlast),
    .axis_tuser(mac_tx_axis_tuser[0]),

    .avst_ready(mac_tx_ready),
    .avst_valid(mac_tx_valid),
    .avst_data(mac_tx_data),
    .avst_startofpacket(mac_tx_startofpacket),
    .avst_endofpacket(mac_tx_endofpacket),
    .avst_empty(mac_tx_empty),
    .avst_error(mac_tx_error)
);

assign mac_ptp_fp = mac_tx_axis_tuser[1 +: PTP_TAG_WIDTH];

wire [DATA_WIDTH-1:0] mac_rx_axis_tdata_int;
wire [KEEP_WIDTH-1:0] mac_rx_axis_tkeep_int;
wire                  mac_rx_axis_tvalid_int;
wire                  mac_rx_axis_tlast_int;
wire                  mac_rx_axis_tuser_int;

avst2axis #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH),
    .KEEP_ENABLE(1),
    .EMPTY_WIDTH(6),
    .BYTE_REVERSE(1)
)
mac_rx_avst2axis (
    .clk(mac_clk),
    .rst(mac_rst),

    .avst_ready(),
    .avst_valid(mac_rx_valid),
    .avst_data(mac_rx_data),
    .avst_startofpacket(mac_rx_startofpacket),
    .avst_endofpacket(mac_rx_endofpacket),
    .avst_empty(mac_rx_empty),
    .avst_error(mac_rx_error != 0),

    .axis_tdata(mac_rx_axis_tdata_int),
    .axis_tkeep(mac_rx_axis_tkeep_int),
    .axis_tvalid(mac_rx_axis_tvalid_int),
    .axis_tready(1'b1),
    .axis_tlast(mac_rx_axis_tlast_int),
    .axis_tuser(mac_rx_axis_tuser_int)
);

mac_ts_insert #(
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH),
    .S_USER_WIDTH(1),
    .M_USER_WIDTH(PTP_TS_WIDTH+1)
)
mac_ts_insert_inst (
    .clk(mac_clk),
    .rst(mac_rst),

    /*
     * PTP TS input
     */
    .ptp_ts(mac_ptp_rx_its),

    /*
     * AXI input
     */
    .s_axis_tdata(mac_rx_axis_tdata_int),
    .s_axis_tkeep(mac_rx_axis_tkeep_int),
    .s_axis_tvalid(mac_rx_axis_tvalid_int),
    .s_axis_tready(),
    .s_axis_tlast(mac_rx_axis_tlast_int),
    .s_axis_tuser(mac_rx_axis_tuser_int),

    /*
     * AXI output
     */
    .m_axis_tdata(mac_rx_axis_tdata),
    .m_axis_tkeep(mac_rx_axis_tkeep),
    .m_axis_tvalid(mac_rx_axis_tvalid),
    .m_axis_tready(1'b1),
    .m_axis_tlast(mac_rx_axis_tlast),
    .m_axis_tuser(mac_rx_axis_tuser)
);

endmodule

`resetall
