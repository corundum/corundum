// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2021, The Regents of the University of California.
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

int mqnic_create_scheduler(struct mqnic_sched_block *block, struct mqnic_sched **sched_ptr,
		int index, struct mqnic_reg_block *rb)
{
	struct device *dev = block->dev;
	struct mqnic_sched *sched;

	sched = kzalloc(sizeof(*sched), GFP_KERNEL);
	if (!sched)
		return -ENOMEM;

	*sched_ptr = sched;

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

	return 0;
}

void mqnic_destroy_scheduler(struct mqnic_sched **sched_ptr)
{
	struct mqnic_sched *sched = *sched_ptr;
	*sched_ptr = NULL;

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
