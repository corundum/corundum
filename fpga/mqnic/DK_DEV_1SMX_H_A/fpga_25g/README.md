# Corundum mqnic for DK-DEV-1SMX-H-A

## Introduction

This design targets the Intel DK-DEV-1SMX-H-A FPGA development board.

*  FPGA (DK-DEV-1SMX-H-A): 1SM21BHU2F53E1VG (8 GB HBM2)
*  FPGA (DK-DEV-1SMC-H-A): 1SM21CHU1F53E1VG (16 GB HBM2)
*  PHY: Transceiver in 10G BASE-R native mode

## How to build

Run make to build.  Ensure that the Intel Quartus Prime Pro toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the board with the Intel software.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.
