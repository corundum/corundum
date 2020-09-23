# Corundum mqnic for fb2CG@KU15P

## Introduction

This design targets the Silicom fb2CG@KU15P FPGA board.

FPGA: xcku15p-ffve1760-2-e
PHY: 10G BASE-R PHY IP core and internal GTY transceiver

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are
installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the fb2CG@KU15P board with Vivado.  Then load the
driver with insmod mqnic.ko.  Check dmesg for output from driver
initialization.


