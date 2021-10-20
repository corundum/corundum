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
 * AXI4 Central DMA
 */
module axi_cdma #
(
    // Width of data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
    // Width of length field
    parameter LEN_WIDTH = 20,
    // Width of tag field
    parameter TAG_WIDTH = 8,
    // Enable support for unaligned transfers
    parameter ENABLE_UNALIGNED = 0
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * AXI descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_desc_read_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_desc_write_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_desc_tag,
    input  wire                       s_axis_desc_valid,
    output wire                       s_axis_desc_ready,

    /*
     * AXI descriptor status output
     */
    output wire [TAG_WIDTH-1:0]       m_axis_desc_status_tag,
    output wire [3:0]                 m_axis_desc_status_error,
    output wire                       m_axis_desc_status_valid,

    /*
     * AXI write master interface
     */
    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,

    /*
     * AXI read master interface
     */
    output wire [AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready,

    /*
     * Configuration
     */
    input  wire                       enable
);

parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

parameter OFFSET_WIDTH = AXI_STRB_WIDTH > 1 ? $clog2(AXI_STRB_WIDTH) : 1;
parameter OFFSET_MASK = AXI_STRB_WIDTH > 1 ? {OFFSET_WIDTH{1'b1}} : 0;
parameter ADDR_MASK = {AXI_ADDR_WIDTH{1'b1}} << $clog2(AXI_STRB_WIDTH);
parameter CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1;

parameter STATUS_FIFO_ADDR_WIDTH = 5;
parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

// bus width assertions
initial begin
    if (AXI_WORD_SIZE * AXI_STRB_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisble (instance %m)");
        $finish;
    end

    if (2**$clog2(AXI_WORD_WIDTH) != AXI_WORD_WIDTH) begin
        $error("Error: AXI word width must be even power of two (instance %m)");
        $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
        $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
        $finish;
    end
end

localparam [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

localparam [3:0]
    DMA_ERROR_NONE = 4'd0,
    DMA_ERROR_TIMEOUT = 4'd1,
    DMA_ERROR_PARITY = 4'd2,
    DMA_ERROR_AXI_RD_SLVERR = 4'd4,
    DMA_ERROR_AXI_RD_DECERR = 4'd5,
    DMA_ERROR_AXI_WR_SLVERR = 4'd6,
    DMA_ERROR_AXI_WR_DECERR = 4'd7,
    DMA_ERROR_PCIE_FLR = 4'd8,
    DMA_ERROR_PCIE_CPL_POISONED = 4'd9,
    DMA_ERROR_PCIE_CPL_STATUS_UR = 4'd10,
    DMA_ERROR_PCIE_CPL_STATUS_CA = 4'd11;

localparam [1:0]
    READ_STATE_IDLE = 2'd0,
    READ_STATE_START = 2'd1,
    READ_STATE_REQ = 2'd2;

reg [1:0] read_state_reg = READ_STATE_IDLE, read_state_next;

localparam [0:0]
    AXI_STATE_IDLE = 1'd0,
    AXI_STATE_WRITE = 1'd1;

reg [0:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

// datapath control signals
reg transfer_in_save;
reg axi_cmd_ready;
reg status_fifo_we;

reg [AXI_ADDR_WIDTH-1:0] read_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, read_addr_next;
reg [AXI_ADDR_WIDTH-1:0] write_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, write_addr_next;
reg [LEN_WIDTH-1:0] op_word_count_reg = {LEN_WIDTH{1'b0}}, op_word_count_next;
reg [LEN_WIDTH-1:0] tr_word_count_reg = {LEN_WIDTH{1'b0}}, tr_word_count_next;
reg [LEN_WIDTH-1:0] axi_word_count_reg = {LEN_WIDTH{1'b0}}, axi_word_count_next;

reg [AXI_ADDR_WIDTH-1:0] axi_cmd_addr_reg = {AXI_ADDR_WIDTH{1'b0}}, axi_cmd_addr_next;
reg [OFFSET_WIDTH-1:0] axi_cmd_offset_reg = {OFFSET_WIDTH{1'b0}}, axi_cmd_offset_next;
reg [OFFSET_WIDTH-1:0] axi_cmd_first_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, axi_cmd_first_cycle_offset_next;
reg [OFFSET_WIDTH-1:0] axi_cmd_last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, axi_cmd_last_cycle_offset_next;
reg [CYCLE_COUNT_WIDTH-1:0] axi_cmd_input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, axi_cmd_input_cycle_count_next;
reg [CYCLE_COUNT_WIDTH-1:0] axi_cmd_output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, axi_cmd_output_cycle_count_next;
reg axi_cmd_bubble_cycle_reg = 1'b0, axi_cmd_bubble_cycle_next;
reg axi_cmd_last_transfer_reg = 1'b0, axi_cmd_last_transfer_next;
reg [TAG_WIDTH-1:0] axi_cmd_tag_reg = {TAG_WIDTH{1'b0}}, axi_cmd_tag_next;
reg axi_cmd_valid_reg = 1'b0, axi_cmd_valid_next;

reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
reg [OFFSET_WIDTH-1:0] first_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, first_cycle_offset_next;
reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;
reg [CYCLE_COUNT_WIDTH-1:0] input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, input_cycle_count_next;
reg [CYCLE_COUNT_WIDTH-1:0] output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, output_cycle_count_next;
reg input_active_reg = 1'b0, input_active_next;
reg output_active_reg = 1'b0, output_active_next;
reg bubble_cycle_reg = 1'b0, bubble_cycle_next;
reg first_input_cycle_reg = 1'b0, first_input_cycle_next;
reg first_output_cycle_reg = 1'b0, first_output_cycle_next;
reg output_last_cycle_reg = 1'b0, output_last_cycle_next;
reg last_transfer_reg = 1'b0, last_transfer_next;
reg [1:0] rresp_reg = AXI_RESP_OKAY, rresp_next;
reg [1:0] bresp_reg = AXI_RESP_OKAY, bresp_next;

reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_wr_ptr_reg = 0;
reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] status_fifo_rd_ptr_reg = 0, status_fifo_rd_ptr_next;
reg [TAG_WIDTH-1:0] status_fifo_tag[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [1:0] status_fifo_resp[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg status_fifo_last[(2**STATUS_FIFO_ADDR_WIDTH)-1:0];
reg [TAG_WIDTH-1:0] status_fifo_wr_tag;
reg [1:0] status_fifo_wr_resp;
reg status_fifo_wr_last;

reg [STATUS_FIFO_ADDR_WIDTH+1-1:0] active_count_reg = 0;
reg active_count_av_reg = 1'b1;
reg inc_active;
reg dec_active;

reg s_axis_desc_ready_reg = 1'b0, s_axis_desc_ready_next;

reg [TAG_WIDTH-1:0] m_axis_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_desc_status_tag_next;
reg [3:0] m_axis_desc_status_error_reg = 4'd0, m_axis_desc_status_error_next;
reg m_axis_desc_status_valid_reg = 1'b0, m_axis_desc_status_valid_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
reg m_axi_rready_reg = 1'b0, m_axi_rready_next;

reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_awaddr_next;
reg [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
reg m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;
reg m_axi_bready_reg = 1'b0, m_axi_bready_next;

reg [AXI_DATA_WIDTH-1:0] save_axi_rdata_reg = {AXI_DATA_WIDTH{1'b0}};

wire [AXI_DATA_WIDTH-1:0] shift_axi_rdata = {m_axi_rdata, save_axi_rdata_reg} >> ((AXI_STRB_WIDTH-offset_reg)*AXI_WORD_SIZE);

// internal datapath
reg  [AXI_DATA_WIDTH-1:0] m_axi_wdata_int;
reg  [AXI_STRB_WIDTH-1:0] m_axi_wstrb_int;
reg                       m_axi_wlast_int;
reg                       m_axi_wvalid_int;
wire                      m_axi_wready_int;

assign s_axis_desc_ready = s_axis_desc_ready_reg;

assign m_axis_desc_status_tag = m_axis_desc_status_tag_reg;
assign m_axis_desc_status_error = m_axis_desc_status_error_reg;
assign m_axis_desc_status_valid = m_axis_desc_status_valid_reg;

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

assign m_axi_awid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_awaddr = m_axi_awaddr_reg;
assign m_axi_awlen = m_axi_awlen_reg;
assign m_axi_awsize = AXI_BURST_SIZE;
assign m_axi_awburst = 2'b01;
assign m_axi_awlock = 1'b0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot = 3'b010;
assign m_axi_awvalid = m_axi_awvalid_reg;
assign m_axi_bready = m_axi_bready_reg;

always @* begin
    read_state_next = READ_STATE_IDLE;

    s_axis_desc_ready_next = 1'b0;

    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;

    read_addr_next = read_addr_reg;
    write_addr_next = write_addr_reg;
    op_word_count_next = op_word_count_reg;
    tr_word_count_next = tr_word_count_reg;
    axi_word_count_next = axi_word_count_reg;

    axi_cmd_addr_next = axi_cmd_addr_reg;
    axi_cmd_offset_next = axi_cmd_offset_reg;
    axi_cmd_first_cycle_offset_next = axi_cmd_first_cycle_offset_reg;
    axi_cmd_last_cycle_offset_next = axi_cmd_last_cycle_offset_reg;
    axi_cmd_input_cycle_count_next = axi_cmd_input_cycle_count_reg;
    axi_cmd_output_cycle_count_next = axi_cmd_output_cycle_count_reg;
    axi_cmd_bubble_cycle_next = axi_cmd_bubble_cycle_reg;
    axi_cmd_last_transfer_next = axi_cmd_last_transfer_reg;
    axi_cmd_tag_next = axi_cmd_tag_reg;
    axi_cmd_valid_next = axi_cmd_valid_reg && !axi_cmd_ready;

    inc_active = 1'b0;

    case (read_state_reg)
        READ_STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            s_axis_desc_ready_next = !axi_cmd_valid_reg && enable && active_count_av_reg;

            if (s_axis_desc_ready && s_axis_desc_valid) begin
                if (ENABLE_UNALIGNED) begin
                    read_addr_next = s_axis_desc_read_addr;
                    write_addr_next = s_axis_desc_write_addr;
                end else begin
                    read_addr_next = s_axis_desc_read_addr & ADDR_MASK;
                    write_addr_next = s_axis_desc_write_addr & ADDR_MASK;
                end
                axi_cmd_tag_next = s_axis_desc_tag;
                op_word_count_next = s_axis_desc_len;

                s_axis_desc_ready_next = 1'b0;
                read_state_next = READ_STATE_START;
            end else begin
                read_state_next = READ_STATE_IDLE;
            end
        end
        READ_STATE_START: begin
            // start state - compute write length
            if (!axi_cmd_valid_reg && active_count_av_reg) begin
                if (op_word_count_reg <= AXI_MAX_BURST_SIZE - (write_addr_reg & OFFSET_MASK)) begin
                    // packet smaller than max burst size
                    if (((write_addr_reg & 12'hfff) + (op_word_count_reg & 12'hfff)) >> 12 != 0 || op_word_count_reg >> 12 != 0) begin
                        // crosses 4k boundary
                        axi_word_count_next = 13'h1000 - (write_addr_reg & 12'hfff);
                    end else begin
                        // does not cross 4k boundary
                        axi_word_count_next = op_word_count_reg;
                    end
                end else begin
                    // packet larger than max burst size
                    if (((write_addr_reg & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
                        // crosses 4k boundary
                        axi_word_count_next = 13'h1000 - (write_addr_reg & 12'hfff);
                    end else begin
                        // does not cross 4k boundary
                        axi_word_count_next = AXI_MAX_BURST_SIZE - (write_addr_reg & OFFSET_MASK);
                    end
                end

                write_addr_next = write_addr_reg + axi_word_count_next;
                op_word_count_next = op_word_count_reg - axi_word_count_next;

                axi_cmd_addr_next = write_addr_reg;
                if (ENABLE_UNALIGNED) begin
                    axi_cmd_input_cycle_count_next = (axi_word_count_next + (read_addr_reg & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
                    axi_cmd_output_cycle_count_next = (axi_word_count_next + (write_addr_reg & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
                    axi_cmd_offset_next = (write_addr_reg & OFFSET_MASK) - (read_addr_reg & OFFSET_MASK);
                    axi_cmd_bubble_cycle_next = (read_addr_reg & OFFSET_MASK) > (write_addr_reg & OFFSET_MASK);
                    axi_cmd_first_cycle_offset_next = write_addr_reg & OFFSET_MASK;
                    axi_cmd_last_cycle_offset_next = axi_cmd_first_cycle_offset_next + axi_word_count_next & OFFSET_MASK;
                end else begin
                    axi_cmd_input_cycle_count_next = (axi_word_count_next - 1) >> AXI_BURST_SIZE;
                    axi_cmd_output_cycle_count_next = (axi_word_count_next - 1) >> AXI_BURST_SIZE;
                    axi_cmd_offset_next = 0;
                    axi_cmd_bubble_cycle_next = 0;
                    axi_cmd_first_cycle_offset_next = 0;
                    axi_cmd_last_cycle_offset_next = axi_word_count_next & OFFSET_MASK;
                end
                axi_cmd_last_transfer_next = op_word_count_next == 0;
                axi_cmd_valid_next = 1'b1;

                inc_active = 1'b1;

                read_state_next = READ_STATE_REQ;
            end else begin
                read_state_next = READ_STATE_START;
            end
        end
        READ_STATE_REQ: begin
            // request state - issue AXI read requests
            if (!m_axi_arvalid) begin
                if (axi_word_count_reg <= AXI_MAX_BURST_SIZE - (read_addr_reg & OFFSET_MASK)) begin
                    // packet smaller than max burst size
                    if (((read_addr_reg & 12'hfff) + (axi_word_count_reg & 12'hfff)) >> 12 != 0 || axi_word_count_reg >> 12 != 0) begin
                        // crosses 4k boundary
                        tr_word_count_next = 13'h1000 - (read_addr_reg & 12'hfff);
                    end else begin
                        // does not cross 4k boundary
                        tr_word_count_next = axi_word_count_reg;
                    end
                end else begin
                    // packet larger than max burst size
                    if (((read_addr_reg & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
                        // crosses 4k boundary
                        tr_word_count_next = 13'h1000 - (read_addr_reg & 12'hfff);
                    end else begin
                        // does not cross 4k boundary
                        tr_word_count_next = AXI_MAX_BURST_SIZE - (read_addr_reg & OFFSET_MASK);
                    end
                end

                m_axi_araddr_next = read_addr_reg;
                if (ENABLE_UNALIGNED) begin
                    m_axi_arlen_next = (tr_word_count_next + (read_addr_reg & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
                end else begin
                    m_axi_arlen_next = (tr_word_count_next - 1) >> AXI_BURST_SIZE;
                end
                m_axi_arvalid_next = 1'b1;

                read_addr_next = read_addr_reg + tr_word_count_next;
                axi_word_count_next = axi_word_count_reg - tr_word_count_next;

                if (axi_word_count_next > 0) begin
                    read_state_next = READ_STATE_REQ;
                end else if (op_word_count_next > 0) begin
                    read_state_next = READ_STATE_START;
                end else begin
                    s_axis_desc_ready_next = !axi_cmd_valid_reg && enable && active_count_av_reg;
                    read_state_next = READ_STATE_IDLE;
                end
            end else begin
                read_state_next = READ_STATE_REQ;
            end
        end
    endcase
end

always @* begin
    axi_state_next = AXI_STATE_IDLE;

    m_axis_desc_status_tag_next = m_axis_desc_status_tag_reg;
    m_axis_desc_status_error_next = m_axis_desc_status_error_reg;
    m_axis_desc_status_valid_next = 1'b0;

    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;
    m_axi_wdata_int = shift_axi_rdata;
    m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b0}};
    m_axi_wlast_int = 1'b0;
    m_axi_wvalid_int = 1'b0;
    m_axi_bready_next = 1'b0;

    m_axi_rready_next = 1'b0;

    transfer_in_save = 1'b0;
    axi_cmd_ready = 1'b0;
    status_fifo_we = 1'b0;

    offset_next = offset_reg;
    first_cycle_offset_next = first_cycle_offset_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    output_active_next = output_active_reg;
    bubble_cycle_next = bubble_cycle_reg;
    first_input_cycle_next = first_input_cycle_reg;
    first_output_cycle_next = first_output_cycle_reg;
    output_last_cycle_next = output_last_cycle_reg;
    last_transfer_next = last_transfer_reg;

    tag_next = tag_reg;

    status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg;

    dec_active = 1'b0;

    if (m_axi_rready && m_axi_rvalid && (m_axi_rresp == AXI_RESP_SLVERR || m_axi_rresp == AXI_RESP_DECERR)) begin
        rresp_next = m_axi_rresp;
    end else begin
        rresp_next = rresp_reg;
    end

    if (m_axi_bready && m_axi_bvalid && (m_axi_bresp == AXI_RESP_SLVERR || m_axi_bresp == AXI_RESP_DECERR)) begin
        bresp_next = m_axi_bresp;
    end else begin
        bresp_next = bresp_reg;
    end

    status_fifo_wr_tag = tag_reg;
    status_fifo_wr_resp = rresp_next;
    status_fifo_wr_last = 1'b0;

    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            m_axi_rready_next = 1'b0;

            // store transfer parameters
            if (ENABLE_UNALIGNED) begin
                offset_next = axi_cmd_offset_reg;
                first_cycle_offset_next = axi_cmd_first_cycle_offset_reg;
            end else begin
                offset_next = 0;
                first_cycle_offset_next = 0;
            end
            last_cycle_offset_next = axi_cmd_last_cycle_offset_reg;
            input_cycle_count_next = axi_cmd_input_cycle_count_reg;
            output_cycle_count_next = axi_cmd_output_cycle_count_reg;
            bubble_cycle_next = axi_cmd_bubble_cycle_reg;
            last_transfer_next = axi_cmd_last_transfer_reg;
            tag_next = axi_cmd_tag_reg;

            output_last_cycle_next = output_cycle_count_next == 0;
            input_active_next = 1'b1;
            output_active_next = 1'b1;
            first_input_cycle_next = 1'b1;
            first_output_cycle_next = 1'b1;

            if (!m_axi_awvalid && axi_cmd_valid_reg) begin
                axi_cmd_ready = 1'b1;

                m_axi_awaddr_next = axi_cmd_addr_reg;
                m_axi_awlen_next = axi_cmd_output_cycle_count_reg;
                m_axi_awvalid_next = 1'b1;

                m_axi_rready_next = m_axi_wready_int;
                axi_state_next = AXI_STATE_WRITE;
            end
        end
        AXI_STATE_WRITE: begin
            // handle AXI read data
            m_axi_rready_next = m_axi_wready_int && input_active_reg;

            if ((m_axi_rready && m_axi_rvalid) || !input_active_reg) begin
                // transfer in AXI read data
                transfer_in_save = m_axi_rready && m_axi_rvalid;

                if (ENABLE_UNALIGNED && first_input_cycle_reg && bubble_cycle_reg) begin
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg > 0;
                    end
                    bubble_cycle_next = 1'b0;
                    first_input_cycle_next = 1'b0;

                    m_axi_rready_next = m_axi_wready_int && input_active_next;
                    axi_state_next = AXI_STATE_WRITE;
                end else begin
                    // update counters
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg > 0;
                    end
                    if (output_active_reg) begin
                        output_cycle_count_next = output_cycle_count_reg - 1;
                        output_active_next = output_cycle_count_reg > 0;
                    end
                    output_last_cycle_next = output_cycle_count_next == 0;
                    bubble_cycle_next = 1'b0;
                    first_input_cycle_next = 1'b0;
                    first_output_cycle_next = 1'b0;

                    // pass through read data
                    m_axi_wdata_int = shift_axi_rdata;
                    if (first_output_cycle_reg) begin
                        m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b1}} << first_cycle_offset_reg;
                    end else begin
                        m_axi_wstrb_int = {AXI_STRB_WIDTH{1'b1}};
                    end
                    m_axi_wvalid_int = 1'b1;

                    if (output_last_cycle_reg) begin
                        // no more data to transfer, finish operation
                        if (last_cycle_offset_reg > 0) begin
                            m_axi_wstrb_int = m_axi_wstrb_int & {AXI_STRB_WIDTH{1'b1}} >> (AXI_STRB_WIDTH - last_cycle_offset_reg);
                        end
                        m_axi_wlast_int = 1'b1;

                        status_fifo_we = 1'b1;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_resp = rresp_next;
                        status_fifo_wr_last = last_transfer_reg;

                        if (last_transfer_reg) begin
                            rresp_next = AXI_RESP_OKAY;
                        end

                        m_axi_rready_next = 1'b0;
                        axi_state_next = AXI_STATE_IDLE;
                    end else begin
                        // more cycles in AXI transfer
                        axi_state_next = AXI_STATE_WRITE;
                    end
                end
            end else begin
                axi_state_next = AXI_STATE_WRITE;
            end
        end
    endcase

    if (status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin
        // status FIFO not empty
        if (m_axi_bready && m_axi_bvalid) begin
            // got write completion, pop and return status
            m_axis_desc_status_tag_next = status_fifo_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
            if (status_fifo_resp[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] == AXI_RESP_SLVERR) begin
                m_axis_desc_status_error_next = DMA_ERROR_AXI_RD_SLVERR;
            end else if (status_fifo_resp[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] == AXI_RESP_DECERR) begin
                m_axis_desc_status_error_next = DMA_ERROR_AXI_RD_DECERR;
            end else if (bresp_next == AXI_RESP_SLVERR) begin
                m_axis_desc_status_error_next = DMA_ERROR_AXI_WR_SLVERR;
            end else if (bresp_next == AXI_RESP_DECERR) begin
                m_axis_desc_status_error_next = DMA_ERROR_AXI_WR_DECERR;
            end else begin
                m_axis_desc_status_error_next = DMA_ERROR_NONE;
            end
            m_axis_desc_status_valid_next = status_fifo_last[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]];
            status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg + 1;
            m_axi_bready_next = 1'b0;

            if (status_fifo_last[status_fifo_rd_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]]) begin
                bresp_next = AXI_RESP_OKAY;
            end

            dec_active = 1'b1;
        end else begin
            // wait for write completion
            m_axi_bready_next = 1'b1;
        end
    end
end

always @(posedge clk) begin
    read_state_reg <= read_state_next;
    axi_state_reg <= axi_state_next;

    s_axis_desc_ready_reg <= s_axis_desc_ready_next;

    m_axis_desc_status_tag_reg <= m_axis_desc_status_tag_next;
    m_axis_desc_status_error_reg <= m_axis_desc_status_error_next;
    m_axis_desc_status_valid_reg <= m_axis_desc_status_valid_next;

    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;
    m_axi_awvalid_reg <= m_axi_awvalid_next;
    m_axi_bready_reg <= m_axi_bready_next;
    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;
    m_axi_arvalid_reg <= m_axi_arvalid_next;
    m_axi_rready_reg <= m_axi_rready_next;

    read_addr_reg <= read_addr_next;
    write_addr_reg <= write_addr_next;
    op_word_count_reg <= op_word_count_next;
    tr_word_count_reg <= tr_word_count_next;
    axi_word_count_reg <= axi_word_count_next;

    axi_cmd_addr_reg <= axi_cmd_addr_next;
    axi_cmd_offset_reg <= axi_cmd_offset_next;
    axi_cmd_first_cycle_offset_reg <= axi_cmd_first_cycle_offset_next;
    axi_cmd_last_cycle_offset_reg <= axi_cmd_last_cycle_offset_next;
    axi_cmd_input_cycle_count_reg <= axi_cmd_input_cycle_count_next;
    axi_cmd_output_cycle_count_reg <= axi_cmd_output_cycle_count_next;
    axi_cmd_bubble_cycle_reg <= axi_cmd_bubble_cycle_next;
    axi_cmd_last_transfer_reg <= axi_cmd_last_transfer_next;
    axi_cmd_tag_reg <= axi_cmd_tag_next;
    axi_cmd_valid_reg <= axi_cmd_valid_next;

    offset_reg <= offset_next;
    first_cycle_offset_reg <= first_cycle_offset_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    output_active_reg <= output_active_next;
    bubble_cycle_reg <= bubble_cycle_next;
    first_input_cycle_reg <= first_input_cycle_next;
    first_output_cycle_reg <= first_output_cycle_next;
    output_last_cycle_reg <= output_last_cycle_next;
    last_transfer_reg <= last_transfer_next;
    rresp_reg <= rresp_next;
    bresp_reg <= bresp_next;

    tag_reg <= tag_next;

    if (transfer_in_save) begin
        save_axi_rdata_reg <= m_axi_rdata;
    end

    if (status_fifo_we) begin
        status_fifo_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_tag;
        status_fifo_resp[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_resp;
        status_fifo_last[status_fifo_wr_ptr_reg[STATUS_FIFO_ADDR_WIDTH-1:0]] <= status_fifo_wr_last;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end
    status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_next;

    if (active_count_reg < 2**STATUS_FIFO_ADDR_WIDTH && inc_active && !dec_active) begin
        active_count_reg <= active_count_reg + 1;
        active_count_av_reg <= active_count_reg < (2**STATUS_FIFO_ADDR_WIDTH-1);
    end else if (active_count_reg > 0 && !inc_active && dec_active) begin
        active_count_reg <= active_count_reg - 1;
        active_count_av_reg <= 1'b1;
    end else begin
        active_count_av_reg <= active_count_reg < 2**STATUS_FIFO_ADDR_WIDTH;
    end

    if (rst) begin
        read_state_reg <= READ_STATE_IDLE;
        axi_state_reg <= AXI_STATE_IDLE;

        s_axis_desc_ready_reg <= 1'b0;
        m_axis_desc_status_valid_reg <= 1'b0;

        m_axi_awvalid_reg <= 1'b0;
        m_axi_bready_reg <= 1'b0;
        m_axi_arvalid_reg <= 1'b0;
        m_axi_rready_reg <= 1'b0;

        axi_cmd_valid_reg <= 1'b0;

        rresp_reg <= AXI_RESP_OKAY;
        bresp_reg <= AXI_RESP_OKAY;

        status_fifo_wr_ptr_reg <= 0;
        status_fifo_rd_ptr_reg <= 0;

        active_count_reg <= 0;
        active_count_av_reg <= 1'b1;
    end
end

// output datapath logic
reg [AXI_DATA_WIDTH-1:0] m_axi_wdata_reg  = {AXI_DATA_WIDTH{1'b0}};
reg [AXI_STRB_WIDTH-1:0] m_axi_wstrb_reg  = {AXI_STRB_WIDTH{1'b0}};
reg                      m_axi_wlast_reg  = 1'b0;
reg                      m_axi_wvalid_reg = 1'b0;

reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
reg out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed" *)
reg [AXI_DATA_WIDTH-1:0] out_fifo_wdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
reg [AXI_STRB_WIDTH-1:0] out_fifo_wstrb[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
(* ram_style = "distributed" *)
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
