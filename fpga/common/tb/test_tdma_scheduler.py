#!/usr/bin/env python
"""

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

"""

from myhdl import *
import os

import ptp

module = 'tdma_scheduler'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    INDEX_WIDTH = 8
    SCHEDULE_START_S = 0x0
    SCHEDULE_START_NS = 0x0
    SCHEDULE_PERIOD_S = 0
    SCHEDULE_PERIOD_NS = 1000000
    TIMESLOT_PERIOD_S = 0
    TIMESLOT_PERIOD_NS = 100000

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    input_ts_96 = Signal(intbv(0)[96:])
    input_ts_step = Signal(bool(0))
    enable = Signal(bool(0))
    input_schedule_start = Signal(intbv(0)[80:])
    input_schedule_start_valid = Signal(bool(0))
    input_schedule_period = Signal(intbv(0)[80:])
    input_schedule_period_valid = Signal(bool(0))
    input_timeslot_period = Signal(intbv(0)[80:])
    input_timeslot_period_valid = Signal(bool(0))
    input_active_period = Signal(intbv(0)[80:])
    input_active_period_valid = Signal(bool(0))

    # Outputs
    locked = Signal(bool(0))
    error = Signal(bool(0))
    schedule_start = Signal(bool(0))
    timeslot_index = Signal(intbv(0)[INDEX_WIDTH:])
    timeslot_start = Signal(bool(0))
    timeslot_end = Signal(bool(0))
    timeslot_active = Signal(bool(0))

    # PTP clock
    ptp_clock = ptp.PtpClock()

    ptp_logic = ptp_clock.create_logic(
        clk,
        rst,
        ts_96=input_ts_96
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        input_ts_96=input_ts_96,
        input_ts_step=input_ts_step,
        enable=enable,
        input_schedule_start=input_schedule_start,
        input_schedule_start_valid=input_schedule_start_valid,
        input_schedule_period=input_schedule_period,
        input_schedule_period_valid=input_schedule_period_valid,
        input_timeslot_period=input_timeslot_period,
        input_timeslot_period_valid=input_timeslot_period_valid,
        input_active_period=input_active_period,
        input_active_period_valid=input_active_period_valid,
        locked=locked,
        error=error,
        schedule_start=schedule_start,
        timeslot_index=timeslot_index,
        timeslot_start=timeslot_start,
        timeslot_end=timeslot_end,
        timeslot_active=timeslot_active
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    @instance
    def check():
        yield delay(100)
        yield clk.posedge
        rst.next = 1
        yield clk.posedge
        rst.next = 0
        yield clk.posedge
        yield delay(100)
        yield clk.posedge

        # testbench stimulus

        enable.next = 1

        yield clk.posedge
        print("test 1: Test pulse out")
        current_test.next = 1

        input_schedule_start.next = 1000
        input_schedule_start_valid.next = 1
        input_schedule_period.next = 2000
        input_schedule_period_valid.next = 1
        input_timeslot_period.next = 400
        input_timeslot_period_valid.next = 1
        input_active_period.next = 300
        input_active_period_valid.next = 1

        yield clk.posedge

        input_schedule_start_valid.next = 0
        input_schedule_period_valid.next = 0
        input_timeslot_period_valid.next = 0
        input_active_period_valid.next = 0

        yield delay(10000)

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
