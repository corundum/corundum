/* SPDX-License-Identifier: BSD-2-Clause-Views */
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
