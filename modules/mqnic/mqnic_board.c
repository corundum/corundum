// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <linux/module.h>
#include <linux/i2c-mux.h>
#include <linux/version.h>

static const struct property_entry i2c_mux_props[] = {
	PROPERTY_ENTRY_BOOL("i2c-mux-idle-disconnect"),
	{}
};

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 13, 0)
static const struct software_node i2c_mux_node = {
	.properties = i2c_mux_props
};
#endif

static struct i2c_client *create_i2c_client(struct i2c_adapter *adapter,
		const char *type, int addr)
{
	struct i2c_client *client;
	struct i2c_board_info board_info;
	int err;

	if (!adapter)
		return NULL;

	memset(&board_info, 0, sizeof(board_info));
	strscpy(board_info.type, type, I2C_NAME_SIZE);
	board_info.addr = addr;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 13, 0)
	board_info.swnode = &i2c_mux_node;
#else
	board_info.properties = i2c_mux_props;
#endif
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 2, 0)
	client = i2c_new_client_device(adapter, &board_info);
#else
	client = i2c_new_device(adapter, &board_info);
#endif

	if (!client)
		return NULL;

	// force driver load (mainly for muxes so we can talk to downstream devices)
	err = device_attach(&client->dev);
	if (err < 0)
		goto err_free_client;

	return client;

err_free_client:
	i2c_unregister_device(client);
	return NULL;
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

static int init_mac_list_from_base_mac(struct mqnic_dev *mqnic, int count, char *mac)
{
	int k;

	count = min(count, MQNIC_MAX_IF);

	if (!is_valid_ether_addr(mac)) {
		dev_warn(mqnic->dev, "Base MAC is not valid");
		return -1;
	}

	mqnic->mac_count = count;
	for (k = 0; k < mqnic->mac_count; k++) {
		memcpy(mqnic->mac_list[k], mac, ETH_ALEN);
		mqnic->mac_list[k][ETH_ALEN - 1] += k;
	}

	return count;
}

static int read_mac_from_eeprom(struct mqnic_dev *mqnic,
		struct i2c_client *eeprom, int offset, char *mac)
{
	int ret;

	if (!eeprom) {
		dev_warn(mqnic->dev, "Failed to read MAC from EEPROM; no EEPROM I2C client registered");
		return -1;
	}

	ret = i2c_smbus_read_i2c_block_data(eeprom, offset, ETH_ALEN, mac);
	if (ret < 0) {
		dev_warn(mqnic->dev, "Failed to read MAC from EEPROM");
		return -1;
	}

	return 0;
}

static int read_mac_from_eeprom_hex(struct mqnic_dev *mqnic,
		struct i2c_client *eeprom, int offset, char *mac)
{
	int ret;
	char mac_hex[3*ETH_ALEN];

	if (!eeprom) {
		dev_warn(mqnic->dev, "Failed to read MAC from EEPROM; no EEPROM I2C client registered");
		return -1;
	}

	ret = i2c_smbus_read_i2c_block_data(eeprom, offset, 3 * ETH_ALEN - 1, mac_hex);
	mac_hex[3*ETH_ALEN-1] = 0;
	if (ret < 0 || !mac_pton(mac_hex, mac)) {
		dev_warn(mqnic->dev, "Failed to read MAC from EEPROM");
		return -1;
	}

	return 0;
}

static int init_mac_list_from_eeprom(struct mqnic_dev *mqnic,
		struct i2c_client *eeprom, int offset, int count)
{
	int ret, k;
	char mac[ETH_ALEN];

	count = min(count, MQNIC_MAX_IF);

	for (k = 0; k < count; k++) {
		ret = read_mac_from_eeprom(mqnic, eeprom, offset + ETH_ALEN*k, mac);
		if (ret < 0)
			return ret;

		if (!is_valid_ether_addr(mac)) {
			dev_warn(mqnic->dev, "MAC is not valid");
			return -1;
		}

		memcpy(mqnic->mac_list[k], mac, ETH_ALEN);
		mqnic->mac_count = k+1;
	}

	return 0;
}

static int init_mac_list_from_eeprom_base(struct mqnic_dev *mqnic,
		struct i2c_client *eeprom, int offset, int count)
{
	int ret;
	char mac[ETH_ALEN];

	ret = read_mac_from_eeprom(mqnic, eeprom, offset, mac);
	if (ret < 0)
		return ret;

	if (!is_valid_ether_addr(mac)) {
		dev_warn(mqnic->dev, "EEPROM does not contain a valid base MAC");
		return -1;
	}

	return init_mac_list_from_base_mac(mqnic, count, mac);
}

static int init_mac_list_from_eeprom_base_hex(struct mqnic_dev *mqnic,
		struct i2c_client *eeprom, int offset, int count)
{
	int ret;
	char mac[ETH_ALEN];

	ret = read_mac_from_eeprom_hex(mqnic, eeprom, offset, mac);
	if (ret < 0)
		return ret;

	if (!is_valid_ether_addr(mac)) {
		dev_warn(mqnic->dev, "EEPROM does not contain a valid base MAC");
		return -1;
	}

	return init_mac_list_from_base_mac(mqnic, count, mac);
}

static int mqnic_generic_board_init(struct mqnic_dev *mqnic)
{
	struct i2c_adapter *adapter;
	struct i2c_client *mux;
	struct i2c_client *client;
	int ret = 0;

	mqnic->mod_i2c_client_count = 0;

	if (mqnic_i2c_init(mqnic)) {
		dev_err(mqnic->dev, "Failed to initialize I2C subsystem");
		return -1;
	}

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
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// IC31 TCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x74);

		// IC3 SFP1
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50);

		// IC5 SFP2
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50);

		// IC6 SFP3
		mqnic->mod_i2c_client[2] = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c02", 0x50);

		// IC8 SFP4
		mqnic->mod_i2c_client[3] = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c02", 0x50);

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
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// U28 TCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x74);

		// U145 QSFP
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c02", 0x50);

		// U80 PCA9544 I2C MUX
		mux = create_i2c_client(adapter, "pca9544", 0x75);

		// U12 I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c08", 0x54);

		mqnic->mod_i2c_client_count = 1;

		// read MACs from EEPROM
		init_mac_list_from_eeprom_base(mqnic, mqnic->eeprom_i2c_client, 0x20, MQNIC_MAX_IF);

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
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// U28 TCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x74);

		// U145 QSFP1
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c02", 0x50);

		// U123 QSFP2
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c02", 0x50);

		// U80 PCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x75);

		// U12 I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 3), "24c08", 0x54);

		mqnic->mod_i2c_client_count = 2;

		// read MACs from EEPROM
		init_mac_list_from_eeprom_base(mqnic, mqnic->eeprom_i2c_client, 0x20, MQNIC_MAX_IF);

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
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// U28 TCA9546 I2C MUX
		mux = create_i2c_client(adapter, "pca9546", 0x74);

		// J7 QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50);

		// J9 QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50);

		// U12 I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c08", 0x54);

		mqnic->mod_i2c_client_count = 2;

		// read MACs from EEPROM
		init_mac_list_from_eeprom_base(mqnic, mqnic->eeprom_i2c_client, 0x20, MQNIC_MAX_IF);

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
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// U34 TCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x74);

		// U23 I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c08", 0x54);

		// U135 TCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x75);

		// P1 SFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 7), "24c02", 0x50);

		// P2 SFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 6), "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		// read MACs from EEPROM
		init_mac_list_from_eeprom_base(mqnic, mqnic->eeprom_i2c_client, 0x20, MQNIC_MAX_IF);

		break;
	case MQNIC_BOARD_ID_DK_DEV_1SMX_H_A:

		request_module("i2c_mux_pca954x");
		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// Virtual I2C MUX
		mux = create_i2c_client(adapter, "pca9543", 0x74);

		// J4 QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50);

		// J5 QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		break;
	case MQNIC_BOARD_ID_DK_DEV_1SDX_P_A:

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// FPC202 default address 0x0f, module addresses 0x78 and 0x7c
		// release reset and deassert lpmode
		client = create_i2c_client(adapter, "24c02", 0x0f);

		if (client) {
			i2c_smbus_write_i2c_block_data(client, 0x08, 1, "\x55");
			i2c_smbus_write_i2c_block_data(client, 0x0A, 1, "\x05");

			i2c_unregister_device(client);
		}

		// QSFP 1
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x78);

		// QSFP 2
		mqnic->mod_i2c_client[1] = create_i2c_client(adapter, "24c02", 0x7c);

		mqnic->mod_i2c_client_count = 2;

		// U94 I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c128", 0x57);

		break;
	case MQNIC_BOARD_ID_DK_DEV_AGF014EA:

		request_module("i2c_mux_pca954x");
		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// U23 I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c64", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// Virtual I2C MUX
		mux = create_i2c_client(adapter, "pca9543", 0x74);

		// QSFPDD0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50);

		// QSFPDD1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		break;
	case MQNIC_BOARD_ID_DE10_AGILEX:

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// QSFP-DD A
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// QSFP-DD B
		mqnic->mod_i2c_client[1] = create_i2c_client(adapter, "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		break;
	case MQNIC_BOARD_ID_250SOC:
		// FPGA I2C
		//   TCA9548 U28 0x72
		//     CH0: J6 (OCuLink ch 0) A
		//     CH1: J6 (OCuLink ch 0) B
		//     CH2: J7 (OCuLink ch 1) A
		//     CH3: J8 (OCuLink ch 2) A
		//     CH4: J9 (OCuLink ch 3) A
		//     CH5: J9 (OCuLink ch 3) B
		//     CH6: QSFP0
		//     CH7: QSFP1
		// FPGA SMBUS
		//   AT24C16C U51 0x54
		//   TMP431C U52 0x4C

		request_module("i2c_mux_pca954x");
		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// U34 TCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x70);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 6), "24c02", 0x50);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 7), "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 2);

		// I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c16", 0x50);

		break;
	case MQNIC_BOARD_ID_520NMX:
		// FPGA I2C
		//   TCA9548 0x72
		//     CH0: OC_2 J22
		//     CH1: OC_3 J23
		//     CH2: OC_0 J26
		//     CH3: OC_1 J27
		//     CH4: QSFP_0
		//     CH5: QSFP_1
		//     CH6: QSFP_2
		//     CH7: QSFP_3
		//   EEPROM 0x57

		request_module("i2c_mux_pca954x");
		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// TCA9548 I2C MUX
		mux = create_i2c_client(adapter, "pca9548", 0x72);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 4), "24c02", 0x50);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 5), "24c02", 0x50);

		// QSFP2
		mqnic->mod_i2c_client[2] = create_i2c_client(get_i2c_mux_channel(mux, 6), "24c02", 0x50);

		// QSFP3
		mqnic->mod_i2c_client[3] = create_i2c_client(get_i2c_mux_channel(mux, 7), "24c02", 0x50);

		mqnic->mod_i2c_client_count = 4;

		// I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c02", 0x57);

		// read MACs from EEPROM
		init_mac_list_from_eeprom(mqnic, mqnic->eeprom_i2c_client, 0x4B, 16);

		break;
	case MQNIC_BOARD_ID_XUSP3S:
	case MQNIC_BOARD_ID_XUPP3R:

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 2);

		// QSFP2
		mqnic->mod_i2c_client[2] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 3);

		// QSFP3
		mqnic->mod_i2c_client[3] = create_i2c_client(adapter, "24c02", 0x50);

		mqnic->mod_i2c_client_count = 4;

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 4);

		// I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c04", 0x50);

		// read MACs from EEPROM
		init_mac_list_from_eeprom_base_hex(mqnic, mqnic->eeprom_i2c_client, 4, MQNIC_MAX_IF);

		break;
	case MQNIC_BOARD_ID_IA_420F:

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// QSFP-DD
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x50);

		mqnic->mod_i2c_client_count = 1;

		// I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c02", 0x57);

		// read MACs from EEPROM
		init_mac_list_from_eeprom(mqnic, mqnic->eeprom_i2c_client, 0x56, 1);

		break;
	case MQNIC_BOARD_ID_NEXUS_K35_S:
	case MQNIC_BOARD_ID_NEXUS_K3P_S:
	case MQNIC_BOARD_ID_ADM_PCIE_9V3:

		request_module("i2c_mux_pca954x");
		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// Virtual I2C MUX
		mux = create_i2c_client(adapter, "pca9543", 0x74);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		// create I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c02", 0x50);

		// read MACs from EEPROM
		init_mac_list_from_eeprom_base(mqnic, mqnic->eeprom_i2c_client, 0, MQNIC_MAX_IF);

		break;
	case MQNIC_BOARD_ID_NEXUS_K3P_Q:

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(adapter, "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 2);

		// I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c02", 0x50);

		// read MACs from EEPROM
		init_mac_list_from_eeprom_base(mqnic, mqnic->eeprom_i2c_client, 0, MQNIC_MAX_IF);

		break;
	case MQNIC_BOARD_ID_DNPCIE_40G_KU:

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(adapter, "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 2);

		// I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(adapter, "24c256", 0x50);

		// read MACs from EEPROM
		// init_mac_list_from_eeprom(mqnic, mqnic->eeprom_i2c_client, 0x000E, MQNIC_MAX_IF);

		break;
	case MQNIC_BOARD_ID_FB4CGG3_VU9P:

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 2);

		// QSFP2
		mqnic->mod_i2c_client[2] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 3);

		// QSFP3
		mqnic->mod_i2c_client[3] = create_i2c_client(adapter, "24c02", 0x50);

		mqnic->mod_i2c_client_count = 4;

		break;
	default:
		dev_warn(mqnic->dev, "Unknown board ID, not performing any board-specific init");
	}

	return ret;
}

static void mqnic_generic_board_deinit(struct mqnic_dev *mqnic)
{
	int k;

	// unregister I2C clients
	for (k = 0; k < ARRAY_SIZE(mqnic->mod_i2c_client); k++) {
		if (mqnic->mod_i2c_client[k]) {
			i2c_unregister_device(mqnic->mod_i2c_client[k]);
			mqnic->mod_i2c_client[k] = NULL;
		}
	}

	if (mqnic->eeprom_i2c_client) {
		i2c_unregister_device(mqnic->eeprom_i2c_client);
		mqnic->eeprom_i2c_client = NULL;
	}

	mqnic_i2c_deinit(mqnic);
}

static struct mqnic_board_ops generic_board_ops = {
	.init = mqnic_generic_board_init,
	.deinit = mqnic_generic_board_deinit
};

static u32 mqnic_alveo_bmc_reg_read(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, u32 reg)
{
	iowrite32(reg, rb->regs + MQNIC_RB_ALVEO_BMC_REG_ADDR);
	ioread32(rb->regs + MQNIC_RB_ALVEO_BMC_REG_DATA); // dummy read
	return ioread32(rb->regs + MQNIC_RB_ALVEO_BMC_REG_DATA);
}

static void mqnic_alveo_bmc_reg_write(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, u32 reg, u32 val)
{
	iowrite32(reg, rb->regs + MQNIC_RB_ALVEO_BMC_REG_ADDR);
	iowrite32(val, rb->regs + MQNIC_RB_ALVEO_BMC_REG_DATA);
	ioread32(rb->regs + MQNIC_RB_ALVEO_BMC_REG_DATA); // dummy read
}

static int mqnic_alveo_bmc_read_mac(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, int index, char *mac)
{
	u32 reg = 0x0281a0 + index * 8;
	u32 val;

	val = mqnic_alveo_bmc_reg_read(mqnic, rb, reg);
	mac[0] = (val >> 8) & 0xff;
	mac[1] = val & 0xff;

	val = mqnic_alveo_bmc_reg_read(mqnic, rb, reg + 4);
	mac[2] = (val >> 24) & 0xff;
	mac[3] = (val >> 16) & 0xff;
	mac[4] = (val >> 8) & 0xff;
	mac[5] = val & 0xff;

	return 0;
}

static int mqnic_alveo_bmc_read_mac_list(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, int count)
{
	int ret, k;
	char mac[ETH_ALEN];

	count = min(count, MQNIC_MAX_IF);

	mqnic->mac_count = 0;
	for (k = 0; k < count; k++) {
		ret = mqnic_alveo_bmc_read_mac(mqnic, rb, k, mac);
		if (ret) {
			dev_warn(mqnic->dev, "Failed to read MAC from Alveo BMC");
			return -1;
		}

		if (is_valid_ether_addr(mac)) {
			memcpy(mqnic->mac_list[mqnic->mac_count], mac, ETH_ALEN);
			mqnic->mac_count++;
		}
	}

	dev_info(mqnic->dev, "Read %d MACs from Alveo BMC", mqnic->mac_count);

	if (mqnic->mac_count == 0)
		dev_warn(mqnic->dev, "Failed to read any valid MACs from Alveo BMC");

	return mqnic->mac_count;
}

static int mqnic_alveo_board_init(struct mqnic_dev *mqnic)
{
	struct i2c_adapter *adapter;
	struct i2c_client *mux;
	struct mqnic_reg_block *rb;
	int ret = 0;

	mqnic->mod_i2c_client_count = 0;

	if (mqnic_i2c_init(mqnic)) {
		dev_err(mqnic->dev, "Failed to initialize I2C subsystem");
		return -1;
	}

	switch (mqnic->board_id) {
	case MQNIC_BOARD_ID_AU200:
	case MQNIC_BOARD_ID_AU250:
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
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// U28 TCA9546 I2C MUX
		mux = create_i2c_client(adapter, "pca9546", 0x74);

		// J7 QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(get_i2c_mux_channel(mux, 0), "24c02", 0x50);

		// J9 QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(get_i2c_mux_channel(mux, 1), "24c02", 0x50);

		// U12 I2C EEPROM
		mqnic->eeprom_i2c_client = create_i2c_client(get_i2c_mux_channel(mux, 2), "24c08", 0x54);

		mqnic->mod_i2c_client_count = 2;

		break;
	case MQNIC_BOARD_ID_AU45:
	case MQNIC_BOARD_ID_AU50:
	case MQNIC_BOARD_ID_AU55:
	case MQNIC_BOARD_ID_AU280:
		// no I2C interfaces

		break;
	default:
		dev_warn(mqnic->dev, "Unknown Alveo board ID");
	}

	// init BMC
	rb = mqnic_find_reg_block(mqnic->rb_list, MQNIC_RB_ALVEO_BMC_TYPE, MQNIC_RB_ALVEO_BMC_VER, 0);

	if (rb) {
		if (mqnic_alveo_bmc_reg_read(mqnic, rb, 0x020000) == 0 ||
		    mqnic_alveo_bmc_reg_read(mqnic, rb, 0x028000) != 0x74736574) {
			dev_info(mqnic->dev, "Resetting Alveo CMS");

			mqnic_alveo_bmc_reg_write(mqnic, rb, 0x020000, 0);
			mqnic_alveo_bmc_reg_write(mqnic, rb, 0x020000, 1);
			msleep(200);
		}

		if (mqnic_alveo_bmc_reg_read(mqnic, rb, 0x028000) != 0x74736574)
			dev_warn(mqnic->dev, "Alveo CMS not responding");
		else
			mqnic_alveo_bmc_read_mac_list(mqnic, rb, 8);
	} else {
		dev_warn(mqnic->dev, "Alveo CMS not found");
	}

	return ret;
}

static struct mqnic_board_ops alveo_board_ops = {
	.init = mqnic_alveo_board_init,
	.deinit = mqnic_generic_board_deinit
};

static int mqnic_gecko_bmc_read(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb)
{
	u32 val;
	int timeout = 200;

	while (1) {
		val = ioread32(rb->regs + MQNIC_RB_GECKO_BMC_REG_STATUS);
		if (val & BIT(19)) {
			if (val & BIT(18)) {
				// timed out
				dev_warn(mqnic->dev, "Timed out waiting for Gecko BMC response");
				msleep(20);
				return -2;
			}
			return val & 0xffff;
		}

		timeout--;
		if (timeout == 0) {
			dev_warn(mqnic->dev, "Timed out waiting for Gecko BMC interface");
			return -1;
		}
		usleep_range(1000, 100000);
	}

	return -1;
}

static int mqnic_gecko_bmc_write(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, u16 cmd, u32 data)
{
	int ret;

	ret = mqnic_gecko_bmc_read(mqnic, rb);

	if (ret == -1)
		return ret;

	iowrite32(data, rb->regs + MQNIC_RB_GECKO_BMC_REG_DATA);
	iowrite32(cmd << 16, rb->regs + MQNIC_RB_GECKO_BMC_REG_CMD);

	return 0;
}

static int mqnic_gecko_bmc_query(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, u16 cmd, u32 data)
{
	int ret;

	ret = mqnic_gecko_bmc_write(mqnic, rb, cmd, data);

	if (ret)
		return ret;

	return mqnic_gecko_bmc_read(mqnic, rb);
}

static int mqnic_gecko_bmc_read_mac(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, int index, char *mac)
{
	int i;
	u16 val;

	for (i = 0; i < ETH_ALEN; i += 2) {
		val = mqnic_gecko_bmc_query(mqnic, rb, 0x2003, 0 + index * ETH_ALEN + i);
		if (val < 0)
			return val;
		mac[i] = val & 0xff;
		mac[i + 1] = (val >> 8) & 0xff;
	}

	return 0;
}

static int mqnic_gecko_bmc_read_mac_list(struct mqnic_dev *mqnic, struct mqnic_reg_block *rb, int count)
{
	int ret, k;
	char mac[ETH_ALEN];

	count = min(count, MQNIC_MAX_IF);

	mqnic->mac_count = 0;
	for (k = 0; k < count; k++) {
		ret = mqnic_gecko_bmc_read_mac(mqnic, rb, k, mac);
		if (ret) {
			dev_warn(mqnic->dev, "Failed to read MAC from Gecko BMC");
			return -1;
		}

		if (is_valid_ether_addr(mac)) {
			memcpy(mqnic->mac_list[mqnic->mac_count], mac, ETH_ALEN);
			mqnic->mac_count++;
		}
	}

	dev_info(mqnic->dev, "Read %d MACs from Gecko BMC", mqnic->mac_count);

	if (mqnic->mac_count == 0)
		dev_warn(mqnic->dev, "Failed to read any valid MACs from Gecko BMC");

	return mqnic->mac_count;
}

static int mqnic_gecko_board_init(struct mqnic_dev *mqnic)
{
	struct i2c_adapter *adapter;
	struct mqnic_reg_block *rb;
	int ret = 0;

	mqnic->mod_i2c_client_count = 0;

	if (mqnic_i2c_init(mqnic)) {
		dev_err(mqnic->dev, "Failed to initialize I2C subsystem");
		return -1;
	}

	switch (mqnic->board_id) {
	case MQNIC_BOARD_ID_FB2CG_KU15P:
		// FPGA U1 I2C0
		//     QSFP0 J3 0x50
		// FPGA U1 I2C1
		//     QSFP1 J4 0x50

		request_module("at24");

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 0);

		// QSFP0
		mqnic->mod_i2c_client[0] = create_i2c_client(adapter, "24c02", 0x50);

		// I2C adapter
		adapter = mqnic_i2c_adapter_create(mqnic, 1);

		// QSFP1
		mqnic->mod_i2c_client[1] = create_i2c_client(adapter, "24c02", 0x50);

		mqnic->mod_i2c_client_count = 2;

		break;
	default:
		dev_warn(mqnic->dev, "Unknown board ID (Silicom Gecko BMC)");
	}

	// init BMC
	rb = mqnic_find_reg_block(mqnic->rb_list, MQNIC_RB_GECKO_BMC_TYPE, MQNIC_RB_GECKO_BMC_VER, 0);

	if (rb) {
		if (mqnic_gecko_bmc_query(mqnic, rb, 0x7006, 0) <= 0) {
			dev_warn(mqnic->dev, "Gecko BMC not responding");
		} else {
			u16 v_l = mqnic_gecko_bmc_query(mqnic, rb, 0x7005, 0);
			u16 v_h = mqnic_gecko_bmc_query(mqnic, rb, 0x7006, 0);

			dev_info(mqnic->dev, "Gecko BMC version %d.%d.%d.%d",
					(v_h >> 8) & 0xff, v_h & 0xff, (v_l >> 8) & 0xff, v_l & 0xff);

			mqnic_gecko_bmc_read_mac_list(mqnic, rb, 8);
		}
	} else {
		dev_warn(mqnic->dev, "Gecko BMC not found");
	}

	return ret;
}

static struct mqnic_board_ops gecko_board_ops = {
	.init = mqnic_gecko_board_init,
	.deinit = mqnic_generic_board_deinit
};

int mqnic_board_init(struct mqnic_dev *mqnic)
{
	switch (mqnic->board_id) {
	case MQNIC_BOARD_ID_AU45:
	case MQNIC_BOARD_ID_AU50:
	case MQNIC_BOARD_ID_AU55:
	case MQNIC_BOARD_ID_AU200:
	case MQNIC_BOARD_ID_AU250:
	case MQNIC_BOARD_ID_AU280:
		mqnic->board_ops = &alveo_board_ops;
		break;
	case MQNIC_BOARD_ID_FB2CG_KU15P:
		mqnic->board_ops = &gecko_board_ops;
		break;
	default:
		mqnic->board_ops = &generic_board_ops;
	}

	if (!mqnic->board_ops)
		return -1;

	return mqnic->board_ops->init(mqnic);
}

void mqnic_board_deinit(struct mqnic_dev *mqnic)
{
	if (!mqnic->board_ops)
		return;

	mqnic->board_ops->deinit(mqnic);
	mqnic->board_ops = NULL;
}
