# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2023 The Regents of the University of California

import logging
import os

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiBus, AxiRam


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        # Control
        dut.reg_wr_addr.setimmediatevalue(0)
        dut.reg_wr_data.setimmediatevalue(0)
        dut.reg_wr_strb.setimmediatevalue(0)
        dut.reg_wr_en.setimmediatevalue(0)
        dut.reg_rd_addr.setimmediatevalue(0)
        dut.reg_rd_en.setimmediatevalue(0)

        # DRAM
        cocotb.start_soon(Clock(dut.m_axi_clk, 3.332, units="ns").start())
        dut.m_axi_rst.setimmediatevalue(0)

        self.ram = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.m_axi_clk, dut.m_axi_rst, size=16*2**20)

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        self.dut.m_axi_rst.setimmediatevalue(0)
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        self.dut.m_axi_rst.value = 1
        for k in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        self.dut.m_axi_rst.value = 0
        for k in range(10):
            await RisingEdge(self.dut.clk)

    async def write_reg(self, addr, data):
        await RisingEdge(self.dut.clk)
        self.dut.reg_wr_addr.value = addr
        self.dut.reg_wr_data.value = data
        self.dut.reg_wr_strb.value = 0xf
        self.dut.reg_wr_en.value = 1
        await RisingEdge(self.dut.clk)

        k = 4
        while k > 0:
            if self.dut.reg_wr_ack.value:
                break
            if not self.dut.reg_wr_wait.value:
                k -= 1
            await RisingEdge(self.dut.clk)

        self.dut.reg_wr_en.value = 0

    async def read_reg(self, addr):
        self.dut.reg_rd_addr.value = addr
        self.dut.reg_rd_en.value = 1
        await RisingEdge(self.dut.clk)

        k = 4
        while k > 0:
            if self.dut.reg_rd_ack.value:
                break
            if not self.dut.reg_rd_wait.value:
                k -= 1
            await RisingEdge(self.dut.clk)

        self.dut.reg_rd_en.value = 0
        return self.dut.reg_rd_data.value.integer


async def run_test(dut):

    tb = TB(dut)

    await tb.reset()

    # configure FIFO
    await tb.write_reg(0x38, (16*2**20)-1)
    await tb.write_reg(0x3C, 0x00000000)

    # reset FIFO
    await tb.write_reg(0x20, 0x00000002)

    for k in range(10):
        await RisingEdge(dut.clk)

    # enable FIFO
    await tb.write_reg(0x20, 0x00000001)

    # enable data generation and checking (test read and write)
    await tb.write_reg(0x68, 1024)
    await tb.write_reg(0x6C, 1024)
    await tb.write_reg(0x24, 0x00000101)

    # wait for transfer to complete
    while True:
        val = await tb.read_reg(0x24)
        if val == 0:
            break

    for k in range(200):
        await RisingEdge(dut.clk)

    # enable data generation only (test write)
    await tb.write_reg(0x68, 1024)
    await tb.write_reg(0x6C, 0)
    await tb.write_reg(0x24, 0x00000001)

    # wait for transfer to complete
    while True:
        val = await tb.read_reg(0x24)
        if val == 0:
            break

    for k in range(200):
        await RisingEdge(dut.clk)

    # enable data generation and checking (test offset read and write)
    await tb.write_reg(0x68, 1024)
    await tb.write_reg(0x6C, 1024)
    await tb.write_reg(0x24, 0x00000101)

    # wait for transfer to complete
    while True:
        val = await tb.read_reg(0x24)
        if val == 0:
            break

    for k in range(200):
        await RisingEdge(dut.clk)

    # enable data checking only (test read)
    await tb.write_reg(0x68, 0)
    await tb.write_reg(0x6C, 1024)
    await tb.write_reg(0x24, 0x00000100)

    # wait for transfer to complete
    while True:
        val = await tb.read_reg(0x24)
        if val == 0:
            break

    for k in range(200):
        await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if cocotb.SIM_NAME:

    for test in [
                run_test,
            ]:

        factory = TestFactory(test)
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
axi_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axi', 'rtl'))
axis_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axis', 'rtl'))
eth_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'eth', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'pcie', 'rtl'))


@pytest.mark.parametrize("data_width", [256, 512])
def test_dram_test_ch(request, data_width):
    dut = "dram_test_ch"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(eth_rtl_dir, "lfsr.v"),
        os.path.join(axi_rtl_dir, "axi_vfifo_raw.v"),
        os.path.join(axi_rtl_dir, "axi_vfifo_raw_rd.v"),
        os.path.join(axi_rtl_dir, "axi_vfifo_raw_wr.v"),
        os.path.join(axi_rtl_dir, "axil_crossbar.v"),
        os.path.join(axi_rtl_dir, "axil_crossbar_addr.v"),
        os.path.join(axi_rtl_dir, "axil_crossbar_rd.v"),
        os.path.join(axi_rtl_dir, "axil_crossbar_wr.v"),
        os.path.join(axi_rtl_dir, "axil_reg_if.v"),
        os.path.join(axi_rtl_dir, "axil_reg_if_rd.v"),
        os.path.join(axi_rtl_dir, "axil_reg_if_wr.v"),
        os.path.join(axi_rtl_dir, "axil_register_rd.v"),
        os.path.join(axi_rtl_dir, "axil_register_wr.v"),
        os.path.join(axi_rtl_dir, "arbiter.v"),
        os.path.join(axi_rtl_dir, "priority_encoder.v"),
        os.path.join(axis_rtl_dir, "axis_adapter.v"),
        os.path.join(axis_rtl_dir, "axis_arb_mux.v"),
        os.path.join(axis_rtl_dir, "axis_async_fifo.v"),
        os.path.join(axis_rtl_dir, "axis_async_fifo_adapter.v"),
        os.path.join(axis_rtl_dir, "axis_demux.v"),
        os.path.join(axis_rtl_dir, "axis_fifo.v"),
        os.path.join(axis_rtl_dir, "axis_fifo_adapter.v"),
        os.path.join(axis_rtl_dir, "axis_pipeline_fifo.v"),
        os.path.join(axis_rtl_dir, "axis_register.v"),
    ]

    parameters = {}

    # AXI configuration
    parameters['AXI_DATA_WIDTH'] = 256
    parameters['AXI_ADDR_WIDTH'] = 32
    parameters['AXI_STRB_WIDTH'] = parameters['AXI_DATA_WIDTH'] // 8
    parameters['AXI_ID_WIDTH'] = 8
    parameters['AXI_MAX_BURST_LEN'] = 256

    # Register interface
    parameters['REG_ADDR_WIDTH'] = 7
    parameters['REG_DATA_WIDTH'] = 32
    parameters['REG_STRB_WIDTH'] = parameters['REG_DATA_WIDTH'] // 8
    parameters['RB_BASE_ADDR'] = 0
    parameters['RB_NEXT_PTR'] = 0

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
