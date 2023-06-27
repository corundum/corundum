// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <linux/ethtool.h>
#include <linux/version.h>

#define SFF_MODULE_ID_SFP        0x03
#define SFF_MODULE_ID_QSFP       0x0c
#define SFF_MODULE_ID_QSFP_PLUS  0x0d
#define SFF_MODULE_ID_QSFP28     0x11

static void mqnic_get_drvinfo(struct net_device *ndev,
		struct ethtool_drvinfo *drvinfo)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_dev *mdev = priv->mdev;

	strscpy(drvinfo->driver, DRIVER_NAME, sizeof(drvinfo->driver));
	strscpy(drvinfo->version, DRIVER_VERSION, sizeof(drvinfo->version));

	snprintf(drvinfo->fw_version, sizeof(drvinfo->fw_version), "%d.%d.%d.%d",
			mdev->fw_ver >> 24, (mdev->fw_ver >> 16) & 0xff,
			(mdev->fw_ver >> 8) & 0xff, mdev->fw_ver & 0xff);
	strscpy(drvinfo->bus_info, dev_name(mdev->dev), sizeof(drvinfo->bus_info));

	drvinfo->regdump_len = priv->mdev->hw_regs_size;
}

static int mqnic_get_regs_len(struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	return priv->mdev->hw_regs_size;
}

static void mqnic_get_regs(struct net_device *ndev,
		struct ethtool_regs *regs, void *p)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	u32 *out = p;
	int k;

	for (k = 0; k < priv->mdev->hw_regs_size/4; k ++)
		out[k] = ioread32(priv->mdev->hw_addr + k*4);
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 17, 0)
static void mqnic_get_ringparam(struct net_device *ndev,
		struct ethtool_ringparam *param,
		struct kernel_ethtool_ringparam *kernel_param,
		struct netlink_ext_ack *ext_ack)
#else
static void mqnic_get_ringparam(struct net_device *ndev,
		struct ethtool_ringparam *param)
#endif
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	param->rx_max_pending = MQNIC_MAX_RX_RING_SZ;
	param->tx_max_pending = MQNIC_MAX_TX_RING_SZ;

	param->rx_pending = priv->rx_ring_size;
	param->tx_pending = priv->tx_ring_size;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 17, 0)
	kernel_param->cqe_size = MQNIC_CPL_SIZE;
#endif
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 17, 0)
static int mqnic_set_ringparam(struct net_device *ndev,
		struct ethtool_ringparam *param,
		struct kernel_ethtool_ringparam *kernel_param,
		struct netlink_ext_ack *ext_ack)
#else
static int mqnic_set_ringparam(struct net_device *ndev,
		struct ethtool_ringparam *param)
#endif
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	u32 tx_ring_size, rx_ring_size;
	int port_up = priv->port_up;
	int ret = 0;

	if (param->rx_mini_pending || param->rx_jumbo_pending)
		return -EINVAL;

	if (param->rx_pending < MQNIC_MIN_RX_RING_SZ)
		return -EINVAL;

	if (param->rx_pending > MQNIC_MAX_RX_RING_SZ)
		return -EINVAL;

	if (param->tx_pending < MQNIC_MIN_TX_RING_SZ)
		return -EINVAL;

	if (param->tx_pending > MQNIC_MAX_TX_RING_SZ)
		return -EINVAL;

	rx_ring_size = roundup_pow_of_two(param->rx_pending);
	tx_ring_size = roundup_pow_of_two(param->tx_pending);

	if (rx_ring_size == priv->rx_ring_size && tx_ring_size == priv->tx_ring_size)
		return 0;

	netdev_info(ndev, "New TX ring size: %d", tx_ring_size);
	netdev_info(ndev, "New RX ring size: %d", rx_ring_size);

	mutex_lock(&priv->mdev->state_lock);

	if (port_up)
		mqnic_stop_port(ndev);

	priv->tx_ring_size = tx_ring_size;
	priv->rx_ring_size = rx_ring_size;

	if (port_up) {
		ret = mqnic_start_port(ndev);

		if (ret)
			netdev_err(ndev, "%s: Failed to start port: %d", __func__, ret);
	}

	mutex_unlock(&priv->mdev->state_lock);

	return ret;
}

static int mqnic_get_rxnfc(struct net_device *ndev,
		struct ethtool_rxnfc *rxnfc, u32 *rule_locs)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	switch (rxnfc->cmd) {
	case ETHTOOL_GRXRINGS:
		rxnfc->data = priv->rxq_count;
		break;
	default:
		return -EOPNOTSUPP;
	}

	return 0;
}

static u32 mqnic_get_rxfh_indir_size(struct net_device *ndev)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	return priv->rx_queue_map_indir_table_size;
}

static int mqnic_get_rxfh(struct net_device *ndev, u32 *indir, u8 *key,
		u8 *hfunc)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	int k;

	if (hfunc)
		*hfunc = ETH_RSS_HASH_TOP;

	if (indir)
		for (k = 0; k < priv->rx_queue_map_indir_table_size; k++)
			indir[k] = priv->rx_queue_map_indir_table[k];

	return 0;
}

static int mqnic_set_rxfh(struct net_device *ndev, const u32 *indir,
		const u8 *key, const u8 hfunc)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	int k;

	if (hfunc != ETH_RSS_HASH_NO_CHANGE && hfunc != ETH_RSS_HASH_TOP)
		return -EOPNOTSUPP;

	if (!indir)
		return 0;

	if (indir) {
		for (k = 0; k < priv->rx_queue_map_indir_table_size; k++) {
			if (indir[k] >= priv->rxq_count)
				return -EINVAL;
		}

		for (k = 0; k < priv->rx_queue_map_indir_table_size; k++)
			priv->rx_queue_map_indir_table[k] = indir[k];
	}

	return mqnic_update_indir_table(ndev);
}

static void mqnic_get_channels(struct net_device *ndev,
		struct ethtool_channels *channel)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	channel->max_rx = mqnic_res_get_count(priv->interface->rxq_res);
	channel->max_tx = mqnic_res_get_count(priv->interface->txq_res);

	channel->rx_count = priv->rxq_count;
	channel->tx_count = priv->txq_count;
}

static int mqnic_set_channels(struct net_device *ndev,
		struct ethtool_channels *channel)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	u32 txq_count, rxq_count;
	int port_up = priv->port_up;
	int ret = 0;
	int k;

	if (channel->combined_count || channel->other_count)
		return -EINVAL;

	if (priv->rxq_count > mqnic_res_get_count(priv->interface->rxq_res))
		return -EINVAL;

	if (priv->txq_count > mqnic_res_get_count(priv->interface->txq_res))
		return -EINVAL;

	rxq_count = channel->rx_count;
	txq_count = channel->tx_count;

	if (rxq_count == priv->rxq_count && txq_count == priv->txq_count)
		return 0;

	netdev_info(ndev, "New TX channel count: %d", txq_count);
	netdev_info(ndev, "New RX channel count: %d", rxq_count);

	if (rxq_count != priv->rxq_count)
		for (k = 0; k < priv->rx_queue_map_indir_table_size; k++)
			priv->rx_queue_map_indir_table[k] = k % rxq_count;

	mutex_lock(&priv->mdev->state_lock);

	if (port_up)
		mqnic_stop_port(ndev);

	priv->txq_count = txq_count;
	priv->rxq_count = rxq_count;

	if (port_up) {
		ret = mqnic_start_port(ndev);

		if (ret)
			netdev_err(ndev, "%s: Failed to start port: %d", __func__, ret);
	}

	mutex_unlock(&priv->mdev->state_lock);

	return ret;
}

static int mqnic_get_ts_info(struct net_device *ndev,
		struct ethtool_ts_info *info)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	struct mqnic_dev *mdev = priv->mdev;

	ethtool_op_get_ts_info(ndev, info);

	if (mdev->ptp_clock)
		info->phc_index = ptp_clock_index(mdev->ptp_clock);

	if (!(priv->if_features & MQNIC_IF_FEATURE_PTP_TS) || !mdev->ptp_clock)
		return 0;

	info->so_timestamping |= SOF_TIMESTAMPING_TX_HARDWARE |
		SOF_TIMESTAMPING_RX_HARDWARE | SOF_TIMESTAMPING_RAW_HARDWARE;

	info->tx_types = BIT(HWTSTAMP_TX_OFF) | BIT(HWTSTAMP_TX_ON);

	info->rx_filters = BIT(HWTSTAMP_FILTER_NONE) | BIT(HWTSTAMP_FILTER_ALL);

	return 0;
}

static int mqnic_read_module_eeprom(struct net_device *ndev,
		u16 offset, u16 len, u8 *data)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	if (!priv->mod_i2c_client)
		return -EINVAL;

	if (len > I2C_SMBUS_BLOCK_MAX)
		len = I2C_SMBUS_BLOCK_MAX;

	return i2c_smbus_read_i2c_block_data(priv->mod_i2c_client, offset, len, data);
}

static int mqnic_write_module_eeprom(struct net_device *ndev,
		u16 offset, u16 len, u8 *data)
{
	struct mqnic_priv *priv = netdev_priv(ndev);

	if (!priv->mod_i2c_client)
		return -EINVAL;

	if (len > I2C_SMBUS_BLOCK_MAX)
		len = I2C_SMBUS_BLOCK_MAX;

	return i2c_smbus_write_i2c_block_data(priv->mod_i2c_client, offset, len, data);
}

static int mqnic_query_module_id(struct net_device *ndev)
{
	int ret;
	u8 data;

	ret = mqnic_read_module_eeprom(ndev, 0, 1, &data);

	if (ret < 0)
		return ret;

	return data;
}

static int mqnic_query_module_eeprom_by_page(struct net_device *ndev,
		unsigned short i2c_addr, u16 page, u16 bank, u16 offset, u16 len, u8 *data)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	int module_id;
	u8 d;
	int ret;
	unsigned short orig_i2c_addr;

	module_id = mqnic_query_module_id(ndev);

	if (module_id < 0) {
		netdev_err(ndev, "%s: Failed to read module ID (%d)", __func__, module_id);
		return module_id;
	}

	switch (module_id) {
	case SFF_MODULE_ID_SFP:
		if (page > 0 || bank > 0)
			return -EINVAL;
		if (i2c_addr != 0x50 && i2c_addr != 0x51)
			return -EINVAL;
		break;
	case SFF_MODULE_ID_QSFP:
	case SFF_MODULE_ID_QSFP_PLUS:
	case SFF_MODULE_ID_QSFP28:
		if (page > 3 || bank > 0)
			return -EINVAL;
		if (i2c_addr != 0x50)
			return -EINVAL;
		break;
	default:
		netdev_err(ndev, "%s: Unknown module ID (0x%x)", __func__, module_id);
		return -EINVAL;
	}

	// set page
	switch (module_id) {
	case SFF_MODULE_ID_SFP:
		break;
	case SFF_MODULE_ID_QSFP:
	case SFF_MODULE_ID_QSFP_PLUS:
	case SFF_MODULE_ID_QSFP28:
		if (offset+len >= 128) {
			// select page
			d = page;
			mqnic_write_module_eeprom(ndev, 127, 1, &d);
			msleep(1);
		}
		break;
	default:
		netdev_err(ndev, "%s: Unknown module ID (0x%x)", __func__, module_id);
		return -EINVAL;
	}

	// set i2c address of the mod_i2c_client
	// This code section should not be called concurrently since the IOCTL
	// handler for ethtool operations is called under the RTNL lock.
	// In addition the i2c_client is used only within code inside this lock.
	if (!priv->mod_i2c_client)
		return -EINVAL;

	orig_i2c_addr = priv->mod_i2c_client->addr;
	priv->mod_i2c_client->addr = i2c_addr;

	// read data
	ret = mqnic_read_module_eeprom(ndev, offset, len, data);

	// reset i2c addr
	priv->mod_i2c_client->addr = orig_i2c_addr;

	return ret;
}

static int mqnic_query_module_eeprom(struct net_device *ndev,
		u16 offset, u16 len, u8 *data)
{
	int module_id;
	unsigned short i2c_addr = 0x50;
	u16 page = 0;
	u16 bank = 0;

	module_id = mqnic_query_module_id(ndev);

	if (module_id < 0) {
		netdev_err(ndev, "%s: Failed to read module ID (%d)", __func__, module_id);
		return module_id;
	}

	switch (module_id) {
	case SFF_MODULE_ID_SFP:
		i2c_addr = 0x50;
		page = 0;
		if (offset >= 256) {
			offset -= 256;
			i2c_addr = 0x51;
		}
		break;
	case SFF_MODULE_ID_QSFP:
	case SFF_MODULE_ID_QSFP_PLUS:
	case SFF_MODULE_ID_QSFP28:
		i2c_addr = 0x50;
		if (offset < 256) {
			page = 0;
		} else {
			page = 1 + ((offset - 256) / 128);
			offset -= page * 128;
		}
		break;
	default:
		netdev_err(ndev, "%s: Unknown module ID (0x%x)", __func__, module_id);
		return -EINVAL;
	}

	// clip request to end of page
	if (offset + len > 256)
		len = 256 - offset;

	return mqnic_query_module_eeprom_by_page(ndev, i2c_addr,
			page, bank, offset, len, data);
}

static int mqnic_get_module_info(struct net_device *ndev,
		struct ethtool_modinfo *modinfo)
{
	int read_len = 0;
	u8 data[16];

	// read module ID and revision
	read_len = mqnic_read_module_eeprom(ndev, 0, 2, data);

	if (read_len < 0)
		return read_len;

	if (read_len < 2)
		return -EIO;

	// check identifier byte at address 0
	switch (data[0]) {
	case SFF_MODULE_ID_SFP:
		modinfo->type = ETH_MODULE_SFF_8472;
		modinfo->eeprom_len = ETH_MODULE_SFF_8472_LEN;
		break;
	case SFF_MODULE_ID_QSFP:
		modinfo->type = ETH_MODULE_SFF_8436;
		modinfo->eeprom_len = ETH_MODULE_SFF_8436_LEN;
		break;
	case SFF_MODULE_ID_QSFP_PLUS:
		// check revision at address 1
		if (data[1] >= 0x03) {
			modinfo->type = ETH_MODULE_SFF_8636;
			modinfo->eeprom_len = ETH_MODULE_SFF_8636_LEN;
		} else {
			modinfo->type = ETH_MODULE_SFF_8436;
			modinfo->eeprom_len = ETH_MODULE_SFF_8436_LEN;
		}
		break;
	case SFF_MODULE_ID_QSFP28:
		modinfo->type = ETH_MODULE_SFF_8636;
		modinfo->eeprom_len = ETH_MODULE_SFF_8636_LEN;
		break;
	default:
		netdev_err(ndev, "%s: Unknown module ID (0x%x)", __func__, data[0]);
		return -EINVAL;
	}

	return 0;
}

static int mqnic_get_module_eeprom(struct net_device *ndev,
		struct ethtool_eeprom *eeprom, u8 *data)
{
	int i = 0;
	int read_len;

	if (eeprom->len == 0)
		return -EINVAL;

	memset(data, 0, eeprom->len);

	while (i < eeprom->len) {
		read_len = mqnic_query_module_eeprom(ndev, eeprom->offset + i,
				eeprom->len - i, data + i);

		if (read_len == 0)
			return 0;

		if (read_len < 0) {
			netdev_err(ndev, "%s: Failed to read module EEPROM (%d)", __func__, read_len);
			return read_len;
		}

		i += read_len;
	}

	return 0;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 13, 0)
static int mqnic_get_module_eeprom_by_page(struct net_device *ndev,
		const struct ethtool_module_eeprom *eeprom,
		struct netlink_ext_ack *extack)
{
	int i = 0;
	int read_len;

	if (eeprom->length == 0)
		return -EINVAL;

	memset(eeprom->data, 0, eeprom->length);

	while (i < eeprom->length) {
		read_len = mqnic_query_module_eeprom_by_page(ndev, eeprom->i2c_address,
				eeprom->page, eeprom->bank, eeprom->offset + i,
				eeprom->length - i, eeprom->data + i);

		if (read_len == 0)
			return 0;

		if (read_len < 0) {
			netdev_err(ndev, "%s: Failed to read module EEPROM (%d)", __func__, read_len);
			return read_len;
		}

		i += read_len;
	}

	return i;
}
#endif

const struct ethtool_ops mqnic_ethtool_ops = {
	.get_drvinfo = mqnic_get_drvinfo,
	.get_regs_len = mqnic_get_regs_len,
	.get_regs = mqnic_get_regs,
	.get_link = ethtool_op_get_link,
	.get_ringparam = mqnic_get_ringparam,
	.set_ringparam = mqnic_set_ringparam,
	.get_rxnfc = mqnic_get_rxnfc,
	.get_rxfh_indir_size = mqnic_get_rxfh_indir_size,
	.get_rxfh = mqnic_get_rxfh,
	.set_rxfh = mqnic_set_rxfh,
	.get_channels = mqnic_get_channels,
	.set_channels = mqnic_set_channels,
	.get_ts_info = mqnic_get_ts_info,
	.get_module_info = mqnic_get_module_info,
	.get_module_eeprom = mqnic_get_module_eeprom,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 13, 0)
	.get_module_eeprom_by_page = mqnic_get_module_eeprom_by_page,
#endif
};
