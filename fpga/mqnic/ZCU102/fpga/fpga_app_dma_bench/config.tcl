# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2021-2023 The Regents of the University of California

set params [dict create]

# collect build information
set build_date [clock seconds]
set git_hash 00000000
set git_tag ""

if { [catch {set git_hash [exec git rev-parse --short=8 HEAD]}] } {
    puts "Error running git or project not under version control"
}

if { [catch {set git_tag [exec git describe --tags HEAD]}] } {
    puts "Error running git, project not under version control, or no tag found"
}

puts "Build date: ${build_date}"
puts "Git hash: ${git_hash}"
puts "Git tag: ${git_tag}"

if { ! [regsub {^.*(\d+\.\d+\.\d+([\.-]\d+)?).*$} $git_tag {\1} tag_ver ] } {
    puts "Failed to extract version from git tag"
    set tag_ver 0.0.1
}

puts "Tag version: ${tag_ver}"

# FW and board IDs
set fpga_id [expr 0x4738093]
set fw_id [expr 0x00000000]
set fw_ver $tag_ver
set board_vendor_id [expr 0x10ee]
set board_device_id [expr 0x9066]
set board_ver 1.0
set release_info [expr 0x00000000]

# FW ID block
dict set params FPGA_ID [format "32'h%08x" $fpga_id]
dict set params FW_ID [format "32'h%08x" $fw_id]
dict set params FW_VER [format "32'h%02x%02x%02x%02x" {*}[split $fw_ver .-] 0 0 0 0]
dict set params BOARD_ID [format "32'h%04x%04x" $board_vendor_id $board_device_id]
dict set params BOARD_VER [format "32'h%02x%02x%02x%02x" {*}[split $board_ver .-] 0 0 0 0]
dict set params BUILD_DATE  "32'd${build_date}"
dict set params GIT_HASH  "32'h${git_hash}"
dict set params RELEASE_INFO  [format "32'h%08x" $release_info]

# Board configuration
dict set params TDMA_BER_ENABLE "0"

# Structural configuration
dict set params IF_COUNT "2"
dict set params PORTS_PER_IF "1"
dict set params SCHED_PER_IF [dict get $params PORTS_PER_IF]
dict set params PORT_MASK "0"

# Clock configuration
dict set params CLK_PERIOD_NS_NUM "10"
dict set params CLK_PERIOD_NS_DENOM "3"

# PTP configuration
dict set params PTP_CLOCK_PIPELINE "0"
dict set params PTP_CLOCK_CDC_PIPELINE "0"
dict set params PTP_PORT_CDC_PIPELINE "0"
dict set params PTP_PEROUT_ENABLE "1"
dict set params PTP_PEROUT_COUNT "1"

# Queue manager configuration
dict set params EVENT_QUEUE_OP_TABLE_SIZE "32"
dict set params TX_QUEUE_OP_TABLE_SIZE "32"
dict set params RX_QUEUE_OP_TABLE_SIZE "32"
dict set params CQ_OP_TABLE_SIZE "32"
dict set params EQN_WIDTH "2"
dict set params TX_QUEUE_INDEX_WIDTH "5"
dict set params RX_QUEUE_INDEX_WIDTH "5"
dict set params CQN_WIDTH [expr max([dict get $params TX_QUEUE_INDEX_WIDTH], [dict get $params RX_QUEUE_INDEX_WIDTH]) + 1]
dict set params EQ_PIPELINE "3"
dict set params TX_QUEUE_PIPELINE [expr 3 + max([dict get $params TX_QUEUE_INDEX_WIDTH] - 12, 0)]
dict set params RX_QUEUE_PIPELINE [expr 3 + max([dict get $params RX_QUEUE_INDEX_WIDTH] - 12, 0)]
dict set params CQ_PIPELINE [expr 3 + max([dict get $params CQN_WIDTH] - 12, 0)]

# TX and RX engine configuration
dict set params TX_DESC_TABLE_SIZE "32"
dict set params RX_DESC_TABLE_SIZE "32"
dict set params RX_INDIR_TBL_ADDR_WIDTH [expr min([dict get $params RX_QUEUE_INDEX_WIDTH], 8)]

# Scheduler configuration
dict set params TX_SCHEDULER_OP_TABLE_SIZE [dict get $params TX_DESC_TABLE_SIZE]
dict set params TX_SCHEDULER_PIPELINE [dict get $params TX_QUEUE_PIPELINE]
dict set params TDMA_INDEX_WIDTH "6"

# Interface configuration
dict set params PTP_TS_ENABLE "1"
dict set params TX_CPL_FIFO_DEPTH "32"
dict set params TX_CHECKSUM_ENABLE "1"
dict set params RX_HASH_ENABLE "1"
dict set params RX_CHECKSUM_ENABLE "1"
dict set params TX_FIFO_DEPTH "32768"
dict set params RX_FIFO_DEPTH "32768"
dict set params MAX_TX_SIZE "9214"
dict set params MAX_RX_SIZE "9214"
dict set params TX_RAM_SIZE "32768"
dict set params RX_RAM_SIZE "32768"

# RAM configuration
dict set params DDR_CH "1"
dict set params DDR_ENABLE "1"
dict set params AXI_DDR_ID_WIDTH "8"
dict set params AXI_DDR_MAX_BURST_LEN "256"

# Application block configuration
dict set params APP_ID "32'h12348001"
dict set params APP_ENABLE "1"
dict set params APP_CTRL_ENABLE "1"
dict set params APP_DMA_ENABLE "1"
dict set params APP_AXIS_DIRECT_ENABLE "1"
dict set params APP_AXIS_SYNC_ENABLE "1"
dict set params APP_AXIS_IF_ENABLE "1"
dict set params APP_STAT_ENABLE "1"

# AXI DMA interface configuration
open_bd_design [get_files zynq_ps.bd]
set s_axi_dma [get_bd_intf_ports s_axi_dma]
dict set params AXI_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $s_axi_dma]
# dict set params AXI_ADDR_WIDTH [get_property CONFIG.ADDR_WIDTH $s_axi_dma]
dict set params AXI_ADDR_WIDTH 64
dict set params AXI_ID_WIDTH [get_property CONFIG.ID_WIDTH $s_axi_dma]

# DMA interface configuration
dict set params DMA_IMM_ENABLE "0"
dict set params DMA_IMM_WIDTH "32"
dict set params DMA_LEN_WIDTH "16"
dict set params DMA_TAG_WIDTH "16"
dict set params RAM_ADDR_WIDTH [expr int(ceil(log(max([dict get $params TX_RAM_SIZE], [dict get $params RX_RAM_SIZE]))/log(2)))]
dict set params RAM_PIPELINE "2"
# NOTE: Querying the BD top-level interface port (or even the ZynqMP's interface
#       pin) yields 256 for the maximum burst length, instead of 16, which is
#       the actually supported length (due to ZynqMP using AXI3 internally).
#dict set params AXI_DMA_MAX_BURST_LEN [get_property CONFIG.MAX_BURST_LENGTH $s_axi_dma]
dict set params AXI_DMA_MAX_BURST_LEN "16"

# AXI lite interface configuration (control)
set m_axil_ctrl [get_bd_intf_ports m_axil_ctrl]
dict set params AXIL_CTRL_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $m_axil_ctrl]
dict set params AXIL_CTRL_ADDR_WIDTH 24

# AXI lite interface configuration (application control)
set m_axil_app_ctrl [get_bd_intf_ports m_axil_app_ctrl]
dict set params AXIL_APP_CTRL_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $m_axil_app_ctrl]
dict set params AXIL_APP_CTRL_ADDR_WIDTH 24

# Interrupt configuration
set irq [get_bd_ports pl_ps_irq0]
dict set params IRQ_COUNT [get_property CONFIG.PortWidth $irq]
close_bd_design [get_bd_designs zynq_ps]
dict set params IRQ_STRETCH "10"

# Ethernet interface configuration
dict set params AXIS_ETH_TX_PIPELINE "0"
dict set params AXIS_ETH_TX_FIFO_PIPELINE "2"
dict set params AXIS_ETH_TX_TS_PIPELINE "0"
dict set params AXIS_ETH_RX_PIPELINE "0"
dict set params AXIS_ETH_RX_FIFO_PIPELINE "2"

# Statistics counter subsystem
dict set params STAT_ENABLE "1"
dict set params STAT_DMA_ENABLE "1"
dict set params STAT_AXI_ENABLE "1"
dict set params STAT_INC_WIDTH "24"
dict set params STAT_ID_WIDTH "12"

# DDR4 MIG settings
if {[dict get $params DDR_ENABLE]} {
    set ddr4 [get_ips ddr4_0]

    # performance-related configuration
    set_property CONFIG.C0.DDR4_AxiArbitrationScheme {RD_PRI_REG} $ddr4
    set_property CONFIG.C0.DDR4_AUTO_AP_COL_A3 {false} $ddr4
    set_property CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK} $ddr4

    # set AXI ID width
    set_property CONFIG.C0.DDR4_AxiIDWidth [dict get $params AXI_DDR_ID_WIDTH] $ddr4

    # extract AXI configuration
    dict set params AXI_DDR_DATA_WIDTH [get_property CONFIG.C0.DDR4_AxiDataWidth $ddr4]
    dict set params AXI_DDR_ADDR_WIDTH [get_property CONFIG.C0.DDR4_AxiAddressWidth $ddr4]
    dict set params AXI_DDR_NARROW_BURST [expr [get_property CONFIG.C0.DDR4_AxiNarrowBurst $ddr4] && 1]
}

# apply parameters to top-level
set param_list {}
dict for {name value} $params {
    lappend param_list $name=$value
}

# set_property generic $param_list [current_fileset]
set_property generic $param_list [get_filesets sources_1]
