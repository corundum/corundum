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
