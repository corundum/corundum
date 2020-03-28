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
import pcie_us
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
srcs.append("../rtl/common/tdma_scheduler.v")
srcs.append("../rtl/common/event_mux.v")
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
    AXIS_PCIE_DATA_WIDTH = 256
    AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32)
    AXIS_PCIE_RC_USER_WIDTH = 75
    AXIS_PCIE_RQ_USER_WIDTH = 60
    AXIS_PCIE_CQ_USER_WIDTH = 85
    AXIS_PCIE_CC_USER_WIDTH = 33
    RQ_SEQ_NUM_WIDTH = 4
    BAR0_APERTURE = 24

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    clk_250mhz = Signal(bool(0))
    rst_250mhz = Signal(bool(0))
    btn = Signal(intbv(0)[2:])
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
    s_axis_rq_seq_num = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    s_axis_rq_seq_num_valid = Signal(bool(0))
    pcie_tfc_nph_av = Signal(intbv(0)[2:])
    pcie_tfc_npd_av = Signal(intbv(0)[2:])
    cfg_max_payload = Signal(intbv(0)[3:])
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
    cfg_interrupt_msi_vf_enable = Signal(intbv(0)[8:])
    cfg_interrupt_msi_mmenable = Signal(intbv(0)[12:])
    cfg_interrupt_msi_mask_update = Signal(bool(0))
    cfg_interrupt_msi_data = Signal(intbv(0)[32:])
    cfg_interrupt_msi_sent = Signal(bool(0))
    cfg_interrupt_msi_fail = Signal(bool(0))
    sfp_1_tx_clk = Signal(bool(0))
    sfp_1_tx_rst = Signal(bool(0))
    sfp_1_rx_clk = Signal(bool(0))
    sfp_1_rx_rst = Signal(bool(0))
    sfp_1_rxd = Signal(intbv(0)[64:])
    sfp_1_rxc = Signal(intbv(0)[8:])
    sfp_2_tx_clk = Signal(bool(0))
    sfp_2_tx_rst = Signal(bool(0))
    sfp_2_rx_clk = Signal(bool(0))
    sfp_2_rx_rst = Signal(bool(0))
    sfp_2_rxd = Signal(intbv(0)[64:])
    sfp_2_rxc = Signal(intbv(0)[8:])
    sfp_3_tx_clk = Signal(bool(0))
    sfp_3_tx_rst = Signal(bool(0))
    sfp_3_rx_clk = Signal(bool(0))
    sfp_3_rx_rst = Signal(bool(0))
    sfp_3_rxd = Signal(intbv(0)[64:])
    sfp_3_rxc = Signal(intbv(0)[8:])
    sfp_4_tx_clk = Signal(bool(0))
    sfp_4_tx_rst = Signal(bool(0))
    sfp_4_rx_clk = Signal(bool(0))
    sfp_4_rx_rst = Signal(bool(0))
    sfp_4_rxd = Signal(intbv(0)[64:])
    sfp_4_rxc = Signal(intbv(0)[8:])
    i2c_scl_i = Signal(bool(1))
    i2c_sda_i = Signal(bool(1))

    # Outputs
    sfp_1_led = Signal(intbv(0)[2:])
    sfp_2_led = Signal(intbv(0)[2:])
    sfp_3_led = Signal(intbv(0)[2:])
    sfp_4_led = Signal(intbv(0)[2:])
    led = Signal(intbv(0)[2:])
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
    cfg_mgmt_addr = Signal(intbv(0)[19:])
    cfg_mgmt_write = Signal(bool(0))
    cfg_mgmt_write_data = Signal(intbv(0)[32:])
    cfg_mgmt_byte_enable = Signal(intbv(0)[4:])
    cfg_mgmt_read = Signal(bool(0))
    cfg_fc_sel = Signal(intbv(4)[3:])
    cfg_interrupt_msi_int = Signal(intbv(0)[32:])
    cfg_interrupt_msi_pending_status = Signal(intbv(0)[32:])
    cfg_interrupt_msi_select = Signal(intbv(0)[4:])
    cfg_interrupt_msi_pending_status_function_num = Signal(intbv(0)[4:])
    cfg_interrupt_msi_pending_status_data_enable = Signal(bool(0))
    cfg_interrupt_msi_attr = Signal(intbv(0)[3:])
    cfg_interrupt_msi_tph_present = Signal(bool(0))
    cfg_interrupt_msi_tph_type = Signal(intbv(0)[2:])
    cfg_interrupt_msi_tph_st_tag = Signal(intbv(0)[9:])
    cfg_interrupt_msi_function_number = Signal(intbv(0)[4:])
    sfp_1_txd = Signal(intbv(0)[64:])
    sfp_1_txc = Signal(intbv(0)[8:])
    sfp_2_txd = Signal(intbv(0)[64:])
    sfp_2_txc = Signal(intbv(0)[8:])
    sfp_3_txd = Signal(intbv(0)[64:])
    sfp_3_txc = Signal(intbv(0)[8:])
    sfp_4_txd = Signal(intbv(0)[64:])
    sfp_4_txc = Signal(intbv(0)[8:])
    i2c_scl_o = Signal(bool(1))
    i2c_scl_t = Signal(bool(1))
    i2c_sda_o = Signal(bool(1))
    i2c_sda_t = Signal(bool(1))

    # sources and sinks
    sfp_1_source = xgmii_ep.XGMIISource()
    sfp_1_source_logic = sfp_1_source.create_logic(sfp_1_rx_clk, sfp_1_rx_rst, txd=sfp_1_rxd, txc=sfp_1_rxc, name='sfp_1_source')

    sfp_1_sink = xgmii_ep.XGMIISink()
    sfp_1_sink_logic = sfp_1_sink.create_logic(sfp_1_tx_clk, sfp_1_tx_rst, rxd=sfp_1_txd, rxc=sfp_1_txc, name='sfp_1_sink')

    sfp_2_source = xgmii_ep.XGMIISource()
    sfp_2_source_logic = sfp_2_source.create_logic(sfp_2_rx_clk, sfp_2_rx_rst, txd=sfp_2_rxd, txc=sfp_2_rxc, name='sfp_2_source')

    sfp_2_sink = xgmii_ep.XGMIISink()
    sfp_2_sink_logic = sfp_2_sink.create_logic(sfp_2_tx_clk, sfp_2_tx_rst, rxd=sfp_2_txd, rxc=sfp_2_txc, name='sfp_2_sink')

    sfp_3_source = xgmii_ep.XGMIISource()
    sfp_3_source_logic = sfp_3_source.create_logic(sfp_3_rx_clk, sfp_3_rx_rst, txd=sfp_3_rxd, txc=sfp_3_rxc, name='sfp_3_source')

    sfp_3_sink = xgmii_ep.XGMIISink()
    sfp_3_sink_logic = sfp_3_sink.create_logic(sfp_3_tx_clk, sfp_3_tx_rst, rxd=sfp_3_txd, rxc=sfp_3_txc, name='sfp_3_sink')

    sfp_4_source = xgmii_ep.XGMIISource()
    sfp_4_source_logic = sfp_4_source.create_logic(sfp_4_rx_clk, sfp_4_rx_rst, txd=sfp_4_rxd, txc=sfp_4_rxc, name='sfp_4_source')

    sfp_4_sink = xgmii_ep.XGMIISink()
    sfp_4_sink_logic = sfp_4_sink.create_logic(sfp_4_tx_clk, sfp_4_tx_rst, rxd=sfp_4_txd, rxc=sfp_4_txc, name='sfp_4_sink')

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

    dev = pcie_us.UltrascalePCIe()

    dev.pcie_generation = 3
    dev.pcie_link_width = 8
    dev.user_clock_frequency = 250e6

    dev.functions[0].msi_multiple_message_capable = 5

    dev.functions[0].configure_bar(0, 2**BAR0_APERTURE)

    rc.make_port().connect(dev)

    pcie_logic = dev.create_logic(
        # Completer reQuest Interface
        m_axis_cq_tdata=s_axis_cq_tdata,
        m_axis_cq_tuser=s_axis_cq_tuser,
        m_axis_cq_tlast=s_axis_cq_tlast,
        m_axis_cq_tkeep=s_axis_cq_tkeep,
        m_axis_cq_tvalid=s_axis_cq_tvalid,
        m_axis_cq_tready=s_axis_cq_tready,
        #pcie_cq_np_req=pcie_cq_np_req,
        pcie_cq_np_req=Signal(bool(1)),
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
        pcie_rq_seq_num=s_axis_rq_seq_num,
        pcie_rq_seq_num_vld=s_axis_rq_seq_num_valid,
        #pcie_rq_tag=pcie_rq_tag,
        #pcie_rq_tag_vld=pcie_rq_tag_vld,

        # Requester Completion Interface
        m_axis_rc_tdata=s_axis_rc_tdata,
        m_axis_rc_tuser=s_axis_rc_tuser,
        m_axis_rc_tlast=s_axis_rc_tlast,
        m_axis_rc_tkeep=s_axis_rc_tkeep,
        m_axis_rc_tvalid=s_axis_rc_tvalid,
        m_axis_rc_tready=s_axis_rc_tready,

        # Transmit Flow Control Interface
        pcie_tfc_nph_av=pcie_tfc_nph_av,
        pcie_tfc_npd_av=pcie_tfc_npd_av,

        # Configuration Management Interface
        cfg_mgmt_addr=cfg_mgmt_addr,
        cfg_mgmt_write=cfg_mgmt_write,
        cfg_mgmt_write_data=cfg_mgmt_write_data,
        cfg_mgmt_byte_enable=cfg_mgmt_byte_enable,
        cfg_mgmt_read=cfg_mgmt_read,
        cfg_mgmt_read_data=cfg_mgmt_read_data,
        cfg_mgmt_read_write_done=cfg_mgmt_read_write_done,
        #cfg_mgmt_type1_cfg_reg_access=cfg_mgmt_type1_cfg_reg_access,

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
        #cfg_ltr_enable=cfg_ltr_enable,
        #cfg_ltssm_state=cfg_ltssm_state,
        #cfg_rcb_status=cfg_rcb_status,
        #cfg_dpa_substate_change=cfg_dpa_substate_change,
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

        # Per-Function Status Interface
        #cfg_per_func_status_control=cfg_per_func_status_control,
        #cfg_per_func_status_data=cfg_per_func_status_data,

        # Configuration Control Interface
        #cfg_hot_reset_in=cfg_hot_reset_in,
        #cfg_hot_reset_out=cfg_hot_reset_out,
        #cfg_config_space_enable=cfg_config_space_enable,
        #cfg_per_function_update_done=cfg_per_function_update_done,
        #cfg_per_function_number=cfg_per_function_number,
        #cfg_per_function_output_request=cfg_per_function_output_request,
        #cfg_dsn=cfg_dsn,
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
        cfg_interrupt_msi_vf_enable=cfg_interrupt_msi_vf_enable,
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
        #cfg_interrupt_msix_sent=cfg_interrupt_msix_sent,
        #cfg_interrupt_msix_fail=cfg_interrupt_msix_fail,
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
        #pcie_perstn0_out=pcie_perstn0_out,
        #pcie_perstn1_in=pcie_perstn1_in,
        #pcie_perstn1_out=pcie_perstn1_out
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        clk_250mhz=user_clk,
        rst_250mhz=user_reset,
        btn=btn,
        sfp_1_led=sfp_1_led,
        sfp_2_led=sfp_2_led,
        sfp_3_led=sfp_3_led,
        sfp_4_led=sfp_4_led,
        led=led,
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
        s_axis_rq_seq_num=s_axis_rq_seq_num,
        s_axis_rq_seq_num_valid=s_axis_rq_seq_num_valid,
        pcie_tfc_nph_av=pcie_tfc_nph_av,
        pcie_tfc_npd_av=pcie_tfc_npd_av,
        cfg_max_payload=cfg_max_payload,
        cfg_max_read_req=cfg_max_read_req,
        cfg_mgmt_addr=cfg_mgmt_addr,
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
        cfg_interrupt_msi_vf_enable=cfg_interrupt_msi_vf_enable,
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
        sfp_1_tx_clk=sfp_1_tx_clk,
        sfp_1_tx_rst=sfp_1_tx_rst,
        sfp_1_txd=sfp_1_txd,
        sfp_1_txc=sfp_1_txc,
        sfp_1_rx_clk=sfp_1_rx_clk,
        sfp_1_rx_rst=sfp_1_rx_rst,
        sfp_1_rxd=sfp_1_rxd,
        sfp_1_rxc=sfp_1_rxc,
        sfp_2_tx_clk=sfp_2_tx_clk,
        sfp_2_tx_rst=sfp_2_tx_rst,
        sfp_2_txd=sfp_2_txd,
        sfp_2_txc=sfp_2_txc,
        sfp_2_rx_clk=sfp_2_rx_clk,
        sfp_2_rx_rst=sfp_2_rx_rst,
        sfp_2_rxd=sfp_2_rxd,
        sfp_2_rxc=sfp_2_rxc,
        sfp_3_tx_clk=sfp_3_tx_clk,
        sfp_3_tx_rst=sfp_3_tx_rst,
        sfp_3_txd=sfp_3_txd,
        sfp_3_txc=sfp_3_txc,
        sfp_3_rx_clk=sfp_3_rx_clk,
        sfp_3_rx_rst=sfp_3_rx_rst,
        sfp_3_rxd=sfp_3_rxd,
        sfp_3_rxc=sfp_3_rxc,
        sfp_4_tx_clk=sfp_4_tx_clk,
        sfp_4_tx_rst=sfp_4_tx_rst,
        sfp_4_txd=sfp_4_txd,
        sfp_4_txc=sfp_4_txc,
        sfp_4_rx_clk=sfp_4_rx_clk,
        sfp_4_rx_rst=sfp_4_rx_rst,
        sfp_4_rxd=sfp_4_rxd,
        sfp_4_rxc=sfp_4_rxc,
        i2c_scl_i=i2c_scl_i,
        i2c_scl_o=i2c_scl_o,
        i2c_scl_t=i2c_scl_t,
        i2c_sda_i=i2c_sda_i,
        i2c_sda_o=i2c_sda_o,
        i2c_sda_t=i2c_sda_t
    )

    @always(delay(5))
    def clkgen():
        clk.next = not clk

    @always_comb
    def clk_logic():
        sys_clk.next = clk
        sys_reset.next = not rst

        sfp_1_tx_clk.next = clk
        sfp_1_tx_rst.next = rst
        sfp_1_rx_clk.next = clk
        sfp_1_rx_rst.next = rst
        sfp_2_tx_clk.next = clk
        sfp_2_tx_rst.next = rst
        sfp_2_rx_clk.next = clk
        sfp_2_rx_rst.next = rst
        sfp_3_tx_clk.next = clk
        sfp_3_tx_rst.next = rst
        sfp_3_rx_clk.next = clk
        sfp_3_rx_rst.next = rst
        sfp_4_tx_clk.next = clk
        sfp_4_tx_rst.next = rst
        sfp_4_rx_clk.next = clk
        sfp_4_rx_rst.next = rst

    loopback_enable = Signal(bool(0))

    @instance
    def loopback():
        while True:

            yield clk.posedge

            if loopback_enable:
                if not sfp_1_sink.empty():
                    pkt = sfp_1_sink.recv()
                    sfp_1_source.send(pkt)
                if not sfp_2_sink.empty():
                    pkt = sfp_2_sink.recv()
                    sfp_2_source.send(pkt)
                if not sfp_3_sink.empty():
                    pkt = sfp_3_sink.recv()
                    sfp_3_source.send(pkt)
                if not sfp_4_sink.empty():
                    pkt = sfp_4_sink.recv()
                    sfp_4_source.send(pkt)

    @instance
    def check():
        yield delay(100)
        yield clk.posedge
        rst.next = 1
        yield clk.posedge
        rst.next = 0
        yield clk.posedge
        yield delay(100)
        yield clk.posedge

        # testbench stimulus

        current_tag = 1

        yield clk.posedge
        print("test 1: enumeration")
        current_test.next = 1

        yield rc.enumerate()

        yield delay(100)

        yield clk.posedge
        print("test 2: init NIC")
        current_test.next = 2

        yield from driver.init_dev(dev.functions[0].get_id())
        yield from driver.interfaces[0].open()

        # enable queues
        yield from rc.mem_write_dword(driver.interfaces[0].ports[0].hw_addr+mqnic.MQNIC_PORT_REG_SCHED_ENABLE, 0x00000001)
        for k in range(driver.interfaces[0].tx_queue_count):
            yield from rc.mem_write_dword(driver.interfaces[0].ports[0].schedulers[0].hw_addr+4*k, 0x00000003)

        yield from rc.mem_read(driver.hw_addr, 4) # wait for all writes to complete

        yield delay(100)

        yield clk.posedge
        print("test 3: send and receive a packet")
        current_test.next = 3

        data = bytearray([x%256 for x in range(1024)])

        yield from driver.interfaces[0].start_xmit(data, 0)

        yield sfp_1_sink.wait()

        pkt = sfp_1_sink.recv()
        print(pkt)

        sfp_1_source.send(pkt)

        yield driver.interfaces[0].wait()

        pkt = driver.interfaces[0].recv()

        print(pkt)

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

        yield sfp_1_sink.wait()

        pkt = sfp_1_sink.recv()
        print(pkt)

        sfp_1_source.send(pkt)

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

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
