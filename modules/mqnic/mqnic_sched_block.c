// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

struct mqnic_sched_block *mqnic_create_sched_block(struct mqnic_if *interface,
		int index, struct mqnic_reg_block *block_rb)
{
	struct device *dev = interface->dev;
	struct mqnic_sched_block *block;
	struct mqnic_reg_block *rb;
	u32 offset;
	int ret = 0;

	block = kzalloc(sizeof(*block), GFP_KERNEL);
	if (!block)
		return ERR_PTR(-ENOMEM);

	block->dev = dev;
	block->interface = interface;

	block->index = index;

	block->block_rb = block_rb;

	offset = ioread32(block_rb->regs + MQNIC_RB_SCHED_BLOCK_REG_OFFSET);

	block->rb_list = mqnic_enumerate_reg_block_list(interface->hw_addr, offset, interface->hw_regs_size - offset);

	if (!block->rb_list) {
		ret = -EIO;
		dev_err(dev, "Failed to enumerate blocks");
		goto fail;
	}

	dev_info(dev, "Scheduler block-level register blocks:");
	for (rb = block->rb_list; rb->regs; rb++)
		dev_info(dev, " type 0x%08x (v %d.%d.%d.%d)", rb->type, rb->version >> 24,
				(rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

	block->sched_count = 0;
	for (rb = block->rb_list; rb->regs; rb++) {
		if (rb->type == MQNIC_RB_SCHED_RR_TYPE && rb->version == MQNIC_RB_SCHED_RR_VER) {
			struct mqnic_sched *sched = mqnic_create_scheduler(block,
					block->sched_count, rb);

			if (IS_ERR_OR_NULL(sched)) {
				ret = PTR_ERR(sched);
				goto fail;
			}

			block->sched[block->sched_count] = sched;
			block->sched_count++;
		}
	}

	dev_info(dev, "Scheduler count: %d", block->sched_count);

	mqnic_deactivate_sched_block(block);

	return block;

fail:
	mqnic_destroy_sched_block(block);
	return ERR_PTR(ret);
}

void mqnic_destroy_sched_block(struct mqnic_sched_block *block)
{
	int k;

	mqnic_deactivate_sched_block(block);

	for (k = 0; k < ARRAY_SIZE(block->sched); k++) {
		if (block->sched[k]) {
			mqnic_destroy_scheduler(block->sched[k]);
			block->sched[k] = NULL;
		}
	}

	if (block->rb_list)
		mqnic_free_reg_block_list(block->rb_list);

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
EXPORT_SYMBOL(mqnic_activate_sched_block);

void mqnic_deactivate_sched_block(struct mqnic_sched_block *block)
{
	int k;

	// disable schedulers
	for (k = 0; k < ARRAY_SIZE(block->sched); k++)
		if (block->sched[k])
			mqnic_scheduler_disable(block->sched[k]);
}
EXPORT_SYMBOL(mqnic_deactivate_sched_block);
