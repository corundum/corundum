# Copyright 2019, The Regents of the University of California.
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

# TDMA BER channel module

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == tdma_ber_ch || REF_NAME == tdma_ber_ch)}] {
    puts "Inserting timing constraints for tdma_ber_ch instance $inst"

    # get clock periods
    set clk [get_clocks -of_objects [get_pins $inst/tx_prbs31_enable_reg_reg/C]]
    set tx_clk [get_clocks -of_objects [get_pins $inst/phy_tx_prbs31_enable_reg_reg/C]]
    set rx_clk [get_clocks -of_objects [get_pins $inst/phy_rx_prbs31_enable_reg_reg/C]]

    set clk_period [get_property -min PERIOD $clk]
    set tx_clk_period [get_property -min PERIOD $tx_clk]
    set rx_clk_period [get_property -min PERIOD $rx_clk]

    set min_clk_period [expr $tx_clk_period < $write_clk_period ? $tx_clk_period : $write_clk_period]

    # control synchronization
    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/phy_(rx|tx)_prbs31_enable_reg_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/tx_prbs31_enable_reg_reg"] -to [get_cells "$inst/phy_tx_prbs31_enable_reg_reg"] -datapath_only $clk_period
    set_max_delay -from [get_cells "$inst/rx_prbs31_enable_reg_reg"] -to [get_cells "$inst/phy_rx_prbs31_enable_reg_reg"] -datapath_only $clk_period

    # data synchronization
    set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/rx_flag_sync_reg_\[123\]_reg" -filter "PARENT == $inst"]

    set_max_delay -from [get_cells "$inst/phy_rx_flag_reg_reg"] -to [get_cells $inst/rx_flag_sync_reg_1_reg] -datapath_only $rx_clk_period

    set_max_delay -from [get_cells "$inst/phy_rx_error_count_reg_reg[*]"] -to [get_cells $inst/phy_rx_error_count_sync_reg_reg[*]] -datapath_only $rx_clk_period
    set_bus_skew  -from [get_cells "$inst/phy_rx_error_count_reg_reg[*]"] -to [get_cells $inst/phy_rx_error_count_sync_reg_reg[*]] $clk_period
}
