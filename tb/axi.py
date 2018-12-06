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
import math
import mmap

BURST_FIXED = 0b00
BURST_INCR = 0b01
BURST_WRAP = 0b10

BURST_SIZE_1 = 0b000
BURST_SIZE_2 = 0b001
BURST_SIZE_4 = 0b010
BURST_SIZE_8 = 0b011
BURST_SIZE_16 = 0b100
BURST_SIZE_32 = 0b101
BURST_SIZE_64 = 0b110
BURST_SIZE_128 = 0b111

LOCK_NORMAL = 0b0
LOCK_EXCLUSIVE = 0b1

CACHE_B = 0b0001
CACHE_M = 0b0010
CACHE_RA = 0b0100
CACHE_WA = 0b1000

ARCACHE_DEVICE_NON_BUFFERABLE = 0b0000
ARCACHE_DEVICE_BUFFERABLE = 0b0001
ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE = 0b0010
ARCACHE_NORMAL_NON_CACHEABLE_BUFFERABLE = 0b0011
ARCACHE_WRITE_THROUGH_NO_ALLOC = 0b1010
ARCACHE_WRITE_THROUGH_READ_ALLOC = 0b1110
ARCACHE_WRITE_THROUGH_WRITE_ALLOC = 0b1010
ARCACHE_WRITE_THROUGH_READ_AND_WRITE_ALLOC = 0b1110
ARCACHE_WRITE_BACK_NO_ALLOC = 0b1011
ARCACHE_WRITE_BACK_READ_ALLOC = 0b1111
ARCACHE_WRITE_BACK_WRITE_ALLOC = 0b1011
ARCACHE_WRITE_BACK_READ_AND_WRIE_ALLOC = 0b1111

AWCACHE_DEVICE_NON_BUFFERABLE = 0b0000
AWCACHE_DEVICE_BUFFERABLE = 0b0001
AWCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE = 0b0010
AWCACHE_NORMAL_NON_CACHEABLE_BUFFERABLE = 0b0011
AWCACHE_WRITE_THROUGH_NO_ALLOC = 0b0110
AWCACHE_WRITE_THROUGH_READ_ALLOC = 0b0110
AWCACHE_WRITE_THROUGH_WRITE_ALLOC = 0b1110
AWCACHE_WRITE_THROUGH_READ_AND_WRITE_ALLOC = 0b1110
AWCACHE_WRITE_BACK_NO_ALLOC = 0b0111
AWCACHE_WRITE_BACK_READ_ALLOC = 0b0111
AWCACHE_WRITE_BACK_WRITE_ALLOC = 0b1111
AWCACHE_WRITE_BACK_READ_AND_WRIE_ALLOC = 0b1111

PROT_PRIVILEGED = 0b001
PROT_NONSECURE = 0b010
PROT_INSTRUCTION = 0b100

RESP_OKAY = 0b00
RESP_EXOKAY = 0b01
RESP_SLVERR = 0b10
RESP_DECERR = 0b11

class AXIMaster(object):
    def __init__(self):
        self.write_command_queue = []
        self.write_command_sync = Signal(False)
        self.write_resp_queue = []
        self.write_resp_sync = Signal(False)

        self.read_command_queue = []
        self.read_command_sync = Signal(False)
        self.read_data_queue = []
        self.read_data_sync = Signal(False)

        self.cur_write_id = 0
        self.cur_read_id = 0

        self.int_write_addr_queue = []
        self.int_write_addr_sync = Signal(False)
        self.int_write_data_queue = []
        self.int_write_data_sync = Signal(False)
        self.int_write_resp_command_queue = []
        self.int_write_resp_command_sync = Signal(False)
        self.int_write_resp_queue = []
        self.int_write_resp_sync = Signal(False)

        self.int_read_addr_queue = []
        self.int_read_addr_sync = Signal(False)
        self.int_read_resp_command_queue = []
        self.int_read_resp_command_sync = Signal(False)
        self.int_read_resp_queue_list = {}
        self.int_read_resp_sync = Signal(False)

        self.in_flight_operations = 0

        self.max_burst_len = 256

        self.has_logic = False
        self.clk = None

    def init_read(self, address, length, burst=0b01, size=None, lock=0b0, cache=0b0011, prot=0b010, qos=0b0000, region=0b0000, user=None):
        self.read_command_queue.append((address, length, burst, size, lock, cache, prot, qos, region, user))
        self.read_command_sync.next = not self.read_command_sync

    def init_write(self, address, data, burst=0b01, size=None, lock=0b0, cache=0b0011, prot=0b010, qos=0b0000, region=0b0000, user=None):
        self.write_command_queue.append((address, data, burst, size, lock, cache, prot, qos, region, user))
        self.write_command_sync.next = not self.write_command_sync

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
                m_axi_awid=None,
                m_axi_awaddr=None,
                m_axi_awlen=Signal(intbv(0)[8:]),
                m_axi_awsize=Signal(intbv(0)[3:]),
                m_axi_awburst=Signal(intbv(0)[2:]),
                m_axi_awlock=Signal(intbv(0)[1:]),
                m_axi_awcache=Signal(intbv(0)[4:]),
                m_axi_awprot=Signal(intbv(0)[3:]),
                m_axi_awqos=Signal(intbv(0)[4:]),
                m_axi_awregion=Signal(intbv(0)[4:]),
                m_axi_awuser=None,
                m_axi_awvalid=Signal(bool(False)),
                m_axi_awready=Signal(bool(True)),
                m_axi_wdata=None,
                m_axi_wstrb=Signal(intbv(1)[1:]),
                m_axi_wlast=Signal(bool(True)),
                m_axi_wuser=None,
                m_axi_wvalid=Signal(bool(False)),
                m_axi_wready=Signal(bool(True)),
                m_axi_bid=None,
                m_axi_bresp=Signal(intbv(0)[2:]),
                m_axi_buser=None,
                m_axi_bvalid=Signal(bool(False)),
                m_axi_bready=Signal(bool(False)),
                m_axi_arid=None,
                m_axi_araddr=None,
                m_axi_arlen=Signal(intbv(0)[8:]),
                m_axi_arsize=Signal(intbv(0)[3:]),
                m_axi_arburst=Signal(intbv(0)[2:]),
                m_axi_arlock=Signal(intbv(0)[1:]),
                m_axi_arcache=Signal(intbv(0)[4:]),
                m_axi_arprot=Signal(intbv(0)[3:]),
                m_axi_arqos=Signal(intbv(0)[4:]),
                m_axi_arregion=Signal(intbv(0)[4:]),
                m_axi_aruser=None,
                m_axi_arvalid=Signal(bool(False)),
                m_axi_arready=Signal(bool(True)),
                m_axi_rid=None,
                m_axi_rdata=None,
                m_axi_rresp=Signal(intbv(0)[2:]),
                m_axi_rlast=Signal(bool(True)),
                m_axi_ruser=None,
                m_axi_rvalid=Signal(bool(False)),
                m_axi_rready=Signal(bool(False)),
                pause=False,
                awpause=False,
                wpause=False,
                bpause=False,
                arpause=False,
                rpause=False,
                name=None
            ):

        if self.has_logic:
            raise Exception("Logic already instantiated!")

        if m_axi_wdata is not None:
            if m_axi_awid is not None:
                assert m_axi_bid is not None
                assert len(m_axi_awid) == len(m_axi_bid)
            assert m_axi_awaddr is not None
            assert len(m_axi_wdata) % 8 == 0
            assert len(m_axi_wdata) / 8 == len(m_axi_wstrb)
            w = len(m_axi_wdata)

        if m_axi_rdata is not None:
            if m_axi_arid is not None:
                assert m_axi_rid is not None
                assert len(m_axi_arid) == len(m_axi_rid)
            assert m_axi_araddr is not None
            assert len(m_axi_rdata) % 8 == 0
            w = len(m_axi_rdata)

            if m_axi_wdata is not None:
                assert len(m_axi_awaddr) == len(m_axi_araddr)
                assert len(m_axi_wdata) == len(m_axi_rdata)

        bw = int(w/8)

        assert bw in (1, 2, 4, 8, 16, 32, 64, 128)

        self.has_logic = True
        self.clk = clk

        m_axi_bvalid_int = Signal(bool(False))
        m_axi_bready_int = Signal(bool(False))
        m_axi_rvalid_int = Signal(bool(False))
        m_axi_rready_int = Signal(bool(False))

        @always_comb
        def pause_logic():
            m_axi_bvalid_int.next = m_axi_bvalid and not (pause or bpause)
            m_axi_bready.next = m_axi_bready_int and not (pause or bpause)
            m_axi_rvalid_int.next = m_axi_rvalid and not (pause or rpause)
            m_axi_rready.next = m_axi_rready_int and not (pause or rpause)

        @instance
        def write_logic():
            while True:
                if not self.write_command_queue:
                    yield self.write_command_sync

                if m_axi_awaddr is None:
                    print("Error: attempted write on read-only interface")
                    raise StopSimulation

                addr, data, burst, size, lock, cache, prot, qos, region, user = self.write_command_queue.pop(0)
                self.in_flight_operations += 1

                num_bytes = bw

                if size is None:
                    size = int(math.log(bw, 2))
                else:
                    num_bytes = 2**size
                    assert 0 < num_bytes <= bw

                aligned_addr = int(addr/num_bytes)*num_bytes
                word_addr = int(addr/bw)*bw

                start_offset = addr % bw
                end_offset = ((addr + len(data) - 1) % bw) + 1

                cycles = int((len(data) + num_bytes-1 + (addr % num_bytes)) / num_bytes)

                cur_addr = aligned_addr
                offset = 0
                cycle_offset = aligned_addr-word_addr
                n = 0
                transfer_count = 0

                burst_length = 0

                if name is not None:
                    print("[%s] Write data addr: 0x%08x prot: 0x%x data: %s" % (name, addr, prot, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                for k in range(cycles):
                    start = cycle_offset
                    stop = cycle_offset+num_bytes

                    if k == 0:
                        start = start_offset
                    if k == cycles-1:
                        stop = end_offset

                    strb = ((2**bw-1) << start) & (2**bw-1) & (2**bw-1) >> (bw - stop)

                    val = 0
                    for j in range(start, stop):
                        val |= bytearray(data)[offset] << j*8
                        offset += 1

                    if n >= burst_length:
                        transfer_count += 1
                        n = 0
                        burst_length = min(cycles-k, min(max(self.max_burst_len, 1), 256)) # max len
                        burst_length = int((min(burst_length*num_bytes, 0x1000-(cur_addr&0xfff))+num_bytes-1)/num_bytes) # 4k align
                        awid = self.cur_write_id
                        if m_axi_awid is not None:
                            self.cur_write_id = (self.cur_write_id + 1) % 2**len(m_axi_awid)
                        else:
                            self.cur_write_id = 0
                        self.int_write_addr_queue.append((cur_addr, awid, burst_length-1, size, burst, lock, cache, prot, qos, region, user))
                        self.int_write_addr_sync.next = not self.int_write_addr_sync
                        if name is not None:
                            print("[%s] Write burst awid: 0x%x awaddr: 0x%08x awlen: %d awsize: %d" % (name, awid, cur_addr, burst_length-1, size))
                    n += 1
                    self.int_write_data_queue.append((val, strb, n >= burst_length))
                    self.int_write_data_sync.next = not self.int_write_data_sync

                    cur_addr += num_bytes
                    cycle_offset = (cycle_offset + num_bytes) % bw

                self.int_write_resp_command_queue.append((addr, len(data), transfer_count, prot))
                self.int_write_resp_command_sync.next = not self.int_write_resp_command_sync

        @instance
        def write_resp_logic():
            while True:
                if not self.int_write_resp_command_queue:
                    yield self.int_write_resp_command_sync

                addr, length, transfer_count, prot = self.int_write_resp_command_queue.pop(0)

                resp = 0

                for k in range(transfer_count):
                    while not self.int_write_resp_queue:
                        yield clk.posedge

                    cycle_id, cycle_resp, cycle_user = self.int_write_resp_queue.pop(0)

                    if cycle_resp != 0:
                        resp = cycle_resp

                self.write_resp_queue.append((addr, length, prot, resp))
                self.write_resp_sync.next = not self.write_resp_sync
                self.in_flight_operations -= 1

        @instance
        def write_addr_interface_logic():
            while True:
                while not self.int_write_addr_queue:
                    yield clk.posedge

                addr, awid, length, size, burst, lock, cache, prot, qos, region, user = self.int_write_addr_queue.pop(0)
                if m_axi_awaddr is not None:
                    m_axi_awaddr.next = addr
                m_axi_awid.next = awid
                m_axi_awlen.next = length
                m_axi_awsize.next = size
                m_axi_awburst.next = burst
                m_axi_awlock.next = lock
                m_axi_awcache.next = cache
                m_axi_awprot.next = prot
                m_axi_awqos.next = qos
                m_axi_awregion.next = region
                if m_axi_awuser is not None:
                    m_axi_awuser.next = user
                m_axi_awvalid.next = not (pause or awpause)

                yield clk.posedge

                while not m_axi_awvalid or not m_axi_awready:
                    m_axi_awvalid.next = m_axi_awvalid or not (pause or awpause)
                    yield clk.posedge

                m_axi_awvalid.next = False

        @instance
        def write_data_interface_logic():
            while True:
                while not self.int_write_data_queue:
                    yield clk.posedge

                m_axi_wdata.next, m_axi_wstrb.next, m_axi_wlast.next = self.int_write_data_queue.pop(0)
                m_axi_wvalid.next = not (pause or wpause)

                yield clk.posedge

                while not m_axi_wvalid or not m_axi_wready:
                    m_axi_wvalid.next = m_axi_wvalid or not (pause or wpause)
                    yield clk.posedge

                m_axi_wvalid.next = False

        @instance
        def write_resp_interface_logic():
            while True:
                m_axi_bready_int.next = True

                yield clk.posedge

                if m_axi_bready and m_axi_bvalid_int:
                    if m_axi_bid is not None:
                        bid = int(m_axi_bid)
                    else:
                        bid = 0
                    bresp = int(m_axi_bresp)
                    if m_axi_buser is not None:
                        buser = int(m_axi_buser)
                    else:
                        buser = 0
                    self.int_write_resp_queue.append((bid, bresp, buser))
                    self.int_write_resp_sync.next = not self.int_write_resp_sync

        @instance
        def read_logic():
            while True:
                if not self.read_command_queue:
                    yield self.read_command_sync

                if m_axi_araddr is None:
                    print("Error: attempted read on write-only interface")
                    raise StopSimulation

                addr, length, burst, size, lock, cache, prot, qos, region, user = self.read_command_queue.pop(0)
                self.in_flight_operations += 1

                num_bytes = bw

                if size is None:
                    size = int(math.log(bw, 2))
                else:
                    num_bytes = 2**size
                    assert 0 < num_bytes <= bw

                aligned_addr = int(addr/num_bytes)*num_bytes
                word_addr = int(addr/bw)*bw

                cycles = int((length + num_bytes-1 + (addr % num_bytes)) / num_bytes)

                burst_list = []

                self.int_read_resp_command_queue.append((addr, length, size, cycles, prot, burst_list))
                self.int_read_resp_command_sync.next = not self.int_read_resp_command_sync

                cur_addr = aligned_addr
                n = 0

                burst_length = 0

                for k in range(cycles):

                    n += 1
                    if n >= burst_length:
                        n = 0
                        burst_length = min(cycles-k, min(max(self.max_burst_len, 1), 256)) # max len
                        burst_length = int((min(burst_length*num_bytes, 0x1000-(cur_addr&0xfff))+num_bytes-1)/num_bytes) # 4k align
                        arid = self.cur_read_id
                        if m_axi_arid is not None:
                            self.cur_read_id = (self.cur_read_id + 1) % 2**len(m_axi_arid)
                        else:
                            self.cur_read_id = 0
                        burst_list.append((arid, burst_length))
                        self.int_read_addr_queue.append((cur_addr, arid, burst_length-1, size, burst, lock, cache, prot, qos, region, user))
                        self.int_read_addr_sync.next = not self.int_read_addr_sync
                        if name is not None:
                            print("[%s] Read burst arid: 0x%x araddr: 0x%08x arlen: %d arsize: %d" % (name, arid, cur_addr, burst_length-1, size))

                    cur_addr += num_bytes

                burst_list.append(None)

        @instance
        def read_resp_logic():
            while True:
                if not self.int_read_resp_command_queue:
                    yield self.int_read_resp_command_sync

                addr, length, size, cycles, prot, burst_list = self.int_read_resp_command_queue.pop(0)

                num_bytes = 2**size
                assert 0 <= size <= int(math.log(bw, 2))

                aligned_addr = int(addr/num_bytes)*num_bytes
                word_addr = int(addr/bw)*bw

                start_offset = addr % bw
                end_offset = ((addr + length - 1) % bw) + 1

                cycle_offset = aligned_addr-word_addr
                data = b''

                resp = 0

                first = True

                while True:
                    while not burst_list:
                        yield clk.posedge

                    cur_burst = burst_list.pop(0)

                    if cur_burst is None:
                        break

                    rid = cur_burst[0]
                    burst_length = cur_burst[1]

                    for k in range(burst_length):
                        self.int_read_resp_queue_list.setdefault(rid, [])
                        while not self.int_read_resp_queue_list[rid]:
                            yield self.int_read_resp_sync

                        cycle_id, cycle_data, cycle_resp, cycle_last, cycle_user = self.int_read_resp_queue_list[rid].pop(0)

                        if cycle_resp != 0:
                            resp = cycle_resp

                        start = cycle_offset
                        stop = cycle_offset+num_bytes

                        if first:
                            start = start_offset

                        assert cycle_last == (k == burst_length - 1)

                        for j in range(start, stop):
                            data += bytearray([(cycle_data >> j*8) & 0xff])

                        cycle_offset = (cycle_offset + num_bytes) % bw

                        first = False

                data = data[:length]

                if name is not None:
                    print("[%s] Read data addr: 0x%08x prot: 0x%x data: %s" % (name, addr, prot, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                self.read_data_queue.append((addr, data, prot, resp))
                self.read_data_sync.next = not self.read_data_sync
                self.in_flight_operations -= 1

        @instance
        def read_addr_interface_logic():
            while True:
                while not self.int_read_addr_queue:
                    yield clk.posedge

                addr, arid, length, size, burst, lock, cache, prot, qos, region, user = self.int_read_addr_queue.pop(0)
                m_axi_araddr.next = addr
                if m_axi_arid is not None:
                    m_axi_arid.next = arid
                m_axi_arlen.next = length
                m_axi_arsize.next = size
                m_axi_arburst.next = burst
                m_axi_arlock.next = lock
                m_axi_arcache.next = cache
                m_axi_arprot.next = prot
                m_axi_arqos.next = qos
                m_axi_arregion.next = region
                if m_axi_aruser is not None:
                    m_axi_aruser.next = user
                m_axi_arvalid.next = not (pause or arpause)

                yield clk.posedge

                while not m_axi_arvalid or not m_axi_arready:
                    m_axi_arvalid.next = m_axi_arvalid or not (pause or arpause)
                    yield clk.posedge

                m_axi_arvalid.next = False

        @instance
        def read_resp_interface_logic():
            while True:
                m_axi_rready_int.next = True

                yield clk.posedge

                if m_axi_rready and m_axi_rvalid_int:
                    if m_axi_rid is not None:
                        rid = int(m_axi_rid)
                    else:
                        rid = 0
                    rdata = int(m_axi_rdata)
                    rresp = int(m_axi_rresp)
                    rlast = int(m_axi_rlast)
                    if m_axi_buser is not None:
                        ruser = int(m_axi_ruser)
                    else:
                        ruser = 0
                    self.int_read_resp_queue_list.setdefault(rid, [])
                    self.int_read_resp_queue_list[rid].append((rid, rdata, rresp, rlast, ruser))
                    self.int_read_resp_sync.next = not self.int_read_resp_sync

        return instances()


class AXIRam(object):
    def __init__(self, size = 1024):
        self.size = size
        self.mem = mmap.mmap(-1, size)

        self.int_write_addr_queue = []
        self.int_write_addr_sync = Signal(False)
        self.int_write_data_queue = []
        self.int_write_data_sync = Signal(False)
        self.int_write_resp_queue = []
        self.int_write_resp_sync = Signal(False)

        self.int_read_addr_queue = []
        self.int_read_addr_sync = Signal(False)
        self.int_read_resp_queue = []
        self.int_read_resp_sync = Signal(False)

    def read_mem(self, address, length):
        self.mem.seek(address % self.size)
        return self.mem.read(length)

    def write_mem(self, address, data):
        self.mem.seek(address % self.size)
        self.mem.write(bytes(data))

    def create_port(self,
                clk,
                s_axi_awid=None,
                s_axi_awaddr=None,
                s_axi_awlen=Signal(intbv(0)[8:]),
                s_axi_awsize=Signal(intbv(0)[3:]),
                s_axi_awburst=Signal(intbv(0)[2:]),
                s_axi_awlock=Signal(intbv(0)[1:]),
                s_axi_awcache=Signal(intbv(0)[4:]),
                s_axi_awprot=Signal(intbv(0)[3:]),
                s_axi_awvalid=Signal(bool(False)),
                s_axi_awready=Signal(bool(True)),
                s_axi_wdata=None,
                s_axi_wstrb=Signal(intbv(1)[1:]),
                s_axi_wlast=Signal(bool(True)),
                s_axi_wvalid=Signal(bool(False)),
                s_axi_wready=Signal(bool(True)),
                s_axi_bid=None,
                s_axi_bresp=Signal(intbv(0)[2:]),
                s_axi_bvalid=Signal(bool(False)),
                s_axi_bready=Signal(bool(False)),
                s_axi_arid=None,
                s_axi_araddr=None,
                s_axi_arlen=Signal(intbv(0)[8:]),
                s_axi_arsize=Signal(intbv(0)[3:]),
                s_axi_arburst=Signal(intbv(0)[2:]),
                s_axi_arlock=Signal(intbv(0)[1:]),
                s_axi_arcache=Signal(intbv(0)[4:]),
                s_axi_arprot=Signal(intbv(0)[3:]),
                s_axi_arvalid=Signal(bool(False)),
                s_axi_arready=Signal(bool(True)),
                s_axi_rid=None,
                s_axi_rdata=None,
                s_axi_rresp=Signal(intbv(0)[2:]),
                s_axi_rlast=Signal(bool(True)),
                s_axi_rvalid=Signal(bool(False)),
                s_axi_rready=Signal(bool(False)),
                pause=False,
                awpause=False,
                wpause=False,
                bpause=False,
                arpause=False,
                rpause=False,
                name=None
            ):

        if s_axi_wdata is not None:
            if s_axi_awid is not None:
                assert s_axi_bid is not None
                assert len(s_axi_awid) == len(s_axi_bid)
            assert s_axi_awaddr is not None
            assert len(s_axi_wdata) % 8 == 0
            assert len(s_axi_wdata) / 8 == len(s_axi_wstrb)
            w = len(s_axi_wdata)

        if s_axi_rdata is not None:
            if s_axi_arid is not None:
                assert s_axi_rid is not None
                assert len(s_axi_arid) == len(s_axi_rid)
            assert s_axi_araddr is not None
            assert len(s_axi_rdata) % 8 == 0
            w = len(s_axi_rdata)

            if s_axi_wdata is not None:
                assert len(s_axi_awaddr) == len(s_axi_araddr)
                assert len(s_axi_wdata) == len(s_axi_rdata)

        bw = int(w/8)

        assert bw in (1, 2, 4, 8, 16, 32, 64, 128)

        s_axi_awvalid_int = Signal(bool(False))
        s_axi_awready_int = Signal(bool(False))
        s_axi_wvalid_int = Signal(bool(False))
        s_axi_wready_int = Signal(bool(False))
        s_axi_arvalid_int = Signal(bool(False))
        s_axi_arready_int = Signal(bool(False))

        @always_comb
        def pause_logic():
            s_axi_awvalid_int.next = s_axi_awvalid and not (pause or awpause)
            s_axi_awready.next = s_axi_awready_int and not (pause or awpause)
            s_axi_wvalid_int.next = s_axi_wvalid and not (pause or wpause)
            s_axi_wready.next = s_axi_wready_int and not (pause or wpause)
            s_axi_arvalid_int.next = s_axi_arvalid and not (pause or arpause)
            s_axi_arready.next = s_axi_arready_int and not (pause or arpause)

        @instance
        def write_logic():
            while True:
                if not self.int_write_addr_queue:
                    yield self.int_write_addr_sync

                addr, awid, length, size, burst, lock, cache, prot = self.int_write_addr_queue.pop(0)

                if name is not None:
                    print("[%s] Write burst awid: 0x%x awaddr: 0x%08x awlen: %d awsize: %d" % (name, awid, addr, length, size))

                num_bytes = 2**size
                assert 0 < num_bytes <= bw

                aligned_addr = int(addr/num_bytes)*num_bytes
                length = length+1

                transfer_size = num_bytes*length

                if burst == BURST_WRAP:
                    lower_wrap_boundary = int(addr/transfer_size)*transfer_size
                    upper_wrap_boundary = lower_wrap_boundary+transfer_size

                if burst == BURST_INCR:
                    # check for 4k boundary crossing
                    assert 0x1000-(aligned_addr&0xfff) >= transfer_size

                cur_addr = aligned_addr

                for n in range(length):
                    cur_word_addr = int(cur_addr/bw)*bw

                    if not self.int_write_data_queue:
                        yield self.int_write_data_sync

                    wdata, strb, last = self.int_write_data_queue.pop(0)

                    self.mem.seek(cur_word_addr % self.size)

                    data = bytearray()
                    for i in range(bw):
                        data.extend(bytearray([wdata & 0xff]))
                        wdata >>= 8
                    for i in range(bw):
                        if strb & (1 << i):
                            self.mem.write(bytes(data[i:i+1]))
                        else:
                            self.mem.seek(1, 1)
                    if n == length-1:
                        self.int_write_resp_queue.append((awid, 0b00))
                        self.int_write_resp_sync.next = not self.int_write_resp_sync
                    if last != (n == length-1):
                        print("Error: bad last assert")
                        raise StopSimulation
                    assert last == (n == length-1)
                    if name is not None:
                        print("[%s] Write word id: %d addr: 0x%08x prot: 0x%x wstrb: 0x%02x data: %s" % (name, awid, cur_addr, prot, s_axi_wstrb, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                    if burst != BURST_FIXED:
                        cur_addr += num_bytes

                        if burst == BURST_WRAP:
                            if cur_addr == upper_wrap_boundary:
                                cur_addr = lower_wrap_boundary

        @instance
        def write_addr_interface_logic():
            while True:
                s_axi_awready_int.next = True

                yield clk.posedge

                if s_axi_awready and s_axi_awvalid_int:
                    addr = int(s_axi_awaddr)
                    if s_axi_awid is not None:
                        awid = int(s_axi_awid)
                    else:
                        awid = 0
                    length = int(s_axi_awlen)
                    size = int(s_axi_awsize)
                    burst = int(s_axi_awburst)
                    lock = int(s_axi_awlock)
                    cache = int(s_axi_awcache)
                    prot = int(s_axi_awprot)
                    self.int_write_addr_queue.append((addr, awid, length, size, burst, lock, cache, prot))
                    self.int_write_addr_sync.next = not self.int_write_addr_sync

        @instance
        def write_data_interface_logic():
            while True:
                s_axi_wready_int.next = True

                yield clk.posedge

                if s_axi_wready and s_axi_wvalid_int:
                    data = int(s_axi_wdata)
                    strb = int(s_axi_wstrb)
                    last = bool(s_axi_wlast)
                    self.int_write_data_queue.append((data, strb, last))
                    self.int_write_data_sync.next = not self.int_write_data_sync

        @instance
        def write_resp_interface_logic():
            while True:
                while not self.int_write_resp_queue:
                    yield clk.posedge

                bid, bresp = self.int_write_resp_queue.pop(0)
                if s_axi_bid is not None:
                    s_axi_bid.next = bid
                s_axi_bresp.next = bresp
                s_axi_bvalid.next = not (pause or bpause)

                yield clk.posedge

                while not s_axi_bvalid or not s_axi_bready:
                    s_axi_bvalid.next = s_axi_bvalid or not (pause or bpause)
                    yield clk.posedge

                s_axi_bvalid.next = False

        @instance
        def read_logic():
            while True:
                if not self.int_read_addr_queue:
                    yield self.int_read_addr_sync

                addr, arid, length, size, burst, lock, cache, prot = self.int_read_addr_queue.pop(0)

                if name is not None:
                    print("[%s] Read burst arid: 0x%x araddr: 0x%08x arlen: %d arsize: %d" % (name, arid, addr, length, size))

                num_bytes = 2**size
                assert 0 < num_bytes <= bw

                aligned_addr = int(addr/num_bytes)*num_bytes
                length = length+1

                transfer_size = num_bytes*length

                if burst == BURST_WRAP:
                    lower_wrap_boundary = int(addr/transfer_size)*transfer_size
                    upper_wrap_boundary = lower_wrap_boundary+transfer_size

                if burst == BURST_INCR:
                    # check for 4k boundary crossing
                    assert 0x1000-(aligned_addr&0xfff) >= transfer_size

                cur_addr = aligned_addr

                for n in range(length):
                    cur_word_addr = int(cur_addr/bw)*bw

                    self.mem.seek(cur_word_addr % self.size)

                    data = bytearray(self.mem.read(bw))
                    val = 0
                    for i in range(bw-1,-1,-1):
                        val <<= 8
                        val += data[i]
                    self.int_read_resp_queue.append((arid, val, 0x00, n == length-1))
                    self.int_read_resp_sync.next = not self.int_read_resp_sync
                    if name is not None:
                        print("[%s] Read word id: %d addr: 0x%08x prot: 0x%x data: %s" % (name, arid, cur_addr, prot, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                    if burst != BURST_FIXED:
                        cur_addr += num_bytes

                        if burst == BURST_WRAP:
                            if cur_addr == upper_wrap_boundary:
                                cur_addr = lower_wrap_boundary

        @instance
        def read_addr_interface_logic():
            while True:
                s_axi_arready_int.next = True

                yield clk.posedge

                if s_axi_arready and s_axi_arvalid_int:
                    addr = int(s_axi_araddr)
                    if s_axi_arid is not None:
                        arid = int(s_axi_arid)
                    else:
                        arid = 0
                    length = int(s_axi_arlen)
                    size = int(s_axi_arsize)
                    burst = int(s_axi_arburst)
                    lock = int(s_axi_arlock)
                    cache = int(s_axi_arcache)
                    prot = int(s_axi_arprot)
                    self.int_read_addr_queue.append((addr, arid, length, size, burst, lock, cache, prot))
                    self.int_read_addr_sync.next = not self.int_read_addr_sync

        @instance
        def read_resp_interface_logic():
            while True:
                while not self.int_read_resp_queue:
                    yield clk.posedge

                rid, rdata, rresp, rlast = self.int_read_resp_queue.pop(0)
                if s_axi_rid is not None:
                    s_axi_rid.next = rid
                s_axi_rdata.next = rdata
                s_axi_rresp.next = rresp
                s_axi_rlast.next = rlast
                s_axi_rvalid.next = not (pause or rpause)

                yield clk.posedge

                while not s_axi_rvalid or not s_axi_rready:
                    s_axi_rvalid.next = s_axi_rvalid or not (pause or rpause)
                    yield clk.posedge

                s_axi_rvalid.next = False

        return instances()

