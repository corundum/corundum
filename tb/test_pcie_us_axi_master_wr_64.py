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

import pcie
import pcie_us
import axi

module = 'pcie_us_axi_master_wr'
testbench = 'test_%s_64' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    AXIS_PCIE_DATA_WIDTH = 64
    AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32)
    AXIS_PCIE_CQ_USER_WIDTH = 85
    AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH
    AXI_ADDR_WIDTH = 64
    AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8)
    AXI_ID_WIDTH = 8
    AXI_MAX_BURST_LEN = 256

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_cq_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    s_axis_cq_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    s_axis_cq_tvalid = Signal(bool(0))
    s_axis_cq_tlast = Signal(bool(0))
    s_axis_cq_tuser = Signal(intbv(0)[AXIS_PCIE_CQ_USER_WIDTH:])
    m_axi_awready = Signal(bool(0))
    m_axi_wready = Signal(bool(0))
    m_axi_bid = Signal(intbv(0)[AXI_ID_WIDTH:])
    m_axi_bresp = Signal(intbv(0)[2:])
    m_axi_bvalid = Signal(bool(0))

    # Outputs
    s_axis_cq_tready = Signal(bool(0))
    m_axi_awid = Signal(intbv(0)[AXI_ID_WIDTH:])
    m_axi_awaddr = Signal(intbv(0)[AXI_ADDR_WIDTH:])
    m_axi_awlen = Signal(intbv(0)[8:])
    m_axi_awsize = Signal(intbv(3)[3:])
    m_axi_awburst = Signal(intbv(1)[2:])
    m_axi_awlock = Signal(bool(0))
    m_axi_awcache = Signal(intbv(3)[4:])
    m_axi_awprot = Signal(intbv(2)[3:])
    m_axi_awvalid = Signal(bool(0))
    m_axi_wdata = Signal(intbv(0)[AXI_DATA_WIDTH:])
    m_axi_wstrb = Signal(intbv(0)[AXI_STRB_WIDTH:])
    m_axi_wlast = Signal(bool(0))
    m_axi_wvalid = Signal(bool(0))
    m_axi_bready = Signal(bool(1))
    status_error_uncor = Signal(bool(0))

    # Clock and Reset Interface
    user_clk=Signal(bool(0))
    user_reset=Signal(bool(0))
    sys_clk=Signal(bool(0))
    sys_reset=Signal(bool(0))

    # AXI4 RAM model
    axi_ram_inst = axi.AXIRam(2**16)

    axi_ram_port0 = axi_ram_inst.create_port(
        user_clk,
        s_axi_awid=m_axi_awid,
        s_axi_awaddr=m_axi_awaddr,
        s_axi_awlen=m_axi_awlen,
        s_axi_awsize=m_axi_awsize,
        s_axi_awburst=m_axi_awburst,
        s_axi_awlock=m_axi_awlock,
        s_axi_awcache=m_axi_awcache,
        s_axi_awprot=m_axi_awprot,
        s_axi_awvalid=m_axi_awvalid,
        s_axi_awready=m_axi_awready,
        s_axi_wdata=m_axi_wdata,
        s_axi_wstrb=m_axi_wstrb,
        s_axi_wlast=m_axi_wlast,
        s_axi_wvalid=m_axi_wvalid,
        s_axi_wready=m_axi_wready,
        s_axi_bid=m_axi_bid,
        s_axi_bresp=m_axi_bresp,
        s_axi_bvalid=m_axi_bvalid,
        s_axi_bready=m_axi_bready,
        name='port0'
    )

    # PCIe devices
    rc = pcie.RootComplex()

    dev = pcie_us.UltrascalePCIe()

    dev.pcie_generation = 3
    dev.pcie_link_width = 2
    dev.user_clock_frequency = 250e6

    dev.functions[0].configure_bar(0, 16*1024*1024)

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
        #pcie_cq_np_req_count=pcie_cq_np_req_count,

        # Completer Completion Interface
        s_axis_cc_tdata=Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:]),
        s_axis_cc_tuser=Signal(intbv(0)[33:]),
        s_axis_cc_tlast=Signal(bool(0)),
        s_axis_cc_tkeep=Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:]),
        s_axis_cc_tvalid=Signal(bool(0)),
        s_axis_cc_tready=Signal(bool(0)),

        # Requester reQuest Interface
        s_axis_rq_tdata=Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:]),
        s_axis_rq_tuser=Signal(intbv(0)[60:]),
        s_axis_rq_tlast=Signal(bool(0)),
        s_axis_rq_tkeep=Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:]),
        s_axis_rq_tvalid=Signal(bool(0)),
        s_axis_rq_tready=Signal(bool(1)),
        # pcie_rq_seq_num=pcie_rq_seq_num,
        # pcie_rq_seq_num_vld=pcie_rq_seq_num_vld,
        # pcie_rq_tag=pcie_rq_tag,
        # pcie_rq_tag_av=pcie_rq_tag_av,
        # pcie_rq_tag_vld=pcie_rq_tag_vld,

        # Requester Completion Interface
        m_axis_rc_tdata=Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:]),
        m_axis_rc_tuser=Signal(intbv(0)[75:]),
        m_axis_rc_tlast=Signal(bool(0)),
        m_axis_rc_tkeep=Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:]),
        m_axis_rc_tvalid=Signal(bool(0)),
        m_axis_rc_tready=Signal(bool(0)),

        # Transmit Flow Control Interface
        # pcie_tfc_nph_av=pcie_tfc_nph_av,
        # pcie_tfc_npd_av=pcie_tfc_npd_av,

        # Configuration Control Interface
        # cfg_hot_reset_in=cfg_hot_reset_in,
        # cfg_hot_reset_out=cfg_hot_reset_out,
        # cfg_config_space_enable=cfg_config_space_enable,
        # cfg_per_function_update_done=cfg_per_function_update_done,
        # cfg_per_function_number=cfg_per_function_number,
        # cfg_per_function_output_request=cfg_per_function_output_request,
        # cfg_dsn=cfg_dsn,
        # cfg_ds_bus_number=cfg_ds_bus_number,
        # cfg_ds_device_number=cfg_ds_device_number,
        # cfg_ds_function_number=cfg_ds_function_number,
        # cfg_power_state_change_ack=cfg_power_state_change_ack,
        # cfg_power_state_change_interrupt=cfg_power_state_change_interrupt,
        # cfg_err_cor_in=cfg_err_cor_in,
        # cfg_err_uncor_in=cfg_err_uncor_in,
        # cfg_flr_done=cfg_flr_done,
        # cfg_vf_flr_done=cfg_vf_flr_done,
        # cfg_flr_in_process=cfg_flr_in_process,
        # cfg_vf_flr_in_process=cfg_vf_flr_in_process,
        # cfg_req_pm_transition_l23_ready=cfg_req_pm_transition_l23_ready,
        # cfg_link_training_enable=cfg_link_training_enable,

        # Clock and Reset Interface
        user_clk=user_clk,
        user_reset=user_reset,
        #user_lnk_up=user_lnk_up,
        sys_clk=sys_clk,
        sys_clk_gt=sys_clk,
        sys_reset=sys_reset,

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
        clk=user_clk,
        rst=user_reset,
        current_test=current_test,
        s_axis_cq_tdata=s_axis_cq_tdata,
        s_axis_cq_tkeep=s_axis_cq_tkeep,
        s_axis_cq_tvalid=s_axis_cq_tvalid,
        s_axis_cq_tready=s_axis_cq_tready,
        s_axis_cq_tlast=s_axis_cq_tlast,
        s_axis_cq_tuser=s_axis_cq_tuser,
        m_axi_awid=m_axi_awid,
        m_axi_awaddr=m_axi_awaddr,
        m_axi_awlen=m_axi_awlen,
        m_axi_awsize=m_axi_awsize,
        m_axi_awburst=m_axi_awburst,
        m_axi_awlock=m_axi_awlock,
        m_axi_awcache=m_axi_awcache,
        m_axi_awprot=m_axi_awprot,
        m_axi_awvalid=m_axi_awvalid,
        m_axi_awready=m_axi_awready,
        m_axi_wdata=m_axi_wdata,
        m_axi_wstrb=m_axi_wstrb,
        m_axi_wlast=m_axi_wlast,
        m_axi_wvalid=m_axi_wvalid,
        m_axi_wready=m_axi_wready,
        m_axi_bid=m_axi_bid,
        m_axi_bresp=m_axi_bresp,
        m_axi_bvalid=m_axi_bvalid,
        m_axi_bready=m_axi_bready,
        status_error_uncor=status_error_uncor
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    @always_comb
    def clk_logic():
        sys_clk.next = clk
        sys_reset.next = not rst

    status_error_uncor_asserted = Signal(bool(0))

    @always(user_clk.posedge)
    def monitor():
        if (status_error_uncor):
            status_error_uncor_asserted.next = 1

    cq_pause_toggle = Signal(bool(0))
    cc_pause_toggle = Signal(bool(0))
    rq_pause_toggle = Signal(bool(0))
    rc_pause_toggle = Signal(bool(0))

    @instance
    def pause_toggle():
        while True:
            if (cq_pause_toggle or cc_pause_toggle or rq_pause_toggle or rc_pause_toggle):
                cq_pause.next = cq_pause_toggle
                cc_pause.next = cc_pause_toggle
                rq_pause.next = rq_pause_toggle
                rc_pause.next = rc_pause_toggle

                yield user_clk.posedge
                yield user_clk.posedge
                yield user_clk.posedge

                cq_pause.next = 0
                cc_pause.next = 0
                rq_pause.next = 0
                rc_pause.next = 0

            yield user_clk.posedge

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

        yield user_clk.posedge
        print("test 1: enumeration")
        current_test.next = 1

        yield rc.enumerate()

        dev_bar0 = rc.tree[0][0].bar[0]

        yield delay(100)

        yield clk.posedge
        print("test 2: memory write")
        current_test.next = 2

        pcie_addr = 0x00000000
        test_data = b'\x11\x22\x33\x44'

        yield rc.mem_write(dev_bar0+pcie_addr, test_data)

        yield delay(300)

        data = axi_ram_inst.read_mem(pcie_addr, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axi_ram_inst.read_mem(pcie_addr, len(test_data)) == test_data

        assert not status_error_uncor_asserted

        yield delay(100)

        yield user_clk.posedge
        print("test 3: various writes")
        current_test.next = 3

        for length in list(range(1,34))+[1024]:
            for pcie_offset in list(range(8,41))+list(range(4096-32,4096)):
                for pause in [False, True]:
                    print("length %d, pcie_offset %d"% (length, pcie_offset))
                    #pcie_addr = length * 0x100000000 + pcie_offset * 0x10000 + offset
                    pcie_addr = pcie_offset
                    test_data = bytearray([x%256 for x in range(length)])

                    axi_ram_inst.write_mem(pcie_addr & 0xffff80, b'\x55'*(len(test_data)+256))

                    cq_pause_toggle.next = pause

                    yield from rc.mem_write(dev_bar0+pcie_addr, test_data)

                    yield delay(length*4+120)

                    cq_pause_toggle.next = 0

                    data = axi_ram_inst.read_mem(pcie_addr&0xfffff0, 64)
                    for i in range(0, len(data), 16):
                        print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                    assert axi_ram_inst.read_mem(pcie_addr-1, len(test_data)+2) == b'\x55'+test_data+b'\x55'

                    assert not status_error_uncor_asserted

                    yield delay(100)

        yield clk.posedge
        print("test 4: bad request")
        current_test.next = 4

        try:
            yield from rc.mem_read(dev_bar0, 4, 100)
        except:
            print("Caught timeout exception")
            pass
        else:
            assert False

        assert status_error_uncor_asserted

        status_error_uncor_asserted.next = False

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
