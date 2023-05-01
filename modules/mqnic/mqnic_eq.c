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

static int mqnic_eq_int(struct notifier_block *nb, unsigned long action, void *data)
{
	struct mqnic_eq *eq = container_of(nb, struct mqnic_eq, irq_nb);

	mqnic_process_eq(eq);
	mqnic_arm_eq(eq);

	return NOTIFY_DONE;
}

struct mqnic_eq *mqnic_create_eq(struct mqnic_if *interface,
		int eqn, u8 __iomem *hw_addr)
{
	struct mqnic_eq *eq;

	eq = kzalloc(sizeof(*eq), GFP_KERNEL);
	if (!eq)
		return ERR_PTR(-ENOMEM);

	eq->dev = interface->dev;
	eq->interface = interface;

	eq->eqn = eqn;
	eq->active = 0;

	eq->irq_nb.notifier_call = mqnic_eq_int;

	eq->hw_addr = hw_addr;
	eq->hw_ptr_mask = 0xffff;
	eq->hw_head_ptr = hw_addr + MQNIC_EQ_HEAD_PTR_REG;
	eq->hw_tail_ptr = hw_addr + MQNIC_EQ_TAIL_PTR_REG;

	eq->head_ptr = 0;
	eq->tail_ptr = 0;

	// deactivate queue
	iowrite32(0, eq->hw_addr + MQNIC_EQ_ACTIVE_LOG_SIZE_REG);

	return eq;
}

void mqnic_destroy_eq(struct mqnic_eq *eq)
{
	mqnic_free_eq(eq);

	kfree(eq);
}

int mqnic_alloc_eq(struct mqnic_eq *eq, int size, int stride)
{
	if (eq->active || eq->buf)
		return -EINVAL;

	eq->size = roundup_pow_of_two(size);
	eq->size_mask = eq->size - 1;
	eq->stride = roundup_pow_of_two(stride);

	eq->buf_size = eq->size * eq->stride;
	eq->buf = dma_alloc_coherent(eq->dev, eq->buf_size, &eq->buf_dma_addr, GFP_KERNEL);
	if (!eq->buf)
		return -ENOMEM;

	eq->head_ptr = 0;
	eq->tail_ptr = 0;

	// deactivate queue
	iowrite32(0, eq->hw_addr + MQNIC_EQ_ACTIVE_LOG_SIZE_REG);
	// set base address
	iowrite32(eq->buf_dma_addr, eq->hw_addr + MQNIC_EQ_BASE_ADDR_REG + 0);
	iowrite32(eq->buf_dma_addr >> 32, eq->hw_addr + MQNIC_EQ_BASE_ADDR_REG + 4);
	// set interrupt index
	iowrite32(0, eq->hw_addr + MQNIC_EQ_INTERRUPT_INDEX_REG);
	// set pointers
	iowrite32(eq->head_ptr & eq->hw_ptr_mask, eq->hw_addr + MQNIC_EQ_HEAD_PTR_REG);
	iowrite32(eq->tail_ptr & eq->hw_ptr_mask, eq->hw_addr + MQNIC_EQ_TAIL_PTR_REG);
	// set size
	iowrite32(ilog2(eq->size), eq->hw_addr + MQNIC_EQ_ACTIVE_LOG_SIZE_REG);

	return 0;
}

void mqnic_free_eq(struct mqnic_eq *eq)
{
	mqnic_deactivate_eq(eq);

	if (eq->buf) {
		dma_free_coherent(eq->dev, eq->buf_size, eq->buf, eq->buf_dma_addr);
		eq->buf = NULL;
		eq->buf_dma_addr = 0;
	}
}

int mqnic_activate_eq(struct mqnic_eq *eq, struct mqnic_irq *irq)
{
	int ret = 0;

	mqnic_deactivate_eq(eq);

	if (!eq->buf || !irq)
		return -EINVAL;

	// register interrupt
	ret = atomic_notifier_chain_register(&irq->nh, &eq->irq_nb);
	if (ret)
		return ret;

	eq->irq = irq;

	eq->head_ptr = 0;
	eq->tail_ptr = 0;

	memset(eq->buf, 1, eq->buf_size);

	// deactivate queue
	iowrite32(0, eq->hw_addr + MQNIC_EQ_ACTIVE_LOG_SIZE_REG);
	// set base address
	iowrite32(eq->buf_dma_addr, eq->hw_addr + MQNIC_EQ_BASE_ADDR_REG + 0);
	iowrite32(eq->buf_dma_addr >> 32, eq->hw_addr + MQNIC_EQ_BASE_ADDR_REG + 4);
	// set interrupt index
	iowrite32(eq->irq->index, eq->hw_addr + MQNIC_EQ_INTERRUPT_INDEX_REG);
	// set pointers
	iowrite32(eq->head_ptr & eq->hw_ptr_mask, eq->hw_addr + MQNIC_EQ_HEAD_PTR_REG);
	iowrite32(eq->tail_ptr & eq->hw_ptr_mask, eq->hw_addr + MQNIC_EQ_TAIL_PTR_REG);
	// set size and activate queue
	iowrite32(ilog2(eq->size) | MQNIC_EQ_ACTIVE_MASK,
			eq->hw_addr + MQNIC_EQ_ACTIVE_LOG_SIZE_REG);

	eq->active = 1;

	return 0;
}

void mqnic_deactivate_eq(struct mqnic_eq *eq)
{
	int ret = 0;

	// deactivate queue
	iowrite32(ilog2(eq->size), eq->hw_addr + MQNIC_EQ_ACTIVE_LOG_SIZE_REG);
	// disarm queue
	iowrite32(0, eq->hw_addr + MQNIC_EQ_INTERRUPT_INDEX_REG);

	// unregister interrupt
	if (eq->irq)
		ret = atomic_notifier_chain_unregister(&eq->irq->nh, &eq->irq_nb);

	eq->irq = NULL;

	eq->active = 0;
}

void mqnic_eq_read_head_ptr(struct mqnic_eq *eq)
{
	eq->head_ptr += (ioread32(eq->hw_head_ptr) - eq->head_ptr) & eq->hw_ptr_mask;
}

void mqnic_eq_write_tail_ptr(struct mqnic_eq *eq)
{
	iowrite32(eq->tail_ptr & eq->hw_ptr_mask, eq->hw_tail_ptr);
}

void mqnic_arm_eq(struct mqnic_eq *eq)
{
	if (!eq->active)
		return;

	iowrite32(eq->irq->index | MQNIC_EQ_ARM_MASK,
			eq->hw_addr + MQNIC_EQ_INTERRUPT_INDEX_REG);
}

void mqnic_process_eq(struct mqnic_eq *eq)
{
	struct mqnic_if *interface = eq->interface;
	struct mqnic_event *event;
	struct mqnic_cq *cq;
	u32 eq_index;
	u32 eq_tail_ptr;
	int done = 0;

	// read head pointer from NIC
	eq_tail_ptr = eq->tail_ptr;
	eq_index = eq_tail_ptr & eq->size_mask;

	while (1) {
		event = (struct mqnic_event *)(eq->buf + eq_index * eq->stride);

		if (!!(event->phase & cpu_to_le32(0x80000000)) == !!(eq_tail_ptr & eq->size))
			break;

		dma_rmb();

		if (event->type == MQNIC_EVENT_TYPE_TX_CPL) {
			// transmit completion event
			if (unlikely(le16_to_cpu(event->source) > interface->tx_cq_count)) {
				dev_err(eq->dev, "%s on port %d: unknown event source %d (index %d, type %d)",
						__func__, interface->index, le16_to_cpu(event->source), eq_index,
						le16_to_cpu(event->type));
				print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
						event, MQNIC_EVENT_SIZE, true);
			} else {
				cq = interface->tx_cq[le16_to_cpu(event->source)];
				if (likely(cq && cq->handler))
					cq->handler(cq);
			}
		} else if (le16_to_cpu(event->type) == MQNIC_EVENT_TYPE_RX_CPL) {
			// receive completion event
			if (unlikely(le16_to_cpu(event->source) > interface->rx_cq_count)) {
				dev_err(eq->dev, "%s on port %d: unknown event source %d (index %d, type %d)",
						__func__, interface->index, le16_to_cpu(event->source), eq_index,
						le16_to_cpu(event->type));
				print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
						event, MQNIC_EVENT_SIZE, true);
			} else {
				cq = interface->rx_cq[le16_to_cpu(event->source)];
				if (likely(cq && cq->handler))
					cq->handler(cq);
			}
		} else {
			dev_err(eq->dev, "%s on port %d: unknown event type %d (index %d, source %d)",
					__func__, interface->index, le16_to_cpu(event->type), eq_index,
					le16_to_cpu(event->source));
			print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
					event, MQNIC_EVENT_SIZE, true);
		}

		done++;

		eq_tail_ptr++;
		eq_index = eq_tail_ptr & eq->size_mask;
	}

	// update eq tail
	eq->tail_ptr = eq_tail_ptr;
	mqnic_eq_write_tail_ptr(eq);
}
