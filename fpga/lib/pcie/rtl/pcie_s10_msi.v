/*

Copyright (c) 2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Intel Stratix 10 H-Tile/L-Tile PCIe MSI shim
 */
module pcie_s10_msi #
(
    parameter MSI_COUNT = 32
)
(
    input  wire                  clk,
    input  wire                  rst,

    /*
     * Interrupt request inputs
     */
    input  wire [MSI_COUNT-1:0]  msi_irq,

    /*
     * Interface to H-Tile/L-Tile PCIe IP core
     */
    output wire                  app_msi_req,
    input  wire                  app_msi_ack,
    output wire [2:0]            app_msi_tc,
    output wire [4:0]            app_msi_num,
    output wire [1:0]            app_msi_func_num,

    /*
     * Configuration
     */
    input  wire                  cfg_msi_enable,
    input  wire [2:0]            cfg_multiple_msi_enable,
    input  wire [31:0]           cfg_msi_mask
);

reg active_reg = 1'b0, active_next;

reg [MSI_COUNT-1:0] msi_irq_reg = {MSI_COUNT{1'b0}};
reg [MSI_COUNT-1:0] msi_irq_last_reg = {MSI_COUNT{1'b0}};
reg [MSI_COUNT-1:0] msi_irq_active_reg = {MSI_COUNT{1'b0}}, msi_irq_active_next;

reg [MSI_COUNT-1:0] msi_irq_mask_reg = {MSI_COUNT{1'b0}}, msi_irq_mask_next;

reg [4:0] msi_int_reg = 0, msi_int_next;

assign app_msi_req = active_reg;
assign app_msi_tc = 0; // TC 0
assign app_msi_num = msi_int_reg;
assign app_msi_func_num = 0; // PF 0

wire [MSI_COUNT-1:0] message_enable_mask = cfg_multiple_msi_enable > 3'd4 ? {32{1'b1}} : {32{1'b1}} >> (32 - (1 << cfg_multiple_msi_enable));

reg [MSI_COUNT-1:0] acknowledge;
wire [MSI_COUNT-1:0] grant;
wire [4:0] grant_encoded;
wire grant_valid;

// arbiter instance
arbiter #(
    .PORTS(MSI_COUNT),
    .ARB_TYPE_ROUND_ROBIN(1),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(1)
)
arb_inst (
    .clk(clk),
    .rst(rst),
    .request(msi_irq_active_reg & msi_irq_mask_reg & ~grant),
    .acknowledge(acknowledge),
    .grant(grant),
    .grant_valid(grant_valid),
    .grant_encoded(grant_encoded)
);

always @* begin
    active_next = active_reg;

    msi_irq_active_next = (msi_irq_active_reg | (msi_irq_reg & ~msi_irq_last_reg));

    msi_irq_mask_next = ~cfg_msi_mask & message_enable_mask & {32{cfg_msi_enable}};

    msi_int_next = msi_int_reg;

    acknowledge = {MSI_COUNT{1'b0}};

    if (!active_reg) begin
        if (cfg_msi_enable && grant_valid) begin
            msi_int_next = grant_encoded;
            active_next = 1'b1;
        end
    end else begin
        if (app_msi_ack) begin
            msi_irq_active_next = msi_irq_active_next & ~grant;
            acknowledge = grant;
            active_next = 1'b0;
        end
    end
end

always @(posedge clk) begin
    active_reg <= active_next;
    msi_irq_reg <= msi_irq;
    msi_irq_last_reg <= msi_irq_reg;
    msi_irq_active_reg <= msi_irq_active_next;
    msi_irq_mask_reg <= msi_irq_mask_next;
    msi_int_reg <= msi_int_next;

    if (rst) begin
        active_reg <= 1'b0;
        msi_irq_reg <= {MSI_COUNT{1'b0}};
        msi_irq_last_reg <= {MSI_COUNT{1'b0}};
        msi_irq_active_reg <= {MSI_COUNT{1'b0}};
        msi_irq_mask_reg <= {MSI_COUNT{1'b0}};
        msi_int_reg <= {MSI_COUNT{1'b0}};
    end
end

endmodule

`resetall
