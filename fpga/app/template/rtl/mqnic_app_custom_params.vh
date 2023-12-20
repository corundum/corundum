// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 Missing Link Electronics, Inc.
 *
 * Template verilog header containing definitions for custom app parameters.
 *
 * See mqnic_app_custom_ports.vh for detailed explanation.
 */

// Custom parameter list (name, default value)
`define APP_CUSTOM_PARAMS(X_PARAM) \
    X_PARAM(TEMPLATE_PARAM_1, 42) \
    X_PARAM(TEMPLATE_PARAM_2, 32'hDEADBEEF)

// parameter declaration expression
`define X_PARAM_DECL(NAME, DEFAULT) \
    parameter NAME = DEFAULT,

// parameter mapping expression
`define X_PARAM_MAP(NAME, DEFAULT) \
    .NAME(NAME),

// final macro definitions
`define APP_CUSTOM_PARAMS_DECL `APP_CUSTOM_PARAMS(`X_PARAM_DECL)
`define APP_CUSTOM_PARAMS_MAP  `APP_CUSTOM_PARAMS(`X_PARAM_MAP)
