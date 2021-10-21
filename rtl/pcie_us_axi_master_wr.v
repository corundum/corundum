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
 * Ultrascale PCIe AXI Master (write)
 */
module pcie_us_axi_master_wr #
(
    // Width of PCIe AXI stream interfaces in bits
    parameter AXIS_PCIE_DATA_WIDTH = 256,
    // PCIe AXI stream tkeep signal width (words per cycle)
    parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32),
    // PCIe AXI stream CQ tuser signal width
    parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183,
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
     * AXI Master output
     */
    output wire [AXI_ID_WIDTH-1:0]            m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axi_awaddr,
    output wire [7:0]                         m_axi_awlen,
    output wire [2:0]                         m_axi_awsize,
    output wire [1:0]                         m_axi_awburst,
    output wire                               m_axi_awlock,
    output wire [3:0]                         m_axi_awcache,
    output wire [2:0]                         m_axi_awprot,
    output wire                               m_axi_awvalid,
    input  wire                               m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]          m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]          m_axi_wstrb,
    output wire                               m_axi_wlast,
    output wire                               m_axi_wvalid,
    input  wire                               m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]            m_axi_bid,
    input  wire [1:0]                         m_axi_bresp,
    input  wire                               m_axi_bvalid,
    output wire                               m_axi_bready,

    /*
     * Status
     */
    output wire                               status_error_uncor
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN*AXI_WORD_WIDTH;

parameter AXIS_PCIE_WORD_WIDTH = AXIS_PCIE_KEEP_WIDTH;
parameter AXIS_PCIE_WORD_SIZE = AXIS_PCIE_DATA_WIDTH/AXIS_PCIE_WORD_WIDTH;

parameter OFFSET_WIDTH = $clog2(AXIS_PCIE_DATA_WIDTH/32);

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
    end else begin
        if (AXIS_PCIE_CQ_USER_WIDTH != 85 && AXIS_PCIE_CQ_USER_WIDTH != 88) begin
            $error("Error: PCIe CQ tuser width must be 85 or 88 (instance %m)");
            $finish;
        end
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

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_HEADER = 3'd1,
    STATE_TRANSFER = 2'd2,
    STATE_WAIT_END = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg transfer_in_save;
reg flush_save;

reg [AXI_ADDR_WIDTH-1:0] axi_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, axi_addr_next;
reg [9:0] op_dword_count_reg = 10'd0, op_dword_count_next;
reg [9:0] tr_dword_count_reg = 10'd0, tr_dword_count_next;
reg [11:0] input_cycle_count_reg = 12'd0, input_cycle_count_next;
reg [11:0] output_cycle_count_reg = 12'd0, output_cycle_count_next;
reg input_active_reg = 1'b0, input_active_next;
reg bubble_cycle_reg = 1'b0, bubble_cycle_next;
reg first_cycle_reg = 1'b0, first_cycle_next;
reg last_cycle_reg = 1'b0, last_cycle_next;

reg [3:0] type_reg = 4'd0, type_next;
reg [3:0] first_be_reg = 4'd0, first_be_next;
reg [3:0] last_be_reg = 4'd0, last_be_next;
reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
reg [OFFSET_WIDTH-1:0] first_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, first_cycle_offset_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;

reg s_axis_cq_tready_reg = 1'b0, s_axis_cq_tready_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_awaddr_next;
reg [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
reg m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;

reg [AXI_DATA_WIDTH-1:0] save_axis_tdata_reg = {AXI_DATA_WIDTH{1'b0}};

wire [AXI_DATA_WIDTH-1:0] shift_axis_tdata = {s_axis_cq_tdata, save_axis_tdata_reg} >> ((AXI_STRB_WIDTH/4-offset_reg)*32);

reg status_error_uncor_reg = 1'b0, status_error_uncor_next;

// internal datapath
reg  [AXI_DATA_WIDTH-1:0]  m_axi_wdata_int;
reg  [AXI_STRB_WIDTH-1:0]  m_axi_wstrb_int;
reg                        m_axi_wvalid_int;
reg                        m_axi_wready_int_reg = 1'b0;
reg                        m_axi_wlast_int;
wire                       m_axi_wready_int_early;

assign s_axis_cq_tready = s_axis_cq_tready_reg;

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

    transfer_in_save = 1'b0;

    s_axis_cq_tready_next = 1'b0;

    type_next = type_reg;
    axi_addr_next = axi_addr_reg;
    op_dword_count_next = op_dword_count_reg;
    tr_dword_count_next = tr_dword_count_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    bubble_cycle_next = bubble_cycle_reg;
    first_cycle_next = first_cycle_reg;
    last_cycle_next = last_cycle_reg;
    first_be_next = first_be_reg;
    last_be_next = last_be_reg;
    offset_next = offset_reg;
    first_cycle_offset_next = first_cycle_offset_reg;
    last_cycle_offset_next = last_cycle_offset_reg;

    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;

    m_axi_wdata_int = shift_axis_tdata;
    m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b1}};
    m_axi_wvalid_int = 1'b0;
    m_axi_wlast_int = 1'b0;

    status_error_uncor_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state, wait for completion request
            if (AXIS_PCIE_DATA_WIDTH > 64) begin
                s_axis_cq_tready_next = m_axi_wready_int_early && (!m_axi_awvalid || m_axi_awready);

                if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                    transfer_in_save = 1'b1;

                    // header fields
                    axi_addr_next = {s_axis_cq_tdata[63:2], 2'b00};
                    op_dword_count_next = s_axis_cq_tdata[74:64];
                    type_next = s_axis_cq_tdata[78:75];

                    // tuser fields
                    if (AXIS_PCIE_DATA_WIDTH == 512) begin
                        first_be_next = s_axis_cq_tuser[3:0];
                        last_be_next = s_axis_cq_tuser[11:8];
                    end else begin
                        first_be_next = s_axis_cq_tuser[3:0];
                        last_be_next = s_axis_cq_tuser[7:4];
                    end

                    if (op_dword_count_next == 1) begin
                        // use first_be for both byte enables for single DWORD transfers
                        last_be_next = first_be_next;
                    end

                    if (op_dword_count_next <= AXI_MAX_BURST_SIZE/4) begin
                        // packet smaller than max burst size
                        // assumed to not cross 4k boundary, send one request
                        tr_dword_count_next = op_dword_count_next;
                        m_axi_awlen_next = (tr_dword_count_next + axi_addr_next[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                    end else begin
                        // packet larger than max burst size
                        // assumed to not cross 4k boundary, send one request
                        tr_dword_count_next = AXI_MAX_BURST_SIZE/4 - axi_addr_next[OFFSET_WIDTH+2-1:2];
                        m_axi_awlen_next = (tr_dword_count_next - 1) >> (AXI_BURST_SIZE-2);
                    end

                    m_axi_awaddr_next = axi_addr_next;

                    // required DWORD shift to place first DWORD from the TLP payload into proper position on AXI interface
                    // bubble cycle required if first TLP payload transfer does not fill first AXI transfer
                    if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                        offset_next = axi_addr_next[OFFSET_WIDTH+2-1:2] - 4;
                        bubble_cycle_next = axi_addr_next[OFFSET_WIDTH+2-1:2] < 4;
                    end else begin
                        offset_next = axi_addr_next[OFFSET_WIDTH+2-1:2];
                        bubble_cycle_next = 1'b0;
                    end
                    first_cycle_offset_next = axi_addr_next[OFFSET_WIDTH+2-1:2];
                    first_cycle_next = 1'b1;

                    // number of bus transfers in TLP, DOWRD count plus payload start DWORD offset, divided by bus width in DWORDS
                    if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                        input_cycle_count_next = (tr_dword_count_next + 4 - 1) >> (AXI_BURST_SIZE-2);
                    end else begin
                        input_cycle_count_next = (tr_dword_count_next - 1) >> (AXI_BURST_SIZE-2);
                    end
                    // number of bus transfers to AXI, DWORD count plus DWORD offset, divided by bus width in DWORDS
                    output_cycle_count_next = (tr_dword_count_next + axi_addr_next[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                    last_cycle_offset_next = axi_addr_next[OFFSET_WIDTH+2-1:2] + tr_dword_count_next;
                    last_cycle_next = output_cycle_count_next == 0;
                    input_active_next = 1'b1;

                    axi_addr_next = axi_addr_next + (tr_dword_count_next << 2);
                    op_dword_count_next = op_dword_count_next - tr_dword_count_next;

                    if (type_next == REQ_MEM_WRITE) begin
                        // write request
                        m_axi_awvalid_next = 1'b1;
                        if (AXIS_PCIE_DATA_WIDTH >= 256) begin
                            // some data is transferred with header
                            input_active_next = input_cycle_count_next > 0;
                            input_cycle_count_next = input_cycle_count_next - 1;
                            s_axis_cq_tready_next = 1'b0;
                            state_next = STATE_TRANSFER;
                        end else begin
                            s_axis_cq_tready_next = m_axi_wready_int_early;
                            state_next = STATE_TRANSFER;
                        end
                    end else begin
                        // invalid request
                        status_error_uncor_next = 1'b1;
                        if (s_axis_cq_tlast) begin
                            state_next = STATE_IDLE;
                        end else begin
                            s_axis_cq_tready_next = 1'b1;
                            state_next = STATE_WAIT_END;
                        end
                    end
                end else begin
                    state_next = STATE_IDLE;
                end
            end else begin
                s_axis_cq_tready_next = !m_axi_awvalid || m_axi_awready;

                if (s_axis_cq_tready & s_axis_cq_tvalid) begin
                    // header fields
                    axi_addr_next = {s_axis_cq_tdata[63:2], 2'b00};

                    // tuser fields
                    first_be_next = s_axis_cq_tuser[3:0];
                    last_be_next = s_axis_cq_tuser[7:4];

                    state_next = STATE_HEADER;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
        end
        STATE_HEADER: begin
            // header state, store rest of header (64 bit interface only)
            s_axis_cq_tready_next = m_axi_wready_int_early;

            if (s_axis_cq_tready && s_axis_cq_tvalid) begin
                transfer_in_save = 1'b1;

                // header fields
                op_dword_count_next = s_axis_cq_tdata[10:0];
                type_next = s_axis_cq_tdata[14:11];

                if (op_dword_count_next == 1) begin
                    // use first_be for both byte enables for single DWORD transfers
                    last_be_next = first_be_reg;
                end

                if (op_dword_count_next <= AXI_MAX_BURST_SIZE/4) begin
                    // packet smaller than max burst size (only for 64 bits)
                    // assumed to not cross 4k boundary, send one request
                    tr_dword_count_next = op_dword_count_next;
                end else begin
                    // packet larger than max burst size
                    // assumed to not cross 4k boundary, send one request
                    tr_dword_count_next = AXI_MAX_BURST_SIZE/4 - axi_addr_reg[OFFSET_WIDTH+2-1:2];
                end

                // required DWORD shift to place first DWORD from the TLP payload into proper position on AXI interface
                // bubble cycle required if first TLP payload transfer does not fill first AXI transfer
                offset_next = axi_addr_reg[OFFSET_WIDTH+2-1:2];
                bubble_cycle_next = 1'b0;
                first_cycle_offset_next = axi_addr_reg[OFFSET_WIDTH+2-1:2];
                first_cycle_next = 1'b1;

                // number of bus transfers in TLP, DOWRD count plus payload start DWORD offset, divided by bus width in DWORDS
                input_cycle_count_next = (tr_dword_count_next - 1) >> (AXI_BURST_SIZE-2);
                // number of bus transfers to AXI, DWORD count plus DWORD offset, divided by bus width in DWORDS
                output_cycle_count_next = (tr_dword_count_next + axi_addr_reg[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                last_cycle_offset_next = axi_addr_reg[OFFSET_WIDTH+2-1:2] + tr_dword_count_next;
                last_cycle_next = output_cycle_count_next == 0;
                input_active_next = 1'b1;

                m_axi_awaddr_next = axi_addr_reg;
                m_axi_awlen_next = output_cycle_count_next;

                axi_addr_next = axi_addr_reg + (tr_dword_count_next << 2);
                op_dword_count_next = op_dword_count_next - tr_dword_count_next;

                if (type_next == REQ_MEM_WRITE) begin
                    // write request
                    m_axi_awvalid_next = 1'b1;
                    s_axis_cq_tready_next = m_axi_wready_int_early;
                    state_next = STATE_TRANSFER;
                end else begin
                    // invalid request
                    status_error_uncor_next = 1'b1;
                    if (s_axis_cq_tlast) begin
                        state_next = STATE_IDLE;
                    end else begin
                        s_axis_cq_tready_next = 1'b1;
                        state_next = STATE_WAIT_END;
                    end
                end
            end else begin
                state_next = STATE_HEADER;
            end
        end
        STATE_TRANSFER: begin
            // transfer state, transfer data
            s_axis_cq_tready_next = m_axi_wready_int_early && input_active_reg && !(AXIS_PCIE_DATA_WIDTH >= 256 && first_cycle_reg && !bubble_cycle_reg);

            if (m_axi_wready_int_reg && ((s_axis_cq_tready && s_axis_cq_tvalid) || !input_active_reg || (AXIS_PCIE_DATA_WIDTH >= 256 && first_cycle_reg && !bubble_cycle_reg))) begin
                transfer_in_save = s_axis_cq_tready && s_axis_cq_tvalid;

                // transfer data
                if (AXIS_PCIE_DATA_WIDTH >= 256 && first_cycle_reg && !bubble_cycle_reg) begin
                    m_axi_wdata_int = {save_axis_tdata_reg, {AXIS_PCIE_DATA_WIDTH{1'b0}}} >> ((AXI_STRB_WIDTH/4-offset_reg)*32);
                    s_axis_cq_tready_next = m_axi_wready_int_early && input_active_reg;
                end else begin
                    m_axi_wdata_int = shift_axis_tdata;
                end
                // generate strb signal
                if (first_cycle_reg) begin
                    m_axi_wstrb_int = {{AXI_STRB_WIDTH-4{1'b1}}, first_be_reg} << (first_cycle_offset_reg*4);
                end else begin
                    m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b1}};
                end

                // update cycle counters
                if (input_active_reg && !(AXIS_PCIE_DATA_WIDTH >= 256 && first_cycle_reg && !bubble_cycle_reg)) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_reg > 0;
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
                    s_axis_cq_tready_next = m_axi_wready_int_early && input_active_next;
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
                        // assumed to not cross 4k boundary, send one request
                        tr_dword_count_next = AXI_MAX_BURST_SIZE/4 - axi_addr_reg[OFFSET_WIDTH+2-1:2];
                        m_axi_awlen_next = (tr_dword_count_next - 1) >> (AXI_BURST_SIZE-2);
                    end

                    m_axi_awaddr_next = axi_addr_reg;

                    // keep offset, no bubble cycles, not first cycle
                    bubble_cycle_next = 1'b0;
                    first_cycle_next = 1'b0;

                    // number of bus transfers in TLP, DOWRD count minus payload start DWORD offset, divided by bus width in DWORDS
                    input_cycle_count_next = (tr_dword_count_next - offset_reg - 1) >> (AXI_BURST_SIZE-2);
                    // number of bus transfers to AXI, DWORD count plus DWORD offset, divided by bus width in DWORDS
                    output_cycle_count_next = (tr_dword_count_next + axi_addr_reg[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
                    last_cycle_offset_next = axi_addr_reg[OFFSET_WIDTH+2-1:2] + tr_dword_count_next;
                    last_cycle_next = output_cycle_count_next == 0;
                    input_active_next = tr_dword_count_next > offset_reg;

                    axi_addr_next = axi_addr_reg + (tr_dword_count_next << 2);
                    op_dword_count_next = op_dword_count_reg - tr_dword_count_next;

                    m_axi_awvalid_next = 1'b1;
                    s_axis_cq_tready_next = m_axi_wready_int_early && input_active_next;
                    state_next = STATE_TRANSFER;
                end else begin
                    s_axis_cq_tready_next = m_axi_wready_int_early && (!m_axi_awvalid || m_axi_awready);
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_TRANSFER;
            end
        end
        STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            s_axis_cq_tready_next = 1'b1;

            if (s_axis_cq_tready & s_axis_cq_tvalid) begin
                if (s_axis_cq_tlast) begin
                    if (AXIS_PCIE_DATA_WIDTH > 64) begin
                        s_axis_cq_tready_next = m_axi_wready_int_early && (!m_axi_awvalid || m_axi_awready);
                    end else begin
                        s_axis_cq_tready_next = 1'b1;
                    end
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
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_axis_cq_tready_reg <= 1'b0;

        m_axi_awvalid_reg <= 1'b0;

        status_error_uncor_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        s_axis_cq_tready_reg <= s_axis_cq_tready_next;

        m_axi_awvalid_reg <= m_axi_awvalid_next;

        status_error_uncor_reg <= status_error_uncor_next;
    end

    axi_addr_reg <= axi_addr_next;
    op_dword_count_reg <= op_dword_count_next;
    tr_dword_count_reg <= tr_dword_count_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    bubble_cycle_reg <= bubble_cycle_next;
    first_cycle_reg <= first_cycle_next;
    last_cycle_reg <= last_cycle_next;

    type_reg <= type_next;
    first_be_reg <= first_be_next;
    last_be_reg <= last_be_next;
    offset_reg <= offset_next;
    first_cycle_offset_reg <= first_cycle_offset_next;
    last_cycle_offset_reg <= last_cycle_offset_next;

    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;

    if (transfer_in_save) begin
        save_axis_tdata_reg <= s_axis_cq_tdata;
    end
end

// output datapath logic (AXI write data)
reg [AXI_DATA_WIDTH-1:0] m_axi_wdata_reg = {AXI_DATA_WIDTH{1'b0}};
reg [AXI_STRB_WIDTH-1:0] m_axi_wstrb_reg = {AXI_STRB_WIDTH{1'b0}};
reg                      m_axi_wvalid_reg = 1'b0, m_axi_wvalid_next;
reg                      m_axi_wlast_reg = 1'b0;

reg [AXI_DATA_WIDTH-1:0] temp_m_axi_wdata_reg = {AXI_DATA_WIDTH{1'b0}};
reg [AXI_STRB_WIDTH-1:0] temp_m_axi_wstrb_reg = {AXI_STRB_WIDTH{1'b0}};
reg                      temp_m_axi_wvalid_reg = 1'b0, temp_m_axi_wvalid_next;
reg                      temp_m_axi_wlast_reg = 1'b0;

// datapath control
reg store_axi_w_int_to_output;
reg store_axi_w_int_to_temp;
reg store_axi_w_temp_to_output;

assign m_axi_wdata = m_axi_wdata_reg;
assign m_axi_wstrb = m_axi_wstrb_reg;
assign m_axi_wvalid = m_axi_wvalid_reg;
assign m_axi_wlast = m_axi_wlast_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axi_wready_int_early = m_axi_wready || (!temp_m_axi_wvalid_reg && (!m_axi_wvalid_reg || !m_axi_wvalid_int));

always @* begin
    // transfer sink ready state to source
    m_axi_wvalid_next = m_axi_wvalid_reg;
    temp_m_axi_wvalid_next = temp_m_axi_wvalid_reg;

    store_axi_w_int_to_output = 1'b0;
    store_axi_w_int_to_temp = 1'b0;
    store_axi_w_temp_to_output = 1'b0;
    
    if (m_axi_wready_int_reg) begin
        // input is ready
        if (m_axi_wready || !m_axi_wvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axi_wvalid_next = m_axi_wvalid_int;
            store_axi_w_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axi_wvalid_next = m_axi_wvalid_int;
            store_axi_w_int_to_temp = 1'b1;
        end
    end else if (m_axi_wready) begin
        // input is not ready, but output is ready
        m_axi_wvalid_next = temp_m_axi_wvalid_reg;
        temp_m_axi_wvalid_next = 1'b0;
        store_axi_w_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axi_wvalid_reg <= 1'b0;
        m_axi_wready_int_reg <= 1'b0;
        temp_m_axi_wvalid_reg <= 1'b0;
    end else begin
        m_axi_wvalid_reg <= m_axi_wvalid_next;
        m_axi_wready_int_reg <= m_axi_wready_int_early;
        temp_m_axi_wvalid_reg <= temp_m_axi_wvalid_next;
    end

    // datapath
    if (store_axi_w_int_to_output) begin
        m_axi_wdata_reg <= m_axi_wdata_int;
        m_axi_wstrb_reg <= m_axi_wstrb_int;
        m_axi_wlast_reg <= m_axi_wlast_int;
    end else if (store_axi_w_temp_to_output) begin
        m_axi_wdata_reg <= temp_m_axi_wdata_reg;
        m_axi_wstrb_reg <= temp_m_axi_wstrb_reg;
        m_axi_wlast_reg <= temp_m_axi_wlast_reg;
    end

    if (store_axi_w_int_to_temp) begin
        temp_m_axi_wdata_reg <= m_axi_wdata_int;
        temp_m_axi_wstrb_reg <= m_axi_wstrb_int;
        temp_m_axi_wlast_reg <= m_axi_wlast_int;
    end
end

endmodule

`resetall
