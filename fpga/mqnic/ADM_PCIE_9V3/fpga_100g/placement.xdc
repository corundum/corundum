# Placement constraints
create_pblock pblock_pcie
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "pcie4_uscale_plus_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/pcie_if_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/pcie_axil_master_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/dma_if_pcie_inst"]
resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X4Y0:CLOCKREGION_X5Y4}

# create_pblock pblock_eth
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "qsfp0_cmac_inst qsfp0_cmac_pad_inst"]
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "qsfp1_cmac_inst qsfp1_cmac_pad_inst"]
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].port[*].tx_async_fifo_inst"]
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].port[*].rx_async_fifo_inst"]
# add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].port[*].ptp.tx_ptp_ts_fifo_inst"]
# resize_pblock [get_pblocks pblock_eth] -add {CLOCKREGION_X0Y6:CLOCKREGION_X0Y8}
