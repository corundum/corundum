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
import sys

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from cocotbext.pcie.core import RootComplex

try:
    from pcie_if import PcieIfDevice, PcieIfRxBus, PcieIfTxBus
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from pcie_if import PcieIfDevice, PcieIfRxBus, PcieIfTxBus
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        # PCIe
        self.rc = RootComplex()

        self.dev = PcieIfDevice(
            # configuration options
            force_64bit_addr=False,
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
            pf0_msix_table_size=31,
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

            clk=dut.clk,
            rst=dut.rst,

            rx_req_tlp_bus=PcieIfRxBus.from_prefix(dut, "rx_req_tlp"),

            tx_cpl_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_cpl_tlp"),

            tx_wr_req_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_wr_req_tlp"),
            wr_req_tx_seq_num=dut.s_axis_wr_req_tx_seq_num,
            wr_req_tx_seq_num_valid=dut.s_axis_wr_req_tx_seq_num_valid,

            tx_rd_req_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_rd_req_tlp"),
            rd_req_tx_seq_num=dut.s_axis_rd_req_tx_seq_num,
            rd_req_tx_seq_num_valid=dut.s_axis_rd_req_tx_seq_num_valid,

            rx_cpl_tlp_bus=PcieIfRxBus.from_prefix(dut, "rx_cpl_tlp"),

            tx_msi_wr_req_tlp_bus=PcieIfTxBus.from_prefix(dut, "tx_msix_wr_req_tlp"),

            cfg_max_payload=dut.max_payload_size,
            cfg_max_read_req=dut.max_read_request_size,
            cfg_ext_tag_enable=dut.ext_tag_enable,
            cfg_rcb=dut.rcb_128b,
        )

        self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        self.dev.functions[0].configure_bar(0, 2**len(dut.axil_ctrl_awaddr))
        self.dev.functions[0].configure_bar(2, 2**len(dut.axi_ram_awaddr))
        self.dev.functions[0].configure_bar(4, 2**len(dut.axil_msix_awaddr))

        dut.bus_num.setimmediatevalue(0)

        dut.msix_enable.setimmediatevalue(0)
        dut.msix_mask.setimmediatevalue(0)

        # monitor error outputs
        self.status_error_cor_asserted = False
        self.status_error_uncor_asserted = False
        cocotb.start_soon(self._run_monitor_status_error_cor())
        cocotb.start_soon(self._run_monitor_status_error_uncor())

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
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


@cocotb.test()
async def run_test(dut):

    tb = TB(dut)

    await tb.cycle_reset()

    await tb.rc.enumerate()

    mem = tb.rc.mem_pool.alloc_region(16*1024*1024)
    mem_base = mem.get_absolute_address(0)

    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    await dev.enable_device()
    await dev.set_master()
    await dev.alloc_irq_vectors(32, 32)

    dev_pf0_bar0 = dev.bar_window[0]
    dev_pf0_bar2 = dev.bar_window[2]

    tb.dut.bus_num.value = tb.dev.bus_num
    tb.dut.msix_enable.value = tb.dev.functions[0].msix_cap.msix_enable
    tb.dut.msix_mask.value = tb.dev.functions[0].msix_cap.msix_function_mask

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
    status = await dev_pf0_bar0.read_dword(0x000000)
    tb.log.info("DMA Status: 0x%x", status)
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
    status = await dev_pf0_bar0.read_dword(0x000000)
    tb.log.info("DMA Status: 0x%x", status)
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
    status = await dev_pf0_bar0.read_dword(0x000000)
    tb.log.info("DMA Status: 0x%x", status)
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
        await Timer(1000, 'ns')
        run = await dev_pf0_bar0.read_dword(0x001000)
        if run == 0:
            break

    # read status
    status = await dev_pf0_bar0.read_dword(0x000000)
    tb.log.info("DMA Status: 0x%x", status)

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
        await Timer(1000, 'ns')
        run = await dev_pf0_bar0.read_dword(0x001100)
        if run == 0:
            break

    # read status
    status = await dev_pf0_bar0.read_dword(0x000000)
    tb.log.info("DMA Status: 0x%x", status)

    assert status & 0x300 == 0

    tb.log.info("%s", mem.hexdump_str(dest_offset, region_len))

    assert mem[src_offset:src_offset+region_len] == mem[dest_offset:dest_offset+region_len]

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..', '..', 'rtl'))


@pytest.mark.parametrize("pcie_data_width", [64, 128, 256, 512])
def test_example_core_pcie(request, pcie_data_width):
    dut = "example_core_pcie"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "example_core.v"),
        os.path.join(rtl_dir, "axi_ram.v"),
        os.path.join(pcie_rtl_dir, "pcie_axil_master.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master_rd.v"),
        os.path.join(pcie_rtl_dir, "pcie_axi_master_wr.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux_bar.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_mux.v"),
        os.path.join(pcie_rtl_dir, "pcie_msix.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_psdpram.v"),
        os.path.join(pcie_rtl_dir, "priority_encoder.v"),
        os.path.join(pcie_rtl_dir, "pulse_merge.v"),
    ]

    parameters = {}

    parameters['TLP_DATA_WIDTH'] = pcie_data_width
    parameters['TLP_STRB_WIDTH'] = parameters['TLP_DATA_WIDTH'] // 32
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_SEG_COUNT'] = 1
    parameters['TX_SEQ_NUM_COUNT'] = 1
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['TX_SEQ_NUM_ENABLE'] = 1
    parameters['PCIE_TAG_COUNT'] = 256
    parameters['IMM_ENABLE'] = 1
    parameters['IMM_WIDTH'] = 32
    parameters['READ_OP_TABLE_SIZE'] = parameters['PCIE_TAG_COUNT']
    parameters['READ_TX_LIMIT'] = 2**parameters['TX_SEQ_NUM_WIDTH']
    parameters['READ_CPLH_FC_LIMIT'] = 0
    parameters['READ_CPLD_FC_LIMIT'] = parameters['READ_CPLH_FC_LIMIT']*4
    parameters['WRITE_OP_TABLE_SIZE'] = 2**parameters['TX_SEQ_NUM_WIDTH']
    parameters['WRITE_TX_LIMIT'] = 2**parameters['TX_SEQ_NUM_WIDTH']
    parameters['TLP_FORCE_64_BIT_ADDR'] = 0
    parameters['CHECK_BUS_NUMBER'] = 1
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
