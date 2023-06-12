# Corundum mqnic for 520N-MX

## Introduction

This design targets the BittWare 520N-MX FPGA development board.

*  FPGA: 1SM21CHU2F53E2VG
*  PHY: Transceiver in 10G BASE-R native mode

## How to build

Run make to build.  Ensure that the Intel Quartus Prime Pro toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the board with the Intel software.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.
