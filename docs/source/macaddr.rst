.. _macaddr:

========================
Persistent MAC Addresses
========================

When registering network interfaces with the operating system, the driver must provide a MAC address for each interface.  Ensuring that the configured MAC addresses are unique and consistent across driver reloads requires binding the addresses to the hardware in some way, usually through the use of some form of nonvolatile memory.  It is relatively common for FPGA boards to provide small I2C EEPROMs for storing this sort of information.  On other boards, the MAC address can be read out from the board management controller.  If the driver fails to read a valid MAC address, it will fall back to using a randomly-generated MAC address.  See the :ref:`device_list` for a summary of how persistent MAC addresses are implemented on each board.  Boards that have pre-programmed MAC addresses should work "out of the box".  However, boards that include blank EEPROMs need to have a MAC address written into the EEPROM for this functionality to work.  

Programming I2C EEPROM via kernel module
========================================

The driver registers all on-card I2C devices via the Linux I2C subsystem.  Therefore, the MAC address EEPROM appears in sysfs, and a MAC address can easily be written using ``dd``.  Note that accessing the EEPROM is a little bit different on each board.  

After loading the driver, the device can be accessed either directly (``/sys/bus/pci/devices/0000:xx:00.0/``) or from the corresponding network interface (``/sys/class/net/eth0/device/``) or miscdev (``/sys/class/misc/mqnic0/device/``).  See the table below for the sysfs paths for each board.  Note that the I2C  bus numbers will vary.  Also note that optical module I2C interfaces are registered as EEPROMs with I2C address 0x50, so ensure you have the correct EEPROM by dumping the contents with ``xxd`` or a hex editor before programming it. 

After determining the sysfs path and picking a MAC address, run a command similar to this one to program the MAC address into the EEPROM::

    echo 02 aa bb 00 00 00 | xxd -r -p - | dd bs=1 count=6 of=/sys/class/net/eth0/device/i2c-4/4-0074/channel-2/7-0054/eeprom

After reloading the driver, the interfaces should use the new MAC address::

    14: enp1s0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
        link/ether 02:aa:bb:00:00:00 brd ff:ff:ff:ff:ff:ff
    15: enp1s0d1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
        link/ether 02:aa:bb:00:00:01 brd ff:ff:ff:ff:ff:ff

============  ===================  ========================================
Manufacturer  Board                sysfs path :sup:`1`
============  ===================  ========================================
Alpha Data    ADM-PCIE-9V3         ``i2c-X/X-0050/eeprom`` :sup:`3`
Exablaze      ExaNIC X10 :sup:`2`  ``i2c-X/X-0050/eeprom`` :sup:`3`
Exablaze      ExaNIC X25 :sup:`2`  ``i2c-X/X-0050/eeprom`` :sup:`3`
Xilinx        VCU108               ``i2c-X/X-0075/channel-3/Y-0054/eeprom``
Xilinx        VCU118               ``i2c-X/X-0075/channel-3/Y-0054/eeprom``
Xilinx        VCU1525              ``i2c-X/X-0074/channel-2/Y-0054/eeprom``
Xilinx        ZCU106               ``i2c-X/X-0074/channel-0/Y-0054/eeprom``
============  ===================  ========================================

Notes:
* :sup:`1` X and Y are i2c bus numbers that will vary
* :sup:`2` Card should come pre-programmed with a base MAC address
* :sup:`3` Optical module I2C interfaces may appear exactly the same way; confirm correct EEPROM by reading the contents with ``xxd`` or a hex editor.
