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
 * PCIe AXI Master
 */
module pcie_axi_master #
(
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TLP segment data width
    parameter TLP_SEG_DATA_WIDTH = 256,
    // TLP segment strobe width
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    // TLP segment header width
    parameter TLP_SEG_HDR_WIDTH = 128,
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 64,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // Force 64 bit address
    parameter TLP_FORCE_64_BIT_ADDR = 0
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * TLP input (request)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  rx_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   rx_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                     rx_req_tlp_eop,
    output wire                                         rx_req_tlp_ready,

    /*
     * TLP output (completion)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  tx_cpl_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  tx_cpl_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   tx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                     tx_cpl_tlp_eop,
    input  wire                                         tx_cpl_tlp_ready,

    /*
     * AXI Master output
     */
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr,
    output wire [7:0]                                   m_axi_awlen,
    output wire [2:0]                                   m_axi_awsize,
    output wire [1:0]                                   m_axi_awburst,
    output wire                                         m_axi_awlock,
    output wire [3:0]                                   m_axi_awcache,
    output wire [2:0]                                   m_axi_awprot,
    output wire                                         m_axi_awvalid,
    input  wire                                         m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]                    m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]                    m_axi_wstrb,
    output wire                                         m_axi_wlast,
    output wire                                         m_axi_wvalid,
    input  wire                                         m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_bid,
    input  wire [1:0]                                   m_axi_bresp,
    input  wire                                         m_axi_bvalid,
    output wire                                         m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]                      m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr,
    output wire [7:0]                                   m_axi_arlen,
    output wire [2:0]                                   m_axi_arsize,
    output wire [1:0]                                   m_axi_arburst,
    output wire                                         m_axi_arlock,
    output wire [3:0]                                   m_axi_arcache,
    output wire [2:0]                                   m_axi_arprot,
    output wire                                         m_axi_arvalid,
    input  wire                                         m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]                      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]                    m_axi_rdata,
    input  wire [1:0]                                   m_axi_rresp,
    input  wire                                         m_axi_rlast,
    input  wire                                         m_axi_rvalid,
    output wire                                         m_axi_rready,

    /*
     * Configuration
     */
    input  wire [15:0]                                  completer_id,
    input  wire [2:0]                                   max_payload_size,

    /*
     * Status
     */
    output wire                                         status_error_cor,
    output wire                                         status_error_uncor
);

wire [1:0] status_error_uncor_int;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  read_rx_req_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   read_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                     read_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                     read_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                     read_rx_req_tlp_eop;
wire                                         read_rx_req_tlp_ready;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  write_rx_req_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   write_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                     write_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                     write_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                     write_rx_req_tlp_eop;
wire                                         write_rx_req_tlp_ready;

wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0] match_tlp_hdr;

wire [TLP_SEG_COUNT*2-1:0] select;

generate

    genvar n;

    for (n = 0; n < TLP_SEG_COUNT; n = n + 1) begin
        assign select[n*2+1] = match_tlp_hdr[n*TLP_SEG_HDR_WIDTH+120 +: 8] == 8'b010_00000 ||
            match_tlp_hdr[n*TLP_SEG_HDR_WIDTH+120 +: 8] == 8'b011_00000;
        assign select[n*2+0] = !select[n*2+1];
    end

endgenerate

pcie_tlp_demux #(
    .PORTS(2),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH)
)
pcie_tlp_demux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(rx_req_tlp_data),
    .in_tlp_strb(0),
    .in_tlp_hdr(rx_req_tlp_hdr),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid(rx_req_tlp_valid),
    .in_tlp_sop(rx_req_tlp_sop),
    .in_tlp_eop(rx_req_tlp_eop),
    .in_tlp_ready(rx_req_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data({write_rx_req_tlp_data, read_rx_req_tlp_data}),
    .out_tlp_strb(),
    .out_tlp_hdr({write_rx_req_tlp_hdr, read_rx_req_tlp_hdr}),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(),
    .out_tlp_valid({write_rx_req_tlp_valid, read_rx_req_tlp_valid}),
    .out_tlp_sop({write_rx_req_tlp_sop, read_rx_req_tlp_sop}),
    .out_tlp_eop({write_rx_req_tlp_eop, read_rx_req_tlp_eop}),
    .out_tlp_ready({write_rx_req_tlp_ready, read_rx_req_tlp_ready}),

    /*
     * Fields
     */
    .match_tlp_hdr(match_tlp_hdr),
    .match_tlp_bar_id(),
    .match_tlp_func_num(),

    /*
     * Control
     */
    .enable(1'b1),
    .drop({TLP_SEG_COUNT{1'b0}}),
    .select(select)
);

pcie_axi_master_rd #(
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
pcie_axi_master_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request)
     */
    .rx_req_tlp_hdr(read_rx_req_tlp_hdr),
    .rx_req_tlp_valid(read_rx_req_tlp_valid),
    .rx_req_tlp_sop(read_rx_req_tlp_sop),
    .rx_req_tlp_eop(read_rx_req_tlp_eop),
    .rx_req_tlp_ready(read_rx_req_tlp_ready),

    /*
     * TLP output (completion)
     */
    .tx_cpl_tlp_data(tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(tx_cpl_tlp_ready),

    /*
     * AXI master interface
     */
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    /*
     * Configuration
     */
    .completer_id(completer_id),
    .max_payload_size(max_payload_size),

    /*
     * Status
     */
    .status_error_cor(status_error_cor),
    .status_error_uncor(status_error_uncor_int[0])
);

pcie_axi_master_wr #(
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
pcie_axi_master_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request)
     */
    .rx_req_tlp_data(write_rx_req_tlp_data),
    .rx_req_tlp_hdr(write_rx_req_tlp_hdr),
    .rx_req_tlp_valid(write_rx_req_tlp_valid),
    .rx_req_tlp_sop(write_rx_req_tlp_sop),
    .rx_req_tlp_eop(write_rx_req_tlp_eop),
    .rx_req_tlp_ready(write_rx_req_tlp_ready),

    /*
     * AXI master interface
     */
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),

    /*
     * Status
     */
    .status_error_uncor(status_error_uncor_int[1])
);

pulse_merge #(
    .INPUT_WIDTH(2),
    .COUNT_WIDTH(4)
)
status_error_uncor_pm_inst (
    .clk(clk),
    .rst(rst),

    .pulse_in(status_error_uncor_int),
    .count_out(),
    .pulse_out(status_error_uncor)
);

endmodule

`resetall
