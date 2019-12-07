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

import math
import struct
from myhdl import *

import axis_ep
from pcie_us import *


class UltrascalePlusPCIeFunction(Endpoint, MSICapability, MSIXCapability):
    def __init__(self):
        super(UltrascalePlusPCIeFunction, self).__init__()

        self.msi_64bit_address_capable = 1
        self.msi_per_vector_mask_capable = 0

        self.register_capability(PM_CAP_ID, offset=0x10)
        self.register_capability(MSI_CAP_ID, offset=0x12)
        self.register_capability(MSIX_CAP_ID, offset=0x18)
        self.register_capability(PCIE_CAP_ID, offset=0x1c)


class UltrascalePlusPCIe(Device):
    def __init__(self):
        super(UltrascalePlusPCIe, self).__init__()

        self.has_logic = False

        self.default_function = UltrascalePlusPCIeFunction

        self.dw = 256

        # configuration options
        self.pcie_generation = 3
        self.pcie_link_width = 8
        self.user_clk_frequency = 250e6
        self.alignment = "dword"
        self.cq_cc_straddle = False
        self.rq_rc_straddle = False
        self.rc_4tlp_straddle = False
        self.enable_pf1 = False
        self.enable_client_tag = True
        self.enable_extended_tag = False
        self.enable_parity = False
        self.enable_rx_msg_interface = False
        self.enable_sriov = False
        self.enable_extended_configuration = False

        self.enable_pf0_msi = False
        self.enable_pf1_msi = False

        self.cq_queue = []
        self.cq_np_queue = []
        self.cq_np_req_count = 0
        self.rc_queue = []
        self.msg_queue = []

        self.config_space_enable = False

        self.cq_source = CQSource()
        self.cc_sink = CCSink()
        self.rq_sink = RQSink()
        self.rc_source = RCSource()

        self.rq_seq_num = []

        self.make_function()


    def upstream_recv(self, tlp):
        # logging
        print("[%s] Got downstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        if tlp.fmt_type == TLP_CFG_READ_0 or tlp.fmt_type == TLP_CFG_WRITE_0:
            # config type 0

            if not self.config_space_enable:
                print("Configuraion space disabled")

                cpl = TLP()
                cpl.set_crs_completion(tlp, (self.bus_num, self.device_num, 0))
                # logging
                print("[%s] CRS Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
                yield from self.upstream_send(cpl)
                return
            elif tlp.dest_id.device == self.device_num:
                # capture address information
                self.bus_num = tlp.dest_id.bus

                for f in self.functions:
                    f.bus_num = self.bus_num

                # pass TLP to function
                for f in self.functions:
                    if f.function_num == tlp.dest_id.function:
                        yield from f.upstream_recv(tlp)
                        return

                #raise Exception("Function not found")
                print("Function not found")
            else:
                print("Device number mismatch")
            
            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, (self.bus_num, self.device_num, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.upstream_send(cpl)
        elif (tlp.fmt_type == TLP_CPL or tlp.fmt_type == TLP_CPL_DATA or
                tlp.fmt_type == TLP_CPL_LOCKED or tlp.fmt_type == TLP_CPL_LOCKED_DATA):
            # Completion

            if tlp.requester_id.bus == self.bus_num and tlp.requester_id.device == self.device_num:
                for f in self.functions:
                    if f.function_num == tlp.requester_id.function:

                        tlp = TLP_us(tlp)

                        tlp.error_code = RC_ERROR_NORMAL_TERMINATION

                        if tlp.status != CPL_STATUS_SC:
                            tlp.error = RC_ERROR_BAD_STATUS

                        self.rc_queue.append(tlp)

                        return

                print("Function not found")
            else:
                print("Bus/device number mismatch")
        elif (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE):
            # IO read/write

            for f in self.functions:
                bar = f.match_bar(tlp.address, True)
                if len(bar) == 1:

                    tlp = TLP_us(tlp)
                    tlp.bar_id = bar[0][0]
                    tlp.bar_aperture = int(math.log2((~self.functions[0].bar_mask[bar[0][0]]&0xffffffff)+1))
                    tlp.completer_id = PcieId(self.bus_num, self.device_num, f.function_num)
                    self.cq_queue.append(tlp)

                    return

            print("IO request did not match any BARs")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, (self.bus_num, self.device_num, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.upstream_send(cpl)
        elif (tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64 or
                tlp.fmt_type == TLP_MEM_WRITE or tlp.fmt_type == TLP_MEM_WRITE_64):
            # Memory read/write

            for f in self.functions:
                bar = f.match_bar(tlp.address)
                if len(bar) == 1:

                    tlp = TLP_us(tlp)
                    tlp.bar_id = bar[0][0]
                    if self.functions[0].bar[bar[0][0]] & 4:
                        tlp.bar_aperture = int(math.log2((~(self.functions[0].bar_mask[bar[0][0]] | (self.functions[0].bar_mask[bar[0][0]+1]<<32))&0xffffffffffffffff)+1))
                    else:
                        tlp.bar_aperture = int(math.log2((~self.functions[0].bar_mask[bar[0][0]]&0xffffffff)+1))
                    tlp.completer_id = PcieId(self.bus_num, self.device_num, f.function_num)
                    self.cq_queue.append(tlp)

                    return

            print("Memory request did not match any BARs")

            if tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64:
                # Unsupported request
                cpl = TLP()
                cpl.set_ur_completion(tlp, PcieId(self.bus_num, self.device_num, 0))
                # logging
                print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
                yield from self.upstream_send(cpl)
        else:
            raise Exception("TODO")

    def create_logic(self,
                # Completer reQuest Interface
                m_axis_cq_tdata=None,
                m_axis_cq_tuser=None,
                m_axis_cq_tlast=None,
                m_axis_cq_tkeep=None,
                m_axis_cq_tvalid=None,
                m_axis_cq_tready=None,
                pcie_cq_np_req=Signal(intbv(1)[2:]),
                pcie_cq_np_req_count=Signal(intbv(0)[6:]),

                # Completer Completion Interface
                s_axis_cc_tdata=None,
                s_axis_cc_tuser=None,
                s_axis_cc_tlast=None,
                s_axis_cc_tkeep=None,
                s_axis_cc_tvalid=None,
                s_axis_cc_tready=None,

                # Requester reQuest Interface
                s_axis_rq_tdata=None,
                s_axis_rq_tuser=None,
                s_axis_rq_tlast=None,
                s_axis_rq_tkeep=None,
                s_axis_rq_tvalid=None,
                s_axis_rq_tready=None,
                pcie_rq_seq_num0=Signal(intbv(0)[6:]),
                pcie_rq_seq_num_vld0=Signal(bool(0)),
                pcie_rq_seq_num1=Signal(intbv(0)[6:]),
                pcie_rq_seq_num_vld1=Signal(bool(0)),
                pcie_rq_tag0=Signal(intbv(0)[8:]),
                pcie_rq_tag1=Signal(intbv(0)[8:]),
                pcie_rq_tag_av=Signal(intbv(0)[4:]),
                pcie_rq_tag_vld0=Signal(bool(0)),
                pcie_rq_tag_vld1=Signal(bool(0)),

                # Requester Completion Interface
                m_axis_rc_tdata=None,
                m_axis_rc_tuser=None,
                m_axis_rc_tlast=None,
                m_axis_rc_tkeep=None,
                m_axis_rc_tvalid=None,
                m_axis_rc_tready=None,

                # Transmit Flow Control Interface
                pcie_tfc_nph_av=Signal(intbv(0)[4:]),
                pcie_tfc_npd_av=Signal(intbv(0)[4:]),

                # Configuration Management Interface
                cfg_mgmt_addr=Signal(intbv(0)[10:]),
                cfg_mgmt_function_number=Signal(intbv(0)[8:]),
                cfg_mgmt_write=Signal(bool(0)),
                cfg_mgmt_write_data=Signal(intbv(0)[32:]),
                cfg_mgmt_byte_enable=Signal(intbv(0)[4:]),
                cfg_mgmt_read=Signal(bool(0)),
                cfg_mgmt_read_data=Signal(intbv(0)[32:]),
                cfg_mgmt_read_write_done=Signal(bool(0)),
                cfg_mgmt_debug_access=Signal(bool(0)),

                # Configuration Status Interface
                cfg_phy_link_down=Signal(bool(0)),
                cfg_phy_link_status=Signal(intbv(0)[2:]),
                cfg_negotiated_width=Signal(intbv(0)[3:]),
                cfg_current_speed=Signal(intbv(0)[2:]),
                cfg_max_payload=Signal(intbv(0)[2:]),
                cfg_max_read_req=Signal(intbv(0)[3:]),
                cfg_function_status=Signal(intbv(0)[16:]),
                cfg_vf_status=Signal(intbv(0)[504:]),
                cfg_function_power_state=Signal(intbv(0)[12:]),
                cfg_vf_power_state=Signal(intbv(0)[756:]),
                cfg_link_power_state=Signal(intbv(0)[2:]),
                cfg_err_cor_out=Signal(bool(0)),
                cfg_err_nonfatal_out=Signal(bool(0)),
                cfg_err_fatal_out=Signal(bool(0)),
                cfg_local_err_out=Signal(intbv(0)[5:]),
                cfg_local_err_valid=Signal(bool(0)),
                cfg_rx_pm_state=Signal(intbv(0)[2:]),
                cfg_tx_pm_state=Signal(intbv(0)[2:]),
                cfg_ltssm_state=Signal(intbv(0)[6:]),
                cfg_rcb_status=Signal(intbv(0)[4:]),
                cfg_obff_enable=Signal(intbv(0)[2:]),
                cfg_pl_status_change=Signal(bool(0)),
                cfg_tph_requester_enable=Signal(intbv(0)[4:]),
                cfg_tph_st_mode=Signal(intbv(0)[12:]),
                cfg_vf_tph_requester_enable=Signal(intbv(0)[252:]),
                cfg_vf_tph_st_mode=Signal(intbv(0)[756:]),

                # Configuration Received Message Interface
                cfg_msg_received=Signal(bool(0)),
                cfg_msg_received_data=Signal(intbv(0)[8:]),
                cfg_msg_received_type=Signal(intbv(0)[5:]),

                # Configuration Transmit Message Interface
                cfg_msg_transmit=Signal(bool(0)),
                cfg_msg_transmit_type=Signal(intbv(0)[3:]),
                cfg_msg_transmit_data=Signal(intbv(0)[32:]),
                cfg_msg_transmit_done=Signal(bool(0)),

                # Configuration Flow Control Interface
                cfg_fc_ph=Signal(intbv(0)[8:]),
                cfg_fc_pd=Signal(intbv(0)[12:]),
                cfg_fc_nph=Signal(intbv(0)[8:]),
                cfg_fc_npd=Signal(intbv(0)[12:]),
                cfg_fc_cplh=Signal(intbv(0)[8:]),
                cfg_fc_cpld=Signal(intbv(0)[12:]),
                cfg_fc_sel=Signal(intbv(0)[3:]),

                # Configuration Control Interface
                cfg_hot_reset_in=Signal(bool(0)),
                cfg_hot_reset_out=Signal(bool(0)),
                cfg_config_space_enable=Signal(bool(1)),
                cfg_dsn=Signal(intbv(0)[64:]),
                cfg_ds_port_number=Signal(intbv(0)[8:]),
                cfg_ds_bus_number=Signal(intbv(0)[8:]),
                cfg_ds_device_number=Signal(intbv(0)[5:]),
                cfg_ds_function_number=Signal(intbv(0)[3:]),
                cfg_power_state_change_ack=Signal(bool(0)),
                cfg_power_state_change_interrupt=Signal(bool(0)),
                cfg_err_cor_in=Signal(bool(0)),
                cfg_err_uncor_in=Signal(bool(0)),
                cfg_flr_done=Signal(intbv(0)[4:]),
                cfg_vf_flr_done=Signal(intbv(0)[1:]),
                cfg_flr_in_process=Signal(intbv(0)[4:]),
                cfg_vf_flr_in_process=Signal(intbv(0)[252:]),
                cfg_req_pm_transition_l23_ready=Signal(bool(0)),
                cfg_link_training_enable=Signal(bool(1)),

                # Configuration Interrupt Controller Interface
                cfg_interrupt_int=Signal(intbv(0)[4:]),
                cfg_interrupt_sent=Signal(bool(0)),
                cfg_interrupt_pending=Signal(intbv(0)[2:]),
                cfg_interrupt_msi_enable=Signal(intbv(0)[4:]),
                cfg_interrupt_msi_mmenable=Signal(intbv(0)[12:]),
                cfg_interrupt_msi_mask_update=Signal(bool(0)),
                cfg_interrupt_msi_data=Signal(intbv(0)[32:]),
                cfg_interrupt_msi_select=Signal(intbv(0)[2:]),
                cfg_interrupt_msi_int=Signal(intbv(0)[32:]),
                cfg_interrupt_msi_pending_status=Signal(intbv(0)[32:]),
                cfg_interrupt_msi_pending_status_data_enable=Signal(bool(0)),
                cfg_interrupt_msi_pending_status_function_num=Signal(intbv(0)[2:]),
                cfg_interrupt_msi_sent=Signal(bool(0)),
                cfg_interrupt_msi_fail=Signal(bool(0)),
                cfg_interrupt_msix_enable=Signal(intbv(0)[4:]),
                cfg_interrupt_msix_mask=Signal(intbv(0)[4:]),
                cfg_interrupt_msix_vf_enable=Signal(intbv(0)[252:]),
                cfg_interrupt_msix_vf_mask=Signal(intbv(0)[252:]),
                cfg_interrupt_msix_address=Signal(intbv(0)[64:]),
                cfg_interrupt_msix_data=Signal(intbv(0)[32:]),
                cfg_interrupt_msix_int=Signal(bool(0)),
                cfg_interrupt_msix_vec_pending=Signal(intbv(0)[2:]),
                cfg_interrupt_msix_vec_pending_status=Signal(bool(0)),
                cfg_interrupt_msi_attr=Signal(intbv(0)[3:]),
                cfg_interrupt_msi_tph_present=Signal(bool(0)),
                cfg_interrupt_msi_tph_type=Signal(intbv(0)[2:]),
                cfg_interrupt_msi_tph_st_tag=Signal(intbv(0)[8:]),
                cfg_interrupt_msi_function_number=Signal(intbv(0)[8:]),

                # Configuration Extend Interface
                cfg_ext_read_received=Signal(bool(0)),
                cfg_ext_write_received=Signal(bool(0)),
                cfg_ext_register_number=Signal(intbv(0)[10:]),
                cfg_ext_function_number=Signal(intbv(0)[8:]),
                cfg_ext_write_data=Signal(intbv(0)[32:]),
                cfg_ext_write_byte_enable=Signal(intbv(0)[4:]),
                cfg_ext_read_data=Signal(intbv(0)[32:]),
                cfg_ext_read_data_valid=Signal(bool(0)),

                # Clock and Reset Interface
                user_clk=Signal(bool(0)),
                user_reset=Signal(bool(0)),
                user_lnk_up=Signal(bool(0)),
                sys_clk=None,
                sys_clk_gt=None,
                sys_reset=None,
                phy_rdy_out=Signal(bool(0)),

                # debugging connections
                cq_pause=Signal(bool(0)),
                cc_pause=Signal(bool(0)),
                rq_pause=Signal(bool(0)),
                rc_pause=Signal(bool(0)),
            ):

        # validate parameters and widths
        self.dw = len(m_axis_cq_tdata)

        assert self.dw in [64, 128, 256, 512]

        if self.user_clk_frequency < 1e6:
            self.user_clk_frequency *= 1e6

        assert self.pcie_generation in [1, 2, 3]
        assert self.pcie_link_width in [1, 2, 4, 8, 16]
        assert self.user_clk_frequency in [62.5e6, 125e6, 250e6]
        assert self.alignment in ["address", "dword"]

        self.upstream_port.max_speed = self.pcie_generation
        self.upstream_port.max_width = self.pcie_link_width

        if self.dw < 256 or self.alignment != "dword":
            # straddle only supported with 256-bit or wider, DWORD-aligned interface
            assert not self.cq_cc_straddle
            assert not self.rq_rc_straddle
            if self.dw != 512:
                assert not self.rc_4tlp_straddle

        # TODO change this when support added
        assert self.alignment == 'dword'
        assert not self.cq_cc_straddle
        assert not self.rq_rc_straddle
        assert not self.rc_4tlp_straddle

        if self.pcie_generation == 1:
            if self.pcie_link_width in [1, 2]:
                assert self.dw == 64
                assert self.user_clk_frequency in [62.5e6, 125e6, 250e6]
            elif self.pcie_link_width == 4:
                assert self.dw == 64
                assert self.user_clk_frequency in [125e6, 250e6]
            elif self.pcie_link_width == 8:
                assert self.dw in [64, 128]
                if self.dw == 64:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 128:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 16:
                assert self.dw == 128
                assert self.user_clk_frequency == 250e6
        elif self.pcie_generation == 2:
            if self.pcie_link_width == 1:
                assert self.dw == 64
                assert self.user_clk_frequency in [62.5e6, 125e6, 250e6]
            elif self.pcie_link_width == 2:
                assert self.dw == 64
                assert self.user_clk_frequency in [125e6, 250e6]
            elif self.pcie_link_width == 4:
                assert self.dw in [64, 128]
                if self.dw == 64:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 128:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 8:
                assert self.dw in [128, 256]
                if self.dw == 128:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 256:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 16:
                assert self.dw == 256
                assert self.user_clk_frequency == 250e6
        elif self.pcie_generation == 3:
            if self.pcie_link_width == 1:
                assert self.dw == 64
                assert self.user_clk_frequency in [125e6, 250e6]
            elif self.pcie_link_width == 2:
                assert self.dw in [64, 128]
                if self.dw == 64:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 128:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 4:
                assert self.dw in [128, 256]
                if self.dw == 128:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 256:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 8:
                assert self.dw == 256
                assert self.user_clk_frequency == 250e6
            elif self.pcie_link_width == 16:
                assert self.dw == 512
                assert self.user_clk_frequency == 250e6

        # Completer reQuest Interface
        assert len(m_axis_cq_tdata) == self.dw
        if len(m_axis_cq_tdata) == 512:
            assert len(m_axis_cq_tuser) == 183
        else:
            assert len(m_axis_cq_tuser) == 88
        assert len(m_axis_cq_tlast) == 1
        assert len(m_axis_cq_tkeep) == self.dw/32
        assert len(m_axis_cq_tvalid) == 1
        assert len(m_axis_cq_tready) == 1
        assert len(pcie_cq_np_req) == 2
        assert len(pcie_cq_np_req_count) == 6

        # Completer Completion Interface
        assert len(s_axis_cc_tdata) == self.dw
        if len(m_axis_cq_tdata) == 512:
            assert len(s_axis_cc_tuser) == 81
        else:
            assert len(s_axis_cc_tuser) == 33
        assert len(s_axis_cc_tlast) == 1
        assert len(s_axis_cc_tkeep) == self.dw/32
        assert len(s_axis_cc_tvalid) == 1
        assert len(s_axis_cc_tready) == 1

        # Requester reQuest Interface
        assert len(s_axis_rq_tdata) == self.dw
        if len(m_axis_cq_tdata) == 512:
            assert len(s_axis_rq_tuser) == 137
        else:
            assert len(s_axis_rq_tuser) == 62
        assert len(s_axis_rq_tlast) == 1
        assert len(s_axis_rq_tkeep) == self.dw/32
        assert len(s_axis_rq_tvalid) == 1
        assert len(s_axis_rq_tready) == 1
        assert len(pcie_rq_seq_num0) == 6
        assert len(pcie_rq_seq_num_vld0) == 1
        assert len(pcie_rq_seq_num1) == 6
        assert len(pcie_rq_seq_num_vld1) == 1
        assert len(pcie_rq_tag0) >= 8
        assert len(pcie_rq_tag1) >= 8
        assert len(pcie_rq_tag_av) == 4
        assert len(pcie_rq_tag_vld0) == 1
        assert len(pcie_rq_tag_vld1) == 1

        # Requester Completion Interface
        assert len(m_axis_rc_tdata) == self.dw
        if len(m_axis_cq_tdata) == 512:
            assert len(m_axis_rc_tuser) == 161
        else:
            assert len(m_axis_rc_tuser) == 75
        assert len(m_axis_rc_tlast) == 1
        assert len(m_axis_rc_tkeep) == self.dw/32
        assert len(m_axis_rc_tvalid) == 1
        assert len(m_axis_rc_tready) == 1

        # Transmit Flow Control Interface
        assert len(pcie_tfc_nph_av) == 4
        assert len(pcie_tfc_npd_av) == 4

        # Configuration Management Interface
        assert len(cfg_mgmt_addr) == 10
        assert len(cfg_mgmt_function_number) == 8
        assert len(cfg_mgmt_write) == 1
        assert len(cfg_mgmt_write_data) == 32
        assert len(cfg_mgmt_byte_enable) == 4
        assert len(cfg_mgmt_read) == 1
        assert len(cfg_mgmt_read_data) == 32
        assert len(cfg_mgmt_read_write_done) == 1
        assert len(cfg_mgmt_debug_access) == 1

        # Configuration Status Interface
        assert len(cfg_phy_link_down) == 1
        assert len(cfg_phy_link_status) == 2
        assert len(cfg_negotiated_width) == 3
        assert len(cfg_current_speed) == 2
        assert len(cfg_max_payload) == 2
        assert len(cfg_max_read_req) == 3
        assert len(cfg_function_status) == 16
        assert len(cfg_vf_status) == 504
        assert len(cfg_function_power_state) == 12
        assert len(cfg_vf_power_state) == 756
        assert len(cfg_link_power_state) == 2
        assert len(cfg_err_cor_out) == 1
        assert len(cfg_err_nonfatal_out) == 1
        assert len(cfg_err_fatal_out) == 1
        assert len(cfg_local_err_out) == 5
        assert len(cfg_local_err_valid) == 1
        assert len(cfg_rx_pm_state) == 2
        assert len(cfg_tx_pm_state) == 2
        assert len(cfg_ltssm_state) == 6
        assert len(cfg_rcb_status) == 4
        assert len(cfg_obff_enable) == 2
        assert len(cfg_pl_status_change) == 1
        assert len(cfg_tph_requester_enable) == 4
        assert len(cfg_tph_st_mode) == 12
        assert len(cfg_vf_tph_requester_enable) == 252
        assert len(cfg_vf_tph_st_mode) == 756

        # Configuration Received Message Interface
        assert len(cfg_msg_received) == 1
        assert len(cfg_msg_received_data) == 8
        assert len(cfg_msg_received_type) == 5

        # Configuration Transmit Message Interface
        assert len(cfg_msg_transmit) == 1
        assert len(cfg_msg_transmit_type) == 3
        assert len(cfg_msg_transmit_data) == 32
        assert len(cfg_msg_transmit_done) == 1

        # Configuration Flow Control Interface
        assert len(cfg_fc_ph) == 8
        assert len(cfg_fc_pd) == 12
        assert len(cfg_fc_nph) == 8
        assert len(cfg_fc_npd) == 12
        assert len(cfg_fc_cplh) == 8
        assert len(cfg_fc_cpld) == 12
        assert len(cfg_fc_sel) == 3

        # Configuration Control Interface
        assert len(cfg_hot_reset_in) == 1
        assert len(cfg_hot_reset_out) == 1
        assert len(cfg_config_space_enable) == 1
        assert len(cfg_dsn) == 64
        assert len(cfg_ds_port_number) == 8
        assert len(cfg_ds_bus_number) == 8
        assert len(cfg_ds_device_number) == 5
        assert len(cfg_ds_function_number) == 3
        assert len(cfg_power_state_change_ack) == 1
        assert len(cfg_power_state_change_interrupt) == 1
        assert len(cfg_err_cor_in) == 1
        assert len(cfg_err_uncor_in) == 1
        assert len(cfg_flr_done) == 4
        assert len(cfg_vf_flr_done) == 1
        assert len(cfg_flr_in_process) == 4
        assert len(cfg_vf_flr_in_process) == 252
        assert len(cfg_req_pm_transition_l23_ready) == 1
        assert len(cfg_link_training_enable) == 1

        # Configuration Interrupt Controller Interface
        assert len(cfg_interrupt_int) == 4
        assert len(cfg_interrupt_sent) == 1
        assert len(cfg_interrupt_pending) == 2
        assert len(cfg_interrupt_msi_enable) == 4
        assert len(cfg_interrupt_msi_mmenable) == 12
        assert len(cfg_interrupt_msi_mask_update) == 1
        assert len(cfg_interrupt_msi_data) == 32
        assert len(cfg_interrupt_msi_select) == 2
        assert len(cfg_interrupt_msi_int) == 32
        assert len(cfg_interrupt_msi_pending_status) == 32
        assert len(cfg_interrupt_msi_pending_status_data_enable) == 1
        assert len(cfg_interrupt_msi_pending_status_function_num) == 2
        assert len(cfg_interrupt_msi_sent) == 1
        assert len(cfg_interrupt_msi_fail) == 1
        assert len(cfg_interrupt_msix_enable) == 4
        assert len(cfg_interrupt_msix_mask) == 4
        assert len(cfg_interrupt_msix_vf_enable) == 252
        assert len(cfg_interrupt_msix_vf_mask) == 252
        assert len(cfg_interrupt_msix_address) == 64
        assert len(cfg_interrupt_msix_data) == 32
        assert len(cfg_interrupt_msix_vec_pending) == 2
        assert len(cfg_interrupt_msix_vec_pending_status) == 1
        assert len(cfg_interrupt_msix_int) == 1
        assert len(cfg_interrupt_msi_attr) == 3
        assert len(cfg_interrupt_msi_tph_present) == 1
        assert len(cfg_interrupt_msi_tph_type) == 2
        assert len(cfg_interrupt_msi_tph_st_tag) == 8
        assert len(cfg_interrupt_msi_function_number) == 8

        # Configuration Extend Interface
        assert len(cfg_ext_read_received) == 1
        assert len(cfg_ext_write_received) == 1
        assert len(cfg_ext_register_number) == 10
        assert len(cfg_ext_function_number) == 8
        assert len(cfg_ext_write_data) == 32
        assert len(cfg_ext_write_byte_enable) == 4
        assert len(cfg_ext_read_data) == 32
        assert len(cfg_ext_read_data_valid) == 1

        # Clock and Reset Interface
        assert len(user_clk) == 1
        assert len(user_reset) == 1
        assert len(user_lnk_up) == 1
        assert len(sys_clk) == 1
        assert len(sys_clk_gt) == 1
        assert len(sys_reset) == 1
        assert len(phy_rdy_out) == 1

        assert not self.has_logic

        self.has_logic = True

        # sources and sinks
        cq_source_logic = self.cq_source.create_logic(
            user_clk,
            user_reset,
            tdata=m_axis_cq_tdata,
            tuser=m_axis_cq_tuser,
            tlast=m_axis_cq_tlast,
            tkeep=m_axis_cq_tkeep,
            tvalid=m_axis_cq_tvalid,
            tready=m_axis_cq_tready,
            name='cq_source',
            pause=cq_pause
        )

        cc_sink_logic = self.cc_sink.create_logic(
            user_clk,
            user_reset,
            tdata=s_axis_cc_tdata,
            tuser=s_axis_cc_tuser,
            tlast=s_axis_cc_tlast,
            tkeep=s_axis_cc_tkeep,
            tvalid=s_axis_cc_tvalid,
            tready=s_axis_cc_tready,
            name='cc_sink',
            pause=cc_pause
        )

        rq_sink_logic = self.rq_sink.create_logic(
            user_clk,
            user_reset,
            tdata=s_axis_rq_tdata,
            tuser=s_axis_rq_tuser,
            tlast=s_axis_rq_tlast,
            tkeep=s_axis_rq_tkeep,
            tvalid=s_axis_rq_tvalid,
            tready=s_axis_rq_tready,
            name='rq_sink',
            pause=rq_pause
        )

        rc_source_logic = self.rc_source.create_logic(
            user_clk,
            user_reset,
            tdata=m_axis_rc_tdata,
            tuser=m_axis_rc_tuser,
            tlast=m_axis_rc_tlast,
            tkeep=m_axis_rc_tkeep,
            tvalid=m_axis_rc_tvalid,
            tready=m_axis_rc_tready,
            name='rc_source',
            pause=rc_pause
        )

        if self.user_clk_frequency == 62.5e6:
            user_clk_period = 8
        elif self.user_clk_frequency == 125e6:
            user_clk_period = 4
        else:
            user_clk_period = 2

        @always(delay(user_clk_period))
        def clkgen():
            user_clk.next = not user_clk

        @instance
        def reset_logic():
            while True:
                yield user_clk.posedge, sys_reset.negedge

                if not sys_reset:
                    user_reset.next = 1
                    yield sys_reset.posedge
                    yield delay(20)
                    yield user_clk.posedge
                    user_reset.next = 0

        @instance
        def logic():

            while True:
                yield user_clk.posedge, sys_reset.negedge

                if not sys_reset:
                    self.cq_np_req_count = 0
                elif pcie_cq_np_req:
                    if self.cq_np_req_count < 32:
                        self.cq_np_req_count += 1

                # handle completer requests
                # send any queued non-posted requests first
                while self.cq_np_queue and self.cq_np_req_count > 0:
                    tlp = self.cq_np_queue.pop(0)
                    self.cq_np_req_count -= 1
                    self.cq_source.send(tlp.pack_us_cq())

                # handle new requests
                while self.cq_queue:
                    tlp = self.cq_queue.pop(0)

                    if (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE or
                            tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64):
                        # non-posted request
                        if self.cq_np_req_count > 0:
                            # have credit, can forward
                            self.cq_np_req_count -= 1
                            self.cq_source.send(tlp.pack_us_cq())
                        else:
                            # no credits, put it in the queue
                            self.cq_np_queue.append(tlp)
                    else:
                        # posted request
                        self.cq_source.send(tlp.pack_us_cq())

                pcie_cq_np_req_count.next = self.cq_np_req_count

                # handle completer completions
                while not self.cc_sink.empty():
                    pkt = self.cc_sink.recv()

                    tlp = TLP_us().unpack_us_cc(pkt, self.enable_parity)

                    if not tlp.completer_id_enable:
                        tlp.completer_id = PcieId(self.bus_num, self.device_num, tlp.completer_id.function)

                    if not tlp.discontinue:
                        yield from self.send(TLP(tlp))

                # handle requester requests
                while not self.rq_sink.empty():
                    pkt = self.rq_sink.recv()

                    tlp = TLP_us().unpack_us_rq(pkt, self.enable_parity)

                    if not tlp.requester_id_enable:
                        tlp.requester_id = PcieId(self.bus_num, self.device_num, tlp.requester_id.function)

                    if not tlp.discontinue:
                        if self.functions[tlp.requester_id.function].bus_master_enable:
                            self.rq_seq_num.append(tlp.seq_num)
                            yield from self.send(TLP(tlp))
                        else:
                            print("Bus mastering disabled")

                            # TODO: internal response

                # transmit sequence number
                pcie_rq_seq_num_vld0.next = 0
                if self.rq_seq_num:
                    pcie_rq_seq_num0.next = self.rq_seq_num.pop(0)
                    pcie_rq_seq_num_vld0.next = 1

                pcie_rq_seq_num_vld1.next = 0
                if self.rq_seq_num:
                    pcie_rq_seq_num1.next = self.rq_seq_num.pop(0)
                    pcie_rq_seq_num_vld1.next = 1

                # TODO pcie_rq_tag

                # handle requester completions
                while self.rc_queue:
                    tlp = self.rc_queue.pop(0)
                    self.rc_source.send(tlp.pack_us_rc())

                # transmit flow control
                # TODO
                pcie_tfc_nph_av.next = 0xf
                pcie_tfc_npd_av.next = 0xf

                # configuration management
                # TODO four cycle delay
                function = cfg_mgmt_function_number
                reg_num = cfg_mgmt_addr
                if cfg_mgmt_read_write_done:
                    cfg_mgmt_read_write_done.next = 0
                elif cfg_mgmt_read:
                    cfg_mgmt_read_data.next = self.functions[function].read_config_register(reg_num)
                    cfg_mgmt_read_write_done.next = 1
                elif cfg_mgmt_write:
                    self.functions[function].write_config_register(reg_num, cfg_mgmt_write_data, cfg_mgmt_byte_enable)
                    cfg_mgmt_read_write_done.next = 1
                #cfg_mgmt_debug_access

                # configuration status
                if not sys_reset:
                    cfg_phy_link_down.next = 1
                    user_lnk_up.next = 0
                else:
                    cfg_phy_link_down.next = 0 # TODO
                    user_lnk_up.next = 1 # TODO

                #cfg_phy_link_status
                cfg_negotiated_width.next = min(max((self.functions[0].negotiated_link_width).bit_length()-1, 0), 4)
                cfg_current_speed.next = min(max(self.functions[0].current_link_speed-1, 0), 3)
                cfg_max_payload.next = self.functions[0].max_payload_size & 3
                cfg_max_read_req.next = self.functions[0].max_read_request_size

                status = 0
                for k in range(len(self.functions)):
                    if self.functions[k].bus_master_enable:
                        status |= 0x07 << k*4
                    if self.functions[k].interrupt_disable:
                        status |= 0x08 << k*4
                cfg_function_status.next = status

                #cfg_vf_status
                #cfg_function_power_state
                #cfg_vf_power_state
                #cfg_link_power_state
                #cfg_err_cor_out
                #cfg_err_nonfatal_out
                #cfg_err_fatal_out
                #cfg_local_err_out
                #cfg_local_err_valid
                #cfg_rx_pm_state
                #cfg_tx_pm_state
                #cfg_ltssm_state

                status = 0
                for k in range(len(self.functions)):
                    if self.functions[k].read_completion_boundary:
                        status |= 1 << k
                cfg_rcb_status.next = status

                #cfg_obff_enable
                #cfg_pl_status_change
                #cfg_tph_requester_enable
                #cfg_tph_st_mode
                #cfg_vf_tph_requester_enable
                #cfg_vf_tph_st_mode

                # configuration received message
                #cfg_msg_received
                #cfg_msg_received_data
                #cfg_msg_received_type

                # configuration transmit message
                #cfg_msg_transmit
                #cfg_msg_transmit_type
                #cfg_msg_transmit_data
                #cfg_msg_transmit_done

                # configuration flow control
                if (cfg_fc_sel == 0b010):
                    # Receive credits consumed
                    # TODO
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0
                elif (cfg_fc_sel == 0b100):
                    # Transmit credits available
                    # TODO
                    cfg_fc_ph.next = 0x80
                    cfg_fc_pd.next = 0x800
                    cfg_fc_nph.next = 0x80
                    cfg_fc_npd.next = 0x800
                    cfg_fc_cplh.next = 0x80
                    cfg_fc_cpld.next = 0x800
                elif (cfg_fc_sel == 0b101):
                    # Transmit credit limit
                    # TODO
                    cfg_fc_ph.next = 0x80
                    cfg_fc_pd.next = 0x800
                    cfg_fc_nph.next = 0x80
                    cfg_fc_npd.next = 0x800
                    cfg_fc_cplh.next = 0x80
                    cfg_fc_cpld.next = 0x800
                elif (cfg_fc_sel == 0b110):
                    # Transmit credits consumed
                    # TODO
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0
                else:
                    # Reserved
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0

                # configuration control
                #cfg_hot_reset_in
                #cfg_hot_reset_out

                if not sys_reset:
                    self.config_space_enable = False
                else:
                    self.config_space_enable = bool(cfg_config_space_enable)

                #cfg_dsn
                #cfg_ds_port_number
                #cfg_ds_bus_number
                #cfg_ds_device_number
                #cfg_ds_function_number
                #cfg_power_state_change_ack
                #cfg_power_state_change_interrupt
                #cfg_err_cor_in
                #cfg_err_uncor_in
                #cfg_flr_done
                #cfg_vf_flr_done
                #cfg_flr_in_process
                #cfg_vf_flr_in_process
                #cfg_req_pm_transition_l23_ready
                #cfg_link_training_enable

                # configuration interrupt controller
                # INTx
                #cfg_interrupt_int
                #cfg_interrupt_sent
                #cfg_interrupt_pending

                # MSI
                val = 0
                if self.functions[0].msi_enable:
                    val |= 1
                if len(self.functions) > 1:
                    if self.functions[1].msi_enable:
                        val |= 2
                cfg_interrupt_msi_enable.next = val

                cfg_interrupt_msi_sent.next = 0
                cfg_interrupt_msi_fail.next = 0
                if (cfg_interrupt_msi_int):
                    n = int(cfg_interrupt_msi_int)
                    #bits = [i for i in range(n.bit_length()) if n >> i & 1]
                    bits = [i for i in range(32) if n >> i & 1]
                    if len(bits) == 1 and cfg_interrupt_msi_function_number < len(self.functions):
                        yield self.functions[cfg_interrupt_msi_function_number].issue_msi_interrupt(bits[0], attr=int(cfg_interrupt_msi_attr))
                        cfg_interrupt_msi_sent.next = 1

                val = 0
                val |= self.functions[0].msi_multiple_message_enable & 0x7
                if len(self.functions) > 1:
                    val |= (self.functions[1].msi_multiple_message_enable & 0x7) << 3
                cfg_interrupt_msi_mmenable.next = val

                #cfg_interrupt_msi_mask_update

                if cfg_interrupt_msi_select == 0b1111:
                    cfg_interrupt_msi_data.next = 0
                else:
                    if cfg_interrupt_msi_select < len(self.functions):
                        cfg_interrupt_msi_data.next = self.functions[cfg_interrupt_msi_select].msi_mask_bits;
                    else:
                        cfg_interrupt_msi_data.next = 0
                if cfg_interrupt_msi_pending_status_data_enable:
                    if cfg_interrupt_msi_pending_status_function_num < len(self.functions):
                        self.functions[cfg_interrupt_msi_pending_status_function_num].msi_pending_bits = int(cfg_interrupt_msi_pending_status)

                # MSI-X
                val = 0
                if self.functions[0].msix_enable:
                    val |= 1
                if len(self.functions) > 1:
                    if self.functions[1].msix_enable:
                        val |= 2
                cfg_interrupt_msix_enable.next = val
                val = 0
                if self.functions[0].msix_function_mask:
                    val |= 1
                if len(self.functions) > 1:
                    if self.functions[1].msix_function_mask:
                        val |= 2
                cfg_interrupt_msix_mask.next = val
                #cfg_interrupt_msix_vf_enable
                #cfg_interrupt_msix_vf_mask

                if cfg_interrupt_msix_int:
                    if cfg_interrupt_msi_function_number < len(self.functions):
                        yield self.functions[cfg_interrupt_msi_function_number].issue_msix_interrupt(int(cfg_interrupt_msix_address), int(cfg_interrupt_msix_data), attr=int(cfg_interrupt_msi_attr))
                        cfg_interrupt_msi_sent.next = 1

                # MSI/MSI-X
                #cfg_interrupt_msi_tph_present
                #cfg_interrupt_msi_tph_type
                #cfg_interrupt_msi_tph_st_tag

                # configuration extend
                #cfg_ext_read_received
                #cfg_ext_write_received
                #cfg_ext_register_number
                #cfg_ext_function_number
                #cfg_ext_write_data
                #cfg_ext_write_byte_enable
                #cfg_ext_read_data
                #cfg_ext_read_data_valid

        return instances()

