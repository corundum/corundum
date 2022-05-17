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

# GTY transceiver and PHY wrapper timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == eth_xcvr_phy_10g_gty_wrapper || REF_NAME == eth_xcvr_phy_10g_gty_wrapper)}] {
    puts "Inserting timing constraints for eth_xcvr_phy_10g_gty_wrapper instance $inst"

    proc constrain_sync_chain {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set src_clk [get_clocks -of_objects [get_pins $inst/$driver/C]]

            set_max_delay -from [get_cells $inst/$driver] -to [get_cells $inst/[lindex $args 0]] -datapath_only [get_property -min PERIOD $src_clk]
        }
    }

    # PLL lock
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/qpll\[01\]_lock_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]

    # reset synchronization
    constrain_sync_chain $inst "gt_tx_reset_done_reg_reg" "gt_tx_reset_done_sync_1_reg_reg" "gt_tx_reset_done_sync_2_reg_reg"
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_pma_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_prgdiv_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    constrain_sync_chain $inst "gt_userclk_tx_active_reg_reg" "gt_userclk_tx_active_sync_1_reg_reg" "gt_userclk_tx_active_sync_2_reg_reg"
    constrain_sync_chain $inst "gt_rx_reset_done_reg_reg" "gt_rx_reset_done_sync_1_reg_reg" "gt_rx_reset_done_sync_2_reg_reg"
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_pma_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rx_prgdiv_reset_done_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]
    constrain_sync_chain $inst "gt_userclk_rx_active_reg_reg" "gt_userclk_rx_active_sync_1_reg_reg" "gt_userclk_rx_active_sync_2_reg_reg"
    set_property -quiet ASYNC_REG TRUE [get_cells -quiet -hier -regexp ".*/gt_rxcdrlock_sync_\[12\]_reg_reg" -filter "PARENT == $inst"]

    # TX
    constrain_sync_chain $inst "gt_txprbssel_drp_reg_reg[*]" "gt_txprbssel_sync_reg_reg[*]"
    constrain_sync_chain $inst "gt_txprbsforceerr_drp_reg_reg" "gt_txprbsforceerr_sync_1_reg_reg" "gt_txprbsforceerr_sync_2_reg_reg"
    constrain_sync_chain $inst "gt_txpolarity_drp_reg_reg" "gt_txpolarity_sync_reg_reg"
    constrain_sync_chain $inst "gt_txinhibit_drp_reg_reg" "gt_txinhibit_sync_reg_reg"
    set_false_path -from [get_cells $inst/gt_tx_pd_reg_reg]
    set_false_path -from [get_cells $inst/gt_txelecidle_reg_reg]

    # RX
    constrain_sync_chain $inst "gt_rxpolarity_drp_reg_reg" "gt_rxpolarity_sync_reg_reg"
    constrain_sync_chain $inst "gt_rxprbssel_drp_reg_reg[*]" "gt_rxprbssel_sync_reg_reg[*]"
    constrain_sync_chain $inst "gt_rxprbscntreset_drp_reg_reg" "gt_rxprbscntreset_sync_1_reg_reg" "gt_rxprbscntreset_sync_2_reg_reg"
    constrain_sync_chain $inst "gt_rxprbserr_sync_1_reg_reg" "gt_rxprbserr_sync_2_reg_reg" "gt_rxprbserr_sync_3_reg_reg"
    constrain_sync_chain $inst "gt_rxprbserr_sync_3_reg_reg" "gt_rxprbserr_sync_4_reg_reg" "gt_rxprbserr_sync_5_reg_reg"
    constrain_sync_chain $inst "gt_rxprbslocked_reg_reg" "gt_rxprbslocked_sync_1_reg_reg" "gt_rxprbslocked_sync_2_reg_reg"

    # PHY
    constrain_sync_chain $inst "phy_rx_reset_req_sync_1_reg_reg" "phy_rx_reset_req_sync_2_reg_reg" "phy_rx_reset_req_sync_3_reg_reg"
    constrain_sync_chain $inst "phy_rx_block_lock_reg_reg" "phy_rx_block_lock_sync_1_reg_reg" "phy_rx_block_lock_sync_2_reg_reg"
    constrain_sync_chain $inst "phy_rx_high_ber_reg_reg" "phy_rx_high_ber_sync_1_reg_reg" "phy_rx_high_ber_sync_2_reg_reg"
    constrain_sync_chain $inst "phy_rx_status_reg_reg" "phy_rx_status_sync_1_reg_reg" "phy_rx_status_sync_2_reg_reg"
}
