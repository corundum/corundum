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
 * AXI4 RAM read interface
 */
module axi_ram_rd_if #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 16,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
    // Extra pipeline register on output
    parameter PIPELINE_OUTPUT = 0
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire [3:0]               s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    /*
     * RAM interface
     */
    output wire [ID_WIDTH-1:0]      ram_rd_cmd_id,
    output wire [ADDR_WIDTH-1:0]    ram_rd_cmd_addr,
    output wire                     ram_rd_cmd_lock,
    output wire [3:0]               ram_rd_cmd_cache,
    output wire [2:0]               ram_rd_cmd_prot,
    output wire [3:0]               ram_rd_cmd_qos,
    output wire [3:0]               ram_rd_cmd_region,
    output wire [ARUSER_WIDTH-1:0]  ram_rd_cmd_auser,
    output wire                     ram_rd_cmd_en,
    output wire                     ram_rd_cmd_last,
    input  wire                     ram_rd_cmd_ready,
    input  wire [ID_WIDTH-1:0]      ram_rd_resp_id,
    input  wire [DATA_WIDTH-1:0]    ram_rd_resp_data,
    input  wire                     ram_rd_resp_last,
    input  wire [RUSER_WIDTH-1:0]   ram_rd_resp_user,
    input  wire                     ram_rd_resp_valid,
    output wire                     ram_rd_resp_ready
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

localparam [0:0]
    STATE_IDLE = 1'd0,
    STATE_BURST = 1'd1;

reg [0:0] state_reg = STATE_IDLE, state_next;

reg [ID_WIDTH-1:0] read_id_reg = {ID_WIDTH{1'b0}}, read_id_next;
reg [ADDR_WIDTH-1:0] read_addr_reg = {ADDR_WIDTH{1'b0}}, read_addr_next;
reg read_lock_reg = 1'b0, read_lock_next;
reg [3:0] read_cache_reg = 4'd0, read_cache_next;
reg [2:0] read_prot_reg = 3'd0, read_prot_next;
reg [3:0] read_qos_reg = 4'd0, read_qos_next;
reg [3:0] read_region_reg = 4'd0, read_region_next;
reg [ARUSER_WIDTH-1:0] read_aruser_reg = {ARUSER_WIDTH{1'b0}}, read_aruser_next;
reg read_addr_valid_reg = 1'b0, read_addr_valid_next;
reg read_last_reg = 1'b0, read_last_next;
reg [7:0] read_count_reg = 8'd0, read_count_next;
reg [2:0] read_size_reg = 3'd0, read_size_next;
reg [1:0] read_burst_reg = 2'd0, read_burst_next;

reg s_axi_arready_reg = 1'b0, s_axi_arready_next;
reg [ID_WIDTH-1:0] s_axi_rid_pipe_reg = {ID_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0] s_axi_rdata_pipe_reg = {DATA_WIDTH{1'b0}};
reg s_axi_rlast_pipe_reg = 1'b0;
reg [RUSER_WIDTH-1:0] s_axi_ruser_pipe_reg = {RUSER_WIDTH{1'b0}};
reg s_axi_rvalid_pipe_reg = 1'b0;

assign s_axi_arready = s_axi_arready_reg;
assign s_axi_rid = PIPELINE_OUTPUT ? s_axi_rid_pipe_reg : ram_rd_resp_id;
assign s_axi_rdata = PIPELINE_OUTPUT ? s_axi_rdata_pipe_reg : ram_rd_resp_data;
assign s_axi_rresp = 2'b00;
assign s_axi_rlast = PIPELINE_OUTPUT ? s_axi_rlast_pipe_reg : ram_rd_resp_last;
assign s_axi_ruser = PIPELINE_OUTPUT ? s_axi_ruser_pipe_reg : ram_rd_resp_user;
assign s_axi_rvalid = PIPELINE_OUTPUT ? s_axi_rvalid_pipe_reg : ram_rd_resp_valid;

assign ram_rd_cmd_id = read_id_reg;
assign ram_rd_cmd_addr = read_addr_reg;
assign ram_rd_cmd_lock = read_lock_reg;
assign ram_rd_cmd_cache = read_cache_reg;
assign ram_rd_cmd_prot = read_prot_reg;
assign ram_rd_cmd_qos = read_qos_reg;
assign ram_rd_cmd_region = read_region_reg;
assign ram_rd_cmd_auser = ARUSER_ENABLE ? read_aruser_reg : {ARUSER_WIDTH{1'b0}};
assign ram_rd_cmd_en = read_addr_valid_reg;
assign ram_rd_cmd_last = read_last_reg;

assign ram_rd_resp_ready = s_axi_rready || (PIPELINE_OUTPUT && !s_axi_rvalid_pipe_reg);

always @* begin
    state_next = STATE_IDLE;

    read_id_next = read_id_reg;
    read_addr_next = read_addr_reg;
    read_lock_next = read_lock_reg;
    read_cache_next = read_cache_reg;
    read_prot_next = read_prot_reg;
    read_qos_next = read_qos_reg;
    read_region_next = read_region_reg;
    read_aruser_next = read_aruser_reg;
    read_addr_valid_next = read_addr_valid_reg && !ram_rd_cmd_ready;
    read_last_next = read_last_reg;
    read_count_next = read_count_reg;
    read_size_next = read_size_reg;
    read_burst_next = read_burst_reg;

    s_axi_arready_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            s_axi_arready_next = 1'b1;

            if (s_axi_arready && s_axi_arvalid) begin
                read_id_next = s_axi_arid;
                read_addr_next = s_axi_araddr;
                read_lock_next = s_axi_arlock;
                read_cache_next = s_axi_arcache;
                read_prot_next = s_axi_arprot;
                read_qos_next = s_axi_arqos;
                read_region_next = s_axi_arregion;
                read_aruser_next = s_axi_aruser;
                read_count_next = s_axi_arlen;
                read_size_next = s_axi_arsize < $clog2(STRB_WIDTH) ? s_axi_arsize : $clog2(STRB_WIDTH);
                read_burst_next = s_axi_arburst;

                s_axi_arready_next = 1'b0;
                read_last_next = read_count_next == 0;
                read_addr_valid_next = 1'b1;
                state_next = STATE_BURST;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_BURST: begin
            if (ram_rd_cmd_ready && ram_rd_cmd_en) begin
                if (read_burst_reg != 2'b00) begin
                    read_addr_next = read_addr_reg + (1 << read_size_reg);
                end
                read_count_next = read_count_reg - 1;
                read_last_next = read_count_next == 0;
                if (read_count_reg > 0) begin
                    read_addr_valid_next = 1'b1;
                    state_next = STATE_BURST;
                end else begin
                    s_axi_arready_next = 1'b1;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_BURST;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    read_id_reg <= read_id_next;
    read_addr_reg <= read_addr_next;
    read_lock_reg <= read_lock_next;
    read_cache_reg <= read_cache_next;
    read_prot_reg <= read_prot_next;
    read_qos_reg <= read_qos_next;
    read_region_reg <= read_region_next;
    read_aruser_reg <= read_aruser_next;
    read_addr_valid_reg <= read_addr_valid_next;
    read_last_reg <= read_last_next;
    read_count_reg <= read_count_next;
    read_size_reg <= read_size_next;
    read_burst_reg <= read_burst_next;

    s_axi_arready_reg <= s_axi_arready_next;

    if (!s_axi_rvalid_pipe_reg || s_axi_rready) begin
        s_axi_rid_pipe_reg <= ram_rd_resp_id;
        s_axi_rdata_pipe_reg <= ram_rd_resp_data;
        s_axi_rlast_pipe_reg <= ram_rd_resp_last;
        s_axi_ruser_pipe_reg <= ram_rd_resp_user;
        s_axi_rvalid_pipe_reg <= ram_rd_resp_valid;
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        read_addr_valid_reg <= 1'b0;

        s_axi_arready_reg <= 1'b0;
        s_axi_rvalid_pipe_reg <= 1'b0;
    end
end

endmodule

`resetall
