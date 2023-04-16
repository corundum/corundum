# Timing constraints for the Intel DK-DEV-AGF014EA FPGA development board

set_time_format -unit ns -decimal_places 3

# Clock constraints
create_clock -period 10.000 -name "clk_sys_100m" [ get_ports "clk_sys_100m_p" ]
create_clock -period 20.000 -name "clk_sys_bak_50m" [ get_ports "clk_sys_bak_50m_p" ]
create_clock -period 40.000 -name "hps_osc_clk" [ get_ports "hps_osc_clk" ]

create_clock -period 10.000 -name "pcie_refclk_0" [ get_ports "pcie_refclk_p[0]" ]
create_clock -period 10.000 -name "pcie_refclk_1" [ get_ports "pcie_refclk_p[1]" ]

create_clock -period 3.103 -name "refclk_322m_qsfpdd" [ get_ports "refclk_322m_qsfpdd_p" ]
create_clock -period 6.400 -name "refclk_156m_qsfpdd" [ get_ports "refclk_156m_qsfpdd_p" ]

create_clock -period 30.000 -name "clk_ddr4_ch0" [ get_ports "clk_ddr4_ch0_p" ]
create_clock -period 30.000 -name "clk_ddr4_ch1" [ get_ports "clk_ddr4_ch1_p" ]
create_clock -period 30.000 -name "clk_ddr4_ch2" [ get_ports "clk_ddr4_ch2_p" ]
create_clock -period 30.000 -name "clk_ddr4_ch3" [ get_ports "clk_ddr4_ch3_p" ]

derive_clock_uncertainty

set_clock_groups -asynchronous -group [ get_clocks "clk_sys_100m" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_sys_bak_50m" ]
set_clock_groups -asynchronous -group [ get_clocks "hps_osc_clk" ]

set_clock_groups -asynchronous -group [ get_clocks "pcie_refclk_0" ]
set_clock_groups -asynchronous -group [ get_clocks "pcie_refclk_1" ]

set_clock_groups -asynchronous -group [ get_clocks "refclk_322m_qsfpdd" ]
set_clock_groups -asynchronous -group [ get_clocks "refclk_156m_qsfpdd" ]

set_clock_groups -asynchronous -group [ get_clocks "clk_ddr4_ch0" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_ddr4_ch1" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_ddr4_ch2" ]
set_clock_groups -asynchronous -group [ get_clocks "clk_ddr4_ch3" ]

# JTAG constraints
create_clock -name {altera_reserved_tck} -period 41.667 [get_ports { altera_reserved_tck }]

set_clock_groups -asynchronous -group [get_clocks "altera_reserved_tck"]
set_input_delay -clock altera_reserved_tck 6 [get_ports altera_reserved_tdi]
set_input_delay -clock altera_reserved_tck 6 [get_ports altera_reserved_tms]
set_output_delay -clock altera_reserved_tck -clock_fall -max 6 [get_ports altera_reserved_tdo]

# IO constraints
set_false_path -from "cpu_resetn"

set_false_path -to   "fpga_led[*]"
set_false_path -to   "qsfpdd0_led0"
set_false_path -to   "qsfpdd0_led1_g"
set_false_path -to   "qsfpdd0_led1_y"
set_false_path -to   "qsfpdd1_led0"
set_false_path -to   "qsfpdd1_led1_g"
set_false_path -to   "qsfpdd1_led1_y"

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

constrain_etile_mac_dual_quad "qsfpdd0_mac_inst"
constrain_etile_mac_dual_quad "qsfpdd1_mac_inst"
