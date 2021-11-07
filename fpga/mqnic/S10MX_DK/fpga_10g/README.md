# Corundum mqnic for Stratix 10 MX

## Introduction

This design targets the Intel Stratix 10 MX FPGA development board.

*  FPGA: 1SM21BHU2F53E1VG (8 GB HBM2) or 1SM21CHU1F53E1VG (16 GB HBM2)
*  PHY: Transceiver in 10G BASE-R native mode

## How to build

Run make to build.  Ensure that the Intel Quartus Prime Pro toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the board with the Intel software.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.
