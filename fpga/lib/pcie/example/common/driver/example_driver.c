/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

#include "example_driver.h"
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/version.h>
#include <linux/delay.h>

#if LINUX_VERSION_CODE < KERNEL_VERSION(5,4,0)
#include <linux/pci-aspm.h>
#endif

MODULE_DESCRIPTION("verilog-pcie example driver");
MODULE_AUTHOR("Alex Forencich");
MODULE_LICENSE("Dual MIT/GPL");
MODULE_VERSION(DRIVER_VERSION);
MODULE_SUPPORTED_DEVICE(DRIVER_NAME);

static int edev_probe(struct pci_dev *pdev, const struct pci_device_id *ent);
static void edev_remove(struct pci_dev *pdev);
static void edev_shutdown(struct pci_dev *pdev);

static int enumerate_bars(struct example_dev *edev, struct pci_dev *pdev);
static int map_bars(struct example_dev *edev, struct pci_dev *pdev);
static void free_bars(struct example_dev *edev, struct pci_dev *pdev);

static const struct pci_device_id pci_ids[] = {
    { PCI_DEVICE(0x1234, 0x0001) },
    { 0 /* end */ }
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

    dev_info(dev, "edev probe");
    dev_info(dev, " vendor: 0x%04x", pdev->vendor);
    dev_info(dev, " device: 0x%04x", pdev->device);
    dev_info(dev, " class: 0x%06x", pdev->class);
    dev_info(dev, " pci id: %02x:%02x.%02x", pdev->bus->number, PCI_SLOT(pdev->devfn), PCI_FUNC(pdev->devfn));

    if (!(edev = devm_kzalloc(dev, sizeof(struct example_dev), GFP_KERNEL))) {
        return -ENOMEM;
    }

    edev->pdev = pdev;
    pci_set_drvdata(pdev, edev);

    // Allocate DMA buffer
    edev->dma_region_len = 16*1024;
    edev->dma_region = dma_alloc_coherent(dev, edev->dma_region_len, &edev->dma_region_addr, GFP_KERNEL | __GFP_ZERO);
    if (!edev->dma_region)
    {
        dev_err(dev, "Failed to allocate DMA buffer");
        ret = -ENOMEM;
        goto fail_dma_alloc;
    }

    dev_info(dev, "Allocated DMA region virt %p, phys %p", edev->dma_region, (void *)edev->dma_region_addr);

    // Disable ASPM
    pci_disable_link_state(pdev, PCIE_LINK_STATE_L0S | PCIE_LINK_STATE_L1 | PCIE_LINK_STATE_CLKPM);

    // Enable device
    ret = pci_enable_device_mem(pdev);
    if (ret)
    {
        dev_err(dev, "Failed to enable PCI device");
        //ret = -ENODEV;
        goto fail_enable_device;
    }

    // Enable bus mastering for DMA
    pci_set_master(pdev);

    // Reserve regions
    ret = pci_request_regions(pdev, DRIVER_NAME);
    if (ret)
    {
        dev_err(dev, "Failed to reserve regions");
        //ret = -EBUSY;
        goto fail_regions;
    }

    // Enumerate BARs
    enumerate_bars(edev, pdev);

    // Map BARs
    ret = map_bars(edev, pdev);
    if (ret)
    {
        dev_err(dev, "Failed to map BARs");
        goto fail_map_bars;
    }

    // Allocate MSI IRQs
    ret = pci_alloc_irq_vectors(pdev, 1, 32, PCI_IRQ_MSI);
    if (ret < 0)
    {
        dev_err(dev, "Failed to allocate IRQs");
        goto fail_map_bars;
    }

    // Set up interrupt
    ret = pci_request_irq(pdev, 0, edev_intr, 0, edev, "edev");
    if (ret < 0)
    {
        dev_err(dev, "Failed to request IRQ");
        goto fail_irq;
    }

    // Dump counters
    dev_info(dev, "TLP counters");
    dev_info(dev, "RQ: %d", ioread32(edev->bar[0]+0x000400));
    dev_info(dev, "RC: %d", ioread32(edev->bar[0]+0x000404));
    dev_info(dev, "CQ: %d", ioread32(edev->bar[0]+0x000408));
    dev_info(dev, "CC: %d", ioread32(edev->bar[0]+0x00040C));

    // Read/write test
    dev_info(dev, "write to BAR1");
    iowrite32(0x11223344, edev->bar[1]);

    dev_info(dev, "read from BAR1");
    dev_info(dev, "%08x", ioread32(edev->bar[1]));

    // Dump counters
    dev_info(dev, "TLP counters");
    dev_info(dev, "RQ: %d", ioread32(edev->bar[0]+0x000400));
    dev_info(dev, "RC: %d", ioread32(edev->bar[0]+0x000404));
    dev_info(dev, "CQ: %d", ioread32(edev->bar[0]+0x000408));
    dev_info(dev, "CC: %d", ioread32(edev->bar[0]+0x00040C));

    // PCIe DMA test
    dev_info(dev, "write test data");
    for (k = 0; k < 256; k++)
    {
        ((char *)edev->dma_region)[k] = k;
    }

    dev_info(dev, "read test data");
    print_hex_dump(KERN_INFO, "", DUMP_PREFIX_NONE, 16, 1, edev->dma_region, 256, true);

    dev_info(dev, "check DMA enable");
    dev_info(dev, "%08x", ioread32(edev->bar[0]+0x000000));

    dev_info(dev, "enable DMA");
    iowrite32(0x1, edev->bar[0]+0x000000);

    dev_info(dev, "check DMA enable");
    dev_info(dev, "%08x", ioread32(edev->bar[0]+0x000000));

    dev_info(dev, "start copy to card");
    iowrite32((edev->dma_region_addr+0x0000)&0xffffffff, edev->bar[0]+0x000100);
    iowrite32(((edev->dma_region_addr+0x0000) >> 32)&0xffffffff, edev->bar[0]+0x000104);
    iowrite32(0x100, edev->bar[0]+0x000108);
    iowrite32(0, edev->bar[0]+0x00010C);
    iowrite32(0x100, edev->bar[0]+0x000110);
    iowrite32(0xAA, edev->bar[0]+0x000114);

    msleep(1);

    dev_info(dev, "Read status");
    dev_info(dev, "%08x", ioread32(edev->bar[0]+0x000118));

    dev_info(dev, "start copy to host");
    iowrite32((edev->dma_region_addr+0x0200)&0xffffffff, edev->bar[0]+0x000200);
    iowrite32(((edev->dma_region_addr+0x0200) >> 32)&0xffffffff, edev->bar[0]+0x000204);
    iowrite32(0x100, edev->bar[0]+0x000208);
    iowrite32(0, edev->bar[0]+0x00020C);
    iowrite32(0x100, edev->bar[0]+0x000210);
    iowrite32(0x55, edev->bar[0]+0x000214);

    msleep(1);

    dev_info(dev, "Read status");
    dev_info(dev, "%08x", ioread32(edev->bar[0]+0x000218));

    dev_info(dev, "read test data");
    print_hex_dump(KERN_INFO, "", DUMP_PREFIX_NONE, 16, 1, edev->dma_region+0x0200, 256, true);

    // Dump counters
    dev_info(dev, "TLP counters");
    dev_info(dev, "RQ: %d", ioread32(edev->bar[0]+0x000400));
    dev_info(dev, "RC: %d", ioread32(edev->bar[0]+0x000404));
    dev_info(dev, "CQ: %d", ioread32(edev->bar[0]+0x000408));
    dev_info(dev, "CC: %d", ioread32(edev->bar[0]+0x00040C));

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
    struct example_dev *edev;
    struct device *dev = &pdev->dev;

    dev_info(dev, "edev remove");

    if (!(edev = pci_get_drvdata(pdev))) {
        return;
    }

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
    struct example_dev *edev = pci_get_drvdata(pdev);
    struct device *dev = &pdev->dev;

    dev_info(dev, "edev shutdown");

    if (!edev) {
        return;
    }

    // ensure DMA is disabled on shutdown
    pci_clear_master(pdev);
}

static int enumerate_bars(struct example_dev *edev, struct pci_dev *pdev)
{
    struct device *dev = &pdev->dev;
    int i;

    for (i = 0; i < DEV_BAR_CNT; i++)
    {
        resource_size_t bar_start = pci_resource_start(pdev, i);
        if (bar_start)
        {
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

    for (i = 0; i < DEV_BAR_CNT; i++)
    {
        resource_size_t bar_start = pci_resource_start(pdev, i);
        resource_size_t bar_end = pci_resource_end(pdev, i);
        resource_size_t bar_len = bar_end - bar_start + 1;
        edev->bar_len[i] = bar_len;

        if (!bar_start || !bar_end)
        {
            edev->bar_len[i] = 0;
            continue;
        }

        if (bar_len < 1)
        {
            dev_warn(dev, "BAR[%d] is less than 1 byte", i);
            continue;
        }

        edev->bar[i] = pci_ioremap_bar(pdev, i);

        if (!edev->bar[i])
        {
            dev_err(dev, "Could not map BAR[%d]", i);
            return -1;
        }

        dev_info(dev, "BAR[%d] mapped at 0x%p with length %llu", i, edev->bar[i], bar_len);
    }

    return 0;
}

static void free_bars(struct example_dev *edev, struct pci_dev *pdev)
{
    struct device *dev = &pdev->dev;
    int i;

    for (i = 0; i < DEV_BAR_CNT; i++)
    {
        if (edev->bar[i])
        {
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

