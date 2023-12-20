// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 Missing Link Electronics, Inc.
 *
 * Verilog header containing port definitions for custom app port demo.
 *
 * Write and read data channels use a custom parameter for data width to
 * demonstrate usage of custom parameters in custom port definitions.
 *
 * See template header files in fpga/app/template/rtl/ for feature documentation.
 */

// Custom port list (direction, dimension (empty for regular 1-bit wire), name)
`define APP_CUSTOM_PORTS(X_PORT) \
    X_PORT(output,   [AXIL_APP_CTRL_ADDR_WIDTH-1:0], m_axil_app_ctrl_awaddr) \
    X_PORT(output,                            [2:0], m_axil_app_ctrl_awprot) \
    X_PORT(output,                                 , m_axil_app_ctrl_awvalid) \
    X_PORT(input,                                  , m_axil_app_ctrl_awready) \
    X_PORT(output, [AXIL_APP_CUSTOM_DATA_WIDTH-1:0], m_axil_app_ctrl_wdata) \
    X_PORT(output, [AXIL_APP_CUSTOM_STRB_WIDTH-1:0], m_axil_app_ctrl_wstrb) \
    X_PORT(output,                                 , m_axil_app_ctrl_wvalid) \
    X_PORT(input,                                  , m_axil_app_ctrl_wready) \
    X_PORT(input,                             [1:0], m_axil_app_ctrl_bresp) \
    X_PORT(input,                                  , m_axil_app_ctrl_bvalid) \
    X_PORT(output,                                 , m_axil_app_ctrl_bready) \
    X_PORT(output,   [AXIL_APP_CTRL_ADDR_WIDTH-1:0], m_axil_app_ctrl_araddr) \
    X_PORT(output,                            [2:0], m_axil_app_ctrl_arprot) \
    X_PORT(output,                                 , m_axil_app_ctrl_arvalid) \
    X_PORT(input,                                  , m_axil_app_ctrl_arready) \
    X_PORT(input,  [AXIL_APP_CUSTOM_DATA_WIDTH-1:0], m_axil_app_ctrl_rdata) \
    X_PORT(input,                             [1:0], m_axil_app_ctrl_rresp) \
    X_PORT(input,                                  , m_axil_app_ctrl_rvalid) \
    X_PORT(output,                                 , m_axil_app_ctrl_rready)

// port declaration expression
`define X_PORT_DECL(DIR, DIM, NAME) \
    DIR wire DIM NAME,

// port mapping expression
`define X_PORT_MAP(DIR, DIM, NAME) \
    .NAME(NAME),

// wire declarations expression
`define X_PORT_WIRE(DIR, DIM, NAME) \
    wire DIM NAME;

// final macro definitions
`define APP_CUSTOM_PORTS_DECL `APP_CUSTOM_PORTS(`X_PORT_DECL)
`define APP_CUSTOM_PORTS_MAP  `APP_CUSTOM_PORTS(`X_PORT_MAP)
`define APP_CUSTOM_PORTS_WIRE `APP_CUSTOM_PORTS(`X_PORT_WIRE)
