// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * DRAM test channel
 */
module dram_test_ch #
(
    // AXI configuration
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 16,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_MAX_BURST_LEN = 16,

    // FIFO config
    parameter FIFO_BASE_ADDR = 0,
    parameter FIFO_SIZE_MASK = {AXI_ADDR_WIDTH{1'b1}},

    // Register interface
    parameter REG_ADDR_WIDTH = 7,
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
     * AXI master interface
     */
    input  wire                       m_axi_clk,
    input  wire                       m_axi_rst,
    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready
);

localparam RBB = RB_BASE_ADDR & {REG_ADDR_WIDTH{1'b1}};

localparam LANE_WIDTH = 32;
localparam LANE_COUNT = (AXI_DATA_WIDTH + LANE_WIDTH-1) / LANE_WIDTH;
localparam LANE_ERR_CNT_WIDTH = $clog2(LANE_WIDTH)+1;

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

    if (RB_NEXT_PTR && RB_NEXT_PTR >= RB_BASE_ADDR && RB_NEXT_PTR < RB_BASE_ADDR + 7'h60) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end
end

// control registers
reg reg_wr_ack_reg = 1'b0, reg_wr_ack_next;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0, reg_rd_data_next;
reg reg_rd_ack_reg = 1'b0, reg_rd_ack_next;

reg [AXI_ADDR_WIDTH-1:0] fifo_base_addr_reg = FIFO_BASE_ADDR, fifo_base_addr_next;
reg [AXI_ADDR_WIDTH-1:0] fifo_size_mask_reg = FIFO_SIZE_MASK, fifo_size_mask_next;
reg fifo_enable_reg = 1'b0, fifo_enable_next;
reg fifo_reset_reg = 1'b0, fifo_reset_next;

(* shreg_extract = "no" *)
reg [AXI_ADDR_WIDTH-1:0] fifo_base_addr_sync_1_reg = FIFO_BASE_ADDR;
(* shreg_extract = "no" *)
reg [AXI_ADDR_WIDTH-1:0] fifo_base_addr_sync_2_reg = FIFO_BASE_ADDR;
(* shreg_extract = "no" *)
reg [AXI_ADDR_WIDTH-1:0] fifo_size_mask_sync_1_reg = FIFO_SIZE_MASK;
(* shreg_extract = "no" *)
reg [AXI_ADDR_WIDTH-1:0] fifo_size_mask_sync_2_reg = FIFO_SIZE_MASK;
(* shreg_extract = "no" *)
reg fifo_enable_sync_1_reg = 1'b0;
(* shreg_extract = "no" *)
reg fifo_enable_sync_2_reg = 1'b0;
(* shreg_extract = "no" *)
reg fifo_reset_sync_1_reg = 1'b0;
(* shreg_extract = "no" *)
reg fifo_reset_sync_2_reg = 1'b0;

always @(posedge m_axi_clk) begin
    fifo_base_addr_sync_1_reg <= fifo_base_addr_reg;
    fifo_base_addr_sync_2_reg <= fifo_base_addr_sync_1_reg;
    fifo_size_mask_sync_1_reg <= fifo_size_mask_reg;
    fifo_size_mask_sync_2_reg <= fifo_size_mask_sync_1_reg;
    fifo_enable_sync_1_reg <= fifo_enable_reg;
    fifo_enable_sync_2_reg <= fifo_enable_sync_1_reg;
    fifo_reset_sync_1_reg <= fifo_reset_reg;
    fifo_reset_sync_2_reg <= fifo_reset_sync_1_reg;

    if (m_axi_rst) begin
        fifo_base_addr_sync_1_reg <= FIFO_BASE_ADDR;
        fifo_base_addr_sync_2_reg <= FIFO_BASE_ADDR;
        fifo_size_mask_sync_1_reg <= FIFO_SIZE_MASK;
        fifo_size_mask_sync_2_reg <= FIFO_SIZE_MASK;
        fifo_enable_sync_1_reg <= 1'b0;
        fifo_enable_sync_2_reg <= 1'b0;
        fifo_reset_sync_1_reg <= 1'b0;
        fifo_reset_sync_2_reg <= 1'b0;
    end
end

wire [AXI_ADDR_WIDTH+1-1:0] fifo_occupancy;
wire fifo_reset_status;
wire fifo_active;

reg [AXI_ADDR_WIDTH+1-1:0] fifo_occupancy_reg = 0;
reg fifo_reset_status_reg = 1'b0;
reg fifo_active_reg = 1'b0;

(* shreg_extract = "no" *)
reg [AXI_ADDR_WIDTH+1-1:0] fifo_occupancy_sync_1_reg = 0;
(* shreg_extract = "no" *)
reg [AXI_ADDR_WIDTH+1-1:0] fifo_occupancy_sync_2_reg = 0;
(* shreg_extract = "no" *)
reg fifo_reset_status_sync_1_reg = 1'b0;
(* shreg_extract = "no" *)
reg fifo_reset_status_sync_2_reg = 1'b0;
(* shreg_extract = "no" *)
reg fifo_active_sync_1_reg = 1'b0;
(* shreg_extract = "no" *)
reg fifo_active_sync_2_reg = 1'b0;

always @(posedge m_axi_clk) begin
    fifo_occupancy_reg <= fifo_occupancy;
    fifo_reset_status_reg <= fifo_reset_status;
    fifo_active_reg <= fifo_active;
end

always @(posedge clk) begin
    fifo_occupancy_sync_1_reg <= fifo_occupancy_reg;
    fifo_occupancy_sync_2_reg <= fifo_occupancy_sync_1_reg;
    fifo_reset_status_sync_1_reg <= fifo_reset_status_reg;
    fifo_reset_status_sync_2_reg <= fifo_reset_status_sync_1_reg;
    fifo_active_sync_1_reg <= fifo_active_reg;
    fifo_active_sync_2_reg <= fifo_active_sync_1_reg;
end

reg data_gen_enable_reg = 1'b0, data_gen_enable_next;
reg data_gen_reset_reg = 1'b0, data_gen_reset_next;
reg data_check_enable_reg = 1'b0, data_check_enable_next;
reg data_check_reset_reg = 1'b0, data_check_reset_next;

reg [31:0] active_cycle_count_reg = 0, active_cycle_count_next;

reg [31:0] write_count_reg = 0, write_count_next;
reg [31:0] read_count_reg = 0, read_count_next;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

// test data generator and checker
wire [AXI_DATA_WIDTH-1:0] prbs_gen_data;
reg prbs_gen_en;
reg prbs_gen_rst;

reg [AXI_DATA_WIDTH-1:0] prbs_check_data;
wire [31:0] prbs_check_lane_err_cnt[LANE_COUNT-1:0];
reg prbs_check_en;
reg prbs_check_rst;

reg [AXI_DATA_WIDTH-1:0] in_axis_tdata_reg = 0, in_axis_tdata_next;
reg in_axis_tvalid_reg = 1'b0, in_axis_tvalid_next;
wire in_axis_tready;

wire [AXI_DATA_WIDTH-1:0] out_axis_tdata;
wire out_axis_tvalid;
reg out_axis_tready_reg = 1'b0, out_axis_tready_next;

generate

genvar n;

for (n = 0; n < LANE_COUNT; n = n + 1) begin : lane

    // test data generator (PRBS31)
    reg [30:0] lane_gen_state_reg = {31{1'b1}};
    wire [LANE_WIDTH-1:0] lane_gen_data;
    wire [30:0] lane_gen_state;

    assign prbs_gen_data[n*LANE_WIDTH +: LANE_WIDTH] = lane_gen_data;

    lfsr #(
        .LFSR_WIDTH(31),
        .LFSR_POLY(31'h10000001),
        .LFSR_CONFIG("FIBONACCI"),
        .LFSR_FEED_FORWARD(0),
        .REVERSE(0),
        .DATA_WIDTH(LANE_WIDTH)
    )
    prbs31_gen_inst (
        .data_in(0),
        .state_in(lane_gen_state_reg),
        .data_out(lane_gen_data),
        .state_out(lane_gen_state)
    );

    always @(posedge clk) begin
        if (prbs_gen_en) begin
            lane_gen_state_reg <= lane_gen_state;
        end

        if (prbs_gen_rst) begin
            lane_gen_state_reg <= {31{1'b1}};
        end
    end

    // test data checker (PRBS31)
    reg [30:0] lane_check_state_reg = {31{1'b1}};
    wire [LANE_WIDTH-1:0] lane_check_data = prbs_check_data[n*LANE_WIDTH +: LANE_WIDTH];
    wire [LANE_WIDTH-1:0] lane_check_errors;
    reg [LANE_ERR_CNT_WIDTH-1:0] lane_check_err_cnt;
    reg [LANE_ERR_CNT_WIDTH-1:0] lane_check_err_cnt_reg = 0;
    reg [31:0] lane_check_err_cnt_acc_reg = 0;
    wire [30:0] lane_check_state;

    assign prbs_check_lane_err_cnt[n] = lane_check_err_cnt_acc_reg;

    lfsr #(
        .LFSR_WIDTH(31),
        .LFSR_POLY(31'h10000001),
        .LFSR_CONFIG("FIBONACCI"),
        .LFSR_FEED_FORWARD(1),
        .REVERSE(0),
        .DATA_WIDTH(LANE_WIDTH)
    )
    prbs31_check_inst (
        .data_in(lane_check_data),
        .state_in(lane_check_state_reg),
        .data_out(lane_check_errors),
        .state_out(lane_check_state)
    );

    integer i;

    always @* begin
        lane_check_err_cnt = 0;
        for (i = 0; i < LANE_WIDTH; i = i + 1) begin
            lane_check_err_cnt = lane_check_err_cnt + lane_check_errors[i];
        end
    end

    always @(posedge clk) begin
        lane_check_err_cnt_reg <= 0;
        lane_check_err_cnt_acc_reg <= lane_check_err_cnt_acc_reg + lane_check_err_cnt_reg;

        if (prbs_check_en) begin
            lane_check_state_reg <= lane_check_state;
            lane_check_err_cnt_reg <= lane_check_err_cnt;
        end

        if (prbs_check_rst) begin
            lane_check_state_reg <= {31{1'b1}};
            lane_check_err_cnt_acc_reg <= 0;
        end
    end

end

endgenerate

integer k;

always @* begin
    reg_wr_ack_next = 1'b0;
    reg_rd_data_next = 0;
    reg_rd_ack_next = 1'b0;

    fifo_base_addr_next = fifo_base_addr_reg;
    fifo_size_mask_next = fifo_size_mask_reg;
    fifo_enable_next = fifo_enable_reg;
    fifo_reset_next = fifo_reset_reg;

    data_gen_enable_next = data_gen_enable_reg;
    data_gen_reset_next = data_gen_reset_reg;
    data_check_enable_next = data_check_enable_reg;
    data_check_reset_next = data_check_reset_reg;

    active_cycle_count_next = active_cycle_count_reg;

    write_count_next = write_count_reg;
    read_count_next = read_count_reg;

    in_axis_tdata_next = in_axis_tdata_reg;
    in_axis_tvalid_next = in_axis_tvalid_reg && !in_axis_tready;

    out_axis_tready_next = data_check_enable_reg;

    prbs_gen_en = 1'b0;
    prbs_gen_rst = data_gen_reset_reg;

    prbs_check_data = out_axis_tdata;
    prbs_check_en = 1'b0;
    prbs_check_rst = data_check_reset_reg;

    if (data_gen_enable_reg && (!in_axis_tvalid_reg || in_axis_tready)) begin
        prbs_gen_en = 1'b1;
        in_axis_tdata_next = prbs_gen_data;
        in_axis_tvalid_next = 1'b1;

        if (write_count_reg) begin
            write_count_next = write_count_reg - 1;
        end

        if (write_count_reg == 1) begin
            data_gen_enable_next = 1'b0;
        end
    end

    if (out_axis_tready_reg && out_axis_tvalid) begin
        prbs_check_en = 1'b1;

        if (read_count_reg) begin
            read_count_next = read_count_reg - 1;
        end

        if (read_count_reg == 1) begin
            data_check_enable_next = 1'b0;
            out_axis_tready_next = 1'b0;
        end
    end

    if (data_gen_enable_reg || data_check_enable_reg) begin
        active_cycle_count_next = active_cycle_count_reg + 1;
    end

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_next = 1'b1;
        case ({reg_wr_addr >> 2, 2'b00})
            RBB+8'h20: begin
                fifo_enable_next = reg_wr_data[0];
                fifo_reset_next = reg_wr_data[1];
            end
            RBB+8'h24: begin
                data_gen_enable_next = reg_wr_data[0];
                data_gen_reset_next = reg_wr_data[1];
                data_check_enable_next = reg_wr_data[8];
                data_check_reset_next = reg_wr_data[9];
            end
            RBB+8'h40: fifo_base_addr_next = (fifo_base_addr_reg & 64'hffffffff00000000) | {32'd0, reg_wr_data};
            RBB+8'h44: fifo_base_addr_next = (fifo_base_addr_reg & 64'h00000000ffffffff) | {reg_wr_data, 32'd0};
            RBB+8'h48: fifo_size_mask_next = (fifo_size_mask_reg & 64'hffffffff00000000) | {32'd0, reg_wr_data};
            RBB+8'h4C: fifo_size_mask_next = (fifo_size_mask_reg & 64'h00000000ffffffff) | {reg_wr_data, 32'd0};
            RBB+8'h60: active_cycle_count_next = 0;
            RBB+8'h68: write_count_next = reg_wr_data;
            RBB+8'h6C: read_count_next = reg_wr_data;
            default: reg_wr_ack_next = 1'b0;
        endcase
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_next = 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            RBB+8'h00: reg_rd_data_next = 32'h12348102;  // Type
            RBB+8'h04: reg_rd_data_next = 32'h00000100;  // Version
            RBB+8'h08: reg_rd_data_next = RB_NEXT_PTR;   // Next header
            RBB+8'h10: reg_rd_data_next = AXI_ADDR_WIDTH;
            RBB+8'h14: reg_rd_data_next = AXI_DATA_WIDTH;
            RBB+8'h18: reg_rd_data_next = LANE_COUNT;
            RBB+8'h1C: reg_rd_data_next = LANE_WIDTH;
            RBB+8'h20: begin
                reg_rd_data_next[0] = fifo_enable_reg;
                reg_rd_data_next[1] = fifo_reset_reg;
                reg_rd_data_next[16] = fifo_active_sync_2_reg;
                reg_rd_data_next[17] = fifo_reset_status_sync_2_reg;
            end
            RBB+8'h24: begin
                reg_rd_data_next[0] = data_gen_enable_reg;
                reg_rd_data_next[1] = data_gen_reset_reg;
                reg_rd_data_next[8] = data_check_enable_reg;
                reg_rd_data_next[9] = data_check_reset_reg;
            end
            RBB+8'h30: reg_rd_data_next = FIFO_BASE_ADDR;
            RBB+8'h34: reg_rd_data_next = FIFO_BASE_ADDR >> 32;
            RBB+8'h38: reg_rd_data_next = FIFO_SIZE_MASK;
            RBB+8'h3C: reg_rd_data_next = FIFO_SIZE_MASK >> 32;
            RBB+8'h40: reg_rd_data_next = fifo_base_addr_reg;
            RBB+8'h44: reg_rd_data_next = fifo_base_addr_reg >> 32;
            RBB+8'h48: reg_rd_data_next = fifo_size_mask_reg;
            RBB+8'h4C: reg_rd_data_next = fifo_size_mask_reg >> 32;
            RBB+8'h50: reg_rd_data_next = fifo_occupancy_sync_2_reg;
            RBB+8'h54: reg_rd_data_next = fifo_occupancy_sync_2_reg >> 32;
            RBB+8'h60: reg_rd_data_next = active_cycle_count_reg;
            RBB+8'h68: reg_rd_data_next = write_count_reg;
            RBB+8'h6C: reg_rd_data_next = read_count_reg;
            default: reg_rd_ack_next = 1'b0;
        endcase
        for (k = 0; k < LANE_COUNT; k = k + 1) begin
            if ({reg_rd_addr >> 2, 2'b00} == RBB+8'h80 + k*4) begin
                reg_rd_data_next = prbs_check_lane_err_cnt[k];
                reg_rd_ack_next = 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    reg_wr_ack_reg <= reg_wr_ack_next;
    reg_rd_data_reg <= reg_rd_data_next;
    reg_rd_ack_reg <= reg_rd_ack_next;

    fifo_base_addr_reg <= fifo_base_addr_next;
    fifo_size_mask_reg <= fifo_size_mask_next;
    fifo_enable_reg <= fifo_enable_next;
    fifo_reset_reg <= fifo_reset_next;

    data_gen_enable_reg <= data_gen_enable_next;
    data_gen_reset_reg <= data_gen_reset_next;
    data_check_enable_reg <= data_check_enable_next;
    data_check_reset_reg <= data_check_reset_next;

    active_cycle_count_reg <= active_cycle_count_next;

    write_count_reg <= write_count_next;
    read_count_reg <= read_count_next;

    in_axis_tdata_reg <= in_axis_tdata_next;
    in_axis_tvalid_reg <= in_axis_tvalid_next;

    out_axis_tready_reg <= out_axis_tready_next;

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        fifo_base_addr_reg <= FIFO_BASE_ADDR;
        fifo_size_mask_reg <= FIFO_SIZE_MASK;
        fifo_enable_reg <= 1'b0;
        fifo_reset_reg <= 1'b0;

        data_gen_enable_reg <= 1'b0;
        data_gen_reset_reg <= 1'b0;
        data_check_enable_reg <= 1'b0;
        data_check_reset_reg <= 1'b0;

        active_cycle_count_reg <= 0;

        write_count_reg <= 0;
        read_count_reg <= 0;

        in_axis_tvalid_reg <= in_axis_tvalid_next;
        out_axis_tready_reg <= out_axis_tready_next;
    end
end

axi_vfifo_raw #(
    .SEG_WIDTH(AXI_DATA_WIDTH),
    .SEG_CNT(1),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .LEN_WIDTH(AXI_ADDR_WIDTH),
    .CTRL_OUT_EN(0)
)
axi_vfifo_raw_inst (
    .clk(m_axi_clk),
    .rst(m_axi_rst),

    /*
     * Segmented data input (from encode logic)
     */
    .input_clk(clk),
    .input_rst(rst),
    .input_rst_out(),
    .input_watermark(),
    .input_data(in_axis_tdata_reg),
    .input_valid(in_axis_tvalid_reg),
    .input_ready(in_axis_tready),

    /*
     * Segmented data output (to decode logic)
     */
    .output_clk(clk),
    .output_rst(rst),
    .output_rst_out(),
    .output_data(out_axis_tdata),
    .output_valid(out_axis_tvalid),
    .output_ready(out_axis_tready_reg),
    .output_ctrl_data(),
    .output_ctrl_valid(),
    .output_ctrl_ready(1'b1),

    /*
     * AXI master interface
     */
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    /*
     * Reset sync
     */
    .rst_req_out(),
    .rst_req_in(1'b0),

    /*
     * Configuration
     */
    .cfg_fifo_base_addr(fifo_base_addr_sync_2_reg),
    .cfg_fifo_size_mask(fifo_size_mask_sync_2_reg),
    .cfg_enable(fifo_enable_sync_2_reg),
    .cfg_reset(fifo_reset_sync_2_reg),

    /*
     * Status
     */
    .sts_fifo_occupancy(fifo_occupancy),
    .sts_fifo_empty(),
    .sts_fifo_full(),
    .sts_reset(fifo_reset_status),
    .sts_active(fifo_active),
    .sts_write_active(),
    .sts_read_active()
);

endmodule

`resetall
