// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2023 The Regents of the University of California
 */

#include "mqnic.h"

struct mqnic_res *mqnic_create_res(unsigned int count, u8 __iomem *base, unsigned int stride)
{
    struct mqnic_res *res;
    int ret;

    res = kzalloc(sizeof(*res), GFP_KERNEL);
    if (!res)
        return ERR_PTR(-ENOMEM);

    res->count = count;
    res->base = base;
    res->stride = stride;

    spin_lock_init(&res->lock);

    res->bmap = bitmap_zalloc(count, GFP_KERNEL);
    if (!res) {
        ret = -ENOMEM;
        goto fail;
    }

    return res;

fail:
    mqnic_destroy_res(res);
    return ERR_PTR(ret);
}

void mqnic_destroy_res(struct mqnic_res *res)
{
    if (!res)
        return;

    bitmap_free(res->bmap);

    kfree(res);
}

int mqnic_res_alloc(struct mqnic_res *res)
{
    int index;

    spin_lock(&res->lock);
    index = bitmap_find_free_region(res->bmap, res->count, 0);
    spin_unlock(&res->lock);

    return index;
}

void mqnic_res_free(struct mqnic_res *res, int index)
{
    if (index < 0 || index >= res->count)
        return;

    spin_lock(&res->lock);
    bitmap_clear(res->bmap, index, 1);
    spin_unlock(&res->lock);
}

unsigned int mqnic_res_get_count(struct mqnic_res *res)
{
    return res->count;
}

u8 __iomem *mqnic_res_get_addr(struct mqnic_res *res, int index)
{
    if (index < 0 || index >= res->count)
        return NULL;
    
    return res->base + index * res->stride;
}
