// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2020-2023 The Regents of the University of California
 */

#ifndef FLASH_H
#define FLASH_H

#include <stdint.h>
#include <unistd.h>

#define FLASH_ERASE_REGIONS 2

struct flash_driver;
struct flash_ops;

struct flash_erase_region_info {
    size_t block_count;
    size_t block_size;
    size_t region_start;
    size_t region_end;
};

struct flash_device {
    const struct flash_driver *driver;
    const struct flash_ops *ops;

    volatile uint8_t *ctrl_reg;
    volatile uint8_t *addr_reg;
    volatile uint8_t *data_reg;

    size_t size;
    int data_width;

    size_t write_buffer_size;
    size_t erase_block_size;

    int protocol;
    int bulk_protocol;

    int read_dummy_cycles;

    int erase_region_count;
    struct flash_erase_region_info erase_region[FLASH_ERASE_REGIONS];
};

struct flash_ops {
    void (*init)(struct flash_device *fdev);
    int (*sector_erase)(struct flash_device *fdev, size_t addr);
    int (*buffered_program)(struct flash_device *fdev, size_t addr, size_t len, const void *src);
};

struct flash_driver {
    int (*init)(struct flash_device *fdev);
    void (*release)(struct flash_device *fdev);
    int (*read)(struct flash_device *fdev, size_t addr, size_t len, void *dest);
    int (*write)(struct flash_device *fdev, size_t addr, size_t len, const void *src);
    int (*erase)(struct flash_device *fdev, size_t addr, size_t len);
};

struct flash_device *flash_open_spi(int data_width, volatile uint8_t *ctrl_reg);
struct flash_device *flash_open_bpi(int data_width, volatile uint8_t *ctrl_reg, volatile uint8_t *addr_reg, volatile uint8_t *data_reg);
void flash_release(struct flash_device *fdev);
int flash_read(struct flash_device *fdev, size_t addr, size_t len, void *dest);
int flash_write(struct flash_device *fdev, size_t addr, size_t len, const void *src);
int flash_erase(struct flash_device *fdev, size_t addr, size_t len);

#endif /* FLASH_H */
