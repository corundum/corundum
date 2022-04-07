#!/usr/bin/make -f
# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2018-2019 Missing Link Electronics, Inc.
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
##  File Name      : Makefile
##  Initial Author : Joachim Foerster
##                   <joachim.foerster@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : xsct/xsdk convenience wrapper
##
##                   Uses: xsct xsdk
##
################################################################################

ifeq ($(XILINX_VIVADO),)
$(error XILINX_VIVADO is unset. This Makefile must be invoked from within a Vivado/XSDK environment)
endif

MAKEFILE_PATH := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

all: build

# include config
CFG ?= default
include $(CFG).mk

include $(MAKEFILE_PATH)common.mk

###############################################################################
# Variables

#  path to .hdf file exported from Vivado
HDF ?=

# user arguments, defaults, usually set via config.mk
DEF_BSP_OS ?= standalone
DEF_APP_LANG ?= C
DEF_APP_BCFG ?= Release
DEF_APP_OPT ?= Optimize more (-O2)
DEF_APP_TMPL ?= Empty Application
DEF_LIB_TYPE ?= static
DEF_LIB_OS ?= standalone
DEF_LIB_LANG ?= C
DEF_LIB_BCFG ?= Release
DEF_LIB_OPT ?= Optimize more (-O2)

BSP_PRJS ?=
APP_PRJS ?=

# user arguments, rarely modified
HW_PRJ ?= hw
XSCT ?= xsct
XSDK ?= xsdk

# internal settings
# <none>

###############################################################################
# Hardware Platform Project

# arg1: hw name
# arg2: path to hdf file
define gen-hw-rule
$(O)/$(1)/system.hdf: $(O)/.metadata/repos.stamp
ifeq ($(HDF),)
	@echo "error: missing HDF, run with HDF=<path-to-hdf>" >&2
	@false
endif
	$(XSCT) -eval 'setws {$(O)}; \
		createhw -name {$(1)} -hwspec {$(2)}; \
		$$($(1)_POST_CREATE_TCL)'

# shortcut to create hw, "make <hw>"
$(1): $(O)/$(1)/system.hdf
.PHONY: $(1)

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		deleteprojects -name {$(1)}'
.PHONY: $(1)_distclean
endef

###############################################################################
# Board Support Packages (BSPs)

# arg1: bsp name
# arg2: hw name
define gen-bsp-rule
$(1)_PROC ?=
$(1)_OS ?= $(DEF_BSP_OS)
ifeq ($$($(1)_PROC),psu_cortexa53_0)
$(1)_ARCH ?= 64
else
$(1)_ARCH ?= 32
endif
$(1)_LIBS ?=
$(1)_EXTRA_CFLAGS ?=
$(1)_STDIN ?=
$(1)_STDOUT ?=
$(1)_IS_FSBL ?=

ifneq ($$strip($$($(1)_LIBS)),)
__$(1)_LIBS_CCMD = $$(foreach LIB,$$($(1)_LIBS), \
	setlib -bsp {$(1)} -lib {$$(LIB)};)
endif
__$(1)_EXTRA_CCMD =
ifneq ($$($(1)_EXTRA_CFLAGS),)
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} extra_compiler_flags {$$($(1)_EXTRA_CFLAGS)};
endif
ifneq ($$($(1)_STDIN),)
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} stdin {$$($(1)_STDIN)};
endif
ifneq ($$($(1)_STDOUT),)
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} stdout {$$($(1)_STDOUT)};
endif
ifeq ($$($(1)_IS_FSBL),yes)
# non-default BSP settings for FSBL
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} {zynqmp_fsbl_bsp} {true}; \
	configbsp -bsp {$(1)} {read_only} {true}; \
	configbsp -bsp {$(1)} {use_mkfs} {false}; \
	configbsp -bsp {$(1)} {extra_compiler_flags} {-g -Wall -Wextra -Os -flto -ffat-lto-objects};
endif
$(O)/$(1)/system.mss: $(O)/$(2)/system.hdf
	$(XSCT) -eval 'setws {$(O)}; \
		createbsp -name {$(1)} -proc {$$($(1)_PROC)} \
			-hwproject {$(2)} -os {$$($(1)_OS)} \
			-arch {$$($(1)_ARCH)}; \
		$$(__$(1)_LIBS_CCMD) \
		$$(__$(1)_EXTRA_CCMD) \
		$$($(1)_POST_CREATE_TCL); \
		regenbsp -bsp {$(1)}'
ifneq ($$(strip $$($(1)_PATCH)),)
	$$(foreach PATCH,$$($(1)_PATCH),$(call patch-src,$(1),$$(PATCH))) :
endif
ifneq ($$(strip $$($(1)_SED)),)
	$$(foreach SED,$$($(1)_SED),$(call sed-src,$(1),$$(SED))) :
endif

$(O)/$(1)/$$($(1)_PROC)/lib/libxil.a: $(O)/$(2)/system.hdf $(O)/$(1)/system.mss
	$(XSCT) -eval 'setws {$(O)}; \
		projects -build -type bsp -name {$(1)}'

# shortcut to build bsp, "make <bsp>"
$(1): $(O)/$(1)/$$($(1)_PROC)/lib/libxil.a
.PHONY: $(1)

$(1)_clean:
	-$(XSCT) -eval 'setws {$(O)}; \
		projects -clean -type bsp -name {$(1)}'
.PHONY: $(1)_clean

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		deleteprojects -name {$(1)}'
.PHONY: $(1)_distclean
endef

###############################################################################
# Applications

# arg1: app name
define gen-app-proc-contents-rule
$$($(1)_PROC)
endef

# arg1: app name
# arg2: hw name
define gen-app-rule
$(1)_BSP ?=
$(1)_PROC ?= $(call gen-app-proc-contents-rule,$$($(1)_BSP))
$(1)_LANG ?= $(DEF_APP_LANG)
$(1)_BCFG ?= $(DEF_APP_BCFG)
$(1)_OPT ?= $(DEF_APP_OPT)
$(1)_TMPL ?= $(DEF_APP_TMPL)
$(1)_CPPSYMS ?=
$(1)_LIBS ?=

ifneq ($$strip($$($(1)_CPPSYMS)),)
__$(1)_CPPSYMS_CCMD = $$(foreach SYM,$$($(1)_CPPSYMS), \
	configapp -app {$(1)} define-compiler-symbols {$$(SYM)};)
endif
ifneq ($$(strip $$($(1)_LIBS)),)
__$(1)_LIBS_CCMD = $$(foreach LIB,$$($(1)_LIBS), \
	configapp -app {$(1)} include-path {../../$$(LIB)/src}; \
	configapp -app {$(1)} library-search-path {../../$$(LIB)/$$($$(LIB)_BCFG)}; \
	configapp -app {$(1)} libraries {$$(LIB)};)
endif
$(O)/$(1)/src/lscript.ld: $(O)/$$($(1)_BSP)/system.mss
	$(XSCT) -eval 'setws {$(O)}; \
		createapp -name {$(1)} -app {$$($(1)_TMPL)} \
			-proc {$$($(1)_PROC)} -hwproject {$(2)} \
			-bsp {$$($(1)_BSP)} -lang {$$($(1)_LANG)}; \
		configapp -app {$(1)} build-config {$$($(1)_BCFG)}; \
		configapp -app {$(1)} compiler-optimization {$$($(1)_OPT)}; \
		$$(__$(1)_CPPSYMS_CCMD) \
		$$(__$(1)_LIBS_CCMD) \
		$$($(1)_POST_CREATE_TCL)'
ifneq ($$(strip $$($(1)_SRC)),)
	$$(foreach SRC,$$($(1)_SRC),$(call symlink-src,$(1),$$(SRC))) :
endif
ifneq ($$(strip $$($(1)_PATCH)),)
	$$(foreach PATCH,$$($(1)_PATCH),$(call patch-src,$(1)/src,$$(PATCH))) :
endif
ifneq ($$(strip $$($(1)_SED)),)
	$$(foreach SED,$$($(1)_SED),$(call sed-src,$(1)/src,$$(SED))) :
endif

__$(1)_SRC = $(addprefix $(O)/$(1)/src/,$$($(1)_SRC))
$(O)/$(1)/$$($(1)_BCFG)/$(1).elf: $(O)/$$($(1)_BSP)/$$($(1)_PROC)/lib/libxil.a $(O)/$(1)/src/lscript.ld $$(__$(1)_SRC) $$($(1)_LIBS)
	$(XSCT) -eval 'setws {$(O)}; \
		projects -build -type app -name {$(1)}'

GEN_APPS_DEP += $(O)/$(1)/src/lscript.ld
BLD_APPS_DEP += $(O)/$(1)/$$($(1)_BCFG)/$(1).elf

# shortcut to build app, "make <app>"
$(1): $(O)/$(1)/$$($(1)_BCFG)/$(1).elf
.PHONY: $(1)

$(1)_clean:
	-$(XSCT) -eval 'setws {$(O)}; \
		projects -clean -type app -name {$(1)}'
.PHONY: $(1)_clean

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		deleteprojects -name {$(1)}'
.PHONY: $(1)_distclean
endef

###############################################################################
# Libraries

# arg1: lib name
define gen-lib-rule
$(1)_TYPE ?= $(DEF_LIB_TYPE)
$(1)_PROC ?= $(DEF_LIB_PROC)
$(1)_OS ?= $(DEF_LIB_OS)
$(1)_LANG ?= $(DEF_LIB_LANG)
ifeq ($$($(1)_PROC),psu_cortexa53)
$(1)_ARCH ?= 64
else
$(1)_ARCH ?= 32
endif
$(1)_BCFG ?= $(DEF_LIB_BCFG)
$(1)_OPT ?= $(DEF_LIB_OPT)
$(1)_CPPSYMS ?=

ifneq ($$strip($$($(1)_CPPSYMS)),)
__$(1)_CPPSYMS_CCMD = $$(foreach SYM,$$($(1)_CPPSYMS), \
	configapp -app {$(1)} define-compiler-symbols {$$(SYM)};)
endif
$(O)/$(1)/src:
	$(XSCT) -eval 'setws {$(O)}; \
		createlib -name {$(1)} -type {$$($(1)_TYPE)} \
			-proc {$$($(1)_PROC)} -os {$$($(1)_OS)} \
			-lang {$$($(1)_LANG)} -arch {$$($(1)_ARCH)}; \
		configapp -app {$(1)} build-config {$$($(1)_BCFG)}; \
		configapp -app {$(1)} compiler-optimization {$$($(1)_OPT)}; \
		$$(__$(1)_CPPSYMS_CCMD) \
		$$($(1)_POST_CREATE_TCL)'
ifneq ($$(strip $$($(1)_SRC)),)
	$$(foreach SRC,$$($(1)_SRC),$(call symlink-src,$(1),$$(SRC))) :
endif

__$(1)_SRC = $(addprefix $(O)/$(1)/src/,$$($(1)_SRC))
ifeq ($$($(1)_TYPE),shared)
$(O)/$(1)/$$($(1)_BCFG)/lib$(1).so: $(O)/$(1)/src
else
$(O)/$(1)/$$($(1)_BCFG)/lib$(1).a: $(O)/$(1)/src
endif
	$(XSCT) -eval 'setws {$(O)}; \
		projects -build -type app -name {$(1)}'
# Workaround for missing "lib" prefix
ifeq ($$($(1)_TYPE),shared)
	ln -fs $(1).so $(O)/$(1)/$$($(1)_BCFG)/lib$(1).so
endif

GEN_LIBS_DEP += $(O)/$(1)/src
ifeq ($$($(1)_TYPE),shared)
BLD_LIBS_DEP += $(O)/$(1)/$$($(1)_BCFG)/lib$(1).so
else
BLD_LIBS_DEP += $(O)/$(1)/$$($(1)_BCFG)/lib$(1).a
endif

# shortcut to build lib, "make <lib>"
ifeq ($$($(1)_TYPE),shared)
$(1): $(O)/$(1)/$$($(1)_BCFG)/lib$(1).so
else
$(1): $(O)/$(1)/$$($(1)_BCFG)/lib$(1).a
endif
.PHONY: $(1)

$(1)_clean:
	-$(XSCT) -eval 'setws {$(O)}; \
		projects -clean -type app -name {$(1)}'
.PHONY: $(1)_clean

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		deleteprojects -name {$(1)}'
.PHONY: $(1)_distclean
endef

###############################################################################
# Targets

# generate make rules for hardware project, single
$(eval $(call gen-hw-rule,$(HW_PRJ),$(HDF)))
gethdf: $(HW_PRJ)
.PHONY: gethdf

# generate make rules for bsp projects, multiple
$(foreach BSP_PRJ,$(BSP_PRJS),\
	$(eval $(call gen-bsp-rule,$(BSP_PRJ),$(HW_PRJ))))

# generate make rules for application projects, multiple
$(foreach APP_PRJ,$(APP_PRJS),\
	$(eval $(call gen-app-rule,$(APP_PRJ),$(HW_PRJ))))

# generate make rules for library projects, multiple
$(foreach LIB_PRJ,$(LIB_PRJS),\
	$(eval $(call gen-lib-rule,$(LIB_PRJ))))

# generate make rules for bootgen projects, multiple
$(foreach BOOTGEN_PRJ,$(BOOTGEN_PRJS),\
	$(eval $(call gen-bif-rule,$(BOOTGEN_PRJ))))

# generate all (app) projects
generate: $(GEN_APPS_DEP) $(GEN_BOOTGEN_DEP)
.PHONY: generate

# build all (app) projects
build: $(BLD_APPS_DEP) $(BLD_BOOTGEN_DEP)
.PHONY: build

# open workspace in GUI mode
xsdk:
	$(XSDK) -workspace $(O)
.PHONY: xsdk

# clean all projects
clean:
	$(XSCT) -eval 'setws {$(O)}; \
		projects -clean -type all'
.PHONY: clean
