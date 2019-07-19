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
import struct

import axil
import ptp

module = 'tdma_ber'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/tdma_ber_ch.v")
srcs.append("../rtl/tdma_scheduler.v")
srcs.append("../lib/axi/rtl/axil_interconnect.v")
srcs.append("../lib/axi/rtl/arbiter.v")
srcs.append("../lib/axi/rtl/priority_encoder.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    COUNT = 2
    INDEX_WIDTH = 6
    SLICE_WIDTH = 5
    AXIL_DATA_WIDTH = 32
    AXIL_ADDR_WIDTH = INDEX_WIDTH+4+1+(COUNT-1).bit_length()
    AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)
    SCHEDULE_START_S = 0x0
    SCHEDULE_START_NS = 0x0
    SCHEDULE_PERIOD_S = 0
    SCHEDULE_PERIOD_NS = 1000000
    TIMESLOT_PERIOD_S = 0
    TIMESLOT_PERIOD_NS = 100000
    ACTIVE_PERIOD_S = 0
    ACTIVE_PERIOD_NS = 100000

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    phy_tx_clk = Signal(intbv(0)[COUNT:])
    phy_rx_clk = Signal(intbv(0)[COUNT:])
    phy_rx_error_count = Signal(intbv(0)[COUNT*7:])
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
    ptp_ts_96 = Signal(intbv(0)[96:])
    ptp_ts_step = Signal(bool(0))

    # Outputs
    phy_tx_prbs31_enable = Signal(intbv(0)[COUNT:])
    phy_rx_prbs31_enable = Signal(intbv(0)[COUNT:])
    s_axil_awready = Signal(bool(0))
    s_axil_wready = Signal(bool(0))
    s_axil_bresp = Signal(intbv(0)[2:])
    s_axil_bvalid = Signal(bool(0))
    s_axil_arready = Signal(bool(0))
    s_axil_rdata = Signal(intbv(0)[AXIL_DATA_WIDTH:])
    s_axil_rresp = Signal(intbv(0)[2:])
    s_axil_rvalid = Signal(bool(0))

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

    # PTP clock
    ptp_clock = ptp.PtpClock()

    ptp_logic = ptp_clock.create_logic(
        clk,
        rst,
        ts_96=ptp_ts_96
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        phy_tx_clk=phy_tx_clk,
        phy_rx_clk=phy_rx_clk,
        phy_rx_error_count=phy_rx_error_count,
        phy_tx_prbs31_enable=phy_tx_prbs31_enable,
        phy_rx_prbs31_enable=phy_rx_prbs31_enable,
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
        ptp_ts_96=ptp_ts_96,
        ptp_ts_step=ptp_ts_step
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    @always(delay(3))
    def clkgen2():
        phy_tx_clk.next = ~phy_tx_clk
        phy_rx_clk.next = ~phy_rx_clk

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

        yield clk.posedge
        print("test 1: Test pulse out")
        current_test.next = 1

        axil_master_inst.init_write(0x0110, struct.pack('<LLLL', 0,  500, 0, 0))
        axil_master_inst.init_write(0x0120, struct.pack('<LLLL', 0, 2000, 0, 0))
        axil_master_inst.init_write(0x0130, struct.pack('<LLLL', 0,  400, 0, 0))
        axil_master_inst.init_write(0x0140, struct.pack('<LLLL', 0,  300, 0, 0))
        axil_master_inst.init_write(0x0100, struct.pack('<L', 0x00000001))

        yield delay(10000)

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
