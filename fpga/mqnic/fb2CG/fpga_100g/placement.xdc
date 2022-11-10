# Placement constraints
create_pblock pblock_pcie
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "pcie4_uscale_plus_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/pcie_if_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/pcie_axil_master_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/dma_if_pcie_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/pcie_msix_inst"]
resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X2Y0:CLOCKREGION_X3Y3}

create_pblock pblock_eth
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "qsfp_0_cmac_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "qsfp_1_cmac_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/port[*].port_inst/port_tx_inst/tx_async_fifo_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/port[*].port_inst/port_rx_inst/rx_async_fifo_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/port[*].port_inst/port_tx_inst/tx_cpl_fifo_inst"]
resize_pblock [get_pblocks pblock_eth] -add {CLOCKREGION_X0Y6:CLOCKREGION_X0Y8}

# CMACs
set_property LOC CMACE4_X0Y1 [get_cells -hierarchical -filter {NAME =~ qsfp_0_cmac_inst/cmac_inst/inst/i_cmac_usplus_top/* && REF_NAME==CMACE4}]
set_property LOC CMACE4_X0Y2 [get_cells -hierarchical -filter {NAME =~ qsfp_1_cmac_inst/cmac_inst/inst/i_cmac_usplus_top/* && REF_NAME==CMACE4}]
