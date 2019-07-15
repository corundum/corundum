#!/usr/bin/env python
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
import os

import axi

module = 'axi_dp_ram'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/axi_ram_wr_if.v")
srcs.append("../rtl/axi_ram_rd_if.v")
srcs.append("../rtl/axi_ram_wr_rd_if.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    DATA_WIDTH = 32
    ADDR_WIDTH = 16
    STRB_WIDTH = (DATA_WIDTH/8)
    ID_WIDTH = 8
    A_PIPELINE_OUTPUT = 0
    B_PIPELINE_OUTPUT = 0
    A_INTERLEAVE = 0
    B_INTERLEAVE = 1

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    a_clk = Signal(bool(0))
    a_rst = Signal(bool(0))
    b_clk = Signal(bool(0))
    b_rst = Signal(bool(0))
    s_axi_a_awid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_a_awaddr = Signal(intbv(0)[ADDR_WIDTH:])
    s_axi_a_awlen = Signal(intbv(0)[8:])
    s_axi_a_awsize = Signal(intbv(0)[3:])
    s_axi_a_awburst = Signal(intbv(0)[2:])
    s_axi_a_awlock = Signal(bool(0))
    s_axi_a_awcache = Signal(intbv(0)[4:])
    s_axi_a_awprot = Signal(intbv(0)[3:])
    s_axi_a_awvalid = Signal(bool(0))
    s_axi_a_wdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axi_a_wstrb = Signal(intbv(0)[STRB_WIDTH:])
    s_axi_a_wlast = Signal(bool(0))
    s_axi_a_wvalid = Signal(bool(0))
    s_axi_a_bready = Signal(bool(0))
    s_axi_a_arid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_a_araddr = Signal(intbv(0)[ADDR_WIDTH:])
    s_axi_a_arlen = Signal(intbv(0)[8:])
    s_axi_a_arsize = Signal(intbv(0)[3:])
    s_axi_a_arburst = Signal(intbv(0)[2:])
    s_axi_a_arlock = Signal(bool(0))
    s_axi_a_arcache = Signal(intbv(0)[4:])
    s_axi_a_arprot = Signal(intbv(0)[3:])
    s_axi_a_arvalid = Signal(bool(0))
    s_axi_a_rready = Signal(bool(0))
    s_axi_b_awid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_b_awaddr = Signal(intbv(0)[ADDR_WIDTH:])
    s_axi_b_awlen = Signal(intbv(0)[8:])
    s_axi_b_awsize = Signal(intbv(0)[3:])
    s_axi_b_awburst = Signal(intbv(0)[2:])
    s_axi_b_awlock = Signal(bool(0))
    s_axi_b_awcache = Signal(intbv(0)[4:])
    s_axi_b_awprot = Signal(intbv(0)[3:])
    s_axi_b_awvalid = Signal(bool(0))
    s_axi_b_wdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axi_b_wstrb = Signal(intbv(0)[STRB_WIDTH:])
    s_axi_b_wlast = Signal(bool(0))
    s_axi_b_wvalid = Signal(bool(0))
    s_axi_b_bready = Signal(bool(0))
    s_axi_b_arid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_b_araddr = Signal(intbv(0)[ADDR_WIDTH:])
    s_axi_b_arlen = Signal(intbv(0)[8:])
    s_axi_b_arsize = Signal(intbv(0)[3:])
    s_axi_b_arburst = Signal(intbv(0)[2:])
    s_axi_b_arlock = Signal(bool(0))
    s_axi_b_arcache = Signal(intbv(0)[4:])
    s_axi_b_arprot = Signal(intbv(0)[3:])
    s_axi_b_arvalid = Signal(bool(0))
    s_axi_b_rready = Signal(bool(0))

    # Outputs
    s_axi_a_awready = Signal(bool(0))
    s_axi_a_wready = Signal(bool(0))
    s_axi_a_bid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_a_bresp = Signal(intbv(0)[2:])
    s_axi_a_bvalid = Signal(bool(0))
    s_axi_a_arready = Signal(bool(0))
    s_axi_a_rid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_a_rdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axi_a_rresp = Signal(intbv(0)[2:])
    s_axi_a_rlast = Signal(bool(0))
    s_axi_a_rvalid = Signal(bool(0))
    s_axi_b_awready = Signal(bool(0))
    s_axi_b_wready = Signal(bool(0))
    s_axi_b_bid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_b_bresp = Signal(intbv(0)[2:])
    s_axi_b_bvalid = Signal(bool(0))
    s_axi_b_arready = Signal(bool(0))
    s_axi_b_rid = Signal(intbv(0)[ID_WIDTH:])
    s_axi_b_rdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axi_b_rresp = Signal(intbv(0)[2:])
    s_axi_b_rlast = Signal(bool(0))
    s_axi_b_rvalid = Signal(bool(0))

    # AXI4 master
    axi_a_master_inst = axi.AXIMaster()
    axi_a_master_pause = Signal(bool(False))

    axi_a_master_logic = axi_a_master_inst.create_logic(
        a_clk,
        a_rst,
        m_axi_awid=s_axi_a_awid,
        m_axi_awaddr=s_axi_a_awaddr,
        m_axi_awlen=s_axi_a_awlen,
        m_axi_awsize=s_axi_a_awsize,
        m_axi_awburst=s_axi_a_awburst,
        m_axi_awlock=s_axi_a_awlock,
        m_axi_awcache=s_axi_a_awcache,
        m_axi_awprot=s_axi_a_awprot,
        m_axi_awvalid=s_axi_a_awvalid,
        m_axi_awready=s_axi_a_awready,
        m_axi_wdata=s_axi_a_wdata,
        m_axi_wstrb=s_axi_a_wstrb,
        m_axi_wlast=s_axi_a_wlast,
        m_axi_wvalid=s_axi_a_wvalid,
        m_axi_wready=s_axi_a_wready,
        m_axi_bid=s_axi_a_bid,
        m_axi_bresp=s_axi_a_bresp,
        m_axi_bvalid=s_axi_a_bvalid,
        m_axi_bready=s_axi_a_bready,
        m_axi_arid=s_axi_a_arid,
        m_axi_araddr=s_axi_a_araddr,
        m_axi_arlen=s_axi_a_arlen,
        m_axi_arsize=s_axi_a_arsize,
        m_axi_arburst=s_axi_a_arburst,
        m_axi_arlock=s_axi_a_arlock,
        m_axi_arcache=s_axi_a_arcache,
        m_axi_arprot=s_axi_a_arprot,
        m_axi_arvalid=s_axi_a_arvalid,
        m_axi_arready=s_axi_a_arready,
        m_axi_rid=s_axi_a_rid,
        m_axi_rdata=s_axi_a_rdata,
        m_axi_rresp=s_axi_a_rresp,
        m_axi_rlast=s_axi_a_rlast,
        m_axi_rvalid=s_axi_a_rvalid,
        m_axi_rready=s_axi_a_rready,
        pause=axi_a_master_pause,
        name='master_a'
    )

    axi_b_master_inst = axi.AXIMaster()
    axi_b_master_pause = Signal(bool(False))

    axi_b_master_logic = axi_b_master_inst.create_logic(
        b_clk,
        b_rst,
        m_axi_awid=s_axi_b_awid,
        m_axi_awaddr=s_axi_b_awaddr,
        m_axi_awlen=s_axi_b_awlen,
        m_axi_awsize=s_axi_b_awsize,
        m_axi_awburst=s_axi_b_awburst,
        m_axi_awlock=s_axi_b_awlock,
        m_axi_awcache=s_axi_b_awcache,
        m_axi_awprot=s_axi_b_awprot,
        m_axi_awvalid=s_axi_b_awvalid,
        m_axi_awready=s_axi_b_awready,
        m_axi_wdata=s_axi_b_wdata,
        m_axi_wstrb=s_axi_b_wstrb,
        m_axi_wlast=s_axi_b_wlast,
        m_axi_wvalid=s_axi_b_wvalid,
        m_axi_wready=s_axi_b_wready,
        m_axi_bid=s_axi_b_bid,
        m_axi_bresp=s_axi_b_bresp,
        m_axi_bvalid=s_axi_b_bvalid,
        m_axi_bready=s_axi_b_bready,
        m_axi_arid=s_axi_b_arid,
        m_axi_araddr=s_axi_b_araddr,
        m_axi_arlen=s_axi_b_arlen,
        m_axi_arsize=s_axi_b_arsize,
        m_axi_arburst=s_axi_b_arburst,
        m_axi_arlock=s_axi_b_arlock,
        m_axi_arcache=s_axi_b_arcache,
        m_axi_arprot=s_axi_b_arprot,
        m_axi_arvalid=s_axi_b_arvalid,
        m_axi_arready=s_axi_b_arready,
        m_axi_rid=s_axi_b_rid,
        m_axi_rdata=s_axi_b_rdata,
        m_axi_rresp=s_axi_b_rresp,
        m_axi_rlast=s_axi_b_rlast,
        m_axi_rvalid=s_axi_b_rvalid,
        m_axi_rready=s_axi_b_rready,
        pause=axi_b_master_pause,
        name='master_b'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,

        a_clk=a_clk,
        a_rst=a_rst,
        b_clk=b_clk,
        b_rst=b_rst,
        s_axi_a_awid=s_axi_a_awid,
        s_axi_a_awaddr=s_axi_a_awaddr,
        s_axi_a_awlen=s_axi_a_awlen,
        s_axi_a_awsize=s_axi_a_awsize,
        s_axi_a_awburst=s_axi_a_awburst,
        s_axi_a_awlock=s_axi_a_awlock,
        s_axi_a_awcache=s_axi_a_awcache,
        s_axi_a_awprot=s_axi_a_awprot,
        s_axi_a_awvalid=s_axi_a_awvalid,
        s_axi_a_awready=s_axi_a_awready,
        s_axi_a_wdata=s_axi_a_wdata,
        s_axi_a_wstrb=s_axi_a_wstrb,
        s_axi_a_wlast=s_axi_a_wlast,
        s_axi_a_wvalid=s_axi_a_wvalid,
        s_axi_a_wready=s_axi_a_wready,
        s_axi_a_bid=s_axi_a_bid,
        s_axi_a_bresp=s_axi_a_bresp,
        s_axi_a_bvalid=s_axi_a_bvalid,
        s_axi_a_bready=s_axi_a_bready,
        s_axi_a_arid=s_axi_a_arid,
        s_axi_a_araddr=s_axi_a_araddr,
        s_axi_a_arlen=s_axi_a_arlen,
        s_axi_a_arsize=s_axi_a_arsize,
        s_axi_a_arburst=s_axi_a_arburst,
        s_axi_a_arlock=s_axi_a_arlock,
        s_axi_a_arcache=s_axi_a_arcache,
        s_axi_a_arprot=s_axi_a_arprot,
        s_axi_a_arvalid=s_axi_a_arvalid,
        s_axi_a_arready=s_axi_a_arready,
        s_axi_a_rid=s_axi_a_rid,
        s_axi_a_rdata=s_axi_a_rdata,
        s_axi_a_rresp=s_axi_a_rresp,
        s_axi_a_rlast=s_axi_a_rlast,
        s_axi_a_rvalid=s_axi_a_rvalid,
        s_axi_a_rready=s_axi_a_rready,
        s_axi_b_awid=s_axi_b_awid,
        s_axi_b_awaddr=s_axi_b_awaddr,
        s_axi_b_awlen=s_axi_b_awlen,
        s_axi_b_awsize=s_axi_b_awsize,
        s_axi_b_awburst=s_axi_b_awburst,
        s_axi_b_awlock=s_axi_b_awlock,
        s_axi_b_awcache=s_axi_b_awcache,
        s_axi_b_awprot=s_axi_b_awprot,
        s_axi_b_awvalid=s_axi_b_awvalid,
        s_axi_b_awready=s_axi_b_awready,
        s_axi_b_wdata=s_axi_b_wdata,
        s_axi_b_wstrb=s_axi_b_wstrb,
        s_axi_b_wlast=s_axi_b_wlast,
        s_axi_b_wvalid=s_axi_b_wvalid,
        s_axi_b_wready=s_axi_b_wready,
        s_axi_b_bid=s_axi_b_bid,
        s_axi_b_bresp=s_axi_b_bresp,
        s_axi_b_bvalid=s_axi_b_bvalid,
        s_axi_b_bready=s_axi_b_bready,
        s_axi_b_arid=s_axi_b_arid,
        s_axi_b_araddr=s_axi_b_araddr,
        s_axi_b_arlen=s_axi_b_arlen,
        s_axi_b_arsize=s_axi_b_arsize,
        s_axi_b_arburst=s_axi_b_arburst,
        s_axi_b_arlock=s_axi_b_arlock,
        s_axi_b_arcache=s_axi_b_arcache,
        s_axi_b_arprot=s_axi_b_arprot,
        s_axi_b_arvalid=s_axi_b_arvalid,
        s_axi_b_arready=s_axi_b_arready,
        s_axi_b_rid=s_axi_b_rid,
        s_axi_b_rdata=s_axi_b_rdata,
        s_axi_b_rresp=s_axi_b_rresp,
        s_axi_b_rlast=s_axi_b_rlast,
        s_axi_b_rvalid=s_axi_b_rvalid,
        s_axi_b_rready=s_axi_b_rready
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk
        a_clk.next = not a_clk
        b_clk.next = not b_clk

    def wait_normal():
        while not axi_a_master_inst.idle() or not axi_b_master_inst.idle():
            yield clk.posedge

    def wait_pause_master():
        while not axi_a_master_inst.idle() or not axi_b_master_inst.idle():
            axi_a_master_pause.next = True
            axi_b_master_pause.next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            axi_a_master_pause.next = False
            axi_b_master_pause.next = False
            yield clk.posedge

    @instance
    def check():
        yield delay(100)
        yield clk.posedge
        rst.next = 1
        a_rst.next = 1
        b_rst.next = 1
        yield clk.posedge
        rst.next = 0
        a_rst.next = 0
        b_rst.next = 0
        yield clk.posedge
        yield delay(100)
        yield clk.posedge

        # testbench stimulus

        yield clk.posedge
        print("test 1: read and write, port A")
        current_test.next = 1

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axi_a_master_inst.init_write(addr, test_data)

        yield axi_a_master_inst.wait()
        yield clk.posedge

        axi_a_master_inst.init_read(addr, len(test_data))

        yield axi_a_master_inst.wait()
        yield clk.posedge

        data = axi_a_master_inst.get_read_data()
        assert data[0] == addr
        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 2: read and write, port B")
        current_test.next = 2

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axi_b_master_inst.init_write(addr, test_data)

        yield axi_b_master_inst.wait()
        yield clk.posedge

        axi_b_master_inst.init_read(addr, len(test_data))

        yield axi_b_master_inst.wait()
        yield clk.posedge

        data = axi_b_master_inst.get_read_data()
        assert data[0] == addr
        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 3: various reads and writes, port A")
        current_test.next = 3

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for size in (2, 1, 0):
                    for wait in wait_normal, wait_pause_master:
                        print("length %d, offset %d, size %d"% (length, offset, size))
                        #addr = 256*(16*offset+length)+offset
                        addr = offset
                        test_data = bytearray([x%256 for x in range(length)])

                        axi_a_master_inst.init_write(addr-4, b'\xAA'*(length+8))

                        yield axi_a_master_inst.wait()

                        axi_a_master_inst.init_write(addr, test_data, size=size)

                        yield wait()

                        axi_a_master_inst.init_read(addr-1, length+2)

                        yield axi_a_master_inst.wait()

                        data = axi_a_master_inst.get_read_data()
                        assert data[0] == addr-1
                        assert data[1] == b'\xAA'+test_data+b'\xAA'

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for size in (2, 1, 0):
                    for wait in wait_normal, wait_pause_master:
                        print("length %d, offset %d, size %d"% (length, offset, size))
                        #addr = 256*(16*offset+length)+offset
                        addr = offset
                        test_data = bytearray([x%256 for x in range(length)])

                        axi_a_master_inst.init_write(addr, test_data)

                        yield axi_a_master_inst.wait()

                        axi_a_master_inst.init_read(addr, length, size=size)

                        yield wait()
                        yield clk.posedge

                        data = axi_a_master_inst.get_read_data()
                        assert data[0] == addr
                        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 4: various reads and writes, port B")
        current_test.next = 4

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for size in (2, 1, 0):
                    for wait in wait_normal, wait_pause_master:
                        print("length %d, offset %d, size %d"% (length, offset, size))
                        #addr = 256*(16*offset+length)+offset
                        addr = offset
                        test_data = bytearray([x%256 for x in range(length)])

                        axi_b_master_inst.init_write(addr-4, b'\xAA'*(length+8))

                        yield axi_b_master_inst.wait()

                        axi_b_master_inst.init_write(addr, test_data, size=size)

                        yield wait()

                        axi_b_master_inst.init_read(addr-1, length+2)

                        yield axi_b_master_inst.wait()

                        data = axi_b_master_inst.get_read_data()
                        assert data[0] == addr-1
                        assert data[1] == b'\xAA'+test_data+b'\xAA'

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for size in (2, 1, 0):
                    for wait in wait_normal, wait_pause_master:
                        print("length %d, offset %d, size %d"% (length, offset, size))
                        #addr = 256*(16*offset+length)+offset
                        addr = offset
                        test_data = bytearray([x%256 for x in range(length)])

                        axi_b_master_inst.init_write(addr, test_data)

                        yield axi_b_master_inst.wait()

                        axi_b_master_inst.init_read(addr, length, size=size)

                        yield wait()
                        yield clk.posedge

                        data = axi_b_master_inst.get_read_data()
                        assert data[0] == addr
                        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 5: arbitration test")
        current_test.next = 5

        for k in range(10):
            axi_a_master_inst.init_write(k*256, b'\x11\x22\x33\x44')
            axi_a_master_inst.init_read(k*256, 4)
            axi_b_master_inst.init_write(k*256, b'\x11\x22\x33\x44')
            axi_b_master_inst.init_read(k*256, 4)

        for k in range(10):
            axi_a_master_inst.init_write(k*256, bytearray(range(256)))
            axi_a_master_inst.init_read(k*256, 256)
            axi_b_master_inst.init_write(k*256, bytearray(range(256)))
            axi_b_master_inst.init_read(k*256, 256)

        yield wait_normal()

        for k in range(20):
            axi_a_master_inst.get_read_data()
            axi_b_master_inst.get_read_data()

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
