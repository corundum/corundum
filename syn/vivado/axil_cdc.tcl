# Copyright (c) 2019 Alex Forencich
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# AXI lite clock domain crossing module timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == axil_cdc_rd || REF_NAME == axil_cdc_rd || ORIG_REF_NAME == axil_cdc_wr || REF_NAME == axil_cdc_wr)}] {
    puts "Inserting timing constraints for axil_cdc instance $inst"

    # get clock periods
    set m_clk [get_clocks -of_objects [get_pins $inst/m_flag_reg_reg/C]]
    set s_clk [get_clocks -of_objects [get_pins $inst/s_flag_reg_reg/C]]

    set m_clk_period [get_property -min PERIOD $m_clk]
    set s_clk_period [get_property -min PERIOD $s_clk]

    set min_clk_period [expr $m_clk_period < $s_clk_period ? $m_clk_period : $s_clk_period]

    set_property ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/m_flag_sync_reg_\[12\]_reg" -filter "PARENT == $inst"]
    set_property ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/s_flag_sync_reg_\[12\]_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells $inst/m_flag_reg_reg] -to [get_cells $inst/m_flag_sync_reg_1_reg] -datapath_only $s_clk_period
    set_max_delay -from [get_cells $inst/s_flag_reg_reg] -to [get_cells $inst/s_flag_sync_reg_1_reg] -datapath_only $m_clk_period

    set source [get_cells -quiet -hier -regexp ".*/s_axil_a?(r|w)(addr|prot|data|strb)_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]
    set dest   [get_cells -quiet -hier -regexp ".*/m_axil_a?(r|w)(addr|prot|data|strb)_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $dest]} {
        if {![llength $source]} {
            # source cells seem to have been merged with something, so go hunt them down
            set dest_pins [get_pins -of_objects $dest -filter {REF_PIN_NAME == "D"}]
            set nets [get_nets -segments -of_objects $dest_pins]
            set source_pins [get_pins -of_objects $nets -filter {IS_LEAF && DIRECTION == "OUT"}]
            set source [get_cells -of_objects $source_pins]
        }

        if {[llength $source]} {
            set_max_delay -from $source -to $dest -datapath_only $m_clk_period
            set_bus_skew  -from $source -to $dest $s_clk_period
        }
    }

    set source [get_cells -quiet -hier -regexp ".*/m_axil_(r|b)(resp|data)_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]
    set dest   [get_cells -quiet -hier -regexp ".*/s_axil_(r|b)(resp|data)_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $dest]} {
        if {![llength $source]} {
            # source cells seem to have been merged with something, so go hunt them down
            set dest_pins [get_pins -of_objects $dest -filter {REF_PIN_NAME == "D"}]
            set nets [get_nets -segments -of_objects $dest_pins]
            set source_pins [get_pins -of_objects $nets -filter {IS_LEAF && DIRECTION == "OUT"}]
            set source [get_cells -of_objects $source_pins]
        }

        if {[llength $source]} {
            set_max_delay -from $source -to $dest -datapath_only $s_clk_period
            set_bus_skew  -from $source -to $dest $m_clk_period
        }
    }
}
