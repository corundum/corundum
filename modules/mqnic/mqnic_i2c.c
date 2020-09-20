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

#include "mqnic.h"
#include <linux/module.h>
#include <linux/i2c-mux.h>
#include <linux/version.h>

void mqnic_i2c_set_scl(void *data, int state)
{
    struct mqnic_i2c_priv *priv = data;

    if (state)
    {
        iowrite32(ioread32(priv->scl_out_reg) | priv->scl_out_mask, priv->scl_out_reg);
    }
    else
    {
        iowrite32(ioread32(priv->scl_out_reg) & ~priv->scl_out_mask, priv->scl_out_reg);
    }
}

void mqnic_i2c_set_sda(void *data, int state)
{
    struct mqnic_i2c_priv *priv = data;

    if (state)
    {
        iowrite32(ioread32(priv->sda_out_reg) | priv->sda_out_mask, priv->sda_out_reg);
    }
    else
    {
        iowrite32(ioread32(priv->sda_out_reg) & ~priv->sda_out_mask, priv->sda_out_reg);
    }
}

int mqnic_i2c_get_scl(void *data)
{
    struct mqnic_i2c_priv *priv = data;

    return !!(ioread32(priv->scl_in_reg) & priv->scl_in_mask);
}

int mqnic_i2c_get_sda(void *data)
{
    struct mqnic_i2c_priv *priv = data;

    return !!(ioread32(priv->sda_in_reg) & priv->sda_in_mask);
}

static const struct i2c_algo_bit_data mqnic_i2c_algo = {
    .setsda     = mqnic_i2c_set_sda,
    .setscl     = mqnic_i2c_set_scl,
    .getsda     = mqnic_i2c_get_sda,
    .getscl     = mqnic_i2c_get_scl,
    .udelay     = 5,
    .timeout    = 20
};

static const struct property_entry i2c_mux_props[] = {
    PROPERTY_ENTRY_BOOL("i2c-mux-idle-disconnect"),
    { }
};

static struct i2c_client *create_i2c_client(struct i2c_adapter *adapter, const char *type, int addr, const struct property_entry *props)
{
    struct i2c_client *client;
    struct i2c_board_info board_info;

    if (!adapter)
        return NULL;

    memset(&board_info, 0, sizeof(board_info));
    strscpy(board_info.type, type, I2C_NAME_SIZE);
    board_info.addr = addr;
    board_info.properties = props;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5,2,0)
    client = i2c_new_client_device(adapter, &board_info);
#else
    client = i2c_new_device(adapter, &board_info);
#endif

    if (!client)
        return NULL;

    // force driver load (mainly for muxes so we can talk to downstream devices)
    device_attach(&client->dev);

    return client;
}

static struct i2c_adapter *get_i2c_mux_channel(struct i2c_client *mux, u32 chan_id)
{
    struct i2c_mux_core *muxc;

    if (!mux)
        return NULL;

    muxc = i2c_get_clientdata(mux);

    if (!muxc || chan_id >= muxc->num_adapters)
        return NULL;

    return muxc->adapter[chan_id];
}

static struct i2c_adapter *mqnic_create_i2c_adapter(struct mqnic_dev *mqnic, u8 __iomem *reg)
{
    struct i2c_algo_bit_data *algo;
    struct i2c_adapter *adapter;
    struct mqnic_i2c_priv *priv;

    if (mqnic->i2c_adapter_count >= MQNIC_MAX_I2C_ADAPTERS || !reg)
        return NULL;

    algo = &mqnic->i2c_algo[mqnic->i2c_adapter_count];
    adapter = &mqnic->i2c_adapter[mqnic->i2c_adapter_count];
    priv = &mqnic->i2c_priv[mqnic->i2c_adapter_count];

    priv->mqnic = mqnic;
    priv->scl_in_reg = reg;
    priv->scl_out_reg = reg;
    priv->sda_in_reg = reg;
    priv->sda_out_reg = reg;
    priv->scl_in_mask = MQNIC_REG_GPIO_I2C_SCL_IN;
    priv->scl_out_mask = MQNIC_REG_GPIO_I2C_SCL_OUT;
    priv->sda_in_mask = MQNIC_REG_GPIO_I2C_SDA_IN;
    priv->sda_out_mask = MQNIC_REG_GPIO_I2C_SDA_OUT;

    *algo = mqnic_i2c_algo;
    algo->data = priv;

    adapter->owner = THIS_MODULE;
    adapter->algo_data = algo;
    adapter->dev.parent = mqnic->dev;
    snprintf(adapter->name, sizeof(adapter->name), "%s I2C%d", mqnic->name, mqnic->i2c_adapter_count);

    if (i2c_bit_add_bus(adapter))
    {
        dev_err(mqnic->dev, "Failed to register I2C adapter");
        memset(adapter, 0, sizeof(*adapter));
        return NULL;
    }

    mqnic->i2c_adapter_count++;

    return adapter;
}

int mqnic_init_i2c(struct mqnic_dev *mqnic)
{
    struct i2c_adapter *adapter;
    struct i2c_client *mux;
    int ret = 0;

    mqnic->mod_i2c_client_count = 0;

    // Interface I2C bus
    switch (mqnic->board_id) {
    case MQNIC_BOARD_ID_NETFPGA_SUME:
        // FPGA IC12
        //   TCA9548 IC31 0x74
        //     CH0: SFP1 IC3 0x50
        //     CH1: SFP2 IC5 0x50
        //     CH2: SFP3 IC6 0x50
        //     CH3: SFP4 IC8 0x50
        //     CH4: DDR3 IC27 0x51
        //          DDR3 IC28 0x52
        //          SI5324 IC20 0x68
        //     CH5: FMC
        //     CH6: PCON
        //     CH7: PMOD J11

        request_module("i2c_mux_pca954x");
        request_module("at24");

        // I2C adapter
        adapter = mqnic_create_i2c_adapter(mqnic, mqnic->hw_addr+MQNIC_REG_GPIO_I2C_0);

        // IC31 TCA9548 I2C MUX
        mux = create_i2c_client(adapter, "pca9548", 0x74, i2c_mux_props);

        // IC3 SFP1
        mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50, NULL);

        // IC5 SFP2
        mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50, NULL);

        // IC6 SFP3
        mqnic->mod_i2c_client[2] = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c02", 0x50, NULL);

        // IC8 SFP4
        mqnic->mod_i2c_client[3] = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c02", 0x50, NULL);

        mqnic->mod_i2c_client_count = 4;

        break;
    case MQNIC_BOARD_ID_VCU108:
        // FPGA U1
        //   TCA9548 U28 0x74
        //     CH0: SI570 Osc U32 0x5D
        //     CH1: TCA6416 Port Exp U89 0x21
        //     CH2: QSFP U145 0x50
        //     CH3: NC
        //     CH4: SI5328 U57 0x68
        //     CH5: HDMI U52 0x39
        //     CH6: SYSMON U1 0x32
        //     CH7: NC
        //   PCA9544 U80 0x75
        //     CH0: PMBUS
        //     CH1: FMC_HPC0 J22
        //     CH2: FMC_HPC1 J2
        //     CH3: M24C08 EEPROM U12 0x54

        request_module("i2c_mux_pca954x");
        request_module("at24");

        // I2C adapter
        adapter = mqnic_create_i2c_adapter(mqnic, mqnic->hw_addr+MQNIC_REG_GPIO_I2C_0);

        // U28 TCA9548 I2C MUX
        mux = create_i2c_client(adapter, "pca9548", 0x74, i2c_mux_props);

        // U145 QSFP
        mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c02", 0x50, NULL);

        // U80 PCA9544 I2C MUX
        mux = create_i2c_client(adapter, "pca9544", 0x75, i2c_mux_props);

        // U12 I2C EEPROM
        mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c08", 0x54, NULL);

        mqnic->mod_i2c_client_count = 1;

        break;
    case MQNIC_BOARD_ID_VCU118:
        // FPGA U1
        //   TCA9548 U28 0x74
        //     CH0: SI570 Osc U32 0x5D
        //     CH1: NC
        //     CH2: QSFP1 U145 0x50
        //     CH3: QSFP2 U123 0x50
        //     CH4: SI5328 U57 0x68
        //     CH5: SI570 Osc U18 0x5D
        //     CH6: SYSMON U1 0x32
        //     CH7: FIREFLY J6 0x50
        //   TCA9548 U80 0x75
        //     CH0: PMBUS
        //     CH1: FMCP_HSPC J22
        //     CH2: FMC_HPC1 J2
        //     CH3: M24C08 EEPROM U12 0x54
        //     CH4: INA_PMBUS
        //     CH5: SI570 Osc U38 0x5D
        //     CH6: NC
        //     CH7: NC

        request_module("i2c_mux_pca954x");
        request_module("at24");

        // I2C adapter
        adapter = mqnic_create_i2c_adapter(mqnic, mqnic->hw_addr+MQNIC_REG_GPIO_I2C_0);

        // U28 TCA9548 I2C MUX
        mux = create_i2c_client(adapter, "pca9548", 0x74, i2c_mux_props);

        // U145 QSFP1
        mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c02", 0x50, NULL);

        // U123 QSFP2
        mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c02", 0x50, NULL);

        // U80 PCA9548 I2C MUX
        mux = create_i2c_client(adapter, "pca9548", 0x75, i2c_mux_props);

        // U12 I2C EEPROM
        mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c08", 0x54, NULL);

        mqnic->mod_i2c_client_count = 2;

        break;
    case MQNIC_BOARD_ID_VCU1525:
        // FPGA U13
        //   PCA9546 U28 0x74
        //     CH0: QSFP0 J7 0x50
        //     CH1: QSFP1 J9 0x50
        //     CH2: M24C08 EEPROM U62 0x54
        //          SI570 Osc U14 0x5D
        //     CH3: SYSMON U13 0x32

        request_module("i2c_mux_pca954x");
        request_module("at24");

        // I2C adapter
        adapter = mqnic_create_i2c_adapter(mqnic, mqnic->hw_addr+MQNIC_REG_GPIO_I2C_0);

        // U28 TCA9546 I2C MUX
        mux = create_i2c_client(adapter, "pca9546", 0x74, i2c_mux_props);

        // J7 QSFP0
        mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50, NULL);

        // J9 QSFP1
        mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50, NULL);

        // U12 I2C EEPROM
        mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c08", 0x54, NULL);

        mqnic->mod_i2c_client_count = 2;

        break;
    case MQNIC_BOARD_ID_ZCU106:
        // FPGA U1 / MSP430 U41 I2C0
        //   TCA6416 U61 0x21
        //   TCA6416 U97 0x20
        //   PCA9544 U60 0x75
        //     CH0: PS_PMBUS
        //     CH1: PL_PMBUS
        //     CH2: MAXIM_PMBUS
        //     CH3: SYSMON U1 0x32
        // FPGA U1 / MSP430 U41 I2C1
        //   TCA9548 U34 0x74
        //     CH0: M24C08 EEPROM U23 0x54
        //     CH1: SI5341 U69 0x36
        //     CH2: SI570 Osc U42 0x5D
        //     CH3: SI570 Osc U56 0x5D
        //     CH4: SI5328 U20 0x68
        //     CH5: NC
        //     CH6: NC
        //     CH7: NC
        //   TCA9548 U135 0x75
        //     CH0: FMC_HPC0 J5
        //     CH1: FMC_HPC1 J4
        //     CH2: SYSMON U1 0x32
        //     CH3: DDR4 SODIMM 0x51
        //     CH4: NC
        //     CH5: NC
        //     CH6: SFP1 P2 0x50
        //     CH7: SFP0 P1 0x50

        request_module("i2c_mux_pca954x");
        request_module("at24");

        // I2C adapter
        adapter = mqnic_create_i2c_adapter(mqnic, mqnic->hw_addr+MQNIC_REG_GPIO_I2C_0);

        // U34 TCA9548 I2C MUX
        mux = create_i2c_client(adapter, "pca9548", 0x74, i2c_mux_props);

        // U23 I2C EEPROM
        mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c08", 0x54, NULL);

        // U135 TCA9548 I2C MUX
        mux = create_i2c_client(adapter, "pca9548", 0x75, i2c_mux_props);

        // P1 SFP0
        mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 7), "24c02", 0x50, NULL);

        // P2 SFP1
        mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 6), "24c02", 0x50, NULL);

        mqnic->mod_i2c_client_count = 2;

        break;
    }

    // EEPROM I2C bus
    switch (mqnic->board_id) {
    case MQNIC_BOARD_ID_EXANIC_X10:
    case MQNIC_BOARD_ID_EXANIC_X25:
    case MQNIC_BOARD_ID_ADM_PCIE_9V3:

        // create I2C adapter
        adapter = mqnic_create_i2c_adapter(mqnic, mqnic->hw_addr+MQNIC_REG_GPIO_I2C_1);

        // I2C EEPROM
        mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c02", 0x50, NULL);

        break;
    }

    return ret;
}

void mqnic_remove_i2c(struct mqnic_dev *mqnic)
{
    int k;

    // unregister I2C clients
    for (k = 0; k < ARRAY_SIZE(mqnic->mod_i2c_client); k++)
    {
        if (mqnic->mod_i2c_client[k])
        {
            i2c_unregister_device(mqnic->mod_i2c_client[k]);
            mqnic->mod_i2c_client[k] = NULL;
        }
    }

    if (mqnic->eeprom_i2c_client)
    {
        i2c_unregister_device(mqnic->eeprom_i2c_client);
        mqnic->eeprom_i2c_client = NULL;
    }

    // delete adapters
    for (k = 0; k < ARRAY_SIZE(mqnic->i2c_adapter); k++)
    {
        if (mqnic->i2c_adapter[k].owner)
        {
            i2c_del_adapter(&mqnic->i2c_adapter[k]);
        }

        memset(&mqnic->i2c_adapter[k], 0, sizeof(mqnic->i2c_adapter[k]));
    }
}


