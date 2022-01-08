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

#include <limits.h>
#include <stdint.h>
#include <unistd.h>

#include "mqnic_hw.h"
#include "mqnic_ioctl.h"
#include "reg_block.h"

#define mqnic_reg_read32(base, reg) (((volatile uint32_t *)(base))[(reg)/4])
#define mqnic_reg_write32(base, reg, val) (((volatile uint32_t *)(base))[(reg)/4]) = val

struct mqnic;

struct mqnic_sched {
    struct mqnic *mqnic;
    struct mqnic_if *interface;
    struct mqnic_port *port;

    int index;

    struct reg_block *rb;

    uint32_t type;
    uint32_t offset;
    uint32_t channel_count;
    uint32_t channel_stride;

    size_t regs_size;
    volatile uint8_t *regs;
};

struct mqnic_port {
    struct mqnic *mqnic;
    struct mqnic_if *interface;

    int index;

    size_t regs_size;
    volatile uint8_t *regs;

    struct reg_block *rb_list;

    uint32_t sched_count;
    struct mqnic_sched *sched[MQNIC_MAX_SCHED];
};

struct mqnic_if {
    struct mqnic *mqnic;

    int index;

    size_t regs_size;
    volatile uint8_t *regs;
    volatile uint8_t *csr_regs;

    struct reg_block *rb_list;
    struct reg_block *if_ctrl_tx_rb;
    struct reg_block *if_ctrl_rx_rb;
    struct reg_block *event_queue_rb;
    struct reg_block *tx_queue_rb;
    struct reg_block *tx_cpl_queue_rb;
    struct reg_block *rx_queue_rb;
    struct reg_block *rx_cpl_queue_rb;

    uint32_t if_tx_features;
    uint32_t if_rx_features;

    uint32_t max_tx_mtu;
    uint32_t max_rx_mtu;

    uint32_t event_queue_offset;
    uint32_t event_queue_count;
    uint32_t event_queue_stride;

    uint32_t tx_queue_offset;
    uint32_t tx_queue_count;
    uint32_t tx_queue_stride;
    uint32_t tx_cpl_queue_offset;
    uint32_t tx_cpl_queue_count;
    uint32_t tx_cpl_queue_stride;
    uint32_t rx_queue_offset;
    uint32_t rx_queue_count;
    uint32_t rx_queue_stride;
    uint32_t rx_cpl_queue_offset;
    uint32_t rx_cpl_queue_count;
    uint32_t rx_cpl_queue_stride;

    uint32_t port_count;
    struct mqnic_port *ports[MQNIC_MAX_PORTS];
};

struct mqnic {
    int fd;

    size_t regs_size;
    volatile uint8_t *regs;

    struct reg_block *rb_list;
    struct reg_block *fw_id_rb;
    struct reg_block *if_rb;
    struct reg_block *phc_rb;

    uint32_t fpga_id;
    uint32_t fw_id;
    uint32_t fw_ver;
    uint32_t board_id;
    uint32_t board_ver;
    uint32_t build_date;
    uint32_t git_hash;
    uint32_t rel_info;

    uint32_t if_offset;
    uint32_t if_count;
    uint32_t if_stride;
    uint32_t if_csr_offset;

    char build_date_str[32];

    struct mqnic_if *interfaces[MQNIC_MAX_IF];

    char device_path[PATH_MAX];
    char pci_device_path[PATH_MAX];
};

struct mqnic *mqnic_open(const char *dev_name);
void mqnic_close(struct mqnic *dev);

struct mqnic_if *mqnic_if_open(struct mqnic *dev, int index, volatile uint8_t *regs);
void mqnic_if_close(struct mqnic_if *interface);

struct mqnic_port *mqnic_port_open(struct mqnic_if *interface, int index, struct reg_block *block_rb);
void mqnic_port_close(struct mqnic_port *port);

struct mqnic_sched *mqnic_sched_open(struct mqnic_port *port, int index, struct reg_block *rb);
void mqnic_sched_close(struct mqnic_sched *sched);

#endif /* MQNIC_H */
