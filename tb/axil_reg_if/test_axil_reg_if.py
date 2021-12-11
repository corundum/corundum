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
import mmap
import os
import random

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

        dut.reg_wr_wait.setimmediatevalue(0)
        dut.reg_wr_ack.setimmediatevalue(0)
        dut.reg_rd_data.setimmediatevalue(0)
        dut.reg_rd_wait.setimmediatevalue(0)
        dut.reg_rd_ack.setimmediatevalue(0)

        self.mem = mmap.mmap(-1, 16384)

        cocotb.start_soon(self.run_reg_read())
        cocotb.start_soon(self.run_reg_write())

    def set_idle_generator(self, generator=None):
        if generator:
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
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

    async def run_reg_read(self):
        byte_lanes = len(self.dut.reg_wr_strb)

        while True:
            self.dut.reg_rd_data.value = 0
            self.dut.reg_rd_wait.value = 0
            self.dut.reg_rd_ack.value = 0
            await RisingEdge(self.dut.clk)

            addr = (self.dut.reg_rd_addr.value.integer // byte_lanes) * byte_lanes

            if self.dut.reg_rd_en.value.integer and addr < len(self.mem):
                self.dut.reg_rd_wait.value = 1

                for k in range(10):
                    await RisingEdge(self.dut.clk)

                self.mem.seek(addr)

                data = self.mem.read(byte_lanes)

                self.dut.reg_rd_data.value = int.from_bytes(data, 'little')
                self.dut.reg_rd_wait.value = 0
                self.dut.reg_rd_ack.value = 1
                await RisingEdge(self.dut.clk)

    async def run_reg_write(self):
        byte_lanes = len(self.dut.reg_wr_strb)

        while True:
            self.dut.reg_wr_wait.value = 0
            self.dut.reg_wr_ack.value = 0
            await RisingEdge(self.dut.clk)

            addr = (self.dut.reg_wr_addr.value.integer // byte_lanes) * byte_lanes
            data = self.dut.reg_wr_data.value.integer
            strb = self.dut.reg_wr_strb.value.integer

            if self.dut.reg_wr_en.value.integer and addr < len(self.mem):
                self.dut.reg_wr_wait.value = 1

                for k in range(10):
                    await RisingEdge(self.dut.clk)

                self.mem.seek(addr)

                data = data.to_bytes(byte_lanes, 'little')

                for i in range(byte_lanes):
                    if strb & (1 << i):
                        self.mem.write(data[i:i+1])
                    else:
                        self.mem.seek(1, 1)

                self.dut.reg_wr_wait.value = 0
                self.dut.reg_wr_ack.value = 1
                await RisingEdge(self.dut.clk)

    def mem_read(self, address, length):
        self.mem.seek(address)
        return self.mem.read(length)

    def mem_write(self, address, data):
        self.mem.seek(address)
        self.mem.write(bytes(data))


async def run_test_write(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes*2):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset+0x100
            test_data = bytearray([x % 256 for x in range(length)])

            tb.mem_write(addr-128, b'\xaa'*(length+256))

            await tb.axil_master.write(addr, test_data)

            tb.log.debug("%s", tb.mem_read((addr & ~0xf)-16, (((addr & 0xf)+length-1) & ~0xf)+48))

            assert tb.mem_read(addr, length) == test_data
            assert tb.mem_read(addr-1, 1) == b'\xaa'
            assert tb.mem_read(addr+length, 1) == b'\xaa'

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_read(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes*2):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset+0x100
            test_data = bytearray([x % 256 for x in range(length)])

            tb.mem_write(addr, test_data)

            data = await tb.axil_master.read(addr, length)

            assert data.data == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    async def worker(master, offset, aperture, count=16):
        for k in range(count):
            length = random.randint(1, min(32, aperture))
            addr = offset+random.randint(0, aperture-length)
            test_data = bytearray([x % 256 for x in range(length)])

            await Timer(random.randint(1, 100), 'ns')

            await master.write(addr, test_data)

            await Timer(random.randint(1, 100), 'ns')

            data = await master.read(addr, length)
            assert data.data == test_data

    workers = []

    for k in range(16):
        workers.append(cocotb.start_soon(worker(tb.axil_master, k*0x100, 0x100, count=16)))

    while workers:
        await workers.pop(0).join()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [run_test_write, run_test_read]:

        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()

    factory = TestFactory(run_stress_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("data_width", [8, 16, 32])
def test_axil_reg_if(request, data_width):
    dut = "axil_reg_if"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_rd.v"),
        os.path.join(rtl_dir, f"{dut}_wr.v"),
    ]

    parameters = {}

    parameters['DATA_WIDTH'] = data_width
    parameters['ADDR_WIDTH'] = 16
    parameters['STRB_WIDTH'] = parameters['DATA_WIDTH'] // 8
    parameters['TIMEOUT'] = 4

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    extra_env['COCOTB_RESOLVE_X'] = 'RANDOM'

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
