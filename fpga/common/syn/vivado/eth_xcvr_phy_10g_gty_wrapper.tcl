# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# GTY transceiver and PHY wrapper timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == eth_xcvr_phy_10g_gty_wrapper || REF_NAME == eth_xcvr_phy_10g_gty_wrapper)}] {
    puts "Inserting timing constraints for eth_xcvr_phy_10g_gty_wrapper instance $inst"

    proc constrain_sync_chain {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set src_clk [get_clocks -of_objects [get_cells "$inst/$driver"]]

            set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

            set_max_delay -from [get_cells "$inst/$driver"] -to [get_cells "$inst/[lindex $args 0]"] -datapath_only $src_clk_period
        }
    }

    # PLL lock
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/qpll\[01\]_lock_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]

    # reset synchronization
    constrain_sync_chain $inst "gt_tx_reset_done_reg_reg" "gt_tx_reset_done_sync_1_reg_reg" "gt_tx_reset_done_sync_2_reg_reg"
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_pma_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_prgdiv_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    constrain_sync_chain $inst "gt_userclk_tx_active_reg_reg" "gt_userclk_tx_active_sync_1_reg_reg" "gt_userclk_tx_active_sync_2_reg_reg"
    constrain_sync_chain $inst "gt_rx_reset_done_reg_reg" "gt_rx_reset_done_sync_1_reg_reg" "gt_rx_reset_done_sync_2_reg_reg"
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_pma_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_prgdiv_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    constrain_sync_chain $inst "gt_userclk_rx_active_reg_reg" "gt_userclk_rx_active_sync_1_reg_reg" "gt_userclk_rx_active_sync_2_reg_reg"
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rxcdrlock_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]

    # TX
    constrain_sync_chain $inst "gt_txprbssel_drp_reg_reg[*]" "gt_txprbssel_sync_reg_reg[*]"
    constrain_sync_chain $inst "gt_txprbsforceerr_drp_reg_reg" "gt_txprbsforceerr_sync_1_reg_reg" "gt_txprbsforceerr_sync_2_reg_reg"
    constrain_sync_chain $inst "gt_txpolarity_drp_reg_reg" "gt_txpolarity_sync_reg_reg"
    constrain_sync_chain $inst "gt_txinhibit_drp_reg_reg" "gt_txinhibit_sync_reg_reg"

    set driver_ffs [get_cells -hier "gt_tx_pd_reg_reg gt_txelecidle_reg_reg" -filter "PARENT == $inst"]

    if {[llength $driver_ffs]} {
        set_false_path -from $driver_ffs
    }

    # RX
    constrain_sync_chain $inst "gt_rxpolarity_drp_reg_reg" "gt_rxpolarity_sync_reg_reg"
    constrain_sync_chain $inst "gt_rxprbssel_drp_reg_reg[*]" "gt_rxprbssel_sync_reg_reg[*]"
    constrain_sync_chain $inst "gt_rxprbscntreset_drp_reg_reg" "gt_rxprbscntreset_sync_1_reg_reg" "gt_rxprbscntreset_sync_2_reg_reg"
    constrain_sync_chain $inst "gt_rxprbserr_sync_1_reg_reg" "gt_rxprbserr_sync_2_reg_reg" "gt_rxprbserr_sync_3_reg_reg"
    constrain_sync_chain $inst "gt_rxprbserr_sync_3_reg_reg" "gt_rxprbserr_sync_4_reg_reg" "gt_rxprbserr_sync_5_reg_reg"
    constrain_sync_chain $inst "gt_rxprbslocked_reg_reg" "gt_rxprbslocked_sync_1_reg_reg" "gt_rxprbslocked_sync_2_reg_reg"

    # PHY
    constrain_sync_chain $inst "phy_rx_reset_req_sync_1_reg_reg" "phy_rx_reset_req_sync_2_reg_reg" "phy_rx_reset_req_sync_3_reg_reg"
    constrain_sync_chain $inst "phy_rx_block_lock_reg_reg" "phy_rx_block_lock_sync_1_reg_reg" "phy_rx_block_lock_sync_2_reg_reg"
    constrain_sync_chain $inst "phy_rx_high_ber_reg_reg" "phy_rx_high_ber_sync_1_reg_reg" "phy_rx_high_ber_sync_2_reg_reg"
    constrain_sync_chain $inst "phy_rx_status_reg_reg" "phy_rx_status_sync_1_reg_reg" "phy_rx_status_sync_2_reg_reg"
}
