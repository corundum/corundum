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

import dma_ram
import axis_ep

module = 'dma_client_axis_sink'
testbench = 'test_%s_512_64' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    SEG_COUNT = 4
    SEG_DATA_WIDTH = 128
    SEG_ADDR_WIDTH = 12
    SEG_BE_WIDTH = int(SEG_DATA_WIDTH/8)
    RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+(SEG_COUNT-1).bit_length()+(SEG_BE_WIDTH-1).bit_length()
    AXIS_DATA_WIDTH = 64
    AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8)
    AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8)
    AXIS_LAST_ENABLE = 1
    AXIS_ID_ENABLE = 0
    AXIS_ID_WIDTH = 8
    AXIS_DEST_ENABLE = 0
    AXIS_DEST_WIDTH = 8
    AXIS_USER_ENABLE = 1
    AXIS_USER_WIDTH = 1
    LEN_WIDTH = 20
    TAG_WIDTH = 8

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_write_desc_ram_addr = Signal(intbv(0)[RAM_ADDR_WIDTH:])
    s_axis_write_desc_len = Signal(intbv(0)[LEN_WIDTH:])
    s_axis_write_desc_tag = Signal(intbv(0)[TAG_WIDTH:])
    s_axis_write_desc_valid = Signal(bool(0))
    s_axis_write_data_tdata = Signal(intbv(0)[AXIS_DATA_WIDTH:])
    s_axis_write_data_tkeep = Signal(intbv(0)[AXIS_KEEP_WIDTH:])
    s_axis_write_data_tvalid = Signal(bool(0))
    s_axis_write_data_tlast = Signal(bool(0))
    s_axis_write_data_tid = Signal(intbv(0)[AXIS_ID_WIDTH:])
    s_axis_write_data_tdest = Signal(intbv(0)[AXIS_DEST_WIDTH:])
    s_axis_write_data_tuser = Signal(intbv(0)[AXIS_USER_WIDTH:])
    ram_wr_cmd_ready = Signal(intbv(0)[SEG_COUNT:])
    enable = Signal(bool(0))
    abort = Signal(bool(0))

    # Outputs
    s_axis_write_desc_ready = Signal(bool(0))
    m_axis_write_desc_status_len = Signal(intbv(0)[LEN_WIDTH:])
    m_axis_write_desc_status_tag = Signal(intbv(0)[TAG_WIDTH:])
    m_axis_write_desc_status_id = Signal(intbv(0)[AXIS_ID_WIDTH:])
    m_axis_write_desc_status_dest = Signal(intbv(0)[AXIS_DEST_WIDTH:])
    m_axis_write_desc_status_user = Signal(intbv(0)[AXIS_USER_WIDTH:])
    m_axis_write_desc_status_valid = Signal(bool(0))
    s_axis_write_data_tready = Signal(bool(0))
    ram_wr_cmd_be = Signal(intbv(0)[SEG_COUNT*SEG_BE_WIDTH:])
    ram_wr_cmd_addr = Signal(intbv(0)[SEG_COUNT*SEG_ADDR_WIDTH:])
    ram_wr_cmd_data = Signal(intbv(0)[SEG_COUNT*SEG_DATA_WIDTH:])
    ram_wr_cmd_valid = Signal(intbv(0)[SEG_COUNT:])

    # PCIe DMA RAM
    dma_ram_inst = dma_ram.PSDPRam(2**16)
    dma_ram_pause = Signal(bool(0))

    dma_ram_port0 = dma_ram_inst.create_write_ports(
        clk,
        ram_wr_cmd_be=ram_wr_cmd_be,
        ram_wr_cmd_addr=ram_wr_cmd_addr,
        ram_wr_cmd_data=ram_wr_cmd_data,
        ram_wr_cmd_valid=ram_wr_cmd_valid,
        ram_wr_cmd_ready=ram_wr_cmd_ready,
        pause=dma_ram_pause,
        name='port0'
    )

    # sources and sinks
    write_desc_source = axis_ep.AXIStreamSource()
    write_desc_source_pause = Signal(bool(False))

    write_desc_source_logic = write_desc_source.create_logic(
        clk,
        rst,
        tdata=(s_axis_write_desc_ram_addr, s_axis_write_desc_len, s_axis_write_desc_tag),
        tvalid=s_axis_write_desc_valid,
        tready=s_axis_write_desc_ready,
        pause=write_desc_source_pause,
        name='write_desc_source'
    )

    write_desc_status_sink = axis_ep.AXIStreamSink()

    write_desc_status_sink_logic = write_desc_status_sink.create_logic(
        clk,
        rst,
        tdata=(m_axis_write_desc_status_len, m_axis_write_desc_status_tag, m_axis_write_desc_status_id, m_axis_write_desc_status_dest, m_axis_write_desc_status_user),
        tvalid=m_axis_write_desc_status_valid,
        name='write_desc_status_sink'
    )

    write_data_source = axis_ep.AXIStreamSource()
    write_data_source_pause = Signal(bool(False))

    write_data_source_logic = write_data_source.create_logic(
        clk,
        rst,
        tdata=s_axis_write_data_tdata,
        tkeep=s_axis_write_data_tkeep,
        tvalid=s_axis_write_data_tvalid,
        tready=s_axis_write_data_tready,
        tlast=s_axis_write_data_tlast,
        tid=s_axis_write_data_tid,
        tdest=s_axis_write_data_tdest,
        tuser=s_axis_write_data_tuser,
        pause=write_data_source_pause,
        name='write_data_source'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        s_axis_write_desc_ram_addr=s_axis_write_desc_ram_addr,
        s_axis_write_desc_len=s_axis_write_desc_len,
        s_axis_write_desc_tag=s_axis_write_desc_tag,
        s_axis_write_desc_valid=s_axis_write_desc_valid,
        s_axis_write_desc_ready=s_axis_write_desc_ready,
        m_axis_write_desc_status_len=m_axis_write_desc_status_len,
        m_axis_write_desc_status_tag=m_axis_write_desc_status_tag,
        m_axis_write_desc_status_id=m_axis_write_desc_status_id,
        m_axis_write_desc_status_dest=m_axis_write_desc_status_dest,
        m_axis_write_desc_status_user=m_axis_write_desc_status_user,
        m_axis_write_desc_status_valid=m_axis_write_desc_status_valid,
        s_axis_write_data_tdata=s_axis_write_data_tdata,
        s_axis_write_data_tkeep=s_axis_write_data_tkeep,
        s_axis_write_data_tvalid=s_axis_write_data_tvalid,
        s_axis_write_data_tready=s_axis_write_data_tready,
        s_axis_write_data_tlast=s_axis_write_data_tlast,
        s_axis_write_data_tid=s_axis_write_data_tid,
        s_axis_write_data_tdest=s_axis_write_data_tdest,
        s_axis_write_data_tuser=s_axis_write_data_tuser,
        ram_wr_cmd_be=ram_wr_cmd_be,
        ram_wr_cmd_addr=ram_wr_cmd_addr,
        ram_wr_cmd_data=ram_wr_cmd_data,
        ram_wr_cmd_valid=ram_wr_cmd_valid,
        ram_wr_cmd_ready=ram_wr_cmd_ready,
        enable=enable,
        abort=abort
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    def wait_normal():
        while write_desc_status_sink.empty():
            yield clk.posedge

    def wait_pause_ram():
        while write_desc_status_sink.empty():
            dma_ram_pause.next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            dma_ram_pause.next = False
            yield clk.posedge

    def wait_pause_source():
        while write_desc_status_sink.empty():
            write_data_source_pause.next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            write_data_source_pause.next = False
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

        cur_tag = 1

        enable.next = 1

        yield clk.posedge
        print("test 1: write")
        current_test.next = 1

        addr = 0x00000000
        test_data = b'\x11\x22\x33\x44'

        write_desc_source.send([(addr, len(test_data), cur_tag)])
        write_data_source.send(axis_ep.AXIStreamFrame(test_data, id=cur_tag))

        yield write_desc_status_sink.wait(2000)

        status = write_desc_status_sink.recv()

        print(status)
        assert status.data[0][0] == len(test_data)
        assert status.data[0][1] == cur_tag
        assert status.data[0][2] == cur_tag

        data = dma_ram_inst.read_mem(addr, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert dma_ram_inst.read_mem(addr, len(test_data)) == test_data

        cur_tag = (cur_tag + 1) % 256

        yield delay(100)

        yield clk.posedge
        print("test 2: various writes")
        current_test.next = 2

        for length in list(range(1,66))+[128]:
            for offset in list(range(8,65,8))+list(range(4096-64,4096,8)):
                for diff in [-16, -2, -1, 0, 1, 2, 16]:
                    if length+diff < 1:
                        continue
                    for wait in wait_normal, wait_pause_ram, wait_pause_source:
                        print("length %d, offset %d, diff %d"% (length, offset, diff))
                        #addr = length * 0x100000000 + offset * 0x10000 + offset
                        addr = offset
                        test_data = bytearray([x%256 for x in range(length)])
                        test_data2 = bytearray([x%256 for x in range(length+diff)])

                        dma_ram_inst.write_mem(addr & 0xffff80, b'\xaa'*(len(test_data)+256))

                        write_desc_source.send([(addr, len(test_data), cur_tag)])
                        write_data_source.send(axis_ep.AXIStreamFrame(test_data2, id=cur_tag))

                        yield wait()
                        yield clk.posedge
                        yield clk.posedge

                        status = write_desc_status_sink.recv()

                        print(status)
                        assert status.data[0][0] == min(len(test_data), len(test_data2))
                        assert status.data[0][1] == cur_tag
                        assert status.data[0][2] == cur_tag

                        data = dma_ram_inst.read_mem(addr&0xfffff0, 64)
                        for i in range(0, len(data), 16):
                            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                        if len(test_data) <= len(test_data2):
                            assert dma_ram_inst.read_mem(addr-8, len(test_data)+16) == b'\xaa'*8+test_data+b'\xaa'*8
                        else:
                            assert dma_ram_inst.read_mem(addr-8, len(test_data2)+16) == b'\xaa'*8+test_data2+b'\xaa'*8

                        cur_tag = (cur_tag + 1) % 256

                        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
