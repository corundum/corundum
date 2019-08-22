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

import struct

import axis_ep
import eth_ep
import udp_ep

module = 'tx_checksum'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../lib/axis/rtl/axis_fifo.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def frame_checksum(frame, offset=14):
    data = bytearray()
    if isinstance(frame, eth_ep.EthFrame):
        data = frame.payload.data[offset-14:]
    elif isinstance(frame, axis_ep.AXIStreamFrame):
        data = frame.data[offset:]
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
    ID_ENABLE = 0
    ID_WIDTH = 8
    DEST_ENABLE = 0
    DEST_WIDTH = 8
    USER_ENABLE = 1
    USER_WIDTH = 1
    USE_INIT_VALUE = 1
    DATA_FIFO_DEPTH = 4096
    CHECKSUM_FIFO_DEPTH = 4

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_tdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axis_tkeep = Signal(intbv(0)[KEEP_WIDTH:])
    s_axis_tvalid = Signal(bool(0))
    s_axis_tlast = Signal(bool(0))
    s_axis_tid = Signal(intbv(0)[ID_WIDTH:])
    s_axis_tdest = Signal(intbv(0)[DEST_WIDTH:])
    s_axis_tuser = Signal(intbv(0)[USER_WIDTH:])
    m_axis_tready = Signal(bool(0))
    s_axis_cmd_csum_enable = Signal(bool(0))
    s_axis_cmd_csum_start = Signal(intbv(0)[8:])
    s_axis_cmd_csum_offset = Signal(intbv(0)[8:])
    s_axis_cmd_csum_init = Signal(intbv(0)[16:])
    s_axis_cmd_valid = Signal(bool(0))

    # Outputs
    s_axis_tready = Signal(bool(0))
    m_axis_tdata = Signal(intbv(0)[DATA_WIDTH:])
    m_axis_tkeep = Signal(intbv(0)[KEEP_WIDTH:])
    m_axis_tvalid = Signal(bool(0))
    m_axis_tlast = Signal(bool(0))
    m_axis_tid = Signal(intbv(0)[ID_WIDTH:])
    m_axis_tdest = Signal(intbv(0)[DEST_WIDTH:])
    m_axis_tuser = Signal(intbv(0)[USER_WIDTH:])
    s_axis_cmd_ready = Signal(bool(1))

    # sources and sinks
    source_pause = Signal(bool(0))
    sink_pause = Signal(bool(0))

    source = axis_ep.AXIStreamSource()

    source_logic = source.create_logic(
        clk,
        rst,
        tdata=s_axis_tdata,
        tkeep=s_axis_tkeep,
        tvalid=s_axis_tvalid,
        tready=s_axis_tready,
        tlast=s_axis_tlast,
        tuser=s_axis_tuser,
        pause=source_pause,
        name='source'
    )

    cmd_source = axis_ep.AXIStreamSource()

    cmd_source_logic = cmd_source.create_logic(
        clk,
        rst,
        tdata=(s_axis_cmd_csum_enable, s_axis_cmd_csum_start, s_axis_cmd_csum_offset, s_axis_cmd_csum_init),
        tvalid=s_axis_cmd_valid,
        tready=s_axis_cmd_ready,
        name='cmd_source'
    )

    sink = axis_ep.AXIStreamSink()

    sink_logic = sink.create_logic(
        clk,
        rst,
        tdata=m_axis_tdata,
        tkeep=m_axis_tkeep,
        tvalid=m_axis_tvalid,
        tready=m_axis_tready,
        tlast=m_axis_tlast,
        tuser=m_axis_tuser,
        pause=sink_pause,
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
        s_axis_tready=s_axis_tready,
        s_axis_tlast=s_axis_tlast,
        s_axis_tid=s_axis_tid,
        s_axis_tdest=s_axis_tdest,
        s_axis_tuser=s_axis_tuser,
        m_axis_tdata=m_axis_tdata,
        m_axis_tkeep=m_axis_tkeep,
        m_axis_tvalid=m_axis_tvalid,
        m_axis_tready=m_axis_tready,
        m_axis_tlast=m_axis_tlast,
        m_axis_tid=m_axis_tid,
        m_axis_tdest=m_axis_tdest,
        m_axis_tuser=m_axis_tuser,
        s_axis_cmd_csum_enable=s_axis_cmd_csum_enable,
        s_axis_cmd_csum_start=s_axis_cmd_csum_start,
        s_axis_cmd_csum_offset=s_axis_cmd_csum_offset,
        s_axis_cmd_csum_init=s_axis_cmd_csum_init,
        s_axis_cmd_valid=s_axis_cmd_valid,
        s_axis_cmd_ready=s_axis_cmd_ready
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    def wait_normal():
        while s_axis_tvalid:
            yield clk.posedge

    def wait_pause_source():
        while s_axis_tvalid or m_axis_tvalid:
            yield clk.posedge
            yield clk.posedge
            source_pause.next = False
            yield clk.posedge
            source_pause.next = True
            yield clk.posedge

        source_pause.next = False

    def wait_pause_sink():
        while s_axis_tvalid or m_axis_tvalid:
            yield clk.posedge
            yield clk.posedge
            sink_pause.next = False
            yield clk.posedge
            sink_pause.next = True
            yield clk.posedge

        sink_pause.next = False

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

        for payload_len in list(range(1, 128)) + list([1024, 1500]):
            yield clk.posedge
            print("test 1: test packet, length %d" % payload_len)
            current_test.next = 1

            test_frame = eth_ep.EthFrame()
            test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame.eth_src_mac = 0x5A5152535455
            test_frame.eth_type = 0x8000
            test_frame.payload = bytearray((x%256 for x in range(payload_len)))

            axis_frame = test_frame.build_axis()
            cmd_frame = [(False, 0, 0, 0)]

            for wait in wait_normal, wait_pause_source, wait_pause_sink:
                source.send(axis_frame)
                cmd_source.send(cmd_frame)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_frame = sink.recv()

                check_frame = eth_ep.EthFrame()
                check_frame.parse_axis(rx_frame)

                assert check_frame == test_frame

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
            cmd_frame1 = [(False, 0, 0, 0)]
            axis_frame2 = test_frame2.build_axis()
            cmd_frame2 = [(False, 0, 0, 0)]

            for wait in wait_normal, wait_pause_source, wait_pause_sink:
                source.send(axis_frame1)
                cmd_source.send(cmd_frame1)
                source.send(axis_frame2)
                cmd_source.send(cmd_frame2)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_frame = sink.recv()

                check_frame = eth_ep.EthFrame()
                check_frame.parse_axis(rx_frame)

                assert check_frame == test_frame1

                yield sink.wait()
                rx_frame = sink.recv()

                check_frame = eth_ep.EthFrame()
                check_frame.parse_axis(rx_frame)

                assert check_frame == test_frame2

                assert sink.empty()

                yield delay(100)

            yield clk.posedge
            print("test 3: test UDP packet with zero checksum, length %d" % payload_len)
            current_test.next = 3

            test_frame = udp_ep.UDPFrame()
            test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame.eth_src_mac = 0x5A5152535455
            test_frame.eth_type = 0x0800
            test_frame.ip_version = 4
            test_frame.ip_ihl = 5
            test_frame.ip_length = None
            test_frame.ip_identification = 0
            test_frame.ip_flags = 2
            test_frame.ip_fragment_offset = 0
            test_frame.ip_ttl = 64
            test_frame.ip_protocol = 0x11
            test_frame.ip_header_checksum = None
            test_frame.ip_source_ip = 0xc0a80164
            test_frame.ip_dest_ip = 0xc0a80165
            test_frame.udp_source_port = 1
            test_frame.udp_dest_port = 2
            test_frame.udp_length = None
            test_frame.udp_checksum = None
            test_frame.payload = bytearray((x%256 for x in range(payload_len)))

            test_frame.update_udp_length()
            test_frame.udp_checksum = 0
            pseudo_header_checksum = test_frame.calc_udp_pseudo_header_checksum()

            axis_frame = test_frame.build_axis()
            cmd_frame = [(True, 34, 40, pseudo_header_checksum)]

            for wait in wait_normal, wait_pause_source, wait_pause_sink:
                source.send(axis_frame)
                cmd_source.send(cmd_frame)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_frame = sink.recv()

                check_frame = udp_ep.UDPFrame()
                check_frame.parse_axis(rx_frame)

                print(hex(check_frame.udp_checksum))
                print(hex(check_frame.calc_udp_checksum()))

                assert check_frame.verify_checksums()

                assert sink.empty()

                yield delay(100)

            yield clk.posedge
            print("test 4: test UDP packet with inline pseudo header checksum, length %d" % payload_len)
            current_test.next = 4

            test_frame = udp_ep.UDPFrame()
            test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame.eth_src_mac = 0x5A5152535455
            test_frame.eth_type = 0x0800
            test_frame.ip_version = 4
            test_frame.ip_ihl = 5
            test_frame.ip_length = None
            test_frame.ip_identification = 0
            test_frame.ip_flags = 2
            test_frame.ip_fragment_offset = 0
            test_frame.ip_ttl = 64
            test_frame.ip_protocol = 0x11
            test_frame.ip_header_checksum = None
            test_frame.ip_source_ip = 0xc0a80164
            test_frame.ip_dest_ip = 0xc0a80165
            test_frame.udp_source_port = 1
            test_frame.udp_dest_port = 2
            test_frame.udp_length = None
            test_frame.udp_checksum = None
            test_frame.payload = bytearray((x%256 for x in range(payload_len)))

            test_frame.set_udp_pseudo_header_checksum()

            axis_frame = test_frame.build_axis()
            cmd_frame = [(True, 34, 40, 0)]

            for wait in wait_normal, wait_pause_source, wait_pause_sink:
                source.send(axis_frame)
                cmd_source.send(cmd_frame)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_frame = sink.recv()

                check_frame = udp_ep.UDPFrame()
                check_frame.parse_axis(rx_frame)

                print(hex(check_frame.udp_checksum))
                print(hex(check_frame.calc_udp_checksum()))

                assert check_frame.verify_checksums()

                assert sink.empty()

                yield delay(100)

            for start in list(range(0, min(payload_len+14, 64))):
                offset = 0
                yield clk.posedge
                print("test 5: test various offsets, length %d, start %d, offset %d" % (payload_len, start, offset))
                current_test.next = 5

                test_frame = eth_ep.EthFrame()
                test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
                test_frame.eth_src_mac = 0x5A5152535455
                test_frame.eth_type = 0x8000
                test_frame.payload = bytearray((x%256 for x in range(payload_len)))

                axis_frame = test_frame.build_axis()
                cmd_frame = [(True, start, offset, 0)]

                for wait in wait_normal, wait_pause_source, wait_pause_sink:
                    source.send(axis_frame)
                    cmd_source.send(cmd_frame)
                    yield clk.posedge
                    yield clk.posedge

                    yield wait()

                    yield sink.wait()
                    rx_frame = sink.recv()

                    csum = ~frame_checksum(axis_frame, start) & 0xffff
                    print(hex(csum))

                    check_data = axis_frame.data
                    struct.pack_into('>H', check_data, offset, csum)

                    print(check_data)
                    print(rx_frame.data)

                    yield delay(100)

                    assert check_data == rx_frame.data

                    assert sink.empty()

                    yield delay(100)

            for offset in list(range(0, min(payload_len+14, 64)-1)):
                start = 0
                yield clk.posedge
                print("test 6: test various offsets, length %d, start %d, offset %d" % (payload_len, start, offset))
                current_test.next = 6

                test_frame = eth_ep.EthFrame()
                test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
                test_frame.eth_src_mac = 0x5A5152535455
                test_frame.eth_type = 0x8000
                test_frame.payload = bytearray((x%256 for x in range(payload_len)))

                axis_frame = test_frame.build_axis()
                cmd_frame = [(True, start, offset, 0)]

                for wait in wait_normal, wait_pause_source, wait_pause_sink:
                    source.send(axis_frame)
                    cmd_source.send(cmd_frame)
                    yield clk.posedge
                    yield clk.posedge

                    yield wait()

                    yield sink.wait()
                    rx_frame = sink.recv()

                    csum = ~frame_checksum(axis_frame, start) & 0xffff
                    print(hex(csum))

                    check_data = axis_frame.data
                    struct.pack_into('>H', check_data, offset, csum)

                    print(check_data)
                    print(rx_frame.data)

                    assert check_data == rx_frame.data

                    assert sink.empty()

                    yield delay(100)

        yield clk.posedge
        print("test 7: backpressure test")
        current_test.next = 7

        test_frame = eth_ep.EthFrame()
        test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
        test_frame.eth_src_mac = 0x5A5152535455
        test_frame.eth_type = 0x8000
        test_frame.payload = bytearray((x%256 for x in range(64)))

        axis_frame = test_frame.build_axis()
        cmd_frame = [(False, 0, 0, 0)]

        sink_pause.next = 1

        for k in range(10):
            source.send(axis_frame)
            cmd_source.send(cmd_frame)
        yield clk.posedge
        yield clk.posedge

        yield delay(1000)

        sink_pause.next = 0

        for k in range(10):
            yield sink.wait()
            rx_frame = sink.recv()

            check_frame = eth_ep.EthFrame()
            check_frame.parse_axis(rx_frame)

            assert check_frame == test_frame

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
