// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * DRP register block
 */
module rb_drp #
(
    parameter DRP_ADDR_WIDTH = 10,
    parameter DRP_DATA_WIDTH = 15,
    parameter DRP_INFO = 32'd0,
    parameter REG_ADDR_WIDTH = 16,
    parameter REG_DATA_WIDTH = 32,
    parameter REG_STRB_WIDTH = (REG_DATA_WIDTH/8),
    parameter RB_TYPE = 32'h0000C150,
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
     * DRP
     */
    input  wire                       drp_clk,
    input  wire                       drp_rst,
    output wire [DRP_ADDR_WIDTH-1:0]  drp_addr,
    output wire [DRP_DATA_WIDTH-1:0]  drp_di,
    output wire                       drp_en,
    output wire                       drp_we,
    input  wire [DRP_DATA_WIDTH-1:0]  drp_do,
    input  wire                       drp_rdy
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

    if (REG_ADDR_WIDTH < 7) begin
        $error("Error: Register address width too narrow (instance %m)");
        $finish;
    end

    if (RB_NEXT_PTR >= RB_BASE_ADDR && RB_NEXT_PTR < RB_BASE_ADDR + 7'h20) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end
end

// control registers
reg reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0;
reg reg_rd_ack_reg = 1'b0;

reg [1:0] rb_state_reg = 2'd0;
reg rb_flag_reg = 1'b0;
(* srl_style = "register" *)
reg rb_flag_sync_reg_1 = 1'b0;
(* srl_style = "register" *)
reg rb_flag_sync_reg_2 = 1'b0;

reg [1:0] drp_state_reg = 2'd0;
reg drp_flag_reg = 1'b0;
(* srl_style = "register" *)
reg drp_flag_sync_reg_1 = 1'b0;
(* srl_style = "register" *)
reg drp_flag_sync_reg_2 = 1'b0;

reg [DRP_ADDR_WIDTH-1:0] rb_ctrl_addr_reg = 0;
reg [DRP_DATA_WIDTH-1:0] rb_ctrl_di_reg = 0;
reg rb_ctrl_we_reg = 1'b0;
reg rb_ctrl_en_reg = 1'b0;

reg [DRP_ADDR_WIDTH-1:0] rb_addr_reg = 0;
reg [DRP_DATA_WIDTH-1:0] rb_di_reg = 0;
reg [DRP_DATA_WIDTH-1:0] rb_do_reg = 0;
reg rb_we_reg = 1'b0;

reg [DRP_ADDR_WIDTH-1:0] drp_addr_reg = 0;
reg [DRP_DATA_WIDTH-1:0] drp_di_reg = 0;
reg [DRP_DATA_WIDTH-1:0] drp_do_reg = 0;
reg drp_en_reg = 1'b0;
reg drp_we_reg = 1'b0;
reg drp_do_valid_reg = 1'b0;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

assign drp_addr = drp_addr_reg;
assign drp_di = drp_di_reg;
assign drp_en = drp_en_reg;
assign drp_we = drp_we_reg;

always @(posedge drp_clk) begin
    drp_en_reg <= 1'b0;
    drp_we_reg <= 1'b0;

    if (drp_rdy) begin
        drp_do_reg <= drp_do;
        drp_do_valid_reg <= 1'b1;
    end

    case (drp_state_reg)
        2'd0: begin
            if (rb_flag_sync_reg_2) begin
                drp_state_reg <= 2'd1;
                drp_addr_reg <= rb_addr_reg;
                drp_di_reg <= rb_di_reg;
                drp_en_reg <= 1'b1;
                drp_we_reg <= rb_we_reg;
                drp_do_valid_reg <= 1'b0;
            end
        end
        2'd1: begin
            if (drp_do_valid_reg) begin
                drp_state_reg <= 2'd2;
                drp_flag_reg <= 1'b1;
            end
        end
        2'd2: begin
            if (!rb_flag_sync_reg_2) begin
                drp_state_reg <= 2'd0;
                drp_flag_reg <= 1'b0;
            end
        end
    endcase

    if (drp_rst) begin
        drp_state_reg <= 2'd0;
        drp_flag_reg <= 1'b0;

        drp_en_reg <= 1'b0;
        drp_we_reg <= 1'b0;
        drp_do_valid_reg <= 1'b0;
    end
end

// synchronization
always @(posedge clk) begin
    drp_flag_sync_reg_1 <= drp_flag_reg;
    drp_flag_sync_reg_2 <= drp_flag_sync_reg_1;
end

always @(posedge drp_clk) begin
    rb_flag_sync_reg_1 <= rb_flag_reg;
    rb_flag_sync_reg_2 <= rb_flag_sync_reg_1;
end

always @(posedge clk) begin
    reg_wr_ack_reg <= 1'b0;
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    case (rb_state_reg)
        2'd0: begin
            if (rb_ctrl_en_reg) begin
                rb_state_reg <= 2'd1;
                rb_flag_reg <= 1'b1;
                rb_addr_reg <= rb_ctrl_addr_reg;
                rb_di_reg <= rb_ctrl_di_reg;
                rb_we_reg <= rb_ctrl_we_reg;
            end
        end
        2'd1: begin
            if (drp_flag_sync_reg_2) begin
                rb_state_reg <= 2'd2;
                rb_flag_reg <= 1'b0;
                rb_do_reg <= drp_do_reg;
            end
        end
        2'd2: begin
            if (!drp_flag_sync_reg_2) begin
                rb_state_reg <= 2'd0;
                rb_ctrl_en_reg <= 1'b0;
            end
        end
    endcase

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_reg <= 1'b1;
        case ({reg_wr_addr >> 2, 2'b00})
            RBB+7'h10: begin
                // DRP: control
                rb_ctrl_en_reg <= reg_wr_data[0];
                rb_ctrl_we_reg <= reg_wr_data[1];
            end
            RBB+7'h14: rb_ctrl_addr_reg <= reg_wr_data; // DRP: address
            RBB+7'h18: rb_ctrl_di_reg <= reg_wr_data;   // DRP: data in
            default: reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_reg <= 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            RBB+7'h00: reg_rd_data_reg <= RB_TYPE;       // DRP: Type
            RBB+7'h04: reg_rd_data_reg <= 32'h00000100;  // DRP: Version
            RBB+7'h08: reg_rd_data_reg <= RB_NEXT_PTR;   // DRP: Next header
            RBB+7'h0C: reg_rd_data_reg <= DRP_INFO;      // DRP: info
            RBB+7'h10: begin
                // DRP: control
                reg_rd_data_reg[0] <= rb_ctrl_en_reg;
                reg_rd_data_reg[1] <= rb_ctrl_we_reg;
                reg_rd_data_reg[8] <= (rb_state_reg != 2'd0);
            end
            RBB+7'h14: reg_rd_data_reg <= rb_ctrl_addr_reg; // DRP: address
            RBB+7'h18: reg_rd_data_reg <= rb_ctrl_di_reg;   // DRP: data in
            RBB+7'h1C: reg_rd_data_reg <= rb_do_reg;        // DRP: data out
            default: reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        rb_state_reg <= 2'd0;
        rb_ctrl_en_reg <= 1'b0;
    end
end

endmodule

`resetall
