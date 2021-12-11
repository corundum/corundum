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
import sys

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource
from cocotbext.axi.stream import define_stream

try:
    from dma_psdp_ram import PsdpRamWrite, PsdpRamWriteBus
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from dma_psdp_ram import PsdpRamWrite, PsdpRamWriteBus
    finally:
        del sys.path[0]

DescBus, DescTransaction, DescSource, DescSink, DescMonitor = define_stream("Desc",
    signals=["ram_addr", "len", "tag", "valid", "ready"],
    optional_signals=["id", "dest", "user"]
)

DescStatusBus, DescStatusTransaction, DescStatusSource, DescStatusSink, DescStatusMonitor = define_stream("DescStatus",
    signals=["tag", "valid"],
    optional_signals=["len", "id", "dest", "user"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        # write interface
        self.write_desc_source = DescSource(DescBus.from_prefix(dut, "s_axis_write_desc"), dut.clk, dut.rst)
        self.write_desc_status_sink = DescStatusSink(DescStatusBus.from_prefix(dut, "m_axis_write_desc_status"), dut.clk, dut.rst)
        self.write_data_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis_write_data"), dut.clk, dut.rst)

        # DMA RAM
        self.dma_ram = PsdpRamWrite(PsdpRamWriteBus.from_prefix(dut, "ram"), dut.clk, dut.rst, size=2**16)

        dut.enable.setimmediatevalue(0)
        dut.abort.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.write_desc_source.set_pause_generator(generator())
            self.write_data_source.set_pause_generator(generator())
            # self.dma_ram.b_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        # if generator:
        #     self.dma_ram.aw_channel.set_pause_generator(generator())
        pass

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


async def run_test_write(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.dma_ram.byte_lanes
    step_size = tb.write_data_source.byte_lanes
    tag_count = 2**len(tb.write_desc_source.bus.tag)

    cur_tag = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.enable.value = 1

    for length in list(range(1, byte_lanes*3+1))+[128]:
        for offset in range(0, byte_lanes*2, step_size):
            for diff in [-8, -2, -1, 0, 1, 2, 8]:
                if length+diff < 1:
                    continue

                tb.log.info("length %d, offset %d, diff %d", length, offset, diff)
                ram_addr = offset+0x1000
                test_data = bytearray([x % 256 for x in range(length)])
                test_data2 = bytearray([x % 256 for x in range(length+diff)])

                tb.dma_ram.write(ram_addr-128, b'\xaa'*(len(test_data)+256))

                desc = DescTransaction(ram_addr=ram_addr, len=len(test_data), tag=cur_tag)
                await tb.write_desc_source.send(desc)

                await tb.write_data_source.send(AxiStreamFrame(test_data2, tid=cur_tag))

                status = await tb.write_desc_status_sink.recv()

                tb.log.info("status: %s", status)
                assert int(status.len) == min(len(test_data), len(test_data2))
                assert int(status.tag) == cur_tag
                assert int(status.id) == cur_tag

                tb.log.debug("%s", tb.dma_ram.hexdump_str((ram_addr & ~0xf)-16, (((ram_addr & 0xf)+length-1) & ~0xf)+48))

                if len(test_data) <= len(test_data2):
                    assert tb.dma_ram.read(ram_addr-8, len(test_data)+16) == b'\xaa'*8+test_data+b'\xaa'*8
                else:
                    assert tb.dma_ram.read(ram_addr-8, len(test_data2)+16) == b'\xaa'*8+test_data2+b'\xaa'*8

                cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    factory = TestFactory(run_test_write)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize(("ram_data_width", "axis_data_width"), [
    (128, 64), (128, 128),
    (256, 64), (256, 128),
])
def test_dma_client_axis_sink(request, ram_data_width, axis_data_width):
    dut = "dma_client_axis_sink"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    # segmented interface parameters
    seg_count = max(2, ram_data_width // 128)
    seg_data_width = ram_data_width // seg_count
    seg_addr_width = 12
    seg_be_width = seg_data_width // 8
    ram_addr_width = seg_addr_width + (seg_count*seg_be_width-1).bit_length()

    parameters['SEG_COUNT'] = seg_count
    parameters['SEG_DATA_WIDTH'] = seg_data_width
    parameters['SEG_ADDR_WIDTH'] = seg_addr_width
    parameters['SEG_BE_WIDTH'] = seg_be_width
    parameters['RAM_ADDR_WIDTH'] = ram_addr_width
    parameters['AXIS_DATA_WIDTH'] = axis_data_width
    parameters['AXIS_KEEP_ENABLE'] = int(axis_data_width > 8)
    parameters['AXIS_KEEP_WIDTH'] = axis_data_width // 8
    parameters['AXIS_LAST_ENABLE'] = 1
    parameters['AXIS_ID_ENABLE'] = 1
    parameters['AXIS_ID_WIDTH'] = 8
    parameters['AXIS_DEST_ENABLE'] = 1
    parameters['AXIS_DEST_WIDTH'] = 8
    parameters['AXIS_USER_ENABLE'] = 1
    parameters['AXIS_USER_WIDTH'] = 1
    parameters['LEN_WIDTH'] = 20
    parameters['TAG_WIDTH'] = 8

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
