// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 Missing Link Electronics, Inc.
 *
 * Template verilog header containing definitions for custom app ports.
 * See fpga/mqnic/ZCU102/fpga/fpga_app_custom_port_demo for an example design.
 *
 * The macros defined within this file and mqnic_app_custom_params.vh allow
 * users to add custom ports and parameters to the mqnic_app_block. The
 * additional ports and parameters are added and propagated throughout
 * hierarchical modules of mqnic, starting from the toplevel mqnic_core modules:
 *   - mqnic_core_axi
 *   - mqnic_core_pcie_ptile
 *   - mqnic_core_pcie_s10
 *   - mqnic_core_pcie_us
 *
 * Usage:
 * 1. Enable custom app ports by adding the following line to config.tcl:
 *        set_property VERILOG_DEFINE  {APP_CUSTOM_PORTS_ENABLE} [get_filesets sources_1]
 *    For custom parameters, add:
 *        set_property VERILOG_DEFINE  {APP_CUSTOM_PARAMS_ENABLE} [get_filesets sources_1]
 *    Enable both custom ports and parameters by adding:
 *         set_property VERILOG_DEFINE  {APP_CUSTOM_PORTS_ENABLE APP_CUSTOM_PARAMS_ENABLE} [get_filesets sources_1]
 *    Be aware that this overwrites the property VERILOG_DEFINE of the fileset.
 * 2. Custom ports must be defined in a verilog header file named "mqnic_app_custom_ports.vh".
 *    Custom parameters must be defined in "mqnic_app_custom_params.vh". When
 *    using custom ports/parameters, add the respective header file to the
 *    synthesis sources.
 * 3. For custom ports, define the following macros:
 *    - APP_CUSTOM_PORTS_DECL: port declarations, inserted into port lists of
 *        hierarchical modules up to mqnic_core_*
 *    - APP_CUSTOM_PORTS_MAP: port assignments, inserted into instantiation of
 *        hierarchical modules
 *    - (optional) APP_CUSTOM_PORTS_WIRE: wire declarations matching the ports,
 *        can be used in conjunction with APP_CUSTOM_INTF_PORT_MAP at toplevel,
 *        where mqnic is instantiated
 *    For custom parameters, define the following macros:
 *    - APP_CUSTOM_PARAMS_DECL: parameter declarations, inserted into parameter
 *        lists of hierarchical modules up to mqnic_core_*
 *    - APP_CUSTOM_PARAMS_MAP: parameter massignments, inserted into instantiation
 *        of hierarchical modules
 *
 * Ports may use existing or custom parameters for their dimension; when using
 * existing parameters, make sure they are available at every hierarchical level,
 * otherwise define a new custom parameter with a suitable value.
 *
 * Custom parameters may be overridden via config.tcl, just like all other
 * parameters. To enable this, the custom parameters must be passed through all
 * hierarchical modules from the design top to the instantiation of mqnic_core_*.
 *
 * The template headers are implemented with nested 'X macros', so ports and
 * parameters only have to be defined once in APP_CUSTOM_PORTS and APP_CUSTOM_PARAMS,
 * respectively. If nested macros are not properly supported by your tool, define
 * the necessary macros by manually typing out the lists of port declarations,
 * port mappings, etc., for example:
 *
 * `define APP_CUSTOM_PORTS_DECL \
 *   input        custom_port_a, \
 *   output [3:0] custom_port_b,
 *
 * `define APP_CUSTOM_PORTS_MAP \
 *   .custom_port_a(custom_port_a), \
 *   .custom_port_b(custom_port_b),
 */

// Custom port list (direction, dimension (empty for regular 1-bit wire), name)
`define APP_CUSTOM_PORTS(X_PORT) \
    X_PORT(input,        , template_wire_in) \
    X_PORT(input,  [15:0], template_vec_in) \
    X_PORT(output,       , template_wire_out) \
    X_PORT(output, [15:0], template_vec_out)

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
