// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <stdio.h>
#include <stdlib.h>

struct mqnic_sched *mqnic_sched_open(struct mqnic_sched_block *block, int index, struct mqnic_reg_block *rb)
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
