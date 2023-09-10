// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC layer 2 egress processing
 */
module mqnic_l2_egress #
(
    // Interface configuration
    parameter PFC_ENABLE = 0,
    parameter LFC_ENABLE = PFC_ENABLE,
    parameter MAC_CTRL_ENABLE = 0,

    // Streaming interface configuration
    parameter AXIS_DATA_WIDTH = 256,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_USER_WIDTH = 1
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
    input  wire [AXIS_USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * Transmit data output
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
    input  wire                        tx_lfc_en,
    input  wire                        tx_lfc_req,
    input  wire [7:0]                  tx_pfc_en,
    input  wire [7:0]                  tx_pfc_req,
    input  wire                        tx_pause_req,
    output wire                        tx_pause_ack,
    input  wire [9:0]                  tx_fc_quanta_step,
    input  wire                        tx_fc_quanta_clk_en
);

if ((LFC_ENABLE || PFC_ENABLE) && MAC_CTRL_ENABLE) begin : mac_ctrl

    localparam MCF_PARAMS_SIZE = PFC_ENABLE ? 18 : 2;

    wire                          tx_mcf_valid;
    wire                          tx_mcf_ready;
    wire [47:0]                   tx_mcf_eth_dst;
    wire [47:0]                   tx_mcf_eth_src;
    wire [15:0]                   tx_mcf_eth_type;
    wire [15:0]                   tx_mcf_opcode;
    wire [MCF_PARAMS_SIZE*8-1:0]  tx_mcf_params;

    mac_ctrl_tx #(
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
        .KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(1),
        .USER_WIDTH(AXIS_USER_WIDTH),
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
    )
    mac_ctrl_tx_inst (
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
        .mcf_valid(tx_mcf_valid),
        .mcf_ready(tx_mcf_ready),
        .mcf_eth_dst(tx_mcf_eth_dst),
        .mcf_eth_src(tx_mcf_eth_src),
        .mcf_eth_type(tx_mcf_eth_type),
        .mcf_opcode(tx_mcf_opcode),
        .mcf_params(tx_mcf_params),
        .mcf_id(0),
        .mcf_dest(0),
        .mcf_user(0),

        /*
         * Pause interface
         */
        .tx_pause_req(tx_pause_req),
        .tx_pause_ack(tx_pause_ack),

        /*
         * Status
         */
        .stat_tx_mcf()
    );

    mac_pause_ctrl_tx #(
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE),
        .PFC_ENABLE(PFC_ENABLE)
    )
    mac_pause_ctrl_tx_inst (
        .clk(clk),
        .rst(rst),

        /*
         * MAC control frame interface
         */
        .mcf_valid(tx_mcf_valid),
        .mcf_ready(tx_mcf_ready),
        .mcf_eth_dst(tx_mcf_eth_dst),
        .mcf_eth_src(tx_mcf_eth_src),
        .mcf_eth_type(tx_mcf_eth_type),
        .mcf_opcode(tx_mcf_opcode),
        .mcf_params(tx_mcf_params),

        /*
         * Pause (IEEE 802.3 annex 31B)
         */
        .tx_lfc_req(tx_lfc_req),
        .tx_lfc_resend(1'b0),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D)
         */
        .tx_pfc_req(tx_pfc_req),
        .tx_pfc_resend(1'b0),

        /*
         * Configuration
         */
        .cfg_tx_lfc_eth_dst(48'h01_80_C2_00_00_01),
        .cfg_tx_lfc_eth_src(48'h80_23_31_43_54_4C),
        .cfg_tx_lfc_eth_type(16'h8808),
        .cfg_tx_lfc_opcode(16'h0001),
        .cfg_tx_lfc_en(tx_lfc_en),
        .cfg_tx_lfc_quanta(16'hffff),
        .cfg_tx_lfc_refresh(16'h7fff),
        .cfg_tx_pfc_eth_dst(48'h01_80_C2_00_00_01),
        .cfg_tx_pfc_eth_src(48'h80_23_31_43_54_4C),
        .cfg_tx_pfc_eth_type(16'h8808),
        .cfg_tx_pfc_opcode(16'h0101),
        .cfg_tx_pfc_en(tx_pfc_en),
        .cfg_tx_pfc_quanta({8{16'hffff}}),
        .cfg_tx_pfc_refresh({8{16'h7fff}}),
        .cfg_quanta_step(tx_fc_quanta_step),
        .cfg_quanta_clk_en(tx_fc_quanta_clk_en),

        /*
         * Status
         */
        .stat_tx_lfc_pkt(),
        .stat_tx_lfc_xon(),
        .stat_tx_lfc_xoff(),
        .stat_tx_lfc_paused(),
        .stat_tx_pfc_pkt(),
        .stat_tx_pfc_xon(),
        .stat_tx_pfc_xoff(),
        .stat_tx_pfc_paused()
    );

end else begin

    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tkeep = s_axis_tkeep;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tlast = s_axis_tlast;
    assign m_axis_tuser = s_axis_tuser;

    assign tx_pause_ack = 1'b0;

end

endmodule

`resetall
