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
 * AXI4 dual port RAM
 */
module axi_dp_ram #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 16,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
    // Extra pipeline register on output port A
    parameter A_PIPELINE_OUTPUT = 0,
    // Extra pipeline register on output port B
    parameter B_PIPELINE_OUTPUT = 0,
    // Interleave read and write burst cycles on port A
    parameter A_INTERLEAVE = 0,
    // Interleave read and write burst cycles on port B
    parameter B_INTERLEAVE = 0
)
(
    input  wire                   a_clk,
    input  wire                   a_rst,

    input  wire                   b_clk,
    input  wire                   b_rst,

    input  wire [ID_WIDTH-1:0]    s_axi_a_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_a_awaddr,
    input  wire [7:0]             s_axi_a_awlen,
    input  wire [2:0]             s_axi_a_awsize,
    input  wire [1:0]             s_axi_a_awburst,
    input  wire                   s_axi_a_awlock,
    input  wire [3:0]             s_axi_a_awcache,
    input  wire [2:0]             s_axi_a_awprot,
    input  wire                   s_axi_a_awvalid,
    output wire                   s_axi_a_awready,
    input  wire [DATA_WIDTH-1:0]  s_axi_a_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_a_wstrb,
    input  wire                   s_axi_a_wlast,
    input  wire                   s_axi_a_wvalid,
    output wire                   s_axi_a_wready,
    output wire [ID_WIDTH-1:0]    s_axi_a_bid,
    output wire [1:0]             s_axi_a_bresp,
    output wire                   s_axi_a_bvalid,
    input  wire                   s_axi_a_bready,
    input  wire [ID_WIDTH-1:0]    s_axi_a_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_a_araddr,
    input  wire [7:0]             s_axi_a_arlen,
    input  wire [2:0]             s_axi_a_arsize,
    input  wire [1:0]             s_axi_a_arburst,
    input  wire                   s_axi_a_arlock,
    input  wire [3:0]             s_axi_a_arcache,
    input  wire [2:0]             s_axi_a_arprot,
    input  wire                   s_axi_a_arvalid,
    output wire                   s_axi_a_arready,
    output wire [ID_WIDTH-1:0]    s_axi_a_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_a_rdata,
    output wire [1:0]             s_axi_a_rresp,
    output wire                   s_axi_a_rlast,
    output wire                   s_axi_a_rvalid,
    input  wire                   s_axi_a_rready,

    input  wire [ID_WIDTH-1:0]    s_axi_b_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_b_awaddr,
    input  wire [7:0]             s_axi_b_awlen,
    input  wire [2:0]             s_axi_b_awsize,
    input  wire [1:0]             s_axi_b_awburst,
    input  wire                   s_axi_b_awlock,
    input  wire [3:0]             s_axi_b_awcache,
    input  wire [2:0]             s_axi_b_awprot,
    input  wire                   s_axi_b_awvalid,
    output wire                   s_axi_b_awready,
    input  wire [DATA_WIDTH-1:0]  s_axi_b_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_b_wstrb,
    input  wire                   s_axi_b_wlast,
    input  wire                   s_axi_b_wvalid,
    output wire                   s_axi_b_wready,
    output wire [ID_WIDTH-1:0]    s_axi_b_bid,
    output wire [1:0]             s_axi_b_bresp,
    output wire                   s_axi_b_bvalid,
    input  wire                   s_axi_b_bready,
    input  wire [ID_WIDTH-1:0]    s_axi_b_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_b_araddr,
    input  wire [7:0]             s_axi_b_arlen,
    input  wire [2:0]             s_axi_b_arsize,
    input  wire [1:0]             s_axi_b_arburst,
    input  wire                   s_axi_b_arlock,
    input  wire [3:0]             s_axi_b_arcache,
    input  wire [2:0]             s_axi_b_arprot,
    input  wire                   s_axi_b_arvalid,
    output wire                   s_axi_b_arready,
    output wire [ID_WIDTH-1:0]    s_axi_b_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_b_rdata,
    output wire [1:0]             s_axi_b_rresp,
    output wire                   s_axi_b_rlast,
    output wire                   s_axi_b_rvalid,
    input  wire                   s_axi_b_rready
);

parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
parameter WORD_WIDTH = STRB_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

// bus width assertions
initial begin
    if (WORD_SIZE * STRB_WIDTH != DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisble (instance %m)");
        $finish;
    end

    if (2**$clog2(WORD_WIDTH) != WORD_WIDTH) begin
        $error("Error: AXI word width must be even power of two (instance %m)");
        $finish;
    end
end

wire [ID_WIDTH-1:0]    ram_a_cmd_id;
wire [ADDR_WIDTH-1:0]  ram_a_cmd_addr;
wire [DATA_WIDTH-1:0]  ram_a_cmd_wr_data;
wire [STRB_WIDTH-1:0]  ram_a_cmd_wr_strb;
wire                   ram_a_cmd_wr_en;
wire                   ram_a_cmd_rd_en;
wire                   ram_a_cmd_last;
wire                   ram_a_cmd_ready;
reg  [ID_WIDTH-1:0]    ram_a_rd_resp_id_reg = {ID_WIDTH{1'b0}};
reg  [DATA_WIDTH-1:0]  ram_a_rd_resp_data_reg = {DATA_WIDTH{1'b0}};
reg                    ram_a_rd_resp_last_reg = 1'b0;
reg                    ram_a_rd_resp_valid_reg = 1'b0;
wire                   ram_a_rd_resp_ready;

wire [ID_WIDTH-1:0]    ram_b_cmd_id;
wire [ADDR_WIDTH-1:0]  ram_b_cmd_addr;
wire [DATA_WIDTH-1:0]  ram_b_cmd_wr_data;
wire [STRB_WIDTH-1:0]  ram_b_cmd_wr_strb;
wire                   ram_b_cmd_wr_en;
wire                   ram_b_cmd_rd_en;
wire                   ram_b_cmd_last;
wire                   ram_b_cmd_ready;
reg  [ID_WIDTH-1:0]    ram_b_rd_resp_id_reg = {ID_WIDTH{1'b0}};
reg  [DATA_WIDTH-1:0]  ram_b_rd_resp_data_reg = {DATA_WIDTH{1'b0}};
reg                    ram_b_rd_resp_last_reg = 1'b0;
reg                    ram_b_rd_resp_valid_reg = 1'b0;
wire                   ram_b_rd_resp_ready;

axi_ram_wr_rd_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AWUSER_ENABLE(0),
    .WUSER_ENABLE(0),
    .BUSER_ENABLE(0),
    .ARUSER_ENABLE(0),
    .RUSER_ENABLE(0),
    .PIPELINE_OUTPUT(A_PIPELINE_OUTPUT),
    .INTERLEAVE(A_INTERLEAVE)
)
a_if (
    .clk(a_clk),
    .rst(a_rst),

    /*
     * AXI slave interface
     */
    .s_axi_awid(s_axi_a_awid),
    .s_axi_awaddr(s_axi_a_awaddr),
    .s_axi_awlen(s_axi_a_awlen),
    .s_axi_awsize(s_axi_a_awsize),
    .s_axi_awburst(s_axi_a_awburst),
    .s_axi_awlock(s_axi_a_awlock),
    .s_axi_awcache(s_axi_a_awcache),
    .s_axi_awprot(s_axi_a_awprot),
    .s_axi_awqos(4'd0),
    .s_axi_awregion(4'd0),
    .s_axi_awuser(0),
    .s_axi_awvalid(s_axi_a_awvalid),
    .s_axi_awready(s_axi_a_awready),
    .s_axi_wdata(s_axi_a_wdata),
    .s_axi_wstrb(s_axi_a_wstrb),
    .s_axi_wlast(s_axi_a_wlast),
    .s_axi_wuser(0),
    .s_axi_wvalid(s_axi_a_wvalid),
    .s_axi_wready(s_axi_a_wready),
    .s_axi_bid(s_axi_a_bid),
    .s_axi_bresp(s_axi_a_bresp),
    .s_axi_buser(),
    .s_axi_bvalid(s_axi_a_bvalid),
    .s_axi_bready(s_axi_a_bready),
    .s_axi_arid(s_axi_a_arid),
    .s_axi_araddr(s_axi_a_araddr),
    .s_axi_arlen(s_axi_a_arlen),
    .s_axi_arsize(s_axi_a_arsize),
    .s_axi_arburst(s_axi_a_arburst),
    .s_axi_arlock(s_axi_a_arlock),
    .s_axi_arcache(s_axi_a_arcache),
    .s_axi_arprot(s_axi_a_arprot),
    .s_axi_arqos(4'd0),
    .s_axi_arregion(4'd0),
    .s_axi_aruser(0),
    .s_axi_arvalid(s_axi_a_arvalid),
    .s_axi_arready(s_axi_a_arready),
    .s_axi_rid(s_axi_a_rid),
    .s_axi_rdata(s_axi_a_rdata),
    .s_axi_rresp(s_axi_a_rresp),
    .s_axi_rlast(s_axi_a_rlast),
    .s_axi_ruser(),
    .s_axi_rvalid(s_axi_a_rvalid),
    .s_axi_rready(s_axi_a_rready),

    /*
     * RAM interface
     */
    .ram_cmd_id(ram_a_cmd_id),
    .ram_cmd_addr(ram_a_cmd_addr),
    .ram_cmd_lock(),
    .ram_cmd_cache(),
    .ram_cmd_prot(),
    .ram_cmd_qos(),
    .ram_cmd_region(),
    .ram_cmd_auser(),
    .ram_cmd_wr_data(ram_a_cmd_wr_data),
    .ram_cmd_wr_strb(ram_a_cmd_wr_strb),
    .ram_cmd_wr_user(),
    .ram_cmd_wr_en(ram_a_cmd_wr_en),
    .ram_cmd_rd_en(ram_a_cmd_rd_en),
    .ram_cmd_last(ram_a_cmd_last),
    .ram_cmd_ready(ram_a_cmd_ready),
    .ram_rd_resp_id(ram_a_rd_resp_id_reg),
    .ram_rd_resp_data(ram_a_rd_resp_data_reg),
    .ram_rd_resp_last(ram_a_rd_resp_last_reg),
    .ram_rd_resp_user(0),
    .ram_rd_resp_valid(ram_a_rd_resp_valid_reg),
    .ram_rd_resp_ready(ram_a_rd_resp_ready)
);

axi_ram_wr_rd_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AWUSER_ENABLE(0),
    .WUSER_ENABLE(0),
    .BUSER_ENABLE(0),
    .ARUSER_ENABLE(0),
    .RUSER_ENABLE(0),
    .PIPELINE_OUTPUT(B_PIPELINE_OUTPUT),
    .INTERLEAVE(B_INTERLEAVE)
)
b_if (
    .clk(b_clk),
    .rst(b_rst),

    /*
     * AXI slave interface
     */
    .s_axi_awid(s_axi_b_awid),
    .s_axi_awaddr(s_axi_b_awaddr),
    .s_axi_awlen(s_axi_b_awlen),
    .s_axi_awsize(s_axi_b_awsize),
    .s_axi_awburst(s_axi_b_awburst),
    .s_axi_awlock(s_axi_b_awlock),
    .s_axi_awcache(s_axi_b_awcache),
    .s_axi_awprot(s_axi_b_awprot),
    .s_axi_awqos(4'd0),
    .s_axi_awregion(4'd0),
    .s_axi_awuser(0),
    .s_axi_awvalid(s_axi_b_awvalid),
    .s_axi_awready(s_axi_b_awready),
    .s_axi_wdata(s_axi_b_wdata),
    .s_axi_wstrb(s_axi_b_wstrb),
    .s_axi_wlast(s_axi_b_wlast),
    .s_axi_wuser(0),
    .s_axi_wvalid(s_axi_b_wvalid),
    .s_axi_wready(s_axi_b_wready),
    .s_axi_bid(s_axi_b_bid),
    .s_axi_bresp(s_axi_b_bresp),
    .s_axi_buser(),
    .s_axi_bvalid(s_axi_b_bvalid),
    .s_axi_bready(s_axi_b_bready),
    .s_axi_arid(s_axi_b_arid),
    .s_axi_araddr(s_axi_b_araddr),
    .s_axi_arlen(s_axi_b_arlen),
    .s_axi_arsize(s_axi_b_arsize),
    .s_axi_arburst(s_axi_b_arburst),
    .s_axi_arlock(s_axi_b_arlock),
    .s_axi_arcache(s_axi_b_arcache),
    .s_axi_arprot(s_axi_b_arprot),
    .s_axi_arqos(4'd0),
    .s_axi_arregion(4'd0),
    .s_axi_aruser(0),
    .s_axi_arvalid(s_axi_b_arvalid),
    .s_axi_arready(s_axi_b_arready),
    .s_axi_rid(s_axi_b_rid),
    .s_axi_rdata(s_axi_b_rdata),
    .s_axi_rresp(s_axi_b_rresp),
    .s_axi_rlast(s_axi_b_rlast),
    .s_axi_ruser(),
    .s_axi_rvalid(s_axi_b_rvalid),
    .s_axi_rready(s_axi_b_rready),

    /*
     * RAM interface
     */
    .ram_cmd_id(ram_b_cmd_id),
    .ram_cmd_addr(ram_b_cmd_addr),
    .ram_cmd_lock(),
    .ram_cmd_cache(),
    .ram_cmd_prot(),
    .ram_cmd_qos(),
    .ram_cmd_region(),
    .ram_cmd_auser(),
    .ram_cmd_wr_data(ram_b_cmd_wr_data),
    .ram_cmd_wr_strb(ram_b_cmd_wr_strb),
    .ram_cmd_wr_user(),
    .ram_cmd_wr_en(ram_b_cmd_wr_en),
    .ram_cmd_rd_en(ram_b_cmd_rd_en),
    .ram_cmd_last(ram_b_cmd_last),
    .ram_cmd_ready(ram_b_cmd_ready),
    .ram_rd_resp_id(ram_b_rd_resp_id_reg),
    .ram_rd_resp_data(ram_b_rd_resp_data_reg),
    .ram_rd_resp_last(ram_b_rd_resp_last_reg),
    .ram_rd_resp_user(0),
    .ram_rd_resp_valid(ram_b_rd_resp_valid_reg),
    .ram_rd_resp_ready(ram_b_rd_resp_ready)
);

// (* RAM_STYLE="BLOCK" *)
reg [DATA_WIDTH-1:0] mem[(2**VALID_ADDR_WIDTH)-1:0];

wire [VALID_ADDR_WIDTH-1:0] addr_a_valid = ram_a_cmd_addr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
wire [VALID_ADDR_WIDTH-1:0] addr_b_valid = ram_b_cmd_addr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);

integer i, j;

initial begin
    // two nested loops for smaller number of iterations per loop
    // workaround for synthesizer complaints about large loop counts
    for (i = 0; i < 2**VALID_ADDR_WIDTH; i = i + 2**(VALID_ADDR_WIDTH/2)) begin
        for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin
            mem[j] = 0;
        end
    end
end

assign ram_a_cmd_ready = !ram_a_rd_resp_valid_reg || ram_a_rd_resp_ready;

always @(posedge a_clk) begin
    ram_a_rd_resp_valid_reg <= ram_a_rd_resp_valid_reg && !ram_a_rd_resp_ready;

    if (ram_a_cmd_rd_en && ram_a_cmd_ready) begin
        ram_a_rd_resp_id_reg <= ram_a_cmd_id;
        ram_a_rd_resp_data_reg <= mem[addr_a_valid];
        ram_a_rd_resp_last_reg <= ram_a_cmd_last;
        ram_a_rd_resp_valid_reg <= 1'b1;
    end else if (ram_a_cmd_wr_en && ram_a_cmd_ready) begin
        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (ram_a_cmd_wr_strb[i]) begin
                mem[addr_a_valid][WORD_SIZE*i +: WORD_SIZE] <= ram_a_cmd_wr_data[WORD_SIZE*i +: WORD_SIZE];
            end
        end
    end

    if (a_rst) begin
        ram_a_rd_resp_valid_reg <= 1'b0;
    end
end

assign ram_b_cmd_ready = !ram_b_rd_resp_valid_reg || ram_b_rd_resp_ready;

always @(posedge b_clk) begin
    ram_b_rd_resp_valid_reg <= ram_b_rd_resp_valid_reg && !ram_b_rd_resp_ready;

    if (ram_b_cmd_rd_en && ram_b_cmd_ready) begin
        ram_b_rd_resp_id_reg <= ram_b_cmd_id;
        ram_b_rd_resp_data_reg <= mem[addr_b_valid];
        ram_b_rd_resp_last_reg <= ram_b_cmd_last;
        ram_b_rd_resp_valid_reg <= 1'b1;
    end else if (ram_b_cmd_wr_en && ram_b_cmd_ready) begin
        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (ram_b_cmd_wr_strb[i]) begin
                mem[addr_b_valid][WORD_SIZE*i +: WORD_SIZE] <= ram_b_cmd_wr_data[WORD_SIZE*i +: WORD_SIZE];
            end
        end
    end

    if (b_rst) begin
        ram_b_rd_resp_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
