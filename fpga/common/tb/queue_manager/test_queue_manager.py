#!/usr/bin/env python
"""

Copyright 2020, The Regents of the University of California.
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
import random

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotbext.axi.stream import define_stream


DequeueReqBus, DequeueReqTransaction, DequeueReqSource, DequeueReqSink, DequeueReqMonitor = define_stream("DequeueReq",
    signals=["queue", "tag", "valid"],
    optional_signals=["ready"]
)

DequeueRespBus, DequeueRespTransaction, DequeueRespSource, DequeueRespSink, DequeueRespMonitor = define_stream("DequeueResp",
    signals=["queue", "ptr", "addr", "block_size", "cpl", "tag", "op_tag", "empty", "error", "valid"],
    optional_signals=["ready"]
)

DequeueCommitBus, DequeueCommitTransaction, DequeueCommitSource, DequeueCommitSink, DequeueCommitMonitor = define_stream("DequeueCommit",
    signals=["op_tag", "valid"],
    optional_signals=["ready"]
)

DoorbellBus, DoorbellTransaction, DoorbellSource, DoorbellSink, DoorbellMonitor = define_stream("Doorbell",
    signals=["queue", "valid"],
    optional_signals=["ready"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

        self.dequeue_req_source = DequeueReqSource(DequeueReqBus.from_prefix(dut, "s_axis_dequeue_req"), dut.clk, dut.rst)
        self.dequeue_resp_sink = DequeueRespSink(DequeueRespBus.from_prefix(dut, "m_axis_dequeue_resp"), dut.clk, dut.rst)
        self.dequeue_commit_source = DequeueCommitSource(DequeueCommitBus.from_prefix(dut, "s_axis_dequeue_commit"), dut.clk, dut.rst)
        self.doorbell_sink = DoorbellSink(DoorbellBus.from_prefix(dut, "m_axis_doorbell"), dut.clk, dut.rst)

        dut.enable.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test(dut):

    OP_TABLE_SIZE = int(os.getenv("PARAM_OP_TABLE_SIZE"))

    tb = TB(dut)

    await tb.reset()

    dut.enable <= 1

    tb.log.info("Test read and write queue configuration registers")

    await tb.axil_master.write_qword(0*32+0,  0x8877665544332211)  # address
    await tb.axil_master.write_dword(0*32+8,  0x00000004)  # active, log size
    await tb.axil_master.write_dword(0*32+12, 0x00000001)  # completion queue index
    await tb.axil_master.write_dword(0*32+16, 0x00000000)  # head pointer
    await tb.axil_master.write_dword(0*32+24, 0x00000000)  # tail pointer
    await tb.axil_master.write_dword(0*32+8,  0x80000004)  # active, log size

    assert await tb.axil_master.read_qword(0*32+0) == 0x8877665544332211
    assert await tb.axil_master.read_dword(0*32+8) == 0x80000004
    assert await tb.axil_master.read_dword(0*32+12) == 0x00000001

    tb.log.info("Test enqueue and dequeue")

    # increment head pointer
    head_ptr = await tb.axil_master.read_dword(0*32+16)  # head pointer
    head_ptr += 1
    tb.log.info("Head pointer: %d", head_ptr)
    await tb.axil_master.write_dword(0*32+16, head_ptr)  # head pointer

    # check for doorbell
    db = await tb.doorbell_sink.recv()
    tb.log.info("Doorbell: %s", db)

    assert db.queue == 0

    # read tail pointer
    tail_ptr = await tb.axil_master.read_dword(0*32+24)  # tail pointer
    tb.log.info("Tail pointer: %d", tail_ptr)

    # dequeue request
    await tb.dequeue_req_source.send(DequeueReqTransaction(queue=0, tag=1))

    resp = await tb.dequeue_resp_sink.recv()

    tb.log.info("Dequeue response: %s", resp)

    assert resp.queue == 0
    assert resp.ptr == tail_ptr
    assert resp.addr == 0x8877665544332211
    assert resp.block_size == 0
    assert resp.cpl == 1
    assert resp.tag == 1
    assert not resp.empty
    assert not resp.error

    # dequeue commit
    await tb.dequeue_commit_source.send(DequeueCommitTransaction(op_tag=resp.op_tag))

    await Timer(100, 'ns')

    # read tail pointer
    new_tail_ptr = await tb.axil_master.read_dword(0*32+24)  # tail pointer
    tb.log.info("Tail pointer: %d", new_tail_ptr)

    assert new_tail_ptr - tail_ptr == 1

    tb.log.info("Test multiple enqueue and dequeue")

    for k in range(4):
        await tb.axil_master.write_dword(k*32+8,  0x00000004)  # active, log size
        await tb.axil_master.write_qword(k*32+0,  0x5555555555000000 + 0x10000*k)  # address
        await tb.axil_master.write_dword(k*32+8,  0x00000004)  # active, log size
        await tb.axil_master.write_dword(k*32+12, 0x00000000 + k)  # completion queue index
        await tb.axil_master.write_dword(k*32+16, 0x0000fff0)  # head pointer
        await tb.axil_master.write_dword(k*32+24, 0x0000fff0)  # tail pointer
        await tb.axil_master.write_dword(k*32+8,  0x80000004)  # active, log size

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
                tb.log.info("Enqueue into queue %d", q)

                # increment head pointer
                head_ptr = await tb.axil_master.read_dword(q*32+16)  # head pointer

                assert head_ptr == queue_head_ptr[q]

                head_ptr = (head_ptr + 1) & 0xffff

                queue_head_ptr[q] = head_ptr
                queue_depth[q] += 1
                queue_uncommit_depth[q] += 1

                tb.log.info("Head pointer: %d", head_ptr)
                await tb.axil_master.write_dword(q*32+16, head_ptr)  # head pointer

                # check doorbell event
                db = await tb.doorbell_sink.recv()
                tb.log.info("Doorbell: %s", db)

                assert db.queue == q

        # dequeue
        for k in range(random.randrange(8)):
            q = random.randrange(4)

            if len(commit_list) < OP_TABLE_SIZE:
                tb.log.info("Try dequeue from queue %d", q)

                # dequeue request
                await tb.dequeue_req_source.send(DequeueReqTransaction(queue=q, tag=current_tag))

                resp = await tb.dequeue_resp_sink.recv()

                tb.log.info("Dequeue response: %s", resp)

                assert resp.queue == q
                assert resp.ptr == queue_tail_ptr[q]
                assert (resp.addr >> 16) & 0xf == q
                assert (resp.addr >> 4) & 0xf == queue_tail_ptr[q] & 0xf
                assert resp.block_size == 0
                assert resp.cpl == q
                assert resp.tag == current_tag
                assert not resp.error

                if queue_uncommit_depth[q]:
                    commit_list.append((q, resp.op_tag))
                    queue_tail_ptr[q] = (queue_tail_ptr[q] + 1) & 0xffff
                    queue_uncommit_depth[q] -= 1
                    assert not resp.empty
                else:
                    tb.log.info("Queue was empty")
                    assert resp.empty

                current_tag = (current_tag + 1) % 256

        # commit
        #random.shuffle(commit_list)
        for k in range(random.randrange(8)):
            if commit_list:
                q, t = commit_list.pop(0)

                tb.log.info("Commit dequeue from queue %d", q)

                # dequeue commit
                await tb.dequeue_commit_source.send(DequeueCommitTransaction(op_tag=t))

                queue_depth[q] -= 1

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if cocotb.SIM_NAME:

    factory = TestFactory(run_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
axi_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axi', 'rtl'))
axis_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axis', 'rtl'))
eth_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'eth', 'rtl'))
pcie_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'pcie', 'rtl'))


def test_queue_manager(request):
    dut = "queue_manager"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['ADDR_WIDTH'] = 64
    parameters['REQ_TAG_WIDTH'] = 8
    parameters['OP_TABLE_SIZE'] = 16
    parameters['OP_TAG_WIDTH'] = 8
    parameters['QUEUE_INDEX_WIDTH'] = 8
    parameters['CPL_INDEX_WIDTH'] = 8
    parameters['QUEUE_PTR_WIDTH'] = 16
    parameters['LOG_QUEUE_SIZE_WIDTH'] = 4
    parameters['DESC_SIZE'] = 16
    parameters['LOG_BLOCK_SIZE_WIDTH'] = 2
    parameters['PIPELINE'] = 2
    parameters['AXIL_DATA_WIDTH'] = 32
    parameters['AXIL_ADDR_WIDTH'] = 16
    parameters['AXIL_STRB_WIDTH'] = parameters['AXIL_DATA_WIDTH'] // 8

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
