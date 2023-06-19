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
 * Example design core logic - PCIe DMA wrapper
 */
module example_core_pcie #
(
    // TLP data width
    parameter TLP_DATA_WIDTH = 256,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TX sequence number count
    parameter TX_SEQ_NUM_COUNT = 1,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 5,
    // TX sequence number tracking enable
    parameter TX_SEQ_NUM_ENABLE = 1,
    // Immediate enable
    parameter IMM_ENABLE = 1,
    // Immediate width
    parameter IMM_WIDTH = 32,
    // PCIe tag count
    parameter PCIE_TAG_COUNT = 256,
    // Operation table size (read)
    parameter READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    // In-flight transmit limit (read)
    parameter READ_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // Completion header flow control credit limit (read)
    parameter READ_CPLH_FC_LIMIT = 0,
    // Completion data flow control credit limit (read)
    parameter READ_CPLD_FC_LIMIT = READ_CPLH_FC_LIMIT*4,
    // Operation table size (write)
    parameter WRITE_OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    // In-flight transmit limit (write)
    parameter WRITE_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    // Force 64 bit address
    parameter TLP_FORCE_64_BIT_ADDR = 0,
    // Requester ID mash
    parameter CHECK_BUS_NUMBER = 1,
    // BAR0 aperture (log2 size)
    parameter BAR0_APERTURE = 24,
    // BAR2 aperture (log2 size)
    parameter BAR2_APERTURE = 24,
    // BAR4 aperture (log2 size)
    parameter BAR4_APERTURE = 16
)
(
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * TLP input (request)
     */
    input  wire [TLP_DATA_WIDTH-1:0]                     rx_req_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                     rx_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        rx_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*3-1:0]                    rx_req_tlp_bar_id,
    input  wire [TLP_SEG_COUNT*8-1:0]                    rx_req_tlp_func_num,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_req_tlp_eop,
    output wire                                          rx_req_tlp_ready,

    /*
     * TLP output (completion)
     */
    output wire [TLP_DATA_WIDTH-1:0]                     tx_cpl_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]                     tx_cpl_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        tx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT-1:0]                      tx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      tx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      tx_cpl_tlp_eop,
    input  wire                                          tx_cpl_tlp_ready,

    /*
     * TLP input (completion)
     */
    input  wire [TLP_DATA_WIDTH-1:0]                     rx_cpl_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                     rx_cpl_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        rx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT*4-1:0]                    rx_cpl_tlp_error,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      rx_cpl_tlp_eop,
    output wire                                          rx_cpl_tlp_ready,

    /*
     * TLP output (read request)
     */
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        tx_rd_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_rd_req_tlp_seq,
    output wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      tx_rd_req_tlp_eop,
    input  wire                                          tx_rd_req_tlp_ready,

    /*
     * TLP output (write request)
     */
    output wire [TLP_DATA_WIDTH-1:0]                     tx_wr_req_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]                     tx_wr_req_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]        tx_wr_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     tx_wr_req_tlp_seq,
    output wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      tx_wr_req_tlp_eop,
    input  wire                                          tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number input
     */
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_rd_req_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_rd_req_tx_seq_num_valid,
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_wr_req_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_wr_req_tx_seq_num_valid,

    /*
     * TLP output (MSI-X write request)
     */
    output wire [31:0]                                   tx_msix_wr_req_tlp_data,
    output wire                                          tx_msix_wr_req_tlp_strb,
    output wire [TLP_HDR_WIDTH-1:0]                      tx_msix_wr_req_tlp_hdr,
    output wire                                          tx_msix_wr_req_tlp_valid,
    output wire                                          tx_msix_wr_req_tlp_sop,
    output wire                                          tx_msix_wr_req_tlp_eop,
    input  wire                                          tx_msix_wr_req_tlp_ready,

    /*
     * Configuration
     */
    input  wire [7:0]                                    bus_num,
    input  wire                                          ext_tag_enable,
    input  wire                                          rcb_128b,
    input  wire [2:0]                                    max_read_request_size,
    input  wire [2:0]                                    max_payload_size,
    input  wire                                          msix_enable,
    input  wire                                          msix_mask,

    /*
     * Status
     */
    output wire                                          status_error_cor,
    output wire                                          status_error_uncor,

    /*
     * Control and status
     */
    output wire                                          rx_cpl_stall
);

parameter AXIL_CTRL_DATA_WIDTH = 32;
parameter AXIL_CTRL_ADDR_WIDTH = BAR0_APERTURE;
parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8);

parameter AXI_DATA_WIDTH = TLP_DATA_WIDTH;
parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
parameter AXI_ADDR_WIDTH = BAR2_APERTURE;
parameter AXI_ID_WIDTH = 8;

parameter AXIL_MSIX_DATA_WIDTH = 32;
parameter AXIL_MSIX_ADDR_WIDTH = BAR4_APERTURE;
parameter AXIL_MSIX_STRB_WIDTH = (AXIL_MSIX_DATA_WIDTH/8);

parameter RAM_SEL_WIDTH = 2;
parameter RAM_ADDR_WIDTH = 16;
parameter RAM_SEG_COUNT = TLP_SEG_COUNT*2;
parameter RAM_SEG_DATA_WIDTH = TLP_DATA_WIDTH*2/RAM_SEG_COUNT;
parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8;
parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH);

parameter PCIE_ADDR_WIDTH = 64;
parameter DMA_LEN_WIDTH = 16;
parameter DMA_TAG_WIDTH = 8;

parameter IRQ_INDEX_WIDTH = 5;

wire [AXIL_CTRL_ADDR_WIDTH-1:0]  axil_ctrl_awaddr;
wire [2:0]                       axil_ctrl_awprot;
wire                             axil_ctrl_awvalid;
wire                             axil_ctrl_awready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_ctrl_wdata;
wire [AXIL_CTRL_STRB_WIDTH-1:0]  axil_ctrl_wstrb;
wire                             axil_ctrl_wvalid;
wire                             axil_ctrl_wready;
wire [1:0]                       axil_ctrl_bresp;
wire                             axil_ctrl_bvalid;
wire                             axil_ctrl_bready;
wire [AXIL_CTRL_ADDR_WIDTH-1:0]  axil_ctrl_araddr;
wire [2:0]                       axil_ctrl_arprot;
wire                             axil_ctrl_arvalid;
wire                             axil_ctrl_arready;
wire [AXIL_CTRL_DATA_WIDTH-1:0]  axil_ctrl_rdata;
wire [1:0]                       axil_ctrl_rresp;
wire                             axil_ctrl_rvalid;
wire                             axil_ctrl_rready;

wire [AXIL_MSIX_ADDR_WIDTH-1:0]  axil_msix_awaddr;
wire [2:0]                       axil_msix_awprot;
wire                             axil_msix_awvalid;
wire                             axil_msix_awready;
wire [AXIL_MSIX_DATA_WIDTH-1:0]  axil_msix_wdata;
wire [AXIL_MSIX_STRB_WIDTH-1:0]  axil_msix_wstrb;
wire                             axil_msix_wvalid;
wire                             axil_msix_wready;
wire [1:0]                       axil_msix_bresp;
wire                             axil_msix_bvalid;
wire                             axil_msix_bready;
wire [AXIL_MSIX_ADDR_WIDTH-1:0]  axil_msix_araddr;
wire [2:0]                       axil_msix_arprot;
wire                             axil_msix_arvalid;
wire                             axil_msix_arready;
wire [AXIL_MSIX_DATA_WIDTH-1:0]  axil_msix_rdata;
wire [1:0]                       axil_msix_rresp;
wire                             axil_msix_rvalid;
wire                             axil_msix_rready;

wire [PCIE_ADDR_WIDTH-1:0]  axis_dma_read_desc_dma_addr;
wire [RAM_SEL_WIDTH-1:0]    axis_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]   axis_dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]    axis_dma_read_desc_len;
wire [DMA_TAG_WIDTH-1:0]    axis_dma_read_desc_tag;
wire                        axis_dma_read_desc_valid;
wire                        axis_dma_read_desc_ready;

wire [DMA_TAG_WIDTH-1:0]    axis_dma_read_desc_status_tag;
wire [3:0]                  axis_dma_read_desc_status_error;
wire                        axis_dma_read_desc_status_valid;

wire [PCIE_ADDR_WIDTH-1:0]  axis_dma_write_desc_dma_addr;
wire [RAM_SEL_WIDTH-1:0]    axis_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]   axis_dma_write_desc_ram_addr;
wire [IMM_WIDTH-1:0]        axis_dma_write_desc_imm;
wire                        axis_dma_write_desc_imm_en;
wire [DMA_LEN_WIDTH-1:0]    axis_dma_write_desc_len;
wire [DMA_TAG_WIDTH-1:0]    axis_dma_write_desc_tag;
wire                        axis_dma_write_desc_valid;
wire                        axis_dma_write_desc_ready;

wire [DMA_TAG_WIDTH-1:0]    axis_dma_write_desc_status_tag;
wire [3:0]                  axis_dma_write_desc_status_error;
wire                        axis_dma_write_desc_status_valid;

wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_ready;
wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     ram_wr_done;

wire [3:0] status_error_cor_int;
wire [3:0] status_error_uncor_int;

// PCIe connections
wire [TLP_DATA_WIDTH-1:0]               ctrl_rx_req_tlp_data;
wire [TLP_STRB_WIDTH-1:0]               ctrl_rx_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  ctrl_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]              ctrl_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]              ctrl_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                ctrl_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                ctrl_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                ctrl_rx_req_tlp_eop;
wire                                    ctrl_rx_req_tlp_ready;

wire [TLP_DATA_WIDTH-1:0]               ctrl_tx_cpl_tlp_data;
wire [TLP_STRB_WIDTH-1:0]               ctrl_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  ctrl_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                ctrl_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                ctrl_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                ctrl_tx_cpl_tlp_eop;
wire                                    ctrl_tx_cpl_tlp_ready;

wire [TLP_DATA_WIDTH-1:0]               ram_rx_req_tlp_data;
wire [TLP_STRB_WIDTH-1:0]               ram_rx_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  ram_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]              ram_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]              ram_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                ram_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                ram_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                ram_rx_req_tlp_eop;
wire                                    ram_rx_req_tlp_ready;

wire [TLP_DATA_WIDTH-1:0]               ram_tx_cpl_tlp_data;
wire [TLP_STRB_WIDTH-1:0]               ram_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  ram_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                ram_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                ram_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                ram_tx_cpl_tlp_eop;
wire                                    ram_tx_cpl_tlp_ready;

wire [TLP_DATA_WIDTH-1:0]               msix_rx_req_tlp_data;
wire [TLP_STRB_WIDTH-1:0]               msix_rx_req_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  msix_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]              msix_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]              msix_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                msix_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                msix_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                msix_rx_req_tlp_eop;
wire                                    msix_rx_req_tlp_ready;

wire [TLP_DATA_WIDTH-1:0]               msix_tx_cpl_tlp_data;
wire [TLP_STRB_WIDTH-1:0]               msix_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  msix_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                msix_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                msix_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                msix_tx_cpl_tlp_eop;
wire                                    msix_tx_cpl_tlp_ready;

// Interrupts
wire [IRQ_INDEX_WIDTH-1:0]  irq_index;
wire                        irq_valid;
wire                        irq_ready;

// Control and status
wire dma_enable;
wire dma_rd_busy;
wire dma_wr_busy;

pcie_tlp_demux_bar #(
    .PORTS(3),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .IN_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .FIFO_ENABLE(0),
    .BAR_BASE(0),
    .BAR_STRIDE(2),
    .BAR_IDS(0)
)
pcie_tlp_demux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(rx_req_tlp_data),
    .in_tlp_strb(rx_req_tlp_strb),
    .in_tlp_hdr(rx_req_tlp_hdr),
    .in_tlp_bar_id(rx_req_tlp_bar_id),
    .in_tlp_func_num(rx_req_tlp_func_num),
    .in_tlp_error(0),
    .in_tlp_valid(rx_req_tlp_valid),
    .in_tlp_sop(rx_req_tlp_sop),
    .in_tlp_eop(rx_req_tlp_eop),
    .in_tlp_ready(rx_req_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(    {msix_rx_req_tlp_data,     ram_rx_req_tlp_data,     ctrl_rx_req_tlp_data    }),
    .out_tlp_strb(    {msix_rx_req_tlp_strb,     ram_rx_req_tlp_strb,     ctrl_rx_req_tlp_strb    }),
    .out_tlp_hdr(     {msix_rx_req_tlp_hdr,      ram_rx_req_tlp_hdr,      ctrl_rx_req_tlp_hdr     }),
    .out_tlp_bar_id(  {msix_rx_req_tlp_bar_id,   ram_rx_req_tlp_bar_id,   ctrl_rx_req_tlp_bar_id  }),
    .out_tlp_func_num({msix_rx_req_tlp_func_num, ram_rx_req_tlp_func_num, ctrl_rx_req_tlp_func_num}),
    .out_tlp_error(),
    .out_tlp_valid(   {msix_rx_req_tlp_valid,    ram_rx_req_tlp_valid,    ctrl_rx_req_tlp_valid   }),
    .out_tlp_sop(     {msix_rx_req_tlp_sop,      ram_rx_req_tlp_sop,      ctrl_rx_req_tlp_sop     }),
    .out_tlp_eop(     {msix_rx_req_tlp_eop,      ram_rx_req_tlp_eop,      ctrl_rx_req_tlp_eop     }),
    .out_tlp_ready(   {msix_rx_req_tlp_ready,    ram_rx_req_tlp_ready,    ctrl_rx_req_tlp_ready   }),

    /*
     * Control
     */
    .enable(1'b1),

    /*
     * Status
     */
    .fifo_half_full(),
    .fifo_watermark()
);

pcie_tlp_mux #(
    .PORTS(3),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
pcie_tlp_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data( {msix_tx_cpl_tlp_data,  ram_tx_cpl_tlp_data,  ctrl_tx_cpl_tlp_data }),
    .in_tlp_strb( {msix_tx_cpl_tlp_strb,  ram_tx_cpl_tlp_strb,  ctrl_tx_cpl_tlp_strb }),
    .in_tlp_hdr(  {msix_tx_cpl_tlp_hdr,   ram_tx_cpl_tlp_hdr,   ctrl_tx_cpl_tlp_hdr  }),
    .in_tlp_seq(0),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid({msix_tx_cpl_tlp_valid, ram_tx_cpl_tlp_valid, ctrl_tx_cpl_tlp_valid}),
    .in_tlp_sop(  {msix_tx_cpl_tlp_sop,   ram_tx_cpl_tlp_sop,   ctrl_tx_cpl_tlp_sop  }),
    .in_tlp_eop(  {msix_tx_cpl_tlp_eop,   ram_tx_cpl_tlp_eop,   ctrl_tx_cpl_tlp_eop  }),
    .in_tlp_ready({msix_tx_cpl_tlp_ready, ram_tx_cpl_tlp_ready, ctrl_tx_cpl_tlp_ready}),

    /*
     * TLP output
     */
    .out_tlp_data(tx_cpl_tlp_data),
    .out_tlp_strb(tx_cpl_tlp_strb),
    .out_tlp_hdr(tx_cpl_tlp_hdr),
    .out_tlp_seq(),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(),
    .out_tlp_valid(tx_cpl_tlp_valid),
    .out_tlp_sop(tx_cpl_tlp_sop),
    .out_tlp_eop(tx_cpl_tlp_eop),
    .out_tlp_ready(tx_cpl_tlp_ready),

    /*
     * Control
     */
    .pause(0),

    /*
     * Status
     */
    .sel_tlp_seq(),
    .sel_tlp_seq_valid()
);

pcie_axil_master #(
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .AXIL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
pcie_axil_master_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request)
     */
    .rx_req_tlp_data(ctrl_rx_req_tlp_data),
    .rx_req_tlp_hdr(ctrl_rx_req_tlp_hdr),
    .rx_req_tlp_valid(ctrl_rx_req_tlp_valid),
    .rx_req_tlp_sop(ctrl_rx_req_tlp_sop),
    .rx_req_tlp_eop(ctrl_rx_req_tlp_eop),
    .rx_req_tlp_ready(ctrl_rx_req_tlp_ready),

    /*
     * TLP output (completion)
     */
    .tx_cpl_tlp_data(ctrl_tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(ctrl_tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(ctrl_tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(ctrl_tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(ctrl_tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(ctrl_tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(ctrl_tx_cpl_tlp_ready),

    /*
     * AXI Lite Master output
     */
    .m_axil_awaddr(axil_ctrl_awaddr),
    .m_axil_awprot(axil_ctrl_awprot),
    .m_axil_awvalid(axil_ctrl_awvalid),
    .m_axil_awready(axil_ctrl_awready),
    .m_axil_wdata(axil_ctrl_wdata),
    .m_axil_wstrb(axil_ctrl_wstrb),
    .m_axil_wvalid(axil_ctrl_wvalid),
    .m_axil_wready(axil_ctrl_wready),
    .m_axil_bresp(axil_ctrl_bresp),
    .m_axil_bvalid(axil_ctrl_bvalid),
    .m_axil_bready(axil_ctrl_bready),
    .m_axil_araddr(axil_ctrl_araddr),
    .m_axil_arprot(axil_ctrl_arprot),
    .m_axil_arvalid(axil_ctrl_arvalid),
    .m_axil_arready(axil_ctrl_arready),
    .m_axil_rdata(axil_ctrl_rdata),
    .m_axil_rresp(axil_ctrl_rresp),
    .m_axil_rvalid(axil_ctrl_rvalid),
    .m_axil_rready(axil_ctrl_rready),

    /*
     * Configuration
     */
    .completer_id({bus_num, 5'd0, 3'd0}),

    /*
     * Status
     */
    .status_error_cor(status_error_cor_int[0]),
    .status_error_uncor(status_error_uncor_int[0])
);

wire [AXI_ID_WIDTH-1:0]    axi_ram_awid;
wire [AXI_ADDR_WIDTH-1:0]  axi_ram_awaddr;
wire [7:0]                 axi_ram_awlen;
wire [2:0]                 axi_ram_awsize;
wire [1:0]                 axi_ram_awburst;
wire                       axi_ram_awlock;
wire [3:0]                 axi_ram_awcache;
wire [2:0]                 axi_ram_awprot;
wire                       axi_ram_awvalid;
wire                       axi_ram_awready;
wire [AXI_DATA_WIDTH-1:0]  axi_ram_wdata;
wire [AXI_STRB_WIDTH-1:0]  axi_ram_wstrb;
wire                       axi_ram_wlast;
wire                       axi_ram_wvalid;
wire                       axi_ram_wready;
wire [AXI_ID_WIDTH-1:0]    axi_ram_bid;
wire [1:0]                 axi_ram_bresp;
wire                       axi_ram_bvalid;
wire                       axi_ram_bready;
wire [AXI_ID_WIDTH-1:0]    axi_ram_arid;
wire [AXI_ADDR_WIDTH-1:0]  axi_ram_araddr;
wire [7:0]                 axi_ram_arlen;
wire [2:0]                 axi_ram_arsize;
wire [1:0]                 axi_ram_arburst;
wire                       axi_ram_arlock;
wire [3:0]                 axi_ram_arcache;
wire [2:0]                 axi_ram_arprot;
wire                       axi_ram_arvalid;
wire                       axi_ram_arready;
wire [AXI_ID_WIDTH-1:0]    axi_ram_rid;
wire [AXI_DATA_WIDTH-1:0]  axi_ram_rdata;
wire [1:0]                 axi_ram_rresp;
wire                       axi_ram_rlast;
wire                       axi_ram_rvalid;
wire                       axi_ram_rready;

pcie_axi_master #(
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(256),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
pcie_axi_master_isnt (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request)
     */
    .rx_req_tlp_data(ram_rx_req_tlp_data),
    .rx_req_tlp_hdr(ram_rx_req_tlp_hdr),
    .rx_req_tlp_valid(ram_rx_req_tlp_valid),
    .rx_req_tlp_sop(ram_rx_req_tlp_sop),
    .rx_req_tlp_eop(ram_rx_req_tlp_eop),
    .rx_req_tlp_ready(ram_rx_req_tlp_ready),

    /*
     * TLP output (completion)
     */
    .tx_cpl_tlp_data(ram_tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(ram_tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(ram_tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(ram_tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(ram_tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(ram_tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(ram_tx_cpl_tlp_ready),

    /*
     * AXI Master output
     */
    .m_axi_awid(axi_ram_awid),
    .m_axi_awaddr(axi_ram_awaddr),
    .m_axi_awlen(axi_ram_awlen),
    .m_axi_awsize(axi_ram_awsize),
    .m_axi_awburst(axi_ram_awburst),
    .m_axi_awlock(axi_ram_awlock),
    .m_axi_awcache(axi_ram_awcache),
    .m_axi_awprot(axi_ram_awprot),
    .m_axi_awvalid(axi_ram_awvalid),
    .m_axi_awready(axi_ram_awready),
    .m_axi_wdata(axi_ram_wdata),
    .m_axi_wstrb(axi_ram_wstrb),
    .m_axi_wlast(axi_ram_wlast),
    .m_axi_wvalid(axi_ram_wvalid),
    .m_axi_wready(axi_ram_wready),
    .m_axi_bid(axi_ram_bid),
    .m_axi_bresp(axi_ram_bresp),
    .m_axi_bvalid(axi_ram_bvalid),
    .m_axi_bready(axi_ram_bready),
    .m_axi_arid(axi_ram_arid),
    .m_axi_araddr(axi_ram_araddr),
    .m_axi_arlen(axi_ram_arlen),
    .m_axi_arsize(axi_ram_arsize),
    .m_axi_arburst(axi_ram_arburst),
    .m_axi_arlock(axi_ram_arlock),
    .m_axi_arcache(axi_ram_arcache),
    .m_axi_arprot(axi_ram_arprot),
    .m_axi_arvalid(axi_ram_arvalid),
    .m_axi_arready(axi_ram_arready),
    .m_axi_rid(axi_ram_rid),
    .m_axi_rdata(axi_ram_rdata),
    .m_axi_rresp(axi_ram_rresp),
    .m_axi_rlast(axi_ram_rlast),
    .m_axi_rvalid(axi_ram_rvalid),
    .m_axi_rready(axi_ram_rready),

    /*
     * Configuration
     */
    .completer_id({bus_num, 5'd0, 3'd0}),
    .max_payload_size(max_payload_size),

    /*
     * Status
     */
    .status_error_cor(status_error_cor_int[1]),
    .status_error_uncor(status_error_uncor_int[1])
);

axi_ram #(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH < 16 ? AXI_ADDR_WIDTH : 16),
    .ID_WIDTH(AXI_ID_WIDTH),
    .PIPELINE_OUTPUT(1)
)
axi_ram_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(axi_ram_awid),
    .s_axi_awaddr(axi_ram_awaddr),
    .s_axi_awlen(axi_ram_awlen),
    .s_axi_awsize(axi_ram_awsize),
    .s_axi_awburst(axi_ram_awburst),
    .s_axi_awlock(axi_ram_awlock),
    .s_axi_awcache(axi_ram_awcache),
    .s_axi_awprot(axi_ram_awprot),
    .s_axi_awvalid(axi_ram_awvalid),
    .s_axi_awready(axi_ram_awready),
    .s_axi_wdata(axi_ram_wdata),
    .s_axi_wstrb(axi_ram_wstrb),
    .s_axi_wlast(axi_ram_wlast),
    .s_axi_wvalid(axi_ram_wvalid),
    .s_axi_wready(axi_ram_wready),
    .s_axi_bid(axi_ram_bid),
    .s_axi_bresp(axi_ram_bresp),
    .s_axi_bvalid(axi_ram_bvalid),
    .s_axi_bready(axi_ram_bready),
    .s_axi_arid(axi_ram_arid),
    .s_axi_araddr(axi_ram_araddr),
    .s_axi_arlen(axi_ram_arlen),
    .s_axi_arsize(axi_ram_arsize),
    .s_axi_arburst(axi_ram_arburst),
    .s_axi_arlock(axi_ram_arlock),
    .s_axi_arcache(axi_ram_arcache),
    .s_axi_arprot(axi_ram_arprot),
    .s_axi_arvalid(axi_ram_arvalid),
    .s_axi_arready(axi_ram_arready),
    .s_axi_rid(axi_ram_rid),
    .s_axi_rdata(axi_ram_rdata),
    .s_axi_rresp(axi_ram_rresp),
    .s_axi_rlast(axi_ram_rlast),
    .s_axi_rvalid(axi_ram_rvalid),
    .s_axi_rready(axi_ram_rready)
);

pcie_axil_master #(
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .AXIL_DATA_WIDTH(AXIL_MSIX_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_MSIX_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_MSIX_STRB_WIDTH),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
msix_pcie_axil_master_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (request)
     */
    .rx_req_tlp_data(msix_rx_req_tlp_data),
    .rx_req_tlp_hdr(msix_rx_req_tlp_hdr),
    .rx_req_tlp_valid(msix_rx_req_tlp_valid),
    .rx_req_tlp_sop(msix_rx_req_tlp_sop),
    .rx_req_tlp_eop(msix_rx_req_tlp_eop),
    .rx_req_tlp_ready(msix_rx_req_tlp_ready),

    /*
     * TLP output (completion)
     */
    .tx_cpl_tlp_data(msix_tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(msix_tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(msix_tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(msix_tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(msix_tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(msix_tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(msix_tx_cpl_tlp_ready),

    /*
     * AXI Lite Master output
     */
    .m_axil_awaddr(axil_msix_awaddr),
    .m_axil_awprot(axil_msix_awprot),
    .m_axil_awvalid(axil_msix_awvalid),
    .m_axil_awready(axil_msix_awready),
    .m_axil_wdata(axil_msix_wdata),
    .m_axil_wstrb(axil_msix_wstrb),
    .m_axil_wvalid(axil_msix_wvalid),
    .m_axil_wready(axil_msix_wready),
    .m_axil_bresp(axil_msix_bresp),
    .m_axil_bvalid(axil_msix_bvalid),
    .m_axil_bready(axil_msix_bready),
    .m_axil_araddr(axil_msix_araddr),
    .m_axil_arprot(axil_msix_arprot),
    .m_axil_arvalid(axil_msix_arvalid),
    .m_axil_arready(axil_msix_arready),
    .m_axil_rdata(axil_msix_rdata),
    .m_axil_rresp(axil_msix_rresp),
    .m_axil_rvalid(axil_msix_rvalid),
    .m_axil_rready(axil_msix_rready),

    /*
     * Configuration
     */
    .completer_id({bus_num, 5'd0, 3'd0}),

    /*
     * Status
     */
    .status_error_cor(status_error_cor_int[2]),
    .status_error_uncor(status_error_uncor_int[2])
);

dma_if_pcie #(
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(TX_SEQ_NUM_ENABLE),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .IMM_ENABLE(IMM_ENABLE),
    .IMM_WIDTH(IMM_WIDTH),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .TAG_WIDTH(DMA_TAG_WIDTH),
    .READ_OP_TABLE_SIZE(READ_OP_TABLE_SIZE),
    .READ_TX_LIMIT(READ_TX_LIMIT),
    .READ_CPLH_FC_LIMIT(READ_CPLH_FC_LIMIT),
    .READ_CPLD_FC_LIMIT(READ_CPLD_FC_LIMIT),
    .WRITE_OP_TABLE_SIZE(WRITE_OP_TABLE_SIZE),
    .WRITE_TX_LIMIT(WRITE_TX_LIMIT),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR),
    .CHECK_BUS_NUMBER(CHECK_BUS_NUMBER)
)
dma_if_pcie_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (completion)
     */
    .rx_cpl_tlp_data(rx_cpl_tlp_data),
    .rx_cpl_tlp_hdr(rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(rx_cpl_tlp_ready),

    /*
     * TLP output (read request)
     */
    .tx_rd_req_tlp_hdr(tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(tx_rd_req_tlp_ready),

    /*
     * TLP output (write request)
     */
    .tx_wr_req_tlp_data(tx_wr_req_tlp_data),
    .tx_wr_req_tlp_strb(tx_wr_req_tlp_strb),
    .tx_wr_req_tlp_hdr(tx_wr_req_tlp_hdr),
    .tx_wr_req_tlp_seq(tx_wr_req_tlp_seq),
    .tx_wr_req_tlp_valid(tx_wr_req_tlp_valid),
    .tx_wr_req_tlp_sop(tx_wr_req_tlp_sop),
    .tx_wr_req_tlp_eop(tx_wr_req_tlp_eop),
    .tx_wr_req_tlp_ready(tx_wr_req_tlp_ready),

    /*
     * Transmit sequence number input
     */
    .s_axis_rd_req_tx_seq_num(s_axis_rd_req_tx_seq_num),
    .s_axis_rd_req_tx_seq_num_valid(s_axis_rd_req_tx_seq_num_valid),
    .s_axis_wr_req_tx_seq_num(s_axis_wr_req_tx_seq_num),
    .s_axis_wr_req_tx_seq_num_valid(s_axis_wr_req_tx_seq_num_valid),

    /*
     * AXI read descriptor input
     */
    .s_axis_read_desc_pcie_addr(axis_dma_read_desc_dma_addr),
    .s_axis_read_desc_ram_sel(axis_dma_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(axis_dma_read_desc_ram_addr),
    .s_axis_read_desc_len(axis_dma_read_desc_len),
    .s_axis_read_desc_tag(axis_dma_read_desc_tag),
    .s_axis_read_desc_valid(axis_dma_read_desc_valid),
    .s_axis_read_desc_ready(axis_dma_read_desc_ready),

    /*
     * AXI read descriptor status output
     */
    .m_axis_read_desc_status_tag(axis_dma_read_desc_status_tag),
    .m_axis_read_desc_status_error(axis_dma_read_desc_status_error),
    .m_axis_read_desc_status_valid(axis_dma_read_desc_status_valid),

    /*
     * AXI write descriptor input
     */
    .s_axis_write_desc_pcie_addr(axis_dma_write_desc_dma_addr),
    .s_axis_write_desc_ram_sel(axis_dma_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(axis_dma_write_desc_ram_addr),
    .s_axis_write_desc_imm(axis_dma_write_desc_imm),
    .s_axis_write_desc_imm_en(axis_dma_write_desc_imm_en),
    .s_axis_write_desc_len(axis_dma_write_desc_len),
    .s_axis_write_desc_tag(axis_dma_write_desc_tag),
    .s_axis_write_desc_valid(axis_dma_write_desc_valid),
    .s_axis_write_desc_ready(axis_dma_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_tag(axis_dma_write_desc_status_tag),
    .m_axis_write_desc_status_error(axis_dma_write_desc_status_error),
    .m_axis_write_desc_status_valid(axis_dma_write_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_rd_cmd_sel(ram_rd_cmd_sel),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_valid(ram_rd_cmd_valid),
    .ram_rd_cmd_ready(ram_rd_cmd_ready),
    .ram_rd_resp_data(ram_rd_resp_data),
    .ram_rd_resp_valid(ram_rd_resp_valid),
    .ram_rd_resp_ready(ram_rd_resp_ready),
    .ram_wr_cmd_sel(ram_wr_cmd_sel),
    .ram_wr_cmd_be(ram_wr_cmd_be),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_valid(ram_wr_cmd_valid),
    .ram_wr_cmd_ready(ram_wr_cmd_ready),
    .ram_wr_done(ram_wr_done),

    /*
     * Configuration
     */
    .read_enable(dma_enable),
    .write_enable(dma_enable),
    .ext_tag_enable(ext_tag_enable),
    .rcb_128b(rcb_128b),
    .requester_id({bus_num, 5'd0, 3'd0}),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),

    /*
     * Status
     */
    .status_rd_busy(dma_rd_busy),
    .status_wr_busy(dma_wr_busy),
    .status_error_cor(status_error_cor_int[3]),
    .status_error_uncor(status_error_uncor_int[3])
);

pcie_msix #(
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH),
    .AXIL_DATA_WIDTH(AXIL_MSIX_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_MSIX_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_MSIX_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
pcie_msix_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI lite interface for MSI-X tables
     */
    .s_axil_awaddr(axil_msix_awaddr),
    .s_axil_awprot(axil_msix_awprot),
    .s_axil_awvalid(axil_msix_awvalid),
    .s_axil_awready(axil_msix_awready),
    .s_axil_wdata(axil_msix_wdata),
    .s_axil_wstrb(axil_msix_wstrb),
    .s_axil_wvalid(axil_msix_wvalid),
    .s_axil_wready(axil_msix_wready),
    .s_axil_bresp(axil_msix_bresp),
    .s_axil_bvalid(axil_msix_bvalid),
    .s_axil_bready(axil_msix_bready),
    .s_axil_araddr(axil_msix_araddr),
    .s_axil_arprot(axil_msix_arprot),
    .s_axil_arvalid(axil_msix_arvalid),
    .s_axil_arready(axil_msix_arready),
    .s_axil_rdata(axil_msix_rdata),
    .s_axil_rresp(axil_msix_rresp),
    .s_axil_rvalid(axil_msix_rvalid),
    .s_axil_rready(axil_msix_rready),

    /*
     * Interrupt request input
     */
    .irq_index(irq_index),
    .irq_valid(irq_valid),
    .irq_ready(irq_ready),

    /*
     * Memory write TLP output
     */
    .tx_wr_req_tlp_data(tx_msix_wr_req_tlp_data),
    .tx_wr_req_tlp_strb(tx_msix_wr_req_tlp_strb),
    .tx_wr_req_tlp_hdr(tx_msix_wr_req_tlp_hdr),
    .tx_wr_req_tlp_valid(tx_msix_wr_req_tlp_valid),
    .tx_wr_req_tlp_sop(tx_msix_wr_req_tlp_sop),
    .tx_wr_req_tlp_eop(tx_msix_wr_req_tlp_eop),
    .tx_wr_req_tlp_ready(tx_msix_wr_req_tlp_ready),

    /*
     * Configuration
     */
    .requester_id({bus_num, 5'd0, 3'd0}),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask)
);

pulse_merge #(
    .INPUT_WIDTH(4),
    .COUNT_WIDTH(4)
)
status_error_cor_pm_inst (
    .clk(clk),
    .rst(rst),

    .pulse_in(status_error_cor_int),
    .count_out(),
    .pulse_out(status_error_cor)
);

pulse_merge #(
    .INPUT_WIDTH(4),
    .COUNT_WIDTH(4)
)
status_error_uncor_pm_inst (
    .clk(clk),
    .rst(rst),

    .pulse_in(status_error_uncor_int),
    .count_out(),
    .pulse_out(status_error_uncor)
);

example_core #(
    .AXIL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .DMA_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .DMA_IMM_ENABLE(IMM_ENABLE),
    .DMA_IMM_WIDTH(IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .IRQ_INDEX_WIDTH(IRQ_INDEX_WIDTH)
)
core_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI Lite control interface
     */
    .s_axil_ctrl_awaddr(axil_ctrl_awaddr),
    .s_axil_ctrl_awprot(axil_ctrl_awprot),
    .s_axil_ctrl_awvalid(axil_ctrl_awvalid),
    .s_axil_ctrl_awready(axil_ctrl_awready),
    .s_axil_ctrl_wdata(axil_ctrl_wdata),
    .s_axil_ctrl_wstrb(axil_ctrl_wstrb),
    .s_axil_ctrl_wvalid(axil_ctrl_wvalid),
    .s_axil_ctrl_wready(axil_ctrl_wready),
    .s_axil_ctrl_bresp(axil_ctrl_bresp),
    .s_axil_ctrl_bvalid(axil_ctrl_bvalid),
    .s_axil_ctrl_bready(axil_ctrl_bready),
    .s_axil_ctrl_araddr(axil_ctrl_araddr),
    .s_axil_ctrl_arprot(axil_ctrl_arprot),
    .s_axil_ctrl_arvalid(axil_ctrl_arvalid),
    .s_axil_ctrl_arready(axil_ctrl_arready),
    .s_axil_ctrl_rdata(axil_ctrl_rdata),
    .s_axil_ctrl_rresp(axil_ctrl_rresp),
    .s_axil_ctrl_rvalid(axil_ctrl_rvalid),
    .s_axil_ctrl_rready(axil_ctrl_rready),

    /*
     * AXI read descriptor output
     */
    .m_axis_dma_read_desc_dma_addr(axis_dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_sel(axis_dma_read_desc_ram_sel),
    .m_axis_dma_read_desc_ram_addr(axis_dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(axis_dma_read_desc_len),
    .m_axis_dma_read_desc_tag(axis_dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(axis_dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(axis_dma_read_desc_ready),

    /*
     * AXI read descriptor status input
     */
    .s_axis_dma_read_desc_status_tag(axis_dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(axis_dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(axis_dma_read_desc_status_valid),

    /*
     * AXI write descriptor output
     */
    .m_axis_dma_write_desc_dma_addr(axis_dma_write_desc_dma_addr),
    .m_axis_dma_write_desc_ram_sel(axis_dma_write_desc_ram_sel),
    .m_axis_dma_write_desc_ram_addr(axis_dma_write_desc_ram_addr),
    .m_axis_dma_write_desc_imm(axis_dma_write_desc_imm),
    .m_axis_dma_write_desc_imm_en(axis_dma_write_desc_imm_en),
    .m_axis_dma_write_desc_len(axis_dma_write_desc_len),
    .m_axis_dma_write_desc_tag(axis_dma_write_desc_tag),
    .m_axis_dma_write_desc_valid(axis_dma_write_desc_valid),
    .m_axis_dma_write_desc_ready(axis_dma_write_desc_ready),

    /*
     * AXI write descriptor status input
     */
    .s_axis_dma_write_desc_status_tag(axis_dma_write_desc_status_tag),
    .s_axis_dma_write_desc_status_error(axis_dma_write_desc_status_error),
    .s_axis_dma_write_desc_status_valid(axis_dma_write_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_rd_cmd_sel(ram_rd_cmd_sel),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_valid(ram_rd_cmd_valid),
    .ram_rd_cmd_ready(ram_rd_cmd_ready),
    .ram_rd_resp_data(ram_rd_resp_data),
    .ram_rd_resp_valid(ram_rd_resp_valid),
    .ram_rd_resp_ready(ram_rd_resp_ready),
    .ram_wr_cmd_sel(ram_wr_cmd_sel),
    .ram_wr_cmd_be(ram_wr_cmd_be),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_data(ram_wr_cmd_data),
    .ram_wr_cmd_valid(ram_wr_cmd_valid),
    .ram_wr_cmd_ready(ram_wr_cmd_ready),
    .ram_wr_done(ram_wr_done),

    /*
     * Interrupt request output
     */
    .irq_index(irq_index),
    .irq_valid(irq_valid),
    .irq_ready(irq_ready),

    /*
     * Control and status
     */
    .dma_enable(dma_enable),
    .dma_rd_busy(dma_rd_busy),
    .dma_wr_busy(dma_wr_busy),
    .dma_rd_req(tx_rd_req_tlp_valid && tx_rd_req_tlp_sop && tx_rd_req_tlp_ready),
    .dma_rd_cpl(rx_cpl_tlp_valid && rx_cpl_tlp_sop && rx_cpl_tlp_ready),
    .dma_wr_req(tx_wr_req_tlp_valid && tx_wr_req_tlp_sop && tx_wr_req_tlp_ready),
    .rx_cpl_stall(rx_cpl_stall)
);

endmodule

`resetall
