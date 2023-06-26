// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * MAC PTP TS insert module
 */
module mac_ts_insert #
(
    // PTP TS width
    parameter PTP_TS_WIDTH = 80,
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 512,
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    // input tuser signal width
    parameter S_USER_WIDTH = 1,
    // output tuser signal width
    parameter M_USER_WIDTH = S_USER_WIDTH+PTP_TS_WIDTH
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * PTP TS input
     */
    input  wire [PTP_TS_WIDTH-1:0]  ptp_ts,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]    s_axis_tkeep,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,
    input  wire [S_USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]    m_axis_tkeep,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast,
    output wire [M_USER_WIDTH-1:0]  m_axis_tuser
);

// check configuration
initial begin
    if (KEEP_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

reg [DATA_WIDTH-1:0] axis_tdata_reg = 0;
reg [KEEP_WIDTH-1:0] axis_tkeep_reg = 0;
reg axis_tvalid_reg = 1'b0;
reg axis_tlast_reg = 1'b0;
reg [M_USER_WIDTH-1:0] axis_tuser_reg = 0;

reg frame_reg = 1'b0;

assign s_axis_tready = m_axis_tready;

assign m_axis_tdata = axis_tdata_reg;
assign m_axis_tkeep = axis_tkeep_reg;
assign m_axis_tvalid = axis_tvalid_reg;
assign m_axis_tlast = axis_tlast_reg;
assign m_axis_tuser = axis_tuser_reg;

always @(posedge clk) begin
    if (s_axis_tready) begin
        if (s_axis_tvalid) begin
            frame_reg <= !s_axis_tlast;
        end

        axis_tdata_reg <= s_axis_tdata;
        axis_tkeep_reg <= s_axis_tkeep;
        axis_tvalid_reg <= s_axis_tvalid;
        axis_tlast_reg <= s_axis_tlast;
        axis_tuser_reg[S_USER_WIDTH-1:0] <= s_axis_tuser;

        if (!frame_reg) begin
            axis_tuser_reg[S_USER_WIDTH +: PTP_TS_WIDTH] <= ptp_ts;
        end
    end

    if (rst) begin
        frame_reg <= 1'b0;
        axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
