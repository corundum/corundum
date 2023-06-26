// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2020-2023 The Regents of the University of California
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

int flash_read(struct flash_device *fdev, size_t addr, size_t len, void *dest)
{
    if (!fdev)
        return -1;

    return fdev->driver->read(fdev, addr, len, dest);
}

int flash_write(struct flash_device *fdev, size_t addr, size_t len, const void *src)
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

