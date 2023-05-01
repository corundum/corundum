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

int mqnic_create_interface(struct mqnic_dev *mdev, struct mqnic_if **interface_ptr,
		int index, u8 __iomem *hw_addr)
{
	struct device *dev = mdev->dev;
	struct mqnic_if *interface;
	struct mqnic_reg_block *rb;
	int ret = 0;
	int k;
	u32 desc_block_size;
	u32 val;

	interface = kzalloc(sizeof(*interface), GFP_KERNEL);
	if (!interface)
		return -ENOMEM;

	*interface_ptr = interface;

	interface->mdev = mdev;
	interface->dev = dev;

	interface->index = index;

	interface->hw_regs_size = mdev->if_stride;
	interface->hw_addr = hw_addr;
	interface->csr_hw_addr = hw_addr + mdev->if_csr_offset;

	// Enumerate registers
	interface->rb_list = mqnic_enumerate_reg_block_list(interface->hw_addr, mdev->if_csr_offset, interface->hw_regs_size);
	if (!interface->rb_list) {
		ret = -EIO;
		dev_err(dev, "Failed to enumerate blocks");
		goto fail;
	}

	dev_info(dev, "Interface-level register blocks:");
	for (rb = interface->rb_list; rb->regs; rb++)
		dev_info(dev, " type 0x%08x (v %d.%d.%d.%d)", rb->type, rb->version >> 24,
				(rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

	interface->if_ctrl_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_IF_CTRL_TYPE, MQNIC_RB_IF_CTRL_VER, 0);

	if (!interface->if_ctrl_rb) {
		ret = -EIO;
		dev_err(dev, "Interface control block not found");
		goto fail;
	}

	interface->if_features = ioread32(interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_FEATURES);
	interface->port_count = ioread32(interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_PORT_COUNT);
	interface->sched_block_count = ioread32(interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_SCHED_COUNT);
	interface->max_tx_mtu = ioread32(interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_MAX_TX_MTU);
	interface->max_rx_mtu = ioread32(interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_MAX_RX_MTU);

	dev_info(dev, "IF features: 0x%08x", interface->if_features);
	dev_info(dev, "Port count: %d", interface->port_count);
	dev_info(dev, "Scheduler block count: %d", interface->sched_block_count);
	dev_info(dev, "Max TX MTU: %d", interface->max_tx_mtu);
	dev_info(dev, "Max RX MTU: %d", interface->max_rx_mtu);

	interface->eq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_EQM_TYPE, MQNIC_RB_EQM_VER, 0);

	if (!interface->eq_rb) {
		ret = -EIO;
		dev_err(dev, "EQ block not found");
		goto fail;
	}

	interface->eq_offset = ioread32(interface->eq_rb->regs + MQNIC_RB_EQM_REG_OFFSET);
	interface->eq_count = ioread32(interface->eq_rb->regs + MQNIC_RB_EQM_REG_COUNT);
	interface->eq_stride = ioread32(interface->eq_rb->regs + MQNIC_RB_EQM_REG_STRIDE);

	dev_info(dev, "EQ offset: 0x%08x", interface->eq_offset);
	dev_info(dev, "EQ count: %d", interface->eq_count);
	dev_info(dev, "EQ stride: 0x%08x", interface->eq_stride);

	interface->eq_count = min_t(u32, interface->eq_count, MQNIC_MAX_EQ);

	interface->txq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_TX_QM_TYPE, MQNIC_RB_TX_QM_VER, 0);

	if (!interface->txq_rb) {
		ret = -EIO;
		dev_err(dev, "TXQ block not found");
		goto fail;
	}

	interface->txq_offset = ioread32(interface->txq_rb->regs + MQNIC_RB_TX_QM_REG_OFFSET);
	interface->txq_count = ioread32(interface->txq_rb->regs + MQNIC_RB_TX_QM_REG_COUNT);
	interface->txq_stride = ioread32(interface->txq_rb->regs + MQNIC_RB_TX_QM_REG_STRIDE);

	dev_info(dev, "TXQ offset: 0x%08x", interface->txq_offset);
	dev_info(dev, "TXQ count: %d", interface->txq_count);
	dev_info(dev, "TXQ stride: 0x%08x", interface->txq_stride);

	interface->txq_count = min_t(u32, interface->txq_count, MQNIC_MAX_TXQ);

	interface->tx_cq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_TX_CQM_TYPE, MQNIC_RB_TX_CQM_VER, 0);

	if (!interface->tx_cq_rb) {
		ret = -EIO;
		dev_err(dev, "TX CQ block not found");
		goto fail;
	}

	interface->tx_cq_offset = ioread32(interface->tx_cq_rb->regs + MQNIC_RB_TX_CQM_REG_OFFSET);
	interface->tx_cq_count = ioread32(interface->tx_cq_rb->regs + MQNIC_RB_TX_CQM_REG_COUNT);
	interface->tx_cq_stride = ioread32(interface->tx_cq_rb->regs + MQNIC_RB_TX_CQM_REG_STRIDE);

	dev_info(dev, "TX CQ offset: 0x%08x", interface->tx_cq_offset);
	dev_info(dev, "TX CQ count: %d", interface->tx_cq_count);
	dev_info(dev, "TX CQ stride: 0x%08x", interface->tx_cq_stride);

	interface->tx_cq_count = min_t(u32, interface->tx_cq_count, MQNIC_MAX_TX_CQ);

	interface->rxq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_QM_TYPE, MQNIC_RB_RX_QM_VER, 0);

	if (!interface->rxq_rb) {
		ret = -EIO;
		dev_err(dev, "RXQ block not found");
		goto fail;
	}

	interface->rxq_offset = ioread32(interface->rxq_rb->regs + MQNIC_RB_RX_QM_REG_OFFSET);
	interface->rxq_count = ioread32(interface->rxq_rb->regs + MQNIC_RB_RX_QM_REG_COUNT);
	interface->rxq_stride = ioread32(interface->rxq_rb->regs + MQNIC_RB_RX_QM_REG_STRIDE);

	dev_info(dev, "RXQ offset: 0x%08x", interface->rxq_offset);
	dev_info(dev, "RXQ count: %d", interface->rxq_count);
	dev_info(dev, "RXQ stride: 0x%08x", interface->rxq_stride);

	interface->rxq_count = min_t(u32, interface->rxq_count, MQNIC_MAX_RXQ);

	interface->rx_cq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_CQM_TYPE, MQNIC_RB_RX_CQM_VER, 0);

	if (!interface->rx_cq_rb) {
		ret = -EIO;
		dev_err(dev, "RX CQ block not found");
		goto fail;
	}

	interface->rx_cq_offset = ioread32(interface->rx_cq_rb->regs + MQNIC_RB_RX_CQM_REG_OFFSET);
	interface->rx_cq_count = ioread32(interface->rx_cq_rb->regs + MQNIC_RB_RX_CQM_REG_COUNT);
	interface->rx_cq_stride = ioread32(interface->rx_cq_rb->regs + MQNIC_RB_RX_CQM_REG_STRIDE);

	dev_info(dev, "RX CQ offset: 0x%08x", interface->rx_cq_offset);
	dev_info(dev, "RX CQ count: %d", interface->rx_cq_count);
	dev_info(dev, "RX CQ stride: 0x%08x", interface->rx_cq_stride);

	interface->rx_cq_count = min_t(u32, interface->rx_cq_count, MQNIC_MAX_RX_CQ);

	interface->rx_queue_map_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_QUEUE_MAP_TYPE, MQNIC_RB_RX_QUEUE_MAP_VER, 0);

	if (!interface->rx_queue_map_rb) {
		ret = -EIO;
		dev_err(dev, "RX queue map block not found");
		goto fail;
	}

	val = ioread32(interface->rx_queue_map_rb->regs + MQNIC_RB_RX_QUEUE_MAP_REG_CFG);
	interface->rx_queue_map_indir_table_size = 1 << ((val >> 8) & 0xff);

	dev_info(dev, "RX queue map indirection table size: %d", interface->rx_queue_map_indir_table_size);

	for (k = 0; k < interface->port_count; k++) {
		interface->rx_queue_map_indir_table[k] = interface->hw_addr + ioread32(interface->rx_queue_map_rb->regs +
			MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET + MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*k + MQNIC_RB_RX_QUEUE_MAP_CH_REG_OFFSET);

		mqnic_interface_set_rx_queue_map_rss_mask(interface, k, 0);
		mqnic_interface_set_rx_queue_map_app_mask(interface, k, 0);
		mqnic_interface_set_rx_queue_map_indir_table(interface, k, 0, 0);
	}

	// determine desc block size
	iowrite32(0xf << 8, hw_addr + interface->txq_offset + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);
	interface->max_desc_block_size = 1 << ((ioread32(hw_addr + interface->txq_offset + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) >> 8) & 0xf);
	iowrite32(0, hw_addr + interface->txq_offset + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);

	dev_info(dev, "Max desc block size: %d", interface->max_desc_block_size);

	interface->max_desc_block_size = min_t(u32, interface->max_desc_block_size, MQNIC_MAX_FRAGS);

	desc_block_size = min_t(u32, interface->max_desc_block_size, 4);

	// create rings
	for (k = 0; k < interface->eq_count; k++) {
		ret = mqnic_create_eq(interface, &interface->eq[k], k,
				hw_addr + interface->eq_offset + k * interface->eq_stride);
		if (ret)
			goto fail;

		ret = mqnic_alloc_eq(interface->eq[k], mqnic_num_eq_entries,
				MQNIC_EVENT_SIZE);
		if (ret)
			goto fail;

		mqnic_activate_eq(interface->eq[k], mdev->irq[k % mdev->irq_count]);
		mqnic_arm_eq(interface->eq[k]);
	}

	for (k = 0; k < interface->txq_count; k++) {
		ret = mqnic_create_tx_ring(interface, &interface->txq[k], k,
				hw_addr + interface->txq_offset + k * interface->txq_stride);
		if (ret)
			goto fail;
	}

	for (k = 0; k < interface->tx_cq_count; k++) {
		ret = mqnic_create_cq(interface, &interface->tx_cq[k], k,
				hw_addr + interface->tx_cq_offset + k * interface->tx_cq_stride);
		if (ret)
			goto fail;
	}

	for (k = 0; k < interface->rxq_count; k++) {
		ret = mqnic_create_rx_ring(interface, &interface->rxq[k], k,
				hw_addr + interface->rxq_offset + k * interface->rxq_stride);
		if (ret)
			goto fail;
	}

	for (k = 0; k < interface->rx_cq_count; k++) {
		ret = mqnic_create_cq(interface, &interface->rx_cq[k], k,
				hw_addr + interface->rx_cq_offset + k * interface->rx_cq_stride);
		if (ret)
			goto fail;
	}

	// create ports
	for (k = 0; k < interface->port_count; k++) {
		struct mqnic_reg_block *port_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_PORT_TYPE, MQNIC_RB_PORT_VER, k);

		if (!port_rb) {
			ret = -EIO;
			dev_err(dev, "Port index %d not found", k);
			goto fail;
		}

		ret = mqnic_create_port(interface, &interface->port[k],
				k, port_rb);
		if (ret)
			goto fail;
	}

	// create schedulers
	for (k = 0; k < interface->sched_block_count; k++) {
		struct mqnic_reg_block *sched_block_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_SCHED_BLOCK_TYPE, MQNIC_RB_SCHED_BLOCK_VER, k);

		if (!sched_block_rb) {
			ret = -EIO;
			dev_err(dev, "Scheduler block index %d not found", k);
			goto fail;
		}

		ret = mqnic_create_sched_block(interface, &interface->sched_block[k],
				k, sched_block_rb);
		if (ret)
			goto fail;
	}

	// create net_devices
	interface->dev_port_base = mdev->dev_port_max;
	interface->dev_port_max = mdev->dev_port_max;

	interface->ndev_count = 1;
	for (k = 0; k < interface->ndev_count; k++) {
		ret = mqnic_create_netdev(interface, &interface->ndev[k], k, interface->dev_port_max++);
		if (ret)
			goto fail;
	}

	return 0;

fail:
	mqnic_destroy_interface(interface_ptr);
	return ret;
}

void mqnic_destroy_interface(struct mqnic_if **interface_ptr)
{
	struct mqnic_if *interface = *interface_ptr;
	int k;

	// destroy associated net_devices
	for (k = 0; k < ARRAY_SIZE(interface->ndev); k++)
		if (interface->ndev[k])
			mqnic_destroy_netdev(&interface->ndev[k]);

	// free rings
	for (k = 0; k < ARRAY_SIZE(interface->eq); k++)
		if (interface->eq[k])
			mqnic_destroy_eq(&interface->eq[k]);

	for (k = 0; k < ARRAY_SIZE(interface->txq); k++)
		if (interface->txq[k])
			mqnic_destroy_tx_ring(&interface->txq[k]);

	for (k = 0; k < ARRAY_SIZE(interface->tx_cq); k++)
		if (interface->tx_cq[k])
			mqnic_destroy_cq(&interface->tx_cq[k]);

	for (k = 0; k < ARRAY_SIZE(interface->rxq); k++)
		if (interface->rxq[k])
			mqnic_destroy_rx_ring(&interface->rxq[k]);

	for (k = 0; k < ARRAY_SIZE(interface->rx_cq); k++)
		if (interface->rx_cq[k])
			mqnic_destroy_cq(&interface->rx_cq[k]);

	// free schedulers
	for (k = 0; k < ARRAY_SIZE(interface->sched_block); k++)
		if (interface->sched_block[k])
			mqnic_destroy_sched_block(&interface->sched_block[k]);

	// free ports
	for (k = 0; k < ARRAY_SIZE(interface->port); k++)
		if (interface->port[k])
			mqnic_destroy_port(&interface->port[k]);

	if (interface->rb_list)
		mqnic_free_reg_block_list(interface->rb_list);

	*interface_ptr = NULL;
	kfree(interface);
}

u32 mqnic_interface_get_tx_mtu(struct mqnic_if *interface)
{
	return ioread32(interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_TX_MTU);
}
EXPORT_SYMBOL(mqnic_interface_get_tx_mtu);

void mqnic_interface_set_tx_mtu(struct mqnic_if *interface, u32 mtu)
{
	iowrite32(mtu, interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_TX_MTU);
}
EXPORT_SYMBOL(mqnic_interface_set_tx_mtu);

u32 mqnic_interface_get_rx_mtu(struct mqnic_if *interface)
{
	return ioread32(interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_RX_MTU);
}
EXPORT_SYMBOL(mqnic_interface_get_rx_mtu);

void mqnic_interface_set_rx_mtu(struct mqnic_if *interface, u32 mtu)
{
	iowrite32(mtu, interface->if_ctrl_rb->regs + MQNIC_RB_IF_CTRL_REG_RX_MTU);
}
EXPORT_SYMBOL(mqnic_interface_set_rx_mtu);

u32 mqnic_interface_get_rx_queue_map_rss_mask(struct mqnic_if *interface, int port)
{
	return ioread32(interface->rx_queue_map_rb->regs + MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
			MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_RSS_MASK);
}
EXPORT_SYMBOL(mqnic_interface_get_rx_queue_map_rss_mask);

void mqnic_interface_set_rx_queue_map_rss_mask(struct mqnic_if *interface, int port, u32 val)
{
	iowrite32(val, interface->rx_queue_map_rb->regs + MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
			MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_RSS_MASK);
}
EXPORT_SYMBOL(mqnic_interface_set_rx_queue_map_rss_mask);

u32 mqnic_interface_get_rx_queue_map_app_mask(struct mqnic_if *interface, int port)
{
	return ioread32(interface->rx_queue_map_rb->regs + MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
			MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_APP_MASK);
}
EXPORT_SYMBOL(mqnic_interface_get_rx_queue_map_app_mask);

void mqnic_interface_set_rx_queue_map_app_mask(struct mqnic_if *interface, int port, u32 val)
{
	iowrite32(val, interface->rx_queue_map_rb->regs + MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
			MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_APP_MASK);
}
EXPORT_SYMBOL(mqnic_interface_set_rx_queue_map_app_mask);

u32 mqnic_interface_get_rx_queue_map_indir_table(struct mqnic_if *interface, int port, int index)
{
	return ioread32(interface->rx_queue_map_indir_table[port] + index*4);
}
EXPORT_SYMBOL(mqnic_interface_get_rx_queue_map_indir_table);

void mqnic_interface_set_rx_queue_map_indir_table(struct mqnic_if *interface, int port, int index, u32 val)
{
	iowrite32(val, interface->rx_queue_map_indir_table[port] + index*4);
}
EXPORT_SYMBOL(mqnic_interface_set_rx_queue_map_indir_table);
