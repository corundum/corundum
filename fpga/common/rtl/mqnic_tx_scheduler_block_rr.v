// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * TX scheduler block (round-robin)
 */
module mqnic_tx_scheduler_block #
(
    // Structural configuration
    parameter PORTS = 1,
    parameter INDEX = 0,

    // Clock configuration
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,

    // PTP configuration
    parameter PTP_CLK_PERIOD_NS_NUM = 4,
    parameter PTP_CLK_PERIOD_NS_DENOM = 1,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Queue manager configuration
    parameter QUEUE_INDEX_WIDTH = 13,

    // Scheduler configuration
    parameter TX_SCHEDULER_OP_TABLE_SIZE = 8,
    parameter TX_SCHEDULER_PIPELINE = 3,
    parameter TDMA_INDEX_WIDTH = 6,

    // Interface configuration
    parameter DMA_LEN_WIDTH = 16,
    parameter TX_REQ_TAG_WIDTH = 8,
    parameter MAX_TX_SIZE = 9214,

    // Register interface configuration
    parameter REG_ADDR_WIDTH = 16,
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    parameter RB_BASE_ADDR = 0,
    parameter RB_NEXT_PTR = 0,

    // AXI lite interface configuration
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter AXIL_OFFSET = 0,

    // Streaming interface configuration
    parameter AXIS_TX_DEST_WIDTH = $clog2(PORTS)+4
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Control register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]     ctrl_reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]     ctrl_reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]     ctrl_reg_wr_strb,
    input  wire                          ctrl_reg_wr_en,
    output wire                          ctrl_reg_wr_wait,
    output wire                          ctrl_reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]     ctrl_reg_rd_addr,
    input  wire                          ctrl_reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]     ctrl_reg_rd_data,
    output wire                          ctrl_reg_rd_wait,
    output wire                          ctrl_reg_rd_ack,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire [2:0]                    s_axil_awprot,
    input  wire                          s_axil_awvalid,
    output wire                          s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]    s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]    s_axil_wstrb,
    input  wire                          s_axil_wvalid,
    output wire                          s_axil_wready,
    output wire [1:0]                    s_axil_bresp,
    output wire                          s_axil_bvalid,
    input  wire                          s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [2:0]                    s_axil_arprot,
    input  wire                          s_axil_arvalid,
    output wire                          s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [1:0]                    s_axil_rresp,
    output wire                          s_axil_rvalid,
    input  wire                          s_axil_rready,

    /*
     * Transmit request output (queue index)
     */
    output wire [QUEUE_INDEX_WIDTH-1:0]  m_axis_tx_req_queue,
    output wire [TX_REQ_TAG_WIDTH-1:0]   m_axis_tx_req_tag,
    output wire [AXIS_TX_DEST_WIDTH-1:0] m_axis_tx_req_dest,
    output wire                          m_axis_tx_req_valid,
    input  wire                          m_axis_tx_req_ready,

    /*
     * Transmit request status input
     */
    input  wire [DMA_LEN_WIDTH-1:0]      s_axis_tx_req_status_len,
    input  wire [TX_REQ_TAG_WIDTH-1:0]   s_axis_tx_req_status_tag,
    input  wire                          s_axis_tx_req_status_valid,

    /*
     * TX doorbell input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]  s_axis_doorbell_queue,
    input  wire                          s_axis_doorbell_valid,

    /*
     * PTP clock
     */
    input  wire                          ptp_clk,
    input  wire                          ptp_rst,
    input  wire                          ptp_sample_clk,
    input  wire                          ptp_td_sd,
    input  wire                          ptp_pps,
    input  wire                          ptp_pps_str,
    input  wire                          ptp_sync_locked,
    input  wire [63:0]                   ptp_sync_ts_rel,
    input  wire                          ptp_sync_ts_rel_step,
    input  wire [96:0]                   ptp_sync_ts_tod,
    input  wire                          ptp_sync_ts_tod_step,
    input  wire                          ptp_sync_pps,
    input  wire                          ptp_sync_pps_str,
    input  wire [PTP_PEROUT_COUNT-1:0]   ptp_perout_locked,
    input  wire [PTP_PEROUT_COUNT-1:0]   ptp_perout_error,
    input  wire [PTP_PEROUT_COUNT-1:0]   ptp_perout_pulse,

    /*
     * Configuration
     */
    input  wire [DMA_LEN_WIDTH-1:0]      mtu
);

parameter SCHED_COUNT = 1;
parameter AXIL_SCHED_ADDR_WIDTH = AXIL_ADDR_WIDTH-$clog2(SCHED_COUNT);

localparam RBB = RB_BASE_ADDR & {REG_ADDR_WIDTH{1'b1}};

// control registers
reg ctrl_reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = 0;
reg ctrl_reg_rd_ack_reg = 1'b0;

reg sched_enable_reg = 1'b0;
reg [AXIS_TX_DEST_WIDTH-1:0] sched_dest_reg = (INDEX % PORTS) << 4;

assign ctrl_reg_wr_wait = 1'b0;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_reg;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_reg;
assign ctrl_reg_rd_wait = 1'b0;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_reg;

always @(posedge clk) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= 0;
    ctrl_reg_rd_ack_reg <= 1'b0;

    if (ctrl_reg_wr_en && !ctrl_reg_wr_ack_reg) begin
        // write operation
        ctrl_reg_wr_ack_reg <= 1'b1;
        case ({ctrl_reg_wr_addr >> 2, 2'b00})
            // Scheduler
            RBB+8'h28: begin
                // Sched: Control
                if (ctrl_reg_wr_strb[0]) begin
                    sched_enable_reg <= ctrl_reg_wr_data[0];
                end
            end
            RBB+8'h2C: begin
                // Sched: dest
                if (ctrl_reg_wr_strb[0]) begin
                    sched_dest_reg <= ctrl_reg_wr_data[7:0];
                end
            end
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            // Scheduler block
            RBB+8'h00: ctrl_reg_rd_data_reg <= 32'h0000C004;          // Sched block: Type
            RBB+8'h04: ctrl_reg_rd_data_reg <= 32'h00000300;          // Sched block: Version
            RBB+8'h08: ctrl_reg_rd_data_reg <= RB_NEXT_PTR;           // Sched block: Next header
            RBB+8'h0C: ctrl_reg_rd_data_reg <= RB_BASE_ADDR+8'h10;    // Sched block: Offset
            // Round-robin scheduler
            RBB+8'h10: ctrl_reg_rd_data_reg <= 32'h0000C040;          // Sched: Type
            RBB+8'h14: ctrl_reg_rd_data_reg <= 32'h00000100;          // Sched: Version
            RBB+8'h18: ctrl_reg_rd_data_reg <= 0;                     // Sched: Next header
            RBB+8'h1C: ctrl_reg_rd_data_reg <= AXIL_OFFSET;           // Sched: Offset
            RBB+8'h20: ctrl_reg_rd_data_reg <= 2**QUEUE_INDEX_WIDTH;  // Sched: Channel count
            RBB+8'h24: ctrl_reg_rd_data_reg <= 4;                     // Sched: Channel stride
            RBB+8'h28: begin
                // Sched: Control
                ctrl_reg_rd_data_reg[0] <= sched_enable_reg;
            end
            RBB+8'h2C: ctrl_reg_rd_data_reg <= sched_dest_reg;        // Sched: dest
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        sched_enable_reg <= 1'b0;
        sched_dest_reg <= (INDEX % PORTS) << 4;
    end
end

assign m_axis_tx_req_dest = sched_dest_reg;

tx_scheduler_rr #(
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_SCHED_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .REQ_TAG_WIDTH(TX_REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(TX_SCHEDULER_OP_TABLE_SIZE),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .PIPELINE(TX_SCHEDULER_PIPELINE),
    .SCHED_CTRL_ENABLE(0)
)
tx_scheduler_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Transmit request output (queue index)
     */
    .m_axis_tx_req_queue(m_axis_tx_req_queue),
    .m_axis_tx_req_tag(m_axis_tx_req_tag),
    .m_axis_tx_req_valid(m_axis_tx_req_valid),
    .m_axis_tx_req_ready(m_axis_tx_req_ready),

    /*
     * Transmit request status input
     */
    .s_axis_tx_req_status_len(s_axis_tx_req_status_len),
    .s_axis_tx_req_status_tag(s_axis_tx_req_status_tag),
    .s_axis_tx_req_status_valid(s_axis_tx_req_status_valid),

    /*
     * Doorbell input
     */
    .s_axis_doorbell_queue(s_axis_doorbell_queue),
    .s_axis_doorbell_valid(s_axis_doorbell_valid),

    /*
     * Scheduler control input
     */
    .s_axis_sched_ctrl_queue(0),
    .s_axis_sched_ctrl_enable(1'b0),
    .s_axis_sched_ctrl_valid(1'b0),
    .s_axis_sched_ctrl_ready(),

    /*
     * AXI-Lite slave interface
     */
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

    /*
     * Control
     */
    .enable(sched_enable_reg),
    .active()
);

endmodule

`resetall
