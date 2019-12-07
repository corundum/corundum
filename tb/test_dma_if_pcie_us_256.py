#!/usr/bin/env python
"""

Copyright (c) 2019 Alex Forencich

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
import dma_ram
import axis_ep

module = 'dma_if_pcie_us'
testbench = 'test_%s_256' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/dma_if_pcie_us_rd.v")
srcs.append("../rtl/dma_if_pcie_us_wr.v")
srcs.append("../rtl/priority_encoder.v")
srcs.append("../rtl/pcie_tag_manager.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    AXIS_PCIE_DATA_WIDTH = 256
    AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH/32)
    AXIS_PCIE_RC_USER_WIDTH = 75
    AXIS_PCIE_RQ_USER_WIDTH = 60
    RQ_SEQ_NUM_WIDTH = 4 if AXIS_PCIE_RQ_USER_WIDTH == 60 else 6
    RQ_SEQ_NUM_ENABLE = 1
    SEG_COUNT = max(2, int(AXIS_PCIE_DATA_WIDTH*2/128))
    SEG_DATA_WIDTH = AXIS_PCIE_DATA_WIDTH*2/SEG_COUNT
    SEG_ADDR_WIDTH = 12
    SEG_BE_WIDTH = int(SEG_DATA_WIDTH/8)
    RAM_SEL_WIDTH = 2
    RAM_ADDR_WIDTH = SEG_ADDR_WIDTH+(SEG_COUNT-1).bit_length()+(SEG_BE_WIDTH-1).bit_length()
    PCIE_ADDR_WIDTH = 64
    PCIE_TAG_COUNT = 64 if AXIS_PCIE_RQ_USER_WIDTH == 60 else 256
    PCIE_TAG_WIDTH = (PCIE_TAG_COUNT-1).bit_length()
    PCIE_EXT_TAG_ENABLE = (PCIE_TAG_COUNT>32)
    LEN_WIDTH = 16
    TAG_WIDTH = 8
    READ_OP_TABLE_SIZE = PCIE_TAG_COUNT
    READ_TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1)
    READ_TX_FC_ENABLE = 1
    WRITE_OP_TABLE_SIZE = 2**(RQ_SEQ_NUM_WIDTH-1)
    WRITE_TX_LIMIT = 2**(RQ_SEQ_NUM_WIDTH-1)
    WRITE_TX_FC_ENABLE = 1

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_rc_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    s_axis_rc_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    s_axis_rc_tvalid = Signal(bool(0))
    s_axis_rc_tlast = Signal(bool(0))
    s_axis_rc_tuser = Signal(intbv(0)[AXIS_PCIE_RC_USER_WIDTH:])
    m_axis_rq_tready = Signal(bool(0))
    s_axis_rq_seq_num_0 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    s_axis_rq_seq_num_valid_0 = Signal(bool(0))
    s_axis_rq_seq_num_1 = Signal(intbv(0)[RQ_SEQ_NUM_WIDTH:])
    s_axis_rq_seq_num_valid_1 = Signal(bool(0))
    pcie_tx_fc_nph_av = Signal(intbv(0)[8:])
    pcie_tx_fc_ph_av = Signal(intbv(0)[8:])
    pcie_tx_fc_pd_av = Signal(intbv(0)[12:])
    s_axis_read_desc_pcie_addr = Signal(intbv(0)[PCIE_ADDR_WIDTH:])
    s_axis_read_desc_ram_sel = Signal(intbv(0)[RAM_SEL_WIDTH:])
    s_axis_read_desc_ram_addr = Signal(intbv(0)[RAM_ADDR_WIDTH:])
    s_axis_read_desc_len = Signal(intbv(0)[LEN_WIDTH:])
    s_axis_read_desc_tag = Signal(intbv(0)[TAG_WIDTH:])
    s_axis_read_desc_valid = Signal(bool(0))
    s_axis_write_desc_pcie_addr = Signal(intbv(0)[PCIE_ADDR_WIDTH:])
    s_axis_write_desc_ram_sel = Signal(intbv(0)[RAM_SEL_WIDTH:])
    s_axis_write_desc_ram_addr = Signal(intbv(0)[RAM_ADDR_WIDTH:])
    s_axis_write_desc_len = Signal(intbv(0)[LEN_WIDTH:])
    s_axis_write_desc_tag = Signal(intbv(0)[TAG_WIDTH:])
    s_axis_write_desc_valid = Signal(bool(0))
    ram_wr_cmd_ready = Signal(intbv(0)[SEG_COUNT:])
    ram_rd_cmd_ready = Signal(intbv(0)[SEG_COUNT:])
    ram_rd_resp_data = Signal(intbv(0)[SEG_COUNT*SEG_DATA_WIDTH:])
    ram_rd_resp_valid = Signal(intbv(0)[SEG_COUNT:])
    read_enable = Signal(bool(0))
    write_enable = Signal(bool(0))
    ext_tag_enable = Signal(bool(0))
    requester_id = Signal(intbv(0)[16:])
    requester_id_enable = Signal(bool(0))
    max_read_request_size = Signal(intbv(0)[3:])
    max_payload_size = Signal(intbv(0)[3:])

    # Outputs
    s_axis_rc_tready = Signal(bool(0))
    m_axis_rq_tdata = Signal(intbv(0)[AXIS_PCIE_DATA_WIDTH:])
    m_axis_rq_tkeep = Signal(intbv(0)[AXIS_PCIE_KEEP_WIDTH:])
    m_axis_rq_tvalid = Signal(bool(0))
    m_axis_rq_tlast = Signal(bool(0))
    m_axis_rq_tuser = Signal(intbv(0)[AXIS_PCIE_RQ_USER_WIDTH:])
    s_axis_read_desc_ready = Signal(bool(0))
    m_axis_read_desc_status_tag = Signal(intbv(0)[TAG_WIDTH:])
    m_axis_read_desc_status_valid = Signal(bool(0))
    s_axis_write_desc_ready = Signal(bool(0))
    m_axis_write_desc_status_tag = Signal(intbv(0)[TAG_WIDTH:])
    m_axis_write_desc_status_valid = Signal(bool(0))
    ram_wr_cmd_sel = Signal(intbv(0)[SEG_COUNT*RAM_SEL_WIDTH:])
    ram_wr_cmd_be = Signal(intbv(0)[SEG_COUNT*SEG_BE_WIDTH:])
    ram_wr_cmd_addr = Signal(intbv(0)[SEG_COUNT*SEG_ADDR_WIDTH:])
    ram_wr_cmd_data = Signal(intbv(0)[SEG_COUNT*SEG_DATA_WIDTH:])
    ram_wr_cmd_valid = Signal(intbv(0)[SEG_COUNT:])
    ram_rd_cmd_sel = Signal(intbv(0)[SEG_COUNT*RAM_SEL_WIDTH:])
    ram_rd_cmd_addr = Signal(intbv(0)[SEG_COUNT*SEG_ADDR_WIDTH:])
    ram_rd_cmd_valid = Signal(intbv(0)[SEG_COUNT:])
    ram_rd_resp_ready = Signal(intbv(0)[SEG_COUNT:])
    status_error_cor = Signal(bool(0))
    status_error_uncor = Signal(bool(0))

    # Clock and Reset Interface
    user_clk=Signal(bool(0))
    user_reset=Signal(bool(0))
    sys_clk=Signal(bool(0))
    sys_reset=Signal(bool(0))

    # PCIe DMA RAM
    dma_ram_inst = dma_ram.PSDPRam(2**16)
    dma_ram_pause = Signal(bool(0))

    dma_ram_port0_wr = dma_ram_inst.create_write_ports(
        user_clk,
        ram_wr_cmd_be=ram_wr_cmd_be,
        ram_wr_cmd_addr=ram_wr_cmd_addr,
        ram_wr_cmd_data=ram_wr_cmd_data,
        ram_wr_cmd_valid=ram_wr_cmd_valid,
        ram_wr_cmd_ready=ram_wr_cmd_ready,
        pause=dma_ram_pause,
        name='port0_wr'
    )

    dma_ram_port0_rd = dma_ram_inst.create_read_ports(
        user_clk,
        ram_rd_cmd_addr=ram_rd_cmd_addr,
        ram_rd_cmd_valid=ram_rd_cmd_valid,
        ram_rd_cmd_ready=ram_rd_cmd_ready,
        ram_rd_resp_data=ram_rd_resp_data,
        ram_rd_resp_valid=ram_rd_resp_valid,
        ram_rd_resp_ready=ram_rd_resp_ready,
        pause=dma_ram_pause,
        name='port0_rd'
    )

    # sources and sinks
    read_desc_source = axis_ep.AXIStreamSource()

    read_desc_source_logic = read_desc_source.create_logic(
        user_clk,
        user_reset,
        tdata=(s_axis_read_desc_pcie_addr, s_axis_read_desc_ram_sel, s_axis_read_desc_ram_addr, s_axis_read_desc_len, s_axis_read_desc_tag),
        tvalid=s_axis_read_desc_valid,
        tready=s_axis_read_desc_ready,
        name='read_desc_source'
    )

    read_desc_status_sink = axis_ep.AXIStreamSink()

    read_desc_status_sink_logic = read_desc_status_sink.create_logic(
        user_clk,
        user_reset,
        tdata=(m_axis_read_desc_status_tag,),
        tvalid=m_axis_read_desc_status_valid,
        name='read_desc_status_sink'
    )

    write_desc_source = axis_ep.AXIStreamSource()

    write_desc_source_logic = write_desc_source.create_logic(
        user_clk,
        user_reset,
        tdata=(s_axis_write_desc_pcie_addr, s_axis_write_desc_ram_sel, s_axis_write_desc_ram_addr, s_axis_write_desc_len, s_axis_write_desc_tag),
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
    dev.user_clock_frequency = 256e6

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
        pcie_cq_np_req=Signal(bool(1)),
        pcie_cq_np_req_count=Signal(intbv(0)[6:]),

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
        m_axis_rc_tdata=s_axis_rc_tdata,
        m_axis_rc_tuser=s_axis_rc_tuser,
        m_axis_rc_tlast=s_axis_rc_tlast,
        m_axis_rc_tkeep=s_axis_rc_tkeep,
        m_axis_rc_tvalid=s_axis_rc_tvalid,
        m_axis_rc_tready=s_axis_rc_tready,

        # Transmit Flow Control Interface
        # pcie_tfc_nph_av=pcie_tfc_nph_av,
        # pcie_tfc_npd_av=pcie_tfc_npd_av,

        # Configuration Flow Control Interface
        cfg_fc_ph=pcie_tx_fc_ph_av,
        cfg_fc_pd=pcie_tx_fc_pd_av,
        cfg_fc_nph=pcie_tx_fc_nph_av,
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
        s_axis_rc_tdata=s_axis_rc_tdata,
        s_axis_rc_tkeep=s_axis_rc_tkeep,
        s_axis_rc_tvalid=s_axis_rc_tvalid,
        s_axis_rc_tready=s_axis_rc_tready,
        s_axis_rc_tlast=s_axis_rc_tlast,
        s_axis_rc_tuser=s_axis_rc_tuser,
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
        pcie_tx_fc_nph_av=pcie_tx_fc_nph_av,
        pcie_tx_fc_ph_av=pcie_tx_fc_ph_av,
        pcie_tx_fc_pd_av=pcie_tx_fc_pd_av,
        s_axis_read_desc_pcie_addr=s_axis_read_desc_pcie_addr,
        s_axis_read_desc_ram_sel=s_axis_read_desc_ram_sel,
        s_axis_read_desc_ram_addr=s_axis_read_desc_ram_addr,
        s_axis_read_desc_len=s_axis_read_desc_len,
        s_axis_read_desc_tag=s_axis_read_desc_tag,
        s_axis_read_desc_valid=s_axis_read_desc_valid,
        s_axis_read_desc_ready=s_axis_read_desc_ready,
        m_axis_read_desc_status_tag=m_axis_read_desc_status_tag,
        m_axis_read_desc_status_valid=m_axis_read_desc_status_valid,
        s_axis_write_desc_pcie_addr=s_axis_write_desc_pcie_addr,
        s_axis_write_desc_ram_sel=s_axis_write_desc_ram_sel,
        s_axis_write_desc_ram_addr=s_axis_write_desc_ram_addr,
        s_axis_write_desc_len=s_axis_write_desc_len,
        s_axis_write_desc_tag=s_axis_write_desc_tag,
        s_axis_write_desc_valid=s_axis_write_desc_valid,
        s_axis_write_desc_ready=s_axis_write_desc_ready,
        m_axis_write_desc_status_tag=m_axis_write_desc_status_tag,
        m_axis_write_desc_status_valid=m_axis_write_desc_status_valid,
        ram_wr_cmd_sel=ram_wr_cmd_sel,
        ram_wr_cmd_be=ram_wr_cmd_be,
        ram_wr_cmd_addr=ram_wr_cmd_addr,
        ram_wr_cmd_data=ram_wr_cmd_data,
        ram_wr_cmd_valid=ram_wr_cmd_valid,
        ram_wr_cmd_ready=ram_wr_cmd_ready,
        ram_rd_cmd_sel=ram_rd_cmd_sel,
        ram_rd_cmd_addr=ram_rd_cmd_addr,
        ram_rd_cmd_valid=ram_rd_cmd_valid,
        ram_rd_cmd_ready=ram_rd_cmd_ready,
        ram_rd_resp_data=ram_rd_resp_data,
        ram_rd_resp_valid=ram_rd_resp_valid,
        ram_rd_resp_ready=ram_rd_resp_ready,
        read_enable=read_enable,
        write_enable=write_enable,
        ext_tag_enable=ext_tag_enable,
        requester_id=requester_id,
        requester_id_enable=requester_id_enable,
        max_read_request_size=max_read_request_size,
        max_payload_size=max_payload_size,
        status_error_cor=status_error_cor,
        status_error_uncor=status_error_uncor
    )

    @always(delay(4))
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

        cur_tag = 1

        max_payload_size.next = 0
        max_read_request_size.next = 2

        read_enable.next = 1
        write_enable.next = 1

        yield user_clk.posedge
        print("test 1: enumeration")
        current_test.next = 1

        yield rc.enumerate(enable_bus_mastering=True)

        yield delay(100)

        yield user_clk.posedge
        print("test 2: PCIe write")
        current_test.next = 2

        pcie_addr = 0x00000000
        ram_addr = 0x00000000
        test_data = b'\x11\x22\x33\x44'

        dma_ram_inst.write_mem(ram_addr, test_data)
        mem_data[pcie_addr:pcie_addr+len(test_data)] = b'\x00'*len(test_data)

        data = dma_ram_inst.read_mem(ram_addr, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        write_desc_source.send([(mem_base+pcie_addr, 0, ram_addr, len(test_data), cur_tag)])

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
        print("test 3: PCIe read")
        current_test.next = 3

        pcie_addr = 0x00000000
        ram_addr = 0x00000000
        test_data = b'\x11\x22\x33\x44'

        dma_ram_inst.write_mem(ram_addr, b'\x00'*len(test_data))
        mem_data[pcie_addr:pcie_addr+len(test_data)] = test_data

        data = mem_data[pcie_addr:pcie_addr+32]
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        read_desc_source.send([(pcie_addr, 0, ram_addr, len(test_data), cur_tag)])

        yield read_desc_status_sink.wait(2000)

        status = read_desc_status_sink.recv()

        print(status)

        assert status.data[0][0] == cur_tag

        data = dma_ram_inst.read_mem(ram_addr, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert dma_ram_inst.read_mem(ram_addr, len(test_data)) == test_data

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
