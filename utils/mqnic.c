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

    if (fstat(dev->fd, &st))
    {
        perror("fstat failed");
        goto fail_fstat;
    }

    dev->regs_size = st.st_size;

    if (dev->regs_size == 0)
    {
        struct mqnic_ioctl_info info;
        if (ioctl(dev->fd, MQNIC_IOCTL_INFO, &info) != 0)
        {
            perror("MQNIC_IOCTL_INFO ioctl failed");
            goto fail_ioctl;
        }

        dev->regs_size = info.regs_size;
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

    // map registers
    dev->regs = (volatile uint8_t *)mmap(NULL, dev->regs_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, 0);
    if (dev->regs == MAP_FAILED)
    {
        perror("mmap regs failed");
        goto fail_mmap_regs;
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
    munmap((void *)dev->regs, dev->regs_size);
fail_mmap_regs:
fail_ioctl:
fail_fstat:
    close(dev->fd);
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

    // absolute path
    if (mqnic_try_open(dev, "%s", dev_name) == 0)
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

    munmap((void *)dev->regs, dev->regs_size);
    close(dev->fd);
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

    interface->if_ctrl_tx_rb = find_reg_block(interface->rb_list, MQNIC_RB_IF_CTRL_TX_TYPE, MQNIC_RB_IF_CTRL_TX_VER, 0);

    if (!interface->if_ctrl_tx_rb)
    {
        fprintf(stderr, "Error: TX interface control block not found\n");
        goto fail;
    }

    interface->if_tx_features = mqnic_reg_read32(interface->if_ctrl_tx_rb->regs, MQNIC_RB_IF_CTRL_TX_REG_FEATURES);
    interface->max_tx_mtu = mqnic_reg_read32(interface->if_ctrl_tx_rb->regs, MQNIC_RB_IF_CTRL_TX_REG_MAX_MTU);

    interface->if_ctrl_rx_rb = find_reg_block(interface->rb_list, MQNIC_RB_IF_CTRL_RX_TYPE, MQNIC_RB_IF_CTRL_RX_VER, 0);

    if (!interface->if_ctrl_rx_rb)
    {
        fprintf(stderr, "Error: RX interface control block not found\n");
        goto fail;
    }

    interface->if_rx_features = mqnic_reg_read32(interface->if_ctrl_rx_rb->regs, MQNIC_RB_IF_CTRL_RX_REG_FEATURES);
    interface->max_rx_mtu = mqnic_reg_read32(interface->if_ctrl_rx_rb->regs, MQNIC_RB_IF_CTRL_TX_REG_MAX_MTU);

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

    interface->port_count = 0;
    while (interface->port_count < MQNIC_MAX_PORTS)
    {
        struct reg_block *sched_block_rb = find_reg_block(interface->rb_list, MQNIC_RB_SCHED_BLOCK_TYPE, MQNIC_RB_SCHED_BLOCK_VER, interface->port_count);
        struct mqnic_port *port;

        if (!sched_block_rb)
            break;

        port = mqnic_port_open(interface, interface->port_count, sched_block_rb);

        if (!port)
            goto fail;

        interface->ports[interface->port_count++] = port;
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

    for (int k = 0; k < interface->port_count; k++)
    {
        if (!interface->ports[k])
            continue;

        mqnic_port_close(interface->ports[k]);
        interface->ports[k] = NULL;
    }

    if (interface->rb_list)
        free_reg_block_list(interface->rb_list);

    free(interface);
}

struct mqnic_port *mqnic_port_open(struct mqnic_if *interface, int index, struct reg_block *block_rb)
{
    struct mqnic_port *port = calloc(1, sizeof(struct mqnic_port));

    if (!port)
        return NULL;

    int offset = mqnic_reg_read32(block_rb->regs, MQNIC_RB_SCHED_BLOCK_REG_OFFSET);

    port->mqnic = interface->mqnic;
    port->interface = interface;

    port->index = index;

    port->rb_list = enumerate_reg_block_list(interface->regs, offset, interface->regs_size);

    if (!port->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail;
    }

    port->sched_count = 0;
    for (struct reg_block *rb = port->rb_list; rb->type && rb->version; rb++)
    {
        if (rb->type == MQNIC_RB_SCHED_RR_TYPE && rb->version == MQNIC_RB_SCHED_RR_VER)
        {
            struct mqnic_sched *sched = mqnic_sched_open(port, port->sched_count, rb);

            if (!sched)
                goto fail;

            port->sched[port->sched_count++] = sched;
        }
    }

    return port;

fail:
    mqnic_port_close(port);
    return NULL;
}

void mqnic_port_close(struct mqnic_port *port)
{
    if (!port)
        return;

    for (int k = 0; k < port->sched_count; k++)
    {
        if (!port->sched[k])
            continue;

        mqnic_sched_close(port->sched[k]);
        port->sched[k] = NULL;
    }

    if (port->rb_list)
        free_reg_block_list(port->rb_list);

    free(port);
}

struct mqnic_sched *mqnic_sched_open(struct mqnic_port *port, int index, struct reg_block *rb)
{
    struct mqnic_sched *sched = calloc(1, sizeof(struct mqnic_sched));

    if (!sched)
        return NULL;

    sched->mqnic = port->mqnic;
    sched->interface = port->interface;
    sched->port = port;

    sched->index = index;

    sched->rb = rb;
    sched->regs = rb->base + mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_OFFSET);

    if (sched->regs >= port->interface->regs+port->interface->regs_size)
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
