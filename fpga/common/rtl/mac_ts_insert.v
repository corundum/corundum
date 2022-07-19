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
