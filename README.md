# Verilog PCI Express Components Readme

For more information and updates: http://alexforencich.com/wiki/en/verilog/pcie/start

GitHub repository: https://github.com/alexforencich/verilog-pcie

## Introduction

Collection of PCI express related components.  Includes full MyHDL testbench
with intelligent bus cosimulation endpoints.

## Documentation

### PCIe BFM

A MyHDL transaction layer PCI Express bus functional model (BFM) is included in pcie.py.  This BFM implements an extensive event driven simulation of a complete PCI express system, including root complex, switches, devices, and functions.  The BFM includes code to enumerate the bus, initialize configuration space registers and allocate BARs, pass messages between devices, and perform memory read and write operations.  Any module can be connected to a cosimulated design, enabling testing of not only isolated components but also communication between multiple components such as device-to-device DMA and message passing.  

### Common signals

### Common parameters

### Source Files

## Testing

Running the included testbenches requires MyHDL and Icarus Verilog.  Make sure
that myhdl.vpi is installed properly for cosimulation to work correctly.  The
testbenches can be run with a Python test runner like nose or py.test, or the
individual test scripts can be run with python directly.

### Testbench Files

    tb/axis_ep.py        : MyHDL AXI Stream endpoints
    tb/pcie.py           : MyHDL PCI Express BFM
    tb/pcie_us.py        : MyHDL Xilinx Ultrascale PCIe core model
