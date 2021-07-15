# Placement constraints
#create_pblock pblock_slr0
#add_cells_to_pblock [get_pblocks pblock_slr0] [get_cells -quiet [list ]]
#resize_pblock [get_pblocks pblock_slr0] -add {SLR0}

create_pblock pblock_slr1
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/dma_if_mux_inst]]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/dma_if_mux_ctrl_inst]]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/dma_if_mux_data_inst]]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/iface[0].interface_inst]]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/iface[1].interface_inst]]
resize_pblock [get_pblocks pblock_slr1] -add {SLR1}

#create_pblock pblock_slr2
#add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet [list ]]
#resize_pblock [get_pblocks pblock_slr2] -add {SLR2}

create_pblock pblock_pcie
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list pcie4_uscale_plus_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/pcie_us_msi_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/pcie_us_cfg_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/pcie_us_axil_master_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/dma_if_pcie_us_inst]]
# resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X1Y2:CLOCKREGION_X2Y4}
resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X4Y5:CLOCKREGION_X5Y8}
# resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X1Y20:CLOCKREGION_X1Y35}

#create_pblock pblock_eth0
#add_cells_to_pblock [get_pblocks pblock_eth0] [get_cells -quiet [list qsfp0_cmac_pad_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth0] [get_cells -quiet [list core_inst/iface[0].mac[0].mac_tx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth0] [get_cells -quiet [list core_inst/iface[0].mac[0].mac_rx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth0] [get_cells -quiet [list core_inst/iface[0].mac[0].tx_ptp_ts_fifo]]
#resize_pblock [get_pblocks pblock_eth0] -add {CLOCKREGION_X0Y0:CLOCKREGION_X0Y2} 
#resize_pblock [get_pblocks pblock_eth0] -add {CLOCKREGION_X0Y4:CLOCKREGION_X0Y7}

#create_pblock pblock_eth1
#add_cells_to_pblock [get_pblocks pblock_eth1] [get_cells -quiet [list qsfp1_cmac_pad_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth1] [get_cells -quiet [list core_inst/iface[1].mac[0].mac_tx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth1] [get_cells -quiet [list core_inst/iface[1].mac[0].mac_rx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth1] [get_cells -quiet [list core_inst/iface[1].mac[0].tx_ptp_ts_fifo]]
#resize_pblock [get_pblocks pblock_eth1] -add {CLOCKREGION_X0Y3:CLOCKREGION_X0Y5}
#resize_pblock [get_pblocks pblock_eth1] -add {CLOCKREGION_X0Y12:CLOCKREGION_X0Y15}

#create_pblock pblock_eth2
#add_cells_to_pblock [get_pblocks pblock_eth2] [get_cells -quiet [list qsfp2_cmac_pad_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth2] [get_cells -quiet [list core_inst/iface[2].mac[0].mac_tx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth2] [get_cells -quiet [list core_inst/iface[2].mac[0].mac_rx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth2] [get_cells -quiet [list core_inst/iface[2].mac[0].tx_ptp_ts_fifo]]
#resize_pblock [get_pblocks pblock_eth2] -add {CLOCKREGION_X0Y3:CLOCKREGION_X0Y5}
#resize_pblock [get_pblocks pblock_eth2] -add {CLOCKREGION_X0Y24:CLOCKREGION_X0Y27}

#create_pblock pblock_eth3
#add_cells_to_pblock [get_pblocks pblock_eth3] [get_cells -quiet [list qsfp3_cmac_pad_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth3] [get_cells -quiet [list core_inst/iface[3].mac[0].mac_tx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth3] [get_cells -quiet [list core_inst/iface[3].mac[0].mac_rx_fifo_inst]]
#add_cells_to_pblock [get_pblocks pblock_eth3] [get_cells -quiet [list core_inst/iface[3].mac[0].tx_ptp_ts_fifo]]
#resize_pblock [get_pblocks pblock_eth3] -add {CLOCKREGION_X0Y3:CLOCKREGION_X0Y5}
#resize_pblock [get_pblocks pblock_eth3] -add {CLOCKREGION_X0Y32:CLOCKREGION_X0Y35}


