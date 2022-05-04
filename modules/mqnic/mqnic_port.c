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
		int index, struct mqnic_reg_block *port_rb)
{
	struct device *dev = interface->dev;
	struct mqnic_port *port;
	struct mqnic_reg_block *rb;
	u32 offset;
	int ret = 0;

	port = kzalloc(sizeof(*port), GFP_KERNEL);
	if (!port)
		return -ENOMEM;

	*port_ptr = port;

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

	return 0;

fail:
	mqnic_destroy_port(port_ptr);
	return ret;
}

void mqnic_destroy_port(struct mqnic_port **port_ptr)
{
	struct mqnic_port *port = *port_ptr;

	if (port->rb_list)
		mqnic_free_reg_block_list(port->rb_list);

	*port_ptr = NULL;
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
