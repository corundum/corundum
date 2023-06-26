// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <stdio.h>
#include <stdlib.h>

struct mqnic_res *mqnic_res_open(unsigned int count, volatile uint8_t *base, unsigned int stride)
{
    struct mqnic_res *res = calloc(1, sizeof(struct mqnic_res));

    if (!res)
        return NULL;

    res->count = count;
    res->base = base;
    res->stride = stride;

    return res;
}

void mqnic_res_close(struct mqnic_res *res)
{
    if (!res)
        return;

    free(res);
}

unsigned int mqnic_res_get_count(struct mqnic_res *res)
{
    return res->count;
}

volatile uint8_t *mqnic_res_get_addr(struct mqnic_res *res, int index)
{
    if (index < 0 || index >= res->count)
        return NULL;
    
    return res->base + index * res->stride;
}
