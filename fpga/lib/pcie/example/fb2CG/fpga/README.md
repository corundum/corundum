# Verilog PCIe fb2CG@KU15P Example Design

## Introduction

This example design targets the Silicom fb2CG@KU15P FPGA board.

The design implements the PCIe AXI lite master module, the PCIe AXI master module, and the PCIe DMA module.  A very simple Linux driver is included to test the FPGA design.

* FPGA: xcku15p-ffve1760-2-e

## How to build

Run `make` to build.  Ensure that the Xilinx Vivado toolchain components are in PATH.

Run `make` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the fb2CG@KU15P board with Vivado.  Then load the driver with `insmod example.ko`.  Check dmesg for the output.
