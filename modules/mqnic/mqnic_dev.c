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

static int mqnic_map_registers(struct mqnic_dev *mqnic, struct vm_area_struct *vma)
{
	size_t map_size = vma->vm_end - vma->vm_start;
	int ret;

	if (map_size > mqnic->hw_regs_size) {
		dev_err(mqnic->dev, "%s: Tried to map registers region with wrong size %lu (expected <= %llu)",
				__func__, vma->vm_end - vma->vm_start, mqnic->hw_regs_size);
		return -EINVAL;
	}

	ret = remap_pfn_range(vma, vma->vm_start, mqnic->hw_regs_phys >> PAGE_SHIFT,
			map_size, pgprot_noncached(vma->vm_page_prot));

	if (ret)
		dev_err(mqnic->dev, "%s: remap_pfn_range failed for registers region", __func__);
	else
		dev_dbg(mqnic->dev, "%s: Mapped registers region at phys: 0x%pap, virt: 0x%p",
				__func__, &mqnic->hw_regs_phys, (void *)vma->vm_start);

	return ret;
}

static int mqnic_mmap(struct file *file, struct vm_area_struct *vma)
{
	struct miscdevice *miscdev = file->private_data;
	struct mqnic_dev *mqnic = container_of(miscdev, struct mqnic_dev, misc_dev);

	if (vma->vm_pgoff == 0)
		return mqnic_map_registers(mqnic, vma);

	dev_err(mqnic->dev, "%s: Tried to map an unknown region at page offset %lu",
			__func__, vma->vm_pgoff);
	return -EINVAL;
}

static long mqnic_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct miscdevice *miscdev = file->private_data;
	struct mqnic_dev *mqnic = container_of(miscdev, struct mqnic_dev, misc_dev);

	if (_IOC_TYPE(cmd) != MQNIC_IOCTL_TYPE)
		return -ENOTTY;

	switch (cmd) {
	case MQNIC_IOCTL_INFO:
		{
			struct mqnic_ioctl_info ctl;

			ctl.fw_id = mqnic->fw_id;
			ctl.fw_ver = mqnic->fw_ver;
			ctl.board_id = mqnic->board_id;
			ctl.board_ver = mqnic->board_ver;
			ctl.regs_size = mqnic->hw_regs_size;

			if (copy_to_user((void __user *)arg, &ctl, sizeof(ctl)) != 0)
				return -EFAULT;

			return 0;
		}
	default:
		return -ENOTTY;
	}
}

const struct file_operations mqnic_fops = {
	.owner = THIS_MODULE,
	.open = mqnic_open,
	.release = mqnic_release,
	.mmap = mqnic_mmap,
	.unlocked_ioctl = mqnic_ioctl,
};
