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

struct mqnic_cq *mqnic_create_cq(struct mqnic_if *interface,
		int cqn, u8 __iomem *hw_addr)
{
	struct mqnic_cq *cq;

	cq = kzalloc(sizeof(*cq), GFP_KERNEL);
	if (!cq)
		return ERR_PTR(-ENOMEM);

	cq->dev = interface->dev;
	cq->interface = interface;

	cq->cqn = cqn;
	cq->active = 0;

	cq->hw_addr = hw_addr;
	cq->hw_ptr_mask = 0xffff;
	cq->hw_head_ptr = hw_addr + MQNIC_CQ_HEAD_PTR_REG;
	cq->hw_tail_ptr = hw_addr + MQNIC_CQ_TAIL_PTR_REG;

	cq->head_ptr = 0;
	cq->tail_ptr = 0;

	// deactivate queue
	iowrite32(0, cq->hw_addr + MQNIC_CQ_ACTIVE_LOG_SIZE_REG);

	return cq;
}

void mqnic_destroy_cq(struct mqnic_cq *cq)
{
	mqnic_free_cq(cq);

	kfree(cq);
}

int mqnic_alloc_cq(struct mqnic_cq *cq, int size, int stride)
{
	if (cq->active || cq->buf)
		return -EINVAL;

	cq->size = roundup_pow_of_two(size);
	cq->size_mask = cq->size - 1;
	cq->stride = roundup_pow_of_two(stride);

	cq->buf_size = cq->size * cq->stride;
	cq->buf = dma_alloc_coherent(cq->dev, cq->buf_size, &cq->buf_dma_addr, GFP_KERNEL);
	if (!cq->buf)
		return -ENOMEM;

	cq->head_ptr = 0;
	cq->tail_ptr = 0;

	// deactivate queue
	iowrite32(0, cq->hw_addr + MQNIC_CQ_ACTIVE_LOG_SIZE_REG);
	// set base address
	iowrite32(cq->buf_dma_addr, cq->hw_addr + MQNIC_CQ_BASE_ADDR_REG + 0);
	iowrite32(cq->buf_dma_addr >> 32, cq->hw_addr + MQNIC_CQ_BASE_ADDR_REG + 4);
	// set interrupt index
	iowrite32(0, cq->hw_addr + MQNIC_CQ_INTERRUPT_INDEX_REG);
	// set pointers
	iowrite32(cq->head_ptr & cq->hw_ptr_mask, cq->hw_addr + MQNIC_CQ_HEAD_PTR_REG);
	iowrite32(cq->tail_ptr & cq->hw_ptr_mask, cq->hw_addr + MQNIC_CQ_TAIL_PTR_REG);
	// set size
	iowrite32(ilog2(cq->size), cq->hw_addr + MQNIC_CQ_ACTIVE_LOG_SIZE_REG);

	return 0;
}

void mqnic_free_cq(struct mqnic_cq *cq)
{
	mqnic_deactivate_cq(cq);

	if (cq->buf) {
		dma_free_coherent(cq->dev, cq->buf_size, cq->buf, cq->buf_dma_addr);
		cq->buf = NULL;
		cq->buf_dma_addr = 0;
	}
}

int mqnic_activate_cq(struct mqnic_cq *cq, struct mqnic_eq *eq)
{
	mqnic_deactivate_cq(cq);

	if (!cq->buf || !eq)
		return -EINVAL;

	cq->eq = eq;

	cq->head_ptr = 0;
	cq->tail_ptr = 0;

	memset(cq->buf, 1, cq->buf_size);

	// deactivate queue
	iowrite32(0, cq->hw_addr + MQNIC_CQ_ACTIVE_LOG_SIZE_REG);
	// set base address
	iowrite32(cq->buf_dma_addr, cq->hw_addr + MQNIC_CQ_BASE_ADDR_REG + 0);
	iowrite32(cq->buf_dma_addr >> 32, cq->hw_addr + MQNIC_CQ_BASE_ADDR_REG + 4);
	// set interrupt index
	iowrite32(cq->eq->eqn, cq->hw_addr + MQNIC_CQ_INTERRUPT_INDEX_REG);
	// set pointers
	iowrite32(cq->head_ptr & cq->hw_ptr_mask, cq->hw_addr + MQNIC_CQ_HEAD_PTR_REG);
	iowrite32(cq->tail_ptr & cq->hw_ptr_mask, cq->hw_addr + MQNIC_CQ_TAIL_PTR_REG);
	// set size and activate queue
	iowrite32(ilog2(cq->size) | MQNIC_CQ_ACTIVE_MASK,
			cq->hw_addr + MQNIC_CQ_ACTIVE_LOG_SIZE_REG);

	cq->active = 1;

	return 0;
}

void mqnic_deactivate_cq(struct mqnic_cq *cq)
{
	// deactivate queue
	iowrite32(ilog2(cq->size), cq->hw_addr + MQNIC_CQ_ACTIVE_LOG_SIZE_REG);
	// disarm queue
	iowrite32(0, cq->hw_addr + MQNIC_CQ_INTERRUPT_INDEX_REG);

	cq->eq = NULL;

	cq->active = 0;
}

void mqnic_cq_read_head_ptr(struct mqnic_cq *cq)
{
	cq->head_ptr += (ioread32(cq->hw_head_ptr) - cq->head_ptr) & cq->hw_ptr_mask;
}

void mqnic_cq_write_tail_ptr(struct mqnic_cq *cq)
{
	iowrite32(cq->tail_ptr & cq->hw_ptr_mask, cq->hw_tail_ptr);
}

void mqnic_arm_cq(struct mqnic_cq *cq)
{
	if (!cq->active)
		return;

	iowrite32(cq->eq->eqn | MQNIC_CQ_ARM_MASK,
			cq->hw_addr + MQNIC_CQ_INTERRUPT_INDEX_REG);
}
