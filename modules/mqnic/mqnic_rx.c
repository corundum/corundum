// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

struct mqnic_ring *mqnic_create_rx_ring(struct mqnic_if *interface)
{
	struct mqnic_ring *ring;

	ring = kzalloc(sizeof(*ring), GFP_KERNEL);
	if (!ring)
		return ERR_PTR(-ENOMEM);

	ring->dev = interface->dev;
	ring->interface = interface;

	ring->index = -1;
	ring->enabled = 0;

	ring->hw_addr = NULL;
	ring->hw_ptr_mask = 0xffff;
	ring->hw_head_ptr = NULL;
	ring->hw_tail_ptr = NULL;

	ring->head_ptr = 0;
	ring->tail_ptr = 0;

	return ring;
}

void mqnic_destroy_rx_ring(struct mqnic_ring *ring)
{
	mqnic_close_rx_ring(ring);

	kfree(ring);
}

int mqnic_open_rx_ring(struct mqnic_ring *ring, struct mqnic_priv *priv,
		struct mqnic_cq *cq, int size, int desc_block_size)
{
	int ret = 0;

	if (ring->enabled || ring->hw_addr || ring->buf || !priv || !cq)
		return -EINVAL;

	ring->index = mqnic_res_alloc(ring->interface->rxq_res);
	if (ring->index < 0)
		return -ENOMEM;

	ring->log_desc_block_size = desc_block_size < 2 ? 0 : ilog2(desc_block_size - 1) + 1;
	ring->desc_block_size = 1 << ring->log_desc_block_size;

	ring->size = roundup_pow_of_two(size);
	ring->full_size = ring->size >> 1;
	ring->size_mask = ring->size - 1;
	ring->stride = roundup_pow_of_two(MQNIC_DESC_SIZE * ring->desc_block_size);

	ring->rx_info = kvzalloc(sizeof(*ring->rx_info) * ring->size, GFP_KERNEL);
	if (!ring->rx_info) {
		ret = -ENOMEM;
		goto fail;
	}

	ring->buf_size = ring->size * ring->stride;
	ring->buf = dma_alloc_coherent(ring->dev, ring->buf_size, &ring->buf_dma_addr, GFP_KERNEL);
	if (!ring->buf) {
		ret = -ENOMEM;
		goto fail;
	}

	ring->priv = priv;
	ring->cq = cq;
	cq->src_ring = ring;
	cq->handler = mqnic_rx_irq;

	ring->hw_addr = mqnic_res_get_addr(ring->interface->rxq_res, ring->index);
	ring->hw_head_ptr = ring->hw_addr + MQNIC_QUEUE_HEAD_PTR_REG;
	ring->hw_tail_ptr = ring->hw_addr + MQNIC_QUEUE_TAIL_PTR_REG;

	ring->head_ptr = 0;
	ring->tail_ptr = 0;

	// deactivate queue
	iowrite32(0, ring->hw_addr + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);
	// set base address
	iowrite32(ring->buf_dma_addr, ring->hw_addr + MQNIC_QUEUE_BASE_ADDR_REG + 0);
	iowrite32(ring->buf_dma_addr >> 32, ring->hw_addr + MQNIC_QUEUE_BASE_ADDR_REG + 4);
	// set CQN
	iowrite32(ring->cq->cqn, ring->hw_addr + MQNIC_QUEUE_CPL_QUEUE_INDEX_REG);
	// set pointers
	iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_addr + MQNIC_QUEUE_HEAD_PTR_REG);
	iowrite32(ring->tail_ptr & ring->hw_ptr_mask, ring->hw_addr + MQNIC_QUEUE_TAIL_PTR_REG);
	// set size
	iowrite32(ilog2(ring->size) | (ring->log_desc_block_size << 8),
			ring->hw_addr + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);

	mqnic_refill_rx_buffers(ring);

	return 0;

fail:
	mqnic_close_rx_ring(ring);
	return ret;
}

void mqnic_close_rx_ring(struct mqnic_ring *ring)
{
	mqnic_disable_rx_ring(ring);

	if (ring->cq) {
		ring->cq->src_ring = NULL;
		ring->cq->handler = NULL;
	}

	ring->priv = NULL;
	ring->cq = NULL;

	ring->hw_addr = NULL;
	ring->hw_head_ptr = NULL;
	ring->hw_tail_ptr = NULL;

	if (ring->buf) {
		mqnic_free_rx_buf(ring);

		dma_free_coherent(ring->dev, ring->buf_size, ring->buf, ring->buf_dma_addr);
		ring->buf = NULL;
		ring->buf_dma_addr = 0;
	}

	if (ring->rx_info) {
		kvfree(ring->rx_info);
		ring->rx_info = NULL;
	}

	mqnic_res_free(ring->interface->rxq_res, ring->index);
	ring->index = -1;
}

int mqnic_enable_rx_ring(struct mqnic_ring *ring)
{
	if (!ring->hw_addr)
		return -EINVAL;

	// enable queue
	iowrite32(ilog2(ring->size) | (ring->log_desc_block_size << 8) | MQNIC_QUEUE_ACTIVE_MASK,
			ring->hw_addr + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);

	ring->enabled = 1;

	return 0;
}

void mqnic_disable_rx_ring(struct mqnic_ring *ring)
{
	// disable queue
	if (ring->hw_addr) {
		iowrite32(ilog2(ring->size) | (ring->log_desc_block_size << 8),
				ring->hw_addr + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);
	}

	ring->enabled = 0;
}

bool mqnic_is_rx_ring_empty(const struct mqnic_ring *ring)
{
	return ring->head_ptr == ring->tail_ptr;
}

bool mqnic_is_rx_ring_full(const struct mqnic_ring *ring)
{
	return ring->head_ptr - ring->tail_ptr >= ring->size;
}

void mqnic_rx_read_tail_ptr(struct mqnic_ring *ring)
{
	ring->tail_ptr += (ioread32(ring->hw_tail_ptr) - ring->tail_ptr) & ring->hw_ptr_mask;
}

void mqnic_rx_write_head_ptr(struct mqnic_ring *ring)
{
	iowrite32(ring->head_ptr & ring->hw_ptr_mask, ring->hw_head_ptr);
}

void mqnic_free_rx_desc(struct mqnic_ring *ring, int index)
{
	struct mqnic_rx_info *rx_info = &ring->rx_info[index];
	struct page *page = rx_info->page;

	dma_unmap_page(ring->dev, dma_unmap_addr(rx_info, dma_addr),
			dma_unmap_len(rx_info, len), DMA_FROM_DEVICE);
	rx_info->dma_addr = 0;
	__free_pages(page, rx_info->page_order);
	rx_info->page = NULL;
}

int mqnic_free_rx_buf(struct mqnic_ring *ring)
{
	u32 index;
	int cnt = 0;

	while (!mqnic_is_rx_ring_empty(ring)) {
		index = ring->tail_ptr & ring->size_mask;
		mqnic_free_rx_desc(ring, index);
		ring->tail_ptr++;
		cnt++;
	}

	return cnt;
}

int mqnic_prepare_rx_desc(struct mqnic_ring *ring, int index)
{
	struct mqnic_rx_info *rx_info = &ring->rx_info[index];
	struct mqnic_desc *rx_desc = (struct mqnic_desc *)(ring->buf + index * ring->stride);
	struct page *page = rx_info->page;
	u32 page_order = ring->page_order;
	u32 len = PAGE_SIZE << page_order;
	dma_addr_t dma_addr;

	if (unlikely(page)) {
		dev_err(ring->dev, "%s: skb not yet processed on interface %d",
				__func__, ring->interface->index);
		return -1;
	}

	page = dev_alloc_pages(page_order);
	if (unlikely(!page)) {
		dev_err(ring->dev, "%s: failed to allocate memory on interface %d",
				__func__, ring->interface->index);
		return -1;
	}

	// map page
	dma_addr = dma_map_page(ring->dev, page, 0, len, DMA_FROM_DEVICE);

	if (unlikely(dma_mapping_error(ring->dev, dma_addr))) {
		dev_err(ring->dev, "%s: DMA mapping failed on interface %d",
				__func__, ring->interface->index);
		__free_pages(page, page_order);
		return -1;
	}

	// write descriptor
	rx_desc->len = cpu_to_le32(len);
	rx_desc->addr = cpu_to_le64(dma_addr);

	// update rx_info
	rx_info->page = page;
	rx_info->page_order = page_order;
	rx_info->page_offset = 0;
	rx_info->dma_addr = dma_addr;
	rx_info->len = len;

	return 0;
}

void mqnic_refill_rx_buffers(struct mqnic_ring *ring)
{
	u32 missing = ring->size - (ring->head_ptr - ring->tail_ptr);

	if (missing < 8)
		return;

	for (; missing-- > 0;) {
		if (mqnic_prepare_rx_desc(ring, ring->head_ptr & ring->size_mask))
			break;
		ring->head_ptr++;
	}

	// enqueue on NIC
	dma_wmb();
	mqnic_rx_write_head_ptr(ring);
}

int mqnic_process_rx_cq(struct mqnic_cq *cq, int napi_budget)
{
	struct mqnic_if *interface = cq->interface;
	struct device *dev = interface->dev;
	struct mqnic_ring *rx_ring = cq->src_ring;
	struct mqnic_priv *priv = rx_ring->priv;
	struct mqnic_rx_info *rx_info;
	struct mqnic_cpl *cpl;
	struct sk_buff *skb;
	struct page *page;
	u32 cq_index;
	u32 cq_tail_ptr;
	u32 ring_index;
	u32 ring_tail_ptr;
	int done = 0;
	int budget = napi_budget;
	u32 len;

	if (unlikely(!priv || !priv->port_up))
		return done;

	// process completion queue
	cq_tail_ptr = cq->tail_ptr;
	cq_index = cq_tail_ptr & cq->size_mask;

	while (done < budget) {
		cpl = (struct mqnic_cpl *)(cq->buf + cq_index * cq->stride);

		if (!!(cpl->phase & cpu_to_le32(0x80000000)) == !!(cq_tail_ptr & cq->size))
			break;

		dma_rmb();

		ring_index = le16_to_cpu(cpl->index) & rx_ring->size_mask;
		rx_info = &rx_ring->rx_info[ring_index];
		page = rx_info->page;

		if (unlikely(!page)) {
			netdev_err(priv->ndev, "%s: ring %d null page at index %d",
					__func__, rx_ring->index, ring_index);
			print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
					cpl, MQNIC_CPL_SIZE, true);
			break;
		}

		skb = napi_get_frags(&cq->napi);
		if (unlikely(!skb)) {
			netdev_err(priv->ndev, "%s: ring %d failed to allocate skb",
					__func__, rx_ring->index);
			break;
		}

		// RX hardware timestamp
		if (interface->if_features & MQNIC_IF_FEATURE_PTP_TS)
			skb_hwtstamps(skb)->hwtstamp = mqnic_read_cpl_ts(interface->mdev, rx_ring, cpl);

		skb_record_rx_queue(skb, rx_ring->index);

		// RX hardware checksum
		if (priv->ndev->features & NETIF_F_RXCSUM) {
			skb->csum = csum_unfold((__sum16) cpu_to_be16(le16_to_cpu(cpl->rx_csum)));
			skb->ip_summed = CHECKSUM_COMPLETE;
		}

		// unmap
		dma_unmap_page(dev, dma_unmap_addr(rx_info, dma_addr),
				dma_unmap_len(rx_info, len), DMA_FROM_DEVICE);
		rx_info->dma_addr = 0;

		len = min_t(u32, le16_to_cpu(cpl->len), rx_info->len);

		dma_sync_single_range_for_cpu(dev, rx_info->dma_addr, rx_info->page_offset,
				rx_info->len, DMA_FROM_DEVICE);

		__skb_fill_page_desc(skb, 0, page, rx_info->page_offset, len);
		rx_info->page = NULL;

		skb_shinfo(skb)->nr_frags = 1;
		skb->len = len;
		skb->data_len = len;
		skb->truesize += rx_info->len;

		// hand off SKB
		napi_gro_frags(&cq->napi);

		rx_ring->packets++;
		rx_ring->bytes += le16_to_cpu(cpl->len);

		done++;

		cq_tail_ptr++;
		cq_index = cq_tail_ptr & cq->size_mask;
	}

	// update CQ tail
	cq->tail_ptr = cq_tail_ptr;
	mqnic_cq_write_tail_ptr(cq);

	// process ring
	ring_tail_ptr = READ_ONCE(rx_ring->tail_ptr);
	ring_index = ring_tail_ptr & rx_ring->size_mask;

	while (ring_tail_ptr != rx_ring->head_ptr) {
		rx_info = &rx_ring->rx_info[ring_index];

		if (rx_info->page)
			break;

		ring_tail_ptr++;
		ring_index = ring_tail_ptr & rx_ring->size_mask;
	}

	// update ring tail
	WRITE_ONCE(rx_ring->tail_ptr, ring_tail_ptr);

	// replenish buffers
	mqnic_refill_rx_buffers(rx_ring);

	return done;
}

void mqnic_rx_irq(struct mqnic_cq *cq)
{
	napi_schedule_irqoff(&cq->napi);
}

int mqnic_poll_rx_cq(struct napi_struct *napi, int budget)
{
	struct mqnic_cq *cq = container_of(napi, struct mqnic_cq, napi);
	int done;

	done = mqnic_process_rx_cq(cq, budget);

	if (done == budget)
		return done;

	napi_complete(napi);

	mqnic_arm_cq(cq);

	return done;
}
