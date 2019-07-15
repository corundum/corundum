# Corundum Readme

GitHub repository: https://github.com/ucsdsysnet/corundum

## Introduction

Corundum is an open source, high performance FPGA based NIC.

## Documentation

### Modules

### Common signals

### Common parameters

### Source Files

    arbiter.v               : Parametrizable arbiter

## Testing

Running the included testbenches requires MyHDL and Icarus Verilog.  Make sure
that myhdl.vpi is installed properly for cosimulation to work correctly.  The
testbenches can be run with a Python test runner like nose or py.test, or the
individual test scripts can be run with python directly.

### Testbench Files

    tb/axis_ep.py        : MyHDL AXI Stream endpoints
    tb/pcie.py           : MyHDL PCI Express BFM
    tb/pcie_us.py        : MyHDL Xilinx Ultrascale PCIe core model
