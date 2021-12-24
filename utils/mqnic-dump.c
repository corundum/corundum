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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mqnic.h"

static void usage(char *name)
{
    fprintf(stderr,
        "usage: %s [options]\n"
        " -d name    device to open (/dev/mqnic0)\n"
        " -i number  interface\n"
        " -P number  port\n",
        name);
}

int main(int argc, char *argv[])
{
    char *name;
    int opt;
    int ret = 0;

    char *device = NULL;
    struct mqnic *dev;
    int interface = 0;
    int port = 0;

    name = strrchr(argv[0], '/');
    name = name ? 1+name : argv[0];

    while ((opt = getopt(argc, argv, "d:i:P:h?")) != EOF)
    {
        switch (opt)
        {
        case 'd':
            device = optarg;
            break;
        case 'i':
            interface = atoi(optarg);
            break;
        case 'P':
            port = atoi(optarg);
            break;
        case 'h':
        case '?':
            usage(name);
            return 0;
        default:
            usage(name);
            return -1;
        }
    }

    if (!device)
    {
        fprintf(stderr, "Device not specified\n");
        usage(name);
        return -1;
    }

    dev = mqnic_open(device);

    if (!dev)
    {
        fprintf(stderr, "Failed to open device\n");
        return -1;
    }

    printf("FW ID: 0x%08x\n", dev->fw_id);
    printf("FW version: %d.%d\n", dev->fw_ver >> 16, dev->fw_ver & 0xffff);
    printf("Board ID: 0x%08x\n", dev->board_id);
    printf("Board version: %d.%d\n", dev->board_ver >> 16, dev->board_ver & 0xffff);
    printf("PHC count: %d\n", dev->phc_count);
    printf("PHC offset: 0x%08x\n", dev->phc_offset);
    printf("PHC stride: 0x%08x\n", dev->phc_stride);
    printf("IF count: %d\n", dev->if_count);
    printf("IF stride: 0x%08x\n", dev->if_stride);
    printf("IF CSR offset: 0x%08x\n", dev->if_csr_offset);

    for (int k = 0; k < dev->phc_count; k++)
    {
        volatile uint8_t *phc_base = dev->phc_regs + k*dev->phc_stride;

        printf("PHC%d features: 0x%08x\n", k, mqnic_reg_read32(phc_base, MQNIC_PHC_REG_FEATURES));

        printf("PHC%d time: %ld.%09d s\n", k, mqnic_reg_read32(phc_base, MQNIC_PHC_REG_PTP_CUR_SEC_L) + (((int64_t)mqnic_reg_read32(phc_base, MQNIC_PHC_REG_PTP_CUR_SEC_H)) << 32), mqnic_reg_read32(phc_base, MQNIC_PHC_REG_PTP_CUR_NS));
        printf("PHC%d period:     %d ns 0x%08x fns\n", k, mqnic_reg_read32(phc_base, MQNIC_PHC_REG_PTP_PERIOD_NS), mqnic_reg_read32(phc_base, MQNIC_PHC_REG_PTP_PERIOD_FNS));
        printf("PHC%d nom period: %d ns 0x%08x fns\n", k, mqnic_reg_read32(phc_base, MQNIC_PHC_REG_PTP_NOM_PERIOD_NS), mqnic_reg_read32(phc_base, MQNIC_PHC_REG_PTP_NOM_PERIOD_FNS));

        for (int ch = 0; ch < (mqnic_reg_read32(phc_base, MQNIC_PHC_REG_FEATURES) & 0xff); ch++)
        {
            volatile uint8_t *perout_base = phc_base + MQNIC_PHC_PEROUT_OFFSET + MQNIC_PHC_PEROUT_STRIDE*ch;

            printf("PHC%d perout ch %d ctrl:   0x%08x\n", k, ch, mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_CTRL));
            printf("PHC%d perout ch %d status: 0x%08x\n", k, ch, mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_STATUS));
            printf("PHC%d perout ch %d start:  %ld.%09d s\n", k, ch, mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_START_SEC_L) + (((int64_t)mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_START_SEC_H)) << 32), mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_START_NS));
            printf("PHC%d perout ch %d period: %ld.%09d s\n", k, ch, mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_PERIOD_SEC_L) + (((int64_t)mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_PERIOD_SEC_H)) << 32), mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_PERIOD_NS));
            printf("PHC%d perout ch %d width:  %ld.%09d s\n", k, ch, mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_WIDTH_SEC_L) + (((int64_t)mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_WIDTH_SEC_H)) << 32), mqnic_reg_read32(perout_base, MQNIC_PHC_REG_PEROUT_WIDTH_NS));
        }
    }

    if (interface < 0 || interface >= dev->if_count)
    {
        fprintf(stderr, "Interface out of range\n");
        ret = -1;
        goto err;
    }

    struct mqnic_if *dev_interface = dev->interfaces[interface];

    if (!dev_interface)
    {
        fprintf(stderr, "Invalid interface\n");
        ret = -1;
        goto err;
    }

    printf("IF ID: 0x%08x\n", dev_interface->if_id);
    printf("IF features: 0x%08x\n", dev_interface->if_features);
    
    printf("Event queue count: %d\n", dev_interface->event_queue_count);
    printf("Event queue offset: 0x%08x\n", dev_interface->event_queue_offset);
    printf("TX queue count: %d\n", dev_interface->tx_queue_count);
    printf("TX queue offset: 0x%08x\n", dev_interface->tx_queue_offset);
    printf("TX completion queue count: %d\n", dev_interface->tx_cpl_queue_count);
    printf("TX completion queue offset: 0x%08x\n", dev_interface->tx_cpl_queue_offset);
    printf("RX queue count: %d\n", dev_interface->rx_queue_count);
    printf("RX queue offset: 0x%08x\n", dev_interface->rx_queue_offset);
    printf("RX completion queue count: %d\n", dev_interface->rx_cpl_queue_count);
    printf("RX completion queue offset: 0x%08x\n", dev_interface->rx_cpl_queue_offset);
    printf("Port count: %d\n", dev_interface->port_count);
    printf("Port offset: 0x%08x\n", dev_interface->port_offset);
    printf("Port stride: 0x%08x\n", dev_interface->port_stride);

    if (port < 0 || port >= dev_interface->port_count)
    {
        fprintf(stderr, "Port out of range\n");
        ret = -1;
        goto err;
    }

    struct mqnic_port *dev_port = dev_interface->ports[port];

    if (!dev_port)
    {
        fprintf(stderr, "Invalid port\n");
        ret = -1;
        goto err;
    }

    printf("Port ID: 0x%08x\n", dev_port->port_id);
    printf("Port features: 0x%08x\n", dev_port->port_features);
    printf("Port MTU: %d\n", dev_port->port_mtu);
    
    printf("Sched count: %d\n", dev_port->sched_count);
    printf("Sched offset: 0x%08x\n", dev_port->sched_offset);
    printf("Sched stride: 0x%08x\n", dev_port->sched_stride);
    printf("Sched type: 0x%08x\n", dev_port->sched_type);

    printf("TX MTU: %d\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TX_MTU));
    printf("RX MTU: %d\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_RX_MTU));

    if (dev->phc_count > 0)
    {
        printf("TDMA control: 0x%08x\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_CTRL));
        printf("TDMA status:  0x%08x\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_STATUS));
        printf("TDMA timeslot count: %d\n", dev_port->tdma_timeslot_count);

        printf("TDMA schedule start:  %ld.%09d s\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_START_SEC_L) + (((int64_t)mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_START_SEC_H)) << 32), mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_START_NS));
        printf("TDMA schedule period: %ld.%09d s\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_L) + (((int64_t)mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_H)) << 32), mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_PERIOD_NS));
        printf("TDMA timeslot period: %ld.%09d s\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_L) + (((int64_t)mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_H)) << 32), mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_NS));
        printf("TDMA active period:   %ld.%09d s\n", mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_L) + (((int64_t)mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_H)) << 32), mqnic_reg_read32(dev_port->regs, MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_NS));
    }

    printf("TX queue info\n");
    printf("  Queue      Base Address     E  B  LS   CPL    Head    Tail     Len\n");
    for (int k = 0; k < dev_interface->tx_queue_count; k++)
    {
        volatile uint8_t *base = dev_interface->regs+dev_interface->tx_queue_offset+k*MQNIC_QUEUE_STRIDE;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_REG+4) << 32);
        uint8_t active = (mqnic_reg_read32(base, MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) & MQNIC_QUEUE_ACTIVE_MASK) != 0;
        uint8_t log_desc_block_size = (mqnic_reg_read32(base, MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) >> 8) & 0xff;
        uint8_t log_queue_size = mqnic_reg_read32(base, MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) & 0xff;
        uint32_t cpl_queue_index = mqnic_reg_read32(base, MQNIC_QUEUE_CPL_QUEUE_INDEX_REG);
        uint32_t head_ptr = mqnic_reg_read32(base, MQNIC_QUEUE_HEAD_PTR_REG);
        uint32_t tail_ptr = mqnic_reg_read32(base, MQNIC_QUEUE_TAIL_PTR_REG);
        uint32_t occupancy = (head_ptr - tail_ptr) & 0xffff;

        printf("TXQ %4d  0x%016lx  %d  %d  %2d  %4d  %6d  %6d  %6d\n", k, base_addr, active, log_desc_block_size, log_queue_size, cpl_queue_index, head_ptr, tail_ptr, occupancy);
    }

    printf("TX completion queue info\n");
    printf("  Queue       Base Address     E  LS  A C   Int    Head    Tail     Len\n");
    for (int k = 0; k < dev_interface->tx_queue_count; k++)
    {
        volatile uint8_t *base = dev_interface->regs+dev_interface->tx_cpl_queue_offset+k*MQNIC_CPL_QUEUE_STRIDE;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_CPL_QUEUE_BASE_ADDR_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_CPL_QUEUE_BASE_ADDR_REG+4) << 32);
        uint8_t active = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG) & MQNIC_CPL_QUEUE_ACTIVE_MASK) != 0;
        uint8_t log_queue_size = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG) & 0xff;
        uint8_t armed = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & MQNIC_CPL_QUEUE_ARM_MASK) != 0;
        uint8_t continuous = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & MQNIC_CPL_QUEUE_CONT_MASK) != 0;
        uint32_t interrupt_index = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & 0xffff;
        uint32_t head_ptr = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_HEAD_PTR_REG);
        uint32_t tail_ptr = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_TAIL_PTR_REG);
        uint32_t occupancy = (head_ptr - tail_ptr) & 0xffff;

        printf("TXCQ %4d  0x%016lx  %d  %2d  %d %d  %4d  %6d  %6d  %6d\n", k, base_addr, active, log_queue_size, armed, continuous, interrupt_index, head_ptr, tail_ptr, occupancy);
    }

    printf("RX queue info\n");
    printf("  Queue      Base Address     E  B  LS   CPL    Head    Tail     Len\n");
    for (int k = 0; k < dev_interface->rx_queue_count; k++)
    {
        volatile uint8_t *base = dev_interface->regs+dev_interface->rx_queue_offset+k*MQNIC_QUEUE_STRIDE;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_REG+4) << 32);
        uint8_t active = (mqnic_reg_read32(base, MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) & MQNIC_QUEUE_ACTIVE_MASK) != 0;
        uint8_t log_desc_block_size = (mqnic_reg_read32(base, MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) >> 8) & 0xff;
        uint8_t log_queue_size = mqnic_reg_read32(base, MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG) & 0xff;
        uint32_t cpl_queue_index = mqnic_reg_read32(base, MQNIC_QUEUE_CPL_QUEUE_INDEX_REG);
        uint32_t head_ptr = mqnic_reg_read32(base, MQNIC_QUEUE_HEAD_PTR_REG);
        uint32_t tail_ptr = mqnic_reg_read32(base, MQNIC_QUEUE_TAIL_PTR_REG);
        uint32_t occupancy = (head_ptr - tail_ptr) & 0xffff;

        printf("RXQ %4d  0x%016lx  %d  %d  %2d  %4d  %6d  %6d  %6d\n", k, base_addr, active, log_desc_block_size, log_queue_size, cpl_queue_index, head_ptr, tail_ptr, occupancy);
    }

    printf("RX completion queue info\n");
    printf("  Queue       Base Address     E  LS  A C   Int    Head    Tail     Len\n");
    for (int k = 0; k < dev_interface->rx_queue_count; k++)
    {
        volatile uint8_t *base = dev_interface->regs+dev_interface->rx_cpl_queue_offset+k*MQNIC_CPL_QUEUE_STRIDE;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_CPL_QUEUE_BASE_ADDR_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_CPL_QUEUE_BASE_ADDR_REG+4) << 32);
        uint8_t active = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG) & MQNIC_CPL_QUEUE_ACTIVE_MASK) != 0;
        uint8_t log_queue_size = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG) & 0xff;
        uint8_t armed = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & MQNIC_CPL_QUEUE_ARM_MASK) != 0;
        uint8_t continuous = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & MQNIC_CPL_QUEUE_CONT_MASK) != 0;
        uint32_t interrupt_index = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & 0xffff;
        uint32_t head_ptr = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_HEAD_PTR_REG);
        uint32_t tail_ptr = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_TAIL_PTR_REG);
        uint32_t occupancy = (head_ptr - tail_ptr) & 0xffff;

        printf("RXCQ %4d  0x%016lx  %d  %2d  %d %d  %4d  %6d  %6d  %6d\n", k, base_addr, active, log_queue_size, armed, continuous, interrupt_index, head_ptr, tail_ptr, occupancy);
    }

    printf("Event queue info\n");
    printf(" Queue      Base Address     E  LS  A C   Int    Head    Tail     Len\n");
    for (int k = 0; k < dev_interface->event_queue_count; k++)
    {
        volatile uint8_t *base = dev_interface->regs+dev_interface->event_queue_offset+k*MQNIC_CPL_QUEUE_STRIDE;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_CPL_QUEUE_BASE_ADDR_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_CPL_QUEUE_BASE_ADDR_REG+4) << 32);
        uint8_t active = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG) & MQNIC_CPL_QUEUE_ACTIVE_MASK) != 0;
        uint8_t log_queue_size = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG) & 0xff;
        uint8_t armed = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & MQNIC_CPL_QUEUE_ARM_MASK) != 0;
        uint8_t continuous = (mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & MQNIC_CPL_QUEUE_CONT_MASK) != 0;
        uint32_t interrupt_index = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG) & 0xffff;
        uint32_t head_ptr = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_HEAD_PTR_REG);
        uint32_t tail_ptr = mqnic_reg_read32(base, MQNIC_CPL_QUEUE_TAIL_PTR_REG);
        uint32_t occupancy = (head_ptr - tail_ptr) & 0xffff;

        printf("EQ %4d  0x%016lx  %d  %2d  %d %d  %4d  %6d  %6d  %6d\n", k, base_addr, active, log_queue_size, armed, continuous, interrupt_index, head_ptr, tail_ptr, occupancy);
    }

    for (int k = 0; k < dev_port->sched_count; k++)
    {
        printf("Port %d scheduler %d\n", port, k);
        for (int l = 0; l < dev_interface->tx_queue_count; l++)
        {
            printf("Sched %2d queue %4d state: 0x%08x\n", k, l, mqnic_reg_read32(dev_port->sched[k]->regs, l*4));
        }
    }

err:

    mqnic_close(dev);

    return ret;
}
