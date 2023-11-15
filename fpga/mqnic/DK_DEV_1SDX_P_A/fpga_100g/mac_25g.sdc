# E-Tile MACs
set_clock_groups -asynchronous -group [ get_clocks "iopll_etile_ptp_inst|iopll_0_refclk" ]
set_clock_groups -asynchronous -group [ get_clocks "iopll_etile_ptp_inst|iopll_0_outclk0" ]

proc constrain_etile_mac_quad { inst } {
    puts "Inserting timing constraints for MAC quad $inst"

    for {set i 0} {$i < 4} {incr i} {
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|rx_clkout2|ch${i}" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|rx_clkout|ch${i}" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|tx_clkout2|ch${i}" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|tx_clkout|ch${i}" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|rx_clkout2|ch${i}" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|rx_clkout|ch${i}" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|tx_clkout2|ch${i}" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_nphy_elane|tx_clkout|ch${i}" ]
    }

    set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_PTP_NPHY_CHPLL.nphy_ptp0|alt_ehipc3_nphy_elane_ptp|tx_clkout|ch0" ]
    set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|SL_PTP_NPHY_CHPLL.nphy_ptp1|alt_ehipc3_nphy_elane_ptp_plloff|tx_transfer_clk|ch0" ]

    for {set i 0} {$i < 4} {incr i} {
        constrain_sync_reset_inst "$inst|mac_ch[$i].mac_tx_reset_sync_inst"
        constrain_sync_reset_inst "$inst|mac_ch[$i].mac_tx_ptp_reset_sync_inst"
        constrain_sync_reset_inst "$inst|mac_ch[$i].mac_rx_ptp_reset_sync_inst"
    }
}

constrain_etile_mac_quad "qsfp1_mac_inst"
constrain_etile_mac_quad "qsfp2_mac_inst"
