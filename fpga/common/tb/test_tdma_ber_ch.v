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
 * Testbench for tdma_ber_ch
 */
module test_tdma_ber_ch;

// Parameters
parameter INDEX_WIDTH = 6;
parameter SLICE_WIDTH = 5;
parameter AXIL_DATA_WIDTH = 32;
parameter AXIL_ADDR_WIDTH = INDEX_WIDTH+4;
parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8);

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg phy_tx_clk = 0;
reg phy_rx_clk = 0;
reg [6:0] phy_rx_error_count = 0;
reg [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr = 0;
reg [2:0] s_axil_awprot = 0;
reg s_axil_awvalid = 0;
reg [AXIL_DATA_WIDTH-1:0] s_axil_wdata = 0;
reg [AXIL_STRB_WIDTH-1:0] s_axil_wstrb = 0;
reg s_axil_wvalid = 0;
reg s_axil_bready = 0;
reg [AXIL_ADDR_WIDTH-1:0] s_axil_araddr = 0;
reg [2:0] s_axil_arprot = 0;
reg s_axil_arvalid = 0;
reg s_axil_rready = 0;
reg [INDEX_WIDTH-1:0] tdma_timeslot_index = 0;
reg tdma_timeslot_start = 0;
reg tdma_timeslot_active = 0;

// Outputs
wire phy_tx_prbs31_enable;
wire phy_rx_prbs31_enable;
wire s_axil_awready;
wire s_axil_wready;
wire [1:0] s_axil_bresp;
wire s_axil_bvalid;
wire s_axil_arready;
wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata;
wire [1:0] s_axil_rresp;
wire s_axil_rvalid;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        phy_tx_clk,
        phy_rx_clk,
        phy_rx_error_count,
        s_axil_awaddr,
        s_axil_awprot,
        s_axil_awvalid,
        s_axil_wdata,
        s_axil_wstrb,
        s_axil_wvalid,
        s_axil_bready,
        s_axil_araddr,
        s_axil_arprot,
        s_axil_arvalid,
        s_axil_rready,
        tdma_timeslot_index,
        tdma_timeslot_start,
        tdma_timeslot_active
    );
    $to_myhdl(
        phy_tx_prbs31_enable,
        phy_rx_prbs31_enable,
        s_axil_awready,
        s_axil_wready,
        s_axil_bresp,
        s_axil_bvalid,
        s_axil_arready,
        s_axil_rdata,
        s_axil_rresp,
        s_axil_rvalid
    );

    // dump file
    $dumpfile("test_tdma_ber_ch.lxt");
    $dumpvars(0, test_tdma_ber_ch);
end

tdma_ber_ch #(
    .INDEX_WIDTH(INDEX_WIDTH),
    .SLICE_WIDTH(SLICE_WIDTH),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH)
)
UUT (
    .clk(clk),
    .rst(rst),
    .phy_tx_clk(phy_tx_clk),
    .phy_rx_clk(phy_rx_clk),
    .phy_rx_error_count(phy_rx_error_count),
    .phy_tx_prbs31_enable(phy_tx_prbs31_enable),
    .phy_rx_prbs31_enable(phy_rx_prbs31_enable),
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
    .tdma_timeslot_index(tdma_timeslot_index),
    .tdma_timeslot_start(tdma_timeslot_start),
    .tdma_timeslot_active(tdma_timeslot_active)
);

endmodule
