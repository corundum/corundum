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
from cocotbext.pcie.intel.ptile.interface import PTilePcieSink, PTileTxBus

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
        self.cpl_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_cpl_tlp"), dut.clk, dut.rst)
        self.msi_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_msi_wr_req_tlp"), dut.clk, dut.rst)
        self.sink = PTilePcieSink(PTileTxBus.from_prefix(dut, "tx_st"), dut.clk, dut.rst)
        self.sink.ready_latency = 3

        dut.tx_cdts_limit.setimmediatevalue(0)
        dut.tx_cdts_limit_tdm_idx.setimmediatevalue(0)

        dut.max_payload_size.setimmediatevalue(0)

        self.tx_fc_ph_limit = 0x080
        self.tx_fc_pd_limit = 0x0800
        self.tx_fc_nph_limit = 0x080
        self.tx_fc_npd_limit = 0x0800
        self.tx_fc_cplh_limit = 0x080
        self.tx_fc_cpld_limit = 0x0800

        cocotb.start_soon(self.run_fc_logic())

    def set_idle_generator(self, generator=None):
        if generator:
            self.rd_req_source.set_pause_generator(generator())
            self.wr_req_source.set_pause_generator(generator())
            self.cpl_source.set_pause_generator(generator())
            self.msi_source.set_pause_generator(generator())

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

    async def run_fc_logic(self):
        clock_edge_event = RisingEdge(self.dut.clk)

        while True:
            self.dut.tx_cdts_limit.value = self.tx_fc_ph_limit & 0xfff
            self.dut.tx_cdts_limit_tdm_idx.value = 0
            await clock_edge_event

            self.dut.tx_cdts_limit.value = self.tx_fc_nph_limit & 0xfff
            self.dut.tx_cdts_limit_tdm_idx.value = 1
            await clock_edge_event

            self.dut.tx_cdts_limit.value = self.tx_fc_cplh_limit & 0xfff
            self.dut.tx_cdts_limit_tdm_idx.value = 2
            await clock_edge_event

            self.dut.tx_cdts_limit.value = self.tx_fc_pd_limit & 0xffff
            self.dut.tx_cdts_limit_tdm_idx.value = 4
            await clock_edge_event

            self.dut.tx_cdts_limit.value = self.tx_fc_npd_limit & 0xffff
            self.dut.tx_cdts_limit_tdm_idx.value = 5
            await clock_edge_event

            self.dut.tx_cdts_limit.value = self.tx_fc_cpld_limit & 0xffff
            self.dut.tx_cdts_limit_tdm_idx.value = 6
            await clock_edge_event


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

        test_frame = PcieIfFrame.from_tlp(test_tlp)
        test_frame.seq = cur_seq

        test_tlps.append(test_tlp)
        test_frames.append(test_frame)
        if test_tlp.fmt_type == TlpType.MEM_WRITE:
            await tb.wr_req_source.send(test_frame)
        else:
            await tb.rd_req_source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    for test_tlp in test_tlps:
        rx_frame = await tb.sink.recv()

        rx_tlp = rx_frame.to_tlp()

        assert test_tlp == rx_tlp

        if rx_tlp.is_posted():
            tb.tx_fc_ph_limit += 1
            tb.tx_fc_pd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_nonposted():
            tb.tx_fc_nph_limit += 1
            tb.tx_fc_npd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_completion():
            tb.tx_fc_cplh_limit += 1
            tb.tx_fc_cpld_limit += rx_tlp.get_data_credits()

    assert tb.sink.empty()

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

        test_frame = PcieIfFrame.from_tlp(test_tlp)

        test_tlps.append(test_tlp)
        test_frames.append(test_frame)
        await tb.cpl_source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    for test_tlp in test_tlps:
        rx_frame = await tb.sink.recv()

        rx_tlp = rx_frame.to_tlp()

        assert test_tlp == rx_tlp

        if rx_tlp.is_posted():
            tb.tx_fc_ph_limit += 1
            tb.tx_fc_pd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_nonposted():
            tb.tx_fc_nph_limit += 1
            tb.tx_fc_npd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_completion():
            tb.tx_fc_cplh_limit += 1
            tb.tx_fc_cpld_limit += rx_tlp.get_data_credits()

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_msi(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    seq_count = 32

    cur_seq = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_tlps = []
    test_frames = []

    for k in range(10):
        test_tlp = Tlp()

        test_tlp.fmt_type = TlpType.MEM_WRITE
        test_tlp.set_addr_be_data(cur_seq*4, k.to_bytes(4, 'little'))

        test_frame = PcieIfFrame.from_tlp(test_tlp)

        test_tlps.append(test_tlp)
        test_frames.append(test_frame)
        await tb.msi_source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    for test_tlp in test_tlps:
        rx_frame = await tb.sink.recv()

        rx_tlp = rx_frame.to_tlp()

        assert test_tlp == rx_tlp

        if rx_tlp.is_posted():
            tb.tx_fc_ph_limit += 1
            tb.tx_fc_pd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_nonposted():
            tb.tx_fc_nph_limit += 1
            tb.tx_fc_npd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_completion():
            tb.tx_fc_cplh_limit += 1
            tb.tx_fc_cpld_limit += rx_tlp.get_data_credits()

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
            test_wr_tlps.append(test_tlp)
            test_frame = PcieIfFrame.from_tlp(test_tlp)
            test_frame.seq = cur_seq
            await tb.wr_req_source.send(test_frame)
        elif test_tlp.fmt_type == TlpType.MEM_READ:
            if addr >> 32:
                test_tlp.fmt_type = TlpType.MEM_READ_64
            test_tlp.set_addr_be(addr, length)
            test_tlp.tag = cur_seq
            test_rd_tlps.append(test_tlp)
            test_frame = PcieIfFrame.from_tlp(test_tlp)
            test_frame.seq = cur_seq
            await tb.rd_req_source.send(test_frame)
        elif test_tlp.fmt_type == TlpType.CPL_DATA:
            test_data = bytearray(itertools.islice(itertools.cycle(range(256)), length))
            test_tlp.byte_count = len(test_data)
            test_tlp.length = (test_tlp.byte_count+3) // 4
            test_tlp.set_data(test_data+b'\x00'*(3-(len(test_data)-1) % 4))
            test_tlp.tag = cur_seq
            test_cpl_tlps.append(test_tlp)
            test_frame = PcieIfFrame.from_tlp(test_tlp)
            test_frame.seq = cur_seq
            await tb.cpl_source.send(test_frame)

        cur_seq = (cur_seq + 1) % seq_count

    rx_wr_tlps = []
    rx_rd_tlps = []
    rx_cpl_tlps = []
    for k in range(len(test_wr_tlps) + len(test_rd_tlps) + len(test_cpl_tlps)):
        rx_frame = await tb.sink.recv()
        rx_tlp = rx_frame.to_tlp()

        if rx_tlp.fmt_type in (TlpType.MEM_WRITE, TlpType.MEM_WRITE_64):
            rx_wr_tlps.append(rx_tlp)
        elif rx_tlp.fmt_type in (TlpType.MEM_READ, TlpType.MEM_READ_64):
            rx_rd_tlps.append(rx_tlp)
        elif rx_tlp.fmt_type in (TlpType.CPL, TlpType.CPL_DATA):
            rx_cpl_tlps.append(rx_tlp)

        if rx_tlp.is_posted():
            tb.tx_fc_ph_limit += 1
            tb.tx_fc_pd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_nonposted():
            tb.tx_fc_nph_limit += 1
            tb.tx_fc_npd_limit += rx_tlp.get_data_credits()
        if rx_tlp.is_completion():
            tb.tx_fc_cplh_limit += 1
            tb.tx_fc_cpld_limit += rx_tlp.get_data_credits()

    for test_tlp in test_wr_tlps:
        assert test_tlp == rx_wr_tlps.pop(0)

    for test_tlp in test_rd_tlps:
        assert test_tlp == rx_rd_tlps.pop(0)

    for test_tlp in test_cpl_tlps:
        assert test_tlp == rx_cpl_tlps.pop(0)

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

    for test in [run_test_req, run_test_cpl]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()

    for test in [run_test_msi]:

        factory = TestFactory(test)
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
def test_pcie_ptile_if_tx(request, data_width):
    dut = "pcie_ptile_if_tx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "pcie_ptile_fc_counter.v"),
        os.path.join(rtl_dir, "pcie_tlp_fc_count.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_raw.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_mux.v"),
    ]

    parameters = {}

    parameters['SEG_COUNT'] = 2 if data_width == 512 else 1
    parameters['SEG_DATA_WIDTH'] = data_width // parameters['SEG_COUNT']
    parameters['SEG_HDR_WIDTH'] = 128
    parameters['SEG_PRFX_WIDTH'] = 32
    parameters['TLP_DATA_WIDTH'] = data_width
    parameters['TLP_STRB_WIDTH'] = parameters['TLP_DATA_WIDTH'] // 32
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_SEG_COUNT'] = 1
    parameters['TX_SEQ_NUM_WIDTH'] = 6

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
