# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2019-2023 The Regents of the University of California

# TDMA BER channel module

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == tdma_ber_ch || REF_NAME == tdma_ber_ch)}] {
    puts "Inserting timing constraints for tdma_ber_ch instance $inst"

    # get clock periods
    set clk [get_clocks -of_objects [get_cells "$inst/cfg_tx_prbs31_enable_reg_reg"]]
    set tx_clk [get_clocks -of_objects [get_cells "$inst/phy_cfg_tx_prbs31_enable_reg_reg"]]
    set rx_clk [get_clocks -of_objects [get_cells "$inst/phy_cfg_rx_prbs31_enable_reg_reg"]]

    set clk_period [if {[llength $clk]} {get_property -min PERIOD $clk} {expr 1.0}]
    set tx_clk_period [if {[llength $tx_clk]} {get_property -min PERIOD $tx_clk} {expr 1.0}]
    set rx_clk_period [if {[llength $rx_clk]} {get_property -min PERIOD $rx_clk} {expr 1.0}]

    # control synchronization
    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/phy_cfg_(rx|tx)_prbs31_enable_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/cfg_tx_prbs31_enable_reg_reg"] -to [get_cells "$inst/phy_cfg_tx_prbs31_enable_reg_reg"] -datapath_only $clk_period
    set_max_delay -from [get_cells "$inst/cfg_rx_prbs31_enable_reg_reg"] -to [get_cells "$inst/phy_cfg_rx_prbs31_enable_reg_reg"] -datapath_only $clk_period

    # data synchronization
    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/rx_flag_sync_reg_\[123\]_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/phy_rx_flag_reg_reg"] -to [get_cells $inst/rx_flag_sync_reg_1_reg] -datapath_only $rx_clk_period

    set_max_delay -from [get_cells "$inst/phy_rx_error_count_reg_reg[*]"] -to [get_cells $inst/phy_rx_error_count_sync_reg_reg[*]] -datapath_only $rx_clk_period
    set_bus_skew  -from [get_cells "$inst/phy_rx_error_count_reg_reg[*]"] -to [get_cells $inst/phy_rx_error_count_sync_reg_reg[*]] $clk_period
}
