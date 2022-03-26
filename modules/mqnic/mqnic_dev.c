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
#include "mqnic_ioctl.h"

#include <linux/uaccess.h>

static int mqnic_open(struct inode *inode, struct file *file)
{
	// struct miscdevice *miscdev = file->private_data;
	// struct mqnic_dev *mqnic = container_of(miscdev, struct mqnic_dev, misc_dev);

	return 0;
}

static int mqnic_release(struct inode *inode, struct file *file)
{
	// struct miscdevice *miscdev = file->private_data;
	// struct mqnic_dev *mqnic = container_of(miscdev, struct mqnic_dev, misc_dev);

	return 0;
}

static int mqnic_mmap(struct file *file, struct vm_area_struct *vma)
{
	struct miscdevice *miscdev = file->private_data;
	struct mqnic_dev *mqnic = container_of(miscdev, struct mqnic_dev, misc_dev);
	int index;
	u64 pgoff, req_len, req_start;

	index = vma->vm_pgoff >> (40 - PAGE_SHIFT);
	req_len = vma->vm_end - vma->vm_start;
	pgoff = vma->vm_pgoff & ((1U << (40 - PAGE_SHIFT)) - 1);
	req_start = pgoff << PAGE_SHIFT;

	if (vma->vm_end < vma->vm_start)
		return -EINVAL;

	if ((vma->vm_flags & VM_SHARED) == 0)
		return -EINVAL;

	switch (index) {
	case 0:
		if (req_start + req_len > mqnic->hw_regs_size)
			return -EINVAL;

		return io_remap_pfn_range(vma, vma->vm_start,
				(mqnic->hw_regs_phys >> PAGE_SHIFT) + pgoff,
				req_len, pgprot_noncached(vma->vm_page_prot));
	case 1:
		if (req_start + req_len > mqnic->app_hw_regs_size)
			return -EINVAL;

		return io_remap_pfn_range(vma, vma->vm_start,
				(mqnic->app_hw_regs_phys >> PAGE_SHIFT) + pgoff,
				req_len, pgprot_noncached(vma->vm_page_prot));
	case 2:
		if (req_start + req_len > mqnic->ram_hw_regs_size)
			return -EINVAL;

		return io_remap_pfn_range(vma, vma->vm_start,
				(mqnic->ram_hw_regs_phys >> PAGE_SHIFT) + pgoff,
				req_len, pgprot_noncached(vma->vm_page_prot));
	default:
		dev_err(mqnic->dev, "%s: Tried to map an unknown region at page offset 0x%lx",
				__func__, vma->vm_pgoff);
		return -EINVAL;
	}

	return -EINVAL;
}

static long mqnic_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct miscdevice *miscdev = file->private_data;
	struct mqnic_dev *mqnic = container_of(miscdev, struct mqnic_dev, misc_dev);
	size_t minsz;

	if (cmd == MQNIC_IOCTL_GET_API_VERSION) {
		// Get API version
		return MQNIC_IOCTL_API_VERSION;
	} else if (cmd == MQNIC_IOCTL_GET_DEVICE_INFO) {
		// Get device information
		struct mqnic_ioctl_device_info info;

		minsz = offsetofend(struct mqnic_ioctl_device_info, num_irqs);

		if (copy_from_user(&info, (void __user *)arg, minsz))
			return -EFAULT;

		if (info.argsz < minsz)
			return -EINVAL;

		info.flags = 0;
		info.fw_id = mqnic->fw_id;
		info.fw_ver = mqnic->fw_ver;
		info.board_id = mqnic->board_id;
		info.board_ver = mqnic->board_ver;
		info.build_date = mqnic->build_date;
		info.git_hash = mqnic->git_hash;
		info.rel_info = mqnic->rel_info;
		info.num_regions = 3;
		info.num_irqs = 0;

		return copy_to_user((void __user *)arg, &info, minsz) ? -EFAULT : 0;

	} else if (cmd == MQNIC_IOCTL_GET_REGION_INFO) {
		// Get region information
		struct mqnic_ioctl_region_info info;

		minsz = offsetofend(struct mqnic_ioctl_region_info, name);

		if (copy_from_user(&info, (void __user *)arg, minsz))
			return -EFAULT;

		if (info.argsz < minsz)
			return -EINVAL;

		info.flags = 0;
		info.type = MQNIC_REGION_TYPE_UNIMPLEMENTED;
		info.next = 0;
		info.child = 0;
		info.size = 0;
		info.offset = ((u64)info.index) << 40;
		info.name[0] = 0;

		switch (info.index) {
		case 0:
			info.type = MQNIC_REGION_TYPE_NIC_CTRL;
			info.next = 1;
			info.child = 0;
			info.size = mqnic->hw_regs_size;
			info.offset = ((u64)info.index) << 40;
			strlcpy(info.name, "ctrl", sizeof(info.name));
			break;
		case 1:
			info.type = MQNIC_REGION_TYPE_APP_CTRL;
			info.next = 2;
			info.child = 0;
			info.size = mqnic->app_hw_regs_size;
			info.offset = ((u64)info.index) << 40;
			strlcpy(info.name, "app", sizeof(info.name));
			break;
		case 2:
			info.type = MQNIC_REGION_TYPE_RAM;
			info.next = 3;
			info.child = 0;
			info.size = mqnic->ram_hw_regs_size;
			info.offset = ((u64)info.index) << 40;
			strlcpy(info.name, "ram", sizeof(info.name));
			break;
		default:
			return -EINVAL;
		}

		return copy_to_user((void __user *)arg, &info, minsz) ? -EFAULT : 0;

	}

	return -EINVAL;
}

const struct file_operations mqnic_fops = {
	.owner = THIS_MODULE,
	.open = mqnic_open,
	.release = mqnic_release,
	.mmap = mqnic_mmap,
	.unlocked_ioctl = mqnic_ioctl,
};
