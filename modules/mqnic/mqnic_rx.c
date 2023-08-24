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

	ring->prod_ptr = 0;
	ring->cons_ptr = 0;

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

	ring->prod_ptr = 0;
	ring->cons_ptr = 0;

	// deactivate queue
	iowrite32(MQNIC_QUEUE_CMD_SET_ENABLE | 0,
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
	// set base address
	iowrite32((ring->buf_dma_addr & 0xfffff000),
			ring->hw_addr + MQNIC_QUEUE_BASE_ADDR_VF_REG + 0);
	iowrite32(ring->buf_dma_addr >> 32,
			ring->hw_addr + MQNIC_QUEUE_BASE_ADDR_VF_REG + 4);
	// set size
	iowrite32(MQNIC_QUEUE_CMD_SET_SIZE | ilog2(ring->size) | (ring->log_desc_block_size << 8),
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
	// set CQN
	iowrite32(MQNIC_QUEUE_CMD_SET_CQN | ring->cq->cqn,
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
	// set pointers
	iowrite32(MQNIC_QUEUE_CMD_SET_PROD_PTR | (ring->prod_ptr & MQNIC_QUEUE_PTR_MASK),
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
	iowrite32(MQNIC_QUEUE_CMD_SET_CONS_PTR | (ring->cons_ptr & MQNIC_QUEUE_PTR_MASK),
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);

	ret = mqnic_refill_rx_buffers(ring);
	if (ret) {
		netdev_err(priv->ndev, "failed to allocate RX buffer for RX queue index %d (of %u total) entry index %u (of %u total)",
				ring->index, priv->rxq_count, ring->prod_ptr, ring->size);
		if (ret == -ENOMEM)
			netdev_err(priv->ndev, "machine might not have enough DMA-capable RAM; try to decrease number of RX channels (currently %u) and/or RX ring parameters (entries; currently %u) and/or module parameter \"num_rxq_entries\" (currently %u)",
					priv->rxq_count, ring->size, mqnic_num_rxq_entries);

		goto fail;
	}

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
	iowrite32(MQNIC_QUEUE_CMD_SET_ENABLE | 1,
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);

	ring->enabled = 1;

	return 0;
}

void mqnic_disable_rx_ring(struct mqnic_ring *ring)
{
	// disable queue
	if (ring->hw_addr) {
		iowrite32(MQNIC_QUEUE_CMD_SET_ENABLE | 0,
				ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
	}

	ring->enabled = 0;
}

bool mqnic_is_rx_ring_empty(const struct mqnic_ring *ring)
{
	return ring->prod_ptr == ring->cons_ptr;
}

bool mqnic_is_rx_ring_full(const struct mqnic_ring *ring)
{
	return ring->prod_ptr - ring->cons_ptr >= ring->size;
}

void mqnic_rx_read_cons_ptr(struct mqnic_ring *ring)
{
	ring->cons_ptr += ((ioread32(ring->hw_addr + MQNIC_QUEUE_PTR_REG) >> 16) - ring->cons_ptr) & MQNIC_QUEUE_PTR_MASK;
}

void mqnic_rx_write_prod_ptr(struct mqnic_ring *ring)
{
	iowrite32(MQNIC_QUEUE_CMD_SET_PROD_PTR | (ring->prod_ptr & MQNIC_QUEUE_PTR_MASK),
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
}

void mqnic_free_rx_desc(struct mqnic_ring *ring, int index)
{
	struct mqnic_rx_info *rx_info = &ring->rx_info[index];
	// struct page *page = rx_info->page;

	if (!rx_info->page)
		return;

	dma_unmap_page(ring->dev, dma_unmap_addr(rx_info, dma_addr),
			dma_unmap_len(rx_info, len), DMA_FROM_DEVICE);
	rx_info->dma_addr = 0;
	__free_pages(rx_info->page, rx_info->page_order);
	rx_info->page = NULL;
}

int mqnic_free_rx_buf(struct mqnic_ring *ring)
{
	u32 index;
	int cnt = 0;

	while (!mqnic_is_rx_ring_empty(ring)) {
		index = ring->cons_ptr & ring->size_mask;
		mqnic_free_rx_desc(ring, index);
		ring->cons_ptr++;
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
		return -ENOMEM;
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

int mqnic_refill_rx_buffers(struct mqnic_ring *ring)
{
	u32 missing = ring->size - (ring->prod_ptr - ring->cons_ptr);
	int ret = 0;

	if (missing < 8)
		return 0;

	for (; missing-- > 0;) {
		ret = mqnic_prepare_rx_desc(ring, ring->prod_ptr & ring->size_mask);
		if (ret)
			break;
		ring->prod_ptr++;
	}

	// enqueue on NIC
	dma_wmb();
	mqnic_rx_write_prod_ptr(ring);

	return ret;
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
	u32 cq_cons_ptr;
	u32 ring_index;
	u32 ring_cons_ptr;
	int done = 0;
	int budget = napi_budget;
	u32 len;

	if (unlikely(!priv || !priv->port_up))
		return done;

	// process completion queue
	cq_cons_ptr = cq->cons_ptr;
	cq_index = cq_cons_ptr & cq->size_mask;

	while (done < budget) {
		cpl = (struct mqnic_cpl *)(cq->buf + cq_index * cq->stride);

		if (!!(cpl->phase & cpu_to_le32(0x80000000)) == !!(cq_cons_ptr & cq->size))
			break;

		dma_rmb();

		ring_index = le16_to_cpu(cpl->index) & rx_ring->size_mask;
		rx_info = &rx_ring->rx_info[ring_index];
		page = rx_info->page;
		len = min_t(u32, le16_to_cpu(cpl->len), rx_info->len);

		if (len < ETH_HLEN) {
			netdev_warn(priv->ndev, "%s: ring %d dropping short frame (length %d)",
					__func__, rx_ring->index, len);
			rx_ring->dropped_packets++;
			goto rx_drop;
		}

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

rx_drop:
		done++;

		cq_cons_ptr++;
		cq_index = cq_cons_ptr & cq->size_mask;
	}

	// update CQ consumer pointer
	cq->cons_ptr = cq_cons_ptr;
	mqnic_cq_write_cons_ptr(cq);

	// process ring
	ring_cons_ptr = READ_ONCE(rx_ring->cons_ptr);
	ring_index = ring_cons_ptr & rx_ring->size_mask;

	while (ring_cons_ptr != rx_ring->prod_ptr) {
		rx_info = &rx_ring->rx_info[ring_index];

		if (rx_info->page)
			break;

		ring_cons_ptr++;
		ring_index = ring_cons_ptr & rx_ring->size_mask;
	}

	// update consumer pointer
	WRITE_ONCE(rx_ring->cons_ptr, ring_cons_ptr);

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
