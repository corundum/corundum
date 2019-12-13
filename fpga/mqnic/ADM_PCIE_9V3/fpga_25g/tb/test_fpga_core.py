#!/usr/bin/env python
"""

Copyright 2019, The Regents of the University of California.
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

from myhdl import *
import os

import pcie
import pcie_usp
import xgmii_ep
import axis_ep
import eth_ep
import udp_ep

import struct

import mqnic

module = 'fpga_core'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/common/interface.v")
srcs.append("../rtl/common/port.v")
srcs.append("../rtl/common/cpl_write.v")
srcs.append("../rtl/common/cpl_op_mux.v")
srcs.append("../rtl/common/desc_fetch.v")
srcs.append("../rtl/common/desc_op_mux.v")
srcs.append("../rtl/common/queue_manager.v")
srcs.append("../rtl/common/cpl_queue_manager.v")
srcs.append("../rtl/common/tx_engine.v")
srcs.append("../rtl/common/rx_engine.v")
srcs.append("../rtl/common/tx_checksum.v")
srcs.append("../rtl/common/rx_hash.v")
srcs.append("../rtl/common/rx_checksum.v")
srcs.append("../rtl/common/tx_scheduler_rr.v")
srcs.append("../rtl/common/event_mux.v")
srcs.append("../rtl/common/tdma_scheduler.v")
srcs.append("../rtl/common/tdma_ber.v")
srcs.append("../rtl/common/tdma_ber_ch.v")
srcs.append("../lib/eth/rtl/eth_mac_10g_fifo.v")
srcs.append("../lib/eth/rtl/eth_mac_10g.v")
srcs.append("../lib/eth/rtl/axis_xgmii_rx_64.v")
srcs.append("../lib/eth/rtl/axis_xgmii_tx_64.v")
srcs.append("../lib/eth/rtl/lfsr.v")
srcs.append("../lib/eth/rtl/ptp_clock.v")
srcs.append("../lib/eth/rtl/ptp_clock_cdc.v")
srcs.append("../lib/eth/rtl/ptp_perout.v")
srcs.append("../lib/eth/rtl/ptp_ts_extract.v")
srcs.append("../lib/axi/rtl/axil_interconnect.v")
srcs.append("../lib/axi/rtl/arbiter.v")
srcs.append("../lib/axi/rtl/priority_encoder.v")
srcs.append("../lib/axis/rtl/axis_adapter.v")
srcs.append("../lib/axis/rtl/axis_arb_mux.v")
srcs.append("../lib/axis/rtl/axis_async_fifo.v")
srcs.append("../lib/axis/rtl/axis_async_fifo_adapter.v")
srcs.append("../lib/axis/rtl/axis_fifo.v")
srcs.append("../lib/axis/rtl/axis_register.v")
srcs.append("../lib/pcie/rtl/pcie_us_axil_master.v")
srcs.append("../lib/pcie/rtl/dma_if_pcie_us.v")
srcs.append("../lib/pcie/rtl/dma_if_pcie_us_rd.v")
srcs.append("../lib/pcie/rtl/dma_if_pcie_us_wr.v")
srcs.append("../lib/pcie/rtl/dma_if_mux.v")
srcs.append("../lib/pcie/rtl/dma_if_mux_rd.v")
srcs.append("../lib/pcie/rtl/dma_if_mux_wr.v")
srcs.append("../lib/pcie/rtl/dma_psdpram.v")
srcs.append("../lib/pcie/rtl/dma_client_axis_sink.v")
srcs.append("../lib/pcie/rtl/dma_client_axis_source.v")
srcs.append("../lib/pcie/rtl/pcie_us_cfg.v")
srcs.append("../lib/pcie/rtl/pcie_us_msi.v")
srcs.append("../lib/pcie/rtl/pcie_tag_manager.v")
srcs.append("../lib/pcie/rtl/pulse_merge.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def frame_checksum(frame):
    data = frame[14:]

    csum = 0
    odd = False

    for b in data:
        if odd:
            csum += b
        else:
            csum += b << 8
        odd = not odd

    csum = (csum & 0xffff) + (csum >> 16)
    csum = (csum & 0xffff) + (csum >> 16)

    return csum

def bench():

    # Parameters
    AXIS_PCIE_DATA_WIDTH = 512
    AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32)
    AXIS_PCIE_RC_USER_WIDTH = 161
    AXIS_PCIE_RQ_USER_WIDTH = 137
    AXIS_PCIE_CQ_USER_WIDTH = 183
    AXIS_PCIE_CC_USER_WIDTH = 81
    RQ_SEQ_NUM_WIDTH = 6
    BAR0_APERTURE = 24

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    clk_156mhz = Signal(bool(0))
    rst_156mhz = Signal(bool(0))
    clk_250mhz = Signal(bool(0))
    rst_250mhz = Signal(bool(0))
    user_sw = Signal(intbv(0)[2:])
    m_axis_rq_tready = Signal(bool(0))
    s_axis_rc_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    s_axis_rc_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    s_axis_rc_tlast = Signal(bool(0))
    s_axis_rc_tuser = Signal(intbv(0)[AXIS_PCIE_RC_USER_WIDTH:])
    s_axis_rc_tvalid = Signal(bool(0))
    s_axis_cq_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    s_axis_cq_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    s_axis_cq_tlast = Signal(bool(0))
    s_axis_cq_tuser = Signal(intbv(0)[AXIS_PCIE_CQ_USER_WIDTH:])
    s_axis_cq_tvalid = Signal(bool(0))
    m_axis_cc_tready = Signal(bool(0))
    s_axis_rq_seq_num_0 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    s_axis_rq_seq_num_valid_0 = Signal(bool(0))
    s_axis_rq_seq_num_1 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    s_axis_rq_seq_num_valid_1 = Signal(bool(0))
    pcie_tfc_nph_av = Signal(intbv(15)[4:])
    pcie_tfc_npd_av = Signal(intbv(15)[4:])
    cfg_max_payload = Signal(intbv(0)[2:])
    cfg_max_read_req = Signal(intbv(0)[3:])
    cfg_mgmt_read_data = Signal(intbv(0)[32:])
    cfg_mgmt_read_write_done = Signal(bool(0))
    cfg_fc_ph = Signal(intbv(0)[8:])
    cfg_fc_pd = Signal(intbv(0)[12:])
    cfg_fc_nph = Signal(intbv(0)[8:])
    cfg_fc_npd = Signal(intbv(0)[12:])
    cfg_fc_cplh = Signal(intbv(0)[8:])
    cfg_fc_cpld = Signal(intbv(0)[12:])
    cfg_interrupt_msi_enable = Signal(intbv(0)[4:])
    cfg_interrupt_msi_mmenable = Signal(intbv(0)[12:])
    cfg_interrupt_msi_mask_update = Signal(bool(0))
    cfg_interrupt_msi_data = Signal(intbv(0)[32:])
    cfg_interrupt_msi_sent = Signal(bool(0))
    cfg_interrupt_msi_fail = Signal(bool(0))
    qsfp_0_tx_clk_0 = Signal(bool(0))
    qsfp_0_tx_rst_0 = Signal(bool(0))
    qsfp_0_rx_clk_0 = Signal(bool(0))
    qsfp_0_rx_rst_0 = Signal(bool(0))
    qsfp_0_rxd_0 = Signal(intbv(0)[64:])
    qsfp_0_rxc_0 = Signal(intbv(0)[8:])
    qsfp_0_tx_clk_1 = Signal(bool(0))
    qsfp_0_tx_rst_1 = Signal(bool(0))
    qsfp_0_rx_clk_1 = Signal(bool(0))
    qsfp_0_rx_rst_1 = Signal(bool(0))
    qsfp_0_rxd_1 = Signal(intbv(0)[64:])
    qsfp_0_rxc_1 = Signal(intbv(0)[8:])
    qsfp_0_tx_clk_2 = Signal(bool(0))
    qsfp_0_tx_rst_2 = Signal(bool(0))
    qsfp_0_rx_clk_2 = Signal(bool(0))
    qsfp_0_rx_rst_2 = Signal(bool(0))
    qsfp_0_rxd_2 = Signal(intbv(0)[64:])
    qsfp_0_rxc_2 = Signal(intbv(0)[8:])
    qsfp_0_tx_clk_3 = Signal(bool(0))
    qsfp_0_tx_rst_3 = Signal(bool(0))
    qsfp_0_rx_clk_3 = Signal(bool(0))
    qsfp_0_rx_rst_3 = Signal(bool(0))
    qsfp_0_rxd_3 = Signal(intbv(0)[64:])
    qsfp_0_rxc_3 = Signal(intbv(0)[8:])
    qsfp_0_modprs_l = Signal(bool(0))
    qsfp_1_tx_clk_0 = Signal(bool(0))
    qsfp_1_tx_rst_0 = Signal(bool(0))
    qsfp_1_rx_clk_0 = Signal(bool(0))
    qsfp_1_rx_rst_0 = Signal(bool(0))
    qsfp_1_rxd_0 = Signal(intbv(0)[64:])
    qsfp_1_rxc_0 = Signal(intbv(0)[8:])
    qsfp_1_tx_clk_1 = Signal(bool(0))
    qsfp_1_tx_rst_1 = Signal(bool(0))
    qsfp_1_rx_clk_1 = Signal(bool(0))
    qsfp_1_rx_rst_1 = Signal(bool(0))
    qsfp_1_rxd_1 = Signal(intbv(0)[64:])
    qsfp_1_rxc_1 = Signal(intbv(0)[8:])
    qsfp_1_tx_clk_2 = Signal(bool(0))
    qsfp_1_tx_rst_2 = Signal(bool(0))
    qsfp_1_rx_clk_2 = Signal(bool(0))
    qsfp_1_rx_rst_2 = Signal(bool(0))
    qsfp_1_rxd_2 = Signal(intbv(0)[64:])
    qsfp_1_rxc_2 = Signal(intbv(0)[8:])
    qsfp_1_tx_clk_3 = Signal(bool(0))
    qsfp_1_tx_rst_3 = Signal(bool(0))
    qsfp_1_rx_clk_3 = Signal(bool(0))
    qsfp_1_rx_rst_3 = Signal(bool(0))
    qsfp_1_rxd_3 = Signal(intbv(0)[64:])
    qsfp_1_rxc_3 = Signal(intbv(0)[8:])
    qsfp_1_modprs_l = Signal(bool(0))
    qsfp_int_l = Signal(bool(0))
    qsfp_i2c_scl_i = Signal(bool(1))
    qsfp_i2c_sda_i = Signal(bool(1))
    eeprom_i2c_scl_i = Signal(bool(1))
    eeprom_i2c_sda_i = Signal(bool(1))
    qspi_0_dq_i = Signal(intbv(0)[4:])
    qspi_1_dq_i = Signal(intbv(0)[4:])

    # Outputs
    user_led_g = Signal(intbv(0)[2:])
    user_led_r = Signal(bool(0))
    front_led = Signal(intbv(0)[2:])
    m_axis_rq_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    m_axis_rq_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    m_axis_rq_tlast = Signal(bool(0))
    m_axis_rq_tuser = Signal(intbv(0)[AXIS_PCIE_RQ_USER_WIDTH:])
    m_axis_rq_tvalid = Signal(bool(0))
    s_axis_rc_tready = Signal(bool(0))
    s_axis_cq_tready = Signal(bool(0))
    m_axis_cc_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    m_axis_cc_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    m_axis_cc_tlast = Signal(bool(0))
    m_axis_cc_tuser = Signal(intbv(0)[AXIS_PCIE_CC_USER_WIDTH:])
    m_axis_cc_tvalid = Signal(bool(0))
    status_error_cor = Signal(bool(0))
    status_error_uncor = Signal(bool(0))
    cfg_mgmt_addr = Signal(intbv(0)[10:])
    cfg_mgmt_function_number = Signal(intbv(0)[8:])
    cfg_mgmt_write = Signal(bool(0))
    cfg_mgmt_write_data = Signal(intbv(0)[32:])
    cfg_mgmt_byte_enable = Signal(intbv(0)[4:])
    cfg_mgmt_read = Signal(bool(0))
    cfg_fc_sel = Signal(intbv(4)[3:])
    cfg_interrupt_msi_int = Signal(intbv(0)[32:])
    cfg_interrupt_msi_pending_status = Signal(intbv(0)[32:])
    cfg_interrupt_msi_select = Signal(intbv(0)[2:])
    cfg_interrupt_msi_pending_status_function_num = Signal(intbv(0)[2:])
    cfg_interrupt_msi_pending_status_data_enable = Signal(bool(0))
    cfg_interrupt_msi_attr = Signal(intbv(0)[3:])
    cfg_interrupt_msi_tph_present = Signal(bool(0))
    cfg_interrupt_msi_tph_type = Signal(intbv(0)[2:])
    cfg_interrupt_msi_tph_st_tag = Signal(intbv(0)[8:])
    cfg_interrupt_msi_function_number = Signal(intbv(0)[8:])
    qsfp_0_txd_0 = Signal(intbv(0)[64:])
    qsfp_0_txc_0 = Signal(intbv(0)[8:])
    qsfp_0_txd_1 = Signal(intbv(0)[64:])
    qsfp_0_txc_1 = Signal(intbv(0)[8:])
    qsfp_0_txd_2 = Signal(intbv(0)[64:])
    qsfp_0_txc_2 = Signal(intbv(0)[8:])
    qsfp_0_txd_3 = Signal(intbv(0)[64:])
    qsfp_0_txc_3 = Signal(intbv(0)[8:])
    qsfp_0_sel_l = Signal(bool(1))
    qsfp_1_txd_0 = Signal(intbv(0)[64:])
    qsfp_1_txc_0 = Signal(intbv(0)[8:])
    qsfp_1_txd_1 = Signal(intbv(0)[64:])
    qsfp_1_txc_1 = Signal(intbv(0)[8:])
    qsfp_1_txd_2 = Signal(intbv(0)[64:])
    qsfp_1_txc_2 = Signal(intbv(0)[8:])
    qsfp_1_txd_3 = Signal(intbv(0)[64:])
    qsfp_1_txc_3 = Signal(intbv(0)[8:])
    qsfp_1_sel_l = Signal(bool(1))
    qsfp_reset_l = Signal(bool(1))
    qsfp_i2c_scl_o = Signal(bool(1))
    qsfp_i2c_scl_t = Signal(bool(1))
    qsfp_i2c_sda_o = Signal(bool(1))
    qsfp_i2c_sda_t = Signal(bool(1))
    eeprom_i2c_scl_o = Signal(bool(1))
    eeprom_i2c_scl_t = Signal(bool(1))
    eeprom_i2c_sda_o = Signal(bool(1))
    eeprom_i2c_sda_t = Signal(bool(1))
    eeprom_wp = Signal(bool(1))
    qspi_clk = Signal(bool(0))
    qspi_0_dq_o = Signal(intbv(0)[4:])
    qspi_0_dq_oe = Signal(intbv(0)[4:])
    qspi_0_cs = Signal(bool(1))
    qspi_1_dq_o = Signal(intbv(0)[4:])
    qspi_1_dq_oe = Signal(intbv(0)[4:])
    qspi_1_cs = Signal(bool(1))

    # sources and sinks
    qsfp_0_0_source = xgmii_ep.XGMIISource()
    qsfp_0_0_source_logic = qsfp_0_0_source.create_logic(qsfp_0_rx_clk_0, qsfp_0_rx_rst_0, txd=qsfp_0_rxd_0, txc=qsfp_0_rxc_0, name='qsfp_0_0_source')

    qsfp_0_0_sink = xgmii_ep.XGMIISink()
    qsfp_0_0_sink_logic = qsfp_0_0_sink.create_logic(qsfp_0_tx_clk_0, qsfp_0_tx_rst_0, rxd=qsfp_0_txd_0, rxc=qsfp_0_txc_0, name='qsfp_0_0_sink')

    qsfp_0_1_source = xgmii_ep.XGMIISource()
    qsfp_0_1_source_logic = qsfp_0_1_source.create_logic(qsfp_0_rx_clk_1, qsfp_0_rx_rst_1, txd=qsfp_0_rxd_1, txc=qsfp_0_rxc_1, name='qsfp_0_1_source')

    qsfp_0_1_sink = xgmii_ep.XGMIISink()
    qsfp_0_1_sink_logic = qsfp_0_1_sink.create_logic(qsfp_0_tx_clk_1, qsfp_0_tx_rst_1, rxd=qsfp_0_txd_1, rxc=qsfp_0_txc_1, name='qsfp_0_1_sink')

    qsfp_0_2_source = xgmii_ep.XGMIISource()
    qsfp_0_2_source_logic = qsfp_0_2_source.create_logic(qsfp_0_rx_clk_2, qsfp_0_rx_rst_2, txd=qsfp_0_rxd_2, txc=qsfp_0_rxc_2, name='qsfp_0_2_source')

    qsfp_0_2_sink = xgmii_ep.XGMIISink()
    qsfp_0_2_sink_logic = qsfp_0_2_sink.create_logic(qsfp_0_tx_clk_2, qsfp_0_tx_rst_2, rxd=qsfp_0_txd_2, rxc=qsfp_0_txc_2, name='qsfp_0_2_sink')

    qsfp_0_3_source = xgmii_ep.XGMIISource()
    qsfp_0_3_source_logic = qsfp_0_3_source.create_logic(qsfp_0_rx_clk_3, qsfp_0_rx_rst_3, txd=qsfp_0_rxd_3, txc=qsfp_0_rxc_3, name='qsfp_0_3_source')

    qsfp_0_3_sink = xgmii_ep.XGMIISink()
    qsfp_0_3_sink_logic = qsfp_0_3_sink.create_logic(qsfp_0_tx_clk_3, qsfp_0_tx_rst_3, rxd=qsfp_0_txd_3, rxc=qsfp_0_txc_3, name='qsfp_0_3_sink')

    qsfp_1_0_source = xgmii_ep.XGMIISource()
    qsfp_1_0_source_logic = qsfp_1_0_source.create_logic(qsfp_1_rx_clk_0, qsfp_1_rx_rst_0, txd=qsfp_1_rxd_0, txc=qsfp_1_rxc_0, name='qsfp_1_0_source')

    qsfp_1_0_sink = xgmii_ep.XGMIISink()
    qsfp_1_0_sink_logic = qsfp_1_0_sink.create_logic(qsfp_1_tx_clk_0, qsfp_1_tx_rst_0, rxd=qsfp_1_txd_0, rxc=qsfp_1_txc_0, name='qsfp_1_0_sink')

    qsfp_1_1_source = xgmii_ep.XGMIISource()
    qsfp_1_1_source_logic = qsfp_1_1_source.create_logic(qsfp_1_rx_clk_1, qsfp_1_rx_rst_1, txd=qsfp_1_rxd_1, txc=qsfp_1_rxc_1, name='qsfp_1_1_source')

    qsfp_1_1_sink = xgmii_ep.XGMIISink()
    qsfp_1_1_sink_logic = qsfp_1_1_sink.create_logic(qsfp_1_tx_clk_1, qsfp_1_tx_rst_1, rxd=qsfp_1_txd_1, rxc=qsfp_1_txc_1, name='qsfp_1_1_sink')

    qsfp_1_2_source = xgmii_ep.XGMIISource()
    qsfp_1_2_source_logic = qsfp_1_2_source.create_logic(qsfp_1_rx_clk_2, qsfp_1_rx_rst_2, txd=qsfp_1_rxd_2, txc=qsfp_1_rxc_2, name='qsfp_1_2_source')

    qsfp_1_2_sink = xgmii_ep.XGMIISink()
    qsfp_1_2_sink_logic = qsfp_1_2_sink.create_logic(qsfp_1_tx_clk_2, qsfp_1_tx_rst_2, rxd=qsfp_1_txd_2, rxc=qsfp_1_txc_2, name='qsfp_1_2_sink')

    qsfp_1_3_source = xgmii_ep.XGMIISource()
    qsfp_1_3_source_logic = qsfp_1_3_source.create_logic(qsfp_1_rx_clk_3, qsfp_1_rx_rst_3, txd=qsfp_1_rxd_3, txc=qsfp_1_rxc_3, name='qsfp_1_3_source')

    qsfp_1_3_sink = xgmii_ep.XGMIISink()
    qsfp_1_3_sink_logic = qsfp_1_3_sink.create_logic(qsfp_1_tx_clk_3, qsfp_1_tx_rst_3, rxd=qsfp_1_txd_3, rxc=qsfp_1_txc_3, name='qsfp_1_3_sink')

    # Clock and Reset Interface
    user_clk=Signal(bool(0))
    user_reset=Signal(bool(0))
    sys_clk=Signal(bool(0))
    sys_reset=Signal(bool(0))

    # PCIe devices
    rc = pcie.RootComplex()

    rc.max_payload_size = 0x1 # 256 bytes
    rc.max_read_request_size = 0x5 # 4096 bytes

    driver = mqnic.Driver(rc)

    dev = pcie_usp.UltrascalePlusPCIe()

    dev.pcie_generation = 3
    dev.pcie_link_width = 16
    dev.user_clock_frequency = 250e6

    dev.functions[0].msi_multiple_message_capable = 5

    dev.functions[0].configure_bar(0, 2**BAR0_APERTURE)

    rc.make_port().connect(dev)

    cq_pause = Signal(bool(0))
    cc_pause = Signal(bool(0))
    rq_pause = Signal(bool(0))
    rc_pause = Signal(bool(0))

    pcie_logic = dev.create_logic(
        # Completer reQuest Interface
        m_axis_cq_tdata=s_axis_cq_tdata,
        m_axis_cq_tuser=s_axis_cq_tuser,
        m_axis_cq_tlast=s_axis_cq_tlast,
        m_axis_cq_tkeep=s_axis_cq_tkeep,
        m_axis_cq_tvalid=s_axis_cq_tvalid,
        m_axis_cq_tready=s_axis_cq_tready,
        #pcie_cq_np_req=pcie_cq_np_req,
        pcie_cq_np_req=Signal(intbv(3)[2:]),
        #pcie_cq_np_req_count=pcie_cq_np_req_count,

        # Completer Completion Interface
        s_axis_cc_tdata=m_axis_cc_tdata,
        s_axis_cc_tuser=m_axis_cc_tuser,
        s_axis_cc_tlast=m_axis_cc_tlast,
        s_axis_cc_tkeep=m_axis_cc_tkeep,
        s_axis_cc_tvalid=m_axis_cc_tvalid,
        s_axis_cc_tready=m_axis_cc_tready,

        # Requester reQuest Interface
        s_axis_rq_tdata=m_axis_rq_tdata,
        s_axis_rq_tuser=m_axis_rq_tuser,
        s_axis_rq_tlast=m_axis_rq_tlast,
        s_axis_rq_tkeep=m_axis_rq_tkeep,
        s_axis_rq_tvalid=m_axis_rq_tvalid,
        s_axis_rq_tready=m_axis_rq_tready,
        pcie_rq_seq_num0=s_axis_rq_seq_num_0,
        pcie_rq_seq_num_vld0=s_axis_rq_seq_num_valid_0,
        pcie_rq_seq_num1=s_axis_rq_seq_num_1,
        pcie_rq_seq_num_vld1=s_axis_rq_seq_num_valid_1,
        #pcie_rq_tag0=pcie_rq_tag0,
        #pcie_rq_tag1=pcie_rq_tag1,
        #pcie_rq_tag_av=pcie_rq_tag_av,
        #pcie_rq_tag_vld0=pcie_rq_tag_vld0,
        #pcie_rq_tag_vld1=pcie_rq_tag_vld1,

        # Requester Completion Interface
        m_axis_rc_tdata=s_axis_rc_tdata,
        m_axis_rc_tuser=s_axis_rc_tuser,
        m_axis_rc_tlast=s_axis_rc_tlast,
        m_axis_rc_tkeep=s_axis_rc_tkeep,
        m_axis_rc_tvalid=s_axis_rc_tvalid,
        m_axis_rc_tready=s_axis_rc_tready,

        # Transmit Flow Control Interface
        #pcie_tfc_nph_av=pcie_tfc_nph_av,
        #pcie_tfc_npd_av=pcie_tfc_npd_av,

        # Configuration Management Interface
        cfg_mgmt_addr=cfg_mgmt_addr,
        cfg_mgmt_function_number=cfg_mgmt_function_number,
        cfg_mgmt_write=cfg_mgmt_write,
        cfg_mgmt_write_data=cfg_mgmt_write_data,
        cfg_mgmt_byte_enable=cfg_mgmt_byte_enable,
        cfg_mgmt_read=cfg_mgmt_read,
        cfg_mgmt_read_data=cfg_mgmt_read_data,
        cfg_mgmt_read_write_done=cfg_mgmt_read_write_done,
        #cfg_mgmt_debug_access=cfg_mgmt_debug_access,

        # Configuration Status Interface
        #cfg_phy_link_down=cfg_phy_link_down,
        #cfg_phy_link_status=cfg_phy_link_status,
        #cfg_negotiated_width=cfg_negotiated_width,
        #cfg_current_speed=cfg_current_speed,
        cfg_max_payload=cfg_max_payload,
        cfg_max_read_req=cfg_max_read_req,
        #cfg_function_status=cfg_function_status,
        #cfg_vf_status=cfg_vf_status,
        #cfg_function_power_state=cfg_function_power_state,
        #cfg_vf_power_state=cfg_vf_power_state,
        #cfg_link_power_state=cfg_link_power_state,
        #cfg_err_cor_out=cfg_err_cor_out,
        #cfg_err_nonfatal_out=cfg_err_nonfatal_out,
        #cfg_err_fatal_out=cfg_err_fatal_out,
        #cfg_local_err_out=cfg_local_err_out,
        #cfg_local_err_valid=cfg_local_err_valid,
        #cfg_rx_pm_state=cfg_rx_pm_state,
        #cfg_tx_pm_state=cfg_tx_pm_state,
        #cfg_ltssm_state=cfg_ltssm_state,
        #cfg_rcb_status=cfg_rcb_status,
        #cfg_obff_enable=cfg_obff_enable,
        #cfg_pl_status_change=cfg_pl_status_change,
        #cfg_tph_requester_enable=cfg_tph_requester_enable,
        #cfg_tph_st_mode=cfg_tph_st_mode,
        #cfg_vf_tph_requester_enable=cfg_vf_tph_requester_enable,
        #cfg_vf_tph_st_mode=cfg_vf_tph_st_mode,

        # Configuration Received Message Interface
        #cfg_msg_received=cfg_msg_received,
        #cfg_msg_received_data=cfg_msg_received_data,
        #cfg_msg_received_type=cfg_msg_received_type,

        # Configuration Transmit Message Interface
        #cfg_msg_transmit=cfg_msg_transmit,
        #cfg_msg_transmit_type=cfg_msg_transmit_type,
        #cfg_msg_transmit_data=cfg_msg_transmit_data,
        #cfg_msg_transmit_done=cfg_msg_transmit_done,

        # Configuration Flow Control Interface
        cfg_fc_ph=cfg_fc_ph,
        cfg_fc_pd=cfg_fc_pd,
        cfg_fc_nph=cfg_fc_nph,
        cfg_fc_npd=cfg_fc_npd,
        cfg_fc_cplh=cfg_fc_cplh,
        cfg_fc_cpld=cfg_fc_cpld,
        cfg_fc_sel=cfg_fc_sel,

        # Configuration Control Interface
        #cfg_hot_reset_in=cfg_hot_reset_in,
        #cfg_hot_reset_out=cfg_hot_reset_out,
        #cfg_config_space_enable=cfg_config_space_enable,
        #cfg_dsn=cfg_dsn,
        #cfg_ds_port_number=cfg_ds_port_number,
        #cfg_ds_bus_number=cfg_ds_bus_number,
        #cfg_ds_device_number=cfg_ds_device_number,
        #cfg_ds_function_number=cfg_ds_function_number,
        #cfg_power_state_change_ack=cfg_power_state_change_ack,
        #cfg_power_state_change_interrupt=cfg_power_state_change_interrupt,
        cfg_err_cor_in=status_error_cor,
        cfg_err_uncor_in=status_error_uncor,
        #cfg_flr_done=cfg_flr_done,
        #cfg_vf_flr_done=cfg_vf_flr_done,
        #cfg_flr_in_process=cfg_flr_in_process,
        #cfg_vf_flr_in_process=cfg_vf_flr_in_process,
        #cfg_req_pm_transition_l23_ready=cfg_req_pm_transition_l23_ready,
        #cfg_link_training_enable=cfg_link_training_enable,

        # Configuration Interrupt Controller Interface
        #cfg_interrupt_int=cfg_interrupt_int,
        #cfg_interrupt_sent=cfg_interrupt_sent,
        #cfg_interrupt_pending=cfg_interrupt_pending,
        cfg_interrupt_msi_enable=cfg_interrupt_msi_enable,
        cfg_interrupt_msi_mmenable=cfg_interrupt_msi_mmenable,
        cfg_interrupt_msi_mask_update=cfg_interrupt_msi_mask_update,
        cfg_interrupt_msi_data=cfg_interrupt_msi_data,
        cfg_interrupt_msi_select=cfg_interrupt_msi_select,
        cfg_interrupt_msi_int=cfg_interrupt_msi_int,
        cfg_interrupt_msi_pending_status=cfg_interrupt_msi_pending_status,
        cfg_interrupt_msi_pending_status_data_enable=cfg_interrupt_msi_pending_status_data_enable,
        cfg_interrupt_msi_pending_status_function_num=cfg_interrupt_msi_pending_status_function_num,
        cfg_interrupt_msi_sent=cfg_interrupt_msi_sent,
        cfg_interrupt_msi_fail=cfg_interrupt_msi_fail,
        #cfg_interrupt_msix_enable=cfg_interrupt_msix_enable,
        #cfg_interrupt_msix_mask=cfg_interrupt_msix_mask,
        #cfg_interrupt_msix_vf_enable=cfg_interrupt_msix_vf_enable,
        #cfg_interrupt_msix_vf_mask=cfg_interrupt_msix_vf_mask,
        #cfg_interrupt_msix_address=cfg_interrupt_msix_address,
        #cfg_interrupt_msix_data=cfg_interrupt_msix_data,
        #cfg_interrupt_msix_int=cfg_interrupt_msix_int,
        #cfg_interrupt_msix_vec_pending=cfg_interrupt_msix_vec_pending,
        #cfg_interrupt_msix_vec_pending_status=cfg_interrupt_msix_vec_pending_status,
        cfg_interrupt_msi_attr=cfg_interrupt_msi_attr,
        cfg_interrupt_msi_tph_present=cfg_interrupt_msi_tph_present,
        cfg_interrupt_msi_tph_type=cfg_interrupt_msi_tph_type,
        cfg_interrupt_msi_tph_st_tag=cfg_interrupt_msi_tph_st_tag,
        cfg_interrupt_msi_function_number=cfg_interrupt_msi_function_number,

        # Configuration Extend Interface
        #cfg_ext_read_received=cfg_ext_read_received,
        #cfg_ext_write_received=cfg_ext_write_received,
        #cfg_ext_register_number=cfg_ext_register_number,
        #cfg_ext_function_number=cfg_ext_function_number,
        #cfg_ext_write_data=cfg_ext_write_data,
        #cfg_ext_write_byte_enable=cfg_ext_write_byte_enable,
        #cfg_ext_read_data=cfg_ext_read_data,
        #cfg_ext_read_data_valid=cfg_ext_read_data_valid,

        # Clock and Reset Interface
        user_clk=user_clk,
        user_reset=user_reset,
        sys_clk=sys_clk,
        sys_clk_gt=sys_clk,
        sys_reset=sys_reset,
        #phy_rdy_out=phy_rdy_out,

        cq_pause=cq_pause,
        cc_pause=cc_pause,
        rq_pause=rq_pause,
        rc_pause=rc_pause
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        clk_156mhz=clk_156mhz,
        rst_156mhz=rst_156mhz,
        clk_250mhz=user_clk,
        rst_250mhz=user_reset,
        user_led_g=user_led_g,
        user_led_r=user_led_r,
        front_led=front_led,
        user_sw=user_sw,
        m_axis_rq_tdata=m_axis_rq_tdata,
        m_axis_rq_tkeep=m_axis_rq_tkeep,
        m_axis_rq_tlast=m_axis_rq_tlast,
        m_axis_rq_tready=m_axis_rq_tready,
        m_axis_rq_tuser=m_axis_rq_tuser,
        m_axis_rq_tvalid=m_axis_rq_tvalid,
        s_axis_rc_tdata=s_axis_rc_tdata,
        s_axis_rc_tkeep=s_axis_rc_tkeep,
        s_axis_rc_tlast=s_axis_rc_tlast,
        s_axis_rc_tready=s_axis_rc_tready,
        s_axis_rc_tuser=s_axis_rc_tuser,
        s_axis_rc_tvalid=s_axis_rc_tvalid,
        s_axis_cq_tdata=s_axis_cq_tdata,
        s_axis_cq_tkeep=s_axis_cq_tkeep,
        s_axis_cq_tlast=s_axis_cq_tlast,
        s_axis_cq_tready=s_axis_cq_tready,
        s_axis_cq_tuser=s_axis_cq_tuser,
        s_axis_cq_tvalid=s_axis_cq_tvalid,
        m_axis_cc_tdata=m_axis_cc_tdata,
        m_axis_cc_tkeep=m_axis_cc_tkeep,
        m_axis_cc_tlast=m_axis_cc_tlast,
        m_axis_cc_tready=m_axis_cc_tready,
        m_axis_cc_tuser=m_axis_cc_tuser,
        m_axis_cc_tvalid=m_axis_cc_tvalid,
        s_axis_rq_seq_num_0=s_axis_rq_seq_num_0,
        s_axis_rq_seq_num_valid_0=s_axis_rq_seq_num_valid_0,
        s_axis_rq_seq_num_1=s_axis_rq_seq_num_1,
        s_axis_rq_seq_num_valid_1=s_axis_rq_seq_num_valid_1,
        pcie_tfc_nph_av=pcie_tfc_nph_av,
        pcie_tfc_npd_av=pcie_tfc_npd_av,
        cfg_max_payload=cfg_max_payload,
        cfg_max_read_req=cfg_max_read_req,
        cfg_mgmt_addr=cfg_mgmt_addr,
        cfg_mgmt_function_number=cfg_mgmt_function_number,
        cfg_mgmt_write=cfg_mgmt_write,
        cfg_mgmt_write_data=cfg_mgmt_write_data,
        cfg_mgmt_byte_enable=cfg_mgmt_byte_enable,
        cfg_mgmt_read=cfg_mgmt_read,
        cfg_mgmt_read_data=cfg_mgmt_read_data,
        cfg_mgmt_read_write_done=cfg_mgmt_read_write_done,
        cfg_fc_ph=cfg_fc_ph,
        cfg_fc_pd=cfg_fc_pd,
        cfg_fc_nph=cfg_fc_nph,
        cfg_fc_npd=cfg_fc_npd,
        cfg_fc_cplh=cfg_fc_cplh,
        cfg_fc_cpld=cfg_fc_cpld,
        cfg_fc_sel=cfg_fc_sel,
        cfg_interrupt_msi_enable=cfg_interrupt_msi_enable,
        cfg_interrupt_msi_int=cfg_interrupt_msi_int,
        cfg_interrupt_msi_sent=cfg_interrupt_msi_sent,
        cfg_interrupt_msi_fail=cfg_interrupt_msi_fail,
        cfg_interrupt_msi_mmenable=cfg_interrupt_msi_mmenable,
        cfg_interrupt_msi_pending_status=cfg_interrupt_msi_pending_status,
        cfg_interrupt_msi_mask_update=cfg_interrupt_msi_mask_update,
        cfg_interrupt_msi_select=cfg_interrupt_msi_select,
        cfg_interrupt_msi_data=cfg_interrupt_msi_data,
        cfg_interrupt_msi_pending_status_function_num=cfg_interrupt_msi_pending_status_function_num,
        cfg_interrupt_msi_pending_status_data_enable=cfg_interrupt_msi_pending_status_data_enable,
        cfg_interrupt_msi_attr=cfg_interrupt_msi_attr,
        cfg_interrupt_msi_tph_present=cfg_interrupt_msi_tph_present,
        cfg_interrupt_msi_tph_type=cfg_interrupt_msi_tph_type,
        cfg_interrupt_msi_tph_st_tag=cfg_interrupt_msi_tph_st_tag,
        cfg_interrupt_msi_function_number=cfg_interrupt_msi_function_number,
        status_error_cor=status_error_cor,
        status_error_uncor=status_error_uncor,
        qsfp_0_tx_clk_0=qsfp_0_tx_clk_0,
        qsfp_0_tx_rst_0=qsfp_0_tx_rst_0,
        qsfp_0_txd_0=qsfp_0_txd_0,
        qsfp_0_txc_0=qsfp_0_txc_0,
        qsfp_0_rx_clk_0=qsfp_0_rx_clk_0,
        qsfp_0_rx_rst_0=qsfp_0_rx_rst_0,
        qsfp_0_rxd_0=qsfp_0_rxd_0,
        qsfp_0_rxc_0=qsfp_0_rxc_0,
        qsfp_0_tx_clk_1=qsfp_0_tx_clk_1,
        qsfp_0_tx_rst_1=qsfp_0_tx_rst_1,
        qsfp_0_txd_1=qsfp_0_txd_1,
        qsfp_0_txc_1=qsfp_0_txc_1,
        qsfp_0_rx_clk_1=qsfp_0_rx_clk_1,
        qsfp_0_rx_rst_1=qsfp_0_rx_rst_1,
        qsfp_0_rxd_1=qsfp_0_rxd_1,
        qsfp_0_rxc_1=qsfp_0_rxc_1,
        qsfp_0_tx_clk_2=qsfp_0_tx_clk_2,
        qsfp_0_tx_rst_2=qsfp_0_tx_rst_2,
        qsfp_0_txd_2=qsfp_0_txd_2,
        qsfp_0_txc_2=qsfp_0_txc_2,
        qsfp_0_rx_clk_2=qsfp_0_rx_clk_2,
        qsfp_0_rx_rst_2=qsfp_0_rx_rst_2,
        qsfp_0_rxd_2=qsfp_0_rxd_2,
        qsfp_0_rxc_2=qsfp_0_rxc_2,
        qsfp_0_tx_clk_3=qsfp_0_tx_clk_3,
        qsfp_0_tx_rst_3=qsfp_0_tx_rst_3,
        qsfp_0_txd_3=qsfp_0_txd_3,
        qsfp_0_txc_3=qsfp_0_txc_3,
        qsfp_0_rx_clk_3=qsfp_0_rx_clk_3,
        qsfp_0_rx_rst_3=qsfp_0_rx_rst_3,
        qsfp_0_rxd_3=qsfp_0_rxd_3,
        qsfp_0_rxc_3=qsfp_0_rxc_3,
        qsfp_0_modprs_l=qsfp_0_modprs_l,
        qsfp_0_sel_l=qsfp_0_sel_l,
        qsfp_1_tx_clk_0=qsfp_1_tx_clk_0,
        qsfp_1_tx_rst_0=qsfp_1_tx_rst_0,
        qsfp_1_txd_0=qsfp_1_txd_0,
        qsfp_1_txc_0=qsfp_1_txc_0,
        qsfp_1_rx_clk_0=qsfp_1_rx_clk_0,
        qsfp_1_rx_rst_0=qsfp_1_rx_rst_0,
        qsfp_1_rxd_0=qsfp_1_rxd_0,
        qsfp_1_rxc_0=qsfp_1_rxc_0,
        qsfp_1_tx_clk_1=qsfp_1_tx_clk_1,
        qsfp_1_tx_rst_1=qsfp_1_tx_rst_1,
        qsfp_1_txd_1=qsfp_1_txd_1,
        qsfp_1_txc_1=qsfp_1_txc_1,
        qsfp_1_rx_clk_1=qsfp_1_rx_clk_1,
        qsfp_1_rx_rst_1=qsfp_1_rx_rst_1,
        qsfp_1_rxd_1=qsfp_1_rxd_1,
        qsfp_1_rxc_1=qsfp_1_rxc_1,
        qsfp_1_tx_clk_2=qsfp_1_tx_clk_2,
        qsfp_1_tx_rst_2=qsfp_1_tx_rst_2,
        qsfp_1_txd_2=qsfp_1_txd_2,
        qsfp_1_txc_2=qsfp_1_txc_2,
        qsfp_1_rx_clk_2=qsfp_1_rx_clk_2,
        qsfp_1_rx_rst_2=qsfp_1_rx_rst_2,
        qsfp_1_rxd_2=qsfp_1_rxd_2,
        qsfp_1_rxc_2=qsfp_1_rxc_2,
        qsfp_1_tx_clk_3=qsfp_1_tx_clk_3,
        qsfp_1_tx_rst_3=qsfp_1_tx_rst_3,
        qsfp_1_txd_3=qsfp_1_txd_3,
        qsfp_1_txc_3=qsfp_1_txc_3,
        qsfp_1_rx_clk_3=qsfp_1_rx_clk_3,
        qsfp_1_rx_rst_3=qsfp_1_rx_rst_3,
        qsfp_1_rxd_3=qsfp_1_rxd_3,
        qsfp_1_rxc_3=qsfp_1_rxc_3,
        qsfp_1_modprs_l=qsfp_1_modprs_l,
        qsfp_1_sel_l=qsfp_1_sel_l,
        qsfp_reset_l=qsfp_reset_l,
        qsfp_int_l=qsfp_int_l,
        qsfp_i2c_scl_i=qsfp_i2c_scl_i,
        qsfp_i2c_scl_o=qsfp_i2c_scl_o,
        qsfp_i2c_scl_t=qsfp_i2c_scl_t,
        qsfp_i2c_sda_i=qsfp_i2c_sda_i,
        qsfp_i2c_sda_o=qsfp_i2c_sda_o,
        qsfp_i2c_sda_t=qsfp_i2c_sda_t,
        eeprom_i2c_scl_i=eeprom_i2c_scl_i,
        eeprom_i2c_scl_o=eeprom_i2c_scl_o,
        eeprom_i2c_scl_t=eeprom_i2c_scl_t,
        eeprom_i2c_sda_i=eeprom_i2c_sda_i,
        eeprom_i2c_sda_o=eeprom_i2c_sda_o,
        eeprom_i2c_sda_t=eeprom_i2c_sda_t,
        eeprom_wp=eeprom_wp,
        qspi_clk=qspi_clk,
        qspi_0_dq_i=qspi_0_dq_i,
        qspi_0_dq_o=qspi_0_dq_o,
        qspi_0_dq_oe=qspi_0_dq_oe,
        qspi_0_cs=qspi_0_cs,
        qspi_1_dq_i=qspi_1_dq_i,
        qspi_1_dq_o=qspi_1_dq_o,
        qspi_1_dq_oe=qspi_1_dq_oe,
        qspi_1_cs=qspi_1_cs
    )

    @always(delay(5))
    def clkgen():
        clk.next = not clk

    @always(delay(1))
    def qsfp_clkgen():
        qsfp_0_tx_clk_0.next = not qsfp_0_tx_clk_0
        qsfp_0_rx_clk_0.next = not qsfp_0_rx_clk_0
        qsfp_0_tx_clk_1.next = not qsfp_0_tx_clk_1
        qsfp_0_rx_clk_1.next = not qsfp_0_rx_clk_1
        qsfp_0_tx_clk_2.next = not qsfp_0_tx_clk_2
        qsfp_0_rx_clk_2.next = not qsfp_0_rx_clk_2
        qsfp_0_tx_clk_3.next = not qsfp_0_tx_clk_3
        qsfp_0_rx_clk_3.next = not qsfp_0_rx_clk_3
        qsfp_1_tx_clk_0.next = not qsfp_1_tx_clk_0
        qsfp_1_rx_clk_0.next = not qsfp_1_rx_clk_0
        qsfp_1_tx_clk_1.next = not qsfp_1_tx_clk_1
        qsfp_1_rx_clk_1.next = not qsfp_1_rx_clk_1
        qsfp_1_tx_clk_2.next = not qsfp_1_tx_clk_2
        qsfp_1_rx_clk_2.next = not qsfp_1_rx_clk_2
        qsfp_1_tx_clk_3.next = not qsfp_1_tx_clk_3
        qsfp_1_rx_clk_3.next = not qsfp_1_rx_clk_3

    @always_comb
    def clk_logic():
        sys_clk.next = clk
        sys_reset.next = not rst

    loopback_enable = Signal(bool(0))

    @instance
    def loopback():
        while True:

            yield clk.posedge

            if loopback_enable:
                if not qsfp_0_0_sink.empty():
                    pkt = qsfp_0_0_sink.recv()
                    qsfp_0_0_source.send(pkt)
                if not qsfp_0_1_sink.empty():
                    pkt = qsfp_0_1_sink.recv()
                    qsfp_0_1_source.send(pkt)
                if not qsfp_0_2_sink.empty():
                    pkt = qsfp_0_2_sink.recv()
                    qsfp_0_2_source.send(pkt)
                if not qsfp_0_3_sink.empty():
                    pkt = qsfp_0_3_sink.recv()
                    qsfp_0_3_source.send(pkt)
                if not qsfp_1_0_sink.empty():
                    pkt = qsfp_1_0_sink.recv()
                    qsfp_1_0_source.send(pkt)
                if not qsfp_1_1_sink.empty():
                    pkt = qsfp_1_1_sink.recv()
                    qsfp_1_1_source.send(pkt)
                if not qsfp_1_2_sink.empty():
                    pkt = qsfp_1_2_sink.recv()
                    qsfp_1_2_source.send(pkt)
                if not qsfp_1_3_sink.empty():
                    pkt = qsfp_1_3_sink.recv()
                    qsfp_1_3_source.send(pkt)

    @instance
    def check():
        yield delay(100)
        yield clk.posedge
        rst.next = 1
        qsfp_0_tx_rst_0.next = 1
        qsfp_0_rx_rst_0.next = 1
        qsfp_0_tx_rst_1.next = 1
        qsfp_0_rx_rst_1.next = 1
        qsfp_0_tx_rst_2.next = 1
        qsfp_0_rx_rst_2.next = 1
        qsfp_0_tx_rst_3.next = 1
        qsfp_0_rx_rst_3.next = 1
        qsfp_1_tx_rst_0.next = 1
        qsfp_1_rx_rst_0.next = 1
        qsfp_1_tx_rst_1.next = 1
        qsfp_1_rx_rst_1.next = 1
        qsfp_1_tx_rst_2.next = 1
        qsfp_1_rx_rst_2.next = 1
        qsfp_1_tx_rst_3.next = 1
        qsfp_1_rx_rst_3.next = 1
        yield clk.posedge
        yield delay(100)
        rst.next = 0
        qsfp_0_tx_rst_0.next = 0
        qsfp_0_rx_rst_0.next = 0
        qsfp_0_tx_rst_1.next = 0
        qsfp_0_rx_rst_1.next = 0
        qsfp_0_tx_rst_2.next = 0
        qsfp_0_rx_rst_2.next = 0
        qsfp_0_tx_rst_3.next = 0
        qsfp_0_rx_rst_3.next = 0
        qsfp_1_tx_rst_0.next = 0
        qsfp_1_rx_rst_0.next = 0
        qsfp_1_tx_rst_1.next = 0
        qsfp_1_rx_rst_1.next = 0
        qsfp_1_tx_rst_2.next = 0
        qsfp_1_rx_rst_2.next = 0
        qsfp_1_tx_rst_3.next = 0
        qsfp_1_rx_rst_3.next = 0
        yield clk.posedge
        yield delay(100)
        yield clk.posedge

        # testbench stimulus

        current_tag = 1

        yield clk.posedge
        print("test 1: enumeration")
        current_test.next = 1

        yield rc.enumerate(enable_bus_mastering=True, configure_msi=True)

        dev_pf0_bar0 = dev.functions[0].bar[0] & 0xfffffffc
        dev_pf0_bar1 = dev.functions[0].bar[1] & 0xfffffffc

        yield delay(100)

        yield clk.posedge
        print("test 2: init NIC")
        current_test.next = 2

        #data = yield from rc.mem_read(dev_pf0_bar0+0x20000+0x10, 4);
        #print(data)

        #yield delay(1000)

        #raise StopSimulation

        yield from driver.init_dev(dev.functions[0].get_id())
        yield from driver.interfaces[0].open()
        #yield from driver.interfaces[1].open()

        # enable queues
        yield from rc.mem_write_dword(driver.interfaces[0].ports[0].hw_addr+mqnic.MQNIC_PORT_REG_SCHED_ENABLE, 0x00000001)
        for k in range(driver.interfaces[0].tx_queue_count):
            yield from rc.mem_write_dword(driver.interfaces[0].ports[0].schedulers[0].hw_addr+4*k, 0x00000003)

        yield from rc.mem_read(driver.hw_addr, 4) # wait for all writes to complete

        yield delay(100)

        yield clk.posedge
        print("test 3: send and receive a packet")
        current_test.next = 3

        # test bad packet
        #qsfp_0_0_source.send(b'\x55\x55\x55\x55\x55\xd5'+bytearray(range(128)))

        data = bytearray([x%256 for x in range(1024)])

        yield from driver.interfaces[0].start_xmit(data, 0)

        yield qsfp_0_0_sink.wait()

        pkt = qsfp_0_0_sink.recv()
        print(pkt)

        qsfp_0_0_source.send(pkt)

        yield driver.interfaces[0].wait()

        pkt = driver.interfaces[0].recv()

        print(pkt)
        assert frame_checksum(pkt.data) == pkt.rx_checksum

        # yield from driver.interfaces[1].start_xmit(data, 0)

        # yield qsfp_1_0_sink.wait()

        # pkt = qsfp_1_0_sink.recv()
        # print(pkt)

        # qsfp_1_0_source.send(pkt)

        # yield driver.interfaces[1].wait()

        # pkt = driver.interfaces[1].recv()

        # print(pkt)
        # assert frame_checksum(pkt.data) == pkt.rx_checksum

        yield delay(100)

        yield clk.posedge
        print("test 4: checksum tests")
        current_test.next = 4

        test_frame = udp_ep.UDPFrame()
        test_frame.eth_dest_mac = 0xDAD1D2D3D4D5
        test_frame.eth_src_mac = 0x5A5152535455
        test_frame.eth_type = 0x0800
        test_frame.ip_version = 4
        test_frame.ip_ihl = 5
        test_frame.ip_length = None
        test_frame.ip_identification = 0
        test_frame.ip_flags = 2
        test_frame.ip_fragment_offset = 0
        test_frame.ip_ttl = 64
        test_frame.ip_protocol = 0x11
        test_frame.ip_header_checksum = None
        test_frame.ip_source_ip = 0xc0a80164
        test_frame.ip_dest_ip = 0xc0a80165
        test_frame.udp_source_port = 1
        test_frame.udp_dest_port = 2
        test_frame.udp_length = None
        test_frame.udp_checksum = None
        test_frame.payload = bytearray((x%256 for x in range(256)))

        test_frame.set_udp_pseudo_header_checksum()

        axis_frame = test_frame.build_axis()

        yield from driver.interfaces[0].start_xmit(axis_frame.data, 0, 34, 6)

        yield qsfp_0_0_sink.wait()

        pkt = qsfp_0_0_sink.recv()
        print(pkt)

        qsfp_0_0_source.send(pkt)

        yield driver.interfaces[0].wait()

        pkt = driver.interfaces[0].recv()

        print(pkt)

        assert pkt.rx_checksum == frame_checksum(pkt.data)

        check_frame = udp_ep.UDPFrame()
        check_frame.parse_axis(pkt.data)

        assert check_frame.verify_checksums()

        yield delay(100)

        yield clk.posedge
        print("test 5: multiple small packets")
        current_test.next = 5

        count = 64

        pkts = [bytearray([(x+k)%256 for x in range(64)]) for k in range(count)]

        loopback_enable.next = True

        for p in pkts:
            yield from driver.interfaces[0].start_xmit(p, 0)

        for k in range(count):
            pkt = driver.interfaces[0].recv()

            if not pkt:
                yield driver.interfaces[0].wait()
                pkt = driver.interfaces[0].recv()

            print(pkt)
            assert pkt.data == pkts[k]
            assert frame_checksum(pkt.data) == pkt.rx_checksum

        loopback_enable.next = False

        yield delay(100)

        yield clk.posedge
        print("test 6: multiple large packets")
        current_test.next = 6

        count = 64

        pkts = [bytearray([(x+k)%256 for x in range(1514)]) for k in range(count)]

        loopback_enable.next = True

        for p in pkts:
            yield from driver.interfaces[0].start_xmit(p, 0)

        for k in range(count):
            pkt = driver.interfaces[0].recv()

            if not pkt:
                yield driver.interfaces[0].wait()
                pkt = driver.interfaces[0].recv()

            print(pkt)
            assert pkt.data == pkts[k]
            assert frame_checksum(pkt.data) == pkt.rx_checksum

        loopback_enable.next = False

        yield delay(100)

        # yield clk.posedge
        # print("test 7: send from multiple queues")
        # current_test.next = 7

        # count = 64

        # pkts = [bytearray([(x+k)%256 for x in range(1514)]) for k in range(count)]

        # loopback_enable.next = True

        # for k in range(count):
        #     yield from driver.interfaces[0].start_xmit(pkts[k], k%4)

        # for k in range(count):
        #     pkt = driver.interfaces[0].recv()

        #     if not pkt:
        #         yield driver.interfaces[0].wait()
        #         pkt = driver.interfaces[0].recv()

        #     print(pkt)
        #     #assert pkt.data == pkts[k]
        #     assert frame_checksum(pkt.data) == pkt.rx_checksum

        # loopback_enable.next = False

        # yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
