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

from cocotbext.axi import AxiReadBus, AxiRamRead
from cocotbext.axi import AxiStreamBus, AxiStreamSink
from cocotbext.axi.stream import define_stream

DescBus, DescTransaction, DescSource, DescSink, DescMonitor = define_stream("Desc",
    signals=["addr", "len", "tag", "valid", "ready"],
    optional_signals=["id", "dest", "user"]
)

DescStatusBus, DescStatusTransaction, DescStatusSource, DescStatusSink, DescStatusMonitor = define_stream("DescStatus",
    signals=["tag", "error", "valid"],
    optional_signals=["len", "id", "dest", "user"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        # read interface
        self.read_desc_source = DescSource(DescBus.from_prefix(dut, "s_axis_read_desc"), dut.clk, dut.rst)
        self.read_desc_status_sink = DescStatusSink(DescStatusBus.from_prefix(dut, "m_axis_read_desc_status"), dut.clk, dut.rst)
        self.read_data_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis_read_data"), dut.clk, dut.rst)

        # AXI interface
        self.axi_ram = AxiRamRead(AxiReadBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst, size=2**16)

        dut.enable.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.read_desc_source.set_pause_generator(generator())
            self.axi_ram.r_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.read_data_sink.set_pause_generator(generator())
            self.axi_ram.ar_channel.set_pause_generator(generator())

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


async def run_test_read(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axi_ram.byte_lanes
    step_size = 1 if int(os.getenv("PARAM_ENABLE_UNALIGNED")) else byte_lanes
    tag_count = 2**len(tb.read_desc_source.bus.tag)

    cur_tag = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.enable.value = 1

    for length in list(range(1, byte_lanes*4+1))+[128]:
        for offset in list(range(0, byte_lanes*2, step_size))+list(range(4096-byte_lanes*2, 4096, step_size)):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset+0x1000
            test_data = bytearray([x % 256 for x in range(length)])

            tb.axi_ram.write(addr-128, b'\xaa'*(len(test_data)+256))
            tb.axi_ram.write(addr, test_data)

            tb.log.debug("%s", tb.axi_ram.hexdump_str((addr & ~0xf)-16, (((addr & 0xf)+length-1) & ~0xf)+48))

            desc = DescTransaction(addr=addr, len=len(test_data), tag=cur_tag, id=cur_tag)
            await tb.read_desc_source.send(desc)

            status = await tb.read_desc_status_sink.recv()

            read_data = await tb.read_data_sink.recv()

            tb.log.info("status: %s", status)
            tb.log.info("read_data: %s", read_data)

            assert int(status.tag) == cur_tag
            assert int(status.error) == 0
            assert read_data.tdata == test_data
            assert read_data.tid == cur_tag

            cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    factory = TestFactory(run_test_read)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("unaligned", [0, 1])
@pytest.mark.parametrize("axi_data_width", [8, 16, 32])
def test_axi_dma_rd(request, axi_data_width, unaligned):
    dut = "axi_dma_rd"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    axis_data_width = axi_data_width

    parameters['AXI_DATA_WIDTH'] = axi_data_width
    parameters['AXI_ADDR_WIDTH'] = 16
    parameters['AXI_STRB_WIDTH'] = parameters['AXI_DATA_WIDTH'] // 8
    parameters['AXI_ID_WIDTH'] = 8
    parameters['AXI_MAX_BURST_LEN'] = 16
    parameters['AXIS_DATA_WIDTH'] = axis_data_width
    parameters['AXIS_KEEP_ENABLE'] = int(parameters['AXIS_DATA_WIDTH'] > 8)
    parameters['AXIS_KEEP_WIDTH'] = parameters['AXIS_DATA_WIDTH'] // 8
    parameters['AXIS_LAST_ENABLE'] = 1
    parameters['AXIS_ID_ENABLE'] = 1
    parameters['AXIS_ID_WIDTH'] = 8
    parameters['AXIS_DEST_ENABLE'] = 0
    parameters['AXIS_DEST_WIDTH'] = 8
    parameters['AXIS_USER_ENABLE'] = 1
    parameters['AXIS_USER_WIDTH'] = 1
    parameters['LEN_WIDTH'] = 20
    parameters['TAG_WIDTH'] = 8
    parameters['ENABLE_SG'] = 0
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
