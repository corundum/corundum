// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 The Regents of the University of California
 */

#include "mqnic.h"

void mqnic_stats_init(struct mqnic *dev)
{
    dev->stats_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_STATS_TYPE, MQNIC_RB_STATS_VER, 0);

    if (!dev->stats_rb)
        return;

    dev->stats_offset = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_OFFSET);
    dev->stats_count = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_COUNT);
    dev->stats_stride = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_STRIDE);
    dev->stats_flags = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_FLAGS);
}

uint64_t mqnic_stats_read(struct mqnic *dev, int index)
{
    uint64_t val;

    if (!dev->stats_rb || index < 0 || index >= dev->stats_count)
        return 0;

    val = (uint64_t)mqnic_reg_read32(dev->regs, dev->stats_offset + index*8 + 0);
    val |= (uint64_t)mqnic_reg_read32(dev->regs, dev->stats_offset + index*8 + 4) << 32;

    return val;
}
