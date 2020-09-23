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

#include <linux/types.h>

#define MQNIC_MAX_IF 8
#define MQNIC_MAX_PORTS 8
#define MQNIC_MAX_SCHED 8

#define MQNIC_MAX_FRAGS 8

#define MQNIC_MAX_EVENT_RINGS   256
#define MQNIC_MAX_TX_RINGS      8192
#define MQNIC_MAX_TX_CPL_RINGS  8192
#define MQNIC_MAX_RX_RINGS      8192
#define MQNIC_MAX_RX_CPL_RINGS  8192

#define MQNIC_MAX_I2C_ADAPTERS 4

#define MQNIC_BOARD_ID_NETFPGA_SUME  0x10ee7028
#define MQNIC_BOARD_ID_AU50          0x10ee9032
#define MQNIC_BOARD_ID_AU200         0x10ee90c8
#define MQNIC_BOARD_ID_AU250         0x10ee90fa
#define MQNIC_BOARD_ID_AU280         0x10ee9118
#define MQNIC_BOARD_ID_VCU108        0x10ee806c
#define MQNIC_BOARD_ID_VCU118        0x10ee9076
#define MQNIC_BOARD_ID_VCU1525       0x10ee95f5
#define MQNIC_BOARD_ID_ZCU106        0x10ee906a
#define MQNIC_BOARD_ID_FB2CG_KU15P   0x1c2ca00e
#define MQNIC_BOARD_ID_EXANIC_X10    0x1ce40003
#define MQNIC_BOARD_ID_EXANIC_X25    0x1ce40009
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

#define MQNIC_REG_FPGA_ID                 0x0040

#define MQNIC_REG_GPIO_OUT                0x0100
#define MQNIC_REG_GPIO_IN                 0x0104

#define MQNIC_REG_GPIO_I2C_0              0x0110
#define MQNIC_REG_GPIO_I2C_1              0x0114
#define MQNIC_REG_GPIO_I2C_2              0x0118
#define MQNIC_REG_GPIO_I2C_3              0x011C

#define MQNIC_REG_GPIO_I2C_SCL_IN         0x00000001
#define MQNIC_REG_GPIO_I2C_SCL_OUT        0x00000002
#define MQNIC_REG_GPIO_I2C_SDA_IN         0x00000100
#define MQNIC_REG_GPIO_I2C_SDA_OUT        0x00000200

#define MQNIC_REG_GPIO_XCVR_0123          0x0120
#define MQNIC_REG_GPIO_XCVR_4567          0x0124

#define MQNIC_REG_GPIO_XCVR_PRSNT_IN           0x01
#define MQNIC_REG_GPIO_XCVR_TX_FAULT_INT_IN    0x02
#define MQNIC_REG_GPIO_XCVR_RX_LOS_IN          0x03
#define MQNIC_REG_GPIO_XCVR_RST_OUT            0x10
#define MQNIC_REG_GPIO_XCVR_TX_DIS_LPMODE_OUT  0x20
#define MQNIC_REG_GPIO_XCVR_RS0_OUT            0x40
#define MQNIC_REG_GPIO_XCVR_RS1_OUT            0x80

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

#define MQNIC_PHC_PEROUT_OFFSET           0x60
#define MQNIC_PHC_PEROUT_STRIDE           0x40

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

#define MQNIC_IF_FEATURE_RSS              (1 << 0)
#define MQNIC_IF_FEATURE_PTP_TS           (1 << 4)
#define MQNIC_IF_FEATURE_TX_CSUM          (1 << 8)
#define MQNIC_IF_FEATURE_RX_CSUM          (1 << 9)
#define MQNIC_IF_FEATURE_RX_HASH          (1 << 10)

// Port CSRs
#define MQNIC_PORT_REG_PORT_ID                    0x0000
#define MQNIC_PORT_REG_PORT_FEATURES              0x0004
#define MQNIC_PORT_REG_PORT_MTU                   0x0008

#define MQNIC_PORT_REG_SCHED_COUNT                0x0010
#define MQNIC_PORT_REG_SCHED_OFFSET               0x0014
#define MQNIC_PORT_REG_SCHED_STRIDE               0x0018
#define MQNIC_PORT_REG_SCHED_TYPE                 0x001C
#define MQNIC_PORT_REG_SCHED_ENABLE               0x0040

#define MQNIC_PORT_REG_RSS_MASK                   0x0080

#define MQNIC_PORT_REG_TX_MTU                     0x0100
#define MQNIC_PORT_REG_RX_MTU                     0x0200

#define MQNIC_PORT_REG_TDMA_CTRL                  0x1000
#define MQNIC_PORT_REG_TDMA_STATUS                0x1004
#define MQNIC_PORT_REG_TDMA_TIMESLOT_COUNT        0x1008
#define MQNIC_PORT_REG_TDMA_SCHED_START_FNS       0x1010
#define MQNIC_PORT_REG_TDMA_SCHED_START_NS        0x1014
#define MQNIC_PORT_REG_TDMA_SCHED_START_SEC_L     0x1018
#define MQNIC_PORT_REG_TDMA_SCHED_START_SEC_H     0x101C
#define MQNIC_PORT_REG_TDMA_SCHED_PERIOD_FNS      0x1020
#define MQNIC_PORT_REG_TDMA_SCHED_PERIOD_NS       0x1024
#define MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_L    0x1028
#define MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_H    0x102C
#define MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_FNS   0x1030
#define MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_NS    0x1034
#define MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_L 0x1038
#define MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_H 0x103C
#define MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_FNS     0x1040
#define MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_NS      0x1044
#define MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_L   0x1048
#define MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_H   0x104C

#define MQNIC_PORT_FEATURE_RSS                    (1 << 0)
#define MQNIC_PORT_FEATURE_PTP_TS                 (1 << 4)
#define MQNIC_PORT_FEATURE_TX_CSUM                (1 << 8)
#define MQNIC_PORT_FEATURE_RX_CSUM                (1 << 9)
#define MQNIC_PORT_FEATURE_RX_HASH                (1 << 10)

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
    __u16 rsvd0;
    __u16 tx_csum_cmd;
    __u32 len;
    __u64 addr;
};

struct mqnic_cpl {
    __u16 queue;
    __u16 index;
    __u16 len;
    __u16 rsvd0;
    __u32 ts_ns;
    __u16 ts_s;
    __u16 rx_csum;
    __u32 rx_hash;
    __u8 rx_hash_type;
    __u8 rsvd1;
    __u8 rsvd2;
    __u8 rsvd3;
    __u32 rsvd4;
    __u32 rsvd5;
};

struct mqnic_event {
    __u16 type;
    __u16 source;
};

#endif /* MQNIC_HW_H */
