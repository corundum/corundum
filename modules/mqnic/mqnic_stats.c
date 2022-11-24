// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2022, The Regents of the University of California.
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
