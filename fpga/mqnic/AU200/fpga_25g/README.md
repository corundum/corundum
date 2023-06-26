# Corundum mqnic for Alveo U200

## Introduction

This design targets the Xilinx Alveo U200 FPGA board.

* FPGA: xcu200-fsgd2104-2-e
* PHY: 10G BASE-R PHY IP core and internal GTY transceiver
* RAM: 64 GB DDR4 2400 (4x 2G x72 DIMM)

## Quick start

### Build FPGA bitstream

Run `make` in the `fpga` subdirectory to build the bitstream.  Ensure that the Xilinx Vivado toolchain components are in PATH.

### Build driver and userspace tools

On the host system, run `make` in `modules/mqnic` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.  Then, run `make` in `utils` to build the userspace tools.

### Testing

Run `make program` to program the board with Vivado.  Then, reboot the machine to re-enumerate the PCIe bus.  Finally, load the driver on the host system with `insmod mqnic.ko`.  Check `dmesg` for output from driver initialization, and run `mqnic-dump -d /dev/mqnic0` to dump the internal state.
