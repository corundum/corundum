# Verilog PCIe Terasic DE10-Agilex Example Design

## Introduction

This example design targets the Terasic DE10-Agilex.

The design implements the PCIe AXI lite master module, the PCIe AXI master module, and the PCIe DMA module.  A very simple Linux driver is included to test the FPGA design.

*  FPGA: AGFB014R24B2E2V

## How to build

Run `make` to build.  Ensure that the Intel Quartus Pro components are in PATH.

Run `make` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the DE10-Agilex with Quartus Pro.  Then load the driver with `insmod example.ko`.  Check dmesg for the output.
