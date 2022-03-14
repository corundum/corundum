.. _modules_overview:

========
Overview
========

Corundum has several unique architectural features.  First, hardware queue states are stored efficiently in FPGA block RAM, enabling support for thousands of individually-controllable queues.  These queues are associated with interfaces, and each interface can have multiple ports, each with its own independent transmit scheduler.  This enables extremely fine-grained control over packet transmission.  The scheduler module is designed to be modified or swapped out completely to implement different transmit scheduling schemes, including experimental schedulers.  Coupled with PTP time synchronization, this enables time-based scheduling, including high precision TDMA.

The design of Corundum is  modular and highly parametrized.  Many configuration and structural options can be set at synthesis time by Verilog parameters, including interface and port counts, queue counts, memory sizes, etc.  These design parameters are exposed in configuration registers that the driver reads to determine the NIC configuration, enabling the same driver to support many different boards and configurations without modification.

High-level overview
===================

.. _fig_overview_block:
.. figure:: /diagrams/svg/corundum_block.svg

    Block diagram of the Corundum NIC. PCIe HIP: PCIe hard IP core; AXIL M: AXI lite master; DMA IF: DMA interface; AXI M: AXI master; PHC: PTP hardware clock; TXQ: transmit queue manager; TXCQ: transmit completion queue manager; RXQ: receive queue manager; RXCQ: receive completion queue manager; EQ: event queue manager; MAC + PHY: Ethernet media access controller (MAC) and physical interface layer (PHY).

A  block diagram of the Corundum NIC is shown in :numref:`fig_overview_block`.  At a high level, the NIC consists of several hierarchy levels.  The top-level module primarily contains support and interfacing components. These components include the PCI express hard IP core and Ethernet interface components including MACs, PHYs, and associated serializers, along with an instance of an appropriate :ref:`mod_mqnic_core` wrapper, which provides the DMA interface.  This core module contains the PTP clock (:ref:`mod_mqnic_ptp`), application section (:ref:`mod_mqnic_app_block`), and one or more :ref:`mod_mqnic_interface` module instances.  Each interface module corresponds to an operating-system-level network interface (e.g. ``eth0``), and contains the queue management logic, descriptor and completion handling logic, transmit schedulers, transmit and receive engines, transmit and receive datapaths, and a scratchpad RAM for temporarily storing incoming and outgoing packets during DMA operations.  The queue management logic maintains the queue state for all of the NIC queues---transmit, transmit completion, receive, receive completion, and event queues.

For each interface, the transmit scheduler (:ref:`mod_mqnic_tx_scheduler_block`) in the interface module decides which queues are designated for transmission. The transmit scheduler generates commands for the transmit engine, which coordinates operations on the transmit datapath.  The scheduler module is a flexible functional block that can be modified or replaced to support arbitrary schedules, which may be event driven.  The default implementation of the scheduler in :ref:`mod_tx_scheduler_rr` is simple round robin.  All ports associated with the same interface module share the same set of transmit queues and appear as a single, unified interface to the operating system.  This enables flows to be migrated between ports or load-balanced across multiple ports by changing only the transmit scheduler settings without affecting the rest of the network stack.  This dynamic, scheduler-defined mapping of queues to ports is a unique feature of Corundum that can enable research into new protocols and network architectures, including parallel networks and optically-switched networks.

In the receive direction, incoming packets pass through a flow hash module to determine the target receive queue and generate commands for the receive engine, which coordinates operations on the receive datapath.  Because all ports in the same interface module share the same set of receive queues, incoming flows on different ports are merged together into the same set of queues.

An application block (:ref:`mod_mqnic_app_block`) is provided for customization, including packet processing, routing, and in-network compute applications.  The application block has connections to several different subsystems.

The components on the NIC are interconnected with several different interfaces including AXI lite, AXI stream, and a custom segmented memory interface for DMA operations.  AXI lite is used for the control path from the driver to the NIC.  It is used to initialize and configure the NIC components and to control the queue pointers during transmit and receive operations.  AXI stream interfaces are used for transferring packetized data within the NIC.  The segmented memory interface serves to connect the PCIe DMA interface to the NIC datapath and to the descriptor and completion handling logic.

The majority of the NIC logic runs in the PCIe user clock domain, which is nominally 250 MHz for all of the current design variants.  Asynchronous FIFOs are used to interface with the MACs, which run in the serializer transmit and receive clock domains as appropriate---156.25 MHz for 10G, 390.625 MHz for 25G, and 322.265625 MHz for 100G.
