/*

Copyright 2019, The Regents of the University of California.
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

`timescale 1ns / 1ps

/*
 * NIC Interface
 */
module interface #
(
    // Number of ports
    parameter PORTS = 1,
    // PCIe address width
    parameter PCIE_ADDR_WIDTH = 64,
    // PCIe DMA length field width
    parameter PCIE_DMA_LEN_WIDTH = 16,
    // PCIe DMA tag field width
    parameter PCIE_DMA_TAG_WIDTH = 8,
    // Request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Number of outstanding operations (event queue)
    parameter EVENT_QUEUE_OP_TABLE_SIZE = 16,
    // Number of outstanding operations (transmit queue)
    parameter TX_QUEUE_OP_TABLE_SIZE = 16,
    // Number of outstanding operations (receive queue)
    parameter RX_QUEUE_OP_TABLE_SIZE = 16,
    // Number of outstanding operations (transmit completion queue)
    parameter TX_CPL_QUEUE_OP_TABLE_SIZE = 16,
    // Number of outstanding operations (receive completion queue)
    parameter RX_CPL_QUEUE_OP_TABLE_SIZE = 16,
    // Queue request tag field width
    parameter QUEUE_REQ_TAG_WIDTH = 8,
    // Queue operation tag field width
    parameter QUEUE_OP_TAG_WIDTH = 8,
    // Event queue index width
    parameter EVENT_QUEUE_INDEX_WIDTH = 5,
    // Transmit queue index width
    parameter TX_QUEUE_INDEX_WIDTH = 8,
    // Receive queue index width
    parameter RX_QUEUE_INDEX_WIDTH = 8,
    // Transmit completion queue index width
    parameter TX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Receive completion queue index width
    parameter RX_CPL_QUEUE_INDEX_WIDTH = 8,
    // Transmit descriptor table size (number of in-flight operations)
    parameter TX_DESC_TABLE_SIZE = 16,
    // Transmit packet table size (number of in-progress packets)
    parameter TX_PKT_TABLE_SIZE = 8,
    // Receive descriptor table size (number of in-flight operations)
    parameter RX_DESC_TABLE_SIZE = 16,
    // Receive packet table size (number of in-progress packets)
    parameter RX_PKT_TABLE_SIZE = 8,
    // Transmit scheduler type
    parameter TX_SCHEDULER = "RR",
    // Scheduler operation table size
    parameter TX_SCHEDULER_OP_TABLE_SIZE = 32,
    // Scheduler TDMA index width
    parameter TDMA_INDEX_WIDTH = 8,
    // Interrupt number width
    parameter INT_WIDTH = 8,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Queue log size field width
    parameter QUEUE_LOG_SIZE_WIDTH = 4,
    // RAM internal address width
    parameter RAM_ADDR_WIDTH = 16,
    // Packet scratch RAM size
    parameter RAM_SIZE = 2**14,
    // Enable PTP timestamping
    parameter PTP_TS_ENABLE = 1,
    // PTP timestamp width
    parameter PTP_TS_WIDTH = 96,
    // Enable TX checksum offload
    parameter TX_CHECKSUM_ENABLE = 1,
    // Enable RX checksum offload
    parameter RX_CHECKSUM_ENABLE = 1,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 256,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
    // AXI base address of this module (as seen by PCIe DMA)
    parameter AXI_BASE_ADDR = 0,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXI_STRB_WIDTH
)
(
    input  wire                               clk,
    input  wire                               rst,

    /*
     * PCIe read descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]         m_axis_pcie_axi_dma_read_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axis_pcie_axi_dma_read_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]      m_axis_pcie_axi_dma_read_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]      m_axis_pcie_axi_dma_read_desc_tag,
    output wire                               m_axis_pcie_axi_dma_read_desc_valid,
    input  wire                               m_axis_pcie_axi_dma_read_desc_ready,

    /*
     * PCIe read descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]      s_axis_pcie_axi_dma_read_desc_status_tag,
    input  wire                               s_axis_pcie_axi_dma_read_desc_status_valid,

    /*
     * PCIe write descriptor output
     */
    output wire [PCIE_ADDR_WIDTH-1:0]         m_axis_pcie_axi_dma_write_desc_pcie_addr,
    output wire [AXI_ADDR_WIDTH-1:0]          m_axis_pcie_axi_dma_write_desc_axi_addr,
    output wire [PCIE_DMA_LEN_WIDTH-1:0]      m_axis_pcie_axi_dma_write_desc_len,
    output wire [PCIE_DMA_TAG_WIDTH-1:0]      m_axis_pcie_axi_dma_write_desc_tag,
    output wire                               m_axis_pcie_axi_dma_write_desc_valid,
    input  wire                               m_axis_pcie_axi_dma_write_desc_ready,

    /*
     * PCIe write descriptor status input
     */
    input  wire [PCIE_DMA_TAG_WIDTH-1:0]      s_axis_pcie_axi_dma_write_desc_status_tag,
    input  wire                               s_axis_pcie_axi_dma_write_desc_status_valid,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]         s_axil_awaddr,
    input  wire [2:0]                         s_axil_awprot,
    input  wire                               s_axil_awvalid,
    output wire                               s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]         s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]         s_axil_wstrb,
    input  wire                               s_axil_wvalid,
    output wire                               s_axil_wready,
    output wire [1:0]                         s_axil_bresp,
    output wire                               s_axil_bvalid,
    input  wire                               s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]         s_axil_araddr,
    input  wire [2:0]                         s_axil_arprot,
    input  wire                               s_axil_arvalid,
    output wire                               s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]         s_axil_rdata,
    output wire [1:0]                         s_axil_rresp,
    output wire                               s_axil_rvalid,
    input  wire                               s_axil_rready,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_ADDR_WIDTH-1:0]         m_axil_csr_awaddr,
    output wire [2:0]                         m_axil_csr_awprot,
    output wire                               m_axil_csr_awvalid,
    input  wire                               m_axil_csr_awready,
    output wire [AXIL_DATA_WIDTH-1:0]         m_axil_csr_wdata,
    output wire [AXIL_STRB_WIDTH-1:0]         m_axil_csr_wstrb,
    output wire                               m_axil_csr_wvalid,
    input  wire                               m_axil_csr_wready,
    input  wire [1:0]                         m_axil_csr_bresp,
    input  wire                               m_axil_csr_bvalid,
    output wire                               m_axil_csr_bready,
    output wire [AXIL_ADDR_WIDTH-1:0]         m_axil_csr_araddr,
    output wire [2:0]                         m_axil_csr_arprot,
    output wire                               m_axil_csr_arvalid,
    input  wire                               m_axil_csr_arready,
    input  wire [AXIL_DATA_WIDTH-1:0]         m_axil_csr_rdata,
    input  wire [1:0]                         m_axil_csr_rresp,
    input  wire                               m_axil_csr_rvalid,
    output wire                               m_axil_csr_rready,

    /*
     * AXI slave inteface
     */
    input  wire [AXI_ID_WIDTH-1:0]            s_axi_awid,
    input  wire [AXI_ADDR_WIDTH-1:0]          s_axi_awaddr,
    input  wire [7:0]                         s_axi_awlen,
    input  wire [2:0]                         s_axi_awsize,
    input  wire [1:0]                         s_axi_awburst,
    input  wire                               s_axi_awlock,
    input  wire [3:0]                         s_axi_awcache,
    input  wire [2:0]                         s_axi_awprot,
    input  wire                               s_axi_awvalid,
    output wire                               s_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]          s_axi_wdata,
    input  wire [AXI_STRB_WIDTH-1:0]          s_axi_wstrb,
    input  wire                               s_axi_wlast,
    input  wire                               s_axi_wvalid,
    output wire                               s_axi_wready,
    output wire [AXI_ID_WIDTH-1:0]            s_axi_bid,
    output wire [1:0]                         s_axi_bresp,
    output wire                               s_axi_bvalid,
    input  wire                               s_axi_bready,
    input  wire [AXI_ID_WIDTH-1:0]            s_axi_arid,
    input  wire [AXI_ADDR_WIDTH-1:0]          s_axi_araddr,
    input  wire [7:0]                         s_axi_arlen,
    input  wire [2:0]                         s_axi_arsize,
    input  wire [1:0]                         s_axi_arburst,
    input  wire                               s_axi_arlock,
    input  wire [3:0]                         s_axi_arcache,
    input  wire [2:0]                         s_axi_arprot,
    input  wire                               s_axi_arvalid,
    output wire                               s_axi_arready,
    output wire [AXI_ID_WIDTH-1:0]            s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]          s_axi_rdata,
    output wire [1:0]                         s_axi_rresp,
    output wire                               s_axi_rlast,
    output wire                               s_axi_rvalid,
    input  wire                               s_axi_rready,

    /*
     * Transmit data output
     */
    output wire [PORTS*AXIS_DATA_WIDTH-1:0]   tx_axis_tdata,
    output wire [PORTS*AXIS_KEEP_WIDTH-1:0]   tx_axis_tkeep,
    output wire [PORTS-1:0]                   tx_axis_tvalid,
    input  wire [PORTS-1:0]                   tx_axis_tready,
    output wire [PORTS-1:0]                   tx_axis_tlast,
    output wire [PORTS-1:0]                   tx_axis_tuser,

    /*
     * Transmit timestamp input
     */
    input  wire [PORTS*PTP_TS_WIDTH-1:0]      s_axis_tx_ptp_ts_96,
    input  wire [PORTS-1:0]                   s_axis_tx_ptp_ts_valid,
    output wire [PORTS-1:0]                   s_axis_tx_ptp_ts_ready,

    /*
     * Receive data input
     */
    input  wire [PORTS*AXIS_DATA_WIDTH-1:0]   rx_axis_tdata,
    input  wire [PORTS*AXIS_KEEP_WIDTH-1:0]   rx_axis_tkeep,
    input  wire [PORTS-1:0]                   rx_axis_tvalid,
    output wire [PORTS-1:0]                   rx_axis_tready,
    input  wire [PORTS-1:0]                   rx_axis_tlast,
    input  wire [PORTS-1:0]                   rx_axis_tuser,

    /*
     * Receive timestamp input
     */
    input  wire [PORTS*PTP_TS_WIDTH-1:0]      s_axis_rx_ptp_ts_96,
    input  wire [PORTS-1:0]                   s_axis_rx_ptp_ts_valid,
    output wire [PORTS-1:0]                   s_axis_rx_ptp_ts_ready,

    /*
     * PTP clock
     */
    input  wire [95:0]                        ptp_ts_96,
    input  wire                               ptp_ts_step,

    /*
     * MSI interrupts
     */
    output wire [31:0]                        msi_irq
);

parameter DESC_SIZE = 16;
parameter CPL_SIZE = 32;
parameter EVENT_SIZE = 32;

parameter EVENT_SOURCE_WIDTH = 16;
parameter EVENT_TYPE_WIDTH = 16;

parameter PCIE_DMA_TAG_WIDTH_INT = PCIE_DMA_TAG_WIDTH - $clog2(PORTS+1);

// AXI lite connections
wire [AXIL_ADDR_WIDTH-1:0] axil_ctrl_awaddr;
wire [2:0]                 axil_ctrl_awprot;
wire                       axil_ctrl_awvalid;
wire                       axil_ctrl_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_ctrl_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_ctrl_wstrb;
wire                       axil_ctrl_wvalid;
wire                       axil_ctrl_wready;
wire [1:0]                 axil_ctrl_bresp;
wire                       axil_ctrl_bvalid;
wire                       axil_ctrl_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_ctrl_araddr;
wire [2:0]                 axil_ctrl_arprot;
wire                       axil_ctrl_arvalid;
wire                       axil_ctrl_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_ctrl_rdata;
wire [1:0]                 axil_ctrl_rresp;
wire                       axil_ctrl_rvalid;
wire                       axil_ctrl_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_event_queue_manager_awaddr;
wire [2:0]                 axil_event_queue_manager_awprot;
wire                       axil_event_queue_manager_awvalid;
wire                       axil_event_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_event_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_event_queue_manager_wstrb;
wire                       axil_event_queue_manager_wvalid;
wire                       axil_event_queue_manager_wready;
wire [1:0]                 axil_event_queue_manager_bresp;
wire                       axil_event_queue_manager_bvalid;
wire                       axil_event_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_event_queue_manager_araddr;
wire [2:0]                 axil_event_queue_manager_arprot;
wire                       axil_event_queue_manager_arvalid;
wire                       axil_event_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_event_queue_manager_rdata;
wire [1:0]                 axil_event_queue_manager_rresp;
wire                       axil_event_queue_manager_rvalid;
wire                       axil_event_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_tx_queue_manager_awaddr;
wire [2:0]                 axil_tx_queue_manager_awprot;
wire                       axil_tx_queue_manager_awvalid;
wire                       axil_tx_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_tx_queue_manager_wstrb;
wire                       axil_tx_queue_manager_wvalid;
wire                       axil_tx_queue_manager_wready;
wire [1:0]                 axil_tx_queue_manager_bresp;
wire                       axil_tx_queue_manager_bvalid;
wire                       axil_tx_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_tx_queue_manager_araddr;
wire [2:0]                 axil_tx_queue_manager_arprot;
wire                       axil_tx_queue_manager_arvalid;
wire                       axil_tx_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_queue_manager_rdata;
wire [1:0]                 axil_tx_queue_manager_rresp;
wire                       axil_tx_queue_manager_rvalid;
wire                       axil_tx_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_tx_cpl_queue_manager_awaddr;
wire [2:0]                 axil_tx_cpl_queue_manager_awprot;
wire                       axil_tx_cpl_queue_manager_awvalid;
wire                       axil_tx_cpl_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_cpl_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_tx_cpl_queue_manager_wstrb;
wire                       axil_tx_cpl_queue_manager_wvalid;
wire                       axil_tx_cpl_queue_manager_wready;
wire [1:0]                 axil_tx_cpl_queue_manager_bresp;
wire                       axil_tx_cpl_queue_manager_bvalid;
wire                       axil_tx_cpl_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_tx_cpl_queue_manager_araddr;
wire [2:0]                 axil_tx_cpl_queue_manager_arprot;
wire                       axil_tx_cpl_queue_manager_arvalid;
wire                       axil_tx_cpl_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_tx_cpl_queue_manager_rdata;
wire [1:0]                 axil_tx_cpl_queue_manager_rresp;
wire                       axil_tx_cpl_queue_manager_rvalid;
wire                       axil_tx_cpl_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_rx_queue_manager_awaddr;
wire [2:0]                 axil_rx_queue_manager_awprot;
wire                       axil_rx_queue_manager_awvalid;
wire                       axil_rx_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_rx_queue_manager_wstrb;
wire                       axil_rx_queue_manager_wvalid;
wire                       axil_rx_queue_manager_wready;
wire [1:0]                 axil_rx_queue_manager_bresp;
wire                       axil_rx_queue_manager_bvalid;
wire                       axil_rx_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_rx_queue_manager_araddr;
wire [2:0]                 axil_rx_queue_manager_arprot;
wire                       axil_rx_queue_manager_arvalid;
wire                       axil_rx_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_queue_manager_rdata;
wire [1:0]                 axil_rx_queue_manager_rresp;
wire                       axil_rx_queue_manager_rvalid;
wire                       axil_rx_queue_manager_rready;

wire [AXIL_ADDR_WIDTH-1:0] axil_rx_cpl_queue_manager_awaddr;
wire [2:0]                 axil_rx_cpl_queue_manager_awprot;
wire                       axil_rx_cpl_queue_manager_awvalid;
wire                       axil_rx_cpl_queue_manager_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_cpl_queue_manager_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_rx_cpl_queue_manager_wstrb;
wire                       axil_rx_cpl_queue_manager_wvalid;
wire                       axil_rx_cpl_queue_manager_wready;
wire [1:0]                 axil_rx_cpl_queue_manager_bresp;
wire                       axil_rx_cpl_queue_manager_bvalid;
wire                       axil_rx_cpl_queue_manager_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_rx_cpl_queue_manager_araddr;
wire [2:0]                 axil_rx_cpl_queue_manager_arprot;
wire                       axil_rx_cpl_queue_manager_arvalid;
wire                       axil_rx_cpl_queue_manager_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_rx_cpl_queue_manager_rdata;
wire [1:0]                 axil_rx_cpl_queue_manager_rresp;
wire                       axil_rx_cpl_queue_manager_rvalid;
wire                       axil_rx_cpl_queue_manager_rready;

wire [PORTS*AXIL_ADDR_WIDTH-1:0] axil_port_awaddr;
wire [PORTS*3-1:0]               axil_port_awprot;
wire [PORTS-1:0]                 axil_port_awvalid;
wire [PORTS-1:0]                 axil_port_awready;
wire [PORTS*AXIL_DATA_WIDTH-1:0] axil_port_wdata;
wire [PORTS*AXIL_STRB_WIDTH-1:0] axil_port_wstrb;
wire [PORTS-1:0]                 axil_port_wvalid;
wire [PORTS-1:0]                 axil_port_wready;
wire [PORTS*2-1:0]               axil_port_bresp;
wire [PORTS-1:0]                 axil_port_bvalid;
wire [PORTS-1:0]                 axil_port_bready;
wire [PORTS*AXIL_ADDR_WIDTH-1:0] axil_port_araddr;
wire [PORTS*3-1:0]               axil_port_arprot;
wire [PORTS-1:0]                 axil_port_arvalid;
wire [PORTS-1:0]                 axil_port_arready;
wire [PORTS*AXIL_DATA_WIDTH-1:0] axil_port_rdata;
wire [PORTS*2-1:0]               axil_port_rresp;
wire [PORTS-1:0]                 axil_port_rvalid;
wire [PORTS-1:0]                 axil_port_rready;

// AXI connections
wire [AXI_ID_WIDTH-1:0]    axi_event_awid;
wire [AXI_ADDR_WIDTH-1:0]  axi_event_awaddr;
wire [7:0]                 axi_event_awlen;
wire [2:0]                 axi_event_awsize;
wire [1:0]                 axi_event_awburst;
wire                       axi_event_awlock;
wire [3:0]                 axi_event_awcache;
wire [2:0]                 axi_event_awprot;
wire                       axi_event_awvalid;
wire                       axi_event_awready;
wire [AXI_DATA_WIDTH-1:0]  axi_event_wdata;
wire [AXI_STRB_WIDTH-1:0]  axi_event_wstrb;
wire                       axi_event_wlast;
wire                       axi_event_wvalid;
wire                       axi_event_wready;
wire [AXI_ID_WIDTH-1:0]    axi_event_bid;
wire [1:0]                 axi_event_bresp;
wire                       axi_event_bvalid;
wire                       axi_event_bready;
wire [AXI_ID_WIDTH-1:0]    axi_event_arid;
wire [AXI_ADDR_WIDTH-1:0]  axi_event_araddr;
wire [7:0]                 axi_event_arlen;
wire [2:0]                 axi_event_arsize;
wire [1:0]                 axi_event_arburst;
wire                       axi_event_arlock;
wire [3:0]                 axi_event_arcache;
wire [2:0]                 axi_event_arprot;
wire                       axi_event_arvalid;
wire                       axi_event_arready;
wire [AXI_ID_WIDTH-1:0]    axi_event_rid;
wire [AXI_DATA_WIDTH-1:0]  axi_event_rdata;
wire [1:0]                 axi_event_rresp;
wire                       axi_event_rlast;
wire                       axi_event_rvalid;
wire                       axi_event_rready;

// PCIe DMA
wire [PCIE_ADDR_WIDTH-1:0]        event_pcie_axi_dma_write_desc_pcie_addr;
wire [AXI_ADDR_WIDTH-1:0]         event_pcie_axi_dma_write_desc_axi_addr;
wire [PCIE_DMA_LEN_WIDTH-1:0]     event_pcie_axi_dma_write_desc_len;
wire [PCIE_DMA_TAG_WIDTH_INT-1:0] event_pcie_axi_dma_write_desc_tag;
wire                              event_pcie_axi_dma_write_desc_valid;
wire                              event_pcie_axi_dma_write_desc_ready;

wire [PCIE_DMA_TAG_WIDTH_INT-1:0] event_pcie_axi_dma_write_desc_status_tag;
wire                              event_pcie_axi_dma_write_desc_status_valid;

wire [PORTS*PCIE_ADDR_WIDTH-1:0]        port_pcie_axi_dma_read_desc_pcie_addr;
wire [PORTS*AXI_ADDR_WIDTH-1:0]         port_pcie_axi_dma_read_desc_axi_addr;
wire [PORTS*PCIE_DMA_LEN_WIDTH-1:0]     port_pcie_axi_dma_read_desc_len;
wire [PORTS*PCIE_DMA_TAG_WIDTH_INT-1:0] port_pcie_axi_dma_read_desc_tag;
wire [PORTS-1:0]                        port_pcie_axi_dma_read_desc_valid;
wire [PORTS-1:0]                        port_pcie_axi_dma_read_desc_ready;

wire [PORTS*PCIE_DMA_TAG_WIDTH_INT-1:0] port_pcie_axi_dma_read_desc_status_tag;
wire [PORTS-1:0]                        port_pcie_axi_dma_read_desc_status_valid;

wire [PORTS*PCIE_ADDR_WIDTH-1:0]        port_pcie_axi_dma_write_desc_pcie_addr;
wire [PORTS*AXI_ADDR_WIDTH-1:0]         port_pcie_axi_dma_write_desc_axi_addr;
wire [PORTS*PCIE_DMA_LEN_WIDTH-1:0]     port_pcie_axi_dma_write_desc_len;
wire [PORTS*PCIE_DMA_TAG_WIDTH_INT-1:0] port_pcie_axi_dma_write_desc_tag;
wire [PORTS-1:0]                        port_pcie_axi_dma_write_desc_valid;
wire [PORTS-1:0]                        port_pcie_axi_dma_write_desc_ready;

wire [PORTS*PCIE_DMA_TAG_WIDTH_INT-1:0] port_pcie_axi_dma_write_desc_status_tag;
wire [PORTS-1:0]                        port_pcie_axi_dma_write_desc_status_valid;

// Queue management
wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  event_enqueue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      event_enqueue_req_tag;
wire                                event_enqueue_req_valid;
wire                                event_enqueue_req_ready;

wire [PCIE_ADDR_WIDTH-1:0]          event_enqueue_resp_addr;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      event_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       event_enqueue_resp_op_tag;
wire                                event_enqueue_resp_full;
wire                                event_enqueue_resp_error;
wire                                event_enqueue_resp_valid;
wire                                event_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       event_enqueue_commit_op_tag;
wire                                event_enqueue_commit_valid;
wire                                event_enqueue_commit_ready;

wire [TX_QUEUE_INDEX_WIDTH-1:0]     tx_desc_dequeue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_desc_dequeue_req_tag;
wire                                tx_desc_dequeue_req_valid;
wire                                tx_desc_dequeue_req_ready;

wire [QUEUE_PTR_WIDTH-1:0]          tx_desc_dequeue_resp_ptr;
wire [PCIE_ADDR_WIDTH-1:0]          tx_desc_dequeue_resp_addr;
wire [TX_CPL_QUEUE_INDEX_WIDTH-1:0] tx_desc_dequeue_resp_cpl;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_desc_dequeue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_desc_dequeue_resp_op_tag;
wire                                tx_desc_dequeue_resp_empty;
wire                                tx_desc_dequeue_resp_error;
wire                                tx_desc_dequeue_resp_valid;
wire                                tx_desc_dequeue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_desc_dequeue_commit_op_tag;
wire                                tx_desc_dequeue_commit_valid;
wire                                tx_desc_dequeue_commit_ready;

wire [TX_QUEUE_INDEX_WIDTH-1:0]     tx_doorbell_queue;
wire                                tx_doorbell_valid;

wire [PORTS*TX_QUEUE_INDEX_WIDTH-1:0]     tx_port_desc_dequeue_req_queue;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      tx_port_desc_dequeue_req_tag;
wire [PORTS-1:0]                          tx_port_desc_dequeue_req_valid;
wire [PORTS-1:0]                          tx_port_desc_dequeue_req_ready;

wire [PORTS*QUEUE_PTR_WIDTH-1:0]          tx_port_desc_dequeue_resp_ptr;
wire [PORTS*PCIE_ADDR_WIDTH-1:0]          tx_port_desc_dequeue_resp_addr;
wire [PORTS*TX_CPL_QUEUE_INDEX_WIDTH-1:0] tx_port_desc_dequeue_resp_cpl;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      tx_port_desc_dequeue_resp_tag;
wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       tx_port_desc_dequeue_resp_op_tag;
wire [PORTS-1:0]                          tx_port_desc_dequeue_resp_empty;
wire [PORTS-1:0]                          tx_port_desc_dequeue_resp_error;
wire [PORTS-1:0]                          tx_port_desc_dequeue_resp_valid;
wire [PORTS-1:0]                          tx_port_desc_dequeue_resp_ready;

wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       tx_port_desc_dequeue_commit_op_tag;
wire [PORTS-1:0]                          tx_port_desc_dequeue_commit_valid;
wire [PORTS-1:0]                          tx_port_desc_dequeue_commit_ready;

wire [TX_CPL_QUEUE_INDEX_WIDTH-1:0] tx_cpl_enqueue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_cpl_enqueue_req_tag;
wire                                tx_cpl_enqueue_req_valid;
wire                                tx_cpl_enqueue_req_ready;

wire [PCIE_ADDR_WIDTH-1:0]          tx_cpl_enqueue_resp_addr;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_cpl_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_cpl_enqueue_resp_op_tag;
wire                                tx_cpl_enqueue_resp_full;
wire                                tx_cpl_enqueue_resp_error;
wire                                tx_cpl_enqueue_resp_valid;
wire                                tx_cpl_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_cpl_enqueue_commit_op_tag;
wire                                tx_cpl_enqueue_commit_valid;
wire                                tx_cpl_enqueue_commit_ready;

wire [PORTS*TX_CPL_QUEUE_INDEX_WIDTH-1:0] tx_port_cpl_enqueue_req_queue;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      tx_port_cpl_enqueue_req_tag;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_req_valid;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_req_ready;

wire [PORTS*PCIE_ADDR_WIDTH-1:0]          tx_port_cpl_enqueue_resp_addr;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      tx_port_cpl_enqueue_resp_tag;
wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       tx_port_cpl_enqueue_resp_op_tag;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_resp_full;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_resp_error;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_resp_valid;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_resp_ready;

wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       tx_port_cpl_enqueue_commit_op_tag;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_commit_valid;
wire [PORTS-1:0]                          tx_port_cpl_enqueue_commit_ready;

wire [TX_QUEUE_INDEX_WIDTH-1:0]     rx_desc_dequeue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_desc_dequeue_req_tag;
wire                                rx_desc_dequeue_req_valid;
wire                                rx_desc_dequeue_req_ready;

wire [QUEUE_PTR_WIDTH-1:0]          rx_desc_dequeue_resp_ptr;
wire [PCIE_ADDR_WIDTH-1:0]          rx_desc_dequeue_resp_addr;
wire [RX_CPL_QUEUE_INDEX_WIDTH-1:0] rx_desc_dequeue_resp_cpl;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_desc_dequeue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_desc_dequeue_resp_op_tag;
wire                                rx_desc_dequeue_resp_empty;
wire                                rx_desc_dequeue_resp_error;
wire                                rx_desc_dequeue_resp_valid;
wire                                rx_desc_dequeue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_desc_dequeue_commit_op_tag;
wire                                rx_desc_dequeue_commit_valid;
wire                                rx_desc_dequeue_commit_ready;

wire [PORTS*RX_QUEUE_INDEX_WIDTH-1:0]     rx_port_desc_dequeue_req_queue;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      rx_port_desc_dequeue_req_tag;
wire [PORTS-1:0]                          rx_port_desc_dequeue_req_valid;
wire [PORTS-1:0]                          rx_port_desc_dequeue_req_ready;

wire [PORTS*QUEUE_PTR_WIDTH-1:0]          rx_port_desc_dequeue_resp_ptr;
wire [PORTS*PCIE_ADDR_WIDTH-1:0]          rx_port_desc_dequeue_resp_addr;
wire [PORTS*RX_CPL_QUEUE_INDEX_WIDTH-1:0] rx_port_desc_dequeue_resp_cpl;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      rx_port_desc_dequeue_resp_tag;
wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       rx_port_desc_dequeue_resp_op_tag;
wire [PORTS-1:0]                          rx_port_desc_dequeue_resp_empty;
wire [PORTS-1:0]                          rx_port_desc_dequeue_resp_error;
wire [PORTS-1:0]                          rx_port_desc_dequeue_resp_valid;
wire [PORTS-1:0]                          rx_port_desc_dequeue_resp_ready;

wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       rx_port_desc_dequeue_commit_op_tag;
wire [PORTS-1:0]                          rx_port_desc_dequeue_commit_valid;
wire [PORTS-1:0]                          rx_port_desc_dequeue_commit_ready;

wire [RX_CPL_QUEUE_INDEX_WIDTH-1:0] rx_cpl_enqueue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_cpl_enqueue_req_tag;
wire                                rx_cpl_enqueue_req_valid;
wire                                rx_cpl_enqueue_req_ready;

wire [PCIE_ADDR_WIDTH-1:0]          rx_cpl_enqueue_resp_addr;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_cpl_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_cpl_enqueue_resp_op_tag;
wire                                rx_cpl_enqueue_resp_full;
wire                                rx_cpl_enqueue_resp_error;
wire                                rx_cpl_enqueue_resp_valid;
wire                                rx_cpl_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_cpl_enqueue_commit_op_tag;
wire                                rx_cpl_enqueue_commit_valid;
wire                                rx_cpl_enqueue_commit_ready;

wire [PORTS*RX_CPL_QUEUE_INDEX_WIDTH-1:0] rx_port_cpl_enqueue_req_queue;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      rx_port_cpl_enqueue_req_tag;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_req_valid;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_req_ready;

wire [PORTS*PCIE_ADDR_WIDTH-1:0]          rx_port_cpl_enqueue_resp_addr;
wire [PORTS*QUEUE_REQ_TAG_WIDTH-1:0]      rx_port_cpl_enqueue_resp_tag;
wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       rx_port_cpl_enqueue_resp_op_tag;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_resp_full;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_resp_error;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_resp_valid;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_resp_ready;

wire [PORTS*QUEUE_OP_TAG_WIDTH-1:0]       rx_port_cpl_enqueue_commit_op_tag;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_commit_valid;
wire [PORTS-1:0]                          rx_port_cpl_enqueue_commit_ready;

// events
wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  axis_event_queue;
wire [EVENT_TYPE_WIDTH-1:0]         axis_event_type;
wire [EVENT_SOURCE_WIDTH-1:0]       axis_event_source;
wire                                axis_event_valid;
wire                                axis_event_ready;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  tx_fifo_event;
wire [EVENT_TYPE_WIDTH-1:0]         tx_fifo_event_type;
wire [EVENT_SOURCE_WIDTH-1:0]       tx_fifo_event_source;
wire                                tx_fifo_event_valid;
wire                                tx_fifo_event_ready;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  rx_fifo_event;
wire [EVENT_TYPE_WIDTH-1:0]         rx_fifo_event_type;
wire [EVENT_SOURCE_WIDTH-1:0]       rx_fifo_event_source;
wire                                rx_fifo_event_valid;
wire                                rx_fifo_event_ready;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  tx_event;
wire [EVENT_TYPE_WIDTH-1:0]         tx_event_type = 16'd0;
wire [EVENT_SOURCE_WIDTH-1:0]       tx_event_source;
wire                                tx_event_valid;

wire [EVENT_QUEUE_INDEX_WIDTH-1:0]  rx_event;
wire [EVENT_TYPE_WIDTH-1:0]         rx_event_type = 16'd1;
wire [EVENT_SOURCE_WIDTH-1:0]       rx_event_source;
wire                                rx_event_valid;

// interrupts
wire [INT_WIDTH-1:0] event_int;
wire event_int_valid;

assign msi_irq = (event_int_valid << event_int);

// Interface control registers
reg axil_ctrl_awready_reg = 1'b0;
reg axil_ctrl_wready_reg = 1'b0;
reg [1:0] axil_ctrl_bresp_reg = 2'b00;
reg axil_ctrl_bvalid_reg = 1'b0;
reg axil_ctrl_arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] axil_ctrl_rdata_reg = {AXIL_DATA_WIDTH{1'b0}};
reg [1:0] axil_ctrl_rresp_reg = 2'b00;
reg axil_ctrl_rvalid_reg = 1'b0;

assign axil_ctrl_awready = axil_ctrl_awready_reg;
assign axil_ctrl_wready = axil_ctrl_wready_reg;
assign axil_ctrl_bresp = axil_ctrl_bresp_reg;
assign axil_ctrl_bvalid = axil_ctrl_bvalid_reg;
assign axil_ctrl_arready = axil_ctrl_arready_reg;
assign axil_ctrl_rdata = axil_ctrl_rdata_reg;
assign axil_ctrl_rresp = axil_ctrl_rresp_reg;
assign axil_ctrl_rvalid = axil_ctrl_rvalid_reg;

always @(posedge clk) begin
    axil_ctrl_awready_reg <= 1'b0;
    axil_ctrl_wready_reg <= 1'b0;
    axil_ctrl_bresp_reg <= 2'b00;
    axil_ctrl_bvalid_reg <= axil_ctrl_bvalid_reg && !axil_ctrl_bready;
    axil_ctrl_arready_reg <= 1'b0;
    axil_ctrl_rresp_reg <= 2'b00;
    axil_ctrl_rvalid_reg <= axil_ctrl_rvalid_reg && !axil_ctrl_rready;

    if (axil_ctrl_awvalid && axil_ctrl_wvalid && !axil_ctrl_bvalid) begin
        // write operation
        axil_ctrl_awready_reg <= 1'b1;
        axil_ctrl_wready_reg <= 1'b1;
        axil_ctrl_bresp_reg <= 2'b00;
        axil_ctrl_bvalid_reg <= 1'b1;

        // case ({axil_ctrl_awaddr[15:2], 2'b00})
        //     16'h0000: 
        // endcase
    end

    if (axil_ctrl_arvalid && !axil_ctrl_rvalid) begin
        // read operation
        axil_ctrl_arready_reg <= 1'b1;
        axil_ctrl_rresp_reg <= 2'b00;
        axil_ctrl_rvalid_reg <= 1'b1;
        axil_ctrl_rdata_reg <= {AXIL_DATA_WIDTH{1'b0}};

        case ({axil_ctrl_araddr[15:2], 2'b00})
            16'h0000: axil_ctrl_rdata_reg <= 32'd0;                       // if_id
            16'h0004: begin
                // if_features
                axil_ctrl_rdata_reg[4] <= PTP_TS_ENABLE;
                axil_ctrl_rdata_reg[8] <= TX_CHECKSUM_ENABLE;
                axil_ctrl_rdata_reg[9] <= RX_CHECKSUM_ENABLE;
            end
            16'h0010: axil_ctrl_rdata_reg <= 2**EVENT_QUEUE_INDEX_WIDTH;  // event_queue_count
            16'h0014: axil_ctrl_rdata_reg <= 24'h080000;                  // event_queue_offset
            16'h0020: axil_ctrl_rdata_reg <= 2**TX_QUEUE_INDEX_WIDTH;     // tx_queue_count
            16'h0024: axil_ctrl_rdata_reg <= 24'h100000;                  // tx_queue_offset
            16'h0028: axil_ctrl_rdata_reg <= 2**TX_CPL_QUEUE_INDEX_WIDTH; // tx_cpl_queue_count
            16'h002C: axil_ctrl_rdata_reg <= 24'h200000;                  // tx_cpl_queue_offset
            16'h0030: axil_ctrl_rdata_reg <= 2**RX_QUEUE_INDEX_WIDTH;     // rx_queue_count
            16'h0034: axil_ctrl_rdata_reg <= 24'h300000;                  // rx_queue_offset
            16'h0038: axil_ctrl_rdata_reg <= 2**RX_CPL_QUEUE_INDEX_WIDTH; // rx_cpl_queue_count
            16'h003C: axil_ctrl_rdata_reg <= 24'h380000;                  // rx_cpl_queue_offset
            16'h0040: axil_ctrl_rdata_reg <= PORTS;                       // port_count
            16'h0044: axil_ctrl_rdata_reg <= 24'h400000;                  // port_offset
            16'h0048: axil_ctrl_rdata_reg <= 24'h100000;                  // port_stride
        endcase
    end

    if (rst) begin
        axil_ctrl_awready_reg <= 1'b0;
        axil_ctrl_wready_reg <= 1'b0;
        axil_ctrl_bvalid_reg <= 1'b0;
        axil_ctrl_arready_reg <= 1'b0;
        axil_ctrl_rvalid_reg <= 1'b0;
    end
end

// AXI lite interconnect
parameter AXIL_S_COUNT = 1;
parameter AXIL_M_COUNT = 7+PORTS;

axil_interconnect #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .S_COUNT(AXIL_S_COUNT),
    .M_COUNT(AXIL_M_COUNT),
    .M_BASE_ADDR({23'h400000, 23'h380000, 23'h300000, 23'h200000, 23'h100000, 23'h080000, 23'h040000, 23'h000000}),
    .M_ADDR_WIDTH({32'd20, 32'd19, 32'd19, 32'd20, 32'd20, 32'd19, 32'd18, 32'd18}),
    .M_CONNECT_READ({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}})
)
axil_interconnect_inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .m_axil_awaddr( {axil_port_awaddr,  axil_rx_cpl_queue_manager_awaddr,  axil_rx_queue_manager_awaddr,  axil_tx_cpl_queue_manager_awaddr,  axil_tx_queue_manager_awaddr,  axil_event_queue_manager_awaddr,  axil_ctrl_awaddr,  m_axil_csr_awaddr}),
    .m_axil_awprot( {axil_port_awprot,  axil_rx_cpl_queue_manager_awprot,  axil_rx_queue_manager_awprot,  axil_tx_cpl_queue_manager_awprot,  axil_tx_queue_manager_awprot,  axil_event_queue_manager_awprot,  axil_ctrl_awprot,  m_axil_csr_awprot}),
    .m_axil_awvalid({axil_port_awvalid, axil_rx_cpl_queue_manager_awvalid, axil_rx_queue_manager_awvalid, axil_tx_cpl_queue_manager_awvalid, axil_tx_queue_manager_awvalid, axil_event_queue_manager_awvalid, axil_ctrl_awvalid, m_axil_csr_awvalid}),
    .m_axil_awready({axil_port_awready, axil_rx_cpl_queue_manager_awready, axil_rx_queue_manager_awready, axil_tx_cpl_queue_manager_awready, axil_tx_queue_manager_awready, axil_event_queue_manager_awready, axil_ctrl_awready, m_axil_csr_awready}),
    .m_axil_wdata(  {axil_port_wdata,   axil_rx_cpl_queue_manager_wdata,   axil_rx_queue_manager_wdata,   axil_tx_cpl_queue_manager_wdata,   axil_tx_queue_manager_wdata,   axil_event_queue_manager_wdata,   axil_ctrl_wdata,   m_axil_csr_wdata}),
    .m_axil_wstrb(  {axil_port_wstrb,   axil_rx_cpl_queue_manager_wstrb,   axil_rx_queue_manager_wstrb,   axil_tx_cpl_queue_manager_wstrb,   axil_tx_queue_manager_wstrb,   axil_event_queue_manager_wstrb,   axil_ctrl_wstrb,   m_axil_csr_wstrb}),
    .m_axil_wvalid( {axil_port_wvalid,  axil_rx_cpl_queue_manager_wvalid,  axil_rx_queue_manager_wvalid,  axil_tx_cpl_queue_manager_wvalid,  axil_tx_queue_manager_wvalid,  axil_event_queue_manager_wvalid,  axil_ctrl_wvalid,  m_axil_csr_wvalid}),
    .m_axil_wready( {axil_port_wready,  axil_rx_cpl_queue_manager_wready,  axil_rx_queue_manager_wready,  axil_tx_cpl_queue_manager_wready,  axil_tx_queue_manager_wready,  axil_event_queue_manager_wready,  axil_ctrl_wready,  m_axil_csr_wready}),
    .m_axil_bresp(  {axil_port_bresp,   axil_rx_cpl_queue_manager_bresp,   axil_rx_queue_manager_bresp,   axil_tx_cpl_queue_manager_bresp,   axil_tx_queue_manager_bresp,   axil_event_queue_manager_bresp,   axil_ctrl_bresp,   m_axil_csr_bresp}),
    .m_axil_bvalid( {axil_port_bvalid,  axil_rx_cpl_queue_manager_bvalid,  axil_rx_queue_manager_bvalid,  axil_tx_cpl_queue_manager_bvalid,  axil_tx_queue_manager_bvalid,  axil_event_queue_manager_bvalid,  axil_ctrl_bvalid,  m_axil_csr_bvalid}),
    .m_axil_bready( {axil_port_bready,  axil_rx_cpl_queue_manager_bready,  axil_rx_queue_manager_bready,  axil_tx_cpl_queue_manager_bready,  axil_tx_queue_manager_bready,  axil_event_queue_manager_bready,  axil_ctrl_bready,  m_axil_csr_bready}),
    .m_axil_araddr( {axil_port_araddr,  axil_rx_cpl_queue_manager_araddr,  axil_rx_queue_manager_araddr,  axil_tx_cpl_queue_manager_araddr,  axil_tx_queue_manager_araddr,  axil_event_queue_manager_araddr,  axil_ctrl_araddr,  m_axil_csr_araddr}),
    .m_axil_arprot( {axil_port_arprot,  axil_rx_cpl_queue_manager_arprot,  axil_rx_queue_manager_arprot,  axil_tx_cpl_queue_manager_arprot,  axil_tx_queue_manager_arprot,  axil_event_queue_manager_arprot,  axil_ctrl_arprot,  m_axil_csr_arprot}),
    .m_axil_arvalid({axil_port_arvalid, axil_rx_cpl_queue_manager_arvalid, axil_rx_queue_manager_arvalid, axil_tx_cpl_queue_manager_arvalid, axil_tx_queue_manager_arvalid, axil_event_queue_manager_arvalid, axil_ctrl_arvalid, m_axil_csr_arvalid}),
    .m_axil_arready({axil_port_arready, axil_rx_cpl_queue_manager_arready, axil_rx_queue_manager_arready, axil_tx_cpl_queue_manager_arready, axil_tx_queue_manager_arready, axil_event_queue_manager_arready, axil_ctrl_arready, m_axil_csr_arready}),
    .m_axil_rdata(  {axil_port_rdata,   axil_rx_cpl_queue_manager_rdata,   axil_rx_queue_manager_rdata,   axil_tx_cpl_queue_manager_rdata,   axil_tx_queue_manager_rdata,   axil_event_queue_manager_rdata,   axil_ctrl_rdata,   m_axil_csr_rdata}),
    .m_axil_rresp(  {axil_port_rresp,   axil_rx_cpl_queue_manager_rresp,   axil_rx_queue_manager_rresp,   axil_tx_cpl_queue_manager_rresp,   axil_tx_queue_manager_rresp,   axil_event_queue_manager_rresp,   axil_ctrl_rresp,   m_axil_csr_rresp}),
    .m_axil_rvalid( {axil_port_rvalid,  axil_rx_cpl_queue_manager_rvalid,  axil_rx_queue_manager_rvalid,  axil_tx_cpl_queue_manager_rvalid,  axil_tx_queue_manager_rvalid,  axil_event_queue_manager_rvalid,  axil_ctrl_rvalid,  m_axil_csr_rvalid}),
    .m_axil_rready( {axil_port_rready,  axil_rx_cpl_queue_manager_rready,  axil_rx_queue_manager_rready,  axil_tx_cpl_queue_manager_rready,  axil_tx_queue_manager_rready,  axil_event_queue_manager_rready,  axil_ctrl_rready,  m_axil_csr_rready})
);

// Queue managers

cpl_queue_manager #(
    .ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(INT_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .QUEUE_LOG_SIZE_WIDTH(QUEUE_LOG_SIZE_WIDTH),
    .CPL_SIZE(EVENT_SIZE),
    .PIPELINE(3),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
event_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Enqueue request input
     */
    .s_axis_enqueue_req_queue(event_enqueue_req_queue),
    .s_axis_enqueue_req_tag(event_enqueue_req_tag),
    .s_axis_enqueue_req_valid(event_enqueue_req_valid),
    .s_axis_enqueue_req_ready(event_enqueue_req_ready),

    /*
     * Enqueue response output
     */
    .m_axis_enqueue_resp_ptr(),
    .m_axis_enqueue_resp_addr(event_enqueue_resp_addr),
    .m_axis_enqueue_resp_event(),
    .m_axis_enqueue_resp_tag(event_enqueue_resp_tag),
    .m_axis_enqueue_resp_op_tag(event_enqueue_resp_op_tag),
    .m_axis_enqueue_resp_full(event_enqueue_resp_full),
    .m_axis_enqueue_resp_error(event_enqueue_resp_error),
    .m_axis_enqueue_resp_valid(event_enqueue_resp_valid),
    .m_axis_enqueue_resp_ready(event_enqueue_resp_ready),

    /*
     * Enqueue commit input
     */
    .s_axis_enqueue_commit_op_tag(event_enqueue_commit_op_tag),
    .s_axis_enqueue_commit_valid(event_enqueue_commit_valid),
    .s_axis_enqueue_commit_ready(event_enqueue_commit_ready),

    /*
     * Event output
     */
    .m_axis_event(event_int),
    .m_axis_event_source(),
    .m_axis_event_valid(event_int_valid),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_event_queue_manager_awaddr),
    .s_axil_awprot(axil_event_queue_manager_awprot),
    .s_axil_awvalid(axil_event_queue_manager_awvalid),
    .s_axil_awready(axil_event_queue_manager_awready),
    .s_axil_wdata(axil_event_queue_manager_wdata),
    .s_axil_wstrb(axil_event_queue_manager_wstrb),
    .s_axil_wvalid(axil_event_queue_manager_wvalid),
    .s_axil_wready(axil_event_queue_manager_wready),
    .s_axil_bresp(axil_event_queue_manager_bresp),
    .s_axil_bvalid(axil_event_queue_manager_bvalid),
    .s_axil_bready(axil_event_queue_manager_bready),
    .s_axil_araddr(axil_event_queue_manager_araddr),
    .s_axil_arprot(axil_event_queue_manager_arprot),
    .s_axil_arvalid(axil_event_queue_manager_arvalid),
    .s_axil_arready(axil_event_queue_manager_arready),
    .s_axil_rdata(axil_event_queue_manager_rdata),
    .s_axil_rresp(axil_event_queue_manager_rresp),
    .s_axil_rvalid(axil_event_queue_manager_rvalid),
    .s_axil_rready(axil_event_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

if (PORTS > 1) begin

    queue_op_mux #(
        .PORTS(PORTS),
        .ADDR_WIDTH(PCIE_ADDR_WIDTH),
        .S_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
        .M_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH), // TODO
        .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
        .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
        .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
        .CPL_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
        .ARB_TYPE("ROUND_ROBIN"),
        .LSB_PRIORITY("HIGH")
    )
    event_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Dequeue request output
         */
        .m_axis_dequeue_req_queue(tx_desc_dequeue_req_queue),
        .m_axis_dequeue_req_tag(tx_desc_dequeue_req_tag),
        .m_axis_dequeue_req_valid(tx_desc_dequeue_req_valid),
        .m_axis_dequeue_req_ready(tx_desc_dequeue_req_ready),

        /*
         * Dequeue response input
         */
        .s_axis_dequeue_resp_ptr(tx_desc_dequeue_resp_ptr),
        .s_axis_dequeue_resp_addr(tx_desc_dequeue_resp_addr),
        .s_axis_dequeue_resp_cpl(tx_desc_dequeue_resp_cpl),
        .s_axis_dequeue_resp_tag(tx_desc_dequeue_resp_tag),
        .s_axis_dequeue_resp_op_tag(tx_desc_dequeue_resp_op_tag),
        .s_axis_dequeue_resp_empty(tx_desc_dequeue_resp_empty),
        .s_axis_dequeue_resp_error(tx_desc_dequeue_resp_error),
        .s_axis_dequeue_resp_valid(tx_desc_dequeue_resp_valid),
        .s_axis_dequeue_resp_ready(tx_desc_dequeue_resp_ready),

        /*
         * Dequeue commit output
         */
        .m_axis_dequeue_commit_op_tag(tx_desc_dequeue_commit_op_tag),
        .m_axis_dequeue_commit_valid(tx_desc_dequeue_commit_valid),
        .m_axis_dequeue_commit_ready(tx_desc_dequeue_commit_ready),

        /*
         * Dequeue request input
         */
        .s_axis_dequeue_req_queue(tx_port_desc_dequeue_req_queue),
        .s_axis_dequeue_req_tag(tx_port_desc_dequeue_req_tag),
        .s_axis_dequeue_req_valid(tx_port_desc_dequeue_req_valid),
        .s_axis_dequeue_req_ready(tx_port_desc_dequeue_req_ready),

        /*
         * Dequeue response output
         */
        .m_axis_dequeue_resp_ptr(tx_port_desc_dequeue_resp_ptr),
        .m_axis_dequeue_resp_addr(tx_port_desc_dequeue_resp_addr),
        .m_axis_dequeue_resp_cpl(tx_port_desc_dequeue_resp_cpl),
        .m_axis_dequeue_resp_tag(tx_port_desc_dequeue_resp_tag),
        .m_axis_dequeue_resp_op_tag(tx_port_desc_dequeue_resp_op_tag),
        .m_axis_dequeue_resp_empty(tx_port_desc_dequeue_resp_empty),
        .m_axis_dequeue_resp_error(tx_port_desc_dequeue_resp_error),
        .m_axis_dequeue_resp_valid(tx_port_desc_dequeue_resp_valid),
        .m_axis_dequeue_resp_ready(tx_port_desc_dequeue_resp_ready),

        /*
         * Dequeue commit input
         */
        .s_axis_dequeue_commit_op_tag(tx_port_desc_dequeue_commit_op_tag),
        .s_axis_dequeue_commit_valid(tx_port_desc_dequeue_commit_valid),
        .s_axis_dequeue_commit_ready(tx_port_desc_dequeue_commit_ready)
    );

end else begin

    assign tx_desc_dequeue_req_queue = tx_port_desc_dequeue_req_queue;
    assign tx_desc_dequeue_req_tag = tx_port_desc_dequeue_req_tag;
    assign tx_desc_dequeue_req_valid = tx_port_desc_dequeue_req_valid;
    assign tx_port_desc_dequeue_req_ready = tx_desc_dequeue_req_ready;

    assign tx_port_desc_dequeue_resp_ptr = tx_desc_dequeue_resp_ptr;
    assign tx_port_desc_dequeue_resp_addr = tx_desc_dequeue_resp_addr;
    assign tx_port_desc_dequeue_resp_cpl = tx_desc_dequeue_resp_cpl;
    assign tx_port_desc_dequeue_resp_tag = tx_desc_dequeue_resp_tag;
    assign tx_port_desc_dequeue_resp_op_tag = tx_desc_dequeue_resp_op_tag;
    assign tx_port_desc_dequeue_resp_empty = tx_desc_dequeue_resp_empty;
    assign tx_port_desc_dequeue_resp_error = tx_desc_dequeue_resp_error;
    assign tx_port_desc_dequeue_resp_valid = tx_desc_dequeue_resp_valid;
    assign tx_desc_dequeue_resp_ready = tx_port_desc_dequeue_resp_ready;

    assign tx_desc_dequeue_commit_op_tag = tx_port_desc_dequeue_commit_op_tag;
    assign tx_desc_dequeue_commit_valid = tx_port_desc_dequeue_commit_valid;
    assign tx_port_desc_dequeue_commit_ready = tx_desc_dequeue_commit_ready;

end

queue_manager #(
    .ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .CPL_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .QUEUE_LOG_SIZE_WIDTH(QUEUE_LOG_SIZE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .PIPELINE(3),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
tx_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Dequeue request input
     */
    .s_axis_dequeue_req_queue(tx_desc_dequeue_req_queue),
    .s_axis_dequeue_req_tag(tx_desc_dequeue_req_tag),
    .s_axis_dequeue_req_valid(tx_desc_dequeue_req_valid),
    .s_axis_dequeue_req_ready(tx_desc_dequeue_req_ready),

    /*
     * Dequeue response output
     */
    .m_axis_dequeue_resp_ptr(tx_desc_dequeue_resp_ptr),
    .m_axis_dequeue_resp_addr(tx_desc_dequeue_resp_addr),
    .m_axis_dequeue_resp_cpl(tx_desc_dequeue_resp_cpl),
    .m_axis_dequeue_resp_tag(tx_desc_dequeue_resp_tag),
    .m_axis_dequeue_resp_op_tag(tx_desc_dequeue_resp_op_tag),
    .m_axis_dequeue_resp_empty(tx_desc_dequeue_resp_empty),
    .m_axis_dequeue_resp_error(tx_desc_dequeue_resp_error),
    .m_axis_dequeue_resp_valid(tx_desc_dequeue_resp_valid),
    .m_axis_dequeue_resp_ready(tx_desc_dequeue_resp_ready),

    /*
     * Dequeue commit input
     */
    .s_axis_dequeue_commit_op_tag(tx_desc_dequeue_commit_op_tag),
    .s_axis_dequeue_commit_valid(tx_desc_dequeue_commit_valid),
    .s_axis_dequeue_commit_ready(tx_desc_dequeue_commit_ready),

    /*
     * Doorbell output
     */
    .m_axis_doorbell_queue(tx_doorbell_queue),
    .m_axis_doorbell_valid(tx_doorbell_valid),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_tx_queue_manager_awaddr),
    .s_axil_awprot(axil_tx_queue_manager_awprot),
    .s_axil_awvalid(axil_tx_queue_manager_awvalid),
    .s_axil_awready(axil_tx_queue_manager_awready),
    .s_axil_wdata(axil_tx_queue_manager_wdata),
    .s_axil_wstrb(axil_tx_queue_manager_wstrb),
    .s_axil_wvalid(axil_tx_queue_manager_wvalid),
    .s_axil_wready(axil_tx_queue_manager_wready),
    .s_axil_bresp(axil_tx_queue_manager_bresp),
    .s_axil_bvalid(axil_tx_queue_manager_bvalid),
    .s_axil_bready(axil_tx_queue_manager_bready),
    .s_axil_araddr(axil_tx_queue_manager_araddr),
    .s_axil_arprot(axil_tx_queue_manager_arprot),
    .s_axil_arvalid(axil_tx_queue_manager_arvalid),
    .s_axil_arready(axil_tx_queue_manager_arready),
    .s_axil_rdata(axil_tx_queue_manager_rdata),
    .s_axil_rresp(axil_tx_queue_manager_rresp),
    .s_axil_rvalid(axil_tx_queue_manager_rvalid),
    .s_axil_rready(axil_tx_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

if (PORTS > 1) begin

    queue_op_mux #(
        .PORTS(PORTS),
        .ADDR_WIDTH(PCIE_ADDR_WIDTH),
        .S_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
        .M_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH), // TODO
        .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
        .QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
        .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
        .CPL_INDEX_WIDTH(0),
        .ARB_TYPE("ROUND_ROBIN"),
        .LSB_PRIORITY("HIGH")
    )
    event_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Dequeue request output
         */
        .m_axis_dequeue_req_queue(tx_cpl_enqueue_req_queue),
        .m_axis_dequeue_req_tag(tx_cpl_enqueue_req_tag),
        .m_axis_dequeue_req_valid(tx_cpl_enqueue_req_valid),
        .m_axis_dequeue_req_ready(tx_cpl_enqueue_req_ready),

        /*
         * Dequeue response input
         */
        .s_axis_dequeue_resp_ptr(0),
        .s_axis_dequeue_resp_addr(tx_cpl_enqueue_resp_addr),
        .s_axis_dequeue_resp_cpl(0),
        .s_axis_dequeue_resp_tag(tx_cpl_enqueue_resp_tag),
        .s_axis_dequeue_resp_op_tag(tx_cpl_enqueue_resp_op_tag),
        .s_axis_dequeue_resp_empty(tx_cpl_enqueue_resp_full),
        .s_axis_dequeue_resp_error(tx_cpl_enqueue_resp_error),
        .s_axis_dequeue_resp_valid(tx_cpl_enqueue_resp_valid),
        .s_axis_dequeue_resp_ready(tx_cpl_enqueue_resp_ready),

        /*
         * Dequeue commit output
         */
        .m_axis_dequeue_commit_op_tag(tx_cpl_enqueue_commit_op_tag),
        .m_axis_dequeue_commit_valid(tx_cpl_enqueue_commit_valid),
        .m_axis_dequeue_commit_ready(tx_cpl_enqueue_commit_ready),

        /*
         * Dequeue request input
         */
        .s_axis_dequeue_req_queue(tx_port_cpl_enqueue_req_queue),
        .s_axis_dequeue_req_tag(tx_port_cpl_enqueue_req_tag),
        .s_axis_dequeue_req_valid(tx_port_cpl_enqueue_req_valid),
        .s_axis_dequeue_req_ready(tx_port_cpl_enqueue_req_ready),

        /*
         * Dequeue response output
         */
        .m_axis_dequeue_resp_ptr(),
        .m_axis_dequeue_resp_addr(tx_port_cpl_enqueue_resp_addr),
        .m_axis_dequeue_resp_cpl(),
        .m_axis_dequeue_resp_tag(tx_port_cpl_enqueue_resp_tag),
        .m_axis_dequeue_resp_op_tag(tx_port_cpl_enqueue_resp_op_tag),
        .m_axis_dequeue_resp_empty(tx_port_cpl_enqueue_resp_full),
        .m_axis_dequeue_resp_error(tx_port_cpl_enqueue_resp_error),
        .m_axis_dequeue_resp_valid(tx_port_cpl_enqueue_resp_valid),
        .m_axis_dequeue_resp_ready(tx_port_cpl_enqueue_resp_ready),

        /*
         * Dequeue commit input
         */
        .s_axis_dequeue_commit_op_tag(tx_port_cpl_enqueue_commit_op_tag),
        .s_axis_dequeue_commit_valid(tx_port_cpl_enqueue_commit_valid),
        .s_axis_dequeue_commit_ready(tx_port_cpl_enqueue_commit_ready)
    );

end else begin

    assign tx_cpl_enqueue_req_queue = tx_port_cpl_enqueue_req_queue;
    assign tx_cpl_enqueue_req_tag = tx_port_cpl_enqueue_req_tag;
    assign tx_cpl_enqueue_req_valid = tx_port_cpl_enqueue_req_valid;
    assign tx_port_cpl_enqueue_req_ready = tx_cpl_enqueue_req_ready;

    assign tx_port_cpl_enqueue_resp_addr = tx_cpl_enqueue_resp_addr;
    assign tx_port_cpl_enqueue_resp_tag = tx_cpl_enqueue_resp_tag;
    assign tx_port_cpl_enqueue_resp_op_tag = tx_cpl_enqueue_resp_op_tag;
    assign tx_port_cpl_enqueue_resp_full = tx_cpl_enqueue_resp_full;
    assign tx_port_cpl_enqueue_resp_error = tx_cpl_enqueue_resp_error;
    assign tx_port_cpl_enqueue_resp_valid = tx_cpl_enqueue_resp_valid;
    assign tx_cpl_enqueue_resp_ready = tx_port_cpl_enqueue_resp_ready;

    assign tx_cpl_enqueue_commit_op_tag = tx_port_cpl_enqueue_commit_op_tag;
    assign tx_cpl_enqueue_commit_valid = tx_port_cpl_enqueue_commit_valid;
    assign tx_port_cpl_enqueue_commit_ready = tx_cpl_enqueue_commit_ready;

end

cpl_queue_manager #(
    .ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .QUEUE_LOG_SIZE_WIDTH(QUEUE_LOG_SIZE_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .PIPELINE(3),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
tx_cpl_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Enqueue request input
     */
    .s_axis_enqueue_req_queue(tx_cpl_enqueue_req_queue),
    .s_axis_enqueue_req_tag(tx_cpl_enqueue_req_tag),
    .s_axis_enqueue_req_valid(tx_cpl_enqueue_req_valid),
    .s_axis_enqueue_req_ready(tx_cpl_enqueue_req_ready),

    /*
     * Enqueue response output
     */
    .m_axis_enqueue_resp_ptr(),
    .m_axis_enqueue_resp_addr(tx_cpl_enqueue_resp_addr),
    .m_axis_enqueue_resp_event(),
    .m_axis_enqueue_resp_tag(tx_cpl_enqueue_resp_tag),
    .m_axis_enqueue_resp_op_tag(tx_cpl_enqueue_resp_op_tag),
    .m_axis_enqueue_resp_full(tx_cpl_enqueue_resp_full),
    .m_axis_enqueue_resp_error(tx_cpl_enqueue_resp_error),
    .m_axis_enqueue_resp_valid(tx_cpl_enqueue_resp_valid),
    .m_axis_enqueue_resp_ready(tx_cpl_enqueue_resp_ready),

    /*
     * Enqueue commit input
     */
    .s_axis_enqueue_commit_op_tag(tx_cpl_enqueue_commit_op_tag),
    .s_axis_enqueue_commit_valid(tx_cpl_enqueue_commit_valid),
    .s_axis_enqueue_commit_ready(tx_cpl_enqueue_commit_ready),

    /*
     * Event output
     */
    .m_axis_event(tx_event),
    .m_axis_event_source(tx_event_source),
    .m_axis_event_valid(tx_event_valid),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_tx_cpl_queue_manager_awaddr),
    .s_axil_awprot(axil_tx_cpl_queue_manager_awprot),
    .s_axil_awvalid(axil_tx_cpl_queue_manager_awvalid),
    .s_axil_awready(axil_tx_cpl_queue_manager_awready),
    .s_axil_wdata(axil_tx_cpl_queue_manager_wdata),
    .s_axil_wstrb(axil_tx_cpl_queue_manager_wstrb),
    .s_axil_wvalid(axil_tx_cpl_queue_manager_wvalid),
    .s_axil_wready(axil_tx_cpl_queue_manager_wready),
    .s_axil_bresp(axil_tx_cpl_queue_manager_bresp),
    .s_axil_bvalid(axil_tx_cpl_queue_manager_bvalid),
    .s_axil_bready(axil_tx_cpl_queue_manager_bready),
    .s_axil_araddr(axil_tx_cpl_queue_manager_araddr),
    .s_axil_arprot(axil_tx_cpl_queue_manager_arprot),
    .s_axil_arvalid(axil_tx_cpl_queue_manager_arvalid),
    .s_axil_arready(axil_tx_cpl_queue_manager_arready),
    .s_axil_rdata(axil_tx_cpl_queue_manager_rdata),
    .s_axil_rresp(axil_tx_cpl_queue_manager_rresp),
    .s_axil_rvalid(axil_tx_cpl_queue_manager_rvalid),
    .s_axil_rready(axil_tx_cpl_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);


if (PORTS > 1) begin

    queue_op_mux #(
        .PORTS(PORTS),
        .ADDR_WIDTH(PCIE_ADDR_WIDTH),
        .S_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
        .M_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH), // TODO
        .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
        .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
        .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
        .CPL_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
        .ARB_TYPE("ROUND_ROBIN"),
        .LSB_PRIORITY("HIGH")
    )
    event_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Dequeue request output
         */
        .m_axis_dequeue_req_queue(rx_desc_dequeue_req_queue),
        .m_axis_dequeue_req_tag(rx_desc_dequeue_req_tag),
        .m_axis_dequeue_req_valid(rx_desc_dequeue_req_valid),
        .m_axis_dequeue_req_ready(rx_desc_dequeue_req_ready),

        /*
         * Dequeue response input
         */
        .s_axis_dequeue_resp_ptr(rx_desc_dequeue_resp_ptr),
        .s_axis_dequeue_resp_addr(rx_desc_dequeue_resp_addr),
        .s_axis_dequeue_resp_cpl(rx_desc_dequeue_resp_cpl),
        .s_axis_dequeue_resp_tag(rx_desc_dequeue_resp_tag),
        .s_axis_dequeue_resp_op_tag(rx_desc_dequeue_resp_op_tag),
        .s_axis_dequeue_resp_empty(rx_desc_dequeue_resp_empty),
        .s_axis_dequeue_resp_error(rx_desc_dequeue_resp_error),
        .s_axis_dequeue_resp_valid(rx_desc_dequeue_resp_valid),
        .s_axis_dequeue_resp_ready(rx_desc_dequeue_resp_ready),

        /*
         * Dequeue commit output
         */
        .m_axis_dequeue_commit_op_tag(rx_desc_dequeue_commit_op_tag),
        .m_axis_dequeue_commit_valid(rx_desc_dequeue_commit_valid),
        .m_axis_dequeue_commit_ready(rx_desc_dequeue_commit_ready),

        /*
         * Dequeue request input
         */
        .s_axis_dequeue_req_queue(rx_port_desc_dequeue_req_queue),
        .s_axis_dequeue_req_tag(rx_port_desc_dequeue_req_tag),
        .s_axis_dequeue_req_valid(rx_port_desc_dequeue_req_valid),
        .s_axis_dequeue_req_ready(rx_port_desc_dequeue_req_ready),

        /*
         * Dequeue response output
         */
        .m_axis_dequeue_resp_ptr(rx_port_desc_dequeue_resp_ptr),
        .m_axis_dequeue_resp_addr(rx_port_desc_dequeue_resp_addr),
        .m_axis_dequeue_resp_cpl(rx_port_desc_dequeue_resp_cpl),
        .m_axis_dequeue_resp_tag(rx_port_desc_dequeue_resp_tag),
        .m_axis_dequeue_resp_op_tag(rx_port_desc_dequeue_resp_op_tag),
        .m_axis_dequeue_resp_empty(rx_port_desc_dequeue_resp_empty),
        .m_axis_dequeue_resp_error(rx_port_desc_dequeue_resp_error),
        .m_axis_dequeue_resp_valid(rx_port_desc_dequeue_resp_valid),
        .m_axis_dequeue_resp_ready(rx_port_desc_dequeue_resp_ready),

        /*
         * Dequeue commit input
         */
        .s_axis_dequeue_commit_op_tag(rx_port_desc_dequeue_commit_op_tag),
        .s_axis_dequeue_commit_valid(rx_port_desc_dequeue_commit_valid),
        .s_axis_dequeue_commit_ready(rx_port_desc_dequeue_commit_ready)
    );

end else begin

    assign rx_desc_dequeue_req_queue = rx_port_desc_dequeue_req_queue;
    assign rx_desc_dequeue_req_tag = rx_port_desc_dequeue_req_tag;
    assign rx_desc_dequeue_req_valid = rx_port_desc_dequeue_req_valid;
    assign rx_port_desc_dequeue_req_ready = rx_desc_dequeue_req_ready;

    assign rx_port_desc_dequeue_resp_ptr = rx_desc_dequeue_resp_ptr;
    assign rx_port_desc_dequeue_resp_addr = rx_desc_dequeue_resp_addr;
    assign rx_port_desc_dequeue_resp_cpl = rx_desc_dequeue_resp_cpl;
    assign rx_port_desc_dequeue_resp_tag = rx_desc_dequeue_resp_tag;
    assign rx_port_desc_dequeue_resp_op_tag = rx_desc_dequeue_resp_op_tag;
    assign rx_port_desc_dequeue_resp_empty = rx_desc_dequeue_resp_empty;
    assign rx_port_desc_dequeue_resp_error = rx_desc_dequeue_resp_error;
    assign rx_port_desc_dequeue_resp_valid = rx_desc_dequeue_resp_valid;
    assign rx_desc_dequeue_resp_ready = rx_port_desc_dequeue_resp_ready;

    assign rx_desc_dequeue_commit_op_tag = rx_port_desc_dequeue_commit_op_tag;
    assign rx_desc_dequeue_commit_valid = rx_port_desc_dequeue_commit_valid;
    assign rx_port_desc_dequeue_commit_ready = rx_desc_dequeue_commit_ready;

end

queue_manager #(
    .ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .CPL_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .QUEUE_LOG_SIZE_WIDTH(QUEUE_LOG_SIZE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .PIPELINE(3),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
rx_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Dequeue request input
     */
    .s_axis_dequeue_req_queue(rx_desc_dequeue_req_queue),
    .s_axis_dequeue_req_tag(rx_desc_dequeue_req_tag),
    .s_axis_dequeue_req_valid(rx_desc_dequeue_req_valid),
    .s_axis_dequeue_req_ready(rx_desc_dequeue_req_ready),

    /*
     * Dequeue response output
     */
    .m_axis_dequeue_resp_ptr(rx_desc_dequeue_resp_ptr),
    .m_axis_dequeue_resp_addr(rx_desc_dequeue_resp_addr),
    .m_axis_dequeue_resp_cpl(rx_desc_dequeue_resp_cpl),
    .m_axis_dequeue_resp_tag(rx_desc_dequeue_resp_tag),
    .m_axis_dequeue_resp_op_tag(rx_desc_dequeue_resp_op_tag),
    .m_axis_dequeue_resp_empty(rx_desc_dequeue_resp_empty),
    .m_axis_dequeue_resp_error(rx_desc_dequeue_resp_error),
    .m_axis_dequeue_resp_valid(rx_desc_dequeue_resp_valid),
    .m_axis_dequeue_resp_ready(rx_desc_dequeue_resp_ready),

    /*
     * Dequeue commit input
     */
    .s_axis_dequeue_commit_op_tag(rx_desc_dequeue_commit_op_tag),
    .s_axis_dequeue_commit_valid(rx_desc_dequeue_commit_valid),
    .s_axis_dequeue_commit_ready(rx_desc_dequeue_commit_ready),

    /*
     * Doorbell output
     */
    .m_axis_doorbell_queue(),
    .m_axis_doorbell_valid(),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_rx_queue_manager_awaddr),
    .s_axil_awprot(axil_rx_queue_manager_awprot),
    .s_axil_awvalid(axil_rx_queue_manager_awvalid),
    .s_axil_awready(axil_rx_queue_manager_awready),
    .s_axil_wdata(axil_rx_queue_manager_wdata),
    .s_axil_wstrb(axil_rx_queue_manager_wstrb),
    .s_axil_wvalid(axil_rx_queue_manager_wvalid),
    .s_axil_wready(axil_rx_queue_manager_wready),
    .s_axil_bresp(axil_rx_queue_manager_bresp),
    .s_axil_bvalid(axil_rx_queue_manager_bvalid),
    .s_axil_bready(axil_rx_queue_manager_bready),
    .s_axil_araddr(axil_rx_queue_manager_araddr),
    .s_axil_arprot(axil_rx_queue_manager_arprot),
    .s_axil_arvalid(axil_rx_queue_manager_arvalid),
    .s_axil_arready(axil_rx_queue_manager_arready),
    .s_axil_rdata(axil_rx_queue_manager_rdata),
    .s_axil_rresp(axil_rx_queue_manager_rresp),
    .s_axil_rvalid(axil_rx_queue_manager_rvalid),
    .s_axil_rready(axil_rx_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

if (PORTS > 1) begin

    queue_op_mux #(
        .PORTS(PORTS),
        .ADDR_WIDTH(PCIE_ADDR_WIDTH),
        .S_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
        .M_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH), // TODO
        .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
        .QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
        .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
        .CPL_INDEX_WIDTH(0),
        .ARB_TYPE("ROUND_ROBIN"),
        .LSB_PRIORITY("HIGH")
    )
    event_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Dequeue request output
         */
        .m_axis_dequeue_req_queue(rx_cpl_enqueue_req_queue),
        .m_axis_dequeue_req_tag(rx_cpl_enqueue_req_tag),
        .m_axis_dequeue_req_valid(rx_cpl_enqueue_req_valid),
        .m_axis_dequeue_req_ready(rx_cpl_enqueue_req_ready),

        /*
         * Dequeue response input
         */
        .s_axis_dequeue_resp_ptr(0),
        .s_axis_dequeue_resp_addr(rx_cpl_enqueue_resp_addr),
        .s_axis_dequeue_resp_cpl(0),
        .s_axis_dequeue_resp_tag(rx_cpl_enqueue_resp_tag),
        .s_axis_dequeue_resp_op_tag(rx_cpl_enqueue_resp_op_tag),
        .s_axis_dequeue_resp_empty(rx_cpl_enqueue_resp_full),
        .s_axis_dequeue_resp_error(rx_cpl_enqueue_resp_error),
        .s_axis_dequeue_resp_valid(rx_cpl_enqueue_resp_valid),
        .s_axis_dequeue_resp_ready(rx_cpl_enqueue_resp_ready),

        /*
         * Dequeue commit output
         */
        .m_axis_dequeue_commit_op_tag(rx_cpl_enqueue_commit_op_tag),
        .m_axis_dequeue_commit_valid(rx_cpl_enqueue_commit_valid),
        .m_axis_dequeue_commit_ready(rx_cpl_enqueue_commit_ready),

        /*
         * Dequeue request input
         */
        .s_axis_dequeue_req_queue(rx_port_cpl_enqueue_req_queue),
        .s_axis_dequeue_req_tag(rx_port_cpl_enqueue_req_tag),
        .s_axis_dequeue_req_valid(rx_port_cpl_enqueue_req_valid),
        .s_axis_dequeue_req_ready(rx_port_cpl_enqueue_req_ready),

        /*
         * Dequeue response output
         */
        .m_axis_dequeue_resp_ptr(),
        .m_axis_dequeue_resp_addr(rx_port_cpl_enqueue_resp_addr),
        .m_axis_dequeue_resp_cpl(),
        .m_axis_dequeue_resp_tag(rx_port_cpl_enqueue_resp_tag),
        .m_axis_dequeue_resp_op_tag(rx_port_cpl_enqueue_resp_op_tag),
        .m_axis_dequeue_resp_empty(rx_port_cpl_enqueue_resp_full),
        .m_axis_dequeue_resp_error(rx_port_cpl_enqueue_resp_error),
        .m_axis_dequeue_resp_valid(rx_port_cpl_enqueue_resp_valid),
        .m_axis_dequeue_resp_ready(rx_port_cpl_enqueue_resp_ready),

        /*
         * Dequeue commit input
         */
        .s_axis_dequeue_commit_op_tag(rx_port_cpl_enqueue_commit_op_tag),
        .s_axis_dequeue_commit_valid(rx_port_cpl_enqueue_commit_valid),
        .s_axis_dequeue_commit_ready(rx_port_cpl_enqueue_commit_ready)
    );

end else begin

    assign rx_cpl_enqueue_req_queue = rx_port_cpl_enqueue_req_queue;
    assign rx_cpl_enqueue_req_tag = rx_port_cpl_enqueue_req_tag;
    assign rx_cpl_enqueue_req_valid = rx_port_cpl_enqueue_req_valid;
    assign rx_port_cpl_enqueue_req_ready = rx_cpl_enqueue_req_ready;

    assign rx_port_cpl_enqueue_resp_addr = rx_cpl_enqueue_resp_addr;
    assign rx_port_cpl_enqueue_resp_tag = rx_cpl_enqueue_resp_tag;
    assign rx_port_cpl_enqueue_resp_op_tag = rx_cpl_enqueue_resp_op_tag;
    assign rx_port_cpl_enqueue_resp_full = rx_cpl_enqueue_resp_full;
    assign rx_port_cpl_enqueue_resp_error = rx_cpl_enqueue_resp_error;
    assign rx_port_cpl_enqueue_resp_valid = rx_cpl_enqueue_resp_valid;
    assign rx_cpl_enqueue_resp_ready = rx_port_cpl_enqueue_resp_ready;

    assign rx_cpl_enqueue_commit_op_tag = rx_port_cpl_enqueue_commit_op_tag;
    assign rx_cpl_enqueue_commit_valid = rx_port_cpl_enqueue_commit_valid;
    assign rx_port_cpl_enqueue_commit_ready = rx_cpl_enqueue_commit_ready;

end

cpl_queue_manager #(
    .ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .QUEUE_LOG_SIZE_WIDTH(QUEUE_LOG_SIZE_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .PIPELINE(3),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
rx_cpl_queue_manager_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Enqueue request input
     */
    .s_axis_enqueue_req_queue(rx_cpl_enqueue_req_queue),
    .s_axis_enqueue_req_tag(rx_cpl_enqueue_req_tag),
    .s_axis_enqueue_req_valid(rx_cpl_enqueue_req_valid),
    .s_axis_enqueue_req_ready(rx_cpl_enqueue_req_ready),

    /*
     * Enqueue response output
     */
    .m_axis_enqueue_resp_ptr(),
    .m_axis_enqueue_resp_addr(rx_cpl_enqueue_resp_addr),
    .m_axis_enqueue_resp_event(),
    .m_axis_enqueue_resp_tag(rx_cpl_enqueue_resp_tag),
    .m_axis_enqueue_resp_op_tag(rx_cpl_enqueue_resp_op_tag),
    .m_axis_enqueue_resp_full(rx_cpl_enqueue_resp_full),
    .m_axis_enqueue_resp_error(rx_cpl_enqueue_resp_error),
    .m_axis_enqueue_resp_valid(rx_cpl_enqueue_resp_valid),
    .m_axis_enqueue_resp_ready(rx_cpl_enqueue_resp_ready),

    /*
     * Enqueue commit input
     */
    .s_axis_enqueue_commit_op_tag(rx_cpl_enqueue_commit_op_tag),
    .s_axis_enqueue_commit_valid(rx_cpl_enqueue_commit_valid),
    .s_axis_enqueue_commit_ready(rx_cpl_enqueue_commit_ready),

    /*
     * Event output
     */
    .m_axis_event(rx_event),
    .m_axis_event_source(rx_event_source),
    .m_axis_event_valid(rx_event_valid),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_rx_cpl_queue_manager_awaddr),
    .s_axil_awprot(axil_rx_cpl_queue_manager_awprot),
    .s_axil_awvalid(axil_rx_cpl_queue_manager_awvalid),
    .s_axil_awready(axil_rx_cpl_queue_manager_awready),
    .s_axil_wdata(axil_rx_cpl_queue_manager_wdata),
    .s_axil_wstrb(axil_rx_cpl_queue_manager_wstrb),
    .s_axil_wvalid(axil_rx_cpl_queue_manager_wvalid),
    .s_axil_wready(axil_rx_cpl_queue_manager_wready),
    .s_axil_bresp(axil_rx_cpl_queue_manager_bresp),
    .s_axil_bvalid(axil_rx_cpl_queue_manager_bvalid),
    .s_axil_bready(axil_rx_cpl_queue_manager_bready),
    .s_axil_araddr(axil_rx_cpl_queue_manager_araddr),
    .s_axil_arprot(axil_rx_cpl_queue_manager_arprot),
    .s_axil_arvalid(axil_rx_cpl_queue_manager_arvalid),
    .s_axil_arready(axil_rx_cpl_queue_manager_arready),
    .s_axil_rdata(axil_rx_cpl_queue_manager_rdata),
    .s_axil_rresp(axil_rx_cpl_queue_manager_rresp),
    .s_axil_rvalid(axil_rx_cpl_queue_manager_rvalid),
    .s_axil_rready(axil_rx_cpl_queue_manager_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

generate

if (PORTS > 1) begin

    pcie_axi_dma_desc_mux #(
        .PORTS(PORTS),
        .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
        .S_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
        .M_TAG_WIDTH(PCIE_DMA_TAG_WIDTH),
        .ARB_TYPE("ROUND_ROBIN"),
        .LSB_PRIORITY("HIGH")
    )
    pcie_axi_dma_read_desc_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Descriptor output
         */
        .m_axis_desc_pcie_addr(m_axis_pcie_axi_dma_read_desc_pcie_addr),
        .m_axis_desc_axi_addr(m_axis_pcie_axi_dma_read_desc_axi_addr),
        .m_axis_desc_len(m_axis_pcie_axi_dma_read_desc_len),
        .m_axis_desc_tag(m_axis_pcie_axi_dma_read_desc_tag),
        .m_axis_desc_valid(m_axis_pcie_axi_dma_read_desc_valid),
        .m_axis_desc_ready(m_axis_pcie_axi_dma_read_desc_ready),

        /*
         * Descriptor status input
         */
        .s_axis_desc_status_tag(s_axis_pcie_axi_dma_read_desc_status_tag),
        .s_axis_desc_status_valid(s_axis_pcie_axi_dma_read_desc_status_valid),

        /*
         * Descriptor input
         */
        .s_axis_desc_pcie_addr(port_pcie_axi_dma_read_desc_pcie_addr),
        .s_axis_desc_axi_addr(port_pcie_axi_dma_read_desc_axi_addr),
        .s_axis_desc_len(port_pcie_axi_dma_read_desc_len),
        .s_axis_desc_tag(port_pcie_axi_dma_read_desc_tag),
        .s_axis_desc_valid(port_pcie_axi_dma_read_desc_valid),
        .s_axis_desc_ready(port_pcie_axi_dma_read_desc_ready),

        /*
         * Descriptor status output
         */
        .m_axis_desc_status_tag(port_pcie_axi_dma_read_desc_status_tag),
        .m_axis_desc_status_valid(port_pcie_axi_dma_read_desc_status_valid)
    );

end else begin
    
    assign m_axis_pcie_axi_dma_read_desc_pcie_addr = port_pcie_axi_dma_read_desc_pcie_addr;
    assign m_axis_pcie_axi_dma_read_desc_axi_addr = port_pcie_axi_dma_read_desc_axi_addr;
    assign m_axis_pcie_axi_dma_read_desc_len = port_pcie_axi_dma_read_desc_len;
    assign m_axis_pcie_axi_dma_read_desc_tag = port_pcie_axi_dma_read_desc_tag;
    assign m_axis_pcie_axi_dma_read_desc_valid = port_pcie_axi_dma_read_desc_valid;
    assign port_pcie_axi_dma_read_desc_ready = m_axis_pcie_axi_dma_read_desc_ready;

    assign port_pcie_axi_dma_read_desc_status_tag = s_axis_pcie_axi_dma_read_desc_status_tag;
    assign port_pcie_axi_dma_read_desc_status_valid = s_axis_pcie_axi_dma_read_desc_status_valid;

end

endgenerate

pcie_axi_dma_desc_mux #(
    .PORTS(PORTS+1),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .S_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
    .M_TAG_WIDTH(PCIE_DMA_TAG_WIDTH),
    .ARB_TYPE("ROUND_ROBIN"),
    .LSB_PRIORITY("HIGH")
)
pcie_axi_dma_write_desc_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor output
     */
    .m_axis_desc_pcie_addr(m_axis_pcie_axi_dma_write_desc_pcie_addr),
    .m_axis_desc_axi_addr(m_axis_pcie_axi_dma_write_desc_axi_addr),
    .m_axis_desc_len(m_axis_pcie_axi_dma_write_desc_len),
    .m_axis_desc_tag(m_axis_pcie_axi_dma_write_desc_tag),
    .m_axis_desc_valid(m_axis_pcie_axi_dma_write_desc_valid),
    .m_axis_desc_ready(m_axis_pcie_axi_dma_write_desc_ready),

    /*
     * Descriptor status input
     */
    .s_axis_desc_status_tag(s_axis_pcie_axi_dma_write_desc_status_tag),
    .s_axis_desc_status_valid(s_axis_pcie_axi_dma_write_desc_status_valid),

    /*
     * Descriptor input
     */
    .s_axis_desc_pcie_addr({port_pcie_axi_dma_write_desc_pcie_addr, event_pcie_axi_dma_write_desc_pcie_addr}),
    .s_axis_desc_axi_addr({port_pcie_axi_dma_write_desc_axi_addr, event_pcie_axi_dma_write_desc_axi_addr}),
    .s_axis_desc_len({port_pcie_axi_dma_write_desc_len, event_pcie_axi_dma_write_desc_len}),
    .s_axis_desc_tag({port_pcie_axi_dma_write_desc_tag, event_pcie_axi_dma_write_desc_tag}),
    .s_axis_desc_valid({port_pcie_axi_dma_write_desc_valid, event_pcie_axi_dma_write_desc_valid}),
    .s_axis_desc_ready({port_pcie_axi_dma_write_desc_ready, event_pcie_axi_dma_write_desc_ready}),

    /*
     * Descriptor status output
     */
    .m_axis_desc_status_tag({port_pcie_axi_dma_write_desc_status_tag, event_pcie_axi_dma_write_desc_status_tag}),
    .m_axis_desc_status_valid({port_pcie_axi_dma_write_desc_status_valid, event_pcie_axi_dma_write_desc_status_valid})
);

event_mux #(
    .PORTS(2),
    .QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .EVENT_TYPE_WIDTH(EVENT_TYPE_WIDTH),
    .EVENT_SOURCE_WIDTH(EVENT_SOURCE_WIDTH),
    .ARB_TYPE("ROUND_ROBIN"),
    .LSB_PRIORITY("HIGH")
)
event_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Event output
     */
    .m_axis_event_queue(axis_event_queue),
    .m_axis_event_type(axis_event_type),
    .m_axis_event_source(axis_event_source),
    .m_axis_event_valid(axis_event_valid),
    .m_axis_event_ready(axis_event_ready),

    /*
     * Event input
     */
    .s_axis_event_queue({rx_fifo_event, tx_fifo_event}),
    .s_axis_event_type({rx_fifo_event_type, tx_fifo_event_type}),
    .s_axis_event_source({rx_fifo_event_source, tx_fifo_event_source}),
    .s_axis_event_valid({rx_fifo_event_valid, tx_fifo_event_valid}),
    .s_axis_event_ready({rx_fifo_event_ready, tx_fifo_event_ready})
);

axis_fifo #(
    .DEPTH(16),
    .DATA_WIDTH(EVENT_SOURCE_WIDTH+EVENT_TYPE_WIDTH+EVENT_QUEUE_INDEX_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
tx_event_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata({tx_event_source, tx_event_type, tx_event}),
    .s_axis_tkeep(0),
    .s_axis_tvalid(tx_event_valid),
    .s_axis_tready(),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_axis_tdata({tx_fifo_event_source, tx_fifo_event_type, tx_fifo_event}),
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_fifo_event_valid),
    .m_axis_tready(tx_fifo_event_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

axis_fifo #(
    .DEPTH(16),
    .DATA_WIDTH(EVENT_SOURCE_WIDTH+EVENT_TYPE_WIDTH+EVENT_QUEUE_INDEX_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
rx_event_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata({rx_event_source, rx_event_type, rx_event}),
    .s_axis_tkeep(0),
    .s_axis_tvalid(rx_event_valid),
    .s_axis_tready(),
    .s_axis_tlast(0),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(0),

    // AXI output
    .m_axis_tdata({rx_fifo_event_source, rx_fifo_event_type, rx_fifo_event}),
    .m_axis_tkeep(),
    .m_axis_tvalid(rx_fifo_event_valid),
    .m_axis_tready(rx_fifo_event_ready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

event_queue #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
    .PCIE_DMA_LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
    .PCIE_DMA_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .EVENT_TABLE_SIZE(16),
    .AXI_BASE_ADDR(AXI_BASE_ADDR + 24'h000000)
)
event_queue_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Event input
     */
    .s_axis_event_queue(axis_event_queue),
    .s_axis_event_type(axis_event_type),
    .s_axis_event_source(axis_event_source),
    .s_axis_event_valid(axis_event_valid),
    .s_axis_event_ready(axis_event_ready),

    /*
     * Completion enqueue request output
     */
    .m_axis_event_enqueue_req_queue(event_enqueue_req_queue),
    .m_axis_event_enqueue_req_tag(event_enqueue_req_tag),
    .m_axis_event_enqueue_req_valid(event_enqueue_req_valid),
    .m_axis_event_enqueue_req_ready(event_enqueue_req_ready),

    /*
     * Completion enqueue response input
     */
    .s_axis_event_enqueue_resp_addr(event_enqueue_resp_addr),
    .s_axis_event_enqueue_resp_tag(event_enqueue_resp_tag),
    .s_axis_event_enqueue_resp_op_tag(event_enqueue_resp_op_tag),
    .s_axis_event_enqueue_resp_full(event_enqueue_resp_full),
    .s_axis_event_enqueue_resp_error(event_enqueue_resp_error),
    .s_axis_event_enqueue_resp_valid(event_enqueue_resp_valid),
    .s_axis_event_enqueue_resp_ready(event_enqueue_resp_ready),

    /*
     * Completion enqueue commit output
     */
    .m_axis_event_enqueue_commit_op_tag(event_enqueue_commit_op_tag),
    .m_axis_event_enqueue_commit_valid(event_enqueue_commit_valid),
    .m_axis_event_enqueue_commit_ready(event_enqueue_commit_ready),

    /*
     * PCIe DMA write descriptor output
     */
    .m_axis_pcie_axi_dma_write_desc_pcie_addr(event_pcie_axi_dma_write_desc_pcie_addr),
    .m_axis_pcie_axi_dma_write_desc_axi_addr(event_pcie_axi_dma_write_desc_axi_addr),
    .m_axis_pcie_axi_dma_write_desc_len(event_pcie_axi_dma_write_desc_len),
    .m_axis_pcie_axi_dma_write_desc_tag(event_pcie_axi_dma_write_desc_tag),
    .m_axis_pcie_axi_dma_write_desc_valid(event_pcie_axi_dma_write_desc_valid),
    .m_axis_pcie_axi_dma_write_desc_ready(event_pcie_axi_dma_write_desc_ready),

    /*
     * PCIe DMA write descriptor status input
     */
    .s_axis_pcie_axi_dma_write_desc_status_tag(event_pcie_axi_dma_write_desc_status_tag),
    .s_axis_pcie_axi_dma_write_desc_status_valid(event_pcie_axi_dma_write_desc_status_valid),

    /*
     * AXI slave interface
     */
    .s_axi_awid(axi_event_awid),
    .s_axi_awaddr(axi_event_awaddr),
    .s_axi_awlen(axi_event_awlen),
    .s_axi_awsize(axi_event_awsize),
    .s_axi_awburst(axi_event_awburst),
    .s_axi_awlock(axi_event_awlock),
    .s_axi_awcache(axi_event_awcache),
    .s_axi_awprot(axi_event_awprot),
    .s_axi_awvalid(axi_event_awvalid),
    .s_axi_awready(axi_event_awready),
    .s_axi_wdata(axi_event_wdata),
    .s_axi_wstrb(axi_event_wstrb),
    .s_axi_wlast(axi_event_wlast),
    .s_axi_wvalid(axi_event_wvalid),
    .s_axi_wready(axi_event_wready),
    .s_axi_bid(axi_event_bid),
    .s_axi_bresp(axi_event_bresp),
    .s_axi_bvalid(axi_event_bvalid),
    .s_axi_bready(axi_event_bready),
    .s_axi_arid(axi_event_arid),
    .s_axi_araddr(axi_event_araddr),
    .s_axi_arlen(axi_event_arlen),
    .s_axi_arsize(axi_event_arsize),
    .s_axi_arburst(axi_event_arburst),
    .s_axi_arlock(axi_event_arlock),
    .s_axi_arcache(axi_event_arcache),
    .s_axi_arprot(axi_event_arprot),
    .s_axi_arvalid(axi_event_arvalid),
    .s_axi_arready(axi_event_arready),
    .s_axi_rid(axi_event_rid),
    .s_axi_rdata(axi_event_rdata),
    .s_axi_rresp(axi_event_rresp),
    .s_axi_rlast(axi_event_rlast),
    .s_axi_rvalid(axi_event_rvalid),
    .s_axi_rready(axi_event_rready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

parameter RAM_COUNT = PORTS*2+1;
parameter RAM_BASE_ADDR_WIDTH = RAM_COUNT*AXI_ADDR_WIDTH;
parameter RAM_BASE_ADDR = calcRAMBaseAddrs(RAM_ADDR_WIDTH);

function [RAM_BASE_ADDR_WIDTH-1:0] calcRAMBaseAddrs(input [31:0] ram_width);
    integer i;
    begin
        calcRAMBaseAddrs = {RAM_BASE_ADDR_WIDTH{1'b0}};
        for (i = 0; i < RAM_COUNT; i = i + 1) begin
            calcRAMBaseAddrs[i * AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = i * (2**ram_width);
        end
    end
endfunction

parameter AXI_S_COUNT = PORTS+1;
parameter AXI_M_COUNT = RAM_COUNT+1;

parameter RAM_ID_WIDTH = AXI_ID_WIDTH+$clog2(AXI_S_COUNT);


wire [PORTS*AXI_ID_WIDTH-1:0]    axi_port_dma_awid;
wire [PORTS*AXI_ADDR_WIDTH-1:0]  axi_port_dma_awaddr;
wire [PORTS*8-1:0]               axi_port_dma_awlen;
wire [PORTS*3-1:0]               axi_port_dma_awsize;
wire [PORTS*2-1:0]               axi_port_dma_awburst;
wire [PORTS-1:0]                 axi_port_dma_awlock;
wire [PORTS*4-1:0]               axi_port_dma_awcache;
wire [PORTS*3-1:0]               axi_port_dma_awprot;
wire [PORTS-1:0]                 axi_port_dma_awvalid;
wire [PORTS-1:0]                 axi_port_dma_awready;
wire [PORTS*AXI_DATA_WIDTH-1:0]  axi_port_dma_wdata;
wire [PORTS*AXI_STRB_WIDTH-1:0]  axi_port_dma_wstrb;
wire [PORTS-1:0]                 axi_port_dma_wlast;
wire [PORTS-1:0]                 axi_port_dma_wvalid;
wire [PORTS-1:0]                 axi_port_dma_wready;
wire [PORTS*AXI_ID_WIDTH-1:0]    axi_port_dma_bid;
wire [PORTS*2-1:0]               axi_port_dma_bresp;
wire [PORTS-1:0]                 axi_port_dma_bvalid;
wire [PORTS-1:0]                 axi_port_dma_bready;
wire [PORTS*AXI_ID_WIDTH-1:0]    axi_port_dma_arid;
wire [PORTS*AXI_ADDR_WIDTH-1:0]  axi_port_dma_araddr;
wire [PORTS*8-1:0]               axi_port_dma_arlen;
wire [PORTS*3-1:0]               axi_port_dma_arsize;
wire [PORTS*2-1:0]               axi_port_dma_arburst;
wire [PORTS-1:0]                 axi_port_dma_arlock;
wire [PORTS*4-1:0]               axi_port_dma_arcache;
wire [PORTS*3-1:0]               axi_port_dma_arprot;
wire [PORTS-1:0]                 axi_port_dma_arvalid;
wire [PORTS-1:0]                 axi_port_dma_arready;
wire [PORTS*AXI_ID_WIDTH-1:0]    axi_port_dma_rid;
wire [PORTS*AXI_DATA_WIDTH-1:0]  axi_port_dma_rdata;
wire [PORTS*2-1:0]               axi_port_dma_rresp;
wire [PORTS-1:0]                 axi_port_dma_rlast;
wire [PORTS-1:0]                 axi_port_dma_rvalid;
wire [PORTS-1:0]                 axi_port_dma_rready;

wire [RAM_COUNT*RAM_ID_WIDTH-1:0]   axi_ram_awid;
wire [RAM_COUNT*AXI_ADDR_WIDTH-1:0] axi_ram_awaddr;
wire [RAM_COUNT*8-1:0]              axi_ram_awlen;
wire [RAM_COUNT*3-1:0]              axi_ram_awsize;
wire [RAM_COUNT*2-1:0]              axi_ram_awburst;
wire [RAM_COUNT-1:0]                axi_ram_awlock;
wire [RAM_COUNT*4-1:0]              axi_ram_awcache;
wire [RAM_COUNT*3-1:0]              axi_ram_awprot;
wire [RAM_COUNT-1:0]                axi_ram_awvalid;
wire [RAM_COUNT-1:0]                axi_ram_awready;
wire [RAM_COUNT*AXI_DATA_WIDTH-1:0] axi_ram_wdata;
wire [RAM_COUNT*AXI_STRB_WIDTH-1:0] axi_ram_wstrb;
wire [RAM_COUNT-1:0]                axi_ram_wlast;
wire [RAM_COUNT-1:0]                axi_ram_wvalid;
wire [RAM_COUNT-1:0]                axi_ram_wready;
wire [RAM_COUNT*RAM_ID_WIDTH-1:0]   axi_ram_bid;
wire [RAM_COUNT*2-1:0]              axi_ram_bresp;
wire [RAM_COUNT-1:0]                axi_ram_bvalid;
wire [RAM_COUNT-1:0]                axi_ram_bready;
wire [RAM_COUNT*RAM_ID_WIDTH-1:0]   axi_ram_arid;
wire [RAM_COUNT*AXI_ADDR_WIDTH-1:0] axi_ram_araddr;
wire [RAM_COUNT*8-1:0]              axi_ram_arlen;
wire [RAM_COUNT*3-1:0]              axi_ram_arsize;
wire [RAM_COUNT*2-1:0]              axi_ram_arburst;
wire [RAM_COUNT-1:0]                axi_ram_arlock;
wire [RAM_COUNT*4-1:0]              axi_ram_arcache;
wire [RAM_COUNT*3-1:0]              axi_ram_arprot;
wire [RAM_COUNT-1:0]                axi_ram_arvalid;
wire [RAM_COUNT-1:0]                axi_ram_arready;
wire [RAM_COUNT*RAM_ID_WIDTH-1:0]   axi_ram_rid;
wire [RAM_COUNT*AXI_DATA_WIDTH-1:0] axi_ram_rdata;
wire [RAM_COUNT*2-1:0]              axi_ram_rresp;
wire [RAM_COUNT-1:0]                axi_ram_rlast;
wire [RAM_COUNT-1:0]                axi_ram_rvalid;
wire [RAM_COUNT-1:0]                axi_ram_rready;

wire [PORTS*RAM_ID_WIDTH-1:0]    axi_port_desc_awid;
wire [PORTS*AXI_ADDR_WIDTH-1:0]  axi_port_desc_awaddr;
wire [PORTS*8-1:0]               axi_port_desc_awlen;
wire [PORTS*3-1:0]               axi_port_desc_awsize;
wire [PORTS*2-1:0]               axi_port_desc_awburst;
wire [PORTS-1:0]                 axi_port_desc_awlock;
wire [PORTS*4-1:0]               axi_port_desc_awcache;
wire [PORTS*3-1:0]               axi_port_desc_awprot;
wire [PORTS-1:0]                 axi_port_desc_awvalid;
wire [PORTS-1:0]                 axi_port_desc_awready;
wire [PORTS*AXI_DATA_WIDTH-1:0]  axi_port_desc_wdata;
wire [PORTS*AXI_STRB_WIDTH-1:0]  axi_port_desc_wstrb;
wire [PORTS-1:0]                 axi_port_desc_wlast;
wire [PORTS-1:0]                 axi_port_desc_wvalid;
wire [PORTS-1:0]                 axi_port_desc_wready;
wire [PORTS*RAM_ID_WIDTH-1:0]    axi_port_desc_bid;
wire [PORTS*2-1:0]               axi_port_desc_bresp;
wire [PORTS-1:0]                 axi_port_desc_bvalid;
wire [PORTS-1:0]                 axi_port_desc_bready;
wire [PORTS*RAM_ID_WIDTH-1:0]    axi_port_desc_arid;
wire [PORTS*AXI_ADDR_WIDTH-1:0]  axi_port_desc_araddr;
wire [PORTS*8-1:0]               axi_port_desc_arlen;
wire [PORTS*3-1:0]               axi_port_desc_arsize;
wire [PORTS*2-1:0]               axi_port_desc_arburst;
wire [PORTS-1:0]                 axi_port_desc_arlock;
wire [PORTS*4-1:0]               axi_port_desc_arcache;
wire [PORTS*3-1:0]               axi_port_desc_arprot;
wire [PORTS-1:0]                 axi_port_desc_arvalid;
wire [PORTS-1:0]                 axi_port_desc_arready;
wire [PORTS*RAM_ID_WIDTH-1:0]    axi_port_desc_rid;
wire [PORTS*AXI_DATA_WIDTH-1:0]  axi_port_desc_rdata;
wire [PORTS*2-1:0]               axi_port_desc_rresp;
wire [PORTS-1:0]                 axi_port_desc_rlast;
wire [PORTS-1:0]                 axi_port_desc_rvalid;
wire [PORTS-1:0]                 axi_port_desc_rready;

axi_crossbar #(
    .S_COUNT(AXI_S_COUNT),
    .M_COUNT(RAM_COUNT),
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .STRB_WIDTH(AXI_STRB_WIDTH),
    .S_ID_WIDTH(AXI_ID_WIDTH),
    .M_ID_WIDTH(RAM_ID_WIDTH),
    .AWUSER_ENABLE(0),
    .WUSER_ENABLE(0),
    .BUSER_ENABLE(0),
    .ARUSER_ENABLE(0),
    .RUSER_ENABLE(0),
    .S_THREADS({AXI_S_COUNT{32'd2}}),
    .S_ACCEPT({AXI_S_COUNT{32'd16}}),
    .M_REGIONS(1),
    .M_BASE_ADDR(RAM_BASE_ADDR),
    .M_ADDR_WIDTH({RAM_COUNT{32'd16}}),
    .M_CONNECT_READ({RAM_COUNT{{AXI_S_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({RAM_COUNT{{AXI_S_COUNT{1'b1}}}}),
    .M_ISSUE({RAM_COUNT{32'd4}}),
    .M_SECURE({RAM_COUNT{1'b0}})
)
axi_crossbar_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(     {axi_port_dma_awid,     s_axi_awid}),
    .s_axi_awaddr(   {axi_port_dma_awaddr,   s_axi_awaddr}),
    .s_axi_awlen(    {axi_port_dma_awlen,    s_axi_awlen}),
    .s_axi_awsize(   {axi_port_dma_awsize,   s_axi_awsize}),
    .s_axi_awburst(  {axi_port_dma_awburst,  s_axi_awburst}),
    .s_axi_awlock(   {axi_port_dma_awlock,   s_axi_awlock}),
    .s_axi_awcache(  {axi_port_dma_awcache,  s_axi_awcache}),
    .s_axi_awprot(   {axi_port_dma_awprot,   s_axi_awprot}),
    .s_axi_awqos(0),
    .s_axi_awuser(0),
    .s_axi_awvalid(  {axi_port_dma_awvalid,  s_axi_awvalid}),
    .s_axi_awready(  {axi_port_dma_awready,  s_axi_awready}),
    .s_axi_wdata(    {axi_port_dma_wdata,    s_axi_wdata}),
    .s_axi_wstrb(    {axi_port_dma_wstrb,    s_axi_wstrb}),
    .s_axi_wlast(    {axi_port_dma_wlast,    s_axi_wlast}),
    .s_axi_wuser(0),
    .s_axi_wvalid(   {axi_port_dma_wvalid,   s_axi_wvalid}),
    .s_axi_wready(   {axi_port_dma_wready,   s_axi_wready}),
    .s_axi_bid(      {axi_port_dma_bid,      s_axi_bid}),
    .s_axi_bresp(    {axi_port_dma_bresp,    s_axi_bresp}),
    .s_axi_buser(),
    .s_axi_bvalid(   {axi_port_dma_bvalid,   s_axi_bvalid}),
    .s_axi_bready(   {axi_port_dma_bready,   s_axi_bready}),
    .s_axi_arid(     {axi_port_dma_arid,     s_axi_arid}),
    .s_axi_araddr(   {axi_port_dma_araddr,   s_axi_araddr}),
    .s_axi_arlen(    {axi_port_dma_arlen,    s_axi_arlen}),
    .s_axi_arsize(   {axi_port_dma_arsize,   s_axi_arsize}),
    .s_axi_arburst(  {axi_port_dma_arburst,  s_axi_arburst}),
    .s_axi_arlock(   {axi_port_dma_arlock,   s_axi_arlock}),
    .s_axi_arcache(  {axi_port_dma_arcache,  s_axi_arcache}),
    .s_axi_arprot(   {axi_port_dma_arprot,   s_axi_arprot}),
    .s_axi_arqos(0),
    .s_axi_aruser(0),
    .s_axi_arvalid(  {axi_port_dma_arvalid,  s_axi_arvalid}),
    .s_axi_arready(  {axi_port_dma_arready,  s_axi_arready}),
    .s_axi_rid(      {axi_port_dma_rid,      s_axi_rid}),
    .s_axi_rdata(    {axi_port_dma_rdata,    s_axi_rdata}),
    .s_axi_rresp(    {axi_port_dma_rresp,    s_axi_rresp}),
    .s_axi_rlast(    {axi_port_dma_rlast,    s_axi_rlast}),
    .s_axi_ruser(),
    .s_axi_rvalid(   {axi_port_dma_rvalid,   s_axi_rvalid}),
    .s_axi_rready(   {axi_port_dma_rready,   s_axi_rready}),

    .m_axi_awid(     {axi_ram_awid}),
    .m_axi_awaddr(   {axi_ram_awaddr}),
    .m_axi_awlen(    {axi_ram_awlen}),
    .m_axi_awsize(   {axi_ram_awsize}),
    .m_axi_awburst(  {axi_ram_awburst}),
    .m_axi_awlock(   {axi_ram_awlock}),
    .m_axi_awcache(  {axi_ram_awcache}),
    .m_axi_awprot(   {axi_ram_awprot}),
    .m_axi_awqos(),
    .m_axi_awregion(),
    .m_axi_awuser(),
    .m_axi_awvalid(  {axi_ram_awvalid}),
    .m_axi_awready(  {axi_ram_awready}),
    .m_axi_wdata(    {axi_ram_wdata}),
    .m_axi_wstrb(    {axi_ram_wstrb}),
    .m_axi_wlast(    {axi_ram_wlast}),
    .m_axi_wuser(),
    .m_axi_wvalid(   {axi_ram_wvalid}),
    .m_axi_wready(   {axi_ram_wready}),
    .m_axi_bid(      {axi_ram_bid}),
    .m_axi_bresp(    {axi_ram_bresp}),
    .m_axi_buser(0),
    .m_axi_bvalid(   {axi_ram_bvalid}),
    .m_axi_bready(   {axi_ram_bready}),
    .m_axi_arid(     {axi_ram_arid}),
    .m_axi_araddr(   {axi_ram_araddr}),
    .m_axi_arlen(    {axi_ram_arlen}),
    .m_axi_arsize(   {axi_ram_arsize}),
    .m_axi_arburst(  {axi_ram_arburst}),
    .m_axi_arlock(   {axi_ram_arlock}),
    .m_axi_arcache(  {axi_ram_arcache}),
    .m_axi_arprot(   {axi_ram_arprot}),
    .m_axi_arqos(),
    .m_axi_arregion(),
    .m_axi_aruser(),
    .m_axi_arvalid(  {axi_ram_arvalid}),
    .m_axi_arready(  {axi_ram_arready}),
    .m_axi_rid(      {axi_ram_rid}),
    .m_axi_rdata(    {axi_ram_rdata}),
    .m_axi_rresp(    {axi_ram_rresp}),
    .m_axi_rlast(    {axi_ram_rlast}),
    .m_axi_ruser(0),
    .m_axi_rvalid(   {axi_ram_rvalid}),
    .m_axi_rready(   {axi_ram_rready})
);

axi_interconnect #(
    .S_COUNT(1),
    .M_COUNT(2),
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .STRB_WIDTH(AXI_STRB_WIDTH),
    .ID_WIDTH(RAM_ID_WIDTH),
    .AWUSER_ENABLE(0),
    .WUSER_ENABLE(0),
    .BUSER_ENABLE(0),
    .ARUSER_ENABLE(0),
    .RUSER_ENABLE(0),
    .FORWARD_ID(0),
    .M_REGIONS(1),
    .M_BASE_ADDR({23'h004000, 23'h000000}),
    .M_ADDR_WIDTH({2{32'd14}}),
    .M_CONNECT_READ({2{{1{1'b1}}}}),
    .M_CONNECT_WRITE({2{{1{1'b1}}}})
)
axi_interconnect_inst (
    .clk(clk),
    .rst(rst),
    .s_axi_awid(     {axi_ram_awid[RAM_ID_WIDTH-1:0]}),
    .s_axi_awaddr(   {axi_ram_awaddr[AXI_ADDR_WIDTH-1:0]}),
    .s_axi_awlen(    {axi_ram_awlen[7:0]}),
    .s_axi_awsize(   {axi_ram_awsize[2:0]}),
    .s_axi_awburst(  {axi_ram_awburst[1:0]}),
    .s_axi_awlock(   {axi_ram_awlock[0]}),
    .s_axi_awcache(  {axi_ram_awcache[3:0]}),
    .s_axi_awprot(   {axi_ram_awprot[2:0]}),
    .s_axi_awqos(0),
    .s_axi_awuser(0),
    .s_axi_awvalid(  {axi_ram_awvalid[0]}),
    .s_axi_awready(  {axi_ram_awready[0]}),
    .s_axi_wdata(    {axi_ram_wdata[AXI_DATA_WIDTH-1:0]}),
    .s_axi_wstrb(    {axi_ram_wstrb[AXI_STRB_WIDTH-1:0]}),
    .s_axi_wlast(    {axi_ram_wlast[0]}),
    .s_axi_wuser(0),
    .s_axi_wvalid(   {axi_ram_wvalid[0]}),
    .s_axi_wready(   {axi_ram_wready[0]}),
    .s_axi_bid(      {axi_ram_bid[RAM_ID_WIDTH-1:0]}),
    .s_axi_bresp(    {axi_ram_bresp[1:0]}),
    .s_axi_buser(),
    .s_axi_bvalid(   {axi_ram_bvalid[0]}),
    .s_axi_bready(   {axi_ram_bready[0]}),
    .s_axi_arid(     {axi_ram_arid[RAM_ID_WIDTH-1:0]}),
    .s_axi_araddr(   {axi_ram_araddr[AXI_ADDR_WIDTH-1:0]}),
    .s_axi_arlen(    {axi_ram_arlen[7:0]}),
    .s_axi_arsize(   {axi_ram_arsize[2:0]}),
    .s_axi_arburst(  {axi_ram_arburst[1:0]}),
    .s_axi_arlock(   {axi_ram_arlock[0]}),
    .s_axi_arcache(  {axi_ram_arcache[3:0]}),
    .s_axi_arprot(   {axi_ram_arprot[2:0]}),
    .s_axi_arqos(0),
    .s_axi_aruser(0),
    .s_axi_arvalid(  {axi_ram_arvalid[0]}),
    .s_axi_arready(  {axi_ram_arready[0]}),
    .s_axi_rid(      {axi_ram_rid[RAM_ID_WIDTH-1:0]}),
    .s_axi_rdata(    {axi_ram_rdata[AXI_DATA_WIDTH-1:0]}),
    .s_axi_rresp(    {axi_ram_rresp[1:0]}),
    .s_axi_rlast(    {axi_ram_rlast[0]}),
    .s_axi_ruser(),
    .s_axi_rvalid(   {axi_ram_rvalid[0]}),
    .s_axi_rready(   {axi_ram_rready[0]}),

    .m_axi_awid(     {axi_port_desc_awid,     axi_event_awid}),
    .m_axi_awaddr(   {axi_port_desc_awaddr,   axi_event_awaddr}),
    .m_axi_awlen(    {axi_port_desc_awlen,    axi_event_awlen}),
    .m_axi_awsize(   {axi_port_desc_awsize,   axi_event_awsize}),
    .m_axi_awburst(  {axi_port_desc_awburst,  axi_event_awburst}),
    .m_axi_awlock(   {axi_port_desc_awlock,   axi_event_awlock}),
    .m_axi_awcache(  {axi_port_desc_awcache,  axi_event_awcache}),
    .m_axi_awprot(   {axi_port_desc_awprot,   axi_event_awprot}),
    .m_axi_awqos(),
    .m_axi_awuser(),
    .m_axi_awvalid(  {axi_port_desc_awvalid,  axi_event_awvalid}),
    .m_axi_awready(  {axi_port_desc_awready,  axi_event_awready}),
    .m_axi_wdata(    {axi_port_desc_wdata,    axi_event_wdata}),
    .m_axi_wstrb(    {axi_port_desc_wstrb,    axi_event_wstrb}),
    .m_axi_wlast(    {axi_port_desc_wlast,    axi_event_wlast}),
    .m_axi_wuser(),
    .m_axi_wvalid(   {axi_port_desc_wvalid,   axi_event_wvalid}),
    .m_axi_wready(   {axi_port_desc_wready,   axi_event_wready}),
    .m_axi_bid(      {axi_port_desc_bid,      axi_event_bid}),
    .m_axi_bresp(    {axi_port_desc_bresp,    axi_event_bresp}),
    .m_axi_buser(0),
    .m_axi_bvalid(   {axi_port_desc_bvalid,   axi_event_bvalid}),
    .m_axi_bready(   {axi_port_desc_bready,   axi_event_bready}),
    .m_axi_arid(     {axi_port_desc_arid,     axi_event_arid}),
    .m_axi_araddr(   {axi_port_desc_araddr,   axi_event_araddr}),
    .m_axi_arlen(    {axi_port_desc_arlen,    axi_event_arlen}),
    .m_axi_arsize(   {axi_port_desc_arsize,   axi_event_arsize}),
    .m_axi_arburst(  {axi_port_desc_arburst,  axi_event_arburst}),
    .m_axi_arlock(   {axi_port_desc_arlock,   axi_event_arlock}),
    .m_axi_arcache(  {axi_port_desc_arcache,  axi_event_arcache}),
    .m_axi_arprot(   {axi_port_desc_arprot,   axi_event_arprot}),
    .m_axi_arqos(),
    .m_axi_aruser(),
    .m_axi_arvalid(  {axi_port_desc_arvalid,  axi_event_arvalid}),
    .m_axi_arready(  {axi_port_desc_arready,  axi_event_arready}),
    .m_axi_rid(      {axi_port_desc_rid,      axi_event_rid}),
    .m_axi_rdata(    {axi_port_desc_rdata,    axi_event_rdata}),
    .m_axi_rresp(    {axi_port_desc_rresp,    axi_event_rresp}),
    .m_axi_rlast(    {axi_port_desc_rlast,    axi_event_rlast}),
    .m_axi_ruser(0),
    .m_axi_rvalid(   {axi_port_desc_rvalid,   axi_event_rvalid}),
    .m_axi_rready(   {axi_port_desc_rready,   axi_event_rready})
);

generate
    genvar n;

    for (n = 0; n < PORTS; n = n + 1) begin : port

        port #(
            .PCIE_ADDR_WIDTH(PCIE_ADDR_WIDTH),
            .PCIE_DMA_LEN_WIDTH(PCIE_DMA_LEN_WIDTH),
            .PCIE_DMA_TAG_WIDTH(PCIE_DMA_TAG_WIDTH_INT),
            .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
            .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
            .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
            .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
            .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
            .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
            .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
            .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
            .TX_PKT_TABLE_SIZE(TX_PKT_TABLE_SIZE),
            .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
            .RX_PKT_TABLE_SIZE(RX_PKT_TABLE_SIZE),
            .TX_SCHEDULER(TX_SCHEDULER),
            .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
            .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),
            .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
            .PTP_TS_ENABLE(PTP_TS_ENABLE),
            .PTP_TS_WIDTH(PTP_TS_WIDTH),
            .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
            .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
            .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
            .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
            .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
            .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
            .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
            .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
            .AXI_ID_WIDTH(AXI_ID_WIDTH),
            .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
            .AXI_BASE_ADDR(23'h000000),
            .TX_RAM_AXI_BASE_ADDR(23'h000000 + 23'h010000),
            .RX_RAM_AXI_BASE_ADDR(23'h000000 + 23'h020000),
            .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
            .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH)
        )
        port_inst (
            .clk(clk),
            .rst(rst),

            /*
             * TX descriptor dequeue request output
             */
            .m_axis_tx_desc_dequeue_req_queue(tx_port_desc_dequeue_req_queue[n*TX_QUEUE_INDEX_WIDTH +: TX_QUEUE_INDEX_WIDTH]),
            .m_axis_tx_desc_dequeue_req_tag(tx_port_desc_dequeue_req_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .m_axis_tx_desc_dequeue_req_valid(tx_port_desc_dequeue_req_valid[n +: 1]),
            .m_axis_tx_desc_dequeue_req_ready(tx_port_desc_dequeue_req_ready[n +: 1]),

            /*
             * TX descriptor dequeue response input
             */
            .s_axis_tx_desc_dequeue_resp_ptr(tx_port_desc_dequeue_resp_ptr[n*QUEUE_PTR_WIDTH +: QUEUE_PTR_WIDTH]),
            .s_axis_tx_desc_dequeue_resp_addr(tx_port_desc_dequeue_resp_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            .s_axis_tx_desc_dequeue_resp_cpl(tx_port_desc_dequeue_resp_cpl[n*TX_CPL_QUEUE_INDEX_WIDTH +: TX_CPL_QUEUE_INDEX_WIDTH]),
            .s_axis_tx_desc_dequeue_resp_tag(tx_port_desc_dequeue_resp_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .s_axis_tx_desc_dequeue_resp_op_tag(tx_port_desc_dequeue_resp_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .s_axis_tx_desc_dequeue_resp_empty(tx_port_desc_dequeue_resp_empty[n +: 1]),
            .s_axis_tx_desc_dequeue_resp_error(tx_port_desc_dequeue_resp_error[n +: 1]),
            .s_axis_tx_desc_dequeue_resp_valid(tx_port_desc_dequeue_resp_valid[n +: 1]),
            .s_axis_tx_desc_dequeue_resp_ready(tx_port_desc_dequeue_resp_ready[n +: 1]),

            /*
             * TX descriptor dequeue commit output
             */
            .m_axis_tx_desc_dequeue_commit_op_tag(tx_port_desc_dequeue_commit_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .m_axis_tx_desc_dequeue_commit_valid(tx_port_desc_dequeue_commit_valid[n +: 1]),
            .m_axis_tx_desc_dequeue_commit_ready(tx_port_desc_dequeue_commit_ready[n +: 1]),

            /*
             * TX doorbell input
             */
            .s_axis_tx_doorbell_queue(tx_doorbell_queue),
            .s_axis_tx_doorbell_valid(tx_doorbell_valid),

            /*
             * TX completion enqueue request output
             */
            .m_axis_tx_cpl_enqueue_req_queue(tx_port_cpl_enqueue_req_queue[n*TX_CPL_QUEUE_INDEX_WIDTH +: TX_CPL_QUEUE_INDEX_WIDTH]),
            .m_axis_tx_cpl_enqueue_req_tag(tx_port_cpl_enqueue_req_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .m_axis_tx_cpl_enqueue_req_valid(tx_port_cpl_enqueue_req_valid[n +: 1]),
            .m_axis_tx_cpl_enqueue_req_ready(tx_port_cpl_enqueue_req_ready[n +: 1]),

            /*
             * TX completion enqueue response input
             */
            //.s_axis_tx_cpl_enqueue_resp_ptr(),
            .s_axis_tx_cpl_enqueue_resp_addr(tx_port_cpl_enqueue_resp_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            //.s_axis_tx_cpl_enqueue_resp_event(),
            .s_axis_tx_cpl_enqueue_resp_tag(tx_port_cpl_enqueue_resp_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .s_axis_tx_cpl_enqueue_resp_op_tag(tx_port_cpl_enqueue_resp_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .s_axis_tx_cpl_enqueue_resp_full(tx_port_cpl_enqueue_resp_full[n +: 1]),
            .s_axis_tx_cpl_enqueue_resp_error(tx_port_cpl_enqueue_resp_error[n +: 1]),
            .s_axis_tx_cpl_enqueue_resp_valid(tx_port_cpl_enqueue_resp_valid[n +: 1]),
            .s_axis_tx_cpl_enqueue_resp_ready(tx_port_cpl_enqueue_resp_ready[n +: 1]),

            /*
             * TX completion enqueue commit output
             */
            .m_axis_tx_cpl_enqueue_commit_op_tag(tx_port_cpl_enqueue_commit_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .m_axis_tx_cpl_enqueue_commit_valid(tx_port_cpl_enqueue_commit_valid[n +: 1]),
            .m_axis_tx_cpl_enqueue_commit_ready(tx_port_cpl_enqueue_commit_ready[n +: 1]),

            /*
             * RX descriptor dequeue request output
             */
            .m_axis_rx_desc_dequeue_req_queue(rx_port_desc_dequeue_req_queue[n*RX_QUEUE_INDEX_WIDTH +: RX_QUEUE_INDEX_WIDTH]),
            .m_axis_rx_desc_dequeue_req_tag(rx_port_desc_dequeue_req_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .m_axis_rx_desc_dequeue_req_valid(rx_port_desc_dequeue_req_valid[n +: 1]),
            .m_axis_rx_desc_dequeue_req_ready(rx_port_desc_dequeue_req_ready[n +: 1]),

            /*
             * RX descriptor dequeue response input
             */
            .s_axis_rx_desc_dequeue_resp_ptr(rx_port_desc_dequeue_resp_ptr[n*QUEUE_PTR_WIDTH +: QUEUE_PTR_WIDTH]),
            .s_axis_rx_desc_dequeue_resp_addr(rx_port_desc_dequeue_resp_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            .s_axis_rx_desc_dequeue_resp_cpl(rx_port_desc_dequeue_resp_cpl[n*RX_CPL_QUEUE_INDEX_WIDTH +: RX_CPL_QUEUE_INDEX_WIDTH]),
            .s_axis_rx_desc_dequeue_resp_tag(rx_port_desc_dequeue_resp_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .s_axis_rx_desc_dequeue_resp_op_tag(rx_port_desc_dequeue_resp_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .s_axis_rx_desc_dequeue_resp_empty(rx_port_desc_dequeue_resp_empty[n +: 1]),
            .s_axis_rx_desc_dequeue_resp_error(rx_port_desc_dequeue_resp_error[n +: 1]),
            .s_axis_rx_desc_dequeue_resp_valid(rx_port_desc_dequeue_resp_valid[n +: 1]),
            .s_axis_rx_desc_dequeue_resp_ready(rx_port_desc_dequeue_resp_ready[n +: 1]),

            /*
             * RX descriptor dequeue commit output
             */
            .m_axis_rx_desc_dequeue_commit_op_tag(rx_port_desc_dequeue_commit_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .m_axis_rx_desc_dequeue_commit_valid(rx_port_desc_dequeue_commit_valid[n +: 1]),
            .m_axis_rx_desc_dequeue_commit_ready(rx_port_desc_dequeue_commit_ready[n +: 1]),

            /*
             * RX completion enqueue request output
             */
            .m_axis_rx_cpl_enqueue_req_queue(rx_port_cpl_enqueue_req_queue[n*RX_CPL_QUEUE_INDEX_WIDTH +: RX_CPL_QUEUE_INDEX_WIDTH]),
            .m_axis_rx_cpl_enqueue_req_tag(rx_port_cpl_enqueue_req_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .m_axis_rx_cpl_enqueue_req_valid(rx_port_cpl_enqueue_req_valid[n +: 1]),
            .m_axis_rx_cpl_enqueue_req_ready(rx_port_cpl_enqueue_req_ready[n +: 1]),

            /*
             * RX completion enqueue response input
             */
            //.s_axis_rx_cpl_enqueue_resp_ptr(),
            .s_axis_rx_cpl_enqueue_resp_addr(rx_port_cpl_enqueue_resp_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            //.s_axis_rx_cpl_enqueue_resp_event(),
            .s_axis_rx_cpl_enqueue_resp_tag(rx_port_cpl_enqueue_resp_tag[n*QUEUE_REQ_TAG_WIDTH +: QUEUE_REQ_TAG_WIDTH]),
            .s_axis_rx_cpl_enqueue_resp_op_tag(rx_port_cpl_enqueue_resp_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .s_axis_rx_cpl_enqueue_resp_full(rx_port_cpl_enqueue_resp_full[n +: 1]),
            .s_axis_rx_cpl_enqueue_resp_error(rx_port_cpl_enqueue_resp_error[n +: 1]),
            .s_axis_rx_cpl_enqueue_resp_valid(rx_port_cpl_enqueue_resp_valid[n +: 1]),
            .s_axis_rx_cpl_enqueue_resp_ready(rx_port_cpl_enqueue_resp_ready[n +: 1]),

            /*
             * RX completion enqueue commit output
             */
            .m_axis_rx_cpl_enqueue_commit_op_tag(rx_port_cpl_enqueue_commit_op_tag[n*QUEUE_OP_TAG_WIDTH +: QUEUE_OP_TAG_WIDTH]),
            .m_axis_rx_cpl_enqueue_commit_valid(rx_port_cpl_enqueue_commit_valid[n +: 1]),
            .m_axis_rx_cpl_enqueue_commit_ready(rx_port_cpl_enqueue_commit_ready[n +: 1]),

            /*
             * PCIe read descriptor output
             */
            .m_axis_pcie_axi_dma_read_desc_pcie_addr(port_pcie_axi_dma_read_desc_pcie_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            .m_axis_pcie_axi_dma_read_desc_axi_addr(port_pcie_axi_dma_read_desc_axi_addr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .m_axis_pcie_axi_dma_read_desc_len(port_pcie_axi_dma_read_desc_len[n*PCIE_DMA_LEN_WIDTH +: PCIE_DMA_LEN_WIDTH]),
            .m_axis_pcie_axi_dma_read_desc_tag(port_pcie_axi_dma_read_desc_tag[n*PCIE_DMA_TAG_WIDTH_INT +: PCIE_DMA_TAG_WIDTH_INT]),
            .m_axis_pcie_axi_dma_read_desc_valid(port_pcie_axi_dma_read_desc_valid[n +: 1]),
            .m_axis_pcie_axi_dma_read_desc_ready(port_pcie_axi_dma_read_desc_ready[n +: 1]),

            /*
             * PCIe read descriptor status input
             */
            .s_axis_pcie_axi_dma_read_desc_status_tag(port_pcie_axi_dma_read_desc_status_tag[n*PCIE_DMA_TAG_WIDTH_INT +: PCIE_DMA_TAG_WIDTH_INT]),
            .s_axis_pcie_axi_dma_read_desc_status_valid(port_pcie_axi_dma_read_desc_status_valid[n +: 1]),

            /*
             * PCIe write descriptor output
             */
            .m_axis_pcie_axi_dma_write_desc_pcie_addr(port_pcie_axi_dma_write_desc_pcie_addr[n*PCIE_ADDR_WIDTH +: PCIE_ADDR_WIDTH]),
            .m_axis_pcie_axi_dma_write_desc_axi_addr(port_pcie_axi_dma_write_desc_axi_addr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .m_axis_pcie_axi_dma_write_desc_len(port_pcie_axi_dma_write_desc_len[n*PCIE_DMA_LEN_WIDTH +: PCIE_DMA_LEN_WIDTH]),
            .m_axis_pcie_axi_dma_write_desc_tag(port_pcie_axi_dma_write_desc_tag[n*PCIE_DMA_TAG_WIDTH_INT +: PCIE_DMA_TAG_WIDTH_INT]),
            .m_axis_pcie_axi_dma_write_desc_valid(port_pcie_axi_dma_write_desc_valid[n +: 1]),
            .m_axis_pcie_axi_dma_write_desc_ready(port_pcie_axi_dma_write_desc_ready[n +: 1]),

            /*
             * PCIe write descriptor status input
             */
            .s_axis_pcie_axi_dma_write_desc_status_tag(port_pcie_axi_dma_write_desc_status_tag[n*PCIE_DMA_TAG_WIDTH_INT +: PCIE_DMA_TAG_WIDTH_INT]),
            .s_axis_pcie_axi_dma_write_desc_status_valid(port_pcie_axi_dma_write_desc_status_valid[n +: 1]),

            /*
             * AXI-Lite slave interface
             */
            .s_axil_awaddr(axil_port_awaddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_awprot(axil_port_awprot[n*3 +: 3]),
            .s_axil_awvalid(axil_port_awvalid[n +: 1]),
            .s_axil_awready(axil_port_awready[n +: 1]),
            .s_axil_wdata(axil_port_wdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_wstrb(axil_port_wstrb[n*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
            .s_axil_wvalid(axil_port_wvalid[n +: 1]),
            .s_axil_wready(axil_port_wready[n +: 1]),
            .s_axil_bresp(axil_port_bresp[n*2 +: 2]),
            .s_axil_bvalid(axil_port_bvalid[n +: 1]),
            .s_axil_bready(axil_port_bready[n +: 1]),
            .s_axil_araddr(axil_port_araddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_arprot(axil_port_arprot[n*3 +: 3]),
            .s_axil_arvalid(axil_port_arvalid[n +: 1]),
            .s_axil_arready(axil_port_arready[n +: 1]),
            .s_axil_rdata(axil_port_rdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_rresp(axil_port_rresp[n*2 +: 2]),
            .s_axil_rvalid(axil_port_rvalid[n +: 1]),
            .s_axil_rready(axil_port_rready[n +: 1]),

            /*
             * AXI master interface
             */
            .m_axi_awid(axi_port_dma_awid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
            .m_axi_awaddr(axi_port_dma_awaddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .m_axi_awlen(axi_port_dma_awlen[n*8 +: 8]),
            .m_axi_awsize(axi_port_dma_awsize[n*3 +: 3]),
            .m_axi_awburst(axi_port_dma_awburst[n*2 +: 2]),
            .m_axi_awlock(axi_port_dma_awlock[n +: 1]),
            .m_axi_awcache(axi_port_dma_awcache[n*4 +: 4]),
            .m_axi_awprot(axi_port_dma_awprot[n*3 +: 3]),
            .m_axi_awvalid(axi_port_dma_awvalid[n +: 1]),
            .m_axi_awready(axi_port_dma_awready[n +: 1]),
            .m_axi_wdata(axi_port_dma_wdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
            .m_axi_wstrb(axi_port_dma_wstrb[n*AXI_STRB_WIDTH +: AXI_STRB_WIDTH]),
            .m_axi_wlast(axi_port_dma_wlast[n +: 1]),
            .m_axi_wvalid(axi_port_dma_wvalid[n +: 1]),
            .m_axi_wready(axi_port_dma_wready[n +: 1]),
            .m_axi_bid(axi_port_dma_bid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
            .m_axi_bresp(axi_port_dma_bresp[n*2 +: 2]),
            .m_axi_bvalid(axi_port_dma_bvalid[n +: 1]),
            .m_axi_bready(axi_port_dma_bready[n +: 1]),
            .m_axi_arid(axi_port_dma_arid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
            .m_axi_araddr(axi_port_dma_araddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .m_axi_arlen(axi_port_dma_arlen[n*8 +: 8]),
            .m_axi_arsize(axi_port_dma_arsize[n*3 +: 3]),
            .m_axi_arburst(axi_port_dma_arburst[n*2 +: 2]),
            .m_axi_arlock(axi_port_dma_arlock[n +: 1]),
            .m_axi_arcache(axi_port_dma_arcache[n*4 +: 4]),
            .m_axi_arprot(axi_port_dma_arprot[n*3 +: 3]),
            .m_axi_arvalid(axi_port_dma_arvalid[n +: 1]),
            .m_axi_arready(axi_port_dma_arready[n +: 1]),
            .m_axi_rid(axi_port_dma_rid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
            .m_axi_rdata(axi_port_dma_rdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
            .m_axi_rresp(axi_port_dma_rresp[n*2 +: 2]),
            .m_axi_rlast(axi_port_dma_rlast[n +: 1]),
            .m_axi_rvalid(axi_port_dma_rvalid[n +: 1]),
            .m_axi_rready(axi_port_dma_rready[n +: 1]),

            /*
             * AXI slave inteface
             */
            .s_axi_awid(axi_port_desc_awid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_awaddr(axi_port_desc_awaddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .s_axi_awlen(axi_port_desc_awlen[n*8 +: 8]),
            .s_axi_awsize(axi_port_desc_awsize[n*3 +: 3]),
            .s_axi_awburst(axi_port_desc_awburst[n*2 +: 2]),
            .s_axi_awlock(axi_port_desc_awlock[n +: 1]),
            .s_axi_awcache(axi_port_desc_awcache[n*4 +: 4]),
            .s_axi_awprot(axi_port_desc_awprot[n*3 +: 3]),
            .s_axi_awvalid(axi_port_desc_awvalid[n +: 1]),
            .s_axi_awready(axi_port_desc_awready[n +: 1]),
            .s_axi_wdata(axi_port_desc_wdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
            .s_axi_wstrb(axi_port_desc_wstrb[n*AXI_STRB_WIDTH +: AXI_STRB_WIDTH]),
            .s_axi_wlast(axi_port_desc_wlast[n +: 1]),
            .s_axi_wvalid(axi_port_desc_wvalid[n +: 1]),
            .s_axi_wready(axi_port_desc_wready[n +: 1]),
            .s_axi_bid(axi_port_desc_bid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_bresp(axi_port_desc_bresp[n*2 +: 2]),
            .s_axi_bvalid(axi_port_desc_bvalid[n +: 1]),
            .s_axi_bready(axi_port_desc_bready[n +: 1]),
            .s_axi_arid(axi_port_desc_arid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_araddr(axi_port_desc_araddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .s_axi_arlen(axi_port_desc_arlen[n*8 +: 8]),
            .s_axi_arsize(axi_port_desc_arsize[n*3 +: 3]),
            .s_axi_arburst(axi_port_desc_arburst[n*2 +: 2]),
            .s_axi_arlock(axi_port_desc_arlock[n +: 1]),
            .s_axi_arcache(axi_port_desc_arcache[n*4 +: 4]),
            .s_axi_arprot(axi_port_desc_arprot[n*3 +: 3]),
            .s_axi_arvalid(axi_port_desc_arvalid[n +: 1]),
            .s_axi_arready(axi_port_desc_arready[n +: 1]),
            .s_axi_rid(axi_port_desc_rid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_rdata(axi_port_desc_rdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
            .s_axi_rresp(axi_port_desc_rresp[n*2 +: 2]),
            .s_axi_rlast(axi_port_desc_rlast[n +: 1]),
            .s_axi_rvalid(axi_port_desc_rvalid[n +: 1]),
            .s_axi_rready(axi_port_desc_rready[n +: 1]),

            /*
             * Transmit data output
             */
            .tx_axis_tdata(tx_axis_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
            .tx_axis_tkeep(tx_axis_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
            .tx_axis_tvalid(tx_axis_tvalid[n +: 1]),
            .tx_axis_tready(tx_axis_tready[n +: 1]),
            .tx_axis_tlast(tx_axis_tlast[n +: 1]),
            .tx_axis_tuser(tx_axis_tuser[n +: 1]),

            /*
             * Transmit timestamp input
             */
            .s_axis_tx_ptp_ts_96(s_axis_tx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
            .s_axis_tx_ptp_ts_valid(s_axis_tx_ptp_ts_valid[n +: 1]),
            .s_axis_tx_ptp_ts_ready(s_axis_tx_ptp_ts_ready[n +: 1]),

            /*
             * Receive data input
             */
            .rx_axis_tdata(rx_axis_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
            .rx_axis_tkeep(rx_axis_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
            .rx_axis_tvalid(rx_axis_tvalid[n +: 1]),
            .rx_axis_tready(rx_axis_tready[n +: 1]),
            .rx_axis_tlast(rx_axis_tlast[n +: 1]),
            .rx_axis_tuser(rx_axis_tuser[n +: 1]),

            /*
             * Receive timestamp input
             */
            .s_axis_rx_ptp_ts_96(s_axis_rx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
            .s_axis_rx_ptp_ts_valid(s_axis_rx_ptp_ts_valid[n +: 1]),
            .s_axis_rx_ptp_ts_ready(s_axis_rx_ptp_ts_ready[n +: 1]),

            /*
             * PTP clock
             */
            .ptp_ts_96(ptp_ts_96),
            .ptp_ts_step(ptp_ts_step)
        );

    end

    for (n = 1; n < RAM_COUNT; n = n + 1) begin : ram

        axi_ram #(
            .DATA_WIDTH(AXI_DATA_WIDTH),
            //.ADDR_WIDTH(RAM_ADDR_WIDTH),
            .ADDR_WIDTH($clog2(RAM_SIZE)),
            .STRB_WIDTH(AXI_STRB_WIDTH),
            .ID_WIDTH(RAM_ID_WIDTH),
            .PIPELINE_OUTPUT(1)
        )
        axi_ram_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_awid(axi_ram_awid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_awaddr(axi_ram_awaddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .s_axi_awlen(axi_ram_awlen[n*8 +: 8]),
            .s_axi_awsize(axi_ram_awsize[n*3 +: 3]),
            .s_axi_awburst(axi_ram_awburst[n*2 +: 2]),
            .s_axi_awlock(axi_ram_awlock[n +: 1]),
            .s_axi_awcache(axi_ram_awcache[n*4 +: 4]),
            .s_axi_awprot(axi_ram_awprot[n*3 +: 3]),
            .s_axi_awvalid(axi_ram_awvalid[n +: 1]),
            .s_axi_awready(axi_ram_awready[n +: 1]),
            .s_axi_wdata(axi_ram_wdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
            .s_axi_wstrb(axi_ram_wstrb[n*AXI_STRB_WIDTH +: AXI_STRB_WIDTH]),
            .s_axi_wlast(axi_ram_wlast[n +: 1]),
            .s_axi_wvalid(axi_ram_wvalid[n +: 1]),
            .s_axi_wready(axi_ram_wready[n +: 1]),
            .s_axi_bid(axi_ram_bid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_bresp(axi_ram_bresp[n*2 +: 2]),
            .s_axi_bvalid(axi_ram_bvalid[n +: 1]),
            .s_axi_bready(axi_ram_bready[n +: 1]),
            .s_axi_arid(axi_ram_arid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_araddr(axi_ram_araddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
            .s_axi_arlen(axi_ram_arlen[n*8 +: 8]),
            .s_axi_arsize(axi_ram_arsize[n*3 +: 3]),
            .s_axi_arburst(axi_ram_arburst[n*2 +: 2]),
            .s_axi_arlock(axi_ram_arlock[n +: 1]),
            .s_axi_arcache(axi_ram_arcache[n*4 +: 4]),
            .s_axi_arprot(axi_ram_arprot[n*3 +: 3]),
            .s_axi_arvalid(axi_ram_arvalid[n +: 1]),
            .s_axi_arready(axi_ram_arready[n +: 1]),
            .s_axi_rid(axi_ram_rid[n*RAM_ID_WIDTH +: RAM_ID_WIDTH]),
            .s_axi_rdata(axi_ram_rdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
            .s_axi_rresp(axi_ram_rresp[n*2 +: 2]),
            .s_axi_rlast(axi_ram_rlast[n +: 1]),
            .s_axi_rvalid(axi_ram_rvalid[n +: 1]),
            .s_axi_rready(axi_ram_rready[n +: 1])
        );

    end

endgenerate

endmodule
