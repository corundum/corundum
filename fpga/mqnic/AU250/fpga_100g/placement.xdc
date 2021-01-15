# Placement constraints
#create_pblock pblock_slr0
#add_cells_to_pblock [get_pblocks pblock_slr0] [get_cells -quiet [list ]]
#resize_pblock [get_pblocks pblock_slr0] -add {SLR0}

create_pblock pblock_slr1
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/dma_if_mux_inst]]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/iface[0].mac[0].tx_reg/pipe_reg[0].reg_inst core_inst/iface[0].mac[0].rx_reg/pipe_reg[2].reg_inst]]
add_cells_to_pblock [get_pblocks pblock_slr1] [get_cells -quiet [list core_inst/iface[1].mac[0].tx_reg/pipe_reg[0].reg_inst core_inst/iface[1].mac[0].rx_reg/pipe_reg[2].reg_inst]]
resize_pblock [get_pblocks pblock_slr1] -add {SLR1}

create_pblock pblock_slr2
add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet [list qsfp0_cmac_inst qsfp0_cmac_pad_inst]]
add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet [list core_inst/iface[0].mac[0].mac_tx_fifo_inst core_inst/iface[0].mac[0].mac_rx_fifo_inst]]
add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet [list core_inst/iface[0].mac[0].tx_reg/pipe_reg[2].reg_inst core_inst/iface[0].mac[0].rx_reg/pipe_reg[0].reg_inst]]
add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet [list qsfp1_cmac_inst qsfp1_cmac_pad_inst]]
add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet [list core_inst/iface[1].mac[0].mac_tx_fifo_inst core_inst/iface[1].mac[0].mac_rx_fifo_inst]]
add_cells_to_pblock [get_pblocks pblock_slr2] [get_cells -quiet [list core_inst/iface[1].mac[0].tx_reg/pipe_reg[2].reg_inst core_inst/iface[1].mac[0].rx_reg/pipe_reg[0].reg_inst]]
resize_pblock [get_pblocks pblock_slr2] -add {SLR2}

#create_pblock pblock_slr3
#add_cells_to_pblock [get_pblocks pblock_slr3] [get_cells -quiet [list ]]
#resize_pblock [get_pblocks pblock_slr3] -add {SLR3}

create_pblock pblock_pcie
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list pcie4_uscale_plus_inst]]
add_cells_to_pblock [get_pblocks pblock_pcie] [get_cells -quiet [list core_inst/dma_if_pcie_us_inst]]
resize_pblock [get_pblocks pblock_pcie] -add {SLICE_X176Y240:SLICE_X232Y479 DSP48E2_X25Y96:DSP48E2_X31Y191 RAMB18_X11Y96:RAMB18_X13Y191 RAMB36_X11Y48:RAMB36_X13Y95 URAM288_X4Y64:URAM288_X4Y127}
