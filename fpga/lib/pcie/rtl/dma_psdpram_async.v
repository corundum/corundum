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
 * DMA parallel simple dual port RAM (asynchronous)
 */
module dma_psdpram_async #
(
    // RAM size
    parameter SIZE = 4096,
    // RAM segment count
    parameter SEG_COUNT = 2,
    // RAM segment data width
    parameter SEG_DATA_WIDTH = 128,
    // RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // Read data output pipeline stages
    parameter PIPELINE = 2
)
(
    /*
     * Write port
     */
    input  wire                                clk_wr,
    input  wire                                rst_wr,
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]   wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                wr_done,

    /*
     * Read port
     */
    input  wire                                clk_rd,
    input  wire                                rst_rd,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] rd_resp_data,
    output wire [SEG_COUNT-1:0]                rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                rd_resp_ready
);

parameter INT_ADDR_WIDTH = $clog2(SIZE/(SEG_COUNT*SEG_BE_WIDTH));

// check configuration
initial begin
    if (SEG_ADDR_WIDTH < INT_ADDR_WIDTH) begin
        $error("Error: SEG_ADDR_WIDTH not sufficient for requested size (min %d for size %d) (instance %m)", INT_ADDR_WIDTH, SIZE);
        $finish;
    end
end

generate

    genvar n;

    for (n = 0; n < SEG_COUNT; n = n + 1) begin

        (* ramstyle = "no_rw_check" *)
        reg [SEG_DATA_WIDTH-1:0] mem_reg[2**INT_ADDR_WIDTH-1:0];

        reg wr_done_reg = 1'b0;

        reg [PIPELINE-1:0] rd_resp_valid_pipe_reg = 0;
        reg [SEG_DATA_WIDTH-1:0] rd_resp_data_pipe_reg[PIPELINE-1:0];

        integer i, j;

        initial begin
            // two nested loops for smaller number of iterations per loop
            // workaround for synthesizer complaints about large loop counts
            for (i = 0; i < 2**INT_ADDR_WIDTH; i = i + 2**(INT_ADDR_WIDTH/2)) begin
                for (j = i; j < i + 2**(INT_ADDR_WIDTH/2); j = j + 1) begin
                    mem_reg[j] = 0;
                end
            end

            for (i = 0; i < PIPELINE; i = i + 1) begin
                rd_resp_data_pipe_reg[i] = 0;
            end
        end

        always @(posedge clk_wr) begin
            wr_done_reg <= 1'b0;

            for (i = 0; i < SEG_BE_WIDTH; i = i + 1) begin
                if (wr_cmd_valid[n] && wr_cmd_be[n*SEG_BE_WIDTH+i]) begin
                    mem_reg[wr_cmd_addr[SEG_ADDR_WIDTH*n +: INT_ADDR_WIDTH]][i*8 +: 8] <= wr_cmd_data[SEG_DATA_WIDTH*n+i*8 +: 8];
                    wr_done_reg <= 1'b1;
                end
            end

            if (rst_wr) begin
                wr_done_reg <= 1'b0;
            end
        end

        assign wr_cmd_ready[n] = 1'b1;
        assign wr_done[n] = wr_done_reg;

        always @(posedge clk_rd) begin
            if (rd_resp_ready[n]) begin
                rd_resp_valid_pipe_reg[PIPELINE-1] <= 1'b0;
            end

            for (j = PIPELINE-1; j > 0; j = j - 1) begin
                if (rd_resp_ready[n] || ((~rd_resp_valid_pipe_reg) >> j)) begin
                    rd_resp_valid_pipe_reg[j] <= rd_resp_valid_pipe_reg[j-1];
                    rd_resp_data_pipe_reg[j] <= rd_resp_data_pipe_reg[j-1];
                    rd_resp_valid_pipe_reg[j-1] <= 1'b0;
                end
            end

            if (rd_cmd_valid[n] && rd_cmd_ready[n]) begin
                rd_resp_valid_pipe_reg[0] <= 1'b1;
                rd_resp_data_pipe_reg[0] <= mem_reg[rd_cmd_addr[SEG_ADDR_WIDTH*n +: INT_ADDR_WIDTH]];
            end

            if (rst_rd) begin
                rd_resp_valid_pipe_reg <= 0;
            end
        end

        assign rd_cmd_ready[n] = rd_resp_ready[n] || ~rd_resp_valid_pipe_reg;

        assign rd_resp_valid[n] = rd_resp_valid_pipe_reg[PIPELINE-1];
        assign rd_resp_data[SEG_DATA_WIDTH*n +: SEG_DATA_WIDTH] = rd_resp_data_pipe_reg[PIPELINE-1];
    end

endgenerate

endmodule

`resetall
