# E-Tile MACs
proc constrain_etile_mac_dual { inst } {
    puts "Inserting timing constraints for MAC dual $inst"

    foreach mac {mac_02_inst mac_13_inst} {
        set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|E100GX4_FEC_PTP_PR.nphy_ptp0|alt_ehipc3_fm_nphy_elane_ptp|tx_clkout|ch0" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|E100GX4_FEC_PTP_PR.nphy_ptp1|alt_ehipc3_fm_nphy_elane_ptp|tx_clkout|ch0" ]
    }

    for {set i 0} {$i < 2} {incr i} {
        constrain_sync_reset_inst "$inst|mac_ch[$i].mac_reset_sync_inst"
    }
}

constrain_etile_mac_dual "qsfp_mac_inst"
