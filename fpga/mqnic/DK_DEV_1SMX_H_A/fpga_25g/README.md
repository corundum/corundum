# Corundum mqnic for DK-DEV-1SMX-H-A

## Introduction

This design targets the Intel DK-DEV-1SMX-H-A FPGA development board.

* FPGA (DK-DEV-1SMX-H-A): 1SM21BHU2F53E1VG (8 GB HBM2)
* FPGA (DK-DEV-1SMC-H-A): 1SM21CHU1F53E1VG (16 GB HBM2)
* PHY: Transceiver in 10G BASE-R native mode

## Quick start

### Build FPGA bitstream

Run `make` in the `fpga` subdirectory to build the bitstream.  Ensure that the Intel Quartus Pro toolchain components are in PATH.

### Build driver and userspace tools

On the host system, run `make` in `modules/mqnic` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.  Then, run `make` in `utils` to build the userspace tools.

### Testing

Run `make program` to program the board with Quartus.  Then, reboot the machine to re-enumerate the PCIe bus.  Finally, load the driver on the host system with `insmod mqnic.ko`.  Check `dmesg` for output from driver initialization, and run `mqnic-dump -d /dev/mqnic0` to dump the internal state.
