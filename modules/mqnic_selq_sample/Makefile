ifneq ($(KERNELRELEASE),)

# object files to build
obj-m += mqnic_selq_sample.o

# mqnic's custom TX Queue Selection hooking capability
MQNIC_INC ?= $(M)/../mqnic
MQNIC_SYMVERS ?= $(MQNIC_INC)/Module.symvers

ccflags-y := -I$(MQNIC_INC)
KBUILD_EXTRA_SYMBOLS := $(MQNIC_SYMVERS)

else

ifneq ($(KERNEL_SRC),)
# alternatively to variable KDIR accept variable KERNEL_SRC as used in
# PetaLinux/Yocto for example
KDIR ?= $(KERNEL_SRC)
endif

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(shell pwd) modules

help modules modules_install clean:
	$(MAKE) -C $(KDIR) M=$(shell pwd) $@

install: modules_install

endif
