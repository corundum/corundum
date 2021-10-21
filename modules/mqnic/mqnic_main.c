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

module_param_named(num_ev_queue_entries, mqnic_num_ev_queue_entries,
		   uint, 0444);
MODULE_PARM_DESC(num_ev_queue_entries, "number of entries to allocate per event queue (default: 1024)");
module_param_named(num_tx_queue_entries, mqnic_num_tx_queue_entries,
		   uint, 0444);
MODULE_PARM_DESC(num_tx_queue_entries, "number of entries to allocate per transmit queue (default: 1024)");
module_param_named(num_rx_queue_entries, mqnic_num_rx_queue_entries,
		   uint, 0444);
MODULE_PARM_DESC(num_rx_queue_entries, "number of entries to allocate per receive queue (default: 1024)");

static const struct pci_device_id mqnic_pci_id_table[] = {
	{PCI_DEVICE(0x1234, 0x1001)},
	{PCI_DEVICE(0x5543, 0x1001)},
	{0 /* end */ }
};

MODULE_DEVICE_TABLE(pci, mqnic_pci_id_table);

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

static int mqnic_pci_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
	int ret = 0;
	struct mqnic_dev *mqnic;
	struct device *dev = &pdev->dev;

	int k = 0;

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
	spin_lock(&mqnic_devices_lock);
	mqnic->id = mqnic_get_free_id();
	list_add_tail(&mqnic->dev_list_node, &mqnic_devices);
	spin_unlock(&mqnic_devices_lock);

	snprintf(mqnic->name, sizeof(mqnic->name), DRIVER_NAME "%d", mqnic->id);

	// Disable ASPM
	pci_disable_link_state(pdev, PCIE_LINK_STATE_L0S |
			PCIE_LINK_STATE_L1 | PCIE_LINK_STATE_CLKPM);

	// Enable device
	ret = pci_enable_device_mem(pdev);
	if (ret) {
		dev_err(dev, "Failed to enable PCI device");
		goto fail_enable_device;
	}

	// Set mask
	ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(64));
	if (ret) {
		dev_warn(dev, "Warning: failed to set 64 bit PCI DMA mask");
		ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(32));
		if (ret) {
			dev_err(dev, "Failed to set PCI DMA mask");
			goto fail_regions;
		}
	}

	// Set max segment size
	dma_set_max_seg_size(dev, DMA_BIT_MASK(32));

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
	if (ioread32(mqnic->hw_addr) == 0xffffffff) {
		ret = -EIO;
		dev_err(dev, "Device needs to be reset");
		goto fail_map_bars;
	}

	// Read ID registers
	mqnic->fw_id = ioread32(mqnic->hw_addr + MQNIC_REG_FW_ID);
	dev_info(dev, "FW ID: 0x%08x", mqnic->fw_id);
	mqnic->fw_ver = ioread32(mqnic->hw_addr + MQNIC_REG_FW_VER);
	dev_info(dev, "FW version: %d.%d", mqnic->fw_ver >> 16, mqnic->fw_ver & 0xffff);
	mqnic->board_id = ioread32(mqnic->hw_addr + MQNIC_REG_BOARD_ID);
	dev_info(dev, "Board ID: 0x%08x", mqnic->board_id);
	mqnic->board_ver = ioread32(mqnic->hw_addr + MQNIC_REG_BOARD_VER);
	dev_info(dev, "Board version: %d.%d", mqnic->board_ver >> 16, mqnic->board_ver & 0xffff);

	mqnic->phc_count = ioread32(mqnic->hw_addr + MQNIC_REG_PHC_COUNT);
	dev_info(dev, "PHC count: %d", mqnic->phc_count);
	mqnic->phc_offset = ioread32(mqnic->hw_addr + MQNIC_REG_PHC_OFFSET);
	dev_info(dev, "PHC offset: 0x%08x", mqnic->phc_offset);

	if (mqnic->phc_count)
		mqnic->phc_hw_addr = mqnic->hw_addr + mqnic->phc_offset;

	mqnic->if_count = ioread32(mqnic->hw_addr + MQNIC_REG_IF_COUNT);
	dev_info(dev, "IF count: %d", mqnic->if_count);
	mqnic->if_stride = ioread32(mqnic->hw_addr + MQNIC_REG_IF_STRIDE);
	dev_info(dev, "IF stride: 0x%08x", mqnic->if_stride);
	mqnic->if_csr_offset = ioread32(mqnic->hw_addr + MQNIC_REG_IF_CSR_OFFSET);
	dev_info(dev, "IF CSR offset: 0x%08x", mqnic->if_csr_offset);

	// check BAR size
	if (mqnic->if_count * mqnic->if_stride > mqnic->hw_regs_size) {
		ret = -EIO;
		dev_err(dev, "Invalid BAR configuration (%d IF * 0x%x > 0x%llx)",
				mqnic->if_count, mqnic->if_stride, mqnic->hw_regs_size);
		goto fail_map_bars;
	}

	// Set up interrupts
	ret = mqnic_irq_init_pcie(mqnic);
	if (ret) {
		dev_err(dev, "Failed to set up interrupts");
		goto fail_map_bars;
	}

	// Board-specific init
	ret = mqnic_board_init(mqnic);
	if (ret) {
		dev_err(dev, "Failed to initialize board");
		goto fail_board;
	}

	// Enable bus mastering for DMA
	pci_set_master(pdev);

	// register PHC
	if (mqnic->phc_count)
		mqnic_register_phc(mqnic);

	mutex_init(&mqnic->state_lock);

	// Set up interfaces
	mqnic->if_count = min_t(u32, mqnic->if_count, MQNIC_MAX_IF);

	for (k = 0; k < mqnic->if_count; k++) {
		dev_info(dev, "Creating interface %d", k);
		ret = mqnic_create_interface(mqnic, &mqnic->interface[k], k, mqnic->hw_addr + k * mqnic->if_stride);
		if (ret) {
			dev_err(dev, "Failed to create interface: %d", ret);
			goto fail_create_if;
		}
	}

	// pass module I2C clients to interface instances
	for (k = 0; k < mqnic->if_count; k++) {
		mqnic->interface[k]->mod_i2c_client = mqnic->mod_i2c_client[k];
	}

	mqnic->misc_dev.minor = MISC_DYNAMIC_MINOR;
	mqnic->misc_dev.name = mqnic->name;
	mqnic->misc_dev.fops = &mqnic_fops;
	mqnic->misc_dev.parent = dev;

	ret = misc_register(&mqnic->misc_dev);
	if (ret) {
		dev_err(dev, "misc_register failed: %d\n", ret);
		goto fail_miscdev;
	}

	dev_info(dev, "Registered device %s", mqnic->name);

	pci_save_state(pdev);

	// probe complete
	return 0;

	// error handling
fail_miscdev:
fail_create_if:
	for (k = 0; k < ARRAY_SIZE(mqnic->interface); k++)
		if (mqnic->interface[k])
			mqnic_destroy_interface(&mqnic->interface[k]);
	mqnic_unregister_phc(mqnic);
	pci_clear_master(pdev);
fail_board:
	mqnic_irq_deinit_pcie(mqnic);
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
	spin_lock(&mqnic_devices_lock);
	list_del(&mqnic->dev_list_node);
	spin_unlock(&mqnic_devices_lock);
	return ret;
}

static void mqnic_pci_remove(struct pci_dev *pdev)
{
	struct mqnic_dev *mqnic = pci_get_drvdata(pdev);

	int k = 0;

	dev_info(&pdev->dev, DRIVER_NAME " PCI remove");

	misc_deregister(&mqnic->misc_dev);

	spin_lock(&mqnic_devices_lock);
	list_del(&mqnic->dev_list_node);
	spin_unlock(&mqnic_devices_lock);

	for (k = 0; k < ARRAY_SIZE(mqnic->interface); k++)
		if (mqnic->interface[k])
			mqnic_destroy_interface(&mqnic->interface[k]);

	mqnic_unregister_phc(mqnic);

	pci_clear_master(pdev);
	mqnic_board_deinit(mqnic);
	mqnic_irq_deinit_pcie(mqnic);
	if (mqnic->hw_addr)
		pci_iounmap(pdev, mqnic->hw_addr);
	if (mqnic->app_hw_addr)
		pci_iounmap(pdev, mqnic->app_hw_addr);
	if (mqnic->ram_hw_addr)
		pci_iounmap(pdev, mqnic->ram_hw_addr);
	pci_release_regions(pdev);
	pci_disable_device(pdev);
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

static int __init mqnic_init(void)
{
	return pci_register_driver(&mqnic_pci_driver);
}

static void __exit mqnic_exit(void)
{
	pci_unregister_driver(&mqnic_pci_driver);
}

module_init(mqnic_init);
module_exit(mqnic_exit);
