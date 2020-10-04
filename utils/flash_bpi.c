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

#include <stdio.h>
#include <stdlib.h>

#define reg_read32(reg) (*((volatile uint32_t *)(reg)))
#define reg_write32(reg, val) (*((volatile uint32_t *)(reg))) = (val)

#define CFI_QUERY_ADDR             0x55
#define CFI_QUERY_DATA             0x98
#define CFI_READ_ARRAY             0xFF
#define CFI_READ_ARRAY_ALT         0xF0
#define CFI_ID_0                   0x10
#define CFI_ID_1                   0x11
#define CFI_ID_2                   0x12
#define CFI_PRI_CMD_SET_0          0x13
#define CFI_PRI_CMD_SET_1          0x14
#define CFI_DEVICE_SIZE            0x27
#define CFI_WRITE_BUFFER_SIZE_0    0x2A
#define CFI_WRITE_BUFFER_SIZE_1    0x2B
#define CFI_ERASE_REGION_COUNT     0x2C
#define CFI_ERASE_REGION_1_INFO_0  0x2D
#define CFI_ERASE_REGION_1_INFO_1  0x2E
#define CFI_ERASE_REGION_1_INFO_2  0x2F
#define CFI_ERASE_REGION_1_INFO_3  0x30
#define CFI_ERASE_REGION_2_INFO_0  0x31
#define CFI_ERASE_REGION_2_INFO_1  0x32
#define CFI_ERASE_REGION_2_INFO_2  0x33
#define CFI_ERASE_REGION_2_INFO_3  0x34

#define BPI_INTEL_READ_ARRAY                0xFF
#define BPI_INTEL_READ_STATUS_REG           0x70
#define BPI_INTEL_READ_ID                   0x90
#define BPI_INTEL_CLEAR_STATUS_REG          0x50
#define BPI_INTEL_READ_CONFIG_REG_SETUP     0x60
#define BPI_INTEL_SET_READ_CONFIG_REG       0x03
#define BPI_INTEL_BLOCK_LOCK_SETUP          0x60
#define BPI_INTEL_BLOCK_LOCK                0x01
#define BPI_INTEL_BLOCK_UNLOCK              0xD0
#define BPI_INTEL_BLOCK_ERASE_SETUP         0x20
#define BPI_INTEL_BLOCK_ERASE_CONFIRM       0xD0
#define BPI_INTEL_BUFFERED_PROGRAM_SETUP    0xE8
#define BPI_INTEL_BUFFERED_PROGRAM_CONFIRM  0xD0

#define BPI_AMD_UNLOCK_ADDR_1             0x555
#define BPI_AMD_UNLOCK_DATA_1             0xAA
#define BPI_AMD_UNLOCK_ADDR_2             0x2AA
#define BPI_AMD_UNLOCK_DATA_2             0x55
#define BPI_AMD_UNLOCK_BYPASS_ENTER_ADDR  0x555
#define BPI_AMD_UNLOCK_BYPASS_ENTER_DATA  0x20
#define BPI_AMD_UNLOCK_BYPASS_RESET_1     0x90
#define BPI_AMD_UNLOCK_BYPASS_RESET_2     0x00
#define BPI_AMD_BLOCK_ERASE_SETUP         0x80
#define BPI_AMD_BLOCK_ERASE_CONFIRM       0x30
#define BPI_AMD_BUFFERED_PROGRAM_SETUP    0x25
#define BPI_AMD_BUFFERED_PROGRAM_CONFIRM  0x29
#define BPI_AMD_READ_ARRAY                0xF0

#define BPI_MICRON_READ_ARRAY                0xFF
#define BPI_MICRON_READ_STATUS_REG           0x70
#define BPI_MICRON_READ_ID                   0x90
#define BPI_MICRON_CLEAR_STATUS_REG          0x50
#define BPI_MICRON_READ_CONFIG_REG_SETUP     0x60
#define BPI_MICRON_SET_READ_CONFIG_REG       0x03
#define BPI_MICRON_BLOCK_LOCK_SETUP          0x60
#define BPI_MICRON_BLOCK_LOCK                0x01
#define BPI_MICRON_BLOCK_UNLOCK              0xD0
#define BPI_MICRON_BLOCK_ERASE_SETUP         0x20
#define BPI_MICRON_BLOCK_ERASE_CONFIRM       0xD0
#define BPI_MICRON_BUFFERED_PROGRAM_SETUP    0xE9
#define BPI_MICRON_BUFFERED_PROGRAM_CONFIRM  0xD0

#define FLASH_CE_N      (1 << 0)
#define FLASH_OE_N      (1 << 1)
#define FLASH_WE_N      (1 << 2)
#define FLASH_ADV_N     (1 << 3)
#define FLASH_DQ_OE     (1 << 8)
#define FLASH_REGION_OE (1 << 16)

void bpi_flash_set_addr(struct flash_device *fdev, size_t addr)
{
    reg_write32(fdev->addr_reg, addr);
}

uint16_t bpi_flash_read_cur(struct flash_device *fdev)
{
    uint16_t val;

    reg_write32(fdev->ctrl_reg, FLASH_REGION_OE | FLASH_WE_N);
    reg_read32(fdev->data_reg); // dummy read
    val = reg_read32(fdev->data_reg);
    reg_write32(fdev->ctrl_reg, FLASH_OE_N | FLASH_WE_N | FLASH_ADV_N);

    return val;
}

uint16_t bpi_flash_read_word(struct flash_device *fdev, size_t addr)
{
    bpi_flash_set_addr(fdev, addr);
    return bpi_flash_read_cur(fdev);
}

void bpi_flash_write_cur(struct flash_device *fdev, uint16_t data)
{
    reg_write32(fdev->data_reg, data);
    reg_write32(fdev->ctrl_reg, FLASH_REGION_OE | FLASH_DQ_OE | FLASH_OE_N);
    reg_read32(fdev->data_reg); // dummy read
    reg_write32(fdev->ctrl_reg, FLASH_OE_N | FLASH_WE_N | FLASH_ADV_N);
}

void bpi_flash_write_word(struct flash_device *fdev, size_t addr, uint16_t data)
{
    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, data);
}

void bpi_flash_deselect(struct flash_device *fdev)
{
    bpi_flash_write_word(fdev, 0, CFI_READ_ARRAY);
    reg_write32(fdev->ctrl_reg, FLASH_CE_N | FLASH_OE_N | FLASH_WE_N | FLASH_ADV_N);
}

// Intel flash ops (0x0001)

uint16_t bpi_flash_intel_read_status_register(struct flash_device *fdev)
{
    bpi_flash_write_cur(fdev, BPI_INTEL_READ_STATUS_REG);
    return bpi_flash_read_cur(fdev);
}

void bpi_flash_intel_clear_status_register(struct flash_device *fdev)
{
    bpi_flash_write_cur(fdev, BPI_INTEL_CLEAR_STATUS_REG);
}

void bpi_flash_intel_init(struct flash_device *fdev)
{
    bpi_flash_intel_clear_status_register(fdev);
}

int bpi_flash_intel_sector_erase(struct flash_device *fdev, size_t addr)
{
    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, BPI_INTEL_BLOCK_LOCK_SETUP);
    bpi_flash_write_cur(fdev, BPI_INTEL_BLOCK_UNLOCK);

    if (bpi_flash_intel_read_status_register(fdev) & 0x30)
    {
        fprintf(stderr, "Failed to unlock block\n");
        return -1;
    }

    bpi_flash_write_cur(fdev, BPI_INTEL_BLOCK_ERASE_SETUP);
    bpi_flash_write_cur(fdev, BPI_INTEL_BLOCK_ERASE_CONFIRM);

    while (!(bpi_flash_intel_read_status_register(fdev) & 0x80)) {};

    if (bpi_flash_intel_read_status_register(fdev) & 0x30)
    {
        fprintf(stderr, "Failed to erase block\n");
        return -1;
    }

    return 0;
}

int bpi_flash_intel_buffered_program(struct flash_device *fdev, size_t addr, size_t len, void *src)
{
    uint8_t *s = src;

    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, BPI_INTEL_BUFFERED_PROGRAM_SETUP);
    bpi_flash_write_cur(fdev, len-1);

    for (size_t i = 0; i < len; i++)
    {
        bpi_flash_write_word(fdev, addr+i, s[0] | (s[1] << 8));
        s += 2;
    }

    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, BPI_INTEL_BUFFERED_PROGRAM_CONFIRM);

    while (!(bpi_flash_intel_read_status_register(fdev) & 0x80)) {};

    if (bpi_flash_intel_read_status_register(fdev) & 0x30)
    {
        fprintf(stderr, "Failed to write block\n");
        return -1;
    }

    return 0;
}

const struct flash_ops bpi_flash_intel_ops = {
    .init = bpi_flash_intel_init,
    .sector_erase = bpi_flash_intel_sector_erase,
    .buffered_program = bpi_flash_intel_buffered_program
};

// AMD flash ops (0x0002)

void bpi_flash_amd_unlock(struct flash_device *fdev)
{
    bpi_flash_write_word(fdev, BPI_AMD_UNLOCK_ADDR_1, BPI_AMD_UNLOCK_DATA_1);
    bpi_flash_write_word(fdev, BPI_AMD_UNLOCK_ADDR_2, BPI_AMD_UNLOCK_DATA_2);
}

void bpi_flash_amd_write_buffer_abort_reset(struct flash_device *fdev)
{
    bpi_flash_amd_unlock(fdev);
    bpi_flash_write_word(fdev, BPI_AMD_UNLOCK_ADDR_1, BPI_AMD_READ_ARRAY);
}

void bpi_flash_amd_init(struct flash_device *fdev)
{
    // write-to-buffer-abort reset (just in case)
    bpi_flash_amd_write_buffer_abort_reset(fdev);
}

int bpi_flash_amd_wait_for_operation(struct flash_device *fdev, uint16_t stop_mask)
{
    uint16_t read_1, read_2, read_3;

    while (1)
    {
        read_1 = bpi_flash_read_cur(fdev);
        read_2 = bpi_flash_read_cur(fdev);
        read_3 = bpi_flash_read_cur(fdev);

        if ((read_1 ^ read_2) & (read_2 ^ read_3) & 0x40)
        {
            if (read_1 & stop_mask)
            {
                return read_1;
            }
        }
        else
        {
            return 0;
        }
    }
}

int bpi_flash_amd_sector_erase(struct flash_device *fdev, size_t addr)
{
    bpi_flash_amd_unlock(fdev);
    bpi_flash_write_word(fdev, BPI_AMD_UNLOCK_ADDR_1, BPI_AMD_BLOCK_ERASE_SETUP);
    bpi_flash_amd_unlock(fdev);
    bpi_flash_write_word(fdev, addr, BPI_AMD_BLOCK_ERASE_CONFIRM);

    while (!(bpi_flash_read_cur(fdev) & 0x08)) {};

    if (bpi_flash_amd_wait_for_operation(fdev, 0x20) & 0x20)
    {
        // write-to-buffer-abort reset
        bpi_flash_amd_write_buffer_abort_reset(fdev);

        fprintf(stderr, "Failed to erase block\n");
        return -1;
    }

    return 0;
}

int bpi_flash_amd_buffered_program(struct flash_device *fdev, size_t addr, size_t len, void *src)
{
    uint8_t *s = src;

    bpi_flash_amd_unlock(fdev);
    bpi_flash_write_word(fdev, addr, BPI_AMD_BUFFERED_PROGRAM_SETUP);
    bpi_flash_write_cur(fdev, len-1);

    for (size_t i = 0; i < len; i++)
    {
        bpi_flash_write_word(fdev, addr+i, s[0] | (s[1] << 8));
        s += 2;
    }

    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, BPI_AMD_BUFFERED_PROGRAM_CONFIRM);

    if (bpi_flash_amd_wait_for_operation(fdev, 0x22) & 0x22)
    {
        // write-to-buffer-abort reset
        bpi_flash_amd_write_buffer_abort_reset(fdev);

        fprintf(stderr, "Failed to write block\n");
        return -1;
    }

    return 0;
}

const struct flash_ops bpi_flash_amd_ops = {
    .init = bpi_flash_amd_init,
    .sector_erase = bpi_flash_amd_sector_erase,
    .buffered_program = bpi_flash_amd_buffered_program
};

// Micron flash ops (0x0002)

uint16_t bpi_flash_micron_read_status_register(struct flash_device *fdev)
{
    bpi_flash_write_cur(fdev, BPI_MICRON_READ_STATUS_REG);
    return bpi_flash_read_cur(fdev);
}

void bpi_flash_micron_clear_status_register(struct flash_device *fdev)
{
    bpi_flash_write_cur(fdev, BPI_MICRON_CLEAR_STATUS_REG);
}

void bpi_flash_micron_init(struct flash_device *fdev)
{
    bpi_flash_micron_clear_status_register(fdev);
}

int bpi_flash_micron_sector_erase(struct flash_device *fdev, size_t addr)
{
    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, BPI_MICRON_BLOCK_LOCK_SETUP);
    bpi_flash_write_cur(fdev, BPI_MICRON_BLOCK_UNLOCK);

    if (bpi_flash_micron_read_status_register(fdev) & 0x30)
    {
        fprintf(stderr, "Failed to unlock block\n");
        bpi_flash_write_cur(fdev, CFI_READ_ARRAY);
        return -1;
    }

    bpi_flash_write_cur(fdev, BPI_MICRON_BLOCK_ERASE_SETUP);
    bpi_flash_write_cur(fdev, BPI_MICRON_BLOCK_ERASE_CONFIRM);

    while (!(bpi_flash_micron_read_status_register(fdev) & 0x80)) {};

    if (bpi_flash_micron_read_status_register(fdev) & 0x30)
    {
        fprintf(stderr, "Failed to erase block\n");
        bpi_flash_write_cur(fdev, CFI_READ_ARRAY);
        return -1;
    }

    bpi_flash_write_cur(fdev, CFI_READ_ARRAY);

    return 0;
}

int bpi_flash_micron_buffered_program(struct flash_device *fdev, size_t addr, size_t len, void *src)
{
    uint8_t *s = src;

    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, BPI_MICRON_BUFFERED_PROGRAM_SETUP);
    bpi_flash_write_cur(fdev, len-1);

    for (size_t i = 0; i < len; i++)
    {
        bpi_flash_write_word(fdev, addr+i, s[0] | (s[1] << 8));
        s += 2;
    }

    bpi_flash_set_addr(fdev, addr);
    bpi_flash_write_cur(fdev, BPI_MICRON_BUFFERED_PROGRAM_CONFIRM);

    while (!(bpi_flash_micron_read_status_register(fdev) & 0x80)) {};

    if (bpi_flash_micron_read_status_register(fdev) & 0x30)
    {
        fprintf(stderr, "Failed to write block\n");
        bpi_flash_write_cur(fdev, CFI_READ_ARRAY);
        return -1;
    }

    bpi_flash_write_cur(fdev, CFI_READ_ARRAY);

    return 0;
}

const struct flash_ops bpi_flash_micron_ops = {
    .init = bpi_flash_micron_init,
    .sector_erase = bpi_flash_micron_sector_erase,
    .buffered_program = bpi_flash_micron_buffered_program
};


void bpi_flash_release(struct flash_device *fdev)
{
    bpi_flash_deselect(fdev);
}

int bpi_flash_init(struct flash_device *fdev)
{
    int ret = 0;

    if (!fdev)
        return -1;

    // CFI query
    bpi_flash_write_word(fdev, CFI_QUERY_ADDR, CFI_QUERY_DATA);

    if (bpi_flash_read_word(fdev, CFI_ID_0) != 'Q')
    {
        // may be Intel flash in sync read mode; attempt switch to async
        bpi_flash_write_word(fdev, 0xf94f, BPI_INTEL_READ_CONFIG_REG_SETUP);
        bpi_flash_write_word(fdev, 0xf94f, BPI_INTEL_SET_READ_CONFIG_REG);
        bpi_flash_write_word(fdev, CFI_QUERY_ADDR, CFI_QUERY_DATA);
    }

    if (bpi_flash_read_word(fdev, CFI_ID_0) != 'Q' && ((bpi_flash_read_cur(fdev) ^ bpi_flash_read_cur(fdev)) & 0x44))
    {
        // may be AMD flash in write buffer abort; perform write buffer abort reset
        bpi_flash_amd_write_buffer_abort_reset(fdev);
        bpi_flash_write_word(fdev, CFI_QUERY_ADDR, CFI_QUERY_DATA);
    }

    if (bpi_flash_read_word(fdev, CFI_ID_0) != 'Q' ||
        bpi_flash_read_word(fdev, CFI_ID_1) != 'R' ||
        bpi_flash_read_word(fdev, CFI_ID_2) != 'Y')
    {
        fprintf(stderr, "Failed to read flash ID\n");
        ret = -1;
        goto err;
    }

    fdev->protocol = bpi_flash_read_word(fdev, CFI_PRI_CMD_SET_0) | (bpi_flash_read_word(fdev, CFI_PRI_CMD_SET_1) << 8);

    printf("Command set: %d\n", fdev->protocol);

    switch (fdev->protocol)
    {
    case 0x0001:
        // Intel command set (P30)
        fdev->ops = &bpi_flash_intel_ops;
        break;
    case 0x0002:
        // AMD command set (S29, MT28)
        fdev->ops = &bpi_flash_amd_ops;
        break;
    case 0x0200:
        // Micron
        fdev->ops = &bpi_flash_micron_ops;
        break;
    default:
        fprintf(stderr, "Unknown command set: %d\n", fdev->protocol);
        ret = -1;
        goto err;
    }

    uint8_t flash_size = bpi_flash_read_word(fdev, CFI_DEVICE_SIZE);
    fdev->size = ((size_t)1) << flash_size;

    printf("Flash size: %d MB\n", 1 << (flash_size-20));

    uint16_t write_buffer_size = bpi_flash_read_word(fdev, CFI_WRITE_BUFFER_SIZE_0) | (bpi_flash_read_word(fdev, CFI_WRITE_BUFFER_SIZE_1) << 8);
    fdev->write_buffer_size = ((size_t)1) << write_buffer_size;

    printf("Write buffer size: %ld B\n", fdev->write_buffer_size);

    fdev->erase_region_count = bpi_flash_read_word(fdev, CFI_ERASE_REGION_COUNT);

    printf("Erase regions: %d\n", fdev->erase_region_count);

    if (fdev->erase_region_count > 0)
    {
        fdev->erase_region[0].block_count = (bpi_flash_read_word(fdev, CFI_ERASE_REGION_1_INFO_0) | (bpi_flash_read_word(fdev, CFI_ERASE_REGION_1_INFO_1) << 8)) + 1;
        fdev->erase_region[0].block_size = (bpi_flash_read_word(fdev, CFI_ERASE_REGION_1_INFO_2) | (bpi_flash_read_word(fdev, CFI_ERASE_REGION_1_INFO_3) << 8)) * 256;
        fdev->erase_region[0].region_start = 0;
        fdev->erase_region[0].region_end = fdev->erase_region[0].region_start + fdev->erase_region[0].block_count * fdev->erase_region[0].block_size;

        fdev->erase_block_size = fdev->erase_region[0].block_size;

        printf("Erase region 0 block count: %ld\n", fdev->erase_region[0].block_count);
        printf("Erase region 0 block size: %ld B\n", fdev->erase_region[0].block_size);
        printf("Erase region 0 start: 0x%08lx\n", fdev->erase_region[0].region_start);
        printf("Erase region 0 end: 0x%08lx\n", fdev->erase_region[0].region_end);
    }
    else
    {
        fprintf(stderr, "No erase regions found!\n");
        ret = -1;
        goto err;
    }

    if (fdev->erase_region_count > 1)
    {
        fdev->erase_region[1].block_count = (bpi_flash_read_word(fdev, CFI_ERASE_REGION_2_INFO_0) | (bpi_flash_read_word(fdev, CFI_ERASE_REGION_2_INFO_1) << 8)) + 1;
        fdev->erase_region[1].block_size = (bpi_flash_read_word(fdev, CFI_ERASE_REGION_2_INFO_2) | (bpi_flash_read_word(fdev, CFI_ERASE_REGION_2_INFO_3) << 8)) * 256;
        fdev->erase_region[1].region_start = fdev->erase_region[0].region_end;
        fdev->erase_region[1].region_end = fdev->erase_region[1].region_start + fdev->erase_region[1].block_count * fdev->erase_region[1].block_size;

        if (fdev->erase_region[1].block_size > fdev->erase_block_size)
        {
            fdev->erase_block_size = fdev->erase_region[1].block_size;
        }

        printf("Erase region 1 block count: %ld\n", fdev->erase_region[1].block_count);
        printf("Erase region 1 block size: %ld B\n", fdev->erase_region[1].block_size);
        printf("Erase region 1 start: 0x%08lx\n", fdev->erase_region[1].region_start);
        printf("Erase region 1 end: 0x%08lx\n", fdev->erase_region[1].region_end);
    }

    printf("Erase block size: %ld B\n", fdev->erase_block_size);

    fdev->ops->init(fdev);

err:
    bpi_flash_release(fdev);
    return ret;
}

int bpi_flash_read(struct flash_device *fdev, size_t addr, size_t len, void *dest)
{
    char *d = dest;

    bpi_flash_write_word(fdev, 0, CFI_READ_ARRAY);

    if (addr & 1)
    {
        *d = bpi_flash_read_word(fdev, addr >> 1) >> 8;
        addr++;
        len--;
        d++;
    }

    while (len > 1)
    {
        *((uint16_t *)d) = bpi_flash_read_word(fdev, addr >> 1);
        addr += 2;
        len -= 2;
        d += 2;
    }

    if (len)
    {
        *d = bpi_flash_read_word(fdev, addr >> 1);
        addr++;
        len--;
        d++;
    }

    bpi_flash_deselect(fdev);

    return 0;
}

int bpi_flash_write(struct flash_device *fdev, size_t addr, size_t len, void *src)
{
    char *s = src;

    while (len > 0)
    {
        size_t seg = len;

        // align to buffer size
        if (seg > fdev->write_buffer_size - (addr & (fdev->write_buffer_size-1)))
        {
            seg = fdev->write_buffer_size - (addr & (fdev->write_buffer_size-1));
        }

        if (fdev->ops->buffered_program(fdev, addr >> 1, seg >> 1, s))
        {
            fprintf(stderr, "Buffered write failed\n");
            bpi_flash_deselect(fdev);
            return -1;
        }

        addr += seg;
        len -= seg;
        s += seg;
    }

    bpi_flash_deselect(fdev);

    return 0;
}

int bpi_flash_erase(struct flash_device *fdev, size_t addr, size_t len)
{
    size_t erase_block_size = fdev->erase_block_size;

    while (len > 0)
    {
        // determine sector size
        erase_block_size = 0;

        for (int k = 0; k < fdev->erase_region_count; k++)
        {
            if (addr >= fdev->erase_region[k].region_start && addr < fdev->erase_region[k].region_end)
            {
                erase_block_size = fdev->erase_region[k].block_size;
                break;
            }
        }

        if (!erase_block_size)
        {
            fprintf(stderr, "Address does not match an erase region\n");
            bpi_flash_deselect(fdev);
            return -1;
        }

        // check size and alignment
        if (addr & (erase_block_size-1) || len < erase_block_size)
        {
            fprintf(stderr, "Invalid erase request\n");
            bpi_flash_deselect(fdev);
            return -1;
        }

        // block erase
        if (fdev->ops->sector_erase(fdev, addr >> 1))
        {
            fprintf(stderr, "Failed to erase sector\n");
            bpi_flash_deselect(fdev);
            return -1;
        }

        if (len <= erase_block_size)
            break;

        addr += erase_block_size;
        len -= erase_block_size;
    }

    bpi_flash_deselect(fdev);

    return 0;
}

const struct flash_driver bpi_flash_driver = {
    .init = bpi_flash_init,
    .release = bpi_flash_release,
    .read = bpi_flash_read,
    .write = bpi_flash_write,
    .erase = bpi_flash_erase
};

