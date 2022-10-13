# Corundum mqnic for Dini Group DNPCIe_40G_KU_LL_2QSFP

## Introduction

This design targets the Dini Group DNPCIe_40G_KU_LL_2QSFP FPGA board.

* FPGA: xcku040-ffva1156-2-e
* PHY: 10G BASE-R PHY IP core and internal GTH transceiver
* RAM: 4 GB DDR4 2400 (512M x72)

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the DNPCIe_40G_KU_LL_2QSFP board with Vivado.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.


