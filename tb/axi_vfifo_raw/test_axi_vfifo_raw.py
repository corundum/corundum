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

import cocotb_test.simulator
import pytest

import cocotb

from cocotb.queue import Queue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Event
from cocotb.regression import TestFactory
from cocotb_bus.bus import Bus

from cocotbext.axi import AxiBus, AxiRam


class BaseBus(Bus):

    _signals = ["data"]
    _optional_signals = []

    def __init__(self, entity=None, prefix=None, **kwargs):
        super().__init__(entity, prefix, self._signals, optional_signals=self._optional_signals, **kwargs)

    @classmethod
    def from_entity(cls, entity, **kwargs):
        return cls(entity, **kwargs)

    @classmethod
    def from_prefix(cls, entity, prefix, **kwargs):
        return cls(entity, prefix, **kwargs)


class DataBus(BaseBus):
    _signals = ["data", "valid", "ready"]


class DataSource:

    def __init__(self, bus, clock, reset=None, *args, **kwargs):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        self.log = logging.getLogger(f"cocotb.{bus._entity._name}.{bus._name}")

        self.pause = False
        self._pause_generator = None
        self._pause_cr = None

        self.width = len(self.bus.data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        self.seg_count = len(self.bus.valid)
        self.seg_data_width = self.width // self.seg_count
        self.seg_byte_lanes = self.seg_data_width // self.byte_size

        self.seg_data_mask = 2**self.seg_data_width-1

        # queue per segment
        self.queue = [Queue() for x in range(self.seg_count)]

        self.bus.data.setimmediatevalue(0)
        self.bus.valid.setimmediatevalue(0)

        cocotb.start_soon(self._run())

    def set_pause_generator(self, generator=None):
        if self._pause_cr is not None:
            self._pause_cr.kill()
            self._pause_cr = None

        self._pause_generator = generator

        if self._pause_generator is not None:
            self._pause_cr = cocotb.start_soon(self._run_pause())

    def clear_pause_generator(self):
        self.set_pause_generator(None)

    def empty(self):
        for queue in self.queue:
            if not queue.empty():
                return False
        return True

    def clear(self):
        for queue in self.queue:
            while not queue.empty():
                _ = queue.get_nowait()

    async def write(self, data):
        self.write_nowait(data)

    def write_nowait(self, data):
        data = bytearray(data)

        # pad to interface width
        if len(data) % self.byte_lanes:
            data.extend(b'\x00'*(self.byte_lanes - (len(data) % self.byte_lanes)))

        # stripe across segment queues
        index = 0
        for offset in range(0, len(data), self.seg_byte_lanes):
            self.queue[index].put_nowait(data[offset:offset+self.seg_byte_lanes])
            index = (index + 1) % self.seg_count

    async def _run(self):
        data = 0
        valid = 0
        ready_sample = 0

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            ready_sample = self.bus.ready.value.integer

            if self.reset is not None and self.reset.value:
                self.bus.valid.setimmediatevalue(0)
                valid = 0
                self.clear()
                continue

            # process segments
            for seg in range(self.seg_count):
                seg_mask = 1 << seg
                if ((ready_sample & seg_mask) or not (valid & seg_mask)):
                    if not self.queue[seg].empty() and not self.pause:
                        d = self.queue[seg].get_nowait()
                        data &= ~(self.seg_data_mask << self.seg_data_width*seg)
                        data |= int.from_bytes(d, 'little') << self.seg_data_width*seg
                        valid |= seg_mask

                        self.log.info("TX seg: %d data: %s", seg, d)
                    else:
                        valid = valid & ~seg_mask

            self.bus.data.value = data
            self.bus.valid.value = valid

    async def _run_pause(self):
        clock_edge_event = RisingEdge(self.clock)

        for val in self._pause_generator:
            self.pause = val
            await clock_edge_event


class DataSink:

    def __init__(self, bus, clock, reset=None, watermark=None, *args, **kwargs):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        self.watermark = watermark
        self.log = logging.getLogger(f"cocotb.{bus._entity._name}.{bus._name}")

        self.pause = False
        self._pause_generator = None
        self._pause_cr = None

        self.enqueue_event = Event()

        self.watermark_level = 0

        self.width = len(self.bus.data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        self.seg_count = len(self.bus.valid)
        self.seg_data_width = self.width // self.seg_count
        self.seg_byte_lanes = self.seg_data_width // self.byte_size

        self.seg_data_mask = 2**self.seg_data_width-1

        # queue per segment
        self.queue = [Queue() for x in range(self.seg_count)]

        self.read_queue = bytearray()

        self.bus.data.setimmediatevalue(0)
        self.bus.valid.setimmediatevalue(0)

        cocotb.start_soon(self._run())

    def set_pause_generator(self, generator=None):
        if self._pause_cr is not None:
            self._pause_cr.kill()
            self._pause_cr = None

        self._pause_generator = generator

        if self._pause_generator is not None:
            self._pause_cr = cocotb.start_soon(self._run_pause())

    def clear_pause_generator(self):
        self.set_pause_generator(None)

    def empty(self):
        for queue in self.queue:
            if not queue.empty():
                return False
        return True

    def clear(self):
        for queue in self.queue:
            while not queue.empty():
                _ = queue.get_nowait()
        self.read_queue.clear()

    def _read_queues(self):
        while True:
            for queue in self.queue:
                if queue.empty():
                    return
            for queue in self.queue:
                self.read_queue.extend(queue.get_nowait())

    async def read(self, count=-1):
        self._read_queues()
        while not self.read_queue:
            self.enqueue_event.clear()
            await self.enqueue_event.wait()
            self._read_queues()
        return self.read_nowait(count)

    def read_nowait(self, count=-1):
        self._read_queues()
        if count < 0:
            count = len(self.read_queue)
        data = self.read_queue[:count]
        del self.read_queue[:count]
        return data

    async def _run(self):
        data_sample = 0
        valid_sample = 0
        ready = 0
        watermark = 0

        has_ready = self.bus.ready is not None
        has_watermark = self.watermark is not None

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            valid_sample = self.bus.valid.value.integer

            if valid_sample:
                data_sample = self.bus.data.value.integer

            if self.reset is not None and self.reset.value:
                if has_ready:
                    self.bus.ready.setimmediatevalue(0)
                ready = 0
                continue

            # process segments
            watermark = 0
            for seg in range(self.seg_count):
                seg_mask = 1 << seg
                if ready & valid_sample & seg_mask:
                    data = (data_sample >> self.seg_data_width*seg) & self.seg_data_mask

                    data = data.to_bytes(self.seg_byte_lanes, 'little')

                    self.queue[seg].put_nowait(data)
                    self.enqueue_event.set()

                    self.log.info("RX seg: %d data: %s", seg, data)

                if has_watermark and self.watermark_level > 0 and self.queue[seg].qsize() > self.watermark_level:
                    watermark = 1

            ready = 2**self.seg_count-1

            if self.pause:
                ready = 0
                watermark = 1

            if has_ready:
                self.bus.ready.value = ready
            if has_watermark:
                self.watermark.value = watermark

    async def _run_pause(self):
        clock_edge_event = RisingEdge(self.clock)

        for val in self._pause_generator:
            self.pause = val
            await clock_edge_event


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        # streaming data in
        cocotb.start_soon(Clock(dut.input_clk, 10, units="ns").start())
        self.source = DataSource(DataBus.from_prefix(dut, "input"), dut.input_clk, dut.input_rst_out)

        # streaming data out
        cocotb.start_soon(Clock(dut.output_clk, 10, units="ns").start())
        self.sink = DataSink(DataBus.from_prefix(dut, "output"), dut.output_clk, dut.output_rst_out)

        # AXI interface
        self.axi_ram = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst, size=2**16)

        dut.rst_req_in.setimmediatevalue(0)

        dut.cfg_fifo_base_addr.setimmediatevalue(0)
        dut.cfg_fifo_size_mask.setimmediatevalue(0)
        dut.cfg_enable.setimmediatevalue(0)
        dut.cfg_reset.setimmediatevalue(0)

    def set_stream_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_stream_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    def set_axi_idle_generator(self, generator=None):
        if generator:
            self.axi_ram.write_if.b_channel.set_pause_generator(generator())
            self.axi_ram.read_if.r_channel.set_pause_generator(generator())

    def set_axi_backpressure_generator(self, generator=None):
        if generator:
            self.axi_ram.write_if.aw_channel.set_pause_generator(generator())
            self.axi_ram.write_if.w_channel.set_pause_generator(generator())
            self.axi_ram.read_if.ar_channel.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        self.dut.input_rst.setimmediatevalue(0)
        self.dut.output_rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        self.dut.input_rst.value = 1
        self.dut.output_rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        self.dut.input_rst.value = 0
        self.dut.output_rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)

    async def reset_axi(self):
        self.dut.rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)

    async def reset_source(self):
        self.dut.input_rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.input_clk)
        self.dut.input_rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.input_clk)
        self.dut.input_rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.input_clk)

    async def reset_sink(self):
        self.dut.output_rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.output_clk)
        self.dut.output_rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.output_clk)
        self.dut.output_rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.output_clk)

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
        axi_idle_inserter=None, axi_backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    tb.set_stream_idle_generator(stream_idle_inserter)
    tb.set_stream_backpressure_generator(stream_backpressure_inserter)
    tb.set_axi_idle_generator(axi_idle_inserter)
    tb.set_axi_backpressure_generator(axi_backpressure_inserter)

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**len(dut.m_axi_awaddr)-1)
    dut.cfg_enable.setimmediatevalue(1)

    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        if len(test_data) % byte_lanes:
            test_data.extend(b'\x00'*(byte_lanes - (len(test_data) % byte_lanes)))

        test_frames.append(test_data)
        await tb.source.write(test_data)

        if space:
            for k in range(1000):
                await RisingEdge(dut.clk)

    for test_data in test_frames:
        rx_data = bytearray()
        while len(rx_data) < len(test_data):
            d = await tb.sink.read(len(test_data) - len(rx_data))
            rx_data.extend(d)

        assert rx_data == test_data

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_init_sink_pause(dut):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**len(dut.m_axi_awaddr)-1)
    dut.cfg_enable.setimmediatevalue(1)

    tb.sink.pause = True

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))

    if len(test_data) % byte_lanes:
        test_data.extend(b'\x00'*(byte_lanes - (len(test_data) % byte_lanes)))

    await tb.source.write(test_data)

    for k in range(256):
        await RisingEdge(dut.clk)

    tb.sink.pause = False

    rx_data = bytearray()
    while len(rx_data) < len(test_data):
        d = await tb.sink.read(len(test_data) - len(rx_data))
        rx_data.extend(d)

    assert rx_data == test_data

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_init_sink_pause_reset(dut, reset_type=TB.reset):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**len(dut.m_axi_awaddr)-1)
    dut.cfg_enable.setimmediatevalue(1)

    tb.sink.pause = True

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))

    if len(test_data) % byte_lanes:
        test_data.extend(b'\x00'*(byte_lanes - (len(test_data) % byte_lanes)))

    await tb.source.write(test_data)

    for k in range(256):
        await RisingEdge(dut.clk)

    await reset_type(tb)
    tb.sink.clear()

    tb.sink.pause = False

    for k in range(1024):
        await RisingEdge(dut.clk)

    assert tb.sink.empty()

    await tb.source.write(test_data)

    rx_data = bytearray()
    while len(rx_data) < len(test_data):
        d = await tb.sink.read(len(test_data) - len(rx_data))
        rx_data.extend(d)

    assert rx_data == test_data

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_shift_in_reset(dut, reset_type=TB.reset):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**len(dut.m_axi_awaddr)-1)
    dut.cfg_enable.setimmediatevalue(1)

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))

    if len(test_data) % byte_lanes:
        test_data.extend(b'\x00'*(byte_lanes - (len(test_data) % byte_lanes)))

    await tb.source.write(test_data)

    for k in range(256):
        await RisingEdge(dut.clk)

    await reset_type(tb)
    tb.sink.clear()

    for k in range(2048):
        await RisingEdge(dut.clk)

    assert tb.sink.empty()

    await tb.source.write(test_data)

    rx_data = bytearray()
    while len(rx_data) < len(test_data):
        d = await tb.sink.read(len(test_data) - len(rx_data))
        rx_data.extend(d)

    assert rx_data == test_data

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_shift_out_reset(dut, reset_type=TB.reset):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**len(dut.m_axi_awaddr)-1)
    dut.cfg_enable.setimmediatevalue(1)

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 1024*byte_lanes))

    if len(test_data) % byte_lanes:
        test_data.extend(b'\x00'*(byte_lanes - (len(test_data) % byte_lanes)))

    await tb.source.write(test_data)

    while not dut.output_valid:
        await RisingEdge(dut.clk)

    for k in range(8):
        await RisingEdge(dut.clk)

    await reset_type(tb)
    tb.sink.clear()

    for k in range(2048):
        await RisingEdge(dut.clk)

    assert tb.sink.empty()

    await tb.source.write(test_data)

    rx_data = bytearray()
    while len(rx_data) < len(test_data):
        d = await tb.sink.read(len(test_data) - len(rx_data))
        rx_data.extend(d)

    assert rx_data == test_data

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_overflow(dut):

    tb = TB(dut)

    byte_lanes = tb.source.byte_lanes

    await tb.reset()

    dut.cfg_fifo_base_addr.setimmediatevalue(0)
    dut.cfg_fifo_size_mask.setimmediatevalue(2**len(dut.m_axi_awaddr)-1)
    dut.cfg_enable.setimmediatevalue(1)

    tb.sink.pause = True

    test_data = bytearray(itertools.islice(itertools.cycle(range(256)), 2*2**len(dut.m_axi_awaddr)))

    if len(test_data) % byte_lanes:
        test_data.extend(b'\x00'*(byte_lanes - (len(test_data) % byte_lanes)))

    await tb.source.write(test_data)

    for k in range(2*2**len(dut.m_axi_awaddr)//len(dut.m_axi_wstrb)):
        await RisingEdge(dut.clk)

    tb.sink.pause = False

    rx_data = bytearray()
    while len(rx_data) < len(test_data):
        d = await tb.sink.read(len(test_data) - len(rx_data))
        rx_data.extend(d)

    assert rx_data == test_data

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    data_width = len(cocotb.top.input_data)
    byte_width = data_width // 8
    return list(range(byte_width, byte_width*64, byte_width))+[1]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option(("space",
            "stream_idle_inserter", "stream_backpressure_inserter",
            "axi_idle_inserter", "axi_backpressure_inserter"), [
        (False, None, None, None, None),
        (False, cycle_pause, None, None, None),
        (False, None, cycle_pause, None, None),
        (False, None, None, cycle_pause, None),
        (False, None, None, None, cycle_pause),
        (True,  None, None, None, None),
        (True,  cycle_pause, None, None, None),
        (True,  None, cycle_pause, None, None),
        (True,  None, None, cycle_pause, None),
        (True,  None, None, None, cycle_pause),
    ])
    factory.generate_tests()

    for test in [
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
                TB.reset_sink, TB.reset_axi, TB.reset_cfg])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize(("seg_width", "seg_cnt"), [
            (32, 1),
            (16, 2),
        ])
def test_axi_vfifo_raw(request, seg_width, seg_cnt):
    dut = "axi_vfifo_raw"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_wr.v"),
        os.path.join(rtl_dir, f"{dut}_rd.v"),
    ]

    parameters = {}

    parameters['SEG_WIDTH'] = seg_width
    parameters['SEG_CNT'] = seg_cnt
    parameters['AXI_DATA_WIDTH'] = seg_width*seg_cnt
    parameters['AXI_ADDR_WIDTH'] = 16
    parameters['AXI_STRB_WIDTH'] = parameters['AXI_DATA_WIDTH'] // 8
    parameters['AXI_ID_WIDTH'] = 8
    parameters['AXI_MAX_BURST_LEN'] = 16
    parameters['LEN_WIDTH'] = parameters['AXI_ADDR_WIDTH']
    parameters['WRITE_FIFO_DEPTH'] = 64
    parameters['WRITE_MAX_BURST_LEN'] = parameters['WRITE_FIFO_DEPTH'] // 4
    parameters['READ_FIFO_DEPTH'] = 128
    parameters['READ_MAX_BURST_LEN'] = parameters['WRITE_MAX_BURST_LEN']
    parameters['WATERMARK_LEVEL'] = parameters['WRITE_FIFO_DEPTH'] // 2
    parameters['CTRL_OUT_EN'] = 0

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
