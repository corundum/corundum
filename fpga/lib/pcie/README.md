# Verilog PCI Express Components Readme

[![Build Status](https://github.com/alexforencich/verilog-pcie/workflows/Regression%20Tests/badge.svg?branch=master)](https://github.com/alexforencich/verilog-pcie/actions/)

For more information and updates: http://alexforencich.com/wiki/en/verilog/pcie/start

GitHub repository: https://github.com/alexforencich/verilog-pcie

## Introduction

Collection of PCI express related components.  Includes PCIe to AXI and AXI
lite bridges, a simple PCIe AXI DMA engine, and a flexible, high-performance
DMA subsystem.  Currently supports operation with the Xilinx Ultrascale and
Ultrascale Plus PCIe hard IP cores with interfaces between 64 and 512 bits.
Includes full cocotb testbenches that utilize
[cocotbext-axi](https://github.com/alexforencich/cocotbext-axi).

## Documentation

### PCIe AXI and AXI lite master

The pcie_us_axi_master and pcie_us_axil_master modules provide a bridge
between PCIe and AXI.  These can be used to implement PCIe BARs.  The
pcie_us_axil_master module is a very simple module for providing register
access, supporting only 32 bit operations.  The pcie_us_axi_master module is
more complex, converting PCIe operations to AXI bursts.  It can be used to
terminate device-to-device DMA operations with reasonable performance.  The
pcie_us_axis_cq_demux module can be used to demultiplex PCIe operations based
on the target BAR.

### PCIe AXI DMA

The pcie_us_axi_dma module provides a DMA engine with an internal AXI
interface.  The AXI interface width must match the PCIe interface width.  The
module directly translates AXI operations into PCIe operations.  As a result,
it is relatively simple, but the performance is limited due to the constraints
of the AXI interface.  Backpressure on the AXI interface is also passed
through to the PCIe interface.

The pcie_axi_dma_desc_mux module can be used to share the AXI DMA module
between multiple request sources.

### Flexible DMA subsystem

The split DMA interface/DMA client modules support highly flexible, highly
performant DMA operations.  The DMA interface and DMA client modules are
connected by dual port RAMs with a high performance segmented memory
interface.  The segmented memory interface is a better 'impedance match' to
the PCIe hard core interface - data realignment can be done in the same clock
cycle; no bursts, address decoding, arbitration, or reordering simplifies
implementation and provides much higher performance than AXI.  The architecture
is also quite flexible as it decouples the DMA interface from the clients with
dual port RAMs, enabling mixing different client interface types and widths
and even supporting clients running in different clock domains without
datapath FIFOs.

![DMA system block diagram](dma_block.svg)

The dma_if_pcie_us module connects the Xilinx Ultrascale PCIe interface to the
segmented memory interface.  Currently, it does not support TLP straddling,
but it should be possible to support this with the segmented interface.

The dma_psdpram module is a dual clock, parallel simple dual port RAM module
with a segmented interface.  The depth is independently adjustable from the
address width, simplifying use of the segmented interface.  The module also contains a parametrizable output pipeline register to improve timing.

The dma_if_mux module enables sharing the DMA interface across several DMA
clients.  This module handles the tags and select lines appropriately on both
the descriptor and segmented memory interface for plug-and-play operation
without address assignment - routing is completely determined by component
connections.  The module also contains a FIFO to maintain read data ordering
across multiple clients.  Make sure to equalize pipeline delay across all
paths for maximum performance.

DMA client modules connect the segmented memory interface to different
internal interfaces.

The dma_client_axis_source and dma_client_axis_sink modules provide support
for streaming DMA over AXI stream.  The AXI stream width can be any power of
two fraction of the segmented memory interface width.

### arbiter module

General-purpose parametrizable arbiter.  Supports priority and round-robin
arbitration.  Supports blocking until request release or acknowledge.

### axis_arb_mux module

Frame-aware AXI stream arbitrated muliplexer with parametrizable data width
and port count.  Supports priority and round-robin arbitration.

### dma_client_axis_sink module

AXI stream sink DMA client module.  Uses a segmented memory interface.

### dma_client_axis_source module

AXI stream source DMA client module.  Uses a segmented memory interface.

### dma_if_mux module

DMA interface mux module.  Enables sharing a DMA interface module between
multiple DMA client modules.  Wrapper for dma_if_mux_rd and dma_if_mux_wr.

### dma_if_mux_rd module

DMA interface mux module.  Enables sharing a DMA interface module between
multiple DMA client modules.  Muxes descriptors and demuxes memory writes.

### dma_if_mux_wr module

DMA interface mux module.  Enables sharing a DMA interface module between
multiple DMA client modules.  Muxes descriptors, demuxes memory read commands,
and muxes read data.

### dma_if_pcie_us module

PCIe DMA interface module for Xilinx Ultrascale series FPGAs.  Supports 64,
128, 256, and 512 bit datapaths.  Uses a double width segmented memory
interface.  Wrapper for dma_if_pcie_us_rd and dma_if_pcie_us_wr.

### dma_if_pcie_us_rd module

PCIe DMA interface module for Xilinx Ultrascale series FPGAs.  Supports 64,
128, 256, and 512 bit datapaths.  Uses a double width segmented memory
interface.

### dma_if_pcie_us_wr module

PCIe DMA interface module for Xilinx Ultrascale series FPGAs.  Supports 64,
128, 256, and 512 bit datapaths.  Uses a double width segmented memory
interface.

### dma_psdpram module

DMA RAM module.  Segmented simple dual port RAM to connect a DMA interface
module to a DMA client.

### pcie_axi_dma_desc_mux module

Descriptor multiplexer/demultiplexer for PCIe AXI DMA module.  Enables sharing
the PCIe AXI DMA module between multiple request sources, interleaving
requests and distributing responses.

### pcie_us_axi_dma module

PCIe AXI DMA module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, 256,
and 512 bit datapaths.  Parametrizable AXI burst length.  Wrapper for
pcie_us_axi_dma_rd and pcie_us_axi_dma_wr.

### pcie_us_axi_dma_rd module

PCIe AXI DMA module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, 256,
and 512 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axi_dma_wr module

PCIe AXI DMA module for Xilinx Ultrascale series FPGAs.  Supports 64, 128, 256,
and 512 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axi_master module

PCIe AXI master module for Xilinx Ultrascale series FPGAs.  Supports 64, 128,
256, and 512 bit datapaths.  Parametrizable AXI burst length.  Wrapper for
pcie_us_axi_master_rd and pcie_us_axi_master_wr.

### pcie_us_axi_master_rd module

PCIe AXI master module for Xilinx Ultrascale series FPGAs.  Supports 64, 128,
256, and 512 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axi_master_wr module

PCIe AXI master module for Xilinx Ultrascale series FPGAs.  Supports 64, 128,
256, and 512 bit datapaths.  Parametrizable AXI burst length.

### pcie_us_axil_master module

PCIe AXI lite master module for Xilinx Ultrascale series FPGAs.  Supports 64,
128, 256, and 512 bit PCIe interfaces.

### pcie_us_axis_cq_demux module

Demux module for Xilinx Ultrascale CQ interface.  Can be used to route
incoming requests based on function, BAR, and other fields.  Supports 64, 128,
256, and 512 bit datapaths.

### pcie_us_axis_rc_demux module

Demux module for Xilinx Ultrascale RC interface.  Can be used to route
incoming completions based on the requester ID (function).  Supports 64, 128,
256, and 512 bit datapaths.

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

    arbiter.v                : Parametrizable arbiter
    axis_arb_mux.v           : Parametrizable AXI stream mux
    dma_client_axis_sink.v   : AXI stream sink DMA client
    dma_client_axis_source.v : AXI stream source DMA client
    dma_if_mux.v             : DMA interface mux
    dma_if_mux_rd.v          : DMA interface mux (read)
    dma_if_mux_wr.v          : DMA interface mux (write)
    dma_if_pcie_us.v         ; DMA interface for Xilinx Ultrascale PCIe
    dma_if_pcie_us_rd.v      ; DMA interface for Xilinx Ultrascale PCIe (read)
    dma_if_pcie_us_wr.v      ; DMA interface for Xilinx Ultrascale PCIe (write)
    dma_psdpram.v            : DMA RAM (segmented simple dual port RAM)
    pcie_axi_dma_desc_mux.v  : Descriptor mux for DMA engine
    pcie_us_axi_dma.v        : PCIe AXI DMA module (Xilinx Ultrascale)
    pcie_us_axi_dma_rd.v     : PCIe AXI DMA read module (Xilinx Ultrascale)
    pcie_us_axi_dma_wr.v     : PCIe AXI DMA write module (Xilinx Ultrascale)
    pcie_us_axi_master.v     : PCIe AXI Master module (Xilinx Ultrascale)
    pcie_us_axi_master_rd.v  : PCIe AXI Master read module (Xilinx Ultrascale)
    pcie_us_axi_master_wr.v  : PCIe AXI Master write module (Xilinx Ultrascale)
    pcie_us_axil_master.v    : PCIe AXI Lite Master module (Xilinx Ultrascale)
    pcie_us_axis_cq_demux.v  : Parametrizable AXI stream CQ demux
    pcie_us_axis_rc_demux.v  : Parametrizable AXI stream RC demux
    pcie_us_cfg.v            : Configuration shim for Xilinx Ultrascale devices
    pcie_us_msi.v            : MSI shim for Xilinx Ultrascale devices
    priority_encoder.v       : Parametrizable priority encoder
    pulse_merge              : Parametrizable pulse merge module

## Testing

Running the included testbenches requires [cocotb](https://github.com/cocotb/cocotb), [cocotbext-axi](https://github.com/alexforencich/cocotbext-axi), [cocotbext-pcie](https://github.com/alexforencich/cocotbext-pcie), and [Icarus Verilog](http://iverilog.icarus.com/).  The testbenches can be run with pytest directly (requires [cocotb-test](https://github.com/themperek/cocotb-test)), pytest via tox, or via cocotb makefiles.
