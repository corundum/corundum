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
import random
import sys

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.pcie.core.tlp import Tlp, TlpType
from cocotbext.pcie.intel.ptile.interface import PTilePcieSource, PTileRxBus, PTilePcieFrame

try:
    from pcie_if import PcieIfSink, PcieIfRxBus
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from pcie_if import PcieIfSink, PcieIfRxBus
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut, msix=False):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.source = PTilePcieSource(PTileRxBus.from_prefix(dut, "rx_st"), dut.clk, dut.rst)
        self.source.ready_latency = 18 if self.source.width == 512 else 17
        self.req_sink = PcieIfSink(PcieIfRxBus.from_prefix(dut, "rx_req_tlp"), dut.clk, dut.rst)
        self.cpl_sink = PcieIfSink(PcieIfRxBus.from_prefix(dut, "rx_cpl_tlp"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.req_sink.set_pause_generator(generator())
            self.cpl_sink.set_pause_generator(generator())

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


async def run_test_req(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    seq_count = 32

    cur_seq = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_tlps = []
    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_tlp = Tlp()

        if len(test_data):
            test_tlp.fmt_type = TlpType.MEM_WRITE
            test_tlp.set_addr_be_data(cur_seq*4, test_data)
        else:
            test_tlp.fmt_type = TlpType.MEM_READ
            test_tlp.set_addr_be(cur_seq*4, 4)

        test_frame = PTilePcieFrame.from_tlp(test_tlp)

        test_tlps.append(test_tlp)
        test_frames.append(test_frame)
        await tb.source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    for test_tlp in test_tlps:
        rx_frame = await tb.req_sink.recv()

        rx_tlp = rx_frame.to_tlp()

        assert test_tlp == rx_tlp

    assert tb.req_sink.empty()
    assert tb.cpl_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_cpl(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    seq_count = 32

    cur_seq = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_tlps = []
    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_tlp = Tlp()

        if len(test_data):
            test_tlp.fmt_type = TlpType.CPL_DATA
            test_tlp.byte_count = len(test_data)
            test_tlp.length = test_tlp.byte_count // 4
            test_tlp.set_data(test_data)
            test_tlp.tag = cur_seq
        else:
            test_tlp.fmt_type = TlpType.CPL
            test_tlp.byte_count = 4
            test_tlp.length = 0
            test_tlp.tag = cur_seq

        test_frame = PTilePcieFrame.from_tlp(test_tlp)

        test_tlps.append(test_tlp)
        test_frames.append(test_frame)
        await tb.source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    for test_tlp in test_tlps:
        rx_frame = await tb.cpl_sink.recv()

        rx_tlp = rx_frame.to_tlp()

        assert test_tlp == rx_tlp

    assert tb.req_sink.empty()
    assert tb.cpl_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    seq_count = 32

    cur_seq = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_req_tlps = []
    test_cpl_tlps = []

    for k in range(128):
        length = random.randint(1, 512)
        test_tlp = Tlp()
        test_tlp.fmt_type = random.choice([TlpType.MEM_WRITE, TlpType.MEM_READ, TlpType.CPL_DATA])
        addr = cur_seq*4 + random.choice([0x12340000, 0x123400000000])
        if test_tlp.fmt_type == TlpType.MEM_WRITE:
            if addr >> 32:
                test_tlp.fmt_type = TlpType.MEM_WRITE_64
            test_data = bytearray(itertools.islice(itertools.cycle(range(256)), length))
            test_tlp.set_addr_be_data(addr, test_data)
            test_req_tlps.append(test_tlp)
        elif test_tlp.fmt_type == TlpType.MEM_READ:
            if addr >> 32:
                test_tlp.fmt_type = TlpType.MEM_READ_64
            test_tlp.set_addr_be(addr, length)
            test_tlp.tag = cur_seq
            test_req_tlps.append(test_tlp)
        elif test_tlp.fmt_type == TlpType.CPL_DATA:
            test_data = bytearray(itertools.islice(itertools.cycle(range(256)), length))
            test_tlp.byte_count = len(test_data)
            test_tlp.length = (test_tlp.byte_count+3) // 4
            test_tlp.set_data(test_data+b'\x00'*(3-(len(test_data)-1) % 4))
            test_tlp.tag = cur_seq
            test_cpl_tlps.append(test_tlp)

        test_frame = PTilePcieFrame.from_tlp(test_tlp)

        await tb.source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    for test_tlp in test_req_tlps:
        rx_frame = await tb.req_sink.recv()

        rx_tlp = rx_frame.to_tlp()

        assert test_tlp == rx_tlp

    for test_tlp in test_cpl_tlps:
        rx_frame = await tb.cpl_sink.recv()

        rx_tlp = rx_frame.to_tlp()

        assert test_tlp == rx_tlp

    assert tb.req_sink.empty()
    assert tb.cpl_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    return list(range(0, 512+1, 4))+[4]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    for test in [run_test_req, run_test_cpl]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()

    factory = TestFactory(run_stress_test)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("data_width", [128, 256, 512])
def test_pcie_ptile_if_rx(request, data_width):
    dut = "pcie_ptile_if_rx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_raw.v"),
    ]

    parameters = {}

    parameters['SEG_COUNT'] = 2 if data_width == 512 else 1
    parameters['SEG_DATA_WIDTH'] = data_width // parameters['SEG_COUNT']
    parameters['SEG_EMPTY_WIDTH'] = ((parameters['SEG_DATA_WIDTH'] // 32) - 1).bit_length()
    parameters['SEG_HDR_WIDTH'] = 128
    parameters['SEG_PRFX_WIDTH'] = 32
    parameters['TLP_DATA_WIDTH'] = data_width
    parameters['TLP_STRB_WIDTH'] = parameters['TLP_DATA_WIDTH'] // 32
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_SEG_COUNT'] = 1
    parameters['IO_BAR_INDEX'] = 3

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
