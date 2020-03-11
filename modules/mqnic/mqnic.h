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

#ifndef MQNIC_H
#define MQNIC_H

#include <linux/kernel.h>
#include <linux/pci.h>
#include <linux/miscdevice.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/net_tstamp.h>
#include <linux/ptp_clock_kernel.h>

#include <linux/i2c.h>
#include <linux/i2c-algo-bit.h>

#define DRIVER_NAME "mqnic"
#define DRIVER_VERSION "0.1"

#include "mqnic_hw.h"

struct mqnic_i2c_priv
{
    struct mqnic_dev *mqnic;

    u8 __iomem *scl_in_reg;
    u8 __iomem *scl_out_reg;
    u8 __iomem *sda_in_reg;
    u8 __iomem *sda_out_reg;

    uint32_t scl_in_mask;
    uint32_t scl_out_mask;
    uint32_t sda_in_mask;
    uint32_t sda_out_mask;
};

struct mqnic_dev {
    struct pci_dev *pdev;

    size_t hw_regs_size;
    phys_addr_t hw_regs_phys;
    u8 __iomem *hw_addr;
    u8 __iomem *phc_hw_addr;

    struct mutex state_lock;

    u8 base_mac[ETH_ALEN];

    char name[16];

    int msi_nvecs;

    unsigned int id;
    struct list_head dev_list_node;

    struct miscdevice misc_dev;

    u32 fw_id;
    u32 fw_ver;
    u32 board_id;
    u32 board_ver;

    u32 phc_count;
    u32 phc_offset;

    u32 if_count;
    u32 if_stride;
    u32 if_csr_offset;

    struct net_device *ndev[MQNIC_MAX_IF];

    struct ptp_clock *ptp_clock;
    struct ptp_clock_info ptp_clock_info;

    struct i2c_algo_bit_data if_i2c_algo[MQNIC_MAX_IF];
    struct i2c_adapter if_i2c_adap[MQNIC_MAX_IF];
    struct mqnic_i2c_priv if_i2c_priv[MQNIC_MAX_IF];

    struct i2c_algo_bit_data eeprom_i2c_algo;
    struct i2c_adapter eeprom_i2c_adap;
    struct mqnic_i2c_priv eeprom_i2c_priv;
    struct i2c_client *eeprom_i2c_client;
};

struct mqnic_tx_info {
    struct sk_buff *skb;
    DEFINE_DMA_UNMAP_ADDR(dma_addr);
    DEFINE_DMA_UNMAP_LEN(len);
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
    u32 head_ptr;
    u64 bytes;
    u64 packets;
    u64 dropped_packets;
    struct netdev_queue *tx_queue;

    // written from completion
    u32 tail_ptr ____cacheline_aligned_in_smp;
    u32 clean_tail_ptr;
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

    size_t buf_size;
    u8 *buf;
    dma_addr_t buf_dma_addr;

    union {
        struct mqnic_tx_info *tx_info;
        struct mqnic_rx_info *rx_info;
    };

    u32 hw_ptr_mask;
    u8 __iomem *hw_addr;
    u8 __iomem *hw_head_ptr;
    u8 __iomem *hw_tail_ptr;
} ____cacheline_aligned_in_smp;

struct mqnic_cq_ring {
    u32 head_ptr;

    u32 tail_ptr;

    u32 size;
    u32 size_mask;
    u32 stride;

    size_t buf_size;
    u8 *buf;
    dma_addr_t buf_dma_addr;

    struct net_device *ndev;
    struct napi_struct napi;
    int ring_index;
    int eq_index;

    void (*handler) (struct mqnic_cq_ring *);

    u32 hw_ptr_mask;
    u8 __iomem *hw_addr;
    u8 __iomem *hw_head_ptr;
    u8 __iomem *hw_tail_ptr;
};

struct mqnic_eq_ring {
    u32 head_ptr;

    u32 tail_ptr;

    u32 size;
    u32 size_mask;
    u32 stride;

    size_t buf_size;
    u8 *buf;
    dma_addr_t buf_dma_addr;

    struct net_device *ndev;
    int int_index;

    int irq;

    void (*handler) (struct mqnic_eq_ring *);

    u32 hw_ptr_mask;
    u8 __iomem *hw_addr;
    u8 __iomem *hw_head_ptr;
    u8 __iomem *hw_tail_ptr;
};

struct mqnic_port {
    struct device *dev;
    struct net_device *ndev;

    int index;

    u32 tx_queue_count;

    u32 port_id;
    u32 port_features;
    u32 port_mtu;
    u32 sched_count;
    u32 sched_offset;
    u32 sched_stride;
    u32 sched_type;

    u8 __iomem *hw_addr;
};

struct mqnic_priv {
    struct device *dev;
    struct net_device *ndev;
    struct mqnic_dev *mdev;

    spinlock_t stats_lock;

    bool registered;
    int port;
    bool port_up;

    u32 if_id;
    u32 if_features;
    u32 event_queue_count;
    u32 event_queue_offset;
    u32 tx_queue_count;
    u32 tx_queue_offset;
    u32 tx_cpl_queue_count;
    u32 tx_cpl_queue_offset;
    u32 rx_queue_count;
    u32 rx_queue_offset;
    u32 rx_cpl_queue_count;
    u32 rx_cpl_queue_offset;
    u32 port_count;
    u32 port_offset;
    u32 port_stride;

    u8 __iomem *hw_addr;
    u8 __iomem *csr_hw_addr;

    struct mqnic_eq_ring *event_ring[MQNIC_MAX_EVENT_RINGS];
    struct mqnic_ring *tx_ring[MQNIC_MAX_TX_RINGS];
    struct mqnic_cq_ring *tx_cpl_ring[MQNIC_MAX_TX_CPL_RINGS];
    struct mqnic_ring *rx_ring[MQNIC_MAX_RX_RINGS];
    struct mqnic_cq_ring *rx_cpl_ring[MQNIC_MAX_RX_CPL_RINGS];
    struct mqnic_port *ports[MQNIC_MAX_PORTS];

    struct hwtstamp_config hwts_config;
};

// mqnic_main.c
extern struct mqnic_dev *mqnic_find_by_minor(unsigned minor);

// mqnic_dev.c
extern const struct file_operations mqnic_fops;

// mqnic_netdev.c
void mqnic_update_stats(struct net_device *ndev);
int mqnic_init_netdev(struct mqnic_dev *mdev, int port, u8 __iomem *hw_addr);
void mqnic_destroy_netdev(struct net_device *ndev);

// mqnic_port.c
int mqnic_create_port(struct mqnic_priv *priv, struct mqnic_port **port_ptr, int index, u8 __iomem *hw_addr);
void mqnic_destroy_port(struct mqnic_priv *priv, struct mqnic_port **port_ptr);
int mqnic_activate_port(struct mqnic_port *port);
void mqnic_deactivate_port(struct mqnic_port *port);
u32 mqnic_port_get_rss_mask(struct mqnic_port *port);
void mqnic_port_set_rss_mask(struct mqnic_port *port, u32 rss_mask);

// mqnic_ptp.c
void mqnic_register_phc(struct mqnic_dev *mdev);
void mqnic_unregister_phc(struct mqnic_dev *mdev);
ktime_t mqnic_read_cpl_ts(struct mqnic_dev *mdev, struct mqnic_ring *ring, const struct mqnic_cpl *cpl);

// mqnic_i2c.c
int mqnic_init_i2c(struct mqnic_dev *mqnic);
void mqnic_remove_i2c(struct mqnic_dev *mqnic);

// mqnic_eq.c
int mqnic_create_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring **ring_ptr, int size, int stride, int index, u8 __iomem *hw_addr);
void mqnic_destroy_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring **ring_ptr);
int mqnic_activate_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring *ring, int int_index);
void mqnic_deactivate_eq_ring(struct mqnic_priv *priv, struct mqnic_eq_ring *ring);
bool mqnic_is_eq_ring_empty(const struct mqnic_eq_ring *ring);
bool mqnic_is_eq_ring_full(const struct mqnic_eq_ring *ring);
void mqnic_eq_read_head_ptr(struct mqnic_eq_ring *ring);
void mqnic_eq_write_tail_ptr(struct mqnic_eq_ring *ring);
void mqnic_arm_eq(struct mqnic_eq_ring *ring);
void mqnic_process_eq(struct net_device *ndev, struct mqnic_eq_ring *eq_ring);

// mqnic_cq.c
int mqnic_create_cq_ring(struct mqnic_priv *priv, struct mqnic_cq_ring **ring_ptr, int size, int stride, int index, u8 __iomem *hw_addr);
void mqnic_destroy_cq_ring(struct mqnic_priv *priv, struct mqnic_cq_ring **ring_ptr);
int mqnic_activate_cq_ring(struct mqnic_priv *priv, struct mqnic_cq_ring *ring, int eq_index);
void mqnic_deactivate_cq_ring(struct mqnic_priv *priv, struct mqnic_cq_ring *ring);
bool mqnic_is_cq_ring_empty(const struct mqnic_cq_ring *ring);
bool mqnic_is_cq_ring_full(const struct mqnic_cq_ring *ring);
void mqnic_cq_read_head_ptr(struct mqnic_cq_ring *ring);
void mqnic_cq_write_tail_ptr(struct mqnic_cq_ring *ring);
void mqnic_arm_cq(struct mqnic_cq_ring *ring);

// mqnic_tx.c
int mqnic_create_tx_ring(struct mqnic_priv *priv, struct mqnic_ring **ring_ptr, int size, int stride, int index, u8 __iomem *hw_addr);
void mqnic_destroy_tx_ring(struct mqnic_priv *priv, struct mqnic_ring **ring_ptr);
int mqnic_activate_tx_ring(struct mqnic_priv *priv, struct mqnic_ring *ring, int cpl_index);
void mqnic_deactivate_tx_ring(struct mqnic_priv *priv, struct mqnic_ring *ring);
bool mqnic_is_tx_ring_empty(const struct mqnic_ring *ring);
bool mqnic_is_tx_ring_full(const struct mqnic_ring *ring);
void mqnic_tx_read_tail_ptr(struct mqnic_ring *ring);
void mqnic_tx_write_head_ptr(struct mqnic_ring *ring);
void mqnic_free_tx_desc(struct mqnic_priv *priv, struct mqnic_ring *ring, int index, int napi_budget);
int mqnic_free_tx_buf(struct mqnic_priv *priv, struct mqnic_ring *ring);
int mqnic_process_tx_cq(struct net_device *ndev, struct mqnic_cq_ring *cq_ring, int napi_budget);
void mqnic_tx_irq(struct mqnic_cq_ring *cq);
int mqnic_poll_tx_cq(struct napi_struct *napi, int budget);
netdev_tx_t mqnic_start_xmit(struct sk_buff *skb, struct net_device *dev);

// mqnic_rx.c
int mqnic_create_rx_ring(struct mqnic_priv *priv, struct mqnic_ring **ring_ptr, int size, int stride, int index, u8 __iomem *hw_addr);
void mqnic_destroy_rx_ring(struct mqnic_priv *priv, struct mqnic_ring **ring_ptr);
int mqnic_activate_rx_ring(struct mqnic_priv *priv, struct mqnic_ring *ring, int cpl_index);
void mqnic_deactivate_rx_ring(struct mqnic_priv *priv, struct mqnic_ring *ring);
bool mqnic_is_rx_ring_empty(const struct mqnic_ring *ring);
bool mqnic_is_rx_ring_full(const struct mqnic_ring *ring);
void mqnic_rx_read_tail_ptr(struct mqnic_ring *ring);
void mqnic_rx_write_head_ptr(struct mqnic_ring *ring);
void mqnic_free_rx_desc(struct mqnic_priv *priv, struct mqnic_ring *ring, int index);
int mqnic_free_rx_buf(struct mqnic_priv *priv, struct mqnic_ring *ring);
int mqnic_prepare_rx_desc(struct mqnic_priv *priv, struct mqnic_ring *ring, int index);
void mqnic_refill_rx_buffers(struct mqnic_priv *priv, struct mqnic_ring *ring);
int mqnic_process_rx_cq(struct net_device *ndev, struct mqnic_cq_ring *cq_ring, int napi_budget);
void mqnic_rx_irq(struct mqnic_cq_ring *cq);
int mqnic_poll_rx_cq(struct napi_struct *napi, int budget);

// mqnic_ethtool.c
extern const struct ethtool_ops mqnic_ethtool_ops;

#endif /* MQNIC_H */
