/*

Copyright (c) 2021-2022 Alex Forencich

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
 * Xilinx UltraScale PCIe interface adapter (Requester reQuest)
 */
module pcie_us_if_rq #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream RQ tuser signal width
    parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 60 : 137,
    // RQ interface TLP straddling
    parameter RQ_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    // RQ sequence number width
    parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6,
    // TLP data width
    parameter TLP_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TX sequence number count
    parameter TX_SEQ_NUM_COUNT = AXIS_PCIE_DATA_WIDTH < 512 ? 1 : 2,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = RQ_SEQ_NUM_WIDTH-1
)
(
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * AXI output (RQ)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]               m_axis_rq_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]               m_axis_rq_tkeep,
    output wire                                          m_axis_rq_tvalid,
    input  wire                                          m_axis_rq_tready,
    output wire                                          m_axis_rq_tlast,
    output wire [AXIS_PCIE_RQ_USER_WIDTH-1:0]            m_axis_rq_tuser,

    /*
     * Transmit sequence number input
     */
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]                   s_axis_rq_seq_num_0,
    input  wire                                          s_axis_rq_seq_num_valid_0,
    input  wire [RQ_SEQ_NUM_WIDTH-1:0]                   s_axis_rq_seq_num_1,
    input  wire                                          s_axis_rq_seq_num_valid_1,

    /*
     * TLP input (read request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        tx_rd_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_rd_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_eop,
    output wire                                          tx_rd_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA read request)
     */
    output wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  m_axis_rd_req_tx_seq_num,
    output wire [TX_SEQ_NUM_COUNT-1:0]                   m_axis_rd_req_tx_seq_num_valid,

    /*
     * TLP input (write request from DMA)
     */
    input  wire [TLP_DATA_WIDTH-1:0]                     tx_wr_req_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                     tx_wr_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        tx_wr_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_wr_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_eop,
    output wire                                          tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA write request)
     */
    output wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  m_axis_wr_req_tx_seq_num,
    output wire [TX_SEQ_NUM_COUNT-1:0]                   m_axis_wr_req_tx_seq_num_valid,

    /*
     * Flow control
     */
    input  wire [7:0]                                    tx_fc_ph_av,
    input  wire [11:0]                                   tx_fc_pd_av,
    input  wire [7:0]                                    tx_fc_nph_av,
    input  wire [11:0]                                   tx_fc_npd_av,

    /*
     * Configuration
     */
    input  wire [2:0]                                    max_payload_size
);

parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter INT_TLP_SEG_COUNT = (RQ_STRADDLE && AXIS_PCIE_DATA_WIDTH >= 512) ? 2 : 1;
parameter INT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / INT_TLP_SEG_COUNT;
parameter INT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / INT_TLP_SEG_COUNT;

parameter SEG_SEL_WIDTH = $clog2(INT_TLP_SEG_COUNT);

parameter PORTS = 2;
parameter CL_PORTS = $clog2(PORTS);

parameter SEQ_NUM_MASK = {RQ_SEQ_NUM_WIDTH-1{1'b1}};
parameter SEQ_NUM_FLAG = {1'b1, {RQ_SEQ_NUM_WIDTH-1{1'b0}}};

// bus width assertions
initial begin
    if (AXIS_PCIE_DATA_WIDTH != 64 && AXIS_PCIE_DATA_WIDTH != 128 && AXIS_PCIE_DATA_WIDTH != 256 && AXIS_PCIE_DATA_WIDTH != 512) begin
        $error("Error: PCIe interface width must be 64, 128, 256, or 512 (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_KEEP_WIDTH * 32 != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        if (AXIS_PCIE_RQ_USER_WIDTH != 137) begin
            $error("Error: PCIe RQ tuser width must be 137 (instance %m)");
            $finish;
        end

        if (TX_SEQ_NUM_COUNT != 2) begin
            $error("Error: TX sequence number count must be 2 (instance %m)");
            $finish;
        end
    end else begin
        if (AXIS_PCIE_RQ_USER_WIDTH != 60 && AXIS_PCIE_RQ_USER_WIDTH != 62) begin
            $error("Error: PCIe RQ tuser width must be 60 or 62 (instance %m)");
            $finish;
        end

        if (TX_SEQ_NUM_COUNT != 1) begin
            $error("Error: TX sequence number count must be 1 (instance %m)");
            $finish;
        end
    end

    if (AXIS_PCIE_RQ_USER_WIDTH == 60) begin
        if (RQ_SEQ_NUM_WIDTH != 4) begin
            $error("Error: RQ sequence number width must be 4 (instance %m)");
            $finish;
        end
    end else begin
        if (RQ_SEQ_NUM_WIDTH != 6) begin
            $error("Error: RQ sequence number width must be 6 (instance %m)");
            $finish;
        end
    end

    if (TLP_DATA_WIDTH != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end

    if (TX_SEQ_NUM_WIDTH > RQ_SEQ_NUM_WIDTH-1) begin
        $error("Error: TX sequence number width must be less than RQ_SEQ_NUM_WIDTH (instance %m)");
        $finish;
    end
end

localparam [3:0]
    REQ_MEM_READ = 4'b0000,
    REQ_MEM_WRITE = 4'b0001,
    REQ_IO_READ = 4'b0010,
    REQ_IO_WRITE = 4'b0011,
    REQ_MEM_FETCH_ADD = 4'b0100,
    REQ_MEM_SWAP = 4'b0101,
    REQ_MEM_CAS = 4'b0110,
    REQ_MEM_READ_LOCKED = 4'b0111,
    REQ_CFG_READ_0 = 4'b1000,
    REQ_CFG_READ_1 = 4'b1001,
    REQ_CFG_WRITE_0 = 4'b1010,
    REQ_CFG_WRITE_1 = 4'b1011,
    REQ_MSG = 4'b1100,
    REQ_MSG_VENDOR = 4'b1101,
    REQ_MSG_ATS = 4'b1110;

reg [8:0] max_payload_size_fc_reg = 9'd0;
reg have_p_credit_reg = 1'b0;
reg have_np_credit_reg = 1'b0;

reg frame_reg = 1'b0, frame_next, frame_cyc;
reg tlp_hdr1_reg = 1'b0, tlp_hdr1_next, tlp_hdr1_cyc;
reg tlp_hdr2_reg = 1'b0, tlp_hdr2_next, tlp_hdr2_cyc;
reg tlp_split1_reg = 1'b0, tlp_split1_next, tlp_split1_cyc;
reg tlp_split2_reg = 1'b0, tlp_split2_next, tlp_split2_cyc;
reg [CL_PORTS-1:0] port_reg = 0, port_next, port_cyc;
reg [SEG_SEL_WIDTH-1:0] seg_offset_cyc;
reg [SEG_SEL_WIDTH+1-1:0] seg_count_cyc;
reg valid, sop, eop;
reg frame, abort;
reg [SEG_SEL_WIDTH-1:0] port_seg_offset_cyc[0:PORTS-1];
reg [SEG_SEL_WIDTH+1-1:0] port_seg_count_cyc[0:PORTS-1];

reg [INT_TLP_SEG_COUNT-1:0] port_seg_valid[0:PORTS-1];
reg [INT_TLP_SEG_COUNT-1:0] port_seg_sop[0:PORTS-1];
reg [INT_TLP_SEG_COUNT-1:0] port_seg_eop[0:PORTS-1];
reg [INT_TLP_SEG_COUNT-1:0] port_seg_extra[0:PORTS-1];

reg [INT_TLP_SEG_COUNT-1:0] out_sel, out_sel_cyc;
reg [INT_TLP_SEG_COUNT-1:0] out_sop;
reg [INT_TLP_SEG_COUNT-1:0] out_eop;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_hdr1;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_hdr2;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_split1;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_split2;
reg [CL_PORTS-1:0] out_sel_port[0:INT_TLP_SEG_COUNT-1];
reg [SEG_SEL_WIDTH+1-1:0] out_sel_seg[0:INT_TLP_SEG_COUNT-1];

reg [TLP_DATA_WIDTH-1:0] out_tlp_data;
reg [TLP_STRB_WIDTH-1:0] out_tlp_strb;
reg [INT_TLP_SEG_COUNT*8-1:0] out_tlp_be;
reg [INT_TLP_SEG_COUNT*RQ_SEQ_NUM_WIDTH-1:0] out_tlp_seq;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_valid;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_sop;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_eop;
reg [127:0] out_shift_tlp_data_reg = 0, out_shift_tlp_data_next;
reg [3:0] out_shift_tlp_strb_reg = 0, out_shift_tlp_strb_next;

reg [127:0] seg_tlp_hdr;
reg [127:0] seg_rq_hdr;
reg [INT_TLP_SEG_COUNT*3-1:0] eop_index;

reg [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_rq_tdata_reg = 0, m_axis_rq_tdata_next;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_rq_tkeep_reg = 0, m_axis_rq_tkeep_next;
reg m_axis_rq_tvalid_reg = 1'b0, m_axis_rq_tvalid_next;
reg m_axis_rq_tlast_reg = 1'b0, m_axis_rq_tlast_next;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser_reg = 0, m_axis_rq_tuser_next;

generate

assign m_axis_rd_req_tx_seq_num[TX_SEQ_NUM_WIDTH*0 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_0;
assign m_axis_rd_req_tx_seq_num_valid[0] = s_axis_rq_seq_num_valid_0 && ((s_axis_rq_seq_num_0 & SEQ_NUM_FLAG) != 0);
assign m_axis_wr_req_tx_seq_num[TX_SEQ_NUM_WIDTH*0 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_0;
assign m_axis_wr_req_tx_seq_num_valid[0] = s_axis_rq_seq_num_valid_0 && ((s_axis_rq_seq_num_0 & SEQ_NUM_FLAG) == 0);

if (TX_SEQ_NUM_COUNT > 1) begin
    assign m_axis_rd_req_tx_seq_num[TX_SEQ_NUM_WIDTH*1 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_1;
    assign m_axis_rd_req_tx_seq_num_valid[1] = s_axis_rq_seq_num_valid_1 && ((s_axis_rq_seq_num_1 & SEQ_NUM_FLAG) != 0);
    assign m_axis_wr_req_tx_seq_num[TX_SEQ_NUM_WIDTH*1 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_1;
    assign m_axis_wr_req_tx_seq_num_valid[1] = s_axis_rq_seq_num_valid_1 && ((s_axis_rq_seq_num_1 & SEQ_NUM_FLAG) == 0);
end

endgenerate

assign m_axis_rq_tdata = m_axis_rq_tdata_reg;
assign m_axis_rq_tkeep = m_axis_rq_tkeep_reg;
assign m_axis_rq_tvalid = m_axis_rq_tvalid_reg;
assign m_axis_rq_tlast = m_axis_rq_tlast_reg;
assign m_axis_rq_tuser = m_axis_rq_tuser_reg;

wire [TLP_DATA_WIDTH-1:0] fifo_tlp_data[0:PORTS-1];
wire [TLP_STRB_WIDTH-1:0] fifo_tlp_strb[0:PORTS-1];
wire [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] fifo_tlp_hdr[0:PORTS-1];
wire [INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0] fifo_tlp_seq[0:PORTS-1];
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_valid[0:PORTS-1];
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_sop[0:PORTS-1];
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_eop[0:PORTS-1];
wire [SEG_SEL_WIDTH-1:0] fifo_seg_offset[0:PORTS-1];
wire [SEG_SEL_WIDTH+1-1:0] fifo_seg_count[0:PORTS-1];
reg [PORTS-1:0] fifo_read_en;
reg [SEG_SEL_WIDTH+1-1:0] fifo_read_seg_count[0:PORTS-1];

reg [INT_TLP_SEG_COUNT-1:0] fifo_tlp_extra[0:PORTS-1];

wire [PORTS-1:0] port_have_credit;

// read requests
pcie_tlp_fifo_raw #(
    .DEPTH((1024/4)*2),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .IN_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .CTRL_OUT_EN(0)
)
rd_req_fifo_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(0),
    .in_tlp_strb(0),
    .in_tlp_hdr(tx_rd_req_tlp_hdr),
    .in_tlp_seq(tx_rd_req_tlp_seq),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid(tx_rd_req_tlp_valid),
    .in_tlp_sop(1'b1),
    .in_tlp_eop(1'b1),
    .in_tlp_ready(tx_rd_req_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(),
    .out_tlp_strb(),
    .out_tlp_hdr(fifo_tlp_hdr[0]),
    .out_tlp_seq(fifo_tlp_seq[0]),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(),
    .out_tlp_valid(fifo_tlp_valid[0]),
    .out_tlp_sop(fifo_tlp_sop[0]),
    .out_tlp_eop(fifo_tlp_eop[0]),
    .out_seg_offset(fifo_seg_offset[0]),
    .out_seg_count(fifo_seg_count[0]),
    .out_read_en(fifo_read_en[0]),
    .out_read_seg_count(fifo_read_seg_count[0]),

    .out_ctrl_tlp_strb(),
    .out_ctrl_tlp_hdr(),
    .out_ctrl_tlp_valid(),
    .out_ctrl_tlp_sop(),
    .out_ctrl_tlp_eop(),
    .out_ctrl_seg_offset(),
    .out_ctrl_seg_count(),
    .out_ctrl_read_en(0),
    .out_ctrl_read_seg_count(0),

    /*
     * Status
     */
    .half_full(),
    .watermark()
);

assign fifo_tlp_data[0] = 0;
assign fifo_tlp_strb[0] = 0;

assign port_have_credit[0] = have_np_credit_reg;

// write requests
pcie_tlp_fifo_raw #(
    .DEPTH((1024/4)*2),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .IN_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .CTRL_OUT_EN(0)
)
wr_req_fifo_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(tx_wr_req_tlp_data),
    .in_tlp_strb(tx_wr_req_tlp_strb),
    .in_tlp_hdr(tx_wr_req_tlp_hdr),
    .in_tlp_seq(tx_wr_req_tlp_seq),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid(tx_wr_req_tlp_valid),
    .in_tlp_sop(tx_wr_req_tlp_sop),
    .in_tlp_eop(tx_wr_req_tlp_eop),
    .in_tlp_ready(tx_wr_req_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(fifo_tlp_data[1]),
    .out_tlp_strb(fifo_tlp_strb[1]),
    .out_tlp_hdr(fifo_tlp_hdr[1]),
    .out_tlp_seq(fifo_tlp_seq[1]),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(),
    .out_tlp_valid(fifo_tlp_valid[1]),
    .out_tlp_sop(fifo_tlp_sop[1]),
    .out_tlp_eop(fifo_tlp_eop[1]),
    .out_seg_offset(fifo_seg_offset[1]),
    .out_seg_count(fifo_seg_count[1]),
    .out_read_en(fifo_read_en[1]),
    .out_read_seg_count(fifo_read_seg_count[1]),

    .out_ctrl_tlp_strb(),
    .out_ctrl_tlp_hdr(),
    .out_ctrl_tlp_valid(),
    .out_ctrl_tlp_sop(),
    .out_ctrl_tlp_eop(),
    .out_ctrl_seg_offset(),
    .out_ctrl_seg_count(),
    .out_ctrl_read_en(0),
    .out_ctrl_read_seg_count(0),

    /*
     * Status
     */
    .half_full(),
    .watermark()
);

assign port_have_credit[1] = have_p_credit_reg;

integer port, cur_port, seg, cur_seg, lane;

always @* begin
    frame_next = frame_reg;
    tlp_hdr1_next = tlp_hdr1_reg;
    tlp_hdr2_next = tlp_hdr2_reg;
    tlp_split1_next = tlp_split1_reg;
    tlp_split2_next = tlp_split2_reg;
    port_next = port_reg;

    m_axis_rq_tdata_next = m_axis_rq_tdata_reg;
    m_axis_rq_tkeep_next = m_axis_rq_tkeep_reg;
    m_axis_rq_tvalid_next = m_axis_rq_tvalid_reg && !m_axis_rq_tready;
    m_axis_rq_tlast_next = m_axis_rq_tlast_reg;
    m_axis_rq_tuser_next = m_axis_rq_tuser_reg;

    fifo_read_en = 0;

    frame_cyc = frame_reg;
    tlp_hdr1_cyc = tlp_hdr1_reg;
    tlp_hdr2_cyc = tlp_hdr2_reg;
    tlp_split1_cyc = tlp_split1_reg;
    tlp_split2_cyc = tlp_split2_reg;
    port_cyc = port_reg;
    seg_offset_cyc = fifo_seg_offset[port_reg];
    seg_count_cyc = 0;
    valid = 0;
    eop = 0;
    frame = frame_cyc;
    abort = 0;

    eop_index = 0;

    for (port = 0; port < PORTS; port = port + 1) begin
        port_seg_offset_cyc[port] = fifo_seg_offset[port];
        port_seg_count_cyc[port] = 0;
        fifo_read_seg_count[port] = 0;
    end

    out_sel = 0;
    out_sel_cyc = 0;
    out_sop = 0;
    out_eop = 0;
    out_tlp_hdr1 = 0;
    out_tlp_hdr2 = 0;
    out_tlp_split1 = 0;
    out_tlp_split2 = 0;
    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        out_sel_port[seg] = 0;
        out_sel_seg[seg] = 0;
    end

    out_shift_tlp_data_next = out_shift_tlp_data_reg;
    out_shift_tlp_strb_next = out_shift_tlp_strb_reg;

    // pre-compute
    for (port = 0; port < PORTS; port = port + 1) begin
        for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
            fifo_tlp_extra[port][seg] = fifo_tlp_eop[port][seg] && fifo_tlp_strb[port][seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] >> (INT_TLP_SEG_STRB_WIDTH-4);
        end
    end

    // compute mux settings
    for (port = 0; port < PORTS; port = port + 1) begin
        port_seg_valid[port] = {2{fifo_tlp_valid[port]}} >> fifo_seg_offset[port];
        port_seg_sop[port] = {2{fifo_tlp_sop[port]}} >> fifo_seg_offset[port];
        port_seg_eop[port] = {2{fifo_tlp_eop[port]}} >> fifo_seg_offset[port];
        port_seg_extra[port] = {2{fifo_tlp_extra[port]}} >> fifo_seg_offset[port];
    end

    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        // select port
        if (!frame_cyc && !abort) begin
            // priority arb - start from high priority end
            cur_port = 0;
            tlp_hdr1_cyc = 1'b1;
            tlp_hdr2_cyc = 1'b0;
            tlp_split1_cyc = 1'b0;
            tlp_split2_cyc = 1'b0;
            for (port = 0; port < PORTS; port = port + 1) begin
                if (port_seg_valid[cur_port][0] && port_have_credit[cur_port] && !frame_cyc) begin
                    // select port, set frame
                    frame_cyc = 1'b1;
                    port_cyc = cur_port;
                    seg_offset_cyc = port_seg_offset_cyc[cur_port];
                    seg_count_cyc = port_seg_count_cyc[cur_port];
                end
                // next port
                if (cur_port < PORTS-1) begin
                    cur_port = cur_port + 1;
                end else begin
                    cur_port = 0;
                end
            end
        end

        // route segment
        valid = port_seg_valid[port_cyc][0];
        sop = port_seg_sop[port_cyc][0];
        eop = port_seg_eop[port_cyc][0];
        frame = frame_cyc;

        out_sel_cyc[seg] = 1'b1;
        out_sop[seg] = tlp_hdr1_cyc;
        out_sel_port[seg] = port_cyc;
        out_sel_seg[seg] = seg_offset_cyc;

        out_tlp_hdr1[seg] = tlp_hdr1_cyc;
        out_tlp_hdr2[seg] = tlp_hdr2_cyc;

        if (AXIS_PCIE_DATA_WIDTH == 64 && tlp_hdr1_cyc) begin
            // output header (first cycle)
            tlp_hdr1_cyc = 1'b0;
            tlp_hdr2_cyc = 1'b1;
        end else if ((AXIS_PCIE_DATA_WIDTH == 128 && tlp_hdr1_cyc) || (AXIS_PCIE_DATA_WIDTH == 64 && tlp_hdr2_cyc)) begin
            // output header (last cycle)
            tlp_hdr1_cyc = 1'b0;
            tlp_hdr2_cyc = 1'b0;
            if (eop && fifo_tlp_strb[port_cyc][seg_offset_cyc*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] == 0) begin
                // no payload
                frame_cyc = 0;
                out_eop[seg] = 1'b1;
                seg_offset_cyc = seg_offset_cyc + 1;
                seg_count_cyc = seg_count_cyc + 1;
                port_seg_valid[port_cyc] = port_seg_valid[port_cyc] >> 1;
                port_seg_sop[port_cyc] = port_seg_sop[port_cyc] >> 1;
                port_seg_eop[port_cyc] = port_seg_eop[port_cyc] >> 1;
                port_seg_extra[port_cyc] = port_seg_extra[port_cyc] >> 1;
            end
        end else if (AXIS_PCIE_DATA_WIDTH > 128 && port_seg_extra[port_cyc][0]) begin
            tlp_hdr1_cyc = 1'b0;
            tlp_hdr2_cyc = 1'b0;
            // extra cycle
            if (tlp_split1_cyc) begin
                frame_cyc = 0;
                out_eop[seg] = 1'b1;
                tlp_split1_cyc = 1'b0;
                tlp_split2_cyc = 1'b1;
                seg_offset_cyc = seg_offset_cyc + 1;
                seg_count_cyc = seg_count_cyc + 1;
                port_seg_valid[port_cyc] = port_seg_valid[port_cyc] >> 1;
                port_seg_sop[port_cyc] = port_seg_sop[port_cyc] >> 1;
                port_seg_eop[port_cyc] = port_seg_eop[port_cyc] >> 1;
                port_seg_extra[port_cyc] = port_seg_extra[port_cyc] >> 1;
            end else begin
                tlp_split1_cyc = 1'b1;
            end
        end else begin
            tlp_hdr1_cyc = 1'b0;
            tlp_hdr2_cyc = 1'b0;
            if (eop) begin
                // end of packet
                frame_cyc = 0;
                out_eop[seg] = 1'b1;
            end
            seg_offset_cyc = seg_offset_cyc + 1;
            seg_count_cyc = seg_count_cyc + 1;
            port_seg_valid[port_cyc] = port_seg_valid[port_cyc] >> 1;
            port_seg_sop[port_cyc] = port_seg_sop[port_cyc] >> 1;
            port_seg_eop[port_cyc] = port_seg_eop[port_cyc] >> 1;
            port_seg_extra[port_cyc] = port_seg_extra[port_cyc] >> 1;
        end
        tlp_hdr1_cyc = 1'b0;

        out_tlp_split1[seg] = tlp_split1_cyc;
        out_tlp_split2[seg] = tlp_split2_cyc;

        if (frame && !abort) begin
            if (valid) begin
                if (eop || seg == INT_TLP_SEG_COUNT-1) begin
                    // end of packet or end of cycle, commit
                    port_seg_offset_cyc[port_cyc] = seg_offset_cyc;
                    port_seg_count_cyc[port_cyc] = seg_count_cyc;
                    fifo_read_seg_count[port_cyc] = seg_count_cyc;
                    if (!m_axis_rq_tvalid || m_axis_rq_tready) begin
                        frame_next = frame_cyc;
                        tlp_hdr1_next = tlp_hdr1_cyc;
                        tlp_hdr2_next = tlp_hdr2_cyc;
                        tlp_split1_next = tlp_split1_cyc;
                        tlp_split2_next = tlp_split2_cyc;
                        out_sel = out_sel_cyc;
                        port_next = port_cyc;
                        fifo_read_en[port_cyc] = seg_count_cyc != 0;
                    end
                end
            end else begin
                // input has stalled, wait
                abort = 1;
            end
        end
    end

    // remap
    out_tlp_data = 0;
    out_tlp_strb = 0;
    out_tlp_be = 0;
    out_tlp_seq = 0;
    out_tlp_valid = 0;
    out_tlp_sop = 0;
    out_tlp_eop = 0;

    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        // remap header
        seg_tlp_hdr = fifo_tlp_hdr[out_sel_port[seg]][out_sel_seg[seg]*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
        seg_rq_hdr[1:0] = seg_tlp_hdr[107:106]; // address type
        seg_rq_hdr[63:2] = seg_tlp_hdr[63:2]; // address
        seg_rq_hdr[74:64] = {seg_tlp_hdr[105:96] == 0, seg_tlp_hdr[105:96]}; // DWORD count
        casez (seg_tlp_hdr[127:120])
            8'b00z_00000: seg_rq_hdr[78:75] = REQ_MEM_READ;
            8'b00z_00001: seg_rq_hdr[78:75] = REQ_MEM_READ_LOCKED;
            8'b01z_00000: seg_rq_hdr[78:75] = REQ_MEM_WRITE;
            8'b00z_00010: seg_rq_hdr[78:75] = REQ_IO_READ;
            8'b01z_00010: seg_rq_hdr[78:75] = REQ_IO_WRITE;
            8'b000_00100: seg_rq_hdr[78:75] = REQ_CFG_READ_0;
            8'b010_00100: seg_rq_hdr[78:75] = REQ_CFG_WRITE_0;
            8'b000_00101: seg_rq_hdr[78:75] = REQ_CFG_READ_1;
            8'b010_00101: seg_rq_hdr[78:75] = REQ_CFG_WRITE_1;
            8'b01z_01100: seg_rq_hdr[78:75] = REQ_MEM_FETCH_ADD;
            8'b01z_01101: seg_rq_hdr[78:75] = REQ_MEM_SWAP;
            8'b01z_01110: seg_rq_hdr[78:75] = REQ_MEM_CAS;
            default:      seg_rq_hdr[78:75] = REQ_MEM_WRITE;
        endcase
        seg_rq_hdr[79] = seg_tlp_hdr[110]; // poisoned request
        seg_rq_hdr[95:80] = seg_tlp_hdr[95:80]; // requester ID
        seg_rq_hdr[103:96] = seg_tlp_hdr[79:72]; // tag
        seg_rq_hdr[119:104] = 16'd0; // completer ID
        seg_rq_hdr[120] = 1'b0; // requester ID enable
        seg_rq_hdr[123:121] = seg_tlp_hdr[118:116]; // traffic class
        seg_rq_hdr[126:124] = {seg_tlp_hdr[114], seg_tlp_hdr[109:108]}; // attr
        seg_rq_hdr[127] = 1'b0; // force ECRC

        // mux for output segments
        out_tlp_be[seg*8+0 +: 4] = seg_tlp_hdr[67:64]; // first BE
        out_tlp_be[seg*8+4 +: 4] = seg_tlp_hdr[71:68]; // last BE

        if (AXIS_PCIE_DATA_WIDTH <= 128) begin
            out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = fifo_tlp_data[out_sel_port[seg]][out_sel_seg[seg]*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH];
            out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = fifo_tlp_strb[out_sel_port[seg]][out_sel_seg[seg]*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH];

            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                if (out_tlp_hdr1[seg]) begin
                    out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = seg_rq_hdr[63:0];
                    out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = 2'b11;
                end else if (out_tlp_hdr2[seg]) begin
                    out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = seg_rq_hdr[127:64];
                    out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = 2'b11;
                end
            end else begin
                if (out_tlp_hdr1[seg]) begin
                    out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = seg_rq_hdr;
                    out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = 4'b1111;
                end
            end

            out_tlp_valid[seg] = out_sel[seg];
            out_tlp_sop[seg] = out_sop[seg];
            out_tlp_eop[seg] = out_eop[seg];

            out_tlp_seq[seg*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH] = fifo_tlp_seq[out_sel_port[seg]][out_sel_seg[seg]*TX_SEQ_NUM_WIDTH +: TX_SEQ_NUM_WIDTH] | (out_sel_port[seg] ? 0 : SEQ_NUM_FLAG);
        end else begin
            out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = out_shift_tlp_data_next;
            out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = out_shift_tlp_strb_next;
            out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH+128 +: INT_TLP_SEG_DATA_WIDTH-128] = fifo_tlp_data[out_sel_port[seg]][out_sel_seg[seg]*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH-128];
            if (!out_tlp_split2[seg]) begin
                out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH+4 +: INT_TLP_SEG_STRB_WIDTH-4] = fifo_tlp_strb[out_sel_port[seg]][out_sel_seg[seg]*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH-4];
            end

            if (out_tlp_hdr1[seg]) begin
                out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: 128] = seg_rq_hdr;
                out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: 4] = 4'b1111;
            end

            out_tlp_valid[seg] = out_sel[seg];
            out_tlp_sop[seg] = out_sop[seg];
            out_tlp_eop[seg] = out_eop[seg];

            out_tlp_seq[seg*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH] = fifo_tlp_seq[out_sel_port[seg]][out_sel_seg[seg]*TX_SEQ_NUM_WIDTH +: TX_SEQ_NUM_WIDTH] | (out_sel_port[seg] ? 0 : SEQ_NUM_FLAG);

            if (out_sel[seg]) begin
                out_shift_tlp_data_next = fifo_tlp_data[out_sel_port[seg]][(out_sel_seg[seg]+1)*INT_TLP_SEG_DATA_WIDTH-128 +: 128];
                out_shift_tlp_strb_next = fifo_tlp_strb[out_sel_port[seg]][(out_sel_seg[seg]+1)*INT_TLP_SEG_STRB_WIDTH-4 +: 4];
            end
        end

    end

    if (!m_axis_rq_tvalid || m_axis_rq_tready) begin
        // remap header and sideband
        m_axis_rq_tdata_next = out_tlp_data;
        m_axis_rq_tkeep_next = 0;
        m_axis_rq_tvalid_next = out_tlp_valid != 0;
        m_axis_rq_tlast_next = !(RQ_STRADDLE && AXIS_PCIE_DATA_WIDTH == 512) && (out_tlp_valid & out_tlp_eop);
        m_axis_rq_tuser_next = 0;

        for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
            if (out_tlp_valid[seg]) begin
                m_axis_rq_tkeep_next[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH];
            end

            eop_index[seg*3 +: 3] = 0;
            for (lane = 0; lane < INT_TLP_SEG_STRB_WIDTH; lane = lane + 1) begin
                if (out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH+lane]) begin
                    eop_index[seg*3 +: 3] = lane;
                end
            end
        end

        if (AXIS_PCIE_DATA_WIDTH == 512) begin
            if (INT_TLP_SEG_COUNT == 1) begin
                m_axis_rq_tuser_next[3:0] = out_tlp_be[0*8+0 +: 4]; // first BE 0
                m_axis_rq_tuser_next[11:8] = out_tlp_be[0*8+4 +: 4]; // last BE 0
                m_axis_rq_tuser_next[7:4]   = 0; // first BE 1
                m_axis_rq_tuser_next[15:12] = 0; // last BE 1
            end else begin
                case (out_tlp_valid & out_tlp_sop)
                    2'b00: begin
                        m_axis_rq_tuser_next[3:0]   = out_tlp_be[0*8+0 +: 4]; // first BE 0
                        m_axis_rq_tuser_next[11:8]  = out_tlp_be[0*8+4 +: 4]; // last BE 0
                    end
                    2'b01: begin
                        m_axis_rq_tuser_next[3:0]   = out_tlp_be[0*8+0 +: 4]; // first BE 0
                        m_axis_rq_tuser_next[11:8]  = out_tlp_be[0*8+4 +: 4]; // last BE 0
                    end
                    2'b10: begin
                        m_axis_rq_tuser_next[3:0]   = out_tlp_be[1*8+0 +: 4]; // first BE 0
                        m_axis_rq_tuser_next[11:8]  = out_tlp_be[1*8+4 +: 4]; // last BE 0
                    end
                    2'b11: begin
                        m_axis_rq_tuser_next[3:0]   = out_tlp_be[0*8+0 +: 4]; // first BE 0
                        m_axis_rq_tuser_next[11:8]  = out_tlp_be[0*8+4 +: 4]; // last BE 0
                    end
                endcase
                m_axis_rq_tuser_next[7:4]   = out_tlp_be[1*8+0 +: 4]; // first BE 1
                m_axis_rq_tuser_next[15:12] = out_tlp_be[1*8+4 +: 4]; // last BE 1
            end
            m_axis_rq_tuser_next[19:16] = 3'd0; // addr_offset
            if (INT_TLP_SEG_COUNT > 1) begin
                case (out_tlp_valid & out_tlp_sop)
                    2'b00: begin
                        m_axis_rq_tuser_next[21:20] = 2'b00; // is_sop
                        m_axis_rq_tuser_next[23:22] = 2'd0; // is_sop0_ptr
                    end
                    2'b01: begin
                        m_axis_rq_tuser_next[21:20] = 2'b01; // is_sop
                        m_axis_rq_tuser_next[23:22] = 2'd0; // is_sop0_ptr
                    end
                    2'b10: begin
                        m_axis_rq_tuser_next[21:20] = 2'b01; // is_sop
                        m_axis_rq_tuser_next[23:22] = 2'd2; // is_sop0_ptr
                    end
                    2'b11: begin
                        m_axis_rq_tuser_next[21:20] = 2'b11; // is_sop
                        m_axis_rq_tuser_next[23:22] = 2'd0; // is_sop0_ptr
                    end
                endcase
                m_axis_rq_tuser_next[25:24] = 2'd2; // is_sop1_ptr
                case (out_tlp_valid & out_tlp_eop)
                    2'b00: begin
                        m_axis_rq_tuser_next[27:26] = 2'b00; // is_eop
                        m_axis_rq_tuser_next[31:28] = eop_index[0*3 +: 3]; // is_eop0_ptr
                    end
                    2'b01: begin
                        m_axis_rq_tuser_next[27:26] = 2'b01; // is_eop
                        m_axis_rq_tuser_next[31:28] = eop_index[0*3 +: 3]; // is_eop0_ptr
                    end
                    2'b10: begin
                        m_axis_rq_tuser_next[27:26] = 2'b01; // is_eop
                        m_axis_rq_tuser_next[31:28] = 4'd8+eop_index[1*3 +: 3]; // is_eop0_ptr
                    end
                    2'b11: begin
                        m_axis_rq_tuser_next[27:26] = 2'b11; // is_eop
                        m_axis_rq_tuser_next[31:28] = eop_index[0*3 +: 3]; // is_eop0_ptr
                    end
                endcase
                m_axis_rq_tuser_next[35:32] = 4'd8+eop_index[1*3 +: 3]; // is_eop1_ptr
            end
            m_axis_rq_tuser_next[36] = 1'b0; // discontinue
            m_axis_rq_tuser_next[38:37] = 2'b00; // tph_present
            m_axis_rq_tuser_next[42:39] = 4'b0000; // tph_type
            m_axis_rq_tuser_next[44:43] = 2'b00; // tph_indirect_tag_en
            m_axis_rq_tuser_next[60:45] = 16'd0; // tph_st_tag
            if (INT_TLP_SEG_COUNT == 1) begin
                m_axis_rq_tuser_next[66:61] = out_tlp_seq[0*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH]; // seq_num0
                m_axis_rq_tuser_next[72:67] = 0; // seq_num1
            end else begin
                case (out_tlp_valid & out_tlp_sop)
                    2'b00: begin
                        m_axis_rq_tuser_next[66:61] = out_tlp_seq[0*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH]; // seq_num0
                    end
                    2'b01: begin
                        m_axis_rq_tuser_next[66:61] = out_tlp_seq[0*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH]; // seq_num0
                    end
                    2'b10: begin
                        m_axis_rq_tuser_next[66:61] = out_tlp_seq[1*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH]; // seq_num0
                    end
                    2'b11: begin
                        m_axis_rq_tuser_next[66:61] = out_tlp_seq[0*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH]; // seq_num0
                    end
                endcase
                m_axis_rq_tuser_next[72:67] = out_tlp_seq[1*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH]; // seq_num1
            end
            m_axis_rq_tuser_next[136:73] = 64'd0; // parity
        end else begin
            m_axis_rq_tuser_next[3:0] = out_tlp_be[0*8+0 +: 4]; // first BE
            m_axis_rq_tuser_next[7:4] = out_tlp_be[0*8+4 +: 4]; // last BE
            m_axis_rq_tuser_next[10:8] = 3'd0; // addr_offset
            m_axis_rq_tuser_next[11] = 1'b0; // discontinue
            m_axis_rq_tuser_next[12] = 1'b0; // tph_present
            m_axis_rq_tuser_next[14:13] = 2'b00; // tph_type
            m_axis_rq_tuser_next[15] = 1'b0; // tph_indirect_tag_en
            m_axis_rq_tuser_next[23:16] = 8'd0; // tph_st_tag
            m_axis_rq_tuser_next[27:24] = out_tlp_seq[0*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH]; // seq_num
            m_axis_rq_tuser_next[59:28] = 32'd0; // parity
            if (AXIS_PCIE_RQ_USER_WIDTH == 62) begin
                m_axis_rq_tuser_next[61:60] = out_tlp_seq[0*RQ_SEQ_NUM_WIDTH +: RQ_SEQ_NUM_WIDTH] >> 4; // seq_num
            end
        end
    end
end

always @(posedge clk) begin
    max_payload_size_fc_reg <= 9'd8 << (max_payload_size > 5 ? 5 : max_payload_size);
    have_p_credit_reg <= (tx_fc_ph_av > 8) && (tx_fc_pd_av > (max_payload_size_fc_reg << 1));
    have_np_credit_reg <= tx_fc_nph_av > 8;

    frame_reg <= frame_next;
    tlp_hdr1_reg <= tlp_hdr1_next;
    tlp_hdr2_reg <= tlp_hdr2_next;
    tlp_split1_reg <= tlp_split1_next;
    tlp_split2_reg <= tlp_split2_next;
    port_reg <= port_next;

    out_shift_tlp_data_reg <= out_shift_tlp_data_next;
    out_shift_tlp_strb_reg <= out_shift_tlp_strb_next;

    m_axis_rq_tdata_reg <= m_axis_rq_tdata_next;
    m_axis_rq_tkeep_reg <= m_axis_rq_tkeep_next;
    m_axis_rq_tvalid_reg <= m_axis_rq_tvalid_next;
    m_axis_rq_tlast_reg <= m_axis_rq_tlast_next;
    m_axis_rq_tuser_reg <= m_axis_rq_tuser_next;

    if (rst) begin
        frame_reg <= 1'b0;
        port_reg <= 0;

        m_axis_rq_tvalid_reg <= 0;
    end
end

endmodule

`resetall
