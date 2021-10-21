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
 * TX scheduler block (round-robin TDMA)
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

parameter SCHED_COUNT = 2;
parameter AXIL_SCHED_ADDR_WIDTH = AXIL_ADDR_WIDTH-$clog2(SCHED_COUNT);

// parameter sizing helpers
function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

// AXI lite connections
wire [SCHED_COUNT*AXIL_ADDR_WIDTH-1:0] axil_sched_awaddr;
wire [SCHED_COUNT*3-1:0]               axil_sched_awprot;
wire [SCHED_COUNT-1:0]                 axil_sched_awvalid;
wire [SCHED_COUNT-1:0]                 axil_sched_awready;
wire [SCHED_COUNT*AXIL_DATA_WIDTH-1:0] axil_sched_wdata;
wire [SCHED_COUNT*AXIL_STRB_WIDTH-1:0] axil_sched_wstrb;
wire [SCHED_COUNT-1:0]                 axil_sched_wvalid;
wire [SCHED_COUNT-1:0]                 axil_sched_wready;
wire [SCHED_COUNT*2-1:0]               axil_sched_bresp;
wire [SCHED_COUNT-1:0]                 axil_sched_bvalid;
wire [SCHED_COUNT-1:0]                 axil_sched_bready;
wire [SCHED_COUNT*AXIL_ADDR_WIDTH-1:0] axil_sched_araddr;
wire [SCHED_COUNT*3-1:0]               axil_sched_arprot;
wire [SCHED_COUNT-1:0]                 axil_sched_arvalid;
wire [SCHED_COUNT-1:0]                 axil_sched_arready;
wire [SCHED_COUNT*AXIL_DATA_WIDTH-1:0] axil_sched_rdata;
wire [SCHED_COUNT*2-1:0]               axil_sched_rresp;
wire [SCHED_COUNT-1:0]                 axil_sched_rvalid;
wire [SCHED_COUNT-1:0]                 axil_sched_rready;

// Scheduler
wire [QUEUE_INDEX_WIDTH-1:0]  tx_sched_ctrl_queue;
wire                          tx_sched_ctrl_enable;
wire                          tx_sched_ctrl_valid;
wire                          tx_sched_ctrl_ready;

wire                          tdma_schedule_start;
wire [TDMA_INDEX_WIDTH-1:0]   tdma_timeslot_index;
wire                          tdma_timeslot_start;
wire                          tdma_timeslot_end;
wire                          tdma_timeslot_active;

// control registers
reg ctrl_reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] ctrl_reg_rd_data_reg = 0;
reg ctrl_reg_rd_ack_reg = 1'b0;

reg sched_enable_reg = 1'b0;

reg tdma_enable_reg = 1'b0;
wire tdma_locked;
wire tdma_error;

reg [79:0] set_tdma_schedule_start_reg = 0;
reg set_tdma_schedule_start_valid_reg = 0;
reg [79:0] set_tdma_schedule_period_reg = 0;
reg set_tdma_schedule_period_valid_reg = 0;
reg [79:0] set_tdma_timeslot_period_reg = 0;
reg set_tdma_timeslot_period_valid_reg = 0;
reg [79:0] set_tdma_active_period_reg = 0;
reg set_tdma_active_period_valid_reg = 0;

assign ctrl_reg_wr_wait = 1'b0;
assign ctrl_reg_wr_ack = ctrl_reg_wr_ack_reg;
assign ctrl_reg_rd_data = ctrl_reg_rd_data_reg;
assign ctrl_reg_rd_wait = 1'b0;
assign ctrl_reg_rd_ack = ctrl_reg_rd_ack_reg;

always @(posedge clk) begin
    ctrl_reg_wr_ack_reg <= 1'b0;
    ctrl_reg_rd_data_reg <= 0;
    ctrl_reg_rd_ack_reg <= 1'b0;

    set_tdma_schedule_start_valid_reg <= 1'b0;
    set_tdma_schedule_period_valid_reg <= 1'b0;
    set_tdma_timeslot_period_valid_reg <= 1'b0;
    set_tdma_active_period_valid_reg <= 1'b0;

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
            16'h1000: begin
                // TDMA control
                if (ctrl_reg_wr_strb[0]) begin
                    tdma_enable_reg <= ctrl_reg_wr_data[0];
                end
            end
            16'h1014: set_tdma_schedule_start_reg[29:0] <= ctrl_reg_wr_data; // TDMA schedule start ns
            16'h1018: set_tdma_schedule_start_reg[63:32] <= ctrl_reg_wr_data; // TDMA schedule start sec l
            16'h101C: begin
                // TDMA schedule start sec h
                set_tdma_schedule_start_reg[79:64] <= ctrl_reg_wr_data;
                set_tdma_schedule_start_valid_reg <= 1'b1;
            end
            16'h1024: set_tdma_schedule_period_reg[29:0] <= ctrl_reg_wr_data; // TDMA schedule period ns
            16'h1028: set_tdma_schedule_period_reg[63:32] <= ctrl_reg_wr_data; // TDMA schedule period sec l
            16'h102C: begin
                // TDMA schedule period sec h
                set_tdma_schedule_period_reg[79:64] <= ctrl_reg_wr_data;
                set_tdma_schedule_period_valid_reg <= 1'b1;
            end
            16'h1034: set_tdma_timeslot_period_reg[29:0] <= ctrl_reg_wr_data; // TDMA timeslot period ns
            16'h1038: set_tdma_timeslot_period_reg[63:32] <= ctrl_reg_wr_data; // TDMA timeslot period sec l
            16'h103C: begin
                // TDMA timeslot period sec h
                set_tdma_timeslot_period_reg[79:64] <= ctrl_reg_wr_data;
                set_tdma_timeslot_period_valid_reg <= 1'b1;
            end
            16'h1044: set_tdma_active_period_reg[29:0] <= ctrl_reg_wr_data; // TDMA active period ns
            16'h1048: set_tdma_active_period_reg[63:32] <= ctrl_reg_wr_data; // TDMA active period sec l
            16'h104C: begin
                // TDMA active period sec h
                set_tdma_active_period_reg[79:64] <= ctrl_reg_wr_data;
                set_tdma_active_period_valid_reg <= 1'b1;
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
            16'h1000: begin
                // TDMA control
                ctrl_reg_rd_data_reg[0] <= tdma_enable_reg;
            end
            16'h1004: begin
                // TDMA status
                ctrl_reg_rd_data_reg[0] <= tdma_locked;
                ctrl_reg_rd_data_reg[1] <= tdma_error;
            end
            16'h1008: ctrl_reg_rd_data_reg <= 2**TDMA_INDEX_WIDTH; // TDMA timeslot count
            16'h1014: ctrl_reg_rd_data_reg <= set_tdma_schedule_start_reg[29:0]; // TDMA schedule start ns
            16'h1018: ctrl_reg_rd_data_reg <= set_tdma_schedule_start_reg[63:32]; // TDMA schedule start sec l
            16'h101C: ctrl_reg_rd_data_reg <= set_tdma_schedule_start_reg[79:64]; // TDMA schedule start sec h
            16'h1024: ctrl_reg_rd_data_reg <= set_tdma_schedule_period_reg[29:0]; // TDMA schedule period ns
            16'h1028: ctrl_reg_rd_data_reg <= set_tdma_schedule_period_reg[63:32]; // TDMA schedule period sec l
            16'h102C: ctrl_reg_rd_data_reg <= set_tdma_schedule_period_reg[79:64]; // TDMA schedule period sec h
            16'h1034: ctrl_reg_rd_data_reg <= set_tdma_timeslot_period_reg[29:0]; // TDMA timeslot period ns
            16'h1038: ctrl_reg_rd_data_reg <= set_tdma_timeslot_period_reg[63:32]; // TDMA timeslot period sec l
            16'h103C: ctrl_reg_rd_data_reg <= set_tdma_timeslot_period_reg[79:64]; // TDMA timeslot period sec h
            16'h1044: ctrl_reg_rd_data_reg <= set_tdma_active_period_reg[29:0]; // TDMA active period ns
            16'h1048: ctrl_reg_rd_data_reg <= set_tdma_active_period_reg[63:32]; // TDMA active period sec l
            16'h104C: ctrl_reg_rd_data_reg <= set_tdma_active_period_reg[79:64]; // TDMA active period sec h
            default: ctrl_reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        ctrl_reg_wr_ack_reg <= 1'b0;
        ctrl_reg_rd_ack_reg <= 1'b0;

        sched_enable_reg <= 1'b0;
    end
end

// AXI lite interconnect
parameter AXIL_S_COUNT = 1;
parameter AXIL_M_COUNT = SCHED_COUNT;

axil_crossbar #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .S_COUNT(AXIL_S_COUNT),
    .M_COUNT(AXIL_M_COUNT),
    .M_ADDR_WIDTH({AXIL_M_COUNT{w_32(AXIL_SCHED_ADDR_WIDTH)}}),
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
    .m_axil_awaddr(axil_sched_awaddr),
    .m_axil_awprot(axil_sched_awprot),
    .m_axil_awvalid(axil_sched_awvalid),
    .m_axil_awready(axil_sched_awready),
    .m_axil_wdata(axil_sched_wdata),
    .m_axil_wstrb(axil_sched_wstrb),
    .m_axil_wvalid(axil_sched_wvalid),
    .m_axil_wready(axil_sched_wready),
    .m_axil_bresp(axil_sched_bresp),
    .m_axil_bvalid(axil_sched_bvalid),
    .m_axil_bready(axil_sched_bready),
    .m_axil_araddr(axil_sched_araddr),
    .m_axil_arprot(axil_sched_arprot),
    .m_axil_arvalid(axil_sched_arvalid),
    .m_axil_arready(axil_sched_arready),
    .m_axil_rdata(axil_sched_rdata),
    .m_axil_rresp(axil_sched_rresp),
    .m_axil_rvalid(axil_sched_rvalid),
    .m_axil_rready(axil_sched_rready)
);

tx_scheduler_rr #(
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_SCHED_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .REQ_TAG_WIDTH(REQ_TAG_WIDTH),
    .OP_TABLE_SIZE(OP_TABLE_SIZE),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .PIPELINE(PIPELINE),
    .SCHED_CTRL_ENABLE(1)
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
    .s_axis_sched_ctrl_queue(tx_sched_ctrl_queue),
    .s_axis_sched_ctrl_enable(tx_sched_ctrl_enable),
    .s_axis_sched_ctrl_valid(tx_sched_ctrl_valid),
    .s_axis_sched_ctrl_ready(tx_sched_ctrl_ready),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_sched_awaddr[0*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
    .s_axil_awprot(axil_sched_awprot[0*3 +: 3]),
    .s_axil_awvalid(axil_sched_awvalid[0*1 +: 1]),
    .s_axil_awready(axil_sched_awready[0*1 +: 1]),
    .s_axil_wdata(axil_sched_wdata[0*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
    .s_axil_wstrb(axil_sched_wstrb[0*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
    .s_axil_wvalid(axil_sched_wvalid[0*1 +: 1]),
    .s_axil_wready(axil_sched_wready[0*1 +: 1]),
    .s_axil_bresp(axil_sched_bresp[0*2 +: 2]),
    .s_axil_bvalid(axil_sched_bvalid[0*1 +: 1]),
    .s_axil_bready(axil_sched_bready[0*1 +: 1]),
    .s_axil_araddr(axil_sched_araddr[0*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
    .s_axil_arprot(axil_sched_arprot[0*3 +: 3]),
    .s_axil_arvalid(axil_sched_arvalid[0*1 +: 1]),
    .s_axil_arready(axil_sched_arready[0*1 +: 1]),
    .s_axil_rdata(axil_sched_rdata[0*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
    .s_axil_rresp(axil_sched_rresp[0*2 +: 2]),
    .s_axil_rvalid(axil_sched_rvalid[0*1 +: 1]),
    .s_axil_rready(axil_sched_rready[0*1 +: 1]),

    /*
     * Control
     */
    .enable(sched_enable_reg),
    .active()
);

tdma_scheduler #(
    .INDEX_WIDTH(TDMA_INDEX_WIDTH),
    .SCHEDULE_START_S(48'h0),
    .SCHEDULE_START_NS(30'h0),
    .SCHEDULE_PERIOD_S(48'd0),
    .SCHEDULE_PERIOD_NS(30'd1000000),
    .TIMESLOT_PERIOD_S(48'd0),
    .TIMESLOT_PERIOD_NS(30'd100000),
    .ACTIVE_PERIOD_S(48'd0),
    .ACTIVE_PERIOD_NS(30'd100000)
)
tdma_scheduler_inst (
    .clk(clk),
    .rst(rst),
    .input_ts_96(ptp_ts_96),
    .input_ts_step(ptp_ts_step),
    .enable(tdma_enable_reg),
    .input_schedule_start(set_tdma_schedule_start_reg),
    .input_schedule_start_valid(set_tdma_schedule_start_valid_reg),
    .input_schedule_period(set_tdma_schedule_period_reg),
    .input_schedule_period_valid(set_tdma_schedule_period_valid_reg),
    .input_timeslot_period(set_tdma_timeslot_period_reg),
    .input_timeslot_period_valid(set_tdma_timeslot_period_valid_reg),
    .input_active_period(set_tdma_active_period_reg),
    .input_active_period_valid(set_tdma_active_period_valid_reg),
    .locked(tdma_locked),
    .error(tdma_error),
    .schedule_start(tdma_schedule_start),
    .timeslot_index(tdma_timeslot_index),
    .timeslot_start(tdma_timeslot_start),
    .timeslot_end(tdma_timeslot_end),
    .timeslot_active(tdma_timeslot_active)
);

tx_scheduler_ctrl_tdma #(
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_SCHED_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .TDMA_INDEX_WIDTH(TDMA_INDEX_WIDTH),
    .QUEUE_INDEX_WIDTH(QUEUE_INDEX_WIDTH),
    .PIPELINE(2)
)
tx_scheduler_ctrl_tdma_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Scheduler control output
     */
    .m_axis_sched_ctrl_queue(tx_sched_ctrl_queue),
    .m_axis_sched_ctrl_enable(tx_sched_ctrl_enable),
    .m_axis_sched_ctrl_valid(tx_sched_ctrl_valid),
    .m_axis_sched_ctrl_ready(tx_sched_ctrl_ready),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(axil_sched_awaddr[1*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
    .s_axil_awprot(axil_sched_awprot[1*3 +: 3]),
    .s_axil_awvalid(axil_sched_awvalid[1*1 +: 1]),
    .s_axil_awready(axil_sched_awready[1*1 +: 1]),
    .s_axil_wdata(axil_sched_wdata[1*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
    .s_axil_wstrb(axil_sched_wstrb[1*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
    .s_axil_wvalid(axil_sched_wvalid[1*1 +: 1]),
    .s_axil_wready(axil_sched_wready[1*1 +: 1]),
    .s_axil_bresp(axil_sched_bresp[1*2 +: 2]),
    .s_axil_bvalid(axil_sched_bvalid[1*1 +: 1]),
    .s_axil_bready(axil_sched_bready[1*1 +: 1]),
    .s_axil_araddr(axil_sched_araddr[1*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
    .s_axil_arprot(axil_sched_arprot[1*3 +: 3]),
    .s_axil_arvalid(axil_sched_arvalid[1*1 +: 1]),
    .s_axil_arready(axil_sched_arready[1*1 +: 1]),
    .s_axil_rdata(axil_sched_rdata[1*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
    .s_axil_rresp(axil_sched_rresp[1*2 +: 2]),
    .s_axil_rvalid(axil_sched_rvalid[1*1 +: 1]),
    .s_axil_rready(axil_sched_rready[1*1 +: 1]),

    /*
     * TDMA schedule inputs
     */
    .tdma_schedule_start(tdma_schedule_start),
    .tdma_timeslot_index(tdma_timeslot_index),
    .tdma_timeslot_start(tdma_timeslot_start),
    .tdma_timeslot_end(tdma_timeslot_end),
    .tdma_timeslot_active(tdma_timeslot_active)
);

endmodule

`resetall
