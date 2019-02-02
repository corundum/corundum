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

`timescale 1ns / 1ps

/*
 * AXI4 RAM read/write interface
 */
module axi_ram_wr_rd_if #
(
    parameter DATA_WIDTH = 32,  // width of data bus in bits
    parameter ADDR_WIDTH = 16,  // width of address bus in bits
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter ID_WIDTH = 8,
    parameter PIPELINE_OUTPUT = 0,
    parameter INTERLEAVE = 0
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awlock,
    input  wire [3:0]             s_axi_awcache,
    input  wire [2:0]             s_axi_awprot,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,
    output wire [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,
    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arlock,
    input  wire [3:0]             s_axi_arcache,
    input  wire [2:0]             s_axi_arprot,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,
    output wire [ID_WIDTH-1:0]    s_axi_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready,

    /*
     * RAM interface
     */
    output wire [ID_WIDTH-1:0]    ram_cmd_id,
    output wire [ADDR_WIDTH-1:0]  ram_cmd_addr,
    output wire [DATA_WIDTH-1:0]  ram_cmd_wr_data,
    output wire [STRB_WIDTH-1:0]  ram_cmd_wr_strb,
    output wire                   ram_cmd_wr_en,
    output wire                   ram_cmd_rd_en,
    output wire                   ram_cmd_last,
    input  wire                   ram_cmd_ready,
    input  wire [ID_WIDTH-1:0]    ram_rd_resp_id,
    input  wire [DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire                   ram_rd_resp_last,
    input  wire                   ram_rd_resp_valid,
    output wire                   ram_rd_resp_ready
);

wire [ADDR_WIDTH-1:0]  ram_wr_cmd_addr;
wire                   ram_wr_cmd_en;
wire                   ram_wr_cmd_last;
wire                   ram_wr_cmd_ready;

wire [ADDR_WIDTH-1:0]  ram_rd_cmd_addr;
wire                   ram_rd_cmd_en;
wire                   ram_rd_cmd_last;
wire                   ram_rd_cmd_ready;

axi_ram_wr_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH)
)
axi_ram_wr_if_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_cmd_wr_data),
    .ram_wr_cmd_strb(ram_cmd_wr_strb),
    .ram_wr_cmd_en(ram_wr_cmd_en),
    .ram_wr_cmd_last(ram_wr_cmd_last),
    .ram_wr_cmd_ready(ram_wr_cmd_ready)
);

axi_ram_rd_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .PIPELINE_OUTPUT(PIPELINE_OUTPUT)
)
axi_ram_rd_if_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .ram_rd_cmd_id(ram_cmd_id),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_en(ram_rd_cmd_en),
    .ram_rd_cmd_last(ram_rd_cmd_last),
    .ram_rd_cmd_ready(ram_rd_cmd_ready),
    .ram_rd_resp_id(ram_rd_resp_id),
    .ram_rd_resp_data(ram_rd_resp_data),
    .ram_rd_resp_last(ram_rd_resp_last),
    .ram_rd_resp_valid(ram_rd_resp_valid),
    .ram_rd_resp_ready(ram_rd_resp_ready)
);

// arbitration
reg read_eligible;
reg write_eligible;

reg write_en;
reg read_en;

reg last_read_reg = 1'b0, last_read_next;
reg transaction_reg = 1'b0, transaction_next;

assign ram_cmd_wr_en = write_en;
assign ram_cmd_rd_en = read_en;

assign ram_cmd_addr = ram_cmd_rd_en ? ram_rd_cmd_addr : ram_wr_cmd_addr;
assign ram_cmd_last = ram_cmd_rd_en ? ram_rd_cmd_last : ram_wr_cmd_last;

assign ram_wr_cmd_ready = ram_cmd_ready && write_en;
assign ram_rd_cmd_ready = ram_cmd_ready && read_en;

always @* begin
    write_en = 1'b0;
    read_en = 1'b0;

    last_read_next = last_read_reg;
    transaction_next = transaction_reg;

    write_eligible = ram_wr_cmd_en && ram_cmd_ready;
    read_eligible = ram_rd_cmd_en && ram_cmd_ready;

    if (write_eligible && (!read_eligible || last_read_reg || (!INTERLEAVE && transaction_reg)) && (INTERLEAVE || !transaction_reg || !last_read_reg)) begin
        last_read_next = 1'b0;
        transaction_next = !ram_wr_cmd_last;

        write_en = 1'b1;
    end else if (read_eligible && (INTERLEAVE || !transaction_reg || last_read_reg)) begin
        last_read_next = 1'b1;
        transaction_next = !ram_rd_cmd_last;

        read_en = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        last_read_reg <= 1'b0;
        transaction_reg <= 1'b0;
    end else begin
        last_read_reg <= last_read_next;
        transaction_reg <= transaction_next;
    end
end

endmodule
