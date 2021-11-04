// SPDX-License-Identifier: MIT
/*
 * Copyright (c) 2018-2021 Alex Forencich
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "example_driver.h"
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/version.h>
#include <linux/delay.h>

#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 4, 0)
#include <linux/pci-aspm.h>
#endif

MODULE_DESCRIPTION("verilog-pcie example driver");
MODULE_AUTHOR("Alex Forencich");
MODULE_LICENSE("Dual MIT/GPL");
MODULE_VERSION(DRIVER_VERSION);

static int edev_probe(struct pci_dev *pdev, const struct pci_device_id *ent);
static void edev_remove(struct pci_dev *pdev);
static void edev_shutdown(struct pci_dev *pdev);

static int enumerate_bars(struct example_dev *edev, struct pci_dev *pdev);
static int map_bars(struct example_dev *edev, struct pci_dev *pdev);
static void free_bars(struct example_dev *edev, struct pci_dev *pdev);

static const struct pci_device_id pci_ids[] = {
	{PCI_DEVICE(0x1234, 0x0001)},
	{0 /* end */ }
};

MODULE_DEVICE_TABLE(pci, pci_ids);

static irqreturn_t edev_intr(int irq, void *data)
{
	struct example_dev *edev = data;
	struct device *dev = &edev->pdev->dev;

	edev->irqcount++;

	dev_info(dev, "Interrupt");

	return IRQ_HANDLED;
}

static int edev_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
	int ret = 0;
	struct example_dev *edev;
	struct device *dev = &pdev->dev;

	int k;

	dev_info(dev, DRIVER_NAME " probe");
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

	edev = devm_kzalloc(dev, sizeof(struct example_dev), GFP_KERNEL);
	if (!edev)
		return -ENOMEM;

	edev->pdev = pdev;
	pci_set_drvdata(pdev, edev);

	// Allocate DMA buffer
	edev->dma_region_len = 16 * 1024;
	edev->dma_region = dma_alloc_coherent(dev, edev->dma_region_len,
			&edev->dma_region_addr, GFP_KERNEL | __GFP_ZERO);
	if (!edev->dma_region) {
		ret = -ENOMEM;
		goto fail_dma_alloc;
	}

	dev_info(dev, "Allocated DMA region virt %p, phys %p",
			edev->dma_region, (void *)edev->dma_region_addr);

	// Disable ASPM
	pci_disable_link_state(pdev, PCIE_LINK_STATE_L0S |
			PCIE_LINK_STATE_L1 | PCIE_LINK_STATE_CLKPM);

	// Enable device
	ret = pci_enable_device_mem(pdev);
	if (ret) {
		dev_err(dev, "Failed to enable PCI device");
		goto fail_enable_device;
	}

	// Enable bus mastering for DMA
	pci_set_master(pdev);

	// Reserve regions
	ret = pci_request_regions(pdev, DRIVER_NAME);
	if (ret) {
		dev_err(dev, "Failed to reserve regions");
		goto fail_regions;
	}

	// Enumerate BARs
	enumerate_bars(edev, pdev);

	// Map BARs
	ret = map_bars(edev, pdev);
	if (ret) {
		dev_err(dev, "Failed to map BARs");
		goto fail_map_bars;
	}

	// Allocate MSI IRQs
	ret = pci_alloc_irq_vectors(pdev, 1, 32, PCI_IRQ_MSI);
	if (ret < 0) {
		dev_err(dev, "Failed to allocate IRQs");
		goto fail_map_bars;
	}

	// Set up interrupt
	ret = pci_request_irq(pdev, 0, edev_intr, 0, edev, DRIVER_NAME);
	if (ret < 0) {
		dev_err(dev, "Failed to request IRQ");
		goto fail_irq;
	}

	// Read/write test
	dev_info(dev, "write to BAR2");
	iowrite32(0x11223344, edev->bar[2]);

	dev_info(dev, "read from BAR2");
	dev_info(dev, "%08x", ioread32(edev->bar[2]));

	// PCIe DMA test
	dev_info(dev, "write test data");
	for (k = 0; k < 256; k++)
		((char *)edev->dma_region)[k] = k;

	dev_info(dev, "read test data");
	print_hex_dump(KERN_INFO, "", DUMP_PREFIX_NONE, 16, 1,
			edev->dma_region, 256, true);

	dev_info(dev, "check DMA enable");
	dev_info(dev, "%08x", ioread32(edev->bar[0] + 0x000000));

	dev_info(dev, "enable DMA");
	iowrite32(0x1, edev->bar[0] + 0x000000);

	dev_info(dev, "check DMA enable");
	dev_info(dev, "%08x", ioread32(edev->bar[0] + 0x000000));

	dev_info(dev, "enable interrupts");
	iowrite32(0x3, edev->bar[0] + 0x000008);

	dev_info(dev, "start copy to card");
	iowrite32((edev->dma_region_addr + 0x0000) & 0xffffffff, edev->bar[0] + 0x000100);
	iowrite32(((edev->dma_region_addr + 0x0000) >> 32) & 0xffffffff, edev->bar[0] + 0x000104);
	iowrite32(0x100, edev->bar[0] + 0x000108);
	iowrite32(0, edev->bar[0] + 0x00010C);
	iowrite32(0x100, edev->bar[0] + 0x000110);
	iowrite32(0xAA, edev->bar[0] + 0x000114);

	msleep(1);

	dev_info(dev, "Read status");
	dev_info(dev, "%08x", ioread32(edev->bar[0] + 0x000118));

	dev_info(dev, "start copy to host");
	iowrite32((edev->dma_region_addr + 0x0200) & 0xffffffff, edev->bar[0] + 0x000200);
	iowrite32(((edev->dma_region_addr + 0x0200) >> 32) & 0xffffffff, edev->bar[0] + 0x000204);
	iowrite32(0x100, edev->bar[0] + 0x000208);
	iowrite32(0, edev->bar[0] + 0x00020C);
	iowrite32(0x100, edev->bar[0] + 0x000210);
	iowrite32(0x55, edev->bar[0] + 0x000214);

	msleep(1);

	dev_info(dev, "Read status");
	dev_info(dev, "%08x", ioread32(edev->bar[0] + 0x000218));

	dev_info(dev, "read test data");
	print_hex_dump(KERN_INFO, "", DUMP_PREFIX_NONE, 16, 1,
			edev->dma_region + 0x0200, 256, true);

	// probe complete
	return 0;

	// error handling
fail_irq:
	pci_free_irq_vectors(pdev);
fail_map_bars:
	free_bars(edev, pdev);
	pci_release_regions(pdev);
fail_regions:
	pci_clear_master(pdev);
	pci_disable_device(pdev);
fail_enable_device:
	dma_free_coherent(dev, edev->dma_region_len, edev->dma_region, edev->dma_region_addr);
fail_dma_alloc:
	return ret;
}

static void edev_remove(struct pci_dev *pdev)
{
	struct example_dev *edev = pci_get_drvdata(pdev);
	struct device *dev = &pdev->dev;

	dev_info(dev, DRIVER_NAME " remove");

	pci_free_irq(pdev, 0, edev);
	pci_free_irq_vectors(pdev);
	free_bars(edev, pdev);
	pci_release_regions(pdev);
	pci_clear_master(pdev);
	pci_disable_device(pdev);
	dma_free_coherent(dev, edev->dma_region_len, edev->dma_region, edev->dma_region_addr);
}

static void edev_shutdown(struct pci_dev *pdev)
{
	dev_info(&pdev->dev, DRIVER_NAME " shutdown");

	edev_remove(pdev);
}

static int enumerate_bars(struct example_dev *edev, struct pci_dev *pdev)
{
	struct device *dev = &pdev->dev;
	int i;

	for (i = 0; i < 6; i++) {
		resource_size_t bar_start = pci_resource_start(pdev, i);

		if (bar_start) {
			resource_size_t bar_end = pci_resource_end(pdev, i);
			unsigned long bar_flags = pci_resource_flags(pdev, i);

			dev_info(dev, "BAR[%d] 0x%08llx-0x%08llx flags 0x%08lx",
					i, bar_start, bar_end, bar_flags);
		}
	}

	return 0;
}

static int map_bars(struct example_dev *edev, struct pci_dev *pdev)
{
	struct device *dev = &pdev->dev;
	int i;

	for (i = 0; i < 6; i++) {
		resource_size_t bar_start = pci_resource_start(pdev, i);
		resource_size_t bar_end = pci_resource_end(pdev, i);
		resource_size_t bar_len = bar_end - bar_start + 1;

		edev->bar_len[i] = bar_len;

		if (!bar_start || !bar_end) {
			edev->bar_len[i] = 0;
			continue;
		}

		if (bar_len < 1) {
			dev_warn(dev, "BAR[%d] is less than 1 byte", i);
			continue;
		}

		edev->bar[i] = pci_ioremap_bar(pdev, i);

		if (!edev->bar[i]) {
			dev_err(dev, "Could not map BAR[%d]", i);
			return -1;
		}

		dev_info(dev, "BAR[%d] mapped at 0x%p with length %llu",
			i, edev->bar[i], bar_len);
	}

	return 0;
}

static void free_bars(struct example_dev *edev, struct pci_dev *pdev)
{
	struct device *dev = &pdev->dev;
	int i;

	for (i = 0; i < 6; i++) {
		if (edev->bar[i]) {
			pci_iounmap(pdev, edev->bar[i]);
			edev->bar[i] = NULL;
			dev_info(dev, "Unmapped BAR[%d]", i);
		}
	}
}

static struct pci_driver pci_driver = {
	.name = DRIVER_NAME,
	.id_table = pci_ids,
	.probe = edev_probe,
	.remove = edev_remove,
	.shutdown = edev_shutdown
};

static int __init edev_init(void)
{
	return pci_register_driver(&pci_driver);
}

static void __exit edev_exit(void)
{
	pci_unregister_driver(&pci_driver);
}

module_init(edev_init);
module_exit(edev_exit);
