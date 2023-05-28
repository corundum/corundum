"""

Copyright (c) 2020-2023 Alex Forencich

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
from typing import NamedTuple

import cocotb
from cocotb.queue import Queue
from cocotb.triggers import Event, RisingEdge
from cocotb_bus.bus import Bus

from cocotbext.axi.memory import Memory
from cocotbext.axi import Region


# master write helper objects
class WriteCmd(NamedTuple):
    address: int
    data: bytes
    event: Event


class SegWriteData:
    def __int__(self):
        self.addr = 0
        self.data = 0
        self.be = 0


class WriteRespCmd(NamedTuple):
    address: int
    length: int
    segments: int
    first_seg: int
    event: Event


class WriteResp(NamedTuple):
    address: int
    length: int


# master read helper objects
class ReadCmd(NamedTuple):
    address: int
    length: int
    event: Event


class SegReadCmd:
    def __int__(self):
        self.addr = 0


class ReadRespCmd(NamedTuple):
    address: int
    length: int
    segments: int
    first_seg: int
    event: Event


class ReadResp(NamedTuple):
    address: int
    data: bytes

    def __bytes__(self):
        return self.data


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


class PsdpRamWriteBus(BaseBus):
    _signals = ["wr_cmd_be", "wr_cmd_addr", "wr_cmd_data", "wr_cmd_valid", "wr_cmd_ready", "wr_done"]


class PsdpRamReadBus(BaseBus):
    _signals = ["rd_cmd_addr", "rd_cmd_valid", "rd_cmd_ready", "rd_resp_data", "rd_resp_valid", "rd_resp_ready"]


class PsdpRamBus:
    def __init__(self, write=None, read=None, **kwargs):
        self.write = write
        self.read = read

    @classmethod
    def from_entity(cls, entity, **kwargs):
        write = PsdpRamWriteBus.from_entity(entity, **kwargs)
        read = PsdpRamReadBus.from_entity(entity, **kwargs)
        return cls(write, read)

    @classmethod
    def from_prefix(cls, entity, prefix, **kwargs):
        write = PsdpRamWriteBus.from_prefix(entity, prefix, **kwargs)
        read = PsdpRamReadBus.from_prefix(entity, prefix, **kwargs)
        return cls(write, read)

    @classmethod
    def from_channels(cls, wr, rd):
        write = PsdpRamWriteBus.from_channels(wr)
        read = PsdpRamReadBus.from_channels(rd)
        return cls(write, read)


class PsdpRamMasterWrite(Region):

    def __init__(self, bus, clock, reset=None, **kwargs):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        if bus._name:
            self.log = logging.getLogger(f"cocotb.{bus._entity._name}.{bus._name}")
        else:
            self.log = logging.getLogger(f"cocotb.{bus._entity._name}")

        self.log.info("Parallel Simple Dual Port RAM master model (write)")
        self.log.info("Copyright (c) 2020 Alex Forencich")

        self.pause = False
        self._pause_generator = None
        self._pause_cr = None

        self.in_flight_operations = 0
        self._idle = Event()
        self._idle.set()

        self.width = len(self.bus.wr_cmd_data)
        self.byte_size = 8
        self.byte_lanes = len(self.bus.wr_cmd_be)

        self.seg_count = len(self.bus.wr_cmd_valid)
        self.seg_data_width = self.width // self.seg_count
        self.seg_byte_lanes = self.seg_data_width // self.byte_size
        self.seg_addr_width = len(self.bus.wr_cmd_addr) // self.seg_count
        self.seg_be_width = self.seg_data_width // self.byte_size

        self.seg_data_mask = 2**self.seg_data_width-1
        self.seg_addr_mask = 2**self.seg_addr_width-1
        self.seg_be_mask = 2**self.seg_be_width-1

        self.address_width = self.seg_addr_width + (self.seg_byte_lanes*self.seg_count-1).bit_length()

        self.write_command_queue = Queue()
        self.write_command_queue.queue_occupancy_limit = 2
        self.current_write_command = None

        self.seg_write_queue = [Queue() for x in range(self.seg_count)]
        self.seg_write_resp_queue = [Queue() for x in range(self.seg_count)]

        self.int_write_resp_command_queue = Queue()
        self.current_write_resp_command = None

        super().__init__(2**self.address_width, **kwargs)

        self.log.info("Parallel Simple Dual Port RAM master model configuration:")
        self.log.info("  Address width: %d bits", self.address_width)
        self.log.info("  Segment count: %d", self.seg_count)
        self.log.info("  Segment addr width: %d bits", self.seg_addr_width)
        self.log.info("  Segment data width: %d bits (%d bytes)", self.seg_data_width, self.seg_byte_lanes)
        self.log.info("  Total data width: %d bits (%d bytes)", self.width, self.byte_lanes)

        assert self.seg_be_width*self.seg_count == len(self.bus.wr_cmd_be)

        self.bus.wr_cmd_valid.setimmediatevalue(0)

        cocotb.start_soon(self._process_write())
        cocotb.start_soon(self._process_write_resp())
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

    def idle(self):
        return not self.in_flight_operations

    async def wait(self):
        while not self.idle():
            await self._idle.wait()

    async def write(self, address, data):
        if address < 0 or address >= 2**self.address_width:
            raise ValueError("Address out of range")

        if isinstance(data, int):
            raise ValueError("Expected bytes or bytearray for data")

        if address+len(data) > 2**self.address_width:
            raise ValueError("Requested transfer overruns end of address space")

        event = Event()
        data = bytes(data)

        self.in_flight_operations += 1
        self._idle.clear()

        await self.write_command_queue.put(WriteCmd(address, data, event))
        await event.wait()
        return event.data

    async def _process_write(self):
        while True:
            cmd = await self.write_command_queue.get()
            self.current_write_command = cmd

            seg_start_offset = cmd.address % self.seg_byte_lanes
            seg_end_offset = ((cmd.address + len(cmd.data) - 1) % self.seg_byte_lanes) + 1

            seg_be_start = (self.seg_be_mask << seg_start_offset) & self.seg_be_mask
            seg_be_end = self.seg_be_mask >> (self.seg_byte_lanes - seg_end_offset)

            first_seg = (cmd.address // self.seg_byte_lanes) % self.seg_count
            segments = (len(cmd.data) + (cmd.address % self.seg_byte_lanes) + self.seg_byte_lanes-1) // self.seg_byte_lanes

            resp_cmd = WriteRespCmd(cmd.address, len(cmd.data), segments, first_seg, cmd.event)
            await self.int_write_resp_command_queue.put(resp_cmd)

            offset = 0

            if self.log.isEnabledFor(logging.INFO):
                self.log.info("Write start addr: 0x%08x data: %s",
                        cmd.address, ' '.join((f'{c:02x}' for c in cmd.data)))

            seg = first_seg
            for k in range(segments):
                start = 0
                stop = self.seg_byte_lanes
                be = self.seg_be_mask

                if k == 0:
                    start = seg_start_offset
                    be &= seg_be_start
                if k == segments-1:
                    stop = seg_end_offset
                    be &= seg_be_end

                val = 0
                for j in range(start, stop):
                    val |= cmd.data[offset] << j*8
                    offset += 1

                op = SegWriteData()
                op.addr = (cmd.address + k*self.seg_byte_lanes) // self.byte_lanes
                op.data = val
                op.be = be

                await self.seg_write_queue[seg].put(op)

                seg = (seg + 1) % self.seg_count

            self.current_write_command = None

    async def _process_write_resp(self):
        while True:
            cmd = await self.int_write_resp_command_queue.get()
            self.current_write_resp_command = cmd

            seg = cmd.first_seg
            for k in range(cmd.segments):
                await self.seg_write_resp_queue[seg].get()

                seg = (seg + 1) % self.seg_count

            if self.log.isEnabledFor(logging.INFO):
                self.log.info("Write complete addr: 0x%08x length: %d", cmd.address, cmd.length)

            write_resp = WriteResp(cmd.address, cmd.length)

            cmd.event.set(write_resp)

            self.current_write_resp_command = None

            self.in_flight_operations -= 1

            if self.in_flight_operations == 0:
                self._idle.set()

    async def _run(self):
        cmd_valid = 0
        cmd_addr = 0
        cmd_data = 0
        cmd_be = 0

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            cmd_ready_sample = self.bus.wr_cmd_ready.value
            done_sample = self.bus.wr_done.value

            if self.reset is not None and self.reset.value:
                self.bus.wr_cmd_valid.setimmediatevalue(0)
                continue

            # process segments
            for seg in range(self.seg_count):
                seg_mask = 1 << seg

                if (cmd_ready_sample & seg_mask) or not (cmd_valid & seg_mask):
                    if not self.seg_write_queue[seg].empty() and not self.pause:
                        op = await self.seg_write_queue[seg].get()
                        cmd_addr &= ~(self.seg_addr_mask << self.seg_addr_width*seg)
                        cmd_addr |= ((op.addr & self.seg_addr_mask) << self.seg_addr_width*seg)
                        cmd_data &= ~(self.seg_data_mask << self.seg_data_width*seg)
                        cmd_data |= ((op.data & self.seg_data_mask) << self.seg_data_width*seg)
                        cmd_be &= ~(self.seg_be_mask << self.seg_be_width*seg)
                        cmd_be |= ((op.be & self.seg_be_mask) << self.seg_be_width*seg)
                        cmd_valid |= seg_mask

                        if self.log.isEnabledFor(logging.INFO):
                            self.log.info("Write word seg: %d addr: 0x%08x be 0x%02x data %s",
                                seg, op.addr, op.be, ' '.join((f'{c:02x}' for c in op.data.to_bytes(self.seg_byte_lanes, 'little'))))
                    else:
                        cmd_valid &= ~seg_mask

                if done_sample & seg_mask:
                    await self.seg_write_resp_queue[seg].put(None)

            self.bus.wr_cmd_valid.value = cmd_valid
            self.bus.wr_cmd_addr.value = cmd_addr
            self.bus.wr_cmd_data.value = cmd_data
            self.bus.wr_cmd_be.value = cmd_be

    async def _run_pause(self):
        clock_edge_event = RisingEdge(self.clock)

        for val in self._pause_generator:
            self.pause = val
            await clock_edge_event


class PsdpRamMasterRead(Region):

    def __init__(self, bus, clock, reset=None, **kwargs):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        if bus._name:
            self.log = logging.getLogger(f"cocotb.{bus._entity._name}.{bus._name}")
        else:
            self.log = logging.getLogger(f"cocotb.{bus._entity._name}")

        self.log.info("Parallel Simple Dual Port RAM master model (read)")
        self.log.info("Copyright (c) 2020 Alex Forencich")

        self.pause = False
        self._pause_generator = None
        self._pause_cr = None

        self.in_flight_operations = 0
        self._idle = Event()
        self._idle.set()

        self.width = len(self.bus.rd_resp_data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        self.seg_count = len(self.bus.rd_cmd_valid)
        self.seg_data_width = self.width // self.seg_count
        self.seg_byte_lanes = self.seg_data_width // self.byte_size
        self.seg_addr_width = len(self.bus.rd_cmd_addr) // self.seg_count

        self.seg_data_mask = 2**self.seg_data_width-1
        self.seg_addr_mask = 2**self.seg_addr_width-1

        self.address_width = self.seg_addr_width + (self.seg_byte_lanes*self.seg_count-1).bit_length()

        self.read_command_queue = Queue()
        self.read_command_queue.queue_occupancy_limit = 2
        self.current_read_command = None

        self.seg_read_queue = [Queue() for x in range(self.seg_count)]
        self.seg_read_resp_queue = [Queue() for x in range(self.seg_count)]

        self.int_read_resp_command_queue = Queue()
        self.current_read_resp_command = None

        super().__init__(2**self.address_width, **kwargs)

        self.log.info("Parallel Simple Dual Port RAM master model configuration:")
        self.log.info("  Address width: %d bits", self.address_width)
        self.log.info("  Segment count: %d", self.seg_count)
        self.log.info("  Segment addr width: %d bits", self.seg_addr_width)
        self.log.info("  Segment data width: %d bits (%d bytes)", self.seg_data_width, self.seg_byte_lanes)
        self.log.info("  Total data width: %d bits (%d bytes)", self.width, self.byte_lanes)

        self.bus.rd_cmd_valid.setimmediatevalue(0)
        self.bus.rd_resp_ready.setimmediatevalue(0)

        cocotb.start_soon(self._process_read())
        cocotb.start_soon(self._process_read_resp())
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

    def idle(self):
        return not self.in_flight_operations

    async def wait(self):
        while not self.idle():
            await self._idle.wait()

    async def read(self, address, length):
        if address < 0 or address >= 2**self.address_width:
            raise ValueError("Address out of range")

        if length < 0:
            raise ValueError("Read length must be positive")

        if address+length > 2**self.address_width:
            raise ValueError("Requested transfer overruns end of address space")

        event = Event()

        self.in_flight_operations += 1
        self._idle.clear()

        await self.read_command_queue.put(ReadCmd(address, length, event))

        await event.wait()
        return event.data

    async def _process_read(self):
        while True:
            cmd = await self.read_command_queue.get()
            self.current_read_command = cmd

            first_seg = (cmd.address // self.seg_byte_lanes) % self.seg_count
            segments = (cmd.length + (cmd.address % self.seg_byte_lanes) + self.seg_byte_lanes-1) // self.seg_byte_lanes

            resp_cmd = ReadRespCmd(cmd.address, cmd.length, segments, first_seg, cmd.event)
            await self.int_read_resp_command_queue.put(resp_cmd)

            if self.log.isEnabledFor(logging.INFO):
                self.log.info("Read start addr: 0x%08x length: %d", cmd.address, cmd.length)

            seg = first_seg
            for k in range(segments):
                op = SegReadCmd()
                op.addr = (cmd.address + k*self.seg_byte_lanes) // self.byte_lanes

                await self.seg_read_queue[seg].put(op)

                seg = (seg + 1) % self.seg_count

            self.current_read_command = None

    async def _process_read_resp(self):
        while True:
            cmd = await self.int_read_resp_command_queue.get()
            self.current_read_resp_command = cmd

            seg_start_offset = cmd.address % self.seg_byte_lanes
            seg_end_offset = ((cmd.address + cmd.length - 1) % self.seg_byte_lanes) + 1

            data = bytearray()

            seg = cmd.first_seg
            for k in range(cmd.segments):
                seg_data = await self.seg_read_resp_queue[seg].get()

                start = 0
                stop = self.seg_byte_lanes

                if k == 0:
                    start = seg_start_offset
                if k == cmd.segments-1:
                    stop = seg_end_offset

                for j in range(start, stop):
                    data.extend(bytearray([(seg_data >> j*8) & 0xff]))

                seg = (seg + 1) % self.seg_count

            if self.log.isEnabledFor(logging.INFO):
                self.log.info("Read complete addr: 0x%08x data: %s",
                        cmd.address, ' '.join((f'{c:02x}' for c in data)))

            read_resp = ReadResp(cmd.address, bytes(data))

            cmd.event.set(read_resp)

            self.current_read_resp_command = None

            self.in_flight_operations -= 1

            if self.in_flight_operations == 0:
                self._idle.set()

    async def _run(self):
        cmd_valid = 0
        cmd_addr = 0
        resp_ready = 0

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            cmd_ready_sample = self.bus.rd_cmd_ready.value
            resp_valid_sample = self.bus.rd_resp_valid.value

            if resp_valid_sample:
                resp_data_sample = self.bus.rd_resp_data.value

            if self.reset is not None and self.reset.value:
                self.bus.rd_cmd_valid.setimmediatevalue(0)
                self.bus.rd_resp_ready.setimmediatevalue(0)
                cmd_valid = 0
                resp_ready = 0
                continue

            # process segments
            for seg in range(self.seg_count):
                seg_mask = 1 << seg

                if (cmd_ready_sample & seg_mask) or not (cmd_valid & seg_mask):
                    if not self.seg_read_queue[seg].empty() and not self.pause:
                        op = await self.seg_read_queue[seg].get()
                        cmd_addr &= ~(self.seg_addr_mask << self.seg_addr_width*seg)
                        cmd_addr |= ((op.addr & self.seg_addr_mask) << self.seg_addr_width*seg)
                        cmd_valid |= seg_mask

                        if self.log.isEnabledFor(logging.INFO):
                            self.log.info("Read word seg: %d addr: 0x%08x", seg, op.addr)
                    else:
                        cmd_valid &= ~seg_mask

                if resp_ready & resp_valid_sample & (1 << seg):
                    seg_data = (resp_data_sample >> self.seg_data_width*seg) & self.seg_data_mask

                    await self.seg_read_resp_queue[seg].put(seg_data)

            resp_ready = 2**self.seg_count-1

            if self.pause:
                resp_ready = 0

            self.bus.rd_cmd_valid.value = cmd_valid
            self.bus.rd_cmd_addr.value = cmd_addr

            self.bus.rd_resp_ready.value = resp_ready

    async def _run_pause(self):
        clock_edge_event = RisingEdge(self.clock)

        for val in self._pause_generator:
            self.pause = val
            await clock_edge_event


class PsdpRamMaster(Region):
    def __init__(self, bus, clock, reset=None, **kwargs):
        self.write_if = None
        self.read_if = None

        self.write_if = PsdpRamMasterWrite(bus.write, clock, reset)
        self.read_if = PsdpRamMasterRead(bus.read, clock, reset)

        super().__init__(max(self.write_if.size, self.read_if.size), **kwargs)

    def init_read(self, address, length, event=None):
        return self.read_if.init_read(address, length, event)

    def init_write(self, address, data, event=None):
        return self.write_if.init_write(address, data, event)

    def idle(self):
        return (not self.read_if or self.read_if.idle()) and (not self.write_if or self.write_if.idle())

    async def wait(self):
        while not self.idle():
            await self.write_if.wait()
            await self.read_if.wait()

    async def wait_read(self):
        await self.read_if.wait()

    async def wait_write(self):
        await self.write_if.wait()

    async def read(self, address, length):
        return await self.read_if.read(address, length)

    async def write(self, address, data):
        return await self.write_if.write(address, data)


class PsdpRamWrite(Memory):

    def __init__(self, bus, clock, reset=None, size=1024, mem=None, *args, **kwargs):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        self.log = logging.getLogger(f"cocotb.{bus._entity._name}.{bus._name}")

        self.log.info("Parallel Simple Dual Port RAM model (write)")
        self.log.info("Copyright (c) 2020 Alex Forencich")

        super().__init__(size, mem, *args, **kwargs)

        self.pause = False
        self._pause_generator = None
        self._pause_cr = None

        self.width = len(self.bus.wr_cmd_data)
        self.byte_size = 8
        self.byte_lanes = len(self.bus.wr_cmd_be)

        self.seg_count = len(self.bus.wr_cmd_valid)
        self.seg_data_width = self.width // self.seg_count
        self.seg_byte_lanes = self.seg_data_width // self.byte_size
        self.seg_addr_width = len(self.bus.wr_cmd_addr) // self.seg_count
        self.seg_be_width = self.seg_data_width // self.byte_size

        self.seg_data_mask = 2**self.seg_data_width-1
        self.seg_addr_mask = 2**self.seg_addr_width-1
        self.seg_be_mask = 2**self.seg_be_width-1

        self.log.info("Parallel Simple Dual Port RAM model configuration:")
        self.log.info("  Memory size: %d bytes", len(self.mem))
        self.log.info("  Segment count: %d", self.seg_count)
        self.log.info("  Segment addr width: %d bits", self.seg_addr_width)
        self.log.info("  Segment data width: %d bits (%d bytes)", self.seg_data_width, self.seg_byte_lanes)
        self.log.info("  Total data width: %d bits (%d bytes)", self.width, self.byte_lanes)

        assert self.seg_be_width*self.seg_count == len(self.bus.wr_cmd_be)

        self.bus.wr_cmd_ready.setimmediatevalue(0)
        self.bus.wr_done.setimmediatevalue(0)

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

    async def _run(self):
        cmd_ready = 0

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            wr_done = 0

            cmd_valid_sample = self.bus.wr_cmd_valid.value

            if cmd_valid_sample:
                cmd_be_sample = self.bus.wr_cmd_be.value
                cmd_addr_sample = self.bus.wr_cmd_addr.value
                cmd_data_sample = self.bus.wr_cmd_data.value

            if self.reset is not None and self.reset.value:
                self.bus.wr_cmd_ready.setimmediatevalue(0)
                self.bus.wr_done.setimmediatevalue(0)
                continue

            # process segments
            for seg in range(self.seg_count):
                if cmd_ready & cmd_valid_sample & (1 << seg):
                    seg_addr = (cmd_addr_sample >> self.seg_addr_width*seg) & self.seg_addr_mask
                    seg_data = (cmd_data_sample >> self.seg_data_width*seg) & self.seg_data_mask
                    seg_be = (cmd_be_sample >> self.seg_be_width*seg) & self.seg_be_mask

                    addr = (seg_addr*self.seg_count+seg)*self.seg_byte_lanes

                    # generate operation list
                    offset = 0
                    start_offset = None
                    write_ops = []

                    data = seg_data.to_bytes(self.seg_byte_lanes, 'little')

                    for i in range(self.byte_lanes):
                        if seg_be & (1 << i):
                            if start_offset is None:
                                start_offset = offset
                        else:
                            if start_offset is not None and offset != start_offset:
                                write_ops.append((addr+start_offset, data[start_offset:offset]))
                            start_offset = None

                        offset += 1

                    if start_offset is not None and offset != start_offset:
                        write_ops.append((addr+start_offset, data[start_offset:offset]))

                    # perform writes
                    for addr, data in write_ops:
                        self.write(addr, data)

                    wr_done |= 1 << seg

                    self.log.info("Write word seg: %d addr: 0x%08x be 0x%02x data %s",
                        seg, addr, seg_be, ' '.join((f'{c:02x}' for c in data)))

            cmd_ready = 2**self.seg_count-1

            if self.pause:
                cmd_ready = 0

            self.bus.wr_cmd_ready.value = cmd_ready
            self.bus.wr_done.value = wr_done

    async def _run_pause(self):
        clock_edge_event = RisingEdge(self.clock)

        for val in self._pause_generator:
            self.pause = val
            await clock_edge_event


class PsdpRamRead(Memory):

    def __init__(self, bus, clock, reset=None, size=1024, mem=None, *args, **kwargs):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        self.log = logging.getLogger(f"cocotb.{bus._entity._name}.{bus._name}")

        self.log.info("Parallel Simple Dual Port RAM model (read)")
        self.log.info("Copyright (c) 2020 Alex Forencich")

        super().__init__(size, mem, *args, **kwargs)

        self.pause = False
        self._pause_generator = None
        self._pause_cr = None

        self.width = len(self.bus.rd_resp_data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        self.seg_count = len(self.bus.rd_cmd_valid)
        self.seg_data_width = self.width // self.seg_count
        self.seg_byte_lanes = self.seg_data_width // self.byte_size
        self.seg_addr_width = len(self.bus.rd_cmd_addr) // self.seg_count

        self.seg_data_mask = 2**self.seg_data_width-1
        self.seg_addr_mask = 2**self.seg_addr_width-1

        self.log.info("Parallel Simple Dual Port RAM model configuration:")
        self.log.info("  Memory size: %d bytes", len(self.mem))
        self.log.info("  Segment count: %d", self.seg_count)
        self.log.info("  Segment addr width: %d bits", self.seg_addr_width)
        self.log.info("  Segment data width: %d bits (%d bytes)", self.seg_data_width, self.seg_byte_lanes)
        self.log.info("  Total data width: %d bits (%d bytes)", self.width, self.byte_lanes)

        self.bus.rd_cmd_ready.setimmediatevalue(0)
        self.bus.rd_resp_valid.setimmediatevalue(0)

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

    async def _run(self):
        pipeline = [[None for x in range(1)] for seg in range(self.seg_count)]

        cmd_ready = 0
        resp_valid = 0
        resp_data = 0

        clock_edge_event = RisingEdge(self.clock)

        while True:
            await clock_edge_event

            cmd_valid_sample = self.bus.rd_cmd_valid.value

            if cmd_valid_sample:
                cmd_addr_sample = self.bus.rd_cmd_addr.value

            resp_ready_sample = self.bus.rd_resp_ready.value

            if self.reset is not None and self.reset.value:
                self.bus.rd_cmd_ready.setimmediatevalue(0)
                self.bus.rd_resp_valid.setimmediatevalue(0)
                cmd_ready = 0
                resp_valid = 0
                continue

            # process segments
            for seg in range(self.seg_count):
                seg_mask = 1 << seg

                if (resp_ready_sample & seg_mask) or not (resp_valid & seg_mask):
                    if pipeline[seg][-1] is not None:
                        resp_data &= ~(self.seg_data_mask << self.seg_data_width*seg)
                        resp_data |= ((pipeline[seg][-1] & self.seg_data_mask) << self.seg_data_width*seg)
                        resp_valid |= seg_mask
                        pipeline[seg][-1] = None
                    else:
                        resp_valid &= ~seg_mask

                for i in range(len(pipeline[seg])-1, 0, -1):
                    if pipeline[seg][i] is None:
                        pipeline[i] = pipeline[i-1]
                        pipeline[i-1] = None

                if cmd_ready & cmd_valid_sample & seg_mask:
                    seg_addr = (cmd_addr_sample >> self.seg_addr_width*seg) & self.seg_addr_mask

                    addr = (seg_addr*self.seg_count+seg)*self.seg_byte_lanes

                    data = self.read(addr % self.size, self.seg_byte_lanes)
                    pipeline[seg][0] = int.from_bytes(data, 'little')

                    self.log.info("Read word seg: %d addr: 0x%08x data %s",
                        seg, addr, ' '.join((f'{c:02x}' for c in data)))

                if (not resp_valid & seg_mask) or None in pipeline[seg]:
                    cmd_ready |= seg_mask
                else:
                    cmd_ready &= ~seg_mask

            if self.pause:
                cmd_ready = 0

            self.bus.rd_cmd_ready.value = cmd_ready

            self.bus.rd_resp_data.value = resp_data
            self.bus.rd_resp_valid.value = resp_valid

    async def _run_pause(self):
        clock_edge_event = RisingEdge(self.clock)

        for val in self._pause_generator:
            self.pause = val
            await clock_edge_event


class PsdpRam(Memory):
    def __init__(self, bus, clock, reset=None, size=1024, mem=None, *args, **kwargs):
        self.write_if = None
        self.read_if = None

        super().__init__(size, mem, *args, **kwargs)

        self.write_if = PsdpRamWrite(bus.write, clock, reset, mem=self.mem)
        self.read_if = PsdpRamRead(bus.read, clock, reset, mem=self.mem)
