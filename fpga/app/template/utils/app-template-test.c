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

#include <stdio.h>
#include <string.h>

#include <mqnic/mqnic.h>

#define TEMPLATE_APP_ID 0x12340001

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

    if (dev->pci_device_path)
    {
        char *ptr = strrchr(dev->pci_device_path, '/');
        if (ptr)
            printf("PCIe ID: %s\n", ptr+1);
    }

    mqnic_print_fw_id(dev);

    if (!dev->app_regs)
    {
        fprintf(stderr, "Application section not present\n");
        goto err;
    }

    if (dev->app_id != TEMPLATE_APP_ID)
    {
        fprintf(stderr, "Unexpected application id (expected 0x%08x, got 0x%08x)\n", TEMPLATE_APP_ID, dev->app_id);
        goto err;
    }

    printf("App regs size: %ld\n", dev->app_regs_size);

    // Read/write test
    printf("Write to application registers\n");
    mqnic_reg_write32(dev->app_regs, 0, 0x11223344);

    printf("Read from application registers\n");
    printf("%08x\n", mqnic_reg_read32(dev->app_regs, 0));

err:
    mqnic_close(dev);
    return 0;
}
