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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include <linux/ptp_clock.h>

#ifndef CLOCK_INVALID
#define CLOCK_INVALID -1
#endif

static clockid_t get_clockid(int fd)
{
#define CLOCKFD 3
#define FD_TO_CLOCKID(fd)   ((~(clockid_t) (fd) << 3) | CLOCKFD)

    return FD_TO_CLOCKID(fd);
}

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
        " -d name    device to open\n"
        " -s number  start time (ns)\n"
        " -p number  period (ns)\n",
        name);
}

int main(int argc, char *argv[])
{
    char *name;
    int opt;

    char *device = NULL;
    int ptp_fd;
    clockid_t clkid;

    struct ptp_perout_request perout_request;
    struct timespec ts;

    int64_t start_sec = 0;
    int64_t start_nsec = 0;
    int64_t period_sec = 0;
    int64_t period_nsec = 0;

    name = strrchr(argv[0], '/');
    name = name ? 1+name : argv[0];

    while ((opt = getopt(argc, argv, "d:s:p:h?")) != EOF)
    {
        switch (opt)
        {
        case 'd':
            device = optarg;
            break;
        case 's':
            start_nsec = atoll(optarg);
            break;
        case 'p':
            period_nsec = atoll(optarg);
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
        fprintf(stderr, "PTP device not specified\n");
        usage(name);
        return -1;
    }

    ptp_fd = open(device, O_RDWR);
    if (ptp_fd < 0)
    {
        fprintf(stderr, "Failed to open %s: %s\n", device, strerror(errno));
        return -1;
    }

    clkid = get_clockid(ptp_fd);
    if (clkid == CLOCK_INVALID)
    {
        fprintf(stderr, "Failed to read clock id\n");
        close(ptp_fd);
        return -1;
    }

    if (period_nsec > 0)
    {
        if (clock_gettime(clkid, &ts))
        {
            perror("Failed to read current time");
            return -1;
        }

        // normalize start
        start_sec = start_nsec / NSEC_PER_SEC;
        start_nsec -= start_sec * NSEC_PER_SEC;

        // normalize period
        period_sec = period_nsec / NSEC_PER_SEC;
        period_nsec -= period_sec * NSEC_PER_SEC;

        printf("time   %ld.%09ld\n", ts.tv_sec, ts.tv_nsec);
        printf("start  %ld.%09ld\n", start_sec, start_nsec);
        printf("period %ld.%09ld\n", period_sec, period_nsec);

        if (start_sec < ts.tv_sec || (start_sec == ts.tv_sec && start_nsec < ts.tv_sec))
        {
            // start time is in the past

            // modulo start with period
            ts_mod(&start_sec, &start_nsec, period_sec, period_nsec);

            // align time with period
            int64_t m_sec = ts.tv_sec;
            int64_t m_nsec = ts.tv_nsec;

            ts_mod(&m_sec, &m_nsec, period_sec, period_nsec);

            // add current time and normalize
            start_nsec += ts.tv_nsec;
            start_sec += ts.tv_sec;

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

        printf("time   %ld.%09ld\n", ts.tv_sec, ts.tv_nsec);
        printf("start  %ld.%09ld\n", start_sec, start_nsec);
        printf("period %ld.%09ld\n", period_sec, period_nsec);

        memset(&perout_request, 0, sizeof(perout_request));
        perout_request.index = 0;
        perout_request.start.sec = start_sec;
        perout_request.start.nsec = start_nsec;
        perout_request.period.sec = period_sec;
        perout_request.period.nsec = period_nsec;
        
        if (ioctl(ptp_fd, PTP_PEROUT_REQUEST, &perout_request))
        {
            perror("PTP_PEROUT_REQUEST ioctl failed");
        }
        else
        {
            printf("PTP_PEROUT_REQUEST ioctl OK\n");
        }
    }

    close(ptp_fd);
    return 0;
}




