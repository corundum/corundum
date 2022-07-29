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
