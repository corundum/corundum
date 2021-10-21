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
 * DMA RAM demux
 */
module dma_ram_demux #
(
    // Number of ports
    parameter PORTS = 2,
    // RAM segment count
    parameter SEG_COUNT = 2,
    // RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
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
    input  wire [SEG_COUNT*M_RAM_SEL_WIDTH-1:0]       ctrl_wr_cmd_sel,
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]          ctrl_wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]        ctrl_wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]        ctrl_wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                       ctrl_wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                       ctrl_wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                       ctrl_wr_done,
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
    output wire [PORTS*SEG_COUNT*S_RAM_SEL_WIDTH-1:0] ram_wr_cmd_sel,
    output wire [PORTS*SEG_COUNT*SEG_BE_WIDTH-1:0]    ram_wr_cmd_be,
    output wire [PORTS*SEG_COUNT*SEG_ADDR_WIDTH-1:0]  ram_wr_cmd_addr,
    output wire [PORTS*SEG_COUNT*SEG_DATA_WIDTH-1:0]  ram_wr_cmd_data,
    output wire [PORTS*SEG_COUNT-1:0]                 ram_wr_cmd_valid,
    input  wire [PORTS*SEG_COUNT-1:0]                 ram_wr_cmd_ready,
    input  wire [PORTS*SEG_COUNT-1:0]                 ram_wr_done,
    output wire [PORTS*SEG_COUNT*S_RAM_SEL_WIDTH-1:0] ram_rd_cmd_sel,
    output wire [PORTS*SEG_COUNT*SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    output wire [PORTS*SEG_COUNT-1:0]                 ram_rd_cmd_valid,
    input  wire [PORTS*SEG_COUNT-1:0]                 ram_rd_cmd_ready,
    input  wire [PORTS*SEG_COUNT*SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire [PORTS*SEG_COUNT-1:0]                 ram_rd_resp_valid,
    output wire [PORTS*SEG_COUNT-1:0]                 ram_rd_resp_ready
);

dma_ram_demux_wr #(
    .PORTS(PORTS),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .S_RAM_SEL_WIDTH(S_RAM_SEL_WIDTH),
    .M_RAM_SEL_WIDTH(M_RAM_SEL_WIDTH)
)
dma_ram_demux_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * RAM interface (from DMA client/interface)
     */
    .ctrl_wr_cmd_sel(ctrl_wr_cmd_sel),
    .ctrl_wr_cmd_be(ctrl_wr_cmd_be),
    .ctrl_wr_cmd_addr(ctrl_wr_cmd_addr),
    .ctrl_wr_cmd_data(ctrl_wr_cmd_data),
    .ctrl_wr_cmd_valid(ctrl_wr_cmd_valid),
    .ctrl_wr_cmd_ready(ctrl_wr_cmd_ready),
    .ctrl_wr_done(ctrl_wr_done),

    /*
     * RAM interface (towards RAM)
     */
    .ram_wr_cmd_sel(ram_wr_cmd_sel),
    .ram_wr_cmd_be(ram_wr_cmd_be),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_valid(ram_wr_cmd_valid),
    .ram_wr_cmd_ready(ram_wr_cmd_ready),
    .ram_wr_done(ram_wr_done)
);

dma_ram_demux_rd #(
    .PORTS(PORTS),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .S_RAM_SEL_WIDTH(S_RAM_SEL_WIDTH),
    .M_RAM_SEL_WIDTH(M_RAM_SEL_WIDTH)
)
dma_ram_demux_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * RAM interface (from DMA client/interface)
     */
    .ctrl_rd_cmd_sel(ctrl_rd_cmd_sel),
    .ctrl_rd_cmd_addr(ctrl_rd_cmd_addr),
    .ctrl_rd_cmd_valid(ctrl_rd_cmd_valid),
    .ctrl_rd_cmd_ready(ctrl_rd_cmd_ready),
    .ctrl_rd_resp_data(ctrl_rd_resp_data),
    .ctrl_rd_resp_valid(ctrl_rd_resp_valid),
    .ctrl_rd_resp_ready(ctrl_rd_resp_ready),

    /*
     * RAM interface (towards RAM)
     */
    .ram_rd_cmd_sel(ram_rd_cmd_sel),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_valid(ram_rd_cmd_valid),
    .ram_rd_cmd_ready(ram_rd_cmd_ready),
    .ram_rd_resp_data(ram_rd_resp_data),
    .ram_rd_resp_valid(ram_rd_resp_valid),
    .ram_rd_resp_ready(ram_rd_resp_ready)
);

endmodule

`resetall
