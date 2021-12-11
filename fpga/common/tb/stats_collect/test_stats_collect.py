"""

Copyright (c) 2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import itertools
import logging
import os
import random

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi.stream import define_stream


AxiStreamBus, AxiStreamTransaction, AxiStreamSource, AxiStreamSink, AxiStreamMonitor = define_stream("AxiStream",
    signals=["tvalid", "tdata"],
    optional_signals=["tready", "tkeep", "tlast", "tid", "tdest", "tuser"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.stat_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis_stat"), dut.clk, dut.rst)

        dut.stat_inc.setimmediatevalue(0)
        dut.stat_valid.setimmediatevalue(0)
        dut.update.setimmediatevalue(0)

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.stat_sink.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test_acc(dut, data_in=None, backpressure_inserter=None):

    tb = TB(dut)

    stat_count = len(dut.stat_valid)
    stat_inc_width = len(dut.stat_inc) // stat_count

    await tb.cycle_reset()

    tb.set_backpressure_generator(backpressure_inserter)

    for n in range(10):
        inc = 0
        valid = 0
        for k in range(stat_count):
            inc |= (k) << (stat_inc_width*k)
            valid |= 1 << k

        await RisingEdge(dut.clk)
        dut.stat_inc <= inc
        dut.stat_valid <= valid
        await RisingEdge(dut.clk)
        dut.stat_inc <= 0
        dut.stat_valid <= 0

        await Timer(1000, 'ns')

    await Timer(1000, 'ns')

    data = [0]*stat_count

    while not tb.stat_sink.empty():
        stat = await tb.stat_sink.recv()
        print(stat)

        assert stat.tdata != 0

        data[stat.tid] += stat.tdata

    print(data)

    for n in range(stat_count):
        assert data[n] == n*10

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_stress_test(dut, backpressure_inserter=None):

    tb = TB(dut)

    stat_count = len(dut.stat_valid)
    stat_inc_width = len(dut.stat_inc) // stat_count

    await tb.cycle_reset()

    tb.set_backpressure_generator(backpressure_inserter)

    async def worker(num, queue_ref, queue_drive, count=1024):
        for k in range(count):
            count = random.randrange(1, 2**stat_inc_width)

            await queue_drive.put(count)
            await queue_ref.put((num, count))

            await Timer(random.randint(1, 100), 'ns')

    workers = []
    queue_ref = Queue()
    queue_drive = [Queue() for k in range(stat_count)]

    for k in range(stat_count):
        workers.append(cocotb.start_soon(worker(k, queue_ref, queue_drive[k], count=1024)))

    async def driver(dut, queues):
        while True:
            await RisingEdge(dut.clk)

            inc = 0
            valid = 0
            for num, queue in enumerate(queues):
                if not queue.empty():
                    count = await queue.get()
                    inc |= (count) << (stat_inc_width*num)
                    valid |= 1 << num

            dut.stat_inc <= inc
            dut.stat_valid <= valid

    driver = cocotb.start_soon(driver(dut, queue_drive))

    while workers:
        await workers.pop(0).join()

    await Timer(1000, 'ns')

    driver.kill()

    await Timer(1000, 'ns')

    data_ref = [0]*stat_count

    while not queue_ref.empty():
        num, count = await queue_ref.get()
        data_ref[num] += count

    print(data_ref)

    data = [0]*stat_count

    while not tb.stat_sink.empty():
        stat = await tb.stat_sink.recv()
        # print(stat)

        assert stat.tdata != 0

        data[stat.tid] += stat.tdata

    print(data)

    assert data == data_ref

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [run_test_acc]:

        factory = TestFactory(test)
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()

    factory = TestFactory(run_stress_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


def test_stats_collect(request):
    dut = "stats_collect"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['COUNT'] = 8
    parameters['INC_WIDTH'] = 8
    parameters['STAT_INC_WIDTH'] = 16
    parameters['STAT_ID_WIDTH'] = (parameters['COUNT']-1).bit_length()
    parameters['UPDATE_PERIOD'] = 128

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
