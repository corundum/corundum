# Corundum mqnic for ExaNIC X25/Cisco Nexus K3P-S

## Introduction

This design targets the Exablaze ExaNIC X25/Cisco Nexus K3P-S FPGA board.

FPGA: xcku3p-ffvb676-2-e
PHY: 25G BASE-R PHY IP core and internal GTY transceiver

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are
installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the ExaNIC X25 board with Vivado.  Then load the
driver with insmod mqnic.ko.  Check dmesg for output from driver
initialization.


