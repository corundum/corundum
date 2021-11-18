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

from cocotbext.axi import AxiStreamBus
from cocotbext.pcie.core import RootComplex
from cocotbext.pcie.xilinx.us import UltraScalePlusPcieDevice

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
            # Clock and Reset Interface
            user_clk=dut.clk,
            user_reset=dut.rst,
            # user_lnk_up
            # sys_clk
            # sys_clk_gt
            # sys_reset
            # phy_rdy_out

            # Requester reQuest Interface
            rq_bus=AxiStreamBus.from_prefix(dut, "m_axis_rq"),
            pcie_rq_seq_num0=dut.s_axis_rq_seq_num_0,
            pcie_rq_seq_num_vld0=dut.s_axis_rq_seq_num_valid_0,
            pcie_rq_seq_num1=dut.s_axis_rq_seq_num_1,
            pcie_rq_seq_num_vld1=dut.s_axis_rq_seq_num_valid_1,
            # pcie_rq_tag0
            # pcie_rq_tag1
            # pcie_rq_tag_av
            # pcie_rq_tag_vld0
            # pcie_rq_tag_vld1

            # Requester Completion Interface
            rc_bus=AxiStreamBus.from_prefix(dut, "s_axis_rc"),

            # Completer reQuest Interface
            cq_bus=AxiStreamBus.from_prefix(dut, "s_axis_cq"),
            # pcie_cq_np_req
            # pcie_cq_np_req_count

            # Completer Completion Interface
            cc_bus=AxiStreamBus.from_prefix(dut, "m_axis_cc"),

            # Transmit Flow Control Interface
            # pcie_tfc_nph_av=dut.pcie_tfc_nph_av,
            # pcie_tfc_npd_av=dut.pcie_tfc_npd_av,

            # Configuration Management Interface
            cfg_mgmt_addr=dut.cfg_mgmt_addr,
            cfg_mgmt_function_number=dut.cfg_mgmt_function_number,
            cfg_mgmt_write=dut.cfg_mgmt_write,
            cfg_mgmt_write_data=dut.cfg_mgmt_write_data,
            cfg_mgmt_byte_enable=dut.cfg_mgmt_byte_enable,
            cfg_mgmt_read=dut.cfg_mgmt_read,
            cfg_mgmt_read_data=dut.cfg_mgmt_read_data,
            cfg_mgmt_read_write_done=dut.cfg_mgmt_read_write_done,
            # cfg_mgmt_debug_access

            # Configuration Status Interface
            # cfg_phy_link_down
            # cfg_phy_link_status
            # cfg_negotiated_width
            # cfg_current_speed
            # cfg_max_payload
            # cfg_max_read_req
            # cfg_function_status
            # cfg_vf_status
            # cfg_function_power_state
            # cfg_vf_power_state
            # cfg_link_power_state
            # cfg_err_cor_out
            # cfg_err_nonfatal_out
            # cfg_err_fatal_out
            # cfg_local_error_out
            # cfg_local_error_valid
            # cfg_rx_pm_state
            # cfg_tx_pm_state
            # cfg_ltssm_state
            # cfg_rcb_status
            # cfg_obff_enable
            # cfg_pl_status_change
            # cfg_tph_requester_enable
            # cfg_tph_st_mode
            # cfg_vf_tph_requester_enable
            # cfg_vf_tph_st_mode

            # Configuration Received Message Interface
            # cfg_msg_received
            # cfg_msg_received_data
            # cfg_msg_received_type

            # Configuration Transmit Message Interface
            # cfg_msg_transmit
            # cfg_msg_transmit_type
            # cfg_msg_transmit_data
            # cfg_msg_transmit_done

            # Configuration Flow Control Interface
            cfg_fc_ph=dut.cfg_fc_ph,
            cfg_fc_pd=dut.cfg_fc_pd,
            cfg_fc_nph=dut.cfg_fc_nph,
            cfg_fc_npd=dut.cfg_fc_npd,
            cfg_fc_cplh=dut.cfg_fc_cplh,
            cfg_fc_cpld=dut.cfg_fc_cpld,
            cfg_fc_sel=dut.cfg_fc_sel,

            # Configuration Control Interface
            # cfg_hot_reset_in
            # cfg_hot_reset_out
            # cfg_config_space_enable
            # cfg_dsn
            # cfg_bus_number
            # cfg_ds_port_number
            # cfg_ds_bus_number
            # cfg_ds_device_number
            # cfg_ds_function_number
            # cfg_power_state_change_ack
            # cfg_power_state_change_interrupt
            # cfg_err_cor_in
            # cfg_err_uncor_in
            # cfg_flr_in_process
            # cfg_flr_done
            # cfg_vf_flr_in_process
            # cfg_vf_flr_func_num
            # cfg_vf_flr_done
            # cfg_pm_aspm_l1_entry_reject
            # cfg_pm_aspm_tx_l0s_entry_disable
            # cfg_req_pm_transition_l23_ready
            # cfg_link_training_enable

            # Configuration Interrupt Controller Interface
            # cfg_interrupt_int
            # cfg_interrupt_sent
            # cfg_interrupt_pending
            cfg_interrupt_msi_enable=dut.cfg_interrupt_msi_enable,
            cfg_interrupt_msi_mmenable=dut.cfg_interrupt_msi_mmenable,
            cfg_interrupt_msi_mask_update=dut.cfg_interrupt_msi_mask_update,
            cfg_interrupt_msi_data=dut.cfg_interrupt_msi_data,
            # cfg_interrupt_msi_select=dut.cfg_interrupt_msi_select,
            cfg_interrupt_msi_int=dut.cfg_interrupt_msi_int,
            cfg_interrupt_msi_pending_status=dut.cfg_interrupt_msi_pending_status,
            cfg_interrupt_msi_pending_status_data_enable=dut.cfg_interrupt_msi_pending_status_data_enable,
            # cfg_interrupt_msi_pending_status_function_num=dut.cfg_interrupt_msi_pending_status_function_num,
            cfg_interrupt_msi_sent=dut.cfg_interrupt_msi_sent,
            cfg_interrupt_msi_fail=dut.cfg_interrupt_msi_fail,
            # cfg_interrupt_msix_enable
            # cfg_interrupt_msix_mask
            # cfg_interrupt_msix_vf_enable
            # cfg_interrupt_msix_vf_mask
            # cfg_interrupt_msix_address
            # cfg_interrupt_msix_data
            # cfg_interrupt_msix_int
            # cfg_interrupt_msix_vec_pending
            # cfg_interrupt_msix_vec_pending_status
            cfg_interrupt_msi_attr=dut.cfg_interrupt_msi_attr,
            cfg_interrupt_msi_tph_present=dut.cfg_interrupt_msi_tph_present,
            cfg_interrupt_msi_tph_type=dut.cfg_interrupt_msi_tph_type,
            # cfg_interrupt_msi_tph_st_tag=dut.cfg_interrupt_msi_tph_st_tag,
            # cfg_interrupt_msi_function_number=dut.cfg_interrupt_msi_function_number,

            # Configuration Extend Interface
            # cfg_ext_read_received
            # cfg_ext_write_received
            # cfg_ext_register_number
            # cfg_ext_function_number
            # cfg_ext_write_data
            # cfg_ext_write_byte_enable
            # cfg_ext_read_data
            # cfg_ext_read_data_valid
        )

        self.test_dev = PcieIfTestDevice(
            force_64bit_addr=True,

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
            self.dev.rc_source.set_pause_generator(generator())
            self.dev.cq_source.set_pause_generator(generator())
            self.test_dev.tx_cpl_tlp_source.set_pause_generator(generator())
            self.test_dev.tx_rd_req_tlp_source.set_pause_generator(generator())
            self.test_dev.tx_wr_req_tlp_source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.dev.rq_sink.set_pause_generator(generator())
            self.dev.cc_sink.set_pause_generator(generator())
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
            await tb.test_dev.dma_mem_read(addr, 1, timeout=5000, timeout_unit='ns')
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


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("axis_pcie_data_width", [64, 128, 256, 512])
def test_pcie_us_if(request, axis_pcie_data_width):
    dut = "pcie_us_if"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_rc.v"),
        os.path.join(rtl_dir, f"{dut}_rq.v"),
        os.path.join(rtl_dir, f"{dut}_cc.v"),
        os.path.join(rtl_dir, f"{dut}_cq.v"),
        os.path.join(rtl_dir, "pcie_us_cfg.v"),
        os.path.join(rtl_dir, "pcie_us_msi.v"),
        os.path.join(rtl_dir, "arbiter.v"),
        os.path.join(rtl_dir, "priority_encoder.v"),
    ]

    parameters = {}

    # segmented interface parameters
    tlp_seg_count = 1
    tlp_seg_data_width = axis_pcie_data_width // tlp_seg_count
    tlp_seg_strb_width = tlp_seg_data_width // 32

    parameters['AXIS_PCIE_DATA_WIDTH'] = axis_pcie_data_width
    parameters['AXIS_PCIE_KEEP_WIDTH'] = parameters['AXIS_PCIE_DATA_WIDTH'] // 32
    parameters['AXIS_PCIE_RQ_USER_WIDTH'] = 62 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 137
    parameters['AXIS_PCIE_RC_USER_WIDTH'] = 75 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 161
    parameters['AXIS_PCIE_CQ_USER_WIDTH'] = 88 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 183
    parameters['AXIS_PCIE_CC_USER_WIDTH'] = 33 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 81
    parameters['RQ_SEQ_NUM_WIDTH'] = 4 if parameters['AXIS_PCIE_RQ_USER_WIDTH'] == 60 else 6
    parameters['TLP_SEG_COUNT'] = tlp_seg_count
    parameters['TLP_SEG_DATA_WIDTH'] = tlp_seg_data_width
    parameters['TLP_SEG_STRB_WIDTH'] = tlp_seg_strb_width
    parameters['TLP_SEG_HDR_WIDTH'] = 128
    parameters['TX_SEQ_NUM_COUNT'] = 1 if parameters['AXIS_PCIE_DATA_WIDTH'] < 512 else 2
    parameters['TX_SEQ_NUM_WIDTH'] = parameters['RQ_SEQ_NUM_WIDTH']-1
    parameters['PF_COUNT'] = 1
    parameters['VF_COUNT'] = 0
    parameters['F_COUNT'] = parameters['PF_COUNT']+parameters['VF_COUNT']
    parameters['READ_EXT_TAG_ENABLE'] = 1
    parameters['READ_MAX_READ_REQ_SIZE'] = 1
    parameters['READ_MAX_PAYLOAD_SIZE'] = 1
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
