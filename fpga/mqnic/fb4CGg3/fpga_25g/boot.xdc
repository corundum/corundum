# Timing constraints for FPGA boot logic

set_property ASYNC_REG TRUE [get_cells "fpga_boot_sync_reg_0_reg fpga_boot_sync_reg_1_reg"]
set_false_path -to [get_pins "fpga_boot_sync_reg_0_reg/D"]
