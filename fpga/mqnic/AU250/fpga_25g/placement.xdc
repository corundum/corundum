# Placement constraints
create_pblock pblock_slr0
#add_cells_to_pblock [get_pblocks pblock_slr0] [get_cells -quiet ""]
resize_pblock [get_pblocks pblock_slr0] -add {SLR0}

create_pblock pblock_slr1
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/dma_if_mux_inst"]
add_cells_to_pblock -quiet [get_pblocks pblock_slr1] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/dma_if_mux.dma_if_mux_ctrl_inst"]
add_cells_to_pblock -quiet [get_pblocks pblock_slr1] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/dma_if_mux.dma_if_mux_data_inst"]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/interface_rx_inst"]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/interface_tx_inst"]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/tx_fifo_inst"]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/rx_fifo_inst"]
resize_pblock [get_pblocks pblock_slr1] -add {SLR1}

create_pblock pblock_slr2
#add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet ""]
resize_pblock [get_pblocks pblock_slr2] -add {SLR2}

create_pblock pblock_slr3
#add_cells_to_pblock [get_pblocks pblock_slr3] [get_cells -quiet ""]
resize_pblock [get_pblocks pblock_slr3] -add {SLR3}

create_pblock pblock_pcie
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "pcie4_uscale_plus_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/pcie_if_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/pcie_axil_master_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/dma_if_pcie_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/pcie_msix_inst"]
resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X6Y4:CLOCKREGION_X7Y7}

create_pblock pblock_eth
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "qsfp0_phy_quad_inst qsfp1_phy_quad_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/mac[*].eth_mac_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/port[*].port_inst/port_tx_inst/tx_async_fifo_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/port[*].port_inst/port_rx_inst/rx_async_fifo_inst"]
add_cells_to_pblock [get_pblocks pblock_eth] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/core_inst/iface[*].interface_inst/port[*].port_inst/port_tx_inst/tx_cpl_fifo_inst"]
resize_pblock [get_pblocks pblock_eth] -add {CLOCKREGION_X7Y8:CLOCKREGION_X7Y11}
