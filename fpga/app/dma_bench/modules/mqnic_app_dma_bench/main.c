// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2022-2023 The Regents of the University of California
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

	struct mqnic_reg_block *rb_list;
	struct mqnic_reg_block *dma_bench_rb;

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
	"dma_rd_tx_limit",         // index 9
	"dma_rd_tx_stall",         // index 10
	"",                        // index 11
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
	"dma_wr_tx_limit",         // index 25
	"dma_wr_tx_stall",         // index 26
	"",                        // index 27
	"",                        // index 28
	"",                        // index 29
	"",                        // index 30
	"",                        // index 31
	0
};

static void print_counters(struct mqnic_app_dma_bench *app)
{
	struct device *dev = app->dev;

	int index = 0;
	u64 val;

	while (dma_bench_stats_names[index]) {
		if (strlen(dma_bench_stats_names[index]) > 0) {
			val = mqnic_stats_read(app->mdev, index);
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

	tag = ioread32(app->dma_bench_rb->regs + 0x118); // dummy read
	tag = (ioread32(app->dma_bench_rb->regs + 0x118) & 0x7f) + 1;
	iowrite32(dma_addr & 0xffffffff, app->dma_bench_rb->regs + 0x100);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x104);
	iowrite32(ram_addr, app->dma_bench_rb->regs + 0x108);
	iowrite32(0, app->dma_bench_rb->regs + 0x10C);
	iowrite32(len, app->dma_bench_rb->regs + 0x110);
	iowrite32(tag, app->dma_bench_rb->regs + 0x114);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(200);
	while (time_before(jiffies, t)) {
		new_tag = (ioread32(app->dma_bench_rb->regs + 0x118) & 0xff);
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

	tag = ioread32(app->dma_bench_rb->regs + 0x218); // dummy read
	tag = (ioread32(app->dma_bench_rb->regs + 0x218) & 0x7f) + 1;
	iowrite32(dma_addr & 0xffffffff, app->dma_bench_rb->regs + 0x200);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x204);
	iowrite32(ram_addr, app->dma_bench_rb->regs + 0x208);
	iowrite32(0, app->dma_bench_rb->regs + 0x20C);
	iowrite32(len, app->dma_bench_rb->regs + 0x210);
	iowrite32(tag, app->dma_bench_rb->regs + 0x214);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(200);
	while (time_before(jiffies, t)) {
		new_tag = (ioread32(app->dma_bench_rb->regs + 0x218) & 0xff);
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
	iowrite32(dma_addr & 0xffffffff, app->dma_bench_rb->regs + 0x380);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x384);
	// DMA offset address
	iowrite32(dma_offset & 0xffffffff, app->dma_bench_rb->regs + 0x388);
	iowrite32((dma_offset >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x38c);
	// DMA offset mask
	iowrite32(dma_offset_mask & 0xffffffff, app->dma_bench_rb->regs + 0x390);
	iowrite32((dma_offset_mask >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x394);
	// DMA stride
	iowrite32(dma_stride & 0xffffffff, app->dma_bench_rb->regs + 0x398);
	iowrite32((dma_stride >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x39c);
	// RAM base address
	iowrite32(ram_addr & 0xffffffff, app->dma_bench_rb->regs + 0x3c0);
	iowrite32((ram_addr >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x3c4);
	// RAM offset address
	iowrite32(ram_offset & 0xffffffff, app->dma_bench_rb->regs + 0x3c8);
	iowrite32((ram_offset >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x3cc);
	// RAM offset mask
	iowrite32(ram_offset_mask & 0xffffffff, app->dma_bench_rb->regs + 0x3d0);
	iowrite32((ram_offset_mask >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x3d4);
	// RAM stride
	iowrite32(ram_stride & 0xffffffff, app->dma_bench_rb->regs + 0x3d8);
	iowrite32((ram_stride >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x3dc);
	// clear cycle count
	iowrite32(0, app->dma_bench_rb->regs + 0x308);
	iowrite32(0, app->dma_bench_rb->regs + 0x30c);
	// block length
	iowrite32(block_len, app->dma_bench_rb->regs + 0x310);
	// block count
	iowrite32(block_count, app->dma_bench_rb->regs + 0x318);
	// start
	iowrite32(1, app->dma_bench_rb->regs + 0x300);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(20000);
	while (time_before(jiffies, t)) {
		if ((ioread32(app->dma_bench_rb->regs + 0x300) & 1) == 0)
			break;
	}

	if ((ioread32(app->dma_bench_rb->regs + 0x300) & 1) != 0)
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
	iowrite32(dma_addr & 0xffffffff, app->dma_bench_rb->regs + 0x480);
	iowrite32((dma_addr >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x484);
	// DMA offset address
	iowrite32(dma_offset & 0xffffffff, app->dma_bench_rb->regs + 0x488);
	iowrite32((dma_offset >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x48c);
	// DMA offset mask
	iowrite32(dma_offset_mask & 0xffffffff, app->dma_bench_rb->regs + 0x490);
	iowrite32((dma_offset_mask >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x494);
	// DMA stride
	iowrite32(dma_stride & 0xffffffff, app->dma_bench_rb->regs + 0x498);
	iowrite32((dma_stride >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x49c);
	// RAM base address
	iowrite32(ram_addr & 0xffffffff, app->dma_bench_rb->regs + 0x4c0);
	iowrite32((ram_addr >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x4c4);
	// RAM offset address
	iowrite32(ram_offset & 0xffffffff, app->dma_bench_rb->regs + 0x4c8);
	iowrite32((ram_offset >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x4cc);
	// RAM offset mask
	iowrite32(ram_offset_mask & 0xffffffff, app->dma_bench_rb->regs + 0x4d0);
	iowrite32((ram_offset_mask >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x4d4);
	// RAM stride
	iowrite32(ram_stride & 0xffffffff, app->dma_bench_rb->regs + 0x4d8);
	iowrite32((ram_stride >> 32) & 0xffffffff, app->dma_bench_rb->regs + 0x4dc);
	// clear cycle count
	iowrite32(0, app->dma_bench_rb->regs + 0x408);
	iowrite32(0, app->dma_bench_rb->regs + 0x40c);
	// block length
	iowrite32(block_len, app->dma_bench_rb->regs + 0x410);
	// block count
	iowrite32(block_count, app->dma_bench_rb->regs + 0x418);
	// start
	iowrite32(1, app->dma_bench_rb->regs + 0x400);

	// wait for transfer to complete
	t = jiffies + msecs_to_jiffies(20000);
	while (time_before(jiffies, t)) {
		if ((ioread32(app->dma_bench_rb->regs + 0x400) & 1) == 0)
			break;
	}

	if ((ioread32(app->dma_bench_rb->regs + 0x400) & 1) != 0)
		dev_warn(app->dev, "%s: operation timed out", __func__);
}

static void dma_block_read_bench(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, u64 size, u64 stride, u64 count)
{
	u64 time;
	u64 op_count;
	u64 op_latency;
	u64 req_count;
	u64 req_latency;

	udelay(5);

	op_count = mqnic_stats_read(app->mdev, 32);
	op_latency = mqnic_stats_read(app->mdev, 34);
	req_count = mqnic_stats_read(app->mdev, 36);
	req_latency = mqnic_stats_read(app->mdev, 37);

	dma_block_read(app, dma_addr, 0, 0x3fff, stride,
			0, 0, 0x3fff, stride, size, count);

	time = mqnic_core_clk_cycles_to_ns(app->mdev, ioread32(app->dma_bench_rb->regs + 0x308));

	udelay(5);

	op_count = mqnic_stats_read(app->mdev, 32) - op_count;
	op_latency = mqnic_core_clk_cycles_to_ns(app->mdev, mqnic_stats_read(app->mdev, 34) - op_latency);
	req_count = mqnic_stats_read(app->mdev, 36) - req_count;
	req_latency = mqnic_core_clk_cycles_to_ns(app->mdev, mqnic_stats_read(app->mdev, 37) - req_latency);

	dev_info(app->dev, "read %lld blocks of %lld bytes (stride %lld) in %lld ns (%lld ns/op, %lld req, %lld ns/req): %lld Mbps",
			count, size, stride, time, op_latency / op_count, req_count,
			req_latency / req_count, size * count * 8 * 1000 / time);
}

static void dma_block_write_bench(struct mqnic_app_dma_bench *app,
		dma_addr_t dma_addr, u64 size, u64 stride, u64 count)
{
	u64 time;
	u64 op_count;
	u64 op_latency;
	u64 req_count;
	u64 req_latency;

	udelay(5);

	op_count = mqnic_stats_read(app->mdev, 48);
	op_latency = mqnic_stats_read(app->mdev, 50);
	req_count = mqnic_stats_read(app->mdev, 52);
	req_latency = mqnic_stats_read(app->mdev, 53);

	dma_block_write(app, dma_addr, 0, 0x3fff, stride,
			0, 0, 0x3fff, stride, size, count);

	time = mqnic_core_clk_cycles_to_ns(app->mdev, ioread32(app->dma_bench_rb->regs + 0x408));

	udelay(5);

	op_count = mqnic_stats_read(app->mdev, 48) - op_count;
	op_latency = mqnic_core_clk_cycles_to_ns(app->mdev, mqnic_stats_read(app->mdev, 50) - op_latency);
	req_count = mqnic_stats_read(app->mdev, 52) - req_count;
	req_latency = mqnic_core_clk_cycles_to_ns(app->mdev, mqnic_stats_read(app->mdev, 53) - req_latency);

	dev_info(app->dev, "wrote %lld blocks of %lld bytes (stride %lld) in %lld ns (%lld ns/op, %lld req, %lld ns/req): %lld Mbps",
			count, size, stride, time, op_latency / op_count, req_count,
			req_latency / req_count, size * count * 8 * 1000 / time);
}

static void mqnic_app_dma_bench_remove(struct auxiliary_device *adev);

static int mqnic_app_dma_bench_probe(struct auxiliary_device *adev,
		const struct auxiliary_device_id *id)
{
	int ret = 0;
	struct mqnic_app_dma_bench *app;
	struct mqnic_dev *mdev = container_of(adev, struct mqnic_adev, adev)->mdev;
	struct device *dev = &adev->dev;
	struct mqnic_reg_block *rb;

	int mismatch = 0;
	int k;
	int rb_index;

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

	app->rb_list = mqnic_enumerate_reg_block_list(mdev->app_hw_addr, 0, mdev->app_hw_regs_size);
	if (!app->rb_list) {
		dev_err(dev, "Failed to enumerate blocks");
		return -EIO;
	}

	dev_info(dev, "Application register blocks:");
	for (rb = app->rb_list; rb->regs; rb++)
		dev_info(dev, " type 0x%08x (v %d.%d.%d.%d)", rb->type, rb->version >> 24,
				(rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

	app->dma_bench_rb = mqnic_find_reg_block(app->rb_list, 0x12348101, 0x00000100, 0);

	if (!app->dma_bench_rb) {
		ret = -EIO;
		dev_err(dev, "Error: DMA bench register block not found");
		goto fail_rb_init;
	}

	// Allocate DMA buffer
	app->dma_region_len = 16 * 1024;
	app->dma_region = dma_alloc_coherent(app->nic_dev, app->dma_region_len,
			&app->dma_region_addr, GFP_KERNEL | __GFP_ZERO);
	if (!app->dma_region) {
		ret = -ENOMEM;
		goto fail_dma_alloc;
	}

	dev_info(dev, "Allocated DMA region virt %p, phys %p",
			app->dma_region, (void *)app->dma_region_addr);

	// Dump counters
	dev_info(dev, "Statistics counters");
	print_counters(app);

	// DMA test
	dev_info(dev, "Run DMA benchmark");

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

	// DRAM test
	rb_index = 0;
	while ((rb = mqnic_find_reg_block(app->rb_list, 0x12348102, 0x00000100, rb_index))) {
		u32 data_width;
		u32 lane_count;
		u64 size;
		u64 base_addr;
		u64 size_mask;
		u64 cycles, time;
		dev_info(dev, "Run DRAM benchmark (channel %d)", rb_index);

		data_width = ioread32(rb->regs + 0x14);
		lane_count = ioread32(rb->regs + 0x18);

		dev_info(dev, "Address width: %d", ioread32(rb->regs + 0x10));
		dev_info(dev, "Data width: %d", data_width);
		base_addr = ioread32(rb->regs + 0x30);
		base_addr |= ((u64)ioread32(rb->regs + 0x34)) << 32;
		dev_info(dev, "Base address: 0x%016llx", base_addr);
		size_mask = ioread32(rb->regs + 0x38);
		size_mask |= ((u64)ioread32(rb->regs + 0x3C)) << 32;
		dev_info(dev, "Size mask: 0x%016llx", size_mask);

		// reset FIFO and data generator/checker
		iowrite32(0x00000002, rb->regs + 0x20);
		iowrite32(0x00000202, rb->regs + 0x24);

		// enable FIFO
		iowrite32(0x00000001, rb->regs + 0x20);

		size = 1024*1024;

		dev_info(dev, "Write test, size %lld", size);

		// clear cycle count
		iowrite32(0, rb->regs + 0x60);

		// set up and start transfer
		iowrite32(size, rb->regs + 0x68);
		iowrite32(0, rb->regs + 0x6C);
		iowrite32(0x00000001, rb->regs + 0x24);

		// wait for transfer to complete
		for (k = 0; k < 10; k++) {
			udelay(10000);
			if (ioread32(rb->regs + 0x24) == 0)
				break;
		}

		dev_info(dev, "Status: %d", ioread32(rb->regs + 0x24));
		dev_info(dev, "Occupancy: %d", ioread32(rb->regs + 0x50));
		cycles = ioread32(rb->regs + 0x60);
		time = mqnic_core_clk_cycles_to_ns(app->mdev, cycles);
		dev_info(dev, "Time: %lld ns (%lld cycles)", time, cycles);
		dev_info(dev, "Bandwidth: %lld Mbps", size*data_width*1000/time);

		dev_info(dev, "Read+write test with offset, size %lld", size);

		// clear cycle count
		iowrite32(0, rb->regs + 0x60);

		// set up and start transfer
		iowrite32(size, rb->regs + 0x68);
		iowrite32(size, rb->regs + 0x6C);
		iowrite32(0x00000101, rb->regs + 0x24);

		// wait for transfer to complete
		for (k = 0; k < 10; k++) {
			udelay(10000);
			if (ioread32(rb->regs + 0x24) == 0)
				break;
		}

		dev_info(dev, "Status: %d", ioread32(rb->regs + 0x24));
		dev_info(dev, "Occupancy: %d", ioread32(rb->regs + 0x50));
		cycles = ioread32(rb->regs + 0x60);
		time = mqnic_core_clk_cycles_to_ns(app->mdev, cycles);
		dev_info(dev, "Time: %lld ns (%lld cycles)", time, cycles);
		dev_info(dev, "Bandwidth: %lld Mbps", size*data_width*1000/time);

		dev_info(dev, "Read test, size %lld", size);

		// clear cycle count
		iowrite32(0, rb->regs + 0x60);

		// set up and start transfer
		iowrite32(0, rb->regs + 0x68);
		iowrite32(size, rb->regs + 0x6C);
		iowrite32(0x00000100, rb->regs + 0x24);

		// wait for transfer to complete
		for (k = 0; k < 10; k++) {
			udelay(10000);
			if (ioread32(rb->regs + 0x24) == 0)
				break;
		}

		dev_info(dev, "Status: %d", ioread32(rb->regs + 0x24));
		dev_info(dev, "Occupancy: %d", ioread32(rb->regs + 0x50));
		cycles = ioread32(rb->regs + 0x60);
		time = mqnic_core_clk_cycles_to_ns(app->mdev, cycles);
		dev_info(dev, "Time: %lld ns (%lld cycles)", time, cycles);
		dev_info(dev, "Bandwidth: %lld Mbps", size*data_width*1000/time);

		dev_info(dev, "Read+write test, size %lld", size);

		// clear cycle count
		iowrite32(0, rb->regs + 0x60);

		// set up and start transfer
		iowrite32(size, rb->regs + 0x68);
		iowrite32(size, rb->regs + 0x6C);
		iowrite32(0x00000101, rb->regs + 0x24);

		// wait for transfer to complete
		for (k = 0; k < 10; k++) {
			udelay(10000);
			if (ioread32(rb->regs + 0x24) == 0)
				break;
		}

		dev_info(dev, "Status: %d", ioread32(rb->regs + 0x24));
		dev_info(dev, "Occupancy: %d", ioread32(rb->regs + 0x50));
		cycles = ioread32(rb->regs + 0x60);
		time = mqnic_core_clk_cycles_to_ns(app->mdev, cycles);
		dev_info(dev, "Time: %lld ns (%lld cycles)", time, cycles);
		dev_info(dev, "Bandwidth: %lld Mbps", size*data_width*1000/time);

		for (k = 0; k < lane_count; k++) {
			dev_info(dev, "Lane %d error count: %d", k, ioread32(rb->regs + 0x80 + k*4));
		}

		rb_index++;
	}

	return 0;

fail_dma_alloc:
fail_rb_init:
	mqnic_app_dma_bench_remove(adev);
	return ret;
}	

static void mqnic_app_dma_bench_remove(struct auxiliary_device *adev)
{
	struct mqnic_app_dma_bench *app = dev_get_drvdata(&adev->dev);
	struct device *dev = app->dev;

	dev_info(dev, "%s() called", __func__);

	if (app->dma_region)
		dma_free_coherent(app->nic_dev, app->dma_region_len, app->dma_region,
				app->dma_region_addr);

	if (app->rb_list)
		mqnic_free_reg_block_list(app->rb_list);
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
