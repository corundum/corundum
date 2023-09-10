# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

# NIC port timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == mqnic_port || REF_NAME == mqnic_port)}] {
    puts "Inserting timing constraints for mqnic_port instance $inst"

    proc constrain_sync_chain_async {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set_false_path -to [get_pins "$inst/$driver/D"]
        }
    }

    constrain_sync_chain_async $inst "tx_enable_sync_1_reg_reg" "tx_enable_sync_2_reg_reg"
    constrain_sync_chain_async $inst "tx_lfc_en_sync_1_reg_reg" "tx_lfc_en_sync_2_reg_reg"
    constrain_sync_chain_async $inst "tx_lfc_req_sync_1_reg_reg" "tx_lfc_req_sync_2_reg_reg"
    constrain_sync_chain_async $inst "tx_pfc_en_sync_1_reg_reg[*]" "tx_pfc_en_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "tx_pfc_req_sync_1_reg_reg[*]" "tx_pfc_req_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "tx_fc_quanta_step_sync_1_reg_reg[*]" "tx_fc_quanta_step_sync_2_reg_reg[*]"

    constrain_sync_chain_async $inst "tx_rst_sync_2_reg_reg" "tx_rst_sync_3_reg_reg"
    constrain_sync_chain_async $inst "tx_status_sync_2_reg_reg" "tx_status_sync_3_reg_reg"

    constrain_sync_chain_async $inst "rx_enable_sync_1_reg_reg" "rx_enable_sync_2_reg_reg"
    constrain_sync_chain_async $inst "rx_lfc_en_sync_1_reg_reg" "rx_lfc_en_sync_2_reg_reg"
    constrain_sync_chain_async $inst "rx_lfc_ack_sync_1_reg_reg" "rx_lfc_ack_sync_2_reg_reg"
    constrain_sync_chain_async $inst "rx_pfc_en_sync_1_reg_reg[*]" "rx_pfc_en_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "rx_pfc_ack_sync_1_reg_reg[*]" "rx_pfc_ack_sync_2_reg_reg[*]"

    constrain_sync_chain_async $inst "rx_rst_sync_2_reg_reg" "rx_rst_sync_3_reg_reg"
    constrain_sync_chain_async $inst "rx_status_sync_2_reg_reg" "rx_status_sync_3_reg_reg"
    constrain_sync_chain_async $inst "rx_lfc_req_sync_2_reg_reg" "rx_lfc_req_sync_3_reg_reg"
    constrain_sync_chain_async $inst "rx_pfc_req_sync_2_reg_reg[*]" "rx_pfc_req_sync_3_reg_reg[*]"
    constrain_sync_chain_async $inst "rx_fc_quanta_step_sync_1_reg_reg[*]" "rx_fc_quanta_step_sync_2_reg_reg[*]"
}
