#!/usr/bin/env python
"""

Copyright (c) 2015 Alex Forencich

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
import os

import axil

def bench():

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    port0_axil_awaddr = Signal(intbv(0)[32:])
    port0_axil_awprot = Signal(intbv(0)[3:])
    port0_axil_awvalid = Signal(bool(False))
    port0_axil_wdata = Signal(intbv(0)[32:])
    port0_axil_wstrb = Signal(intbv(0)[4:])
    port0_axil_wvalid = Signal(bool(False))
    port0_axil_bready = Signal(bool(False))
    port0_axil_araddr = Signal(intbv(0)[32:])
    port0_axil_arprot = Signal(intbv(0)[3:])
    port0_axil_arvalid = Signal(bool(False))
    port0_axil_rready = Signal(bool(False))

    # Outputs
    port0_axil_awready = Signal(bool(False))
    port0_axil_wready = Signal(bool(False))
    port0_axil_bresp = Signal(intbv(0)[2:])
    port0_axil_bvalid = Signal(bool(False))
    port0_axil_arready = Signal(bool(False))
    port0_axil_rdata = Signal(intbv(0)[32:])
    port0_axil_rresp = Signal(intbv(0)[2:])
    port0_axil_rvalid = Signal(bool(False))

    # AXI4-Lite master
    axil_master_inst = axil.AXILiteMaster()
    axil_master_pause = Signal(bool(False))

    axil_master_logic = axil_master_inst.create_logic(
        clk,
        rst,
        m_axil_awaddr=port0_axil_awaddr,
        m_axil_awprot=port0_axil_awprot,
        m_axil_awvalid=port0_axil_awvalid,
        m_axil_awready=port0_axil_awready,
        m_axil_wdata=port0_axil_wdata,
        m_axil_wstrb=port0_axil_wstrb,
        m_axil_wvalid=port0_axil_wvalid,
        m_axil_wready=port0_axil_wready,
        m_axil_bresp=port0_axil_bresp,
        m_axil_bvalid=port0_axil_bvalid,
        m_axil_bready=port0_axil_bready,
        m_axil_araddr=port0_axil_araddr,
        m_axil_arprot=port0_axil_arprot,
        m_axil_arvalid=port0_axil_arvalid,
        m_axil_arready=port0_axil_arready,
        m_axil_rdata=port0_axil_rdata,
        m_axil_rresp=port0_axil_rresp,
        m_axil_rvalid=port0_axil_rvalid,
        m_axil_rready=port0_axil_rready,
        pause=axil_master_pause,
        name='master'
    )

    # AXI4-Lite RAM model
    axil_ram_inst = axil.AXILiteRam(2**16)
    axil_ram_pause = Signal(bool(False))

    axil_ram_port0 = axil_ram_inst.create_port(
        clk,
        s_axil_awaddr=port0_axil_awaddr,
        s_axil_awprot=port0_axil_awprot,
        s_axil_awvalid=port0_axil_awvalid,
        s_axil_awready=port0_axil_awready,
        s_axil_wdata=port0_axil_wdata,
        s_axil_wstrb=port0_axil_wstrb,
        s_axil_wvalid=port0_axil_wvalid,
        s_axil_wready=port0_axil_wready,
        s_axil_bresp=port0_axil_bresp,
        s_axil_bvalid=port0_axil_bvalid,
        s_axil_bready=port0_axil_bready,
        s_axil_araddr=port0_axil_araddr,
        s_axil_arprot=port0_axil_arprot,
        s_axil_arvalid=port0_axil_arvalid,
        s_axil_arready=port0_axil_arready,
        s_axil_rdata=port0_axil_rdata,
        s_axil_rresp=port0_axil_rresp,
        s_axil_rvalid=port0_axil_rvalid,
        s_axil_rready=port0_axil_rready,
        pause=axil_ram_pause,
        latency=1,
        name='port0'
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    def wait_normal():
        while not axil_master_inst.idle():
            yield clk.posedge

    def wait_pause_master():
        while not axil_master_inst.idle():
            axil_master_pause.next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            axil_master_pause.next = False
            yield clk.posedge

    def wait_pause_slave():
        while not axil_master_inst.idle():
            axil_ram_pause.next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            axil_ram_pause.next = False
            yield clk.posedge

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
        print("test 1: baseline")
        current_test.next = 1

        data = axil_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        yield delay(100)

        yield clk.posedge
        print("test 2: direct write")
        current_test.next = 2

        axil_ram_inst.write_mem(0, b'test')

        data = axil_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axil_ram_inst.read_mem(0, 4) == b'test'

        yield delay(100)

        yield clk.posedge
        print("test 3: write via port0")
        current_test.next = 3

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axil_master_inst.init_write(addr, test_data)

        yield axil_master_inst.wait()
        yield clk.posedge

        data = axil_ram_inst.read_mem(addr&0xffffff80, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axil_ram_inst.read_mem(addr, len(test_data)) == test_data

        yield delay(100)

        yield clk.posedge
        print("test 4: read via port0")
        current_test.next = 4

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axil_ram_inst.write_mem(addr, test_data)

        axil_master_inst.init_read(addr, len(test_data))

        yield axil_master_inst.wait()
        yield clk.posedge

        data = axil_master_inst.get_read_data()
        assert data[0] == addr
        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 5: various writes")
        current_test.next = 5

        for length in range(1,8):
            for offset in range(4,8):
                for wait in wait_normal, wait_pause_master, wait_pause_slave:
                    print("length %d, offset %d"% (length, offset))
                    addr = 256*(16*offset+length)+offset
                    test_data = b'\x11\x22\x33\x44\x55\x66\x77\x88'[0:length]

                    axil_ram_inst.write_mem(256*(16*offset+length), b'\xAA'*32)
                    axil_master_inst.init_write(addr, test_data)

                    yield wait()
                    yield clk.posedge

                    data = axil_ram_inst.read_mem(256*(16*offset+length), 32)
                    for i in range(0, len(data), 16):
                        print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                    assert axil_ram_inst.read_mem(addr, length) == test_data
                    assert axil_ram_inst.read_mem(addr-1, 1) == b'\xAA'
                    assert axil_ram_inst.read_mem(addr+length, 1) == b'\xAA'

        yield delay(100)

        yield clk.posedge
        print("test 6: various reads")
        current_test.next = 6

        for length in range(1,8):
            for offset in range(4,8):
                for wait in wait_normal, wait_pause_master, wait_pause_slave:
                    print("length %d, offset %d"% (length, offset))
                    addr = 256*(16*offset+length)+offset
                    test_data = b'\x11\x22\x33\x44\x55\x66\x77\x88'[0:length]

                    axil_master_inst.init_read(addr, length)

                    yield wait()
                    yield clk.posedge

                    data = axil_master_inst.get_read_data()
                    assert data[0] == addr
                    assert data[1] == test_data

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

