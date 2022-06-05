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
 * PCIe AXI Master (write)
 */
module pcie_axi_master_wr #
(
    // TLP data width
    parameter TLP_DATA_WIDTH = 256,
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
    input  wire [TLP_DATA_WIDTH-1:0]               rx_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  rx_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_eop,
    output wire                                    rx_req_tlp_ready,

    /*
     * AXI Master output
     */
    output wire [AXI_ID_WIDTH-1:0]                 m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]               m_axi_awaddr,
    output wire [7:0]                              m_axi_awlen,
    output wire [2:0]                              m_axi_awsize,
    output wire [1:0]                              m_axi_awburst,
    output wire                                    m_axi_awlock,
    output wire [3:0]                              m_axi_awcache,
    output wire [2:0]                              m_axi_awprot,
    output wire                                    m_axi_awvalid,
    input  wire                                    m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]               m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]               m_axi_wstrb,
    output wire                                    m_axi_wlast,
    output wire                                    m_axi_wvalid,
    input  wire                                    m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]                 m_axi_bid,
    input  wire [1:0]                              m_axi_bresp,
    input  wire                                    m_axi_bvalid,
    output wire                                    m_axi_bready,

    /*
     * Status
     */
    output wire                                    status_error_uncor
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN*AXI_WORD_WIDTH;

parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter OFFSET_WIDTH = $clog2(TLP_DATA_WIDTH_DWORDS);

parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

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
end

localparam [2:0]
    TLP_FMT_3DW = 3'b000,
    TLP_FMT_4DW = 3'b001,
    TLP_FMT_3DW_DATA = 3'b010,
    TLP_FMT_4DW_DATA = 3'b011,
    TLP_FMT_PREFIX = 3'b100;

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_TRANSFER = 2'd1,
    STATE_WAIT_END = 2'd2;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg [AXI_ADDR_WIDTH-1:0] axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, axi_addr_next;
reg [10:0] op_dword_count_reg = 11'd0, op_dword_count_next;
reg [10:0] tr_dword_count_reg = 11'd0, tr_dword_count_next;
reg [12:0] input_cycle_count_reg = 13'd0, input_cycle_count_next;
reg [12:0] output_cycle_count_reg = 13'd0, output_cycle_count_next;
reg input_active_reg = 1'b0, input_active_next;
reg first_cycle_reg = 1'b0, first_cycle_next;
reg last_cycle_reg = 1'b0, last_cycle_next;

reg [3:0] type_reg = 4'd0, type_next;
reg [3:0] first_be_reg = 4'd0, first_be_next;
reg [3:0] last_be_reg = 4'd0, last_be_next;
reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;

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

reg rx_req_tlp_ready_reg = 1'b0, rx_req_tlp_ready_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_awaddr_next;
reg [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
reg m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;

reg [TLP_DATA_WIDTH-1:0] save_tlp_data_reg = {TLP_DATA_WIDTH{1'b0}};

wire [TLP_DATA_WIDTH-1:0] shift_tlp_data = {rx_req_tlp_data, save_tlp_data_reg} >> ((TLP_DATA_WIDTH_DWORDS-offset_reg)*32);

reg status_error_uncor_reg = 1'b0, status_error_uncor_next;

// internal datapath
reg  [AXI_DATA_WIDTH-1:0]  m_axi_wdata_int;
reg  [AXI_STRB_WIDTH-1:0]  m_axi_wstrb_int;
reg                        m_axi_wvalid_int;
reg                        m_axi_wlast_int;
wire                       m_axi_wready_int;

assign rx_req_tlp_ready = rx_req_tlp_ready_reg;

assign m_axi_awid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_awaddr = m_axi_awaddr_reg;
assign m_axi_awlen = m_axi_awlen_reg;
assign m_axi_awsize = $clog2(AXI_STRB_WIDTH);
assign m_axi_awburst = 2'b01;
assign m_axi_awlock = 1'b0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot = 3'b010;
assign m_axi_awvalid = m_axi_awvalid_reg;

assign m_axi_bready = 1'b1;

assign status_error_uncor = status_error_uncor_reg;

always @* begin
    state_next = STATE_IDLE;

    type_next = type_reg;
    axi_addr_next = axi_addr_reg;
    op_dword_count_next = op_dword_count_reg;
    tr_dword_count_next = tr_dword_count_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    first_cycle_next = first_cycle_reg;
    last_cycle_next = last_cycle_reg;
    first_be_next = first_be_reg;
    last_be_next = last_be_reg;
    offset_next = offset_reg;
    last_cycle_offset_next = last_cycle_offset_reg;

    rx_req_tlp_ready_next = 1'b0;

    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;

    m_axi_wdata_int = shift_tlp_data;
    m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b1}};
    m_axi_wvalid_int = 1'b0;
    m_axi_wlast_int = 1'b0;

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

    case (state_reg)
        STATE_IDLE: begin
            // idle state, wait for completion request
            rx_req_tlp_ready_next = (!m_axi_awvalid_reg || m_axi_awready) && m_axi_wready_int;

            axi_addr_next = rx_req_tlp_hdr_addr;
            op_dword_count_next = rx_req_tlp_hdr_length;
            first_be_next = rx_req_tlp_hdr_first_be;
            last_be_next = op_dword_count_next == 1 ? rx_req_tlp_hdr_first_be : rx_req_tlp_hdr_last_be;

            if (rx_req_tlp_ready && rx_req_tlp_valid && rx_req_tlp_sop) begin

                if (op_dword_count_next <= AXI_MAX_BURST_SIZE/4) begin
                    // packet smaller than max burst size
                    // assumed to not cross 4k boundary, send one request
                    tr_dword_count_next = op_dword_count_next;
                    m_axi_awlen_next = (tr_dword_count_next + axi_addr_next[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                end else begin
                    // packet larger than max burst size
                    // assumed to not cross 4k boundary, aligned split on burst size
                    tr_dword_count_next = AXI_MAX_BURST_SIZE/4 - axi_addr_next[OFFSET_WIDTH+2-1:2];
                    m_axi_awlen_next = (tr_dword_count_next - 1) >> (AXI_BURST_SIZE-2);
                end

                m_axi_awaddr_next = axi_addr_next;

                // required DWORD shift to place first DWORD from the TLP payload into proper position on AXI interface
                offset_next = axi_addr_next >> 2;
                first_cycle_next = 1'b1;

                // number of bus transfers in TLP, DOWRD count divided by bus width in DWORDS
                input_cycle_count_next = (tr_dword_count_next - 1) >> (AXI_BURST_SIZE-2);
                // number of bus transfers to AXI, DWORD count plus DWORD offset, divided by bus width in DWORDS
                output_cycle_count_next = m_axi_awlen_next;
                last_cycle_offset_next = offset_next + tr_dword_count_next;
                last_cycle_next = output_cycle_count_next == 0;
                input_active_next = input_cycle_count_next != 0;

                axi_addr_next = axi_addr_next + (tr_dword_count_next << 2);
                op_dword_count_next = op_dword_count_next - tr_dword_count_next;

                if (rx_req_tlp_hdr_fmt[1] && rx_req_tlp_hdr_type == 5'b00000 && !rx_req_tlp_hdr_ep) begin
                    // write request

                    m_axi_awvalid_next = 1'b1;

                    rx_req_tlp_ready_next = 1'b0;
                    state_next = STATE_TRANSFER;
                end else begin
                    // other request
                    status_error_uncor_next = 1'b1;

                    if (rx_req_tlp_eop) begin
                        state_next = STATE_IDLE;
                    end else begin
                        rx_req_tlp_ready_next = 1'b1;
                        state_next = STATE_WAIT_END;
                    end
                end
            end
        end
        STATE_TRANSFER: begin
            // transfer state, transfer data
            rx_req_tlp_ready_next = m_axi_wready_int && input_active_reg && !first_cycle_reg;

            if ((rx_req_tlp_ready && rx_req_tlp_valid) || !input_active_reg || first_cycle_reg) begin
                // transfer data

                if (first_cycle_reg) begin
                    m_axi_wdata_int = {save_tlp_data_reg, {TLP_DATA_WIDTH{1'b0}}} >> ((TLP_DATA_WIDTH_DWORDS-offset_reg)*32);
                    rx_req_tlp_ready_next = m_axi_wready_int && input_active_reg;
                end else begin
                    m_axi_wdata_int = shift_tlp_data;
                end
                // generate strb signal
                if (first_cycle_reg) begin
                    m_axi_wstrb_int = {{AXI_STRB_WIDTH-4{1'b1}}, first_be_reg} << (offset_reg*4);
                end else begin
                    m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b1}};
                end

                // update cycle counters
                if (input_active_reg && !first_cycle_reg) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_next != 0;
                end
                output_cycle_count_next = output_cycle_count_reg - 1;
                last_cycle_next = output_cycle_count_next == 0;

                // modify strb signal at end of transfer
                if (last_cycle_reg) begin
                    if (op_dword_count_reg == 0) begin
                        if (last_cycle_offset_reg > 0) begin
                            m_axi_wstrb_int = m_axi_wstrb_int & {last_be_reg, {AXI_STRB_WIDTH-4{1'b1}}} >> (AXI_STRB_WIDTH-last_cycle_offset_reg*4);
                        end else begin
                            m_axi_wstrb_int = m_axi_wstrb_int & {last_be_reg, {AXI_STRB_WIDTH-4{1'b1}}};
                        end
                    end
                    m_axi_wlast_int = 1'b1;
                end
                m_axi_wvalid_int = 1'b1;
                first_cycle_next = 1'b0;

                if (!last_cycle_reg) begin
                    // more data to transfer
                    rx_req_tlp_ready_next = m_axi_wready_int && input_active_next;
                    state_next = STATE_TRANSFER;
                end else if (op_dword_count_reg > 0) begin
                    // current transfer done, but operation not finished yet
                    if (op_dword_count_reg <= AXI_MAX_BURST_SIZE/4) begin
                        // packet smaller than max burst size
                        // assumed to not cross 4k boundary, send one request
                        tr_dword_count_next = op_dword_count_reg;
                        m_axi_awlen_next = (tr_dword_count_next + axi_addr_reg[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                    end else begin
                        // packet larger than max burst size
                        // assumed to not cross 4k boundary, aligned split on burst size
                        tr_dword_count_next = AXI_MAX_BURST_SIZE/4 - axi_addr_reg[OFFSET_WIDTH+2-1:2];
                        m_axi_awlen_next = (tr_dword_count_next - 1) >> (AXI_BURST_SIZE-2);
                    end

                    m_axi_awaddr_next = axi_addr_reg;

                    // number of bus transfers in TLP, DOWRD count minus payload start DWORD offset, divided by bus width in DWORDS
                    input_cycle_count_next = (tr_dword_count_next - offset_reg - 1) >> (AXI_BURST_SIZE-2);
                    // number of bus transfers to AXI, DWORD count plus DWORD offset, divided by bus width in DWORDS
                    output_cycle_count_next = m_axi_awlen_next;
                    last_cycle_offset_next = axi_addr_reg[OFFSET_WIDTH+2-1:2] + tr_dword_count_next;
                    last_cycle_next = output_cycle_count_next == 0;
                    input_active_next = input_cycle_count_next != 0;

                    axi_addr_next = axi_addr_reg + (tr_dword_count_next << 2);
                    op_dword_count_next = op_dword_count_reg - tr_dword_count_next;

                    m_axi_awvalid_next = 1'b1;
                    rx_req_tlp_ready_next = m_axi_wready_int && input_active_next;
                    state_next = STATE_TRANSFER;
                end else begin
                    rx_req_tlp_ready_next = (!m_axi_awvalid_reg || m_axi_awready) && m_axi_wready_int;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_TRANSFER;
            end
        end
        STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            rx_req_tlp_ready_next = 1'b1;

            if (rx_req_tlp_ready && rx_req_tlp_valid) begin
                if (rx_req_tlp_eop) begin

                    rx_req_tlp_ready_next = (!m_axi_awvalid_reg || m_axi_awready) && m_axi_wready_int;

                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_END;
                end
            end else begin
                state_next = STATE_WAIT_END;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    axi_addr_reg <= axi_addr_next;
    op_dword_count_reg <= op_dword_count_next;
    tr_dword_count_reg <= tr_dword_count_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    first_cycle_reg <= first_cycle_next;
    last_cycle_reg <= last_cycle_next;

    type_reg <= type_next;
    first_be_reg <= first_be_next;
    last_be_reg <= last_be_next;
    offset_reg <= offset_next;
    last_cycle_offset_reg <= last_cycle_offset_next;

    rx_req_tlp_ready_reg <= rx_req_tlp_ready_next;

    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;
    m_axi_awvalid_reg <= m_axi_awvalid_next;

    status_error_uncor_reg <= status_error_uncor_next;

    if (rx_req_tlp_ready && rx_req_tlp_valid) begin
        save_tlp_data_reg <= rx_req_tlp_data;
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        rx_req_tlp_ready_reg <= 1'b0;

        m_axi_awvalid_reg <= 1'b0;

        status_error_uncor_reg <= 1'b0;
    end
end

// output datapath logic (AXI write data)
reg [AXI_DATA_WIDTH-1:0] m_axi_wdata_reg  = {AXI_DATA_WIDTH{1'b0}};
reg [AXI_STRB_WIDTH-1:0] m_axi_wstrb_reg  = {AXI_STRB_WIDTH{1'b0}};
reg                      m_axi_wlast_reg  = 1'b0;
reg                      m_axi_wvalid_reg = 1'b0;

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_DATA_WIDTH-1:0] out_fifo_wdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [AXI_STRB_WIDTH-1:0] out_fifo_wstrb[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg                      out_fifo_wlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

assign m_axi_wready_int = !out_fifo_half_full_reg;

assign m_axi_wdata  = m_axi_wdata_reg;
assign m_axi_wstrb  = m_axi_wstrb_reg;
assign m_axi_wvalid = m_axi_wvalid_reg;
assign m_axi_wlast  = m_axi_wlast_reg;

always @(posedge clk) begin
    m_axi_wvalid_reg <= m_axi_wvalid_reg && !m_axi_wready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

    if (!out_fifo_full && m_axi_wvalid_int) begin
        out_fifo_wdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wdata_int;
        out_fifo_wstrb[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wstrb_int;
        out_fifo_wlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axi_wlast_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axi_wvalid_reg || m_axi_wready)) begin
        m_axi_wdata_reg <= out_fifo_wdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wstrb_reg <= out_fifo_wstrb[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wlast_reg <= out_fifo_wlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axi_wvalid_reg <= 1'b1;
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= 0;
        out_fifo_rd_ptr_reg <= 0;
        m_axi_wvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
