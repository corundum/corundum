.. _device_list:

===========
Device list
===========

This section includes a summary of the various devices supported by Corundum, including a summary of board-specific features.

PCIe
====

This section details PCIe form-factor targets, which interface with a separate host system via PCI express as a PCIe endpoint.

.. table:: Summary of the various devices supported by Corundum.

    ============  =======================  ====================  ==========
    Manufacturer  Board                    FPGA                  Board ID
    ============  =======================  ====================  ==========
    Alpha Data    ADM-PCIE-9V3             XCVU3P-2FFVC1517I     0x41449003
    Dini Group    DNPCIe_40G_KU_LL_2QSFP   XCKU040-2FFVA1156E    0x17df1a00
    Cisco         Nexus K35-S              XCKU035-2FBVA676E     0x1ce40003
    Cisco         Nexus K3P-S              XCKU3P-2FFVB676E      0x1ce40009
    Cisco         Nexus K3P-Q              XCKU3P-2FFVB676E      0x1ce4000a
    Silicom       fb2CG\@KU15P             XCKU15P-2FFVE1760E    0x1c2ca00e
    Digilent      NetFPGA SUME             XC7V690T-3FFG1761     0x10ee7028
    BittWare      XUP-P3R                  XCVU9P-2FLGB2104E     0x12ba9823
    Intel         DK-DEV-1SMX-H-A          1SM21BHU2F53E1VG      0x11720001
    Intel         DK-DEV-1SMC-H-A          1SM21CHU1F53E1VG      0x11720001
    Xilinx        Alveo U50                XCU50-2FSVH2104E      0x10ee9032
    Xilinx        Alveo U200               XCU200-2FSGD2104E     0x10ee90c8
    Xilinx        Alveo U250               XCU250-2FIGD2104E     0x10ee90fa
    Xilinx        Alveo U280               XCU280-L2FSVH2892E    0x10ee9118
    Xilinx        VCU108                   XCVU095-2FFVA2104E    0x10ee806c
    Xilinx        VCU118                   XCVU9P-L2FLGA2104E    0x10ee9076
    Xilinx        VCU1525                  XCVU9P-L2FSGD2014E    0x10ee95f5
    Xilinx        ZCU106                   XCZU7EV-2FFVC1156E    0x10ee906a
    ============  =======================  ====================  ==========

.. table:: Summary of available interfaces and on-board memory.

    =======================  =========  ==========  ===============================  =====
    Board                    PCIe IF    Network IF  DDR                              HBM
    =======================  =========  ==========  ===============================  =====
    ADM-PCIE-9V3             Gen 3 x16  2x QSFP28   16 GB DDR4 2400 (2x 1G x72)      \-
    DNPCIe_40G_KU_LL_2QSFP   Gen 3 x8   2x QSFP+    4 GB DDR4 2400 (512M x72)        \-
    Nexus K35-S              Gen 3 x8   2x SFP+     \-                               \-
    Nexus K3P-S              Gen 3 x8   2x SFP28    4 GB DDR4 (1G x32)               \-
    Nexus K3P-Q              Gen 3 x8   2x QSFP28   8 GB DDR4 (1G x72)               \-
    fb2CG\@KU15P             Gen 3 x16  2x QSFP28   16 GB DDR4 2400 (4x 512M x72)    \-
    NetFPGA SUME             Gen 3 x8   4x SFP+     8 GB DDR3 1866 (2x 512M x64)     \-
    XUP-P3R                  Gen 3 x16  4x QSFP28   4x DDR4 2400 DIMM (4x x72)       \-
    DK-DEV-1SMX-H-A          Gen 3 x8   2x QSFP28   8 GB DDR4 2666 (2x 512M x72)     8 GB
    DK-DEV-1SMC-H-A          Gen 3 x8   2x QSFP28   8 GB DDR4 2666 (2x 512M x72)     16 GB
    Alveo U50                Gen 3 x16  1x QSFP28   \-                               8 GB
    Alveo U200               Gen 3 x16  2x QSFP28   64 GB DDR4 2400 (4x 2G x72)      \-
    Alveo U250               Gen 3 x16  2x QSFP28   64 GB DDR4 2400 (4x 2G x72)      \-
    Alveo U280               Gen 3 x16  2x QSFP28   32 GB DDR4 2400 (2x 2G x72)      8 GB
    VCU108                   Gen 3 x8   1x QSFP28   4 GB DDR4 2400 (2x 256M x80)     \-
    VCU118                   Gen 3 x16  2x QSFP28   4 GB DDR4 2400 (2x 256M x80)     \-
    VCU1525                  Gen 3 x16  2x QSFP28   64 GB DDR4 2400 (4x 2G x72)      \-
    ZCU106                   Gen 3 x4   2x SFP+     2 GB DDR4 2400 (256M x64)        \-
    =======================  =========  ==========  ===============================  =====

.. table:: Summary of support for various ancillary features.

    =======================  ============  ============  ==========
    Board                    I2C :sup:`1`  MAC :sup:`2`  FW update
    =======================  ============  ============  ==========
    ADM-PCIE-9V3             N :sup:`3`    Y :sup:`5`    Y
    DNPCIe_40G_KU_LL_2QSFP   Y             N :sup:`3`    Y
    Nexus K35-S              N :sup:`3`    Y             Y
    Nexus K3P-S              N :sup:`3`    Y             Y
    Nexus K3P-Q              Y             Y             Y
    fb2CG\@KU15P             Y             Y             Y
    NetFPGA SUME             Y             N :sup:`7`    N :sup:`8`
    XUP-P3R                  Y             Y             Y
    DK-DEV-1SMX-H-A          N             N             N
    DK-DEV-1SMC-H-A          N             N             N
    Alveo U50                N :sup:`4`    Y             Y
    Alveo U200               Y             Y             Y
    Alveo U250               Y             Y             Y
    Alveo U280               N :sup:`4`    Y             Y
    VCU108                   Y             Y :sup:`5`    Y
    VCU118                   Y             Y :sup:`5`    Y
    VCU1525                  Y             Y :sup:`5`    Y
    ZCU106                   Y             Y :sup:`5`    Y
    =======================  ============  ============  ==========

- :sup:`1` I2C access to optical modules
- :sup:`2` Persistent MAC address storage
- :sup:`3` Supported in hardware, driver support in progress
- :sup:`4` Limited read/write access via BMC pending driver support, full read/write access requires support in BMC firmware
- :sup:`5` Can read MAC from I2C EEPROM, but EEPROM is blank from factory
- :sup:`6` MAC available from BMC, but accessing BMC is not yet implemented
- :sup:`7` No on-board EEPROM
- :sup:`8` Flash sits behind CPLD, not currently exposed via PCIe

.. table:: Summary of the board-specific design variants and some important configuration parameters.

    =======================  ===========================  ====  =======  ====  =====
    Board                    Design                       IFxP  RXQ/TXQ  MAC   Sched
    =======================  ===========================  ====  =======  ====  =====
    ADM-PCIE-9V3             mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    ADM-PCIE-9V3             mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    ADM-PCIE-9V3             mqnic/fpga_25g/fpga_tdma     2x1   256/256  25G   TDMA
    ADM-PCIE-9V3             mqnic/fpga_100g/fpga         2x1   256/8K   100G  RR
    ADM-PCIE-9V3             mqnic/fpga_100g/fpga_tdma    2x1   256/256  100G  TDMA
    DNPCIe_40G_KU_LL_2QSFP   mqnic/fpga/fpga_ku040        2x1   256/2K   10G   RR
    DNPCIe_40G_KU_LL_2QSFP   mqnic/fpga/fpga_ku060        2x1   256/2K   10G   RR
    Nexus K35-S              mqnic/fpga/fpga              2x1   256/2K   10G   RR
    Nexus K3P-S              mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    Nexus K3P-S              mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    Nexus K3P-Q              mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    Nexus K3P-Q              mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    fb2CG\@KU15P             mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    fb2CG\@KU15P             mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    fb2CG\@KU15P             mqnic/fpga_25g/fpga_tdma     2x1   256/256  25G   TDMA
    fb2CG\@KU15P             mqnic/fpga_100g/fpga         2x1   256/8K   100G  RR
    fb2CG\@KU15P             mqnic/fpga_100g/fpga_tdma    2x1   256/256  100G  TDMA
    NetFPGA SUME             mqnic/fpga/fpga              1x1   256/512  10G   RR
    XUP-P3R                  mqnic/fpga_25g/fpga          4x1   256/8K   25G   RR
    XUP-P3R                  mqnic/fpga_25g/fpga_10g      4x1   256/8K   10G   RR
    XUP-P3R                  mqnic/fpga_100g/fpga         4x1   256/8K   100G  RR
    DK-DEV-1SMX-H-A          mqnic/fpga_10g/fpga_1sm21b   2x1   256/1K   10G   RR
    DK-DEV-1SMC-H-A          mqnic/fpga_10g/fpga_1sm21c   2x1   256/1K   10G   RR
    Alveo U50                mqnic/fpga_25g/fpga          1x1   256/8K   25G   RR
    Alveo U50                mqnic/fpga_25g/fpga_10g      1x1   256/8K   10G   RR
    Alveo U50                mqnic/fpga_100g/fpga         1x1   256/8K   100G  RR
    Alveo U200               mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    Alveo U200               mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    Alveo U200               mqnic/fpga_100g/fpga         2x1   256/8K   100G  RR
    Alveo U250               mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    Alveo U250               mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    Alveo U250               mqnic/fpga_100g/fpga         2x1   256/8K   100G  RR
    Alveo U280               mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    Alveo U280               mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    Alveo U280               mqnic/fpga_100g/fpga         2x1   256/8K   100G  RR
    VCU108                   mqnic/fpga_10g/fpga          1x1   256/2K   10G   RR
    VCU118                   mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    VCU118                   mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    VCU118                   mqnic/fpga_100g/fpga         2x1   256/8K   100G  RR
    VCU1525                  mqnic/fpga_25g/fpga          2x1   256/8K   25G   RR
    VCU1525                  mqnic/fpga_25g/fpga_10g      2x1   256/8K   10G   RR
    VCU1525                  mqnic/fpga_100g/fpga         2x1   256/8K   100G  RR
    ZCU106                   mqnic/fpga_pcie/fpga         2x1   256/8K   10G   RR
    =======================  ===========================  ====  =======  ====  =====

SoC
===

This section details SoC targets, which interface with CPU cores on the same device, usually via AXI.

.. table:: Summary of the various devices supported by Corundum.

    ============  =================  ====================  ==========
    Manufacturer  Board              FPGA                  Board ID
    ============  =================  ====================  ==========
    Xilinx        ZCU106             XCZU7EV-2FFVC1156E    0x10ee906a
    ============  =================  ====================  ==========

.. table:: Summary of available interfaces and on-board memory.

    =================  =========  ==========  ===============================  =====
    Board              PCIe IF    Network IF  DDR                              HBM
    =================  =========  ==========  ===============================  =====
    ZCU106             Gen 3 x4   2x SFP+     2 GB DDR4 2400 (256M x64)        \-
    =================  =========  ==========  ===============================  =====

.. table:: Summary of support for various ancillary features.

    =================  ============  ============  ==========
    Board              I2C :sup:`1`  MAC :sup:`2`  FW update
    =================  ============  ============  ==========
    ZCU106             Y             Y :sup:`3`    N
    =================  ============  ============  ==========

- :sup:`1` I2C access to optical modules
- :sup:`2` Persistent MAC address storage
- :sup:`3` Can read MAC from I2C EEPROM, but EEPROM is blank from factory

.. table:: Summary of the board-specific design variants and some important configuration parameters.

    =================  =========================  ====  =======  ====  =====
    Board              Design                     IFxP  RXQ/TXQ  MAC   Sched
    =================  =========================  ====  =======  ====  =====
    ZCU106             mqnic/fpga_zynqmp/fpga     2x1   32/32    10G   RR
    =================  =========================  ====  =======  ====  =====
