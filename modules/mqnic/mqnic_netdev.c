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

static int mqnic_start_port(struct net_device *ndev)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_dev *mdev = priv->mdev;
    int k;

    dev_info(&mdev->pdev->dev, "mqnic_open on port %d", priv->port);

    // set up event queues
    for (k = 0; k < priv->event_queue_count; k++)
    {
        priv->event_ring[k]->irq = pci_irq_vector(mdev->pdev, k % mdev->msi_nvecs);
        mqnic_activate_eq_ring(priv, priv->event_ring[k], k % mdev->msi_nvecs);
        mqnic_arm_eq(priv->event_ring[k]);
    }

    // set up RX completion queues
    for (k = 0; k < priv->rx_cpl_queue_count; k++)
    {
        mqnic_activate_cq_ring(priv, priv->rx_cpl_ring[k], k % priv->event_queue_count);
        priv->rx_cpl_ring[k]->ring_index = k;
        priv->rx_cpl_ring[k]->handler = mqnic_rx_irq;

        netif_napi_add(ndev, &priv->rx_cpl_ring[k]->napi, mqnic_poll_rx_cq, NAPI_POLL_WEIGHT);
        napi_enable(&priv->rx_cpl_ring[k]->napi);

        mqnic_arm_cq(priv->rx_cpl_ring[k]);
    }

    // set up RX queues
    for (k = 0; k < priv->rx_queue_count; k++)
    {
        priv->rx_ring[k]->mtu = ndev->mtu;
        mqnic_activate_rx_ring(priv, priv->rx_ring[k], k);
    }

    // set up TX completion queues
    for (k = 0; k < priv->tx_cpl_queue_count; k++)
    {
        mqnic_activate_cq_ring(priv, priv->tx_cpl_ring[k], k % priv->event_queue_count);
        priv->tx_cpl_ring[k]->ring_index = k;
        priv->tx_cpl_ring[k]->handler = mqnic_tx_irq;

        netif_tx_napi_add(ndev, &priv->tx_cpl_ring[k]->napi, mqnic_poll_tx_cq, NAPI_POLL_WEIGHT);
        napi_enable(&priv->tx_cpl_ring[k]->napi);
        
        mqnic_arm_cq(priv->tx_cpl_ring[k]);
    }

    // set up TX queues
    for (k = 0; k < priv->tx_queue_count; k++)
    {
        mqnic_activate_tx_ring(priv, priv->tx_ring[k], k);
        priv->tx_ring[k]->tx_queue = netdev_get_tx_queue(ndev, k);
    }

    // enable first port
    mqnic_activate_port(priv->ports[0]);

    priv->port_up = true;

    netif_tx_start_all_queues(ndev);
    netif_device_attach(ndev);

    //netif_carrier_off(ndev);
    netif_carrier_on(ndev); // TODO link status monitoring

    return 0;
}

static int mqnic_stop_port(struct net_device *ndev)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_dev *mdev = priv->mdev;
    int k;

    dev_info(&mdev->pdev->dev, "mqnic_close on port %d", priv->port);

    netif_tx_lock_bh(ndev);
//    if (detach)
//        netif_device_detach(ndev);
    netif_tx_stop_all_queues(ndev);
    netif_tx_unlock_bh(ndev);

    netif_tx_disable(ndev);

    spin_lock_bh(&priv->stats_lock);
    mqnic_update_stats(ndev);
    priv->port_up = false;
    spin_unlock_bh(&priv->stats_lock);

    // disable ports
    for (k = 0; k < priv->port_count; k++)
    {
        mqnic_deactivate_port(priv->ports[k]);
    }

    // deactivate TX queues
    for (k = 0; k < priv->tx_queue_count; k++)
    {
        mqnic_deactivate_tx_ring(priv, priv->tx_ring[k]);
    }

    // deactivate TX completion queues
    for (k = 0; k < priv->tx_cpl_queue_count; k++)
    {
        mqnic_deactivate_cq_ring(priv, priv->tx_cpl_ring[k]);

        napi_disable(&priv->tx_cpl_ring[k]->napi);
        netif_napi_del(&priv->tx_cpl_ring[k]->napi);
    }

    // deactivate RX queues
    for (k = 0; k < priv->rx_queue_count; k++)
    {
        mqnic_deactivate_rx_ring(priv, priv->rx_ring[k]);
    }

    // deactivate RX completion queues
    for (k = 0; k < priv->rx_cpl_queue_count; k++)
    {
        mqnic_deactivate_cq_ring(priv, priv->rx_cpl_ring[k]);

        napi_disable(&priv->rx_cpl_ring[k]->napi);
        netif_napi_del(&priv->rx_cpl_ring[k]->napi);
    }

    // deactivate event queues
    for (k = 0; k < priv->event_queue_count; k++)
    {
        mqnic_deactivate_eq_ring(priv, priv->event_ring[k]);
    }

    msleep(10);

    // free descriptors in TX queues
    for (k = 0; k < priv->tx_queue_count; k++)
    {
        mqnic_free_tx_buf(priv, priv->tx_ring[k]);
    }

    // free descriptors in RX queues
    for (k = 0; k < priv->rx_queue_count; k++)
    {
        mqnic_free_rx_buf(priv, priv->rx_ring[k]);
    }

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
    {
        dev_err(&mdev->pdev->dev, "Failed to start port: %d", priv->port);
    }

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
    {
        dev_err(&mdev->pdev->dev, "Failed to stop port: %d", priv->port);
    }

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
    for (k = 0; k < priv->rx_queue_count; k++)
    {
        const struct mqnic_ring *ring = priv->rx_ring[k];

        packets += READ_ONCE(ring->packets);
        bytes   += READ_ONCE(ring->bytes);
    }
    ndev->stats.rx_packets = packets;
    ndev->stats.rx_bytes = bytes;

    packets = 0;
    bytes = 0;
    for (k = 0; k < priv->tx_queue_count; k++)
    {
        const struct mqnic_ring *ring = priv->tx_ring[k];

        packets += READ_ONCE(ring->packets);
        bytes   += READ_ONCE(ring->bytes);
    }
    ndev->stats.tx_packets = packets;
    ndev->stats.tx_bytes = bytes;
}

static void mqnic_get_stats64(struct net_device *ndev, struct rtnl_link_stats64 *stats)
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
    {
        return -EFAULT;
    }

    if (hwts_config.flags)
    {
        return -EINVAL;
    }

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
    {
        return -EFAULT;
    }
    else
    {
        return 0;
    }
}

static int mqnic_hwtstamp_get(struct net_device *ndev, struct ifreq *ifr)
{
    struct mqnic_priv *priv = netdev_priv(ndev);

    if (copy_to_user(ifr->ifr_data, &priv->hwts_config, sizeof(priv->hwts_config)))
    {
        return -EFAULT;
    }
    else
    {
        return 0;
    }
}

static int mqnic_change_mtu(struct net_device *ndev, int new_mtu)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_dev *mdev = priv->mdev;

    if (new_mtu < ndev->min_mtu || new_mtu > ndev->max_mtu)
    {
        dev_err(&mdev->pdev->dev, "Bad MTU: %d", new_mtu);
        return -EPERM;
    }

    dev_info(&mdev->pdev->dev, "New MTU: %d", new_mtu);

    ndev->mtu = new_mtu;

    if (netif_running(ndev))
    {
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
    .ndo_open               = mqnic_open,
    .ndo_stop               = mqnic_close,
    .ndo_start_xmit         = mqnic_start_xmit,
    .ndo_get_stats64        = mqnic_get_stats64,
    .ndo_validate_addr      = eth_validate_addr,
    .ndo_change_mtu         = mqnic_change_mtu,
    .ndo_do_ioctl           = mqnic_ioctl,
};

int mqnic_init_netdev(struct mqnic_dev *mdev, int port, u8 __iomem *hw_addr)
{
    struct device *dev = &mdev->pdev->dev;
    struct net_device *ndev;
    struct mqnic_priv *priv;
    int ret = 0;
    int k;

    ndev = alloc_etherdev_mqs(sizeof(*priv), MQNIC_MAX_TX_RINGS, MQNIC_MAX_RX_RINGS);
    if (!ndev)
    {
        return -ENOMEM;
    }

    SET_NETDEV_DEV(ndev, &mdev->pdev->dev);
    ndev->dev_port = port;

    // init private data
    priv = netdev_priv(ndev);
    memset(priv, 0, sizeof(struct mqnic_priv));

    spin_lock_init(&priv->stats_lock);

    priv->ndev = ndev;
    priv->mdev = mdev;
    priv->dev = dev;
    priv->port = port;
    priv->port_up = false;

    priv->hw_addr = hw_addr;
    priv->csr_hw_addr = hw_addr+mdev->if_csr_offset;

    // read ID registers
    priv->if_id = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_IF_ID);
    dev_info(dev, "IF ID: 0x%08x", priv->if_id);
    priv->if_features = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_IF_FEATURES);
    dev_info(dev, "IF features: 0x%08x", priv->if_features);

    priv->event_queue_count = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_EVENT_QUEUE_COUNT);
    dev_info(dev, "Event queue count: %d", priv->event_queue_count);
    priv->event_queue_offset = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_EVENT_QUEUE_OFFSET);
    dev_info(dev, "Event queue offset: 0x%08x", priv->event_queue_offset);
    priv->tx_queue_count = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_TX_QUEUE_COUNT);
    dev_info(dev, "TX queue count: %d", priv->tx_queue_count);
    priv->tx_queue_offset = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_TX_QUEUE_OFFSET);
    dev_info(dev, "TX queue offset: 0x%08x", priv->tx_queue_offset);
    priv->tx_cpl_queue_count = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_TX_CPL_QUEUE_COUNT);
    dev_info(dev, "TX completion queue count: %d", priv->tx_cpl_queue_count);
    priv->tx_cpl_queue_offset = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_TX_CPL_QUEUE_OFFSET);
    dev_info(dev, "TX completion queue offset: 0x%08x", priv->tx_cpl_queue_offset);
    priv->rx_queue_count = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_RX_QUEUE_COUNT);
    dev_info(dev, "RX queue count: %d", priv->rx_queue_count);
    priv->rx_queue_offset = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_RX_QUEUE_OFFSET);
    dev_info(dev, "RX queue offset: 0x%08x", priv->rx_queue_offset);
    priv->rx_cpl_queue_count = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_RX_CPL_QUEUE_COUNT);
    dev_info(dev, "RX completion queue count: %d", priv->rx_cpl_queue_count);
    priv->rx_cpl_queue_offset = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_RX_CPL_QUEUE_OFFSET);
    dev_info(dev, "RX completion queue offset: 0x%08x", priv->rx_cpl_queue_offset);
    priv->port_count = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_PORT_COUNT);
    dev_info(dev, "Port count: %d", priv->port_count);
    priv->port_offset = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_PORT_OFFSET);
    dev_info(dev, "Port offset: 0x%08x", priv->port_offset);
    priv->port_stride = ioread32(priv->csr_hw_addr+MQNIC_IF_REG_PORT_STRIDE);
    dev_info(dev, "Port stride: 0x%08x", priv->port_stride);

    if (priv->event_queue_count > MQNIC_MAX_EVENT_RINGS)
        priv->event_queue_count = MQNIC_MAX_EVENT_RINGS;
    if (priv->tx_queue_count > MQNIC_MAX_TX_RINGS)
        priv->tx_queue_count = MQNIC_MAX_TX_RINGS;
    if (priv->tx_cpl_queue_count > MQNIC_MAX_TX_CPL_RINGS)
        priv->tx_cpl_queue_count = MQNIC_MAX_TX_CPL_RINGS;
    if (priv->rx_queue_count > MQNIC_MAX_RX_RINGS)
        priv->rx_queue_count = MQNIC_MAX_RX_RINGS;
    if (priv->rx_cpl_queue_count > MQNIC_MAX_RX_CPL_RINGS)
        priv->rx_cpl_queue_count = MQNIC_MAX_RX_CPL_RINGS;

    if (priv->port_count > MQNIC_MAX_PORTS)
        priv->port_count = MQNIC_MAX_PORTS;

    netif_set_real_num_tx_queues(ndev, priv->tx_queue_count);
    netif_set_real_num_rx_queues(ndev, priv->rx_queue_count);

    // set MAC
    ndev->addr_len = ETH_ALEN;
    memcpy(ndev->dev_addr, mdev->base_mac, ETH_ALEN);

    if (!is_valid_ether_addr(ndev->dev_addr))
    {
        dev_warn(dev, "Bad MAC in EEPROM; using random MAC");
        eth_hw_addr_random(ndev);
    }
    else
    {
        ndev->dev_addr[ETH_ALEN-1] += port;
    }

    priv->hwts_config.flags = 0;
    priv->hwts_config.tx_type = HWTSTAMP_TX_OFF;
    priv->hwts_config.rx_filter = HWTSTAMP_FILTER_NONE;

    // allocate rings
    for (k = 0; k < priv->event_queue_count; k++)
    {
        ret = mqnic_create_eq_ring(priv, &priv->event_ring[k], 1024, MQNIC_EVENT_SIZE, k, hw_addr+priv->event_queue_offset+k*MQNIC_EVENT_QUEUE_STRIDE); // TODO configure/constant
        if (ret)
        {
            goto fail;
        }
    }

    for (k = 0; k < priv->tx_queue_count; k++)
    {
        ret = mqnic_create_tx_ring(priv, &priv->tx_ring[k], 1024, MQNIC_DESC_SIZE, k, hw_addr+priv->tx_queue_offset+k*MQNIC_QUEUE_STRIDE); // TODO configure/constant
        if (ret)
        {
            goto fail;
        }
    }

    for (k = 0; k < priv->tx_cpl_queue_count; k++)
    {
        ret = mqnic_create_cq_ring(priv, &priv->tx_cpl_ring[k], 1024, MQNIC_CPL_SIZE, k, hw_addr+priv->tx_cpl_queue_offset+k*MQNIC_CPL_QUEUE_STRIDE); // TODO configure/constant
        if (ret)
        {
            goto fail;
        }
    }

    for (k = 0; k < priv->rx_queue_count; k++)
    {
        ret = mqnic_create_rx_ring(priv, &priv->rx_ring[k], 1024, MQNIC_DESC_SIZE, k, hw_addr+priv->rx_queue_offset+k*MQNIC_QUEUE_STRIDE); // TODO configure/constant
        if (ret)
        {
            goto fail;
        }
    }

    for (k = 0; k < priv->rx_cpl_queue_count; k++)
    {
        ret = mqnic_create_cq_ring(priv, &priv->rx_cpl_ring[k], 1024, MQNIC_CPL_SIZE, k, hw_addr+priv->rx_cpl_queue_offset+k*MQNIC_CPL_QUEUE_STRIDE); // TODO configure/constant
        if (ret)
        {
            goto fail;
        }
    }

    for (k = 0; k < priv->port_count; k++)
    {
        ret = mqnic_create_port(priv, &priv->ports[k], k, hw_addr+priv->port_offset+k*priv->port_stride);
        if (ret)
        {
            goto fail;
        }

        mqnic_port_set_rss_mask(priv->ports[k], 0xffffffff);
    }

    // entry points
    ndev->netdev_ops = &mqnic_netdev_ops;
    ndev->ethtool_ops = &mqnic_ethtool_ops;

    // set up features
    ndev->hw_features = 0;

    if (priv->if_features & MQNIC_IF_FEATURE_RX_CSUM)
    {
        ndev->hw_features |= NETIF_F_RXCSUM;
    }

    if (priv->if_features & MQNIC_IF_FEATURE_TX_CSUM)
    {
        ndev->hw_features |= NETIF_F_HW_CSUM;
    }

    ndev->features = ndev->hw_features | NETIF_F_HIGHDMA;
    ndev->hw_features |= 0;

    ndev->min_mtu = ETH_MIN_MTU;
    ndev->max_mtu = 1500;

    if (priv->ports[0] && priv->ports[0]->port_mtu)
    {
        ndev->max_mtu = priv->ports[0]->port_mtu-ETH_HLEN;
    }

    netif_carrier_off(ndev);

    ret = register_netdev(ndev);
    if (ret)
    {
        dev_err(dev, "netdev registration failed on port %d", port);
        goto fail;
    }

    priv->registered = 1;

    mdev->ndev[port] = ndev;

    return 0;

fail:
    mqnic_destroy_netdev(ndev);
    return ret;
}

void mqnic_destroy_netdev(struct net_device *ndev)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_dev *mdev = priv->mdev;
    int k;

    if (priv->registered)
    {
        unregister_netdev(ndev);
    }

    mdev->ndev[priv->port] = NULL;

    // free rings
    for (k = 0; k < MQNIC_MAX_EVENT_RINGS; k++)
    {
        if (priv->event_ring[k])
        {
            mqnic_destroy_eq_ring(priv, &priv->event_ring[k]);
        }
    }

    for (k = 0; k < MQNIC_MAX_TX_RINGS; k++)
    {
        if (priv->tx_ring[k])
        {
            mqnic_destroy_tx_ring(priv, &priv->tx_ring[k]);
        }
    }

    for (k = 0; k < MQNIC_MAX_TX_CPL_RINGS; k++)
    {
        if (priv->tx_cpl_ring[k])
        {
            mqnic_destroy_cq_ring(priv, &priv->tx_cpl_ring[k]);
        }
    }

    for (k = 0; k < MQNIC_MAX_RX_RINGS; k++)
    {
        if (priv->rx_ring[k])
        {
            mqnic_destroy_rx_ring(priv, &priv->rx_ring[k]);
        }
    }

    for (k = 0; k < MQNIC_MAX_RX_CPL_RINGS; k++)
    {
        if (priv->rx_cpl_ring[k])
        {
            mqnic_destroy_cq_ring(priv, &priv->rx_cpl_ring[k]);
        }
    }

    for (k = 0; k < MQNIC_MAX_PORTS; k++)
    {
        if (priv->ports[k])
        {
            mqnic_destroy_port(priv, &priv->ports[k]);
        }
    }

    free_netdev(ndev);
}

