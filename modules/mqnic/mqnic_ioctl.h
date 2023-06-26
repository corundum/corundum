/* SPDX-License-Identifier: BSD-2-Clause-Views */
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#ifndef MQNIC_IOCTL_H
#define MQNIC_IOCTL_H

#include <linux/types.h>

#define MQNIC_IOCTL_API_VERSION 0

#define MQNIC_IOCTL_TYPE 0x88
#define MQNIC_IOCTL_BASE 0xC0

enum {
	MQNIC_REGION_TYPE_UNIMPLEMENTED = 0x00000000,
	MQNIC_REGION_TYPE_CTRL = 0x00001000,
	MQNIC_REGION_TYPE_NIC_CTRL = 0x00001001,
	MQNIC_REGION_TYPE_APP_CTRL = 0x00001002,
	MQNIC_REGION_TYPE_RAM = 0x00002000
};

// get API version
#define MQNIC_IOCTL_GET_API_VERSION _IO(MQNIC_IOCTL_TYPE, MQNIC_IOCTL_BASE + 0)

// get device information
struct mqnic_ioctl_device_info {
	__u32 argsz;
	__u32 flags;
	__u32 fw_id;
	__u32 fw_ver;
	__u32 board_id;
	__u32 board_ver;
	__u32 build_date;
	__u32 git_hash;
	__u32 rel_info;
	__u32 num_regions;
	__u32 num_irqs;
};

#define MQNIC_IOCTL_GET_DEVICE_INFO _IO(MQNIC_IOCTL_TYPE, MQNIC_IOCTL_BASE + 1)

// get region information
struct mqnic_ioctl_region_info {
	__u32 argsz;
	__u32 flags;
	__u32 index;
	__u32 type;
	__u32 next;
	__u32 child;
	__u64 size;
	__u64 offset;
	__u8 name[32];
};

#define MQNIC_IOCTL_GET_REGION_INFO _IO(MQNIC_IOCTL_TYPE, MQNIC_IOCTL_BASE + 2)

#endif /* MQNIC_IOCTL_H */
