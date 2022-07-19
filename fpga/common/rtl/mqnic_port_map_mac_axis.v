/*

Copyright 2022, The Regents of the University of California.
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
 * Port map module for AXI stream MACs
 */
module mqnic_port_map_mac_axis #
(
    parameter MAC_COUNT = 4,
    parameter PORT_MASK = 0,
    parameter PORT_GROUP_SIZE = 1,

    parameter IF_COUNT = 1,
    parameter PORTS_PER_IF = 4,

    parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF,

    parameter PTP_TS_WIDTH = 96,
    parameter PTP_TAG_WIDTH = 16,
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_TX_USER_WIDTH = PTP_TAG_WIDTH + 1,
    parameter AXIS_RX_USER_WIDTH = PTP_TS_WIDTH + 1
)
(
    // towards MAC
    input  wire [MAC_COUNT-1:0]                      mac_tx_clk,
    input  wire [MAC_COUNT-1:0]                      mac_tx_rst,

    input  wire [MAC_COUNT-1:0]                      mac_tx_ptp_clk,
    input  wire [MAC_COUNT-1:0]                      mac_tx_ptp_rst,
    output wire [MAC_COUNT*PTP_TS_WIDTH-1:0]         mac_tx_ptp_ts_96,
    output wire [MAC_COUNT-1:0]                      mac_tx_ptp_ts_step,

    output wire [MAC_COUNT*AXIS_DATA_WIDTH-1:0]      m_axis_mac_tx_tdata,
    output wire [MAC_COUNT*AXIS_KEEP_WIDTH-1:0]      m_axis_mac_tx_tkeep,
    output wire [MAC_COUNT-1:0]                      m_axis_mac_tx_tvalid,
    input  wire [MAC_COUNT-1:0]                      m_axis_mac_tx_tready,
    output wire [MAC_COUNT-1:0]                      m_axis_mac_tx_tlast,
    output wire [MAC_COUNT*AXIS_TX_USER_WIDTH-1:0]   m_axis_mac_tx_tuser,

    input  wire [MAC_COUNT*PTP_TS_WIDTH-1:0]         s_axis_mac_tx_ptp_ts,
    input  wire [MAC_COUNT*PTP_TAG_WIDTH-1:0]        s_axis_mac_tx_ptp_ts_tag,
    input  wire [MAC_COUNT-1:0]                      s_axis_mac_tx_ptp_ts_valid,
    output wire [MAC_COUNT-1:0]                      s_axis_mac_tx_ptp_ts_ready,

    input  wire [MAC_COUNT-1:0]                      mac_tx_status,

    input  wire [MAC_COUNT-1:0]                      mac_rx_clk,
    input  wire [MAC_COUNT-1:0]                      mac_rx_rst,

    input  wire [MAC_COUNT-1:0]                      mac_rx_ptp_clk,
    input  wire [MAC_COUNT-1:0]                      mac_rx_ptp_rst,
    output wire [MAC_COUNT*PTP_TS_WIDTH-1:0]         mac_rx_ptp_ts_96,
    output wire [MAC_COUNT-1:0]                      mac_rx_ptp_ts_step,

    input  wire [MAC_COUNT*AXIS_DATA_WIDTH-1:0]      s_axis_mac_rx_tdata,
    input  wire [MAC_COUNT*AXIS_KEEP_WIDTH-1:0]      s_axis_mac_rx_tkeep,
    input  wire [MAC_COUNT-1:0]                      s_axis_mac_rx_tvalid,
    output wire [MAC_COUNT-1:0]                      s_axis_mac_rx_tready,
    input  wire [MAC_COUNT-1:0]                      s_axis_mac_rx_tlast,
    input  wire [MAC_COUNT*AXIS_RX_USER_WIDTH-1:0]   s_axis_mac_rx_tuser,

    input  wire [MAC_COUNT-1:0]                      mac_rx_status,

    // towards datapath
    output wire [PORT_COUNT-1:0]                     tx_clk,
    output wire [PORT_COUNT-1:0]                     tx_rst,

    output wire [PORT_COUNT-1:0]                     tx_ptp_clk,
    output wire [PORT_COUNT-1:0]                     tx_ptp_rst,
    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]        tx_ptp_ts_96,
    input  wire [PORT_COUNT-1:0]                     tx_ptp_ts_step,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]     s_axis_tx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]     s_axis_tx_tkeep,
    input  wire [PORT_COUNT-1:0]                     s_axis_tx_tvalid,
    output wire [PORT_COUNT-1:0]                     s_axis_tx_tready,
    input  wire [PORT_COUNT-1:0]                     s_axis_tx_tlast,
    input  wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]  s_axis_tx_tuser,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]        m_axis_tx_ptp_ts,
    output wire [PORT_COUNT*PTP_TAG_WIDTH-1:0]       m_axis_tx_ptp_ts_tag,
    output wire [PORT_COUNT-1:0]                     m_axis_tx_ptp_ts_valid,
    input  wire [PORT_COUNT-1:0]                     m_axis_tx_ptp_ts_ready,

    output wire [PORT_COUNT-1:0]                     tx_status,

    output wire [PORT_COUNT-1:0]                     rx_clk,
    output wire [PORT_COUNT-1:0]                     rx_rst,

    output wire [PORT_COUNT-1:0]                     rx_ptp_clk,
    output wire [PORT_COUNT-1:0]                     rx_ptp_rst,
    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]        rx_ptp_ts_96,
    input  wire [PORT_COUNT-1:0]                     rx_ptp_ts_step,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]     m_axis_rx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]     m_axis_rx_tkeep,
    output wire [PORT_COUNT-1:0]                     m_axis_rx_tvalid,
    input  wire [PORT_COUNT-1:0]                     m_axis_rx_tready,
    output wire [PORT_COUNT-1:0]                     m_axis_rx_tlast,
    output wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]  m_axis_rx_tuser,

    output wire [PORT_COUNT-1:0]                     rx_status
);

initial begin
    if (PORT_COUNT > MAC_COUNT) begin
        $error("Error: Requested port count out of range (instance %m)");
        $finish;
    end
end

function [MAC_COUNT-1:0] calcMask(input [31:0] if_count, input [31:0] ports_per_if, input [31:0] group_size);
    integer iface, port, mac;
    begin
        mac = 0;
        calcMask = 0;
        if (if_count*ports_per_if*group_size <= MAC_COUNT) begin
            // all ports in their own group
            for (port = 0; port < if_count*ports_per_if; port = port + 1) begin
                calcMask[mac] = 1'b1;
                mac = mac + group_size;
            end
        end else if (if_count*((ports_per_if+group_size-1)/group_size)*group_size <= MAC_COUNT) begin
            // pack ports on each interface, each interface starts on a group boundary
            for (iface = 0; iface < if_count; iface = iface + 1) begin
                for (port = 0; port < ports_per_if; port = port + 1) begin
                    calcMask[mac] = 1'b1;
                    mac = mac + 1;
                end
                if (mac % group_size > 0) begin
                    mac = mac + group_size - (mac % group_size);
                end
            end
        end else begin
            // pack everything
            calcMask = {MAC_COUNT{1'b1}};
        end
    end
endfunction

localparam PORT_MASK_INT = PORT_MASK ? PORT_MASK : calcMask(IF_COUNT, PORTS_PER_IF, PORT_GROUP_SIZE);

function [MAC_COUNT*8-1:0] calcIndices(input [MAC_COUNT-1:0] mask);
    integer port, mac;
    begin
        port = 0;
        calcIndices = {MAC_COUNT*8{1'b1}};
        for (mac = 0; mac < MAC_COUNT; mac = mac + 1) begin
            if (mask[mac] && port < PORT_COUNT) begin
                calcIndices[mac*8 +: 8] = port;
                port = port + 1;
            end else begin
                calcIndices[mac*8 +: 8] = 8'hff;
            end
        end

        if (port < PORT_COUNT) begin
            // invalid mask - not enough set bits
            calcIndices = {MAC_COUNT*8{1'b1}};
        end
    end
endfunction

localparam IND = calcIndices(PORT_MASK_INT);

initial begin
    if (&IND) begin
        $error("Error: Invalid mask (%x) for requested port count (%d) (instance %m)", PORT_MASK_INT, PORT_COUNT);
        $finish;
    end
end

generate
    genvar n;

    for (n = 0; n < MAC_COUNT; n = n + 1) begin : mac
        if (IND[n*8 +: 8] != 8'hff) begin
            assign tx_clk[IND[n*8 +: 8]] = mac_tx_clk[n];
            assign tx_rst[IND[n*8 +: 8]] = mac_tx_rst[n];

            assign m_axis_mac_tx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH] = s_axis_tx_tdata[IND[n*8 +: 8]*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];
            assign m_axis_mac_tx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH] = s_axis_tx_tkeep[IND[n*8 +: 8]*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH];
            assign m_axis_mac_tx_tvalid[n] = s_axis_tx_tvalid[IND[n*8 +: 8]];
            assign s_axis_tx_tready[IND[n*8 +: 8]] = m_axis_mac_tx_tready[n];
            assign m_axis_mac_tx_tlast[n] = s_axis_tx_tlast[IND[n*8 +: 8]];
            assign m_axis_mac_tx_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH] = s_axis_tx_tuser[IND[n*8 +: 8]*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH];

            assign m_axis_tx_ptp_ts[IND[n*8 +: 8]*PTP_TS_WIDTH +: PTP_TS_WIDTH] = s_axis_mac_tx_ptp_ts[n*PTP_TS_WIDTH +: PTP_TS_WIDTH];
            assign m_axis_tx_ptp_ts_tag[IND[n*8 +: 8]*PTP_TAG_WIDTH +: PTP_TAG_WIDTH] = s_axis_mac_tx_ptp_ts_tag[n*PTP_TAG_WIDTH +: PTP_TAG_WIDTH];
            assign m_axis_tx_ptp_ts_valid[IND[n*8 +: 8]] = s_axis_mac_tx_ptp_ts_valid[n];

            assign tx_ptp_clk[IND[n*8 +: 8]] = mac_tx_ptp_clk[n];
            assign tx_ptp_rst[IND[n*8 +: 8]] = mac_tx_ptp_rst[n];

            assign mac_tx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH] = tx_ptp_ts_96[IND[n*8 +: 8]*PTP_TS_WIDTH +: PTP_TS_WIDTH];
            assign mac_tx_ptp_ts_step[n] = tx_ptp_ts_step[IND[n*8 +: 8]];

            assign tx_status[IND[n*8 +: 8]] = mac_tx_status[n];

            assign rx_clk[IND[n*8 +: 8]] = mac_rx_clk[n];
            assign rx_rst[IND[n*8 +: 8]] = mac_rx_rst[n];

            assign m_axis_rx_tdata[IND[n*8 +: 8]*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH] = s_axis_mac_rx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH];
            assign m_axis_rx_tkeep[IND[n*8 +: 8]*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH] = s_axis_mac_rx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH];
            assign m_axis_rx_tvalid[IND[n*8 +: 8]] = s_axis_mac_rx_tvalid[n];
            assign s_axis_mac_rx_tready[n] = m_axis_rx_tready[IND[n*8 +: 8]];
            assign m_axis_rx_tlast[IND[n*8 +: 8]] = s_axis_mac_rx_tlast[n];
            assign m_axis_rx_tuser[IND[n*8 +: 8]*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH] = s_axis_mac_rx_tuser[n*AXIS_RX_USER_WIDTH +: AXIS_RX_USER_WIDTH];

            assign rx_ptp_clk[IND[n*8 +: 8]] = mac_rx_ptp_clk[n];
            assign rx_ptp_rst[IND[n*8 +: 8]] = mac_rx_ptp_rst[n];

            assign mac_rx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH] = rx_ptp_ts_96[IND[n*8 +: 8]*PTP_TS_WIDTH +: PTP_TS_WIDTH];
            assign mac_rx_ptp_ts_step[n] = rx_ptp_ts_step[IND[n*8 +: 8]];

            assign rx_status[IND[n*8 +: 8]] = mac_rx_status[n];
        end else begin
            assign m_axis_mac_tx_tdata[n*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH] = {AXIS_DATA_WIDTH{1'b0}};
            assign m_axis_mac_tx_tkeep[n*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH] = {AXIS_KEEP_WIDTH{1'b0}};
            assign m_axis_mac_tx_tvalid[n] = 1'b0;
            assign m_axis_mac_tx_tlast[n] = 1'b0;
            assign m_axis_mac_tx_tuser[n*AXIS_TX_USER_WIDTH +: AXIS_TX_USER_WIDTH] = {AXIS_TX_USER_WIDTH{1'b0}};

            assign mac_tx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {PTP_TS_WIDTH{1'b0}};
            assign mac_tx_ptp_ts_step[n] = 1'b0;

            assign mac_rx_ptp_ts_96[n*PTP_TS_WIDTH +: PTP_TS_WIDTH] = {PTP_TS_WIDTH{1'b0}};
            assign mac_rx_ptp_ts_step[n] = 1'b0;
        end
    end
endgenerate

endmodule

`resetall
