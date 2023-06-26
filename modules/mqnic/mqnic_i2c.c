// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

static void mqnic_i2c_set_scl(void *data, int state)
{
	struct mqnic_i2c_bus *bus = data;

	if (state)
		iowrite32(ioread32(bus->scl_out_reg) | bus->scl_out_mask, bus->scl_out_reg);
	else
		iowrite32(ioread32(bus->scl_out_reg) & ~bus->scl_out_mask, bus->scl_out_reg);
}

static void mqnic_i2c_set_sda(void *data, int state)
{
	struct mqnic_i2c_bus *bus = data;

	if (state)
		iowrite32(ioread32(bus->sda_out_reg) | bus->sda_out_mask, bus->sda_out_reg);
	else
		iowrite32(ioread32(bus->sda_out_reg) & ~bus->sda_out_mask, bus->sda_out_reg);
}

static int mqnic_i2c_get_scl(void *data)
{
	struct mqnic_i2c_bus *bus = data;

	return !!(ioread32(bus->scl_in_reg) & bus->scl_in_mask);
}

static int mqnic_i2c_get_sda(void *data)
{
	struct mqnic_i2c_bus *bus = data;

	return !!(ioread32(bus->sda_in_reg) & bus->sda_in_mask);
}

struct mqnic_i2c_bus *mqnic_i2c_bus_create(struct mqnic_dev *mqnic, int index)
{
	struct mqnic_i2c_bus *bus;
	struct i2c_algo_bit_data *algo;
	struct i2c_adapter *adapter;
	struct mqnic_reg_block *rb;

	rb = mqnic_find_reg_block(mqnic->rb_list, MQNIC_RB_I2C_TYPE, MQNIC_RB_I2C_VER, index);

	if (!rb)
		return NULL;

	bus = kzalloc(sizeof(*bus), GFP_KERNEL);

	if (!bus)
		return NULL;

	// set private data
	bus->mqnic = mqnic;
	bus->scl_in_reg = rb->regs + MQNIC_RB_I2C_REG_CTRL;
	bus->scl_out_reg = rb->regs + MQNIC_RB_I2C_REG_CTRL;
	bus->sda_in_reg = rb->regs + MQNIC_RB_I2C_REG_CTRL;
	bus->sda_out_reg = rb->regs + MQNIC_RB_I2C_REG_CTRL;
	bus->scl_in_mask = MQNIC_REG_GPIO_I2C_SCL_IN;
	bus->scl_out_mask = MQNIC_REG_GPIO_I2C_SCL_OUT;
	bus->sda_in_mask = MQNIC_REG_GPIO_I2C_SDA_IN;
	bus->sda_out_mask = MQNIC_REG_GPIO_I2C_SDA_OUT;

	// bit-bang algorithm setup
	algo = &bus->algo;
	algo->udelay = 5;
	algo->timeout = usecs_to_jiffies(2000);
	algo->setsda = mqnic_i2c_set_sda;
	algo->setscl = mqnic_i2c_set_scl;
	algo->getsda = mqnic_i2c_get_sda;
	algo->getscl = mqnic_i2c_get_scl;
	algo->data = bus;

	// adapter setup
	adapter = &bus->adapter;
	adapter->owner = THIS_MODULE;
	adapter->algo_data = algo;
	adapter->dev.parent = mqnic->dev;
	snprintf(adapter->name, sizeof(adapter->name), "%s I2C%d", mqnic->name,
			mqnic->i2c_adapter_count);

	if (i2c_bit_add_bus(adapter)) {
		dev_err(mqnic->dev, "Failed to register I2C adapter");
		goto err_free_bus;
	}

	list_add_tail(&bus->head, &mqnic->i2c_bus);

	mqnic->i2c_adapter_count++;

	return bus;

err_free_bus:
	kfree(bus);
	return NULL;
}

struct i2c_adapter *mqnic_i2c_adapter_create(struct mqnic_dev *mqnic, int index)
{
	struct mqnic_i2c_bus *bus = mqnic_i2c_bus_create(mqnic, index);

	if (!bus)
		return NULL;

	return &bus->adapter;
}

void mqnic_i2c_bus_release(struct mqnic_i2c_bus *bus)
{
	struct mqnic_dev *mqnic;

	if (!bus)
		return;

	mqnic = bus->mqnic;

	mqnic->i2c_adapter_count--;

	i2c_del_adapter(&bus->adapter);
	list_del(&bus->head);
	kfree(bus);
}

void mqnic_i2c_adapter_release(struct i2c_adapter *adapter)
{
	struct mqnic_i2c_bus *bus;

	if (!adapter)
		return;

	bus = container_of(adapter, struct mqnic_i2c_bus, adapter);
	mqnic_i2c_bus_release(bus);
}

int mqnic_i2c_init(struct mqnic_dev *mqnic)
{
	INIT_LIST_HEAD(&mqnic->i2c_bus);

	return 0;
}

void mqnic_i2c_deinit(struct mqnic_dev *mqnic)
{
	struct mqnic_i2c_bus *bus;

	while (!list_empty(&mqnic->i2c_bus)) {
		bus = list_first_entry(&mqnic->i2c_bus, typeof(*bus), head);
		mqnic_i2c_bus_release(bus);
	}
}
