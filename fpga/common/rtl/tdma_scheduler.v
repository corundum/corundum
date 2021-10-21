/*

Copyright 2019, The Regents of the University of California.
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
 * TDMA scheduler module
 */
module tdma_scheduler #
(
    // Timeslot index width
    parameter INDEX_WIDTH = 8,
    // Schedule absolute PTP start time, seconds part
    parameter SCHEDULE_START_S = 48'h0,
    // Schedule absolute PTP start time, nanoseconds part
    parameter SCHEDULE_START_NS = 30'h0,
    // Schedule period, seconds part
    parameter SCHEDULE_PERIOD_S = 48'd0,
    // Schedule period, nanoseconds part
    parameter SCHEDULE_PERIOD_NS = 30'd1000000,
    // Timeslot period, seconds part
    parameter TIMESLOT_PERIOD_S = 48'd0,
    // Timeslot period, nanoseconds part
    parameter TIMESLOT_PERIOD_NS = 30'd100000,
    // Timeslot active period, seconds part
    parameter ACTIVE_PERIOD_S = 48'd0,
    // Timeslot active period, nanoseconds part
    parameter ACTIVE_PERIOD_NS = 30'd100000
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * Timestamp input from PTP clock
     */
    input  wire [95:0]            input_ts_96,
    input  wire                   input_ts_step,

    /*
     * Control
     */
    input  wire                   enable,
    input  wire [79:0]            input_schedule_start,
    input  wire                   input_schedule_start_valid,
    input  wire [79:0]            input_schedule_period,
    input  wire                   input_schedule_period_valid,
    input  wire [79:0]            input_timeslot_period,
    input  wire                   input_timeslot_period_valid,
    input  wire [79:0]            input_active_period,
    input  wire                   input_active_period_valid,

    /*
     * Status
     */
    output wire                   locked,
    output wire                   error,

    /*
     * TDMA schedule outputs
     */
    output wire                   schedule_start,
    output wire [INDEX_WIDTH-1:0] timeslot_index,
    output wire                   timeslot_start,
    output wire                   timeslot_end,
    output wire                   timeslot_active
);

/*

      schedule
       start
         |
         V
         |<-------- schedule period -------->|
    -----+--------+--------+--------+--------+--------+---
         | SLOT 0 | SLOT 1 | SLOT 2 | SLOT 3 | SLOT 0 | 
    -----+--------+--------+--------+--------+--------+---
         |<------>|
          timeslot
           period


         |<-------- timeslot period -------->|
    -----+-----------------------------------+------------
         | SLOT 0                            | SLOT 1   
    -----+-----------------------------------+------------
         |<---- active period ----->|

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_UPDATE_SCHEDULE_1 = 3'd1,
    STATE_UPDATE_SCHEDULE_2 = 3'd2,
    STATE_UPDATE_SLOT_1 = 3'd3,
    STATE_UPDATE_SLOT_2 = 3'd4,
    STATE_UPDATE_SLOT_3 = 3'd5,
    STATE_WAIT = 3'd6;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg [47:0] time_s_reg = 0;
reg [30:0] time_ns_reg = 0;

reg [47:0] first_slot_s_reg = 0, first_slot_s_next;
reg [30:0] first_slot_ns_reg = 0, first_slot_ns_next;

reg [47:0] next_slot_s_reg = 0, next_slot_s_next;
reg [30:0] next_slot_ns_reg = 0, next_slot_ns_next;

reg [47:0] active_end_s_reg = 0, active_end_s_next;
reg [30:0] active_end_ns_reg = 0, active_end_ns_next;

reg [47:0] schedule_start_s_reg = SCHEDULE_START_S;
reg [30:0] schedule_start_ns_reg = SCHEDULE_START_NS;

reg [47:0] schedule_period_s_reg = SCHEDULE_PERIOD_S;
reg [30:0] schedule_period_ns_reg = SCHEDULE_PERIOD_NS;

reg [47:0] timeslot_period_s_reg = TIMESLOT_PERIOD_S;
reg [30:0] timeslot_period_ns_reg = TIMESLOT_PERIOD_NS;

reg [47:0] active_period_s_reg = ACTIVE_PERIOD_S;
reg [30:0] active_period_ns_reg = ACTIVE_PERIOD_NS;

reg [29:0] ts_ns_inc_reg = 0, ts_ns_inc_next;
reg [30:0] ts_ns_ovf_reg = 0, ts_ns_ovf_next;

reg locked_reg = 1'b0, locked_next;
reg locked_int_reg = 1'b0, locked_int_next;
reg error_reg = 1'b0, error_next;
reg schedule_running_reg = 1'b0, schedule_running_next;

reg schedule_start_reg = 1'b0, schedule_start_next;
reg [INDEX_WIDTH-1:0] timeslot_index_reg = 0, timeslot_index_next;
reg timeslot_start_reg = 1'b0, timeslot_start_next;
reg timeslot_end_reg = 1'b0, timeslot_end_next;
reg timeslot_active_reg = 1'b0, timeslot_active_next;

assign locked = locked_reg;
assign error = error_reg;

assign schedule_start = schedule_start_reg;
assign timeslot_index = timeslot_index_reg;
assign timeslot_start = timeslot_start_reg;
assign timeslot_end = timeslot_end_reg;
assign timeslot_active = timeslot_active_reg;

always @* begin
    state_next = STATE_IDLE;

    first_slot_s_next = first_slot_s_reg;
    first_slot_ns_next = first_slot_ns_reg;

    next_slot_s_next = next_slot_s_reg;
    next_slot_ns_next = next_slot_ns_reg;

    active_end_s_next = active_end_s_reg;
    active_end_ns_next = active_end_ns_reg;

    ts_ns_inc_next = ts_ns_inc_reg;

    ts_ns_ovf_next = ts_ns_ovf_reg;

    locked_next = locked_reg;
    locked_int_next = locked_int_reg;
    error_next = error_reg;
    schedule_running_next = schedule_running_reg;

    schedule_start_next = 1'b0;
    timeslot_index_next = timeslot_index_reg;
    timeslot_start_next = 1'b0;
    timeslot_end_next = 1'b0;
    timeslot_active_next = timeslot_active_reg;

    if (input_schedule_start_valid || input_schedule_period_valid || input_ts_step) begin
        timeslot_index_next = 0;
        timeslot_start_next = 1'b0;
        timeslot_end_next = timeslot_active_reg;
        timeslot_active_next = 1'b0;
        error_next = input_ts_step;
        state_next = STATE_IDLE;
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                // set next rise to start time
                first_slot_s_next = schedule_start_s_reg;
                first_slot_ns_next = schedule_start_ns_reg;
                next_slot_s_next = schedule_start_s_reg;
                next_slot_ns_next = schedule_start_ns_reg;
                timeslot_index_next = 0;
                timeslot_start_next = 1'b0;
                timeslot_end_next = timeslot_active_reg;
                timeslot_active_next = 1'b0;
                locked_next = 1'b0;
                locked_int_next = 1'b0;
                schedule_running_next = 1'b0;
                state_next = STATE_WAIT;
            end
            STATE_UPDATE_SCHEDULE_1: begin
                // set next schedule start time to next schedule start time plus schedule period
                ts_ns_inc_next = first_slot_ns_reg + schedule_period_ns_reg;
                ts_ns_ovf_next = first_slot_ns_reg + schedule_period_ns_reg - 31'd1_000_000_000;
                state_next = STATE_UPDATE_SCHEDULE_2;
            end
            STATE_UPDATE_SCHEDULE_2: begin
                if (!ts_ns_ovf_reg[30]) begin
                    // if the overflow lookahead did not borrow, one second has elapsed
                    first_slot_s_next = first_slot_s_reg + schedule_period_s_reg + 1;
                    first_slot_ns_next = ts_ns_ovf_reg;
                end else begin
                    // no increment seconds field
                    first_slot_s_next = first_slot_s_reg + schedule_period_s_reg;
                    first_slot_ns_next = ts_ns_inc_reg;
                end
                next_slot_s_next = first_slot_s_reg;
                next_slot_ns_next = first_slot_ns_reg;
                state_next = STATE_UPDATE_SLOT_1;
            end
            STATE_UPDATE_SLOT_1: begin
                // set next fall time to next rise time plus width
                ts_ns_inc_next = next_slot_ns_reg + active_period_ns_reg;
                ts_ns_ovf_next = next_slot_ns_reg + active_period_ns_reg - 31'd1_000_000_000;
                state_next = STATE_UPDATE_SLOT_2;
            end
            STATE_UPDATE_SLOT_2: begin
                if (!ts_ns_ovf_reg[30]) begin
                    // if the overflow lookahead did not borrow, one second has elapsed
                    active_end_s_next = next_slot_s_reg + active_period_s_reg + 1;
                    active_end_ns_next = ts_ns_ovf_reg;
                end else begin
                    // no increment seconds field
                    active_end_s_next = next_slot_s_reg + active_period_s_reg;
                    active_end_ns_next = ts_ns_inc_reg;
                end
                // set next timeslot start time to next timeslot start time plus timeslot period
                ts_ns_inc_next = next_slot_ns_reg + timeslot_period_ns_reg;
                ts_ns_ovf_next = next_slot_ns_reg + timeslot_period_ns_reg - 31'd1_000_000_000;
                state_next = STATE_UPDATE_SLOT_3;
            end
            STATE_UPDATE_SLOT_3: begin
                if (!ts_ns_ovf_reg[30]) begin
                    // if the overflow lookahead did not borrow, one second has elapsed
                    next_slot_s_next = next_slot_s_reg + timeslot_period_s_reg + 1;
                    next_slot_ns_next = ts_ns_ovf_reg;
                end else begin
                    // no increment seconds field
                    next_slot_s_next = next_slot_s_reg + timeslot_period_s_reg;
                    next_slot_ns_next = ts_ns_inc_reg;
                end
                state_next = STATE_WAIT;
            end
            STATE_WAIT: begin
                if ((time_s_reg > first_slot_s_reg) || (time_s_reg == first_slot_s_reg && time_ns_reg > first_slot_ns_reg)) begin
                    // start of next schedule period
                    schedule_start_next = enable && locked_int_reg;
                    timeslot_index_next = 0;
                    timeslot_start_next = enable && locked_int_reg;
                    timeslot_end_next = timeslot_active_reg;
                    timeslot_active_next = enable && locked_int_reg;
                    schedule_running_next = 1'b1;
                    locked_next = locked_int_reg;
                    error_next = error_reg && !locked_int_reg;
                    state_next = STATE_UPDATE_SCHEDULE_1;
                end else if ((time_s_reg > next_slot_s_reg) || (time_s_reg == next_slot_s_reg && time_ns_reg > next_slot_ns_reg)) begin
                    // start of next timeslot
                    timeslot_index_next = timeslot_index_reg + 1;
                    timeslot_start_next = enable && locked_reg;
                    timeslot_end_next = timeslot_active_reg;
                    timeslot_active_next = enable && locked_reg;
                    state_next = STATE_UPDATE_SLOT_1;
                end else if (timeslot_active_reg && ((time_s_reg > active_end_s_reg) || (time_s_reg == active_end_s_reg && time_ns_reg > active_end_ns_reg))) begin
                    // end of timeslot
                    timeslot_end_next = 1'b1;
                    timeslot_active_next = 1'b0;
                    state_next = STATE_WAIT;
                end else begin
                    locked_int_next = schedule_running_reg;
                    state_next = STATE_WAIT;
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    time_s_reg <= input_ts_96[95:48];
    time_ns_reg <= input_ts_96[45:16];

    if (input_schedule_start_valid) begin
        schedule_start_s_reg <= input_schedule_start[79:32];
        schedule_start_ns_reg <= input_schedule_start[31:0];
    end

    if (input_schedule_period_valid) begin
        schedule_period_s_reg <= input_schedule_period[79:32];
        schedule_period_ns_reg <= input_schedule_period[31:0];
    end

    if (input_timeslot_period_valid) begin
        timeslot_period_s_reg <= input_timeslot_period[79:32];
        timeslot_period_ns_reg <= input_timeslot_period[31:0];
    end

    if (input_active_period_valid) begin
        active_period_s_reg <= input_active_period[79:32];
        active_period_ns_reg <= input_active_period[31:0];
    end

    first_slot_s_reg <= first_slot_s_next;
    first_slot_ns_reg <= first_slot_ns_next;

    next_slot_s_reg <= next_slot_s_next;
    next_slot_ns_reg <= next_slot_ns_next;

    active_end_s_reg <= active_end_s_next;
    active_end_ns_reg <= active_end_ns_next;

    ts_ns_inc_reg <= ts_ns_inc_next;
    ts_ns_ovf_reg <= ts_ns_ovf_next;

    locked_reg <= locked_next;
    locked_int_reg <= locked_int_next;
    error_reg <= error_next;
    schedule_running_reg <= schedule_running_next;

    schedule_start_reg <= schedule_start_next;
    timeslot_index_reg <= timeslot_index_next;
    timeslot_start_reg <= timeslot_start_next;
    timeslot_end_reg <= timeslot_end_next;
    timeslot_active_reg <= timeslot_active_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        time_s_reg <= 0;
        time_ns_reg <= 0;

        schedule_start_s_reg <= SCHEDULE_START_S;
        schedule_start_ns_reg <= SCHEDULE_START_NS;

        schedule_period_s_reg <= SCHEDULE_PERIOD_S;
        schedule_period_ns_reg <= SCHEDULE_PERIOD_NS;

        timeslot_period_s_reg <= TIMESLOT_PERIOD_S;
        timeslot_period_ns_reg <= TIMESLOT_PERIOD_NS;

        active_period_s_reg <= ACTIVE_PERIOD_S;
        active_period_ns_reg <= ACTIVE_PERIOD_NS;

        locked_reg <= 1'b0;
        locked_int_reg <= 1'b0;
        error_reg <= 1'b0;
        schedule_running_reg <= 1'b0;

        schedule_start_reg <= 1'b0;
        timeslot_index_reg <= 0;
        timeslot_start_reg <= 1'b0;
        timeslot_end_reg <= 1'b0;
        timeslot_active_reg <= 1'b0;
    end
end

endmodule

`resetall
