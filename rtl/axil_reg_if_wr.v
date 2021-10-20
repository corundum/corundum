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
 * AXI lite register interface module (write)
 */
module axil_reg_if_wr #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Timeout delay (cycles)
    parameter TIMEOUT = 4
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI-Lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,

    /*
     * Register interface
     */
    output wire [ADDR_WIDTH-1:0]  reg_wr_addr,
    output wire [DATA_WIDTH-1:0]  reg_wr_data,
    output wire [STRB_WIDTH-1:0]  reg_wr_strb,
    output wire                   reg_wr_en,
    input  wire                   reg_wr_wait,
    input  wire                   reg_wr_ack
);

parameter TIMEOUT_WIDTH = $clog2(TIMEOUT);

reg [TIMEOUT_WIDTH-1:0] timeout_count_reg = 0, timeout_count_next;

reg [ADDR_WIDTH-1:0] s_axil_awaddr_reg = {ADDR_WIDTH{1'b0}}, s_axil_awaddr_next;
reg s_axil_awvalid_reg = 1'b0, s_axil_awvalid_next;
reg [DATA_WIDTH-1:0] s_axil_wdata_reg = {DATA_WIDTH{1'b0}}, s_axil_wdata_next;
reg [STRB_WIDTH-1:0] s_axil_wstrb_reg = {STRB_WIDTH{1'b0}}, s_axil_wstrb_next;
reg s_axil_wvalid_reg = 1'b0, s_axil_wvalid_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

reg reg_wr_en_reg = 1'b0, reg_wr_en_next;

assign s_axil_awready = !s_axil_awvalid_reg;
assign s_axil_wready = !s_axil_wvalid_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;

assign reg_wr_addr = s_axil_awaddr_reg;
assign reg_wr_data = s_axil_wdata_reg;
assign reg_wr_strb = s_axil_wstrb_reg;
assign reg_wr_en = reg_wr_en_reg;

always @* begin
    timeout_count_next = timeout_count_reg;

    s_axil_awaddr_next = s_axil_awaddr_reg;
    s_axil_awvalid_next = s_axil_awvalid_reg;
    s_axil_wdata_next = s_axil_wdata_reg;
    s_axil_wstrb_next = s_axil_wstrb_reg;
    s_axil_wvalid_next = s_axil_wvalid_reg;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    if (reg_wr_en_reg && (reg_wr_ack || timeout_count_reg == 0)) begin
        s_axil_awvalid_next = 1'b0;
        s_axil_wvalid_next = 1'b0;
        s_axil_bvalid_next = 1'b1;
    end

    if (!s_axil_awvalid_reg) begin
        s_axil_awaddr_next = s_axil_awaddr;
        s_axil_awvalid_next = s_axil_awvalid;
        timeout_count_next = TIMEOUT-1;
    end

    if (!s_axil_wvalid_reg) begin
        s_axil_wdata_next = s_axil_wdata;
        s_axil_wstrb_next = s_axil_wstrb;
        s_axil_wvalid_next = s_axil_wvalid;
    end

    if (reg_wr_en && !reg_wr_wait && timeout_count_reg != 0)begin
        timeout_count_next = timeout_count_reg - 1;
    end

    reg_wr_en_next = s_axil_awvalid_next && s_axil_wvalid_next && !s_axil_bvalid_next;
end

always @(posedge clk) begin
    timeout_count_reg <= timeout_count_next;

    s_axil_awaddr_reg <= s_axil_awaddr_next;
    s_axil_awvalid_reg <= s_axil_awvalid_next;
    s_axil_wdata_reg <= s_axil_wdata_next;
    s_axil_wstrb_reg <= s_axil_wstrb_next;
    s_axil_wvalid_reg <= s_axil_wvalid_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    reg_wr_en_reg <= reg_wr_en_next;

    if (rst) begin
        s_axil_awvalid_reg <= 1'b0;
        s_axil_wvalid_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
        reg_wr_en_reg <= 1'b0;
    end
end

endmodule

`resetall
