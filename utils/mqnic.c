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

#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>

struct mqnic *mqnic_open(const char *dev_name)
{
    struct mqnic *dev = calloc(1, sizeof(struct mqnic));
    struct stat st;

    if (!dev)
    {
        perror("memory allocation failed");
        goto fail_alloc;
    }

    dev->fd = open(dev_name, O_RDWR);

    if (dev->fd < 0)
    {
        perror("open device failed");
        goto fail_open;
    }

    if (fstat(dev->fd, &st) == -1)
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

    dev->regs = (volatile uint8_t *)mmap(NULL, dev->regs_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, 0);
    if (dev->regs == MAP_FAILED)
    {
        perror("mmap regs failed");
        goto fail_mmap_regs;
    }

    if (mqnic_reg_read32(dev->regs, MQNIC_REG_FW_ID) == 0xffffffff)
    {
        // if we were given a PCIe resource, then we may need to enable the device
        char path[PATH_MAX+32];
        char *ptr;

        strcpy(path, dev_name);
        ptr = strrchr(path, '/');
        if (ptr)
        {
            strcpy(++ptr, "enable");
        }

        if (access(path, F_OK) != -1)
        {
            FILE *fp = fopen(path, "w");

            if (fp)
            {
                fputc('1', fp);
                fclose(fp);
            }
        }
    }

    if (mqnic_reg_read32(dev->regs, MQNIC_REG_FW_ID) == 0xffffffff)
    {
        fprintf(stderr, "Error: device needs to be reset\n");
        goto fail_reset;
    }

    dev->fw_id = mqnic_reg_read32(dev->regs, MQNIC_REG_FW_ID);
    dev->fw_ver = mqnic_reg_read32(dev->regs, MQNIC_REG_FW_VER);
    dev->board_id = mqnic_reg_read32(dev->regs, MQNIC_REG_BOARD_ID);
    dev->board_ver = mqnic_reg_read32(dev->regs, MQNIC_REG_BOARD_VER);

    dev->phc_count = mqnic_reg_read32(dev->regs, MQNIC_REG_PHC_COUNT);
    dev->phc_offset = mqnic_reg_read32(dev->regs, MQNIC_REG_PHC_OFFSET);
    dev->phc_stride = mqnic_reg_read32(dev->regs, MQNIC_REG_PHC_STRIDE);

    if (dev->phc_count)
    {
        dev->phc_regs = dev->regs + dev->phc_offset;
    }

    dev->if_count = mqnic_reg_read32(dev->regs, MQNIC_REG_IF_COUNT);
    dev->if_stride = mqnic_reg_read32(dev->regs, MQNIC_REG_IF_STRIDE);
    dev->if_csr_offset = mqnic_reg_read32(dev->regs, MQNIC_REG_IF_CSR_OFFSET);

    if (dev->if_count > MQNIC_MAX_IF)
        dev->if_count = MQNIC_MAX_IF;

    for (int k = 0; k < dev->if_count; k++)
    {
        struct mqnic_if *interface = mqnic_if_open(dev, k, dev->regs + k*dev->if_stride);

        if (!interface)
            goto fail;

        dev->interfaces[k] = interface;
    }

    return dev;

fail:
fail_reset:
    mqnic_close(dev);
    return NULL;
fail_mmap_regs:
fail_ioctl:
fail_fstat:
    close(dev->fd);
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

    interface->if_id = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_IF_ID);
    interface->if_features = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_IF_FEATURES);

    interface->event_queue_count = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_EVENT_QUEUE_COUNT);
    interface->event_queue_offset = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_EVENT_QUEUE_OFFSET);
    interface->tx_queue_count = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_TX_QUEUE_COUNT);
    interface->tx_queue_offset = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_TX_QUEUE_OFFSET);
    interface->tx_cpl_queue_count = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_TX_CPL_QUEUE_COUNT);
    interface->tx_cpl_queue_offset = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_TX_CPL_QUEUE_OFFSET);
    interface->rx_queue_count = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_RX_QUEUE_COUNT);
    interface->rx_queue_offset = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_RX_QUEUE_OFFSET);
    interface->rx_cpl_queue_count = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_RX_CPL_QUEUE_COUNT);
    interface->rx_cpl_queue_offset = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_RX_CPL_QUEUE_OFFSET);

    interface->port_count = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_PORT_COUNT);
    interface->port_offset = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_PORT_OFFSET);
    interface->port_stride = mqnic_reg_read32(interface->csr_regs, MQNIC_IF_REG_PORT_STRIDE);

    if (interface->event_queue_count > MQNIC_MAX_EVENT_RINGS)
        interface->event_queue_count = MQNIC_MAX_EVENT_RINGS;
    if (interface->tx_queue_count > MQNIC_MAX_TX_RINGS)
        interface->tx_queue_count = MQNIC_MAX_TX_RINGS;
    if (interface->tx_cpl_queue_count > MQNIC_MAX_TX_CPL_RINGS)
        interface->tx_cpl_queue_count = MQNIC_MAX_TX_CPL_RINGS;
    if (interface->rx_queue_count > MQNIC_MAX_RX_RINGS)
        interface->rx_queue_count = MQNIC_MAX_RX_RINGS;
    if (interface->rx_cpl_queue_count > MQNIC_MAX_RX_CPL_RINGS)
        interface->rx_cpl_queue_count = MQNIC_MAX_RX_CPL_RINGS;

    if (interface->port_count > MQNIC_MAX_PORTS)
        interface->port_count = MQNIC_MAX_PORTS;

    for (int k = 0; k < interface->port_count; k++)
    {
        struct mqnic_port *port = mqnic_port_open(interface, k, interface->regs + interface->port_offset + k*interface->port_stride);

        if (!port)
            goto fail;

        interface->ports[k] = port;
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

    free(interface);
}

struct mqnic_port *mqnic_port_open(struct mqnic_if *interface, int index, volatile uint8_t *regs)
{
    struct mqnic_port *port = calloc(1, sizeof(struct mqnic_port));

    if (!port)
        return NULL;

    port->mqnic = interface->mqnic;
    port->interface = interface;

    port->index = index;

    port->regs_size = interface->port_stride;
    port->regs = regs;

    if (port->regs >= interface->regs+interface->regs_size)
    {
        fprintf(stderr, "Error: computed pointer out of range\n");
        goto fail;
    }

    port->port_id = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_PORT_ID);
    port->port_features = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_PORT_FEATURES);
    port->port_mtu = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_PORT_MTU);

    port->sched_count = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_SCHED_COUNT);
    port->sched_offset = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_SCHED_OFFSET);
    port->sched_stride = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_SCHED_STRIDE);
    port->sched_type = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_SCHED_TYPE);

    port->tdma_timeslot_count = mqnic_reg_read32(port->regs, MQNIC_PORT_REG_TDMA_TIMESLOT_COUNT);

    for (int k = 0; k < port->sched_count; k++)
    {
        struct mqnic_sched *sched = mqnic_sched_open(port, k, port->regs + port->sched_offset + k*port->sched_stride);

        if (!sched)
            goto fail;

        port->sched[k] = sched;
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

    free(port);
}

struct mqnic_sched *mqnic_sched_open(struct mqnic_port *port, int index, volatile uint8_t *regs)
{
    struct mqnic_sched *sched = calloc(1, sizeof(struct mqnic_sched));

    if (!sched)
        return NULL;

    sched->mqnic = port->mqnic;
    sched->interface = port->interface;
    sched->port = port;

    sched->index = index;

    sched->regs_size = port->sched_stride;
    sched->regs = regs;

    if (sched->regs >= port->interface->regs+port->interface->regs_size)
    {
        fprintf(stderr, "Error: computed pointer out of range\n");
        goto fail;
    }

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
