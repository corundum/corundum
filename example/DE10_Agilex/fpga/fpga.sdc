# Timing constraints for the Terasic DE10-Agilex FPGA development board

set_time_format -unit ns -decimal_places 3

# Clock constraints
create_clock -period 10.000 -name {clk_100_b2a} [ get_ports {clk_100_b2a} ]
create_clock -period 20.000 -name {clk_50_b3a} [ get_ports {clk_50_b3a} ]
create_clock -period 20.000 -name {clk_50_b3c} [ get_ports {clk_50_b3c} ]
create_clock -period 32.552 -name {clk_30m72} [ get_ports {clk_30m72} ]
create_clock -period 20.000 -name {clk_from_si5397a_0} [ get_ports {clk_from_si5397a_p[0]} ]
create_clock -period 20.000 -name {clk_from_si5397a_1} [ get_ports {clk_from_si5397a_p[1]} ]

create_clock -period 10.000 -name {pcie_refclk_0} [ get_ports {pcie_refclk_p[0]} ]
create_clock -period 10.000 -name {pcie_refclk_1} [ get_ports {pcie_refclk_p[1]} ]

create_clock -period 6.400 -name {qsfpdda_refclk} [ get_ports {qsfpdda_refclk_p} ]
create_clock -period 6.400 -name {qsfpddb_refclk} [ get_ports {qsfpddb_refclk_p} ]
create_clock -period 6.400 -name {qsfpddrsv_refclk} [ get_ports {qsfpddrsv_refclk_p} ]

create_clock -period 30.000 -name {ddr4a_refclk} [ get_ports {ddr4a_refclk_p} ]
create_clock -period 30.000 -name {ddr4b_refclk} [ get_ports {ddr4b_refclk_p} ]
create_clock -period 30.000 -name {ddr4c_refclk} [ get_ports {ddr4c_refclk_p} ]
create_clock -period 30.000 -name {ddr4d_refclk} [ get_ports {ddr4d_refclk_p} ]

derive_clock_uncertainty

set_clock_groups -asynchronous -group [ get_clocks {clk_100_b2a} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_50_b3a} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_50_b3c} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_30m72} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_from_si5397a_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_from_si5397a_1} ]

set_clock_groups -asynchronous -group [ get_clocks {pcie_refclk_0} ]
set_clock_groups -asynchronous -group [ get_clocks {pcie_refclk_1} ]

set_clock_groups -asynchronous -group [ get_clocks {qsfpdda_refclk} ]
set_clock_groups -asynchronous -group [ get_clocks {qsfpddb_refclk} ]
set_clock_groups -asynchronous -group [ get_clocks {qsfpddrsv_refclk} ]

set_clock_groups -asynchronous -group [ get_clocks {ddr4a_refclk} ]
set_clock_groups -asynchronous -group [ get_clocks {ddr4b_refclk} ]
set_clock_groups -asynchronous -group [ get_clocks {ddr4c_refclk} ]
set_clock_groups -asynchronous -group [ get_clocks {ddr4d_refclk} ]

# JTAG constraints
# create_clock -name {altera_reserved_tck} -period 40.800 {altera_reserved_tck}

# set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}]

# IO constraints
set_false_path -from "cpu_resetn"
set_false_path -from "button[*]"
set_false_path -from "sw[*]"
set_false_path -to   "led[*]"
set_false_path -to   "led_bracket[*]"

set_false_path -from "pcie_perst_n"
