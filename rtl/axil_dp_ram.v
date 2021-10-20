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
 * AXI4-Lite dual port RAM
 */
module axil_dp_ram #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 16,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Extra pipeline register on output
    parameter PIPELINE_OUTPUT = 0
)
(
    input  wire                   a_clk,
    input  wire                   a_rst,

    input  wire                   b_clk,
    input  wire                   b_rst,

    input  wire [ADDR_WIDTH-1:0]  s_axil_a_awaddr,
    input  wire [2:0]             s_axil_a_awprot,
    input  wire                   s_axil_a_awvalid,
    output wire                   s_axil_a_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_a_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_a_wstrb,
    input  wire                   s_axil_a_wvalid,
    output wire                   s_axil_a_wready,
    output wire [1:0]             s_axil_a_bresp,
    output wire                   s_axil_a_bvalid,
    input  wire                   s_axil_a_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_a_araddr,
    input  wire [2:0]             s_axil_a_arprot,
    input  wire                   s_axil_a_arvalid,
    output wire                   s_axil_a_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_a_rdata,
    output wire [1:0]             s_axil_a_rresp,
    output wire                   s_axil_a_rvalid,
    input  wire                   s_axil_a_rready,

    input  wire [ADDR_WIDTH-1:0]  s_axil_b_awaddr,
    input  wire [2:0]             s_axil_b_awprot,
    input  wire                   s_axil_b_awvalid,
    output wire                   s_axil_b_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_b_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_b_wstrb,
    input  wire                   s_axil_b_wvalid,
    output wire                   s_axil_b_wready,
    output wire [1:0]             s_axil_b_bresp,
    output wire                   s_axil_b_bvalid,
    input  wire                   s_axil_b_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_b_araddr,
    input  wire [2:0]             s_axil_b_arprot,
    input  wire                   s_axil_b_arvalid,
    output wire                   s_axil_b_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_b_rdata,
    output wire [1:0]             s_axil_b_rresp,
    output wire                   s_axil_b_rvalid,
    input  wire                   s_axil_b_rready
);

parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
parameter WORD_WIDTH = STRB_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

reg read_eligible_a;
reg write_eligible_a;

reg read_eligible_b;
reg write_eligible_b;

reg mem_wr_en_a;
reg mem_rd_en_a;

reg mem_wr_en_b;
reg mem_rd_en_b;

reg last_read_a_reg = 1'b0, last_read_a_next;
reg last_read_b_reg = 1'b0, last_read_b_next;

reg s_axil_a_awready_reg = 1'b0, s_axil_a_awready_next;
reg s_axil_a_wready_reg = 1'b0, s_axil_a_wready_next;
reg s_axil_a_bvalid_reg = 1'b0, s_axil_a_bvalid_next;
reg s_axil_a_arready_reg = 1'b0, s_axil_a_arready_next;
reg [DATA_WIDTH-1:0] s_axil_a_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_a_rdata_next;
reg s_axil_a_rvalid_reg = 1'b0, s_axil_a_rvalid_next;
reg [DATA_WIDTH-1:0] s_axil_a_rdata_pipe_reg = {DATA_WIDTH{1'b0}};
reg s_axil_a_rvalid_pipe_reg = 1'b0;

reg s_axil_b_awready_reg = 1'b0, s_axil_b_awready_next;
reg s_axil_b_wready_reg = 1'b0, s_axil_b_wready_next;
reg s_axil_b_bvalid_reg = 1'b0, s_axil_b_bvalid_next;
reg s_axil_b_arready_reg = 1'b0, s_axil_b_arready_next;
reg [DATA_WIDTH-1:0] s_axil_b_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_b_rdata_next;
reg s_axil_b_rvalid_reg = 1'b0, s_axil_b_rvalid_next;
reg [DATA_WIDTH-1:0] s_axil_b_rdata_pipe_reg = {DATA_WIDTH{1'b0}};
reg s_axil_b_rvalid_pipe_reg = 1'b0;

// (* RAM_STYLE="BLOCK" *)
reg [DATA_WIDTH-1:0] mem[(2**VALID_ADDR_WIDTH)-1:0];

wire [VALID_ADDR_WIDTH-1:0] s_axil_a_awaddr_valid = s_axil_a_awaddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
wire [VALID_ADDR_WIDTH-1:0] s_axil_a_araddr_valid = s_axil_a_araddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);

wire [VALID_ADDR_WIDTH-1:0] s_axil_b_awaddr_valid = s_axil_b_awaddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
wire [VALID_ADDR_WIDTH-1:0] s_axil_b_araddr_valid = s_axil_b_araddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);

assign s_axil_a_awready = s_axil_a_awready_reg;
assign s_axil_a_wready = s_axil_a_wready_reg;
assign s_axil_a_bresp = 2'b00;
assign s_axil_a_bvalid = s_axil_a_bvalid_reg;
assign s_axil_a_arready = s_axil_a_arready_reg;
assign s_axil_a_rdata = PIPELINE_OUTPUT ? s_axil_a_rdata_pipe_reg : s_axil_a_rdata_reg;
assign s_axil_a_rresp = 2'b00;
assign s_axil_a_rvalid = PIPELINE_OUTPUT ? s_axil_a_rvalid_pipe_reg : s_axil_a_rvalid_reg;

assign s_axil_b_awready = s_axil_b_awready_reg;
assign s_axil_b_wready = s_axil_b_wready_reg;
assign s_axil_b_bresp = 2'b00;
assign s_axil_b_bvalid = s_axil_b_bvalid_reg;
assign s_axil_b_arready = s_axil_b_arready_reg;
assign s_axil_b_rdata = PIPELINE_OUTPUT ? s_axil_b_rdata_pipe_reg : s_axil_b_rdata_reg;
assign s_axil_b_rresp = 2'b00;
assign s_axil_b_rvalid = PIPELINE_OUTPUT ? s_axil_b_rvalid_pipe_reg : s_axil_b_rvalid_reg;

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

always @* begin
    mem_wr_en_a = 1'b0;
    mem_rd_en_a = 1'b0;

    last_read_a_next = last_read_a_reg;

    s_axil_a_awready_next = 1'b0;
    s_axil_a_wready_next = 1'b0;
    s_axil_a_bvalid_next = s_axil_a_bvalid_reg && !s_axil_a_bready;

    s_axil_a_arready_next = 1'b0;
    s_axil_a_rvalid_next = s_axil_a_rvalid_reg && !(s_axil_a_rready || (PIPELINE_OUTPUT && !s_axil_a_rvalid_pipe_reg));

    write_eligible_a = s_axil_a_awvalid && s_axil_a_wvalid && (!s_axil_a_bvalid || s_axil_a_bready) && (!s_axil_a_awready && !s_axil_a_wready);
    read_eligible_a = s_axil_a_arvalid && (!s_axil_a_rvalid || s_axil_a_rready || (PIPELINE_OUTPUT && !s_axil_a_rvalid_pipe_reg)) && (!s_axil_a_arready);

    if (write_eligible_a && (!read_eligible_a || last_read_a_reg)) begin
        last_read_a_next = 1'b0;

        s_axil_a_awready_next = 1'b1;
        s_axil_a_wready_next = 1'b1;
        s_axil_a_bvalid_next = 1'b1;

        mem_wr_en_a = 1'b1;
    end else if (read_eligible_a) begin
        last_read_a_next = 1'b1;

        s_axil_a_arready_next = 1'b1;
        s_axil_a_rvalid_next = 1'b1;

        mem_rd_en_a = 1'b1;
    end
end

always @(posedge a_clk) begin
    last_read_a_reg <= last_read_a_next;

    s_axil_a_awready_reg <= s_axil_a_awready_next;
    s_axil_a_wready_reg <= s_axil_a_wready_next;
    s_axil_a_bvalid_reg <= s_axil_a_bvalid_next;

    s_axil_a_arready_reg <= s_axil_a_arready_next;
    s_axil_a_rvalid_reg <= s_axil_a_rvalid_next;

    if (mem_rd_en_a) begin
        s_axil_a_rdata_reg <= mem[s_axil_a_araddr_valid];
    end else begin
        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (mem_wr_en_a && s_axil_a_wstrb[i]) begin
                mem[s_axil_a_awaddr_valid][WORD_SIZE*i +: WORD_SIZE] <= s_axil_a_wdata[WORD_SIZE*i +: WORD_SIZE];
            end
        end
    end

    if (!s_axil_a_rvalid_pipe_reg || s_axil_a_rready) begin
        s_axil_a_rdata_pipe_reg <= s_axil_a_rdata_reg;
        s_axil_a_rvalid_pipe_reg <= s_axil_a_rvalid_reg;
    end

    if (a_rst) begin
        last_read_a_reg <= 1'b0;

        s_axil_a_awready_reg <= 1'b0;
        s_axil_a_wready_reg <= 1'b0;
        s_axil_a_bvalid_reg <= 1'b0;

        s_axil_a_arready_reg <= 1'b0;
        s_axil_a_rvalid_reg <= 1'b0;
        s_axil_a_rvalid_pipe_reg <= 1'b0;
    end
end

always @* begin
    mem_wr_en_b = 1'b0;
    mem_rd_en_b = 1'b0;

    last_read_b_next = last_read_b_reg;

    s_axil_b_awready_next = 1'b0;
    s_axil_b_wready_next = 1'b0;
    s_axil_b_bvalid_next = s_axil_b_bvalid_reg && !s_axil_b_bready;

    s_axil_b_arready_next = 1'b0;
    s_axil_b_rvalid_next = s_axil_b_rvalid_reg && !(s_axil_b_rready || (PIPELINE_OUTPUT && !s_axil_b_rvalid_pipe_reg));

    write_eligible_b = s_axil_b_awvalid && s_axil_b_wvalid && (!s_axil_b_bvalid || s_axil_b_bready) && (!s_axil_b_awready && !s_axil_b_wready);
    read_eligible_b = s_axil_b_arvalid && (!s_axil_b_rvalid || s_axil_b_rready || (PIPELINE_OUTPUT && !s_axil_b_rvalid_pipe_reg)) && (!s_axil_b_arready);

    if (write_eligible_b && (!read_eligible_b || last_read_b_reg)) begin
        last_read_b_next = 1'b0;

        s_axil_b_awready_next = 1'b1;
        s_axil_b_wready_next = 1'b1;
        s_axil_b_bvalid_next = 1'b1;

        mem_wr_en_b = 1'b1;
    end else if (read_eligible_b) begin
        last_read_b_next = 1'b1;

        s_axil_b_arready_next = 1'b1;
        s_axil_b_rvalid_next = 1'b1;

        mem_rd_en_b = 1'b1;
    end
end

always @(posedge b_clk) begin
        last_read_b_reg <= last_read_b_next;

    s_axil_b_awready_reg <= s_axil_b_awready_next;
    s_axil_b_wready_reg <= s_axil_b_wready_next;
    s_axil_b_bvalid_reg <= s_axil_b_bvalid_next;

    s_axil_b_arready_reg <= s_axil_b_arready_next;
    s_axil_b_rvalid_reg <= s_axil_b_rvalid_next;

    if (mem_rd_en_b) begin
        s_axil_b_rdata_reg <= mem[s_axil_b_araddr_valid];
    end else begin
        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (mem_wr_en_b && s_axil_b_wstrb[i]) begin
                mem[s_axil_b_awaddr_valid][WORD_SIZE*i +: WORD_SIZE] <= s_axil_b_wdata[WORD_SIZE*i +: WORD_SIZE];
            end
        end
    end

    if (!s_axil_b_rvalid_pipe_reg || s_axil_b_rready) begin
        s_axil_b_rdata_pipe_reg <= s_axil_b_rdata_reg;
        s_axil_b_rvalid_pipe_reg <= s_axil_b_rvalid_reg;
    end

    if (b_rst) begin
        last_read_b_reg <= 1'b0;

        s_axil_b_awready_reg <= 1'b0;
        s_axil_b_wready_reg <= 1'b0;
        s_axil_b_bvalid_reg <= 1'b0;

        s_axil_b_arready_reg <= 1'b0;
        s_axil_b_rvalid_reg <= 1'b0;
        s_axil_b_rvalid_pipe_reg <= 1'b0;
    end
end

endmodule

`resetall
