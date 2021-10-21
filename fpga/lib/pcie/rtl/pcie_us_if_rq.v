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
    // RQ sequence number width
    parameter RQ_SEQ_NUM_WIDTH = AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH/TLP_SEG_COUNT,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
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
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    tx_rd_req_tlp_hdr,
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
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   tx_wr_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   tx_wr_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    tx_wr_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_wr_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_eop,
    output wire                                          tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA write request)
     */
    output wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  m_axis_wr_req_tx_seq_num,
    output wire [TX_SEQ_NUM_COUNT-1:0]                   m_axis_wr_req_tx_seq_num_valid
);

parameter TLP_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH;
parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter SEQ_NUM_MASK = {RQ_SEQ_NUM_WIDTH-1{1'b1}};
parameter SEQ_NUM_FLAG = {1'b1, {RQ_SEQ_NUM_WIDTH-1{1'b0}}};

parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

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

    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_SEG_HDR_WIDTH != 128) begin
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

reg tx_rd_req_tlp_ready_cmb;

wire [TLP_SEG_COUNT*RQ_SEQ_NUM_WIDTH-1:0] tx_rd_req_tlp_seq_int = {1'b1, tx_rd_req_tlp_seq};

reg tx_wr_req_tlp_ready_cmb;

wire [TLP_SEG_COUNT*RQ_SEQ_NUM_WIDTH-1:0] tx_wr_req_tlp_seq_int = {1'b0, tx_wr_req_tlp_seq};

assign tx_rd_req_tlp_ready = tx_rd_req_tlp_ready_cmb;

assign tx_wr_req_tlp_ready = tx_wr_req_tlp_ready_cmb;

generate

assign m_axis_rd_req_tx_seq_num[TX_SEQ_NUM_WIDTH*0 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_0;
assign m_axis_rd_req_tx_seq_num_valid[0] = s_axis_rq_seq_num_valid_0 && ((s_axis_rq_seq_num_0 & SEQ_NUM_FLAG) != 0);

if (TX_SEQ_NUM_COUNT > 1) begin
    assign m_axis_rd_req_tx_seq_num[TX_SEQ_NUM_WIDTH*1 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_1;
    assign m_axis_rd_req_tx_seq_num_valid[1] = s_axis_rq_seq_num_valid_1 && ((s_axis_rq_seq_num_1 & SEQ_NUM_FLAG) != 0);
end

assign m_axis_wr_req_tx_seq_num[TX_SEQ_NUM_WIDTH*0 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_0;
assign m_axis_wr_req_tx_seq_num_valid[0] = s_axis_rq_seq_num_valid_0 && ((s_axis_rq_seq_num_0 & SEQ_NUM_FLAG) == 0);

if (TX_SEQ_NUM_COUNT > 1) begin
    assign m_axis_wr_req_tx_seq_num[TX_SEQ_NUM_WIDTH*1 +: TX_SEQ_NUM_WIDTH] = s_axis_rq_seq_num_1;
    assign m_axis_wr_req_tx_seq_num_valid[1] = s_axis_rq_seq_num_valid_1 && ((s_axis_rq_seq_num_1 & SEQ_NUM_FLAG) == 0);
end

endgenerate

localparam [1:0]
    TLP_OUTPUT_STATE_IDLE = 2'd0,
    TLP_OUTPUT_STATE_RD_HEADER = 2'd1,
    TLP_OUTPUT_STATE_WR_HEADER = 2'd2,
    TLP_OUTPUT_STATE_WR_PAYLOAD = 2'd3;

reg [1:0] tlp_output_state_reg = TLP_OUTPUT_STATE_IDLE, tlp_output_state_next;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0] out_tlp_data_reg = 0, out_tlp_data_next;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0] out_tlp_strb_reg = 0, out_tlp_strb_next;
reg [TLP_SEG_COUNT-1:0] out_tlp_eop_reg = 0, out_tlp_eop_next;

reg [127:0] tlp_header_data_rd;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] tlp_tuser_rd;
reg [127:0] tlp_header_data_wr;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] tlp_tuser_wr;

reg  [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata_int = 0;
reg  [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep_int = 0;
reg                                m_axis_rq_tvalid_int = 0;
wire                               m_axis_rq_tready_int;
reg                                m_axis_rq_tlast_int = 0;
reg  [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser_int = 0;

always @* begin
    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;

    out_tlp_data_next = out_tlp_data_reg;
    out_tlp_strb_next = out_tlp_strb_reg;
    out_tlp_eop_next = out_tlp_eop_reg;

    tx_rd_req_tlp_ready_cmb = 1'b0;
    tx_wr_req_tlp_ready_cmb = 1'b0;

    // TLP header and sideband data
    tlp_header_data_rd[1:0] = tx_rd_req_tlp_hdr[107:106]; // address type
    tlp_header_data_rd[63:2] = tx_rd_req_tlp_hdr[63:2]; // address
    tlp_header_data_rd[74:64] = (tx_rd_req_tlp_hdr[105:96] != 0) ? tx_rd_req_tlp_hdr[105:96] : 11'd1024; // DWORD count
    if (tx_rd_req_tlp_hdr[124:120] == 5'h02) begin
        tlp_header_data_rd[78:75] = REQ_IO_READ; // request type - IO read
    end else begin
        tlp_header_data_rd[78:75] = REQ_MEM_READ; // request type - memory read
    end
    tlp_header_data_rd[79] = tx_rd_req_tlp_hdr[110]; // poisoned request
    tlp_header_data_rd[95:80] = tx_rd_req_tlp_hdr[95:80]; // requester ID
    tlp_header_data_rd[103:96] = tx_rd_req_tlp_hdr[79:72]; // tag
    tlp_header_data_rd[119:104] = 16'd0; // completer ID
    tlp_header_data_rd[120] = 1'b0; // requester ID enable
    tlp_header_data_rd[123:121] = tx_rd_req_tlp_hdr[118:116]; // traffic class
    tlp_header_data_rd[126:124] = {tx_rd_req_tlp_hdr[114], tx_rd_req_tlp_hdr[109:108]}; // attr
    tlp_header_data_rd[127] = 1'b0; // force ECRC

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        tlp_tuser_rd[3:0] = tx_rd_req_tlp_hdr[67:64]; // first BE 0
        tlp_tuser_rd[7:4] = 4'd0; // first BE 1
        tlp_tuser_rd[11:8] = tx_rd_req_tlp_hdr[71:68]; // last BE 0
        tlp_tuser_rd[15:12] = 4'd0; // last BE 1
        tlp_tuser_rd[19:16] = 3'd0; // addr_offset
        tlp_tuser_rd[21:20] = 2'b01; // is_sop
        tlp_tuser_rd[23:22] = 2'd0; // is_sop0_ptr
        tlp_tuser_rd[25:24] = 2'd0; // is_sop1_ptr
        tlp_tuser_rd[27:26] = 2'b01; // is_eop
        tlp_tuser_rd[31:28]  = 4'd3; // is_eop0_ptr
        tlp_tuser_rd[35:32] = 4'd0; // is_eop1_ptr
        tlp_tuser_rd[36] = 1'b0; // discontinue
        tlp_tuser_rd[38:37] = 2'b00; // tph_present
        tlp_tuser_rd[42:39] = 4'b0000; // tph_type
        tlp_tuser_rd[44:43] = 2'b00; // tph_indirect_tag_en
        tlp_tuser_rd[60:45] = 16'd0; // tph_st_tag
        tlp_tuser_rd[66:61] = tx_rd_req_tlp_seq_int; // seq_num0
        tlp_tuser_rd[72:67] = 6'd0; // seq_num1
        tlp_tuser_rd[136:73] = 64'd0; // parity
    end else begin
        tlp_tuser_rd[3:0] = tx_rd_req_tlp_hdr[67:64]; // first BE
        tlp_tuser_rd[7:4] = tx_rd_req_tlp_hdr[71:68]; // last BE
        tlp_tuser_rd[10:8] = 3'd0; // addr_offset
        tlp_tuser_rd[11] = 1'b0; // discontinue
        tlp_tuser_rd[12] = 1'b0; // tph_present
        tlp_tuser_rd[14:13] = 2'b00; // tph_type
        tlp_tuser_rd[15] = 1'b0; // tph_indirect_tag_en
        tlp_tuser_rd[23:16] = 8'd0; // tph_st_tag
        tlp_tuser_rd[27:24] = tx_rd_req_tlp_seq_int; // seq_num
        tlp_tuser_rd[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_WIDTH == 62) begin
            tlp_tuser_rd[61:60] = tx_rd_req_tlp_seq_int >> 4; // seq_num
        end
    end

    tlp_header_data_wr[1:0] = tx_wr_req_tlp_hdr[107:106]; // address type
    tlp_header_data_wr[63:2] = tx_wr_req_tlp_hdr[63:2]; // address
    tlp_header_data_wr[74:64] = (tx_wr_req_tlp_hdr[105:96] != 0) ? tx_wr_req_tlp_hdr[105:96] : 11'd1024; // DWORD count
    if (tx_wr_req_tlp_hdr[124:120] == 5'h02) begin
        tlp_header_data_wr[78:75] = REQ_IO_WRITE; // request type - IO write
    end else begin
        tlp_header_data_wr[78:75] = REQ_MEM_WRITE; // request type - memory write
    end
    tlp_header_data_wr[79] = tx_wr_req_tlp_hdr[110]; // poisoned request
    tlp_header_data_wr[95:80] = tx_wr_req_tlp_hdr[95:80]; // requester ID
    tlp_header_data_wr[103:96] = tx_wr_req_tlp_hdr[79:72]; // tag
    tlp_header_data_wr[119:104] = 16'd0; // completer ID
    tlp_header_data_wr[120] = 1'b0; // requester ID enable
    tlp_header_data_wr[123:121] = tx_wr_req_tlp_hdr[118:116]; // traffic class
    tlp_header_data_wr[126:124] = {tx_wr_req_tlp_hdr[114], tx_wr_req_tlp_hdr[109:108]}; // attr
    tlp_header_data_wr[127] = 1'b0; // force ECRC

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        tlp_tuser_wr[3:0] = tx_wr_req_tlp_hdr[67:64]; // first BE 0
        tlp_tuser_wr[7:4] = 4'd0; // first BE 1
        tlp_tuser_wr[11:8] = tx_wr_req_tlp_hdr[71:68]; // last BE 0
        tlp_tuser_wr[15:12] = 4'd0; // last BE 1
        tlp_tuser_wr[19:16] = 3'd0; // addr_offset
        tlp_tuser_wr[21:20] = 2'b01; // is_sop
        tlp_tuser_wr[23:22] = 2'd0; // is_sop0_ptr
        tlp_tuser_wr[25:24] = 2'd0; // is_sop1_ptr
        tlp_tuser_wr[27:26] = 2'b01; // is_eop
        tlp_tuser_wr[31:28]  = 4'd3; // is_eop0_ptr
        tlp_tuser_wr[35:32] = 4'd0; // is_eop1_ptr
        tlp_tuser_wr[36] = 1'b0; // discontinue
        tlp_tuser_wr[38:37] = 2'b00; // tph_present
        tlp_tuser_wr[42:39] = 4'b0000; // tph_type
        tlp_tuser_wr[44:43] = 2'b00; // tph_indirect_tag_en
        tlp_tuser_wr[60:45] = 16'd0; // tph_st_tag
        tlp_tuser_wr[66:61] = tx_wr_req_tlp_seq_int; // seq_num0
        tlp_tuser_wr[72:67] = 6'd0; // seq_num1
        tlp_tuser_wr[136:73] = 64'd0; // parity
    end else begin
        tlp_tuser_wr[3:0] = tx_wr_req_tlp_hdr[67:64]; // first BE
        tlp_tuser_wr[7:4] = tx_wr_req_tlp_hdr[71:68]; // last BE
        tlp_tuser_wr[10:8] = 3'd0; // addr_offset
        tlp_tuser_wr[11] = 1'b0; // discontinue
        tlp_tuser_wr[12] = 1'b0; // tph_present
        tlp_tuser_wr[14:13] = 2'b00; // tph_type
        tlp_tuser_wr[15] = 1'b0; // tph_indirect_tag_en
        tlp_tuser_wr[23:16] = 8'd0; // tph_st_tag
        tlp_tuser_wr[27:24] = tx_wr_req_tlp_seq_int; // seq_num
        tlp_tuser_wr[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_WIDTH == 62) begin
            tlp_tuser_wr[61:60] = tx_wr_req_tlp_seq_int >> 4; // seq_num
        end
    end

    // TLP output
    m_axis_rq_tdata_int = 0;
    m_axis_rq_tkeep_int = 0;
    m_axis_rq_tvalid_int = 1'b0;
    m_axis_rq_tlast_int = 1'b0;
    m_axis_rq_tuser_int = 0;

    // combine header and payload, merge in read request TLPs
    case (tlp_output_state_reg)
        TLP_OUTPUT_STATE_IDLE: begin
            // idle state

            if (tx_rd_req_tlp_valid && m_axis_rq_tready_int) begin
                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    // 64 bit interface, send first half of header (read request)
                    m_axis_rq_tdata_int = tlp_header_data_rd[63:0];
                    m_axis_rq_tkeep_int = 2'b11;
                    m_axis_rq_tvalid_int = 1'b1;
                    m_axis_rq_tlast_int = 1'b0;
                    m_axis_rq_tuser_int = tlp_tuser_rd;

                    tlp_output_state_next = TLP_OUTPUT_STATE_RD_HEADER;
                end else begin
                    // wider interface, send complete header (read request)
                    m_axis_rq_tdata_int = tlp_header_data_rd;
                    m_axis_rq_tkeep_int = 4'b1111;
                    m_axis_rq_tvalid_int = 1'b1;
                    m_axis_rq_tlast_int = 1'b1;
                    m_axis_rq_tuser_int = tlp_tuser_rd;

                    tx_rd_req_tlp_ready_cmb = 1'b1;
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end
            end else if (tx_wr_req_tlp_valid && m_axis_rq_tready_int) begin
                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    // 64 bit interface, send first half of header (write request)
                    m_axis_rq_tdata_int = tlp_header_data_wr[63:0];
                    m_axis_rq_tkeep_int = 2'b11;
                    m_axis_rq_tvalid_int = 1'b1;
                    m_axis_rq_tlast_int = 1'b0;
                    m_axis_rq_tuser_int = tlp_tuser_wr;

                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_HEADER;
                end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
                    // 128 bit interface, send complete header (write request)
                    m_axis_rq_tdata_int = tlp_header_data_wr;
                    m_axis_rq_tkeep_int = 4'b1111;
                    m_axis_rq_tvalid_int = 1'b1;
                    m_axis_rq_tlast_int = 1'b0;
                    m_axis_rq_tuser_int = tlp_tuser_wr;

                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                end else begin
                    // wider interface, send header and start of payload (write request)
                    m_axis_rq_tdata_int = {tx_wr_req_tlp_data, tlp_header_data_wr};
                    m_axis_rq_tkeep_int = {tx_wr_req_tlp_strb, 4'b1111};
                    m_axis_rq_tvalid_int = 1'b1;
                    m_axis_rq_tlast_int = 1'b0;
                    m_axis_rq_tuser_int = tlp_tuser_wr;

                    tx_wr_req_tlp_ready_cmb = 1'b1;

                    out_tlp_data_next = tx_wr_req_tlp_data;
                    out_tlp_strb_next = tx_wr_req_tlp_strb;
                    out_tlp_eop_next = tx_wr_req_tlp_eop;

                    if (tx_wr_req_tlp_eop && ((tx_wr_req_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-4)) == 0)) begin
                        m_axis_rq_tlast_int = 1'b1;
                        tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                    end else begin
                        tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                    end
                end
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end
        end
        TLP_OUTPUT_STATE_RD_HEADER: begin
            // second cycle of header (read request) (64 bit interface width only)
            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axis_rq_tdata_int = tlp_header_data_rd[127:64];
                m_axis_rq_tkeep_int = 2'b11;
                m_axis_rq_tlast_int = 1'b1;
                m_axis_rq_tuser_int = tlp_tuser_rd;

                if (tx_rd_req_tlp_valid && m_axis_rq_tready_int) begin
                    m_axis_rq_tvalid_int = 1'b1;

                    tx_rd_req_tlp_ready_cmb = 1'b1;
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_RD_HEADER;
                end
            end
        end
        TLP_OUTPUT_STATE_WR_HEADER: begin
            // second cycle of header (write request) (64 bit interface width only)
            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axis_rq_tdata_int = tlp_header_data_wr[127:64];
                m_axis_rq_tkeep_int = 2'b11;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser_wr;

                if (tx_wr_req_tlp_valid && m_axis_rq_tready_int) begin
                    m_axis_rq_tvalid_int = 1'b1;

                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_HEADER;
                end
            end
        end
        TLP_OUTPUT_STATE_WR_PAYLOAD: begin
            // transfer payload (write request)
            if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                m_axis_rq_tdata_int = {tx_wr_req_tlp_data, out_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-128]};
                if (tx_wr_req_tlp_valid && !out_tlp_eop_reg) begin
                    m_axis_rq_tkeep_int = {tx_wr_req_tlp_strb, out_tlp_strb_reg[TLP_STRB_WIDTH-1:TLP_DATA_WIDTH_DWORDS-4]};
                end else begin
                    m_axis_rq_tkeep_int = out_tlp_strb_reg[TLP_STRB_WIDTH-1:TLP_DATA_WIDTH_DWORDS-4];
                end
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser_wr;

                if ((tx_wr_req_tlp_valid || out_tlp_eop_reg) && m_axis_rq_tready_int) begin
                    m_axis_rq_tvalid_int = 1'b1;
                    tx_wr_req_tlp_ready_cmb = !out_tlp_eop_reg;

                    out_tlp_data_next = tx_wr_req_tlp_data;
                    out_tlp_strb_next = tx_wr_req_tlp_strb;
                    out_tlp_eop_next = tx_wr_req_tlp_eop;

                    if (out_tlp_eop_reg || (tx_wr_req_tlp_eop && ((tx_wr_req_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-4)) == 0))) begin
                        m_axis_rq_tlast_int = 1'b1;
                        tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                    end else begin
                        tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                    end
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                end
            end else begin
                m_axis_rq_tdata_int = tx_wr_req_tlp_data;
                m_axis_rq_tkeep_int = tx_wr_req_tlp_strb;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser_wr;

                if (tx_wr_req_tlp_valid && m_axis_rq_tready_int) begin
                    m_axis_rq_tvalid_int = 1'b1;
                    tx_wr_req_tlp_ready_cmb = 1'b1;
                        
                    if (tx_wr_req_tlp_eop) begin
                        m_axis_rq_tlast_int = 1'b1;
                        tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                    end else begin
                        tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                    end
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                end
            end
        end
    endcase
end

always @(posedge clk) begin
    tlp_output_state_reg <= tlp_output_state_next;

    out_tlp_data_reg <= out_tlp_data_next;
    out_tlp_strb_reg <= out_tlp_strb_next;
    out_tlp_eop_reg <= out_tlp_eop_next;

    if (rst) begin
        tlp_output_state_reg <= TLP_OUTPUT_STATE_IDLE;
    end
end

// output datapath logic (PCIe TLP)
reg [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_rq_tdata_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_rq_tkeep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg                               m_axis_rq_tvalid_reg = 1'b0, m_axis_rq_tvalid_next;
reg                               m_axis_rq_tlast_reg = 1'b0;
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] m_axis_rq_tuser_reg = {AXIS_PCIE_RQ_USER_WIDTH{1'b0}};

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed" *)
reg [AXIS_PCIE_DATA_WIDTH-1:0]    out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
reg                               out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
reg [AXIS_PCIE_RQ_USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axis_rq_tready_int = !out_fifo_half_full_reg;

assign m_axis_rq_tdata = m_axis_rq_tdata_reg;
assign m_axis_rq_tkeep = m_axis_rq_tkeep_reg;
assign m_axis_rq_tvalid = m_axis_rq_tvalid_reg;
assign m_axis_rq_tlast = m_axis_rq_tlast_reg;
assign m_axis_rq_tuser = m_axis_rq_tuser_reg;

always @(posedge clk) begin
    m_axis_rq_tvalid_reg <= m_axis_rq_tvalid_reg && !m_axis_rq_tready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axis_rq_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tdata_int;
        out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tkeep_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tlast_int;
        out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_rq_tuser_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axis_rq_tvalid_reg || m_axis_rq_tready)) begin
        m_axis_rq_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_rq_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_rq_tvalid_reg <= 1'b1;
        m_axis_rq_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_rq_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axis_rq_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
