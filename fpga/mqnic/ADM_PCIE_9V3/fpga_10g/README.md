# Corundum mqnic for ADM-PCIE-9V3

## Introduction

This design targets the Alpha Data ADM-PCIE-9V3 FPGA board.

FPGA: xcvu3p-ffvc1517-2-i
PHY: 10G BASE-R PHY IP core and internal GTY transceiver

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are
installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the ADM-PCIE-9V3 board with Vivado.  Then load the
driver with insmod mqnic.ko.  Check dmesg for output from driver
initialization.


