// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

struct mqnic_port *mqnic_create_port(struct mqnic_if *interface, int index,
		struct mqnic_reg_block *port_rb)
{
	struct device *dev = interface->dev;
	struct mqnic_port *port;
	struct mqnic_reg_block *rb;
	u32 offset;
	int ret = 0;

	port = kzalloc(sizeof(*port), GFP_KERNEL);
	if (!port)
		return ERR_PTR(-ENOMEM);

	port->dev = dev;
	port->interface = interface;

	port->index = index;

	port->port_rb = port_rb;

	offset = ioread32(port_rb->regs + MQNIC_RB_SCHED_BLOCK_REG_OFFSET);

	port->rb_list = mqnic_enumerate_reg_block_list(interface->hw_addr, offset, interface->hw_regs_size - offset);

	if (!port->rb_list) {
		ret = -EIO;
		dev_err(dev, "Failed to enumerate blocks");
		goto fail;
	}

	dev_info(dev, "Port-level register blocks:");
	for (rb = port->rb_list; rb->regs; rb++)
		dev_info(dev, " type 0x%08x (v %d.%d.%d.%d)", rb->type, rb->version >> 24,
				(rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

	port->port_ctrl_rb = mqnic_find_reg_block(port->rb_list, MQNIC_RB_PORT_CTRL_TYPE, MQNIC_RB_PORT_CTRL_VER, 0);

	if (!port->port_ctrl_rb) {
		ret = -EIO;
		dev_err(dev, "Port control register block not found");
		goto fail;
	}

	port->port_features = ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_FEATURES);

	dev_info(dev, "Port features: 0x%08x", port->port_features);

	dev_info(dev, "Port TX status: 0x%08x", mqnic_port_get_tx_status(port));
	dev_info(dev, "Port RX status: 0x%08x", mqnic_port_get_rx_status(port));

	return port;

fail:
	mqnic_destroy_port(port);
	return ERR_PTR(ret);
}

void mqnic_destroy_port(struct mqnic_port *port)
{
	if (port->rb_list)
		mqnic_free_reg_block_list(port->rb_list);

	kfree(port);
}

u32 mqnic_port_get_tx_status(struct mqnic_port *port)
{
	return ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_TX_STATUS);
}
EXPORT_SYMBOL(mqnic_port_get_tx_status);

u32 mqnic_port_get_rx_status(struct mqnic_port *port)
{
	return ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_RX_STATUS);
}
EXPORT_SYMBOL(mqnic_port_get_rx_status);
