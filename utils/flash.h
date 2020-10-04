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
    int (*buffered_program)(struct flash_device *fdev, size_t addr, size_t len, void *src);
};

struct flash_driver {
    int (*init)(struct flash_device *fdev);
    void (*release)(struct flash_device *fdev);
    int (*read)(struct flash_device *fdev, size_t addr, size_t len, void* dest);
    int (*write)(struct flash_device *fdev, size_t addr, size_t len, void* src);
    int (*erase)(struct flash_device *fdev, size_t addr, size_t len);
};

struct flash_device *flash_open_spi(int data_width, volatile uint8_t *ctrl_reg);
struct flash_device *flash_open_bpi(int data_width, volatile uint8_t *ctrl_reg, volatile uint8_t *addr_reg, volatile uint8_t *data_reg);
void flash_release(struct flash_device *fdev);
int flash_read(struct flash_device *fdev, size_t addr, size_t len, void* dest);
int flash_write(struct flash_device *fdev, size_t addr, size_t len, void* src);
int flash_erase(struct flash_device *fdev, size_t addr, size_t len);

#endif /* FLASH_H */
