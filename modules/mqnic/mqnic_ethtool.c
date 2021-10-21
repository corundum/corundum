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

#include <linux/ethtool.h>

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

	snprintf(drvinfo->fw_version, sizeof(drvinfo->fw_version), "%d.%d",
			mdev->fw_ver >> 16, mdev->fw_ver & 0xffff);
	strscpy(drvinfo->bus_info, dev_name(mdev->dev), sizeof(drvinfo->bus_info));
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
		return -1;

	if (len > I2C_SMBUS_BLOCK_MAX)
		len = I2C_SMBUS_BLOCK_MAX;

	return i2c_smbus_read_i2c_block_data(priv->mod_i2c_client, offset, len, data);
}

static int mqnic_get_module_info(struct net_device *ndev,
		struct ethtool_modinfo *modinfo)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	int read_len = 0;
	u8 data[16];

	// read module ID and revision
	read_len = mqnic_read_module_eeprom(ndev, 0, 2, data);

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
		dev_err(priv->dev, "Unknown module ID");
		return -EINVAL;
	}

	return 0;
}

static int mqnic_get_module_eeprom(struct net_device *ndev,
		struct ethtool_eeprom *eeprom, u8 *data)
{
	struct mqnic_priv *priv = netdev_priv(ndev);
	int i = 0;
	int read_len;

	if (eeprom->len == 0)
		return -EINVAL;

	memset(data, 0, eeprom->len);

	while (i < eeprom->len) {
		read_len = mqnic_read_module_eeprom(ndev, eeprom->offset + i,
				eeprom->len - i, data + i);

		if (read_len == 0)
			return -EIO;

		if (read_len < 0) {
			dev_err(priv->dev, "Failed to read module EEPROM");
			return 0;
		}

		i += read_len;
	}

	return 0;
}

const struct ethtool_ops mqnic_ethtool_ops = {
	.get_drvinfo = mqnic_get_drvinfo,
	.get_ts_info = mqnic_get_ts_info,
	.get_module_info = mqnic_get_module_info,
	.get_module_eeprom = mqnic_get_module_eeprom,
};
