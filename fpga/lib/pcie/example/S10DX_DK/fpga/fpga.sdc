# Timing constraints for the Intel Stratix 10 DX FPGA development board

set_time_format -unit ns -decimal_places 3

# Clock constraints
create_clock -period 7.519 -name {clk_133m_ddr4_1} [ get_ports {clk_133m_ddr4_1_p} ]
create_clock -period 7.519 -name {clk_133m_ddr4_0} [ get_ports {clk_133m_ddr4_0_p} ]
create_clock -period 7.519 -name {clk_133m_dimm_1} [ get_ports {clk_133m_dimm_1_p} ]
create_clock -period 7.519 -name {clk_133m_dimm_0} [ get_ports {clk_133m_dimm_0_p} ]

create_clock -period 10.000 -name {clk2_100m_fpga_2i} [ get_ports {clk2_100m_fpga_2i_p} ]
create_clock -period 10.000 -name {clk2_100m_fpga_2j_0} [ get_ports {clk2_100m_fpga_2j_0_p} ]
create_clock -period 10.000 -name {clk2_100m_fpga_2j_1} [ get_ports {clk2_100m_fpga_2j_1_p} ]
create_clock -period 10.000 -name {clk_100m_fpga_3h} [ get_ports {clk_100m_fpga_3h_p} ]
create_clock -period 10.000 -name {clk_100m_fpga_3l_0} [ get_ports {clk_100m_fpga_3l_0_p} ]
create_clock -period 10.000 -name {clk_100m_fpga_3l_1} [ get_ports {clk_100m_fpga_3l_1_p} ]

create_clock -period 20.000 -name {clk2_fpga_50m} [ get_ports {clk2_fpga_50m} ]

create_clock -period 10.000 -name {clk_100m_pcie_0} [ get_ports {clk_100m_pcie_0_p} ]
create_clock -period 10.000 -name {clk_100m_pcie_1} [ get_ports {clk_100m_pcie_1_p} ]

create_clock -period 10.000 -name {clk_100m_upi0_0} [ get_ports {clk_100m_upi0_0_p} ]
create_clock -period 10.000 -name {clk_100m_upi0_1} [ get_ports {clk_100m_upi0_1_p} ]

create_clock -period 10.000 -name {clk_100m_upi1_0} [ get_ports {clk_100m_upi1_0_p} ]
create_clock -period 10.000 -name {clk_100m_upi1_1} [ get_ports {clk_100m_upi1_1_p} ]

create_clock -period 10.000 -name {clk_100m_upi2_0} [ get_ports {clk_100m_upi2_0_p} ]
create_clock -period 10.000 -name {clk_100m_upi2_1} [ get_ports {clk_100m_upi2_1_p} ]

create_clock -period 3.2 -name {clk_312p5m_qsfp0} [ get_ports {clk_312p5m_qsfp0_p} ]
create_clock -period 6.4 -name {clk_156p25m_qsfp0} [ get_ports {clk_156p25m_qsfp0_p} ]
create_clock -period 3.2 -name {clk_312p5m_qsfp1} [ get_ports {clk_312p5m_qsfp1_p} ]
create_clock -period 6.4 -name {clk_156p25m_qsfp1} [ get_ports {clk_156p25m_qsfp1_p} ]
create_clock -period 3.2 -name {clk_312p5m_qsfp2} [ get_ports {clk_312p5m_qsfp2_p} ]

derive_clock_uncertainty

set_clock_groups -asynchronous -group [ get_clocks {clk_133m_ddr4_1} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_133m_ddr4_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_133m_dimm_1} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_133m_dimm_0} ]

set_clock_groups -asynchronous -group [ get_clocks {clk2_100m_fpga_2i} ]
set_clock_groups -asynchronous -group [ get_clocks {clk2_100m_fpga_2j_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk2_100m_fpga_2j_1} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_100m_fpga_3h} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_100m_fpga_3l_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_100m_fpga_3l_1} ]

set_clock_groups -asynchronous -group [ get_clocks {clk2_fpga_50m} ]

set_clock_groups -asynchronous -group [ get_clocks {clk_100m_pcie_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_100m_pcie_1} ]

set_clock_groups -asynchronous -group [ get_clocks {clk_100m_upi0_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_100m_upi0_1} ]

set_clock_groups -asynchronous -group [ get_clocks {clk_100m_upi1_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_100m_upi1_1} ]

set_clock_groups -asynchronous -group [ get_clocks {clk_100m_upi2_0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_100m_upi2_1} ]

set_clock_groups -asynchronous -group [ get_clocks {clk_312p5m_qsfp0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_156p25m_qsfp0} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_312p5m_qsfp1} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_156p25m_qsfp1} ]
set_clock_groups -asynchronous -group [ get_clocks {clk_312p5m_qsfp2} ]

# JTAG constraints
create_clock -name {altera_reserved_tck} -period 40.800 {altera_reserved_tck}

set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}]

# IO constraints
set_false_path -from "cpu_resetn"
set_false_path -to   "user_led_g[*]"

set_false_path -from "pcie_rst_n"

