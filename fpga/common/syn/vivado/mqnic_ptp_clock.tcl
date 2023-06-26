# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# PTP clock timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == mqnic_ptp_clock || REF_NAME == mqnic_ptp_clock)}] {
    puts "Inserting timing constraints for mqnic_ptp_clock instance $inst"

    set src_clk [get_clocks -of_objects [get_cells "$inst/set_ptp_ts_96_valid_reg_reg"]]

    set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_ts_96_valid_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_ns_inc_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_fns_inc_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_ns_ovf_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_fns_ovf_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_s_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_fns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_valid_reg_reg"] -to [get_cells "$inst/set_ptp_ts_96_valid_sync_1_reg_reg"] -datapath_only $src_clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_period_valid_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_period_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/period_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/period_fns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_valid_reg_reg"] -to [get_cells "$inst/set_ptp_period_valid_sync_1_reg_reg"] -datapath_only $src_clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_offset_valid_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_offset_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/adj_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_offset_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/adj_fns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_offset_count_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/adj_count_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_offset_valid_reg_reg"] -to [get_cells "$inst/set_ptp_offset_valid_sync_1_reg_reg"] -datapath_only $src_clk_period
}
