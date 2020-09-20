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

    return client;
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
    int ret = 0;
    // interface i2c interfaces
    // TODO

    // eeprom i2c interface
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

    // eeprom i2c interface
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


