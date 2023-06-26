// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <stdio.h>
#include <stdlib.h>

struct mqnic_sched_block *mqnic_sched_block_open(struct mqnic_if *interface, int index, struct mqnic_reg_block *block_rb)
{
    struct mqnic_sched_block *block = calloc(1, sizeof(struct mqnic_sched_block));

    if (!block)
        return NULL;

    int offset = mqnic_reg_read32(block_rb->regs, MQNIC_RB_SCHED_BLOCK_REG_OFFSET);

    block->mqnic = interface->mqnic;
    block->interface = interface;

    block->index = index;

    block->rb_list = mqnic_enumerate_reg_block_list(interface->regs, offset, interface->regs_size);

    if (!block->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail;
    }

    block->sched_count = 0;
    for (struct mqnic_reg_block *rb = block->rb_list; rb->type && rb->version; rb++)
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
        mqnic_free_reg_block_list(block->rb_list);

    free(block);
}
