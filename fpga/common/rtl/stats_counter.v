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
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Pipeline length
    parameter PIPELINE = 2
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

// check configuration
initial begin
    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: AXI lite interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (AXIL_ADDR_WIDTH < STAT_ID_WIDTH+ID_SHIFT) begin
        $error("Error: AXI lite address width too narrow (instance %m)");
        $finish;
    end

    if (PIPELINE < 2) begin
        $error("Error: PIPELINE must be at least 2 (instance %m)");
        $finish;
    end
end

reg init_reg = 1'b1, init_next;
reg [STAT_ID_WIDTH-1:0] init_ptr_reg = 0, init_ptr_next;

reg op_acc_pipe_hazard;
reg stage_active;

reg [PIPELINE-1:0] op_axil_read_pipe_reg = 0, op_axil_read_pipe_next;
reg [PIPELINE-1:0] op_acc_pipe_reg = 0, op_acc_pipe_next;

reg [STAT_ID_WIDTH-1:0] mem_addr_pipeline_reg[PIPELINE-1:0], mem_addr_pipeline_next[PIPELINE-1:0];
reg [WORD_SELECT_WIDTH-1:0] axil_shift_pipeline_reg[PIPELINE-1:0], axil_shift_pipeline_next[PIPELINE-1:0];
reg [STAT_INC_WIDTH-1:0] stat_inc_pipeline_reg[PIPELINE-1:0], stat_inc_pipeline_next[PIPELINE-1:0];

reg s_axis_stat_tready_reg = 1'b0, s_axis_stat_tready_next;

reg s_axil_awready_reg = 0, s_axil_awready_next;
reg s_axil_wready_reg = 0, s_axil_wready_next;
reg s_axil_bvalid_reg = 0, s_axil_bvalid_next;
reg s_axil_arready_reg = 0, s_axil_arready_next;
reg [AXIL_DATA_WIDTH-1:0] s_axil_rdata_reg = 0, s_axil_rdata_next;
reg s_axil_rvalid_reg = 0, s_axil_rvalid_next;

(* ramstyle = "no_rw_check" *)
reg [STAT_COUNT_WIDTH-1:0] mem[2**STAT_ID_WIDTH-1:0];

reg [STAT_ID_WIDTH-1:0] mem_rd_addr;
reg [STAT_ID_WIDTH-1:0] mem_wr_addr;
reg [STAT_COUNT_WIDTH-1:0] mem_wr_data;
reg mem_wr_en;
reg [STAT_COUNT_WIDTH-1:0] mem_read_data_reg = 0;
reg [STAT_COUNT_WIDTH-1:0] mem_read_data_pipeline_reg[PIPELINE-1:1];

assign s_axis_stat_tready = s_axis_stat_tready_reg;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

wire [STAT_ID_WIDTH-1:0] s_axil_araddr_id = s_axil_araddr >> ID_SHIFT;
wire [WORD_SELECT_WIDTH-1:0] s_axil_araddr_shift = s_axil_araddr >> WORD_SELECT_SHIFT;

integer i, j;

initial begin
    // break up loop to work around iteration termination
    for (i = 0; i < 2**STAT_ID_WIDTH; i = i + 2**(STAT_ID_WIDTH/2)) begin
        for (j = i; j < i + 2**(STAT_ID_WIDTH/2); j = j + 1) begin
            mem[j] = 0;
        end
    end

    for (i = 0; i < PIPELINE; i = i + 1) begin
        mem_addr_pipeline_reg[i] = 0;
        axil_shift_pipeline_reg[i] = 0;
        stat_inc_pipeline_reg[i] = 0;
    end
end

always @* begin
    init_next = init_reg;
    init_ptr_next = init_ptr_reg;

    op_axil_read_pipe_next = {op_axil_read_pipe_reg, 1'b0};
    op_acc_pipe_next = {op_acc_pipe_reg, 1'b0};

    mem_addr_pipeline_next[0] = 0;
    axil_shift_pipeline_next[0] = 0;
    stat_inc_pipeline_next[0] = 0;
    for (j = 1; j < PIPELINE; j = j + 1) begin
        mem_addr_pipeline_next[j] = mem_addr_pipeline_reg[j-1];
        axil_shift_pipeline_next[j] = axil_shift_pipeline_reg[j-1];
        stat_inc_pipeline_next[j] = stat_inc_pipeline_reg[j-1];
    end

    s_axis_stat_tready_next = 1'b0;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;

    mem_rd_addr = 0;
    mem_wr_addr = mem_addr_pipeline_reg[PIPELINE-1];
    mem_wr_data = mem_read_data_pipeline_reg[PIPELINE-1] + stat_inc_pipeline_reg[PIPELINE-1];
    mem_wr_en = 0;

    op_acc_pipe_hazard = 1'b0;
    stage_active = 1'b0;

    for (j = 0; j < PIPELINE; j = j + 1) begin
        stage_active = op_axil_read_pipe_reg[j] || op_acc_pipe_reg[j];
        op_acc_pipe_hazard = op_acc_pipe_hazard || (stage_active && mem_addr_pipeline_reg[j] == s_axis_stat_tid);
    end

    // discard writes
    if (s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready)) begin
        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;
    end

    // pipeline stage 0 - accept request
    if (init_reg) begin
        init_ptr_next = init_ptr_reg + 1;

        mem_wr_addr = init_ptr_reg;
        mem_wr_data = 0;
        mem_wr_en = 1'b1;

        if (&init_ptr_reg) begin
            init_next = 1'b0;
        end
    end else if (s_axil_arvalid && (!s_axil_rvalid || s_axil_rready) && !op_axil_read_pipe_reg) begin
        // AXIL read
        op_axil_read_pipe_next[0] = 1'b1;

        s_axil_arready_next = 1'b1;

        mem_rd_addr = s_axil_araddr_id;
        mem_addr_pipeline_next[0] = s_axil_araddr_id;
        axil_shift_pipeline_next[0] = s_axil_araddr_shift;
    end else if (s_axis_stat_tvalid && !s_axis_stat_tready && !op_acc_pipe_hazard) begin
        // accumulate
        op_acc_pipe_next[0] = 1'b1;

        s_axis_stat_tready_next = 1'b1;

        stat_inc_pipeline_next[0] = s_axis_stat_tdata;

        mem_rd_addr = s_axis_stat_tid;
        mem_addr_pipeline_next[0] = s_axis_stat_tid;
    end

    // read complete, perform operation
    if (op_acc_pipe_reg[PIPELINE-1]) begin
        // accumulate
        mem_wr_addr = mem_addr_pipeline_reg[PIPELINE-1];
        mem_wr_data = mem_read_data_pipeline_reg[PIPELINE-1] + stat_inc_pipeline_reg[PIPELINE-1];
        mem_wr_en = 1'b1;
    end else if (op_axil_read_pipe_reg[PIPELINE-1]) begin
        // AXIL read
        s_axil_rvalid_next = 1'b1;
        s_axil_rdata_next = 0;

        if (STAT_COUNT_WIDTH > AXIL_DATA_WIDTH) begin
            s_axil_rdata_next = mem_read_data_pipeline_reg[PIPELINE-1] >> axil_shift_pipeline_reg[PIPELINE-1]*AXIL_DATA_WIDTH;
        end else begin
            s_axil_rdata_next = mem_read_data_pipeline_reg[PIPELINE-1];
        end
    end
end

always @(posedge clk) begin
    init_reg <= init_next;
    init_ptr_reg <= init_ptr_next;

    op_axil_read_pipe_reg <= op_axil_read_pipe_next;
    op_acc_pipe_reg <= op_acc_pipe_next;

    s_axis_stat_tready_reg <= s_axis_stat_tready_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;
    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    for (i = 0; i < PIPELINE; i = i + 1) begin
        mem_addr_pipeline_reg[i] <= mem_addr_pipeline_next[i];
        axil_shift_pipeline_reg[i] <= axil_shift_pipeline_next[i];
        stat_inc_pipeline_reg[i] <= stat_inc_pipeline_next[i];
    end

    if (mem_wr_en) begin
        mem[mem_wr_addr] <= mem_wr_data;
    end
    mem_read_data_reg <= mem[mem_rd_addr];
    mem_read_data_pipeline_reg[1] <= mem_read_data_reg;
    for (i = 2; i < PIPELINE; i = i + 1) begin
        mem_read_data_pipeline_reg[i] <= mem_read_data_pipeline_reg[i-1];
    end

    if (rst) begin
        init_reg <= 1'b1;
        init_ptr_reg <= 0;

        op_axil_read_pipe_reg <= 0;
        op_acc_pipe_reg <= 0;

        s_axis_stat_tready_reg <= 1'b0;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
