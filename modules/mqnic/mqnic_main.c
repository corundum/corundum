// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2019-2021, The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of The Regents of the
 * University of California.
 */

#include "mqnic.h"
#include <linux/module.h>
#include <linux/version.h>
#include <linux/delay.h>
#include <linux/rtc.h>

#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 4, 0)
#include <linux/pci-aspm.h>
#endif

MODULE_DESCRIPTION("mqnic driver");
MODULE_AUTHOR("Alex Forencich");
MODULE_LICENSE("Dual BSD/GPL");
MODULE_VERSION(DRIVER_VERSION);

unsigned int mqnic_num_ev_queue_entries = 1024;
unsigned int mqnic_num_tx_queue_entries = 1024;
unsigned int mqnic_num_rx_queue_entries = 1024;

module_param_named(num_ev_queue_entries, mqnic_num_ev_queue_entries, uint, 0444);
MODULE_PARM_DESC(num_ev_queue_entries, "number of entries to allocate per event queue (default: 1024)");
module_param_named(num_tx_queue_entries, mqnic_num_tx_queue_entries, uint, 0444);
MODULE_PARM_DESC(num_tx_queue_entries, "number of entries to allocate per transmit queue (default: 1024)");
module_param_named(num_rx_queue_entries, mqnic_num_rx_queue_entries, uint, 0444);
MODULE_PARM_DESC(num_rx_queue_entries, "number of entries to allocate per receive queue (default: 1024)");

unsigned int mqnic_link_status_poll = MQNIC_LINK_STATUS_POLL_MS;

module_param_named(link_status_poll, mqnic_link_status_poll, uint, 0444);
MODULE_PARM_DESC(link_status_poll,
		 "link status polling interval, in ms (default: 1000; 0 to turn off)");


#ifdef CONFIG_PCI
static const struct pci_device_id mqnic_pci_id_table[] = {
	{PCI_DEVICE(0x1234, 0x1001)},
	{PCI_DEVICE(0x5543, 0x1001)},
	{0 /* end */ }
};

MODULE_DEVICE_TABLE(pci, mqnic_pci_id_table);
#endif

#ifdef CONFIG_OF
static struct of_device_id mqnic_of_id_table[] = {
	{ .compatible = "corundum,mqnic" },
	{ },
};
MODULE_DEVICE_TABLE(of, mqnic_of_id_table);
#endif

static LIST_HEAD(mqnic_devices);
static DEFINE_SPINLOCK(mqnic_devices_lock);

static unsigned int mqnic_get_free_id(void)
{
	struct mqnic_dev *mqnic;
	unsigned int id = 0;
	bool available = false;

	while (!available) {
		available = true;
		list_for_each_entry(mqnic, &mqnic_devices, dev_list_node) {
			if (mqnic->id == id) {
				available = false;
				id++;
				break;
			}
		}
	}

	return id;
}

static void mqnic_assign_id(struct mqnic_dev *mqnic)
{
	spin_lock(&mqnic_devices_lock);
	mqnic->id = mqnic_get_free_id();
	list_add_tail(&mqnic->dev_list_node, &mqnic_devices);
	spin_unlock(&mqnic_devices_lock);

	snprintf(mqnic->name, sizeof(mqnic->name), DRIVER_NAME "%d", mqnic->id);
}

static void mqnic_free_id(struct mqnic_dev *mqnic)
{
	spin_lock(&mqnic_devices_lock);
	list_del(&mqnic->dev_list_node);
	spin_unlock(&mqnic_devices_lock);
}

static int mqnic_common_setdma(struct mqnic_dev *mqnic)
{
	int ret;
	struct device *dev = mqnic->dev;

	// Set mask
	ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(64));
	if (ret) {
		dev_warn(dev, "Warning: failed to set 64 bit PCI DMA mask");
		ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(32));
		if (ret) {
			dev_err(dev, "Failed to set PCI DMA mask");
			return ret;
		}
	}

	// Set max segment size
	dma_set_max_seg_size(dev, DMA_BIT_MASK(32));

	return ret;
}

#ifdef CONFIG_OF
static int mqnic_platform_get_mac_address(struct mqnic_dev *mqnic)
{
	int ret;
	struct device *dev = mqnic->dev;
	char mac_base[ETH_ALEN];
	struct device_node *np;
	u32 inc_idx;
	u32 inc;
	int k;

	/* NOTE: Not being able to get a (base) MAC address shall not be an
	 *       error to fail on intentionally. Thus we are warning, only.
	 */
	ret = eth_platform_get_mac_address(dev, mac_base);
	if (ret) {
		dev_warn(dev, "Unable to get MAC address\n");
		return 0;
	}

	np = mqnic->dev->of_node;
	if (!np)
		return 0;

	if (of_property_read_u32(np, MQNIC_PROP_MAC_ADDR_INC_BYTE, &inc_idx))
		inc_idx = 5;
	if ((inc_idx < 3) || (inc_idx > 5)) {
		dev_err(dev, "Invalid property \"" MQNIC_PROP_MAC_ADDR_INC_BYTE "\"\n");
		return -EINVAL;
	}

	ret = of_property_read_u32(np, MQNIC_PROP_MAC_ADDR_INC, &inc);
	if (ret == -EINVAL) {
		inc = 0;
	} else if (ret) {
		dev_err(dev, "Invalid property \"" MQNIC_PROP_MAC_ADDR_INC "\"\n");
		return ret;
	}

	if (of_property_read_bool(np, MQNIC_PROP_MAC_ADDR_LOCAL))
		mac_base[0] |= BIT(1);

	mqnic->mac_count = mqnic->if_count;
	for (k = 0; k < mqnic->mac_count; k++) {
		memcpy(mqnic->mac_list[k], mac_base, ETH_ALEN);
		mqnic->mac_list[k][inc_idx] += inc + k;
	}

	return 0;
}

static void mqnic_platform_module_eeprom_put(struct mqnic_dev *mqnic)
{
	int k;

	for (k = 0; k < mqnic->if_count; k++)
		if (mqnic->mod_i2c_client)
			put_device(&mqnic->mod_i2c_client[k]->dev);
}

static int mqnic_platform_module_eeprom_get(struct mqnic_dev *mqnic)
{
	int ret;
	struct device *dev = mqnic->dev;
	int k;

	ret = 0;

	if (!dev->of_node)
		return 0;

	for (k = 0; k < mqnic->if_count; k++) {
		struct device_node *np;
		struct i2c_client *cl;

		/* NOTE: Not being able to get a phandle for module EEPROM shall
		 *       not be an error to fail on intentionally. Thus we are
		 *       warning, only.
		 */
		np = of_parse_phandle(dev->of_node, MQNIC_PROP_MODULE_EEPROM, k);
		if (!np) {
			dev_warn(dev, "Missing phandle to module EEPROM for interface %d\n", k);
			continue;
		}

		cl = of_find_i2c_device_by_node(np);
		if (!cl) {
			ret = -ENOENT;
			dev_err(dev, "Failed to find I2C device for module of interface %d\n", k);
			of_node_put(np);
			break;
		} else {
			mqnic->mod_i2c_client[k] = cl;
			mqnic->mod_i2c_client_count++;
		}
		of_node_put(np);
	}

	if (ret)
		mqnic_platform_module_eeprom_put(mqnic);

	return ret;
}
#endif

static void mqnic_common_remove(struct mqnic_dev *mqnic);

#ifdef CONFIG_AUXILIARY_BUS
static void mqnic_adev_release(struct device *dev)
{
	struct mqnic_adev *mqnic_adev = container_of(dev, struct mqnic_adev, adev.dev);

	if (mqnic_adev->ptr)
		*mqnic_adev->ptr = NULL;
	kfree(mqnic_adev);
}
#endif

static int mqnic_common_probe(struct mqnic_dev *mqnic)
{
	int ret = 0;
	struct device *dev = mqnic->dev;
	struct mqnic_reg_block *rb;
	struct rtc_time tm;

	int k = 0, l = 0;

	// Enumerate registers
	mqnic->rb_list = mqnic_enumerate_reg_block_list(mqnic->hw_addr, 0, mqnic->hw_regs_size);
	if (!mqnic->rb_list) {
		dev_err(dev, "Failed to enumerate blocks");
		return -EIO;
	}

	dev_info(dev, "Device-level register blocks:");
	for (rb = mqnic->rb_list; rb->regs; rb++)
		dev_info(dev, " type 0x%08x (v %d.%d.%d.%d)", rb->type, rb->version >> 24,
				(rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

	// Read ID registers
	mqnic->fw_id_rb = mqnic_find_reg_block(mqnic->rb_list, MQNIC_RB_FW_ID_TYPE, MQNIC_RB_FW_ID_VER, 0);

	if (!mqnic->fw_id_rb) {
		ret = -EIO;
		dev_err(dev, "Error: FW ID block not found");
		goto fail_rb_init;
	}

	mqnic->fpga_id = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_FPGA_ID);
	mqnic->fw_id = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_FW_ID);
	mqnic->fw_ver = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_FW_VER);
	mqnic->board_id = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_BOARD_ID);
	mqnic->board_ver = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_BOARD_VER);
	mqnic->build_date = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_BUILD_DATE);
	mqnic->git_hash = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_GIT_HASH);
	mqnic->rel_info = ioread32(mqnic->fw_id_rb->regs + MQNIC_RB_FW_ID_REG_REL_INFO);

	rtc_time64_to_tm(mqnic->build_date, &tm);

	dev_info(dev, "FPGA ID: 0x%08x", mqnic->fpga_id);
	dev_info(dev, "FW ID: 0x%08x", mqnic->fw_id);
	dev_info(dev, "FW version: %d.%d.%d.%d", mqnic->fw_ver >> 24,
			(mqnic->fw_ver >> 16) & 0xff,
			(mqnic->fw_ver >> 8) & 0xff,
			mqnic->fw_ver & 0xff);
	dev_info(dev, "Board ID: 0x%08x", mqnic->board_id);
	dev_info(dev, "Board version: %d.%d.%d.%d", mqnic->board_ver >> 24,
			(mqnic->board_ver >> 16) & 0xff,
			(mqnic->board_ver >> 8) & 0xff,
			mqnic->board_ver & 0xff);
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)
	dev_info(dev, "Build date: %ptRd %ptRt UTC (raw: 0x%08x)", &tm, &tm, mqnic->build_date);
#else
	dev_info(dev, "Build date: %04d-%02d-%02d %02d:%02d:%02d UTC (raw: 0x%08x)",
			tm.tm_year+1900, tm.tm_mon+1, tm.tm_mday,
			tm.tm_hour, tm.tm_min, tm.tm_sec, mqnic->build_date);
#endif
	dev_info(dev, "Git hash: %08x", mqnic->git_hash);
	dev_info(dev, "Release info: %08x", mqnic->rel_info);

	rb = mqnic_find_reg_block(mqnic->rb_list, MQNIC_RB_APP_INFO_TYPE, MQNIC_RB_APP_INFO_VER, 0);

	if (rb) {
		mqnic->app_id = ioread32(rb->regs + MQNIC_RB_APP_INFO_REG_ID);
		dev_info(dev, "Application ID: 0x%08x", mqnic->app_id);
	}

	mqnic_clk_info_init(mqnic);
	mqnic_stats_init(mqnic);

	mqnic->phc_rb = mqnic_find_reg_block(mqnic->rb_list, MQNIC_RB_PHC_TYPE, MQNIC_RB_PHC_VER, 0);

	// Enumerate interfaces
	mqnic->if_rb = mqnic_find_reg_block(mqnic->rb_list, MQNIC_RB_IF_TYPE, MQNIC_RB_IF_VER, 0);

	if (!mqnic->if_rb) {
		ret = -EIO;
		dev_err(dev, "Error: interface block not found");
		goto fail_rb_init;
	}

	mqnic->if_offset = ioread32(mqnic->if_rb->regs + MQNIC_RB_IF_REG_OFFSET);
	mqnic->if_count = ioread32(mqnic->if_rb->regs + MQNIC_RB_IF_REG_COUNT);
	mqnic->if_stride = ioread32(mqnic->if_rb->regs + MQNIC_RB_IF_REG_STRIDE);
	mqnic->if_csr_offset = ioread32(mqnic->if_rb->regs + MQNIC_RB_IF_REG_CSR_OFFSET);

	dev_info(dev, "IF offset: 0x%08x", mqnic->if_offset);
	dev_info(dev, "IF count: %d", mqnic->if_count);
	dev_info(dev, "IF stride: 0x%08x", mqnic->if_stride);
	dev_info(dev, "IF CSR offset: 0x%08x", mqnic->if_csr_offset);

	// check BAR size
	if (mqnic->if_count * mqnic->if_stride > mqnic->hw_regs_size) {
		ret = -EIO;
		dev_err(dev, "Invalid BAR configuration (%d IF * 0x%x > 0x%llx)",
				mqnic->if_count, mqnic->if_stride, mqnic->hw_regs_size);
		goto fail_bar_size;
	}

	if (mqnic->pfdev) {
#ifdef CONFIG_OF
		ret = mqnic_platform_get_mac_address(mqnic);
		if (ret)
			goto fail_board;

		ret = mqnic_platform_module_eeprom_get(mqnic);
		if (ret)
			goto fail_board;
#endif
	} else {
		// Board-specific init
		ret = mqnic_board_init(mqnic);
		if (ret) {
			dev_err(dev, "Failed to initialize board");
			goto fail_board;
		}
	}

	// register PHC
	if (mqnic->phc_rb)
		mqnic_register_phc(mqnic);

	mutex_init(&mqnic->state_lock);

	// Set up interfaces
	mqnic->dev_port_max = 0;
	mqnic->dev_port_limit = MQNIC_MAX_IF;

	mqnic->if_count = min_t(u32, mqnic->if_count, MQNIC_MAX_IF);

	for (k = 0; k < mqnic->if_count; k++) {
		dev_info(dev, "Creating interface %d", k);
		ret = mqnic_create_interface(mqnic, &mqnic->interface[k], k, mqnic->hw_addr + k * mqnic->if_stride);
		if (ret) {
			dev_err(dev, "Failed to create interface: %d", ret);
			goto fail_create_if;
		}
		mqnic->dev_port_max = mqnic->interface[k]->dev_port_max;
	}

	// pass module I2C clients to interface instances
	for (k = 0; k < mqnic->if_count; k++) {
		struct mqnic_if *interface = mqnic->interface[k];
		interface->mod_i2c_client = mqnic->mod_i2c_client[k];

		for (l = 0; l < interface->ndev_count; l++) {
			struct mqnic_priv *priv = netdev_priv(interface->ndev[l]);
			priv->mod_i2c_client = mqnic->mod_i2c_client[k];
		}
	}

fail_create_if:
	mqnic->misc_dev.minor = MISC_DYNAMIC_MINOR;
	mqnic->misc_dev.name = mqnic->name;
	mqnic->misc_dev.fops = &mqnic_fops;
	mqnic->misc_dev.parent = dev;

	ret = misc_register(&mqnic->misc_dev);
	if (ret) {
		mqnic->misc_dev.this_device = NULL;
		dev_err(dev, "misc_register failed: %d\n", ret);
		goto fail_miscdev;
	}

	dev_info(dev, "Registered device %s", mqnic->name);

#ifdef CONFIG_AUXILIARY_BUS
	if (mqnic->app_id) {
		mqnic->app_adev = kzalloc(sizeof(*mqnic->app_adev), GFP_KERNEL);
		if (!mqnic->app_adev) {
			ret = -ENOMEM;
			goto fail_adev;
		}

		snprintf(mqnic->app_adev->name, sizeof(mqnic->app_adev->name), "app_%08x", mqnic->app_id);

		mqnic->app_adev->adev.id = mqnic->id;
		mqnic->app_adev->adev.name = mqnic->app_adev->name;
		mqnic->app_adev->adev.dev.parent = dev;
		mqnic->app_adev->adev.dev.release = mqnic_adev_release;
		mqnic->app_adev->mdev = mqnic;
		mqnic->app_adev->ptr = &mqnic->app_adev;

		ret = auxiliary_device_init(&mqnic->app_adev->adev);
		if (ret) {
			kfree(mqnic->app_adev);
			mqnic->app_adev = NULL;
			goto fail_adev;
		}

		ret = auxiliary_device_add(&mqnic->app_adev->adev);
		if (ret) {
			auxiliary_device_uninit(&mqnic->app_adev->adev);
			mqnic->app_adev = NULL;
			goto fail_adev;
		}

		dev_info(dev, "Registered auxiliary bus device " DRIVER_NAME ".%s.%d",
				mqnic->app_adev->adev.name, mqnic->app_adev->adev.id);
	}
#endif

	// probe complete
	return 0;

	// error handling
#ifdef CONFIG_AUXILIARY_BUS
fail_adev:
#endif
fail_miscdev:
fail_board:
fail_bar_size:
fail_rb_init:
	mqnic_common_remove(mqnic);
	return ret;
}

static void mqnic_common_remove(struct mqnic_dev *mqnic)
{
	int k = 0;

#ifdef CONFIG_AUXILIARY_BUS
	if (mqnic->app_adev) {
		auxiliary_device_delete(&mqnic->app_adev->adev);
		auxiliary_device_uninit(&mqnic->app_adev->adev);
	}
#endif

	if (mqnic->misc_dev.this_device)
		misc_deregister(&mqnic->misc_dev);

	for (k = 0; k < ARRAY_SIZE(mqnic->interface); k++)
		if (mqnic->interface[k])
			mqnic_destroy_interface(&mqnic->interface[k]);

	mqnic_unregister_phc(mqnic);
	if (mqnic->pfdev) {
#ifdef CONFIG_OF
		mqnic_platform_module_eeprom_put(mqnic);
#endif
	} else {
		mqnic_board_deinit(mqnic);
	}
	if (mqnic->rb_list)
		mqnic_free_reg_block_list(mqnic->rb_list);
}

#ifdef CONFIG_PCI
static int mqnic_pci_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
	int ret = 0;
	struct mqnic_dev *mqnic;
	struct device *dev = &pdev->dev;
	struct pci_dev *bridge = pci_upstream_bridge(pdev);

	dev_info(dev, DRIVER_NAME " PCI probe");
	dev_info(dev, " Vendor: 0x%04x", pdev->vendor);
	dev_info(dev, " Device: 0x%04x", pdev->device);
	dev_info(dev, " Subsystem vendor: 0x%04x", pdev->subsystem_vendor);
	dev_info(dev, " Subsystem device: 0x%04x", pdev->subsystem_device);
	dev_info(dev, " Class: 0x%06x", pdev->class);
	dev_info(dev, " PCI ID: %04x:%02x:%02x.%d", pci_domain_nr(pdev->bus),
			pdev->bus->number, PCI_SLOT(pdev->devfn), PCI_FUNC(pdev->devfn));

	if (pdev->pcie_cap) {
		u16 devctl;
		u32 lnkcap;
		u16 lnksta;

		pci_read_config_word(pdev, pdev->pcie_cap + PCI_EXP_DEVCTL, &devctl);
		pci_read_config_dword(pdev, pdev->pcie_cap + PCI_EXP_LNKCAP, &lnkcap);
		pci_read_config_word(pdev, pdev->pcie_cap + PCI_EXP_LNKSTA, &lnksta);

		dev_info(dev, " Max payload size: %d bytes",
				128 << ((devctl & PCI_EXP_DEVCTL_PAYLOAD) >> 5));
		dev_info(dev, " Max read request size: %d bytes",
				128 << ((devctl & PCI_EXP_DEVCTL_READRQ) >> 12));
		dev_info(dev, " Link capability: gen %d x%d",
				lnkcap & PCI_EXP_LNKCAP_SLS, (lnkcap & PCI_EXP_LNKCAP_MLW) >> 4);
		dev_info(dev, " Link status: gen %d x%d",
				lnksta & PCI_EXP_LNKSTA_CLS, (lnksta & PCI_EXP_LNKSTA_NLW) >> 4);
		dev_info(dev, " Relaxed ordering: %s",
				devctl & PCI_EXP_DEVCTL_RELAX_EN ? "enabled" : "disabled");
		dev_info(dev, " Phantom functions: %s",
				devctl & PCI_EXP_DEVCTL_PHANTOM ? "enabled" : "disabled");
		dev_info(dev, " Extended tags: %s",
				devctl & PCI_EXP_DEVCTL_EXT_TAG ? "enabled" : "disabled");
		dev_info(dev, " No snoop: %s",
				devctl & PCI_EXP_DEVCTL_NOSNOOP_EN ? "enabled" : "disabled");
	}

#ifdef CONFIG_NUMA
	dev_info(dev, " NUMA node: %d", pdev->dev.numa_node);
#endif

	if (bridge) {
		dev_info(dev, " PCI ID (bridge): %04x:%02x:%02x.%d", pci_domain_nr(bridge->bus),
				bridge->bus->number, PCI_SLOT(bridge->devfn), PCI_FUNC(bridge->devfn));
	}

	if (bridge && bridge->pcie_cap) {
		u32 lnkcap;
		u16 lnksta;

		pci_read_config_dword(bridge, bridge->pcie_cap + PCI_EXP_LNKCAP, &lnkcap);
		pci_read_config_word(bridge, bridge->pcie_cap + PCI_EXP_LNKSTA, &lnksta);

		dev_info(dev, " Link capability (bridge): gen %d x%d",
				lnkcap & PCI_EXP_LNKCAP_SLS, (lnkcap & PCI_EXP_LNKCAP_MLW) >> 4);
		dev_info(dev, " Link status (bridge): gen %d x%d",
				lnksta & PCI_EXP_LNKSTA_CLS, (lnksta & PCI_EXP_LNKSTA_NLW) >> 4);
	}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 17, 0)
	pcie_print_link_status(pdev);
#endif

	mqnic = devm_kzalloc(dev, sizeof(*mqnic), GFP_KERNEL);
	if (!mqnic)
		return -ENOMEM;

	mqnic->dev = dev;
	mqnic->pdev = pdev;
	pci_set_drvdata(pdev, mqnic);

	// assign ID and add to list
	mqnic_assign_id(mqnic);

	// Disable ASPM
	pci_disable_link_state(pdev, PCIE_LINK_STATE_L0S |
			PCIE_LINK_STATE_L1 | PCIE_LINK_STATE_CLKPM);

	// Enable device
	ret = pci_enable_device_mem(pdev);
	if (ret) {
		dev_err(dev, "Failed to enable PCI device");
		goto fail_enable_device;
	}

	// Set DMA properties
	ret = mqnic_common_setdma(mqnic);
	if (ret)
		goto fail_regions;

	// Reserve regions
	ret = pci_request_regions(pdev, DRIVER_NAME);
	if (ret) {
		dev_err(dev, "Failed to reserve regions");
		goto fail_regions;
	}

	mqnic->hw_regs_size = pci_resource_len(pdev, 0);
	mqnic->hw_regs_phys = pci_resource_start(pdev, 0);
	mqnic->app_hw_regs_size = pci_resource_len(pdev, 2);
	mqnic->app_hw_regs_phys = pci_resource_start(pdev, 2);
	mqnic->ram_hw_regs_size = pci_resource_len(pdev, 4);
	mqnic->ram_hw_regs_phys = pci_resource_start(pdev, 4);

	// Map BARs
	dev_info(dev, "Control BAR size: %llu", mqnic->hw_regs_size);
	mqnic->hw_addr = pci_ioremap_bar(pdev, 0);
	if (!mqnic->hw_addr) {
		ret = -ENOMEM;
		dev_err(dev, "Failed to map control BAR");
		goto fail_map_bars;
	}

	if (mqnic->app_hw_regs_size) {
		dev_info(dev, "Application BAR size: %llu", mqnic->app_hw_regs_size);
		mqnic->app_hw_addr = pci_ioremap_bar(pdev, 2);
		if (!mqnic->app_hw_addr) {
			ret = -ENOMEM;
			dev_err(dev, "Failed to map application BAR");
			goto fail_map_bars;
		}
	}

	if (mqnic->ram_hw_regs_size) {
		dev_info(dev, "RAM BAR size: %llu", mqnic->ram_hw_regs_size);
		mqnic->ram_hw_addr = pci_ioremap_bar(pdev, 4);
		if (!mqnic->ram_hw_addr) {
			ret = -ENOMEM;
			dev_err(dev, "Failed to map RAM BAR");
			goto fail_map_bars;
		}
	}

	// Check if device needs to be reset
	if (ioread32(mqnic->hw_addr+4) == 0xffffffff) {
		ret = -EIO;
		dev_err(dev, "Device needs to be reset");
		goto fail_reset;
	}

	// Set up interrupts
	ret = mqnic_irq_init_pcie(mqnic);
	if (ret) {
		dev_err(dev, "Failed to set up interrupts");
		goto fail_init_irq;
	}

	// Enable bus mastering for DMA
	pci_set_master(pdev);

	// Common init
	ret = mqnic_common_probe(mqnic);
	if (ret)
		goto fail_common;

	// probe complete
	return 0;

	// error handling
fail_common:
	pci_clear_master(pdev);
	mqnic_irq_deinit_pcie(mqnic);
fail_reset:
fail_init_irq:
fail_map_bars:
	if (mqnic->hw_addr)
		pci_iounmap(pdev, mqnic->hw_addr);
	if (mqnic->app_hw_addr)
		pci_iounmap(pdev, mqnic->app_hw_addr);
	if (mqnic->ram_hw_addr)
		pci_iounmap(pdev, mqnic->ram_hw_addr);
	pci_release_regions(pdev);
fail_regions:
	pci_disable_device(pdev);
fail_enable_device:
	mqnic_free_id(mqnic);
	return ret;
}

static void mqnic_pci_remove(struct pci_dev *pdev)
{
	struct mqnic_dev *mqnic = pci_get_drvdata(pdev);

	dev_info(&pdev->dev, DRIVER_NAME " PCI remove");

	mqnic_common_remove(mqnic);

	pci_clear_master(pdev);
	mqnic_irq_deinit_pcie(mqnic);
	if (mqnic->hw_addr)
		pci_iounmap(pdev, mqnic->hw_addr);
	if (mqnic->app_hw_addr)
		pci_iounmap(pdev, mqnic->app_hw_addr);
	if (mqnic->ram_hw_addr)
		pci_iounmap(pdev, mqnic->ram_hw_addr);
	pci_release_regions(pdev);
	pci_disable_device(pdev);
	mqnic_free_id(mqnic);
}

static void mqnic_pci_shutdown(struct pci_dev *pdev)
{
	dev_info(&pdev->dev, DRIVER_NAME " PCI shutdown");

	mqnic_pci_remove(pdev);
}

static struct pci_driver mqnic_pci_driver = {
	.name = DRIVER_NAME,
	.id_table = mqnic_pci_id_table,
	.probe = mqnic_pci_probe,
	.remove = mqnic_pci_remove,
	.shutdown = mqnic_pci_shutdown
};
#endif /* CONFIG_PCI */

static int mqnic_platform_probe(struct platform_device *pdev)
{
	int ret;
	struct mqnic_dev *mqnic;
	struct device *dev = &pdev->dev;
	struct resource *res;

	dev_info(dev, DRIVER_NAME " platform probe");

#ifdef CONFIG_NUMA
	dev_info(dev, " NUMA node: %d", pdev->dev.numa_node);
#endif

	mqnic = devm_kzalloc(dev, sizeof(*mqnic), GFP_KERNEL);
	if (!mqnic)
		return -ENOMEM;

	mqnic->dev = dev;
	mqnic->pfdev = pdev;
	platform_set_drvdata(pdev, mqnic);

	// assign ID and add to list
	mqnic_assign_id(mqnic);

	// Set DMA properties
	ret = mqnic_common_setdma(mqnic);
	if (ret)
		goto fail;

	// Reserve and map regions
	res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	mqnic->hw_regs_size = resource_size(res);
	mqnic->hw_regs_phys = res->start;

	dev_info(dev, "Control BAR size: %llu", mqnic->hw_regs_size);
	mqnic->hw_addr = devm_ioremap_resource(&pdev->dev, res);
	if (IS_ERR(mqnic->hw_addr)) {
		ret = PTR_ERR(mqnic->hw_addr);
		dev_err(dev, "Failed to map control BAR");
		goto fail;
	}

	res = platform_get_resource(pdev, IORESOURCE_MEM, 1);
	if (res) {
		void __iomem *hw_addr;

		mqnic->app_hw_regs_size = resource_size(res);
		mqnic->app_hw_regs_phys = res->start;

		dev_info(dev, "Application BAR size: %llu", mqnic->app_hw_regs_size);
		hw_addr = devm_ioremap_resource(&pdev->dev, res);
		if (IS_ERR(hw_addr)) {
			ret = PTR_ERR(hw_addr);
			dev_err(dev, "Failed to map application BAR");
			goto fail;
		}
		mqnic->app_hw_addr = hw_addr;
	}

	res = platform_get_resource(pdev, IORESOURCE_MEM, 2);
	if (res) {
		void __iomem *hw_addr;

		mqnic->ram_hw_regs_size = resource_size(res);
		mqnic->ram_hw_regs_phys = res->start;

		dev_info(dev, "RAM BAR size: %llu", mqnic->ram_hw_regs_size);
		hw_addr = devm_ioremap_resource(&pdev->dev, res);
		if (IS_ERR(hw_addr)) {
			ret = PTR_ERR(hw_addr);
			dev_err(dev, "Failed to map RAM BAR");
			goto fail;
		}
		mqnic->ram_hw_addr = hw_addr;
	}

	// Set up interrupts
	ret = mqnic_irq_init_platform(mqnic);
	if (ret) {
		dev_err(dev, "Failed to set up interrupts");
		goto fail;
	}

	// Common init
	ret = mqnic_common_probe(mqnic);
	if (ret)
		goto fail;

	// probe complete
	return 0;

	// error handling
fail:
	mqnic_free_id(mqnic);
	return ret;
}

static int mqnic_platform_remove(struct platform_device *pdev)
{
	struct mqnic_dev *mqnic = platform_get_drvdata(pdev);

	dev_info(&pdev->dev, DRIVER_NAME " platform remove");

	mqnic_common_remove(mqnic);

	mqnic_free_id(mqnic);
	return 0;
}

static struct platform_driver mqnic_platform_driver = {
	.probe = mqnic_platform_probe,
	.remove = mqnic_platform_remove,
	.driver = {
		.name = DRIVER_NAME,
		.of_match_table = of_match_ptr(mqnic_of_id_table),
	},
};

static int __init mqnic_init(void)
{
	int rc;

#ifdef CONFIG_PCI
	rc = pci_register_driver(&mqnic_pci_driver);
	if (rc)
		return rc;
#endif

	rc = platform_driver_register(&mqnic_platform_driver);
	if (rc)
		goto err;

	return 0;

err:
#ifdef CONFIG_PCI
	pci_unregister_driver(&mqnic_pci_driver);
#endif
	return rc;
}

static void __exit mqnic_exit(void)
{
	platform_driver_unregister(&mqnic_platform_driver);

#ifdef CONFIG_PCI
	pci_unregister_driver(&mqnic_pci_driver);
#endif
}

module_init(mqnic_init);
module_exit(mqnic_exit);
