.. _intro:

============
Introduction
============

Corundum is an open-source, high-performance :term:`FPGA`-based :term:`NIC` and platform for in-network compute.  Features include a high performance datapath, 10G/25G/100G Ethernet, PCI express gen 3, a custom, high performance, tightly-integrated :term:`PCIe` :term:`DMA` engine, many (1000+) transmit, receive, completion, and event queues, scatter/gather DMA, :term:`MSI`, multiple interfaces, multiple ports per interface, per-port transmit scheduling including high precision TDMA, flow hashing, :term:`RSS`, checksum offloading, and native IEEE 1588 :term:`PTP` timestamping.  A Linux driver is included that integrates with the Linux networking stack.  Development and debugging is facilitated by an extensive simulation framework that covers the entire system from a simulation model of the driver and PCI express interface on one side to the Ethernet interfaces on the other side.

Corundum has several unique architectural features.  First, transmit, receive, completion, and event queue states are stored efficiently in block RAM or ultra RAM, enabling support for thousands of individually-controllable queues.  These queues are associated with interfaces, and each interface can have multiple ports, each with its own independent scheduler.  This enables extremely fine-grained control over packet transmission.  Coupled with PTP time synchronization, this enables high precision TDMA.

Corundum also provides an application section for implementing custom logic.  The application section has a dedicated PCIe BAR for control and a number of interfaces that provide access to the core datapath and DMA infrastructure.

The latest source code is available from the `Corundum GitHub repository <https://github.com/corundum/corundum>`_.  To stay up to date with the latest developments and get support, consider joining the `mailing list <https://groups.google.com/d/forum/corundum-nic>`_ and `Zulip <https://corundum.zulipchat.com/>`_.

Corundum currently supports devices from both Xilinx and Intel, on boards from several different manufacturers.  Designs are included for the following FPGA boards; see :ref:`device_list` for more details:

*  Alpha Data ADM-PCIE-9V3 (Xilinx Virtex UltraScale+ XCVU3P)
*  Dini Group DNPCIe_40G_KU_LL_2QSFP (Xilinx Kintex UltraScale XCKU040)
*  Cisco Nexus K35-S (Xilinx Kintex UltraScale XCKU035)
*  Cisco Nexus K3P-S (Xilinx Kintex UltraScale+ XCKU3P)
*  Cisco Nexus K3P-Q (Xilinx Kintex UltraScale+ XCKU3P)
*  Silicom fb2CG\@KU15P (Xilinx Kintex UltraScale+ XCKU15P)
*  NetFPGA SUME (Xilinx Virtex 7 XC7V690T)
*  BittWare 250-SoC (Xilinx Zynq UltraScale+ XCZU19EG)
*  BittWare XUP-P3R (Xilinx Virtex UltraScale+ XCVU9P)
*  Intel Stratix 10 MX dev kit (Intel Stratix 10 MX 2100)
*  Intel Stratix 10 DX dev kit (Intel Stratix 10 DX 2800)
*  Terasic DE10-Agilex (Intel Agilex F 014)
*  Xilinx Alveo U50 (Xilinx Virtex UltraScale+ XCU50)
*  Xilinx Alveo U200 (Xilinx Virtex UltraScale+ XCU200)
*  Xilinx Alveo U250 (Xilinx Virtex UltraScale+ XCU250)
*  Xilinx Alveo U280 (Xilinx Virtex UltraScale+ XCU280)
*  Xilinx VCU108 (Xilinx Virtex UltraScale XCVU095)
*  Xilinx VCU118 (Xilinx Virtex UltraScale+ XCVU9P)
*  Xilinx VCU1525 (Xilinx Virtex UltraScale+ XCVU9P)
*  Xilinx ZCU102 (Xilinx Zynq UltraScale+ XCZU9EG)
*  Xilinx ZCU106 (Xilinx Zynq UltraScale+ XCZU7EV)

Publications
============

- A. Forencich, A. C. Snoeren, G. Porter, G. Papen, *Corundum: An Open-Source 100-Gbps NIC,* in FCCM'20. (`FCCM Paper <https://www.cse.ucsd.edu/~snoeren/papers/corundum-fccm20.pdf>`_, `FCCM Presentation <https://www.fccm.org/past/2020/forums/topic/corundum-an-open-source-100-gbps-nic/>`_)

- J. A. Forencich, *System-Level Considerations for Optical Switching in Data Center Networks*. (`Thesis <https://escholarship.org/uc/item/3mc9070t>`_)

Citation
========

If you use Corundum in your project, please cite one of the following papers
and/or link to the project on GitHub::

    @inproceedings{forencich2020fccm,
        author = {Alex Forencich and Alex C. Snoeren and George Porter and George Papen},
        title = {Corundum: An Open-Source {100-Gbps} {NIC}},
        booktitle = {28th IEEE International Symposium on Field-Programmable Custom Computing Machines},
        year = {2020},
    }

    @phdthesis{forencich2020thesis,
        author = {John Alexander Forencich},
        title = {System-Level Considerations for Optical Switching in Data Center Networks},
        school = {UC San Diego},
        year = {2020},
        url = {https://escholarship.org/uc/item/3mc9070t},
    }

.. only:: html

    Indices and tables
    ==================

    * :ref:`genindex`
    * :ref:`modindex`
    * :ref:`search`
