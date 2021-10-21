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
 * AXI4 lite crossbar
 */
module axil_crossbar #
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
    parameter M_ISSUE = {M_COUNT{32'd16}},
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
     * AXI lite slave interfaces
     */
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire [S_COUNT*3-1:0]             s_axil_awprot,
    input  wire [S_COUNT-1:0]               s_axil_awvalid,
    output wire [S_COUNT-1:0]               s_axil_awready,
    input  wire [S_COUNT*DATA_WIDTH-1:0]    s_axil_wdata,
    input  wire [S_COUNT*STRB_WIDTH-1:0]    s_axil_wstrb,
    input  wire [S_COUNT-1:0]               s_axil_wvalid,
    output wire [S_COUNT-1:0]               s_axil_wready,
    output wire [S_COUNT*2-1:0]             s_axil_bresp,
    output wire [S_COUNT-1:0]               s_axil_bvalid,
    input  wire [S_COUNT-1:0]               s_axil_bready,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [S_COUNT*3-1:0]             s_axil_arprot,
    input  wire [S_COUNT-1:0]               s_axil_arvalid,
    output wire [S_COUNT-1:0]               s_axil_arready,
    output wire [S_COUNT*DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [S_COUNT*2-1:0]             s_axil_rresp,
    output wire [S_COUNT-1:0]               s_axil_rvalid,
    input  wire [S_COUNT-1:0]               s_axil_rready,

    /*
     * AXI lite master interfaces
     */
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axil_awaddr,
    output wire [M_COUNT*3-1:0]             m_axil_awprot,
    output wire [M_COUNT-1:0]               m_axil_awvalid,
    input  wire [M_COUNT-1:0]               m_axil_awready,
    output wire [M_COUNT*DATA_WIDTH-1:0]    m_axil_wdata,
    output wire [M_COUNT*STRB_WIDTH-1:0]    m_axil_wstrb,
    output wire [M_COUNT-1:0]               m_axil_wvalid,
    input  wire [M_COUNT-1:0]               m_axil_wready,
    input  wire [M_COUNT*2-1:0]             m_axil_bresp,
    input  wire [M_COUNT-1:0]               m_axil_bvalid,
    output wire [M_COUNT-1:0]               m_axil_bready,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axil_araddr,
    output wire [M_COUNT*3-1:0]             m_axil_arprot,
    output wire [M_COUNT-1:0]               m_axil_arvalid,
    input  wire [M_COUNT-1:0]               m_axil_arready,
    input  wire [M_COUNT*DATA_WIDTH-1:0]    m_axil_rdata,
    input  wire [M_COUNT*2-1:0]             m_axil_rresp,
    input  wire [M_COUNT-1:0]               m_axil_rvalid,
    output wire [M_COUNT-1:0]               m_axil_rready
);

axil_crossbar_wr #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
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
axil_crossbar_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI lite slave interfaces
     */
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),

    /*
     * AXI lite master interfaces
     */
    .m_axil_awaddr(m_axil_awaddr),
    .m_axil_awprot(m_axil_awprot),
    .m_axil_awvalid(m_axil_awvalid),
    .m_axil_awready(m_axil_awready),
    .m_axil_wdata(m_axil_wdata),
    .m_axil_wstrb(m_axil_wstrb),
    .m_axil_wvalid(m_axil_wvalid),
    .m_axil_wready(m_axil_wready),
    .m_axil_bresp(m_axil_bresp),
    .m_axil_bvalid(m_axil_bvalid),
    .m_axil_bready(m_axil_bready)
);

axil_crossbar_rd #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
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
axil_crossbar_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI lite slave interfaces
     */
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),

    /*
     * AXI lite master interfaces
     */
    .m_axil_araddr(m_axil_araddr),
    .m_axil_arprot(m_axil_arprot),
    .m_axil_arvalid(m_axil_arvalid),
    .m_axil_arready(m_axil_arready),
    .m_axil_rdata(m_axil_rdata),
    .m_axil_rresp(m_axil_rresp),
    .m_axil_rvalid(m_axil_rvalid),
    .m_axil_rready(m_axil_rready)
);

endmodule

`resetall
