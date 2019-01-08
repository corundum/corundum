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

    arbiter.v               : Parametriable arbiter
    axis_arb_mux.v          : Parametriable AXI stream mux
    pcie_axi_dma_desc_mux.v : Descriptor mux for DMA engine
    pcie_tag_manager.v      : PCIe in-flight tag manager
    pcie_us_axi_dma.v       : PCIe AXI DMA module with Xilinx Ultrascale interface
    pcie_us_axi_dma_rd.v    : PCIe AXI DMA read module with Xilinx Ultrascale interface
    pcie_us_axi_dma_wr.v    : PCIe AXI DMA write module with Xilinx Ultrascale interface
    pcie_us_axi_master.v    : AXI Master module with Xilinx Ultrascale interface
    pcie_us_axi_master_rd.v : AXI Master read module with Xilinx Ultrascale interface
    pcie_us_axi_master_wr.v : AXI Master write module with Xilinx Ultrascale interface
    pcie_us_axil_master.v   : AXI Lite Master module with Xilinx Ultrascale interface
    pcie_us_axis_cq_demux.v : Parametriable AXI stream CQ demux
    pcie_us_axis_rc_demux.v : Parametriable AXI stream RC demux
    pcie_us_msi.v           : MSI shim for Xilinx Ultrascale devices
    priority_encoder.v      : Parametriable priority encoder

## Testing

Running the included testbenches requires MyHDL and Icarus Verilog.  Make sure
that myhdl.vpi is installed properly for cosimulation to work correctly.  The
testbenches can be run with a Python test runner like nose or py.test, or the
individual test scripts can be run with python directly.

### Testbench Files

    tb/axis_ep.py        : MyHDL AXI Stream endpoints
    tb/pcie.py           : MyHDL PCI Express BFM
    tb/pcie_us.py        : MyHDL Xilinx Ultrascale PCIe core model
