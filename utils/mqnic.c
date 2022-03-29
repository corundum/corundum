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

#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
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

    dev->rb_list = enumerate_reg_block_list(dev->regs, 0, dev->regs_size);

    if (!dev->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail_enum;
    }

    // Read ID registers
    dev->fw_id_rb = find_reg_block(dev->rb_list, MQNIC_RB_FW_ID_TYPE, MQNIC_RB_FW_ID_VER, 0);

    if (!dev->fw_id_rb)
    {
        fprintf(stderr, "Error: FW ID block not found\n");
        goto fail_enum;
    }

    return 0;

fail_enum:
    if (dev->rb_list)
        free_reg_block_list(dev->rb_list);
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

    time_t build_date = dev->build_date;
    struct tm *tm_info = gmtime(&build_date);
    strftime(dev->build_date_str, sizeof(dev->build_date_str), "%F %T", tm_info);

    dev->phc_rb = find_reg_block(dev->rb_list, MQNIC_RB_PHC_TYPE, MQNIC_RB_PHC_VER, 0);

    // Enumerate interfaces
    dev->if_rb = find_reg_block(dev->rb_list, MQNIC_RB_IF_TYPE, MQNIC_RB_IF_VER, 0);

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
        free_reg_block_list(dev->rb_list);

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


struct mqnic_if *mqnic_if_open(struct mqnic *dev, int index, volatile uint8_t *regs)
{
    struct mqnic_if *interface = calloc(1, sizeof(struct mqnic_if));

    if (!interface)
        return NULL;

    interface->mqnic = dev;

    interface->index = index;

    interface->regs_size = dev->if_stride;
    interface->regs = regs;
    interface->csr_regs = interface->regs + dev->if_csr_offset;

    if (interface->regs >= dev->regs+dev->regs_size || interface->csr_regs >= dev->regs+dev->regs_size)
    {
        fprintf(stderr, "Error: computed pointer out of range\n");
        goto fail;
    }

    // Enumerate registers
    interface->rb_list = enumerate_reg_block_list(interface->regs, dev->if_csr_offset, interface->regs_size);

    if (!interface->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail;
    }

    interface->if_ctrl_rb = find_reg_block(interface->rb_list, MQNIC_RB_IF_CTRL_TYPE, MQNIC_RB_IF_CTRL_VER, 0);

    if (!interface->if_ctrl_rb)
    {
        fprintf(stderr, "Error: Interface control block not found\n");
        goto fail;
    }

    interface->if_features = mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_FEATURES);
    interface->port_count = mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_PORT_COUNT);
    interface->sched_block_count = mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_SCHED_COUNT);
    interface->max_tx_mtu = mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_MAX_TX_MTU);
    interface->max_rx_mtu = mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_MAX_RX_MTU);

    interface->event_queue_rb = find_reg_block(interface->rb_list, MQNIC_RB_EVENT_QM_TYPE, MQNIC_RB_EVENT_QM_VER, 0);

    if (!interface->event_queue_rb)
    {
        fprintf(stderr, "Error: Event queue block not found\n");
        goto fail;
    }

    interface->event_queue_offset = mqnic_reg_read32(interface->event_queue_rb->regs, MQNIC_RB_EVENT_QM_REG_OFFSET);
    interface->event_queue_count = mqnic_reg_read32(interface->event_queue_rb->regs, MQNIC_RB_EVENT_QM_REG_COUNT);
    interface->event_queue_stride = mqnic_reg_read32(interface->event_queue_rb->regs, MQNIC_RB_EVENT_QM_REG_STRIDE);

    if (interface->event_queue_count > MQNIC_MAX_EVENT_RINGS)
        interface->event_queue_count = MQNIC_MAX_EVENT_RINGS;

    interface->tx_queue_rb = find_reg_block(interface->rb_list, MQNIC_RB_TX_QM_TYPE, MQNIC_RB_TX_QM_VER, 0);

    if (!interface->tx_queue_rb)
    {
        fprintf(stderr, "Error: TX queue block not found\n");
        goto fail;
    }

    interface->tx_queue_offset = mqnic_reg_read32(interface->tx_queue_rb->regs, MQNIC_RB_TX_QM_REG_OFFSET);
    interface->tx_queue_count = mqnic_reg_read32(interface->tx_queue_rb->regs, MQNIC_RB_TX_QM_REG_COUNT);
    interface->tx_queue_stride = mqnic_reg_read32(interface->tx_queue_rb->regs, MQNIC_RB_TX_QM_REG_STRIDE);

    if (interface->tx_queue_count > MQNIC_MAX_TX_RINGS)
        interface->tx_queue_count = MQNIC_MAX_TX_RINGS;

    interface->tx_cpl_queue_rb = find_reg_block(interface->rb_list, MQNIC_RB_TX_CQM_TYPE, MQNIC_RB_TX_CQM_VER, 0);

    if (!interface->tx_cpl_queue_rb)
    {
        fprintf(stderr, "Error: TX completion queue block not found\n");
        goto fail;
    }

    interface->tx_cpl_queue_offset = mqnic_reg_read32(interface->tx_cpl_queue_rb->regs, MQNIC_RB_TX_CQM_REG_OFFSET);
    interface->tx_cpl_queue_count = mqnic_reg_read32(interface->tx_cpl_queue_rb->regs, MQNIC_RB_TX_CQM_REG_COUNT);
    interface->tx_cpl_queue_stride = mqnic_reg_read32(interface->tx_cpl_queue_rb->regs, MQNIC_RB_TX_CQM_REG_STRIDE);

    if (interface->tx_cpl_queue_count > MQNIC_MAX_TX_CPL_RINGS)
        interface->tx_cpl_queue_count = MQNIC_MAX_TX_CPL_RINGS;

    interface->rx_queue_rb = find_reg_block(interface->rb_list, MQNIC_RB_RX_QM_TYPE, MQNIC_RB_RX_QM_VER, 0);

    if (!interface->rx_queue_rb)
    {
        fprintf(stderr, "Error: RX queue block not found\n");
        goto fail;
    }

    interface->rx_queue_offset = mqnic_reg_read32(interface->rx_queue_rb->regs, MQNIC_RB_RX_QM_REG_OFFSET);
    interface->rx_queue_count = mqnic_reg_read32(interface->rx_queue_rb->regs, MQNIC_RB_RX_QM_REG_COUNT);
    interface->rx_queue_stride = mqnic_reg_read32(interface->rx_queue_rb->regs, MQNIC_RB_RX_QM_REG_STRIDE);

    if (interface->rx_queue_count > MQNIC_MAX_RX_RINGS)
        interface->rx_queue_count = MQNIC_MAX_RX_RINGS;

    interface->rx_cpl_queue_rb = find_reg_block(interface->rb_list, MQNIC_RB_RX_CQM_TYPE, MQNIC_RB_RX_CQM_VER, 0);

    if (!interface->rx_cpl_queue_rb)
    {
        fprintf(stderr, "Error: RX completion queue block not found\n");
        goto fail;
    }

    interface->rx_cpl_queue_offset = mqnic_reg_read32(interface->rx_cpl_queue_rb->regs, MQNIC_RB_RX_CQM_REG_OFFSET);
    interface->rx_cpl_queue_count = mqnic_reg_read32(interface->rx_cpl_queue_rb->regs, MQNIC_RB_RX_CQM_REG_COUNT);
    interface->rx_cpl_queue_stride = mqnic_reg_read32(interface->rx_cpl_queue_rb->regs, MQNIC_RB_RX_CQM_REG_STRIDE);

    if (interface->rx_cpl_queue_count > MQNIC_MAX_RX_CPL_RINGS)
        interface->rx_cpl_queue_count = MQNIC_MAX_RX_CPL_RINGS;

    for (int k = 0; k < interface->sched_block_count; k++)
    {
        struct reg_block *sched_block_rb = find_reg_block(interface->rb_list, MQNIC_RB_SCHED_BLOCK_TYPE, MQNIC_RB_SCHED_BLOCK_VER, k);
        struct mqnic_sched_block *sched_block;

        if (!sched_block_rb)
            goto fail;

        sched_block = mqnic_sched_block_open(interface, k, sched_block_rb);

        if (!sched_block)
            goto fail;

        interface->sched_blocks[k] = sched_block;
    }

    return interface;

fail:
    mqnic_if_close(interface);
    return NULL;
}

void mqnic_if_close(struct mqnic_if *interface)
{
    if (!interface)
        return;

    for (int k = 0; k < interface->sched_block_count; k++)
    {
        if (!interface->sched_blocks[k])
            continue;

        mqnic_sched_block_close(interface->sched_blocks[k]);
        interface->sched_blocks[k] = NULL;
    }

    if (interface->rb_list)
        free_reg_block_list(interface->rb_list);

    free(interface);
}

struct mqnic_sched_block *mqnic_sched_block_open(struct mqnic_if *interface, int index, struct reg_block *block_rb)
{
    struct mqnic_sched_block *block = calloc(1, sizeof(struct mqnic_sched_block));

    if (!block)
        return NULL;

    int offset = mqnic_reg_read32(block_rb->regs, MQNIC_RB_SCHED_BLOCK_REG_OFFSET);

    block->mqnic = interface->mqnic;
    block->interface = interface;

    block->index = index;

    block->rb_list = enumerate_reg_block_list(interface->regs, offset, interface->regs_size);

    if (!block->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail;
    }

    block->sched_count = 0;
    for (struct reg_block *rb = block->rb_list; rb->type && rb->version; rb++)
    {
        if (rb->type == MQNIC_RB_SCHED_RR_TYPE && rb->version == MQNIC_RB_SCHED_RR_VER)
        {
            struct mqnic_sched *sched = mqnic_sched_open(block, block->sched_count, rb);

            if (!sched)
                goto fail;

            block->sched[block->sched_count++] = sched;
        }
    }

    return block;

fail:
    mqnic_sched_block_close(block);
    return NULL;
}

void mqnic_sched_block_close(struct mqnic_sched_block *block)
{
    if (!block)
        return;

    for (int k = 0; k < block->sched_count; k++)
    {
        if (!block->sched[k])
            continue;

        mqnic_sched_close(block->sched[k]);
        block->sched[k] = NULL;
    }

    if (block->rb_list)
        free_reg_block_list(block->rb_list);

    free(block);
}

struct mqnic_sched *mqnic_sched_open(struct mqnic_sched_block *block, int index, struct reg_block *rb)
{
    struct mqnic_sched *sched = calloc(1, sizeof(struct mqnic_sched));

    if (!sched)
        return NULL;

    sched->mqnic = block->mqnic;
    sched->interface = block->interface;
    sched->sched_block = block;

    sched->index = index;

    sched->rb = rb;
    sched->regs = rb->base + mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_OFFSET);

    if (sched->regs >= block->interface->regs+block->interface->regs_size)
    {
        fprintf(stderr, "Error: computed pointer out of range\n");
        goto fail;
    }

    sched->type = rb->type;
    sched->offset = mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_OFFSET);
    sched->channel_count = mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_CH_COUNT);
    sched->channel_stride = mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_CH_STRIDE);

    return sched;

fail:
    mqnic_sched_close(sched);
    return NULL;
}

void mqnic_sched_close(struct mqnic_sched *sched)
{
    if (!sched)
        return;

    free(sched);
}
