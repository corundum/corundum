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


DequeueReqBus, DequeueReqTransaction, DequeueReqSource, DequeueReqSink, DequeueReqMonitor = define_stream("DequeueReq",
    signals=["queue", "tag", "valid"],
    optional_signals=["ready"]
)

DequeueRespBus, DequeueRespTransaction, DequeueRespSource, DequeueRespSink, DequeueRespMonitor = define_stream("DequeueResp",
    signals=["queue", "ptr", "phase", "addr", "block_size", "cpl", "tag", "op_tag", "empty", "error", "valid"],
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
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


MQNIC_QUEUE_BASE_ADDR_VF_REG  = 0x00
MQNIC_QUEUE_CTRL_STATUS_REG   = 0x08
MQNIC_QUEUE_SIZE_CQN_REG      = 0x0C
MQNIC_QUEUE_PTR_REG           = 0x10
MQNIC_QUEUE_PROD_PTR_REG      = 0x10
MQNIC_QUEUE_CONS_PTR_REG      = 0x12

MQNIC_QUEUE_ENABLE_MASK  = 0x00000001
MQNIC_QUEUE_ACTIVE_MASK  = 0x00000008
MQNIC_QUEUE_PTR_MASK     = 0xFFFF

MQNIC_QUEUE_CMD_SET_VF_ID     = 0x80010000
MQNIC_QUEUE_CMD_SET_SIZE      = 0x80020000
MQNIC_QUEUE_CMD_SET_CQN       = 0xC0000000
MQNIC_QUEUE_CMD_SET_PROD_PTR  = 0x80800000
MQNIC_QUEUE_CMD_SET_CONS_PTR  = 0x80900000
MQNIC_QUEUE_CMD_SET_ENABLE    = 0x40000100


async def run_test(dut):

    OP_TABLE_SIZE = int(os.getenv("PARAM_OP_TABLE_SIZE"))

    tb = TB(dut)

    await tb.reset()

    dut.enable.value = 1

    tb.log.info("Test read and write queue configuration registers")

    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_ENABLE | 0)
    await tb.axil_master.write_qword(0*32+MQNIC_QUEUE_BASE_ADDR_VF_REG, 0x8877665544332000)
    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_VF_ID | 0)
    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_SIZE | 4)
    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_CQN | 1)
    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_PROD_PTR | 0)
    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_CONS_PTR | 0)
    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_ENABLE | 1)

    assert await tb.axil_master.read_qword(0*32+MQNIC_QUEUE_BASE_ADDR_VF_REG) == 0x8877665544332000
    assert await tb.axil_master.read_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG) == MQNIC_QUEUE_ENABLE_MASK
    assert await tb.axil_master.read_dword(0*32+MQNIC_QUEUE_SIZE_CQN_REG) == 0x04000001

    tb.log.info("Test enqueue and dequeue")

    # increment producer pointer
    prod_ptr = (await tb.axil_master.read_dword(0*32+MQNIC_QUEUE_PTR_REG)) & MQNIC_QUEUE_PTR_MASK
    prod_ptr += 1
    tb.log.info("Producer pointer: %d", prod_ptr)
    await tb.axil_master.write_dword(0*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_PROD_PTR | prod_ptr)

    # check for doorbell
    db = await tb.doorbell_sink.recv()
    tb.log.info("Doorbell: %s", db)

    assert db.queue == 0

    # read consumer pointer
    cons_ptr = (await tb.axil_master.read_dword(0*32+MQNIC_QUEUE_PTR_REG)) >> 16
    tb.log.info("Consumer pointer: %d", cons_ptr)

    # dequeue request
    await tb.dequeue_req_source.send(DequeueReqTransaction(queue=0, tag=1))

    resp = await tb.dequeue_resp_sink.recv()

    tb.log.info("Dequeue response: %s", resp)

    assert resp.queue == 0
    assert resp.ptr == cons_ptr
    assert resp.phase == ~(resp.ptr >> 4) & 1
    assert resp.addr == 0x8877665544332000
    assert resp.block_size == 0
    assert resp.cpl == 1
    assert resp.tag == 1
    assert not resp.empty
    assert not resp.error

    # dequeue commit
    await tb.dequeue_commit_source.send(DequeueCommitTransaction(op_tag=resp.op_tag))

    await Timer(100, 'ns')

    # read consumer pointer
    new_cons_ptr = (await tb.axil_master.read_dword(0*32+MQNIC_QUEUE_PTR_REG)) >> 16
    tb.log.info("Consumer pointer: %d", new_cons_ptr)

    assert new_cons_ptr - cons_ptr == 1

    tb.log.info("Test multiple enqueue and dequeue")

    for k in range(4):
        await tb.axil_master.write_dword(k*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_ENABLE | 0)
        await tb.axil_master.write_qword(k*32+MQNIC_QUEUE_BASE_ADDR_VF_REG, 0x5555555555000000 + 0x10000*k)
        await tb.axil_master.write_dword(k*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_VF_ID | 0)
        await tb.axil_master.write_dword(k*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_SIZE | 4)
        await tb.axil_master.write_dword(k*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_CQN | k)
        await tb.axil_master.write_dword(k*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_PROD_PTR | 0xfff0)
        await tb.axil_master.write_dword(k*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_CONS_PTR | 0xfff0)
        await tb.axil_master.write_dword(k*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_ENABLE | 1)

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

            if queue_depth[q] < 16:
                tb.log.info("Enqueue into queue %d", q)

                # increment producer pointer
                prod_ptr = (await tb.axil_master.read_dword(q*32+MQNIC_QUEUE_PTR_REG)) & MQNIC_QUEUE_PTR_MASK

                assert prod_ptr == queue_prod_ptr[q]

                prod_ptr = (prod_ptr + 1) & MQNIC_QUEUE_PTR_MASK

                queue_prod_ptr[q] = prod_ptr
                queue_depth[q] += 1
                queue_uncommit_depth[q] += 1

                tb.log.info("Producer pointer: %d", prod_ptr)
                await tb.axil_master.write_dword(q*32+MQNIC_QUEUE_CTRL_STATUS_REG, MQNIC_QUEUE_CMD_SET_PROD_PTR | prod_ptr)

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
                assert resp.ptr == queue_cons_ptr[q]
                assert resp.phase == ~(resp.ptr >> 4) & 1
                assert (resp.addr >> 16) & 0xf == q
                assert (resp.addr >> 4) & 0xf == queue_cons_ptr[q] & 0xf
                assert resp.block_size == 0
                assert resp.cpl == q
                assert resp.tag == current_tag
                assert not resp.error

                if queue_uncommit_depth[q]:
                    commit_list.append((q, resp.op_tag))
                    queue_cons_ptr[q] = (queue_cons_ptr[q] + 1) & MQNIC_QUEUE_PTR_MASK
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
    parameters['AXIL_ADDR_WIDTH'] = parameters['QUEUE_INDEX_WIDTH'] + 5
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
