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

`timescale 1ns / 1ps

/*
 * Testbench for tdma_scheduler
 */
module test_tdma_scheduler;

// Parameters
parameter INDEX_WIDTH = 8;
parameter SCHEDULE_START_S = 48'h0;
parameter SCHEDULE_START_NS = 30'h0;
parameter SCHEDULE_PERIOD_S = 48'd0;
parameter SCHEDULE_PERIOD_NS = 30'd1000000;
parameter TIMESLOT_PERIOD_S = 48'd0;
parameter TIMESLOT_PERIOD_NS = 30'd100000;
parameter ACTIVE_PERIOD_S = 48'd0;
parameter ACTIVE_PERIOD_NS = 30'd100000;

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [95:0] input_ts_96 = 0;
reg input_ts_step = 0;
reg enable = 0;
reg [79:0] input_schedule_start = 0;
reg input_schedule_start_valid = 0;
reg [79:0] input_schedule_period = 0;
reg input_schedule_period_valid = 0;
reg [79:0] input_timeslot_period = 0;
reg input_timeslot_period_valid = 0;
reg [79:0] input_active_period = 0;
reg input_active_period_valid = 0;

// Outputs
wire locked;
wire error;
wire schedule_start;
wire [INDEX_WIDTH-1:0] timeslot_index;
wire timeslot_start;
wire timeslot_end;
wire timeslot_active;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        input_ts_96,
        input_ts_step,
        enable,
        input_schedule_start,
        input_schedule_start_valid,
        input_schedule_period,
        input_schedule_period_valid,
        input_timeslot_period,
        input_timeslot_period_valid,
        input_active_period,
        input_active_period_valid
    );
    $to_myhdl(
        locked,
        error,
        schedule_start,
        timeslot_index,
        timeslot_start,
        timeslot_end,
        timeslot_active
    );

    // dump file
    $dumpfile("test_tdma_scheduler.lxt");
    $dumpvars(0, test_tdma_scheduler);
end

tdma_scheduler #(
    .INDEX_WIDTH(INDEX_WIDTH),
    .SCHEDULE_START_S(SCHEDULE_START_S),
    .SCHEDULE_START_NS(SCHEDULE_START_NS),
    .SCHEDULE_PERIOD_S(SCHEDULE_PERIOD_S),
    .SCHEDULE_PERIOD_NS(SCHEDULE_PERIOD_NS),
    .TIMESLOT_PERIOD_S(TIMESLOT_PERIOD_S),
    .TIMESLOT_PERIOD_NS(TIMESLOT_PERIOD_NS),
    .ACTIVE_PERIOD_S(ACTIVE_PERIOD_S),
    .ACTIVE_PERIOD_NS(ACTIVE_PERIOD_NS)
)
UUT (
    .clk(clk),
    .rst(rst),
    .input_ts_96(input_ts_96),
    .input_ts_step(input_ts_step),
    .enable(enable),
    .input_schedule_start(input_schedule_start),
    .input_schedule_start_valid(input_schedule_start_valid),
    .input_schedule_period(input_schedule_period),
    .input_schedule_period_valid(input_schedule_period_valid),
    .input_timeslot_period(input_timeslot_period),
    .input_timeslot_period_valid(input_timeslot_period_valid),
    .input_active_period(input_active_period),
    .input_active_period_valid(input_active_period_valid),
    .locked(locked),
    .error(error),
    .schedule_start(schedule_start),
    .timeslot_index(timeslot_index),
    .timeslot_start(timeslot_start),
    .timeslot_end(timeslot_end),
    .timeslot_active(timeslot_active)
);

endmodule
