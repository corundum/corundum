// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * mqnic DRAM interface
 */
module mqnic_dram_if #
(
    // RAM configuration
    parameter CH = 1,
    parameter GROUP_SIZE = 1,
    parameter AXI_DATA_WIDTH = 256,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_AWUSER_ENABLE = 0,
    parameter AXI_AWUSER_WIDTH = 1,
    parameter AXI_WUSER_ENABLE = 0,
    parameter AXI_WUSER_WIDTH = 1,
    parameter AXI_BUSER_ENABLE = 0,
    parameter AXI_BUSER_WIDTH = 1,
    parameter AXI_ARUSER_ENABLE = 0,
    parameter AXI_ARUSER_WIDTH = 1,
    parameter AXI_RUSER_ENABLE = 0,
    parameter AXI_RUSER_WIDTH = 1,
    parameter AXI_MAX_BURST_LEN = 256,
    parameter AXI_NARROW_BURST = 0,
    parameter AXI_FIXED_BURST = 0,
    parameter AXI_WRAP_BURST = 0
)
(
    input  wire                            clk,
    input  wire                            rst,

    /*
     * AXI to DRAM
     */
    input  wire [CH-1:0]                   m_axi_clk,
    input  wire [CH-1:0]                   m_axi_rst,

    output wire [CH*AXI_ID_WIDTH-1:0]      m_axi_awid,
    output wire [CH*AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [CH*8-1:0]                 m_axi_awlen,
    output wire [CH*3-1:0]                 m_axi_awsize,
    output wire [CH*2-1:0]                 m_axi_awburst,
    output wire [CH-1:0]                   m_axi_awlock,
    output wire [CH*4-1:0]                 m_axi_awcache,
    output wire [CH*3-1:0]                 m_axi_awprot,
    output wire [CH*4-1:0]                 m_axi_awqos,
    output wire [CH*AXI_AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire [CH-1:0]                   m_axi_awvalid,
    input  wire [CH-1:0]                   m_axi_awready,
    output wire [CH*AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [CH*AXI_STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire [CH-1:0]                   m_axi_wlast,
    output wire [CH*AXI_WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire [CH-1:0]                   m_axi_wvalid,
    input  wire [CH-1:0]                   m_axi_wready,
    input  wire [CH*AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [CH*2-1:0]                 m_axi_bresp,
    input  wire [CH*AXI_BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire [CH-1:0]                   m_axi_bvalid,
    output wire [CH-1:0]                   m_axi_bready,
    output wire [CH*AXI_ID_WIDTH-1:0]      m_axi_arid,
    output wire [CH*AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [CH*8-1:0]                 m_axi_arlen,
    output wire [CH*3-1:0]                 m_axi_arsize,
    output wire [CH*2-1:0]                 m_axi_arburst,
    output wire [CH-1:0]                   m_axi_arlock,
    output wire [CH*4-1:0]                 m_axi_arcache,
    output wire [CH*3-1:0]                 m_axi_arprot,
    output wire [CH*4-1:0]                 m_axi_arqos,
    output wire [CH*AXI_ARUSER_WIDTH-1:0]  m_axi_aruser,
    output wire [CH-1:0]                   m_axi_arvalid,
    input  wire [CH-1:0]                   m_axi_arready,
    input  wire [CH*AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [CH*AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [CH*2-1:0]                 m_axi_rresp,
    input  wire [CH-1:0]                   m_axi_rlast,
    input  wire [CH*AXI_RUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire [CH-1:0]                   m_axi_rvalid,
    output wire [CH-1:0]                   m_axi_rready,

    input  wire [CH-1:0]                   status_in,

    /*
     * AXI to application
     */
    output wire [CH-1:0]                   s_axi_app_clk,
    output wire [CH-1:0]                   s_axi_app_rst,

    input  wire [CH*AXI_ID_WIDTH-1:0]      s_axi_app_awid,
    input  wire [CH*AXI_ADDR_WIDTH-1:0]    s_axi_app_awaddr,
    input  wire [CH*8-1:0]                 s_axi_app_awlen,
    input  wire [CH*3-1:0]                 s_axi_app_awsize,
    input  wire [CH*2-1:0]                 s_axi_app_awburst,
    input  wire [CH-1:0]                   s_axi_app_awlock,
    input  wire [CH*4-1:0]                 s_axi_app_awcache,
    input  wire [CH*3-1:0]                 s_axi_app_awprot,
    input  wire [CH*4-1:0]                 s_axi_app_awqos,
    input  wire [CH*AXI_AWUSER_WIDTH-1:0]  s_axi_app_awuser,
    input  wire [CH-1:0]                   s_axi_app_awvalid,
    output wire [CH-1:0]                   s_axi_app_awready,
    input  wire [CH*AXI_DATA_WIDTH-1:0]    s_axi_app_wdata,
    input  wire [CH*AXI_STRB_WIDTH-1:0]    s_axi_app_wstrb,
    input  wire [CH-1:0]                   s_axi_app_wlast,
    input  wire [CH*AXI_WUSER_WIDTH-1:0]   s_axi_app_wuser,
    input  wire [CH-1:0]                   s_axi_app_wvalid,
    output wire [CH-1:0]                   s_axi_app_wready,
    output wire [CH*AXI_ID_WIDTH-1:0]      s_axi_app_bid,
    output wire [CH*2-1:0]                 s_axi_app_bresp,
    output wire [CH*AXI_BUSER_WIDTH-1:0]   s_axi_app_buser,
    output wire [CH-1:0]                   s_axi_app_bvalid,
    input  wire [CH-1:0]                   s_axi_app_bready,
    input  wire [CH*AXI_ID_WIDTH-1:0]      s_axi_app_arid,
    input  wire [CH*AXI_ADDR_WIDTH-1:0]    s_axi_app_araddr,
    input  wire [CH*8-1:0]                 s_axi_app_arlen,
    input  wire [CH*3-1:0]                 s_axi_app_arsize,
    input  wire [CH*2-1:0]                 s_axi_app_arburst,
    input  wire [CH-1:0]                   s_axi_app_arlock,
    input  wire [CH*4-1:0]                 s_axi_app_arcache,
    input  wire [CH*3-1:0]                 s_axi_app_arprot,
    input  wire [CH*4-1:0]                 s_axi_app_arqos,
    input  wire [CH*AXI_ARUSER_WIDTH-1:0]  s_axi_app_aruser,
    input  wire [CH-1:0]                   s_axi_app_arvalid,
    output wire [CH-1:0]                   s_axi_app_arready,
    output wire [CH*AXI_ID_WIDTH-1:0]      s_axi_app_rid,
    output wire [CH*AXI_DATA_WIDTH-1:0]    s_axi_app_rdata,
    output wire [CH*2-1:0]                 s_axi_app_rresp,
    output wire [CH-1:0]                   s_axi_app_rlast,
    output wire [CH*AXI_RUSER_WIDTH-1:0]   s_axi_app_ruser,
    output wire [CH-1:0]                   s_axi_app_rvalid,
    input  wire [CH-1:0]                   s_axi_app_rready,

    output wire [CH-1:0]                   app_status
);

generate

genvar n;

    for (n = 0; n < CH; n = n + 1) begin : ch

        wire ch_clk = m_axi_clk[n];
        wire ch_rst = m_axi_rst[n];

        wire [AXI_ID_WIDTH-1:0]      axi_ch_awid;
        wire [AXI_ADDR_WIDTH-1:0]    axi_ch_awaddr;
        wire [7:0]                   axi_ch_awlen;
        wire [2:0]                   axi_ch_awsize;
        wire [1:0]                   axi_ch_awburst;
        wire                         axi_ch_awlock;
        wire [3:0]                   axi_ch_awcache;
        wire [2:0]                   axi_ch_awprot;
        wire [3:0]                   axi_ch_awqos;
        wire [AXI_AWUSER_WIDTH-1:0]  axi_ch_awuser;
        wire                         axi_ch_awvalid;
        wire                         axi_ch_awready;
        wire [AXI_DATA_WIDTH-1:0]    axi_ch_wdata;
        wire [AXI_STRB_WIDTH-1:0]    axi_ch_wstrb;
        wire                         axi_ch_wlast;
        wire [AXI_WUSER_WIDTH-1:0]   axi_ch_wuser;
        wire                         axi_ch_wvalid;
        wire                         axi_ch_wready;
        wire [AXI_ID_WIDTH-1:0]      axi_ch_bid;
        wire [1:0]                   axi_ch_bresp;
        wire [AXI_BUSER_WIDTH-1:0]   axi_ch_buser;
        wire                         axi_ch_bvalid;
        wire                         axi_ch_bready;
        wire [AXI_ID_WIDTH-1:0]      axi_ch_arid;
        wire [AXI_ADDR_WIDTH-1:0]    axi_ch_araddr;
        wire [7:0]                   axi_ch_arlen;
        wire [2:0]                   axi_ch_arsize;
        wire [1:0]                   axi_ch_arburst;
        wire                         axi_ch_arlock;
        wire [3:0]                   axi_ch_arcache;
        wire [2:0]                   axi_ch_arprot;
        wire [3:0]                   axi_ch_arqos;
        wire [AXI_ARUSER_WIDTH-1:0]  axi_ch_aruser;
        wire                         axi_ch_arvalid;
        wire                         axi_ch_arready;
        wire [AXI_ID_WIDTH-1:0]      axi_ch_rid;
        wire [AXI_DATA_WIDTH-1:0]    axi_ch_rdata;
        wire [1:0]                   axi_ch_rresp;
        wire                         axi_ch_rlast;
        wire [AXI_RUSER_WIDTH-1:0]   axi_ch_ruser;
        wire                         axi_ch_rvalid;
        wire                         axi_ch_rready;

        wire ch_status = status_in[n];

        assign m_axi_awid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH] = axi_ch_awid;
        assign m_axi_awaddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = axi_ch_awaddr;
        assign m_axi_awlen[n*8 +: 8] = axi_ch_awlen;
        assign m_axi_awsize[n*3 +: 3] = axi_ch_awsize;
        assign m_axi_awburst[n*2 +: 2] = axi_ch_awburst;
        assign m_axi_awlock[n*1 +: 1] = axi_ch_awlock;
        assign m_axi_awcache[n*4 +: 4] = axi_ch_awcache;
        assign m_axi_awprot[n*3 +: 3] = axi_ch_awprot;
        assign m_axi_awqos[n*4 +: 4] = axi_ch_awqos;
        assign m_axi_awuser[n*AXI_AWUSER_WIDTH +: AXI_AWUSER_WIDTH] = axi_ch_awuser;
        assign m_axi_awvalid[n*1 +: 1] = axi_ch_awvalid;
        assign axi_ch_awready = m_axi_awready[n*1 +: 1];
        assign m_axi_wdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = axi_ch_wdata;
        assign m_axi_wstrb[n*AXI_STRB_WIDTH +: AXI_STRB_WIDTH] = axi_ch_wstrb;
        assign m_axi_wlast[n*1 +: 1] = axi_ch_wlast;
        assign m_axi_wuser[n*AXI_WUSER_WIDTH +: AXI_WUSER_WIDTH] = axi_ch_wuser;
        assign m_axi_wvalid[n*1 +: 1] = axi_ch_wvalid;
        assign axi_ch_wready = m_axi_wready[n*1 +: 1];
        assign axi_ch_bid = m_axi_bid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH];
        assign axi_ch_bresp = m_axi_bresp[n*2 +: 2];
        assign axi_ch_buser = m_axi_buser[n*AXI_BUSER_WIDTH +: AXI_BUSER_WIDTH];
        assign axi_ch_bvalid = m_axi_bvalid[n*1 +: 1];
        assign m_axi_bready[n*1 +: 1] = axi_ch_bready;
        assign m_axi_arid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH] = axi_ch_arid;
        assign m_axi_araddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = axi_ch_araddr;
        assign m_axi_arlen[n*8 +: 8] = axi_ch_arlen;
        assign m_axi_arsize[n*3 +: 3] = axi_ch_arsize;
        assign m_axi_arburst[n*2 +: 2] = axi_ch_arburst;
        assign m_axi_arlock[n*1 +: 1] = axi_ch_arlock;
        assign m_axi_arcache[n*4 +: 4] = axi_ch_arcache;
        assign m_axi_arprot[n*3 +: 3] = axi_ch_arprot;
        assign m_axi_arqos[n*4 +: 4] = axi_ch_arqos;
        assign m_axi_aruser[n*AXI_ARUSER_WIDTH +: AXI_ARUSER_WIDTH] = axi_ch_aruser;
        assign m_axi_arvalid[n*1 +: 1] = axi_ch_arvalid;
        assign axi_ch_arready = m_axi_arready[n*1 +: 1];
        assign axi_ch_rid = m_axi_rid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH];
        assign axi_ch_rdata = m_axi_rdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH];
        assign axi_ch_rresp = m_axi_rresp[n*2 +: 2];
        assign axi_ch_rlast = m_axi_rlast[n*1 +: 1];
        assign axi_ch_ruser = m_axi_ruser[n*AXI_RUSER_WIDTH +: AXI_RUSER_WIDTH];
        assign axi_ch_rvalid = m_axi_rvalid[n*1 +: 1];
        assign m_axi_rready[n*1 +: 1] = axi_ch_rready;

        assign s_axi_app_clk[n] = ch_clk;
        assign s_axi_app_rst[n] = ch_rst;

        assign axi_ch_awid = s_axi_app_awid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH];
        assign axi_ch_awaddr = s_axi_app_awaddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH];
        assign axi_ch_awlen = s_axi_app_awlen[n*8 +: 8];
        assign axi_ch_awsize = s_axi_app_awsize[n*3 +: 3];
        assign axi_ch_awburst = s_axi_app_awburst[n*2 +: 2];
        assign axi_ch_awlock = s_axi_app_awlock[n*1 +: 1];
        assign axi_ch_awcache = s_axi_app_awcache[n*4 +: 4];
        assign axi_ch_awprot = s_axi_app_awprot[n*3 +: 3];
        assign axi_ch_awqos = s_axi_app_awqos[n*4 +: 4];
        assign axi_ch_awuser = s_axi_app_awuser[n*AXI_AWUSER_WIDTH +: AXI_AWUSER_WIDTH];
        assign axi_ch_awvalid = s_axi_app_awvalid[n*1 +: 1];
        assign s_axi_app_awready[n*1 +: 1] = axi_ch_awready;
        assign axi_ch_wdata = s_axi_app_wdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH];
        assign axi_ch_wstrb = s_axi_app_wstrb[n*AXI_STRB_WIDTH +: AXI_STRB_WIDTH];
        assign axi_ch_wlast = s_axi_app_wlast[n*1 +: 1];
        assign axi_ch_wuser = s_axi_app_wuser[n*AXI_WUSER_WIDTH +: AXI_WUSER_WIDTH];
        assign axi_ch_wvalid = s_axi_app_wvalid[n*1 +: 1];
        assign s_axi_app_wready[n*1 +: 1] = axi_ch_wready;
        assign s_axi_app_bid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH] = axi_ch_bid;
        assign s_axi_app_bresp[n*2 +: 2] = axi_ch_bresp;
        assign s_axi_app_buser[n*AXI_BUSER_WIDTH +: AXI_BUSER_WIDTH] = axi_ch_buser;
        assign s_axi_app_bvalid[n*1 +: 1] = axi_ch_bvalid;
        assign axi_ch_bready = s_axi_app_bready[n*1 +: 1];
        assign axi_ch_arid = s_axi_app_arid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH];
        assign axi_ch_araddr = s_axi_app_araddr[n*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH];
        assign axi_ch_arlen = s_axi_app_arlen[n*8 +: 8];
        assign axi_ch_arsize = s_axi_app_arsize[n*3 +: 3];
        assign axi_ch_arburst = s_axi_app_arburst[n*2 +: 2];
        assign axi_ch_arlock = s_axi_app_arlock[n*1 +: 1];
        assign axi_ch_arcache = s_axi_app_arcache[n*4 +: 4];
        assign axi_ch_arprot = s_axi_app_arprot[n*3 +: 3];
        assign axi_ch_arqos = s_axi_app_arqos[n*4 +: 4];
        assign axi_ch_aruser = s_axi_app_aruser[n*AXI_ARUSER_WIDTH +: AXI_ARUSER_WIDTH];
        assign axi_ch_arvalid = s_axi_app_arvalid[n*1 +: 1];
        assign s_axi_app_arready[n*1 +: 1] = axi_ch_arready;
        assign s_axi_app_rid[n*AXI_ID_WIDTH +: AXI_ID_WIDTH] = axi_ch_rid;
        assign s_axi_app_rdata[n*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = axi_ch_rdata;
        assign s_axi_app_rresp[n*2 +: 2] = axi_ch_rresp;
        assign s_axi_app_rlast[n*1 +: 1] = axi_ch_rlast;
        assign s_axi_app_ruser[n*AXI_RUSER_WIDTH +: AXI_RUSER_WIDTH] = axi_ch_ruser;
        assign s_axi_app_rvalid[n*1 +: 1] = axi_ch_rvalid;
        assign axi_ch_rready = s_axi_app_rready[n*1 +: 1];

        assign app_status[n] = ch_status;

    end

endgenerate

endmodule

`resetall
