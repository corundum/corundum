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

# DRP register block timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == rb_drp || REF_NAME == rb_drp)}] {
    puts "Inserting timing constraints for rb_drp instance $inst"

    # get clock periods
    set drp_clk [get_clocks -of_objects [get_pins $inst/drp_flag_reg_reg/C]]
    set rb_clk [get_clocks -of_objects [get_pins $inst/rb_flag_reg_reg/C]]

    set drp_clk_period [get_property -min PERIOD $drp_clk]
    set rb_clk_period [get_property -min PERIOD $rb_clk]

    set min_clk_period [expr $drp_clk_period < $rb_clk_period ? $drp_clk_period : $rb_clk_period]

    set_property ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/drp_flag_sync_reg_\[12\]_reg" -filter "PARENT == $inst"]
    set_property ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/rb_flag_sync_reg_\[12\]_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells $inst/drp_flag_reg_reg] -to [get_cells $inst/drp_flag_sync_reg_1_reg] -datapath_only $rb_clk_period
    set_max_delay -from [get_cells $inst/rb_flag_reg_reg] -to [get_cells $inst/rb_flag_sync_reg_1_reg] -datapath_only $drp_clk_period

    set source [get_cells -quiet -hier -regexp ".*/rb_(addr|di|we)_reg_reg(\\\[\\d+\\\])?" -filter "PARENT == $inst"]
    set dest   [get_cells -quiet -hier -regexp ".*/drp_(addr|di|we)_reg_reg(\\\[\\d+\\\])?" -filter "PARENT == $inst"]

    if {[llength $dest]} {
        if {![llength $source]} {
            # source cells seem to have been merged with something, so go hunt them down
            set dest_pins [get_pins -of_objects $dest -filter {REF_PIN_NAME == "D"}]
            set nets [get_nets -segments -of_objects $dest_pins]
            set source_pins [get_pins -of_objects $nets -filter {IS_LEAF && DIRECTION == "OUT"}]
            set source [get_cells -of_objects $source_pins]
        }

        if {[llength $source]} {
            set_max_delay -from $source -to $dest -datapath_only $drp_clk_period
            set_bus_skew  -from $source -to $dest $rb_clk_period
        }
    }

    set source [get_cells -quiet -hier -regexp ".*/drp_do_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]
    set dest   [get_cells -quiet -hier -regexp ".*/rb_do_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $dest]} {
        if {![llength $source]} {
            # source cells seem to have been merged with something, so go hunt them down
            set dest_pins [get_pins -of_objects $dest -filter {REF_PIN_NAME == "D"}]
            set nets [get_nets -segments -of_objects $dest_pins]
            set source_pins [get_pins -of_objects $nets -filter {IS_LEAF && DIRECTION == "OUT"}]
            set source [get_cells -of_objects $source_pins]
        }

        if {[llength $source]} {
            set_max_delay -from $source -to $dest -datapath_only $rb_clk_period
            set_bus_skew  -from $source -to $dest $drp_clk_period
        }
    }
}
