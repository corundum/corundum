# Corundum mqnic for KR260

## Introduction

This design targets the Xilinx KR260 FPGA board.

* FPGA: K26 SoM (xck26-sfvc784-2LV-c)
* PHY: 10G BASE-R PHY IP core and internal GTH transceiver

## Quick start for Ubuntu

### Build FPGA bitstream

Run `make app` in the `fpga` subdirectory to build the bitstream, `.xsa` file, and device tree overlay.  Ensure that the Xilinx Vivado toolchain components are in PATH (source `settings64.sh` in Vivado installation directory).

### Installation

Download an Ubuntu image for the KR260 here: https://ubuntu.com/download/amd-xilinx.  Write the image to an SD card with `dd`, for example:

	xzcat ubuntu.img.xz | dd of=/dev/sdX

Copy files in `fpga/app` to `/lib/firmware/xilinx/mqnic` on the KR260.  Also make a copy of the source repo on the KR260 from which the kernel module and userspace tools can be built.

### Build driver and userspace tools

On the KR260, run `make` in `modules/mqnic` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.  Then run `make` in `utils` to build the userspace tools.

### Testing

On the KR260, run `sudo xmutil unloadapp` to unload the FPGA, then `sudo xmutil loadapp mqnic` to load the configuration.  Then, build the kernel module and userspace tools by running `make` in `modules/mqnic` and `utils`.  Finally, load the kernel module with `insmod mqnic.ko`.  Check `dmesg` for output from driver initialization.  Run `mqnic-dump -d /dev/mqnic0` to dump the internal state.
