/*

Copyright 2020, The Regents of the University of California.
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

#include "flash.h"

#include <stdlib.h>

extern const struct flash_driver spi_flash_driver;
extern const struct flash_driver bpi_flash_driver;

struct flash_device *flash_open_spi(int data_width, volatile uint8_t *ctrl_reg)
{
    struct flash_device *fdev;

    if (!ctrl_reg)
        return NULL;

    fdev = calloc(1, sizeof(struct flash_device));

    if (!fdev)
        return NULL;

    fdev->driver = &spi_flash_driver;

    fdev->data_width = data_width;

    fdev->ctrl_reg = ctrl_reg;

    if (fdev->driver->init(fdev))
    {
        goto err;
    }

    return fdev;

err:
    flash_release(fdev);
    return NULL;
}

struct flash_device *flash_open_bpi(int data_width, volatile uint8_t *ctrl_reg, volatile uint8_t *addr_reg, volatile uint8_t *data_reg)
{
    struct flash_device *fdev;

    if (!ctrl_reg || !addr_reg || !data_reg)
        return NULL;

    fdev = calloc(1, sizeof(struct flash_device));

    if (!fdev)
        return NULL;

    fdev->driver = &bpi_flash_driver;

    fdev->data_width = data_width;

    fdev->ctrl_reg = ctrl_reg;
    fdev->addr_reg = addr_reg;
    fdev->data_reg = data_reg;

    if (fdev->driver->init(fdev))
    {
        goto err;
    }

    return fdev;

err:
    flash_release(fdev);
    return NULL;
}

void flash_release(struct flash_device *fdev)
{
    if (!fdev)
        return;

    fdev->driver->release(fdev);

    free(fdev);
}

int flash_read(struct flash_device *fdev, size_t addr, size_t len, void* dest)
{
    if (!fdev)
        return -1;

    return fdev->driver->read(fdev, addr, len, dest);
}

int flash_write(struct flash_device *fdev, size_t addr, size_t len, void* src)
{
    if (!fdev)
        return -1;

    return fdev->driver->write(fdev, addr, len, src);
}

int flash_erase(struct flash_device *fdev, size_t addr, size_t len)
{
    if (!fdev)
        return -1;

    return fdev->driver->erase(fdev, addr, len);
}

