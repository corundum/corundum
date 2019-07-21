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

#ifndef MQNIC_HW_H
#define MQNIC_HW_H

#define MQNIC_MAX_IF 8

#define MQNIC_MAX_EVENT_RINGS   256
#define MQNIC_MAX_TX_RINGS      256
#define MQNIC_MAX_TX_CPL_RINGS  256
#define MQNIC_MAX_RX_RINGS      256
#define MQNIC_MAX_RX_CPL_RINGS  256

#define MQNIC_BOARD_ID_EXANIC_X10    0x1ce4800a
#define MQNIC_BOARD_ID_ADM_PCIE_9V3  0x41449003

// NIC CSRs
#define MQNIC_REG_FW_ID                   0x0000
#define MQNIC_REG_FW_VER                  0x0004
#define MQNIC_REG_BOARD_ID                0x0008
#define MQNIC_REG_BOARD_VER               0x000C

#define MQNIC_REG_PHC_COUNT               0x0010
#define MQNIC_REG_PHC_OFFSET              0x0014
#define MQNIC_REG_PHC_STRIDE              0x0018

#define MQNIC_REG_IF_COUNT                0x0020
#define MQNIC_REG_IF_STRIDE               0x0024
#define MQNIC_REG_IF_CSR_OFFSET           0x002C

#define MQNIC_REG_GPIO_OUT                0x0100
#define MQNIC_REG_GPIO_IN                 0x0104

#define MQNIC_PHC_REG_FEATURES            0x0000
#define MQNIC_PHC_REG_PTP_CUR_FNS         0x0010
#define MQNIC_PHC_REG_PTP_CUR_NS          0x0014
#define MQNIC_PHC_REG_PTP_CUR_SEC_L       0x0018
#define MQNIC_PHC_REG_PTP_CUR_SEC_H       0x001C
#define MQNIC_PHC_REG_PTP_GET_FNS         0x0020
#define MQNIC_PHC_REG_PTP_GET_NS          0x0024
#define MQNIC_PHC_REG_PTP_GET_SEC_L       0x0028
#define MQNIC_PHC_REG_PTP_GET_SEC_H       0x002C
#define MQNIC_PHC_REG_PTP_SET_FNS         0x0030
#define MQNIC_PHC_REG_PTP_SET_NS          0x0034
#define MQNIC_PHC_REG_PTP_SET_SEC_L       0x0038
#define MQNIC_PHC_REG_PTP_SET_SEC_H       0x003C
#define MQNIC_PHC_REG_PTP_PERIOD_FNS      0x0040
#define MQNIC_PHC_REG_PTP_PERIOD_NS       0x0044
#define MQNIC_PHC_REG_PTP_NOM_PERIOD_FNS  0x0048
#define MQNIC_PHC_REG_PTP_NOM_PERIOD_NS   0x004C
#define MQNIC_PHC_REG_PTP_ADJ_FNS         0x0050
#define MQNIC_PHC_REG_PTP_ADJ_NS          0x0054
#define MQNIC_PHC_REG_PTP_ADJ_COUNT       0x0058
#define MQNIC_PHC_REG_PTP_ADJ_ACTIVE      0x005C

#define MQNIC_PHC_REG_PEROUT_CTRL         0x0000
#define MQNIC_PHC_REG_PEROUT_STATUS       0x0004
#define MQNIC_PHC_REG_PEROUT_START_FNS    0x0010
#define MQNIC_PHC_REG_PEROUT_START_NS     0x0014
#define MQNIC_PHC_REG_PEROUT_START_SEC_L  0x0018
#define MQNIC_PHC_REG_PEROUT_START_SEC_H  0x001C
#define MQNIC_PHC_REG_PEROUT_PERIOD_FNS   0x0020
#define MQNIC_PHC_REG_PEROUT_PERIOD_NS    0x0024
#define MQNIC_PHC_REG_PEROUT_PERIOD_SEC_L 0x0028
#define MQNIC_PHC_REG_PEROUT_PERIOD_SEC_H 0x002C
#define MQNIC_PHC_REG_PEROUT_WIDTH_FNS    0x0030
#define MQNIC_PHC_REG_PEROUT_WIDTH_NS     0x0034
#define MQNIC_PHC_REG_PEROUT_WIDTH_SEC_L  0x0038
#define MQNIC_PHC_REG_PEROUT_WIDTH_SEC_H  0x003C

// Interface CSRs
#define MQNIC_IF_REG_IF_ID                0x0000
#define MQNIC_IF_REG_IF_FEATURES          0x0004

#define MQNIC_IF_REG_EVENT_QUEUE_COUNT    0x0010
#define MQNIC_IF_REG_EVENT_QUEUE_OFFSET   0x0014
#define MQNIC_IF_REG_TX_QUEUE_COUNT       0x0020
#define MQNIC_IF_REG_TX_QUEUE_OFFSET      0x0024
#define MQNIC_IF_REG_TX_CPL_QUEUE_COUNT   0x0028
#define MQNIC_IF_REG_TX_CPL_QUEUE_OFFSET  0x002C
#define MQNIC_IF_REG_RX_QUEUE_COUNT       0x0030
#define MQNIC_IF_REG_RX_QUEUE_OFFSET      0x0034
#define MQNIC_IF_REG_RX_CPL_QUEUE_COUNT   0x0038
#define MQNIC_IF_REG_RX_CPL_QUEUE_OFFSET  0x003C
#define MQNIC_IF_REG_PORT_COUNT           0x0040
#define MQNIC_IF_REG_PORT_OFFSET          0x0044
#define MQNIC_IF_REG_PORT_STRIDE          0x0048

#define MQNIC_QUEUE_STRIDE        0x00000020
#define MQNIC_CPL_QUEUE_STRIDE    0x00000020
#define MQNIC_EVENT_QUEUE_STRIDE  0x00000020

#define MQNIC_QUEUE_BASE_ADDR_REG       0x00
#define MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG 0x08
#define MQNIC_QUEUE_CPL_QUEUE_INDEX_REG 0x0C
#define MQNIC_QUEUE_HEAD_PTR_REG        0x10
#define MQNIC_QUEUE_TAIL_PTR_REG        0x18

#define MQNIC_QUEUE_ACTIVE_MASK 0x80000000

#define MQNIC_CPL_QUEUE_BASE_ADDR_REG       0x00
#define MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG 0x08
#define MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG 0x0C
#define MQNIC_CPL_QUEUE_HEAD_PTR_REG        0x10
#define MQNIC_CPL_QUEUE_TAIL_PTR_REG        0x18

#define MQNIC_CPL_QUEUE_ACTIVE_MASK 0x80000000

#define MQNIC_CPL_QUEUE_ARM_MASK 0x80000000
#define MQNIC_CPL_QUEUE_CONT_MASK 0x40000000

#define MQNIC_EVENT_QUEUE_BASE_ADDR_REG       0x00
#define MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG 0x08
#define MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG 0x0C
#define MQNIC_EVENT_QUEUE_HEAD_PTR_REG        0x10
#define MQNIC_EVENT_QUEUE_TAIL_PTR_REG        0x18

#define MQNIC_EVENT_QUEUE_ACTIVE_MASK 0x80000000

#define MQNIC_EVENT_QUEUE_ARM_MASK 0x80000000
#define MQNIC_EVENT_QUEUE_CONT_MASK 0x40000000

#define MQNIC_EVENT_TYPE_TX_CPL 0x0000
#define MQNIC_EVENT_TYPE_RX_CPL 0x0001

#define MQNIC_DESC_SIZE 16
#define MQNIC_CPL_SIZE 32
#define MQNIC_EVENT_SIZE 32

struct mqnic_desc {
    u16 rsvd0;
    u16 tx_csum_cmd;
    u32 len;
    u64 addr;
};

struct mqnic_cpl {
    u16 queue;
    u16 index;
    u16 len;
    u16 rsvd0;
    u32 ts_ns;
    u16 ts_s;
    u16 rx_csum;
};

struct mqnic_event {
    u16 type;
    u16 source;
};

#endif /* MQNIC_HW_H */
