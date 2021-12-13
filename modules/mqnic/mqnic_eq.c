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
	struct mqnic_eq_ring *ring = container_of(nb, struct mqnic_eq_ring, irq_nb);

	mqnic_process_eq(ring);
	mqnic_arm_eq(ring);

	return NOTIFY_DONE;
}

int mqnic_create_eq_ring(struct mqnic_if *interface, struct mqnic_eq_ring **ring_ptr,
		int index, u8 __iomem *hw_addr)
{
	struct mqnic_eq_ring *ring;

	ring = kzalloc(sizeof(*ring), GFP_KERNEL);
	if (!ring)
		return -ENOMEM;

	ring->dev = interface->dev;
	ring->interface = interface;

	ring->index = index;
	ring->active = 0;

	ring->irq_nb.notifier_call = mqnic_eq_int;

	ring->hw_addr = hw_addr;
	ring->hw_ptr_mask = 0xffff;
	ring->hw_head_ptr = hw_addr + MQNIC_EVENT_QUEUE_HEAD_PTR_REG;
	ring->hw_tail_ptr = hw_addr + MQNIC_EVENT_QUEUE_TAIL_PTR_REG;

	ring->head_ptr = 0;
	ring->tail_ptr = 0;

	// deactivate queue
	iowrite32(0, ring->hw_addr + MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);

	*ring_ptr = ring;
	return 0;
}

void mqnic_destroy_eq_ring(struct mqnic_eq_ring **ring_ptr)
{
	struct mqnic_eq_ring *ring = *ring_ptr;
	*ring_ptr = NULL;

	mqnic_free_eq_ring(ring);

	kfree(ring);
}

int mqnic_alloc_eq_ring(struct mqnic_eq_ring *ring, int size, int stride)
{
	ring->size = roundup_pow_of_two(size);
	ring->size_mask = ring->size - 1;
	ring->stride = roundup_pow_of_two(stride);

	ring->buf_size = ring->size * ring->stride;
	ring->buf = dma_alloc_coherent(ring->dev, ring->buf_size, &ring->buf_dma_addr, GFP_KERNEL);
	if (!ring->buf)
		return -ENOMEM;

	ring->head_ptr = 0;
	ring->tail_ptr = 0;

	// deactivate queue
	iowrite32(0, ring->hw_addr + MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);
	// set base address
	iowrite32(ring->buf_dma_addr, ring->hw_addr + MQNIC_EVENT_QUEUE_BASE_ADDR_REG + 0);
	iowrite32(ring->buf_dma_addr >> 32, ring->hw_addr + MQNIC_EVENT_QUEUE_BASE_ADDR_REG + 4);
	// set interrupt index
	iowrite32(0, ring->hw_addr + MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);
	// set pointers
	iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_addr + MQNIC_EVENT_QUEUE_HEAD_PTR_REG);
	iowrite32(ring->tail_ptr & ring->hw_ptr_mask, ring->hw_addr + MQNIC_EVENT_QUEUE_TAIL_PTR_REG);
	// set size
	iowrite32(ilog2(ring->size), ring->hw_addr + MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);

	return 0;
}

void mqnic_free_eq_ring(struct mqnic_eq_ring *ring)
{
	mqnic_deactivate_eq_ring(ring);

	if (!ring->buf)
		return;

	dma_free_coherent(ring->dev, ring->buf_size, ring->buf, ring->buf_dma_addr);
	ring->buf = NULL;
	ring->buf_dma_addr = 0;
}

int mqnic_activate_eq_ring(struct mqnic_eq_ring *ring, struct mqnic_irq *irq)
{
	int ret = 0;

	mqnic_deactivate_eq_ring(ring);

	if (!ring->buf || !irq)
		return -EINVAL;

	// register interrupt
	ret = atomic_notifier_chain_register(&irq->nh, &ring->irq_nb);
	if (ret)
		return ret;

	ring->irq = irq;
	ring->irq_index = irq->index;

	// deactivate queue
	iowrite32(0, ring->hw_addr + MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);
	// set base address
	iowrite32(ring->buf_dma_addr, ring->hw_addr + MQNIC_EVENT_QUEUE_BASE_ADDR_REG + 0);
	iowrite32(ring->buf_dma_addr >> 32, ring->hw_addr + MQNIC_EVENT_QUEUE_BASE_ADDR_REG + 4);
	// set interrupt index
	iowrite32(ring->irq_index, ring->hw_addr + MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);
	// set pointers
	iowrite32(ring->head_ptr & ring->hw_ptr_mask,
			ring->hw_addr + MQNIC_EVENT_QUEUE_HEAD_PTR_REG);
	iowrite32(ring->tail_ptr & ring->hw_ptr_mask,
			ring->hw_addr + MQNIC_EVENT_QUEUE_TAIL_PTR_REG);
	// set size and activate queue
	iowrite32(ilog2(ring->size) | MQNIC_EVENT_QUEUE_ACTIVE_MASK,
			ring->hw_addr + MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);

	ring->active = 1;

	return 0;
}

void mqnic_deactivate_eq_ring(struct mqnic_eq_ring *ring)
{
	int ret = 0;

	// deactivate queue
	iowrite32(ilog2(ring->size), ring->hw_addr + MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);
	// disarm queue
	iowrite32(0, ring->hw_addr + MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);

	// unregister interrupt
	if (ring->irq)
		ret = atomic_notifier_chain_unregister(&ring->irq->nh, &ring->irq_nb);

	ring->irq = NULL;

	ring->active = 0;
}

bool mqnic_is_eq_ring_empty(const struct mqnic_eq_ring *ring)
{
	return ring->head_ptr == ring->tail_ptr;
}

bool mqnic_is_eq_ring_full(const struct mqnic_eq_ring *ring)
{
	return ring->head_ptr - ring->tail_ptr >= ring->size;
}

void mqnic_eq_read_head_ptr(struct mqnic_eq_ring *ring)
{
	ring->head_ptr += (ioread32(ring->hw_head_ptr) - ring->head_ptr) & ring->hw_ptr_mask;
}

void mqnic_eq_write_tail_ptr(struct mqnic_eq_ring *ring)
{
	iowrite32(ring->tail_ptr & ring->hw_ptr_mask, ring->hw_tail_ptr);
}

void mqnic_arm_eq(struct mqnic_eq_ring *ring)
{
	if (!ring->active)
		return;

	iowrite32(ring->irq_index | MQNIC_EVENT_QUEUE_ARM_MASK,
			ring->hw_addr + MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);
}

void mqnic_process_eq(struct mqnic_eq_ring *eq_ring)
{
	struct mqnic_if *interface = eq_ring->interface;
	struct mqnic_event *event;
	struct mqnic_cq_ring *cq_ring;
	u32 eq_index;
	u32 eq_tail_ptr;
	int done = 0;

	// read head pointer from NIC
	mqnic_eq_read_head_ptr(eq_ring);

	eq_tail_ptr = eq_ring->tail_ptr;
	eq_index = eq_tail_ptr & eq_ring->size_mask;

	while (eq_ring->head_ptr != eq_tail_ptr) {
		event = (struct mqnic_event *)(eq_ring->buf + eq_index * eq_ring->stride);

		if (event->type == MQNIC_EVENT_TYPE_TX_CPL) {
			// transmit completion event
			if (unlikely(le16_to_cpu(event->source) > interface->tx_cpl_queue_count)) {
				dev_err(eq_ring->dev, "%s on port %d: unknown event source %d (index %d, type %d)",
						__func__, interface->index, le16_to_cpu(event->source), eq_index,
						le16_to_cpu(event->type));
				print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
						event, MQNIC_EVENT_SIZE, true);
			} else {
				cq_ring = interface->tx_cpl_ring[le16_to_cpu(event->source)];
				if (likely(cq_ring && cq_ring->handler))
					cq_ring->handler(cq_ring);
			}
		} else if (le16_to_cpu(event->type) == MQNIC_EVENT_TYPE_RX_CPL) {
			// receive completion event
			if (unlikely(le16_to_cpu(event->source) > interface->rx_cpl_queue_count)) {
				dev_err(eq_ring->dev, "%s on port %d: unknown event source %d (index %d, type %d)",
						__func__, interface->index, le16_to_cpu(event->source), eq_index,
						le16_to_cpu(event->type));
				print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
						event, MQNIC_EVENT_SIZE, true);
			} else {
				cq_ring = interface->rx_cpl_ring[le16_to_cpu(event->source)];
				if (likely(cq_ring && cq_ring->handler))
					cq_ring->handler(cq_ring);
			}
		} else {
			dev_err(eq_ring->dev, "%s on port %d: unknown event type %d (index %d, source %d)",
					__func__, interface->index, le16_to_cpu(event->type), eq_index,
					le16_to_cpu(event->source));
			print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
					event, MQNIC_EVENT_SIZE, true);
		}

		done++;

		eq_tail_ptr++;
		eq_index = eq_tail_ptr & eq_ring->size_mask;
	}

	// update eq tail
	eq_ring->tail_ptr = eq_tail_ptr;
	mqnic_eq_write_tail_ptr(eq_ring);
}
