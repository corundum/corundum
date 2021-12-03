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

import logging
import os

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.log import SimLog
from cocotb.triggers import RisingEdge, FallingEdge, Timer

from cocotbext.pcie.core import RootComplex
from cocotbext.pcie.intel.s10 import S10PcieDevice, S10RxBus, S10TxBus


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
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

        self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        self.dev.functions[0].msi_multiple_message_capable = 5

        self.dev.functions[0].configure_bar(0, 2**len(dut.core_pcie_inst.axil_ctrl_awaddr))
        self.dev.functions[0].configure_bar(2, 2**len(dut.core_pcie_inst.axi_ram_awaddr))

    async def init(self):

        await FallingEdge(self.dut.rst)
        await Timer(100, 'ns')

        await self.rc.enumerate(enable_bus_mastering=True, configure_msi=True)


@cocotb.test()
async def run_test(dut):

    tb = TB(dut)

    await tb.init()

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    dev_pf0_bar0 = tb.rc.tree[0][0].bar_window[0]
    dev_pf0_bar2 = tb.rc.tree[0][0].bar_window[2]

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

    tb.log.info("Test DMA block operations")

    # write packet data
    mem[0:1024] = bytearray([x % 256 for x in range(1024)])

    # enable DMA
    await dev_pf0_bar0.write_dword(0x000000, 1)
    # disable interrupts
    await dev_pf0_bar0.write_dword(0x000008, 0)

    # configure operation (read)
    # DMA base address
    await dev_pf0_bar0.write_dword(0x001080, (mem_base+0x0000) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x001084, (mem_base+0x0000 >> 32) & 0xffffffff)
    # DMA offset address
    await dev_pf0_bar0.write_dword(0x001088, 0)
    await dev_pf0_bar0.write_dword(0x00108c, 0)
    # DMA offset mask
    await dev_pf0_bar0.write_dword(0x001090, 0x000003ff)
    await dev_pf0_bar0.write_dword(0x001094, 0)
    # DMA stride
    await dev_pf0_bar0.write_dword(0x001098, 256)
    await dev_pf0_bar0.write_dword(0x00109c, 0)
    # RAM base address
    await dev_pf0_bar0.write_dword(0x0010c0, 0)
    await dev_pf0_bar0.write_dword(0x0010c4, 0)
    # RAM offset address
    await dev_pf0_bar0.write_dword(0x0010c8, 0)
    await dev_pf0_bar0.write_dword(0x0010cc, 0)
    # RAM offset mask
    await dev_pf0_bar0.write_dword(0x0010d0, 0x000003ff)
    await dev_pf0_bar0.write_dword(0x0010d4, 0)
    # RAM stride
    await dev_pf0_bar0.write_dword(0x0010d8, 256)
    await dev_pf0_bar0.write_dword(0x0010dc, 0)
    # clear cycle count
    await dev_pf0_bar0.write_dword(0x001008, 0)
    await dev_pf0_bar0.write_dword(0x00100c, 0)
    # block length
    await dev_pf0_bar0.write_dword(0x001010, 256)
    # block count
    await dev_pf0_bar0.write_dword(0x001018, 32)
    await dev_pf0_bar0.write_dword(0x00101c, 0)
    # start
    await dev_pf0_bar0.write_dword(0x001000, 1)

    await Timer(2000, 'ns')

    # configure operation (write)
    # DMA base address
    await dev_pf0_bar0.write_dword(0x001180, (mem_base+0x0000) & 0xffffffff)
    await dev_pf0_bar0.write_dword(0x001184, (mem_base+0x0000 >> 32) & 0xffffffff)
    # DMA offset address
    await dev_pf0_bar0.write_dword(0x001188, 0)
    await dev_pf0_bar0.write_dword(0x00118c, 0)
    # DMA offset mask
    await dev_pf0_bar0.write_dword(0x001190, 0x000003ff)
    await dev_pf0_bar0.write_dword(0x001194, 0)
    # DMA stride
    await dev_pf0_bar0.write_dword(0x001198, 256)
    await dev_pf0_bar0.write_dword(0x00119c, 0)
    # RAM base address
    await dev_pf0_bar0.write_dword(0x0011c0, 0)
    await dev_pf0_bar0.write_dword(0x0011c4, 0)
    # RAM offset address
    await dev_pf0_bar0.write_dword(0x0011c8, 0)
    await dev_pf0_bar0.write_dword(0x0011cc, 0)
    # RAM offset mask
    await dev_pf0_bar0.write_dword(0x0011d0, 0x000003ff)
    await dev_pf0_bar0.write_dword(0x0011d4, 0)
    # RAM stride
    await dev_pf0_bar0.write_dword(0x0011d8, 256)
    await dev_pf0_bar0.write_dword(0x0011dc, 0)
    # clear cycle count
    await dev_pf0_bar0.write_dword(0x001108, 0)
    await dev_pf0_bar0.write_dword(0x00110c, 0)
    # block length
    await dev_pf0_bar0.write_dword(0x001110, 256)
    # block count
    await dev_pf0_bar0.write_dword(0x001118, 32)
    await dev_pf0_bar0.write_dword(0x00111c, 0)
    # start
    await dev_pf0_bar0.write_dword(0x001100, 1)

    await Timer(2000, 'ns')

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..', '..', 'rtl'))


@pytest.mark.parametrize("data_width", [256])
@pytest.mark.parametrize("l_tile", [0, 1])
def test_example_core_pcie_s10(request, data_width, l_tile):
    dut = "example_core_pcie_s10"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "example_core_pcie.v"),
        os.path.join(rtl_dir, "example_core.v"),
        os.path.join(rtl_dir, "axi_ram.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_if.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_if_rx.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_if_tx.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_cfg.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_msi.v"),
        os.path.join(pcie_rtl_dir, "pcie_axil_master.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master_rd.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master_wr.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux_bar.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_mux.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_psdpram.v"),
        os.path.join(pcie_rtl_dir, "arbiter.v"),
        os.path.join(pcie_rtl_dir, "priority_encoder.v"),
        os.path.join(pcie_rtl_dir, "pulse_merge.v"),
    ]

    parameters = {}

    parameters['SEG_COUNT'] = 2 if data_width == 512 else 1
    parameters['SEG_DATA_WIDTH'] = data_width // parameters['SEG_COUNT']
    parameters['SEG_EMPTY_WIDTH'] = ((parameters['SEG_DATA_WIDTH'] // 32) - 1).bit_length()
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['TX_SEQ_NUM_ENABLE'] = 1
    parameters['L_TILE'] = l_tile
    parameters['PCIE_TAG_COUNT'] = 256
    parameters['READ_OP_TABLE_SIZE'] = parameters['PCIE_TAG_COUNT']
    parameters['READ_TX_LIMIT'] = 2**parameters['TX_SEQ_NUM_WIDTH']
    parameters['READ_TX_FC_ENABLE'] = 1
    parameters['WRITE_OP_TABLE_SIZE'] = 2**parameters['TX_SEQ_NUM_WIDTH']
    parameters['WRITE_TX_LIMIT'] = 2**parameters['TX_SEQ_NUM_WIDTH']
    parameters['WRITE_TX_FC_ENABLE'] = 1
    parameters['BAR0_APERTURE'] = 24
    parameters['BAR2_APERTURE'] = 24

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
