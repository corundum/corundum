/*

Copyright 2021, The Regents of the University of California.
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
#include <stdlib.h>
#include <string.h>

#include <mqnic/mqnic.h>

static void usage(char *name)
{
    fprintf(stderr,
        "usage: %s [options]\n"
        " -d name    device to open (/dev/mqnic0)\n"
        " -i number  interface\n"
        " -P number  port\n",
        name);
}

uint32_t mqnic_alveo_bmc_reg_read(struct mqnic_reg_block *rb, uint32_t reg)
{
    mqnic_reg_write32(rb->regs, MQNIC_RB_ALVEO_BMC_REG_ADDR, reg);
    mqnic_reg_read32(rb->regs, MQNIC_RB_ALVEO_BMC_REG_DATA); // dummy read
    return mqnic_reg_read32(rb->regs, MQNIC_RB_ALVEO_BMC_REG_DATA);
}

void mqnic_alveo_bmc_reg_write(struct mqnic_reg_block *rb, uint32_t reg, uint32_t val)
{
    mqnic_reg_write32(rb->regs, MQNIC_RB_ALVEO_BMC_REG_ADDR, reg);
    mqnic_reg_write32(rb->regs, MQNIC_RB_ALVEO_BMC_REG_DATA, val);
    mqnic_reg_read32(rb->regs, MQNIC_RB_ALVEO_BMC_REG_DATA); // dummy read
}

struct sensor_channel {
    uint32_t reg;
    char name[32];
    char unit[8];
};

struct sensor_channel alveo_bmc_sensors[] = {
    {0x0020, "12V_PEX", "mV"},
    {0x002C, "3V3_PEX", "mV"},
    {0x0038, "3V3_AUX", "mV"},
    {0x0044, "12V_AUX", "mV"},
    {0x0050, "DDR4_VPP_BTM", "mV"},
    {0x005C, "SYS_5V5", "mV"},
    {0x0068, "VCC1V2_TOP", "mV"},
    {0x0074, "VCC1V8", "mV"},
    {0x0080, "VCC0V85", "mV"},
    {0x008C, "DDR4_VPP_TOP", "mV"},
    {0x0098, "MGT0V9AVCC", "mV"},
    {0x00A4, "12VSW", "mV"},
    {0x00B0, "MGTAVTT", "mV"},
    {0x00BC, "VCC1V2_BTM", "mV"},
    {0x00C8, "12VPEX_I_IN", "mA"},
    {0x00D4, "12V_AUX_I_IN", "mA"},
    {0x00E0, "VCCINT", "mV"},
    {0x00EC, "VCCINT_I", "mA"},
    {0x00F8, "FPGA_TEMP", "C"},
    {0x0104, "FAN_TEMP", "C"},
    {0x0110, "DIMM_TEMP0", "C"},
    {0x011C, "DIMM_TEMP1", "C"},
    {0x0128, "DIMM_TEMP2", "C"},
    {0x0134, "DIMM_TEMP3", "C"},
    {0x0140, "SE98_TEMP0", "C"},
    {0x014C, "SE98_TEMP1", "C"},
    {0x0158, "SE98_TEMP2", "C"},
    {0x0164, "FAN_SPEED", "RPM"},
    {0x0170, "CAGE_TEMP0", "C"},
    {0x017C, "CAGE_TEMP1", "C"},
    {0x0188, "CAGE_TEMP2", "C"},
    {0x0194, "CAGE_TEMP3", "C"},
    {0x0260, "HBM_TEMP1", "C"},
    {0x026C, "VCC3V3", "mV"},
    {0x0278, "3V3_PEX_I_IN", "mA"},
    {0x0284, "VCC0V85_I", "mA"},
    {0x0290, "HBM_1V2", "mV"},
    {0x029C, "VPP2V5", "mV"},
    {0x02A8, "VCCINT_BRAM", "mV"},
    {0x02B4, "HBM_TEMP2", "C"},
    {0x02C0, "12V_AUX1", "mV"},
    {0x02CC, "VCCINT_TEMP", "C"},
    {0x02D8, "PEX_12V_POWER", "mW"},
    {0x02E4, "PEX_3V3_POWER", "mW"},
    {0x02F0, "AUX_3V3_I", "mA"},
    {0x0314, "VCC1V2_I", "mA"},
    {0x0320, "V12_IN_I", "mA"},
    {0x032C, "V12_IN_AUX0_I", "mA"},
    {0x0338, "V12_IN_AUX1_I", "mA"},
    {0x0344, "VCCAUX", "mV"},
    {0x0350, "VCCAUX_PMC", "mV"},
    {0x035C, "VCCRAM", "mV"},
    {0, "", ""}
};

int mqnic_gecko_bmc_read(struct mqnic_reg_block *rb)
{
    uint32_t val;
    int timeout = 20000;

    while (1)
    {
        val = mqnic_reg_read32(rb->regs, MQNIC_RB_GECKO_BMC_REG_STATUS);
        if (val & (1 << 19))
        {
            if (val & (1 << 18))
            {
                // timed out
                printf("Timed out waiting for BMC\n");
                usleep(10000);
                return -2;
            }
            return val & 0xffff;
        }
        else
        {
            timeout--;
            if (timeout == 0)
            {
                printf("Timed out waiting for operation\n");
                return -1;
            }
            usleep(10);
        }
    }

    return -1;
}

int mqnic_gecko_bmc_write(struct mqnic_reg_block *rb, uint16_t cmd, uint32_t data)
{
    int ret;
    ret = mqnic_gecko_bmc_read(rb);

    if (ret == -1)
        return ret;

    mqnic_reg_write32(rb->regs, MQNIC_RB_GECKO_BMC_REG_DATA, data);
    mqnic_reg_write32(rb->regs, MQNIC_RB_GECKO_BMC_REG_CMD, cmd << 16);

    return 0;
}

int mqnic_gecko_bmc_query(struct mqnic_reg_block *rb, uint16_t cmd, uint32_t data)
{
    int ret;

    ret = mqnic_gecko_bmc_write(rb, cmd, data);

    if (ret)
        return ret;

    return mqnic_gecko_bmc_read(rb);
}

int main(int argc, char *argv[])
{
    char *name;
    int opt;
    int ret = 0;

    char *device = NULL;
    struct mqnic *dev;
    struct mqnic_reg_block *bmc_rb;

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

    if (dev->pci_device_path[0])
    {
        char *ptr = strrchr(dev->pci_device_path, '/');
        if (ptr)
            printf("PCIe ID: %s\n", ptr+1);
    }

    mqnic_print_fw_id(dev);

    if ((bmc_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_ALVEO_BMC_TYPE, MQNIC_RB_ALVEO_BMC_VER, 0)))
    {
        printf("Detected Xilinx Alveo board with MSP430 BMC\n");

        printf("Attempt to communicate with CMS microblaze...\n");

        if (mqnic_alveo_bmc_reg_read(bmc_rb, 0x020000) == 0 || mqnic_alveo_bmc_reg_read(bmc_rb, 0x028000) == 0)
        {
            printf("Resetting CMS...\n");

            // reset CMS
            mqnic_alveo_bmc_reg_write(bmc_rb, 0x020000, 0);
            mqnic_alveo_bmc_reg_write(bmc_rb, 0x020000, 1);
            usleep(200000);
        }

        if (mqnic_alveo_bmc_reg_read(bmc_rb, 0x028000) != 0x74736574)
        {
            fprintf(stderr, "CMS not responding\n");
            ret = -1;
            goto err;
        }

        // read sensor channels
        printf("Sensor values:\n");
        for (const struct sensor_channel *ptr = alveo_bmc_sensors; ptr->reg; ptr++)
        {
            uint32_t reg = 0x028000 + ptr->reg;
            uint32_t val_max = mqnic_alveo_bmc_reg_read(bmc_rb, reg);
            uint32_t val_avg = mqnic_alveo_bmc_reg_read(bmc_rb, reg+4);
            uint32_t val_ins = mqnic_alveo_bmc_reg_read(bmc_rb, reg+8);

            printf("%s: %d %s (%d %s avg, %d %s max)\n", ptr->name,
                val_ins, ptr->unit, val_avg, ptr->unit, val_max, ptr->unit);
        }

        // read MAC addresses
        printf("MAC addresses:\n");
        for (int k = 0; k < 8; k++)
        {
            uint8_t mac[6];
            uint32_t reg = 0x0281a0 + k*8;
            uint32_t val = mqnic_alveo_bmc_reg_read(bmc_rb, reg);
            mac[0] = (val >> 8) & 0xff;
            mac[1] = val & 0xff;
            val = mqnic_alveo_bmc_reg_read(bmc_rb, reg+4);
            mac[2] = (val >> 24) & 0xff;
            mac[3] = (val >> 16) & 0xff;
            mac[4] = (val >> 8) & 0xff;
            mac[5] = val & 0xff;
            printf("MAC %d: ", k);
            for (int i = 0; i < 6; i++)
            {
                if (i != 0)
                    printf(":");
                printf("%02x", mac[i]);
            }
            printf("\n");
        }
    }
    else if ((bmc_rb = mqnic_find_reg_block(dev->rb_list, MQNIC_RB_GECKO_BMC_TYPE, MQNIC_RB_GECKO_BMC_VER, 0)))
    {
        printf("Detected Silicom board with Gecko BMC\n");

        if (mqnic_gecko_bmc_query(bmc_rb, 0x7006, 0) <= 0)
        {
            fprintf(stderr, "Failed to communicate with BMC\n");
            ret = -1;
            goto err;
        }

        uint16_t v_l = mqnic_gecko_bmc_query(bmc_rb, 0x7005, 0);
        uint16_t v_h = mqnic_gecko_bmc_query(bmc_rb, 0x7006, 0);

        printf("Gecko BMC version %d.%d.%d.%d\n", (v_h >> 8) & 0xff, v_h & 0xff, (v_l >> 8) & 0xff, v_l & 0xff);

        // read MAC addresses
        printf("MAC addresses:\n");
        for (int k = 0; k < 8; k++)
        {
            uint8_t mac[6];
            for (int i = 0; i < 6; i += 2)
            {
                uint16_t val = mqnic_gecko_bmc_query(bmc_rb, 0x2003, 0+k*6+i);
                mac[i] = val & 0xff;
                mac[i+1] = (val >> 8) & 0xff;
            }
            printf("MAC %d: ", k);
            for (int i = 0; i < 6; i++)
            {
                if (i != 0)
                    printf(":");
                printf("%02x", mac[i]);
            }
            printf("\n");
        }
    }
    else
    {
        fprintf(stderr, "Board does not have BMC or BMC not currently supported\n");
        ret = -1;

        goto err;
    }

err:

    mqnic_close(dev);

    return ret;
}
