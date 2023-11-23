# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# PTP clock timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == mqnic_rb_clk_info || REF_NAME == mqnic_rb_clk_info)}] {
    puts "Inserting timing constraints for mqnic_rb_clk_info instance $inst"

    set clk [get_clocks -of_objects [get_cells "$inst/ref_strb_sync_1_reg_reg"]]

    set clk_period [if {[llength $clk]} {get_property -min PERIOD $clk} {expr 1.0}]

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/ref_strb_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/ref_strb_reg_reg"] -to [get_cells "$inst/ref_strb_sync_1_reg_reg"] -datapath_only $clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/channel\\\[\\d+\\\]\\.ch_flag_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/channel[*].ch_prescale_reg_reg[*]"] -to [get_cells "$inst/channel[*].ch_flag_sync_1_reg_reg"] -datapath_only $clk_period
}
