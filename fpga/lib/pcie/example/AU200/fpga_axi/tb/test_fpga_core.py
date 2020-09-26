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
import os
import struct

import pcie
import pcie_usp

module = 'fpga_core'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/axi_ram.v")
srcs.append("../rtl/axis_register.v")
srcs.append("../lib/pcie/rtl/axis_arb_mux.v")
srcs.append("../lib/pcie/rtl/pcie_us_axil_master.v")
srcs.append("../lib/pcie/rtl/pcie_us_axi_dma.v")
srcs.append("../lib/pcie/rtl/pcie_us_axi_dma_rd.v")
srcs.append("../lib/pcie/rtl/pcie_us_axi_dma_wr.v")
srcs.append("../lib/pcie/rtl/pcie_tag_manager.v")
srcs.append("../lib/pcie/rtl/pcie_us_axi_master.v")
srcs.append("../lib/pcie/rtl/pcie_us_axi_master_rd.v")
srcs.append("../lib/pcie/rtl/pcie_us_axi_master_wr.v")
srcs.append("../lib/pcie/rtl/pcie_us_axis_cq_demux.v")
srcs.append("../lib/pcie/rtl/pcie_us_cfg.v")
srcs.append("../lib/pcie/rtl/pcie_us_msi.v")
srcs.append("../lib/pcie/rtl/arbiter.v")
srcs.append("../lib/pcie/rtl/priority_encoder.v")
srcs.append("../lib/pcie/rtl/pulse_merge.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    AXIS_PCIE_DATA_WIDTH = 512
    AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32)
    AXIS_PCIE_RC_USER_WIDTH = 161
    AXIS_PCIE_RQ_USER_WIDTH = 137
    AXIS_PCIE_CQ_USER_WIDTH = 183
    AXIS_PCIE_CC_USER_WIDTH = 81

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    btnu = Signal(bool(0))
    btnl = Signal(bool(0))
    btnd = Signal(bool(0))
    btnr = Signal(bool(0))
    btnc = Signal(bool(0))
    sw = Signal(intbv(0)[4:])
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
    cfg_max_payload = Signal(intbv(0)[2:])
    cfg_max_read_req = Signal(intbv(0)[3:])
    cfg_mgmt_read_data = Signal(intbv(0)[32:])
    cfg_mgmt_read_write_done = Signal(bool(0))
    cfg_interrupt_msi_enable = Signal(intbv(0)[4:])
    cfg_interrupt_msi_mmenable = Signal(intbv(0)[12:])
    cfg_interrupt_msi_mask_update = Signal(bool(0))
    cfg_interrupt_msi_data = Signal(intbv(0)[32:])
    cfg_interrupt_msi_sent = Signal(bool(0))
    cfg_interrupt_msi_fail = Signal(bool(0))

    # Outputs
    led = Signal(intbv(0)[8:])
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

    # Clock and Reset Interface
    user_clk=Signal(bool(0))
    user_reset=Signal(bool(0))
    sys_clk=Signal(bool(0))
    sys_reset=Signal(bool(0))

    # PCIe devices
    rc = pcie.RootComplex()

    mem_base, mem_data = rc.alloc_region(16*1024*1024)

    dev = pcie_usp.UltrascalePlusPCIe()

    dev.pcie_generation = 3
    dev.pcie_link_width = 16
    dev.user_clock_frequency = 256e6

    dev.functions[0].msi_multiple_message_capable = 5

    dev.functions[0].configure_bar(0, 4*1024*1024)
    dev.functions[0].configure_bar(1, 4*1024*1024)

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
        pcie_cq_np_req=Signal(intbv(1)[2:]),
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
        #pcie_rq_seq_num0=pcie_rq_seq_num0,
        #pcie_rq_seq_num_vld0=pcie_rq_seq_num_vld0,
        #pcie_rq_seq_num1=pcie_rq_seq_num1,
        #pcie_rq_seq_num_vld1=pcie_rq_seq_num_vld1,
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
        #cfg_fc_ph=cfg_fc_ph,
        #cfg_fc_pd=cfg_fc_pd,
        #cfg_fc_nph=cfg_fc_nph,
        #cfg_fc_npd=cfg_fc_npd,
        #cfg_fc_cplh=cfg_fc_cplh,
        #cfg_fc_cpld=cfg_fc_cpld,
        #cfg_fc_sel=cfg_fc_sel,

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
        #user_lnk_up=user_lnk_up,
        sys_clk=sys_clk,
        sys_clk_gt=sys_clk,
        sys_reset=sys_reset,
        #phy_rdy_out=phy_rdy_out
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=user_clk,
        rst=user_reset,
        current_test=current_test,
        btnu=btnu,
        btnl=btnl,
        btnd=btnd,
        btnr=btnr,
        btnc=btnc,
        sw=sw,
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
        status_error_uncor=status_error_uncor
    )

    @always(delay(5))
    def clkgen():
        clk.next = not clk

    @always_comb
    def clk_logic():
        sys_clk.next = clk
        sys_reset.next = not rst

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

        yield rc.enumerate(enable_bus_mastering=True, configure_msi=True)

        dev_pf0_bar0 = dev.functions[0].bar[0] & 0xfffffffc
        dev_pf0_bar1 = dev.functions[0].bar[1] & 0xfffffffc

        yield delay(100)

        yield clk.posedge
        print("test 2: memory write to bar 1")
        current_test.next = 2

        yield rc.mem_write(dev_pf0_bar1, b'\x11\x22\x33\x44')

        yield delay(100)

        yield clk.posedge
        print("test 3: memory read from bar 1")
        current_test.next = 3

        val = yield from rc.mem_read(dev_pf0_bar1, 4, 1000)
        print(val)
        assert val == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 4: test DMA")
        current_test.next = 4

        # write packet data
        mem_data[0:1024] = bytearray([x%256 for x in range(1024)])

        # enable DMA
        yield rc.mem_write(dev_pf0_bar0+0x100000, struct.pack('<L', 1))

        # write pcie read descriptor
        yield rc.mem_write(dev_pf0_bar0+0x100100, struct.pack('<L', (mem_base+0x0000) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x100104, struct.pack('<L', (mem_base+0x0000 >> 32) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x100108, struct.pack('<L', (0x100) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x10010C, struct.pack('<L', (0x100 >> 32) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x100110, struct.pack('<L', 0x400))
        yield rc.mem_write(dev_pf0_bar0+0x100114, struct.pack('<L', 0xAA))

        yield delay(2000)

        # read status
        val = yield from rc.mem_read(dev_pf0_bar0+0x100118, 4)
        print(val)

        # write pcie write descriptor
        yield rc.mem_write(dev_pf0_bar0+0x100200, struct.pack('<L', (mem_base+0x1000) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x100204, struct.pack('<L', (mem_base+0x1000 >> 32) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x100208, struct.pack('<L', (0x100) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x10020C, struct.pack('<L', (0x100 >> 32) & 0xffffffff))
        yield rc.mem_write(dev_pf0_bar0+0x100210, struct.pack('<L', 0x400))
        yield rc.mem_write(dev_pf0_bar0+0x100214, struct.pack('<L', 0x55))

        yield delay(2000)

        # read status
        val = yield from rc.mem_read(dev_pf0_bar0+0x100218, 4)
        print(val)

        data = mem_data[0x1000:(0x1000)+64]
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert mem_data[0:1024] == mem_data[0x1000:0x1000+1024]

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
