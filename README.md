# Verilog PCI Express Components Readme

For more information and updates: http://alexforencich.com/wiki/en/verilog/pcie/start

GitHub repository: https://github.com/alexforencich/verilog-pcie

## Introduction

Collection of PCI express related components.  Includes full MyHDL testbench
with intelligent bus cosimulation endpoints.

## Documentation

### PCIe BFM

A MyHDL transaction layer PCI Express bus functional model (BFM) is included
in pcie.py.  This BFM implements an extensive event driven simulation of a
complete PCI express system, including root complex, switches, devices, and
functions, including support for configuration spaces, capabilities and
extended capabilities, and memory and IO operations between devices.  The BFM
includes code to enumerate the bus, initialize configuration space registers
and allocate BARs, route messages between devices, perform memory read and
write operations, allocate DMA accessible memory regions in the root complex,
and handle message signaled interrupts.  Any module can be connected to a
cosimulated design, enabling testing of not only isolated components and
host-device communication but also communication between multiple components
such as device-to-device DMA and message passing.

A MyHDL model of the Xilinx Ultrascale PCIe hard core is included in
pcie_us.py.  This module can be used in combination with the PCIe BFM to test
a MyHDL or Verilog design that targets a Xilinx Ultrascale FPGA.  The model
currently only supports operation as a device, not as a root port.

### arbiter module

General-purpose parametrizable arbiter.  Supports priority and round-robin
arbitration.  Supports blocking until request release or acknowledge.  

### axis_arb_mux module

Frame-aware AXI stream arbitrated muliplexer with parametrizable data width
and port count.  Supports priority and round-robin arbitration.

### pcie_axi_dma_desc_mux module

Descriptor multiplexer/demultiplexer for PCIe AXI DMA module.  Enables sharing
the PCIe AXI DMA module between multiple request sources, interleaving
requests and distributing responses.

### pcie_tag_manager module

PCIe in-flight tag manager.

### pcie_us_axi_dma module

PCIe AXI DMA module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, and 256 bit datapaths.  Parametrizable AXI burst length.  Wrapper for pcie_us_axi_dma_rd and pcie_us_axi_dma_wr

### pcie_us_axi_dma_rd module

PCIe AXI DMA module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, and 256 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axi_dma_wr module

PCIe AXI DMA module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, and 256 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axi_master module

PCIe AXI master module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, and 256 bit datapaths.  Parametrizable AXI burst length.  Wrapper for pcie_us_axi_master_rd and pcie_us_axi_master_wr.  

### pcie_us_axi_master_rd module

PCIe AXI master module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, and 256 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axi_master_wr module

PCIe AXI master module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, and 256 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axil_master module

PCIe AXI lite master module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, and 256 bit PCIe interfaces.  

### pcie_us_axis_cq_demux module

Demux module for Xilinx Ultrascale CQ interface.  Can be used to route
incoming requests based on function, BAR, and other fields.  Supports 64, 128,
and 256 bit datapaths.

### pcie_us_axis_rc_demux module

Demux module for Xilinx Ultrascale RC interface.  Can be used to route
incoming completions based on the requester ID (function).  Supports 64, 128,
and 256 bit datapaths.

### pcie_us_cfg module

Configuration shim for Xilinx Ultrascale series FPGAs.

### pcie_us_msi module

MSI shim for Xilinx Ultrascale series FPGAs.

### priority_encoder module

Parametrizable priority encoder.

### pulse_merge module

Parametrizable pulse merge module.  Combines several single-cycle pulse status
signals together.

### Common signals

### Common parameters

### Source Files

    arbiter.v               : Parametrizable arbiter
    axis_arb_mux.v          : Parametrizable AXI stream mux
    pcie_axi_dma_desc_mux.v : Descriptor mux for DMA engine
    pcie_tag_manager.v      : PCIe in-flight tag manager
    pcie_us_axi_dma.v       : PCIe AXI DMA module with Xilinx Ultrascale interface
    pcie_us_axi_dma_rd.v    : PCIe AXI DMA read module with Xilinx Ultrascale interface
    pcie_us_axi_dma_wr.v    : PCIe AXI DMA write module with Xilinx Ultrascale interface
    pcie_us_axi_master.v    : AXI Master module with Xilinx Ultrascale interface
    pcie_us_axi_master_rd.v : AXI Master read module with Xilinx Ultrascale interface
    pcie_us_axi_master_wr.v : AXI Master write module with Xilinx Ultrascale interface
    pcie_us_axil_master.v   : AXI Lite Master module with Xilinx Ultrascale interface
    pcie_us_axis_cq_demux.v : Parametrizable AXI stream CQ demux
    pcie_us_axis_rc_demux.v : Parametrizable AXI stream RC demux
    pcie_us_cfg.v           : Configuration shim for Xilinx Ultrascale devices
    pcie_us_msi.v           : MSI shim for Xilinx Ultrascale devices
    priority_encoder.v      : Parametrizable priority encoder
    pulse_merge             : Parametrizable pulse merge module

## Testing

Running the included testbenches requires MyHDL and Icarus Verilog.  Make sure
that myhdl.vpi is installed properly for cosimulation to work correctly.  The
testbenches can be run with a Python test runner like nose or py.test, or the
individual test scripts can be run with python directly.

### Testbench Files

    tb/axis_ep.py        : MyHDL AXI Stream endpoints
    tb/pcie.py           : MyHDL PCI Express BFM
    tb/pcie_us.py        : MyHDL Xilinx Ultrascale PCIe core model
