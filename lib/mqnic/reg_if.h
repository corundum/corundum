// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

#ifndef REG_IF_H
#define REG_IF_H

#include <stdint.h>
#include <stddef.h>

struct mqnic_reg_if {
    const struct mqnic_reg_if_ops *ops;
    void *priv;
};

struct mqnic_reg_if_ops {
    int (*read8)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t *value);
    int (*write8)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t value);
    int (*read16)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t *value);
    int (*write16)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t value);
    int (*read32)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t *value);
    int (*write32)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t value);
    int (*read64)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t *value);
    int (*write64)(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t value);
};

int mqnic_reg_if_read8(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t *value);
int mqnic_reg_if_write8(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint8_t value);
int mqnic_reg_if_read16(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t *value);
int mqnic_reg_if_write16(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint16_t value);
int mqnic_reg_if_read32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t *value);
int mqnic_reg_if_write32(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint32_t value);
int mqnic_reg_if_read64(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t *value);
int mqnic_reg_if_write64(const struct mqnic_reg_if *reg, ptrdiff_t offset, uint64_t value);

void mqnic_reg_if_setup_raw(struct mqnic_reg_if *reg, void *regs);

#endif /* REG_IF_H */
