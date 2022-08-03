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

import logging
import os

import cocotb_test.simulator

import cocotb
from cocotb.log import SimLog
from cocotb.triggers import RisingEdge, FallingEdge, Timer

from cocotbext.pcie.core import RootComplex
from cocotbext.pcie.intel.ptile import PTilePcieDevice, PTileRxBus, PTileTxBus


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # PCIe
        self.rc = RootComplex()

        self.dev = PTilePcieDevice(
            # configuration options
            pcie_generation=3,
            pcie_link_width=16,
            pld_clk_frequency=250e6,
            pf_count=1,
            max_payload_size=512,
            enable_extended_tag=True,

            pf0_msi_enable=False,
            pf0_msi_count=1,
            pf1_msi_enable=False,
            pf1_msi_count=1,
            pf2_msi_enable=False,
            pf2_msi_count=1,
            pf3_msi_enable=False,
            pf3_msi_count=1,
            pf0_msix_enable=True,
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

        # self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        self.dev.functions[0].configure_bar(0, 2**len(dut.core_inst.core_pcie_inst.axil_ctrl_awaddr))
        self.dev.functions[0].configure_bar(2, 2**len(dut.core_inst.core_pcie_inst.axi_ram_awaddr))
        self.dev.functions[0].configure_bar(4, 2**len(dut.core_inst.core_pcie_inst.axil_msix_awaddr))

    async def init(self):

        await FallingEdge(self.dut.rst)
        await Timer(100, 'ns')

        await self.rc.enumerate()

        dev = self.rc.find_device(self.dev.functions[0].pcie_id)
        await dev.enable_device()
        await dev.set_master()
        await dev.alloc_irq_vectors(32, 32)


@cocotb.test()
async def run_test(dut):

    tb = TB(dut)

    await tb.init()

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)

    dev_pf0_bar0 = dev.bar_window[0]
    dev_pf0_bar2 = dev.bar_window[2]

    tb.log.info("Test memory write to BAR 2")

    test_data = b'\x11\x22\x33\x44'
    await dev_pf0_bar2.write(0, test_data)

    await Timer(100, 'ns')

    tb.log.info("Test memory read from BAR 2")

    val = await dev_pf0_bar2.read(0, len(test_data), timeout=1000)
    tb.log.info("Read data: %s", val)
    assert val == test_data

    tb.log.info("Test DMA")

    # write packet data
    mem[0:1024] = bytearray([x % 256 for x in range(1024)])

    # enable DMA
    await dev_pf0_bar0.write_dword(0x000000, 1)
    # enable interrupts
    await dev_pf0_bar0.write_dword(0x000008, 0x3)

    # write pcie read descriptor
    await dev_pf0_bar0.write_dword(0x000100, (mem_base+0x0000) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x000104, (mem_base+0x0000 >> 32) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x000108, 0x100)
    await dev_pf0_bar0.write_dword(0x000110, 0x400)
    await dev_pf0_bar0.write_dword(0x000114, 0xAA)

    await Timer(2000, 'ns')

    # read status
    val = await dev_pf0_bar0.read_dword(0x000118)
    tb.log.info("Status: 0x%x", val)
    assert val == 0x800000AA

    # write pcie write descriptor
    await dev_pf0_bar0.write_dword(0x000200, (mem_base+0x1000) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x000204, (mem_base+0x1000 >> 32) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x000208, 0x100)
    await dev_pf0_bar0.write_dword(0x000210, 0x400)
    await dev_pf0_bar0.write_dword(0x000214, 0x55)

    await Timer(2000, 'ns')

    # read status
    val = await dev_pf0_bar0.read_dword(0x000218)
    tb.log.info("Status: 0x%x", val)
    assert val == 0x80000055

    tb.log.info("%s", mem.hexdump_str(0x1000, 64))

    assert mem[0:1024] == mem[0x1000:0x1000+1024]

    tb.log.info("Test immediate write")

    # write pcie write descriptor
    await dev_pf0_bar0.write_dword(0x000200, (mem_base+0x1000) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x000204, (mem_base+0x1000 >> 32) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x000208, 0x44332211)
    await dev_pf0_bar0.write_dword(0x000210, 0x4)
    await dev_pf0_bar0.write_dword(0x000214, 0x800000AA)

    await Timer(2000, 'ns')

    # read status
    val = await dev_pf0_bar0.read_dword(0x000218)
    tb.log.info("Status: 0x%x", val)
    assert val == 0x800000AA

    tb.log.info("%s", mem.hexdump_str(0x1000, 64))

    assert mem[0x1000:0x1000+4] == b'\x11\x22\x33\x44'

    tb.log.info("Test DMA block operations")

    region_len = 0x2000
    src_offset = 0x0000
    dest_offset = 0x4000

    block_size = 256
    block_stride = block_size
    block_count = 32

    # write packet data
    mem[src_offset:src_offset+region_len] = bytearray([x % 256 for x in range(region_len)])

    # enable DMA
    await dev_pf0_bar0.write_dword(0x000000, 1)
    # disable interrupts
    await dev_pf0_bar0.write_dword(0x000008, 0)

    # configure operation (read)
    # DMA base address
    await dev_pf0_bar0.write_dword(0x001080, (mem_base+src_offset) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x001084, (mem_base+src_offset >> 32) & 0xffffffff)
    # DMA offset address
    await dev_pf0_bar0.write_dword(0x001088, 0)
    await dev_pf0_bar0.write_dword(0x00108c, 0)
    # DMA offset mask
    await dev_pf0_bar0.write_dword(0x001090, region_len-1)
    await dev_pf0_bar0.write_dword(0x001094, 0)
    # DMA stride
    await dev_pf0_bar0.write_dword(0x001098, block_stride)
    await dev_pf0_bar0.write_dword(0x00109c, 0)
    # RAM base address
    await dev_pf0_bar0.write_dword(0x0010c0, 0)
    await dev_pf0_bar0.write_dword(0x0010c4, 0)
    # RAM offset address
    await dev_pf0_bar0.write_dword(0x0010c8, 0)
    await dev_pf0_bar0.write_dword(0x0010cc, 0)
    # RAM offset mask
    await dev_pf0_bar0.write_dword(0x0010d0, region_len-1)
    await dev_pf0_bar0.write_dword(0x0010d4, 0)
    # RAM stride
    await dev_pf0_bar0.write_dword(0x0010d8, block_stride)
    await dev_pf0_bar0.write_dword(0x0010dc, 0)
    # clear cycle count
    await dev_pf0_bar0.write_dword(0x001008, 0)
    await dev_pf0_bar0.write_dword(0x00100c, 0)
    # block length
    await dev_pf0_bar0.write_dword(0x001010, block_size)
    # block count
    await dev_pf0_bar0.write_dword(0x001018, block_count)
    await dev_pf0_bar0.write_dword(0x00101c, 0)
    # start
    await dev_pf0_bar0.write_dword(0x001000, 1)

    for k in range(10):
        cnt = await dev_pf0_bar0.read_dword(0x001018)
        await Timer(1000, 'ns')
        if cnt == 0:
            break

    # configure operation (write)
    # DMA base address
    await dev_pf0_bar0.write_dword(0x001180, (mem_base+dest_offset) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x001184, (mem_base+dest_offset >> 32) & 0xffffffff)
    # DMA offset address
    await dev_pf0_bar0.write_dword(0x001188, 0)
    await dev_pf0_bar0.write_dword(0x00118c, 0)
    # DMA offset mask
    await dev_pf0_bar0.write_dword(0x001190, region_len-1)
    await dev_pf0_bar0.write_dword(0x001194, 0)
    # DMA stride
    await dev_pf0_bar0.write_dword(0x001198, block_stride)
    await dev_pf0_bar0.write_dword(0x00119c, 0)
    # RAM base address
    await dev_pf0_bar0.write_dword(0x0011c0, 0)
    await dev_pf0_bar0.write_dword(0x0011c4, 0)
    # RAM offset address
    await dev_pf0_bar0.write_dword(0x0011c8, 0)
    await dev_pf0_bar0.write_dword(0x0011cc, 0)
    # RAM offset mask
    await dev_pf0_bar0.write_dword(0x0011d0, region_len-1)
    await dev_pf0_bar0.write_dword(0x0011d4, 0)
    # RAM stride
    await dev_pf0_bar0.write_dword(0x0011d8, block_stride)
    await dev_pf0_bar0.write_dword(0x0011dc, 0)
    # clear cycle count
    await dev_pf0_bar0.write_dword(0x001108, 0)
    await dev_pf0_bar0.write_dword(0x00110c, 0)
    # block length
    await dev_pf0_bar0.write_dword(0x001110, block_size)
    # block count
    await dev_pf0_bar0.write_dword(0x001118, block_count)
    await dev_pf0_bar0.write_dword(0x00111c, 0)
    # start
    await dev_pf0_bar0.write_dword(0x001100, 1)

    for k in range(10):
        cnt = await dev_pf0_bar0.read_dword(0x001118)
        await Timer(1000, 'ns')
        if cnt == 0:
            break

    tb.log.info("%s", mem.hexdump_str(dest_offset, region_len))

    assert mem[src_offset:src_offset+region_len] == mem[dest_offset:dest_offset+region_len]

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
pcie_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'pcie', 'rtl'))


def test_fpga_core(request):
    dut = "fpga_core"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "common", "example_core_pcie_ptile.v"),
        os.path.join(rtl_dir, "common", "example_core_pcie.v"),
        os.path.join(rtl_dir, "common", "example_core.v"),
        os.path.join(rtl_dir, "common", "axi_ram.v"),
        os.path.join(pcie_rtl_dir, "pcie_ptile_if.v"),
        os.path.join(pcie_rtl_dir, "pcie_ptile_if_rx.v"),
        os.path.join(pcie_rtl_dir, "pcie_ptile_if_tx.v"),
        os.path.join(pcie_rtl_dir, "pcie_ptile_cfg.v"),
        os.path.join(pcie_rtl_dir, "pcie_ptile_fc_counter.v"),
        os.path.join(pcie_rtl_dir, "pcie_axil_master.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master_rd.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master_wr.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux_bar.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_mux.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_fc_count.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_fifo.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_fifo_raw.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_fifo_mux.v"),
        os.path.join(pcie_rtl_dir, "pcie_msix.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_psdpram.v"),
        os.path.join(pcie_rtl_dir, "priority_encoder.v"),
        os.path.join(pcie_rtl_dir, "pulse_merge.v"),
    ]

    parameters = {}

    parameters['SEG_COUNT'] = 2
    parameters['SEG_DATA_WIDTH'] = 256
    parameters['SEG_EMPTY_WIDTH'] = (parameters['SEG_DATA_WIDTH'] // 32 - 1).bit_length()
    parameters['SEG_HDR_WIDTH'] = 128
    parameters['SEG_PRFX_WIDTH'] = 32
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['PCIE_TAG_COUNT'] = 64
    parameters['BAR0_APERTURE'] = 24
    parameters['BAR2_APERTURE'] = 24
    parameters['BAR4_APERTURE'] = 16

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
