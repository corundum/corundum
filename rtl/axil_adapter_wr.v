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
 * AXI4 lite width adapter (write)
 */
module axil_adapter_wr #
(
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) interface data bus in bits
    parameter S_DATA_WIDTH = 32,
    // Width of input (slave) interface wstrb (width of data bus in words)
    parameter S_STRB_WIDTH = (S_DATA_WIDTH/8),
    // Width of output (master) interface data bus in bits
    parameter M_DATA_WIDTH = 32,
    // Width of output (master) interface wstrb (width of data bus in words)
    parameter M_STRB_WIDTH = (M_DATA_WIDTH/8)
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire [2:0]               s_axil_awprot,
    input  wire                     s_axil_awvalid,
    output wire                     s_axil_awready,
    input  wire [S_DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [S_STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                     s_axil_wvalid,
    output wire                     s_axil_wready,
    output wire [1:0]               s_axil_bresp,
    output wire                     s_axil_bvalid,
    input  wire                     s_axil_bready,

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]    m_axil_awaddr,
    output wire [2:0]               m_axil_awprot,
    output wire                     m_axil_awvalid,
    input  wire                     m_axil_awready,
    output wire [M_DATA_WIDTH-1:0]  m_axil_wdata,
    output wire [M_STRB_WIDTH-1:0]  m_axil_wstrb,
    output wire                     m_axil_wvalid,
    input  wire                     m_axil_wready,
    input  wire [1:0]               m_axil_bresp,
    input  wire                     m_axil_bvalid,
    output wire                     m_axil_bready
);

parameter S_ADDR_BIT_OFFSET = $clog2(S_STRB_WIDTH);
parameter M_ADDR_BIT_OFFSET = $clog2(M_STRB_WIDTH);
parameter S_WORD_WIDTH = S_STRB_WIDTH;
parameter M_WORD_WIDTH = M_STRB_WIDTH;
parameter S_WORD_SIZE = S_DATA_WIDTH/S_WORD_WIDTH;
parameter M_WORD_SIZE = M_DATA_WIDTH/M_WORD_WIDTH;

// output bus is wider
parameter EXPAND = M_STRB_WIDTH > S_STRB_WIDTH;
parameter DATA_WIDTH = EXPAND ? M_DATA_WIDTH : S_DATA_WIDTH;
parameter STRB_WIDTH = EXPAND ? M_STRB_WIDTH : S_STRB_WIDTH;
// required number of segments in wider bus
parameter SEGMENT_COUNT = EXPAND ? (M_STRB_WIDTH / S_STRB_WIDTH) : (S_STRB_WIDTH / M_STRB_WIDTH);
parameter SEGMENT_COUNT_WIDTH = SEGMENT_COUNT == 1 ? 1 : $clog2(SEGMENT_COUNT);
// data width and keep width per segment
parameter SEGMENT_DATA_WIDTH = DATA_WIDTH / SEGMENT_COUNT;
parameter SEGMENT_STRB_WIDTH = STRB_WIDTH / SEGMENT_COUNT;

// bus width assertions
initial begin
    if (S_WORD_SIZE * S_STRB_WIDTH != S_DATA_WIDTH) begin
        $error("Error: AXI slave interface data width not evenly divisble (instance %m)");
        $finish;
    end

    if (M_WORD_SIZE * M_STRB_WIDTH != M_DATA_WIDTH) begin
        $error("Error: AXI master interface data width not evenly divisble (instance %m)");
        $finish;
    end

    if (S_WORD_SIZE != M_WORD_SIZE) begin
        $error("Error: word size mismatch (instance %m)");
        $finish;
    end

    if (2**$clog2(S_WORD_WIDTH) != S_WORD_WIDTH) begin
        $error("Error: AXI slave interface word width must be even power of two (instance %m)");
        $finish;
    end

    if (2**$clog2(M_WORD_WIDTH) != M_WORD_WIDTH) begin
        $error("Error: AXI master interface word width must be even power of two (instance %m)");
        $finish;
    end
end

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_DATA = 2'd1,
    STATE_RESP = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg [DATA_WIDTH-1:0] data_reg = {DATA_WIDTH{1'b0}}, data_next;
reg [STRB_WIDTH-1:0] strb_reg = {STRB_WIDTH{1'b0}}, strb_next;

reg [SEGMENT_COUNT_WIDTH-1:0] current_segment_reg = 0, current_segment_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg [1:0] s_axil_bresp_reg = 2'd0, s_axil_bresp_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

reg [ADDR_WIDTH-1:0] m_axil_awaddr_reg = {ADDR_WIDTH{1'b0}}, m_axil_awaddr_next;
reg [2:0] m_axil_awprot_reg = 3'd0, m_axil_awprot_next;
reg m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
reg [M_DATA_WIDTH-1:0] m_axil_wdata_reg = {M_DATA_WIDTH{1'b0}}, m_axil_wdata_next;
reg [M_STRB_WIDTH-1:0] m_axil_wstrb_reg = {M_STRB_WIDTH{1'b0}}, m_axil_wstrb_next;
reg m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
reg m_axil_bready_reg = 1'b0, m_axil_bready_next;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = s_axil_bresp_reg;
assign s_axil_bvalid = s_axil_bvalid_reg;

assign m_axil_awaddr = m_axil_awaddr_reg;
assign m_axil_awprot = m_axil_awprot_reg;
assign m_axil_awvalid = m_axil_awvalid_reg;
assign m_axil_wdata = m_axil_wdata_reg;
assign m_axil_wstrb = m_axil_wstrb_reg;
assign m_axil_wvalid = m_axil_wvalid_reg;
assign m_axil_bready = m_axil_bready_reg;

always @* begin
    state_next = STATE_IDLE;

    data_next = data_reg;
    strb_next = strb_reg;

    current_segment_next = current_segment_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bresp_next = s_axil_bresp_reg;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;
    m_axil_awaddr_next = m_axil_awaddr_reg;
    m_axil_awprot_next = m_axil_awprot_reg;
    m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_awready;
    m_axil_wdata_next = m_axil_wdata_reg;
    m_axil_wstrb_next = m_axil_wstrb_reg;
    m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wready;
    m_axil_bready_next = 1'b0;

    if (SEGMENT_COUNT == 1 || EXPAND) begin
        // master output is same width or wider; single cycle direct transfer
        case (state_reg)
            STATE_IDLE: begin
                s_axil_awready_next = !m_axil_awvalid;

                if (s_axil_awready && s_axil_awvalid) begin
                    s_axil_awready_next = 1'b0;
                    m_axil_awaddr_next = s_axil_awaddr;
                    m_axil_awprot_next = s_axil_awprot;
                    m_axil_awvalid_next = 1'b1;
                    s_axil_wready_next = !m_axil_wvalid;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                s_axil_wready_next = !m_axil_wvalid;

                if (s_axil_wready && s_axil_wvalid) begin
                    s_axil_wready_next = 1'b0;
                    if (M_WORD_WIDTH == S_WORD_WIDTH) begin
                        m_axil_wdata_next = s_axil_wdata;
                        m_axil_wstrb_next = s_axil_wstrb;
                    end else begin
                        m_axil_wdata_next = {(M_WORD_WIDTH/S_WORD_WIDTH){s_axil_wdata}};
                        m_axil_wstrb_next = s_axil_wstrb << (m_axil_awaddr_reg[M_ADDR_BIT_OFFSET - 1:S_ADDR_BIT_OFFSET] * S_STRB_WIDTH);
                    end
                    m_axil_wvalid_next = 1'b1;
                    m_axil_bready_next = !s_axil_bvalid;
                    state_next = STATE_RESP;
                end else begin
                    state_next = STATE_DATA;
                end
            end
            STATE_RESP: begin
                m_axil_bready_next = !s_axil_bvalid;

                if (m_axil_bready && m_axil_bvalid) begin
                    m_axil_bready_next = 1'b0;
                    s_axil_bresp_next = m_axil_bresp;
                    s_axil_bvalid_next = 1'b1;
                    s_axil_awready_next = !m_axil_awvalid;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_RESP;
                end
            end
        endcase
    end else begin
        // master output is narrower; may need several cycles
        case (state_reg)
            STATE_IDLE: begin
                s_axil_awready_next = !m_axil_awvalid;

                current_segment_next = 0;
                s_axil_bresp_next = 2'd0;

                if (s_axil_awready && s_axil_awvalid) begin
                    s_axil_awready_next = 1'b0;
                    m_axil_awaddr_next = s_axil_awaddr & ({ADDR_WIDTH{1'b1}} << S_ADDR_BIT_OFFSET);
                    m_axil_awprot_next = s_axil_awprot;
                    m_axil_awvalid_next = 1'b1;
                    s_axil_wready_next = !m_axil_wvalid;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                s_axil_wready_next = !m_axil_wvalid;

                if (s_axil_wready && s_axil_wvalid) begin
                    s_axil_wready_next = 1'b0;
                    data_next = s_axil_wdata;
                    strb_next = s_axil_wstrb;
                    m_axil_wdata_next = s_axil_wdata;
                    m_axil_wstrb_next = s_axil_wstrb;
                    m_axil_wvalid_next = 1'b1;
                    m_axil_bready_next = !s_axil_bvalid;
                    state_next = STATE_RESP;
                end else begin
                    state_next = STATE_DATA;
                end
            end
            STATE_RESP: begin
                m_axil_bready_next = !s_axil_bvalid;

                if (m_axil_bready && m_axil_bvalid) begin
                    m_axil_bready_next = 1'b0;
                    if (m_axil_bresp != 0) begin
                        s_axil_bresp_next = m_axil_bresp;
                    end
                    if (current_segment_reg == SEGMENT_COUNT-1) begin
                        s_axil_bvalid_next = 1'b1;
                        s_axil_awready_next = !m_axil_awvalid;
                        state_next = STATE_IDLE;
                    end else begin
                        current_segment_next = current_segment_reg + 1;
                        m_axil_awaddr_next = m_axil_awaddr_reg + SEGMENT_STRB_WIDTH;
                        m_axil_awvalid_next = 1'b1;
                        m_axil_wdata_next = data_reg >> (current_segment_reg+1)*SEGMENT_DATA_WIDTH;
                        m_axil_wstrb_next = strb_reg >> (current_segment_reg+1)*SEGMENT_STRB_WIDTH;
                        m_axil_wvalid_next = 1'b1;
                        state_next = STATE_RESP;
                    end
                end else begin
                    state_next = STATE_RESP;
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    data_reg <= data_next;
    strb_reg <= strb_next;

    current_segment_reg <= current_segment_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bresp_reg <= s_axil_bresp_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    m_axil_awaddr_reg <= m_axil_awaddr_next;
    m_axil_awprot_reg <= m_axil_awprot_next;
    m_axil_awvalid_reg <= m_axil_awvalid_next;
    m_axil_wdata_reg <= m_axil_wdata_next;
    m_axil_wstrb_reg <= m_axil_wstrb_next;
    m_axil_wvalid_reg <= m_axil_wvalid_next;
    m_axil_bready_reg <= m_axil_bready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        m_axil_awvalid_reg <= 1'b0;
        m_axil_wvalid_reg <= 1'b0;
        m_axil_bready_reg <= 1'b0;
    end
end

endmodule

`resetall
