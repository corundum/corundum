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

# NIC port timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == mqnic_port || REF_NAME == mqnic_port)}] {
    puts "Inserting timing constraints for mqnic_port instance $inst"

    proc constrain_slow_sync {inst driver args} {
        set sync_ffs [get_cells -hier $args -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set_false_path -from [get_cells "$inst/$driver"] -to [get_cells "$inst/[lindex $args 0]"]
        }
    }

    constrain_slow_sync $inst "rx_rst_sync_1_reg_reg" "rx_rst_sync_2_reg_reg" "rx_rst_sync_3_reg_reg"
    constrain_slow_sync $inst "rx_status_sync_1_reg_reg" "rx_status_sync_2_reg_reg" "rx_status_sync_3_reg_reg"
    constrain_slow_sync $inst "tx_rst_sync_1_reg_reg" "tx_rst_sync_2_reg_reg" "tx_rst_sync_3_reg_reg"
    constrain_slow_sync $inst "tx_status_sync_1_reg_reg" "tx_status_sync_2_reg_reg" "tx_status_sync_3_reg_reg"
}
