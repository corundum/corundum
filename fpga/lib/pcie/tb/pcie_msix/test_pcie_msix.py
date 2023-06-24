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
import re
import sys
from contextlib import contextmanager

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotbext.axi.stream import define_stream


try:
    from pcie_if import PcieIfSink, PcieIfTxBus
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from pcie_if import PcieIfSink, PcieIfTxBus
    finally:
        del sys.path[0]


IrqBus, IrqTransaction, IrqSource, IrqSink, IrqMonitor = define_stream("Irq",
    signals=["index", "valid", "ready"]
)


@contextmanager
def assert_raises(exc_type, pattern=None):
    try:
        yield
    except exc_type as e:
        if pattern:
            assert re.match(pattern, str(e)), \
                "Correct exception type caught, but message did not match pattern"
        pass
    else:
        raise AssertionError("{} was not raised".format(exc_type.__name__))


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

        self.irq_source = IrqSource(IrqBus.from_prefix(dut, "irq"), dut.clk, dut.rst)

        self.tlp_sink = PcieIfSink(PcieIfTxBus.from_prefix(dut, "tx_wr_req_tlp"), dut.clk, dut.rst)

        dut.requester_id.setimmediatevalue(0)
        dut.msix_enable.setimmediatevalue(0)
        dut.msix_mask.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())
            self.tlp_sink.set_pause_generator(generator())

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


async def run_test_table_write(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes*4):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset+0x100
            test_data = bytearray([x % 256 for x in range(length)])

            await tb.axil_master.write(addr-4, b'\xaa'*(length+8))

            await tb.axil_master.write(addr, test_data)

            data = await tb.axil_master.read(addr-1, length+2)

            assert data.data == b'\xaa'+test_data+b'\xaa'

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_table_read(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes*4):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset+0x100
            test_data = bytearray([x % 256 for x in range(length)])

            await tb.axil_master.write(addr, test_data)

            data = await tb.axil_master.read(addr, length)

            assert data.data == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_msix(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    tbl_offset = 0
    pba_offset = 2**(tb.axil_master.write_if.address_width-1)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.msix_enable.value = 1

    tb.log.info("Init table")

    for k in range(2**len(dut.irq_index)):
        await tb.axil_master.write_qword(tbl_offset+k*16+0, 0x1234567800000000 + k*4)
        await tb.axil_master.write_dword(tbl_offset+k*16+8, k)
        await tb.axil_master.write_dword(tbl_offset+k*16+12, 0)

    tb.log.info("Test unmasked interrupts")

    for k in range(8):
        await tb.irq_source.send(IrqTransaction(index=k))

    for k in range(8):
        frame = await tb.tlp_sink.recv()
        tlp = frame.to_tlp()

        tb.log.info("TLP: %s", tlp)

        assert tlp.address == 0x1234567800000000 + k*4
        assert tlp.data == k.to_bytes(4, 'little')
        assert tlp.first_be == 0xf

    val = await tb.axil_master.read_dword(pba_offset+0)

    tb.log.info("PBA value: 0x%02x", val)

    assert val == 0x00

    tb.log.info("Test global mask")

    dut.msix_mask.value = 1

    for k in range(8):
        await tb.irq_source.send(IrqTransaction(index=k))

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    while dut.irq_valid.value.integer:
        await RisingEdge(dut.clk)
    for k in range(10):
        await RisingEdge(dut.clk)

    val = await tb.axil_master.read_dword(pba_offset+0)

    tb.log.info("PBA value: 0x%02x", val)

    assert val == 0xff

    dut.msix_mask.value = 0

    for k in range(8):
        frame = await tb.tlp_sink.recv()
        tlp = frame.to_tlp()

        tb.log.info("TLP: %s", tlp)

        assert tlp.address == 0x1234567800000000 + k*4
        assert tlp.data == k.to_bytes(4, 'little')
        assert tlp.first_be == 0xf

    val = await tb.axil_master.read_dword(pba_offset+0)

    tb.log.info("PBA value: 0x%02x", val)

    assert val == 0x00

    tb.log.info("Test vector masks")

    for k in range(8):
        await tb.axil_master.write_dword(tbl_offset+k*16+12, 1)

    for k in range(8):
        await tb.irq_source.send(IrqTransaction(index=k))

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    while dut.irq_valid.value.integer:
        await RisingEdge(dut.clk)
    for k in range(10):
        await RisingEdge(dut.clk)

    val = await tb.axil_master.read_dword(pba_offset+0)

    tb.log.info("PBA value: 0x%02x", val)

    assert val == 0xff

    for k in range(8):
        await tb.axil_master.write_dword(tbl_offset+k*16+12, 0)

    for k in range(8):
        frame = await tb.tlp_sink.recv()
        tlp = frame.to_tlp()

        tb.log.info("TLP: %s", tlp)

        assert tlp.address == 0x1234567800000000 + k*4
        assert tlp.data == k.to_bytes(4, 'little')
        assert tlp.first_be == 0xf

    val = await tb.axil_master.read_dword(pba_offset+0)

    tb.log.info("PBA value: 0x%02x", val)

    assert val == 0x00

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [
                run_test_table_write,
                run_test_table_read,
                run_test_msix
            ]:

        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("axil_data_width", [32, 64])
def test_pcie_msix(request, axil_data_width):
    dut = "pcie_msix"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['IRQ_INDEX_WIDTH'] = 11
    parameters['AXIL_DATA_WIDTH'] = axil_data_width
    parameters['AXIL_ADDR_WIDTH'] = parameters['IRQ_INDEX_WIDTH']+5
    parameters['AXIL_STRB_WIDTH'] = (axil_data_width // 8)
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_FORCE_64_BIT_ADDR'] = 0

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
