"""

Copyright (c) 2018 Alex Forencich

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

from myhdl import *
import mmap

class AXILiteMaster(object):
    def __init__(self):
        self.write_command_queue = []
        self.write_resp_queue = []

        self.read_command_queue = []
        self.read_data_queue = []

        self.int_write_addr_queue = []
        self.int_write_data_queue = []
        self.int_write_resp_command_queue = []
        self.int_write_resp_queue = []

        self.int_read_addr_queue = []
        self.int_read_resp_command_queue = []
        self.int_read_resp_queue = []

        self.in_flight_operations = 0

        self.has_logic = False
        self.clk = None

    def init_read(self, address, length, prot=0b010):
        self.read_command_queue.append((address, length, prot))

    def init_write(self, address, data, prot=0b010):
        self.write_command_queue.append((address, data, prot))

    def idle(self):
        return not self.write_command_queue and not self.read_command_queue and not self.in_flight_operations

    def wait(self):
        while not self.idle():
            yield self.clk.posedge

    def read_data_ready(self):
        return bool(self.read_data_queue)

    def get_read_data(self):
        if self.read_data_queue:
            return self.read_data_queue.pop(0)
        return None

    def create_logic(self,
                clk,
                rst,
                m_axil_awaddr=None,
                m_axil_awprot=Signal(intbv(0)[3:]),
                m_axil_awvalid=Signal(bool(False)),
                m_axil_awready=Signal(bool(True)),
                m_axil_wdata=None,
                m_axil_wstrb=Signal(intbv(1)[1:]),
                m_axil_wvalid=Signal(bool(False)),
                m_axil_wready=Signal(bool(True)),
                m_axil_bresp=Signal(intbv(0)[2:]),
                m_axil_bvalid=Signal(bool(False)),
                m_axil_bready=Signal(bool(False)),
                m_axil_araddr=None,
                m_axil_arprot=Signal(intbv(0)[3:]),
                m_axil_arvalid=Signal(bool(False)),
                m_axil_arready=Signal(bool(True)),
                m_axil_rdata=None,
                m_axil_rresp=Signal(intbv(0)[2:]),
                m_axil_rvalid=Signal(bool(False)),
                m_axil_rready=Signal(bool(False)),
                name=None
            ):
        
        if self.has_logic:
            raise Exception("Logic already instantiated!")

        if m_axil_wdata is not None:
            assert m_axil_awaddr is not None
            assert len(m_axil_wdata) % 8 == 0
            assert len(m_axil_wdata) / 8 == len(m_axil_wstrb)
            w = len(m_axil_wdata)

        if m_axil_rdata is not None:
            assert m_axil_araddr is not None
            assert len(m_axil_rdata) % 8 == 0
            w = len(m_axil_rdata)

            if m_axil_wdata is not None:
                assert len(m_axil_wdata) == len(m_axil_rdata)
                assert len(m_axil_awaddr) == len(m_axil_araddr)

        bw = int(w/8)

        assert bw in (1, 2, 4, 8, 16, 32, 64, 128)

        self.has_logic = True
        self.clk = clk

        @instance
        def write_logic():
            while True:
                while not self.write_command_queue:
                    yield clk.posedge

                addr, data, prot = self.write_command_queue.pop(0)
                self.in_flight_operations += 1

                word_addr = int(addr/bw)*bw

                start_offset = addr % bw
                end_offset = ((addr + len(data) - 1) % bw) + 1

                strb_start = ((2**bw-1) << start_offset) & (2**bw-1)
                strb_end = (2**bw-1) >> (bw - end_offset)

                cycles = int((len(data) + bw-1 + (addr % bw)) / bw)

                self.int_write_resp_command_queue.append((addr, len(data), cycles, prot))

                offset = 0

                if name is not None:
                    print("[%s] Write data addr: 0x%08x prot: 0x%x data: %s" % (name, addr, prot, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                for k in range(cycles):
                    start = 0
                    stop = bw
                    strb = 2**bw-1

                    if k == 0:
                        start = start_offset
                        strb &= strb_start
                    if k == cycles-1:
                        stop = end_offset
                        strb &= strb_end

                    val = 0
                    for j in range(start, stop):
                        val |= bytearray(data)[offset] << j*8
                        offset += 1

                    self.int_write_addr_queue.append((word_addr + start + k*bw, prot))
                    self.int_write_data_queue.append((val, strb))

        @instance
        def write_resp_logic():
            while True:
                while not self.int_write_resp_command_queue:
                    yield clk.posedge

                addr, length, cycles, prot = self.int_write_resp_command_queue.pop(0)

                resp = 0

                for k in range(cycles):
                    while not self.int_write_resp_queue:
                        yield clk.posedge

                    cycle_resp = self.int_write_resp_queue.pop(0)

                    if cycle_resp != 0:
                        resp = cycle_resp

                self.write_resp_queue.append((addr, length, prot, resp))
                self.in_flight_operations -= 1

        @instance
        def write_addr_interface_logic():
            while True:
                while not self.int_write_addr_queue:
                    yield clk.posedge

                m_axil_awaddr.next, m_axil_awprot.next = self.int_write_addr_queue.pop(0)
                m_axil_awvalid.next = True

                yield clk.posedge

                while m_axil_awvalid and not m_axil_awready:
                    yield clk.posedge

                m_axil_awvalid.next = False

        @instance
        def write_data_interface_logic():
            while True:
                while not self.int_write_data_queue:
                    yield clk.posedge

                m_axil_wdata.next, m_axil_wstrb.next = self.int_write_data_queue.pop(0)
                m_axil_wvalid.next = True

                yield clk.posedge

                while m_axil_wvalid and not m_axil_wready:
                    yield clk.posedge

                m_axil_wvalid.next = False

        @instance
        def write_resp_interface_logic():
            while True:
                m_axil_bready.next = True

                yield clk.posedge

                if m_axil_bready & m_axil_bvalid:
                    self.int_write_resp_queue.append(int(m_axil_bresp))

        @instance
        def read_logic():
            while True:
                while not self.read_command_queue:
                    yield clk.posedge

                addr, length, prot = self.read_command_queue.pop(0)
                self.in_flight_operations += 1

                word_addr = int(addr/bw)*bw

                start_offset = addr % bw

                cycles = int((length + bw-1 + (addr % bw)) / bw)

                self.int_read_resp_command_queue.append((addr, length, cycles, prot))

                # first cycle
                self.int_read_addr_queue.append((word_addr+start_offset, prot))

                for k in range(1, cycles):
                    # middle and last cycles
                    self.int_read_addr_queue.append((word_addr + k*bw, prot))

        @instance
        def read_resp_logic():
            while True:
                while not self.int_read_resp_command_queue:
                    yield clk.posedge

                addr, length, cycles, prot = self.int_read_resp_command_queue.pop(0)

                word_addr = int(addr/bw)*bw

                start_offset = addr % bw
                end_offset = ((addr + length - 1) % bw) + 1

                data = b''

                resp = 0

                for k in range(cycles):
                    while not self.int_read_resp_queue:
                        yield clk.posedge

                    cycle_data, cycle_resp = self.int_read_resp_queue.pop(0)

                    if cycle_resp != 0:
                        resp = cycle_resp

                    start = 0
                    stop = bw

                    if k == 0:
                        start = start_offset
                    if k == cycles-1:
                        stop = end_offset

                    for j in range(start, stop):
                        data += bytearray([(cycle_data >> j*8) & 0xff])

                if name is not None:
                    print("[%s] Read data addr: 0x%08x prot: 0x%x data: %s" % (name, addr, prot, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                self.read_data_queue.append((addr, data, prot, resp))
                self.in_flight_operations -= 1

        @instance
        def read_addr_interface_logic():
            while True:
                while not self.int_read_addr_queue:
                    yield clk.posedge

                m_axil_araddr.next, m_axil_arprot.next = self.int_read_addr_queue.pop(0)
                m_axil_arvalid.next = True

                yield clk.posedge

                while m_axil_arvalid and not m_axil_arready:
                    yield clk.posedge

                m_axil_arvalid.next = False

        @instance
        def read_resp_interface_logic():
            while True:
                m_axil_rready.next = True

                yield clk.posedge

                if m_axil_rready & m_axil_rvalid:
                    self.int_read_resp_queue.append((int(m_axil_rdata), int(m_axil_rresp)))

        return instances()


class AXILiteRam(object):
    def __init__(self, size = 1024):
        self.size = size
        self.mem = mmap.mmap(-1, size)

    def read_mem(self, address, length):
        self.mem.seek(address)
        return self.mem.read(length)

    def write_mem(self, address, data):
        self.mem.seek(address)
        self.mem.write(bytes(data))

    def create_port(self,
                clk,
                s_axil_awaddr=None,
                s_axil_awprot=Signal(intbv(0)[3:]),
                s_axil_awvalid=Signal(bool(False)),
                s_axil_awready=Signal(bool(True)),
                s_axil_wdata=None,
                s_axil_wstrb=Signal(intbv(1)[1:]),
                s_axil_wvalid=Signal(bool(False)),
                s_axil_wready=Signal(bool(True)),
                s_axil_bresp=Signal(intbv(0)[2:]),
                s_axil_bvalid=Signal(bool(False)),
                s_axil_bready=Signal(bool(False)),
                s_axil_araddr=None,
                s_axil_arprot=Signal(intbv(0)[3:]),
                s_axil_arvalid=Signal(bool(False)),
                s_axil_arready=Signal(bool(True)),
                s_axil_rdata=None,
                s_axil_rresp=Signal(intbv(0)[2:]),
                s_axil_rvalid=Signal(bool(False)),
                s_axil_rready=Signal(bool(False)),
                latency=1,
                name=None
            ):

        if s_axil_wdata is not None:
            assert s_axil_awaddr is not None
            assert len(s_axil_wdata) % 8 == 0
            assert len(s_axil_wdata) / 8 == len(s_axil_wstrb)
            w = len(s_axil_wdata)

        if s_axil_rdata is not None:
            assert s_axil_araddr is not None
            assert len(s_axil_rdata) % 8 == 0
            w = len(s_axil_rdata)

            if s_axil_wdata is not None:
                assert len(s_axil_wdata) == len(s_axil_rdata)
                assert len(s_axil_awaddr) == len(s_axil_araddr)

        bw = int(w/8)

        assert bw in (1, 2, 4, 8, 16, 32, 64, 128)

        @instance
        def write_logic():
            while True:
                s_axil_awready.next = True

                yield clk.posedge

                addr = int(int(s_axil_awaddr)/bw)*bw
                prot = int(s_axil_awprot)

                if s_axil_awready & s_axil_awvalid:
                    s_axil_awready.next = False

                    for i in range(latency):
                        yield clk.posedge

                    self.mem.seek(addr % self.size)

                    s_axil_wready.next = True

                    yield clk.posedge

                    while not s_axil_wvalid:
                        yield clk.posedge

                    s_axil_wready.next = False

                    data = bytearray()
                    val = int(s_axil_wdata)
                    for i in range(bw):
                        data.extend(bytearray([val & 0xff]))
                        val >>= 8
                    for i in range(bw):
                        if s_axil_wstrb & (1 << i):
                            self.mem.write(bytes(data[i:i+1]))
                        else:
                            self.mem.seek(1, 1)
                    s_axil_bresp.next = 0b00
                    s_axil_bvalid.next = True
                    if name is not None:
                        print("[%s] Write word addr: 0x%08x prot: 0x%x wstrb: 0x%02x data: %s" % (name, addr, prot, s_axil_wstrb, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                    yield clk.posedge

                    while not s_axil_bready:
                        yield clk.posedge

                    s_axil_bvalid.next = False

        @instance
        def read_logic():
            while True:
                s_axil_arready.next = True

                yield clk.posedge

                addr = int(int(s_axil_araddr)/bw)*bw
                prot = int(s_axil_arprot)

                if s_axil_arready & s_axil_arvalid:
                    s_axil_arready.next = False

                    for i in range(latency):
                        yield clk.posedge

                    self.mem.seek(addr % self.size)

                    data = bytearray(self.mem.read(bw))
                    val = 0
                    for i in range(bw-1,-1,-1):
                        val <<= 8
                        val += data[i]
                    s_axil_rdata.next = val
                    s_axil_rresp.next = 0b00
                    s_axil_rvalid.next = True
                    if name is not None:
                        print("[%s] Read word addr: 0x%08x prot: 0x%x data: %s" % (name, addr, prot, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                    yield clk.posedge

                    while not s_axil_rready:
                        yield clk.posedge

                    s_axil_rvalid.next = False

        return instances()

