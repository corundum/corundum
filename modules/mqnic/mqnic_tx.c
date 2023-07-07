// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include <linux/version.h>
#include "mqnic.h"

struct mqnic_ring *mqnic_create_tx_ring(struct mqnic_if *interface)
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

void mqnic_destroy_tx_ring(struct mqnic_ring *ring)
{
	mqnic_close_tx_ring(ring);

	kfree(ring);
}

int mqnic_open_tx_ring(struct mqnic_ring *ring, struct mqnic_priv *priv,
		struct mqnic_cq *cq, int size, int desc_block_size)
{
	int ret = 0;

	if (ring->enabled || ring->hw_addr || ring->buf || !priv || !cq)
		return -EINVAL;

	ring->index = mqnic_res_alloc(ring->interface->txq_res);
	if (ring->index < 0)
		return -ENOMEM;

	ring->log_desc_block_size = desc_block_size < 2 ? 0 : ilog2(desc_block_size - 1) + 1;
	ring->desc_block_size = 1 << ring->log_desc_block_size;

	ring->size = roundup_pow_of_two(size);
	ring->full_size = ring->size >> 1;
	ring->size_mask = ring->size - 1;
	ring->stride = roundup_pow_of_two(MQNIC_DESC_SIZE * ring->desc_block_size);

	ring->tx_info = kvzalloc(sizeof(*ring->tx_info) * ring->size, GFP_KERNEL);
	if (!ring->tx_info) {
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
	cq->handler = mqnic_tx_irq;

	ring->hw_addr = mqnic_res_get_addr(ring->interface->txq_res, ring->index);

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

	return 0;

fail:
	mqnic_close_tx_ring(ring);
	return ret;
}

void mqnic_close_tx_ring(struct mqnic_ring *ring)
{
	mqnic_disable_tx_ring(ring);

	if (ring->cq) {
		ring->cq->src_ring = NULL;
		ring->cq->handler = NULL;
	}

	ring->priv = NULL;
	ring->cq = NULL;

	ring->hw_addr = NULL;

	if (ring->buf) {
		mqnic_free_tx_buf(ring);

		dma_free_coherent(ring->dev, ring->buf_size, ring->buf, ring->buf_dma_addr);
		ring->buf = NULL;
		ring->buf_dma_addr = 0;
	}

	if (ring->tx_info) {
		kvfree(ring->tx_info);
		ring->tx_info = NULL;
	}

	mqnic_res_free(ring->interface->txq_res, ring->index);
	ring->index = -1;
}

int mqnic_enable_tx_ring(struct mqnic_ring *ring)
{
	if (!ring->hw_addr)
		return -EINVAL;

	// enable queue
	iowrite32(MQNIC_QUEUE_CMD_SET_ENABLE | 1,
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);

	ring->enabled = 1;

	return 0;
}

void mqnic_disable_tx_ring(struct mqnic_ring *ring)
{
	// disable queue
	if (ring->hw_addr) {
		iowrite32(MQNIC_QUEUE_CMD_SET_ENABLE | 0,
				ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
	}

	ring->enabled = 0;
}

bool mqnic_is_tx_ring_empty(const struct mqnic_ring *ring)
{
	return ring->prod_ptr == ring->cons_ptr;
}

bool mqnic_is_tx_ring_full(const struct mqnic_ring *ring)
{
	return ring->prod_ptr - ring->cons_ptr >= ring->full_size;
}

void mqnic_tx_read_cons_ptr(struct mqnic_ring *ring)
{
	ring->cons_ptr += ((ioread32(ring->hw_addr + MQNIC_QUEUE_PTR_REG) >> 16) - ring->cons_ptr) & MQNIC_QUEUE_PTR_MASK;
}

void mqnic_tx_write_prod_ptr(struct mqnic_ring *ring)
{
	iowrite32(MQNIC_QUEUE_CMD_SET_PROD_PTR | (ring->prod_ptr & MQNIC_QUEUE_PTR_MASK),
			ring->hw_addr + MQNIC_QUEUE_CTRL_STATUS_REG);
}

void mqnic_free_tx_desc(struct mqnic_ring *ring, int index, int napi_budget)
{
	struct mqnic_tx_info *tx_info = &ring->tx_info[index];
	struct sk_buff *skb = tx_info->skb;
	u32 i;

	prefetchw(&skb->users);

	dma_unmap_single(ring->dev, dma_unmap_addr(tx_info, dma_addr),
			dma_unmap_len(tx_info, len), DMA_TO_DEVICE);
	dma_unmap_addr_set(tx_info, dma_addr, 0);

	// unmap frags
	for (i = 0; i < tx_info->frag_count; i++)
		dma_unmap_page(ring->dev, tx_info->frags[i].dma_addr,
				tx_info->frags[i].len, DMA_TO_DEVICE);

	napi_consume_skb(skb, napi_budget);
	tx_info->skb = NULL;
}

int mqnic_free_tx_buf(struct mqnic_ring *ring)
{
	u32 index;
	int cnt = 0;

	while (!mqnic_is_tx_ring_empty(ring)) {
		index = ring->cons_ptr & ring->size_mask;
		mqnic_free_tx_desc(ring, index, 0);
		ring->cons_ptr++;
		cnt++;
	}

	return cnt;
}

int mqnic_process_tx_cq(struct mqnic_cq *cq, int napi_budget)
{
	struct mqnic_if *interface = cq->interface;
	struct mqnic_ring *tx_ring = cq->src_ring;
	struct mqnic_priv *priv = tx_ring->priv;
	struct mqnic_tx_info *tx_info;
	struct mqnic_cpl *cpl;
	struct skb_shared_hwtstamps hwts;
	u32 cq_index;
	u32 cq_cons_ptr;
	u32 ring_index;
	u32 ring_cons_ptr;
	u32 packets = 0;
	u32 bytes = 0;
	int done = 0;
	int budget = napi_budget;

	if (unlikely(!priv || !priv->port_up))
		return done;

	// prefetch for BQL
	netdev_txq_bql_complete_prefetchw(tx_ring->tx_queue);

	// process completion queue
	cq_cons_ptr = cq->cons_ptr;
	cq_index = cq_cons_ptr & cq->size_mask;

	while (done < budget) {
		cpl = (struct mqnic_cpl *)(cq->buf + cq_index * cq->stride);

		if (!!(cpl->phase & cpu_to_le32(0x80000000)) == !!(cq_cons_ptr & cq->size))
			break;

		dma_rmb();

		ring_index = le16_to_cpu(cpl->index) & tx_ring->size_mask;
		tx_info = &tx_ring->tx_info[ring_index];

		// TX hardware timestamp
		if (unlikely(tx_info->ts_requested)) {
			netdev_dbg(priv->ndev, "%s: TX TS requested", __func__);
			hwts.hwtstamp = mqnic_read_cpl_ts(interface->mdev, tx_ring, cpl);
			skb_tstamp_tx(tx_info->skb, &hwts);
		}
		// free TX descriptor
		mqnic_free_tx_desc(tx_ring, ring_index, napi_budget);

		packets++;
		bytes += le16_to_cpu(cpl->len);

		done++;

		cq_cons_ptr++;
		cq_index = cq_cons_ptr & cq->size_mask;
	}

	// update CQ consumer pointer
	cq->cons_ptr = cq_cons_ptr;
	mqnic_cq_write_cons_ptr(cq);

	// process ring
	ring_cons_ptr = READ_ONCE(tx_ring->cons_ptr);
	ring_index = ring_cons_ptr & tx_ring->size_mask;

	while (ring_cons_ptr != tx_ring->prod_ptr) {
		tx_info = &tx_ring->tx_info[ring_index];

		if (tx_info->skb)
			break;

		ring_cons_ptr++;
		ring_index = ring_cons_ptr & tx_ring->size_mask;
	}

	// update consumer pointer
	WRITE_ONCE(tx_ring->cons_ptr, ring_cons_ptr);

	// BQL
	//netdev_tx_completed_queue(tx_ring->tx_queue, packets, bytes);

	// wake queue if it is stopped
	if (netif_tx_queue_stopped(tx_ring->tx_queue) && !mqnic_is_tx_ring_full(tx_ring))
		netif_tx_wake_queue(tx_ring->tx_queue);

	return done;
}

void mqnic_tx_irq(struct mqnic_cq *cq)
{
	napi_schedule_irqoff(&cq->napi);
}

int mqnic_poll_tx_cq(struct napi_struct *napi, int budget)
{
	struct mqnic_cq *cq = container_of(napi, struct mqnic_cq, napi);
	int done;

	done = mqnic_process_tx_cq(cq, budget);

	if (done == budget)
		return done;

	napi_complete(napi);

	mqnic_arm_cq(cq);

	return done;
}

static bool mqnic_map_skb(struct mqnic_ring *ring, struct mqnic_tx_info *tx_info,
		struct mqnic_desc *tx_desc, struct sk_buff *skb)
{
	struct skb_shared_info *shinfo = skb_shinfo(skb);
	const skb_frag_t *frag;
	u32 i;
	u32 len;
	dma_addr_t dma_addr;

	// update tx_info
	tx_info->skb = skb;
	tx_info->frag_count = 0;

	for (i = 0; i < shinfo->nr_frags; i++) {
		frag = &shinfo->frags[i];
		len = skb_frag_size(frag);
		dma_addr = skb_frag_dma_map(ring->dev, frag, 0, len, DMA_TO_DEVICE);
		if (unlikely(dma_mapping_error(ring->dev, dma_addr)))
			// mapping failed
			goto map_error;

		// write descriptor
		tx_desc[i + 1].len = cpu_to_le32(len);
		tx_desc[i + 1].addr = cpu_to_le64(dma_addr);

		// update tx_info
		tx_info->frag_count = i + 1;
		tx_info->frags[i].len = len;
		tx_info->frags[i].dma_addr = dma_addr;
	}

	for (i = tx_info->frag_count; i < ring->desc_block_size - 1; i++) {
		tx_desc[i + 1].len = 0;
		tx_desc[i + 1].addr = 0;
	}

	// map skb
	len = skb_headlen(skb);
	dma_addr = dma_map_single(ring->dev, skb->data, len, DMA_TO_DEVICE);

	if (unlikely(dma_mapping_error(ring->dev, dma_addr)))
		// mapping failed
		goto map_error;

	// write descriptor
	tx_desc[0].len = cpu_to_le32(len);
	tx_desc[0].addr = cpu_to_le64(dma_addr);

	// update tx_info
	dma_unmap_addr_set(tx_info, dma_addr, dma_addr);
	dma_unmap_len_set(tx_info, len, len);

	return true;

map_error:
	dev_err(ring->dev, "%s: DMA mapping failed", __func__);

	// unmap frags
	for (i = 0; i < tx_info->frag_count; i++)
		dma_unmap_page(ring->dev, tx_info->frags[i].dma_addr,
				tx_info->frags[i].len, DMA_TO_DEVICE);

	// update tx_info
	tx_info->skb = NULL;
	tx_info->frag_count = 0;

	return false;
}

netdev_tx_t mqnic_start_xmit(struct sk_buff *skb, struct net_device *ndev)
{
	struct skb_shared_info *shinfo = skb_shinfo(skb);
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_ring *ring;
	struct mqnic_tx_info *tx_info;
	struct mqnic_desc *tx_desc;
	int ring_index;
	u32 index;
	bool stop_queue;
	u32 cons_ptr;

	if (unlikely(!priv->port_up))
		goto tx_drop;

	ring_index = skb_get_queue_mapping(skb);

	rcu_read_lock();
	ring = radix_tree_lookup(&priv->txq_table, ring_index);
	rcu_read_unlock();

	if (unlikely(!ring))
		// unknown TX queue
		goto tx_drop;

	cons_ptr = READ_ONCE(ring->cons_ptr);

	// prefetch for BQL
	netdev_txq_bql_enqueue_prefetchw(ring->tx_queue);

	index = ring->prod_ptr & ring->size_mask;

	tx_desc = (struct mqnic_desc *)(ring->buf + index * ring->stride);

	tx_info = &ring->tx_info[index];

	// TX hardware timestamp
	tx_info->ts_requested = 0;
	if (unlikely(priv->if_features & MQNIC_IF_FEATURE_PTP_TS && shinfo->tx_flags & SKBTX_HW_TSTAMP)) {
		netdev_dbg(ndev, "%s: TX TS requested", __func__);
		shinfo->tx_flags |= SKBTX_IN_PROGRESS;
		tx_info->ts_requested = 1;
	}

	// TX hardware checksum
	if (skb->ip_summed == CHECKSUM_PARTIAL) {
		unsigned int csum_start = skb_checksum_start_offset(skb);
		unsigned int csum_offset = skb->csum_offset;

		if (csum_start > 255 || csum_offset > 127) {
			netdev_info(ndev, "%s: Hardware checksum fallback start %d offset %d",
					__func__, csum_start, csum_offset);

			// offset out of range, fall back on software checksum
			if (skb_checksum_help(skb)) {
				// software checksumming failed
				goto tx_drop_count;
			}
			tx_desc->tx_csum_cmd = 0;
		} else {
			tx_desc->tx_csum_cmd = cpu_to_le16(0x8000 | (csum_offset << 8) | (csum_start));
		}
	} else {
		tx_desc->tx_csum_cmd = 0;
	}

	if (shinfo->nr_frags > ring->desc_block_size - 1 || (skb->data_len && skb->data_len < 32)) {
		// too many frags or very short data portion; linearize
		if (skb_linearize(skb))
			goto tx_drop_count;
	}

	// map skb
	if (!mqnic_map_skb(ring, tx_info, tx_desc, skb))
		// map failed
		goto tx_drop_count;

	// count packet
	ring->packets++;
	ring->bytes += skb->len;

	// enqueue
	ring->prod_ptr++;

	skb_tx_timestamp(skb);

	stop_queue = mqnic_is_tx_ring_full(ring);
	if (unlikely(stop_queue)) {
		netdev_dbg(ndev, "%s: TX ring %d full on port %d",
				__func__, ring_index, priv->index);
		netif_tx_stop_queue(ring->tx_queue);
	}

	// BQL
	//netdev_tx_sent_queue(ring->tx_queue, tx_info->len);
	//__netdev_tx_sent_queue(ring->tx_queue, tx_info->len, skb->xmit_more);

	// enqueue on NIC
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 2, 0)
	if (unlikely(!netdev_xmit_more() || stop_queue)) {
#else
	if (unlikely(!skb->xmit_more || stop_queue)) {
#endif
		dma_wmb();
		mqnic_tx_write_prod_ptr(ring);
	}

	// check if queue restarted
	if (unlikely(stop_queue)) {
		smp_rmb();

		cons_ptr = READ_ONCE(ring->cons_ptr);

		if (unlikely(!mqnic_is_tx_ring_full(ring)))
			netif_tx_wake_queue(ring->tx_queue);
	}

	return NETDEV_TX_OK;

tx_drop_count:
	ring->dropped_packets++;
tx_drop:
	dev_kfree_skb_any(skb);
	return NETDEV_TX_OK;
}
