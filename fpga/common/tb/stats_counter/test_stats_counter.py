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
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
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

        self.stat_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis_stat"), dut.clk, dut.rst)

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.stat_source.set_pause_generator(generator())
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())

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


async def run_test_acc(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axil_master.read_if.byte_lanes
    counter_size = max(int(os.getenv("PARAM_STAT_COUNT_WIDTH")) // 8, byte_lanes)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await Timer(4000, 'ns')

    for n in range(10):
        for k in range(10):
            await tb.stat_source.send(AxiStreamTransaction(tdata=k, tid=k))

        await Timer(1000, 'ns')

    data = await tb.axil_master.read_words(0, 10, ws=counter_size)

    print(data)

    for n in range(10):
        assert data[n] == n*10

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axil_master.read_if.byte_lanes
    counter_size = max(int(os.getenv("PARAM_STAT_COUNT_WIDTH")) // 8, byte_lanes)
    stat_inc_width = len(dut.s_axis_stat_tdata)
    stat_id_width = len(dut.s_axis_stat_tid)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await Timer(4000, 'ns')

    async def worker(source, queue, count=128):
        for k in range(count):
            count = random.randrange(1, 2**stat_inc_width)
            num = random.randrange(0, 2**stat_id_width)

            await source.send(AxiStreamTransaction(tdata=count, tid=num))

            await queue.put((num, count))

            await Timer(random.randint(1, 1000), 'ns')

    workers = []
    queue = Queue()

    for k in range(16):
        workers.append(cocotb.start_soon(worker(tb.stat_source, queue, count=128)))

    while workers:
        await workers.pop(0).join()

    await Timer(1000, 'ns')

    data_ref = [0]*2**stat_id_width

    while not queue.empty():
        num, count = await queue.get()
        data_ref[num] += count

    print(data_ref)

    data = await tb.axil_master.read_words(0, 2**stat_id_width, ws=counter_size)

    print(data)

    assert data == data_ref

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [run_test_acc]:

        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()

    factory = TestFactory(run_stress_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("stat_count_width", [32, 64])
def test_stats_counter(request, stat_count_width):
    dut = "stats_counter"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['STAT_INC_WIDTH'] = 16
    parameters['STAT_ID_WIDTH'] = 8
    parameters['STAT_COUNT_WIDTH'] = stat_count_width
    parameters['AXIL_DATA_WIDTH'] = 32
    parameters['AXIL_ADDR_WIDTH'] = parameters['STAT_ID_WIDTH'] + ((parameters['STAT_COUNT_WIDTH']+7)//8-1).bit_length()
    parameters['AXIL_STRB_WIDTH'] = parameters['AXIL_DATA_WIDTH'] // 8
    parameters['PIPELINE'] = 1

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
