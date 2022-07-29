/*

Copyright 2022, The Regents of the University of California.
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

#include <stdlib.h>
#include "drp.h"
#include "xcvr_gt.h"

#include "xcvr_gthe3.h"
#include "xcvr_gtye3.h"
#include "xcvr_gthe4.h"
#include "xcvr_gtye4.h"

#include <stdio.h>

int gt_pll_reg_read(struct gt_pll *pll, uint32_t addr, uint32_t *val)
{
    if (!pll)
        return -1;

    return mqnic_reg_if_read32(&pll->quad->reg, addr | (1 << 19), val);
}

int gt_pll_reg_read_masked(struct gt_pll *pll, uint32_t addr, uint32_t *val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t v;

    ret = gt_pll_reg_read(pll, addr, &v);
    if (ret)
        return ret;

    *val = (v & mask) >> shift;
    return 0;
}

int gt_pll_reg_write(struct gt_pll *pll, uint32_t addr, uint32_t val)
{
    if (!pll)
        return -1;

    return mqnic_reg_if_write32(&pll->quad->reg, addr | (1 << 19), val);
}

int gt_pll_reg_write_masked(struct gt_pll *pll, uint32_t addr, uint32_t val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t old_val;

    ret = gt_pll_reg_read(pll, addr, &old_val);
    if (ret)
        return ret;

    return gt_pll_reg_write(pll, addr, ((val << shift) & mask) | (old_val & ~mask));
}

int gt_pll_reg_write_multiple(struct gt_pll *pll, const struct gt_reg_val *vals)
{
    int ret = 0;
    const struct gt_reg_val *val = vals;

    while (val && val->mask)
    {
        ret = gt_pll_reg_write_masked(pll, val->addr, val->value, val->mask, val->shift);
        if (ret)
            return ret;
        val++;
    }

    return 0;
}

int gt_ch_reg_read(struct gt_ch *ch, uint32_t addr, uint32_t *val)
{
    if (!ch)
        return -1;

    return mqnic_reg_if_read32(&ch->quad->reg, addr | (ch->index << 17), val);
}

int gt_ch_reg_read_masked(struct gt_ch *ch, uint32_t addr, uint32_t *val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t v;

    ret = gt_ch_reg_read(ch, addr, &v);
    if (ret)
        return ret;

    *val = (v & mask) >> shift;
    return 0;
}

int gt_ch_reg_write(struct gt_ch *ch, uint32_t addr, uint32_t val)
{
    if (!ch)
        return -1;

    return mqnic_reg_if_write32(&ch->quad->reg, addr | (ch->index << 17), val);
}

int gt_ch_reg_write_masked(struct gt_ch *ch, uint32_t addr, uint32_t val, uint32_t mask, uint32_t shift)
{
    int ret = 0;
    uint32_t old_val;

    ret = gt_ch_reg_read(ch, addr, &old_val);
    if (ret)
        return ret;

    return gt_ch_reg_write(ch, addr, ((val << shift) & mask) | (old_val & ~mask));
}

int gt_ch_reg_write_multiple(struct gt_ch *ch, const struct gt_reg_val *vals)
{
    int ret = 0;
    const struct gt_reg_val *val = vals;

    while (val && val->mask)
    {
        ret = gt_ch_reg_write_masked(ch, val->addr, val->value, val->mask, val->shift);
        if (ret)
            return ret;
        val++;
    }

    return 0;
}

struct gt_quad *gt_create_quad_from_drp_rb(struct mqnic_reg_block *rb)
{
    struct gt_quad *quad = calloc(1, sizeof(struct gt_quad));
    drp_rb_reg_if_init(&quad->reg, rb);
    quad->pll.quad = quad;

    uint32_t info = mqnic_reg_read32(rb->regs, 0x0C);

    quad->ch_count = info & 0xff;
    quad->gt_type = info >> 16;
    quad->type = "Unknown";

    switch (quad->gt_type) {
        case 0x0802:
            quad->ops = &gthe3_gt_quad_ops;
            break;
        case 0x0803:
            quad->ops = &gtye3_gt_quad_ops;
            break;
        case 0x0902:
            quad->ops = &gthe4_gt_quad_ops;
            break;
        case 0x0903:
            quad->ops = &gtye4_gt_quad_ops;
            break;
        default:
            goto err;
    }

    if (!quad->ops || !quad->ops->init)
        goto err;

    if (quad->ops->init(quad))
        goto err;

    return quad;

err:
    gt_free_quad(quad);
    return NULL;
}

void gt_free_quad(struct gt_quad *quad){
    free(quad);
}

int gt_ch_get_tx_reset(struct gt_ch *ch, uint32_t *val)
{
    if (!ch || !ch->ops || !ch->ops->get_tx_reset)
        return -1;

    return ch->ops->get_tx_reset(ch, val);
}

int gt_ch_set_tx_reset(struct gt_ch *ch, uint32_t val)
{
    if (!ch || !ch->ops || !ch->ops->set_tx_reset)
        return -1;

    return ch->ops->set_tx_reset(ch, val);
}

int gt_ch_tx_reset(struct gt_ch *ch)
{
    if (!ch || !ch->ops || !ch->ops->tx_reset)
        return -1;

    return ch->ops->tx_reset(ch);
}

int gt_ch_get_rx_reset(struct gt_ch *ch, uint32_t *val)
{
    if (!ch || !ch->ops || !ch->ops->get_rx_reset)
        return -1;

    return ch->ops->get_rx_reset(ch, val);
}

int gt_ch_set_rx_reset(struct gt_ch *ch, uint32_t val)
{
    if (!ch || !ch->ops || !ch->ops->set_rx_reset)
        return -1;

    return ch->ops->set_rx_reset(ch, val);
}

int gt_ch_rx_reset(struct gt_ch *ch)
{
    if (!ch || !ch->ops || !ch->ops->rx_reset)
        return -1;

    return ch->ops->rx_reset(ch);
}

int gt_ch_get_tx_data_width(struct gt_ch *ch, uint32_t *val)
{
    if (!ch || !ch->ops || !ch->ops->get_tx_data_width)
        return -1;

    return ch->ops->get_tx_data_width(ch, val);
}

int gt_ch_get_tx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    if (!ch || !ch->ops || !ch->ops->get_tx_int_data_width)
        return -1;

    return ch->ops->get_tx_int_data_width(ch, val);
}

int gt_ch_get_rx_data_width(struct gt_ch *ch, uint32_t *val)
{
    if (!ch || !ch->ops || !ch->ops->get_rx_data_width)
        return -1;

    return ch->ops->get_rx_data_width(ch, val);
}

int gt_ch_get_rx_int_data_width(struct gt_ch *ch, uint32_t *val)
{
    if (!ch || !ch->ops || !ch->ops->get_rx_int_data_width)
        return -1;

    return ch->ops->get_rx_int_data_width(ch, val);
}

int gt_ch_get_available_presets(struct gt_ch *ch, const uint32_t **presets)
{
    if (!ch || !ch->ops || !ch->ops->get_available_presets)
        return -1;

    return ch->ops->get_available_presets(ch, presets);
}

int gt_ch_load_preset(struct gt_ch *ch, uint32_t preset)
{
    if (!ch || !ch->ops || !ch->ops->load_preset)
        return -1;

    return ch->ops->load_preset(ch, preset);
}

int gt_ch_eyescan_start(struct gt_ch *ch, struct gt_eyescan_params *params)
{
    if (!ch || !ch->ops || !ch->ops->eyescan_start)
        return -1;

    return ch->ops->eyescan_start(ch, params);
}

int gt_ch_eyescan_step(struct gt_ch *ch, struct gt_eyescan_point *point)
{
    if (!ch || !ch->ops || !ch->ops->eyescan_step)
        return -1;

    return ch->ops->eyescan_step(ch, point);
}
