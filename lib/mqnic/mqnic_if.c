// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <stdio.h>
#include <stdlib.h>

struct mqnic_if *mqnic_if_open(struct mqnic *dev, int index, volatile uint8_t *regs)
{
    struct mqnic_if *interface = calloc(1, sizeof(struct mqnic_if));
    uint32_t count, offset, stride;
    uint32_t val;

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
    interface->tx_fifo_depth = mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_TX_FIFO_DEPTH);
    interface->rx_fifo_depth = mqnic_reg_read32(interface->if_ctrl_rb->regs, MQNIC_RB_IF_CTRL_REG_RX_FIFO_DEPTH);

    interface->eq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_EQM_TYPE, MQNIC_RB_EQM_VER, 0);

    if (!interface->eq_rb)
    {
        fprintf(stderr, "Error: EQ block not found\n");
        goto fail;
    }

    offset = mqnic_reg_read32(interface->eq_rb->regs, MQNIC_RB_EQM_REG_OFFSET);
    count = mqnic_reg_read32(interface->eq_rb->regs, MQNIC_RB_EQM_REG_COUNT);
    stride = mqnic_reg_read32(interface->eq_rb->regs, MQNIC_RB_EQM_REG_STRIDE);

    if (count > MQNIC_MAX_EQ)
        count = MQNIC_MAX_EQ;

    interface->eq_res = mqnic_res_open(count, interface->regs + offset, stride);

    if (!interface->eq_res)
        goto fail;

    interface->cq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_CQM_TYPE, MQNIC_RB_CQM_VER, 0);

    if (!interface->cq_rb)
    {
        fprintf(stderr, "Error: CQ block not found\n");
        goto fail;
    }

    offset = mqnic_reg_read32(interface->cq_rb->regs, MQNIC_RB_CQM_REG_OFFSET);
    count = mqnic_reg_read32(interface->cq_rb->regs, MQNIC_RB_CQM_REG_COUNT);
    stride = mqnic_reg_read32(interface->cq_rb->regs, MQNIC_RB_CQM_REG_STRIDE);

    if (count > MQNIC_MAX_CQ)
        count = MQNIC_MAX_CQ;

    interface->cq_res = mqnic_res_open(count, interface->regs + offset, stride);

    if (!interface->cq_res)
        goto fail;

    interface->txq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_TX_QM_TYPE, MQNIC_RB_TX_QM_VER, 0);

    if (!interface->txq_rb)
    {
        fprintf(stderr, "Error: TXQ block not found\n");
        goto fail;
    }

    offset = mqnic_reg_read32(interface->txq_rb->regs, MQNIC_RB_TX_QM_REG_OFFSET);
    count = mqnic_reg_read32(interface->txq_rb->regs, MQNIC_RB_TX_QM_REG_COUNT);
    stride = mqnic_reg_read32(interface->txq_rb->regs, MQNIC_RB_TX_QM_REG_STRIDE);

    if (count > MQNIC_MAX_TXQ)
        count = MQNIC_MAX_TXQ;

    interface->txq_res = mqnic_res_open(count, interface->regs + offset, stride);

    if (!interface->txq_res)
        goto fail;

    interface->rxq_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_QM_TYPE, MQNIC_RB_RX_QM_VER, 0);

    if (!interface->rxq_rb)
    {
        fprintf(stderr, "Error: RXQ block not found\n");
        goto fail;
    }

    offset = mqnic_reg_read32(interface->rxq_rb->regs, MQNIC_RB_RX_QM_REG_OFFSET);
    count = mqnic_reg_read32(interface->rxq_rb->regs, MQNIC_RB_RX_QM_REG_COUNT);
    stride = mqnic_reg_read32(interface->rxq_rb->regs, MQNIC_RB_RX_QM_REG_STRIDE);

    if (count > MQNIC_MAX_RXQ)
        count = MQNIC_MAX_RXQ;

    interface->rxq_res = mqnic_res_open(count, interface->regs + offset, stride);

    if (!interface->rxq_res)
        goto fail;

    interface->rx_queue_map_rb = mqnic_find_reg_block(interface->rb_list, MQNIC_RB_RX_QUEUE_MAP_TYPE, MQNIC_RB_RX_QUEUE_MAP_VER, 0);

    if (!interface->rx_queue_map_rb)
    {
        fprintf(stderr, "Error: RX queue map block not found\n");
        goto fail;
    }

    val = mqnic_reg_read32(interface->rx_queue_map_rb->regs, MQNIC_RB_RX_QUEUE_MAP_REG_CFG);
    interface->rx_queue_map_indir_table_size = 1 << ((val >> 8) & 0xff);

    for (int k = 0; k < interface->port_count; k++)
    {
        interface->rx_queue_map_indir_table[k] = interface->regs + mqnic_reg_read32(interface->rx_queue_map_rb->regs, MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
            MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*k + MQNIC_RB_RX_QUEUE_MAP_CH_REG_OFFSET);
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

    mqnic_res_close(interface->eq_res);
    mqnic_res_close(interface->cq_res);
    mqnic_res_close(interface->txq_res);
    mqnic_res_close(interface->rxq_res);

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

uint32_t mqnic_interface_get_rx_queue_map_indir_table(struct mqnic_if *interface, int port, int index)
{
    return mqnic_reg_read32(interface->rx_queue_map_indir_table[port], index*4);
}
