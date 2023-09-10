// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2019-2023 The Regents of the University of California
 */

#include "mqnic.h"

#include <stdio.h>
#include <stdlib.h>

struct mqnic_port *mqnic_port_open(struct mqnic_if *interface, int index, struct mqnic_reg_block *port_rb)
{
    struct mqnic_port *port = calloc(1, sizeof(struct mqnic_port));

    if (!port)
        return NULL;

    int offset = mqnic_reg_read32(port_rb->regs, MQNIC_RB_PORT_REG_OFFSET);

    port->mqnic = interface->mqnic;
    port->interface = interface;

    port->index = index;

    port->rb_list = mqnic_enumerate_reg_block_list(interface->regs, offset, interface->regs_size);

    if (!port->rb_list)
    {
        fprintf(stderr, "Error: filed to enumerate blocks\n");
        goto fail;
    }

    port->port_ctrl_rb = mqnic_find_reg_block(port->rb_list, MQNIC_RB_PORT_CTRL_TYPE, MQNIC_RB_PORT_CTRL_VER, 0);

    if (!port->port_ctrl_rb) {
        fprintf(stderr, "Error: port control register block not found\n");
        goto fail;
    }

    port->port_features = mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_FEATURES);

    return port;

fail:
    mqnic_port_close(port);
    return NULL;
}

void mqnic_port_close(struct mqnic_port *port)
{
    if (!port)
        return;

    if (port->rb_list)
        mqnic_free_reg_block_list(port->rb_list);

    free(port);
}

uint32_t mqnic_port_get_tx_ctrl(struct mqnic_port *port)
{
    return mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_TX_CTRL);
}

uint32_t mqnic_port_get_rx_ctrl(struct mqnic_port *port)
{
    return mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_RX_CTRL);
}

uint32_t mqnic_port_get_fc_ctrl(struct mqnic_port *port)
{
    return mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_FC_CTRL);
}

uint32_t mqnic_port_get_lfc_ctrl(struct mqnic_port *port)
{
    return mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_LFC_CTRL);
}

uint32_t mqnic_port_get_pfc_ctrl(struct mqnic_port *port, int index)
{
    return mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_PFC_CTRL0 + index*4);
}
