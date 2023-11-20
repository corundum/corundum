# Timing constraints for the Intel DK-DEV-AGF014EA FPGA development board

set_time_format -unit ns -decimal_places 3

# Clock constraints
create_clock -period 30.000 -name "usr_clk_33m" [ get_ports "usr_clk_33m_p" ]
create_clock -period 20.000 -name "sys_clk_50m" [ get_ports "sys_clk_50m" ]
#create_clock -period 40.000 -name "hps_osc_clk" [ get_ports "hps_osc_clk" ]

create_clock -period 10.000 -name "pcie_refclk_0" [ get_ports "pcie_refclk_p[0]" ]
create_clock -period 10.000 -name "pcie_refclk_1" [ get_ports "pcie_refclk_p[1]" ]

create_clock -period 6.400 -name "qsfp_refclk_156m" [ get_ports "qsfp_refclk_156m_p" ]

create_clock -period 30.000 -name "clk_ddr4_ch0" [ get_ports "clk_ddr4_ch0_p" ]
create_clock -period 30.000 -name "clk_ddr4_ch1" [ get_ports "clk_ddr4_ch1_p" ]

derive_clock_uncertainty

set_clock_groups -asynchronous -group [ get_clocks "clk_sys_100m" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_sys_bak_50m" ]
set_clock_groups -asynchronous -group [ get_clocks "hps_osc_clk" ]

set_clock_groups -asynchronous -group [ get_clocks "pcie_refclk_0" ]
set_clock_groups -asynchronous -group [ get_clocks "pcie_refclk_1" ]

set_clock_groups -asynchronous -group [ get_clocks "qsfp_refclk_156m" ]

set_clock_groups -asynchronous -group [ get_clocks "clk_ddr4_ch0" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_ddr4_ch1" ]

# JTAG constraints
create_clock -name {altera_reserved_tck} -period 41.667 [get_ports { altera_reserved_tck }]

set_clock_groups -asynchronous -group [get_clocks "altera_reserved_tck"]
set_input_delay -clock altera_reserved_tck 6 [get_ports altera_reserved_tdi]
set_input_delay -clock altera_reserved_tck 6 [get_ports altera_reserved_tms]
set_output_delay -clock altera_reserved_tck -clock_fall -max 6 [get_ports altera_reserved_tdo]

# IO constraints
set_false_path -to   "user_led_g"
set_false_path -to   "user_led_r"

set_false_path -from "pcie_perst_n"


source ../lib/eth/lib/axis/syn/quartus_pro/sync_reset.sdc

# clocking infrastructure
constrain_sync_reset_inst "sync_reset_100mhz_inst"
constrain_sync_reset_inst "ptp_rst_reset_sync_inst"

# PCIe clock
set_clock_groups -asynchronous -group [ get_clocks "pcie_hip_inst|intel_pcie_ptile_ast_0|inst|inst|maib_and_tile|xcvr_hip_native|rx_ch15" ]
