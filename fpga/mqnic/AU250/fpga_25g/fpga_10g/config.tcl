# Copyright 2021, The Regents of the University of California.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
# IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of The Regents of the University of California.

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
set fpga_id [expr 0x4B57093]
set fw_id [expr 0x00000000]
set fw_ver $tag_ver
set board_vendor_id [expr 0x10ee]
set board_device_id [expr 0x90fa]
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

# Transceiver configuration
set eth_xcvr_freerun_freq {125}
set eth_xcvr_line_rate {10.3125}
set eth_xcvr_sec_line_rate {0}
set eth_xcvr_refclk_freq {161.1328125}
set eth_xcvr_qpll_fracn [expr {int(fmod($eth_xcvr_line_rate*1000/2 / $eth_xcvr_refclk_freq, 1)*pow(2, 24))}]
set eth_xcvr_sec_qpll_fracn [expr {int(fmod($eth_xcvr_sec_line_rate*1000/2 / $eth_xcvr_refclk_freq, 1)*pow(2, 24))}]
set eth_xcvr_rx_eq_mode {DFE}

# Structural configuration

#  counts    QSFP 0                                QSFP 1
# IF  PORT   0_1      0_2      0_3      0_4        1_1      1_2      1_3      1_4
# 1   1      0 (0.0)
# 1   2      0 (0.0)  1 (0.1)
# 1   3      0 (0.0)  1 (0.1)  2 (0.2)
# 1   4      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)
# 1   5      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)
# 1   6      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)  5 (0.5)
# 1   7      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)  5 (0.5)  6 (0.6)
# 1   8      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (0.4)  5 (0.5)  6 (0.6)  7 (0.7)
# 2   1      0 (0.0)                               1 (1.0)
# 2   2      0 (0.0)  1 (0.1)                      2 (1.0)  3 (1.1)
# 2   3      0 (0.0)  1 (0.1)  2 (0.2)             3 (1.0)  4 (1.1)  5 (1.2)
# 2   4      0 (0.0)  1 (0.1)  2 (0.2)  3 (0.3)    4 (1.0)  5 (1.1)  6 (1.2)  7 (1.3)
# 3   1      0 (0.0)  1 (1.0)  2 (2.0)
# 3   2      0 (0.0)  1 (0.1)  2 (1.0)  3 (1.1)    4 (2.0)  5 (2.1)
# 4   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)
# 4   2      0 (0.0)  1 (0.1)  2 (1.0)  3 (1.1)    4 (2.0)  5 (2.1)  6 (3.0)  7 (3.1)
# 5   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)
# 6   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)  5 (5.0)
# 7   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)  5 (5.0)  6 (6.0)
# 8   1      0 (0.0)  1 (1.0)  2 (2.0)  3 (3.0)    4 (4.0)  5 (5.0)  6 (6.0)  7 (7.0)

dict set params IF_COUNT "2"
dict set params PORTS_PER_IF "1"
dict set params SCHED_PER_IF [dict get $params PORTS_PER_IF]

# PTP configuration
dict set params PTP_CLOCK_PIPELINE "0"
dict set params PTP_PORT_CDC_PIPELINE "0"
dict set params PTP_PEROUT_ENABLE "0"
dict set params PTP_PEROUT_COUNT "1"

# Queue manager configuration (interface)
dict set params EVENT_QUEUE_OP_TABLE_SIZE "32"
dict set params TX_QUEUE_OP_TABLE_SIZE "32"
dict set params RX_QUEUE_OP_TABLE_SIZE "32"
dict set params TX_CPL_QUEUE_OP_TABLE_SIZE [dict get $params TX_QUEUE_OP_TABLE_SIZE]
dict set params RX_CPL_QUEUE_OP_TABLE_SIZE [dict get $params RX_QUEUE_OP_TABLE_SIZE]
dict set params EVENT_QUEUE_INDEX_WIDTH "5"
dict set params TX_QUEUE_INDEX_WIDTH "13"
dict set params RX_QUEUE_INDEX_WIDTH "8"
dict set params TX_CPL_QUEUE_INDEX_WIDTH [dict get $params TX_QUEUE_INDEX_WIDTH]
dict set params RX_CPL_QUEUE_INDEX_WIDTH [dict get $params RX_QUEUE_INDEX_WIDTH]
dict set params EVENT_QUEUE_PIPELINE "3"
dict set params TX_QUEUE_PIPELINE [expr 3+([dict get $params TX_QUEUE_INDEX_WIDTH] > 12 ? [dict get $params TX_QUEUE_INDEX_WIDTH]-12 : 0)]
dict set params RX_QUEUE_PIPELINE [expr 3+([dict get $params RX_QUEUE_INDEX_WIDTH] > 12 ? [dict get $params RX_QUEUE_INDEX_WIDTH]-12 : 0)]
dict set params TX_CPL_QUEUE_PIPELINE [dict get $params TX_QUEUE_PIPELINE]
dict set params RX_CPL_QUEUE_PIPELINE [dict get $params RX_QUEUE_PIPELINE]

# TX and RX engine configuration (port)
dict set params TX_DESC_TABLE_SIZE "32"
dict set params RX_DESC_TABLE_SIZE "32"

# Scheduler configuration (port)
dict set params TX_SCHEDULER_OP_TABLE_SIZE [dict get $params TX_DESC_TABLE_SIZE]
dict set params TX_SCHEDULER_PIPELINE [dict get $params TX_QUEUE_PIPELINE]
dict set params TDMA_INDEX_WIDTH "6"

# Timestamping configuration (port)
dict set params PTP_TS_ENABLE "1"
dict set params TX_PTP_TS_FIFO_DEPTH "32"
dict set params RX_PTP_TS_FIFO_DEPTH "32"

# Interface configuration (port)
dict set params TX_CHECKSUM_ENABLE "1"
dict set params RX_RSS_ENABLE "1"
dict set params RX_HASH_ENABLE "1"
dict set params RX_CHECKSUM_ENABLE "1"
dict set params TX_FIFO_DEPTH "32768"
dict set params RX_FIFO_DEPTH "32768"
dict set params MAX_TX_SIZE "9214"
dict set params MAX_RX_SIZE "9214"
dict set params TX_RAM_SIZE "32768"
dict set params RX_RAM_SIZE "32768"
 
# Application block configuration
dict set params APP_ENABLE "0"
dict set params APP_CTRL_ENABLE "1"
dict set params APP_DMA_ENABLE "1"
dict set params APP_AXIS_DIRECT_ENABLE "1"
dict set params APP_AXIS_SYNC_ENABLE "1"
dict set params APP_AXIS_IF_ENABLE "1"
dict set params APP_STAT_ENABLE "1"

# DMA interface configuration
dict set params DMA_LEN_WIDTH "16"
dict set params DMA_TAG_WIDTH "16"
dict set params RAM_ADDR_WIDTH [expr int(ceil(log(max([dict get $params TX_RAM_SIZE], [dict get $params RX_RAM_SIZE]))/log(2)))]
dict set params RAM_PIPELINE "2"

# PCIe interface configuration
dict set params PCIE_TAG_COUNT "64"
dict set params PCIE_DMA_READ_OP_TABLE_SIZE [dict get $params PCIE_TAG_COUNT]
dict set params PCIE_DMA_READ_TX_LIMIT "16"
dict set params PCIE_DMA_READ_TX_FC_ENABLE "1"
dict set params PCIE_DMA_WRITE_OP_TABLE_SIZE "16"
dict set params PCIE_DMA_WRITE_TX_LIMIT "3"
dict set params PCIE_DMA_WRITE_TX_FC_ENABLE "1"

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

# PCIe IP core settings
set pcie [get_ips pcie4_uscale_plus_0]

# PCIe IDs
set_property CONFIG.vendor_id [format "%04x" $pcie_vendor_id] $pcie
set_property CONFIG.PF0_DEVICE_ID [format "%04x" $pcie_device_id] $pcie
set_property CONFIG.PF0_CLASS_CODE [format "%06x" $pcie_class_code] $pcie
set_property CONFIG.PF0_REVISION_ID [format "%02x" $pcie_revision_id] $pcie
set_property CONFIG.PF0_SUBSYSTEM_VENDOR_ID [format "%04x" $pcie_subsystem_vendor_id] $pcie
set_property CONFIG.PF0_SUBSYSTEM_ID [format "%04x" $pcie_subsystem_device_id] $pcie

# Internal interface settings
dict set params AXIS_PCIE_DATA_WIDTH [regexp -all -inline -- {[0-9]+} [get_property CONFIG.axisten_if_width $pcie]]
dict set params AXIS_PCIE_KEEP_WIDTH [expr [dict get $params AXIS_PCIE_DATA_WIDTH]/32]
dict set params AXIS_PCIE_RC_USER_WIDTH [expr [dict get $params AXIS_PCIE_DATA_WIDTH] < 512 ? 75 : 161]
dict set params AXIS_PCIE_RQ_USER_WIDTH [expr [dict get $params AXIS_PCIE_DATA_WIDTH] < 512 ? 62 : 137]
dict set params AXIS_PCIE_CQ_USER_WIDTH [expr [dict get $params AXIS_PCIE_DATA_WIDTH] < 512 ? 85 : 183]
dict set params AXIS_PCIE_CC_USER_WIDTH [expr [dict get $params AXIS_PCIE_DATA_WIDTH] < 512 ? 33 : 81]
dict set params RQ_SEQ_NUM_WIDTH [expr [dict get $params AXIS_PCIE_RQ_USER_WIDTH] == 60 ? 4 : 6]

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
    dict set xcvr_config CONFIG.SECONDARY_QPLL_REFCLK_FREQUENCY $eth_xcvr_refclk_freq
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
