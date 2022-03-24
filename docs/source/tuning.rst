.. _tuning:

==================
Performance Tuning
==================

Here are some tips and tricks to get the best possible performance with Corundum.

First, it's always a good idea to test with a commercial 100G NIC as a sanity check - if a commercial 100G NIC doesn't run near 100G line rate, then Corundum will definitely have issues.

Second, check the PCIe configuration with ``lspci``.  You'll want to make sure that the card is actually running with the full PCIe bandwidth.  Some x16 PCIe slots don't have all of the lanes physically wired, and in many cases lanes can be switched between slots depending on which slots are used---for example, two slots may share 16 lanes, if the second slot is empty, the first slot will use all 16 lanes, but if the second slot has a card installed, both slots will run with 8 lanes.

This is what ``lspci`` reports for Corundum in a gen 3 x16 configuration in a machine with an AMD EPYC 7302P CPU::

    $ sudo lspci -d 1234:1001 -vvv
    81:00.0 Ethernet controller: Device 1234:1001
        Subsystem: Silicom Denmark Device a00e
        Control: I/O- Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR- FastB2B- DisINTx+
        Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
        Latency: 0, Cache Line Size: 64 bytes
        Interrupt: pin ? routed to IRQ 337
        NUMA node: 1
        IOMMU group: 13
        Region 0: Memory at 20020000000 (64-bit, prefetchable) [size=16M]
        Capabilities: [40] Power Management version 3
            Flags: PMEClk- DSI- D1- D2- AuxCurrent=0mA PME(D0-,D1-,D2-,D3hot-,D3cold-)
            Status: D0 NoSoftRst+ PME-Enable- DSel=0 DScale=0 PME-
        Capabilities: [48] MSI: Enable+ Count=32/32 Maskable+ 64bit+
            Address: 00000000fee00000  Data: 0000
            Masking: 00000000  Pending: 00000000
        Capabilities: [70] Express (v2) Endpoint, MSI 00
            DevCap: MaxPayload 1024 bytes, PhantFunc 0, Latency L0s <64ns, L1 <1us
                ExtTag+ AttnBtn- AttnInd- PwrInd- RBE+ FLReset- SlotPowerLimit 75.000W
            DevCtl: CorrErr+ NonFatalErr+ FatalErr+ UnsupReq-
                RlxdOrd+ ExtTag+ PhantFunc- AuxPwr- NoSnoop+
                MaxPayload 512 bytes, MaxReadReq 512 bytes
            DevSta: CorrErr+ NonFatalErr- FatalErr- UnsupReq+ AuxPwr- TransPend-
            LnkCap: Port #0, Speed 8GT/s, Width x16, ASPM not supported
                ClockPM- Surprise- LLActRep- BwNot- ASPMOptComp+
            LnkCtl: ASPM Disabled; RCB 64 bytes, Disabled- CommClk+
                ExtSynch- ClockPM- AutWidDis- BWInt- AutBWInt-
            LnkSta: Speed 8GT/s (ok), Width x16 (ok)
                TrErr- Train- SlotClk+ DLActive- BWMgmt- ABWMgmt-
            DevCap2: Completion Timeout: Range BC, TimeoutDis+ NROPrPrP- LTR-
                 10BitTagComp- 10BitTagReq- OBFF Not Supported, ExtFmt- EETLPPrefix-
                 EmergencyPowerReduction Not Supported, EmergencyPowerReductionInit-
                 FRS- TPHComp- ExtTPHComp-
                 AtomicOpsCap: 32bit- 64bit- 128bitCAS-
            DevCtl2: Completion Timeout: 50us to 50ms, TimeoutDis- LTR- OBFF Disabled,
                 AtomicOpsCtl: ReqEn-
            LnkCap2: Supported Link Speeds: 2.5-8GT/s, Crosslink- Retimer- 2Retimers- DRS-
            LnkCtl2: Target Link Speed: 8GT/s, EnterCompliance- SpeedDis-
                 Transmit Margin: Normal Operating Range, EnterModifiedCompliance- ComplianceSOS-
                 Compliance De-emphasis: -6dB
            LnkSta2: Current De-emphasis Level: -6dB, EqualizationComplete+ EqualizationPhase1+
                 EqualizationPhase2+ EqualizationPhase3+ LinkEqualizationRequest-
                 Retimer- 2Retimers- CrosslinkRes: unsupported
        Capabilities: [100 v1] Advanced Error Reporting
            UESta:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq- ACSViol-
            UEMsk:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq- ACSViol-
            UESvrt: DLP+ SDES+ TLP- FCP+ CmpltTO- CmpltAbrt- UnxCmplt- RxOF+ MalfTLP+ ECRC- UnsupReq- ACSViol-
            CESta:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+
            CEMsk:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+
            AERCap: First Error Pointer: 00, ECRCGenCap- ECRCGenEn- ECRCChkCap- ECRCChkEn-
                MultHdrRecCap- MultHdrRecEn- TLPPfxPres- HdrLogCap-
            HeaderLog: 00000000 00000000 00000000 00000000
        Capabilities: [1c0 v1] Secondary PCI Express
            LnkCtl3: LnkEquIntrruptEn- PerformEqu-
            LaneErrStat: 0
        Kernel driver in use: mqnic

The device driver also prints out some PCIe-related information when it attaches to the device, to save the trouble of running ``lspci``::

    [  349.460705] mqnic 0000:81:00.0: mqnic PCI probe
    [  349.460712] mqnic 0000:81:00.0:  Vendor: 0x1234
    [  349.460715] mqnic 0000:81:00.0:  Device: 0x1001
    [  349.460717] mqnic 0000:81:00.0:  Subsystem vendor: 0x1c2c
    [  349.460719] mqnic 0000:81:00.0:  Subsystem device: 0xa00e
    [  349.460721] mqnic 0000:81:00.0:  Class: 0x020000
    [  349.460723] mqnic 0000:81:00.0:  PCI ID: 0000:81:00.0
    [  349.460730] mqnic 0000:81:00.0:  Max payload size: 512 bytes
    [  349.460733] mqnic 0000:81:00.0:  Max read request size: 512 bytes
    [  349.460735] mqnic 0000:81:00.0:  Link capability: gen 3 x16
    [  349.460737] mqnic 0000:81:00.0:  Link status: gen 3 x16
    [  349.460739] mqnic 0000:81:00.0:  Relaxed ordering: enabled
    [  349.460740] mqnic 0000:81:00.0:  Phantom functions: disabled
    [  349.460742] mqnic 0000:81:00.0:  Extended tags: enabled
    [  349.460744] mqnic 0000:81:00.0:  No snoop: enabled
    [  349.460745] mqnic 0000:81:00.0:  NUMA node: 1
    [  349.460753] mqnic 0000:81:00.0: 126.016 Gb/s available PCIe bandwidth (8.0 GT/s PCIe x16 link)
    [  349.460767] mqnic 0000:81:00.0: enabling device (0000 -> 0002)
    [  349.460802] mqnic 0000:81:00.0: Control BAR size: 16777216
    [  349.462723] mqnic 0000:81:00.0: Configured 32 IRQs

Note that ``lspci`` reports ``LnkSta: Speed 8GT/s (ok), Width x16 (ok)``, indicating that the link is running at the max supported speed and max supported link width.  If one of those is reported as ``(degraded)``, then further investigation is required.  If ``(ok)`` or ``(degraded)`` is not shown, then compare ``LnkSta`` with ``LnkCap`` to see if ``LnkSta`` reports lower values.  In this case, ``lspci`` reports ``LnkCap: Port #0, Speed 8GT/s, Width x16``, which matches ``LnkSta``.  It also reports ``MSI: Enable+ Count=32/32``, indicating that all 32 MSI channels are active.  Some motherboards do not fully implement MSI and limit devices to a single channel.  Eventually, Corundum will migrate to MSI-X to mitigate this issue, as well as support more interrupt channels.  Also note that ``lspci`` reports ``MaxPayload 512 bytes``---this is the largest that I have seen so far (on AMD EPYC), most modern systems report 256 bytes.  Obviously, the larger, the better in terms of PCIe overhead.

Non-uniform memory access (NUMA) is another potential pitfall to be aware of.  Systems with multiple CPU sockets will generally have at least one NUMA node associated with each socket, and some CPUs, like AMD EPYC, have internal NUMA nodes even with a single CPU.  For best performance, any processes that access the NIC should be pinned to the NIC's local NUMA node.  If packets are stored in memory located on a different NUMA node, then there will be a performance penalty associated with the NIC accessing that memory via QPI, UPI, etc.  Use ``numactl -s`` to get a list of all physical CPUs and NUMA nodes on the system.  If only one node is listed, then no binding is required.  If you're running a CPU with internal NUMA nodes such as AMD EPYC, make sure that BIOS is set up to expose the internal NUMA nodes.  The NUMA node associated with the network interface is shown both in the ``lspci`` and driver output output (``NUMA node: 3``), and it can also be read from sysfs (``/sys/class/net/<dev>/device/numa_node``).  Use ``numactl -l -N <node> <command>`` to run programs on a specified NUMA node, for example, ``numactl -l -N 3 iperf3 -s``.  Recent versions of ``numactl`` also support automatically determining the NUMA node from the network device name, so in this case ``numactl -l -N netdev:enp129s0 iperf3 -s`` would run ``iperf`` on the NUMA node that ``enp129s0`` is associated with.  It's important to make sure that both the client and the server are run on the correct NUMA node, so it's probably a better idea to manually run ``iperf3 -s`` under ``numactl`` than to run ``iperf3`` as a system service that could potentially run on any NUMA node.  On Intel CPUs, `PCM <https://github.com/opcm/pcm>`_ can be used to monitor QPI/UPI traffic to confirm that processes are bound to the correct NUMA nodes.

It's also advisable to go into BIOS setup and disable any power-management features to get the system into its highest-performance state.

Notes on the performance evaluation for the FCCM paper: the servers used are Dell R540 machines with dual Intel Xeon 6138 CPUs and all memory channels populated, and ``lspci`` reports ``MaxPayload 256 bytes``.  The machines have two NUMA nodes, so only one CPU is used for performance evaluation to prevent traffic from traversing the UPI link.  On these machines, a single ``iperf`` process would run at 20-30 Gbps with 1500 byte MTU, or 40-50 Gbps with 9000 byte MTU.  The Corundum design for those tests was configured with 8192 TX queues and 256 RX queues.
