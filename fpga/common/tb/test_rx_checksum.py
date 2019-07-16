#!/usr/bin/env python
"""

Copyright 2019, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

"""

from myhdl import *
import os

import axis_ep
import eth_ep

module = 'rx_checksum'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def frame_checksum(frame):
    data = bytearray()
    if isinstance(frame, eth_ep.EthFrame):
        data = frame.payload.data
    elif isinstance(frame, axis_ep.AXIStreamFrame):
        data = frame.data[14:]
    else:
        return None

    csum = 0
    odd = False

    for b in data:
        if odd:
            csum += b
        else:
            csum += b << 8
        odd = not odd

    csum = (csum & 0xffff) + (csum >> 16)
    csum = (csum & 0xffff) + (csum >> 16)

    return csum

def bench():

    # Parameters
    DATA_WIDTH = 256
    KEEP_WIDTH = (DATA_WIDTH/8)

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_tdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axis_tkeep = Signal(intbv(0)[KEEP_WIDTH:])
    s_axis_tvalid = Signal(bool(0))
    s_axis_tlast = Signal(bool(0))

    # Outputs
    m_axis_csum = Signal(intbv(0)[16:])
    m_axis_csum_valid = Signal(bool(0))

    # sources and sinks
    source_pause = Signal(bool(0))

    source = axis_ep.AXIStreamSource()

    source_logic = source.create_logic(
        clk,
        rst,
        tdata=s_axis_tdata,
        tkeep=s_axis_tkeep,
        tvalid=s_axis_tvalid,
        tlast=s_axis_tlast,
        pause=source_pause,
        name='source'
    )

    sink = axis_ep.AXIStreamSink()

    sink_logic = sink.create_logic(
        clk,
        rst,
        tdata=(m_axis_csum,),
        tvalid=m_axis_csum_valid,
        name='sink'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        s_axis_tdata=s_axis_tdata,
        s_axis_tkeep=s_axis_tkeep,
        s_axis_tvalid=s_axis_tvalid,
        s_axis_tlast=s_axis_tlast,
        m_axis_csum=m_axis_csum,
        m_axis_csum_valid=m_axis_csum_valid
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    def wait_normal():
        while s_axis_tvalid:
            yield clk.posedge

    def wait_pause_source():
        while s_axis_tvalid:
            yield clk.posedge
            yield clk.posedge
            source_pause.next = False
            yield clk.posedge
            source_pause.next = True
            yield clk.posedge

        source_pause.next = False

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

        for payload_len in list(range(1, 128)) + list([1024, 1500, 9000, 9214]):
            yield clk.posedge
            print("test 1: test packet, length %d" % payload_len)
            current_test.next = 1

            test_frame = eth_ep.EthFrame()
            test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame.eth_src_mac = 0x5A5152535455
            test_frame.eth_type = 0x8000
            test_frame.payload = bytearray((x%256 for x in range(payload_len)))

            axis_frame = test_frame.build_axis()

            for wait in wait_normal, wait_pause_source:
                source.send(axis_frame)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_csum = sink.recv().data[0][0]
                print(hex(rx_csum))

                csum = frame_checksum(test_frame)
                print(hex(csum))

                assert rx_csum == csum

                assert sink.empty()

                yield delay(100)

            yield clk.posedge
            print("test 2: back-to-back packets, length %d" % payload_len)
            current_test.next = 2

            test_frame1 = eth_ep.EthFrame()
            test_frame1.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame1.eth_src_mac = 0x5A5152535455
            test_frame1.eth_type = 0x8000
            test_frame1.payload = bytearray((x%256 for x in range(payload_len)))
            test_frame2 = eth_ep.EthFrame()
            test_frame2.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame2.eth_src_mac = 0x5A5152535455
            test_frame2.eth_type = 0x8000
            test_frame2.payload = bytearray((~x%256 for x in range(payload_len)))

            axis_frame1 = test_frame1.build_axis()
            axis_frame2 = test_frame2.build_axis()

            for wait in wait_normal, wait_pause_source:
                source.send(axis_frame1)
                source.send(axis_frame2)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_csum = sink.recv().data[0][0]
                print(hex(rx_csum))

                csum = frame_checksum(test_frame1)
                print(hex(csum))

                assert rx_csum == csum

                yield sink.wait()
                rx_csum = sink.recv().data[0][0]
                print(hex(rx_csum))

                csum = frame_checksum(test_frame2)
                print(hex(csum))

                assert rx_csum == csum

                assert sink.empty()

                yield delay(100)

        yield clk.posedge
        print("test 3: overflow test")
        current_test.next = 3

        axis_frame = axis_ep.AXIStreamFrame(bytearray([0xff]*10240))

        for wait in wait_normal, wait_pause_source:
            source.send(axis_frame)
            yield clk.posedge
            yield clk.posedge

            yield wait()

            yield sink.wait()
            rx_csum = sink.recv().data[0][0]
            print(hex(rx_csum))

            csum = frame_checksum(axis_frame)
            print(hex(csum))

            assert rx_csum == csum

            assert sink.empty()

            yield delay(100)

        yield clk.posedge
        print("test 4: checksum test")
        current_test.next = 4

        test_frame = eth_ep.EthFrame()
        test_frame.eth_dest_mac = 0xDA0203040506
        test_frame.eth_src_mac = 0xCA0203040506
        test_frame.eth_type = 0x005a
        test_frame.payload = b'\xab\xcd'+bytearray(range(20, 108))

        axis_frame = test_frame.build_axis()

        for wait in wait_normal, wait_pause_source:
            source.send(axis_frame)
            yield clk.posedge
            yield clk.posedge

            yield wait()

            yield sink.wait()
            rx_csum = sink.recv().data[0][0]
            print(hex(rx_csum))

            csum = frame_checksum(test_frame)
            print(hex(csum))

            assert csum == 0x8ad8
            assert rx_csum == csum

            assert sink.empty()

            yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
