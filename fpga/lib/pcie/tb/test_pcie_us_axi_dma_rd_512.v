/*

Copyright (c) 2018 Alex Forencich

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
 * Testbench for pcie_us_axi_dma_rd
 */
module test_pcie_us_axi_dma_rd_512;

// Parameters
parameter AXIS_PCIE_DATA_WIDTH = 512;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_RC_USER_WIDTH = 161;
parameter AXIS_PCIE_RQ_USER_WIDTH = 137;
parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6;
parameter RQ_SEQ_NUM_ENABLE = 1;
parameter AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH;
parameter AXI_ADDR_WIDTH = 64;
parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
parameter AXI_ID_WIDTH = 8;
parameter AXI_MAX_BURST_LEN = 256;
parameter PCIE_ADDR_WIDTH = 64;
parameter PCIE_TAG_COUNT = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 64 : 256;
parameter PCIE_TAG_WIDTH = $clog2(PCIE_TAG_COUNT);
parameter PCIE_EXT_TAG_ENABLE = 1;
parameter LEN_WIDTH = 20;
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
reg [AXI_ADDR_WIDTH-1:0] s_axis_read_desc_axi_addr = 0;
reg [LEN_WIDTH-1:0] s_axis_read_desc_len = 0;
reg [TAG_WIDTH-1:0] s_axis_read_desc_tag = 0;
reg s_axis_read_desc_valid = 0;
reg m_axi_awready = 0;
reg m_axi_wready = 0;
reg [AXI_ID_WIDTH-1:0] m_axi_bid = 0;
reg [1:0] m_axi_bresp = 0;
reg m_axi_bvalid = 0;
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
wire [AXI_ID_WIDTH-1:0] m_axi_awid;
wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
wire [7:0] m_axi_awlen;
wire [2:0] m_axi_awsize;
wire [1:0] m_axi_awburst;
wire m_axi_awlock;
wire [3:0] m_axi_awcache;
wire [2:0] m_axi_awprot;
wire m_axi_awvalid;
wire [AXI_DATA_WIDTH-1:0] m_axi_wdata;
wire [AXI_STRB_WIDTH-1:0] m_axi_wstrb;
wire m_axi_wlast;
wire m_axi_wvalid;
wire m_axi_bready;
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
        s_axis_read_desc_axi_addr,
        s_axis_read_desc_len,
        s_axis_read_desc_tag,
        s_axis_read_desc_valid,
        m_axi_awready,
        m_axi_wready,
        m_axi_bid,
        m_axi_bresp,
        m_axi_bvalid,
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
        m_axi_awid,
        m_axi_awaddr,
        m_axi_awlen,
        m_axi_awsize,
        m_axi_awburst,
        m_axi_awlock,
        m_axi_awcache,
        m_axi_awprot,
        m_axi_awvalid,
        m_axi_wdata,
        m_axi_wstrb,
        m_axi_wlast,
        m_axi_wvalid,
        m_axi_bready,
        status_error_cor,
        status_error_uncor
    );

    // dump file
    $dumpfile("test_pcie_us_axi_dma_rd_512.lxt");
    $dumpvars(0, test_pcie_us_axi_dma_rd_512);
end

pcie_us_axi_dma_rd #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RC_USER_WIDTH(AXIS_PCIE_RC_USER_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .RQ_SEQ_NUM_ENABLE(RQ_SEQ_NUM_ENABLE),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_TAG_WIDTH(PCIE_TAG_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
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
    .s_axis_read_desc_axi_addr(s_axis_read_desc_axi_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),
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
    .enable(enable),
    .ext_tag_enable(ext_tag_enable),
    .requester_id(requester_id),
    .requester_id_enable(requester_id_enable),
    .max_read_request_size(max_read_request_size),
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor)
);

endmodule
