// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2022, The Regents of the University of California.
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

MODULE_DESCRIPTION("mqnic DMA benchmark application driver");
MODULE_AUTHOR("Alex Forencich");
MODULE_LICENSE("Dual BSD/GPL");
MODULE_VERSION("0.1");

struct mqnic_app_dma_bench {
	struct device *dev;
	struct mqnic_dev *mdev;
	struct mqnic_adev *adev;

	struct device *nic_dev;

	void __iomem *nic_hw_addr;
	void __iomem *app_hw_addr;
	void __iomem *ram_hw_addr;

	// DMA buffer
	size_t dma_region_len;
	void *dma_region;
	dma_addr_t dma_region_addr;
};

const char *dma_bench_stats_names[] = {
	// PCIe stats
	"pcie_rx_tlp_mem_rd",      // index 0
	"pcie_rx_tlp_mem_wr",      // index 1
	"pcie_rx_tlp_io",          // index 2
	"pcie_rx_tlp_cfg",         // index 3
	"pcie_rx_tlp_msg",         // index 4
	"pcie_rx_tlp_cpl",         // index 5
	"pcie_rx_tlp_cpl_ur",      // index 6
	"pcie_rx_tlp_cpl_ca",      // index 7
	"pcie_rx_tlp_atomic",      // index 8
	"pcie_rx_tlp_ep",          // index 9
	"pcie_rx_tlp_hdr_dw",      // index 10
	"pcie_rx_tlp_req_dw",      // index 11
	"pcie_rx_tlp_payload_dw",  // index 12
	"pcie_rx_tlp_cpl_dw",      // index 13
	"",                        // index 14
	"",                        // index 15
	"pcie_tx_tlp_mem_rd",      // index 16
	"pcie_tx_tlp_mem_wr",      // index 17
	"pcie_tx_tlp_io",          // index 18
	"pcie_tx_tlp_cfg",         // index 19
	"pcie_tx_tlp_msg",         // index 20
	"pcie_tx_tlp_cpl",         // index 21
	"pcie_tx_tlp_cpl_ur",      // index 22
	"pcie_tx_tlp_cpl_ca",      // index 23
	"pcie_tx_tlp_atomic",      // index 24
	"pcie_tx_tlp_ep",          // index 25
	"pcie_tx_tlp_hdr_dw",      // index 26
	"pcie_tx_tlp_req_dw",      // index 27
	"pcie_tx_tlp_payload_dw",  // index 28
	"pcie_tx_tlp_cpl_dw",      // index 29
	"",                        // index 30
	"",                        // index 31

	// DMA statistics
	"dma_rd_op_count",         // index 0
	"dma_rd_op_bytes",         // index 1
	"dma_rd_op_latency",       // index 2
	"dma_rd_op_error",         // index 3
	"dma_rd_req_count",        // index 4
	"dma_rd_req_latency",      // index 5
	"dma_rd_req_timeout",      // index 6
	"dma_rd_op_table_full",    // index 7
	"dma_rd_no_tags",          // index 8
	"dma_rd_tx_no_credit",     // index 9
	"dma_rd_tx_limit",         // index 10
	"dma_rd_tx_stall",         // index 11
	"",                        // index 12
	"",                        // index 13
	"",                        // index 14
	"",                        // index 15
	"dma_wr_op_count",         // index 16
	"dma_wr_op_bytes",         // index 17
	"dma_wr_op_latency",       // index 18
	"dma_wr_op_error",         // index 19
	"dma_wr_req_count",        // index 20
	"dma_wr_req_latency",      // index 21
	"",                        // index 22
	"dma_wr_op_table_full",    // index 23
	"",                        // index 24
	"dma_wr_tx_no_credit",     // index 25
	"dma_wr_tx_limit",         // index 26
	"dma_wr_tx_stall",         // index 27
	"",                        // index 28
	"",                        // index 29
	"",                        // index 30
	"",                        // index 31
	0
};

static u64 read_stat_counter(struct mqnic_app_dma_bench *app, int index)
{
	u64 val;

	val = (u64) ioread32(app->nic_hw_addr + 0x010000 + index * 8 + 0);
	val |= (u64) ioread32(app->nic_hw_addr + 0x010000 + index * 8 + 4) << 32;
	return val;
}

static void print_counters(struct mqnic_app_dma_bench *app)
{
	struct device *dev = app->dev;

	int index = 0;
	u64 val;

	while (dma_bench_stats_names[index]) {
		if (strlen(dma_bench_stats_names[index]) > 0) {
			val = read_stat_counter(app, index);
			dev_info(dev, "%s: %lld", dma_bench_stats_names[index], val);
		}
		index++;
	}
}

static void dma_read(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, size_t ram_addr, size_t len)
{
	int tag = 0;
	int new_tag = 0;
	unsigned long t;

	tag = ioread32(app->app_hw_addr + 0x000118); // dummy read
	tag = (ioread32(app->app_hw_addr + 0x000118) & 0x7f) + 1;
	iowrite32(dma_addr & 0xffffffff, app->app_hw_addr + 0x000100);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->app_hw_addr + 0x000104);
	iowrite32(ram_addr, app->app_hw_addr + 0x000108);
	iowrite32(0, app->app_hw_addr + 0x00010C);
	iowrite32(len, app->app_hw_addr + 0x000110);
	iowrite32(tag, app->app_hw_addr + 0x000114);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(200);
	while (time_before(jiffies, t)) {
		new_tag = (ioread32(app->app_hw_addr + 0x000118) & 0xff);
		if (new_tag == tag)
			break;
	}

	if (tag != new_tag)
		dev_warn(app->dev, "%s: tag %d (expected %d)", __func__, new_tag, tag);
}

static void dma_write(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, size_t ram_addr, size_t len)
{
	int tag = 0;
	int new_tag = 0;
	unsigned long t;

	tag = ioread32(app->app_hw_addr + 0x000218); // dummy read
	tag = (ioread32(app->app_hw_addr + 0x000218) & 0x7f) + 1;
	iowrite32(dma_addr & 0xffffffff, app->app_hw_addr + 0x000200);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->app_hw_addr + 0x000204);
	iowrite32(ram_addr, app->app_hw_addr + 0x000208);
	iowrite32(0, app->app_hw_addr + 0x00020C);
	iowrite32(len, app->app_hw_addr + 0x000210);
	iowrite32(tag, app->app_hw_addr + 0x000214);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(200);
	while (time_before(jiffies, t)) {
		new_tag = (ioread32(app->app_hw_addr + 0x000218) & 0xff);
		if (new_tag == tag)
			break;
	}

	if (tag != new_tag)
		dev_warn(app->dev, "%s: tag %d (expected %d)", __func__, new_tag, tag);
}

static void dma_block_read(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, size_t dma_offset,
		size_t dma_offset_mask, size_t dma_stride,
		size_t ram_addr, size_t ram_offset,
		size_t ram_offset_mask, size_t ram_stride,
		size_t block_len, size_t block_count)
{
	unsigned long t;

	// DMA base address
	iowrite32(dma_addr & 0xffffffff, app->app_hw_addr + 0x001080);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->app_hw_addr + 0x001084);
	// DMA offset address
	iowrite32(dma_offset & 0xffffffff, app->app_hw_addr + 0x001088);
	iowrite32((dma_offset >> 32) & 0xffffffff, app->app_hw_addr + 0x00108c);
	// DMA offset mask
	iowrite32(dma_offset_mask & 0xffffffff, app->app_hw_addr + 0x001090);
	iowrite32((dma_offset_mask >> 32) & 0xffffffff, app->app_hw_addr + 0x001094);
	// DMA stride
	iowrite32(dma_stride & 0xffffffff, app->app_hw_addr + 0x001098);
	iowrite32((dma_stride >> 32) & 0xffffffff, app->app_hw_addr + 0x00109c);
	// RAM base address
	iowrite32(ram_addr & 0xffffffff, app->app_hw_addr + 0x0010c0);
	iowrite32((ram_addr >> 32) & 0xffffffff, app->app_hw_addr + 0x0010c4);
	// RAM offset address
	iowrite32(ram_offset & 0xffffffff, app->app_hw_addr + 0x0010c8);
	iowrite32((ram_offset >> 32) & 0xffffffff, app->app_hw_addr + 0x0010cc);
	// RAM offset mask
	iowrite32(ram_offset_mask & 0xffffffff, app->app_hw_addr + 0x0010d0);
	iowrite32((ram_offset_mask >> 32) & 0xffffffff, app->app_hw_addr + 0x0010d4);
	// RAM stride
	iowrite32(ram_stride & 0xffffffff, app->app_hw_addr + 0x0010d8);
	iowrite32((ram_stride >> 32) & 0xffffffff, app->app_hw_addr + 0x0010dc);
	// clear cycle count
	iowrite32(0, app->app_hw_addr + 0x001008);
	iowrite32(0, app->app_hw_addr + 0x00100c);
	// block length
	iowrite32(block_len, app->app_hw_addr + 0x001010);
	// block count
	iowrite32(block_count, app->app_hw_addr + 0x001018);
	// start
	iowrite32(1, app->app_hw_addr + 0x001000);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(20000);
	while (time_before(jiffies, t)) {
		if ((ioread32(app->app_hw_addr + 0x001000) & 1) == 0)
			break;
	}

	if ((ioread32(app->app_hw_addr + 0x001000) & 1) != 0)
		dev_warn(app->dev, "%s: operation timed out", __func__);
}

static void dma_block_write(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, size_t dma_offset,
		size_t dma_offset_mask, size_t dma_stride,
		size_t ram_addr, size_t ram_offset,
		size_t ram_offset_mask, size_t ram_stride,
		size_t block_len, size_t block_count)
{
	unsigned long t;

	// DMA base address
	iowrite32(dma_addr & 0xffffffff, app->app_hw_addr + 0x001180);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->app_hw_addr + 0x001184);
	// DMA offset address
	iowrite32(dma_offset & 0xffffffff, app->app_hw_addr + 0x001188);
	iowrite32((dma_offset >> 32) & 0xffffffff, app->app_hw_addr + 0x00118c);
	// DMA offset mask
	iowrite32(dma_offset_mask & 0xffffffff, app->app_hw_addr + 0x001190);
	iowrite32((dma_offset_mask >> 32) & 0xffffffff, app->app_hw_addr + 0x001194);
	// DMA stride
	iowrite32(dma_stride & 0xffffffff, app->app_hw_addr + 0x001198);
	iowrite32((dma_stride >> 32) & 0xffffffff, app->app_hw_addr + 0x00119c);
	// RAM base address
	iowrite32(ram_addr & 0xffffffff, app->app_hw_addr + 0x0011c0);
	iowrite32((ram_addr >> 32) & 0xffffffff, app->app_hw_addr + 0x0011c4);
	// RAM offset address
	iowrite32(ram_offset & 0xffffffff, app->app_hw_addr + 0x0011c8);
	iowrite32((ram_offset >> 32) & 0xffffffff, app->app_hw_addr + 0x0011cc);
	// RAM offset mask
	iowrite32(ram_offset_mask & 0xffffffff, app->app_hw_addr + 0x0011d0);
	iowrite32((ram_offset_mask >> 32) & 0xffffffff, app->app_hw_addr + 0x0011d4);
	// RAM stride
	iowrite32(ram_stride & 0xffffffff, app->app_hw_addr + 0x0011d8);
	iowrite32((ram_stride >> 32) & 0xffffffff, app->app_hw_addr + 0x0011dc);
	// clear cycle count
	iowrite32(0, app->app_hw_addr + 0x001108);
	iowrite32(0, app->app_hw_addr + 0x00110c);
	// block length
	iowrite32(block_len, app->app_hw_addr + 0x001110);
	// block count
	iowrite32(block_count, app->app_hw_addr + 0x001118);
	// start
	iowrite32(1, app->app_hw_addr + 0x001100);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(20000);
	while (time_before(jiffies, t)) {
		if ((ioread32(app->app_hw_addr + 0x001100) & 1) == 0)
			break;
	}

	if ((ioread32(app->app_hw_addr + 0x001100) & 1) != 0)
		dev_warn(app->dev, "%s: operation timed out", __func__);
}

static void dma_block_read_bench(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, u64 size, u64 stride, u64 count)
{
	u64 cycles;
	u64 op_count;
	u64 op_latency;
	u64 req_count;
	u64 req_latency;

	udelay(5);

	op_count = read_stat_counter(app, 32);
	op_latency = read_stat_counter(app, 34);
	req_count = read_stat_counter(app, 36);
	req_latency = read_stat_counter(app, 37);

	dma_block_read(app, dma_addr, 0, 0x3fff, stride,
			0, 0, 0x3fff, stride, size, count);

	cycles = ioread32(app->app_hw_addr + 0x001008);

	udelay(5);

	op_count = read_stat_counter(app, 32) - op_count;
	op_latency = read_stat_counter(app, 34) - op_latency;
	req_count = read_stat_counter(app, 36) - req_count;
	req_latency = read_stat_counter(app, 37) - req_latency;

	dev_info(app->dev, "read %lld blocks of %lld bytes (stride %lld) in %lld ns (%lld ns/op, %lld req, %lld ns/req): %lld Mbps",
			count, size, stride, cycles * 4, (op_latency * 4) / op_count, req_count,
			(req_latency * 4) / req_count, size * count * 8 * 1000 / (cycles * 4));
}

static void dma_block_write_bench(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, u64 size, u64 stride, u64 count)
{
	u64 cycles;
	u64 op_count;
	u64 op_latency;
	u64 req_count;
	u64 req_latency;

	udelay(5);

	op_count = read_stat_counter(app, 48);
	op_latency = read_stat_counter(app, 50);
	req_count = read_stat_counter(app, 52);
	req_latency = read_stat_counter(app, 53);

	dma_block_write(app, dma_addr, 0, 0x3fff, stride,
			0, 0, 0x3fff, stride, size, count);

	cycles = ioread32(app->app_hw_addr + 0x001108);

	udelay(5);

	op_count = read_stat_counter(app, 48) - op_count;
	op_latency = read_stat_counter(app, 50) - op_latency;
	req_count = read_stat_counter(app, 52) - req_count;
	req_latency = read_stat_counter(app, 53) - req_latency;

	dev_info(app->dev, "wrote %lld blocks of %lld bytes (stride %lld) in %lld ns (%lld ns/op, %lld req, %lld ns/req): %lld Mbps",
			count, size, stride, cycles * 4, (op_latency * 4) / op_count, req_count,
			(req_latency * 4) / req_count, size * count * 8 * 1000 / (cycles * 4));
}

static int mqnic_app_dma_bench_probe(struct auxiliary_device *adev,
		const struct auxiliary_device_id *id)
{
	struct mqnic_app_dma_bench *app;
	struct mqnic_dev *mdev = container_of(adev, struct mqnic_adev, adev)->mdev;
	struct device *dev = &adev->dev;

	int mismatch = 0;
	int k;

	dev_info(dev, "%s() called", __func__);

	if (!mdev->hw_addr || !mdev->app_hw_addr) {
		dev_err(dev, "Error: required region not present");
		return -EIO;
	}

	app = devm_kzalloc(dev, sizeof(*app), GFP_KERNEL);
	if (!app)
		return -ENOMEM;

	app->dev = dev;
	app->mdev = mdev;
	dev_set_drvdata(&adev->dev, app);

	app->nic_dev = mdev->dev;
	app->nic_hw_addr = mdev->hw_addr;
	app->app_hw_addr = mdev->app_hw_addr;
	app->ram_hw_addr = mdev->ram_hw_addr;

	// Allocate DMA buffer
	app->dma_region_len = 16 * 1024;
	app->dma_region = dma_alloc_coherent(app->nic_dev, app->dma_region_len,
			&app->dma_region_addr, GFP_KERNEL | __GFP_ZERO);
	if (!app->dma_region)
		return -ENOMEM;

	dev_info(dev, "Allocated DMA region virt %p, phys %p",
			app->dma_region, (void *)app->dma_region_addr);

	// Dump counters
	dev_info(dev, "Statistics counters");
	print_counters(app);

	// DMA test
	dev_info(dev, "Write test data");
	for (k = 0; k < 256; k++)
		((char *)app->dma_region)[k] = k;

	dev_info(dev, "Read test data");
	print_hex_dump(KERN_INFO, "", DUMP_PREFIX_NONE, 16, 1,
			app->dma_region, 256, true);

	dev_info(dev, "Start copy to card");
	dma_read(app, app->dma_region_addr + 0x0000, 0x100, 0x100);

	dev_info(dev, "Start copy to host");
	dma_write(app, app->dma_region_addr + 0x0200, 0x100, 0x100);

	dev_info(dev, "read test data");
	print_hex_dump(KERN_INFO, "", DUMP_PREFIX_NONE, 16, 1,
			app->dma_region + 0x0200, 256, true);

	if (memcmp(app->dma_region + 0x0000, app->dma_region + 0x0200, 256) == 0) {
		dev_info(dev, "test data matches");
	} else {
		dev_warn(dev, "test data mismatch");
		mismatch = 1;
	}

	if (!mismatch) {
		u64 size;
		u64 stride;
		struct page *page;
		dma_addr_t dma_addr;

		dev_info(dev, "perform block reads (dma_alloc_coherent)");

		for (size = 1; size <= 8192; size *= 2) {
			for (stride = size; stride <= max(size, 256llu); stride *= 2) {
				dma_block_read_bench(app, app->dma_region_addr + 0x0000,
						size, stride, 10000);
			}
		}

		dev_info(dev, "perform block writes (dma_alloc_coherent)");

		for (size = 1; size <= 8192; size *= 2) {
			for (stride = size; stride <= max(size, 256llu); stride *= 2) {
				dma_block_write_bench(app, app->dma_region_addr + 0x0000,
						size, stride, 10000);
			}
		}

		page = alloc_pages_node(NUMA_NO_NODE, GFP_ATOMIC | __GFP_NOWARN |
				__GFP_COMP | __GFP_MEMALLOC, 2);

		if (page) {
			dma_addr = dma_map_page(app->nic_dev, page, 0, 4096 * (1 << 2), PCI_DMA_TODEVICE);

			if (!dma_mapping_error(app->nic_dev, dma_addr)) {
				dev_info(dev, "perform block reads (alloc_pages_node)");

				for (size = 1; size <= 8192; size *= 2) {
					for (stride = size; stride <= max(size, 256llu); stride *= 2) {
						dma_block_read_bench(app, dma_addr + 0x0000,
								size, stride, 10000);
					}
				}

				dma_unmap_page(app->nic_dev, dma_addr, 4096 * (1 << 2), PCI_DMA_TODEVICE);
			} else {
				dev_warn(dev, "DMA mapping error");
			}

			dma_addr = dma_map_page(app->nic_dev, page, 0, 4096 * (1 << 2), PCI_DMA_FROMDEVICE);

			if (!dma_mapping_error(app->nic_dev, dma_addr)) {
				dev_info(dev, "perform block writes (alloc_pages_node)");

				for (size = 1; size <= 8192; size *= 2) {
					for (stride = size; stride <= max(size, 256llu); stride *= 2) {
						dma_block_write_bench(app, dma_addr + 0x0000,
								size, stride, 10000);
					}
				}

				dma_unmap_page(app->nic_dev, dma_addr, 4096 * (1 << 2), PCI_DMA_FROMDEVICE);
			} else {
				dev_warn(dev, "DMA mapping error");
			}
		}

		if (page)
			__free_pages(page, 2);
		else
			dev_warn(dev, "failed to allocate memory");
	}

	// Dump counters
	dev_info(dev, "Statistics counters");
	print_counters(app);

	return 0;
}

static void mqnic_app_dma_bench_remove(struct auxiliary_device *adev)
{
	struct mqnic_app_dma_bench *app = dev_get_drvdata(&adev->dev);
	struct device *dev = app->dev;

	dev_info(dev, "%s() called", __func__);

	dma_free_coherent(app->nic_dev, app->dma_region_len, app->dma_region,
			app->dma_region_addr);
}

static const struct auxiliary_device_id mqnic_app_dma_bench_id_table[] = {
	{ .name = "mqnic.app_12348001" },
	{},
};

MODULE_DEVICE_TABLE(auxiliary, mqnic_app_dma_bench_id_table);

static struct auxiliary_driver mqnic_app_dma_bench_driver = {
	.name = "mqnic_app_dma_bench",
	.probe = mqnic_app_dma_bench_probe,
	.remove = mqnic_app_dma_bench_remove,
	.id_table = mqnic_app_dma_bench_id_table,
};

static int __init mqnic_app_dma_bench_init(void)
{
	return auxiliary_driver_register(&mqnic_app_dma_bench_driver);
}

static void __exit mqnic_app_dma_bench_exit(void)
{
	auxiliary_driver_unregister(&mqnic_app_dma_bench_driver);
}

module_init(mqnic_app_dma_bench_init);
module_exit(mqnic_app_dma_bench_exit);
