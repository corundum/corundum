/*

Copyright (c) 2018 Alex Forencich

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
 * Ultrascale PCIe MSI shim
 */
module pcie_us_msi #
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
     * Interface to Ultrascale PCIe IP core
     */
    input  wire [3:0]            cfg_interrupt_msi_enable,
    input  wire [7:0]            cfg_interrupt_msi_vf_enable,
    input  wire [11:0]           cfg_interrupt_msi_mmenable,
    input  wire                  cfg_interrupt_msi_mask_update,
    input  wire [31:0]           cfg_interrupt_msi_data,
    output wire [3:0]            cfg_interrupt_msi_select,
    output wire [31:0]           cfg_interrupt_msi_int,
    output wire [31:0]           cfg_interrupt_msi_pending_status,
    output wire                  cfg_interrupt_msi_pending_status_data_enable,
    output wire [3:0]            cfg_interrupt_msi_pending_status_function_num,
    input  wire                  cfg_interrupt_msi_sent,
    input  wire                  cfg_interrupt_msi_fail,
    output wire [2:0]            cfg_interrupt_msi_attr,
    output wire                  cfg_interrupt_msi_tph_present,
    output wire [1:0]            cfg_interrupt_msi_tph_type,
    output wire [8:0]            cfg_interrupt_msi_tph_st_tag,
    output wire [3:0]            cfg_interrupt_msi_function_number
);

reg active_reg = 1'b0, active_next;

reg [MSI_COUNT-1:0] msi_irq_reg = {MSI_COUNT{1'b0}};
reg [MSI_COUNT-1:0] msi_irq_last_reg = {MSI_COUNT{1'b0}};
reg [MSI_COUNT-1:0] msi_irq_active_reg = {MSI_COUNT{1'b0}}, msi_irq_active_next;

reg [MSI_COUNT-1:0] msi_irq_mask_reg = {MSI_COUNT{1'b0}}, msi_irq_mask_next;

reg [MSI_COUNT-1:0] msi_int_reg = {MSI_COUNT{1'b0}}, msi_int_next;

assign cfg_interrupt_msi_select = 4'd0; // request PF0 mask on cfg_interrupt_msi_data
assign cfg_interrupt_msi_int = msi_int_reg;
assign cfg_interrupt_msi_pending_status = msi_irq_reg;
assign cfg_interrupt_msi_pending_status_data_enable = 1'b1; // set PF0 pending status
assign cfg_interrupt_msi_pending_status_function_num = 4'd0; // set PF0 pending status
assign cfg_interrupt_msi_attr = 3'd0;
assign cfg_interrupt_msi_tph_present = 1'b0; // no TPH
assign cfg_interrupt_msi_tph_type = 2'd0;
assign cfg_interrupt_msi_tph_st_tag = 9'd0;
assign cfg_interrupt_msi_function_number = 4'd0; // send MSI for PF0

wire [MSI_COUNT-1:0] message_enable_mask = cfg_interrupt_msi_mmenable[2:0] > 3'd4 ? {32{1'b1}} : {32{1'b1}} >> (32 - (1 << cfg_interrupt_msi_mmenable[2:0]));

reg [MSI_COUNT-1:0] acknowledge;
wire [MSI_COUNT-1:0] grant;
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
    .grant_encoded()
);

always @* begin
    active_next = active_reg;

    msi_irq_active_next = (msi_irq_active_reg | (msi_irq_reg & ~msi_irq_last_reg));

    msi_irq_mask_next = ~cfg_interrupt_msi_data & message_enable_mask & {32{cfg_interrupt_msi_enable[0]}};

    msi_int_next = {MSI_COUNT{1'b0}};

    acknowledge = {MSI_COUNT{1'b0}};

    if (!active_reg) begin
        if (cfg_interrupt_msi_enable && grant_valid) begin
            msi_int_next = grant;
            active_next = 1'b1;
        end
    end else begin
        if (cfg_interrupt_msi_sent || cfg_interrupt_msi_fail) begin
            if (cfg_interrupt_msi_sent) begin
                msi_irq_active_next = msi_irq_active_next & ~grant;
            end
            acknowledge = grant;
            active_next = 1'b0;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        active_reg <= 1'b0;
        msi_irq_reg <= {MSI_COUNT{1'b0}};
        msi_irq_last_reg <= {MSI_COUNT{1'b0}};
        msi_irq_active_reg <= {MSI_COUNT{1'b0}};
        msi_irq_mask_reg <= {MSI_COUNT{1'b0}};
        msi_int_reg <= {MSI_COUNT{1'b0}};
    end else begin
        active_reg <= active_next;
        msi_irq_reg <= msi_irq;
        msi_irq_last_reg <= msi_irq_reg;
        msi_irq_active_reg <= msi_irq_active_next;
        msi_irq_mask_reg <= msi_irq_mask_next;
        msi_int_reg <= msi_int_next;
    end
end

endmodule

`resetall
