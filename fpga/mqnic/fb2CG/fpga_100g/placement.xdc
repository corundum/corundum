# Placement constraints
create_pblock pblock_pcie
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list pcie4_uscale_plus_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/core_inst/pcie_if_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/core_inst/core_pcie_inst/pcie_axil_master_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/core_inst/core_pcie_inst/dma_if_pcie_inst]]
resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X2Y0:CLOCKREGION_X3Y3}

# create_pblock pblock_eth
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet [list qsfp0_cmac_pad_inst]]
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet [list core_inst/iface[0].mac[0].mac_tx_fifo_inst core_inst/iface[0].mac[0].mac_rx_fifo_inst]]
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet [list qsfp1_cmac_pad_inst]]
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet [list core_inst/iface[1].mac[0].mac_tx_fifo_inst core_inst/iface[1].mac[0].mac_rx_fifo_inst]]
# resize_pblock [get_pblocks pblock_eth] -add {CLOCKREGION_X0Y6:CLOCKREGION_X0Y8}
