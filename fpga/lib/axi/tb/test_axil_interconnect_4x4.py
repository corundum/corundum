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

module = 'axil_interconnect'
testbench = 'test_%s_4x4' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/arbiter.v")
srcs.append("../rtl/priority_encoder.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    S_COUNT = 4
    M_COUNT = 4
    DATA_WIDTH = 32
    ADDR_WIDTH = 32
    STRB_WIDTH = (DATA_WIDTH/8)
    M_REGIONS = 1
    M_BASE_ADDR = [0x00000000, 0x01000000, 0x02000000, 0x03000000]
    M_ADDR_WIDTH = [24]*M_COUNT*M_REGIONS
    M_CONNECT_READ = [0b1111]*M_COUNT
    M_CONNECT_WRITE = [0b1111]*M_COUNT
    M_SECURE = 0b0000

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axil_awaddr_list = [Signal(intbv(0)[ADDR_WIDTH:]) for i in range(S_COUNT)]
    s_axil_awprot_list = [Signal(intbv(0)[3:]) for i in range(S_COUNT)]
    s_axil_awvalid_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axil_wdata_list = [Signal(intbv(0)[DATA_WIDTH:]) for i in range(S_COUNT)]
    s_axil_wstrb_list = [Signal(intbv(0)[STRB_WIDTH:]) for i in range(S_COUNT)]
    s_axil_wvalid_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axil_bready_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axil_araddr_list = [Signal(intbv(0)[ADDR_WIDTH:]) for i in range(S_COUNT)]
    s_axil_arprot_list = [Signal(intbv(0)[3:]) for i in range(S_COUNT)]
    s_axil_arvalid_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axil_rready_list = [Signal(bool(0)) for i in range(S_COUNT)]
    m_axil_awready_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axil_wready_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axil_bresp_list = [Signal(intbv(0)[2:]) for i in range(M_COUNT)]
    m_axil_bvalid_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axil_arready_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axil_rdata_list = [Signal(intbv(0)[DATA_WIDTH:]) for i in range(M_COUNT)]
    m_axil_rresp_list = [Signal(intbv(0)[2:]) for i in range(M_COUNT)]
    m_axil_rvalid_list = [Signal(bool(0)) for i in range(M_COUNT)]

    s_axil_awaddr = ConcatSignal(*reversed(s_axil_awaddr_list))
    s_axil_awprot = ConcatSignal(*reversed(s_axil_awprot_list))
    s_axil_awvalid = ConcatSignal(*reversed(s_axil_awvalid_list))
    s_axil_wdata = ConcatSignal(*reversed(s_axil_wdata_list))
    s_axil_wstrb = ConcatSignal(*reversed(s_axil_wstrb_list))
    s_axil_wvalid = ConcatSignal(*reversed(s_axil_wvalid_list))
    s_axil_bready = ConcatSignal(*reversed(s_axil_bready_list))
    s_axil_araddr = ConcatSignal(*reversed(s_axil_araddr_list))
    s_axil_arprot = ConcatSignal(*reversed(s_axil_arprot_list))
    s_axil_arvalid = ConcatSignal(*reversed(s_axil_arvalid_list))
    s_axil_rready = ConcatSignal(*reversed(s_axil_rready_list))
    m_axil_awready = ConcatSignal(*reversed(m_axil_awready_list))
    m_axil_wready = ConcatSignal(*reversed(m_axil_wready_list))
    m_axil_bresp = ConcatSignal(*reversed(m_axil_bresp_list))
    m_axil_bvalid = ConcatSignal(*reversed(m_axil_bvalid_list))
    m_axil_arready = ConcatSignal(*reversed(m_axil_arready_list))
    m_axil_rdata = ConcatSignal(*reversed(m_axil_rdata_list))
    m_axil_rresp = ConcatSignal(*reversed(m_axil_rresp_list))
    m_axil_rvalid = ConcatSignal(*reversed(m_axil_rvalid_list))

    # Outputs
    s_axil_awready = Signal(intbv(0)[S_COUNT:])
    s_axil_wready = Signal(intbv(0)[S_COUNT:])
    s_axil_bresp = Signal(intbv(0)[S_COUNT*2:])
    s_axil_bvalid = Signal(intbv(0)[S_COUNT:])
    s_axil_arready = Signal(intbv(0)[S_COUNT:])
    s_axil_rdata = Signal(intbv(0)[S_COUNT*DATA_WIDTH:])
    s_axil_rresp = Signal(intbv(0)[S_COUNT*2:])
    s_axil_rvalid = Signal(intbv(0)[S_COUNT:])
    m_axil_awaddr = Signal(intbv(0)[M_COUNT*ADDR_WIDTH:])
    m_axil_awprot = Signal(intbv(0)[M_COUNT*3:])
    m_axil_awvalid = Signal(intbv(0)[M_COUNT:])
    m_axil_wdata = Signal(intbv(0)[M_COUNT*DATA_WIDTH:])
    m_axil_wstrb = Signal(intbv(0)[M_COUNT*STRB_WIDTH:])
    m_axil_wvalid = Signal(intbv(0)[M_COUNT:])
    m_axil_bready = Signal(intbv(0)[M_COUNT:])
    m_axil_araddr = Signal(intbv(0)[M_COUNT*ADDR_WIDTH:])
    m_axil_arprot = Signal(intbv(0)[M_COUNT*3:])
    m_axil_arvalid = Signal(intbv(0)[M_COUNT:])
    m_axil_rready = Signal(intbv(0)[M_COUNT:])

    s_axil_awready_list = [s_axil_awready(i) for i in range(S_COUNT)]
    s_axil_wready_list = [s_axil_wready(i) for i in range(S_COUNT)]
    s_axil_bresp_list = [s_axil_bresp((i+1)*2, i*2) for i in range(S_COUNT)]
    s_axil_bvalid_list = [s_axil_bvalid(i) for i in range(S_COUNT)]
    s_axil_arready_list = [s_axil_arready(i) for i in range(S_COUNT)]
    s_axil_rdata_list = [s_axil_rdata((i+1)*DATA_WIDTH, i*DATA_WIDTH) for i in range(S_COUNT)]
    s_axil_rresp_list = [s_axil_rresp((i+1)*2, i*2) for i in range(S_COUNT)]
    s_axil_rvalid_list = [s_axil_rvalid(i) for i in range(S_COUNT)]
    m_axil_awaddr_list = [m_axil_awaddr((i+1)*ADDR_WIDTH, i*ADDR_WIDTH) for i in range(M_COUNT)]
    m_axil_awprot_list = [m_axil_awprot((i+1)*3, i*3) for i in range(M_COUNT)]
    m_axil_awvalid_list = [m_axil_awvalid(i) for i in range(M_COUNT)]
    m_axil_wdata_list = [m_axil_wdata((i+1)*DATA_WIDTH, i*DATA_WIDTH) for i in range(M_COUNT)]
    m_axil_wstrb_list = [m_axil_wstrb((i+1)*STRB_WIDTH, i*STRB_WIDTH) for i in range(M_COUNT)]
    m_axil_wvalid_list = [m_axil_wvalid(i) for i in range(M_COUNT)]
    m_axil_bready_list = [m_axil_bready(i) for i in range(M_COUNT)]
    m_axil_araddr_list = [m_axil_araddr((i+1)*ADDR_WIDTH, i*ADDR_WIDTH) for i in range(M_COUNT)]
    m_axil_arprot_list = [m_axil_arprot((i+1)*3, i*3) for i in range(M_COUNT)]
    m_axil_arvalid_list = [m_axil_arvalid(i) for i in range(M_COUNT)]
    m_axil_rready_list = [m_axil_rready(i) for i in range(M_COUNT)]

    # AXI4-Lite masters
    axil_master_inst_list = []
    axil_master_pause_list = []
    axil_master_logic = []

    for k in range(S_COUNT):
        m = axil.AXILiteMaster()
        p = Signal(bool(False))

        axil_master_inst_list.append(m)
        axil_master_pause_list.append(p)

        axil_master_logic.append(m.create_logic(
            clk,
            rst,
            m_axil_awaddr=s_axil_awaddr_list[k],
            m_axil_awprot=s_axil_awprot_list[k],
            m_axil_awvalid=s_axil_awvalid_list[k],
            m_axil_awready=s_axil_awready_list[k],
            m_axil_wdata=s_axil_wdata_list[k],
            m_axil_wstrb=s_axil_wstrb_list[k],
            m_axil_wvalid=s_axil_wvalid_list[k],
            m_axil_wready=s_axil_wready_list[k],
            m_axil_bresp=s_axil_bresp_list[k],
            m_axil_bvalid=s_axil_bvalid_list[k],
            m_axil_bready=s_axil_bready_list[k],
            m_axil_araddr=s_axil_araddr_list[k],
            m_axil_arprot=s_axil_arprot_list[k],
            m_axil_arvalid=s_axil_arvalid_list[k],
            m_axil_arready=s_axil_arready_list[k],
            m_axil_rdata=s_axil_rdata_list[k],
            m_axil_rresp=s_axil_rresp_list[k],
            m_axil_rvalid=s_axil_rvalid_list[k],
            m_axil_rready=s_axil_rready_list[k],
            pause=p,
            name='master_%d' % k
        ))

    # AXI4-Lite RAM models
    axil_ram_inst_list = []
    axil_ram_pause_list = []
    axil_ram_logic = []

    for k in range(M_COUNT):
        r = axil.AXILiteRam(2**16)
        p = Signal(bool(False))

        axil_ram_inst_list.append(r)
        axil_ram_pause_list.append(p)

        axil_ram_logic.append(r.create_port(
            clk,
            s_axil_awaddr=m_axil_awaddr_list[k],
            s_axil_awprot=m_axil_awprot_list[k],
            s_axil_awvalid=m_axil_awvalid_list[k],
            s_axil_awready=m_axil_awready_list[k],
            s_axil_wdata=m_axil_wdata_list[k],
            s_axil_wstrb=m_axil_wstrb_list[k],
            s_axil_wvalid=m_axil_wvalid_list[k],
            s_axil_wready=m_axil_wready_list[k],
            s_axil_bresp=m_axil_bresp_list[k],
            s_axil_bvalid=m_axil_bvalid_list[k],
            s_axil_bready=m_axil_bready_list[k],
            s_axil_araddr=m_axil_araddr_list[k],
            s_axil_arprot=m_axil_arprot_list[k],
            s_axil_arvalid=m_axil_arvalid_list[k],
            s_axil_arready=m_axil_arready_list[k],
            s_axil_rdata=m_axil_rdata_list[k],
            s_axil_rresp=m_axil_rresp_list[k],
            s_axil_rvalid=m_axil_rvalid_list[k],
            s_axil_rready=m_axil_rready_list[k],
            pause=p,
            latency=1,
            name='ram_%d' % k
        ))

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        s_axil_awaddr=s_axil_awaddr,
        s_axil_awprot=s_axil_awprot,
        s_axil_awvalid=s_axil_awvalid,
        s_axil_awready=s_axil_awready,
        s_axil_wdata=s_axil_wdata,
        s_axil_wstrb=s_axil_wstrb,
        s_axil_wvalid=s_axil_wvalid,
        s_axil_wready=s_axil_wready,
        s_axil_bresp=s_axil_bresp,
        s_axil_bvalid=s_axil_bvalid,
        s_axil_bready=s_axil_bready,
        s_axil_araddr=s_axil_araddr,
        s_axil_arprot=s_axil_arprot,
        s_axil_arvalid=s_axil_arvalid,
        s_axil_arready=s_axil_arready,
        s_axil_rdata=s_axil_rdata,
        s_axil_rresp=s_axil_rresp,
        s_axil_rvalid=s_axil_rvalid,
        s_axil_rready=s_axil_rready,
        m_axil_awaddr=m_axil_awaddr,
        m_axil_awprot=m_axil_awprot,
        m_axil_awvalid=m_axil_awvalid,
        m_axil_awready=m_axil_awready,
        m_axil_wdata=m_axil_wdata,
        m_axil_wstrb=m_axil_wstrb,
        m_axil_wvalid=m_axil_wvalid,
        m_axil_wready=m_axil_wready,
        m_axil_bresp=m_axil_bresp,
        m_axil_bvalid=m_axil_bvalid,
        m_axil_bready=m_axil_bready,
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
        while not all([axil_master_inst_list[k].idle() for k in range(S_COUNT)]):
            yield clk.posedge

    def wait_pause_master():
        while not all([axil_master_inst_list[k].idle() for k in range(S_COUNT)]):
            for k in range(S_COUNT):
                axil_master_pause_list[k].next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            for k in range(S_COUNT):
                axil_master_pause_list[k].next = False
            yield clk.posedge

    def wait_pause_slave():
        while not all([axil_master_inst_list[k].idle() for k in range(S_COUNT)]):
            for k in range(M_COUNT):
                axil_ram_pause_list[k].next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            for k in range(M_COUNT):
                axil_ram_pause_list[k].next = False
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
        print("test 1: write")
        current_test.next = 1

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axil_master_inst_list[0].init_write(addr, test_data)

        yield axil_master_inst_list[0].wait()
        yield clk.posedge

        data = axil_ram_inst_list[0].read_mem(addr&0xffffff80, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axil_ram_inst_list[0].read_mem(addr, len(test_data)) == test_data

        yield delay(100)

        yield clk.posedge
        print("test 2: read")
        current_test.next = 2

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axil_ram_inst_list[0].write_mem(addr, test_data)

        axil_master_inst_list[0].init_read(addr, len(test_data))

        yield axil_master_inst_list[0].wait()
        yield clk.posedge

        data = axil_master_inst_list[0].get_read_data()
        assert data[0] == addr
        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 3: one to many")
        current_test.next = 3

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        for k in range(S_COUNT):
            axil_master_inst_list[0].init_write(addr+M_BASE_ADDR[k], test_data)

        yield axil_master_inst_list[0].wait()
        yield clk.posedge

        for k in range(S_COUNT):
            data = axil_ram_inst_list[k].read_mem(addr&0xffffff80, 32)
            for i in range(0, len(data), 16):
                print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        for k in range(S_COUNT):
            assert axil_ram_inst_list[k].read_mem(addr, len(test_data)) == test_data

        for k in range(S_COUNT):
            axil_master_inst_list[0].init_read(addr+M_BASE_ADDR[k], len(test_data))

        yield axil_master_inst_list[0].wait()
        yield clk.posedge

        for k in range(S_COUNT):
            data = axil_master_inst_list[0].get_read_data()
            assert data[0] == addr+M_BASE_ADDR[k]
            assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 4: many to one")
        current_test.next = 4

        for k in range(M_COUNT):
            axil_master_inst_list[k].init_write(k*4, bytearray([(k+1)*17]*4))

        for k in range(M_COUNT):
            yield axil_master_inst_list[k].wait()
        yield clk.posedge

        data = axil_ram_inst_list[0].read_mem(addr&0xffffff80, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        for k in range(M_COUNT):
            assert axil_ram_inst_list[0].read_mem(k*4, 4) == bytearray([(k+1)*17]*4)

        for k in range(M_COUNT):
            axil_master_inst_list[k].init_read(k*4, 4)

        for k in range(M_COUNT):
            yield axil_master_inst_list[k].wait()
        yield clk.posedge

        for k in range(M_COUNT):
            data = axil_master_inst_list[k].get_read_data()
            assert data[0] == k*4
            assert data[1] == bytearray([(k+1)*17]*4)

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

                    axil_ram_inst_list[0].write_mem(256*(16*offset+length), b'\xAA'*32)
                    axil_master_inst_list[0].init_write(addr, test_data)

                    yield wait()
                    yield clk.posedge

                    data = axil_ram_inst_list[0].read_mem(256*(16*offset+length), 32)
                    for i in range(0, len(data), 16):
                        print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                    assert axil_ram_inst_list[0].read_mem(addr, length) == test_data
                    assert axil_ram_inst_list[0].read_mem(addr-1, 1) == b'\xAA'
                    assert axil_ram_inst_list[0].read_mem(addr+length, 1) == b'\xAA'

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

                    axil_master_inst_list[0].init_read(addr, length)

                    yield wait()
                    yield clk.posedge

                    data = axil_master_inst_list[0].get_read_data()
                    assert data[0] == addr
                    assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 7: concurrent operations")
        current_test.next = 7

        for count in [1, 2, 4, 8]:
            for stride in [2, 3, 5, 7]:
                for wait in wait_normal, wait_pause_master, wait_pause_slave:
                    print("count %d, stride %d"% (count, stride))

                    for k in range(S_COUNT):
                        for l in range(count):
                            ram = ((k*61+l)*stride)%M_COUNT
                            offset = k*256+l*4
                            axil_ram_inst_list[ram].write_mem(offset, b'\xAA'*4)
                            axil_master_inst_list[k].init_write(M_BASE_ADDR[ram]+offset, bytearray([0xaa, k, l, 0xaa]))

                            ram = ((k*61+l+67)*stride)%M_COUNT
                            offset = k*256+l*4
                            axil_ram_inst_list[ram].write_mem(offset+0x8000, bytearray([0xaa, k, l, 0xaa]))
                            axil_master_inst_list[k].init_read(M_BASE_ADDR[ram]+offset+0x8000, 4)

                    yield wait()
                    yield clk.posedge

                    for k in range(S_COUNT):
                        for l in range(count):
                            ram = ((k*61+l)*stride)%M_COUNT
                            offset = k*256+l*4
                            axil_ram_inst_list[ram].read_mem(offset, 4) == bytearray([0xaa, k, l, 0xaa])

                            ram = ((k*61+l+67)*stride)%M_COUNT
                            offset = k*256+l*4
                            data = axil_master_inst_list[k].get_read_data()
                            assert data[0] == M_BASE_ADDR[ram]+offset+0x8000
                            assert data[1] == bytearray([0xaa, k, l, 0xaa])

        yield delay(100)

        yield clk.posedge
        print("test 8: bad write")
        current_test.next = 8

        axil_master_inst_list[0].init_write(0xff000000, b'\xDE\xAD\xBE\xEF')

        yield axil_master_inst_list[0].wait()
        yield clk.posedge

        yield delay(100)

        yield clk.posedge
        print("test 9: bad read")
        current_test.next = 9

        axil_master_inst_list[0].init_read(0xff000000, 4)

        yield axil_master_inst_list[0].wait()
        yield clk.posedge

        data = axil_master_inst_list[0].get_read_data()
        assert data[0] == 0xff000000

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
