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

import logging
import os

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())
        cocotb.start_soon(Clock(dut.phy_tx_clk, 6.4, units="ns").start())
        cocotb.start_soon(Clock(dut.phy_rx_clk, 6.4, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

        dut.phy_rx_error_count.setimmediatevalue(0)

        dut.tdma_timeslot_index.setimmediatevalue(0)
        dut.tdma_timeslot_start.setimmediatevalue(0)
        dut.tdma_timeslot_active.setimmediatevalue(0)

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

    async def run_scheduler(self, period=50, active_period=None, slots=4, cycles=5):
        if active_period is None:
            active_period = period
        active_period = min(active_period, period)

        await RisingEdge(self.dut.clk)
        for i in range(cycles):
            for k in range(slots):
                self.dut.tdma_timeslot_index <= k
                self.dut.tdma_timeslot_start <= 1
                self.dut.tdma_timeslot_active <= 1
                await RisingEdge(self.dut.clk)
                self.dut.tdma_timeslot_start <= 0
                for k in range(active_period-1):
                    await RisingEdge(self.dut.clk)
                self.dut.tdma_timeslot_active <= 0
                for k in range(period-active_period):
                    await RisingEdge(self.dut.clk)

    async def dump_counters(self):
        cycles, updates, errors = await self.axil_master.read_dwords(0x0014, 3)
        self.log.info("Cycles: %d", cycles)
        self.log.info("Updates: %d", updates)
        self.log.info("Errors: %d", errors)

    async def dump_timeslot_counters(self, slice_index=0):
        await self.axil_master.write_dword(0x0030, slice_index)
        counters = await self.axil_master.read_dwords(0x0200, 8)
        for k in range(4):
            self.log.info("Timeslot %d slice %d updates: %s", k, slice_index, counters[k*2])
            self.log.info("Timeslot %d slice %d errors: %s", k, slice_index, counters[k*2+1])

    async def clear_timeslot_counters(self, slice_index=0):
        await self.axil_master.write_dword(0x0030, slice_index)
        await self.axil_master.write_dwords(0x0200, [0]*8)


async def run_test(dut):

    tb = TB(dut)

    await tb.reset()

    tb.log.info("Test error counts")

    await tb.axil_master.write_dword(0x0000, 0x00000003)
    await tb.axil_master.write_dword(0x0020, 0x00000001)

    await tb.dump_counters()
    await tb.dump_timeslot_counters()
    await tb.clear_timeslot_counters()

    await tb.run_scheduler(period=50, active_period=None, slots=4, cycles=5)

    await tb.dump_counters()
    await tb.dump_timeslot_counters()
    await tb.clear_timeslot_counters()

    await RisingEdge(dut.clk)
    dut.phy_rx_error_count <= 1

    await tb.run_scheduler(period=50, active_period=None, slots=4, cycles=5)

    await RisingEdge(dut.clk)
    dut.phy_rx_error_count <= 0

    await tb.dump_counters()
    await tb.dump_timeslot_counters()
    await tb.clear_timeslot_counters()

    tb.log.info("Change duty cycle")

    await tb.axil_master.write_dword(0x0000, 0x00000003)
    await tb.axil_master.write_dword(0x0020, 0x00000001)

    await tb.dump_counters()
    await tb.dump_timeslot_counters()
    await tb.clear_timeslot_counters()

    await tb.run_scheduler(period=50, active_period=40, slots=4, cycles=5)

    await tb.dump_counters()
    await tb.dump_timeslot_counters()
    await tb.clear_timeslot_counters()

    await RisingEdge(dut.clk)
    dut.phy_rx_error_count <= 1

    await tb.run_scheduler(period=50, active_period=40, slots=4, cycles=5)

    await RisingEdge(dut.clk)
    dut.phy_rx_error_count <= 0

    await tb.dump_counters()
    await tb.dump_timeslot_counters()
    await tb.clear_timeslot_counters()

    tb.log.info("Test slices")

    await tb.axil_master.write_dword(0x0000, 0x00000003)
    await tb.axil_master.write_dword(0x0020, 0x00000003)
    await tb.axil_master.write_dword(0x0024, 0x00000010)
    await tb.axil_master.write_dword(0x0028, 0x00000020)

    await tb.dump_counters()
    for k in range(3):
        await tb.dump_timeslot_counters(k)
    for k in range(3):
        await tb.clear_timeslot_counters(k)

    await tb.run_scheduler(period=500, active_period=400, slots=4, cycles=5)

    await tb.dump_counters()
    for k in range(3):
        await tb.dump_timeslot_counters(k)
    for k in range(3):
        await tb.clear_timeslot_counters(k)

    await RisingEdge(dut.clk)
    dut.phy_rx_error_count <= 1

    await tb.run_scheduler(period=500, active_period=400, slots=4, cycles=5)

    await RisingEdge(dut.clk)
    dut.phy_rx_error_count <= 0

    await tb.dump_counters()
    for k in range(3):
        await tb.dump_timeslot_counters(k)
    for k in range(3):
        await tb.clear_timeslot_counters(k)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
axi_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axi', 'rtl'))
axis_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axis', 'rtl'))
eth_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'eth', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'pcie', 'rtl'))


def test_tdma_ber_ch(request):
    dut = "tdma_ber_ch"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['INDEX_WIDTH'] = 6
    parameters['SLICE_WIDTH'] = 5
    parameters['AXIL_DATA_WIDTH'] = 32
    parameters['AXIL_ADDR_WIDTH'] = parameters['INDEX_WIDTH']+4
    parameters['AXIL_STRB_WIDTH'] = parameters['AXIL_DATA_WIDTH'] // 8

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
