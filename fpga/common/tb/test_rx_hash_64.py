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
import ipaddress

import axis_ep
import eth_ep
import ip_ep
import udp_ep

module = 'rx_hash'
testbench = 'test_%s_64' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def hash_toep(data, key):
    k = len(key)*8-32
    key = int.from_bytes(key, 'big')

    h = 0

    for b in data:
        for i in range(8):
            if b & 0x80 >> i:
                h ^= (key >> k) & 0xffffffff
            k -= 1

    return h

def tuple_pack(src_ip, dest_ip, src_port=None, dest_port=None):
    src_ip = ipaddress.ip_address(src_ip)
    dest_ip = ipaddress.ip_address(dest_ip)
    if src_ip.version == 6 or dest_ip.version == 6:
        src_ip = int(src_ip).to_bytes(16, 'big')
        dest_ip = int(dest_ip).to_bytes(16, 'big')
    else:
        src_ip = int(src_ip).to_bytes(4, 'big')
        dest_ip = int(dest_ip).to_bytes(4, 'big')
    data = src_ip+dest_ip
    if src_port is not None and dest_port is not None:
        data += src_port.to_bytes(2, 'big') + dest_port.to_bytes(2, 'big')
    return data

def bench():

    # Parameters
    DATA_WIDTH = 64
    KEEP_WIDTH = (DATA_WIDTH/8)

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_tdata = Signal(intbv(0)[DATA_WIDTH:])
    s_axis_tkeep = Signal(intbv(0)[KEEP_WIDTH:])
    s_axis_tvalid = Signal(bool(0))
    s_axis_tlast = Signal(bool(0))
    hash_key = Signal(intbv(0)[40*8:])

    # Outputs
    m_axis_hash = Signal(intbv(0)[32:])
    m_axis_hash_type = Signal(intbv(0)[4:])
    m_axis_hash_valid = Signal(bool(0))

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
        tdata=(m_axis_hash, m_axis_hash_type),
        tvalid=m_axis_hash_valid,
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
        hash_key=hash_key,
        m_axis_hash=m_axis_hash,
        m_axis_hash_type=m_axis_hash_type,
        m_axis_hash_valid=m_axis_hash_valid
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

        key = [0x6d, 0x5a, 0x56, 0xda, 0x25, 0x5b, 0x0e, 0xc2,
            0x41, 0x67, 0x25, 0x3d, 0x43, 0xa3, 0x8f, 0xb0,
            0xd0, 0xca, 0x2b, 0xcb, 0xae, 0x7b, 0x30, 0xb4,
            0x77, 0xcb, 0x2d, 0xa3, 0x80, 0x30, 0xf2, 0x0c,
            0x6a, 0x42, 0xb7, 0x3b, 0xbe, 0xac, 0x01, 0xfa]

        hash_key.next = int.from_bytes(key, 'big')

        for payload_len in list(range(1, 128)) + list([1024, 1500, 9000, 9214]):
            yield clk.posedge
            print("test 1: test raw ethernet frame, length %d" % payload_len)
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
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                assert rx_hash[1] == 0b0000

                assert sink.empty()

                yield delay(100)

            yield clk.posedge
            print("test 2: test raw IP frame, length %d" % payload_len)
            current_test.next = 2

            test_frame = ip_ep.IPFrame()
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
            test_frame.ip_protocol = 0x1
            test_frame.ip_header_checksum = None
            test_frame.ip_source_ip = 0xc0a80164
            test_frame.ip_dest_ip = 0xc0a80165
            test_frame.payload = bytearray((x%256 for x in range(payload_len)))

            axis_frame = test_frame.build_axis()

            for wait in wait_normal, wait_pause_source:
                source.send(axis_frame)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                h = hash_toep(tuple_pack(test_frame.ip_source_ip, test_frame.ip_dest_ip), key)
                print(hex(h))

                assert rx_hash[0] == h
                assert rx_hash[1] == 0b0001

                assert sink.empty()

                yield delay(100)

            yield clk.posedge
            print("test 3: test UDP frame, length %d" % payload_len)
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

            axis_frame = test_frame.build_axis()

            for wait in wait_normal, wait_pause_source:
                source.send(axis_frame)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                h = hash_toep(tuple_pack(test_frame.ip_source_ip, test_frame.ip_dest_ip, test_frame.udp_source_port, test_frame.udp_dest_port), key)
                print(hex(h))

                assert rx_hash[0] == h
                assert rx_hash[1] == 0b1001

                assert sink.empty()

                yield delay(100)

            yield clk.posedge
            print("test 4: test TCP frame, length %d" % payload_len)
            current_test.next = 4

            test_frame = ip_ep.IPFrame()
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
            test_frame.ip_protocol = 0x6
            test_frame.ip_header_checksum = None
            test_frame.ip_source_ip = 0xc0a80164
            test_frame.ip_dest_ip = 0xc0a80165
            test_frame.payload = b'\x12\x34\x43\x21'+bytearray((x%256 for x in range(payload_len)))

            axis_frame = test_frame.build_axis()

            for wait in wait_normal, wait_pause_source:
                source.send(axis_frame)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                h = hash_toep(tuple_pack(test_frame.ip_source_ip, test_frame.ip_dest_ip, 0x1234, 0x4321), key)
                print(hex(h))

                assert rx_hash[0] == h
                assert rx_hash[1] == 0b0101

                assert sink.empty()

                yield delay(100)

            yield clk.posedge
            print("test 5: back-to-back frames, length %d" % payload_len)
            current_test.next = 5

            test_frame1 = eth_ep.EthFrame()
            test_frame1.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame1.eth_src_mac = 0x5A5152535455
            test_frame1.eth_type = 0x8000
            test_frame1.payload = bytearray((x%256 for x in range(payload_len)))

            test_frame2 = ip_ep.IPFrame()
            test_frame2.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame2.eth_src_mac = 0x5A5152535455
            test_frame2.eth_type = 0x0800
            test_frame2.ip_version = 4
            test_frame2.ip_ihl = 5
            test_frame2.ip_length = None
            test_frame2.ip_identification = 0
            test_frame2.ip_flags = 2
            test_frame2.ip_fragment_offset = 0
            test_frame2.ip_ttl = 64
            test_frame2.ip_protocol = 0x1
            test_frame2.ip_header_checksum = None
            test_frame2.ip_source_ip = 0xc0a80164
            test_frame2.ip_dest_ip = 0xc0a80165
            test_frame2.payload = bytearray((x%256 for x in range(payload_len)))

            test_frame3 = udp_ep.UDPFrame()
            test_frame3.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame3.eth_src_mac = 0x5A5152535455
            test_frame3.eth_type = 0x0800
            test_frame3.ip_version = 4
            test_frame3.ip_ihl = 5
            test_frame3.ip_length = None
            test_frame3.ip_identification = 0
            test_frame3.ip_flags = 2
            test_frame3.ip_fragment_offset = 0
            test_frame3.ip_ttl = 64
            test_frame3.ip_protocol = 0x11
            test_frame3.ip_header_checksum = None
            test_frame3.ip_source_ip = 0xc0a80164
            test_frame3.ip_dest_ip = 0xc0a80165
            test_frame3.udp_source_port = 1
            test_frame3.udp_dest_port = 2
            test_frame3.udp_length = None
            test_frame3.udp_checksum = None
            test_frame3.payload = bytearray((x%256 for x in range(payload_len)))

            test_frame4 = ip_ep.IPFrame()
            test_frame4.eth_dest_mac = 0xDAD1D2D3D4D5
            test_frame4.eth_src_mac = 0x5A5152535455
            test_frame4.eth_type = 0x0800
            test_frame4.ip_version = 4
            test_frame4.ip_ihl = 5
            test_frame4.ip_length = None
            test_frame4.ip_identification = 0
            test_frame4.ip_flags = 2
            test_frame4.ip_fragment_offset = 0
            test_frame4.ip_ttl = 64
            test_frame4.ip_protocol = 0x6
            test_frame4.ip_header_checksum = None
            test_frame4.ip_source_ip = 0xc0a80164
            test_frame4.ip_dest_ip = 0xc0a80165
            test_frame4.payload = b'\x12\x34\x43\x21'+bytearray((x%256 for x in range(payload_len)))

            axis_frame1 = test_frame1.build_axis()
            axis_frame2 = test_frame2.build_axis()
            axis_frame3 = test_frame3.build_axis()
            axis_frame4 = test_frame4.build_axis()

            for wait in wait_normal, wait_pause_source:
                source.send(axis_frame1)
                source.send(axis_frame2)
                source.send(axis_frame3)
                source.send(axis_frame4)
                yield clk.posedge
                yield clk.posedge

                yield wait()

                yield sink.wait()
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                assert rx_hash[1] == 0b0000

                yield sink.wait()
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                h = hash_toep(tuple_pack(test_frame2.ip_source_ip, test_frame2.ip_dest_ip), key)
                print(hex(h))

                assert rx_hash[0] == h
                assert rx_hash[1] == 0b0001

                yield sink.wait()
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                h = hash_toep(tuple_pack(test_frame3.ip_source_ip, test_frame3.ip_dest_ip, test_frame3.udp_source_port, test_frame3.udp_dest_port), key)
                print(hex(h))

                assert rx_hash[0] == h
                assert rx_hash[1] == 0b1001

                yield sink.wait()
                rx_hash = sink.recv().data[0]
                print(rx_hash)

                h = hash_toep(tuple_pack(test_frame4.ip_source_ip, test_frame4.ip_dest_ip, 0x1234, 0x4321), key)
                print(hex(h))

                assert rx_hash[0] == h
                assert rx_hash[1] == 0b0101

                assert sink.empty()

                yield delay(100)

        yield clk.posedge
        print("test 6: hash test")
        current_test.next = 6

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
        test_frame.ip_source_ip = 0x420995bb
        test_frame.ip_dest_ip = 0xa18e6450
        test_frame.udp_source_port = 2794
        test_frame.udp_dest_port = 1766
        test_frame.udp_length = None
        test_frame.udp_checksum = None
        test_frame.payload = bytearray((x%256 for x in range(128)))

        axis_frame = test_frame.build_axis()

        for wait in wait_normal, wait_pause_source:
            source.send(axis_frame)
            yield clk.posedge
            yield clk.posedge

            yield wait()

            yield sink.wait()
            rx_hash = sink.recv().data[0]
            print(rx_hash)

            h = hash_toep(tuple_pack(test_frame.ip_source_ip, test_frame.ip_dest_ip, test_frame.udp_source_port, test_frame.udp_dest_port), key)
            print(hex(h))

            assert rx_hash[0] == h
            assert rx_hash[1] == 0b1001
            assert h == 0x51ccc178

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
