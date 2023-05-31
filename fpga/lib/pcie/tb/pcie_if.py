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

import logging
import mmap
import struct

import cocotb
from cocotb.queue import Queue, QueueFull
from cocotb.triggers import RisingEdge, Timer, First, Event
from cocotb_bus.bus import Bus

from cocotbext.pcie.core import Device
from cocotbext.pcie.core.utils import PcieId
from cocotbext.pcie.core.tlp import Tlp, TlpType, CplStatus
from cocotbext.pcie.core.caps import MsiCapability, MsixCapability


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


class PcieIfBus(BaseBus):
    _signals = ["hdr", "valid", "sop", "eop", "ready"]
    _optional_signals = ["data", "strb", "error", "tlp_prfx", "vf_active",
        "func_num", "vf_num", "data_par", "hdr_par", "tlp_prfx_par",
        "seq", "bar_id", "tlp_abort"]


class PcieIfTxBus(BaseBus):
    _signals = ["hdr", "valid", "sop", "eop", "ready"]
    _optional_signals = ["data", "strb", "tlp_prfx",
        "data_par", "hdr_par", "tlp_prfx_par", "seq"]


class PcieIfRxBus(BaseBus):
    _signals = ["hdr", "valid", "sop", "eop", "ready"]
    _optional_signals = ["data", "strb", "error", "tlp_prfx", "vf_active", "func_num", "vf_num",
        "data_par", "hdr_par", "tlp_prfx_par", "bar_id", "tlp_abort"]


def dword_parity(d):
    d ^= d >> 4
    d ^= d >> 2
    d ^= d >> 1
    p = d & 0x1
    if d & 0x100:
        p |= 0x2
    if d & 0x10000:
        p |= 0x4
    if d & 0x1000000:
        p |= 0x8
    return p


def parity(d):
    d ^= d >> 4
    d ^= d >> 2
    d ^= d >> 1
    b = 0x1
    p = 0
    while d:
        if d & 0x1:
            p |= b
        d >>= 8
        b <<= 1
    return p


class PcieIfFrame:
    def __init__(self, frame=None):
        self.tlp_prfx = 0
        self.hdr = 0
        self.data = []
        self.tlp_prfx_par = 0
        self.hdr_par = 0
        self.parity = []
        self.func_num = 0
        self.vf_num = None
        self.bar_id = 0
        self.tlp_abort = 0
        self.error = 0
        self.seq = 0

        if isinstance(frame, PcieIfFrame):
            self.tlp_prfx = frame.tlp_prfx
            self.hdr = frame.hdr
            self.data = list(frame.data)
            self.tlp_prfx_par = frame.tlp_prfx_par
            self.hdr_par = frame.hdr_par
            self.parity = list(frame.parity)
            self.func_num = frame.func_num
            self.vf_num = frame.vf_num
            self.bar_id = frame.bar_id
            self.tlp_abort = frame.tlp_abort
            self.error = frame.error
            self.seq = frame.seq

    @classmethod
    def from_tlp(cls, tlp, force_64bit_addr=False):
        frame = cls()

        hdr = tlp.pack_header()

        # force 64-bit address
        if force_64bit_addr and tlp.fmt_type in {TlpType.MEM_READ, TlpType.MEM_READ_LOCKED,
                TlpType.MEM_WRITE, TlpType.IO_READ, TlpType.IO_WRITE, TlpType.FETCH_ADD,
                TlpType.SWAP, TlpType.CAS}:

            hdr = bytes([hdr[0] | 0x20]) + hdr[1:8] + b'\x00'*4 + hdr[8:12]

        frame.hdr = int.from_bytes(hdr.ljust(16, b'\x00'), 'big')

        data = tlp.get_data()
        for k in range(0, len(data), 4):
            frame.data.extend(struct.unpack_from('<L', data, k))

        frame.update_parity()

        return frame

    def to_tlp(self):
        hdr = self.hdr.to_bytes(16, 'big')

        # fix forced 64-bit address field
        if hdr[0] in {0x22, 0x62}:
            hdr = bytes([hdr[0] & 0xdf]) + hdr[1:8] + hdr[12:16]

        tlp = Tlp.unpack_header(hdr)

        for dw in self.data:
            tlp.data.extend(struct.pack('<L', dw))

        return tlp

    def update_parity(self):
        self.parity = [dword_parity(d) ^ 0xf for d in self.data]
        self.hdr_par = parity(self.hdr)
        self.tlp_prfx_par = dword_parity(self.tlp_prfx)

    def check_parity(self):
        return (
            self.parity == [dword_parity(d) ^ 0xf for d in self.data] and
            self.hdr_par == parity(self.hdr) and
            self.tlp_prfx_par == dword_parity(self.tlp_prfx)
        )

    def __eq__(self, other):
        if isinstance(other, PcieIfFrame):
            return (
                self.tlp_prfx == other.tlp_prfx and
                self.hdr == other.hdr and
                self.data == other.data and
                self.tlp_prfx_par == other.tlp_prfx_par and
                self.hdr_par == other.hdr_par and
                self.parity == other.parity and
                self.func_num == other.func_num and
                self.vf_num == other.vf_num and
                self.bar_id == other.bar_id and
                self.tlp_abort == other.tlp_abort and
                self.error == other.error and
                self.seq == other.seq
            )
        return False

    def __repr__(self):
        return (
            f"{type(self).__name__}(tlp_prfx={self.tlp_prfx:#010x}, hdr={self.hdr:#034x}, "
            f"data=[{', '.join(f'{x:#010x}' for x in self.data)}], "
            f"tlp_prfx_par={self.tlp_prfx_par:#x}, hdr_par={self.hdr_par:#06x}, "
            f"parity=[{', '.join(hex(x) for x in self.parity)}], "
            f"func_num={self.func_num}, "
            f"vf_num={self.vf_num}, "
            f"bar_id={self.bar_id}, "
            f"tlp_abort={self.tlp_abort}, "
            f"error={self.error}, "
            f"seq={self.seq})"
        )

    def __len__(self):
        return len(self.data)


class PcieIfTransaction:

    _signals = ["data", "strb", "sop", "eop", "valid", "error", "hdr", "tlp_prfx", "seq",
        "vf_active", "func_num", "vf_num", "bar_id", "tlp_abort", "data_par", "hdr_par", "tlp_prfx_par"]

    def __init__(self, *args, **kwargs):
        for sig in self._signals:
            if sig in kwargs:
                setattr(self, sig, kwargs[sig])
                del kwargs[sig]
            else:
                setattr(self, sig, 0)

        super().__init__(*args, **kwargs)

    def __repr__(self):
        return f"{type(self).__name__}({', '.join(f'{s}={int(getattr(self, s))}' for s in self._signals)})"


class PcieIfBase:

    _signal_widths = {"ready": 1}

    _valid_signal = "valid"
    _ready_signal = "ready"

    _transaction_obj = PcieIfTransaction
    _frame_obj = PcieIfFrame

    def __init__(self, bus, clock, reset=None, *args, **kwargs):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        self.log = logging.getLogger(f"cocotb.{bus._entity._name}.{bus._name}")

        super().__init__(*args, **kwargs)

        self.active = False
        self.queue = Queue()
        self.dequeue_event = Event()
        self.idle_event = Event()
        self.idle_event.set()
        self.active_event = Event()

        self.pause = False
        self._pause_generator = None
        self._pause_cr = None

        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

        if hasattr(self.bus, "data"):
            self.width = len(self.bus.data)
        else:
            self.width = 64
        self.byte_size = 32
        self.byte_lanes = self.width // self.byte_size
        self.byte_mask = 2**self.byte_size-1

        self.seg_count = len(self.bus.valid)
        self.seg_width = self.width // self.seg_count
        self.seg_mask = 2**self.seg_width-1
        self.seg_par_width = self.seg_width // 8
        self.seg_par_mask = 2**self.seg_par_width-1
        self.seg_byte_lanes = self.byte_lanes // self.seg_count
        self.seg_strb_width = self.seg_byte_lanes
        self.seg_strb_mask = 2**self.seg_strb_width-1

        if hasattr(self.bus, "seq"):
            self.seq_width = len(self.bus.seq) // self.seg_count
        else:
            self.seq_width = 6
        self.seq_mask = 2**self.seq_width-1

        if hasattr(self.bus, "data"):
            assert len(self.bus.data) == self.seg_count*self.seg_width
        assert len(self.bus.sop) == self.seg_count
        assert len(self.bus.eop) == self.seg_count
        assert len(self.bus.valid) == self.seg_count
        assert len(self.bus.hdr) == self.seg_count*128
        if hasattr(self.bus, "tlp_prfx"):
            assert len(self.bus.tlp_prfx) == self.seg_count*32

        if hasattr(self.bus, "strb"):
            assert len(self.bus.strb) == self.seg_count*self.seg_strb_width

        if hasattr(self.bus, "error"):
            assert len(self.bus.error) == self.seg_count*4
        if hasattr(self.bus, "bar_id"):
            assert len(self.bus.bar_id) == self.seg_count*3
        if hasattr(self.bus, "tlp_abort"):
            assert len(self.bus.tlp_abort) == self.seg_count

        if hasattr(self.bus, "vf_active"):
            assert len(self.bus.vf_active) == self.seg_count
        if hasattr(self.bus, "func_num"):
            assert len(self.bus.func_num) == self.seg_count*8
        if hasattr(self.bus, "vf_num"):
            assert len(self.bus.vf_num) == self.seg_count*11

        if hasattr(self.bus, "data_par"):
            assert len(self.bus.data_par) == self.seg_count*self.seg_width//8
        if hasattr(self.bus, "hdr_par"):
            assert len(self.bus.hdr_par) == self.seg_count*128//8
        if hasattr(self.bus, "tlp_prfx_par"):
            assert len(self.bus.tlp_prfx_par) == self.seg_count*32//8

    def count(self):
        return self.queue.qsize()

    def empty(self):
        return self.queue.empty()

    def clear(self):
        while not self.queue.empty():
            self.queue.get_nowait()
        self.idle_event.set()
        self.active_event.clear()

    def idle(self):
        raise NotImplementedError()

    async def wait(self):
        raise NotImplementedError()

    def set_pause_generator(self, generator=None):
        if self._pause_cr is not None:
            self._pause_cr.kill()
            self._pause_cr = None

        self._pause_generator = generator

        if self._pause_generator is not None:
            self._pause_cr = cocotb.start_soon(self._run_pause())

    def clear_pause_generator(self):
        self.set_pause_generator(None)

    async def _run_pause(self):
        clock_edge_event = RisingEdge(self.clock)

        for val in self._pause_generator:
            self.pause = val
            await clock_edge_event


class PcieIfSource(PcieIfBase):

    _signal_widths = {"valid": 1, "ready": 1}

    _valid_signal = "valid"
    _ready_signal = "ready"

    _transaction_obj = PcieIfTransaction
    _frame_obj = PcieIfFrame

    def __init__(self, bus, clock, reset=None, *args, **kwargs):
        super().__init__(bus, clock, reset, *args, **kwargs)

        self.drive_obj = None
        self.drive_sync = Event()

        self.queue_occupancy_limit_bytes = -1
        self.queue_occupancy_limit_frames = -1

        if hasattr(self.bus, "data"):
            self.bus.data.setimmediatevalue(0)
        self.bus.sop.setimmediatevalue(0)
        self.bus.eop.setimmediatevalue(0)
        self.bus.valid.setimmediatevalue(0)
        self.bus.hdr.setimmediatevalue(0)
        if hasattr(self.bus, "tlp_prfx"):
            self.bus.tlp_prfx.setimmediatevalue(0)

        if hasattr(self.bus, "strb"):
            self.bus.strb.setimmediatevalue(0)

        if hasattr(self.bus, "error"):
            self.bus.error.setimmediatevalue(0)
        if hasattr(self.bus, "seq"):
            self.bus.seq.setimmediatevalue(0)
        if hasattr(self.bus, "bar_id"):
            self.bus.bar_id.setimmediatevalue(0)
        if hasattr(self.bus, "tlp_abort"):
            self.bus.tlp_abort.setimmediatevalue(0)

        if hasattr(self.bus, "vf_active"):
            self.bus.vf_active.setimmediatevalue(0)
        if hasattr(self.bus, "func_num"):
            self.bus.func_num.setimmediatevalue(0)
        if hasattr(self.bus, "vf_num"):
            self.bus.vf_num.setimmediatevalue(0)

        if hasattr(self.bus, "data_par"):
            self.bus.data_par.setimmediatevalue(0)
        if hasattr(self.bus, "hdr_par"):
            self.bus.hdr_par.setimmediatevalue(0)
        if hasattr(self.bus, "tlp_prfx_par"):
            self.bus.tlp_prfx_par.setimmediatevalue(0)

        cocotb.start_soon(self._run_source())
        cocotb.start_soon(self._run())

    async def _drive(self, obj):
        if self.drive_obj is not None:
            self.drive_sync.clear()
            await self.drive_sync.wait()

        self.drive_obj = obj

    async def send(self, frame):
        while self.full():
            self.dequeue_event.clear()
            await self.dequeue_event.wait()
        frame = PcieIfFrame(frame)
        await self.queue.put(frame)
        self.idle_event.clear()
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

    def send_nowait(self, frame):
        if self.full():
            raise QueueFull()
        frame = PcieIfFrame(frame)
        self.queue.put_nowait(frame)
        self.idle_event.clear()
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

    def full(self):
        if self.queue_occupancy_limit_bytes > 0 and self.queue_occupancy_bytes > self.queue_occupancy_limit_bytes:
            return True
        elif self.queue_occupancy_limit_frames > 0 and self.queue_occupancy_frames > self.queue_occupancy_limit_frames:
            return True
        else:
            return False

    def idle(self):
        return self.empty() and not self.active

    async def wait(self):
        await self.idle_event.wait()

    async def _run_source(self):
        self.active = False

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            # read handshake signals
            ready_sample = self.bus.ready.value
            valid_sample = self.bus.valid.value

            if self.reset is not None and self.reset.value:
                self.active = False
                self.bus.valid.value = 0
                continue

            if ready_sample or not valid_sample:
                if self.drive_obj and not self.pause:
                    self.bus.drive(self.drive_obj)
                    self.drive_obj = None
                    self.drive_sync.set()
                    self.active = True
                else:
                    self.bus.valid.value = 0
                    self.active = bool(self.drive_obj)
                    if not self.drive_obj:
                        self.idle_event.set()

    async def _run(self):
        while True:
            frame = await self._get_frame()
            frame_offset = 0
            self.log.info(f"TX frame: {frame}")
            first = True

            while frame is not None:
                transaction = self._transaction_obj()

                for seg in range(self.seg_count):
                    if frame is None:
                        if not self.empty():
                            frame = self._get_frame_nowait()
                            frame_offset = 0
                            self.log.info(f"TX frame: {frame}")
                            first = True
                        else:
                            break

                    if first:
                        first = False

                        transaction.valid |= 1 << seg
                        transaction.sop |= 1 << seg
                        transaction.hdr |= frame.hdr << seg*128
                        transaction.tlp_prfx |= frame.tlp_prfx << seg*32
                        transaction.hdr_par |= frame.hdr_par << seg*16
                        transaction.tlp_prfx_par |= frame.tlp_prfx_par << seg*4

                    transaction.bar_id |= frame.bar_id << seg*3
                    transaction.func_num |= frame.func_num << seg*8
                    if frame.vf_num is not None:
                        transaction.vf_active |= 1 << seg
                        transaction.vf_num |= frame.vf_num << seg*11
                    transaction.error |= frame.error << seg*4
                    transaction.seq |= frame.seq << seg*self.seq_width

                    if frame.data:
                        transaction.valid |= 1 << seg

                        for k in range(min(self.seg_byte_lanes, len(frame.data)-frame_offset)):
                            transaction.data |= frame.data[frame_offset] << 32*(k+seg*self.seg_byte_lanes)
                            transaction.data_par |= frame.parity[frame_offset] << 4*(k+seg*self.seg_byte_lanes)
                            transaction.strb |= 1 << (k+seg*self.seg_byte_lanes)
                            frame_offset += 1

                    if frame_offset >= len(frame.data):
                        transaction.eop |= 1 << seg

                        frame = None

                await self._drive(transaction)

    async def _get_frame(self):
        frame = await self.queue.get()
        self.dequeue_event.set()
        self.queue_occupancy_bytes -= len(frame)
        self.queue_occupancy_frames -= 1
        return frame

    def _get_frame_nowait(self):
        frame = self.queue.get_nowait()
        self.dequeue_event.set()
        self.queue_occupancy_bytes -= len(frame)
        self.queue_occupancy_frames -= 1
        return frame


class PcieIfSink(PcieIfBase):

    _signal_widths = {"valid": 1, "ready": 1}

    _valid_signal = "valid"
    _ready_signal = "ready"

    _transaction_obj = PcieIfTransaction
    _frame_obj = PcieIfFrame

    def __init__(self, bus, clock, reset=None, *args, **kwargs):
        super().__init__(bus, clock, reset, *args, **kwargs)

        self.sample_obj = None
        self.sample_sync = Event()

        self.queue_occupancy_limit_bytes = -1
        self.queue_occupancy_limit_frames = -1

        self.strb_present = hasattr(self.bus, "strb")

        self.bus.ready.setimmediatevalue(0)

        cocotb.start_soon(self._run_sink())
        cocotb.start_soon(self._run())

    def _recv(self, frame):
        if self.queue.empty():
            self.active_event.clear()
        self.queue_occupancy_bytes -= len(frame)
        self.queue_occupancy_frames -= 1
        return frame

    async def recv(self):
        frame = await self.queue.get()
        return self._recv(frame)

    def recv_nowait(self):
        frame = self.queue.get_nowait()
        return self._recv(frame)

    def full(self):
        if self.queue_occupancy_limit_bytes > 0 and self.queue_occupancy_bytes > self.queue_occupancy_limit_bytes:
            return True
        elif self.queue_occupancy_limit_frames > 0 and self.queue_occupancy_frames > self.queue_occupancy_limit_frames:
            return True
        else:
            return False

    def idle(self):
        return not self.active

    async def wait(self, timeout=0, timeout_unit='ns'):
        if not self.empty():
            return
        if timeout:
            await First(self.active_event.wait(), Timer(timeout, timeout_unit))
        else:
            await self.active_event.wait()

    async def _run_sink(self):
        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            # read handshake signals
            ready_sample = self.bus.ready.value
            valid_sample = self.bus.valid.value

            if self.reset is not None and self.reset.value:
                self.bus.ready.value = 0
                continue

            if ready_sample and valid_sample:
                self.sample_obj = self._transaction_obj()
                self.bus.sample(self.sample_obj)
                self.sample_sync.set()

            self.bus.ready.value = (not self.full() and not self.pause)

    async def _run(self):
        self.active = False
        frame = None
        dword_count = 0

        while True:
            while not self.sample_obj:
                self.sample_sync.clear()
                await self.sample_sync.wait()

            self.active = True
            sample = self.sample_obj
            self.sample_obj = None

            for seg in range(self.seg_count):
                if not sample.valid & (1 << seg):
                    continue

                if sample.sop & (1 << seg):
                    assert frame is None, "framing error: sop asserted in frame"
                    frame = PcieIfFrame()

                    frame.tlp_prfx = (sample.tlp_prfx >> (seg*32)) & 0xffffffff
                    frame.tlp_prfx_par = (sample.tlp_prfx_par >> (seg*4)) & 0xf
                    frame.hdr = (sample.hdr >> (seg*128)) & (2**128-1)
                    frame.hdr_par = (sample.hdr_par >> (seg*16)) & 0xffff
                    if frame.hdr & (1 << 126):
                        dword_count = (frame.hdr >> 96) & 0x3ff
                        if dword_count == 0:
                            dword_count = 1024
                    else:
                        dword_count = 0

                    frame.bar_id = (sample.bar_id >> seg*3) & 0x7
                    frame.func_num = (sample.func_num >> seg*8) & 0xff
                    if sample.vf_active & (1 << seg):
                        frame.vf_num = (sample.vf_num >> seg*11) & 0x7ff
                    frame.error = (sample.error >> seg*4) & 0xf
                    frame.seq = (sample.seq >> seg*self.seq_width) & self.seq_mask

                assert frame is not None, "framing error: data transferred outside of frame"

                if dword_count > 0:
                    data = (sample.data >> (seg*self.seg_width)) & self.seg_mask
                    data_par = (sample.data_par >> (seg*self.seg_par_width)) & self.seg_par_mask
                    strb = (sample.strb >> (seg*self.seg_strb_width)) & self.seg_strb_mask
                    for k in range(self.seg_byte_lanes):
                        if dword_count > 0:
                            frame.data.append((data >> 32*k) & 0xffffffff)
                            frame.parity.append((data_par >> 4*k) & 0xf)
                            if self.strb_present:
                                assert (strb >> k) & 1, "incorrect strobe signal level"
                            dword_count -= 1
                        else:
                            if self.strb_present:
                                assert (strb >> k) & 1 == 0, "incorrect strobe signal level"
                else:
                    if self.strb_present:
                        strb = (sample.strb >> (seg*self.seg_strb_width)) & self.seg_strb_mask
                        assert strb == 0, "incorrect strobe signal level"

                if sample.eop & (1 << seg):
                    assert dword_count == 0, "framing error: incorrect length or early eop"
                    self.log.info(f"RX frame: {frame}")
                    self._sink_frame(frame)
                    self.active = False
                    frame = None

    def _sink_frame(self, frame):
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

        self.queue.put_nowait(frame)
        self.active_event.set()


def init_signal(sig, width=None, initval=None):
    if sig is None:
        return None
    if width is not None:
        assert len(sig) == width
    if initval is not None:
        sig.setimmediatevalue(initval)
    return sig


class PcieIfDevice(Device):
    def __init__(self,
            # configuration options
            force_64bit_addr=False,
            pf_count=1,
            max_payload_size=128,
            enable_extended_tag=False,

            pf0_msi_enable=False,
            pf0_msi_count=1,
            pf1_msi_enable=False,
            pf1_msi_count=1,
            pf2_msi_enable=False,
            pf2_msi_count=1,
            pf3_msi_enable=False,
            pf3_msi_count=1,
            pf0_msix_enable=False,
            pf0_msix_table_size=0,
            pf0_msix_table_bir=0,
            pf0_msix_table_offset=0x00000000,
            pf0_msix_pba_bir=0,
            pf0_msix_pba_offset=0x00000000,
            pf1_msix_enable=False,
            pf1_msix_table_size=0,
            pf1_msix_table_bir=0,
            pf1_msix_table_offset=0x00000000,
            pf1_msix_pba_bir=0,
            pf1_msix_pba_offset=0x00000000,
            pf2_msix_enable=False,
            pf2_msix_table_size=0,
            pf2_msix_table_bir=0,
            pf2_msix_table_offset=0x00000000,
            pf2_msix_pba_bir=0,
            pf2_msix_pba_offset=0x00000000,
            pf3_msix_enable=False,
            pf3_msix_table_size=0,
            pf3_msix_table_bir=0,
            pf3_msix_table_offset=0x00000000,
            pf3_msix_pba_bir=0,
            pf3_msix_pba_offset=0x00000000,

            # signals
            # Clock and reset
            clk=None,
            rst=None,

            # Completer interfaces
            rx_req_tlp_bus=None,
            tx_cpl_tlp_bus=None,

            # Requester interfaces
            tx_rd_req_tlp_bus=None,
            tx_wr_req_tlp_bus=None,
            tx_msi_wr_req_tlp_bus=None,
            rx_cpl_tlp_bus=None,

            rd_req_tx_seq_num=None,
            rd_req_tx_seq_num_valid=None,

            wr_req_tx_seq_num=None,
            wr_req_tx_seq_num_valid=None,

            # Configuration
            cfg_max_payload=None,
            cfg_max_read_req=None,
            cfg_ext_tag_enable=None,
            cfg_rcb=None,

            # Flow control
            tx_fc_ph_av=None,
            tx_fc_pd_av=None,
            tx_fc_nph_av=None,
            tx_fc_npd_av=None,
            tx_fc_cplh_av=None,
            tx_fc_cpld_av=None,

            tx_fc_ph_lim=None,
            tx_fc_pd_lim=None,
            tx_fc_nph_lim=None,
            tx_fc_npd_lim=None,
            tx_fc_cplh_lim=None,
            tx_fc_cpld_lim=None,

            tx_fc_ph_cons=None,
            tx_fc_pd_cons=None,
            tx_fc_nph_cons=None,
            tx_fc_npd_cons=None,
            tx_fc_cplh_cons=None,
            tx_fc_cpld_cons=None,

            *args, **kwargs):

        super().__init__(*args, **kwargs)

        self.log.info("PCIe interface model")
        self.log.info("Copyright (c) 2021 Alex Forencich")
        self.log.info("https://github.com/alexforencich/verilog-pcie")

        self.dw = None

        self.force_64bit_addr = force_64bit_addr
        self.pf_count = pf_count
        self.max_payload_size = max_payload_size
        self.enable_extended_tag = enable_extended_tag

        self.pf0_msi_enable = pf0_msi_enable
        self.pf0_msi_count = pf0_msi_count
        self.pf1_msi_enable = pf1_msi_enable
        self.pf1_msi_count = pf1_msi_count
        self.pf2_msi_enable = pf2_msi_enable
        self.pf2_msi_count = pf2_msi_count
        self.pf3_msi_enable = pf3_msi_enable
        self.pf3_msi_count = pf3_msi_count
        self.pf0_msix_enable = pf0_msix_enable
        self.pf0_msix_table_size = pf0_msix_table_size
        self.pf0_msix_table_bir = pf0_msix_table_bir
        self.pf0_msix_table_offset = pf0_msix_table_offset
        self.pf0_msix_pba_bir = pf0_msix_pba_bir
        self.pf0_msix_pba_offset = pf0_msix_pba_offset
        self.pf1_msix_enable = pf1_msix_enable
        self.pf1_msix_table_size = pf1_msix_table_size
        self.pf1_msix_table_bir = pf1_msix_table_bir
        self.pf1_msix_table_offset = pf1_msix_table_offset
        self.pf1_msix_pba_bir = pf1_msix_pba_bir
        self.pf1_msix_pba_offset = pf1_msix_pba_offset
        self.pf2_msix_enable = pf2_msix_enable
        self.pf2_msix_table_size = pf2_msix_table_size
        self.pf2_msix_table_bir = pf2_msix_table_bir
        self.pf2_msix_table_offset = pf2_msix_table_offset
        self.pf2_msix_pba_bir = pf2_msix_pba_bir
        self.pf2_msix_pba_offset = pf2_msix_pba_offset
        self.pf3_msix_enable = pf3_msix_enable
        self.pf3_msix_table_size = pf3_msix_table_size
        self.pf3_msix_table_bir = pf3_msix_table_bir
        self.pf3_msix_table_offset = pf3_msix_table_offset
        self.pf3_msix_pba_bir = pf3_msix_pba_bir
        self.pf3_msix_pba_offset = pf3_msix_pba_offset

        self.rx_cpl_queue = Queue()
        self.rx_req_queue = Queue()

        self.rd_req_tx_seq_num_queue = Queue()
        self.wr_req_tx_seq_num_queue = Queue()

        # signals

        # Clock and reset
        self.clk = clk
        self.rst = rst

        # Completer interfaces
        self.rx_req_tlp_source = None
        self.tx_cpl_tlp_sink = None

        if rx_req_tlp_bus is not None:
            self.rx_req_tlp_source = PcieIfSource(rx_req_tlp_bus, self.clk, self.rst)
            self.rx_req_tlp_source.queue_occupancy_limit_frames = 2
            self.dw = self.rx_req_tlp_source.width

        if tx_cpl_tlp_bus is not None:
            self.tx_cpl_tlp_sink = PcieIfSink(tx_cpl_tlp_bus, self.clk, self.rst)
            self.tx_cpl_tlp_sink.queue_occupancy_limit_frames = 2
            self.dw = self.tx_cpl_tlp_sink.width

        # Requester interfaces
        self.tx_rd_req_tlp_sink = None
        self.tx_wr_req_tlp_sink = None
        self.tx_msi_wr_req_tlp_sink = None
        self.rx_cpl_tlp_source = None

        if tx_rd_req_tlp_bus is not None:
            self.tx_rd_req_tlp_sink = PcieIfSink(tx_rd_req_tlp_bus, self.clk, self.rst)
            self.tx_rd_req_tlp_sink.queue_occupancy_limit_frames = 2
            self.dw = self.tx_rd_req_tlp_sink.width

        if tx_wr_req_tlp_bus is not None:
            self.tx_wr_req_tlp_sink = PcieIfSink(tx_wr_req_tlp_bus, self.clk, self.rst)
            self.tx_wr_req_tlp_sink.queue_occupancy_limit_frames = 2
            self.dw = self.tx_wr_req_tlp_sink.width

        if tx_msi_wr_req_tlp_bus is not None:
            self.tx_msi_wr_req_tlp_sink = PcieIfSink(tx_msi_wr_req_tlp_bus, self.clk, self.rst)
            self.tx_msi_wr_req_tlp_sink.queue_occupancy_limit_frames = 2

        if rx_cpl_tlp_bus is not None:
            self.rx_cpl_tlp_source = PcieIfSource(rx_cpl_tlp_bus, self.clk, self.rst)
            self.rx_cpl_tlp_source.queue_occupancy_limit_frames = 2
            self.dw = self.rx_cpl_tlp_source.width

        self.rd_req_tx_seq_num = init_signal(rd_req_tx_seq_num, None, 0)
        self.rd_req_tx_seq_num_valid = init_signal(rd_req_tx_seq_num_valid, None, 0)

        self.wr_req_tx_seq_num = init_signal(wr_req_tx_seq_num, None, 0)
        self.wr_req_tx_seq_num_valid = init_signal(wr_req_tx_seq_num_valid, None, 0)

        # Configuration
        self.cfg_max_payload = init_signal(cfg_max_payload, 3, 0)
        self.cfg_max_read_req = init_signal(cfg_max_read_req, 3, 0)
        self.cfg_ext_tag_enable = init_signal(cfg_ext_tag_enable, 1, 0)
        self.cfg_rcb = init_signal(cfg_rcb, 1, 0)

        # Flow control
        self.tx_fc_ph_av = init_signal(tx_fc_ph_av, 8, 0)
        self.tx_fc_pd_av = init_signal(tx_fc_pd_av, 12, 0)
        self.tx_fc_nph_av = init_signal(tx_fc_nph_av, 8, 0)
        self.tx_fc_npd_av = init_signal(tx_fc_npd_av, 12, 0)
        self.tx_fc_cplh_av = init_signal(tx_fc_cplh_av, 8, 0)
        self.tx_fc_cpld_av = init_signal(tx_fc_cpld_av, 12, 0)

        self.tx_fc_ph_lim = init_signal(tx_fc_ph_lim, 8, 0)
        self.tx_fc_pd_lim = init_signal(tx_fc_pd_lim, 12, 0)
        self.tx_fc_nph_lim = init_signal(tx_fc_nph_lim, 8, 0)
        self.tx_fc_npd_lim = init_signal(tx_fc_npd_lim, 12, 0)
        self.tx_fc_cplh_lim = init_signal(tx_fc_cplh_lim, 8, 0)
        self.tx_fc_cpld_lim = init_signal(tx_fc_cpld_lim, 12, 0)

        self.tx_fc_ph_cons = init_signal(tx_fc_ph_cons, 8, 0)
        self.tx_fc_pd_cons = init_signal(tx_fc_pd_cons, 12, 0)
        self.tx_fc_nph_cons = init_signal(tx_fc_nph_cons, 8, 0)
        self.tx_fc_npd_cons = init_signal(tx_fc_npd_cons, 12, 0)
        self.tx_fc_cplh_cons = init_signal(tx_fc_cplh_cons, 8, 0)
        self.tx_fc_cpld_cons = init_signal(tx_fc_cpld_cons, 12, 0)

        self.log.info("PCIe interface model configuration:")
        self.log.info("  PF count: %d", self.pf_count)
        self.log.info("  Max payload size: %d", self.max_payload_size)
        self.log.info("  Enable extended tag: %s", self.enable_extended_tag)
        self.log.info("  Enable PF0 MSI: %s", self.pf0_msi_enable)
        self.log.info("  PF0 MSI vector count: %d", self.pf0_msi_count)
        self.log.info("  Enable PF1 MSI: %s", self.pf1_msi_enable)
        self.log.info("  PF1 MSI vector count: %d", self.pf1_msi_count)
        self.log.info("  Enable PF2 MSI: %s", self.pf2_msi_enable)
        self.log.info("  PF2 MSI vector count: %d", self.pf2_msi_count)
        self.log.info("  Enable PF3 MSI: %s", self.pf3_msi_enable)
        self.log.info("  PF3 MSI vector count: %d", self.pf3_msi_count)
        self.log.info("  Enable PF0 MSIX: %s", self.pf0_msix_enable)
        self.log.info("  PF0 MSIX table size: %d", self.pf0_msix_table_size)
        self.log.info("  PF0 MSIX table BIR: %d", self.pf0_msix_table_bir)
        self.log.info("  PF0 MSIX table offset: 0x%08x", self.pf0_msix_table_offset)
        self.log.info("  PF0 MSIX PBA BIR: %d", self.pf0_msix_pba_bir)
        self.log.info("  PF0 MSIX PBA offset: 0x%08x", self.pf0_msix_pba_offset)
        self.log.info("  Enable PF1 MSIX: %s", self.pf1_msix_enable)
        self.log.info("  PF1 MSIX table size: %d", self.pf1_msix_table_size)
        self.log.info("  PF1 MSIX table BIR: %d", self.pf1_msix_table_bir)
        self.log.info("  PF1 MSIX table offset: 0x%08x", self.pf1_msix_table_offset)
        self.log.info("  PF1 MSIX PBA BIR: %d", self.pf1_msix_pba_bir)
        self.log.info("  PF1 MSIX PBA offset: 0x%08x", self.pf1_msix_pba_offset)
        self.log.info("  Enable PF2 MSIX: %s", self.pf2_msix_enable)
        self.log.info("  PF2 MSIX table size: %d", self.pf2_msix_table_size)
        self.log.info("  PF2 MSIX table BIR: %d", self.pf2_msix_table_bir)
        self.log.info("  PF2 MSIX table offset: 0x%08x", self.pf2_msix_table_offset)
        self.log.info("  PF2 MSIX PBA BIR: %d", self.pf2_msix_pba_bir)
        self.log.info("  PF2 MSIX PBA offset: 0x%08x", self.pf2_msix_pba_offset)
        self.log.info("  Enable PF3 MSIX: %s", self.pf3_msix_enable)
        self.log.info("  PF3 MSIX table size: %d", self.pf3_msix_table_size)
        self.log.info("  PF3 MSIX table BIR: %d", self.pf3_msix_table_bir)
        self.log.info("  PF3 MSIX table offset: 0x%08x", self.pf3_msix_table_offset)
        self.log.info("  PF3 MSIX PBA BIR: %d", self.pf3_msix_pba_bir)
        self.log.info("  PF3 MSIX PBA offset: 0x%08x", self.pf3_msix_pba_offset)

        # configure functions

        self.make_function()

        if self.pf0_msi_enable:
            self.functions[0].msi_cap = MsiCapability()
            self.functions[0].register_capability(self.functions[0].msi_cap)
            self.functions[0].msi_cap.msi_multiple_message_capable = (self.pf0_msi_count-1).bit_length()

        if self.pf0_msix_enable:
            self.functions[0].msix_cap = MsixCapability()
            self.functions[0].register_capability(self.functions[0].msix_cap)
            self.functions[0].msix_cap.msix_table_size = self.pf0_msix_table_size
            self.functions[0].msix_cap.msix_table_bar_indicator_register = self.pf0_msix_table_bir
            self.functions[0].msix_cap.msix_table_offset = self.pf0_msix_table_offset
            self.functions[0].msix_cap.msix_pba_bar_indicator_register = self.pf0_msix_pba_bir
            self.functions[0].msix_cap.msix_pba_offset = self.pf0_msix_pba_offset

        if self.pf_count > 1:
            self.make_function()

            if self.pf1_msi_enable:
                self.functions[1].msi_cap = MsiCapability()
                self.functions[1].register_capability(self.functions[1].msi_cap)
                self.functions[1].msi_cap.msi_multiple_message_capable = (self.pf1_msi_count-1).bit_length()

            if self.pf1_msix_enable:
                self.functions[1].msix_cap = MsixCapability()
                self.functions[1].register_capability(self.functions[1].msix_cap)
                self.functions[1].msix_cap.msix_table_size = self.pf1_msix_table_size
                self.functions[1].msix_cap.msix_table_bar_indicator_register = self.pf1_msix_table_bir
                self.functions[1].msix_cap.msix_table_offset = self.pf1_msix_table_offset
                self.functions[1].msix_cap.msix_pba_bar_indicator_register = self.pf1_msix_pba_bir
                self.functions[1].msix_cap.msix_pba_offset = self.pf1_msix_pba_offset

        if self.pf_count > 2:
            self.make_function()

            if self.pf2_msi_enable:
                self.functions[2].msi_cap = MsiCapability()
                self.functions[2].register_capability(self.functions[2].msi_cap)
                self.functions[2].msi_cap.msi_multiple_message_capable = (self.pf2_msi_count-2).bit_length()

            if self.pf2_msix_enable:
                self.functions[2].msix_cap = MsixCapability()
                self.functions[2].register_capability(self.functions[2].msix_cap)
                self.functions[2].msix_cap.msix_table_size = self.pf2_msix_table_size
                self.functions[2].msix_cap.msix_table_bar_indicator_register = self.pf2_msix_table_bir
                self.functions[2].msix_cap.msix_table_offset = self.pf2_msix_table_offset
                self.functions[2].msix_cap.msix_pba_bar_indicator_register = self.pf2_msix_pba_bir
                self.functions[2].msix_cap.msix_pba_offset = self.pf2_msix_pba_offset

        if self.pf_count > 3:
            self.make_function()

            if self.pf3_msi_enable:
                self.functions[3].msi_cap = MsiCapability()
                self.functions[3].register_capability(self.functions[3].msi_cap)
                self.functions[3].msi_cap.msi_multiple_message_capable = (self.pf3_msi_count-3).bit_length()

            if self.pf3_msix_enable:
                self.functions[3].msix_cap = MsixCapability()
                self.functions[3].register_capability(self.functions[3].msix_cap)
                self.functions[3].msix_cap.msix_table_size = self.pf3_msix_table_size
                self.functions[3].msix_cap.msix_table_bar_indicator_register = self.pf3_msix_table_bir
                self.functions[3].msix_cap.msix_table_offset = self.pf3_msix_table_offset
                self.functions[3].msix_cap.msix_pba_bar_indicator_register = self.pf3_msix_pba_bir
                self.functions[3].msix_cap.msix_pba_offset = self.pf3_msix_pba_offset

        for f in self.functions:
            f.pcie_cap.max_payload_size_supported = (self.max_payload_size//128-1).bit_length()
            f.pcie_cap.extended_tag_supported = self.enable_extended_tag

        # fork coroutines

        if self.rx_req_tlp_source:
            cocotb.start_soon(self._run_rx_req_logic())
        if self.rx_cpl_tlp_source:
            cocotb.start_soon(self._run_rx_cpl_logic())
        if self.tx_cpl_tlp_sink:
            cocotb.start_soon(self._run_tx_cpl_logic())
        if self.tx_rd_req_tlp_sink:
            cocotb.start_soon(self._run_tx_rd_req_logic())
            cocotb.start_soon(self._run_rd_req_tx_seq_num_logic())
        if self.tx_wr_req_tlp_sink:
            cocotb.start_soon(self._run_tx_wr_req_logic())
            cocotb.start_soon(self._run_wr_req_tx_seq_num_logic())
        if self.tx_msi_wr_req_tlp_sink:
            cocotb.start_soon(self._run_tx_msi_wr_req_logic())
        cocotb.start_soon(self._run_cfg_status_logic())
        cocotb.start_soon(self._run_fc_logic())

    async def upstream_recv(self, tlp):
        self.log.debug("Got downstream TLP: %s", repr(tlp))

        if tlp.fmt_type in {TlpType.CFG_READ_0, TlpType.CFG_WRITE_0}:
            # config type 0

            # capture address information
            self.bus_num = tlp.dest_id.bus

            # pass TLP to function
            for f in self.functions:
                if f.pcie_id == tlp.dest_id:
                    await f.upstream_recv(tlp)
                    return

            tlp.release_fc()

            self.log.info("Function not found: failed to route config type 0 TLP: %r", tlp)
        elif tlp.fmt_type in {TlpType.CFG_READ_1, TlpType.CFG_WRITE_1}:
            # config type 1

            tlp.release_fc()

            self.log.warning("Malformed TLP: endpoint received config type 1 TLP: %r", tlp)
        elif tlp.fmt_type in {TlpType.CPL, TlpType.CPL_DATA, TlpType.CPL_LOCKED, TlpType.CPL_LOCKED_DATA}:
            # Completion

            for f in self.functions:
                if f.pcie_id == tlp.requester_id:

                    frame = PcieIfFrame.from_tlp(tlp, self.force_64bit_addr)

                    frame.func_num = tlp.requester_id.function

                    await self.rx_cpl_queue.put(frame)

                    tlp.release_fc()

                    return

            tlp.release_fc()

            self.log.warning("Unexpected completion: failed to route completion to function: %r", tlp)
            return  # no UR response for completion
        elif tlp.fmt_type in {TlpType.IO_READ, TlpType.IO_WRITE}:
            # IO read/write

            for f in self.functions:
                bar = f.match_bar(tlp.address, True)
                if bar:

                    frame = PcieIfFrame.from_tlp(tlp, self.force_64bit_addr)

                    frame.bar_id = bar[0]
                    frame.func_num = tlp.requester_id.function

                    await self.rx_req_queue.put(frame)

                    tlp.release_fc()

                    return

            tlp.release_fc()

            self.log.warning("No BAR match: IO request did not match any BARs: %r", tlp)
        elif tlp.fmt_type in {TlpType.MEM_READ, TlpType.MEM_READ_64, TlpType.MEM_WRITE, TlpType.MEM_WRITE_64}:
            # Memory read/write

            for f in self.functions:
                bar = f.match_bar(tlp.address)
                if bar:

                    frame = PcieIfFrame.from_tlp(tlp, self.force_64bit_addr)

                    frame.bar_id = bar[0]
                    frame.func_num = tlp.requester_id.function

                    await self.rx_req_queue.put(frame)

                    tlp.release_fc()

                    return

            tlp.release_fc()

            if tlp.fmt_type in {TlpType.MEM_WRITE, TlpType.MEM_WRITE_64}:
                self.log.warning("No BAR match: memory write request did not match any BARs: %r", tlp)
                return  # no UR response for write request
            else:
                self.log.warning("No BAR match: memory read request did not match any BARs: %r", tlp)
        else:
            raise Exception("TODO")

        # Unsupported request
        cpl = Tlp.create_ur_completion_for_tlp(tlp, PcieId(self.bus_num, 0, 0))
        self.log.debug("UR Completion: %s", repr(cpl))
        await self.upstream_send(cpl)

    async def _run_rx_req_logic(self):
        while True:
            frame = await self.rx_req_queue.get()
            await self.rx_req_tlp_source.send(frame)

    async def _run_rx_cpl_logic(self):
        while True:
            frame = await self.rx_cpl_queue.get()
            await self.rx_cpl_tlp_source.send(frame)

    async def _run_tx_cpl_logic(self):
        while True:
            frame = await self.tx_cpl_tlp_sink.recv()
            tlp = frame.to_tlp()
            await self.send(tlp)

    async def _run_tx_rd_req_logic(self):
        while True:
            frame = await self.tx_rd_req_tlp_sink.recv()
            tlp = frame.to_tlp()
            await self.send(tlp)
            self.rd_req_tx_seq_num_queue.put_nowait(frame.seq)

    async def _run_rd_req_tx_seq_num_logic(self):
        clock_edge_event = RisingEdge(self.clk)

        if self.rd_req_tx_seq_num is not None:
            width = len(self.rd_req_tx_seq_num) // len(self.rd_req_tx_seq_num_valid)

        while True:
            await clock_edge_event

            if self.rd_req_tx_seq_num is not None:
                data = 0
                valid = 0
                for k in range(len(self.rd_req_tx_seq_num_valid)):
                    if not self.rd_req_tx_seq_num_queue.empty():
                        data |= self.rd_req_tx_seq_num_queue.get_nowait() << (width*k)
                        valid |= 1 << k
                self.rd_req_tx_seq_num.value = data
                self.rd_req_tx_seq_num_valid.value = valid
            elif not self.rd_req_tx_seq_num_queue.empty():
                self.rd_req_tx_seq_num_queue.get_nowait()

    async def _run_tx_wr_req_logic(self):
        while True:
            frame = await self.tx_wr_req_tlp_sink.recv()
            tlp = frame.to_tlp()
            await self.send(tlp)
            self.wr_req_tx_seq_num_queue.put_nowait(frame.seq)

    async def _run_wr_req_tx_seq_num_logic(self):
        clock_edge_event = RisingEdge(self.clk)

        if self.wr_req_tx_seq_num is not None:
            width = len(self.wr_req_tx_seq_num) // len(self.wr_req_tx_seq_num_valid)

        while True:
            await clock_edge_event

            if self.wr_req_tx_seq_num is not None:
                data = 0
                valid = 0
                for k in range(len(self.wr_req_tx_seq_num_valid)):
                    if not self.wr_req_tx_seq_num_queue.empty():
                        data |= self.wr_req_tx_seq_num_queue.get_nowait() << (width*k)
                        valid |= 1 << k
                self.wr_req_tx_seq_num.value = data
                self.wr_req_tx_seq_num_valid.value = valid
            elif not self.wr_req_tx_seq_num_queue.empty():
                self.wr_req_tx_seq_num_queue.get_nowait()

    async def _run_tx_msi_wr_req_logic(self):
        while True:
            frame = await self.tx_msi_wr_req_tlp_sink.recv()
            tlp = frame.to_tlp()
            await self.send(tlp)

    async def _run_cfg_status_logic(self):
        clock_edge_event = RisingEdge(self.clk)

        while True:
            await clock_edge_event

            if self.cfg_max_payload is not None:
                self.cfg_max_payload.value = self.functions[0].pcie_cap.max_payload_size
            if self.cfg_max_read_req is not None:
                self.cfg_max_read_req.value = self.functions[0].pcie_cap.max_read_request_size
            if self.cfg_ext_tag_enable is not None:
                self.cfg_ext_tag_enable.value = self.functions[0].pcie_cap.extended_tag_field_enable
            if self.cfg_rcb is not None:
                self.cfg_rcb.value = self.functions[0].pcie_cap.read_completion_boundary

    async def _run_fc_logic(self):
        clock_edge_event = RisingEdge(self.clk)

        while True:
            await clock_edge_event

            if self.tx_fc_ph_av is not None:
                self.tx_fc_ph_av.value = self.upstream_port.fc_state[0].ph.tx_credits_available & 0xff
            if self.tx_fc_pd_av is not None:
                self.tx_fc_pd_av.value = self.upstream_port.fc_state[0].pd.tx_credits_available & 0xfff
            if self.tx_fc_nph_av is not None:
                self.tx_fc_nph_av.value = self.upstream_port.fc_state[0].nph.tx_credits_available & 0xff
            if self.tx_fc_npd_av is not None:
                self.tx_fc_npd_av.value = self.upstream_port.fc_state[0].npd.tx_credits_available & 0xfff
            if self.tx_fc_cplh_av is not None:
                self.tx_fc_cplh_av.value = self.upstream_port.fc_state[0].cplh.tx_credits_available & 0xff
            if self.tx_fc_cpld_av is not None:
                self.tx_fc_cpld_av.value = self.upstream_port.fc_state[0].cpld.tx_credits_available & 0xfff

            if self.tx_fc_ph_lim is not None:
                self.tx_fc_ph_lim.value = self.upstream_port.fc_state[0].ph.tx_credit_limit & 0xff
            if self.tx_fc_pd_lim is not None:
                self.tx_fc_pd_lim.value = self.upstream_port.fc_state[0].pd.tx_credit_limit & 0xfff
            if self.tx_fc_nph_lim is not None:
                self.tx_fc_nph_lim.value = self.upstream_port.fc_state[0].nph.tx_credit_limit & 0xff
            if self.tx_fc_npd_lim is not None:
                self.tx_fc_npd_lim.value = self.upstream_port.fc_state[0].npd.tx_credit_limit & 0xfff
            if self.tx_fc_cplh_lim is not None:
                self.tx_fc_cplh_lim.value = self.upstream_port.fc_state[0].cplh.tx_credit_limit & 0xff
            if self.tx_fc_cpld_lim is not None:
                self.tx_fc_cpld_lim.value = self.upstream_port.fc_state[0].cpld.tx_credit_limit & 0xfff

            if self.tx_fc_ph_cons is not None:
                self.tx_fc_ph_cons.value = self.upstream_port.fc_state[0].ph.tx_credits_consumed & 0xff
            if self.tx_fc_pd_cons is not None:
                self.tx_fc_pd_cons.value = self.upstream_port.fc_state[0].pd.tx_credits_consumed & 0xfff
            if self.tx_fc_nph_cons is not None:
                self.tx_fc_nph_cons.value = self.upstream_port.fc_state[0].nph.tx_credits_consumed & 0xff
            if self.tx_fc_npd_cons is not None:
                self.tx_fc_npd_cons.value = self.upstream_port.fc_state[0].npd.tx_credits_consumed & 0xfff
            if self.tx_fc_cplh_cons is not None:
                self.tx_fc_cplh_cons.value = self.upstream_port.fc_state[0].cplh.tx_credits_consumed & 0xff
            if self.tx_fc_cpld_cons is not None:
                self.tx_fc_cpld_cons.value = self.upstream_port.fc_state[0].cpld.tx_credits_consumed & 0xfff


class PcieIfTestDevice:
    def __init__(self,
            # configuration options
            force_64bit_addr=False,

            # signals
            # Clock and reset
            clk=None,
            rst=None,

            # Completer interfaces
            rx_req_tlp_bus=None,
            tx_cpl_tlp_bus=None,

            # Requester interfaces
            tx_rd_req_tlp_bus=None,
            tx_wr_req_tlp_bus=None,
            tx_msi_wr_req_tlp_bus=None,
            rx_cpl_tlp_bus=None,

            rd_req_tx_seq_num=None,
            rd_req_tx_seq_num_valid=None,

            wr_req_tx_seq_num=None,
            wr_req_tx_seq_num_valid=None,

            *args, **kwargs):

        super().__init__(*args, **kwargs)

        self.log = logging.getLogger("cocotb.tb")

        self.log.info("PCIe interface test model")
        self.log.info("Copyright (c) 2021 Alex Forencich")
        self.log.info("https://github.com/alexforencich/verilog-pcie")

        self.dw = None

        self.force_64bit_addr = force_64bit_addr

        self.bar_ptr = 0
        self.regions = [None]*6

        self.current_tag = 0
        self.tag_count = 32
        self.tag_active = [False]*256
        self.tag_release = Event()

        self.rx_cpl_queues = [Queue() for k in range(256)]
        self.rx_cpl_sync = [Event() for k in range(256)]

        self.dev_max_payload = 0
        self.dev_max_read_req = 0
        self.dev_bus_num = 0
        self.dev_device_num = 0

        # signals

        # Clock and reset
        self.clk = clk
        self.rst = rst

        # Completer interfaces
        self.rx_req_tlp_sink = None
        self.tx_cpl_tlp_source = None

        if rx_req_tlp_bus is not None:
            self.rx_req_tlp_sink = PcieIfSink(rx_req_tlp_bus, self.clk, self.rst)
            self.rx_req_tlp_sink.queue_occupancy_limit_frames = 2
            self.dw = self.rx_req_tlp_sink.width

        if tx_cpl_tlp_bus is not None:
            self.tx_cpl_tlp_source = PcieIfSource(tx_cpl_tlp_bus, self.clk, self.rst)
            self.tx_cpl_tlp_source.queue_occupancy_limit_frames = 2
            self.dw = self.tx_cpl_tlp_source.width

        # Requester interfaces
        self.tx_rd_req_tlp_source = None
        self.tx_wr_req_tlp_source = None
        self.tx_msi_wr_req_tlp_source = None
        self.rx_cpl_tlp_sink = None

        if tx_rd_req_tlp_bus is not None:
            self.tx_rd_req_tlp_source = PcieIfSource(tx_rd_req_tlp_bus, self.clk, self.rst)
            self.tx_rd_req_tlp_source.queue_occupancy_limit_frames = 2
            self.dw = self.tx_rd_req_tlp_source.width

        if tx_wr_req_tlp_bus is not None:
            self.tx_wr_req_tlp_source = PcieIfSource(tx_wr_req_tlp_bus, self.clk, self.rst)
            self.tx_wr_req_tlp_source.queue_occupancy_limit_frames = 2
            self.dw = self.tx_wr_req_tlp_source.width

        if tx_msi_wr_req_tlp_bus is not None:
            self.tx_msi_wr_req_tlp_source = PcieIfSource(tx_msi_wr_req_tlp_bus, self.clk, self.rst)
            self.tx_msi_wr_req_tlp_source.queue_occupancy_limit_frames = 2

        if rx_cpl_tlp_bus is not None:
            self.rx_cpl_tlp_sink = PcieIfSink(rx_cpl_tlp_bus, self.clk, self.rst)
            self.rx_cpl_tlp_sink.queue_occupancy_limit_frames = 2
            self.dw = self.rx_cpl_tlp_sink.width

        self.rd_req_tx_seq_num = init_signal(rd_req_tx_seq_num, None)
        self.rd_req_tx_seq_num_valid = init_signal(rd_req_tx_seq_num_valid, None)

        self.wr_req_tx_seq_num = init_signal(wr_req_tx_seq_num, None)
        self.wr_req_tx_seq_num_valid = init_signal(wr_req_tx_seq_num_valid, None)

        # fork coroutines

        cocotb.start_soon(self._run_rx_req_tlp())
        cocotb.start_soon(self._run_rx_cpl_tlp())

    def add_region(self, size, read=None, write=None, ext=False, prefetch=False, io=False):
        if self.bar_ptr > 5 or (ext and self.bar_ptr > 4):
            raise Exception("No more BARs available")

        mem = None
        if not read and not write:
            mem = mmap.mmap(-1, size)
            self.regions[self.bar_ptr] = (size, mem)
        else:
            self.regions[self.bar_ptr] = (size, read, write)
        if ext:
            self.bar_ptr += 2
        else:
            self.bar_ptr += 1
        return mem

    def add_io_region(self, size, read=None, write=None):
        return self.add_region(size, read, write, False, False, True)

    def add_mem_region(self, size, read=None, write=None):
        return self.add_region(size, read, write)

    def add_prefetchable_mem_region(self, size, read=None, write=None):
        return self.add_region(size, read, write, True, True)

    async def read_region(self, region, addr, length):
        if not self.regions[region]:
            raise Exception("Invalid region")
        if len(self.regions[region]) == 3:
            return await self.regions[region][1](addr, length)
        else:
            return self.regions[region][1][addr:addr+length]

    async def write_region(self, region, addr, data):
        if not self.regions[region]:
            raise Exception("Invalid region")
        if len(self.regions[region]) == 3:
            await self.regions[region][2](addr, data)
        else:
            self.regions[region][1][addr:addr+len(data)] = data

    async def recv_cpl(self, tag, timeout=0, timeout_unit='ns'):
        queue = self.rx_cpl_queues[tag]
        sync = self.rx_cpl_sync[tag]

        if not queue.empty():
            return queue.get_nowait()

        sync.clear()
        if timeout:
            await First(sync.wait(), Timer(timeout, timeout_unit))
        else:
            await sync.wait()

        if not queue.empty():
            return queue.get_nowait()

        return None

    async def alloc_tag(self):
        tag_count = min(256, self.tag_count)

        while True:
            tag = self.current_tag
            for k in range(tag_count):
                tag = (tag + 1) % tag_count
                if not self.tag_active[tag]:
                    self.tag_active[tag] = True
                    self.current_tag = tag
                    return tag

            self.tag_release.clear()
            await self.tag_release.wait()

    def release_tag(self, tag):
        assert self.tag_active[tag]
        self.tag_active[tag] = False
        self.tag_release.set()

    async def perform_posted_operation(self, source, req):
        await source.send(PcieIfFrame.from_tlp(req, self.force_64bit_addr))

    async def perform_nonposted_operation(self, source, req, timeout=0, timeout_unit='ns'):
        completions = []

        req.tag = await self.alloc_tag()

        await source.send(PcieIfFrame.from_tlp(req, self.force_64bit_addr))

        while True:
            cpl = await self.recv_cpl(req.tag, timeout, timeout_unit)

            if not cpl:
                break

            completions.append(cpl)

            if cpl.status != CplStatus.SC:
                # bad status
                break
            elif req.fmt_type in {TlpType.MEM_READ, TlpType.MEM_READ_64}:
                # completion for memory read request

                # request completed
                if cpl.byte_count <= cpl.length*4 - (cpl.lower_address & 0x3):
                    break

                # completion for read request has SC status but no data
                if cpl.fmt_type in {TlpType.CPL, TlpType.CPL_LOCKED}:
                    break

            else:
                # completion for other request
                break

        self.release_tag(req.tag)

        return completions

    async def dma_io_write(self, addr, data, timeout=0, timeout_unit='ns'):
        n = 0

        zero_len = len(data) == 0
        if zero_len:
            data = b'\x00'

        op_list = []

        while n < len(data):
            req = Tlp()
            req.fmt_type = TlpType.IO_WRITE
            req.requester_id = PcieId(self.dev_bus_num, self.dev_device_num, 0)

            first_pad = addr % 4
            byte_length = min(len(data)-n, 4-first_pad)
            req.set_addr_be_data(addr, data[n:n+byte_length])

            if zero_len:
                req.first_be = 0

            op_list.append(cocotb.start_soon(self.perform_nonposted_operation(self.tx_wr_req_tlp_source, req, timeout, timeout_unit)))

            n += byte_length
            addr += byte_length

        for op in op_list:
            cpl_list = await op.join()

            if not cpl_list:
                raise Exception("Timeout")
            if cpl_list[0].status != CplStatus.SC:
                raise Exception("Unsuccessful completion")

    async def dma_io_read(self, addr, length, timeout=0, timeout_unit='ns'):
        data = bytearray()
        n = 0

        zero_len = length <= 0
        if zero_len:
            length = 1

        op_list = []

        while n < length:
            req = Tlp()
            req.fmt_type = TlpType.IO_READ
            req.requester_id = PcieId(self.dev_bus_num, self.dev_device_num, 0)

            first_pad = addr % 4
            byte_length = min(length-n, 4-first_pad)
            req.set_addr_be(addr, byte_length)

            if zero_len:
                req.first_be = 0

            op_list.append((first_pad, cocotb.start_soon(self.perform_nonposted_operation(self.tx_rd_req_tlp_source, req, timeout, timeout_unit))))

            n += byte_length
            addr += byte_length

        for first_pad, op in op_list:
            cpl_list = await op.join()

            if not cpl_list:
                raise Exception("Timeout")
            cpl = cpl_list[0]
            if cpl.status != CplStatus.SC:
                raise Exception("Unsuccessful completion")

            assert cpl.length == 1
            d = cpl.get_data()

            data.extend(d[first_pad:])

        if zero_len:
            return b''

        return bytes(data[:length])

    async def dma_mem_write(self, addr, data, timeout=0, timeout_unit='ns'):
        n = 0

        zero_len = len(data) == 0
        if zero_len:
            data = b'\x00'

        while n < len(data):
            req = Tlp()
            if addr > 0xffffffff:
                req.fmt_type = TlpType.MEM_WRITE_64
            else:
                req.fmt_type = TlpType.MEM_WRITE
            req.requester_id = PcieId(self.dev_bus_num, self.dev_device_num, 0)

            first_pad = addr % 4
            byte_length = len(data)-n
            # max payload size
            byte_length = min(byte_length, (128 << self.dev_max_payload)-first_pad)
            # 4k address align
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff))
            req.set_addr_be_data(addr, data[n:n+byte_length])

            if zero_len:
                req.first_be = 0

            await self.perform_posted_operation(self.tx_wr_req_tlp_source, req)

            n += byte_length
            addr += byte_length

    async def dma_mem_read(self, addr, length, timeout=0, timeout_unit='ns'):
        data = bytearray()
        n = 0

        zero_len = length <= 0
        if zero_len:
            length = 1

        op_list = []

        while n < length:
            req = Tlp()
            if addr > 0xffffffff:
                req.fmt_type = TlpType.MEM_READ_64
            else:
                req.fmt_type = TlpType.MEM_READ
            req.requester_id = PcieId(self.dev_bus_num, self.dev_device_num, 0)

            first_pad = addr % 4
            # remaining length
            byte_length = length-n
            # limit to max read request size
            if byte_length > (128 << self.dev_max_read_req) - first_pad:
                # split on 128-byte read completion boundary
                byte_length = min(byte_length, (128 << self.dev_max_read_req) - (addr & 0x7f))
            # 4k align
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff))
            req.set_addr_be(addr, byte_length)

            if zero_len:
                req.first_be = 0

            op_list.append((byte_length, cocotb.start_soon(self.perform_nonposted_operation(self.tx_rd_req_tlp_source, req, timeout, timeout_unit))))

            n += byte_length
            addr += byte_length

        for byte_length, op in op_list:
            cpl_list = await op.join()

            m = 0

            while m < byte_length:
                if not cpl_list:
                    raise Exception("Timeout")

                cpl = cpl_list.pop(0)

                if cpl.status != CplStatus.SC:
                    raise Exception("Unsuccessful completion")

                assert cpl.byte_count+3+(cpl.lower_address & 3) >= cpl.length*4
                assert cpl.byte_count == max(byte_length - m, 1)

                d = cpl.get_data()

                offset = cpl.lower_address & 3
                data.extend(d[offset:offset+cpl.byte_count])

                m += len(d)-offset

        if zero_len:
            return b''

        return bytes(data[:length])

    async def issue_msi_interrupt(self, addr, data):
        data = data.to_bytes(4, 'little')
        n = 0

        while True:
            req = Tlp()
            if addr > 0xffffffff:
                req.fmt_type = TlpType.MEM_WRITE_64
            else:
                req.fmt_type = TlpType.MEM_WRITE
            req.requester_id = PcieId(self.dev_bus_num, self.dev_device_num, 0)

            first_pad = addr % 4
            byte_length = len(data)-n
            # max payload size
            byte_length = min(byte_length, (128 << self.dev_max_payload)-first_pad)
            # 4k address align
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff))
            req.set_addr_be_data(addr, data[n:n+byte_length])

            await self.perform_posted_operation(self.tx_msi_wr_req_tlp_source, req)

            n += byte_length
            addr += byte_length

            if n >= len(data):
                break

    async def _run_rx_req_tlp(self):
        while True:
            frame = await self.rx_req_tlp_sink.recv()

            tlp = frame.to_tlp()

            self.log.debug("RX TLP: %s", repr(tlp))

            if tlp.fmt_type in {TlpType.CPL, TlpType.CPL_DATA, TlpType.CPL_LOCKED, TlpType.CPL_LOCKED_DATA}:
                self.log.info("Completion")

                self.rx_cpl_queues[tlp.tag].put_nowait(tlp)
                self.rx_cpl_sync[tlp.tag].set()

            elif tlp.fmt_type == TlpType.IO_READ:
                self.log.info("IO read")

                cpl = Tlp.create_completion_data_for_tlp(tlp, PcieId(self.dev_bus_num, self.dev_device_num, 0))

                region = frame.bar_id
                addr = tlp.address % self.regions[region][0]
                offset = 0
                start_offset = None
                mask = tlp.first_be

                # perform operation
                data = bytearray(4)

                for k in range(4):
                    if mask & (1 << k):
                        if start_offset is None:
                            start_offset = offset
                    else:
                        if start_offset is not None and offset != start_offset:
                            data[start_offset:offset] = await self.read_region(region, addr+start_offset, offset-start_offset)
                        start_offset = None

                    offset += 1

                if start_offset is not None and offset != start_offset:
                    data[start_offset:offset] = await self.read_region(region, addr+start_offset, offset-start_offset)

                cpl.set_data(data)
                cpl.byte_count = 4
                cpl.length = 1

                self.log.debug("Completion: %s", repr(cpl))
                await self.tx_cpl_tlp_source.send(PcieIfFrame.from_tlp(cpl, self.force_64bit_addr))

            elif tlp.fmt_type == TlpType.IO_WRITE:
                self.log.info("IO write")

                cpl = Tlp.create_completion_for_tlp(tlp, PcieId(self.dev_bus_num, self.dev_device_num, 0))

                region = frame.bar_id
                addr = tlp.address % self.regions[region][0]
                offset = 0
                start_offset = None
                mask = tlp.first_be

                # perform operation
                data = tlp.get_data()

                for k in range(4):
                    if mask & (1 << k):
                        if start_offset is None:
                            start_offset = offset
                    else:
                        if start_offset is not None and offset != start_offset:
                            await self.write_region(region, addr+start_offset, data[start_offset:offset])
                        start_offset = None

                    offset += 1

                if start_offset is not None and offset != start_offset:
                    await self.write_region(region, addr+start_offset, data[start_offset:offset])

                self.log.debug("Completion: %s", repr(cpl))
                await self.tx_cpl_tlp_source.send(PcieIfFrame.from_tlp(cpl, self.force_64bit_addr))

            elif tlp.fmt_type in {TlpType.MEM_READ, TlpType.MEM_READ_64}:
                self.log.info("Memory read")

                # perform operation
                region = frame.bar_id
                addr = tlp.address % self.regions[region][0]
                offset = 0
                length = tlp.length

                # perform read
                data = bytearray(await self.read_region(region, addr, tlp.length*4))

                # prepare completion TLP(s)
                m = 0
                n = 0
                addr = tlp.address+tlp.get_first_be_offset()
                dw_length = tlp.length
                byte_length = tlp.get_be_byte_count()

                while m < dw_length:
                    cpl = Tlp.create_completion_data_for_tlp(tlp, PcieId(self.dev_bus_num, self.dev_device_num, 0))

                    cpl_dw_length = dw_length - m
                    cpl_byte_length = byte_length - n
                    cpl.byte_count = cpl_byte_length
                    if cpl_dw_length > 32 << self.dev_max_payload:
                        # max payload size
                        cpl_dw_length = 32 << self.dev_max_payload
                        # RCB align
                        cpl_dw_length -= (addr & 0x7c) >> 2

                    cpl.lower_address = addr & 0x7f

                    cpl.set_data(data[m*4:(m+cpl_dw_length)*4])

                    self.log.debug("Completion: %s", repr(cpl))
                    await self.tx_cpl_tlp_source.send(PcieIfFrame.from_tlp(cpl, self.force_64bit_addr))

                    m += cpl_dw_length
                    n += cpl_dw_length*4 - (addr & 3)
                    addr += cpl_dw_length*4 - (addr & 3)

            elif tlp.fmt_type in {TlpType.MEM_WRITE, TlpType.MEM_WRITE_64}:
                self.log.info("Memory write")

                # perform operation
                region = frame.bar_id
                addr = tlp.address % self.regions[region][0]
                offset = 0
                start_offset = None
                mask = tlp.first_be
                length = tlp.length

                # perform write
                data = tlp.get_data()

                # first dword
                for k in range(4):
                    if mask & (1 << k):
                        if start_offset is None:
                            start_offset = offset
                    else:
                        if start_offset is not None and offset != start_offset:
                            await self.write_region(region, addr+start_offset, data[start_offset:offset])
                        start_offset = None

                    offset += 1

                if length > 2:
                    # middle dwords
                    if start_offset is None:
                        start_offset = offset
                    offset += (length-2)*4

                if length > 1:
                    # last dword
                    mask = tlp.last_be

                    for k in range(4):
                        if mask & (1 << k):
                            if start_offset is None:
                                start_offset = offset
                        else:
                            if start_offset is not None and offset != start_offset:
                                await self.write_region(region, addr+start_offset, data[start_offset:offset])
                            start_offset = None

                        offset += 1

                if start_offset is not None and offset != start_offset:
                    await self.write_region(region, addr+start_offset, data[start_offset:offset])

    async def _run_rx_cpl_tlp(self):
        while True:
            frame = await self.rx_cpl_tlp_sink.recv()

            tlp = frame.to_tlp()

            self.log.debug("RX TLP: %s", repr(tlp))

            if tlp.fmt_type in {TlpType.CPL, TlpType.CPL_DATA, TlpType.CPL_LOCKED, TlpType.CPL_LOCKED_DATA}:
                self.log.info("Completion")

                self.rx_cpl_queues[tlp.tag].put_nowait(tlp)
                self.rx_cpl_sync[tlp.tag].set()
