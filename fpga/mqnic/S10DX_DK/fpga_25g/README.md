# Corundum mqnic for Stratix 10 DX

## Introduction

This design targets the Intel Stratix 10 DX FPGA development board.

*  FPGA: 1SD280PT2F55E1VG
*  PHY: E-Tile

## How to build

Run make to build.  Ensure that the Intel Quartus Prime Pro toolchain components are in PATH.

Run make to build the driver.  Ensure the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run make program to program the board with the Intel software.  Then load the driver with insmod mqnic.ko.  Check dmesg for output from driver initialization.
