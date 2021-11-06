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
 * Statistics counter
 */
module stats_counter #
(
    // Statistics counter increment width (bits)
    parameter STAT_INC_WIDTH = 16,
    // Statistics counter ID width (bits)
    parameter STAT_ID_WIDTH = 8,
    // Statistics counter (bits)
    parameter STAT_COUNT_WIDTH = 32,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = STAT_ID_WIDTH+$clog2(((AXIL_DATA_WIDTH > STAT_COUNT_WIDTH ? AXIL_DATA_WIDTH : STAT_COUNT_WIDTH)+7)/8),
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * Statistics increment input
     */
    input  wire [STAT_INC_WIDTH-1:0]   s_axis_stat_tdata,
    input  wire [STAT_ID_WIDTH-1:0]    s_axis_stat_tid,
    input  wire                        s_axis_stat_tvalid,
    output wire                        s_axis_stat_tready,

    /*
     * AXI Lite register interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]                  s_axil_awprot,
    input  wire                        s_axil_awvalid,
    output wire                        s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                        s_axil_wvalid,
    output wire                        s_axil_wready,
    output wire [1:0]                  s_axil_bresp,
    output wire                        s_axil_bvalid,
    input  wire                        s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]                  s_axil_arprot,
    input  wire                        s_axil_arvalid,
    output wire                        s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]                  s_axil_rresp,
    output wire                        s_axil_rvalid,
    input  wire                        s_axil_rready
);

parameter ID_SHIFT = $clog2(((AXIL_DATA_WIDTH > STAT_COUNT_WIDTH ? AXIL_DATA_WIDTH : STAT_COUNT_WIDTH)+7)/8);
parameter WORD_SELECT_SHIFT = $clog2(AXIL_DATA_WIDTH/8);
parameter WORD_SELECT_WIDTH = STAT_COUNT_WIDTH > AXIL_DATA_WIDTH ? $clog2((STAT_COUNT_WIDTH+7)/8) - $clog2(AXIL_DATA_WIDTH/8) : 0;

// bus width assertions
initial begin
    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: AXI lite interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIL_ADDR_WIDTH < STAT_ID_WIDTH+ID_SHIFT) begin
        $error("Error: AXI lite address width too narrow (instance %m)");
        $finish;
    end
end

localparam [1:0]
    STATE_INIT = 2'd0,
    STATE_IDLE = 2'd1,
    STATE_READ = 2'd2,
    STATE_WRITE = 2'd3;

reg [1:0] state_reg = STATE_INIT, state_next;

reg s_axis_stat_tready_reg = 1'b0, s_axis_stat_tready_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_reg = {AXIL_DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg [STAT_ID_WIDTH-1:0] id_reg = {STAT_ID_WIDTH{1'b0}}, id_next;
reg [STAT_INC_WIDTH-1:0] inc_reg = {STAT_INC_WIDTH{1'b0}}, inc_next;

reg rd_data_valid_reg = 1'b0, rd_data_valid_next;
reg [WORD_SELECT_WIDTH-1:0] rd_data_shift_reg = 0, rd_data_shift_next;

(* ramstyle = "no_rw_check" *)
reg [STAT_COUNT_WIDTH-1:0] mem_reg[(2**STAT_ID_WIDTH)-1:0];

reg [STAT_COUNT_WIDTH-1:0] mem_rd_data_reg = {STAT_COUNT_WIDTH{1'b0}};
reg [STAT_COUNT_WIDTH-1:0] mem_rd_data_axil_reg = {STAT_COUNT_WIDTH{1'b0}};

reg mem_rd_en;
reg mem_wr_en;
reg [STAT_COUNT_WIDTH-1:0] mem_wr_data;

reg mem_rd_en_axil;

wire [STAT_ID_WIDTH-1:0] s_axil_araddr_id = s_axil_araddr >> ID_SHIFT;
wire [WORD_SELECT_WIDTH-1:0] s_axil_araddr_word = s_axil_araddr >> WORD_SELECT_SHIFT;

assign s_axis_stat_tready = s_axis_stat_tready_reg;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

integer i, j;

initial begin
    // two nested loops for smaller number of iterations per loop
    // workaround for synthesizer complaints about large loop counts
    for (i = 0; i < 2**STAT_ID_WIDTH; i = i + 2**(STAT_ID_WIDTH/2)) begin
        for (j = i; j < i + 2**(STAT_ID_WIDTH/2); j = j + 1) begin
            mem_reg[j] = 0;
        end
    end
end

// accumulate
always @* begin
    state_next = STATE_IDLE;

    s_axis_stat_tready_next = 1'b0;

    id_next = id_reg;
    inc_next = inc_reg;

    mem_rd_en = 1'b0;
    mem_wr_en = 1'b0;
    mem_wr_data = mem_rd_data_reg + inc_reg;

    case (state_reg)
        STATE_INIT: begin
            id_next = id_reg + 1;
            mem_wr_en = 1'b1;
            mem_wr_data = 0;

            if (id_reg == {STAT_ID_WIDTH{1'b1}}) begin
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_INIT;
            end
        end
        STATE_IDLE: begin
            s_axis_stat_tready_next = 1'b1;

            if (s_axis_stat_tvalid && s_axis_stat_tready) begin
                inc_next = s_axis_stat_tdata;
                id_next = s_axis_stat_tid;
                s_axis_stat_tready_next = 1'b0;
                state_next = STATE_READ;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_READ: begin
            s_axis_stat_tready_next = 1'b1;
            mem_rd_en = 1'b1;
            state_next = STATE_WRITE;
        end
        STATE_WRITE: begin
            s_axis_stat_tready_next = 1'b1;
            mem_wr_en = 1'b1;
            mem_wr_data = mem_rd_data_reg + inc_reg;

            if (s_axis_stat_tvalid && s_axis_stat_tready) begin
                inc_next = s_axis_stat_tdata;
                id_next = s_axis_stat_tid;
                s_axis_stat_tready_next = 1'b0;
                state_next = STATE_READ;
            end else begin
                state_next = STATE_IDLE;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    s_axis_stat_tready_reg <= s_axis_stat_tready_next;

    id_reg <= id_next;
    inc_reg <= inc_next;

    if (mem_wr_en) begin
        mem_reg[id_reg] <= mem_wr_data;
    end else if (mem_rd_en) begin
        mem_rd_data_reg <= mem_reg[id_reg];
    end

    if (rst) begin
        state_reg <= STATE_INIT;
        s_axis_stat_tready_reg <= 1'b0;
        id_reg <= {STAT_ID_WIDTH{1'b0}};
    end
end

// register interface
always @* begin
    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    if (s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready)) begin
        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;
    end
end

always @(posedge clk) begin
    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    if (rst) begin
        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
    end
end

always @* begin
    s_axil_arready_next = 1'b0;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;
    s_axil_rdata_next = s_axil_rdata_reg;

    rd_data_valid_next = rd_data_valid_reg;
    rd_data_shift_next = rd_data_shift_reg;

    mem_rd_en_axil = 1'b0;

    if (rd_data_valid_reg && (!s_axil_rvalid || s_axil_rready)) begin
        s_axil_rvalid_next = 1'b1;
        rd_data_valid_next = 1'b0;

        if (STAT_COUNT_WIDTH > AXIL_DATA_WIDTH) begin
            s_axil_rdata_next = mem_rd_data_axil_reg >> rd_data_shift_reg*AXIL_DATA_WIDTH;
        end else begin
            s_axil_rdata_next = mem_rd_data_axil_reg;
        end
    end

    if (s_axil_arvalid && (!s_axil_rvalid || s_axil_rready || !rd_data_valid_reg) && !s_axil_arready) begin
        s_axil_arready_next = 1'b1;
        rd_data_valid_next = 1'b1;
        rd_data_shift_next = s_axil_araddr_word;

        mem_rd_en_axil = 1'b1;
    end
end

always @(posedge clk) begin
    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;
    s_axil_rdata_reg <= s_axil_rdata_next;

    rd_data_valid_reg <= rd_data_valid_next;
    rd_data_shift_reg <= rd_data_shift_next;

    if (mem_rd_en_axil) begin
        mem_rd_data_axil_reg <= mem_reg[s_axil_araddr_id];
    end

    if (rst) begin
        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
        rd_data_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
