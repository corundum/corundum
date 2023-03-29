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

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource


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
                if (ready & seg_mask or not has_ready) and (valid_sample & seg_mask):
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
        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)

        # streaming data out
        self.sink = DataSink(DataBus.from_prefix(dut, "output"), dut.clk, dut.rst, dut.fifo_watermark_in)

        dut.fifo_rst_in.value = 0

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)

    async def reset_fifo(self):
        self.dut.fifo_rst_in.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.fifo_rst_in.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.fifo_rst_in.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)


async def run_test(dut, payload_lengths=None, payload_data=None, space=False, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    id_width = len(tb.source.bus.tid)
    dest_width = len(tb.source.bus.tdest)
    user_width = len(tb.source.bus.tuser)

    seg_cnt = tb.sink.seg_count
    seg_byte_lanes = tb.sink.seg_byte_lanes

    meta_id_offset = 0
    meta_dest_offset = meta_id_offset + id_width
    meta_user_offset = meta_dest_offset + dest_width
    meta_width = meta_user_offset + user_width
    hdr_size = (16 + meta_width + 7) // 8

    id_count = 2**id_width

    cur_id = 1

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id

        await tb.source.send(test_frame)

        test_frames.append(test_frame)

        cur_id = (cur_id + 1) % id_count

        if space:
            for k in range(1000):
                await RisingEdge(dut.clk)

    for test_frame in test_frames:
        rx_frame = AxiStreamFrame()
        while True:
            # read block
            block = await tb.sink.read(seg_byte_lanes)
            # print(block)

            # extract header
            hdr = int.from_bytes(block[0:hdr_size], 'little')
            # print(hex(hdr))

            # check parity bits
            assert bool(hdr & 0x4) == bool(bin(hdr & 0x0003).count("1") & 1)
            assert bool(hdr & 0x8) == bool(bin(hdr & 0xfff0).count("1") & 1)

            if not hdr & 1:
                # null block, skip
                continue

            length = ((hdr >> 4) & 0xfff)+1
            meta = hdr >> 16

            rx_frame.tid = (meta >> meta_id_offset) & (2**id_width-1)
            rx_frame.tdest = (meta >> meta_dest_offset) & (2**dest_width-1)
            rx_frame.tuser = (meta >> meta_user_offset) & (2**user_width-1)

            data = block[hdr_size:]

            while len(data) < length:
                block = await tb.sink.read(seg_byte_lanes)
                data.extend(block)

            if len(data) >= length:
                rx_frame.tdata.extend(data[0:length])

                if hdr & 0x2:
                    break

        print(rx_frame)

        assert rx_frame == test_frame

    # assert tb.sink.empty()

    for k in range(1000):
        await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    data_width = len(cocotb.top.s_axis_tdata)
    byte_width = data_width // 8
    return list(range(1, byte_width*4+1))+list(range(byte_width, 2**14, byte_width))+[1]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("space", [False, True])
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize(("axis_data_width", "seg_width", "seg_cnt"), [
            # (32, 32, 2),
            # (64, 256, 4),
            (512, 256, 4),
        ])
def test_axi_vfifo_enc(request, axis_data_width, seg_width, seg_cnt):
    dut = "axi_vfifo_enc"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['SEG_WIDTH'] = seg_width
    parameters['SEG_CNT'] = seg_cnt
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
