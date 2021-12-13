// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2019-2021, The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of The Regents of the
 * University of California.
 */

#include "mqnic.h"

int mqnic_create_port(struct mqnic_if *interface, struct mqnic_port **port_ptr,
		int index, u8 __iomem *hw_addr)
{
	struct device *dev = interface->dev;
	struct mqnic_port *port;

	port = kzalloc(sizeof(*port), GFP_KERNEL);
	if (!port)
		return -ENOMEM;

	*port_ptr = port;

	port->dev = dev;
	port->interface = interface;

	port->index = index;

	port->tx_queue_count = interface->tx_queue_count;

	port->hw_addr = hw_addr;

	// read ID registers
	port->port_id = ioread32(port->hw_addr + MQNIC_PORT_REG_PORT_ID);
	dev_info(dev, "Port ID: 0x%08x", port->port_id);
	port->port_features = ioread32(port->hw_addr + MQNIC_PORT_REG_PORT_FEATURES);
	dev_info(dev, "Port features: 0x%08x", port->port_features);
	port->port_mtu = ioread32(port->hw_addr + MQNIC_PORT_REG_PORT_MTU);
	dev_info(dev, "Port MTU: %d", port->port_mtu);

	port->sched_count = ioread32(port->hw_addr + MQNIC_PORT_REG_SCHED_COUNT);
	dev_info(dev, "Scheduler count: %d", port->sched_count);
	port->sched_offset = ioread32(port->hw_addr + MQNIC_PORT_REG_SCHED_OFFSET);
	dev_info(dev, "Scheduler offset: 0x%08x", port->sched_offset);
	port->sched_stride = ioread32(port->hw_addr + MQNIC_PORT_REG_SCHED_STRIDE);
	dev_info(dev, "Scheduler stride: 0x%08x", port->sched_stride);
	port->sched_type = ioread32(port->hw_addr + MQNIC_PORT_REG_SCHED_TYPE);
	dev_info(dev, "Scheduler type: 0x%08x", port->sched_type);

	mqnic_deactivate_port(port);

	return 0;
}

void mqnic_destroy_port(struct mqnic_port **port_ptr)
{
	struct mqnic_port *port = *port_ptr;
	*port_ptr = NULL;

	mqnic_deactivate_port(port);

	kfree(port);
}

int mqnic_activate_port(struct mqnic_port *port)
{
	int k;

	// enable schedulers
	iowrite32(0xffffffff, port->hw_addr + MQNIC_PORT_REG_SCHED_ENABLE);

	// enable queues
	for (k = 0; k < port->tx_queue_count; k++)
		iowrite32(3, port->hw_addr + port->sched_offset + k * 4);

	return 0;
}

void mqnic_deactivate_port(struct mqnic_port *port)
{
	// disable schedulers
	iowrite32(0, port->hw_addr + MQNIC_PORT_REG_SCHED_ENABLE);
}

u32 mqnic_port_get_rss_mask(struct mqnic_port *port)
{
	return ioread32(port->hw_addr + MQNIC_PORT_REG_RSS_MASK);
}

void mqnic_port_set_rss_mask(struct mqnic_port *port, u32 rss_mask)
{
	iowrite32(rss_mask, port->hw_addr + MQNIC_PORT_REG_RSS_MASK);
}

u32 mqnic_port_get_tx_mtu(struct mqnic_port *port)
{
	return ioread32(port->hw_addr + MQNIC_PORT_REG_TX_MTU);
}

void mqnic_port_set_tx_mtu(struct mqnic_port *port, u32 mtu)
{
	iowrite32(mtu, port->hw_addr + MQNIC_PORT_REG_TX_MTU);
}

u32 mqnic_port_get_rx_mtu(struct mqnic_port *port)
{
	return ioread32(port->hw_addr + MQNIC_PORT_REG_RX_MTU);
}

void mqnic_port_set_rx_mtu(struct mqnic_port *port, u32 mtu)
{
	iowrite32(mtu, port->hw_addr + MQNIC_PORT_REG_RX_MTU);
}
