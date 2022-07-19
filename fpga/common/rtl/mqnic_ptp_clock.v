/*

Copyright 2021, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

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
    parameter PTP_CLOCK_PIPELINE = 0,
    parameter PTP_CLOCK_CDC_PIPELINE = 0,
    parameter PTP_USE_SAMPLE_CLOCK = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,
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
    output wire                       ptp_pps,
    output wire                       ptp_pps_str,
    output wire [95:0]                ptp_ts_96,
    output wire                       ptp_ts_step,
    output wire                       ptp_sync_pps,
    output wire [95:0]                ptp_sync_ts_96,
    output wire                       ptp_sync_ts_step
);

parameter PTP_FNS_WIDTH = 32;

parameter PTP_CLK_PERIOD_NS = PTP_CLK_PERIOD_NS_NUM / PTP_CLK_PERIOD_NS_DENOM;
parameter PTP_CLK_PERIOD_NS_REM = PTP_CLK_PERIOD_NS_NUM - PTP_CLK_PERIOD_NS*PTP_CLK_PERIOD_NS_DENOM;
parameter PTP_CLK_PERIOD_FNS = (PTP_CLK_PERIOD_NS_REM * {32'd1, {PTP_FNS_WIDTH{1'b0}}}) / PTP_CLK_PERIOD_NS_DENOM;
parameter PTP_CLK_PERIOD_FNS_REM = (PTP_CLK_PERIOD_NS_REM * {32'd1, {PTP_FNS_WIDTH{1'b0}}}) - PTP_CLK_PERIOD_FNS*PTP_CLK_PERIOD_NS_DENOM;

parameter PTP_PERIOD_NS_WIDTH = $clog2(PTP_CLK_PERIOD_NS+1) + 2;
parameter PTP_OFFSET_NS_WIDTH = 32;

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

reg [95:0] get_ptp_ts_96_reg = 0;
reg [95:0] set_ptp_ts_96_reg = 0;
reg set_ptp_ts_96_valid_reg = 0;
reg [PTP_PERIOD_NS_WIDTH-1:0] set_ptp_period_ns_reg = PTP_CLK_PERIOD_NS;
reg [PTP_FNS_WIDTH-1:0] set_ptp_period_fns_reg = PTP_CLK_PERIOD_FNS;
reg set_ptp_period_valid_reg = 0;
reg [PTP_OFFSET_NS_WIDTH-1:0] set_ptp_offset_ns_reg = 0;
reg [PTP_FNS_WIDTH-1:0] set_ptp_offset_fns_reg = 0;
reg [15:0] set_ptp_offset_count_reg = 0;
reg set_ptp_offset_valid_reg = 0;
wire set_ptp_offset_active;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_ack_reg;
assign reg_rd_data = reg_rd_data_reg;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_ack_reg;

always @(posedge clk) begin
    reg_wr_ack_reg <= 1'b0;
    reg_rd_data_reg <= 0;
    reg_rd_ack_reg <= 1'b0;

    if (reg_wr_en && !reg_wr_ack_reg) begin
        // write operation
        reg_wr_ack_reg <= 1'b1;
        case ({reg_wr_addr >> 2, 2'b00})
            // PHC
            RBB+7'h30: set_ptp_ts_96_reg[15:0] <= reg_wr_data;  // PTP set fns
            RBB+7'h34: set_ptp_ts_96_reg[45:16] <= reg_wr_data; // PTP set ns
            RBB+7'h38: set_ptp_ts_96_reg[79:48] <= reg_wr_data; // PTP set sec l
            RBB+7'h3C: begin
                // PTP set sec h
                set_ptp_ts_96_reg[95:80] <= reg_wr_data;
                set_ptp_ts_96_valid_reg <= !set_ptp_ts_96_valid_reg;
            end
            RBB+7'h40: set_ptp_period_fns_reg <= reg_wr_data; // PTP period fns
            RBB+7'h44: begin
                // PTP period ns
                set_ptp_period_ns_reg <= reg_wr_data;
                set_ptp_period_valid_reg <= !set_ptp_period_valid_reg;
            end
            RBB+7'h50: set_ptp_offset_fns_reg <= reg_wr_data; // PTP offset fns
            RBB+7'h54: set_ptp_offset_ns_reg <= reg_wr_data;  // PTP offset ns
            RBB+7'h58: begin
                // PTP offset count
                set_ptp_offset_count_reg <= reg_wr_data;
                set_ptp_offset_valid_reg <= !set_ptp_offset_valid_reg;
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
            RBB+7'h04: reg_rd_data_reg <= 32'h00000100;  // PHC: Version
            RBB+7'h08: reg_rd_data_reg <= RB_NEXT_PTR;   // PHC: Next header
            RBB+7'h0C: begin
                // PHC features
                reg_rd_data_reg[7:0] <= PTP_PEROUT_ENABLE ? PTP_PEROUT_COUNT : 0;
                reg_rd_data_reg[15:8] <= 0;
                reg_rd_data_reg[23:16] <= 0;
                reg_rd_data_reg[31:24] <= 0;
            end
            RBB+7'h10: reg_rd_data_reg <= ptp_sync_ts_96[15:0];    // PTP cur fns
            RBB+7'h14: reg_rd_data_reg <= ptp_sync_ts_96[45:16];   // PTP cur ns
            RBB+7'h18: reg_rd_data_reg <= ptp_sync_ts_96[79:48];   // PTP cur sec l
            RBB+7'h1C: reg_rd_data_reg <= ptp_sync_ts_96[95:80];   // PTP cur sec h
            RBB+7'h20: begin
                // PTP get fns
                get_ptp_ts_96_reg <= ptp_sync_ts_96;
                reg_rd_data_reg <= ptp_sync_ts_96[15:0];
            end
            RBB+7'h24: reg_rd_data_reg <= get_ptp_ts_96_reg[45:16]; // PTP get ns
            RBB+7'h28: reg_rd_data_reg <= get_ptp_ts_96_reg[79:48]; // PTP get sec l
            RBB+7'h2C: reg_rd_data_reg <= get_ptp_ts_96_reg[95:80]; // PTP get sec h
            RBB+7'h30: reg_rd_data_reg <= set_ptp_ts_96_reg[15:0];  // PTP set fns
            RBB+7'h34: reg_rd_data_reg <= set_ptp_ts_96_reg[45:16]; // PTP set ns
            RBB+7'h38: reg_rd_data_reg <= set_ptp_ts_96_reg[79:48]; // PTP set sec l
            RBB+7'h3C: reg_rd_data_reg <= set_ptp_ts_96_reg[95:80]; // PTP set sec h
            RBB+7'h40: reg_rd_data_reg <= set_ptp_period_fns_reg;   // PTP period fns
            RBB+7'h44: reg_rd_data_reg <= set_ptp_period_ns_reg;    // PTP period ns
            RBB+7'h48: reg_rd_data_reg <= PTP_CLK_PERIOD_FNS;       // PTP nom period fns
            RBB+7'h4C: reg_rd_data_reg <= PTP_CLK_PERIOD_NS;        // PTP nom period ns
            RBB+7'h50: reg_rd_data_reg <= set_ptp_offset_fns_reg;   // PTP offset fns
            RBB+7'h54: reg_rd_data_reg <= set_ptp_offset_ns_reg;    // PTP offset ns
            RBB+7'h58: reg_rd_data_reg <= set_ptp_offset_count_reg; // PTP offset count
            RBB+7'h5C: reg_rd_data_reg <= set_ptp_offset_active;    // PTP offset status
            default: reg_rd_ack_reg <= 1'b0;
        endcase
    end

    if (rst) begin
        reg_wr_ack_reg <= 1'b0;
        reg_rd_ack_reg <= 1'b0;

        set_ptp_period_ns_reg <= PTP_CLK_PERIOD_NS;
        set_ptp_period_fns_reg <= PTP_CLK_PERIOD_FNS;
    end
end

(* shreg_extract = "no" *)
reg set_ptp_ts_96_valid_sync_1_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_ts_96_valid_sync_2_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_ts_96_valid_sync_3_reg = 1'b0;

(* shreg_extract = "no" *)
reg set_ptp_period_valid_sync_1_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_period_valid_sync_2_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_period_valid_sync_3_reg = 1'b0;

(* shreg_extract = "no" *)
reg set_ptp_offset_valid_sync_1_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_offset_valid_sync_2_reg = 1'b0;
(* shreg_extract = "no" *)
reg set_ptp_offset_valid_sync_3_reg = 1'b0;

always @(posedge ptp_clk) begin
    set_ptp_ts_96_valid_sync_1_reg <= set_ptp_ts_96_valid_reg;
    set_ptp_ts_96_valid_sync_2_reg <= set_ptp_ts_96_valid_sync_1_reg;
    set_ptp_ts_96_valid_sync_3_reg <= set_ptp_ts_96_valid_sync_2_reg;

    set_ptp_period_valid_sync_1_reg <= set_ptp_period_valid_reg;
    set_ptp_period_valid_sync_2_reg <= set_ptp_period_valid_sync_1_reg;
    set_ptp_period_valid_sync_3_reg <= set_ptp_period_valid_sync_2_reg;

    set_ptp_offset_valid_sync_1_reg <= set_ptp_offset_valid_reg;
    set_ptp_offset_valid_sync_2_reg <= set_ptp_offset_valid_sync_1_reg;
    set_ptp_offset_valid_sync_3_reg <= set_ptp_offset_valid_sync_2_reg;
end

// PTP clock
ptp_clock #(
    .PERIOD_NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .OFFSET_NS_WIDTH(PTP_OFFSET_NS_WIDTH),
    .FNS_WIDTH(PTP_FNS_WIDTH),
    .PERIOD_NS(PTP_CLK_PERIOD_NS),
    .PERIOD_FNS(PTP_CLK_PERIOD_FNS),
    .DRIFT_ENABLE(0),
    .DRIFT_NS(0),
    .DRIFT_FNS(PTP_CLK_PERIOD_FNS_REM),
    .DRIFT_RATE(PTP_CLK_PERIOD_NS_DENOM),
    .PIPELINE_OUTPUT(PTP_CLOCK_PIPELINE)
)
ptp_clock_inst (
    .clk(ptp_clk),
    .rst(ptp_rst),

    /*
     * Timestamp inputs for synchronization
     */
    .input_ts_96(set_ptp_ts_96_reg),
    .input_ts_96_valid(set_ptp_ts_96_valid_sync_2_reg ^ set_ptp_ts_96_valid_sync_3_reg),
    .input_ts_64(0),
    .input_ts_64_valid(1'b0),

    /*
     * Period adjustment
     */
    .input_period_ns(set_ptp_period_ns_reg),
    .input_period_fns(set_ptp_period_fns_reg),
    .input_period_valid(set_ptp_period_valid_sync_2_reg ^ set_ptp_period_valid_sync_3_reg),

    /*
     * Offset adjustment
     */
    .input_adj_ns(set_ptp_offset_ns_reg),
    .input_adj_fns(set_ptp_offset_fns_reg),
    .input_adj_count(set_ptp_offset_count_reg),
    .input_adj_valid(set_ptp_offset_valid_sync_2_reg ^ set_ptp_offset_valid_sync_3_reg),
    // .input_adj_active(set_ptp_offset_active),

    /*
     * Drift adjustment
     */
    .input_drift_ns(0),
    .input_drift_fns(0),
    .input_drift_rate(0),
    .input_drift_valid(0),

    /*
     * Timestamp outputs
     */
    .output_ts_96(ptp_ts_96),
    .output_ts_64(),
    .output_ts_step(ptp_ts_step),

    /*
     * PPS output
     */
    .output_pps(ptp_pps)
);

// stretched PPS output
localparam PPS_CNT_PERIOD = (64'd500_000_000*PTP_CLK_PERIOD_NS_DENOM)/PTP_CLK_PERIOD_NS_NUM;

reg [$clog2(PPS_CNT_PERIOD)-1:0] pps_counter_reg = 0;
reg pps_str_reg = 0;

always @(posedge ptp_clk) begin
    pps_str_reg <= 1'b0;

    if (ptp_pps) begin
        pps_counter_reg <= PPS_CNT_PERIOD;
        pps_str_reg <= 1'b1;
    end else if (pps_counter_reg > 0) begin
        pps_counter_reg <= pps_counter_reg - 1;
        pps_str_reg <= 1'b1;
    end
end

assign ptp_pps_str = pps_str_reg;

// sync to core clock domain
ptp_clock_cdc #(
    .TS_WIDTH(96),
    .NS_WIDTH(PTP_PERIOD_NS_WIDTH),
    .FNS_WIDTH(16),
    .USE_SAMPLE_CLOCK(PTP_USE_SAMPLE_CLOCK),
    .PIPELINE_OUTPUT(PTP_CLOCK_CDC_PIPELINE)
)
ptp_cdc_inst (
    .input_clk(ptp_clk),
    .input_rst(ptp_rst),
    .output_clk(clk),
    .output_rst(rst),
    .sample_clk(ptp_sample_clk),
    .input_ts(ptp_ts_96),
    .input_ts_step(ptp_ts_step),
    .output_ts(ptp_sync_ts_96),
    .output_ts_step(ptp_sync_ts_step),
    .output_pps(ptp_sync_pps),
    .locked()
);

endmodule

`resetall
