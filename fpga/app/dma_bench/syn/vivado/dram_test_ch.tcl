# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2023 The Regents of the University of California

# DRAM test channel timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == dram_test_ch || REF_NAME == dram_test_ch)}] {
    puts "Inserting timing constraints for dram_test_ch instance $inst"

    proc constrain_sync_chain {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set src_clk [get_clocks -of_objects [get_pins "$inst/$driver/C"]]

            set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

            set_max_delay -from [get_cells "$inst/$driver"] -to [get_cells "$inst/[lindex $args 0]"] -datapath_only $src_clk_period
        }
    }

    constrain_sync_chain $inst "fifo_base_addr_reg_reg[*]" "fifo_base_addr_sync_1_reg_reg[*]" "fifo_base_addr_sync_2_reg_reg[*]"
    constrain_sync_chain $inst "fifo_size_mask_reg_reg[*]" "fifo_size_mask_sync_1_reg_reg[*]" "fifo_size_mask_sync_2_reg_reg[*]"
    constrain_sync_chain $inst "fifo_enable_reg_reg" "fifo_enable_sync_1_reg_reg" "fifo_enable_sync_2_reg_reg"
    constrain_sync_chain $inst "fifo_reset_reg_reg" "fifo_reset_sync_1_reg_reg" "fifo_reset_sync_2_reg_reg"

    constrain_sync_chain $inst "fifo_occupancy_reg_reg[*]" "fifo_occupancy_sync_1_reg_reg[*]" "fifo_occupancy_sync_2_reg_reg[*]"
    constrain_sync_chain $inst "fifo_reset_status_reg_reg" "fifo_reset_status_sync_1_reg_reg" "fifo_reset_status_sync_2_reg_reg"
    constrain_sync_chain $inst "fifo_active_reg_reg" "fifo_active_sync_1_reg_reg" "fifo_active_sync_2_reg_reg"
}
