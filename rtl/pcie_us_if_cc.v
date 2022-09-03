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
 * Xilinx UltraScale PCIe interface adapter (Completer Completion)
 */
module pcie_us_if_cc #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream CC tuser signal width
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81,
    // CC interface TLP straddling
    parameter CC_STRADDLE = AXIS_PCIE_DATA_WIDTH >= 512,
    // TLP data width
    parameter TLP_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1
)
(
    input  wire                                    clk,
    input  wire                                    rst,

    /*
     * AXI output (CC)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]         m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]         m_axis_cc_tkeep,
    output wire                                    m_axis_cc_tvalid,
    input  wire                                    m_axis_cc_tready,
    output wire                                    m_axis_cc_tlast,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0]      m_axis_cc_tuser,

    /*
     * TLP input (completion from BAR)
     */
    input  wire [TLP_DATA_WIDTH-1:0]               tx_cpl_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]               tx_cpl_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  tx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_eop,
    output wire                                    tx_cpl_tlp_ready
);

parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter INT_TLP_SEG_COUNT = (CC_STRADDLE && AXIS_PCIE_DATA_WIDTH >= 512) ? 2 : 1;
parameter INT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / INT_TLP_SEG_COUNT;
parameter INT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / INT_TLP_SEG_COUNT;

parameter SEG_SEL_WIDTH = $clog2(INT_TLP_SEG_COUNT);

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
        if (AXIS_PCIE_CC_USER_WIDTH != 81) begin
            $error("Error: PCIe CC tuser width must be 81 (instance %m)");
            $finish;
        end
    end else begin
        if (AXIS_PCIE_CC_USER_WIDTH != 33) begin
            $error("Error: PCIe CC tuser width must be 33 (instance %m)");
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
end

localparam [2:0]
    TLP_FMT_3DW = 3'b000,
    TLP_FMT_4DW = 3'b001,
    TLP_FMT_3DW_DATA = 3'b010,
    TLP_FMT_4DW_DATA = 3'b011,
    TLP_FMT_PREFIX = 3'b100;

localparam [2:0]
    CPL_STATUS_SC  = 3'b000, // successful completion
    CPL_STATUS_UR  = 3'b001, // unsupported request
    CPL_STATUS_CRS = 3'b010, // configuration request retry status
    CPL_STATUS_CA  = 3'b100; // completer abort

reg frame_reg = 1'b0, frame_next, frame_cyc;
reg tlp_hdr1_reg = 1'b0, tlp_hdr1_next, tlp_hdr1_cyc;
reg tlp_hdr2_reg = 1'b0, tlp_hdr2_next, tlp_hdr2_cyc;
reg tlp_split1_reg = 1'b0, tlp_split1_next, tlp_split1_cyc;
reg tlp_split2_reg = 1'b0, tlp_split2_next, tlp_split2_cyc;
reg [SEG_SEL_WIDTH-1:0] seg_offset_cyc;
reg [SEG_SEL_WIDTH+1-1:0] seg_count_cyc;
reg valid, sop, eop;
reg frame, abort;

reg [INT_TLP_SEG_COUNT-1:0] out_sel, out_sel_cyc;
reg [INT_TLP_SEG_COUNT-1:0] out_sop;
reg [INT_TLP_SEG_COUNT-1:0] out_eop;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_hdr1;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_hdr2;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_split1;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_split2;
reg [SEG_SEL_WIDTH+1-1:0] out_sel_seg[0:INT_TLP_SEG_COUNT-1];

reg [TLP_DATA_WIDTH-1:0] out_tlp_data;
reg [TLP_STRB_WIDTH-1:0] out_tlp_strb;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_valid;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_sop;
reg [INT_TLP_SEG_COUNT-1:0] out_tlp_eop;
reg [95:0] out_shift_tlp_data_reg = 0, out_shift_tlp_data_next;
reg [2:0] out_shift_tlp_strb_reg = 0, out_shift_tlp_strb_next;

reg [127:0] seg_tlp_hdr;
reg [95:0] seg_cc_hdr;
reg [INT_TLP_SEG_COUNT*3-1:0] eop_index;

reg [AXIS_PCIE_DATA_WIDTH-1:0] m_axis_cc_tdata_reg = 0, m_axis_cc_tdata_next;
reg [AXIS_PCIE_KEEP_WIDTH-1:0] m_axis_cc_tkeep_reg = 0, m_axis_cc_tkeep_next;
reg m_axis_cc_tvalid_reg = 1'b0, m_axis_cc_tvalid_next;
reg m_axis_cc_tlast_reg = 1'b0, m_axis_cc_tlast_next;
reg [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser_reg = 0, m_axis_cc_tuser_next;

assign m_axis_cc_tdata = m_axis_cc_tdata_reg;
assign m_axis_cc_tkeep = m_axis_cc_tkeep_reg;
assign m_axis_cc_tvalid = m_axis_cc_tvalid_reg;
assign m_axis_cc_tlast = m_axis_cc_tlast_reg;
assign m_axis_cc_tuser = m_axis_cc_tuser_reg;

wire [TLP_DATA_WIDTH-1:0] fifo_tlp_data;
wire [TLP_STRB_WIDTH-1:0] fifo_tlp_strb;
wire [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] fifo_tlp_hdr;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_valid;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_sop;
wire [INT_TLP_SEG_COUNT-1:0] fifo_tlp_eop;
wire [SEG_SEL_WIDTH-1:0] fifo_seg_offset;
wire [SEG_SEL_WIDTH+1-1:0] fifo_seg_count;
reg fifo_read_en;
reg [SEG_SEL_WIDTH+1-1:0] fifo_read_seg_count;

// completions
pcie_tlp_fifo_raw #(
    .DEPTH((1024/4)*2),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(1),
    .IN_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .CTRL_OUT_EN(0)
)
cpl_fifo_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(tx_cpl_tlp_data),
    .in_tlp_strb(tx_cpl_tlp_strb),
    .in_tlp_hdr(tx_cpl_tlp_hdr),
    .in_tlp_seq(0),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid(tx_cpl_tlp_valid),
    .in_tlp_sop(tx_cpl_tlp_sop),
    .in_tlp_eop(tx_cpl_tlp_eop),
    .in_tlp_ready(tx_cpl_tlp_ready),

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
    .out_read_en(fifo_read_en),
    .out_read_seg_count(fifo_read_seg_count),

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

integer seg, cur_seg, lane;

always @* begin
    frame_next = frame_reg;
    tlp_hdr1_next = tlp_hdr1_reg;
    tlp_hdr2_next = tlp_hdr2_reg;
    tlp_split1_next = tlp_split1_reg;
    tlp_split2_next = tlp_split2_reg;

    m_axis_cc_tdata_next = m_axis_cc_tdata_reg;
    m_axis_cc_tkeep_next = m_axis_cc_tkeep_reg;
    m_axis_cc_tvalid_next = m_axis_cc_tvalid_reg && !m_axis_cc_tready;
    m_axis_cc_tlast_next = m_axis_cc_tlast_reg;
    m_axis_cc_tuser_next = m_axis_cc_tuser_reg;

    fifo_read_en = 0;

    frame_cyc = frame_reg;
    tlp_hdr1_cyc = tlp_hdr1_reg;
    tlp_hdr2_cyc = tlp_hdr2_reg;
    tlp_split1_cyc = tlp_split1_reg;
    tlp_split2_cyc = tlp_split2_reg;
    seg_offset_cyc = fifo_seg_offset;
    seg_count_cyc = 0;
    valid = 0;
    eop = 0;
    frame = frame_cyc;
    abort = 0;

    fifo_read_seg_count = 0;

    out_sel = 0;
    out_sel_cyc = 0;
    out_sop = 0;
    out_eop = 0;
    out_tlp_hdr1 = 0;
    out_tlp_hdr2 = 0;
    out_tlp_split1 = 0;
    out_tlp_split2 = 0;
    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        out_sel_seg[seg] = 0;
    end

    out_shift_tlp_data_next = out_shift_tlp_data_reg;
    out_shift_tlp_strb_next = out_shift_tlp_strb_reg;

    // compute mux settings
    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        if (!frame_cyc && !abort) begin
            tlp_hdr1_cyc = 1'b1;
            tlp_hdr2_cyc = 1'b0;
            tlp_split1_cyc = 1'b0;
            tlp_split2_cyc = 1'b0;
            if (fifo_tlp_valid[seg_offset_cyc]) begin
                frame_cyc = 1'b1;
            end
        end

        // route segment
        valid = fifo_tlp_valid[seg_offset_cyc];
        sop = fifo_tlp_sop[seg_offset_cyc];
        eop = fifo_tlp_eop[seg_offset_cyc];
        frame = frame_cyc;

        out_sel_cyc[seg] = 1'b1;
        out_sop[seg] = tlp_hdr1_cyc;
        out_sel_seg[seg] = seg_offset_cyc;

        out_tlp_hdr1[seg] = tlp_hdr1_cyc;
        out_tlp_hdr2[seg] = tlp_hdr2_cyc;

        if (AXIS_PCIE_DATA_WIDTH == 64 && tlp_hdr1_cyc) begin
            // output header
            tlp_hdr1_cyc = 1'b0;
            tlp_hdr2_cyc = 1'b1;
        end else if (eop && fifo_tlp_strb[seg_offset_cyc*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] >> (INT_TLP_SEG_STRB_WIDTH-(AXIS_PCIE_DATA_WIDTH == 64 ? 1 : 3))) begin
            // extra cycle
            tlp_hdr1_cyc = 1'b0;
            tlp_hdr2_cyc = 1'b0;
            if (tlp_split1_cyc) begin
                frame_cyc = 0;
                out_eop[seg] = 1'b1;
                tlp_split1_cyc = 1'b0;
                tlp_split2_cyc = 1'b1;
                seg_offset_cyc = seg_offset_cyc + 1;
                seg_count_cyc = seg_count_cyc + 1;
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
        end

        out_tlp_split1[seg] = tlp_split1_cyc;
        out_tlp_split2[seg] = tlp_split2_cyc;

        if (frame && !abort) begin
            if (valid) begin
                if (eop || seg == INT_TLP_SEG_COUNT-1) begin
                    // end of packet or end of cycle, commit
                    fifo_read_seg_count = seg_count_cyc;
                    if (!m_axis_cc_tvalid || m_axis_cc_tready) begin
                        frame_next = frame_cyc;
                        tlp_hdr1_next = tlp_hdr1_cyc;
                        tlp_hdr2_next = tlp_hdr2_cyc;
                        tlp_split1_next = tlp_split1_cyc;
                        tlp_split2_next = tlp_split2_cyc;
                        out_sel = out_sel_cyc;
                        fifo_read_en = seg_count_cyc != 0;
                    end
                end
            end else begin
                // input has stalled, wait
                abort = 1;
            end
        end
    end

    out_tlp_data = 0;
    out_tlp_strb = 0;
    out_tlp_valid = 0;
    out_tlp_sop = 0;
    out_tlp_eop = 0;

    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        // remap header
        seg_tlp_hdr = fifo_tlp_hdr[out_sel_seg[seg]*TLP_HDR_WIDTH +: TLP_HDR_WIDTH];
        seg_cc_hdr[6:0] = seg_tlp_hdr[38:32]; // lower address
        seg_cc_hdr[7] = 1'b0;
        seg_cc_hdr[9:8] = seg_tlp_hdr[107:106]; // AT
        seg_cc_hdr[15:10] = 6'd0;
        seg_cc_hdr[28:16] = seg_tlp_hdr[75:64]; // Byte count
        seg_cc_hdr[29] = 1'b0; // locked read completion
        seg_cc_hdr[31:30] = 2'd0;
        seg_cc_hdr[42:32] = seg_tlp_hdr[105:96]; // DWORD count
        seg_cc_hdr[45:43] = seg_tlp_hdr[79:77]; // completion status
        seg_cc_hdr[46] = seg_tlp_hdr[110]; // poisoned
        seg_cc_hdr[47] = 1'b0;
        seg_cc_hdr[63:48] = seg_tlp_hdr[63:48]; // requester ID
        seg_cc_hdr[71:64] = seg_tlp_hdr[47:40]; // tag
        seg_cc_hdr[87:72] = seg_tlp_hdr[95:80]; // completer ID
        seg_cc_hdr[88] = 1'b0; // completer ID enable
        seg_cc_hdr[91:89] = seg_tlp_hdr[118:116]; // TC
        seg_cc_hdr[94:92] = {seg_tlp_hdr[114], seg_tlp_hdr[109:108]}; // attr
        seg_cc_hdr[95] = 1'b0; // force ECRC

        // mux for output segments
        if (AXIS_PCIE_DATA_WIDTH == 64) begin
            out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = out_shift_tlp_data_next;
            out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = out_shift_tlp_strb_next;
            out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH+32 +: INT_TLP_SEG_DATA_WIDTH-32] = fifo_tlp_data[out_sel_seg[seg]*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH-32];
            if (!out_tlp_split2[seg]) begin
                out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH+1 +: INT_TLP_SEG_STRB_WIDTH-1] = fifo_tlp_strb[out_sel_seg[seg]*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH-1];
            end

            if (out_tlp_hdr1[seg]) begin
                out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = seg_cc_hdr[63:0];
                out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = 2'b11;
            end else if (out_tlp_hdr2[seg]) begin
                out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: 32] = seg_cc_hdr[95:64];
                out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: 1] = 1'b1;
            end

            out_tlp_valid[seg] = out_sel[seg];
            out_tlp_sop[seg] = out_sop[seg];
            out_tlp_eop[seg] = out_eop[seg];

            if (out_sel[seg]) begin
                out_shift_tlp_data_next = fifo_tlp_data[(out_sel_seg[seg]+1)*INT_TLP_SEG_DATA_WIDTH-32 +: 32];
                out_shift_tlp_strb_next = fifo_tlp_strb[(out_sel_seg[seg]+1)*INT_TLP_SEG_STRB_WIDTH-1 +: 1];
            end
        end else begin
            out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH] = out_shift_tlp_data_next;
            out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = out_shift_tlp_strb_next;
            out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH+96 +: INT_TLP_SEG_DATA_WIDTH-96] = fifo_tlp_data[out_sel_seg[seg]*INT_TLP_SEG_DATA_WIDTH +: INT_TLP_SEG_DATA_WIDTH-96];
            if (!out_tlp_split2[seg]) begin
                out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH+3 +: INT_TLP_SEG_STRB_WIDTH-3] = fifo_tlp_strb[out_sel_seg[seg]*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH-3];
            end

            if (out_tlp_hdr1[seg]) begin
                out_tlp_data[seg*INT_TLP_SEG_DATA_WIDTH +: 96] = seg_cc_hdr;
                out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: 3] = 3'b111;
            end

            out_tlp_valid[seg] = out_sel[seg];
            out_tlp_sop[seg] = out_sop[seg];
            out_tlp_eop[seg] = out_eop[seg];

            if (out_sel[seg]) begin
                out_shift_tlp_data_next = fifo_tlp_data[(out_sel_seg[seg]+1)*INT_TLP_SEG_DATA_WIDTH-96 +: 96];
                out_shift_tlp_strb_next = fifo_tlp_strb[(out_sel_seg[seg]+1)*INT_TLP_SEG_STRB_WIDTH-3 +: 3];
            end
        end
    end

    eop_index = 0;
    for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
        for (lane = 0; lane < INT_TLP_SEG_STRB_WIDTH; lane = lane + 1) begin
            if (out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH+lane]) begin
                eop_index[seg*3 +: 3] = lane;
            end
        end
    end

    if (!m_axis_cc_tvalid || m_axis_cc_tready) begin
        // remap header and sideband
        m_axis_cc_tdata_next = out_tlp_data;
        m_axis_cc_tkeep_next = 0;
        m_axis_cc_tvalid_next = out_tlp_valid != 0;
        m_axis_cc_tlast_next = !(CC_STRADDLE && AXIS_PCIE_DATA_WIDTH == 512) && (out_tlp_valid & out_tlp_eop);
        m_axis_cc_tuser_next = 0;

        for (seg = 0; seg < INT_TLP_SEG_COUNT; seg = seg + 1) begin
            if (out_tlp_valid[seg]) begin
                m_axis_cc_tkeep_next[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH] = out_tlp_strb[seg*INT_TLP_SEG_STRB_WIDTH +: INT_TLP_SEG_STRB_WIDTH];
            end
        end

        if (AXIS_PCIE_DATA_WIDTH == 512) begin
            case (out_tlp_valid & out_tlp_sop)
                2'b00: begin
                    m_axis_cc_tuser_next[1:0] = 2'b00; // is_sop
                    m_axis_cc_tuser_next[3:2] = 2'd0; // is_sop0_ptr
                    m_axis_cc_tuser_next[5:4] = 2'd0; // is_sop1_ptr
                end
                2'b01: begin
                    m_axis_cc_tuser_next[1:0] = 2'b01; // is_sop
                    m_axis_cc_tuser_next[3:2] = 2'd0; // is_sop0_ptr
                    m_axis_cc_tuser_next[5:4] = 2'd0; // is_sop1_ptr
                end
                2'b10: begin
                    m_axis_cc_tuser_next[1:0] = 2'b01; // is_sop
                    m_axis_cc_tuser_next[3:2] = 2'd2; // is_sop0_ptr
                    m_axis_cc_tuser_next[5:4] = 2'd0; // is_sop1_ptr
                end
                2'b11: begin
                    m_axis_cc_tuser_next[1:0] = 2'b11; // is_sop
                    m_axis_cc_tuser_next[3:2] = 2'd0; // is_sop0_ptr
                    m_axis_cc_tuser_next[5:4] = 2'd2; // is_sop1_ptr
                end
            endcase
            case (out_tlp_valid & out_tlp_eop)
                2'b00: begin
                    m_axis_cc_tuser_next[7:6] = 2'b00; // is_eop
                    m_axis_cc_tuser_next[11:8]  = 4'd0; // is_eop0_ptr
                    m_axis_cc_tuser_next[15:12] = 4'd0; // is_eop1_ptr
                end
                2'b01: begin
                    m_axis_cc_tuser_next[7:6] = 2'b01; // is_eop
                    m_axis_cc_tuser_next[11:8]  = eop_index[0*3 +: 3]; // is_eop0_ptr
                    m_axis_cc_tuser_next[15:12] = 4'd0; // is_eop1_ptr
                end
                2'b10: begin
                    m_axis_cc_tuser_next[7:6] = 2'b01; // is_eop
                    m_axis_cc_tuser_next[11:8]  = 4'd8+eop_index[1*3 +: 3]; // is_eop0_ptr
                    m_axis_cc_tuser_next[15:12] = 4'd0; // is_eop1_ptr
                end
                2'b11: begin
                    m_axis_cc_tuser_next[7:6] = 2'b11; // is_eop
                    m_axis_cc_tuser_next[11:8]  = eop_index[0*3 +: 3]; // is_eop0_ptr
                    m_axis_cc_tuser_next[15:12] = 4'd8+eop_index[1*3 +: 3]; // is_eop1_ptr
                end
            endcase
            m_axis_cc_tuser_next[16] = 1'b0; // discontinue
            m_axis_cc_tuser_next[80:17] = 64'd0; // parity
        end else begin
            m_axis_cc_tuser_next[1] = 1'b0; // discontinue
            m_axis_cc_tuser_next[32:1] = 32'd0; // parity
        end
    end
end

integer i;

always @(posedge clk) begin
    frame_reg <= frame_next;
    tlp_hdr1_reg <= tlp_hdr1_next;
    tlp_hdr2_reg <= tlp_hdr2_next;
    tlp_split1_reg <= tlp_split1_next;
    tlp_split2_reg <= tlp_split2_next;

    out_shift_tlp_data_reg <= out_shift_tlp_data_next;
    out_shift_tlp_strb_reg <= out_shift_tlp_strb_next;

    m_axis_cc_tdata_reg <= m_axis_cc_tdata_next;
    m_axis_cc_tkeep_reg <= m_axis_cc_tkeep_next;
    m_axis_cc_tvalid_reg <= m_axis_cc_tvalid_next;
    m_axis_cc_tlast_reg <= m_axis_cc_tlast_next;
    m_axis_cc_tuser_reg <= m_axis_cc_tuser_next;

    if (rst) begin
        frame_reg <= 1'b0;

        m_axis_cc_tvalid_reg <= 0;
    end
end

endmodule

`resetall
