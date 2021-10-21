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

ktime_t mqnic_read_cpl_ts(struct mqnic_dev *mdev, struct mqnic_ring *ring,
		const struct mqnic_cpl *cpl)
{
	u64 ts_s = le16_to_cpu(cpl->ts_s);
	u32 ts_ns = le32_to_cpu(cpl->ts_ns);

	if (unlikely(!ring->ts_valid || (ring->ts_s ^ ts_s) & 0xff00)) {
		// seconds MSBs do not match, update cached timestamp
		ring->ts_s = ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_CUR_SEC_L);
		ring->ts_s |= (u64) ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_CUR_SEC_H) << 32;
		ring->ts_valid = 1;
	}

	ts_s |= ring->ts_s & 0xffffffffffffff00;

	return ktime_set(ts_s, ts_ns);
}

static int mqnic_phc_adjfine(struct ptp_clock_info *ptp, long scaled_ppm)
{
	struct mqnic_dev *mdev = container_of(ptp, struct mqnic_dev, ptp_clock_info);

	bool neg = false;
	u64 nom_per_fns, adj;

	dev_info(mdev->dev, "%s: scaled_ppm: %ld", __func__, scaled_ppm);

	if (scaled_ppm < 0) {
		neg = true;
		scaled_ppm = -scaled_ppm;
	}

	nom_per_fns = ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_NOM_PERIOD_FNS);
	nom_per_fns = (u64) ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_NOM_PERIOD_NS) << 32;

	if (nom_per_fns == 0)
		nom_per_fns = 0x4ULL << 32;

	adj = div_u64(((nom_per_fns >> 16) * scaled_ppm) + 500000, 1000000);

	if (neg)
		adj = nom_per_fns - adj;
	else
		adj = nom_per_fns + adj;

	iowrite32(adj & 0xffffffff, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_PERIOD_FNS);
	iowrite32(adj >> 32, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_PERIOD_NS);

	dev_info(mdev->dev, "%s adj: 0x%llx", __func__, adj);

	return 0;
}

static int mqnic_phc_gettime(struct ptp_clock_info *ptp, struct timespec64 *ts)
{
	struct mqnic_dev *mdev = container_of(ptp, struct mqnic_dev, ptp_clock_info);

	ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_FNS);
	ts->tv_nsec = ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_NS);
	ts->tv_sec = ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_SEC_L);
	ts->tv_sec |= (u64) ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_SEC_H) << 32;

	return 0;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)
static int mqnic_phc_gettimex(struct ptp_clock_info *ptp, struct timespec64 *ts,
		struct ptp_system_timestamp *sts)
{
	struct mqnic_dev *mdev = container_of(ptp, struct mqnic_dev, ptp_clock_info);

	ptp_read_system_prets(sts);
	ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_FNS);
	ptp_read_system_postts(sts);
	ts->tv_nsec = ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_NS);
	ts->tv_sec = ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_SEC_L);
	ts->tv_sec |= (u64) ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_GET_SEC_H) << 32;

	return 0;
}
#endif

static int mqnic_phc_settime(struct ptp_clock_info *ptp, const struct timespec64 *ts)
{
	struct mqnic_dev *mdev = container_of(ptp, struct mqnic_dev, ptp_clock_info);

	iowrite32(0, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_SET_FNS);
	iowrite32(ts->tv_nsec, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_SET_NS);
	iowrite32(ts->tv_sec & 0xffffffff, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_SET_SEC_L);
	iowrite32(ts->tv_sec >> 32, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_SET_SEC_H);

	return 0;
}

static int mqnic_phc_adjtime(struct ptp_clock_info *ptp, s64 delta)
{
	struct mqnic_dev *mdev = container_of(ptp, struct mqnic_dev, ptp_clock_info);
	struct timespec64 ts;

	dev_info(mdev->dev, "%s: delta: %lld", __func__, delta);

	if (delta > 1000000000 || delta < -1000000000) {
		mqnic_phc_gettime(ptp, &ts);
		ts = timespec64_add(ts, ns_to_timespec64(delta));
		mqnic_phc_settime(ptp, &ts);
	} else {
		iowrite32(0, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_ADJ_FNS);
		iowrite32(delta & 0xffffffff, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_ADJ_NS);
		iowrite32(1, mdev->phc_hw_addr + MQNIC_PHC_REG_PTP_ADJ_COUNT);
	}

	return 0;
}

static int mqnic_phc_perout(struct ptp_clock_info *ptp, int on, struct ptp_perout_request *perout)
{
	struct mqnic_dev *mdev = container_of(ptp, struct mqnic_dev, ptp_clock_info);
	u8 __iomem *hw_addr;

	u64 start_sec, period_sec, width_sec;
	u32 start_nsec, period_nsec, width_nsec;

	if (perout->index >= mdev->ptp_clock_info.n_per_out)
		return -EINVAL;

	hw_addr = mdev->phc_hw_addr + MQNIC_PHC_PEROUT_OFFSET;

	if (!on) {
		iowrite32(0, hw_addr + MQNIC_PHC_REG_PEROUT_CTRL);

		return 0;
	}

	start_nsec = perout->start.nsec;
	start_sec = start_nsec / NSEC_PER_SEC;
	start_nsec -= start_sec * NSEC_PER_SEC;
	start_sec += perout->start.sec;

	period_nsec = perout->period.nsec;
	period_sec = period_nsec / NSEC_PER_SEC;
	period_nsec -= period_sec * NSEC_PER_SEC;
	period_sec += perout->period.sec;

	// set width to half of period
	width_sec = period_sec >> 1;
	width_nsec = (period_nsec + (period_sec & 1 ? NSEC_PER_SEC : 0)) >> 1;

	dev_info(mdev->dev, "%s: start: %lld.%09d", __func__, start_sec, start_nsec);
	dev_info(mdev->dev, "%s: period: %lld.%09d", __func__, period_sec, period_nsec);
	dev_info(mdev->dev, "%s: width: %lld.%09d", __func__, width_sec, width_nsec);

	iowrite32(0, hw_addr + MQNIC_PHC_REG_PEROUT_START_FNS);
	iowrite32(start_nsec, hw_addr + MQNIC_PHC_REG_PEROUT_START_NS);
	iowrite32(start_sec & 0xffffffff, hw_addr + MQNIC_PHC_REG_PEROUT_START_SEC_L);
	iowrite32(start_sec >> 32, hw_addr + MQNIC_PHC_REG_PEROUT_START_SEC_H);

	iowrite32(0, hw_addr + MQNIC_PHC_REG_PEROUT_PERIOD_FNS);
	iowrite32(period_nsec, hw_addr + MQNIC_PHC_REG_PEROUT_PERIOD_NS);
	iowrite32(period_sec & 0xffffffff, hw_addr + MQNIC_PHC_REG_PEROUT_PERIOD_SEC_L);
	iowrite32(period_sec >> 32, hw_addr + MQNIC_PHC_REG_PEROUT_PERIOD_SEC_H);

	iowrite32(0, hw_addr + MQNIC_PHC_REG_PEROUT_WIDTH_FNS);
	iowrite32(width_nsec, hw_addr + MQNIC_PHC_REG_PEROUT_WIDTH_NS);
	iowrite32(width_sec & 0xffffffff, hw_addr + MQNIC_PHC_REG_PEROUT_WIDTH_SEC_L);
	iowrite32(width_sec >> 32, hw_addr + MQNIC_PHC_REG_PEROUT_WIDTH_SEC_H);

	iowrite32(1, hw_addr + MQNIC_PHC_REG_PEROUT_CTRL);

	return 0;
}

static int mqnic_phc_enable(struct ptp_clock_info *ptp, struct ptp_clock_request *request, int on)
{
	if (!request)
		return -EINVAL;

	switch (request->type) {
	case PTP_CLK_REQ_EXTTS:
		return -EINVAL;
	case PTP_CLK_REQ_PEROUT:
		return mqnic_phc_perout(ptp, on, &request->perout);
	case PTP_CLK_REQ_PPS:
		return -EINVAL;
	default:
		return -EINVAL;
	}
}

static void mqnic_phc_set_from_system_clock(struct ptp_clock_info *ptp)
{
	struct timespec64 ts;

#ifdef ktime_get_clocktai_ts64
	ktime_get_clocktai_ts64(&ts);
#else
	ts = ktime_to_timespec64(ktime_get_clocktai());
#endif

	mqnic_phc_settime(ptp, &ts);
}

void mqnic_register_phc(struct mqnic_dev *mdev)
{
	u32 phc_features;

	if (mdev->ptp_clock) {
		dev_warn(mdev->dev, "PTP clock already registered");
		return;
	}

	phc_features = ioread32(mdev->phc_hw_addr + MQNIC_PHC_REG_FEATURES);

	mdev->ptp_clock_info.owner = THIS_MODULE;
	mdev->ptp_clock_info.max_adj = 100000000;
	mdev->ptp_clock_info.n_alarm = 0;
	mdev->ptp_clock_info.n_ext_ts = 0;
	mdev->ptp_clock_info.n_per_out = phc_features & 0xff;
	mdev->ptp_clock_info.n_pins = 0;
	mdev->ptp_clock_info.pps = 0;
	mdev->ptp_clock_info.adjfine = mqnic_phc_adjfine;
	mdev->ptp_clock_info.adjtime = mqnic_phc_adjtime;
	mdev->ptp_clock_info.gettime64 = mqnic_phc_gettime;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)
	mdev->ptp_clock_info.gettimex64 = mqnic_phc_gettimex;
#endif
	mdev->ptp_clock_info.settime64 = mqnic_phc_settime;
	mdev->ptp_clock_info.enable = mqnic_phc_enable;
	mdev->ptp_clock = ptp_clock_register(&mdev->ptp_clock_info, mdev->dev);

	if (IS_ERR(mdev->ptp_clock)) {
		mdev->ptp_clock = NULL;
		dev_err(mdev->dev, "%s: failed", __func__);
	} else {
		dev_info(mdev->dev, "registered PHC (index %d)", ptp_clock_index(mdev->ptp_clock));

		mqnic_phc_set_from_system_clock(&mdev->ptp_clock_info);
	}
}

void mqnic_unregister_phc(struct mqnic_dev *mdev)
{
	if (mdev->ptp_clock) {
		ptp_clock_unregister(mdev->ptp_clock);
		mdev->ptp_clock = NULL;
		dev_info(mdev->dev, "unregistered PHC");
	}
}
