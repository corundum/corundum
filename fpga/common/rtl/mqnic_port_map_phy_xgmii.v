// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Port map module for XGMII PHYs
 */
module mqnic_port_map_phy_xgmii #
(
    parameter PHY_COUNT = 4,
    parameter PORT_MASK = 0,
    parameter PORT_GROUP_SIZE = 1,

    parameter IF_COUNT = 1,
    parameter PORTS_PER_IF = 4,

    parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF,

    parameter XGMII_DATA_WIDTH = 64,
    parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8
)
(
    // towards PHY
    input  wire [PHY_COUNT-1:0]                    phy_xgmii_tx_clk,
    input  wire [PHY_COUNT-1:0]                    phy_xgmii_tx_rst,
    output wire [PHY_COUNT*XGMII_DATA_WIDTH-1:0]   phy_xgmii_txd,
    output wire [PHY_COUNT*XGMII_CTRL_WIDTH-1:0]   phy_xgmii_txc,
    input  wire [PHY_COUNT-1:0]                    phy_tx_status,

    input  wire [PHY_COUNT-1:0]                    phy_xgmii_rx_clk,
    input  wire [PHY_COUNT-1:0]                    phy_xgmii_rx_rst,
    input  wire [PHY_COUNT*XGMII_DATA_WIDTH-1:0]   phy_xgmii_rxd,
    input  wire [PHY_COUNT*XGMII_CTRL_WIDTH-1:0]   phy_xgmii_rxc,
    input  wire [PHY_COUNT-1:0]                    phy_rx_status,

    // towards MAC
    output wire [PORT_COUNT-1:0]                   port_xgmii_tx_clk,
    output wire [PORT_COUNT-1:0]                   port_xgmii_tx_rst,
    input  wire [PORT_COUNT*XGMII_DATA_WIDTH-1:0]  port_xgmii_txd,
    input  wire [PORT_COUNT*XGMII_CTRL_WIDTH-1:0]  port_xgmii_txc,
    output wire [PORT_COUNT-1:0]                   port_tx_status,

    output wire [PORT_COUNT-1:0]                   port_xgmii_rx_clk,
    output wire [PORT_COUNT-1:0]                   port_xgmii_rx_rst,
    output wire [PORT_COUNT*XGMII_DATA_WIDTH-1:0]  port_xgmii_rxd,
    output wire [PORT_COUNT*XGMII_CTRL_WIDTH-1:0]  port_xgmii_rxc,
    output wire [PORT_COUNT-1:0]                   port_rx_status
);

initial begin
    if (PORT_COUNT > PHY_COUNT) begin
        $error("Error: Requested port count out of range (instance %m)");
        $finish;
    end
end

function [PHY_COUNT-1:0] calcMask(input [31:0] if_count, input [31:0] ports_per_if, input [31:0] group_size);
    integer iface, port, phy;
    begin
        phy = 0;
        calcMask = 0;
        if (if_count*ports_per_if*group_size <= PHY_COUNT) begin
            // all ports in their own group
            for (port = 0; port < if_count*ports_per_if; port = port + 1) begin
                calcMask[phy] = 1'b1;
                phy = phy + group_size;
            end
        end else if (if_count*((ports_per_if+group_size-1)/group_size)*group_size <= PHY_COUNT) begin
            // pack ports on each interface, each interface starts on a group boundary
            for (iface = 0; iface < if_count; iface = iface + 1) begin
                for (port = 0; port < ports_per_if; port = port + 1) begin
                    calcMask[phy] = 1'b1;
                    phy = phy + 1;
                end
                if (phy % group_size > 0) begin
                    phy = phy + group_size - (phy % group_size);
                end
            end
        end else begin
            // pack everything
            calcMask = {PHY_COUNT{1'b1}};
        end
    end
endfunction

localparam PORT_MASK_INT = PORT_MASK ? PORT_MASK : calcMask(IF_COUNT, PORTS_PER_IF, PORT_GROUP_SIZE);

function [PHY_COUNT*8-1:0] calcIndices(input [PHY_COUNT-1:0] mask);
    integer port, phy;
    begin
        port = 0;
        calcIndices = {PHY_COUNT*8{1'b1}};
        for (phy = 0; phy < PHY_COUNT; phy = phy + 1) begin
            if (mask[phy] && port < PORT_COUNT) begin
                calcIndices[phy*8 +: 8] = port;
                port = port + 1;
            end else begin
                calcIndices[phy*8 +: 8] = 8'hff;
            end
        end

        if (port < PORT_COUNT) begin
            // invalid mask - not enough set bits
            calcIndices = {PHY_COUNT*8{1'b1}};
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

    for (n = 0; n < PHY_COUNT; n = n + 1) begin : phy
        if (IND[n*8 +: 8] != 8'hff) begin
            initial begin
                $display("Phy %d connected to port %d", n, IND[n*8 +: 8]);
            end
            assign port_xgmii_tx_clk[IND[n*8 +: 8]] = phy_xgmii_tx_clk[n];
            assign port_xgmii_tx_rst[IND[n*8 +: 8]] = phy_xgmii_tx_rst[n];

            assign phy_xgmii_txd[n*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = port_xgmii_txd[IND[n*8 +: 8]*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
            assign phy_xgmii_txc[n*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = port_xgmii_txc[IND[n*8 +: 8]*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];

            assign port_tx_status[IND[n*8 +: 8]] = phy_tx_status[n];

            assign port_xgmii_rx_clk[IND[n*8 +: 8]] = phy_xgmii_rx_clk[n];
            assign port_xgmii_rx_rst[IND[n*8 +: 8]] = phy_xgmii_rx_rst[n];

            assign port_xgmii_rxd[IND[n*8 +: 8]*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = phy_xgmii_rxd[n*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH];
            assign port_xgmii_rxc[IND[n*8 +: 8]*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = phy_xgmii_rxc[n*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH];

            assign port_rx_status[IND[n*8 +: 8]] = phy_rx_status[n];
        end else begin
            initial begin
                $display("Phy %d skipped", n);
            end
            assign phy_xgmii_txd[n*XGMII_DATA_WIDTH +: XGMII_DATA_WIDTH] = {XGMII_CTRL_WIDTH{8'h07}};
            assign phy_xgmii_txc[n*XGMII_CTRL_WIDTH +: XGMII_CTRL_WIDTH] = {XGMII_CTRL_WIDTH{1'b1}};
        end
    end
endgenerate

endmodule

`resetall
