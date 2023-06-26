// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

#include "reg_if.h"

int mqnic_reg_if_read8(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t *value)
{
    if (!reg || !reg->ops || !reg->ops->read8)
        return -1;
    return reg->ops->read8(reg, offset, value);
}

int mqnic_reg_if_write8(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t value)
{
    if (!reg || !reg->ops || !reg->ops->write8)
        return -1;
    return reg->ops->write8(reg, offset, value);
}

int mqnic_reg_if_read16(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t *value)
{
    if (!reg || !reg->ops || !reg->ops->read16)
        return -1;
    return reg->ops->read16(reg, offset, value);
}

int mqnic_reg_if_write16(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t value)
{
    if (!reg || !reg->ops || !reg->ops->write16)
        return -1;
    return reg->ops->write16(reg, offset, value);
}

int mqnic_reg_if_read32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t *value)
{
    if (!reg || !reg->ops || !reg->ops->read32)
        return -1;
    return reg->ops->read32(reg, offset, value);
}

int mqnic_reg_if_write32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t value)
{
    if (!reg || !reg->ops || !reg->ops->write32)
        return -1;
    return reg->ops->write32(reg, offset, value);
}

int mqnic_reg_if_read64(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t *value)
{
    if (!reg || !reg->ops || !reg->ops->read64)
        return -1;
    return reg->ops->read64(reg, offset, value);
}

int mqnic_reg_if_write64(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t value)
{
    if (!reg || !reg->ops || !reg->ops->write64)
        return -1;
    return reg->ops->write64(reg, offset, value);
}

static int mqnic_reg_if_raw_read8(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t *value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *value = *(volatile uint8_t *)(regs+offset);
    return 0;
}

static int mqnic_reg_if_raw_write8(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *(volatile uint8_t *)(regs+offset) = value;
    return 0;
}

static int mqnic_reg_if_raw_read16(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t *value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *value = *(volatile uint16_t *)(regs+offset);
    return 0;
}

static int mqnic_reg_if_raw_write16(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *(volatile uint16_t *)(regs+offset) = value;
    return 0;
}

static int mqnic_reg_if_raw_read32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t *value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *value = *(volatile uint32_t *)(regs+offset);
    return 0;
}

static int mqnic_reg_if_raw_write32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *(volatile uint32_t *)(regs+offset) = value;
    return 0;
}

static int mqnic_reg_if_raw_read64(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t *value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *value = *(volatile uint64_t *)(regs+offset);
    return 0;
}

static int mqnic_reg_if_raw_write64(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t value)
{
    uint8_t *regs = (uint8_t *)reg->priv;
    *(volatile uint64_t *)(regs+offset) = value;
    return 0;
}

static const struct mqnic_reg_if_ops mqnic_reg_if_raw_ops = {
    .read8 = mqnic_reg_if_raw_read8,
    .write8 = mqnic_reg_if_raw_write8,
    .read16 = mqnic_reg_if_raw_read16,
    .write16 = mqnic_reg_if_raw_write16,
    .read32 = mqnic_reg_if_raw_read32,
    .write32 = mqnic_reg_if_raw_write32,
    .read64 = mqnic_reg_if_raw_read64,
    .write64 = mqnic_reg_if_raw_write64
};

void mqnic_reg_if_setup_raw(struct mqnic_reg_if *reg, void *regs)
{
    reg->priv = regs;
    reg->ops = &mqnic_reg_if_raw_ops;
}
