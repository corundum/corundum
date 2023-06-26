// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

#include "mqnic.h"

void mqnic_stats_init(struct mqnic_dev *mdev)
{
	mdev->stats_rb = mqnic_find_reg_block(mdev->rb_list, MQNIC_RB_STATS_TYPE, MQNIC_RB_STATS_VER, 0);

	if (!mdev->stats_rb)
		return;

	mdev->stats_offset = ioread32(mdev->stats_rb->regs + MQNIC_RB_STATS_REG_OFFSET);
	mdev->stats_count = ioread32(mdev->stats_rb->regs + MQNIC_RB_STATS_REG_COUNT);
	mdev->stats_stride = ioread32(mdev->stats_rb->regs + MQNIC_RB_STATS_REG_STRIDE);
	mdev->stats_flags = ioread32(mdev->stats_rb->regs + MQNIC_RB_STATS_REG_FLAGS);
}

u64 mqnic_stats_read(struct mqnic_dev *mdev, int index)
{
	u64 val;

	if (!mdev->stats_rb || index < 0 || index >= mdev->stats_count)
		return 0;

	val = (u64)ioread32(mdev->hw_addr + mdev->stats_offset + index*8 + 0);
	val |= (u64)ioread32(mdev->hw_addr + mdev->stats_offset + index*8 + 4) << 32;

	return val;
}
EXPORT_SYMBOL(mqnic_stats_read);
