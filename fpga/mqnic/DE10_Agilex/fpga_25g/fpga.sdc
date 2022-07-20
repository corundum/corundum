# Timing constraints for the Terasic DE10-Agilex FPGA development board

set_time_format -unit ns -decimal_places 3

# Clock constraints
create_clock -period 10.000 -name "clk_100_b2a" [ get_ports "clk_100_b2a" ]
create_clock -period 20.000 -name "clk_50_b3a" [ get_ports "clk_50_b3a" ]
create_clock -period 20.000 -name "clk_50_b3c" [ get_ports "clk_50_b3c" ]
create_clock -period 32.552 -name "clk_30m72" [ get_ports "clk_30m72" ]
create_clock -period 20.000 -name "clk_from_si5397a_0" [ get_ports "clk_from_si5397a_p[0]" ]
create_clock -period 20.000 -name "clk_from_si5397a_1" [ get_ports "clk_from_si5397a_p[1]" ]

create_clock -period 10.000 -name "pcie_refclk_0" [ get_ports "pcie_refclk_p[0]" ]
create_clock -period 10.000 -name "pcie_refclk_1" [ get_ports "pcie_refclk_p[1]" ]

create_clock -period 6.400 -name "qsfpdda_refclk" [ get_ports "qsfpdda_refclk_p" ]
create_clock -period 6.400 -name "qsfpddb_refclk" [ get_ports "qsfpddb_refclk_p" ]
create_clock -period 6.400 -name "qsfpddrsv_refclk" [ get_ports "qsfpddrsv_refclk_p" ]

create_clock -period 30.000 -name "ddr4a_refclk" [ get_ports "ddr4a_refclk_p" ]
create_clock -period 30.000 -name "ddr4b_refclk" [ get_ports "ddr4b_refclk_p" ]
create_clock -period 30.000 -name "ddr4c_refclk" [ get_ports "ddr4c_refclk_p" ]
create_clock -period 30.000 -name "ddr4d_refclk" [ get_ports "ddr4d_refclk_p" ]

derive_clock_uncertainty

set_clock_groups -asynchronous -group [ get_clocks "clk_100_b2a" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_50_b3a" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_50_b3c" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_30m72" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_from_si5397a_0" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_from_si5397a_1" ]

set_clock_groups -asynchronous -group [ get_clocks "pcie_refclk_0" ]
set_clock_groups -asynchronous -group [ get_clocks "pcie_refclk_1" ]

set_clock_groups -asynchronous -group [ get_clocks "qsfpdda_refclk" ]
set_clock_groups -asynchronous -group [ get_clocks "qsfpddb_refclk" ]
set_clock_groups -asynchronous -group [ get_clocks "qsfpddrsv_refclk" ]

set_clock_groups -asynchronous -group [ get_clocks "ddr4a_refclk" ]
set_clock_groups -asynchronous -group [ get_clocks "ddr4b_refclk" ]
set_clock_groups -asynchronous -group [ get_clocks "ddr4c_refclk" ]
set_clock_groups -asynchronous -group [ get_clocks "ddr4d_refclk" ]

# JTAG constraints
# create_clock -name "altera_reserved_tck" -period 40.800 "altera_reserved_tck"

# set_clock_groups -asynchronous -group [get_clocks "altera_reserved_tck"]

# IO constraints
set_false_path -from "cpu_resetn"
set_false_path -from "button[*]"
set_false_path -from "sw[*]"
set_false_path -to   "led[*]"
set_false_path -to   "led_bracket[*]"

set_false_path -from "pcie_perst_n"


source ../lib/eth/lib/axis/syn/quartus_pro/sync_reset.sdc

# clocking infrastructure
constrain_sync_reset_inst "sync_reset_100mhz_inst"
constrain_sync_reset_inst "ptp_rst_reset_sync_inst"

# PCIe clock
set_clock_groups -asynchronous -group [ get_clocks "pcie_hip_inst|intel_pcie_ptile_ast_0|inst|inst|maib_and_tile|xcvr_hip_native|rx_ch15" ]

# E-Tile MACs
set_clock_groups -asynchronous -group [ get_clocks "iopll_etile_ptp_inst|iopll_0_refclk" ]
set_clock_groups -asynchronous -group [ get_clocks "iopll_etile_ptp_inst|iopll_0_outclk0" ]

proc constrain_etile_mac_dual_quad { inst } {
    puts "Inserting timing constraints for MAC quad $inst"

    foreach mac {mac_02_inst mac_13_inst} {
        for {set i 0} {$i < 4} {incr i} {
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|rx_clkout2|ch${i}" ]
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|rx_clkout|ch${i}" ]
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|tx_clkout2|ch${i}" ]
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|tx_clkout|ch${i}" ]
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|rx_clkout2|ch${i}" ]
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|rx_clkout|ch${i}" ]
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|tx_clkout2|ch${i}" ]
            set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_NPHY_RSFEC.altera_xcvr_native_inst|alt_ehipc3_fm_nphy_elane|tx_clkout|ch${i}" ]
        }

        set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_PTP_NPHY_CHPLL.nphy_ptp0|alt_ehipc3_fm_nphy_elane_ptp|tx_clkout|ch0" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_PTP_NPHY_CHPLL.nphy_ptp1|alt_ehipc3_fm_nphy_elane_ptp|tx_clkout|ch0" ]
        set_clock_groups -asynchronous -group [ get_clocks "$inst|$mac|alt_ehipc3_fm_0|alt_ehipc3_fm_hard_inst|SL_PTP_NPHY_CHPLL.nphy_ptp1|alt_ehipc3_fm_nphy_elane_ptp_plloff|tx_transfer_clk|ch0" ]
    }

    for {set i 0} {$i < 8} {incr i} {
        constrain_sync_reset_inst "$inst|mac_ch[$i].mac_tx_reset_sync_inst"
        constrain_sync_reset_inst "$inst|mac_ch[$i].mac_tx_ptp_reset_sync_inst"
        constrain_sync_reset_inst "$inst|mac_ch[$i].mac_rx_ptp_reset_sync_inst"
    }
}

constrain_etile_mac_dual_quad "qsfpdda_mac_inst"
constrain_etile_mac_dual_quad "qsfpddb_mac_inst"
