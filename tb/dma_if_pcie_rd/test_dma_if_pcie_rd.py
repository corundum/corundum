#!/usr/bin/env python
"""

Copyright (c) 2021 Alex Forencich

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

import itertools
import logging
import os
import sys

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.pcie.core import RootComplex
from cocotbext.axi.stream import define_stream
from cocotbext.axi.utils import hexdump_str

try:
    from pcie_if import PcieIfDevice, PcieIfRxBus, PcieIfTxBus
    from dma_psdp_ram import PsdpRamWrite, PsdpRamWriteBus
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from pcie_if import PcieIfDevice, PcieIfRxBus, PcieIfTxBus
        from dma_psdp_ram import PsdpRamWrite, PsdpRamWriteBus
    finally:
        del sys.path[0]

DescBus, DescTransaction, DescSource, DescSink, DescMonitor = define_stream("Desc",
    signals=["pcie_addr", "ram_addr", "ram_sel", "len", "tag", "valid", "ready"]
)

DescStatusBus, DescStatusTransaction, DescStatusSource, DescStatusSink, DescStatusMonitor = define_stream("DescStatus",
    signals=["tag", "error", "valid"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        # PCIe
        self.rc = RootComplex()

        self.dev = PcieIfDevice(
            clk=dut.clk,
            rst=dut.rst,

            tx_rd_req_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_rd_req_tlp"),
            rd_req_tx_seq_num=dut.s_axis_tx_seq_num,
            rd_req_tx_seq_num_valid=dut.s_axis_tx_seq_num_valid,

            rx_cpl_tlp_bus=PcieIfRxBus.from_prefix(dut, "rx_cpl_tlp"),

            cfg_max_read_req=dut.max_read_request_size,
            cfg_ext_tag_enable=dut.ext_tag_enable,

            tx_fc_nph_av=dut.pcie_tx_fc_nph_av,
        )

        self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        # DMA RAM
        self.dma_ram = PsdpRamWrite(PsdpRamWriteBus.from_prefix(dut, "ram"), dut.clk, dut.rst, size=2**16)

        # Control
        self.read_desc_source = DescSource(DescBus.from_prefix(dut, "s_axis_read_desc"), dut.clk, dut.rst)
        self.read_desc_status_sink = DescStatusSink(DescStatusBus.from_prefix(dut, "m_axis_read_desc_status"), dut.clk, dut.rst)

        dut.requester_id.setimmediatevalue(0)

        dut.enable.setimmediatevalue(0)

        # monitor error outputs
        self.status_error_cor_asserted = False
        self.status_error_uncor_asserted = False
        cocotb.start_soon(self._run_monitor_status_error_cor())
        cocotb.start_soon(self._run_monitor_status_error_uncor())

    def set_idle_generator(self, generator=None):
        if generator:
            self.dev.rx_cpl_tlp_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.dev.tx_rd_req_tlp_sink.set_pause_generator(generator())
            self.dma_ram.set_pause_generator(generator())

    async def _run_monitor_status_error_cor(self):
        while True:
            await RisingEdge(self.dut.status_error_cor)
            self.log.info("status_error_cor (correctable error) was asserted")
            self.status_error_cor_asserted = True

    async def _run_monitor_status_error_uncor(self):
        while True:
            await RisingEdge(self.dut.status_error_uncor)
            self.log.info("status_error_uncor (uncorrectable error) was asserted")
            self.status_error_uncor_asserted = True

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test_read(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    if os.getenv("PCIE_OFFSET") is None:
        pcie_offsets = list(range(4))+list(range(4096-4, 4096))
    else:
        pcie_offsets = [int(os.getenv("PCIE_OFFSET"))]

    byte_lanes = tb.dma_ram.byte_lanes
    tag_count = 2**len(tb.read_desc_source.bus.tag)

    cur_tag = 1

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await tb.cycle_reset()

    await tb.rc.enumerate(enable_bus_mastering=True)

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    tb.dut.requester_id <= tb.dev.bus_num << 8
    tb.dut.enable <= 1

    for length in list(range(0, byte_lanes+3))+list(range(128-4, 128+4))+[1024]:
        for pcie_offset in pcie_offsets:
            for ram_offset in range(byte_lanes+1):
                tb.log.info("length %d, pcie_offset %d, ram_offset %d", length, pcie_offset, ram_offset)
                pcie_addr = pcie_offset+0x1000
                ram_addr = ram_offset+0x1000
                test_data = bytearray([x % 256 for x in range(length)])

                mem[pcie_addr:pcie_addr+len(test_data)] = test_data

                tb.log.debug("%s", hexdump_str(mem, (pcie_addr & ~0xf)-16, (((pcie_addr & 0xf)+length-1) & ~0xf)+48, prefix="PCIe "))

                tb.dma_ram.write(ram_addr-256, b'\xaa'*(len(test_data)+512))

                desc = DescTransaction(pcie_addr=mem_base+pcie_addr, ram_addr=ram_addr, ram_sel=0, len=len(test_data), tag=cur_tag)
                await tb.read_desc_source.send(desc)

                status = await tb.read_desc_status_sink.recv()

                tb.log.info("status: %s", status)

                assert int(status.tag) == cur_tag
                assert int(status.error) == 0

                tb.log.debug("%s", tb.dma_ram.hexdump_str((ram_addr & ~0xf)-16, (((ram_addr & 0xf)+length-1) & ~0xf)+48, prefix="RAM "))

                assert tb.dma_ram.read(ram_addr-8, len(test_data)+16) == b'\xaa'*8+test_data+b'\xaa'*8

                cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_read_errors(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    tag_count = 2**len(tb.read_desc_source.bus.tag)

    cur_tag = 1

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await tb.cycle_reset()

    await tb.rc.enumerate(enable_bus_mastering=True)

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    tb.dut.requester_id <= tb.dev.bus_num << 8
    tb.dut.enable <= 1

    tb.log.info("Test bad DMA read (UR) short")

    desc = DescTransaction(pcie_addr=mem_base-512, ram_addr=0, ram_sel=0, len=8, tag=cur_tag)
    await tb.read_desc_source.send(desc)

    status = await tb.read_desc_status_sink.recv()

    tb.log.info("status: %s", status)

    assert int(status.tag) == cur_tag
    assert int(status.error) in {10, 11}

    cur_tag = (cur_tag + 1) % tag_count

    tb.log.info("Test bad DMA read (UR) first")

    desc = DescTransaction(pcie_addr=mem_base-512, ram_addr=0, ram_sel=0, len=1024, tag=cur_tag)
    await tb.read_desc_source.send(desc)

    status = await tb.read_desc_status_sink.recv()

    tb.log.info("status: %s", status)

    assert int(status.tag) == cur_tag
    assert int(status.error) in {10, 11}

    cur_tag = (cur_tag + 1) % tag_count

    tb.log.info("Test bad DMA read (UR) last")

    desc = DescTransaction(pcie_addr=mem_base+16*1024*1024-512, ram_addr=0, ram_sel=0, len=1024, tag=cur_tag)
    await tb.read_desc_source.send(desc)

    status = await tb.read_desc_status_sink.recv()

    tb.log.info("status: %s", status)

    assert int(status.tag) == cur_tag
    assert int(status.error) in {10, 11}

    cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [
                run_test_read,
                run_test_read_errors,
            ]:

        factory = TestFactory(test)
        factory.add_option(("idle_inserter", "backpressure_inserter"), [(None, None), (cycle_pause, cycle_pause)])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("pcie_offset", list(range(4))+list(range(4096-4, 4096)))
@pytest.mark.parametrize("pcie_data_width", [64, 128, 256, 512])
def test_dma_if_pcie_rd(request, pcie_data_width, pcie_offset):
    dut = "dma_if_pcie_rd"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    # segmented interface parameters
    tlp_seg_count = 1
    tlp_seg_data_width = pcie_data_width // tlp_seg_count

    ram_seg_count = tlp_seg_count*2
    ram_seg_data_width = (tlp_seg_count*tlp_seg_data_width)*2 // ram_seg_count
    ram_seg_addr_width = 12
    ram_seg_be_width = ram_seg_data_width // 8
    ram_sel_width = 2
    ram_addr_width = ram_seg_addr_width + (ram_seg_count-1).bit_length() + (ram_seg_be_width-1).bit_length()

    parameters['TLP_SEG_COUNT'] = tlp_seg_count
    parameters['TLP_SEG_DATA_WIDTH'] = tlp_seg_data_width
    parameters['TLP_SEG_HDR_WIDTH'] = 128
    parameters['TX_SEQ_NUM_COUNT'] = 1
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['TX_SEQ_NUM_ENABLE'] = 1
    parameters['RAM_SEG_COUNT'] = ram_seg_count
    parameters['RAM_SEG_DATA_WIDTH'] = ram_seg_data_width
    parameters['RAM_SEG_ADDR_WIDTH'] = ram_seg_addr_width
    parameters['RAM_SEG_BE_WIDTH'] = ram_seg_be_width
    parameters['RAM_SEL_WIDTH'] = ram_sel_width
    parameters['RAM_ADDR_WIDTH'] = ram_addr_width
    parameters['PCIE_ADDR_WIDTH'] = 64
    parameters['PCIE_TAG_COUNT'] = 256
    parameters['LEN_WIDTH'] = 20
    parameters['TAG_WIDTH'] = 8
    parameters['OP_TABLE_SIZE'] = parameters['PCIE_TAG_COUNT']
    parameters['TX_LIMIT'] = 2**(parameters['TX_SEQ_NUM_WIDTH']-1)
    parameters['TX_FC_ENABLE'] = 1
    parameters['TLP_FORCE_64_BIT_ADDR'] = 0
    parameters['CHECK_BUS_NUMBER'] = 0

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    extra_env['PCIE_OFFSET'] = str(pcie_offset)

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
