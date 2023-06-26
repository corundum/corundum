// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
 */

#ifndef DRP_H
#define DRP_H

#include <mqnic/reg_block.h>
#include <mqnic/reg_if.h>

int drp_rb_reg_read(const struct mqnic_reg_block *rb, uint32_t addr, uint32_t *val);
int drp_rb_reg_write(const struct mqnic_reg_block *rb, uint32_t addr, uint32_t val);

void drp_rb_reg_if_init(struct mqnic_reg_if *reg, struct mqnic_reg_block *rb);

#endif /* DRP_H */
