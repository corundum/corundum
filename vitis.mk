#!/usr/bin/make -f
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
##  File Name      : Makefile
##  Initial Author : Stefan Wiehler <stefan.wiehler@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Vitis convenience wrapper
##
##                   Uses: vitis xsct
##
################################################################################

ifeq ($(XILINX_VITIS),)
$(error XILINX_VITIS is unset. This Makefile must be invoked from within a Vitis environment)
endif

MAKEFILE_PATH := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

all: build

# include config
CFG ?= default
include $(CFG).mk

include $(MAKEFILE_PATH)common.mk

###############################################################################
# Variables

# platform project paths
HDF ?=
XPFM ?=

# user arguments, defaults, usually set via config.mk
DEF_DOMAIN_PROC ?= psu_cortexa53_0
DEF_DOMAIN_OS ?= standalone
DEF_APP_PROC ?= psu_cortexa53_0
DEF_APP_TMPL ?= Empty Application
DEF_APP_OS ?= standalone
DEF_APP_LANG ?= C
DEF_APP_BCFG ?= Release
DEF_APP_OPT ?= Optimize more (-O2)

DOMAIN_PRJS ?=
APP_PRJS ?=

# user arguments, rarely modified
PLAT_PRJ ?= plat
XSCT ?= xsct
VITIS ?= vitis

###############################################################################
# Platform repos

PLATS ?=

ifneq ($(strip $(PLATS)),)
__PLATS_CCMD = $(foreach PLAT,$(PLATS), \
	repo -add-platforms {$(PLAT)};)
endif

$(O)/.metadata/plats.stamp:
ifneq ($(strip $(PLATS)),)
	$(XSCT) -eval 'setws {$(O)}; $(__PLATS_CCMD)'
else
	mkdir -p $(O)/.metadata/
endif
	touch $@

###############################################################################
# Platform

# arg1: platform name
# arg2: path to platform file
define gen-plat-rule
$(O)/$(1)/hw/$(1).stamp: $(O)/.metadata/repos.stamp $(O)/.metadata/plats.stamp
ifneq ($(HDF),)
	$(XSCT) -eval 'setws {$(O)}; \
		platform create -name {$(1)} -hw {$(2)}'
else
ifneq ($(XPFM),)
	$(XSCT) -eval 'setws {$(O)}; \
		platform create -name {$(1)} -xpfm {$(XPFM)}'
	touch $(O)/$(1)/xpfm.stamp
else
	@echo "error: missing HDF or XPFM, run either with HDF=<path-to-.xsa-file> or XPFM=<path-to-.xpfm-file>" >&2
	@false
endif
endif
	touch $$@

# shortcut to create platform, "make <plat>"
$(1): $(O)/$(1)/hw/$(1).stamp
.PHONY: $(1)

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		platform remove -name {$(1)}'
.PHONY: $(1)_distclean
endef

###############################################################################
# Domains

# arg1: domain name
# arg2: platform name
define gen-domain-rule
$(1)_PROC ?= $(DEF_DOMAIN_PROC)
$(1)_OS ?= $(DEF_DOMAIN_OS)
$(1)_LIBS ?=
$(1)_EXTRA_CFLAGS ?=
$(1)_STDIN ?=
$(1)_STDOUT ?=
$(1)_IS_FSBL ?=

ifneq ($$strip($$($(1)_LIBS)),)
__$(1)_LIBS_CCMD = $$(foreach LIB,$$($(1)_LIBS), \
	bsp setlib -name {$$(LIB)};)
endif
__$(1)_EXTRA_CCMD =
ifneq ($$($(1)_EXTRA_CFLAGS),)
__$(1)_EXTRA_CCMD += \
	bsp config extra_compiler_flags {$$($(1)_EXTRA_CFLAGS)};
endif
ifneq ($$($(1)_STDIN),)
__$(1)_EXTRA_CCMD += \
	bsp config stdin {$$($(1)_STDIN)};
endif
ifneq ($$($(1)_STDOUT),)
__$(1)_EXTRA_CCMD += \
	bsp config stdout {$$($(1)_STDOUT)};
endif
ifeq ($$($(1)_IS_FSBL),yes)
# non-default BSP settings for FSBL
__$(1)_EXTRA_CCMD += \
	bsp config {zynqmp_fsbl_bsp} {true}; \
	bsp config {read_only} {true}; \
	bsp config {use_mkfs} {false}; \
	bsp config {extra_compiler_flags} {-g -Wall -Wextra -Os -flto -ffat-lto-objects};
endif

$(O)/$(2)/$$($(1)_PROC)/$(1)/bsp/Makefile: $(O)/$(2)/hw/$(2).stamp
	$(XSCT) -eval 'setws {$(O)}; \
		platform active {$(2)}; \
		domain create -name {$(1)} -proc {$$($(1)_PROC)} \
			-os {$$($(1)_OS)}; \
		$$(__$(1)_LIBS_CCMD) \
		$$(__$(1)_EXTRA_CCMD) \
		$$($(1)_POST_CREATE_TCL); \
		bsp regenerate'
ifneq ($$(strip $$($(1)_PATCH)),)
	$$(foreach PATCH,$$($(1)_PATCH),$(call patch-src,$(1),$$(PATCH))) :
endif
ifneq ($$(strip $$($(1)_SED)),)
	$$(foreach SED,$$($(1)_SED),$(call sed-src,$(1),$$(SED))) :
endif


$(O)/$(2)/export/$(2)/sw/$(2)/$(1)/bsplib/lib/libxil.a: $(O)/$(2)/$$($(1)_PROC)/$(1)/bsp/Makefile
	$(XSCT) -eval 'setws {$(O)}; \
		platform active {$(2)}; \
		platform generate -domains {$(1)}'

# shortcut to create domain, "make <domain>"
$(1): $(O)/$(2)/export/$(2)/sw/$(2)/$(1)/bsplib/lib/libxil.a
.PHONY: $(1)

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		platform active {$(2)}; \
		domain remove -name {$(1)}'
.PHONY: $(1)_distclean
endef

###############################################################################
# Applications

# arg1: app name
# arg2: src file/folder name, scheme <srcfile>
# Paths are normalized because Vitis does not accept relative paths
define import-src
importsources -name $(1) -path [file normalize $(2)] -soft-link;
endef

# arg1: app name
# arg2: platform name
define gen-app-rule
$(1)_PROC ?= $(DEF_APP_PROC)
$(1)_TMPL ?= $(DEF_APP_TMPL)
$(1)_OS ?= $(DEF_APP_OS)
$(1)_LANG ?= $(DEF_APP_LANG)
$(1)_BCFG ?= $(DEF_APP_BCFG)
$(1)_OPT ?= $(DEF_APP_OPT)

ifneq ($$strip($$($(1)_CPPSYMS)),)
__$(1)_CPPSYMS_CCMD = $$(foreach SYM,$$($(1)_CPPSYMS), \
	app config -name {$(1)} define-compiler-symbols {$$(SYM)};)
endif
ifneq ($$($(1)_HW),)
$(O)/$(1)/src/lscript.ld:
	$(XSCT) -eval 'setws {$(O)}; \
		app create -name {$(1)} -hw {$$($(1)_HW)} \
			-proc {$$($(1)_PROC)} -template {$$($(1)_TMPL)} \
			-os {$$($(1)_OS)} -lang {$$($(1)_LANG)}'
else
ifneq ($$($(1)_PLAT),)
$(O)/$(1)/src/lscript.ld:
	$(XSCT) -eval 'setws {$(O)}; \
		app create -name {$(1)} -platform {$$($(1)_PLAT)} \
			-domain {$$($(1)_DOMAIN)} \
			-proc {$$($(1)_PROC)} -template {$$($(1)_TMPL)} \
			-os {$$($(1)_OS)} -lang {$$($(1)_LANG)}; \
		app config -name {$(1)} build-config {$$($(1)_BCFG)}; \
		app config -name {$(1)} compiler-optimization {$$($(1)_OPT)}; \
		$$(__$(1)_CPPSYMS_CCMD) \
		$$($(1)_POST_CREATE_TCL)'
else
$(O)/$(1)/src/lscript.ld:
	$(XSCT) -eval 'setws {$(O)}; \
		app create -name {$(1)} -platform {$(2)} \
			-domain {$$($(1)_DOMAIN)} \
			-proc {$$($(1)_PROC)} -template {$$($(1)_TMPL)} \
			-os {$$($(1)_OS)} -lang {$$($(1)_LANG)}; \
		app config -name {$(1)} build-config {$$($(1)_BCFG)}; \
		app config -name {$(1)} compiler-optimization {$$($(1)_OPT)}; \
		$$(__$(1)_CPPSYMS_CCMD) \
		$$($(1)_POST_CREATE_TCL)'
endif
endif
ifneq ($$(strip $$($(1)_SRC)),)
	$(XSCT) -eval 'setws {$(O)}; \
		$$(foreach SRC,$$($(1)_SRC),$(call import-src,$(1),$$(SRC)))'
endif
ifneq ($$(strip $$($(1)_PATCH)),)
	$$(foreach PATCH,$$($(1)_PATCH),$(call patch-src,$(1)/src,$$(PATCH))) :
endif
ifneq ($$(strip $$($(1)_SED)),)
	$$(foreach SED,$$($(1)_SED),$(call sed-src,$(1)/src,$$(SED))) :
endif

$(O)/$(1)/$$($(1)_BCFG)/$(1).elf: $(O)/$(2)/export/$(2)/sw/$(2)/$$($(1)_DOMAIN)/bsplib/lib/libxil.a \
		$(O)/.metadata/repos.stamp $(O)/.metadata/plats.stamp $(O)/$(1)/src/lscript.ld \
		$$($(1)_SRC)
	$(XSCT) -eval 'setws {$(O)}; \
		app build -name {$(1)}'

GEN_APPS_DEP += $(O)/$(2)/export/$(2)/sw/$(2)/$$($(1)_DOMAIN)/bsplib/lib/libxil.a
BLD_APPS_DEP += $(O)/$(1)/$$($(1)_BCFG)/$(1).elf

# shortcut to create application, "make <app>"
$(1): $(O)/$(1)/$$($(1)_BCFG)/$(1).elf
.PHONY: $(1)

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		app remove {$(1)}'
.PHONY: $(1)_distclean

endef

###############################################################################
# Targets

# generate make rules for platform project, single
$(eval $(call gen-plat-rule,$(PLAT_PRJ),$(HDF)))
getdsa: $(PLAT_PRJ)
.PHONY: gethwplat

# generate make rules for domains, multiple
$(foreach DOMAIN_PRJ,$(DOMAIN_PRJS),\
	$(eval $(call gen-domain-rule,$(DOMAIN_PRJ),$(PLAT_PRJ))))

# generate make rules for apps, multiple
$(foreach APP_PRJ,$(APP_PRJS),\
	$(eval $(call gen-app-rule,$(APP_PRJ),$(PLAT_PRJ))))

# generate make rules for bootgen projects, multiple
$(foreach BOOTGEN_PRJ,$(BOOTGEN_PRJS),\
	$(eval $(call gen-bif-rule,$(BOOTGEN_PRJ))))

# generate all projects
generate: $(GEN_APPS_DEP) $(GEN_BOOTGEN_DEP)
.PHONY: generate

# build all projects
build: $(BLD_APPS_DEP) $(BLD_BOOTGEN_DEP)
.PHONY: build

# open workspace in GUI mode
vitis:
	$(VITIS) -workspace $(O)
.PHONY: vitis
