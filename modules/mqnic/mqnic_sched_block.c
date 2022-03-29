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

int mqnic_create_sched_block(struct mqnic_if *interface, struct mqnic_sched_block **block_ptr,
		int index, struct reg_block *block_rb)
{
	struct device *dev = interface->dev;
	struct mqnic_sched_block *block;
	struct reg_block *rb;
	u32 offset;
	int ret = 0;

	block = kzalloc(sizeof(*block), GFP_KERNEL);
	if (!block)
		return -ENOMEM;

	*block_ptr = block;

	block->dev = dev;
	block->interface = interface;

	block->index = index;

	block->tx_queue_count = interface->tx_queue_count;

	block->block_rb = block_rb;

	offset = ioread32(block_rb->regs + MQNIC_RB_SCHED_BLOCK_REG_OFFSET);

	block->rb_list = enumerate_reg_block_list(interface->hw_addr, offset, interface->hw_regs_size - offset);

	if (!block->rb_list) {
		ret = -EIO;
		dev_err(dev, "Failed to enumerate blocks");
		goto fail;
	}

	dev_info(dev, "Scheduler block-level register blocks:");
	for (rb = block->rb_list; rb->type && rb->version; rb++)
		dev_info(dev, " type 0x%08x (v %d.%d.%d.%d)", rb->type, rb->version >> 24, 
				(rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

	block->sched_count = 0;
	for (rb = block->rb_list; rb->type && rb->version; rb++) {
		if (rb->type == MQNIC_RB_SCHED_RR_TYPE && rb->version == MQNIC_RB_SCHED_RR_VER) {
			ret = mqnic_create_scheduler(block, &block->sched[block->sched_count],
					block->sched_count, rb);

			if (ret)
				goto fail;

			block->sched_count++;
		}
	}

	dev_info(dev, "Scheduler count: %d", block->sched_count);

	mqnic_deactivate_sched_block(block);

	return 0;

fail:
	mqnic_destroy_sched_block(block_ptr);
	return ret;
}

void mqnic_destroy_sched_block(struct mqnic_sched_block **block_ptr)
{
	struct mqnic_sched_block *block = *block_ptr;
	int k;

	mqnic_deactivate_sched_block(block);

	for (k = 0; k < ARRAY_SIZE(block->sched); k++)
		if (block->sched[k])
			mqnic_destroy_scheduler(&block->sched[k]);

	if (block->rb_list)
		free_reg_block_list(block->rb_list);

	*block_ptr = NULL;
	kfree(block);
}

int mqnic_activate_sched_block(struct mqnic_sched_block *block)
{
	int k;

	// enable schedulers
	for (k = 0; k < ARRAY_SIZE(block->sched); k++)
		if (block->sched[k])
			mqnic_scheduler_enable(block->sched[k]);

	return 0;
}

void mqnic_deactivate_sched_block(struct mqnic_sched_block *block)
{
	int k;

	// disable schedulers
	for (k = 0; k < ARRAY_SIZE(block->sched); k++)
		if (block->sched[k])
			mqnic_scheduler_disable(block->sched[k]);
}
