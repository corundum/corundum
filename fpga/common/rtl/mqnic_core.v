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

`timescale 1ns / 1ps

/*
 * FPGA core logic
 */
module mqnic_core #
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

    // DMA interface configuration
    parameter DMA_ADDR_WIDTH = 64,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_ADDR_WIDTH = 12,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter IF_RAM_SEL_WIDTH = PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1,
    parameter RAM_SEL_WIDTH = $clog2(IF_COUNT)+IF_RAM_SEL_WIDTH+1,
    parameter RAM_ADDR_WIDTH = RAM_SEG_ADDR_WIDTH+$clog2(RAM_SEG_COUNT)+$clog2(RAM_SEG_BE_WIDTH),
    parameter RAM_PIPELINE = 2,

    parameter MSI_COUNT = 32,

    // AXI lite interface configuration (control)
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter IF_AXIL_ADDR_WIDTH = AXIL_ADDR_WIDTH-$clog2(IF_COUNT),
    parameter AXIL_CSR_ADDR_WIDTH = IF_AXIL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8),
    parameter AXIL_CSR_PASSTHROUGH_ENABLE = 0,

    // Ethernet interface configuration
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_INT_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_TX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TAG_WIDTH : 0) + 1,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_RX_USE_READY = 0,
    parameter AXIS_TX_PIPELINE = 0,
    parameter AXIS_TX_FIFO_PIPELINE = 2,
    parameter AXIS_TX_TS_PIPELINE = 0,
    parameter AXIS_RX_PIPELINE = 0,
    parameter AXIS_RX_FIFO_PIPELINE = 2
)
(
    input  wire                                         clk,
    input  wire                                         rst,

    /*
     * AXI-Lite slave interface (control)
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_awaddr,
    input  wire [2:0]                                   s_axil_awprot,
    input  wire                                         s_axil_awvalid,
    output wire                                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]                   s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]                   s_axil_wstrb,
    input  wire                                         s_axil_wvalid,
    output wire                                         s_axil_wready,
    output wire [1:0]                                   s_axil_bresp,
    output wire                                         s_axil_bvalid,
    input  wire                                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]                   s_axil_araddr,
    input  wire [2:0]                                   s_axil_arprot,
    input  wire                                         s_axil_arvalid,
    output wire                                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]                   s_axil_rdata,
    output wire [1:0]                                   s_axil_rresp,
    output wire                                         s_axil_rvalid,
    input  wire                                         s_axil_rready,

    /*
     * AXI-Lite master interface (passthrough for NIC control and status)
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               m_axil_csr_awaddr,
    output wire [2:0]                                   m_axil_csr_awprot,
    output wire                                         m_axil_csr_awvalid,
    input  wire                                         m_axil_csr_awready,
    output wire [AXIL_DATA_WIDTH-1:0]                   m_axil_csr_wdata,
    output wire [AXIL_STRB_WIDTH-1:0]                   m_axil_csr_wstrb,
    output wire                                         m_axil_csr_wvalid,
    input  wire                                         m_axil_csr_wready,
    input  wire [1:0]                                   m_axil_csr_bresp,
    input  wire                                         m_axil_csr_bvalid,
    output wire                                         m_axil_csr_bready,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               m_axil_csr_araddr,
    output wire [2:0]                                   m_axil_csr_arprot,
    output wire                                         m_axil_csr_arvalid,
    input  wire                                         m_axil_csr_arready,
    input  wire [AXIL_DATA_WIDTH-1:0]                   m_axil_csr_rdata,
    input  wire [1:0]                                   m_axil_csr_rresp,
    input  wire                                         m_axil_csr_rvalid,
    output wire                                         m_axil_csr_rready,

    /*
     * Control register interface
     */
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               ctrl_reg_wr_addr,
    output wire [AXIL_DATA_WIDTH-1:0]                   ctrl_reg_wr_data,
    output wire [AXIL_STRB_WIDTH-1:0]                   ctrl_reg_wr_strb,
    output wire                                         ctrl_reg_wr_en,
    input  wire                                         ctrl_reg_wr_wait,
    input  wire                                         ctrl_reg_wr_ack,
    output wire [AXIL_CSR_ADDR_WIDTH-1:0]               ctrl_reg_rd_addr,
    output wire                                         ctrl_reg_rd_en,
    input  wire [AXIL_DATA_WIDTH-1:0]                   ctrl_reg_rd_data,
    input  wire                                         ctrl_reg_rd_wait,
    input  wire                                         ctrl_reg_rd_ack,

    /*
     * DMA read descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_read_desc_tag,
    output wire                                         m_axis_dma_read_desc_valid,
    input  wire                                         m_axis_dma_read_desc_ready,

    /*
     * DMA read descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_read_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_read_desc_status_error,
    input  wire                                         s_axis_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output
     */
    output wire [DMA_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                    m_axis_dma_write_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                     m_axis_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                     m_axis_dma_write_desc_tag,
    output wire                                         m_axis_dma_write_desc_valid,
    input  wire                                         m_axis_dma_write_desc_ready,

    /*
     * DMA write descriptor status input
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_dma_write_desc_status_tag,
    input  wire [3:0]                                   s_axis_dma_write_desc_status_error,
    input  wire                                         s_axis_dma_write_desc_status_valid,

    /*
     * DMA RAM interface
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]       dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     dma_ram_rd_resp_ready,

    /*
     * MSI request outputs
     */
    output wire [MSI_COUNT-1:0]                         msi_irq,

    /*
     * PTP clock
     */
    input  wire                                         ptp_sample_clk,
    output wire                                         ptp_pps,
    output wire [PTP_TS_WIDTH-1:0]                      ptp_ts_96,
    output wire                                         ptp_ts_step,
    output wire [PTP_PEROUT_COUNT-1:0]                  ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]                  ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]                  ptp_perout_pulse,

    /*
     * Ethernet
     */
    input  wire [PORT_COUNT-1:0]                        tx_clk,
    input  wire [PORT_COUNT-1:0]                        tx_rst,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           tx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                        tx_ptp_ts_step,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        m_axis_tx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        m_axis_tx_tkeep,
    output wire [PORT_COUNT-1:0]                        m_axis_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                        m_axis_tx_tready,
    output wire [PORT_COUNT-1:0]                        m_axis_tx_tlast,
    output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]     m_axis_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           s_axis_tx_ptp_ts,
    input  wire [PORT_COUNT*PTP_TAG_WIDTH-1:0]          s_axis_tx_ptp_ts_tag,
    input  wire [PORT_COUNT-1:0]                        s_axis_tx_ptp_ts_valid,
    output wire [PORT_COUNT-1:0]                        s_axis_tx_ptp_ts_ready,

    input  wire [PORT_COUNT-1:0]                        rx_clk,
    input  wire [PORT_COUNT-1:0]                        rx_rst,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]           rx_ptp_ts_96,
    output wire [PORT_COUNT-1:0]                        rx_ptp_ts_step,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]        s_axis_rx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]        s_axis_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                        s_axis_rx_tvalid,
    output wire [PORT_COUNT-1:0]                        s_axis_rx_tready,
    input  wire [PORT_COUNT-1:0]                        s_axis_rx_tlast,
    input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]     s_axis_rx_tuser
);

parameter IF_DMA_TAG_WIDTH = DMA_TAG_WIDTH-$clog2(IF_COUNT)-1;

parameter AXIS_INT_KEEP_WIDTH = AXIS_INT_DATA_WIDTH/(AXIS_DATA_WIDTH/AXIS_KEEP_WIDTH);

// parameter sizing helpers
function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

// AXI lite connections
wire [AXIL_CSR_ADDR_WIDTH-1:0] axil_csr_awaddr;
wire [2:0]                     axil_csr_awprot;
wire                           axil_csr_awvalid;
wire                           axil_csr_awready;
wire [AXIL_DATA_WIDTH-1:0]     axil_csr_wdata;
wire [AXIL_STRB_WIDTH-1:0]     axil_csr_wstrb;
wire                           axil_csr_wvalid;
wire                           axil_csr_wready;
wire [1:0]                     axil_csr_bresp;
wire                           axil_csr_bvalid;
wire                           axil_csr_bready;
wire [AXIL_CSR_ADDR_WIDTH-1:0] axil_csr_araddr;
wire [2:0]                     axil_csr_arprot;
wire                           axil_csr_arvalid;
wire                           axil_csr_arready;
wire [AXIL_DATA_WIDTH-1:0]     axil_csr_rdata;
wire [1:0]                     axil_csr_rresp;
wire                           axil_csr_rvalid;
wire                           axil_csr_rready;

// control registers
wire ctrl_reg_wr_wait_int;
wire ctrl_reg_wr_ack_int;
wire [AXIL_DATA_WIDTH-1:0] ctrl_reg_rd_data_int;
wire ctrl_reg_rd_wait_int;
wire ctrl_reg_rd_ack_int;

axil_reg_if #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .TIMEOUT(4)
)
axil_reg_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_csr_awaddr),
    .s_axil_awprot(axil_csr_awprot),
    .s_axil_awvalid(axil_csr_awvalid),
    .s_axil_awready(axil_csr_awready),
    .s_axil_wdata(axil_csr_wdata),
    .s_axil_wstrb(axil_csr_wstrb),
    .s_axil_wvalid(axil_csr_wvalid),
    .s_axil_wready(axil_csr_wready),
    .s_axil_bresp(axil_csr_bresp),
    .s_axil_bvalid(axil_csr_bvalid),
    .s_axil_bready(axil_csr_bready),
    .s_axil_araddr(axil_csr_araddr),
    .s_axil_arprot(axil_csr_arprot),
    .s_axil_arvalid(axil_csr_arvalid),
    .s_axil_arready(axil_csr_arready),
    .s_axil_rdata(axil_csr_rdata),
    .s_axil_rresp(axil_csr_rresp),
    .s_axil_rvalid(axil_csr_rvalid),
    .s_axil_rready(axil_csr_rready),

    /*
     * Register interface
     */
    .reg_wr_addr(ctrl_reg_wr_addr),
    .reg_wr_data(ctrl_reg_wr_data),
    .reg_wr_strb(ctrl_reg_wr_strb),
    .reg_wr_en(ctrl_reg_wr_en),
    .reg_wr_wait(ctrl_reg_wr_wait_int),
    .reg_wr_ack(ctrl_reg_wr_ack_int),
    .reg_rd_addr(ctrl_reg_rd_addr),
    .reg_rd_en(ctrl_reg_rd_en),
    .reg_rd_data(ctrl_reg_rd_data_int),
    .reg_rd_wait(ctrl_reg_rd_wait_int),
    .reg_rd_ack(ctrl_reg_rd_ack_int)
);

wire ptp_ctrl_reg_wr_wait;
wire ptp_ctrl_reg_wr_ack;
wire [AXIL_DATA_WIDTH-1:0] ptp_ctrl_reg_rd_data;
wire ptp_ctrl_reg_rd_wait;
wire ptp_ctrl_reg_rd_ack;

reg ctrl_reg_wr_ack_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = {AXIL_DATA_WIDTH{1'b0}};
reg ctrl_reg_rd_ack_reg = 1'b0;

assign ctrl_reg_wr_wait_int = ctrl_reg_wr_wait | ptp_ctrl_reg_wr_wait;
assign ctrl_reg_wr_ack_int = ctrl_reg_wr_ack | ctrl_reg_wr_ack_reg | ptp_ctrl_reg_wr_ack;
assign ctrl_reg_rd_data_int = ctrl_reg_rd_data | ctrl_reg_rd_data_reg | ptp_ctrl_reg_rd_data;
assign ctrl_reg_rd_wait_int = ctrl_reg_rd_wait | ptp_ctrl_reg_rd_wait;
assign ctrl_reg_rd_ack_int = ctrl_reg_rd_ack | ctrl_reg_rd_ack_reg | ptp_ctrl_reg_rd_ack;

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
            8'h00: ctrl_reg_rd_data_reg <= FW_ID;      // fw_id
            8'h04: ctrl_reg_rd_data_reg <= FW_VER;     // fw_ver
            8'h08: ctrl_reg_rd_data_reg <= BOARD_ID;   // board_id
            8'h0C: ctrl_reg_rd_data_reg <= BOARD_VER;  // board_ver
            8'h10: ctrl_reg_rd_data_reg <= 1;          // phc_count
            8'h14: ctrl_reg_rd_data_reg <= 16'h0200;   // phc_offset
            8'h18: ctrl_reg_rd_data_reg <= 16'h0080;   // phc_stride
            8'h20: ctrl_reg_rd_data_reg <= IF_COUNT;   // if_count
            8'h24: ctrl_reg_rd_data_reg <= 2**IF_AXIL_ADDR_WIDTH; // if_stride
            8'h2C: ctrl_reg_rd_data_reg <= 2**AXIL_CSR_ADDR_WIDTH; // if_csr_offset
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;
    end
end

mqnic_ptp #(
    .PTP_PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .PTP_OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .PTP_FNS_WIDTH(PTP_FNS_WIDTH),
    .PTP_PERIOD_NS(PTP_PERIOD_NS),
    .PTP_PERIOD_FNS(PTP_PERIOD_FNS),
    .PTP_PEROUT_ENABLE(PTP_PEROUT_ENABLE),
    .PTP_PEROUT_COUNT(PTP_PEROUT_COUNT),
    .REG_ADDR_WIDTH(8),
    .REG_DATA_WIDTH(AXIL_DATA_WIDTH),
    .REG_STRB_WIDTH(AXIL_STRB_WIDTH)
)
mqnic_ptp_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Register interface
     */
    .reg_wr_addr(ctrl_reg_wr_addr),
    .reg_wr_data(ctrl_reg_wr_data),
    .reg_wr_strb(ctrl_reg_wr_strb),
    .reg_wr_en(ctrl_reg_wr_en && (ctrl_reg_wr_addr >> 8 == 2)),
    .reg_wr_wait(ptp_ctrl_reg_wr_wait),
    .reg_wr_ack(ptp_ctrl_reg_wr_ack),
    .reg_rd_addr(ctrl_reg_rd_addr),
    .reg_rd_en(ctrl_reg_rd_en && (ctrl_reg_wr_addr >> 8 == 2)),
    .reg_rd_data(ptp_ctrl_reg_rd_data),
    .reg_rd_wait(ptp_ctrl_reg_rd_wait),
    .reg_rd_ack(ptp_ctrl_reg_rd_ack),

    /*
     * PTP clock
     */
    .ptp_pps(ptp_pps),
    .ptp_ts_96(ptp_ts_96),
    .ptp_ts_step(ptp_ts_step),
    .ptp_perout_locked(ptp_perout_locked),
    .ptp_perout_error(ptp_perout_error),
    .ptp_perout_pulse(ptp_perout_pulse)
);

wire [IF_COUNT*AXIL_ADDR_WIDTH-1:0] axil_if_awaddr;
wire [IF_COUNT*3-1:0]               axil_if_awprot;
wire [IF_COUNT-1:0]                 axil_if_awvalid;
wire [IF_COUNT-1:0]                 axil_if_awready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0] axil_if_wdata;
wire [IF_COUNT*AXIL_STRB_WIDTH-1:0] axil_if_wstrb;
wire [IF_COUNT-1:0]                 axil_if_wvalid;
wire [IF_COUNT-1:0]                 axil_if_wready;
wire [IF_COUNT*2-1:0]               axil_if_bresp;
wire [IF_COUNT-1:0]                 axil_if_bvalid;
wire [IF_COUNT-1:0]                 axil_if_bready;
wire [IF_COUNT*AXIL_ADDR_WIDTH-1:0] axil_if_araddr;
wire [IF_COUNT*3-1:0]               axil_if_arprot;
wire [IF_COUNT-1:0]                 axil_if_arvalid;
wire [IF_COUNT-1:0]                 axil_if_arready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0] axil_if_rdata;
wire [IF_COUNT*2-1:0]               axil_if_rresp;
wire [IF_COUNT-1:0]                 axil_if_rvalid;
wire [IF_COUNT-1:0]                 axil_if_rready;

wire [IF_COUNT*AXIL_CSR_ADDR_WIDTH-1:0] axil_if_csr_awaddr;
wire [IF_COUNT*3-1:0]                   axil_if_csr_awprot;
wire [IF_COUNT-1:0]                     axil_if_csr_awvalid;
wire [IF_COUNT-1:0]                     axil_if_csr_awready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0]     axil_if_csr_wdata;
wire [IF_COUNT*AXIL_STRB_WIDTH-1:0]     axil_if_csr_wstrb;
wire [IF_COUNT-1:0]                     axil_if_csr_wvalid;
wire [IF_COUNT-1:0]                     axil_if_csr_wready;
wire [IF_COUNT*2-1:0]                   axil_if_csr_bresp;
wire [IF_COUNT-1:0]                     axil_if_csr_bvalid;
wire [IF_COUNT-1:0]                     axil_if_csr_bready;
wire [IF_COUNT*AXIL_CSR_ADDR_WIDTH-1:0] axil_if_csr_araddr;
wire [IF_COUNT*3-1:0]                   axil_if_csr_arprot;
wire [IF_COUNT-1:0]                     axil_if_csr_arvalid;
wire [IF_COUNT-1:0]                     axil_if_csr_arready;
wire [IF_COUNT*AXIL_DATA_WIDTH-1:0]     axil_if_csr_rdata;
wire [IF_COUNT*2-1:0]                   axil_if_csr_rresp;
wire [IF_COUNT-1:0]                     axil_if_csr_rvalid;
wire [IF_COUNT-1:0]                     axil_if_csr_rready;

axil_crossbar #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .S_COUNT(1),
    .M_COUNT(IF_COUNT),
    .M_BASE_ADDR(0),
    .M_ADDR_WIDTH({IF_COUNT{w_32(IF_AXIL_ADDR_WIDTH)}}),
    .M_CONNECT_READ({IF_COUNT{1'b1}}),
    .M_CONNECT_WRITE({IF_COUNT{1'b1}})
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
    .m_axil_awaddr(axil_if_awaddr),
    .m_axil_awprot(axil_if_awprot),
    .m_axil_awvalid(axil_if_awvalid),
    .m_axil_awready(axil_if_awready),
    .m_axil_wdata(axil_if_wdata),
    .m_axil_wstrb(axil_if_wstrb),
    .m_axil_wvalid(axil_if_wvalid),
    .m_axil_wready(axil_if_wready),
    .m_axil_bresp(axil_if_bresp),
    .m_axil_bvalid(axil_if_bvalid),
    .m_axil_bready(axil_if_bready),
    .m_axil_araddr(axil_if_araddr),
    .m_axil_arprot(axil_if_arprot),
    .m_axil_arvalid(axil_if_arvalid),
    .m_axil_arready(axil_if_arready),
    .m_axil_rdata(axil_if_rdata),
    .m_axil_rresp(axil_if_rresp),
    .m_axil_rvalid(axil_if_rvalid),
    .m_axil_rready(axil_if_rready)
);

axil_crossbar #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),
    .S_COUNT(IF_COUNT),
    .M_COUNT((AXIL_CSR_PASSTHROUGH_ENABLE ? 1 : 0) + 1),
    .M_BASE_ADDR(0),
    .M_ADDR_WIDTH({w_32(AXIL_CSR_ADDR_WIDTH-1), 32'd16}),
    .M_CONNECT_READ({2{{IF_COUNT{1'b1}}}}),
    .M_CONNECT_WRITE({2{{IF_COUNT{1'b1}}}})
)
axil_csr_crossbar_inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(axil_if_csr_awaddr),
    .s_axil_awprot(axil_if_csr_awprot),
    .s_axil_awvalid(axil_if_csr_awvalid),
    .s_axil_awready(axil_if_csr_awready),
    .s_axil_wdata(axil_if_csr_wdata),
    .s_axil_wstrb(axil_if_csr_wstrb),
    .s_axil_wvalid(axil_if_csr_wvalid),
    .s_axil_wready(axil_if_csr_wready),
    .s_axil_bresp(axil_if_csr_bresp),
    .s_axil_bvalid(axil_if_csr_bvalid),
    .s_axil_bready(axil_if_csr_bready),
    .s_axil_araddr(axil_if_csr_araddr),
    .s_axil_arprot(axil_if_csr_arprot),
    .s_axil_arvalid(axil_if_csr_arvalid),
    .s_axil_arready(axil_if_csr_arready),
    .s_axil_rdata(axil_if_csr_rdata),
    .s_axil_rresp(axil_if_csr_rresp),
    .s_axil_rvalid(axil_if_csr_rvalid),
    .s_axil_rready(axil_if_csr_rready),
    .m_axil_awaddr( {m_axil_csr_awaddr,  axil_csr_awaddr}),
    .m_axil_awprot( {m_axil_csr_awprot,  axil_csr_awprot}),
    .m_axil_awvalid({m_axil_csr_awvalid, axil_csr_awvalid}),
    .m_axil_awready({m_axil_csr_awready, axil_csr_awready}),
    .m_axil_wdata(  {m_axil_csr_wdata,   axil_csr_wdata}),
    .m_axil_wstrb(  {m_axil_csr_wstrb,   axil_csr_wstrb}),
    .m_axil_wvalid( {m_axil_csr_wvalid,  axil_csr_wvalid}),
    .m_axil_wready( {m_axil_csr_wready,  axil_csr_wready}),
    .m_axil_bresp(  {m_axil_csr_bresp,   axil_csr_bresp}),
    .m_axil_bvalid( {m_axil_csr_bvalid,  axil_csr_bvalid}),
    .m_axil_bready( {m_axil_csr_bready,  axil_csr_bready}),
    .m_axil_araddr( {m_axil_csr_araddr,  axil_csr_araddr}),
    .m_axil_arprot( {m_axil_csr_arprot,  axil_csr_arprot}),
    .m_axil_arvalid({m_axil_csr_arvalid, axil_csr_arvalid}),
    .m_axil_arready({m_axil_csr_arready, axil_csr_arready}),
    .m_axil_rdata(  {m_axil_csr_rdata,   axil_csr_rdata}),
    .m_axil_rresp(  {m_axil_csr_rresp,   axil_csr_rresp}),
    .m_axil_rvalid( {m_axil_csr_rvalid,  axil_csr_rvalid}),
    .m_axil_rready( {m_axil_csr_rready,  axil_csr_rready})
);

wire [DMA_ADDR_WIDTH-1:0]  ctrl_dma_read_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   ctrl_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  ctrl_dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   ctrl_dma_read_desc_len;
wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_read_desc_tag;
wire                       ctrl_dma_read_desc_valid;
wire                       ctrl_dma_read_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_read_desc_status_tag;
wire [3:0]                 ctrl_dma_read_desc_status_error;
wire                       ctrl_dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  ctrl_dma_write_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   ctrl_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  ctrl_dma_write_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   ctrl_dma_write_desc_len;
wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_write_desc_tag;
wire                       ctrl_dma_write_desc_valid;
wire                       ctrl_dma_write_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   ctrl_dma_write_desc_status_tag;
wire [3:0]                 ctrl_dma_write_desc_status_error;
wire                       ctrl_dma_write_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  data_dma_read_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   data_dma_read_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  data_dma_read_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   data_dma_read_desc_len;
wire [DMA_TAG_WIDTH-2:0]   data_dma_read_desc_tag;
wire                       data_dma_read_desc_valid;
wire                       data_dma_read_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   data_dma_read_desc_status_tag;
wire [3:0]                 data_dma_read_desc_status_error;
wire                       data_dma_read_desc_status_valid;

wire [DMA_ADDR_WIDTH-1:0]  data_dma_write_desc_dma_addr;
wire [RAM_SEL_WIDTH-2:0]   data_dma_write_desc_ram_sel;
wire [RAM_ADDR_WIDTH-1:0]  data_dma_write_desc_ram_addr;
wire [DMA_LEN_WIDTH-1:0]   data_dma_write_desc_len;
wire [DMA_TAG_WIDTH-2:0]   data_dma_write_desc_tag;
wire                       data_dma_write_desc_valid;
wire                       data_dma_write_desc_ready;

wire [DMA_TAG_WIDTH-2:0]   data_dma_write_desc_status_tag;
wire [3:0]                 data_dma_write_desc_status_error;
wire                       data_dma_write_desc_status_valid;

wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   ctrl_dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    ctrl_dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ctrl_dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ctrl_dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_wr_done;
wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   ctrl_dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ctrl_dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ctrl_dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     ctrl_dma_ram_rd_resp_ready;

wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   data_dma_ram_wr_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    data_dma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  data_dma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  data_dma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_wr_done;
wire [RAM_SEG_COUNT*(RAM_SEL_WIDTH-1)-1:0]   data_dma_ram_rd_cmd_sel;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  data_dma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  data_dma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                     data_dma_ram_rd_resp_ready;

dma_if_mux #(
    .PORTS(2),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .S_RAM_SEL_WIDTH(RAM_SEL_WIDTH-1),
    .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .S_TAG_WIDTH(DMA_TAG_WIDTH-1),
    .M_TAG_WIDTH(DMA_TAG_WIDTH),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(1)
)
dma_if_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Read descriptor output (to DMA interface)
     */
    .m_axis_read_desc_dma_addr(m_axis_dma_read_desc_dma_addr),
    .m_axis_read_desc_ram_sel(m_axis_dma_read_desc_ram_sel),
    .m_axis_read_desc_ram_addr(m_axis_dma_read_desc_ram_addr),
    .m_axis_read_desc_len(m_axis_dma_read_desc_len),
    .m_axis_read_desc_tag(m_axis_dma_read_desc_tag),
    .m_axis_read_desc_valid(m_axis_dma_read_desc_valid),
    .m_axis_read_desc_ready(m_axis_dma_read_desc_ready),

    /*
     * Read descriptor status input (from DMA interface)
     */
    .s_axis_read_desc_status_tag(s_axis_dma_read_desc_status_tag),
    .s_axis_read_desc_status_error(s_axis_dma_read_desc_status_error),
    .s_axis_read_desc_status_valid(s_axis_dma_read_desc_status_valid),

    /*
     * Read descriptor input
     */
    .s_axis_read_desc_dma_addr({data_dma_read_desc_dma_addr, ctrl_dma_read_desc_dma_addr}),
    .s_axis_read_desc_ram_sel({data_dma_read_desc_ram_sel, ctrl_dma_read_desc_ram_sel}),
    .s_axis_read_desc_ram_addr({data_dma_read_desc_ram_addr, ctrl_dma_read_desc_ram_addr}),
    .s_axis_read_desc_len({data_dma_read_desc_len, ctrl_dma_read_desc_len}),
    .s_axis_read_desc_tag({data_dma_read_desc_tag, ctrl_dma_read_desc_tag}),
    .s_axis_read_desc_valid({data_dma_read_desc_valid, ctrl_dma_read_desc_valid}),
    .s_axis_read_desc_ready({data_dma_read_desc_ready, ctrl_dma_read_desc_ready}),

    /*
     * Read descriptor status output
     */
    .m_axis_read_desc_status_tag({data_dma_read_desc_status_tag, ctrl_dma_read_desc_status_tag}),
    .m_axis_read_desc_status_error({data_dma_read_desc_status_error, ctrl_dma_read_desc_status_error}),
    .m_axis_read_desc_status_valid({data_dma_read_desc_status_valid, ctrl_dma_read_desc_status_valid}),

    /*
     * Write descriptor output (to DMA interface)
     */
    .m_axis_write_desc_dma_addr(m_axis_dma_write_desc_dma_addr),
    .m_axis_write_desc_ram_sel(m_axis_dma_write_desc_ram_sel),
    .m_axis_write_desc_ram_addr(m_axis_dma_write_desc_ram_addr),
    .m_axis_write_desc_len(m_axis_dma_write_desc_len),
    .m_axis_write_desc_tag(m_axis_dma_write_desc_tag),
    .m_axis_write_desc_valid(m_axis_dma_write_desc_valid),
    .m_axis_write_desc_ready(m_axis_dma_write_desc_ready),

    /*
     * Write descriptor status input (from DMA interface)
     */
    .s_axis_write_desc_status_tag(s_axis_dma_write_desc_status_tag),
    .s_axis_write_desc_status_error(s_axis_dma_write_desc_status_error),
    .s_axis_write_desc_status_valid(s_axis_dma_write_desc_status_valid),

    /*
     * Write descriptor input
     */
    .s_axis_write_desc_dma_addr({data_dma_write_desc_dma_addr, ctrl_dma_write_desc_dma_addr}),
    .s_axis_write_desc_ram_sel({data_dma_write_desc_ram_sel, ctrl_dma_write_desc_ram_sel}),
    .s_axis_write_desc_ram_addr({data_dma_write_desc_ram_addr, ctrl_dma_write_desc_ram_addr}),
    .s_axis_write_desc_len({data_dma_write_desc_len, ctrl_dma_write_desc_len}),
    .s_axis_write_desc_tag({data_dma_write_desc_tag, ctrl_dma_write_desc_tag}),
    .s_axis_write_desc_valid({data_dma_write_desc_valid, ctrl_dma_write_desc_valid}),
    .s_axis_write_desc_ready({data_dma_write_desc_ready, ctrl_dma_write_desc_ready}),

    /*
     * Write descriptor status output
     */
    .m_axis_write_desc_status_tag({data_dma_write_desc_status_tag, ctrl_dma_write_desc_status_tag}),
    .m_axis_write_desc_status_error({data_dma_write_desc_status_error, ctrl_dma_write_desc_status_error}),
    .m_axis_write_desc_status_valid({data_dma_write_desc_status_valid, ctrl_dma_write_desc_status_valid}),

    /*
     * RAM interface (from DMA interface)
     */
    .if_ram_wr_cmd_sel(dma_ram_wr_cmd_sel),
    .if_ram_wr_cmd_be(dma_ram_wr_cmd_be),
    .if_ram_wr_cmd_addr(dma_ram_wr_cmd_addr),
    .if_ram_wr_cmd_data(dma_ram_wr_cmd_data),
    .if_ram_wr_cmd_valid(dma_ram_wr_cmd_valid),
    .if_ram_wr_cmd_ready(dma_ram_wr_cmd_ready),
    .if_ram_wr_done(dma_ram_wr_done),
    .if_ram_rd_cmd_sel(dma_ram_rd_cmd_sel),
    .if_ram_rd_cmd_addr(dma_ram_rd_cmd_addr),
    .if_ram_rd_cmd_valid(dma_ram_rd_cmd_valid),
    .if_ram_rd_cmd_ready(dma_ram_rd_cmd_ready),
    .if_ram_rd_resp_data(dma_ram_rd_resp_data),
    .if_ram_rd_resp_valid(dma_ram_rd_resp_valid),
    .if_ram_rd_resp_ready(dma_ram_rd_resp_ready),

    /*
     * RAM interface
     */
    .ram_wr_cmd_sel({data_dma_ram_wr_cmd_sel, ctrl_dma_ram_wr_cmd_sel}),
    .ram_wr_cmd_be({data_dma_ram_wr_cmd_be, ctrl_dma_ram_wr_cmd_be}),
    .ram_wr_cmd_addr({data_dma_ram_wr_cmd_addr, ctrl_dma_ram_wr_cmd_addr}),
    .ram_wr_cmd_data({data_dma_ram_wr_cmd_data, ctrl_dma_ram_wr_cmd_data}),
    .ram_wr_cmd_valid({data_dma_ram_wr_cmd_valid, ctrl_dma_ram_wr_cmd_valid}),
    .ram_wr_cmd_ready({data_dma_ram_wr_cmd_ready, ctrl_dma_ram_wr_cmd_ready}),
    .ram_wr_done({data_dma_ram_wr_done, ctrl_dma_ram_wr_done}),
    .ram_rd_cmd_sel({data_dma_ram_rd_cmd_sel, ctrl_dma_ram_rd_cmd_sel}),
    .ram_rd_cmd_addr({data_dma_ram_rd_cmd_addr, ctrl_dma_ram_rd_cmd_addr}),
    .ram_rd_cmd_valid({data_dma_ram_rd_cmd_valid, ctrl_dma_ram_rd_cmd_valid}),
    .ram_rd_cmd_ready({data_dma_ram_rd_cmd_ready, ctrl_dma_ram_rd_cmd_ready}),
    .ram_rd_resp_data({data_dma_ram_rd_resp_data, ctrl_dma_ram_rd_resp_data}),
    .ram_rd_resp_valid({data_dma_ram_rd_resp_valid, ctrl_dma_ram_rd_resp_valid}),
    .ram_rd_resp_ready({data_dma_ram_rd_resp_ready, ctrl_dma_ram_rd_resp_ready})
);

wire [IF_COUNT*DMA_ADDR_WIDTH-1:0]    if_ctrl_dma_read_desc_dma_addr;
wire [IF_COUNT*IF_RAM_SEL_WIDTH-1:0]  if_ctrl_dma_read_desc_ram_sel;
wire [IF_COUNT*RAM_ADDR_WIDTH-1:0]    if_ctrl_dma_read_desc_ram_addr;
wire [IF_COUNT*DMA_LEN_WIDTH-1:0]     if_ctrl_dma_read_desc_len;
wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_read_desc_tag;
wire [IF_COUNT-1:0]                   if_ctrl_dma_read_desc_valid;
wire [IF_COUNT-1:0]                   if_ctrl_dma_read_desc_ready;

wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_read_desc_status_tag;
wire [IF_COUNT*4-1:0]                 if_ctrl_dma_read_desc_status_error;
wire [IF_COUNT-1:0]                   if_ctrl_dma_read_desc_status_valid;

wire [IF_COUNT*DMA_ADDR_WIDTH-1:0]    if_ctrl_dma_write_desc_dma_addr;
wire [IF_COUNT*IF_RAM_SEL_WIDTH-1:0]  if_ctrl_dma_write_desc_ram_sel;
wire [IF_COUNT*RAM_ADDR_WIDTH-1:0]    if_ctrl_dma_write_desc_ram_addr;
wire [IF_COUNT*DMA_LEN_WIDTH-1:0]     if_ctrl_dma_write_desc_len;
wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_write_desc_tag;
wire [IF_COUNT-1:0]                   if_ctrl_dma_write_desc_valid;
wire [IF_COUNT-1:0]                   if_ctrl_dma_write_desc_ready;

wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_ctrl_dma_write_desc_status_tag;
wire [IF_COUNT*4-1:0]                 if_ctrl_dma_write_desc_status_error;
wire [IF_COUNT-1:0]                   if_ctrl_dma_write_desc_status_valid;

wire [IF_COUNT*DMA_ADDR_WIDTH-1:0]    if_data_dma_read_desc_dma_addr;
wire [IF_COUNT*IF_RAM_SEL_WIDTH-1:0]  if_data_dma_read_desc_ram_sel;
wire [IF_COUNT*RAM_ADDR_WIDTH-1:0]    if_data_dma_read_desc_ram_addr;
wire [IF_COUNT*DMA_LEN_WIDTH-1:0]     if_data_dma_read_desc_len;
wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_read_desc_tag;
wire [IF_COUNT-1:0]                   if_data_dma_read_desc_valid;
wire [IF_COUNT-1:0]                   if_data_dma_read_desc_ready;

wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_read_desc_status_tag;
wire [IF_COUNT*4-1:0]                 if_data_dma_read_desc_status_error;
wire [IF_COUNT-1:0]                   if_data_dma_read_desc_status_valid;

wire [IF_COUNT*DMA_ADDR_WIDTH-1:0]    if_data_dma_write_desc_dma_addr;
wire [IF_COUNT*IF_RAM_SEL_WIDTH-1:0]  if_data_dma_write_desc_ram_sel;
wire [IF_COUNT*RAM_ADDR_WIDTH-1:0]    if_data_dma_write_desc_ram_addr;
wire [IF_COUNT*DMA_LEN_WIDTH-1:0]     if_data_dma_write_desc_len;
wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_write_desc_tag;
wire [IF_COUNT-1:0]                   if_data_dma_write_desc_valid;
wire [IF_COUNT-1:0]                   if_data_dma_write_desc_ready;

wire [IF_COUNT*IF_DMA_TAG_WIDTH-1:0]  if_data_dma_write_desc_status_tag;
wire [IF_COUNT*4-1:0]                 if_data_dma_write_desc_status_error;
wire [IF_COUNT-1:0]                   if_data_dma_write_desc_status_valid;

wire [IF_COUNT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_ctrl_dma_ram_wr_cmd_sel;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    if_ctrl_dma_ram_wr_cmd_be;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_ctrl_dma_ram_wr_cmd_addr;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_ctrl_dma_ram_wr_cmd_data;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_wr_cmd_valid;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_wr_cmd_ready;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_wr_done;
wire [IF_COUNT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_ctrl_dma_ram_rd_cmd_sel;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_ctrl_dma_ram_rd_cmd_addr;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_cmd_valid;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_cmd_ready;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_ctrl_dma_ram_rd_resp_data;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_resp_valid;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_ctrl_dma_ram_rd_resp_ready;

wire [IF_COUNT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_data_dma_ram_wr_cmd_sel;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]    if_data_dma_ram_wr_cmd_be;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_data_dma_ram_wr_cmd_addr;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_data_dma_ram_wr_cmd_data;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_wr_cmd_valid;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_wr_cmd_ready;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_wr_done;
wire [IF_COUNT*RAM_SEG_COUNT*IF_RAM_SEL_WIDTH-1:0]    if_data_dma_ram_rd_cmd_sel;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  if_data_dma_ram_rd_cmd_addr;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_cmd_valid;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_cmd_ready;
wire [IF_COUNT*RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  if_data_dma_ram_rd_resp_data;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_resp_valid;
wire [IF_COUNT*RAM_SEG_COUNT-1:0]                     if_data_dma_ram_rd_resp_ready;

generate

if (IF_COUNT > 1) begin : dma_if_mux

    dma_if_mux #(
        .PORTS(IF_COUNT),
        .SEG_COUNT(RAM_SEG_COUNT),
        .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
        .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
        .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
        .S_RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
        .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH-1),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
        .LEN_WIDTH(DMA_LEN_WIDTH),
        .S_TAG_WIDTH(IF_DMA_TAG_WIDTH),
        .M_TAG_WIDTH(DMA_TAG_WIDTH-1),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    dma_if_mux_ctrl_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Read descriptor output (to DMA interface)
         */
        .m_axis_read_desc_dma_addr(ctrl_dma_read_desc_dma_addr),
        .m_axis_read_desc_ram_sel(ctrl_dma_read_desc_ram_sel),
        .m_axis_read_desc_ram_addr(ctrl_dma_read_desc_ram_addr),
        .m_axis_read_desc_len(ctrl_dma_read_desc_len),
        .m_axis_read_desc_tag(ctrl_dma_read_desc_tag),
        .m_axis_read_desc_valid(ctrl_dma_read_desc_valid),
        .m_axis_read_desc_ready(ctrl_dma_read_desc_ready),

        /*
         * Read descriptor status input (from DMA interface)
         */
        .s_axis_read_desc_status_tag(ctrl_dma_read_desc_status_tag),
        .s_axis_read_desc_status_error(ctrl_dma_read_desc_status_error),
        .s_axis_read_desc_status_valid(ctrl_dma_read_desc_status_valid),

        /*
         * Read descriptor input
         */
        .s_axis_read_desc_dma_addr(if_ctrl_dma_read_desc_dma_addr),
        .s_axis_read_desc_ram_sel(if_ctrl_dma_read_desc_ram_sel),
        .s_axis_read_desc_ram_addr(if_ctrl_dma_read_desc_ram_addr),
        .s_axis_read_desc_len(if_ctrl_dma_read_desc_len),
        .s_axis_read_desc_tag(if_ctrl_dma_read_desc_tag),
        .s_axis_read_desc_valid(if_ctrl_dma_read_desc_valid),
        .s_axis_read_desc_ready(if_ctrl_dma_read_desc_ready),

        /*
         * Read descriptor status output
         */
        .m_axis_read_desc_status_tag(if_ctrl_dma_read_desc_status_tag),
        .m_axis_read_desc_status_error(if_ctrl_dma_read_desc_status_error),
        .m_axis_read_desc_status_valid(if_ctrl_dma_read_desc_status_valid),

        /*
         * Write descriptor output (to DMA interface)
         */
        .m_axis_write_desc_dma_addr(ctrl_dma_write_desc_dma_addr),
        .m_axis_write_desc_ram_sel(ctrl_dma_write_desc_ram_sel),
        .m_axis_write_desc_ram_addr(ctrl_dma_write_desc_ram_addr),
        .m_axis_write_desc_len(ctrl_dma_write_desc_len),
        .m_axis_write_desc_tag(ctrl_dma_write_desc_tag),
        .m_axis_write_desc_valid(ctrl_dma_write_desc_valid),
        .m_axis_write_desc_ready(ctrl_dma_write_desc_ready),

        /*
         * Write descriptor status input (from DMA interface)
         */
        .s_axis_write_desc_status_tag(ctrl_dma_write_desc_status_tag),
        .s_axis_write_desc_status_error(ctrl_dma_write_desc_status_error),
        .s_axis_write_desc_status_valid(ctrl_dma_write_desc_status_valid),

        /*
         * Write descriptor input
         */
        .s_axis_write_desc_dma_addr(if_ctrl_dma_write_desc_dma_addr),
        .s_axis_write_desc_ram_sel(if_ctrl_dma_write_desc_ram_sel),
        .s_axis_write_desc_ram_addr(if_ctrl_dma_write_desc_ram_addr),
        .s_axis_write_desc_len(if_ctrl_dma_write_desc_len),
        .s_axis_write_desc_tag(if_ctrl_dma_write_desc_tag),
        .s_axis_write_desc_valid(if_ctrl_dma_write_desc_valid),
        .s_axis_write_desc_ready(if_ctrl_dma_write_desc_ready),

        /*
         * Write descriptor status output
         */
        .m_axis_write_desc_status_tag(if_ctrl_dma_write_desc_status_tag),
        .m_axis_write_desc_status_error(if_ctrl_dma_write_desc_status_error),
        .m_axis_write_desc_status_valid(if_ctrl_dma_write_desc_status_valid),

        /*
         * RAM interface (from DMA interface)
         */
        .if_ram_wr_cmd_sel(ctrl_dma_ram_wr_cmd_sel),
        .if_ram_wr_cmd_be(ctrl_dma_ram_wr_cmd_be),
        .if_ram_wr_cmd_addr(ctrl_dma_ram_wr_cmd_addr),
        .if_ram_wr_cmd_data(ctrl_dma_ram_wr_cmd_data),
        .if_ram_wr_cmd_valid(ctrl_dma_ram_wr_cmd_valid),
        .if_ram_wr_cmd_ready(ctrl_dma_ram_wr_cmd_ready),
        .if_ram_wr_done(ctrl_dma_ram_wr_done),
        .if_ram_rd_cmd_sel(ctrl_dma_ram_rd_cmd_sel),
        .if_ram_rd_cmd_addr(ctrl_dma_ram_rd_cmd_addr),
        .if_ram_rd_cmd_valid(ctrl_dma_ram_rd_cmd_valid),
        .if_ram_rd_cmd_ready(ctrl_dma_ram_rd_cmd_ready),
        .if_ram_rd_resp_data(ctrl_dma_ram_rd_resp_data),
        .if_ram_rd_resp_valid(ctrl_dma_ram_rd_resp_valid),
        .if_ram_rd_resp_ready(ctrl_dma_ram_rd_resp_ready),

        /*
         * RAM interface
         */
        .ram_wr_cmd_sel(if_ctrl_dma_ram_wr_cmd_sel),
        .ram_wr_cmd_be(if_ctrl_dma_ram_wr_cmd_be),
        .ram_wr_cmd_addr(if_ctrl_dma_ram_wr_cmd_addr),
        .ram_wr_cmd_data(if_ctrl_dma_ram_wr_cmd_data),
        .ram_wr_cmd_valid(if_ctrl_dma_ram_wr_cmd_valid),
        .ram_wr_cmd_ready(if_ctrl_dma_ram_wr_cmd_ready),
        .ram_wr_done(if_ctrl_dma_ram_wr_done),
        .ram_rd_cmd_sel(if_ctrl_dma_ram_rd_cmd_sel),
        .ram_rd_cmd_addr(if_ctrl_dma_ram_rd_cmd_addr),
        .ram_rd_cmd_valid(if_ctrl_dma_ram_rd_cmd_valid),
        .ram_rd_cmd_ready(if_ctrl_dma_ram_rd_cmd_ready),
        .ram_rd_resp_data(if_ctrl_dma_ram_rd_resp_data),
        .ram_rd_resp_valid(if_ctrl_dma_ram_rd_resp_valid),
        .ram_rd_resp_ready(if_ctrl_dma_ram_rd_resp_ready)
    );

    dma_if_mux #(
        .PORTS(IF_COUNT),
        .SEG_COUNT(RAM_SEG_COUNT),
        .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
        .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
        .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
        .S_RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
        .M_RAM_SEL_WIDTH(RAM_SEL_WIDTH-1),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
        .LEN_WIDTH(DMA_LEN_WIDTH),
        .S_TAG_WIDTH(IF_DMA_TAG_WIDTH),
        .M_TAG_WIDTH(DMA_TAG_WIDTH-1),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_LSB_HIGH_PRIORITY(1)
    )
    dma_if_mux_data_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Read descriptor output (to DMA interface)
         */
        .m_axis_read_desc_dma_addr(data_dma_read_desc_dma_addr),
        .m_axis_read_desc_ram_sel(data_dma_read_desc_ram_sel),
        .m_axis_read_desc_ram_addr(data_dma_read_desc_ram_addr),
        .m_axis_read_desc_len(data_dma_read_desc_len),
        .m_axis_read_desc_tag(data_dma_read_desc_tag),
        .m_axis_read_desc_valid(data_dma_read_desc_valid),
        .m_axis_read_desc_ready(data_dma_read_desc_ready),

        /*
         * Read descriptor status input (from DMA interface)
         */
        .s_axis_read_desc_status_tag(data_dma_read_desc_status_tag),
        .s_axis_read_desc_status_error(data_dma_read_desc_status_error),
        .s_axis_read_desc_status_valid(data_dma_read_desc_status_valid),

        /*
         * Read descriptor input
         */
        .s_axis_read_desc_dma_addr(if_data_dma_read_desc_dma_addr),
        .s_axis_read_desc_ram_sel(if_data_dma_read_desc_ram_sel),
        .s_axis_read_desc_ram_addr(if_data_dma_read_desc_ram_addr),
        .s_axis_read_desc_len(if_data_dma_read_desc_len),
        .s_axis_read_desc_tag(if_data_dma_read_desc_tag),
        .s_axis_read_desc_valid(if_data_dma_read_desc_valid),
        .s_axis_read_desc_ready(if_data_dma_read_desc_ready),

        /*
         * Read descriptor status output
         */
        .m_axis_read_desc_status_tag(if_data_dma_read_desc_status_tag),
        .m_axis_read_desc_status_error(if_data_dma_read_desc_status_error),
        .m_axis_read_desc_status_valid(if_data_dma_read_desc_status_valid),

        /*
         * Write descriptor output (to DMA interface)
         */
        .m_axis_write_desc_dma_addr(data_dma_write_desc_dma_addr),
        .m_axis_write_desc_ram_sel(data_dma_write_desc_ram_sel),
        .m_axis_write_desc_ram_addr(data_dma_write_desc_ram_addr),
        .m_axis_write_desc_len(data_dma_write_desc_len),
        .m_axis_write_desc_tag(data_dma_write_desc_tag),
        .m_axis_write_desc_valid(data_dma_write_desc_valid),
        .m_axis_write_desc_ready(data_dma_write_desc_ready),

        /*
         * Write descriptor status input (from DMA interface)
         */
        .s_axis_write_desc_status_tag(data_dma_write_desc_status_tag),
        .s_axis_write_desc_status_error(data_dma_write_desc_status_error),
        .s_axis_write_desc_status_valid(data_dma_write_desc_status_valid),

        /*
         * Write descriptor input
         */
        .s_axis_write_desc_dma_addr(if_data_dma_write_desc_dma_addr),
        .s_axis_write_desc_ram_sel(if_data_dma_write_desc_ram_sel),
        .s_axis_write_desc_ram_addr(if_data_dma_write_desc_ram_addr),
        .s_axis_write_desc_len(if_data_dma_write_desc_len),
        .s_axis_write_desc_tag(if_data_dma_write_desc_tag),
        .s_axis_write_desc_valid(if_data_dma_write_desc_valid),
        .s_axis_write_desc_ready(if_data_dma_write_desc_ready),

        /*
         * Write descriptor status output
         */
        .m_axis_write_desc_status_tag(if_data_dma_write_desc_status_tag),
        .m_axis_write_desc_status_error(if_data_dma_write_desc_status_error),
        .m_axis_write_desc_status_valid(if_data_dma_write_desc_status_valid),

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
        .ram_wr_cmd_sel(if_data_dma_ram_wr_cmd_sel),
        .ram_wr_cmd_be(if_data_dma_ram_wr_cmd_be),
        .ram_wr_cmd_addr(if_data_dma_ram_wr_cmd_addr),
        .ram_wr_cmd_data(if_data_dma_ram_wr_cmd_data),
        .ram_wr_cmd_valid(if_data_dma_ram_wr_cmd_valid),
        .ram_wr_cmd_ready(if_data_dma_ram_wr_cmd_ready),
        .ram_wr_done(if_data_dma_ram_wr_done),
        .ram_rd_cmd_sel(if_data_dma_ram_rd_cmd_sel),
        .ram_rd_cmd_addr(if_data_dma_ram_rd_cmd_addr),
        .ram_rd_cmd_valid(if_data_dma_ram_rd_cmd_valid),
        .ram_rd_cmd_ready(if_data_dma_ram_rd_cmd_ready),
        .ram_rd_resp_data(if_data_dma_ram_rd_resp_data),
        .ram_rd_resp_valid(if_data_dma_ram_rd_resp_valid),
        .ram_rd_resp_ready(if_data_dma_ram_rd_resp_ready)
    );

end else begin

    assign ctrl_dma_read_desc_dma_addr = if_ctrl_dma_read_desc_dma_addr;
    assign ctrl_dma_read_desc_ram_sel = if_ctrl_dma_read_desc_ram_sel;
    assign ctrl_dma_read_desc_ram_addr = if_ctrl_dma_read_desc_ram_addr;
    assign ctrl_dma_read_desc_len = if_ctrl_dma_read_desc_len;
    assign ctrl_dma_read_desc_tag = if_ctrl_dma_read_desc_tag;
    assign ctrl_dma_read_desc_valid = if_ctrl_dma_read_desc_valid;
    assign if_ctrl_dma_read_desc_ready = ctrl_dma_read_desc_ready;

    assign if_ctrl_dma_read_desc_status_tag = ctrl_dma_read_desc_status_tag;
    assign if_ctrl_dma_read_desc_status_error = ctrl_dma_read_desc_status_error;
    assign if_ctrl_dma_read_desc_status_valid = ctrl_dma_read_desc_status_valid;

    assign ctrl_dma_write_desc_dma_addr = if_ctrl_dma_write_desc_dma_addr;
    assign ctrl_dma_write_desc_ram_sel = if_ctrl_dma_write_desc_ram_sel;
    assign ctrl_dma_write_desc_ram_addr = if_ctrl_dma_write_desc_ram_addr;
    assign ctrl_dma_write_desc_len = if_ctrl_dma_write_desc_len;
    assign ctrl_dma_write_desc_tag = if_ctrl_dma_write_desc_tag;
    assign ctrl_dma_write_desc_valid = if_ctrl_dma_write_desc_valid;
    assign if_ctrl_dma_write_desc_ready = ctrl_dma_write_desc_ready;

    assign if_ctrl_dma_write_desc_status_tag = ctrl_dma_write_desc_status_tag;
    assign if_ctrl_dma_write_desc_status_error = ctrl_dma_write_desc_status_error;
    assign if_ctrl_dma_write_desc_status_valid = ctrl_dma_write_desc_status_valid;

    assign if_ctrl_dma_ram_wr_cmd_sel = ctrl_dma_ram_wr_cmd_sel;
    assign if_ctrl_dma_ram_wr_cmd_be = ctrl_dma_ram_wr_cmd_be;
    assign if_ctrl_dma_ram_wr_cmd_addr = ctrl_dma_ram_wr_cmd_addr;
    assign if_ctrl_dma_ram_wr_cmd_data = ctrl_dma_ram_wr_cmd_data;
    assign if_ctrl_dma_ram_wr_cmd_valid = ctrl_dma_ram_wr_cmd_valid;
    assign ctrl_dma_ram_wr_cmd_ready = if_ctrl_dma_ram_wr_cmd_ready;
    assign ctrl_dma_ram_wr_done = if_ctrl_dma_ram_wr_done;
    assign if_ctrl_dma_ram_rd_cmd_sel = ctrl_dma_ram_rd_cmd_sel;
    assign if_ctrl_dma_ram_rd_cmd_addr = ctrl_dma_ram_rd_cmd_addr;
    assign if_ctrl_dma_ram_rd_cmd_valid = ctrl_dma_ram_rd_cmd_valid;
    assign ctrl_dma_ram_rd_cmd_ready = if_ctrl_dma_ram_rd_cmd_ready;
    assign ctrl_dma_ram_rd_resp_data = if_ctrl_dma_ram_rd_resp_data;
    assign ctrl_dma_ram_rd_resp_valid = if_ctrl_dma_ram_rd_resp_valid;
    assign if_ctrl_dma_ram_rd_resp_ready = ctrl_dma_ram_rd_resp_ready;

    assign data_dma_read_desc_dma_addr = if_data_dma_read_desc_dma_addr;
    assign data_dma_read_desc_ram_sel = if_data_dma_read_desc_ram_sel;
    assign data_dma_read_desc_ram_addr = if_data_dma_read_desc_ram_addr;
    assign data_dma_read_desc_len = if_data_dma_read_desc_len;
    assign data_dma_read_desc_tag = if_data_dma_read_desc_tag;
    assign data_dma_read_desc_valid = if_data_dma_read_desc_valid;
    assign if_data_dma_read_desc_ready = data_dma_read_desc_ready;

    assign if_data_dma_read_desc_status_tag = data_dma_read_desc_status_tag;
    assign if_data_dma_read_desc_status_error = data_dma_read_desc_status_error;
    assign if_data_dma_read_desc_status_valid = data_dma_read_desc_status_valid;

    assign data_dma_write_desc_dma_addr = if_data_dma_write_desc_dma_addr;
    assign data_dma_write_desc_ram_sel = if_data_dma_write_desc_ram_sel;
    assign data_dma_write_desc_ram_addr = if_data_dma_write_desc_ram_addr;
    assign data_dma_write_desc_len = if_data_dma_write_desc_len;
    assign data_dma_write_desc_tag = if_data_dma_write_desc_tag;
    assign data_dma_write_desc_valid = if_data_dma_write_desc_valid;
    assign if_data_dma_write_desc_ready = data_dma_write_desc_ready;

    assign if_data_dma_write_desc_status_tag = data_dma_write_desc_status_tag;
    assign if_data_dma_write_desc_status_error = data_dma_write_desc_status_error;
    assign if_data_dma_write_desc_status_valid = data_dma_write_desc_status_valid;

    assign if_data_dma_ram_wr_cmd_sel = data_dma_ram_wr_cmd_sel;
    assign if_data_dma_ram_wr_cmd_be = data_dma_ram_wr_cmd_be;
    assign if_data_dma_ram_wr_cmd_addr = data_dma_ram_wr_cmd_addr;
    assign if_data_dma_ram_wr_cmd_data = data_dma_ram_wr_cmd_data;
    assign if_data_dma_ram_wr_cmd_valid = data_dma_ram_wr_cmd_valid;
    assign data_dma_ram_wr_cmd_ready = if_data_dma_ram_wr_cmd_ready;
    assign data_dma_ram_wr_done = if_data_dma_ram_wr_done;
    assign if_data_dma_ram_rd_cmd_sel = data_dma_ram_rd_cmd_sel;
    assign if_data_dma_ram_rd_cmd_addr = data_dma_ram_rd_cmd_addr;
    assign if_data_dma_ram_rd_cmd_valid = data_dma_ram_rd_cmd_valid;
    assign data_dma_ram_rd_cmd_ready = if_data_dma_ram_rd_cmd_ready;
    assign data_dma_ram_rd_resp_data = if_data_dma_ram_rd_resp_data;
    assign data_dma_ram_rd_resp_valid = if_data_dma_ram_rd_resp_valid;
    assign if_data_dma_ram_rd_resp_ready = data_dma_ram_rd_resp_ready;

end

endgenerate

wire [MSI_COUNT-1:0] if_msi_irq[IF_COUNT-1:0];
reg [MSI_COUNT-1:0] msi_irq_cmb = 0;

assign msi_irq = msi_irq_cmb;

integer k;

always @* begin
    msi_irq_cmb = 0;
    for (k = 0; k < IF_COUNT; k = k + 1) begin
        msi_irq_cmb = msi_irq_cmb | if_msi_irq[k];
    end
end

generate
    genvar m, n;

    for (n = 0; n < IF_COUNT; n = n + 1) begin : iface

        wire [PORTS_PER_IF*AXIS_INT_DATA_WIDTH-1:0] if_tx_axis_tdata;
        wire [PORTS_PER_IF*AXIS_INT_KEEP_WIDTH-1:0] if_tx_axis_tkeep;
        wire [PORTS_PER_IF-1:0] if_tx_axis_tvalid;
        wire [PORTS_PER_IF-1:0] if_tx_axis_tready;
        wire [PORTS_PER_IF-1:0] if_tx_axis_tlast;
        // wire [PORTS_PER_IF*AXIS_TX_USER_WIDTH-1:0] if_tx_axis_tuser;
        wire [PORTS_PER_IF-1:0] if_tx_axis_tuser;

        wire [PORTS_PER_IF*PTP_TS_WIDTH-1:0] if_tx_ptp_ts_96;
        wire [PORTS_PER_IF*PTP_TAG_WIDTH-1:0] if_tx_ptp_ts_tag;
        wire [PORTS_PER_IF-1:0] if_tx_ptp_ts_valid;
        wire [PORTS_PER_IF-1:0] if_tx_ptp_ts_ready;

        wire [PORTS_PER_IF*AXIS_INT_DATA_WIDTH-1:0] if_rx_axis_tdata;
        wire [PORTS_PER_IF*AXIS_INT_KEEP_WIDTH-1:0] if_rx_axis_tkeep;
        wire [PORTS_PER_IF-1:0] if_rx_axis_tvalid;
        wire [PORTS_PER_IF-1:0] if_rx_axis_tready;
        wire [PORTS_PER_IF-1:0] if_rx_axis_tlast;
        // wire [PORTS_PER_IF*AXIS_RX_USER_WIDTH-1:0] if_rx_axis_tuser;
        wire [PORTS_PER_IF-1:0] if_rx_axis_tuser;
        wire [PORTS_PER_IF*AXIS_RX_USER_WIDTH-1:0] if_rx_axis_tuser_int;

        wire [PORTS_PER_IF*PTP_TS_WIDTH-1:0] if_rx_ptp_ts_96;
        wire [PORTS_PER_IF-1:0] if_rx_ptp_ts_valid;
        wire [PORTS_PER_IF-1:0] if_rx_ptp_ts_ready;

        mqnic_interface #(
            .PORTS(PORTS_PER_IF),
            .DMA_ADDR_WIDTH(DMA_ADDR_WIDTH),
            .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
            .DMA_TAG_WIDTH(IF_DMA_TAG_WIDTH),
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
            .TX_DESC_TABLE_SIZE(TX_DESC_TABLE_SIZE),
            .RX_DESC_TABLE_SIZE(RX_DESC_TABLE_SIZE),
            .TX_SCHEDULER_OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
            .TX_SCHEDULER_PIPELINE(TX_SCHEDULER_PIPELINE),
            .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),
            .INT_WIDTH(8),
            .QUEUE_PTR_WIDTH(16),
            .LOG_QUEUE_SIZE_WIDTH(4),
            .PTP_TS_ENABLE(PTP_TS_ENABLE),
            .PTP_TS_WIDTH(PTP_TS_WIDTH),
            .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
            .RX_RSS_ENABLE(RX_RSS_ENABLE),
            .RX_HASH_ENABLE(RX_HASH_ENABLE),
            .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
            .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
            .AXIL_ADDR_WIDTH(IF_AXIL_ADDR_WIDTH),
            .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
            .SEG_COUNT(RAM_SEG_COUNT),
            .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
            .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
            .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
            .RAM_SEL_WIDTH(IF_RAM_SEL_WIDTH),
            .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
            .RAM_PIPELINE(RAM_PIPELINE),
            .AXIS_DATA_WIDTH(AXIS_INT_DATA_WIDTH),
            .AXIS_KEEP_WIDTH(AXIS_INT_KEEP_WIDTH),
            .MAX_TX_SIZE(MAX_TX_SIZE),
            .MAX_RX_SIZE(MAX_RX_SIZE),
            .TX_RAM_SIZE(TX_RAM_SIZE),
            .RX_RAM_SIZE(RX_RAM_SIZE)
        )
        interface_inst (
            .clk(clk),
            .rst(rst),

            /*
             * DMA read descriptor output (control)
             */
            .m_axis_ctrl_dma_read_desc_dma_addr(if_ctrl_dma_read_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_ctrl_dma_read_desc_ram_sel(if_ctrl_dma_read_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_ctrl_dma_read_desc_ram_addr(if_ctrl_dma_read_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_ctrl_dma_read_desc_len(if_ctrl_dma_read_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_ctrl_dma_read_desc_tag(if_ctrl_dma_read_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_ctrl_dma_read_desc_valid(if_ctrl_dma_read_desc_valid[n]),
            .m_axis_ctrl_dma_read_desc_ready(if_ctrl_dma_read_desc_ready[n]),

            /*
             * DMA read descriptor status input (control)
             */
            .s_axis_ctrl_dma_read_desc_status_tag(if_ctrl_dma_read_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_ctrl_dma_read_desc_status_error(if_ctrl_dma_read_desc_status_error[n*4 +: 4]),
            .s_axis_ctrl_dma_read_desc_status_valid(if_ctrl_dma_read_desc_status_valid[n]),

            /*
             * DMA write descriptor output (control)
             */
            .m_axis_ctrl_dma_write_desc_dma_addr(if_ctrl_dma_write_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_ctrl_dma_write_desc_ram_sel(if_ctrl_dma_write_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_ctrl_dma_write_desc_ram_addr(if_ctrl_dma_write_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_ctrl_dma_write_desc_len(if_ctrl_dma_write_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_ctrl_dma_write_desc_tag(if_ctrl_dma_write_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_ctrl_dma_write_desc_valid(if_ctrl_dma_write_desc_valid[n]),
            .m_axis_ctrl_dma_write_desc_ready(if_ctrl_dma_write_desc_ready[n]),

            /*
             * DMA write descriptor status input (control)
             */
            .s_axis_ctrl_dma_write_desc_status_tag(if_ctrl_dma_write_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_ctrl_dma_write_desc_status_error(if_ctrl_dma_write_desc_status_error[n*4 +: 4]),
            .s_axis_ctrl_dma_write_desc_status_valid(if_ctrl_dma_write_desc_status_valid[n]),

            /*
             * DMA read descriptor output (data)
             */
            .m_axis_data_dma_read_desc_dma_addr(if_data_dma_read_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_data_dma_read_desc_ram_sel(if_data_dma_read_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_data_dma_read_desc_ram_addr(if_data_dma_read_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_data_dma_read_desc_len(if_data_dma_read_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_data_dma_read_desc_tag(if_data_dma_read_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_data_dma_read_desc_valid(if_data_dma_read_desc_valid[n]),
            .m_axis_data_dma_read_desc_ready(if_data_dma_read_desc_ready[n]),

            /*
             * DMA read descriptor status input (data)
             */
            .s_axis_data_dma_read_desc_status_tag(if_data_dma_read_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_data_dma_read_desc_status_error(if_data_dma_read_desc_status_error[n*4 +: 4]),
            .s_axis_data_dma_read_desc_status_valid(if_data_dma_read_desc_status_valid[n]),

            /*
             * DMA write descriptor output (data)
             */
            .m_axis_data_dma_write_desc_dma_addr(if_data_dma_write_desc_dma_addr[n*DMA_ADDR_WIDTH +: DMA_ADDR_WIDTH]),
            .m_axis_data_dma_write_desc_ram_sel(if_data_dma_write_desc_ram_sel[n*IF_RAM_SEL_WIDTH +: IF_RAM_SEL_WIDTH]),
            .m_axis_data_dma_write_desc_ram_addr(if_data_dma_write_desc_ram_addr[n*RAM_ADDR_WIDTH +: RAM_ADDR_WIDTH]),
            .m_axis_data_dma_write_desc_len(if_data_dma_write_desc_len[n*DMA_LEN_WIDTH +: DMA_LEN_WIDTH]),
            .m_axis_data_dma_write_desc_tag(if_data_dma_write_desc_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .m_axis_data_dma_write_desc_valid(if_data_dma_write_desc_valid[n]),
            .m_axis_data_dma_write_desc_ready(if_data_dma_write_desc_ready[n]),

            /*
             * DMA write descriptor status input (data)
             */
            .s_axis_data_dma_write_desc_status_tag(if_data_dma_write_desc_status_tag[n*IF_DMA_TAG_WIDTH +: IF_DMA_TAG_WIDTH]),
            .s_axis_data_dma_write_desc_status_error(if_data_dma_write_desc_status_error[n*4 +: 4]),
            .s_axis_data_dma_write_desc_status_valid(if_data_dma_write_desc_status_valid[n]),

            /*
             * AXI-Lite slave interface
             */
            .s_axil_awaddr(axil_if_awaddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_awprot(axil_if_awprot[n*3 +: 3]),
            .s_axil_awvalid(axil_if_awvalid[n]),
            .s_axil_awready(axil_if_awready[n]),
            .s_axil_wdata(axil_if_wdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_wstrb(axil_if_wstrb[n*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
            .s_axil_wvalid(axil_if_wvalid[n]),
            .s_axil_wready(axil_if_wready[n]),
            .s_axil_bresp(axil_if_bresp[n*2 +: 2]),
            .s_axil_bvalid(axil_if_bvalid[n]),
            .s_axil_bready(axil_if_bready[n]),
            .s_axil_araddr(axil_if_araddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_arprot(axil_if_arprot[n*3 +: 3]),
            .s_axil_arvalid(axil_if_arvalid[n]),
            .s_axil_arready(axil_if_arready[n]),
            .s_axil_rdata(axil_if_rdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_rresp(axil_if_rresp[n*2 +: 2]),
            .s_axil_rvalid(axil_if_rvalid[n]),
            .s_axil_rready(axil_if_rready[n]),

            /*
             * AXI-Lite master interface (passthrough for NIC control and status)
             */
            .m_axil_csr_awaddr(axil_if_csr_awaddr[n*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH]),
            .m_axil_csr_awprot(axil_if_csr_awprot[n*3 +: 3]),
            .m_axil_csr_awvalid(axil_if_csr_awvalid[n]),
            .m_axil_csr_awready(axil_if_csr_awready[n]),
            .m_axil_csr_wdata(axil_if_csr_wdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .m_axil_csr_wstrb(axil_if_csr_wstrb[n*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
            .m_axil_csr_wvalid(axil_if_csr_wvalid[n]),
            .m_axil_csr_wready(axil_if_csr_wready[n]),
            .m_axil_csr_bresp(axil_if_csr_bresp[n*2 +: 2]),
            .m_axil_csr_bvalid(axil_if_csr_bvalid[n]),
            .m_axil_csr_bready(axil_if_csr_bready[n]),
            .m_axil_csr_araddr(axil_if_csr_araddr[n*AXIL_CSR_ADDR_WIDTH +: AXIL_CSR_ADDR_WIDTH]),
            .m_axil_csr_arprot(axil_if_csr_arprot[n*3 +: 3]),
            .m_axil_csr_arvalid(axil_if_csr_arvalid[n]),
            .m_axil_csr_arready(axil_if_csr_arready[n]),
            .m_axil_csr_rdata(axil_if_csr_rdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .m_axil_csr_rresp(axil_if_csr_rresp[n*2 +: 2]),
            .m_axil_csr_rvalid(axil_if_csr_rvalid[n]),
            .m_axil_csr_rready(axil_if_csr_rready[n]),

            /*
             * RAM interface (control)
             */
            .ctrl_dma_ram_wr_cmd_sel(if_ctrl_dma_ram_wr_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .ctrl_dma_ram_wr_cmd_be(if_ctrl_dma_ram_wr_cmd_be[RAM_SEG_COUNT*RAM_SEG_BE_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_BE_WIDTH]),
            .ctrl_dma_ram_wr_cmd_addr(if_ctrl_dma_ram_wr_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .ctrl_dma_ram_wr_cmd_data(if_ctrl_dma_ram_wr_cmd_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .ctrl_dma_ram_wr_cmd_valid(if_ctrl_dma_ram_wr_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_wr_cmd_ready(if_ctrl_dma_ram_wr_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_wr_done(if_ctrl_dma_ram_wr_done[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_cmd_sel(if_ctrl_dma_ram_rd_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .ctrl_dma_ram_rd_cmd_addr(if_ctrl_dma_ram_rd_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .ctrl_dma_ram_rd_cmd_valid(if_ctrl_dma_ram_rd_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_cmd_ready(if_ctrl_dma_ram_rd_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_resp_data(if_ctrl_dma_ram_rd_resp_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .ctrl_dma_ram_rd_resp_valid(if_ctrl_dma_ram_rd_resp_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .ctrl_dma_ram_rd_resp_ready(if_ctrl_dma_ram_rd_resp_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),

            /*
             * RAM interface (data)
             */
            .data_dma_ram_wr_cmd_sel(if_data_dma_ram_wr_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .data_dma_ram_wr_cmd_be(if_data_dma_ram_wr_cmd_be[RAM_SEG_COUNT*RAM_SEG_BE_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_BE_WIDTH]),
            .data_dma_ram_wr_cmd_addr(if_data_dma_ram_wr_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .data_dma_ram_wr_cmd_data(if_data_dma_ram_wr_cmd_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .data_dma_ram_wr_cmd_valid(if_data_dma_ram_wr_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_wr_cmd_ready(if_data_dma_ram_wr_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_wr_done(if_data_dma_ram_wr_done[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_cmd_sel(if_data_dma_ram_rd_cmd_sel[RAM_SEG_COUNT*IF_RAM_SEL_WIDTH*n +: RAM_SEG_COUNT*IF_RAM_SEL_WIDTH]),
            .data_dma_ram_rd_cmd_addr(if_data_dma_ram_rd_cmd_addr[RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH]),
            .data_dma_ram_rd_cmd_valid(if_data_dma_ram_rd_cmd_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_cmd_ready(if_data_dma_ram_rd_cmd_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_resp_data(if_data_dma_ram_rd_resp_data[RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH*n +: RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH]),
            .data_dma_ram_rd_resp_valid(if_data_dma_ram_rd_resp_valid[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),
            .data_dma_ram_rd_resp_ready(if_data_dma_ram_rd_resp_ready[RAM_SEG_COUNT*n +: RAM_SEG_COUNT]),

            /*
             * Transmit data output
             */
            .tx_axis_tdata(if_tx_axis_tdata),
            .tx_axis_tkeep(if_tx_axis_tkeep),
            .tx_axis_tvalid(if_tx_axis_tvalid),
            .tx_axis_tready(if_tx_axis_tready),
            .tx_axis_tlast(if_tx_axis_tlast),
            .tx_axis_tuser(if_tx_axis_tuser),

            /*
             * Transmit timestamp input
             */
            .s_axis_tx_ptp_ts_96(if_tx_ptp_ts_96),
            .s_axis_tx_ptp_ts_valid(if_tx_ptp_ts_valid),
            .s_axis_tx_ptp_ts_ready(if_tx_ptp_ts_ready),

            /*
             * Receive data input
             */
            .rx_axis_tdata(if_rx_axis_tdata),
            .rx_axis_tkeep(if_rx_axis_tkeep),
            .rx_axis_tvalid(if_rx_axis_tvalid),
            .rx_axis_tready(if_rx_axis_tready),
            .rx_axis_tlast(if_rx_axis_tlast),
            .rx_axis_tuser(if_rx_axis_tuser),

            /*
             * Receive timestamp input
             */
            .s_axis_rx_ptp_ts_96(if_rx_ptp_ts_96),
            .s_axis_rx_ptp_ts_valid(if_rx_ptp_ts_valid),
            .s_axis_rx_ptp_ts_ready(if_rx_ptp_ts_ready),

            /*
             * PTP clock
             */
            .ptp_ts_96(ptp_ts_96),
            .ptp_ts_step(ptp_ts_step),

            /*
             * MSI interrupts
             */
            .msi_irq(if_msi_irq[n])
        );

        for (m = 0; m < PORTS_PER_IF; m = m + 1) begin : port

            if (PTP_TS_ENABLE) begin: ptp

                // PTP CDC logic
                ptp_clock_cdc #(
                    .TS_WIDTH(PTP_TS_WIDTH),
                    .NS_WIDTH(PTP_PERIOD_NS_WIDTH),
                    .FNS_WIDTH(16),
                    .USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK)
                )
                tx_ptp_cdc_inst (
                    .input_clk(clk),
                    .input_rst(rst),
                    .output_clk(tx_clk[n*PORTS_PER_IF+m]),
                    .output_rst(tx_rst[n*PORTS_PER_IF+m]),
                    .sample_clk(ptp_sample_clk),
                    .input_ts(ptp_ts_96),
                    .input_ts_step(ptp_ts_step),
                    .output_ts(tx_ptp_ts_96[(n*PORTS_PER_IF+m)*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
                    .output_ts_step(tx_ptp_ts_step[n*PORTS_PER_IF+m]),
                    .output_pps(),
                    .locked()
                );

                ptp_clock_cdc #(
                    .TS_WIDTH(PTP_TS_WIDTH),
                    .NS_WIDTH(PTP_PERIOD_NS_WIDTH),
                    .FNS_WIDTH(16),
                    .USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK)
                )
                rx_ptp_cdc_inst (
                    .input_clk(clk),
                    .input_rst(rst),
                    .output_clk(rx_clk[n*PORTS_PER_IF+m]),
                    .output_rst(rx_rst[n*PORTS_PER_IF+m]),
                    .sample_clk(ptp_sample_clk),
                    .input_ts(ptp_ts_96),
                    .input_ts_step(ptp_ts_step),
                    .output_ts(rx_ptp_ts_96[(n*PORTS_PER_IF+m)*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
                    .output_ts_step(rx_ptp_ts_step[n*PORTS_PER_IF+m]),
                    .output_pps(),
                    .locked()
                );

                // PTP TS FIFO (TX)
                wire [PTP_TS_WIDTH-1:0] tx_pipe_ptp_ts;
                wire [PTP_TAG_WIDTH-1:0] tx_pipe_ptp_ts_tag;
                wire tx_pipe_ptp_ts_valid;
                wire tx_pipe_ptp_ts_ready;

                axis_async_fifo #(
                    .DEPTH(TX_PTP_TS_FIFO_DEPTH),
                    .DATA_WIDTH(PTP_TS_WIDTH),
                    .KEEP_ENABLE(0),
                    .LAST_ENABLE(0),
                    .ID_ENABLE(1),
                    .ID_WIDTH(PTP_TAG_WIDTH),
                    .DEST_ENABLE(0),
                    .USER_ENABLE(0),
                    .FRAME_FIFO(0)
                )
                tx_ptp_ts_fifo_inst (
                    .async_rst(rst | tx_rst[n*PORTS_PER_IF+m]),

                    // AXI input
                    .s_clk(tx_clk[n*PORTS_PER_IF+m]),
                    .s_axis_tdata(s_axis_tx_ptp_ts[(n*PORTS_PER_IF+m)*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
                    .s_axis_tkeep(0),
                    .s_axis_tvalid(s_axis_tx_ptp_ts_valid[n*PORTS_PER_IF+m +: 1]),
                    .s_axis_tready(s_axis_tx_ptp_ts_ready[n*PORTS_PER_IF+m +: 1]),
                    .s_axis_tlast(0),
                    .s_axis_tid(s_axis_tx_ptp_ts_tag[(n*PORTS_PER_IF+m)*PTP_TAG_WIDTH +: PTP_TAG_WIDTH]),
                    .s_axis_tdest(0),
                    .s_axis_tuser(0),

                    // AXI output
                    .m_clk(clk),
                    .m_axis_tdata(tx_pipe_ptp_ts),
                    .m_axis_tkeep(),
                    .m_axis_tvalid(tx_pipe_ptp_ts_valid),
                    .m_axis_tready(tx_pipe_ptp_ts_ready),
                    .m_axis_tlast(),
                    .m_axis_tid(tx_pipe_ptp_ts_tag),
                    .m_axis_tdest(),
                    .m_axis_tuser(),

                    // Status
                    .s_status_overflow(),
                    .s_status_bad_frame(),
                    .s_status_good_frame(),
                    .m_status_overflow(),
                    .m_status_bad_frame(),
                    .m_status_good_frame()
                );

                axis_pipeline_fifo #(
                    .DATA_WIDTH(PTP_TS_WIDTH),
                    .KEEP_ENABLE(0),
                    .LAST_ENABLE(0),
                    .ID_ENABLE(1),
                    .ID_WIDTH(PTP_TAG_WIDTH),
                    .DEST_ENABLE(0),
                    .USER_ENABLE(0),
                    .LENGTH(AXIS_TX_TS_PIPELINE)
                )
                tx_ptp_ts_pipeline_fifo_inst (
                    .clk(clk),
                    .rst(rst),

                    // AXI input
                    .s_axis_tdata(tx_pipe_ptp_ts),
                    .s_axis_tkeep(0),
                    .s_axis_tvalid(tx_pipe_ptp_ts_valid),
                    .s_axis_tready(tx_pipe_ptp_ts_ready),
                    .s_axis_tlast(0),
                    .s_axis_tid(tx_pipe_ptp_ts_tag),
                    .s_axis_tdest(0),
                    .s_axis_tuser(0),

                    // AXI output
                    .m_axis_tdata(if_tx_ptp_ts_96[m*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
                    .m_axis_tkeep(),
                    .m_axis_tvalid(if_tx_ptp_ts_valid[m +: 1]),
                    .m_axis_tready(if_tx_ptp_ts_ready[m +: 1]),
                    .m_axis_tlast(),
                    .m_axis_tid(if_tx_ptp_ts_tag[m*PTP_TAG_WIDTH +: PTP_TAG_WIDTH]),
                    .m_axis_tdest(),
                    .m_axis_tuser()
                );

                wire [PTP_TS_WIDTH-1:0] rx_ts;
                wire rx_ts_valid;

                ptp_ts_extract #(
                    .TS_WIDTH(PTP_TS_WIDTH),
                    .TS_OFFSET(1),
                    .USER_WIDTH(PTP_TS_WIDTH+1)
                )
                rx_ptp_ts_extract_inst (
                    .clk(clk),
                    .rst(rst),

                    // AXI stream input
                    .s_axis_tvalid(if_rx_axis_tvalid[m +: 1] && if_rx_axis_tready[m +: 1]),
                    .s_axis_tlast(if_rx_axis_tlast[m +: 1]),
                    .s_axis_tuser(if_rx_axis_tuser_int[m*(PTP_TS_WIDTH+1) +: (PTP_TS_WIDTH+1)]),

                    // Timestamp output
                    .m_axis_ts(rx_ts),
                    .m_axis_ts_valid(rx_ts_valid)
                );

                // PTP TS FIFO (RX)
                axis_fifo #(
                    .DEPTH(RX_PTP_TS_FIFO_DEPTH),
                    .DATA_WIDTH(PTP_TS_WIDTH),
                    .KEEP_ENABLE(0),
                    .LAST_ENABLE(0),
                    .ID_ENABLE(0),
                    .DEST_ENABLE(0),
                    .USER_ENABLE(0),
                    .FRAME_FIFO(0)
                )
                rx_ptp_ts_fifo_inst (
                    .clk(clk),
                    .rst(rst),

                    // AXI input
                    .s_axis_tdata(rx_ts),
                    .s_axis_tkeep(0),
                    .s_axis_tvalid(rx_ts_valid),
                    .s_axis_tready(),
                    .s_axis_tlast(0),
                    .s_axis_tid(0),
                    .s_axis_tdest(0),
                    .s_axis_tuser(0),

                    // AXI output
                    .m_axis_tdata(if_rx_ptp_ts_96[m*PTP_TS_WIDTH +: PTP_TS_WIDTH]),
                    .m_axis_tkeep(),
                    .m_axis_tvalid(if_rx_ptp_ts_valid[m +: 1]),
                    .m_axis_tready(if_rx_ptp_ts_ready[m +: 1]),
                    .m_axis_tlast(),
                    .m_axis_tid(),
                    .m_axis_tdest(),
                    .m_axis_tuser(),

                    // Status
                    .status_overflow(),
                    .status_bad_frame(),
                    .status_good_frame()
                );

            end else begin

                assign tx_ptp_ts_96[(n*PORTS_PER_IF+m)*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {PTP_TS_WIDTH{1'b0}};
                assign tx_ptp_ts_step[n*PORTS_PER_IF+m] = 1'b0;

                assign rx_ptp_ts_96[(n*PORTS_PER_IF+m)*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {PTP_TS_WIDTH{1'b0}};
                assign rx_ptp_ts_step[n*PORTS_PER_IF+m] = 1'b0;

                assign if_tx_ptp_ts_96[m*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {PTP_TS_WIDTH{1'b0}};
                assign if_tx_ptp_ts_tag[m*PTP_TAG_WIDTH +: PTP_TAG_WIDTH] = {PTP_TAG_WIDTH{1'b0}};
                assign if_tx_ptp_ts_valid = 1'b0;

                assign if_rx_ptp_ts_96[m*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {PTP_TS_WIDTH{1'b0}};
                assign if_rx_ptp_ts_valid[m +: 1] = 1'b0;

            end

            // TX FIFOs
            wire [AXIS_INT_DATA_WIDTH-1:0] axis_tx_fifo_tdata;
            wire [AXIS_INT_KEEP_WIDTH-1:0] axis_tx_fifo_tkeep;
            wire axis_tx_fifo_tvalid;
            wire axis_tx_fifo_tready;
            wire axis_tx_fifo_tlast;
            wire [AXIS_TX_USER_WIDTH-1:0] axis_tx_fifo_tuser;

            wire [AXIS_INT_DATA_WIDTH-1:0] axis_tx_pipe_tdata;
            wire [AXIS_INT_KEEP_WIDTH-1:0] axis_tx_pipe_tkeep;
            wire axis_tx_pipe_tvalid;
            wire axis_tx_pipe_tready;
            wire axis_tx_pipe_tlast;
            wire [AXIS_TX_USER_WIDTH-1:0] axis_tx_pipe_tuser;

            axis_fifo #(
                .DEPTH(TX_FIFO_DEPTH),
                .DATA_WIDTH(AXIS_INT_DATA_WIDTH),
                .KEEP_ENABLE(AXIS_INT_KEEP_WIDTH > 1),
                .KEEP_WIDTH(AXIS_INT_KEEP_WIDTH),
                .LAST_ENABLE(1),
                .ID_ENABLE(0),
                .DEST_ENABLE(0),
                .USER_ENABLE(1),
                .USER_WIDTH(AXIS_TX_USER_WIDTH),
                .PIPELINE_OUTPUT(AXIS_TX_FIFO_PIPELINE),
                .FRAME_FIFO(1),
                .USER_BAD_FRAME_VALUE(1'b1),
                .USER_BAD_FRAME_MASK(1'b1),
                .DROP_BAD_FRAME(1),
                .DROP_WHEN_FULL(0)
            )
            tx_fifo_inst (
                .clk(clk),
                .rst(rst),

                // AXI input
                .s_axis_tdata(if_tx_axis_tdata[m*AXIS_INT_DATA_WIDTH +: AXIS_INT_DATA_WIDTH]),
                .s_axis_tkeep(if_tx_axis_tkeep[m*AXIS_INT_KEEP_WIDTH +: AXIS_INT_KEEP_WIDTH]),
                .s_axis_tvalid(if_tx_axis_tvalid[m +: 1]),
                .s_axis_tready(if_tx_axis_tready[m +: 1]),
                .s_axis_tlast(if_tx_axis_tlast[m +: 1]),
                .s_axis_tid(0),
                .s_axis_tdest(0),
                // .s_axis_tuser(if_tx_axis_tuser[m*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),
                .s_axis_tuser({{PTP_TAG_WIDTH{1'b0}}, if_tx_axis_tuser[m +: 1]}),

                // AXI output
                .m_axis_tdata(axis_tx_fifo_tdata),
                .m_axis_tkeep(axis_tx_fifo_tkeep),
                .m_axis_tvalid(axis_tx_fifo_tvalid),
                .m_axis_tready(axis_tx_fifo_tready),
                .m_axis_tlast(axis_tx_fifo_tlast),
                .m_axis_tid(),
                .m_axis_tdest(),
                .m_axis_tuser(axis_tx_fifo_tuser),

                // Status
                .status_overflow(),
                .status_bad_frame(),
                .status_good_frame()
            );

            axis_pipeline_fifo #(
                .DATA_WIDTH(AXIS_INT_DATA_WIDTH),
                .KEEP_ENABLE(AXIS_INT_KEEP_WIDTH > 1),
                .KEEP_WIDTH(AXIS_INT_KEEP_WIDTH),
                .LAST_ENABLE(1),
                .ID_ENABLE(0),
                .DEST_ENABLE(0),
                .USER_ENABLE(1),
                .USER_WIDTH(AXIS_TX_USER_WIDTH),
                .LENGTH(AXIS_TX_PIPELINE)
            )
            tx_pipeline_fifo_inst (
                .clk(clk),
                .rst(rst),

                // AXI input
                .s_axis_tdata(axis_tx_fifo_tdata),
                .s_axis_tkeep(axis_tx_fifo_tkeep),
                .s_axis_tvalid(axis_tx_fifo_tvalid),
                .s_axis_tready(axis_tx_fifo_tready),
                .s_axis_tlast(axis_tx_fifo_tlast),
                .s_axis_tid(0),
                .s_axis_tdest(0),
                .s_axis_tuser(axis_tx_fifo_tuser),

                // AXI output
                .m_axis_tdata(axis_tx_pipe_tdata),
                .m_axis_tkeep(axis_tx_pipe_tkeep),
                .m_axis_tvalid(axis_tx_pipe_tvalid),
                .m_axis_tready(axis_tx_pipe_tready),
                .m_axis_tlast(axis_tx_pipe_tlast),
                .m_axis_tid(),
                .m_axis_tdest(),
                .m_axis_tuser(axis_tx_pipe_tuser)
            );

            axis_async_fifo_adapter #(
                .DEPTH(MAX_TX_SIZE),
                .S_DATA_WIDTH(AXIS_INT_DATA_WIDTH),
                .S_KEEP_ENABLE(AXIS_INT_KEEP_WIDTH > 1),
                .S_KEEP_WIDTH(AXIS_INT_KEEP_WIDTH),
                .M_DATA_WIDTH(AXIS_DATA_WIDTH),
                .M_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
                .M_KEEP_WIDTH(AXIS_KEEP_WIDTH),
                .ID_ENABLE(0),
                .DEST_ENABLE(0),
                .USER_ENABLE(1),
                .USER_WIDTH(AXIS_TX_USER_WIDTH),
                .FRAME_FIFO(1),
                .USER_BAD_FRAME_VALUE(1'b1),
                .USER_BAD_FRAME_MASK(1'b1),
                .DROP_BAD_FRAME(1),
                .DROP_WHEN_FULL(0)
            )
            tx_async_fifo_inst (
                // AXI input
                .s_clk(clk),
                .s_rst(rst),
                .s_axis_tdata(axis_tx_pipe_tdata),
                .s_axis_tkeep(axis_tx_pipe_tkeep),
                .s_axis_tvalid(axis_tx_pipe_tvalid),
                .s_axis_tready(axis_tx_pipe_tready),
                .s_axis_tlast(axis_tx_pipe_tlast),
                .s_axis_tid(0),
                .s_axis_tdest(0),
                .s_axis_tuser(axis_tx_pipe_tuser),

                // AXI output
                .m_clk(tx_clk[n*PORTS_PER_IF+m]),
                .m_rst(tx_rst[n*PORTS_PER_IF+m]),
                .m_axis_tdata(m_axis_tx_tdata[(n*PORTS_PER_IF+m)*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
                .m_axis_tkeep(m_axis_tx_tkeep[(n*PORTS_PER_IF+m)*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
                .m_axis_tvalid(m_axis_tx_tvalid[n*PORTS_PER_IF+m]),
                .m_axis_tready(m_axis_tx_tready[n*PORTS_PER_IF+m]),
                .m_axis_tlast(m_axis_tx_tlast[n*PORTS_PER_IF+m]),
                .m_axis_tid(),
                .m_axis_tdest(),
                .m_axis_tuser(m_axis_tx_tuser[(n*PORTS_PER_IF+m)*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH]),

                // Status
                .s_status_overflow(),
                .s_status_bad_frame(),
                .s_status_good_frame(),
                .m_status_overflow(),
                .m_status_bad_frame(),
                .m_status_good_frame()
            );

            // RX FIFOs
            wire [AXIS_INT_DATA_WIDTH-1:0] axis_rx_fifo_tdata;
            wire [AXIS_INT_KEEP_WIDTH-1:0] axis_rx_fifo_tkeep;
            wire axis_rx_fifo_tvalid;
            wire axis_rx_fifo_tready;
            wire axis_rx_fifo_tlast;
            wire [AXIS_RX_USER_WIDTH-1:0] axis_rx_fifo_tuser;

            wire [AXIS_INT_DATA_WIDTH-1:0] axis_rx_pipe_tdata;
            wire [AXIS_INT_KEEP_WIDTH-1:0] axis_rx_pipe_tkeep;
            wire axis_rx_pipe_tvalid;
            wire axis_rx_pipe_tready;
            wire axis_rx_pipe_tlast;
            wire [AXIS_RX_USER_WIDTH-1:0] axis_rx_pipe_tuser;

            axis_async_fifo_adapter #(
                .DEPTH(MAX_RX_SIZE),
                .S_DATA_WIDTH(AXIS_DATA_WIDTH),
                .S_KEEP_ENABLE(AXIS_KEEP_WIDTH > 1),
                .S_KEEP_WIDTH(AXIS_KEEP_WIDTH),
                .M_DATA_WIDTH(AXIS_INT_DATA_WIDTH),
                .M_KEEP_ENABLE(AXIS_INT_KEEP_WIDTH > 1),
                .M_KEEP_WIDTH(AXIS_INT_KEEP_WIDTH),
                .ID_ENABLE(0),
                .DEST_ENABLE(0),
                .USER_ENABLE(1),
                .USER_WIDTH(AXIS_RX_USER_WIDTH),
                .FRAME_FIFO(1),
                .USER_BAD_FRAME_VALUE(1'b1),
                .USER_BAD_FRAME_MASK(1'b1),
                .DROP_BAD_FRAME(1),
                .DROP_WHEN_FULL(!AXIS_RX_USE_READY)
            )
            rx_async_fifo_inst (
                // AXI input
                .s_clk(rx_clk[n*PORTS_PER_IF+m]),
                .s_rst(rx_rst[n*PORTS_PER_IF+m]),
                .s_axis_tdata(s_axis_rx_tdata[(n*PORTS_PER_IF+m)*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
                .s_axis_tkeep(s_axis_rx_tkeep[(n*PORTS_PER_IF+m)*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
                .s_axis_tvalid(s_axis_rx_tvalid[n*PORTS_PER_IF+m]),
                .s_axis_tready(s_axis_rx_tready[n*PORTS_PER_IF+m]),
                .s_axis_tlast(s_axis_rx_tlast[n*PORTS_PER_IF+m]),
                .s_axis_tid(0),
                .s_axis_tdest(0),
                .s_axis_tuser(s_axis_rx_tuser[(n*PORTS_PER_IF+m)*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH]),

                // AXI output
                .m_clk(clk),
                .m_rst(rst),
                .m_axis_tdata(axis_rx_fifo_tdata),
                .m_axis_tkeep(axis_rx_fifo_tkeep),
                .m_axis_tvalid(axis_rx_fifo_tvalid),
                .m_axis_tready(axis_rx_fifo_tready),
                .m_axis_tlast(axis_rx_fifo_tlast),
                .m_axis_tid(),
                .m_axis_tdest(),
                .m_axis_tuser(axis_rx_fifo_tuser),

                // Status
                .s_status_overflow(),
                .s_status_bad_frame(),
                .s_status_good_frame(),
                .m_status_overflow(),
                .m_status_bad_frame(),
                .m_status_good_frame()
            );

            axis_pipeline_fifo #(
                .DATA_WIDTH(AXIS_INT_DATA_WIDTH),
                .KEEP_ENABLE(AXIS_INT_KEEP_WIDTH > 1),
                .KEEP_WIDTH(AXIS_INT_KEEP_WIDTH),
                .LAST_ENABLE(1),
                .ID_ENABLE(0),
                .DEST_ENABLE(0),
                .USER_ENABLE(1),
                .USER_WIDTH(AXIS_RX_USER_WIDTH),
                .LENGTH(AXIS_RX_PIPELINE)
            )
            rx_pipeline_fifo_inst (
                .clk(clk),
                .rst(rst),

                // AXI input
                .s_axis_tdata(axis_rx_fifo_tdata),
                .s_axis_tkeep(axis_rx_fifo_tkeep),
                .s_axis_tvalid(axis_rx_fifo_tvalid),
                .s_axis_tready(axis_rx_fifo_tready),
                .s_axis_tlast(axis_rx_fifo_tlast),
                .s_axis_tid(0),
                .s_axis_tdest(0),
                .s_axis_tuser(axis_rx_fifo_tuser),

                // AXI output
                .m_axis_tdata(axis_rx_pipe_tdata),
                .m_axis_tkeep(axis_rx_pipe_tkeep),
                .m_axis_tvalid(axis_rx_pipe_tvalid),
                .m_axis_tready(axis_rx_pipe_tready),
                .m_axis_tlast(axis_rx_pipe_tlast),
                .m_axis_tid(),
                .m_axis_tdest(),
                .m_axis_tuser(axis_rx_pipe_tuser)
            );

            axis_fifo #(
                .DEPTH(RX_FIFO_DEPTH),
                .DATA_WIDTH(AXIS_INT_DATA_WIDTH),
                .KEEP_ENABLE(AXIS_INT_KEEP_WIDTH > 1),
                .KEEP_WIDTH(AXIS_INT_KEEP_WIDTH),
                .LAST_ENABLE(1),
                .ID_ENABLE(0),
                .DEST_ENABLE(0),
                .USER_ENABLE(1),
                .USER_WIDTH(AXIS_RX_USER_WIDTH),
                .PIPELINE_OUTPUT(AXIS_RX_FIFO_PIPELINE),
                .FRAME_FIFO(1),
                .USER_BAD_FRAME_VALUE(1'b1),
                .USER_BAD_FRAME_MASK(1'b1),
                .DROP_BAD_FRAME(1),
                .DROP_WHEN_FULL(0)
            )
            rx_fifo_inst (
                .clk(clk),
                .rst(rst),

                // AXI input
                .s_axis_tdata(axis_rx_pipe_tdata),
                .s_axis_tkeep(axis_rx_pipe_tkeep),
                .s_axis_tvalid(axis_rx_pipe_tvalid),
                .s_axis_tready(axis_rx_pipe_tready),
                .s_axis_tlast(axis_rx_pipe_tlast),
                .s_axis_tid(0),
                .s_axis_tdest(0),
                .s_axis_tuser(axis_rx_pipe_tuser),

                // AXI output
                .m_axis_tdata(if_rx_axis_tdata[m*AXIS_INT_DATA_WIDTH +: AXIS_INT_DATA_WIDTH]),
                .m_axis_tkeep(if_rx_axis_tkeep[m*AXIS_INT_KEEP_WIDTH +: AXIS_INT_KEEP_WIDTH]),
                .m_axis_tvalid(if_rx_axis_tvalid[m +: 1]),
                .m_axis_tready(if_rx_axis_tready[m +: 1]),
                .m_axis_tlast(if_rx_axis_tlast[m +: 1]),
                .m_axis_tid(),
                .m_axis_tdest(),
                // .m_axis_tuser(if_rx_axis_tuser[m*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH]),
                .m_axis_tuser(if_rx_axis_tuser_int[m*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH]),

                // Status
                .status_overflow(),
                .status_bad_frame(),
                .status_good_frame()
            );

            assign if_rx_axis_tuser[m +: 1] = if_rx_axis_tuser_int[m*AXIS_RX_USER_WIDTH +: 1];

        end

    end

endgenerate

endmodule
