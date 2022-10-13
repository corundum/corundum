# Corundum mqnic for 250-SoC

## Introduction

This design targets the BittWare 250-SoC FPGA board.

* FPGA: xczu19eg-ffvd1760-2-e
* MAC: Xilinx 100G CMAC
* PHY: 100G CAUI-4 CMAC and internal GTY transceivers
* RAM: 4 GB DDR4 2666 (512M x72)

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are
installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the 250-SoC board with Vivado.  Then load the
driver with insmod mqnic.ko.  Check dmesg for output from driver
initialization.


