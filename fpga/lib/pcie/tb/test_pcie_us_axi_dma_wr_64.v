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
 * Testbench for pcie_us_axi_dma_wr
 */
module test_pcie_us_axi_dma_wr_64;

// Parameters
parameter AXIS_PCIE_DATA_WIDTH = 64;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32);
parameter AXIS_PCIE_RQ_USER_WIDTH = 60;
parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6;
parameter RQ_SEQ_NUM_ENABLE = 1;
parameter AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH;
parameter AXI_ADDR_WIDTH = 64;
parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
parameter AXI_ID_WIDTH = 8;
parameter AXI_MAX_BURST_LEN = 256;
parameter PCIE_ADDR_WIDTH = 64;
parameter LEN_WIDTH = 20;
parameter TAG_WIDTH = 8;
parameter OP_TABLE_SIZE = 2**(RQ_SEQ_NUM_WIDTH-1);
parameter TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1);
parameter TX_FC_ENABLE = 1;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [AXIS_PCIE_DATA_WIDTH-1:0] s_axis_rq_tdata = 0;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] s_axis_rq_tkeep = 0;
reg s_axis_rq_tvalid = 0;
reg s_axis_rq_tlast = 0;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] s_axis_rq_tuser = 0;
reg m_axis_rq_tready = 0;
reg [RQ_SEQ_NUM_WIDTH-1:0] s_axis_rq_seq_num_0 = 0;
reg s_axis_rq_seq_num_valid_0 = 0;
reg [RQ_SEQ_NUM_WIDTH-1:0] s_axis_rq_seq_num_1 = 0;
reg s_axis_rq_seq_num_valid_1 = 0;
reg [7:0] pcie_tx_fc_ph_av = 0;
reg [11:0] pcie_tx_fc_pd_av = 0;
reg [PCIE_ADDR_WIDTH-1:0] s_axis_write_desc_pcie_addr = 0;
reg [AXI_ADDR_WIDTH-1:0] s_axis_write_desc_axi_addr = 0;
reg [LEN_WIDTH-1:0] s_axis_write_desc_len = 0;
reg [TAG_WIDTH-1:0] s_axis_write_desc_tag = 0;
reg s_axis_write_desc_valid = 0;
reg m_axi_arready = 0;
reg [AXI_ID_WIDTH-1:0] m_axi_rid = 0;
reg [AXI_DATA_WIDTH-1:0] m_axi_rdata = 0;
reg [1:0] m_axi_rresp = 0;
reg m_axi_rlast = 0;
reg m_axi_rvalid = 0;
reg enable = 0;
reg [15:0] requester_id = 0;
reg requester_id_enable = 0;
reg [2:0] max_payload_size = 0;

// Outputs
wire s_axis_rq_tready;
wire [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_rq_tdata;
wire [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_rq_tkeep;
wire m_axis_rq_tvalid;
wire m_axis_rq_tlast;
wire [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser;
wire [RQ_SEQ_NUM_WIDTH-1:0] m_axis_rq_seq_num_0;
wire m_axis_rq_seq_num_valid_0;
wire [RQ_SEQ_NUM_WIDTH-1:0] m_axis_rq_seq_num_1;
wire m_axis_rq_seq_num_valid_1;
wire s_axis_write_desc_ready;
wire [TAG_WIDTH-1:0] m_axis_write_desc_status_tag;
wire m_axis_write_desc_status_valid;
wire [AXI_ID_WIDTH-1:0] m_axi_arid;
wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
wire [7:0] m_axi_arlen;
wire [2:0] m_axi_arsize;
wire [1:0] m_axi_arburst;
wire m_axi_arlock;
wire [3:0] m_axi_arcache;
wire [2:0] m_axi_arprot;
wire m_axi_arvalid;
wire m_axi_rready;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        s_axis_rq_tdata,
        s_axis_rq_tkeep,
        s_axis_rq_tvalid,
        s_axis_rq_tlast,
        s_axis_rq_tuser,
        m_axis_rq_tready,
        s_axis_rq_seq_num_0,
        s_axis_rq_seq_num_valid_0,
        s_axis_rq_seq_num_1,
        s_axis_rq_seq_num_valid_1,
        pcie_tx_fc_ph_av,
        pcie_tx_fc_pd_av,
        s_axis_write_desc_pcie_addr,
        s_axis_write_desc_axi_addr,
        s_axis_write_desc_len,
        s_axis_write_desc_tag,
        s_axis_write_desc_valid,
        m_axi_arready,
        m_axi_rid,
        m_axi_rdata,
        m_axi_rresp,
        m_axi_rlast,
        m_axi_rvalid,
        enable,
        requester_id,
        requester_id_enable,
        max_payload_size
    );
    $to_myhdl(
        s_axis_rq_tready,
        m_axis_rq_tdata,
        m_axis_rq_tkeep,
        m_axis_rq_tvalid,
        m_axis_rq_tlast,
        m_axis_rq_tuser,
        m_axis_rq_seq_num_0,
        m_axis_rq_seq_num_valid_0,
        m_axis_rq_seq_num_1,
        m_axis_rq_seq_num_valid_1,
        s_axis_write_desc_ready,
        m_axis_write_desc_status_tag,
        m_axis_write_desc_status_valid,
        m_axi_arid,
        m_axi_araddr,
        m_axi_arlen,
        m_axi_arsize,
        m_axi_arburst,
        m_axi_arlock,
        m_axi_arcache,
        m_axi_arprot,
        m_axi_arvalid,
        m_axi_rready
    );

    // dump file
    $dumpfile("test_pcie_us_axi_dma_wr_64.lxt");
    $dumpvars(0, test_pcie_us_axi_dma_wr_64);
end

pcie_us_axi_dma_wr #(
    .AXIS_PCIE_DATA_WIDTH(AXIS_PCIE_DATA_WIDTH),
    .AXIS_PCIE_KEEP_WIDTH(AXIS_PCIE_KEEP_WIDTH),
    .AXIS_PCIE_RQ_USER_WIDTH(AXIS_PCIE_RQ_USER_WIDTH),
    .RQ_SEQ_NUM_WIDTH(RQ_SEQ_NUM_WIDTH),
    .RQ_SEQ_NUM_ENABLE(RQ_SEQ_NUM_ENABLE),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .OP_TABLE_SIZE(OP_TABLE_SIZE),
    .TX_LIMIT(TX_LIMIT),
    .TX_FC_ENABLE(TX_FC_ENABLE)
)
UUT (
    .clk(clk),
    .rst(rst),
    .s_axis_rq_tdata(s_axis_rq_tdata),
    .s_axis_rq_tkeep(s_axis_rq_tkeep),
    .s_axis_rq_tvalid(s_axis_rq_tvalid),
    .s_axis_rq_tready(s_axis_rq_tready),
    .s_axis_rq_tlast(s_axis_rq_tlast),
    .s_axis_rq_tuser(s_axis_rq_tuser),
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
    .m_axis_rq_seq_num_0(m_axis_rq_seq_num_0),
    .m_axis_rq_seq_num_valid_0(m_axis_rq_seq_num_valid_0),
    .m_axis_rq_seq_num_1(m_axis_rq_seq_num_1),
    .m_axis_rq_seq_num_valid_1(m_axis_rq_seq_num_valid_1),
    .pcie_tx_fc_ph_av(pcie_tx_fc_ph_av),
    .pcie_tx_fc_pd_av(pcie_tx_fc_pd_av),
    .s_axis_write_desc_pcie_addr(s_axis_write_desc_pcie_addr),
    .s_axis_write_desc_axi_addr(s_axis_write_desc_axi_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),
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
    .enable(enable),
    .requester_id(requester_id),
    .requester_id_enable(requester_id_enable),
    .max_payload_size(max_payload_size)
);

endmodule
