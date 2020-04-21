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

import axil
import axis_ep

import random
import struct

module = 'queue_manager'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    ADDR_WIDTH = 64
    REQ_TAG_WIDTH = 8
    OP_TABLE_SIZE = 16
    OP_TAG_WIDTH = 8
    QUEUE_INDEX_WIDTH = 8
    CPL_INDEX_WIDTH = 8
    QUEUE_PTR_WIDTH = 16
    LOG_QUEUE_SIZE_WIDTH = 4
    DESC_SIZE = 16
    LOG_BLOCK_SIZE_WIDTH = 2
    PIPELINE = 2
    AXIL_DATA_WIDTH = 32
    AXIL_ADDR_WIDTH = 16
    AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_dequeue_req_queue = Signal(intbv(0)[QUEUE_INDEX_WIDTH:])
    s_axis_dequeue_req_tag = Signal(intbv(0)[REQ_TAG_WIDTH:])
    s_axis_dequeue_req_valid = Signal(bool(0))
    m_axis_dequeue_resp_ready = Signal(bool(0))
    s_axis_dequeue_commit_op_tag = Signal(intbv(0)[OP_TAG_WIDTH:])
    s_axis_dequeue_commit_valid = Signal(bool(0))
    s_axil_awaddr = Signal(intbv(0)[AXIL_ADDR_WIDTH:])
    s_axil_awprot = Signal(intbv(0)[3:])
    s_axil_awvalid = Signal(bool(0))
    s_axil_wdata = Signal(intbv(0)[AXIL_DATA_WIDTH:])
    s_axil_wstrb = Signal(intbv(0)[AXIL_STRB_WIDTH:])
    s_axil_wvalid = Signal(bool(0))
    s_axil_bready = Signal(bool(0))
    s_axil_araddr = Signal(intbv(0)[AXIL_ADDR_WIDTH:])
    s_axil_arprot = Signal(intbv(0)[3:])
    s_axil_arvalid = Signal(bool(0))
    s_axil_rready = Signal(bool(0))
    enable = Signal(bool(0))

    # Outputs
    s_axis_dequeue_req_ready = Signal(bool(0))
    m_axis_dequeue_resp_queue = Signal(intbv(0)[QUEUE_INDEX_WIDTH:])
    m_axis_dequeue_resp_ptr = Signal(intbv(0)[QUEUE_PTR_WIDTH:])
    m_axis_dequeue_resp_addr = Signal(intbv(0)[ADDR_WIDTH:])
    m_axis_dequeue_resp_block_size = Signal(intbv(0)[LOG_BLOCK_SIZE_WIDTH:])
    m_axis_dequeue_resp_cpl = Signal(intbv(0)[CPL_INDEX_WIDTH:])
    m_axis_dequeue_resp_tag = Signal(intbv(0)[REQ_TAG_WIDTH:])
    m_axis_dequeue_resp_op_tag = Signal(intbv(0)[OP_TAG_WIDTH:])
    m_axis_dequeue_resp_empty = Signal(bool(0))
    m_axis_dequeue_resp_error = Signal(bool(0))
    m_axis_dequeue_resp_valid = Signal(bool(0))
    s_axis_dequeue_commit_ready = Signal(bool(0))
    m_axis_doorbell_queue = Signal(intbv(0)[QUEUE_INDEX_WIDTH:])
    m_axis_doorbell_valid = Signal(bool(0))
    s_axil_awready = Signal(bool(0))
    s_axil_wready = Signal(bool(0))
    s_axil_bresp = Signal(intbv(0)[2:])
    s_axil_bvalid = Signal(bool(0))
    s_axil_arready = Signal(bool(0))
    s_axil_rdata = Signal(intbv(0)[AXIL_DATA_WIDTH:])
    s_axil_rresp = Signal(intbv(0)[2:])
    s_axil_rvalid = Signal(bool(0))

    # sources and sinks
    dequeue_req_source = axis_ep.AXIStreamSource()

    dequeue_req_source_logic = dequeue_req_source.create_logic(
        clk,
        rst,
        tdata=(s_axis_dequeue_req_queue, s_axis_dequeue_req_tag),
        tvalid=s_axis_dequeue_req_valid,
        tready=s_axis_dequeue_req_ready,
        name='dequeue_req_source'
    )

    dequeue_resp_sink = axis_ep.AXIStreamSink()

    dequeue_resp_sink_logic = dequeue_resp_sink.create_logic(
        clk,
        rst,
        tdata=(m_axis_dequeue_resp_queue, m_axis_dequeue_resp_ptr, m_axis_dequeue_resp_addr, m_axis_dequeue_resp_block_size, m_axis_dequeue_resp_cpl, m_axis_dequeue_resp_tag, m_axis_dequeue_resp_op_tag, m_axis_dequeue_resp_empty, m_axis_dequeue_resp_error),
        tvalid=m_axis_dequeue_resp_valid,
        tready=m_axis_dequeue_resp_ready,
        name='dequeue_resp_sink'
    )

    dequeue_commit_source = axis_ep.AXIStreamSource()

    dequeue_commit_source_logic = dequeue_commit_source.create_logic(
        clk,
        rst,
        tdata=(s_axis_dequeue_commit_op_tag,),
        tvalid=s_axis_dequeue_commit_valid,
        tready=s_axis_dequeue_commit_ready,
        name='dequeue_commit_source'
    )

    doorbell_sink = axis_ep.AXIStreamSink()

    doorbell_sink_logic = doorbell_sink.create_logic(
        clk,
        rst,
        tdata=(m_axis_doorbell_queue,),
        tvalid=m_axis_doorbell_valid,
        name='doorbell_sink'
    )

    # AXI4-Lite master
    axil_master_inst = axil.AXILiteMaster()
    axil_master_pause = Signal(bool(False))

    axil_master_logic = axil_master_inst.create_logic(
        clk,
        rst,
        m_axil_awaddr=s_axil_awaddr,
        m_axil_awprot=s_axil_awprot,
        m_axil_awvalid=s_axil_awvalid,
        m_axil_awready=s_axil_awready,
        m_axil_wdata=s_axil_wdata,
        m_axil_wstrb=s_axil_wstrb,
        m_axil_wvalid=s_axil_wvalid,
        m_axil_wready=s_axil_wready,
        m_axil_bresp=s_axil_bresp,
        m_axil_bvalid=s_axil_bvalid,
        m_axil_bready=s_axil_bready,
        m_axil_araddr=s_axil_araddr,
        m_axil_arprot=s_axil_arprot,
        m_axil_arvalid=s_axil_arvalid,
        m_axil_arready=s_axil_arready,
        m_axil_rdata=s_axil_rdata,
        m_axil_rresp=s_axil_rresp,
        m_axil_rvalid=s_axil_rvalid,
        m_axil_rready=s_axil_rready,
        pause=axil_master_pause,
        name='master'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        s_axis_dequeue_req_queue=s_axis_dequeue_req_queue,
        s_axis_dequeue_req_tag=s_axis_dequeue_req_tag,
        s_axis_dequeue_req_valid=s_axis_dequeue_req_valid,
        s_axis_dequeue_req_ready=s_axis_dequeue_req_ready,
        m_axis_dequeue_resp_queue=m_axis_dequeue_resp_queue,
        m_axis_dequeue_resp_ptr=m_axis_dequeue_resp_ptr,
        m_axis_dequeue_resp_addr=m_axis_dequeue_resp_addr,
        m_axis_dequeue_resp_block_size=m_axis_dequeue_resp_block_size,
        m_axis_dequeue_resp_cpl=m_axis_dequeue_resp_cpl,
        m_axis_dequeue_resp_tag=m_axis_dequeue_resp_tag,
        m_axis_dequeue_resp_op_tag=m_axis_dequeue_resp_op_tag,
        m_axis_dequeue_resp_empty=m_axis_dequeue_resp_empty,
        m_axis_dequeue_resp_error=m_axis_dequeue_resp_error,
        m_axis_dequeue_resp_valid=m_axis_dequeue_resp_valid,
        m_axis_dequeue_resp_ready=m_axis_dequeue_resp_ready,
        s_axis_dequeue_commit_op_tag=s_axis_dequeue_commit_op_tag,
        s_axis_dequeue_commit_valid=s_axis_dequeue_commit_valid,
        s_axis_dequeue_commit_ready=s_axis_dequeue_commit_ready,
        m_axis_doorbell_queue=m_axis_doorbell_queue,
        m_axis_doorbell_valid=m_axis_doorbell_valid,
        s_axil_awaddr=s_axil_awaddr,
        s_axil_awprot=s_axil_awprot,
        s_axil_awvalid=s_axil_awvalid,
        s_axil_awready=s_axil_awready,
        s_axil_wdata=s_axil_wdata,
        s_axil_wstrb=s_axil_wstrb,
        s_axil_wvalid=s_axil_wvalid,
        s_axil_wready=s_axil_wready,
        s_axil_bresp=s_axil_bresp,
        s_axil_bvalid=s_axil_bvalid,
        s_axil_bready=s_axil_bready,
        s_axil_araddr=s_axil_araddr,
        s_axil_arprot=s_axil_arprot,
        s_axil_arvalid=s_axil_arvalid,
        s_axil_arready=s_axil_arready,
        s_axil_rdata=s_axil_rdata,
        s_axil_rresp=s_axil_rresp,
        s_axil_rvalid=s_axil_rvalid,
        s_axil_rready=s_axil_rready,
        enable=enable
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

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

        enable.next = 1

        yield clk.posedge
        print("test 1: read and write queue configuration registers")
        current_test.next = 1

        axil_master_inst.init_write(0*32+0,  struct.pack('<Q', 0x8877665544332211)) # address
        axil_master_inst.init_write(0*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(0*32+12, struct.pack('<L', 0x00000001)) # completion queue index
        axil_master_inst.init_write(0*32+16, struct.pack('<L', 0x00000000)) # head pointer
        axil_master_inst.init_write(0*32+24, struct.pack('<L', 0x00000000)) # tail pointer
        axil_master_inst.init_write(0*32+8,  struct.pack('<L', 0x80000004)) # active, log size

        yield axil_master_inst.wait()
        yield clk.posedge

        axil_master_inst.init_read(0*32+0,  8)
        axil_master_inst.init_read(0*32+8,  4)
        axil_master_inst.init_read(0*32+12, 4)

        yield axil_master_inst.wait()
        yield clk.posedge

        data = axil_master_inst.get_read_data()
        assert struct.unpack('<Q', data[1])[0] == 0x8877665544332211
        data = axil_master_inst.get_read_data()
        assert struct.unpack('<L', data[1])[0] == 0x80000004
        data = axil_master_inst.get_read_data()
        assert struct.unpack('<L', data[1])[0] == 0x00000001

        yield delay(100)

        yield clk.posedge
        print("test 2: enqueue and dequeue")
        current_test.next = 2

        # increment head pointer
        axil_master_inst.init_read(0*32+16, 4) # head pointer
        yield axil_master_inst.wait()

        data = axil_master_inst.get_read_data()
        head_ptr = struct.unpack('<L', data[1])[0]

        axil_master_inst.init_write(0*32+16, struct.pack('<L', head_ptr + 1)) # head pointer

        yield axil_master_inst.wait()
        yield clk.posedge

        # check for doorbell event
        yield doorbell_sink.wait()
        db = doorbell_sink.recv()
        assert db.data[0][0] == 0

        # read tail pointer
        axil_master_inst.init_read(0*32+24, 4) # tail pointer
        yield axil_master_inst.wait()

        data = axil_master_inst.get_read_data()
        tail_ptr = struct.unpack('<L', data[1])[0]

        # dequeue request
        dequeue_req_source.send([(0, 1)])

        yield dequeue_resp_sink.wait()

        resp = dequeue_resp_sink.recv()
        print(resp)

        # dequeue commit
        dequeue_commit_source.send([(resp.data[0][6],)])

        yield delay(100)

        # read tail pointer
        axil_master_inst.init_read(0*32+24, 4) # tail pointer
        yield axil_master_inst.wait()

        data = axil_master_inst.get_read_data()
        new_tail_ptr = struct.unpack('<L', data[1])[0]

        assert new_tail_ptr - tail_ptr == 1

        yield delay(100)

        yield clk.posedge
        print("test 3: set up more queues")
        current_test.next = 3

        axil_master_inst.init_write(0*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(0*32+0,  struct.pack('<Q', 0x5555555555000000)) # address
        axil_master_inst.init_write(0*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(0*32+12, struct.pack('<L', 0x00000000)) # completion queue index
        axil_master_inst.init_write(0*32+16, struct.pack('<L', 0x0000fff0)) # head pointer
        axil_master_inst.init_write(0*32+24, struct.pack('<L', 0x0000fff0)) # tail pointer
        axil_master_inst.init_write(0*32+8,  struct.pack('<L', 0x80000004)) # active, log size

        axil_master_inst.init_write(1*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(1*32+0,  struct.pack('<Q', 0x5555555555010000)) # address
        axil_master_inst.init_write(1*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(1*32+12, struct.pack('<L', 0x00000001)) # completion queue index
        axil_master_inst.init_write(1*32+16, struct.pack('<L', 0x0000fff0)) # head pointer
        axil_master_inst.init_write(1*32+24, struct.pack('<L', 0x0000fff0)) # tail pointer
        axil_master_inst.init_write(1*32+8,  struct.pack('<L', 0x80000004)) # active, log size

        axil_master_inst.init_write(2*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(2*32+0,  struct.pack('<Q', 0x5555555555020000)) # address
        axil_master_inst.init_write(2*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(2*32+12, struct.pack('<L', 0x00000002)) # completion queue index
        axil_master_inst.init_write(2*32+16, struct.pack('<L', 0x0000fff0)) # head pointer
        axil_master_inst.init_write(2*32+24, struct.pack('<L', 0x0000fff0)) # tail pointer
        axil_master_inst.init_write(2*32+8,  struct.pack('<L', 0x80000004)) # active, log size

        axil_master_inst.init_write(3*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(3*32+0,  struct.pack('<Q', 0x5555555555030000)) # address
        axil_master_inst.init_write(3*32+8,  struct.pack('<L', 0x00000004)) # active, log size
        axil_master_inst.init_write(3*32+12, struct.pack('<L', 0x00000003)) # completion queue index
        axil_master_inst.init_write(3*32+16, struct.pack('<L', 0x0000fff0)) # head pointer
        axil_master_inst.init_write(3*32+24, struct.pack('<L', 0x0000fff0)) # tail pointer
        axil_master_inst.init_write(3*32+8,  struct.pack('<L', 0x80000004)) # active, log size

        yield axil_master_inst.wait()
        yield clk.posedge

        yield delay(100)

        yield clk.posedge
        print("test 4: multiple enqueue and dequeue")
        current_test.next = 4

        current_tag = 1

        queue_head_ptr = [0xfff0]*4
        queue_tail_ptr = [0xfff0]*4
        queue_depth = [0]*4
        queue_uncommit_depth = [0]*4

        commit_list = []

        random.seed(123456)

        for i in range(50):
            # enqueue
            for k in range(random.randrange(8)):
                q = random.randrange(4)

                if queue_depth[q] < 16:
                    print("Enqueue into queue %d" % q)

                    # increment head pointer
                    axil_master_inst.init_read(q*32+16, 4) # head pointer
                    yield axil_master_inst.wait()

                    data = axil_master_inst.get_read_data()
                    head_ptr = struct.unpack('<L', data[1])[0]

                    assert head_ptr == queue_head_ptr[q]

                    head_ptr = (head_ptr + 1) & 0xffff

                    queue_head_ptr[q] = head_ptr
                    queue_depth[q] += 1
                    queue_uncommit_depth[q] += 1

                    axil_master_inst.init_write(q*32+16, struct.pack('<L', head_ptr)) # head pointer
                    yield axil_master_inst.wait()

                    # check doorbell event
                    yield doorbell_sink.wait()
                    db = doorbell_sink.recv()
                    assert db.data[0][0] == q

            # dequeue
            for k in range(random.randrange(8)):
                q = random.randrange(4)

                if len(commit_list) < OP_TABLE_SIZE:
                    print("Try dequeue from queue %d" % q)

                    # dequeue request
                    dequeue_req_source.send([(q, current_tag)])

                    yield dequeue_resp_sink.wait()

                    resp = dequeue_resp_sink.recv()
                    print(resp)

                    assert resp.data[0][0] == q
                    assert resp.data[0][1] == queue_tail_ptr[q]
                    assert (resp.data[0][2] >> 16) & 0xf == q
                    assert (resp.data[0][2] >> 4) & 0xf == queue_tail_ptr[q] & 0xf
                    assert resp.data[0][4] == q

                    assert resp.data[0][5] == current_tag # tag
                    assert not resp.data[0][8] # error

                    if queue_uncommit_depth[q]:
                        commit_list.append((q, resp.data[0][6]))
                        queue_tail_ptr[q] = (queue_tail_ptr[q] + 1) & 0xffff
                        queue_uncommit_depth[q] -= 1
                    else:
                        print("Queue was empty")
                        assert resp.data[0][7] # empty

                    current_tag = (current_tag + 1) % 256

            # commit
            #random.shuffle(commit_list)
            for k in range(random.randrange(8)):
                if commit_list:
                    q, t = commit_list.pop(0)

                    print("Commit dequeue from queue %d" % q)

                    # dequeue commit
                    dequeue_commit_source.send([(t,)])

                    queue_depth[q] -= 1

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
