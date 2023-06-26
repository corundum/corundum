# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# NIC port timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == mqnic_port || REF_NAME == mqnic_port)}] {
    puts "Inserting timing constraints for mqnic_port instance $inst"

    proc constrain_slow_sync {inst driver args} {
        set sync_ffs [get_cells -hier $args -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set_false_path -from [get_cells "$inst/$driver"] -to [get_cells "$inst/[lindex $args 0]"]
        }
    }

    constrain_slow_sync $inst "rx_rst_sync_1_reg_reg" "rx_rst_sync_2_reg_reg" "rx_rst_sync_3_reg_reg"
    constrain_slow_sync $inst "rx_status_sync_1_reg_reg" "rx_status_sync_2_reg_reg" "rx_status_sync_3_reg_reg"
    constrain_slow_sync $inst "tx_rst_sync_1_reg_reg" "tx_rst_sync_2_reg_reg" "tx_rst_sync_3_reg_reg"
    constrain_slow_sync $inst "tx_status_sync_1_reg_reg" "tx_status_sync_2_reg_reg" "tx_status_sync_3_reg_reg"
}
