// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#ifndef MQNIC_H
#define MQNIC_H

#include <linux/kernel.h>
#ifdef CONFIG_PCI
#include <linux/pci.h>
#endif
#ifdef CONFIG_AUXILIARY_BUS
#include <linux/auxiliary_bus.h>
#endif
#include <linux/platform_device.h>
#include <linux/miscdevice.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/net_tstamp.h>
#include <linux/ptp_clock_kernel.h>
#include <linux/timer.h>
#include <net/devlink.h>

#include <linux/i2c.h>
#include <linux/i2c-algo-bit.h>

#define DRIVER_NAME "mqnic"
#define DRIVER_VERSION "0.1"

#include "mqnic_hw.h"

#ifdef CONFIG_OF
/* platform driver OF-related definitions */
#define MQNIC_PROP_MAC_ADDR_INC_BYTE "mac-address-increment-byte"
#define MQNIC_PROP_MAC_ADDR_INC "mac-address-increment"
#define MQNIC_PROP_MAC_ADDR_LOCAL "mac-address-local"
#define MQNIC_PROP_MODULE_EEPROM "module-eeproms"
#endif

// default interval to poll port TX/RX status, in ms
#define MQNIC_LINK_STATUS_POLL_MS 1000

extern unsigned int mqnic_num_eq_entries;
extern unsigned int mqnic_num_txq_entries;
extern unsigned int mqnic_num_rxq_entries;

extern unsigned int mqnic_link_status_poll;

struct mqnic_dev;
struct mqnic_if;

struct mqnic_res {
	unsigned int count;
	u8 __iomem *base;
	unsigned int stride;

	spinlock_t lock;
	unsigned long *bmap;
};

struct mqnic_reg_block {
	u32 type;
	u32 version;
	u8 __iomem *regs;
	u8 __iomem *base;
};

struct mqnic_board_ops {
	int (*init)(struct mqnic_dev *mqnic);
	void (*deinit)(struct mqnic_dev *mqnic);
};

struct mqnic_i2c_bus {
	struct mqnic_dev *mqnic;

	u8 __iomem *scl_in_reg;
	u8 __iomem *scl_out_reg;
	u8 __iomem *sda_in_reg;
	u8 __iomem *sda_out_reg;

	u32 scl_in_mask;
	u32 scl_out_mask;
	u32 sda_in_mask;
	u32 sda_out_mask;

	struct list_head head;

	struct i2c_algo_bit_data algo;
	struct i2c_adapter adapter;
};

struct mqnic_irq {
	int index;
	int irqn;
	char name[16 + 3];
	struct atomic_notifier_head nh;
};

#ifdef CONFIG_AUXILIARY_BUS
struct mqnic_adev {
	struct auxiliary_device adev;
	struct mqnic_dev *mdev;
	struct mqnic_adev **ptr;
	char name[32];
};
#endif

struct mqnic_dev {
	struct device *dev;
#ifdef CONFIG_PCI
	struct pci_dev *pdev;
#endif
	struct platform_device *pfdev;

	resource_size_t hw_regs_size;
	phys_addr_t hw_regs_phys;
	u8 __iomem *hw_addr;
	u8 __iomem *phc_hw_addr;

	resource_size_t app_hw_regs_size;
	phys_addr_t app_hw_regs_phys;
	u8 __iomem *app_hw_addr;

	resource_size_t ram_hw_regs_size;
	phys_addr_t ram_hw_regs_phys;
	u8 __iomem *ram_hw_addr;

	struct mutex state_lock;

	int mac_count;
	u8 mac_list[MQNIC_MAX_IF][ETH_ALEN];

	char name[16];

	int irq_count;
	struct mqnic_irq *irq[MQNIC_MAX_IRQ];

	unsigned int id;
	struct list_head dev_list_node;

	struct miscdevice misc_dev;

#ifdef CONFIG_AUXILIARY_BUS
	struct mqnic_adev *app_adev;
#endif

	struct mqnic_reg_block *rb_list;
	struct mqnic_reg_block *fw_id_rb;
	struct mqnic_reg_block *if_rb;
	struct mqnic_reg_block *stats_rb;
	struct mqnic_reg_block *clk_info_rb;
	struct mqnic_reg_block *phc_rb;

	int phys_port_max;

	u32 fpga_id;
	u32 fw_id;
	u32 fw_ver;
	u32 board_id;
	u32 board_ver;
	u32 build_date;
	u32 git_hash;
	u32 rel_info;

	u32 app_id;

	u32 stats_offset;
	u32 stats_count;
	u32 stats_stride;
	u32 stats_flags;

	u32 core_clk_nom_per_ns_num;
	u32 core_clk_nom_per_ns_denom;
	u32 core_clk_nom_freq_hz;
	u32 ref_clk_nom_per_ns_num;
	u32 ref_clk_nom_per_ns_denom;
	u32 ref_clk_nom_freq_hz;
	u32 clk_info_channels;

	u32 if_offset;
	u32 if_count;
	u32 if_stride;
	u32 if_csr_offset;

	char build_date_str[32];

	struct mqnic_if *interface[MQNIC_MAX_IF];

	struct ptp_clock *ptp_clock;
	struct ptp_clock_info ptp_clock_info;

	struct mqnic_board_ops *board_ops;

	struct list_head i2c_bus;
	int i2c_adapter_count;

	int mod_i2c_client_count;
	struct i2c_client *mod_i2c_client[MQNIC_MAX_IF];
	struct i2c_client *eeprom_i2c_client;
};

struct mqnic_frag {
	dma_addr_t dma_addr;
	u32 len;
};

struct mqnic_tx_info {
	struct sk_buff *skb;
	DEFINE_DMA_UNMAP_ADDR(dma_addr);
	DEFINE_DMA_UNMAP_LEN(len);
	u32 frag_count;
	struct mqnic_frag frags[MQNIC_MAX_FRAGS - 1];
	int ts_requested;
};

struct mqnic_rx_info {
	struct page *page;
	u32 page_order;
	u32 page_offset;
	dma_addr_t dma_addr;
	u32 len;
};

struct mqnic_ring {
	// written on enqueue (i.e. start_xmit)
	u32 prod_ptr;
	u64 bytes;
	u64 packets;
	u64 dropped_packets;
	struct netdev_queue *tx_queue;

	// written from completion
	u32 cons_ptr ____cacheline_aligned_in_smp;
	u64 ts_s;
	u8 ts_valid;

	// mostly constant
	u32 size;
	u32 full_size;
	u32 size_mask;
	u32 stride;

	u32 cpl_index;

	u32 mtu;
	u32 page_order;

	u32 desc_block_size;
	u32 log_desc_block_size;

	size_t buf_size;
	u8 *buf;
	dma_addr_t buf_dma_addr;

	union {
		struct mqnic_tx_info *tx_info;
		struct mqnic_rx_info *rx_info;
	};

	struct device *dev;
	struct mqnic_if *interface;
	struct mqnic_priv *priv;
	int index;
	struct mqnic_cq *cq;
	int enabled;

	u8 __iomem *hw_addr;
} ____cacheline_aligned_in_smp;

struct mqnic_cq {
	u32 prod_ptr;

	u32 cons_ptr;

	u32 size;
	u32 size_mask;
	u32 stride;

	size_t buf_size;
	u8 *buf;
	dma_addr_t buf_dma_addr;

	struct device *dev;
	struct mqnic_if *interface;
	struct napi_struct napi;
	int cqn;
	struct mqnic_eq *eq;
	struct mqnic_ring *src_ring;
	int enabled;

	void (*handler)(struct mqnic_cq *cq);

	u8 __iomem *hw_addr;
};

struct mqnic_eq {
	u32 prod_ptr;

	u32 cons_ptr;

	u32 size;
	u32 size_mask;
	u32 stride;

	size_t buf_size;
	u8 *buf;
	dma_addr_t buf_dma_addr;

	struct device *dev;
	struct mqnic_if *interface;
	int eqn;
	struct mqnic_irq *irq;
	int enabled;

	struct notifier_block irq_nb;

	void (*handler)(struct mqnic_eq *eq);

	spinlock_t table_lock;
	struct radix_tree_root cq_table;

	u8 __iomem *hw_addr;
};

struct mqnic_sched {
	struct device *dev;
	struct mqnic_if *interface;
	struct mqnic_sched_block *sched_block;

	struct mqnic_reg_block *rb;

	int index;

	u32 type;
	u32 offset;
	u32 channel_count;
	u32 channel_stride;

	u8 __iomem *hw_addr;
};

struct mqnic_port {
	struct device *dev;
	struct mqnic_if *interface;

	struct mqnic_reg_block *port_rb;
	struct mqnic_reg_block *rb_list;
	struct mqnic_reg_block *port_ctrl_rb;

	int index;
	int phys_index;

	u32 port_features;

	struct devlink_port dl_port;
};

struct mqnic_sched_block {
	struct device *dev;
	struct mqnic_if *interface;

	struct mqnic_reg_block *block_rb;
	struct mqnic_reg_block *rb_list;

	int index;

	u32 sched_count;
	struct mqnic_sched *sched[MQNIC_MAX_PORTS];
};

struct mqnic_if {
	struct device *dev;
	struct mqnic_dev *mdev;

	struct mqnic_reg_block *rb_list;
	struct mqnic_reg_block *if_ctrl_rb;
	struct mqnic_reg_block *eq_rb;
	struct mqnic_reg_block *cq_rb;
	struct mqnic_reg_block *txq_rb;
	struct mqnic_reg_block *rxq_rb;
	struct mqnic_reg_block *rx_queue_map_rb;

	int index;

	u32 if_features;

	u32 max_tx_mtu;
	u32 max_rx_mtu;
	u32 tx_fifo_depth;
	u32 rx_fifo_depth;

	struct mqnic_res *eq_res;
	struct mqnic_res *cq_res;
	struct mqnic_res *txq_res;
	struct mqnic_res *rxq_res;

	u32 eq_count;
	struct mqnic_eq *eq[MQNIC_MAX_EQ];

	u32 port_count;
	struct mqnic_port *port[MQNIC_MAX_PORTS];

	u32 sched_block_count;
	struct mqnic_sched_block *sched_block[MQNIC_MAX_PORTS];

	u32 max_desc_block_size;

	u32 rx_queue_map_indir_table_size;
	u8 __iomem *rx_queue_map_indir_table[MQNIC_MAX_PORTS];

	resource_size_t hw_regs_size;
	u8 __iomem *hw_addr;
	u8 __iomem *csr_hw_addr;

	u32 ndev_count;
	struct net_device *ndev[MQNIC_MAX_PORTS];

	struct i2c_client *mod_i2c_client;
};

struct mqnic_priv {
	struct device *dev;
	struct net_device *ndev;
	struct devlink_port *dl_port;
	struct mqnic_dev *mdev;
	struct mqnic_if *interface;

	spinlock_t stats_lock;

	int index;
	bool registered;
	bool port_up;

	u32 if_features;

	unsigned int link_status;
	struct timer_list link_status_timer;

	u32 txq_count;
	u32 rxq_count;

	u32 tx_ring_size;
	u32 rx_ring_size;

	struct rw_semaphore txq_table_sem;
	struct radix_tree_root txq_table;

	struct rw_semaphore rxq_table_sem;
	struct radix_tree_root rxq_table;

	struct mqnic_sched_block *sched_block;
	struct mqnic_port *port;

	u32 max_desc_block_size;

	u32 rx_queue_map_indir_table_size;
	u32 *rx_queue_map_indir_table;

	struct hwtstamp_config hwts_config;

	struct i2c_client *mod_i2c_client;
};

// mqnic_main.c

// mqnic_devlink.c
struct devlink *mqnic_devlink_alloc(struct device *dev);
void mqnic_devlink_free(struct devlink *devlink);

// mqnic_res.c
struct mqnic_res *mqnic_create_res(unsigned int count, u8 __iomem *base, unsigned int stride);
void mqnic_destroy_res(struct mqnic_res *res);
int mqnic_res_alloc(struct mqnic_res *res);
void mqnic_res_free(struct mqnic_res *res, int index);
unsigned int mqnic_res_get_count(struct mqnic_res *res);
u8 __iomem *mqnic_res_get_addr(struct mqnic_res *res, int index);

// mqnic_reg_block.c
struct mqnic_reg_block *mqnic_enumerate_reg_block_list(u8 __iomem *base, size_t offset, size_t size);
struct mqnic_reg_block *mqnic_find_reg_block(struct mqnic_reg_block *list, u32 type, u32 version, int index);
void mqnic_free_reg_block_list(struct mqnic_reg_block *list);

// mqnic_irq.c
int mqnic_irq_init_pcie(struct mqnic_dev *mdev);
void mqnic_irq_deinit_pcie(struct mqnic_dev *mdev);
int mqnic_irq_init_platform(struct mqnic_dev *mdev);

// mqnic_dev.c
extern const struct file_operations mqnic_fops;

// mqnic_if.c
struct mqnic_if *mqnic_create_interface(struct mqnic_dev *mdev, int index, u8 __iomem *hw_addr);
void mqnic_destroy_interface(struct mqnic_if *interface);
u32 mqnic_interface_get_tx_mtu(struct mqnic_if *interface);
void mqnic_interface_set_tx_mtu(struct mqnic_if *interface, u32 mtu);
u32 mqnic_interface_get_rx_mtu(struct mqnic_if *interface);
void mqnic_interface_set_rx_mtu(struct mqnic_if *interface, u32 mtu);
u32 mqnic_interface_get_rx_queue_map_rss_mask(struct mqnic_if *interface, int port);
void mqnic_interface_set_rx_queue_map_rss_mask(struct mqnic_if *interface, int port, u32 val);
u32 mqnic_interface_get_rx_queue_map_app_mask(struct mqnic_if *interface, int port);
void mqnic_interface_set_rx_queue_map_app_mask(struct mqnic_if *interface, int port, u32 val);
u32 mqnic_interface_get_rx_queue_map_indir_table(struct mqnic_if *interface, int port, int index);
void mqnic_interface_set_rx_queue_map_indir_table(struct mqnic_if *interface, int port, int index, u32 val);

// mqnic_port.c
struct mqnic_port *mqnic_create_port(struct mqnic_if *interface, int index,
		int phys_index, struct mqnic_reg_block *port_rb);
void mqnic_destroy_port(struct mqnic_port *port);
u32 mqnic_port_get_tx_ctrl(struct mqnic_port *port);
void mqnic_port_set_tx_ctrl(struct mqnic_port *port, u32 val);
u32 mqnic_port_get_rx_ctrl(struct mqnic_port *port);
void mqnic_port_set_rx_ctrl(struct mqnic_port *port, u32 val);
u32 mqnic_port_get_fc_ctrl(struct mqnic_port *port);
void mqnic_port_set_fc_ctrl(struct mqnic_port *port, u32 val);
u32 mqnic_port_get_lfc_ctrl(struct mqnic_port *port);
void mqnic_port_set_lfc_ctrl(struct mqnic_port *port, u32 val);
u32 mqnic_port_get_pfc_ctrl(struct mqnic_port *port, int index);
void mqnic_port_set_pfc_ctrl(struct mqnic_port *port, int index, u32 val);

// mqnic_netdev.c
int mqnic_start_port(struct net_device *ndev);
void mqnic_stop_port(struct net_device *ndev);
int mqnic_update_indir_table(struct net_device *ndev);
void mqnic_update_stats(struct net_device *ndev);
struct net_device *mqnic_create_netdev(struct mqnic_if *interface, int index,
		struct mqnic_port *port, struct mqnic_sched_block *sched_block);
void mqnic_destroy_netdev(struct net_device *ndev);

// mqnic_sched_block.c
struct mqnic_sched_block *mqnic_create_sched_block(struct mqnic_if *interface,
		int index, struct mqnic_reg_block *rb);
void mqnic_destroy_sched_block(struct mqnic_sched_block *block);
int mqnic_activate_sched_block(struct mqnic_sched_block *block);
void mqnic_deactivate_sched_block(struct mqnic_sched_block *block);

// mqnic_scheduler.c
struct mqnic_sched *mqnic_create_scheduler(struct mqnic_sched_block *block,
		int index, struct mqnic_reg_block *rb);
void mqnic_destroy_scheduler(struct mqnic_sched *sched);
int mqnic_scheduler_enable(struct mqnic_sched *sched);
void mqnic_scheduler_disable(struct mqnic_sched *sched);

// mqnic_ptp.c
void mqnic_register_phc(struct mqnic_dev *mdev);
void mqnic_unregister_phc(struct mqnic_dev *mdev);
ktime_t mqnic_read_cpl_ts(struct mqnic_dev *mdev, struct mqnic_ring *ring,
		const struct mqnic_cpl *cpl);

// mqnic_i2c.c
struct mqnic_i2c_bus *mqnic_i2c_bus_create(struct mqnic_dev *mqnic, int index);
struct i2c_adapter *mqnic_i2c_adapter_create(struct mqnic_dev *mqnic, int index);
void mqnic_i2c_bus_release(struct mqnic_i2c_bus *bus);
void mqnic_i2c_adapter_release(struct i2c_adapter *adapter);
int mqnic_i2c_init(struct mqnic_dev *mqnic);
void mqnic_i2c_deinit(struct mqnic_dev *mqnic);

// mqnic_board.c
int mqnic_board_init(struct mqnic_dev *mqnic);
void mqnic_board_deinit(struct mqnic_dev *mqnic);

// mqnic_clk_info.c
void mqnic_clk_info_init(struct mqnic_dev *mdev);
u32 mqnic_get_core_clk_nom_freq_hz(struct mqnic_dev *mdev);
u32 mqnic_get_ref_clk_nom_freq_hz(struct mqnic_dev *mdev);
u32 mqnic_get_core_clk_freq_hz(struct mqnic_dev *mdev);
u32 mqnic_get_clk_freq_hz(struct mqnic_dev *mdev, int ch);
u64 mqnic_core_clk_cycles_to_ns(struct mqnic_dev *mdev, u64 cycles);
u64 mqnic_core_clk_ns_to_cycles(struct mqnic_dev *mdev, u64 ns);
u64 mqnic_ref_clk_cycles_to_ns(struct mqnic_dev *mdev, u64 cycles);
u64 mqnic_ref_clk_ns_to_cycles(struct mqnic_dev *mdev, u64 ns);

// mqnic_stats.c
void mqnic_stats_init(struct mqnic_dev *mdev);
u64 mqnic_stats_read(struct mqnic_dev *mdev, int index);

// mqnic_eq.c
struct mqnic_eq *mqnic_create_eq(struct mqnic_if *interface);
void mqnic_destroy_eq(struct mqnic_eq *eq);
int mqnic_open_eq(struct mqnic_eq *eq, struct mqnic_irq *irq, int size);
void mqnic_close_eq(struct mqnic_eq *eq);
int mqnic_eq_attach_cq(struct mqnic_eq *eq, struct mqnic_cq *cq);
void mqnic_eq_detach_cq(struct mqnic_eq *eq, struct mqnic_cq *cq);
void mqnic_eq_read_prod_ptr(struct mqnic_eq *eq);
void mqnic_eq_write_cons_ptr(struct mqnic_eq *eq);
void mqnic_arm_eq(struct mqnic_eq *eq);
void mqnic_process_eq(struct mqnic_eq *eq);

// mqnic_cq.c
struct mqnic_cq *mqnic_create_cq(struct mqnic_if *interface);
void mqnic_destroy_cq(struct mqnic_cq *cq);
int mqnic_open_cq(struct mqnic_cq *cq, struct mqnic_eq *eq, int size);
void mqnic_close_cq(struct mqnic_cq *cq);
void mqnic_cq_read_prod_ptr(struct mqnic_cq *cq);
void mqnic_cq_write_cons_ptr(struct mqnic_cq *cq);
void mqnic_arm_cq(struct mqnic_cq *cq);

// mqnic_tx.c
struct mqnic_ring *mqnic_create_tx_ring(struct mqnic_if *interface);
void mqnic_destroy_tx_ring(struct mqnic_ring *ring);
int mqnic_open_tx_ring(struct mqnic_ring *ring, struct mqnic_priv *priv,
		struct mqnic_cq *cq, int size, int desc_block_size);
void mqnic_close_tx_ring(struct mqnic_ring *ring);
int mqnic_enable_tx_ring(struct mqnic_ring *ring);
void mqnic_disable_tx_ring(struct mqnic_ring *ring);
bool mqnic_is_tx_ring_empty(const struct mqnic_ring *ring);
bool mqnic_is_tx_ring_full(const struct mqnic_ring *ring);
void mqnic_tx_read_cons_ptr(struct mqnic_ring *ring);
void mqnic_tx_write_prod_ptr(struct mqnic_ring *ring);
void mqnic_free_tx_desc(struct mqnic_ring *ring, int index, int napi_budget);
int mqnic_free_tx_buf(struct mqnic_ring *ring);
int mqnic_process_tx_cq(struct mqnic_cq *cq, int napi_budget);
void mqnic_tx_irq(struct mqnic_cq *cq);
int mqnic_poll_tx_cq(struct napi_struct *napi, int budget);
netdev_tx_t mqnic_start_xmit(struct sk_buff *skb, struct net_device *dev);

// mqnic_rx.c
struct mqnic_ring *mqnic_create_rx_ring(struct mqnic_if *interface);
void mqnic_destroy_rx_ring(struct mqnic_ring *ring);
int mqnic_open_rx_ring(struct mqnic_ring *ring, struct mqnic_priv *priv,
		struct mqnic_cq *cq, int size, int desc_block_size);
void mqnic_close_rx_ring(struct mqnic_ring *ring);
int mqnic_enable_rx_ring(struct mqnic_ring *ring);
void mqnic_disable_rx_ring(struct mqnic_ring *ring);
bool mqnic_is_rx_ring_empty(const struct mqnic_ring *ring);
bool mqnic_is_rx_ring_full(const struct mqnic_ring *ring);
void mqnic_rx_read_cons_ptr(struct mqnic_ring *ring);
void mqnic_rx_write_prod_ptr(struct mqnic_ring *ring);
void mqnic_free_rx_desc(struct mqnic_ring *ring, int index);
int mqnic_free_rx_buf(struct mqnic_ring *ring);
int mqnic_prepare_rx_desc(struct mqnic_ring *ring, int index);
int mqnic_refill_rx_buffers(struct mqnic_ring *ring);
int mqnic_process_rx_cq(struct mqnic_cq *cq, int napi_budget);
void mqnic_rx_irq(struct mqnic_cq *cq);
int mqnic_poll_rx_cq(struct napi_struct *napi, int budget);

// mqnic_ethtool.c
extern const struct ethtool_ops mqnic_ethtool_ops;

#endif /* MQNIC_H */
