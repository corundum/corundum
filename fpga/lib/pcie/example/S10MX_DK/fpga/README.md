# Verilog PCIe Intel Stratix 10 MX Development Kit Example Design

## Introduction

This example design targets the Intel Stratix 10 MX Development Kit.

The design implements the PCIe AXI lite master module, the PCIe AXI master module, and the PCIe DMA module.  A very simple Linux driver is included to test the FPGA design.

*  FPGA: 1SM21BHU2F53E1VG (8 GB HBM2) or 1SM21CHU1F53E1VG (16 GB HBM2)

## How to build

Run `make` to build.  Ensure that the Intel Quartus Pro components are in PATH.

Run `make` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the Stratix 10 MX development kit with Quartus Pro.  Then load the driver with `insmod example.ko`.  Check dmesg for the output.
