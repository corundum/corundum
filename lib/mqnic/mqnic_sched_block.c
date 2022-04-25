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
