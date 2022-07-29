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

#ifndef XCVR_GT_H
#define XCVR_GT_H

#include <mqnic/mqnic.h>
#include <mqnic/reg_if.h>
#include "drp.h"

struct gt_pll {
    struct gt_quad *quad;
};

struct gt_ch {
    struct gt_quad *quad;
    struct gt_pll *pll;
    const struct gt_ch_ops *ops;
    void *priv;

    int index;
};

struct gt_quad {
    struct mqnic_reg_if reg;
    struct gt_pll pll;
    struct gt_ch ch[4];
    const struct gt_quad_ops *ops;
    void *priv;
    const char *type;

    int index;
    int ch_count;
    int gt_type;
};

struct gt_reg_val {
    uint16_t addr;
    uint16_t mask;
    uint16_t shift;
    uint16_t value;
};

struct gt_eyescan_params {
    uint64_t target_bit_count;
    int h_range;
    int h_start;
    int h_stop;
    int h_step;
    int v_range;
    int v_start;
    int v_stop;
    int v_step;
};

struct gt_eyescan_point {
    uint64_t error_count;
    uint64_t bit_count;
    int x;
    int y;
    int ut_sign;
};

struct gt_quad_ops {
    int (*init)(struct gt_quad *quad);
};

struct gt_ch_ops {
    int (*get_tx_reset)(struct gt_ch *ch, uint32_t *val);
    int (*set_tx_reset)(struct gt_ch *ch, uint32_t val);
    int (*tx_reset)(struct gt_ch *ch);
    int (*get_rx_reset)(struct gt_ch *ch, uint32_t *val);
    int (*set_rx_reset)(struct gt_ch *ch, uint32_t val);
    int (*rx_reset)(struct gt_ch *ch);
    int (*get_tx_data_width)(struct gt_ch *ch, uint32_t *val);
    int (*get_tx_int_data_width)(struct gt_ch *ch, uint32_t *val);
    int (*get_rx_data_width)(struct gt_ch *ch, uint32_t *val);
    int (*get_rx_int_data_width)(struct gt_ch *ch, uint32_t *val);
    int (*get_available_presets)(struct gt_ch *ch, const uint32_t **presets);
    int (*load_preset)(struct gt_ch *ch, uint32_t preset);
    int (*eyescan_start)(struct gt_ch *ch, struct gt_eyescan_params *params);
    int (*eyescan_step)(struct gt_ch *ch, struct gt_eyescan_point *point);
};

#define GT_PRESET_10G_DFE 0x0001010A
#define GT_PRESET_10G_LPM 0x0000010A
#define GT_PRESET_25G_DFE 0x0001190A
#define GT_PRESET_25G_LPM 0x0000190A

int gt_pll_reg_read(struct gt_pll *pll, uint32_t addr, uint32_t *val);
int gt_pll_reg_read_masked(struct gt_pll *pll, uint32_t addr, uint32_t *val, uint32_t mask, uint32_t shift);
int gt_pll_reg_write(struct gt_pll *pll, uint32_t addr, uint32_t val);
int gt_pll_reg_write_masked(struct gt_pll *pll, uint32_t addr, uint32_t val, uint32_t mask, uint32_t shift);
int gt_pll_reg_write_multiple(struct gt_pll *pll, const struct gt_reg_val *vals);

#define def_gt_pll_masked_reg_read16(prefix, name, addr, mask, shift) \
static inline int prefix##_pll_get_##name(struct gt_pll *pll, uint32_t *val) \
{ \
    return gt_pll_reg_read_masked(pll, addr, val, mask, shift); \
}

#define def_gt_pll_masked_reg_write16(prefix, name, addr, mask, shift) \
static inline int prefix##_pll_set_##name(struct gt_pll *pll, uint32_t val) \
{ \
    return gt_pll_reg_write_masked(pll, addr, val, mask, shift); \
}

#define def_gt_pll_masked_reg_rw16(prefix, name, addr, mask, shift) \
def_gt_pll_masked_reg_read16(prefix, name, addr, mask, shift) \
def_gt_pll_masked_reg_write16(prefix, name, addr, mask, shift)

int gt_ch_reg_read(struct gt_ch *ch, uint32_t addr, uint32_t *val);
int gt_ch_reg_read_masked(struct gt_ch *ch, uint32_t addr, uint32_t *val, uint32_t mask, uint32_t shift);
int gt_ch_reg_write(struct gt_ch *ch, uint32_t addr, uint32_t val);
int gt_ch_reg_write_masked(struct gt_ch *ch, uint32_t addr, uint32_t val, uint32_t mask, uint32_t shift);
int gt_ch_reg_write_multiple(struct gt_ch *ch, const struct gt_reg_val *vals);

#define def_gt_ch_masked_reg_read16(prefix, name, addr, mask, shift) \
static inline int prefix##_ch_get_##name(struct gt_ch *ch, uint32_t *val) \
{ \
    return gt_ch_reg_read_masked(ch, addr, val, mask, shift); \
}

#define def_gt_ch_masked_reg_write16(prefix, name, addr, mask, shift) \
static inline int prefix##_ch_set_##name(struct gt_ch *ch, uint32_t val) \
{ \
    return gt_ch_reg_write_masked(ch, addr, val, mask, shift); \
}

#define def_gt_ch_masked_reg_rw16(prefix, name, addr, mask, shift) \
def_gt_ch_masked_reg_read16(prefix, name, addr, mask, shift) \
def_gt_ch_masked_reg_write16(prefix, name, addr, mask, shift)

struct gt_quad *gt_create_quad_from_drp_rb(struct mqnic_reg_block *rb);
void gt_free_quad(struct gt_quad *quad);

int gt_ch_get_tx_reset(struct gt_ch *ch, uint32_t *val);
int gt_ch_set_tx_reset(struct gt_ch *ch, uint32_t val);
int gt_ch_tx_reset(struct gt_ch *ch);
int gt_ch_get_rx_reset(struct gt_ch *ch, uint32_t *val);
int gt_ch_set_rx_reset(struct gt_ch *ch, uint32_t val);
int gt_ch_rx_reset(struct gt_ch *ch);
int gt_ch_get_tx_data_width(struct gt_ch *ch, uint32_t *val);
int gt_ch_get_tx_int_data_width(struct gt_ch *ch, uint32_t *val);
int gt_ch_get_rx_data_width(struct gt_ch *ch, uint32_t *val);
int gt_ch_get_rx_int_data_width(struct gt_ch *ch, uint32_t *val);
int gt_ch_get_available_presets(struct gt_ch *ch, const uint32_t **presets);
int gt_ch_load_preset(struct gt_ch *ch, uint32_t preset);
int gt_ch_eyescan_start(struct gt_ch *ch, struct gt_eyescan_params *params);
int gt_ch_eyescan_step(struct gt_ch *ch, struct gt_eyescan_point *point);

#endif /* XCVR_GT_H */
