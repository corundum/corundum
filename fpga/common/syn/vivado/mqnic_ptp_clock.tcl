# Copyright 2022, The Regents of the University of California.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
# IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of The Regents of the University of California.

# PTP clock timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == mqnic_ptp_clock || REF_NAME == mqnic_ptp_clock)}] {
    puts "Inserting timing constraints for mqnic_ptp_clock instance $inst"

    set src_clk [get_clocks -of_objects [get_pins "$inst/set_ptp_ts_96_valid_reg_reg/C"]]

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_ts_96_valid_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_ns_inc_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_fns_inc_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_ns_ovf_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_fns_ovf_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_s_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_ns_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/ts_96_fns_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_ts_96_valid_reg_reg"] -to [get_cells "$inst/set_ptp_ts_96_valid_sync_1_reg_reg"] -datapath_only [get_property -min PERIOD $src_clk]

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_period_valid_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_period_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/period_ns_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_period_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/period_fns_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_period_valid_reg_reg"] -to [get_cells "$inst/set_ptp_period_valid_sync_1_reg_reg"] -datapath_only [get_property -min PERIOD $src_clk]

    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/set_ptp_offset_valid_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/set_ptp_offset_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/adj_ns_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_offset_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/adj_fns_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_offset_count_reg_reg[*]"] -to [get_cells "$inst/ptp_clock_inst/adj_count_reg_reg[*]"] -datapath_only [get_property -min PERIOD $src_clk]
    set_max_delay -from [get_cells "$inst/set_ptp_offset_valid_reg_reg"] -to [get_cells "$inst/set_ptp_offset_valid_sync_1_reg_reg"] -datapath_only [get_property -min PERIOD $src_clk]
}
