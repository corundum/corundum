# Corundum mqnic for XUP-P3R

## Introduction

This design targets the BittWare XUP-P3R FPGA board.

* FPGA: xcvu9p-flgb2104-2-e
* PHY: 10G BASE-R PHY IP core and internal GTY transceiver
* RAM: 4x DDR4 DIMM

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are
installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the XUP-P3R board with Vivado.  Then load the
driver with insmod mqnic.ko.  Check dmesg for output from driver
initialization.
