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
