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
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.pcie.core import RootComplex
from cocotbext.pcie.intel.s10 import S10PcieDevice, S10RxBus, S10TxBus

try:
    from pcie_if import PcieIfTestDevice, PcieIfRxBus, PcieIfTxBus
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from pcie_if import PcieIfTestDevice, PcieIfRxBus, PcieIfTxBus
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # PCIe
        self.rc = RootComplex()

        self.dev = S10PcieDevice(
            # configuration options
            pcie_generation=3,
            # pcie_link_width=2,
            # pld_clk_frequency=250e6,
            l_tile=False,

            # signals
            # Clock and reset
            # npor=dut.npor,
            # pin_perst=dut.pin_perst,
            # ninit_done=dut.ninit_done,
            # pld_clk_inuse=dut.pld_clk_inuse,
            # pld_core_ready=dut.pld_core_ready,
            reset_status=dut.rst,
            # clr_st=dut.clr_st,
            # refclk=dut.refclk,
            coreclkout_hip=dut.clk,

            # RX interface
            rx_bus=S10RxBus.from_prefix(dut, "rx_st"),

            # TX interface
            tx_bus=S10TxBus.from_prefix(dut, "tx_st"),

            # TX flow control
            tx_ph_cdts=dut.tx_ph_cdts,
            tx_pd_cdts=dut.tx_pd_cdts,
            tx_nph_cdts=dut.tx_nph_cdts,
            tx_npd_cdts=dut.tx_npd_cdts,
            tx_cplh_cdts=dut.tx_cplh_cdts,
            tx_cpld_cdts=dut.tx_cpld_cdts,
            tx_hdr_cdts_consumed=dut.tx_hdr_cdts_consumed,
            tx_data_cdts_consumed=dut.tx_data_cdts_consumed,
            tx_cdts_type=dut.tx_cdts_type,
            tx_cdts_data_value=dut.tx_cdts_data_value,

            # Hard IP status
            # int_status=dut.int_status,
            # int_status_common=dut.int_status_common,
            # derr_cor_ext_rpl=dut.derr_cor_ext_rpl,
            # derr_rpl=dut.derr_rpl,
            # derr_cor_ext_rcv=dut.derr_cor_ext_rcv,
            # derr_uncor_ext_rcv=dut.derr_uncor_ext_rcv,
            # rx_par_err=dut.rx_par_err,
            # tx_par_err=dut.tx_par_err,
            # ltssmstate=dut.ltssmstate,
            # link_up=dut.link_up,
            # lane_act=dut.lane_act,
            # currentspeed=dut.currentspeed,

            # Power management
            # pm_linkst_in_l1=dut.pm_linkst_in_l1,
            # pm_linkst_in_l0s=dut.pm_linkst_in_l0s,
            # pm_state=dut.pm_state,
            # pm_dstate=dut.pm_dstate,
            # apps_pm_xmt_pme=dut.apps_pm_xmt_pme,
            # apps_ready_entr_l23=dut.apps_ready_entr_l23,
            # apps_pm_xmt_turnoff=dut.apps_pm_xmt_turnoff,
            # app_init_rst=dut.app_init_rst,
            # app_xfer_pending=dut.app_xfer_pending,

            # Interrupt interface
            app_msi_req=dut.app_msi_req,
            app_msi_ack=dut.app_msi_ack,
            app_msi_tc=dut.app_msi_tc,
            app_msi_num=dut.app_msi_num,
            app_msi_func_num=dut.app_msi_func_num,
            # app_int_sts=dut.app_int_sts,

            # Error interface
            # serr_out=dut.serr_out,
            # hip_enter_err_mode=dut.hip_enter_err_mode,
            # app_err_valid=dut.app_err_valid,
            # app_err_hdr=dut.app_err_hdr,
            # app_err_info=dut.app_err_info,
            # app_err_func_num=dut.app_err_func_num,

            # Configuration output
            tl_cfg_func=dut.tl_cfg_func,
            tl_cfg_add=dut.tl_cfg_add,
            tl_cfg_ctl=dut.tl_cfg_ctl,

            # Configuration extension bus
            # ceb_req=dut.ceb_req,
            # ceb_ack=dut.ceb_ack,
            # ceb_addr=dut.ceb_addr,
            # ceb_din=dut.ceb_din,
            # ceb_dout=dut.ceb_dout,
            # ceb_wr=dut.ceb_wr,
            # ceb_cdm_convert_data=dut.ceb_cdm_convert_data,
            # ceb_func_num=dut.ceb_func_num,
            # ceb_vf_num=dut.ceb_vf_num,
            # ceb_vf_active=dut.ceb_vf_active,

            # Hard IP reconfiguration interface
            # hip_reconfig_clk=dut.hip_reconfig_clk,
            # hip_reconfig_address=dut.hip_reconfig_address,
            # hip_reconfig_read=dut.hip_reconfig_read,
            # hip_reconfig_readdata=dut.hip_reconfig_readdata,
            # hip_reconfig_readdatavalid=dut.hip_reconfig_readdatavalid,
            # hip_reconfig_write=dut.hip_reconfig_write,
            # hip_reconfig_writedata=dut.hip_reconfig_writedata,
            # hip_reconfig_waitrequest=dut.hip_reconfig_waitrequest,
        )

        self.test_dev = PcieIfTestDevice(
            clk=dut.clk,
            rst=dut.rst,

            rx_req_tlp_bus=PcieIfRxBus.from_prefix(dut, "rx_req_tlp"),

            tx_cpl_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_cpl_tlp"),

            tx_rd_req_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_rd_req_tlp"),
            rd_req_tx_seq_num=dut.m_axis_rd_req_tx_seq_num,
            rd_req_tx_seq_num_valid=dut.m_axis_rd_req_tx_seq_num_valid,

            tx_wr_req_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_wr_req_tlp"),
            wr_req_tx_seq_num=dut.m_axis_wr_req_tx_seq_num,
            wr_req_tx_seq_num_valid=dut.m_axis_wr_req_tx_seq_num_valid,

            rx_cpl_tlp_bus=PcieIfRxBus.from_prefix(dut, "rx_cpl_tlp"),
        )

        self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        self.dev.functions[0].msi_cap.msi_multiple_message_capable = 5

        self.dev.functions[0].configure_bar(0, 1024*1024)
        self.test_dev.add_mem_region(1024*1024)
        self.dev.functions[0].configure_bar(1, 1024*1024, True, True)
        self.test_dev.add_prefetchable_mem_region(1024*1024)
        self.dev.functions[0].configure_bar(3, 1024, False, False, True)
        self.test_dev.add_io_region(1024)

        self.dut.msi_irq.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.dev.rx_source.set_pause_generator(generator())
            self.test_dev.tx_cpl_tlp_source.set_pause_generator(generator())
            self.test_dev.tx_rd_req_tlp_source.set_pause_generator(generator())
            self.test_dev.tx_wr_req_tlp_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.dev.tx_sink.set_pause_generator(generator())
            self.test_dev.rx_req_tlp_sink.set_pause_generator(generator())
            self.test_dev.rx_cpl_tlp_sink.set_pause_generator(generator())


async def run_test_mem(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True, configure_msi=True)

    tb.test_dev.dev_max_payload = tb.dev.functions[0].pcie_cap.max_payload_size
    tb.test_dev.dev_max_read_req = tb.dev.functions[0].pcie_cap.max_read_request_size
    tb.test_dev.dev_bus_num = tb.dev.bus_num

    dev_bar0 = tb.rc.tree[0][0].bar_window[0]
    dev_bar1 = tb.rc.tree[0][0].bar_window[1]
    dev_bar3 = tb.rc.tree[0][0].bar_window[3]

    for length in list(range(0, 8)):
        for offset in list(range(8)):
            tb.log.info("IO operation length: %d offset: %d", length, offset)
            test_data = bytearray([x % 256 for x in range(length)])

            await dev_bar3.write(offset, test_data, timeout=5000)
            assert tb.test_dev.regions[3][1][offset:offset+length] == test_data

            assert await dev_bar3.read(offset, length, timeout=5000) == test_data

    for length in list(range(0, 32))+[1024]:
        for offset in list(range(8))+list(range(4096-8, 4096)):
            tb.log.info("Memory operation (32-bit BAR) length: %d offset: %d", length, offset)
            test_data = bytearray([x % 256 for x in range(length)])

            await dev_bar0.write(offset, test_data, timeout=100)
            # wait for write to complete
            await dev_bar0.read(offset, 1, timeout=5000)
            assert tb.test_dev.regions[0][1][offset:offset+length] == test_data

            assert await dev_bar0.read(offset, length, timeout=5000) == test_data

    for length in list(range(0, 32))+[1024]:
        for offset in list(range(8))+list(range(4096-8, 4096)):
            tb.log.info("Memory operation (64-bit BAR) length: %d offset: %d", length, offset)
            test_data = bytearray([x % 256 for x in range(length)])

            await dev_bar1.write(offset, test_data, timeout=100)
            # wait for write to complete
            await dev_bar1.read(offset, 1, timeout=5000)
            assert tb.test_dev.regions[1][1][offset:offset+length] == test_data

            assert await dev_bar1.read(offset, length, timeout=5000) == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_dma(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    io = tb.rc.io_pool.alloc_region(1024)
    io_base = io.get_absolute_address(0)

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True, configure_msi=True)

    tb.test_dev.dev_max_payload = tb.dev.functions[0].pcie_cap.max_payload_size
    tb.test_dev.dev_max_read_req = tb.dev.functions[0].pcie_cap.max_read_request_size
    tb.test_dev.dev_bus_num = tb.dev.bus_num

    for length in list(range(0, 32))+[1024]:
        for offset in list(range(8))+list(range(4096-8, 4096)):
            tb.log.info("Memory operation (DMA) length: %d offset: %d", length, offset)
            addr = mem_base+offset
            test_data = bytearray([x % 256 for x in range(length)])

            await tb.test_dev.dma_mem_write(addr, test_data, timeout=5000, timeout_unit='ns')
            # wait for write to complete
            while not tb.test_dev.tx_wr_req_tlp_source.empty() or tb.test_dev.tx_wr_req_tlp_source.active:
                await RisingEdge(dut.clk)
            await tb.test_dev.dma_mem_read(addr, length, timeout=5000, timeout_unit='ns')
            assert mem[offset:offset+length] == test_data

            assert await tb.test_dev.dma_mem_read(addr, length, timeout=5000, timeout_unit='ns') == test_data

    for length in list(range(0, 8)):
        for offset in list(range(8)):
            tb.log.info("IO operation (DMA) length: %d offset: %d", length, offset)
            addr = io_base+offset
            test_data = bytearray([x % 256 for x in range(length)])

            await tb.test_dev.dma_io_write(addr, test_data, timeout=5000, timeout_unit='ns')
            assert io[offset:offset+length] == test_data

            assert await tb.test_dev.dma_io_read(addr, length, timeout=5000, timeout_unit='ns') == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_dma_errors(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True, configure_msi=True)

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    tb.test_dev.dev_max_payload = tb.dev.functions[0].pcie_cap.max_payload_size
    tb.test_dev.dev_max_read_req = tb.dev.functions[0].pcie_cap.max_read_request_size
    tb.test_dev.dev_bus_num = tb.dev.bus_num

    tb.log.info("Memory operation (DMA) bad read (UR) short")

    try:
        await tb.test_dev.dma_mem_read(mem_base - 1024, 8, timeout=5000, timeout_unit='ns')
    except Exception:
        pass
    else:
        assert False, "Expected exception"

    tb.log.info("Memory operation (DMA) bad read (UR) first")

    try:
        await tb.test_dev.dma_mem_read(mem_base - 512, 1024, timeout=5000, timeout_unit='ns')
    except Exception:
        pass
    else:
        assert False, "Expected exception"

    tb.log.info("Memory operation (DMA) bad read (UR) last")

    try:
        await tb.test_dev.dma_mem_read(mem_base + mem.size - 512, 1024, timeout=5000, timeout_unit='ns')
    except Exception:
        pass
    else:
        assert False, "Expected exception"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_msi(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True, configure_msi=True)

    for k in range(32):
        tb.log.info("Send MSI %d", k)

        await RisingEdge(dut.clk)
        tb.dut.msi_irq.value = 1 << k
        await RisingEdge(dut.clk)
        tb.dut.msi_irq.value = 0

        event = tb.rc.msi_get_event(tb.dev.functions[0].pcie_id, k)
        event.clear()
        await event.wait()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_fifos(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate(enable_bus_mastering=True, configure_msi=True)

    tb.test_dev.dev_max_payload = tb.dev.functions[0].pcie_cap.max_payload_size
    tb.test_dev.dev_max_read_req = tb.dev.functions[0].pcie_cap.max_read_request_size
    tb.test_dev.dev_bus_num = tb.dev.bus_num

    dev_bar0 = tb.rc.tree[0][0].bar_window[0]

    test_data = bytearray([x for x in range(256)])

    for k in range(64):
        await dev_bar0.write(k*256, test_data, timeout=100)

    for k in range(64):
        assert await dev_bar0.read(k*256, len(test_data), timeout=50000) == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [
                run_test_mem,
                run_test_dma,
                run_test_dma_errors,
                run_test_msi,
            ]:

        factory = TestFactory(test)
        factory.add_option(("idle_inserter", "backpressure_inserter"), [(None, None), (cycle_pause, cycle_pause)])
        factory.generate_tests()

    factory = TestFactory(run_test_fifos)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("data_width", [256])
@pytest.mark.parametrize("l_tile", [0])
def test_pcie_s10_if(request, data_width, l_tile):
    dut = "pcie_s10_if"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_rx.v"),
        os.path.join(rtl_dir, f"{dut}_tx.v"),
        os.path.join(rtl_dir, "pcie_s10_cfg.v"),
        os.path.join(rtl_dir, "pcie_s10_msi.v"),
        os.path.join(rtl_dir, "arbiter.v"),
        os.path.join(rtl_dir, "priority_encoder.v"),
    ]

    parameters = {}

    # segmented interface parameters
    tlp_seg_count = 1
    tlp_seg_data_width = data_width // tlp_seg_count
    tlp_seg_strb_width = tlp_seg_data_width // 32

    parameters['SEG_COUNT'] = 2 if data_width == 512 else 1
    parameters['SEG_DATA_WIDTH'] = data_width // parameters['SEG_COUNT']
    parameters['SEG_EMPTY_WIDTH'] = ((parameters['SEG_DATA_WIDTH'] // 32) - 1).bit_length()
    parameters['TLP_SEG_COUNT'] = tlp_seg_count
    parameters['TLP_SEG_DATA_WIDTH'] = tlp_seg_data_width
    parameters['TLP_SEG_STRB_WIDTH'] = tlp_seg_strb_width
    parameters['TLP_SEG_HDR_WIDTH'] = 128
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['L_TILE'] = l_tile
    parameters['PF_COUNT'] = 1
    parameters['VF_COUNT'] = 0
    parameters['F_COUNT'] = parameters['PF_COUNT']+parameters['VF_COUNT']
    parameters['IO_BAR_INDEX'] = 3
    parameters['MSI_ENABLE'] = 1
    parameters['MSI_COUNT'] = 32

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
