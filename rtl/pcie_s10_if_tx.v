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
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = (SEG_COUNT*SEG_DATA_WIDTH)/TLP_SEG_COUNT,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 6
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    // H-Tile/L-Tile TX AVST interface
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]          tx_st_data,
    output wire [SEG_COUNT-1:0]                         tx_st_sop,
    output wire [SEG_COUNT-1:0]                         tx_st_eop,
    output wire [SEG_COUNT-1:0]                         tx_st_valid,
    input  wire                                         tx_st_ready,
    output wire [SEG_COUNT-1:0]                         tx_st_err,

    /*
     * TLP input (read request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_rd_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]    tx_rd_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_rd_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_rd_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_rd_req_tlp_eop,
    output wire                                         tx_rd_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA read request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]        m_axis_rd_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                         m_axis_rd_req_tx_seq_num_valid,

    /*
     * TLP input (write request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  tx_wr_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  tx_wr_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_wr_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]    tx_wr_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_wr_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_wr_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_wr_req_tlp_eop,
    output wire                                         tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA write request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]        m_axis_wr_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                         m_axis_wr_req_tx_seq_num_valid,

    /*
     * TLP input (completion from BAR)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  tx_cpl_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  tx_cpl_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_eop,
    output wire                                         tx_cpl_tlp_ready
);

parameter TLP_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH;
parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter FIFO_ADDR_WIDTH = 5;

// bus width assertions
initial begin
    if (SEG_COUNT != 1) begin
        $error("Error: segment count must be 1 (instance %m)");
        $finish;        
    end

    if (SEG_DATA_WIDTH != 256) begin
        $error("Error: segment data width must be 256 (instance %m)");
        $finish;        
    end

    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH != SEG_COUNT*SEG_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_SEG_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end
end

localparam [0:0]
    WR_REQ_STATE_IDLE = 1'd0,
    WR_REQ_STATE_PAYLOAD = 1'd1;

reg [0:0] wr_req_state_reg = WR_REQ_STATE_IDLE, wr_req_state_next;

localparam [0:0]
    CPL_STATE_IDLE = 1'd0,
    CPL_STATE_PAYLOAD = 1'd1;

reg [0:0] cpl_state_reg = CPL_STATE_IDLE, cpl_state_next;

localparam [1:0]
    TLP_OUTPUT_STATE_IDLE = 2'd0,
    TLP_OUTPUT_STATE_WR_PAYLOAD = 2'd1,
    TLP_OUTPUT_STATE_CPL_PAYLOAD = 2'd2;

reg [1:0] tlp_output_state_reg = TLP_OUTPUT_STATE_IDLE, tlp_output_state_next;

reg wr_req_payload_offset_reg = 1'b0, wr_req_payload_offset_next;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0] wr_req_tlp_data_reg = 0, wr_req_tlp_data_next;
reg [TLP_SEG_COUNT-1:0] wr_req_tlp_eop_reg = 0, wr_req_tlp_eop_next;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0] cpl_tlp_data_reg = 0, cpl_tlp_data_next;
reg [TLP_SEG_COUNT-1:0] cpl_tlp_eop_reg = 0, cpl_tlp_eop_next;

reg tx_rd_req_tlp_ready_reg = 1'b0, tx_rd_req_tlp_ready_next;
reg tx_wr_req_tlp_ready_reg = 1'b0, tx_wr_req_tlp_ready_next;
reg tx_cpl_tlp_ready_reg = 1'b0, tx_cpl_tlp_ready_next;

reg [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]  m_axis_rd_req_tx_seq_num_reg = 0, m_axis_rd_req_tx_seq_num_next;
reg [SEG_COUNT-1:0]                   m_axis_rd_req_tx_seq_num_valid_reg = 0, m_axis_rd_req_tx_seq_num_valid_next;
reg [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]  m_axis_wr_req_tx_seq_num_reg = 0, m_axis_wr_req_tx_seq_num_next;
reg [SEG_COUNT-1:0]                   m_axis_wr_req_tx_seq_num_valid_reg = 0, m_axis_wr_req_tx_seq_num_valid_next;

reg [SEG_COUNT*SEG_DATA_WIDTH-1:0]  tx_st_data_reg = 0, tx_st_data_next;
reg [SEG_COUNT-1:0]                 tx_st_sop_reg = 0, tx_st_sop_next;
reg [SEG_COUNT-1:0]                 tx_st_eop_reg = 0, tx_st_eop_next;
reg [SEG_COUNT-1:0]                 tx_st_valid_reg = 0, tx_st_valid_next;

reg [1:0] tx_st_ready_delay_reg = 0;

assign tx_rd_req_tlp_ready = tx_rd_req_tlp_ready_reg;
assign tx_wr_req_tlp_ready = tx_wr_req_tlp_ready_reg;
assign tx_cpl_tlp_ready = tx_cpl_tlp_ready_reg;

assign m_axis_rd_req_tx_seq_num = m_axis_rd_req_tx_seq_num_reg;
assign m_axis_rd_req_tx_seq_num_valid = m_axis_rd_req_tx_seq_num_valid_reg;
assign m_axis_wr_req_tx_seq_num = m_axis_wr_req_tx_seq_num_reg;
assign m_axis_wr_req_tx_seq_num_valid = m_axis_wr_req_tx_seq_num_valid_reg;

assign tx_st_data = tx_st_data_reg;
assign tx_st_sop = tx_st_sop_reg;
assign tx_st_eop = tx_st_eop_reg;
assign tx_st_valid = tx_st_valid_reg;
assign tx_st_err = 0;

// read request FIFO
reg [FIFO_ADDR_WIDTH+1-1:0] rd_req_fifo_wr_ptr_reg = 0;
reg [FIFO_ADDR_WIDTH+1-1:0] rd_req_fifo_rd_ptr_reg = 0, rd_req_fifo_rd_ptr_next;

(* ramstyle = "no_rw_check, mlab" *)
reg [SEG_DATA_WIDTH-1:0] rd_req_fifo_data[(2**FIFO_ADDR_WIDTH)-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg [TX_SEQ_NUM_WIDTH-1:0] rd_req_fifo_seq[(2**FIFO_ADDR_WIDTH)-1:0];

reg [SEG_DATA_WIDTH-1:0] rd_req_fifo_wr_data;
reg [TX_SEQ_NUM_WIDTH-1:0] rd_req_fifo_wr_seq;
reg rd_req_fifo_we;

reg rd_req_fifo_watermark_reg = 1'b0;
reg [SEG_DATA_WIDTH-1:0] rd_req_fifo_rd_data_reg = 0, rd_req_fifo_rd_data_next;
reg rd_req_fifo_rd_valid_reg = 0, rd_req_fifo_rd_valid_next;
reg [TX_SEQ_NUM_WIDTH-1:0] rd_req_fifo_rd_seq_reg = 0, rd_req_fifo_rd_seq_next;

// write request FIFO
reg [FIFO_ADDR_WIDTH+1-1:0] wr_req_fifo_wr_ptr_reg = 0;
reg [FIFO_ADDR_WIDTH+1-1:0] wr_req_fifo_wr_ptr_cur_reg = 0;
reg [FIFO_ADDR_WIDTH+1-1:0] wr_req_fifo_rd_ptr_reg = 0, wr_req_fifo_rd_ptr_next;

(* ramstyle = "no_rw_check, mlab" *)
reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] wr_req_fifo_data[(2**FIFO_ADDR_WIDTH)-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg [SEG_COUNT-1:0] wr_req_fifo_eop[(2**FIFO_ADDR_WIDTH)-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg [SEG_COUNT-1:0] wr_req_fifo_valid[(2**FIFO_ADDR_WIDTH)-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg [TX_SEQ_NUM_WIDTH-1:0] wr_req_fifo_seq[(2**FIFO_ADDR_WIDTH)-1:0];

reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] wr_req_fifo_wr_data;
reg [SEG_COUNT-1:0] wr_req_fifo_wr_eop;
reg [SEG_COUNT-1:0] wr_req_fifo_wr_valid;
reg [TX_SEQ_NUM_WIDTH-1:0] wr_req_fifo_wr_seq;
reg wr_req_fifo_we;

reg wr_req_fifo_watermark_reg = 1'b0;
reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] wr_req_fifo_rd_data_reg = 0, wr_req_fifo_rd_data_next;
reg [SEG_COUNT-1:0] wr_req_fifo_rd_eop_reg = 0, wr_req_fifo_rd_eop_next;
reg [SEG_COUNT-1:0] wr_req_fifo_rd_valid_reg = 0, wr_req_fifo_rd_valid_next;
reg [TX_SEQ_NUM_WIDTH-1:0] wr_req_fifo_rd_seq_reg = 0, wr_req_fifo_rd_seq_next;

// completion FIFO
reg [FIFO_ADDR_WIDTH+1-1:0] cpl_fifo_wr_ptr_reg = 0;
reg [FIFO_ADDR_WIDTH+1-1:0] cpl_fifo_wr_ptr_cur_reg = 0;
reg [FIFO_ADDR_WIDTH+1-1:0] cpl_fifo_rd_ptr_reg = 0, cpl_fifo_rd_ptr_next;

(* ramstyle = "no_rw_check, mlab" *)
reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] cpl_fifo_data[(2**FIFO_ADDR_WIDTH)-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg [SEG_COUNT-1:0] cpl_fifo_eop[(2**FIFO_ADDR_WIDTH)-1:0];
(* ramstyle = "no_rw_check, mlab" *)
reg [SEG_COUNT-1:0] cpl_fifo_valid[(2**FIFO_ADDR_WIDTH)-1:0];

reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] cpl_fifo_wr_data;
reg [SEG_COUNT-1:0] cpl_fifo_wr_eop;
reg [SEG_COUNT-1:0] cpl_fifo_wr_valid;
reg cpl_fifo_we;

reg cpl_fifo_watermark_reg = 1'b0;
reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] cpl_fifo_rd_data_reg = 0, cpl_fifo_rd_data_next;
reg [SEG_COUNT-1:0] cpl_fifo_rd_eop_reg = 0, cpl_fifo_rd_eop_next;
reg [SEG_COUNT-1:0] cpl_fifo_rd_valid_reg = 0, cpl_fifo_rd_valid_next;

// Read request processing
always @* begin
    tx_rd_req_tlp_ready_next = 1'b0;

    rd_req_fifo_wr_data[31:0] = tx_rd_req_tlp_hdr[127:96];
    rd_req_fifo_wr_data[63:32] = tx_rd_req_tlp_hdr[95:64];
    rd_req_fifo_wr_data[95:64] = tx_rd_req_tlp_hdr[63:32];
    rd_req_fifo_wr_data[127:96] = tx_rd_req_tlp_hdr[31:0];
    rd_req_fifo_wr_data[SEG_COUNT*SEG_DATA_WIDTH-1:128] = 0;
    rd_req_fifo_wr_seq = tx_rd_req_tlp_seq;
    rd_req_fifo_we = 0;

    tx_rd_req_tlp_ready_next = !cpl_fifo_watermark_reg;

    if (tx_rd_req_tlp_valid && tx_rd_req_tlp_ready) begin
        // send complete header (read request)
        rd_req_fifo_we = 1;
    end
end

// Write request processing
always @* begin
    wr_req_state_next = WR_REQ_STATE_IDLE;

    wr_req_payload_offset_next = wr_req_payload_offset_reg;

    wr_req_tlp_data_next = wr_req_tlp_data_reg;
    wr_req_tlp_eop_next = wr_req_tlp_eop_reg;

    tx_wr_req_tlp_ready_next = 1'b0;

    if (wr_req_payload_offset_reg) begin
        wr_req_fifo_wr_data = {tx_wr_req_tlp_data, wr_req_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-128]};
    end else begin
        wr_req_fifo_wr_data = {tx_wr_req_tlp_data, wr_req_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-96]};
    end
    wr_req_fifo_wr_eop = 0;
    wr_req_fifo_wr_valid = 1;
    wr_req_fifo_wr_seq = tx_wr_req_tlp_seq;
    wr_req_fifo_we = 0;

    // combine header and payload, merge in read request TLPs
    case (wr_req_state_reg)
        WR_REQ_STATE_IDLE: begin
            // idle state
            tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg;

            wr_req_payload_offset_next = tx_wr_req_tlp_hdr[125];

            wr_req_fifo_wr_data[31:0] = tx_wr_req_tlp_hdr[127:96];
            wr_req_fifo_wr_data[63:32] = tx_wr_req_tlp_hdr[95:64];
            wr_req_fifo_wr_data[95:64] = tx_wr_req_tlp_hdr[63:32];
            if (wr_req_payload_offset_next) begin
                wr_req_fifo_wr_data[127:96] = tx_rd_req_tlp_hdr[31:0];
                wr_req_fifo_wr_data[SEG_COUNT*SEG_DATA_WIDTH-1:128] = tx_wr_req_tlp_data;
            end else begin
                wr_req_fifo_wr_data[SEG_COUNT*SEG_DATA_WIDTH-1:96] = tx_wr_req_tlp_data;
            end
            wr_req_fifo_wr_eop = 0;
            wr_req_fifo_wr_valid = 1;
            wr_req_fifo_wr_seq = tx_wr_req_tlp_seq;

            if (tx_wr_req_tlp_valid && tx_wr_req_tlp_ready) begin
                // send complete header and start of payload (completion)
                wr_req_fifo_we = 1;

                wr_req_tlp_data_next = tx_wr_req_tlp_data;
                wr_req_tlp_eop_next = tx_wr_req_tlp_eop;

                if (tx_wr_req_tlp_eop && wr_req_payload_offset_next && ((tx_wr_req_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-4)) == 0)) begin
                    wr_req_fifo_wr_eop = 1;
                    tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg;
                    wr_req_state_next = WR_REQ_STATE_IDLE;
                end else if (tx_wr_req_tlp_eop && !wr_req_payload_offset_next && ((tx_wr_req_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-3)) == 0)) begin
                    wr_req_fifo_wr_eop = 1;
                    tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg;
                    wr_req_state_next = WR_REQ_STATE_IDLE;
                end else begin
                    tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg && !wr_req_tlp_eop_next;
                    wr_req_state_next = WR_REQ_STATE_PAYLOAD;
                end
            end else begin
                wr_req_state_next = WR_REQ_STATE_IDLE;
            end
        end
        WR_REQ_STATE_PAYLOAD: begin
            // transfer payload (completion)
            tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg && !wr_req_tlp_eop_reg;

            if (wr_req_payload_offset_reg) begin
                wr_req_fifo_wr_data = {tx_wr_req_tlp_data, wr_req_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-128]};
            end else begin
                wr_req_fifo_wr_data = {tx_wr_req_tlp_data, wr_req_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-96]};
            end
            wr_req_fifo_wr_eop = 0;
            wr_req_fifo_wr_valid = 1;
            wr_req_fifo_wr_seq = tx_wr_req_tlp_seq;

            if ((tx_wr_req_tlp_valid && tx_wr_req_tlp_ready) || (wr_req_tlp_eop_reg && !wr_req_fifo_watermark_reg)) begin
                wr_req_fifo_we = 1;

                wr_req_tlp_data_next = tx_wr_req_tlp_data;
                wr_req_tlp_eop_next = tx_wr_req_tlp_eop;

                if (wr_req_tlp_eop_reg || (tx_wr_req_tlp_eop && wr_req_payload_offset_reg && ((tx_wr_req_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-4)) == 0))) begin
                    wr_req_fifo_wr_eop = 1;
                    tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg;
                    wr_req_state_next = WR_REQ_STATE_IDLE;
                end else if (wr_req_tlp_eop_reg || (tx_wr_req_tlp_eop && !wr_req_payload_offset_reg && ((tx_wr_req_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-3)) == 0))) begin
                    wr_req_fifo_wr_eop = 1;
                    tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg;
                    wr_req_state_next = WR_REQ_STATE_IDLE;
                end else begin
                    tx_wr_req_tlp_ready_next = !wr_req_fifo_watermark_reg && !wr_req_tlp_eop_next;
                    wr_req_state_next = WR_REQ_STATE_PAYLOAD;
                end
            end else begin
                wr_req_state_next = WR_REQ_STATE_PAYLOAD;
            end
        end
    endcase
end

// Completion processing
always @* begin
    cpl_state_next = CPL_STATE_IDLE;

    cpl_tlp_data_next = cpl_tlp_data_reg;
    cpl_tlp_eop_next = cpl_tlp_eop_reg;

    tx_cpl_tlp_ready_next = 1'b0;

    cpl_fifo_wr_data = {tx_cpl_tlp_data, cpl_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-96]};
    cpl_fifo_wr_eop = 0;
    cpl_fifo_wr_valid = 1;
    cpl_fifo_we = 0;

    // combine header and payload, merge in read request TLPs
    case (cpl_state_reg)
        CPL_STATE_IDLE: begin
            // idle state
            tx_cpl_tlp_ready_next = !cpl_fifo_watermark_reg;

            cpl_fifo_wr_data[31:0] = tx_cpl_tlp_hdr[127:96];
            cpl_fifo_wr_data[63:32] = tx_cpl_tlp_hdr[95:64];
            cpl_fifo_wr_data[95:64] = tx_cpl_tlp_hdr[63:32];
            cpl_fifo_wr_data[SEG_COUNT*SEG_DATA_WIDTH-1:96] = tx_cpl_tlp_data;
            cpl_fifo_wr_eop = 0;
            cpl_fifo_wr_valid = 1;

            if (tx_cpl_tlp_valid && tx_cpl_tlp_ready) begin
                // send complete header and start of payload (completion)
                cpl_fifo_we = 1;

                cpl_tlp_data_next = tx_cpl_tlp_data;
                cpl_tlp_eop_next = tx_cpl_tlp_eop;

                if (tx_cpl_tlp_eop && ((tx_cpl_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-3)) == 0)) begin
                    cpl_fifo_wr_eop = 1;
                    tx_cpl_tlp_ready_next = !cpl_fifo_watermark_reg;
                    cpl_state_next = CPL_STATE_IDLE;
                end else begin
                    tx_cpl_tlp_ready_next = !cpl_fifo_watermark_reg && !cpl_tlp_eop_next;
                    cpl_state_next = CPL_STATE_PAYLOAD;
                end
            end else begin
                cpl_state_next = CPL_STATE_IDLE;
            end
        end
        CPL_STATE_PAYLOAD: begin
            // transfer payload (completion)
            tx_cpl_tlp_ready_next = !cpl_fifo_watermark_reg && !cpl_tlp_eop_reg;

            cpl_fifo_wr_data = {tx_cpl_tlp_data, cpl_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-96]};
            cpl_fifo_wr_eop = 0;
            cpl_fifo_wr_valid = 1;

            if ((tx_cpl_tlp_valid && tx_cpl_tlp_ready) || (cpl_tlp_eop_reg && !cpl_fifo_watermark_reg)) begin
                cpl_fifo_we = 1;

                cpl_tlp_data_next = tx_cpl_tlp_data;
                cpl_tlp_eop_next = tx_cpl_tlp_eop;

                if (cpl_tlp_eop_reg || (tx_cpl_tlp_eop && ((tx_cpl_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-3)) == 0))) begin
                    cpl_fifo_wr_eop = 1;
                    tx_cpl_tlp_ready_next = !cpl_fifo_watermark_reg;
                    cpl_state_next = CPL_STATE_IDLE;
                end else begin
                    tx_cpl_tlp_ready_next = !cpl_fifo_watermark_reg && !cpl_tlp_eop_next;
                    cpl_state_next = CPL_STATE_PAYLOAD;
                end
            end else begin
                cpl_state_next = CPL_STATE_PAYLOAD;
            end
        end
    endcase
end

// Output arbitration
always @* begin
    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;

    m_axis_rd_req_tx_seq_num_next = 0;
    m_axis_rd_req_tx_seq_num_valid_next = 0;
    m_axis_wr_req_tx_seq_num_next = 0;
    m_axis_wr_req_tx_seq_num_valid_next = 0;

    tx_st_data_next = 0;
    tx_st_sop_next = 0;
    tx_st_eop_next = 0;
    tx_st_valid_next = 0;

    rd_req_fifo_rd_data_next = rd_req_fifo_rd_data_reg;
    rd_req_fifo_rd_valid_next = rd_req_fifo_rd_valid_reg;
    rd_req_fifo_rd_seq_next = rd_req_fifo_rd_seq_reg;

    wr_req_fifo_rd_data_next = wr_req_fifo_rd_data_reg;
    wr_req_fifo_rd_eop_next = wr_req_fifo_rd_eop_reg;
    wr_req_fifo_rd_valid_next = wr_req_fifo_rd_valid_reg;
    wr_req_fifo_rd_seq_next = wr_req_fifo_rd_seq_reg;

    cpl_fifo_rd_data_next = cpl_fifo_rd_data_reg;
    cpl_fifo_rd_eop_next = cpl_fifo_rd_eop_reg;
    cpl_fifo_rd_valid_next = cpl_fifo_rd_valid_reg;

    // combine header and payload, merge in read request TLPs
    case (tlp_output_state_reg)
        TLP_OUTPUT_STATE_IDLE: begin
            // idle state

            if (cpl_fifo_rd_valid_reg && tx_st_ready_delay_reg[1]) begin
                // transfer completion
                tx_st_data_next = cpl_fifo_rd_data_reg;
                tx_st_sop_next = 1;
                tx_st_eop_next = cpl_fifo_rd_eop_reg;
                tx_st_valid_next = cpl_fifo_rd_valid_reg;

                cpl_fifo_rd_valid_next = 0;

                if (cpl_fifo_rd_eop_reg) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_CPL_PAYLOAD;
                end
            end else if (rd_req_fifo_rd_valid_reg && tx_st_ready_delay_reg[1]) begin
                // transfer read request
                tx_st_data_next = rd_req_fifo_rd_data_reg;
                tx_st_sop_next = 1;
                tx_st_eop_next = 1;
                tx_st_valid_next = 1;

                rd_req_fifo_rd_valid_next = 0;

                // return read request sequence number
                m_axis_rd_req_tx_seq_num_next = rd_req_fifo_rd_seq_reg;
                m_axis_rd_req_tx_seq_num_valid_next = 1'b1;
            end else if (wr_req_fifo_rd_valid_reg && tx_st_ready_delay_reg[1]) begin
                // transfer write request
                tx_st_data_next = wr_req_fifo_rd_data_reg;
                tx_st_sop_next = 1;
                tx_st_eop_next = wr_req_fifo_rd_eop_reg;
                tx_st_valid_next = wr_req_fifo_rd_valid_reg;

                wr_req_fifo_rd_valid_next = 0;

                // return write request sequence number
                m_axis_wr_req_tx_seq_num_next = wr_req_fifo_rd_seq_reg;
                m_axis_wr_req_tx_seq_num_valid_next = 1'b1;

                if (wr_req_fifo_rd_eop_reg) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                end
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end
        end
        TLP_OUTPUT_STATE_WR_PAYLOAD: begin
            // transfer payload (write request)
            tx_st_data_next = wr_req_fifo_rd_data_reg;
            tx_st_sop_next = 0;
            tx_st_eop_next = wr_req_fifo_rd_eop_reg;

            if (wr_req_fifo_rd_valid_reg && tx_st_ready_delay_reg[1]) begin
                tx_st_valid_next = wr_req_fifo_rd_valid_reg;

                wr_req_fifo_rd_valid_next = 0;

                if (wr_req_fifo_rd_eop_reg) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
                end
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_WR_PAYLOAD;
            end
        end
        TLP_OUTPUT_STATE_CPL_PAYLOAD: begin
            // transfer payload (completion)
            tx_st_data_next = cpl_fifo_rd_data_reg;
            tx_st_sop_next = 0;
            tx_st_eop_next = cpl_fifo_rd_eop_reg;

            if (cpl_fifo_rd_valid_reg && tx_st_ready_delay_reg[1]) begin
                tx_st_valid_next = cpl_fifo_rd_valid_reg;

                cpl_fifo_rd_valid_next = 0;

                if (cpl_fifo_rd_eop_reg) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_CPL_PAYLOAD;
                end
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_CPL_PAYLOAD;
            end
        end
    endcase

    rd_req_fifo_rd_ptr_next = rd_req_fifo_rd_ptr_reg;

    if (!rd_req_fifo_rd_valid_next && rd_req_fifo_rd_ptr_reg != rd_req_fifo_wr_ptr_reg) begin
        // read request FIFO not empty
        rd_req_fifo_rd_data_next = rd_req_fifo_data[rd_req_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        rd_req_fifo_rd_valid_next = 1;
        rd_req_fifo_rd_seq_next = rd_req_fifo_seq[rd_req_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        rd_req_fifo_rd_ptr_next = rd_req_fifo_rd_ptr_reg + 1;
    end

    wr_req_fifo_rd_ptr_next = wr_req_fifo_rd_ptr_reg;

    if (!wr_req_fifo_rd_valid_next && wr_req_fifo_rd_ptr_reg != wr_req_fifo_wr_ptr_reg) begin
        // write request FIFO not empty
        wr_req_fifo_rd_data_next = wr_req_fifo_data[wr_req_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        wr_req_fifo_rd_eop_next = wr_req_fifo_eop[wr_req_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        wr_req_fifo_rd_valid_next = wr_req_fifo_valid[wr_req_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        wr_req_fifo_rd_seq_next = wr_req_fifo_seq[wr_req_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        wr_req_fifo_rd_ptr_next = wr_req_fifo_rd_ptr_reg + 1;
    end

    cpl_fifo_rd_ptr_next = cpl_fifo_rd_ptr_reg;

    if (!cpl_fifo_rd_valid_next && cpl_fifo_rd_ptr_reg != cpl_fifo_wr_ptr_reg) begin
        // completion FIFO not empty
        cpl_fifo_rd_data_next = cpl_fifo_data[cpl_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        cpl_fifo_rd_eop_next = cpl_fifo_eop[cpl_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        cpl_fifo_rd_valid_next = cpl_fifo_valid[cpl_fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];
        cpl_fifo_rd_ptr_next = cpl_fifo_rd_ptr_reg + 1;
    end
end

always @(posedge clk) begin
    wr_req_state_reg <= wr_req_state_next;
    cpl_state_reg <= cpl_state_next;
    tlp_output_state_reg <= tlp_output_state_next;

    wr_req_payload_offset_reg <= wr_req_payload_offset_next;

    wr_req_tlp_data_reg <= wr_req_tlp_data_next;
    wr_req_tlp_eop_reg <= wr_req_tlp_eop_next;

    cpl_tlp_data_reg <= cpl_tlp_data_next;
    cpl_tlp_eop_reg <= cpl_tlp_eop_next;

    tx_rd_req_tlp_ready_reg <= tx_rd_req_tlp_ready_next;
    tx_wr_req_tlp_ready_reg <= tx_wr_req_tlp_ready_next;
    tx_cpl_tlp_ready_reg <= tx_cpl_tlp_ready_next;

    m_axis_rd_req_tx_seq_num_reg <= m_axis_rd_req_tx_seq_num_next;
    m_axis_rd_req_tx_seq_num_valid_reg <= m_axis_rd_req_tx_seq_num_valid_next;
    m_axis_wr_req_tx_seq_num_reg <= m_axis_wr_req_tx_seq_num_next;
    m_axis_wr_req_tx_seq_num_valid_reg <= m_axis_wr_req_tx_seq_num_valid_next;

    tx_st_data_reg <= tx_st_data_next;
    tx_st_sop_reg <= tx_st_sop_next;
    tx_st_eop_reg <= tx_st_eop_next;
    tx_st_valid_reg <= tx_st_valid_next;

    tx_st_ready_delay_reg <= {tx_st_ready_delay_reg, tx_st_ready};

    if (rd_req_fifo_we) begin
        rd_req_fifo_data[rd_req_fifo_wr_ptr_reg[FIFO_ADDR_WIDTH-1:0]] <= rd_req_fifo_wr_data;
        rd_req_fifo_seq[rd_req_fifo_wr_ptr_reg[FIFO_ADDR_WIDTH-1:0]] <= rd_req_fifo_wr_seq;
        rd_req_fifo_wr_ptr_reg <= rd_req_fifo_wr_ptr_reg + 1;
    end
    rd_req_fifo_rd_ptr_reg <= rd_req_fifo_rd_ptr_next;

    rd_req_fifo_rd_data_reg <= rd_req_fifo_rd_data_next;
    rd_req_fifo_rd_valid_reg <= rd_req_fifo_rd_valid_next;
    rd_req_fifo_rd_seq_reg <= rd_req_fifo_rd_seq_next;

    rd_req_fifo_watermark_reg <= $unsigned(rd_req_fifo_wr_ptr_reg - rd_req_fifo_rd_ptr_reg) >= 2**FIFO_ADDR_WIDTH-4;

    if (wr_req_fifo_we) begin
        wr_req_fifo_data[wr_req_fifo_wr_ptr_cur_reg[FIFO_ADDR_WIDTH-1:0]] <= wr_req_fifo_wr_data;
        wr_req_fifo_eop[wr_req_fifo_wr_ptr_cur_reg[FIFO_ADDR_WIDTH-1:0]] <= wr_req_fifo_wr_eop;
        wr_req_fifo_valid[wr_req_fifo_wr_ptr_cur_reg[FIFO_ADDR_WIDTH-1:0]] <= wr_req_fifo_wr_valid;
        wr_req_fifo_seq[wr_req_fifo_wr_ptr_cur_reg[FIFO_ADDR_WIDTH-1:0]] <= wr_req_fifo_wr_seq;
        wr_req_fifo_wr_ptr_cur_reg <= wr_req_fifo_wr_ptr_cur_reg + 1;
        if (wr_req_fifo_wr_eop) begin
            // update write pointer at end of frame
            wr_req_fifo_wr_ptr_reg <= wr_req_fifo_wr_ptr_cur_reg + 1;
        end
    end
    wr_req_fifo_rd_ptr_reg <= wr_req_fifo_rd_ptr_next;

    wr_req_fifo_rd_data_reg <= wr_req_fifo_rd_data_next;
    wr_req_fifo_rd_eop_reg <= wr_req_fifo_rd_eop_next;
    wr_req_fifo_rd_valid_reg <= wr_req_fifo_rd_valid_next;
    wr_req_fifo_rd_seq_reg <= wr_req_fifo_rd_seq_next;

    wr_req_fifo_watermark_reg <= $unsigned(wr_req_fifo_wr_ptr_cur_reg - wr_req_fifo_rd_ptr_reg) >= 2**FIFO_ADDR_WIDTH-4;

    if (cpl_fifo_we) begin
        cpl_fifo_data[cpl_fifo_wr_ptr_cur_reg[FIFO_ADDR_WIDTH-1:0]] <= cpl_fifo_wr_data;
        cpl_fifo_eop[cpl_fifo_wr_ptr_cur_reg[FIFO_ADDR_WIDTH-1:0]] <= cpl_fifo_wr_eop;
        cpl_fifo_valid[cpl_fifo_wr_ptr_cur_reg[FIFO_ADDR_WIDTH-1:0]] <= cpl_fifo_wr_valid;
        cpl_fifo_wr_ptr_cur_reg <= cpl_fifo_wr_ptr_cur_reg + 1;
        if (cpl_fifo_wr_eop) begin
            // update write pointer at end of frame
            cpl_fifo_wr_ptr_reg <= cpl_fifo_wr_ptr_cur_reg + 1;
        end
    end
    cpl_fifo_rd_ptr_reg <= cpl_fifo_rd_ptr_next;

    cpl_fifo_rd_data_reg <= cpl_fifo_rd_data_next;
    cpl_fifo_rd_eop_reg <= cpl_fifo_rd_eop_next;
    cpl_fifo_rd_valid_reg <= cpl_fifo_rd_valid_next;

    cpl_fifo_watermark_reg <= $unsigned(cpl_fifo_wr_ptr_cur_reg - cpl_fifo_rd_ptr_reg) >= 2**FIFO_ADDR_WIDTH-4;

    if (rst) begin
        wr_req_state_reg <= WR_REQ_STATE_IDLE;
        cpl_state_reg <= CPL_STATE_IDLE;
        tlp_output_state_reg <= TLP_OUTPUT_STATE_IDLE;

        tx_rd_req_tlp_ready_reg <= 1'b0;
        tx_wr_req_tlp_ready_reg <= 1'b0;
        tx_cpl_tlp_ready_reg <= 1'b0;

        m_axis_rd_req_tx_seq_num_valid_reg <= 0;
        m_axis_wr_req_tx_seq_num_valid_reg <= 0;

        tx_st_valid_reg <= 0;
        tx_st_ready_delay_reg <= 0;

        rd_req_fifo_wr_ptr_reg <= 0;
        rd_req_fifo_rd_ptr_reg <= 0;
        rd_req_fifo_rd_valid_reg <= 1'b0;

        wr_req_fifo_wr_ptr_reg <= 0;
        wr_req_fifo_wr_ptr_cur_reg <= 0;
        wr_req_fifo_rd_ptr_reg <= 0;
        wr_req_fifo_rd_valid_reg <= 0;

        cpl_fifo_wr_ptr_reg <= 0;
        cpl_fifo_wr_ptr_cur_reg <= 0;
        cpl_fifo_rd_ptr_reg <= 0;
        cpl_fifo_rd_valid_reg <= 0;
    end
end

endmodule

`resetall
