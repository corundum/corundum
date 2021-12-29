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
	int ret = 0;
	int k;
	u32 desc_block_size;

	interface = kzalloc(sizeof(*interface), GFP_KERNEL);
	if (!interface)
		return -ENOMEM;

	interface->mdev = mdev;
	interface->dev = dev;

	interface->index = index;

	interface->hw_addr = hw_addr;
	interface->csr_hw_addr = hw_addr + mdev->if_csr_offset;

	// read ID registers
	interface->if_id = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_IF_ID);
	dev_info(dev, "IF ID: 0x%08x", interface->if_id);
	interface->if_features = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_IF_FEATURES);
	dev_info(dev, "IF features: 0x%08x", interface->if_features);

	interface->event_queue_count = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_EVENT_QUEUE_COUNT);
	dev_info(dev, "Event queue count: %d", interface->event_queue_count);
	interface->event_queue_offset = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_EVENT_QUEUE_OFFSET);
	dev_info(dev, "Event queue offset: 0x%08x", interface->event_queue_offset);

	interface->event_queue_count = min_t(u32, interface->event_queue_count, MQNIC_MAX_EVENT_RINGS);

	interface->tx_queue_count = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_TX_QUEUE_COUNT);
	dev_info(dev, "TX queue count: %d", interface->tx_queue_count);
	interface->tx_queue_offset = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_TX_QUEUE_OFFSET);
	dev_info(dev, "TX queue offset: 0x%08x", interface->tx_queue_offset);

	interface->tx_queue_count = min_t(u32, interface->tx_queue_count, MQNIC_MAX_TX_RINGS);

	interface->tx_cpl_queue_count = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_TX_CPL_QUEUE_COUNT);
	dev_info(dev, "TX completion queue count: %d", interface->tx_cpl_queue_count);
	interface->tx_cpl_queue_offset = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_TX_CPL_QUEUE_OFFSET);
	dev_info(dev, "TX completion queue offset: 0x%08x", interface->tx_cpl_queue_offset);

	interface->tx_cpl_queue_count = min_t(u32, interface->tx_cpl_queue_count, MQNIC_MAX_TX_CPL_RINGS);

	interface->rx_queue_count = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_RX_QUEUE_COUNT);
	dev_info(dev, "RX queue count: %d", interface->rx_queue_count);
	interface->rx_queue_offset = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_RX_QUEUE_OFFSET);
	dev_info(dev, "RX queue offset: 0x%08x", interface->rx_queue_offset);

	interface->rx_queue_count = min_t(u32, interface->rx_queue_count, MQNIC_MAX_RX_RINGS);

	interface->rx_cpl_queue_count = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_RX_CPL_QUEUE_COUNT);
	dev_info(dev, "RX completion queue count: %d", interface->rx_cpl_queue_count);
	interface->rx_cpl_queue_offset = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_RX_CPL_QUEUE_OFFSET);
	dev_info(dev, "RX completion queue offset: 0x%08x", interface->rx_cpl_queue_offset);

	interface->rx_cpl_queue_count = min_t(u32, interface->rx_cpl_queue_count, MQNIC_MAX_RX_CPL_RINGS);

	interface->port_count = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_PORT_COUNT);
	dev_info(dev, "Port count: %d", interface->port_count);
	interface->port_offset = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_PORT_OFFSET);
	dev_info(dev, "Port offset: 0x%08x", interface->port_offset);
	interface->port_stride = ioread32(interface->csr_hw_addr + MQNIC_IF_REG_PORT_STRIDE);
	dev_info(dev, "Port stride: 0x%08x", interface->port_stride);

	interface->port_count = min_t(u32, interface->port_count, MQNIC_MAX_PORTS);

	// determine desc block size
	iowrite32(0xf << 8, hw_addr + interface->tx_queue_offset + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);
	interface->max_desc_block_size = 1 << ((ioread32(hw_addr + interface->tx_queue_offset + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) >> 8) & 0xf);
	iowrite32(0, hw_addr + interface->tx_queue_offset + MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG);

	dev_info(dev, "Max desc block size: %d", interface->max_desc_block_size);

	interface->max_desc_block_size = min_t(u32, interface->max_desc_block_size, MQNIC_MAX_FRAGS);

	desc_block_size = min_t(u32, interface->max_desc_block_size, 4);

	*interface_ptr = interface;

	// create rings
	for (k = 0; k < interface->event_queue_count; k++) {
		ret = mqnic_create_eq_ring(interface, &interface->event_ring[k], k,
				hw_addr + interface->event_queue_offset + k * MQNIC_EVENT_QUEUE_STRIDE);
		if (ret)
			goto fail;

		ret = mqnic_alloc_eq_ring(interface->event_ring[k], mqnic_num_ev_queue_entries,
				MQNIC_EVENT_SIZE);
		if (ret)
			goto fail;

		mqnic_activate_eq_ring(interface->event_ring[k], mdev->irq[k % mdev->irq_count]);
		mqnic_arm_eq(interface->event_ring[k]);
	}

	for (k = 0; k < interface->tx_queue_count; k++) {
		ret = mqnic_create_tx_ring(interface, &interface->tx_ring[k], k,
				hw_addr + interface->tx_queue_offset + k * MQNIC_QUEUE_STRIDE);
		if (ret)
			goto fail;
	}

	for (k = 0; k < interface->tx_cpl_queue_count; k++) {
		ret = mqnic_create_cq_ring(interface, &interface->tx_cpl_ring[k], k,
				hw_addr + interface->tx_cpl_queue_offset + k * MQNIC_CPL_QUEUE_STRIDE);
		if (ret)
			goto fail;
	}

	for (k = 0; k < interface->rx_queue_count; k++) {
		ret = mqnic_create_rx_ring(interface, &interface->rx_ring[k], k,
				hw_addr + interface->rx_queue_offset + k * MQNIC_QUEUE_STRIDE);
		if (ret)
			goto fail;
	}

	for (k = 0; k < interface->rx_cpl_queue_count; k++) {
		ret = mqnic_create_cq_ring(interface, &interface->rx_cpl_ring[k], k,
				hw_addr + interface->rx_cpl_queue_offset + k * MQNIC_CPL_QUEUE_STRIDE);
		if (ret)
			goto fail;
	}

	// create ports
	for (k = 0; k < interface->port_count; k++) {
		ret = mqnic_create_port(interface, &interface->port[k], k,
				hw_addr + interface->port_offset + k * interface->port_stride);
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
	for (k = 0; k < ARRAY_SIZE(interface->event_ring); k++)
		if (interface->event_ring[k])
			mqnic_destroy_eq_ring(&interface->event_ring[k]);

	for (k = 0; k < ARRAY_SIZE(interface->tx_ring); k++)
		if (interface->tx_ring[k])
			mqnic_destroy_tx_ring(&interface->tx_ring[k]);

	for (k = 0; k < ARRAY_SIZE(interface->tx_cpl_ring); k++)
		if (interface->tx_cpl_ring[k])
			mqnic_destroy_cq_ring(&interface->tx_cpl_ring[k]);

	for (k = 0; k < ARRAY_SIZE(interface->rx_ring); k++)
		if (interface->rx_ring[k])
			mqnic_destroy_rx_ring(&interface->rx_ring[k]);

	for (k = 0; k < ARRAY_SIZE(interface->rx_cpl_ring); k++)
		if (interface->rx_cpl_ring[k])
			mqnic_destroy_cq_ring(&interface->rx_cpl_ring[k]);

	// free ports
	for (k = 0; k < ARRAY_SIZE(interface->port); k++)
		if (interface->port[k])
			mqnic_destroy_port(&interface->port[k]);

	*interface_ptr = NULL;
	kfree(interface);
}
