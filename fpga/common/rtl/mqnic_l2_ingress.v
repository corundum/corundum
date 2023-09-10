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
    // Interface configuration
    parameter PFC_ENABLE = 0,
    parameter LFC_ENABLE = PFC_ENABLE,
    parameter MAC_CTRL_ENABLE = 0,

    // Streaming interface configuration
    parameter AXIS_DATA_WIDTH = 256,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_USER_WIDTH = 1,
    parameter AXIS_USE_READY = 0
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * Receive data input
     */
    input  wire [AXIS_DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                        s_axis_tvalid,
    output wire                        s_axis_tready,
    input  wire                        s_axis_tlast,
    input  wire [AXIS_USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * Receive data output
     */
    output wire [AXIS_DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                        m_axis_tvalid,
    input  wire                        m_axis_tready,
    output wire                        m_axis_tlast,
    output wire [AXIS_USER_WIDTH-1:0]  m_axis_tuser,

    /*
     * Flow control
     */
    input  wire                        rx_lfc_en,
    output wire                        rx_lfc_req,
    input  wire                        rx_lfc_ack,
    input  wire [7:0]                  rx_pfc_en,
    output wire [7:0]                  rx_pfc_req,
    input  wire [7:0]                  rx_pfc_ack,
    input  wire [9:0]                  rx_fc_quanta_step,
    input  wire                        rx_fc_quanta_clk_en
);

if ((LFC_ENABLE || PFC_ENABLE) && MAC_CTRL_ENABLE) begin : mac_ctrl

    localparam MCF_PARAMS_SIZE = PFC_ENABLE ? 18 : 2;

    wire                          rx_mcf_valid;
    wire [47:0]                   rx_mcf_eth_dst;
    wire [47:0]                   rx_mcf_eth_src;
    wire [15:0]                   rx_mcf_eth_type;
    wire [15:0]                   rx_mcf_opcode;
    wire [MCF_PARAMS_SIZE*8-1:0]  rx_mcf_params;

    mac_ctrl_rx #(
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
        .KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(1),
        .USER_WIDTH(AXIS_USER_WIDTH),
        .USE_READY(AXIS_USE_READY),
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
    )
    mac_ctrl_rx_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI stream input
         */
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(s_axis_tuser),

        /*
         * AXI stream output
         */
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(m_axis_tuser),

        /*
         * MAC control frame interface
         */
        .mcf_valid(rx_mcf_valid),
        .mcf_eth_dst(rx_mcf_eth_dst),
        .mcf_eth_src(rx_mcf_eth_src),
        .mcf_eth_type(rx_mcf_eth_type),
        .mcf_opcode(rx_mcf_opcode),
        .mcf_params(rx_mcf_params),
        .mcf_id(),
        .mcf_dest(),
        .mcf_user(),

        /*
         * Configuration
         */
        .cfg_mcf_rx_eth_dst_mcast(48'h01_80_C2_00_00_01),
        .cfg_mcf_rx_check_eth_dst_mcast(1'b1),
        .cfg_mcf_rx_eth_dst_ucast(48'd0),
        .cfg_mcf_rx_check_eth_dst_ucast(1'b0),
        .cfg_mcf_rx_eth_src(48'd0),
        .cfg_mcf_rx_check_eth_src(1'b0),
        .cfg_mcf_rx_eth_type(16'h8808),
        .cfg_mcf_rx_opcode_lfc(16'h0001),
        .cfg_mcf_rx_check_opcode_lfc(rx_lfc_en),
        .cfg_mcf_rx_opcode_pfc(16'h0101),
        .cfg_mcf_rx_check_opcode_pfc(rx_pfc_en != 0),
        .cfg_mcf_rx_forward(1'b0),
        .cfg_mcf_rx_enable(rx_lfc_en || rx_pfc_en),

        /*
         * Status
         */
        .stat_rx_mcf()
    );

    mac_pause_ctrl_rx #(
        .MCF_PARAMS_SIZE(18),
        .PFC_ENABLE(PFC_ENABLE)
    )
    mac_pause_ctrl_rx_inst (
        .clk(clk),
        .rst(rst),

        /*
         * MAC control frame interface
         */
        .mcf_valid(rx_mcf_valid),
        .mcf_eth_dst(rx_mcf_eth_dst),
        .mcf_eth_src(rx_mcf_eth_src),
        .mcf_eth_type(rx_mcf_eth_type),
        .mcf_opcode(rx_mcf_opcode),
        .mcf_params(rx_mcf_params),

        /*
         * Pause (IEEE 802.3 annex 31B)
         */
        .rx_lfc_en(rx_lfc_en),
        .rx_lfc_req(rx_lfc_req),
        .rx_lfc_ack(rx_lfc_ack),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D)
         */
        .rx_pfc_en(rx_pfc_en),
        .rx_pfc_req(rx_pfc_req),
        .rx_pfc_ack(rx_pfc_ack),

        /*
         * Configuration
         */
        .cfg_rx_lfc_opcode(16'h0001),
        .cfg_rx_lfc_en(rx_lfc_en),
        .cfg_rx_pfc_opcode(16'h0101),
        .cfg_rx_pfc_en(rx_pfc_en),
        .cfg_quanta_step(rx_fc_quanta_step),
        .cfg_quanta_clk_en(rx_fc_quanta_clk_en),

        /*
         * Status
         */
        .stat_rx_lfc_pkt(),
        .stat_rx_lfc_xon(),
        .stat_rx_lfc_xoff(),
        .stat_rx_lfc_paused(),
        .stat_rx_pfc_pkt(),
        .stat_rx_pfc_xon(),
        .stat_rx_pfc_xoff(),
        .stat_rx_pfc_paused()
    );

end else begin

    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tkeep = s_axis_tkeep;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tlast = s_axis_tlast;
    assign m_axis_tuser = s_axis_tuser;

    assign rx_lfc_req = 1'b0;
    assign rx_pfc_req = 8'd0;

end

endmodule

`resetall
