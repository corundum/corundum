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
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH/TLP_SEG_COUNT,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI output (CC)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]              m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]              m_axis_cc_tkeep,
    output wire                                         m_axis_cc_tvalid,
    input  wire                                         m_axis_cc_tready,
    output wire                                         m_axis_cc_tlast,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0]           m_axis_cc_tuser,

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

reg tx_cpl_tlp_ready_cmb;

assign tx_cpl_tlp_ready = tx_cpl_tlp_ready_cmb;

// process outgoing TLPs
localparam [1:0]
    TLP_OUTPUT_STATE_IDLE = 2'd0,
    TLP_OUTPUT_STATE_HEADER = 2'd1,
    TLP_OUTPUT_STATE_PAYLOAD = 2'd2;

reg [1:0] tlp_output_state_reg = TLP_OUTPUT_STATE_IDLE, tlp_output_state_next;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0] out_tlp_data_reg = 0, out_tlp_data_next;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0] out_tlp_strb_reg = 0, out_tlp_strb_next;
reg [TLP_SEG_COUNT-1:0] out_tlp_eop_reg = 0, out_tlp_eop_next;

reg [2:0] tx_cpl_tlp_hdr_fmt;
reg [4:0] tx_cpl_tlp_hdr_type;
reg [2:0] tx_cpl_tlp_hdr_tc;
reg tx_cpl_tlp_hdr_ln;
reg tx_cpl_tlp_hdr_th;
reg tx_cpl_tlp_hdr_td;
reg tx_cpl_tlp_hdr_ep;
reg [2:0] tx_cpl_tlp_hdr_attr;
reg [1:0] tx_cpl_tlp_hdr_at;
reg [9:0] tx_cpl_tlp_hdr_length;
reg [15:0] tx_cpl_tlp_hdr_completer_id;
reg [2:0] tx_cpl_tlp_hdr_cpl_status;
reg tx_cpl_tlp_hdr_bcm;
reg [11:0] tx_cpl_tlp_hdr_byte_count;
reg [15:0] tx_cpl_tlp_hdr_requester_id;
reg [9:0] tx_cpl_tlp_hdr_tag;
reg [6:0] tx_cpl_tlp_hdr_lower_addr;

reg [95:0] tlp_header_data;
reg [AXIS_PCIE_CC_USER_WIDTH-1:0] tlp_tuser;

reg  [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata_int = 0;
reg  [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep_int = 0;
reg                                m_axis_cc_tvalid_int = 0;
wire                               m_axis_cc_tready_int;
reg                                m_axis_cc_tlast_int = 0;
reg  [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser_int = 0;

always @* begin
    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;

    out_tlp_data_next = out_tlp_data_reg;
    out_tlp_strb_next = out_tlp_strb_reg;
    out_tlp_eop_next = out_tlp_eop_reg;

    tx_cpl_tlp_ready_cmb = 1'b0;

    // TLP header parsing
    // DW 0
    tx_cpl_tlp_hdr_fmt = tx_cpl_tlp_hdr[127:125]; // fmt
    tx_cpl_tlp_hdr_type = tx_cpl_tlp_hdr[124:120]; // type
    tx_cpl_tlp_hdr_tag[9] = tx_cpl_tlp_hdr[119]; // T9
    tx_cpl_tlp_hdr_tc = tx_cpl_tlp_hdr[118:116]; // TC
    tx_cpl_tlp_hdr_tag[8] = tx_cpl_tlp_hdr[115]; // T8
    tx_cpl_tlp_hdr_attr[2] = tx_cpl_tlp_hdr[114]; // attr
    tx_cpl_tlp_hdr_ln = tx_cpl_tlp_hdr[113]; // LN
    tx_cpl_tlp_hdr_th = tx_cpl_tlp_hdr[112]; // TH
    tx_cpl_tlp_hdr_td = tx_cpl_tlp_hdr[111]; // TD
    tx_cpl_tlp_hdr_ep = tx_cpl_tlp_hdr[110]; // EP
    tx_cpl_tlp_hdr_attr[1:0] = tx_cpl_tlp_hdr[109:108]; // attr
    tx_cpl_tlp_hdr_at = tx_cpl_tlp_hdr[107:106]; // AT
    tx_cpl_tlp_hdr_length = tx_cpl_tlp_hdr[105:96]; // length
    // DW 1
    tx_cpl_tlp_hdr_completer_id = tx_cpl_tlp_hdr[95:80]; // completer ID
    tx_cpl_tlp_hdr_cpl_status = tx_cpl_tlp_hdr[79:77]; // completion status
    tx_cpl_tlp_hdr_bcm = tx_cpl_tlp_hdr[76]; // BCM
    tx_cpl_tlp_hdr_byte_count = tx_cpl_tlp_hdr[75:64]; // byte count
    // DW 2
    tx_cpl_tlp_hdr_requester_id = tx_cpl_tlp_hdr[63:48]; // requester ID
    tx_cpl_tlp_hdr_tag[7:0] = tx_cpl_tlp_hdr[47:40]; // tag
    tx_cpl_tlp_hdr_lower_addr = tx_cpl_tlp_hdr[38:32]; // lower address

    tlp_header_data[6:0] = tx_cpl_tlp_hdr_lower_addr; // lower address
    tlp_header_data[7] = 1'b0;
    tlp_header_data[9:8] = tx_cpl_tlp_hdr_at; // AT
    tlp_header_data[15:10] = 6'd0;
    tlp_header_data[28:16] = tx_cpl_tlp_hdr_byte_count; // Byte count
    tlp_header_data[29] = 1'b0; // locked read completion
    tlp_header_data[31:30] = 2'd0;
    tlp_header_data[42:32] = tx_cpl_tlp_hdr_length; // DWORD count
    tlp_header_data[45:43] = tx_cpl_tlp_hdr_cpl_status; // completion status
    tlp_header_data[46] = tx_cpl_tlp_hdr_ep; // poisoned
    tlp_header_data[47] = 1'b0;
    tlp_header_data[63:48] = tx_cpl_tlp_hdr_requester_id; // requester ID
    tlp_header_data[71:64] = tx_cpl_tlp_hdr_tag; // tag
    tlp_header_data[87:72] = tx_cpl_tlp_hdr_completer_id; // completer ID
    tlp_header_data[88] = 1'b0; // completer ID enable
    tlp_header_data[91:89] = tx_cpl_tlp_hdr_tc; // TC
    tlp_header_data[94:92] = tx_cpl_tlp_hdr_attr; // attr
    tlp_header_data[95] = 1'b0; // force ECRC

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        tlp_tuser[1:0] = 2'b01; // is_sop
        tlp_tuser[3:2] = 2'd0; // is_sop0_ptr
        tlp_tuser[5:4] = 2'd0; // is_sop1_ptr
        tlp_tuser[7:6] = 2'b01; // is_eop
        tlp_tuser[11:8]  = 4'd3; // is_eop0_ptr
        tlp_tuser[15:12] = 4'd0; // is_eop1_ptr
        tlp_tuser[16] = 1'b0; // discontinue
        tlp_tuser[80:17] = 64'd0; // parity
    end else begin
        tlp_tuser[0] = 1'b0; // discontinue
        tlp_tuser[32:1] = 32'd0; // parity
    end

    // TLP output
    m_axis_cc_tdata_int = 0;
    m_axis_cc_tkeep_int = 0;
    m_axis_cc_tvalid_int = 1'b0;
    m_axis_cc_tlast_int = 1'b0;
    m_axis_cc_tuser_int = 0;

    // combine header and payload, merge in read request TLPs
    case (tlp_output_state_reg)
        TLP_OUTPUT_STATE_IDLE: begin
            // idle state

            if (tx_cpl_tlp_valid && m_axis_cc_tready_int) begin
                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    // 64 bit interface, send first half of header
                    m_axis_cc_tdata_int = tlp_header_data[63:0];
                    m_axis_cc_tkeep_int = 2'b11;
                    m_axis_cc_tvalid_int = 1'b1;
                    m_axis_cc_tlast_int = 1'b0;
                    m_axis_cc_tuser_int = tlp_tuser;

                    tlp_output_state_next = TLP_OUTPUT_STATE_HEADER;
                end else begin
                    // wider interface, send header and start of payload
                    m_axis_cc_tdata_int = {tx_cpl_tlp_data, tlp_header_data};
                    m_axis_cc_tkeep_int = {tx_cpl_tlp_strb, 3'b111};
                    m_axis_cc_tvalid_int = 1'b1;
                    m_axis_cc_tlast_int = 1'b0;
                    m_axis_cc_tuser_int = tlp_tuser;

                    tx_cpl_tlp_ready_cmb = 1'b1;

                    out_tlp_data_next = tx_cpl_tlp_data;
                    out_tlp_strb_next = tx_cpl_tlp_strb;
                    out_tlp_eop_next = tx_cpl_tlp_eop;

                    if (tx_cpl_tlp_eop && ((tx_cpl_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-3)) == 0)) begin
                        m_axis_cc_tlast_int = 1'b1;
                        tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                    end else begin
                        tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                    end
                end
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end
        end
        TLP_OUTPUT_STATE_HEADER: begin
            // second cycle of header (64 bit interface width only)
            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axis_cc_tdata_int = {tx_cpl_tlp_data, tlp_header_data[95:64]};
                m_axis_cc_tkeep_int = {tx_cpl_tlp_strb, 1'b1};
                m_axis_cc_tvalid_int = 1'b1;
                m_axis_cc_tlast_int = 1'b0;
                m_axis_cc_tuser_int = tlp_tuser;

                tx_cpl_tlp_ready_cmb = 1'b1;

                out_tlp_data_next = tx_cpl_tlp_data;
                out_tlp_strb_next = tx_cpl_tlp_strb;
                out_tlp_eop_next = tx_cpl_tlp_eop;

                if (tx_cpl_tlp_eop && ((tx_cpl_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-1)) == 0)) begin
                    m_axis_cc_tlast_int = 1'b1;
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                end
            end
        end
        TLP_OUTPUT_STATE_PAYLOAD: begin
            // transfer payload
            if (AXIS_PCIE_DATA_WIDTH >= 128) begin
                m_axis_cc_tdata_int = {tx_cpl_tlp_data, out_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-96]};
                if (tx_cpl_tlp_valid && !out_tlp_eop_reg) begin
                    m_axis_cc_tkeep_int = {tx_cpl_tlp_strb, out_tlp_strb_reg[TLP_STRB_WIDTH-1:TLP_DATA_WIDTH_DWORDS-3]};
                end else begin
                    m_axis_cc_tkeep_int = out_tlp_strb_reg[TLP_STRB_WIDTH-1:TLP_DATA_WIDTH_DWORDS-3];
                end
                m_axis_cc_tlast_int = 1'b0;
                m_axis_cc_tuser_int = tlp_tuser;

                if ((tx_cpl_tlp_valid || out_tlp_eop_reg) && m_axis_cc_tready_int) begin
                    m_axis_cc_tvalid_int = 1'b1;
                    tx_cpl_tlp_ready_cmb = !out_tlp_eop_reg;

                    out_tlp_data_next = tx_cpl_tlp_data;
                    out_tlp_strb_next = tx_cpl_tlp_strb;
                    out_tlp_eop_next = tx_cpl_tlp_eop;

                    if (out_tlp_eop_reg || (tx_cpl_tlp_eop && ((tx_cpl_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-3)) == 0))) begin
                        m_axis_cc_tlast_int = 1'b1;
                        tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                    end else begin
                        tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                    end
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                end
            end else begin
                m_axis_cc_tdata_int = {tx_cpl_tlp_data, out_tlp_data_reg[TLP_DATA_WIDTH-1:TLP_DATA_WIDTH-32]};
                if (tx_cpl_tlp_valid && !out_tlp_eop_reg) begin
                    m_axis_cc_tkeep_int = {tx_cpl_tlp_strb, out_tlp_strb_reg[TLP_STRB_WIDTH-1:TLP_DATA_WIDTH_DWORDS-1]};
                end else begin
                    m_axis_cc_tkeep_int = out_tlp_strb_reg[TLP_STRB_WIDTH-1:TLP_DATA_WIDTH_DWORDS-1];
                end
                m_axis_cc_tlast_int = 1'b0;
                m_axis_cc_tuser_int = tlp_tuser;

                if ((tx_cpl_tlp_valid || out_tlp_eop_reg) && m_axis_cc_tready_int) begin
                    m_axis_cc_tvalid_int = 1'b1;
                    tx_cpl_tlp_ready_cmb = !out_tlp_eop_reg;

                    out_tlp_data_next = tx_cpl_tlp_data;
                    out_tlp_strb_next = tx_cpl_tlp_strb;
                    out_tlp_eop_next = tx_cpl_tlp_eop;

                    if (out_tlp_eop_reg || (tx_cpl_tlp_eop && ((tx_cpl_tlp_strb >> (TLP_DATA_WIDTH_DWORDS-1)) == 0))) begin
                        m_axis_cc_tlast_int = 1'b1;
                        tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                    end else begin
                        tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                    end
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
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
reg [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg                               m_axis_cc_tvalid_reg = 1'b0, m_axis_cc_tvalid_next;
reg                               m_axis_cc_tlast_reg = 1'b0;
reg [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser_reg = {AXIS_PCIE_CC_USER_WIDTH{1'b0}};

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
reg [AXIS_PCIE_CC_USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axis_cc_tready_int = !out_fifo_half_full_reg;

assign m_axis_cc_tdata = m_axis_cc_tdata_reg;
assign m_axis_cc_tkeep = m_axis_cc_tkeep_reg;
assign m_axis_cc_tvalid = m_axis_cc_tvalid_reg;
assign m_axis_cc_tlast = m_axis_cc_tlast_reg;
assign m_axis_cc_tuser = m_axis_cc_tuser_reg;

always @(posedge clk) begin
    m_axis_cc_tvalid_reg <= m_axis_cc_tvalid_reg && !m_axis_cc_tready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axis_cc_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_cc_tdata_int;
        out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_cc_tkeep_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_cc_tlast_int;
        out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_cc_tuser_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axis_cc_tvalid_reg || m_axis_cc_tready)) begin
        m_axis_cc_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_cc_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_cc_tvalid_reg <= 1'b1;
        m_axis_cc_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_cc_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axis_cc_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
