/*

Copyright (c) 2021 Alex Forencich

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
 * Intel Stratix 10 H-Tile/L-Tile PCIe interface adapter (transmit)
 */
module pcie_s10_if_tx #
(
    // H-Tile/L-Tile AVST segment count
    parameter SEG_COUNT = 1,
    // H-Tile/L-Tile AVST segment data width
    parameter SEG_DATA_WIDTH = 256,
    // TLP data width
    parameter TLP_DATA_WIDTH = SEG_COUNT*SEG_DATA_WIDTH,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 6
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * H-Tile/L-Tile TX AVST interface
     */
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]        tx_st_data,
    output wire [SEG_COUNT-1:0]                       tx_st_sop,
    output wire [SEG_COUNT-1:0]                       tx_st_eop,
    output wire [SEG_COUNT-1:0]                       tx_st_valid,
    input  wire                                       tx_st_ready,
    output wire [SEG_COUNT-1:0]                       tx_st_err,

    /*
     * H-Tile/L-Tile TX flow control
     */
    input  wire [7:0]                                 tx_ph_cdts,
    input  wire [11:0]                                tx_pd_cdts,
    input  wire [7:0]                                 tx_nph_cdts,
    input  wire [11:0]                                tx_npd_cdts,
    input  wire [7:0]                                 tx_cplh_cdts,
    input  wire [11:0]                                tx_cpld_cdts,
    input  wire [SEG_COUNT-1:0]                       tx_hdr_cdts_consumed,
    input  wire [SEG_COUNT-1:0]                       tx_data_cdts_consumed,
    input  wire [SEG_COUNT*2-1:0]                     tx_cdts_type,
    input  wire [SEG_COUNT*1-1:0]                     tx_cdts_data_value,

    /*
     * TLP input (read request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]     tx_rd_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]  tx_rd_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_rd_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_rd_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_rd_req_tlp_eop,
    output wire                                       tx_rd_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA read request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]      m_axis_rd_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                       m_axis_rd_req_tx_seq_num_valid,

    /*
     * TLP input (write request from DMA)
     */
    input  wire [TLP_DATA_WIDTH-1:0]                  tx_wr_req_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                  tx_wr_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]     tx_wr_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]  tx_wr_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_wr_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_wr_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_wr_req_tlp_eop,
    output wire                                       tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA write request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]      m_axis_wr_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                       m_axis_wr_req_tx_seq_num_valid,

    /*
     * TLP input (completion from BAR)
     */
    input  wire [TLP_DATA_WIDTH-1:0]                  tx_cpl_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                  tx_cpl_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]     tx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_cpl_tlp_eop,
    output wire                                       tx_cpl_tlp_ready,

    /*
     * TLP input (write request from MSI)
     */
    input  wire [31:0]                                tx_msi_wr_req_tlp_data,
    input  wire                                       tx_msi_wr_req_tlp_strb,
    input  wire [TLP_HDR_WIDTH-1:0]                   tx_msi_wr_req_tlp_hdr,
    input  wire                                       tx_msi_wr_req_tlp_valid,
    input  wire                                       tx_msi_wr_req_tlp_sop,
    input  wire                                       tx_msi_wr_req_tlp_eop,
    output wire                                       tx_msi_wr_req_tlp_ready,

    /*
     * Flow control
     */
    output wire [7:0]                                 tx_fc_ph_av,
    output wire [11:0]                                tx_fc_pd_av,
    output wire [7:0]                                 tx_fc_nph_av,
    output wire [11:0]                                tx_fc_npd_av,
    output wire [7:0]                                 tx_fc_cplh_av,
    output wire [11:0]                                tx_fc_cpld_av,

    /*
     * Configuration
     */
    input  wire [2:0]                                 max_payload_size
);

parameter SEG_STRB_WIDTH = SEG_DATA_WIDTH/32;

parameter INT_TLP_SEG_COUNT = SEG_COUNT;
parameter INT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / INT_TLP_SEG_COUNT;
parameter INT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / INT_TLP_SEG_COUNT;

parameter SEG_SEL_WIDTH = $clog2(INT_TLP_SEG_COUNT);

parameter PORTS = 4;
parameter CL_PORTS = $clog2(PORTS);

// bus width assertions
initial begin
    if (SEG_DATA_WIDTH != 256) begin
        $error("Error: segment data width must be 256 (instance %m)");
        $finish;        
    end

    if (TLP_DATA_WIDTH != SEG_COUNT*SEG_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end
end

reg frame_reg = 1'b0, frame_next, frame_cyc;
reg tlp_hdr_4dw_reg = 1'b0, tlp_hdr_4dw_next, tlp_hdr_4dw_cyc;
reg tlp_hdr_cyc;
reg tlp_split1_reg = 1'b0, tlp_split1_next, tlp_split1_cyc;
reg tlp_split2_reg = 1'b0, tlp_split2_next, tlp_split2_cyc;
reg [INT_TLP_SEG_COUNT-1:0] seg_cons_reg = 0, seg_cons_next, seg_cons_cyc;
reg [SEG_SEL_WIDTH-1:0] seg_offset_cyc;
reg [SEG_SEL_WIDTH+1-1:0] seg_count_cyc;
reg valid, eop;
reg frame, abort;

reg [INT_TLP_SEG_COUNT-1:0] port_seg_valid;
reg [INT_TLP_SEG_COUNT-1:0] port_seg_hdr_4dw;
reg [INT_TLP_SEG_COUNT-1:0] port_seg_extra_3dw;
reg [INT_TLP_SEG_COUNT-1:0] port_seg_extra_4dw;
reg [INT_TLP_SEG_COUNT-1:0] port_seg_eop;

reg [INT_TLP_SEG_COUNT-1:0] out_sel_reg = 0, out_sel_next, out_sel_cyc;
reg [INT_TLP_SEG_COUNT-1:0] out_sop_reg = 0, out_sop_next;
reg [INT_TLP_SEG_COUNT-1:0] out_eop_reg = 0, out_eop_next;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_hdr_4dw_reg = 0, out_tlp_hdr_4dw_next;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_hdr_reg = 0, out_tlp_hdr_next;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_split1_reg = 0, out_tlp_split1_next;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_split2_reg = 0, out_tlp_split2_next;
reg [SEG_SEL_WIDTH+1-1:0] out_sel_seg_reg[0:INT_TLP_SEG_COUNT-1], out_sel_seg_next[0:INT_TLP_SEG_COUNT-1];

reg [127:0] out_shift_tlp_data_reg = 0, out_shift_tlp_data_next;

reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] tx_st_data_reg = 0, tx_st_data_next;
reg [SEG_COUNT-1:0] tx_st_sop_reg = 0, tx_st_sop_next;
reg [SEG_COUNT-1:0] tx_st_eop_reg = 0, tx_st_eop_next;
reg [SEG_COUNT-1:0] tx_st_valid_reg = 0, tx_st_valid_next;

reg [1:0] tx_st_ready_delay_reg = 0;

wire [PORTS*TLP_DATA_WIDTH-1:0] mux_in_tlp_data;
wire [PORTS*TLP_STRB_WIDTH-1:0] mux_in_tlp_strb;
wire [PORTS*TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] mux_in_tlp_hdr;
wire [PORTS*TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0] mux_in_tlp_seq;
wire [PORTS*TLP_SEG_COUNT-1:0] mux_in_tlp_valid;
wire [PORTS*TLP_SEG_COUNT-1:0] mux_in_tlp_sop;
wire [PORTS*TLP_SEG_COUNT-1:0] mux_in_tlp_eop;
wire [PORTS-1:0] mux_in_tlp_ready;

wire [TLP_DATA_WIDTH-1:0] mux_out_tlp_data;
wire [TLP_STRB_WIDTH-1:0] mux_out_tlp_strb;
wire [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] mux_out_tlp_hdr;
wire [INT_TLP_SEG_COUNT-1:0] mux_out_tlp_valid;
wire [INT_TLP_SEG_COUNT-1:0] mux_out_tlp_sop;
wire [INT_TLP_SEG_COUNT-1:0] mux_out_tlp_eop;
wire mux_out_tlp_ready;

wire [PORTS-1:0] mux_pause;

wire [PORTS*INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0] mux_out_sel_tlp_seq;
wire [PORTS*INT_TLP_SEG_COUNT-1:0] mux_out_sel_tlp_seq_valid;

wire [TLP_DATA_WIDTH-1:0] fifo_tlp_data;
wire [TLP_STRB_WIDTH-1:0] fifo_tlp_strb;
wire [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] fifo_tlp_hdr;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_valid;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_sop;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_eop;
wire [SEG_SEL_WIDTH-1:0] fifo_seg_offset;
wire [SEG_SEL_WIDTH+1-1:0] fifo_seg_count;
reg fifo_read_en_reg = 1'b0, fifo_read_en_next;
reg [SEG_SEL_WIDTH+1-1:0] fifo_read_seg_count_reg, fifo_read_seg_count_next;

wire [TLP_STRB_WIDTH-1:0] fifo_ctrl_tlp_strb;
wire [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] fifo_ctrl_tlp_hdr;
wire [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_valid;
wire [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_sop;
wire [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_eop;
wire [SEG_SEL_WIDTH-1:0] fifo_ctrl_seg_offset;
wire [SEG_SEL_WIDTH+1-1:0] fifo_ctrl_seg_count;
reg fifo_ctrl_read_en;
reg [SEG_SEL_WIDTH+1-1:0] fifo_ctrl_read_seg_count;

reg [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_hdr_4dw;
reg [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_extra_3dw;
reg [INT_TLP_SEG_COUNT-1:0] fifo_ctrl_tlp_extra_4dw;

wire [3:0] mux_tx_fc_ph, out_tx_fc_ph;
wire [8:0] mux_tx_fc_pd, out_tx_fc_pd;
wire [3:0] mux_tx_fc_nph, out_tx_fc_nph;
wire [8:0] mux_tx_fc_npd, out_tx_fc_npd;
wire [3:0] mux_tx_fc_cplh, out_tx_fc_cplh;
wire [8:0] mux_tx_fc_cpld, out_tx_fc_cpld;

reg [7:0] int_tx_fc_ph_reg = 0;
reg [11:0] int_tx_fc_pd_reg = 0;
reg [7:0] int_tx_fc_nph_reg = 0;
reg [11:0] int_tx_fc_npd_reg = 0;
reg [7:0] int_tx_fc_cplh_reg = 0;
reg [11:0] int_tx_fc_cpld_reg = 0;

reg [7:0] adj_tx_fc_ph_reg = 0;
reg [11:0] adj_tx_fc_pd_reg = 0;
reg [7:0] adj_tx_fc_nph_reg = 0;
reg [11:0] adj_tx_fc_npd_reg = 0;
reg [7:0] adj_tx_fc_cplh_reg = 0;
reg [11:0] adj_tx_fc_cpld_reg = 0;

reg [8:0] max_payload_size_fc_reg = 9'd0;
reg have_p_credit_reg = 1'b0;
reg have_np_credit_reg = 1'b0;
reg have_cpl_credit_reg = 1'b0;

assign mux_in_tlp_data[TLP_DATA_WIDTH*0 +: TLP_DATA_WIDTH] = tx_msi_wr_req_tlp_data;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*0 +: TLP_STRB_WIDTH] = tx_msi_wr_req_tlp_strb;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*0 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_msi_wr_req_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*0 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = 0;
assign mux_in_tlp_valid[TLP_SEG_COUNT*0 +: TLP_SEG_COUNT] = tx_msi_wr_req_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*0 +: TLP_SEG_COUNT] = tx_msi_wr_req_tlp_sop;
assign mux_in_tlp_eop[TLP_SEG_COUNT*0 +: TLP_SEG_COUNT] = tx_msi_wr_req_tlp_eop;
assign tx_msi_wr_req_tlp_ready = mux_in_tlp_ready[0 +: 1];

assign mux_pause[0] = !have_p_credit_reg;

assign mux_in_tlp_data[TLP_DATA_WIDTH*1 +: TLP_DATA_WIDTH] = tx_cpl_tlp_data;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*1 +: TLP_STRB_WIDTH] = tx_cpl_tlp_strb;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*1 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_cpl_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*1 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = 0;
assign mux_in_tlp_valid[TLP_SEG_COUNT*1 +: TLP_SEG_COUNT] = tx_cpl_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*1 +: TLP_SEG_COUNT] = tx_cpl_tlp_sop;
assign mux_in_tlp_eop[TLP_SEG_COUNT*1 +: TLP_SEG_COUNT] = tx_cpl_tlp_eop;
assign tx_cpl_tlp_ready = mux_in_tlp_ready[1 +: 1];

assign mux_pause[1] = !have_cpl_credit_reg;

assign mux_in_tlp_data[TLP_DATA_WIDTH*2 +: TLP_DATA_WIDTH] = 0;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*2 +: TLP_STRB_WIDTH] = 0;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*2 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_rd_req_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*2 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = tx_rd_req_tlp_seq;
assign mux_in_tlp_valid[TLP_SEG_COUNT*2 +: TLP_SEG_COUNT] = tx_rd_req_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*2 +: TLP_SEG_COUNT] = {TLP_SEG_COUNT{1'b1}};
assign mux_in_tlp_eop[TLP_SEG_COUNT*2 +: TLP_SEG_COUNT] = {TLP_SEG_COUNT{1'b1}};
assign tx_rd_req_tlp_ready = mux_in_tlp_ready[2 +: 1];

assign mux_pause[2] = !have_np_credit_reg;

assign mux_in_tlp_data[TLP_DATA_WIDTH*3 +: TLP_DATA_WIDTH] = tx_wr_req_tlp_data;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*3 +: TLP_STRB_WIDTH] = tx_wr_req_tlp_strb;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*3 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_wr_req_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*3 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = tx_wr_req_tlp_seq;
assign mux_in_tlp_valid[TLP_SEG_COUNT*3 +: TLP_SEG_COUNT] = tx_wr_req_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*3 +: TLP_SEG_COUNT] = tx_wr_req_tlp_sop;
assign mux_in_tlp_eop[TLP_SEG_COUNT*3 +: TLP_SEG_COUNT] = tx_wr_req_tlp_eop;
assign tx_wr_req_tlp_ready = mux_in_tlp_ready[3 +: 1];

assign mux_pause[3] = !have_p_credit_reg;

assign m_axis_rd_req_tx_seq_num = mux_out_sel_tlp_seq[INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*2 +: INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH];
assign m_axis_rd_req_tx_seq_num_valid = mux_out_sel_tlp_seq_valid[INT_TLP_SEG_COUNT*2 +: INT_TLP_SEG_COUNT];
assign m_axis_wr_req_tx_seq_num = mux_out_sel_tlp_seq[INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*3 +: INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH];
assign m_axis_wr_req_tx_seq_num_valid = mux_out_sel_tlp_seq_valid[INT_TLP_SEG_COUNT*3 +: INT_TLP_SEG_COUNT];

assign tx_st_data = tx_st_data_reg;
assign tx_st_sop = tx_st_sop_reg;
assign tx_st_eop = tx_st_eop_reg;
assign tx_st_valid = tx_st_valid_reg;
assign tx_st_err = 0;

assign tx_fc_ph_av = adj_tx_fc_ph_reg;
assign tx_fc_pd_av = adj_tx_fc_pd_reg;
assign tx_fc_nph_av = adj_tx_fc_nph_reg;
assign tx_fc_npd_av = adj_tx_fc_npd_reg;
assign tx_fc_cplh_av = adj_tx_fc_cplh_reg;
assign tx_fc_cpld_av = adj_tx_fc_cpld_reg;

pcie_tlp_fifo_mux #(
    .PORTS(PORTS),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .IN_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(1),
    .FIFO_DEPTH((1024/4)*2)
)
pcie_tlp_fifo_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(mux_in_tlp_data),
    .in_tlp_strb(mux_in_tlp_strb),
    .in_tlp_hdr(mux_in_tlp_hdr),
    .in_tlp_seq(mux_in_tlp_seq),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid(mux_in_tlp_valid),
    .in_tlp_sop(mux_in_tlp_sop),
    .in_tlp_eop(mux_in_tlp_eop),
    .in_tlp_ready(mux_in_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(mux_out_tlp_data),
    .out_tlp_strb(mux_out_tlp_strb),
    .out_tlp_hdr(mux_out_tlp_hdr),
    .out_tlp_seq(),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(),
    .out_tlp_valid(mux_out_tlp_valid),
    .out_tlp_sop(mux_out_tlp_sop),
    .out_tlp_eop(mux_out_tlp_eop),
    .out_tlp_ready(mux_out_tlp_ready),

    /*
     * Flow control count output
     */
    .out_fc_ph(mux_tx_fc_ph),
    .out_fc_pd(mux_tx_fc_pd),
    .out_fc_nph(mux_tx_fc_nph),
    .out_fc_npd(mux_tx_fc_npd),
    .out_fc_cplh(mux_tx_fc_cplh),
    .out_fc_cpld(mux_tx_fc_cpld),

    /*
     * Control
     */
    .pause(mux_pause),

    /*
     * Status
     */
    .sel_tlp_seq(mux_out_sel_tlp_seq),
    .sel_tlp_seq_valid(mux_out_sel_tlp_seq_valid),
    .fifo_half_full(),
    .fifo_watermark()
);

pcie_tlp_fifo_raw #(
    .DEPTH((1024/4)*2),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(1),
    .IN_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .CTRL_OUT_EN(1)
)
pcie_tlp_fifo_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(mux_out_tlp_data),
    .in_tlp_strb(mux_out_tlp_strb),
    .in_tlp_hdr(mux_out_tlp_hdr),
    .in_tlp_seq(0),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid(mux_out_tlp_valid),
    .in_tlp_sop(mux_out_tlp_sop),
    .in_tlp_eop(mux_out_tlp_eop),
    .in_tlp_ready(mux_out_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(fifo_tlp_data),
    .out_tlp_strb(fifo_tlp_strb),
    .out_tlp_hdr(fifo_tlp_hdr),
    .out_tlp_seq(),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(),
    .out_tlp_valid(fifo_tlp_valid),
    .out_tlp_sop(fifo_tlp_sop),
    .out_tlp_eop(fifo_tlp_eop),
    .out_seg_offset(fifo_seg_offset),
    .out_seg_count(fifo_seg_count),
    .out_read_en(fifo_read_en_reg),
    .out_read_seg_count(fifo_read_seg_count_reg),

    .out_ctrl_tlp_strb(fifo_ctrl_tlp_strb),
    .out_ctrl_tlp_hdr(fifo_ctrl_tlp_hdr),
    .out_ctrl_tlp_valid(fifo_ctrl_tlp_valid),
    .out_ctrl_tlp_sop(fifo_ctrl_tlp_sop),
    .out_ctrl_tlp_eop(fifo_ctrl_tlp_eop),
    .out_ctrl_seg_offset(fifo_ctrl_seg_offset),
    .out_ctrl_seg_count(fifo_ctrl_seg_count),
    .out_ctrl_read_en(fifo_ctrl_read_en),
    .out_ctrl_read_seg_count(fifo_ctrl_read_seg_count),

    /*
     * Status
     */
    .half_full(),
    .watermark()
);

reg [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] fc_delay_fifo_hdr_mem[31:0];
reg [INT_TLP_SEG_COUNT-1:0] fc_delay_fifo_valid_mem[31:0];
reg [4:0] fc_delay_fifo_wr_ptr_reg = 0;
reg [4:0] fc_delay_fifo_rd_ptr_reg = 0;

always @(posedge clk) begin
    fc_delay_fifo_hdr_mem[fc_delay_fifo_wr_ptr_reg] <= fifo_tlp_hdr;
    fc_delay_fifo_valid_mem[fc_delay_fifo_wr_ptr_reg] <= seg_cons_reg & fifo_tlp_sop;

    fc_delay_fifo_wr_ptr_reg <= fc_delay_fifo_wr_ptr_reg + 1;
    if (fc_delay_fifo_wr_ptr_reg - fc_delay_fifo_rd_ptr_reg >= 23) begin
        fc_delay_fifo_rd_ptr_reg <= fc_delay_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        fc_delay_fifo_wr_ptr_reg <= 0;
        fc_delay_fifo_rd_ptr_reg <= 0;
    end
end

pcie_tlp_fc_count #(
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(INT_TLP_SEG_COUNT)
)
fc_count_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP monitor
     */
    .tlp_hdr(fc_delay_fifo_hdr_mem[fc_delay_fifo_rd_ptr_reg]),
    .tlp_valid(fc_delay_fifo_valid_mem[fc_delay_fifo_rd_ptr_reg]),
    .tlp_sop({INT_TLP_SEG_COUNT{1'b1}}),
    .tlp_ready(1'b1),

    /*
     * Flow control count output
     */
    .out_fc_ph(out_tx_fc_ph),
    .out_fc_pd(out_tx_fc_pd),
    .out_fc_nph(out_tx_fc_nph),
    .out_fc_npd(out_tx_fc_npd),
    .out_fc_cplh(out_tx_fc_cplh),
    .out_fc_cpld(out_tx_fc_cpld)
);

integer seg, cur_seg;

always @* begin
    frame_next = frame_reg;
    tlp_hdr_4dw_next = tlp_hdr_4dw_reg;
    tlp_split1_next = tlp_split1_reg;
    tlp_split2_next = tlp_split2_reg;

    tx_st_data_next = 0;
    tx_st_sop_next = 0;
    tx_st_eop_next = 0;
    tx_st_valid_next = 0;

    fifo_read_en_next = 0;
    fifo_read_seg_count_next = 0;
    fifo_ctrl_read_en = 0;
    fifo_ctrl_read_seg_count = 0;

    frame_cyc = frame_reg;
    tlp_hdr_4dw_cyc = tlp_hdr_4dw_reg;
    tlp_hdr_cyc = 1'b0;
    tlp_split1_cyc = tlp_split1_reg;
    tlp_split2_cyc = tlp_split2_reg;
    seg_cons_cyc = 0;
    seg_cons_next = 0;
    seg_offset_cyc = fifo_ctrl_seg_offset;
    seg_count_cyc = 0;
    valid = 0;
    eop = 0;
    frame = frame_cyc;
    abort = 0;

    out_sel_next = 0;
    out_sel_cyc = 0;
    out_sop_next = 0;
    out_eop_next = 0;
    out_tlp_hdr_4dw_next = 0;
    out_tlp_hdr_next = 0;
    out_tlp_split1_next = 0;
    out_tlp_split2_next = 0;
    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        out_sel_seg_next[seg] = 0;
    end

    out_shift_tlp_data_next = out_shift_tlp_data_reg;

    // pre-compute
    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        fifo_ctrl_tlp_hdr_4dw[seg] = fifo_ctrl_tlp_hdr[seg*TLP_HDR_WIDTH+125];
        fifo_ctrl_tlp_extra_3dw[seg] = fifo_ctrl_tlp_eop[seg] && fifo_ctrl_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] >> (INT_TLP_SEG_STRB_WIDTH-3);
        fifo_ctrl_tlp_extra_4dw[seg] = fifo_ctrl_tlp_eop[seg] && fifo_ctrl_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] >> (INT_TLP_SEG_STRB_WIDTH-4);
    end

    // compute mux settings
    port_seg_valid = {2{fifo_ctrl_tlp_valid}} >> fifo_ctrl_seg_offset;
    port_seg_hdr_4dw = {2{fifo_ctrl_tlp_hdr_4dw}} >> fifo_ctrl_seg_offset;
    port_seg_eop = {2{fifo_ctrl_tlp_eop}} >> fifo_ctrl_seg_offset;
    port_seg_extra_3dw = {2{fifo_ctrl_tlp_extra_3dw}} >> fifo_ctrl_seg_offset;
    port_seg_extra_4dw = {2{fifo_ctrl_tlp_extra_4dw}} >> fifo_ctrl_seg_offset;

    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        if (!frame_cyc && !abort) begin
            tlp_hdr_cyc = 1'b1;
            tlp_split1_cyc = 1'b0;
            tlp_split2_cyc = 1'b0;
            if (port_seg_valid[0]) begin
                frame_cyc = 1'b1;
                tlp_hdr_4dw_cyc = port_seg_hdr_4dw[0];
            end
        end

        // route segment
        valid = port_seg_valid[0];
        eop = port_seg_eop[0];
        frame = frame_cyc;

        out_sel_cyc[seg] = 1'b1;
        out_sop_next[seg] = tlp_hdr_cyc;
        out_tlp_hdr_4dw_next[seg] = tlp_hdr_4dw_cyc;
        out_tlp_hdr_next[seg] = tlp_hdr_cyc;
        out_sel_seg_next[seg] = seg_offset_cyc;

        if (tlp_hdr_4dw_cyc ? port_seg_extra_4dw[0] : port_seg_extra_3dw[0]) begin
            // extra cycle
            tlp_hdr_cyc = 1'b0;
            if (tlp_split1_cyc) begin
                frame_cyc = 0;
                out_eop_next[seg] = 1'b1;
                tlp_split1_cyc = 1'b0;
                tlp_split2_cyc = 1'b1;
                seg_cons_cyc[seg_offset_cyc] = 1'b1;
                seg_offset_cyc = seg_offset_cyc + 1;
                seg_count_cyc = seg_count_cyc + 1;
                port_seg_valid = port_seg_valid >> 1;
                port_seg_hdr_4dw = port_seg_hdr_4dw >> 1;
                port_seg_eop = port_seg_eop >> 1;
                port_seg_extra_3dw = port_seg_extra_3dw >> 1;
                port_seg_extra_4dw = port_seg_extra_4dw >> 1;
            end else begin
                tlp_split1_cyc = 1'b1;
            end
        end else begin
            tlp_hdr_cyc = 1'b0;
            if (eop) begin
                // end of packet
                frame_cyc = 0;
                out_eop_next[seg] = 1'b1;
            end
            seg_cons_cyc[seg_offset_cyc] = 1'b1;
            seg_offset_cyc = seg_offset_cyc + 1;
            seg_count_cyc = seg_count_cyc + 1;
            port_seg_valid = port_seg_valid >> 1;
            port_seg_hdr_4dw = port_seg_hdr_4dw >> 1;
            port_seg_eop = port_seg_eop >> 1;
            port_seg_extra_3dw = port_seg_extra_3dw >> 1;
            port_seg_extra_4dw = port_seg_extra_4dw >> 1;
        end

        out_tlp_split1_next[seg] = tlp_split1_cyc;
        out_tlp_split2_next[seg] = tlp_split2_cyc;

        if (frame && !abort) begin
            if (valid) begin
                if (eop || seg == INT_TLP_SEG_COUNT-1) begin
                    // end of packet or end of cycle, commit
                    fifo_ctrl_read_seg_count = seg_count_cyc;
                    fifo_read_seg_count_next = seg_count_cyc;
                    if (tx_st_ready_delay_reg[0]) begin
                        frame_next = frame_cyc;
                        tlp_hdr_4dw_next = tlp_hdr_4dw_cyc;
                        tlp_split1_next = tlp_split1_cyc;
                        tlp_split2_next = tlp_split2_cyc;
                        out_sel_next = out_sel_cyc;
                        fifo_ctrl_read_en = seg_count_cyc != 0;
                        fifo_read_en_next = seg_count_cyc != 0;
                        seg_cons_next = seg_cons_cyc;
                    end
                end
            end else begin
                // input has stalled, wait
                abort = 1;
            end
        end
    end

    // mux for output segments
    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        if (out_tlp_hdr_4dw_reg[seg]) begin
            tx_st_data_next[seg*SEG_DATA_WIDTH +: SEG_DATA_WIDTH] = out_shift_tlp_data_next;
            tx_st_data_next[seg*SEG_DATA_WIDTH+128 +: SEG_DATA_WIDTH-128] = fifo_tlp_data[out_sel_seg_reg[seg]*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH-128];
        end else begin
            tx_st_data_next[seg*SEG_DATA_WIDTH +: SEG_DATA_WIDTH] = out_shift_tlp_data_next >> 32;
            tx_st_data_next[seg*SEG_DATA_WIDTH+96 +: SEG_DATA_WIDTH-96] = fifo_tlp_data[out_sel_seg_reg[seg]*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH-96];
        end
        if (out_tlp_hdr_reg[seg]) begin
            tx_st_data_next[seg*SEG_DATA_WIDTH+0 +: 32] = fifo_tlp_hdr[out_sel_seg_reg[seg]*TLP_HDR_WIDTH+96 +: 32];
            tx_st_data_next[seg*SEG_DATA_WIDTH+32 +: 32] = fifo_tlp_hdr[out_sel_seg_reg[seg]*TLP_HDR_WIDTH+64 +: 32];
            tx_st_data_next[seg*SEG_DATA_WIDTH+64 +: 32] = fifo_tlp_hdr[out_sel_seg_reg[seg]*TLP_HDR_WIDTH+32 +: 32];
            if (out_tlp_hdr_4dw_reg[seg]) begin
                tx_st_data_next[seg*SEG_DATA_WIDTH+96 +: 32] = fifo_tlp_hdr[out_sel_seg_reg[seg]*TLP_HDR_WIDTH+0 +: 32];
            end
        end
        tx_st_valid_next[seg +: 1] = out_sel_reg[seg];
        tx_st_sop_next[seg +: 1] = out_sop_reg[seg];
        tx_st_eop_next[seg +: 1] = out_eop_reg[seg];

        if (out_sel_reg[seg]) begin
            out_shift_tlp_data_next = fifo_tlp_data[(out_sel_seg_reg[seg]+1)*INT_TLP_SEG_DATA_WIDTH-128 +: 128];
        end
    end
end

integer i;

always @(posedge clk) begin
    frame_reg <= frame_next;
    tlp_hdr_4dw_reg <= tlp_hdr_4dw_next;
    tlp_split1_reg <= tlp_split1_next;
    tlp_split2_reg <= tlp_split2_next;
    seg_cons_reg <= seg_cons_next;

    out_sel_reg <= out_sel_next;
    out_sop_reg <= out_sop_next;
    out_eop_reg <= out_eop_next;
    out_tlp_hdr_4dw_reg <= out_tlp_hdr_4dw_next;
    out_tlp_hdr_reg <= out_tlp_hdr_next;
    out_tlp_split1_reg <= out_tlp_split1_next;
    out_tlp_split2_reg <= out_tlp_split2_next;
    for (i = 0; i < INT_TLP_SEG_COUNT; i = i + 1) begin
        out_sel_seg_reg[i] <= out_sel_seg_next[i];
    end

    fifo_read_en_reg <= fifo_read_en_next;
    fifo_read_seg_count_reg <= fifo_read_seg_count_next;

    out_shift_tlp_data_reg <= out_shift_tlp_data_next;

    tx_st_data_reg <= tx_st_data_next;
    tx_st_sop_reg <= tx_st_sop_next;
    tx_st_eop_reg <= tx_st_eop_next;
    tx_st_valid_reg <= tx_st_valid_next;

    tx_st_ready_delay_reg <= {tx_st_ready_delay_reg, tx_st_ready};

    // flow control
    int_tx_fc_ph_reg <= int_tx_fc_ph_reg + mux_tx_fc_ph - out_tx_fc_ph;
    int_tx_fc_pd_reg <= int_tx_fc_pd_reg + mux_tx_fc_pd - out_tx_fc_pd;
    int_tx_fc_nph_reg <= int_tx_fc_nph_reg + mux_tx_fc_nph - out_tx_fc_nph;
    int_tx_fc_npd_reg <= int_tx_fc_npd_reg + mux_tx_fc_npd - out_tx_fc_npd;
    int_tx_fc_cplh_reg <= int_tx_fc_cplh_reg + mux_tx_fc_cplh - out_tx_fc_cplh;
    int_tx_fc_cpld_reg <= int_tx_fc_cpld_reg + mux_tx_fc_cpld - out_tx_fc_cpld;

    adj_tx_fc_ph_reg <= tx_ph_cdts > int_tx_fc_ph_reg ? tx_ph_cdts - int_tx_fc_ph_reg : 0;
    adj_tx_fc_pd_reg <= tx_pd_cdts > int_tx_fc_pd_reg ? tx_pd_cdts - int_tx_fc_pd_reg : 0;
    adj_tx_fc_nph_reg <= tx_nph_cdts > int_tx_fc_nph_reg ? tx_nph_cdts - int_tx_fc_nph_reg : 0;
    adj_tx_fc_npd_reg <= tx_npd_cdts > int_tx_fc_npd_reg ? tx_npd_cdts - int_tx_fc_npd_reg : 0;
    adj_tx_fc_cplh_reg <= tx_cplh_cdts > int_tx_fc_cplh_reg ? tx_cplh_cdts - int_tx_fc_cplh_reg : 0;
    adj_tx_fc_cpld_reg <= tx_cpld_cdts > int_tx_fc_cpld_reg ? tx_cpld_cdts - int_tx_fc_cpld_reg : 0;

    max_payload_size_fc_reg <= 9'd8 << (max_payload_size > 5 ? 5 : max_payload_size);
    have_p_credit_reg <= (adj_tx_fc_ph_reg > 4) && (adj_tx_fc_pd_reg > (max_payload_size_fc_reg << 1));
    have_np_credit_reg <= adj_tx_fc_nph_reg > 4;
    have_cpl_credit_reg <= (adj_tx_fc_cplh_reg > 4) && (adj_tx_fc_cpld_reg > (max_payload_size_fc_reg << 1));

    if (rst) begin
        frame_reg <= 1'b0;

        out_sel_reg <= 0;

        fifo_read_en_reg <= 1'b0;

        tx_st_valid_reg <= 0;
        tx_st_ready_delay_reg <= 0;

        int_tx_fc_ph_reg <= 0;
        int_tx_fc_pd_reg <= 0;
        int_tx_fc_nph_reg <= 0;
        int_tx_fc_npd_reg <= 0;
        int_tx_fc_cplh_reg <= 0;
        int_tx_fc_cpld_reg <= 0;

        adj_tx_fc_ph_reg <= 0;
        adj_tx_fc_pd_reg <= 0;
        adj_tx_fc_nph_reg <= 0;
        adj_tx_fc_npd_reg <= 0;
        adj_tx_fc_cplh_reg <= 0;
        adj_tx_fc_cpld_reg <= 0;
    end
end

endmodule

`resetall
