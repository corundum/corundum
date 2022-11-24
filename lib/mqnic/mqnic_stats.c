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

#include "mqnic.h"

void mqnic_stats_init(struct mqnic *dev)
{
    dev->stats_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_STATS_TYPE, MQNIC_RB_STATS_VER, 0);

    if (!dev->stats_rb)
        return;

    dev->stats_offset = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_OFFSET);
    dev->stats_count = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_COUNT);
    dev->stats_stride = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_STRIDE);
    dev->stats_flags = mqnic_reg_read32(dev->stats_rb->regs, MQNIC_RB_STATS_REG_FLAGS);
}

uint64_t mqnic_stats_read(struct mqnic *dev, int index)
{
    uint64_t val;

    if (!dev->stats_rb || index < 0 || index >= dev->stats_count)
        return 0;

    val = (uint64_t)mqnic_reg_read32(dev->regs, dev->stats_offset + index*8 + 0);
    val |= (uint64_t)mqnic_reg_read32(dev->regs, dev->stats_offset + index*8 + 4) << 32;

    return val;
}
