#!/usr/bin/env python
"""

Copyright (c) 2022 Alex Forencich

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

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi.stream import define_stream


IrqBus, IrqTransaction, IrqSource, IrqSink, IrqMonitor = define_stream("Irq",
    signals=["index", "valid", "ready"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.irq_source = IrqSource(IrqBus.from_prefix(dut, "in_irq"), dut.clk, dut.rst)
        self.irq_sink = IrqSink(IrqBus.from_prefix(dut, "out_irq"), dut.clk, dut.rst)

        dut.prescale.setimmediatevalue(0)
        dut.min_interval.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.irq_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.irq_sink.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test_irq(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.prescale.setimmediatevalue(249)
    dut.min_interval.setimmediatevalue(100)

    tb.log.info("Test interrupts (single shot)")

    for k in range(8):
        await tb.irq_source.send(IrqTransaction(index=k))

    for k in range(8):
        irq = await tb.irq_sink.recv()
        tb.log.info(irq)
        assert irq.index == k

    assert tb.irq_sink.empty()

    await Timer(110, 'us')

    assert tb.irq_sink.empty()

    tb.log.info("Test interrupts (multiple)")

    for n in range(5):
        for k in range(8):
            await tb.irq_source.send(IrqTransaction(index=k))

    for k in range(8):
        irq = await tb.irq_sink.recv()
        tb.log.info(irq)
        assert irq.index == k

    assert tb.irq_sink.empty()

    await Timer(99, 'us')

    assert tb.irq_sink.empty()

    await Timer(11, 'us')

    assert not tb.irq_sink.empty()

    for k in range(8):
        irq = await tb.irq_sink.recv()
        tb.log.info(irq)
        assert irq.index == k

    assert tb.irq_sink.empty()

    await Timer(110, 'us')

    assert tb.irq_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [
                run_test_irq
            ]:

        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


def test_irq_rate_limit(request):
    dut = "irq_rate_limit"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['IRQ_INDEX_WIDTH'] = 11

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
