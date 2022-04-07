# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2019-2020 Missing Link Electronics, Inc.
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
##  File Name      : default.mk
##  Initial Author : Stefan Wiehler <stefan.wiehler@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Example for Vitis Makefile
##
##                   Build with default fixed platform for ZC102:
##
##                       $ make HW_PLAT=zcu102
##
##                   Also provide PLATS variable if default does not fit.
##
################################################################################

# FSBL

DOMAIN_PRJS += fsbl_bsp
fsbl_bsp_PROC = psu_cortexa53_0
fsbl_bsp_IS_FSBL = yes
fsbl_bsp_LIBS = xilffs xilsecure xilpm
fsbl_bsp_POST_CREATE_TCL = bsp config use_strfunc 1

APP_PRJS += fsbl
fsbl_TMPL = Zynq MP FSBL
fsbl_DOMAIN = fsbl_bsp
fsbl_CPPSYMS = FSBL_DEBUG_DETAILED

################################################################################
# Hello World

DOMAIN_PRJS += gen_bsp
gen_bsp_PROC = psu_cortexa53_0
gen_bsp_EXTRA_CFLAGS = -g -Wall -Wextra -Os
gen_bsp_STDOUT = psu_uart_1

APP_PRJS += helloworld
helloworld_TMPL = Hello World
helloworld_DOMAIN = gen_bsp
helloworld_BCFG = Debug
helloworld_PATCH = helloworld.patch
helloworld_SED = platform.c;baud_rate.sed

APP_PRJS += example_app
example_app_TMPL = Empty Application
example_app_DOMAIN = gen_bsp
example_app_BCFG = Debug
example_app_SRC = example_app

################################################################################
# Boot image

BOOTGEN_PRJS += bootbin

bootbin_BIF_ARCH = zynqmp
bootbin_BIF_ATTRS = fsbl helloworld
bootbin_fsbl_BIF_ATTR = bootloader, destination_cpu=a53-0
bootbin_fsbl_BIF_FILE = fsbl/$(fsbl_BCFG)/fsbl.elf
bootbin_helloworld_BIF_ATTR = destination_cpu=a53-0
bootbin_helloworld_BIF_FILE = helloworld/$(helloworld_BCFG)/helloworld.elf

################################################################################
# Key generation

BOOTGEN_PRJS += generate_pem

generate_pem_BIF_ARCH = zynqmp
generate_pem_BIF_NO_OUTPUT = yes
generate_pem_BIF_ARGS_EXTRA = -p zu9eg -generate_keys pem
generate_pem_BIF_ATTRS = pskfile sskfile fsbl
generate_pem_pskfile_BIF_ATTR = pskfile
generate_pem_pskfile_BIF_FILE = generate_pem/psk0.pem
generate_pem_pskfile_BIF_FILE_NO_DEP = yes
generate_pem_sskfile_BIF_ATTR = sskfile
generate_pem_sskfile_BIF_FILE = generate_pem/ssk0.pem
generate_pem_sskfile_BIF_FILE_NO_DEP = yes
generate_pem_fsbl_BIF_ATTR = bootloader, destination_cpu=a53-0
generate_pem_fsbl_BIF_FILE = fsbl/$(fsbl_BCFG)/fsbl.elf
