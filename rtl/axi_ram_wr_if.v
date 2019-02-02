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
 * AXI4 RAM write interface
 */
module axi_ram_wr_if #
(
    parameter DATA_WIDTH = 32,  // width of data bus in bits
    parameter ADDR_WIDTH = 16,  // width of address bus in bits
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter ID_WIDTH = 8
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

    /*
     * RAM interface
     */
    output wire [ADDR_WIDTH-1:0]  ram_wr_cmd_addr,
    output wire [DATA_WIDTH-1:0]  ram_wr_cmd_data,
    output wire [STRB_WIDTH-1:0]  ram_wr_cmd_strb,
    output wire                   ram_wr_cmd_en,
    output wire                   ram_wr_cmd_last,
    input  wire                   ram_wr_cmd_ready
);

parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
parameter WORD_WIDTH = STRB_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

// bus width assertions
initial begin
    if (WORD_SIZE * STRB_WIDTH != DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisble");
        $finish;
    end

    if (2**$clog2(WORD_WIDTH) != WORD_WIDTH) begin
        $error("Error: AXI word width must be even power of two");
        $finish;
    end
end

localparam [0:0]
    STATE_IDLE = 1'd0,
    STATE_BURST = 1'd1;

reg [0:0] state_reg = STATE_IDLE, state_next;

reg [ID_WIDTH-1:0] write_id_reg = {ID_WIDTH{1'b0}}, write_id_next;
reg [ADDR_WIDTH-1:0] write_addr_reg = {ADDR_WIDTH{1'b0}}, write_addr_next;
reg write_addr_valid_reg = 1'b0, write_addr_valid_next;
reg write_addr_ready;
reg write_last_reg = 1'b0, write_last_next;
reg [7:0] write_count_reg = 8'd0, write_count_next;
reg [2:0] write_size_reg = 3'd0, write_size_next;
reg [1:0] write_burst_reg = 2'd0, write_burst_next;

reg s_axi_awready_reg = 1'b0, s_axi_awready_next;
reg [ID_WIDTH-1:0] s_axi_bid_reg = {ID_WIDTH{1'b0}}, s_axi_bid_next;
reg s_axi_bvalid_reg = 1'b0, s_axi_bvalid_next;

assign s_axi_awready = s_axi_awready_reg;
assign s_axi_wready = write_addr_valid_reg && ram_wr_cmd_ready;
assign s_axi_bid = s_axi_bid_reg;
assign s_axi_bresp = 2'b00;
assign s_axi_bvalid = s_axi_bvalid_reg;

assign ram_wr_cmd_addr = write_addr_reg;
assign ram_wr_cmd_data = s_axi_wdata;
assign ram_wr_cmd_strb = s_axi_wstrb;
assign ram_wr_cmd_en = write_addr_valid_reg && s_axi_wvalid;
assign ram_wr_cmd_last = write_last_reg;

always @* begin
    state_next = STATE_IDLE;

    write_addr_ready = 1'b0;

    write_id_next = write_id_reg;
    write_addr_next = write_addr_reg;
    write_addr_valid_next = write_addr_valid_reg;
    write_last_next = write_last_reg;
    write_count_next = write_count_reg;
    write_size_next = write_size_reg;
    write_burst_next = write_burst_reg;

    s_axi_awready_next = 1'b0;
    s_axi_bid_next = s_axi_bid_reg;
    s_axi_bvalid_next = s_axi_bvalid_reg && !s_axi_bready;

    if (ram_wr_cmd_ready && ram_wr_cmd_en) begin
        write_addr_ready = 1'b1;
        write_addr_valid_next = !write_last_reg;
    end

    case (state_reg)
        STATE_IDLE: begin
            s_axi_awready_next = (write_addr_ready || !write_addr_valid_reg) && (!s_axi_bvalid || s_axi_bready);

            if (s_axi_awready & s_axi_awvalid) begin
                write_id_next = s_axi_awid;
                write_addr_next = s_axi_awaddr;
                write_count_next = s_axi_awlen;
                write_size_next = s_axi_awsize < $clog2(STRB_WIDTH) ? s_axi_awsize : $clog2(STRB_WIDTH);
                write_burst_next = s_axi_awburst;

                write_addr_valid_next = 1'b1;
                s_axi_awready_next = 1'b0;
                if (s_axi_awlen > 0) begin
                    write_last_next = 1'b0;
                    state_next = STATE_BURST;
                end else begin
                    s_axi_bid_next = write_id_next;
                    s_axi_bvalid_next = 1'b1;
                    write_last_next = 1'b1;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_BURST: begin
            s_axi_awready_next = 1'b0;

            if (write_addr_ready) begin
                if (write_burst_reg != 2'b00) begin
                    write_addr_next = write_addr_reg + (1 << write_size_reg);
                end
                write_count_next = write_count_reg - 1;
                write_last_next = write_count_next == 0;
                if (write_count_reg > 0) begin
                    state_next = STATE_BURST;
                end else begin
                    s_axi_bid_next = write_id_reg;
                    s_axi_bvalid_next = 1'b1;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_BURST;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        write_addr_valid_reg <= 1'b0;
        s_axi_awready_reg <= 1'b0;
        s_axi_bvalid_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        write_addr_valid_reg <= write_addr_valid_next;
        s_axi_awready_reg <= s_axi_awready_next;
        s_axi_bvalid_reg <= s_axi_bvalid_next;
    end

    write_id_reg <= write_id_next;
    write_addr_reg <= write_addr_next;
    write_last_reg <= write_last_next;
    write_count_reg <= write_count_next;
    write_size_reg <= write_size_next;
    write_burst_reg <= write_burst_next;

    s_axi_bid_reg <= s_axi_bid_next;
end

endmodule
