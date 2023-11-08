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
module mqnic_ptp_clock #
(
    parameter PTP_CLK_PERIOD_NS_NUM = 4,
    parameter PTP_CLK_PERIOD_NS_DENOM = 1,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
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
     * PTP clock
     */
    input  wire                       ptp_clk,
    input  wire                       ptp_rst,
    input  wire                       ptp_sample_clk,
    output wire                       ptp_td_sd,
    output wire                       ptp_pps,
    output wire                       ptp_pps_str,
    output wire                       ptp_sync_locked,
    output wire [63:0]                ptp_sync_ts_rel,
    output wire                       ptp_sync_ts_rel_step,
    output wire [95:0]                ptp_sync_ts_tod,
    output wire                       ptp_sync_ts_tod_step,
    output wire                       ptp_sync_pps,
    output wire                       ptp_sync_pps_str
);

parameter PTP_FNS_WIDTH = 32;

parameter PTP_CLK_PERIOD_NS = PTP_CLK_PERIOD_NS_NUM / PTP_CLK_PERIOD_NS_DENOM;
parameter PTP_CLK_PERIOD_NS_REM = PTP_CLK_PERIOD_NS_NUM - PTP_CLK_PERIOD_NS*PTP_CLK_PERIOD_NS_DENOM;
parameter PTP_CLK_PERIOD_FNS = (PTP_CLK_PERIOD_NS_REM * {32'd1, {PTP_FNS_WIDTH{1'b0}}}) / PTP_CLK_PERIOD_NS_DENOM;
parameter PTP_CLK_PERIOD_FNS_REM = (PTP_CLK_PERIOD_NS_REM * {32'd1, {PTP_FNS_WIDTH{1'b0}}}) - PTP_CLK_PERIOD_FNS*PTP_CLK_PERIOD_NS_DENOM;

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

    if (RB_NEXT_PTR >= RB_BASE_ADDR && RB_NEXT_PTR < RB_BASE_ADDR + 7'h60) begin
        $error("Error: RB_NEXT_PTR overlaps block (instance %m)");
        $finish;
    end
end

// control registers
reg reg_wr_ack_reg = 1'b0;
reg [REG_DATA_WIDTH-1:0] reg_rd_data_reg = 0;
reg reg_rd_ack_reg = 1'b0;

reg [95:0] get_ptp_ts_tod_reg = 0;
reg [29:0] set_ptp_ts_tod_ns_reg = 0;
reg [47:0] set_ptp_ts_tod_s_reg = 0;

reg set_ptp_ts_tod_req_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_ts_tod_req_sync1_reg = 1'b0,  set_ptp_ts_tod_req_sync2_reg = 1'b0;

reg set_ptp_ts_tod_ack_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_ts_tod_ack_sync1_reg = 1'b0,  set_ptp_ts_tod_ack_sync2_reg = 1'b0;

reg set_ptp_ts_tod_valid_reg = 0;
wire set_ptp_ts_tod_ready;

reg [29:0] offset_ptp_ts_tod_ns_reg = 0;

reg offset_ptp_ts_tod_req_reg = 1'b0;
(* shreg_extract = "no" *)
reg offset_ptp_ts_tod_req_sync1_reg = 1'b0,  offset_ptp_ts_tod_req_sync2_reg = 1'b0;

reg offset_ptp_ts_tod_ack_reg = 1'b0;
(* shreg_extract = "no" *)
reg offset_ptp_ts_tod_ack_sync1_reg = 1'b0,  offset_ptp_ts_tod_ack_sync2_reg = 1'b0;

reg offset_ptp_ts_tod_valid_reg = 0;
wire offset_ptp_ts_tod_ready;

reg [63:0] get_ptp_ts_rel_reg = 0;
reg [47:0] set_ptp_ts_rel_ns_reg = 0;

reg set_ptp_ts_rel_req_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_ts_rel_req_sync1_reg = 1'b0,  set_ptp_ts_rel_req_sync2_reg = 1'b0;

reg set_ptp_ts_rel_ack_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_ts_rel_ack_sync1_reg = 1'b0,  set_ptp_ts_rel_ack_sync2_reg = 1'b0;

reg set_ptp_ts_rel_valid_reg = 0;
wire set_ptp_ts_rel_ready;

reg [31:0] offset_ptp_ts_rel_ns_reg = 0;

reg offset_ptp_ts_rel_req_reg = 1'b0;
(* shreg_extract = "no" *)
reg offset_ptp_ts_rel_req_sync1_reg = 1'b0,  offset_ptp_ts_rel_req_sync2_reg = 1'b0;

reg offset_ptp_ts_rel_ack_reg = 1'b0;
(* shreg_extract = "no" *)
reg offset_ptp_ts_rel_ack_sync1_reg = 1'b0,  offset_ptp_ts_rel_ack_sync2_reg = 1'b0;

reg offset_ptp_ts_rel_valid_reg = 0;
wire offset_ptp_ts_rel_ready;

reg [7:0] set_ptp_period_ns_reg = PTP_CLK_PERIOD_NS;
reg [PTP_FNS_WIDTH-1:0] set_ptp_period_fns_reg = PTP_CLK_PERIOD_FNS;

reg set_ptp_period_req_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_period_req_sync1_reg = 1'b0,  set_ptp_period_req_sync2_reg = 1'b0;

reg set_ptp_period_ack_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_period_ack_sync1_reg = 1'b0,  set_ptp_period_ack_sync2_reg = 1'b0;

reg set_ptp_period_valid_reg = 0;
wire set_ptp_period_ready;

reg [31:0] offset_ptp_ts_fns_reg = 0;

reg offset_ptp_ts_req_reg = 1'b0;
(* shreg_extract = "no" *)
reg offset_ptp_ts_req_sync1_reg = 1'b0,  offset_ptp_ts_req_sync2_reg = 1'b0;

reg offset_ptp_ts_ack_reg = 1'b0;
(* shreg_extract = "no" *)
reg offset_ptp_ts_ack_sync1_reg = 1'b0,  offset_ptp_ts_ack_sync2_reg = 1'b0;

reg offset_ptp_ts_valid_reg = 0;
wire offset_ptp_ts_ready;

always @(posedge ptp_clk) begin
    set_ptp_ts_tod_req_sync1_reg <= set_ptp_ts_tod_req_reg;
    set_ptp_ts_tod_req_sync2_reg <= set_ptp_ts_tod_req_sync1_reg;
    offset_ptp_ts_tod_req_sync1_reg <= offset_ptp_ts_tod_req_reg;
    offset_ptp_ts_tod_req_sync2_reg <= offset_ptp_ts_tod_req_sync1_reg;
    set_ptp_ts_rel_req_sync1_reg <= set_ptp_ts_rel_req_reg;
    set_ptp_ts_rel_req_sync2_reg <= set_ptp_ts_rel_req_sync1_reg;
    offset_ptp_ts_rel_req_sync1_reg <= offset_ptp_ts_rel_req_reg;
    offset_ptp_ts_rel_req_sync2_reg <= offset_ptp_ts_rel_req_sync1_reg;
    set_ptp_period_req_sync1_reg <= set_ptp_period_req_reg;
    set_ptp_period_req_sync2_reg <= set_ptp_period_req_sync1_reg;
    offset_ptp_ts_req_sync1_reg <= offset_ptp_ts_req_reg;
    offset_ptp_ts_req_sync2_reg <= offset_ptp_ts_req_sync1_reg;
end

always @(posedge clk) begin
    set_ptp_ts_tod_ack_sync1_reg <= set_ptp_ts_tod_ack_reg;
    set_ptp_ts_tod_ack_sync2_reg <= set_ptp_ts_tod_ack_sync1_reg;
    offset_ptp_ts_tod_ack_sync1_reg <= offset_ptp_ts_tod_ack_reg;
    offset_ptp_ts_tod_ack_sync2_reg <= offset_ptp_ts_tod_ack_sync1_reg;
    set_ptp_ts_rel_ack_sync1_reg <= set_ptp_ts_rel_ack_reg;
    set_ptp_ts_rel_ack_sync2_reg <= set_ptp_ts_rel_ack_sync1_reg;
    offset_ptp_ts_rel_ack_sync1_reg <= offset_ptp_ts_rel_ack_reg;
    offset_ptp_ts_rel_ack_sync2_reg <= offset_ptp_ts_rel_ack_sync1_reg;
    set_ptp_period_ack_sync1_reg <= set_ptp_period_ack_reg;
    set_ptp_period_ack_sync2_reg <= set_ptp_period_ack_sync1_reg;
    offset_ptp_ts_ack_sync1_reg <= offset_ptp_ts_ack_reg;
    offset_ptp_ts_ack_sync2_reg <= offset_ptp_ts_ack_sync1_reg;
end

always @(posedge ptp_clk) begin
    if (set_ptp_ts_tod_ack_reg) begin
        set_ptp_ts_tod_ack_reg <= set_ptp_ts_tod_req_sync2_reg;
    end else begin
        if (set_ptp_ts_tod_valid_reg && set_ptp_ts_tod_ready) begin
            set_ptp_ts_tod_valid_reg <= 1'b0;
            set_ptp_ts_tod_ack_reg <= 1'b1;
        end else begin
            set_ptp_ts_tod_valid_reg <= set_ptp_ts_tod_req_sync2_reg;
        end
    end

    if (offset_ptp_ts_tod_ack_reg) begin
        offset_ptp_ts_tod_ack_reg <= offset_ptp_ts_tod_req_sync2_reg;
    end else begin
        if (offset_ptp_ts_tod_valid_reg && offset_ptp_ts_tod_ready) begin
            offset_ptp_ts_tod_valid_reg <= 1'b0;
            offset_ptp_ts_tod_ack_reg <= 1'b1;
        end else begin
            offset_ptp_ts_tod_valid_reg <= offset_ptp_ts_tod_req_sync2_reg;
        end
    end

    if (set_ptp_ts_rel_ack_reg) begin
        set_ptp_ts_rel_ack_reg <= set_ptp_ts_rel_req_sync2_reg;
    end else begin
        if (set_ptp_ts_rel_valid_reg && set_ptp_ts_rel_ready) begin
            set_ptp_ts_rel_valid_reg <= 1'b0;
            set_ptp_ts_rel_ack_reg <= 1'b1;
        end else begin
            set_ptp_ts_rel_valid_reg <= set_ptp_ts_rel_req_sync2_reg;
        end
    end

    if (offset_ptp_ts_rel_ack_reg) begin
        offset_ptp_ts_rel_ack_reg <= offset_ptp_ts_rel_req_sync2_reg;
    end else begin
        if (offset_ptp_ts_rel_valid_reg && offset_ptp_ts_rel_ready) begin
            offset_ptp_ts_rel_valid_reg <= 1'b0;
            offset_ptp_ts_rel_ack_reg <= 1'b1;
        end else begin
            offset_ptp_ts_rel_valid_reg <= offset_ptp_ts_rel_req_sync2_reg;
        end
    end

    if (set_ptp_period_ack_reg) begin
        set_ptp_period_ack_reg <= set_ptp_period_req_sync2_reg;
    end else begin
        if (set_ptp_period_valid_reg && set_ptp_period_ready) begin
            set_ptp_period_valid_reg <= 1'b0;
            set_ptp_period_ack_reg <= 1'b1;
        end else begin
            set_ptp_period_valid_reg <= set_ptp_period_req_sync2_reg;
        end
    end

    if (offset_ptp_ts_ack_reg) begin
        offset_ptp_ts_ack_reg <= offset_ptp_ts_req_sync2_reg;
    end else begin
        if (offset_ptp_ts_valid_reg && offset_ptp_ts_ready) begin
            offset_ptp_ts_valid_reg <= 1'b0;
            offset_ptp_ts_ack_reg <= 1'b1;
        end else begin
            offset_ptp_ts_valid_reg <= offset_ptp_ts_req_sync2_reg;
        end
    end

    if (ptp_rst) begin
        set_ptp_ts_tod_ack_reg <= 1'b0;
        set_ptp_ts_tod_valid_reg <= 1'b0;
        offset_ptp_ts_tod_ack_reg <= 1'b0;
        offset_ptp_ts_tod_valid_reg <= 1'b0;
        set_ptp_ts_rel_ack_reg <= 1'b0;
        set_ptp_ts_rel_valid_reg <= 1'b0;
        offset_ptp_ts_rel_ack_reg <= 1'b0;
        offset_ptp_ts_rel_valid_reg <= 1'b0;
        set_ptp_period_ack_reg <= 1'b0;
        set_ptp_period_valid_reg <= 1'b0;
        offset_ptp_ts_ack_reg <= 1'b0;
        offset_ptp_ts_valid_reg <= 1'b0;
    end
end

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

always @(posedge clk) begin
    reg_wr_ack_reg <= 1'b0;
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    set_ptp_ts_tod_req_reg <= set_ptp_ts_tod_req_reg && !set_ptp_ts_tod_ack_sync2_reg;
    offset_ptp_ts_tod_req_reg <= offset_ptp_ts_tod_req_reg && !offset_ptp_ts_tod_ack_sync2_reg;
    set_ptp_ts_rel_req_reg <= set_ptp_ts_rel_req_reg && !set_ptp_ts_rel_ack_sync2_reg;
    offset_ptp_ts_rel_req_reg <= offset_ptp_ts_rel_req_reg && !offset_ptp_ts_rel_ack_sync2_reg;
    offset_ptp_ts_req_reg <= offset_ptp_ts_req_reg && !offset_ptp_ts_ack_sync2_reg;
    set_ptp_period_req_reg <= set_ptp_period_req_reg && !set_ptp_period_ack_sync2_reg;

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_reg <= 1'b1;
        case ({reg_wr_addr >> 2, 2'b00})
            // PHC
            RBB+7'h50: begin
                // PTP offset ToD
                if (!offset_ptp_ts_tod_req_reg || offset_ptp_ts_tod_ack_sync2_reg) begin
                    offset_ptp_ts_tod_ns_reg <= reg_wr_data;
                    offset_ptp_ts_tod_req_reg <= reg_wr_data != 0;
                end
            end
            RBB+7'h54: begin
                // PTP set ToD ns
                if (!set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg) begin
                    set_ptp_ts_tod_ns_reg <= reg_wr_data;
                end
            end
            RBB+7'h58: begin
                // PTP set ToD sec l
                if (!set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg) begin
                    set_ptp_ts_tod_s_reg[31:0] <= reg_wr_data;
                end
            end
            RBB+7'h5C: begin
                // PTP set ToD sec h
                if (!set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg) begin
                    set_ptp_ts_tod_s_reg[47:32] <= reg_wr_data;
                    set_ptp_ts_tod_req_reg <= 1'b1;
                end
            end
            RBB+7'h60: begin
                // PTP set rel ns l
                if (!set_ptp_ts_rel_req_reg || set_ptp_ts_rel_ack_sync2_reg) begin
                    set_ptp_ts_rel_ns_reg[31:0] <= reg_wr_data;
                end
            end
            RBB+7'h64: begin
                // PTP set rel ns h
                if (!set_ptp_ts_rel_req_reg || set_ptp_ts_rel_ack_sync2_reg) begin
                    set_ptp_ts_rel_ns_reg[47:32] <= reg_wr_data;
                    set_ptp_ts_rel_req_reg <= 1'b1;
                end
            end
            RBB+7'h68: begin
                // PTP offset rel
                if (!offset_ptp_ts_rel_req_reg || offset_ptp_ts_rel_ack_sync2_reg) begin
                    offset_ptp_ts_rel_ns_reg <= reg_wr_data;
                    offset_ptp_ts_rel_req_reg <= reg_wr_data != 0;
                end
            end
            RBB+7'h6C: begin
                // PTP offset FNS
                if (!offset_ptp_ts_req_reg || offset_ptp_ts_ack_sync2_reg) begin
                    offset_ptp_ts_fns_reg <= reg_wr_data;
                    offset_ptp_ts_req_reg <= reg_wr_data != 0;
                end
            end
            RBB+7'h78: begin
                // PTP period fns
                if (!set_ptp_period_req_reg || set_ptp_period_ack_sync2_reg) begin
                    set_ptp_period_fns_reg <= reg_wr_data;
                end
            end
            RBB+7'h7C: begin
                // PTP period ns
                if (!set_ptp_period_req_reg || set_ptp_period_ack_sync2_reg) begin
                    set_ptp_period_ns_reg <= reg_wr_data;
                    set_ptp_period_req_reg <= 1'b1;
                end
            end
            default: reg_wr_ack_reg <= 1'b0;
        endcase
    end

    if (reg_rd_en && !reg_rd_ack_reg) begin
        // read operation
        reg_rd_ack_reg <= 1'b1;
        case ({reg_rd_addr >> 2, 2'b00})
            // PHC
            RBB+7'h00: reg_rd_data_reg <= 32'h0000C080;  // PHC: Type
            RBB+7'h04: reg_rd_data_reg <= 32'h00000200;  // PHC: Version
            RBB+7'h08: reg_rd_data_reg <= RB_NEXT_PTR;   // PHC: Next header
            RBB+7'h0C: begin
                // PHC control
                reg_rd_data_reg[8] <= ptp_sync_pps_str;  // PPS
                reg_rd_data_reg[16] <= ptp_sync_locked;  // Locked
                reg_rd_data_reg[24] <= set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg;        // ToD set pending
                reg_rd_data_reg[25] <= offset_ptp_ts_tod_req_reg || offset_ptp_ts_tod_ack_sync2_reg;  // ToD offset pending
                reg_rd_data_reg[26] <= set_ptp_ts_rel_req_reg || set_ptp_ts_rel_ack_sync2_reg;        // Relative set pending
                reg_rd_data_reg[27] <= offset_ptp_ts_rel_req_reg || offset_ptp_ts_rel_ack_sync2_reg;  // Relative offset pending
                reg_rd_data_reg[28] <= set_ptp_period_req_reg || set_ptp_period_ack_sync2_reg;        // Period set pending
                reg_rd_data_reg[29] <= offset_ptp_ts_req_reg || offset_ptp_ts_ack_sync2_reg;          // FNS offset pending
            end
            RBB+7'h10: reg_rd_data_reg <= {ptp_sync_ts_tod[15:0], 16'd0};  // PTP cur fns
            RBB+7'h14: reg_rd_data_reg <= ptp_sync_ts_tod[47:16];          // PTP cur ToD ns
            RBB+7'h18: reg_rd_data_reg <= ptp_sync_ts_tod[79:48];          // PTP cur ToD sec l
            RBB+7'h1C: reg_rd_data_reg <= ptp_sync_ts_tod[95:80];          // PTP cur ToD sec h
            RBB+7'h20: reg_rd_data_reg <= ptp_sync_ts_rel[47:16];          // PTP cur rel ns l
            RBB+7'h24: reg_rd_data_reg <= ptp_sync_ts_rel[63:48];          // PTP cur rel ns h
            RBB+7'h28: reg_rd_data_reg <= 0;                               // PTP cur PTM l
            RBB+7'h2C: reg_rd_data_reg <= 0;                               // PTP cur PTM h
            RBB+7'h30: begin
                // PTP snapshot fns
                get_ptp_ts_tod_reg <= ptp_sync_ts_tod;
                get_ptp_ts_rel_reg <= ptp_sync_ts_rel;
                reg_rd_data_reg <= {ptp_sync_ts_tod[15:0], 16'd0};
            end
            RBB+7'h34: reg_rd_data_reg <= get_ptp_ts_tod_reg[45:16];    // PTP snapshot ToD ns
            RBB+7'h38: reg_rd_data_reg <= get_ptp_ts_tod_reg[79:48];    // PTP snapshot ToD sec l
            RBB+7'h3C: reg_rd_data_reg <= get_ptp_ts_tod_reg[95:80];    // PTP snapshot ToD sec h
            RBB+7'h40: reg_rd_data_reg <= get_ptp_ts_rel_reg[47:16];    // PTP snapshot rel ns l
            RBB+7'h44: reg_rd_data_reg <= get_ptp_ts_rel_reg[63:48];    // PTP snapshot rel ns h
            RBB+7'h48: reg_rd_data_reg <= 0;                            // PTP snapshot PTM l
            RBB+7'h4C: reg_rd_data_reg <= 0;                            // PTP snapshot PTM h
            RBB+7'h50: reg_rd_data_reg <= offset_ptp_ts_tod_ns_reg;     // PTP offset ToD
            RBB+7'h54: reg_rd_data_reg <= set_ptp_ts_tod_ns_reg;        // PTP set ToD ns
            RBB+7'h58: reg_rd_data_reg <= set_ptp_ts_tod_s_reg[31:0];   // PTP set ToD sec l
            RBB+7'h5C: reg_rd_data_reg <= set_ptp_ts_tod_s_reg[47:16];  // PTP set ToD sec h
            RBB+7'h60: reg_rd_data_reg <= set_ptp_ts_rel_ns_reg[31:0];  // PTP set rel ns l
            RBB+7'h64: reg_rd_data_reg <= set_ptp_ts_rel_ns_reg[47:16]; // PTP set rel ns h
            RBB+7'h68: reg_rd_data_reg <= offset_ptp_ts_rel_ns_reg;     // PTP offset rel
            RBB+7'h6C: reg_rd_data_reg <= offset_ptp_ts_fns_reg;        // PTP offset FNS
            RBB+7'h70: reg_rd_data_reg <= PTP_CLK_PERIOD_FNS;           // PTP nom period fns
            RBB+7'h74: reg_rd_data_reg <= PTP_CLK_PERIOD_NS;            // PTP nom period ns
            RBB+7'h78: reg_rd_data_reg <= set_ptp_period_fns_reg;       // PTP period fns
            RBB+7'h7C: reg_rd_data_reg <= set_ptp_period_ns_reg;        // PTP period ns
            default: reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        set_ptp_period_ns_reg <= PTP_CLK_PERIOD_NS;
        set_ptp_period_fns_reg <= PTP_CLK_PERIOD_FNS;

        set_ptp_ts_tod_req_reg <= 1'b0;
        offset_ptp_ts_tod_req_reg <= 1'b0;
        set_ptp_ts_rel_req_reg <= 1'b0;
        offset_ptp_ts_rel_req_reg <= 1'b0;
        offset_ptp_ts_req_reg <= 1'b0;
        set_ptp_period_req_reg <= 1'b0;
    end
end

// PTP clock
ptp_td_phc #(
    .PERIOD_NS_NUM(PTP_CLK_PERIOD_NS_NUM),
    .PERIOD_NS_DENOM(PTP_CLK_PERIOD_NS_DENOM)
)
ptp_td_phc_inst (
    .clk(ptp_clk),
    .rst(ptp_rst),

    /*
     * ToD timestamp control
     */
    .input_ts_tod_s(set_ptp_ts_tod_s_reg),
    .input_ts_tod_ns(set_ptp_ts_tod_ns_reg),
    .input_ts_tod_valid(set_ptp_ts_tod_valid_reg),
    .input_ts_tod_ready(set_ptp_ts_tod_ready),
    .input_ts_tod_offset_ns(offset_ptp_ts_tod_ns_reg),
    .input_ts_tod_offset_valid(offset_ptp_ts_tod_valid_reg),
    .input_ts_tod_offset_ready(offset_ptp_ts_tod_ready),

    /*
     * Relative timestamp control
     */
    .input_ts_rel_ns(set_ptp_ts_rel_ns_reg),
    .input_ts_rel_valid(set_ptp_ts_rel_valid_reg),
    .input_ts_rel_ready(set_ptp_ts_rel_ready),
    .input_ts_rel_offset_ns(offset_ptp_ts_rel_ns_reg),
    .input_ts_rel_offset_valid(offset_ptp_ts_rel_valid_reg),
    .input_ts_rel_offset_ready(offset_ptp_ts_rel_ready),

    /*
     * Fractional ns control
     */
    .input_ts_offset_fns(offset_ptp_ts_fns_reg),
    .input_ts_offset_valid(offset_ptp_ts_valid_reg),
    .input_ts_offset_ready(offset_ptp_ts_ready),

    /*
     * Period control
     */
    .input_period_ns(set_ptp_period_ns_reg),
    .input_period_fns(set_ptp_period_fns_reg),
    .input_period_valid(set_ptp_period_valid_reg),
    .input_period_ready(set_ptp_period_ready),
    .input_drift_num(0),
    .input_drift_denom(0),
    .input_drift_valid(1'b0),
    .input_drift_ready(),

    /*
     * Time distribution serial data output
     */
    .ptp_td_sdo(ptp_td_sd),

    /*
     * PPS output
     */
    .output_pps(ptp_pps),
    .output_pps_str(ptp_pps_str)
);

// sync to core clock domain
ptp_td_leaf #(
    .TS_REL_EN(1),
    .TS_TOD_EN(1),
    .TS_FNS_W(16),
    .TS_REL_NS_W(48),
    .TS_TOD_S_W(48),
    .TS_REL_W(64),
    .TS_TOD_W(96),
    .TD_SDI_PIPELINE(PTP_CLOCK_CDC_PIPELINE)
)
ptp_td_leaf_inst (
    .clk(clk),
    .rst(rst),
    .sample_clk(ptp_sample_clk),

    /*
     * PTP clock interface
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_td_sdi(ptp_td_sd),

    /*
     * Timestamp output
     */
    .output_ts_rel(ptp_sync_ts_rel),
    .output_ts_rel_step(ptp_sync_ts_rel_step),
    .output_ts_tod(ptp_sync_ts_tod),
    .output_ts_tod_step(ptp_sync_ts_tod_step),

    /*
     * PPS output (ToD format only)
     */
    .output_pps(ptp_sync_pps),
    .output_pps_str(ptp_sync_pps_str),

    /*
     * Status
     */
    .locked(ptp_sync_locked)
);

endmodule

`resetall
