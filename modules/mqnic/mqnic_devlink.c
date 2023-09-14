// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <linux/version.h>

static int mqnic_devlink_info_get(struct devlink *devlink,
		struct devlink_info_req *req, struct netlink_ext_ack *extack)
{
	struct mqnic_dev *mdev = devlink_priv(devlink);
	char str[32];
	int err;

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 2, 0)
	err = devlink_info_driver_name_put(req, KBUILD_MODNAME);
	if (err)
		return err;
#endif

	snprintf(str, sizeof(str), "%08x", mdev->fpga_id);

	err = devlink_info_version_fixed_put(req, "fpga.id", str);
	if (err)
		return err;

	snprintf(str, sizeof(str), "%08x", mdev->board_id);

	err = devlink_info_version_fixed_put(req, DEVLINK_INFO_VERSION_GENERIC_BOARD_ID, str);
	if (err)
		return err;

	snprintf(str, sizeof(str), "%d.%d.%d.%d",
			mdev->board_ver >> 24, (mdev->board_ver >> 16) & 0xff,
			(mdev->board_ver >> 8) & 0xff, mdev->board_ver & 0xff);

	err = devlink_info_version_fixed_put(req, DEVLINK_INFO_VERSION_GENERIC_BOARD_REV, str);
	if (err)
		return err;

	snprintf(str, sizeof(str), "%08x", mdev->fw_id);

	err = devlink_info_version_running_put(req, "fw.id", str);
	if (err)
		return err;

	snprintf(str, sizeof(str), "%d.%d.%d.%d",
			mdev->fw_ver >> 24, (mdev->fw_ver >> 16) & 0xff,
			(mdev->fw_ver >> 8) & 0xff, mdev->fw_ver & 0xff);

	err = devlink_info_version_running_put(req, "fw.version", str);
	if (err)
		return err;
	err = devlink_info_version_running_put(req, DEVLINK_INFO_VERSION_GENERIC_FW, str);
	if (err)
		return err;

	err = devlink_info_version_running_put(req, "fw.build_date", mdev->build_date_str);
	if (err)
		return err;

	snprintf(str, sizeof(str), "%08x", mdev->git_hash);

	err = devlink_info_version_running_put(req, "fw.git_hash", str);
	if (err)
		return err;

	snprintf(str, sizeof(str), "%08x", mdev->rel_info);

	err = devlink_info_version_running_put(req, "fw.rel_info", str);
	if (err)
		return err;

	if (mdev->app_id) {
		snprintf(str, sizeof(str), "%08x", mdev->app_id);

		err = devlink_info_version_running_put(req, "fw.app.id", str);
		if (err)
			return err;
	}

	return 0;
}

static const struct devlink_ops mqnic_devlink_ops = {
	.info_get = mqnic_devlink_info_get,
};

struct devlink *mqnic_devlink_alloc(struct device *dev)
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
	return devlink_alloc(&mqnic_devlink_ops, sizeof(struct mqnic_dev), dev);
#else
	return devlink_alloc(&mqnic_devlink_ops, sizeof(struct mqnic_dev));
#endif
}

void mqnic_devlink_free(struct devlink *devlink)
{
	devlink_free(devlink);
}
