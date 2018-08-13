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

import axi

def bench():

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    port0_axi_awid = Signal(intbv(0)[8:])
    port0_axi_awaddr = Signal(intbv(0)[32:])
    port0_axi_awlen = Signal(intbv(0)[8:])
    port0_axi_awsize = Signal(intbv(0)[3:])
    port0_axi_awburst = Signal(intbv(0)[2:])
    port0_axi_awlock = Signal(intbv(0)[1:])
    port0_axi_awcache = Signal(intbv(0)[4:])
    port0_axi_awprot = Signal(intbv(0)[3:])
    port0_axi_awqos = Signal(intbv(0)[4:])
    port0_axi_awregion = Signal(intbv(0)[4:])
    port0_axi_awvalid = Signal(bool(False))
    port0_axi_wdata = Signal(intbv(0)[32:])
    port0_axi_wstrb = Signal(intbv(0)[4:])
    port0_axi_wlast = Signal(bool(False))
    port0_axi_wvalid = Signal(bool(False))
    port0_axi_bready = Signal(bool(False))
    port0_axi_arid = Signal(intbv(0)[8:])
    port0_axi_araddr = Signal(intbv(0)[32:])
    port0_axi_arlen = Signal(intbv(0)[8:])
    port0_axi_arsize = Signal(intbv(0)[3:])
    port0_axi_arburst = Signal(intbv(0)[2:])
    port0_axi_arlock = Signal(intbv(0)[1:])
    port0_axi_arcache = Signal(intbv(0)[4:])
    port0_axi_arprot = Signal(intbv(0)[3:])
    port0_axi_arqos = Signal(intbv(0)[4:])
    port0_axi_arregion = Signal(intbv(0)[4:])
    port0_axi_arvalid = Signal(bool(False))
    port0_axi_rready = Signal(bool(False))

    # Outputs
    port0_axi_awready = Signal(bool(False))
    port0_axi_wready = Signal(bool(False))
    port0_axi_bid = Signal(intbv(0)[8:])
    port0_axi_bresp = Signal(intbv(0)[2:])
    port0_axi_bvalid = Signal(bool(False))
    port0_axi_arready = Signal(bool(False))
    port0_axi_rid = Signal(intbv(0)[8:])
    port0_axi_rdata = Signal(intbv(0)[32:])
    port0_axi_rresp = Signal(intbv(0)[2:])
    port0_axi_rlast = Signal(bool(False))
    port0_axi_rvalid = Signal(bool(False))

    # AXI4 master
    axi_master_inst = axi.AXIMaster()
    axi_master_pause = Signal(bool(False))

    axi_master_logic = axi_master_inst.create_logic(
        clk,
        rst,
        m_axi_awid=port0_axi_awid,
        m_axi_awaddr=port0_axi_awaddr,
        m_axi_awlen=port0_axi_awlen,
        m_axi_awsize=port0_axi_awsize,
        m_axi_awburst=port0_axi_awburst,
        m_axi_awlock=port0_axi_awlock,
        m_axi_awcache=port0_axi_awcache,
        m_axi_awprot=port0_axi_awprot,
        m_axi_awqos=port0_axi_awqos,
        m_axi_awregion=port0_axi_awregion,
        m_axi_awvalid=port0_axi_awvalid,
        m_axi_awready=port0_axi_awready,
        m_axi_wdata=port0_axi_wdata,
        m_axi_wstrb=port0_axi_wstrb,
        m_axi_wlast=port0_axi_wlast,
        m_axi_wvalid=port0_axi_wvalid,
        m_axi_wready=port0_axi_wready,
        m_axi_bid=port0_axi_bid,
        m_axi_bresp=port0_axi_bresp,
        m_axi_bvalid=port0_axi_bvalid,
        m_axi_bready=port0_axi_bready,
        m_axi_arid=port0_axi_arid,
        m_axi_araddr=port0_axi_araddr,
        m_axi_arlen=port0_axi_arlen,
        m_axi_arsize=port0_axi_arsize,
        m_axi_arburst=port0_axi_arburst,
        m_axi_arlock=port0_axi_arlock,
        m_axi_arcache=port0_axi_arcache,
        m_axi_arprot=port0_axi_arprot,
        m_axi_arqos=port0_axi_arqos,
        m_axi_arregion=port0_axi_arregion,
        m_axi_arvalid=port0_axi_arvalid,
        m_axi_arready=port0_axi_arready,
        m_axi_rid=port0_axi_rid,
        m_axi_rdata=port0_axi_rdata,
        m_axi_rresp=port0_axi_rresp,
        m_axi_rlast=port0_axi_rlast,
        m_axi_rvalid=port0_axi_rvalid,
        m_axi_rready=port0_axi_rready,
        pause=axi_master_pause,
        name='master'
    )

    # AXI4 RAM model
    axi_ram_inst = axi.AXIRam(2**16)
    axi_ram_pause = Signal(bool(False))

    axi_ram_port0 = axi_ram_inst.create_port(
        clk,
        s_axi_awid=port0_axi_awid,
        s_axi_awaddr=port0_axi_awaddr,
        s_axi_awlen=port0_axi_awlen,
        s_axi_awsize=port0_axi_awsize,
        s_axi_awburst=port0_axi_awburst,
        s_axi_awlock=port0_axi_awlock,
        s_axi_awcache=port0_axi_awcache,
        s_axi_awprot=port0_axi_awprot,
        s_axi_awvalid=port0_axi_awvalid,
        s_axi_awready=port0_axi_awready,
        s_axi_wdata=port0_axi_wdata,
        s_axi_wstrb=port0_axi_wstrb,
        s_axi_wlast=port0_axi_wlast,
        s_axi_wvalid=port0_axi_wvalid,
        s_axi_wready=port0_axi_wready,
        s_axi_bid=port0_axi_bid,
        s_axi_bresp=port0_axi_bresp,
        s_axi_bvalid=port0_axi_bvalid,
        s_axi_bready=port0_axi_bready,
        s_axi_arid=port0_axi_arid,
        s_axi_araddr=port0_axi_araddr,
        s_axi_arlen=port0_axi_arlen,
        s_axi_arsize=port0_axi_arsize,
        s_axi_arburst=port0_axi_arburst,
        s_axi_arlock=port0_axi_arlock,
        s_axi_arcache=port0_axi_arcache,
        s_axi_arprot=port0_axi_arprot,
        s_axi_arvalid=port0_axi_arvalid,
        s_axi_arready=port0_axi_arready,
        s_axi_rid=port0_axi_rid,
        s_axi_rdata=port0_axi_rdata,
        s_axi_rresp=port0_axi_rresp,
        s_axi_rlast=port0_axi_rlast,
        s_axi_rvalid=port0_axi_rvalid,
        s_axi_rready=port0_axi_rready,
        pause=axi_ram_pause,
        name='port0'
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    def wait_normal():
        while not axi_master_inst.idle():
            yield clk.posedge

    def wait_pause_master():
        while not axi_master_inst.idle():
            axi_master_pause.next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            axi_master_pause.next = False
            yield clk.posedge

    def wait_pause_slave():
        while not axi_master_inst.idle():
            axi_ram_pause.next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            axi_ram_pause.next = False
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

        data = axi_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        yield delay(100)

        yield clk.posedge
        print("test 2: direct write")
        current_test.next = 2

        axi_ram_inst.write_mem(0, b'test')

        data = axi_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axi_ram_inst.read_mem(0, 4) == b'test'

        yield delay(100)

        yield clk.posedge
        print("test 3: write via port0")
        current_test.next = 3

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axi_master_inst.init_write(addr, test_data)

        yield axi_master_inst.wait()
        yield clk.posedge

        data = axi_ram_inst.read_mem(addr&0xffffff80, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axi_ram_inst.read_mem(addr, len(test_data)) == test_data

        yield delay(100)

        yield clk.posedge
        print("test 4: read via port0")
        current_test.next = 4

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axi_ram_inst.write_mem(addr, test_data)

        axi_master_inst.init_read(addr, len(test_data))

        yield axi_master_inst.wait()
        yield clk.posedge

        data = axi_master_inst.get_read_data()
        assert data[0] == addr
        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 5: various writes")
        current_test.next = 5

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for size in (2, 1, 0):
                    for wait in wait_normal, wait_pause_master, wait_pause_slave:
                        print("length %d, offset %d, size %d"% (length, offset, size))
                        addr = 256*(16*offset+length)+offset
                        test_data = bytearray([x%256 for x in range(length)])

                        axi_ram_inst.write_mem(addr&0xffffff80, b'\xAA'*(length+256))
                        axi_master_inst.init_write(addr, test_data, size=size)

                        yield wait()
                        yield clk.posedge

                        data = axi_ram_inst.read_mem(addr&0xffffff80, 32)
                        for i in range(0, len(data), 16):
                            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                        assert axi_ram_inst.read_mem(addr, length) == test_data
                        assert axi_ram_inst.read_mem(addr-1, 1) == b'\xAA'
                        assert axi_ram_inst.read_mem(addr+length, 1) == b'\xAA'

        yield delay(100)

        yield clk.posedge
        print("test 6: various reads")
        current_test.next = 6

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for size in (2, 1, 0):
                    for wait in wait_normal, wait_pause_master, wait_pause_slave:
                        print("length %d, offset %d, size %d"% (length, offset, size))
                        addr = 256*(16*offset+length)+offset
                        test_data = bytearray([x%256 for x in range(length)])

                        axi_ram_inst.write_mem(addr, test_data)

                        axi_master_inst.init_read(addr, length, size=size)

                        yield wait()
                        yield clk.posedge

                        data = axi_master_inst.get_read_data()
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

