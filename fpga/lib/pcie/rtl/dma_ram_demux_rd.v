/*

Copyright (c) 2019-2021 Alex Forencich

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
 * DMA RAM demux (read)
 */
module dma_ram_demux_rd #
(
    // Number of ports
    parameter PORTS = 2,
    // RAM segment count
    parameter SEG_COUNT = 2,
    // RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // Input RAM segment select width
    parameter S_RAM_SEL_WIDTH = 2,
    // Output RAM segment select width
    // Additional bits required for response routing
    parameter M_RAM_SEL_WIDTH = S_RAM_SEL_WIDTH+$clog2(PORTS)
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * RAM interface (from DMA client/interface)
     */
    input  wire [SEG_COUNT*M_RAM_SEL_WIDTH-1:0]       ctrl_rd_cmd_sel,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]        ctrl_rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                       ctrl_rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                       ctrl_rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]        ctrl_rd_resp_data,
    output wire [SEG_COUNT-1:0]                       ctrl_rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                       ctrl_rd_resp_ready,

    /*
     * RAM interface (towards RAM)
     */
    output wire [PORTS*SEG_COUNT*S_RAM_SEL_WIDTH-1:0] ram_rd_cmd_sel,
    output wire [PORTS*SEG_COUNT*SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    output wire [PORTS*SEG_COUNT-1:0]                 ram_rd_cmd_valid,
    input  wire [PORTS*SEG_COUNT-1:0]                 ram_rd_cmd_ready,
    input  wire [PORTS*SEG_COUNT*SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire [PORTS*SEG_COUNT-1:0]                 ram_rd_resp_valid,
    output wire [PORTS*SEG_COUNT-1:0]                 ram_rd_resp_ready
);

parameter CL_PORTS = $clog2(PORTS);

parameter S_RAM_SEL_WIDTH_INT = S_RAM_SEL_WIDTH > 0 ? S_RAM_SEL_WIDTH : 1;

parameter FIFO_ADDR_WIDTH = 5;
parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

// check configuration
initial begin
    if (M_RAM_SEL_WIDTH < S_RAM_SEL_WIDTH+$clog2(PORTS)) begin
        $error("Error: M_RAM_SEL_WIDTH must be at least $clog2(PORTS) larger than S_RAM_SEL_WIDTH (instance %m)");
        $finish;
    end
end

generate

genvar n, p;

for (n = 0; n < SEG_COUNT; n = n + 1) begin

    // FIFO to maintain response ordering
    reg [FIFO_ADDR_WIDTH+1-1:0] fifo_wr_ptr_reg = 0;
    reg [FIFO_ADDR_WIDTH+1-1:0] fifo_rd_ptr_reg = 0;
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [CL_PORTS-1:0] fifo_sel[(2**FIFO_ADDR_WIDTH)-1:0];

    wire fifo_empty = fifo_wr_ptr_reg == fifo_rd_ptr_reg;
    wire fifo_full = fifo_wr_ptr_reg == (fifo_rd_ptr_reg ^ (1 << FIFO_ADDR_WIDTH));

    integer i;

    initial begin
        for (i = 0; i < 2**FIFO_ADDR_WIDTH; i = i + 1) begin
            fifo_sel[i] = 0;
        end
    end

    // RAM read command demux

    wire [M_RAM_SEL_WIDTH-1:0] seg_ctrl_rd_cmd_sel   = ctrl_rd_cmd_sel[M_RAM_SEL_WIDTH*n +: M_RAM_SEL_WIDTH];
    wire [SEG_ADDR_WIDTH-1:0]  seg_ctrl_rd_cmd_addr  = ctrl_rd_cmd_addr[SEG_ADDR_WIDTH*n +: SEG_ADDR_WIDTH];
    wire                       seg_ctrl_rd_cmd_valid = ctrl_rd_cmd_valid[n];
    wire                       seg_ctrl_rd_cmd_ready;

    assign ctrl_rd_cmd_ready[n] = seg_ctrl_rd_cmd_ready;

    wire [PORTS*S_RAM_SEL_WIDTH-1:0] seg_ram_rd_cmd_sel;
    wire [PORTS*SEG_ADDR_WIDTH-1:0]  seg_ram_rd_cmd_addr;
    wire [PORTS-1:0]                 seg_ram_rd_cmd_valid;
    wire [PORTS-1:0]                 seg_ram_rd_cmd_ready;

    for (p = 0; p < PORTS; p = p + 1) begin
        if (S_RAM_SEL_WIDTH > 0) begin
            assign ram_rd_cmd_sel[(p*SEG_COUNT+n)*S_RAM_SEL_WIDTH +: S_RAM_SEL_WIDTH_INT] = seg_ram_rd_cmd_sel[p*S_RAM_SEL_WIDTH +: S_RAM_SEL_WIDTH_INT];
        end
        assign ram_rd_cmd_addr[(p*SEG_COUNT+n)*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH] = seg_ram_rd_cmd_addr[p*SEG_ADDR_WIDTH +: SEG_ADDR_WIDTH];
        assign ram_rd_cmd_valid[p*SEG_COUNT+n] = seg_ram_rd_cmd_valid[p];
        assign seg_ram_rd_cmd_ready[p] = ram_rd_cmd_ready[p*SEG_COUNT+n];
    end

    if (S_RAM_SEL_WIDTH == 0) begin
        assign ram_rd_cmd_sel = 0;
    end

    // internal datapath
    reg  [S_RAM_SEL_WIDTH-1:0] seg_ram_rd_cmd_sel_int;
    reg  [SEG_ADDR_WIDTH-1:0]  seg_ram_rd_cmd_addr_int;
    reg  [PORTS-1:0]           seg_ram_rd_cmd_valid_int;
    reg                        seg_ram_rd_cmd_ready_int_reg = 1'b0;
    wire                       seg_ram_rd_cmd_ready_int_early;

    assign seg_ctrl_rd_cmd_ready = seg_ram_rd_cmd_ready_int_reg && !fifo_full;

    wire [CL_PORTS-1:0] select_cmd = PORTS > 1 ? (seg_ctrl_rd_cmd_sel >> (M_RAM_SEL_WIDTH - CL_PORTS)) : 0;

    always @* begin
        seg_ram_rd_cmd_sel_int   = seg_ctrl_rd_cmd_sel;
        seg_ram_rd_cmd_addr_int  = seg_ctrl_rd_cmd_addr;
        seg_ram_rd_cmd_valid_int = (seg_ctrl_rd_cmd_valid && seg_ctrl_rd_cmd_ready) << select_cmd;
    end

    always @(posedge clk) begin
        if (seg_ctrl_rd_cmd_valid && seg_ctrl_rd_cmd_ready) begin
            fifo_sel[fifo_wr_ptr_reg[FIFO_ADDR_WIDTH-1:0]] <= select_cmd;
            fifo_wr_ptr_reg <= fifo_wr_ptr_reg + 1;
        end

        if (rst) begin
            fifo_wr_ptr_reg <= 0;
        end
    end

    // output datapath logic
    reg [S_RAM_SEL_WIDTH-1:0] seg_ram_rd_cmd_sel_reg   = {S_RAM_SEL_WIDTH_INT{1'b0}};
    reg [SEG_ADDR_WIDTH-1:0]  seg_ram_rd_cmd_addr_reg  = {SEG_ADDR_WIDTH{1'b0}};
    reg [PORTS-1:0]           seg_ram_rd_cmd_valid_reg = {PORTS{1'b0}}, seg_ram_rd_cmd_valid_next;

    reg [S_RAM_SEL_WIDTH-1:0] temp_seg_ram_rd_cmd_sel_reg   = {S_RAM_SEL_WIDTH_INT{1'b0}};
    reg [SEG_ADDR_WIDTH-1:0]  temp_seg_ram_rd_cmd_addr_reg  = {SEG_ADDR_WIDTH{1'b0}};
    reg [PORTS-1:0]           temp_seg_ram_rd_cmd_valid_reg = {PORTS{1'b0}}, temp_seg_ram_rd_cmd_valid_next;

    // datapath control
    reg store_axis_resp_int_to_output;
    reg store_axis_resp_int_to_temp;
    reg store_axis_resp_temp_to_output;

    assign seg_ram_rd_cmd_sel = {PORTS{seg_ram_rd_cmd_sel_reg}};
    assign seg_ram_rd_cmd_addr = {PORTS{seg_ram_rd_cmd_addr_reg}};
    assign seg_ram_rd_cmd_valid = seg_ram_rd_cmd_valid_reg;

    // enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
    assign seg_ram_rd_cmd_ready_int_early = (seg_ram_rd_cmd_ready & seg_ram_rd_cmd_valid_reg) || (!temp_seg_ram_rd_cmd_valid_reg && (!seg_ram_rd_cmd_valid_reg || !seg_ram_rd_cmd_valid_int));

    always @* begin
        // transfer sink ready state to source
        seg_ram_rd_cmd_valid_next = seg_ram_rd_cmd_valid_reg;
        temp_seg_ram_rd_cmd_valid_next = temp_seg_ram_rd_cmd_valid_reg;

        store_axis_resp_int_to_output = 1'b0;
        store_axis_resp_int_to_temp = 1'b0;
        store_axis_resp_temp_to_output = 1'b0;

        if (seg_ram_rd_cmd_ready_int_reg) begin
            // input is ready
            if ((seg_ram_rd_cmd_ready & seg_ram_rd_cmd_valid_reg) || !seg_ram_rd_cmd_valid_reg) begin
                // output is ready or currently not valid, transfer data to output
                seg_ram_rd_cmd_valid_next = seg_ram_rd_cmd_valid_int;
                store_axis_resp_int_to_output = 1'b1;
            end else begin
                // output is not ready, store input in temp
                temp_seg_ram_rd_cmd_valid_next = seg_ram_rd_cmd_valid_int;
                store_axis_resp_int_to_temp = 1'b1;
            end
        end else if (seg_ram_rd_cmd_ready & seg_ram_rd_cmd_valid_reg) begin
            // input is not ready, but output is ready
            seg_ram_rd_cmd_valid_next = temp_seg_ram_rd_cmd_valid_reg;
            temp_seg_ram_rd_cmd_valid_next = {PORTS{1'b0}};
            store_axis_resp_temp_to_output = 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            seg_ram_rd_cmd_valid_reg <= {PORTS{1'b0}};
            seg_ram_rd_cmd_ready_int_reg <= 1'b0;
            temp_seg_ram_rd_cmd_valid_reg <= {PORTS{1'b0}};
        end else begin
            seg_ram_rd_cmd_valid_reg <= seg_ram_rd_cmd_valid_next;
            seg_ram_rd_cmd_ready_int_reg <= seg_ram_rd_cmd_ready_int_early;
            temp_seg_ram_rd_cmd_valid_reg <= temp_seg_ram_rd_cmd_valid_next;
        end

        // datapath
        if (store_axis_resp_int_to_output) begin
            seg_ram_rd_cmd_sel_reg <= seg_ram_rd_cmd_sel_int;
            seg_ram_rd_cmd_addr_reg <= seg_ram_rd_cmd_addr_int;
        end else if (store_axis_resp_temp_to_output) begin
            seg_ram_rd_cmd_sel_reg <= temp_seg_ram_rd_cmd_sel_reg;
            seg_ram_rd_cmd_addr_reg <= temp_seg_ram_rd_cmd_addr_reg;
        end

        if (store_axis_resp_int_to_temp) begin
            temp_seg_ram_rd_cmd_sel_reg <= seg_ram_rd_cmd_sel_int;
            temp_seg_ram_rd_cmd_addr_reg <= seg_ram_rd_cmd_addr_int;
        end
    end

    // RAM read response mux

    wire [PORTS*SEG_DATA_WIDTH-1:0] seg_ram_rd_resp_data;
    wire [PORTS-1:0]                seg_ram_rd_resp_valid;
    wire [PORTS-1:0]                seg_ram_rd_resp_ready;

    for (p = 0; p < PORTS; p = p + 1) begin
        assign seg_ram_rd_resp_data[p*SEG_DATA_WIDTH +: SEG_DATA_WIDTH] = ram_rd_resp_data[(p*SEG_COUNT+n)*SEG_DATA_WIDTH +: SEG_DATA_WIDTH];
        assign seg_ram_rd_resp_valid[p] = ram_rd_resp_valid[p*SEG_COUNT+n];
        assign ram_rd_resp_ready[p*SEG_COUNT+n] = seg_ram_rd_resp_ready[p];
    end

    wire [SEG_DATA_WIDTH-1:0] seg_ctrl_rd_resp_data;
    wire                      seg_ctrl_rd_resp_valid;
    wire                      seg_ctrl_rd_resp_ready = ctrl_rd_resp_ready[n];

    assign ctrl_rd_resp_data[n*SEG_DATA_WIDTH +: SEG_DATA_WIDTH] = seg_ctrl_rd_resp_data;
    assign ctrl_rd_resp_valid[n] = seg_ctrl_rd_resp_valid;

    // internal datapath
    reg  [SEG_DATA_WIDTH-1:0] seg_ctrl_rd_resp_data_int;
    reg                       seg_ctrl_rd_resp_valid_int;
    wire                      seg_ctrl_rd_resp_ready_int;

    wire [CL_PORTS-1:0] select_resp = fifo_sel[fifo_rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]];

    assign seg_ram_rd_resp_ready = (seg_ctrl_rd_resp_ready_int && !fifo_empty) << select_resp;

    // mux for incoming packet
    wire [SEG_DATA_WIDTH-1:0] current_resp_data  = seg_ram_rd_resp_data[select_resp*SEG_DATA_WIDTH +: SEG_DATA_WIDTH];
    wire                      current_resp_valid = seg_ram_rd_resp_valid[select_resp];
    wire                      current_resp_ready = seg_ram_rd_resp_ready[select_resp];

    always @* begin
        // pass through selected packet data
        seg_ctrl_rd_resp_data_int  = current_resp_data;
        seg_ctrl_rd_resp_valid_int = current_resp_valid && seg_ctrl_rd_resp_ready_int && !fifo_empty;
    end

    always @(posedge clk) begin
        if (current_resp_valid && seg_ctrl_rd_resp_ready_int && !fifo_empty) begin
            fifo_rd_ptr_reg <= fifo_rd_ptr_reg + 1;
        end

        if (rst) begin
            fifo_rd_ptr_reg <= 0;
        end
    end

    // output datapath logic
    reg [SEG_DATA_WIDTH-1:0] seg_ctrl_rd_resp_data_reg  = {SEG_DATA_WIDTH{1'b0}};
    reg                      seg_ctrl_rd_resp_valid_reg = 1'b0;

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
    reg out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [SEG_DATA_WIDTH-1:0] out_fifo_rd_resp_data[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

    assign seg_ctrl_rd_resp_ready_int = !out_fifo_half_full_reg;

    assign seg_ctrl_rd_resp_data = seg_ctrl_rd_resp_data_reg;
    assign seg_ctrl_rd_resp_valid = seg_ctrl_rd_resp_valid_reg;

    always @(posedge clk) begin
        seg_ctrl_rd_resp_valid_reg <= seg_ctrl_rd_resp_valid_reg && !seg_ctrl_rd_resp_ready;

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

        if (!out_fifo_full && seg_ctrl_rd_resp_valid_int) begin
            out_fifo_rd_resp_data[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= seg_ctrl_rd_resp_data_int;
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!seg_ctrl_rd_resp_valid_reg || seg_ctrl_rd_resp_ready)) begin
            seg_ctrl_rd_resp_data_reg <= out_fifo_rd_resp_data[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            seg_ctrl_rd_resp_valid_reg <= 1'b1;
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (rst) begin
            out_fifo_wr_ptr_reg <= 0;
            out_fifo_rd_ptr_reg <= 0;
            seg_ctrl_rd_resp_valid_reg <= 1'b0;
        end
    end

end

endgenerate

endmodule

`resetall
