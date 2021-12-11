#!/usr/bin/env python
"""

Copyright (c) 2020 Alex Forencich

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

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus
from cocotbext.pcie.core import RootComplex
from cocotbext.pcie.xilinx.us import UltraScalePlusPcieDevice
from cocotbext.axi import AxiBus, AxiRam
from cocotbext.axi.stream import define_stream
from cocotbext.axi.utils import hexdump_str

DescBus, DescTransaction, DescSource, DescSink, DescMonitor = define_stream("Desc",
    signals=["pcie_addr", "axi_addr", "len", "tag", "valid", "ready"]
)

DescStatusBus, DescStatusTransaction, DescStatusSource, DescStatusSink, DescStatusMonitor = define_stream("DescStatus",
    signals=["tag", "error", "valid"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # PCIe
        self.rc = RootComplex()

        self.dev = UltraScalePlusPcieDevice(
            # configuration options
            pcie_generation=3,
            # pcie_link_width=2,
            # user_clk_frequency=250e6,
            alignment="dword",
            cq_cc_straddle=False,
            rq_rc_straddle=False,
            rc_4tlp_straddle=False,
            enable_pf1=False,
            enable_client_tag=True,
            enable_extended_tag=False,
            enable_parity=False,
            enable_rx_msg_interface=False,
            enable_sriov=False,
            enable_extended_configuration=False,

            enable_pf0_msi=True,
            enable_pf1_msi=False,

            # signals
            user_clk=dut.clk,
            user_reset=dut.rst,

            rq_bus=AxiStreamBus.from_prefix(dut, "m_axis_rq"),
            pcie_rq_seq_num0=dut.s_axis_rq_seq_num_0,
            pcie_rq_seq_num_vld0=dut.s_axis_rq_seq_num_valid_0,
            pcie_rq_seq_num1=dut.s_axis_rq_seq_num_1,
            pcie_rq_seq_num_vld1=dut.s_axis_rq_seq_num_valid_1,

            rc_bus=AxiStreamBus.from_prefix(dut, "s_axis_rc"),

            cfg_max_payload=dut.max_payload_size,
            cfg_max_read_req=dut.max_read_request_size,

            cfg_fc_sel=0b100,
            cfg_fc_ph=dut.pcie_tx_fc_ph_av,
            cfg_fc_pd=dut.pcie_tx_fc_pd_av,
            cfg_fc_nph=dut.pcie_tx_fc_nph_av,
        )

        self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        # AXI
        self.axi_ram = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst, size=2**16)

        # Control
        self.read_desc_source = DescSource(DescBus.from_prefix(dut, "s_axis_read_desc"), dut.clk, dut.rst)
        self.read_desc_status_sink = DescStatusSink(DescStatusBus.from_prefix(dut, "m_axis_read_desc_status"), dut.clk, dut.rst)

        self.write_desc_source = DescSource(DescBus.from_prefix(dut, "s_axis_write_desc"), dut.clk, dut.rst)
        self.write_desc_status_sink = DescStatusSink(DescStatusBus.from_prefix(dut, "m_axis_write_desc_status"), dut.clk, dut.rst)

        dut.requester_id.setimmediatevalue(0)
        dut.requester_id_enable.setimmediatevalue(0)

        dut.ext_tag_enable.setimmediatevalue(0)
        dut.read_enable.setimmediatevalue(0)
        dut.write_enable.setimmediatevalue(0)

        # monitor error outputs
        self.status_error_cor_asserted = False
        self.status_error_uncor_asserted = False
        cocotb.start_soon(self._run_monitor_status_error_cor())
        cocotb.start_soon(self._run_monitor_status_error_uncor())

    def set_idle_generator(self, generator=None):
        if generator:
            self.dev.rc_source.set_pause_generator(generator())
            self.axi_ram.write_if.b_channel.set_pause_generator(generator())
            self.axi_ram.read_if.r_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.dev.rq_sink.set_pause_generator(generator())
            self.axi_ram.write_if.aw_channel.set_pause_generator(generator())
            self.axi_ram.write_if.w_channel.set_pause_generator(generator())
            self.axi_ram.read_if.ar_channel.set_pause_generator(generator())

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


async def run_test_write(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axi_ram.write_if.byte_lanes
    tag_count = 2**len(tb.write_desc_source.bus.tag)

    cur_tag = 1

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True)

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    tb.dut.write_enable.value = 1

    for length in list(range(0, byte_lanes+3))+list(range(128-4, 128+4))+[1024]:
        for pcie_offset in list(range(4))+list(range(4096-4, 4096)):
            for axi_offset in range(1):
                tb.log.info("length %d, pcie_offset %d, axi_offset %d", length, pcie_offset, axi_offset)
                pcie_addr = pcie_offset+0x1000
                axi_addr = axi_offset+0x1000
                test_data = bytearray([x % 256 for x in range(length)])

                tb.axi_ram.write(axi_addr & 0xffff80, b'\x55'*(len(test_data)+256))
                mem[pcie_addr-128:pcie_addr-128+len(test_data)+256] = b'\xaa'*(len(test_data)+256)
                tb.axi_ram.write(axi_addr, test_data)

                tb.log.debug("%s", tb.axi_ram.hexdump_str((axi_addr & ~0xf)-16, (((axi_addr & 0xf)+length-1) & ~0xf)+48, prefix="AXI "))

                desc = DescTransaction(pcie_addr=mem_base+pcie_addr, axi_addr=axi_addr, len=len(test_data), tag=cur_tag)
                await tb.write_desc_source.send(desc)

                status = await tb.write_desc_status_sink.recv()
                await Timer(100 + (length // byte_lanes), 'ns')

                tb.log.info("status: %s", status)

                assert int(status.tag) == cur_tag
                assert int(status.error) == 0

                tb.log.debug("%s", hexdump_str(mem, (pcie_addr & ~0xf)-16, (((pcie_addr & 0xf)+length-1) & ~0xf)+48, prefix="PCIe "))

                assert mem[pcie_addr-1:pcie_addr+len(test_data)+1] == b'\xaa'+test_data+b'\xaa'

                cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_read(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axi_ram.write_if.byte_lanes
    tag_count = 2**len(tb.read_desc_source.bus.tag)

    cur_tag = 1

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True)

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    tb.dut.read_enable.value = 1

    for length in list(range(0, byte_lanes+3))+list(range(128-4, 128+4))+[1024]:
        for pcie_offset in list(range(4))+list(range(4096-4, 4096)):
            for axi_offset in range(1):
                tb.log.info("length %d, pcie_offset %d, axi_offset %d", length, pcie_offset, axi_offset)
                pcie_addr = pcie_offset+0x1000
                axi_addr = axi_offset+0x1000
                test_data = bytearray([x % 256 for x in range(length)])

                mem[pcie_addr:pcie_addr+len(test_data)] = test_data

                tb.log.debug("%s", hexdump_str(mem, (pcie_addr & ~0xf)-16, (((pcie_addr & 0xf)+length-1) & ~0xf)+48, prefix="PCIe "))

                tb.axi_ram.write(axi_addr-256, b'\xaa'*(len(test_data)+512))

                desc = DescTransaction(pcie_addr=mem_base+pcie_addr, axi_addr=axi_addr, len=len(test_data), tag=cur_tag)
                await tb.read_desc_source.send(desc)

                status = await tb.read_desc_status_sink.recv()

                tb.log.info("status: %s", status)

                assert int(status.tag) == cur_tag
                assert int(status.error) == 0

                tb.log.debug("%s", tb.axi_ram.hexdump_str((axi_addr & ~0xf)-16, (((axi_addr & 0xf)+length-1) & ~0xf)+48, prefix="AXI "))

                assert tb.axi_ram.read(axi_addr-8, len(test_data)+16) == b'\xaa'*8+test_data+b'\xaa'*8

                cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_read_errors(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    tag_count = 2**len(tb.read_desc_source.bus.tag)

    cur_tag = 1

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True)

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    tb.dut.read_enable.value = 1

    tb.log.info("Test bad DMA read (UR) short")

    desc = DescTransaction(pcie_addr=mem_base-512, axi_addr=0, len=8, tag=cur_tag)
    await tb.read_desc_source.send(desc)

    status = await tb.read_desc_status_sink.recv()

    tb.log.info("status: %s", status)

    assert int(status.tag) == cur_tag
    assert int(status.error) in {10, 11}

    cur_tag = (cur_tag + 1) % tag_count

    tb.log.info("Test bad DMA read (UR) first")

    desc = DescTransaction(pcie_addr=mem_base-512, axi_addr=0, len=1024, tag=cur_tag)
    await tb.read_desc_source.send(desc)

    status = await tb.read_desc_status_sink.recv()

    tb.log.info("status: %s", status)

    assert int(status.tag) == cur_tag
    assert int(status.error) in {10, 11}

    cur_tag = (cur_tag + 1) % tag_count

    tb.log.info("Test bad DMA read (UR) last")

    desc = DescTransaction(pcie_addr=mem_base+16*1024*1024-512, axi_addr=0, len=1024, tag=cur_tag)
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
                run_test_write,
                run_test_read,
                run_test_read_errors,
            ]:

        factory = TestFactory(test)
        factory.add_option(("idle_inserter", "backpressure_inserter"), [(None, None), (cycle_pause, cycle_pause)])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("axis_pcie_data_width", [64, 128, 256, 512])
def test_pcie_us_axi_dma(request, axis_pcie_data_width):
    dut = "pcie_us_axi_dma"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_rd.v"),
        os.path.join(rtl_dir, f"{dut}_wr.v"),
    ]

    parameters = {}

    parameters['AXIS_PCIE_DATA_WIDTH'] = axis_pcie_data_width
    parameters['AXIS_PCIE_KEEP_WIDTH'] = parameters['AXIS_PCIE_DATA_WIDTH'] // 32
    parameters['AXIS_PCIE_RQ_USER_WIDTH'] = 62 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 137
    parameters['AXIS_PCIE_RC_USER_WIDTH'] = 75 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 161
    parameters['RQ_SEQ_NUM_WIDTH'] = 4 if parameters['AXIS_PCIE_RQ_USER_WIDTH'] == 60 else 6
    parameters['RQ_SEQ_NUM_ENABLE'] = 1
    parameters['AXI_DATA_WIDTH'] = parameters['AXIS_PCIE_DATA_WIDTH']
    parameters['AXI_ADDR_WIDTH'] = 24
    parameters['AXI_STRB_WIDTH'] = parameters['AXI_DATA_WIDTH'] // 8
    parameters['AXI_ID_WIDTH'] = 8
    parameters['AXI_MAX_BURST_LEN'] = 256
    parameters['PCIE_ADDR_WIDTH'] = 64
    parameters['PCIE_TAG_COUNT'] = 64 if parameters['AXIS_PCIE_RQ_USER_WIDTH'] == 60 else 256
    parameters['LEN_WIDTH'] = 20
    parameters['TAG_WIDTH'] = 8
    parameters['READ_OP_TABLE_SIZE'] = parameters['PCIE_TAG_COUNT']
    parameters['READ_TX_LIMIT'] = 2**(parameters['RQ_SEQ_NUM_WIDTH']-1)
    parameters['READ_TX_FC_ENABLE'] = 1
    parameters['WRITE_OP_TABLE_SIZE'] = 2**(parameters['RQ_SEQ_NUM_WIDTH']-1)
    parameters['WRITE_TX_LIMIT'] = 2**(parameters['RQ_SEQ_NUM_WIDTH']-1)
    parameters['WRITE_TX_FC_ENABLE'] = 1

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
