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

#define SPI_CMD_RESET_ENABLE                 0x66
#define SPI_CMD_RESET_MEMORY                 0x99
#define SPI_CMD_READ_ID                      0x9F
#define SPI_CMD_READ                         0x03
#define SPI_CMD_FAST_READ                    0x0B
#define SPI_CMD_FAST_READ_DUAL_OUT           0x3B
#define SPI_CMD_FAST_READ_DUAL_IO            0xBB
#define SPI_CMD_FAST_READ_QUAD_OUT           0x6B
#define SPI_CMD_FAST_READ_QUAD_IO            0xEB
#define SPI_CMD_DTR_FAST_READ                0x0D
#define SPI_CMD_DTR_FAST_READ_DUAL_OUT       0x3D
#define SPI_CMD_DTR_FAST_READ_DUAL_IO        0xBD
#define SPI_CMD_DTR_FAST_READ_QUAD_OUT       0x6D
#define SPI_CMD_DTR_FAST_READ_QUAD_IO        0xED
#define SPI_CMD_4B_READ                      0x13
#define SPI_CMD_4B_FAST_READ                 0x0C
#define SPI_CMD_4B_FAST_READ_DUAL_OUT        0x3C
#define SPI_CMD_4B_FAST_READ_DUAL_IO         0xBC
#define SPI_CMD_4B_FAST_READ_QUAD_OUT        0x6C
#define SPI_CMD_4B_FAST_READ_QUAD_IO         0xEC
#define SPI_CMD_4B_DTR_FAST_READ             0x0E
#define SPI_CMD_4B_DTR_FAST_READ_DUAL_IO     0xBE
#define SPI_CMD_4B_DTR_FAST_READ_QUAD_IO     0xEE
#define SPI_CMD_WRITE_ENABLE                 0x06
#define SPI_CMD_WRITE_DISABLE                0x04
#define SPI_CMD_READ_STATUS_REG              0x05
#define SPI_CMD_READ_FLAG_STATUS_REG         0x70
#define SPI_CMD_READ_NV_CONFIG_REG           0xB5
#define SPI_CMD_READ_V_CONFIG_REG            0x85
#define SPI_CMD_READ_EV_CONFIG_REG           0x65
#define SPI_CMD_READ_EXT_ADDR_REG            0xC8
#define SPI_CMD_WRITE_STATUS_REG             0x01
#define SPI_CMD_WRITE_NV_CONFIG_REG          0xB1
#define SPI_CMD_WRITE_V_CONFIG_REG           0x81
#define SPI_CMD_WRITE_EV_CONFIG_REG          0x61
#define SPI_CMD_WRITE_EXT_ADDR_REG           0xC5
#define SPI_CMD_CLEAR_FLAG_STATUS_REG        0x50
#define SPI_CMD_PAGE_PROGRAM                 0x02
#define SPI_CMD_PAGE_PROGRAM_DUAL_IN         0xA2
#define SPI_CMD_PAGE_PROGRAM_DUAL_IN_EXT     0xD2
#define SPI_CMD_PAGE_PROGRAM_QUAD_IN         0x32
#define SPI_CMD_PAGE_PROGRAM_QUAD_IN_EXT     0x38
#define SPI_CMD_4B_PAGE_PROGRAM              0x12
#define SPI_CMD_4B_PAGE_PROGRAM_QUAD_IN      0x34
#define SPI_CMD_4B_PAGE_PROGRAM_QUAD_IN_EXT  0x3E
#define SPI_CMD_32KB_SUBSECTOR_ERASE         0x52
#define SPI_CMD_4KB_SUBSECTOR_ERASE          0x20
#define SPI_CMD_SECTOR_ERASE                 0xD8
#define SPI_CMD_BULK_ERASE                   0xC7
#define SPI_CMD_4B_4KB_SUBSECTOR_ERASE       0x21
#define SPI_CMD_4B_SECTOR_ERASE              0xDC
#define SPI_CMD_PROGRAM_SUSPEND              0x75
#define SPI_CMD_PROGRAM_RESUME               0x7A
#define SPI_CMD_READ_OTP_ARRAY               0x4B
#define SPI_CMD_PROGRAM_OTP_ARRAY            0x42
#define SPI_CMD_ENTER_4B_ADDR_MODE           0xB7
#define SPI_CMD_EXIT_4B_ADDR_MODE            0xE9
#define SPI_CMD_ENTER_QUAD_IO_MODE           0x35
#define SPI_CMD_EXIT_QUAD_IO_MODE            0xF5
#define SPI_CMD_ENTER_DEEP_POWER_DOWN        0xB9
#define SPI_CMD_EXIT_DEEP_POWER_DOWN         0xAB

#define SPI_PROTO_STR       0
#define SPI_PROTO_DTR       1
#define SPI_PROTO_DUAL_STR  2
#define SPI_PROTO_DUAL_DTR  3
#define SPI_PROTO_QUAD_STR  4
#define SPI_PROTO_QUAD_DTR  5

#define SPI_PAGE_SIZE       0x100
#define SPI_SUBSECTOR_SIZE  0x1000
#define SPI_SECTOR_SIZE     0x10000

#define FLASH_D_0     (1 << 0)
#define FLASH_D_1     (1 << 1)
#define FLASH_D_2     (1 << 2)
#define FLASH_D_3     (1 << 3)
#define FLASH_D_01    (FLASH_D_0 | FLASH_D_1)
#define FLASH_D_0123  (FLASH_D_0 | FLASH_D_1 | FLASH_D_2 | FLASH_D_3)
#define FLASH_OE_0    (1 << 8)
#define FLASH_OE_1    (1 << 9)
#define FLASH_OE_2    (1 << 10)
#define FLASH_OE_3    (1 << 11)
#define FLASH_OE_01   (FLASH_OE_0 | FLASH_OE_1)
#define FLASH_OE_0123 (FLASH_OE_0 | FLASH_OE_1 | FLASH_OE_2 | FLASH_OE_3)
#define FLASH_CLK     (1 << 16)
#define FLASH_CS_N    (1 << 17)

void spi_flash_select(struct flash_device *fdev)
{
    reg_write32(fdev->ctrl_reg, 0);
}

void spi_flash_deselect(struct flash_device *fdev)
{
    reg_write32(fdev->ctrl_reg, FLASH_CS_N);
}

uint8_t spi_flash_read_byte(struct flash_device *fdev, int protocol)
{
    uint8_t val = 0;

    switch (protocol)
    {
    case SPI_PROTO_STR:
        for (int i = 7; i >= 0; i--)
        {
            reg_write32(fdev->ctrl_reg, 0);
            val |= ((reg_read32(fdev->ctrl_reg) & FLASH_D_1) != 0) << i;
            reg_write32(fdev->ctrl_reg, FLASH_CLK);
            reg_read32(fdev->ctrl_reg); // dummy read
        }
        break;
    case SPI_PROTO_DTR:
        break;
    case SPI_PROTO_DUAL_STR:
        for (int i = 6; i >= 0; i -= 2)
        {
            reg_write32(fdev->ctrl_reg, 0);
            val |= (reg_read32(fdev->ctrl_reg) & FLASH_D_01) << i;
            reg_write32(fdev->ctrl_reg, FLASH_CLK);
            reg_read32(fdev->ctrl_reg); // dummy read
        }
        break;
    case SPI_PROTO_DUAL_DTR:
        break;
    case SPI_PROTO_QUAD_STR:
        for (int i = 4; i >= 0; i -= 4)
        {
            reg_write32(fdev->ctrl_reg, 0);
            val |= (reg_read32(fdev->ctrl_reg) & FLASH_D_0123) << i;
            reg_write32(fdev->ctrl_reg, FLASH_CLK);
            reg_read32(fdev->ctrl_reg); // dummy read
        }
        break;
    case SPI_PROTO_QUAD_DTR:
        break;
    }

    reg_write32(fdev->ctrl_reg, 0);

    return val;
}

void spi_flash_write_byte(struct flash_device *fdev, uint8_t val, int protocol)
{
    uint8_t bit;

    switch (protocol)
    {
    case SPI_PROTO_STR:
        for (int i = 7; i >= 0; i--)
        {
            bit = (val >> i) & 0x1;
            reg_write32(fdev->ctrl_reg, bit | FLASH_OE_0);
            reg_read32(fdev->ctrl_reg); // dummy read
            reg_write32(fdev->ctrl_reg, bit | FLASH_OE_0 | FLASH_CLK);
            reg_read32(fdev->ctrl_reg); // dummy read
        }
        break;
    case SPI_PROTO_DTR:
        break;
    case SPI_PROTO_DUAL_STR:
        for (int i = 6; i >= 0; i -= 2)
        {
            bit = (val >> i) & 0x3;
            reg_write32(fdev->ctrl_reg, bit | FLASH_OE_01);
            reg_read32(fdev->ctrl_reg); // dummy read
            reg_write32(fdev->ctrl_reg, bit | FLASH_OE_01 | FLASH_CLK);
            reg_read32(fdev->ctrl_reg); // dummy read
        }
        break;
    case SPI_PROTO_DUAL_DTR:
        break;
    case SPI_PROTO_QUAD_STR:
        for (int i = 4; i >= 0; i -= 4)
        {
            bit = (val >> i) & 0xf;
            reg_write32(fdev->ctrl_reg, bit | FLASH_OE_0123);
            reg_read32(fdev->ctrl_reg); // dummy read
            reg_write32(fdev->ctrl_reg, bit | FLASH_OE_0123 | FLASH_CLK);
            reg_read32(fdev->ctrl_reg); // dummy read
        }
        break;
    case SPI_PROTO_QUAD_DTR:
        break;
    }

    reg_write32(fdev->ctrl_reg, 0);
}

void spi_flash_write_addr(struct flash_device *fdev, size_t addr, int protocol)
{
    spi_flash_write_byte(fdev, (addr >> 16) & 0xff, protocol);
    spi_flash_write_byte(fdev, (addr >> 8) & 0xff, protocol);
    spi_flash_write_byte(fdev, (addr >> 0) & 0xff, protocol);
}

void spi_flash_write_addr_4b(struct flash_device *fdev, size_t addr, int protocol)
{
    spi_flash_write_byte(fdev, (addr >> 24) & 0xff, protocol);
    spi_flash_write_byte(fdev, (addr >> 16) & 0xff, protocol);
    spi_flash_write_byte(fdev, (addr >> 8) & 0xff, protocol);
    spi_flash_write_byte(fdev, (addr >> 0) & 0xff, protocol);
}

void spi_flash_write_enable(struct flash_device *fdev, int protocol)
{
    spi_flash_write_byte(fdev, SPI_CMD_WRITE_ENABLE, protocol);
    spi_flash_deselect(fdev);
}

void spi_flash_write_disable(struct flash_device *fdev, int protocol)
{
    spi_flash_write_byte(fdev, SPI_CMD_WRITE_DISABLE, protocol);
    spi_flash_deselect(fdev);
}

uint8_t spi_flash_read_status_register(struct flash_device *fdev, int protocol)
{
    uint8_t val;
    spi_flash_write_byte(fdev, SPI_CMD_READ_STATUS_REG, protocol);
    val = spi_flash_read_byte(fdev, protocol);
    spi_flash_deselect(fdev);
    return val;
}

void spi_flash_write_status_register(struct flash_device *fdev, uint8_t val, int protocol)
{
    spi_flash_write_byte(fdev, SPI_CMD_WRITE_STATUS_REG, protocol);
    spi_flash_write_byte(fdev, val, protocol);
    spi_flash_deselect(fdev);
}

uint8_t spi_flash_read_flag_status_register(struct flash_device *fdev, int protocol)
{
    uint8_t val;
    spi_flash_write_byte(fdev, SPI_CMD_READ_FLAG_STATUS_REG, protocol);
    val = spi_flash_read_byte(fdev, protocol);
    spi_flash_deselect(fdev);
    return val;
}

void spi_flash_clear_flag_status_register(struct flash_device *fdev, int protocol)
{
    spi_flash_write_byte(fdev, SPI_CMD_CLEAR_FLAG_STATUS_REG, protocol);
    spi_flash_deselect(fdev);
}

uint8_t spi_flash_read_volatile_config_register(struct flash_device *fdev, int protocol)
{
    uint8_t val;
    spi_flash_write_byte(fdev, SPI_CMD_READ_V_CONFIG_REG, protocol);
    val = spi_flash_read_byte(fdev, protocol);
    spi_flash_deselect(fdev);
    return val;
}

void spi_flash_write_volatile_config_register(struct flash_device *fdev, uint8_t val, int protocol)
{
    spi_flash_write_byte(fdev, SPI_CMD_WRITE_V_CONFIG_REG, protocol);
    spi_flash_write_byte(fdev, val, protocol);
    spi_flash_deselect(fdev);
}

void spi_flash_reset(struct flash_device *fdev, int protocol)
{
    spi_flash_deselect(fdev);
    spi_flash_write_byte(fdev, SPI_CMD_RESET_ENABLE, protocol);
    spi_flash_deselect(fdev);
    reg_read32(fdev->ctrl_reg); // dummy read
    reg_read32(fdev->ctrl_reg); // dummy read
    spi_flash_write_byte(fdev, SPI_CMD_RESET_MEMORY, protocol);
    spi_flash_deselect(fdev);
    reg_read32(fdev->ctrl_reg); // dummy read
    reg_read32(fdev->ctrl_reg); // dummy read
}

void spi_flash_release(struct flash_device *fdev)
{
    spi_flash_deselect(fdev);
}

int spi_flash_init(struct flash_device *fdev)
{
    int ret = 0;

    if (!fdev)
        return -1;

    spi_flash_reset(fdev, SPI_PROTO_STR);

    spi_flash_write_byte(fdev, SPI_CMD_READ_ID, SPI_PROTO_STR);
    int mfr_id = spi_flash_read_byte(fdev, SPI_PROTO_STR);
    int mem_type = spi_flash_read_byte(fdev, SPI_PROTO_STR);
    int mem_capacity = spi_flash_read_byte(fdev, SPI_PROTO_STR);
    spi_flash_deselect(fdev);

    printf("Manufacturer ID: 0x%02x\n", mfr_id);
    printf("Memory type: 0x%02x\n", mem_type);
    printf("Memory capacity: 0x%02x\n", mem_capacity);

    // convert from BCD
    mem_capacity = (mem_capacity & 0xf) + (((mem_capacity >> 4) & 0xf) * 10);

    fdev->size = ((size_t)1) << (mem_capacity+6);

    printf("Flash size: %ld MB\n", fdev->size / (1 << 20));

    fdev->protocol = SPI_PROTO_STR;
    fdev->bulk_protocol = SPI_PROTO_STR;
    fdev->read_dummy_cycles = 0;
    fdev->write_buffer_size = SPI_PAGE_SIZE;
    fdev->erase_block_size = SPI_SUBSECTOR_SIZE;

    printf("Write buffer size: %ld B\n", fdev->write_buffer_size);
    printf("Erase block size: %ld B\n", fdev->erase_block_size);

    if (fdev->data_width == 4)
    {
        spi_flash_write_volatile_config_register(fdev, 0xFB, SPI_PROTO_STR);
        fdev->bulk_protocol = SPI_PROTO_QUAD_STR;
        fdev->read_dummy_cycles = 10;
    }

    spi_flash_release(fdev);
    return ret;
}

int spi_flash_read(struct flash_device *fdev, size_t addr, size_t len, void *dest)
{
    char *d = dest;

    int protocol = SPI_PROTO_STR;

    if (fdev->data_width == 4)
    {
        protocol = SPI_PROTO_QUAD_STR;
    }

    if (addr > 0xffffff)
    {
        // four byte address read
        if (protocol == SPI_PROTO_QUAD_STR)
        {
            spi_flash_write_byte(fdev, SPI_CMD_4B_FAST_READ_QUAD_IO, SPI_PROTO_STR);
        }
        else
        {
            spi_flash_write_byte(fdev, SPI_CMD_4B_READ, SPI_PROTO_STR);
        }
        spi_flash_write_addr_4b(fdev, addr, protocol);
    }
    else
    {
        // normal read
        if (protocol == SPI_PROTO_QUAD_STR)
        {
            spi_flash_write_byte(fdev, SPI_CMD_FAST_READ_QUAD_IO, SPI_PROTO_STR);
        }
        else
        {
            spi_flash_write_byte(fdev, SPI_CMD_READ, SPI_PROTO_STR);
        }
        spi_flash_write_addr(fdev, addr, protocol);
    }

    if (protocol != SPI_PROTO_STR)
    {
        // dummy cycles
        for (int i = 0; i < fdev->read_dummy_cycles; i++)
        {
            reg_write32(fdev->ctrl_reg, FLASH_CLK);
            reg_write32(fdev->ctrl_reg, 0);
        }
    }

    while (len > 0)
    {
        *d = spi_flash_read_byte(fdev, protocol);
        len--;
        d++;
    }

    spi_flash_deselect(fdev);

    return 0;
}

int spi_flash_write(struct flash_device *fdev, size_t addr, size_t len, void *src)
{
    char *s = src;

    int protocol = SPI_PROTO_STR;

    if (fdev->data_width == 4)
    {
        protocol = SPI_PROTO_QUAD_STR;
    }

    while (len > 0)
    {
        spi_flash_write_enable(fdev, SPI_PROTO_STR);

        if (!(spi_flash_read_status_register(fdev, SPI_PROTO_STR) & 0x02))
        {
            fprintf(stderr, "Failed to enable writing\n");
            spi_flash_deselect(fdev);
            return -1;
        }

        if (addr > 0xffffff)
        {
            // four byte address page program
            if (protocol == SPI_PROTO_QUAD_STR)
            {
                spi_flash_write_byte(fdev, SPI_CMD_4B_PAGE_PROGRAM_QUAD_IN_EXT, SPI_PROTO_STR);
            }
            else
            {
                spi_flash_write_byte(fdev, SPI_CMD_4B_PAGE_PROGRAM, SPI_PROTO_STR);
            }
            spi_flash_write_addr_4b(fdev, addr, protocol);
        }
        else
        {
            // normal page program
            if (protocol == SPI_PROTO_QUAD_STR)
            {
                spi_flash_write_byte(fdev, SPI_CMD_PAGE_PROGRAM_QUAD_IN_EXT, SPI_PROTO_STR);
            }
            else
            {
                spi_flash_write_byte(fdev, SPI_CMD_PAGE_PROGRAM, SPI_PROTO_STR);
            }
            spi_flash_write_addr(fdev, addr, protocol);
        }

        while (len > 0)
        {
            spi_flash_write_byte(fdev, *s, protocol);
            addr++;
            s++;
            len--;

            if ((addr & 0xff) == 0)
                break;
        }

        spi_flash_deselect(fdev);

        // wait for operation to complete
        while (spi_flash_read_status_register(fdev, SPI_PROTO_STR) & 0x01) {};
    }

    spi_flash_deselect(fdev);

    return 0;
}

int spi_flash_erase(struct flash_device *fdev, size_t addr, size_t len)
{
    size_t erase_block_size = fdev->erase_block_size;

    while (len > 0)
    {
        // determine sector size
        erase_block_size = 0;

        if ((addr & (SPI_SECTOR_SIZE-1)) == 0 && len >= SPI_SECTOR_SIZE)
        {
            erase_block_size = SPI_SECTOR_SIZE;
        }
        else if ((addr & (SPI_SUBSECTOR_SIZE-1)) == 0 && len >= SPI_SUBSECTOR_SIZE)
        {
            erase_block_size = SPI_SUBSECTOR_SIZE;
        }

        // check size and alignment
        if (!erase_block_size)
        {
            fprintf(stderr, "Invalid erase request\n");
            spi_flash_deselect(fdev);
            return -1;
        }

        // enable writing
        spi_flash_write_enable(fdev, SPI_PROTO_STR);

        if (!(spi_flash_read_status_register(fdev, SPI_PROTO_STR) & 0x02))
        {
            fprintf(stderr, "Failed to enable writing\n");
            spi_flash_deselect(fdev);
            return -1;
        }

        // block erase
        if (addr > 0xffffff)
        {
            if (erase_block_size == SPI_SECTOR_SIZE)
            {
                // four byte address sector erase
                spi_flash_write_byte(fdev, SPI_CMD_4B_SECTOR_ERASE, SPI_PROTO_STR);
                spi_flash_write_addr_4b(fdev, addr, SPI_PROTO_STR);
            }
            else if (erase_block_size == SPI_SUBSECTOR_SIZE)
            {
                // normal 4KB subsector erase
                spi_flash_write_byte(fdev, SPI_CMD_4B_4KB_SUBSECTOR_ERASE, SPI_PROTO_STR);
                spi_flash_write_addr_4b(fdev, addr, SPI_PROTO_STR);
            }
        }
        else
        {
            if (erase_block_size == SPI_SECTOR_SIZE)
            {
                // normal sector erase
                spi_flash_write_byte(fdev, SPI_CMD_SECTOR_ERASE, SPI_PROTO_STR);
                spi_flash_write_addr(fdev, addr, SPI_PROTO_STR);
            }
            else if (erase_block_size == SPI_SUBSECTOR_SIZE)
            {
                // normal 4KB subsector erase
                spi_flash_write_byte(fdev, SPI_CMD_4KB_SUBSECTOR_ERASE, SPI_PROTO_STR);
                spi_flash_write_addr(fdev, addr, SPI_PROTO_STR);
            }
        }

        spi_flash_deselect(fdev);

        // wait for operation to complete
        while (spi_flash_read_status_register(fdev, SPI_PROTO_STR) & 0x01) {};

        if (len <= erase_block_size)
            break;

        addr += erase_block_size;
        len -= erase_block_size;
    }

    spi_flash_deselect(fdev);

    return 0;
}

const struct flash_driver spi_flash_driver = {
    .init = spi_flash_init,
    .release = spi_flash_release,
    .read = spi_flash_read,
    .write = spi_flash_write,
    .erase = spi_flash_erase
};

