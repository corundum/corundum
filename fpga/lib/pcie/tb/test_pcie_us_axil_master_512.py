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
import pcie_us

module = 'pcie_us_axil_master'
testbench = 'test_%s_512' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    AXIS_PCIE_DATA_WIDTH = 512
    AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32)
    AXIS_PCIE_CQ_USER_WIDTH = 183
    AXIS_PCIE_CC_USER_WIDTH = 81
    AXI_DATA_WIDTH = 32
    AXI_ADDR_WIDTH = 64
    AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8)
    ENABLE_PARITY = 0

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_cq_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    s_axis_cq_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    s_axis_cq_tvalid = Signal(bool(0))
    s_axis_cq_tlast = Signal(bool(0))
    s_axis_cq_tuser = Signal(intbv(0)[AXIS_PCIE_CQ_USER_WIDTH:])
    m_axis_cc_tready = Signal(bool(0))
    m_axil_awready = Signal(bool(0))
    m_axil_wready = Signal(bool(0))
    m_axil_bresp = Signal(intbv(0)[2:])
    m_axil_bvalid = Signal(bool(0))
    m_axil_arready = Signal(bool(0))
    m_axil_rdata = Signal(intbv(0)[AXI_DATA_WIDTH:])
    m_axil_rresp = Signal(intbv(0)[2:])
    m_axil_rvalid = Signal(bool(0))
    completer_id = Signal(intbv(0)[16:])
    completer_id_enable = Signal(bool(0))

    # Outputs
    s_axis_cq_tready = Signal(bool(0))
    m_axis_cc_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    m_axis_cc_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    m_axis_cc_tvalid = Signal(bool(0))
    m_axis_cc_tlast = Signal(bool(0))
    m_axis_cc_tuser = Signal(intbv(0)[AXIS_PCIE_CC_USER_WIDTH:])
    m_axil_awaddr = Signal(intbv(0)[AXI_ADDR_WIDTH:])
    m_axil_awprot = Signal(intbv(0)[3:])
    m_axil_awvalid = Signal(bool(0))
    m_axil_wdata = Signal(intbv(0)[AXI_DATA_WIDTH:])
    m_axil_wstrb = Signal(intbv(0)[AXI_STRB_WIDTH:])
    m_axil_wvalid = Signal(bool(0))
    m_axil_bready = Signal(bool(0))
    m_axil_araddr = Signal(intbv(0)[AXI_ADDR_WIDTH:])
    m_axil_arprot = Signal(intbv(2)[3:])
    m_axil_arvalid = Signal(bool(0))
    m_axil_rready = Signal(bool(0))
    status_error_cor = Signal(bool(0))
    status_error_uncor = Signal(bool(0))

    # sources and sinks
    cq_source = pcie_us.CQSource()

    cq_source_logic = cq_source.create_logic(
        clk,
        rst,
        tdata=s_axis_cq_tdata,
        tkeep=s_axis_cq_tkeep,
        tvalid=s_axis_cq_tvalid,
        tready=s_axis_cq_tready,
        tlast=s_axis_cq_tlast,
        tuser=s_axis_cq_tuser,
        name='cq_source'
    )

    cc_sink = pcie_us.CCSink()

    cc_sink_logic = cc_sink.create_logic(
        clk,
        rst,
        tdata=m_axis_cc_tdata,
        tkeep=m_axis_cc_tkeep,
        tvalid=m_axis_cc_tvalid,
        tready=m_axis_cc_tready,
        tlast=m_axis_cc_tlast,
        tuser=m_axis_cc_tuser,
        name='cc_sink'
    )

    # AXI4-Lite RAM model
    axil_ram_inst = axil.AXILiteRam(2**16)

    axil_ram_port0 = axil_ram_inst.create_port(
        clk,
        s_axil_awaddr=m_axil_awaddr,
        s_axil_awprot=m_axil_awprot,
        s_axil_awvalid=m_axil_awvalid,
        s_axil_awready=m_axil_awready,
        s_axil_wdata=m_axil_wdata,
        s_axil_wstrb=m_axil_wstrb,
        s_axil_wvalid=m_axil_wvalid,
        s_axil_wready=m_axil_wready,
        s_axil_bresp=m_axil_bresp,
        s_axil_bvalid=m_axil_bvalid,
        s_axil_bready=m_axil_bready,
        s_axil_araddr=m_axil_araddr,
        s_axil_arprot=m_axil_arprot,
        s_axil_arvalid=m_axil_arvalid,
        s_axil_arready=m_axil_arready,
        s_axil_rdata=m_axil_rdata,
        s_axil_rresp=m_axil_rresp,
        s_axil_rvalid=m_axil_rvalid,
        s_axil_rready=m_axil_rready,
        latency=1,
        name='ram'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,

        s_axis_cq_tdata=s_axis_cq_tdata,
        s_axis_cq_tkeep=s_axis_cq_tkeep,
        s_axis_cq_tvalid=s_axis_cq_tvalid,
        s_axis_cq_tready=s_axis_cq_tready,
        s_axis_cq_tlast=s_axis_cq_tlast,
        s_axis_cq_tuser=s_axis_cq_tuser,

        m_axis_cc_tdata=m_axis_cc_tdata,
        m_axis_cc_tkeep=m_axis_cc_tkeep,
        m_axis_cc_tvalid=m_axis_cc_tvalid,
        m_axis_cc_tready=m_axis_cc_tready,
        m_axis_cc_tlast=m_axis_cc_tlast,
        m_axis_cc_tuser=m_axis_cc_tuser,

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
        m_axil_rready=m_axil_rready,

        completer_id=completer_id,
        completer_id_enable=completer_id_enable,

        status_error_cor=status_error_cor,
        status_error_uncor=status_error_uncor
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    status_error_cor_asserted = Signal(bool(0))
    status_error_uncor_asserted = Signal(bool(0))

    @always(clk.posedge)
    def monitor():
        if (status_error_cor):
            status_error_cor_asserted.next = 1
        if (status_error_uncor):
            status_error_uncor_asserted.next = 1

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

        cur_tag = 1

        completer_id.next = int(pcie_us.PcieId(4, 5, 6))

        yield clk.posedge
        print("test 1: baseline")
        current_test.next = 1

        data = axil_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        yield delay(100)

        yield clk.posedge
        print("test 2: memory write")
        current_test.next = 2

        tlp = pcie_us.TLP_us()
        tlp.fmt_type = pcie_us.TLP_MEM_WRITE
        tlp.requester_id = pcie_us.PcieId(1, 2, 3)
        tlp.tag = cur_tag
        tlp.tc = 0
        tlp.set_be_data(0x0000, b'\x11\x22\x33\x44')
        tlp.address = 0x0000

        cq_source.send(tlp.pack_us_cq())

        yield delay(100)

        data = axil_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axil_ram_inst.read_mem(0, 4) == b'\x11\x22\x33\x44'

        assert not status_error_cor_asserted
        assert not status_error_uncor_asserted

        cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        yield clk.posedge
        print("test 3: IO write")
        current_test.next = 3

        tlp = pcie_us.TLP_us()
        tlp.fmt_type = pcie_us.TLP_IO_WRITE
        tlp.requester_id = pcie_us.PcieId(1, 2, 3)
        tlp.tag = cur_tag
        tlp.tc = 0
        tlp.set_be_data(0x0000, b'\x11\x22\x33\x44')
        tlp.address = 0x0000

        cq_source.send(tlp.pack_us_cq())

        yield cc_sink.wait(500)
        pkt = cc_sink.recv()

        rx_tlp = pcie_us.TLP_us().unpack_us_cc(pkt)

        print(rx_tlp)

        assert rx_tlp.status == pcie_us.CPL_STATUS_SC
        assert rx_tlp.tag == cur_tag
        assert rx_tlp.completer_id == pcie_us.PcieId(4, 5, 6)

        data = axil_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axil_ram_inst.read_mem(0, 4) == b'\x11\x22\x33\x44'

        assert not status_error_cor_asserted
        assert not status_error_uncor_asserted

        cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        yield clk.posedge
        print("test 4: memory read")
        current_test.next = 4

        tlp = pcie_us.TLP_us()
        tlp.fmt_type = pcie_us.TLP_MEM_READ
        tlp.requester_id = pcie_us.PcieId(1, 2, 3)
        tlp.tag = cur_tag
        tlp.tc = 0
        tlp.length = 1
        tlp.set_be(0x0000, 4)
        tlp.address = 0x0000

        cq_source.send(tlp.pack_us_cq())

        yield cc_sink.wait(500)
        pkt = cc_sink.recv()

        rx_tlp = pcie_us.TLP_us().unpack_us_cc(pkt)

        print(rx_tlp)

        data = rx_tlp.get_data()

        print(data)

        assert data == b'\x11\x22\x33\x44'
        assert rx_tlp.status == pcie_us.CPL_STATUS_SC
        assert rx_tlp.tag == cur_tag
        assert rx_tlp.completer_id == pcie_us.PcieId(4, 5, 6)

        assert not status_error_cor_asserted
        assert not status_error_uncor_asserted

        cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        yield clk.posedge
        print("test 5: IO read")
        current_test.next = 5

        tlp = pcie_us.TLP_us()
        tlp.fmt_type = pcie_us.TLP_IO_READ
        tlp.requester_id = pcie_us.PcieId(1, 2, 3)
        tlp.tag = cur_tag
        tlp.tc = 0
        tlp.length = 1
        tlp.set_be(0x0000, 4)
        tlp.address = 0x0000

        cq_source.send(tlp.pack_us_cq())

        yield cc_sink.wait(500)
        pkt = cc_sink.recv()

        rx_tlp = pcie_us.TLP_us().unpack_us_cc(pkt)

        print(rx_tlp)

        data = rx_tlp.get_data()

        print(data)

        assert data == b'\x11\x22\x33\x44'
        assert rx_tlp.status == pcie_us.CPL_STATUS_SC
        assert rx_tlp.tag == cur_tag
        assert rx_tlp.completer_id == pcie_us.PcieId(4, 5, 6)

        assert not status_error_cor_asserted
        assert not status_error_uncor_asserted

        cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        yield clk.posedge
        print("test 6: various writes")
        current_test.next = 6

        for length in range(1,5):
            for offset in range(4,8-length+1):
                axil_ram_inst.write_mem(256*(16*offset+length), b'\xAA'*32)

                tlp = pcie_us.TLP_us()
                tlp.fmt_type = pcie_us.TLP_MEM_WRITE
                tlp.requester_id = pcie_us.PcieId(1, 2, 3)
                tlp.tag = cur_tag
                tlp.tc = 0
                tlp.set_be_data(256*(16*offset+length)+offset, b'\x11\x22\x33\x44'[0:length])
                tlp.address = 256*(16*offset+length)+offset

                cq_source.send(tlp.pack_us_cq())

                yield delay(100)

                data = axil_ram_inst.read_mem(256*(16*offset+length), 32)
                for i in range(0, len(data), 16):
                    print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                assert axil_ram_inst.read_mem(256*(16*offset+length)+offset, length) == b'\x11\x22\x33\x44'[0:length]
                assert axil_ram_inst.read_mem(256*(16*offset+length)+offset-1, 1) == b'\xAA'
                assert axil_ram_inst.read_mem(256*(16*offset+length)+offset+length, 1) == b'\xAA'

                assert not status_error_cor_asserted
                assert not status_error_uncor_asserted

                cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        yield clk.posedge
        print("test 7: various reads")
        current_test.next = 7

        for length in range(1,5):
            for offset in range(4,8-length+1):
                tlp = pcie_us.TLP_us()
                tlp.fmt_type = pcie_us.TLP_MEM_READ
                tlp.requester_id = pcie_us.PcieId(1, 2, 3)
                tlp.tag = cur_tag
                tlp.tc = 0
                tlp.length = 1
                tlp.set_be(256*(16*offset+length)+offset, length)
                tlp.address = 256*(16*offset+length)+offset

                cq_source.send(tlp.pack_us_cq())

                yield cc_sink.wait(500)
                pkt = cc_sink.recv()

                rx_tlp = pcie_us.TLP_us().unpack_us_cc(pkt)

                print(rx_tlp)

                data = rx_tlp.get_data()

                print(data)

                assert data == b'\xAA'*(offset-4)+b'\x11\x22\x33\x44'[0:length]+b'\xAA'*(8-offset-length)
                assert rx_tlp.status == pcie_us.CPL_STATUS_SC
                assert rx_tlp.tag == cur_tag
                assert rx_tlp.completer_id == pcie_us.PcieId(4, 5, 6)

                assert not status_error_cor_asserted
                assert not status_error_uncor_asserted

                cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        yield clk.posedge
        print("test 8: bad memory write")
        current_test.next = 8

        tlp = pcie_us.TLP_us()
        tlp.fmt_type = pcie_us.TLP_MEM_WRITE
        tlp.requester_id = pcie_us.PcieId(1, 2, 3)
        tlp.tag = cur_tag
        tlp.tc = 0
        tlp.set_be_data(0x0000, bytearray(range(64)))
        tlp.address = 0x0000

        cq_source.send(tlp.pack_us_cq())

        yield delay(100)

        assert not status_error_cor_asserted
        assert status_error_uncor_asserted

        status_error_uncor_asserted.next = 0

        cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        yield clk.posedge
        print("test 9: bad memory read")
        current_test.next = 9

        tlp = pcie_us.TLP_us()
        tlp.fmt_type = pcie_us.TLP_MEM_READ
        tlp.requester_id = pcie_us.PcieId(1, 2, 3)
        tlp.tag = cur_tag
        tlp.tc = 0
        tlp.set_be(0x0000, 64)
        tlp.address = 0x0000

        cq_source.send(tlp.pack_us_cq())

        yield cc_sink.wait(500)
        pkt = cc_sink.recv()

        rx_tlp = pcie_us.TLP_us().unpack_us_cc(pkt)

        print(rx_tlp)

        assert rx_tlp.status == pcie_us.CPL_STATUS_CA
        assert rx_tlp.tag == cur_tag
        assert rx_tlp.completer_id == pcie_us.PcieId(4, 5, 6)

        assert status_error_cor_asserted
        assert not status_error_uncor_asserted

        cur_tag = (cur_tag + 1) % 32

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
