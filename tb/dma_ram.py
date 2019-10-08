"""

Copyright (c) 2019 Alex Forencich

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

class PSDPRam(object):
    def __init__(self, size = 1024):
        self.size = size
        self.mem = mmap.mmap(-1, size)

    def read_mem(self, address, length):
        self.mem.seek(address)
        return self.mem.read(length)

    def write_mem(self, address, data):
        self.mem.seek(address)
        self.mem.write(bytes(data))

    def create_write_ports(self,
                clk,
                ram_wr_cmd_be=Signal(intbv(1)[1:]),
                ram_wr_cmd_addr=None,
                ram_wr_cmd_data=None,
                ram_wr_cmd_valid=Signal(bool(False)),
                ram_wr_cmd_ready=Signal(bool(True)),
                pause=False,
                latency=1,
                name=None
            ):

        cnt = len(ram_wr_cmd_valid)

        assert len(ram_wr_cmd_ready) == cnt

        be_len = int(len(ram_wr_cmd_be) / cnt)
        addr_len = int(len(ram_wr_cmd_addr) / cnt)
        data_len = int(len(ram_wr_cmd_data) / cnt)

        ram_wr_cmd_be_list = [ram_wr_cmd_be((i+1)*be_len, i*be_len) for i in range(cnt)]
        ram_wr_cmd_addr_list = [ram_wr_cmd_addr((i+1)*addr_len, i*addr_len) for i in range(cnt)]
        ram_wr_cmd_data_list = [ram_wr_cmd_data((i+1)*data_len, i*data_len) for i in range(cnt)]
        ram_wr_cmd_valid_list = [ram_wr_cmd_valid(i) for i in range(cnt)]

        ram_wr_cmd_ready_list = [Signal(bool(0)) for i in range(cnt)]

        port_logic_list = []

        for k in range(cnt):
            port_logic_list.append(self.create_write_port(
                    clk=clk,
                    ram_wr_cmd_be=ram_wr_cmd_be_list[k],
                    ram_wr_cmd_addr=ram_wr_cmd_addr_list[k],
                    ram_wr_cmd_data=ram_wr_cmd_data_list[k],
                    ram_wr_cmd_valid=ram_wr_cmd_valid_list[k],
                    ram_wr_cmd_ready=ram_wr_cmd_ready_list[k],
                    pause=pause,
                    offset=k,
                    stride=cnt,
                    name=name
                ))

        @always_comb
        def ready_logic():
            ram_wr_cmd_ready.next = concat(*reversed(ram_wr_cmd_ready_list))

        return instances()

    def create_write_port(self,
                clk,
                ram_wr_cmd_be=Signal(intbv(1)[1:]),
                ram_wr_cmd_addr=None,
                ram_wr_cmd_data=None,
                ram_wr_cmd_valid=Signal(bool(False)),
                ram_wr_cmd_ready=Signal(bool(True)),
                pause=False,
                offset=0,
                stride=1,
                name=None
            ):

        assert ram_wr_cmd_addr is not None
        assert ram_wr_cmd_data is not None
        assert len(ram_wr_cmd_data) % 8 == 0
        assert len(ram_wr_cmd_data) / 8 == len(ram_wr_cmd_be)

        w = len(ram_wr_cmd_data)

        bw = int(w/8)

        @instance
        def write_logic():
            while True:
                ram_wr_cmd_ready.next = not pause

                yield clk.posedge

                addr = (ram_wr_cmd_addr*stride+offset)*bw

                if ram_wr_cmd_ready and ram_wr_cmd_valid:
                    self.mem.seek(addr % self.size)

                    data = bytearray()
                    val = int(ram_wr_cmd_data)

                    for i in range(bw):
                        data.extend(bytearray([val & 0xff]))
                        val >>= 8
                    for i in range(bw):
                        if ram_wr_cmd_be & (1 << i):
                            self.mem.write(bytes(data[i:i+1]))
                        else:
                            self.mem.seek(1, 1)
                    if name is not None:
                        print("[%s] Write word addr: 0x%08x be: 0x%02x data: %s" % (name, addr, ram_wr_cmd_be, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

        return instances()

    def create_read_ports(self,
                clk,
                ram_rd_cmd_addr=None,
                ram_rd_cmd_valid=Signal(bool(False)),
                ram_rd_cmd_ready=Signal(bool(True)),
                ram_rd_resp_data=None,
                ram_rd_resp_valid=Signal(bool(False)),
                ram_rd_resp_ready=Signal(bool(False)),
                pause=False,
                latency=1,
                name=None
            ):

        cnt = len(ram_rd_cmd_valid)

        assert len(ram_rd_cmd_ready) == cnt
        assert len(ram_rd_resp_valid) == cnt
        assert len(ram_rd_resp_ready) == cnt

        addr_len = int(len(ram_rd_cmd_addr) / cnt)
        data_len = int(len(ram_rd_resp_data) / cnt)

        ram_rd_cmd_addr_list = [ram_rd_cmd_addr((i+1)*addr_len, i*addr_len) for i in range(cnt)]
        ram_rd_cmd_valid_list = [ram_rd_cmd_valid(i) for i in range(cnt)]
        ram_rd_resp_ready_list = [ram_rd_resp_ready(i) for i in range(cnt)]

        ram_rd_cmd_ready_list = [Signal(bool(0)) for i in range(cnt)]
        ram_rd_resp_data_list = [Signal(intbv(0)[data_len:]) for i in range(cnt)]
        ram_rd_resp_valid_list = [Signal(bool(0)) for i in range(cnt)]

        port_logic_list = []

        for k in range(cnt):
            port_logic_list.append(self.create_read_port(
                    clk=clk,
                    ram_rd_cmd_addr=ram_rd_cmd_addr_list[k],
                    ram_rd_cmd_valid=ram_rd_cmd_valid_list[k],
                    ram_rd_cmd_ready=ram_rd_cmd_ready_list[k],
                    ram_rd_resp_data=ram_rd_resp_data_list[k],
                    ram_rd_resp_valid=ram_rd_resp_valid_list[k],
                    ram_rd_resp_ready=ram_rd_resp_ready_list[k],
                    pause=pause,
                    latency=latency,
                    offset=k,
                    stride=cnt,
                    name=name
                ))

        @always_comb
        def resp_logic():
            ram_rd_cmd_ready.next = concat(*reversed(ram_rd_cmd_ready_list))
            ram_rd_resp_data.next = concat(*reversed(ram_rd_resp_data_list))
            ram_rd_resp_valid.next = concat(*reversed(ram_rd_resp_valid_list))

        return instances()

    def create_read_port(self,
                clk,
                ram_rd_cmd_addr=None,
                ram_rd_cmd_valid=Signal(bool(False)),
                ram_rd_cmd_ready=Signal(bool(True)),
                ram_rd_resp_data=None,
                ram_rd_resp_valid=Signal(bool(False)),
                ram_rd_resp_ready=Signal(bool(False)),
                pause=False,
                latency=1,
                offset=0,
                stride=1,
                name=None
            ):

        assert ram_rd_cmd_addr is not None
        assert ram_rd_resp_data is not None
        assert len(ram_rd_resp_data) % 8 == 0

        w = len(ram_rd_resp_data)

        bw = int(w/8)

        pipeline = [None]*latency

        ready_int = Signal(bool(False))

        @always_comb
        def ready_logic():
            ram_rd_cmd_ready.next = (ram_rd_resp_ready or ready_int) and not pause

        @instance
        def read_logic():
            out_valid = False
            
            while True:
                ready_int.next = not out_valid or None in pipeline

                yield clk.posedge

                if ram_rd_resp_ready or not ram_rd_resp_valid:
                    if pipeline[-1] is not None:
                        ram_rd_resp_data.next = pipeline[-1]
                        ram_rd_resp_valid.next = True
                        out_valid = True
                        pipeline[-1] = None
                    else:
                        ram_rd_resp_valid.next = False
                        out_valid = False

                for i in range(latency-1,0,-1):
                    if pipeline[i] is None:
                        pipeline[i] = pipeline[i-1]
                        pipeline[i-1] = None

                addr = (ram_rd_cmd_addr*stride+offset)*bw

                if ram_rd_cmd_ready and ram_rd_cmd_valid:
                    self.mem.seek(addr % self.size)

                    data = bytearray(self.mem.read(bw))
                    val = 0
                    for i in range(bw-1,-1,-1):
                        val <<= 8
                        val += data[i]
                    pipeline[0] = val
                    if name is not None:
                        print("[%s] Read word addr: 0x%08x data: %s" % (name, addr, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

        return instances()
