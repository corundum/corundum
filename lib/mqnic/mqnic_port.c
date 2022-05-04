/*

Copyright 2019-2022, The Regents of the University of California.
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

uint32_t mqnic_port_get_tx_status(struct mqnic_port *port)
{
    return mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_TX_STATUS);
}

uint32_t mqnic_port_get_rx_status(struct mqnic_port *port)
{
    return mqnic_reg_read32(port->port_ctrl_rb->regs, MQNIC_RB_PORT_CTRL_REG_RX_STATUS);
}
