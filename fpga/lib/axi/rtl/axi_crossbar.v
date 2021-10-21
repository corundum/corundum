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
 * AXI4 crossbar
 */
module axi_crossbar #
(
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Input ID field width (from AXI masters)
    parameter S_ID_WIDTH = 8,
    // Output ID field width (towards AXI slaves)
    // Additional bits required for response routing
    parameter M_ID_WIDTH = S_ID_WIDTH+$clog2(S_COUNT),
    // Propagate awuser signal
    parameter AWUSER_ENABLE = 0,
    // Width of awuser signal
    parameter AWUSER_WIDTH = 1,
    // Propagate wuser signal
    parameter WUSER_ENABLE = 0,
    // Width of wuser signal
    parameter WUSER_WIDTH = 1,
    // Propagate buser signal
    parameter BUSER_ENABLE = 0,
    // Width of buser signal
    parameter BUSER_WIDTH = 1,
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
    // Number of concurrent unique IDs for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_THREADS = {S_COUNT{32'd2}},
    // Number of concurrent operations for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_ACCEPT = {S_COUNT{32'd16}},
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Read connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT_READ = {M_COUNT{{S_COUNT{1'b1}}}},
    // Write connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT_WRITE = {M_COUNT{{S_COUNT{1'b1}}}},
    // Number of concurrent operations for each master interface
    // M_COUNT concatenated fields of 32 bits
    parameter M_ISSUE = {M_COUNT{32'd4}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Slave interface AW channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AW_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface W channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_W_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface B channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_B_REG_TYPE = {S_COUNT{2'd1}},
    // Slave interface AR channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AR_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface R channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_R_REG_TYPE = {S_COUNT{2'd2}},
    // Master interface AW channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AW_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface W channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_W_REG_TYPE = {M_COUNT{2'd2}},
    // Master interface B channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_B_REG_TYPE = {M_COUNT{2'd0}},
    // Master interface AR channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AR_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface R channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_R_REG_TYPE = {M_COUNT{2'd0}}
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * AXI slave interfaces
     */
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_awid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [S_COUNT*8-1:0]             s_axi_awlen,
    input  wire [S_COUNT*3-1:0]             s_axi_awsize,
    input  wire [S_COUNT*2-1:0]             s_axi_awburst,
    input  wire [S_COUNT-1:0]               s_axi_awlock,
    input  wire [S_COUNT*4-1:0]             s_axi_awcache,
    input  wire [S_COUNT*3-1:0]             s_axi_awprot,
    input  wire [S_COUNT*4-1:0]             s_axi_awqos,
    input  wire [S_COUNT*AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire [S_COUNT-1:0]               s_axi_awvalid,
    output wire [S_COUNT-1:0]               s_axi_awready,
    input  wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [S_COUNT*STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire [S_COUNT-1:0]               s_axi_wlast,
    input  wire [S_COUNT*WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire [S_COUNT-1:0]               s_axi_wvalid,
    output wire [S_COUNT-1:0]               s_axi_wready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_bid,
    output wire [S_COUNT*2-1:0]             s_axi_bresp,
    output wire [S_COUNT*BUSER_WIDTH-1:0]   s_axi_buser,
    output wire [S_COUNT-1:0]               s_axi_bvalid,
    input  wire [S_COUNT-1:0]               s_axi_bready,
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_arid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [S_COUNT*8-1:0]             s_axi_arlen,
    input  wire [S_COUNT*3-1:0]             s_axi_arsize,
    input  wire [S_COUNT*2-1:0]             s_axi_arburst,
    input  wire [S_COUNT-1:0]               s_axi_arlock,
    input  wire [S_COUNT*4-1:0]             s_axi_arcache,
    input  wire [S_COUNT*3-1:0]             s_axi_arprot,
    input  wire [S_COUNT*4-1:0]             s_axi_arqos,
    input  wire [S_COUNT*ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire [S_COUNT-1:0]               s_axi_arvalid,
    output wire [S_COUNT-1:0]               s_axi_arready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_rid,
    output wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [S_COUNT*2-1:0]             s_axi_rresp,
    output wire [S_COUNT-1:0]               s_axi_rlast,
    output wire [S_COUNT*RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire [S_COUNT-1:0]               s_axi_rvalid,
    input  wire [S_COUNT-1:0]               s_axi_rready,

    /*
     * AXI master interfaces
     */
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_awid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [M_COUNT*8-1:0]             m_axi_awlen,
    output wire [M_COUNT*3-1:0]             m_axi_awsize,
    output wire [M_COUNT*2-1:0]             m_axi_awburst,
    output wire [M_COUNT-1:0]               m_axi_awlock,
    output wire [M_COUNT*4-1:0]             m_axi_awcache,
    output wire [M_COUNT*3-1:0]             m_axi_awprot,
    output wire [M_COUNT*4-1:0]             m_axi_awqos,
    output wire [M_COUNT*4-1:0]             m_axi_awregion,
    output wire [M_COUNT*AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire [M_COUNT-1:0]               m_axi_awvalid,
    input  wire [M_COUNT-1:0]               m_axi_awready,
    output wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [M_COUNT*STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire [M_COUNT-1:0]               m_axi_wlast,
    output wire [M_COUNT*WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire [M_COUNT-1:0]               m_axi_wvalid,
    input  wire [M_COUNT-1:0]               m_axi_wready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [M_COUNT*2-1:0]             m_axi_bresp,
    input  wire [M_COUNT*BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire [M_COUNT-1:0]               m_axi_bvalid,
    output wire [M_COUNT-1:0]               m_axi_bready,
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_arid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [M_COUNT*8-1:0]             m_axi_arlen,
    output wire [M_COUNT*3-1:0]             m_axi_arsize,
    output wire [M_COUNT*2-1:0]             m_axi_arburst,
    output wire [M_COUNT-1:0]               m_axi_arlock,
    output wire [M_COUNT*4-1:0]             m_axi_arcache,
    output wire [M_COUNT*3-1:0]             m_axi_arprot,
    output wire [M_COUNT*4-1:0]             m_axi_arqos,
    output wire [M_COUNT*4-1:0]             m_axi_arregion,
    output wire [M_COUNT*ARUSER_WIDTH-1:0]  m_axi_aruser,
    output wire [M_COUNT-1:0]               m_axi_arvalid,
    input  wire [M_COUNT-1:0]               m_axi_arready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [M_COUNT*2-1:0]             m_axi_rresp,
    input  wire [M_COUNT-1:0]               m_axi_rlast,
    input  wire [M_COUNT*RUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire [M_COUNT-1:0]               m_axi_rvalid,
    output wire [M_COUNT-1:0]               m_axi_rready
);

axi_crossbar_wr #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .S_ID_WIDTH(S_ID_WIDTH),
    .M_ID_WIDTH(M_ID_WIDTH),
    .AWUSER_ENABLE(AWUSER_ENABLE),
    .AWUSER_WIDTH(AWUSER_WIDTH),
    .WUSER_ENABLE(WUSER_ENABLE),
    .WUSER_WIDTH(WUSER_WIDTH),
    .BUSER_ENABLE(BUSER_ENABLE),
    .BUSER_WIDTH(BUSER_WIDTH),
    .S_THREADS(S_THREADS),
    .S_ACCEPT(S_ACCEPT),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_WIDTH(M_ADDR_WIDTH),
    .M_CONNECT(M_CONNECT_WRITE),
    .M_ISSUE(M_ISSUE),
    .M_SECURE(M_SECURE),
    .S_AW_REG_TYPE(S_AW_REG_TYPE),
    .S_W_REG_TYPE (S_W_REG_TYPE),
    .S_B_REG_TYPE (S_B_REG_TYPE)
)
axi_crossbar_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI slave interfaces
     */
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awqos(s_axi_awqos),
    .s_axi_awuser(s_axi_awuser),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wuser(s_axi_wuser),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_buser(s_axi_buser),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),

    /*
     * AXI master interfaces
     */
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awqos(m_axi_awqos),
    .m_axi_awregion(m_axi_awregion),
    .m_axi_awuser(m_axi_awuser),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wuser(m_axi_wuser),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_buser(m_axi_buser),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready)
);

axi_crossbar_rd #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .S_ID_WIDTH(S_ID_WIDTH),
    .M_ID_WIDTH(M_ID_WIDTH),
    .ARUSER_ENABLE(ARUSER_ENABLE),
    .ARUSER_WIDTH(ARUSER_WIDTH),
    .RUSER_ENABLE(RUSER_ENABLE),
    .RUSER_WIDTH(RUSER_WIDTH),
    .S_THREADS(S_THREADS),
    .S_ACCEPT(S_ACCEPT),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_WIDTH(M_ADDR_WIDTH),
    .M_CONNECT(M_CONNECT_READ),
    .M_ISSUE(M_ISSUE),
    .M_SECURE(M_SECURE),
    .S_AR_REG_TYPE(S_AR_REG_TYPE),
    .S_R_REG_TYPE (S_R_REG_TYPE)
)
axi_crossbar_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI slave interfaces
     */
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arqos(s_axi_arqos),
    .s_axi_aruser(s_axi_aruser),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_ruser(s_axi_ruser),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),

    /*
     * AXI master interfaces
     */
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arqos(m_axi_arqos),
    .m_axi_arregion(m_axi_arregion),
    .m_axi_aruser(m_axi_aruser),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_ruser(m_axi_ruser),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready)
);

endmodule

`resetall
