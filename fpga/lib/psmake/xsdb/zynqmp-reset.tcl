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
##  File Name      : zynqmp-reset.tcl
##  Initial Author : Stefan Wiehler <stefan.wiehler@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : petalinux-* convenience wrapper
##
##                   TCL script for XSDB to "reset" Zynq UltraScale+. PL is left
##                   unconfigured and PS CPU cores are stopped.
##
################################################################################

connect -url $::env(HW_SERVER_URL)

if {$::env(PETALINUX_VER) < 2018.3} {
	set ZYNQMP_UTILS "tools/hsm/scripts/sdk/util/zynqmp_utils.tcl"
} elseif {$::env(PETALINUX_VER) == 2018.3} {
	set ZYNQMP_UTILS "tools/xsct/SDK/2018.3/scripts/sdk/util/zynqmp_utils.tcl"
} elseif {$::env(PETALINUX_VER) == 2019.1} {
	set ZYNQMP_UTILS "tools/xsct/scripts/sdk/util/zynqmp_utils.tcl"
} else {
	set ZYNQMP_UTILS "tools/xsct/scripts/vitis/util/zynqmp_utils.tcl"
}
source $::env(PETALINUX)/$ZYNQMP_UTILS
targets -set -nocase -filter {name =~"APU*"} -index 1
rst -system
after 3000
targets -set -nocase -filter {name =~"APU*"} -index 1
reset_apu
targets -set -filter {level==0} -index 0
exit
