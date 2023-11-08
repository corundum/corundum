// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PTP hardware clock
 */
module mqnic_ptp #
(
    parameter PTP_CLK_PERIOD_NS_NUM = 4,
    parameter PTP_CLK_PERIOD_NS_DENOM = 1,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,
    parameter REG_ADDR_WIDTH = 7+(PTP_PEROUT_ENABLE ? $clog2((PTP_PEROUT_COUNT+1)/2) + 1 : 0),
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    parameter RB_BASE_ADDR = 0,
    parameter RB_NEXT_PTR = 0
)
(
    input  wire                         clk,
    input  wire                         rst,

    /*
     * Register interface
     */
    input  wire [REG_ADDR_WIDTH-1:0]    reg_wr_addr,
    input  wire [REG_DATA_WIDTH-1:0]    reg_wr_data,
    input  wire [REG_STRB_WIDTH-1:0]    reg_wr_strb,
    input  wire                         reg_wr_en,
    output wire                         reg_wr_wait,
    output wire                         reg_wr_ack,
    input  wire [REG_ADDR_WIDTH-1:0]    reg_rd_addr,
    input  wire                         reg_rd_en,
    output wire [REG_DATA_WIDTH-1:0]    reg_rd_data,
    output wire                         reg_rd_wait,
    output wire                         reg_rd_ack,

    /*
     * PTP clock
     */
    input  wire                         ptp_clk,
    input  wire                         ptp_rst,
    input  wire                         ptp_sample_clk,
    output wire                         ptp_td_sd,
    output wire                         ptp_pps,
    output wire                         ptp_pps_str,
    output wire                         ptp_sync_locked,
    output wire [63:0]                  ptp_sync_ts_rel,
    output wire                         ptp_sync_ts_rel_step,
    output wire [95:0]                  ptp_sync_ts_tod,
    output wire                         ptp_sync_ts_tod_step,
    output wire                         ptp_sync_pps,
    output wire                         ptp_sync_pps_str,
    output wire [PTP_PEROUT_COUNT-1:0]  ptp_perout_locked,
    output wire [PTP_PEROUT_COUNT-1:0]  ptp_perout_error,
    output wire [PTP_PEROUT_COUNT-1:0]  ptp_perout_pulse
);

// bus width assertions
initial begin
    if (REG_DATA_WIDTH != 32) begin
        $error("Error: Register interface width must be 32 (instance %m)");
        $finish;
    end

    if (REG_STRB_WIDTH * 8 != REG_DATA_WIDTH) begin
        $error("Error: Register interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end

    if (REG_ADDR_WIDTH < 7+(PTP_PEROUT_ENABLE ? $clog2((PTP_PEROUT_COUNT+1)/2) + 1 : 0)) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end
end

wire clock_reg_wr_wait;
wire clock_reg_wr_ack;
wire [REG_DATA_WIDTH-1:0] clock_reg_rd_data;
wire clock_reg_rd_wait;
wire clock_reg_rd_ack;

wire perout_reg_wr_wait[PTP_PEROUT_COUNT-1:0];
wire perout_reg_wr_ack[PTP_PEROUT_COUNT-1:0];
wire [REG_DATA_WIDTH-1:0] perout_reg_rd_data[PTP_PEROUT_COUNT-1:0];
wire perout_reg_rd_wait[PTP_PEROUT_COUNT-1:0];
wire perout_reg_rd_ack[PTP_PEROUT_COUNT-1:0];

reg reg_wr_wait_cmb;
reg reg_wr_ack_cmb;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_cmb;
reg reg_rd_wait_cmb;
reg reg_rd_ack_cmb;

assign reg_wr_wait = reg_wr_wait_cmb;
assign reg_wr_ack = reg_wr_ack_cmb;
assign reg_rd_data = reg_rd_data_cmb;
assign reg_rd_wait = reg_rd_wait_cmb;
assign reg_rd_ack = reg_rd_ack_cmb;

integer k;

always @* begin
    reg_wr_wait_cmb = clock_reg_wr_wait;
    reg_wr_ack_cmb = clock_reg_wr_ack;
    reg_rd_data_cmb = clock_reg_rd_data;
    reg_rd_wait_cmb = clock_reg_rd_wait;
    reg_rd_ack_cmb = clock_reg_rd_ack;

    if (PTP_PEROUT_ENABLE) begin
        for (k = 0; k < PTP_PEROUT_COUNT; k = k + 1) begin
            reg_wr_wait_cmb = reg_wr_wait_cmb | perout_reg_wr_wait[k];
            reg_wr_ack_cmb = reg_wr_ack_cmb | perout_reg_wr_ack[k];
            reg_rd_data_cmb = reg_rd_data_cmb | perout_reg_rd_data[k];
            reg_rd_wait_cmb = reg_rd_wait_cmb | perout_reg_rd_wait[k];
            reg_rd_ack_cmb = reg_rd_ack_cmb | perout_reg_rd_ack[k];
        end
    end
end

mqnic_ptp_clock #(
    .PTP_CLK_PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
    .PTP_CLK_PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM),
    .PTP_CLOCK_CDC_PIPELINE(PTP_CLOCK_CDC_PIPELINE),
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .REG_DATA_WIDTH(REG_DATA_WIDTH),
    .REG_STRB_WIDTH(REG_STRB_WIDTH),
    .RB_BASE_ADDR(RB_BASE_ADDR),
    .RB_NEXT_PTR(PTP_PEROUT_ENABLE ? RB_BASE_ADDR + 32'h80 : RB_NEXT_PTR)
)
ptp_clock_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Register interface
     */
    .reg_wr_addr(reg_wr_addr),
    .reg_wr_data(reg_wr_data),
    .reg_wr_strb(reg_wr_strb),
    .reg_wr_en(reg_wr_en),
    .reg_wr_wait(clock_reg_wr_wait),
    .reg_wr_ack(clock_reg_wr_ack),
    .reg_rd_addr(reg_rd_addr),
    .reg_rd_en(reg_rd_en),
    .reg_rd_data(clock_reg_rd_data),
    .reg_rd_wait(clock_reg_rd_wait),
    .reg_rd_ack(clock_reg_rd_ack),

    /*
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sd(ptp_td_sd),
    .ptp_pps(ptp_pps),
    .ptp_pps_str(ptp_pps_str),
    .ptp_sync_locked(ptp_sync_locked),
    .ptp_sync_ts_rel(ptp_sync_ts_rel),
    .ptp_sync_ts_rel_step(ptp_sync_ts_rel_step),
    .ptp_sync_ts_tod(ptp_sync_ts_tod),
    .ptp_sync_ts_tod_step(ptp_sync_ts_tod_step),
    .ptp_sync_pps(ptp_sync_pps),
    .ptp_sync_pps_str(ptp_sync_pps_str)
);

generate

genvar n;

if (PTP_PEROUT_ENABLE) begin

    for (n = 0; n < PTP_PEROUT_COUNT; n = n + 1) begin : perout

        mqnic_ptp_perout  #(
            .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
            .REG_DATA_WIDTH(REG_DATA_WIDTH),
            .REG_STRB_WIDTH(REG_STRB_WIDTH),
            .RB_BASE_ADDR(RB_BASE_ADDR + 32'h80 + 32'h40*n),
            .RB_NEXT_PTR(n < PTP_PEROUT_COUNT-1 ? RB_BASE_ADDR + 32'h80 + 32'h40*(n+1) : RB_NEXT_PTR)
        )
        ptp_perout_inst (
            .clk(clk),
            .rst(rst),

            /*
             * Register interface
             */
            .reg_wr_addr(reg_wr_addr),
            .reg_wr_data(reg_wr_data),
            .reg_wr_strb(reg_wr_strb),
            .reg_wr_en(reg_wr_en),
            .reg_wr_wait(perout_reg_wr_wait[n]),
            .reg_wr_ack(perout_reg_wr_ack[n]),
            .reg_rd_addr(reg_rd_addr),
            .reg_rd_en(reg_rd_en),
            .reg_rd_data(perout_reg_rd_data[n]),
            .reg_rd_wait(perout_reg_rd_wait[n]),
            .reg_rd_ack(perout_reg_rd_ack[n]),

            /*
             * PTP clock
             */
            .ptp_ts_96(ptp_sync_ts_tod),
            .ptp_ts_step(ptp_sync_ts_tod_step),
            .ptp_perout_locked(ptp_perout_locked[n]),
            .ptp_perout_error(ptp_perout_error[n]),
            .ptp_perout_pulse(ptp_perout_pulse[n])
        );

    end
    
end else begin
    
    assign ptp_perout_locked = 0;
    assign ptp_perout_error = 0;
    assign ptp_perout_pulse = 0;

end

endgenerate

endmodule

`resetall
