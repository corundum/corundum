# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

ifneq ($(KERNELRELEASE),)

KBUILD_EXTRA_SYMBOLS=$(src)/../mqnic/Module.symvers

ccflags-y += -I$(src)/../mqnic/

# object files to build
obj-m += mqnic_app_template.o
mqnic_app_template-y += main.o

else

ifneq ($(KERNEL_SRC),)
# alternatively to variable KDIR accept variable KERNEL_SRC as used in
# PetaLinux/Yocto for example
KDIR ?= $(KERNEL_SRC)
endif

KDIR ?= /lib/modules/$(shell uname -r)/build

all: modules

help modules modules_install clean:
	$(MAKE) -C $(KDIR) M=$(shell pwd) $@

install: modules_install

endif
