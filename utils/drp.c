// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

#include <mqnic/mqnic.h>
#include <mqnic/reg_if.h>

int drp_rb_reg_read(const struct mqnic_reg_block *rb, uint32_t addr, uint32_t *val)
{
    mqnic_reg_write32(rb->regs, 0x14, addr);
    mqnic_reg_write32(rb->regs, 0x10, 0x00000001);
    mqnic_reg_read32(rb->regs, 0x10);
    if ((mqnic_reg_read32(rb->regs, 0x10) & 0x00000101) != 0)
        return -1;
    *val = mqnic_reg_read32(rb->regs, 0x1C);
    return 0;
}

int drp_rb_reg_write(const struct mqnic_reg_block *rb, uint32_t addr, uint32_t val)
{
    mqnic_reg_write32(rb->regs, 0x14, addr);
    mqnic_reg_write32(rb->regs, 0x18, val);
    mqnic_reg_write32(rb->regs, 0x10, 0x00000003);
    mqnic_reg_read32(rb->regs, 0x10);
    if ((mqnic_reg_read32(rb->regs, 0x10) & 0x00000101) != 0)
        return -1;
    return 0;
}

static int drp_rb_reg_if_read32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t *value)
{
    return drp_rb_reg_read((const struct mqnic_reg_block *)reg->priv, offset, value);
}

static int drp_rb_reg_if_write32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t value)
{
    return drp_rb_reg_write((const struct mqnic_reg_block *)reg->priv, offset, value);
}

static const struct mqnic_reg_if_ops drp_rb_reg_if_ops = {
    .read32 = drp_rb_reg_if_read32,
    .write32 = drp_rb_reg_if_write32
};

void drp_rb_reg_if_init(struct mqnic_reg_if *reg, struct mqnic_reg_block *rb)
{
    reg->priv = rb;
    reg->ops = &drp_rb_reg_if_ops;
}
