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

#define NSEC_PER_SEC 1000000000

void ts_mod(int64_t *m_sec, int64_t *m_nsec, int64_t n_sec, int64_t n_nsec)
{
    int i = 0;

    // shift until larger
    while (n_sec < *m_sec || (n_sec == *m_sec && n_nsec < *m_nsec))
    {
        i++;
        n_nsec <<= 1;
        n_sec <<= 1;
        if (n_nsec > NSEC_PER_SEC)
        {
            n_nsec -= NSEC_PER_SEC;
            n_sec++;
        }
    }

    // subtract and shift back
    while (i > 0)
    {
        i--;
        if (n_sec & 1)
        {
            n_nsec += NSEC_PER_SEC;
        }
        n_nsec >>= 1;
        n_sec >>= 1;

        if (n_sec < *m_sec || (n_sec == *m_sec && n_nsec < *m_nsec))
        {
            *m_nsec -= n_nsec;
            *m_sec -= n_sec;

            if (*m_nsec < 0)
            {
                *m_nsec += NSEC_PER_SEC;
                (*m_sec)--;
            }
        }
    }
}

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
    int interface = 0;
    int port = 0;
    int dev_fd;

    uint32_t fw_id;
    uint32_t fw_ver;
    uint32_t board_id;
    uint32_t board_ver;
    uint32_t phc_count;
    uint32_t phc_offset;
    uint32_t if_count;
    uint32_t if_stride;
    uint32_t if_csr_offset;

    uint32_t if_id;
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

    int64_t cur_sec = 0;
    int64_t cur_nsec = 0;
    int64_t start_sec = 0;
    int64_t start_nsec = 0;
    int64_t period_sec = 0;
    int64_t period_nsec = 0;
    int64_t timeslot_period_sec = 0;
    int64_t timeslot_period_nsec = 0;
    int64_t active_period_sec = 0;
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

    dev_fd = open(device, O_RDWR);

    uint32_t *regs = mmap(NULL, 0x1000000, PROT_READ | PROT_WRITE, MAP_SHARED, dev_fd, 0);
    if (regs == MAP_FAILED)
    {
        perror("Registers mmap failed");
        goto err_mmap_registers;
    }

    fw_id = regs[0];
    fw_ver = regs[1];
    board_id = regs[2];
    board_ver = regs[3];

    phc_count = regs[4];
    phc_offset = regs[5];

    if_count = regs[8];
    if_stride = regs[9];
    if_csr_offset = regs[11];

    printf("FW ID: 0x%08x\n", fw_id);
    printf("FW version: %d.%d\n", fw_ver >> 16, fw_ver & 0xffff);
    printf("Board ID: 0x%08x\n", board_id);
    printf("Board version: %d.%d\n", board_ver >> 16, board_ver & 0xffff);
    printf("PHC count: %d\n", phc_count);
    printf("PHC offset: 0x%08x\n", phc_offset);
    printf("IF count: %d\n", if_count);
    printf("IF stride: 0x%08x\n", if_stride);
    printf("IF CSR offset: 0x%08x\n", if_csr_offset);

    if (phc_count == 0)
    {
        fprintf(stderr, "No PHC on card\n");
        goto err;
    }

    uint32_t *phc_regs = (uint32_t *)((uint8_t *)regs + phc_offset);

    if (interface < 0 || interface >= if_count)
    {
        fprintf(stderr, "Interface out of range\n");
        goto err;
    }

    uint32_t *if_regs = (uint32_t *)((uint8_t *)regs + interface * if_stride);
    uint32_t *if_csr_regs = (uint32_t *)((uint8_t *)if_regs + if_csr_offset);

    if_id = if_csr_regs[0];
    printf("IF ID: 0x%08x\n", if_id);

    event_queue_count = if_csr_regs[4];
    event_queue_offset = if_csr_regs[5];
    tx_queue_count = if_csr_regs[8];
    tx_queue_offset = if_csr_regs[9];
    tx_cpl_queue_count = if_csr_regs[10];
    tx_cpl_queue_offset = if_csr_regs[11];
    rx_queue_count = if_csr_regs[12];
    rx_queue_offset = if_csr_regs[13];
    rx_cpl_queue_count = if_csr_regs[14];
    rx_cpl_queue_offset = if_csr_regs[15];
    port_count = if_csr_regs[16];
    port_offset = if_csr_regs[17];
    port_stride = if_csr_regs[18];
    
    printf("Event queue count: %d\n", event_queue_count);
    printf("Event queue offset: 0x%08x\n", event_queue_offset);
    printf("TX queue count: %d\n", tx_queue_count);
    printf("TX queue offset: 0x%08x\n", tx_queue_offset);
    printf("TX completion queue count: %d\n", tx_cpl_queue_count);
    printf("TX completion queue offset: 0x%08x\n", tx_cpl_queue_offset);
    printf("RX queue count: %d\n", rx_queue_count);
    printf("RX queue offset: 0x%08x\n", rx_queue_offset);
    printf("RX completion queue count: %d\n", rx_cpl_queue_count);
    printf("RX completion queue offset: 0x%08x\n", rx_cpl_queue_offset);
    printf("Port count: %d\n", port_count);
    printf("Port offset: 0x%08x\n", port_offset);
    printf("Port stride: 0x%08x\n", port_stride);

    if (port < 0 || port >= port_count)
    {
        fprintf(stderr, "Port out of range\n");
        goto err;
    }

    uint32_t *port_regs = (uint32_t *)((uint8_t *)if_regs + port_offset + port * port_stride);

    if (period_nsec > 0)
    {
        printf("Configure port TDMA schedule\n");

        cur_nsec = phc_regs[5];
        cur_sec = phc_regs[6] + (((int64_t)phc_regs[7]) << 32);

        // normalize start
        start_sec = start_nsec / NSEC_PER_SEC;
        start_nsec -= start_sec * NSEC_PER_SEC;

        // normalize period
        period_sec = period_nsec / NSEC_PER_SEC;
        period_nsec -= period_sec * NSEC_PER_SEC;

        printf("time   %ld.%09ld\n", cur_sec, cur_nsec);
        printf("start  %ld.%09ld\n", start_sec, start_nsec);
        printf("period %ld.%09ld\n", period_sec, period_nsec);

        if (start_sec < cur_sec || (start_sec == cur_sec && start_nsec < cur_sec))
        {
            // start time is in the past

            // modulo start with period
            ts_mod(&start_sec, &start_nsec, period_sec, period_nsec);

            // align time with period
            int64_t m_sec = cur_sec;
            int64_t m_nsec = cur_nsec;

            ts_mod(&m_sec, &m_nsec, period_sec, period_nsec);

            // add current time and normalize
            start_nsec += cur_nsec;
            start_sec += cur_sec;

            if (start_nsec > NSEC_PER_SEC)
            {
                start_nsec -= NSEC_PER_SEC;
                start_sec++;
            }

            // subtract remainder
            start_nsec -= m_nsec;
            start_sec -= m_sec;

            // re-normalize
            if (start_nsec < 0)
            {
                start_nsec += NSEC_PER_SEC;
                start_sec--;
            }
        }

        printf("time   %ld.%09ld\n", cur_sec, cur_nsec);
        printf("start  %ld.%09ld\n", start_sec, start_nsec);
        printf("period %ld.%09ld\n", period_sec, period_nsec);

        port_regs[0x45] = start_nsec;
        port_regs[0x46] = start_sec & 0xffffffff;
        port_regs[0x47] = start_sec >> 32;
        port_regs[0x49] = period_nsec;
        port_regs[0x4a] = period_sec & 0xffffffff;
        port_regs[0x4b] = period_sec >> 32;

        port_regs[0x40] = 0x00000001;
    }

    if (timeslot_period_nsec > 0)
    {
        printf("Configure port TDMA timeslot period\n");

        // normalize period
        timeslot_period_sec = timeslot_period_nsec / NSEC_PER_SEC;
        timeslot_period_nsec -= timeslot_period_sec * NSEC_PER_SEC;

        printf("period %ld.%09ld\n", timeslot_period_sec, timeslot_period_nsec);

        port_regs[0x4d] = timeslot_period_nsec;
        port_regs[0x4e] = timeslot_period_sec & 0xffffffff;
        port_regs[0x4f] = timeslot_period_sec >> 32;
    }

    if (active_period_nsec > 0)
    {
        printf("Configure port TDMA active period\n");

        // normalize period
        active_period_sec = active_period_nsec / NSEC_PER_SEC;
        active_period_nsec -= active_period_sec * NSEC_PER_SEC;

        printf("period %ld.%09ld\n", active_period_sec, active_period_nsec);

        port_regs[0x51] = active_period_nsec;
        port_regs[0x52] = active_period_sec & 0xffffffff;
        port_regs[0x53] = active_period_sec >> 32;
    }

err:

    munmap(regs, 0x1000000);

err_mmap_registers:

    close(dev_fd);

    return 0;
}




