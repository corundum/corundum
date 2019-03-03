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

import axis_ep

module = 'pcie_tag_manager'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/priority_encoder.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    PCIE_TAG_COUNT = 256
    PCIE_TAG_WIDTH = (PCIE_TAG_COUNT-1).bit_length()
    PCIE_EXT_TAG_ENABLE = 1

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    m_axis_tag_ready = Signal(bool(0))
    s_axis_tag = Signal(intbv(0)[PCIE_TAG_WIDTH:])
    s_axis_tag_valid = Signal(bool(0))
    ext_tag_enable = Signal(bool(0))

    # Outputs
    m_axis_tag = Signal(intbv(0)[PCIE_TAG_WIDTH:])
    m_axis_tag_valid = Signal(bool(0))
    active_tags = Signal(intbv(0)[PCIE_TAG_COUNT:])

    # sources and sinks
    tag_sink_pause = Signal(bool(1))

    tag_source = axis_ep.AXIStreamSource()

    tag_source_logic = tag_source.create_logic(
        clk,
        rst,
        tdata=s_axis_tag,
        tvalid=s_axis_tag_valid,
        name='tag_source'
    )

    tag_sink = axis_ep.AXIStreamSink()

    tag_sink_logic = tag_sink.create_logic(
        clk,
        rst,
        tdata=m_axis_tag,
        tvalid=m_axis_tag_valid,
        tready=m_axis_tag_ready,
        pause=tag_sink_pause,
        name='tag_sink'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        m_axis_tag=m_axis_tag,
        m_axis_tag_valid=m_axis_tag_valid,
        m_axis_tag_ready=m_axis_tag_ready,
        s_axis_tag=s_axis_tag,
        s_axis_tag_valid=s_axis_tag_valid,
        ext_tag_enable=ext_tag_enable,
        active_tags=active_tags
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

        ext_tag_enable.next = 0

        yield clk.posedge
        print("test 1: activate all tags")
        current_test.next = 1

        tag_sink_pause.next = 0

        yield delay(300)

        tag_sink_pause.next = 1

        for k in range(32):
            assert tag_sink.recv().data[0] == k

        yield delay(100)

        yield clk.posedge
        print("test 2: return and reissue some tags")
        current_test.next = 2

        for k in [2, 4, 6, 8]:
            tag_source.send([k])

        tag_sink_pause.next = 0

        yield delay(100)

        tag_sink_pause.next = 1

        for k in [2, 4, 6, 8]:
            assert tag_sink.recv().data[0] == k

        yield delay(100)

        yield clk.posedge
        print("test 3: activate all extended tags")
        current_test.next = 3

        rst.next = 1
        ext_tag_enable.next = 1
        yield clk.posedge
        rst.next = 0

        tag_sink_pause.next = 0

        yield delay(2100)

        tag_sink_pause.next = 1

        for k in range(256):
            assert tag_sink.recv().data[0] == k

        yield delay(100)

        yield clk.posedge
        print("test 4: return and reissue some tags")
        current_test.next = 4

        for k in [10, 20, 30, 40, 50, 60]:
            tag_source.send([k])

        tag_sink_pause.next = 0

        yield delay(100)

        tag_sink_pause.next = 1

        for k in [10, 20, 30, 40, 50, 60]:
            assert tag_sink.recv().data[0] == k

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
