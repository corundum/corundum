# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2019 Missing Link Electronics, Inc.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
################################################################################
##
##  File Name      : zynq-boot-psinit-uboot.tcl
##  Initial Author : Joachim Foerster
##                   <joachim.foerster@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : petalinux-* convenience wrapper
##
##                   TCL script for XSDB to "boot" Zynq 7000 into U-Boot via
##                   JTAG using ps7_init TCL function instead of FSBL
##                   executable. Thus no FSBL hook code is executed.
##
################################################################################


if {![info exists ::env(HW_SERVER_URL)]} {
	puts stderr "error: environment variable HW_SERVER_URL not set"
	exit 1
}

# use PetaLinux built-in defaults if user does not specify certain items
set PS7INIT "project-spec/hw-description/ps7_init.tcl"
if {[info exists ::env(BIT)]} {
	set BIT $::env(BIT)
} else {
	set BIT "images/linux/system.bit"
}
if {[info exists ::env(UBOOT)]} {
	set UBOOT $::env(UBOOT)
} else {
	set UBOOT "images/linux/u-boot.elf"
}

if {![file exists $PS7INIT]} {
	puts stderr "error: required file $PS7INIT does not exist"
	exit 1
}
if {![file exists $BIT]} {
	puts stderr "error: required file $BIT does not exist"
	exit 1
}
if {![file exists $UBOOT]} {
	puts stderr "error: required file $UBOOT does not exist"
	exit 1
}

source $PS7INIT

connect -url $::env(HW_SERVER_URL)

puts "Execute ps7_init TCL proc ..."
targets -set -filter {name =~ "ARM*#0"}
ps7_init
puts "done."

puts "Download bitstream $BIT ..."
fpga $BIT
puts "done."

puts "Execute ps7_post_config TCL proc ..."
targets -set -filter {name =~ "ARM*#0"}
ps7_post_config
puts "done."

puts "Download U-Boot executable $UBOOT ..."
targets -set -filter {name =~ "ARM*#0"}
dow $UBOOT
puts "done."

puts "Start U-Boot ..."
con
puts "done."

disconnect
