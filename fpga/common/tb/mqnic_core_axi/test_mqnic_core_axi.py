"""

Copyright 2021, The Regents of the University of California.
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
import sys

import scapy.utils
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from cocotbext.axi import AxiStreamBus
from cocotbext.axi import AddressSpace
from cocotbext.axi import AxiLiteMaster, AxiLiteBus
from cocotbext.axi import AxiSlave, AxiBus
from cocotbext.eth import EthMac

try:
    import mqnic
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        import mqnic
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        # AXI
        self.address_space = AddressSpace()
        self.pool = self.address_space.create_pool(0, 0x8000_0000)

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil_ctrl"), dut.clk, dut.rst)
        self.address_space.register_region(self.axil_master, 0x10_0000_0000)
        self.hw_regs = self.address_space.create_window(0x10_0000_0000, self.axil_master.size)

        self.axi_slave = AxiSlave(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst, self.address_space)

        self.driver = mqnic.Driver()

        # Ethernet
        self.port_mac = []

        eth_int_if_width = len(dut.core_inst.iface[0].port[0].rx_async_fifo_inst.m_axis_tdata)
        eth_clock_period = 6.4
        eth_speed = 10e9

        if eth_int_if_width == 64:
            # 10G
            eth_clock_period = 6.4
            eth_speed = 10e9
        elif eth_int_if_width == 128:
            # 25G
            eth_clock_period = 2.56
            eth_speed = 25e9
        elif eth_int_if_width == 512:
            # 100G
            eth_clock_period = 3.102
            eth_speed = 100e9

        for iface in dut.core_inst.iface:
            for port in iface.port:
                cocotb.start_soon(Clock(port.port_rx_clk, eth_clock_period, units="ns").start())
                cocotb.start_soon(Clock(port.port_tx_clk, eth_clock_period, units="ns").start())

                port.port_rx_rst.setimmediatevalue(0)
                port.port_tx_rst.setimmediatevalue(0)

                mac = EthMac(
                    tx_clk=port.port_tx_clk,
                    tx_rst=port.port_tx_rst,
                    tx_bus=AxiStreamBus.from_prefix(port, "axis_tx"),
                    tx_ptp_time=port.ptp.tx_ptp_cdc_inst.output_ts,
                    tx_ptp_ts=port.ptp.axis_tx_ptp_ts,
                    tx_ptp_ts_tag=port.ptp.axis_tx_ptp_ts_tag,
                    tx_ptp_ts_valid=port.ptp.axis_tx_ptp_ts_valid,
                    rx_clk=port.port_rx_clk,
                    rx_rst=port.port_rx_rst,
                    rx_bus=AxiStreamBus.from_prefix(port, "axis_rx"),
                    rx_ptp_time=port.ptp.rx_ptp_cdc_inst.output_ts,
                    ifg=12, speed=eth_speed
                )

                self.port_mac.append(mac)

        dut.ctrl_reg_wr_wait.setimmediatevalue(0)
        dut.ctrl_reg_wr_ack.setimmediatevalue(0)
        dut.ctrl_reg_rd_data.setimmediatevalue(0)
        dut.ctrl_reg_rd_wait.setimmediatevalue(0)
        dut.ctrl_reg_rd_ack.setimmediatevalue(0)

        dut.ptp_sample_clk.setimmediatevalue(0)

        dut.s_axis_stat_tdata.setimmediatevalue(0)
        dut.s_axis_stat_tid.setimmediatevalue(0)
        dut.s_axis_stat_tvalid.setimmediatevalue(0)

        self.loopback_enable = False
        cocotb.start_soon(self._run_loopback())

    async def init(self):

        self.dut.rst.setimmediatevalue(0)
        for mac in self.port_mac:
            mac.rx.reset.setimmediatevalue(0)
            mac.tx.reset.setimmediatevalue(0)

        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

        self.dut.rst.value = 1
        for mac in self.port_mac:
            mac.rx.reset.value = 1
            mac.tx.reset.value = 1

        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

        self.dut.rst.value = 0
        for mac in self.port_mac:
            mac.rx.reset.value = 0
            mac.tx.reset.value = 0

    async def _run_loopback(self):
        while True:
            await RisingEdge(self.dut.clk)

            if self.loopback_enable:
                for mac in self.port_mac:
                    if not mac.tx.empty():
                        await mac.rx.send(await mac.tx.recv())


@cocotb.test()
async def run_test_nic(dut):

    tb = TB(dut)

    await tb.init()

    tb.log.info("Init driver")
    await tb.driver.init_axi_dev(tb.pool, tb.hw_regs, irq=dut.irq)
    for interface in tb.driver.interfaces:
        await interface.open()

    # enable queues
    tb.log.info("Enable queues")
    for interface in tb.driver.interfaces:
        await interface.ports[0].hw_regs.write_dword(mqnic.MQNIC_PORT_REG_SCHED_ENABLE, 0x00000001)
        for k in range(interface.tx_queue_count):
            await interface.ports[0].schedulers[0].hw_regs.write_dword(4*k, 0x00000003)

    # wait for all writes to complete
    await tb.driver.hw_regs.read_dword(0)
    tb.log.info("Init complete")

    tb.log.info("Send and receive single packet")

    for interface in tb.driver.interfaces:
        data = bytearray([x % 256 for x in range(1024)])

        await interface.start_xmit(data, 0)

        pkt = await tb.port_mac[interface.index*interface.port_count].tx.recv()
        tb.log.info("Packet: %s", pkt)

        await tb.port_mac[interface.index*interface.port_count].rx.send(pkt)

        pkt = await interface.recv()

        tb.log.info("Packet: %s", pkt)
        assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

    tb.log.info("RX and TX checksum tests")

    payload = bytes([x % 256 for x in range(256)])
    eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
    ip = IP(src='192.168.1.100', dst='192.168.1.101')
    udp = UDP(sport=1, dport=2)
    test_pkt = eth / ip / udp / payload

    test_pkt2 = test_pkt.copy()
    test_pkt2[UDP].chksum = scapy.utils.checksum(bytes(test_pkt2[UDP]))

    await tb.driver.interfaces[0].start_xmit(test_pkt2.build(), 0, 34, 6)

    pkt = await tb.port_mac[0].tx.recv()
    tb.log.info("Packet: %s", pkt)

    await tb.port_mac[0].rx.send(pkt)

    pkt = await tb.driver.interfaces[0].recv()

    tb.log.info("Packet: %s", pkt)
    assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff
    assert Ether(pkt.data).build() == test_pkt.build()

    tb.log.info("Multiple small packets")

    count = 64

    pkts = [bytearray([(x+k) % 256 for x in range(60)]) for k in range(count)]

    tb.loopback_enable = True

    for p in pkts:
        await tb.driver.interfaces[0].start_xmit(p, 0)

    for k in range(count):
        pkt = await tb.driver.interfaces[0].recv()

        tb.log.info("Packet: %s", pkt)
        assert pkt.data == pkts[k]
        assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

    tb.loopback_enable = False

    tb.log.info("Multiple large packets")

    count = 64

    pkts = [bytearray([(x+k) % 256 for x in range(1514)]) for k in range(count)]

    tb.loopback_enable = True

    for p in pkts:
        await tb.driver.interfaces[0].start_xmit(p, 0)

    for k in range(count):
        pkt = await tb.driver.interfaces[0].recv()

        tb.log.info("Packet: %s", pkt)
        assert pkt.data == pkts[k]
        assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

    tb.loopback_enable = False

    tb.log.info("Jumbo frames")

    count = 64

    pkts = [bytearray([(x+k) % 256 for x in range(9014)]) for k in range(count)]

    tb.loopback_enable = True

    for p in pkts:
        await tb.driver.interfaces[0].start_xmit(p, 0)

    for k in range(count):
        pkt = await tb.driver.interfaces[0].recv()

        tb.log.info("Packet: %s", pkt)
        assert pkt.data == pkts[k]
        assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

    tb.loopback_enable = False

    if len(tb.driver.interfaces) > 1:
        tb.log.info("All interfaces")

        count = 64

        pkts = [bytearray([(x+k) % 256 for x in range(1514)]) for k in range(count)]

        tb.loopback_enable = True

        for k, p in enumerate(pkts):
            await tb.driver.interfaces[k % len(tb.driver.interfaces)].start_xmit(p, 0)

        for k in range(count):
            pkt = await tb.driver.interfaces[k % len(tb.driver.interfaces)].recv()

            tb.log.info("Packet: %s", pkt)
            assert pkt.data == pkts[k]
            assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

        tb.loopback_enable = False

    if len(tb.driver.interfaces[0].ports) > 1:
        tb.log.info("All interface 0 ports")

        for port in tb.driver.interfaces[0].ports:
            await port.hw_regs.write_dword(mqnic.MQNIC_PORT_REG_SCHED_ENABLE, 0x00000001)
            for k in range(port.interface.tx_queue_count):
                if k % len(tb.driver.interfaces[0].ports) == port.index:
                    await port.schedulers[0].hw_regs.write_dword(4*k, 0x00000003)
                else:
                    await port.schedulers[0].hw_regs.write_dword(4*k, 0x00000000)

        count = 64

        pkts = [bytearray([(x+k) % 256 for x in range(1514)]) for k in range(count)]

        tb.loopback_enable = True

        for k, p in enumerate(pkts):
            await tb.driver.interfaces[0].start_xmit(p, k % len(tb.driver.interfaces[0].ports))

        for k in range(count):
            pkt = await tb.driver.interfaces[0].recv()

            tb.log.info("Packet: %s", pkt)
            # assert pkt.data == pkts[k]
            assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

        tb.loopback_enable = False

        for port in tb.driver.interfaces[0].ports[1:]:
            await port.hw_regs.write_dword(mqnic.MQNIC_PORT_REG_SCHED_ENABLE, 0x00000000)

    tb.log.info("Read statistics counters")

    await Timer(2000, 'ns')

    lst = []

    for k in range(64):
        lst.append(await tb.driver.hw_regs.read_dword(0x010000+k*8))

    print(lst)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
axi_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axi', 'rtl'))
axis_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axis', 'rtl'))
eth_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'eth', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'pcie', 'rtl'))


@pytest.mark.parametrize(("if_count", "ports_per_if", "axi_data_width",
        "axis_data_width", "axis_sync_data_width"), [
            (1, 1, 128, 64, 64),
            (2, 1, 256, 64, 64),
            (1, 2, 256, 64, 64),
            (1, 1, 128, 64, 128),
        ])
def test_mqnic_core_pcie_axi(request, if_count, ports_per_if, axi_data_width,
        axis_data_width, axis_sync_data_width):
    dut = "mqnic_core_axi"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "mqnic_core.v"),
        os.path.join(rtl_dir, "mqnic_interface.v"),
        os.path.join(rtl_dir, "mqnic_port.v"),
        os.path.join(rtl_dir, "mqnic_ptp.v"),
        os.path.join(rtl_dir, "mqnic_ptp_clock.v"),
        os.path.join(rtl_dir, "mqnic_ptp_perout.v"),
        os.path.join(rtl_dir, "cpl_write.v"),
        os.path.join(rtl_dir, "cpl_op_mux.v"),
        os.path.join(rtl_dir, "desc_fetch.v"),
        os.path.join(rtl_dir, "desc_op_mux.v"),
        os.path.join(rtl_dir, "event_mux.v"),
        os.path.join(rtl_dir, "queue_manager.v"),
        os.path.join(rtl_dir, "cpl_queue_manager.v"),
        os.path.join(rtl_dir, "tx_engine.v"),
        os.path.join(rtl_dir, "rx_engine.v"),
        os.path.join(rtl_dir, "tx_checksum.v"),
        os.path.join(rtl_dir, "rx_hash.v"),
        os.path.join(rtl_dir, "rx_checksum.v"),
        os.path.join(rtl_dir, "stats_counter.v"),
        os.path.join(rtl_dir, "stats_collect.v"),
        os.path.join(rtl_dir, "stats_pcie_if.v"),
        os.path.join(rtl_dir, "stats_pcie_tlp.v"),
        os.path.join(rtl_dir, "stats_dma_if_pcie.v"),
        os.path.join(rtl_dir, "stats_dma_latency.v"),
        os.path.join(rtl_dir, "mqnic_tx_scheduler_block_rr.v"),
        os.path.join(rtl_dir, "tx_scheduler_rr.v"),
        os.path.join(eth_rtl_dir, "ptp_clock.v"),
        os.path.join(eth_rtl_dir, "ptp_clock_cdc.v"),
        os.path.join(eth_rtl_dir, "ptp_perout.v"),
        os.path.join(eth_rtl_dir, "ptp_ts_extract.v"),
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
        os.path.join(axis_rtl_dir, "axis_fifo.v"),
        os.path.join(axis_rtl_dir, "axis_pipeline_fifo.v"),
        os.path.join(axis_rtl_dir, "axis_register.v"),
        os.path.join(pcie_rtl_dir, "dma_if_axi.v"),
        os.path.join(pcie_rtl_dir, "dma_if_axi_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_if_axi_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_if_mux.v"),
        os.path.join(pcie_rtl_dir, "dma_if_mux_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_if_mux_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_if_desc_mux.v"),
        os.path.join(pcie_rtl_dir, "dma_ram_demux_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_ram_demux_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_psdpram.v"),
        os.path.join(pcie_rtl_dir, "dma_client_axis_sink.v"),
        os.path.join(pcie_rtl_dir, "dma_client_axis_source.v"),
        os.path.join(pcie_rtl_dir, "pulse_merge.v"),
    ]

    parameters = {}

    # Structural configuration
    parameters['IF_COUNT'] = if_count
    parameters['PORTS_PER_IF'] = ports_per_if

    # PTP configuration
    parameters['PTP_USE_SAMPLE_CLOCK'] = 0
    parameters['PTP_SEPARATE_RX_CLOCK'] = 0
    parameters['PTP_PEROUT_ENABLE'] = 0
    parameters['PTP_PEROUT_COUNT'] = 1

    # Queue manager configuration (interface)
    parameters['EVENT_QUEUE_OP_TABLE_SIZE'] = 32
    parameters['TX_QUEUE_OP_TABLE_SIZE'] = 32
    parameters['RX_QUEUE_OP_TABLE_SIZE'] = 32
    parameters['TX_CPL_QUEUE_OP_TABLE_SIZE'] = parameters['TX_QUEUE_OP_TABLE_SIZE']
    parameters['RX_CPL_QUEUE_OP_TABLE_SIZE'] = parameters['RX_QUEUE_OP_TABLE_SIZE']
    parameters['TX_QUEUE_INDEX_WIDTH'] = 13
    parameters['RX_QUEUE_INDEX_WIDTH'] = 8
    parameters['TX_CPL_QUEUE_INDEX_WIDTH'] = parameters['TX_QUEUE_INDEX_WIDTH']
    parameters['RX_CPL_QUEUE_INDEX_WIDTH'] = parameters['RX_QUEUE_INDEX_WIDTH']
    parameters['EVENT_QUEUE_PIPELINE'] = 3
    parameters['TX_QUEUE_PIPELINE'] = 3 + max(parameters['TX_QUEUE_INDEX_WIDTH']-12, 0)
    parameters['RX_QUEUE_PIPELINE'] = 3 + max(parameters['RX_QUEUE_INDEX_WIDTH']-12, 0)
    parameters['TX_CPL_QUEUE_PIPELINE'] = parameters['TX_QUEUE_PIPELINE']
    parameters['RX_CPL_QUEUE_PIPELINE'] = parameters['RX_QUEUE_PIPELINE']

    # TX and RX engine configuration (port)
    parameters['TX_DESC_TABLE_SIZE'] = 32
    parameters['RX_DESC_TABLE_SIZE'] = 32

    # Scheduler configuration (port)
    parameters['TX_SCHEDULER_OP_TABLE_SIZE'] = parameters['TX_DESC_TABLE_SIZE']
    parameters['TX_SCHEDULER_PIPELINE'] = parameters['TX_QUEUE_PIPELINE']
    parameters['TDMA_INDEX_WIDTH'] = 6

    # Timestamping configuration (port)
    parameters['PTP_TS_ENABLE'] = 1
    parameters['TX_PTP_TS_FIFO_DEPTH'] = 32
    parameters['RX_PTP_TS_FIFO_DEPTH'] = 32

    # Interface configuration (port)
    parameters['TX_CHECKSUM_ENABLE'] = 1
    parameters['RX_RSS_ENABLE'] = 1
    parameters['RX_HASH_ENABLE'] = 1
    parameters['RX_CHECKSUM_ENABLE'] = 1
    parameters['TX_FIFO_DEPTH'] = 32768
    parameters['RX_FIFO_DEPTH'] = 131072
    parameters['MAX_TX_SIZE'] = 9214
    parameters['MAX_RX_SIZE'] = 9214
    parameters['TX_RAM_SIZE'] = 131072
    parameters['RX_RAM_SIZE'] = 131072

    # Application block configuration
    parameters['APP_ENABLE'] = 0
    parameters['APP_CTRL_ENABLE'] = 1
    parameters['APP_DMA_ENABLE'] = 1
    parameters['APP_AXIS_DIRECT_ENABLE'] = 1
    parameters['APP_AXIS_SYNC_ENABLE'] = 1
    parameters['APP_AXIS_IF_ENABLE'] = 1
    parameters['APP_STAT_ENABLE'] = 1

    # AXI interface configuration (DMA)
    parameters['AXI_DATA_WIDTH'] = axi_data_width
    parameters['AXI_ADDR_WIDTH'] = 49
    parameters['AXI_STRB_WIDTH'] = parameters['AXI_DATA_WIDTH'] // 8
    parameters['AXI_ID_WIDTH'] = 6

    # DMA interface configuration
    parameters['DMA_LEN_WIDTH'] = 16
    parameters['DMA_TAG_WIDTH'] = 16
    parameters['RAM_PIPELINE'] = 2
    parameters['AXI_DMA_MAX_BURST_LEN'] = 16
    parameters['AXI_DMA_USE_ID'] = 1
    parameters['AXI_DMA_READ_OP_TABLE_SIZE'] = 2**parameters['AXI_ID_WIDTH']
    parameters['AXI_DMA_WRITE_OP_TABLE_SIZE'] = 2**parameters['AXI_ID_WIDTH']

    # Interrupts
    parameters['IRQ_COUNT'] = 32

    # AXI lite interface configuration (control)
    parameters['AXIL_CTRL_DATA_WIDTH'] = 32
    parameters['AXIL_CTRL_ADDR_WIDTH'] = 24
    parameters['AXIL_CSR_PASSTHROUGH_ENABLE'] = 0

    # AXI lite interface configuration (application control)
    parameters['AXIL_APP_CTRL_DATA_WIDTH'] = parameters['AXIL_CTRL_DATA_WIDTH']
    parameters['AXIL_APP_CTRL_ADDR_WIDTH'] = 24

    # Ethernet interface configuration
    parameters['AXIS_DATA_WIDTH'] = axis_data_width
    parameters['AXIS_SYNC_DATA_WIDTH'] = axis_sync_data_width
    parameters['AXIS_RX_USE_READY'] = 0
    parameters['AXIS_TX_PIPELINE'] = 0
    parameters['AXIS_TX_FIFO_PIPELINE'] = 2
    parameters['AXIS_TX_TS_PIPELINE'] = 0
    parameters['AXIS_RX_PIPELINE'] = 0
    parameters['AXIS_RX_FIFO_PIPELINE'] = 2

    # Statistics counter subsystem
    parameters['STAT_ENABLE'] = 1
    parameters['STAT_DMA_ENABLE'] = 1
    parameters['STAT_PCIE_ENABLE'] = 1
    parameters['STAT_INC_WIDTH'] = 24
    parameters['STAT_ID_WIDTH'] = 12

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
