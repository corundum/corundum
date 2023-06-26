// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PTP period output
 */
module mqnic_ptp_perout #
(
    parameter REG_ADDR_WIDTH = 6,
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    parameter RB_BASE_ADDR = 0,
    parameter RB_NEXT_PTR = 0
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * Register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]  reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]  reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]  reg_wr_strb,
    input  wire                       reg_wr_en,
    output wire                       reg_wr_wait,
    output wire                       reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]  reg_rd_addr,
    input  wire                       reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]  reg_rd_data,
    output wire                       reg_rd_wait,
    output wire                       reg_rd_ack,

    /*
     * PTP clock
     */
    input  wire [95:0]                ptp_ts_96,
    input  wire                       ptp_ts_step,
    output wire                       ptp_perout_locked,
    output wire                       ptp_perout_error,
    output wire                       ptp_perout_pulse
);

localparam RBB = RB_BASE_ADDR & {REG_ADDR_WIDTH{1'b1}};

// check configuration
initial begin
    if (REG_DATA_WIDTH != 32) begin
        $error("Error: Register interface width must be 32 (instance %m)");
        $finish;
    end

    if (REG_STRB_WIDTH * 8 != REG_DATA_WIDTH) begin
        $error("Error: Register interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (REG_ADDR_WIDTH < 6) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end

    if (RB_NEXT_PTR >= RB_BASE_ADDR && RB_NEXT_PTR < RB_BASE_ADDR + 7'h40) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end
end

reg ptp_perout_enable_reg = 1'b0;

// control registers
reg reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0;
reg reg_rd_ack_reg = 1'b0;

reg [95:0] set_ptp_perout_start_reg = 0;
reg set_ptp_perout_start_valid_reg = 0;
reg [95:0] set_ptp_perout_period_reg = 0;
reg set_ptp_perout_period_valid_reg = 0;
reg [95:0] set_ptp_perout_width_reg = 0;
reg set_ptp_perout_width_valid_reg = 0;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

always @(posedge clk) begin
    reg_wr_ack_reg <= 1'b0;
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    set_ptp_perout_start_valid_reg <= 1'b0;
    set_ptp_perout_period_valid_reg <= 1'b0;
    set_ptp_perout_width_valid_reg <= 1'b0;

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_reg <= 1'b1;
        case ({reg_wr_addr >> 2, 2'b00})
            RBB+6'h0C: begin
                // PTP perout control and status
                ptp_perout_enable_reg <= reg_wr_data[0];
            end
            RBB+6'h10: set_ptp_perout_start_reg[15:0] <= reg_wr_data;  // PTP perout start fns
            RBB+6'h14: set_ptp_perout_start_reg[45:16] <= reg_wr_data; // PTP perout start ns
            RBB+6'h18: set_ptp_perout_start_reg[79:48] <= reg_wr_data; // PTP perout start sec l
            RBB+6'h1C: begin
                // PTP perout start sec h
                set_ptp_perout_start_reg[95:80] <= reg_wr_data;
                set_ptp_perout_start_valid_reg <= 1'b1;
            end
            RBB+6'h20: set_ptp_perout_period_reg[15:0] <= reg_wr_data;  // PTP perout period fns
            RBB+6'h24: set_ptp_perout_period_reg[45:16] <= reg_wr_data; // PTP perout period ns
            RBB+6'h28: set_ptp_perout_period_reg[79:48] <= reg_wr_data; // PTP perout period sec l
            RBB+6'h2C: begin
                // PTP perout period sec h
                set_ptp_perout_period_reg[95:80] <= reg_wr_data;
                set_ptp_perout_period_valid_reg <= 1'b1;
            end
            RBB+6'h30: set_ptp_perout_width_reg[15:0] <= reg_wr_data;  // PTP perout width fns
            RBB+6'h34: set_ptp_perout_width_reg[45:16] <= reg_wr_data; // PTP perout width ns
            RBB+6'h38: set_ptp_perout_width_reg[79:48] <= reg_wr_data; // PTP perout width sec l
            RBB+6'h3C: begin
                // PTP perout width sec h
                set_ptp_perout_width_reg[95:80] <= reg_wr_data;
                set_ptp_perout_width_valid_reg <= 1'b1;
            end
            default: reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_reg <= 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            RBB+6'h00: reg_rd_data_reg <= 32'h0000C081;  // PHC: Type
            RBB+6'h04: reg_rd_data_reg <= 32'h00000100;  // PHC: Version
            RBB+6'h08: reg_rd_data_reg <= RB_NEXT_PTR;   // PHC: Next header
            RBB+6'h0C: begin
                // PTP perout control and status
                reg_rd_data_reg[0] <= ptp_perout_enable_reg;
                reg_rd_data_reg[8] <= ptp_perout_pulse;
                reg_rd_data_reg[16] <= ptp_perout_locked;
                reg_rd_data_reg[24] <= ptp_perout_error;
            end
            RBB+6'h10: reg_rd_data_reg <= set_ptp_perout_start_reg[15:0];  // PTP perout start fns
            RBB+6'h14: reg_rd_data_reg <= set_ptp_perout_start_reg[45:16]; // PTP perout start ns
            RBB+6'h18: reg_rd_data_reg <= set_ptp_perout_start_reg[79:48]; // PTP perout start sec l
            RBB+6'h1C: reg_rd_data_reg <= set_ptp_perout_start_reg[95:80]; // PTP perout start sec h
            RBB+6'h20: reg_rd_data_reg <= set_ptp_perout_period_reg[15:0];  // PTP perout period fns
            RBB+6'h24: reg_rd_data_reg <= set_ptp_perout_period_reg[45:16]; // PTP perout period ns
            RBB+6'h28: reg_rd_data_reg <= set_ptp_perout_period_reg[79:48]; // PTP perout period sec l
            RBB+6'h2C: reg_rd_data_reg <= set_ptp_perout_period_reg[95:80]; // PTP perout period sec h
            RBB+6'h30: reg_rd_data_reg <= set_ptp_perout_width_reg[15:0];  // PTP perout width fns
            RBB+6'h34: reg_rd_data_reg <= set_ptp_perout_width_reg[45:16]; // PTP perout width ns
            RBB+6'h38: reg_rd_data_reg <= set_ptp_perout_width_reg[79:48]; // PTP perout width sec l
            RBB+6'h3C: reg_rd_data_reg <= set_ptp_perout_width_reg[95:80]; // PTP perout width sec h
            default: reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        ptp_perout_enable_reg <= 1'b0;
    end
end

ptp_perout #(
    .FNS_ENABLE(0),
    .OUT_START_S(0),
    .OUT_START_NS(0),
    .OUT_START_FNS(0),
    .OUT_PERIOD_S(1),
    .OUT_PERIOD_NS(0),
    .OUT_PERIOD_FNS(0),
    .OUT_WIDTH_S(0),
    .OUT_WIDTH_NS(500000000),
    .OUT_WIDTH_FNS(0)
)
ptp_perout_inst (
    .clk(clk),
    .rst(rst),
    .input_ts_96(ptp_ts_96),
    .input_ts_step(ptp_ts_step),
    .enable(ptp_perout_enable_reg),
    .input_start(set_ptp_perout_start_reg),
    .input_start_valid(set_ptp_perout_start_valid_reg),
    .input_period(set_ptp_perout_period_reg),
    .input_period_valid(set_ptp_perout_period_valid_reg),
    .input_width(set_ptp_perout_width_reg),
    .input_width_valid(set_ptp_perout_width_valid_reg),
    .locked(ptp_perout_locked),
    .error(ptp_perout_error),
    .output_pulse(ptp_perout_pulse)
);

endmodule

`resetall
