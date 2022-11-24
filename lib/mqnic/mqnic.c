/*

Copyright 2019-2022, The Regents of the University of California.
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
#include "fpga_id.h"

#include <dirent.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>

static int mqnic_try_open(struct mqnic *dev, const char *fmt, ...)
{
    va_list ap;
    char path[PATH_MAX+32];
    struct stat st;
    char *ptr;

    va_start(ap, fmt);
    vsnprintf(dev->device_path, sizeof(dev->device_path), fmt, ap);
    va_end(ap);

    dev->pci_device_path[0] = 0;

    if (access(dev->device_path, W_OK))
        return -1;

    if (stat(dev->device_path, &st))
        return -1;

    if (S_ISDIR(st.st_mode))
        return -1;

    dev->fd = open(dev->device_path, O_RDWR);

    if (dev->fd < 0)
    {
        perror("open device failed");
        goto fail_open;
    }

    // determine sysfs path of PCIe device
    // first, try to find via miscdevice
    ptr = strrchr(dev->device_path, '/');
    ptr = ptr ? ptr+1 : dev->device_path;

    snprintf(path, sizeof(path), "/sys/class/misc/%s/device", ptr);

    if (!realpath(path, dev->pci_device_path))
    {
        // that failed, perhaps it was a PCIe resource
        snprintf(path, sizeof(path), "%s", dev->device_path);
        ptr = strrchr(path, '/');
        if (ptr)
            *ptr = 0;

        if (!realpath(path, dev->pci_device_path))
            dev->pci_device_path[0] = 0;
    }

    // PCIe device will have a config space, so check for that
    if (dev->pci_device_path[0])
    {
        snprintf(path, sizeof(path), "%s/config", dev->pci_device_path);

        if (access(path, F_OK))
            dev->pci_device_path[0] = 0;
    }

    if (fstat(dev->fd, &st))
    {
        perror("fstat failed");
        goto fail_fstat;
    }

    dev->regs_size = st.st_size;

    if (dev->regs_size == 0)
    {
        // miscdevice
        off_t regs_offset = 0;
        off_t app_regs_offset = 0;
        off_t ram_offset = 0;

        if (ioctl(dev->fd, MQNIC_IOCTL_GET_API_VERSION, 0) != MQNIC_IOCTL_API_VERSION)
        {
            fprintf(stderr, "Error: unknown API version\n");
            goto fail_ioctl;
        }

        struct mqnic_ioctl_device_info device_info;
        device_info.argsz = sizeof(device_info);
        device_info.flags = 0;

        if (ioctl(dev->fd, MQNIC_IOCTL_GET_DEVICE_INFO, &device_info) != 0)
        {
            perror("MQNIC_IOCTL_GET_DEVICE_INFO ioctl failed");
            goto fail_ioctl;
        }

        struct mqnic_ioctl_region_info region_info;
        region_info.argsz = sizeof(region_info);
        region_info.flags = 0;
        region_info.index = 0;

        for (region_info.index = 0; region_info.index < device_info.num_regions; region_info.index++)
        {
            if (ioctl(dev->fd, MQNIC_IOCTL_GET_REGION_INFO, &region_info) != 0)
            {
                perror("MQNIC_IOCTL_GET_REGION_INFO ioctl failed");
                goto fail_ioctl;
            }

            switch (region_info.type) {
            case MQNIC_REGION_TYPE_NIC_CTRL:
                regs_offset = region_info.offset;
                dev->regs_size = region_info.size;
                break;
            case MQNIC_REGION_TYPE_APP_CTRL:
                app_regs_offset = region_info.offset;
                dev->app_regs_size = region_info.size;
                break;
            case MQNIC_REGION_TYPE_RAM:
                ram_offset = region_info.offset;
                dev->ram_size = region_info.size;
                break;
            default:
                break;
            }
        }

        // map registers
        dev->regs = (volatile uint8_t *)mmap(NULL, dev->regs_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, regs_offset);
        if (dev->regs == MAP_FAILED)
        {
            perror("mmap regs failed");
            goto fail_mmap_regs;
        }

        // map application section registers
        if (dev->app_regs_size)
        {
            dev->app_regs = (volatile uint8_t *)mmap(NULL, dev->app_regs_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, app_regs_offset);
            if (dev->app_regs == MAP_FAILED)
            {
                perror("mmap app regs failed");
                goto fail_mmap_regs;
            }
        }

        // map RAM
        if (dev->ram_size)
        {
            dev->ram = (volatile uint8_t *)mmap(NULL, dev->ram_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, ram_offset);
            if (dev->ram == MAP_FAILED)
            {
                perror("mmap RAM failed");
                goto fail_mmap_regs;
            }
        }
    }
    else
    {
        // PCIe resource

        // map registers
        dev->regs = (volatile uint8_t *)mmap(NULL, dev->regs_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, 0);
        if (dev->regs == MAP_FAILED)
        {
            perror("mmap regs failed");
            goto fail_mmap_regs;
        }

        if (dev->pci_device_path[0])
        {
            // map application section registers
            snprintf(path, sizeof(path), "%s/resource2", dev->pci_device_path);

            dev->app_fd = open(path, O_RDWR);

            if (dev->app_fd >= 0)
            {
                if (fstat(dev->app_fd, &st))
                {
                    perror("fstat failed");
                    goto fail_fstat;
                }

                dev->app_regs_size = st.st_size;

                dev->app_regs = (volatile uint8_t *)mmap(NULL, dev->app_regs_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->app_fd, 0);
                if (dev->app_regs == MAP_FAILED)
                {
                    perror("mmap app regs failed");
                    goto fail_mmap_regs;
                }
            }

            // map RAM
            snprintf(path, sizeof(path), "%s/resource4", dev->pci_device_path);

            dev->ram_fd = open(path, O_RDWR);

            if (dev->ram_fd >= 0)
            {
                if (fstat(dev->ram_fd, &st))
                {
                    perror("fstat failed");
                    goto fail_fstat;
                }

                dev->ram_size = st.st_size;

                dev->ram = (volatile uint8_t *)mmap(NULL, dev->ram_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->ram_fd, 0);
                if (dev->ram == MAP_FAILED)
                {
                    perror("mmap RAM failed");
                    goto fail_mmap_regs;
                }
            }

            if (dev->pci_device_path[0] && mqnic_reg_read32(dev->regs, 4) == 0xffffffff)
            {
                // if we were given a PCIe resource, then we may need to enable the device
                snprintf(path, sizeof(path), "%s/enable", dev->pci_device_path);

                if (access(path, W_OK) == 0)
                {
                    FILE *fp = fopen(path, "w");

                    if (fp)
                    {
                        fputc('1', fp);
                        fclose(fp);
                    }
                }
            }
        }
    }

    if (mqnic_reg_read32(dev->regs, 4) == 0xffffffff)
    {
        fprintf(stderr, "Error: device needs to be reset\n");
        goto fail_reset;
    }

    dev->rb_list = mqnic_enumerate_reg_block_list(dev->regs, 0, dev->regs_size);

    if (!dev->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail_enum;
    }

    // Read ID registers
    dev->fw_id_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_FW_ID_TYPE, MQNIC_RB_FW_ID_VER, 0);

    if (!dev->fw_id_rb)
    {
        fprintf(stderr, "Error: FW ID block not found\n");
        goto fail_enum;
    }

    return 0;

fail_enum:
    if (dev->rb_list)
        mqnic_free_reg_block_list(dev->rb_list);
fail_reset:
fail_mmap_regs:
    if (dev->ram)
        munmap((void *)dev->ram, dev->ram_size);
    dev->ram = NULL;
    if (dev->app_regs)
        munmap((void *)dev->app_regs, dev->app_regs_size);
    dev->app_regs = NULL;
    if (dev->regs)
        munmap((void *)dev->regs, dev->regs_size);
    dev->regs = NULL;
fail_ioctl:
fail_fstat:
    close(dev->fd);
    dev->fd = -1;
    close(dev->app_fd);
    dev->app_fd = -1;
    close(dev->ram_fd);
    dev->ram_fd = -1;
fail_open:
    return -1;
}

static int mqnic_try_open_if_name(struct mqnic *dev, const char *if_name)
{
    DIR *folder;
    struct dirent *entry;
    char path[PATH_MAX];

    snprintf(path, sizeof(path), "/sys/class/net/%s/device/misc/", if_name);

    folder = opendir(path);
    if (!folder)
        return -1;

    while ((entry = readdir(folder)))
    {
        if (entry->d_name[0] != '.')
            break;
    }

    if (!entry)
    {
        closedir(folder);
        return -1;
    }

    snprintf(path, sizeof(path), "/dev/%s", entry->d_name);

    closedir(folder);

    return mqnic_try_open(dev, "%s", path);
}

struct mqnic *mqnic_open(const char *dev_name)
{
    struct mqnic *dev = calloc(1, sizeof(struct mqnic));
    struct mqnic_reg_block *rb;

    if (!dev)
    {
        perror("memory allocation failed");
        goto fail_alloc;
    }

    dev->fd = -1;
    dev->app_fd = -1;
    dev->ram_fd = -1;

    // absolute path
    if (mqnic_try_open(dev, "%s", dev_name) == 0)
        goto open;

    // device name
    if (mqnic_try_open(dev, "/dev/%s", dev_name) == 0)
        goto open;

    // network interface
    if (mqnic_try_open_if_name(dev, dev_name) == 0)
        goto open;

    // PCIe sysfs path
    if (mqnic_try_open(dev, "%s/resource0", dev_name) == 0)
        goto open;

    // PCIe BDF (dddd:xx:yy.z)
    if (mqnic_try_open(dev, "/sys/bus/pci/devices/%s/resource0", dev_name) == 0)
        goto open;

    // PCIe BDF (xx:yy.z)
    if (mqnic_try_open(dev, "/sys/bus/pci/devices/0000:%s/resource0", dev_name) == 0)
        goto open;

    goto fail_open;

open:
    dev->fpga_id = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_FPGA_ID);
    dev->fw_id = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_FW_ID);
    dev->fw_ver = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_FW_VER);
    dev->board_id = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_BOARD_ID);
    dev->board_ver = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_BOARD_VER);
    dev->build_date = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_BUILD_DATE);
    dev->git_hash = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_GIT_HASH);
    dev->rel_info = mqnic_reg_read32(dev->fw_id_rb->regs, MQNIC_RB_FW_ID_REG_REL_INFO);

    dev->fpga_part = get_fpga_part(dev->fpga_id);

    time_t build_date = dev->build_date;
    struct tm *tm_info = gmtime(&build_date);
    strftime(dev->build_date_str, sizeof(dev->build_date_str), "%F %T", tm_info);

    rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_APP_INFO_TYPE, MQNIC_RB_APP_INFO_VER, 0);

    if (rb) {
        dev->app_id = mqnic_reg_read32(rb->regs, MQNIC_RB_APP_INFO_REG_ID);
    }

    mqnic_stats_init(dev);
    mqnic_clk_info_init(dev);

    dev->phc_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_PHC_TYPE, MQNIC_RB_PHC_VER, 0);

    // Enumerate interfaces
    dev->if_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_IF_TYPE, MQNIC_RB_IF_VER, 0);

    if (!dev->if_rb)
    {
        fprintf(stderr, "Interface block not found, skipping interface enumeration\n");
        dev->if_count = 0;
        goto skip_interface;
    }

    dev->if_offset = mqnic_reg_read32(dev->if_rb->regs, MQNIC_RB_IF_REG_OFFSET);
    dev->if_count = mqnic_reg_read32(dev->if_rb->regs, MQNIC_RB_IF_REG_COUNT);
    dev->if_stride = mqnic_reg_read32(dev->if_rb->regs, MQNIC_RB_IF_REG_STRIDE);
    dev->if_csr_offset = mqnic_reg_read32(dev->if_rb->regs, MQNIC_RB_IF_REG_CSR_OFFSET);

    if (dev->if_count > MQNIC_MAX_IF)
        dev->if_count = MQNIC_MAX_IF;

    for (int k = 0; k < dev->if_count; k++)
    {
        struct mqnic_if *interface = mqnic_if_open(dev, k, dev->regs + dev->if_offset + k*dev->if_stride);

        if (!interface)
        {
            fprintf(stderr, "Failed to create interface %d, skipping\n", k);
            continue;
        }

        dev->interfaces[k] = interface;
    }

skip_interface:
    return dev;

fail_open:
    free(dev);
fail_alloc:
    return NULL;
}

void mqnic_close(struct mqnic *dev)
{
    if (!dev)
        return;

    for (int k = 0; k < dev->if_count; k++)
    {
        if (!dev->interfaces[k])
            continue;

        mqnic_if_close(dev->interfaces[k]);
        dev->interfaces[k] = NULL;
    }

    if (dev->rb_list)
        mqnic_free_reg_block_list(dev->rb_list);

    if (dev->ram)
        munmap((void *)dev->ram, dev->ram_size);
    if (dev->app_regs)
        munmap((void *)dev->app_regs, dev->app_regs_size);
    if (dev->regs)
        munmap((void *)dev->regs, dev->regs_size);

    close(dev->fd);
    close(dev->app_fd);
    close(dev->ram_fd);

    free(dev);
}

void mqnic_print_fw_id(struct mqnic *dev)
{
    printf("FPGA ID: 0x%08x\n", dev->fpga_id);
    printf("FPGA part: %s\n", dev->fpga_part);
    printf("FW ID: 0x%08x\n", dev->fw_id);
    printf("FW version: %d.%d.%d.%d\n", dev->fw_ver >> 24,
            (dev->fw_ver >> 16) & 0xff,
            (dev->fw_ver >> 8) & 0xff,
            dev->fw_ver & 0xff);
    printf("Board ID: 0x%08x\n", dev->board_id);
    printf("Board version: %d.%d.%d.%d\n", dev->board_ver >> 24,
            (dev->board_ver >> 16) & 0xff,
            (dev->board_ver >> 8) & 0xff,
            dev->board_ver & 0xff);
    printf("Build date: %s UTC (raw 0x%08x)\n", dev->build_date_str, dev->build_date);
    printf("Git hash: %08x\n", dev->git_hash);
    printf("Release info: %08x\n", dev->rel_info);
    if (dev->app_id)
        printf("Application ID: 0x%08x\n", dev->app_id);
}
