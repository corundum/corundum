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
import os

import axil

module = 'axil_register_rd'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    DATA_WIDTH = 32
    ADDR_WIDTH = 16
    STRB_WIDTH = (DATA_WIDTH/8)
    AR_REG_TYPE = 1
    R_REG_TYPE = 1

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axil_araddr = Signal(intbv(0)[ADDR_WIDTH:])
    s_axil_arprot = Signal(intbv(0)[3:])
    s_axil_arvalid = Signal(bool(0))
    s_axil_rready = Signal(bool(0))
    m_axil_arready = Signal(bool(0))
    m_axil_rdata = Signal(intbv(0)[DATA_WIDTH:])
    m_axil_rresp = Signal(intbv(0)[2:])
    m_axil_rvalid = Signal(bool(0))

    # Outputs
    s_axil_arready = Signal(bool(0))
    s_axil_rdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axil_rresp = Signal(intbv(0)[2:])
    s_axil_rvalid = Signal(bool(0))
    m_axil_araddr = Signal(intbv(0)[ADDR_WIDTH:])
    m_axil_arprot = Signal(intbv(0)[3:])
    m_axil_arvalid = Signal(bool(0))
    m_axil_rready = Signal(bool(0))

    # AXIl4 master
    axil_master_inst = axil.AXILiteMaster()
    axil_master_pause = Signal(bool(False))

    axil_master_logic = axil_master_inst.create_logic(
        clk,
        rst,
        m_axil_araddr=s_axil_araddr,
        m_axil_arprot=s_axil_arprot,
        m_axil_arvalid=s_axil_arvalid,
        m_axil_arready=s_axil_arready,
        m_axil_rdata=s_axil_rdata,
        m_axil_rresp=s_axil_rresp,
        m_axil_rvalid=s_axil_rvalid,
        m_axil_rready=s_axil_rready,
        pause=axil_master_pause,
        name='master'
    )

    # AXIl4 RAM model
    axil_ram_inst = axil.AXILiteRam(2**16)
    axil_ram_pause = Signal(bool(False))

    axil_ram_port0 = axil_ram_inst.create_port(
        clk,
        s_axil_araddr=m_axil_araddr,
        s_axil_arprot=m_axil_arprot,
        s_axil_arvalid=m_axil_arvalid,
        s_axil_arready=m_axil_arready,
        s_axil_rdata=m_axil_rdata,
        s_axil_rresp=m_axil_rresp,
        s_axil_rvalid=m_axil_rvalid,
        s_axil_rready=m_axil_rready,
        pause=axil_ram_pause,
        name='port0'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        s_axil_araddr=s_axil_araddr,
        s_axil_arprot=s_axil_arprot,
        s_axil_arvalid=s_axil_arvalid,
        s_axil_arready=s_axil_arready,
        s_axil_rdata=s_axil_rdata,
        s_axil_rresp=s_axil_rresp,
        s_axil_rvalid=s_axil_rvalid,
        s_axil_rready=s_axil_rready,
        m_axil_araddr=m_axil_araddr,
        m_axil_arprot=m_axil_arprot,
        m_axil_arvalid=m_axil_arvalid,
        m_axil_arready=m_axil_arready,
        m_axil_rdata=m_axil_rdata,
        m_axil_rresp=m_axil_rresp,
        m_axil_rvalid=m_axil_rvalid,
        m_axil_rready=m_axil_rready
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

        # testbench stimulus

        yield clk.posedge
        print("test 1: read")
        current_test.next = 1

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
        print("test 2: various reads")
        current_test.next = 2

        for length in range(1,8):
            for offset in range(4,8):
                for wait in wait_normal, wait_pause_master, wait_pause_slave:
                    print("length %d, offset %d"% (length, offset))
                    addr = 256*(16*offset+length)+offset
                    test_data = bytearray([x%256 for x in range(length)])

                    axil_ram_inst.write_mem(addr, test_data)

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
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
