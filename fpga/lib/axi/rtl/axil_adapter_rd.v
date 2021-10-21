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
 * AXI4 lite width adapter (read)
 */
module axil_adapter_rd #
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
    input  wire [ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [2:0]               s_axil_arprot,
    input  wire                     s_axil_arvalid,
    output wire                     s_axil_arready,
    output wire [S_DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]               s_axil_rresp,
    output wire                     s_axil_rvalid,
    input  wire                     s_axil_rready,

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]    m_axil_araddr,
    output wire [2:0]               m_axil_arprot,
    output wire                     m_axil_arvalid,
    input  wire                     m_axil_arready,
    input  wire [M_DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [1:0]               m_axil_rresp,
    input  wire                     m_axil_rvalid,
    output wire                     m_axil_rready
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

localparam [0:0]
    STATE_IDLE = 1'd0,
    STATE_DATA = 1'd1;

reg [0:0] state_reg = STATE_IDLE, state_next;

reg [SEGMENT_COUNT_WIDTH-1:0] current_segment_reg = 0, current_segment_next;

reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [S_DATA_WIDTH-1:0] s_axil_rdata_reg = {S_DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg [1:0] s_axil_rresp_reg = 2'd0, s_axil_rresp_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg [ADDR_WIDTH-1:0] m_axil_araddr_reg = {ADDR_WIDTH{1'b0}}, m_axil_araddr_next;
reg [2:0] m_axil_arprot_reg = 3'd0, m_axil_arprot_next;
reg m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
reg m_axil_rready_reg = 1'b0, m_axil_rready_next;

assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = s_axil_rresp_reg;
assign s_axil_rvalid = s_axil_rvalid_reg;

assign m_axil_araddr = m_axil_araddr_reg;
assign m_axil_arprot = m_axil_arprot_reg;
assign m_axil_arvalid = m_axil_arvalid_reg;
assign m_axil_rready = m_axil_rready_reg;

always @* begin
    state_next = STATE_IDLE;

    current_segment_next = current_segment_reg;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rresp_next = s_axil_rresp_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;
    m_axil_araddr_next = m_axil_araddr_reg;
    m_axil_arprot_next = m_axil_arprot_reg;
    m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_arready;
    m_axil_rready_next = 1'b0;

    if (SEGMENT_COUNT == 1 || EXPAND) begin
        // master output is same width or wider; single cycle direct transfer
        case (state_reg)
            STATE_IDLE: begin
                s_axil_arready_next = !m_axil_arvalid;

                if (s_axil_arready && s_axil_arvalid) begin
                    s_axil_arready_next = 1'b0;
                    m_axil_araddr_next = s_axil_araddr;
                    m_axil_arprot_next = s_axil_arprot;
                    m_axil_arvalid_next = 1'b1;
                    m_axil_rready_next = !m_axil_rvalid;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                m_axil_rready_next = !s_axil_rvalid;

                if (m_axil_rready && m_axil_rvalid) begin
                    m_axil_rready_next = 1'b0;
                    if (M_WORD_WIDTH == S_WORD_WIDTH) begin
                        s_axil_rdata_next = m_axil_rdata;
                    end else begin
                        s_axil_rdata_next = m_axil_rdata >> (m_axil_araddr_reg[M_ADDR_BIT_OFFSET - 1:S_ADDR_BIT_OFFSET] * S_DATA_WIDTH);
                    end
                    s_axil_rresp_next = m_axil_rresp;
                    s_axil_rvalid_next = 1'b1;
                    s_axil_arready_next = !m_axil_arvalid;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DATA;
                end
            end
        endcase
    end else begin
        // master output is narrower; may need several cycles
        case (state_reg)
            STATE_IDLE: begin
                s_axil_arready_next = !m_axil_arvalid;

                current_segment_next = 0;
                s_axil_rresp_next = 2'd0;

                if (s_axil_arready && s_axil_arvalid) begin
                    s_axil_arready_next = 1'b0;
                    m_axil_araddr_next = s_axil_araddr & ({ADDR_WIDTH{1'b1}} << S_ADDR_BIT_OFFSET);
                    m_axil_arprot_next = s_axil_arprot;
                    m_axil_arvalid_next = 1'b1;
                    m_axil_rready_next = !m_axil_rvalid;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                m_axil_rready_next = !s_axil_rvalid;

                if (m_axil_rready && m_axil_rvalid) begin
                    m_axil_rready_next = 1'b0;
                    s_axil_rdata_next[current_segment_reg*SEGMENT_DATA_WIDTH +: SEGMENT_DATA_WIDTH] = m_axil_rdata;
                    if (m_axil_rresp) begin
                        s_axil_rresp_next = m_axil_rresp;
                    end
                    if (current_segment_reg == SEGMENT_COUNT-1) begin
                        s_axil_rvalid_next = 1'b1;
                        s_axil_arready_next = !m_axil_arvalid;
                        state_next = STATE_IDLE;
                    end else begin
                        current_segment_next = current_segment_reg + 1;
                        m_axil_araddr_next = m_axil_araddr_reg + SEGMENT_STRB_WIDTH;
                        m_axil_arvalid_next = 1'b1;
                        state_next = STATE_DATA;
                    end
                end else begin
                    state_next = STATE_DATA;
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    current_segment_reg <= current_segment_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rresp_reg <= s_axil_rresp_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    m_axil_araddr_reg <= m_axil_araddr_next;
    m_axil_arprot_reg <= m_axil_arprot_next;
    m_axil_arvalid_reg <= m_axil_arvalid_next;
    m_axil_rready_reg <= m_axil_rready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        m_axil_arvalid_reg <= 1'b0;
        m_axil_rready_reg <= 1'b0;
    end
end

endmodule

`resetall
