package require -exact qsys 21.3

# create the system "ref_div"
proc do_create_ref_div {} {
	# create the system
	create_system ref_div
	set_project_property DEVICE {1SM21CHU1F53E1VG}
	set_project_property DEVICE_FAMILY {Stratix 10}
	set_project_property HIDE_FROM_IP_CATALOG {true}
	set_use_testbench_naming_pattern 0 {}

	# add HDL parameters

	# add the components
	add_instance stratix10_clkctrl_0 stratix10_clkctrl
	set_instance_parameter_value stratix10_clkctrl_0 {CLOCK_DIVIDER} {1}
	set_instance_parameter_value stratix10_clkctrl_0 {CLOCK_DIVIDER_OUTPUTS} {3}
	set_instance_parameter_value stratix10_clkctrl_0 {ENABLE} {0}
	set_instance_parameter_value stratix10_clkctrl_0 {ENABLE_REGISTER_TYPE} {1}
	set_instance_parameter_value stratix10_clkctrl_0 {ENABLE_TYPE} {2}
	set_instance_parameter_value stratix10_clkctrl_0 {GLITCH_FREE_SWITCHOVER} {0}
	set_instance_parameter_value stratix10_clkctrl_0 {NUM_CLOCKS} {1}
	set_instance_property stratix10_clkctrl_0 AUTO_EXPORT true

	# add wirelevel expressions

	# preserve ports for debug

	# add the exports
	set_interface_property inclk EXPORT_OF stratix10_clkctrl_0.inclk
	set_interface_property clock_div1x EXPORT_OF stratix10_clkctrl_0.clock_div1x
	set_interface_property clock_div2x EXPORT_OF stratix10_clkctrl_0.clock_div2x
	set_interface_property clock_div4x EXPORT_OF stratix10_clkctrl_0.clock_div4x

	# set values for exposed HDL parameters

	# set the the module properties
	set_module_property BONUS_DATA {<?xml version="1.0" encoding="UTF-8"?>
<bonusData>
 <element __value="stratix10_clkctrl_0">
  <datum __value="_sortIndex" value="0" type="int" />
 </element>
</bonusData>
}
	set_module_property FILE {ref_div.ip}
	set_module_property GENERATION_ID {0x00000000}
	set_module_property NAME {ref_div}

	# save the system
	sync_sysinfo_parameters
	save_system ref_div
}

proc do_set_exported_interface_sysinfo_parameters {} {
}

# create all the systems, from bottom up
do_create_ref_div

# set system info parameters on exported interface, from bottom up
do_set_exported_interface_sysinfo_parameters
