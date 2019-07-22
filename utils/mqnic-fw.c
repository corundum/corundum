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

#include "mqnic.h"

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

    struct mqnic *dev;

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
    printf("IF count: %d\n", dev->if_count);
    printf("IF stride: 0x%08x\n", dev->if_stride);
    printf("IF CSR offset: 0x%08x\n", dev->if_csr_offset);

    // dump regs
    printf("Flash ID:   %08x\n", mqnic_reg_read32(dev->regs, 0x140));
    printf("Flash Addr: %08x\n", mqnic_reg_read32(dev->regs, 0x144));
    printf("Flash Data: %08x\n", mqnic_reg_read32(dev->regs, 0x148));
    printf("Flash Ctrl: %08x\n", mqnic_reg_read32(dev->regs, 0x14c));

    // release control lines
    mqnic_reg_write32(dev->regs, 0x14c, 0x0000000f);

    // write RCR to put flash in async mode
    mqnic_reg_write32(dev->regs, 0x144, 0x0000f94f);
    mqnic_reg_write32(dev->regs, 0x148, 0x0060);
    mqnic_reg_write32(dev->regs, 0x14c, 0x00000102);
    mqnic_reg_write32(dev->regs, 0x14c, 0x0000000f);
    mqnic_reg_write32(dev->regs, 0x144, 0x0000f94f);
    mqnic_reg_write32(dev->regs, 0x148, 0x0003);
    mqnic_reg_write32(dev->regs, 0x14c, 0x00000102);
    mqnic_reg_write32(dev->regs, 0x14c, 0x0000000f);

    // read flash ID
    mqnic_reg_write32(dev->regs, 0x144, 0x00000000);
    mqnic_reg_write32(dev->regs, 0x148, 0x0090);
    mqnic_reg_write32(dev->regs, 0x14c, 0x00000102);
    mqnic_reg_write32(dev->regs, 0x14c, 0x00000004);

    // dump regs
    printf("Flash Addr: %08x\n", mqnic_reg_read32(dev->regs, 0x144));
    printf("Flash Data: %08x\n", mqnic_reg_read32(dev->regs, 0x148));
    printf("Flash Ctrl: %08x\n", mqnic_reg_read32(dev->regs, 0x14c));

    // read rest of flash ID
    mqnic_reg_write32(dev->regs, 0x144, 0x00000001);
    mqnic_reg_write32(dev->regs, 0x14c, 0x00000004);

    // dump regs
    printf("Flash Addr: %08x\n", mqnic_reg_read32(dev->regs, 0x144));
    printf("Flash Data: %08x\n", mqnic_reg_read32(dev->regs, 0x148));
    printf("Flash Ctrl: %08x\n", mqnic_reg_read32(dev->regs, 0x14c));

    // release control lines
    mqnic_reg_write32(dev->regs, 0x14c, 0x0000000f);

    // try reading a word from flash
    // read array
    mqnic_reg_write32(dev->regs, 0x144, 0x00000000 >> 1);
    mqnic_reg_write32(dev->regs, 0x148, 0x00ff);
    mqnic_reg_write32(dev->regs, 0x14c, 0x00000102);
    mqnic_reg_write32(dev->regs, 0x14c, 0x0000000f);

    // read word
    mqnic_reg_write32(dev->regs, 0x144, 0x00000050 >> 1);
    mqnic_reg_write32(dev->regs, 0x14c, 0x00000004);

    // dump regs
    printf("Flash Addr: %08x\n", mqnic_reg_read32(dev->regs, 0x144));
    printf("Flash Data: %08x\n", mqnic_reg_read32(dev->regs, 0x148));
    printf("Flash Ctrl: %08x\n", mqnic_reg_read32(dev->regs, 0x14c));

    // release address and control lines
    mqnic_reg_write32(dev->regs, 0x144, 0x00000000);
    mqnic_reg_write32(dev->regs, 0x14c, 0x0000000f);

    mqnic_close(dev);

    return 0;
}




