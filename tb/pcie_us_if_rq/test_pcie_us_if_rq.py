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

from cocotbext.axi import AxiStreamBus
from cocotbext.pcie.core.tlp import Tlp, TlpType
from cocotbext.pcie.xilinx.us.interface import RqSink
from cocotbext.pcie.xilinx.us.tlp import Tlp_us

try:
    from pcie_if import PcieIfSource, PcieIfTxBus, PcieIfFrame
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from pcie_if import PcieIfSource, PcieIfTxBus, PcieIfFrame
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut, msix=False):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.rd_req_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_rd_req_tlp"), dut.clk, dut.rst)
        self.wr_req_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_wr_req_tlp"), dut.clk, dut.rst)
        self.sink = RqSink(AxiStreamBus.from_prefix(dut, "m_axis_rq"), dut.clk, dut.rst, segments=len(dut.out_tlp_valid))

        dut.s_axis_rq_seq_num_0.setimmediatevalue(0)
        dut.s_axis_rq_seq_num_valid_0.setimmediatevalue(0)
        dut.s_axis_rq_seq_num_1.setimmediatevalue(0)
        dut.s_axis_rq_seq_num_valid_1.setimmediatevalue(0)

        dut.tx_fc_ph_av.setimmediatevalue(0x80)
        dut.tx_fc_pd_av.setimmediatevalue(0x800)
        dut.tx_fc_nph_av.setimmediatevalue(0x80)
        dut.tx_fc_npd_av.setimmediatevalue(0x800)
        dut.max_payload_size.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.rd_req_source.set_pause_generator(generator())
            self.wr_req_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

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


async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

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

        test_frame = PcieIfFrame.from_tlp(test_tlp, force_64bit_addr=True)

        test_tlps.append(test_tlp)
        test_frames.append(test_frame)
        if test_tlp.fmt_type == TlpType.MEM_WRITE:
            await tb.wr_req_source.send(test_frame)
        else:
            await tb.rd_req_source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    for test_tlp in test_tlps:
        rx_frame = await tb.sink.recv()

        rx_tlp = Tlp(Tlp_us.unpack_us_rq(rx_frame))

        assert test_tlp == rx_tlp

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    seq_count = 32

    cur_seq = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_wr_tlps = []
    test_rd_tlps = []

    for k in range(128):
        length = random.randint(1, 512)
        test_tlp = Tlp()
        test_tlp.fmt_type = random.choice([TlpType.MEM_WRITE, TlpType.MEM_READ])
        if test_tlp.fmt_type == TlpType.MEM_WRITE:
            test_data = bytearray(itertools.islice(itertools.cycle(range(256)), length))
            test_tlp.set_addr_be_data(cur_seq*4, test_data)
        elif test_tlp.fmt_type == TlpType.MEM_READ:
            test_tlp.set_addr_be(cur_seq*4, length)
            test_tlp.tag = cur_seq

        test_frame = PcieIfFrame.from_tlp(test_tlp, force_64bit_addr=True)

        if test_tlp.fmt_type == TlpType.MEM_WRITE:
            test_wr_tlps.append(test_tlp)
            await tb.wr_req_source.send(test_frame)
        else:
            test_rd_tlps.append(test_tlp)
            await tb.rd_req_source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    rx_wr_tlps = []
    rx_rd_tlps = []
    for k in range(len(test_wr_tlps) + len(test_rd_tlps)):
        rx_frame = await tb.sink.recv()
        rx_tlp = Tlp(Tlp_us.unpack_us_rq(rx_frame))

        if rx_tlp.fmt_type == TlpType.MEM_WRITE:
            rx_wr_tlps.append(rx_tlp)
        elif rx_tlp.fmt_type == TlpType.MEM_READ:
            rx_rd_tlps.append(rx_tlp)

    for test_tlp in test_wr_tlps:
        assert test_tlp == rx_wr_tlps.pop(0)

    for test_tlp in test_rd_tlps:
        assert test_tlp == rx_rd_tlps.pop(0)

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    return list(range(0, 512+1, 4))+[4]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
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


@pytest.mark.parametrize(("axis_pcie_data_width", "straddle"),
    [(64, False), (128, False), (256, False), (512, False), (512, True)])
def test_pcie_us_if_rq(request, axis_pcie_data_width, straddle):
    dut = "pcie_us_if_rq"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_raw.v"),
    ]

    parameters = {}

    parameters['AXIS_PCIE_DATA_WIDTH'] = axis_pcie_data_width
    parameters['AXIS_PCIE_KEEP_WIDTH'] = parameters['AXIS_PCIE_DATA_WIDTH'] // 32
    parameters['AXIS_PCIE_RQ_USER_WIDTH'] = 62 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 137
    parameters['RQ_STRADDLE'] = int(parameters['AXIS_PCIE_DATA_WIDTH'] >= 512 and straddle)
    parameters['RQ_SEQ_NUM_WIDTH'] = 4 if parameters['AXIS_PCIE_RQ_USER_WIDTH'] == 60 else 6
    parameters['TLP_DATA_WIDTH'] = parameters['AXIS_PCIE_DATA_WIDTH']
    parameters['TLP_STRB_WIDTH'] = parameters['TLP_DATA_WIDTH'] // 32
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_SEG_COUNT'] = 1
    parameters['TX_SEQ_NUM_COUNT'] = 1 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 2
    parameters['TX_SEQ_NUM_WIDTH'] = parameters['RQ_SEQ_NUM_WIDTH']-1

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
