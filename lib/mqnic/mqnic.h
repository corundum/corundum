// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#ifndef MQNIC_H
#define MQNIC_H

#include <limits.h>
#include <stdint.h>

#include "mqnic_hw.h"
#include "reg_block.h"

#define mqnic_reg_read32(base, reg) (((volatile uint32_t *)(base))[(reg)/4])
#define mqnic_reg_write32(base, reg, val) (((volatile uint32_t *)(base))[(reg)/4]) = val

struct mqnic;

struct mqnic_res {
    unsigned int count;
    volatile uint8_t *base;
    unsigned int stride;
};

struct mqnic_sched {
    struct mqnic *mqnic;
    struct mqnic_if *interface;
    struct mqnic_sched_block *sched_block;

    int index;

    struct mqnic_reg_block *rb;

    uint32_t type;
    uint32_t offset;
    uint32_t channel_count;
    uint32_t channel_stride;

    size_t regs_size;
    volatile uint8_t *regs;
};

struct mqnic_sched_block {
    struct mqnic *mqnic;
    struct mqnic_if *interface;

    int index;

    struct mqnic_reg_block *rb_list;

    uint32_t sched_count;
    struct mqnic_sched *sched[MQNIC_MAX_SCHED];
};

struct mqnic_port {
    struct mqnic *mqnic;
    struct mqnic_if *interface;

    int index;

    struct mqnic_reg_block *rb_list;
    struct mqnic_reg_block *port_ctrl_rb;

    uint32_t port_features;
};

struct mqnic_if {
    struct mqnic *mqnic;

    int index;

    size_t regs_size;
    volatile uint8_t *regs;
    volatile uint8_t *csr_regs;

    struct mqnic_reg_block *rb_list;
    struct mqnic_reg_block *if_ctrl_rb;
    struct mqnic_reg_block *eq_rb;
    struct mqnic_reg_block *cq_rb;
    struct mqnic_reg_block *txq_rb;
    struct mqnic_reg_block *rxq_rb;
    struct mqnic_reg_block *rx_queue_map_rb;

    uint32_t if_features;

    uint32_t max_tx_mtu;
    uint32_t max_rx_mtu;
    uint32_t tx_fifo_depth;
    uint32_t rx_fifo_depth;

    uint32_t rx_queue_map_indir_table_size;
    volatile uint8_t *rx_queue_map_indir_table[MQNIC_MAX_PORTS];

    struct mqnic_res *eq_res;
    struct mqnic_res *cq_res;
    struct mqnic_res *txq_res;
    struct mqnic_res *rxq_res;

    uint32_t port_count;
    struct mqnic_port *ports[MQNIC_MAX_PORTS];

    uint32_t sched_block_count;
    struct mqnic_sched_block *sched_blocks[MQNIC_MAX_PORTS];
};

struct mqnic {
    int fd;
    int app_fd;
    int ram_fd;

    size_t regs_size;
    volatile uint8_t *regs;

    size_t app_regs_size;
    volatile uint8_t *app_regs;

    size_t ram_size;
    volatile uint8_t *ram;

    struct mqnic_reg_block *rb_list;
    struct mqnic_reg_block *fw_id_rb;
    struct mqnic_reg_block *if_rb;
    struct mqnic_reg_block *stats_rb;
    struct mqnic_reg_block *clk_info_rb;
    struct mqnic_reg_block *phc_rb;

    uint32_t fpga_id;
    const char *fpga_part;
    uint32_t fw_id;
    uint32_t fw_ver;
    uint32_t board_id;
    uint32_t board_ver;
    uint32_t build_date;
    uint32_t git_hash;
    uint32_t rel_info;

    uint32_t app_id;

    uint32_t stats_offset;
    uint32_t stats_count;
    uint32_t stats_stride;
    uint32_t stats_flags;

    uint16_t core_clk_nom_per_ns_num;
    uint16_t core_clk_nom_per_ns_denom;
    uint32_t core_clk_nom_freq_hz;
    uint16_t ref_clk_nom_per_ns_num;
    uint16_t ref_clk_nom_per_ns_denom;
    uint32_t ref_clk_nom_freq_hz;
    uint32_t clk_info_channels;

    uint32_t if_offset;
    uint32_t if_count;
    uint32_t if_stride;
    uint32_t if_csr_offset;

    char build_date_str[32];

    struct mqnic_if *interfaces[MQNIC_MAX_IF];

    char device_path[PATH_MAX];
    char pci_device_path[PATH_MAX];
};

// mqnic.c
struct mqnic *mqnic_open(const char *dev_name);
void mqnic_close(struct mqnic *dev);
void mqnic_print_fw_id(struct mqnic *dev);

// mqnic_res.c
struct mqnic_res *mqnic_res_open(unsigned int count, volatile uint8_t *base, unsigned int stride);
void mqnic_res_close(struct mqnic_res *res);
unsigned int mqnic_res_get_count(struct mqnic_res *res);
volatile uint8_t *mqnic_res_get_addr(struct mqnic_res *res, int index);

// mqnic_if.c
struct mqnic_if *mqnic_if_open(struct mqnic *dev, int index, volatile uint8_t *regs);
void mqnic_if_close(struct mqnic_if *interface);
uint32_t mqnic_interface_get_tx_mtu(struct mqnic_if *interface);
uint32_t mqnic_interface_get_rx_mtu(struct mqnic_if *interface);
uint32_t mqnic_interface_get_rx_queue_map_rss_mask(struct mqnic_if *interface, int port);
uint32_t mqnic_interface_get_rx_queue_map_app_mask(struct mqnic_if *interface, int port);
uint32_t mqnic_interface_get_rx_queue_map_indir_table(struct mqnic_if *interface, int port, int index);

// mqnic_port.c
struct mqnic_port *mqnic_port_open(struct mqnic_if *interface, int index, struct mqnic_reg_block *port_rb);
void mqnic_port_close(struct mqnic_port *port);
uint32_t mqnic_port_get_tx_ctrl(struct mqnic_port *port);
uint32_t mqnic_port_get_rx_ctrl(struct mqnic_port *port);
uint32_t mqnic_port_get_fc_ctrl(struct mqnic_port *port);
uint32_t mqnic_port_get_lfc_ctrl(struct mqnic_port *port);
uint32_t mqnic_port_get_pfc_ctrl(struct mqnic_port *port, int index);

// mqnic_sched_block.c
struct mqnic_sched_block *mqnic_sched_block_open(struct mqnic_if *interface, int index, struct mqnic_reg_block *block_rb);
void mqnic_sched_block_close(struct mqnic_sched_block *block);

// mqnic_scheduler.c
struct mqnic_sched *mqnic_sched_open(struct mqnic_sched_block *block, int index, struct mqnic_reg_block *rb);
void mqnic_sched_close(struct mqnic_sched *sched);

// mqnic_clk_info.c
void mqnic_clk_info_init(struct mqnic *dev);
uint32_t mqnic_get_core_clk_nom_freq_hz(struct mqnic *dev);
uint32_t mqnic_get_ref_clk_nom_freq_hz(struct mqnic *dev);
uint32_t mqnic_get_core_clk_freq_hz(struct mqnic *dev);
uint32_t mqnic_get_clk_freq_hz(struct mqnic *dev, int ch);
uint64_t mqnic_core_clk_cycles_to_ns(struct mqnic *dev, uint64_t cycles);
uint64_t mqnic_core_clk_ns_to_cycles(struct mqnic *dev, uint64_t ns);
uint64_t mqnic_ref_clk_cycles_to_ns(struct mqnic *dev, uint64_t cycles);
uint64_t mqnic_ref_clk_ns_to_cycles(struct mqnic *dev, uint64_t ns);

// mqnic_stats.c
void mqnic_stats_init(struct mqnic *dev);
uint64_t mqnic_stats_read(struct mqnic *dev, int index);

#endif /* MQNIC_H */
