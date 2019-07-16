# Verilog PCIe ADM-PCIE-9V3 Example Design

## Introduction

This example design targets the Alpha Data ADM-PCIE-9V3 FPGA board.

The design implements the PCIe AXI lite master module, the PCIe AXI master
module, and the PCIe AXI DMA module.  A very simple Linux driver is included
to test the FPGA design.

FPGA: xcvu3p-ffvc1517-2-i

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are
installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the ADM-PCIE-9V3 board with Vivado.  Then load the
driver with insmod example.ko.  Check dmesg for the output.


