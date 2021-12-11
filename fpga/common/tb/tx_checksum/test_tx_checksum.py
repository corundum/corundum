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

import itertools
import logging
import os
import struct

import scapy.utils
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink
from cocotbext.axi.stream import define_stream


CsumCmdBus, CsumCmdTransaction, CsumCmdSource, CsumCmdSink, CsumCmdMonitor = define_stream("CsumCmd",
    signals=["csum_enable", "csum_start", "csum_offset", "csum_init", "valid"],
    optional_signals=["ready"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

        self.cmd_source = CsumCmdSource(CsumCmdBus.from_prefix(dut, "s_axis_cmd"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

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


async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_pkts = []
    test_frames = []

    ip_id = 1

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
        ip = IP(src='192.168.1.100', dst='192.168.1.101', id=ip_id)
        udp = UDP(sport=1234, dport=4321)
        test_pkt = eth / ip / udp / payload

        ip_id = (ip_id + 1) & 0xffff

        # don't compute checksum
        test_pkts.append(test_pkt.copy())
        test_frame = AxiStreamFrame(test_pkt.build())
        test_frames.append(test_frame)

        await tb.source.send(test_frame)
        await tb.cmd_source.send(CsumCmdTransaction(csum_enable=0, csum_start=34, csum_offset=40, csum_init=0))

        # inline partial checksum
        test_pkts.append(test_pkt.copy())

        pkt = test_pkt.copy()
        partial_csum = scapy.utils.checksum(bytes(pkt[UDP]))
        pkt[UDP].chksum = partial_csum

        test_frame = AxiStreamFrame(pkt.build())
        test_frames.append(test_frame)

        await tb.source.send(test_frame)
        await tb.cmd_source.send(CsumCmdTransaction(csum_enable=1, csum_start=34, csum_offset=40, csum_init=0))

        # partial checksum in command
        test_pkts.append(test_pkt.copy())

        pkt = test_pkt.copy()
        partial_csum = scapy.utils.checksum(bytes(pkt[UDP]))
        pkt[UDP].chksum = 0

        test_frame = AxiStreamFrame(pkt.build())
        test_frames.append(test_frame)

        await tb.source.send(test_frame)
        await tb.cmd_source.send(CsumCmdTransaction(csum_enable=1, csum_start=34, csum_offset=40, csum_init=partial_csum))

    for test_pkt, test_frame in zip(test_pkts, test_frames):
        rx_frame = await tb.sink.recv()

        rx_pkt = Ether(bytes(rx_frame))

        tb.log.info("RX packet: %s", repr(rx_pkt))

        check_pkt = Ether(test_pkt.build())

        tb.log.info("RX packet UDP checksum: 0x%04x (expected 0x%04x)", rx_pkt[UDP].chksum, check_pkt[UDP].chksum)

        assert check_pkt == rx_pkt

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_offsets(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_pkts = []
    test_frames = []
    check_frames = []

    ip_id = 1

    for payload in [payload_data(x) for x in payload_lengths()]:
        eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
        test_pkt = eth / payload

        ip_id = (ip_id + 1) & 0xffff

        for start in range(0, min(len(payload)+14, 32)):
            offset = 0
            test_pkts.append(test_pkt.copy())
            test_frame = AxiStreamFrame(test_pkt.build())
            test_frames.append(test_frame)

            await tb.source.send(test_frame)
            await tb.cmd_source.send(CsumCmdTransaction(csum_enable=1, csum_start=start, csum_offset=offset, csum_init=0))

            csum = scapy.utils.checksum(bytes(test_pkt)[start:])

            check_frame = bytearray(test_frame.tdata)
            struct.pack_into('>H', check_frame, offset, csum)

            check_frames.append(check_frame)

        for offset in range(0, min(len(payload)+14, 32)-1):
            start = 0
            test_pkts.append(test_pkt.copy())
            test_frame = AxiStreamFrame(test_pkt.build())
            test_frames.append(test_frame)

            await tb.source.send(test_frame)
            await tb.cmd_source.send(CsumCmdTransaction(csum_enable=1, csum_start=start, csum_offset=offset, csum_init=0))

            csum = scapy.utils.checksum(bytes(test_pkt)[start:])

            check_frame = bytearray(test_frame.tdata)
            struct.pack_into('>H', check_frame, offset, csum)

            check_frames.append(check_frame)

    for test_pkt, test_frame, check_frame in zip(test_pkts, test_frames, check_frames):
        rx_frame = await tb.sink.recv()

        rx_pkt = Ether(bytes(rx_frame))

        tb.log.info("RX packet: %s", repr(rx_pkt))

        assert rx_frame.tdata == check_frame

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    return list(range(1, 128)) + [512, 1472, 9172] + [18]*10


def size_list2():
    return list(range(1, 64))


def incrementing_payload(length):
    return bytes(itertools.islice(itertools.cycle(range(256)), length))


if cocotb.SIM_NAME:

    # for test in [run_test, run_test_offsets]:

    #     factory = TestFactory(run_test)
    #     factory.add_option("payload_lengths", [size_list])
    #     factory.add_option("payload_data", [incrementing_payload])
    #     factory.add_option("idle_inserter", [None, cycle_pause])
    #     factory.add_option("backpressure_inserter", [None, cycle_pause])
    #     factory.generate_tests()

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()

    factory = TestFactory(run_test_offsets)
    factory.add_option("payload_lengths", [size_list2])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
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
def test_tx_checksum(request, data_width):
    dut = "tx_checksum"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(axis_rtl_dir, "axis_fifo.v"),
    ]

    parameters = {}

    parameters['DATA_WIDTH'] = data_width
    parameters['KEEP_WIDTH'] = parameters['DATA_WIDTH'] // 8
    parameters['ID_ENABLE'] = 0
    parameters['ID_WIDTH'] = 8
    parameters['DEST_ENABLE'] = 0
    parameters['DEST_WIDTH'] = 8
    parameters['USER_ENABLE'] = 1
    parameters['USER_WIDTH'] = 1
    parameters['USE_INIT_VALUE'] = 1
    parameters['DATA_FIFO_DEPTH'] = 16384
    parameters['CHECKSUM_FIFO_DEPTH'] = 4

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
