.. _debugging:

=========
Debugging
=========

The server rebooted when configuring the FPGA
=============================================

This is a common problem caused by the server management subsystem (IPMI, iLO, iDRAC, or whatever your server manufacturer calls it).  It detects the PCIe device falling off the bus when the FPGA is reset, and does something in response.  In some machines it just complains bitterly by logging an event and turning on an angry red LED.  In other machines, it does that, and then immediately reboots the machine.  Highly annoying.  However, there is a simple solution for this that involves some poking around in PCIe configuration registers to disable PCIe fatal error reporting on the port that the device is connected to.  

Run the ``pcie_disable_fatal_err.sh`` script before you configure the FPGA.  Specify the PCIe device ID of the FPGA board as the argument (``xy:00.0``, as shown in ``lspci``).  You'll have to do a warm reboot after loading the configuration if the PCIe BAR configuration has changed.  This will most likely be the case when going from a stock flash image that brings up the PCIe link to Corundum, but not from Corundum to Corundum unless something was changed in the PCIe IP core configuration.  If the BAR configuration has not changed, then using the ``pcie_hot_reset.sh`` script to perform a hot reset of the device may be sufficient.  The firmware update utility ``mqnic-fw`` includes the same functionality as ``pcie_disable_fatal_err.sh`` and ``pcie_hot_reset.sh``, so if the card is running a Corundum design, then you can use ``mqnic-fw -t`` to disable fatal error reporting and reset the card before connecting to it via JTAG.

The link is down
================

Things to check, in no particular order:

- Try a hot reset of the card
- Try an unmodified "known good" design for your board, either corundum or verilog-ethernet
- Try using a direct attach copper cable to rule out issues with optical transceivers.
- Try a different link partner---try a NIC instead of a switch, or a different model NIC.
- txdisable/lpmode/reset pins---only applies if you're using optical transceivers or active optical cables.  If these pins are pulled the wrong way, the lasers in the transceiver will not turn on, and the link will not come up.  (No, I have never wasted an hour waiting for Vivado to do its thing after pulling lpmode the wrong way...on several different boards...)
- Optical module CDR settings---if you're trying to run a 25G or 100G optical transceiver or active optical cable at 10G or 40G, you may need to disable the module CDRs via I2C by writing 0x00 to MSA register 98 on I2C address 0x50 (CDR control).  (No, I have not wasted several days trying to figure out why the electrical loopback works fine at 10G, but the optical transceiver only works at 25G...)
- Check settings at link partner---some devices are better about figuring out the proper configuration than others and need to have the correct settings applied manually (e.g. Mellanox NICs are quite good, but most packet switches can be rather bad about this and may only look at the line rate reported in the transceiver EEPROM instead of what's actually going on on the link).  Also check to make sure the link partner doesn't have some sort of disagreement with the cable/transceiver - some devices, usually switches, are very picky about what the EEPROM says about who manufactured the cable.
- Check FEC settings---in general, 100G devices seem to require the use of RS-FEC, 10G and 25G usually run fine without FEC, but it may need to be manually disabled on the link partner.
- Serdes configuration---ensure the correct line rate, gearbox settings, etc. are correct.  Some boards also have p/n swapped (e.g. ExaNIC X10/X25), so check tx/rx invert settings.  (Yes, I managed to figure *that* one out after some head-scratching despite not having access to the schematic)
- Serdes site locations---make sure you're using the correct pins.
- Serdes reference clock configuration---make sure the reference clock matches the serdes configuration, and on some boards the reference clock needs to be configured in some way before use.

Ping and iperf don't work
=========================

Things to check, in no particular order:

- Check that the interface is up (``ip link set dev <interface> up``)
- Check that the interface has an IP address assigned (``ip addr``, ``ip -c a``, ``ip -c -br``, to check, ``ip addr add 192.168.1.1/24 dev <interface>`` to set)
- The corundum driver does not currently report the link status to the OS, so check for a link light (not all design variants implement this) and check the link partner for the link status (``ip link``, NO-CARRIER means the link is down at the PHY layer)
- Try hot resetting the card with the link partner connected (clear up possible RX DFE problem)
- Check tcpdump for inbound traffic on both ends of the link ``tcpdump -i <interface> -Q in`` to see what is actually traversing the link.  If the TX direction works but the RX direction does not, there is a high probability it is a transceiver DFE issue that may be fixable with a hot reset.
- Check with ``mqnic-dump`` to see if there is anything stuck in transmit queues, transmit or receive completion queues, or event queues.

The device loses its IP address
===============================

This is not a corundum issue, this is NetworkManager or a similar application causing trouble by attempting to run DHCP or similar on the interface.  There are basically four options here: disable NetworkManager, configure NetworkManager to ignore the interface, use NetworkManager to configure the interface and assign the IP address you want, or use network namespaces to isolate the interface from NetworkManager.  Unfortunately, if you have a board that doesn't support persistent MAC addresses, it may not be possible to configure NetworkManager to deal with the interface correctly.
