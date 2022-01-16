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
		int index, struct reg_block *block_rb)
{
	struct device *dev = interface->dev;
	struct mqnic_port *port;
	struct reg_block *rb;
	u32 offset;
	int ret = 0;

	port = kzalloc(sizeof(*port), GFP_KERNEL);
	if (!port)
		return -ENOMEM;

	*port_ptr = port;

	port->dev = dev;
	port->interface = interface;

	port->index = index;

	port->tx_queue_count = interface->tx_queue_count;

	port->block_rb = block_rb;

	offset = ioread32(block_rb->regs + MQNIC_RB_SCHED_BLOCK_REG_OFFSET);

	port->rb_list = enumerate_reg_block_list(interface->hw_addr, offset, interface->hw_regs_size - offset);

	if (!port->rb_list) {
		ret = -EIO;
		dev_err(dev, "Failed to enumerate blocks");
		goto fail;
	}

	dev_info(dev, "Port-level register blocks:");
	for (rb = port->rb_list; rb->type && rb->version; rb++)
		dev_info(dev, " type 0x%08x (v %d.%d.%d.%d)", rb->type, rb->version >> 24, 
				(rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

	port->sched_count = 0;
	for (rb = port->rb_list; rb->type && rb->version; rb++) {
		if (rb->type == MQNIC_RB_SCHED_RR_TYPE && rb->version == MQNIC_RB_SCHED_RR_VER) {
			ret = mqnic_create_scheduler(port, &port->sched[port->sched_count],
					port->sched_count, rb);

			if (ret)
				goto fail;

			port->sched_count++;
		}
	}

	dev_info(dev, "Scheduler count: %d", port->sched_count);

	mqnic_deactivate_port(port);

	return 0;

fail:
	mqnic_destroy_port(port_ptr);
	return ret;
}

void mqnic_destroy_port(struct mqnic_port **port_ptr)
{
	struct mqnic_port *port = *port_ptr;
	int k;

	mqnic_deactivate_port(port);

	for (k = 0; k < ARRAY_SIZE(port->sched); k++)
		if (port->sched[k])
			mqnic_destroy_scheduler(&port->sched[k]);

	if (port->rb_list)
		free_reg_block_list(port->rb_list);

	*port_ptr = NULL;
	kfree(port);
}

int mqnic_activate_port(struct mqnic_port *port)
{
	int k;

	// enable schedulers
	for (k = 0; k < ARRAY_SIZE(port->sched); k++)
		if (port->sched[k])
			mqnic_scheduler_enable(port->sched[k]);

	return 0;
}

void mqnic_deactivate_port(struct mqnic_port *port)
{
	int k;

	// disable schedulers
	for (k = 0; k < ARRAY_SIZE(port->sched); k++)
		if (port->sched[k])
			mqnic_scheduler_disable(port->sched[k]);
}
