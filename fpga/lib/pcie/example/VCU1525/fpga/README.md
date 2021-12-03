# Verilog PCIe VCU1525 Example Design

## Introduction

This example design targets the Xilinx VCU1525 FPGA board.

The design implements the PCIe AXI lite master module, the PCIe AXI master module, and the PCIe DMA module.  A very simple Linux driver is included to test the FPGA design.

*  FPGA: xcvu9p-fsgd2104-2L-e

## How to build

Run `make` to build.  Ensure that the Xilinx Vivado components are in PATH.

Run `make` to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the VCU1525 board with Vivado.  Then load the driver with `insmod example.ko`.  Check dmesg for the output.
