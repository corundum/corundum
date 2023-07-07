#!/usr/bin/env python
# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2020 The Regents of the University of California

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


EnqueueReqBus, EnqueueReqTransaction, EnqueueReqSource, EnqueueReqSink, EnqueueReqMonitor = define_stream("EnqueueReq",
    signals=["queue", "tag", "valid"],
    optional_signals=["ready"]
)

EnqueueRespBus, EnqueueRespTransaction, EnqueueRespSource, EnqueueRespSink, EnqueueRespMonitor = define_stream("EnqueueResp",
    signals=["queue", "ptr", "phase", "addr", "event", "tag", "op_tag", "full", "error", "valid"],
    optional_signals=["ready"]
)

EnqueueCommitBus, EnqueueCommitTransaction, EnqueueCommitSource, EnqueueCommitSink, EnqueueCommitMonitor = define_stream("EnqueueCommit",
    signals=["op_tag", "valid"],
    optional_signals=["ready"]
)

EventBus, EventTransaction, EventSource, EventSink, EventMonitor = define_stream("Event",
    signals=["event", "event_source", "event_valid"],
    optional_signals=["event_ready"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)

        self.enqueue_req_source = EnqueueReqSource(EnqueueReqBus.from_prefix(dut, "s_axis_enqueue_req"), dut.clk, dut.rst)
        self.enqueue_resp_sink = EnqueueRespSink(EnqueueRespBus.from_prefix(dut, "m_axis_enqueue_resp"), dut.clk, dut.rst)
        self.enqueue_commit_source = EnqueueCommitSource(EnqueueCommitBus.from_prefix(dut, "s_axis_enqueue_commit"), dut.clk, dut.rst)
        self.event_sink = EventSink(EventBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

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
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


MQNIC_CQ_BASE_ADDR_VF_REG  = 0x00
MQNIC_CQ_CTRL_STATUS_REG   = 0x08
MQNIC_CQ_PTR_REG           = 0x0C
MQNIC_CQ_PROD_PTR_REG      = 0x0C
MQNIC_CQ_CONS_PTR_REG      = 0x0E

MQNIC_CQ_ENABLE_MASK  = 0x00010000
MQNIC_CQ_ARM_MASK     = 0x00020000
MQNIC_CQ_ACTIVE_MASK  = 0x00080000
MQNIC_CQ_PTR_MASK     = 0xFFFF

MQNIC_CQ_CMD_SET_VF_ID         = 0x80010000
MQNIC_CQ_CMD_SET_SIZE          = 0x80020000
MQNIC_CQ_CMD_SET_EQN           = 0xC0000000
MQNIC_CQ_CMD_SET_PROD_PTR      = 0x80800000
MQNIC_CQ_CMD_SET_CONS_PTR      = 0x80900000
MQNIC_CQ_CMD_SET_CONS_PTR_ARM  = 0x80910000
MQNIC_CQ_CMD_SET_ENABLE        = 0x40000100
MQNIC_CQ_CMD_SET_ARM           = 0x40000200


async def run_test(dut):

    OP_TABLE_SIZE = int(os.getenv("PARAM_OP_TABLE_SIZE"))

    tb = TB(dut)

    await tb.reset()

    dut.enable.value = 1

    tb.log.info("Test read and write queue configuration registers")

    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_ENABLE | 0)
    await tb.axil_master.write_qword(0*16+MQNIC_CQ_BASE_ADDR_VF_REG, 0x8877665544332000)
    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_VF_ID | 0)
    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_SIZE | 4)
    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_EQN | 1)
    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_PROD_PTR | 0)
    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_CONS_PTR_ARM | 0)
    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_ENABLE | 1)

    assert await tb.axil_master.read_qword(0*16+MQNIC_CQ_BASE_ADDR_VF_REG) == 0x8877665544332000
    assert await tb.axil_master.read_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG) == (4 << 28) | MQNIC_CQ_ENABLE_MASK | MQNIC_CQ_ARM_MASK | 1

    tb.log.info("Test enqueue and dequeue")

    # read producer pointer
    prod_ptr = (await tb.axil_master.read_dword(0*16+MQNIC_CQ_PTR_REG)) >> 16
    tb.log.info("Producer pointer: %d", prod_ptr)

    # enqueue request
    await tb.enqueue_req_source.send(EnqueueReqTransaction(queue=0, tag=1))

    resp = await tb.enqueue_resp_sink.recv()

    tb.log.info("Enqueue response: %s", resp)

    assert resp.queue == 0
    assert resp.ptr == prod_ptr
    assert resp.phase == ~(resp.ptr >> 4) & 1
    assert resp.addr == 0x8877665544332000
    assert resp.event == 1
    assert resp.tag == 1
    assert not resp.full
    assert not resp.error

    # enqueue commit
    await tb.enqueue_commit_source.send(EnqueueCommitTransaction(op_tag=resp.op_tag))

    await Timer(100, 'ns')

    # check for event
    event = await tb.event_sink.recv()
    tb.log.info("Event: %s", event)

    assert event.event == 1
    assert event.event_source == 0

    # read producer pointer
    new_prod_ptr = (await tb.axil_master.read_dword(0*16+MQNIC_CQ_PTR_REG)) & MQNIC_CQ_PTR_MASK
    tb.log.info("Producer pointer: %d", new_prod_ptr)

    assert new_prod_ptr - prod_ptr == 1

    # increment consumer pointer
    cons_ptr = (await tb.axil_master.read_dword(0*16+MQNIC_CQ_PTR_REG)) >> 16
    cons_ptr += 1
    tb.log.info("Consumer pointer: %d", cons_ptr)
    await tb.axil_master.write_dword(0*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_CONS_PTR | cons_ptr)

    tb.log.info("Test multiple enqueue and dequeue")

    for k in range(4):
        await tb.axil_master.write_dword(k*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_ENABLE | 0)
        await tb.axil_master.write_qword(k*16+MQNIC_CQ_BASE_ADDR_VF_REG, 0x5555555555000000 + 0x10000*k)
        await tb.axil_master.write_dword(k*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_VF_ID | 0)
        await tb.axil_master.write_dword(k*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_SIZE | 4)
        await tb.axil_master.write_dword(k*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_EQN | k)
        await tb.axil_master.write_dword(k*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_PROD_PTR | 0xfff0)
        await tb.axil_master.write_dword(k*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_CONS_PTR_ARM | 0xfff0)
        await tb.axil_master.write_dword(k*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_ENABLE | 1)

    current_tag = 1

    queue_prod_ptr = [0xfff0]*4
    queue_cons_ptr = [0xfff0]*4
    queue_depth = [0]*4
    queue_uncommit_depth = [0]*4

    commit_list = []

    random.seed(123456)

    for i in range(50):
        # enqueue
        for k in range(random.randrange(8)):
            q = random.randrange(4)

            if len(commit_list) < OP_TABLE_SIZE:
                tb.log.info("Try enqueue into queue %d", q)

                # enqueue request
                await tb.enqueue_req_source.send(EnqueueReqTransaction(queue=q, tag=current_tag))

                resp = await tb.enqueue_resp_sink.recv()

                tb.log.info("Enqueue response: %s", resp)

                assert resp.queue == q
                assert resp.ptr == queue_prod_ptr[q]
                assert resp.phase == ~(resp.ptr >> 4) & 1
                assert (resp.addr >> 16) & 0xf == q
                assert (resp.addr >> 4) & 0xf == queue_prod_ptr[q] & 0xf
                assert resp.event == q
                assert resp.tag == current_tag
                assert not resp.error

                if queue_uncommit_depth[q] < 16:
                    commit_list.append((q, resp.op_tag))
                    queue_prod_ptr[q] = (queue_prod_ptr[q] + 1) & MQNIC_CQ_PTR_MASK
                    queue_uncommit_depth[q] += 1
                    assert not resp.full
                else:
                    tb.log.info("Queue was full")
                    assert resp.full

                current_tag = (current_tag + 1) % 256

        # commit
        #random.shuffle(commit_list)
        for k in range(random.randrange(8)):
            if commit_list:
                q, t = commit_list.pop(0)

                tb.log.info("Commit enqueue into queue %d", q)

                # enqueue commit
                await tb.enqueue_commit_source.send(EnqueueCommitTransaction(op_tag=t))

                queue_depth[q] += 1

        # dequeue
        for k in range(random.randrange(8)):
            q = random.randrange(4)

            if queue_depth[q] > 0:
                tb.log.info("Dequeue from queue %d", q)

                # increment consumer pointer
                cons_ptr = (await tb.axil_master.read_dword(q*16+MQNIC_CQ_PTR_REG)) >> 16

                assert cons_ptr == queue_cons_ptr[q]

                cons_ptr = (cons_ptr + 1) & MQNIC_CQ_PTR_MASK

                queue_cons_ptr[q] = cons_ptr
                queue_depth[q] -= 1
                queue_uncommit_depth[q] -= 1

                tb.log.info("Consumer pointer: %d", cons_ptr)
                await tb.axil_master.write_dword(q*16+MQNIC_CQ_CTRL_STATUS_REG, MQNIC_CQ_CMD_SET_CONS_PTR | cons_ptr)

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


def test_cpl_queue_manager(request):
    dut = "cpl_queue_manager"
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
    parameters['EVENT_WIDTH'] = 8
    parameters['QUEUE_PTR_WIDTH'] = 16
    parameters['LOG_QUEUE_SIZE_WIDTH'] = 4
    parameters['CPL_SIZE'] = 16
    parameters['PIPELINE'] = 2
    parameters['AXIL_DATA_WIDTH'] = 32
    parameters['AXIL_ADDR_WIDTH'] = parameters['QUEUE_INDEX_WIDTH'] + 4
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
