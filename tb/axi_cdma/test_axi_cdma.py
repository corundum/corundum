"""

Copyright (c) 2020 Alex Forencich

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
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiBus, AxiRam
from cocotbext.axi.stream import define_stream

DescBus, DescTransaction, DescSource, DescSink, DescMonitor = define_stream("Desc",
    signals=["read_addr", "write_addr", "len", "tag", "valid", "ready"]
)

DescStatusBus, DescStatusTransaction, DescStatusSource, DescStatusSink, DescStatusMonitor = define_stream("DescStatus",
    signals=["tag", "error", "valid"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        # control interface
        self.desc_source = DescSource(DescBus.from_prefix(dut, "s_axis_desc"), dut.clk, dut.rst)
        self.desc_status_sink = DescStatusSink(DescStatusBus.from_prefix(dut, "m_axis_desc_status"), dut.clk, dut.rst)

        # AXI interface
        self.axi_ram = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst, size=2**16)

        dut.enable.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.desc_source.set_pause_generator(generator())
            self.axi_ram.write_if.b_channel.set_pause_generator(generator())
            self.axi_ram.read_if.r_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axi_ram.write_if.aw_channel.set_pause_generator(generator())
            self.axi_ram.write_if.w_channel.set_pause_generator(generator())
            self.axi_ram.read_if.ar_channel.set_pause_generator(generator())

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


async def run_test(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axi_ram.write_if.byte_lanes
    step_size = 1 if int(os.getenv("PARAM_ENABLE_UNALIGNED")) else byte_lanes
    tag_count = 2**len(tb.desc_source.bus.tag)

    cur_tag = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.enable.value = 1

    for length in list(range(1, byte_lanes*4+1))+[128]:
        for read_offset in list(range(8, 8+byte_lanes*2, step_size))+list(range(4096-byte_lanes*2, 4096, step_size)):
            for write_offset in list(range(8, 8+byte_lanes*2, step_size))+list(range(4096-byte_lanes*2, 4096, step_size)):
                tb.log.info("length %d, read_offset %d, write_offset %d", length, read_offset, write_offset)
                read_addr = read_offset+0x1000
                write_addr = 0x00008000+write_offset+0x1000
                test_data = bytearray([x % 256 for x in range(length)])

                tb.axi_ram.write(read_addr, test_data)
                tb.axi_ram.write(write_addr & 0xffff80, b'\xaa'*(len(test_data)+256))

                desc = DescTransaction(read_addr=read_addr, write_addr=write_addr, len=len(test_data), tag=cur_tag)
                await tb.desc_source.send(desc)

                status = await tb.desc_status_sink.recv()

                tb.log.info("status: %s", status)
                assert int(status.tag) == cur_tag
                assert int(status.error) == 0

                tb.log.debug("%s", tb.axi_ram.hexdump_str((write_addr & ~0xf)-16, (((write_addr & 0xf)+length-1) & ~0xf)+48))

                assert tb.axi_ram.read(write_addr-8, len(test_data)+16) == b'\xaa'*8+test_data+b'\xaa'*8

                cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [run_test]:

        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("unaligned", [0, 1])
@pytest.mark.parametrize("axi_data_width", [8, 16, 32])
def test_axi_cdma(request, axi_data_width, unaligned):
    dut = "axi_cdma"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['AXI_DATA_WIDTH'] = axi_data_width
    parameters['AXI_ADDR_WIDTH'] = 16
    parameters['AXI_STRB_WIDTH'] = parameters['AXI_DATA_WIDTH'] // 8
    parameters['AXI_ID_WIDTH'] = 8
    parameters['AXI_MAX_BURST_LEN'] = 16
    parameters['LEN_WIDTH'] = 20
    parameters['TAG_WIDTH'] = 8
    parameters['ENABLE_UNALIGNED'] = unaligned

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
