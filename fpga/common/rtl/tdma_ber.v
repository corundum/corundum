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
 * TDMA BER module
 */
module tdma_ber #
(
    // Channel count
    parameter COUNT = 1,
    // Timeslot index width
    parameter INDEX_WIDTH = 6,
    // Slice index width
    parameter SLICE_WIDTH = 5,
    // Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = INDEX_WIDTH+4+1+$clog2(COUNT),
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // Schedule absolute PTP start time, seconds part
    parameter SCHEDULE_START_S = 48'h0,
    // Schedule absolute PTP start time, nanoseconds part
    parameter SCHEDULE_START_NS = 30'h0,
    // Schedule period, seconds part
    parameter SCHEDULE_PERIOD_S = 48'd0,
    // Schedule period, nanoseconds part
    parameter SCHEDULE_PERIOD_NS = 30'd1000000,
    // Timeslot period, seconds part
    parameter TIMESLOT_PERIOD_S = 48'd0,
    // Timeslot period, nanoseconds part
    parameter TIMESLOT_PERIOD_NS = 30'd100000,
    // Timeslot active period, seconds part
    parameter ACTIVE_PERIOD_S = 48'd0,
    // Timeslot active period, nanoseconds part
    parameter ACTIVE_PERIOD_NS = 30'd100000
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * PHY connections
     */
    input  wire [COUNT-1:0]            phy_tx_clk,
    input  wire [COUNT-1:0]            phy_rx_clk,
    input  wire [COUNT*7-1:0]          phy_rx_error_count,
    output wire [COUNT-1:0]            phy_tx_prbs31_enable,
    output wire [COUNT-1:0]            phy_rx_prbs31_enable,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]                  s_axil_awprot,
    input  wire                        s_axil_awvalid,
    output wire                        s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                        s_axil_wvalid,
    output wire                        s_axil_wready,
    output wire [1:0]                  s_axil_bresp,
    output wire                        s_axil_bvalid,
    input  wire                        s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]                  s_axil_arprot,
    input  wire                        s_axil_arvalid,
    output wire                        s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]                  s_axil_rresp,
    output wire                        s_axil_rvalid,
    input  wire                        s_axil_rready,

    /*
     * PTP clock
     */
    input  wire [95:0]                 ptp_ts_96,
    input  wire                        ptp_ts_step
);

// check configuration
initial begin
    if (AXIL_ADDR_WIDTH < INDEX_WIDTH+4+1+$clog2(COUNT)) begin
        $error("Error: AXI address width too narrow (instance %m)");
        $finish;
    end

    if (AXIL_DATA_WIDTH != 32) begin
        $error("Error: AXI data width must be 32 (instance %m)");
        $finish;
    end

    if (AXIL_STRB_WIDTH * 8 != AXIL_DATA_WIDTH) begin
        $error("Error: Interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

wire [AXIL_ADDR_WIDTH-1:0] axil_csr_awaddr;
wire [2:0]                 axil_csr_awprot;
wire                       axil_csr_awvalid;
wire                       axil_csr_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_csr_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_csr_wstrb;
wire                       axil_csr_wvalid;
wire                       axil_csr_wready;
wire [1:0]                 axil_csr_bresp;
wire                       axil_csr_bvalid;
wire                       axil_csr_bready;
wire [AXIL_ADDR_WIDTH-1:0] axil_csr_araddr;
wire [2:0]                 axil_csr_arprot;
wire                       axil_csr_arvalid;
wire                       axil_csr_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_csr_rdata;
wire [1:0]                 axil_csr_rresp;
wire                       axil_csr_rvalid;
wire                       axil_csr_rready;

// control registers
reg axil_csr_awready_reg = 1'b0;
reg axil_csr_wready_reg = 1'b0;
reg axil_csr_bvalid_reg = 1'b0;
reg axil_csr_arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] axil_csr_rdata_reg = {AXIL_DATA_WIDTH{1'b0}};
reg axil_csr_rvalid_reg = 1'b0;

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

wire tdma_schedule_start;
wire [INDEX_WIDTH-1:0] tdma_timeslot_index;
wire tdma_timeslot_start;
wire tdma_timeslot_end;
wire tdma_timeslot_active;

assign axil_csr_awready = axil_csr_awready_reg;
assign axil_csr_wready = axil_csr_wready_reg;
assign axil_csr_bresp = 2'b00;
assign axil_csr_bvalid = axil_csr_bvalid_reg;
assign axil_csr_arready = axil_csr_arready_reg;
assign axil_csr_rdata = axil_csr_rdata_reg;
assign axil_csr_rresp = 2'b00;
assign axil_csr_rvalid = axil_csr_rvalid_reg;

always @(posedge clk) begin
    axil_csr_awready_reg <= 1'b0;
    axil_csr_wready_reg <= 1'b0;
    axil_csr_bvalid_reg <= axil_csr_bvalid_reg && !axil_csr_bready;
    axil_csr_arready_reg <= 1'b0;
    axil_csr_rvalid_reg <= axil_csr_rvalid_reg && !axil_csr_rready;

    set_tdma_schedule_start_valid_reg <= 1'b0;
    set_tdma_schedule_period_valid_reg <= 1'b0;
    set_tdma_timeslot_period_valid_reg <= 1'b0;
    set_tdma_active_period_valid_reg <= 1'b0;

    if (axil_csr_awvalid && axil_csr_wvalid && !axil_csr_bvalid) begin
        // write operation
        axil_csr_awready_reg <= 1'b1;
        axil_csr_wready_reg <= 1'b1;
        axil_csr_bvalid_reg <= 1'b1;

        case (axil_csr_awaddr & ({AXIL_ADDR_WIDTH{1'b1}} << 2))
            16'h0100: begin
                // TDMA control
                tdma_enable_reg <= axil_csr_wdata[0];
            end
            16'h0114: set_tdma_schedule_start_reg[29:0] <= axil_csr_wdata; // TDMA schedule start ns
            16'h0118: set_tdma_schedule_start_reg[63:32] <= axil_csr_wdata; // TDMA schedule start sec l
            16'h011C: begin
                // TDMA schedule start sec h
                set_tdma_schedule_start_reg[79:64] <= axil_csr_wdata;
                set_tdma_schedule_start_valid_reg <= 1'b1;
            end
            16'h0124: set_tdma_schedule_period_reg[29:0] <= axil_csr_wdata; // TDMA schedule period ns
            16'h0128: set_tdma_schedule_period_reg[63:32] <= axil_csr_wdata; // TDMA schedule period sec l
            16'h012C: begin
                // TDMA schedule period sec h
                set_tdma_schedule_period_reg[79:64] <= axil_csr_wdata;
                set_tdma_schedule_period_valid_reg <= 1'b1;
            end
            16'h0134: set_tdma_timeslot_period_reg[29:0] <= axil_csr_wdata; // TDMA timeslot period ns
            16'h0138: set_tdma_timeslot_period_reg[63:32] <= axil_csr_wdata; // TDMA timeslot period sec l
            16'h013C: begin
                // TDMA timeslot period sec h
                set_tdma_timeslot_period_reg[79:64] <= axil_csr_wdata;
                set_tdma_timeslot_period_valid_reg <= 1'b1;
            end
            16'h0144: set_tdma_active_period_reg[29:0] <= axil_csr_wdata; // TDMA active period ns
            16'h0148: set_tdma_active_period_reg[63:32] <= axil_csr_wdata; // TDMA active period sec l
            16'h014C: begin
                // TDMA active period sec h
                set_tdma_active_period_reg[79:64] <= axil_csr_wdata;
                set_tdma_active_period_valid_reg <= 1'b1;
            end
        endcase
    end

    if (axil_csr_arvalid && !axil_csr_rvalid) begin
        // read operation
        axil_csr_arready_reg <= 1'b1;
        axil_csr_rvalid_reg <= 1'b1;
        axil_csr_rdata_reg <= {AXIL_DATA_WIDTH{1'b0}};

        case (axil_csr_araddr & ({AXIL_ADDR_WIDTH{1'b1}} << 2))
            16'h0000: axil_csr_rdata_reg <= 0;
            16'h0010: axil_csr_rdata_reg <= COUNT;
            16'h0014: axil_csr_rdata_reg <= INDEX_WIDTH;
            16'h0018: axil_csr_rdata_reg <= SLICE_WIDTH;
            16'h0100: begin
                // TDMA control
                axil_csr_rdata_reg[0] <= tdma_enable_reg;
            end
            16'h0104: begin
                // TDMA status
                axil_csr_rdata_reg[0] <= tdma_locked;
                axil_csr_rdata_reg[1] <= tdma_error;
            end
            16'h0114: axil_csr_rdata_reg <= set_tdma_schedule_start_reg[29:0]; // TDMA schedule start ns
            16'h0118: axil_csr_rdata_reg <= set_tdma_schedule_start_reg[63:32]; // TDMA schedule start sec l
            16'h011C: axil_csr_rdata_reg <= set_tdma_schedule_start_reg[79:64]; // TDMA schedule start sec h
            16'h0124: axil_csr_rdata_reg <= set_tdma_schedule_period_reg[29:0]; // TDMA schedule period ns
            16'h0128: axil_csr_rdata_reg <= set_tdma_schedule_period_reg[63:32]; // TDMA schedule period sec l
            16'h012C: axil_csr_rdata_reg <= set_tdma_schedule_period_reg[79:64]; // TDMA schedule period sec h
            16'h0134: axil_csr_rdata_reg <= set_tdma_timeslot_period_reg[29:0]; // TDMA timeslot period ns
            16'h0138: axil_csr_rdata_reg <= set_tdma_timeslot_period_reg[63:32]; // TDMA timeslot period sec l
            16'h013C: axil_csr_rdata_reg <= set_tdma_timeslot_period_reg[79:64]; // TDMA timeslot period sec h
            16'h0144: axil_csr_rdata_reg <= set_tdma_active_period_reg[29:0]; // TDMA active period ns
            16'h0148: axil_csr_rdata_reg <= set_tdma_active_period_reg[63:32]; // TDMA active period sec l
            16'h014C: axil_csr_rdata_reg <= set_tdma_active_period_reg[79:64]; // TDMA active period sec h
        endcase
    end

    if (rst) begin
        axil_csr_awready_reg <= 1'b0;
        axil_csr_wready_reg <= 1'b0;
        axil_csr_bvalid_reg <= 1'b0;
        axil_csr_arready_reg <= 1'b0;
        axil_csr_rvalid_reg <= 1'b0;

        tdma_enable_reg <= 1'b0;
    end
end

tdma_scheduler #(
    .INDEX_WIDTH(INDEX_WIDTH),
    .SCHEDULE_START_S(SCHEDULE_START_S),
    .SCHEDULE_START_NS(SCHEDULE_START_NS),
    .SCHEDULE_PERIOD_S(SCHEDULE_PERIOD_S),
    .SCHEDULE_PERIOD_NS(SCHEDULE_PERIOD_NS),
    .TIMESLOT_PERIOD_S(TIMESLOT_PERIOD_S),
    .TIMESLOT_PERIOD_NS(TIMESLOT_PERIOD_NS),
    .ACTIVE_PERIOD_S(ACTIVE_PERIOD_S),
    .ACTIVE_PERIOD_NS(ACTIVE_PERIOD_NS)
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

wire [COUNT*AXIL_ADDR_WIDTH-1:0] axil_ch_awaddr;
wire [COUNT*3-1:0]               axil_ch_awprot;
wire [COUNT-1:0]                 axil_ch_awvalid;
wire [COUNT-1:0]                 axil_ch_awready;
wire [COUNT*AXIL_DATA_WIDTH-1:0] axil_ch_wdata;
wire [COUNT*AXIL_STRB_WIDTH-1:0] axil_ch_wstrb;
wire [COUNT-1:0]                 axil_ch_wvalid;
wire [COUNT-1:0]                 axil_ch_wready;
wire [COUNT*2-1:0]               axil_ch_bresp;
wire [COUNT-1:0]                 axil_ch_bvalid;
wire [COUNT-1:0]                 axil_ch_bready;
wire [COUNT*AXIL_ADDR_WIDTH-1:0] axil_ch_araddr;
wire [COUNT*3-1:0]               axil_ch_arprot;
wire [COUNT-1:0]                 axil_ch_arvalid;
wire [COUNT-1:0]                 axil_ch_arready;
wire [COUNT*AXIL_DATA_WIDTH-1:0] axil_ch_rdata;
wire [COUNT*2-1:0]               axil_ch_rresp;
wire [COUNT-1:0]                 axil_ch_rvalid;
wire [COUNT-1:0]                 axil_ch_rready;

parameter CH_ADDR_WIDTH = INDEX_WIDTH+4;
parameter CH_BASE_ADDR_WIDTH = (COUNT+1)*AXIL_ADDR_WIDTH;
parameter CH_BASE_ADDR = calcBaseAddrs(CH_ADDR_WIDTH);

function [CH_BASE_ADDR_WIDTH-1:0] calcBaseAddrs(input [31:0] width);
    integer i;
    begin
        calcBaseAddrs = {CH_BASE_ADDR_WIDTH{1'b0}};
        for (i = 0; i < COUNT+1; i = i + 1) begin
            calcBaseAddrs[i * AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH] = i * (2**width);
        end
    end
endfunction

function [31:0] w_32(input [31:0] val);
    w_32 = val;
endfunction

axil_interconnect #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .S_COUNT(1),
    .M_COUNT(COUNT+1),
    .M_BASE_ADDR(CH_BASE_ADDR),
    .M_ADDR_WIDTH({COUNT+1{w_32(CH_ADDR_WIDTH)}}),
    .M_CONNECT_READ({COUNT+1{1'b1}}),
    .M_CONNECT_WRITE({COUNT+1{1'b1}})
)
axil_csr_interconnect_inst (
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
    .m_axil_awaddr(  {axil_ch_awaddr,  axil_csr_awaddr}),
    .m_axil_awprot(  {axil_ch_awprot,  axil_csr_awprot}),
    .m_axil_awvalid( {axil_ch_awvalid, axil_csr_awvalid}),
    .m_axil_awready( {axil_ch_awready, axil_csr_awready}),
    .m_axil_wdata(   {axil_ch_wdata,   axil_csr_wdata}),
    .m_axil_wstrb(   {axil_ch_wstrb,   axil_csr_wstrb}),
    .m_axil_wvalid(  {axil_ch_wvalid,  axil_csr_wvalid}),
    .m_axil_wready(  {axil_ch_wready,  axil_csr_wready}),
    .m_axil_bresp(   {axil_ch_bresp,   axil_csr_bresp}),
    .m_axil_bvalid(  {axil_ch_bvalid,  axil_csr_bvalid}),
    .m_axil_bready(  {axil_ch_bready,  axil_csr_bready}),
    .m_axil_araddr(  {axil_ch_araddr,  axil_csr_araddr}),
    .m_axil_arprot(  {axil_ch_arprot,  axil_csr_arprot}),
    .m_axil_arvalid( {axil_ch_arvalid, axil_csr_arvalid}),
    .m_axil_arready( {axil_ch_arready, axil_csr_arready}),
    .m_axil_rdata(   {axil_ch_rdata,   axil_csr_rdata}),
    .m_axil_rresp(   {axil_ch_rresp,   axil_csr_rresp}),
    .m_axil_rvalid(  {axil_ch_rvalid,  axil_csr_rvalid}),
    .m_axil_rready(  {axil_ch_rready,  axil_csr_rready})
);

generate
    genvar n;

    for (n = 0; n < COUNT; n = n + 1) begin
        
        tdma_ber_ch #(
            .INDEX_WIDTH(INDEX_WIDTH),
            .SLICE_WIDTH(SLICE_WIDTH),
            .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
            .AXIL_ADDR_WIDTH(CH_ADDR_WIDTH),
            .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
        )
        tdma_ber_ch_inst (
            .clk(clk),
            .rst(rst),
            .phy_tx_clk(phy_tx_clk[n]),
            .phy_rx_clk(phy_rx_clk[n]),
            .phy_rx_error_count(phy_rx_error_count[n*7 +: 7]),
            .phy_tx_prbs31_enable(phy_tx_prbs31_enable[n]),
            .phy_rx_prbs31_enable(phy_rx_prbs31_enable[n]),
            .s_axil_awaddr(axil_ch_awaddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_awprot(axil_ch_awprot[n*3 +: 3]),
            .s_axil_awvalid(axil_ch_awvalid[n]),
            .s_axil_awready(axil_ch_awready[n]),
            .s_axil_wdata(axil_ch_wdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_wstrb(axil_ch_wstrb[n*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
            .s_axil_wvalid(axil_ch_wvalid[n]),
            .s_axil_wready(axil_ch_wready[n]),
            .s_axil_bresp(axil_ch_bresp[n*2 +: 2]),
            .s_axil_bvalid(axil_ch_bvalid[n]),
            .s_axil_bready(axil_ch_bready[n]),
            .s_axil_araddr(axil_ch_araddr[n*AXIL_ADDR_WIDTH +: AXIL_ADDR_WIDTH]),
            .s_axil_arprot(axil_ch_arprot[n*3 +: 3]),
            .s_axil_arvalid(axil_ch_arvalid[n]),
            .s_axil_arready(axil_ch_arready[n]),
            .s_axil_rdata(axil_ch_rdata[n*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
            .s_axil_rresp(axil_ch_rresp[n*2 +: 2]),
            .s_axil_rvalid(axil_ch_rvalid[n]),
            .s_axil_rready(axil_ch_rready[n]),
            .tdma_timeslot_index(tdma_timeslot_index),
            .tdma_timeslot_start(tdma_timeslot_start),
            .tdma_timeslot_active(tdma_timeslot_active)
        );

    end
endgenerate

endmodule

`resetall
