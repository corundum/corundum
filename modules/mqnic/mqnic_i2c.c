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

static struct i2c_board_info mqnic_eeprom_info = {
    I2C_BOARD_INFO("24c02", 0x50),
};

int mqnic_init_i2c(struct mqnic_dev *mqnic)
{
    int ret = 0;
    // interface i2c interfaces
    // TODO

    // eeprom i2c interface
    switch (mqnic->board_id) {
    case MQNIC_BOARD_ID_EXANIC_X10:
    case MQNIC_BOARD_ID_EXANIC_X25:
    case MQNIC_BOARD_ID_ADM_PCIE_9V3:
        mqnic->eeprom_i2c_adap.owner = THIS_MODULE;
        mqnic->eeprom_i2c_priv.mqnic = mqnic;
        mqnic->eeprom_i2c_priv.scl_in_reg = mqnic->hw_addr+MQNIC_REG_GPIO_IN;
        mqnic->eeprom_i2c_priv.scl_out_reg = mqnic->hw_addr+MQNIC_REG_GPIO_OUT;
        mqnic->eeprom_i2c_priv.sda_in_reg = mqnic->hw_addr+MQNIC_REG_GPIO_IN;
        mqnic->eeprom_i2c_priv.sda_out_reg = mqnic->hw_addr+MQNIC_REG_GPIO_OUT;
        mqnic->eeprom_i2c_priv.scl_in_mask = 1 << 24;
        mqnic->eeprom_i2c_priv.scl_out_mask = 1 << 24;
        mqnic->eeprom_i2c_priv.sda_in_mask = 1 << 25;
        mqnic->eeprom_i2c_priv.sda_out_mask = 1 << 25;
        mqnic->eeprom_i2c_algo = mqnic_i2c_algo;
        mqnic->eeprom_i2c_algo.data = &mqnic->eeprom_i2c_priv;
        mqnic->eeprom_i2c_adap.algo_data = &mqnic->eeprom_i2c_algo;
        mqnic->eeprom_i2c_adap.dev.parent = mqnic->dev;
        iowrite32(ioread32(mqnic->hw_addr+MQNIC_REG_GPIO_OUT) & ~(1 << 26), mqnic->hw_addr+MQNIC_REG_GPIO_OUT); // WP disable
        strlcpy(mqnic->eeprom_i2c_adap.name, "mqnic EEPROM", sizeof(mqnic->eeprom_i2c_adap.name));
        ret = i2c_bit_add_bus(&mqnic->eeprom_i2c_adap);
        if (ret)
        {
            return ret;
        }

        mqnic->eeprom_i2c_client = i2c_new_device(&mqnic->eeprom_i2c_adap, &mqnic_eeprom_info);
        if (mqnic->eeprom_i2c_client == NULL)
        {
            ret = -ENODEV;
        }
        break;
    }

    return ret;
}

void mqnic_remove_i2c(struct mqnic_dev *mqnic)
{
    // eeprom i2c interface
    if (mqnic->eeprom_i2c_client)
    {
        i2c_unregister_device(mqnic->eeprom_i2c_client);
        mqnic->eeprom_i2c_client = NULL;
    }

    if (mqnic->eeprom_i2c_adap.owner)
    {
        i2c_del_adapter(&mqnic->eeprom_i2c_adap);
    }

    memset(&mqnic->eeprom_i2c_adap, 0, sizeof(mqnic->eeprom_i2c_adap));
}


