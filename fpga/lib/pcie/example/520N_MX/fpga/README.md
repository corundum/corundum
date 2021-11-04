# Verilog PCIe BittWare 520N-MX Example Design

## Introduction

This example design targets the BittWare 520N-MX FPGA board.

The design implements the PCIe AXI lite master module, the PCIe AXI master module, and the PCIe DMA module.  A very simple Linux driver is included to test the FPGA design.

*  FPGA: 1SM21CHU2F53E2VG

## How to build

Run `make` to build.  Ensure that the Intel Quartus Pro components are in PATH.

Run `make` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the 520N-MX board with Quartus Pro.  Then load the driver with `insmod example.ko`.  Check dmesg for the output.
