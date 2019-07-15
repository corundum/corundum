#!/usr/bin/env python
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
import struct
import os

import pcie

class TestEP(pcie.MemoryEndpoint, pcie.MSICapability):
    def __init__(self, *args, **kwargs):
        super(TestEP, self).__init__(*args, **kwargs)

        self.vendor_id = 0x1234
        self.device_id = 0x5678

        self.msi_multiple_message_capable = 5
        self.msi_64bit_address_capable = 1
        self.msi_per_vector_mask_capable = 1

        self.add_mem_region(1024)
        self.add_prefetchable_mem_region(1024*1024)
        self.add_io_region(32)

def bench():

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    # Outputs

    # PCIe devices
    rc = pcie.RootComplex()

    ep = TestEP()
    dev = pcie.Device(ep)

    rc.make_port().connect(dev)

    sw = pcie.Switch()

    rc.make_port().connect(sw)

    ep2 = TestEP()
    dev2 = pcie.Device(ep2)

    sw.make_port().connect(dev2)

    ep3 = TestEP()
    dev3 = pcie.Device(ep3)

    sw.make_port().connect(dev3)

    ep4 = TestEP()
    dev4 = pcie.Device(ep4)

    rc.make_port().connect(dev4)

    @always(delay(2))
    def clkgen():
        clk.next = not clk

    @instance
    def check():
        yield delay(100)
        yield clk.posedge
        rst.next = 1
        yield clk.posedge
        rst.next = 0
        yield clk.posedge
        yield delay(100)
        yield clk.posedge

        yield clk.posedge
        print("test 1: enumeration")
        current_test.next = 1

        yield from rc.enumerate(enable_bus_mastering=True, configure_msi=True)

        # val = yield from rc.config_read((0, 1, 0), 0x000, 4)

        # print(val)

        # val = yield from rc.config_read((1, 0, 0), 0x000, 4)

        # print(val)

        # yield from rc.config_write((1, 0, 0), 0x010, b'\xff'*4*6)

        # val = yield from rc.config_read((1, 0, 0), 0x010, 4*6)

        # print(val)

        for k in range(6):
            print("0x%08x / 0x%08x" %(ep.bar[k], ep.bar_mask[k]))

        print(sw.upstream_bridge.pri_bus_num)
        print(sw.upstream_bridge.sec_bus_num)
        print(sw.upstream_bridge.sub_bus_num)
        print("0x%08x" % sw.upstream_bridge.io_base)
        print("0x%08x" % sw.upstream_bridge.io_limit)
        print("0x%08x" % sw.upstream_bridge.mem_base)
        print("0x%08x" % sw.upstream_bridge.mem_limit)
        print("0x%016x" % sw.upstream_bridge.prefetchable_mem_base)
        print("0x%016x" % sw.upstream_bridge.prefetchable_mem_limit)

        yield delay(100)

        yield clk.posedge
        print("test 2: IO and memory read/write")
        current_test.next = 2

        yield from rc.io_write(0x80000000, bytearray(range(16)), 1000)
        assert ep.read_region(3, 0, 16) == bytearray(range(16))

        val = yield from rc.io_read(0x80000000, 16, 1000)
        assert val == bytearray(range(16))

        yield from rc.mem_write(0x80000000, bytearray(range(16)), 1000)
        yield delay(1000)
        assert ep.read_region(0, 0, 16) == bytearray(range(16))

        val = yield from rc.mem_read(0x80000000, 16, 1000)
        assert val == bytearray(range(16))

        yield from rc.mem_write(0x8000000000000000, bytearray(range(16)), 1000)
        yield delay(1000)
        assert ep.read_region(1, 0, 16) == bytearray(range(16))

        val = yield from rc.mem_read(0x8000000000000000, 16, 1000)
        assert val == bytearray(range(16))

        yield delay(100)

        # yield clk.posedge
        # print("test 3: Large read/write")
        # current_test.next = 3

        # yield from rc.mem_write(0x8000000000000000, bytearray(range(256))*32, 100)
        # yield delay(1000)
        # assert ep.read_region(1, 0, 256*32) == bytearray(range(256))*32

        # val = yield from rc.mem_read(0x8000000000000000, 256*32, 100)
        # assert val == bytearray(range(256))*32

        # yield delay(100)

        yield clk.posedge
        print("test 4: Root complex memory")
        current_test.next = 4

        mem_base, mem_data = rc.alloc_region(1024*1024)
        io_base, io_data = rc.alloc_io_region(1024)

        yield from rc.io_write(io_base, bytearray(range(16)))
        assert io_data[0:16] == bytearray(range(16))

        val = yield from rc.io_read(io_base, 16)
        assert val == bytearray(range(16))

        yield from rc.mem_write(mem_base, bytearray(range(16)))
        assert mem_data[0:16] == bytearray(range(16))

        val = yield from rc.mem_read(mem_base, 16)
        assert val == bytearray(range(16))

        yield delay(100)

        yield clk.posedge
        print("test 5: device-to-device DMA")
        current_test.next = 5

        yield from ep.io_write(0x80001000, bytearray(range(16)), 10000)
        assert ep2.read_region(3, 0, 16) == bytearray(range(16))

        val = yield from ep.io_read(0x80001000, 16, 10000)
        assert val == bytearray(range(16))

        yield from ep.mem_write(0x80100000, bytearray(range(16)), 10000)
        yield delay(1000)
        assert ep2.read_region(0, 0, 16) == bytearray(range(16))

        val = yield from ep.mem_read(0x80100000, 16, 10000)
        assert val == bytearray(range(16))

        yield from ep.mem_write(0x8000000000100000, bytearray(range(16)), 10000)
        yield delay(1000)
        assert ep2.read_region(1, 0, 16) == bytearray(range(16))

        val = yield from ep.mem_read(0x8000000000100000, 16, 10000)
        assert val == bytearray(range(16))

        yield delay(100)

        yield clk.posedge
        print("test 6: device-to-root DMA")
        current_test.next = 6

        yield from ep.io_write(io_base, bytearray(range(16)), 1000)
        assert io_data[0:16] == bytearray(range(16))

        val = yield from ep.io_read(io_base, 16, 1000)
        assert val == bytearray(range(16))

        yield from ep.mem_write(mem_base, bytearray(range(16)), 1000)
        yield delay(1000)
        assert mem_data[0:16] == bytearray(range(16))

        val = yield from ep.mem_read(mem_base, 16, 1000)
        assert val == bytearray(range(16))

        yield delay(100)

        yield clk.posedge
        print("test 7: MSI")
        current_test.next = 7

        yield from ep.issue_msi_interrupt(4)

        yield rc.msi_get_signal(ep.get_id(), 4)

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()

