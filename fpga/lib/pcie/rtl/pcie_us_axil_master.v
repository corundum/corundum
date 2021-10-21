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

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Ultrascale PCIe AXI Lite Master
 */
module pcie_us_axil_master #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream CQ tuser signal width
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
    // PCIe AXI stream CC tuser signal width
    parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81,
    // Width of AXI lite data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXI_ADDR_WIDTH = 64,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Enable parity
    parameter ENABLE_PARITY = 0
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
     * AXI Lite Master output
     */
    output wire [AXI_ADDR_WIDTH-1:0]          m_axil_awaddr,
    output wire [2:0]                         m_axil_awprot,
    output wire                               m_axil_awvalid,
    input  wire                               m_axil_awready,
    output wire [AXI_DATA_WIDTH-1:0]          m_axil_wdata,
    output wire [AXI_STRB_WIDTH-1:0]          m_axil_wstrb,
    output wire                               m_axil_wvalid,
    input  wire                               m_axil_wready,
    input  wire [1:0]                         m_axil_bresp,
    input  wire                               m_axil_bvalid,
    output wire                               m_axil_bready,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axil_araddr,
    output wire [2:0]                         m_axil_arprot,
    output wire                               m_axil_arvalid,
    input  wire                               m_axil_arready,
    input  wire [AXI_DATA_WIDTH-1:0]          m_axil_rdata,
    input  wire [1:0]                         m_axil_rresp,
    input  wire                               m_axil_rvalid,
    output wire                               m_axil_rready,

    /*
     * Configuration
     */
    input  wire [15:0]                        completer_id,
    input  wire                               completer_id_enable,

    /*
     * Status
     */
    output wire                               status_error_cor,
    output wire                               status_error_uncor
);

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
        if (AXIS_PCIE_CQ_USER_WIDTH != 183) begin
            $error("Error: PCIe CQ tuser width must be 183 (instance %m)");
            $finish;
        end

        if (AXIS_PCIE_CC_USER_WIDTH != 81) begin
            $error("Error: PCIe CC tuser width must be 81 (instance %m)");
            $finish;
        end
    end else begin
        if (AXIS_PCIE_CQ_USER_WIDTH != 85 && AXIS_PCIE_CQ_USER_WIDTH != 88) begin
            $error("Error: PCIe CQ tuser width must be 85 or 88 (instance %m)");
            $finish;
        end

        if (AXIS_PCIE_CC_USER_WIDTH != 33) begin
            $error("Error: PCIe CC tuser width must be 33 (instance %m)");
            $finish;
        end
    end

    if (AXI_DATA_WIDTH != 32) begin
        $error("Error: AXI interface width must be 32 (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH * 8 != AXI_DATA_WIDTH) begin
        $error("Error: AXI interface requires byte (8-bit) granularity (instance %m)");
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
    STATE_IDLE = 3'd0,
    STATE_HEADER = 3'd1,
    STATE_READ = 3'd2,
    STATE_WRITE_1 = 3'd3,
    STATE_WRITE_2 = 3'd4,
    STATE_WAIT_END = 3'd5,
    STATE_CPL_1 = 3'd6,
    STATE_CPL_2 = 3'd7;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg [10:0] dword_count_reg = 11'd0, dword_count_next;
reg [3:0] type_reg = 4'd0, type_next;
reg [2:0] status_reg = 3'b000, status_next;
reg [15:0] requester_id_reg = 16'd0, requester_id_next;
reg [7:0] tag_reg = 7'd0, tag_next;
reg [2:0] tc_reg = 3'd0, tc_next;
reg [2:0] attr_reg = 3'd0, attr_next;
reg [3:0] first_be_reg = 4'd0, first_be_next;
reg [3:0] last_be_reg = 4'd0, last_be_next;
reg cpl_data_reg = 1'b0, cpl_data_next;

reg s_axis_cq_tready_reg = 1'b0, s_axis_cq_tready_next;

reg [AXI_ADDR_WIDTH-1:0] m_axil_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axil_addr_next;
reg m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
reg [AXI_DATA_WIDTH-1:0] m_axil_wdata_reg = {AXI_DATA_WIDTH{1'b0}}, m_axil_wdata_next;
reg [AXI_STRB_WIDTH-1:0] m_axil_wstrb_reg = {AXI_STRB_WIDTH{1'b0}}, m_axil_wstrb_next;
reg m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
reg m_axil_bready_reg = 1'b0, m_axil_bready_next;
reg m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
reg m_axil_rready_reg = 1'b0, m_axil_rready_next;

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
    state_next = STATE_IDLE;

    s_axis_cq_tready_next = 1'b0;

    dword_count_next = dword_count_reg;
    type_next = type_reg;
    status_next = status_reg;
    requester_id_next = requester_id_reg;
    tag_next = tag_reg;
    tc_next = tc_reg;
    attr_next = attr_reg;
    first_be_next = first_be_reg;
    last_be_next = last_be_reg;
    cpl_data_next = cpl_data_reg;

    m_axis_cc_tdata_int = {AXIS_PCIE_DATA_WIDTH{1'b0}};
    m_axis_cc_tkeep_int = {AXIS_PCIE_KEEP_WIDTH{1'b0}};
    m_axis_cc_tvalid_int = 1'b0;
    m_axis_cc_tlast_int = 1'b0;
    m_axis_cc_tuser_int = {AXIS_PCIE_CC_USER_WIDTH{1'b0}};

    casez (first_be_reg)
        4'b0000: m_axis_cc_tdata_int[6:0] = {m_axil_addr_reg[6:2], 2'b00}; // lower address
        4'bzzz1: m_axis_cc_tdata_int[6:0] = {m_axil_addr_reg[6:2], 2'b00}; // lower address
        4'bzz10: m_axis_cc_tdata_int[6:0] = {m_axil_addr_reg[6:2], 2'b01}; // lower address
        4'bz100: m_axis_cc_tdata_int[6:0] = {m_axil_addr_reg[6:2], 2'b10}; // lower address
        4'b1000: m_axis_cc_tdata_int[6:0] = {m_axil_addr_reg[6:2], 2'b11}; // lower address
    endcase
    m_axis_cc_tdata_int[9:8] = 2'b00; // AT
    casez (first_be_reg)
        4'b0000: m_axis_cc_tdata_int[28:16] = 13'd1; // Byte count
        4'b0001: m_axis_cc_tdata_int[28:16] = 13'd1; // Byte count
        4'b0010: m_axis_cc_tdata_int[28:16] = 13'd1; // Byte count
        4'b0100: m_axis_cc_tdata_int[28:16] = 13'd1; // Byte count
        4'b1000: m_axis_cc_tdata_int[28:16] = 13'd1; // Byte count
        4'b0011: m_axis_cc_tdata_int[28:16] = 13'd2; // Byte count
        4'b0110: m_axis_cc_tdata_int[28:16] = 13'd2; // Byte count
        4'b1100: m_axis_cc_tdata_int[28:16] = 13'd2; // Byte count
        4'b01z1: m_axis_cc_tdata_int[28:16] = 13'd3; // Byte count
        4'b1z10: m_axis_cc_tdata_int[28:16] = 13'd3; // Byte count
        4'b1zz1: m_axis_cc_tdata_int[28:16] = 13'd4; // Byte count
    endcase
    m_axis_cc_tdata_int[42:32] = 11'd1; // DWORD count
    m_axis_cc_tdata_int[45:43] = status_reg;
    m_axis_cc_tdata_int[63:48] = requester_id_reg;
    if (AXIS_PCIE_DATA_WIDTH > 64) begin
        m_axis_cc_tdata_int[71:64] = tag_reg;
        m_axis_cc_tdata_int[87:72] = completer_id;
        m_axis_cc_tdata_int[88] = completer_id_enable;
        m_axis_cc_tdata_int[91:89] = tc_reg;
        m_axis_cc_tdata_int[94:92] = attr_reg;
        m_axis_cc_tdata_int[95] = 1'b0; // force ECRC
        m_axis_cc_tdata_int[127:96] = m_axil_rdata;
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        m_axis_cc_tuser_int[1:0] = 2'b01; // is_sop
        m_axis_cc_tuser_int[3:2] = 2'd0; // is_sop0_ptr
        m_axis_cc_tuser_int[5:4] = 2'd0; // is_sop1_ptr
        m_axis_cc_tuser_int[7:6] = 2'b01; // is_eop
        m_axis_cc_tuser_int[11:8]  = 4'd3; // is_eop0_ptr
        m_axis_cc_tuser_int[15:12] = 4'd0; // is_eop1_ptr
        m_axis_cc_tuser_int[16] = 1'b0; // discontinue
        m_axis_cc_tuser_int[80:17] = 64'd0; // parity
    end else begin
        m_axis_cc_tuser_int[0] = 1'b0; // discontinue
        m_axis_cc_tuser_int[32:1] = 32'd0; // parity
    end

    if (AXIS_PCIE_DATA_WIDTH == 512) begin
        m_axis_cc_tkeep_int = 16'b0000000000001111;
    end else if (AXIS_PCIE_DATA_WIDTH == 256) begin
        m_axis_cc_tkeep_int = 8'b00001111;
    end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
        m_axis_cc_tkeep_int = 4'b1111;
    end else if (AXIS_PCIE_DATA_WIDTH == 64) begin
        m_axis_cc_tkeep_int = 2'b11;
    end

    m_axil_addr_next = m_axil_addr_reg;
    m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_awready;
    m_axil_wdata_next = m_axil_wdata_reg;
    m_axil_wstrb_next = m_axil_wstrb_reg;
    m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wready;
    m_axil_bready_next = 1'b0;
    m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_arready;
    m_axil_rready_next = 1'b0;

    status_error_cor_next = 1'b0;
    status_error_uncor_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state, wait for completion request
            s_axis_cq_tready_next = m_axis_cc_tready_int_early;

            if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                // header fields
                m_axil_addr_next = {s_axis_cq_tdata[63:2], 2'b00};
                if (AXIS_PCIE_DATA_WIDTH > 64) begin
                    dword_count_next = s_axis_cq_tdata[74:64];
                    type_next = s_axis_cq_tdata[78:75];
                    requester_id_next = s_axis_cq_tdata[95:80];
                    tag_next = s_axis_cq_tdata[103:96];
                    tc_next = s_axis_cq_tdata[123:121];
                    attr_next = s_axis_cq_tdata[126:124];

                    // data
                    if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                        m_axil_wdata_next = s_axis_cq_tdata[159:128];
                    end
                end

                // tuser fields
                if (AXIS_PCIE_DATA_WIDTH == 512) begin
                    first_be_next = s_axis_cq_tuser[3:0];
                    last_be_next = s_axis_cq_tuser[11:8];
                end else begin
                    first_be_next = s_axis_cq_tuser[3:0];
                    last_be_next = s_axis_cq_tuser[7:4];
                end

                m_axil_wstrb_next = first_be_next;

                status_next = CPL_STATUS_SC; // successful completion

                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    if (s_axis_cq_tlast) begin
                        // truncated packet
                        // report uncorrectable error
                        status_error_uncor_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        state_next = STATE_HEADER;
                    end
                end else begin
                    if (type_next == REQ_MEM_READ || type_next == REQ_IO_READ) begin
                        // read request
                        if (s_axis_cq_tlast && dword_count_next == 11'd1) begin
                            m_axil_arvalid_next = 1'b1;
                            m_axil_rready_next = m_axis_cc_tready_int_early;
                            s_axis_cq_tready_next = 1'b0;
                            state_next = STATE_READ;
                        end else begin
                            // bad length
                            status_next = CPL_STATUS_CA; // completer abort
                            // report correctable error
                            status_error_cor_next = 1'b1;
                            if (s_axis_cq_tlast) begin
                                s_axis_cq_tready_next = 1'b0;
                                state_next = STATE_CPL_1;
                            end else begin
                                s_axis_cq_tready_next = 1'b1;
                                state_next = STATE_WAIT_END;
                            end
                        end
                    end else if (type_next == REQ_MEM_WRITE || type_next == REQ_IO_WRITE) begin
                        // write request
                        if (AXIS_PCIE_DATA_WIDTH >= 256 && s_axis_cq_tlast && dword_count_next == 11'd1) begin
                            m_axil_awvalid_next = 1'b1;
                            m_axil_wvalid_next = 1'b1;
                            m_axil_bready_next = 1'b1;
                            s_axis_cq_tready_next = 1'b0;
                            state_next = STATE_WRITE_2;
                        end else if (AXIS_PCIE_DATA_WIDTH < 256 && dword_count_next == 11'd1) begin
                            s_axis_cq_tready_next = 1'b1;
                            state_next = STATE_WRITE_1;
                        end else begin
                            // bad length
                            status_next = CPL_STATUS_CA; // completer abort
                            if (type_next == REQ_MEM_WRITE) begin
                                // memory write - posted, no completion
                                // report uncorrectable error
                                status_error_uncor_next = 1'b1;
                                if (s_axis_cq_tlast) begin
                                    s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                                    state_next = STATE_IDLE;
                                end else begin
                                    s_axis_cq_tready_next = 1'b1;
                                    state_next = STATE_WAIT_END;
                                end
                            end else begin
                                // IO write - non-posted, send completion
                                // report correctable error
                                status_error_cor_next = 1'b1;
                                if (s_axis_cq_tlast) begin
                                    s_axis_cq_tready_next = 1'b0;
                                    state_next = STATE_CPL_1;
                                end else begin
                                    s_axis_cq_tready_next = 1'b1;
                                    state_next = STATE_WAIT_END;
                                end
                            end
                        end
                    end else begin
                        // other request
                        status_next = CPL_STATUS_UR; // unsupported request
                        if (type_next == REQ_MEM_WRITE || (type_next & 4'b1100) == 4'b1100) begin
                            // memory write or message - posted, no completion
                            // report uncorrectable error
                            status_error_uncor_next = 1'b1;
                            if (s_axis_cq_tlast) begin
                                s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                                state_next = STATE_IDLE;
                            end else begin
                                s_axis_cq_tready_next = 1'b1;
                                state_next = STATE_WAIT_END;
                            end
                        end else begin
                            // other non-posted request, send UR completion
                            // report correctable error
                            status_error_cor_next = 1'b1;
                            if (s_axis_cq_tlast) begin
                                s_axis_cq_tready_next = 1'b0;
                                state_next = STATE_CPL_1;
                            end else begin
                                s_axis_cq_tready_next = 1'b1;
                                state_next = STATE_WAIT_END;
                            end
                        end
                    end
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_HEADER: begin
            // header state, handle header (64 bit interface only)
            s_axis_cq_tready_next = m_axis_cc_tready_int_early;

            // header fields
            dword_count_next = s_axis_cq_tdata[10:0];
            type_next = s_axis_cq_tdata[14:11];
            requester_id_next = s_axis_cq_tdata[31:16];
            tag_next = s_axis_cq_tdata[39:32];
            tc_next = s_axis_cq_tdata[59:57];
            attr_next = s_axis_cq_tdata[62:60];

            // data
            m_axil_wstrb_next = first_be_reg;

            if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                if (type_next == REQ_MEM_READ || type_next == REQ_IO_READ) begin
                    // read request
                    if (s_axis_cq_tlast && dword_count_next == 11'd1) begin
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = m_axis_cc_tready_int_early;
                        s_axis_cq_tready_next = 1'b0;
                        state_next = STATE_READ;
                    end else begin
                        // bad length
                        status_next = CPL_STATUS_CA; // completer abort
                        // report correctable error
                        status_error_cor_next = 1'b1;
                        if (s_axis_cq_tlast) begin
                            s_axis_cq_tready_next = 1'b0;
                            state_next = STATE_CPL_1;
                        end else begin
                            s_axis_cq_tready_next = 1'b1;
                            state_next = STATE_WAIT_END;
                        end
                    end
                end else if (type_next == REQ_MEM_WRITE || type_next == REQ_IO_WRITE) begin
                    // write request
                    if (dword_count_next == 11'd1) begin
                        s_axis_cq_tready_next = 1'b1;
                        state_next = STATE_WRITE_1;
                    end else begin
                        // bad length
                        status_next = CPL_STATUS_CA; // completer abort
                        if (type_next == REQ_MEM_WRITE) begin
                            // memory write - posted, no completion
                            // report uncorrectable error
                            status_error_uncor_next = 1'b1;
                            if (s_axis_cq_tlast) begin
                                s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                                state_next = STATE_IDLE;
                            end else begin
                                s_axis_cq_tready_next = 1'b1;
                                state_next = STATE_WAIT_END;
                            end
                        end else begin
                            // other non-posted request, send UR completion
                            // report correctable error
                            status_error_cor_next = 1'b1;
                            if (s_axis_cq_tlast) begin
                                s_axis_cq_tready_next = 1'b0;
                                state_next = STATE_CPL_1;
                            end else begin
                                s_axis_cq_tready_next = 1'b1;
                                state_next = STATE_WAIT_END;
                            end
                        end
                    end
                end else begin
                    // other request
                    status_next = CPL_STATUS_UR; // unsupported request
                    if (type_next == REQ_MEM_WRITE || (type_next & 4'b1100) == 4'b1100) begin
                        // memory write or message - posted, no completion
                        // report uncorrectable error
                        status_error_uncor_next = 1'b1;
                        if (s_axis_cq_tlast) begin
                            s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                            state_next = STATE_IDLE;
                        end else begin
                            s_axis_cq_tready_next = 1'b1;
                            state_next = STATE_WAIT_END;
                        end
                    end else begin
                        // other non-posted request, send UR completion
                        // report correctable error
                        status_error_cor_next = 1'b1;
                        if (s_axis_cq_tlast) begin
                            s_axis_cq_tready_next = 1'b0;
                            state_next = STATE_CPL_1;
                        end else begin
                            s_axis_cq_tready_next = 1'b1;
                            state_next = STATE_WAIT_END;
                        end
                    end
                end
            end else begin
                state_next = STATE_HEADER;
            end
        end
        STATE_READ: begin
            // read state, wait for read response
            m_axil_rready_next = m_axis_cc_tready_int_early;

            m_axis_cc_tdata_int[42:32] = 11'd1; // DWORD count
            m_axis_cc_tdata_int[45:43] = CPL_STATUS_SC; // status: successful completion
            m_axis_cc_tdata_int[127:96] = m_axil_rdata;

            if (AXIS_PCIE_DATA_WIDTH == 512) begin
                m_axis_cc_tuser_int[7:6] = 2'b01; // is_eop
                m_axis_cc_tuser_int[11:8]  = 4'd3; // is_eop0_ptr
                m_axis_cc_tuser_int[15:12] = 4'd0; // is_eop1_ptr
            end

            if (AXIS_PCIE_DATA_WIDTH == 512) begin
                m_axis_cc_tkeep_int = 16'b0000000000001111;
                m_axis_cc_tlast_int = 1'b1;
            end else if (AXIS_PCIE_DATA_WIDTH == 256) begin
                m_axis_cc_tkeep_int = 8'b00001111;
                m_axis_cc_tlast_int = 1'b1;
            end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
                m_axis_cc_tkeep_int = 4'b1111;
                m_axis_cc_tlast_int = 1'b1;
            end else if (AXIS_PCIE_DATA_WIDTH == 64) begin
                m_axis_cc_tkeep_int = 2'b11;
                m_axis_cc_tlast_int = 1'b0;
            end

            if (m_axil_rready && m_axil_rvalid) begin
                // send completion
                m_axis_cc_tvalid_int = 1'b1;

                m_axil_rready_next = 1'b0;
                if (AXIS_PCIE_DATA_WIDTH == 64) begin
                    cpl_data_next = 1'b1;
                    state_next = STATE_CPL_2;
                end else begin
                    s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_READ;
            end
        end
        STATE_WRITE_1: begin
            // write 1 state, store write data and initiate write
            s_axis_cq_tready_next = 1'b1;

            // data
            m_axil_wdata_next = s_axis_cq_tdata[31:0];

            if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                if (s_axis_cq_tlast) begin
                    m_axil_awvalid_next = 1'b1;
                    m_axil_wvalid_next = 1'b1;
                    m_axil_bready_next = m_axis_cc_tready_int_early;
                    s_axis_cq_tready_next = 1'b0;
                    state_next = STATE_WRITE_2;
                end else begin
                    s_axis_cq_tready_next = 1'b1;
                    state_next = STATE_WAIT_END;
                end
            end else begin
                state_next = STATE_WRITE_1;
            end
        end
        STATE_WRITE_2: begin
            // write 2 state, handle write response
            m_axil_bready_next = m_axis_cc_tready_int_early;

            if (m_axil_bready && m_axil_bvalid) begin
                m_axil_bready_next = 1'b0;
                if (type_reg == REQ_MEM_WRITE) begin
                    // memory write - posted, no completion
                    s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                    state_next = STATE_IDLE;
                end else begin
                    // IO write - non-posted, send completion
                    m_axis_cc_tvalid_int = 1'b1;
                    m_axis_cc_tdata_int[42:32] = 11'd0; // DWORD count
                    m_axis_cc_tdata_int[45:43] = CPL_STATUS_SC; // status: successful completion

                    if (AXIS_PCIE_DATA_WIDTH == 512) begin
                        m_axis_cc_tuser_int[7:6] = 2'b01; // is_eop
                        m_axis_cc_tuser_int[11:8]  = 4'd2; // is_eop0_ptr
                        m_axis_cc_tuser_int[15:12] = 4'd0; // is_eop1_ptr
                    end

                    if (AXIS_PCIE_DATA_WIDTH == 512) begin
                        m_axis_cc_tkeep_int = 16'b0000000000000111;
                        m_axis_cc_tlast_int = 1'b1;
                    end else if (AXIS_PCIE_DATA_WIDTH == 256) begin
                        m_axis_cc_tkeep_int = 8'b00000111;
                        m_axis_cc_tlast_int = 1'b1;
                    end else if (AXIS_PCIE_DATA_WIDTH == 128) begin
                        m_axis_cc_tkeep_int = 4'b0111;
                        m_axis_cc_tlast_int = 1'b1;
                    end else if (AXIS_PCIE_DATA_WIDTH == 64) begin
                        m_axis_cc_tkeep_int = 2'b11;
                        m_axis_cc_tlast_int = 1'b0;
                    end

                    if (AXIS_PCIE_DATA_WIDTH == 64) begin
                        cpl_data_next = 1'b0;
                        state_next = STATE_CPL_2;
                    end else begin
                        s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                        state_next = STATE_IDLE;
                    end
                end
            end else begin
                state_next = STATE_WRITE_2;
            end
        end
        STATE_WAIT_END: begin
            // wait end state, wait for end of completion request
            s_axis_cq_tready_next = 1'b1;

            if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                if (s_axis_cq_tlast) begin
                    // completion
                    if (type_reg == REQ_MEM_WRITE || (type_reg & 4'b1100) == 4'b1100) begin
                        // memory write or message - posted, no completion
                        s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                        state_next = STATE_IDLE;
                    end else begin
                        // IO write - non-posted, send completion
                        m_axis_cc_tvalid_int = 1'b1;
                        m_axis_cc_tdata_int[42:32] = 11'd0; // DWORD count

                        if (AXIS_PCIE_DATA_WIDTH == 512) begin
                            m_axis_cc_tuser_int[7:6] = 2'b01; // is_eop
                            m_axis_cc_tuser_int[11:8]  = 4'd2; // is_eop0_ptr
                            m_axis_cc_tuser_int[15:12] = 4'd0; // is_eop1_ptr
                        end

                        if (AXIS_PCIE_DATA_WIDTH == 512) begin
                            m_axis_cc_tkeep_int = 16'b0000000000000111;
                            m_axis_cc_tlast_int = 1'b1;
                        end else if (AXIS_PCIE_DATA_WIDTH == 256) begin
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
                                cpl_data_next = 1'b0;
                                state_next = STATE_CPL_2;
                            end else begin
                                s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                                state_next = STATE_IDLE;
                            end
                        end else begin
                            state_next = STATE_CPL_1;
                        end
                    end
                end else begin
                    state_next = STATE_WAIT_END;
                end
            end else begin
                state_next = STATE_WAIT_END;
            end
        end
        STATE_CPL_1: begin
            // send completion
            m_axis_cc_tvalid_int = 1'b1;
            m_axis_cc_tdata_int[28:16] = 13'd0; // byte count
            m_axis_cc_tdata_int[42:32] = 11'd0; // DWORD count
            m_axis_cc_tdata_int[45:43] = status_reg;

            if (AXIS_PCIE_DATA_WIDTH == 512) begin
                m_axis_cc_tuser_int[7:6] = 2'b01; // is_eop
                m_axis_cc_tuser_int[11:8]  = 4'd2; // is_eop0_ptr
                m_axis_cc_tuser_int[15:12] = 4'd0; // is_eop1_ptr
            end

            if (AXIS_PCIE_DATA_WIDTH == 512) begin
                m_axis_cc_tkeep_int = 16'b0000000000000111;
                m_axis_cc_tlast_int = 1'b1;
            end else if (AXIS_PCIE_DATA_WIDTH == 256) begin
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
                    cpl_data_next = 1'b0;
                    state_next = STATE_CPL_2;
                end else begin
                    s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_CPL_1;
            end
        end
        STATE_CPL_2: begin
            // send rest of completion
            m_axis_cc_tvalid_int = 1'b1;
            m_axis_cc_tdata_int[7:0] = tag_reg;
            m_axis_cc_tdata_int[23:8] = completer_id;
            m_axis_cc_tdata_int[24] = completer_id_enable;
            m_axis_cc_tdata_int[27:25] = tc_reg;
            m_axis_cc_tdata_int[30:28] = attr_reg;
            m_axis_cc_tdata_int[31] = 1'b0; // force ECRC
            m_axis_cc_tdata_int[63:32] = m_axil_rdata;
            m_axis_cc_tkeep_int = {cpl_data_reg, 1'b1};
            m_axis_cc_tlast_int = 1'b1;

            if (m_axis_cc_tready_int_reg) begin
                s_axis_cq_tready_next = m_axis_cc_tready_int_early;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_CPL_2;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_axis_cq_tready_reg <= 1'b0;

        m_axil_awvalid_reg <= 1'b0;
        m_axil_wvalid_reg <= 1'b0;
        m_axil_bready_reg <= 1'b0;
        m_axil_arvalid_reg <= 1'b0;
        m_axil_rready_reg <= 1'b0;

        status_error_cor_reg <= 1'b0;
        status_error_uncor_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        s_axis_cq_tready_reg <= s_axis_cq_tready_next;

        m_axil_awvalid_reg <= m_axil_awvalid_next;
        m_axil_wvalid_reg <= m_axil_wvalid_next;
        m_axil_bready_reg <= m_axil_bready_next;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
        m_axil_rready_reg <= m_axil_rready_next;

        status_error_cor_reg <= status_error_cor_next;
        status_error_uncor_reg <= status_error_uncor_next;
    end

    dword_count_reg <= dword_count_next;
    type_reg <= type_next;
    tag_reg <= tag_next;
    status_reg <= status_next;
    requester_id_reg <= requester_id_next;
    tc_reg <= tc_next;
    attr_reg <= attr_next;
    first_be_reg <= first_be_next;
    last_be_reg <= last_be_next;
    cpl_data_reg <= cpl_data_next;

    m_axil_addr_reg <= m_axil_addr_next;
    m_axil_wdata_reg <= m_axil_wdata_next;
    m_axil_wstrb_reg <= m_axil_wstrb_next;
end

// output datapath logic
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
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

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

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;
    
    if (m_axis_cc_tready_int_reg) begin
        // input is ready
        if (m_axis_cc_tready || !m_axis_cc_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_cc_tvalid_next = m_axis_cc_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_cc_tvalid_next = m_axis_cc_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_cc_tready) begin
        // input is not ready, but output is ready
        m_axis_cc_tvalid_next = temp_m_axis_cc_tvalid_reg;
        temp_m_axis_cc_tvalid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
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
    if (store_axis_int_to_output) begin
        m_axis_cc_tdata_reg <= m_axis_cc_tdata_int;
        m_axis_cc_tkeep_reg <= m_axis_cc_tkeep_int;
        m_axis_cc_tlast_reg <= m_axis_cc_tlast_int;
        m_axis_cc_tuser_reg <= m_axis_cc_tuser_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_cc_tdata_reg <= temp_m_axis_cc_tdata_reg;
        m_axis_cc_tkeep_reg <= temp_m_axis_cc_tkeep_reg;
        m_axis_cc_tlast_reg <= temp_m_axis_cc_tlast_reg;
        m_axis_cc_tuser_reg <= temp_m_axis_cc_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_cc_tdata_reg <= m_axis_cc_tdata_int;
        temp_m_axis_cc_tkeep_reg <= m_axis_cc_tkeep_int;
        temp_m_axis_cc_tlast_reg <= m_axis_cc_tlast_int;
        temp_m_axis_cc_tuser_reg <= m_axis_cc_tuser_int;
    end
end

endmodule

`resetall
