/*

Copyright (c) 2019 Alex Forencich

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

`timescale 1ns / 1ps

/*
 * Testbench for dma_client_axis_sink
 */
module test_dma_client_axis_sink_128_64;

// Parameters
parameter SEG_COUNT = 2;
parameter SEG_DATA_WIDTH = 64;
parameter SEG_ADDR_WIDTH = 12;
parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8;
parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH);
parameter AXIS_DATA_WIDTH = SEG_DATA_WIDTH*SEG_COUNT/2;
parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8);
parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8);
parameter AXIS_LAST_ENABLE = 1;
parameter AXIS_ID_ENABLE = 0;
parameter AXIS_ID_WIDTH = 8;
parameter AXIS_DEST_ENABLE = 0;
parameter AXIS_DEST_WIDTH = 8;
parameter AXIS_USER_ENABLE = 1;
parameter AXIS_USER_WIDTH = 1;
parameter LEN_WIDTH = 20;
parameter TAG_WIDTH = 8;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [RAM_ADDR_WIDTH-1:0] s_axis_write_desc_ram_addr = 0;
reg [LEN_WIDTH-1:0] s_axis_write_desc_len = 0;
reg [TAG_WIDTH-1:0] s_axis_write_desc_tag = 0;
reg s_axis_write_desc_valid = 0;
reg [AXIS_DATA_WIDTH-1:0] s_axis_write_data_tdata = 0;
reg [AXIS_KEEP_WIDTH-1:0] s_axis_write_data_tkeep = 0;
reg s_axis_write_data_tvalid = 0;
reg s_axis_write_data_tlast = 0;
reg [AXIS_ID_WIDTH-1:0] s_axis_write_data_tid = 0;
reg [AXIS_DEST_WIDTH-1:0] s_axis_write_data_tdest = 0;
reg [AXIS_USER_WIDTH-1:0] s_axis_write_data_tuser = 0;
reg [SEG_COUNT-1:0] ram_wr_cmd_ready = 0;
reg enable = 0;
reg abort = 0;

// Outputs
wire s_axis_write_desc_ready;
wire [LEN_WIDTH-1:0] m_axis_write_desc_status_len;
wire [TAG_WIDTH-1:0] m_axis_write_desc_status_tag;
wire [AXIS_ID_WIDTH-1:0] m_axis_write_desc_status_id;
wire [AXIS_DEST_WIDTH-1:0] m_axis_write_desc_status_dest;
wire [AXIS_USER_WIDTH-1:0] m_axis_write_desc_status_user;
wire m_axis_write_desc_status_valid;
wire s_axis_write_data_tready;
wire [SEG_COUNT*SEG_BE_WIDTH-1:0] ram_wr_cmd_be;
wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] ram_wr_cmd_data;
wire [SEG_COUNT-1:0] ram_wr_cmd_valid;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_write_desc_ram_addr,
        s_axis_write_desc_len,
        s_axis_write_desc_tag,
        s_axis_write_desc_valid,
        s_axis_write_data_tdata,
        s_axis_write_data_tkeep,
        s_axis_write_data_tvalid,
        s_axis_write_data_tlast,
        s_axis_write_data_tid,
        s_axis_write_data_tdest,
        s_axis_write_data_tuser,
        ram_wr_cmd_ready,
        enable,
        abort
    );
    $to_myhdl(
        s_axis_write_desc_ready,
        m_axis_write_desc_status_len,
        m_axis_write_desc_status_tag,
        m_axis_write_desc_status_id,
        m_axis_write_desc_status_dest,
        m_axis_write_desc_status_user,
        m_axis_write_desc_status_valid,
        s_axis_write_data_tready,
        ram_wr_cmd_be,
        ram_wr_cmd_addr,
        ram_wr_cmd_data,
        ram_wr_cmd_valid
    );

    // dump file
    $dumpfile("test_dma_client_axis_sink_128_64.lxt");
    $dumpvars(0, test_dma_client_axis_sink_128_64);
end

dma_client_axis_sink #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axis_write_desc_ram_addr(s_axis_write_desc_ram_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),
    .m_axis_write_desc_status_len(m_axis_write_desc_status_len),
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_id(m_axis_write_desc_status_id),
    .m_axis_write_desc_status_dest(m_axis_write_desc_status_dest),
    .m_axis_write_desc_status_user(m_axis_write_desc_status_user),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),
    .s_axis_write_data_tdata(s_axis_write_data_tdata),
    .s_axis_write_data_tkeep(s_axis_write_data_tkeep),
    .s_axis_write_data_tvalid(s_axis_write_data_tvalid),
    .s_axis_write_data_tready(s_axis_write_data_tready),
    .s_axis_write_data_tlast(s_axis_write_data_tlast),
    .s_axis_write_data_tid(s_axis_write_data_tid),
    .s_axis_write_data_tdest(s_axis_write_data_tdest),
    .s_axis_write_data_tuser(s_axis_write_data_tuser),
    .ram_wr_cmd_be(ram_wr_cmd_be),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_valid(ram_wr_cmd_valid),
    .ram_wr_cmd_ready(ram_wr_cmd_ready),
    .enable(enable),
    .abort(abort)
);

endmodule
