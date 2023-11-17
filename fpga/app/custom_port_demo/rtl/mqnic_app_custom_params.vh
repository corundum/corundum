// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 Missing Link Electronics, Inc.
 *
 * Verilog header containing parameter definitions for custom app port demo.
 *
 * AXIL_APP_CUSTOM_DATA_WIDTH has been assigned a nonsensical value to demonstrate
 * parameter value override via config.tcl.
 *
 * See template header files in fpga/app/template/rtl/ for feature documentation.
 */

// Custom parameter list (name, default value)
`define APP_CUSTOM_PARAMS(X_PARAM) \
    X_PARAM(AXIL_APP_CUSTOM_DATA_WIDTH, 1) \
    X_PARAM(AXIL_APP_CUSTOM_STRB_WIDTH, (AXIL_APP_CUSTOM_DATA_WIDTH/8))

// parameter declaration expression
`define X_PARAM_DECL(NAME, DEFAULT) \
    parameter NAME = DEFAULT,

// parameter mapping expression
`define X_PARAM_MAP(NAME, DEFAULT) \
    .NAME(NAME),

// final macro definitions
`define APP_CUSTOM_PARAMS_DECL `APP_CUSTOM_PARAMS(`X_PARAM_DECL)
`define APP_CUSTOM_PARAMS_MAP  `APP_CUSTOM_PARAMS(`X_PARAM_MAP)
