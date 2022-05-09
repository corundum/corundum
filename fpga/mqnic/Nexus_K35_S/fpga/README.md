# Corundum mqnic for Cisco Nexus K35-S

## Introduction

This design targets the Cisco Nexus K35-S FPGA board.

* FPGA: xcku035-fbva676-2-e
* PHY: 10G BASE-R PHY IP core and internal GTH transceiver

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the Nexus K35-S board with Vivado.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.


