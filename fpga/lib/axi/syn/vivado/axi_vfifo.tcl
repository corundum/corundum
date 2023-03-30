# Copyright (c) 2023 Alex Forencich
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# AXI virtual FIFO timing constraints

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == axi_vfifo || REF_NAME == axi_vfifo)}] {
    puts "Inserting timing constraints for axil_vfifo instance $inst"

    proc constrain_sync_chain {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set src_clk [get_clocks -of_objects [get_cells "$inst/$driver"]]

            set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

            set_max_delay -from [get_cells "$inst/$driver"] -to [get_cells "$inst/[lindex $args 0]"] -datapath_only $src_clk_period
        }
    }

    proc constrain_sync_chain_async {inst driver args} {
        set sync_ffs [get_cells -hier [concat $driver $args] -filter "PARENT == $inst"]

        if {[llength $sync_ffs]} {
            set_property ASYNC_REG TRUE $sync_ffs

            set_false_path -to [get_pins "$inst/$driver/D"]
        }
    }

    # control
    constrain_sync_chain $inst "cfg_enable_reg_reg" "axi_ch[*].ch_cfg_enable_sync_1_reg_reg" "axi_ch[*].ch_cfg_enable_sync_2_reg_reg"
    constrain_sync_chain $inst "cfg_reset_reg_reg" "axi_ch[*].ch_cfg_reset_sync_1_reg_reg" "axi_ch[*].ch_cfg_reset_sync_2_reg_reg"

    set sync_ffs [get_cells "$inst/cfg_fifo_base_addr_reg_reg[*] $inst/axi_ch[*].axi_vfifo_raw_inst/fifo_base_addr_reg_reg[*]"]
    
    if {[llength $sync_ffs]} {
        set_property ASYNC_REG TRUE $sync_ffs

        set src_clk [get_clocks -of_objects [get_cells "$inst/cfg_fifo_base_addr_reg_reg[*]"]]

        set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

        set_max_delay -from [get_cells "$inst/cfg_fifo_base_addr_reg_reg[*]"] -to [get_cells "$inst/axi_ch[*].axi_vfifo_raw_inst/fifo_base_addr_reg_reg[*]"] -datapath_only $src_clk_period
    }

    set sync_ffs [get_cells "$inst/cfg_fifo_size_mask_reg_reg[*] $inst/axi_ch[*].axi_vfifo_raw_inst/fifo_size_mask_reg_reg[*]"]
    
    if {[llength $sync_ffs]} {
        set_property ASYNC_REG TRUE $sync_ffs

        set src_clk [get_clocks -of_objects [get_cells "$inst/cfg_fifo_size_mask_reg_reg[*]"]]

        set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

        set_max_delay -from [get_cells "$inst/cfg_fifo_size_mask_reg_reg[*]"] -to [get_cells "$inst/axi_ch[*].axi_vfifo_raw_inst/fifo_size_mask_reg_reg[*]"] -datapath_only $src_clk_period
    }

    # status
    constrain_sync_chain $inst "sts_sync_flag_reg_reg" "axi_ch[*].ch_sts_flag_sync_1_reg_reg" "axi_ch[*].ch_sts_flag_sync_2_reg_reg"
    constrain_sync_chain_async $inst "sts_fifo_occupancy_sync_reg_reg[*]"

    constrain_sync_chain_async $inst "sts_fifo_empty_sync_1_reg_reg[*]" "sts_fifo_empty_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "sts_fifo_full_sync_1_reg_reg[*]" "sts_fifo_full_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "sts_reset_sync_1_reg_reg[*]" "sts_reset_sync_2_reg_reg[*]"
    constrain_sync_chain_async $inst "sts_active_sync_1_reg_reg[*]" "sts_active_sync_2_reg_reg[*]"
    constrain_sync_chain $inst "sts_hdr_parity_err_reg_reg" "sts_hdr_parity_err_sync_1_reg_reg" "sts_hdr_parity_err_sync_2_reg_reg"
}
