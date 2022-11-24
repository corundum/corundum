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

void mqnic_clk_info_init(struct mqnic_dev *mdev)
{
	u32 val;

	mdev->clk_info_rb = mqnic_find_reg_block(mdev->rb_list, MQNIC_RB_CLK_INFO_TYPE, MQNIC_RB_CLK_INFO_VER, 0);

	if (!mdev->clk_info_rb)
		return;

	val = ioread32(mdev->clk_info_rb->regs + MQNIC_RB_CLK_INFO_REF_NOM_PER);

	mdev->ref_clk_nom_per_ns_num = val >> 16;
	mdev->ref_clk_nom_per_ns_denom = val & 0xffff;
	mdev->ref_clk_nom_freq_hz = (mdev->ref_clk_nom_per_ns_denom * 1000000000ull) / mdev->ref_clk_nom_per_ns_num;

	val = ioread32(mdev->clk_info_rb->regs + MQNIC_RB_CLK_INFO_CLK_NOM_PER);

	mdev->core_clk_nom_per_ns_num = val >> 16;
	mdev->core_clk_nom_per_ns_denom = val & 0xffff;
	mdev->core_clk_nom_freq_hz = (mdev->core_clk_nom_per_ns_denom * 1000000000ull) / mdev->core_clk_nom_per_ns_num;

	mdev->clk_info_channels = ioread32(mdev->clk_info_rb->regs + MQNIC_RB_CLK_INFO_COUNT);
}

u32 mqnic_get_core_clk_nom_freq_hz(struct mqnic_dev *mdev)
{
	return mdev->core_clk_nom_freq_hz;
}
EXPORT_SYMBOL(mqnic_get_core_clk_nom_freq_hz);

u32 mqnic_get_ref_clk_nom_freq_hz(struct mqnic_dev *mdev)
{
	return mdev->ref_clk_nom_freq_hz;
}
EXPORT_SYMBOL(mqnic_get_ref_clk_nom_freq_hz);

u32 mqnic_get_core_clk_freq_hz(struct mqnic_dev *mdev)
{
	if (!mdev->clk_info_rb)
		return 0;

	return ioread32(mdev->clk_info_rb->regs + MQNIC_RB_CLK_INFO_CLK_FREQ);
}
EXPORT_SYMBOL(mqnic_get_core_clk_freq_hz);

u32 mqnic_get_clk_freq_hz(struct mqnic_dev *mdev, int ch)
{
	if (!mdev->clk_info_rb || ch < 0 || ch >= mdev->clk_info_channels)
		return 0;

	return ioread32(mdev->clk_info_rb->regs + MQNIC_RB_CLK_INFO_FREQ_BASE + ch*4);
}
EXPORT_SYMBOL(mqnic_get_clk_freq_hz);

u64 mqnic_core_clk_cycles_to_ns(struct mqnic_dev *mdev, u64 cycles)
{
	if (!mdev->clk_info_rb || !mdev->core_clk_nom_per_ns_denom)
		return 0;

	return (cycles * (u64)mdev->core_clk_nom_per_ns_num) / (u64)mdev->core_clk_nom_per_ns_denom;
}
EXPORT_SYMBOL(mqnic_core_clk_cycles_to_ns);

u64 mqnic_core_clk_ns_to_cycles(struct mqnic_dev *mdev, u64 ns)
{
	if (!mdev->clk_info_rb || !mdev->core_clk_nom_per_ns_num)
		return 0;

	return (ns * (u64)mdev->core_clk_nom_per_ns_denom) / (u64)mdev->core_clk_nom_per_ns_num;
}
EXPORT_SYMBOL(mqnic_core_clk_ns_to_cycles);

u64 mqnic_ref_clk_cycles_to_ns(struct mqnic_dev *mdev, u64 cycles)
{
	if (!mdev->clk_info_rb || !mdev->ref_clk_nom_per_ns_denom)
		return 0;

	return (cycles * (u64)mdev->ref_clk_nom_per_ns_num) / (u64)mdev->ref_clk_nom_per_ns_denom;
}
EXPORT_SYMBOL(mqnic_ref_clk_cycles_to_ns);

u64 mqnic_ref_clk_ns_to_cycles(struct mqnic_dev *mdev, u64 ns)
{
	if (!mdev->clk_info_rb || !mdev->ref_clk_nom_per_ns_num)
		return 0;

	return (ns * (u64)mdev->ref_clk_nom_per_ns_denom) / (u64)mdev->ref_clk_nom_per_ns_num;
}
EXPORT_SYMBOL(mqnic_ref_clk_ns_to_cycles);
