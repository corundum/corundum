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
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory
from cocotb_bus.bus import Bus

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink


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

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            ready_sample = self.bus.ready.value.integer

            if self.reset is not None and self.reset.value:
                self.bus.valid.setimmediatevalue(0)
                valid = 0
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


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        # streaming data in
        self.source = DataSource(DataBus.from_prefix(dut, "input"), dut.clk, dut.rst)
        self.source_ctrl = DataSource(DataBus.from_prefix(dut, "input_ctrl"), dut.clk, dut.rst)

        # streaming data out
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

        dut.fifo_rst_in.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source_ctrl.set_pause_generator(generator())

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


async def run_test(dut, payload_lengths=None, payload_data=None, pack=False, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    id_width = len(tb.sink.bus.tid)
    dest_width = len(tb.sink.bus.tdest)
    user_width = len(tb.sink.bus.tuser)

    seg_cnt = tb.source.seg_count
    seg_byte_lanes = tb.source.seg_byte_lanes

    max_block_size = seg_byte_lanes*seg_cnt*16

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

    packed_data = bytearray()

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id
        test_frame.tuser = 0

        # encode frame
        test_frame_enc = bytearray()

        for offset in range(0, len(test_data), max_block_size):
            block = test_data[offset:offset+max_block_size]
            block_enc = bytearray()

            meta = test_frame.tid << meta_id_offset
            meta |= (test_frame.tdest) << meta_dest_offset
            meta |= (test_frame.tuser) << meta_user_offset

            # pack header
            hdr = 0x1
            if offset+len(block) >= len(test_data):
                # last block
                hdr |= 0x2
            hdr |= (len(block)-1) << 4
            hdr |= (bin(hdr & 0x0003).count("1") & 1) << 2
            hdr |= (bin(hdr & 0xfff0).count("1") & 1) << 3
            hdr |= meta << 16

            # pack data
            block_enc.extend(hdr.to_bytes(hdr_size, 'little'))
            block_enc.extend(block)

            # zero pad to segment size
            if len(block_enc) % seg_byte_lanes:
                block_enc.extend(b'\x00'*(seg_byte_lanes - (len(block_enc) % seg_byte_lanes)))

            test_frame_enc.extend(block_enc)

        if pack:
            packed_data.extend(test_frame_enc)
        else:
            await tb.source.write(test_frame_enc)
            await tb.source_ctrl.write(test_frame_enc)

        test_frames.append(test_frame)

        cur_id = (cur_id + 1) % id_count

    if pack:
        await tb.source.write(packed_data)
        await tb.source_ctrl.write(packed_data)

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    data_width = len(cocotb.top.m_axis_tdata)
    byte_width = data_width // 8
    return list(range(1, byte_width*4+1))+list(range(byte_width, 2**14, byte_width))+[1]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("pack", [False, True])
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
def test_axi_vfifo_dec(request, axis_data_width, seg_width, seg_cnt):
    dut = "axi_vfifo_dec"
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
