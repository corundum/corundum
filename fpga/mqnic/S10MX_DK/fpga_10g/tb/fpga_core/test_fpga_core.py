"""

Copyright 2020-2021, The Regents of the University of California.
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

import cocotb
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

from cocotbext.eth import XgmiiSource, XgmiiSink
from cocotbext.pcie.core import RootComplex
from cocotbext.pcie.intel.s10 import S10PcieDevice, S10RxBus, S10TxBus

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

        # PCIe
        self.rc = RootComplex()

        self.rc.max_payload_size = 0x1  # 256 bytes
        self.rc.max_read_request_size = 0x2  # 512 bytes

        self.dev = S10PcieDevice(
            # configuration options
            pcie_generation=3,
            # pcie_link_width=8,
            # pld_clk_frequency=250e6,
            l_tile=False,

            # signals
            # Clock and reset
            # npor=dut.npor,
            # pin_perst=dut.pin_perst,
            # ninit_done=dut.ninit_done,
            # pld_clk_inuse=dut.pld_clk_inuse,
            # pld_core_ready=dut.pld_core_ready,
            reset_status=dut.rst_250mhz,
            # clr_st=dut.clr_st,
            # refclk=dut.refclk,
            coreclkout_hip=dut.clk_250mhz,

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

        # self.dev.log.setLevel(logging.DEBUG)

        self.rc.make_port().connect(self.dev)

        self.driver = mqnic.Driver()

        self.dev.functions[0].msi_cap.msi_multiple_message_capable = 5

        self.dev.functions[0].configure_bar(0, 2**len(dut.core_inst.core_pcie_inst.axil_ctrl_araddr), ext=True, prefetch=True)
        if hasattr(dut.core_inst.core_pcie_inst, 'pcie_app_ctrl'):
            self.dev.functions[0].configure_bar(2, 2**len(dut.core_inst.core_pcie_inst.axil_app_ctrl_araddr), ext=True, prefetch=True)

        # Ethernet
        cocotb.start_soon(Clock(dut.qsfp0_rx_clk_1, 6.4, units="ns").start())
        self.qsfp0_1_source = XgmiiSource(dut.qsfp0_rxd_1, dut.qsfp0_rxc_1, dut.qsfp0_rx_clk_1, dut.qsfp0_rx_rst_1)
        cocotb.start_soon(Clock(dut.qsfp0_tx_clk_1, 6.4, units="ns").start())
        self.qsfp0_1_sink = XgmiiSink(dut.qsfp0_txd_1, dut.qsfp0_txc_1, dut.qsfp0_tx_clk_1, dut.qsfp0_tx_rst_1)

        cocotb.start_soon(Clock(dut.qsfp0_rx_clk_2, 6.4, units="ns").start())
        self.qsfp0_2_source = XgmiiSource(dut.qsfp0_rxd_2, dut.qsfp0_rxc_2, dut.qsfp0_rx_clk_2, dut.qsfp0_rx_rst_2)
        cocotb.start_soon(Clock(dut.qsfp0_tx_clk_2, 6.4, units="ns").start())
        self.qsfp0_2_sink = XgmiiSink(dut.qsfp0_txd_2, dut.qsfp0_txc_2, dut.qsfp0_tx_clk_2, dut.qsfp0_tx_rst_2)

        cocotb.start_soon(Clock(dut.qsfp0_rx_clk_3, 6.4, units="ns").start())
        self.qsfp0_3_source = XgmiiSource(dut.qsfp0_rxd_3, dut.qsfp0_rxc_3, dut.qsfp0_rx_clk_3, dut.qsfp0_rx_rst_3)
        cocotb.start_soon(Clock(dut.qsfp0_tx_clk_3, 6.4, units="ns").start())
        self.qsfp0_3_sink = XgmiiSink(dut.qsfp0_txd_3, dut.qsfp0_txc_3, dut.qsfp0_tx_clk_3, dut.qsfp0_tx_rst_3)

        cocotb.start_soon(Clock(dut.qsfp0_rx_clk_4, 6.4, units="ns").start())
        self.qsfp0_4_source = XgmiiSource(dut.qsfp0_rxd_4, dut.qsfp0_rxc_4, dut.qsfp0_rx_clk_4, dut.qsfp0_rx_rst_4)
        cocotb.start_soon(Clock(dut.qsfp0_tx_clk_4, 6.4, units="ns").start())
        self.qsfp0_4_sink = XgmiiSink(dut.qsfp0_txd_4, dut.qsfp0_txc_4, dut.qsfp0_tx_clk_4, dut.qsfp0_tx_rst_4)

        cocotb.start_soon(Clock(dut.qsfp1_rx_clk_1, 6.4, units="ns").start())
        self.qsfp1_1_source = XgmiiSource(dut.qsfp1_rxd_1, dut.qsfp1_rxc_1, dut.qsfp1_rx_clk_1, dut.qsfp1_rx_rst_1)
        cocotb.start_soon(Clock(dut.qsfp1_tx_clk_1, 6.4, units="ns").start())
        self.qsfp1_1_sink = XgmiiSink(dut.qsfp1_txd_1, dut.qsfp1_txc_1, dut.qsfp1_tx_clk_1, dut.qsfp1_tx_rst_1)

        cocotb.start_soon(Clock(dut.qsfp1_rx_clk_2, 6.4, units="ns").start())
        self.qsfp1_2_source = XgmiiSource(dut.qsfp1_rxd_2, dut.qsfp1_rxc_2, dut.qsfp1_rx_clk_2, dut.qsfp1_rx_rst_2)
        cocotb.start_soon(Clock(dut.qsfp1_tx_clk_2, 6.4, units="ns").start())
        self.qsfp1_2_sink = XgmiiSink(dut.qsfp1_txd_2, dut.qsfp1_txc_2, dut.qsfp1_tx_clk_2, dut.qsfp1_tx_rst_2)

        cocotb.start_soon(Clock(dut.qsfp1_rx_clk_3, 6.4, units="ns").start())
        self.qsfp1_3_source = XgmiiSource(dut.qsfp1_rxd_3, dut.qsfp1_rxc_3, dut.qsfp1_rx_clk_3, dut.qsfp1_rx_rst_3)
        cocotb.start_soon(Clock(dut.qsfp1_tx_clk_3, 6.4, units="ns").start())
        self.qsfp1_3_sink = XgmiiSink(dut.qsfp1_txd_3, dut.qsfp1_txc_3, dut.qsfp1_tx_clk_3, dut.qsfp1_tx_rst_3)

        cocotb.start_soon(Clock(dut.qsfp1_rx_clk_4, 6.4, units="ns").start())
        self.qsfp1_4_source = XgmiiSource(dut.qsfp1_rxd_4, dut.qsfp1_rxc_4, dut.qsfp1_rx_clk_4, dut.qsfp1_rx_rst_4)
        cocotb.start_soon(Clock(dut.qsfp1_tx_clk_4, 6.4, units="ns").start())
        self.qsfp1_4_sink = XgmiiSink(dut.qsfp1_txd_4, dut.qsfp1_txc_4, dut.qsfp1_tx_clk_4, dut.qsfp1_tx_rst_4)

        # dut.qsfp0_i2c_scl_i.setimmediatevalue(1)
        # dut.qsfp0_i2c_sda_i.setimmediatevalue(1)
        # dut.qsfp0_intr_n.setimmediatevalue(1)
        # dut.qsfp0_mod_prsnt_n.setimmediatevalue(0)

        # dut.qsfp0_rx_error_count_0.setimmediatevalue(0)
        # dut.qsfp0_rx_error_count_1.setimmediatevalue(0)
        # dut.qsfp0_rx_error_count_2.setimmediatevalue(0)
        # dut.qsfp0_rx_error_count_3.setimmediatevalue(0)

        # dut.qsfp1_i2c_scl_i.setimmediatevalue(1)
        # dut.qsfp1_i2c_sda_i.setimmediatevalue(1)
        # dut.qsfp1_intr_n.setimmediatevalue(1)
        # dut.qsfp1_mod_prsnt_n.setimmediatevalue(0)

        # dut.qsfp1_rx_error_count_0.setimmediatevalue(0)
        # dut.qsfp1_rx_error_count_1.setimmediatevalue(0)
        # dut.qsfp1_rx_error_count_2.setimmediatevalue(0)
        # dut.qsfp1_rx_error_count_3.setimmediatevalue(0)

        # dut.qspi_dq_i.setimmediatevalue(0)

        self.loopback_enable = False
        cocotb.start_soon(self._run_loopback())

    async def init(self):

        self.dut.qsfp0_rx_rst_1.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_1.setimmediatevalue(0)
        self.dut.qsfp0_rx_rst_2.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_2.setimmediatevalue(0)
        self.dut.qsfp0_rx_rst_3.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_3.setimmediatevalue(0)
        self.dut.qsfp0_rx_rst_4.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_4.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_1.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_1.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_2.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_2.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_3.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_3.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_4.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_4.setimmediatevalue(0)

        await RisingEdge(self.dut.clk_250mhz)
        await RisingEdge(self.dut.clk_250mhz)

        self.dut.qsfp0_rx_rst_1.setimmediatevalue(1)
        self.dut.qsfp0_tx_rst_1.setimmediatevalue(1)
        self.dut.qsfp0_rx_rst_2.setimmediatevalue(1)
        self.dut.qsfp0_tx_rst_2.setimmediatevalue(1)
        self.dut.qsfp0_rx_rst_3.setimmediatevalue(1)
        self.dut.qsfp0_tx_rst_3.setimmediatevalue(1)
        self.dut.qsfp0_rx_rst_4.setimmediatevalue(1)
        self.dut.qsfp0_tx_rst_4.setimmediatevalue(1)
        self.dut.qsfp1_rx_rst_1.setimmediatevalue(1)
        self.dut.qsfp1_tx_rst_1.setimmediatevalue(1)
        self.dut.qsfp1_rx_rst_2.setimmediatevalue(1)
        self.dut.qsfp1_tx_rst_2.setimmediatevalue(1)
        self.dut.qsfp1_rx_rst_3.setimmediatevalue(1)
        self.dut.qsfp1_tx_rst_3.setimmediatevalue(1)
        self.dut.qsfp1_rx_rst_4.setimmediatevalue(1)
        self.dut.qsfp1_tx_rst_4.setimmediatevalue(1)

        await FallingEdge(self.dut.rst_250mhz)
        await Timer(100, 'ns')

        await RisingEdge(self.dut.clk_250mhz)
        await RisingEdge(self.dut.clk_250mhz)

        self.dut.qsfp0_rx_rst_1.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_1.setimmediatevalue(0)
        self.dut.qsfp0_rx_rst_2.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_2.setimmediatevalue(0)
        self.dut.qsfp0_rx_rst_3.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_3.setimmediatevalue(0)
        self.dut.qsfp0_rx_rst_4.setimmediatevalue(0)
        self.dut.qsfp0_tx_rst_4.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_1.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_1.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_2.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_2.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_3.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_3.setimmediatevalue(0)
        self.dut.qsfp1_rx_rst_4.setimmediatevalue(0)
        self.dut.qsfp1_tx_rst_4.setimmediatevalue(0)

        await self.rc.enumerate(enable_bus_mastering=True, configure_msi=True)

    async def _run_loopback(self):
        while True:
            await RisingEdge(self.dut.clk_250mhz)

            if self.loopback_enable:
                if not self.qsfp0_1_sink.empty():
                    await self.qsfp0_1_source.send(await self.qsfp0_1_sink.recv())
                if not self.qsfp0_2_sink.empty():
                    await self.qsfp0_2_source.send(await self.qsfp0_2_sink.recv())
                if not self.qsfp0_3_sink.empty():
                    await self.qsfp0_3_source.send(await self.qsfp0_3_sink.recv())
                if not self.qsfp0_4_sink.empty():
                    await self.qsfp0_4_source.send(await self.qsfp0_4_sink.recv())
                if not self.qsfp1_1_sink.empty():
                    await self.qsfp1_1_source.send(await self.qsfp1_1_sink.recv())
                if not self.qsfp1_2_sink.empty():
                    await self.qsfp1_2_source.send(await self.qsfp1_2_sink.recv())
                if not self.qsfp1_3_sink.empty():
                    await self.qsfp1_3_source.send(await self.qsfp1_3_sink.recv())
                if not self.qsfp1_4_sink.empty():
                    await self.qsfp1_4_source.send(await self.qsfp1_4_sink.recv())


@cocotb.test()
async def run_test_nic(dut):

    tb = TB(dut)

    await tb.init()

    tb.log.info("Init driver")
    await tb.driver.init_pcie_dev(tb.rc, tb.dev.functions[0].pcie_id)
    await tb.driver.interfaces[0].open()
    # await tb.driver.interfaces[1].open()

    # enable queues
    tb.log.info("Enable queues")
    await tb.driver.interfaces[0].ports[0].hw_regs.write_dword(mqnic.MQNIC_PORT_REG_SCHED_ENABLE, 0x00000001)
    for k in range(tb.driver.interfaces[0].tx_queue_count):
        await tb.driver.interfaces[0].ports[0].schedulers[0].hw_regs.write_dword(4*k, 0x00000003)

    # wait for all writes to complete
    await tb.driver.hw_regs.read_dword(0)
    tb.log.info("Init complete")

    tb.log.info("Send and receive single packet")

    data = bytearray([x % 256 for x in range(1024)])

    await tb.driver.interfaces[0].start_xmit(data, 0)

    pkt = await tb.qsfp0_1_sink.recv()
    tb.log.info("Packet: %s", pkt)

    await tb.qsfp0_1_source.send(pkt)

    pkt = await tb.driver.interfaces[0].recv()

    tb.log.info("Packet: %s", pkt)
    assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

    # await tb.driver.interfaces[1].start_xmit(data, 0)

    # pkt = await tb.qsfp1_1_sink.recv()
    # tb.log.info("Packet: %s", pkt)

    # await tb.qsfp1_1_source.send(pkt)

    # pkt = await tb.driver.interfaces[1].recv()

    # tb.log.info("Packet: %s", pkt)
    # assert pkt.rx_checksum == ~scapy.utils.checksum(bytes(pkt.data[14:])) & 0xffff

    tb.log.info("RX and TX checksum tests")

    payload = bytes([x % 256 for x in range(256)])
    eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
    ip = IP(src='192.168.1.100', dst='192.168.1.101')
    udp = UDP(sport=1, dport=2)
    test_pkt = eth / ip / udp / payload

    test_pkt2 = test_pkt.copy()
    test_pkt2[UDP].chksum = scapy.utils.checksum(bytes(test_pkt2[UDP]))

    await tb.driver.interfaces[0].start_xmit(test_pkt2.build(), 0, 34, 6)

    pkt = await tb.qsfp0_1_sink.recv()
    tb.log.info("Packet: %s", pkt)

    await tb.qsfp0_1_source.send(pkt)

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

    await RisingEdge(dut.clk_250mhz)
    await RisingEdge(dut.clk_250mhz)


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
app_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'app'))
axi_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axi', 'rtl'))
axis_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axis', 'rtl'))
eth_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'eth', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'pcie', 'rtl'))


def test_fpga_core(request):
    dut = "fpga_core"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "common", "mqnic_core_pcie_s10.v"),
        os.path.join(rtl_dir, "common", "mqnic_core_pcie.v"),
        os.path.join(rtl_dir, "common", "mqnic_core.v"),
        os.path.join(rtl_dir, "common", "mqnic_interface.v"),
        os.path.join(rtl_dir, "common", "mqnic_port.v"),
        os.path.join(rtl_dir, "common", "mqnic_ptp.v"),
        os.path.join(rtl_dir, "common", "mqnic_ptp_clock.v"),
        os.path.join(rtl_dir, "common", "mqnic_ptp_perout.v"),
        os.path.join(rtl_dir, "common", "cpl_write.v"),
        os.path.join(rtl_dir, "common", "cpl_op_mux.v"),
        os.path.join(rtl_dir, "common", "desc_fetch.v"),
        os.path.join(rtl_dir, "common", "desc_op_mux.v"),
        os.path.join(rtl_dir, "common", "event_mux.v"),
        os.path.join(rtl_dir, "common", "queue_manager.v"),
        os.path.join(rtl_dir, "common", "cpl_queue_manager.v"),
        os.path.join(rtl_dir, "common", "tx_engine.v"),
        os.path.join(rtl_dir, "common", "rx_engine.v"),
        os.path.join(rtl_dir, "common", "tx_checksum.v"),
        os.path.join(rtl_dir, "common", "rx_hash.v"),
        os.path.join(rtl_dir, "common", "rx_checksum.v"),
        os.path.join(rtl_dir, "common", "stats_counter.v"),
        os.path.join(rtl_dir, "common", "stats_collect.v"),
        os.path.join(rtl_dir, "common", "stats_pcie_if.v"),
        os.path.join(rtl_dir, "common", "stats_pcie_tlp.v"),
        os.path.join(rtl_dir, "common", "stats_dma_if_pcie.v"),
        os.path.join(rtl_dir, "common", "stats_dma_latency.v"),
        os.path.join(rtl_dir, "common", "mqnic_tx_scheduler_block_rr.v"),
        os.path.join(rtl_dir, "common", "tx_scheduler_rr.v"),
        os.path.join(rtl_dir, "common", "tdma_scheduler.v"),
        os.path.join(rtl_dir, "common", "tdma_ber.v"),
        os.path.join(rtl_dir, "common", "tdma_ber_ch.v"),
        os.path.join(eth_rtl_dir, "eth_mac_10g.v"),
        os.path.join(eth_rtl_dir, "axis_xgmii_rx_64.v"),
        os.path.join(eth_rtl_dir, "axis_xgmii_tx_64.v"),
        os.path.join(eth_rtl_dir, "lfsr.v"),
        os.path.join(eth_rtl_dir, "ptp_clock.v"),
        os.path.join(eth_rtl_dir, "ptp_clock_cdc.v"),
        os.path.join(eth_rtl_dir, "ptp_perout.v"),
        os.path.join(eth_rtl_dir, "ptp_ts_extract.v"),
        os.path.join(axi_rtl_dir, "axil_interconnect.v"),
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
        os.path.join(pcie_rtl_dir, "pcie_axil_master.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_demux_bar.v"),
        os.path.join(pcie_rtl_dir, "pcie_tlp_mux.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_if_pcie_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_if_mux.v"),
        os.path.join(pcie_rtl_dir, "dma_if_mux_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_if_mux_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_if_desc_mux.v"),
        os.path.join(pcie_rtl_dir, "dma_ram_demux_rd.v"),
        os.path.join(pcie_rtl_dir, "dma_ram_demux_wr.v"),
        os.path.join(pcie_rtl_dir, "dma_psdpram.v"),
        os.path.join(pcie_rtl_dir, "dma_client_axis_sink.v"),
        os.path.join(pcie_rtl_dir, "dma_client_axis_source.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_if.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_if_rx.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_if_tx.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_cfg.v"),
        os.path.join(pcie_rtl_dir, "pcie_s10_msi.v"),
        os.path.join(pcie_rtl_dir, "pulse_merge.v"),
    ]

    parameters = {}

    # Structural configuration
    parameters['IF_COUNT'] = 2
    parameters['PORTS_PER_IF'] = 1

    # PTP configuration
    parameters['PTP_USE_SAMPLE_CLOCK'] = 0
    parameters['PTP_PEROUT_ENABLE'] = 1
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
    parameters['RX_FIFO_DEPTH'] = 32768
    parameters['MAX_TX_SIZE'] = 9214
    parameters['MAX_RX_SIZE'] = 9214
    parameters['TX_RAM_SIZE'] = 32768
    parameters['RX_RAM_SIZE'] = 32768

    # Application block configuration
    parameters['APP_ENABLE'] = 0
    parameters['APP_CTRL_ENABLE'] = 1
    parameters['APP_DMA_ENABLE'] = 1
    parameters['APP_AXIS_DIRECT_ENABLE'] = 1
    parameters['APP_AXIS_SYNC_ENABLE'] = 1
    parameters['APP_AXIS_IF_ENABLE'] = 1
    parameters['APP_STAT_ENABLE'] = 1

    # DMA interface configuration
    parameters['DMA_LEN_WIDTH'] = 16
    parameters['DMA_TAG_WIDTH'] = 16
    parameters['RAM_PIPELINE'] = 2

    # PCIe interface configuration
    parameters['SEG_COUNT'] = 1
    parameters['SEG_DATA_WIDTH'] = 256
    parameters['SEG_EMPTY_WIDTH'] = ((parameters['SEG_DATA_WIDTH'] // 32) - 1).bit_length()
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['PF_COUNT'] = 1
    parameters['VF_COUNT'] = 0
    parameters['PCIE_TAG_COUNT'] = 256
    parameters['PCIE_DMA_READ_OP_TABLE_SIZE'] = parameters['PCIE_TAG_COUNT']
    parameters['PCIE_DMA_READ_TX_LIMIT'] = 16
    parameters['PCIE_DMA_READ_TX_FC_ENABLE'] = 1
    parameters['PCIE_DMA_WRITE_OP_TABLE_SIZE'] = 16
    parameters['PCIE_DMA_WRITE_TX_LIMIT'] = 3
    parameters['PCIE_DMA_WRITE_TX_FC_ENABLE'] = 1

    # AXI lite interface configuration (control)
    parameters['AXIL_CTRL_DATA_WIDTH'] = 32
    parameters['AXIL_CTRL_ADDR_WIDTH'] = 24

    # AXI lite interface configuration (application control)
    parameters['AXIL_APP_CTRL_DATA_WIDTH'] = parameters['AXIL_CTRL_DATA_WIDTH']
    parameters['AXIL_APP_CTRL_ADDR_WIDTH'] = 24

    # Ethernet interface configuration
    parameters['AXIS_ETH_TX_PIPELINE'] = 0
    parameters['AXIS_ETH_TX_FIFO_PIPELINE'] = 2
    parameters['AXIS_ETH_TX_TS_PIPELINE'] = 0
    parameters['AXIS_ETH_RX_PIPELINE'] = 0
    parameters['AXIS_ETH_RX_FIFO_PIPELINE'] = 2

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
