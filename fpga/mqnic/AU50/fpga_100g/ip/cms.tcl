
# create block design
create_bd_design "cms"

# create CMS IP
set cms_block [create_bd_cell -type ip -vlnv xilinx.com:ip:cms_subsystem cms_subsystem_0]
make_bd_pins_external $cms_block
make_bd_intf_pins_external $cms_block

# assign addresses
assign_bd_address -target_address_space /s_axi_ctrl_0 [get_bd_addr_segs $cms_block/s_axi_ctrl/Mem0] -force

# save block design and create HDL wrapper
save_bd_design [current_bd_design]
add_files -norecurse [make_wrapper -files [get_files [get_property FILE_NAME [current_bd_design]]] -top]
close_bd_design [current_bd_design]
