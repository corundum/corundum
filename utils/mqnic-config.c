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

#include <errno.h>
#include <fcntl.h>
//#include <math.h>
//#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
//#include <sys/stat.h>
//#include <sys/time.h>
//#include <sys/timex.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include "timespec.h"

#include "mqnic.h"

#define NSEC_PER_SEC 1000000000

static void usage(char *name)
{
    fprintf(stderr,
        "usage: %s [options]\n"
        " -d name    device to open (/dev/mqnic0)\n"
        " -i number  interface\n"
        " -P number  port\n"
        " -s number  TDMA schedule start time (ns)\n"
        " -p number  TDMA schedule period (ns)\n"
        " -t number  TDMA timeslot period (ns)\n"
        " -a number  TDMA active period (ns)\n",
        name);
}

int main(int argc, char *argv[])
{
    char *name;
    int opt;

    char *device = NULL;
    struct mqnic *dev;
    int interface = 0;
    int port = 0;

    struct timespec ts_now;
    struct timespec ts_start;
    struct timespec ts_period;
    struct timespec ts_timeslot_period;
    struct timespec ts_active_period;

    int64_t start_nsec = 0;
    int64_t period_nsec = 0;
    int64_t timeslot_period_nsec = 0;
    int64_t active_period_nsec = 0;

    name = strrchr(argv[0], '/');
    name = name ? 1+name : argv[0];

    while ((opt = getopt(argc, argv, "d:i:P:s:p:t:a:h?")) != EOF)
    {
        switch (opt)
        {
        case 'd':
            device = optarg;
            break;
        case 'i':
            interface = atoi(optarg);
            break;
        case 'P':
            port = atoi(optarg);
            break;
        case 's':
            start_nsec = atoll(optarg);
            break;
        case 'p':
            period_nsec = atoll(optarg);
            break;
        case 't':
            timeslot_period_nsec = atoll(optarg);
            break;
        case 'a':
            active_period_nsec = atoll(optarg);
            break;
        case 'h':
        case '?':
            usage(name);
            return 0;
        default:
            usage(name);
            return -1;
        }
    }

    if (!device)
    {
        fprintf(stderr, "Device not specified\n");
        usage(name);
        return -1;
    }

    dev = mqnic_open(device);

    if (!dev)
    {
        fprintf(stderr, "Failed to open device\n");
        return -1;
    }

    printf("FW ID: 0x%08x\n", dev->fw_id);
    printf("FW version: %d.%d\n", dev->fw_ver >> 16, dev->fw_ver & 0xffff);
    printf("Board ID: 0x%08x\n", dev->board_id);
    printf("Board version: %d.%d\n", dev->board_ver >> 16, dev->board_ver & 0xffff);
    printf("PHC count: %d\n", dev->phc_count);
    printf("PHC offset: 0x%08x\n", dev->phc_offset);
    printf("PHC stride: 0x%08x\n", dev->phc_stride);
    printf("IF count: %d\n", dev->if_count);
    printf("IF stride: 0x%08x\n", dev->if_stride);
    printf("IF CSR offset: 0x%08x\n", dev->if_csr_offset);

    if (dev->phc_count == 0)
    {
        fprintf(stderr, "No PHC on card\n");
        goto err;
    }

    if (interface < 0 || interface >= dev->if_count)
    {
        fprintf(stderr, "Interface out of range\n");
        goto err;
    }

    struct mqnic_if *dev_interface = dev->interfaces[interface];

    if (!dev_interface)
    {
        fprintf(stderr, "Invalid interface\n");
        goto err;
    }

    printf("IF ID: 0x%08x\n", dev_interface->if_id);
    
    printf("Event queue count: %d\n", dev_interface->event_queue_count);
    printf("Event queue offset: 0x%08x\n", dev_interface->event_queue_offset);
    printf("TX queue count: %d\n", dev_interface->tx_queue_count);
    printf("TX queue offset: 0x%08x\n", dev_interface->tx_queue_offset);
    printf("TX completion queue count: %d\n", dev_interface->tx_cpl_queue_count);
    printf("TX completion queue offset: 0x%08x\n", dev_interface->tx_cpl_queue_offset);
    printf("RX queue count: %d\n", dev_interface->rx_queue_count);
    printf("RX queue offset: 0x%08x\n", dev_interface->rx_queue_offset);
    printf("RX completion queue count: %d\n", dev_interface->rx_cpl_queue_count);
    printf("RX completion queue offset: 0x%08x\n", dev_interface->rx_cpl_queue_offset);
    printf("Port count: %d\n", dev_interface->port_count);
    printf("Port offset: 0x%08x\n", dev_interface->port_offset);
    printf("Port stride: 0x%08x\n", dev_interface->port_stride);

    if (port < 0 || port >= dev_interface->port_count)
    {
        fprintf(stderr, "Port out of range\n");
        goto err;
    }

    struct mqnic_port *dev_port = dev_interface->ports[port];

    if (!dev_port)
    {
        fprintf(stderr, "Invalid port\n");
        goto err;
    }

    printf("Port ID: 0x%08x\n", dev_port->port_id);
    
    printf("Sched count: %d\n", dev_port->sched_count);
    printf("Sched offset: 0x%08x\n", dev_port->sched_offset);
    printf("Sched stride: 0x%08x\n", dev_port->sched_stride);
    printf("Sched type: 0x%08x\n", dev_port->sched_type);

    printf("Timeslot count: %d\n", dev_port->tdma_timeslot_count);

    if (period_nsec > 0)
    {
        printf("Configure port TDMA schedule\n");

        ts_now.tv_nsec = mqnic_reg_read32(dev->phc_regs, MQNIC_PHC_REG_PTP_CUR_NS);
        ts_now.tv_sec = mqnic_reg_read32(dev->phc_regs, MQNIC_PHC_REG_PTP_CUR_SEC_L) + (((int64_t)mqnic_reg_read32(dev->phc_regs, MQNIC_PHC_REG_PTP_CUR_SEC_H)) << 32);

        // normalize start
        ts_start.tv_sec = start_nsec / NSEC_PER_SEC;
        ts_start.tv_nsec = start_nsec - ts_start.tv_sec * NSEC_PER_SEC;

        // normalize period
        ts_period.tv_sec = period_nsec / NSEC_PER_SEC;
        ts_period.tv_nsec = period_nsec - ts_period.tv_sec * NSEC_PER_SEC;

        printf("time   %ld.%09ld s\n", ts_now.tv_sec, ts_now.tv_nsec);
        printf("start  %ld.%09ld s\n", ts_start.tv_sec, ts_start.tv_nsec);
        printf("period %ld.%09ld s\n", ts_period.tv_sec, ts_period.tv_nsec);

        if (timespec_lt(ts_start, ts_now))
        {
            // start time is in the past

            // modulo start with period
            ts_start = timespec_mod(ts_start, ts_period);

            // align time with period
            struct timespec ts_aligned = timespec_sub(ts_now, timespec_mod(ts_now, ts_period));

            // add aligned time
            ts_start = timespec_add(ts_start, ts_aligned);
        }

        printf("time   %ld.%09ld s\n", ts_now.tv_sec, ts_now.tv_nsec);
        printf("start  %ld.%09ld s\n", ts_start.tv_sec, ts_start.tv_nsec);
        printf("period %ld.%09ld s\n", ts_period.tv_sec, ts_period.tv_nsec);

        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_START_NS, ts_start.tv_nsec);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_START_SEC_L, ts_start.tv_sec & 0xffffffff);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_START_SEC_H, ts_start.tv_sec >> 32);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_PERIOD_NS, ts_period.tv_nsec);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_L, ts_period.tv_sec & 0xffffffff);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_H, ts_period.tv_sec >> 32);

        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_CTRL, 0x00000001);
    }

    if (timeslot_period_nsec > 0)
    {
        printf("Configure port TDMA timeslot period\n");

        // normalize period
        ts_timeslot_period.tv_sec = timeslot_period_nsec / NSEC_PER_SEC;
        ts_timeslot_period.tv_nsec = timeslot_period_nsec - ts_timeslot_period.tv_sec * NSEC_PER_SEC;

        printf("period %ld.%09ld s\n", ts_timeslot_period.tv_sec, ts_timeslot_period.tv_nsec);

        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_NS, ts_timeslot_period.tv_nsec);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_L, ts_timeslot_period.tv_sec & 0xffffffff);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_H, ts_timeslot_period.tv_sec >> 32);
    }

    if (active_period_nsec > 0)
    {
        printf("Configure port TDMA active period\n");

        // normalize period
        ts_active_period.tv_sec = active_period_nsec / NSEC_PER_SEC;
        ts_active_period.tv_nsec = active_period_nsec - ts_active_period.tv_sec * NSEC_PER_SEC;

        printf("period %ld.%09ld s\n", ts_active_period.tv_sec, ts_active_period.tv_nsec);

        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_NS, ts_active_period.tv_nsec);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_L, ts_active_period.tv_sec & 0xffffffff);
        mqnic_reg_write32(dev_port->regs, MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_H, ts_active_period.tv_sec >> 32);
    }

err:

    mqnic_close(dev);

    return 0;
}




