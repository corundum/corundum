// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
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
