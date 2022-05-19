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

#include <linux/version.h>

static int mqnic_start_port(struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_dev *mdev = priv->mdev;
	int k;

	dev_info(mdev->dev, "%s on interface %d netdev %d", __func__,
			priv->interface->index, priv->index);

	// set up RX queues
	for (k = 0; k < min(priv->rx_queue_count, priv->rx_cpl_queue_count); k++) {
		// set up CQ
		mqnic_activate_cq_ring(priv->rx_cpl_ring[k],
				priv->event_ring[k % priv->event_queue_count]);

		netif_napi_add(ndev, &priv->rx_cpl_ring[k]->napi,
				mqnic_poll_rx_cq, NAPI_POLL_WEIGHT);
		napi_enable(&priv->rx_cpl_ring[k]->napi);

		mqnic_arm_cq(priv->rx_cpl_ring[k]);

		// set up queue
		priv->rx_ring[k]->mtu = ndev->mtu;
		if (ndev->mtu + ETH_HLEN <= PAGE_SIZE)
			priv->rx_ring[k]->page_order = 0;
		else
			priv->rx_ring[k]->page_order = ilog2((ndev->mtu + ETH_HLEN + PAGE_SIZE - 1) / PAGE_SIZE - 1) + 1;
		mqnic_activate_rx_ring(priv->rx_ring[k], priv, priv->rx_cpl_ring[k]);
	}

	// set up TX queues
	for (k = 0; k < min(priv->tx_queue_count, priv->tx_cpl_queue_count); k++) {
		// set up CQ
		mqnic_activate_cq_ring(priv->tx_cpl_ring[k],
				priv->event_ring[k % priv->event_queue_count]);

		netif_tx_napi_add(ndev, &priv->tx_cpl_ring[k]->napi,
				mqnic_poll_tx_cq, NAPI_POLL_WEIGHT);
		napi_enable(&priv->tx_cpl_ring[k]->napi);

		mqnic_arm_cq(priv->tx_cpl_ring[k]);

		// set up queue
		priv->tx_ring[k]->tx_queue = netdev_get_tx_queue(ndev, k);
		mqnic_activate_tx_ring(priv->tx_ring[k], priv, priv->tx_cpl_ring[k]);
	}

	// set MTU
	mqnic_interface_set_tx_mtu(priv->interface, ndev->mtu + ETH_HLEN);
	mqnic_interface_set_rx_mtu(priv->interface, ndev->mtu + ETH_HLEN);

	// configure RSS
	mqnic_interface_set_rx_queue_map_rss_mask(priv->interface, 0, rounddown_pow_of_two(priv->rx_queue_count)-1);

	// enable first scheduler
	mqnic_activate_sched_block(priv->sched_block[0]);

	priv->port_up = true;

	netif_tx_start_all_queues(ndev);
	netif_device_attach(ndev);

	if (mqnic_link_status_poll)
		mod_timer(&priv->link_status_timer,
				jiffies + msecs_to_jiffies(mqnic_link_status_poll));
	else
		netif_carrier_on(ndev);

	return 0;
}

static int mqnic_stop_port(struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_dev *mdev = priv->mdev;
	int k;

	dev_info(mdev->dev, "%s on interface %d netdev %d", __func__,
			priv->interface->index, priv->index);

	if (mqnic_link_status_poll)
		del_timer_sync(&priv->link_status_timer);

	netif_tx_lock_bh(ndev);
//	if (detach)
//		netif_device_detach(ndev);
	netif_tx_stop_all_queues(ndev);
	netif_tx_unlock_bh(ndev);

	netif_tx_disable(ndev);

	spin_lock_bh(&priv->stats_lock);
	mqnic_update_stats(ndev);
	priv->port_up = false;
	spin_unlock_bh(&priv->stats_lock);

	// disable schedulers
	for (k = 0; k < priv->sched_block_count; k++)
		mqnic_deactivate_sched_block(priv->sched_block[k]);

	// deactivate TX queues
	for (k = 0; k < min(priv->tx_queue_count, priv->tx_cpl_queue_count); k++) {
		napi_disable(&priv->tx_cpl_ring[k]->napi);

		mqnic_deactivate_tx_ring(priv->tx_ring[k]);

		mqnic_deactivate_cq_ring(priv->tx_cpl_ring[k]);

		netif_napi_del(&priv->tx_cpl_ring[k]->napi);
	}

	// deactivate RX queues
	for (k = 0; k < min(priv->rx_queue_count, priv->rx_cpl_queue_count); k++) {
		napi_disable(&priv->rx_cpl_ring[k]->napi);

		mqnic_deactivate_rx_ring(priv->rx_ring[k]);

		mqnic_deactivate_cq_ring(priv->rx_cpl_ring[k]);

		netif_napi_del(&priv->rx_cpl_ring[k]->napi);
	}

	msleep(20);

	// free descriptors in TX queues
	for (k = 0; k < priv->tx_queue_count; k++)
		mqnic_free_tx_buf(priv->tx_ring[k]);

	// free descriptors in RX queues
	for (k = 0; k < priv->rx_queue_count; k++)
		mqnic_free_rx_buf(priv->rx_ring[k]);

	netif_carrier_off(ndev);
	return 0;
}

static int mqnic_open(struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_dev *mdev = priv->mdev;
	int ret = 0;

	mutex_lock(&mdev->state_lock);

	ret = mqnic_start_port(ndev);

	if (ret)
		dev_err(mdev->dev, "Failed to start port on interface %d netdev %d: %d",
				priv->interface->index, priv->index, ret);

	mutex_unlock(&mdev->state_lock);
	return ret;
}

static int mqnic_close(struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_dev *mdev = priv->mdev;
	int ret = 0;

	mutex_lock(&mdev->state_lock);

	ret = mqnic_stop_port(ndev);

	if (ret)
		dev_err(mdev->dev, "Failed to stop port on interface %d netdev %d: %d",
				priv->interface->index, priv->index, ret);

	mutex_unlock(&mdev->state_lock);
	return ret;
}

void mqnic_update_stats(struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	unsigned long packets, bytes;
	int k;

	if (unlikely(!priv->port_up))
		return;

	packets = 0;
	bytes = 0;
	for (k = 0; k < priv->rx_queue_count; k++) {
		const struct mqnic_ring *ring = priv->rx_ring[k];

		packets += READ_ONCE(ring->packets);
		bytes += READ_ONCE(ring->bytes);
	}
	ndev->stats.rx_packets = packets;
	ndev->stats.rx_bytes = bytes;

	packets = 0;
	bytes = 0;
	for (k = 0; k < priv->tx_queue_count; k++) {
		const struct mqnic_ring *ring = priv->tx_ring[k];

		packets += READ_ONCE(ring->packets);
		bytes += READ_ONCE(ring->bytes);
	}
	ndev->stats.tx_packets = packets;
	ndev->stats.tx_bytes = bytes;
}

static void mqnic_get_stats64(struct net_device *ndev,
		struct rtnl_link_stats64 *stats)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	spin_lock_bh(&priv->stats_lock);
	mqnic_update_stats(ndev);
	netdev_stats_to_stats64(stats, &ndev->stats);
	spin_unlock_bh(&priv->stats_lock);
}

static int mqnic_hwtstamp_set(struct net_device *ndev, struct ifreq *ifr)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct hwtstamp_config hwts_config;

	if (copy_from_user(&hwts_config, ifr->ifr_data, sizeof(hwts_config)))
		return -EFAULT;

	if (hwts_config.flags)
		return -EINVAL;

	switch (hwts_config.tx_type) {
	case HWTSTAMP_TX_OFF:
	case HWTSTAMP_TX_ON:
		break;
	default:
		return -ERANGE;
	}

	switch (hwts_config.rx_filter) {
	case HWTSTAMP_FILTER_NONE:
		break;
	case HWTSTAMP_FILTER_ALL:
	case HWTSTAMP_FILTER_SOME:
	case HWTSTAMP_FILTER_PTP_V1_L4_EVENT:
	case HWTSTAMP_FILTER_PTP_V1_L4_SYNC:
	case HWTSTAMP_FILTER_PTP_V1_L4_DELAY_REQ:
	case HWTSTAMP_FILTER_PTP_V2_L4_EVENT:
	case HWTSTAMP_FILTER_PTP_V2_L4_SYNC:
	case HWTSTAMP_FILTER_PTP_V2_L4_DELAY_REQ:
	case HWTSTAMP_FILTER_PTP_V2_L2_EVENT:
	case HWTSTAMP_FILTER_PTP_V2_L2_SYNC:
	case HWTSTAMP_FILTER_PTP_V2_L2_DELAY_REQ:
	case HWTSTAMP_FILTER_PTP_V2_EVENT:
	case HWTSTAMP_FILTER_PTP_V2_SYNC:
	case HWTSTAMP_FILTER_PTP_V2_DELAY_REQ:
	case HWTSTAMP_FILTER_NTP_ALL:
		hwts_config.rx_filter = HWTSTAMP_FILTER_ALL;
		break;
	default:
		return -ERANGE;
	}

	memcpy(&priv->hwts_config, &hwts_config, sizeof(hwts_config));

	if (copy_to_user(ifr->ifr_data, &hwts_config, sizeof(hwts_config)))
		return -EFAULT;

	return 0;
}

static int mqnic_hwtstamp_get(struct net_device *ndev, struct ifreq *ifr)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	if (copy_to_user(ifr->ifr_data, &priv->hwts_config, sizeof(priv->hwts_config)))
		return -EFAULT;

	return 0;
}

static int mqnic_change_mtu(struct net_device *ndev, int new_mtu)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_dev *mdev = priv->mdev;

	if (new_mtu < ndev->min_mtu || new_mtu > ndev->max_mtu) {
		dev_err(mdev->dev, "Bad MTU: %d", new_mtu);
		return -EPERM;
	}

	dev_info(mdev->dev, "New MTU: %d", new_mtu);

	ndev->mtu = new_mtu;

	if (netif_running(ndev)) {
		mutex_lock(&mdev->state_lock);

		mqnic_stop_port(ndev);
		mqnic_start_port(ndev);

		mutex_unlock(&mdev->state_lock);
	}

	return 0;
}

static int mqnic_ioctl(struct net_device *ndev, struct ifreq *ifr, int cmd)
{
	switch (cmd) {
	case SIOCSHWTSTAMP:
		return mqnic_hwtstamp_set(ndev, ifr);
	case SIOCGHWTSTAMP:
		return mqnic_hwtstamp_get(ndev, ifr);
	default:
		return -EOPNOTSUPP;
	}
}

static const struct net_device_ops mqnic_netdev_ops = {
	.ndo_open = mqnic_open,
	.ndo_stop = mqnic_close,
	.ndo_start_xmit = mqnic_start_xmit,
	.ndo_get_stats64 = mqnic_get_stats64,
	.ndo_validate_addr = eth_validate_addr,
	.ndo_change_mtu = mqnic_change_mtu,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
	.ndo_eth_ioctl = mqnic_ioctl,
#else
	.ndo_do_ioctl = mqnic_ioctl,
#endif
};

static void mqnic_link_status_timeout(struct timer_list *timer)
{
	struct mqnic_priv *priv = from_timer(priv, timer, link_status_timer);
	struct mqnic_if *interface = priv->interface;
	int k;
	unsigned int up;

	// "combine" all TX/RX status signals of all ports of this interface
	for (k = 0, up = 0; k < interface->port_count; k++) {
		if (!(mqnic_port_get_tx_status(interface->port[k]) & 0x1))
			continue;
		if (!(mqnic_port_get_rx_status(interface->port[k]) & 0x1))
			continue;

		up++;
	}

	if (up < interface->port_count) {
		// report carrier off, as soon as a one port's TX/RX status is deasserted
		if (priv->link_status) {
			netif_carrier_off(priv->ndev);
			priv->link_status = !priv->link_status;
		}
	} else {
		// report carrier on, as soon as all ports' TX/RX status is asserted
		if (!priv->link_status) {
			netif_carrier_on(priv->ndev);
			priv->link_status = !priv->link_status;
		}
	}

	mod_timer(&priv->link_status_timer, jiffies + msecs_to_jiffies(mqnic_link_status_poll));
}

int mqnic_create_netdev(struct mqnic_if *interface, struct net_device **ndev_ptr,
		int index, int dev_port)
{
	struct mqnic_dev *mdev = interface->mdev;
	struct device *dev = interface->dev;
	struct net_device *ndev;
	struct mqnic_priv *priv;
	int ret = 0;
	int k;
	u32 desc_block_size;

	ndev = alloc_etherdev_mqs(sizeof(*priv), MQNIC_MAX_TX_RINGS, MQNIC_MAX_RX_RINGS);
	if (!ndev) {
		dev_err(dev, "Failed to allocate memory");
		return -ENOMEM;
	}

	*ndev_ptr = ndev;

	SET_NETDEV_DEV(ndev, dev);
	ndev->dev_port = dev_port;

	// init private data
	priv = netdev_priv(ndev);
	memset(priv, 0, sizeof(struct mqnic_priv));

	spin_lock_init(&priv->stats_lock);

	priv->ndev = ndev;
	priv->mdev = interface->mdev;
	priv->interface = interface;
	priv->dev = dev;
	priv->index = index;
	priv->port_up = false;

	// associate interface resources
	priv->if_features = interface->if_features;

	priv->event_queue_count = interface->event_queue_count;
	for (k = 0; k < interface->event_queue_count; k++)
		priv->event_ring[k] = interface->event_ring[k];

	priv->tx_queue_count = interface->tx_queue_count;
	for (k = 0; k < interface->tx_queue_count; k++)
		priv->tx_ring[k] = interface->tx_ring[k];

	priv->tx_cpl_queue_count = interface->tx_cpl_queue_count;
	for (k = 0; k < interface->tx_cpl_queue_count; k++)
		priv->tx_cpl_ring[k] = interface->tx_cpl_ring[k];

	priv->rx_queue_count = interface->rx_queue_count;
	for (k = 0; k < interface->rx_queue_count; k++)
		priv->rx_ring[k] = interface->rx_ring[k];

	priv->rx_cpl_queue_count = interface->rx_cpl_queue_count;
	for (k = 0; k < interface->rx_cpl_queue_count; k++)
		priv->rx_cpl_ring[k] = interface->rx_cpl_ring[k];

	priv->sched_block_count = interface->sched_block_count;
	for (k = 0; k < interface->sched_block_count; k++)
		priv->sched_block[k] = interface->sched_block[k];

	netif_set_real_num_tx_queues(ndev, priv->tx_queue_count);
	netif_set_real_num_rx_queues(ndev, priv->rx_queue_count);

	// set MAC
	ndev->addr_len = ETH_ALEN;

	if (dev_port >= mdev->mac_count) {
		dev_warn(dev, "Exhausted permanent MAC addresses; using random MAC");
		eth_hw_addr_random(ndev);
	} else {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
		eth_hw_addr_set(ndev, mdev->mac_list[dev_port]);
#else
		memcpy(ndev->dev_addr, mdev->mac_list[dev_port], ETH_ALEN);
#endif

		if (!is_valid_ether_addr(ndev->dev_addr)) {
			dev_warn(dev, "Invalid MAC address in list; using random MAC");
			eth_hw_addr_random(ndev);
		}
	}

	priv->hwts_config.flags = 0;
	priv->hwts_config.tx_type = HWTSTAMP_TX_OFF;
	priv->hwts_config.rx_filter = HWTSTAMP_FILTER_NONE;

	desc_block_size = min_t(u32, interface->max_desc_block_size, 4);

	// allocate ring buffers
	for (k = 0; k < priv->tx_queue_count; k++) {
		ret = mqnic_alloc_tx_ring(priv->tx_ring[k], mqnic_num_tx_queue_entries,
				MQNIC_DESC_SIZE * desc_block_size);
		if (ret)
			goto fail;
	}

	for (k = 0; k < priv->tx_cpl_queue_count; k++) {
		ret = mqnic_alloc_cq_ring(priv->tx_cpl_ring[k], mqnic_num_tx_queue_entries,
				MQNIC_CPL_SIZE);
		if (ret)
			goto fail;
	}

	for (k = 0; k < priv->rx_queue_count; k++) {
		ret = mqnic_alloc_rx_ring(priv->rx_ring[k], mqnic_num_rx_queue_entries,
				MQNIC_DESC_SIZE);
		if (ret)
			goto fail;
	}

	for (k = 0; k < priv->rx_cpl_queue_count; k++) {
		ret = mqnic_alloc_cq_ring(priv->rx_cpl_ring[k], mqnic_num_rx_queue_entries,
				MQNIC_CPL_SIZE);

		if (ret)
			goto fail;
	}

	// entry points
	ndev->netdev_ops = &mqnic_netdev_ops;
	ndev->ethtool_ops = &mqnic_ethtool_ops;

	// set up features
	ndev->hw_features = NETIF_F_SG;

	if (priv->if_features & MQNIC_IF_FEATURE_RX_CSUM)
		ndev->hw_features |= NETIF_F_RXCSUM;

	if (priv->if_features & MQNIC_IF_FEATURE_TX_CSUM)
		ndev->hw_features |= NETIF_F_HW_CSUM;

	ndev->features = ndev->hw_features | NETIF_F_HIGHDMA;
	ndev->hw_features |= 0;

	ndev->min_mtu = ETH_MIN_MTU;
	ndev->max_mtu = 1500;

	if (interface->max_tx_mtu && interface->max_rx_mtu)
		ndev->max_mtu = min(interface->max_tx_mtu, interface->max_rx_mtu) - ETH_HLEN;

	netif_carrier_off(ndev);
	if (mqnic_link_status_poll) {
		priv->link_status = false;
		timer_setup(&priv->link_status_timer, mqnic_link_status_timeout, 0);
	}

	ret = register_netdev(ndev);
	if (ret) {
		dev_err(dev, "netdev registration failed on interface %d netdev %d: %d",
				priv->interface->index, priv->index, ret);
		goto fail;
	}

	priv->registered = 1;

	return 0;

fail:
	mqnic_destroy_netdev(ndev_ptr);
	return ret;
}

void mqnic_destroy_netdev(struct net_device **ndev_ptr)
{
	struct net_device *ndev = *ndev_ptr;
	struct mqnic_priv *priv = netdev_priv(ndev);
	int k;

	if (priv->registered)
		unregister_netdev(ndev);

	// free rings
	for (k = 0; k < ARRAY_SIZE(priv->tx_ring); k++)
		if (priv->tx_ring[k])
			mqnic_free_tx_ring(priv->tx_ring[k]);

	for (k = 0; k < ARRAY_SIZE(priv->tx_cpl_ring); k++)
		if (priv->tx_cpl_ring[k])
			mqnic_free_cq_ring(priv->tx_cpl_ring[k]);

	for (k = 0; k < ARRAY_SIZE(priv->rx_ring); k++)
		if (priv->rx_ring[k])
			mqnic_free_rx_ring(priv->rx_ring[k]);

	for (k = 0; k < ARRAY_SIZE(priv->rx_cpl_ring); k++)
		if (priv->rx_cpl_ring[k])
			mqnic_free_cq_ring(priv->rx_cpl_ring[k]);

	*ndev_ptr = NULL;
	free_netdev(ndev);
}
