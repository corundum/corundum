# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# PTP clock timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == mqnic_ptp_clock || REF_NAME == mqnic_ptp_clock)}] {
    puts "Inserting timing constraints for mqnic_ptp_clock instance $inst"

    set src_clk [get_clocks -of_objects [get_cells "$inst/set_ptp_period_req_reg_reg"]]

    set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_ts_tod_(req|ack)_sync\[12\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_s_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/ts_tod_s_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/ts_tod_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_req_reg_reg"] -to [get_cells "$inst/set_ptp_ts_tod_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_ack_reg_reg"] -to [get_cells "$inst/set_ptp_ts_tod_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/offset_ptp_ts_tod_(req|ack)_sync\[12\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/offset_ptp_ts_tod_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/adder_b_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_tod_req_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_tod_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_tod_ack_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_tod_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_ts_rel_(req|ack)_sync\[12\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_ts_rel_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/ts_rel_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_rel_req_reg_reg"] -to [get_cells "$inst/set_ptp_ts_rel_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_rel_ack_reg_reg"] -to [get_cells "$inst/set_ptp_ts_rel_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/offset_ptp_ts_rel_(req|ack)_sync\[12\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/offset_ptp_ts_rel_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/adder_b_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_rel_req_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_rel_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_rel_ack_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_rel_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_period_(req|ack)_sync\[12\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_period_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/period_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/period_fns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_req_reg_reg"] -to [get_cells "$inst/set_ptp_period_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_ack_reg_reg"] -to [get_cells "$inst/set_ptp_period_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/offset_ptp_ts_(req|ack)_sync\[12\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/offset_ptp_ts_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/adder_b_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_req_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_ack_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_ack_sync1_reg_reg"] -datapath_only $src_clk_period
}
