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

static void mqnic_get_drvinfo(struct net_device *ndev, struct ethtool_drvinfo *drvinfo)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_dev *mdev = priv->mdev;

    strlcpy(drvinfo->driver, DRIVER_NAME, sizeof(drvinfo->driver));
    strlcpy(drvinfo->version, DRIVER_VERSION, sizeof(drvinfo->version));

    snprintf(drvinfo->fw_version, sizeof(drvinfo->fw_version), "%d.%d", mdev->fw_ver >> 16, mdev->fw_ver & 0xffff);
    strlcpy(drvinfo->bus_info, dev_name(mdev->dev), sizeof(drvinfo->bus_info));
}

static int mqnic_get_ts_info(struct net_device *ndev, struct ethtool_ts_info *info)
{
    struct mqnic_priv *priv = netdev_priv(ndev);
    struct mqnic_dev *mdev = priv->mdev;
    int ret;

    ret = ethtool_op_get_ts_info(ndev, info);
    if (ret)
        return ret;

    info->so_timestamping |=
        SOF_TIMESTAMPING_TX_HARDWARE |
        SOF_TIMESTAMPING_RX_HARDWARE |
        SOF_TIMESTAMPING_RAW_HARDWARE;

    info->tx_types =
        (1 << HWTSTAMP_TX_OFF) |
        (1 << HWTSTAMP_TX_ON);

    info->rx_filters =
        (1 << HWTSTAMP_FILTER_NONE) |
        (1 << HWTSTAMP_FILTER_ALL);

    if (mdev->ptp_clock)
        info->phc_index = ptp_clock_index(mdev->ptp_clock);

    return ret;
}

const struct ethtool_ops mqnic_ethtool_ops = {
    .get_drvinfo = mqnic_get_drvinfo,
    .get_ts_info = mqnic_get_ts_info
};

