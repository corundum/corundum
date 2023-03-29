"""

Copyright (c) 2023 Alex Forencich

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
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiBus, AxiRam
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())

        # streaming data in
        cocotb.start_soon(Clock(dut.s_axis_clk, 6, units="ns").start())
        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.s_axis_clk, dut.s_axis_rst_out)

        # streaming data out
        cocotb.start_soon(Clock(dut.m_axis_clk, 6, units="ns").start())
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.m_axis_clk, dut.m_axis_rst_out)

        # AXI interfaces
        self.axi_ram = []
        for ch in dut.axi_ch:
            cocotb.start_soon(Clock(ch.ch_clk, 3, units="ns").start())
            ram = AxiRam(AxiBus.from_prefix(ch.axi_vfifo_raw_inst, "m_axi"), ch.ch_clk, ch.ch_rst, size=2**16)
            self.axi_ram.append(ram)

        dut.cfg_fifo_base_addr.setimmediatevalue(0)
        dut.cfg_fifo_size_mask.setimmediatevalue(0)
        dut.cfg_enable.setimmediatevalue(0)
        dut.cfg_reset.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())
            for ram in self.axi_ram:
                ram.write_if.b_channel.set_pause_generator(generator())
                ram.read_if.r_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())
            for ram in self.axi_ram:
                ram.write_if.aw_channel.set_pause_generator(generator())
                ram.write_if.w_channel.set_pause_generator(generator())
                ram.read_if.ar_channel.set_pause_generator(generator())

    def set_stream_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_stream_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    def set_axi_0_idle_generator(self, generator=None):
        if generator:
            self.axi_ram[0].write_if.b_channel.set_pause_generator(generator())
            self.axi_ram[0].read_if.r_channel.set_pause_generator(generator())

    def set_axi_0_backpressure_generator(self, generator=None):
        if generator:
            self.axi_ram[0].write_if.aw_channel.set_pause_generator(generator())
            self.axi_ram[0].write_if.w_channel.set_pause_generator(generator())
            self.axi_ram[0].read_if.ar_channel.set_pause_generator(generator())

    def set_axi_idle_generator(self, generator=None):
        if generator:
            for ram in self.axi_ram:
                ram.write_if.b_channel.set_pause_generator(generator())
                ram.read_if.r_channel.set_pause_generator(generator())

    def set_axi_backpressure_generator(self, generator=None):
        if generator:
            for ram in self.axi_ram:
                ram.write_if.aw_channel.set_pause_generator(generator())
                ram.write_if.w_channel.set_pause_generator(generator())
                ram.read_if.ar_channel.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        self.dut.s_axis_rst.setimmediatevalue(0)
        self.dut.m_axis_rst.setimmediatevalue(0)
        for ram in self.axi_ram:
            ram.write_if.reset.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        self.dut.s_axis_rst.value = 1
        self.dut.m_axis_rst.value = 1
        for ram in self.axi_ram:
            ram.write_if.reset.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        self.dut.s_axis_rst.value = 0
        self.dut.m_axis_rst.value = 0
        for ram in self.axi_ram:
            ram.write_if.reset.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)

    async def reset_source(self):
        self.dut.s_axis_rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.s_axis_clk)
        self.dut.s_axis_rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.s_axis_clk)
        self.dut.s_axis_rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.s_axis_clk)

    async def reset_sink(self):
        self.dut.m_axis_rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.m_axis_clk)
        self.dut.m_axis_rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.m_axis_clk)
        self.dut.m_axis_rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.m_axis_clk)

    async def reset_axi_0(self):
        self.axi_ram[0].write_if.reset.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.axi_ram[0].write_if.reset.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.axi_ram[0].write_if.reset.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)

    async def reset_axi(self):
        for ram in self.axi_ram:
            ram.write_if.reset.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        for ram in self.axi_ram:
            ram.write_if.reset.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        for ram in self.axi_ram:
            ram.write_if.reset.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)

    async def reset_cfg(self):
        self.dut.cfg_reset.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.cfg_reset.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.cfg_reset.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)


async def run_test(dut, payload_lengths=None, payload_data=None, space=False,
        stream_idle_inserter=None, stream_backpressure_inserter=None,
        axi_0_idle_inserter=None, axi_0_backpressure_inserter=None,
        axi_idle_inserter=None, axi_backpressure_inserter=None):

    tb = TB(dut)

    id_count = 2**len(tb.source.bus.tid)

    cur_id = 1

    await tb.reset()

    tb.set_stream_idle_generator(stream_idle_inserter)
    tb.set_stream_backpressure_generator(stream_backpressure_inserter)
    tb.set_axi_idle_generator(axi_idle_inserter)
    tb.set_axi_backpressure_generator(axi_backpressure_inserter)
    tb.set_axi_0_backpressure_generator(axi_0_backpressure_inserter)
    tb.set_axi_0_idle_generator(axi_0_idle_inserter)

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id

        test_frames.append(test_frame)
        await tb.source.send(test_frame)

        cur_id = (cur_id + 1) % id_count

        if space:
            for k in range(1000):
                await RisingEdge(dut.clk)

                if dut.m_axis_tvalid.value.integer and dut.m_axis_tready.value.integer and dut.m_axis_tlast.value.integer:
                    break

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


async def run_test_tuser_assert(dut):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 32*byte_lanes))
    test_frame = AxiStreamFrame(test_data, tuser=1)
    await tb.source.send(test_frame)

    rx_frame = await tb.sink.recv()

    assert rx_frame.tdata == test_data
    assert rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


async def run_test_init_sink_pause(dut):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    tb.sink.pause = True

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))
    test_frame = AxiStreamFrame(test_data)
    await tb.source.send(test_frame)

    for k in range(256):
        await RisingEdge(dut.s_axis_clk)

    tb.sink.pause = False

    rx_frame = await tb.sink.recv()

    assert rx_frame.tdata == test_data
    assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


async def run_test_init_sink_pause_reset(dut, reset_type=TB.reset):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    tb.sink.pause = True

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))
    test_frame = AxiStreamFrame(test_data)
    await tb.source.send(test_frame)

    for k in range(256):
        await RisingEdge(dut.s_axis_clk)

    await reset_type(tb)

    tb.sink.pause = False

    for k in range(2048):
        await RisingEdge(dut.s_axis_clk)

    assert tb.sink.idle()
    assert tb.sink.empty()

    await tb.source.send(test_frame)

    rx_frame = await tb.sink.recv()

    assert rx_frame.tdata == test_data
    assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


async def run_test_shift_in_reset(dut, reset_type=TB.reset):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))
    test_frame = AxiStreamFrame(test_data)
    await tb.source.send(test_frame)

    for k in range(256):
        await RisingEdge(dut.s_axis_clk)

    await reset_type(tb)

    for k in range(2048):
        await RisingEdge(dut.s_axis_clk)

    assert tb.sink.idle()
    assert tb.sink.empty()

    await tb.source.send(test_frame)

    rx_frame = await tb.sink.recv()

    assert rx_frame.tdata == test_data
    assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


async def run_test_shift_out_reset(dut, reset_type=TB.reset):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))
    test_frame = AxiStreamFrame(test_data)
    await tb.source.send(test_frame)

    await RisingEdge(dut.m_axis_tvalid)

    for k in range(8):
        await RisingEdge(dut.s_axis_clk)

    await reset_type(tb)

    for k in range(2048):
        await RisingEdge(dut.s_axis_clk)

    assert tb.sink.idle()
    assert tb.sink.empty()

    await tb.source.send(test_frame)

    rx_frame = await tb.sink.recv()

    assert rx_frame.tdata == test_data
    assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


async def run_test_overflow(dut):

    tb = TB(dut)

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    tb.sink.pause = True

    ram_size = 2**tb.axi_ram[0].write_if.address_width*len(tb.axi_ram)

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 2*ram_size))
    test_frame = AxiStreamFrame(test_data)
    await tb.source.send(test_frame)

    for k in range(2048):
        await RisingEdge(dut.s_axis_clk)

    tb.sink.pause = False

    rx_frame = await tb.sink.recv()

    assert rx_frame.tdata == test_data
    assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


async def run_stress_test(dut, space=False,
        stream_idle_inserter=None, stream_backpressure_inserter=None,
        axi_0_idle_inserter=None, axi_0_backpressure_inserter=None,
        axi_idle_inserter=None, axi_backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes
    id_count = 2**len(tb.source.bus.tid)

    cur_id = 1

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**16-1)
    dut.cfg_enable.setimmediatevalue(1)

    tb.set_stream_idle_generator(stream_idle_inserter)
    tb.set_stream_backpressure_generator(stream_backpressure_inserter)
    tb.set_axi_idle_generator(axi_idle_inserter)
    tb.set_axi_backpressure_generator(axi_backpressure_inserter)
    tb.set_axi_0_backpressure_generator(axi_0_backpressure_inserter)
    tb.set_axi_0_idle_generator(axi_0_idle_inserter)

    test_frames = []

    for k in range(128):
        length = random.randint(1, byte_lanes*16)
        test_data = bytearray(itertools.islice(itertools.cycle(range(256)), length))
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id

        test_frames.append(test_frame)
        await tb.source.send(test_frame)

        cur_id = (cur_id + 1) % id_count

        if space:
            for k in range(1000):
                await RisingEdge(dut.clk)

                if dut.m_axis_tvalid.value.integer and dut.m_axis_tready.value.integer and dut.m_axis_tlast.value.integer:
                    break

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.s_axis_clk)
    await RisingEdge(dut.s_axis_clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    data_width = len(cocotb.top.m_axis_tdata)
    byte_width = data_width // 8
    return list(range(1, byte_width*4+1))+list(range(byte_width, byte_width*32, byte_width))+[2**14]+[1]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option(("space",
            "stream_idle_inserter", "stream_backpressure_inserter",
            "axi_0_idle_inserter", "axi_0_backpressure_inserter",
            "axi_idle_inserter", "axi_backpressure_inserter"), [
        (False, None, None, None, None, None, None),
        (False, cycle_pause, None, None, None, None, None),
        (False, None, cycle_pause, None, None, None, None),
        (False, None, None, cycle_pause, None, None, None),
        (False, None, None, None, cycle_pause, None, None),
        (False, None, None, None, None, cycle_pause, None),
        (False, None, None, None, None, None, cycle_pause),
        (True,  None, None, None, None, None, None),
        (True,  cycle_pause, None, None, None, None, None),
        (True,  None, cycle_pause, None, None, None, None),
        (True,  None, None, cycle_pause, None, None, None),
        (True,  None, None, None, cycle_pause, None, None),
        (True,  None, None, None, None, cycle_pause, None),
        (True,  None, None, None, None, None, cycle_pause),
    ])
    factory.generate_tests()

    for test in [
                run_test_tuser_assert,
                run_test_init_sink_pause,
                run_test_overflow
            ]:

        factory = TestFactory(test)
        factory.generate_tests()

    for test in [
                run_test_init_sink_pause_reset,
                run_test_shift_in_reset,
                run_test_shift_out_reset,
            ]:

        factory = TestFactory(test)
        factory.add_option("reset_type", [TB.reset, TB.reset_source,
                TB.reset_sink, TB.reset_axi_0, TB.reset_axi, TB.reset_cfg])
        factory.generate_tests()

    factory = TestFactory(run_stress_test)
    factory.add_option(("space",
            "stream_idle_inserter", "stream_backpressure_inserter",
            "axi_0_idle_inserter", "axi_0_backpressure_inserter",
            "axi_idle_inserter", "axi_backpressure_inserter"), [
        (False, None, None, None, None, None, None),
        (False, cycle_pause, None, None, None, None, None),
        (False, None, cycle_pause, None, None, None, None),
        (False, None, None, cycle_pause, None, None, None),
        (False, None, None, None, cycle_pause, None, None),
        (False, None, None, None, None, cycle_pause, None),
        (False, None, None, None, None, None, cycle_pause),
        (True,  None, None, None, None, None, None),
        (True,  cycle_pause, None, None, None, None, None),
        (True,  None, cycle_pause, None, None, None, None),
        (True,  None, None, cycle_pause, None, None, None),
        (True,  None, None, None, cycle_pause, None, None),
        (True,  None, None, None, None, cycle_pause, None),
        (True,  None, None, None, None, None, cycle_pause),
    ])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize(("axis_data_width", "axi_ch", "axi_data_width"), [
            # (32, 1, 32),
            # (32, 2, 32),
            (512, 2, 512),
        ])
def test_axi_vfifo(request, axis_data_width, axi_ch, axi_data_width):
    dut = "axi_vfifo"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "axi_vfifo_raw.v"),
        os.path.join(rtl_dir, "axi_vfifo_raw_wr.v"),
        os.path.join(rtl_dir, "axi_vfifo_raw_rd.v"),
        os.path.join(rtl_dir, "axi_vfifo_enc.v"),
        os.path.join(rtl_dir, "axi_vfifo_dec.v"),
    ]

    parameters = {}

    parameters['AXI_CH'] = axi_ch
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
    parameters['AXIS_DEST_ENABLE'] = 1
    parameters['AXIS_DEST_WIDTH'] = 8
    parameters['AXIS_USER_ENABLE'] = 1
    parameters['AXIS_USER_WIDTH'] = 1
    parameters['LEN_WIDTH'] = parameters['AXI_ADDR_WIDTH']
    parameters['MAX_SEG_WIDTH'] = 256
    parameters['WRITE_FIFO_DEPTH'] = 64
    parameters['WRITE_MAX_BURST_LEN'] = parameters['WRITE_FIFO_DEPTH'] // 4
    parameters['READ_FIFO_DEPTH'] = 128
    parameters['READ_MAX_BURST_LEN'] = parameters['WRITE_MAX_BURST_LEN']

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
