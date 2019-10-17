#!/usr/bin/env python
"""

Copyright (c) 2018 Alex Forencich

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

from myhdl import *
import struct
import os

import pcie
import pcie_us

#pcie.trace_routing = True

def bench():

    # Parameters
    dw = 128

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    # Outputs


    # Completer reQuest Interface
    m_axis_cq_tdata=Signal(intbv(0)[dw:])
    m_axis_cq_tuser=Signal(intbv(0)[85:])
    m_axis_cq_tlast=Signal(bool(0))
    m_axis_cq_tkeep=Signal(intbv(0)[int(dw/32):])
    m_axis_cq_tvalid=Signal(bool(0))
    m_axis_cq_tready=Signal(bool(0))
    pcie_cq_np_req=Signal(bool(1))
    pcie_cq_np_req_count=Signal(intbv(0)[6:])

    # Completer Completion Interface
    s_axis_cc_tdata=Signal(intbv(0)[dw:])
    s_axis_cc_tuser=Signal(intbv(0)[33:])
    s_axis_cc_tlast=Signal(bool(0))
    s_axis_cc_tkeep=Signal(intbv(0)[int(dw/32):])
    s_axis_cc_tvalid=Signal(bool(0))
    s_axis_cc_tready=Signal(bool(0))

    # Requester reQuest Interface
    s_axis_rq_tdata=Signal(intbv(0)[dw:])
    s_axis_rq_tuser=Signal(intbv(0)[60:])
    s_axis_rq_tlast=Signal(bool(0))
    s_axis_rq_tkeep=Signal(intbv(0)[int(dw/32):])
    s_axis_rq_tvalid=Signal(bool(0))
    s_axis_rq_tready=Signal(bool(0))
    pcie_rq_seq_num=Signal(intbv(0)[4:])
    pcie_rq_seq_num_vld=Signal(bool(0))
    pcie_rq_tag=Signal(intbv(0)[6:])
    pcie_rq_tag_av=Signal(intbv(0)[2:])
    pcie_rq_tag_vld=Signal(bool(0))

    # Requester Completion Interface
    m_axis_rc_tdata=Signal(intbv(0)[dw:])
    m_axis_rc_tuser=Signal(intbv(0)[75:])
    m_axis_rc_tlast=Signal(bool(0))
    m_axis_rc_tkeep=Signal(intbv(0)[int(dw/32):])
    m_axis_rc_tvalid=Signal(bool(0))
    m_axis_rc_tready=Signal(bool(0))

    # Transmit Flow Control Interface
    pcie_tfc_nph_av=Signal(intbv(0)[2:])
    pcie_tfc_npd_av=Signal(intbv(0)[2:])

    # Configuration Management Interface
    cfg_mgmt_addr=Signal(intbv(0)[19:])
    cfg_mgmt_write=Signal(bool(0))
    cfg_mgmt_write_data=Signal(intbv(0)[32:])
    cfg_mgmt_byte_enable=Signal(intbv(0)[4:])
    cfg_mgmt_read=Signal(bool(0))
    cfg_mgmt_read_data=Signal(intbv(0)[32:])
    cfg_mgmt_read_write_done=Signal(bool(0))
    cfg_mgmt_type1_cfg_reg_access=Signal(bool(0))

    # Configuration Status Interface
    cfg_phy_link_down=Signal(bool(0))
    cfg_phy_link_status=Signal(intbv(0)[2:])
    cfg_negotiated_width=Signal(intbv(0)[4:])
    cfg_current_speed=Signal(intbv(0)[3:])
    cfg_max_payload=Signal(intbv(0)[3:])
    cfg_max_read_req=Signal(intbv(0)[3:])
    cfg_function_status=Signal(intbv(0)[8:])
    cfg_vf_status=Signal(intbv(0)[12:])
    cfg_function_power_state=Signal(intbv(0)[6:])
    cfg_vf_power_state=Signal(intbv(0)[18:])
    cfg_link_power_state=Signal(intbv(0)[2:])
    cfg_err_cor_out=Signal(bool(0))
    cfg_err_nonfatal_out=Signal(bool(0))
    cfg_err_fatal_out=Signal(bool(0))
    cfg_ltr_enable=Signal(bool(0))
    cfg_ltssm_state=Signal(intbv(0)[6:])
    cfg_rcb_status=Signal(intbv(0)[2:])
    cfg_dpa_substate_change=Signal(intbv(0)[2:])
    cfg_obff_enable=Signal(intbv(0)[2:])
    cfg_pl_status_change=Signal(bool(0))
    cfg_tph_requester_enable=Signal(intbv(0)[2:])
    cfg_tph_st_mode=Signal(intbv(0)[6:])
    cfg_vf_tph_requester_enable=Signal(intbv(0)[6:])
    cfg_vf_tph_st_mode=Signal(intbv(0)[18:])

    # Configuration Received Message Interface
    cfg_msg_received=Signal(bool(0))
    cfg_msg_received_data=Signal(intbv(0)[8:])
    cfg_msg_received_type=Signal(intbv(0)[5:])

    # Configuration Transmit Message Interface
    cfg_msg_transmit=Signal(bool(0))
    cfg_msg_transmit_type=Signal(intbv(0)[3:])
    cfg_msg_transmit_data=Signal(intbv(0)[32:])
    cfg_msg_transmit_done=Signal(bool(0))

    # Configuration Flow Control Interface
    cfg_fc_ph=Signal(intbv(0)[8:])
    cfg_fc_pd=Signal(intbv(0)[12:])
    cfg_fc_nph=Signal(intbv(0)[8:])
    cfg_fc_npd=Signal(intbv(0)[12:])
    cfg_fc_cplh=Signal(intbv(0)[8:])
    cfg_fc_cpld=Signal(intbv(0)[12:])
    cfg_fc_sel=Signal(intbv(0)[3:])

    # Per-Function Status Interface
    cfg_per_func_status_control=Signal(intbv(0)[3:])
    cfg_per_func_status_data=Signal(intbv(0)[16:])

    # Configuration Control Interface
    cfg_hot_reset_in=Signal(bool(0))
    cfg_hot_reset_out=Signal(bool(0))
    cfg_config_space_enable=Signal(bool(1))
    cfg_per_function_update_done=Signal(bool(0))
    cfg_per_function_number=Signal(intbv(0)[3:])
    cfg_per_function_output_request=Signal(bool(0))
    cfg_dsn=Signal(intbv(0)[64:])
    cfg_ds_bus_number=Signal(intbv(0)[8:])
    cfg_ds_device_number=Signal(intbv(0)[5:])
    cfg_ds_function_number=Signal(intbv(0)[3:])
    cfg_power_state_change_ack=Signal(bool(0))
    cfg_power_state_change_interrupt=Signal(bool(0))
    cfg_err_cor_in=Signal(bool(0))
    cfg_err_uncor_in=Signal(bool(0))
    cfg_flr_done=Signal(intbv(0)[2:])
    cfg_vf_flr_done=Signal(intbv(0)[6:])
    cfg_flr_in_process=Signal(intbv(0)[2:])
    cfg_vf_flr_in_process=Signal(intbv(0)[6:])
    cfg_req_pm_transition_l23_ready=Signal(bool(0))
    cfg_link_training_enable=Signal(bool(1))

    # Configuration Interrupt Controller Interface
    cfg_interrupt_int=Signal(intbv(0)[4:])
    cfg_interrupt_sent=Signal(bool(0))
    cfg_interrupt_pending=Signal(intbv(0)[2:])
    cfg_interrupt_msi_enable=Signal(intbv(0)[4:])
    cfg_interrupt_msi_vf_enable=Signal(intbv(0)[8:])
    cfg_interrupt_msi_mmenable=Signal(intbv(0)[12:])
    cfg_interrupt_msi_mask_update=Signal(bool(0))
    cfg_interrupt_msi_data=Signal(intbv(0)[32:])
    cfg_interrupt_msi_select=Signal(intbv(0)[4:])
    cfg_interrupt_msi_int=Signal(intbv(0)[32:])
    cfg_interrupt_msi_pending_status=Signal(intbv(0)[32:])
    cfg_interrupt_msi_pending_status_data_enable=Signal(bool(0))
    cfg_interrupt_msi_pending_status_function_num=Signal(intbv(0)[4:])
    cfg_interrupt_msi_sent=Signal(bool(0))
    cfg_interrupt_msi_fail=Signal(bool(0))
    cfg_interrupt_msix_enable=Signal(intbv(0)[4:])
    cfg_interrupt_msix_mask=Signal(intbv(0)[4:])
    cfg_interrupt_msix_vf_enable=Signal(intbv(0)[8:])
    cfg_interrupt_msix_vf_mask=Signal(intbv(0)[8:])
    cfg_interrupt_msix_address=Signal(intbv(0)[64:])
    cfg_interrupt_msix_data=Signal(intbv(0)[32:])
    cfg_interrupt_msix_int=Signal(bool(0))
    cfg_interrupt_msix_sent=Signal(bool(0))
    cfg_interrupt_msix_fail=Signal(bool(0))
    cfg_interrupt_msi_attr=Signal(intbv(0)[3:])
    cfg_interrupt_msi_tph_present=Signal(bool(0))
    cfg_interrupt_msi_tph_type=Signal(intbv(0)[2:])
    cfg_interrupt_msi_tph_st_tag=Signal(intbv(0)[9:])
    cfg_interrupt_msi_function_number=Signal(intbv(0)[4:])

    # Configuration Extend Interface
    cfg_ext_read_received=Signal(bool(0))
    cfg_ext_write_received=Signal(bool(0))
    cfg_ext_register_number=Signal(intbv(0)[10:])
    cfg_ext_function_number=Signal(intbv(0)[8:])
    cfg_ext_write_data=Signal(intbv(0)[32:])
    cfg_ext_write_byte_enable=Signal(intbv(0)[4:])
    cfg_ext_read_data=Signal(intbv(0)[32:])
    cfg_ext_read_data_valid=Signal(bool(0))

    # Clock and Reset Interface
    user_clk=Signal(bool(0))
    user_reset=Signal(bool(0))
    user_lnk_up=Signal(bool(0))
    sys_clk=Signal(bool(0))
    sys_reset=Signal(bool(0))
    pcie_perstn0_out=Signal(bool(0))
    pcie_perstn1_in=Signal(bool(0))
    pcie_perstn1_out=Signal(bool(0))

    # sources and sinks
    cq_sink = pcie_us.CQSink()

    cq_sink_logic = cq_sink.create_logic(
        user_clk,
        user_reset,
        tdata=m_axis_cq_tdata,
        tuser=m_axis_cq_tuser,
        tlast=m_axis_cq_tlast,
        tkeep=m_axis_cq_tkeep,
        tvalid=m_axis_cq_tvalid,
        tready=m_axis_cq_tready,
        name='cq_sink'
    )

    cc_source = pcie_us.CCSource()

    cc_source_logic = cc_source.create_logic(
        user_clk,
        user_reset,
        tdata=s_axis_cc_tdata,
        tuser=s_axis_cc_tuser,
        tlast=s_axis_cc_tlast,
        tkeep=s_axis_cc_tkeep,
        tvalid=s_axis_cc_tvalid,
        tready=s_axis_cc_tready,
        name='cc_source'
    )

    rq_source = pcie_us.RQSource()

    rq_source_logic = rq_source.create_logic(
        user_clk,
        user_reset,
        tdata=s_axis_rq_tdata,
        tuser=s_axis_rq_tuser,
        tlast=s_axis_rq_tlast,
        tkeep=s_axis_rq_tkeep,
        tvalid=s_axis_rq_tvalid,
        tready=s_axis_rq_tready,
        name='rq_source'
    )

    rc_sink = pcie_us.RCSink()

    rc_sink_logic = rc_sink.create_logic(
        user_clk,
        user_reset,
        tdata=m_axis_rc_tdata,
        tuser=m_axis_rc_tuser,
        tlast=m_axis_rc_tlast,
        tkeep=m_axis_rc_tkeep,
        tvalid=m_axis_rc_tvalid,
        tready=m_axis_rc_tready,
        name='rc_sink'
    )

    # PCIe devices
    rc = pcie.RootComplex()

    mem_base, mem_data = rc.alloc_region(1024*1024)
    io_base, io_data = rc.alloc_io_region(1024)

    dev = pcie_us.UltrascalePCIe()

    dev.pcie_generation = 3
    dev.pcie_link_width = 4
    dev.user_clock_frequency = 256e6

    regions = [None]*6
    regions[0] = bytearray(1024)
    regions[1] = bytearray(1024*1024)
    regions[3] = bytearray(1024)

    dev.functions[0].msi_multiple_message_capable = 5

    dev.functions[0].configure_bar(0, len(regions[0]))
    dev.functions[0].configure_bar(1, len(regions[1]), True, True)
    dev.functions[0].configure_bar(3, len(regions[3]), False, False, True)

    rc.make_port().connect(dev)

    pcie_logic = dev.create_logic(
        # Completer reQuest Interface
        m_axis_cq_tdata=m_axis_cq_tdata,
        m_axis_cq_tuser=m_axis_cq_tuser,
        m_axis_cq_tlast=m_axis_cq_tlast,
        m_axis_cq_tkeep=m_axis_cq_tkeep,
        m_axis_cq_tvalid=m_axis_cq_tvalid,
        m_axis_cq_tready=m_axis_cq_tready,
        pcie_cq_np_req=pcie_cq_np_req,
        pcie_cq_np_req_count=pcie_cq_np_req_count,

        # Completer Completion Interface
        s_axis_cc_tdata=s_axis_cc_tdata,
        s_axis_cc_tuser=s_axis_cc_tuser,
        s_axis_cc_tlast=s_axis_cc_tlast,
        s_axis_cc_tkeep=s_axis_cc_tkeep,
        s_axis_cc_tvalid=s_axis_cc_tvalid,
        s_axis_cc_tready=s_axis_cc_tready,

        # Requester reQuest Interface
        s_axis_rq_tdata=s_axis_rq_tdata,
        s_axis_rq_tuser=s_axis_rq_tuser,
        s_axis_rq_tlast=s_axis_rq_tlast,
        s_axis_rq_tkeep=s_axis_rq_tkeep,
        s_axis_rq_tvalid=s_axis_rq_tvalid,
        s_axis_rq_tready=s_axis_rq_tready,
        pcie_rq_seq_num=pcie_rq_seq_num,
        pcie_rq_seq_num_vld=pcie_rq_seq_num_vld,
        pcie_rq_tag=pcie_rq_tag,
        pcie_rq_tag_av=pcie_rq_tag_av,
        pcie_rq_tag_vld=pcie_rq_tag_vld,

        # Requester Completion Interface
        m_axis_rc_tdata=m_axis_rc_tdata,
        m_axis_rc_tuser=m_axis_rc_tuser,
        m_axis_rc_tlast=m_axis_rc_tlast,
        m_axis_rc_tkeep=m_axis_rc_tkeep,
        m_axis_rc_tvalid=m_axis_rc_tvalid,
        m_axis_rc_tready=m_axis_rc_tready,

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
        cfg_mgmt_type1_cfg_reg_access=cfg_mgmt_type1_cfg_reg_access,

        # Configuration Status Interface
        cfg_phy_link_down=cfg_phy_link_down,
        cfg_phy_link_status=cfg_phy_link_status,
        cfg_negotiated_width=cfg_negotiated_width,
        cfg_current_speed=cfg_current_speed,
        cfg_max_payload=cfg_max_payload,
        cfg_max_read_req=cfg_max_read_req,
        cfg_function_status=cfg_function_status,
        cfg_vf_status=cfg_vf_status,
        cfg_function_power_state=cfg_function_power_state,
        cfg_vf_power_state=cfg_vf_power_state,
        cfg_link_power_state=cfg_link_power_state,
        cfg_err_cor_out=cfg_err_cor_out,
        cfg_err_nonfatal_out=cfg_err_nonfatal_out,
        cfg_err_fatal_out=cfg_err_fatal_out,
        cfg_ltr_enable=cfg_ltr_enable,
        cfg_ltssm_state=cfg_ltssm_state,
        cfg_rcb_status=cfg_rcb_status,
        cfg_dpa_substate_change=cfg_dpa_substate_change,
        cfg_obff_enable=cfg_obff_enable,
        cfg_pl_status_change=cfg_pl_status_change,
        cfg_tph_requester_enable=cfg_tph_requester_enable,
        cfg_tph_st_mode=cfg_tph_st_mode,
        cfg_vf_tph_requester_enable=cfg_vf_tph_requester_enable,
        cfg_vf_tph_st_mode=cfg_vf_tph_st_mode,

        # Configuration Received Message Interface
        cfg_msg_received=cfg_msg_received,
        cfg_msg_received_data=cfg_msg_received_data,
        cfg_msg_received_type=cfg_msg_received_type,

        # Configuration Transmit Message Interface
        cfg_msg_transmit=cfg_msg_transmit,
        cfg_msg_transmit_type=cfg_msg_transmit_type,
        cfg_msg_transmit_data=cfg_msg_transmit_data,
        cfg_msg_transmit_done=cfg_msg_transmit_done,

        # Configuration Flow Control Interface
        cfg_fc_ph=cfg_fc_ph,
        cfg_fc_pd=cfg_fc_pd,
        cfg_fc_nph=cfg_fc_nph,
        cfg_fc_npd=cfg_fc_npd,
        cfg_fc_cplh=cfg_fc_cplh,
        cfg_fc_cpld=cfg_fc_cpld,
        cfg_fc_sel=cfg_fc_sel,

        # Per-Function Status Interface
        cfg_per_func_status_control=cfg_per_func_status_control,
        cfg_per_func_status_data=cfg_per_func_status_data,

        # Configuration Control Interface
        cfg_hot_reset_in=cfg_hot_reset_in,
        cfg_hot_reset_out=cfg_hot_reset_out,
        cfg_config_space_enable=cfg_config_space_enable,
        cfg_per_function_update_done=cfg_per_function_update_done,
        cfg_per_function_number=cfg_per_function_number,
        cfg_per_function_output_request=cfg_per_function_output_request,
        cfg_dsn=cfg_dsn,
        cfg_ds_bus_number=cfg_ds_bus_number,
        cfg_ds_device_number=cfg_ds_device_number,
        cfg_ds_function_number=cfg_ds_function_number,
        cfg_power_state_change_ack=cfg_power_state_change_ack,
        cfg_power_state_change_interrupt=cfg_power_state_change_interrupt,
        cfg_err_cor_in=cfg_err_cor_in,
        cfg_err_uncor_in=cfg_err_uncor_in,
        cfg_flr_done=cfg_flr_done,
        cfg_vf_flr_done=cfg_vf_flr_done,
        cfg_flr_in_process=cfg_flr_in_process,
        cfg_vf_flr_in_process=cfg_vf_flr_in_process,
        cfg_req_pm_transition_l23_ready=cfg_req_pm_transition_l23_ready,
        cfg_link_training_enable=cfg_link_training_enable,

        # Configuration Interrupt Controller Interface
        cfg_interrupt_int=cfg_interrupt_int,
        cfg_interrupt_sent=cfg_interrupt_sent,
        cfg_interrupt_pending=cfg_interrupt_pending,
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
        cfg_interrupt_msix_enable=cfg_interrupt_msix_enable,
        cfg_interrupt_msix_mask=cfg_interrupt_msix_mask,
        cfg_interrupt_msix_vf_enable=cfg_interrupt_msix_vf_enable,
        cfg_interrupt_msix_vf_mask=cfg_interrupt_msix_vf_mask,
        cfg_interrupt_msix_address=cfg_interrupt_msix_address,
        cfg_interrupt_msix_data=cfg_interrupt_msix_data,
        cfg_interrupt_msix_int=cfg_interrupt_msix_int,
        cfg_interrupt_msix_sent=cfg_interrupt_msix_sent,
        cfg_interrupt_msix_fail=cfg_interrupt_msix_fail,
        cfg_interrupt_msi_attr=cfg_interrupt_msi_attr,
        cfg_interrupt_msi_tph_present=cfg_interrupt_msi_tph_present,
        cfg_interrupt_msi_tph_type=cfg_interrupt_msi_tph_type,
        cfg_interrupt_msi_tph_st_tag=cfg_interrupt_msi_tph_st_tag,
        cfg_interrupt_msi_function_number=cfg_interrupt_msi_function_number,

        # Configuration Extend Interface
        cfg_ext_read_received=cfg_ext_read_received,
        cfg_ext_write_received=cfg_ext_write_received,
        cfg_ext_register_number=cfg_ext_register_number,
        cfg_ext_function_number=cfg_ext_function_number,
        cfg_ext_write_data=cfg_ext_write_data,
        cfg_ext_write_byte_enable=cfg_ext_write_byte_enable,
        cfg_ext_read_data=cfg_ext_read_data,
        cfg_ext_read_data_valid=cfg_ext_read_data_valid,

        # Clock and Reset Interface
        user_clk=user_clk,
        user_reset=user_reset,
        user_lnk_up=user_lnk_up,
        sys_clk=sys_clk,
        sys_clk_gt=sys_clk,
        sys_reset=sys_reset,
        pcie_perstn0_out=pcie_perstn0_out,
        pcie_perstn1_in=pcie_perstn1_in,
        pcie_perstn1_out=pcie_perstn1_out
    )

    @always(delay(5))
    def clkgen():
        clk.next = not clk

    @always_comb
    def clk_logic():
        sys_clk.next = clk
        sys_reset.next = not rst

    @instance
    def user_logic():
        while True:
            yield clk.posedge

            # handle completer request
            if not cq_sink.empty():
                pkt = cq_sink.recv()

                tlp = pcie_us.TLP_us().unpack_us_cq(pkt)

                print(tlp)

                if (tlp.fmt_type == pcie.TLP_IO_READ):
                    print("IO read")

                    cpl = pcie_us.TLP_us()
                    cpl.set_completion(tlp, pcie_us.PcieId(0, 0, 0))
                    cpl.fmt_type = pcie.TLP_CPL_DATA

                    region = tlp.bar_id
                    addr = tlp.address & 0xffff # TODO
                    offset = 0
                    start_offset = None
                    mask = tlp.first_be

                    # perform operation
                    data = bytearray(4)

                    for k in range(4):
                        if mask & (1 << k):
                            if start_offset is None:
                                start_offset = offset
                        else:
                            if start_offset is not None and offset != start_offset:
                                data[start_offset:offset] = regions[region][addr+start_offset:addr+offset]
                            start_offset = None

                        offset += 1

                    if start_offset is not None and offset != start_offset:
                        data[start_offset:offset] = regions[region][addr+start_offset:addr+offset]

                    cpl.set_data(data)
                    cpl.byte_count = 4
                    cpl.length = 1

                    cc_source.send(cpl.pack_us_cc())
                elif (tlp.fmt_type == pcie.TLP_IO_WRITE):
                    print("IO write")

                    cpl = pcie_us.TLP_us()
                    cpl.set_completion(tlp, pcie_us.PcieId(0, 0, 0))

                    region = tlp.bar_id
                    addr = tlp.address & 0xffff # TODO
                    offset = 0
                    start_offset = None
                    mask = tlp.first_be

                    # perform operation
                    data = tlp.get_data()

                    for k in range(4):
                        if mask & (1 << k):
                            if start_offset is None:
                                start_offset = offset
                        else:
                            if start_offset is not None and offset != start_offset:
                                regions[region][addr+start_offset:addr+offset] = data[start_offset:offset]
                            start_offset = None

                        offset += 1

                    if start_offset is not None and offset != start_offset:
                        regions[region][addr+start_offset:addr+offset] = data[start_offset:offset]

                    cc_source.send(cpl.pack_us_cc())
                if (tlp.fmt_type == pcie.TLP_MEM_READ or tlp.fmt_type == pcie.TLP_MEM_READ_64):
                    print("Memory read")

                    # perform operation
                    region = tlp.bar_id
                    addr = tlp.address & 0xffff # TODO
                    offset = 0
                    length = tlp.length
                    
                    # perform read
                    data = regions[region][addr:addr+length*4]

                    # prepare completion TLP(s)
                    n = 0
                    offset = 0
                    addr = tlp.address + offset
                    length = tlp.length*4

                    while n < length:
                        cpl = pcie_us.TLP_us()
                        cpl.set_completion(tlp, pcie_us.PcieId(0, 0, 0))

                        byte_length = length-n
                        cpl.byte_count = byte_length
                        byte_length = min(byte_length, 128 << dev.functions[0].max_payload_size) # max payload size
                        if byte_length > 128:
                            byte_length -= (addr + byte_length) % 128 # RCB align
                        byte_length = min(byte_length, 0x1000 - (addr & 0xfff)) # 4k align

                        cpl.lower_address = addr & 0x7f

                        cpl.set_data(data[offset+n:offset+n+byte_length])

                        print("Completion: %s" % (repr(cpl)))
                        cc_source.send(cpl.pack_us_cc())

                        n += byte_length
                        addr += byte_length
                if (tlp.fmt_type == pcie.TLP_MEM_WRITE or tlp.fmt_type == pcie.TLP_MEM_WRITE_64):
                    print("Memory write")

                    # perform operation
                    region = tlp.bar_id
                    addr = tlp.address & 0xffff # TODO
                    offset = 0
                    start_offset = None
                    mask = tlp.first_be
                    length = tlp.length

                    # perform write
                    data = tlp.get_data()

                    # first dword
                    for k in range(4):
                        if mask & (1 << k):
                            if start_offset is None:
                                start_offset = offset
                        else:
                            if start_offset is not None and offset != start_offset:
                                regions[region][addr+start_offset:addr+offset] = data[start_offset:offset]
                            start_offset = None

                        offset += 1

                    if length > 1:
                        # middle dwords
                        if start_offset is None:
                            start_offset = offset
                        offset += length*4

                        # last dword
                        mask = tlp.last_be

                        for k in range(4):
                            if mask & (1 << k):
                                if start_offset is None:
                                    start_offset = offset
                            else:
                                if start_offset is not None and offset != start_offset:
                                    regions[region][addr+start_offset:addr+offset] = data[start_offset:offset]
                                start_offset = None

                            offset += 1

                    if start_offset is not None and offset != start_offset:
                        regions[region][addr+start_offset:addr+offset] = data[start_offset:offset]

            # haldle requester completion
            #if not rc_sink.empty():
            #    pkt = rc_sink.recv()

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

        current_tag = 1

        yield clk.posedge
        print("test 1: enumeration")
        current_test.next = 1

        yield rc.enumerate(enable_bus_mastering=True, configure_msi=True)

        yield delay(100)

        yield clk.posedge
        print("test 2: IO and memory read/write")
        current_test.next = 2

        yield from rc.io_write(0x80000000, bytearray(range(16)), 100)
        assert regions[3][0:16] == bytearray(range(16))

        val = yield from rc.io_read(0x80000000, 16, 100)
        assert val == bytearray(range(16))

        yield from rc.mem_write(0x80000000, bytearray(range(16)), 100)
        yield delay(100)
        assert regions[0][0:16] == bytearray(range(16))

        val = yield from rc.mem_read(0x80000000, 16, 100)
        assert val == bytearray(range(16))

        yield from rc.mem_write(0x8000000000000000, bytearray(range(16)), 100)
        yield delay(100)
        assert regions[1][0:16] == bytearray(range(16))

        val = yield from rc.mem_read(0x8000000000000000, 16, 100)
        assert val == bytearray(range(16))

        yield delay(100)

        # yield clk.posedge
        # print("test 3: Large read/write")
        # current_test.next = 3

        # yield from rc.mem_write(0x8000000000000000, bytearray(range(256))*32, 100)
        # yield delay(100)
        # assert ep.read_region(1, 0, 256*32) == bytearray(range(256))*32

        # val = yield from rc.mem_read(0x8000000000000000, 256*32, 100)
        # assert val == bytearray(range(256))*32

        # yield delay(100)

        yield clk.posedge
        print("test 4: DMA")
        current_test.next = 4

        #yield ep.io_write(io_base, bytearray(range(16)), 100)

        data = bytearray(range(16))
        addr = io_base
        n = 0

        while n < len(data):
            tlp = pcie_us.TLP_us()
            tlp.fmt_type = pcie.TLP_IO_WRITE
            tlp.requester_id = pcie_us.PcieId(dev.bus_num, dev.device_num, 0)
            tlp.tag = current_tag

            first_pad = addr % 4
            byte_length = min(len(data)-n, 4-first_pad)
            tlp.set_be_data(addr, data[n:n+byte_length])

            tlp.address = addr & ~3

            current_tag = (current_tag % 31) + 1

            rq_source.send(tlp.pack_us_rq())
            yield rc_sink.wait(100)
            pkt = rc_sink.recv()

            if not pkt:
                raise Exception("Timeout")

            cpl = pcie_us.TLP_us().unpack_us_rc(pkt)

            if cpl.status != pcie.CPL_STATUS_SC:
                raise Exception("Unsuccessful completion")

            n += byte_length
            addr += byte_length

        assert io_data[0:16] == bytearray(range(16))

        #val = yield from ep.io_read(io_base, 16, 100)

        length = 16
        data = b''
        addr = io_base
        n = 0

        while n < length:
            tlp = pcie_us.TLP_us()
            tlp.fmt_type = pcie.TLP_IO_READ
            tlp.requester_id = pcie_us.PcieId(dev.bus_num, dev.device_num, 0)
            tlp.tag = current_tag

            first_pad = addr % 4
            byte_length = min(length-n, 4-first_pad)
            tlp.set_be(addr, byte_length)

            tlp.address = addr & ~3

            current_tag = (current_tag % 31) + 1

            rq_source.send(tlp.pack_us_rq())
            yield rc_sink.wait(100)
            pkt = rc_sink.recv()

            if not pkt:
                raise Exception("Timeout")

            cpl = pcie_us.TLP_us().unpack_us_rc(pkt)

            if cpl.status != pcie.CPL_STATUS_SC:
                raise Exception("Unsuccessful completion")
            else:
                d = struct.pack('<L', cpl.data[0])

            data += d[first_pad:]

            n += byte_length
            addr += byte_length

        data = data[:length]

        assert val == bytearray(range(16))

        #yield ep.mem_write(mem_base, bytearray(range(16)), 100)

        data = bytearray(range(16))
        addr = io_base
        n = 0

        while n < len(data):
            tlp = pcie_us.TLP_us()
            if addr > 0xffffffff:
                tlp.fmt_type = pcie.TLP_MEM_WRITE_64
            else:
                tlp.fmt_type = pcie.TLP_MEM_WRITE
            tlp.requester_id = pcie_us.PcieId(dev.bus_num, dev.device_num, 0)
            tlp.tag = current_tag

            first_pad = addr % 4
            byte_length = len(data)-n
            byte_length = min(byte_length, (128 << dev.functions[0].max_payload_size)-first_pad) # max payload size
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff)) # 4k align
            tlp.set_be_data(addr, data[n:n+byte_length])
            
            tlp.address = addr & ~3

            current_tag = (current_tag % 31) + 1

            rq_source.send(tlp.pack_us_rq())

            n += byte_length
            addr += byte_length

        yield delay(100)
        assert mem_data[0:16] == bytearray(range(16))

        #val = yield from ep.mem_read(mem_base, 16, 100)

        length = 16
        data = b''
        addr = mem_base
        n = 0

        while n < length:
            tlp = pcie_us.TLP_us()
            if addr > 0xffffffff:
                tlp.fmt_type = pcie.TLP_MEM_READ_64
            else:
                tlp.fmt_type = pcie.TLP_MEM_READ
            tlp.requester_id = pcie_us.PcieId(dev.bus_num, dev.device_num, 0)
            tlp.tag = current_tag

            first_pad = addr % 4
            byte_length = length-n
            byte_length = min(byte_length, (128 << dev.functions[0].max_read_request_size)-first_pad) # max read request size
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff)) # 4k align
            tlp.set_be(addr, byte_length)

            tlp.address = addr & ~3

            current_tag = (current_tag % 31) + 1

            rq_source.send(tlp.pack_us_rq())

            m = 0

            while m < byte_length:
                yield rc_sink.wait(100)
                pkt = rc_sink.recv()

                if not pkt:
                    raise Exception("Timeout")

                cpl = pcie_us.TLP_us().unpack_us_rc(pkt)

                if cpl.status != pcie.CPL_STATUS_SC:
                    raise Exception("Unsuccessful completion")
                else:
                    dw_len = cpl.length
                    if dw_len == 0:
                        dw_len = 1024
                    d = bytearray()

                    for k in range(dw_len):
                        d.extend(struct.pack('<L', cpl.data[k]))

                    offset = cpl.lower_address&3
                    data += d[offset:offset+cpl.byte_count]

                m += len(d)-offset

            n += byte_length
            addr += byte_length

        assert val == bytearray(range(16))

        yield delay(100)

        yield clk.posedge
        print("test 5: MSI")
        current_test.next = 5

        yield user_clk.posedge
        cfg_interrupt_msi_int.next = 1 << 4
        yield user_clk.posedge
        cfg_interrupt_msi_int.next = 0

        yield rc.msi_get_signal(dev.functions[0].get_id(), 4)

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()

