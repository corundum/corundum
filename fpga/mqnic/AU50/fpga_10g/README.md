# Corundum mqnic for Alveo U50

## Introduction

This design targets the Xilinx Alveo U50 FPGA board.

* FPGA: xcu50-fsvh2104-2-e
* PHY: 10G BASE-R PHY IP core and internal GTY transceivers

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are
installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the Alveo U50 board with Vivado.  Then load the
driver with insmod mqnic.ko.  Check dmesg for output from driver
initialization.


