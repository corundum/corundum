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
 * TX scheduler block (round-robin)
 */
module mqnic_tx_scheduler_block #
(
    // Width of control register interface address in bits
    parameter REG_ADDR_WIDTH = 16,
    // Width of control register interface data in bits
    parameter REG_DATA_WIDTH = 32,
    // Width of control register interface strb
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Offset to AXI lite interface
    parameter AXIL_OFFSET = 0,
    // Length field width
    parameter LEN_WIDTH = 16,
    // Transmit request tag field width
    parameter REQ_TAG_WIDTH = 8,
    // Number of outstanding operations
    parameter OP_TABLE_SIZE = 16,
    // Queue index width
    parameter QUEUE_INDEX_WIDTH = 6,
    // Pipeline setting
    parameter PIPELINE = 3,
    // Scheduler TDMA index width
    parameter TDMA_INDEX_WIDTH = 8,
    // PTP timestamp width
    parameter PTP_TS_WIDTH = 96,
    // Max transmit packet size
    parameter MAX_TX_SIZE = 2048
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
    output wire [REQ_TAG_WIDTH-1:0]      m_axis_tx_req_tag,
    output wire                          m_axis_tx_req_valid,
    input  wire                          m_axis_tx_req_ready,

    /*
     * Transmit request status input
     */
    input  wire [LEN_WIDTH-1:0]          s_axis_tx_req_status_len,
    input  wire [REQ_TAG_WIDTH-1:0]      s_axis_tx_req_status_tag,
    input  wire                          s_axis_tx_req_status_valid,

    /*
     * TX doorbell input
     */
    input  wire [QUEUE_INDEX_WIDTH-1:0]  s_axis_doorbell_queue,
    input  wire                          s_axis_doorbell_valid,

    /*
     * PTP clock
     */
    input  wire [PTP_TS_WIDTH-1:0]       ptp_ts_96,
    input  wire                          ptp_ts_step
);

parameter SCHED_COUNT = 1;
parameter AXIL_SCHED_ADDR_WIDTH = AXIL_ADDR_WIDTH-$clog2(SCHED_COUNT);

// control registers
reg ctrl_reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = 0;
reg ctrl_reg_rd_ack_reg = 1'b0;

reg sched_enable_reg = 1'b0;

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
            16'h0040: begin
                // Scheduler enable
                if (ctrl_reg_wr_strb[0]) begin
                    sched_enable_reg <= ctrl_reg_wr_data[0];
                end
            end
            default: ctrl_reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (ctrl_reg_rd_en && !ctrl_reg_rd_ack_reg) begin
        // read operation
        ctrl_reg_rd_ack_reg <= 1'b1;
        case ({ctrl_reg_rd_addr >> 2, 2'b00})
            16'h0010: ctrl_reg_rd_data_reg <= SCHED_COUNT; // scheduler_count
            16'h0014: ctrl_reg_rd_data_reg <= AXIL_OFFSET; // scheduler_offset
            16'h0018: ctrl_reg_rd_data_reg <= 2**AXIL_SCHED_ADDR_WIDTH; // scheduler_stride
            16'h001C: ctrl_reg_rd_data_reg <= 32'd0;       // scheduler_type
            16'h0040: begin
                // Scheduler enable
                ctrl_reg_rd_data_reg[0] <= sched_enable_reg;
            end
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        sched_enable_reg <= 1'b0;
    end
end

tx_scheduler_rr #(
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_SCHED_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(OP_TABLE_SIZE),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .PIPELINE(PIPELINE),
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
