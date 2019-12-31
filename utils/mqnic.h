/*

Copyright 2019, The Regents of the University of California.
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

#ifndef MQNIC_H
#define MQNIC_H

#include <stdint.h>
#include <unistd.h>

#include "mqnic_hw.h"
#include "mqnic_ioctl.h"

#define mqnic_reg_read32(base, reg) (((volatile uint32_t *)(base))[(reg)/4])
#define mqnic_reg_write32(base, reg, val) (((volatile uint32_t *)(base))[(reg)/4]) = val

struct mqnic;

struct mqnic_sched {
    struct mqnic *mqnic;
    struct mqnic_if *mqnic_if;
    struct mqnic_port *mqnic_port;

    volatile uint8_t *regs;
};

struct mqnic_port {
    struct mqnic *mqnic;
    struct mqnic_if *mqnic_if;

    volatile uint8_t *regs;

    uint32_t port_id;
    uint32_t port_features;

    uint32_t sched_count;
    uint32_t sched_offset;
    uint32_t sched_stride;
    uint32_t sched_type;

    uint32_t tdma_timeslot_count;

    struct mqnic_sched sched[MQNIC_MAX_SCHED];
};

struct mqnic_if {
    struct mqnic *mqnic;

    volatile uint8_t *regs;
    volatile uint8_t *csr_regs;

    uint32_t if_id;
    uint32_t if_features;

    uint32_t event_queue_count;
    uint32_t event_queue_offset;
    uint32_t tx_queue_count;
    uint32_t tx_queue_offset;
    uint32_t tx_cpl_queue_count;
    uint32_t tx_cpl_queue_offset;
    uint32_t rx_queue_count;
    uint32_t rx_queue_offset;
    uint32_t rx_cpl_queue_count;
    uint32_t rx_cpl_queue_offset;

    uint32_t port_count;
    uint32_t port_offset;
    uint32_t port_stride;

    struct mqnic_port ports[MQNIC_MAX_PORTS];
};

struct mqnic {
    int fd;

    size_t regs_size;
    volatile uint8_t *regs;
    volatile uint8_t *phc_regs;

    uint32_t fw_id;
    uint32_t fw_ver;
    uint32_t board_id;
    uint32_t board_ver;

    uint32_t phc_count;
    uint32_t phc_offset;
    uint32_t phc_stride;

    uint32_t if_count;
    uint32_t if_stride;
    uint32_t if_csr_offset;

    struct mqnic_if interfaces[MQNIC_MAX_IF];
};

struct mqnic *mqnic_open(const char *dev_name);
void mqnic_close(struct mqnic *dev);

#endif /* MQNIC_H */
