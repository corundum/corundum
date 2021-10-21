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
 * DMA interface mux
 */
module dma_if_mux #
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
    parameter M_RAM_SEL_WIDTH = S_RAM_SEL_WIDTH+$clog2(PORTS),
    // RAM address width
    parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH),
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // Length field width
    parameter LEN_WIDTH = 16,
    // Input tag field width
    parameter S_TAG_WIDTH = 8,
    // Output tag field width (towards DMA module)
    // Additional bits required for response routing
    parameter M_TAG_WIDTH = S_TAG_WIDTH+$clog2(PORTS),
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * Read descriptor output (to DMA interface)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                  m_axis_read_desc_dma_addr,
    output wire [M_RAM_SEL_WIDTH-1:0]                 m_axis_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                  m_axis_read_desc_ram_addr,
    output wire [LEN_WIDTH-1:0]                       m_axis_read_desc_len,
    output wire [M_TAG_WIDTH-1:0]                     m_axis_read_desc_tag,
    output wire                                       m_axis_read_desc_valid,
    input  wire                                       m_axis_read_desc_ready,

    /*
     * Read descriptor status input (from DMA interface)
     */
    input  wire [M_TAG_WIDTH-1:0]                     s_axis_read_desc_status_tag,
    input  wire [3:0]                                 s_axis_read_desc_status_error,
    input  wire                                       s_axis_read_desc_status_valid,

    /*
     * Write descriptor output (to DMA interface)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                  m_axis_write_desc_dma_addr,
    output wire [M_RAM_SEL_WIDTH-1:0]                 m_axis_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                  m_axis_write_desc_ram_addr,
    output wire [LEN_WIDTH-1:0]                       m_axis_write_desc_len,
    output wire [M_TAG_WIDTH-1:0]                     m_axis_write_desc_tag,
    output wire                                       m_axis_write_desc_valid,
    input  wire                                       m_axis_write_desc_ready,

    /*
     * Write descriptor status input (from DMA interface)
     */
    input  wire [M_TAG_WIDTH-1:0]                     s_axis_write_desc_status_tag,
    input  wire [3:0]                                 s_axis_write_desc_status_error,
    input  wire                                       s_axis_write_desc_status_valid,

    /*
     * Read descriptor input
     */
    input  wire [PORTS*DMA_ADDR_WIDTH-1:0]            s_axis_read_desc_dma_addr,
    input  wire [PORTS*S_RAM_SEL_WIDTH-1:0]           s_axis_read_desc_ram_sel,
    input  wire [PORTS*RAM_ADDR_WIDTH-1:0]            s_axis_read_desc_ram_addr,
    input  wire [PORTS*LEN_WIDTH-1:0]                 s_axis_read_desc_len,
    input  wire [PORTS*S_TAG_WIDTH-1:0]               s_axis_read_desc_tag,
    input  wire [PORTS-1:0]                           s_axis_read_desc_valid,
    output wire [PORTS-1:0]                           s_axis_read_desc_ready,

    /*
     * Read descriptor status output
     */
    output wire [PORTS*S_TAG_WIDTH-1:0]               m_axis_read_desc_status_tag,
    output wire [PORTS*4-1:0]                         m_axis_read_desc_status_error,
    output wire [PORTS-1:0]                           m_axis_read_desc_status_valid,

    /*
     * Write descriptor input
     */
    input  wire [PORTS*DMA_ADDR_WIDTH-1:0]            s_axis_write_desc_dma_addr,
    input  wire [PORTS*S_RAM_SEL_WIDTH-1:0]           s_axis_write_desc_ram_sel,
    input  wire [PORTS*RAM_ADDR_WIDTH-1:0]            s_axis_write_desc_ram_addr,
    input  wire [PORTS*LEN_WIDTH-1:0]                 s_axis_write_desc_len,
    input  wire [PORTS*S_TAG_WIDTH-1:0]               s_axis_write_desc_tag,
    input  wire [PORTS-1:0]                           s_axis_write_desc_valid,
    output wire [PORTS-1:0]                           s_axis_write_desc_ready,

    /*
     * Write descriptor status output
     */
    output wire [PORTS*S_TAG_WIDTH-1:0]               m_axis_write_desc_status_tag,
    output wire [PORTS*4-1:0]                         m_axis_write_desc_status_error,
    output wire [PORTS-1:0]                           m_axis_write_desc_status_valid,

    /*
     * RAM interface (from DMA interface)
     */
    input  wire [SEG_COUNT*M_RAM_SEL_WIDTH-1:0]       if_ram_wr_cmd_sel,
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]          if_ram_wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]        if_ram_wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]        if_ram_wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                       if_ram_wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                       if_ram_wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                       if_ram_wr_done,
    input  wire [SEG_COUNT*M_RAM_SEL_WIDTH-1:0]       if_ram_rd_cmd_sel,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0]        if_ram_rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                       if_ram_rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                       if_ram_rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0]        if_ram_rd_resp_data,
    output wire [SEG_COUNT-1:0]                       if_ram_rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                       if_ram_rd_resp_ready,

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

dma_if_mux_rd #(
    .PORTS(PORTS),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .S_RAM_SEL_WIDTH(S_RAM_SEL_WIDTH),
    .M_RAM_SEL_WIDTH(M_RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .S_TAG_WIDTH(S_TAG_WIDTH),
    .M_TAG_WIDTH(M_TAG_WIDTH),
    .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
dma_if_mux_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor output (to DMA interface)
     */
    .m_axis_read_desc_dma_addr(m_axis_read_desc_dma_addr),
    .m_axis_read_desc_ram_sel(m_axis_read_desc_ram_sel),
    .m_axis_read_desc_ram_addr(m_axis_read_desc_ram_addr),
    .m_axis_read_desc_len(m_axis_read_desc_len),
    .m_axis_read_desc_tag(m_axis_read_desc_tag),
    .m_axis_read_desc_valid(m_axis_read_desc_valid),
    .m_axis_read_desc_ready(m_axis_read_desc_ready),

    /*
     * Descriptor status input (from DMA interface)
     */
    .s_axis_read_desc_status_tag(s_axis_read_desc_status_tag),
    .s_axis_read_desc_status_error(s_axis_read_desc_status_error),
    .s_axis_read_desc_status_valid(s_axis_read_desc_status_valid),

    /*
     * Descriptor input
     */
    .s_axis_read_desc_dma_addr(s_axis_read_desc_dma_addr),
    .s_axis_read_desc_ram_sel(s_axis_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(s_axis_read_desc_ram_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),

    /*
     * Descriptor status output
     */
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_error(m_axis_read_desc_status_error),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),

    /*
     * RAM interface (from DMA interface)
     */
    .if_ram_wr_cmd_sel(if_ram_wr_cmd_sel),
    .if_ram_wr_cmd_be(if_ram_wr_cmd_be),
    .if_ram_wr_cmd_addr(if_ram_wr_cmd_addr),
    .if_ram_wr_cmd_data(if_ram_wr_cmd_data),
    .if_ram_wr_cmd_valid(if_ram_wr_cmd_valid),
    .if_ram_wr_cmd_ready(if_ram_wr_cmd_ready),
    .if_ram_wr_done(if_ram_wr_done),

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

dma_if_mux_wr #(
    .PORTS(PORTS),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .S_RAM_SEL_WIDTH(S_RAM_SEL_WIDTH),
    .M_RAM_SEL_WIDTH(M_RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .S_TAG_WIDTH(S_TAG_WIDTH),
    .M_TAG_WIDTH(M_TAG_WIDTH),
    .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
dma_if_mux_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor output (to DMA interface)
     */
    .m_axis_write_desc_dma_addr(m_axis_write_desc_dma_addr),
    .m_axis_write_desc_ram_sel(m_axis_write_desc_ram_sel),
    .m_axis_write_desc_ram_addr(m_axis_write_desc_ram_addr),
    .m_axis_write_desc_len(m_axis_write_desc_len),
    .m_axis_write_desc_tag(m_axis_write_desc_tag),
    .m_axis_write_desc_valid(m_axis_write_desc_valid),
    .m_axis_write_desc_ready(m_axis_write_desc_ready),

    /*
     * Descriptor status input (from DMA interface)
     */
    .s_axis_write_desc_status_tag(s_axis_write_desc_status_tag),
    .s_axis_write_desc_status_error(s_axis_write_desc_status_error),
    .s_axis_write_desc_status_valid(s_axis_write_desc_status_valid),

    /*
     * Descriptor input
     */
    .s_axis_write_desc_dma_addr(s_axis_write_desc_dma_addr),
    .s_axis_write_desc_ram_sel(s_axis_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(s_axis_write_desc_ram_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),

    /*
     * Descriptor status output
     */
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_error(m_axis_write_desc_status_error),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),

    /*
     * RAM interface (from DMA interface)
     */
    .if_ram_rd_cmd_sel(if_ram_rd_cmd_sel),
    .if_ram_rd_cmd_addr(if_ram_rd_cmd_addr),
    .if_ram_rd_cmd_valid(if_ram_rd_cmd_valid),
    .if_ram_rd_cmd_ready(if_ram_rd_cmd_ready),
    .if_ram_rd_resp_data(if_ram_rd_resp_data),
    .if_ram_rd_resp_valid(if_ram_rd_resp_valid),
    .if_ram_rd_resp_ready(if_ram_rd_resp_ready),

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
