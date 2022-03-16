.. _device_list:

===========
Device list
===========

This section includes a summary of the various devices supported by Corundum, including a summary of board-specific features.

PCIe
====

This section details PCIe form-factor targets, which interface with a separate host system via PCI express as a PCIe endpoint.

.. table:: Summary of the various devices supported by Corundum.

    ============  =================  ====================  ==========
    Manufacturer  Board              FPGA                  Board ID
    ============  =================  ====================  ==========
    Alpha Data    ADM-PCIE-9V3       XCVU3P-2FFVC1517I     0x41449003
    Exablaze      ExaNIC X10         XCKU035-2FBVA676E     0x1ce40003
    Exablaze      ExaNIC X25         XCKU3P-2FFVB676E      0x1ce40009
    Silicom       fb2CG\@KU15P       XCKU15P-2FFVE1760E    0x1c2ca00e
    Digilent      NetFPGA SUME       XC7V690T-3FFG1761     0x10ee7028
    Intel         DK-DEV-1SMC-H-A    1SM21CHU1F53E1VG      0x11720001
    Xilinx        Alveo U50          XCU50-2FSVH2104E      0x10ee9032
    Xilinx        Alveo U200         XCU200-2FSGD2104E     0x10ee90c8
    Xilinx        Alveo U250         XCU250-2FIGD2104E     0x10ee90fa
    Xilinx        Alveo U280         XCU280-L2FSVH2892E    0x10ee9118
    Xilinx        VCU108             XCVU095-2FFVA2104E    0x10ee806c
    Xilinx        VCU118             XCVU9P-L2FLGA2104E    0x10ee9076
    Xilinx        VCU1525            XCVU9P-L2FSGD2014E    0x10ee95f5
    Xilinx        ZCU106             XCZU7EV-2FFVC1156E    0x10ee906a
    ============  =================  ====================  ==========

.. table:: Summary of available interfaces and on-board memory.

    =================  =========  ==========  ===============================  =====
    Board              PCIe IF    Network IF  DDR                              HBM
    =================  =========  ==========  ===============================  =====
    ADM-PCIE-9V3       Gen 3 x16  2x QSFP28   16 GB DDR4 2400 (2x 1G x72)      \-
    ExaNIC X10         Gen 3 x8   2x SFP+     \-                               \-
    ExaNIC X25         Gen 3 x8   2x SFP28    \-                               \-
    fb2CG\@KU15P       Gen 3 x16  2x QSFP28   16 GB DDR4 2400 (4x 512M x72)    \-
    NetFPGA SUME       Gen 3 x8   4x SFP+     8 GB DDR3 1866 (2x 512M x64)     \-
    DK-DEV-1SMC-H-A    Gen 3 x8   2x QSFP28   16 GB DDR4 2666 (2x 512M x72)    16 GB
    Alveo U50          Gen 3 x16  1x QSFP28   \-                               8 GB
    Alveo U200         Gen 3 x16  2x QSFP28   64 GB DDR4 2400 (4x 2G x72)      \-
    Alveo U250         Gen 3 x16  2x QSFP28   64 GB DDR4 2400 (4x 2G x72)      \-
    Alveo U280         Gen 3 x16  2x QSFP28   32 GB DDR4 2400 (2x 2G x72)      8 GB
    VCU108             Gen 3 x8   1x QSFP28   4 GB DDR4 2400 (2x 256M x80)     \-
    VCU118             Gen 3 x16  2x QSFP28   4 GB DDR4 2400 (2x 256M x80)     \-
    VCU1525            Gen 3 x16  2x QSFP28   64 GB DDR4 2400 (4x 2G x72)      \-
    ZCU106             Gen 3 x4   2x SFP+     2 GB DDR4 2400 (256M x64)        \-
    =================  =========  ==========  ===============================  =====

.. table:: Summary of support for various ancillary features.

    =================  ============  ============  ==========
    Board              I2C :sup:`1`  MAC :sup:`2`  FW update
    =================  ============  ============  ==========
    ADM-PCIE-9V3       N :sup:`3`    Y :sup:`5`    Y
    ExaNIC X10         N :sup:`3`    Y             Y
    ExaNIC X25         N :sup:`3`    Y             Y
    fb2CG\@KU15P       Y             Y             Y
    NetFPGA SUME       Y             N :sup:`7`    N :sup:`8`
    DK-DEV-1SMC-H-A    N             N             N
    Alveo U50          N :sup:`4`    Y             Y
    Alveo U200         Y             Y             Y
    Alveo U250         Y             Y             Y
    Alveo U280         N :sup:`4`    Y             Y
    VCU108             Y             Y :sup:`5`    Y
    VCU118             Y             Y :sup:`5`    Y
    VCU1525            Y             Y :sup:`5`    Y
    ZCU106             Y             Y :sup:`5`    Y
    =================  ============  ============  ==========

- :sup:`1` I2C access to optical modules
- :sup:`2` Persistent MAC address storage
- :sup:`3` Supported in hardware, driver support in progress
- :sup:`4` Limited read/write access via BMC pending driver support, full read/write access requires support in BMC firmware
- :sup:`5` Can read MAC from I2C EEPROM, but EEPROM is blank from factory
- :sup:`6` MAC available from BMC, but accessing BMC is not yet implemented
- :sup:`7` No on-board EEPROM
- :sup:`8` Flash sits behind CPLD, not currently exposed via PCIe

.. table:: Summary of the board-specific design variants and some important configuration parameters.

    =================  =========================  ====  =======  ====  =====
    Board              Design                     IFxP  RXQ/TXQ  MAC   Sched
    =================  =========================  ====  =======  ====  =====
    ADM-PCIE-9V3       mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    ADM-PCIE-9V3       mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    ADM-PCIE-9V3       mqnic/fpga_25g/fpga_tdma   2x1   256/256  25G   TDMA
    ADM-PCIE-9V3       mqnic/fpga_100g/fpga       2x1   256/8K   100G  RR
    ADM-PCIE-9V3       mqnic/fpga_100g/fpga_tdma  2x1   256/256  100G  TDMA
    ExaNIC X10         mqnic/fpga/fpga            2x1   256/1K   10G   RR
    ExaNIC X25         mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    ExaNIC X25         mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    fb2CG\@KU15P       mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    fb2CG\@KU15P       mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    fb2CG\@KU15P       mqnic/fpga_25g/fpga_tdma   2x1   256/256  25G   TDMA
    fb2CG\@KU15P       mqnic/fpga_100g/fpga       2x1   256/8K   100G  RR
    fb2CG\@KU15P       mqnic/fpga_100g/fpga_tdma  2x1   256/256  100G  TDMA
    NetFPGA SUME       mqnic/fpga/fpga            1x1   256/512  10G   RR
    DK-DEV-1SMC-H-A    mqnic/fpga_10g/fpga        2x1   256/1K   10G   RR
    Alveo U50          mqnic/fpga_25g/fpga        1x1   256/8K   25G   RR
    Alveo U50          mqnic/fpga_25g/fpga_10g    1x1   256/8K   10G   RR
    Alveo U50          mqnic/fpga_100g/fpga       1x1   256/8K   100G  RR
    Alveo U200         mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    Alveo U200         mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    Alveo U200         mqnic/fpga_100g/fpga       2x1   256/8K   100G  RR
    Alveo U250         mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    Alveo U250         mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    Alveo U250         mqnic/fpga_100g/fpga       2x1   256/8K   100G  RR
    Alveo U280         mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    Alveo U280         mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    Alveo U280         mqnic/fpga_100g/fpga       2x1   256/8K   100G  RR
    VCU108             mqnic/fpga_10g/fpga        1x1   256/2K   10G   RR
    VCU118             mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    VCU118             mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    VCU118             mqnic/fpga_100g/fpga       2x1   256/8K   100G  RR
    VCU1525            mqnic/fpga_25g/fpga        2x1   256/8K   25G   RR
    VCU1525            mqnic/fpga_25g/fpga_10g    2x1   256/8K   10G   RR
    VCU1525            mqnic/fpga_100g/fpga       2x1   256/8K   100G  RR
    ZCU106             mqnic/fpga_10g/fpga        2x1   256/8K   10G   RR
    =================  =========================  ====  =======  ====  =====
