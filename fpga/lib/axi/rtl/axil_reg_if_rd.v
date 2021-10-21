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
 * AXI lite register interface module (read)
 */
module axil_reg_if_rd #
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
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,

    /*
     * Register interface
     */
    output wire [ADDR_WIDTH-1:0]  reg_rd_addr,
    output wire                   reg_rd_en,
    input  wire [DATA_WIDTH-1:0]  reg_rd_data,
    input  wire                   reg_rd_wait,
    input  wire                   reg_rd_ack
);

parameter TIMEOUT_WIDTH = $clog2(TIMEOUT);

reg [TIMEOUT_WIDTH-1:0] timeout_count_reg = 0, timeout_count_next;

reg [ADDR_WIDTH-1:0] s_axil_araddr_reg = {ADDR_WIDTH{1'b0}}, s_axil_araddr_next;
reg s_axil_arvalid_reg = 1'b0, s_axil_arvalid_next;
reg [DATA_WIDTH-1:0] s_axil_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg reg_rd_en_reg = 1'b0, reg_rd_en_next;

assign s_axil_arready = !s_axil_arvalid_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

assign reg_rd_addr = s_axil_araddr_reg;
assign reg_rd_en = reg_rd_en_reg;

always @* begin
    timeout_count_next = timeout_count_reg;

    s_axil_araddr_next = s_axil_araddr_reg;
    s_axil_arvalid_next = s_axil_arvalid_reg;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;

    if (reg_rd_en_reg && (reg_rd_ack || timeout_count_reg == 0)) begin
        s_axil_arvalid_next = 1'b0;
        s_axil_rdata_next = reg_rd_data;
        s_axil_rvalid_next = 1'b1;
    end

    if (!s_axil_arvalid_reg) begin
        s_axil_araddr_next = s_axil_araddr;
        s_axil_arvalid_next = s_axil_arvalid;
        timeout_count_next = TIMEOUT-1;
    end

    if (reg_rd_en && !reg_rd_wait && timeout_count_reg != 0)begin
        timeout_count_next = timeout_count_reg - 1;
    end

    reg_rd_en_next = s_axil_arvalid_next && !s_axil_rvalid_next;
end

always @(posedge clk) begin
    timeout_count_reg <= timeout_count_next;

    s_axil_araddr_reg <= s_axil_araddr_next;
    s_axil_arvalid_reg <= s_axil_arvalid_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    reg_rd_en_reg <= reg_rd_en_next;

    if (rst) begin
        s_axil_arvalid_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
        reg_rd_en_reg <= 1'b0;
    end
end

endmodule

`resetall
