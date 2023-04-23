# Corundum mqnic for DK-DEV-AGF014EA

## Introduction

This design targets the Intel DK-DEV-AGF014EA FPGA development board.

*  FPGA: AGFB014R24B2E2V
*  PHY: E-Tile

## How to build

Run make to build.  Ensure that the Intel Quartus Prime Pro toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Configure DIP switches:

*  SW1: off, on, on, off (AS_NORMAL)
*  SW2: all off (UART, Si52202, Si5341 all enable, select USB JTAG)
*  SW3: all off (enable all I2C interfaces)
*  SW4: off, on, on, off (select USB JTAG, bypass MAX10 JTAG, bypass MICTOR JTAG, enable FPGA JTAG)
*  SW6: 1 on, rest off (select x16)
*  SW7: off (PCIe reference clock from edge connector)

Run make program to program the DK-DEV-AGF014EA board with the Intel software.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.
