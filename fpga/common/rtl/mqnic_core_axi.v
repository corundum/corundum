/*

Copyright 2021, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA core logic
 */
module mqnic_core_axi #
(
    // FW and board IDs
    parameter FW_ID = 32'd0,
    parameter FW_VER = {16'd0, 16'd1},
    parameter BOARD_ID = {16'h1234, 16'h0000},
    parameter BOARD_VER = {16'd0, 16'd1},

    // Structural configuration
    parameter IF_COUNT = 1,
    parameter PORTS_PER_IF = 1,

    parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF,

    // PTP configuration
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_TAG_WIDTH = 16,
    parameter PTP_PERIOD_NS_WIDTH = 4,
    parameter PTP_OFFSET_NS_WIDTH = 32,
    parameter PTP_FNS_WIDTH = 32,
    parameter PTP_PERIOD_NS = 4'd4,
    parameter PTP_PERIOD_FNS = 32'd0,
    parameter PTP_USE_SAMPLE_CLOCK = 0,
    parameter PTP_SEPARATE_RX_CLOCK = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration (interface)
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_QUEUE_OP_TABLE_SIZE = 32,
    parameter RX_QUEUE_OP_TABLE_SIZE = 32,
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = TX_QUEUE_OP_TABLE_SIZE,
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = RX_QUEUE_OP_TABLE_SIZE,
    parameter TX_QUEUE_INDEX_WIDTH = 13,
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    parameter TX_CPL_QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH,
    parameter RX_CPL_QUEUE_INDEX_WIDTH = RX_QUEUE_INDEX_WIDTH,
    parameter EVENT_QUEUE_PIPELINE = 3,
    parameter TX_QUEUE_PIPELINE = 3+(TX_QUEUE_INDEX_WIDTH > 12 ? TX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter RX_QUEUE_PIPELINE = 3+(RX_QUEUE_INDEX_WIDTH > 12 ? RX_QUEUE_INDEX_WIDTH-12 : 0),
    parameter TX_CPL_QUEUE_PIPELINE = TX_QUEUE_PIPELINE,
    parameter RX_CPL_QUEUE_PIPELINE = RX_QUEUE_PIPELINE,

    // TX and RX engine configuration (port)
    parameter TX_DESC_TABLE_SIZE = 32,
    parameter RX_DESC_TABLE_SIZE = 32,

    // Scheduler configuration (port)
    parameter TX_SCHEDULER_OP_TABLE_SIZE = TX_DESC_TABLE_SIZE,
    parameter TX_SCHEDULER_PIPELINE = TX_QUEUE_PIPELINE,
    parameter TDMA_INDEX_WIDTH = 6,

    // Timestamping configuration (port)
    parameter PTP_TS_ENABLE = 1,
    parameter TX_PTP_TS_FIFO_DEPTH = 32,
    parameter RX_PTP_TS_FIFO_DEPTH = 32,

    // Interface configuration (port)
    parameter TX_CHECKSUM_ENABLE = 1,
    parameter RX_RSS_ENABLE = 1,
    parameter RX_HASH_ENABLE = 1,
    parameter RX_CHECKSUM_ENABLE = 1,
    parameter TX_FIFO_DEPTH = 32768,
    parameter RX_FIFO_DEPTH = 32768,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,
    parameter TX_RAM_SIZE = 32768,
    parameter RX_RAM_SIZE = 32768,

    // Application block configuration
    parameter APP_ENABLE = 0,
    parameter APP_CTRL_ENABLE = 1,
    parameter APP_DMA_ENABLE = 1,
    parameter APP_AXIS_DIRECT_ENABLE = 1,
    parameter APP_AXIS_SYNC_ENABLE = 1,
    parameter APP_AXIS_IF_ENABLE = 1,
    parameter APP_STAT_ENABLE = 1,

    // AXI interface configuration (DMA)
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,

    // DMA interface configuration
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_PIPELINE = 2,
    parameter AXI_DMA_MAX_BURST_LEN = 256,
    parameter AXI_DMA_USE_ID = 1,
    parameter AXI_DMA_READ_OP_TABLE_SIZE = 2**(AXI_ID_WIDTH),
    parameter AXI_DMA_WRITE_OP_TABLE_SIZE = 2**(AXI_ID_WIDTH),

    // Interrupts
    parameter IRQ_COUNT = 32,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 24,
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),
    parameter AXIL_IF_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT),
    parameter AXIL_CSR_ADDR_WIDTH = AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8),
    parameter AXIL_CSR_PASSTHROUGH_ENABLE = 0,

    // AXI lite interface configuration (application control)
    parameter AXIL_APP_CTRL_DATA_WIDTH = AXIL_CTRL_DATA_WIDTH,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 24,
    parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8),

    // Ethernet interface configuration
    parameter AXIS_DATA_WIDTH = 64,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_RX_USE_READY = 0,
    parameter AXIS_TX_PIPELINE = 0,
    parameter AXIS_TX_FIFO_PIPELINE = 2,
    parameter AXIS_TX_TS_PIPELINE = 0,
    parameter AXIS_RX_PIPELINE = 0,
    parameter AXIS_RX_FIFO_PIPELINE = 2,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_DMA_ENABLE = 1,
    parameter STAT_PCIE_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * AXI master interface (DMA)
     */
    output wire [AXI_ID_WIDTH-1:0]                    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]                  m_axi_awaddr,
    output wire [7:0]                                 m_axi_awlen,
    output wire [2:0]                                 m_axi_awsize,
    output wire [1:0]                                 m_axi_awburst,
    output wire                                       m_axi_awlock,
    output wire [3:0]                                 m_axi_awcache,
    output wire [2:0]                                 m_axi_awprot,
    output wire                                       m_axi_awvalid,
    input  wire                                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]                  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]                  m_axi_wstrb,
    output wire                                       m_axi_wlast,
    output wire                                       m_axi_wvalid,
    input  wire                                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]                    m_axi_bid,
    input  wire [1:0]                                 m_axi_bresp,
    input  wire                                       m_axi_bvalid,
    output wire                                       m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]                    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]                  m_axi_araddr,
    output wire [7:0]                                 m_axi_arlen,
    output wire [2:0]                                 m_axi_arsize,
    output wire [1:0]                                 m_axi_arburst,
    output wire                                       m_axi_arlock,
    output wire [3:0]                                 m_axi_arcache,
    output wire [2:0]                                 m_axi_arprot,
    output wire                                       m_axi_arvalid,
    input  wire                                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]                    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]                  m_axi_rdata,
    input  wire [1:0]                                 m_axi_rresp,
    input  wire                                       m_axi_rlast,
    input  wire                                       m_axi_rvalid,
    output wire                                       m_axi_rready,

    /*
     * AXI-Lite slave interface (control)
     */
    input  wire [AXIL_CTRL_ADDR_WIDTH-1:0]            s_axil_ctrl_awaddr,
    input  wire [2:0]                                 s_axil_ctrl_awprot,
    input  wire                                       s_axil_ctrl_awvalid,
    output wire                                       s_axil_ctrl_awready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]            s_axil_ctrl_wdata,
    input  wire [AXIL_CTRL_STRB_WIDTH-1:0]            s_axil_ctrl_wstrb,
    input  wire                                       s_axil_ctrl_wvalid,
    output wire                                       s_axil_ctrl_wready,
    output wire [1:0]                                 s_axil_ctrl_bresp,
    output wire                                       s_axil_ctrl_bvalid,
    input  wire                                       s_axil_ctrl_bready,
    input  wire [AXIL_CTRL_ADDR_WIDTH-1:0]            s_axil_ctrl_araddr,
    input  wire [2:0]                                 s_axil_ctrl_arprot,
    input  wire                                       s_axil_ctrl_arvalid,
    output wire                                       s_axil_ctrl_arready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]            s_axil_ctrl_rdata,
    output wire [1:0]                                 s_axil_ctrl_rresp,
    output wire                                       s_axil_ctrl_rvalid,
    input  wire                                       s_axil_ctrl_rready,

    /*
     * AXI-Lite slave interface (application control)
     */
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]        s_axil_app_ctrl_awaddr,
    input  wire [2:0]                                 s_axil_app_ctrl_awprot,
    input  wire                                       s_axil_app_ctrl_awvalid,
    output wire                                       s_axil_app_ctrl_awready,
    input  wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]        s_axil_app_ctrl_wdata,
    input  wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]        s_axil_app_ctrl_wstrb,
    input  wire                                       s_axil_app_ctrl_wvalid,
    output wire                                       s_axil_app_ctrl_wready,
    output wire [1:0]                                 s_axil_app_ctrl_bresp,
    output wire                                       s_axil_app_ctrl_bvalid,
    input  wire                                       s_axil_app_ctrl_bready,
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]        s_axil_app_ctrl_araddr,
    input  wire [2:0]                                 s_axil_app_ctrl_arprot,
    input  wire                                       s_axil_app_ctrl_arvalid,
    output wire                                       s_axil_app_ctrl_arready,
    output wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]        s_axil_app_ctrl_rdata,
    output wire [1:0]                                 s_axil_app_ctrl_rresp,
    output wire                                       s_axil_app_ctrl_rvalid,
    input  wire                                       s_axil_app_ctrl_rready,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             m_axil_csr_awaddr,
    output wire [2:0]                                 m_axil_csr_awprot,
    output wire                                       m_axil_csr_awvalid,
    input  wire                                       m_axil_csr_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]            m_axil_csr_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]            m_axil_csr_wstrb,
    output wire                                       m_axil_csr_wvalid,
    input  wire                                       m_axil_csr_wready,
    input  wire [1:0]                                 m_axil_csr_bresp,
    input  wire                                       m_axil_csr_bvalid,
    output wire                                       m_axil_csr_bready,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             m_axil_csr_araddr,
    output wire [2:0]                                 m_axil_csr_arprot,
    output wire                                       m_axil_csr_arvalid,
    input  wire                                       m_axil_csr_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]            m_axil_csr_rdata,
    input  wire [1:0]                                 m_axil_csr_rresp,
    input  wire                                       m_axil_csr_rvalid,
    output wire                                       m_axil_csr_rready,

    /*
     * Control register interface
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             ctrl_reg_wr_addr,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]            ctrl_reg_wr_data,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]            ctrl_reg_wr_strb,
    output wire                                       ctrl_reg_wr_en,
    input  wire                                       ctrl_reg_wr_wait,
    input  wire                                       ctrl_reg_wr_ack,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]             ctrl_reg_rd_addr,
    output wire                                       ctrl_reg_rd_en,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]            ctrl_reg_rd_data,
    input  wire                                       ctrl_reg_rd_wait,
    input  wire                                       ctrl_reg_rd_ack,

    /*
     * Interrupt outputs
     */
    output wire [IRQ_COUNT-1:0]                       irq,

    /*
     * PTP clock
     */
    input  wire                                       ptp_sample_clk,
    output wire                                       ptp_pps,
    output wire [PTP_TS_WIDTH-1:0]                    ptp_ts_96,
    output wire                                       ptp_ts_step,
    output wire [PTP_PEROUT_COUNT-1:0]                ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]                ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]                ptp_perout_pulse,

    /*
     * Ethernet
     */
    input  wire [PORT_COUNT-1:0]                      tx_clk,
    input  wire [PORT_COUNT-1:0]                      tx_rst,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]         tx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                      tx_ptp_ts_step,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]      m_axis_tx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]      m_axis_tx_tkeep,
    output wire [PORT_COUNT-1:0]                      m_axis_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                      m_axis_tx_tready,
    output wire [PORT_COUNT-1:0]                      m_axis_tx_tlast,
    output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]   m_axis_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]         s_axis_tx_ptp_ts,
    input  wire [PORT_COUNT*PTP_TAG_WIDTH-1:0]        s_axis_tx_ptp_ts_tag,
    input  wire [PORT_COUNT-1:0]                      s_axis_tx_ptp_ts_valid,
    output wire [PORT_COUNT-1:0]                      s_axis_tx_ptp_ts_ready,

    input  wire [PORT_COUNT-1:0]                      rx_clk,
    input  wire [PORT_COUNT-1:0]                      rx_rst,

    input  wire [PORT_COUNT-1:0]                      rx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                      rx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]         rx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                      rx_ptp_ts_step,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]      s_axis_rx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]      s_axis_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                      s_axis_rx_tvalid,
    output wire [PORT_COUNT-1:0]                      s_axis_rx_tready,
    input  wire [PORT_COUNT-1:0]                      s_axis_rx_tlast,
    input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]   s_axis_rx_tuser,

    /*
     * Statistics increment input
     */
    input  wire [STAT_INC_WIDTH-1:0]                  s_axis_stat_tdata,
    input  wire [STAT_ID_WIDTH-1:0]                   s_axis_stat_tid,
    input  wire                                       s_axis_stat_tvalid,
    output wire                                       s_axis_stat_tready
);

parameter DMA_ADDR_WIDTH = AXI_ADDR_WIDTH;

parameter RAM_SEG_COUNT = 2;
parameter RAM_SEG_DATA_WIDTH = AXI_DATA_WIDTH*2/RAM_SEG_COUNT;
parameter RAM_SEG_ADDR_WIDTH = 12;
parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8;
parameter IF_RAM_SEL_WIDTH = PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1;
parameter RAM_SEL_WIDTH = $clog2(IF_COUNT+(APP_ENABLE && APP_DMA_ENABLE ? 1 : 0))+IF_RAM_SEL_WIDTH+1;
parameter RAM_ADDR_WIDTH = RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH);

// DMA connections
wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_done;
wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_ready;

// DMA control
wire [DMA_ADDR_WIDTH-1:0]  dma_read_desc_dma_addr;
wire [RAM_SEL_WIDTH-1:0]   dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   dma_read_desc_len;
wire [DMA_TAG_WIDTH-1:0]   dma_read_desc_tag;
wire                       dma_read_desc_valid;
wire                       dma_read_desc_ready;

wire [DMA_TAG_WIDTH-1:0]   dma_read_desc_status_tag;
wire [3:0]                 dma_read_desc_status_error;
wire                       dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  dma_write_desc_dma_addr;
wire [RAM_SEL_WIDTH-1:0]   dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  dma_write_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   dma_write_desc_len;
wire [DMA_TAG_WIDTH-1:0]   dma_write_desc_tag;
wire                       dma_write_desc_valid;
wire                       dma_write_desc_ready;

wire [DMA_TAG_WIDTH-1:0]   dma_write_desc_status_tag;
wire [3:0]                 dma_write_desc_status_error;
wire                       dma_write_desc_status_valid;

wire                       dma_enable = 1;

dma_if_axi #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_DMA_MAX_BURST_LEN),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .TAG_WIDTH(DMA_TAG_WIDTH),
    .READ_OP_TABLE_SIZE(AXI_DMA_READ_OP_TABLE_SIZE),
    .WRITE_OP_TABLE_SIZE(AXI_DMA_WRITE_OP_TABLE_SIZE),
    .USE_AXI_ID(AXI_DMA_USE_ID)
)
dma_if_axi_inst (
    .clk(clk),
    .rst(rst),

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
     * AXI read descriptor input
     */
    .s_axis_read_desc_axi_addr(dma_read_desc_dma_addr),
    .s_axis_read_desc_ram_sel(dma_read_desc_ram_sel),
    .s_axis_read_desc_ram_addr(dma_read_desc_ram_addr),
    .s_axis_read_desc_len(dma_read_desc_len),
    .s_axis_read_desc_tag(dma_read_desc_tag),
    .s_axis_read_desc_valid(dma_read_desc_valid),
    .s_axis_read_desc_ready(dma_read_desc_ready),

    /*
     * AXI read descriptor status output
     */
    .m_axis_read_desc_status_tag(dma_read_desc_status_tag),
    .m_axis_read_desc_status_error(dma_read_desc_status_error),
    .m_axis_read_desc_status_valid(dma_read_desc_status_valid),

    /*
     * AXI write descriptor input
     */
    .s_axis_write_desc_axi_addr(dma_write_desc_dma_addr),
    .s_axis_write_desc_ram_sel(dma_write_desc_ram_sel),
    .s_axis_write_desc_ram_addr(dma_write_desc_ram_addr),
    .s_axis_write_desc_len(dma_write_desc_len),
    .s_axis_write_desc_tag(dma_write_desc_tag),
    .s_axis_write_desc_valid(dma_write_desc_valid),
    .s_axis_write_desc_ready(dma_write_desc_ready),

    /*
     * AXI write descriptor status output
     */
    .m_axis_write_desc_status_tag(dma_write_desc_status_tag),
    .m_axis_write_desc_status_error(dma_write_desc_status_error),
    .m_axis_write_desc_status_valid(dma_write_desc_status_valid),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .ram_wr_done(dma_ram_wr_done),
    .ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .ram_rd_resp_data(dma_ram_rd_resp_data),
    .ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * Configuration
     */
    .read_enable(dma_enable),
    .write_enable(dma_enable)
);

mqnic_core #(
    // FW and board IDs
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),

    // Structural configuration
    .IF_COUNT(IF_COUNT),
    .PORTS_PER_IF(PORTS_PER_IF),

    .PORT_COUNT(PORT_COUNT),

    // PTP configuration
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TAG_WIDTH(PTP_TAG_WIDTH),
    .PTP_PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .PTP_OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .PTP_FNS_WIDTH(PTP_FNS_WIDTH),
    .PTP_PERIOD_NS(PTP_PERIOD_NS),
    .PTP_PERIOD_FNS(PTP_PERIOD_FNS),
    .PTP_USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK),
    .PTP_SEPARATE_RX_CLOCK(PTP_SEPARATE_RX_CLOCK),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),

    // Queue manager configuration (interface)
    .EVENT_QUEUE_OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .TX_QUEUE_OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .RX_QUEUE_OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .TX_CPL_QUEUE_OP_TABLE_SIZE(TX_CPL_QUEUE_OP_TABLE_SIZE),
    .RX_CPL_QUEUE_OP_TABLE_SIZE(RX_CPL_QUEUE_OP_TABLE_SIZE),
    .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_QUEUE_PIPELINE(EVENT_QUEUE_PIPELINE),
    .TX_QUEUE_PIPELINE(TX_QUEUE_PIPELINE),
    .RX_QUEUE_PIPELINE(RX_QUEUE_PIPELINE),
    .TX_CPL_QUEUE_PIPELINE(TX_CPL_QUEUE_PIPELINE),
    .RX_CPL_QUEUE_PIPELINE(RX_CPL_QUEUE_PIPELINE),

    // TX and RX engine configuration (port)
    .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
    .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),

    // Scheduler configuration (port)
    .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
    .TX_SCHEDULER_PIPELINE(TX_SCHEDULER_PIPELINE),
    .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),

    // Timestamping configuration (port)
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .TX_PTP_TS_FIFO_DEPTH(TX_PTP_TS_FIFO_DEPTH),
    .RX_PTP_TS_FIFO_DEPTH(RX_PTP_TS_FIFO_DEPTH),

    // Interface configuration (port)
    .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
    .RX_RSS_ENABLE(RX_RSS_ENABLE),
    .RX_HASH_ENABLE(RX_HASH_ENABLE),
    .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .MAX_TX_SIZE(MAX_TX_SIZE),
    .MAX_RX_SIZE(MAX_RX_SIZE),
    .TX_RAM_SIZE(TX_RAM_SIZE),
    .RX_RAM_SIZE(RX_RAM_SIZE),

    // Application block configuration
    .APP_ENABLE(APP_ENABLE),
    .APP_CTRL_ENABLE(APP_CTRL_ENABLE),
    .APP_DMA_ENABLE(APP_DMA_ENABLE),
    .APP_AXIS_DIRECT_ENABLE(APP_AXIS_DIRECT_ENABLE),
    .APP_AXIS_SYNC_ENABLE(APP_AXIS_SYNC_ENABLE),
    .APP_AXIS_IF_ENABLE(APP_AXIS_IF_ENABLE),
    .APP_STAT_ENABLE(APP_STAT_ENABLE),

    // DMA interface configuration
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .IF_RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),

    .MSI_COUNT(IRQ_COUNT),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_WIDTH(AXIL_CTRL_DATA_WIDTH),
    .AXIL_CTRL_ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .AXIL_CTRL_STRB_WIDTH(AXIL_CTRL_STRB_WIDTH),
    .AXIL_IF_CTRL_ADDR_WIDTH(AXIL_IF_CTRL_ADDR_WIDTH),
    .AXIL_CSR_ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .AXIL_CSR_PASSTHROUGH_ENABLE(AXIL_CSR_PASSTHROUGH_ENABLE),

    // AXI lite interface configuration (application control)
    .AXIL_APP_CTRL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .AXIL_APP_CTRL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),
    .AXIL_APP_CTRL_STRB_WIDTH(AXIL_APP_CTRL_STRB_WIDTH),

    // Ethernet interface configuration
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_SYNC_DATA_WIDTH(AXIS_SYNC_DATA_WIDTH),
    .AXIS_TX_USER_WIDTH(AXIS_TX_USER_WIDTH),
    .AXIS_RX_USER_WIDTH(AXIS_RX_USER_WIDTH),
    .AXIS_RX_USE_READY(AXIS_RX_USE_READY),
    .AXIS_TX_PIPELINE(AXIS_TX_PIPELINE),
    .AXIS_TX_FIFO_PIPELINE(AXIS_TX_FIFO_PIPELINE),
    .AXIS_TX_TS_PIPELINE(AXIS_TX_TS_PIPELINE),
    .AXIS_RX_PIPELINE(AXIS_RX_PIPELINE),
    .AXIS_RX_FIFO_PIPELINE(AXIS_RX_FIFO_PIPELINE),

    // Statistics counter subsystem
    .STAT_ENABLE(STAT_ENABLE),
    .STAT_INC_WIDTH(STAT_INC_WIDTH),
    .STAT_ID_WIDTH(STAT_ID_WIDTH)
)
core_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA read descriptor output
     */
    .m_axis_dma_read_desc_dma_addr(dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_sel(dma_read_desc_ram_sel),
    .m_axis_dma_read_desc_ram_addr(dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(dma_read_desc_len),
    .m_axis_dma_read_desc_tag(dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(dma_read_desc_ready),

    /*
     * DMA read descriptor status input
     */
    .s_axis_dma_read_desc_status_tag(dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(dma_read_desc_status_valid),

    /*
     * DMA write descriptor output
     */
    .m_axis_dma_write_desc_dma_addr(dma_write_desc_dma_addr),
    .m_axis_dma_write_desc_ram_sel(dma_write_desc_ram_sel),
    .m_axis_dma_write_desc_ram_addr(dma_write_desc_ram_addr),
    .m_axis_dma_write_desc_len(dma_write_desc_len),
    .m_axis_dma_write_desc_tag(dma_write_desc_tag),
    .m_axis_dma_write_desc_valid(dma_write_desc_valid),
    .m_axis_dma_write_desc_ready(dma_write_desc_ready),

    /*
     * DMA write descriptor status input
     */
    .s_axis_dma_write_desc_status_tag(dma_write_desc_status_tag),
    .s_axis_dma_write_desc_status_error(dma_write_desc_status_error),
    .s_axis_dma_write_desc_status_valid(dma_write_desc_status_valid),

    /*
     * AXI-Lite slave interface (control)
     */
    .s_axil_ctrl_awaddr(s_axil_ctrl_awaddr),
    .s_axil_ctrl_awprot(s_axil_ctrl_awprot),
    .s_axil_ctrl_awvalid(s_axil_ctrl_awvalid),
    .s_axil_ctrl_awready(s_axil_ctrl_awready),
    .s_axil_ctrl_wdata(s_axil_ctrl_wdata),
    .s_axil_ctrl_wstrb(s_axil_ctrl_wstrb),
    .s_axil_ctrl_wvalid(s_axil_ctrl_wvalid),
    .s_axil_ctrl_wready(s_axil_ctrl_wready),
    .s_axil_ctrl_bresp(s_axil_ctrl_bresp),
    .s_axil_ctrl_bvalid(s_axil_ctrl_bvalid),
    .s_axil_ctrl_bready(s_axil_ctrl_bready),
    .s_axil_ctrl_araddr(s_axil_ctrl_araddr),
    .s_axil_ctrl_arprot(s_axil_ctrl_arprot),
    .s_axil_ctrl_arvalid(s_axil_ctrl_arvalid),
    .s_axil_ctrl_arready(s_axil_ctrl_arready),
    .s_axil_ctrl_rdata(s_axil_ctrl_rdata),
    .s_axil_ctrl_rresp(s_axil_ctrl_rresp),
    .s_axil_ctrl_rvalid(s_axil_ctrl_rvalid),
    .s_axil_ctrl_rready(s_axil_ctrl_rready),

    /*
     * AXI-Lite slave interface (application control)
     */
    .s_axil_app_ctrl_awaddr(s_axil_app_ctrl_awaddr),
    .s_axil_app_ctrl_awprot(s_axil_app_ctrl_awprot),
    .s_axil_app_ctrl_awvalid(s_axil_app_ctrl_awvalid),
    .s_axil_app_ctrl_awready(s_axil_app_ctrl_awready),
    .s_axil_app_ctrl_wdata(s_axil_app_ctrl_wdata),
    .s_axil_app_ctrl_wstrb(s_axil_app_ctrl_wstrb),
    .s_axil_app_ctrl_wvalid(s_axil_app_ctrl_wvalid),
    .s_axil_app_ctrl_wready(s_axil_app_ctrl_wready),
    .s_axil_app_ctrl_bresp(s_axil_app_ctrl_bresp),
    .s_axil_app_ctrl_bvalid(s_axil_app_ctrl_bvalid),
    .s_axil_app_ctrl_bready(s_axil_app_ctrl_bready),
    .s_axil_app_ctrl_araddr(s_axil_app_ctrl_araddr),
    .s_axil_app_ctrl_arprot(s_axil_app_ctrl_arprot),
    .s_axil_app_ctrl_arvalid(s_axil_app_ctrl_arvalid),
    .s_axil_app_ctrl_arready(s_axil_app_ctrl_arready),
    .s_axil_app_ctrl_rdata(s_axil_app_ctrl_rdata),
    .s_axil_app_ctrl_rresp(s_axil_app_ctrl_rresp),
    .s_axil_app_ctrl_rvalid(s_axil_app_ctrl_rvalid),
    .s_axil_app_ctrl_rready(s_axil_app_ctrl_rready),

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    .m_axil_csr_awaddr(m_axil_csr_awaddr),
    .m_axil_csr_awprot(m_axil_csr_awprot),
    .m_axil_csr_awvalid(m_axil_csr_awvalid),
    .m_axil_csr_awready(m_axil_csr_awready),
    .m_axil_csr_wdata(m_axil_csr_wdata),
    .m_axil_csr_wstrb(m_axil_csr_wstrb),
    .m_axil_csr_wvalid(m_axil_csr_wvalid),
    .m_axil_csr_wready(m_axil_csr_wready),
    .m_axil_csr_bresp(m_axil_csr_bresp),
    .m_axil_csr_bvalid(m_axil_csr_bvalid),
    .m_axil_csr_bready(m_axil_csr_bready),
    .m_axil_csr_araddr(m_axil_csr_araddr),
    .m_axil_csr_arprot(m_axil_csr_arprot),
    .m_axil_csr_arvalid(m_axil_csr_arvalid),
    .m_axil_csr_arready(m_axil_csr_arready),
    .m_axil_csr_rdata(m_axil_csr_rdata),
    .m_axil_csr_rresp(m_axil_csr_rresp),
    .m_axil_csr_rvalid(m_axil_csr_rvalid),
    .m_axil_csr_rready(m_axil_csr_rready),

    /*
     * Control register interface
     */
    .ctrl_reg_wr_addr(ctrl_reg_wr_addr),
    .ctrl_reg_wr_data(ctrl_reg_wr_data),
    .ctrl_reg_wr_strb(ctrl_reg_wr_strb),
    .ctrl_reg_wr_en(ctrl_reg_wr_en),
    .ctrl_reg_wr_wait(ctrl_reg_wr_wait),
    .ctrl_reg_wr_ack(ctrl_reg_wr_ack),
    .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
    .ctrl_reg_rd_en(ctrl_reg_rd_en),
    .ctrl_reg_rd_data(ctrl_reg_rd_data),
    .ctrl_reg_rd_wait(ctrl_reg_rd_wait),
    .ctrl_reg_rd_ack(ctrl_reg_rd_ack),

    /*
     * RAM interface
     */
    .dma_ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .dma_ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .dma_ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .dma_ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .dma_ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .dma_ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .dma_ram_wr_done(dma_ram_wr_done),
    .dma_ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .dma_ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .dma_ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .dma_ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .dma_ram_rd_resp_data(dma_ram_rd_resp_data),
    .dma_ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .dma_ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * MSI request outputs
     */
    .msi_irq(irq),

    /*
     * PTP clock
     */
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_pps(ptp_pps),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step),
    .ptp_perout_locked(ptp_perout_locked),
    .ptp_perout_error(ptp_perout_error),
    .ptp_perout_pulse(ptp_perout_pulse),

    /*
     * Ethernet
     */
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),

    .tx_ptp_ts_96(tx_ptp_ts_96),
    .tx_ptp_ts_step(tx_ptp_ts_step),

    .m_axis_tx_tdata(m_axis_tx_tdata),
    .m_axis_tx_tkeep(m_axis_tx_tkeep),
    .m_axis_tx_tvalid(m_axis_tx_tvalid),
    .m_axis_tx_tready(m_axis_tx_tready),
    .m_axis_tx_tlast(m_axis_tx_tlast),
    .m_axis_tx_tuser(m_axis_tx_tuser),

    .s_axis_tx_ptp_ts(s_axis_tx_ptp_ts),
    .s_axis_tx_ptp_ts_tag(s_axis_tx_ptp_ts_tag),
    .s_axis_tx_ptp_ts_valid(s_axis_tx_ptp_ts_valid),
    .s_axis_tx_ptp_ts_ready(s_axis_tx_ptp_ts_ready),

    .rx_clk(rx_clk),
    .rx_rst(rx_rst),

    .rx_ptp_clk(rx_ptp_clk),
    .rx_ptp_rst(rx_ptp_rst),
    .rx_ptp_ts_96(rx_ptp_ts_96),
    .rx_ptp_ts_step(rx_ptp_ts_step),

    .s_axis_rx_tdata(s_axis_rx_tdata),
    .s_axis_rx_tkeep(s_axis_rx_tkeep),
    .s_axis_rx_tvalid(s_axis_rx_tvalid),
    .s_axis_rx_tready(s_axis_rx_tready),
    .s_axis_rx_tlast(s_axis_rx_tlast),
    .s_axis_rx_tuser(s_axis_rx_tuser),

    /*
     * Statistics input
     */
    .s_axis_stat_tdata(s_axis_stat_tdata),
    .s_axis_stat_tid(s_axis_stat_tid),
    .s_axis_stat_tvalid(s_axis_stat_tvalid),
    .s_axis_stat_tready(s_axis_stat_tready)
);

endmodule

`resetall
