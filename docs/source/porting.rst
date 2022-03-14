.. _porting:

=======
Porting
=======

This guide is a high-level overview for how to port Corundum to new hardware.  In general, this guide only applies to FPGA families that are already supported by Corundum, new FPGA families can require significant interfacing changes, especially for the PCI express interface as this can vary significantly between different FPGA families.

The only interfaces that the Corundum datapath requires are the PCI express interface and the Ethernet interfaces.  Ancillary features such as firmware updates, persistent MAC addresses, and optical module communication are optional---the core datapath will still function if these features are not implemented.  In general the PCI express and Ethernet interfaces are dependent almost completely on the FPGA family, while ancillary features tend to be much more board-dependent.

Preparation
===========

Before porting Corundum to a new board, it is recommended to create example designs for both verilog-ethernet and verilog-pcie for the target board.  The verilog-ethernet design will bring up the Ethernet interfaces at 10 Gbps and ensures the transceivers, reference clocks, and module control pins are properly configured for the Ethernet interfaces to operate.  Some boards may require additional code to configure clocking logic to supply the proper reference clocks to the transceivers on the FPGA, which will generally be one of 156.25 MHz, 161.1328125 MHz, 322.265625 MHz, or 644.53125 MHz.  The verilog-pcie design brings up the PCI express interface, validating that all of the pin assignments and transceiver site locations are correct.  Once both of these designs are working, then porting corundum is straightforward.

Porting Corundum
================

Start by making a copy of a Corundum design that targets a similar board.  Priority goes to a chip in the same family, then similar ancillary interfaces.

Board ID
--------

Each board should have a unique board ID specified in ``mqnic_hw.h``.  These IDs are used by the driver for any board-specific initialization and interfacing.  These IDs are arbitrary, but making something relatively predictable is a good idea to reduce the possibility of collisions.  Most of the current IDs are a combination of the PCIe vendor ID of the board manufacturer, combined with a board-specific portion.  For example, the board IDs for ExaNICs are simply the original ExaNIC PCIe VID and PID, and the Xilinx board IDs are a combination of the Xilinx PCIe VID, the part series (7 for 7 series, 8 for UltraScale, 9 for UltraScale+, etc.) and the hex version of the board part number (VCU108 = 6c, VCU1525 = 5f5, etc.).  Pick a board ID, add it to ``mqnic_hw.h``, and set the ``BOARD_ID`` parameter in fpga_core.v.

FPGA ID
-------

The FPGA ID is used by the firmware update tool as a simple sanity check to prevent firmware for a different board from being loaded accidentally.  Set the FPGA_ID parameter in fpga_core.v to the JTAG ID of the FPGA on the board.  The IDs are located in ``fpga_id.h``/``fpga_id.c``.  If you do not want to implement the firmware update feature, ``FPGA_ID`` can be set to 0.

PCIe interface
--------------

Ensure that the PCIe hard IP core settings are correct for the target board.  In many cases, the default settings are correct, but in some cases the transceiver sites need to be changed.  Edit the TCL file appropriately, or generate the IP in vivado and extract the TCL commands from the Vivado journal file.  If you previously ported the verilog-pcie design, then the settings can be copied over, with the PCIe IDs, BARs, and MSI settings configured appropriately.

Check that the ``BAR0_APERTURE`` setting and PCIE_AXIS settings in ``fpga.v`` and ``fpga_core.v`` match the PCIe core configuration.

Ethernet interfaces
-------------------

For 100G interfaces, use Xilinx CMAC instances.  A free license can be generated on the Xilinx website.  The cores must be configured for CAUI-4.  Select the appropriate reference clock and transceiver sites for the interfaces on the board.  It may be necessary to adjust the CMAC site selections depending on which transceiver sites are used.  Implement the design, open the implemented design, check the relative positions of the transceiver sites and CMAC sites, and adjust as appropriate.  You can actually look at any synthesized or implemented design for the same chip to look at the relative positions of the sites.

For 10G or 25G interfaces, you can either use the MAC modules from verilog-ethernet or Xilinx-provided MAC modules.  For the included MACs, the main thing to adjust is the gtwizard instance.  This needs to be set up to use the correct transceiver sites and reference clock inputs.  The internal interface must be the 64 bit asynchronous gearbox.  Check the connection ordering; the gtwizard instance is always in the order of the site names, but this may not match the board, and connections may need to be re-ordered to match.  In particular, double check that the RX clocks are connected correctly.

Update the interfaces between ``fpga.v`` and ``fpga_core.v`` to match the module configuration.  Update the code in ``fpga_core.v`` to connect the PHYs in ``fpga.v`` to the appropriate MACs in ``fpga_core.v``.  Also set ``IF_COUNT`` and ``PORTS_PER_IF`` appropriately in ``fpga_core.v``.

I2C interfaces
--------------

MAC address EEPROMs and optical modules are accessed via I2C.  This is highly board-dependent.  On some boards, there is a single I2C interface and a number of I2C multiplexers to connect everything.  On other boards, each optical module has a dedicated I2C interface.  On other boards, the I2C bus sits behind a board management controller.  The core datapath will work fine without setting up I2C, but having the I2C buses operational can be a useful debugging feature.  If I2C access is not required, simply do not implement the registers and ensure that the selected board ID does not correspond to any I2C init code in ``mqnic_i2c.c``.

All corundum designs that directly connect I2C interfaces to the FPGA pins make use of bit-bang I2C support in the Linux kernel.  There are a set of registers set aside for controlling up to four I2C buses in ``mqnic_hw.h``.  These should be appropriately implemented in the NIC CSR register space in ``fpga_core.v``.  Driver code also needs to be added to ``mqnic_i2c.c`` to initialize everything appropriately based on the board ID.

Flash access
------------

Firmware updates require access to the FPGA configuration flash.  Depending on the flash type, this either requires connections to dedicated pins via specific device primitives, normal FPGA IO pins, or both.  The flash interface is a very simple bit-bang interface that simply exposes these pins over PCIe via NIC CSR register space.  The register definitions are in ``mqnic_hw.h``.  Take a look at existing designs that implement QSPI or BPI flash and implement the same register configuration in ``fpga_core.v``.  If firmware update support is not required, simply do not implement the flash register block.

Module control pins
-------------------

Optical modules have several low-speed control pins in addition to the I2C interface.  For DAC cables, these pins have no effect, but for AOC cables or optical modules, these pins are very important.  Specifically, SFP+ and SFP28 modules need to have the correct level on ``tx_disable`` in order to turn the laser on.  Similarly, QSFP+ and QSFP28 modules need to have the ``reset`` and ``lpmode`` pins set correctly.  These pins can be statically tied off with the modules enabled, or they can be exposed to the driver via standard registers specified in ``mqnic_hw.h`` and implemented in the NIC CSRs in ``fpga_core.v``.