// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2023, The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of The Regents of the
 * University of California.
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
