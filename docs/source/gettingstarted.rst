.. _gettingstarted:

===============
Getting Started
===============

Join the Corundum community
===========================

To stay up to date with the latest developments and get support, consider joining the `mailing list <https://groups.google.com/d/forum/corundum-nic>`_ and `Zulip <https://corundum.zulipchat.com/>`_.

Obtaining the source code
=========================

The main `upstream repository for Corundum <https://github.com/corundum/corundum/>`_ is located on `GitHub <https://github.com/>`_.  There are two main ways to download the source code - downloading an archive, or cloning with git.  

To clone via HTTPS, run::

    $ git clone https://github.com/corundum/corundum.git

To clone via SSH, run::

    $ git clone git@github.com:corundum/corundum.git

Alternatively, download a zip file::

    $ wget https://github.com/corundum/corundum/archive/refs/heads/master.zip
    $ unzip master.zip

Or a gzipped tar archive file::

    $ wget https://github.com/corundum/corundum/archive/refs/heads/master.tar.gz
    $ tar xvf master.tar.gz

There is also a `mirror of the repository <https://gitee.com/alexforencich/corundum/>`_ on `gitee <https://gitee.com/>`_, here are the equivalent commands::

    $ git clone https://gitee.com/alexforencich/corundum.git
    $ git clone git@gitee.com:alexforencich/corundum.git
    $ wget https://gitee.com/alexforencich/corundum/repository/archive/master.zip
    $ wget https://gitee.com/alexforencich/corundum/repository/archive/master.tar.gz

Setting up the FPGA development environment
===========================================

Corundum currently uses `Icarus Verilog <http://iverilog.icarus.com/>`_ and `cocotb <https://github.com/cocotb/cocotb>`_ for simulation.  Linux is the recommended operating system for a development environment due to the use of symlinks (which can cause problems on Windows as they are not supported by windows filesystems), however WSL may also work well.

The required system packages are:

* Python 3 (``python`` or ``python3``, depending on distribution)
* Icarus Verilog (``iverilog``)
* GTKWave (``gtkwave``)

The required python packages are:

* ``cocotb``
* ``cocotb-bus``
* ``cocotb-test``
* ``cocotbext-axi``
* ``cocotbext-eth``
* ``cocotbext-pcie``
* ``pytest``
* ``scapy``

Recommended additional python packages:

* ``tox`` (to run pytest inside a python virtual environment)
* ``pytest-xdist`` (to run tests in parallel with `pytest -n auto`)
* ``pytest-sugar`` (makes pytest output a bit nicer)

It is recommended to install the required system packages via the system package manager (``apt``, ``yum``, ``pacman``, etc.) and then install the required Python packages as user packages via ``pip`` (or ``pip3``, depending on distribution).

Running tests
=============

Once the packages are installed, you should be able to run the tests.  There are several ways to do this.

First, all tests can be run by runing ``tox`` in the repo root.  In this case, tox will set up a python virtual environment and install all python dependencies inside the virtual environment.  Additionally, tox will run pytest as ``pytest -n auto`` so it will run tests in parallel on multiple CPUs. ::

    $ cd /path/to/corundum/
    $ tox
    py3 create: /home/alex/Projects/corundum/.tox/py3
    py3 installdeps: pytest == 6.2.5, pytest-xdist == 2.4.0, pytest-split == 0.4.0, cocotb == 1.6.1, cocotb-test == 0.2.1, cocotbext-axi == 0.1.18, cocotbext-eth == 0.1.18, cocotbext-pcie == 0.1.20, scapy == 2.4.5
    py3 installed: attrs==21.4.0,cocotb==1.6.1,cocotb-bus==0.2.1,cocotb-test==0.2.1,cocotbext-axi==0.1.18,cocotbext-eth==0.1.18,cocotbext-pcie==0.1.20,execnet==1.9.0,iniconfig==1.1.1,packaging==21.3,pluggy==1.0.0,py==1.11.0,pyparsing==3.0.7,pytest==6.2.5,pytest-forked==1.4.0,pytest-split==0.4.0,pytest-xdist==2.4.0,scapy==2.4.5,toml==0.10.2
    py3 run-test-pre: PYTHONHASHSEED='4023917175'
    py3 run-test: commands[0] | pytest -n auto
    ============================= test session starts ==============================
    platform linux -- Python 3.9.7, pytest-6.2.5, py-1.11.0, pluggy-1.0.0
    cachedir: .tox/py3/.pytest_cache
    rootdir: /home/alex/Projects/corundum, configfile: tox.ini, testpaths: fpga, fpga/app
    plugins: forked-1.4.0, split-0.4.0, cocotb-test-0.2.1, xdist-2.4.0
    gw0 [69] / gw1 [69] / gw2 [69] / gw3 [69] / gw4 [69] / gw5 [69] / gw6 [69] / gw7 [69] / gw8 [69] / gw9 [69] / gw10 [69] / gw11 [69] / gw12 [69] / gw13 [69] / gw14 [69] / gw15 [69] / gw16 [69] / gw17 [69] / gw18 [69] / gw19 [69] / gw20 [69] / gw21 [69] / gw22 [69] / gw23 [69] / gw24 [69] / gw25 [69] / gw26 [69] / gw27 [69] / gw28 [69] / gw29 [69] / gw30 [69] / gw31 [69] / gw32 [69] / gw33 [69] / gw34 [69] / gw35 [69] / gw36 [69] / gw37 [69] / gw38 [69] / gw39 [69] / gw40 [69] / gw41 [69] / gw42 [69] / gw43 [69] / gw44 [69] / gw45 [69] / gw46 [69] / gw47 [69] / gw48 [69] / gw49 [69] / gw50 [69] / gw51 [69] / gw52 [69] / gw53 [69] / gw54 [69] / gw55 [69] / gw56 [69] / gw57 [69] / gw58 [69] / gw59 [69] / gw60 [69] / gw61 [69] / gw62 [69] / gw63 [69]
    .....................................................................    [100%]
    ======================= 69 passed in 1534.87s (0:25:34) ========================
    ___________________________________ summary ____________________________________
      py3: commands succeeded
      congratulations :)

Second, all tests can be run by running ``pytest`` in the repo root.  Running as ``pytest -n auto`` is recommended to run multiple tests in parallel on multiple CPUs. ::

    $ cd /path/to/corundum/
    $ pytest -n auto
    ============================= test session starts ==============================
    platform linux -- Python 3.9.7, pytest-6.2.5, py-1.10.0, pluggy-0.13.1
    rootdir: /home/alex/Projects/corundum, configfile: tox.ini, testpaths: fpga, fpga/app
    plugins: split-0.3.0, parallel-0.1.0, cocotb-test-0.2.0, forked-1.3.0, metadata-1.11.0, xdist-2.4.0, html-3.1.1, cov-2.12.1, flake8-1.0.7
    gw0 [69] / gw1 [69] / gw2 [69] / gw3 [69] / gw4 [69] / gw5 [69] / gw6 [69] / gw7 [69] / gw8 [69] / gw9 [69] / gw10 [69] / gw11 [69] / gw12 [69] / gw13 [69] / gw14 [69] / gw15 [69] / gw16 [69] / gw17 [69] / gw18 [69] / gw19 [69] / gw20 [69] / gw21 [69] / gw22 [69] / gw23 [69] / gw24 [69] / gw25 [69] / gw26 [69] / gw27 [69] / gw28 [69] / gw29 [69] / gw30 [69] / gw31 [69] / gw32 [69] / gw33 [69] / gw34 [69] / gw35 [69] / gw36 [69] / gw37 [69] / gw38 [69] / gw39 [69] / gw40 [69] / gw41 [69] / gw42 [69] / gw43 [69] / gw44 [69] / gw45 [69] / gw46 [69] / gw47 [69] / gw48 [69] / gw49 [69] / gw50 [69] / gw51 [69] / gw52 [69] / gw53 [69] / gw54 [69] / gw55 [69] / gw56 [69] / gw57 [69] / gw58 [69] / gw59 [69] / gw60 [69] / gw61 [69] / gw62 [69] / gw63 [69]
    .....................................................................    [100%]
    ======================= 69 passed in in 2032.42s (0:33:52) =====================

Third, groups of tests can be run by running ``pytest`` in a subdirectory.  Running as ``pytest -n auto`` is recommended to run multiple tests in parallel on multiple CPUs. ::

    $ cd /path/to/corundum/fpga/common/tb/rx_hash
    $ pytest -n 4
    ============================= test session starts ==============================
    platform linux -- Python 3.9.7, pytest-6.2.5, py-1.10.0, pluggy-0.13.1
    rootdir: /home/alex/Projects/corundum, configfile: tox.ini
    plugins: split-0.3.0, parallel-0.1.0, cocotb-test-0.2.0, forked-1.3.0, metadata-1.11.0, xdist-2.4.0, html-3.1.1, cov-2.12.1, flake8-1.0.7
    gw0 [2] / gw1 [2] / gw2 [2] / gw3 [2]
    ..                                                                       [100%]
    ============================== 2 passed in 37.49s ==============================

Finally, individual tests can be run by runing ``make``.  This method provides the capability of overriding parameters and enabling waveform dumps in FST format that are viewable in gtkwave. ::

    $ cd /path/to/corundum/fpga/common/tb/rx_hash
    $ make WAVES=1
    make -f Makefile results.xml
    make[1]: Entering directory '/home/alex/Projects/corundum/fpga/common/tb/rx_hash'
    echo 'module iverilog_dump();' > iverilog_dump.v
    echo 'initial begin' >> iverilog_dump.v
    echo '    $dumpfile("rx_hash.fst");' >> iverilog_dump.v
    echo '    $dumpvars(0, rx_hash);' >> iverilog_dump.v
    echo 'end' >> iverilog_dump.v
    echo 'endmodule' >> iverilog_dump.v
    /usr/bin/iverilog -o sim_build/sim.vvp -D COCOTB_SIM=1 -s rx_hash -P rx_hash.DATA_WIDTH=64 -P rx_hash.KEEP_WIDTH=8 -s iverilog_dump -f sim_build/cmds.f -g2012   ../../rtl/rx_hash.v iverilog_dump.v
    MODULE=test_rx_hash TESTCASE= TOPLEVEL=rx_hash TOPLEVEL_LANG=verilog \
             /usr/bin/vvp -M /home/alex/.local/lib/python3.9/site-packages/cocotb/libs -m libcocotbvpi_icarus   sim_build/sim.vvp -fst
         -.--ns INFO     cocotb.gpi                         ..mbed/gpi_embed.cpp:76   in set_program_name_in_venv        Did not detect Python virtual environment. Using system-wide Python interpreter
         -.--ns INFO     cocotb.gpi                         ../gpi/GpiCommon.cpp:99   in gpi_print_registered_impl       VPI registered
         0.00ns INFO     Running on Icarus Verilog version 11.0 (stable)
         0.00ns INFO     Running tests with cocotb v1.7.0.dev0 from /home/alex/.local/lib/python3.9/site-packages/cocotb
         0.00ns INFO     Seeding Python random module with 1643529566
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     Found test test_rx_hash.run_test
         0.00ns INFO     running run_test (1/8)
         0.00ns INFO     AXI stream source
         0.00ns INFO     cocotbext-axi version 0.1.19
         0.00ns INFO     Copyright (c) 2020 Alex Forencich
         0.00ns INFO     https://github.com/alexforencich/cocotbext-axi
         0.00ns INFO     AXI stream source configuration:
         0.00ns INFO       Byte size: 8 bits
         0.00ns INFO       Data width: 64 bits (8 bytes)
         0.00ns INFO     AXI stream source signals:
         0.00ns INFO       tdata width: 64 bits
         0.00ns INFO       tdest: not present
         0.00ns INFO       tid: not present
         0.00ns INFO       tkeep width: 8 bits
         0.00ns INFO       tlast width: 1 bits
         0.00ns INFO       tready: not present
         0.00ns INFO       tuser: not present
         0.00ns INFO       tvalid width: 1 bits
         0.00ns INFO     Reset de-asserted
         0.00ns INFO     Reset de-asserted
    FST info: dumpfile rx_hash.fst opened for output.
         4.00ns INFO     Reset asserted
         4.00ns INFO     Reset asserted
        12.00ns INFO     Reset de-asserted
        12.00ns INFO     Reset de-asserted
        20.00ns INFO     TX frame: AxiStreamFrame(tdata=bytearray(b'\xda\xd1\xd2\xd3\xd4\xd5ZQRSTU\x90\x00\x00'), tkeep=None, tid=None, tdest=None, tuser=None, sim_time_start=20000, sim_time_end=None)
        28.00ns INFO     TX frame: AxiStreamFrame(tdata=bytearray(b'\xda\xd1\xd2\xd3\xd4\xd5ZQRSTU\x90\x00\x00\x01'), tkeep=None, tid=None, tdest=None, tuser=None, sim_time_start=28000, sim_time_end=None)
        36.00ns INFO     TX frame: AxiStreamFrame(tdata=bytearray(b'\xda\xd1\xd2\xd3\xd4\xd5ZQRSTU\x90\x00\x00\x01\x02'), tkeep=None, tid=None, tdest=None, tuser=None, sim_time_start=36000, sim_time_end=None)
        40.00ns INFO     RX hash: 0x00000000 (expected: 0x00000000) type: HashType.0 (expected: HashType.0)
        48.00ns INFO     TX frame: AxiStreamFrame(tdata=bytearray(b'\xda\xd1\xd2\xd3\xd4\xd5ZQRSTU\x90\x00\x00\x01\x02\x03'), tkeep=None, tid=None, tdest=None, tuser=None, sim_time_start=48000, sim_time_end=None)
        48.00ns INFO     RX hash: 0x00000000 (expected: 0x00000000) type: HashType.0 (expected: HashType.0)
        56.00ns INFO     RX hash: 0x00000000 (expected: 0x00000000) type: HashType.0 (expected: HashType.0)


    ################    skip a very large number of lines    ################


    252652.01ns INFO     TX frame: AxiStreamFrame(tdata=bytearray(b'\xda\xd1\xd2\xd3\xd4\xd5ZQRSTU\x08\x00E\x00\x00V\x00\x8b\x00\x00@\x06d\xff\n\x01\x00\x8b\n\x02\x00\x8b\x00\x8b\x10\x8b\x00\x00\x00\x00\x00\x00\x00\x00P\x02 \x00ms\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f !"#$%&\'()*+,-'), tkeep=None, tid=None, tdest=None, tuser=None, sim_time_start=252652007, sim_time_end=None)
    252744.01ns INFO     RX hash: 0xa2a55ee3 (expected: 0xa2a55ee3) type: HashType.TCP|IPV4 (expected: HashType.TCP|IPV4)
    252860.01ns INFO     TX frame: AxiStreamFrame(tdata=bytearray(b'\xda\xd1\xd2\xd3\xd4\xd5ZQRSTU\x08\x00E\x00\x00V\x00\x8c\x00\x00@\x06d\xfc\n\x01\x00\x8c\n\x02\x00\x8c\x00\x8c\x10\x8c\x00\x00\x00\x00\x00\x00\x00\x00P\x02 \x00mo\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f !"#$%&\'()*+,-'), tkeep=None, tid=None, tdest=None, tuser=None, sim_time_start=252860007, sim_time_end=None)
    252952.01ns INFO     RX hash: 0x6308c813 (expected: 0x6308c813) type: HashType.TCP|IPV4 (expected: HashType.TCP|IPV4)
    252960.01ns INFO     run_test passed
    252960.01ns INFO     **************************************************************************************
                         ** TEST                          STATUS  SIM TIME (ns)  REAL TIME (s)  RATIO (ns/s) **
                         **************************************************************************************
                         ** test_rx_hash.run_test          PASS       11144.00           1.14       9781.95  **
                         ** test_rx_hash.run_test          PASS       44448.00           3.80      11688.88  **
                         ** test_rx_hash.run_test          PASS       12532.00           1.40       8943.27  **
                         ** test_rx_hash.run_test          PASS       49984.00           4.42      11302.44  **
                         ** test_rx_hash.run_test          PASS       13088.00           1.54       8479.38  **
                         ** test_rx_hash.run_test          PASS       52208.00           4.62      11308.18  **
                         ** test_rx_hash.run_test          PASS       13940.00           1.65       8461.27  **
                         ** test_rx_hash.run_test          PASS       55616.00           5.03      11046.45  **
                         **************************************************************************************
                         ** TESTS=8 PASS=8 FAIL=0 SKIP=0             252960.01          25.11      10073.76  **
                         **************************************************************************************
                         
    make[1]: Leaving directory '/home/alex/Projects/corundum/fpga/common/tb/rx_hash'

Setting up the FPGA build environment (Vivado)
==============================================

Building FPGA configurations for Xilinx devices requires `Vivado <https://www.xilinx.com/products/design-tools/vivado.html>`_.  Linux is the recommended operating system for a build environment due to the use of symlinks (which can cause problems on Windows) and makefiles for build automation.  Additionally, Vivado uses more CPU cores for building on Linux than on Windows.  It is not recommended to run Vivado inside of a virtual machine as Vivado uses a significant amount of RAM during the build process.  Download and install the appropriate version of Vivado.  Make sure to install device support for your target device; support for other devices can be disabled to save disk space.

Licenses may be required, depending on the target device.  A bare install of Vivado without any licenses runs in "WebPACK" mode and has limited device support.  If your target device is on the `WebPACK device list <https://www.xilinx.com/products/design-tools/vivado/vivado-webpack.html#architecture>`_, then no Vivado license is required.  Otherwise, you will need access to a Vivado license to build the design.

Additionally, the 100G MAC IP cores on UltraScale and UltraScale+ require separate licenses.  These licenses are free of charge, and can be generated for `UltraScale <https://www.xilinx.com/products/intellectual-property/cmac.html>`_ and `UltraScale+ <https://www.xilinx.com/products/intellectual-property/cmac_usplus.html>`_.  If your target design uses the 100G CMAC IP, then you will need one of these licenses to build the design.

For example: if you want to build a 100G design for an Alveo U50, you will not need a Vivado license as the U50 is supported under WebPACK, but you will need to generate a (free-of-charge) license for the CMAC IP for UltraScale+.

Before building a design with Vivado, you'll have to source the appropriate settings file.  For example::

    $ source /opt/Xilinx/Vivado/2020.2/settings64.sh
    $ make

Building the FPGA configuration
===============================

Each design contains a set of makefiles for automating the build process.  To use the makefile, simply source the settings file for the required toolchain and then run ``make``.  Note that the repository makes significant use of symbolic links, so it is highly recommended to build the design under Linux.

For example::

    $ cd /path/to/corundum/fpga/mqnic/[board]/fpga_[variant]/fpga
    $ source /opt/Xilinx/Vivado/2020.2/settings64.sh
    $ make

Building the driver
===================

To build the driver, you will first need to install the required compiler and kernel source code packages.  After these packages are installed, simply run ``make``. ::

    $ cd /path/to/corundum/modules/mqnic
    $ make

Note that the driver currently does not support RHEL, centos, and related distributions that use very old and significantly modified kernels where the reported kernel version number is not a reliable of the internal kernel API.

Building the userspace tools
============================

To build the driver, you will first need to install the required compiler packages.  After these packages are installed, simply run ``make``. ::

    $ cd /path/to/corundum/utils
    $ make

Setting up the PetaLinux build environment
==========================================

Building PetaLinux projects for Xilinx devices requires `PetaLinux Tools <https://www.xilinx.com/products/design-tools/embedded-software/petalinux-sdk.html>`_.  Linux is the recommended operating system for a build environment due to the use of symlinks (which can cause problems on Windows) and makefiles for build automation.  Download and install the appropriate version of PetaLinux Tools.  Make sure to install device support for your target device; support for other devices can be disabled to save disk space.

An example for a PetaLinux project in Corundum is accompanying the FPGA design using the Xilinx ZynqMP SoC as host system for mqnic on the Xilinx ZCU106 board.  See `fpga/mqnic/ZCU106/fpga_zynqmp/README.md`.

Before building a PetaLinux project, you'll have to source the appropriate settings file.  For example::

    $ source /opt/Xilinx/PetaLinux/2021.1/settings.sh
    $ make -C path/to/petalinux/project build-boot

Loading the FPGA design
=======================

There are three main ways for loading Corundum on to an FPGA board.  The first is via JTAG, into volatile FPGA configuration memory.  This is best for development and debugging, especially when complemented with a baseline design with the same PCIe interface configuration stored in flash.  The second is via indirect JTAG, into nonvolatile on-card flash memory.  This is quite slow.  The third is via PCI express, into nonvolatile on-card memory.  This is the fastest method of programming the flash, but it requires the board to already be running the Corundum design.

For a card that's not already running Corundum, there are two options for programming the flash.  The first is to use indirect JTAG, but this is very slow.  The second is to first load the design via JTAG into volatile configuration memory, then perform a warm reboot, and finally write the design into flash via PCIe with the ``mqnic-fw`` utility.  

Loading the design via JTAG into volatile configuration memory with Vivado is straightforward: install the card into a host computer, attach the JTAG cable, power up the host computer, and use Vivado to connect and load the bit file into the FPGA.  When using the makefile, run ``make program`` to program the device.  If physical access is a problem, it is possible to run a hardware server instance on the host computer and connect to the hardware server over the network.  Once the design is loaded into the FPGA, perform either a hot reset (via ``pcie_hot_reset.sh`` or ``mqnic-fw -t``, but only if the card was enumerated at boot and the PCIe configuration has not changed) or a warm reboot.

Loading the design via indirect JTAG into nonvolatile memory with Vivado requires basically the same steps as loading it into volatile configuration memory, the main difference is that the configuration flash image must first be generated by running ``make fpga.mcs`` after using make to generate the bit file.  Once this file is generated, connect with the hardware manager, add the configuration memory device (check the makefile for the part number), and program the flash.  After the programming operation is complete, boot the FPGA from the configuration memory, either via Vivado (right click -> boot from configuration memory) or by performing a cold reboot (full shut down, then power on).  When using the makefile, run ``make flash`` to generate the flash images, program the flash via indirect JTAG, and boot the FPGA from the configuration memory.  Finally, reboot the host computer to re-enumerate the PCIe bus.

Loading the design via PCI express is straightforward: use the ``mqnic-fw`` utility to load the bit file into flash, then trigger an FPGA reboot to load the new design.  This does not require the kernel module to be loaded.  With the kernel module loaded, point ``mqnic-fw`` either to ``/dev/mqnic<n>`` or to one of the associated network interfaces.  Without the kernel module loaded, point ``mqnic-fw`` either to the raw PCIe ID, or to ``/sys/bus/pci/devices/<pcie-id>/resource0``; check ``lspci`` for the PCIe ID.  Use ``-w`` to specify the bit file to load, then ``-b`` to command the FPGA to reset and reload its configuration from flash.  You can also use ``-t`` to trigger a hot reset to reset the design.

Query device information with ``mqnic-fw``, with no kernel module loaded::

    $ sudo ./mqnic-fw -d 81:00.0
    PCIe ID (device): 0000:81:00.0
    PCIe ID (upstream port): 0000:80:01.1
    FPGA ID: 0x04b77093
    FPGA part: XCU50
    FW ID: 0x00000000
    FW version: 0.0.1.0
    Board ID: 0x10ee9032
    Board version: 1.0.0.0
    Build date: 2022-01-05 08:33:23 UTC (raw 0x61d557d3)
    Git hash: ddd7e639
    Release info: 00000000
    Flash type: SPI
    Flash format: 0x00048100
    Data width: 4
    Manufacturer ID: 0x20
    Memory type: 0xbb
    Memory capacity: 0x21
    Flash size: 128 MB
    Write buffer size: 256 B
    Erase block size: 4096 B
    Flash segment 0: start 0x00000000 length 0x01002000
    Flash segment 1: start 0x01002000 length 0x06ffe000
    Selected: segment 1 start 0x01002000 length 0x06ffe000

Write design into nonvolatile flash memory with ``mqnic-fw``, with no kernel module loaded::

    $ sudo ./mqnic-fw -d 81:00.0 -w ../fpga/mqnic/AU50/fpga_100g/fpga/fpga.bit 
    PCIe ID (device): 0000:81:00.0
    PCIe ID (upstream port): 0000:80:01.1
    FPGA ID: 0x04b77093
    FPGA part: XCU50
    FW ID: 0x00000000
    FW version: 0.0.1.0
    Board ID: 0x10ee9032
    Board version: 1.0.0.0
    Build date: 2022-01-05 08:33:23 UTC (raw 0x61d557d3)
    Git hash: ddd7e639
    Release info: 00000000
    Flash type: SPI
    Flash format: 0x00048100
    Data width: 4
    Manufacturer ID: 0x20
    Memory type: 0xbb
    Memory capacity: 0x21
    Flash size: 128 MB
    Write buffer size: 256 B
    Erase block size: 4096 B
    Flash segment 0: start 0x00000000 length 0x01002000
    Flash segment 1: start 0x01002000 length 0x06ffe000
    Selected: segment 1 start 0x01002000 length 0x06ffe000
    Erasing flash...
    Start address: 0x01002000
    Length: 0x01913000
    Erase address 0x02910000, length 0x00005000 (99%)
    Writing flash...
    Start address: 0x01002000
    Length: 0x01913000
    Write address 0x02910000, length 0x00005000 (99%)
    Verifying flash...
    Start address: 0x01002000
    Length: 0x01913000
    Read address 0x02910000, length 0x00005000 (99%)
    Programming succeeded!

Reboot FPGA to load design from flash with ``mqnic-fw``, with no kernel module loaded::

    $ sudo ./mqnic-fw -d 81:00.0 -b
    PCIe ID (device): 0000:81:00.0
    PCIe ID (upstream port): 0000:80:01.1
    FPGA ID: 0x04b77093
    FPGA part: XCU50
    FW ID: 0x00000000
    FW version: 0.0.1.0
    Board ID: 0x10ee9032
    Board version: 1.0.0.0
    Build date: 2022-01-05 08:33:23 UTC (raw 0x61d557d3)
    Git hash: ddd7e639
    Release info: 00000000
    Flash type: SPI
    Flash format: 0x00048100
    Data width: 4
    Manufacturer ID: 0x20
    Memory type: 0xbb
    Memory capacity: 0x21
    Flash size: 128 MB
    Write buffer size: 256 B
    Erase block size: 4096 B
    Flash segment 0: start 0x00000000 length 0x01002000
    Flash segment 1: start 0x01002000 length 0x06ffe000
    Selected: segment 1 start 0x01002000 length 0x06ffe000
    Preparing to reset device...
    Disabling PCIe fatal error reporting on port...
    No driver bound
    Triggering IPROG to reload FPGA...
    Removing device...
    Performing hot reset on upstream port...
    Rescanning on upstream port...
    Success, device is online!

Loading the kernel module
=========================

Once the kernel module is built, load it with ``insmod``::

    $ sudo insmod mqnic.ko

When the driver loads, it will print some debug information::

    [ 1502.394486] mqnic 0000:81:00.0: mqnic PCI probe
    [ 1502.394494] mqnic 0000:81:00.0:  Vendor: 0x1234
    [ 1502.394496] mqnic 0000:81:00.0:  Device: 0x1001
    [ 1502.394498] mqnic 0000:81:00.0:  Subsystem vendor: 0x10ee
    [ 1502.394500] mqnic 0000:81:00.0:  Subsystem device: 0x9032
    [ 1502.394501] mqnic 0000:81:00.0:  Class: 0x020000
    [ 1502.394504] mqnic 0000:81:00.0:  PCI ID: 0000:81:00.0
    [ 1502.394511] mqnic 0000:81:00.0:  Max payload size: 512 bytes
    [ 1502.394513] mqnic 0000:81:00.0:  Max read request size: 512 bytes
    [ 1502.394515] mqnic 0000:81:00.0:  Link capability: gen 3 x16
    [ 1502.394516] mqnic 0000:81:00.0:  Link status: gen 3 x16
    [ 1502.394518] mqnic 0000:81:00.0:  Relaxed ordering: enabled
    [ 1502.394520] mqnic 0000:81:00.0:  Phantom functions: disabled
    [ 1502.394521] mqnic 0000:81:00.0:  Extended tags: enabled
    [ 1502.394522] mqnic 0000:81:00.0:  No snoop: enabled
    [ 1502.394523] mqnic 0000:81:00.0:  NUMA node: 1
    [ 1502.394531] mqnic 0000:81:00.0: 126.016 Gb/s available PCIe bandwidth (8.0 GT/s PCIe x16 link)
    [ 1502.394554] mqnic 0000:81:00.0: enabling device (0000 -> 0002)
    [ 1502.394587] mqnic 0000:81:00.0: Control BAR size: 16777216
    [ 1502.396014] mqnic 0000:81:00.0: Device-level register blocks:
    [ 1502.396016] mqnic 0000:81:00.0:  type 0xffffffff (v 0.0.1.0)
    [ 1502.396019] mqnic 0000:81:00.0:  type 0x0000c000 (v 0.0.1.0)
    [ 1502.396021] mqnic 0000:81:00.0:  type 0x0000c004 (v 0.0.1.0)
    [ 1502.396023] mqnic 0000:81:00.0:  type 0x0000c080 (v 0.0.1.0)
    [ 1502.396025] mqnic 0000:81:00.0:  type 0x0000c120 (v 0.0.1.0)
    [ 1502.396027] mqnic 0000:81:00.0:  type 0x0000c140 (v 0.0.1.0)
    [ 1502.396029] mqnic 0000:81:00.0:  type 0x0000c150 (v 0.0.1.0)
    [ 1502.396038] mqnic 0000:81:00.0: FPGA ID: 0x04b77093
    [ 1502.396040] mqnic 0000:81:00.0: FW ID: 0x00000000
    [ 1502.396041] mqnic 0000:81:00.0: FW version: 0.0.1.0
    [ 1502.396043] mqnic 0000:81:00.0: Board ID: 0x10ee9032
    [ 1502.396044] mqnic 0000:81:00.0: Board version: 1.0.0.0
    [ 1502.396046] mqnic 0000:81:00.0: Build date: 2022-03-03 07:39:57 UTC (raw: 0x622070cd)
    [ 1502.396049] mqnic 0000:81:00.0: Git hash: 8851b3b1
    [ 1502.396051] mqnic 0000:81:00.0: Release info: 00000000
    [ 1502.396056] mqnic 0000:81:00.0: IF offset: 0x00000000
    [ 1502.396057] mqnic 0000:81:00.0: IF count: 1
    [ 1502.396059] mqnic 0000:81:00.0: IF stride: 0x01000000
    [ 1502.396060] mqnic 0000:81:00.0: IF CSR offset: 0x00080000
    [ 1502.396065] mqnic 0000:81:00.0: Resetting Alveo CMS
    [ 1502.613317] mqnic 0000:81:00.0: Read 4 MACs from Alveo BMC
    [ 1502.624743] mqnic 0000:81:00.0: registered PHC (index 5)
    [ 1502.624748] mqnic 0000:81:00.0: Creating interface 0
    [ 1502.624798] mqnic 0000:81:00.0: Interface-level register blocks:
    [ 1502.624799] mqnic 0000:81:00.0:  type 0x0000c001 (v 0.0.2.0)
    [ 1502.624801] mqnic 0000:81:00.0:  type 0x0000c010 (v 0.0.1.0)
    [ 1502.624803] mqnic 0000:81:00.0:  type 0x0000c020 (v 0.0.1.0)
    [ 1502.624804] mqnic 0000:81:00.0:  type 0x0000c030 (v 0.0.1.0)
    [ 1502.624805] mqnic 0000:81:00.0:  type 0x0000c021 (v 0.0.1.0)
    [ 1502.624806] mqnic 0000:81:00.0:  type 0x0000c031 (v 0.0.1.0)
    [ 1502.624807] mqnic 0000:81:00.0:  type 0x0000c003 (v 0.0.1.0)
    [ 1502.624811] mqnic 0000:81:00.0: IF features: 0x00000711
    [ 1502.624812] mqnic 0000:81:00.0: Max TX MTU: 9214
    [ 1502.624813] mqnic 0000:81:00.0: Max RX MTU: 9214
    [ 1502.624816] mqnic 0000:81:00.0: Event queue offset: 0x00100000
    [ 1502.624817] mqnic 0000:81:00.0: Event queue count: 32
    [ 1502.624818] mqnic 0000:81:00.0: Event queue stride: 0x00000020
    [ 1502.624822] mqnic 0000:81:00.0: TX queue offset: 0x00200000
    [ 1502.624823] mqnic 0000:81:00.0: TX queue count: 8192
    [ 1502.624824] mqnic 0000:81:00.0: TX queue stride: 0x00000020
    [ 1502.624827] mqnic 0000:81:00.0: TX completion queue offset: 0x00400000
    [ 1502.624828] mqnic 0000:81:00.0: TX completion queue count: 8192
    [ 1502.624829] mqnic 0000:81:00.0: TX completion queue stride: 0x00000020
    [ 1502.624832] mqnic 0000:81:00.0: RX queue offset: 0x00600000
    [ 1502.624833] mqnic 0000:81:00.0: RX queue count: 256
    [ 1502.624834] mqnic 0000:81:00.0: RX queue stride: 0x00000020
    [ 1502.624838] mqnic 0000:81:00.0: RX completion queue offset: 0x00700000
    [ 1502.624838] mqnic 0000:81:00.0: RX completion queue count: 256
    [ 1502.624839] mqnic 0000:81:00.0: RX completion queue stride: 0x00000020
    [ 1502.624841] mqnic 0000:81:00.0: Max desc block size: 8
    [ 1502.632850] mqnic 0000:81:00.0: Port-level register blocks:
    [ 1502.632855] mqnic 0000:81:00.0:  type 0x0000c040 (v 0.0.1.0)
    [ 1502.632860] mqnic 0000:81:00.0: Scheduler type: 0x0000c040
    [ 1502.632861] mqnic 0000:81:00.0: Scheduler offset: 0x00800000
    [ 1502.632862] mqnic 0000:81:00.0: Scheduler channel count: 8192
    [ 1502.632863] mqnic 0000:81:00.0: Scheduler channel stride: 0x00000004
    [ 1502.632864] mqnic 0000:81:00.0: Scheduler count: 1
    [ 1502.632866] mqnic 0000:81:00.0: Port count: 1
    [ 1503.217179] mqnic 0000:81:00.0: Registered device mqnic0

The driver will attempt to read MAC addresses from the card.  If it fails, it will fall back on random MAC addresses.  On some cards, the MAC addresses are fixed and cannot be changed, on other cards they are written to use-accessible EEPROM and as such can be changed.  Some cards with EEPROM come with blank EEPROMs, so if you want a persistent MAC address, you'll have to write a base MAC address into the EEPROM.  And finally, some cards do not have an EEPROM for storing MAC addresses, and persistent MAC addresses are not currently supported on these cards.

Testing the design
==================

To test the design, connect it to another NIC, either directly with a DAC cable or similar, or via a switch.

Before performing any testing, an IP address must be assigned through the Linux kernel.  There are various ways to do this, depending on the distribution in question.  For example, using ``iproute2``::

    $ sudo ip link set dev enp129s0 up
    $ sudo ip addr add 10.0.0.2/24 dev enp129s0

You can also change the MTU setting::

    $ sudo ip link set mtu 9000 dev enp129s0

Note that NetworkManager can fight over the network interface configuration (depending on the linux distribution).  If the IP address disappears from the interface, then this is likely the fault of NetworkManager as it attempts to dynamically configure the interface.  One solution for this is simply to use NetworkManager to configure the interface instead of iproute2.  Another is to statically configure the interface using configuration files in ``/etc/network/interfaces`` so that NetworkManager will leave it alone.

One the card is configured, using ``ping`` is a good first test::

    $ ping 10.0.0.1
    PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
    64 bytes from 10.0.0.1: icmp_seq=1 ttl=64 time=0.221 ms
    64 bytes from 10.0.0.1: icmp_seq=2 ttl=64 time=0.109 ms
    ^C
    --- 10.0.0.1 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1052ms
    rtt min/avg/max/mdev = 0.109/0.165/0.221/0.056 ms

If ``ping`` works, then try ``iperf``.

On the server::

    $ iperf3 -s
    -----------------------------------------------------------
    Server listening on 5201
    -----------------------------------------------------------
    Accepted connection from 10.0.0.2, port 54316
    [  5] local 10.0.0.1 port 5201 connected to 10.0.0.2 port 54318
    [ ID] Interval           Transfer     Bitrate
    [  5]   0.00-1.00   sec  2.74 GBytes  23.6 Gbits/sec                  
    [  5]   1.00-2.00   sec  2.85 GBytes  24.5 Gbits/sec                  
    [  5]   2.00-3.00   sec  2.82 GBytes  24.2 Gbits/sec                  
    [  5]   3.00-4.00   sec  2.83 GBytes  24.3 Gbits/sec                  
    [  5]   4.00-5.00   sec  2.82 GBytes  24.2 Gbits/sec                  
    [  5]   5.00-6.00   sec  2.76 GBytes  23.7 Gbits/sec                  
    [  5]   6.00-7.00   sec  2.63 GBytes  22.6 Gbits/sec                  
    [  5]   7.00-8.00   sec  2.81 GBytes  24.2 Gbits/sec                  
    [  5]   8.00-9.00   sec  2.73 GBytes  23.5 Gbits/sec                  
    [  5]   9.00-10.00  sec  2.73 GBytes  23.4 Gbits/sec                  
    [  5]  10.00-10.00  sec   384 KBytes  7.45 Gbits/sec                  
    - - - - - - - - - - - - - - - - - - - - - - - - -
    [ ID] Interval           Transfer     Bitrate
    [  5]   0.00-10.00  sec  27.7 GBytes  23.8 Gbits/sec                  receiver
    -----------------------------------------------------------
    Server listening on 5201
    -----------------------------------------------------------

On the client::

    $ iperf3 -c 10.0.0.1
    Connecting to host 10.0.0.1, port 5201
    [  5] local 10.0.0.2 port 54318 connected to 10.0.0.1 port 5201
    [ ID] Interval           Transfer     Bitrate         Retr  Cwnd
    [  5]   0.00-1.00   sec  2.74 GBytes  23.6 Gbits/sec    0   2.18 MBytes       
    [  5]   1.00-2.00   sec  2.85 GBytes  24.5 Gbits/sec    0   2.18 MBytes       
    [  5]   2.00-3.00   sec  2.82 GBytes  24.2 Gbits/sec    0   2.29 MBytes       
    [  5]   3.00-4.00   sec  2.83 GBytes  24.3 Gbits/sec    0   2.40 MBytes       
    [  5]   4.00-5.00   sec  2.82 GBytes  24.2 Gbits/sec    0   2.40 MBytes       
    [  5]   5.00-6.00   sec  2.76 GBytes  23.7 Gbits/sec    0   2.65 MBytes       
    [  5]   6.00-7.00   sec  2.63 GBytes  22.6 Gbits/sec    0   2.65 MBytes       
    [  5]   7.00-8.00   sec  2.81 GBytes  24.2 Gbits/sec    0   2.65 MBytes       
    [  5]   8.00-9.00   sec  2.73 GBytes  23.5 Gbits/sec    0   2.65 MBytes       
    [  5]   9.00-10.00  sec  2.73 GBytes  23.4 Gbits/sec    0   2.65 MBytes       
    - - - - - - - - - - - - - - - - - - - - - - - - -
    [ ID] Interval           Transfer     Bitrate         Retr
    [  5]   0.00-10.00  sec  27.7 GBytes  23.8 Gbits/sec    0             sender
    [  5]   0.00-10.00  sec  27.7 GBytes  23.8 Gbits/sec                  receiver

    iperf Done.

Finally, test the PTP synchronization performance with ``ptp4l`` from ``linuxptp``.

On the server::

    $ sudo ptp4l -i enp193s0np0 --masterOnly=1 -m --logSyncInterval=-3
    ptp4l[4463.798]: selected /dev/ptp2 as PTP clock
    ptp4l[4463.799]: port 1: INITIALIZING to LISTENING on INIT_COMPLETE
    ptp4l[4463.799]: port 0: INITIALIZING to LISTENING on INIT_COMPLETE
    ptp4l[4471.745]: port 1: LISTENING to MASTER on ANNOUNCE_RECEIPT_TIMEOUT_EXPIRES
    ptp4l[4471.746]: selected local clock ec0d9a.fffe.6821d4 as best master
    ptp4l[4471.746]: port 1: assuming the grand master role

On the client::

    $ sudo ptp4l -i enp129s0 --slaveOnly=1 -m
    ptp4l[642.961]: selected /dev/ptp5 as PTP clock
    ptp4l[642.962]: port 1: INITIALIZING to LISTENING on INIT_COMPLETE
    ptp4l[642.962]: port 0: INITIALIZING to LISTENING on INIT_COMPLETE
    ptp4l[643.477]: port 1: new foreign master ec0d9a.fffe.6821d4-1
    ptp4l[647.478]: selected best master clock ec0d9a.fffe.6821d4
    ptp4l[647.478]: port 1: LISTENING to UNCALIBRATED on RS_SLAVE
    ptp4l[648.233]: port 1: UNCALIBRATED to SLAVE on MASTER_CLOCK_SELECTED
    ptp4l[648.859]: rms 973559315 max 1947121298 freq -41295 +/- 15728 delay   643 +/-   0
    ptp4l[649.860]: rms  698 max 1236 freq -44457 +/- 949 delay   398 +/-   0
    ptp4l[650.861]: rms 1283 max 1504 freq -42099 +/- 257 delay   168 +/-   0
    ptp4l[651.862]: rms  612 max  874 freq -42059 +/-  85 delay   189 +/-   1
    ptp4l[652.863]: rms  127 max  245 freq -42403 +/-  85
    ptp4l[653.865]: rms   58 max   81 freq -42612 +/-  36 delay   188 +/-   0
    ptp4l[654.866]: rms   21 max   36 freq -42603 +/-  12 delay   181 +/-   0
    ptp4l[655.867]: rms    6 max   12 freq -42584 +/-   7 delay   174 +/-   1
    ptp4l[656.868]: rms   14 max   26 freq -42606 +/-  12
    ptp4l[657.869]: rms   19 max   23 freq -42631 +/-  11 delay   173 +/-   0
    ptp4l[658.870]: rms   24 max   35 freq -42660 +/-  12 delay   173 +/-   0
    ptp4l[659.870]: rms   23 max   35 freq -42679 +/-  16 delay   173 +/-   0
    ptp4l[660.872]: rms   18 max   20 freq -42696 +/-   5 delay   170 +/-   0
    ptp4l[661.873]: rms   18 max   30 freq -42714 +/-   8 delay   167 +/-   1
    ptp4l[662.874]: rms   26 max   36 freq -42747 +/-  10 delay   168 +/-   0
    ptp4l[663.875]: rms   18 max   21 freq -42757 +/-  10 delay   167 +/-   0
    ptp4l[664.876]: rms   14 max   17 freq -42767 +/-   8 delay   167 +/-   1
    ptp4l[665.877]: rms    9 max   12 freq -42741 +/-   7 delay   168 +/-   2

In this case, ``ptp4l`` has converged to an offset of well under 100 ns, reporting a frequency difference of about -43 ppm.

While ``ptp4l`` is syncing the clock, the kernel module will print some debug information::

    [  642.943481] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 0
    [  642.943487] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x400000000
    [  647.860040] mqnic 0000:81:00.0: mqnic_start_xmit TX TS requested
    [  647.860084] mqnic 0000:81:00.0: mqnic_process_tx_cq TX TS requested
    [  648.090566] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2795012
    [  648.090572] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000b2e18
    [  648.090575] mqnic 0000:81:00.0: mqnic_phc_adjtime delta: -1947115961
    [  648.215705] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 3241067
    [  648.215711] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000cf6da
    [  648.340845] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 3199401
    [  648.340851] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000ccc30
    [  648.465995] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 3161092
    [  648.466001] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000ca4f5
    [  648.591129] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 3121946
    [  648.591135] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000c7cdf
    [  648.716275] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 3082853
    [  648.716281] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000c54d7
    [  648.841425] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 3048881
    [  648.841431] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000c320e
    [  648.966550] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 3012985
    [  648.966556] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000c0d4c
    [  649.091601] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2980479
    [  649.091607] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000bec03
    [  649.216740] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2950457
    [  649.216746] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000bcd45
    [  649.341844] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2922995
    [  649.341850] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000bb126
    [  649.466966] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2897658
    [  649.466972] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000b9734
    [  649.592007] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2875145
    [  649.592013] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000b8026
    [  649.717159] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2854962
    [  649.717165] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000b6b7b
    [  649.776717] mqnic 0000:81:00.0: mqnic_start_xmit TX TS requested
    [  649.776761] mqnic 0000:81:00.0: mqnic_process_tx_cq TX TS requested
    [  649.842186] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2813737
    [  649.842191] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000b4144
    [  649.967434] mqnic 0000:81:00.0: mqnic_phc_adjfine scaled_ppm: 2800052
    [  649.967440] mqnic 0000:81:00.0: mqnic_phc_adjfine adj: 0x4000b3341

In this case, the core clock frequency is slightly less than 250 MHz.  You can compute the clock frequency in GHz like so::

    >>> 2**32/0x4000b3341
    0.24998931910318553
