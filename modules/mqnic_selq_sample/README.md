# Overview

The module mqnic_selq_sample is a very simple example on how to use mqnic's
custom TX select queue capability.

# Build

The mqnic driver module needs to be built first, including its custom TX select
queue capability. Then this example can be built against it.

	make -C ../mqnic/
	make

# Usage

The mqnic driver module needs to be loaded before this example module.

	insmod ../mqnic/mqnic.ko mqnic selq_handler_enable=1

This example module is controlled solely via 2 module parameters, for example:

	insmod mqnic_selq_sample.ko ifname=eth4 queue=7

Loading the module like shown above makes the module attach a TX select queue
handler to network interface "eth4" and instructs this handler to direct all
traffic towards TX queue index 7.

A third module parameter called "usedata" (boolean) makes the handler use a
private data pointer, which simply points to the "queue" parameter - instead
of using the global variable for the "queue" parameter directly.

Unloading the module detaches the registered handler from the network interface.
