/*

Copyright (c) 2023 Alex Forencich

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
 * I2C single register
 */
module i2c_single_reg #(
    parameter FILTER_LEN = 4,
    parameter DEV_ADDR = 7'h70
)
(
    input  wire       clk,
    input  wire       rst,

    /*
     * I2C interface
     */
    input  wire       scl_i,
    output wire       scl_o,
    output wire       scl_t,
    input  wire       sda_i,
    output wire       sda_o,
    output wire       sda_t,

    /*
     * Data register
     */
    input  wire [7:0] data_in,
    input  wire       data_latch,
    output wire [7:0] data_out
);

localparam [4:0]
    STATE_IDLE = 4'd0,
    STATE_ADDRESS = 4'd1,
    STATE_ACK = 4'd2,
    STATE_WRITE_1 = 4'd3,
    STATE_WRITE_2 = 4'd4,
    STATE_READ_1 = 4'd5,
    STATE_READ_2 = 4'd6,
    STATE_READ_3 = 4'd7;

reg [4:0] state_reg = STATE_IDLE;

reg [7:0] data_reg = 8'd0;
reg [7:0] shift_reg = 8'd0;

reg mode_read_reg = 1'b0;

reg [3:0] bit_count_reg = 4'd0;

reg [FILTER_LEN-1:0] scl_i_filter_reg = {FILTER_LEN{1'b1}};
reg [FILTER_LEN-1:0] sda_i_filter_reg = {FILTER_LEN{1'b1}};

reg scl_i_reg = 1'b1;
reg sda_i_reg = 1'b1;

reg sda_o_reg = 1'b1;

reg last_scl_i_reg = 1'b1;
reg last_sda_i_reg = 1'b1;

assign scl_o = 1'b1;
assign scl_t = 1'b1;
assign sda_o = sda_o_reg;
assign sda_t = sda_o_reg;

assign data_out = data_reg;

wire scl_posedge = scl_i_reg && !last_scl_i_reg;
wire scl_negedge = !scl_i_reg && last_scl_i_reg;
wire sda_posedge = sda_i_reg && !last_sda_i_reg;
wire sda_negedge = !sda_i_reg && last_sda_i_reg;

wire start_bit = sda_negedge && scl_i_reg;
wire stop_bit = sda_posedge && scl_i_reg;

always @(posedge clk) begin

    if (start_bit) begin
        sda_o_reg <= 1'b1;

        bit_count_reg = 4'd7;
        state_reg <= STATE_ADDRESS;
    end else if (stop_bit) begin
        sda_o_reg <= 1'b1;

        state_reg <= STATE_IDLE;
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                // line idle
                sda_o_reg <= 1'b1;

                state_reg <= STATE_IDLE;
            end
            STATE_ADDRESS: begin
                // read address
                sda_o_reg <= 1'b1;

                if (scl_posedge) begin
                    if (bit_count_reg > 0) begin
                        // shift in address
                        bit_count_reg <= bit_count_reg-1;
                        shift_reg <= {shift_reg[6:0], sda_i_reg};
                        state_reg <= STATE_ADDRESS;
                    end else begin
                        // check address
                        mode_read_reg <= sda_i_reg;
                        if (shift_reg[6:0] == DEV_ADDR) begin
                            // it's a match, send ACK
                            state_reg <= STATE_ACK;
                        end else begin
                            // no match, return to idle
                            state_reg <= STATE_IDLE;
                        end
                    end
                end else begin
                    state_reg <= STATE_ADDRESS;
                end
            end
            STATE_ACK: begin
                // send ACK bit
                if (scl_negedge) begin
                    sda_o_reg <= 1'b0;
                    bit_count_reg <= 4'd7;
                    if (mode_read_reg) begin
                        // reading
                        shift_reg <= data_reg;
                        state_reg <= STATE_READ_1;
                    end else begin
                        // writing
                        state_reg <= STATE_WRITE_1;
                    end
                end else begin
                    state_reg <= STATE_ACK;
                end
            end
            STATE_WRITE_1: begin
                // write data byte
                if (scl_negedge) begin
                    sda_o_reg <= 1'b1;
                    state_reg <= STATE_WRITE_2;
                end else begin
                    state_reg <= STATE_WRITE_1;
                end
            end
            STATE_WRITE_2: begin
                // write data byte
                sda_o_reg <= 1'b1;
                if (scl_posedge) begin
                    // shift in data bit
                    shift_reg <= {shift_reg[6:0], sda_i_reg};
                    if (bit_count_reg > 0) begin
                        bit_count_reg <= bit_count_reg-1;
                        state_reg <= STATE_WRITE_2;
                    end else begin
                        data_reg <= {shift_reg[6:0], sda_i_reg};
                        state_reg <= STATE_ACK;
                    end
                end else begin
                    state_reg <= STATE_WRITE_2;
                end
            end
            STATE_READ_1: begin
                // read data byte
                if (scl_negedge) begin
                    // shift out data bit
                    {sda_o_reg, shift_reg} = {shift_reg, sda_i_reg};

                    if (bit_count_reg > 0) begin
                        bit_count_reg = bit_count_reg-1;
                        state_reg = STATE_READ_1;
                    end else begin
                        state_reg = STATE_READ_2;
                    end
                end else begin
                    state_reg = STATE_READ_1;
                end
            end
            STATE_READ_2: begin
                // read ACK bit
                if (scl_negedge) begin
                    // release SDA
                    sda_o_reg <= 1'b1;
                    state_reg <= STATE_READ_3;
                end else begin
                    state_reg <= STATE_READ_2;
                end
            end
            STATE_READ_3: begin
                // read ACK bit
                if (scl_posedge) begin
                    if (sda_i_reg) begin
                        // NACK, return to idle
                        state_reg <= STATE_IDLE;
                    end else begin
                        // ACK, read another byte
                        bit_count_reg <= 4'd7;
                        shift_reg <= data_reg;
                        state_reg <= STATE_READ_1;
                    end
                end else begin
                    state_reg <= STATE_READ_3;
                end
            end
        endcase
    end

    if (data_latch) begin
        data_reg <= data_in;
    end

    scl_i_filter_reg <= (scl_i_filter_reg << 1) | scl_i;
    sda_i_filter_reg <= (sda_i_filter_reg << 1) | sda_i;

    if (scl_i_filter_reg == {FILTER_LEN{1'b1}}) begin
        scl_i_reg <= 1'b1;
    end else if (scl_i_filter_reg == {FILTER_LEN{1'b0}}) begin
        scl_i_reg <= 1'b0;
    end

    if (sda_i_filter_reg == {FILTER_LEN{1'b1}}) begin
        sda_i_reg <= 1'b1;
    end else if (sda_i_filter_reg == {FILTER_LEN{1'b0}}) begin
        sda_i_reg <= 1'b0;
    end

    last_scl_i_reg <= scl_i_reg;
    last_sda_i_reg <= sda_i_reg;

    if (rst) begin
        state_reg <= STATE_IDLE;
        sda_o_reg <= 1'b1;
    end
end

endmodule

`resetall
