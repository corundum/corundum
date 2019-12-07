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
 * Testbench for dma_if_pcie_us_rd
 */
module test_dma_if_pcie_us_rd_256;

// Parameters
parameter AXIS_PCIE_DATA_WIDTH = 256;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_RC_USER_WIDTH = 75;
parameter AXIS_PCIE_RQ_USER_WIDTH = 60;
parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6;
parameter RQ_SEQ_NUM_ENABLE = 1;
parameter SEG_COUNT = AXIS_PCIE_DATA_WIDTH > 64 ? AXIS_PCIE_DATA_WIDTH*2 / 128 : 2;
parameter SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH*2/SEG_COUNT;
parameter SEG_ADDR_WIDTH = 12;
parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8;
parameter RAM_SEL_WIDTH = 2;
parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH);
parameter PCIE_ADDR_WIDTH = 64;
parameter PCIE_TAG_COUNT = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 64 : 256;
parameter PCIE_TAG_WIDTH = $clog2(PCIE_TAG_COUNT);
parameter PCIE_EXT_TAG_ENABLE = (PCIE_TAG_COUNT>32);
parameter LEN_WIDTH = 16;
parameter TAG_WIDTH = 8;
parameter OP_TABLE_SIZE = PCIE_TAG_COUNT;
parameter TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1);
parameter TX_FC_ENABLE = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [AXIS_PCIE_DATA_WIDTH-1:0] s_axis_rc_tdata = 0;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] s_axis_rc_tkeep = 0;
reg s_axis_rc_tvalid = 0;
reg s_axis_rc_tlast = 0;
reg [AXIS_PCIE_RC_USER_WIDTH-1:0] s_axis_rc_tuser = 0;
reg m_axis_rq_tready = 0;
reg [RQ_SEQ_NUM_WIDTH-1:0] s_axis_rq_seq_num_0 = 0;
reg s_axis_rq_seq_num_valid_0 = 0;
reg [RQ_SEQ_NUM_WIDTH-1:0] s_axis_rq_seq_num_1 = 0;
reg s_axis_rq_seq_num_valid_1 = 0;
reg [7:0] pcie_tx_fc_nph_av = 0;
reg [PCIE_ADDR_WIDTH-1:0] s_axis_read_desc_pcie_addr = 0;
reg [RAM_SEL_WIDTH-1:0] s_axis_read_desc_ram_sel = 0;
reg [RAM_ADDR_WIDTH-1:0] s_axis_read_desc_ram_addr = 0;
reg [LEN_WIDTH-1:0] s_axis_read_desc_len = 0;
reg [TAG_WIDTH-1:0] s_axis_read_desc_tag = 0;
reg s_axis_read_desc_valid = 0;
reg [SEG_COUNT-1:0] ram_wr_cmd_ready = 0;
reg enable = 0;
reg ext_tag_enable = 0;
reg [15:0] requester_id = 0;
reg requester_id_enable = 0;
reg [2:0] max_read_request_size = 0;

// Outputs
wire s_axis_rc_tready;
wire [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_rq_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_rq_tkeep;
wire m_axis_rq_tvalid;
wire m_axis_rq_tlast;
wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser;
wire s_axis_read_desc_ready;
wire [TAG_WIDTH-1:0] m_axis_read_desc_status_tag;
wire m_axis_read_desc_status_valid;
wire [SEG_COUNT*RAM_SEL_WIDTH-1:0] ram_wr_cmd_sel;
wire [SEG_COUNT*SEG_BE_WIDTH-1:0] ram_wr_cmd_be;
wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ram_wr_cmd_addr;
wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] ram_wr_cmd_data;
wire [SEG_COUNT-1:0] ram_wr_cmd_valid;
wire status_error_cor;
wire status_error_uncor;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_rc_tdata,
        s_axis_rc_tkeep,
        s_axis_rc_tvalid,
        s_axis_rc_tlast,
        s_axis_rc_tuser,
        m_axis_rq_tready,
        s_axis_rq_seq_num_0,
        s_axis_rq_seq_num_valid_0,
        s_axis_rq_seq_num_1,
        s_axis_rq_seq_num_valid_1,
        pcie_tx_fc_nph_av,
        s_axis_read_desc_pcie_addr,
        s_axis_read_desc_ram_sel,
        s_axis_read_desc_ram_addr,
        s_axis_read_desc_len,
        s_axis_read_desc_tag,
        s_axis_read_desc_valid,
        ram_wr_cmd_ready,
        enable,
        ext_tag_enable,
        requester_id,
        requester_id_enable,
        max_read_request_size
    );
    $to_myhdl(
        s_axis_rc_tready,
        m_axis_rq_tdata,
        m_axis_rq_tkeep,
        m_axis_rq_tvalid,
        m_axis_rq_tlast,
        m_axis_rq_tuser,
        s_axis_read_desc_ready,
        m_axis_read_desc_status_tag,
        m_axis_read_desc_status_valid,
        ram_wr_cmd_sel,
        ram_wr_cmd_be,
        ram_wr_cmd_addr,
        ram_wr_cmd_data,
        ram_wr_cmd_valid,
        status_error_cor,
        status_error_uncor
    );

    // dump file
    $dumpfile("test_dma_if_pcie_us_rd_256.lxt");
    $dumpvars(0, test_dma_if_pcie_us_rd_256);
end

dma_if_pcie_us_rd #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .RQ_SEQ_NUM_ENABLE(RQ_SEQ_NUM_ENABLE),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .PCIE_TAG_WIDTH(PCIE_TAG_WIDTH),
    .PCIE_EXT_TAG_ENABLE(PCIE_EXT_TAG_ENABLE),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .OP_TABLE_SIZE(OP_TABLE_SIZE),
    .TX_LIMIT(TX_LIMIT),
    .TX_FC_ENABLE(TX_FC_ENABLE)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axis_rc_tdata(s_axis_rc_tdata),
    .s_axis_rc_tkeep(s_axis_rc_tkeep),
    .s_axis_rc_tvalid(s_axis_rc_tvalid),
    .s_axis_rc_tready(s_axis_rc_tready),
    .s_axis_rc_tlast(s_axis_rc_tlast),
    .s_axis_rc_tuser(s_axis_rc_tuser),
    .m_axis_rq_tdata(m_axis_rq_tdata),
    .m_axis_rq_tkeep(m_axis_rq_tkeep),
    .m_axis_rq_tvalid(m_axis_rq_tvalid),
    .m_axis_rq_tready(m_axis_rq_tready),
    .m_axis_rq_tlast(m_axis_rq_tlast),
    .m_axis_rq_tuser(m_axis_rq_tuser),
    .s_axis_rq_seq_num_0(s_axis_rq_seq_num_0),
    .s_axis_rq_seq_num_valid_0(s_axis_rq_seq_num_valid_0),
    .s_axis_rq_seq_num_1(s_axis_rq_seq_num_1),
    .s_axis_rq_seq_num_valid_1(s_axis_rq_seq_num_valid_1),
    .pcie_tx_fc_nph_av(pcie_tx_fc_nph_av),
    .s_axis_read_desc_pcie_addr(s_axis_read_desc_pcie_addr),
    .s_axis_read_desc_ram_sel(s_axis_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(s_axis_read_desc_ram_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),
    .ram_wr_cmd_sel(ram_wr_cmd_sel),
    .ram_wr_cmd_be(ram_wr_cmd_be),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_valid(ram_wr_cmd_valid),
    .ram_wr_cmd_ready(ram_wr_cmd_ready),
    .enable(enable),
    .ext_tag_enable(ext_tag_enable),
    .requester_id(requester_id),
    .requester_id_enable(requester_id_enable),
    .max_read_request_size(max_read_request_size),
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor)
);

endmodule
