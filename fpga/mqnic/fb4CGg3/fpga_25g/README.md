# Corundum mqnic for fb4CGg3@VU09P

## Introduction

This design targets the Silicom fb4CGg3@VU09P FPGA board.

* FPGA: xcvu9p-flgb2104-2-e
* PHY: 25G BASE-R PHY IP core and internal GTY transceiver
* RAM: 16GB DDR4 2666 (4x 512M x72)

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the fb4CGg3@VU09P board with Vivado.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.
