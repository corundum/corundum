# Placement constraints
create_pblock pblock_pcie
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "pcie4_uscale_plus_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/pcie_if_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/pcie_axil_master_inst"]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet "core_inst/core_inst/core_pcie_inst/dma_if_pcie_inst"]
resize_pblock [get_pblocks pblock_pcie] -add {CLOCKREGION_X2Y0:CLOCKREGION_X3Y3}
