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
set fpga_id [expr 0x4B37093]
set fw_id [expr 0x00000000]
set fw_ver $tag_ver
set board_vendor_id [expr 0x10ee]
set board_device_id [expr 0x90c8]
set board_ver 1.0
set release_info [expr 0x00000000]

# PCIe IDs
set pcie_vendor_id [expr 0x1234]
set pcie_device_id [expr 0x1001]
set pcie_class_code [expr 0x020000]
set pcie_revision_id [expr 0x00]
set pcie_subsystem_vendor_id $board_vendor_id
set pcie_subsystem_device_id $board_device_id

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
dict set params CMS_ENABLE "1"
dict set params TDMA_BER_ENABLE "0"

# Transceiver configuration
set eth_xcvr_freerun_freq {125}
set eth_xcvr_line_rate {10.3125}
set eth_xcvr_refclk_freq {161.1328125}
set eth_xcvr_sec_line_rate {0}
set eth_xcvr_sec_refclk_freq $eth_xcvr_refclk_freq
set eth_xcvr_qpll_fracn [expr {int(fmod($eth_xcvr_line_rate*1000/2 / $eth_xcvr_refclk_freq, 1)*pow(2, 24))}]
set eth_xcvr_sec_qpll_fracn [expr {int(fmod($eth_xcvr_sec_line_rate*1000/2 / $eth_xcvr_sec_refclk_freq, 1)*pow(2, 24))}]
set eth_xcvr_rx_eq_mode {DFE}

# Structural configuration
dict set params IF_COUNT "2"
dict set params PORTS_PER_IF "1"
dict set params SCHED_PER_IF [dict get $params PORTS_PER_IF]
dict set params PORT_MASK "0"

# Clock configuration
dict set params CLK_PERIOD_NS_NUM "4"
dict set params CLK_PERIOD_NS_DENOM "1"

# PTP configuration
dict set params PTP_CLOCK_PIPELINE "0"
dict set params PTP_CLOCK_CDC_PIPELINE "0"
dict set params PTP_PORT_CDC_PIPELINE "0"
dict set params PTP_PEROUT_ENABLE "0"
dict set params PTP_PEROUT_COUNT "1"

# Queue manager configuration
dict set params EVENT_QUEUE_OP_TABLE_SIZE "32"
dict set params TX_QUEUE_OP_TABLE_SIZE "32"
dict set params RX_QUEUE_OP_TABLE_SIZE "32"
dict set params CQ_OP_TABLE_SIZE "32"
dict set params EQN_WIDTH "6"
dict set params TX_QUEUE_INDEX_WIDTH "13"
dict set params RX_QUEUE_INDEX_WIDTH "8"
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
dict set params PFC_ENABLE "1"
dict set params LFC_ENABLE [dict get $params PFC_ENABLE]
dict set params ENABLE_PADDING "1"
dict set params ENABLE_DIC "1"
dict set params MIN_FRAME_LENGTH "64"
dict set params TX_FIFO_DEPTH "32768"
dict set params RX_FIFO_DEPTH "65536"
dict set params MAX_TX_SIZE "9214"
dict set params MAX_RX_SIZE "9214"
dict set params TX_RAM_SIZE "32768"
dict set params RX_RAM_SIZE "32768"

# RAM configuration
dict set params DDR_CH "4"
dict set params DDR_ENABLE "0"
dict set params AXI_DDR_ID_WIDTH "8"
dict set params AXI_DDR_MAX_BURST_LEN "256"

# Application block configuration
dict set params APP_ID "32'h00000000"
dict set params APP_ENABLE "0"
dict set params APP_CTRL_ENABLE "1"
dict set params APP_DMA_ENABLE "1"
dict set params APP_AXIS_DIRECT_ENABLE "1"
dict set params APP_AXIS_SYNC_ENABLE "1"
dict set params APP_AXIS_IF_ENABLE "1"
dict set params APP_STAT_ENABLE "1"

# DMA interface configuration
dict set params DMA_IMM_ENABLE "0"
dict set params DMA_IMM_WIDTH "32"
dict set params DMA_LEN_WIDTH "16"
dict set params DMA_TAG_WIDTH "16"
dict set params RAM_ADDR_WIDTH [expr int(ceil(log(max([dict get $params TX_RAM_SIZE], [dict get $params RX_RAM_SIZE]))/log(2)))]
dict set params RAM_PIPELINE "2"

# Interrupt configuration
dict set params IRQ_INDEX_WIDTH [dict get $params EQN_WIDTH]

# AXI lite interface configuration (control)
dict set params AXIL_CTRL_DATA_WIDTH "32"
dict set params AXIL_CTRL_ADDR_WIDTH "24"

# AXI lite interface configuration (application control)
dict set params AXIL_APP_CTRL_DATA_WIDTH [dict get $params AXIL_CTRL_DATA_WIDTH]
dict set params AXIL_APP_CTRL_ADDR_WIDTH "24"

# Ethernet interface configuration
dict set params AXIS_ETH_SYNC_DATA_WIDTH_DOUBLE [expr max($eth_xcvr_line_rate, $eth_xcvr_sec_line_rate) > 16]
dict set params AXIS_ETH_TX_PIPELINE "4"
dict set params AXIS_ETH_TX_FIFO_PIPELINE "4"
dict set params AXIS_ETH_TX_TS_PIPELINE "4"
dict set params AXIS_ETH_RX_PIPELINE "4"
dict set params AXIS_ETH_RX_FIFO_PIPELINE "4"

# Statistics counter subsystem
dict set params STAT_ENABLE "1"
dict set params STAT_DMA_ENABLE "1"
dict set params STAT_PCIE_ENABLE "1"
dict set params STAT_INC_WIDTH "24"
dict set params STAT_ID_WIDTH "12"

# DDR4 MIG settings
if {[dict get $params DDR_ENABLE]} {
    set ddr4 [get_ips ddr4_0]

    # performance-related configuration
    set_property CONFIG.C0.DDR4_AxiArbitrationScheme {RD_PRI_REG} $ddr4
    set_property CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} $ddr4
    set_property CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} $ddr4

    # set AXI ID width
    set_property CONFIG.C0.DDR4_AxiIDWidth [dict get $params AXI_DDR_ID_WIDTH] $ddr4

    # extract AXI configuration
    dict set params AXI_DDR_DATA_WIDTH [get_property CONFIG.C0.DDR4_AxiDataWidth $ddr4]
    dict set params AXI_DDR_ADDR_WIDTH [get_property CONFIG.C0.DDR4_AxiAddressWidth $ddr4]
    dict set params AXI_DDR_NARROW_BURST [expr [get_property CONFIG.C0.DDR4_AxiNarrowBurst $ddr4] && 1]
}

# PCIe IP core settings
set pcie [get_ips pcie4_uscale_plus_0]

# Internal interface settings
dict set params AXIS_PCIE_DATA_WIDTH [regexp -all -inline -- {[0-9]+} [get_property CONFIG.axisten_if_width $pcie]]

# configure BAR settings
proc configure_bar {pcie pf bar aperture} {
    set size_list {Bytes Kilobytes Megabytes Gigabytes Terabytes Petabytes Exabytes}
    for { set i 0 } { $i < [llength $size_list] } { incr i } {
        set scale [lindex $size_list $i]

        if {$aperture > 0 && $aperture < ($i+1)*10} {
            set size [expr 1 << $aperture - ($i*10)]

            puts "${pcie} PF${pf} BAR${bar}: aperture ${aperture} bits ($size $scale)"

            set pcie_config [dict create]

            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_enabled" {true}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_type" {Memory}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_64bit" {true}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_prefetchable" {true}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_scale" $scale
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_size" $size

            set_property -dict $pcie_config $pcie

            return
        }
    }
    puts "${pcie} PF${pf} BAR${bar}: disabled"
    set_property "CONFIG.pf${pf}_bar${bar}_enabled" {false} $pcie
}

# Control BAR (BAR 0)
configure_bar $pcie 0 0 [dict get $params AXIL_CTRL_ADDR_WIDTH]

# Application BAR (BAR 2)
configure_bar $pcie 0 2 [expr [dict get $params APP_ENABLE] ? [dict get $params AXIL_APP_CTRL_ADDR_WIDTH] : 0]

# PCIe IP core configuration
set pcie_config [dict create]

# PCIe IDs
dict set pcie_config "CONFIG.vendor_id" [format "%04x" $pcie_vendor_id]
dict set pcie_config "CONFIG.PF0_DEVICE_ID" [format "%04x" $pcie_device_id]
dict set pcie_config "CONFIG.PF0_CLASS_CODE" [format "%06x" $pcie_class_code]
dict set pcie_config "CONFIG.PF0_REVISION_ID" [format "%02x" $pcie_revision_id]
dict set pcie_config "CONFIG.PF0_SUBSYSTEM_VENDOR_ID" [format "%04x" $pcie_subsystem_vendor_id]
dict set pcie_config "CONFIG.PF0_SUBSYSTEM_ID" [format "%04x" $pcie_subsystem_device_id]

# MSI-X
dict set pcie_config "CONFIG.pf0_msi_enabled" {false}
dict set pcie_config "CONFIG.pf0_msix_enabled" {true}
dict set pcie_config "CONFIG.PF0_MSIX_CAP_TABLE_SIZE" [format "%03x" [expr 2**[dict get $params IRQ_INDEX_WIDTH]-1]]
dict set pcie_config "CONFIG.PF0_MSIX_CAP_TABLE_BIR" {BAR_1:0}
dict set pcie_config "CONFIG.PF0_MSIX_CAP_TABLE_OFFSET" {00010000}
dict set pcie_config "CONFIG.PF0_MSIX_CAP_PBA_BIR" {BAR_1:0}
dict set pcie_config "CONFIG.PF0_MSIX_CAP_PBA_OFFSET" {00018000}
dict set pcie_config "CONFIG.MSI_X_OPTIONS" {MSI-X_External}

set_property -dict $pcie_config $pcie

# Transceiver configuration
set xcvr_config [dict create]

dict set xcvr_config CONFIG.TX_LINE_RATE $eth_xcvr_line_rate
dict set xcvr_config CONFIG.TX_QPLL_FRACN_NUMERATOR $eth_xcvr_qpll_fracn
dict set xcvr_config CONFIG.TX_REFCLK_FREQUENCY $eth_xcvr_refclk_freq
dict set xcvr_config CONFIG.RX_LINE_RATE $eth_xcvr_line_rate
dict set xcvr_config CONFIG.RX_QPLL_FRACN_NUMERATOR $eth_xcvr_qpll_fracn
dict set xcvr_config CONFIG.RX_REFCLK_FREQUENCY $eth_xcvr_refclk_freq
dict set xcvr_config CONFIG.RX_EQ_MODE $eth_xcvr_rx_eq_mode
if {$eth_xcvr_sec_line_rate != 0} {
    dict set xcvr_config CONFIG.SECONDARY_QPLL_ENABLE true
    dict set xcvr_config CONFIG.SECONDARY_QPLL_FRACN_NUMERATOR $eth_xcvr_sec_qpll_fracn
    dict set xcvr_config CONFIG.SECONDARY_QPLL_LINE_RATE $eth_xcvr_sec_line_rate
    dict set xcvr_config CONFIG.SECONDARY_QPLL_REFCLK_FREQUENCY $eth_xcvr_sec_refclk_freq
} else {
    dict set xcvr_config CONFIG.SECONDARY_QPLL_ENABLE false
}
dict set xcvr_config CONFIG.FREERUN_FREQUENCY $eth_xcvr_freerun_freq

set_property -dict $xcvr_config [get_ips eth_xcvr_gty_full]
set_property -dict $xcvr_config [get_ips eth_xcvr_gty_channel]

# apply parameters to top-level
set param_list {}
dict for {name value} $params {
    lappend param_list $name=$value
}

# set_property generic $param_list [current_fileset]
set_property generic $param_list [get_filesets sources_1]
