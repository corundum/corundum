# Corundum mqnic for DE10-Agilex

## Introduction

This design targets the Terasic DE10-Agilex FPGA development board.

*  FPGA: AGFB014R24B2E2V
*  PHY: E-Tile

## How to build

Run make to build.  Ensure that the Intel Quartus Prime Pro toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the DE10-Agilex board with the Intel software.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.
