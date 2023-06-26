# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# DRP register block timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == rb_drp || REF_NAME == rb_drp)}] {
    puts "Inserting timing constraints for rb_drp instance $inst"

    # get clock periods
    set drp_clk [get_clocks -of_objects [get_cells "$inst/drp_flag_reg_reg"]]
    set rb_clk [get_clocks -of_objects [get_cells "$inst/rb_flag_reg_reg"]]

    set drp_clk_period [if {[llength $drp_clk]} {get_property -min PERIOD $drp_clk} {expr 1.0}]
    set rb_clk_period [if {[llength $rb_clk]} {get_property -min PERIOD $rb_clk} {expr 1.0}]

    set_property ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/drp_flag_sync_reg_\[12\]_reg" -filter "PARENT == $inst"]
    set_property ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/rb_flag_sync_reg_\[12\]_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/drp_flag_reg_reg"] -to [get_cells "$inst/drp_flag_sync_reg_1_reg"] -datapath_only $rb_clk_period
    set_max_delay -from [get_cells "$inst/rb_flag_reg_reg"] -to [get_cells "$inst/rb_flag_sync_reg_1_reg"] -datapath_only $drp_clk_period

    set source [get_cells -quiet -hier -regexp ".*/rb_(addr|di|we)_reg_reg(\\\[\\d+\\\])?" -filter "PARENT == $inst"]
    set dest   [get_cells -quiet -hier -regexp ".*/drp_(addr|di|we)_reg_reg(\\\[\\d+\\\])?" -filter "PARENT == $inst"]

    if {[llength $dest]} {
        if {![llength $source]} {
            # source cells seem to have been merged with something, so go hunt them down
            set dest_pins [get_pins -of_objects $dest -filter {REF_PIN_NAME == "D"}]
            set nets [get_nets -segments -of_objects $dest_pins]
            set source_pins [get_pins -of_objects $nets -filter {IS_LEAF && DIRECTION == "OUT"}]
            set source [get_cells -of_objects $source_pins]
        }

        if {[llength $source]} {
            set_max_delay -from $source -to $dest -datapath_only $drp_clk_period
            set_bus_skew  -from $source -to $dest $rb_clk_period
        }
    }

    set source [get_cells -quiet -hier -regexp ".*/drp_do_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]
    set dest   [get_cells -quiet -hier -regexp ".*/rb_do_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $dest]} {
        if {![llength $source]} {
            # source cells seem to have been merged with something, so go hunt them down
            set dest_pins [get_pins -of_objects $dest -filter {REF_PIN_NAME == "D"}]
            set nets [get_nets -segments -of_objects $dest_pins]
            set source_pins [get_pins -of_objects $nets -filter {IS_LEAF && DIRECTION == "OUT"}]
            set source [get_cells -of_objects $source_pins]
        }

        if {[llength $source]} {
            set_max_delay -from $source -to $dest -datapath_only $rb_clk_period
            set_bus_skew  -from $source -to $dest $drp_clk_period
        }
    }
}
