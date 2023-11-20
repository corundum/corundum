// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

struct mqnic_port *mqnic_create_port(struct mqnic_if *interface, int index,
		int phys_index, struct mqnic_reg_block *port_rb)
{
	struct device *dev = interface->dev;
	struct devlink *devlink = priv_to_devlink(interface->mdev);
	struct devlink_port_attrs attrs = {};
	struct mqnic_port *port;
	struct mqnic_reg_block *rb;
	u32 offset;
	int ret = 0;
	int k;

	port = kzalloc(sizeof(*port), GFP_KERNEL);
	if (!port)
		return ERR_PTR(-ENOMEM);

	attrs.flavour = DEVLINK_PORT_FLAVOUR_PHYSICAL;
	attrs.phys.port_number = phys_index;
	devlink_port_attrs_set(&port->dl_port, &attrs);

	ret = devlink_port_register(devlink, &port->dl_port, phys_index);
	if (ret) {
		kfree(port);
		return ERR_PTR(ret);
	}

	port->dev = dev;
	port->interface = interface;

	port->index = index;
	port->phys_index = phys_index;

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

	mqnic_port_set_tx_ctrl(port, 0);
	mqnic_port_set_rx_ctrl(port, 0);
	mqnic_port_set_lfc_ctrl(port, interface->max_rx_mtu * 2);

	for (k = 0; k < 8; k++)
		mqnic_port_set_pfc_ctrl(port, k, 0);

	dev_info(dev, "Port RX ctrl: 0x%08x", mqnic_port_get_rx_ctrl(port));
	dev_info(dev, "Port TX ctrl: 0x%08x", mqnic_port_get_tx_ctrl(port));

	return port;

fail:
	mqnic_destroy_port(port);
	return ERR_PTR(ret);
}

void mqnic_destroy_port(struct mqnic_port *port)
{
	if (port->rb_list)
		mqnic_free_reg_block_list(port->rb_list);

	devlink_port_unregister(&port->dl_port);

	kfree(port);
}

u32 mqnic_port_get_tx_ctrl(struct mqnic_port *port)
{
	return ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_TX_CTRL);
}
EXPORT_SYMBOL(mqnic_port_get_tx_ctrl);

void mqnic_port_set_tx_ctrl(struct mqnic_port *port, u32 val)
{
	iowrite32(val, port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_TX_CTRL);
}
EXPORT_SYMBOL(mqnic_port_set_tx_ctrl);

u32 mqnic_port_get_rx_ctrl(struct mqnic_port *port)
{
	return ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_RX_CTRL);
}
EXPORT_SYMBOL(mqnic_port_get_rx_ctrl);

void mqnic_port_set_rx_ctrl(struct mqnic_port *port, u32 val)
{
	iowrite32(val, port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_RX_CTRL);
}
EXPORT_SYMBOL(mqnic_port_set_rx_ctrl);

u32 mqnic_port_get_fc_ctrl(struct mqnic_port *port)
{
	return ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_FC_CTRL);
}
EXPORT_SYMBOL(mqnic_port_get_fc_ctrl);

void mqnic_port_set_fc_ctrl(struct mqnic_port *port, u32 val)
{
	iowrite32(val, port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_FC_CTRL);
}
EXPORT_SYMBOL(mqnic_port_set_fc_ctrl);

u32 mqnic_port_get_lfc_ctrl(struct mqnic_port *port)
{
	return ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_LFC_CTRL);
}
EXPORT_SYMBOL(mqnic_port_get_lfc_ctrl);

void mqnic_port_set_lfc_ctrl(struct mqnic_port *port, u32 val)
{
	iowrite32(val, port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_LFC_CTRL);
}
EXPORT_SYMBOL(mqnic_port_set_lfc_ctrl);

u32 mqnic_port_get_pfc_ctrl(struct mqnic_port *port, int index)
{
	return ioread32(port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_PFC_CTRL0 + index*4);
}
EXPORT_SYMBOL(mqnic_port_get_pfc_ctrl);

void mqnic_port_set_pfc_ctrl(struct mqnic_port *port, int index, u32 val)
{
	iowrite32(val, port->port_ctrl_rb->regs + MQNIC_RB_PORT_CTRL_REG_PFC_CTRL0 + index*4);
}
EXPORT_SYMBOL(mqnic_port_set_pfc_ctrl);
