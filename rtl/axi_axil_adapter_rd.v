/*

Copyright (c) 2019 Alex Forencich

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
 * AXI4 to AXI4-Lite adapter (read)
 */
module axi_axil_adapter_rd #
(
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) AXI interface data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of input (slave) AXI interface wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Width of output (master) AXI lite interface data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of output (master) AXI lite interface wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // When adapting to a wider bus, re-pack full-width burst instead of passing through narrow burst if possible
    parameter CONVERT_BURST = 1,
    // When adapting to a wider bus, re-pack all bursts instead of passing through narrow burst if possible
    parameter CONVERT_NARROW_BURST = 0
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * AXI slave interface
     */
    input  wire [AXI_ID_WIDTH-1:0]     s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [7:0]                  s_axi_arlen,
    input  wire [2:0]                  s_axi_arsize,
    input  wire [1:0]                  s_axi_arburst,
    input  wire                        s_axi_arlock,
    input  wire [3:0]                  s_axi_arcache,
    input  wire [2:0]                  s_axi_arprot,
    input  wire                        s_axi_arvalid,
    output wire                        s_axi_arready,
    output wire [AXI_ID_WIDTH-1:0]     s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]                  s_axi_rresp,
    output wire                        s_axi_rlast,
    output wire                        s_axi_rvalid,
    input  wire                        s_axi_rready,

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]       m_axil_araddr,
    output wire [2:0]                  m_axil_arprot,
    output wire                        m_axil_arvalid,
    input  wire                        m_axil_arready,
    input  wire [AXIL_DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [1:0]                  m_axil_rresp,
    input  wire                        m_axil_rvalid,
    output wire                        m_axil_rready
);

parameter AXI_ADDR_BIT_OFFSET = $clog2(AXI_STRB_WIDTH);
parameter AXIL_ADDR_BIT_OFFSET = $clog2(AXIL_STRB_WIDTH);
parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
parameter AXIL_WORD_WIDTH = AXIL_STRB_WIDTH;
parameter AXI_WORD_SIZE = AXI_DATA_WIDTH/AXI_WORD_WIDTH;
parameter AXIL_WORD_SIZE = AXIL_DATA_WIDTH/AXIL_WORD_WIDTH;
parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
parameter AXIL_BURST_SIZE = $clog2(AXIL_STRB_WIDTH);

// output bus is wider
parameter EXPAND = AXIL_STRB_WIDTH > AXI_STRB_WIDTH;
parameter DATA_WIDTH = EXPAND ? AXIL_DATA_WIDTH : AXI_DATA_WIDTH;
parameter STRB_WIDTH = EXPAND ? AXIL_STRB_WIDTH : AXI_STRB_WIDTH;
// required number of segments in wider bus
parameter SEGMENT_COUNT = EXPAND ? (AXIL_STRB_WIDTH / AXI_STRB_WIDTH) : (AXI_STRB_WIDTH / AXIL_STRB_WIDTH);
// data width and keep width per segment
parameter SEGMENT_DATA_WIDTH = DATA_WIDTH / SEGMENT_COUNT;
parameter SEGMENT_STRB_WIDTH = STRB_WIDTH / SEGMENT_COUNT;

// bus width assertions
initial begin
    if (AXI_WORD_SIZE * AXI_STRB_WIDTH != AXI_DATA_WIDTH) begin
        $error("Error: AXI slave interface data width not evenly divisble (instance %m)");
        $finish;
    end

    if (AXIL_WORD_SIZE * AXIL_STRB_WIDTH != AXIL_DATA_WIDTH) begin
        $error("Error: AXI lite master interface data width not evenly divisble (instance %m)");
        $finish;
    end

    if (AXI_WORD_SIZE != AXIL_WORD_SIZE) begin
        $error("Error: word size mismatch (instance %m)");
        $finish;
    end

    if (2**$clog2(AXI_WORD_WIDTH) != AXI_WORD_WIDTH) begin
        $error("Error: AXI slave interface word width must be even power of two (instance %m)");
        $finish;
    end

    if (2**$clog2(AXIL_WORD_WIDTH) != AXIL_WORD_WIDTH) begin
        $error("Error: AXI lite master interface word width must be even power of two (instance %m)");
        $finish;
    end
end

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_DATA = 2'd1,
    STATE_DATA_READ = 2'd2,
    STATE_DATA_SPLIT = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg [AXI_ID_WIDTH-1:0] id_reg = {AXI_ID_WIDTH{1'b0}}, id_next;
reg [ADDR_WIDTH-1:0] addr_reg = {ADDR_WIDTH{1'b0}}, addr_next;
reg [DATA_WIDTH-1:0] data_reg = {DATA_WIDTH{1'b0}}, data_next;
reg [1:0] resp_reg = 2'd0, resp_next;
reg [7:0] burst_reg = 8'd0, burst_next;
reg [2:0] burst_size_reg = 3'd0, burst_size_next;
reg [7:0] master_burst_reg = 8'd0, master_burst_next;
reg [2:0] master_burst_size_reg = 3'd0, master_burst_size_next;

reg s_axi_arready_reg = 1'b0, s_axi_arready_next;
reg [AXI_ID_WIDTH-1:0] s_axi_rid_reg = {AXI_ID_WIDTH{1'b0}}, s_axi_rid_next;
reg [AXI_DATA_WIDTH-1:0] s_axi_rdata_reg = {AXI_DATA_WIDTH{1'b0}}, s_axi_rdata_next;
reg [1:0] s_axi_rresp_reg = 2'd0, s_axi_rresp_next;
reg s_axi_rlast_reg = 1'b0, s_axi_rlast_next;
reg s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;

reg [ADDR_WIDTH-1:0] m_axil_araddr_reg = {ADDR_WIDTH{1'b0}}, m_axil_araddr_next;
reg [2:0] m_axil_arprot_reg = 3'd0, m_axil_arprot_next;
reg m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
reg m_axil_rready_reg = 1'b0, m_axil_rready_next;

assign s_axi_arready = s_axi_arready_reg;
assign s_axi_rid = s_axi_rid_reg;
assign s_axi_rdata = s_axi_rdata_reg;
assign s_axi_rresp = s_axi_rresp_reg;
assign s_axi_rlast = s_axi_rlast_reg;
assign s_axi_rvalid = s_axi_rvalid_reg;

assign m_axil_araddr = m_axil_araddr_reg;
assign m_axil_arprot = m_axil_arprot_reg;
assign m_axil_arvalid = m_axil_arvalid_reg;
assign m_axil_rready = m_axil_rready_reg;

always @* begin
    state_next = STATE_IDLE;

    id_next = id_reg;
    addr_next = addr_reg;
    data_next = data_reg;
    resp_next = resp_reg;
    burst_next = burst_reg;
    burst_size_next = burst_size_reg;
    master_burst_next = master_burst_reg;
    master_burst_size_next = master_burst_size_reg;

    s_axi_arready_next = 1'b0;
    s_axi_rid_next = s_axi_rid_reg;
    s_axi_rdata_next = s_axi_rdata_reg;
    s_axi_rresp_next = s_axi_rresp_reg;
    s_axi_rlast_next = s_axi_rlast_reg;
    s_axi_rvalid_next = s_axi_rvalid_reg && !s_axi_rready;
    m_axil_araddr_next = m_axil_araddr_reg;
    m_axil_arprot_next = m_axil_arprot_reg;
    m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_arready;
    m_axil_rready_next = 1'b0;

    if (SEGMENT_COUNT == 1) begin
        // master output is same width; direct transfer with no splitting/merging
        case (state_reg)
            STATE_IDLE: begin
                // idle state; wait for new burst
                s_axi_arready_next = !m_axil_arvalid;

                if (s_axi_arready && s_axi_arvalid) begin
                    s_axi_arready_next = 1'b0;
                    id_next = s_axi_arid;
                    m_axil_araddr_next = s_axi_araddr;
                    addr_next = s_axi_araddr;
                    burst_next = s_axi_arlen;
                    burst_size_next = s_axi_arsize;
                    m_axil_arprot_next = s_axi_arprot;
                    m_axil_arvalid_next = 1'b1;
                    m_axil_rready_next = 1'b0;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                // data state; transfer read data
                m_axil_rready_next = !s_axi_rvalid && !m_axil_arvalid;

                if (m_axil_rready && m_axil_rvalid) begin
                    s_axi_rid_next = id_reg;
                    s_axi_rdata_next = m_axil_rdata;
                    s_axi_rresp_next = m_axil_rresp;
                    s_axi_rlast_next = 1'b0;
                    s_axi_rvalid_next = 1'b1;
                    burst_next = burst_reg - 1;
                    addr_next = addr_reg + (1 << burst_size_reg);
                    if (burst_reg == 0) begin
                        // last data word, return to idle
                        m_axil_rready_next = 1'b0;
                        s_axi_rlast_next = 1'b1;
                        s_axi_arready_next = !m_axil_arvalid;
                        state_next = STATE_IDLE;
                    end else begin
                        // start new AXI lite read
                        m_axil_araddr_next = addr_next;
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b0;
                        state_next = STATE_DATA;
                    end
                end else begin
                    state_next = STATE_DATA;
                end
            end
        endcase
    end else if (EXPAND) begin
        // master output is wider; split reads
        case (state_reg)
            STATE_IDLE: begin
                // idle state; wait for new burst
                s_axi_arready_next = !m_axil_arvalid;

                if (s_axi_arready && s_axi_arvalid) begin
                    s_axi_arready_next = 1'b0;
                    id_next = s_axi_arid;
                    m_axil_araddr_next = s_axi_araddr;
                    addr_next = s_axi_araddr;
                    burst_next = s_axi_arlen;
                    burst_size_next = s_axi_arsize;
                    if (CONVERT_BURST && s_axi_arcache[1] && (CONVERT_NARROW_BURST || s_axi_arsize == AXI_BURST_SIZE)) begin
                        // split reads
                        // require CONVERT_BURST and arcache[1] set
                        master_burst_size_next = AXIL_BURST_SIZE;
                        state_next = STATE_DATA_READ;
                    end else begin
                        // output narrow burst
                        master_burst_size_next = s_axi_arsize;
                        state_next = STATE_DATA;
                    end
                    m_axil_arprot_next = s_axi_arprot;
                    m_axil_arvalid_next = 1'b1;
                    m_axil_rready_next = 1'b0;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                m_axil_rready_next = !s_axi_rvalid && !m_axil_arvalid;

                if (m_axil_rready && m_axil_rvalid) begin
                    s_axi_rid_next = id_reg;
                    s_axi_rdata_next = m_axil_rdata >> (addr_reg[AXIL_ADDR_BIT_OFFSET-1:AXI_ADDR_BIT_OFFSET] * AXI_DATA_WIDTH);
                    s_axi_rresp_next = m_axil_rresp;
                    s_axi_rlast_next = 1'b0;
                    s_axi_rvalid_next = 1'b1;
                    burst_next = burst_reg - 1;
                    addr_next = addr_reg + (1 << burst_size_reg);
                    if (burst_reg == 0) begin
                        // last data word, return to idle
                        m_axil_rready_next = 1'b0;
                        s_axi_rlast_next = 1'b1;
                        s_axi_arready_next = !m_axil_arvalid;
                        state_next = STATE_IDLE;
                    end else begin
                        // start new AXI lite read
                        m_axil_araddr_next = addr_next;
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b0;
                        state_next = STATE_DATA;
                    end
                end else begin
                    state_next = STATE_DATA;
                end
            end
            STATE_DATA_READ: begin
                m_axil_rready_next = !s_axi_rvalid && !m_axil_arvalid;

                if (m_axil_rready && m_axil_rvalid) begin
                    s_axi_rid_next = id_reg;
                    data_next = m_axil_rdata;
                    resp_next = m_axil_rresp;
                    s_axi_rdata_next = m_axil_rdata >> (addr_reg[AXIL_ADDR_BIT_OFFSET-1:AXI_ADDR_BIT_OFFSET] * AXI_DATA_WIDTH);
                    s_axi_rresp_next = m_axil_rresp;
                    s_axi_rlast_next = 1'b0;
                    s_axi_rvalid_next = 1'b1;
                    burst_next = burst_reg - 1;
                    addr_next = addr_reg + (1 << burst_size_reg);
                    if (burst_reg == 0) begin
                        m_axil_rready_next = 1'b0;
                        s_axi_arready_next = !m_axil_arvalid;
                        s_axi_rlast_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else if (addr_next[master_burst_size_reg] != addr_reg[master_burst_size_reg]) begin
                        // start new AXI lite read
                        m_axil_araddr_next = addr_next;
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b0;
                        state_next = STATE_DATA_READ;
                    end else begin
                        m_axil_rready_next = 1'b0;
                        state_next = STATE_DATA_SPLIT;
                    end
                end else begin
                    state_next = STATE_DATA_READ;
                end
            end
            STATE_DATA_SPLIT: begin
                m_axil_rready_next = 1'b0;

                if (s_axi_rready || !s_axi_rvalid) begin
                    s_axi_rid_next = id_reg;
                    s_axi_rdata_next = data_reg >> (addr_reg[AXIL_ADDR_BIT_OFFSET-1:AXI_ADDR_BIT_OFFSET] * AXI_DATA_WIDTH);
                    s_axi_rresp_next = resp_reg;
                    s_axi_rlast_next = 1'b0;
                    s_axi_rvalid_next = 1'b1;
                    burst_next = burst_reg - 1;
                    addr_next = addr_reg + (1 << burst_size_reg);
                    if (burst_reg == 0) begin
                        s_axi_arready_next = !m_axil_arvalid;
                        s_axi_rlast_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else if (addr_next[master_burst_size_reg] != addr_reg[master_burst_size_reg]) begin
                        // start new AXI lite read
                        m_axil_araddr_next = addr_next;
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b0;
                        state_next = STATE_DATA_READ;
                    end else begin
                        state_next = STATE_DATA_SPLIT;
                    end
                end else begin
                    state_next = STATE_DATA_SPLIT;
                end
            end
        endcase
    end else begin
        // master output is narrower; merge reads and possibly split burst
        case (state_reg)
            STATE_IDLE: begin
                // idle state; wait for new burst
                s_axi_arready_next = !m_axil_arvalid;

                resp_next = 2'd0;

                if (s_axi_arready && s_axi_arvalid) begin
                    s_axi_arready_next = 1'b0;
                    id_next = s_axi_arid;
                    m_axil_araddr_next = s_axi_araddr;
                    addr_next = s_axi_araddr;
                    burst_next = s_axi_arlen;
                    burst_size_next = s_axi_arsize;
                    if (s_axi_arsize > AXIL_BURST_SIZE) begin
                        // need to adjust burst size
                        if ({s_axi_arlen, {AXI_BURST_SIZE-AXIL_BURST_SIZE{1'b1}}} >> (AXI_BURST_SIZE-s_axi_arsize) > 255) begin
                            // limit burst length to max
                            master_burst_next = 8'd255;
                        end else begin
                            master_burst_next = {s_axi_arlen, {AXI_BURST_SIZE-AXIL_BURST_SIZE{1'b1}}} >> (AXI_BURST_SIZE-s_axi_arsize);
                        end
                        master_burst_size_next = AXIL_BURST_SIZE;
                    end else begin
                        // pass through narrow (enough) burst
                        master_burst_next = s_axi_arlen;
                        master_burst_size_next = s_axi_arsize;
                    end
                    m_axil_arprot_next = s_axi_arprot;
                    m_axil_arvalid_next = 1'b1;
                    m_axil_rready_next = 1'b0;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                m_axil_rready_next = !s_axi_rvalid && !m_axil_arvalid;

                if (m_axil_rready && m_axil_rvalid) begin
                    data_next[addr_reg[AXI_ADDR_BIT_OFFSET-1:AXIL_ADDR_BIT_OFFSET]*SEGMENT_DATA_WIDTH +: SEGMENT_DATA_WIDTH] = m_axil_rdata;
                    if (m_axil_rresp) begin
                        resp_next = m_axil_rresp;
                    end
                    s_axi_rid_next = id_reg;
                    s_axi_rdata_next = data_next;
                    s_axi_rresp_next = resp_next;
                    s_axi_rlast_next = 1'b0;
                    s_axi_rvalid_next = 1'b0;
                    master_burst_next = master_burst_reg - 1;
                    addr_next = addr_reg + (1 << master_burst_size_reg);
                    if (addr_next[burst_size_reg] != addr_reg[burst_size_reg]) begin
                        data_next = {DATA_WIDTH{1'b0}};
                        burst_next = burst_reg - 1;
                        s_axi_rvalid_next = 1'b1;
                    end
                    if (master_burst_reg == 0) begin
                        if (burst_reg == 0) begin
                            m_axil_rready_next = 1'b0;
                            s_axi_rlast_next = 1'b1;
                            s_axi_rvalid_next = 1'b1;
                            s_axi_arready_next = !m_axil_arvalid;
                            state_next = STATE_IDLE;
                        end else begin
                            // start new burst
                            m_axil_araddr_next = addr_next;
                            if (burst_size_reg > AXIL_BURST_SIZE) begin
                                // need to adjust burst size
                                if ({burst_next, {AXI_BURST_SIZE-AXIL_BURST_SIZE{1'b1}}} >> (AXI_BURST_SIZE-burst_size_reg) > 255) begin
                                    // limit burst length to max
                                    master_burst_next = 8'd255;
                                end else begin
                                    master_burst_next = {burst_next, {AXI_BURST_SIZE-AXIL_BURST_SIZE{1'b1}}} >> (AXI_BURST_SIZE-burst_size_reg);
                                end
                                master_burst_size_next = AXIL_BURST_SIZE;
                            end else begin
                                // pass through narrow (enough) burst
                                master_burst_next = burst_next;
                                master_burst_size_next = burst_size_reg;
                            end
                            m_axil_arvalid_next = 1'b1;
                            m_axil_rready_next = 1'b0;
                            state_next = STATE_DATA;
                        end
                    end else begin
                        m_axil_araddr_next = addr_next;
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b0;
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

    id_reg <= id_next;
    addr_reg <= addr_next;
    data_reg <= data_next;
    resp_reg <= resp_next;
    burst_reg <= burst_next;
    burst_size_reg <= burst_size_next;
    master_burst_reg <= master_burst_next;
    master_burst_size_reg <= master_burst_size_next;

    s_axi_arready_reg <= s_axi_arready_next;
    s_axi_rid_reg <= s_axi_rid_next;
    s_axi_rdata_reg <= s_axi_rdata_next;
    s_axi_rresp_reg <= s_axi_rresp_next;
    s_axi_rlast_reg <= s_axi_rlast_next;
    s_axi_rvalid_reg <= s_axi_rvalid_next;

    m_axil_araddr_reg <= m_axil_araddr_next;
    m_axil_arprot_reg <= m_axil_arprot_next;
    m_axil_arvalid_reg <= m_axil_arvalid_next;
    m_axil_rready_reg <= m_axil_rready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axi_arready_reg <= 1'b0;
        s_axi_rvalid_reg <= 1'b0;

        m_axil_arvalid_reg <= 1'b0;
        m_axil_rready_reg <= 1'b0;
    end
end

endmodule

`resetall
