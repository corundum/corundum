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

import axi
import math

module = 'axi_crossbar'
testbench = 'test_%s_4x4' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/axi_crossbar_addr.v")
srcs.append("../rtl/axi_crossbar_rd.v")
srcs.append("../rtl/axi_crossbar_wr.v")
srcs.append("../rtl/axi_register_rd.v")
srcs.append("../rtl/axi_register_wr.v")
srcs.append("../rtl/arbiter.v")
srcs.append("../rtl/priority_encoder.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    S_COUNT = 4
    M_COUNT = 4
    DATA_WIDTH = 32
    ADDR_WIDTH = 32
    STRB_WIDTH = (DATA_WIDTH/8)
    S_ID_WIDTH = 8
    M_ID_WIDTH = S_ID_WIDTH+math.ceil(math.log(M_COUNT, 2))
    AWUSER_ENABLE = 0
    AWUSER_WIDTH = 1
    WUSER_ENABLE = 0
    WUSER_WIDTH = 1
    BUSER_ENABLE = 0
    BUSER_WIDTH = 1
    ARUSER_ENABLE = 0
    ARUSER_WIDTH = 1
    RUSER_ENABLE = 0
    RUSER_WIDTH = 1
    S_THREADS = [2]*S_COUNT
    S_ACCEPT = [16]*S_COUNT
    M_REGIONS = 1
    M_BASE_ADDR = [0x00000000, 0x01000000, 0x02000000, 0x03000000]
    M_ADDR_WIDTH = [24]*M_COUNT*M_REGIONS
    M_CONNECT_READ = [0b1111]*M_COUNT
    M_CONNECT_WRITE = [0b1111]*M_COUNT
    M_ISSUE = [4]*M_COUNT
    M_SECURE = [0]*M_COUNT
    S_AW_REG_TYPE = [0]*S_COUNT
    S_W_REG_TYPE = [0]*S_COUNT
    S_B_REG_TYPE = [1]*S_COUNT
    S_AR_REG_TYPE = [0]*S_COUNT
    S_R_REG_TYPE = [1]*S_COUNT
    M_AW_REG_TYPE = [1]*M_COUNT
    M_W_REG_TYPE = [2]*M_COUNT
    M_B_REG_TYPE = [0]*M_COUNT
    M_AR_REG_TYPE = [1]*M_COUNT
    M_R_REG_TYPE = [0]*M_COUNT

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axi_awid_list = [Signal(intbv(0)[S_ID_WIDTH:]) for i in range(S_COUNT)]
    s_axi_awaddr_list = [Signal(intbv(0)[ADDR_WIDTH:]) for i in range(S_COUNT)]
    s_axi_awlen_list = [Signal(intbv(0)[8:]) for i in range(S_COUNT)]
    s_axi_awsize_list = [Signal(intbv(0)[3:]) for i in range(S_COUNT)]
    s_axi_awburst_list = [Signal(intbv(0)[2:]) for i in range(S_COUNT)]
    s_axi_awlock_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axi_awcache_list = [Signal(intbv(0)[4:]) for i in range(S_COUNT)]
    s_axi_awprot_list = [Signal(intbv(0)[3:]) for i in range(S_COUNT)]
    s_axi_awqos_list = [Signal(intbv(0)[4:]) for i in range(S_COUNT)]
    s_axi_awuser_list = [Signal(intbv(0)[AWUSER_WIDTH:]) for i in range(S_COUNT)]
    s_axi_awvalid_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axi_wdata_list = [Signal(intbv(0)[DATA_WIDTH:]) for i in range(S_COUNT)]
    s_axi_wstrb_list = [Signal(intbv(0)[STRB_WIDTH:]) for i in range(S_COUNT)]
    s_axi_wlast_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axi_wuser_list = [Signal(intbv(0)[WUSER_WIDTH:]) for i in range(S_COUNT)]
    s_axi_wvalid_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axi_bready_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axi_arid_list = [Signal(intbv(0)[S_ID_WIDTH:]) for i in range(S_COUNT)]
    s_axi_araddr_list = [Signal(intbv(0)[ADDR_WIDTH:]) for i in range(S_COUNT)]
    s_axi_arlen_list = [Signal(intbv(0)[8:]) for i in range(S_COUNT)]
    s_axi_arsize_list = [Signal(intbv(0)[3:]) for i in range(S_COUNT)]
    s_axi_arburst_list = [Signal(intbv(0)[2:]) for i in range(S_COUNT)]
    s_axi_arlock_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axi_arcache_list = [Signal(intbv(0)[4:]) for i in range(S_COUNT)]
    s_axi_arprot_list = [Signal(intbv(0)[3:]) for i in range(S_COUNT)]
    s_axi_arqos_list = [Signal(intbv(0)[4:]) for i in range(S_COUNT)]
    s_axi_aruser_list = [Signal(intbv(0)[ARUSER_WIDTH:]) for i in range(S_COUNT)]
    s_axi_arvalid_list = [Signal(bool(0)) for i in range(S_COUNT)]
    s_axi_rready_list = [Signal(bool(0)) for i in range(S_COUNT)]
    m_axi_awready_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axi_wready_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axi_bid_list = [Signal(intbv(0)[M_ID_WIDTH:]) for i in range(M_COUNT)]
    m_axi_bresp_list = [Signal(intbv(0)[2:]) for i in range(M_COUNT)]
    m_axi_buser_list = [Signal(intbv(0)[BUSER_WIDTH:]) for i in range(M_COUNT)]
    m_axi_bvalid_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axi_arready_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axi_rid_list = [Signal(intbv(0)[M_ID_WIDTH:]) for i in range(M_COUNT)]
    m_axi_rdata_list = [Signal(intbv(0)[DATA_WIDTH:]) for i in range(M_COUNT)]
    m_axi_rresp_list = [Signal(intbv(0)[2:]) for i in range(M_COUNT)]
    m_axi_rlast_list = [Signal(bool(0)) for i in range(M_COUNT)]
    m_axi_ruser_list = [Signal(intbv(0)[RUSER_WIDTH:]) for i in range(M_COUNT)]
    m_axi_rvalid_list = [Signal(bool(0)) for i in range(M_COUNT)]

    s_axi_awid = ConcatSignal(*reversed(s_axi_awid_list))
    s_axi_awaddr = ConcatSignal(*reversed(s_axi_awaddr_list))
    s_axi_awlen = ConcatSignal(*reversed(s_axi_awlen_list))
    s_axi_awsize = ConcatSignal(*reversed(s_axi_awsize_list))
    s_axi_awburst = ConcatSignal(*reversed(s_axi_awburst_list))
    s_axi_awlock = ConcatSignal(*reversed(s_axi_awlock_list))
    s_axi_awcache = ConcatSignal(*reversed(s_axi_awcache_list))
    s_axi_awprot = ConcatSignal(*reversed(s_axi_awprot_list))
    s_axi_awqos = ConcatSignal(*reversed(s_axi_awqos_list))
    s_axi_awuser = ConcatSignal(*reversed(s_axi_awuser_list))
    s_axi_awvalid = ConcatSignal(*reversed(s_axi_awvalid_list))
    s_axi_wdata = ConcatSignal(*reversed(s_axi_wdata_list))
    s_axi_wstrb = ConcatSignal(*reversed(s_axi_wstrb_list))
    s_axi_wlast = ConcatSignal(*reversed(s_axi_wlast_list))
    s_axi_wuser = ConcatSignal(*reversed(s_axi_wuser_list))
    s_axi_wvalid = ConcatSignal(*reversed(s_axi_wvalid_list))
    s_axi_bready = ConcatSignal(*reversed(s_axi_bready_list))
    s_axi_arid = ConcatSignal(*reversed(s_axi_arid_list))
    s_axi_araddr = ConcatSignal(*reversed(s_axi_araddr_list))
    s_axi_arlen = ConcatSignal(*reversed(s_axi_arlen_list))
    s_axi_arsize = ConcatSignal(*reversed(s_axi_arsize_list))
    s_axi_arburst = ConcatSignal(*reversed(s_axi_arburst_list))
    s_axi_arlock = ConcatSignal(*reversed(s_axi_arlock_list))
    s_axi_arcache = ConcatSignal(*reversed(s_axi_arcache_list))
    s_axi_arprot = ConcatSignal(*reversed(s_axi_arprot_list))
    s_axi_arqos = ConcatSignal(*reversed(s_axi_arqos_list))
    s_axi_aruser = ConcatSignal(*reversed(s_axi_aruser_list))
    s_axi_arvalid = ConcatSignal(*reversed(s_axi_arvalid_list))
    s_axi_rready = ConcatSignal(*reversed(s_axi_rready_list))
    m_axi_awready = ConcatSignal(*reversed(m_axi_awready_list))
    m_axi_wready = ConcatSignal(*reversed(m_axi_wready_list))
    m_axi_bid = ConcatSignal(*reversed(m_axi_bid_list))
    m_axi_bresp = ConcatSignal(*reversed(m_axi_bresp_list))
    m_axi_buser = ConcatSignal(*reversed(m_axi_buser_list))
    m_axi_bvalid = ConcatSignal(*reversed(m_axi_bvalid_list))
    m_axi_arready = ConcatSignal(*reversed(m_axi_arready_list))
    m_axi_rid = ConcatSignal(*reversed(m_axi_rid_list))
    m_axi_rdata = ConcatSignal(*reversed(m_axi_rdata_list))
    m_axi_rresp = ConcatSignal(*reversed(m_axi_rresp_list))
    m_axi_rlast = ConcatSignal(*reversed(m_axi_rlast_list))
    m_axi_ruser = ConcatSignal(*reversed(m_axi_ruser_list))
    m_axi_rvalid = ConcatSignal(*reversed(m_axi_rvalid_list))

    # Outputs
    s_axi_awready = Signal(intbv(0)[S_COUNT:])
    s_axi_wready = Signal(intbv(0)[S_COUNT:])
    s_axi_bid = Signal(intbv(0)[S_COUNT*S_ID_WIDTH:])
    s_axi_bresp = Signal(intbv(0)[S_COUNT*2:])
    s_axi_buser = Signal(intbv(0)[S_COUNT*BUSER_WIDTH:])
    s_axi_bvalid = Signal(intbv(0)[S_COUNT:])
    s_axi_arready = Signal(intbv(0)[S_COUNT:])
    s_axi_rid = Signal(intbv(0)[S_COUNT*S_ID_WIDTH:])
    s_axi_rdata = Signal(intbv(0)[S_COUNT*DATA_WIDTH:])
    s_axi_rresp = Signal(intbv(0)[S_COUNT*2:])
    s_axi_rlast = Signal(intbv(0)[S_COUNT:])
    s_axi_ruser = Signal(intbv(0)[S_COUNT*RUSER_WIDTH:])
    s_axi_rvalid = Signal(intbv(0)[S_COUNT:])
    m_axi_awid = Signal(intbv(0)[M_COUNT*M_ID_WIDTH:])
    m_axi_awaddr = Signal(intbv(0)[M_COUNT*ADDR_WIDTH:])
    m_axi_awlen = Signal(intbv(0)[M_COUNT*8:])
    m_axi_awsize = Signal(intbv(0)[M_COUNT*3:])
    m_axi_awburst = Signal(intbv(0)[M_COUNT*2:])
    m_axi_awlock = Signal(intbv(0)[M_COUNT:])
    m_axi_awcache = Signal(intbv(0)[M_COUNT*4:])
    m_axi_awprot = Signal(intbv(0)[M_COUNT*3:])
    m_axi_awqos = Signal(intbv(0)[M_COUNT*4:])
    m_axi_awregion = Signal(intbv(0)[M_COUNT*4:])
    m_axi_awuser = Signal(intbv(0)[M_COUNT*AWUSER_WIDTH:])
    m_axi_awvalid = Signal(intbv(0)[M_COUNT:])
    m_axi_wdata = Signal(intbv(0)[M_COUNT*DATA_WIDTH:])
    m_axi_wstrb = Signal(intbv(0)[M_COUNT*STRB_WIDTH:])
    m_axi_wlast = Signal(intbv(0)[M_COUNT:])
    m_axi_wuser = Signal(intbv(0)[M_COUNT*WUSER_WIDTH:])
    m_axi_wvalid = Signal(intbv(0)[M_COUNT:])
    m_axi_bready = Signal(intbv(0)[M_COUNT:])
    m_axi_arid = Signal(intbv(0)[M_COUNT*M_ID_WIDTH:])
    m_axi_araddr = Signal(intbv(0)[M_COUNT*ADDR_WIDTH:])
    m_axi_arlen = Signal(intbv(0)[M_COUNT*8:])
    m_axi_arsize = Signal(intbv(0)[M_COUNT*3:])
    m_axi_arburst = Signal(intbv(0)[M_COUNT*2:])
    m_axi_arlock = Signal(intbv(0)[M_COUNT:])
    m_axi_arcache = Signal(intbv(0)[M_COUNT*4:])
    m_axi_arprot = Signal(intbv(0)[M_COUNT*3:])
    m_axi_arqos = Signal(intbv(0)[M_COUNT*4:])
    m_axi_arregion = Signal(intbv(0)[M_COUNT*4:])
    m_axi_aruser = Signal(intbv(0)[M_COUNT*ARUSER_WIDTH:])
    m_axi_arvalid = Signal(intbv(0)[M_COUNT:])
    m_axi_rready = Signal(intbv(0)[M_COUNT:])

    s_axi_awready_list = [s_axi_awready(i) for i in range(S_COUNT)]
    s_axi_wready_list = [s_axi_wready(i) for i in range(S_COUNT)]
    s_axi_bid_list = [s_axi_bid((i+1)*S_ID_WIDTH, i*S_ID_WIDTH) for i in range(S_COUNT)]
    s_axi_bresp_list = [s_axi_bresp((i+1)*2, i*2) for i in range(S_COUNT)]
    s_axi_buser_list = [s_axi_buser((i+1)*BUSER_WIDTH, i*BUSER_WIDTH) for i in range(S_COUNT)]
    s_axi_bvalid_list = [s_axi_bvalid(i) for i in range(S_COUNT)]
    s_axi_arready_list = [s_axi_arready(i) for i in range(S_COUNT)]
    s_axi_rid_list = [s_axi_rid((i+1)*S_ID_WIDTH, i*S_ID_WIDTH) for i in range(S_COUNT)]
    s_axi_rdata_list = [s_axi_rdata((i+1)*DATA_WIDTH, i*DATA_WIDTH) for i in range(S_COUNT)]
    s_axi_rresp_list = [s_axi_rresp((i+1)*2, i*2) for i in range(S_COUNT)]
    s_axi_rlast_list = [s_axi_rlast(i) for i in range(S_COUNT)]
    s_axi_ruser_list = [s_axi_ruser((i+1)*RUSER_WIDTH, i*RUSER_WIDTH) for i in range(S_COUNT)]
    s_axi_rvalid_list = [s_axi_rvalid(i) for i in range(S_COUNT)]
    m_axi_awid_list = [m_axi_awid((i+1)*M_ID_WIDTH, i*M_ID_WIDTH) for i in range(M_COUNT)]
    m_axi_awaddr_list = [m_axi_awaddr((i+1)*ADDR_WIDTH, i*ADDR_WIDTH) for i in range(M_COUNT)]
    m_axi_awlen_list = [m_axi_awlen((i+1)*8, i*8) for i in range(M_COUNT)]
    m_axi_awsize_list = [m_axi_awsize((i+1)*3, i*3) for i in range(M_COUNT)]
    m_axi_awburst_list = [m_axi_awburst((i+1)*2, i*2) for i in range(M_COUNT)]
    m_axi_awlock_list = [m_axi_awlock(i) for i in range(M_COUNT)]
    m_axi_awcache_list = [m_axi_awcache((i+1)*4, i*4) for i in range(M_COUNT)]
    m_axi_awprot_list = [m_axi_awprot((i+1)*3, i*3) for i in range(M_COUNT)]
    m_axi_awqos_list = [m_axi_awqos((i+1)*4, i*4) for i in range(M_COUNT)]
    m_axi_awregion_list = [m_axi_awregion((i+1)*4, i*4) for i in range(M_COUNT)]
    m_axi_awuser_list = [m_axi_awuser((i+1)*AWUSER_WIDTH, i*AWUSER_WIDTH) for i in range(M_COUNT)]
    m_axi_awvalid_list = [m_axi_awvalid(i) for i in range(M_COUNT)]
    m_axi_wdata_list = [m_axi_wdata((i+1)*DATA_WIDTH, i*DATA_WIDTH) for i in range(M_COUNT)]
    m_axi_wstrb_list = [m_axi_wstrb((i+1)*STRB_WIDTH, i*STRB_WIDTH) for i in range(M_COUNT)]
    m_axi_wlast_list = [m_axi_wlast(i) for i in range(M_COUNT)]
    m_axi_wuser_list = [m_axi_wuser((i+1)*WUSER_WIDTH, i*WUSER_WIDTH) for i in range(M_COUNT)]
    m_axi_wvalid_list = [m_axi_wvalid(i) for i in range(M_COUNT)]
    m_axi_bready_list = [m_axi_bready(i) for i in range(M_COUNT)]
    m_axi_arid_list = [m_axi_arid((i+1)*M_ID_WIDTH, i*M_ID_WIDTH) for i in range(M_COUNT)]
    m_axi_araddr_list = [m_axi_araddr((i+1)*ADDR_WIDTH, i*ADDR_WIDTH) for i in range(M_COUNT)]
    m_axi_arlen_list = [m_axi_arlen((i+1)*8, i*8) for i in range(M_COUNT)]
    m_axi_arsize_list = [m_axi_arsize((i+1)*3, i*3) for i in range(M_COUNT)]
    m_axi_arburst_list = [m_axi_arburst((i+1)*2, i*2) for i in range(M_COUNT)]
    m_axi_arlock_list = [m_axi_arlock(i) for i in range(M_COUNT)]
    m_axi_arcache_list = [m_axi_arcache((i+1)*4, i*4) for i in range(M_COUNT)]
    m_axi_arprot_list = [m_axi_arprot((i+1)*3, i*3) for i in range(M_COUNT)]
    m_axi_arqos_list = [m_axi_arqos((i+1)*4, i*4) for i in range(M_COUNT)]
    m_axi_arregion_list = [m_axi_arregion((i+1)*4, i*4) for i in range(M_COUNT)]
    m_axi_aruser_list = [m_axi_aruser((i+1)*ARUSER_WIDTH, i*ARUSER_WIDTH) for i in range(M_COUNT)]
    m_axi_arvalid_list = [m_axi_arvalid(i) for i in range(M_COUNT)]
    m_axi_rready_list = [m_axi_rready(i) for i in range(M_COUNT)]

    # AXI4 masters
    axi_master_inst_list = []
    axi_master_pause_list = []
    axi_master_logic = []

    for k in range(S_COUNT):
        m = axi.AXIMaster()
        p = Signal(bool(False))

        axi_master_inst_list.append(m)
        axi_master_pause_list.append(p)

        axi_master_logic.append(m.create_logic(
            clk,
            rst,
            m_axi_awid=s_axi_awid_list[k],
            m_axi_awaddr=s_axi_awaddr_list[k],
            m_axi_awlen=s_axi_awlen_list[k],
            m_axi_awsize=s_axi_awsize_list[k],
            m_axi_awburst=s_axi_awburst_list[k],
            m_axi_awlock=s_axi_awlock_list[k],
            m_axi_awcache=s_axi_awcache_list[k],
            m_axi_awprot=s_axi_awprot_list[k],
            m_axi_awqos=s_axi_awqos_list[k],
            m_axi_awvalid=s_axi_awvalid_list[k],
            m_axi_awready=s_axi_awready_list[k],
            m_axi_wdata=s_axi_wdata_list[k],
            m_axi_wstrb=s_axi_wstrb_list[k],
            m_axi_wlast=s_axi_wlast_list[k],
            m_axi_wvalid=s_axi_wvalid_list[k],
            m_axi_wready=s_axi_wready_list[k],
            m_axi_bid=s_axi_bid_list[k],
            m_axi_bresp=s_axi_bresp_list[k],
            m_axi_bvalid=s_axi_bvalid_list[k],
            m_axi_bready=s_axi_bready_list[k],
            m_axi_arid=s_axi_arid_list[k],
            m_axi_araddr=s_axi_araddr_list[k],
            m_axi_arlen=s_axi_arlen_list[k],
            m_axi_arsize=s_axi_arsize_list[k],
            m_axi_arburst=s_axi_arburst_list[k],
            m_axi_arlock=s_axi_arlock_list[k],
            m_axi_arcache=s_axi_arcache_list[k],
            m_axi_arprot=s_axi_arprot_list[k],
            m_axi_arqos=s_axi_arqos_list[k],
            m_axi_arvalid=s_axi_arvalid_list[k],
            m_axi_arready=s_axi_arready_list[k],
            m_axi_rid=s_axi_rid_list[k],
            m_axi_rdata=s_axi_rdata_list[k],
            m_axi_rresp=s_axi_rresp_list[k],
            m_axi_rlast=s_axi_rlast_list[k],
            m_axi_rvalid=s_axi_rvalid_list[k],
            m_axi_rready=s_axi_rready_list[k],
            pause=p,
            name='master_%d' % k
        ))

    # AXI4 RAM models
    axi_ram_inst_list = []
    axi_ram_pause_list = []
    axi_ram_logic = []

    for k in range(M_COUNT):
        r = axi.AXIRam(2**16)
        p = Signal(bool(False))

        axi_ram_inst_list.append(r)
        axi_ram_pause_list.append(p)

        axi_ram_logic.append(r.create_port(
            clk,
            s_axi_awid=m_axi_awid_list[k],
            s_axi_awaddr=m_axi_awaddr_list[k],
            s_axi_awlen=m_axi_awlen_list[k],
            s_axi_awsize=m_axi_awsize_list[k],
            s_axi_awburst=m_axi_awburst_list[k],
            s_axi_awlock=m_axi_awlock_list[k],
            s_axi_awcache=m_axi_awcache_list[k],
            s_axi_awprot=m_axi_awprot_list[k],
            s_axi_awvalid=m_axi_awvalid_list[k],
            s_axi_awready=m_axi_awready_list[k],
            s_axi_wdata=m_axi_wdata_list[k],
            s_axi_wstrb=m_axi_wstrb_list[k],
            s_axi_wlast=m_axi_wlast_list[k],
            s_axi_wvalid=m_axi_wvalid_list[k],
            s_axi_wready=m_axi_wready_list[k],
            s_axi_bid=m_axi_bid_list[k],
            s_axi_bresp=m_axi_bresp_list[k],
            s_axi_bvalid=m_axi_bvalid_list[k],
            s_axi_bready=m_axi_bready_list[k],
            s_axi_arid=m_axi_arid_list[k],
            s_axi_araddr=m_axi_araddr_list[k],
            s_axi_arlen=m_axi_arlen_list[k],
            s_axi_arsize=m_axi_arsize_list[k],
            s_axi_arburst=m_axi_arburst_list[k],
            s_axi_arlock=m_axi_arlock_list[k],
            s_axi_arcache=m_axi_arcache_list[k],
            s_axi_arprot=m_axi_arprot_list[k],
            s_axi_arvalid=m_axi_arvalid_list[k],
            s_axi_arready=m_axi_arready_list[k],
            s_axi_rid=m_axi_rid_list[k],
            s_axi_rdata=m_axi_rdata_list[k],
            s_axi_rresp=m_axi_rresp_list[k],
            s_axi_rlast=m_axi_rlast_list[k],
            s_axi_rvalid=m_axi_rvalid_list[k],
            s_axi_rready=m_axi_rready_list[k],
            pause=p,
            name='ram_%d' % k
        ))

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        s_axi_awid=s_axi_awid,
        s_axi_awaddr=s_axi_awaddr,
        s_axi_awlen=s_axi_awlen,
        s_axi_awsize=s_axi_awsize,
        s_axi_awburst=s_axi_awburst,
        s_axi_awlock=s_axi_awlock,
        s_axi_awcache=s_axi_awcache,
        s_axi_awprot=s_axi_awprot,
        s_axi_awqos=s_axi_awqos,
        s_axi_awuser=s_axi_awuser,
        s_axi_awvalid=s_axi_awvalid,
        s_axi_awready=s_axi_awready,
        s_axi_wdata=s_axi_wdata,
        s_axi_wstrb=s_axi_wstrb,
        s_axi_wlast=s_axi_wlast,
        s_axi_wuser=s_axi_wuser,
        s_axi_wvalid=s_axi_wvalid,
        s_axi_wready=s_axi_wready,
        s_axi_bid=s_axi_bid,
        s_axi_bresp=s_axi_bresp,
        s_axi_buser=s_axi_buser,
        s_axi_bvalid=s_axi_bvalid,
        s_axi_bready=s_axi_bready,
        s_axi_arid=s_axi_arid,
        s_axi_araddr=s_axi_araddr,
        s_axi_arlen=s_axi_arlen,
        s_axi_arsize=s_axi_arsize,
        s_axi_arburst=s_axi_arburst,
        s_axi_arlock=s_axi_arlock,
        s_axi_arcache=s_axi_arcache,
        s_axi_arprot=s_axi_arprot,
        s_axi_arqos=s_axi_arqos,
        s_axi_aruser=s_axi_aruser,
        s_axi_arvalid=s_axi_arvalid,
        s_axi_arready=s_axi_arready,
        s_axi_rid=s_axi_rid,
        s_axi_rdata=s_axi_rdata,
        s_axi_rresp=s_axi_rresp,
        s_axi_rlast=s_axi_rlast,
        s_axi_ruser=s_axi_ruser,
        s_axi_rvalid=s_axi_rvalid,
        s_axi_rready=s_axi_rready,
        m_axi_awid=m_axi_awid,
        m_axi_awaddr=m_axi_awaddr,
        m_axi_awlen=m_axi_awlen,
        m_axi_awsize=m_axi_awsize,
        m_axi_awburst=m_axi_awburst,
        m_axi_awlock=m_axi_awlock,
        m_axi_awcache=m_axi_awcache,
        m_axi_awprot=m_axi_awprot,
        m_axi_awqos=m_axi_awqos,
        m_axi_awregion=m_axi_awregion,
        m_axi_awuser=m_axi_awuser,
        m_axi_awvalid=m_axi_awvalid,
        m_axi_awready=m_axi_awready,
        m_axi_wdata=m_axi_wdata,
        m_axi_wstrb=m_axi_wstrb,
        m_axi_wlast=m_axi_wlast,
        m_axi_wuser=m_axi_wuser,
        m_axi_wvalid=m_axi_wvalid,
        m_axi_wready=m_axi_wready,
        m_axi_bid=m_axi_bid,
        m_axi_bresp=m_axi_bresp,
        m_axi_buser=m_axi_buser,
        m_axi_bvalid=m_axi_bvalid,
        m_axi_bready=m_axi_bready,
        m_axi_arid=m_axi_arid,
        m_axi_araddr=m_axi_araddr,
        m_axi_arlen=m_axi_arlen,
        m_axi_arsize=m_axi_arsize,
        m_axi_arburst=m_axi_arburst,
        m_axi_arlock=m_axi_arlock,
        m_axi_arcache=m_axi_arcache,
        m_axi_arprot=m_axi_arprot,
        m_axi_arqos=m_axi_arqos,
        m_axi_arregion=m_axi_arregion,
        m_axi_aruser=m_axi_aruser,
        m_axi_arvalid=m_axi_arvalid,
        m_axi_arready=m_axi_arready,
        m_axi_rid=m_axi_rid,
        m_axi_rdata=m_axi_rdata,
        m_axi_rresp=m_axi_rresp,
        m_axi_rlast=m_axi_rlast,
        m_axi_ruser=m_axi_ruser,
        m_axi_rvalid=m_axi_rvalid,
        m_axi_rready=m_axi_rready
    )

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    def wait_normal():
        while not all([axi_master_inst_list[k].idle() for k in range(S_COUNT)]):
            yield clk.posedge

    def wait_pause_master():
        while not all([axi_master_inst_list[k].idle() for k in range(S_COUNT)]):
            for k in range(S_COUNT):
                axi_master_pause_list[k].next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            for k in range(S_COUNT):
                axi_master_pause_list[k].next = False
            yield clk.posedge

    def wait_pause_slave():
        while not all([axi_master_inst_list[k].idle() for k in range(S_COUNT)]):
            for k in range(M_COUNT):
                axi_ram_pause_list[k].next = True
            yield clk.posedge
            yield clk.posedge
            yield clk.posedge
            for k in range(M_COUNT):
                axi_ram_pause_list[k].next = False
            yield clk.posedge

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
        print("test 1: write")
        current_test.next = 1

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axi_master_inst_list[0].init_write(addr, test_data)

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        data = axi_ram_inst_list[0].read_mem(addr&0xffffff80, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert axi_ram_inst_list[0].read_mem(addr, len(test_data)) == test_data

        yield delay(100)

        yield clk.posedge
        print("test 2: read")
        current_test.next = 2

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        axi_ram_inst_list[0].write_mem(addr, test_data)

        axi_master_inst_list[0].init_read(addr, len(test_data))

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        data = axi_master_inst_list[0].get_read_data()
        assert data[0] == addr
        assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 3: one to many")
        current_test.next = 3

        addr = 4
        test_data = b'\x11\x22\x33\x44'

        for k in range(S_COUNT):
            axi_master_inst_list[0].init_write(addr+M_BASE_ADDR[k], test_data)

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        for k in range(S_COUNT):
            data = axi_ram_inst_list[k].read_mem(addr&0xffffff80, 32)
            for i in range(0, len(data), 16):
                print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        for k in range(S_COUNT):
            assert axi_ram_inst_list[k].read_mem(addr, len(test_data)) == test_data

        for k in range(S_COUNT):
            axi_master_inst_list[0].init_read(addr+M_BASE_ADDR[k], len(test_data))

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        for k in range(S_COUNT):
            data = axi_master_inst_list[0].get_read_data()
            assert data[0] == addr+M_BASE_ADDR[k]
            assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 4: many to one")
        current_test.next = 4

        for k in range(M_COUNT):
            axi_master_inst_list[k].init_write(k*4, bytearray([(k+1)*17]*4))

        for k in range(M_COUNT):
            yield axi_master_inst_list[k].wait()
        yield clk.posedge

        data = axi_ram_inst_list[0].read_mem(addr&0xffffff80, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        for k in range(M_COUNT):
            assert axi_ram_inst_list[0].read_mem(k*4, 4) == bytearray([(k+1)*17]*4)

        for k in range(M_COUNT):
            axi_master_inst_list[k].init_read(k*4, 4)

        for k in range(M_COUNT):
            yield axi_master_inst_list[k].wait()
        yield clk.posedge

        for k in range(M_COUNT):
            data = axi_master_inst_list[k].get_read_data()
            assert data[0] == k*4
            assert data[1] == bytearray([(k+1)*17]*4)

        yield delay(100)

        yield clk.posedge
        print("test 10: transaction limit and ordering test")
        current_test.next = 10

        length = 256
        test_data = bytearray([x%256 for x in range(length)])

        for k in range(10):
            axi_master_inst_list[0].init_write(length*k+M_BASE_ADDR[0], bytearray([k+1]*length))

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        for k in range(10):
            data = axi_ram_inst_list[0].read_mem((length*k)&0xffffff80, 32)
            for i in range(0, len(data), 16):
                print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        for k in range(10):
            assert axi_ram_inst_list[0].read_mem(length*k, length) == bytearray([k+1]*length)

        for k in range(10):
            axi_master_inst_list[0].init_read(length*k+M_BASE_ADDR[0], length)

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        for k in range(10):
            data = axi_master_inst_list[0].get_read_data()
            assert data[0] == length*k+M_BASE_ADDR[0]
            assert data[1] == bytearray([k+1]*length)

        yield delay(100)

        yield clk.posedge
        print("test 5: various writes")
        current_test.next = 5

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for wait in wait_normal, wait_pause_master, wait_pause_slave:
                    print("length %d, offset %d"% (length, offset))
                    #addr = 256*(16*offset+length)+offset
                    addr = offset
                    test_data = bytearray([x%256 for x in range(length)])

                    axi_ram_inst_list[0].write_mem(addr&0xffffff80, b'\xAA'*(length+256))
                    axi_master_inst_list[0].init_write(addr, test_data)

                    yield wait()
                    yield clk.posedge

                    data = axi_ram_inst_list[0].read_mem(addr&0xffffff80, 32)
                    for i in range(0, len(data), 16):
                        print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                    assert axi_ram_inst_list[0].read_mem(addr, length) == test_data
                    assert axi_ram_inst_list[0].read_mem(addr-1, 1) == b'\xAA'
                    assert axi_ram_inst_list[0].read_mem(addr+length, 1) == b'\xAA'

        yield delay(100)

        yield clk.posedge
        print("test 6: various reads")
        current_test.next = 6

        for length in list(range(1,8))+[1024]:
            for offset in list(range(4,8))+[4096-4]:
                for wait in wait_normal, wait_pause_master, wait_pause_slave:
                    print("length %d, offset %d"% (length, offset))
                    #addr = 256*(16*offset+length)+offset
                    addr = offset
                    test_data = bytearray([x%256 for x in range(length)])

                    axi_ram_inst_list[0].write_mem(addr, test_data)

                    axi_master_inst_list[0].init_read(addr, length)

                    yield wait()
                    yield clk.posedge

                    data = axi_master_inst_list[0].get_read_data()
                    assert data[0] == addr
                    assert data[1] == test_data

        yield delay(100)

        yield clk.posedge
        print("test 7: concurrent operations")
        current_test.next = 7

        for count in [1, 2, 4, 8]:
            for stride in [2, 3, 5, 7]:
                for wait in wait_normal, wait_pause_master, wait_pause_slave:
                    print("count %d, stride %d"% (count, stride))

                    for k in range(S_COUNT):
                        for l in range(count):
                            ram = ((k*61+l)*stride)%M_COUNT
                            offset = k*256+l*4
                            axi_ram_inst_list[ram].write_mem(offset, b'\xAA'*4)
                            axi_master_inst_list[k].init_write(M_BASE_ADDR[ram]+offset, bytearray([0xaa, k, l, 0xaa]))

                            ram = ((k*61+l+67)*stride)%M_COUNT
                            offset = k*256+l*4
                            axi_ram_inst_list[ram].write_mem(offset+0x8000, bytearray([0xaa, k, l, 0xaa]))
                            axi_master_inst_list[k].init_read(M_BASE_ADDR[ram]+offset+0x8000, 4)

                    yield wait()
                    yield clk.posedge

                    for k in range(S_COUNT):
                        for l in range(count):
                            ram = ((k*61+l)*stride)%M_COUNT
                            offset = k*256+l*4
                            axi_ram_inst_list[ram].read_mem(offset, 4) == bytearray([0xaa, k, l, 0xaa])

                            ram = ((k*61+l+67)*stride)%M_COUNT
                            offset = k*256+l*4
                            data = axi_master_inst_list[k].get_read_data()
                            assert data[0] == M_BASE_ADDR[ram]+offset+0x8000
                            assert data[1] == bytearray([0xaa, k, l, 0xaa])

        yield delay(100)

        yield clk.posedge
        print("test 8: bad write")
        current_test.next = 8

        axi_master_inst_list[0].init_write(0xff000000, b'\xDE\xAD\xBE\xEF')

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        yield delay(100)

        yield clk.posedge
        print("test 9: bad read")
        current_test.next = 9

        axi_master_inst_list[0].init_read(0xff000000, 4)

        yield axi_master_inst_list[0].wait()
        yield clk.posedge

        data = axi_master_inst_list[0].get_read_data()
        assert data[0] == 0xff000000

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
