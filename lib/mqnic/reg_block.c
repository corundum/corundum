// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
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
