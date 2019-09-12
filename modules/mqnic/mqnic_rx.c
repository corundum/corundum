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

int mqnic_create_rx_ring(struct mqnic_priv *priv, struct mqnic_ring **ring_ptr, int size, int stride, int index, u8 __iomem *hw_addr)
{
    struct device *dev = priv->dev;
    struct mqnic_ring *ring;
    int ret;

    ring = kzalloc(sizeof(*ring), GFP_KERNEL);
    if (!ring)
    {
        dev_err(dev, "Failed to allocate RX ring");
        return -ENOMEM;
    }

    ring->size = roundup_pow_of_two(size);
    ring->size_mask = ring->size-1;
    ring->stride = roundup_pow_of_two(stride);

    ring->rx_info = kvzalloc(sizeof(*ring->rx_info)*ring->size, GFP_KERNEL);
    if (!ring->rx_info)
    {
        dev_err(dev, "Failed to allocate rx_info");
        ret = -ENOMEM;
        goto fail_ring;
    }

    ring->buf_size = ring->size*ring->stride;
    ring->buf = dma_alloc_coherent(dev, ring->buf_size, &ring->buf_dma_addr, GFP_KERNEL);
    if (!ring->buf)
    {
        dev_err(dev, "Failed to allocate RX ring DMA buffer");
        ret = -ENOMEM;
        goto fail_info;
    }

    ring->hw_addr = hw_addr;
    ring->hw_ptr_mask = 0xffff;
    ring->hw_head_ptr = hw_addr+MQNIC_QUEUE_HEAD_PTR_REG;
    ring->hw_tail_ptr = hw_addr+MQNIC_QUEUE_TAIL_PTR_REG;

    ring->head_ptr = 0;
    ring->tail_ptr = 0;
    ring->clean_tail_ptr = 0;

    // deactivate queue
    iowrite32(0, ring->hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);
    // set base address
    iowrite32(ring->buf_dma_addr, ring->hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+0);
    iowrite32(ring->buf_dma_addr >> 32, ring->hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+4);
    // set completion queue index
    iowrite32(0, ring->hw_addr+MQNIC_QUEUE_CPL_QUEUE_INDEX_REG);
    // set pointers
    iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_QUEUE_HEAD_PTR_REG);
    iowrite32(ring->tail_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_QUEUE_TAIL_PTR_REG);
    // set size
    iowrite32(ilog2(ring->size), ring->hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);

    *ring_ptr = ring;
    return 0;

fail_info:
    kvfree(ring->rx_info);
    ring->rx_info = NULL;
fail_ring:
    kfree(ring);
    *ring_ptr = NULL;
    return ret;
}

void mqnic_destroy_rx_ring(struct mqnic_priv *priv, struct mqnic_ring **ring_ptr)
{
    struct device *dev = priv->dev;
    struct mqnic_ring *ring = *ring_ptr;
    *ring_ptr = NULL;

    mqnic_deactivate_rx_ring(priv, ring);

    mqnic_free_rx_buf(priv, ring);

    dma_free_coherent(dev, ring->buf_size, ring->buf, ring->buf_dma_addr);
    kvfree(ring->rx_info);
    ring->rx_info = NULL;
    kfree(ring);
}

int mqnic_activate_rx_ring(struct mqnic_priv *priv, struct mqnic_ring *ring, int cpl_index)
{
    // deactivate queue
    iowrite32(0, ring->hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);
    // set base address
    iowrite32(ring->buf_dma_addr, ring->hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+0);
    iowrite32(ring->buf_dma_addr >> 32, ring->hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+4);
    // set completion queue index
    iowrite32(cpl_index, ring->hw_addr+MQNIC_QUEUE_CPL_QUEUE_INDEX_REG);
    // set pointers
    iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_QUEUE_HEAD_PTR_REG);
    iowrite32(ring->tail_ptr & ring->hw_ptr_mask, ring->hw_addr+MQNIC_QUEUE_TAIL_PTR_REG);
    // set size and activate queue
    iowrite32(ilog2(ring->size) | MQNIC_QUEUE_ACTIVE_MASK, ring->hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);

    mqnic_refill_rx_buffers(priv, ring);

    return 0;
}

void mqnic_deactivate_rx_ring(struct mqnic_priv *priv, struct mqnic_ring *ring)
{
    // deactivate queue
    iowrite32(ilog2(ring->size), ring->hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);
}

bool mqnic_is_rx_ring_empty(const struct mqnic_ring *ring)
{
    return ring->head_ptr == ring->clean_tail_ptr;
}

bool mqnic_is_rx_ring_full(const struct mqnic_ring *ring)
{
    return ring->head_ptr - ring->clean_tail_ptr >= ring->size;
}

void mqnic_rx_read_tail_ptr(struct mqnic_ring *ring)
{
    ring->tail_ptr += (ioread32(ring->hw_tail_ptr) - ring->tail_ptr) & ring->hw_ptr_mask;
}

void mqnic_rx_write_head_ptr(struct mqnic_ring *ring)
{
    iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_head_ptr);
}

void mqnic_free_rx_desc(struct mqnic_priv *priv, struct mqnic_ring *ring, int index)
{
    struct mqnic_rx_info *rx_info = &ring->rx_info[index];

    dma_unmap_single(priv->dev, rx_info->dma_addr, rx_info->len, PCI_DMA_FROMDEVICE);
    rx_info->dma_addr = 0;
    napi_consume_skb(rx_info->skb, 0);
    rx_info->skb = NULL;
}

int mqnic_free_rx_buf(struct mqnic_priv *priv, struct mqnic_ring *ring)
{
    u32 index;
    int cnt = 0;

    while (!mqnic_is_rx_ring_empty(ring))
    {
        index = ring->clean_tail_ptr & ring->size_mask;
        mqnic_free_rx_desc(priv, ring, index);
        ring->clean_tail_ptr++;
        cnt++;
    }

    return cnt;
}

int mqnic_prepare_rx_desc(struct mqnic_priv *priv, struct mqnic_ring *ring, int index)
{
    struct mqnic_rx_info *rx_info = &ring->rx_info[index];
    struct mqnic_desc *rx_desc = (struct mqnic_desc *)(ring->buf + index * sizeof(*rx_desc));
    struct sk_buff *skb = rx_info->skb;

    rx_info->len = 2048;

    if (skb)
    {
        // skb has not been processed yet
        return -1;
    }

    skb = __netdev_alloc_skb_ip_align(priv->ndev, 2048, GFP_ATOMIC);
    if (!skb)
    {
        dev_err(&priv->mdev->pdev->dev, "mqnic_prepare_rx_desc failed to allocate skb on port %d", priv->port);
        return -1;
    }

    rx_info->skb = skb;

map_skb:
    // map skb
    rx_info->dma_addr = dma_map_single(priv->dev, skb->data, rx_info->len, PCI_DMA_FROMDEVICE);

    if (unlikely(dma_mapping_error(priv->dev, rx_info->dma_addr)))
    {
        dev_err(&priv->mdev->pdev->dev, "mqnic_prepare_rx_desc failed to map skb on port %d", priv->port);
        napi_consume_skb(rx_info->skb, 0);
        return -1;
    }

    // write descriptor
    rx_desc->len = rx_info->len;
    rx_desc->addr = rx_info->dma_addr;

    return 0;
}

void mqnic_refill_rx_buffers(struct mqnic_priv *priv, struct mqnic_ring *ring)
{
    u32 missing = ring->size - (ring->head_ptr - ring->clean_tail_ptr);

    if (missing < 8)
        return;

    for ( ; missing-- > 0; )
    {
        if (mqnic_prepare_rx_desc(priv, ring, ring->head_ptr & ring->size_mask))
            break;
        ring->head_ptr++;
    }

    // enqueue on NIC
    dma_wmb();
    mqnic_rx_write_head_ptr(ring);
}

bool mqnic_process_rx_cq(struct net_device *ndev, struct mqnic_cq_ring *cq_ring, int napi_budget)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_ring *ring = priv->rx_ring[cq_ring->ring_index];
    struct mqnic_rx_info *rx_info;
    struct mqnic_cpl *cpl;
    struct sk_buff *skb;
    u32 cq_index;
    u32 cq_tail_ptr;
    u32 ring_index;
    u32 ring_clean_tail_ptr;
    int done = 0;
    int budget = napi_budget;

    if (unlikely(!priv->port_up))
    {
        return true;
    }

    // process completion queue
    // read head pointer from NIC
    mqnic_cq_read_head_ptr(cq_ring);

    cq_tail_ptr = cq_ring->tail_ptr;
    cq_index = cq_tail_ptr & cq_ring->size_mask;

    mb(); // is a barrier here necessary?  If so, what kind?

    while (cq_ring->head_ptr != cq_tail_ptr && done < budget)
    {
        cpl = (struct mqnic_cpl *)(cq_ring->buf + cq_index * MQNIC_CPL_SIZE);
        ring_index = cpl->index & ring->size_mask;
        rx_info = &ring->rx_info[ring_index];
        skb = rx_info->skb;

        // set length
        if (cpl->len <= rx_info->len)
        {
            skb_put(skb, cpl->len);
        }
        skb->protocol = eth_type_trans(skb, priv->ndev);

        // RX hardware timestamp
        if (priv->if_features & MQNIC_IF_FEATURE_PTP_TS)
        {
            skb_hwtstamps(skb)->hwtstamp = mqnic_read_cpl_ts(priv->mdev, ring, cpl);
        }

        skb_record_rx_queue(skb, cq_ring->ring_index);

        // RX hardware checksum
        if ((ndev->features & NETIF_F_RXCSUM) &&
            (skb->protocol == htons(ETH_P_IP) || skb->protocol == htons(ETH_P_IPV6)) &&
            (skb->len >= 64)) {

            skb->csum = be16_to_cpu(cpl->rx_csum);
            skb->ip_summed = CHECKSUM_COMPLETE;
        }

        // unmap
        dma_unmap_single(priv->dev, rx_info->dma_addr, rx_info->len, PCI_DMA_FROMDEVICE);
        rx_info->dma_addr = 0;

        // hand off SKB
        napi_gro_receive(&cq_ring->napi, skb);
        rx_info->skb = NULL;

        ring->packets++;
        ring->bytes += cpl->len;

        done++;

        cq_tail_ptr++;
        cq_index = cq_tail_ptr & cq_ring->size_mask;
    }

    // update CQ tail
    cq_ring->tail_ptr = cq_tail_ptr;
    mqnic_cq_write_tail_ptr(cq_ring);

    // process ring
    // read tail pointer from NIC
    mqnic_rx_read_tail_ptr(ring);

    ring_clean_tail_ptr = READ_ONCE(ring->clean_tail_ptr);
    ring_index = ring_clean_tail_ptr & ring->size_mask;

    while (ring_clean_tail_ptr != ring->tail_ptr)
    {
        rx_info = &ring->rx_info[ring_index];

        if (rx_info->skb)
            break;

        ring_clean_tail_ptr++;
        ring_index = ring_clean_tail_ptr & ring->size_mask;
    }

    // update ring tail
    WRITE_ONCE(ring->clean_tail_ptr, ring_clean_tail_ptr);

    // replenish buffers
    mqnic_refill_rx_buffers(priv, ring);

    return done < budget;
}

void mqnic_rx_irq(struct mqnic_cq_ring *cq)
{
    struct mqnic_priv *priv = netdev_priv(cq->ndev);

    if (likely(priv->port_up))
    {
        napi_schedule_irqoff(&cq->napi);
    }
    else
    {
        mqnic_arm_cq(cq);
    }
}

int mqnic_poll_rx_cq(struct napi_struct *napi, int budget)
{
    struct mqnic_cq_ring *cq_ring = container_of(napi, struct mqnic_cq_ring, napi);
    struct net_device *ndev = cq_ring->ndev;

    if (!mqnic_process_rx_cq(ndev, cq_ring, budget))
    {
       return budget;
    }

    napi_complete(napi);

    mqnic_arm_cq(cq_ring);

    return 0;
}

