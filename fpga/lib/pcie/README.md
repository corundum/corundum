# Verilog PCI Express Components Readme

[![Build Status](https://github.com/alexforencich/verilog-pcie/workflows/Regression%20Tests/badge.svg?branch=master)](https://github.com/alexforencich/verilog-pcie/actions/)

For more information and updates: http://alexforencich.com/wiki/en/verilog/pcie/start

GitHub repository: https://github.com/alexforencich/verilog-pcie

## Introduction

Collection of PCI express related components.  Includes PCIe to AXI and AXI lite bridges and a flexible, high-performance DMA subsystem.  Currently supports operation with several FPGA families from Xilinx and Intel. Includes full cocotb testbenches that utilize [cocotbext-pcie](https://github.com/alexforencich/cocotbext-pcie) and [cocotbext-axi](https://github.com/alexforencich/cocotbext-axi).

Example designs are included for the following FPGA boards:

*  Alpha Data ADM-PCIE-9V3 (Xilinx Virtex UltraScale+ XCVU3P)
*  BittWare 520N-MX (Intel Stratix 10 MX 1SM21CHU2F53E2VG)
*  Exablaze ExaNIC X10 (Xilinx Kintex UltraScale XCKU035)
*  Exablaze ExaNIC X25 (Xilinx Kintex UltraScale+ XCKU3P)
*  Silicom fb2CG@KU15P (Xilinx Kintex UltraScale+ XCKU15P)
*  Intel Stratix 10 MX dev kit (Intel Stratix 10 MX 1SM21CHU1F53E1VG)
*  Xilinx Alveo U50 (Xilinx Virtex UltraScale+ XCU50)
*  Xilinx Alveo U200 (Xilinx Virtex UltraScale+ XCU200)
*  Xilinx Alveo U250 (Xilinx Virtex UltraScale+ XCU250)
*  Xilinx Alveo U280 (Xilinx Virtex UltraScale+ XCU280)
*  Xilinx VCU108 (Xilinx Virtex UltraScale XCVU095)
*  Xilinx VCU118 (Xilinx Virtex UltraScale+ XCVU9P)
*  Xilinx VCU1525 (Xilinx Virtex UltraScale+ XCVU9P)
*  Xilinx ZCU106 (Xilinx Zynq UltraScale+ XCZU7EV)

## Documentation

### FPGA-independent PCIe

The PCIe modules use a generic, FPGA-independent interface for handling PCIe TLPs. This permits the same core logic to be used on multiple FPGA families, with interface shims to connect to the PCIe IP on each target device.

The `pcie_us_if` module is an adaptation shim for Xilinx 7-series, UltraScale, and UltraScale+.  It handles the main datapath, configuration space parameters, MSI interrupts, and flow control.

The `pcie_s10_if` module is an adaptation shim for Intel Stratix 10 GX/SX/TX/MX series FPGAs that use the H-Tile or L-Tile for PCIe.  It handles the main datapath, configuration space parameters, MSI interrupts, and flow control.

### PCIe AXI and AXI lite master

The `pcie_axi_master`, `pcie_axil_master`, and `pcie_axil_master_minimal` modules provide a bridge between PCIe and AXI.  These can be used to implement PCIe BARs.

The `pcie_axil_master_minimal` module is a very simple module for providing register access, supporting only 32 bit operations.

The `pcie_axi_master` module is more complex, converting PCIe operations to AXI bursts.  It can be used to terminate device-to-device DMA operations with reasonable performance.

The `pcie_tlp_demux_bar` module can be used to demultiplex PCIe operations based on the target BAR.

### Flexible DMA subsystem

The split DMA interface/DMA client modules support highly flexible, highly performant DMA operations.  The DMA interface and DMA client modules are connected by dual port RAMs with a high performance segmented memory interface.  The segmented memory interface is a better 'impedance match' to the PCIe hard core interface - data realignment can be done in the same clock cycle; no bursts, address decoding, arbitration, or reordering simplifies implementation and provides much higher performance than AXI.  The architecture is also quite flexible as it decouples the DMA interface from the clients with dual port RAMs, enabling mixing different client interface types and widths and even supporting clients running in different clock domains without datapath FIFOs.

![DMA system block diagram](dma_block.svg)

The `dma_if_pcie` module connects a generic, FPGA-independent PCIe interface to the segmented memory interface.

The `dma_if_axi` module connects an AXI interface to the segmented memory interface.

The `dma_psdpram` module is a dual clock, parallel simple dual port RAM module with a segmented interface.  The depth is independently adjustable from the address width, simplifying use of the segmented interface.  The module also contains a parametrizable output pipeline register to improve timing.

The `dma_if_mux` module enables sharing the DMA interface across several DMA clients.  This module handles the tags and select lines appropriately on both the descriptor and segmented memory interface for plug-and-play operation without address assignment - routing is completely determined by component connections.  The module also contains a FIFO to maintain read data ordering across multiple clients.  Make sure to equalize pipeline delay across all paths for maximum performance.

DMA client modules connect the segmented memory interface to different internal interfaces.

The `dma_client_axis_source` and `dma_client_axis_sink` modules provide support for streaming DMA over AXI stream.  The AXI stream width can be any power of two fraction of the segmented memory interface width.

### `arbiter` module

General-purpose parametrizable arbiter.  Supports priority and round-robin arbitration.  Supports blocking until request release or acknowledge.

### `axis_arb_mux` module

Frame-aware AXI stream arbitrated multiplexer with parametrizable data width and port count.  Supports priority and round-robin arbitration.

### `dma_client_axis_sink` module

AXI stream sink DMA client module.  Uses a segmented memory interface.

### `dma_client_axis_source` module

AXI stream source DMA client module.  Uses a segmented memory interface.

### `dma_if_axi` module

AXI DMA interface module.  Parametrizable interface width.  Uses a double width segmented memory interface.

### `dma_if_axi_rd` module

AXI DMA interface module.  Parametrizable interface width.  Uses a double width segmented memory interface.

### `dma_if_axi_wr` module

AXI DMA interface module.  Parametrizable interface width.  Uses a double width segmented memory interface.

### `dma_if_desc_mux` module

DMA interface descriptor mux module.  Enables sharing a DMA interface module between multiple DMA client modules.

### `dma_if_mux` module

DMA interface mux module.  Enables sharing a DMA interface module between multiple DMA client modules.  Wrapper for `dma_if_mux_rd` and `dma_if_mux_wr`.

### `dma_if_mux_rd` module

DMA interface mux module.  Enables sharing a DMA interface module between multiple DMA client modules.  Wrapper for `dma_if_desc_mux` and `dma_ram_demux_wr`.

### `dma_if_mux_wr` module

DMA interface mux module.  Enables sharing a DMA interface module between multiple DMA client modules.  Wrapper for `dma_if_desc_mux` and `dma_ram_demux_rd`.

### `dma_if_pcie` module

PCIe DMA interface module.  Parametrizable interface width.  Uses a double width segmented memory interface.

### `dma_if_pcie_rd` module

PCIe DMA interface module.  Parametrizable interface width.  Uses a double width segmented memory interface.

### `dma_if_pcie_wr` module

PCIe DMA interface module.  Parametrizable interface width.  Uses a double width segmented memory interface.

### `dma_if_pcie_us` module

PCIe DMA interface module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Uses a double width segmented memory interface.  Wrapper for `dma_if_pcie_us_rd` and `dma_if_pcie_us_wr`.

### `dma_if_pcie_us_rd` module

PCIe DMA interface module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Uses a double width segmented memory interface.

### `dma_if_pcie_us_wr` module

PCIe DMA interface module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Uses a double width segmented memory interface.

### `dma_psdpram` module

DMA RAM module.  Segmented simple dual port RAM to connect a DMA interface module to a DMA client.

### `dma_psdpram_async` module

DMA RAM module with asynchronous clocks.  Segmented simple dual port RAM to connect a DMA interface module to a DMA client.

### `dma_ram_demux` module

DMA RAM interface demultiplexer module.  Wrapper for `dma_ram_demux_rd` and `dma_ram_demux_wr`.

### `dma_ram_demux_rd` module

DMA RAM interface demultiplexer module for read operations.

### `dma_ram_demux_wr` module

DMA RAM interface demultiplexer module for write operations.

### `pcie_axi_dma_desc_mux` module

Descriptor multiplexer/demultiplexer for PCIe AXI DMA module.  Enables sharing the PCIe AXI DMA module between multiple request sources, interleaving requests and distributing responses.

### `pcie_axi_master` module

PCIe AXI master module.  Parametrizable interface width and AXI burst length. Wrapper for `pcie_axi_master_rd` and `pcie_axi_master_wr`.

### `pcie_axi_master_rd` module

PCIe AXI master module.  Parametrizable interface width and AXI burst length.

### `pcie_axi_master_wr` module

PCIe AXI master module.  Parametrizable interface width and AXI burst length.

### `pcie_axil_master` module

PCIe AXI lite master module.  Parametrizable interface width.

### `pcie_axil_master_minimal` module

Minimal PCIe AXI lite master module.  Parametrizable interface width.  Only supports aligned 32-bit operations, all other operations will result in a completer abort.  Only supports 32-bit AXI lite.

### `pcie_s10_cfg` module

Configuration shim for Intel Stratix 10 GX/SX/TX/MX series FPGAs (H-Tile/L-Tile).

### `pcie_s10_if` module

PCIe interface shim for Intel Stratix 10 GX/SX/TX/MX series FPGAs (H-Tile/L-Tile).  Wrapper for all Intel Stratix 10 GX/SX/TX/MX PCIe interface shims.

### `pcie_s10_if_rx` module

PCIe interface shim (RX) for Intel Stratix 10 GX/SX/TX/MX series FPGAs (H-Tile/L-Tile).

### `pcie_s10_if_tx` module

PCIe interface shim (TX) for Intel Stratix 10 GX/SX/TX/MX series FPGAs (H-Tile/L-Tile).

### `pcie_s10_msi` module

MSI shim for Intel Stratix 10 GX/SX/TX/MX series FPGAs (H-Tile/L-Tile).

### `pcie_tlp_demux` module

PCIe TLP demultiplexer module.

### `pcie_tlp_demux_bar` module

PCIe TLP demultiplexer module.  Wrapper for `pcie_tlp_demux` with parametrizable BAR ID matching logic.

### `pcie_tlp_mux` module

PCIe TLP multiplexer module.

### `pcie_us_axi_dma` module

PCIe AXI DMA module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Parametrizable AXI burst length.  Wrapper for `pcie_us_axi_dma_rd` and `pcie_us_axi_dma_wr`.

### `pcie_us_axi_dma_rd` module

PCIe AXI DMA module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Parametrizable AXI burst length.

### `pcie_us_axi_dma_wr` module

PCIe AXI DMA module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Parametrizable AXI burst length.

### `pcie_us_axi_master` module

PCIe AXI master module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Parametrizable AXI burst length.  Wrapper for `pcie_us_axi_master_rd` and `pcie_us_axi_master_wr`.

### `pcie_us_axi_master_rd` module

PCIe AXI master module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Parametrizable AXI burst length.

### `pcie_us_axi_master_wr` module

PCIe AXI master module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit datapaths.  Parametrizable AXI burst length.

### `pcie_us_axil_master` module

PCIe AXI lite master module for Xilinx UltraScale series FPGAs.  Supports 64, 128, 256, and 512 bit PCIe interfaces.

### `pcie_us_axis_cq_demux` module

Demux module for Xilinx UltraScale CQ interface.  Can be used to route incoming requests based on function, BAR, and other fields.  Supports 64, 128, 256, and 512 bit datapaths.

### `pcie_us_axis_rc_demux` module

Demux module for Xilinx UltraScale RC interface.  Can be used to route incoming completions based on the requester ID (function).  Supports 64, 128, 256, and 512 bit datapaths.

### `pcie_us_cfg` module

Configuration shim for Xilinx UltraScale series FPGAs.

### `pcie_us_if` module

PCIe interface shim for Xilinx UltraScale series FPGAs.  Wrapper for all Xilinx UltraScale PCIe interface shims.

### `pcie_us_if_cc` module

PCIe interface shim (CC) for Xilinx UltraScale series FPGAs.

### `pcie_us_if_cq` module

PCIe interface shim (CQ) for Xilinx UltraScale series FPGAs.

### `pcie_us_if_rc` module

PCIe interface shim (RC) for Xilinx UltraScale series FPGAs.

### `pcie_us_if_rq` module

PCIe interface shim (RQ) for Xilinx UltraScale series FPGAs.

### `pcie_us_msi` module

MSI shim for Xilinx UltraScale series FPGAs.

### `priority_encoder` module

Parametrizable priority encoder.

### `pulse_merge` module

Parametrizable pulse merge module.  Combines several single-cycle pulse status signals together.

### Common signals

### Common parameters

### Source Files

    arbiter.v                  : Parametrizable arbiter
    axis_arb_mux.v             : Parametrizable AXI stream mux
    dma_client_axis_sink.v     : AXI stream sink DMA client
    dma_client_axis_source.v   : AXI stream source DMA client
    dma_if_axi.v               : AXI DMA interface
    dma_if_axi_rd.v            : AXI DMA interface (read)
    dma_if_axi_wr.v            : AXI DMA interface (write)
    dma_if_desc_mux.v          : DMA interface descriptor mux
    dma_if_mux.v               : DMA interface mux
    dma_if_mux_rd.v            : DMA interface mux (read)
    dma_if_mux_wr.v            : DMA interface mux (write)
    dma_if_pcie.v              : PCIe DMA interface
    dma_if_pcie_rd.v           : PCIe DMA interface (read)
    dma_if_pcie_wr.v           : PCIe DMA interface (write)
    dma_if_pcie_us.v           : PCIe DMA interface for Xilinx UltraScale
    dma_if_pcie_us_rd.v        : PCIe DMA interface for Xilinx UltraScale (read)
    dma_if_pcie_us_wr.v        : PCIe DMA interface for Xilinx UltraScale (write)
    dma_psdpram.v              : DMA RAM (segmented simple dual port RAM)
    dma_psdpram_async.v        : DMA RAM (segmented simple dual port RAM)
    dma_ram_demux.v            : DMA RAM demultiplexer
    dma_ram_demux_rd.v         : DMA RAM demultiplexer (read)
    dma_ram_demux_wr.v         : DMA RAM demultiplexer (write)
    pcie_axi_dma_desc_mux.v    : Descriptor mux for DMA engine
    pcie_axi_master.v          : PCIe AXI master module
    pcie_axi_master_rd.v       : PCIe AXI master read module
    pcie_axi_master_wr.v       : PCIe AXI master write module
    pcie_axil_master.v         : PCIe AXI Lite master module
    pcie_axil_master_minimal.v : PCIe AXI Lite master module (minimal)
    pcie_s10_cfg.v             : Configuration shim for Intel Stratix 10
    pcie_s10_if.v              : PCIe interface shim (Intel Stratix 10)
    pcie_s10_if_rx.v           : PCIe interface shim (RX) (Intel Stratix 10)
    pcie_s10_if_tx.v           : PCIe interface shim (TX) (Intel Stratix 10)
    pcie_s10_msi.v             : MSI shim for Intel Stratix 10 devices
    pcie_tlp_demux.v           : PCIe TLP demultiplexer
    pcie_tlp_demux_bar.v       : PCIe TLP demultiplexer (BAR ID)
    pcie_tlp_mux.v             : PCIe TLP multiplexer
    pcie_us_axi_dma.v          : PCIe AXI DMA module (Xilinx UltraScale)
    pcie_us_axi_dma_rd.v       : PCIe AXI DMA read module (Xilinx UltraScale)
    pcie_us_axi_dma_wr.v       : PCIe AXI DMA write module (Xilinx UltraScale)
    pcie_us_axi_master.v       : PCIe AXI master module (Xilinx UltraScale)
    pcie_us_axi_master_rd.v    : PCIe AXI master read module (Xilinx UltraScale)
    pcie_us_axi_master_wr.v    : PCIe AXI master write module (Xilinx UltraScale)
    pcie_us_axil_master.v      : PCIe AXI Lite master module (Xilinx UltraScale)
    pcie_us_axis_cq_demux.v    : Parametrizable AXI stream CQ demux
    pcie_us_axis_rc_demux.v    : Parametrizable AXI stream RC demux
    pcie_us_cfg.v              : Configuration shim for Xilinx UltraScale devices
    pcie_us_if.v               : PCIe interface shim (Xilinx UltraScale)
    pcie_us_if_cc.v            : PCIe interface shim (CC) (Xilinx UltraScale)
    pcie_us_if_cq.v            : PCIe interface shim (CQ) (Xilinx UltraScale)
    pcie_us_if_rc.v            : PCIe interface shim (RC) (Xilinx UltraScale)
    pcie_us_if_rq.v            : PCIe interface shim (RQ) (Xilinx UltraScale)
    pcie_us_msi.v              : MSI shim for Xilinx UltraScale devices
    priority_encoder.v         : Parametrizable priority encoder
    pulse_merge                : Parametrizable pulse merge module

## Testing

Running the included testbenches requires [cocotb](https://github.com/cocotb/cocotb), [cocotbext-axi](https://github.com/alexforencich/cocotbext-axi), [cocotbext-pcie](https://github.com/alexforencich/cocotbext-pcie), and [Icarus Verilog](http://iverilog.icarus.com/).  The testbenches can be run with pytest directly (requires [cocotb-test](https://github.com/themperek/cocotb-test)), pytest via tox, or via cocotb makefiles.
