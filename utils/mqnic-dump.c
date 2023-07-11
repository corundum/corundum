// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mqnic/mqnic.h>

static void usage(char *name)
{
    fprintf(stderr,
        "usage: %s [options]\n"
        " -d name    device to open (/dev/mqnic0)\n"
        " -i number  interface\n"
        " -P number  port\n"
        " -v         verbose output\n",
        name);
}

int main(int argc, char *argv[])
{
    char *name;
    int opt;
    int ret = 0;

    char *device = NULL;
    struct mqnic *dev;
    int interface = 0;
    int port = 0;
    int sched_block = 0;
    int verbose = 0;

    name = strrchr(argv[0], '/');
    name = name ? 1+name : argv[0];

    while ((opt = getopt(argc, argv, "d:i:P:vh?")) != EOF)
    {
        switch (opt)
        {
        case 'd':
            device = optarg;
            break;
        case 'i':
            interface = atoi(optarg);
            break;
        case 'P':
            port = atoi(optarg);
            break;
        case 'v':
            verbose++;
            break;
        case 'h':
        case '?':
            usage(name);
            return 0;
        default:
            usage(name);
            return -1;
        }
    }

    if (!device)
    {
        fprintf(stderr, "Device not specified\n");
        usage(name);
        return -1;
    }

    dev = mqnic_open(device);

    if (!dev)
    {
        fprintf(stderr, "Failed to open device\n");
        return -1;
    }

    if (dev->pci_device_path[0])
    {
        char *ptr = strrchr(dev->pci_device_path, '/');
        if (ptr)
            printf("PCIe ID: %s\n", ptr+1);
    }

    printf("Control region size: %lu\n", dev->regs_size);
    if (dev->app_regs_size)
        printf("Application region size: %lu\n", dev->app_regs_size);
    if (dev->ram_size)
        printf("RAM region size: %lu\n", dev->ram_size);

    printf("Device-level register blocks:\n");
    for (struct mqnic_reg_block *rb = dev->rb_list; rb->regs; rb++)
        printf(" type 0x%08x (v %d.%d.%d.%d)\n", rb->type, rb->version >> 24,
                (rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

    mqnic_print_fw_id(dev);

    printf("IF offset: 0x%08x\n", dev->if_offset);
    printf("IF count: %d\n", dev->if_count);
    printf("IF stride: 0x%08x\n", dev->if_stride);
    printf("IF CSR offset: 0x%08x\n", dev->if_csr_offset);

    if (dev->phc_rb)
    {
        int ch;
        uint32_t ns;
        uint32_t fns;

        printf("PHC time: %ld.%09d s\n", mqnic_reg_read32(dev->phc_rb->regs, MQNIC_RB_PHC_REG_CUR_SEC_L) +
                (((int64_t)mqnic_reg_read32(dev->phc_rb->regs, MQNIC_RB_PHC_REG_CUR_SEC_H)) << 32),
                mqnic_reg_read32(dev->phc_rb->regs, MQNIC_RB_PHC_REG_CUR_NS));

        ns = mqnic_reg_read32(dev->phc_rb->regs, MQNIC_RB_PHC_REG_PERIOD_NS);
        fns = mqnic_reg_read32(dev->phc_rb->regs, MQNIC_RB_PHC_REG_PERIOD_FNS);
        printf("PHC period:     %d.%09ld ns (raw 0x%x ns 0x%08x fns)\n", ns, ((uint64_t)fns * 1000000000) >> 32, ns, fns);

        ns = mqnic_reg_read32(dev->phc_rb->regs, MQNIC_RB_PHC_REG_NOM_PERIOD_NS);
        fns = mqnic_reg_read32(dev->phc_rb->regs, MQNIC_RB_PHC_REG_NOM_PERIOD_FNS);
        printf("PHC nom period: %d.%09ld ns (raw 0x%x ns 0x%08x fns)\n", ns, ((uint64_t)fns * 1000000000) >> 32, ns, fns);

        ch = 0;
        for (struct mqnic_reg_block *rb = dev->rb_list; rb->regs; rb++)
        {
            if (rb->type == MQNIC_RB_PHC_PEROUT_TYPE && rb->version == MQNIC_RB_PHC_PEROUT_VER)
            {
                printf("PHC perout ch %d ctrl:   0x%08x\n", ch, mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_CTRL));
                printf("PHC perout ch %d start:  %ld.%09d s\n", ch, mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_START_SEC_L) +
                        (((int64_t)mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_START_SEC_H)) << 32),
                        mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_START_NS));
                printf("PHC perout ch %d period: %ld.%09d s\n", ch, mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_PERIOD_SEC_L) +
                        (((int64_t)mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_PERIOD_SEC_H)) << 32),
                        mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_PERIOD_NS));
                printf("PHC perout ch %d width:  %ld.%09d s\n", ch, mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_WIDTH_SEC_L) +
                        (((int64_t)mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_WIDTH_SEC_H)) << 32),
                        mqnic_reg_read32(rb->regs, MQNIC_RB_PHC_PEROUT_REG_WIDTH_NS));
                ch++;
            }
        }
    }

    if (dev->clk_info_rb)
    {
        uint32_t num;
        uint32_t denom;
        uint32_t ns;
        uint32_t fns;
        uint32_t mhz;
        uint32_t hz;

        num = dev->ref_clk_nom_per_ns_num;
        denom = dev->ref_clk_nom_per_ns_denom;

        ns = num/denom;
        fns = ((num-ns*denom)*1000000000ull)/denom;

        printf("Ref clock nominal period: %d.%09d ns (raw %d/%d ns)\n", ns, fns, num, denom);

        hz = mqnic_get_ref_clk_nom_freq_hz(dev);

        mhz = hz / 1000000;
        hz = hz - (mhz * 1000000);

        printf("Ref clock nominal freq: %d.%06d MHz\n", mhz, hz);

        num = dev->core_clk_nom_per_ns_num;
        denom = dev->core_clk_nom_per_ns_denom;

        ns = num/denom;
        fns = ((num-ns*denom)*1000000000ull)/denom;

        printf("Core clock nominal period: %d.%09d ns (raw %d/%d ns)\n", ns, fns, num, denom);

        hz = mqnic_get_core_clk_nom_freq_hz(dev);

        mhz = hz / 1000000;
        hz = hz - (mhz * 1000000);

        printf("Core clock nominal freq: %d.%06d MHz\n", mhz, hz);

        hz = mqnic_get_core_clk_freq_hz(dev);

        mhz = hz / 1000000;
        hz = hz - (mhz * 1000000);

        printf("Core clock freq: %d.%06d MHz\n", mhz, hz);

        for (int ch = 0; ch < dev->clk_info_channels; ch++)
        {
            hz = mqnic_get_clk_freq_hz(dev, ch);

            mhz = hz / 1000000;
            hz = hz - (mhz * 1000000);

            printf("CH%d: clock freq: %d.%06d MHz\n", ch, mhz, hz);
        }
    }

    if (interface < 0 || interface >= dev->if_count)
    {
        fprintf(stderr, "Interface out of range\n");
        ret = -1;
        goto err;
    }

    struct mqnic_if *dev_interface = dev->interfaces[interface];

    if (!dev_interface)
    {
        fprintf(stderr, "Invalid interface\n");
        ret = -1;
        goto err;
    }

    printf("Interface-level register blocks:\n");
    for (struct mqnic_reg_block *rb = dev_interface->rb_list; rb->regs; rb++)
        printf(" type 0x%08x (v %d.%d.%d.%d)\n", rb->type, rb->version >> 24,
                (rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

    printf("IF features: 0x%08x\n", dev_interface->if_features);
    printf("Port count: %d\n", dev_interface->port_count);
    printf("Scheduler block count: %d\n", dev_interface->sched_block_count);
    printf("Max TX MTU: %d\n", dev_interface->max_tx_mtu);
    printf("Max RX MTU: %d\n", dev_interface->max_rx_mtu);
    printf("TX MTU: %d\n", mqnic_interface_get_tx_mtu(dev_interface));
    printf("RX MTU: %d\n", mqnic_interface_get_rx_mtu(dev_interface));

    printf("EQ offset: 0x%08lx\n", dev_interface->eq_res->base - dev_interface->regs);
    printf("EQ count: %d\n", mqnic_res_get_count(dev_interface->eq_res));
    printf("EQ stride: 0x%08x\n", dev_interface->eq_res->stride);

    printf("CQ offset: 0x%08lx\n", dev_interface->cq_res->base - dev_interface->regs);
    printf("CQ count: %d\n", mqnic_res_get_count(dev_interface->cq_res));
    printf("CQ stride: 0x%08x\n", dev_interface->cq_res->stride);

    printf("TXQ offset: 0x%08lx\n", dev_interface->txq_res->base - dev_interface->regs);
    printf("TXQ count: %d\n", mqnic_res_get_count(dev_interface->txq_res));
    printf("TXQ stride: 0x%08x\n", dev_interface->txq_res->stride);

    printf("RXQ offset: 0x%08lx\n", dev_interface->rxq_res->base - dev_interface->regs);
    printf("RXQ count: %d\n", mqnic_res_get_count(dev_interface->rxq_res));
    printf("RXQ stride: 0x%08x\n", dev_interface->rxq_res->stride);

    for (int p = 0; p < dev_interface->port_count; p++)
    {
        printf("Port %d RX queue map RSS mask: 0x%08x\n", p, mqnic_interface_get_rx_queue_map_rss_mask(dev_interface, p));
        printf("Port %d RX queue map app mask: 0x%08x\n", p, mqnic_interface_get_rx_queue_map_app_mask(dev_interface, p));
        printf("Port %d RX indirection table size: %d\n", p, dev_interface->rx_queue_map_indir_table_size);

        printf("Port %d RX indirection table:\n", p);
        for (int k = 0; k < dev_interface->rx_queue_map_indir_table_size; k += 8)
        {
            printf("%04x:", k);
            for (int l = 0; l < 8; l++) {
                printf(" %04x", mqnic_interface_get_rx_queue_map_indir_table(dev_interface, p, k+l));
            }
            printf("\n");
        }
    }

    if (port < 0 || port >= dev_interface->port_count)
    {
        fprintf(stderr, "Port out of range\n");
        ret = -1;
        goto err;
    }

    struct mqnic_port *dev_port = dev_interface->ports[port];

    if (!dev_port)
    {
        fprintf(stderr, "Invalid port\n");
        ret = -1;
        goto err;
    }

    printf("Port-level register blocks:\n");
    for (struct mqnic_reg_block *rb = dev_port->rb_list; rb->regs; rb++)
        printf(" type 0x%08x (v %d.%d.%d.%d)\n", rb->type, rb->version >> 24,
                (rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

    printf("Port features: 0x%08x\n", dev_port->port_features);
    printf("Port TX status: 0x%08x\n", mqnic_port_get_tx_status(dev_port));
    printf("Port RX status: 0x%08x\n", mqnic_port_get_rx_status(dev_port));

    sched_block = port;

    if (sched_block < 0 || sched_block >= dev_interface->sched_block_count)
    {
        fprintf(stderr, "Scheduler block out of range\n");
        ret = -1;
        goto err;
    }

    struct mqnic_sched_block *dev_sched_block = dev_interface->sched_blocks[sched_block];

    if (!dev_sched_block)
    {
        fprintf(stderr, "Invalid scheduler block\n");
        ret = -1;
        goto err;
    }

    printf("Scheduler block-level register blocks:\n");
    for (struct mqnic_reg_block *rb = dev_sched_block->rb_list; rb->regs; rb++)
        printf(" type 0x%08x (v %d.%d.%d.%d)\n", rb->type, rb->version >> 24,
                (rb->version >> 16) & 0xff, (rb->version >> 8) & 0xff, rb->version & 0xff);

    printf("Sched count: %d\n", dev_sched_block->sched_count);

    for (struct mqnic_reg_block *rb = dev_sched_block->rb_list; rb->regs; rb++)
    {
        if (rb->type == MQNIC_RB_SCHED_RR_TYPE && rb->version == MQNIC_RB_SCHED_RR_VER)
        {
            printf("Round-robin scheduler\n");

            printf("Sched channel count: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_CH_COUNT));
            printf("Sched channel stride: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_CH_STRIDE));
            printf("Sched control: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_CTRL));
            printf("Sched dest: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_RR_REG_DEST));
        }
        else if (rb->type == MQNIC_RB_SCHED_CTRL_TDMA_TYPE && rb->version == MQNIC_RB_SCHED_CTRL_TDMA_VER)
        {
            printf("TDMA scheduler controller\n");

            printf("Sched channel count: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_CTRL_TDMA_REG_CH_COUNT));
            printf("Sched channel stride: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_CTRL_TDMA_REG_CH_STRIDE));
            printf("Sched control: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_CTRL_TDMA_REG_CTRL));
            printf("Sched timeslot count: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_SCHED_CTRL_TDMA_REG_TS_COUNT));
        }
        else if (rb->type == MQNIC_RB_TDMA_SCH_TYPE && rb->version == MQNIC_RB_TDMA_SCH_VER)
        {
            printf("TDMA scheduler\n");

            printf("TDMA timeslot count: %d\n", mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_TS_COUNT));
            printf("TDMA control: 0x%08x\n", mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_CTRL));
            printf("TDMA status:  0x%08x\n", mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_STATUS));

            printf("TDMA schedule start:  %ld.%09d s\n", mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_SCH_START_SEC_L) +
                    (((int64_t)mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_SCH_START_SEC_H)) << 32),
                    mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_SCH_START_NS));
            printf("TDMA schedule period: %ld.%09d s\n", mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_SCH_PERIOD_SEC_L) +
                    (((int64_t)mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_SCH_PERIOD_SEC_H)) << 32),
                    mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_SCH_PERIOD_NS));
            printf("TDMA timeslot period: %ld.%09d s\n", mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_TS_PERIOD_SEC_L) +
                    (((int64_t)mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_TS_PERIOD_SEC_H)) << 32),
                    mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_TS_PERIOD_NS));
            printf("TDMA active period:   %ld.%09d s\n", mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_ACTIVE_PERIOD_SEC_L) +
                    (((int64_t)mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_ACTIVE_PERIOD_SEC_H)) << 32),
                    mqnic_reg_read32(rb->regs, MQNIC_RB_TDMA_SCH_REG_ACTIVE_PERIOD_NS));
        }
    }

    printf("EQ info\n");
    printf(" Queue      Base Address     En A  LS  A   IRQ    Prod    Cons     Len\n");
    for (int k = 0; k < mqnic_res_get_count(dev_interface->eq_res); k++)
    {
        uint32_t val;
        volatile uint8_t *base = mqnic_res_get_addr(dev_interface->eq_res, k);

        val = mqnic_reg_read32(base, MQNIC_EQ_CTRL_STATUS_REG);
        uint32_t irq = val & 0xffff;
        uint8_t enable = (val & MQNIC_EQ_ENABLE_MASK) != 0;
        uint8_t armed = (val & MQNIC_EQ_ARM_MASK) != 0;
        uint8_t active = (val & MQNIC_EQ_ACTIVE_MASK) != 0;
        uint8_t log_queue_size = (val >> 28) & 0xf;

        if (!enable && !verbose)
            continue;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_EQ_BASE_ADDR_VF_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_EQ_BASE_ADDR_VF_REG+4) << 32);
        base_addr &= 0xfffffffffffff000;
        val = mqnic_reg_read32(base, MQNIC_EQ_PTR_REG);
        uint32_t prod_ptr = val & MQNIC_EQ_PTR_MASK;
        uint32_t cons_ptr = (val >> 16) & MQNIC_EQ_PTR_MASK;
        uint32_t occupancy = (prod_ptr - cons_ptr) & MQNIC_EQ_PTR_MASK;

        printf("EQ %4d  0x%016lx  %d  %d  %2d  %d  %4d  %6d  %6d  %6d\n", k, base_addr, enable, active, log_queue_size, armed, irq, prod_ptr, cons_ptr, occupancy);
    }

    printf("CQ info\n");
    printf(" Queue      Base Address     En A  LS  A   EQN    Prod    Cons     Len\n");
    for (int k = 0; k < mqnic_res_get_count(dev_interface->cq_res); k++)
    {
        uint32_t val;
        volatile uint8_t *base = mqnic_res_get_addr(dev_interface->cq_res, k);

        val = mqnic_reg_read32(base, MQNIC_CQ_CTRL_STATUS_REG);
        uint32_t eqn = val & 0xffff;
        uint8_t enable = (val & MQNIC_CQ_ENABLE_MASK) != 0;
        uint8_t armed = (val & MQNIC_CQ_ARM_MASK) != 0;
        uint8_t active = (val & MQNIC_CQ_ACTIVE_MASK) != 0;
        uint8_t log_queue_size = (val >> 28) & 0xf;

        if (!enable && !verbose)
            continue;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_CQ_BASE_ADDR_VF_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_CQ_BASE_ADDR_VF_REG+4) << 32);
        base_addr &= 0xfffffffffffff000;
        val = mqnic_reg_read32(base, MQNIC_CQ_PTR_REG);
        uint32_t prod_ptr = val & MQNIC_CQ_PTR_MASK;
        uint32_t cons_ptr = (val >> 16) & MQNIC_CQ_PTR_MASK;
        uint32_t occupancy = (prod_ptr - cons_ptr) & MQNIC_CQ_PTR_MASK;

        printf("CQ %4d  0x%016lx  %d  %d  %2d  %d  %4d  %6d  %6d  %6d\n", k, base_addr, enable, active, log_queue_size, armed, eqn, prod_ptr, cons_ptr, occupancy);
    }

    printf("TXQ info\n");
    printf("  Queue      Base Address     En A  B  LS   CQN    Prod    Cons     Len\n");
    for (int k = 0; k < mqnic_res_get_count(dev_interface->txq_res); k++)
    {
        uint32_t val;
        volatile uint8_t *base = mqnic_res_get_addr(dev_interface->txq_res, k);

        val = mqnic_reg_read32(base, MQNIC_QUEUE_CTRL_STATUS_REG);
        uint8_t enable = (val & MQNIC_QUEUE_ENABLE_MASK) != 0;
        uint8_t active = (val & MQNIC_QUEUE_ACTIVE_MASK) != 0;

        if (!enable && !verbose)
            continue;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_VF_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_VF_REG+4) << 32);
        base_addr &= 0xfffffffffffff000;
        val = mqnic_reg_read32(base, MQNIC_QUEUE_SIZE_CQN_REG);
        uint32_t cqn = val & 0xffffff;
        uint8_t log_queue_size = (val >> 24) & 0xf;
        uint8_t log_desc_block_size = (val >> 28) & 0xf;
        val = mqnic_reg_read32(base, MQNIC_QUEUE_PTR_REG);
        uint32_t prod_ptr = val & MQNIC_QUEUE_PTR_MASK;
        uint32_t cons_ptr = (val >> 16) & MQNIC_QUEUE_PTR_MASK;
        uint32_t occupancy = (prod_ptr - cons_ptr) & MQNIC_QUEUE_PTR_MASK;

        printf("TXQ %4d  0x%016lx  %d  %d  %d  %2d  %4d  %6d  %6d  %6d\n", k, base_addr, enable, active, log_desc_block_size, log_queue_size, cqn, prod_ptr, cons_ptr, occupancy);
    }

    printf("RXQ info\n");
    printf("  Queue      Base Address     En A  B  LS   CQN    Prod    Cons     Len\n");
    for (int k = 0; k < mqnic_res_get_count(dev_interface->rxq_res); k++)
    {
        uint32_t val;
        volatile uint8_t *base = mqnic_res_get_addr(dev_interface->rxq_res, k);

        val = mqnic_reg_read32(base, MQNIC_QUEUE_CTRL_STATUS_REG);
        uint8_t enable = (val & MQNIC_QUEUE_ENABLE_MASK) != 0;
        uint8_t active = (val & MQNIC_QUEUE_ACTIVE_MASK) != 0;

        if (!enable && !verbose)
            continue;

        uint64_t base_addr = (uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_VF_REG) + ((uint64_t)mqnic_reg_read32(base, MQNIC_QUEUE_BASE_ADDR_VF_REG+4) << 32);
        base_addr &= 0xfffffffffffff000;
        val = mqnic_reg_read32(base, MQNIC_QUEUE_SIZE_CQN_REG);
        uint32_t cqn = val & 0xffffff;
        uint8_t log_queue_size = (val >> 24) & 0xf;
        uint8_t log_desc_block_size = (val >> 28) & 0xf;
        val = mqnic_reg_read32(base, MQNIC_QUEUE_PTR_REG);
        uint32_t prod_ptr = val & MQNIC_QUEUE_PTR_MASK;
        uint32_t cons_ptr = (val >> 16) & MQNIC_QUEUE_PTR_MASK;
        uint32_t occupancy = (prod_ptr - cons_ptr) & MQNIC_QUEUE_PTR_MASK;

        printf("RXQ %4d  0x%016lx  %d  %d  %d  %2d  %4d  %6d  %6d  %6d\n", k, base_addr, enable, active, log_desc_block_size, log_queue_size, cqn, prod_ptr, cons_ptr, occupancy);
    }

    if (verbose)
    {
        for (int k = 0; k < dev_sched_block->sched_count; k++)
        {
            printf("Scheduler block %d scheduler %d\n", sched_block, k);
            for (int l = 0; l < mqnic_res_get_count(dev_interface->txq_res); l++)
            {
                printf("Sched %2d queue %4d state: 0x%08x\n", k, l, mqnic_reg_read32(dev_sched_block->sched[k]->regs, l*4));
            }
        }
    }

    if (dev->stats_rb)
    {
        printf("Statistics counters\n");
        for (int k = 0; k < dev->stats_count; k++)
        {
            uint64_t val = mqnic_stats_read(dev, k);

            if (val || verbose)
                printf("Index %d: %lu\n", k, mqnic_stats_read(dev, k));
        }
    }

err:

    mqnic_close(dev);

    return ret;
}
