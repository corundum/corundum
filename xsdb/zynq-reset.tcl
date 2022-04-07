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
##  File Name      : zynq-reset.tcl
##  Initial Author : Joachim Foerster
##                   <joachim.foerster@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : petalinux-* convenience wrapper
##
##                   TCL script for XSDB to "reset" Zynq 7000. PL is left
##                   unconfigured and PS CPU cores are stopped.
##
################################################################################

if {![info exists ::env(HW_SERVER_URL)]} {
	puts stderr "error: environment variable HW_SERVER_URL not set"
	exit 1
}

connect -url $::env(HW_SERVER_URL)

puts "Trigger system reset on APU ..."
targets -set -filter {name =~ "APU"}
rst -system
puts "done."

disconnect
