# E-Tile MACs
proc constrain_etile_mac { inst } {
    puts "Inserting timing constraints for MAC $inst"

    set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|E100GX4_FEC_PTP_PR.nphy_ptp0|alt_ehipc3_nphy_elane_ptp|tx_clkout|ch0" ]
    set_clock_groups -asynchronous -group [ get_clocks "$inst|mac_inst|alt_ehipc3_0|alt_ehipc3_hard_inst|E100GX4_FEC_PTP_PR.nphy_ptp1|alt_ehipc3_nphy_elane_ptp|tx_clkout|ch0" ]

    constrain_sync_reset_inst "$inst|.mac_reset_sync_inst"
}

constrain_etile_mac "qsfp1_mac_inst"
constrain_etile_mac "qsfp2_mac_inst"
