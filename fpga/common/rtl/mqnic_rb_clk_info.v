// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Clock info register block
 */
module mqnic_rb_clk_info #
(
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,
    parameter REF_CLK_PERIOD_NS_NUM = 32,
    parameter REF_CLK_PERIOD_NS_DENOM = 5,
    parameter CH_CNT = 2,
    parameter REG_ADDR_WIDTH = 16,
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    parameter RB_TYPE = 32'h0000C008,
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
     * Clock inputs
     */
    input  wire                       ref_clk,

    input  wire [CH_CNT-1:0]          ch_clk
);

localparam SHIFT = 8;
localparam RESOLUTION = 30;

localparam REF_CLK_CYCLES_PER_SEC = (64'd1_000_000_000*REF_CLK_PERIOD_NS_DENOM)/REF_CLK_PERIOD_NS_NUM;
localparam REF_CNT_WIDTH = $clog2(REF_CLK_CYCLES_PER_SEC >> SHIFT);

localparam CH_PRESCALE_WIDTH = 3;
localparam CNT_WIDTH = RESOLUTION-SHIFT;
localparam CH_CNT_WIDTH = CNT_WIDTH-CH_PRESCALE_WIDTH;

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

    if (REG_ADDR_WIDTH < 5) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end

    if (REG_ADDR_WIDTH < $clog2(32 + CH_CNT*4)) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end

    if (RB_NEXT_PTR && RB_NEXT_PTR >= RB_BASE_ADDR && RB_NEXT_PTR < RB_BASE_ADDR + 32 + CH_CNT*4) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end
end

// generate periodic strobe from ref clock for measurement period
reg [REF_CNT_WIDTH-1:0] ref_cnt_reg = 0;
reg ref_strb_reg = 0;

always @(posedge ref_clk) begin
    if (ref_cnt_reg) begin
        ref_cnt_reg <= ref_cnt_reg - 1;
    end else begin
        ref_cnt_reg <= (REF_CLK_CYCLES_PER_SEC >> SHIFT) - 1;
        ref_strb_reg <= !ref_strb_reg;
    end
end

reg ref_strb_sync_1_reg = 0;
reg ref_strb_sync_2_reg = 0;
reg ref_strb_sync_3_reg = 0;

always @(posedge clk) begin
    ref_strb_sync_1_reg <= ref_strb_reg;
    ref_strb_sync_2_reg <= ref_strb_sync_1_reg;
    ref_strb_sync_3_reg <= ref_strb_sync_2_reg;
end

// divide and sync each input clock
wire [CH_CNT-1:0] ch_flag;

generate

genvar ch;

for (ch = 0; ch < CH_CNT; ch = ch + 1) begin : channel

    reg [CH_PRESCALE_WIDTH+1-1:0] ch_prescale_reg = 0;

    always @(posedge ch_clk[ch]) begin
        ch_prescale_reg <= ch_prescale_reg + 1;
    end

    reg ch_flag_sync_1_reg = 0;
    reg ch_flag_sync_2_reg = 0;
    reg ch_flag_sync_3_reg = 0;

    always @(posedge clk) begin
        ch_flag_sync_1_reg <= ch_prescale_reg[CH_PRESCALE_WIDTH];
        ch_flag_sync_2_reg <= ch_flag_sync_1_reg;
        ch_flag_sync_3_reg <= ch_flag_sync_2_reg;
    end

    assign ch_flag[ch] = ch_flag_sync_3_reg ^ ch_flag_sync_2_reg;
end

endgenerate

// control registers
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0;
reg reg_rd_ack_reg = 1'b0;

reg [CNT_WIDTH-1:0] clk_acc_reg = 0;
reg [CNT_WIDTH-1:0] clk_cnt_reg = 0;

reg [CH_CNT_WIDTH-1:0] ch_acc_reg[0:CH_CNT-1];
reg [CH_CNT_WIDTH-1:0] ch_cnt_reg[0:CH_CNT-1];

wire [CH_CNT_WIDTH-1:0] ch_acc_reg_0 = ch_acc_reg[0];
wire [CH_CNT_WIDTH-1:0] ch_cnt_reg_0 = ch_cnt_reg[0];

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = 1'b0;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

integer k;

initial begin
    for (k = 0; k < CH_CNT; k = k + 1) begin
        ch_acc_reg[k] = 0;
        ch_cnt_reg[k] = 0;
    end
end

always @(posedge clk) begin
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    if (ref_strb_sync_3_reg ^ ref_strb_sync_2_reg) begin
        clk_acc_reg <= 1;
        clk_cnt_reg <= clk_acc_reg;
    end else begin
        clk_acc_reg <= clk_acc_reg + 1;
    end

    for (k = 0; k < CH_CNT; k = k + 1) begin
        if (ref_strb_sync_3_reg ^ ref_strb_sync_2_reg) begin
            ch_acc_reg[k] <= ch_flag[k];
            ch_cnt_reg[k] <= ch_acc_reg[k];
        end else begin
            ch_acc_reg[k] <= ch_acc_reg[k] + ch_flag[k];
        end
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_reg <= 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            RBB+5'h00: reg_rd_data_reg <= RB_TYPE;       // Type
            RBB+5'h04: reg_rd_data_reg <= 32'h00000100;  // Version
            RBB+5'h08: reg_rd_data_reg <= RB_NEXT_PTR;   // Next header
            RBB+5'h0C: reg_rd_data_reg <= CH_CNT;
            RBB+5'h10: begin
                reg_rd_data_reg[31:16] <= REF_CLK_PERIOD_NS_NUM;
                reg_rd_data_reg[15:0] <= REF_CLK_PERIOD_NS_DENOM;
            end
            RBB+5'h18: begin
                reg_rd_data_reg[31:16] <= CLK_PERIOD_NS_NUM;
                reg_rd_data_reg[15:0] <= CLK_PERIOD_NS_DENOM;
            end
            RBB+5'h1C: reg_rd_data_reg <= clk_cnt_reg << SHIFT;
            default: reg_rd_ack_reg <= 1'b0;
        endcase
        for (k = 0; k < CH_CNT; k = k + 1) begin
            if ({reg_rd_addr >> 2, 2'b00} == RBB+7'h20 + k*4) begin
                reg_rd_data_reg <= ch_cnt_reg[k] << (SHIFT+CH_PRESCALE_WIDTH);
                reg_rd_ack_reg <= 1'b1;
            end
        end
    end

    if (rst) begin
        reg_rd_ack_reg <= 1'b0;

        clk_acc_reg <= 0;
        clk_cnt_reg <= 0;

        for (k = 0; k < CH_CNT; k = k + 1) begin
            ch_acc_reg[k] <= 0;
            ch_cnt_reg[k] <= 0;
        end
    end
end

endmodule

`resetall
