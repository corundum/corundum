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
import axis_ep

module = 'pcie_us_axi_dma_wr'
testbench = 'test_%s_256' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    AXIS_PCIE_DATA_WIDTH = 256
    AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32)
    AXIS_PCIE_RQ_USER_WIDTH = 60
    RQ_SEQ_NUM_WIDTH = 4 if AXIS_PCIE_RQ_USER_WIDTH == 60 else 6
    RQ_SEQ_NUM_ENABLE = 1
    AXI_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH
    AXI_ADDR_WIDTH = 64
    AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8)
    AXI_ID_WIDTH = 8
    AXI_MAX_BURST_LEN = 256
    PCIE_ADDR_WIDTH = 64
    LEN_WIDTH = 20
    TAG_WIDTH = 8
    OP_TABLE_SIZE = 2**(RQ_SEQ_NUM_WIDTH-1)
    TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1)
    TX_FC_ENABLE = 1

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_rq_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    s_axis_rq_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    s_axis_rq_tvalid = Signal(bool(0))
    s_axis_rq_tlast = Signal(bool(0))
    s_axis_rq_tuser = Signal(intbv(0)[AXIS_PCIE_RQ_USER_WIDTH:])
    m_axis_rq_tready = Signal(bool(0))
    s_axis_rq_seq_num_0 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    s_axis_rq_seq_num_valid_0 = Signal(bool(0))
    s_axis_rq_seq_num_1 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    s_axis_rq_seq_num_valid_1 = Signal(bool(0))
    pcie_tx_fc_ph_av = Signal(intbv(0)[8:])
    pcie_tx_fc_pd_av = Signal(intbv(0)[12:])
    s_axis_write_desc_pcie_addr = Signal(intbv(0)[PCIE_ADDR_WIDTH:])
    s_axis_write_desc_axi_addr = Signal(intbv(0)[AXI_ADDR_WIDTH:])
    s_axis_write_desc_len = Signal(intbv(0)[LEN_WIDTH:])
    s_axis_write_desc_tag = Signal(intbv(0)[TAG_WIDTH:])
    s_axis_write_desc_valid = Signal(bool(0))
    m_axi_arready = Signal(bool(0))
    m_axi_rid = Signal(intbv(0)[AXI_ID_WIDTH:])
    m_axi_rdata = Signal(intbv(0)[AXI_DATA_WIDTH:])
    m_axi_rresp = Signal(intbv(0)[2:])
    m_axi_rlast = Signal(bool(0))
    m_axi_rvalid = Signal(bool(0))
    enable = Signal(bool(0))
    requester_id = Signal(intbv(0)[16:])
    requester_id_enable = Signal(bool(0))
    max_payload_size = Signal(intbv(0)[3:])

    # Outputs
    s_axis_rq_tready = Signal(bool(0))
    m_axis_rq_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    m_axis_rq_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    m_axis_rq_tvalid = Signal(bool(0))
    m_axis_rq_tlast = Signal(bool(0))
    m_axis_rq_tuser = Signal(intbv(0)[AXIS_PCIE_RQ_USER_WIDTH:])
    m_axis_rq_seq_num_0 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    m_axis_rq_seq_num_valid_0 = Signal(bool(0))
    m_axis_rq_seq_num_1 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    m_axis_rq_seq_num_valid_1 = Signal(bool(0))
    s_axis_write_desc_ready = Signal(bool(0))
    m_axis_write_desc_status_tag = Signal(intbv(0)[TAG_WIDTH:])
    m_axis_write_desc_status_valid = Signal(bool(0))
    m_axi_arid = Signal(intbv(0)[AXI_ID_WIDTH:])
    m_axi_araddr = Signal(intbv(0)[AXI_ADDR_WIDTH:])
    m_axi_arlen = Signal(intbv(0)[8:])
    m_axi_arsize = Signal(intbv(5)[3:])
    m_axi_arburst = Signal(intbv(1)[2:])
    m_axi_arlock = Signal(bool(0))
    m_axi_arcache = Signal(intbv(3)[4:])
    m_axi_arprot = Signal(intbv(2)[3:])
    m_axi_arvalid = Signal(bool(0))
    m_axi_rready = Signal(bool(0))

    # Clock and Reset Interface
    user_clk=Signal(bool(0))
    user_reset=Signal(bool(0))
    sys_clk=Signal(bool(0))
    sys_reset=Signal(bool(0))

    # AXI4 RAM model
    axi_ram_inst = axi.AXIRam(2**16)

    axi_ram_port0 = axi_ram_inst.create_port(
        user_clk,
        s_axi_arid=m_axi_arid,
        s_axi_araddr=m_axi_araddr,
        s_axi_arlen=m_axi_arlen,
        s_axi_arsize=m_axi_arsize,
        s_axi_arburst=m_axi_arburst,
        s_axi_arlock=m_axi_arlock,
        s_axi_arcache=m_axi_arcache,
        s_axi_arprot=m_axi_arprot,
        s_axi_arvalid=m_axi_arvalid,
        s_axi_arready=m_axi_arready,
        s_axi_rid=m_axi_rid,
        s_axi_rdata=m_axi_rdata,
        s_axi_rresp=m_axi_rresp,
        s_axi_rlast=m_axi_rlast,
        s_axi_rvalid=m_axi_rvalid,
        s_axi_rready=m_axi_rready,
        name='port0'
    )

    write_desc_source = axis_ep.AXIStreamSource()

    write_desc_source_logic = write_desc_source.create_logic(
        user_clk,
        user_reset,
        tdata=(s_axis_write_desc_pcie_addr, s_axis_write_desc_axi_addr, s_axis_write_desc_len, s_axis_write_desc_tag),
        tvalid=s_axis_write_desc_valid,
        tready=s_axis_write_desc_ready,
        name='write_desc_source'
    )

    write_desc_status_sink = axis_ep.AXIStreamSink()

    write_desc_status_sink_logic = write_desc_status_sink.create_logic(
        user_clk,
        user_reset,
        tdata=(m_axis_write_desc_status_tag,),
        tvalid=m_axis_write_desc_status_valid,
        name='write_desc_status_sink'
    )

    # PCIe devices
    rc = pcie.RootComplex()

    mem_base, mem_data = rc.alloc_region(16*1024*1024)

    dev = pcie_us.UltrascalePCIe()

    dev.pcie_generation = 3
    dev.pcie_link_width = 8
    dev.user_clock_frequency = 250e6

    rc.make_port().connect(dev)

    cq_pause = Signal(bool(0))
    cc_pause = Signal(bool(0))
    rq_pause = Signal(bool(0))
    rc_pause = Signal(bool(0))

    pcie_logic = dev.create_logic(
        # Completer reQuest Interface
        m_axis_cq_tdata=Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:]),
        m_axis_cq_tuser=Signal(intbv(0)[85:]),
        m_axis_cq_tlast=Signal(bool(0)),
        m_axis_cq_tkeep=Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:]),
        m_axis_cq_tvalid=Signal(bool(0)),
        m_axis_cq_tready=Signal(bool(1)),
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
        s_axis_rq_tdata=m_axis_rq_tdata,
        s_axis_rq_tuser=m_axis_rq_tuser,
        s_axis_rq_tlast=m_axis_rq_tlast,
        s_axis_rq_tkeep=m_axis_rq_tkeep,
        s_axis_rq_tvalid=m_axis_rq_tvalid,
        s_axis_rq_tready=m_axis_rq_tready,
        pcie_rq_seq_num=s_axis_rq_seq_num_0,
        pcie_rq_seq_num_vld=s_axis_rq_seq_num_valid_0,
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

        # Configuration Flow Control Interface
        cfg_fc_ph=pcie_tx_fc_ph_av,
        cfg_fc_pd=pcie_tx_fc_pd_av,
        #cfg_fc_nph=cfg_fc_nph,
        #cfg_fc_npd=cfg_fc_npd,
        #cfg_fc_cplh=cfg_fc_cplh,
        #cfg_fc_cpld=cfg_fc_cpld,
        cfg_fc_sel=Signal(intbv(0b100)[3:]),

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
        s_axis_rq_tdata=s_axis_rq_tdata,
        s_axis_rq_tkeep=s_axis_rq_tkeep,
        s_axis_rq_tvalid=s_axis_rq_tvalid,
        s_axis_rq_tready=s_axis_rq_tready,
        s_axis_rq_tlast=s_axis_rq_tlast,
        s_axis_rq_tuser=s_axis_rq_tuser,
        m_axis_rq_tdata=m_axis_rq_tdata,
        m_axis_rq_tkeep=m_axis_rq_tkeep,
        m_axis_rq_tvalid=m_axis_rq_tvalid,
        m_axis_rq_tready=m_axis_rq_tready,
        m_axis_rq_tlast=m_axis_rq_tlast,
        m_axis_rq_tuser=m_axis_rq_tuser,
        s_axis_rq_seq_num_0=s_axis_rq_seq_num_0,
        s_axis_rq_seq_num_valid_0=s_axis_rq_seq_num_valid_0,
        s_axis_rq_seq_num_1=s_axis_rq_seq_num_1,
        s_axis_rq_seq_num_valid_1=s_axis_rq_seq_num_valid_1,
        m_axis_rq_seq_num_0=m_axis_rq_seq_num_0,
        m_axis_rq_seq_num_valid_0=m_axis_rq_seq_num_valid_0,
        m_axis_rq_seq_num_1=m_axis_rq_seq_num_1,
        m_axis_rq_seq_num_valid_1=m_axis_rq_seq_num_valid_1,
        pcie_tx_fc_ph_av=pcie_tx_fc_ph_av,
        pcie_tx_fc_pd_av=pcie_tx_fc_pd_av,
        s_axis_write_desc_pcie_addr=s_axis_write_desc_pcie_addr,
        s_axis_write_desc_axi_addr=s_axis_write_desc_axi_addr,
        s_axis_write_desc_len=s_axis_write_desc_len,
        s_axis_write_desc_tag=s_axis_write_desc_tag,
        s_axis_write_desc_valid=s_axis_write_desc_valid,
        s_axis_write_desc_ready=s_axis_write_desc_ready,
        m_axis_write_desc_status_tag=m_axis_write_desc_status_tag,
        m_axis_write_desc_status_valid=m_axis_write_desc_status_valid,
        m_axi_arid=m_axi_arid,
        m_axi_araddr=m_axi_araddr,
        m_axi_arlen=m_axi_arlen,
        m_axi_arsize=m_axi_arsize,
        m_axi_arburst=m_axi_arburst,
        m_axi_arlock=m_axi_arlock,
        m_axi_arcache=m_axi_arcache,
        m_axi_arprot=m_axi_arprot,
        m_axi_arvalid=m_axi_arvalid,
        m_axi_arready=m_axi_arready,
        m_axi_rid=m_axi_rid,
        m_axi_rdata=m_axi_rdata,
        m_axi_rresp=m_axi_rresp,
        m_axi_rlast=m_axi_rlast,
        m_axi_rvalid=m_axi_rvalid,
        m_axi_rready=m_axi_rready,
        enable=enable,
        requester_id=requester_id,
        requester_id_enable=requester_id_enable,
        max_payload_size=max_payload_size
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    @always_comb
    def clk_logic():
        sys_clk.next = clk
        sys_reset.next = not rst

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

        cur_tag = 1

        max_payload_size.next = 0

        enable.next = 1

        yield user_clk.posedge
        print("test 1: enumeration")
        current_test.next = 1

        yield rc.enumerate(enable_bus_mastering=True)

        yield delay(100)

        yield user_clk.posedge
        print("test 2: PCIe write")
        current_test.next = 2

        pcie_addr = 0x00000000
        axi_addr = 0x00000000
        test_data = b'\x11\x22\x33\x44'

        axi_ram_inst.write_mem(axi_addr, test_data)

        data = axi_ram_inst.read_mem(axi_addr, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        write_desc_source.send([(mem_base+pcie_addr, axi_addr, len(test_data), cur_tag)])

        yield write_desc_status_sink.wait(1000)
        yield delay(50)

        status = write_desc_status_sink.recv()

        print(status)

        assert status.data[0][0] == cur_tag

        data = mem_data[pcie_addr:pcie_addr+32]
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert mem_data[pcie_addr:pcie_addr+len(test_data)] == test_data

        cur_tag = (cur_tag + 1) % 256

        yield delay(100)

        yield user_clk.posedge
        print("test 3: various writes")
        current_test.next = 3

        for length in list(range(1,35))+list(range(128-4,128+4))+[1024]:
            for pcie_offset in list(range(8,13))+list(range(4096-4,4096+4)):
                for axi_offset in list(range(8,41))+list(range(4096-32,4096)):
                    for pause in [False, True]:
                        print("length %d, pcie_offset %d, axi_offset %d"% (length, pcie_offset, axi_offset))
                        #pcie_addr = length * 0x100000000 + pcie_offset * 0x10000 + offset
                        pcie_addr = pcie_offset
                        axi_addr = axi_offset
                        test_data = bytearray([x%256 for x in range(length)])

                        axi_ram_inst.write_mem(axi_addr & 0xffff80, b'\x55'*(len(test_data)+256))
                        mem_data[(pcie_addr-1) & 0xffff80:((pcie_addr-1) & 0xffff80)+len(test_data)+256] = b'\xaa'*(len(test_data)+256)
                        axi_ram_inst.write_mem(axi_addr, test_data) 

                        data = axi_ram_inst.read_mem(axi_addr&0xfffff0, 64)
                        for i in range(0, len(data), 16):
                            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                        rq_pause_toggle.next = pause

                        write_desc_source.send([(mem_base+pcie_addr, axi_addr, len(test_data), cur_tag)])

                        yield write_desc_status_sink.wait(4000)
                        yield delay(50)

                        rq_pause_toggle.next = 0

                        status = write_desc_status_sink.recv()

                        print(status)

                        assert status.data[0][0] == cur_tag

                        data = mem_data[pcie_addr&0xfffff0:(pcie_addr&0xfffff0)+64]
                        for i in range(0, len(data), 16):
                            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                        assert mem_data[pcie_addr-1:pcie_addr+len(test_data)+1] == b'\xaa'+test_data+b'\xaa'

                        cur_tag = (cur_tag + 1) % 256

                        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
