#!/usr/bin/env python
"""

Copyright 2020, The Regents of the University of California.
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

import enum
import ipaddress
import itertools
import logging
import os

from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP, TCP

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource
from cocotbext.axi.stream import define_stream


HashBus, HashTransaction, HashSource, HashSink, HashMonitor = define_stream("Hash",
    signals=["hash", "hash_type", "hash_valid"]
)


class HashType(enum.IntFlag):
    IPV4 = 1
    IPV6 = 2
    TCP = 4
    UDP = 8


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
    data = b''
    if src_ip.version == 6 or dest_ip.version == 6:
        data += src_ip.packed
        data += dest_ip.packed
    else:
        data += src_ip.packed
        data += dest_ip.packed
    if src_port is not None and dest_port is not None:
        data += src_port.to_bytes(2, 'big') + dest_port.to_bytes(2, 'big')
    return data


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
        self.sink = HashSink(HashBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

        hash_key = [
            0x6d, 0x5a, 0x56, 0xda, 0x25, 0x5b, 0x0e, 0xc2,
            0x41, 0x67, 0x25, 0x3d, 0x43, 0xa3, 0x8f, 0xb0,
            0xd0, 0xca, 0x2b, 0xcb, 0xae, 0x7b, 0x30, 0xb4,
            0x77, 0xcb, 0x2d, 0xa3, 0x80, 0x30, 0xf2, 0x0c,
            0x6a, 0x42, 0xb7, 0x3b, 0xbe, 0xac, 0x01, 0xfa
        ]

        self.set_hash_key(hash_key)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_hash_key(self, key):
        self.hash_key = key
        self.dut.hash_key <= int.from_bytes(key, 'big')

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, pkt_type=Ether):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)

    test_pkts = []
    hash_info = []
    test_frames = []

    ip_id = 1

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
        if pkt_type == Ether:
            test_pkt = eth / payload
            hash_type = HashType(0)
            hash_val = 0
        else:
            ip = IP(src=f'10.1.0.{ip_id}', dst=f'10.2.0.{ip_id}', id=ip_id)
            if pkt_type == IP:
                test_pkt = eth / ip / payload
                hash_type = HashType.IPV4
                hash_val = hash_toep(tuple_pack(ip.src, ip.dst), tb.hash_key)
            elif pkt_type == UDP:
                udp = UDP(sport=ip_id, dport=0x1000+ip_id)
                test_pkt = eth / ip / udp / payload
                hash_type = HashType.IPV4 | HashType.UDP
                hash_val = hash_toep(tuple_pack(ip.src, ip.dst, udp.sport, udp.dport), tb.hash_key)
            elif pkt_type == TCP:
                tcp = TCP(sport=ip_id, dport=0x1000+ip_id)
                test_pkt = eth / ip / tcp / payload
                hash_type = HashType.IPV4 | HashType.TCP
                hash_val = hash_toep(tuple_pack(ip.src, ip.dst, tcp.sport, tcp.dport), tb.hash_key)

        test_pkts.append(test_pkt)
        hash_info.append((hash_type, hash_val))

        test_frame = AxiStreamFrame(test_pkt.build())
        test_frames.append(test_frame)
        await tb.source.send(test_frame)

        ip_id = (ip_id + 1) & 0xffff

    for test_pkt, info, test_frame in zip(test_pkts, hash_info, test_frames):
        hash_type, hash_val = info

        rx_hash = await tb.sink.recv()

        tb.log.info("RX hash: 0x%08x (expected: 0x%08x) type: %s (expected: %s)",
            rx_hash.hash, hash_val, HashType(rx_hash.hash_type.integer), hash_type)

        assert rx_hash.hash_type == hash_type
        assert rx_hash.hash == hash_val

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    return list(range(1, 128)) + [512, 1500, 9200] + [46]*10


def incrementing_payload(length):
    return bytes(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.add_option("pkt_type", [Ether, IP, UDP, TCP])
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
axi_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axi', 'rtl'))
axis_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axis', 'rtl'))
eth_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'eth', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'pcie', 'rtl'))


@pytest.mark.parametrize("data_width", [64, 256])
def test_rx_hash(request, data_width):
    dut = "rx_hash"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['DATA_WIDTH'] = data_width
    parameters['KEEP_WIDTH'] = parameters['DATA_WIDTH'] // 8

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
