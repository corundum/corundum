/*

Copyright 2021, The Regents of the University of California.
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

#include "reg_block.h"

#include "mqnic.h"

#include <stdlib.h>
#include <stdio.h>

struct mqnic_reg_block *mqnic_enumerate_reg_block_list(volatile uint8_t *base, size_t offset, size_t size)
{
    int max_count = 8;
    struct mqnic_reg_block *reg_block_list = calloc(max_count, sizeof(struct mqnic_reg_block));
    int count = 0;

    volatile uint8_t *ptr;

    uint32_t rb_type;
    uint32_t rb_version;

    if (!reg_block_list)
        return NULL;

    while (1)
    {
        reg_block_list[count].type = 0;
        reg_block_list[count].version = 0;
        reg_block_list[count].base = 0;
        reg_block_list[count].regs = 0;

        if ((offset == 0 && count != 0) || offset >= size)
            break;

        ptr = base + offset;

        for (int k = 0; k < count; k++)
        {
            if (ptr == reg_block_list[k].regs)
            {
                fprintf(stderr, "Register blocks form a loop\n");
                goto fail;
            }
        }

        rb_type = *((uint32_t *)(ptr + MQNIC_RB_REG_TYPE));
        rb_version = *((uint32_t *)(ptr + MQNIC_RB_REG_VER));
        offset = *((uint32_t *)(ptr + MQNIC_RB_REG_NEXT_PTR));

        reg_block_list[count].type = rb_type;
        reg_block_list[count].version = rb_version;
        reg_block_list[count].base = base;
        reg_block_list[count].regs = ptr;

        count++;

        if (count >= max_count)
        {
            struct mqnic_reg_block *tmp;
            max_count += 4;
            tmp = realloc(reg_block_list, max_count * sizeof(struct mqnic_reg_block));
            if (!tmp)
                goto fail;
            reg_block_list = tmp;
        }
    }

    return reg_block_list;
fail:
    free(reg_block_list);
    return NULL;
}

struct mqnic_reg_block *mqnic_find_reg_block(struct mqnic_reg_block *list, uint32_t type, uint32_t version, int index)
{
    struct mqnic_reg_block *rb = list;

    while (rb->regs)
    {
        if (rb->type == type && (!version || rb->version == version))
        {
            if (index > 0)
            {
                index--;
            }
            else
            {
                return rb;
            }
        }

        rb++;
    }

    return NULL;
}

void mqnic_free_reg_block_list(struct mqnic_reg_block *list)
{
    free(list);
}
