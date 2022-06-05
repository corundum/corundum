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
 * PCIe AXI Master (read)
 */
module pcie_axi_master_rd #
(
    // TLP data width
    parameter TLP_DATA_WIDTH = 256,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = TLP_DATA_WIDTH,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 64,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // Force 64 bit address
    parameter TLP_FORCE_64_BIT_ADDR = 0
)
(
    input  wire                                    clk,
    input  wire                                    rst,

    /*
     * TLP input (request)
     */
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  rx_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_eop,
    output wire                                    rx_req_tlp_ready,

    /*
     * TLP output (completion)
     */
    output wire [TLP_DATA_WIDTH-1:0]               tx_cpl_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]               tx_cpl_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  tx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_eop,
    input  wire                                    tx_cpl_tlp_ready,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]                 m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]               m_axi_araddr,
    output wire [7:0]                              m_axi_arlen,
    output wire [2:0]                              m_axi_arsize,
    output wire [1:0]                              m_axi_arburst,
    output wire                                    m_axi_arlock,
    output wire [3:0]                              m_axi_arcache,
    output wire [2:0]                              m_axi_arprot,
    output wire                                    m_axi_arvalid,
    input  wire                                    m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]                 m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]               m_axi_rdata,
    input  wire [1:0]                              m_axi_rresp,
    input  wire                                    m_axi_rlast,
    input  wire                                    m_axi_rvalid,
    output wire                                    m_axi_rready,

    /*
     * Configuration
     */
    input  wire [15:0]                             completer_id,
    input  wire [2:0]                              max_payload_size,

    /*
     * Status
     */
    output wire                                    status_error_cor,
    output wire                                    status_error_uncor
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN*AXI_WORD_WIDTH;

parameter PAYLOAD_MAX = AXI_MAX_BURST_SIZE < 4096 ? $clog2(AXI_MAX_BURST_SIZE/128) : 5;

parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter OFFSET_WIDTH = $clog2(TLP_DATA_WIDTH_DWORDS);

// bus width assertions
initial begin
    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end

    if (TLP_STRB_WIDTH*32 != TLP_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end

    if (AXI_DATA_WIDTH != TLP_DATA_WIDTH) begin
        $error("Error: AXI interface width must match PCIe interface width (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH * 8 != AXI_DATA_WIDTH) begin
        $error("Error: AXI interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
        $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_SIZE < 128) begin
        $error("Error: AXI max burst size must be at least 128 bytes (instance %m)");
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

localparam [1:0]
    AXI_STATE_IDLE = 2'd0,
    AXI_STATE_START = 2'd1,
    AXI_STATE_WAIT_END = 2'd2;

reg [1:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

localparam [1:0]
    TLP_STATE_IDLE = 2'd0,
    TLP_STATE_HEADER = 2'd1,
    TLP_STATE_TRANSFER = 2'd2,
    TLP_STATE_CPL = 2'd3;

reg [1:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

// datapath control signals
reg transfer_in_save;

reg tlp_cmd_ready;

reg [AXI_ADDR_WIDTH-1:0] axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, axi_addr_next;
reg [12:0] op_count_reg = 13'd0, op_count_next;
reg [10:0] op_dword_count_reg = 11'd0, op_dword_count_next;
reg [10:0] tlp_dword_count_reg = 11'd0, tlp_dword_count_next;
reg [3:0] first_be_reg = 4'd0, first_be_next;
reg [3:0] last_be_reg = 4'd0, last_be_next;

reg [6:0] tlp_lower_addr_reg = 7'd0, tlp_lower_addr_next;
reg [12:0] tlp_len_reg = 13'd0, tlp_len_next;
reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
reg [10:0] dword_count_reg = 11'd0, dword_count_next;
reg [9:0] input_cycle_count_reg = 10'd0, input_cycle_count_next;
reg [9:0] output_cycle_count_reg = 10'd0, output_cycle_count_next;
reg input_active_reg = 1'b0, input_active_next;
reg bubble_cycle_reg = 1'b0, bubble_cycle_next;
reg last_cycle_reg = 1'b0, last_cycle_next;
reg last_tlp_reg = 1'b0, last_tlp_next;
reg [2:0] status_reg = 3'd0, status_next;
reg [15:0] requester_id_reg = 16'd0, requester_id_next;
reg [9:0] tag_reg = 10'd0, tag_next;
reg [2:0] tc_reg = 3'd0, tc_next;
reg [2:0] attr_reg = 3'd0, attr_next;

reg [6:0] tlp_cmd_lower_addr_reg = 7'd0, tlp_cmd_lower_addr_next;
reg [12:0] tlp_cmd_byte_len_reg = 13'd0, tlp_cmd_byte_len_next;
reg [10:0] tlp_cmd_dword_len_reg = 11'd0, tlp_cmd_dword_len_next;
reg [9:0] tlp_cmd_input_cycle_len_reg = 10'd0, tlp_cmd_input_cycle_len_next;
reg [9:0] tlp_cmd_output_cycle_len_reg = 10'd0, tlp_cmd_output_cycle_len_next;
reg [OFFSET_WIDTH-1:0] tlp_cmd_offset_reg = {OFFSET_WIDTH{1'b0}}, tlp_cmd_offset_next;
reg [2:0] tlp_cmd_status_reg = 3'd0, tlp_cmd_status_next;
reg [15:0] tlp_cmd_requester_id_reg = 16'd0, tlp_cmd_requester_id_next;
reg [9:0] tlp_cmd_tag_reg = 10'd0, tlp_cmd_tag_next;
reg [2:0] tlp_cmd_tc_reg = 3'd0, tlp_cmd_tc_next;
reg [2:0] tlp_cmd_attr_reg = 3'd0, tlp_cmd_attr_next;
reg tlp_cmd_bubble_cycle_reg = 1'b0, tlp_cmd_bubble_cycle_next;
reg tlp_cmd_last_reg = 1'b0, tlp_cmd_last_next;
reg tlp_cmd_valid_reg = 1'b0, tlp_cmd_valid_next;

reg [10:0] max_payload_size_dw_reg = 11'd0;

reg [2:0] rx_req_tlp_hdr_fmt;
reg [4:0] rx_req_tlp_hdr_type;
reg [2:0] rx_req_tlp_hdr_tc;
reg rx_req_tlp_hdr_ln;
reg rx_req_tlp_hdr_th;
reg rx_req_tlp_hdr_td;
reg rx_req_tlp_hdr_ep;
reg [2:0] rx_req_tlp_hdr_attr;
reg [1:0] rx_req_tlp_hdr_at;
reg [10:0] rx_req_tlp_hdr_length;
reg [15:0] rx_req_tlp_hdr_requester_id;
reg [9:0] rx_req_tlp_hdr_tag;
reg [7:0] rx_req_tlp_hdr_last_be;
reg [7:0] rx_req_tlp_hdr_first_be;
reg [63:0] rx_req_tlp_hdr_addr;
reg [1:0] rx_req_tlp_hdr_ph;

reg [1:0] rx_req_first_be_offset;
reg [1:0] rx_req_last_be_offset;
reg [2:0] rx_req_single_dword_len;

reg [127:0] cpl_tlp_hdr;

reg rx_req_tlp_ready_reg = 1'b0, rx_req_tlp_ready_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
reg m_axi_rready_reg = 1'b0, m_axi_rready_next;

reg [AXI_DATA_WIDTH-1:0] save_axi_rdata_reg = {AXI_DATA_WIDTH{1'b0}};

wire [AXI_DATA_WIDTH-1:0] shift_axi_rdata = {m_axi_rdata, save_axi_rdata_reg} >> ((AXI_STRB_WIDTH/4-offset_reg)*32);

reg status_error_cor_reg = 1'b0, status_error_cor_next;
reg status_error_uncor_reg = 1'b0, status_error_uncor_next;

// internal datapath
reg  [TLP_DATA_WIDTH-1:0]               tx_cpl_tlp_data_int;
reg  [TLP_STRB_WIDTH-1:0]               tx_cpl_tlp_strb_int;
reg  [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  tx_cpl_tlp_hdr_int;
reg  [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_valid_int;
reg  [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_sop_int;
reg  [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_eop_int;
reg                                     tx_cpl_tlp_ready_int_reg = 1'b0;
wire                                    tx_cpl_tlp_ready_int_early;

assign rx_req_tlp_ready = rx_req_tlp_ready_reg;

assign m_axi_arid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_araddr = m_axi_araddr_reg;
assign m_axi_arlen = m_axi_arlen_reg;
assign m_axi_arsize = AXI_BURST_SIZE;
assign m_axi_arburst = 2'b01;
assign m_axi_arlock = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot = 3'b010;
assign m_axi_arvalid = m_axi_arvalid_reg;
assign m_axi_rready = m_axi_rready_reg;

assign status_error_cor = status_error_cor_reg;
assign status_error_uncor = status_error_uncor_reg;

always @* begin
    axi_state_next = AXI_STATE_IDLE;

    rx_req_tlp_ready_next = 1'b0;

    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;

    axi_addr_next = axi_addr_reg;
    op_count_next = op_count_reg;
    op_dword_count_next = op_dword_count_reg;
    tlp_dword_count_next = tlp_dword_count_reg;
    first_be_next = first_be_reg;
    last_be_next = last_be_reg;

    tlp_cmd_lower_addr_next = tlp_cmd_lower_addr_reg;
    tlp_cmd_byte_len_next = tlp_cmd_byte_len_reg;
    tlp_cmd_dword_len_next = tlp_cmd_dword_len_reg;
    tlp_cmd_input_cycle_len_next = tlp_cmd_input_cycle_len_reg;
    tlp_cmd_output_cycle_len_next = tlp_cmd_output_cycle_len_reg;
    tlp_cmd_offset_next = tlp_cmd_offset_reg;
    tlp_cmd_status_next = tlp_cmd_status_reg;
    tlp_cmd_requester_id_next = tlp_cmd_requester_id_reg;
    tlp_cmd_tag_next = tlp_cmd_tag_reg;
    tlp_cmd_attr_next = tlp_cmd_attr_reg;
    tlp_cmd_tc_next = tlp_cmd_tc_reg;
    tlp_cmd_bubble_cycle_next = tlp_cmd_bubble_cycle_reg;
    tlp_cmd_last_next = tlp_cmd_last_reg;
    tlp_cmd_valid_next = tlp_cmd_valid_reg && !tlp_cmd_ready;

    status_error_cor_next = 1'b0;
    status_error_uncor_next = 1'b0;

    // TLP header parsing
    // DW 0
    rx_req_tlp_hdr_fmt = rx_req_tlp_hdr[127:125]; // fmt
    rx_req_tlp_hdr_type = rx_req_tlp_hdr[124:120]; // type
    rx_req_tlp_hdr_tag[9] = rx_req_tlp_hdr[119]; // T9
    rx_req_tlp_hdr_tc = rx_req_tlp_hdr[118:116]; // TC
    rx_req_tlp_hdr_tag[8] = rx_req_tlp_hdr[115]; // T8
    rx_req_tlp_hdr_attr[2] = rx_req_tlp_hdr[114]; // attr
    rx_req_tlp_hdr_ln = rx_req_tlp_hdr[113]; // LN
    rx_req_tlp_hdr_th = rx_req_tlp_hdr[112]; // TH
    rx_req_tlp_hdr_td = rx_req_tlp_hdr[111]; // TD
    rx_req_tlp_hdr_ep = rx_req_tlp_hdr[110]; // EP
    rx_req_tlp_hdr_attr[1:0] = rx_req_tlp_hdr[109:108]; // attr
    rx_req_tlp_hdr_at = rx_req_tlp_hdr[107:106]; // AT
    rx_req_tlp_hdr_length = {rx_req_tlp_hdr[105:96] == 0, rx_req_tlp_hdr[105:96]}; // length
    // DW 1
    rx_req_tlp_hdr_requester_id = rx_req_tlp_hdr[95:80]; // requester ID
    rx_req_tlp_hdr_tag[7:0] = rx_req_tlp_hdr[79:72]; // tag
    rx_req_tlp_hdr_last_be = rx_req_tlp_hdr[71:68]; // last BE
    rx_req_tlp_hdr_first_be = rx_req_tlp_hdr[67:64]; // first BE
    if (rx_req_tlp_hdr_fmt[0] || TLP_FORCE_64_BIT_ADDR) begin
        // 4 DW (64-bit address)
        // DW 2+3
        rx_req_tlp_hdr_addr = {rx_req_tlp_hdr[63:2], 2'b00}; // addr
        rx_req_tlp_hdr_ph = rx_req_tlp_hdr[1:0]; // PH
    end else begin
        // 3 DW (32-bit address)
        // DW 2
        rx_req_tlp_hdr_addr = {rx_req_tlp_hdr[63:34], 2'b00}; // addr
        rx_req_tlp_hdr_ph = rx_req_tlp_hdr[33:32]; // PH
    end

    casez (rx_req_tlp_hdr_first_be)
        4'b0000: rx_req_single_dword_len = 3'd1;
        4'b0001: rx_req_single_dword_len = 3'd1;
        4'b0010: rx_req_single_dword_len = 3'd1;
        4'b0100: rx_req_single_dword_len = 3'd1;
        4'b1000: rx_req_single_dword_len = 3'd1;
        4'b0011: rx_req_single_dword_len = 3'd2;
        4'b0110: rx_req_single_dword_len = 3'd2;
        4'b1100: rx_req_single_dword_len = 3'd2;
        4'b01z1: rx_req_single_dword_len = 3'd3;
        4'b1z10: rx_req_single_dword_len = 3'd3;
        4'b1zz1: rx_req_single_dword_len = 3'd4;
        default: rx_req_single_dword_len = 3'd1;
    endcase

    casez (rx_req_tlp_hdr_first_be)
        4'b0000: rx_req_first_be_offset = 2'b00;
        4'bzzz1: rx_req_first_be_offset = 2'b00;
        4'bzz10: rx_req_first_be_offset = 2'b01;
        4'bz100: rx_req_first_be_offset = 2'b10;
        4'b1000: rx_req_first_be_offset = 2'b11;
        default: rx_req_first_be_offset = 2'b00;
    endcase

    casez (rx_req_tlp_hdr_last_be)
        4'b0000: rx_req_last_be_offset = 2'b00;
        4'b1zzz: rx_req_last_be_offset = 2'b00;
        4'b01zz: rx_req_last_be_offset = 2'b01;
        4'b001z: rx_req_last_be_offset = 2'b10;
        4'b0001: rx_req_last_be_offset = 2'b11;
        default: rx_req_last_be_offset = 2'b00;
    endcase

    // TLP segmentation and AXI read request generation
    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state, wait for completion request
            rx_req_tlp_ready_next = (!m_axi_arvalid_reg || m_axi_arready) && !tlp_cmd_valid_reg;

            axi_addr_next = {rx_req_tlp_hdr_addr[63:2], rx_req_first_be_offset};
            op_dword_count_next = rx_req_tlp_hdr_length;
            if (rx_req_tlp_hdr_length == 1) begin
                op_count_next = rx_req_single_dword_len;
            end else begin
                op_count_next = (rx_req_tlp_hdr_length << 2) - rx_req_first_be_offset - rx_req_last_be_offset;
            end
            first_be_next = rx_req_tlp_hdr_first_be;
            last_be_next = op_dword_count_next == 1 ? rx_req_tlp_hdr_first_be : rx_req_tlp_hdr_last_be;

            if (rx_req_tlp_ready && rx_req_tlp_valid && rx_req_tlp_sop) begin
                tlp_cmd_status_next = CPL_STATUS_SC;
                tlp_cmd_requester_id_next = rx_req_tlp_hdr_requester_id;
                tlp_cmd_tag_next = rx_req_tlp_hdr_tag;
                tlp_cmd_tc_next = rx_req_tlp_hdr_tc;
                tlp_cmd_attr_next = rx_req_tlp_hdr_attr;

                if (!rx_req_tlp_hdr_fmt[1] && rx_req_tlp_hdr_type == 5'b00000) begin
                    // read request

                    rx_req_tlp_ready_next = 1'b0;

                    axi_state_next = AXI_STATE_START;
                end else begin
                    // other request
                    if ((rx_req_tlp_hdr_fmt[0] && rx_req_tlp_hdr_type & 5'b11000 == 5'b10000) || (rx_req_tlp_hdr_fmt[1] && rx_req_tlp_hdr_type == 5'b00000)) begin
                        // message or write request - posted, no completion
                        // report uncorrectable error
                        status_error_uncor_next = 1'b1;
                    end else if (!rx_req_tlp_hdr_fmt[0] && (rx_req_tlp_hdr_type == 5'b01010 || rx_req_tlp_hdr_type == 5'b01011)) begin
                        // completion TLP
                        // unexpected completion, advisory non-fatal error
                        // report correctable error
                        status_error_cor_next = 1'b1;
                    end else begin
                        // other non-posted request, send UR completion
                        // report correctable error
                        status_error_cor_next = 1'b1;

                        // UR completion
                        tlp_cmd_status_next = CPL_STATUS_UR;
                        tlp_cmd_byte_len_next = 12'd0;
                        tlp_cmd_dword_len_next = 10'd0;
                        tlp_cmd_valid_next = 1'b1;
                    end

                    if (rx_req_tlp_eop) begin
                        axi_state_next = AXI_STATE_IDLE;
                    end else begin
                        rx_req_tlp_ready_next = 1'b1;
                        axi_state_next = AXI_STATE_WAIT_END;
                    end
                end
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_START: begin
            // start state, compute TLP length
            if (!tlp_cmd_valid_reg && !m_axi_arvalid) begin
                if (op_dword_count_reg <= max_payload_size_dw_reg) begin
                    // packet smaller than max payload size
                    // assumed to not cross 4k boundary, send one TLP
                    tlp_dword_count_next = op_dword_count_reg;
                    tlp_cmd_last_next = 1'b1;
                    // always last TLP, so next address is irrelevant
                    axi_addr_next[AXI_ADDR_WIDTH-1:12] = axi_addr_reg[AXI_ADDR_WIDTH-1:12];
                    axi_addr_next[11:0] = 12'd0;
                end else begin
                    // packet larger than max payload size
                    // assumed to not cross 4k boundary, send one TLP, align to 128 byte RCB
                    tlp_dword_count_next = max_payload_size_dw_reg - axi_addr_reg[6:2];
                    tlp_cmd_last_next = 1'b0;
                    // optimized axi_addr_next = axi_addr_reg + tlp_dword_count_next;
                    axi_addr_next[AXI_ADDR_WIDTH-1:12] = axi_addr_reg[AXI_ADDR_WIDTH-1:12];
                    axi_addr_next[11:0] = {{axi_addr_reg[11:7], 5'd0} + max_payload_size_dw_reg, 2'b00};
                end

                // read completion TLP will transfer DWORD count minus offset into first DWORD
                op_count_next = op_count_reg - (tlp_dword_count_next << 2) + axi_addr_reg[1:0];
                op_dword_count_next = op_dword_count_reg - tlp_dword_count_next;

                // number of bus transfers from AXI, DWORD count plus DWORD offset, divided by bus width in DWORDS
                tlp_cmd_input_cycle_len_next = (tlp_dword_count_next + axi_addr_reg[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                // number of bus transfers in TLP, DOWRD count plus payload start DWORD offset, divided by bus width in DWORDS
                tlp_cmd_output_cycle_len_next = (tlp_dword_count_next - 1) >> (AXI_BURST_SIZE-2);

                tlp_cmd_lower_addr_next = axi_addr_reg;
                tlp_cmd_byte_len_next = op_count_reg;
                tlp_cmd_dword_len_next = tlp_dword_count_next;
                // required DWORD shift to place first DWORD read from AXI into proper position in payload
                // bubble cycle required if first AXI transfer does not fill first payload transfer
                tlp_cmd_offset_next = -axi_addr_reg[OFFSET_WIDTH+2-1:2];
                tlp_cmd_bubble_cycle_next = axi_addr_reg[OFFSET_WIDTH+2-1:2] != 0;
                tlp_cmd_valid_next = 1'b1;

                m_axi_araddr_next = axi_addr_reg;
                m_axi_arlen_next = (tlp_dword_count_next + axi_addr_reg[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                m_axi_arvalid_next = 1;

                if (!tlp_cmd_last_next) begin
                    axi_state_next = AXI_STATE_START;
                end else begin
                    axi_state_next = AXI_STATE_IDLE;
                end
            end else begin
                axi_state_next = AXI_STATE_START;
            end
        end
        AXI_STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            rx_req_tlp_ready_next = 1'b1;

            if (rx_req_tlp_ready && rx_req_tlp_valid) begin
                if (rx_req_tlp_eop) begin

                    rx_req_tlp_ready_next = (!m_axi_arvalid_reg || m_axi_arready) && !tlp_cmd_valid_reg;

                    axi_state_next = AXI_STATE_IDLE;
                end else begin
                    axi_state_next = AXI_STATE_WAIT_END;
                end
            end else begin
                axi_state_next = AXI_STATE_WAIT_END;
            end
        end
    endcase
end

always @* begin
    tlp_state_next = TLP_STATE_IDLE;

    transfer_in_save = 1'b0;

    tlp_cmd_ready = 1'b0;

    m_axi_rready_next = 1'b0;

    tlp_lower_addr_next = tlp_lower_addr_reg;
    tlp_len_next = tlp_len_reg;
    dword_count_next = dword_count_reg;
    offset_next = offset_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    bubble_cycle_next = bubble_cycle_reg;
    last_cycle_next = last_cycle_reg;
    last_tlp_next = last_tlp_reg;
    status_next = status_reg;
    requester_id_next = requester_id_reg;
    tag_next = tag_reg;
    tc_next = tc_reg;
    attr_next = attr_reg;

    // TLP header
    // DW 0
    cpl_tlp_hdr[127:125] = (status_reg == CPL_STATUS_SC) ? TLP_FMT_3DW_DATA : TLP_FMT_3DW; // fmt
    cpl_tlp_hdr[124:120] = 5'b01010; // type
    cpl_tlp_hdr[119] = tag_reg[9]; // T9
    cpl_tlp_hdr[118:116] = tc_reg; // TC
    cpl_tlp_hdr[115] = tag_reg[8]; // T8
    cpl_tlp_hdr[114] = attr_reg[2]; // attr
    cpl_tlp_hdr[113] = 1'b0; // LN
    cpl_tlp_hdr[112] = 1'b0; // TH
    cpl_tlp_hdr[111] = 1'b0; // TD
    cpl_tlp_hdr[110] = 1'b0; // EP
    cpl_tlp_hdr[109:108] = attr_reg[1:0]; // attr
    cpl_tlp_hdr[107:106] = 2'b00; // AT
    cpl_tlp_hdr[105:96] = dword_count_reg; // length
    // DW 1
    cpl_tlp_hdr[95:80] = completer_id; // completer ID
    cpl_tlp_hdr[79:77] = status_reg; // completion status
    cpl_tlp_hdr[76] = 1'b0; // BCM
    cpl_tlp_hdr[75:64] = tlp_len_reg; // byte count
    // DW 2
    cpl_tlp_hdr[63:48] = requester_id_reg; // requester ID
    cpl_tlp_hdr[47:40] = tag_reg[7:0]; // tag
    cpl_tlp_hdr[39] = 1'b0;
    cpl_tlp_hdr[38:32] = tlp_lower_addr_reg; // lower address
    cpl_tlp_hdr[31:0] = 32'd0;

    tx_cpl_tlp_data_int = shift_axi_rdata;
    tx_cpl_tlp_strb_int = 0;
    tx_cpl_tlp_hdr_int = cpl_tlp_hdr;
    tx_cpl_tlp_valid_int = 0;
    tx_cpl_tlp_sop_int = 0;
    tx_cpl_tlp_eop_int = 0;

    // AXI read response processing and TLP generation
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for command
            m_axi_rready_next = 1'b0;

            // store TLP fields and transfer parameters
            tlp_lower_addr_next = tlp_cmd_lower_addr_reg;
            tlp_len_next = tlp_cmd_byte_len_reg;
            dword_count_next = tlp_cmd_dword_len_reg;
            offset_next = tlp_cmd_offset_reg;
            input_cycle_count_next = tlp_cmd_input_cycle_len_reg;
            output_cycle_count_next = tlp_cmd_output_cycle_len_reg;
            input_active_next = 1'b1;
            bubble_cycle_next = tlp_cmd_bubble_cycle_reg;
            last_cycle_next = tlp_cmd_output_cycle_len_reg == 0;
            last_tlp_next = tlp_cmd_last_reg;
            status_next = tlp_cmd_status_reg;
            requester_id_next = tlp_cmd_requester_id_reg;
            tag_next = tlp_cmd_tag_reg;
            tc_next = tlp_cmd_tc_reg;
            attr_next = tlp_cmd_attr_reg;

            if (tlp_cmd_valid_reg) begin
                tlp_cmd_ready = 1'b1;
                if (status_next == CPL_STATUS_SC) begin
                    // SC status, output TLP header
                    m_axi_rready_next = tx_cpl_tlp_ready_int_early;
                    tlp_state_next = TLP_STATE_HEADER;
                end else begin
                    // status other than SC
                    tlp_state_next = TLP_STATE_CPL;
                end
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_HEADER: begin
            // header state, send TLP header
                m_axi_rready_next = tx_cpl_tlp_ready_int_early && input_active_reg;

                if (tx_cpl_tlp_ready_int_reg && ((m_axi_rready && m_axi_rvalid) || !input_active_reg)) begin
                    transfer_in_save = m_axi_rready && m_axi_rvalid;

                    if (bubble_cycle_reg) begin
                        // bubble cycle; store input data and update input cycle count
                        if (input_active_reg) begin
                            input_cycle_count_next = input_cycle_count_reg - 1;
                            input_active_next = input_cycle_count_reg > 0;
                        end
                        bubble_cycle_next = 1'b0;
                        m_axi_rready_next = tx_cpl_tlp_ready_int_early && input_active_next;
                        tlp_state_next = TLP_STATE_HEADER;
                    end else begin
                        // some data is transferred with header
                        dword_count_next = dword_count_reg - TLP_STRB_WIDTH;
                        // update cycle counters
                        if (input_active_reg) begin
                            input_cycle_count_next = input_cycle_count_reg - 1;
                            input_active_next = input_cycle_count_reg > 0;
                        end
                        output_cycle_count_next = output_cycle_count_reg - 1;
                        last_cycle_next = output_cycle_count_next == 0;

                        // output data
                        tx_cpl_tlp_data_int = shift_axi_rdata;
                        if (dword_count_reg >= TLP_STRB_WIDTH) begin
                            tx_cpl_tlp_strb_int = {TLP_STRB_WIDTH{1'b1}};
                        end else begin
                            tx_cpl_tlp_strb_int = {TLP_STRB_WIDTH{1'b1}} >> (TLP_STRB_WIDTH - dword_count_reg);
                        end
                        tx_cpl_tlp_hdr_int = cpl_tlp_hdr;
                        tx_cpl_tlp_valid_int = 1'b1;
                        tx_cpl_tlp_sop_int = 1'b1;
                        tx_cpl_tlp_eop_int = 1'b0;

                        if (last_cycle_reg) begin
                            tx_cpl_tlp_eop_int = 1'b1;

                            // skip idle state if possible
                            tlp_lower_addr_next = tlp_cmd_lower_addr_reg;
                            tlp_len_next = tlp_cmd_byte_len_reg;
                            dword_count_next = tlp_cmd_dword_len_reg;
                            offset_next = tlp_cmd_offset_reg;
                            input_cycle_count_next = tlp_cmd_input_cycle_len_reg;
                            output_cycle_count_next = tlp_cmd_output_cycle_len_reg;
                            input_active_next = 1'b1;
                            bubble_cycle_next = tlp_cmd_bubble_cycle_reg;
                            last_cycle_next = tlp_cmd_output_cycle_len_reg == 0;
                            last_tlp_next = tlp_cmd_last_reg;
                            status_next = tlp_cmd_status_reg;
                            requester_id_next = tlp_cmd_requester_id_reg;
                            tag_next = tlp_cmd_tag_reg;
                            tc_next = tlp_cmd_tc_reg;
                            attr_next = tlp_cmd_attr_reg;

                            if (tlp_cmd_valid_reg) begin
                                tlp_cmd_ready = 1'b1;
                                m_axi_rready_next = tx_cpl_tlp_ready_int_early;
                                tlp_state_next = TLP_STATE_HEADER;
                            end else begin
                                m_axi_rready_next = 1'b0;
                                tlp_state_next = TLP_STATE_IDLE;
                            end
                        end else begin
                            m_axi_rready_next = tx_cpl_tlp_ready_int_early && input_active_next;
                            tlp_state_next = TLP_STATE_TRANSFER;
                        end
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER;
                end
        end
        TLP_STATE_TRANSFER: begin
            // transfer state, transfer data
            m_axi_rready_next = tx_cpl_tlp_ready_int_early && input_active_reg;

            if (tx_cpl_tlp_ready_int_reg && ((m_axi_rready && m_axi_rvalid) || !input_active_reg)) begin
                transfer_in_save = 1'b1;

                // update DWORD count
                dword_count_next = dword_count_reg - AXI_STRB_WIDTH/4;
                // update cycle counters
                if (input_active_reg) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_reg > 0;
                end
                output_cycle_count_next = output_cycle_count_reg - 1;
                last_cycle_next = output_cycle_count_next == 0;

                // output data
                tx_cpl_tlp_data_int = shift_axi_rdata;
                if (dword_count_reg >= TLP_STRB_WIDTH) begin
                    tx_cpl_tlp_strb_int = {TLP_STRB_WIDTH{1'b1}};
                end else begin
                    tx_cpl_tlp_strb_int = {TLP_STRB_WIDTH{1'b1}} >> (TLP_STRB_WIDTH - dword_count_reg);
                end
                tx_cpl_tlp_hdr_int = cpl_tlp_hdr;
                tx_cpl_tlp_valid_int = 1'b1;
                tx_cpl_tlp_sop_int = 1'b0;
                tx_cpl_tlp_eop_int = 1'b0;

                if (last_cycle_reg) begin
                    tx_cpl_tlp_eop_int = 1'b1;

                    // skip idle state if possible
                    tlp_lower_addr_next = tlp_cmd_lower_addr_reg;
                    tlp_len_next = tlp_cmd_byte_len_reg;
                    dword_count_next = tlp_cmd_dword_len_reg;
                    offset_next = tlp_cmd_offset_reg;
                    input_cycle_count_next = tlp_cmd_input_cycle_len_reg;
                    output_cycle_count_next = tlp_cmd_output_cycle_len_reg;
                    input_active_next = 1'b1;
                    bubble_cycle_next = tlp_cmd_bubble_cycle_reg;
                    last_cycle_next = tlp_cmd_output_cycle_len_reg == 0;
                    last_tlp_next = tlp_cmd_last_reg;
                    status_next = tlp_cmd_status_reg;
                    requester_id_next = tlp_cmd_requester_id_reg;
                    tag_next = tlp_cmd_tag_reg;
                    tc_next = tlp_cmd_tc_reg;
                    attr_next = tlp_cmd_attr_reg;

                    if (tlp_cmd_valid_reg) begin
                        tlp_cmd_ready = 1'b1;
                        m_axi_rready_next = tx_cpl_tlp_ready_int_early;
                        tlp_state_next = TLP_STATE_HEADER;
                    end else begin
                        m_axi_rready_next = 1'b0;
                        tlp_state_next = TLP_STATE_IDLE;
                    end
                end else begin
                    m_axi_rready_next = tx_cpl_tlp_ready_int_early && input_active_next;
                    tlp_state_next = TLP_STATE_TRANSFER;
                end
            end else begin
                tlp_state_next = TLP_STATE_TRANSFER;
            end
        end
        TLP_STATE_CPL: begin
            // send completion

            tx_cpl_tlp_strb_int = 0;
            tx_cpl_tlp_hdr_int = cpl_tlp_hdr;
            tx_cpl_tlp_valid_int = 1'b1;
            tx_cpl_tlp_sop_int = 1'b1;
            tx_cpl_tlp_eop_int = 1'b1;

            if (tx_cpl_tlp_ready_int_reg) begin
                // skip idle state if possible
                tlp_lower_addr_next = tlp_cmd_lower_addr_reg;
                tlp_len_next = tlp_cmd_byte_len_reg;
                dword_count_next = tlp_cmd_dword_len_reg;
                offset_next = tlp_cmd_offset_reg;
                input_cycle_count_next = tlp_cmd_input_cycle_len_reg;
                output_cycle_count_next = tlp_cmd_output_cycle_len_reg;
                input_active_next = 1'b1;
                bubble_cycle_next = tlp_cmd_bubble_cycle_reg;
                last_cycle_next = tlp_cmd_output_cycle_len_reg == 0;
                last_tlp_next = tlp_cmd_last_reg;
                status_next = tlp_cmd_status_reg;
                requester_id_next = tlp_cmd_requester_id_reg;
                tag_next = tlp_cmd_tag_reg;
                tc_next = tlp_cmd_tc_reg;
                attr_next = tlp_cmd_attr_reg;

                if (tlp_cmd_valid_reg) begin
                    tlp_cmd_ready = 1'b1;
                    m_axi_rready_next = tx_cpl_tlp_ready_int_early;
                    tlp_state_next = TLP_STATE_HEADER;
                end else begin
                    m_axi_rready_next = 1'b0;
                    tlp_state_next = TLP_STATE_IDLE;
                end
            end else begin
                tlp_state_next = TLP_STATE_CPL;
            end
        end
    endcase
end

always @(posedge clk) begin
    axi_state_reg <= axi_state_next;
    tlp_state_reg <= tlp_state_next;

    axi_addr_reg <= axi_addr_next;
    op_count_reg <= op_count_next;
    op_dword_count_reg <= op_dword_count_next;
    tlp_dword_count_reg <= tlp_dword_count_next;
    first_be_reg <= first_be_next;
    last_be_reg <= last_be_next;

    tlp_lower_addr_reg <= tlp_lower_addr_next;
    tlp_len_reg <= tlp_len_next;
    dword_count_reg <= dword_count_next;
    offset_reg <= offset_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    bubble_cycle_reg <= bubble_cycle_next;
    last_cycle_reg <= last_cycle_next;
    last_tlp_reg <= last_tlp_next;
    status_reg <= status_next;
    requester_id_reg <= requester_id_next;
    tag_reg <= tag_next;
    tc_reg <= tc_next;
    attr_reg <= attr_next;

    tlp_cmd_lower_addr_reg <= tlp_cmd_lower_addr_next;
    tlp_cmd_byte_len_reg <= tlp_cmd_byte_len_next;
    tlp_cmd_dword_len_reg <= tlp_cmd_dword_len_next;
    tlp_cmd_input_cycle_len_reg <= tlp_cmd_input_cycle_len_next;
    tlp_cmd_output_cycle_len_reg <= tlp_cmd_output_cycle_len_next;
    tlp_cmd_offset_reg <= tlp_cmd_offset_next;
    tlp_cmd_status_reg <= tlp_cmd_status_next;
    tlp_cmd_requester_id_reg <= tlp_cmd_requester_id_next;
    tlp_cmd_tag_reg <= tlp_cmd_tag_next;
    tlp_cmd_tc_reg <= tlp_cmd_tc_next;
    tlp_cmd_attr_reg <= tlp_cmd_attr_next;
    tlp_cmd_bubble_cycle_reg <= tlp_cmd_bubble_cycle_next;
    tlp_cmd_last_reg <= tlp_cmd_last_next;
    tlp_cmd_valid_reg <= tlp_cmd_valid_next;

    rx_req_tlp_ready_reg <= rx_req_tlp_ready_next;

    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;
    m_axi_arvalid_reg <= m_axi_arvalid_next;
    m_axi_rready_reg <= m_axi_rready_next;

    max_payload_size_dw_reg <= 11'd32 << (max_payload_size > PAYLOAD_MAX ? PAYLOAD_MAX : max_payload_size);

    status_error_cor_reg <= status_error_cor_next;
    status_error_uncor_reg <= status_error_uncor_next;

    if (transfer_in_save) begin
        save_axi_rdata_reg <= m_axi_rdata;
    end

    if (rst) begin
        axi_state_reg <= AXI_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;

        tlp_cmd_valid_reg <= 1'b0;

        rx_req_tlp_ready_reg <= 1'b0;

        m_axi_arvalid_reg <= 1'b0;
        m_axi_rready_reg <= 1'b0;

        status_error_cor_reg <= 1'b0;
        status_error_uncor_reg <= 1'b0;
    end
end

// output datapath logic
reg [TLP_DATA_WIDTH-1:0]               tx_cpl_tlp_data_reg = 0;
reg [TLP_STRB_WIDTH-1:0]               tx_cpl_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  tx_cpl_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_valid_reg = 0, tx_cpl_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                tx_cpl_tlp_eop_reg = 0;

reg [TLP_DATA_WIDTH-1:0]               temp_tx_cpl_tlp_data_reg = 0;
reg [TLP_STRB_WIDTH-1:0]               temp_tx_cpl_tlp_strb_reg = 0;
reg [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  temp_tx_cpl_tlp_hdr_reg = 0;
reg [TLP_SEG_COUNT-1:0]                temp_tx_cpl_tlp_valid_reg = 0, temp_tx_cpl_tlp_valid_next;
reg [TLP_SEG_COUNT-1:0]                temp_tx_cpl_tlp_sop_reg = 0;
reg [TLP_SEG_COUNT-1:0]                temp_tx_cpl_tlp_eop_reg = 0;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign tx_cpl_tlp_data   = tx_cpl_tlp_data_reg;
assign tx_cpl_tlp_strb   = tx_cpl_tlp_strb_reg;
assign tx_cpl_tlp_hdr    = tx_cpl_tlp_hdr_reg;
assign tx_cpl_tlp_valid  = tx_cpl_tlp_valid_reg;
assign tx_cpl_tlp_sop    = tx_cpl_tlp_sop_reg;
assign tx_cpl_tlp_eop    = tx_cpl_tlp_eop_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign tx_cpl_tlp_ready_int_early = tx_cpl_tlp_ready || (!temp_tx_cpl_tlp_valid_reg && !tx_cpl_tlp_valid_reg);

always @* begin
    // transfer sink ready state to source
    tx_cpl_tlp_valid_next = tx_cpl_tlp_valid_reg;
    temp_tx_cpl_tlp_valid_next = temp_tx_cpl_tlp_valid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (tx_cpl_tlp_ready_int_reg) begin
        // input is ready
        if (tx_cpl_tlp_ready || !tx_cpl_tlp_valid_reg) begin
            // output is ready or currently not valid, transfer data to output
            tx_cpl_tlp_valid_next = tx_cpl_tlp_valid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_tx_cpl_tlp_valid_next = tx_cpl_tlp_valid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (tx_cpl_tlp_ready) begin
        // input is not ready, but output is ready
        tx_cpl_tlp_valid_next = temp_tx_cpl_tlp_valid_reg;
        temp_tx_cpl_tlp_valid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    tx_cpl_tlp_valid_reg <= tx_cpl_tlp_valid_next;
    tx_cpl_tlp_ready_int_reg <= tx_cpl_tlp_ready_int_early;
    temp_tx_cpl_tlp_valid_reg <= temp_tx_cpl_tlp_valid_next;

    // datapath
    if (store_axis_int_to_output) begin
        tx_cpl_tlp_data_reg <= tx_cpl_tlp_data_int;
        tx_cpl_tlp_strb_reg <= tx_cpl_tlp_strb_int;
        tx_cpl_tlp_hdr_reg <= tx_cpl_tlp_hdr_int;
        tx_cpl_tlp_sop_reg <= tx_cpl_tlp_sop_int;
        tx_cpl_tlp_eop_reg <= tx_cpl_tlp_eop_int;
    end else if (store_axis_temp_to_output) begin
        tx_cpl_tlp_data_reg <= temp_tx_cpl_tlp_data_reg;
        tx_cpl_tlp_strb_reg <= temp_tx_cpl_tlp_strb_reg;
        tx_cpl_tlp_hdr_reg <= temp_tx_cpl_tlp_hdr_reg;
        tx_cpl_tlp_sop_reg <= temp_tx_cpl_tlp_sop_reg;
        tx_cpl_tlp_eop_reg <= temp_tx_cpl_tlp_eop_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_tx_cpl_tlp_data_reg <= tx_cpl_tlp_data_int;
        temp_tx_cpl_tlp_strb_reg <= tx_cpl_tlp_strb_int;
        temp_tx_cpl_tlp_hdr_reg <= tx_cpl_tlp_hdr_int;
        temp_tx_cpl_tlp_sop_reg <= tx_cpl_tlp_sop_int;
        temp_tx_cpl_tlp_eop_reg <= tx_cpl_tlp_eop_int;
    end

    if (rst) begin
        tx_cpl_tlp_valid_reg <= 1'b0;
        tx_cpl_tlp_ready_int_reg <= 1'b0;
        temp_tx_cpl_tlp_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
