/*

Copyright 2019, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

#include "mqnic.h"

int mqnic_create_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring **ring_ptr, int size, int stride, int index, u8 __iomem *hw_addr)
{
    struct device *dev = priv->dev;
    struct mqnic_eq_ring *ring;
    int ret;

    ring = kzalloc(sizeof(*ring), GFP_KERNEL);
    if (!ring)
    {
        dev_err(dev, "Failed to allocate EQ ring");
        return -ENOMEM;
    }

    ring->ndev = priv->ndev;

    ring->size = roundup_pow_of_two(size);
    ring->size_mask = ring->size-1;
    ring->stride = roundup_pow_of_two(stride);

    ring->buf_size = ring->size*ring->stride;
    ring->buf = dma_alloc_coherent(dev, ring->buf_size, &ring->buf_dma_addr, GFP_KERNEL);
    if (!ring->buf)
    {
        dev_err(dev, "Failed to allocate EQ ring DMA buffer");
        ret = -ENOMEM;
        goto fail_ring;
    }

    ring->hw_addr = hw_addr;
    ring->hw_ptr_mask = 0xffff;
    ring->hw_head_ptr = hw_addr+MQNIC_EVENT_QUEUE_HEAD_PTR_REG;
    ring->hw_tail_ptr = hw_addr+MQNIC_EVENT_QUEUE_TAIL_PTR_REG;

    ring->head_ptr = 0;
    ring->tail_ptr = 0;

    // deactivate queue
    iowrite32(0, ring->hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);
    // set base address
    iowrite32(ring->buf_dma_addr, ring->hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG+0);
    iowrite32(ring->buf_dma_addr >> 32, ring->hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG+4);
    // set interrupt index
    iowrite32(0, ring->hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);
    // set pointers
    iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_EVENT_QUEUE_HEAD_PTR_REG);
    iowrite32(ring->tail_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_EVENT_QUEUE_TAIL_PTR_REG);
    // set size
    iowrite32(ilog2(ring->size), ring->hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);

    *ring_ptr = ring;
    return 0;

fail_ring:
    kfree(ring);
    *ring_ptr = NULL;
    return ret;
}

void mqnic_destroy_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring **ring_ptr)
{
    struct device *dev = priv->dev;
    struct mqnic_eq_ring *ring = *ring_ptr;
    *ring_ptr = NULL;

    mqnic_deactivate_eq_ring(priv, ring);

    dma_free_coherent(dev, ring->buf_size, ring->buf, ring->buf_dma_addr);
    kfree(ring);
}

int mqnic_activate_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring *ring, int int_index)
{
    ring->int_index = int_index;

    // deactivate queue
    iowrite32(0, ring->hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);
    // set base address
    iowrite32(ring->buf_dma_addr, ring->hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG+0);
    iowrite32(ring->buf_dma_addr >> 32, ring->hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG+4);
    // set interrupt index
    iowrite32(int_index, ring->hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);
    // set pointers
    iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_EVENT_QUEUE_HEAD_PTR_REG);
    iowrite32(ring->tail_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_EVENT_QUEUE_TAIL_PTR_REG);
    // set size and activate queue
    iowrite32(ilog2(ring->size) | MQNIC_EVENT_QUEUE_ACTIVE_MASK, ring->hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);

    return 0;
}

void mqnic_deactivate_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring *ring)
{
    // deactivate queue
    iowrite32(ilog2(ring->size), ring->hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG);
    // disarm queue
    iowrite32(ring->int_index, ring->hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);
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
    iowrite32(ring->int_index | MQNIC_EVENT_QUEUE_ARM_MASK, ring->hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG);
}

void mqnic_process_eq(struct net_device *ndev, struct mqnic_eq_ring *eq_ring)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_event *event;
    u32 eq_index;
    u32 eq_tail_ptr;
    int done = 0;

    if (unlikely(!priv->port_up))
    {
        return;
    }

    // read head pointer from NIC
    mqnic_eq_read_head_ptr(eq_ring);

    eq_tail_ptr = eq_ring->tail_ptr;
    eq_index = eq_tail_ptr & eq_ring->size_mask;

    while (eq_ring->head_ptr != eq_tail_ptr)
    {
        event = (struct mqnic_event *)(eq_ring->buf + eq_index*eq_ring->stride);

        if (event->type == MQNIC_EVENT_TYPE_TX_CPL)
        {
            // transmit completion event
            if (unlikely(event->source > priv->tx_cpl_queue_count))
            {
                dev_err(priv->dev, "mqnic_process_eq on port %d: unknown event source %d (index %d, type %d)", priv->port, event->source, eq_index, event->type);
                print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1, event, MQNIC_EVENT_SIZE, true);
            }
            else
            {
                struct mqnic_cq_ring *cq_ring = priv->tx_cpl_ring[event->source];
                if (likely(cq_ring && cq_ring->handler))
                {
                    cq_ring->handler(cq_ring);
                }
            }
        }
        else if (event->type == MQNIC_EVENT_TYPE_RX_CPL)
        {
            // receive completion event
            if (unlikely(event->source > priv->rx_cpl_queue_count))
            {
                dev_err(priv->dev, "mqnic_process_eq on port %d: unknown event source %d (index %d, type %d)", priv->port, event->source, eq_index, event->type);
                print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1, event, MQNIC_EVENT_SIZE, true);
            }
            else
            {
                struct mqnic_cq_ring *cq_ring = priv->rx_cpl_ring[event->source];
                if (likely(cq_ring && cq_ring->handler))
                {
                    cq_ring->handler(cq_ring);
                }
            }
        }
        else
        {
            dev_err(priv->dev, "mqnic_process_eq on port %d: unknown event type %d (index %d, source %d)", priv->port, event->type, eq_index, event->source);
            print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1, event, MQNIC_EVENT_SIZE, true);
        }

        done++;

        eq_tail_ptr++;
        eq_index = eq_tail_ptr & eq_ring->size_mask;
    }

    // update eq tail
    eq_ring->tail_ptr = eq_tail_ptr;
    mqnic_eq_write_tail_ptr(eq_ring);
}

