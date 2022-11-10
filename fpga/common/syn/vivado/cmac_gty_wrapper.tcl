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

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == cmac_gty_wrapper || REF_NAME == cmac_gty_wrapper)}] {
    puts "Inserting timing constraints for cmac_gty_wrapper instance $inst"

    proc constrain_sync_chain {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set src_clk [get_clocks -of_objects [get_pins "$inst/$driver/C"]]

            set_max_delay -from [get_cells "$inst/$driver"] -to [get_cells "$inst/[lindex $args 0]"] -datapath_only [get_property -min PERIOD $src_clk]
        }
    }

    proc constrain_sync_chain_async {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set_false_path -to [get_pins "$inst/$driver/D"]
        }
    }

    # False paths to async input pins on CMAC
    set cmac_cells [get_cells -hierarchical -filter "PARENT == $inst/cmac_inst/inst/i_cmac_usplus_top"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ RX_RESET"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ TX_RESET"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ RX_SERDES_RESET*"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ CTL_RX_ENABLE_PPP"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ CTL_RX_CHECK_SA_PPP"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ CTL_RX_CHECK_OPCODE_PPP"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ CTL_RX_RSFEC_ENABLE"]
    set_false_path -to [get_pins -of $cmac_cells -filter "REF_PIN_NAME =~ CTL_RX_FORCE_RESYNC"]

    # Control and status connections to DRP registers
    constrain_sync_chain_async $inst "tx_rst_sync_1_reg_reg" "tx_rst_sync_2_reg_reg"
    constrain_sync_chain_async $inst "rx_rst_sync_1_reg_reg" "rx_rst_sync_2_reg_reg"

    constrain_sync_chain $inst "cmac_ctl_tx_rsfec_enable_drp_reg_reg" "cmac_ctl_tx_rsfec_enable_sync_reg_reg" "cmac_ctl_tx_rsfec_enable_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_rx_rsfec_enable_drp_reg_reg" "cmac_ctl_rx_rsfec_enable_sync_reg_reg" "cmac_ctl_rx_rsfec_enable_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_rsfec_ieee_error_indication_mode_drp_reg_reg" "cmac_ctl_rsfec_ieee_error_indication_mode_sync_reg_reg" "cmac_ctl_rsfec_ieee_error_indication_mode_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_rx_rsfec_enable_correction_drp_reg_reg" "cmac_ctl_rx_rsfec_enable_correction_sync_reg_reg" "cmac_ctl_rx_rsfec_enable_correction_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_rx_rsfec_enable_indication_drp_reg_reg" "cmac_ctl_rx_rsfec_enable_indication_sync_reg_reg" "cmac_ctl_rx_rsfec_enable_indication_reg_reg"

    constrain_sync_chain_async $inst "cmac_stat_rx_rsfec_am_lock_sync_1_reg_reg[*]" "cmac_stat_rx_rsfec_am_lock_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "cmac_stat_rx_rsfec_hi_ser_sync_1_reg_reg" "cmac_stat_rx_rsfec_hi_ser_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_rsfec_lane_alignment_status_sync_1_reg_reg" "cmac_stat_rx_rsfec_lane_alignment_status_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_rsfec_lane_fill_sync_1_reg_reg[*]" "cmac_stat_rx_rsfec_lane_fill_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "cmac_stat_rx_rsfec_lane_mapping_sync_1_reg_reg[*]" "cmac_stat_rx_rsfec_lane_mapping_sync_2_reg_reg[*]"

    constrain_sync_chain_async $inst "cmac_rx_lane_aligner_fill_sync_1_reg_reg[*]" "cmac_rx_lane_aligner_fill_sync_2_reg_reg[*]"

    constrain_sync_chain_async $inst "cmac_stat_rx_aligned_sync_1_reg_reg" "cmac_stat_rx_aligned_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_aligned_err_sync_1_reg_reg" "cmac_stat_rx_aligned_err_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_block_lock_sync_1_reg_reg[*]" "cmac_stat_rx_block_lock_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "cmac_stat_rx_hi_ber_sync_1_reg_reg" "cmac_stat_rx_hi_ber_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_internal_local_fault_sync_1_reg_reg" "cmac_stat_rx_internal_local_fault_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_local_fault_sync_1_reg_reg" "cmac_stat_rx_local_fault_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_mf_len_err_sync_1_reg_reg[*]" "cmac_stat_rx_mf_len_err_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "cmac_stat_rx_mf_repeat_err_sync_1_reg_reg[*]" "cmac_stat_rx_mf_repeat_err_sync_2_reg_reg[*]"

    constrain_sync_chain $inst "cmac_ctl_rx_enable_drp_reg_reg" "cmac_ctl_rx_enable_sync_reg_reg" "cmac_ctl_rx_enable_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_rx_force_resync_drp_reg_reg" "cmac_ctl_rx_force_resync_sync_reg_reg" "cmac_ctl_rx_force_resync_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_rx_test_pattern_drp_reg_reg" "cmac_ctl_rx_test_pattern_sync_reg_reg" "cmac_ctl_rx_test_pattern_reg_reg"

    constrain_sync_chain_async $inst "cmac_stat_rx_received_local_fault_sync_1_reg_reg" "cmac_stat_rx_received_local_fault_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_remote_fault_sync_1_reg_reg" "cmac_stat_rx_remote_fault_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_status_sync_1_reg_reg" "cmac_stat_rx_status_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_rx_synced_sync_1_reg_reg[*]" "cmac_stat_rx_synced_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "cmac_stat_rx_synced_err_sync_1_reg_reg[*]" "cmac_stat_rx_synced_err_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "cmac_stat_rx_pcsl_demuxed_sync_1_reg_reg[*]" "cmac_stat_rx_pcsl_demuxed_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "cmac_stat_rx_pcsl_number_sync_1_reg_reg[*]" "cmac_stat_rx_pcsl_number_sync_2_reg_reg[*]"

    constrain_sync_chain_async $inst "cmac_stat_tx_ptp_fifo_read_error_sync_1_reg_reg" "cmac_stat_tx_ptp_fifo_read_error_sync_2_reg_reg"
    constrain_sync_chain_async $inst "cmac_stat_tx_ptp_fifo_write_error_sync_1_reg_reg" "cmac_stat_tx_ptp_fifo_write_error_sync_2_reg_reg"

    constrain_sync_chain_async $inst "cmac_stat_tx_local_fault_sync_1_reg_reg" "cmac_stat_tx_local_fault_sync_2_reg_reg"

    constrain_sync_chain $inst "cmac_ctl_tx_enable_drp_reg_reg" "cmac_ctl_tx_enable_sync_reg_reg" "cmac_ctl_tx_enable_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_tx_send_idle_drp_reg_reg" "cmac_ctl_tx_send_idle_sync_reg_reg" "cmac_ctl_tx_send_idle_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_tx_send_rfi_drp_reg_reg" "cmac_ctl_tx_send_rfi_sync_reg_reg" "cmac_ctl_tx_send_rfi_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_tx_send_lfi_drp_reg_reg" "cmac_ctl_tx_send_lfi_sync_reg_reg" "cmac_ctl_tx_send_lfi_reg_reg"
    constrain_sync_chain $inst "cmac_ctl_tx_test_pattern_drp_reg_reg" "cmac_ctl_tx_test_pattern_sync_reg_reg" "cmac_ctl_tx_test_pattern_reg_reg"
}
