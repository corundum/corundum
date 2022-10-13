# Corundum mqnic for ZCU102 using ZynqMP PS as host system

## Introduction

This design targets the Xilinx ZCU102 FPGA board. The host system of the NIC is
the Zynq US+ MPSoC.

* FPGA: xczu9eg-ffvb1156-2-e
* PHY: 10G BASE-R PHY IP core and internal GTH transceiver
* RAM: 512 MB DDR4 2400 (256M x16)

## How to build

Run make in this directory to build the bitstream and the .xsa
file.  Ensure that the Xilinx Vivado toolchain components are in PATH.

Then change into sub-directory ps/petalinux/ and build the PetaLinux project.
Ensure that the Xilinx PetaLinux toolchain components are in PATH.

	make -C ps/petalinux/ build-boot

## How to test

Copy the following, resulting files of building the PetaLinux project onto an
SDcard suitable for then booting the ZCU102 in SDcard boot mode.

	ps/petalinux/images/linux/:
		BOOT.BIN
		boot.scr
		Image
		system.dtb
		rootfs.cpio.gz.u-boot
