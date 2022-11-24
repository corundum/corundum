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

void mqnic_clk_info_init(struct mqnic *dev)
{
    dev->clk_info_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_CLK_INFO_TYPE, MQNIC_RB_CLK_INFO_VER, 0);

    if (!dev->clk_info_rb)
        return;

    uint32_t val = mqnic_reg_read32(dev->clk_info_rb->regs, MQNIC_RB_CLK_INFO_REF_NOM_PER);

    dev->ref_clk_nom_per_ns_num = val >> 16;
    dev->ref_clk_nom_per_ns_denom = val & 0xffff;
    dev->ref_clk_nom_freq_hz = (dev->ref_clk_nom_per_ns_denom * 1000000000ull) / dev->ref_clk_nom_per_ns_num;

    val = mqnic_reg_read32(dev->clk_info_rb->regs, MQNIC_RB_CLK_INFO_CLK_NOM_PER);

    dev->core_clk_nom_per_ns_num = val >> 16;
    dev->core_clk_nom_per_ns_denom = val & 0xffff;
    dev->core_clk_nom_freq_hz = (dev->core_clk_nom_per_ns_denom * 1000000000ull) / dev->core_clk_nom_per_ns_num;

    dev->clk_info_channels = mqnic_reg_read32(dev->clk_info_rb->regs, MQNIC_RB_CLK_INFO_COUNT);
}

uint32_t mqnic_get_core_clk_nom_freq_hz(struct mqnic *dev)
{
    return dev->core_clk_nom_freq_hz;
}

uint32_t mqnic_get_ref_clk_nom_freq_hz(struct mqnic *dev)
{
    return dev->ref_clk_nom_freq_hz;
}

uint32_t mqnic_get_core_clk_freq_hz(struct mqnic *dev)
{
    if (!dev->clk_info_rb)
        return 0;

    return mqnic_reg_read32(dev->clk_info_rb->regs, MQNIC_RB_CLK_INFO_CLK_FREQ);
}

uint32_t mqnic_get_clk_freq_hz(struct mqnic *dev, int ch)
{
    if (!dev->clk_info_rb || ch < 0 || ch >= dev->clk_info_channels)
        return 0;

    return mqnic_reg_read32(dev->clk_info_rb->regs, MQNIC_RB_CLK_INFO_FREQ_BASE + ch*4);
}

uint64_t mqnic_core_clk_cycles_to_ns(struct mqnic *dev, uint64_t cycles)
{
    if (!dev->clk_info_rb || !dev->core_clk_nom_per_ns_denom)
        return 0;

    return (cycles * (uint64_t)dev->core_clk_nom_per_ns_num) / (uint64_t)dev->core_clk_nom_per_ns_denom;
}

uint64_t mqnic_core_clk_ns_to_cycles(struct mqnic *dev, uint64_t ns)
{
    if (!dev->clk_info_rb || !dev->core_clk_nom_per_ns_num)
        return 0;

    return (ns * (uint64_t)dev->core_clk_nom_per_ns_denom) / (uint64_t)dev->core_clk_nom_per_ns_num;
}

uint64_t mqnic_ref_clk_cycles_to_ns(struct mqnic *dev, uint64_t cycles)
{
    if (!dev->clk_info_rb || !dev->ref_clk_nom_per_ns_denom)
        return 0;

    return (cycles * (uint64_t)dev->ref_clk_nom_per_ns_num) / (uint64_t)dev->ref_clk_nom_per_ns_denom;
}

uint64_t mqnic_ref_clk_ns_to_cycles(struct mqnic *dev, uint64_t ns)
{
    if (!dev->clk_info_rb || !dev->ref_clk_nom_per_ns_num)
        return 0;

    return (ns * (uint64_t)dev->ref_clk_nom_per_ns_denom) / (uint64_t)dev->ref_clk_nom_per_ns_num;
}
