# Copyright 2023, The Regents of the University of California.
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

# DRAM test channel timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == dram_test_ch || REF_NAME == dram_test_ch)}] {
    puts "Inserting timing constraints for dram_test_ch instance $inst"

    proc constrain_sync_chain {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set src_clk [get_clocks -of_objects [get_pins "$inst/$driver/C"]]

            set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

            set_max_delay -from [get_cells "$inst/$driver"] -to [get_cells "$inst/[lindex $args 0]"] -datapath_only $src_clk_period
        }
    }

    constrain_sync_chain $inst "fifo_base_addr_reg_reg[*]" "fifo_base_addr_sync_1_reg_reg[*]" "fifo_base_addr_sync_2_reg_reg[*]"
    constrain_sync_chain $inst "fifo_size_mask_reg_reg[*]" "fifo_size_mask_sync_1_reg_reg[*]" "fifo_size_mask_sync_2_reg_reg[*]"
    constrain_sync_chain $inst "fifo_enable_reg_reg" "fifo_enable_sync_1_reg_reg" "fifo_enable_sync_2_reg_reg"
    constrain_sync_chain $inst "fifo_reset_reg_reg" "fifo_reset_sync_1_reg_reg" "fifo_reset_sync_2_reg_reg"

    constrain_sync_chain $inst "fifo_occupancy_reg_reg[*]" "fifo_occupancy_sync_1_reg_reg[*]" "fifo_occupancy_sync_2_reg_reg[*]"
    constrain_sync_chain $inst "fifo_reset_status_reg_reg" "fifo_reset_status_sync_1_reg_reg" "fifo_reset_status_sync_2_reg_reg"
    constrain_sync_chain $inst "fifo_active_reg_reg" "fifo_active_sync_1_reg_reg" "fifo_active_sync_2_reg_reg"
}
