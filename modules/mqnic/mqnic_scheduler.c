// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

#include "mqnic.h"

struct mqnic_sched *mqnic_create_scheduler(struct mqnic_sched_block *block,
		int index, struct mqnic_reg_block *rb)
{
	struct device *dev = block->dev;
	struct mqnic_sched *sched;

	sched = kzalloc(sizeof(*sched), GFP_KERNEL);
	if (!sched)
		return ERR_PTR(-ENOMEM);

	sched->dev = dev;
	sched->interface = block->interface;
	sched->sched_block = block;

	sched->index = index;

	sched->rb = rb;

	sched->type = rb->type;
	sched->offset = ioread32(rb->regs + MQNIC_RB_SCHED_RR_REG_OFFSET);
	sched->channel_count = ioread32(rb->regs + MQNIC_RB_SCHED_RR_REG_CH_COUNT);
	sched->channel_stride = ioread32(rb->regs + MQNIC_RB_SCHED_RR_REG_CH_STRIDE);

	sched->hw_addr = block->interface->hw_addr + sched->offset;

	dev_info(dev, "Scheduler type: 0x%08x", sched->type);
	dev_info(dev, "Scheduler offset: 0x%08x", sched->offset);
	dev_info(dev, "Scheduler channel count: %d", sched->channel_count);
	dev_info(dev, "Scheduler channel stride: 0x%08x", sched->channel_stride);

	mqnic_scheduler_disable(sched);

	return sched;
}

void mqnic_destroy_scheduler(struct mqnic_sched *sched)
{
	mqnic_scheduler_disable(sched);

	kfree(sched);
}

int mqnic_scheduler_enable(struct mqnic_sched *sched)
{
	int k;

	// enable scheduler
	iowrite32(1, sched->rb->regs + MQNIC_RB_SCHED_RR_REG_CTRL);

	// enable queues
	for (k = 0; k < sched->channel_count; k++)
		iowrite32(3, sched->hw_addr + k * sched->channel_stride);

	return 0;
}
EXPORT_SYMBOL(mqnic_scheduler_enable);

void mqnic_scheduler_disable(struct mqnic_sched *sched)
{
	// disable scheduler
	iowrite32(0, sched->rb->regs + MQNIC_RB_SCHED_RR_REG_CTRL);
}
EXPORT_SYMBOL(mqnic_scheduler_disable);
