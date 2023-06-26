# Corundum mqnic for DK-DEV-AGF014EA

## Introduction

This design targets the Intel DK-DEV-AGF014EA FPGA development board.

* FPGA: AGFB014R24B2E2V
* PHY: E-Tile

## Quick start

### Build FPGA bitstream

Run `make` in the `fpga` subdirectory to build the bitstream.  Ensure that the Intel Quartus Pro toolchain components are in PATH.

### Build driver and userspace tools

On the host system, run `make` in `modules/mqnic` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.  Then, run `make` in `utils` to build the userspace tools.

### Testing

Configure DIP switches:

* SW1: off, on, on, off (AS_NORMAL)
* SW2: all off (UART, Si52202, Si5341 all enable, select USB JTAG)
* SW3: all off (enable all I2C interfaces)
* SW4: off, on, on, off (select USB JTAG, bypass MAX10 JTAG, bypass MICTOR JTAG, enable FPGA JTAG)
* SW6: 1 on, rest off (select x16)
* SW7: off (PCIe reference clock from edge connector)

Run `make program` to program the board with Quartus.  Then, reboot the machine to re-enumerate the PCIe bus.  Finally, load the driver on the host system with `insmod mqnic.ko`.  Check `dmesg` for output from driver initialization, and run `mqnic-dump -d /dev/mqnic0` to dump the internal state.
