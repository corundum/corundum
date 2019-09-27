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
 * Ultrascale PCIe AXI Master (read)
 */
module pcie_us_axi_master_rd #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream CQ tuser signal width
    parameter AXIS_PCIE_CQ_USER_WIDTH = 85,
    // PCIe AXI stream CC tuser signal width
    parameter AXIS_PCIE_CC_USER_WIDTH = 33,
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 64,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256
)
(
    input  wire                               clk,
    input  wire                               rst,

    /*
     * AXI input (CQ)
     */
    input  wire [AXIS_PCIE_DATA_WIDTH-1:0]    s_axis_cq_tdata,
    input  wire [AXIS_PCIE_KEEP_WIDTH-1:0]    s_axis_cq_tkeep,
    input  wire                               s_axis_cq_tvalid,
    output wire                               s_axis_cq_tready,
    input  wire                               s_axis_cq_tlast,
    input  wire [AXIS_PCIE_CQ_USER_WIDTH-1:0] s_axis_cq_tuser,

    /*
     * AXI output (CC)
     */
    output wire [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata,
    output wire [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep,
    output wire                               m_axis_cc_tvalid,
    input  wire                               m_axis_cc_tready,
    output wire                               m_axis_cc_tlast,
    output wire [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser,

    /*
     * AXI master interface
     */
    output wire [AXI_ID_WIDTH-1:0]            m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axi_araddr,
    output wire [7:0]                         m_axi_arlen,
    output wire [2:0]                         m_axi_arsize,
    output wire [1:0]                         m_axi_arburst,
    output wire                               m_axi_arlock,
    output wire [3:0]                         m_axi_arcache,
    output wire [2:0]                         m_axi_arprot,
    output wire                               m_axi_arvalid,
    input  wire                               m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]            m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]          m_axi_rdata,
    input  wire [1:0]                         m_axi_rresp,
    input  wire                               m_axi_rlast,
    input  wire                               m_axi_rvalid,
    output wire                               m_axi_rready,

    /*
     * Configuration
     */
    input  wire [15:0]                        completer_id,
    input  wire                               completer_id_enable,
    input  wire [2:0]                         max_payload_size,

    /*
     * Status
     */
    output wire                               status_error_cor,
    output wire                               status_error_uncor
);

parameter PCIE_ADDR_WIDTH = 64;

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN*AXI_WORD_WIDTH;

parameter AXIS_PCIE_WORD_WIDTH = AXIS_PCIE_KEEP_WIDTH;
parameter AXIS_PCIE_WORD_SIZE = AXIS_PCIE_DATA_WIDTH/AXIS_PCIE_WORD_WIDTH;

parameter OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH/32);

// bus width assertions
initial begin
    if (AXIS_PCIE_DATA_WIDTH != 64 && AXIS_PCIE_DATA_WIDTH != 128 && AXIS_PCIE_DATA_WIDTH != 256) begin
        $error("Error: PCIe interface width must be 64, 128, or 256 (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_KEEP_WIDTH * 32 != AXIS_PCIE_DATA_WIDTH) begin
        $error("Error: PCIe interface requires dword (32-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_CQ_USER_WIDTH != 85) begin
        $error("Error: PCIe CQ tuser width must be 85 (instance %m)");
        $finish;
    end

    if (AXIS_PCIE_CC_USER_WIDTH != 33) begin
        $error("Error: PCIe CC tuser width must be 33 (instance %m)");
        $finish;
    end

    if (AXI_DATA_WIDTH != AXIS_PCIE_DATA_WIDTH) begin
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

localparam [2:0]
    CPL_STATUS_SC  = 3'b000, // successful completion
    CPL_STATUS_UR  = 3'b001, // unsupported request
    CPL_STATUS_CRS = 3'b010, // configuration request retry status
    CPL_STATUS_CA  = 3'b100; // completer abort

localparam [2:0]
    AXI_STATE_IDLE = 3'd0,
    AXI_STATE_HEADER = 3'd1,
    AXI_STATE_START = 3'd2,
    AXI_STATE_REQ = 3'd3,
    AXI_STATE_WAIT_END = 3'd4;

reg [2:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

localparam [2:0]
    TLP_STATE_IDLE = 3'd0,
    TLP_STATE_HEADER_1 = 3'd1,
    TLP_STATE_HEADER_2 = 3'd2,
    TLP_STATE_TRANSFER = 3'd3,
    TLP_STATE_CPL_1 = 3'd4,
    TLP_STATE_CPL_2 = 3'd5;

reg [2:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

// datapath control signals
reg transfer_in_save;

reg tlp_cmd_ready;

reg [1:0] first_be_offset;
reg [1:0] last_be_offset;
reg [2:0] single_dword_len;

reg [PCIE_ADDR_WIDTH-1:0] pcie_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, pcie_addr_next;
reg [AXI_ADDR_WIDTH-1:0] axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, axi_addr_next;
reg [12:0] op_count_reg = 13'd0, op_count_next;
reg [10:0] op_dword_count_reg = 11'd0, op_dword_count_next;
reg [10:0] tr_dword_count_reg = 11'd0, tr_dword_count_next;
reg [10:0] tlp_dword_count_reg = 11'd0, tlp_dword_count_next;
reg [3:0] first_be_reg = 4'd0, first_be_next;
reg [3:0] last_be_reg = 4'd0, last_be_next;

reg [1:0] at_reg = 2'd0, at_next;
reg [PCIE_ADDR_WIDTH-1:0] tlp_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, tlp_addr_next;
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
reg [7:0] tag_reg = 8'd0, tag_next;
reg [2:0] tc_reg = 3'd0, tc_next;
reg [2:0] attr_reg = 3'd0, attr_next;

reg [1:0] tlp_cmd_at_reg = 2'd0, tlp_cmd_at_next;
reg [PCIE_ADDR_WIDTH-1:0] tlp_cmd_addr_reg = {PCIE_ADDR_WIDTH{1'b0}}, tlp_cmd_addr_next;
reg [12:0] tlp_cmd_byte_len_reg = 13'd0, tlp_cmd_byte_len_next;
reg [10:0] tlp_cmd_dword_len_reg = 11'd0, tlp_cmd_dword_len_next;
reg [9:0] tlp_cmd_input_cycle_len_reg = 10'd0, tlp_cmd_input_cycle_len_next;
reg [9:0] tlp_cmd_output_cycle_len_reg = 10'd0, tlp_cmd_output_cycle_len_next;
reg [OFFSET_WIDTH-1:0] tlp_cmd_offset_reg = {OFFSET_WIDTH{1'b0}}, tlp_cmd_offset_next;
reg [2:0] tlp_cmd_status_reg = 3'd0, tlp_cmd_status_next;
reg [15:0] tlp_cmd_requester_id_reg = 16'd0, tlp_cmd_requester_id_next;
reg [7:0] tlp_cmd_tag_reg = 8'd0, tlp_cmd_tag_next;
reg [2:0] tlp_cmd_tc_reg = 3'd0, tlp_cmd_tc_next;
reg [2:0] tlp_cmd_attr_reg = 3'd0, tlp_cmd_attr_next;
reg tlp_cmd_bubble_cycle_reg = 1'b0, tlp_cmd_bubble_cycle_next;
reg tlp_cmd_last_reg = 1'b0, tlp_cmd_last_next;
reg tlp_cmd_valid_reg = 1'b0, tlp_cmd_valid_next;

reg [10:0] max_payload_size_dw_reg = 11'd0;

reg s_axis_cq_tready_reg = 1'b0, s_axis_cq_tready_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
reg m_axi_rready_reg = 1'b0, m_axi_rready_next;

reg [AXI_DATA_WIDTH-1:0] save_axi_rdata_reg = {AXI_DATA_WIDTH{1'b0}};

wire [AXI_DATA_WIDTH-1:0] shift_axi_rdata = {m_axi_rdata, save_axi_rdata_reg} >> ((AXI_STRB_WIDTH/4-offset_reg)*32);

reg status_error_cor_reg = 1'b0, status_error_cor_next;
reg status_error_uncor_reg = 1'b0, status_error_uncor_next;

// internal datapath
reg  [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata_int;
reg  [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep_int;
reg                                m_axis_cc_tvalid_int;
reg                                m_axis_cc_tready_int_reg = 1'b0;
reg                                m_axis_cc_tlast_int;
reg  [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser_int;
wire                               m_axis_cc_tready_int_early;

assign s_axis_cq_tready = s_axis_cq_tready_reg;

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
    casez (first_be_next)
        4'b0000: single_dword_len = 3'd0;
        4'b0001: single_dword_len = 3'd1;
        4'b0010: single_dword_len = 3'd1;
        4'b0100: single_dword_len = 3'd1;
        4'b1000: single_dword_len = 3'd1;
        4'b0011: single_dword_len = 3'd2;
        4'b0110: single_dword_len = 3'd2;
        4'b1100: single_dword_len = 3'd2;
        4'b01z1: single_dword_len = 3'd3;
        4'b1z10: single_dword_len = 3'd3;
        4'b1zz1: single_dword_len = 3'd4;
    endcase

    casez (first_be_next)
        4'b0000: first_be_offset = 2'b00;
        4'bzzz1: first_be_offset = 2'b00;
        4'bzz10: first_be_offset = 2'b01;
        4'bz100: first_be_offset = 2'b10;
        4'b1000: first_be_offset = 2'b11;
    endcase

    casez (last_be_next)
        4'b0000: last_be_offset = 2'b00;
        4'b1zzz: last_be_offset = 2'b00;
        4'b01zz: last_be_offset = 2'b01;
        4'b001z: last_be_offset = 2'b10;
        4'b0001: last_be_offset = 2'b11;
    endcase
end

always @* begin
    axi_state_next = AXI_STATE_IDLE;

    s_axis_cq_tready_next = 1'b0;

    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;

    pcie_addr_next = pcie_addr_reg;
    axi_addr_next = axi_addr_reg;
    op_count_next = op_count_reg;
    op_dword_count_next = op_dword_count_reg;
    tr_dword_count_next = tr_dword_count_reg;
    tlp_dword_count_next = tlp_dword_count_reg;
    first_be_next = first_be_reg;
    last_be_next = last_be_reg;

    tlp_cmd_at_next = tlp_cmd_at_reg;
    tlp_cmd_addr_next = tlp_cmd_addr_reg;
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

    // TLP segmentation and AXI read request generation
    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state, wait for completion request
            s_axis_cq_tready_next = !tlp_cmd_valid_reg;

            if (s_axis_cq_tready & s_axis_cq_tvalid) begin
                // header fields
                tlp_cmd_at_next = s_axis_cq_tdata[1:0];
                pcie_addr_next = {s_axis_cq_tdata[63:2], first_be_offset};
                tlp_cmd_status_next = CPL_STATUS_SC; // successful completion
                if (AXIS_PCIE_DATA_WIDTH > 64) begin
                    op_dword_count_next = s_axis_cq_tdata[74:64];
                    if (op_dword_count_next == 1) begin
                        op_count_next = single_dword_len;
                    end else begin
                        op_count_next = (op_dword_count_next << 2) - first_be_offset - last_be_offset;
                    end
                    tlp_cmd_requester_id_next = s_axis_cq_tdata[95:80];
                    tlp_cmd_tag_next = s_axis_cq_tdata[103:96];
                    tlp_cmd_tc_next = s_axis_cq_tdata[123:121];
                    tlp_cmd_attr_next = s_axis_cq_tdata[126:124];
                end

                // tuser fields
                first_be_next = s_axis_cq_tuser[3:0];
                last_be_next = s_axis_cq_tuser[7:4];

                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    // 64 bit interface hasn't processed the whole header yet
                    s_axis_cq_tready_next = 1'b1;
                    if (s_axis_cq_tlast) begin
                        // truncated packet
                        // report uncorrectable error
                        status_error_uncor_next = 1'b1;
                        axi_state_next = AXI_STATE_IDLE;
                    end else begin
                        axi_state_next = AXI_STATE_HEADER;
                    end
                end else begin
                    // processed whole header; check request type
                    if (s_axis_cq_tdata[78:75] == REQ_MEM_READ) begin
                        // read request
                        s_axis_cq_tready_next = 1'b0;
                        axi_state_next = AXI_STATE_START;
                    end else if (s_axis_cq_tdata[78:75] == REQ_MEM_WRITE || (s_axis_cq_tdata[78:75] & 4'b1100) == 4'b1100) begin
                        // posted request (memory write or message), drop and report uncorrectable error
                        status_error_uncor_next = 1'b1;
                        if (s_axis_cq_tlast) begin
                            axi_state_next = AXI_STATE_IDLE;
                        end else begin
                            s_axis_cq_tready_next = 1'b1;
                            axi_state_next = AXI_STATE_WAIT_END;
                        end
                    end else begin
                        // invalid request, send UR completion
                        tlp_cmd_status_next = CPL_STATUS_UR; // unsupported request
                        tlp_cmd_valid_next = 1'b1;
                        // report correctable error
                        status_error_cor_next = 1'b1;
                        if (s_axis_cq_tlast) begin
                            axi_state_next = AXI_STATE_IDLE;
                        end else begin
                            s_axis_cq_tready_next = 1'b1;
                            axi_state_next = AXI_STATE_WAIT_END;
                        end
                    end
                end
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_HEADER: begin
            // header state, store rest of header (64 bit interface only)
            s_axis_cq_tready_next = 1'b1;

            if (s_axis_cq_tready & s_axis_cq_tvalid) begin
                // header fields
                op_dword_count_next = s_axis_cq_tdata[10:0];
                if (op_dword_count_next == 1) begin
                    op_count_next = single_dword_len;
                end else begin
                    op_count_next = (op_dword_count_next << 2) - first_be_offset - last_be_offset;
                end
                tlp_cmd_requester_id_next = s_axis_cq_tdata[31:16];
                tlp_cmd_tag_next = s_axis_cq_tdata[39:32];
                tlp_cmd_tc_next = s_axis_cq_tdata[59:57];
                tlp_cmd_attr_next = s_axis_cq_tdata[62:60];

                // processed whole header; check request type
                if (s_axis_cq_tdata[14:11] == REQ_MEM_READ) begin
                    // read request
                    s_axis_cq_tready_next = 1'b0;
                    axi_state_next = AXI_STATE_START;
                end else if (s_axis_cq_tdata[14:11] == REQ_MEM_WRITE || (s_axis_cq_tdata[14:11] & 4'b1100) == 4'b1100) begin
                    // posted request (memory write or message), drop and report uncorrectable error
                    // write request - drop
                    status_error_uncor_next = 1'b1;
                    if (s_axis_cq_tlast) begin
                        axi_state_next = AXI_STATE_IDLE;
                    end else begin
                        s_axis_cq_tready_next = 1'b1;
                        axi_state_next = AXI_STATE_WAIT_END;
                    end
                end else begin
                    // invalid request, send UR completion
                    tlp_cmd_status_next = CPL_STATUS_UR; // unsupported request
                    tlp_cmd_valid_next = 1'b1;
                    // report correctable error
                    status_error_cor_next = 1'b1;
                    if (s_axis_cq_tlast) begin
                        axi_state_next = AXI_STATE_IDLE;
                    end else begin
                        s_axis_cq_tready_next = 1'b1;
                        axi_state_next = AXI_STATE_WAIT_END;
                    end
                end
            end else begin
                axi_state_next = AXI_STATE_HEADER;
            end
        end
        AXI_STATE_START: begin
            // start state, compute TLP length
            if (!tlp_cmd_valid_reg) begin
                if (op_dword_count_reg <= max_payload_size_dw_reg) begin
                    // packet smaller than max payload size
                    // assumed to not cross 4k boundary, send one TLP
                    tlp_dword_count_next = op_dword_count_reg;
                end else begin
                    // packet larger than max payload size
                    // assumed to not cross 4k boundary, send one TLP, align to 128 byte RCB
                    tlp_dword_count_next = max_payload_size_dw_reg - pcie_addr_reg[6:2];
                end

                // read completion TLP will transfer DWORD count minus offset into first DWORD
                op_count_next = op_count_reg - (tlp_dword_count_next << 2) + pcie_addr_reg[1:0];
                op_dword_count_next = op_dword_count_reg - tlp_dword_count_next;

                // number of bus transfers from AXI, DWORD count plus DWORD offset, divided by bus width in DWORDS
                tlp_cmd_input_cycle_len_next = (tlp_dword_count_next + pcie_addr_reg[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                // number of bus transfers in TLP, DOWRD count plus payload start DWORD offset, divided by bus width in DWORDS
                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    tlp_cmd_output_cycle_len_next = (tlp_dword_count_next + 1 - 1) >> (AXI_BURST_SIZE-2);
                end else begin
                    tlp_cmd_output_cycle_len_next = (tlp_dword_count_next + 3 - 1) >> (AXI_BURST_SIZE-2);
                end

                tlp_cmd_addr_next = pcie_addr_reg;
                tlp_cmd_byte_len_next = op_count_reg;
                tlp_cmd_dword_len_next = tlp_dword_count_next;
                // required DWORD shift to place first DWORD read from AXI into proper position in payload
                // bubble cycle required if first AXI transfer does not fill first payload transfer
                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    tlp_cmd_offset_next = 1-pcie_addr_reg[OFFSET_WIDTH+2-1:2];
                    tlp_cmd_bubble_cycle_next = 1'b0;
                end else begin
                    tlp_cmd_offset_next = 3-pcie_addr_reg[OFFSET_WIDTH+2-1:2];
                    tlp_cmd_bubble_cycle_next = pcie_addr_reg[OFFSET_WIDTH+2-1:2] > 3;
                end
                tlp_cmd_last_next = op_dword_count_next == 0;
                tlp_cmd_valid_next = 1'b1;

                axi_state_next = AXI_STATE_REQ;
            end else begin
                axi_state_next = AXI_STATE_START;
            end
        end
        AXI_STATE_REQ: begin
            // request state, generate AXI read requests
            if (!m_axi_arvalid) begin
                if (tlp_dword_count_reg <= AXI_MAX_BURST_SIZE/4) begin
                    // packet smaller than max burst size
                    // assumed to not cross 4k boundary, send one request
                    tr_dword_count_next = tlp_dword_count_reg;
                end else begin
                    // packet larger than max burst size
                    // assumed to not cross 4k boundary, send one request
                    tr_dword_count_next = AXI_MAX_BURST_SIZE/4 - pcie_addr_reg[OFFSET_WIDTH+2-1:2];
                end

                m_axi_araddr_next = pcie_addr_reg;
                m_axi_arlen_next = (tr_dword_count_next + pcie_addr_reg[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                m_axi_arvalid_next = 1;

                // increment address by transfer size
                pcie_addr_next = pcie_addr_reg + (tr_dword_count_next << 2);
                // first transfer will end on DWORD boundary, so subsequent transfers will be DWORD aligned
                pcie_addr_next[1:0] = 2'b0;
                // keep track of how much more needs to be read to fill the TLP
                tlp_dword_count_next = tlp_dword_count_reg - tr_dword_count_next;

                if (tlp_dword_count_next > 0) begin
                    axi_state_next = AXI_STATE_REQ;
                end else if (op_dword_count_next > 0) begin
                    axi_state_next = AXI_STATE_START;
                end else begin
                    axi_state_next = AXI_STATE_IDLE;
                end
            end else begin
                axi_state_next = AXI_STATE_REQ;
            end
        end
        AXI_STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            s_axis_cq_tready_next = 1'b1;

            if (s_axis_cq_tready & s_axis_cq_tvalid) begin
                if (s_axis_cq_tlast) begin
                    s_axis_cq_tready_next = !tlp_cmd_valid_reg;
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

    at_next = at_reg;
    tlp_addr_next = tlp_addr_reg;
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

    m_axis_cc_tdata_int = {AXIS_PCIE_DATA_WIDTH{1'b0}};
    m_axis_cc_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
    m_axis_cc_tvalid_int = 1'b0;
    m_axis_cc_tlast_int = 1'b0;
    m_axis_cc_tuser_int = {AXIS_PCIE_CC_USER_WIDTH{1'b0}};

    m_axis_cc_tdata_int[6:0] = tlp_addr_reg; // lower address
    m_axis_cc_tdata_int[9:8] = at_reg;
    m_axis_cc_tdata_int[28:16] = tlp_len_reg; // byte count
    m_axis_cc_tdata_int[42:32] = dword_count_reg;
    m_axis_cc_tdata_int[45:43] = status_reg;
    m_axis_cc_tdata_int[63:48] = requester_id_reg;
    if (AXIS_PCIE_DATA_WIDTH > 64) begin
        m_axis_cc_tdata_int[71:64] = tag_reg;
        m_axis_cc_tdata_int[87:72] = completer_id;
        m_axis_cc_tdata_int[88] = completer_id_enable;
        m_axis_cc_tdata_int[91:89] = tc_reg;
        m_axis_cc_tdata_int[94:92] = attr_reg;
        m_axis_cc_tdata_int[95] = 1'b0; // force ECRC
        if (AXIS_PCIE_DATA_WIDTH == 256) begin
            m_axis_cc_tdata_int[255:96] = shift_axi_rdata[255:96];
        end else begin
            m_axis_cc_tdata_int[127:96] = shift_axi_rdata[127:96];
        end
    end

    if (AXIS_PCIE_DATA_WIDTH == 256) begin
        m_axis_cc_tkeep_int = 8'b00000111;
    end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
        m_axis_cc_tkeep_int = 4'b0111;
    end else if (AXIS_PCIE_DATA_WIDTH == 64) begin
        m_axis_cc_tkeep_int = 2'b11;
    end

    m_axis_cc_tuser_int[0] = 1'b0; // discontinue
    m_axis_cc_tuser_int[33:1] = 32'd0; // parity

    // AXI read response processing and TLP generation
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for command
            m_axi_rready_next = 1'b0;

            // store TLP fields and transfer parameters
            at_next = tlp_cmd_at_reg;
            tlp_addr_next = tlp_cmd_addr_reg;
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
                    if (AXIS_PCIE_DATA_WIDTH == 64) begin
                        m_axi_rready_next = 1'b0;
                    end else begin
                        m_axi_rready_next = m_axis_cc_tready_int_early;
                    end
                    tlp_state_next = TLP_STATE_HEADER_1;
                end else begin
                    // status other than SC
                    tlp_state_next = TLP_STATE_CPL_1;
                end
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_HEADER_1: begin
            // header 1 state, send TLP header
            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axi_rready_next = 1'b0;

                if (m_axis_cc_tready_int_reg) begin
                    // output first part of header
                    m_axis_cc_tvalid_int = 1'b1;

                    m_axi_rready_next = m_axis_cc_tready_int_early;

                    tlp_state_next = TLP_STATE_HEADER_2;
                end else begin
                    tlp_state_next = TLP_STATE_HEADER_1;
                end
            end else begin
                m_axi_rready_next = m_axis_cc_tready_int_early && input_active_reg;

                if (m_axis_cc_tready_int_reg && ((m_axi_rready && m_axi_rvalid) || !input_active_reg)) begin
                    transfer_in_save = m_axi_rready && m_axi_rvalid;

                    if (AXIS_PCIE_DATA_WIDTH == 256 && bubble_cycle_reg) begin
                        // bubble cycle; store input data and update input cycle count
                        if (input_active_reg) begin
                            input_cycle_count_next = input_cycle_count_reg - 1;
                            input_active_next = input_cycle_count_reg > 0;
                        end
                        bubble_cycle_next = 1'b0;
                        m_axi_rready_next = m_axis_cc_tready_int_early && input_active_next;
                        tlp_state_next = TLP_STATE_HEADER_1;
                    end else begin
                        // some data is transferred with header
                        if (AXIS_PCIE_DATA_WIDTH == 256) begin
                            dword_count_next = dword_count_reg - 5;
                        end else begin
                            dword_count_next = dword_count_reg - 1;
                        end
                        // update cycle counters
                        if (input_active_reg) begin
                            input_cycle_count_next = input_cycle_count_reg - 1;
                            input_active_next = input_cycle_count_reg > 0;
                        end
                        output_cycle_count_next = output_cycle_count_reg - 1;
                        last_cycle_next = output_cycle_count_next == 0;

                        // transfer data
                        if (AXIS_PCIE_DATA_WIDTH == 256) begin
                            m_axis_cc_tdata_int[255:96] = shift_axi_rdata[255:96];
                        end else begin
                            m_axis_cc_tdata_int[127:96] = shift_axi_rdata[127:96];
                        end

                        // generate tvalid and tkeep signals for header and data
                        m_axis_cc_tvalid_int = 1'b1;
                        if (AXIS_PCIE_DATA_WIDTH == 256) begin
                            if (dword_count_reg >= 5) begin
                                m_axis_cc_tkeep_int = 8'b11111111;
                            end else begin
                                m_axis_cc_tkeep_int = 8'b11111111 >> (5 - dword_count_reg);
                            end
                        end else begin
                            if (dword_count_reg >= 1) begin
                                m_axis_cc_tkeep_int = 4'b1111;
                            end else begin
                                m_axis_cc_tkeep_int = 4'b1111 >> (1 - dword_count_reg);
                            end
                        end

                        if (last_cycle_reg) begin
                            m_axis_cc_tlast_int = 1'b1;

                            // skip idle state if possible
                            at_next = tlp_cmd_at_reg;
                            tlp_addr_next = tlp_cmd_addr_reg;
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
                                m_axi_rready_next = m_axis_cc_tready_int_early;
                                tlp_state_next = TLP_STATE_HEADER_1;
                            end else begin
                                m_axi_rready_next = 1'b0;
                                tlp_state_next = TLP_STATE_IDLE;
                            end
                        end else begin
                            m_axi_rready_next = m_axis_cc_tready_int_early && input_active_next;
                            tlp_state_next = TLP_STATE_TRANSFER;
                        end
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER_1;
                end
            end
        end
        TLP_STATE_HEADER_2: begin
            // header 2 state, send rest of TLP header (64 bit interface only)
            m_axi_rready_next = m_axis_cc_tready_int_early && input_active_reg;

            m_axis_cc_tdata_int[7:0] = tag_reg;
            m_axis_cc_tdata_int[23:8] = completer_id;
            m_axis_cc_tdata_int[24] = completer_id_enable;
            m_axis_cc_tdata_int[27:25] = tc_reg;
            m_axis_cc_tdata_int[30:28] = attr_reg;
            m_axis_cc_tdata_int[31] = 1'b0; // force ECRC
            m_axis_cc_tdata_int[63:32] = shift_axi_rdata[63:32];

            if (m_axis_cc_tready_int_reg && ((m_axi_rready && m_axi_rvalid) || !input_active_reg)) begin
                transfer_in_save = m_axi_rready && m_axi_rvalid;

                // some data is transferred with header
                dword_count_next = dword_count_reg - 1;
                // update cycle counters
                if (input_active_reg) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_reg > 0;
                end
                output_cycle_count_next = output_cycle_count_reg - 1;
                last_cycle_next = output_cycle_count_next == 0;

                // generate tvalid and tkeep signals for header and data
                m_axis_cc_tvalid_int = 1'b1;
                if (dword_count_reg >= 1) begin
                    m_axis_cc_tkeep_int = 2'b11;
                end else begin
                    m_axis_cc_tkeep_int = 2'b11 >> (1 - dword_count_reg);
                end

                if (last_cycle_reg) begin
                    m_axis_cc_tlast_int = 1'b1;

                    // skip idle state if possible
                    at_next = tlp_cmd_at_reg;
                    tlp_addr_next = tlp_cmd_addr_reg;
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
                        m_axi_rready_next = 1'b0;
                        tlp_state_next = TLP_STATE_HEADER_1;
                    end else begin
                        m_axi_rready_next = 1'b0;
                        tlp_state_next = TLP_STATE_IDLE;
                    end
                end else begin
                    m_axi_rready_next = m_axis_cc_tready_int_early && input_active_next;
                    tlp_state_next = TLP_STATE_TRANSFER;
                end
            end else begin
                tlp_state_next = TLP_STATE_HEADER_2;
            end
        end
        TLP_STATE_TRANSFER: begin
            // transfer state, transfer data
            m_axi_rready_next = m_axis_cc_tready_int_early && input_active_reg;

            if (m_axis_cc_tready_int_reg && ((m_axi_rready && m_axi_rvalid) || !input_active_reg)) begin
                transfer_in_save = 1'b1;

                if (bubble_cycle_reg) begin
                    // bubble cycle; store input data and update input cycle count
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg > 0;
                    end
                    bubble_cycle_next = 1'b0;
                    m_axi_rready_next = m_axis_cc_tready_int_early && input_active_next;
                    tlp_state_next = TLP_STATE_TRANSFER;
                end else begin
                    // update DWORD count
                    dword_count_next = dword_count_reg - AXI_STRB_WIDTH/4;
                    // update cycle counters
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg > 0;
                    end
                    output_cycle_count_next = output_cycle_count_reg - 1;
                    last_cycle_next = output_cycle_count_next == 0;

                    // output data and generate tvalid and tkeep signals
                    m_axis_cc_tdata_int = shift_axi_rdata;
                    m_axis_cc_tvalid_int = 1'b1;
                    if (dword_count_reg >= AXI_STRB_WIDTH/4) begin
                        m_axis_cc_tkeep_int = {AXI_STRB_WIDTH{1'b1}};
                    end else begin
                        m_axis_cc_tkeep_int = {AXI_STRB_WIDTH{1'b1}} >> (AXI_STRB_WIDTH - dword_count_reg);
                    end

                    if (last_cycle_reg) begin
                        m_axis_cc_tlast_int = 1'b1;

                        // skip idle state if possible
                        at_next = tlp_cmd_at_reg;
                        tlp_addr_next = tlp_cmd_addr_reg;
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
                            if (AXIS_PCIE_DATA_WIDTH == 64) begin
                                m_axi_rready_next = 1'b0;
                            end else begin
                                m_axi_rready_next = m_axis_cc_tready_int_early;
                            end
                            tlp_state_next = TLP_STATE_HEADER_1;
                        end else begin
                            m_axi_rready_next = 1'b0;
                            tlp_state_next = TLP_STATE_IDLE;
                        end
                    end else begin
                        m_axi_rready_next = m_axis_cc_tready_int_early && input_active_next;
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end
                end
            end else begin
                tlp_state_next = TLP_STATE_TRANSFER;
            end
        end
        TLP_STATE_CPL_1: begin
            // send completion
            m_axis_cc_tvalid_int = 1'b1;
            m_axis_cc_tdata_int[28:16] = 13'd0; // byte count
            m_axis_cc_tdata_int[42:32] = 11'd0; // DWORD count
            m_axis_cc_tdata_int[45:43] = status_reg;

            // generate tvalid and tkeep signals for completion
            if (AXIS_PCIE_DATA_WIDTH == 256) begin
                m_axis_cc_tkeep_int = 8'b00000111;
                m_axis_cc_tlast_int = 1'b1;
            end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
                m_axis_cc_tkeep_int = 4'b0111;
                m_axis_cc_tlast_int = 1'b1;
            end else if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axis_cc_tkeep_int = 2'b11;
                m_axis_cc_tlast_int = 1'b0;
            end

            if (m_axis_cc_tready_int_reg) begin
                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    tlp_state_next = TLP_STATE_CPL_2;
                end else begin
                    // skip idle state if possible
                    at_next = tlp_cmd_at_reg;
                    tlp_addr_next = tlp_cmd_addr_reg;
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
                        m_axi_rready_next = m_axis_cc_tready_int_early;
                        tlp_state_next = TLP_STATE_HEADER_1;
                    end else begin
                        m_axi_rready_next = 1'b0;
                        tlp_state_next = TLP_STATE_IDLE;
                    end
                end
            end else begin
                tlp_state_next = TLP_STATE_CPL_1;
            end
        end
        TLP_STATE_CPL_2: begin
            // send rest of completion
            m_axis_cc_tvalid_int = 1'b1;
            m_axis_cc_tdata_int[7:0] = tag_reg;
            m_axis_cc_tdata_int[23:8] = completer_id;
            m_axis_cc_tdata_int[24] = completer_id_enable;
            m_axis_cc_tdata_int[27:25] = tc_reg;
            m_axis_cc_tdata_int[30:28] = attr_reg;
            m_axis_cc_tdata_int[31] = 1'b0; // force ECRC
            m_axis_cc_tdata_int[63:32] = 32'd0;
            m_axis_cc_tkeep_int = 2'b01;
            m_axis_cc_tlast_int = 1'b1;

            if (m_axis_cc_tready_int_reg) begin
                // skip idle state if possible
                at_next = tlp_cmd_at_reg;
                tlp_addr_next = tlp_cmd_addr_reg;
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
                    m_axi_rready_next = 1'b0;
                    tlp_state_next = TLP_STATE_HEADER_1;
                end else begin
                    m_axi_rready_next = 1'b0;
                    tlp_state_next = TLP_STATE_IDLE;
                end
            end else begin
                tlp_state_next = TLP_STATE_CPL_2;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        axi_state_reg <= AXI_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;
        tlp_cmd_valid_reg <= 1'b0;
        s_axis_cq_tready_reg <= 1'b0;
        m_axi_arvalid_reg <= 1'b0;
        m_axi_rready_reg <= 1'b0;

        status_error_cor_reg <= 1'b0;
        status_error_uncor_reg <= 1'b0;
    end else begin
        axi_state_reg <= axi_state_next;
        tlp_state_reg <= tlp_state_next;
        tlp_cmd_valid_reg <= tlp_cmd_valid_next;
        s_axis_cq_tready_reg <= s_axis_cq_tready_next;
        m_axi_arvalid_reg <= m_axi_arvalid_next;
        m_axi_rready_reg <= m_axi_rready_next;

        status_error_cor_reg <= status_error_cor_next;
        status_error_uncor_reg <= status_error_uncor_next;
    end

    pcie_addr_reg <= pcie_addr_next;
    axi_addr_reg <= axi_addr_next;
    op_count_reg <= op_count_next;
    op_dword_count_reg <= op_dword_count_next;
    tr_dword_count_reg <= tr_dword_count_next;
    tlp_dword_count_reg <= tlp_dword_count_next;
    first_be_reg <= first_be_next;
    last_be_reg <= last_be_next;

    at_reg <= at_next;
    tlp_addr_reg <= tlp_addr_next;
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

    tlp_cmd_at_reg <= tlp_cmd_at_next;
    tlp_cmd_addr_reg <= tlp_cmd_addr_next;
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

    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;

    max_payload_size_dw_reg <= 11'd32 << (max_payload_size > 5 ? 5 : max_payload_size);

    if (transfer_in_save) begin
        save_axi_rdata_reg <= m_axi_rdata;
    end
end

// output datapath logic (PCIe TLP)
reg [AXIS_PCIE_DATA_WIDTH-1:0]    m_axis_cc_tdata_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    m_axis_cc_tkeep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg                               m_axis_cc_tvalid_reg = 1'b0, m_axis_cc_tvalid_next;
reg                               m_axis_cc_tlast_reg = 1'b0;
reg [AXIS_PCIE_CC_USER_WIDTH-1:0] m_axis_cc_tuser_reg = {AXIS_PCIE_CC_USER_WIDTH{1'b0}};

reg [AXIS_PCIE_DATA_WIDTH-1:0]    temp_m_axis_cc_tdata_reg = {AXIS_PCIE_DATA_WIDTH{1'b0}};
reg [AXIS_PCIE_KEEP_WIDTH-1:0]    temp_m_axis_cc_tkeep_reg = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
reg                               temp_m_axis_cc_tvalid_reg = 1'b0, temp_m_axis_cc_tvalid_next;
reg                               temp_m_axis_cc_tlast_reg = 1'b0;
reg [AXIS_PCIE_CC_USER_WIDTH-1:0] temp_m_axis_cc_tuser_reg = {AXIS_PCIE_CC_USER_WIDTH{1'b0}};

// datapath control
reg store_axis_cc_int_to_output;
reg store_axis_cc_int_to_temp;
reg store_axis_cc_temp_to_output;

assign m_axis_cc_tdata = m_axis_cc_tdata_reg;
assign m_axis_cc_tkeep = m_axis_cc_tkeep_reg;
assign m_axis_cc_tvalid = m_axis_cc_tvalid_reg;
assign m_axis_cc_tlast = m_axis_cc_tlast_reg;
assign m_axis_cc_tuser = m_axis_cc_tuser_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_cc_tready_int_early = m_axis_cc_tready || (!temp_m_axis_cc_tvalid_reg && (!m_axis_cc_tvalid_reg || !m_axis_cc_tvalid_int));

always @* begin
    // transfer sink ready state to source
    m_axis_cc_tvalid_next = m_axis_cc_tvalid_reg;
    temp_m_axis_cc_tvalid_next = temp_m_axis_cc_tvalid_reg;

    store_axis_cc_int_to_output = 1'b0;
    store_axis_cc_int_to_temp = 1'b0;
    store_axis_cc_temp_to_output = 1'b0;

    if (m_axis_cc_tready_int_reg) begin
        // input is ready
        if (m_axis_cc_tready || !m_axis_cc_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_cc_tvalid_next = m_axis_cc_tvalid_int;
            store_axis_cc_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_cc_tvalid_next = m_axis_cc_tvalid_int;
            store_axis_cc_int_to_temp = 1'b1;
        end
    end else if (m_axis_cc_tready) begin
        // input is not ready, but output is ready
        m_axis_cc_tvalid_next = temp_m_axis_cc_tvalid_reg;
        temp_m_axis_cc_tvalid_next = 1'b0;
        store_axis_cc_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axis_cc_tvalid_reg <= 1'b0;
        m_axis_cc_tready_int_reg <= 1'b0;
        temp_m_axis_cc_tvalid_reg <= 1'b0;
    end else begin
        m_axis_cc_tvalid_reg <= m_axis_cc_tvalid_next;
        m_axis_cc_tready_int_reg <= m_axis_cc_tready_int_early;
        temp_m_axis_cc_tvalid_reg <= temp_m_axis_cc_tvalid_next;
    end

    // datapath
    if (store_axis_cc_int_to_output) begin
        m_axis_cc_tdata_reg <= m_axis_cc_tdata_int;
        m_axis_cc_tkeep_reg <= m_axis_cc_tkeep_int;
        m_axis_cc_tlast_reg <= m_axis_cc_tlast_int;
        m_axis_cc_tuser_reg <= m_axis_cc_tuser_int;
    end else if (store_axis_cc_temp_to_output) begin
        m_axis_cc_tdata_reg <= temp_m_axis_cc_tdata_reg;
        m_axis_cc_tkeep_reg <= temp_m_axis_cc_tkeep_reg;
        m_axis_cc_tlast_reg <= temp_m_axis_cc_tlast_reg;
        m_axis_cc_tuser_reg <= temp_m_axis_cc_tuser_reg;
    end

    if (store_axis_cc_int_to_temp) begin
        temp_m_axis_cc_tdata_reg <= m_axis_cc_tdata_int;
        temp_m_axis_cc_tkeep_reg <= m_axis_cc_tkeep_int;
        temp_m_axis_cc_tlast_reg <= m_axis_cc_tlast_int;
        temp_m_axis_cc_tuser_reg <= m_axis_cc_tuser_int;
    end
end

endmodule
