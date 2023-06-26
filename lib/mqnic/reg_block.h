// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

#ifndef REG_BLOCK_H
#define REG_BLOCK_H

#include <stdint.h>
#include <unistd.h>

struct mqnic_reg_block {
    uint32_t type;
    uint32_t version;
    volatile uint8_t *base;
    volatile uint8_t *regs;
};

struct mqnic_reg_block *mqnic_enumerate_reg_block_list(volatile uint8_t *base, size_t offset, size_t size);
struct mqnic_reg_block *mqnic_find_reg_block(struct mqnic_reg_block *list, uint32_t type, uint32_t version, int index);
void mqnic_free_reg_block_list(struct mqnic_reg_block *list);

#endif /* REG_BLOCK_H */
