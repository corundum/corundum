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
 * Testbench for tx_checksum
 */
module test_tx_checksum_256;

// Parameters
parameter DATA_WIDTH = 256;
parameter KEEP_WIDTH = (DATA_WIDTH/8);
parameter ID_ENABLE = 0;
parameter ID_WIDTH = 8;
parameter DEST_ENABLE = 0;
parameter DEST_WIDTH = 8;
parameter USER_ENABLE = 1;
parameter USER_WIDTH = 1;
parameter USE_INIT_VALUE = 1;
parameter DATA_FIFO_DEPTH = 4096;
parameter CHECKSUM_FIFO_DEPTH = 4;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [DATA_WIDTH-1:0] s_axis_tdata = 0;
reg [KEEP_WIDTH-1:0] s_axis_tkeep = 0;
reg s_axis_tvalid = 0;
reg s_axis_tlast = 0;
reg [ID_WIDTH-1:0] s_axis_tid = 0;
reg [DEST_WIDTH-1:0] s_axis_tdest = 0;
reg [USER_WIDTH-1:0] s_axis_tuser = 0;
reg m_axis_tready = 0;
reg s_axis_cmd_csum_enable = 0;
reg [7:0] s_axis_cmd_csum_start = 0;
reg [7:0] s_axis_cmd_csum_offset = 0;
reg [15:0] s_axis_cmd_csum_init = 0;
reg s_axis_cmd_valid = 0;

// Outputs
wire s_axis_tready;
wire [DATA_WIDTH-1:0] m_axis_tdata;
wire [KEEP_WIDTH-1:0] m_axis_tkeep;
wire m_axis_tvalid;
wire m_axis_tlast;
wire [ID_WIDTH-1:0] m_axis_tid;
wire [DEST_WIDTH-1:0] m_axis_tdest;
wire [USER_WIDTH-1:0] m_axis_tuser;
wire s_axis_cmd_ready;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_tdata,
        s_axis_tkeep,
        s_axis_tvalid,
        s_axis_tlast,
        s_axis_tid,
        s_axis_tdest,
        s_axis_tuser,
        m_axis_tready,
        s_axis_cmd_csum_enable,
        s_axis_cmd_csum_start,
        s_axis_cmd_csum_offset,
        s_axis_cmd_csum_init,
        s_axis_cmd_valid
    );
    $to_myhdl(
        s_axis_tready,
        m_axis_tdata,
        m_axis_tkeep,
        m_axis_tvalid,
        m_axis_tlast,
        m_axis_tid,
        m_axis_tdest,
        m_axis_tuser,
        s_axis_cmd_ready
    );

    // dump file
    $dumpfile("test_tx_checksum_256.lxt");
    $dumpvars(0, test_tx_checksum_256);
end

tx_checksum #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH),
    .ID_ENABLE(ID_ENABLE),
    .ID_WIDTH(ID_WIDTH),
    .DEST_ENABLE(DEST_ENABLE),
    .DEST_WIDTH(DEST_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(USER_WIDTH),
    .USE_INIT_VALUE(USE_INIT_VALUE),
    .DATA_FIFO_DEPTH(DATA_FIFO_DEPTH),
    .CHECKSUM_FIFO_DEPTH(CHECKSUM_FIFO_DEPTH)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tid(s_axis_tid),
    .s_axis_tdest(s_axis_tdest),
    .s_axis_tuser(s_axis_tuser),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tid(m_axis_tid),
    .m_axis_tdest(m_axis_tdest),
    .m_axis_tuser(m_axis_tuser),
    .s_axis_cmd_csum_enable(s_axis_cmd_csum_enable),
    .s_axis_cmd_csum_start(s_axis_cmd_csum_start),
    .s_axis_cmd_csum_offset(s_axis_cmd_csum_offset),
    .s_axis_cmd_csum_init(s_axis_cmd_csum_init),
    .s_axis_cmd_valid(s_axis_cmd_valid),
    .s_axis_cmd_ready(s_axis_cmd_ready)
);

endmodule
