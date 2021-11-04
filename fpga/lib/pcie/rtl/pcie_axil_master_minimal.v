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
 * PCIe AXI Lite Master (minimal version, supports only aligned, 1 DW operations)
 */
module pcie_axil_master_minimal #
(
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = 256,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 64,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Force 64 bit address
    parameter TLP_FORCE_64_BIT_ADDR = 0
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * TLP input (request)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_eop,
    output wire                                         rx_req_tlp_ready,

    /*
     * TLP output (completion)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  tx_cpl_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  tx_cpl_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_eop,
    input  wire                                         tx_cpl_tlp_ready,

    /*
     * AXI Lite Master output
     */
    output wire [AXIL_ADDR_WIDTH-1:0]                   m_axil_awaddr,
    output wire [2:0]                                   m_axil_awprot,
    output wire                                         m_axil_awvalid,
    input  wire                                         m_axil_awready,
    output wire [AXIL_DATA_WIDTH-1:0]                   m_axil_wdata,
    output wire [AXIL_STRB_WIDTH-1:0]                   m_axil_wstrb,
    output wire                                         m_axil_wvalid,
    input  wire                                         m_axil_wready,
    input  wire [1:0]                                   m_axil_bresp,
    input  wire                                         m_axil_bvalid,
    output wire                                         m_axil_bready,
    output wire [AXIL_ADDR_WIDTH-1:0]                   m_axil_araddr,
    output wire [2:0]                                   m_axil_arprot,
    output wire                                         m_axil_arvalid,
    input  wire                                         m_axil_arready,
    input  wire [AXIL_DATA_WIDTH-1:0]                   m_axil_rdata,
    input  wire [1:0]                                   m_axil_rresp,
    input  wire                                         m_axil_rvalid,
    output wire                                         m_axil_rready,

    /*
     * Configuration
     */
    input  wire [15:0]                                  completer_id,

    /*
     * Status
     */
    output wire                                         status_error_cor,
    output wire                                         status_error_uncor
);

parameter TLP_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH;
parameter TLP_STRB_WIDTH = TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH;
parameter TLP_DATA_WIDTH_BYTES = TLP_DATA_WIDTH/8;
parameter TLP_DATA_WIDTH_DWORDS = TLP_DATA_WIDTH/32;

parameter RESP_FIFO_ADDR_WIDTH = 5;

// bus width assertions
initial begin
    if (TLP_SEG_COUNT != 1) begin
        $error("Error: TLP segment count must be 1 (instance %m)");
        $finish;
    end

    if (TLP_SEG_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end

    if (TLP_STRB_WIDTH*32 != TLP_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIL_DATA_WIDTH != 32) begin
        $error("Error: AXI lite interface width must be 32 (instance %m)");
        $finish;
    end

    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: AXI lite interface requires byte (8-bit) granularity (instance %m)");
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

localparam [0:0]
    REQ_STATE_IDLE = 1'd0,
    REQ_STATE_WAIT_END = 1'd1;

reg [0:0] req_state_reg = REQ_STATE_IDLE, req_state_next;

localparam [1:0]
    RESP_STATE_IDLE = 2'd0,
    RESP_STATE_READ = 2'd1,
    RESP_STATE_WRITE = 2'd2,
    RESP_STATE_CPL = 2'd3;

reg [1:0] resp_state_reg = RESP_STATE_IDLE, resp_state_next;

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

reg [127:0] cpl_tlp_hdr;

reg [RESP_FIFO_ADDR_WIDTH+1-1:0] resp_fifo_wr_ptr_reg = 0;
reg [RESP_FIFO_ADDR_WIDTH+1-1:0] resp_fifo_rd_ptr_reg = 0, resp_fifo_rd_ptr_next;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg resp_fifo_op_read[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg resp_fifo_op_write[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [2:0] resp_fifo_cpl_status[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [2:0] resp_fifo_byte_count[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [6:0] resp_fifo_lower_addr[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [15:0] resp_fifo_requester_id[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [9:0] resp_fifo_tag[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [2:0] resp_fifo_tc[(2**RESP_FIFO_ADDR_WIDTH)-1:0];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [2:0] resp_fifo_attr[(2**RESP_FIFO_ADDR_WIDTH)-1:0];

reg resp_fifo_wr_op_read;
reg resp_fifo_wr_op_write;
reg [2:0] resp_fifo_wr_cpl_status;
reg [2:0] resp_fifo_wr_byte_count;
reg [6:0] resp_fifo_wr_lower_addr;
reg [15:0] resp_fifo_wr_requester_id;
reg [9:0] resp_fifo_wr_tag;
reg [2:0] resp_fifo_wr_tc;
reg [2:0] resp_fifo_wr_attr;
reg resp_fifo_we;
reg resp_fifo_half_full_reg = 1'b0;

reg resp_fifo_rd_op_read_reg = 1'b0, resp_fifo_rd_op_read_next;
reg resp_fifo_rd_op_write_reg = 1'b0, resp_fifo_rd_op_write_next;
reg [2:0] resp_fifo_rd_cpl_status_reg = CPL_STATUS_SC, resp_fifo_rd_cpl_status_next;
reg [2:0] resp_fifo_rd_byte_count_reg = 3'd0, resp_fifo_rd_byte_count_next;
reg [6:0] resp_fifo_rd_lower_addr_reg = 7'd0, resp_fifo_rd_lower_addr_next;
reg [15:0] resp_fifo_rd_requester_id_reg = 16'd0, resp_fifo_rd_requester_id_next;
reg [9:0] resp_fifo_rd_tag_reg = 10'd0, resp_fifo_rd_tag_next;
reg [2:0] resp_fifo_rd_tc_reg = 3'd0, resp_fifo_rd_tc_next;
reg [2:0] resp_fifo_rd_attr_reg = 3'd0, resp_fifo_rd_attr_next;
reg resp_fifo_rd_valid_reg = 1'b0, resp_fifo_rd_valid_next;

reg rx_req_tlp_ready_reg = 1'b0, rx_req_tlp_ready_next;

reg [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0] tx_cpl_tlp_data_reg = 0, tx_cpl_tlp_data_next;
reg [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0] tx_cpl_tlp_strb_reg = 0, tx_cpl_tlp_strb_next;
reg [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0] tx_cpl_tlp_hdr_reg = 0, tx_cpl_tlp_hdr_next;
reg [TLP_SEG_COUNT-1:0] tx_cpl_tlp_valid_reg = 0, tx_cpl_tlp_valid_next;

reg [AXIL_ADDR_WIDTH-1:0] m_axil_addr_reg = {AXIL_ADDR_WIDTH{1'b0}}, m_axil_addr_next;
reg m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
reg [AXIL_DATA_WIDTH-1:0] m_axil_wdata_reg = {AXIL_DATA_WIDTH{1'b0}}, m_axil_wdata_next;
reg [AXIL_STRB_WIDTH-1:0] m_axil_wstrb_reg = {AXIL_STRB_WIDTH{1'b0}}, m_axil_wstrb_next;
reg m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
reg m_axil_bready_reg = 1'b0, m_axil_bready_next;
reg m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
reg m_axil_rready_reg = 1'b0, m_axil_rready_next;

reg status_error_cor_reg = 1'b0, status_error_cor_next;
reg status_error_uncor_reg = 1'b0, status_error_uncor_next;

assign rx_req_tlp_ready = rx_req_tlp_ready_reg;

assign tx_cpl_tlp_data = tx_cpl_tlp_data_reg;
assign tx_cpl_tlp_strb = tx_cpl_tlp_strb_reg;
assign tx_cpl_tlp_hdr = tx_cpl_tlp_hdr_reg;
assign tx_cpl_tlp_valid = tx_cpl_tlp_valid_reg;
assign tx_cpl_tlp_sop = 1'b1;
assign tx_cpl_tlp_eop = 1'b1;

assign m_axil_awaddr = m_axil_addr_reg;
assign m_axil_awprot = 3'b010;
assign m_axil_awvalid = m_axil_awvalid_reg;
assign m_axil_wdata = m_axil_wdata_reg;
assign m_axil_wstrb = m_axil_wstrb_reg;
assign m_axil_wvalid = m_axil_wvalid_reg;
assign m_axil_bready = m_axil_bready_reg;
assign m_axil_araddr = m_axil_addr_reg;
assign m_axil_arprot = 3'b010;
assign m_axil_arvalid = m_axil_arvalid_reg;
assign m_axil_rready = m_axil_rready_reg;

assign status_error_cor = status_error_cor_reg;
assign status_error_uncor = status_error_uncor_reg;

always @* begin
    req_state_next = REQ_STATE_IDLE;

    rx_req_tlp_ready_next = 1'b0;

    m_axil_addr_next = m_axil_addr_reg;
    m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_awready;
    m_axil_wdata_next = m_axil_wdata_reg;
    m_axil_wstrb_next = m_axil_wstrb_reg;
    m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wready;
    m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_arready;

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

    resp_fifo_wr_op_read = 1'b0;
    resp_fifo_wr_op_write = 1'b0;
    resp_fifo_wr_cpl_status = CPL_STATUS_SC;
    resp_fifo_wr_byte_count = 3'd0;
    resp_fifo_wr_lower_addr = 7'd0;
    resp_fifo_wr_requester_id = rx_req_tlp_hdr_requester_id;
    resp_fifo_wr_tag = rx_req_tlp_hdr_tag;
    resp_fifo_wr_tc = rx_req_tlp_hdr_tc;
    resp_fifo_wr_attr = rx_req_tlp_hdr_attr;
    resp_fifo_we = 1'b0;

    case (req_state_reg)
        REQ_STATE_IDLE: begin
            // idle state; wait for request

            rx_req_tlp_ready_next = (!m_axil_awvalid_reg || m_axil_awready)
                && (!m_axil_arvalid_reg || m_axil_arready)
                && (!m_axil_wvalid_reg || m_axil_wready)
                && !resp_fifo_half_full_reg;

            if (rx_req_tlp_ready && rx_req_tlp_valid && rx_req_tlp_sop) begin
                m_axil_addr_next = rx_req_tlp_hdr_addr;
                m_axil_wdata_next = rx_req_tlp_data[31:0];
                m_axil_wstrb_next = rx_req_tlp_hdr_first_be;

                if (!rx_req_tlp_hdr_fmt[1] && rx_req_tlp_hdr_type == 5'b00000) begin
                    // read request
                    if (rx_req_tlp_hdr_length == 11'd1) begin
                        // length OK

                        // perform read
                        m_axil_arvalid_next = 1'b1;

                        // finish read and return completion
                        resp_fifo_wr_op_read = 1'b1;
                        resp_fifo_wr_op_write = 1'b0;
                        resp_fifo_wr_cpl_status = CPL_STATUS_SC;

                        casez (rx_req_tlp_hdr_first_be)
                            4'b0000: resp_fifo_wr_byte_count = 3'd1;
                            4'b0001: resp_fifo_wr_byte_count = 3'd1;
                            4'b0010: resp_fifo_wr_byte_count = 3'd1;
                            4'b0100: resp_fifo_wr_byte_count = 3'd1;
                            4'b1000: resp_fifo_wr_byte_count = 3'd1;
                            4'b0011: resp_fifo_wr_byte_count = 3'd2;
                            4'b0110: resp_fifo_wr_byte_count = 3'd2;
                            4'b1100: resp_fifo_wr_byte_count = 3'd2;
                            4'b01z1: resp_fifo_wr_byte_count = 3'd3;
                            4'b1z10: resp_fifo_wr_byte_count = 3'd3;
                            4'b1zz1: resp_fifo_wr_byte_count = 3'd4;
                        endcase

                        casez (rx_req_tlp_hdr_first_be)
                            4'b0000: resp_fifo_wr_lower_addr = {rx_req_tlp_hdr_addr[6:2], 2'b00};
                            4'bzzz1: resp_fifo_wr_lower_addr = {rx_req_tlp_hdr_addr[6:2], 2'b00};
                            4'bzz10: resp_fifo_wr_lower_addr = {rx_req_tlp_hdr_addr[6:2], 2'b01};
                            4'bz100: resp_fifo_wr_lower_addr = {rx_req_tlp_hdr_addr[6:2], 2'b10};
                            4'b1000: resp_fifo_wr_lower_addr = {rx_req_tlp_hdr_addr[6:2], 2'b11};
                        endcase

                        rx_req_tlp_ready_next = 1'b0;
                    end else begin
                        // bad length
                        // report correctable error
                        status_error_cor_next = 1'b1;

                        // return CA completion
                        resp_fifo_wr_op_read = 1'b0;
                        resp_fifo_wr_op_write = 1'b0;
                        resp_fifo_wr_cpl_status = CPL_STATUS_CA;
                        resp_fifo_wr_byte_count = 3'd0;
                        resp_fifo_wr_lower_addr = 7'd0;
                    end

                    resp_fifo_wr_requester_id = rx_req_tlp_hdr_requester_id;
                    resp_fifo_wr_tag = rx_req_tlp_hdr_tag;
                    resp_fifo_wr_tc = rx_req_tlp_hdr_tc;
                    resp_fifo_wr_attr = rx_req_tlp_hdr_attr;
                    resp_fifo_we = 1'b1;

                    if (rx_req_tlp_eop) begin
                        req_state_next = REQ_STATE_IDLE;
                    end else begin
                        rx_req_tlp_ready_next = 1'b1;
                        req_state_next = REQ_STATE_WAIT_END;
                    end
                end else if (rx_req_tlp_hdr_fmt[1] && rx_req_tlp_hdr_type == 5'b00000) begin
                    // write request
                    if (rx_req_tlp_hdr_length == 11'd1) begin
                        // length OK

                        // perform write
                        m_axil_awvalid_next = 1'b1;
                        m_axil_wvalid_next = 1'b1;

                        // entry in FIFO for proper response ordering
                        resp_fifo_wr_op_read = 1'b0;
                        resp_fifo_wr_op_write = 1'b1;
                        resp_fifo_we = 1'b1;

                        rx_req_tlp_ready_next = 1'b0;
                    end else begin
                        // bad length
                        // report uncorrectable error
                        status_error_uncor_next = 1'b1;
                    end

                    if (rx_req_tlp_eop) begin
                        req_state_next = REQ_STATE_IDLE;
                    end else begin
                        rx_req_tlp_ready_next = 1'b1;
                        req_state_next = REQ_STATE_WAIT_END;
                    end
                end else begin
                    // other request
                    if (rx_req_tlp_hdr_fmt[0] && rx_req_tlp_hdr_type & 5'b11000 == 5'b10000) begin
                        // message - posted, no completion
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
                        resp_fifo_wr_op_read = 1'b0;
                        resp_fifo_wr_op_write = 1'b0;
                        resp_fifo_wr_cpl_status = CPL_STATUS_UR;
                        resp_fifo_wr_byte_count = 3'd0;
                        resp_fifo_wr_lower_addr = 7'd0;
                        resp_fifo_wr_requester_id = rx_req_tlp_hdr_requester_id;
                        resp_fifo_wr_tag = rx_req_tlp_hdr_tag;
                        resp_fifo_wr_tc = rx_req_tlp_hdr_tc;
                        resp_fifo_wr_attr = rx_req_tlp_hdr_attr;
                        resp_fifo_we = 1'b1;
                    end

                    if (rx_req_tlp_eop) begin
                        req_state_next = REQ_STATE_IDLE;
                    end else begin
                        rx_req_tlp_ready_next = 1'b1;
                        req_state_next = REQ_STATE_WAIT_END;
                    end
                end
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            rx_req_tlp_ready_next = 1'b1;

            if (rx_req_tlp_ready && rx_req_tlp_valid) begin
                if (rx_req_tlp_eop) begin

                    rx_req_tlp_ready_next = (!m_axil_awvalid_reg || m_axil_awready)
                        && (!m_axil_arvalid_reg || m_axil_arready)
                        && (!m_axil_wvalid_reg || m_axil_wready)
                        && !resp_fifo_half_full_reg;

                    req_state_next = REQ_STATE_IDLE;
                end else begin
                    req_state_next = REQ_STATE_WAIT_END;
                end
            end else begin
                req_state_next = REQ_STATE_WAIT_END;
            end
        end
    endcase
end

always @* begin
    resp_state_next = RESP_STATE_IDLE;

    resp_fifo_rd_ptr_next = resp_fifo_rd_ptr_reg;

    resp_fifo_rd_op_read_next = resp_fifo_rd_op_read_reg;
    resp_fifo_rd_op_write_next = resp_fifo_rd_op_write_reg;
    resp_fifo_rd_cpl_status_next = resp_fifo_rd_cpl_status_reg;
    resp_fifo_rd_byte_count_next = resp_fifo_rd_byte_count_reg;
    resp_fifo_rd_lower_addr_next = resp_fifo_rd_lower_addr_reg;
    resp_fifo_rd_requester_id_next = resp_fifo_rd_requester_id_reg;
    resp_fifo_rd_tag_next = resp_fifo_rd_tag_reg;
    resp_fifo_rd_tc_next = resp_fifo_rd_tc_reg;
    resp_fifo_rd_attr_next = resp_fifo_rd_attr_reg;
    resp_fifo_rd_valid_next = resp_fifo_rd_valid_reg;

    tx_cpl_tlp_data_next = tx_cpl_tlp_data_reg;
    tx_cpl_tlp_strb_next = tx_cpl_tlp_strb_reg;
    tx_cpl_tlp_hdr_next = tx_cpl_tlp_hdr_reg;
    tx_cpl_tlp_valid_next = tx_cpl_tlp_valid_reg && !tx_cpl_tlp_ready;

    m_axil_bready_next = 1'b0;
    m_axil_rready_next = 1'b0;

    // TLP header
    // DW 0
    cpl_tlp_hdr[127:125] = resp_fifo_rd_op_read_reg ? TLP_FMT_3DW_DATA : TLP_FMT_3DW; // fmt
    cpl_tlp_hdr[124:120] = 5'b01010; // type
    cpl_tlp_hdr[119] = resp_fifo_rd_tag_reg[9]; // T9
    cpl_tlp_hdr[118:116] = resp_fifo_rd_tc_reg; // TC
    cpl_tlp_hdr[115] = resp_fifo_rd_tag_reg[8]; // T8
    cpl_tlp_hdr[114] = resp_fifo_rd_attr_reg[2]; // attr
    cpl_tlp_hdr[113] = 1'b0; // LN
    cpl_tlp_hdr[112] = 1'b0; // TH
    cpl_tlp_hdr[111] = 1'b0; // TD
    cpl_tlp_hdr[110] = 1'b0; // EP
    cpl_tlp_hdr[109:108] = resp_fifo_rd_attr_reg[1:0]; // attr
    cpl_tlp_hdr[107:106] = 2'b00; // AT
    cpl_tlp_hdr[105:96] = resp_fifo_rd_op_read_reg ? 1 : 0; // length
    // DW 1
    cpl_tlp_hdr[95:80] = completer_id; // completer ID
    cpl_tlp_hdr[79:77] = resp_fifo_rd_cpl_status_reg; // completion status
    cpl_tlp_hdr[76] = 1'b0; // BCM
    cpl_tlp_hdr[75:64] = resp_fifo_rd_byte_count_reg; // byte count
    // DW 2
    cpl_tlp_hdr[63:48] = resp_fifo_rd_requester_id_reg; // requester ID
    cpl_tlp_hdr[47:40] = resp_fifo_rd_tag_reg[7:0]; // tag
    cpl_tlp_hdr[39] = 1'b0;
    cpl_tlp_hdr[38:32] = resp_fifo_rd_lower_addr_reg; // lower address
    cpl_tlp_hdr[31:0] = 32'd0;

    case (resp_state_reg)
        RESP_STATE_IDLE: begin
            // idle state - wait for operation

            if (resp_fifo_rd_valid_reg) begin
                if (resp_fifo_rd_op_read_reg) begin
                    m_axil_rready_next = !tx_cpl_tlp_valid_reg || tx_cpl_tlp_ready;
                    resp_state_next = RESP_STATE_READ;
                end else if (resp_fifo_rd_op_write_reg) begin
                    m_axil_bready_next = 1'b1;
                    resp_state_next = RESP_STATE_WRITE;
                end else begin
                    resp_state_next = RESP_STATE_CPL;
                end
            end else begin
                resp_state_next = RESP_STATE_IDLE;
            end
        end
        RESP_STATE_READ: begin
            // read state - wait for read data and generate completion
            m_axil_rready_next = !tx_cpl_tlp_valid_reg || tx_cpl_tlp_ready;

            if (m_axil_rready && m_axil_rvalid) begin
                m_axil_rready_next = 1'b0;
                tx_cpl_tlp_hdr_next = cpl_tlp_hdr;
                tx_cpl_tlp_data_next = m_axil_rdata;
                tx_cpl_tlp_strb_next = 1;
                tx_cpl_tlp_valid_next = 1'b1;

                resp_fifo_rd_valid_next = 1'b0;
                resp_state_next = RESP_STATE_IDLE;
            end else begin
                resp_state_next = RESP_STATE_READ;
            end
        end
        RESP_STATE_WRITE: begin
            // write state - wait for write response
            m_axil_bready_next = 1'b1;

            if (m_axil_bready && m_axil_bvalid) begin
                m_axil_bready_next = 1'b0;

                resp_fifo_rd_valid_next = 1'b0;
                resp_state_next = RESP_STATE_IDLE;
            end else begin
                resp_state_next = RESP_STATE_WRITE;
            end
        end
        RESP_STATE_CPL: begin
            // completion state - generate completion

            if (!tx_cpl_tlp_valid_reg || tx_cpl_tlp_ready) begin
                tx_cpl_tlp_hdr_next = cpl_tlp_hdr;
                tx_cpl_tlp_data_next = 0;
                tx_cpl_tlp_strb_next = 0;
                tx_cpl_tlp_valid_next = 1'b1;

                resp_fifo_rd_valid_next = 1'b0;
                resp_state_next = RESP_STATE_IDLE;
            end else begin
                resp_state_next = RESP_STATE_CPL;
            end
        end
    endcase

    if (!resp_fifo_rd_valid_next && resp_fifo_rd_ptr_reg != resp_fifo_wr_ptr_reg) begin
        resp_fifo_rd_op_read_next = resp_fifo_op_read[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_op_write_next = resp_fifo_op_write[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_cpl_status_next = resp_fifo_cpl_status[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_byte_count_next = resp_fifo_byte_count[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_lower_addr_next = resp_fifo_lower_addr[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_requester_id_next = resp_fifo_requester_id[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_tag_next = resp_fifo_tag[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_tc_next = resp_fifo_tc[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_attr_next = resp_fifo_attr[resp_fifo_rd_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]];
        resp_fifo_rd_ptr_next = resp_fifo_rd_ptr_reg + 1;
        resp_fifo_rd_valid_next = 1'b1;
    end
end

always @(posedge clk) begin
    req_state_reg <= req_state_next;
    resp_state_reg <= resp_state_next;

    rx_req_tlp_ready_reg <= rx_req_tlp_ready_next;

    tx_cpl_tlp_data_reg <= tx_cpl_tlp_data_next;
    tx_cpl_tlp_strb_reg <= tx_cpl_tlp_strb_next;
    tx_cpl_tlp_hdr_reg <= tx_cpl_tlp_hdr_next;
    tx_cpl_tlp_valid_reg <= tx_cpl_tlp_valid_next;

    m_axil_addr_reg <= m_axil_addr_next;
    m_axil_awvalid_reg <= m_axil_awvalid_next;
    m_axil_wdata_reg <= m_axil_wdata_next;
    m_axil_wstrb_reg <= m_axil_wstrb_next;
    m_axil_wvalid_reg <= m_axil_wvalid_next;
    m_axil_bready_reg <= m_axil_bready_next;
    m_axil_arvalid_reg <= m_axil_arvalid_next;
    m_axil_rready_reg <= m_axil_rready_next;

    status_error_cor_reg <= status_error_cor_next;
    status_error_uncor_reg <= status_error_uncor_next;

    if (resp_fifo_we) begin
        resp_fifo_op_read[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_op_read;
        resp_fifo_op_write[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_op_write;
        resp_fifo_cpl_status[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_cpl_status;
        resp_fifo_byte_count[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_byte_count;
        resp_fifo_lower_addr[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_lower_addr;
        resp_fifo_requester_id[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_requester_id;
        resp_fifo_tag[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_tag;
        resp_fifo_tc[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_tc;
        resp_fifo_attr[resp_fifo_wr_ptr_reg[RESP_FIFO_ADDR_WIDTH-1:0]] <= resp_fifo_wr_attr;
        resp_fifo_wr_ptr_reg <= resp_fifo_wr_ptr_reg + 1;
    end
    resp_fifo_rd_ptr_reg <= resp_fifo_rd_ptr_next;

    resp_fifo_rd_op_read_reg <= resp_fifo_rd_op_read_next;
    resp_fifo_rd_op_write_reg <= resp_fifo_rd_op_write_next;
    resp_fifo_rd_cpl_status_reg <= resp_fifo_rd_cpl_status_next;
    resp_fifo_rd_byte_count_reg <= resp_fifo_rd_byte_count_next;
    resp_fifo_rd_lower_addr_reg <= resp_fifo_rd_lower_addr_next;
    resp_fifo_rd_requester_id_reg <= resp_fifo_rd_requester_id_next;
    resp_fifo_rd_tag_reg <= resp_fifo_rd_tag_next;
    resp_fifo_rd_tc_reg <= resp_fifo_rd_tc_next;
    resp_fifo_rd_attr_reg <= resp_fifo_rd_attr_next;
    resp_fifo_rd_valid_reg <= resp_fifo_rd_valid_next;

    resp_fifo_half_full_reg <= $unsigned(resp_fifo_wr_ptr_reg - resp_fifo_rd_ptr_reg) >= 2**(RESP_FIFO_ADDR_WIDTH-1);

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        resp_state_reg <= RESP_STATE_IDLE;

        rx_req_tlp_ready_reg <= 1'b0;

        tx_cpl_tlp_valid_reg <= 1'b0;

        m_axil_awvalid_reg <= 1'b0;
        m_axil_wvalid_reg <= 1'b0;
        m_axil_bready_reg <= 1'b0;
        m_axil_arvalid_reg <= 1'b0;
        m_axil_rready_reg <= 1'b0;

        status_error_cor_reg <= 1'b0;
        status_error_uncor_reg <= 1'b0;

        resp_fifo_wr_ptr_reg <= 0;
        resp_fifo_rd_ptr_reg <= 0;
        resp_fifo_rd_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
