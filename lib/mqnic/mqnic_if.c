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

#include <stdio.h>
#include <stdlib.h>

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
    interface->rb_list = mqnic_enumerate_reg_block_list(interface->regs, dev->if_csr_offset, interface->regs_size);

    if (!interface->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail;
    }

    interface->if_ctrl_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_IF_CTRL_TYPE, MQNIC_RB_IF_CTRL_VER, 0);

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

    interface->event_queue_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_EVENT_QM_TYPE, MQNIC_RB_EVENT_QM_VER, 0);

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

    interface->tx_queue_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_TX_QM_TYPE, MQNIC_RB_TX_QM_VER, 0);

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

    interface->tx_cpl_queue_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_TX_CQM_TYPE, MQNIC_RB_TX_CQM_VER, 0);

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

    interface->rx_queue_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_QM_TYPE, MQNIC_RB_RX_QM_VER, 0);

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

    interface->rx_cpl_queue_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_CQM_TYPE, MQNIC_RB_RX_CQM_VER, 0);

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

    interface->rx_queue_map_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_QUEUE_MAP_TYPE, MQNIC_RB_RX_QUEUE_MAP_VER, 0);

    if (!interface->rx_queue_map_rb)
    {
        fprintf(stderr, "Error: RX queue map block not found\n");
        goto fail;
    }

    for (int k = 0; k < interface->port_count; k++)
    {
        struct mqnic_reg_block *port_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_PORT_TYPE, MQNIC_RB_PORT_VER, k);
        struct mqnic_port *port;

        if (!port_rb)
            goto fail;

        port = mqnic_port_open(interface, k, port_rb);

        if (!port)
            goto fail;

        interface->ports[k] = port;
    }

    for (int k = 0; k < interface->sched_block_count; k++)
    {
        struct mqnic_reg_block *sched_block_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_SCHED_BLOCK_TYPE, MQNIC_RB_SCHED_BLOCK_VER, k);
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

    for (int k = 0; k < interface->port_count; k++)
    {
        if (!interface->ports[k])
            continue;

        mqnic_port_close(interface->ports[k]);
        interface->ports[k] = NULL;
    }

    if (interface->rb_list)
        mqnic_free_reg_block_list(interface->rb_list);

    free(interface);
}

uint32_t mqnic_interface_get_tx_mtu(struct mqnic_if *interface)
{
    return mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_TX_MTU);
}

uint32_t mqnic_interface_get_rx_mtu(struct mqnic_if *interface)
{
    return mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_RX_MTU);
}

uint32_t mqnic_interface_get_rx_queue_map_offset(struct mqnic_if *interface, int port)
{
    return mqnic_reg_read32(interface->rx_queue_map_rb->regs, MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
        MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_OFFSET);
}

uint32_t mqnic_interface_get_rx_queue_map_rss_mask(struct mqnic_if *interface, int port)
{
    return mqnic_reg_read32(interface->rx_queue_map_rb->regs, MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
        MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_RSS_MASK);
}

uint32_t mqnic_interface_get_rx_queue_map_app_mask(struct mqnic_if *interface, int port)
{
    return mqnic_reg_read32(interface->rx_queue_map_rb->regs, MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
        MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_APP_MASK);
}
