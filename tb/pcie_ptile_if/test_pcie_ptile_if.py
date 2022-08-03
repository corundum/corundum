#!/usr/bin/env python
"""

Copyright (c) 2022 Alex Forencich

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
from cocotbext.pcie.intel.ptile import PTilePcieDevice, PTileRxBus, PTileTxBus

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
    def __init__(self, dut, msix=False):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # PCIe
        self.rc = RootComplex()

        self.dev = PTilePcieDevice(
            # configuration options
            pcie_generation=3,
            # pcie_link_width=2,
            # pld_clk_frequency=250e6,
            pf_count=1,
            max_payload_size=1024,
            enable_extended_tag=True,

            pf0_msi_enable=True,
            pf0_msi_count=32,
            pf1_msi_enable=False,
            pf1_msi_count=1,
            pf2_msi_enable=False,
            pf2_msi_count=1,
            pf3_msi_enable=False,
            pf3_msi_count=1,
            pf0_msix_enable=msix,
            pf0_msix_table_size=63,
            pf0_msix_table_bir=4,
            pf0_msix_table_offset=0x00000000,
            pf0_msix_pba_bir=4,
            pf0_msix_pba_offset=0x00008000,
            pf1_msix_enable=False,
            pf1_msix_table_size=0,
            pf1_msix_table_bir=0,
            pf1_msix_table_offset=0x00000000,
            pf1_msix_pba_bir=0,
            pf1_msix_pba_offset=0x00000000,
            pf2_msix_enable=False,
            pf2_msix_table_size=0,
            pf2_msix_table_bir=0,
            pf2_msix_table_offset=0x00000000,
            pf2_msix_pba_bir=0,
            pf2_msix_pba_offset=0x00000000,
            pf3_msix_enable=False,
            pf3_msix_table_size=0,
            pf3_msix_table_bir=0,
            pf3_msix_table_offset=0x00000000,
            pf3_msix_pba_bir=0,
            pf3_msix_pba_offset=0x00000000,

            # signals
            # Clock and reset
            reset_status=dut.rst,
            # reset_status_n=dut.reset_status_n,
            coreclkout_hip=dut.clk,
            # refclk0=dut.refclk0,
            # refclk1=dut.refclk1,
            # pin_perst_n=dut.pin_perst_n,

            # RX interface
            rx_bus=PTileRxBus.from_prefix(dut, "rx_st"),
            # rx_par_err=dut.rx_par_err,

            # TX interface
            tx_bus=PTileTxBus.from_prefix(dut, "tx_st"),
            # tx_par_err=dut.tx_par_err,

            # RX flow control
            rx_buffer_limit=dut.rx_buffer_limit,
            rx_buffer_limit_tdm_idx=dut.rx_buffer_limit_tdm_idx,

            # TX flow control
            tx_cdts_limit=dut.tx_cdts_limit,
            tx_cdts_limit_tdm_idx=dut.tx_cdts_limit_tdm_idx,

            # Power management and hard IP status interface
            # link_up=dut.link_up,
            # dl_up=dut.dl_up,
            # surprise_down_err=dut.surprise_down_err,
            # ltssm_state=dut.ltssm_state,
            # pm_state=dut.pm_state,
            # pm_dstate=dut.pm_dstate,
            # apps_pm_xmt_pme=dut.apps_pm_xmt_pme,
            # app_req_retry_en=dut.app_req_retry_en,

            # Interrupt interface
            # app_int=dut.app_int,
            # msi_pnd_func=dut.msi_pnd_func,
            # msi_pnd_byte=dut.msi_pnd_byte,
            # msi_pnd_addr=dut.msi_pnd_addr,

            # Error interface
            # serr_out=dut.serr_out,
            # hip_enter_err_mode=dut.hip_enter_err_mode,
            # app_err_valid=dut.app_err_valid,
            # app_err_hdr=dut.app_err_hdr,
            # app_err_info=dut.app_err_info,
            # app_err_func_num=dut.app_err_func_num,

            # Completion timeout interface
            # cpl_timeout=dut.cpl_timeout,
            # cpl_timeout_avmm_clk=dut.cpl_timeout_avmm_clk,
            # cpl_timeout_avmm_address=dut.cpl_timeout_avmm_address,
            # cpl_timeout_avmm_read=dut.cpl_timeout_avmm_read,
            # cpl_timeout_avmm_readdata=dut.cpl_timeout_avmm_readdata,
            # cpl_timeout_avmm_readdatavalid=dut.cpl_timeout_avmm_readdatavalid,
            # cpl_timeout_avmm_write=dut.cpl_timeout_avmm_write,
            # cpl_timeout_avmm_writedata=dut.cpl_timeout_avmm_writedata,
            # cpl_timeout_avmm_waitrequest=dut.cpl_timeout_avmm_waitrequest,

            # Configuration output
            tl_cfg_func=dut.tl_cfg_func,
            tl_cfg_add=dut.tl_cfg_add,
            tl_cfg_ctl=dut.tl_cfg_ctl,
            # dl_timer_update=dut.dl_timer_update,

            # Configuration intercept interface
            # cii_req=dut.cii_req,
            # cii_hdr_poisoned=dut.cii_hdr_poisoned,
            # cii_hdr_first_be=dut.cii_hdr_first_be,
            # cii_func_num=dut.cii_func_num,
            # cii_wr_vf_active=dut.cii_wr_vf_active,
            # cii_vf_num=dut.cii_vf_num,
            # cii_wr=dut.cii_wr,
            # cii_addr=dut.cii_addr,
            # cii_dout=dut.cii_dout,
            # cii_override_en=dut.cii_override_en,
            # cii_override_din=dut.cii_override_din,
            # cii_halt=dut.cii_halt,

            # Hard IP reconfiguration interface
            # hip_reconfig_clk=dut.hip_reconfig_clk,
            # hip_reconfig_address=dut.hip_reconfig_address,
            # hip_reconfig_read=dut.hip_reconfig_read,
            # hip_reconfig_readdata=dut.hip_reconfig_readdata,
            # hip_reconfig_readdatavalid=dut.hip_reconfig_readdatavalid,
            # hip_reconfig_write=dut.hip_reconfig_write,
            # hip_reconfig_writedata=dut.hip_reconfig_writedata,
            # hip_reconfig_waitrequest=dut.hip_reconfig_waitrequest,

            # Page request service
            # prs_event_valid=dut.prs_event_valid,
            # prs_event_func=dut.prs_event_func,
            # prs_event=dut.prs_event,

            # SR-IOV (VF error)
            # vf_err_ur_posted_s0=dut.vf_err_ur_posted_s0,
            # vf_err_ur_posted_s1=dut.vf_err_ur_posted_s1,
            # vf_err_ur_posted_s2=dut.vf_err_ur_posted_s2,
            # vf_err_ur_posted_s3=dut.vf_err_ur_posted_s3,
            # vf_err_func_num_s0=dut.vf_err_func_num_s0,
            # vf_err_func_num_s1=dut.vf_err_func_num_s1,
            # vf_err_func_num_s2=dut.vf_err_func_num_s2,
            # vf_err_func_num_s3=dut.vf_err_func_num_s3,
            # vf_err_ca_postedreq_s0=dut.vf_err_ca_postedreq_s0,
            # vf_err_ca_postedreq_s1=dut.vf_err_ca_postedreq_s1,
            # vf_err_ca_postedreq_s2=dut.vf_err_ca_postedreq_s2,
            # vf_err_ca_postedreq_s3=dut.vf_err_ca_postedreq_s3,
            # vf_err_vf_num_s0=dut.vf_err_vf_num_s0,
            # vf_err_vf_num_s1=dut.vf_err_vf_num_s1,
            # vf_err_vf_num_s2=dut.vf_err_vf_num_s2,
            # vf_err_vf_num_s3=dut.vf_err_vf_num_s3,
            # vf_err_poisonedwrreq_s0=dut.vf_err_poisonedwrreq_s0,
            # vf_err_poisonedwrreq_s1=dut.vf_err_poisonedwrreq_s1,
            # vf_err_poisonedwrreq_s2=dut.vf_err_poisonedwrreq_s2,
            # vf_err_poisonedwrreq_s3=dut.vf_err_poisonedwrreq_s3,
            # vf_err_poisonedcompl_s0=dut.vf_err_poisonedcompl_s0,
            # vf_err_poisonedcompl_s1=dut.vf_err_poisonedcompl_s1,
            # vf_err_poisonedcompl_s2=dut.vf_err_poisonedcompl_s2,
            # vf_err_poisonedcompl_s3=dut.vf_err_poisonedcompl_s3,
            # user_vfnonfatalmsg_func_num=dut.user_vfnonfatalmsg_func_num,
            # user_vfnonfatalmsg_vfnum=dut.user_vfnonfatalmsg_vfnum,
            # user_sent_vfnonfatalmsg=dut.user_sent_vfnonfatalmsg,
            # vf_err_overflow=dut.vf_err_overflow,

            # FLR
            # flr_rcvd_pf=dut.flr_rcvd_pf,
            # flr_rcvd_vf=dut.flr_rcvd_vf,
            # flr_rcvd_pf_num=dut.flr_rcvd_pf_num,
            # flr_rcvd_vf_num=dut.flr_rcvd_vf_num,
            # flr_completed_pf=dut.flr_completed_pf,
            # flr_completed_vf=dut.flr_completed_vf,
            # flr_completed_pf_num=dut.flr_completed_pf_num,
            # flr_completed_vf_num=dut.flr_completed_vf_num,

            # VirtIO
            # virtio_pcicfg_vfaccess=dut.virtio_pcicfg_vfaccess,
            # virtio_pcicfg_vfnum=dut.virtio_pcicfg_vfnum,
            # virtio_pcicfg_pfnum=dut.virtio_pcicfg_pfnum,
            # virtio_pcicfg_bar=dut.virtio_pcicfg_bar,
            # virtio_pcicfg_length=dut.virtio_pcicfg_length,
            # virtio_pcicfg_baroffset=dut.virtio_pcicfg_baroffset,
            # virtio_pcicfg_cfgdata=dut.virtio_pcicfg_cfgdata,
            # virtio_pcicfg_cfgwr=dut.virtio_pcicfg_cfgwr,
            # virtio_pcicfg_cfgrd=dut.virtio_pcicfg_cfgrd,
            # virtio_pcicfg_appvfnum=dut.virtio_pcicfg_appvfnum,
            # virtio_pcicfg_apppfnum=dut.virtio_pcicfg_apppfnum,
            # virtio_pcicfg_rdack=dut.virtio_pcicfg_rdack,
            # virtio_pcicfg_rdbe=dut.virtio_pcicfg_rdbe,
            # virtio_pcicfg_data=dut.virtio_pcicfg_data,
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

            tx_msi_wr_req_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_msi_wr_req_tlp"),
        )

        self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        self.dev.functions[0].configure_bar(0, 1024*1024)
        self.test_dev.add_mem_region(1024*1024)
        self.dev.functions[0].configure_bar(1, 1024*1024, True, True)
        self.test_dev.add_prefetchable_mem_region(1024*1024)
        self.dev.functions[0].configure_bar(3, 1024, False, False, True)
        self.test_dev.add_io_region(1024)
        self.dev.functions[0].configure_bar(4, 64*1024)
        self.test_dev.add_mem_region(64*1024)

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

    await tb.rc.enumerate()

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    await dev.enable_device()

    tb.test_dev.dev_max_payload = tb.dev.functions[0].pcie_cap.max_payload_size
    tb.test_dev.dev_max_read_req = tb.dev.functions[0].pcie_cap.max_read_request_size
    tb.test_dev.dev_bus_num = tb.dev.bus_num

    dev_bar0 = dev.bar_window[0]
    dev_bar1 = dev.bar_window[1]
    dev_bar3 = dev.bar_window[3]

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

    await tb.rc.enumerate()

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    await dev.enable_device()
    await dev.set_master()

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

    await tb.rc.enumerate()

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    await dev.enable_device()
    await dev.set_master()

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

    await tb.rc.enumerate()

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    await dev.enable_device()
    await dev.set_master()
    await dev.alloc_irq_vectors(32, 32)

    for k in range(32):
        tb.log.info("Send MSI %d", k)

        addr = tb.dev.functions[0].msi_cap.msi_message_address
        data = tb.dev.functions[0].msi_cap.msi_message_data | k

        await tb.test_dev.issue_msi_interrupt(addr, data)

        event = dev.msi_vectors[k].event
        event.clear()
        await event.wait()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_msix(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut, msix=True)

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    await FallingEdge(dut.rst)
    await Timer(100, 'ns')

    await tb.rc.enumerate()

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    await dev.enable_device()
    await dev.set_master()
    await dev.alloc_irq_vectors(64, 64)

    for k in range(64):
        tb.log.info("Send MSI-X %d", k)

        addr = int.from_bytes(tb.test_dev.regions[4][1][16*k+0:16*k+8], 'little')
        data = int.from_bytes(tb.test_dev.regions[4][1][16*k+8:16*k+12], 'little')

        await tb.test_dev.issue_msi_interrupt(addr, data)

        event = dev.msi_vectors[k].event
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

    await tb.rc.enumerate()

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    await dev.enable_device()
    await dev.set_master()

    tb.test_dev.dev_max_payload = tb.dev.functions[0].pcie_cap.max_payload_size
    tb.test_dev.dev_max_read_req = tb.dev.functions[0].pcie_cap.max_read_request_size
    tb.test_dev.dev_bus_num = tb.dev.bus_num

    dev_bar0 = dev.bar_window[0]

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
                run_test_msix,
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


@pytest.mark.parametrize("data_width", [128, 256, 512])
def test_pcie_ptile_if(request, data_width):
    dut = "pcie_ptile_if"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_rx.v"),
        os.path.join(rtl_dir, f"{dut}_tx.v"),
        os.path.join(rtl_dir, "pcie_ptile_cfg.v"),
        os.path.join(rtl_dir, "pcie_ptile_fc_counter.v"),
        os.path.join(rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(rtl_dir, "pcie_tlp_fc_count.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_raw.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_mux.v"),
    ]

    parameters = {}

    parameters['SEG_COUNT'] = 2 if data_width == 512 else 1
    parameters['SEG_DATA_WIDTH'] = data_width // parameters['SEG_COUNT']
    parameters['SEG_EMPTY_WIDTH'] = ((parameters['SEG_DATA_WIDTH'] // 32) - 1).bit_length()
    parameters['SEG_HDR_WIDTH'] = 128
    parameters['SEG_PRFX_WIDTH'] = 32
    parameters['TLP_DATA_WIDTH'] = data_width
    parameters['TLP_STRB_WIDTH'] = parameters['TLP_DATA_WIDTH'] // 32
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_SEG_COUNT'] = 1
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['PF_COUNT'] = 1
    parameters['VF_COUNT'] = 0
    parameters['F_COUNT'] = parameters['PF_COUNT']+parameters['VF_COUNT']
    parameters['IO_BAR_INDEX'] = 3

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
