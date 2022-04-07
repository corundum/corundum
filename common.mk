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
##  File Name      : common.mk
##  Initial Author : Stefan Wiehler <stefan.wiehler@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : XSDK/Vitis common functionality
##
##                   Uses: bootgen cat git mkdir patch rm sed touch
##
################################################################################


################################################################################
# VCS

# user arguments
VCS_SKIP ?=

# get version control information
ifeq ($(VCS_SKIP),)
VCS_HEAD := $(shell git rev-parse --verify --short HEAD 2>/dev/null)
endif
ifneq ($(VCS_HEAD),)
VCS_DIRTY := $(shell git diff-index --name-only HEAD | head -n 1)
VCS_VER := _g$(VCS_HEAD)$(patsubst %,-dirty,$(VCS_DIRTY))
else
VCS_VER :=
endif

# get build time stamp
BSTAMP := $(shell date +%Y%m%d-%H%M%S)

# user arguments, usually provided on command line
#  container for build directories (= xsdk workspaces)
CNTR ?= build
#  build directory name
BLDN ?= $(CFG)_$(BSTAMP)$(VCS_VER)
#  relative path to build directory
O ?= $(CNTR)/$(BLDN)

###############################################################################
# Repositories

REPOS ?=

ifneq ($(strip $(REPOS)),)
__REPOS_CCMD = $(foreach REPO,$(REPOS), \
	repo -set {$(REPO)};)
endif

$(O)/.metadata/repos.stamp:
ifneq ($(strip $(REPOS)),)
	$(XSCT) -eval 'setws {$(O)}; $(__REPOS_CCMD)'
else
	mkdir -p $(O)/.metadata/
endif
	touch $@

###############################################################################
# Source symlinking, patch and sed rules

# arg1: app name
# arg2: src file name, scheme <srcfile>
define symlink-src
rm -f $(O)/$(1)/src/$$(notdir $(2)) && \
ln -s ../../../../$(2) $(O)/$(1)/src/$$(notdir $(2)) &&
endef

# arg1: app name
# arg2: patch file name, scheme <patchfile>[;<stripnum>]
define patch-src
patch -d $(O)/$(1)/ -p$$(subst ,1,$$(word 2,$$(subst ;, ,$(2)))) \
	<$$(word 1,$$(subst ;, ,$(2))) &&
endef

# arg1: app name
# arg2: src file name to edit and sed command file, scheme <srcfile>;<sedfile>
define sed-src
sed -i -f $$(lastword $$(subst ;, ,$(2))) \
	$(O)/$(1)/$$(firstword $$(subst ;, ,$(2))) &&
endef

###############################################################################
# Bootgen projects

BOOTGEN ?= bootgen

BOOTGEN_PRJS ?=

# arg1: BIF file name
# arg2: BIF attribute
define gen-bif-attr
\t[$$($(1)_$(2)_BIF_ATTR)] $$($(1)_$(2)_BIF_FILE)\n
endef

# arg1: Bootgen project
# arg2: BIF attribute
define gen-bootgen-dep
$$(if $$(findstring yes,$$($(1)_$(2)_BIF_FILE_NO_DEP)),,\
	$(O)/$$($(1)_$(2)_BIF_FILE))
endef

define gen-bif-rule
$(1)_FLASH_TYPE ?=
$(1)_FLASH_FSBL ?=
$(1)_FLASH_OFF ?= 0
$(1)_BOOTGEN_DEP = $$(foreach BIF_ATTR,$$($(1)_BIF_ATTRS),\
	$(call gen-bootgen-dep,$(1),$$(BIF_ATTR)))

$(O)/$(1)/$(1).bif: $$($(1)_BOOTGEN_DEP)
	mkdir -p $(O)/$(1)
	printf '$(1):\n{\n' > $(O)/$(1)/$(1).bif
ifneq ($$(strip $$($(1)_BIF_ATTRS)),)
	printf '$$(foreach BIF_ATTR,$$($(1)_BIF_ATTRS), \
		$(call gen-bif-attr,$(1),$$(BIF_ATTR)))' \
		>> $(O)/$(1)/$(1).bif
endif
	printf '}\n' >> $(O)/$(1)/$(1).bif

$(O)/$(1)/BOOT.BIN: $(O)/$(1)/$(1).bif
ifeq ($$($(1)_BIF_NO_OUTPUT),yes)
	cd $(O) && $(BOOTGEN) -arch $$($(1)_BIF_ARCH) -image $(1)/$(1).bif \
		$$($(1)_BIF_ARGS_EXTRA)
else
	cd $(O) && $(BOOTGEN) -arch $$($(1)_BIF_ARCH) -image $(1)/$(1).bif \
		-o $(1)/BOOT.BIN -w $$($(1)_BIF_ARGS_EXTRA)
endif

GEN_BOOTGEN_DEP += $(O)/$(1)/$(1).bif
BLD_BOOTGEN_DEP += $(O)/$(1)/BOOT.BIN

# NOTE: Target $(1)_flash is written for QSPI flashing in mind - other types
#       might need more or other arguments!
$(1)_flash: $(O)/$(1)/BOOT.BIN
	cd $(O) && \
	program_flash \
		-flash_type $$($(1)_FLASH_TYPE) \
		-fsbl $$($(1)_FLASH_FSBL) \
		-f $(1)/BOOT.BIN -offset $$($(1)_FLASH_OFF) \
		-verify \
		-cable type xilinx_tcf url $(HW_SERVER_URL)
.PHONY: $(1)_flash

# shortcut to build bootgen project, "make <bootgen>"
$(1): $(O)/$(1)/BOOT.BIN
.PHONY: $(1)

$(1)_clean:
	find $(O)/$(1)/* -not -name $(1).bif -delete
.PHONY: $(1)_clean

$(1)_distclean:
	rm -fr $(O)/$(1)
.PHONY: $(1)_distclean
endef

###############################################################################
# Common targets

# show logs
metalog:
	cat $(O)/.metadata/.log
sdklog:
	cat $(O)/SDK.log
.PHONY: sdklog metalog

# remove workspace
distclean:
	rm -fr $(O)
.PHONY: distclean

# open XSCT in interactive mode
xsct:
	$(XSCT) -interactive -eval 'setws $(O)'
.PHONY: xsct
