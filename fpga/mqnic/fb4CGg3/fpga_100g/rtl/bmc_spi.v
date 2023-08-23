// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Board management controller interface
 */
module bmc_spi #(
    // clock prescale (SPI clock half period in cycles of clk)
    parameter PRESCALE = 125,
    // byte wait time (SPI clock cycles)
    parameter BYTE_WAIT = 32,
    // timeout (SPI clock cycles)
    parameter TIMEOUT = 5000
)
(
    input  wire        clk,
    input  wire        rst,

    input  wire [15:0] ctrl_cmd,
    input  wire [31:0] ctrl_data,
    input  wire        ctrl_valid,

    output wire [15:0] read_data,

    output wire        status_idle,
    output wire        status_done,
    output wire        status_timeout,

    output wire        bmc_clk,
    output wire        bmc_nss,
    output wire        bmc_mosi,
    input  wire        bmc_miso,
    input  wire        bmc_int
);

localparam CL_PRESCALE = $clog2(PRESCALE+1);
localparam CL_DELAY = $clog2((BYTE_WAIT > TIMEOUT ? BYTE_WAIT : TIMEOUT)+1);

/*

SPI protocol:

8 byte transfer, MSB first

2 byte command
4 byte data
wait for int
2 byte read data

nss deasserted between each byte
wait 32 SPI cycle times between bytes
wait up to 5 ms for int assert from bmc

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_SHIFT = 3'd1,
    STATE_WAIT_BYTE = 3'd2,
    STATE_WAIT_INT = 3'd3;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg [15:0] read_data_reg = 15'd0, read_data_next;

reg status_idle_reg = 1'b0;
reg status_done_reg = 1'b0, status_done_next;
reg status_timeout_reg = 1'b0, status_timeout_next;

reg bmc_clk_reg = 1'b1, bmc_clk_next;
reg bmc_nss_reg = 1'b1, bmc_nss_next;
reg bmc_mosi_reg = 1'b1, bmc_mosi_next;
reg bmc_miso_reg = 1'b1;
reg bmc_int_reg = 1'b0;

reg [CL_PRESCALE+1-1:0] prescale_count_reg = 0, prescale_count_next;
reg [CL_DELAY-1:0] delay_count_reg = 0, delay_count_next;
reg [3:0] bit_count_reg = 0, bit_count_next;
reg [3:0] byte_count_reg = 0, byte_count_next;
reg [47:0] data_out_reg = 0, data_out_next;
reg [15:0] data_in_reg = 0, data_in_next;
reg int_reg = 0, int_next;

assign read_data = read_data_reg;

assign status_idle = status_idle_reg;
assign status_done = status_done_reg;
assign status_timeout = status_timeout_reg;

assign bmc_clk = bmc_clk_reg;
assign bmc_nss = bmc_nss_reg;
assign bmc_mosi = bmc_mosi_reg;

always @* begin
    state_next = state_reg;

    read_data_next = read_data_reg;

    status_done_next = status_done_reg;
    status_timeout_next = status_timeout_reg;

    bmc_clk_next = bmc_clk_reg;
    bmc_nss_next = bmc_nss_reg;
    bmc_mosi_next = bmc_mosi_reg;

    prescale_count_next = prescale_count_reg;
    delay_count_next = delay_count_reg;
    bit_count_next = bit_count_reg;
    byte_count_next = byte_count_reg;
    data_out_next = data_out_reg;
    data_in_next = data_in_reg;
    int_next = int_reg;

    if (prescale_count_reg != 0) begin
        prescale_count_next = prescale_count_reg - 1;
    end else if (bmc_clk_reg == 1'b0) begin
        bmc_clk_next = 1'b1;
        prescale_count_next = PRESCALE;
    end else if (delay_count_reg != 0) begin
        delay_count_next = delay_count_reg - 1;
        prescale_count_next = PRESCALE*2;
    end

    if (bmc_int_reg) begin
        int_next = 1'b1;
    end

    case (state_reg)
        STATE_IDLE: begin
            bmc_clk_next = 1'b1;
            bmc_nss_next = 1'b1;

            prescale_count_next = 0;
            delay_count_next = 0;
            bit_count_next = 8;
            byte_count_next = 8;
            data_out_next = {ctrl_cmd, ctrl_data};
            int_next = 1'b0;

            if (ctrl_valid) begin
                status_done_next = 1'b0;
                status_timeout_next = 1'b0;
                bmc_nss_next = 1'b0;
                prescale_count_next = PRESCALE*2;
                state_next = STATE_SHIFT;
            end
        end
        STATE_SHIFT: begin
            if (prescale_count_reg == 0 && bmc_clk_reg) begin
                if (bit_count_reg != 8) begin
                    // shift in bit
                    data_in_next = {data_in_reg, bmc_miso_reg};
                end

                if (bit_count_reg != 0) begin
                    // more bits to send; send the next bit
                    bmc_clk_next = 1'b0;
                    prescale_count_next = PRESCALE;
                    bit_count_next = bit_count_reg - 1;
                    {bmc_mosi_next, data_out_next} = {data_out_reg, 1'b0};
                    state_next = STATE_SHIFT;
                end else begin
                    // at the end of the byte; small delay
                    bmc_nss_next = 1'b1;
                    delay_count_next = BYTE_WAIT;
                    bit_count_next = 8;
                    byte_count_next = byte_count_reg - 1;
                    state_next = STATE_WAIT_BYTE;
                end
            end else begin
                state_next = STATE_SHIFT;
            end
        end
        STATE_WAIT_BYTE: begin
            // byte wait state; wait for delay timer
            if (delay_count_reg == 0) begin
                if (byte_count_reg == 2) begin
                    // command sent; wait for int from BMC
                    delay_count_next = TIMEOUT;
                    state_next = STATE_WAIT_INT;
                end else if (byte_count_reg == 0) begin
                    // done with operation; return to idle
                    read_data_next = data_in_reg;
                    status_done_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    // not at end of command; send next byte
                    bmc_nss_next = 1'b0;
                    prescale_count_next = PRESCALE*2;
                    state_next = STATE_SHIFT;
                end
            end else begin
                state_next = STATE_WAIT_BYTE;
            end
        end
        STATE_WAIT_INT: begin
            // wait for int from BMC
            if (int_reg) begin
                // got int, go back to shift state
                bmc_nss_next = 1'b0;
                prescale_count_next = PRESCALE*2;
                state_next = STATE_SHIFT;
            end else if (delay_count_reg == 0) begin
                // timed out waiting for BMC
                status_timeout_next = 1'b1;
                bmc_nss_next = 1'b0;
                prescale_count_next = PRESCALE*2;
                state_next = STATE_SHIFT;
            end else begin
                state_next = STATE_WAIT_INT;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    read_data_reg <= read_data_next;

    status_idle_reg <= state_next == STATE_IDLE;
    status_done_reg <= status_done_next;
    status_timeout_reg <= status_timeout_next;

    bmc_clk_reg <= bmc_clk_next;
    bmc_nss_reg <= bmc_nss_next;
    bmc_mosi_reg <= bmc_mosi_next;
    bmc_miso_reg <= bmc_miso;
    bmc_int_reg <= bmc_int;

    prescale_count_reg <= prescale_count_next;
    delay_count_reg <= delay_count_next;
    bit_count_reg <= bit_count_next;
    byte_count_reg <= byte_count_next;
    data_out_reg <= data_out_next;
    data_in_reg <= data_in_next;
    int_reg <= int_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        status_idle_reg <= 1'b0;
        status_done_reg <= 1'b0;
        status_timeout_reg <= 1'b0;

        bmc_clk_reg <= 1'b1;
        bmc_nss_reg <= 1'b1;
        bmc_mosi_reg <= 1'b1;
    end
end

endmodule

`resetall
