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

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC Interface
 */
module mqnic_interface #
(
    // Number of ports
    parameter PORTS = 1,
    // DMA address width
    parameter DMA_ADDR_WIDTH = 64,
    // DMA length field width
    parameter DMA_LEN_WIDTH = 16,
    // DMA tag field width
    parameter DMA_TAG_WIDTH = 8,
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
    // Pipeline setting (event queue)
    parameter EVENT_QUEUE_PIPELINE = 3,
    // Pipeline setting (transmit queue)
    parameter TX_QUEUE_PIPELINE = 3,
    // Pipeline setting (receive queue)
    parameter RX_QUEUE_PIPELINE = 3,
    // Pipeline setting (transmit completion queue)
    parameter TX_CPL_QUEUE_PIPELINE = 3,
    // Pipeline setting (receive completion queue)
    parameter RX_CPL_QUEUE_PIPELINE = 3,
    // Transmit descriptor table size (number of in-flight operations)
    parameter TX_DESC_TABLE_SIZE = 16,
    // Receive descriptor table size (number of in-flight operations)
    parameter RX_DESC_TABLE_SIZE = 16,
    // Max number of in-flight descriptor requests (transmit)
    parameter TX_MAX_DESC_REQ = 16,
    // Max number of in-flight descriptor requests (transmit)
    parameter RX_MAX_DESC_REQ = 16,
    // Scheduler operation table size
    parameter TX_SCHEDULER_OP_TABLE_SIZE = 32,
    // Scheduler pipeline setting
    parameter TX_SCHEDULER_PIPELINE = 3,
    // Scheduler TDMA index width
    parameter TDMA_INDEX_WIDTH = 8,
    // Interrupt number width
    parameter INT_WIDTH = 8,
    // Queue element pointer width
    parameter QUEUE_PTR_WIDTH = 16,
    // Queue log size field width
    parameter LOG_QUEUE_SIZE_WIDTH = 4,
    // Log desc block size field width
    parameter LOG_BLOCK_SIZE_WIDTH = 2,
    // Enable PTP timestamping
    parameter PTP_TS_ENABLE = 1,
    // PTP timestamp width
    parameter PTP_TS_WIDTH = 96,
    // Enable TX checksum offload
    parameter TX_CHECKSUM_ENABLE = 1,
    // Enable RX RSS
    parameter RX_RSS_ENABLE = 1,
    // Enable RX hashing
    parameter RX_HASH_ENABLE = 1,
    // Enable RX checksum offload
    parameter RX_CHECKSUM_ENABLE = 1,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // DMA RAM segment count
    parameter SEG_COUNT = 2,
    // DMA RAM segment data width
    parameter SEG_DATA_WIDTH = 64,
    // DMA RAM segment address width
    parameter SEG_ADDR_WIDTH = 8,
    // DMA RAM segment byte enable width
    parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8,
    // DMA RAM segment select width
    parameter RAM_SEL_WIDTH = $clog2(PORTS),
    // DMA RAM address width
    parameter RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+$clog2(SEG_COUNT)+$clog2(SEG_BE_WIDTH),
    // DMA RAM pipeline stages
    parameter RAM_PIPELINE = 2,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // Max transmit packet size
    parameter MAX_TX_SIZE = 2048,
    // Max receive packet size
    parameter MAX_RX_SIZE = 2048,
    // DMA TX RAM size
    parameter TX_RAM_SIZE = 8*MAX_TX_SIZE,
    // DMA RX RAM size
    parameter RX_RAM_SIZE = 8*MAX_RX_SIZE
)
(
    input  wire                                clk,
    input  wire                                rst,

    /*
     * DMA read descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]           m_axis_ctrl_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]            m_axis_ctrl_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]           m_axis_ctrl_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]            m_axis_ctrl_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]            m_axis_ctrl_dma_read_desc_tag,
    output wire                                m_axis_ctrl_dma_read_desc_valid,
    input  wire                                m_axis_ctrl_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]            s_axis_ctrl_dma_read_desc_status_tag,
    input  wire [3:0]                          s_axis_ctrl_dma_read_desc_status_error,
    input  wire                                s_axis_ctrl_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]           m_axis_ctrl_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]            m_axis_ctrl_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]           m_axis_ctrl_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]            m_axis_ctrl_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]            m_axis_ctrl_dma_write_desc_tag,
    output wire                                m_axis_ctrl_dma_write_desc_valid,
    input  wire                                m_axis_ctrl_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]            s_axis_ctrl_dma_write_desc_status_tag,
    input  wire [3:0]                          s_axis_ctrl_dma_write_desc_status_error,
    input  wire                                s_axis_ctrl_dma_write_desc_status_valid,

    /*
     * DMA read descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]           m_axis_data_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]            m_axis_data_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]           m_axis_data_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]            m_axis_data_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]            m_axis_data_dma_read_desc_tag,
    output wire                                m_axis_data_dma_read_desc_valid,
    input  wire                                m_axis_data_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]            s_axis_data_dma_read_desc_status_tag,
    input  wire [3:0]                          s_axis_data_dma_read_desc_status_error,
    input  wire                                s_axis_data_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]           m_axis_data_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]            m_axis_data_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]           m_axis_data_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]            m_axis_data_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]            m_axis_data_dma_write_desc_tag,
    output wire                                m_axis_data_dma_write_desc_valid,
    input  wire                                m_axis_data_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]            s_axis_data_dma_write_desc_status_tag,
    input  wire [3:0]                          s_axis_data_dma_write_desc_status_error,
    input  wire                                s_axis_data_dma_write_desc_status_valid,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]          s_axil_awaddr,
    input  wire [2:0]                          s_axil_awprot,
    input  wire                                s_axil_awvalid,
    output wire                                s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]          s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]          s_axil_wstrb,
    input  wire                                s_axil_wvalid,
    output wire                                s_axil_wready,
    output wire [1:0]                          s_axil_bresp,
    output wire                                s_axil_bvalid,
    input  wire                                s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]          s_axil_araddr,
    input  wire [2:0]                          s_axil_arprot,
    input  wire                                s_axil_arvalid,
    output wire                                s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]          s_axil_rdata,
    output wire [1:0]                          s_axil_rresp,
    output wire                                s_axil_rvalid,
    input  wire                                s_axil_rready,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_ADDR_WIDTH-1:0]          m_axil_csr_awaddr,
    output wire [2:0]                          m_axil_csr_awprot,
    output wire                                m_axil_csr_awvalid,
    input  wire                                m_axil_csr_awready,
    output wire [AXIL_DATA_WIDTH-1:0]          m_axil_csr_wdata,
    output wire [AXIL_STRB_WIDTH-1:0]          m_axil_csr_wstrb,
    output wire                                m_axil_csr_wvalid,
    input  wire                                m_axil_csr_wready,
    input  wire [1:0]                          m_axil_csr_bresp,
    input  wire                                m_axil_csr_bvalid,
    output wire                                m_axil_csr_bready,
    output wire [AXIL_ADDR_WIDTH-1:0]          m_axil_csr_araddr,
    output wire [2:0]                          m_axil_csr_arprot,
    output wire                                m_axil_csr_arvalid,
    input  wire                                m_axil_csr_arready,
    input  wire [AXIL_DATA_WIDTH-1:0]          m_axil_csr_rdata,
    input  wire [1:0]                          m_axil_csr_rresp,
    input  wire                                m_axil_csr_rvalid,
    output wire                                m_axil_csr_rready,

    /*
     * RAM interface (control)
     */
    input  wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]  ctrl_dma_ram_wr_cmd_sel,
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]   ctrl_dma_ram_wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ctrl_dma_ram_wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] ctrl_dma_ram_wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                ctrl_dma_ram_wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                ctrl_dma_ram_wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                ctrl_dma_ram_wr_done,
    input  wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]  ctrl_dma_ram_rd_cmd_sel,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] ctrl_dma_ram_rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                ctrl_dma_ram_rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                ctrl_dma_ram_rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] ctrl_dma_ram_rd_resp_data,
    output wire [SEG_COUNT-1:0]                ctrl_dma_ram_rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                ctrl_dma_ram_rd_resp_ready,

    /*
     * RAM interface (data)
     */
    input  wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]  data_dma_ram_wr_cmd_sel,
    input  wire [SEG_COUNT*SEG_BE_WIDTH-1:0]   data_dma_ram_wr_cmd_be,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] data_dma_ram_wr_cmd_addr,
    input  wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] data_dma_ram_wr_cmd_data,
    input  wire [SEG_COUNT-1:0]                data_dma_ram_wr_cmd_valid,
    output wire [SEG_COUNT-1:0]                data_dma_ram_wr_cmd_ready,
    output wire [SEG_COUNT-1:0]                data_dma_ram_wr_done,
    input  wire [SEG_COUNT*RAM_SEL_WIDTH-1:0]  data_dma_ram_rd_cmd_sel,
    input  wire [SEG_COUNT*SEG_ADDR_WIDTH-1:0] data_dma_ram_rd_cmd_addr,
    input  wire [SEG_COUNT-1:0]                data_dma_ram_rd_cmd_valid,
    output wire [SEG_COUNT-1:0]                data_dma_ram_rd_cmd_ready,
    output wire [SEG_COUNT*SEG_DATA_WIDTH-1:0] data_dma_ram_rd_resp_data,
    output wire [SEG_COUNT-1:0]                data_dma_ram_rd_resp_valid,
    input  wire [SEG_COUNT-1:0]                data_dma_ram_rd_resp_ready,

    /*
     * Transmit data output
     */
    output wire [PORTS*AXIS_DATA_WIDTH-1:0]    tx_axis_tdata,
    output wire [PORTS*AXIS_KEEP_WIDTH-1:0]    tx_axis_tkeep,
    output wire [PORTS-1:0]                    tx_axis_tvalid,
    input  wire [PORTS-1:0]                    tx_axis_tready,
    output wire [PORTS-1:0]                    tx_axis_tlast,
    output wire [PORTS-1:0]                    tx_axis_tuser,

    /*
     * Transmit timestamp input
     */
    input  wire [PORTS*PTP_TS_WIDTH-1:0]       s_axis_tx_ptp_ts_96,
    input  wire [PORTS-1:0]                    s_axis_tx_ptp_ts_valid,
    output wire [PORTS-1:0]                    s_axis_tx_ptp_ts_ready,

    /*
     * Receive data input
     */
    input  wire [PORTS*AXIS_DATA_WIDTH-1:0]    rx_axis_tdata,
    input  wire [PORTS*AXIS_KEEP_WIDTH-1:0]    rx_axis_tkeep,
    input  wire [PORTS-1:0]                    rx_axis_tvalid,
    output wire [PORTS-1:0]                    rx_axis_tready,
    input  wire [PORTS-1:0]                    rx_axis_tlast,
    input  wire [PORTS-1:0]                    rx_axis_tuser,

    /*
     * Receive timestamp input
     */
    input  wire [PORTS*PTP_TS_WIDTH-1:0]       s_axis_rx_ptp_ts_96,
    input  wire [PORTS-1:0]                    s_axis_rx_ptp_ts_valid,
    output wire [PORTS-1:0]                    s_axis_rx_ptp_ts_ready,

    /*
     * PTP clock
     */
    input  wire [95:0]                         ptp_ts_96,
    input  wire                                ptp_ts_step,

    /*
     * MSI interrupts
     */
    output wire [31:0]                         msi_irq
);

parameter DESC_SIZE = 16;
parameter CPL_SIZE = 32;
parameter EVENT_SIZE = 32;

parameter AXIS_DESC_DATA_WIDTH = DESC_SIZE*8;
parameter AXIS_DESC_KEEP_WIDTH = AXIS_DESC_DATA_WIDTH/8;

parameter EVENT_SOURCE_WIDTH = 16;
parameter EVENT_TYPE_WIDTH = 16;

parameter MAX_DESC_TABLE_SIZE = TX_DESC_TABLE_SIZE > RX_DESC_TABLE_SIZE ? TX_DESC_TABLE_SIZE : RX_DESC_TABLE_SIZE;

parameter REQ_TAG_WIDTH = $clog2(MAX_DESC_TABLE_SIZE) + 1 + $clog2(PORTS+1);
parameter DESC_REQ_TAG_WIDTH = $clog2(MAX_DESC_TABLE_SIZE) + 1 + $clog2(PORTS+1);

parameter QUEUE_REQ_TAG_WIDTH = $clog2(MAX_DESC_TABLE_SIZE) + 1 + $clog2(PORTS+1);
parameter QUEUE_OP_TAG_WIDTH = 6;

parameter DMA_TAG_WIDTH_INT = DMA_TAG_WIDTH - $clog2(PORTS);

parameter QUEUE_INDEX_WIDTH = TX_QUEUE_INDEX_WIDTH > RX_QUEUE_INDEX_WIDTH ? TX_QUEUE_INDEX_WIDTH : RX_QUEUE_INDEX_WIDTH;
parameter CPL_QUEUE_INDEX_WIDTH = TX_CPL_QUEUE_INDEX_WIDTH > RX_CPL_QUEUE_INDEX_WIDTH ? TX_CPL_QUEUE_INDEX_WIDTH : RX_CPL_QUEUE_INDEX_WIDTH;

parameter PORT_DESC_REQ_TAG_WIDTH = DESC_REQ_TAG_WIDTH - $clog2(PORTS+1);

parameter AXIL_CSR_ADDR_WIDTH = AXIL_ADDR_WIDTH-5-$clog2((PORTS+3)/8);
parameter AXIL_CTRL_ADDR_WIDTH = AXIL_ADDR_WIDTH-5-$clog2((PORTS+3)/8);
parameter AXIL_EQM_ADDR_WIDTH = AXIL_ADDR_WIDTH-4-$clog2((PORTS+3)/8);
parameter AXIL_TX_QM_ADDR_WIDTH = AXIL_ADDR_WIDTH-3-$clog2((PORTS+3)/8);
parameter AXIL_TX_CQM_ADDR_WIDTH = AXIL_ADDR_WIDTH-3-$clog2((PORTS+3)/8);
parameter AXIL_RX_QM_ADDR_WIDTH = AXIL_ADDR_WIDTH-4-$clog2((PORTS+3)/8);
parameter AXIL_RX_CQM_ADDR_WIDTH = AXIL_ADDR_WIDTH-4-$clog2((PORTS+3)/8);
parameter AXIL_PORT_ADDR_WIDTH = AXIL_ADDR_WIDTH-3-$clog2((PORTS+3)/8);

parameter AXIL_CSR_BASE_ADDR = 0;
parameter AXIL_CTRL_BASE_ADDR = AXIL_CSR_BASE_ADDR + 2**AXIL_CSR_ADDR_WIDTH;
parameter AXIL_EQM_BASE_ADDR = AXIL_CTRL_BASE_ADDR + 2**AXIL_CTRL_ADDR_WIDTH;
parameter AXIL_TX_QM_BASE_ADDR = AXIL_EQM_BASE_ADDR + 2**AXIL_EQM_ADDR_WIDTH;
parameter AXIL_TX_CQM_BASE_ADDR = AXIL_TX_QM_BASE_ADDR + 2**AXIL_TX_QM_ADDR_WIDTH;
parameter AXIL_RX_QM_BASE_ADDR = AXIL_TX_CQM_BASE_ADDR + 2**AXIL_TX_CQM_ADDR_WIDTH;
parameter AXIL_RX_CQM_BASE_ADDR = AXIL_RX_QM_BASE_ADDR + 2**AXIL_RX_QM_ADDR_WIDTH;
parameter AXIL_PORT_BASE_ADDR = AXIL_RX_CQM_BASE_ADDR + 2**AXIL_RX_CQM_ADDR_WIDTH;

parameter PORT_CTRL_ADDR_WIDTH = AXIL_CTRL_ADDR_WIDTH-$clog2(PORTS+1);

// parameter sizing helpers
function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

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

// DMA
wire [PORTS*DMA_ADDR_WIDTH-1:0]    port_dma_read_desc_dma_addr;
wire [PORTS*RAM_ADDR_WIDTH-1:0]    port_dma_read_desc_ram_addr;
wire [PORTS*DMA_LEN_WIDTH-1:0]     port_dma_read_desc_len;
wire [PORTS*DMA_TAG_WIDTH_INT-1:0] port_dma_read_desc_tag;
wire [PORTS-1:0]                   port_dma_read_desc_valid;
wire [PORTS-1:0]                   port_dma_read_desc_ready;

wire [PORTS*DMA_TAG_WIDTH_INT-1:0] port_dma_read_desc_status_tag;
wire [PORTS*4-1:0]                 port_dma_read_desc_status_error;
wire [PORTS-1:0]                   port_dma_read_desc_status_valid;

wire [PORTS*DMA_ADDR_WIDTH-1:0]    port_dma_write_desc_dma_addr;
wire [PORTS*RAM_ADDR_WIDTH-1:0]    port_dma_write_desc_ram_addr;
wire [PORTS*DMA_LEN_WIDTH-1:0]     port_dma_write_desc_len;
wire [PORTS*DMA_TAG_WIDTH_INT-1:0] port_dma_write_desc_tag;
wire [PORTS-1:0]                   port_dma_write_desc_valid;
wire [PORTS-1:0]                   port_dma_write_desc_ready;

wire [PORTS*DMA_TAG_WIDTH_INT-1:0] port_dma_write_desc_status_tag;
wire [PORTS*4-1:0]                 port_dma_write_desc_status_error;
wire [PORTS-1:0]                   port_dma_write_desc_status_valid;

wire [PORTS*SEG_COUNT*SEG_BE_WIDTH-1:0]    port_dma_ram_wr_cmd_be;
wire [PORTS*SEG_COUNT*SEG_ADDR_WIDTH-1:0]  port_dma_ram_wr_cmd_addr;
wire [PORTS*SEG_COUNT*SEG_DATA_WIDTH-1:0]  port_dma_ram_wr_cmd_data;
wire [PORTS*SEG_COUNT-1:0]                 port_dma_ram_wr_cmd_valid;
wire [PORTS*SEG_COUNT-1:0]                 port_dma_ram_wr_cmd_ready;
wire [PORTS*SEG_COUNT-1:0]                 port_dma_ram_wr_done;
wire [PORTS*SEG_COUNT*SEG_ADDR_WIDTH-1:0]  port_dma_ram_rd_cmd_addr;
wire [PORTS*SEG_COUNT-1:0]                 port_dma_ram_rd_cmd_valid;
wire [PORTS*SEG_COUNT-1:0]                 port_dma_ram_rd_cmd_ready;
wire [PORTS*SEG_COUNT*SEG_DATA_WIDTH-1:0]  port_dma_ram_rd_resp_data;
wire [PORTS*SEG_COUNT-1:0]                 port_dma_ram_rd_resp_valid;
wire [PORTS*SEG_COUNT-1:0]                 port_dma_ram_rd_resp_ready;

// Queue management
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    event_enqueue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      event_enqueue_req_tag;
wire                                event_enqueue_req_valid;
wire                                event_enqueue_req_ready;

wire [DMA_ADDR_WIDTH-1:0]           event_enqueue_resp_addr;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      event_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       event_enqueue_resp_op_tag;
wire                                event_enqueue_resp_full;
wire                                event_enqueue_resp_error;
wire                                event_enqueue_resp_valid;
wire                                event_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       event_enqueue_commit_op_tag;
wire                                event_enqueue_commit_valid;
wire                                event_enqueue_commit_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        tx_desc_dequeue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_desc_dequeue_req_tag;
wire                                tx_desc_dequeue_req_valid;
wire                                tx_desc_dequeue_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        tx_desc_dequeue_resp_queue;
wire [QUEUE_PTR_WIDTH-1:0]          tx_desc_dequeue_resp_ptr;
wire [DMA_ADDR_WIDTH-1:0]           tx_desc_dequeue_resp_addr;
wire [LOG_BLOCK_SIZE_WIDTH-1:0]     tx_desc_dequeue_resp_block_size;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    tx_desc_dequeue_resp_cpl;
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

wire [CPL_QUEUE_INDEX_WIDTH-1:0]    tx_cpl_enqueue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_cpl_enqueue_req_tag;
wire                                tx_cpl_enqueue_req_valid;
wire                                tx_cpl_enqueue_req_ready;

wire [DMA_ADDR_WIDTH-1:0]           tx_cpl_enqueue_resp_addr;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      tx_cpl_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_cpl_enqueue_resp_op_tag;
wire                                tx_cpl_enqueue_resp_full;
wire                                tx_cpl_enqueue_resp_error;
wire                                tx_cpl_enqueue_resp_valid;
wire                                tx_cpl_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       tx_cpl_enqueue_commit_op_tag;
wire                                tx_cpl_enqueue_commit_valid;
wire                                tx_cpl_enqueue_commit_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        rx_desc_dequeue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_desc_dequeue_req_tag;
wire                                rx_desc_dequeue_req_valid;
wire                                rx_desc_dequeue_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]        rx_desc_dequeue_resp_queue;
wire [QUEUE_PTR_WIDTH-1:0]          rx_desc_dequeue_resp_ptr;
wire [DMA_ADDR_WIDTH-1:0]           rx_desc_dequeue_resp_addr;
wire [LOG_BLOCK_SIZE_WIDTH-1:0]     rx_desc_dequeue_resp_block_size;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]    rx_desc_dequeue_resp_cpl;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_desc_dequeue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_desc_dequeue_resp_op_tag;
wire                                rx_desc_dequeue_resp_empty;
wire                                rx_desc_dequeue_resp_error;
wire                                rx_desc_dequeue_resp_valid;
wire                                rx_desc_dequeue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_desc_dequeue_commit_op_tag;
wire                                rx_desc_dequeue_commit_valid;
wire                                rx_desc_dequeue_commit_ready;

wire [CPL_QUEUE_INDEX_WIDTH-1:0]    rx_cpl_enqueue_req_queue;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_cpl_enqueue_req_tag;
wire                                rx_cpl_enqueue_req_valid;
wire                                rx_cpl_enqueue_req_ready;

wire [DMA_ADDR_WIDTH-1:0]           rx_cpl_enqueue_resp_addr;
wire [QUEUE_REQ_TAG_WIDTH-1:0]      rx_cpl_enqueue_resp_tag;
wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_cpl_enqueue_resp_op_tag;
wire                                rx_cpl_enqueue_resp_full;
wire                                rx_cpl_enqueue_resp_error;
wire                                rx_cpl_enqueue_resp_valid;
wire                                rx_cpl_enqueue_resp_ready;

wire [QUEUE_OP_TAG_WIDTH-1:0]       rx_cpl_enqueue_commit_op_tag;
wire                                rx_cpl_enqueue_commit_valid;
wire                                rx_cpl_enqueue_commit_ready;

// descriptor and completion
wire [0:0]                               desc_req_sel;
wire [QUEUE_INDEX_WIDTH-1:0]             desc_req_queue;
wire [DESC_REQ_TAG_WIDTH-1:0]            desc_req_tag;
wire                                     desc_req_valid;
wire                                     desc_req_ready;

wire [QUEUE_INDEX_WIDTH-1:0]             desc_req_status_queue;
wire [QUEUE_PTR_WIDTH-1:0]               desc_req_status_ptr;
wire [CPL_QUEUE_INDEX_WIDTH-1:0]         desc_req_status_cpl;
wire [DESC_REQ_TAG_WIDTH-1:0]            desc_req_status_tag;
wire                                     desc_req_status_empty;
wire                                     desc_req_status_error;
wire                                     desc_req_status_valid;

wire [AXIS_DESC_DATA_WIDTH-1:0]          axis_desc_tdata;
wire [AXIS_DESC_KEEP_WIDTH-1:0]          axis_desc_tkeep;
wire                                     axis_desc_tvalid;
wire                                     axis_desc_tready;
wire                                     axis_desc_tlast;
wire [DESC_REQ_TAG_WIDTH-1:0]            axis_desc_tid;
wire                                     axis_desc_tuser;

wire [PORTS*1-1:0]                       port_desc_req_sel;
wire [PORTS*QUEUE_INDEX_WIDTH-1:0]       port_desc_req_queue;
wire [PORTS*PORT_DESC_REQ_TAG_WIDTH-1:0] port_desc_req_tag;
wire [PORTS-1:0]                         port_desc_req_valid;
wire [PORTS-1:0]                         port_desc_req_ready;

wire [PORTS*QUEUE_INDEX_WIDTH-1:0]       port_desc_req_status_queue;
wire [PORTS*QUEUE_PTR_WIDTH-1:0]         port_desc_req_status_ptr;
wire [PORTS*CPL_QUEUE_INDEX_WIDTH-1:0]   port_desc_req_status_cpl;
wire [PORTS*PORT_DESC_REQ_TAG_WIDTH-1:0] port_desc_req_status_tag;
wire [PORTS-1:0]                         port_desc_req_status_empty;
wire [PORTS-1:0]                         port_desc_req_status_error;
wire [PORTS-1:0]                         port_desc_req_status_valid;

wire [PORTS*AXIS_DESC_DATA_WIDTH-1:0]    port_axis_desc_tdata;
wire [PORTS*AXIS_DESC_KEEP_WIDTH-1:0]    port_axis_desc_tkeep;
wire [PORTS-1:0]                         port_axis_desc_tvalid;
wire [PORTS-1:0]                         port_axis_desc_tready;
wire [PORTS-1:0]                         port_axis_desc_tlast;
wire [PORTS*PORT_DESC_REQ_TAG_WIDTH-1:0] port_axis_desc_tid;
wire [PORTS-1:0]                         port_axis_desc_tuser;

wire [1:0]                               cpl_req_sel;
wire [QUEUE_INDEX_WIDTH-1:0]             cpl_req_queue;
wire [DESC_REQ_TAG_WIDTH-1:0]            cpl_req_tag;
wire [CPL_SIZE*8-1:0]                    cpl_req_data;
wire                                     cpl_req_valid;
wire                                     cpl_req_ready;

wire [DESC_REQ_TAG_WIDTH-1:0]            cpl_req_status_tag;
wire                                     cpl_req_status_full;
wire                                     cpl_req_status_error;
wire                                     cpl_req_status_valid;

wire [1:0]                               event_cpl_req_sel = 2'd2;
wire [QUEUE_INDEX_WIDTH-1:0]             event_cpl_req_queue;
wire [PORT_DESC_REQ_TAG_WIDTH-1:0]       event_cpl_req_tag;
wire [CPL_SIZE*8-1:0]                    event_cpl_req_data;
wire                                     event_cpl_req_valid;
wire                                     event_cpl_req_ready;

wire [PORT_DESC_REQ_TAG_WIDTH-1:0]       event_cpl_req_status_tag;
wire                                     event_cpl_req_status_full;
wire                                     event_cpl_req_status_error;
wire                                     event_cpl_req_status_valid;

wire [PORTS*2-1:0]                       port_cpl_req_sel;
wire [PORTS*QUEUE_INDEX_WIDTH-1:0]       port_cpl_req_queue;
wire [PORTS*PORT_DESC_REQ_TAG_WIDTH-1:0] port_cpl_req_tag;
wire [PORTS*CPL_SIZE*8-1:0]              port_cpl_req_data;
wire [PORTS-1:0]                         port_cpl_req_valid;
wire [PORTS-1:0]                         port_cpl_req_ready;

wire [PORTS*PORT_DESC_REQ_TAG_WIDTH-1:0] port_cpl_req_status_tag;
wire [PORTS-1:0]                         port_cpl_req_status_full;
wire [PORTS-1:0]                         port_cpl_req_status_error;
wire [PORTS-1:0]                         port_cpl_req_status_valid;

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

reg [31:0] msi_irq_reg = 0;

assign msi_irq = msi_irq_reg;

always @(posedge clk) begin
    msi_irq_reg <= 0;

    if (event_int_valid) begin
        msi_irq_reg <= 1'b1 << event_int;
    end
end

// control registers
wire [AXIL_CTRL_ADDR_WIDTH-1:0]  ctrl_reg_wr_addr;
wire [AXIL_DATA_WIDTH-1:0]       ctrl_reg_wr_data;
wire [AXIL_STRB_WIDTH-1:0]       ctrl_reg_wr_strb;
wire                             ctrl_reg_wr_en;
wire                             ctrl_reg_wr_wait;
wire                             ctrl_reg_wr_ack;
wire [AXIL_CTRL_ADDR_WIDTH-1:0]  ctrl_reg_rd_addr;
wire                             ctrl_reg_rd_en;
wire [AXIL_DATA_WIDTH-1:0]       ctrl_reg_rd_data;
wire                             ctrl_reg_rd_wait;
wire                             ctrl_reg_rd_ack;

axil_reg_if #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_CTRL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .TIMEOUT(4)
)
axil_reg_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_ctrl_awaddr),
    .s_axil_awprot(axil_ctrl_awprot),
    .s_axil_awvalid(axil_ctrl_awvalid),
    .s_axil_awready(axil_ctrl_awready),
    .s_axil_wdata(axil_ctrl_wdata),
    .s_axil_wstrb(axil_ctrl_wstrb),
    .s_axil_wvalid(axil_ctrl_wvalid),
    .s_axil_wready(axil_ctrl_wready),
    .s_axil_bresp(axil_ctrl_bresp),
    .s_axil_bvalid(axil_ctrl_bvalid),
    .s_axil_bready(axil_ctrl_bready),
    .s_axil_araddr(axil_ctrl_araddr),
    .s_axil_arprot(axil_ctrl_arprot),
    .s_axil_arvalid(axil_ctrl_arvalid),
    .s_axil_arready(axil_ctrl_arready),
    .s_axil_rdata(axil_ctrl_rdata),
    .s_axil_rresp(axil_ctrl_rresp),
    .s_axil_rvalid(axil_ctrl_rvalid),
    .s_axil_rready(axil_ctrl_rready),

    /*
     * Register interface
     */
    .reg_wr_addr(ctrl_reg_wr_addr),
    .reg_wr_data(ctrl_reg_wr_data),
    .reg_wr_strb(ctrl_reg_wr_strb),
    .reg_wr_en(ctrl_reg_wr_en),
    .reg_wr_wait(ctrl_reg_wr_wait),
    .reg_wr_ack(ctrl_reg_wr_ack),
    .reg_rd_addr(ctrl_reg_rd_addr),
    .reg_rd_en(ctrl_reg_rd_en),
    .reg_rd_data(ctrl_reg_rd_data),
    .reg_rd_wait(ctrl_reg_rd_wait),
    .reg_rd_ack(ctrl_reg_rd_ack)
);

reg ctrl_reg_wr_ack_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = {AXIL_DATA_WIDTH{1'b0}};
reg ctrl_reg_rd_ack_reg = 1'b0;

wire port_ctrl_reg_wr_wait[PORTS-1:0];
wire port_ctrl_reg_wr_ack[PORTS-1:0];
wire [AXIL_DATA_WIDTH-1:0] port_ctrl_reg_rd_data[PORTS-1:0];
wire port_ctrl_reg_rd_wait[PORTS-1:0];
wire port_ctrl_reg_rd_ack[PORTS-1:0];

reg ctrl_reg_wr_wait_cmb;
reg ctrl_reg_wr_ack_cmb;
reg [AXIL_DATA_WIDTH-1:0] ctrl_reg_rd_data_cmb;
reg ctrl_reg_rd_wait_cmb;
reg ctrl_reg_rd_ack_cmb;

assign ctrl_reg_wr_wait = ctrl_reg_wr_wait_cmb;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_cmb;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_cmb;
assign ctrl_reg_rd_wait = ctrl_reg_rd_wait_cmb;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_cmb;

integer k;

always @* begin
    ctrl_reg_wr_wait_cmb = 1'b0;
    ctrl_reg_wr_ack_cmb = ctrl_reg_wr_ack_reg;
    ctrl_reg_rd_data_cmb = ctrl_reg_rd_data_reg;
    ctrl_reg_rd_wait_cmb = 1'b0;
    ctrl_reg_rd_ack_cmb = ctrl_reg_rd_ack_reg;

    for (k = 0; k < PORTS; k = k + 1) begin
        ctrl_reg_wr_wait_cmb = ctrl_reg_wr_wait_cmb | port_ctrl_reg_wr_wait[k];
        ctrl_reg_wr_ack_cmb = ctrl_reg_wr_ack_cmb | port_ctrl_reg_wr_ack[k];
        ctrl_reg_rd_data_cmb = ctrl_reg_rd_data_cmb | port_ctrl_reg_rd_data[k];
        ctrl_reg_rd_wait_cmb = ctrl_reg_rd_wait_cmb | port_ctrl_reg_rd_wait[k];
        ctrl_reg_rd_ack_cmb = ctrl_reg_rd_ack_cmb | port_ctrl_reg_rd_ack[k];
    end
end

always @(posedge clk) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= {AXIL_DATA_WIDTH{1'b0}};
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b0;
        // case ({ctrl_reg_wr_addr >> 2, 2'b00})
        //     default: ctrl_reg_wr_ack_reg <= 1'b0;
        // endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            16'h0000: ctrl_reg_rd_data_reg <= 32'd0;                       // if_id
            16'h0004: begin
                // if_features
                ctrl_reg_rd_data_reg[0] <= RX_RSS_ENABLE && RX_HASH_ENABLE;
                ctrl_reg_rd_data_reg[4] <= PTP_TS_ENABLE;
                ctrl_reg_rd_data_reg[8] <= TX_CHECKSUM_ENABLE;
                ctrl_reg_rd_data_reg[9] <= RX_CHECKSUM_ENABLE;
                ctrl_reg_rd_data_reg[10] <= RX_HASH_ENABLE;
            end
            16'h0010: ctrl_reg_rd_data_reg <= 2**EVENT_QUEUE_INDEX_WIDTH;  // event_queue_count
            16'h0014: ctrl_reg_rd_data_reg <= AXIL_EQM_BASE_ADDR;          // event_queue_offset
            16'h0020: ctrl_reg_rd_data_reg <= 2**TX_QUEUE_INDEX_WIDTH;     // tx_queue_count
            16'h0024: ctrl_reg_rd_data_reg <= AXIL_TX_QM_BASE_ADDR;        // tx_queue_offset
            16'h0028: ctrl_reg_rd_data_reg <= 2**TX_CPL_QUEUE_INDEX_WIDTH; // tx_cpl_queue_count
            16'h002C: ctrl_reg_rd_data_reg <= AXIL_TX_CQM_BASE_ADDR;       // tx_cpl_queue_offset
            16'h0030: ctrl_reg_rd_data_reg <= 2**RX_QUEUE_INDEX_WIDTH;     // rx_queue_count
            16'h0034: ctrl_reg_rd_data_reg <= AXIL_RX_QM_BASE_ADDR;        // rx_queue_offset
            16'h0038: ctrl_reg_rd_data_reg <= 2**RX_CPL_QUEUE_INDEX_WIDTH; // rx_cpl_queue_count
            16'h003C: ctrl_reg_rd_data_reg <= AXIL_RX_CQM_BASE_ADDR;       // rx_cpl_queue_offset
            16'h0040: ctrl_reg_rd_data_reg <= PORTS;                       // port_count
            16'h0044: ctrl_reg_rd_data_reg <= AXIL_CTRL_BASE_ADDR + 2**PORT_CTRL_ADDR_WIDTH; // port_offset
            16'h0048: ctrl_reg_rd_data_reg <= 2**PORT_CTRL_ADDR_WIDTH;     // port_stride
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;
    end
end

// AXI lite crossbar
parameter AXIL_S_COUNT = 1;
parameter AXIL_M_COUNT = 7+PORTS;

axil_crossbar #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .S_COUNT(AXIL_S_COUNT),
    .M_COUNT(AXIL_M_COUNT),
    .M_ADDR_WIDTH({{PORTS{w_32(AXIL_PORT_ADDR_WIDTH)}}, w_32(AXIL_RX_CQM_ADDR_WIDTH), w_32(AXIL_RX_QM_ADDR_WIDTH), w_32(AXIL_TX_CQM_ADDR_WIDTH), w_32(AXIL_TX_QM_ADDR_WIDTH), w_32(AXIL_EQM_ADDR_WIDTH), w_32(AXIL_CTRL_ADDR_WIDTH), w_32(AXIL_CSR_ADDR_WIDTH)}),
    .M_CONNECT_READ({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({AXIL_M_COUNT{{AXIL_S_COUNT{1'b1}}}})
)
axil_crossbar_inst (
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
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(EVENT_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(INT_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .CPL_SIZE(EVENT_SIZE),
    .PIPELINE(EVENT_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_EQM_ADDR_WIDTH),
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
    .m_axis_enqueue_resp_queue(),
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

queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
    .CPL_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),
    .PIPELINE(TX_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_TX_QM_ADDR_WIDTH),
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
    .m_axis_dequeue_resp_queue(tx_desc_dequeue_resp_queue),
    .m_axis_dequeue_resp_ptr(tx_desc_dequeue_resp_ptr),
    .m_axis_dequeue_resp_addr(tx_desc_dequeue_resp_addr),
    .m_axis_dequeue_resp_block_size(tx_desc_dequeue_resp_block_size),
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

cpl_queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .PIPELINE(TX_CPL_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_TX_CQM_ADDR_WIDTH),
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
    .m_axis_enqueue_resp_queue(),
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

queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
    .CPL_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),
    .PIPELINE(RX_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_RX_QM_ADDR_WIDTH),
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
    .m_axis_dequeue_resp_queue(rx_desc_dequeue_resp_queue),
    .m_axis_dequeue_resp_ptr(rx_desc_dequeue_resp_ptr),
    .m_axis_dequeue_resp_addr(rx_desc_dequeue_resp_addr),
    .m_axis_dequeue_resp_block_size(rx_desc_dequeue_resp_block_size),
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

cpl_queue_manager #(
    .ADDR_WIDTH(DMA_ADDR_WIDTH),
    .REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(RX_QUEUE_OP_TABLE_SIZE),
    .OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
    .EVENT_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .LOG_QUEUE_SIZE_WIDTH(LOG_QUEUE_SIZE_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .PIPELINE(RX_CPL_QUEUE_PIPELINE),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_RX_CQM_ADDR_WIDTH),
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
    .m_axis_enqueue_resp_queue(),
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

if (PORTS > 1) begin

    desc_op_mux #(
        .PORTS(PORTS),
        .SELECT_WIDTH(1),
        .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
        .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
        .CPL_QUEUE_INDEX_WIDTH(CPL_QUEUE_INDEX_WIDTH),
        .S_REQ_TAG_WIDTH(PORT_DESC_REQ_TAG_WIDTH),
        .M_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
        .AXIS_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
        .AXIS_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    desc_op_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Descriptor request output
         */
        .m_axis_req_sel(desc_req_sel),
        .m_axis_req_queue(desc_req_queue),
        .m_axis_req_tag(desc_req_tag),
        .m_axis_req_valid(desc_req_valid),
        .m_axis_req_ready(desc_req_ready),

        /*
         * Descriptor request status input
         */
        .s_axis_req_status_queue(desc_req_status_queue),
        .s_axis_req_status_ptr(desc_req_status_ptr),
        .s_axis_req_status_cpl(desc_req_status_cpl),
        .s_axis_req_status_tag(desc_req_status_tag),
        .s_axis_req_status_empty(desc_req_status_empty),
        .s_axis_req_status_error(desc_req_status_error),
        .s_axis_req_status_valid(desc_req_status_valid),

        /*
         * Descriptor data input
         */
        .s_axis_desc_tdata(axis_desc_tdata),
        .s_axis_desc_tkeep(axis_desc_tkeep),
        .s_axis_desc_tvalid(axis_desc_tvalid),
        .s_axis_desc_tready(axis_desc_tready),
        .s_axis_desc_tlast(axis_desc_tlast),
        .s_axis_desc_tid(axis_desc_tid),
        .s_axis_desc_tuser(axis_desc_tuser),

        /*
         * Descriptor request input
         */
        .s_axis_req_sel(port_desc_req_sel),
        .s_axis_req_queue(port_desc_req_queue),
        .s_axis_req_tag(port_desc_req_tag),
        .s_axis_req_valid(port_desc_req_valid),
        .s_axis_req_ready(port_desc_req_ready),

        /*
         * Descriptor request status output
         */
        .m_axis_req_status_queue(port_desc_req_status_queue),
        .m_axis_req_status_ptr(port_desc_req_status_ptr),
        .m_axis_req_status_cpl(port_desc_req_status_cpl),
        .m_axis_req_status_tag(port_desc_req_status_tag),
        .m_axis_req_status_empty(port_desc_req_status_empty),
        .m_axis_req_status_error(port_desc_req_status_error),
        .m_axis_req_status_valid(port_desc_req_status_valid),

        /*
         * Descriptor data output
         */
        .m_axis_desc_tdata(port_axis_desc_tdata),
        .m_axis_desc_tkeep(port_axis_desc_tkeep),
        .m_axis_desc_tvalid(port_axis_desc_tvalid),
        .m_axis_desc_tready(port_axis_desc_tready),
        .m_axis_desc_tlast(port_axis_desc_tlast),
        .m_axis_desc_tid(port_axis_desc_tid),
        .m_axis_desc_tuser(port_axis_desc_tuser)
    );

end else begin

    assign desc_req_sel = port_desc_req_sel;
    assign desc_req_queue = port_desc_req_queue;
    assign desc_req_tag = port_desc_req_tag;
    assign desc_req_valid = port_desc_req_valid;
    assign port_desc_req_ready = desc_req_ready;

    assign port_desc_req_status_queue = desc_req_status_queue;
    assign port_desc_req_status_ptr = desc_req_status_ptr;
    assign port_desc_req_status_cpl = desc_req_status_cpl;
    assign port_desc_req_status_tag = desc_req_status_tag;
    assign port_desc_req_status_empty = desc_req_status_empty;
    assign port_desc_req_status_error = desc_req_status_error;
    assign port_desc_req_status_valid = desc_req_status_valid;

    assign port_axis_desc_tdata = axis_desc_tdata;
    assign port_axis_desc_tkeep = axis_desc_tkeep;
    assign port_axis_desc_tvalid = axis_desc_tvalid;
    assign axis_desc_tready = port_axis_desc_tready;
    assign port_axis_desc_tlast = axis_desc_tlast;
    assign port_axis_desc_tid = axis_desc_tid;
    assign port_axis_desc_tuser = axis_desc_tuser;

end

desc_fetch #(
    .PORTS(2),
    .SELECT_WIDTH(1),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),
    .AXIS_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .CPL_QUEUE_INDEX_WIDTH(CPL_QUEUE_INDEX_WIDTH),
    .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
    .DESC_SIZE(DESC_SIZE),
    .LOG_BLOCK_SIZE_WIDTH(LOG_BLOCK_SIZE_WIDTH),
    .DESC_TABLE_SIZE(32)
)
desc_fetch_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Descriptor read request input
     */
    .s_axis_req_sel(desc_req_sel),
    .s_axis_req_queue(desc_req_queue),
    .s_axis_req_tag(desc_req_tag),
    .s_axis_req_valid(desc_req_valid),
    .s_axis_req_ready(desc_req_ready),

    /*
     * Descriptor read request status output
     */
    .m_axis_req_status_queue(desc_req_status_queue),
    .m_axis_req_status_ptr(desc_req_status_ptr),
    .m_axis_req_status_cpl(desc_req_status_cpl),
    .m_axis_req_status_tag(desc_req_status_tag),
    .m_axis_req_status_empty(desc_req_status_empty),
    .m_axis_req_status_error(desc_req_status_error),
    .m_axis_req_status_valid(desc_req_status_valid),

    /*
     * Descriptor data output
     */
    .m_axis_desc_tdata(axis_desc_tdata),
    .m_axis_desc_tkeep(axis_desc_tkeep),
    .m_axis_desc_tvalid(axis_desc_tvalid),
    .m_axis_desc_tready(axis_desc_tready),
    .m_axis_desc_tlast(axis_desc_tlast),
    .m_axis_desc_tid(axis_desc_tid),
    .m_axis_desc_tuser(axis_desc_tuser),

    /*
     * Descriptor dequeue request output
     */
    .m_axis_desc_dequeue_req_queue({rx_desc_dequeue_req_queue, tx_desc_dequeue_req_queue}),
    .m_axis_desc_dequeue_req_tag({rx_desc_dequeue_req_tag, tx_desc_dequeue_req_tag}),
    .m_axis_desc_dequeue_req_valid({rx_desc_dequeue_req_valid, tx_desc_dequeue_req_valid}),
    .m_axis_desc_dequeue_req_ready({rx_desc_dequeue_req_ready, tx_desc_dequeue_req_ready}),

    /*
     * Descriptor dequeue response input
     */
    .s_axis_desc_dequeue_resp_queue({rx_desc_dequeue_resp_queue, tx_desc_dequeue_resp_queue}),
    .s_axis_desc_dequeue_resp_ptr({rx_desc_dequeue_resp_ptr, tx_desc_dequeue_resp_ptr}),
    .s_axis_desc_dequeue_resp_addr({rx_desc_dequeue_resp_addr, tx_desc_dequeue_resp_addr}),
    .s_axis_desc_dequeue_resp_block_size({rx_desc_dequeue_resp_block_size, tx_desc_dequeue_resp_block_size}),
    .s_axis_desc_dequeue_resp_cpl({rx_desc_dequeue_resp_cpl, tx_desc_dequeue_resp_cpl}),
    .s_axis_desc_dequeue_resp_tag({rx_desc_dequeue_resp_tag, tx_desc_dequeue_resp_tag}),
    .s_axis_desc_dequeue_resp_op_tag({rx_desc_dequeue_resp_op_tag, tx_desc_dequeue_resp_op_tag}),
    .s_axis_desc_dequeue_resp_empty({rx_desc_dequeue_resp_empty, tx_desc_dequeue_resp_empty}),
    .s_axis_desc_dequeue_resp_error({rx_desc_dequeue_resp_error, tx_desc_dequeue_resp_error}),
    .s_axis_desc_dequeue_resp_valid({rx_desc_dequeue_resp_valid, tx_desc_dequeue_resp_valid}),
    .s_axis_desc_dequeue_resp_ready({rx_desc_dequeue_resp_ready, tx_desc_dequeue_resp_ready}),

    /*
     * Descriptor dequeue commit output
     */
    .m_axis_desc_dequeue_commit_op_tag({rx_desc_dequeue_commit_op_tag, tx_desc_dequeue_commit_op_tag}),
    .m_axis_desc_dequeue_commit_valid({rx_desc_dequeue_commit_valid, tx_desc_dequeue_commit_valid}),
    .m_axis_desc_dequeue_commit_ready({rx_desc_dequeue_commit_ready, tx_desc_dequeue_commit_ready}),

    /*
     * DMA read descriptor output
     */
    .m_axis_dma_read_desc_dma_addr(m_axis_ctrl_dma_read_desc_dma_addr),
    .m_axis_dma_read_desc_ram_addr(m_axis_ctrl_dma_read_desc_ram_addr),
    .m_axis_dma_read_desc_len(m_axis_ctrl_dma_read_desc_len),
    .m_axis_dma_read_desc_tag(m_axis_ctrl_dma_read_desc_tag),
    .m_axis_dma_read_desc_valid(m_axis_ctrl_dma_read_desc_valid),
    .m_axis_dma_read_desc_ready(m_axis_ctrl_dma_read_desc_ready),

    /*
     * DMA read descriptor status input
     */
    .s_axis_dma_read_desc_status_tag(s_axis_ctrl_dma_read_desc_status_tag),
    .s_axis_dma_read_desc_status_error(s_axis_ctrl_dma_read_desc_status_error),
    .s_axis_dma_read_desc_status_valid(s_axis_ctrl_dma_read_desc_status_valid),

    /*
     * RAM interface
     */
    .dma_ram_wr_cmd_be(ctrl_dma_ram_wr_cmd_be),
    .dma_ram_wr_cmd_addr(ctrl_dma_ram_wr_cmd_addr),
    .dma_ram_wr_cmd_data(ctrl_dma_ram_wr_cmd_data),
    .dma_ram_wr_cmd_valid(ctrl_dma_ram_wr_cmd_valid),
    .dma_ram_wr_cmd_ready(ctrl_dma_ram_wr_cmd_ready),
    .dma_ram_wr_done(ctrl_dma_ram_wr_done),

    /*
     * Configuration
     */
    .enable(1'b1)
);

assign m_axis_ctrl_dma_read_desc_ram_sel = 0;

cpl_op_mux #(
    .PORTS(PORTS+1),
    .SELECT_WIDTH(2),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .S_REQ_TAG_WIDTH(PORT_DESC_REQ_TAG_WIDTH),
    .M_REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
cpl_op_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Completion request output
     */
    .m_axis_req_sel(cpl_req_sel),
    .m_axis_req_queue(cpl_req_queue),
    .m_axis_req_tag(cpl_req_tag),
    .m_axis_req_data(cpl_req_data),
    .m_axis_req_valid(cpl_req_valid),
    .m_axis_req_ready(cpl_req_ready),

    /*
     * Completion request status input
     */
    .s_axis_req_status_tag(cpl_req_status_tag),
    .s_axis_req_status_full(cpl_req_status_full),
    .s_axis_req_status_error(cpl_req_status_error),
    .s_axis_req_status_valid(cpl_req_status_valid),

    /*
     * Completion request input
     */
    .s_axis_req_sel({port_cpl_req_sel, event_cpl_req_sel}),
    .s_axis_req_queue({port_cpl_req_queue, event_cpl_req_queue}),
    .s_axis_req_tag({port_cpl_req_tag, event_cpl_req_tag}),
    .s_axis_req_data({port_cpl_req_data, event_cpl_req_data}),
    .s_axis_req_valid({port_cpl_req_valid, event_cpl_req_valid}),
    .s_axis_req_ready({port_cpl_req_ready, event_cpl_req_ready}),

    /*
     * Completion response output
     */
    .m_axis_req_status_tag({port_cpl_req_status_tag, event_cpl_req_status_tag}),
    .m_axis_req_status_full({port_cpl_req_status_full, event_cpl_req_status_full}),
    .m_axis_req_status_error({port_cpl_req_status_error, event_cpl_req_status_error}),
    .m_axis_req_status_valid({port_cpl_req_status_valid, event_cpl_req_status_valid})
);

cpl_write #(
    .PORTS(3),
    .SELECT_WIDTH(2),
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(SEG_BE_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .REQ_TAG_WIDTH(DESC_REQ_TAG_WIDTH),
    .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
    .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .CPL_SIZE(CPL_SIZE),
    .DESC_TABLE_SIZE(32)
)
cpl_write_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Completion read request input
     */
    .s_axis_req_sel(cpl_req_sel),
    .s_axis_req_queue(cpl_req_queue),
    .s_axis_req_tag(cpl_req_tag),
    .s_axis_req_data(cpl_req_data),
    .s_axis_req_valid(cpl_req_valid),
    .s_axis_req_ready(cpl_req_ready),

    /*
     * Completion read request status output
     */
    .m_axis_req_status_tag(cpl_req_status_tag),
    .m_axis_req_status_full(cpl_req_status_full),
    .m_axis_req_status_error(cpl_req_status_error),
    .m_axis_req_status_valid(cpl_req_status_valid),

    /*
     * Completion enqueue request output
     */
    .m_axis_cpl_enqueue_req_queue({event_enqueue_req_queue, rx_cpl_enqueue_req_queue, tx_cpl_enqueue_req_queue}),
    .m_axis_cpl_enqueue_req_tag({event_enqueue_req_tag, rx_cpl_enqueue_req_tag, tx_cpl_enqueue_req_tag}),
    .m_axis_cpl_enqueue_req_valid({event_enqueue_req_valid, rx_cpl_enqueue_req_valid, tx_cpl_enqueue_req_valid}),
    .m_axis_cpl_enqueue_req_ready({event_enqueue_req_ready, rx_cpl_enqueue_req_ready, tx_cpl_enqueue_req_ready}),

    /*
     * Completion enqueue response input
     */
    .s_axis_cpl_enqueue_resp_addr({event_enqueue_resp_addr, rx_cpl_enqueue_resp_addr, tx_cpl_enqueue_resp_addr}),
    .s_axis_cpl_enqueue_resp_tag({event_enqueue_resp_tag, rx_cpl_enqueue_resp_tag, tx_cpl_enqueue_resp_tag}),
    .s_axis_cpl_enqueue_resp_op_tag({event_enqueue_resp_op_tag, rx_cpl_enqueue_resp_op_tag, tx_cpl_enqueue_resp_op_tag}),
    .s_axis_cpl_enqueue_resp_full({event_enqueue_resp_full, rx_cpl_enqueue_resp_full, tx_cpl_enqueue_resp_full}),
    .s_axis_cpl_enqueue_resp_error({event_enqueue_resp_error, rx_cpl_enqueue_resp_error, tx_cpl_enqueue_resp_error}),
    .s_axis_cpl_enqueue_resp_valid({event_enqueue_resp_valid, rx_cpl_enqueue_resp_valid, tx_cpl_enqueue_resp_valid}),
    .s_axis_cpl_enqueue_resp_ready({event_enqueue_resp_ready, rx_cpl_enqueue_resp_ready, tx_cpl_enqueue_resp_ready}),

    /*
     * Completion enqueue commit output
     */
    .m_axis_cpl_enqueue_commit_op_tag({event_enqueue_commit_op_tag, rx_cpl_enqueue_commit_op_tag, tx_cpl_enqueue_commit_op_tag}),
    .m_axis_cpl_enqueue_commit_valid({event_enqueue_commit_valid, rx_cpl_enqueue_commit_valid, tx_cpl_enqueue_commit_valid}),
    .m_axis_cpl_enqueue_commit_ready({event_enqueue_commit_ready, rx_cpl_enqueue_commit_ready, tx_cpl_enqueue_commit_ready}),

    /*
     * DMA write descriptor output
     */
    .m_axis_dma_write_desc_dma_addr(m_axis_ctrl_dma_write_desc_dma_addr),
    .m_axis_dma_write_desc_ram_addr(m_axis_ctrl_dma_write_desc_ram_addr),
    .m_axis_dma_write_desc_len(m_axis_ctrl_dma_write_desc_len),
    .m_axis_dma_write_desc_tag(m_axis_ctrl_dma_write_desc_tag),
    .m_axis_dma_write_desc_valid(m_axis_ctrl_dma_write_desc_valid),
    .m_axis_dma_write_desc_ready(m_axis_ctrl_dma_write_desc_ready),

    /*
     * DMA write descriptor status input
     */
    .s_axis_dma_write_desc_status_tag(s_axis_ctrl_dma_write_desc_status_tag),
    .s_axis_dma_write_desc_status_error(s_axis_ctrl_dma_write_desc_status_error),
    .s_axis_dma_write_desc_status_valid(s_axis_ctrl_dma_write_desc_status_valid),

    /*
     * RAM interface
     */
    .dma_ram_rd_cmd_addr(ctrl_dma_ram_rd_cmd_addr),
    .dma_ram_rd_cmd_valid(ctrl_dma_ram_rd_cmd_valid),
    .dma_ram_rd_cmd_ready(ctrl_dma_ram_rd_cmd_ready),
    .dma_ram_rd_resp_data(ctrl_dma_ram_rd_resp_data),
    .dma_ram_rd_resp_valid(ctrl_dma_ram_rd_resp_valid),
    .dma_ram_rd_resp_ready(ctrl_dma_ram_rd_resp_ready),

    /*
     * Configuration
     */
    .enable(1'b1)
);

assign m_axis_ctrl_dma_write_desc_ram_sel = 0;

if (PORTS > 1) begin

    dma_if_mux #
    (
        .PORTS(PORTS),
        .SEG_COUNT(SEG_COUNT),
        .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
        .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
        .SEG_BE_WIDTH(SEG_BE_WIDTH),
        .S_RAM_SEL_WIDTH(0),
        .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
        .LEN_WIDTH(DMA_LEN_WIDTH),
        .S_TAG_WIDTH(DMA_TAG_WIDTH_INT),
        .M_TAG_WIDTH(DMA_TAG_WIDTH),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    dma_if_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Read descriptor output (to DMA interface)
         */
        .m_axis_read_desc_dma_addr(m_axis_data_dma_read_desc_dma_addr),
        .m_axis_read_desc_ram_sel(m_axis_data_dma_read_desc_ram_sel),
        .m_axis_read_desc_ram_addr(m_axis_data_dma_read_desc_ram_addr),
        .m_axis_read_desc_len(m_axis_data_dma_read_desc_len),
        .m_axis_read_desc_tag(m_axis_data_dma_read_desc_tag),
        .m_axis_read_desc_valid(m_axis_data_dma_read_desc_valid),
        .m_axis_read_desc_ready(m_axis_data_dma_read_desc_ready),

        /*
         * Read descriptor status input (from DMA interface)
         */
        .s_axis_read_desc_status_tag(s_axis_data_dma_read_desc_status_tag),
        .s_axis_read_desc_status_error(s_axis_data_dma_read_desc_status_error),
        .s_axis_read_desc_status_valid(s_axis_data_dma_read_desc_status_valid),

        /*
         * Read descriptor input
         */
        .s_axis_read_desc_dma_addr(port_dma_read_desc_dma_addr),
        .s_axis_read_desc_ram_sel(0),
        .s_axis_read_desc_ram_addr(port_dma_read_desc_ram_addr),
        .s_axis_read_desc_len(port_dma_read_desc_len),
        .s_axis_read_desc_tag(port_dma_read_desc_tag),
        .s_axis_read_desc_valid(port_dma_read_desc_valid),
        .s_axis_read_desc_ready(port_dma_read_desc_ready),

        /*
         * Read descriptor status output
         */
        .m_axis_read_desc_status_tag(port_dma_read_desc_status_tag),
        .m_axis_read_desc_status_error(port_dma_read_desc_status_error),
        .m_axis_read_desc_status_valid(port_dma_read_desc_status_valid),

        /*
         * Write descriptor output (to DMA interface)
         */
        .m_axis_write_desc_dma_addr(m_axis_data_dma_write_desc_dma_addr),
        .m_axis_write_desc_ram_sel(m_axis_data_dma_write_desc_ram_sel),
        .m_axis_write_desc_ram_addr(m_axis_data_dma_write_desc_ram_addr),
        .m_axis_write_desc_len(m_axis_data_dma_write_desc_len),
        .m_axis_write_desc_tag(m_axis_data_dma_write_desc_tag),
        .m_axis_write_desc_valid(m_axis_data_dma_write_desc_valid),
        .m_axis_write_desc_ready(m_axis_data_dma_write_desc_ready),

        /*
         * Write descriptor status input (from DMA interface)
         */
        .s_axis_write_desc_status_tag(s_axis_data_dma_write_desc_status_tag),
        .s_axis_write_desc_status_error(s_axis_data_dma_write_desc_status_error),
        .s_axis_write_desc_status_valid(s_axis_data_dma_write_desc_status_valid),

        /*
         * Write descriptor input
         */
        .s_axis_write_desc_dma_addr(port_dma_write_desc_dma_addr),
        .s_axis_write_desc_ram_sel(0),
        .s_axis_write_desc_ram_addr(port_dma_write_desc_ram_addr),
        .s_axis_write_desc_len(port_dma_write_desc_len),
        .s_axis_write_desc_tag(port_dma_write_desc_tag),
        .s_axis_write_desc_valid(port_dma_write_desc_valid),
        .s_axis_write_desc_ready(port_dma_write_desc_ready),

        /*
         * Write descriptor status output
         */
        .m_axis_write_desc_status_tag(port_dma_write_desc_status_tag),
        .m_axis_write_desc_status_error(port_dma_write_desc_status_error),
        .m_axis_write_desc_status_valid(port_dma_write_desc_status_valid),

        /*
         * RAM interface (from DMA interface)
         */
        .if_ram_wr_cmd_sel(data_dma_ram_wr_cmd_sel),
        .if_ram_wr_cmd_be(data_dma_ram_wr_cmd_be),
        .if_ram_wr_cmd_addr(data_dma_ram_wr_cmd_addr),
        .if_ram_wr_cmd_data(data_dma_ram_wr_cmd_data),
        .if_ram_wr_cmd_valid(data_dma_ram_wr_cmd_valid),
        .if_ram_wr_cmd_ready(data_dma_ram_wr_cmd_ready),
        .if_ram_wr_done(data_dma_ram_wr_done),
        .if_ram_rd_cmd_sel(data_dma_ram_rd_cmd_sel),
        .if_ram_rd_cmd_addr(data_dma_ram_rd_cmd_addr),
        .if_ram_rd_cmd_valid(data_dma_ram_rd_cmd_valid),
        .if_ram_rd_cmd_ready(data_dma_ram_rd_cmd_ready),
        .if_ram_rd_resp_data(data_dma_ram_rd_resp_data),
        .if_ram_rd_resp_valid(data_dma_ram_rd_resp_valid),
        .if_ram_rd_resp_ready(data_dma_ram_rd_resp_ready),

        /*
         * RAM interface
         */
        .ram_wr_cmd_sel(),
        .ram_wr_cmd_be(port_dma_ram_wr_cmd_be),
        .ram_wr_cmd_addr(port_dma_ram_wr_cmd_addr),
        .ram_wr_cmd_data(port_dma_ram_wr_cmd_data),
        .ram_wr_cmd_valid(port_dma_ram_wr_cmd_valid),
        .ram_wr_cmd_ready(port_dma_ram_wr_cmd_ready),
        .ram_wr_done(port_dma_ram_wr_done),
        .ram_rd_cmd_sel(),
        .ram_rd_cmd_addr(port_dma_ram_rd_cmd_addr),
        .ram_rd_cmd_valid(port_dma_ram_rd_cmd_valid),
        .ram_rd_cmd_ready(port_dma_ram_rd_cmd_ready),
        .ram_rd_resp_data(port_dma_ram_rd_resp_data),
        .ram_rd_resp_valid(port_dma_ram_rd_resp_valid),
        .ram_rd_resp_ready(port_dma_ram_rd_resp_ready)
    );

end else begin

    assign m_axis_data_dma_read_desc_dma_addr = port_dma_read_desc_dma_addr;
    assign m_axis_data_dma_read_desc_ram_sel = 0;
    assign m_axis_data_dma_read_desc_ram_addr = port_dma_read_desc_ram_addr;
    assign m_axis_data_dma_read_desc_len = port_dma_read_desc_len;
    assign m_axis_data_dma_read_desc_tag = port_dma_read_desc_tag;
    assign m_axis_data_dma_read_desc_valid = port_dma_read_desc_valid;
    assign port_dma_read_desc_ready = m_axis_data_dma_read_desc_ready;

    assign port_dma_read_desc_status_tag = s_axis_data_dma_read_desc_status_tag;
    assign port_dma_read_desc_status_error = s_axis_data_dma_read_desc_status_error;
    assign port_dma_read_desc_status_valid = s_axis_data_dma_read_desc_status_valid;

    assign m_axis_data_dma_write_desc_dma_addr = port_dma_write_desc_dma_addr;
    assign m_axis_data_dma_write_desc_ram_sel = 0;
    assign m_axis_data_dma_write_desc_ram_addr = port_dma_write_desc_ram_addr;
    assign m_axis_data_dma_write_desc_len = port_dma_write_desc_len;
    assign m_axis_data_dma_write_desc_tag = port_dma_write_desc_tag;
    assign m_axis_data_dma_write_desc_valid = port_dma_write_desc_valid;
    assign port_dma_write_desc_ready = m_axis_data_dma_write_desc_ready;

    assign port_dma_write_desc_status_tag = s_axis_data_dma_write_desc_status_tag;
    assign port_dma_write_desc_status_error = s_axis_data_dma_write_desc_status_error;
    assign port_dma_write_desc_status_valid = s_axis_data_dma_write_desc_status_valid;

    assign port_dma_ram_wr_cmd_be = data_dma_ram_wr_cmd_be;
    assign port_dma_ram_wr_cmd_addr = data_dma_ram_wr_cmd_addr;
    assign port_dma_ram_wr_cmd_data = data_dma_ram_wr_cmd_data;
    assign port_dma_ram_wr_cmd_valid = data_dma_ram_wr_cmd_valid;
    assign data_dma_ram_wr_cmd_ready = port_dma_ram_wr_cmd_ready;
    assign data_dma_ram_wr_done = port_dma_ram_wr_done;
    assign port_dma_ram_rd_cmd_addr = data_dma_ram_rd_cmd_addr;
    assign port_dma_ram_rd_cmd_valid = data_dma_ram_rd_cmd_valid;
    assign data_dma_ram_rd_cmd_ready = port_dma_ram_rd_cmd_ready;
    assign data_dma_ram_rd_resp_data = port_dma_ram_rd_resp_data;
    assign data_dma_ram_rd_resp_valid = port_dma_ram_rd_resp_valid;
    assign port_dma_ram_rd_resp_ready = data_dma_ram_rd_resp_ready;

end

event_mux #(
    .PORTS(2),
    .QUEUE_INDEX_WIDTH(EVENT_QUEUE_INDEX_WIDTH),
    .EVENT_TYPE_WIDTH(EVENT_TYPE_WIDTH),
    .EVENT_SOURCE_WIDTH(EVENT_SOURCE_WIDTH),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIORITY(1)
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

assign event_cpl_req_queue = axis_event_queue;
assign event_cpl_req_tag = 0;
assign event_cpl_req_data[15:0] = axis_event_type;
assign event_cpl_req_data[31:16] = axis_event_source;
assign event_cpl_req_data[255:32] = 0;
assign event_cpl_req_valid = axis_event_valid;
assign axis_event_ready = event_cpl_req_ready;

axis_fifo #(
    .DEPTH(128),
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
    .DEPTH(128),
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

generate
    genvar n;

    for (n = 0; n < PORTS; n = n + 1) begin : port

        assign port_cpl_req_sel[n*2+1 +: 1] = 1'b0;

        mqnic_port #(
            .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
            .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
            .DMA_TAG_WIDTH(DMA_TAG_WIDTH_INT),
            .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
            .DESC_REQ_TAG_WIDTH(PORT_DESC_REQ_TAG_WIDTH),
            .QUEUE_REQ_TAG_WIDTH(QUEUE_REQ_TAG_WIDTH),
            .QUEUE_OP_TAG_WIDTH(QUEUE_OP_TAG_WIDTH),
            .TX_QUEUE_INDEX_WIDTH(TX_QUEUE_INDEX_WIDTH),
            .RX_QUEUE_INDEX_WIDTH(RX_QUEUE_INDEX_WIDTH),
            .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
            .TX_CPL_QUEUE_INDEX_WIDTH(TX_CPL_QUEUE_INDEX_WIDTH),
            .RX_CPL_QUEUE_INDEX_WIDTH(RX_CPL_QUEUE_INDEX_WIDTH),
            .CPL_QUEUE_INDEX_WIDTH(CPL_QUEUE_INDEX_WIDTH),
            .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
            .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
            .DESC_TABLE_DMA_OP_COUNT_WIDTH(((2**LOG_BLOCK_SIZE_WIDTH)-1)+1),
            .TX_MAX_DESC_REQ(TX_MAX_DESC_REQ),
            .TX_DESC_FIFO_SIZE(TX_MAX_DESC_REQ*(2**((2**LOG_BLOCK_SIZE_WIDTH)-1))),
            .RX_MAX_DESC_REQ(RX_MAX_DESC_REQ),
            .RX_DESC_FIFO_SIZE(RX_MAX_DESC_REQ*(2**((2**LOG_BLOCK_SIZE_WIDTH)-1))),
            .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
            .TX_SCHEDULER_PIPELINE(TX_SCHEDULER_PIPELINE),
            .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),
            .QUEUE_PTR_WIDTH(QUEUE_PTR_WIDTH),
            .PTP_TS_ENABLE(PTP_TS_ENABLE),
            .PTP_TS_WIDTH(PTP_TS_WIDTH),
            .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
            .RX_RSS_ENABLE(RX_RSS_ENABLE),
            .RX_HASH_ENABLE(RX_HASH_ENABLE),
            .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
            .REG_DATA_WIDTH(AXIL_DATA_WIDTH),
            .REG_ADDR_WIDTH(PORT_CTRL_ADDR_WIDTH),
            .REG_STRB_WIDTH(AXIL_STRB_WIDTH),
            .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
            .AXIL_ADDR_WIDTH(AXIL_PORT_ADDR_WIDTH),
            .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
            .AXIL_OFFSET(AXIL_PORT_BASE_ADDR + (2**AXIL_PORT_ADDR_WIDTH)*n - (AXIL_CTRL_BASE_ADDR + (2**PORT_CTRL_ADDR_WIDTH)*(n+1))),
            .SEG_COUNT(SEG_COUNT),
            .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
            .SEG_ADDR_WIDTH(SEG_ADDR_WIDTH),
            .SEG_BE_WIDTH(SEG_BE_WIDTH),
            .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
            .RAM_PIPELINE(RAM_PIPELINE),
            .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
            .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
            .MAX_TX_SIZE(MAX_TX_SIZE),
            .MAX_RX_SIZE(MAX_RX_SIZE),
            .TX_RAM_SIZE(TX_RAM_SIZE),
            .RX_RAM_SIZE(RX_RAM_SIZE),
            .DESC_SIZE(DESC_SIZE),
            .CPL_SIZE(CPL_SIZE),
            .AXIS_DESC_DATA_WIDTH(AXIS_DESC_DATA_WIDTH),
            .AXIS_DESC_KEEP_WIDTH(AXIS_DESC_KEEP_WIDTH)
        )
        port_inst (
            .clk(clk),
            .rst(rst),

            /*
             * Descriptor request output
             */
            .m_axis_desc_req_sel(port_desc_req_sel[n*1 +: 1]),
            .m_axis_desc_req_queue(port_desc_req_queue[n*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH]),
            .m_axis_desc_req_tag(port_desc_req_tag[n*PORT_DESC_REQ_TAG_WIDTH +: PORT_DESC_REQ_TAG_WIDTH]),
            .m_axis_desc_req_valid(port_desc_req_valid[n +: 1]),
            .m_axis_desc_req_ready(port_desc_req_ready[n +: 1]),

            /*
             * Descriptor response input
             */
            .s_axis_desc_req_status_queue(port_desc_req_status_queue[n*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH]),
            .s_axis_desc_req_status_ptr(port_desc_req_status_ptr[n*QUEUE_PTR_WIDTH +: QUEUE_PTR_WIDTH]),
            .s_axis_desc_req_status_cpl(port_desc_req_status_cpl[n*CPL_QUEUE_INDEX_WIDTH +: CPL_QUEUE_INDEX_WIDTH]),
            .s_axis_desc_req_status_tag(port_desc_req_status_tag[n*PORT_DESC_REQ_TAG_WIDTH +: PORT_DESC_REQ_TAG_WIDTH]),
            .s_axis_desc_req_status_empty(port_desc_req_status_empty[n +: 1]),
            .s_axis_desc_req_status_error(port_desc_req_status_error[n +: 1]),
            .s_axis_desc_req_status_valid(port_desc_req_status_valid[n +: 1]),

            /*
             * Descriptor data input
             */
            .s_axis_desc_tdata(port_axis_desc_tdata[n*AXIS_DESC_DATA_WIDTH +: AXIS_DESC_DATA_WIDTH]),
            .s_axis_desc_tkeep(port_axis_desc_tkeep[n*AXIS_DESC_KEEP_WIDTH +: AXIS_DESC_KEEP_WIDTH]),
            .s_axis_desc_tvalid(port_axis_desc_tvalid[n +: 1]),
            .s_axis_desc_tready(port_axis_desc_tready[n +: 1]),
            .s_axis_desc_tlast(port_axis_desc_tlast[n +: 1]),
            .s_axis_desc_tid(port_axis_desc_tid[n*PORT_DESC_REQ_TAG_WIDTH +: PORT_DESC_REQ_TAG_WIDTH]),
            .s_axis_desc_tuser(port_axis_desc_tuser[n +: 1]),

            /*
             * Completion request output
             */
            .m_axis_cpl_req_sel(port_cpl_req_sel[n*2 +: 1]),
            .m_axis_cpl_req_queue(port_cpl_req_queue[n*QUEUE_INDEX_WIDTH +: QUEUE_INDEX_WIDTH]),
            .m_axis_cpl_req_tag(port_cpl_req_tag[n*PORT_DESC_REQ_TAG_WIDTH +: PORT_DESC_REQ_TAG_WIDTH]),
            .m_axis_cpl_req_data(port_cpl_req_data[n*CPL_SIZE*8 +: CPL_SIZE*8]),
            .m_axis_cpl_req_valid(port_cpl_req_valid[n +: 1]),
            .m_axis_cpl_req_ready(port_cpl_req_ready[n +: 1]),

            /*
             * Completion response input
             */
            .s_axis_cpl_req_status_tag(port_cpl_req_status_tag[n*PORT_DESC_REQ_TAG_WIDTH +: PORT_DESC_REQ_TAG_WIDTH]),
            .s_axis_cpl_req_status_full(port_cpl_req_status_full[n +: 1]),
            .s_axis_cpl_req_status_error(port_cpl_req_status_error[n +: 1]),
            .s_axis_cpl_req_status_valid(port_cpl_req_status_valid[n +: 1]),

            /*
             * TX doorbell input
             */
            .s_axis_tx_doorbell_queue(tx_doorbell_queue),
            .s_axis_tx_doorbell_valid(tx_doorbell_valid),

            /*
             * DMA read descriptor output
             */
            .m_axis_dma_read_desc_dma_addr(port_dma_read_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_dma_read_desc_ram_addr(port_dma_read_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_dma_read_desc_len(port_dma_read_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_dma_read_desc_tag(port_dma_read_desc_tag[n*DMA_TAG_WIDTH_INT +: DMA_TAG_WIDTH_INT]),
            .m_axis_dma_read_desc_valid(port_dma_read_desc_valid[n +: 1]),
            .m_axis_dma_read_desc_ready(port_dma_read_desc_ready[n +: 1]),

            /*
             * DMA read descriptor status input
             */
            .s_axis_dma_read_desc_status_tag(port_dma_read_desc_status_tag[n*DMA_TAG_WIDTH_INT +: DMA_TAG_WIDTH_INT]),
            .s_axis_dma_read_desc_status_error(port_dma_read_desc_status_error[n*4 +: 4]),
            .s_axis_dma_read_desc_status_valid(port_dma_read_desc_status_valid[n +: 1]),

            /*
             * DMA write descriptor output
             */
            .m_axis_dma_write_desc_dma_addr(port_dma_write_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_dma_write_desc_ram_addr(port_dma_write_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_dma_write_desc_len(port_dma_write_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_dma_write_desc_tag(port_dma_write_desc_tag[n*DMA_TAG_WIDTH_INT +: DMA_TAG_WIDTH_INT]),
            .m_axis_dma_write_desc_valid(port_dma_write_desc_valid[n +: 1]),
            .m_axis_dma_write_desc_ready(port_dma_write_desc_ready[n +: 1]),

            /*
             * DMA write descriptor status input
             */
            .s_axis_dma_write_desc_status_tag(port_dma_write_desc_status_tag[n*DMA_TAG_WIDTH_INT +: DMA_TAG_WIDTH_INT]),
            .s_axis_dma_write_desc_status_error(port_dma_write_desc_status_error[n*4 +: 4]),
            .s_axis_dma_write_desc_status_valid(port_dma_write_desc_status_valid[n +: 1]),

            /*
             * Control register interface
             */
            .ctrl_reg_wr_addr(ctrl_reg_wr_addr),
            .ctrl_reg_wr_data(ctrl_reg_wr_data),
            .ctrl_reg_wr_strb(ctrl_reg_wr_strb),
            .ctrl_reg_wr_en(ctrl_reg_wr_en && ((ctrl_reg_wr_addr >> PORT_CTRL_ADDR_WIDTH) == n+1)),
            .ctrl_reg_wr_wait(port_ctrl_reg_wr_wait[n]),
            .ctrl_reg_wr_ack(port_ctrl_reg_wr_ack[n]),
            .ctrl_reg_rd_addr(ctrl_reg_rd_addr),
            .ctrl_reg_rd_en(ctrl_reg_rd_en && ((ctrl_reg_rd_addr >> PORT_CTRL_ADDR_WIDTH) == n+1)),
            .ctrl_reg_rd_data(port_ctrl_reg_rd_data[n]),
            .ctrl_reg_rd_wait(port_ctrl_reg_rd_wait[n]),
            .ctrl_reg_rd_ack(port_ctrl_reg_rd_ack[n]),

            /*
             * AXI-Lite slave interface (schedulers)
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
             * RAM interface
             */
            .dma_ram_wr_cmd_be(port_dma_ram_wr_cmd_be[SEG_COUNT*SEG_BE_WIDTH*n +: SEG_COUNT*SEG_BE_WIDTH]),
            .dma_ram_wr_cmd_addr(port_dma_ram_wr_cmd_addr[SEG_COUNT*SEG_ADDR_WIDTH*n +: SEG_COUNT*SEG_ADDR_WIDTH]),
            .dma_ram_wr_cmd_data(port_dma_ram_wr_cmd_data[SEG_COUNT*SEG_DATA_WIDTH*n +: SEG_COUNT*SEG_DATA_WIDTH]),
            .dma_ram_wr_cmd_valid(port_dma_ram_wr_cmd_valid[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_wr_cmd_ready(port_dma_ram_wr_cmd_ready[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_wr_done(port_dma_ram_wr_done[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_cmd_addr(port_dma_ram_rd_cmd_addr[SEG_COUNT*SEG_ADDR_WIDTH*n +: SEG_COUNT*SEG_ADDR_WIDTH]),
            .dma_ram_rd_cmd_valid(port_dma_ram_rd_cmd_valid[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_cmd_ready(port_dma_ram_rd_cmd_ready[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_resp_data(port_dma_ram_rd_resp_data[SEG_COUNT*SEG_DATA_WIDTH*n +: SEG_COUNT*SEG_DATA_WIDTH]),
            .dma_ram_rd_resp_valid(port_dma_ram_rd_resp_valid[SEG_COUNT*n +: SEG_COUNT]),
            .dma_ram_rd_resp_ready(port_dma_ram_rd_resp_ready[SEG_COUNT*n +: SEG_COUNT]),

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

endgenerate

endmodule

`resetall
