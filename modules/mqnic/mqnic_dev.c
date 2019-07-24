/*

Copyright 2019, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

#include "mqnic.h"
#include "mqnic_ioctl.h"

static int mqnic_open(struct inode *inode, struct file *filp)
{
    struct mqnic_dev *mqnic;

    mqnic = mqnic_find_by_minor(iminor(inode));
    if (mqnic == NULL)
    {
        pr_err("Failed to locate mqnic for minor = %u.\n", iminor(inode));
        return -ENODEV;
    }

    filp->private_data = mqnic;
    return 0;
}

static int mqnic_release(struct inode *inode, struct file *filp)
{
    //struct mqnic_dev *mqnic = filp->private_data;

    return 0;
}

static int mqnic_map_registers(struct mqnic_dev *mqnic, struct vm_area_struct *vma)
{
    struct device *dev = &mqnic->pdev->dev;
    size_t map_size = vma->vm_end - vma->vm_start;
    int ret;

    if (map_size > mqnic->hw_regs_size)
    {
        dev_err(dev, "mqnic_map_registers: Tried to map registers region with wrong size %lu (expected <=%zu)", vma->vm_end - vma->vm_start, mqnic->hw_regs_size);
        return -EINVAL;
    }

    ret = remap_pfn_range(vma, vma->vm_start, mqnic->hw_regs_phys >> PAGE_SHIFT, map_size, pgprot_noncached(vma->vm_page_prot));

    if (ret)
    {
        dev_err(dev, "mqnic_map_registers: remap_pfn_range failed for registers region");
    }
    else
    {
        dev_dbg(dev, "mqnic_map_registers: Mapped registers region at phys: 0x%pap, virt: 0x%p", &mqnic->hw_regs_phys, (void *)vma->vm_start);
    }

    return ret;    
}

static int mqnic_mmap(struct file *filp, struct vm_area_struct *vma)
{
    struct mqnic_dev *mqnic = filp->private_data;
    struct device *dev = &mqnic->pdev->dev;
    int ret;

    if (vma->vm_pgoff == 0)
    {
        ret = mqnic_map_registers(mqnic, vma);
    }
    else
    {
        goto fail_invalid_offset;
    }

    return ret;

fail_invalid_offset:
    dev_err(dev, "mqnic_mmap: Tried to map an unknown region at page offset %lu", vma->vm_pgoff);
    return -EINVAL;
}

static long mqnic_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    struct mqnic_dev *mqnic = filp->private_data;

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

            if (copy_to_user((void *)arg, &ctl, sizeof(ctl)) != 0)
                return -EFAULT;

            return 0;
        }
    default:
        return -ENOTTY;
    }
}

const struct file_operations mqnic_fops = {
    .owner          = THIS_MODULE,
    .open           = mqnic_open,
    .release        = mqnic_release,
    .mmap           = mqnic_mmap,
    .unlocked_ioctl = mqnic_ioctl,
};
