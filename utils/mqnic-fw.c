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
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

static void usage(char *name)
{
    fprintf(stderr,
        "usage: %s [options]\n"
        " -d name    device to open (/dev/mqnic0)\n",
        name);
}

int main(int argc, char *argv[])
{
    char *name;
    int opt;

    char *device = NULL;
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

    name = strrchr(argv[0], '/');
    name = name ? 1+name : argv[0];

    while ((opt = getopt(argc, argv, "d:h?")) != EOF)
    {
        switch (opt)
        {
        case 'd':
            device = optarg;
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

    volatile uint32_t *regs = mmap(NULL, 0x1000000, PROT_READ | PROT_WRITE, MAP_SHARED, dev_fd, 0);
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

    // dump regs
    printf("Flash ID:   %08x\n", regs[0x50]);
    printf("Flash Addr: %08x\n", regs[0x51]);
    printf("Flash Data: %08x\n", regs[0x52]);
    printf("Flash Ctrl: %08x\n", regs[0x53]);

    regs[0x53] = 0x0000000f;

    // write RCR to put flash in async mode
    regs[0x51] = 0x0000f94f;
    regs[0x52] = 0x0060;
    regs[0x53] = 0x00000102;
    regs[0x53] = 0x0000000f;
    regs[0x51] = 0x0000f94f;
    regs[0x52] = 0x0003;
    regs[0x53] = 0x00000102;
    regs[0x53] = 0x0000000f;

    // read flash ID
    regs[0x51] = 0x00000000;
    regs[0x52] = 0x0090;
    regs[0x53] = 0x00000102;
    regs[0x51] = 0x00000000;
    regs[0x53] = 0x00000004;

    // dump regs
    printf("Flash Addr: %08x\n", regs[0x51]);
    printf("Flash Data: %08x\n", regs[0x52]);
    printf("Flash Ctrl: %08x\n", regs[0x53]);

    regs[0x51] = 0x00000001;
    regs[0x53] = 0x00000004;

    // dump regs
    printf("Flash Addr: %08x\n", regs[0x51]);
    printf("Flash Data: %08x\n", regs[0x52]);
    printf("Flash Ctrl: %08x\n", regs[0x53]);

    regs[0x53] = 0x0000000f;

    // try reading a word from flash
    // read array
    regs[0x53] = 0x0000000f;
    regs[0x51] = 0x00000000 >> 1;
    regs[0x52] = 0x00ff;
    regs[0x53] = 0x00000102;
    regs[0x53] = 0x0000000f;

    // read word
    regs[0x51] = 0x00000050 >> 1;
    regs[0x53] = 0x00000004;

    // dump regs
    printf("Flash ID:   %08x\n", regs[0x50]);
    printf("Flash Addr: %08x\n", regs[0x51]);
    printf("Flash Data: %08x\n", regs[0x52]);
    printf("Flash Ctrl: %08x\n", regs[0x53]);

    regs[0x51] = 0x00000000;
    regs[0x53] = 0x0000000f;

err:

    munmap(regs, 0x1000000);

err_mmap_registers:

    close(dev_fd);

    return 0;
}




