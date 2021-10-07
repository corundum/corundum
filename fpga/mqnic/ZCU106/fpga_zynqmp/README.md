# Corundum mqnic for ZCU106 using ZynqMP PS as host system

## Introduction

This design targets the Xilinx ZCU106 FPGA board. The host system of the NIC is
the Zynq US+ MPSoC.

FPGA: xczu7ev-ffvc1156-2-e
PHY: 10G BASE-R PHY IP core and internal GTH transceiver

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.
