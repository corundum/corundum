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
module mqnic_core_pcie #
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

    // DMA interface configuration
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_PIPELINE = 2,

    // PCIe interface configuration
    parameter TLP_SEG_COUNT = 1,
    parameter TLP_SEG_DATA_WIDTH = 256,
    parameter TLP_SEG_STRB_WIDTH = TLP_SEG_DATA_WIDTH/32,
    parameter TLP_SEG_HDR_WIDTH = 128,
    parameter TX_SEQ_NUM_COUNT = 1,
    parameter TX_SEQ_NUM_WIDTH = 5,
    parameter TX_SEQ_NUM_ENABLE = 0,
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter F_COUNT = PF_COUNT+VF_COUNT,
    parameter PCIE_TAG_COUNT = 256,
    parameter PCIE_DMA_READ_OP_TABLE_SIZE = PCIE_TAG_COUNT,
    parameter PCIE_DMA_READ_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_READ_TX_FC_ENABLE = 0,
    parameter PCIE_DMA_WRITE_OP_TABLE_SIZE = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_WRITE_TX_LIMIT = 2**TX_SEQ_NUM_WIDTH,
    parameter PCIE_DMA_WRITE_TX_FC_ENABLE = 0,
    parameter TLP_FORCE_64_BIT_ADDR = 0,
    parameter CHECK_BUS_NUMBER = 1,
    parameter MSI_COUNT = 32,

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

    // Ethernet interface configuration
    parameter AXIS_DATA_WIDTH = 512,
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
    input  wire                                          clk,
    input  wire                                          rst,

    /*
     * TLP input (request to BAR)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_rx_req_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_rx_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*3-1:0]                    pcie_rx_req_tlp_bar_id,
    input  wire [TLP_SEG_COUNT*8-1:0]                    pcie_rx_req_tlp_func_num,
    input  wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      pcie_rx_req_tlp_eop,
    output wire                                          pcie_rx_req_tlp_ready,

    /*
     * TLP input (completion to DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_rx_cpl_tlp_data,
    input  wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_rx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT*4-1:0]                    pcie_rx_cpl_tlp_error,
    input  wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                      pcie_rx_cpl_tlp_eop,
    output wire                                          pcie_rx_cpl_tlp_ready,

    /*
     * TLP output (read request from DMA)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_tx_rd_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_rd_req_tlp_seq,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_rd_req_tlp_eop,
    input  wire                                          pcie_tx_rd_req_tlp_ready,

    /*
     * Transmit sequence number input (DMA read request)
     */
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_pcie_rd_req_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_pcie_rd_req_tx_seq_num_valid,

    /*
     * TLP output (write request from DMA)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_tx_wr_req_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   pcie_tx_wr_req_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_tx_wr_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]     pcie_tx_wr_req_tlp_seq,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_wr_req_tlp_eop,
    input  wire                                          pcie_tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number input (DMA write request)
     */
    input  wire [TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH-1:0]  s_axis_pcie_wr_req_tx_seq_num,
    input  wire [TX_SEQ_NUM_COUNT-1:0]                   s_axis_pcie_wr_req_tx_seq_num_valid,

    /*
     * TLP output (completion from BAR)
     */
    output wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]   pcie_tx_cpl_tlp_data,
    output wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]   pcie_tx_cpl_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]    pcie_tx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                      pcie_tx_cpl_tlp_eop,
    input  wire                                          pcie_tx_cpl_tlp_ready,

    /*
     * Flow control credits
     */
    input  wire [7:0]                                    pcie_tx_fc_ph_av,
    input  wire [11:0]                                   pcie_tx_fc_pd_av,
    input  wire [7:0]                                    pcie_tx_fc_nph_av,

    /*
     * Configuration inputs
     */
    input  wire [7:0]                                    bus_num,
    input  wire [F_COUNT-1:0]                            ext_tag_enable,
    input  wire [F_COUNT*3-1:0]                          max_read_request_size,
    input  wire [F_COUNT*3-1:0]                          max_payload_size,

    /*
     * PCIe error outputs
     */
    output wire                                          pcie_error_cor,
    output wire                                          pcie_error_uncor,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                m_axil_csr_awaddr,
    output wire [2:0]                                    m_axil_csr_awprot,
    output wire                                          m_axil_csr_awvalid,
    input  wire                                          m_axil_csr_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]               m_axil_csr_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]               m_axil_csr_wstrb,
    output wire                                          m_axil_csr_wvalid,
    input  wire                                          m_axil_csr_wready,
    input  wire [1:0]                                    m_axil_csr_bresp,
    input  wire                                          m_axil_csr_bvalid,
    output wire                                          m_axil_csr_bready,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                m_axil_csr_araddr,
    output wire [2:0]                                    m_axil_csr_arprot,
    output wire                                          m_axil_csr_arvalid,
    input  wire                                          m_axil_csr_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]               m_axil_csr_rdata,
    input  wire [1:0]                                    m_axil_csr_rresp,
    input  wire                                          m_axil_csr_rvalid,
    output wire                                          m_axil_csr_rready,

    /*
     * Control register interface
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                ctrl_reg_wr_addr,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]               ctrl_reg_wr_data,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]               ctrl_reg_wr_strb,
    output wire                                          ctrl_reg_wr_en,
    input  wire                                          ctrl_reg_wr_wait,
    input  wire                                          ctrl_reg_wr_ack,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]                ctrl_reg_rd_addr,
    output wire                                          ctrl_reg_rd_en,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]               ctrl_reg_rd_data,
    input  wire                                          ctrl_reg_rd_wait,
    input  wire                                          ctrl_reg_rd_ack,

    /*
     * MSI request outputs
     */
    output wire [MSI_COUNT-1:0]                          msi_irq,

    /*
     * PTP clock
     */
    input  wire                                          ptp_sample_clk,
    output wire                                          ptp_pps,
    output wire [PTP_TS_WIDTH-1:0]                       ptp_ts_96,
    output wire                                          ptp_ts_step,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]                   ptp_perout_pulse,

    /*
     * Ethernet
     */
    input  wire [PORT_COUNT-1:0]                         tx_clk,
    input  wire [PORT_COUNT-1:0]                         tx_rst,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            tx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                         tx_ptp_ts_step,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]         m_axis_tx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]         m_axis_tx_tkeep,
    output wire [PORT_COUNT-1:0]                         m_axis_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                         m_axis_tx_tready,
    output wire [PORT_COUNT-1:0]                         m_axis_tx_tlast,
    output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]      m_axis_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            s_axis_tx_ptp_ts,
    input  wire [PORT_COUNT*PTP_TAG_WIDTH-1:0]           s_axis_tx_ptp_ts_tag,
    input  wire [PORT_COUNT-1:0]                         s_axis_tx_ptp_ts_valid,
    output wire [PORT_COUNT-1:0]                         s_axis_tx_ptp_ts_ready,

    input  wire [PORT_COUNT-1:0]                         rx_clk,
    input  wire [PORT_COUNT-1:0]                         rx_rst,

    input  wire [PORT_COUNT-1:0]                         rx_ptp_clk,
    input  wire [PORT_COUNT-1:0]                         rx_ptp_rst,
    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]            rx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                         rx_ptp_ts_step,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]         s_axis_rx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]         s_axis_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                         s_axis_rx_tvalid,
    output wire [PORT_COUNT-1:0]                         s_axis_rx_tready,
    input  wire [PORT_COUNT-1:0]                         s_axis_rx_tlast,
    input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]      s_axis_rx_tuser,

    /*
     * Statistics increment input
     */
    input  wire [STAT_INC_WIDTH-1:0]                     s_axis_stat_tdata,
    input  wire [STAT_ID_WIDTH-1:0]                      s_axis_stat_tid,
    input  wire                                          s_axis_stat_tvalid,
    output wire                                          s_axis_stat_tready
);

parameter DMA_ADDR_WIDTH = 64;

parameter RAM_SEG_COUNT = TLP_SEG_COUNT*2;
parameter RAM_SEG_DATA_WIDTH = TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH*2/RAM_SEG_COUNT;
parameter RAM_SEG_ADDR_WIDTH = 12;
parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8;
parameter IF_RAM_SEL_WIDTH = PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1;
parameter RAM_SEL_WIDTH = $clog2(IF_COUNT+(APP_ENABLE && APP_DMA_ENABLE ? 1 : 0))+IF_RAM_SEL_WIDTH+1;
parameter RAM_ADDR_WIDTH = RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH);

parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8);

// PCIe connections
wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  pcie_ctrl_rx_req_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   pcie_ctrl_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]                   pcie_ctrl_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]                   pcie_ctrl_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                     pcie_ctrl_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                     pcie_ctrl_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                     pcie_ctrl_rx_req_tlp_eop;
wire                                         pcie_ctrl_rx_req_tlp_ready;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  pcie_ctrl_tx_cpl_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  pcie_ctrl_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   pcie_ctrl_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                     pcie_ctrl_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                     pcie_ctrl_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                     pcie_ctrl_tx_cpl_tlp_eop;
wire                                         pcie_ctrl_tx_cpl_tlp_ready;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  pcie_app_ctrl_rx_req_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   pcie_app_ctrl_rx_req_tlp_hdr;
wire [TLP_SEG_COUNT*3-1:0]                   pcie_app_ctrl_rx_req_tlp_bar_id;
wire [TLP_SEG_COUNT*8-1:0]                   pcie_app_ctrl_rx_req_tlp_func_num;
wire [TLP_SEG_COUNT-1:0]                     pcie_app_ctrl_rx_req_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                     pcie_app_ctrl_rx_req_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                     pcie_app_ctrl_rx_req_tlp_eop;
wire                                         pcie_app_ctrl_rx_req_tlp_ready;

wire [TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH-1:0]  pcie_app_ctrl_tx_cpl_tlp_data;
wire [TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH-1:0]  pcie_app_ctrl_tx_cpl_tlp_strb;
wire [TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH-1:0]   pcie_app_ctrl_tx_cpl_tlp_hdr;
wire [TLP_SEG_COUNT-1:0]                     pcie_app_ctrl_tx_cpl_tlp_valid;
wire [TLP_SEG_COUNT-1:0]                     pcie_app_ctrl_tx_cpl_tlp_sop;
wire [TLP_SEG_COUNT-1:0]                     pcie_app_ctrl_tx_cpl_tlp_eop;
wire                                         pcie_app_ctrl_tx_cpl_tlp_ready;

// AXI lite connections
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

wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]  axil_app_ctrl_awaddr;
wire [2:0]                           axil_app_ctrl_awprot;
wire                                 axil_app_ctrl_awvalid;
wire                                 axil_app_ctrl_awready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]  axil_app_ctrl_wdata;
wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]  axil_app_ctrl_wstrb;
wire                                 axil_app_ctrl_wvalid;
wire                                 axil_app_ctrl_wready;
wire [1:0]                           axil_app_ctrl_bresp;
wire                                 axil_app_ctrl_bvalid;
wire                                 axil_app_ctrl_bready;
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]  axil_app_ctrl_araddr;
wire [2:0]                           axil_app_ctrl_arprot;
wire                                 axil_app_ctrl_arvalid;
wire                                 axil_app_ctrl_arready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]  axil_app_ctrl_rdata;
wire [1:0]                           axil_app_ctrl_rresp;
wire                                 axil_app_ctrl_rvalid;
wire                                 axil_app_ctrl_rready;

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

// Error handling
wire [2:0] pcie_error_uncor_int;
wire [2:0] pcie_error_cor_int;

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

generate

if (APP_ENABLE) begin : pcie_tlp_mux

    pcie_tlp_demux_bar #(
        .PORTS(2),
        .TLP_SEG_COUNT(TLP_SEG_COUNT),
        .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
        .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
        .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
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
        .in_tlp_data(pcie_rx_req_tlp_data),
        .in_tlp_strb(0),
        .in_tlp_hdr(pcie_rx_req_tlp_hdr),
        .in_tlp_bar_id(pcie_rx_req_tlp_bar_id),
        .in_tlp_func_num(pcie_rx_req_tlp_func_num),
        .in_tlp_error(0),
        .in_tlp_valid(pcie_rx_req_tlp_valid),
        .in_tlp_sop(pcie_rx_req_tlp_sop),
        .in_tlp_eop(pcie_rx_req_tlp_eop),
        .in_tlp_ready(pcie_rx_req_tlp_ready),

        /*
         * TLP output
         */
        .out_tlp_data(    {pcie_app_ctrl_rx_req_tlp_data,     pcie_ctrl_rx_req_tlp_data    }),
        .out_tlp_strb(),
        .out_tlp_hdr(     {pcie_app_ctrl_rx_req_tlp_hdr,      pcie_ctrl_rx_req_tlp_hdr     }),
        .out_tlp_bar_id(  {pcie_app_ctrl_rx_req_tlp_bar_id,   pcie_ctrl_rx_req_tlp_bar_id  }),
        .out_tlp_func_num({pcie_app_ctrl_rx_req_tlp_func_num, pcie_ctrl_rx_req_tlp_func_num}),
        .out_tlp_error(),
        .out_tlp_valid(   {pcie_app_ctrl_rx_req_tlp_valid,    pcie_ctrl_rx_req_tlp_valid   }),
        .out_tlp_sop(     {pcie_app_ctrl_rx_req_tlp_sop,      pcie_ctrl_rx_req_tlp_sop     }),
        .out_tlp_eop(     {pcie_app_ctrl_rx_req_tlp_eop,      pcie_ctrl_rx_req_tlp_eop     }),
        .out_tlp_ready(   {pcie_app_ctrl_rx_req_tlp_ready,    pcie_ctrl_rx_req_tlp_ready   }),

        /*
         * Control
         */
        .enable(1'b1)
    );

    pcie_tlp_mux #(
        .PORTS(2),
        .TLP_SEG_COUNT(TLP_SEG_COUNT),
        .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
        .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
        .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    pcie_tlp_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * TLP input
         */
        .in_tlp_data( {pcie_app_ctrl_tx_cpl_tlp_data,  pcie_ctrl_tx_cpl_tlp_data }),
        .in_tlp_strb( {pcie_app_ctrl_tx_cpl_tlp_strb,  pcie_ctrl_tx_cpl_tlp_strb }),
        .in_tlp_hdr(  {pcie_app_ctrl_tx_cpl_tlp_hdr,   pcie_ctrl_tx_cpl_tlp_hdr  }),
        .in_tlp_bar_id(0),
        .in_tlp_func_num(0),
        .in_tlp_error(0),
        .in_tlp_valid({pcie_app_ctrl_tx_cpl_tlp_valid, pcie_ctrl_tx_cpl_tlp_valid}),
        .in_tlp_sop(  {pcie_app_ctrl_tx_cpl_tlp_sop,   pcie_ctrl_tx_cpl_tlp_sop  }),
        .in_tlp_eop(  {pcie_app_ctrl_tx_cpl_tlp_eop,   pcie_ctrl_tx_cpl_tlp_eop  }),
        .in_tlp_ready({pcie_app_ctrl_tx_cpl_tlp_ready, pcie_ctrl_tx_cpl_tlp_ready}),

        /*
         * TLP output
         */
        .out_tlp_data(pcie_tx_cpl_tlp_data),
        .out_tlp_strb(pcie_tx_cpl_tlp_strb),
        .out_tlp_hdr(pcie_tx_cpl_tlp_hdr),
        .out_tlp_bar_id(),
        .out_tlp_func_num(),
        .out_tlp_error(),
        .out_tlp_valid(pcie_tx_cpl_tlp_valid),
        .out_tlp_sop(pcie_tx_cpl_tlp_sop),
        .out_tlp_eop(pcie_tx_cpl_tlp_eop),
        .out_tlp_ready(pcie_tx_cpl_tlp_ready)
    );

end else begin

    assign pcie_ctrl_rx_req_tlp_data = pcie_rx_req_tlp_data;
    assign pcie_ctrl_rx_req_tlp_hdr = pcie_rx_req_tlp_hdr;
    assign pcie_ctrl_rx_req_tlp_bar_id = pcie_rx_req_tlp_bar_id;
    assign pcie_ctrl_rx_req_tlp_func_num = pcie_rx_req_tlp_func_num;
    assign pcie_ctrl_rx_req_tlp_valid = pcie_rx_req_tlp_valid;
    assign pcie_ctrl_rx_req_tlp_sop = pcie_rx_req_tlp_sop;
    assign pcie_ctrl_rx_req_tlp_eop = pcie_rx_req_tlp_eop;
    assign pcie_rx_req_tlp_ready = pcie_ctrl_rx_req_tlp_ready;

    assign pcie_tx_cpl_tlp_data = pcie_ctrl_tx_cpl_tlp_data;
    assign pcie_tx_cpl_tlp_strb = pcie_ctrl_tx_cpl_tlp_strb;
    assign pcie_tx_cpl_tlp_hdr = pcie_ctrl_tx_cpl_tlp_hdr;
    assign pcie_tx_cpl_tlp_valid = pcie_ctrl_tx_cpl_tlp_valid;
    assign pcie_tx_cpl_tlp_sop = pcie_ctrl_tx_cpl_tlp_sop;
    assign pcie_tx_cpl_tlp_eop = pcie_ctrl_tx_cpl_tlp_eop;
    assign pcie_ctrl_tx_cpl_tlp_ready = pcie_tx_cpl_tlp_ready;

    assign pcie_app_ctrl_rx_req_tlp_data = 0;
    assign pcie_app_ctrl_rx_req_tlp_hdr = 0;
    assign pcie_app_ctrl_rx_req_tlp_valid = 0;
    assign pcie_app_ctrl_rx_req_tlp_sop = 0;
    assign pcie_app_ctrl_rx_req_tlp_eop = 0;

    assign pcie_app_ctrl_tx_cpl_tlp_ready = 1'b1;

    assign axil_app_ctrl_awaddr = 0;
    assign axil_app_ctrl_awprot = 0;
    assign axil_app_ctrl_awvalid = 1'b0;
    assign axil_app_ctrl_wdata = 0;
    assign axil_app_ctrl_wstrb = 0;
    assign axil_app_ctrl_wvalid = 1'b0;
    assign axil_app_ctrl_bready = 1'b1;
    assign axil_app_ctrl_araddr = 0;
    assign axil_app_ctrl_arprot = 0;
    assign axil_app_ctrl_arvalid = 1'b0;
    assign axil_app_ctrl_rready = 1'b1;

    assign pcie_error_cor_int[1] = 1'b0;
    assign pcie_error_uncor_int[1] = 1'b0;

end

if (APP_ENABLE) begin : pcie_app_ctrl

    pcie_axil_master #(
        .TLP_SEG_COUNT(TLP_SEG_COUNT),
        .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
        .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
        .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
        .AXIL_DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),
        .AXIL_STRB_WIDTH(AXIL_APP_CTRL_STRB_WIDTH),
        .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
    )
    pcie_axil_master_inst (
        .clk(clk),
        .rst(rst),

        /*
         * TLP input (request)
         */
        .rx_req_tlp_data(pcie_app_ctrl_rx_req_tlp_data),
        .rx_req_tlp_hdr(pcie_app_ctrl_rx_req_tlp_hdr),
        .rx_req_tlp_valid(pcie_app_ctrl_rx_req_tlp_valid),
        .rx_req_tlp_sop(pcie_app_ctrl_rx_req_tlp_sop),
        .rx_req_tlp_eop(pcie_app_ctrl_rx_req_tlp_eop),
        .rx_req_tlp_ready(pcie_app_ctrl_rx_req_tlp_ready),

        /*
         * TLP output (completion)
         */
        .tx_cpl_tlp_data(pcie_app_ctrl_tx_cpl_tlp_data),
        .tx_cpl_tlp_strb(pcie_app_ctrl_tx_cpl_tlp_strb),
        .tx_cpl_tlp_hdr(pcie_app_ctrl_tx_cpl_tlp_hdr),
        .tx_cpl_tlp_valid(pcie_app_ctrl_tx_cpl_tlp_valid),
        .tx_cpl_tlp_sop(pcie_app_ctrl_tx_cpl_tlp_sop),
        .tx_cpl_tlp_eop(pcie_app_ctrl_tx_cpl_tlp_eop),
        .tx_cpl_tlp_ready(pcie_app_ctrl_tx_cpl_tlp_ready),

        /*
         * AXI Lite Master output
         */
        .m_axil_awaddr(axil_app_ctrl_awaddr),
        .m_axil_awprot(axil_app_ctrl_awprot),
        .m_axil_awvalid(axil_app_ctrl_awvalid),
        .m_axil_awready(axil_app_ctrl_awready),
        .m_axil_wdata(axil_app_ctrl_wdata),
        .m_axil_wstrb(axil_app_ctrl_wstrb),
        .m_axil_wvalid(axil_app_ctrl_wvalid),
        .m_axil_wready(axil_app_ctrl_wready),
        .m_axil_bresp(axil_app_ctrl_bresp),
        .m_axil_bvalid(axil_app_ctrl_bvalid),
        .m_axil_bready(axil_app_ctrl_bready),
        .m_axil_araddr(axil_app_ctrl_araddr),
        .m_axil_arprot(axil_app_ctrl_arprot),
        .m_axil_arvalid(axil_app_ctrl_arvalid),
        .m_axil_arready(axil_app_ctrl_arready),
        .m_axil_rdata(axil_app_ctrl_rdata),
        .m_axil_rresp(axil_app_ctrl_rresp),
        .m_axil_rvalid(axil_app_ctrl_rvalid),
        .m_axil_rready(axil_app_ctrl_rready),

        /*
         * Configuration
         */
        .completer_id({bus_num, 5'd0, 3'd0}),

        /*
         * Status
         */
        .status_error_cor(pcie_error_cor_int[1]),
        .status_error_uncor(pcie_error_uncor_int[1])
    );

end else begin

    assign pcie_app_ctrl_rx_req_tlp_ready = 1'b1;

    assign pcie_app_ctrl_tx_cpl_tlp_data = 0;
    assign pcie_app_ctrl_tx_cpl_tlp_strb = 0;
    assign pcie_app_ctrl_tx_cpl_tlp_hdr = 0;
    assign pcie_app_ctrl_tx_cpl_tlp_valid = 0;
    assign pcie_app_ctrl_tx_cpl_tlp_sop = 0;
    assign pcie_app_ctrl_tx_cpl_tlp_eop = 0;

    assign axil_app_ctrl_awaddr = 0;
    assign axil_app_ctrl_awprot = 0;
    assign axil_app_ctrl_awvalid = 1'b0;
    assign axil_app_ctrl_wdata = 0;
    assign axil_app_ctrl_wstrb = 0;
    assign axil_app_ctrl_wvalid = 1'b0;
    assign axil_app_ctrl_bready = 1'b1;
    assign axil_app_ctrl_araddr = 0;
    assign axil_app_ctrl_arprot = 0;
    assign axil_app_ctrl_arvalid = 1'b0;
    assign axil_app_ctrl_rready = 1'b1;

    assign pcie_error_cor_int[1] = 1'b0;
    assign pcie_error_uncor_int[1] = 1'b0;

end

endgenerate

pcie_axil_master #(
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_STRB_WIDTH(TLP_SEG_STRB_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
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
    .rx_req_tlp_data(pcie_ctrl_rx_req_tlp_data),
    .rx_req_tlp_hdr(pcie_ctrl_rx_req_tlp_hdr),
    .rx_req_tlp_valid(pcie_ctrl_rx_req_tlp_valid),
    .rx_req_tlp_sop(pcie_ctrl_rx_req_tlp_sop),
    .rx_req_tlp_eop(pcie_ctrl_rx_req_tlp_eop),
    .rx_req_tlp_ready(pcie_ctrl_rx_req_tlp_ready),

    /*
     * TLP output (completion)
     */
    .tx_cpl_tlp_data(pcie_ctrl_tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(pcie_ctrl_tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(pcie_ctrl_tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(pcie_ctrl_tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(pcie_ctrl_tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(pcie_ctrl_tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(pcie_ctrl_tx_cpl_tlp_ready),

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
    .status_error_cor(pcie_error_cor_int[0]),
    .status_error_uncor(pcie_error_uncor_int[0])
);

wire [$clog2(PCIE_DMA_READ_OP_TABLE_SIZE)-1:0] stat_rd_op_start_tag;
wire [DMA_LEN_WIDTH-1:0] stat_rd_op_start_len;
wire stat_rd_op_start_valid;
wire [$clog2(PCIE_DMA_READ_OP_TABLE_SIZE)-1:0] stat_rd_op_finish_tag;
wire [3:0] stat_rd_op_finish_status;
wire stat_rd_op_finish_valid;
wire [$clog2(PCIE_TAG_COUNT)-1:0] stat_rd_req_start_tag;
wire [12:0] stat_rd_req_start_len;
wire stat_rd_req_start_valid;
wire [$clog2(PCIE_TAG_COUNT)-1:0] stat_rd_req_finish_tag;
wire [3:0] stat_rd_req_finish_status;
wire stat_rd_req_finish_valid;
wire stat_rd_req_timeout;
wire stat_rd_op_table_full;
wire stat_rd_no_tags;
wire stat_rd_tx_no_credit;
wire stat_rd_tx_limit;
wire stat_rd_tx_stall;
wire [$clog2(PCIE_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_op_start_tag;
wire [DMA_LEN_WIDTH-1:0] stat_wr_op_start_len;
wire stat_wr_op_start_valid;
wire [$clog2(PCIE_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_op_finish_tag;
wire [3:0] stat_wr_op_finish_status;
wire stat_wr_op_finish_valid;
wire [$clog2(PCIE_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_req_start_tag;
wire [12:0] stat_wr_req_start_len;
wire stat_wr_req_start_valid;
wire [$clog2(PCIE_DMA_WRITE_OP_TABLE_SIZE)-1:0] stat_wr_req_finish_tag;
wire [3:0] stat_wr_req_finish_status;
wire stat_wr_req_finish_valid;
wire stat_wr_op_table_full;
wire stat_wr_tx_no_credit;
wire stat_wr_tx_limit;
wire stat_wr_tx_stall;

dma_if_pcie #(
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TLP_SEG_DATA_WIDTH(TLP_SEG_DATA_WIDTH),
    .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
    .TX_SEQ_NUM_COUNT(TX_SEQ_NUM_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .TX_SEQ_NUM_ENABLE(TX_SEQ_NUM_ENABLE),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .PCIE_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .TAG_WIDTH(DMA_TAG_WIDTH),
    .READ_OP_TABLE_SIZE(PCIE_DMA_READ_OP_TABLE_SIZE),
    .READ_TX_LIMIT(PCIE_DMA_READ_TX_LIMIT),
    .READ_TX_FC_ENABLE(PCIE_DMA_READ_TX_FC_ENABLE),
    .WRITE_OP_TABLE_SIZE(PCIE_DMA_WRITE_OP_TABLE_SIZE),
    .WRITE_TX_LIMIT(PCIE_DMA_WRITE_TX_LIMIT),
    .WRITE_TX_FC_ENABLE(PCIE_DMA_WRITE_TX_FC_ENABLE),
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR),
    .CHECK_BUS_NUMBER(CHECK_BUS_NUMBER)
)
dma_if_pcie_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input (completion)
     */
    .rx_cpl_tlp_data(pcie_rx_cpl_tlp_data),
    .rx_cpl_tlp_hdr(pcie_rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(pcie_rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(pcie_rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(pcie_rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(pcie_rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(pcie_rx_cpl_tlp_ready),

    /*
     * TLP output (read request)
     */
    .tx_rd_req_tlp_hdr(pcie_tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(pcie_tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(pcie_tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(pcie_tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(pcie_tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(pcie_tx_rd_req_tlp_ready),

    /*
     * TLP output (write request)
     */
    .tx_wr_req_tlp_data(pcie_tx_wr_req_tlp_data),
    .tx_wr_req_tlp_strb(pcie_tx_wr_req_tlp_strb),
    .tx_wr_req_tlp_hdr(pcie_tx_wr_req_tlp_hdr),
    .tx_wr_req_tlp_seq(pcie_tx_wr_req_tlp_seq),
    .tx_wr_req_tlp_valid(pcie_tx_wr_req_tlp_valid),
    .tx_wr_req_tlp_sop(pcie_tx_wr_req_tlp_sop),
    .tx_wr_req_tlp_eop(pcie_tx_wr_req_tlp_eop),
    .tx_wr_req_tlp_ready(pcie_tx_wr_req_tlp_ready),

    /*
     * Transmit sequence number input
     */
    .s_axis_rd_req_tx_seq_num(s_axis_pcie_rd_req_tx_seq_num),
    .s_axis_rd_req_tx_seq_num_valid(s_axis_pcie_rd_req_tx_seq_num_valid),
    .s_axis_wr_req_tx_seq_num(s_axis_pcie_wr_req_tx_seq_num),
    .s_axis_wr_req_tx_seq_num_valid(s_axis_pcie_wr_req_tx_seq_num_valid),

    /*
     * Transmit flow control
     */
    .pcie_tx_fc_ph_av(pcie_tx_fc_ph_av),
    .pcie_tx_fc_pd_av(pcie_tx_fc_pd_av),
    .pcie_tx_fc_nph_av(pcie_tx_fc_nph_av),

    /*
     * AXI read descriptor input
     */
    .s_axis_read_desc_pcie_addr(dma_read_desc_dma_addr),
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
    .s_axis_write_desc_pcie_addr(dma_write_desc_dma_addr),
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
    .write_enable(dma_enable),
    .ext_tag_enable(ext_tag_enable),
    .requester_id({bus_num, 5'd0, 3'd0}),
    .max_read_request_size(max_read_request_size),
    .max_payload_size(max_payload_size),

    /*
     * Status
     */
    .status_error_cor(pcie_error_cor_int[2]),
    .status_error_uncor(pcie_error_uncor_int[2]),

    /*
     * Statistics
     */
    .stat_rd_op_start_tag(stat_rd_op_start_tag),
    .stat_rd_op_start_len(stat_rd_op_start_len),
    .stat_rd_op_start_valid(stat_rd_op_start_valid),
    .stat_rd_op_finish_tag(stat_rd_op_finish_tag),
    .stat_rd_op_finish_status(stat_rd_op_finish_status),
    .stat_rd_op_finish_valid(stat_rd_op_finish_valid),
    .stat_rd_req_start_tag(stat_rd_req_start_tag),
    .stat_rd_req_start_len(stat_rd_req_start_len),
    .stat_rd_req_start_valid(stat_rd_req_start_valid),
    .stat_rd_req_finish_tag(stat_rd_req_finish_tag),
    .stat_rd_req_finish_status(stat_rd_req_finish_status),
    .stat_rd_req_finish_valid(stat_rd_req_finish_valid),
    .stat_rd_req_timeout(stat_rd_req_timeout),
    .stat_rd_op_table_full(stat_rd_op_table_full),
    .stat_rd_no_tags(stat_rd_no_tags),
    .stat_rd_tx_no_credit(stat_rd_tx_no_credit),
    .stat_rd_tx_limit(stat_rd_tx_limit),
    .stat_rd_tx_stall(stat_rd_tx_stall),
    .stat_wr_op_start_tag(stat_wr_op_start_tag),
    .stat_wr_op_start_len(stat_wr_op_start_len),
    .stat_wr_op_start_valid(stat_wr_op_start_valid),
    .stat_wr_op_finish_tag(stat_wr_op_finish_tag),
    .stat_wr_op_finish_status(stat_wr_op_finish_status),
    .stat_wr_op_finish_valid(stat_wr_op_finish_valid),
    .stat_wr_req_start_tag(stat_wr_req_start_tag),
    .stat_wr_req_start_len(stat_wr_req_start_len),
    .stat_wr_req_start_valid(stat_wr_req_start_valid),
    .stat_wr_req_finish_tag(stat_wr_req_finish_tag),
    .stat_wr_req_finish_status(stat_wr_req_finish_status),
    .stat_wr_req_finish_valid(stat_wr_req_finish_valid),
    .stat_wr_op_table_full(stat_wr_op_table_full),
    .stat_wr_tx_no_credit(stat_wr_tx_no_credit),
    .stat_wr_tx_limit(stat_wr_tx_limit),
    .stat_wr_tx_stall(stat_wr_tx_stall)
);

pulse_merge #(
    .INPUT_WIDTH(3),
    .COUNT_WIDTH(4)
)
pcie_error_cor_pm_inst (
    .clk(clk),
    .rst(rst),

    .pulse_in(pcie_error_cor_int),
    .count_out(),
    .pulse_out(pcie_error_cor)
);

pulse_merge #(
    .INPUT_WIDTH(3),
    .COUNT_WIDTH(4)
)
pcie_error_uncor_pm_inst (
    .clk(clk),
    .rst(rst),

    .pulse_in(pcie_error_uncor_int),
    .count_out(),
    .pulse_out(pcie_error_uncor)
);

wire [STAT_INC_WIDTH-1:0]  axis_stat_tdata;
wire [STAT_ID_WIDTH-1:0]   axis_stat_tid;
wire                       axis_stat_tvalid;
wire                       axis_stat_tready;

wire [STAT_INC_WIDTH-1:0]  axis_stat_pcie_tdata;
wire [STAT_ID_WIDTH-1:0]   axis_stat_pcie_tid;
wire                       axis_stat_pcie_tvalid;
wire                       axis_stat_pcie_tready;

wire [STAT_INC_WIDTH-1:0]  axis_stat_dma_tdata;
wire [STAT_ID_WIDTH-1:0]   axis_stat_dma_tid;
wire                       axis_stat_dma_tvalid;
wire                       axis_stat_dma_tready;

generate

if (STAT_ENABLE && STAT_PCIE_ENABLE) begin : stats_pcie_if

    stats_pcie_if #(
        .TLP_SEG_COUNT(TLP_SEG_COUNT),
        .TLP_SEG_HDR_WIDTH(TLP_SEG_HDR_WIDTH),
        .STAT_INC_WIDTH(STAT_INC_WIDTH),
        .STAT_ID_WIDTH(5),
        .UPDATE_PERIOD(1024)
    )
    stats_pcie_if_inst (
        .clk(clk),
        .rst(rst),

        /*
         * monitor input (request to BAR)
         */
        .rx_req_tlp_hdr(pcie_rx_req_tlp_hdr),
        .rx_req_tlp_valid(pcie_rx_req_tlp_valid && pcie_rx_req_tlp_ready),
        .rx_req_tlp_sop(pcie_rx_req_tlp_sop),
        .rx_req_tlp_eop(pcie_rx_req_tlp_eop),

        /*
         * monitor input (completion to DMA)
         */
        .rx_cpl_tlp_hdr(pcie_rx_cpl_tlp_hdr),
        .rx_cpl_tlp_valid(pcie_rx_cpl_tlp_valid && pcie_rx_cpl_tlp_ready),
        .rx_cpl_tlp_sop(pcie_rx_cpl_tlp_sop),
        .rx_cpl_tlp_eop(pcie_rx_cpl_tlp_eop),

        /*
         * monitor input (read request from DMA)
         */
        .tx_rd_req_tlp_hdr(pcie_tx_rd_req_tlp_hdr),
        .tx_rd_req_tlp_valid(pcie_tx_rd_req_tlp_valid && pcie_tx_rd_req_tlp_ready),
        .tx_rd_req_tlp_sop(pcie_tx_rd_req_tlp_sop),
        .tx_rd_req_tlp_eop(pcie_tx_rd_req_tlp_eop),

        /*
         * monitor input (write request from DMA)
         */
        .tx_wr_req_tlp_hdr(pcie_tx_wr_req_tlp_hdr),
        .tx_wr_req_tlp_valid(pcie_tx_wr_req_tlp_valid && pcie_tx_wr_req_tlp_ready),
        .tx_wr_req_tlp_sop(pcie_tx_wr_req_tlp_sop),
        .tx_wr_req_tlp_eop(pcie_tx_wr_req_tlp_eop),

        /*
         * monitor input (completion from BAR)
         */
        .tx_cpl_tlp_hdr(pcie_tx_cpl_tlp_hdr),
        .tx_cpl_tlp_valid(pcie_tx_cpl_tlp_valid && pcie_tx_cpl_tlp_ready),
        .tx_cpl_tlp_sop(pcie_tx_cpl_tlp_sop),
        .tx_cpl_tlp_eop(pcie_tx_cpl_tlp_eop),

        /*
         * Statistics output
         */
        .m_axis_stat_tdata(axis_stat_pcie_tdata),
        .m_axis_stat_tid(axis_stat_pcie_tid[4:0]),
        .m_axis_stat_tvalid(axis_stat_pcie_tvalid),
        .m_axis_stat_tready(axis_stat_pcie_tready),

        /*
         * Control inputs
         */
        .update(1'b0)
    );

    assign axis_stat_pcie_tid[STAT_ID_WIDTH-1:5] = 0;

end else begin

    assign axis_stat_pcie_tdata = 0;
    assign axis_stat_pcie_tid = 0;
    assign axis_stat_pcie_tvalid = 0;

end

if (STAT_ENABLE && STAT_DMA_ENABLE) begin : stats_dma_if_pcie

    stats_dma_if_pcie #(
        .PCIE_TAG_COUNT(PCIE_TAG_COUNT),
        .LEN_WIDTH(DMA_LEN_WIDTH),
        .READ_OP_TABLE_SIZE(PCIE_DMA_READ_OP_TABLE_SIZE),
        .WRITE_OP_TABLE_SIZE(PCIE_DMA_WRITE_OP_TABLE_SIZE),
        .STAT_INC_WIDTH(STAT_INC_WIDTH),
        .STAT_ID_WIDTH(5),
        .UPDATE_PERIOD(1024)
    )
    stats_dma_if_pcie_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Statistics from dma_if_pcie
         */
        .stat_rd_op_start_tag(stat_rd_op_start_tag),
        .stat_rd_op_start_len(stat_rd_op_start_len),
        .stat_rd_op_start_valid(stat_rd_op_start_valid),
        .stat_rd_op_finish_tag(stat_rd_op_finish_tag),
        .stat_rd_op_finish_status(stat_rd_op_finish_status),
        .stat_rd_op_finish_valid(stat_rd_op_finish_valid),
        .stat_rd_req_start_tag(stat_rd_req_start_tag),
        .stat_rd_req_start_len(stat_rd_req_start_len),
        .stat_rd_req_start_valid(stat_rd_req_start_valid),
        .stat_rd_req_finish_tag(stat_rd_req_finish_tag),
        .stat_rd_req_finish_status(stat_rd_req_finish_status),
        .stat_rd_req_finish_valid(stat_rd_req_finish_valid),
        .stat_rd_req_timeout(stat_rd_req_timeout),
        .stat_rd_op_table_full(stat_rd_op_table_full),
        .stat_rd_no_tags(stat_rd_no_tags),
        .stat_rd_tx_no_credit(stat_rd_tx_no_credit),
        .stat_rd_tx_limit(stat_rd_tx_limit),
        .stat_rd_tx_stall(stat_rd_tx_stall),
        .stat_wr_op_start_tag(stat_wr_op_start_tag),
        .stat_wr_op_start_len(stat_wr_op_start_len),
        .stat_wr_op_start_valid(stat_wr_op_start_valid),
        .stat_wr_op_finish_tag(stat_wr_op_finish_tag),
        .stat_wr_op_finish_status(stat_wr_op_finish_status),
        .stat_wr_op_finish_valid(stat_wr_op_finish_valid),
        .stat_wr_req_start_tag(stat_wr_req_start_tag),
        .stat_wr_req_start_len(stat_wr_req_start_len),
        .stat_wr_req_start_valid(stat_wr_req_start_valid),
        .stat_wr_req_finish_tag(stat_wr_req_finish_tag),
        .stat_wr_req_finish_status(stat_wr_req_finish_status),
        .stat_wr_req_finish_valid(stat_wr_req_finish_valid),
        .stat_wr_op_table_full(stat_wr_op_table_full),
        .stat_wr_tx_no_credit(stat_wr_tx_no_credit),
        .stat_wr_tx_limit(stat_wr_tx_limit),
        .stat_wr_tx_stall(stat_wr_tx_stall),

        /*
         * Statistics output
         */
        .m_axis_stat_tdata(axis_stat_dma_tdata),
        .m_axis_stat_tid(axis_stat_dma_tid[4:0]),
        .m_axis_stat_tvalid(axis_stat_dma_tvalid),
        .m_axis_stat_tready(axis_stat_dma_tready),

        /*
         * Control inputs
         */
        .update(1'b0)
    );

    assign axis_stat_dma_tid[STAT_ID_WIDTH-1:5] = 1;

end else begin

    assign axis_stat_dma_tdata = 0;
    assign axis_stat_dma_tid = 0;
    assign axis_stat_dma_tvalid = 0;

end

if (STAT_ENABLE && (STAT_DMA_ENABLE || STAT_PCIE_ENABLE)) begin : stats_mux

    axis_arb_mux #(
        .S_COUNT(3),
        .DATA_WIDTH(STAT_INC_WIDTH),
        .KEEP_ENABLE(0),
        .ID_ENABLE(1),
        .S_ID_WIDTH(STAT_ID_WIDTH),
        .M_ID_WIDTH(STAT_ID_WIDTH),
        .DEST_ENABLE(0),
        .USER_ENABLE(0),
        .LAST_ENABLE(0),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    axis_stat_mux_inst (
        .clk(clk),
        .rst(rst),

        /*
         * AXI Stream inputs
         */
        .s_axis_tdata({axis_stat_dma_tdata, axis_stat_pcie_tdata, s_axis_stat_tdata}),
        .s_axis_tkeep(0),
        .s_axis_tvalid({axis_stat_dma_tvalid, axis_stat_pcie_tvalid, s_axis_stat_tvalid}),
        .s_axis_tready({axis_stat_dma_tready, axis_stat_pcie_tready, s_axis_stat_tready}),
        .s_axis_tlast(0),
        .s_axis_tid({axis_stat_dma_tid, axis_stat_pcie_tid, s_axis_stat_tid}),
        .s_axis_tdest(0),
        .s_axis_tuser(0),

        /*
         * AXI Stream output
         */
        .m_axis_tdata(axis_stat_tdata),
        .m_axis_tkeep(),
        .m_axis_tvalid(axis_stat_tvalid),
        .m_axis_tready(axis_stat_tready),
        .m_axis_tlast(),
        .m_axis_tid(axis_stat_tid),
        .m_axis_tdest(),
        .m_axis_tuser()
    );

end else begin

    assign axis_stat_tdata = s_axis_stat_tdata;
    assign axis_stat_tid = s_axis_stat_tid;
    assign axis_stat_tvalid = s_axis_stat_tvalid;
    assign s_axis_stat_tready = axis_stat_tready;

end

endgenerate

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

    .MSI_COUNT(MSI_COUNT),

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
     * AXI-Lite slave interface (application control)
     */
    .s_axil_app_ctrl_awaddr(axil_app_ctrl_awaddr),
    .s_axil_app_ctrl_awprot(axil_app_ctrl_awprot),
    .s_axil_app_ctrl_awvalid(axil_app_ctrl_awvalid),
    .s_axil_app_ctrl_awready(axil_app_ctrl_awready),
    .s_axil_app_ctrl_wdata(axil_app_ctrl_wdata),
    .s_axil_app_ctrl_wstrb(axil_app_ctrl_wstrb),
    .s_axil_app_ctrl_wvalid(axil_app_ctrl_wvalid),
    .s_axil_app_ctrl_wready(axil_app_ctrl_wready),
    .s_axil_app_ctrl_bresp(axil_app_ctrl_bresp),
    .s_axil_app_ctrl_bvalid(axil_app_ctrl_bvalid),
    .s_axil_app_ctrl_bready(axil_app_ctrl_bready),
    .s_axil_app_ctrl_araddr(axil_app_ctrl_araddr),
    .s_axil_app_ctrl_arprot(axil_app_ctrl_arprot),
    .s_axil_app_ctrl_arvalid(axil_app_ctrl_arvalid),
    .s_axil_app_ctrl_arready(axil_app_ctrl_arready),
    .s_axil_app_ctrl_rdata(axil_app_ctrl_rdata),
    .s_axil_app_ctrl_rresp(axil_app_ctrl_rresp),
    .s_axil_app_ctrl_rvalid(axil_app_ctrl_rvalid),
    .s_axil_app_ctrl_rready(axil_app_ctrl_rready),

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
    .msi_irq(msi_irq),

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
    .s_axis_stat_tdata(axis_stat_tdata),
    .s_axis_stat_tid(axis_stat_tid),
    .s_axis_stat_tvalid(axis_stat_tvalid),
    .s_axis_stat_tready(axis_stat_tready)
);

endmodule

`resetall
